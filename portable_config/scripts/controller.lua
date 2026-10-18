-- [[
--    controller.lua - Core Modular Engine for Custom MPV Build
--    Handles: Intelligent Content Detection (Anime vs Cinema/K-Drama),
--             Shader Chain Management (ArtCNN, FSRCNNX), Audio Modes,
--             and Silent Startup UX.
-- ]]

local mp = require "mp"
local msg = require "mp.msg"
local utils = require "mp.utils"
local opt = require "mp.options"

local M = {}

-- ── Configuration ─────────────────────────────────────────────────────────────
local config = {
    video_mode     = "auto",      -- auto, eco, low_power, balanced, series, anime_light, anime, fidelity, clean
    audio_mode     = "normal",    -- normal, dolby_atmos, dolby_voice, dts_x, spatial, music_wide, night, passthrough
    audio_channels = "auto-safe", -- auto-safe, mono, stereo, 2.1, 4.0, 5.1, 7.1
    volume_boost   = "off",       -- off, soft, medium, high, auto
    eco_mode       = "no",        -- yes, no
    eq_profile     = "off",       -- off, vocal, cinema, bass, anime, night, custom
    eq_b64         = 0,
    eq_b250        = 0,
    eq_b1000       = 0,
    eq_b2500       = 0,
    eq_b6000       = 0,
    eq_b14000      = 0,
    alang_pref     = "ja,jpn,es-419,spa,es,ko",
    slang_pref     = "es-419,es-LA,spa,es,en"
}

opt.read_options(config, "controller")

-- ── Internal State ────────────────────────────────────────────────────────────
local state = {
    detected_type        = "unknown",
    active_profile       = "Auto (Detección Inteligente)",
    active_shaders       = "ArtCNN / FSRCNNX",
    audio_mode           = config.audio_mode,
    audio_label          = "Estándar (Directo)",
    audio_channels       = config.audio_channels,
    audio_channels_label = "Automático (Nativo)",
    volume_boost         = config.volume_boost,
    volume_boost_label   = "Desactivado (0 dB)",
    eq_profile           = config.eq_profile
}

-- ── Shaders Directory Helper ──────────────────────────────────────────────────
local function shader(name)
    return mp.command_native({"expand-path", "~~/shaders/" .. name})
end

-- ── Intelligent Content Classifier (Multi-Layered Heuristic) ──────────────────
-- Evaluates Subtitles, Fonts, Chapters, Broadcasters/Tags, Audio, and Aspect Ratio.
-- Works accurately even with Spanish/English dubbed anime, K-Dramas, and Western Cinema.
local function detect_content_type()
    local filepath = mp.get_property("path")
    if not filepath then return "clean" end

    local dir, filename = utils.split_path(filepath)
    local parent_dir = dir and dir:match("([^/\\]+)[/\\]*$") or ""
    -- Only evaluate filename and immediate containing folder, not full absolute system path
    local full_text = (filename .. " " .. parent_dir):lower()

    local anime_score = 0
    local live_score = 0

    -- 1. Anime Fansub / Release Groups signatures
    local anime_groups = {
        "subsplease", "erai%-raws", "judas", "asw", "horriblesubs", "tsundere",
        "ember", "puyasubs", "anime time", "commie", "bakedfish", "nandesuka",
        "varyg", "smolgeno", "yameii", "toonshub", "dkb", "kaleido", "beatrice%-raws",
        "reza", "nep_nep", "ssa", "kewl", "dual%-audio", "ncop", "nced"
    }
    for _, g in ipairs(anime_groups) do
        if full_text:match(g) then anime_score = anime_score + 5 end
    end

    -- Anime episode/season naming patterns: e.g. " - 01 (1080p)", " - 12 [", "E01-E12", "s01e01"
    if full_text:match("%s%-%s%d%d%s") or full_text:match("%s%-%s%d%d%d?%s*%[") or full_text:match("s%d%de%d%d") then
        anime_score = anime_score + 2
    end
    if full_text:match("anime") or full_text:match("ova") or full_text:match("ona") then
        anime_score = anime_score + 3
    end

    -- 2. K-Drama / Asian Drama Broadcasters & Networks signatures
    local kdrama_tags = {
        "tvn", "jtbc", "kbs", "kbs2", "sbs", "mbc", "ena", "viki", "iqiyi",
        "wetv", "youku", "doramas", "k%-drama", "kdrama", "c%-drama", "j%-drama",
        "next", "hancinema", "nondrm", "bone", "korean"
    }
    for _, tag in ipairs(kdrama_tags) do
        if full_text:match(tag) then live_score = live_score + 5 end
    end

    -- 3. Live-Action Cinema / Western Web-DL & BluRay signatures
    local cinema_tags = {
        "1080p%.web%.dl", "2160p%.web%.dl", "web%-dl", "webrip", "bluray", "bdrip",
        "brrip", "remux", "criterion", "imax", "uhd", "hdtv", "amzn", "nf%.web",
        "hbo", "disney", "ddp5%.1", "truehd", "atmos", "yify", "yts", "rarbg",
        "tigole", "qxr", "galaxyrg", "flux", "sparks", "rovers"
    }
    for _, tag in ipairs(cinema_tags) do
        if full_text:match(tag) then live_score = live_score + 4 end
    end

    -- 4. Subtitle Track Codecs & Embedded Attachments
    local tracks = mp.get_property_native("track-list") or {}
    for _, t in ipairs(tracks) do
        if t.type == "sub" then
            local codec = (t.codec or ""):lower()
            if codec:match("ass") or codec:match("ssa") then
                anime_score = anime_score + 4
            elseif codec:match("subrip") or codec:match("srt") or codec:match("vtt") or codec:match("pgs") then
                live_score = live_score + 3
            end
        elseif t.type == "audio" then
            local lang = (t.lang or ""):lower()
            if lang == "ja" or lang == "jpn" then
                anime_score = anime_score + 2
            elseif lang == "ko" or lang == "kor" then
                live_score = live_score + 4
            end
            local channels = t["audio-channels"] or 2
            if channels > 2 then
                live_score = live_score + 2
            end
        end
    end

    -- 5. Chapters Structure (Opening/Ending detection)
    local chapters = mp.get_property_native("chapter-list") or {}
    for _, ch in ipairs(chapters) do
        local title = (ch.title or ""):lower()
        if title:match("^op") or title:match("opening") or title:match("^ed") or title:match("ending")
           or title:match("preview") or title:match("part%s*[ab]") or title:match("eyecatch") then
            anime_score = anime_score + 5
            break
        elseif title:match("scene") or title:match("chapter%s*%d") then
            live_score = live_score + 2
        end
    end

    -- 6. Video Aspect Ratio
    local aspect = mp.get_property_number("video-params/aspect", 1.777)
    if aspect and aspect > 2.1 then
        -- Ultra-widescreen Cinemascope (2.35:1, 2.39:1, etc.) is almost exclusively cinema/live-action
        live_score = live_score + 4
    elseif aspect and (math.abs(aspect - 1.777) < 0.05 or math.abs(aspect - 1.333) < 0.05) then
        anime_score = anime_score + 1
    end

    msg.info(string.format("Content Classifier Scores -> Anime: %d | Cinema/Live-Action: %d", anime_score, live_score))

    if anime_score >= 4 and anime_score >= live_score then
        return "anime"
    elseif live_score >= 3 and live_score > anime_score then
        return "fidelity"
    end

    return "clean"
