-- [[
--    window_border.lua - Windows 11 Native Rounded Corners for MPV
--    Applies DwmSetWindowAttribute (DWMWA_WINDOW_CORNER_PREFERENCE = 33, DWMWCP_ROUND = 2)
--    and DwmExtendFrameIntoClientArea to enable smooth rounded corners in windowed mode.
-- ]]

local mp = require "mp"

local is_windows = package.config:sub(1, 1) == "\\"
if not is_windows then return end

local status, ffi = pcall(require, "ffi")
if not status or not ffi then return end

ffi.cdef[[
    typedef void* HWND;
    typedef unsigned long DWORD;
    typedef int BOOL;
    typedef const void* LPCVOID;
    typedef long HRESULT;
    typedef struct {
        int cxLeftWidth;
        int cxRightWidth;
        int cyTopHeight;
        int cyBottomHeight;
    } MARGINS;

    DWORD GetCurrentProcessId();
    DWORD GetWindowThreadProcessId(HWND hWnd, DWORD *lpdwProcessId);
    HWND GetWindow(HWND hWnd, unsigned int uCmd);
    HWND GetTopWindow(HWND hWnd);
    BOOL IsWindowVisible(HWND hWnd);
    HRESULT DwmSetWindowAttribute(HWND hwnd, DWORD dwAttribute, LPCVOID pvAttribute, DWORD cbAttribute);
    HRESULT DwmExtendFrameIntoClientArea(HWND hWnd, const MARGINS *pMarInset);
]]

local user32 = ffi.load("user32.dll")
local kernel32 = ffi.load("kernel32.dll")
local dwmapi = ffi.load("dwmapi.dll")

local mpv_hwnd = nil

local function get_mpv_hwnd()
    if mpv_hwnd then return mpv_hwnd end
    local my_pid = kernel32.GetCurrentProcessId()
    local hwnd = user32.GetTopWindow(nil)
    local pid_buf = ffi.new("DWORD[1]")
    while hwnd ~= nil do
        user32.GetWindowThreadProcessId(hwnd, pid_buf)
        if pid_buf[0] == my_pid and user32.IsWindowVisible(hwnd) ~= 0 then
            mpv_hwnd = hwnd
            return hwnd
        end
        hwnd = user32.GetWindow(hwnd, 2) -- GW_HWNDNEXT = 2
    end
    return nil
end

local corners_applied = false

local function apply_corners()
    local is_fs = mp.get_property_bool("fullscreen", false)
    local is_max = mp.get_property_bool("window-maximized", false)
    local hwnd = get_mpv_hwnd()
    if not hwnd then return false end

    if not is_fs and not is_max then
        -- 33 = DWMWA_WINDOW_CORNER_PREFERENCE, 2 = DWMWCP_ROUND (Standard rounded corners)
        local pref = ffi.new("int[1]", 2)
        dwmapi.DwmSetWindowAttribute(hwnd, 33, pref, ffi.sizeof("int"))

        -- Extend frame into client area to activate rounded clipping & soft drop shadow
        local margins = ffi.new("MARGINS", {1, 1, 1, 1})
        dwmapi.DwmExtendFrameIntoClientArea(hwnd, margins)
        corners_applied = true
        return true
    end
    return false
end

local border_timer_pending = false
local function schedule_corners(delay)
    if border_timer_pending then return end
    border_timer_pending = true
    mp.add_timeout(delay or 0.05, function()
        border_timer_pending = false
        apply_corners()
    end)
end

mp.observe_property("fullscreen", "bool", function() schedule_corners(0.05) end)
mp.observe_property("window-maximized", "bool", function() schedule_corners(0.05) end)

mp.register_event("file-loaded", function()
    if not corners_applied then
        schedule_corners(0.1)
    end
end)

-- Initial retry initialization: stops as soon as HWND is acquired and applied
local function init_corners(retries)
    if apply_corners() or retries <= 0 then return end
    mp.add_timeout(0.2, function()
        init_corners(retries - 1)
    end)
end

init_corners(4)
