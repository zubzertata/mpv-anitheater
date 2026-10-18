local mp   = require "mp"
local msg  = require "mp.msg"
local utils = require "mp.utils"
local backend = require "backends.google"
local parser  = require "parser"

local M = {}

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local cached_cache_dir = nil
local function get_cache_dir()
    if cached_cache_dir then return cached_cache_dir end
    local dir = mp.command_native({"expand-path", "~~/cache/traduccion"})
    local info = utils.file_info(dir)
    if not info or not info.is_dir then
        local is_windows = package.config:sub(1, 1) == "\\"
        if is_windows then
            local clean_dir = (dir:gsub("/", "\\"))
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
                args = {"mkdir", "-p", dir},
                capture_stdout = true,
                capture_stderr = true
            })
        end
    end
    cached_cache_dir = dir
    return dir
end

local function escape_lua_pattern(s)
    return (s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

local cached_ffmpeg_path = nil
local function get_ffmpeg_path()
    if cached_ffmpeg_path then return cached_ffmpeg_path end
    local is_windows = package.config:sub(1, 1) == "\\"
    local exe_name = is_windows and "ffmpeg.exe" or "ffmpeg"
    local candidates = {
        mp.command_native({"expand-path", "~~exe_dir/" .. exe_name}),
        mp.command_native({"expand-path", "~~/" .. exe_name}),
        mp.command_native({"expand-path", "~~/../" .. exe_name}),
    }
    local script_dir = mp.get_script_directory()
    if script_dir then
        table.insert(candidates, utils.join_path(script_dir, "../../" .. exe_name))
        table.insert(candidates, utils.join_path(script_dir, "../../../" .. exe_name))
    end
    for _, path in ipairs(candidates) do
        if path and path ~= "" then
            local f = io.open(path, "rb")
            if f then
                f:close()
                cached_ffmpeg_path = path
                return path
            end
        end
    end
    cached_ffmpeg_path = "ffmpeg"
    return "ffmpeg"
end

local cached_has_ffmpeg = nil
local function has_ffmpeg()
    if cached_has_ffmpeg ~= nil then return cached_has_ffmpeg end
    local res = mp.command_native({
        name = "subprocess",
        playback_only = false,
        args = {get_ffmpeg_path(), "-version"},
        capture_stdout = true
    })
    cached_has_ffmpeg = (res and res.status == 0) or false
    return cached_has_ffmpeg
end

local function extract_subtitle(video_path, ff_index, out_path)
    msg.info("Extracting subtitle stream ff-index=" .. ff_index .. " to " .. out_path)
    local res = mp.command_native({
        name = "subprocess",
        playback_only = false,
        args = {get_ffmpeg_path(), "-y", "-hide_banner", "-loglevel", "error",
                "-i", video_path, "-map", "0:" .. ff_index, out_path},
        capture_stdout = true,
        capture_stderr = true,
    })
    if not res or res.status ~= 0 then
        msg.error("FFmpeg failed: " .. (res and res.stderr or "unknown error"))
        return false
    end
    return true
end

local function is_valid_sub_file(path)
    if not path or path == "" then return false end
    local f = io.open(path, "rb")
    if not f then return false end
    local data = f:read("*all")
    f:close()
    if not data or data == "" or data:find("%z") ~= nil then return false end
    local is_ass = data:find("%[Events%]") and data:find("Dialogue:")
    local is_srt = data:find("%d%d:%d%d:%d%d[,.]%d%d%d %-%-> ")
    return (is_ass or is_srt) ~= nil
end

-- ─── Main translation entry-point ─────────────────────────────────────────────

function M.start_translation(track, target_lang, callback, session_id, save_subtitles, on_progress)
    if not track then callback(false); return end

    local video_path = mp.get_property("path")
    if not video_path then callback(false); return end

    -- Resolve video directory (handle relative paths)
    local video_dir, video_name = utils.split_path(video_path)
    if not video_path:match("^%a+://") and not video_path:match("^\\\\") then
        local wd = mp.get_property("working-directory")
        if wd and video_dir ~= "" then
            video_dir = utils.join_path(wd, video_dir)
        elseif wd then
            video_dir = wd
        end
    end

    local video_base = video_name:match("(.+)%..+$") or video_name
    local is_network = video_path:find("^https?://") ~= nil

    local cache_dir = get_cache_dir()

    -- ── Output path: Standard ISO naming <video_base>.<target_lang>.ass ─────────
    local out_name = video_base .. "." .. target_lang .. ".ass"
    local save_to_disk = (save_subtitles ~= false)

    local target_disk_path = nil
    if save_to_disk and not is_network and video_dir and video_dir ~= "" then
        target_disk_path = utils.join_path(video_dir, out_name)
    end
    local target_cache_path = utils.join_path(cache_dir, out_name)

    -- Check if valid translated subtitle ALREADY exists on disk next to video
    if target_disk_path and is_valid_sub_file(target_disk_path) then
        msg.info("Translated subtitle already exists next to video: " .. target_disk_path)
        callback(true, target_disk_path)
        return
    end

    -- Check if valid translated subtitle ALREADY exists in cache
    if is_valid_sub_file(target_cache_path) then
        msg.info("Translated subtitle already exists in cache: " .. target_cache_path)
        callback(true, target_cache_path)
        return
    end

    -- Check legacy patterns (e.g. video_base_ja-es.ass or video_base_un-es.ass) with escaped metacharacters
    local safe_base = escape_lua_pattern(video_base)
    local safe_lang = escape_lua_pattern(target_lang)
    local legacy_name_pattern = "^" .. safe_base .. "_%a%a%-" .. safe_lang .. "%.ass$"
    if video_dir and video_dir ~= "" then
        local files = utils.readdir(video_dir, "files")
        if files then
            for _, fn in ipairs(files) do
                if fn:match(legacy_name_pattern) then
                    local leg_path = utils.join_path(video_dir, fn)
                    if is_valid_sub_file(leg_path) then
                        msg.info("Found valid legacy translated subtitle: " .. leg_path)
                        callback(true, leg_path)
                        return
                    end
                end
            end
        end
    end

    local out_path = target_disk_path or target_cache_path

    -- ── Extract subtitle if it is embedded ───────────────────────────────────
    local src_path
    if track.external then
        src_path = track["external-filename"]
    else
        if not has_ffmpeg() then
            msg.error("FFmpeg not found")
            mp.osd_message("⚠️ FFmpeg no encontrado: ejecuta 'descargar-ffmpeg.bat' en la carpeta de mpv", 7)
            callback(false)
            return
        end
        src_path = utils.join_path(cache_dir, video_base .. "_track" .. track.id .. ".src.ass")
        if not extract_subtitle(video_path, track["ff-index"], src_path) then
            callback(false)
            return
        end
    end

    -- ── Parse ─────────────────────────────────────────────────────────────────
    local blocks, format = parser.parse_file(src_path)
    if not blocks or #blocks == 0 then
        msg.error("Failed to parse subtitle file: " .. tostring(src_path))
        if not track.external then os.remove(src_path) end
        callback(false)
        return
    end

    -- Collect only non-empty dialogue lines, tracking their original indices
    local texts    = {}
    local indices  = {}
    for i, block in ipairs(blocks) do
        if block.type == "dialogue" then
            local t = block.text
            if t and t ~= "" and not t:match("^%s*$") then
                table.insert(texts, t)
                table.insert(indices, i)
            end
        end
    end

    if #texts == 0 then
        msg.warn("No translatable text found in subtitle")
        if not track.external then os.remove(src_path) end
        callback(false)
        return
    end

    -- ── Translate ─────────────────────────────────────────────────────────────
    backend.translate(texts, target_lang, function(success, translated)
        if not success then
            -- Clean up extracted source if it was temporary
            if not track.external then os.remove(src_path) end
            callback(false)
            return
        end

        -- Reconstruct blocks with translated text
        for k, translated_text in ipairs(translated) do
            local orig_idx = indices[k]
            if orig_idx then
                blocks[orig_idx].text = translated_text
            end
        end

        -- Write output; if writing next to the video fails, fall back to cache
        local ok = parser.write_file(blocks, format, out_path)
        if not ok then
            local fallback = utils.join_path(cache_dir, out_name)
            msg.warn("Cannot write to video folder. Saving to cache: " .. fallback)
            mp.osd_message("Sin permiso para escribir junto al vídeo. Guardando en caché.", 5)
            ok = parser.write_file(blocks, format, fallback)
            if ok then out_path = fallback end
        end

        -- Clean up temporary extracted source
        if not track.external then os.remove(src_path) end

        if ok then
            callback(true, out_path)
        else
            msg.error("Failed to write translated subtitle to any location")
            callback(false)
        end
    end, session_id, on_progress)
end

return M


