-- [[ 
--    FILENAME: skip_intro.lua
--    VERSION:  v2.2 (Performance Fix - Cached Chapters)
--    AUTHOR:   mpv-anime-build
--    DESC:     Comprehensive detection for OP/ED/PV/Intro/Avant in ENG/JPN/ROMAJI.
-- ]]

local mp = require("mp")
local utils = require("mp.utils")
local opts = {
    enabled = true,
    mode = "manual", -- manual, auto_all, auto_op, off
    skip_key = "ENTER",
    timeout = 6
}

local mode_labels = {
    manual   = "Aviso en pantalla (Manual)",
    auto_all = "Automático (Opening y Ending)",
    auto_op  = "Automático (Solo Opening)",
    off      = "Desactivado"
}

local conf_path = mp.command_native({"expand-path", "~~/script-opts/skip_intro.conf"})
local function load_skip_conf()
    local f = io.open(conf_path, "r")
    if not f then return end
    for line in f:lines() do
        local k, v = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
        if k == "mode" and mode_labels[v] then
            opts.mode = v
            opts.enabled = (v ~= "off")
        end
    end
    f:close()
end

local function save_skip_conf()
    local f = io.open(conf_path, "w")
    if f then
        f:write("mode=" .. opts.mode .. "\n")
        f:close()
    end
end

local function sync_skip_props()
    mp.set_property("user-data/skip-intro/mode", opts.mode)
    mp.set_property("user-data/skip-intro/label", mode_labels[opts.mode] or "Aviso en pantalla (Manual)")
    mp.commandv("script-message-to", "uosc", "refresh-master-menu")
end

load_skip_conf()
sync_skip_props()

-- [COMPREHENSIVE PATTERN MATCHING]
-- (Kept exactly as you had it)
local categories = {
    { 
        label = "OP", 
        keywords = { 
            "opening", " op ", "♪ OP" , "♪OP" , "^op$", "op%d", "theme song", "main theme",
            "オープニング", "オープニングテーマ", "OPテーマ", "主題歌",
            "ncop", "creditless op", "creditless opening"
        } 
    },
    { 
        label = "ED", 
        keywords = { 
            "ending", " ed ", "♪ ED" , "♪ED" , "^ed$", "ed%d", "credits", "outro", "end roll",
            "エンディング", "エンディングテーマ", "EDテーマ", "結び",
            "nced", "creditless ed", "creditless ending"
        } 
    },
    { 
        label = "PV", 
        keywords = { 
            "preview", " pv ", "^pv$", "pv%d", "trailer", "next episode",
            "予告", "次回予告", "特報", "プロモーション",
            "jikai", "yokoku"
        } 
    },
    { 
        label = "Intro", 
        keywords = { 
            "intro", "introduction", "prologue", "cold open", 
            "アバン", "アバンタイトル", "序章", "前説"
        } 
    }
}

-- [COLOR PALETTE]
local label_colors = {
    Intro = "FF00FF", -- Magenta
    OP    = "00FF00", -- Green
    PV    = "0099FF", -- Orange
    ED    = "FF8000"  -- Blue
}

local state = {
    key_bound = false,
    mouse_bound = false,
    active_label = nil,
    is_skipping = false,
    timer = nil,
    tick_timer = nil,
    current_chapter_idx = -1,
    remaining_seconds = 0,
    cached_chapters = nil,
    canvas_dirty = false
}

local function get_chapter_label(title)
    if not title then return nil end
    local title_lower = title:lower()
    for _, category in ipairs(categories) do
        for _, keyword in ipairs(category.keywords) do
            if title_lower:find(keyword) or title:find(keyword) then
                return category.label
            end
        end
    end
    return nil
end

local function paint_canvas(ass_text)
    if ass_text == "" then
        if not state.canvas_dirty then return end
        state.canvas_dirty = false
    else
        state.canvas_dirty = true
    end
    mp.set_osd_ass(1920, 1080, ass_text)