end

local function notify_user(text, duration)
    mp.commandv("script-message-to", "uosc", "dynamic-island-message", text, tostring(duration or 2))
end

-- ── Shader Chain Application ──────────────────────────────────────────────────
function M.apply_video_profile(mode, notify)
    local current_mode = mode or config.video_mode
    if config.eco_mode == "yes" or current_mode == "eco" then
        mp.commandv("change-list", "glsl-shaders", "clr", "")
        mp.set_property("scale", "bilinear")
        mp.set_property("cscale", "bilinear")
        mp.set_property("dscale", "bilinear")
        mp.set_property("deband", "no")
        state.active_profile = "Eco (Ultra Bajo Consumo)"
        state.active_shaders = "Ninguno (Hardware Puro)"
        mp.commandv("script-message", "reapply-ambient-shader")
        msg.info("Applied Eco Video Profile")
        if notify then notify_user("⚡ Modo Eco: ACTIVADO") end
        return
    end

    local target = current_mode
    if target == "auto" then
        if mp.get_property("path") then
            local detected = detect_content_type()
            state.detected_type = detected
            target = detected
        else
            state.active_profile = "Auto (Detección Inteligente)"
            state.active_shaders = "ArtCNN / FSRCNNX"
            if notify then notify_user("🎨 Perfil: Auto (Detección Inteligente)") end
            return
        end
    end

    mp.commandv("change-list", "glsl-shaders", "clr", "")

    if target == "low_power" then
        -- Low-power laptop / iGPU mode: fast Spline36 + ultra-lightweight AMD CAS
        mp.commandv("change-list", "glsl-shaders", "append", shader("AMD_CAS.glsl"))
        mp.set_property("scale", "spline36")
        mp.set_property("cscale", "spline36")
        mp.set_property("dscale", "mitchell")
        mp.set_property("deband", "no")
        state.active_profile = "Bajo Consumo (AMD CAS)"
        state.active_shaders = "AMD FidelityFX CAS + Spline36"
    elseif target == "balanced" then
        -- Intermediate balanced profile: SSimSuperRes + KrigBilateral
        mp.commandv("change-list", "glsl-shaders", "append", shader("SSimSuperRes.glsl"))
        mp.commandv("change-list", "glsl-shaders", "append", shader("KrigBilateral.glsl"))
        mp.set_property("scale", "spline64")
        mp.set_property("cscale", "spline64")
        mp.set_property("dscale", "spline64")
        mp.set_property("deband", "no")
        state.active_profile = "Intermedio (SSimSuperRes)"
        state.active_shaders = "SSimSuperRes + KrigBilateral"
    elseif target == "series" then
        -- Streaming / Series / K-Drama Web-DL profile: Deband + KrigBilateral + AMD CAS
        mp.commandv("change-list", "glsl-shaders", "append", shader("KrigBilateral.glsl"))
        mp.commandv("change-list", "glsl-shaders", "append", shader("AMD_CAS.glsl"))
        mp.commandv("change-list", "glsl-shaders", "append", shader("SSimDownscaler.glsl"))
        mp.set_property("scale", "spline64")
        mp.set_property("cscale", "spline64")
        mp.set_property("deband", "yes")
        state.active_profile = "Series & K-Drama (Streaming)"
        state.active_shaders = "Deband + Krig + AMD CAS"
    elseif target == "anime_light" then
        -- Lightweight Anime profile: Anime4K Fast Line Restore + Deband
        mp.commandv("change-list", "glsl-shaders", "append", shader("Anime4K_Fast_Restore.glsl"))
        mp.commandv("change-list", "glsl-shaders", "append", shader("KrigBilateral.glsl"))
        mp.set_property("scale", "spline64")
        mp.set_property("cscale", "spline64")
        mp.set_property("deband", "yes")
        state.active_profile = "Anime Ligero (Anime4K Fast)"
        state.active_shaders = "Anime4K Fast + Krig + Deband"
    elseif target == "anime" then
        -- High-end ArtCNN reconstruction + Adaptive Sharpen + SSim Downscaler
        mp.commandv("change-list", "glsl-shaders", "append", shader("ArtCNN_C4F32.glsl"))
        mp.commandv("change-list", "glsl-shaders", "append", shader("adaptive-sharpen-modern-1080p.glsl"))
        mp.commandv("change-list", "glsl-shaders", "append", shader("SSimDownscaler.glsl"))
        mp.set_property("scale", "spline64")
        mp.set_property("cscale", "spline64")
        mp.set_property("deband", "yes")
        state.active_profile = "Anime Ultra (ArtCNN)"
        state.active_shaders = "ArtCNN C4F32 + Adaptive Sharpen"
    elseif target == "fidelity" then
        -- High-fidelity Cinema reconstruction (FSRCNNX + Krig + SSim)
        mp.commandv("change-list", "glsl-shaders", "append", shader("FSRCNNX_x2_16-0-4-1.glsl"))
        mp.commandv("change-list", "glsl-shaders", "append", shader("KrigBilateral.glsl"))
        mp.commandv("change-list", "glsl-shaders", "append", shader("SSimDownscaler.glsl"))
        mp.commandv("change-list", "glsl-shaders", "append", shader("adaptive-sharpen-modern-1080p.glsl"))
        mp.set_property("scale", "spline64")
        mp.set_property("cscale", "spline64")
        mp.set_property("deband", "no")
        state.active_profile = "Cine Ultra (FSRCNNX)"
        state.active_shaders = "FSRCNNX + Krig + SSim"
    else -- clean
        mp.set_property("scale", "spline64")
        mp.set_property("cscale", "spline64")
        mp.set_property("dscale", "spline64")
        mp.set_property("deband", "no")
        state.active_profile = "Estándar Limpio (Spline64)"
        state.active_shaders = "Ninguno (Spline64)"
    end

    -- Preserve Ambient Crop glow shader if active
    mp.commandv("script-message", "reapply-ambient-shader")

    msg.info("Applied Profile: " .. state.active_profile)
    if notify then notify_user("🎨 Perfil: " .. state.active_profile) end
