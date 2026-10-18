local mp = require 'mp'
local utils = require 'mp.utils'
local msg = require 'mp.msg'
local options = {
    target_lang = "es",
    auto_translate = true,
    save_subtitles = true,
    active_style = "signature"
}

local script_dir = mp.get_script_directory()
if script_dir then
    package.path = script_dir .. "/?.lua;" .. script_dir .. "/?/init.lua;" .. package.path
end
local trad_dir = mp.command_native({"expand-path", "~~/scripts/traduccion"})
if trad_dir and trad_dir ~= "" then
    package.path = trad_dir .. "/?.lua;" .. trad_dir .. "/?/init.lua;" .. package.path
end

-- ─── Built-in & User Subtitle Style Profiles ──────────────────────────────────
local builtin_styles = {
    native = {
        name = "🚫 Off Custom (Estilo Nativo del Video)",
        hint = "Sin modificaciones externas (Respeta ASS/Tipografía original)",
        is_native = true
    },
    signature = {
        name = "✨ Firma Personalizada (Hey Comic)",
        hint = "Blanco suave + Borde azul marino + Desenfoque",
        font = "Hey Comic", size = 40, color = "#B5FFFFFF",
        border_color = "#AA000080", shadow_color = "#AA000000",
        border_size = 3.0, shadow_offset = 3.0, spacing = 0.5, pos = 100,
        gauss = 0.9, blur = 0.9, gray = "yes", override = "force",
        border_style = "outline-and-shadow", back_color = "#00000000"
    },
    anime = {
        name = "🎌 Anime / Fansub Nítido",
        hint = "Alta definición + Borde oscuro + Respeta colores de carteles",
        font = "Segoe UI", size = 42, color = "#FFFFFFFF",
        border_color = "#EE10121C", shadow_color = "#90000000",
        border_size = 2.8, shadow_offset = 2.0, spacing = 0.4, pos = 99,
        gauss = 0.0, blur = 0.0, gray = "no", override = "scale",
        border_style = "outline-and-shadow", back_color = "#00000000"
    },
    cinema = {
        name = "🎬 Películas / Cine Clásico",
        hint = "Amarillo cálido de cine + Borde negro limpio",
        font = "Segoe UI", size = 42, color = "#FFFFE055",
        border_color = "#EE000000", shadow_color = "#90000000",
        border_size = 2.4, shadow_offset = 2.0, spacing = 0.3, pos = 98,
        gauss = 0.0, blur = 0.0, gray = "no", override = "force",
        border_style = "outline-and-shadow", back_color = "#00000000"
    },
    series = {
        name = "📺 Series / Streaming (Caja Opaca)",
        hint = "Texto blanco sobre caja semitransparente oscura",
        font = "Segoe UI", size = 40, color = "#FFFFFFFF",
        border_color = "#B0101218", shadow_color = "#00000000",
        border_size = 4.0, shadow_offset = 0.0, spacing = 0.3, pos = 96,
        gauss = 0.0, blur = 0.0, gray = "no", override = "force",
        border_style = "background-box", back_color = "#B0101218"
    },
    kdrama = {
        name = "🌸 K-Drama / Lectura Cómoda",
        hint = "Blanco marfil cálido + Mayor tamaño y espaciado",
        font = "Trebuchet MS", size = 44, color = "#FFFDFBF0",
        border_color = "#DD181A24", shadow_color = "#88000000",
        border_size = 2.6, shadow_offset = 2.0, spacing = 0.7, pos = 98,
        gauss = 0.2, blur = 0.2, gray = "no", override = "force",
        border_style = "outline-and-shadow", back_color = "#00000000"
    }
}

local builtin_order = {"native", "signature", "anime", "cinema", "series", "kdrama"}
local user_styles = {} -- array of {id, name, font, size, color, border_color, shadow_color, border_size, shadow_offset, spacing, pos, gauss, blur, gray, override, border_style, back_color}

local current_style_state = {
    font = "Hey Comic", size = 40, color = "#B5FFFFFF",
    border_color = "#AA000080", shadow_color = "#AA000000",
    border_size = 3.0, shadow_offset = 3.0, spacing = 0.5, pos = 100,
    gauss = 0.9, blur = 0.9, gray = "yes", override = "force",
    border_style = "outline-and-shadow", back_color = "#00000000"
}

local script_opts_dir = mp.command_native({"expand-path", "~~/script-opts"})
local opt_file = mp.command_native({"expand-path", "~~/script-opts/traduccion.conf"})
local profiles_file = mp.command_native({"expand-path", "~~/script-opts/sub_profiles.json"})

local function ensure_opts_dir()
    local info = utils.file_info(script_opts_dir)
    if not info or not info.is_dir then
        local is_win = package.config:sub(1, 1) == "\\"
        if is_win then
            local clean_dir = (script_opts_dir:gsub("/", "\\"))
            mp.command_native({
                name = "subprocess", playback_only = false,
                args = {"cmd.exe", "/c", "mkdir", clean_dir},
                capture_stdout = true, capture_stderr = true
            })
        else
            mp.command_native({
                name = "subprocess", playback_only = false,
                args = {"mkdir", "-p", script_opts_dir},
                capture_stdout = true, capture_stderr = true
            })
        end
    end
end

local function load_user_styles()
    local f = io.open(profiles_file, "r")
    if not f then return end
    local raw = f:read("*all")
    f:close()
    if raw and raw ~= "" then
        local parsed = utils.parse_json(raw)
        if type(parsed) == "table" then
            user_styles = parsed
        end
    end
end

local function save_user_styles()
    ensure_opts_dir()
    local json = utils.format_json(user_styles)
    if json then
        local f = io.open(profiles_file, "w")
        if f then
            f:write(json)
            f:close()
        end
    end
end

