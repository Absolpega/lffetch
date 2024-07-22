#!/usr/bin/env lua

local json = { null = {}, escape_map = { [ [[\\]] ] = "\\", [ [[\"]] ] = '"' } }

local function json_parse_string(str)
    local whitespace, string = str:match("^([ \010\013\009]*)(..)")
    if string == '""' then
        return "", #whitespace + 2
    end
    string = str:match([=["(.-[^\])"]=], #whitespace)
    return string:gsub([[\.]], json.escape_map), #whitespace + #string + 2
end

function json.decode(str)
    local bytes_read = 0

    local function skip_whitespace()
        bytes_read = bytes_read
            + #str:match("^([ \010\013\009]*)", bytes_read + 1)
    end

    local function read_char()
        bytes_read = bytes_read + 1
        return str:sub(bytes_read, bytes_read)
    end

    local b = 0
    skip_whitespace()
    local char = read_char()
    if char == "{" then
        local t = {}
        repeat
            local key
            local colon
            local value
            local final
            key, b = json_parse_string(str:sub(bytes_read + 1))
            assert(key)
            bytes_read = bytes_read + b

            colon = read_char()
            assert(colon == ":")

            value, b = json.decode(str:sub(bytes_read + 1))
            assert(value ~= nil)
            bytes_read = bytes_read + b

            t[key] = value

            skip_whitespace()
            final = read_char()
            assert(final == "," or final == "}")
        until final == "}"
        return t, bytes_read
    elseif char == "[" then
        local t = {}
        repeat
            local value
            local final
            value, b = json.decode(str:sub(bytes_read + 1))
            bytes_read = bytes_read + b
            t[#t + 1] = value

            skip_whitespace()
            final = read_char()
            assert(final == "," or final == "]")
        until final == "]"
        return t, bytes_read
    elseif char == '"' then
        return json_parse_string(str)
    else
        local word = str:match("[%w.]+", bytes_read)
        bytes_read = bytes_read - 1 + #word
        if word == "true" then
            return true, bytes_read
        elseif word == "false" then
            return false, bytes_read
        elseif word == "null" then
            return json.null, bytes_read
        elseif tonumber(word) then
            return tonumber(word), bytes_read
        end
    end
    return nil, 0
end

local script_location = debug.getinfo(1).source:match("@?(.*/)")
local fastfetch = "fastfetch"
local cmd = fastfetch .. " --format json " .. table.concat(arg, " ")
local logo
local color = 96
local logo_key_margin = 5
local key_value_margin = 2
local json_output
if arg[1] == "-" then
    json_output = io.read("*a")
else
    local fastfetch_handle = assert(io.popen(cmd, "r"))
    json_output = fastfetch_handle:read("*a")
    fastfetch_handle:close()
end

-- debug purposes
-- lua -e 'json_impl = require("json").parse' lffetch.lua
local json_impl = json_impl or json.decode
local fetch = assert(json_impl(json_output)) --[[@as table]]

function string:style(...)
    return string.format("\027[%sm%s\027[0m", table.concat({ ... }, ";"), self)
end

local title_len = 0

local module_format = {
    title = function(_, result)
        local title = result.userName:style(1, color)
            .. "@"
            .. result.hostName:style(1, color)
        title_len = #result.hostName + #result.userName + 1
        return nil, title
    end,
    separator = function()
        return nil, ("-"):rep(title_len)
    end,
    os = function(key, result)
        logo = assert(
            io.open(script_location .. "/logos/arch.txt")
                or io.open(script_location .. "/../logos/arch.txt"),
            "logo not found"
        )
        return key, result.prettyName or result.name
    end,
    kernel = function(key, result)
        return key, result.release
    end,
    uptime = function(key, result)
        local uptime = result.uptime / 1000
        local days = math.floor(uptime / (60 * 60 * 24))
        local hours = math.floor((uptime % (60 * 60 * 24)) / (60 * 60))
        local minutes = math.floor((uptime % (60 * 60)) / 60)
        local t = {}
        table.insert(
            t,
            days > 0 and (days == 1 and "1 day" or days .. " days") or nil
        )
        table.insert(t, hours > 0 and hours .. " hours" or nil)
        table.insert(t, minutes > 0 and minutes .. " minutes" or nil)
        return key, table.concat(t, ", ")
    end,
    packages = function(key, result)
        ---@type string[]
        local t = {}
        for manager, count in pairs(result) do
            if type(count) == "number" then
                if count > 0 and manager ~= "all" then
                    if manager == "flatpakSystem" then
                        count = count + (result["flatpakUser"] or 0)
                        manager = "flatpak"
                    end
                    if manager ~= "flatpakUser" then
                        table.insert(
                            t,
                            string.format("%s (%s)", count, manager)
                        )
                    end
                end
            end
        end
        table.sort(t, function(a, b)
            a = tonumber(a:gmatch("%d*")())
            b = tonumber(b:gmatch("%d*")())
            return a > b
        end)
        return key, table.concat(t, ", ")
    end,
    shell = function(key, result)
        local name = result.prettyName or result.proccessName
        local shell_env = os.getenv("SHELL"):gsub("%w+/", ""):gsub("/", "")
        return key, name:find("lua") and shell_env or name
    end,
    display = function(_, result)
        local t = {}
        for i, monitor in ipairs(result) do
            t[i] = monitor.output.width .. "x" .. monitor.output.height
        end
        return "Resolution", table.concat(t, ", ")
    end,
    de = function(key, result)
        return key, result.prettyName or result.proccessName
    end,
    wm = function(key, result)
        return key, result.prettyName or result.proccessName
    end,
    theme = function(key, result)
        if type(result) == "string" then
            return key, result
        end

        for _, v in pairs(result) do
            if v ~= "" then
                return key, v
            end
        end
    end,
    icons = function(key, result)
        if type(result) == "string" then
            return key, result
        end

        for _, v in pairs(result) do
            if v ~= "" then
                return key, v
            end
        end
    end,
    terminal = function(key, result)
        return key, result.prettyName or result.proccessName
    end,
    cpu = function(key, result)
        return key, result.cpu .. " @ " .. result.frequency.max .. "GHz"
    end,
    gpu = function(key, result)
        local names = {}
        for i, gpu in ipairs(result) do
            names[i] = gpu.name
        end
        return key, table.concat(names, ", ")
    end,
    memory = function(key, result)
        local total = result.total / 1024 ^ 3
        local used = result.used / 1024 ^ 3
        return key, string.format("%.2fGiB / %.2fGiB", used, total)
    end,
    ["break"] = function()
        return nil, ""
    end,
    colors = function()
        local chunk = "   "
        local colors1 = ""
        local colors2 = ""
        for i = 40, 47 do
            ---@diagnostic disable-next-line: param-type-mismatch
            colors1 = colors1 .. chunk:style(i)
        end
        for i = 100, 107 do
            ---@diagnostic disable-next-line: param-type-mismatch
            colors2 = colors2 .. chunk:style(i)
        end
        return { nil, "\027[s" .. colors1 }, {
            nil,
            "\027[u" .. "\027[1B" .. colors2,
        }
    end,
}

io.output():setvbuf("no")

function io.writeln(...)
    if select("#", ...) == 0 then
        return io.write("\n")
    end
    return io.write(..., "\n")
end

local pairs = {}
local longest_key = 0

for _, module in ipairs(fetch) do
    local module_id = (module.type):lower()
    local func = module_format[module_id]
    if func then
        local pair = { func(module.type, module.result, module.error) }

        if type(pair[1]) == "string" then
            longest_key = math.max(longest_key, #pair[1])
        end

        local function insert(pair)
            if type(pair[2]) == "string" or type(pair[2]) == "number" then
                table.insert(pairs, pair)
            end
        end

        if pair[2] then
            if type(pair[1]) == "table" then
                for _, p in ipairs(pair) do
                    insert(p)
                end
            else
                insert(pair)
            end
        end
    end
end

for _, pair in ipairs(pairs) do
    local key, value = pair[1], pair[2]
    io.write(logo:read() .. (" "):rep(logo_key_margin))
    if key and value then
        io.write(
            key:style(1, color)
                .. ":"
                .. (" "):rep(longest_key - #key + key_value_margin)
        )
    end
    io.write(value)
    io.writeln()
end

local line = logo:read()
while line do
    io.writeln(line)
    line = logo:read()
end