end

-- ── Audio Profiles (Dolby, DTS, Binaural, Night, Passthrough) ────────────────
local audio_profiles = {
    normal = {
        name = "Estándar (Directo)",
        hint = "Audio original sin filtros espaciales"
    },
    dolby_atmos = {
        name = "Dolby Atmos / Surround Virtual",
        hint = "Cine 3D (120°) + Subgraves LFE + Diálogos"
    },
    dolby_voice = {
        name = "Dolby Voice (Claridad Vocal 3D)",
        hint = "Realce de canal central + Envolvente suave"
    },
    dts_x = {
        name = "DTS:X / Neural:X Espacial",
        hint = "Escena 3D amplia (Haas) + TruBass + Detalle"
    },
    spatial = {
        name = "Binaural Pro (Audífonos / BS2B)",
        hint = "Crossfeed acústico natural sin fatiga"
    },
    music_wide = {
        name = "Estéreo Expandido (Música / Live)",
        hint = "Ampliación de fase + Nitidez Crystalizer"
    },
    night = {
        name = "Modo Nocturno (DRC Inteligente)",
        hint = "Nivela explosiones y susurros"
    },
    passthrough = {
        name = "Passthrough HDMI / Óptico",
        hint = "Bitstream puro Dolby/DTS a receptor externo"
    }
}

-- ── Audio Output Channel Modes (Mono, Stereo, 2.1, 4.0, 5.1, 7.1) ────────────
local channel_modes = {
    ["auto-safe"] = {
        name = "Automático (Nativo)",
        hint = "Se adapta al hardware conectado"
    },
    ["mono"] = {
        name = "Mono (1.0)",
        hint = "Mezcla todo en 1 canal central"
    },
    ["stereo"] = {
        name = "Estéreo (2.0)",
        hint = "Izquierda / Derecha estándar"
    },
    ["2.1"] = {
        name = "Estéreo 2.1 (Con Subwoofer)",
        hint = "Frontales Izq/Der + Subgraves LFE"
    },
    ["4.0"] = {
        name = "Cuadrafónico (4.0)",
        hint = "Frontales + Traseros envolventes"
    },
    ["5.1"] = {
        name = "Surround 5.1 (Cine en Casa)",
        hint = "6 canales (Frontales, Central, LFE, Traseros)"
    },
    ["7.1"] = {
        name = "Surround 7.1 (Cine Completo)",
        hint = "8 canales (Frontales, Central, LFE, Laterales, Traseros)"
    }
}

-- ── Volume Boost Modes (Intelligent Loudness & Anti-Clipping Limiter) ─────────
local volume_boost_modes = {
    off = {
        name = "Desactivado (0 dB)",
        short = "OFF",
        hint = "Volumen natural sin ganancia"
    },
    soft = {
        name = "Suave (+4 dB)",
        short = "+4 dB",
        hint = "Realce ligero con limitador anti-clip"
    },
    medium = {
        name = "Medio (+8 dB)",
        short = "+8 dB",
        hint = "Nivel cine / equiparable al Modo Noche"
    },
    high = {
        name = "Fuerte (+12 dB)",
        short = "+12 dB",
        hint = "Gran potencia para pistas muy silenciosas"
    },
    auto = {
        name = "Auto DRC (Nivelador Continuo)",
        short = "Auto DRC",
        hint = "Misma nivelación potente del Modo Noche en cualquier modo"
    }
}

