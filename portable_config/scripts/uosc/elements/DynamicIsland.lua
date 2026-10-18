local Element = require('elements/Element')

---@class DynamicIsland : Element
local DynamicIsland = class(Element)

function DynamicIsland:new() return Class.new(self) --[[@as DynamicIsland]] end

function DynamicIsland:init()
	Element.init(self, 'dynamic_island', {render_order = 1002})
	self.ignores_curtain = true

	self.text = ""
	self.progress = 0 -- 0: tiny dot / closed, 1: fully expanded pill
	self.state = 'idle' -- 'idle', 'expanding', 'holding', 'shrinking'
	self.hold_timer = mp.add_timeout(1.8, function() self:shrink() end)
	self.hold_timer:kill()
end

function DynamicIsland:show(text, duration_ms)
	if not text or text == "" then return end
	self.text = text
	self.enabled = true
	self.hold_timer:kill()
	self:tween_stop()

	local font_size = round(14 * state.scale)
	local tw = text_width(self.text, {size = font_size, bold = true})
	self.target_width = math.max(round(120 * state.scale), tw + round(40 * state.scale))
	self.target_height = round(34 * state.scale)

	self.state = 'expanding'
	local duration = 0.22 -- 220ms expand
	self:tween(self.progress, 1, function(val)
		self.progress = val
		request_render()
	end, duration, function()
		self.progress = 1
		self.state = 'holding'
		request_render()
		local hold_time = 2.0
		if duration_ms and duration_ms > 0 then
			hold_time = (duration_ms > 50) and (duration_ms / 1000) or duration_ms
		end
		self.hold_timer.timeout = hold_time
		self.hold_timer:kill()
		self.hold_timer:resume()
	end)
end

function DynamicIsland:shrink()
	self.hold_timer:kill()
	self:tween_stop()
	self.state = 'shrinking'
	local duration = 0.18 -- 180ms shrink back to dot
	self:tween(self.progress, 0, function(val)
		self.progress = val
		request_render()
	end, duration, function()
		self.progress = 0
		self.state = 'idle'
		self.enabled = false
		request_render()
	end)
end

function DynamicIsland:render()
	if self.state == 'idle' or self.progress <= 0.01 then return end

	local ass = assdraw.ass_new()
	local min_dim = round(14 * state.scale)
	local full_w = self.target_width or round(180 * state.scale)
	local full_h = self.target_height or round(34 * state.scale)

	-- Smooth exponential expansion curve for dynamic island feel
	local ease_progress = 1 - (1 - self.progress) ^ 2
	local cur_w = round(min_dim + (full_w - min_dim) * ease_progress)
	local cur_h = round(min_dim + (full_h - min_dim) * ease_progress)
	local cur_radius = round(cur_h / 2)

	local cx = round(display.width / 2)
	local cy = round(32 * state.scale)
	local ax = cx - round(cur_w / 2)
	local bx = cx + round(cur_w / 2)
	local ay = cy - round(cur_h / 2)
	local by = cy + round(cur_h / 2)

	self:set_coordinates(ax, ay, bx, by)

	-- Interactive click-to-dismiss zone
	if self.progress > 0.4 and cursor then
		cursor:zone('primary_down', self, function()
			self:shrink()
		end)
	end

	local alpha_factor = math.min(1.0, self.progress * 1.6)

	-- Draw outer soft glow/shadow
	ass:rect(ax - 1, ay - 1, bx + 1, by + 1, {
		color = '000000',
		radius = cur_radius + 1,
		opacity = 0.35 * alpha_factor,
	})

	-- Draw deep obsidian pill body
	ass:rect(ax, ay, bx, by, {
		color = '0B0C10',
		radius = cur_radius,
		border = 1,
		border_color = '2B2E3A',
		opacity = {main = 0.94 * alpha_factor, border = 0.40 * alpha_factor},
	})

	-- Draw inner subtle glass highlight ring
	ass:rect(ax + 1, ay + 1, bx - 1, by - 1, {
		color = '1B1C22',
		radius = math.max(0, cur_radius - 1),
		border = 0,
		opacity = 0.20 * alpha_factor,
	})

	-- Draw text if island is expanded enough
	if self.progress > 0.55 then
		local text_alpha = clamp(0, (self.progress - 0.55) / 0.45, 1)
		local font_size = round(13 * state.scale)

		ass:txt(cx, cy, 5, self.text, {
			size = font_size,
			bold = true,
			color = 'FFFFFF',
			border = 0,
			opacity = text_alpha,
		})
	end

	return ass
end

return DynamicIsland
