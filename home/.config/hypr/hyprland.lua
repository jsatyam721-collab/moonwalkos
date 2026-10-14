-- Hyprland loads this file when it is started without a config, and it prefers
-- it over hyprland.conf. MoonwalkOS loads it too, last, as the override layer below.
-- The block keeps the two apart: moonwalk.lua sets `moonwalk` on its first line, so it
-- runs only when this file is the entry point and MoonwalkOS has not been loaded.
-- Removing it leaves a session with a cursor and nothing else.
if not moonwalk then
	local share = os.getenv("XDG_DATA_HOME") or (os.getenv("HOME") .. "/.local/share")
	local entry = share .. "/hypr/moonwalk.lua"
	local handle = io.open(entry, "r")
	if not handle then
		error("MoonwalkOS is not installed at " .. entry .. ". Run install.sh -r, or point Hyprland at your own config.")
	end
	handle:close()
	dofile(entry)
end

-- Your Hyprland configuration. MoonwalkOS never overwrites this file.
--
-- It loads after MoonwalkOS's own binds, so settings here take precedence. Replacing
-- a bind needs more than that: see below. MoonwalkOS's defaults live in
-- ~/.local/share/hypr/lua/ and are overwritten on every update, so edits there
-- do not survive.
--
-- Adding a keybind:
--
--     hl.bind("SUPER + SPACE", hl.dsp.exec_cmd(moonwalk.sh.gamelauncher()), {
--         description = "[Utilities] game launcher",
--     })
--
-- Replacing one of MoonwalkOS's: bind the same combination again and yours takes
-- over, but copy its flags across as well. A bind counts as the same one only
-- when its flags match, and `description` is not a flag — miss one and both
-- binds stay live on that combination. Copy the whole options table from
-- ~/.local/share/hypr/lua/key_binds.lua and change only what you need:
--
--     hl.bind("F9", hl.dsp.exec_cmd(moonwalk.sh.volumecontrol("-o", "m")), {
--         locked = true,
--         description = "[Hardware Controls|Audio] un/mute output",
--     })
--
-- Press SUPER + / to see what is actually loaded, your own binds included.
-- The full reference is KEYBINDINGS.md in the MoonwalkOS repository.
--
-- Other Lua files next to this one can be pulled in with require("name").
hl.window_rule({
      name = "wezterm_clear_glass",
      match = { class = "^(org\\.wezfurlong\\.wezterm)$" },
      no_blur = true,
})

hl.layer_rule({
      name = "batman_notification_swoop",
      match = { namespace = "^(notifications)$" },
      animation = "slide right",
})

hl.layer_rule({
      name = "rofi_reveal",
      match = { namespace = "^(rofi)$" },
      animation = "slide bottom",
      dim_around = true,
})

hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd("pkill -f '^qs -p .*/wallwheel' || qs -p " .. os.getenv("HOME") .. "/.config/wallwheel"), {
      description = "[Theming and Wallpaper] wallwheel wallpaper picker",
})

hl.bind("SUPER + M", hl.dsp.exec_cmd("qs ipc -p " .. os.getenv("HOME") .. "/.config/musicwidget call music toggle || qs -p " .. os.getenv("HOME") .. "/.config/musicwidget"), {
      description = "[Launcher] comic music player",
})

hl.unbind("SUPER + SHIFT + T")
hl.unbind("SUPER + ALT + Up")
hl.unbind("SUPER + ALT + Down")

hl.env("MOONWALK_LOCKSCREEN", "mjlock")
hl.unbind("SUPER + SHIFT + U")

hl.bind("SUPER + Delete", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/crt-logout"), {
      description = "[Window Management] exit hyprland session (CRT power-off)",
})

hl.layer_rule({
      name = "crt_overlays_no_anim",
      match = { namespace = "^(crtin|crtout)$" },
      no_anim = true,
})

hl.on("hyprland.start", function()
      hl.exec_cmd("qs -p " .. os.getenv("HOME") .. "/.config/crtin")
end)

hl.config({ misc = { background_color = "rgba(000000ff)" } })

local start = moonwalk.config.start
if start and start.wallpaper and start.wallpaper ~= "" and not start.wallpaper:find("crtin", 1, true) then
      start.wallpaper = "sh -c 'for i in $(seq 40); do hyprctl layers -j 2>/dev/null | grep -q crtin && break; sleep 0.05; done; exec "
            .. start.wallpaper .. "'"
end
if start then
      start.applet_network_manager = nil
      start.applet_bluetooth = nil
end

hl.layer_rule({
      name = "mogo_no_anim",
      match = { namespace = "^(mogo)$" },
      no_anim = true,
})

hl.bind("SUPER + A", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/mogo"), {
      description = "[Launcher|Rofi menus] Mogo app launcher",
})

hl.on("hyprland.start", function()
      hl.exec_cmd("qs -p " .. os.getenv("HOME") .. "/.config/mogo")
end)

hl.layer_rule({
      name = "phone_no_anim",
      match = { namespace = "^(phone|phone-hotcorner)$" },
      no_anim = true,
})

hl.bind("SUPER + N", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/phone"), {
      description = "[Utilities] phone: network + quick settings",
})

hl.on("hyprland.start", function()
      hl.exec_cmd("qs -p " .. os.getenv("HOME") .. "/.config/phone")
end)

hl.layer_rule({
      name = "moonwalk_power_no_anim",
      match = { namespace = "^(moonwalk-power)$" },
      no_anim = true,
})

hl.on("hyprland.start", function()
      hl.exec_cmd("qs -p " .. os.getenv("HOME") .. "/.config/moonwalk-power")
end)