-- ── Equalizer Presets & Configuration ───────────────────────────────────────────
local eq_presets = {
    off = {
        name = "Plano (Desactivado)",
        hint = "Sin filtros",
        bands = {0, 0, 0, 0, 0, 0}
    },
    vocal = {
        name = "Claridad Vocal (Diálogos)",
        hint = "Voces nítidas (+3 a +4 dB en medios)",
        bands = {-2, -1, 3, 4, 2, -1}
    },
    cinema = {
        name = "Cine / Inmersivo",
        hint = "Graves profundos y agudos abiertos",
        bands = {4, 2, -1, 1, 3, 4}
    },
    bass = {
        name = "Graves Potentes (Bass Boost)",
        hint = "+6 dB en sub-graves",
        bands = {6, 4, 1, 0, 1, 1}
    },
    anime = {
        name = "Anime / Brillo Acústico",
        hint = "Realce en agudos y voces",
        bands = {1, 0, 2, 3, 4, 3}
    },
    night = {
        name = "Suavizado Nocturno",
        hint = "Anti-estruendos y diálogo suave",
        bands = {-4, -2, 3, 2, -2, -4}
    }
}

local function get_custom_bands()
    return {
        tonumber(config.eq_b64) or 0,
        tonumber(config.eq_b250) or 0,
        tonumber(config.eq_b1000) or 0,
        tonumber(config.eq_b2500) or 0,
        tonumber(config.eq_b6000) or 0,
        tonumber(config.eq_b14000) or 0
    }
end

local function get_eq_filter(bands)
    local freqs = {64, 250, 1000, 2500, 6000, 14000}
    local is_zero = true
    for _, g in ipairs(bands) do
        if g ~= 0 then is_zero = false; break end
    end
    if is_zero then return nil end

    local parts = {}
    for i, f in ipairs(freqs) do
        local g = math.floor((bands[i] or 0) + 0.5)
        table.insert(parts, string.format("equalizer=f=%d:t=q:w=1:g=%d", f, g))
    end
    return "lavfi=[" .. table.concat(parts, ",") .. "]"
end

-- Determine target surround output layout based on selected channel mode
local function get_surround_layout()
    local ch = config.audio_channels
    if ch == "5.1" or ch == "7.1" or ch == "4.0" or ch == "2.1" then
        return ch
    end
    return "stereo"
end

-- ── Unified Audio Chain Application ──────────────────────────────────────────
local function apply_audio_chain()
    local ch_mode = config.audio_channels or "auto-safe"
    if not channel_modes[ch_mode] then ch_mode = "auto-safe" end
    state.audio_channels = ch_mode
    state.audio_channels_label = channel_modes[ch_mode].name

    local a_mode = config.audio_mode or "normal"
    if not audio_profiles[a_mode] then a_mode = "normal" end
    state.audio_mode = a_mode
    state.audio_label = audio_profiles[a_mode].name

    local v_boost = config.volume_boost or "off"
    if not volume_boost_modes[v_boost] then v_boost = "off" end
    state.volume_boost = v_boost
    state.volume_boost_label = volume_boost_modes[v_boost].name

    -- Handle Hardware Bitstream Passthrough mode
    if a_mode == "passthrough" then
        mp.set_property("af", "")
        mp.set_property("audio-spdif", "ac3,eac3,dts-hd,truehd")
        mp.set_property("audio-channels", "auto")
        return
    else
        mp.set_property("audio-spdif", "")
        mp.set_property("audio-channels", ch_mode)
    end

    local filters = {}
    local sur_out = get_surround_layout()

    if a_mode == "dolby_atmos" then
        if sur_out == "stereo" then
            table.insert(filters, "lavfi=[dialoguenhance=original=1.0:enhance=1.4:voice=2.5,virtualbass=cutoff=160:strength=2.2,aresample=lfe_mix_level=0.707,surround=chl_out=stereo:angle=120:focus=0.35]")
        else
            table.insert(filters, string.format("lavfi=[surround=chl_out=%s:angle=120:focus=0.35:lfe=1]", sur_out))
        end
    elseif a_mode == "dolby_voice" then
        table.insert(filters, string.format("lavfi=[dialoguenhance=original=1.0:enhance=2.2:voice=4.0,surround=chl_out=%s:angle=90:focus=0.6]", sur_out))
    elseif a_mode == "dts_x" then
        table.insert(filters, "lavfi=[aformat=channel_layouts=stereo,haas=middle_phase=1:side_gain=1.35:left_delay=2.1:right_delay=2.45,virtualbass=cutoff=150:strength=2.0,aresample=lfe_mix_level=0.707,aexciter=amount=1.2:drive=2.0:freq=6000]")
    elseif a_mode == "spatial" then
        table.insert(filters, "lavfi=[aformat=channel_layouts=stereo,bs2b=fcut=700:feed=50,bass=g=2:f=90]")
    elseif a_mode == "music_wide" then
        table.insert(filters, "lavfi=[aformat=channel_layouts=stereo,extrastereo=m=1.65,crystalizer=i=1.2]")
    elseif a_mode == "night" then
        table.insert(filters, "lavfi=[dynaudnorm=f=150:g=15:p=0.92:m=12]")
    end

    -- If user explicitly requested upmixing/downmixing to a specific layout in Direct mode
    if a_mode == "normal" and (ch_mode == "5.1" or ch_mode == "7.1" or ch_mode == "4.0" or ch_mode == "2.1") then
        table.insert(filters, string.format("lavfi=[surround=chl_out=%s:lfe=1]", ch_mode))
    end

    local bands
    if config.eq_profile == "custom" then
        bands = get_custom_bands()
    elseif eq_presets[config.eq_profile] then
        bands = eq_presets[config.eq_profile].bands
    else
        bands = {0, 0, 0, 0, 0, 0}
    end

    local eq_str = get_eq_filter(bands)
    if eq_str then
        table.insert(filters, eq_str)
    end

    -- Volume Boost processing (Anti-clipping limiter)
    if v_boost == "soft" then
        table.insert(filters, "lavfi=[volume=volume=4dB,alimiter=limit=0.98]")
    elseif v_boost == "medium" then
        table.insert(filters, "lavfi=[volume=volume=8dB,alimiter=limit=0.98]")
    elseif v_boost == "high" then
        table.insert(filters, "lavfi=[volume=volume=12dB,alimiter=limit=0.98]")
    elseif v_boost == "auto" and a_mode ~= "night" then
        table.insert(filters, "lavfi=[dynaudnorm=f=150:g=15:p=0.92:m=12]")
    end

    -- Enforce mono downmix if mono channel mode is selected
    if ch_mode == "mono" then
        table.insert(filters, "lavfi=[aformat=channel_layouts=mono]")
    end

    local combined = table.concat(filters, ",")
    mp.set_property("af", combined)
