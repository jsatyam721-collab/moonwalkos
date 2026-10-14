--[[-
    moonwalk.dispatcher.lua

    Provides two helper namespaces:
      * moonwalk.sh / moonwalk.shell  - builds moonwalk-shell command strings
      * moonwalk.dsp             - executes via hl.dsp.exec_cmd internally

    Usage:
      local cmd = moonwalk.sh.command.some("arg1", "arg2")
      -- returns: "moonwalk-shell command.some arg1 arg2"

      moonwalk.dsp.command.some("arg1", "arg2")
      -- executes: hl.dsp.exec_cmd("moonwalk-shell command.some arg1 arg2")()

      moonwalk.dsp("command.ext arg1 arg2")
      -- executes: hl.dsp.exec_cmd("moonwalk-shell command.ext arg1 arg2")()

    Extension stripping:
      command.sh -> command
      command.py -> command
      command.lua -> command

    Command map:
      moonwalk.command_map = {
          ["command.sub.sub"] = { "custom", "mapped", "command" },
          ["command.ext"] = "custom-script.sh",
      }

    Notes:
      * moonwalk.sh and moonwalk.shell only build strings
      * moonwalk.dsp runs the command immediately
      * dot-separated names like command.sub.name are preserved
]]


local function trim(str)
    if type(str) ~= "string" then
        return str
    end
    return str:match("^%s*(.-)%s*$")
end

local function remove_extension(name)
    if type(name) ~= "string" then
        return name
    end
    local result = name:gsub("%.sh$", ""):gsub("%.py$", ""):gsub("%.lua$", "")
    return result
end

local function split_whitespace(str)
    local out = {}
    for token in str:gmatch("%S+") do
        out[#out + 1] = token
    end
    return out
end


-- Shell-quote a single argument for safe command-line usage
local function shell_quote(arg)
    arg = tostring(arg)
    -- Escape single quotes: ' -> '\''
    arg = arg:gsub("'", "'\\''")
    return "'" .. arg .. "'"
end

local function join_args(args)
    local out = {}
    for _, v in ipairs(args) do
        out[#out + 1] = shell_quote(v)
    end
    return table.concat(out, " ")
end

local function resolve_mapped_command(command)
    local key = remove_extension(trim(command))
    if type(_G.moonwalk.command_map) == "table" then
        local mapped = _G.moonwalk.command_map[key]
        if type(mapped) == "table" then
            return table.concat(mapped, ".")
        elseif type(mapped) == "string" then
            return remove_extension(trim(mapped))
        end
    end
    return key
end

local function build_shell_string(command, ...)
    command = resolve_mapped_command(command)
    local args = {...}
    local full = command
    if #args > 0 then
        full = full .. " " .. join_args(args)
    end
    return "moonwalk-shell " .. full
end

local function exec_shell_string(command, ...)
    local cmd = build_shell_string(command, ...)
    if type(hl.dsp) == "table" and type(hl.dsp.exec_cmd) == "function" then
        local runner = hl.dsp.exec_cmd(cmd)
        if type(runner) == "function" then
            return runner()
        end
        return runner
    end
    if type(hl.exec_cmd) == "function" then
        local runner = hl.exec_cmd(cmd)
        if type(runner) == "function" then
            return runner()
        end
        return runner
    end
    error("no dispatcher available to execute: " .. tostring(cmd))
end

local function create_shell_proxy(prefix)
    prefix = prefix or ""
    return setmetatable({}, {
        __index = function(_, key)
            local next_prefix = prefix == "" and key or prefix .. "." .. key
            return create_shell_proxy(next_prefix)
        end,
        __call = function(_, ...)
            return build_shell_string(prefix, ...)
        end,
    })
end

local function create_dsp_proxy(prefix)
    prefix = prefix or ""
    return setmetatable({}, {
        __index = function(_, key)
            local next_prefix = prefix == "" and key or prefix .. "." .. key
            return create_dsp_proxy(next_prefix)
        end,
        __call = function(_, ...)
            return exec_shell_string(prefix, ...)
        end,
    })
end

_G.moonwalk = _G.moonwalk or {}
-- Map hypr commands to custom shell command targets.
-- Use string values or arrays for dot-joined replacement.
-- Example:
moonwalk.command_map = {
--     ["command.sub.sub"] = { "custom", "mapped", "command" },
--     ["command.ext"] = "custom-script.sh",
[ "window.pin" ] = "window.pin",
[ "session.logout.launcher" ] = "logoutlaunch",
[ "session.lock" ] = "lock-session",
[ "waybar.toggle" ] = "waybar.py --hide",
[ "menu.apps" ] = "rofilaunch d",
[ "menu.windows" ] = "rofilaunch w",
[ "menu.files" ] = "rofilaunch f",
[ "menu.binds" ] = "keybinds_hint",
[ "menu.emoji" ] = "emoji-picker",
[ "menu.glyph" ] = "glyph-picker",
[ "menu.clipboard" ] = "cliphist -c",
[ "menu.cliphist" ] = "cliphist",
[ "menu.launcher" ] = "rofilaunch",
[ "menu.select" ] = "rofiselect",
[ "menu.calculator" ] = "calculator",
[ "menu.search" ] = "rofi.websearch",
[ "kb.switch" ] = "keyboardswitch",
[ "colorpicker" ] = "hyprpicker -an",
[ "screenshot.full"] = "screenshot p",
[ "screenshot.snip"] = "screenshot s",
[ "screenshot.freeze"] = "screenshot sf",
[ "screenshot.monitor"] = "screenshot m",
[ "screenshot.ocr"] = "screenshot sc",
[ "wallpaper" ] = "wallpaper --global",
[ "menu.wallbash" ] = "wallbashtoggle -m",
[ "menu.themes"] = "theme.select",
[ "menu.wallpapers"] = "wallpaper -GS",

}
_G.moonwalk.command_map = _G.moonwalk.command_map or {}
_G.moonwalk.sh = _G.moonwalk.sh or create_shell_proxy()
_G.moonwalk.shell = _G.moonwalk.shell or _G.moonwalk.sh
_G.moonwalk.dsp = _G.moonwalk.dsp or create_dsp_proxy()

_G.moonwalk.sh.map = _G.moonwalk.sh.map or _G.moonwalk.command_map
_G.moonwalk.shell.map = _G.moonwalk.shell.map or _G.moonwalk.sh.map
_G.moonwalk.dsp.map = _G.moonwalk.dsp.map or _G.moonwalk.command_map

setmetatable(_G.moonwalk.dsp, {
    __index = function(_, key)
        return create_dsp_proxy(key)
    end,
    __call = function(_, raw)
        if type(raw) ~= "string" then
            return nil
        end
        local tokens = split_whitespace(raw)
        if #tokens == 0 then
            return nil
        end
        local command = table.remove(tokens, 1)
        return exec_shell_string(command, table.unpack(tokens))
    end,
})