local function apply_style_table(st)
    if not st then return end
    if st.is_native then
        mp.set_property("sub-ass-override", "no")
        mp.set_property("sub-ass-force-margins", "no")
        mp.set_property("sub-use-margins", "no")
        mp.set_property("sub-ass-style-overrides", "")
        mp.set_property("sub-gray", "no")
        mp.set_property_number("sub-gauss", 0)
        mp.set_property_number("sub-blur", 0)
        mp.set_property("sub-border-style", "outline-and-shadow")
        mp.set_property("sub-back-color", "#00000000")
        mp.set_property_number("sub-pos", 100)
        return
    end

    for k, v in pairs(st) do
        if k ~= "name" and k ~= "hint" and k ~= "id" and k ~= "is_native" then
            current_style_state[k] = v
        end
    end

    mp.set_property("sub-ass-override", current_style_state.override or "force")
    mp.set_property("sub-ass-force-margins", "yes")
    mp.set_property("sub-use-margins", "yes")
    mp.set_property("sub-font", current_style_state.font or "Hey Comic")
    mp.set_property_number("sub-font-size", tonumber(current_style_state.size) or 40)
    mp.set_property("sub-color", current_style_state.color or "#B5FFFFFF")
    mp.set_property("sub-border-color", current_style_state.border_color or "#AA000080")
    mp.set_property("sub-shadow-color", current_style_state.shadow_color or "#AA000000")
    mp.set_property_number("sub-border-size", tonumber(current_style_state.border_size) or 3.0)
    mp.set_property_number("sub-shadow-offset", tonumber(current_style_state.shadow_offset) or 2.0)
    mp.set_property_number("sub-spacing", tonumber(current_style_state.spacing) or 0.5)
    mp.set_property_number("sub-pos", tonumber(current_style_state.pos) or 100)
    mp.set_property_number("sub-gauss", tonumber(current_style_state.gauss) or 0)
    mp.set_property_number("sub-blur", tonumber(current_style_state.blur) or 0)
    mp.set_property("sub-gray", current_style_state.gray or "no")
    mp.set_property("sub-border-style", current_style_state.border_style or "outline-and-shadow")
    mp.set_property("sub-back-color", current_style_state.back_color or "#00000000")
    mp.set_property("sub-ass-style-overrides", (tonumber(current_style_state.blur) or 0) > 0 and "blur=1" or "")
end

local function find_style_by_id(style_id)
    if builtin_styles[style_id] then return builtin_styles[style_id] end
    for _, us in ipairs(user_styles) do
        if us.id == style_id then return us end
    end
    return nil
end

local function load_options()
    load_user_styles()
    local f = io.open(opt_file, "r")
    if f then
        for line in f:lines() do
            local k, v = line:match("^%s*([^=]+)%s*=%s*(.-)%s*$")
            if k == "target_lang" then options.target_lang = v end
            if k == "auto_translate" then options.auto_translate = (v == "yes") end
            if k == "save_subtitles" then options.save_subtitles = (v == "yes") end
            if k == "active_style" then options.active_style = v end
        end
        f:close()
    end
    local st = find_style_by_id(options.active_style)
    if st then apply_style_table(st) end
end
load_options()

local function notify(text, duration)
    mp.commandv("script-message-to", "uosc", "dynamic-island-message", text, tostring(duration or 2))
end

local function save_options()
    ensure_opts_dir()
    local f = io.open(opt_file, "w")
    if f then
        f:write("target_lang="    .. options.target_lang .. "\n")
        f:write("auto_translate=" .. (options.auto_translate and "yes" or "no") .. "\n")
        f:write("save_subtitles=" .. (options.save_subtitles and "yes" or "no") .. "\n")
        f:write("active_style="   .. (options.active_style or "signature") .. "\n")
        f:close()
    end
end

-- ─── Language helpers ──────────────────────────────────────────────────────────
local lang_map = {
    eng="en", fre="fr", fra="fr", ger="de", deu="de", ita="it", 
    spa="es", por="pt", jpn="ja", kor="ko", zho="zh", chi="zh",
    rus="ru", ara="ar", hin="hi", tur="tr", pol="pl", dut="nl",
    nld="nl", swe="sv"
}

local function normalize_lang(l)
    if not l then return "unk" end
    l = l:lower()
    local base = l:match("^([a-z]+)") or l
    if lang_map[base] then return lang_map[base] end
    return base:sub(1, 2)
end

local function matches_lang(lang, pref)
    if not lang or not pref then return false end
    return normalize_lang(lang) == normalize_lang(pref)
end

local function track_matches_lang(t, pref)
    if not t or not pref then return false end
    if matches_lang(t.lang, pref) then return true end

    local target_norm = normalize_lang(pref)
    local title = (t.title or ""):lower()

    if target_norm == "es" and (title:match("español") or title:match("spanish") or title:match("castellano") or title:match("%[es%]") or title:match("%(es%)")) then
        return true
    elseif target_norm == "en" and (title:match("english") or title:match("inglés") or title:match("%[en%]") or title:match("%(en%)")) then
        return true
    end

    if t.external and t["external-filename"] then
        local fn = t["external-filename"]:lower()
        if fn:match("%." .. target_norm .. "%.ass$") or fn:match("%." .. target_norm .. "%.srt$")
           or fn:match("%-" .. target_norm .. "%.ass$") or fn:match("%-" .. target_norm .. "%.srt$")
           or fn:match("_" .. target_norm .. "%.ass$") or fn:match("_" .. target_norm .. "%.srt$")
           or fn:match("%." .. pref:lower() .. "%.ass$") or fn:match("%." .. pref:lower() .. "%.srt$") then
            return true
        end
    end
    return false
end

local function is_forced_track(t)
    if not t then return false end
    if t.forced then return true end
    local title = (t.title or ""):lower()
    if title:match("forced") or title:match("forzad") or title:match("signs") then
        return true
    end
    return false
end

local function get_best_source_track()
    local tracks = mp.get_property_native("track-list") or {}
    -- 1. Try currently selected sub if it is not in target_lang and not forced
    for _, t in ipairs(tracks) do
        if t.type == "sub" and t.selected and not track_matches_lang(t, options.target_lang) and not is_forced_track(t) then
            return t
        end
    end
    -- 2. Try English full track (not forced)
    for _, t in ipairs(tracks) do
        if t.type == "sub" and not is_forced_track(t) then
            local lang = (t.lang or ""):lower()
            if lang == "en" or lang == "eng" then return t end
        end
    end
    -- 3. Any non-forced sub that is not target_lang
    for _, t in ipairs(tracks) do
        if t.type == "sub" and not is_forced_track(t) and not track_matches_lang(t, options.target_lang) then
            return t
        end
    end
    -- 4. Fallback: any non-forced sub
    for _, t in ipairs(tracks) do
        if t.type == "sub" and not is_forced_track(t) then
            return t
        end
    end
    return nil
end

local backend = require "backends.google"
local current_session = 0
local is_translating = false
local translate_timeout = nil

local function new_session()
    current_session = backend.new_session()
    if translate_timeout then
        translate_timeout:kill()
        translate_timeout = nil
    end
end

local refresh_subtitles_menu = nil