end

function M.apply_audio_profile(mode, notify)
    local target = mode or config.audio_mode
    if not audio_profiles[target] then target = "normal" end
    config.audio_mode = target
    apply_audio_chain()
    if notify then
        notify_user("🎧 Audio: " .. audio_profiles[target].name)
    end
end

function M.apply_audio_channels(ch_mode, notify)
    local target = ch_mode or config.audio_channels
    if not channel_modes[target] then target = "auto-safe" end
    config.audio_channels = target
    apply_audio_chain()
    if notify then
        notify_user("🔈 Canales: " .. channel_modes[target].name)
    end
end

function M.apply_volume_boost(boost_mode, notify)
    local target = boost_mode or config.volume_boost
    if not volume_boost_modes[target] then target = "off" end
    config.volume_boost = target
    apply_audio_chain()
    if notify then
        notify_user("📢 Volumen Boost: " .. volume_boost_modes[target].name)
    end
end

function M.apply_equalizer_profile(profile, notify)
    config.eq_profile = profile or "off"
    state.eq_profile = config.eq_profile
    local eq_name = (config.eq_profile == "custom" and "Personalizado")
        or (eq_presets[config.eq_profile] and eq_presets[config.eq_profile].name)
        or "Plano (Desactivado)"
    if notify then notify_user("🎚️ Ecualizador: " .. eq_name) end
    apply_audio_chain()
end

-- ── Persistence (Cached Path & Directory Check) ───────────────────────────────
local script_opts_dir = mp.command_native({"expand-path", "~~/script-opts"})
local conf_path = mp.command_native({"expand-path", "~~/script-opts/controller.conf"})
local script_opts_ensured = false

local function ensure_script_opts_dir()
    if script_opts_ensured then return end
    local info = utils.file_info(script_opts_dir)
    if info and info.is_dir then
        script_opts_ensured = true
        return
    end
    local is_win = package.config:sub(1, 1) == "\\"
    if is_win then
        local clean_dir = (script_opts_dir:gsub("/", "\\"))
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
            args = {"mkdir", "-p", script_opts_dir},
            capture_stdout = true,
            capture_stderr = true
        })
    end
    script_opts_ensured = true
end

local function save_config()
    ensure_script_opts_dir()
    local f = io.open(conf_path, "w")
    if f then
        f:write("video_mode="     .. config.video_mode .. "\n")
        f:write("audio_mode="     .. config.audio_mode .. "\n")
        f:write("audio_channels=" .. config.audio_channels .. "\n")
        f:write("volume_boost="   .. config.volume_boost .. "\n")
        f:write("eco_mode="       .. config.eco_mode .. "\n")
        f:write("eq_profile="     .. config.eq_profile .. "\n")
        f:write("eq_b64="         .. tostring(config.eq_b64) .. "\n")
        f:write("eq_b250="        .. tostring(config.eq_b250) .. "\n")
        f:write("eq_b1000="       .. tostring(config.eq_b1000) .. "\n")
        f:write("eq_b2500="       .. tostring(config.eq_b2500) .. "\n")
        f:write("eq_b6000="       .. tostring(config.eq_b6000) .. "\n")
        f:write("eq_b14000="      .. tostring(config.eq_b14000) .. "\n")
        f:write("alang_pref="     .. tostring(config.alang_pref or "") .. "\n")
        f:write("slang_pref="     .. tostring(config.slang_pref or "") .. "\n")
        f:close()
    end
end

