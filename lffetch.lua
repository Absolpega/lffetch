#!/usr/bin/env lua

package.path = (
    (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config"))
    .. "/fastfetch/?.lua;"
) .. package.path
pcall(require, "config")

local unpack = unpack or table.unpack
local function strip_ansi_codes(str)
    -- https://stackoverflow.com/a/49209650
    return string.gsub(str, "[\27\155][][()#;?%d]*[A-PRZcf-ntqry=><~]", "")
end
local function utf8chars(str)
    local chars = {}
    for char in str:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        table.insert(chars, char)
    end
    return chars
end
local margin = margin or 4
local cmd = "fastfetch --pipe false --logo-position top "
    .. table.concat(arg, " ")

local fastfetch_handle = assert(io.popen(cmd, "r"))

local lines_of_logo = 0

local lines = {}
for line in fastfetch_handle:lines() do
    local line_stripped = strip_ansi_codes(line)
    if #line_stripped == 0 and lines_of_logo == 0 then
        lines_of_logo = #lines
    else
        table.insert(lines, line)
    end
end

function io.writeln(...)
    if select("#", ...) == 0 then
        return io.write("\n")
    end
    return io.write(..., "\n")
end

local empty_lines = 0
for i = lines_of_logo + 1, #lines do
    if #strip_ansi_codes(lines[i]) == 0 then
        empty_lines = empty_lines + 1
    else
        break
    end
end

local final = {}
local logo = { unpack(lines, 1, lines_of_logo) }
local fetch = { unpack(lines, lines_of_logo + 1 + empty_lines) }

for i = 1, math.max(#logo, #fetch) do
    local last_logo_line_len = #utf8chars(strip_ansi_codes(logo[#logo]))
    final[i] = (logo[i] or (" "):rep(last_logo_line_len))
        .. (" "):rep(margin)
        .. (fetch[i] or "")
end

io.writeln(table.concat(final, "\n"))
