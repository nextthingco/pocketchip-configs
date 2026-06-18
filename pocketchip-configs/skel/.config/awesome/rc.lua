-- PocketC.H.I.P. awesome config, ported from the original NTC awesome 3.4/3.5
-- config to awesome 4.x (the version in Debian trixie). The 3.x API this used --
-- awesome.add_signal / client.add_signal / awful.util.spawn* / screen.count() --
-- was removed in 4.0, which made the old rc.lua throw on startup and fall back
-- to awesome's default config (so none of the PocketCHIP session ran).
--
-- Minimal by design: a single fullscreen tag, no wibar/titlebars, the home
-- screen (pocket-home) + onboard launched at startup, and the hardware keys
-- wired the PocketCHIP way.

-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")
-- Theme handling library
local beautiful = require("beautiful")
-- Notification library
local naughty = require("naughty")
-- Rules (the require installs the manage-signal hook that applies them)
require("awful.rules")

local USE_DBG = false
dbg = function (msg)
    if USE_DBG then
        naughty.notify({ preset = naughty.config.presets.critical,
                         title = "DBG MSG:",
                         text = msg })
    end
end

dbgclient = function (event_name, c)
    dbg(event_name.." "..tostring(c.pid).." "..tostring(c.window).." "..(c.class or "_c").." "..(c.name or "_n"))
end

-- {{{ Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
    if USE_DBG then
        naughty.notify({ preset = naughty.config.presets.critical,
                         title = "Oops, there were errors during startup!",
                         text = awesome.startup_errors })
    end
end

-- Handle runtime errors after startup
do
    local in_error = false
    awesome.connect_signal("debug::error", function (err)
        if USE_DBG then
            -- Make sure we don't go into an endless error loop
            if in_error then return end
            in_error = true

            naughty.notify({ preset = naughty.config.presets.critical,
                             title = "Oops, an error happened!",
                             text = tostring(err) })
            in_error = false
        end
    end)
end
-- }}}

-- {{{ client API
onboard = {}
home_screen = {}

focus_next_client = function ()
    awful.client.focus.byidx(1)
    -- never land on the home screen (pocket-home); skip past it
    if client.focus and client.focus == home_screen.client then
        awful.client.focus.byidx(1)
    end

    if client.focus then
        client.focus:raise()
    end
end

focus_client_by_window_id = function (window_id)
    for _, c in ipairs(client.get()) do
        if c.window == window_id then
            client.focus = c
            if client.focus then
                client.focus:raise()
            end
        end
    end
end

launch_home_screen = function ()
    if home_screen.client then
        client:kill()
        home_screen = {}
    end
    awful.spawn.with_shell("pocket-home")
end

focus_home_screen = function ()
    if home_screen.client then
        client.focus = home_screen.client
        if client.focus then
            client.focus:raise()
        end
    else
        launch_home_screen()
    end
end

hide_mouse_cursor = function ()
    -- hide mouse pointer on root window
    awful.spawn.with_shell("xsetroot -cursor $HOME/.config/awesome/blank_ptr.xbm $HOME/.config/awesome/blank_ptr.xbm")
end
-- }}}

-- {{{ Variable definitions
-- Themes define colours, icons, and wallpapers
beautiful.init(os.getenv("HOME") .. "/.config/awesome/theme.lua")

-- This is used later as the default terminal and editor to run.
local terminal = "lxterminal"
local editor = os.getenv("EDITOR") or "editor"
local editor_cmd = terminal .. " -e " .. editor

-- Default modkey.
-- Usually, Mod4 is the key with a logo between Control and Alt.
-- If you do not like this or do not have such a key,
-- I suggest you to remap Mod4 to another key using xmodmap or other tools.
-- However, you can use another modifier like Mod1, but it may interact with others.
local modkey = "Mod1"

-- The only layout PocketCHIP uses: one app, fullscreen.
awful.layout.layouts = { awful.layout.suit.max.fullscreen }
-- }}}

-- {{{ Wallpaper + per-screen tag
-- 4.x sets the wallpaper from here (theme.wallpaper_cmd/awsetbg is gone).
local function set_wallpaper(s)
    gears.wallpaper.maximized("/usr/share/pocketchip/boot-splash.png", s, true)
end

-- re-apply on resolution changes
screen.connect_signal("property::geometry", set_wallpaper)

awful.screen.connect_for_each_screen(function(s)
    set_wallpaper(s)
    -- a single tag, fullscreen layout
    awful.tag({ "1" }, s, awful.layout.layouts[1])
end)
-- }}}

-- {{{ Mouse bindings
root.buttons(gears.table.join(
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev)
))
-- }}}

-- {{{ Key bindings
local globalkeys = gears.table.join(
    awful.key({ }                  , "XF86PowerOff", focus_home_screen),
    awful.key({ modkey,           }, "Tab", focus_next_client),
    awful.key({ "Control",        }, "Tab", focus_next_client),
    awful.key({ modkey,           }, "Return", function () awful.spawn("dmenu_run", false) end)
)

local clientkeys = gears.table.join(
    awful.key({ "Control"         }, "q",
        function (c)
            if c ~= home_screen.client then
                c:kill()
            end
        end)
)

local clientbuttons = gears.table.join(
    awful.button({ }, 1, function (c) client.focus = c; c:raise() end),
    -- left click and mod allows you to move windows
    awful.button({ modkey }, 1, awful.mouse.client.move),
    -- right click when holding mod
    awful.button({ "Control" }, 1, function (c) awful.spawn("xdotool click 3", false) end))

-- Set global keys
root.keys(globalkeys)
-- }}}

-- {{{ Rules
awful.rules.rules = {
    -- All clients will match this rule.
    { rule = { },
      properties = { border_width = 0,
                     border_color = beautiful.border_normal,
                     focus = awful.client.focus.filter,
                     keys = clientkeys,
                     buttons = clientbuttons } }
}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.

client.connect_signal("focus", function (c)
  hide_mouse_cursor()
end)

client.connect_signal("unfocus", function (c)
  if c == onboard.client then
      awful.spawn("xdotool search --name ahoy windowactivate", false)
  end
end)

client.connect_signal("manage", function (c)
    -- match homescreen by name
    if c.name == "pocket-home" then
        home_screen.client = c
    -- match onboarding by class
    elseif c.class == "ahoy" then
        onboard.client = c
        c.ontop = true
    end

    if not awesome.startup then
      -- Put windows in a smart way, only if they do not set an initial position.
      if not c.size_hints.user_position and not c.size_hints.program_position then
          awful.placement.no_overlap(c)
          awful.placement.no_offscreen(c)
      end
    end
end)

-- cleanup watched clients
-- FIXME: make sure to ignore if we don't have a client,
-- apparently it's possible for unmanage to be called before manage
-- when certain applications first open.
client.connect_signal("unmanage", function (c)
    -- match homescreen
    if c.name == "pocket-home" then
        home_screen = {}
    -- match onboarding
    elseif c.class == "ahoy" then
        onboard = {}
    end
end)
-- }}}

-- {{{ Startup applications
hide_mouse_cursor()

-- load keymapping
awful.spawn.with_shell("setxkbmap pocketchip")

-- do screen brightness management
awful.spawn.with_shell("/usr/sbin/pocketchip-load")

-- launch onboarding
awful.spawn.with_shell("onboard $HOME/.config/onboard /usr/share/pocketchip-onboard/")

-- launch home screen
launch_home_screen()
-- }}}