-- ── Script Message Handlers & State Synchronization ───────────────────────────
local function sync_properties(skip_menu_refresh)
    mp.set_property("user-data/controller/video-mode", (config.eco_mode == "yes") and "eco" or config.video_mode)
    mp.set_property("user-data/controller/video-label", state.active_profile or config.video_mode)
    mp.set_property("user-data/controller/video-shaders", state.active_shaders or "Ninguno")
    mp.set_property("user-data/controller/audio-mode", config.audio_mode)
    mp.set_property("user-data/controller/audio-label", state.audio_label or "Estándar (Directo)")
    mp.set_property("user-data/controller/audio-channels", config.audio_channels)
    mp.set_property("user-data/controller/audio-channels-label", state.audio_channels_label or "Automático (Nativo)")
    mp.set_property("user-data/controller/volume-boost", config.volume_boost)
    mp.set_property("user-data/controller/volume-boost-label", state.volume_boost_label or "Desactivado (0 dB)")
    mp.set_property("user-data/controller/eco-mode", config.eco_mode)
    mp.set_property("user-data/controller/alang-pref", config.alang_pref or "")
    mp.set_property("user-data/controller/slang-pref", config.slang_pref or "")

    local eq_name = (config.eq_profile == "custom" and "Personalizado")
        or (eq_presets[config.eq_profile] and eq_presets[config.eq_profile].name)
        or "Plano (Desactivado)"
    mp.set_property("user-data/controller/eq-profile", config.eq_profile)
    mp.set_property("user-data/controller/eq-label", eq_name)
    mp.set_property("user-data/controller/eq-b64", tostring(config.eq_b64))
    mp.set_property("user-data/controller/eq-b250", tostring(config.eq_b250))
    mp.set_property("user-data/controller/eq-b1000", tostring(config.eq_b1000))
    mp.set_property("user-data/controller/eq-b2500", tostring(config.eq_b2500))
    mp.set_property("user-data/controller/eq-b6000", tostring(config.eq_b6000))
    mp.set_property("user-data/controller/eq-b14000", tostring(config.eq_b14000))

    if not skip_menu_refresh then
        mp.commandv("script-message-to", "uosc", "refresh-equalizer-menu")
        mp.commandv("script-message-to", "uosc", "refresh-audio-menu")
        mp.commandv("script-message-to", "uosc", "refresh-lang-prefs-menu")
    end
end
local notify_menu_refresh = sync_properties

mp.register_script_message("set-video-mode", function(mode)
    if mode == "eco" then
        config.eco_mode = "yes"
        config.video_mode = "eco"
    else
        config.eco_mode = "no"
        config.video_mode = mode
    end
    save_config()
    M.apply_video_profile(config.video_mode, true)
    notify_menu_refresh()
end)

mp.register_script_message("set-audio-mode", function(mode)
    M.apply_audio_profile(mode, true)
    save_config()
    notify_menu_refresh()
end)

mp.register_script_message("set-audio-channels", function(ch_mode)
    M.apply_audio_channels(ch_mode, true)
    save_config()
    notify_menu_refresh()
end)