end

local function clear_bindings()
    if state.key_bound then
        mp.remove_key_binding("skip-intro-action")
        state.key_bound = false
    end
    if state.mouse_bound then
        mp.remove_key_binding("mouse-skip-action")
        state.mouse_bound = false
    end
end

local function stop_tick_timer()
    if state.tick_timer then
        state.tick_timer:stop()
    end
end

-- (Kept your exact button styling)
local function draw_button(label, remaining, is_hovering)
    local cx, cy = 1650, 980
    local ass = "{\\an5}{\\pos(" .. cx .. "," .. cy .. ")}"
    ass = ass .. "{\\fnSource Sans Pro}{\\fs36}{\\b1}"
    ass = ass .. "{\\bord4}{\\shad2}{\\blur4}{\\3c&H000000&}{\\4c&H000000&}"
    
    if is_hovering then
        ass = ass .. "{\\1c&HFFFF00&}"
        ass = ass .. "▶ SKIP " .. string.upper(label) .. " [" .. opts.skip_key .. "] (" .. remaining .. ")"
    else
        local specific_color = label_colors[label] or "0099FF"
        ass = ass .. "{\\1c&H" .. specific_color .. "&}▶ "
        ass = ass .. "{\\1c&HFFFFFF&}SKIP "
        ass = ass .. "{\\1c&H" .. specific_color .. "&}" .. string.upper(label) .. " "
        ass = ass .. "{\\1c&HFFFFFF&}[" .. opts.skip_key .. "] (" .. remaining .. ")"
    end
    paint_canvas(ass)
end

local function draw_feedback(label, color_hex)
    local cx, cy = 1650, 980
    local ass = "{\\an5}{\\pos(" .. cx .. "," .. cy .. ")}"
    ass = ass .. "{\\fnSource Sans Pro}{\\fs36}{\\b1}"
    ass = ass .. "{\\bord4}{\\shad2}{\\blur4}{\\3c&H000000&}"
    ass = ass .. "{\\1c&H" .. color_hex .. "&}▶ "
    ass = ass .. "{\\1c&HFFFFFF&}SKIPPED "
    ass = ass .. "{\\1c&H" .. color_hex .. "&}" .. string.upper(label)
    paint_canvas(ass)
end

local function skip_action()
    state.is_skipping = true
    stop_tick_timer()
    mp.command("no-osd add chapter 1")
    
    local color = label_colors[state.active_label] or "0099FF"
    draw_feedback(state.active_label or "Chapter", color)
    clear_bindings()
    
    if state.timer then state.timer:kill() end
    state.timer = mp.add_timeout(2.0, function()
        state.is_skipping = false
        paint_canvas("") 
    end)
end

local function check_mouse_hover()
    local mx, my = mp.get_mouse_pos()
    local osd_w, osd_h = mp.get_osd_size()
    if not osd_w or osd_w == 0 then return false end
    local scale_x = 1920 / osd_w
    local scale_y = 1080 / osd_h
    local target_x = mx * scale_x
    local target_y = my * scale_y
    if target_x > 1400 and target_x < 1860 and target_y > 950 and target_y < 1010 then
        return true
    end
    return false
end

