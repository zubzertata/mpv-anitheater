local M = {}

-- Parses a subtitle file (ASS or SRT) into an array of blocks.
-- Returns: blocks, format ("ass" or "srt")
function M.parse_file(filepath)
    local f = io.open(filepath, "rb")
    if not f then return nil end
    local content = f:read("*all")
    f:close()

    -- Strip UTF-8 BOM if present
    if content:sub(1, 3) == "\xEF\xBB\xBF" then
        content = content:sub(4)
    end

    -- Normalize all line endings to \n
    content = content:gsub("\r\n", "\n")
    content = content:gsub("\r", "")

    -- Detect format: ASS if any structural marker is found
    local is_ass = content:find("%[Script Info%]")
        or content:find("%[Events%]")
        or content:find("Dialogue:")
    local format = is_ass and "ass" or "srt"

    local blocks = {}

    if format == "ass" then
        for line in content:gmatch("([^\n]*)\n?") do
            if line:match("^Dialogue:") then
                -- Split at the 9th comma to isolate the text field
                local split_pos = 0
                local comma_count = 0
                for i = 1, #line do
                    if line:sub(i, i) == "," then
                        comma_count = comma_count + 1
                        if comma_count == 9 then
                            split_pos = i
                            break
                        end
                    end
                end

                if split_pos > 0 then
                    local prefix = line:sub(1, split_pos)
                    local text   = line:sub(split_pos + 1)

                    -- Replace ASS inline tags and newline/space codes with placeholders
                    -- so the translator never sees or corrupts them.
                    local placeholders = {}
                    local p_idx = 1

                    local clean_text = text:gsub("({[^}]+})", function(tag)
                        placeholders[p_idx] = tag
                        local ph = "[[" .. p_idx .. "]]"
                        p_idx = p_idx + 1
                        return ph
                    end)
                    clean_text = clean_text:gsub("\\[Nnh]", function(tag)
                        placeholders[p_idx] = tag
                        local ph = "[[" .. p_idx .. "]]"
                        p_idx = p_idx + 1
                        return ph
                    end)

                    table.insert(blocks, {
                        type         = "dialogue",
                        prefix       = prefix,
                        text         = clean_text,
                        placeholders = placeholders,
                    })
                else
                    -- Malformed Dialogue line: preserve as-is
                    table.insert(blocks, { type = "raw", text = line })
                end
            else
                table.insert(blocks, { type = "raw", text = line })
            end
        end
    else
        -- SRT: number lines, timestamps, and blank lines are raw structure.
        -- Handles both comma and dot as millisecond separator (00:00:00,000 and 00:00:00.000)
        for line in content:gmatch("([^\n]*)\n?") do
            local is_raw = line == ""
                or line:match("^%d+$")
                or line:match("%d%d:%d%d:%d%d[,.]%d%d%d %-%-> %d%d:%d%d:%d%d[,.]%d%d%d")
            if is_raw then
                table.insert(blocks, { type = "raw", text = line })
            else
                table.insert(blocks, {
                    type         = "dialogue",
                    text         = line,
                    placeholders = {},
                })
            end
        end
    end

    return blocks, format
end

-- Writes translated blocks to a subtitle file.
-- Returns true on success, false on failure.
function M.write_file(blocks, format, out_path)
    local f = io.open(out_path, "wb")
    if not f then return false end

    -- Strip any NUL bytes that could corrupt the file or crash libass
    local function clean(text)
        if type(text) ~= "string" then return "" end
        return text:gsub("%z", "")
    end

    for i, block in ipairs(blocks) do
        if block.type == "raw" then
            local text = clean(block.text)
            -- Suppress the trailing empty block to avoid a double-newline at EOF
            if i < #blocks or text ~= "" then
                f:write(text .. "\n")
            end

        elseif block.type == "dialogue" then
            local text = clean(block.text)

            if format == "ass" then
                -- Restore all placeholders (tags, \N, \n, \h) exactly as they were
                -- Matches [[1]], [[ 1 ]], [ [ 1 ] ], and fullwidth bracket variants
                text = text:gsub("%[%s*%[%s*(%d+)%s*%]%s*%]", function(num)
                    local idx = tonumber(num)
                    return block.placeholders[idx] or ""
                end)
                text = text:gsub("【%s*【%s*(%d+)%s*】%s*】", function(num)
                    local idx = tonumber(num)
                    return block.placeholders[idx] or ""
                end)
                f:write(clean(block.prefix) .. text .. "\n")
            else
                f:write(text .. "\n")
            end
        end
    end

    f:close()
    return true
end

return M
