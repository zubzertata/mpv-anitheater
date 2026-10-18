--[[ uosc | https://github.com/tomasklaen/uosc ]]
local uosc_version = '5.13.0'

mp.commandv('script-message', 'uosc-version', uosc_version)

mp.set_property('osc', 'no')

assdraw = require('mp.assdraw')
opt = require('mp.options')
utils = require('mp.utils')
msg = require('mp.msg')
osd = mp.create_osd_overlay('ass-events')
QUARTER_PI_SIN = math.sin(math.pi / 4)

require('lib/std')

-- [PHASE 7: DIRECT BROADCAST LISTENER (ROBUST FIX)]

-- 1. Create a local cache to store the latest state
local anime_cache = { history_enabled = true } -- UPDATED DEFAULT

-- =============================================================================
-- [NEW] HISTORY ENGINE (ROBUST VERSION)
-- =============================================================================
-- Save directly to root mpv folder to avoid missing directory errors
local history_file = mp.command_native({"expand-path", "~~/uosc_history.json"})
local watch_history = {}
local active_video = { path = nil, title = nil, percent = 0 }

local function load_watch_history()
    local f = io.open(history_file, "r")
    if f then
        local content = f:read("*all")
        f:close()
        if content and content ~= "" then watch_history = utils.parse_json(content) or {} end
    end
end

local function save_watch_history()
    if type(watch_history) == 'table' then
        while #watch_history > 100 do
            table.remove(watch_history, 1)
        end
    end
    local f = io.open(history_file, "w")
    if f then
        f:write(utils.format_json(watch_history))
        f:close()
    end
end

load_watch_history()

-- 1. Grab file details when it successfully starts
mp.register_event('file-loaded', function()
    active_video.path = mp.get_property("path")
    active_video.title = mp.get_property("media-title")
    if not active_video.title or active_video.title == "" then
        active_video.title = (active_video.path or ""):match("([^/\\]+)$") or active_video.path or "Unknown"
    end
    active_video.percent = 0
end)

-- 2. Constantly cache exact percent so we have it BEFORE the file closes
mp.observe_property("percent-pos", "number", function(_, percent)
    if percent then active_video.percent = math.floor(percent) end
end)
-- =============================================================================

-- 2. Define the Reader Helper (Uses cache instead of get_property)
function get_anime_state(key)
    -- Return true if the key exists and is true
    return anime_cache[key]
end

-- 3. Listen for the Broadcast (Merged Logic)
mp.register_script_message('anime-state-broadcast', function(json)
    local data = utils.parse_json(json)
    if not data then return end
    
    -- [FIX] Merge data into cache instead of replacing it
    for k, v in pairs(data) do
        anime_cache[k] = v
    end
    
    -- Force Redraw if Menu is Open
    if Menu:is_open('menu') then
        local items = create_default_menu_items()
        local menu_json = utils.format_json({ type = 'menu', items = items })
        mp.commandv("script-message-to", mp.get_script_name(), "update-menu", menu_json)
    end
end)

-- [PHASE 8: CUSTOM DENOISE (HQDN3D) ENGINE]
local denoise = { enabled = false, ls = 0, cs = 0, lt = 4, ct = 4 }
local previous_hwdec = nil -- To remember what hwdec you were using before

mp.register_script_message('update-denoise', function(param, val)
    -- 1. Update State Variables
    if param == "toggle" then
        denoise.enabled = not denoise.enabled
    elseif val == "reset" then
        if param == "lt" or param == "ct" then denoise[param] = 4 else denoise[param] = 0 end
    else
        denoise[param] = math.max(0, denoise[param] + tonumber(val)) 
    end

    -- 2. Apply to MPV Video Filters safely
    mp.command('no-osd vf remove @denoise') 
    
    if denoise.enabled then
        -- [AUTO-FIX] Force a -copy hwdec so CPU filters work
        local current_hwdec = mp.get_property("hwdec", "auto")
        if current_hwdec ~= "no" and not current_hwdec:match("-copy") then
            previous_hwdec = current_hwdec -- Save the original state
            mp.set_property("hwdec", "auto-copy")
        end

        local filter_str = string.format("hqdn3d=%s:%s:%s:%s", denoise.ls, denoise.cs, denoise.lt, denoise.ct)
        mp.command('no-osd vf add @denoise:' .. filter_str)
        mp.commandv("script-message-to", "uosc", "dynamic-island-message", "Denoise ON: " .. filter_str)
    else
        -- [AUTO-FIX] Restore original hwdec when denoise is turned off
        if previous_hwdec then
            mp.set_property("hwdec", previous_hwdec)
            previous_hwdec = nil
        end
        mp.commandv("script-message-to", "uosc", "dynamic-island-message", "Denoise OFF")
    end
end)

--[[ OPTIONS ]]

defaults = {
	timeline_style = 'line',
	timeline_line_width = 2,
	timeline_size = 40,
	progress = 'windowed',
	progress_size = 2,
	progress_line_width = 20,
	timeline_persistency = '',
	timeline_border = 1,
	timeline_step = '5',
	timeline_cache = true,
	timeline_heatmap = 'overlay',
	timeline_mbtn_right = '',

	controls =
	'menu,gap,<video,audio>subtitles,<has_many_audio>audio,<has_many_video>video,<has_many_edition>editions,<stream>stream-quality,gap,space,<video,audio>speed,space,shuffle,loop-playlist,loop-file,gap,prev,items,next,gap,fullscreen',
	controls_size = 32,
	controls_margin = 8,
	controls_spacing = 2,
	controls_persistency = '',

	volume = 'right',
	volume_size = 40,
	volume_persistency = '',
	volume_border = 1,
	volume_step = 1,

	speed_persistency = '',
	speed_step = 0.1,
	speed_step_is_factor = false,

	menu_item_height = 36,
	menu_min_width = 260,
	menu_padding = 4,
	menu_type_to_search = true,

	top_bar = 'no-border',
	top_bar_size = 40,
	top_bar_persistency = '',
	top_bar_controls = 'right',
	top_bar_title = 'yes',
	top_bar_alt_title = '',
	top_bar_alt_title_place = 'below',
	top_bar_flash_on = 'video,audio',

	window_border_size = 1,

	autoload = false,
	shuffle = false,

	scale = 1,
	scale_fullscreen = 1.3,
	font_scale = 1,
	text_border = 1.2,
	border_radius = 4,
	color = '',
	opacity = '',
	animation_duration = 100,
	refine = '',
	flash_duration = 1000,
	proximity_in = 40,
	proximity_out = 120,
	total_time = false, -- deprecated by below
	destination_time = 'playtime-remaining',
	time_precision = 0,
	font_bold = false,
	autohide = false,
	buffered_time_threshold = 60,
	pause_indicator = 'flash',
	stream_quality_options = '4320,2160,1440,1080,720,480,360,240,144',
	video_types =
	'3g2,3gp,asf,avi,f4v,flv,h264,h265,m2ts,m4v,mkv,mov,mp4,mp4v,mpeg,mpg,ogm,ogv,rm,rmvb,ts,vob,webm,wmv,y4m',
	audio_types =
	'aac,ac3,aiff,ape,au,cue,dsf,dts,flac,m4a,mid,midi,mka,mp3,mp4a,oga,ogg,opus,spx,tak,tta,wav,weba,wma,wv',
	image_types = 'apng,avif,bmp,gif,j2k,jp2,jfif,jpeg,jpg,jxl,mj2,png,svg,tga,tif,tiff,webp',
	subtitle_types = 'aqt,ass,gsub,idx,jss,lrc,mks,pgs,pjs,psb,rt,sbv,slt,smi,sub,sup,srt,ssa,ssf,ttxt,txt,usf,vt,vtt',
	playlist_types = 'm3u,m3u8,pls,url,cue',
	load_types = 'video,audio,image',
	default_directory = '~/',
	show_hidden_files = false,
	use_trash = false,
	adjust_osd_margins = true,
	chapter_ranges = 'openings:22c55eb0,endings:a855f7b0,ads:c54e4e80',
	chapter_range_patterns = 'openings:オープニング,opテーマ,主題歌;endings:エンディング,edテーマ,結び',
	languages = 'slang,en',
	subtitles_directory = '~~/subtitles',
	disable_elements = '',
}
options = table_copy(defaults)
function handle_options(changed_options)
	if changed_options.time_precision then
		timestamp_zero_rep_clear_cache()
	end
	update_config()
	update_human_times()
	Manager:disable('user', options.disable_elements)
	Elements:trigger('options')
	Elements:update_proximities()
	request_render()
end
opt.read_options(options, 'uosc', handle_options)
-- Normalize values
options.proximity_out = math.max(options.proximity_out, options.proximity_in + 1)
if options.chapter_ranges:sub(1, 4) == '^op|' then options.chapter_ranges = defaults.chapter_ranges end
if options.total_time and options.destination_time == 'playtime-remaining' then
	msg.warn('`total_time` is deprecated. Use `destination_time` instead.')
	options.destination_time = 'total'
elseif not itable_index_of({'total', 'playtime-remaining', 'time-remaining'}, options.destination_time) then
	options.destination_time = 'playtime-remaining'
end
if not itable_index_of({'left', 'right'}, options.top_bar_controls) then
	options.top_bar_controls = options.top_bar_controls == 'yes' and 'right' or nil
end

--[[ INTERNATIONALIZATION ]]
local intl = require('lib/intl')
t = intl.t
require('lib/char_conv')
fzy = require('lib/fzy')

--[[ CONFIG ]]
local config_defaults = {
	color = {
		foreground = serialize_rgba('ffffff').color,
		foreground_text = serialize_rgba('000000').color,
		background = serialize_rgba('000000').color,
		background_text = serialize_rgba('ffffff').color,
		window_border = serialize_rgba('000000').color,
		curtain = serialize_rgba('111111').color,
		success = serialize_rgba('a5e075').color,
		error = serialize_rgba('ff616e').color,
		match = serialize_rgba('69c5ff').color,
		heatmap = serialize_rgba('00adee').color,
	},
	opacity = {
		timeline = 0.9,
		position = 1,
		chapters = 0.8,
		slider = 0.9,
		slider_gauge = 1,
		controls = 0,
		speed = 0.6,
		menu = 1,
		submenu = 0.4,
		border = 1,
		title = 1,
		tooltip = 1,
		thumbnail = 1,
		curtain = 0.8,
		idle_indicator = 0.8,
		audio_indicator = 0.5,
		buffering_indicator = 0.3,
		playlist_position = 0.8,
		heatmap = 0.4,
	},
}
config = {
	version = uosc_version,
	open_subtitles_api_key = 'b0rd16N0bp7DETMpO4pYZwIqmQkZbYQr',
	open_subtitles_agent = 'uosc v' .. uosc_version,
	-- sets max rendering frequency in case the
	-- native rendering frequency could not be detected
	render_delay = 1 / 60,
	font = mp.get_property('options/osd-font'),
	osd_margin_x = mp.get_property('osd-margin-x'),
	osd_margin_y = mp.get_property('osd-margin-y'),
	osd_alignment_x = mp.get_property('osd-align-x'),
	osd_alignment_y = mp.get_property('osd-align-y'),
	refine = create_set(comma_split(options.refine)),
	types = {
		video = comma_split(options.video_types),
		audio = comma_split(options.audio_types),
		image = comma_split(options.image_types),
		subtitle = comma_split(options.subtitle_types),
		playlist = comma_split(options.playlist_types),
		media = comma_split(options.video_types
			.. ',' .. options.audio_types
			.. ',' .. options.image_types
			.. ',' .. options.playlist_types),
		load = {}, -- populated by update_load_types() below
	},
	stream_quality_options = comma_split(options.stream_quality_options),
	top_bar_flash_on = comma_split(options.top_bar_flash_on),
	chapter_ranges = (function()
		---@type table<string, string[]> Alternative patterns.
		local alt_patterns = {}
		if options.chapter_range_patterns and options.chapter_range_patterns ~= '' then
			for _, definition in ipairs(split(options.chapter_range_patterns, ';+ *')) do
				local name_patterns = split(definition, ' *:')
				local name, patterns = name_patterns[1], name_patterns[2]
				if name and patterns then alt_patterns[name] = split(patterns, ',') end
			end
		end

		---@type table<string, {color: string; opacity: number; patterns?: string[]}>
		local ranges = {}
		if options.chapter_ranges and options.chapter_ranges ~= '' then
			for _, definition in ipairs(split(options.chapter_ranges, ' *,+ *')) do
				local name_color = split(definition, ' *:+ *')
				local name, color = name_color[1], name_color[2]
				if name and color
					and name:match('^[a-zA-Z0-9_]+$') and color:match('^[a-fA-F0-9]+$')
					and (#color == 6 or #color == 8) then
					local range = serialize_rgba(name_color[2])
					range.patterns = alt_patterns[name]
					ranges[name_color[1]] = range
				end
			end
		end
		return ranges
	end)(),
	color = table_copy(config_defaults.color),
	opacity = table_copy(config_defaults.opacity),
	cursor_leave_fadeout_elements = {'timeline', 'volume', 'top_bar', 'controls'},
	timeline_step = 5,
	timeline_step_flag = '',
}

function update_load_types()
	local extensions = {}
	local types = create_set(comma_split(options.load_types:lower()))

	if types.same then
		types.same = nil
		if state and state.type then types[state.type] = true end
	end

	for _, name in ipairs(table_keys(types)) do
		local type_extensions = config.types[name]
		if type(type_extensions) == 'table' then
			itable_append(extensions, type_extensions)
		else
			msg.warn('Unknown load type: ' .. name)
		end
	end

	config.types.load = extensions
end

-- Updates config with values dependent on options
function update_config()
	-- Required environment config
	if options.autoload then
		mp.commandv('set', 'keep-open', 'yes')
		mp.commandv('set', 'keep-open-pause', 'no')
	end

	-- Adds `{element}_persistency` config properties with forced visibility states (e.g.: `{paused = true}`)
	for _, name in ipairs({'timeline', 'controls', 'volume', 'top_bar', 'speed'}) do
		local option_name = name .. '_persistency'
		local value, flags = options[option_name], {}
		if type(value) == 'string' then
			for _, state in ipairs(comma_split(value)) do flags[state] = true end
		end
		config[option_name] = flags
	end

	-- Opacity
	config.opacity = table_assign({}, config_defaults.opacity, serialize_key_value_list(options.opacity,
		function(value, key)
			return clamp(0, tonumber(value) or config.opacity[key], 1)
		end
	))

	-- Color
	config.color = table_assign({}, config_defaults.color, serialize_key_value_list(options.color, function(value)
		return serialize_rgba(value).color
	end))

	-- Global color shorthands
	fg, bg = config.color.foreground, config.color.background
	fgt, bgt = config.color.foreground_text, config.color.background_text

	-- Timeline step
	do
		local is_exact = options.timeline_step:sub(-1) == '!'
		config.timeline_step = tonumber(is_exact and options.timeline_step:sub(1, -2) or options.timeline_step)
		config.timeline_step_flag = is_exact and 'exact' or ''
	end

	-- Other
	update_load_types()
end
update_config()

-- [PHASE 3: SMART UPDATER WITH SELECTION MEMORY]
mp.register_script_message('control-update', function(command, submenu_id, active_index)
    mp.command(command)
    
    -- [FIX] Wait 50ms for asynchronous mpv commands (like Denoise) to fully process
    -- before telling the UI to redraw. This eliminates the visual "lag" race condition.
    mp.add_timeout(0.05, function()
        -- Persist the resulting Controls values in the user's untracked override file.
        mp.commandv("script-message", "persist-user-settings", command)

        -- 1. Refresh the Menu Content
        if Menu:is_open('menu') then
            local items = create_default_menu_items()
            local json = utils.format_json({ type = 'menu', items = items })
            mp.commandv("script-message-to", "uosc", "update-menu", json)
            if submenu_id and submenu_id ~= '' then
                mp.commandv("script-message-to", "uosc", "open-menu", json, submenu_id)
            end

        elseif Menu:is_open('controls') then
            local menu_data = create_controls_menu()
            menu_data.type = "controls"
            local json = utils.format_json(menu_data)
            mp.commandv("script-message-to", "uosc", "open-menu", json, submenu_id)
        end

        -- 2. Restore the Cursor/Selection Position
        -- If we passed an index (e.g. "2" for Decrease), force UOSC to select it now
        if active_index and active_index ~= '' then
            local type = Menu:is_open('menu') and 'menu' or 'controls'
            mp.commandv("script-message-to", "uosc", "select-menu-item", type, active_index, submenu_id)
        end
    end)
end)

-- [SUBTITLES ADDITION] Helper to scan the ~~/fonts folder
local cached_fonts = nil
local function get_available_fonts()
    if cached_fonts then return cached_fonts end
    cached_fonts = {}
    local fonts_dir = mp.command_native({"expand-path", "~~/fonts"})
    local files, err = utils.readdir(fonts_dir, "files")
    
    if files then
        for _, file in ipairs(files) do
            -- Match common font extensions (.ttf, .otf, .woff, .woff2)
            local name = file:match("^(.+)%.[tToO][tT][fF]$") or file:match("^(.+)%.[wW][oO][fF]2?$")
            if name then
                table.insert(cached_fonts, name)
            end
        end
        table.sort(cached_fonts)
    end
    return cached_fonts
end

-- Default menu items
-- Inside scripts/uosc/main.lua

-- [PHASE 5: FINAL CONTROLS (WITH SCALING SUITE)]
function create_controls_menu()
    -- Helpers
    local function prop(p) return mp.get_property(p) end
    local function is_true(p) return prop(p) == 'yes' end
    local function active(p, v) return prop(p) == v end
	
	-- Wrapper: Executes command + Refreshes menu + Selects specific index
    local function cmd(c, id, idx) 
        local menu_id = id or ''
        local item_idx = idx or ''
        return 'script-message-to uosc control-update "' .. c .. '" "' .. menu_id .. '" "' .. item_idx .. '"' 
    end
	
	-- Generator for Denoise Menus (+ / - / Reset)
    local function create_denoise_menu(title, param, step, submenu_id)
        local current = denoise[param]
        return {
            title = title,
            hint = tostring(current),
            id = submenu_id,
            items = {
                { title = 'Increase (+)', value = cmd('script-message-to uosc update-denoise ' .. param .. ' ' .. step, submenu_id, 1) },
                { title = 'Decrease (-)', value = cmd('script-message-to uosc update-denoise ' .. param .. ' -' .. step, submenu_id, 2) },
                { title = 'Reset', value = cmd('script-message-to uosc update-denoise ' .. param .. ' reset', submenu_id, 3) },
            }
        }
    end

    -- Generator for Value Menus (+ / - / Reset)
    local function create_adjust_menu(title, property, step, reset_val, unit, submenu_id)
        local current = tonumber(prop(property)) or 0
        local hint_str = unit and string.format("%s %s", current, unit) or tostring(current)
        return {
            title = title,
            hint = hint_str,
            id = submenu_id,
            items = {
                { title = 'Increase (+)', value = cmd('add ' .. property .. ' ' .. step, submenu_id, 1) },
                { title = 'Decrease (-)', value = cmd('add ' .. property .. ' -' .. step, submenu_id, 2) },
                { title = 'Reset (' .. reset_val .. ')', value = cmd('set ' .. property .. ' ' .. reset_val, submenu_id, 3) },
            }
        }
    end
	
	-- =============================================================================
    -- LOGIC: SUBTITLES MENU 
    -- =============================================================================
    -- 1. Build the dynamic font list
    local font_items = {
        -- MPV's native default or user's fallback
        { 
            title = 'Default', 
            active = (prop('sub-font') == '' or prop('sub-font') == 'sans-serif'),
            value = cmd("osd-msg set sub-font ''", 'sub_font_menu', 1) 
        }
    }
    
    local fonts = get_available_fonts()
    for i, font in ipairs(fonts) do
        table.insert(font_items, {
            title = font,
            active = active('sub-font', font),
            value = cmd("osd-msg set sub-font '" .. font .. "'", 'sub_font_menu', i + 1)
        })
    end

    -- 2. Build the Subtitle Menu tree based on mpv.conf settings
    local subtitles_menu = {
        title = 'Subtitles',
        id = 'subtitles_root',
        items = {
            -- A. Font Style Selector
            {
                title = 'Font Style >',
                hint = (prop('sub-font') ~= '' and prop('sub-font') or 'Default'),
                id = 'sub_font_menu',
                items = font_items
            },
            -- B. ASS Override Settings
            {
                title = 'ASS Override >',
                hint = prop('sub-ass-override') or 'no',
                id = 'sub_ass_override_menu',
                items = {
                    { title = 'no (Respect Script)', active = active('sub-ass-override', 'no'), value = cmd('set sub-ass-override no', 'sub_ass_override_menu', 1) },
                    { title = 'yes (Override Style)', active = active('sub-ass-override', 'yes'), value = cmd('set sub-ass-override yes', 'sub_ass_override_menu', 2) },
                    { title = 'force (Override All)', active = active('sub-ass-override', 'force'), value = cmd('set sub-ass-override force', 'sub_ass_override_menu', 3) },
                    { title = 'scale (Scale w/ Window)', active = active('sub-ass-override', 'scale'), value = cmd('set sub-ass-override scale', 'sub_ass_override_menu', 4) },
                    { title = 'strip (Remove Styling)', active = active('sub-ass-override', 'strip'), value = cmd('set sub-ass-override strip', 'sub_ass_override_menu', 5) },
                }
            },
            -- C. Values/Sliders (Defaults pulled from your mpv.conf)
            create_adjust_menu('Font Size', 'sub-font-size', 1, 40, nil, 'sub_font_size_menu'),
            create_adjust_menu('Blur', 'sub-blur', 0.1, 0.9, nil, 'sub_blur_menu'),
            create_adjust_menu('Gaussian Blur', 'sub-gauss', 0.1, 0.9, nil, 'sub_gauss_menu'),
            create_adjust_menu('Spacing', 'sub-spacing', 0.1, 0.5, nil, 'sub_spacing_menu'),
            
            -- D. Toggles
            { title = 'Scale with Window', active = is_true('sub-scale-with-window'), value = cmd('cycle sub-scale-with-window', 'subtitles_root', 7) },
            { title = 'Stretch Image Subs', active = is_true('stretch-image-subs-to-screen'), value = cmd('cycle stretch-image-subs-to-screen', 'subtitles_root', 8) },
            { title = 'Use Margins', active = is_true('sub-use-margins'), value = cmd('cycle sub-use-margins', 'subtitles_root', 9) },
            { title = 'Blend Subtitles', active = is_true('blend-subtitles'), value = cmd('cycle blend-subtitles', 'subtitles_root', 10) },
            { title = 'Fix Timing', active = is_true('sub-fix-timing'), value = cmd('cycle sub-fix-timing', 'subtitles_root', 11) },
        }
    }
    -- =============================================================================

    return {
        title = 'Controls',
        id = 'controls_root',
        items = {
            -- 1. MAIN TOGGLES
            { title = 'Interpolation (Motion)', active = is_true('interpolation'), value = cmd('cycle interpolation', 'controls_root', 1) },
            { title = 'Deband', active = is_true('deband'), value = cmd('cycle deband', 'controls_root', 2) },
			{
                title = 'Deband Settings >',
                id = 'deband_settings_menu',
                muted = not is_true('deband'),
                hint = is_true('deband') and 'Active' or 'Locked',
                items = {
                    create_adjust_menu('Iterations', 'deband-iterations', 1, 1, nil, 'deband_iter_menu'),
                    create_adjust_menu('Threshold', 'deband-threshold', 4, 32, nil, 'deband_thresh_menu'),
                    create_adjust_menu('Range', 'deband-range', 2, 16, nil, 'deband_range_menu'),
                    create_adjust_menu('Grain', 'deband-grain', 4, 48, nil, 'deband_grain_menu'),
                    { title = 'Reset Deband to Defaults', value = cmd('set deband-iterations 1; set deband-threshold 32; set deband-range 16; set deband-grain 48', 'deband_settings_menu', 5) },
                }
            },
            { title = 'Deinterlace', active = is_true('deinterlace'), value = cmd('cycle deinterlace', 'controls_root', 4) },
            
			-- [NEW] DENOISE FILTER
            { title = 'Denoise (hqdn3d)', active = denoise.enabled, value = cmd('script-message-to uosc update-denoise toggle', 'controls_root', 5) },
            {
                title = 'Denoise Settings >',
                id = 'denoise_settings_menu',
                muted = not denoise.enabled,
                hint = denoise.enabled and 'Active' or 'Locked',
                items = {
                    create_denoise_menu('Luma Spatial (ls)', 'ls', 1, 'denoise_ls_menu'),
                    create_denoise_menu('Chroma Spatial (cs)', 'cs', 1, 'denoise_cs_menu'),
                    create_denoise_menu('Luma Temporal (lt)', 'lt', 1, 'denoise_lt_menu'),
                    create_denoise_menu('Chroma Temporal (ct)', 'ct', 1, 'denoise_ct_menu'),
                }
            },
			
            -- 2. SYNC & COLORS
            {
                title = 'Synchronization',
                id = 'sync_root',
                items = {
                    create_adjust_menu('Audio Delay', 'audio-delay', 0.1, 0, 's', 'audio_delay_menu'),
                    create_adjust_menu('Subtitle Delay', 'sub-delay', 0.1, 0, 's', 'sub_delay_menu'),
                    create_adjust_menu('Subtitle Pos', 'sub-pos', 1, 100, '%', 'sub_pos_menu'),
                }
            },
            {
                title = 'Video Colors',
                id = 'color_root',
                items = {
                    { title = 'Reset All Colors', value = cmd('set contrast 0; set brightness 0; set gamma 0; set saturation 0; set hue 0', 'color_root', 1) },
                    create_adjust_menu('Contrast', 'contrast', 1, 0, nil, 'contrast_menu'),
                    create_adjust_menu('Brightness', 'brightness', 1, 0, nil, 'bright_menu'),
                    create_adjust_menu('Gamma', 'gamma', 1, 0, nil, 'gamma_menu'),
                    create_adjust_menu('Saturation', 'saturation', 1, 0, nil, 'sat_menu'),
                    create_adjust_menu('Hue', 'hue', 1, 0, nil, 'hue_menu'),
                }
            },
			
			-- [NEW] ADDING THE SUBTITLES MENU HERE
            subtitles_menu,

            -- 3. ADVANCED MENU
            {
                title = 'Advanced',
                id = 'advanced_root',
                items = {
                    -- A. Video Sync
                    {
                        title = 'Video Sync >',
                        hint = prop('video-sync'),
                        id = 'vsync_menu',
                        items = {
                            { title = 'Audio', active = active('video-sync', 'audio'), value = cmd('set video-sync audio', 'vsync_menu', 1) },
                            { title = 'Display Resample', active = active('video-sync', 'display-resample'), value = cmd('set video-sync display-resample', 'vsync_menu', 2) },
                            { title = 'Display Resample (Vdrop)', active = active('video-sync', 'display-resample-vdrop'), value = cmd('set video-sync display-resample-vdrop', 'vsync_menu', 3) },
							{ title = 'Display Vdrop', active = active('video-sync', 'display-vdrop'), value = cmd('set video-sync display-vdrop', 'vsync_menu', 4) },
                            { title = 'Desync', active = active('video-sync', 'desync'), value = cmd('set video-sync desync', 'vsync_menu', 5) },
                        }
                    },
                    -- B. Dither
                    {
                        title = 'Dither Settings >',
                        hint = prop('dither'),
                        id = 'dither_menu',
                        items = {
                            { title = 'fruit (Default)', active = active('dither', 'fruit'), value = cmd('set dither fruit', 'dither_menu', 1) },
                            { title = 'ordered', active = active('dither', 'ordered'), value = cmd('set dither ordered', 'dither_menu', 2) },
                            { title = 'Disable', active = active('dither', 'no'), value = cmd('set dither no', 'dither_menu', 3) },
                            { title = 'Depth: Auto', active = active('dither-depth', 'auto'), value = cmd('set dither-depth auto', 'dither_menu', 4) },
                            { title = 'Depth: 8', active = active('dither-depth', '8'), value = cmd('set dither-depth 8', 'dither_menu', 5) },
                            { title = 'Depth: 10', active = active('dither-depth', '10'), value = cmd('set dither-depth 10', 'dither_menu', 6) },
                        }
                    },
                    -- C. Hardware Decoding
                    {
                        title = 'Hardware Decoding >',
                        hint = prop('hwdec') or 'auto',
                        id = 'hwdec_menu',
                        items = {
                            { title = 'auto (Recommended)', active = active('hwdec', 'auto'), value = cmd('set hwdec auto', 'hwdec_menu', 1) },
                            { title = 'auto-copy', active = active('hwdec', 'auto-copy'), value = cmd('set hwdec auto-copy', 'hwdec_menu', 2) },
                            
                            { title = '=== Windows ===', value = 'ignore', bold = true },
                            { title = 'd3d11va (Modern Best)', active = active('hwdec', 'd3d11va'), value = cmd('set hwdec d3d11va', 'hwdec_menu', 4) },
                            { title = 'd3d11va-copy', active = active('hwdec', 'd3d11va-copy'), value = cmd('set hwdec d3d11va-copy', 'hwdec_menu', 5) },
                            { title = 'dxva2 (Legacy)', active = active('hwdec', 'dxva2'), value = cmd('set hwdec dxva2', 'hwdec_menu', 6) },
                            { title = 'dxva2-copy', active = active('hwdec', 'dxva2-copy'), value = cmd('set hwdec dxva2-copy', 'hwdec_menu', 7) },
                            
                            { title = '=== Linux ===', value = 'ignore', bold = true },
                            { title = 'vaapi (AMD/Intel Best)', active = active('hwdec', 'vaapi'), value = cmd('set hwdec vaapi', 'hwdec_menu', 9) },
                            { title = 'vaapi-copy', active = active('hwdec', 'vaapi-copy'), value = cmd('set hwdec vaapi-copy', 'hwdec_menu', 10) },
                            { title = 'vdpau (Legacy)', active = active('hwdec', 'vdpau'), value = cmd('set hwdec vdpau', 'hwdec_menu', 11) },
                            { title = 'vdpau-copy', active = active('hwdec', 'vdpau-copy'), value = cmd('set hwdec vdpau-copy', 'hwdec_menu', 12) },

                            { title = '=== Cross-Platform ===', value = 'ignore', bold = true },
                            { title = 'nvdec (Nvidia)', active = active('hwdec', 'nvdec'), value = cmd('set hwdec nvdec', 'hwdec_menu', 14) },
                            { title = 'nvdec-copy', active = active('hwdec', 'nvdec-copy'), value = cmd('set hwdec nvdec-copy', 'hwdec_menu', 15) },
                            { title = 'vulkan', active = active('hwdec', 'vulkan'), value = cmd('set hwdec vulkan', 'hwdec_menu', 16) },
                            { title = 'vulkan-copy', active = active('hwdec', 'vulkan-copy'), value = cmd('set hwdec vulkan-copy', 'hwdec_menu', 17) },

                            { title = '=== Software ===', value = 'ignore', bold = true },
                            { title = 'OFF (CPU Decoding)', active = active('hwdec', 'no'), value = cmd('set hwdec no', 'hwdec_menu', 19) },
                        }
                    },
					
					-- D. GPU API
                    {
                        title = 'GPU API >',
                        hint = prop('gpu-api') or 'auto',
                        id = 'gpu_api_menu',
                        items = {
                            { title = 'auto (Default)', active = active('gpu-api', 'auto'), value = cmd('set gpu-api auto', 'gpu_api_menu', 1) },
                            { title = 'vulkan (Modern/Fast)', active = active('gpu-api', 'vulkan'), value = cmd('set gpu-api vulkan', 'gpu_api_menu', 2) },
                            { title = 'd3d11 (Windows)', active = active('gpu-api', 'd3d11'), value = cmd('set gpu-api d3d11', 'gpu_api_menu', 3) },
                            { title = 'opengl (Legacy)', active = active('gpu-api', 'opengl'), value = cmd('set gpu-api opengl', 'gpu_api_menu', 4) },
                        }
                    },
                    -- E. GPU Context
                    {
                        title = 'GPU Context >',
                        hint = prop('gpu-context') or 'auto',
                        id = 'gpu_context_menu',
                        items = {
                            { title = 'auto (Default)', active = active('gpu-context', 'auto'), value = cmd('set gpu-context auto', 'gpu_context_menu', 1) },
                            { title = '=== Windows ===', value = 'ignore', bold = true },
                            { title = 'd3d11', active = active('gpu-context', 'd3d11'), value = cmd('set gpu-context d3d11', 'gpu_context_menu', 3) },
                            { title = 'winvk (Vulkan)', active = active('gpu-context', 'winvk'), value = cmd('set gpu-context winvk', 'gpu_context_menu', 4) },
                            { title = 'win (OpenGL)', active = active('gpu-context', 'win'), value = cmd('set gpu-context win', 'gpu_context_menu', 5) },
                            { title = '=== Linux ===', value = 'ignore', bold = true },
                            { title = 'waylandvk (Wayland Vulkan)', active = active('gpu-context', 'waylandvk'), value = cmd('set gpu-context waylandvk', 'gpu_context_menu', 7) },
                            { title = 'wayland (Wayland OpenGL)', active = active('gpu-context', 'wayland'), value = cmd('set gpu-context wayland', 'gpu_context_menu', 8) },
                            { title = 'x11vk (X11 Vulkan)', active = active('gpu-context', 'x11vk'), value = cmd('set gpu-context x11vk', 'gpu_context_menu', 9) },
                            { title = 'x11egl (X11 EGL/OpenGL)', active = active('gpu-context', 'x11egl'), value = cmd('set gpu-context x11egl', 'gpu_context_menu', 10) },
                        }
                    },
					
					-- F. Vulkan Settings
                    {
                        title = 'Vulkan Settings >',
                        id = 'vulkan_settings_menu',
                        muted = not active('gpu-api', 'vulkan'),
                        hint = active('gpu-api', 'vulkan') and 'Active' or 'Locked',
                        items = {
                            { title = '=== Async Compute ===', value = 'ignore', bold = true },
                            { title = 'yes (Default)', active = active('vulkan-async-compute', 'yes'), value = cmd('set vulkan-async-compute yes', 'vulkan_settings_menu', 2) },
                            { title = 'no', active = active('vulkan-async-compute', 'no'), value = cmd('set vulkan-async-compute no', 'vulkan_settings_menu', 3) },
                            
                            { title = '=== Queue Count ===', value = 'ignore', bold = true },
                            { title = '1 (Default)', active = active('vulkan-queue-count', '1'), value = cmd('set vulkan-queue-count 1', 'vulkan_settings_menu', 5) },
                            { title = '2', active = active('vulkan-queue-count', '2'), value = cmd('set vulkan-queue-count 2', 'vulkan_settings_menu', 6) },
                            { title = '3', active = active('vulkan-queue-count', '3'), value = cmd('set vulkan-queue-count 3', 'vulkan_settings_menu', 7) },

                            { title = '=== Async Transfer ===', value = 'ignore', bold = true },
                            { title = 'yes (Default)', active = active('vulkan-async-transfer', 'yes'), value = cmd('set vulkan-async-transfer yes', 'vulkan_settings_menu', 9) },
                            { title = 'no', active = active('vulkan-async-transfer', 'no'), value = cmd('set vulkan-async-transfer no', 'vulkan_settings_menu', 10) },

                            { title = 'Reset to Defaults', value = cmd('set vulkan-async-compute yes; set vulkan-queue-count 1; set vulkan-async-transfer yes', 'vulkan_settings_menu', 12) },
                        }
                    },
					
                    -- G. Scaling (FULL SUITE - UPDATED v1.9.6)
                    {
                        title = 'Scaling',
                        id = 'scaling_root',
                        items = {
                            -- Upscaler
                            {
                                title = 'Upscale >',
                                hint = prop('scale'),
                                id = 'scale_menu',
                                items = {
                                    { title = 'ewa_lanczossharp (Best)', active = active('scale', 'ewa_lanczossharp'), value = cmd('set scale ewa_lanczossharp', 'scale_menu', 1) },
                                    { title = 'spline64 (Sharp)', active = active('scale', 'spline64'), value = cmd('set scale spline64', 'scale_menu', 2) },
                                    { title = 'lanczos (Classic)', active = active('scale', 'lanczos'), value = cmd('set scale lanczos', 'scale_menu', 3) },
                                    { title = 'spline36 (Balanced)', active = active('scale', 'spline36'), value = cmd('set scale spline36', 'scale_menu', 4) },
                                    { title = 'bilinear (Fast)', active = active('scale', 'bilinear'), value = cmd('set scale bilinear', 'scale_menu', 5) },
                                }
                            },
                            -- Downscaler (Critical for 4K content)
                            {
                                title = 'Downscale >',
                                hint = prop('dscale'),
                                id = 'dscale_menu',
                                items = {
                                    { title = 'spline64 (Best/Sharp)', active = active('dscale', 'spline64'), value = cmd('set dscale spline64', 'dscale_menu', 1) },
                                    { title = 'mitchell (Smoothest)', active = active('dscale', 'mitchell'), value = cmd('set dscale mitchell', 'dscale_menu', 2) },
                                    { title = 'lanczos (Very Sharp)', active = active('dscale', 'lanczos'), value = cmd('set dscale lanczos', 'dscale_menu', 3) },
                                    { title = 'spline36 (Balanced)', active = active('dscale', 'spline36'), value = cmd('set dscale spline36', 'dscale_menu', 4) },
                                    { title = 'hermite (Soft)', active = active('dscale', 'hermite'), value = cmd('set dscale hermite', 'dscale_menu', 5) },
                                    { title = 'bilinear (Fast)', active = active('dscale', 'bilinear'), value = cmd('set dscale bilinear', 'dscale_menu', 6) },
									{ title = 'catmull_rom (Smooth)', active = active('dscale', 'catmull_rom'), value = cmd('set dscale catmull_rom', 'dscale_menu', 7) },
                                }
                            },
                            -- Chromascaler (Color)
                            {
                                title = 'Chromascale >',
                                hint = prop('cscale'),
                                id = 'cscale_menu',
                                items = {
                                    { title = 'spline64 (Best)', active = active('cscale', 'spline64'), value = cmd('set cscale spline64', 'cscale_menu', 1) },
                                    { title = 'spline36 (Balanced)', active = active('cscale', 'spline36'), value = cmd('set cscale spline36', 'cscale_menu', 2) },
                                    { title = 'lanczos (Sharp)', active = active('cscale', 'lanczos'), value = cmd('set cscale lanczos', 'cscale_menu', 3) },
                                    { title = 'bilinear (Fast)', active = active('cscale', 'bilinear'), value = cmd('set cscale bilinear', 'cscale_menu', 4) },
                                }
                            },
                            -- Temporalscaler (Interpolation Method)
                            {
                                title = 'Temporalscale >',
                                hint = prop('tscale'),
                                id = 'tscale_menu',
                                items = {
                                    { title = 'oversample (Sharpest)', active = active('tscale', 'oversample'), value = cmd('set tscale oversample', 'tscale_menu', 1) },
                                    { title = 'linear', active = active('tscale', 'linear'), value = cmd('set tscale linear', 'tscale_menu', 2) },
                                    { title = 'catmull_rom', active = active('tscale', 'catmull_rom'), value = cmd('set tscale catmull_rom', 'tscale_menu', 3) },
                                    { title = 'mitchell (Soft)', active = active('tscale', 'mitchell'), value = cmd('set tscale mitchell', 'tscale_menu', 4) },
                                    { title = 'bicubic', active = active('tscale', 'bicubic'), value = cmd('set tscale bicubic', 'tscale_menu', 5) },
									{ title = 'sphinx (Balanced)', active = active('tscale', 'sphinx'), value = cmd('set tscale sphinx', 'tscale_menu', 6) },
									{ title = 'box', active = active('tscale', 'box'), value = cmd('set tscale box', 'tscale_menu', 7) },
									{ title = 'quadric', active = active('tscale', 'quadric'), value = cmd('set tscale quadric', 'tscale_menu', 8) },
									{ title = 'spline16', active = active('tscale', 'spline16'), value = cmd('set tscale spline16', 'tscale_menu', 9) },
                                }
                            },
                            -- Toggles
                            { title = 'Linear Upscaling', active = is_true('linear-upscaling'), value = cmd('cycle linear-upscaling', 'scaling_root', 5) },
                            { title = 'Sigmoid Upscaling', active = is_true('sigmoid-upscaling'), value = cmd('cycle sigmoid-upscaling', 'scaling_root', 6) },
                            { title = 'Correct Downscaling', active = is_true('correct-downscaling'), value = cmd('cycle correct-downscaling', 'scaling_root', 7) },
                            { title = 'Linear Downscaling', active = is_true('linear-downscaling'), value = cmd('cycle linear-downscaling', 'scaling_root', 8) },
                        }
                    },
					
                }
            },
        }
    }
end

-- [PHASE 1: BUTTON BINDING]
mp.add_key_binding(nil, "open-controls-menu", function()
    local menu_data = create_controls_menu()
    menu_data.type = "controls"
    local json = utils.format_json(menu_data)
    mp.commandv("script-message-to", "uosc", "open-menu", json)
end)

local function get_user_data(prop, default)
    local val = mp.get_property_native(prop)
    if val == nil then return default end
    if type(val) == "string" then
        val = val:gsub('^"', ''):gsub('"$', '')
    end
    return val
end

-- ── Modular Controls Bar & Mutual Exclusion ──────────────────────────────────
local refresh_master_menu = nil
local schedule_menu_refresh = nil
local default_bar_controls = {
    subtitles    = true,  -- 💬 Subtítulos & Traducción
    audio        = true,  -- 🎧 Pistas de audio
    volume_boost = true,  -- 📢 Amplificador de Volumen (Boost)
    equalizer    = false, -- 🎚️ Ecualizador de audio
    ambient_crop = false, -- 🖼️ Ambient Crop
    ab_loop      = false, -- 🔁 Loop A-B de Segmento
    loop         = true,  -- 🔁 Repetir archivo
    shuffle      = true,  -- 🔀 Mezclar lista
    speed        = true,  -- ⏱️ Ajustar velocidad
    screenshot   = true,  -- 📸 Captura de pantalla
    playlist     = true,  -- 📜 Lista de reproducción
    stats        = true,  -- 📊 Estadísticas e info
}

local active_bar_controls = table_copy(default_bar_controls)

local uosc_script_opts_dir = mp.command_native({"expand-path", "~~/script-opts"})
local uosc_controls_conf_path = mp.command_native({"expand-path", "~~/script-opts/uosc_controls.conf"})
local uosc_script_opts_ensured = false

local function load_bar_controls()
    local f = io.open(uosc_controls_conf_path, "r")
    if not f then return table_copy(default_bar_controls) end
    local settings = table_copy(default_bar_controls)
    for line in f:lines() do
        local key, val = line:match("^([%w_]+)%s*=%s*(%w+)")
        if key and val and settings[key] ~= nil then
            settings[key] = (val == "yes" or val == "true")
        end
    end
    f:close()
    return settings
end

local function save_bar_controls(settings)
    if not uosc_script_opts_ensured then
        local info = utils.file_info(uosc_script_opts_dir)
        if not info or not info.is_dir then
            local is_win = package.config:sub(1, 1) == "\\"
            if is_win then
                local clean_dir = (uosc_script_opts_dir:gsub("/", "\\"))
                mp.command_native({
                    name = "subprocess",
                    playback_only = false,
                    args = {"cmd.exe", "/c", "mkdir", clean_dir},
                    capture_stdout = true, capture_stderr = true
                })
            else
                mp.command_native({
                    name = "subprocess",
                    playback_only = false,
                    args = {"mkdir", "-p", uosc_script_opts_dir},
                    capture_stdout = true, capture_stderr = true
                })
            end
        end
        uosc_script_opts_ensured = true
    end
    local f = io.open(uosc_controls_conf_path, "w")
    if f then
        local order = {"subtitles", "audio", "volume_boost", "equalizer", "ambient_crop", "ab_loop", "loop", "shuffle", "speed", "screenshot", "playlist", "stats"}
        for _, k in ipairs(order) do
            f:write(k .. "=" .. (settings[k] and "yes" or "no") .. "\n")
        end
        f:close()
    end
end

local function build_controls_string(cfg)
    local left_items = {"menu"}
    if cfg.subtitles then table.insert(left_items, "command:subtitles:script-message open-subtitles-menu?Subtítulos y Traducción") end
    if cfg.audio then table.insert(left_items, "command:graphic_eq:script-binding uosc/audio#audio>1?Pistas de Audio") end
    if cfg.volume_boost then table.insert(left_items, "button:volume_boost?Amplificador de Volumen (Boost)") end
    if cfg.equalizer then table.insert(left_items, "command:tune:script-message open-equalizer-menu?Ecualizador de Audio") end
    if cfg.ambient_crop then table.insert(left_items, "button:ambient_crop?Modo Ambient Crop") end
    if cfg.ab_loop then table.insert(left_items, "button:ab_loop?Loop A-B de Segmento") end
    if cfg.loop then table.insert(left_items, "cycle:repeat_one:loop-file:no/inf!?Repetir Archivo") end
    if cfg.shuffle then table.insert(left_items, "toggle:shuffle:shuffle?Mezclar Lista") end

    local center_items = {
        "space",
        "<has_chapter>command:fast_rewind:add chapter -1?Capítulo Anterior",
        "prev",
        "play-pause",
        "next",
        "<has_chapter>command:fast_forward:add chapter 1?Siguiente Capítulo",
        "space"
    }

    local right_items = {}
    if cfg.speed then table.insert(right_items, "command:speed:script-message toggle-speed-popover?Ajustar Velocidad") end
    if cfg.screenshot then table.insert(right_items, "command:photo_camera:async screenshot?Captura de Pantalla") end
    if cfg.playlist then table.insert(right_items, "playlist") end
    if cfg.stats then table.insert(right_items, "command:info:script-binding stats/display-stats-toggle?Estadísticas e Información") end
    table.insert(right_items, "fullscreen")

    local all_items = {}
    for _, it in ipairs(left_items) do table.insert(all_items, it) end
    for _, it in ipairs(center_items) do table.insert(all_items, it) end
    for _, it in ipairs(right_items) do table.insert(all_items, it) end

    return table.concat(all_items, ",")
end

local function apply_bar_controls(cfg)
    active_bar_controls = cfg
    local c_str = build_controls_string(cfg)
    options.controls = c_str
    if Elements and Elements.controls then
        Elements.controls:on_options()
        Elements:trigger('options')
        Elements:update_proximities()
        request_render()
    end
end

-- Initialize controls configuration on startup
active_bar_controls = load_bar_controls()
apply_bar_controls(active_bar_controls)

-- ── Interactive Controls Customizer Menu ─────────────────────────────────────
local function create_controls_customizer_items()
    local definitions = {
        {id = "subtitles",    label = "💬 Subtítulos & Traducción"},
        {id = "audio",        label = "🎧 Pistas de audio"},
        {id = "volume_boost", label = "📢 Amplificador de Volumen (Boost)"},
        {id = "equalizer",    label = "🎚️ Ecualizador de audio"},
        {id = "ambient_crop", label = "🖼️ Modo Ambient Crop"},
        {id = "ab_loop",      label = "🔁 Loop A-B de Segmento"},
        {id = "loop",         label = "🔁 Repetir archivo"},
        {id = "shuffle",      label = "🔀 Mezclar lista"},
        {id = "speed",        label = "⏱️ Ajustar velocidad"},
        {id = "screenshot",   label = "📸 Captura de pantalla"},
        {id = "playlist",     label = "📜 Lista de reproducción"},
        {id = "stats",        label = "📊 Información y estadísticas"},
    }

    local items = {
        {
            title = "🛠️ Personalizar barra de controles",
            hint = "Exclusión mutua: Si está en barra, desaparece del menú",
            muted = true
        }
    }

    for _, def in ipairs(definitions) do
        local is_on_bar = (active_bar_controls[def.id] == true)
        local status_text = is_on_bar and "Visible en barra (Oculto en menú)" or "Oculto en barra (Visible en menú)"
        table.insert(items, {
            title = (is_on_bar and "● " or "○ ") .. def.label,
            hint = status_text,
            active = is_on_bar,
            value = "script-message toggle-bar-control " .. def.id,
            keep_open = true
        })
    end

    table.insert(items, {
        title = "↺ Restablecer barra por defecto",
        hint = "Configuración inicial",
        value = "script-message reset-bar-controls",
        keep_open = true,
        separator = true
    })

    return items
end

local function refresh_controls_customizer()
    local menu = Menu:is_open('controls_customizer')
    if menu then
        menu:update_items(create_controls_customizer_items())
        request_render()
    end
end

mp.register_script_message("open-controls-customizer", function()
    local menu_data = {
        type = "controls_customizer",
        title = "🛠️ Personalizar barra de controles",
        items = create_controls_customizer_items()
    }
    local json = utils.format_json(menu_data)
    mp.commandv("script-message-to", "uosc", "open-menu", json)
end)

mp.register_script_message("toggle-bar-control", function(key)
    if key and active_bar_controls[key] ~= nil then
        active_bar_controls[key] = not active_bar_controls[key]
        save_bar_controls(active_bar_controls)
        apply_bar_controls(active_bar_controls)
        refresh_controls_customizer()
        if refresh_master_menu then refresh_master_menu() end
        local state_str = active_bar_controls[key] and "VISIBLE EN BARRA" or "OCULTO DE BARRA (EN MENÚ)"
        mp.commandv("script-message-to", "uosc", "dynamic-island-message", "Barra: " .. key:upper() .. " -> " .. state_str)
    end
end)

mp.register_script_message("reset-bar-controls", function()
    active_bar_controls = table_copy(default_bar_controls)
    save_bar_controls(active_bar_controls)
    apply_bar_controls(active_bar_controls)
    refresh_controls_customizer()
    if refresh_master_menu then refresh_master_menu() end
    mp.commandv("script-message-to", "uosc", "dynamic-island-message", "Barra de controles restablecida")
end)

-- ── Spatial Audio Profiles & Channel Mode Submenu Builders ────────────────────
local function build_spatial_audio_submenu_items(cur_audio_mode)
    local profiles = {
        {id = "normal",      name = "🔊 Estándar (Directo)",                hint = "Audio original sin filtros espaciales"},
        {id = "dolby_atmos", name = "🎬 Dolby Atmos / Surround Virtual",    hint = "Cine 3D (120°) + Subgraves LFE + Diálogos"},
        {id = "dolby_voice", name = "🗣️ Dolby Voice (Claridad Vocal 3D)",   hint = "Realce de canal central + Envolvente suave"},
        {id = "dts_x",       name = "🌐 DTS:X / Neural:X Espacial",         hint = "Escena 3D amplia (Haas) + TruBass + Detalle"},
        {id = "spatial",     name = "🎧 Binaural Pro (Audífonos / BS2B)",   hint = "Crossfeed acústico natural sin fatiga"},
        {id = "music_wide",  name = "🎵 Estéreo Expandido (Música / Live)", hint = "Ampliación de fase + Nitidez Crystalizer"},
        {id = "night",       name = "🌙 Modo Nocturno (DRC Inteligente)",   hint = "Nivela explosiones y susurros"},
        {id = "passthrough", name = "🔌 Passthrough HDMI / Óptico",         hint = "Bitstream puro Dolby/DTS a receptor externo"},
    }
    local sub_items = {}
    for _, p in ipairs(profiles) do
        local is_act = (cur_audio_mode == p.id)
        table.insert(sub_items, {
            title = (is_act and "● " or "○ ") .. p.name,
            hint = p.hint,
            active = is_act,
            value = "script-message set-audio-mode " .. p.id,
            keep_open = true
        })
    end
    return sub_items
end

local function build_audio_channels_submenu_items(cur_channels)
    local modes = {
        {id = "auto-safe", name = "🔄 Automático (Nativo)",            hint = "Se adapta al hardware conectado"},
        {id = "mono",      name = "🔈 Mono (1.0 - Canal Único)",       hint = "Mezcla todos los canales en uno"},
        {id = "stereo",    name = "🔉 Estéreo (2.0 - Izq / Der)",      hint = "Configuración clásica para audífonos y 2.0"},
        {id = "2.1",       name = "🔊 Estéreo 2.1 (Con Subwoofer)",    hint = "Frontales Izq/Der + Subgraves LFE"},
        {id = "4.0",       name = " चारों Cuadrafónico (4.0)",              hint = "Frontales + Traseros envolventes"},
        {id = "5.1",       name = "🎥 Surround 5.1 (Cine en Casa)",    hint = "6 canales (Frontales, Central, LFE, Traseros)"},
        {id = "7.1",       name = "🏛️ Surround 7.1 (Cine Completo)",   hint = "8 canales (Frontales, Central, LFE, Lat, Tras)"},
    }
    -- Clean icon for 4.0
    modes[5].name = "🎛️ Cuadrafónico (4.0)"
    local sub_items = {}
    for _, m in ipairs(modes) do
        local is_act = (cur_channels == m.id)
        table.insert(sub_items, {
            title = (is_act and "● " or "○ ") .. m.name,
            hint = m.hint,
            active = is_act,
            value = "script-message set-audio-channels " .. m.id,
            keep_open = true
        })
    end
    return sub_items
end

local function build_volume_boost_submenu_items(cur_boost)
    local modes = {
        {id = "off",    name = "🔇 Desactivado (0 dB)",             hint = "Volumen natural sin ganancia adicional"},
        {id = "soft",   name = "📢 Suave (+4 dB)",                  hint = "Realce ligero con limitador anti-clipping"},
        {id = "medium", name = "🔊 Medio (+8 dB)",                  hint = "Nivel cine / equiparable a Modo Noche"},
        {id = "high",   name = "🚀 Fuerte (+12 dB)",                hint = "Gran potencia para pistas muy silenciosas"},
        {id = "auto",   name = "🌙 Auto DRC (Nivelador Continuo)",  hint = "Misma nivelación potente del Modo Noche en cualquier modo"},
    }
    local sub_items = {}
    for _, m in ipairs(modes) do
        local is_act = (cur_boost == m.id)
        table.insert(sub_items, {
            title = (is_act and "● " or "○ ") .. m.name,
            hint = m.hint,
            active = is_act,
            value = "script-message set-volume-boost " .. m.id,
            keep_open = true
        })
    end
    return sub_items
end

local function build_video_profiles_submenu_items(cur_video_mode)
    local profiles = {
        {id = "auto",        name = "✨ Automático (Adaptativo)",           hint = "Detecta Anime, Películas o Series automáticamente"},
        {id = "low_power",   name = "🔋 Bajo Consumo (AMD CAS + Spline36)", hint = "Nitidez adaptativa ligera ideal para laptops"},
        {id = "balanced",    name = "⚖️ Intermedio / Equilibrado",          hint = "SSimSuperRes + KrigBilateral (Calidad/Rendimiento)"},
        {id = "series",      name = "📺 Series, K-Drama & TV",              hint = "Anti-Banding + KrigBilateral + AMD CAS (Streaming)"},
        {id = "anime_light", name = "🌸 Anime Ligero (Fast Restore)",       hint = "Restauración de trazos ligera sin saturar la GPU"},
        {id = "anime",       name = "🔥 Anime Ultra (ArtCNN C4F32)",        hint = "Máxima definición neuronal de líneas y bordes"},
        {id = "fidelity",    name = "🎬 Cine & Películas Ultra (FSRCNNX)",  hint = "Texturas cinematográficas + Anti-ringing"},
        {id = "clean",       name = "💎 Estándar Limpio (Spline64 Puro)",   hint = "Escalado clásico de alta precisión sin shaders"},
        {id = "eco",         name = "⚡ Modo Eco Extremo (Ahorro Batería)", hint = "Bilinear puro sin post-procesado"},
    }
    local sub_items = {}
    for _, p in ipairs(profiles) do
        local is_act = (cur_video_mode == p.id)
        table.insert(sub_items, {
            title = (is_act and "● " or "○ ") .. p.name,
            hint = p.hint,
            active = is_act,
            value = "script-message set-video-mode " .. p.id,
            keep_open = true
        })
    end
    return sub_items
end

local function build_skip_intro_submenu_items(cur_skip_mode)
    local modes = {
        {id = "manual",   name = "🖐️ Manual (Mostrar aviso Tab)",          hint = "Muestra aviso cuando detecta Opening/Ending"},
        {id = "auto_all", name = "⚡ Automático (Saltar Opening y Ending)", hint = "Salta automáticamente Intro y Créditos"},
        {id = "auto_op",  name = "⏭️ Automático (Solo Opening)",           hint = "Salta Opening automáticamente; Ending manual"},
        {id = "off",      name = "🚫 Desactivado",                         hint = "No detectar ni saltar capítulos"},
    }
    local sub_items = {}
    for _, m in ipairs(modes) do
        local is_act = (cur_skip_mode == m.id)
        table.insert(sub_items, {
            title = (is_act and "● " or "○ ") .. m.name,
            hint = m.hint,
            active = is_act,
            value = "script-message set-skip-intro-mode " .. m.id,
            keep_open = true
        })
    end
    return sub_items
end

-- ── Global Audio & Subtitle Language Priority Configurator (1.E Replacement) ──
local lang_priority_catalog = {
    {group = "es,spa,es-419,es-ES,lat", primary = "es", label = "Español (es, spa, lat, es-419)"},
    {group = "ja,jpn",                  primary = "ja", label = "Japonés (ja, jpn)"},
    {group = "en,eng",                  primary = "en", label = "Inglés (en, eng)"},
    {group = "ko,kor",                  primary = "ko", label = "Coreano (ko, kor)"},
    {group = "zh,chi,zho,chs,cht",      primary = "zh", label = "Chino (zh, chi, zho)"},
    {group = "fr,fre,fra",              primary = "fr", label = "Francés (fr, fre, fra)"},
    {group = "pt,por,pt-BR,pt-PT",      primary = "pt", label = "Portugués (pt, por, pt-BR)"},
    {group = "de,ger,deu",              primary = "de", label = "Alemán (de, ger, deu)"},
    {group = "it,ita",                  primary = "it", label = "Italiano (it, ita)"},
    {group = "ru,rus",                  primary = "ru", label = "Ruso (ru, rus)"},
}

local function get_token_rank_in_csv(csv_str, primary_code)
    local rank = 0
    local seen_groups = {}
    for token in (csv_str or ""):gmatch("[^,%s]+") do
        local t_low = token:lower()
        for _, entry in ipairs(lang_priority_catalog) do
            for g_tok in entry.group:gmatch("[^,%s]+") do
                if g_tok:lower() == t_low then
                    if not seen_groups[entry.primary] then
                        rank = rank + 1
                        seen_groups[entry.primary] = rank
                    end
                end
            end
        end
    end
    return seen_groups[primary_code]
end

local function create_lang_prefs_items()
    local alang_str = get_user_data("user-data/controller/alang-pref", mp.get_property("alang", ""))
    local slang_str = get_user_data("user-data/controller/slang-pref", mp.get_property("slang", ""))

    local alang_items = {
        {
            title = "Cola actual: " .. (alang_str ~= "" and alang_str or "(Vacía)"),
            hint = "Orden de llegada / prioridad",
            muted = true,
            selectable = false
        },
        {
            title = "⌨️ Escribir códigos manualmente (Texto libre)...",
            hint = "Ej: ja,jpn,es,spa,en",
            value = "script-message open-alang-input",
            separator = true
        },
        {
            title = "── Presets Rápidos de Audio ──────────────────",
            muted = true,
            selectable = false
        },
        {title = "⚡ Anime / Japonés → Español → Inglés", hint = "ja,jpn,es,spa,en,eng", value = "script-message set-alang-pref ja,jpn,es,spa,en,eng", keep_open = true},
        {title = "⚡ K-Drama / Coreano → Español → Inglés", hint = "ko,kor,es,spa,en,eng", value = "script-message set-alang-pref ko,kor,es,spa,en,eng", keep_open = true},
        {title = "⚡ Español → Inglés → Japonés", hint = "es,spa,es-419,en,eng,ja,jpn", value = "script-message set-alang-pref es,spa,es-419,en,eng,ja,jpn", keep_open = true},
        {title = "⚡ Inglés Original → Español", hint = "en,eng,es,spa", value = "script-message set-alang-pref en,eng,es,spa", keep_open = true, separator = true},
        {
            title = "── Armar Cola por Orden de Clic ──────────────",
            hint = "Clic para añadir al final o quitar",
            muted = true,
            selectable = false
        },
    }

    for _, entry in ipairs(lang_priority_catalog) do
        local rank = get_token_rank_in_csv(alang_str, entry.primary)
        local is_in = (rank ~= nil)
        table.insert(alang_items, {
            title = (is_in and string.format("● [#%d] ", rank) or "○ [ + ] ") .. entry.label,
            hint = is_in and ("Prioridad #" .. rank .. " (Clic para quitar)") or "Clic para encolar",
            active = is_in,
            value = "script-message toggle-alang-item " .. entry.group,
            keep_open = true
        })
    end

    table.insert(alang_items, {
        title = "🗑️ Vaciar cola de audio",
        hint = "Reiniciar para armar desde #1",
        value = "script-message clear-alang-pref",
        keep_open = true,
        separator = true
    })

    local slang_items = {
        {
            title = "Cola actual: " .. (slang_str ~= "" and slang_str or "(Vacía)"),
            hint = "Orden de llegada / prioridad",
            muted = true,
            selectable = false
        },
        {
            title = "⌨️ Escribir códigos manualmente (Texto libre)...",
            hint = "Ej: es,spa,es-419,en,eng",
            value = "script-message open-slang-input",
            separator = true
        },
        {
            title = "── Presets Rápidos de Subtítulos ─────────────",
            muted = true,
            selectable = false
        },
        {title = "⚡ Español (Todos) → Inglés", hint = "es,spa,es-419,es-ES,lat,en,eng", value = "script-message set-slang-pref es,spa,es-419,es-ES,lat,en,eng", keep_open = true},
        {title = "⚡ Inglés → Español", hint = "en,eng,es,spa,es-419", value = "script-message set-slang-pref en,eng,es,spa,es-419", keep_open = true},
        {title = "⚡ Español → Japonés → Inglés", hint = "es,spa,ja,jpn,en,eng", value = "script-message set-slang-pref es,spa,ja,jpn,en,eng", keep_open = true, separator = true},
        {
            title = "── Armar Cola por Orden de Clic ──────────────",
            hint = "Clic para añadir al final o quitar",
            muted = true,
            selectable = false
        },
    }

    for _, entry in ipairs(lang_priority_catalog) do
        local rank = get_token_rank_in_csv(slang_str, entry.primary)
        local is_in = (rank ~= nil)
        table.insert(slang_items, {
            title = (is_in and string.format("● [#%d] ", rank) or "○ [ + ] ") .. entry.label,
            hint = is_in and ("Prioridad #" .. rank .. " (Clic para quitar)") or "Clic para encolar",
            active = is_in,
            value = "script-message toggle-slang-item " .. entry.group,
            keep_open = true
        })
    end

    table.insert(slang_items, {
        title = "🗑️ Vaciar cola de subtítulos",
        hint = "Reiniciar para armar desde #1",
        value = "script-message clear-slang-pref",
        keep_open = true,
        separator = true
    })

    return {
        {
            title = "🌐 Preferencias de Idioma por Orden de Llegada",
            hint = "Se guarda automáticamente sin editar archivos",
            muted = true,
            selectable = false,
            separator = true
        },
        {
            id = "alang_priority_submenu",
            title = "🎧 Prioridad de Audio (alang)",
            hint = alang_str ~= "" and alang_str or "Sin definir",
            items = alang_items
        },
        {
            id = "slang_priority_submenu",
            title = "💬 Prioridad de Subtítulos (slang)",
            hint = slang_str ~= "" and slang_str or "Sin definir",
            items = slang_items
        }
    }
end

local function refresh_lang_prefs_menu()
    local menu = Menu:is_open('lang_prefs_menu')
    if menu then
        menu:update_items(create_lang_prefs_items())
        request_render()
    elseif Menu:is_open('alang_input_menu') or Menu:is_open('slang_input_menu') then
        mp.commandv("script-message-to", "uosc", "open-lang-prefs-menu")
    end
end
mp.register_script_message("refresh-lang-prefs-menu", function()
    mp.add_timeout(0, refresh_lang_prefs_menu)
end)

mp.register_script_message("open-lang-prefs-menu", function()
    local menu_data = {
        type = "lang_prefs_menu",
        title = "🌐 Idiomas Preferidos (Audio & Subtítulos)",
        items = create_lang_prefs_items()
    }
    local menu = Menu:is_open('lang_prefs_menu')
    if menu then
        menu:update(menu_data)
        request_render()
    else
        open_command_menu(menu_data)
    end
end)

mp.register_script_message("open-alang-input", function()
    local cur = get_user_data("user-data/controller/alang-pref", mp.get_property("alang", ""))
    local json = utils.format_json({
        type = "alang_input_menu",
        title = "Escribir Cola de Audio (alang)",
        search_style = "palette",
        search_debounce = "submit",
        on_search = "script-message set-alang-pref",
        items = {
            {
                title = "⌨️ Escribe los códigos separados por coma y pulsa ENTER",
                hint = "Actual: " .. (cur ~= "" and cur or "Vacío"),
                muted = true,
                selectable = false,
                separator = true
            },
            {title = "Ejemplo 1: ja,jpn,es,spa,en,eng", value = "script-message set-alang-pref ja,jpn,es,spa,en,eng"},
            {title = "Ejemplo 2: ko,kor,es,spa,en,eng", value = "script-message set-alang-pref ko,kor,es,spa,en,eng"},
            {title = "Ejemplo 3: es,spa,es-419,en,eng", value = "script-message set-alang-pref es,spa,es-419,en,eng"},
            {title = "↩ Volver a Preferencias de Idioma", value = "script-message open-lang-prefs-menu", separator = true},
        }
    })
    mp.commandv("script-message-to", "uosc", "open-menu", json)
end)

mp.register_script_message("open-slang-input", function()
    local cur = get_user_data("user-data/controller/slang-pref", mp.get_property("slang", ""))
    local json = utils.format_json({
        type = "slang_input_menu",
        title = "Escribir Cola de Subtítulos (slang)",
        search_style = "palette",
        search_debounce = "submit",
        on_search = "script-message set-slang-pref",
        items = {
            {
                title = "⌨️ Escribe los códigos separados por coma y pulsa ENTER",
                hint = "Actual: " .. (cur ~= "" and cur or "Vacío"),
                muted = true,
                selectable = false,
                separator = true
            },
            {title = "Ejemplo 1: es,spa,es-419,es-ES,lat,en,eng", value = "script-message set-slang-pref es,spa,es-419,es-ES,lat,en,eng"},
            {title = "Ejemplo 2: en,eng,es,spa",                  value = "script-message set-slang-pref en,eng,es,spa"},
            {title = "Ejemplo 3: es,spa,ja,jpn,en,eng",           value = "script-message set-slang-pref es,spa,ja,jpn,en,eng"},
            {title = "↩ Volver a Preferencias de Idioma",         value = "script-message open-lang-prefs-menu", separator = true},
        }
    })
    mp.commandv("script-message-to", "uosc", "open-menu", json)
end)

-- ── Interactive Audio Equalizer Menu ──────────────────────────────────────────
local function build_eq_fader(gain)
    gain = math.max(-12, math.min(12, gain or 0))
    if gain == 0 then
        return "─────●─────"
    end
    local slots = {"─", "─", "─", "─", "─", "│", "─", "─", "─", "─", "─"}
    if gain > 0 then
        local step = math.min(5, math.max(1, math.floor(gain / 12 * 5 + 0.5)))
        slots[6 + step] = "●"
    else
        local step = math.min(5, math.max(1, math.floor(math.abs(gain) / 12 * 5 + 0.5)))
        slots[6 - step] = "●"
    end
    return table.concat(slots)
end

local function create_equalizer_items()
    local cur_profile = get_user_data("user-data/controller/eq-profile", "off")
    local cur_label = get_user_data("user-data/controller/eq-label", "Plano (Desactivado)")
    local audio_mode = get_user_data("user-data/controller/audio-mode", "normal")
    local audio_label = get_user_data("user-data/controller/audio-label", "Estándar (Directo)")
    local audio_channels = get_user_data("user-data/controller/audio-channels", "auto-safe")
    local audio_channels_label = get_user_data("user-data/controller/audio-channels-label", "Automático (Nativo)")
    local volume_boost = get_user_data("user-data/controller/volume-boost", "off")
    local volume_boost_label = get_user_data("user-data/controller/volume-boost-label", "Desactivado (0 dB)")
    local audio_delay = mp.get_property_number("audio-delay", 0) or 0
    local audio_delay_str = string.format("%s%.2fs", audio_delay > 0.001 and "+" or "", audio_delay)

    local items = {
        {
            id = "eq_spatial_submenu",
            title = "🎧 Sonido Espacial (Dolby / DTS)",
            hint = audio_label,
            items = build_spatial_audio_submenu_items(audio_mode)
        },
        {
            id = "eq_channels_submenu",
            title = "🔈 Modo de Canales (Mono / 2.0 / 5.1 / 7.1)",
            hint = audio_channels_label,
            items = build_audio_channels_submenu_items(audio_channels)
        },
        {
            id = "eq_volume_boost_submenu",
            title = "📢 Amplificador de Volumen (Boost)",
            hint = volume_boost_label,
            items = build_volume_boost_submenu_items(volume_boost)
        },
        {
            id = "eq_audio_delay_submenu",
            title = "⏱️ Sincronización de Audio (Delay)",
            hint = math.abs(audio_delay) < 0.005 and "0.00s (Exacto)" or audio_delay_str,
            separator = true,
            items = {
                {
                    title = "Desfase actual de audio: " .. audio_delay_str,
                    hint = "Positivo = retrasa el audio",
                    muted = true
                },
                {title = "⏩ +0.50s (Retrasar medio segundo)",   value = "script-message add-audio-delay 0.50",  keep_open = true},
                {title = "▶️ +0.10s (Ajuste fino adelante)",    value = "script-message add-audio-delay 0.10",  keep_open = true},
                {title = "⏹️  0.00s (Restablecer sincronía)",    value = "script-message reset-audio-delay",     keep_open = true, active = math.abs(audio_delay) < 0.005},
                {title = "◀️ -0.10s (Ajuste fino atrás)",       value = "script-message add-audio-delay -0.10", keep_open = true},
                {title = "⏪ -0.50s (Adelantar medio segundo)", value = "script-message add-audio-delay -0.50", keep_open = true},
            }
        },
        {
            title = "🎚️ Ecualizador de Audio",
            hint = "Perfil actual: " .. cur_label,
            muted = true
        }
    }

    local presets = {
        {id = "off",    name = "Plano (Desactivado)",       hint = "Sin filtros"},
        {id = "vocal",  name = "Claridad Vocal (Diálogos)", hint = "Voces nítidas (+3 a +4 dB en medios)"},
        {id = "cinema", name = "Cine / Inmersivo",          hint = "Graves profundos y agudos abiertos"},
        {id = "bass",   name = "Graves Potentes",           hint = "+6 dB en sub-graves"},
        {id = "anime",  name = "Anime / Brillo Acústico",   hint = "Realce en agudos y voces"},
        {id = "night",  name = "Suavizado Nocturno",        hint = "Anti-estruendos y diálogo suave"},
    }

    for _, p in ipairs(presets) do
        local is_act = (cur_profile == p.id)
        table.insert(items, {
            title = (is_act and "● " or "○ ") .. p.name,
            hint = p.hint,
            active = is_act,
            value = "script-message set-equalizer-profile " .. p.id,
            keep_open = true
        })
    end

    local is_custom = (cur_profile == "custom")
    table.insert(items, {
        title = (is_custom and "● " or "○ ") .. "Personalizado (6 Bandas)",
        hint = is_custom and "Desplegado" or "Seleccionar para ajustar",
        active = is_custom,
        value = "script-message set-equalizer-profile custom",
        keep_open = true,
        separator = true
    })

    -- Las bandas visuales y el reseteo solo son visibles cuando el modo personalizado está activo
    if is_custom then
        local bands = {
            {idx = 1, freq = "64 Hz",  name = "64 Hz (Sub-Graves)",       prop = "b64"},
            {idx = 2, freq = "250 Hz", name = "250 Hz (Graves)",         prop = "b250"},
            {idx = 3, freq = "1 kHz",  name = "1 kHz (Voces / Medios)",   prop = "b1000"},
            {idx = 4, freq = "2.5 kHz",name = "2.5 kHz (Presencia)",      prop = "b2500"},
            {idx = 5, freq = "6 kHz",  name = "6 kHz (Agudos)",           prop = "b6000"},
            {idx = 6, freq = "14 kHz", name = "14 kHz (Aire / Apertura)", prop = "b14000"},
        }

        table.insert(items, {
            title = "── Rack de Faders (±12 dB) ───────────────",
            hint = "Escala: -12 · 0 · +12",
            muted = true
        })

        for _, b in ipairs(bands) do
            local gain = tonumber(get_user_data("user-data/controller/eq-" .. b.prop, 0)) or 0
            local sign = gain > 0 and "+" or ""
            local gain_str = sign .. gain .. " dB"
            local fader_graphic = build_eq_fader(gain)

            table.insert(items, {
                id = "eq_band_" .. b.idx,
                title = b.freq,
                hint = gain_str,
                keep_open = true,
                slider = {
                    min = -12,
                    max = 12,
                    value = gain,
                    step = 1,
                    band_idx = b.idx,
                },
                items = {
                    {
                        title = string.format("Banda: %s", b.name),
                        hint = string.format("%s  [%s]", gain_str, fader_graphic),
                        muted = true
                    },
                    {title = "  ▲▲ +3 dB  (Aumento rápido)", value = string.format("script-message set-equalizer-band %d 3", b.idx), keep_open = true},
                    {title = "  ▲  +1 dB  (Paso fino)", value = string.format("script-message set-equalizer-band %d 1", b.idx), keep_open = true},
                    {title = "  ■   0 dB  (Nivel central plano)", value = string.format("script-message set-equalizer-band-exact %d 0", b.idx), keep_open = true},
                    {title = "  ▼  -1 dB  (Paso fino)", value = string.format("script-message set-equalizer-band %d -1", b.idx), keep_open = true},
                    {title = "  ▼▼ -3 dB  (Atenuación rápida)", value = string.format("script-message set-equalizer-band %d -3", b.idx), keep_open = true},
                    {title = "  ▲▲▲ +6 dB (Realce fuerte)", value = string.format("script-message set-equalizer-band-exact %d 6", b.idx), keep_open = true},
                    {title = "  ▼▼▼ -6 dB (Corte fuerte)", value = string.format("script-message set-equalizer-band-exact %d -6", b.idx), keep_open = true},
                }
            })
        end

        table.insert(items, {
            title = "↺ Restablecer todas las bandas a 0 dB",
            value = "script-message reset-equalizer-custom",
            keep_open = true
        })
    end

    return items
end

local function refresh_equalizer_menu()
    local menu = Menu:is_open('equalizer_menu')
    if menu then
        menu:update_items(create_equalizer_items())
        request_render()
    end
end

local eq_refresh_pending = false
local function schedule_equalizer_refresh()
    if eq_refresh_pending then return end
    if not (Menu and Menu:is_open('equalizer_menu')) then return end
    eq_refresh_pending = true
    mp.add_timeout(0, function()
        eq_refresh_pending = false
        refresh_equalizer_menu()
    end)
end
mp.register_script_message('refresh-equalizer-menu', schedule_equalizer_refresh)
mp.register_script_message('refresh-audio-menu', schedule_equalizer_refresh)
mp.observe_property('audio-delay', 'number', schedule_equalizer_refresh)

mp.register_script_message("open-equalizer-menu", function()
    local menu_data = {
        type = "equalizer_menu",
        title = "🎚️ Audio, Espacial & Ecualizador",
        items = create_equalizer_items()
    }
    local menu = Menu:is_open('equalizer_menu')
    if menu then
        menu:update(menu_data)
        request_render()
    else
        open_command_menu(menu_data)
    end
end)

-- ── Master Menu Builder with Dynamic Mutual Exclusion ─────────────────────────
function create_default_menu_items()
    local video_mode = get_user_data("user-data/controller/video-mode", "auto")
    local video_label = get_user_data("user-data/controller/video-label", "Auto")
    local video_shaders = get_user_data("user-data/controller/video-shaders", "Spline64")
    local audio_mode = get_user_data("user-data/controller/audio-mode", "normal")
    local audio_label = get_user_data("user-data/controller/audio-label", "Estándar (Directo)")
    local audio_channels = get_user_data("user-data/controller/audio-channels", "auto-safe")
    local audio_channels_label = get_user_data("user-data/controller/audio-channels-label", "Automático (Nativo)")
    local volume_boost = get_user_data("user-data/controller/volume-boost", "off")
    local volume_boost_label = get_user_data("user-data/controller/volume-boost-label", "Desactivado (0 dB)")
    local eco_mode = get_user_data("user-data/controller/eco-mode", "no")
    local is_eco = (eco_mode == "yes")
    local is_ambient = (get_user_data("user-data/ambient-active", "no") == "yes")
    local eq_label = get_user_data("user-data/controller/eq-label", "Plano (Desactivado)")
    local skip_mode = get_user_data("user-data/skip-intro/mode", "manual")
    local skip_label = get_user_data("user-data/skip-intro/label", "Manual (Aviso Tab)")
    local alang_pref = get_user_data("user-data/controller/alang-pref", mp.get_property("alang", ""))
    local slang_pref = get_user_data("user-data/controller/slang-pref", mp.get_property("slang", ""))

    local speed = mp.get_property_number("speed", 1.0)
    local loop_file = mp.get_property("loop-file", "no")
    local is_looping = (loop_file ~= "no")
    local is_shuffle = mp.get_property_bool("shuffle", false)
    local cur_ar = mp.get_property_number("video-aspect-override", -1)
    local ab_a = mp.get_property_native("ab-loop-a")
    local ab_b = mp.get_property_native("ab-loop-b")
    local is_ab_active = (type(ab_a) == "number")
    local ab_hint = "Desactivado (Tecla L)"
    if type(ab_a) == "number" and type(ab_b) == "number" then
        ab_hint = string.format("Activo (%02d:%02d → %02d:%02d)", math.floor(ab_a/60), math.floor(ab_a%60), math.floor(ab_b/60), math.floor(ab_b%60))
    elseif type(ab_a) == "number" then
        ab_hint = string.format("Punto A fijado (%02d:%02d) - Clic para B", math.floor(ab_a/60), math.floor(ab_a%60))
    end

    local w = mp.get_property_native("width")
    local h = mp.get_property_native("height")
    local res_str = (w and h) and (w .. "x" .. h) or "N/D"
    local fps = mp.get_property_native("container-fps") or mp.get_property_native("estimated-vf-fps")
    local fps_str = fps and string.format("%.2f fps", fps) or ""

    local video_display = is_eco and "⚡ Modo Eco (Ahorro)" or video_label

    local items = {}

    -- ── 1. Medios & Subtítulos (Exclusión Mutua con la Barra) ────────────────
    if not active_bar_controls.subtitles then
        table.insert(items, {
            title = "💬 Subtítulos & Traducción",
            hint = "Pistas, bilingüe y estilos",
            value = "script-message open-subtitles-menu"
        })
    end

    if not active_bar_controls.audio then
        table.insert(items, {
            title = t("Audio tracks"),
            hint = mp.get_property("current-tracks/audio/lang", ""):upper(),
            value = "script-binding uosc/audio"
        })
    end

    if not active_bar_controls.equalizer then
        table.insert(items, {
            title = "🎚️ Ecualizador: " .. eq_label,
            hint = "Perfiles, 6 bandas y delay",
            value = "script-message open-equalizer-menu"
        })
    end

    if not active_bar_controls.playlist then
        table.insert(items, {
            title = t("Playlist"),
            hint = tostring(state.playlist_count or mp.get_property_number("playlist-count", 0)) .. " archivos",
            value = "script-binding uosc/items"
        })
    end

    table.insert(items, {
        title = t("Chapters"),
        value = "script-binding uosc/chapters",
        separator = true
    })

    -- ── 2. Controles Directos & Perfiles de Video y Sonido ───────────────────
    table.insert(items, {
        id = "video_profiles_menu",
        title = "🎨 Perfil de Video: " .. video_display,
        hint = is_eco and "Aceleración pura" or video_shaders,
        items = build_video_profiles_submenu_items(is_eco and "eco" or video_mode)
    })

    table.insert(items, {
        id = "spatial_audio_menu",
        title = "🎧 Sonido Espacial (Dolby / DTS)",
        hint = audio_label,
        items = build_spatial_audio_submenu_items(audio_mode)
    })

    table.insert(items, {
        id = "audio_channels_menu",
        title = "🔈 Modo de Canales",
        hint = audio_channels_label,
        items = build_audio_channels_submenu_items(audio_channels)
    })

    if not active_bar_controls.volume_boost then
        table.insert(items, {
            id = "volume_boost_menu",
            title = "📢 Amplificador de Volumen (Boost)",
            hint = volume_boost_label,
            items = build_volume_boost_submenu_items(volume_boost)
        })
    end

    table.insert(items, {
        id = "skip_intro_menu",
        title = "⏭️ Saltar Opening / Ending",
        hint = skip_label,
        items = build_skip_intro_submenu_items(skip_mode)
    })

    if not active_bar_controls.ambient_crop then
        table.insert(items, {
            title = "🖼️ Modo Ambient Crop: " .. (is_ambient and "ACTIVADO" or "DESACTIVADO"),
            hint = is_ambient and "Recorte + Resplandor activo" or "Sin barras negras / Resplandor",
            active = is_ambient,
            value = "script-message toggle-crop-ambient",
            keep_open = true
        })
    end

    if not active_bar_controls.ab_loop then
        table.insert(items, {
            title = "🔁 Loop A-B de Segmento",
            hint = ab_hint,
            active = is_ab_active,
            value = "script-message cycle-ab-loop",
            keep_open = true
        })
    end

    if not active_bar_controls.speed then
        table.insert(items, {
            title = string.format("⏱ Velocidad: %.2fx", speed) .. (math.abs(speed - 1.0) < 0.05 and " (Normal)" or ""),
            hint = "Clic para alternar",
            value = "script-message cycle-speed",
            keep_open = true
        })
    end

    if not active_bar_controls.loop then
        table.insert(items, {
            title = "🔁 Repetir archivo: " .. (is_looping and "ACTIVADO" or "DESACTIVADO"),
            hint = is_looping and "Repite infinitamente" or "Desactivado",
            active = is_looping,
            value = "script-message toggle-loop-file",
            keep_open = true
        })
    end

    if not active_bar_controls.shuffle then
        table.insert(items, {
            title = "🔀 Mezclar lista: " .. (is_shuffle and "ACTIVADO" or "DESACTIVADO"),
            hint = is_shuffle and "Orden aleatorio activo" or "Orden normal",
            active = is_shuffle,
            value = "script-binding uosc/shuffle",
            keep_open = true
        })
    end

    items[#items].separator = true

    -- ── 3. Información del Video, Idiomas & Herramientas ─────────────────────
    if not active_bar_controls.stats then
        table.insert(items, {
            title = "📊 Información: " .. res_str .. " " .. fps_str,
            hint = "Shift + I",
            value = "script-binding stats/display-stats-toggle"
        })
    end

    table.insert(items, {
        title = "🌐 Idiomas Preferidos (Audio y Subtítulos)",
        hint = (alang_pref ~= "" and alang_pref:sub(1, 10) or "Auto") .. " / " .. (slang_pref ~= "" and slang_pref:sub(1, 10) or "Auto"),
        value = "script-message open-lang-prefs-menu"
    })

    table.insert(items, {
        title = "🛠️ Personalizar barra de controles",
        hint = "Elegir botones visibles",
        value = "script-message open-controls-customizer"
    })

    table.insert(items, {
        title = t("Navigation"),
        id = "nav_submenu",
        items = {
            { title = t("Next"), hint = t("playlist or file"), value = "script-binding uosc/next" },
            { title = t("Prev"), hint = t("playlist or file"), value = "script-binding uosc/prev" },
            { title = t("Open file"), value = "script-binding uosc/open-file" },
        }
    })

    local util_items = {
        {
            title = t("Aspect ratio"),
            id = "aspect_submenu",
            items = {
                {title = t("Default"), value = "set video-aspect-override no", active = (cur_ar < 0), keep_open = true},
                {title = "16:9", value = 'set video-aspect-override "16:9"', active = (cur_ar > 0 and math.abs(cur_ar - 16/9) < 0.02), keep_open = true},
                {title = "4:3", value = 'set video-aspect-override "4:3"', active = (cur_ar > 0 and math.abs(cur_ar - 4/3) < 0.02), keep_open = true},
                {title = "2.35:1", value = 'set video-aspect-override "2.35:1"', active = (cur_ar > 0 and math.abs(cur_ar - 2.35) < 0.05), keep_open = true},
            },
        },
        {title = t("Audio devices"), value = "script-binding uosc/audio-device"},
    }

    if not active_bar_controls.screenshot then
        table.insert(util_items, {title = t("Screenshot"), value = "async screenshot"})
    end

    table.insert(util_items, {title = t("Key bindings"), value = "script-binding uosc/keybinds"})
    table.insert(util_items, {title = t("Show in directory"), value = "script-binding uosc/show-in-directory"})

    table.insert(items, {
        title = t("Utils"),
        id = "utils_submenu",
        items = util_items
    })

    table.insert(items, {title = t("Quit"), value = "quit"})

    return items
end

-- Function to refresh Master Menu in place whenever any state changes
refresh_master_menu = function()
    local open_menu = Menu:is_open('menu')
    if open_menu then
        local items = create_default_menu_items()
        open_menu:update_items(items)
        request_render()
    end
end

local menu_refresh_pending = false
schedule_menu_refresh = function()
    if menu_refresh_pending then return end
    if not (Menu and Menu:is_open('menu')) then return end
    menu_refresh_pending = true
    mp.add_timeout(0, function()
        menu_refresh_pending = false
        refresh_master_menu()
    end)
end

_G.update_master_menu = refresh_master_menu
_G.schedule_master_menu_refresh = schedule_menu_refresh
mp.register_script_message('refresh-master-menu', schedule_menu_refresh)
mp.observe_property('shuffle', 'bool', schedule_menu_refresh)
mp.observe_property('video-aspect-override', 'native', schedule_menu_refresh)
mp.observe_property('user-data/controller/audio-mode', 'native', schedule_menu_refresh)
mp.observe_property('user-data/controller/audio-label', 'native', schedule_menu_refresh)
mp.observe_property('user-data/controller/audio-channels', 'native', schedule_menu_refresh)
mp.observe_property('user-data/controller/audio-channels-label', 'native', schedule_menu_refresh)
mp.observe_property('user-data/controller/video-mode', 'native', schedule_menu_refresh)
mp.observe_property('user-data/controller/video-label', 'native', schedule_menu_refresh)
mp.observe_property('user-data/controller/video-shaders', 'native', schedule_menu_refresh)
mp.observe_property('user-data/controller/eco-mode', 'native', schedule_menu_refresh)
mp.observe_property('user-data/ambient-active', 'native', schedule_menu_refresh)
mp.observe_property('user-data/controller/eq-profile', 'native', schedule_menu_refresh)
mp.observe_property('user-data/controller/eq-label', 'native', schedule_menu_refresh)
mp.observe_property('user-data/controller/volume-boost', 'native', schedule_menu_refresh)
mp.observe_property('user-data/controller/volume-boost-label', 'native', schedule_menu_refresh)
mp.observe_property('user-data/skip-intro/mode', 'native', schedule_menu_refresh)
mp.observe_property('user-data/skip-intro/label', 'native', schedule_menu_refresh)
mp.observe_property('user-data/controller/alang-pref', 'native', schedule_menu_refresh)
mp.observe_property('user-data/controller/slang-pref', 'native', schedule_menu_refresh)

mp.register_script_message("open-dashboard", function()
    mp.commandv("script-binding", "uosc/menu")
end)


--[[ STATE ]]

display = {ax = 0, ay = 0, bx = 1280, by = 720, width = 1280, height = 720, initialized = false}
cursor = require('lib/cursor')
state = {
	platform = (function()
		local platform = mp.get_property_native('platform')
		if platform then
			if itable_index_of({'windows', 'darwin'}, platform) then return platform end
		else
			if os.getenv('windir') ~= nil then return 'windows' end
			local homedir = os.getenv('HOME')
			if homedir ~= nil and string.sub(homedir, 1, 6) == '/Users' then return 'darwin' end
		end
		return 'linux'
	end)(),
	cwd = mp.get_property('working-directory'),
	path = nil, -- current file path or URL
	history = {}, -- history of last played files stored as full paths
	time = nil, -- current media playback time
	speed = 1,
	---@type number|nil
	duration = nil, -- current media duration
	max_seconds = nil, -- max seconds the time in timeline is expected to reach, accounted for speed
	time_human = nil, -- current playback time in human format
	destination_time_human = nil, -- depends on options.destination_time
	pause = mp.get_property_native('pause'),
	ime_active = mp.get_property_native('input-ime'),
	chapters = {},
	chapter_ranges = {},
	border = mp.get_property_native('border'),
	title_bar = mp.get_property_native('title-bar'),
	fullscreen = mp.get_property_native('fullscreen'),
	maximized = mp.get_property_native('window-maximized'),
	fullormaxed = mp.get_property_native('fullscreen') or mp.get_property_native('window-maximized'),
	render_timer = nil,
	render_last_time = 0,
	volume = mp.get_property_native('volume'),
	volume_max = mp.get_property_native('volume-max'),
	mute = nil,
	type = nil, -- video,image,audio
	is_idle = false,
	is_video = false,
	is_audio = false, -- true if file is audio only (mp3, etc)
	is_image = false,
	is_stream = false,
	has_image = false,
	has_audio = false,
	has_sub = false,
	has_chapter = false,
	has_playlist = false,
	shuffle = options.shuffle,
	---@type nil|{pos: number; paths: string[]}
	shuffle_history = nil,
	on_shuffle = function() state.shuffle_history = nil end,
	mouse_bindings_enabled = false,
	uncached_ranges = nil,
	cache = nil,
	cache_buffering = 100,
	cache_underrun = false,
	cache_duration = nil,
	core_idle = false,
	eof_reached = false,
	render_delay = config.render_delay,
	playlist_count = 0,
	playlist_pos = 0,
	margin_top = 0,
	margin_bottom = 0,
	margin_left = 0,
	margin_right = 0,
	hidpi_scale = 1,
	scale = 1,
	radius = 0,
}
buttons = require('lib/buttons')
thumbnail = {width = 0, height = 0, disabled = false}
external = {} -- Properties set by external scripts
key_binding_overwrites = {} -- Table of key_binding:mpv_command
Elements = require('elements/Elements')
Menu = require('elements/Menu')

-- State dependent utilities
require('lib/utils')
require('lib/text')
require('lib/ass')
require('lib/menus')

-- ── Reactive ManagedButtons for Control Bar (2.3 & 1.D) ───────────────────────
local function sync_managed_bar_buttons()
	local boost = get_user_data("user-data/controller/volume-boost", "off")
	local boost_label = get_user_data("user-data/controller/volume-boost-label", "Desactivado (0 dB)")
	local boost_badges = {soft = "+4", medium = "+8", high = "+12", auto = "DRC"}
	buttons:set("volume_boost", {
		icon = "volume_up",
		active = (boost ~= "off"),
		badge = boost_badges[boost],
		command = "script-message cycle-volume-boost",
		tooltip = "Amplificador de Volumen: " .. boost_label,
	})

	local is_ambient = (get_user_data("user-data/ambient-active", "no") == "yes")
	buttons:set("ambient_crop", {
		icon = "crop",
		active = is_ambient,
		command = "script-message toggle-crop-ambient",
		tooltip = "Modo Ambient Crop: " .. (is_ambient and "ACTIVADO" or "DESACTIVADO"),
	})

	local ab_a = mp.get_property_native("ab-loop-a")
	local ab_b = mp.get_property_native("ab-loop-b")
	local ab_active = (type(ab_a) == "number")
	local ab_badge = (type(ab_a) == "number" and type(ab_b) == "number") and "A-B"
		or (type(ab_a) == "number" and "A" or nil)
	buttons:set("ab_loop", {
		icon = "repeat",
		active = ab_active,
		badge = ab_badge,
		command = "script-message cycle-ab-loop",
		tooltip = "Loop A-B de Segmento (Tecla L)",
	})
end
sync_managed_bar_buttons()
mp.observe_property("user-data/controller/volume-boost", "native", sync_managed_bar_buttons)
mp.observe_property("user-data/controller/volume-boost-label", "native", sync_managed_bar_buttons)
mp.observe_property("user-data/ambient-active", "native", sync_managed_bar_buttons)
mp.observe_property("ab-loop-a", "native", function()
	sync_managed_bar_buttons()
	if schedule_menu_refresh then schedule_menu_refresh() end
end)
mp.observe_property("ab-loop-b", "native", function()
	sync_managed_bar_buttons()
	if schedule_menu_refresh then schedule_menu_refresh() end
end)

-- Determine path to ziggy
do
	local bin = 'ziggy-' .. (state.platform == 'windows' and 'windows.exe' or state.platform)
	config.ziggy_path = os.getenv('MPV_UOSC_ZIGGY') or join_path(mp.get_script_directory(), join_path('bin', bin))
end

--[[ STATE UPDATERS ]]

function update_display_dimensions()
	state.scale = (state.hidpi_scale or 1) * (state.fullormaxed and options.scale_fullscreen or options.scale)
	state.radius = round(options.border_radius * state.scale)
	local real_width, real_height = mp.get_osd_size()
	if real_width <= 0 then return end
	display.bx, display.width, display.by, display.height = real_width, real_width, real_height, real_height
	display.initialized = true

	-- Tell elements about this
	Elements:trigger('display')

	-- Some elements probably changed their rectangles as a reaction to `display`
	Elements:update_proximities()
	request_render()
end

function update_fullormaxed()
	state.fullormaxed = state.fullscreen or state.maximized
	update_display_dimensions()
	Elements:trigger('prop_fullormaxed', state.fullormaxed)
	cursor:leave()
end

function update_duration()
	local duration = state._duration and ((state.rebase_start_time == false and state.start_time)
		and (state._duration + state.start_time) or state._duration)
	set_state('duration', duration)
	update_human_times()
end

function update_human_times()
	state.speed = state.speed or 1
	if state.time then
		if state.duration then
			if options.destination_time == 'playtime-remaining' then
				state.destination_time_human = format_time((state.time - state.duration) / state.speed, state.duration)
			elseif options.destination_time == 'total' then
				state.destination_time_human = format_time(state.duration, state.duration)
			else
				state.destination_time_human = format_time(state.time - state.duration, state.duration)
			end
		else
			state.destination_time_human = nil
		end
		state.time_human = format_time(state.time, state.duration or state.time)
	else
		state.time_human, state.destination_time_human = nil, nil
	end
end

-- Notifies other scripts such as console about where the unoccupied parts of the screen are.
function update_margins()
	if display.height == 0 then return end

	local function causes_margin(element)
		return element and element.enabled and (element:is_persistent() or element.min_visibility > 0.5)
	end
	local timeline, top_bar, controls, volume = Elements.timeline, Elements.top_bar, Elements.controls, Elements.volume
	-- margins are normalized to window size
	local left, right, top, bottom = 0, 0, 0, 0

	if causes_margin(controls) then
		bottom = (display.height - controls.ay) / display.height
	elseif causes_margin(timeline) then
		bottom = (display.height - timeline.ay) / display.height
	end

	if causes_margin(top_bar) then top = top_bar.title_by / display.height end

	if causes_margin(volume) then
		if options.volume == 'left' then
			left = volume.bx / display.width
		elseif options.volume == 'right' then
			right = volume.ax / display.width
		end
	end

	if top == state.margin_top and bottom == state.margin_bottom and
		left == state.margin_left and right == state.margin_right then
		return
	end

	state.margin_top = top
	state.margin_bottom = bottom
	state.margin_left = left
	state.margin_right = right

	if utils.shared_script_property_set then
		utils.shared_script_property_set('osc-margins', string.format('%f,%f,%f,%f', 0, 0, top, bottom))
	end
	mp.set_property_native('user-data/osc/margins', {l = left, r = right, t = top, b = bottom})

	if not options.adjust_osd_margins then return end
	local osd_margin_y, osd_margin_x, osd_factor_x = 0, 0, display.width / display.height * 720
	if config.osd_alignment_y == 'bottom' then
		osd_margin_y = round(bottom * 720)
	elseif config.osd_alignment_y == 'top' then
		osd_margin_y = round(top * 720)
	end
	if config.osd_alignment_x == 'left' then
		osd_margin_x = round(left * osd_factor_x)
	elseif config.osd_alignment_x == 'right' then
		osd_margin_x = round(right * osd_factor_x)
	end
	mp.set_property_native('osd-margin-y', osd_margin_y + config.osd_margin_y)
	mp.set_property_native('osd-margin-x', osd_margin_x + config.osd_margin_x)
end
function create_state_setter(name, callback)
	return function(_, value)
		set_state(name, value)
		if callback then callback() end
		request_render()
	end
end

function set_state(name, value)
	state[name] = value
	local state_event = state['on_' .. name]
	if state_event then state_event(value) end
	Elements:trigger('prop_' .. name, value)
end

function handle_file_end()
	local resume = false
	if not state.loop_file then
		if state.has_playlist then
			resume = state.shuffle and navigate_playlist(1)
		else
			resume = options.autoload and navigate_directory(1)
		end
	end
	-- Resume only when navigation happened
	if resume then mp.command('set pause no') end
end
local file_end_timer = mp.add_timeout(1, handle_file_end)
file_end_timer:kill()

function load_file_index_in_current_directory(index)
	if not state.path or is_protocol(state.path) then return end

	local serialized = serialize_path(state.path)
	if serialized and serialized.dirname then
		local files, _dirs, error = read_directory(serialized.dirname, {
			types = config.types.load,
			hidden = options.show_hidden_files,
		})

		if error then
			msg.error(error)
			return
		end

		sort_strings(files)
		if index < 0 then index = #files + index + 1 end

		if files[index] then
			mp.commandv('loadfile', join_path(serialized.dirname, files[index]))
		end
	end
end

function update_render_delay(name, fps)
	if fps then state.render_delay = 1 / fps end
end

function observe_display_fps(name, fps)
	if fps then
		mp.unobserve_property(update_render_delay)
		mp.unobserve_property(observe_display_fps)
		mp.observe_property('display-fps', 'native', update_render_delay)
	end
end

--[[ STATE HOOKS ]]

mp.register_event('file-loaded', function()
	local path = normalize_path(mp.get_property_native('path'))
	itable_delete_value(state.history, path)
	state.history[#state.history + 1] = path
	set_state('path', path)

	-- Flash top bar on requested file types
	for _, type in ipairs(config.top_bar_flash_on) do
		if state['is_' .. type] then
			Elements:flash({'top_bar'})
			break
		end
	end
end)
mp.register_event('end-file', function(event)
    -- [v4.5] History Save Logic
    local is_url = active_video.path and active_video.path:match("^%a[%w.+-]-://")

    if active_video.path and not is_url and get_anime_state("history_enabled") then
        local final_percent = active_video.percent
        if event.reason == "eof" then final_percent = 100 end

        -- Save if we watched at least 1% or reached End of File
        if final_percent > 1 or event.reason == "eof" then
            -- Remove duplicate to bubble it to the top
            for i, entry in ipairs(watch_history) do
                if entry.path == active_video.path then table.remove(watch_history, i) break end
            end

            -- Insert at top
            table.insert(watch_history, 1, {
                path = active_video.path,
                title = active_video.title,
                percent = final_percent
            })

            -- Prune to max 50
            while #watch_history > 50 do table.remove(watch_history) end
            save_watch_history()
        end
    end

    -- Clear active state
    active_video.path = nil

    -- [ORIGINAL UOSC LOGIC]
    set_state('path', nil)
    if event.reason == 'eof' then
        if file_end_timer then file_end_timer:kill() end
        if handle_file_end then handle_file_end() end
    end
end)
mp.observe_property('playback-time', 'number', create_state_setter('time', function()
	-- Create a file-end event that triggers right before file ends
	file_end_timer:kill()
	if state.duration and state.time and not state.pause then
		local remaining = (state.duration - state.time) / state.speed
		if remaining < 5 then
			local timeout = remaining - 0.02
			if timeout > 0 then
				file_end_timer.timeout = timeout
				file_end_timer:resume()
			else
				handle_file_end()
			end
		end
	end

	update_human_times()
end))
mp.observe_property('rebase-start-time', 'bool', create_state_setter('rebase_start_time', update_duration))
mp.observe_property('demuxer-start-time', 'number', create_state_setter('start_time', update_duration))
mp.observe_property('duration', 'number', create_state_setter('_duration', update_duration))
mp.observe_property('speed', 'number', create_state_setter('speed', function()
	update_human_times()
	if schedule_menu_refresh then schedule_menu_refresh() end
end))
mp.observe_property('track-list', 'native', function(name, value)
	-- checks the file dispositions
	local types = {sub = 0, image = 0, audio = 0, video = 0}
	for _, track in ipairs(value) do
		if track.type == 'video' then
			if track.image or track.albumart then
				types.image = types.image + 1
			else
				types.video = types.video + 1
			end
		elseif types[track.type] then
			types[track.type] = types[track.type] + 1
		end
	end
	set_state('is_audio', types.video == 0 and types.audio > 0)
	set_state('is_image', types.image > 0 and types.video == 0 and types.audio == 0)
	set_state('has_image', types.image > 0)
	set_state('has_audio', types.audio > 0)
	set_state('has_many_audio', types.audio > 1)
	set_state('has_sub', types.sub > 0)
	set_state('has_many_sub', types.sub > 1)
	set_state('is_video', types.video > 0)
	set_state('has_many_video', types.video > 1)
	set_state('type', state.is_video and 'video' or state.is_audio and 'audio' or state.is_image and 'image' or nil)
	update_load_types()
	Elements:trigger('dispositions')
end)
mp.observe_property('editions', 'number', function(_, editions)
	if editions then set_state('has_many_edition', editions > 1) end
	Elements:trigger('dispositions')
end)
mp.observe_property('chapter-list', 'native', function(_, chapters)
	local chapters, chapter_ranges = serialize_chapters(chapters), {}
	if chapters then chapters, chapter_ranges = serialize_chapter_ranges(chapters) end
	set_state('chapters', chapters)
	set_state('chapter_ranges', chapter_ranges)
	set_state('has_chapter', #chapters > 0)
	Elements:trigger('dispositions')
end)
mp.observe_property('border', 'bool', create_state_setter('border'))
mp.observe_property('title-bar', 'bool', create_state_setter('title_bar'))
mp.observe_property('loop-file', 'native', create_state_setter('loop_file', function()
	if schedule_menu_refresh then schedule_menu_refresh() end
end))
mp.observe_property('ab-loop-a', 'number', create_state_setter('ab_loop_a'))
mp.observe_property('ab-loop-b', 'number', create_state_setter('ab_loop_b'))

local dir_cache = {}
local playlist_clean_pending = false

local function perform_clean_playlist_update()
	local pl = mp.get_property_native('playlist') or {}
	local clean_count = 0
	local clean_pos = 1
	local cur_pos = mp.get_property_number('playlist-pos-1', 1)

	for i, entry in ipairs(pl) do
		local is_dir = false
		if entry.filename and not is_protocol(entry.filename) then
			local cached = dir_cache[entry.filename]
			if cached ~= nil then
				is_dir = cached
			else
				local info = utils.file_info(entry.filename)
				is_dir = (info and info.is_dir) or false
				dir_cache[entry.filename] = is_dir
			end
		end
		if not is_dir then
			clean_count = clean_count + 1
			if i <= cur_pos then
				clean_pos = clean_count
			end
		end
	end

	set_state('clean_playlist_count', clean_count)
	set_state('clean_playlist_pos', clean_pos)
	set_state('playlist_count', clean_count)
	set_state('playlist_pos', clean_pos)
	set_state('has_playlist', clean_count > 1)
	Elements:trigger('dispositions')
end

local function update_clean_playlist()
	if playlist_clean_pending then return end
	playlist_clean_pending = true
	mp.add_timeout(0, function()
		playlist_clean_pending = false
		perform_clean_playlist_update()
	end)
end

mp.observe_property('playlist-pos-1', 'number', update_clean_playlist)
mp.observe_property('playlist-count', 'number', update_clean_playlist)
mp.observe_property('playlist', 'native', function()
	if #mp.get_property_native('playlist', {}) == 0 then
		dir_cache = {}
	end
	update_clean_playlist()
end)
mp.observe_property('fullscreen', 'bool', create_state_setter('fullscreen', update_fullormaxed))
mp.observe_property('window-maximized', 'bool', create_state_setter('maximized', update_fullormaxed))
mp.observe_property('idle-active', 'bool', function(_, idle)
	set_state('is_idle', idle)
	Elements:trigger('dispositions')
	mp.commandv('script-message-to', 'thumbfast', 'clear')
end)
mp.observe_property('pause', 'bool', create_state_setter('pause', function() file_end_timer:kill() end))
mp.observe_property('volume', 'number', create_state_setter('volume'))
mp.observe_property('volume-max', 'number', create_state_setter('volume_max'))
mp.observe_property('mute', 'bool', create_state_setter('mute'))
mp.observe_property('osd-dimensions', 'native', function(name, val)
	update_display_dimensions()
	request_render()
end)
mp.observe_property('display-hidpi-scale', 'native', create_state_setter('hidpi_scale', update_display_dimensions))
mp.observe_property('cache', 'string', create_state_setter('cache'))
mp.observe_property('cache-buffering-state', 'number', create_state_setter('cache_buffering'))
mp.observe_property('demuxer-via-network', 'native', create_state_setter('is_stream', function()
	Elements:trigger('dispositions')
end))
mp.observe_property('demuxer-cache-state', 'native', function(prop, cache_state)
	local cached_ranges, bof, eof, uncached_ranges = nil, nil, nil, nil
	if cache_state then
		cached_ranges, bof, eof = cache_state['seekable-ranges'], cache_state['bof-cached'], cache_state['eof-cached']
		set_state('cache_underrun', cache_state['underrun'])
		set_state('cache_duration', not cache_state.eof and cache_state['cache-duration'] or nil)
	else
		cached_ranges = {}
		set_state('cache_underrun', false)
	end

	if not (state.duration and (#cached_ranges > 0 or state.cache == 'yes' or
			(state.cache == 'auto' and state.is_stream))) then
		if state.uncached_ranges then set_state('uncached_ranges', nil) end
		set_state('cache_duration', nil)
		return
	end

	-- Normalize
	local ranges = {}
	for _, range in ipairs(cached_ranges) do
		ranges[#ranges + 1] = {
			math.max(range['start'] or 0, 0),
			math.min(range['end'] or state.duration --[[@as number]], state.duration),
		}
	end
	table.sort(ranges, function(a, b) return a[1] < b[1] end)
	if bof then ranges[1][1] = 0 end
	if eof then ranges[#ranges][2] = state.duration end
	-- Invert cached ranges into uncached ranges, as that's what we're rendering
	local inverted_ranges = {{0, state.duration}}
	for _, cached in pairs(ranges) do
		inverted_ranges[#inverted_ranges][2] = cached[1]
		inverted_ranges[#inverted_ranges + 1] = {cached[2], state.duration}
	end
	uncached_ranges = {}
	local last_range = nil
	for _, range in ipairs(inverted_ranges) do
		if last_range and last_range[2] + 0.5 > range[1] then -- fuse ranges
			last_range[2] = range[2]
		else
			if range[2] - range[1] > 0.5 then -- skip short ranges
				uncached_ranges[#uncached_ranges + 1] = range
				last_range = range
			end
		end
	end

	set_state('uncached_ranges', uncached_ranges)
end)
mp.observe_property('display-fps', 'native', observe_display_fps)
mp.observe_property('estimated-display-fps', 'native', update_render_delay)
mp.observe_property('eof-reached', 'native', create_state_setter('eof_reached'))
mp.observe_property('core-idle', 'native', create_state_setter('core_idle'))

--[[ KEY BINDS ]]

-- Adds a key binding that respects rerouting set by `key_binding_overwrites` table.
---@param name string
---@param callback fun(event: table)
---@param flags nil|string
function bind_command(name, callback, flags)
	mp.add_key_binding(nil, name, function(...)
		if key_binding_overwrites[name] then
			mp.command(key_binding_overwrites[name])
		else
			callback(...)
		end
	end, flags)
end

bind_command('toggle-ui', function() Elements:toggle({'timeline', 'controls', 'volume', 'top_bar'}) end)
bind_command('flash-ui', function() Elements:flash({'timeline', 'controls', 'volume', 'top_bar'}) end)
bind_command('flash-timeline', function() Elements:flash({'timeline'}) end)
bind_command('flash-top-bar', function() Elements:flash({'top_bar'}) end)
bind_command('flash-volume', function() Elements:flash({'volume'}) end)
bind_command('flash-speed', function() Elements:flash({'speed'}) end)
bind_command('flash-pause-indicator', function() Elements:flash({'pause_indicator'}) end)
bind_command('flash-progress', function() Elements:flash({'progress'}) end)
bind_command('toggle-progress', function() Elements:maybe('timeline', 'toggle_progress') end)
bind_command('toggle-title', function() Elements:maybe('top_bar', 'toggle_title') end)
bind_command('decide-pause-indicator', function() Elements:maybe('pause_indicator', 'decide') end)
-- [FIX: BYPASS CACHE AND FORCE REFRESH]
bind_command('menu', function() 
    if Menu:is_open('menu') then
        Menu:close()
    else
        -- Direct call to open_command_menu ensures we always use fresh items
        -- bypassing any internal caching in toggle_menu_with_items
        open_command_menu({ 
            type = 'menu', 
            items = create_default_menu_items(),
            search_style = 'palette' 
        })
    end
end)

bind_command('menu-blurred', function() 
    if Menu:is_open('menu') then
        Menu:close()
    else
        open_command_menu({ 
            type = 'menu', 
            items = create_default_menu_items(),
            search_style = 'palette',
            mouse_nav = true 
        })
    end
end)
bind_command('keybinds', function()
	if Menu:is_open('keybinds') then
		Menu:close()
	else
		open_command_menu({type = 'keybinds', items = get_keybinds_items(), search_style = 'palette'})
	end
end)
bind_command('download-subtitles', open_subtitle_downloader)
bind_command('load-subtitles', create_track_loader_menu_opener({
	prop = 'sub',
	title = t('Load subtitles'),
	loaded_message = t('Loaded subtitles'),
	allowed_types = itable_join(config.types.video, config.types.subtitle),
}))
bind_command('load-audio', create_track_loader_menu_opener({
	prop = 'audio',
	title = t('Load audio'),
	loaded_message = t('Loaded audio'),
	allowed_types = itable_join(config.types.video, config.types.audio),
}))
bind_command('load-video', create_track_loader_menu_opener({
	prop = 'video',
	title = t('Load video'),
	loaded_message = t('Loaded video'),
	allowed_types = config.types.video,
}))
bind_command('subtitles', function()
	mp.commandv('script-message', 'open-subtitles-menu')
end)
bind_command('audio', create_select_tracklist_type_menu_opener({
	title = t('Audio'), type = 'audio', prop = 'aid', load_command = 'script-binding uosc/load-audio',
}))
bind_command('video', create_select_tracklist_type_menu_opener({
	title = t('Video'), type = 'video', prop = 'vid', load_command = 'script-binding uosc/load-video',
}))
bind_command('playlist', create_self_updating_menu_opener({
	title = t('Playlist (Type to Search)'),
	type = 'playlist',
	list_prop = 'playlist',
    
    -- [SEARCH SETTINGS]
    search_style = 'palette',             -- Enables the search bar
    search_subtext = 'Type to search...', -- Adds the visual hint text
    
	footnote = t('Paste path or url to add.') .. ' ' .. t('%s to reorder.', 'ctrl+up/down/pgup/pgdn/home/end'),
	serializer = function(playlist)
		local items = {}
		local force_filename = mp.get_property_native('osd-playlist-entry') == 'filename'
		for index, item in ipairs(playlist) do
			local info = not is_protocol(item.filename) and utils.file_info(item.filename)
			if not (info and info.is_dir) then
				local title = type(item.title) == 'string' and #item.title > 0 and item.title or false
				local raw_title = (not force_filename and title) and title
						or (is_protocol(item.filename) and item.filename or serialize_path(item.filename).basename)
				items[#items + 1] = {
					title = clean_title and clean_title(raw_title) or raw_title,
					hint = tostring(#items + 1),
					active = item.current,
					value = index,
				}
			end
		end
		return items
	end,
	on_activate = function(event) mp.commandv('set', 'playlist-pos-1', tostring(event.value)) end,
	on_paste = function(event) mp.commandv('loadfile', tostring(event.value), 'append') end,
	on_key = function(event)
		if event.id == 'ctrl+c' and event.selected_item then
			local payload = mp.get_property_native('playlist/' .. (event.selected_item.value - 1) .. '/filename')
			set_clipboard(payload)
		end
	end,
	on_move = function(event)
		local from, to = event.from_index, event.to_index
		mp.commandv('playlist-move', tostring(from - 1), tostring(to - (to > from and 0 or 1)))
	end,
	on_remove = function(event) mp.commandv('playlist-remove', tostring(event.value - 1)) end,
}))
-- [v4.5] History UOSC Bind
bind_command('history', function()
    local items = {}
    for i, entry in ipairs(watch_history) do
        local is_watched = entry.percent >= 95

        -- Visual Progress Bar Generator (10 blocks long)
        local bar_length = 10
        local filled_blocks = math.floor((entry.percent / 100) * bar_length + 0.5)
        local empty_blocks = bar_length - filled_blocks

        local progress_bar = string.rep("■", filled_blocks) .. string.rep("□", empty_blocks)

        local hint_text = is_watched and "Watched" or string.format("%s  %d%%", progress_bar, entry.percent)

        items[i] = {
            title = entry.title,
            hint = hint_text,
            icon = is_watched and "check_circle" or "schedule",
            value = string.format("loadfile %q", entry.path),
            muted = is_watched -- [NEW] Greys out the entry if watched
        }
    end

    if #items == 0 then
        items[1] = { title = "Watch history is empty", value = "ignore", bold = true, icon = "info", muted = true }
    end

    open_command_menu({
        type = 'history',
        title = t('Watch History'),
        items = items,
        search_style = 'palette'
    })
end)
bind_command('chapters', create_self_updating_menu_opener({
	title = t('Chapters'),
	type = 'chapters',
	list_prop = 'chapter-list',
	active_prop = 'chapter',
	serializer = function(chapters, current_chapter)
		local items = {}
		chapters = normalize_chapters(chapters)
		for index, chapter in ipairs(chapters) do
			items[index] = {
				title = chapter.title or '',
				hint = format_time(chapter.time, state.duration),
				value = index,
				active = index - 1 == current_chapter,
			}
		end
		return items
	end,
	on_activate = function(event) mp.commandv('set', 'chapter', tostring(event.value - 1)) end,
}))
bind_command('editions', create_self_updating_menu_opener({
	title = t('Editions'),
	type = 'editions',
	list_prop = 'edition-list',
	active_prop = 'current-edition',
	serializer = function(editions, current_id)
		local items = {}
		for _, edition in ipairs(editions or {}) do
			local edition_id_1 = tostring(edition.id + 1)
			items[#items + 1] = {
				title = edition.title or t('Edition %s', edition_id_1),
				hint = edition_id_1,
				value = edition.id,
				active = edition.id == current_id,
			}
		end
		return items
	end,
	on_activate = function(event) mp.commandv('set', 'edition', event.value) end,
}))
bind_command('show-in-directory', function()
	-- Ignore URLs
	if not state.path or is_protocol(state.path) then return end

	if state.platform == 'windows' then
		utils.subprocess_detached({args = {'explorer', '/select,', state.path .. ' '}, cancellable = false})
	elseif state.platform == 'darwin' then
		utils.subprocess_detached({args = {'open', '-R', state.path}, cancellable = false})
	elseif state.platform == 'linux' then
		local result = utils.subprocess({args = {'nautilus', state.path}, cancellable = false})

		-- Fallback opens the folder with xdg-open instead
		if result.status ~= 0 then
			utils.subprocess({args = {'xdg-open', serialize_path(state.path).dirname}, cancellable = false})
		end
	end
end)
bind_command('stream-quality', open_stream_quality_menu)
bind_command('open-file', open_open_file_menu)
bind_command('shuffle', function()
	local next_shuffle = not state.shuffle
	set_state('shuffle', next_shuffle)
	mp.set_property_bool('shuffle', next_shuffle)
	mp.commandv("script-message-to", "uosc", "dynamic-island-message",
		next_shuffle and "🔀 Mezclar lista: ACTIVADO" or "🔀 Mezclar lista: DESACTIVADO")
end)
bind_command('items', function()
	if state.has_playlist then
		mp.command('script-binding uosc/playlist')
	else
		mp.command('script-binding uosc/open-file')
	end
end)
bind_command('next', function() navigate_item(1) end)
bind_command('prev', function() navigate_item(-1) end)
bind_command('next-file', function() navigate_directory(1) end)
bind_command('prev-file', function() navigate_directory(-1) end)
bind_command('first', function()
	if state.has_playlist then
		mp.commandv('set', 'playlist-pos-1', '1')
	else
		load_file_index_in_current_directory(1)
	end
end)
bind_command('last', function()
	if state.has_playlist then
		mp.commandv('set', 'playlist-pos-1', tostring(state.playlist_count))
	else
		load_file_index_in_current_directory(-1)
	end
end)
bind_command('first-file', function() load_file_index_in_current_directory(1) end)
bind_command('last-file', function() load_file_index_in_current_directory(-1) end)
bind_command('delete-file-prev', function() delete_file_navigate(-1) end)
bind_command('delete-file-next', function() delete_file_navigate(1) end)
bind_command('delete-file-quit', function()
	mp.command('stop')
	if state.path and not is_protocol(state.path) then delete_file(state.path) end
	mp.command('quit')
end)
bind_command('menu-prev', function() Elements:maybe('menu', 'navigate_by_items', -1) end)
bind_command('menu-next', function() Elements:maybe('menu', 'navigate_by_items', 1) end)
bind_command('menu-prev-page', function() Elements:maybe('menu', 'navigate_by_page', -1) end)
bind_command('menu-next-page', function() Elements:maybe('menu', 'navigate_by_page', 1) end)
bind_command('menu-start', function() Elements:maybe('menu', 'navigate_by_items', -math.huge) end)
bind_command('menu-end', function() Elements:maybe('menu', 'navigate_by_items', math.huge) end)
bind_command('menu-activate', function() Elements:maybe('menu', 'activate_selected_item') end)
bind_command('menu-back', function() Elements:maybe('menu', 'back') end)
bind_command('audio-device', create_self_updating_menu_opener({
	title = t('Audio devices'),
	type = 'audio-device-list',
	list_prop = 'audio-device-list',
	active_prop = 'audio-device',
	serializer = function(audio_device_list, current_device)
		current_device = current_device or 'auto'
		local ao = mp.get_property('current-ao') or ''
		local items = {}
		for _, device in ipairs(audio_device_list) do
			if device.name == 'auto' or string.match(device.name, '^' .. ao) then
				local hint = string.match(device.name, ao .. '/(.+)')
				if not hint then hint = device.name end
				items[#items + 1] = {
					title = device.description:sub(1, 7) == 'Default'
						and t('Default %s', device.description:sub(9))
						or device.description,
					hint = hint,
					active = device.name == current_device,
					value = device.name,
				}
			end
		end
		return items
	end,
	on_activate = function(event) mp.commandv('set', 'audio-device', event.value) end,
}))
bind_command('paste', function()
	local has_playlist = mp.get_property_native('playlist-count') > 1
	mp.commandv('script-binding', 'uosc/paste-to-' .. (has_playlist and 'playlist' or 'open'))
end)
bind_command('paste-to-open', function()
	local payload = get_clipboard()
	if payload then mp.commandv('loadfile', payload) end
end)
bind_command('paste-to-playlist', function()
	-- If there's no file loaded, we use `paste-to-open`, which both opens and adds to playlist
	if state.is_idle then
		mp.commandv('script-binding', 'uosc/paste-to-open')
	else
		local payload = get_clipboard()
		if payload then
			mp.commandv('loadfile', payload, 'append')
			mp.commandv('show-text', t('Added to playlist') .. ': ' .. payload, 3000)
		end
	end
end)
bind_command('copy-to-clipboard', function()
	if state.path then
		set_clipboard(state.path)
	else
		mp.commandv('show-text', t('Nothing to copy'), 3000)
	end
end)
bind_command('open-config-directory', function()
	local config_path = mp.command_native({'expand-path', '~~/mpv.conf'})
	local config = serialize_path(normalize_path(config_path))

	if config then
		local args

		if state.platform == 'windows' then
			args = {'explorer', '/select,', config.path}
		elseif state.platform == 'darwin' then
			args = {'open', '-R', config.path}
		elseif state.platform == 'linux' then
			args = {'xdg-open', config.dirname}
		end

		utils.subprocess_detached({args = args, cancellable = false})
	else
		msg.error('Couldn\'t serialize config path "' .. config_path .. '".')
	end
end)
--[[ MESSAGE HANDLERS ]]


mp.register_script_message('show-submenu', function(id) toggle_menu_with_items({submenu = id}) end)
mp.register_script_message('show-submenu-blurred', function(id)
	toggle_menu_with_items({submenu = id, mouse_nav = true})
end)
mp.register_script_message('open-menu', function(json, submenu_id)
	local data = utils.parse_json(json)
	if type(data) ~= 'table' or type(data.items) ~= 'table' then
		msg.error('open-menu: received json didn\'t produce a table with menu configuration')
	else
		local menu = data.type and Menu:is_open(data.type)
		if menu then
			menu:update(data)
			request_render()
		else
			open_command_menu(data, {submenu = submenu_id, on_close = data.on_close})
		end
	end
end)
mp.register_script_message('update-menu', function(json)
	local data = utils.parse_json(json)
	if type(data) ~= 'table' or type(data.items) ~= 'table' then
		msg.error('update-menu: received json didn\'t produce a table with menu configuration')
	else
		local menu = data.type and Menu:is_open(data.type)
		if menu then
			menu:update(data)
			request_render()
		end
	end
end)
mp.register_script_message('select-menu-item', function(type, item_index, menu_id)
	local menu = Menu:is_open(type)
	local index = tonumber(item_index)
	if menu and index and not menu.mouse_nav then
		index = round(index)
		if index > 0 and index <= #menu.current.items then
			menu:select_index(index, menu_id)
			menu:scroll_to_index(index, menu_id, true)
		end
	end
end)
mp.register_script_message('close-menu', function(type)
	if Menu:is_open(type) then Menu:close() end
end)

mp.register_script_message('menu-action', function(name, ...)
    local menu = Menu:is_open()
    if menu then
        local method = ({
            ['search-cancel'] = 'search_cancel',
            ['search-query-update'] = 'search_query_update',
        })[name]
        if method then menu[method](menu, ...) end
    end
end)

mp.register_script_message('thumbfast-info', function(json)
	local data = utils.parse_json(json)
	if type(data) ~= 'table' or not data.width or not data.height then
		thumbnail.disabled = true
		msg.error('thumbfast-info: received json didn\'t produce a table with thumbnail information')
	else
		thumbnail = data
		request_render()
	end
end)
mp.register_script_message('set', function(name, value)
	external[name] = value
	Elements:trigger('external_prop_' .. name, value)
end)
mp.register_script_message('toggle-elements', function(elements) Elements:toggle(comma_split(elements)) end)
mp.register_script_message('set-min-visibility', function(visibility, elements)
	local fraction = tonumber(visibility)
	local ids = comma_split(elements and elements ~= '' and elements or 'timeline,controls,volume,top_bar')
	if fraction then Elements:set_min_visibility(clamp(0, fraction, 1), ids) end
end)
mp.register_script_message('flash-elements', function(elements) Elements:flash(comma_split(elements)) end)
mp.register_script_message('overwrite-binding', function(name, command) key_binding_overwrites[name] = command end)
mp.register_script_message('disable-elements', function(id, elements) Manager:disable(id, elements) end)

mp.register_script_message('toggle-speed-popover', function()
	if Elements.speed then
		Elements.speed:toggle()
	end
end)

mp.register_script_message('dynamic-island-message', function(text, duration)
	if Elements.dynamic_island then
		Elements.dynamic_island:show(text, tonumber(duration))
	end
end)

mp.register_script_message('show-message', function(text, duration)
	if Elements.dynamic_island then
		Elements.dynamic_island:show(text, tonumber(duration))
	else
		mp.osd_message(text, tonumber(duration) or 2)
	end
end)

--[[ ELEMENTS ]]

-- Dynamic elements
local constructors = {
	window_border = require('elements/WindowBorder'),
	buffering_indicator = require('elements/BufferingIndicator'),
	pause_indicator = require('elements/PauseIndicator'),
	top_bar = require('elements/TopBar'),
	timeline = require('elements/Timeline'),
	controls = options.controls and options.controls ~= 'never' and require('elements/Controls'),
	volume = itable_index_of({'left', 'right'}, options.volume) and require('elements/Volume'),
}

-- Required elements
require('elements/Curtain'):new()
require('elements/Speed'):new({render_order = 100, ignores_curtain = true})
require('elements/DynamicIsland'):new()

-- Element manager
-- Handles creating and destroying elements based on disabled_elements user+script config.
Manager = {
	-- Managed disable-able element IDs
	_ids = itable_join(table_keys(constructors), {'idle_indicator', 'audio_indicator'}),
	---@type table<string, string[]> A map of clients and a list of element ids they disable
	_disabled_by = {},
	---@type table<string, boolean>
	disabled = {},
}

-- Set client and which elements it wishes disabled. To undo just pass an empty `element_ids` for the same `client`.
---@param client string
---@param element_ids string|string[]|nil `foo,bar` or `{'foo', 'bar'}`.
function Manager:disable(client, element_ids)
	self._disabled_by[client] = comma_split(element_ids)
	---@diagnostic disable-next-line: deprecated
	self.disabled = create_set(itable_join(unpack(table_values(self._disabled_by))))
	self:_commit()
end

function Manager:_commit()
	-- Create and destroy elements as needed
	for _, id in ipairs(self._ids) do
		local constructor = constructors[id]
		if not self.disabled[id] then
			if not Elements:has(id) and constructor then constructor:new() end
		else
			Elements:maybe(id, 'destroy')
		end
	end

	-- We use `on_display` event to tell elements to update their dimensions
	Elements:trigger('display')
end

-- Initial commit
Manager:disable('user', options.disable_elements)

mp.register_event("file-loaded", function()
    if Elements.speed and Elements.speed.is_open then
        Elements.speed:close()
    end
end)