local function translate_track(track, target_lang, as_secondary, dual_with_source)
    if is_translating then
        msg.warn("Translation already in progress, ignoring duplicate request")
        return
    end
    is_translating = true
    local session_id = current_session
    local mode_tag = as_secondary and " (Secundario Arriba)" or (dual_with_source and " (Modo Bilingüe)" or "")
    msg.info("Starting translation: track " .. track.id .. " → " .. target_lang .. mode_tag .. " [Session " .. session_id .. "]")
    notify("⏳ Traduciendo subtítulo a " .. target_lang:upper() .. mode_tag .. "...", 3)

    if translate_timeout then translate_timeout:kill() end
    translate_timeout = mp.add_timeout(60, function()
        if is_translating and current_session == session_id then
            is_translating = false
            notify("⚠️ Traducción cancelada: tiempo límite superado", 4)
        end
    end)

    local translator = require "translator"
    translator.start_translation(track, target_lang, function(success, result_path)
        if current_session ~= session_id then
            msg.info("Translation completed for obsolete session " .. session_id .. ", ignoring result")
            return
        end
        is_translating = false
        if translate_timeout then
            translate_timeout:kill()
            translate_timeout = nil
        end

        if success then
            msg.info("Translation done: " .. result_path)
            local tracks = mp.get_property_native("track-list") or {}
            local found_sid = nil
            for _, t in ipairs(tracks) do
                if t.type == "sub" and t.external and t["external-filename"] == result_path then
                    found_sid = t.id
                    break
                end
            end

            if as_secondary then
                if not found_sid then
                    mp.commandv("sub-add", result_path, "auto", "Traducido (" .. target_lang:upper() .. ")", target_lang)
                    local updated_tracks = mp.get_property_native("track-list") or {}
                    for _, t in ipairs(updated_tracks) do
                        if t.type == "sub" and t.external and t["external-filename"] == result_path then
                            found_sid = t.id
                            break
                        end
                    end
                end
                if found_sid then
                    mp.commandv("set", "secondary-sid", found_sid)
                    notify("✅ Subtítulo secundario (" .. target_lang:upper() .. ") activado arriba", 3)
                end
            else
                if found_sid then
                    mp.commandv("set", "sid", found_sid)
                else
                    mp.commandv("sub-add", result_path, "select")
                end
                if dual_with_source and track and track.id then
                    mp.commandv("set", "secondary-sid", track.id)
                    notify("✅ Modo Bilingüe activo (Original arriba + " .. target_lang:upper() .. " abajo)", 3)
                else
                    notify("✅ Traducción completada (" .. target_lang:upper() .. ")", 3)
                end
            end
            if refresh_subtitles_menu then refresh_subtitles_menu(false) end
        else
            msg.error("Translation failed for track " .. track.id)
            notify("❌ Error al traducir subtítulo", 3)
        end
    end, session_id, options.save_subtitles, function(done, total)
        local pct = (total > 0) and math.floor((done / total) * 100) or 0
        if pct == 50 then
            notify("⏳ Traduciendo subtítulo (50%)...", 2)
        end
    end)
end

local function clear_cache()
    local cache_dir = mp.command_native({"expand-path", "~~/cache/traduccion"})
    local count = 0
    local files = utils.readdir(cache_dir, "files")
    if files then
        for _, fname in ipairs(files) do
            if fname:match("%.ass$") or fname:match("%.srt$") or fname:match("%.txt$") then
                local full = utils.join_path(cache_dir, fname)
                if os.remove(full) then count = count + 1 end
            end
        end
    end
    notify("🗑 Caché limpiada (" .. count .. " archivos eliminados)", 3)
end

-- Purge orphaned temporary files (mpv_tr_*.txt, *.src.ass) left by interrupted sessions
local function cleanup_orphaned_temps()
    local cache_dir = mp.command_native({"expand-path", "~~/cache/traduccion"})
    local files = utils.readdir(cache_dir, "files")
    if files then
        for _, fname in ipairs(files) do
            if fname:match("^mpv_tr_.*%.txt$") or fname:match("%.src%.ass$") then
                os.remove(utils.join_path(cache_dir, fname))
            end
        end
    end
end
cleanup_orphaned_temps()

mp.register_event("file-loaded", function()
    new_session()
    is_translating = false
    local st = find_style_by_id(options.active_style)
    if st then apply_style_table(st) end

    if not options.auto_translate then return end
    mp.add_timeout(1.2, function()
        local tracks = mp.get_property_native("track-list") or {}
        local current_sid = mp.get_property_number("sid")

        -- 1. Check audio language: if audio is already target_lang, skip
        for _, t in ipairs(tracks) do
            if t.type == "audio" and t.selected and track_matches_lang(t, options.target_lang) then
                msg.info("Auto-translate: audio is already " .. options.target_lang .. ", skipping auto-translation")
                return
            end
        end

        -- 2. Check if currently selected subtitle is ALREADY a valid, non-forced target_lang sub
        for _, t in ipairs(tracks) do
            if t.type == "sub" and t.selected and track_matches_lang(t, options.target_lang) and not is_forced_track(t) then
                msg.info("Auto-translate: currently selected sub " .. t.id .. " matches " .. options.target_lang)
                return
            end
        end

        -- 3. Check if any existing non-forced sub matches target_lang
        local target_track = nil
        for _, t in ipairs(tracks) do
            if t.type == "sub" and track_matches_lang(t, options.target_lang) and not is_forced_track(t) then
                target_track = t
                break
            end
        end

        if target_track then
            if current_sid ~= target_track.id then
                msg.info("Auto-translate: found existing full track " .. target_track.id .. " matching " .. options.target_lang)
                mp.commandv("set", "sid", target_track.id)
            end
            return
        end

        -- 4. Check if translated subtitle file already exists on disk next to video or in cache
        local video_path = mp.get_property("path")
        if video_path then
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

            -- Helper to select existing track or add if not in track-list
            local function select_or_add_sub(path)
                local cur_tracks = mp.get_property_native("track-list") or {}
                for _, t in ipairs(cur_tracks) do
                    if t.type == "sub" and t.external and t["external-filename"] then
                        if t["external-filename"] == path or t["external-filename"]:find(video_base .. "." .. options.target_lang, 1, true) then
                            msg.info("Subtitle track already present in track-list: " .. t.id)
                            mp.commandv("set", "sid", t.id)
                            return
                        end
                    end
                end
                mp.commandv("sub-add", path, "select")
            end

            -- Check next to video (.es.ass)
            if video_dir and video_dir ~= "" then
                local sub_on_disk = utils.join_path(video_dir, video_base .. "." .. options.target_lang .. ".ass")
                local f = io.open(sub_on_disk, "rb")
                if f then
                    f:close()
                    msg.info("Auto-translate: found existing subtitle on disk: " .. sub_on_disk)
                    select_or_add_sub(sub_on_disk)
                    return
                end
            end

            -- Check in cache (.es.ass)
            local cache_dir = mp.command_native({"expand-path", "~~/cache/traduccion"})
            local sub_in_cache = utils.join_path(cache_dir, video_base .. "." .. options.target_lang .. ".ass")
            local fc = io.open(sub_in_cache, "rb")
            if fc then
                fc:close()
                msg.info("Auto-translate: found existing subtitle in cache: " .. sub_in_cache)
                select_or_add_sub(sub_in_cache)
                return
            end
        end

        -- 5. No full target_lang track found. Translate best source track
        local src = get_best_source_track()
        if src then
            msg.info("Auto-translate: no full target sub found, translating source track " .. src.id)
            translate_track(src, options.target_lang)
        end
    end)
end)

