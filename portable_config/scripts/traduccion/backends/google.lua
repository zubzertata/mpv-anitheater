local mp = require "mp"
local msg = require "mp.msg"
local utils = require "mp.utils"

local M = {}

-- Incremented every time a new file loads, to discard stale callbacks
local current_session = 0

-- Separator token that Google Translate never translates (Japanese corner brackets)
local SEP = "※※※"

local function chunk_lines(lines, max_lines)
    local chunks = {}
    local i = 1
    while i <= #lines do
        local chunk = {}
        for j = i, math.min(i + max_lines - 1, #lines) do
            table.insert(chunk, lines[j])
        end
        table.insert(chunks, chunk)
        i = i + max_lines
    end
    return chunks
end

-- Call this on every file-loaded to cancel pending callbacks from the previous file
function M.new_session()
    current_session = current_session + 1
    return current_session
end

local cached_temp_dir = nil
local function ensure_temp_dir()
    if cached_temp_dir then return cached_temp_dir end
    local temp_dir = mp.command_native({"expand-path", "~~/cache/traduccion"})
    local info = utils.file_info(temp_dir)
    if not info or not info.is_dir then
        local is_windows = package.config:sub(1, 1) == "\\"
        if is_windows then
            local clean_dir = (temp_dir:gsub("/", "\\"))
            mp.command_native({
                name = "subprocess",
                playback_only = false,
                args = {"cmd.exe", "/c", "mkdir", clean_dir},
                capture_stdout = true,
                capture_stderr = true
            })
        else
            mp.command_native({
                name = "subprocess",
                playback_only = false,
                args = {"mkdir", "-p", temp_dir},
                capture_stdout = true,
                capture_stderr = true
            })
        end
    end
    cached_temp_dir = temp_dir
    return temp_dir
end

-- Translate a list of text strings to target_lang.
-- session_id: pass the value returned by M.new_session() so callbacks from
--             old sessions are discarded automatically.
function M.translate(texts, target_lang, callback, session_id, on_progress)
    if #texts == 0 then
        callback(true, {})
        return
    end

    local my_session = session_id or current_session

    -- Split into chunks of 80 lines max (well within URL/POST limits)
    local chunks = chunk_lines(texts, 80)
    local results = {}
    local pending = #chunks
    local completed = 0
    local has_error = false
    local max_retries = 2
    local max_concurrent = 4
    local next_chunk_idx = 1

    local temp_dir = ensure_temp_dir()
    local temp_id = tostring(os.time()) .. tostring(math.random(1000, 9999))

    local send_chunk
    local function dispatch_next()
        if current_session ~= my_session or has_error then return end
        if next_chunk_idx <= #chunks then
            local idx = next_chunk_idx
            next_chunk_idx = next_chunk_idx + 1
            send_chunk(idx, 0)
        end
    end

    send_chunk = function(i, retry_count)
        if current_session ~= my_session or has_error then return end

        local chunk = chunks[i]
        local joined = table.concat(chunk, "\n" .. SEP .. "\n")
        local temp_file = utils.join_path(temp_dir, "mpv_tr_" .. temp_id .. "_" .. i .. "_" .. retry_count .. ".txt")
        local f = io.open(temp_file, "wb")
        if f then
            f:write(joined)
            f:close()
        end

        local args = {
            "curl", "-s",
            "-d", "client=gtx&sl=auto&tl=" .. target_lang .. "&dt=t&ie=UTF-8&oe=UTF-8",
            "--data-urlencode", "q@" .. temp_file,
            "https://translate.googleapis.com/translate_a/single"
        }

        mp.command_native_async({
            name = "subprocess",
            playback_only = false,
            args = args,
            capture_stdout = true,
            capture_stderr = true
        }, function(success, res, err)
            os.remove(temp_file)

            -- Discard if user opened a new file while we were waiting
            if current_session ~= my_session then return end
            if has_error then return end

            local data = (success and res and res.status == 0) and utils.parse_json(res.stdout) or nil
            if not data or not data[1] then
                if retry_count < max_retries then
                    msg.warn(string.format("Google Translate chunk %d failed (attempt %d/%d). Retrying in 2s...", i, retry_count + 1, max_retries + 1))
                    mp.add_timeout(2, function()
                        if current_session == my_session and not has_error then
                            send_chunk(i, retry_count + 1)
                        end
                    end)
                    return
                else
                    msg.error("Google Translate request failed permanently (chunk " .. i .. "): " .. tostring(res and res.stderr or err))
                    has_error = true
                    callback(false)
                    return
                end
            end

            -- Reassemble the full translated text from all segments Google returned
            local translated_full = ""
            for _, segment in ipairs(data[1]) do
                if segment[1] then
                    translated_full = translated_full .. segment[1]
                end
            end

            -- Strip carriage returns that corrupt ASS files on Windows
            translated_full = translated_full:gsub("\r", "")

            -- Split by the separator token back into individual lines.
            local translated_chunk = {}
            for part in (translated_full .. SEP):gmatch("(.-)" .. SEP) do
                part = part:gsub("^\n+", ""):gsub("\n+$", "")
                table.insert(translated_chunk, part)
            end

            -- Guarantee EXACT line count so indices never shift between chunks.
            while #translated_chunk > #chunk do
                local extra = table.remove(translated_chunk)
                if extra and extra ~= "" then
                    translated_chunk[#translated_chunk] = translated_chunk[#translated_chunk] .. " " .. extra
                end
            end
            while #translated_chunk < #chunk do
                local missing_idx = #translated_chunk + 1
                table.insert(translated_chunk, chunk[missing_idx] or "")
            end

            results[i] = translated_chunk
            pending = pending - 1
            completed = completed + 1

            if on_progress then
                on_progress(completed, #chunks)
            end

            if pending == 0 then
                -- Reconstruct in original order
                local all_translated = {}
                for j = 1, #chunks do
                    for _, t in ipairs(results[j] or {}) do
                        table.insert(all_translated, t)
                    end
                end
                callback(true, all_translated)
            else
                dispatch_next()
            end
        end)
    end

    for _ = 1, math.min(max_concurrent, #chunks) do
        dispatch_next()
    end
end

return M