mp.register_script_message("cycle-audio-channels", function()
    local modes = {"auto-safe", "mono", "stereo", "2.1", "4.0", "5.1", "7.1"}
    local cur_idx = 1
    for i, m in ipairs(modes) do
        if m == config.audio_channels then cur_idx = i; break end
    end
    local next_mode = modes[(cur_idx % #modes) + 1]
    M.apply_audio_channels(next_mode, true)
    save_config()
    notify_menu_refresh()
end)

mp.register_script_message("set-volume-boost", function(mode)
    M.apply_volume_boost(mode, true)
    save_config()
    notify_menu_refresh()
end)

mp.register_script_message("cycle-volume-boost", function()
    local modes = {"off", "soft", "medium", "high", "auto"}
    local cur_idx = 1
    for i, m in ipairs(modes) do
        if m == config.volume_boost then cur_idx = i; break end
    end
    local next_mode = modes[(cur_idx % #modes) + 1]
    M.apply_volume_boost(next_mode, true)
    save_config()
    notify_menu_refresh()
end)

mp.register_script_message("toggle-volume-boost", function()
    local next_mode = (config.volume_boost == "off") and "medium" or "off"
    M.apply_volume_boost(next_mode, true)
    save_config()
    notify_menu_refresh()
end)

mp.register_script_message("set-equalizer-profile", function(profile)
    M.apply_equalizer_profile(profile, true)
    save_config()
    notify_menu_refresh()
end)

mp.register_script_message("cycle-equalizer-profile", function()
    local profiles = {"off", "vocal", "cinema", "bass", "anime", "night", "custom"}
    local cur_idx = 1
    for i, p in ipairs(profiles) do
        if p == config.eq_profile then cur_idx = i; break end
    end
    local next_prof = profiles[(cur_idx % #profiles) + 1]
    M.apply_equalizer_profile(next_prof, true)
    save_config()
    notify_menu_refresh()
end)

local band_keys = {"eq_b64", "eq_b250", "eq_b1000", "eq_b2500", "eq_b6000", "eq_b14000"}
local eq_dsp_timer = nil

local function schedule_live_dsp()
    if eq_dsp_timer then eq_dsp_timer:kill() end
    eq_dsp_timer = mp.add_timeout(0.045, function()
        eq_dsp_timer = nil
        apply_audio_chain()
    end)
end

mp.register_script_message("set-equalizer-band", function(band_idx_str, delta_str)
    local idx = tonumber(band_idx_str)
    local delta = tonumber(delta_str)
    if idx and delta and band_keys[idx] then
        local key = band_keys[idx]
        local cur = tonumber(config[key]) or 0
        local next_val = math.max(-12, math.min(12, cur + delta))
        config[key] = next_val
        config.eq_profile = "custom"
        save_config()
        apply_audio_chain()
        notify_menu_refresh()
    end
end)

mp.register_script_message("set-equalizer-band-exact", function(band_idx_str, val_str)
    local idx = tonumber(band_idx_str)
    local val = tonumber(val_str)
    if idx and val and band_keys[idx] then
        local key = band_keys[idx]
        config[key] = math.max(-12, math.min(12, val))
        config.eq_profile = "custom"
        save_config()
        apply_audio_chain()
        notify_menu_refresh()
    end
end)

-- Live slider dragging: updates memory & debounces DSP without disk I/O or menu table rebuild
mp.register_script_message("set-equalizer-band-live", function(band_idx_str, val_str)
    local idx = tonumber(band_idx_str)
    local val = tonumber(val_str)
    if idx and val and band_keys[idx] then
        local key = band_keys[idx]
        config[key] = math.max(-12, math.min(12, val))
        config.eq_profile = "custom"
        sync_properties(true)
        schedule_live_dsp()
    end
end)

-- Commits live slider drag to disk and refreshes menu state on mouse release
mp.register_script_message("commit-equalizer-bands", function()
    if eq_dsp_timer then
        eq_dsp_timer:kill()
        eq_dsp_timer = nil
    end
    apply_audio_chain()
    save_config()
    notify_menu_refresh()
end)

mp.register_script_message("reset-equalizer-custom", function()
    for _, k in ipairs(band_keys) do
        config[k] = 0
    end
    config.eq_profile = "custom"
    save_config()
    apply_audio_chain()
    notify_user("🎚️ Ecualizador: Bandas a 0 dB")
    notify_menu_refresh()
end)

-- ── Audio Sync Delay Controls ─────────────────────────────────────────────────
mp.register_script_message("add-audio-delay", function(delta_str)
    local d = tonumber(delta_str) or 0
    local cur = mp.get_property_number("audio-delay", 0)
    local next_val = math.floor((cur + d) * 100 + 0.5) / 100
    mp.set_property_number("audio-delay", next_val)
    notify_user(string.format("🔊 Sincronización Audio: %+.2fs", next_val))
    notify_menu_refresh()
end)

mp.register_script_message("reset-audio-delay", function()
    mp.set_property_number("audio-delay", 0)
    notify_user("🔊 Sincronización Audio: 0.00s (Original)")
    notify_menu_refresh()
end)

-- ── Priority Language Queue (alang / slang) ───────────────────────────────────
local function clean_csv_list(str)
    if not str then return "" end
    local list = {}
    local seen = {}
    for token in str:gmatch("[^,%s;]+") do
        local t = token:gsub("^%s*(.-)%s*$", "%1")
        if t ~= "" and not seen[t:lower()] then
            seen[t:lower()] = true
            table.insert(list, t)
        end
    end
    return table.concat(list, ",")
end

local function toggle_csv_token(current_csv, token_group)
    local current_tokens = {}
    for t in (current_csv or ""):gmatch("[^,%s]+") do
        table.insert(current_tokens, t)
    end
    local group_tokens = {}
    for t in (token_group or ""):gmatch("[^,%s]+") do
        table.insert(group_tokens, t)
    end
    if #group_tokens == 0 then return current_csv end

    local primary = group_tokens[1]:lower()
    local exists = false
    for _, ct in ipairs(current_tokens) do
        if ct:lower() == primary then
            exists = true
            break
        end
    end

    local result = {}
    if exists then
        local remove_map = {}
        for _, gt in ipairs(group_tokens) do remove_map[gt:lower()] = true end
        for _, ct in ipairs(current_tokens) do
            if not remove_map[ct:lower()] then
                table.insert(result, ct)
            end
        end
    else
        for _, ct in ipairs(current_tokens) do table.insert(result, ct) end
        for _, gt in ipairs(group_tokens) do table.insert(result, gt) end
    end
    return clean_csv_list(table.concat(result, ","))
end

mp.register_script_message("set-alang-pref", function(...)
    local args = {...}
    if #args > 0 and args[#args] == "{root}" then table.remove(args, #args) end
    local raw = table.concat(args, ""):gsub("%s*{root}$", "")
    local cleaned = clean_csv_list(raw)
    config.alang_pref = cleaned
    mp.set_property("alang", cleaned)
    save_config()
    notify_user("🎧 Prioridad Audio: " .. (cleaned ~= "" and cleaned or "Vacía"))
    notify_menu_refresh()
end)

mp.register_script_message("toggle-alang-item", function(token_group)
    config.alang_pref = toggle_csv_token(config.alang_pref, token_group)
    mp.set_property("alang", config.alang_pref)
    save_config()
    notify_user("🎧 Cola Audio: " .. (config.alang_pref ~= "" and config.alang_pref or "Vacía"))
    notify_menu_refresh()
end)

mp.register_script_message("clear-alang-pref", function()
    config.alang_pref = ""
    mp.set_property("alang", "")
    save_config()
    notify_user("🎧 Cola de prioridad de audio vaciada")
    notify_menu_refresh()
end)

mp.register_script_message("set-slang-pref", function(...)
    local args = {...}
    if #args > 0 and args[#args] == "{root}" then table.remove(args, #args) end
    local raw = table.concat(args, ""):gsub("%s*{root}$", "")
    local cleaned = clean_csv_list(raw)
    config.slang_pref = cleaned
    mp.set_property("slang", cleaned)
    save_config()
    notify_user("💬 Prioridad Subtítulos: " .. (cleaned ~= "" and cleaned or "Vacía"))
    notify_menu_refresh()
end)

mp.register_script_message("toggle-slang-item", function(token_group)
    config.slang_pref = toggle_csv_token(config.slang_pref, token_group)
    mp.set_property("slang", config.slang_pref)
    save_config()
    notify_user("💬 Cola Subtítulos: " .. (config.slang_pref ~= "" and config.slang_pref or "Vacía"))
    notify_menu_refresh()
end)

mp.register_script_message("clear-slang-pref", function()
    config.slang_pref = ""
    mp.set_property("slang", "")
    save_config()
    notify_user("💬 Cola de prioridad de subtítulos vaciada")
    notify_menu_refresh()
end)

-- ── A-B Loop Interactive Controller ───────────────────────────────────────────
local function format_time_short(sec)
    if type(sec) ~= "number" or sec < 0 then return "--:--" end
    local m = math.floor(sec / 60)
    local s = math.floor(sec % 60)
    return string.format("%02d:%02d", m, s)
end

mp.register_script_message("cycle-ab-loop", function()
    local a = mp.get_property_native("ab-loop-a")
    local b = mp.get_property_native("ab-loop-b")
    local now = mp.get_property_number("time-pos", 0)

    if type(a) ~= "number" then
        mp.set_property_number("ab-loop-a", now)
        notify_user("🔁 Loop A-B: Punto A fijado en " .. format_time_short(now))
    elseif type(b) ~= "number" then
        if now > a then
            mp.set_property_number("ab-loop-b", now)
            notify_user("🔁 Loop A-B Activo: " .. format_time_short(a) .. " → " .. format_time_short(now))
        else
            mp.set_property_number("ab-loop-a", now)
            notify_user("🔁 Loop A-B: Punto A actualizado a " .. format_time_short(now))
        end
    else
        mp.set_property("ab-loop-a", "no")
        mp.set_property("ab-loop-b", "no")
        notify_user("🔁 Loop A-B: DESACTIVADO")
    end
    notify_menu_refresh()
end)

mp.register_script_message("clear-ab-loop", function()
    mp.set_property("ab-loop-a", "no")
    mp.set_property("ab-loop-b", "no")
    notify_user("🔁 Loop A-B: DESACTIVADO")
    notify_menu_refresh()
end)

mp.register_script_message("toggle-video-mode", function()
    local modes = {"auto", "low_power", "balanced", "series", "anime_light", "anime", "fidelity", "clean", "eco"}
    local cur_idx = 1
    for i, m in ipairs(modes) do
        if (config.eco_mode == "yes" and m == "eco") or (config.eco_mode ~= "yes" and m == config.video_mode) then
            cur_idx = i; break
        end
    end
    local next_mode = modes[(cur_idx % #modes) + 1]
    if next_mode == "eco" then
        config.eco_mode = "yes"
        config.video_mode = "eco"
    else
        config.eco_mode = "no"
        config.video_mode = next_mode
    end
    save_config()
    M.apply_video_profile(config.video_mode, true)
    notify_menu_refresh()
end)

mp.register_script_message("cycle-audio-mode", function()
    local modes = {"normal", "dolby_atmos", "dolby_voice", "dts_x", "spatial", "music_wide", "night", "passthrough"}
    local cur_idx = 1
    for i, m in ipairs(modes) do
        if m == config.audio_mode then cur_idx = i; break end
    end
    local next_mode = modes[(cur_idx % #modes) + 1]
    M.apply_audio_profile(next_mode, true)
    save_config()
    notify_menu_refresh()
end)

mp.register_script_message("cycle-speed", function()
    local speeds = {1.0, 1.25, 1.5, 2.0, 0.75}
    local cur = mp.get_property_number("speed", 1.0)
    local next_spd = 1.25
    for i, spd in ipairs(speeds) do
        if math.abs(cur - spd) < 0.05 then
            next_spd = speeds[(i % #speeds) + 1]
            break
        end
    end
    mp.set_property("speed", next_spd)
    notify_user(string.format("⏱ Velocidad: %.2fx", next_spd))
    notify_menu_refresh()
end)

mp.register_script_message("toggle-loop-file", function()
    local cur = mp.get_property("loop-file", "no")
    local next_val = (cur == "no") and "inf" or "no"
    mp.set_property("loop-file", next_val)
    notify_user("🔁 Repetir archivo: " .. (next_val == "inf" and "ACTIVADO" or "DESACTIVADO"))
    notify_menu_refresh()
end)

mp.register_script_message("toggle-audio-spatial", function()
    if config.audio_mode == "dolby_atmos" then
        M.apply_audio_profile("normal", true)
    else
        M.apply_audio_profile("dolby_atmos", true)
    end
    save_config()
    notify_menu_refresh()
end)

mp.register_script_message("toggle-audio-night", function()
    if config.audio_mode == "night" then
        M.apply_audio_profile("normal", true)
    else
        M.apply_audio_profile("night", true)
    end
    save_config()
    notify_menu_refresh()
end)

mp.register_script_message("toggle-eco-mode", function()
    config.eco_mode = (config.eco_mode == "yes") and "no" or "yes"
    save_config()
    M.apply_video_profile(config.video_mode, true)
    notify_menu_refresh()
end)

-- ── Event Registration ────────────────────────────────────────────────────────
-- Silent startup: only apply profiles in the background without spamming OSD notifications
mp.register_event("file-loaded", function()
    M.apply_video_profile(nil, false)
    apply_audio_chain()
    sync_properties()
end)

-- Expose state getter for menus
_G.get_controller_state = function()
    return {
        config = config,
        state = state
    }
end

-- Initialize labels, language preferences & user-data properties immediately
if config.alang_pref and config.alang_pref ~= "" then
    mp.set_property("alang", config.alang_pref)
end
if config.slang_pref and config.slang_pref ~= "" then
    mp.set_property("slang", config.slang_pref)
end
if audio_profiles[config.audio_mode] then
    state.audio_label = audio_profiles[config.audio_mode].name
end
if channel_modes[config.audio_channels] then
    state.audio_channels_label = channel_modes[config.audio_channels].name
end
if volume_boost_modes[config.volume_boost] then
    state.volume_boost_label = volume_boost_modes[config.volume_boost].name
end
sync_properties(true)

return M