local langs_catalog = {
    {code="es", name="Español"}, {code="en", name="Inglés"}, {code="ja", name="Japonés"}, {code="ko", name="Coreano"},
    {code="fr", name="Francés"}, {code="de", name="Alemán"}, {code="it", name="Italiano"}, {code="pt", name="Portugués"},
    {code="zh", name="Chino"}, {code="ru", name="Ruso"}, {code="ar", name="Árabe"}, {code="hi", name="Hindi"},
    {code="tr", name="Turco"}, {code="pl", name="Polaco"}, {code="nl", name="Neerlandés"}, {code="sv", name="Sueco"},
}

local function build_style_customizer_submenu()
    local style_items = {
        {
            title = "── Perfiles de Estilo de Subtítulos ──────────",
            hint = "Predefinidos y de usuario",
            muted = true
        }
    }

    -- 1. Built-in presets (including Off Custom / Native)
    for _, key in ipairs(builtin_order) do
        local st = builtin_styles[key]
        local is_act = (options.active_style == key)
        table.insert(style_items, {
            title = (is_act and "● " or "○ ") .. st.name,
            hint = st.hint,
            active = is_act,
            value = "script-message sub_action set_style:" .. key,
            keep_open = true
        })
    end

    -- 2. User-created custom profiles
    if #user_styles > 0 then
        table.insert(style_items, {
            title = "── Mis Perfiles Guardados ────────────────────",
            hint = tostring(#user_styles) .. " perfiles",
            muted = true
        })
        for _, us in ipairs(user_styles) do
            local is_act = (options.active_style == us.id)
            table.insert(style_items, {
                title = (is_act and "● ⭐ " or "○ ⭐ ") .. us.name,
                hint = string.format("%s · %dpx", us.font or "Fuente", tonumber(us.size) or 40),
                active = is_act,
                value = "script-message sub_action set_style:" .. us.id,
                keep_open = true
            })
        end
    end

    style_items[#style_items].separator = true

    -- 3. Live Visual Adjustments
    local cur_size = tonumber(current_style_state.size) or 40
    local cur_pos = tonumber(current_style_state.pos) or 100
    local cur_font = current_style_state.font or "Hey Comic"

    table.insert(style_items, {
        id = "sub_style_size_menu",
        title = "📏 Tamaño de Fuente",
        hint = tostring(cur_size) .. " px",
        items = {
            {title = "🔼 Aumentar (+4 px)", value = "script-message sub_action mod_size:4", keep_open = true},
            {title = "🔼 Aumentar (+2 px)", value = "script-message sub_action mod_size:2", keep_open = true},
            {title = "🔽 Reducir (-2 px)",  value = "script-message sub_action mod_size:-2", keep_open = true},
            {title = "🔽 Reducir (-4 px)",  value = "script-message sub_action mod_size:-4", keep_open = true, separator = true},
            {title = "Pequeño (32 px)",     value = "script-message sub_action exact_size:32", keep_open = true},
            {title = "Mediano (36 px)",     value = "script-message sub_action exact_size:36", keep_open = true},
            {title = "Estándar (40 px)",    value = "script-message sub_action exact_size:40", keep_open = true},
            {title = "Grande (44 px)",      value = "script-message sub_action exact_size:44", keep_open = true},
            {title = "Extra Grande (50 px)",value = "script-message sub_action exact_size:50", keep_open = true},
            {title = "Cine / Sala (56 px)", value = "script-message sub_action exact_size:56", keep_open = true},
        }
    })

    table.insert(style_items, {
        id = "sub_style_color_menu",
        title = "🎨 Color de Texto",
        hint = current_style_state.color or "#B5FFFFFF",
        items = {
            {title = "⚪ Blanco Suave (Firma)",   hint = "#B5FFFFFF", value = "script-message sub_action set_color:#B5FFFFFF", keep_open = true},
            {title = "⚪ Blanco Puro Brillante",  hint = "#FFFFFFFF", value = "script-message sub_action set_color:#FFFFFFFF", keep_open = true},
            {title = "🟡 Amarillo Clásico Cine",  hint = "#FFFFE055", value = "script-message sub_action set_color:#FFFFE055", keep_open = true},
            {title = "🍦 Crema / Marfil Suave",   hint = "#FFFDFBF0", value = "script-message sub_action set_color:#FFFDFBF0", keep_open = true},
            {title = "🔵 Cian Confort Visual",    hint = "#FF88EEFF", value = "script-message sub_action set_color:#FF88EEFF", keep_open = true},
            {title = "🟢 Verde Menta Suave",      hint = "#FF98FF98", value = "script-message sub_action set_color:#FF98FF98", keep_open = true},
            {title = "🌸 Rosa Pastel",            hint = "#FFFFB8E0", value = "script-message sub_action set_color:#FFFFB8E0", keep_open = true},
        }
    })

    table.insert(style_items, {
        id = "sub_style_border_menu",
        title = "🖼️ Contorno y Caja de Fondo",
        hint = (current_style_state.border_style == "background-box") and "Caja Opaca" or "Contorno",
        items = {
            {title = "🔵 Contorno Azul Marino (Firma + Glow)", value = "script-message sub_action set_box:signature_blue", keep_open = true},
            {title = "⚫ Contorno Negro Nítido (Estándar)",    value = "script-message sub_action set_box:clean_black", keep_open = true},
            {title = "⚫ Contorno Negro Grueso (Alto Contraste)", value = "script-message sub_action set_box:heavy_black", keep_open = true},
            {title = "⬛ Caja Semitransparente (Streaming)",    value = "script-message sub_action set_box:streaming_box", keep_open = true},
        }
    })

    table.insert(style_items, {
        id = "sub_style_font_menu",
        title = "🔤 Tipografía (Fuente)",
        hint = cur_font,
        items = {
            {title = "Hey Comic (Firma Original)", value = "script-message sub_action set_font:Hey Comic", keep_open = true},
            {title = "Segoe UI (Moderna y Limpia)", value = "script-message sub_action set_font:Segoe UI", keep_open = true},
            {title = "Trebuchet MS (Cine / Doramas)", value = "script-message sub_action set_font:Trebuchet MS", keep_open = true},
            {title = "Arial (Clásica Universal)", value = "script-message sub_action set_font:Arial", keep_open = true},
            {title = "Verdana (Alta Legibilidad)", value = "script-message sub_action set_font:Verdana", keep_open = true},
            {title = "Tahoma (Compacta)", value = "script-message sub_action set_font:Tahoma", keep_open = true},
        }
    })

    table.insert(style_items, {
        id = "sub_style_pos_menu",
        title = "📐 Posición Vertical",
        hint = tostring(cur_pos) .. "%",
        separator = true,
        items = {
            {title = "⬆️ Subir subtítulos (-2%)", value = "script-message sub_action mod_pos:-2", keep_open = true},
            {title = "⬆️ Subir rápido (-5%)",     value = "script-message sub_action mod_pos:-5", keep_open = true},
            {title = "⬇️ Bajar subtítulos (+2%)", value = "script-message sub_action mod_pos:2", keep_open = true},
            {title = "⬇️ Bajar rápido (+5%)",     value = "script-message sub_action mod_pos:5", keep_open = true},
            {title = "⏹️ Posición base (100%)",  value = "script-message sub_action exact_pos:100", keep_open = true},
        }
    })

    -- 4. Save / Manage User Custom Profiles
    table.insert(style_items, {
        title = "➕ Guardar ajustes actuales como nuevo perfil...",
        hint = "Escribir nombre o elegir categoría",
        value = "script-message open-sub-profile-saver"
    })

    if #user_styles > 0 then
        local del_items = {}
        for _, us in ipairs(user_styles) do
            table.insert(del_items, {
                title = "🗑️ Eliminar: " .. us.name,
                hint = us.id,
                value = "script-message sub_action delete_style:" .. us.id,
                keep_open = true
            })
        end
        table.insert(style_items, {
            id = "sub_style_delete_menu",
            title = "🗑️ Eliminar un perfil guardado...",
            hint = tostring(#user_styles) .. " disponibles",
            items = del_items
        })
    end

    return style_items
end

local function build_unified_subtitles_menu(force_open)
    local tracks = mp.get_property_native("track-list") or {}
    local current_sid = mp.get_property_number("sid")
    local cur_sec_sid = mp.get_property_number("secondary-sid")

    local items = {}
    local main_sub_items = {}
    local has_sub_tracks = false
    local current_track_obj = nil
    local other_tracks = {}

    -- Desactivar subtítulos
    local no_subs_active = (current_sid == nil)
    table.insert(main_sub_items, {
        title = (no_subs_active and "● " or "○ ") .. "🚫 Desactivar subtítulos",
        hint = no_subs_active and "Activo" or "",
        active = no_subs_active,
        value = "script-message sub_action disable",
        keep_open = true
    })

    -- Cargar subtítulo externo
    table.insert(main_sub_items, {
        title = "📂 Cargar subtítulo externo...",
        hint = ".ass, .srt, .vtt",
        value = "script-binding uosc/load-subtitles",
        separator = true
    })

    for _, t in ipairs(tracks) do
        if t.type == "sub" then
            has_sub_tracks = true
            local is_selected = (current_sid ~= nil and t.id == current_sid)
            if is_selected then current_track_obj = t end

            local lang_hint = (t.lang and t.lang:upper() or "UNK")
            local is_translated = false
            if t.external and t["external-filename"] then
                local fn = t["external-filename"]:lower()
                if fn:find("%." .. options.target_lang:lower() .. "%.ass$") or fn:find("cache[/\\]traduccion") then
                    is_translated = true
                end
            end

            local flags = {}
            if is_translated then table.insert(flags, "Traducido") end
            if t.external and not is_translated then table.insert(flags, "Ext") end
            if t.forced then table.insert(flags, "Forzado") end
            if t.default then table.insert(flags, "Predet.") end
            if cur_sec_sid and t.id == cur_sec_sid and not is_selected then
                table.insert(flags, "Secundario")
            end
            local flag_str = #flags > 0 and (" [" .. table.concat(flags, ", ") .. "]") or ""

            local base_name = t.title and (lang_hint .. " - " .. t.title) or (lang_hint .. " (Pista " .. t.id .. ")")
            local track_name = is_translated and ("🔤 [Traducido] " .. base_name) or base_name

            table.insert(main_sub_items, {
                title = (is_selected and "● " or "○ ") .. track_name,
                hint = "Pista " .. t.id .. flag_str,
                active = is_selected,
                value = "script-message sub_action select:" .. t.id,
                keep_open = true
            })

            if not is_selected then
                table.insert(other_tracks, {
                    title = "Traducir " .. track_name,
                    hint = "→ " .. options.target_lang:upper(),
                    value = "script-message sub_action translate_track:" .. t.id
                })
            end
        end
    end

    if not has_sub_tracks then
        table.insert(main_sub_items, {
            title = "⚠️ No hay pistas de subtítulo en este video",
            muted = true,
            value = "ignore"
        })
    end

    -- ── Subtítulo Secundario / Modo Bilingüe Inteligente ──────────────────
    local sec_items = {}
    table.insert(sec_items, {
        title = (cur_sec_sid == nil and "● " or "○ ") .. "🚫 Desactivar subtítulo secundario",
        hint = cur_sec_sid == nil and "Inactivo" or "",
        active = (cur_sec_sid == nil),
        value = "script-message sub_action set_secondary:no",
        keep_open = true
    })

    table.insert(sec_items, {
        title = "⚡ Activar Dual Sub Automático (Original Arriba + " .. options.target_lang:upper() .. " Abajo)",
        hint = "Traduce si falta el idioma",
        value = "script-message sub_action smart_dual_sub",
        separator = true
    })

    -- Traducir y colocar arriba si el idioma buscado no está en el video
    local sec_translate_langs = {}
    for _, l in ipairs(langs_catalog) do
        table.insert(sec_translate_langs, {
            title = "🌐 Traducir y mostrar arriba en: " .. l.name,
            hint = l.code:upper(),
            value = "script-message sub_action translate_secondary:" .. l.code
        })
    end

    table.insert(sec_items, {
        id = "sec_translate_lang_menu",
        title = "🌐 ¿No está el idioma? Traducir para mostrar arriba...",
        hint = "Generar pista secundaria",
        items = sec_translate_langs,
        separator = true
    })

    local sec_track_obj = nil
    for _, t in ipairs(tracks) do
        if t.type == "sub" then
            local is_cur_sec = (cur_sec_sid == t.id)
            if is_cur_sec then sec_track_obj = t end
            local t_lang = t.lang and t.lang:upper() or "UND"
            local t_name = t.title or ("Pista " .. t.id)
            table.insert(sec_items, {
                title = (is_cur_sec and "● " or "○ ") .. t_name,
                hint = t_lang .. (t.codec and (" [" .. t.codec .. "]") or ""),
                active = is_cur_sec,
                value = "script-message sub_action set_secondary:" .. t.id,
                keep_open = true
            })
        end
    end

    local cur_primary_hint = "DESACTIVADO"
    if current_track_obj then
        local lang = current_track_obj.lang and current_track_obj.lang:upper() or "UND"
        cur_primary_hint = lang .. " (Pista " .. current_track_obj.id .. ")"
    end

    local cur_sec_hint = "DESACTIVADO"
    if sec_track_obj then
        local lang = sec_track_obj.lang and sec_track_obj.lang:upper() or "UND"
        cur_sec_hint = lang .. " (Pista " .. sec_track_obj.id .. ")"
    end

    -- ── Entradas de Nivel Superior ────────────────────────────────────────
    table.insert(items, {
        id = "sub_primary_menu",
        title = "💬 Subtítulo principal (Abajo)",
        hint = cur_primary_hint,
        items = main_sub_items
    })

    table.insert(items, {
        id = "sub_secondary_menu",
        title = "👥 Subtítulo secundario / Dual Sub (Arriba)",
        hint = cur_sec_hint,
        items = sec_items
    })

    -- Estilo y Perfiles de Subtítulos
    local active_st = find_style_by_id(options.active_style)
    local style_label = active_st and active_st.name:gsub("^[^%w]+%s*", "") or "Personalizado"
    table.insert(items, {
        id = "sub_style_menu",
        title = "🎨 Estilo y Perfiles de Subtítulos",
        hint = style_label,
        items = build_style_customizer_submenu()
    })

    -- Sincronización Rápida (Delay)
    local sub_delay = mp.get_property_number("sub-delay", 0)
    local delay_str = math.abs(sub_delay) < 0.005 and "0.00s (Exacto)" or string.format("%+.2fs", sub_delay)
    table.insert(items, {
        id = "sub_sync_menu",
        title = "⏱️ Sincronización de Subtítulos (Delay)",
        hint = delay_str,
        separator = true,
        items = {
            {title = "⏩ Adelantar +0.50s", value = "script-message sub_action add_delay:0.5", keep_open = true},
            {title = "▶️ Adelantar +0.10s", value = "script-message sub_action add_delay:0.1", keep_open = true},
            {title = "⏹️ Restablecer a 0.00s (Original)", value = "script-message sub_action reset_delay", keep_open = true},
            {title = "◀️ Retrasar -0.10s",  value = "script-message sub_action add_delay:-0.1", keep_open = true},
            {title = "⏪ Retrasar -0.50s",  value = "script-message sub_action add_delay:-0.5", keep_open = true},
        }
    })

    -- 2. Herramientas de Traducción Automática
    local cur_lang_str = current_track_obj and (current_track_obj.lang and current_track_obj.lang:upper() or "ACTUAL") or "AUTO"
    table.insert(items, {
        title = "⚡ Traducir subtítulo actual ahora",
        hint = cur_lang_str .. " → " .. options.target_lang:upper(),
        value = "script-message sub_action translate_current"
    })

    if #other_tracks > 0 then
        table.insert(items, {
            id = "sub_translate_other_menu",
            title = "🎯 Traducir otra pista específica",
            hint = "Elegir pista",
            items = other_tracks
        })
    end

    local lang_items = {}
    for _, l in ipairs(langs_catalog) do
        local is_tgt = (options.target_lang == l.code)
        table.insert(lang_items, {
            title = (is_tgt and "● " or "○ ") .. l.name,
            hint = l.code:upper(),
            active = is_tgt,
            value = "script-message sub_action set_lang:" .. l.code,
            keep_open = true
        })
    end

    table.insert(items, {
        id = "sub_lang_menu",
        title = "🌐 Idioma destino de traducción",
        hint = options.target_lang:upper(),
        items = lang_items
    })

    table.insert(items, {
        title = (options.auto_translate and "● " or "○ ") .. "🌐 Traducción automática al abrir",
        hint = options.auto_translate and "ACTIVADA" or "DESACTIVADA",
        active = options.auto_translate,
        value = "script-message sub_action toggle_auto",
        keep_open = true
    })

    table.insert(items, {
        title = (options.save_subtitles and "● " or "○ ") .. "💾 Guardar subtítulo traducido",
        hint = options.save_subtitles and "En carpeta (.ass)" or "Solo en caché",
        active = options.save_subtitles,
        value = "script-message sub_action toggle_save",
        keep_open = true
    })

    table.insert(items, {
        title = "↩ Restaurar subtítulo original",
        hint = "Quitar traducción",
        value = "script-message sub_action restore_original",
        keep_open = true
    })

    table.insert(items, {
        title = "🗑 Limpiar caché de traducciones",
        value = "script-message sub_action clear_cache",
        keep_open = true
    })

    local menu_json = utils.format_json({
        type = "subtitles_menu",
        title = "Subtítulos, Estilo & Traducción",
        footnote = "Pistas, Modo Bilingüe, Perfiles Visuales y Traducción",
        items = items
    })

    if force_open == false then
        mp.commandv("script-message-to", "uosc", "update-menu", menu_json)
    else
        mp.commandv("script-message-to", "uosc", "open-menu", menu_json)
    end
end
refresh_subtitles_menu = build_unified_subtitles_menu

-- ── Palette Menu to Save Custom User Subtitle Profile ─────────────────────────
mp.register_script_message("open-sub-profile-saver", function()
    local save_items = {
        {
            title = "⌨️ Escribe arriba el nombre de tu perfil y pulsa ENTER",
            hint = "Ej: Mi Anime, Doramas Noche, Cine 4K...",
            muted = true,
            selectable = false,
            separator = true
        },
        {title = "💾 Guardar como: Mi Perfil Anime",     hint = "Categoría rápida", value = "script-message sub_style_save_custom Mi Perfil Anime"},
        {title = "💾 Guardar como: Mi Perfil Series",    hint = "Categoría rápida", value = "script-message sub_style_save_custom Mi Perfil Series"},
        {title = "💾 Guardar como: Mi Perfil Películas", hint = "Categoría rápida", value = "script-message sub_style_save_custom Mi Perfil Películas"},
        {title = "💾 Guardar como: Mi Perfil K-Drama",   hint = "Categoría rápida", value = "script-message sub_style_save_custom Mi Perfil K-Drama"},
        {title = "💾 Guardar como: Lectura Nocturna",    hint = "Categoría rápida", value = "script-message sub_style_save_custom Lectura Nocturna"},
        {title = "↩ Volver al menú de Subtítulos",       value = "script-message open-subtitles-menu", separator = true},
    }
    local json = utils.format_json({
        type = "sub_profile_saver",
        title = "Guardar Nuevo Perfil de Subtítulos",
        search_style = "palette",
        search_debounce = "submit",
        on_search = "script-message sub_style_save_custom",
        items = save_items
    })
    mp.commandv("script-message-to", "uosc", "open-menu", json)
end)

mp.register_script_message("sub_style_save_custom", function(...)
    local args = {...}
    if #args > 0 and args[#args] == "{root}" then
        table.remove(args, #args)
    end
    local raw_name = table.concat(args, " "):gsub("%s*{root}$", ""):gsub("^%s*(.-)%s*$", "%1")
    if raw_name == "" then
        notify("⚠️ Escribe un nombre para guardar el perfil", 2)
        return
    end
    local slug = "user_" .. raw_name:lower():gsub("[^%w]+", "_")
    local new_prof = {
        id = slug,
        name = raw_name,
        font = current_style_state.font,
        size = current_style_state.size,
        color = current_style_state.color,
        border_color = current_style_state.border_color,
        shadow_color = current_style_state.shadow_color,
        border_size = current_style_state.border_size,
        shadow_offset = current_style_state.shadow_offset,
        spacing = current_style_state.spacing,
        pos = current_style_state.pos,
        gauss = current_style_state.gauss,
        blur = current_style_state.blur,
        gray = current_style_state.gray,
        override = current_style_state.override,
        border_style = current_style_state.border_style,
        back_color = current_style_state.back_color
    }
    local replaced = false
    for i, us in ipairs(user_styles) do
        if us.id == slug or us.name:lower() == raw_name:lower() then
            user_styles[i] = new_prof
            replaced = true
            break
        end
    end
    if not replaced then
        table.insert(user_styles, new_prof)
    end
    options.active_style = slug
    save_user_styles()
    save_options()
    apply_style_table(new_prof)
    notify("⭐ Perfil guardado: " .. raw_name, 3)
    build_unified_subtitles_menu(true)
end)

mp.register_script_message("sub_action", function(action)
    if not action then return end

    if action:match("^select:") then
        local id = tonumber(action:match("^select:(%d+)$"))
        if id then
            mp.commandv("set", "sid", id)
            notify("Pista de subtítulo: " .. id, 2)
            build_unified_subtitles_menu(false)
        end
    elseif action == "disable" then
        mp.commandv("set", "sid", "no")
        notify("Subtítulos desactivados", 2)
        build_unified_subtitles_menu(false)
    elseif action:match("^set_secondary:") then
        local val = action:match("^set_secondary:(.+)$")
        if val == "no" then
            mp.commandv("set", "secondary-sid", "no")
            notify("Subtítulo secundario desactivado", 2)
        else
            local sid = tonumber(val)
            if sid then
                mp.commandv("set", "secondary-sid", sid)
                notify("Subtítulo secundario: Pista " .. sid, 2)
            end
        end
        build_unified_subtitles_menu(false)
    elseif action == "smart_dual_sub" then
        local tracks = mp.get_property_native("track-list") or {}
        local src = get_best_source_track()
        if not src then
            notify("⚠️ No hay pistas de subtítulo para Modo Bilingüe", 3)
            return
        end
        -- Check if we already have a track matching options.target_lang
        local tgt_track = nil
        for _, t in ipairs(tracks) do
            if t.type == "sub" and track_matches_lang(t, options.target_lang) and not is_forced_track(t) then
                tgt_track = t
                break
            end
        end
        if tgt_track and tgt_track.id ~= src.id then
            mp.commandv("set", "sid", tgt_track.id)
            mp.commandv("set", "secondary-sid", src.id)
            notify("👥 Modo Bilingüe activo (Pista " .. src.id .. " arriba + Pista " .. tgt_track.id .. " abajo)", 3)
            build_unified_subtitles_menu(false)
        else
            translate_track(src, options.target_lang, false, true)
        end
    elseif action:match("^translate_secondary:") then
        local lang = action:match("^translate_secondary:(.+)$")
        local tracks = mp.get_property_native("track-list") or {}
        -- First check if a track in that language already exists
        for _, t in ipairs(tracks) do
            if t.type == "sub" and track_matches_lang(t, lang) and not is_forced_track(t) then
                mp.commandv("set", "secondary-sid", t.id)
                notify("👥 Pista existente en " .. lang:upper() .. " colocada arriba", 3)
                build_unified_subtitles_menu(false)
                return
            end
        end
        local src = get_best_source_track()
        if src then
            translate_track(src, lang, true, false)
        else
            notify("⚠️ No hay subtítulo base para traducir a " .. lang:upper(), 3)
        end
    elseif action:match("^set_style:") then
        local st_id = action:match("^set_style:(.+)$")
        local st = find_style_by_id(st_id)
        if st then
            options.active_style = st_id
            save_options()
            apply_style_table(st)
            notify("🎨 Estilo de subtítulos: " .. st.name, 2)
            build_unified_subtitles_menu(false)
        end
    elseif action:match("^delete_style:") then
        local st_id = action:match("^delete_style:(.+)$")
        for i, us in ipairs(user_styles) do
            if us.id == st_id then
                local removed_name = us.name
                table.remove(user_styles, i)
                save_user_styles()
                if options.active_style == st_id then
                    options.active_style = "signature"
                    save_options()
                    apply_style_table(builtin_styles.signature)
                end
                notify("🗑️ Perfil eliminado: " .. removed_name, 2)
                build_unified_subtitles_menu(false)
                break
            end
        end
    elseif action:match("^mod_size:") then
        local delta = tonumber(action:match("^mod_size:([%+%-]?%d+)$")) or 0
        current_style_state.size = math.max(18, math.min(80, (tonumber(current_style_state.size) or 40) + delta))
        options.active_style = "custom_live"
        apply_style_table(current_style_state)
        notify("📏 Tamaño de subtítulo: " .. current_style_state.size .. " px", 2)
        build_unified_subtitles_menu(false)
    elseif action:match("^exact_size:") then
        local sz = tonumber(action:match("^exact_size:(%d+)$")) or 40
        current_style_state.size = sz
        options.active_style = "custom_live"
        apply_style_table(current_style_state)
        notify("📏 Tamaño de subtítulo: " .. sz .. " px", 2)
        build_unified_subtitles_menu(false)
    elseif action:match("^set_color:") then
        local col = action:match("^set_color:(.+)$")
        current_style_state.color = col
        options.active_style = "custom_live"
        apply_style_table(current_style_state)
        notify("🎨 Color de texto actualizado", 2)
        build_unified_subtitles_menu(false)
    elseif action:match("^set_box:") then
        local mode = action:match("^set_box:(.+)$")
        if mode == "signature_blue" then
            current_style_state.border_style = "outline-and-shadow"
            current_style_state.border_color = "#AA000080"
            current_style_state.back_color = "#00000000"
            current_style_state.border_size = 3.0
            current_style_state.gauss = 0.9
            current_style_state.blur = 0.9
            current_style_state.gray = "yes"
        elseif mode == "clean_black" then
            current_style_state.border_style = "outline-and-shadow"
            current_style_state.border_color = "#EE000000"
            current_style_state.back_color = "#00000000"
            current_style_state.border_size = 2.5
            current_style_state.gauss = 0.0
            current_style_state.blur = 0.0
            current_style_state.gray = "no"
        elseif mode == "heavy_black" then
            current_style_state.border_style = "outline-and-shadow"
            current_style_state.border_color = "#FF000000"
            current_style_state.back_color = "#00000000"
            current_style_state.border_size = 3.8
            current_style_state.gauss = 0.0
            current_style_state.blur = 0.0
            current_style_state.gray = "no"
        elseif mode == "streaming_box" then
            current_style_state.border_style = "background-box"
            current_style_state.border_color = "#B0101218"
            current_style_state.back_color = "#B0101218"
            current_style_state.border_size = 4.0
            current_style_state.gauss = 0.0
            current_style_state.blur = 0.0
            current_style_state.gray = "no"
        end
        options.active_style = "custom_live"
        apply_style_table(current_style_state)
        notify("🖼️ Estilo de contorno/caja actualizado", 2)
        build_unified_subtitles_menu(false)
    elseif action:match("^set_font:") then
        local fnt = action:match("^set_font:(.+)$")
        current_style_state.font = fnt
        options.active_style = "custom_live"
        apply_style_table(current_style_state)
        notify("🔤 Fuente: " .. fnt, 2)
        build_unified_subtitles_menu(false)
    elseif action:match("^mod_pos:") then
        local d = tonumber(action:match("^mod_pos:([%+%-]?%d+)$")) or 0
        current_style_state.pos = math.max(50, math.min(105, (tonumber(current_style_state.pos) or 100) + d))
        options.active_style = "custom_live"
        apply_style_table(current_style_state)
        notify("📐 Posición vertical: " .. current_style_state.pos .. "%", 2)
        build_unified_subtitles_menu(false)
    elseif action:match("^exact_pos:") then
        local p = tonumber(action:match("^exact_pos:(%d+)$")) or 100
        current_style_state.pos = p
        options.active_style = "custom_live"
        apply_style_table(current_style_state)
        notify("📐 Posición vertical: " .. p .. "%", 2)
        build_unified_subtitles_menu(false)
    elseif action:match("^add_delay:") then
        local d = tonumber(action:match("^add_delay:([%+%-]?[%d%.]+)$")) or 0
        local cur = mp.get_property_number("sub-delay", 0)
        local next_val = math.floor((cur + d) * 100 + 0.5) / 100
        mp.set_property_number("sub-delay", next_val)
        notify(string.format("⏱️ Sincronización Subtítulos: %+.2fs", next_val), 2)
        build_unified_subtitles_menu(false)
    elseif action == "reset_delay" then
        mp.set_property_number("sub-delay", 0)
        notify("⏱️ Sincronización Subtítulos: 0.00s (Exacto)", 2)
        build_unified_subtitles_menu(false)
    elseif action == "translate_current" then
        local tracks = mp.get_property_native("track-list") or {}
        local current_sid = mp.get_property_number("sid")
        local target_track = nil
        if current_sid then
            for _, t in ipairs(tracks) do
                if t.type == "sub" and t.id == current_sid then
                    target_track = t
                    break
                end
            end
        end
        if not target_track then
            target_track = get_best_source_track()
        end
        if target_track then
            translate_track(target_track, options.target_lang)
        else
            notify("⚠️ No se encontró subtítulo para traducir", 3)
        end
    elseif action:match("^translate_track:") then
        local id = tonumber(action:match("^translate_track:(%d+)$"))
        if id then
            local tracks = mp.get_property_native("track-list") or {}
            for _, t in ipairs(tracks) do
                if t.type == "sub" and t.id == id then
                    translate_track(t, options.target_lang)
                    break
                end
            end
        end
    elseif action:match("^set_lang:") then
        local lang = action:match("^set_lang:(.+)$")
        options.target_lang = lang
        save_options()
        notify("🌐 Idioma destino: " .. lang:upper(), 2)
        build_unified_subtitles_menu(false)
    elseif action == "toggle_auto" then
        options.auto_translate = not options.auto_translate
        save_options()
        notify("🌐 Traducción automática: " .. (options.auto_translate and "ACTIVADA" or "DESACTIVADA"), 2)
        build_unified_subtitles_menu(false)
    elseif action == "toggle_save" then
        options.save_subtitles = not options.save_subtitles
        save_options()
        notify("💾 Guardar subtítulo: " .. (options.save_subtitles and "En carpeta del video" or "Solo en caché temporal"), 3)
        build_unified_subtitles_menu(false)
    elseif action == "restore_original" then
        local tracks = mp.get_property_native("track-list") or {}
        local restored = false
        for _, t in ipairs(tracks) do
            if t.type == "sub" and not t.external then
                mp.commandv("set", "sid", t.id)
                notify("↩ Subtítulo original restaurado", 2)
                restored = true
                break
            end
        end
        if not restored then
            for _, t in ipairs(tracks) do
                if t.type == "sub" and t.external and t["external-filename"] then
                    local fn = t["external-filename"]:lower()
                    if not fn:find("%." .. options.target_lang:lower() .. "%.ass$") and not fn:find("cache[/\\]traduccion") then
                        mp.commandv("set", "sid", t.id)
                        notify("↩ Subtítulo original restaurado", 2)
                        restored = true
                        break
                    end
                end
            end
        end
        if not restored then notify("ℹ️ No se encontraron subtítulos originales", 2) end
        build_unified_subtitles_menu(false)
    elseif action == "clear_cache" then
        clear_cache()
        build_unified_subtitles_menu(false)
    end
end)

mp.register_script_message("open-subtitles-menu", function() build_unified_subtitles_menu(true) end)
mp.register_script_message("traduccion_menu", function() build_unified_subtitles_menu(true) end)