local function on_tick()
    if not opts.enabled or state.is_skipping then
        stop_tick_timer()
        return
    end

    local time = mp.get_property_number("time-pos")
    if not time or time < 0.5 then return end

    local current = mp.get_property_number("chapter")
    local list = state.cached_chapters
    local ch_entry = (current ~= nil and list) and list[current + 1] or nil
    local label = ch_entry and ch_entry.parsed_label or nil

    if not label then
        state.current_chapter_idx = -1
        paint_canvas("")
        clear_bindings()
        stop_tick_timer()
        return
    end

    if current ~= state.current_chapter_idx then
        state.current_chapter_idx = current
        state.remaining_seconds = opts.timeout
    end

    local is_paused = mp.get_property_bool("pause")
    if not is_paused then
        state.remaining_seconds = state.remaining_seconds - 0.1
    end

    if state.remaining_seconds > 0 then
        local is_hovering = check_mouse_hover()
        state.active_label = label
        draw_button(label, math.ceil(state.remaining_seconds), is_hovering)

        if is_hovering and not state.mouse_bound then
            mp.add_forced_key_binding("MBTN_LEFT", "mouse-skip-action", skip_action)
            state.mouse_bound = true
        elseif not is_hovering and state.mouse_bound then
            mp.remove_key_binding("mouse-skip-action")
            state.mouse_bound = false
        end

        if not state.key_bound then
            mp.add_forced_key_binding(opts.skip_key, "skip-intro-action", skip_action)
            state.key_bound = true
        end
    else
        paint_canvas("")
        clear_bindings()
        stop_tick_timer()
    end
end

state.tick_timer = mp.add_periodic_timer(0.1, on_tick)
state.tick_timer:stop()

local function evaluate_active_chapter()
    if not opts.enabled or opts.mode == "off" or state.is_skipping then return end
    local current = mp.get_property_number("chapter")
    local list = state.cached_chapters
    local ch_entry = (current ~= nil and list) and list[current + 1] or nil
    local label = ch_entry and ch_entry.parsed_label or nil
    if label then
        state.current_chapter_idx = current
        state.active_label = label

        -- Check if automatic skip is configured for this chapter type
        local should_auto_skip = (opts.mode == "auto_all" and (label == "OP" or label == "ED" or label == "Intro"))
            or (opts.mode == "auto_op" and (label == "OP" or label == "Intro"))

        if should_auto_skip and list and (current + 1) < #list then
            mp.add_timeout(0.2, function()
                if not state.is_skipping and opts.enabled then
                    state.active_label = label
                    skip_action()
                end
            end)
            return
        end

        state.remaining_seconds = opts.timeout
        state.tick_timer:resume()
    else
        state.current_chapter_idx = -1
        paint_canvas("")
        clear_bindings()
        stop_tick_timer()
    end
end

local function update_chapter_cache()
    local raw = mp.get_property_native("chapter-list") or {}
    for _, ch in ipairs(raw) do
        ch.parsed_label = get_chapter_label(ch.title)
    end
    state.cached_chapters = raw
    state.is_skipping = false
    state.current_chapter_idx = -1
    paint_canvas("")
    clear_bindings()
    evaluate_active_chapter()
end

local function apply_skip_mode(new_mode, notify)
    if not mode_labels[new_mode] then new_mode = "manual" end
    opts.mode = new_mode
    opts.enabled = (new_mode ~= "off")
    save_skip_conf()
    sync_skip_props()
    if not opts.enabled then
        paint_canvas("")
        state.is_skipping = false
        state.current_chapter_idx = -1
        clear_bindings()
        stop_tick_timer()
    else
        evaluate_active_chapter()
    end
    if notify then
        mp.commandv("script-message-to", "uosc", "dynamic-island-message", "⏭️ Salto OP/ED: " .. mode_labels[new_mode])
    end
end

mp.register_script_message("set-skip-intro-mode", function(mode)
    apply_skip_mode(mode, true)
end)

mp.register_script_message("cycle-skip-intro-mode", function()
    local order = {"manual", "auto_op", "auto_all", "off"}
    local idx = 1
    for i, m in ipairs(order) do
        if m == opts.mode then idx = i; break end
    end
    local next_m = order[(idx % #order) + 1]
    apply_skip_mode(next_m, true)
end)

mp.register_script_message("toggle-state", function(val)
    apply_skip_mode(val == "true" and "manual" or "off", false)
end)

mp.observe_property("chapter", "number", function()
    evaluate_active_chapter()
end)

mp.register_event("file-loaded", update_chapter_cache)
