--!      ░▒▒▒░░░▓▓           ___________
--!    ░░▒▒▒░░░░░▓▓        //___________/
--!   ░░▒▒▒░░░░░▓▓     _   _ _    _ _____
--!   ░░▒▒░░░░░▓▓▓▓▓▓ | | | | |  | |  __/
--!    ░▒▒░░░░▓▓   ▓▓ | |_| | |_/ /| |___
--!     ░▒▒░░▓▓   ▓▓   \__  |____/ |____/
--!       ░▒▓▓   ▓▓  //____/

-- // ██████╗░░█████╗░  ███╗░░██╗░█████╗░████████╗  ███████╗██████╗░██╗████████╗
-- // ██╔══██╗██╔══██╗  ████╗░██║██╔══██╗╚══██╔══╝  ██╔════╝██╔══██╗██║╚══██╔══╝
-- // ██║░░██║██║░░██║  ██╔██╗██║██║░░██║░░░██║░░░  █████╗░░██║░░██║██║░░░██║░░░
-- // ██║░░██║██║░░██║  ██║╚████║██║░░██║░░░██║░░░  ██╔══╝░░██║░░██║██║░░░██║░░░
-- // ██████╔╝╚█████╔╝  ██║░╚███║╚█████╔╝░░░██║░░░  ███████╗██████╔╝██║░░░██║░░░
-- // ╚═════╝░░╚════╝░  ╚═╝░░╚══╝░╚════╝░░░░╚═╝░░░  ╚══════╝╚═════╝░╚═╝░░░╚═╝░░░

-- require() resolves against the directory of the config Hyprland was started
-- with, which since v26.8.1 is the user's hyprland.lua, not this file. The
-- resolver is therefore loaded by its own path; everything below loads by name
-- from the search path it sets.
local root = assert(debug.getinfo(1, "S").source:match("^@(.*)/"), "not loaded from a file")

---@module "moonwalk"
moonwalk = moonwalk or {}
---@diagnostic disable-next-line: inject-field
moonwalk.path = dofile(root .. "/lua/moonwalk/path.lua")
package.loaded["moonwalk.path"] = moonwalk.path

local pkg_paths = {
	moonwalk.path.state .. "/moonwalk/?.lua", -- Lua state
	moonwalk.path.lib .. "/moonwalk/?.lua", -- lib scripts
	moonwalk.path.lib .. "/moonwalk/luautils/?.lua", -- lib scripts
	moonwalk.path.share .. "/hypr/lua/?.lua",
	moonwalk.path.state .. "/moonwalk/lua_env/share/lua/5.5/?.lua", -- virtual env for lua
	moonwalk.path.state .. "/moonwalk/lua_env/share/lua/5.5/?/init.lua", -- virtual env for lua
	moonwalk.path.config .. "/hypr/?.lua", -- expose main users config
	root .. "/lua/?.lua" -- this file's own tree, whatever prefix it sits under
}

package.path = package.path .. ";" .. table.concat(pkg_paths, ";") .. ";"
package.cpath = package.cpath
	.. ";"
	.. moonwalk.path.state
	.. "/moonwalk/lua_env/lib/lua/5.5/?.so" -- virtual env shared objects

-- Let's call it early so we can use it in other files
local utils = require("moonwalk.utils")
require("moonwalk.env")
require("moonwalk.config")
require("moonwalk.binds")
require("moonwalk.dispatcher")
require("moonwalk.handlers")

local check_require = utils.check_require

-- * Variables
require("variables")
-- * Default values
require("defaults")
--* Window rules
require("window_rules")
--* Layer rules
require("layer_rules")
-- * Environment variable Setup
require("env")
-- * Binds
require("key_binds")
--* Dynamic Stuff example theming and variable handlings
require("dynamic")
-- * Event handlers for more DE like experience
require("events")
--* MoonwalkOS's startup overridable too!
require("start_up")
-- * Automatically load generated monitor configs (e.g., from nwg-displays)
check_require("monitors")
-- --* user now can have this file
check_require("hyprland")
-- --* workflows configuration overrides everything
check_require("lua_state.workflows")
