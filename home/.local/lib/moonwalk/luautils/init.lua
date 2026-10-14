-- luautils/init.lua
-- Initializes Lua module search paths for MoonwalkOS using XDG base directories.
local xdg = require("luautils.xdg")

local XDG_DATA_HOME = xdg.data
local XDG_STATE_HOME = xdg.state
local XDG_CONFIG_HOME = xdg.config

local MOONWALK_STATE_HOME = os.getenv("MOONWALK_STATE_HOME") or (XDG_STATE_HOME .. "/moonwalk")
local MOONWALK_CONFIG_HOME = os.getenv("MOONWALK_CONFIG_HOME") or (XDG_CONFIG_HOME .. "/moonwalk")

local MOONWALK_SCRIPTS_PATH = os.getenv("MOONWALK_SCRIPTS_PATH")
if not MOONWALK_SCRIPTS_PATH then
    local src = debug.getinfo(1, "S").source
    if src and src:sub(1, 1) == "@" then
        local luautils_dir = src:sub(2):match("(.*/luautils)/")
        if luautils_dir then
            MOONWALK_SCRIPTS_PATH = luautils_dir:gsub("/luautils/$?", "")
        end
    end
end
MOONWALK_SCRIPTS_PATH = MOONWALK_SCRIPTS_PATH or (XDG_DATA_HOME .. "/moonwalk")
local lua_version = _VERSION:match("%d+%.%d+")

local pkg_paths = {
    MOONWALK_STATE_HOME .. "/?.lua",
    MOONWALK_SCRIPTS_PATH .. "/?.lua",
    MOONWALK_SCRIPTS_PATH .. "/luautils/?.lua",
    XDG_DATA_HOME .. "/hypr/lua/?.lua",
    MOONWALK_CONFIG_HOME .. "/hypr/?.lua",
    MOONWALK_STATE_HOME .. "/lua_env/share/lua/" .. lua_version .. "/?.lua",
    MOONWALK_STATE_HOME .. "/lua_env/share/lua/" .. lua_version .. "/?/init.lua"
}
for _, d in ipairs(xdg.dirs.config) do
    if d and d ~= "" then
        table.insert(pkg_paths, d .. "/moonwalk/?.lua")
        table.insert(pkg_paths, d .. "/moonwalk/?/init.lua")
    end
end
package.path = package.path .. ";" .. table.concat(pkg_paths, ";") .. ";"
package.cpath =
    package.cpath ..
    ";" ..
        MOONWALK_STATE_HOME ..
            "/lua_env/lib/lua/" ..
                lua_version .. "/?.so;" .. MOONWALK_STATE_HOME .. "/lua_env/lib/lua/" .. lua_version .. "/?/init.so;"
