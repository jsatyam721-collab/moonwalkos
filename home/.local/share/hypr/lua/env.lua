moonwalk = moonwalk or {}
moonwalk.env.finalize()

-- hl.env sets PATH on the live compositor process, so it is still there for
-- os.getenv on the next `hyprctl reload` -- appending unconditionally grows it
-- by one more copy of moonwalk.path.lib every reload (#1521).
local current_path = moonwalk.env("PATH") or ""
local already_on_path = false
for segment in (current_path .. ":"):gmatch("([^:]*):") do
	if segment == moonwalk.path.lib then
		already_on_path = true
		break
	end
end
if not already_on_path then
	hl.env("PATH", current_path == "" and moonwalk.path.lib or current_path .. ":" .. moonwalk.path.lib)
end
-- ? Isolate dconf (Prevents already-opened GTK apps (brave, nwg-displays, etc.) from updating their theme)
-- hl.env("DCONF_PROFILE",  ((os.getenv("XDG_CONFIG_HOME") ~= "" and os.getenv("XDG_CONFIG_HOME")) or (os.getenv("HOME") or "" ) .. "/.config") .. "/dconf/profile/moonwalk_hyprland")

-- NVIDIA hook
-- https://wiki.hypr.land/Nvidia/
-- This is only a bare minimum to get NVIDIA working.
-- User may need to add specific variables for their
-- setup in ~/.config/hypr/hyprland.lua
-- The probe reads two files and never leaves the process. It used to run
-- nvidia-smi, which is what took whole sessions down: Hyprland gives the
-- entire configuration 1500 ms and its watchdog counts VM instructions, so it
-- cannot interrupt a blocked C call. A laptop that has to wake a sleeping
-- discrete GPU to answer spends the budget here, and every module loaded after
-- this one dies with a timeout reported somewhere unrelated.
local function has_nvidia_working()
	local version = io.open("/proc/driver/nvidia/version", "r")
	if not version then
		return false
	end
	version:close()

	-- The module registers /proc as it comes up, so a driver that is still
	-- loading or on its way out is ruled out by its recorded state.
	local initstate = io.open("/sys/module/nvidia/initstate", "r")
	if not initstate then
		return true
	end

	local state = initstate:read("*l")
	initstate:close()

	return state == "live"
end

local function read_line(path)
	local f = io.open(path, "r")
	if not f then
		return nil
	end
	local line = f:read("*l")
	f:close()
	return line
end

-- On a hybrid laptop the iGPU drives the panel and NVIDIA only renders on
-- request; pointing GBM and GLX at nvidia there keeps the dGPU awake and
-- breaks apps on the iGPU. So the vars only go on when NVIDIA is the GPU the
-- firmware booted on (boot_vga), or the only GPU there is. Plain file reads,
-- same as above, so this stays well inside the config time budget.
local function nvidia_drives_display()
	local other_gpu = false
	for i = 0, 15 do
		local base = "/sys/class/drm/card" .. i .. "/device/"
		local vendor = read_line(base .. "vendor")
		if vendor then
			if read_line(base .. "boot_vga") == "1" then
				return vendor == "0x10de"
			end
			if vendor ~= "0x10de" then
				other_gpu = true
			end
		end
	end
	return not other_gpu
end

if has_nvidia_working() and nvidia_drives_display() then
	hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
	hl.env("GBM_BACKEND", "nvidia-drm")
	-- VA-API on nvidia needs libva-nvidia-driver; without it video decode fails
	local vaapi = io.open("/usr/lib/dri/nvidia_drv_video.so", "rb")
	if vaapi then
		vaapi:close()
		hl.env("LIBVA_DRIVER_NAME", "nvidia")
	end
end
