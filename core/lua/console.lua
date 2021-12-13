--[[

Copyright 2014-2015 The Luvit Authors. All Rights Reserved.
Copyright 2016-2020 The Node.lua Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

--]]

local meta = {
    description = "A lua value pretty printer and colorizer for terminals."
}

local exports = { meta = meta }

local uv  = require('luv')
local util = require('util')

local theme         = { }
local useColors     = false
local defaultTheme  = nil

-------------------------------------------------------------------------------
-- themes

local function initThemes()
    local themes = {}
    -- nice color theme using 16 ansi colors
    themes[16] = {
        ["function"]= "0;35",       -- purple
        ["nil"]     = "1;30",       -- bright-black
        boolean     = "0;33",       -- yellow
        braces      = "1;30",       -- bright-black
        cdata       = "0;36",       -- cyan
        err         = "1;31",       -- bright red
        escape      = "1;32",       -- bright-green
        failure     = "1;33;41",    -- bright-yellow on red
        highlight   = "1;36;44",    -- bright-cyan on blue
        number      = "1;33",       -- bright-yellow
        property    = "0;37",       -- white
        quotes      = "1;32",       -- bright-green
        sep         = "1;30",       -- bright-black
        string      = "0;32",       -- green
        success     = "1;33;42",    -- bright-yellow on green
        table       = "1;34",       -- bright blue
        thread      = "1;35",       -- bright-purple
        userdata    = "1;36",       -- bright cyan
    }

    -- nice color theme using ansi 256-mode colors
    themes[256] = {
        ["function"]= "38;5;129",   -- purple
        ["nil"]     = "38;5;244",
        boolean     = "38;5;220",   -- yellow-orange
        braces      = "38;5;247",
        cdata       = "38;5;69",    -- teal
        err         = "38;5;196",           -- bright red
        escape      = "38;5;46",    -- bright green
        failure     = "38;5;215;48;5;52",   -- bright red on dark red
        highlight   = "38;5;45;48;5;236",   -- bright teal on dark grey
        number      = "38;5;202",   -- orange
        property    = "38;5;253",
        quotes      = "38;5;40",    -- green
        sep         = "38;5;240",
        string      = "38;5;34",    -- darker green
        success     = "38;5;120;48;5;22",   -- bright green on dark green
        table       = "38;5;27",    -- blue
        thread      = "38;5;199",   -- pink
        userdata    = "38;5;39",    -- blue2
    }

    return themes
end

local themes = initThemes()

-------------------------------------------------------------------------------

local symbols = {}
local controls = {}

exports.symbols = symbols

-------------------------------------------------------------------------------

function exports.loadColors(index)

    function symbols.pos(x, y)
        return '\27[' .. y .. ';' .. x .. 'H'
    end

    function symbols.up(n)
        return '\27[' .. n .. 'A'
    end

    function symbols.down(n)
        return '\27[' .. n .. 'B'
    end

    function symbols.left(n)
        return '\27[' .. n .. 'D'
    end

    function symbols.right(n)
        return '\27[' .. n .. 'C'
    end

    symbols.clear = '\27[2J'
    symbols.reset = '\27[0m'
    symbols.underline = '\27[04m'
    symbols.inverse = '\27[07m'
    symbols.clearRight = '\27[K'
    symbols.save = '\27[s'
    symbols.recall = '\27[u'

    -------------------------------------------
    -- theme

    -- Remove the old theme
    for key in pairs(theme) do
        theme[key] = nil
    end

    useColors = false

    -- Add the new theme
    local newTheme = themes[index or defaultTheme or 0]
    if newTheme then
        for key in pairs(newTheme) do
            theme[key] = newTheme[key]
        end

        useColors = true
    end

    -------------------------------------------
    -- colors
    local colorize = exports.colorize

    if (useColors) then
        symbols.quote       = colorize('quotes',    "'", 'string')
        symbols.quote2      = colorize('quotes',    "'")
        symbols.dquote      = colorize('quotes',    '"', 'string')
        symbols.dquote2     = colorize('quotes',    '"')
        symbols.obrace      = colorize('braces',    '{ ')
        symbols.cbrace      = colorize('braces',    '}')
        symbols.obracket    = colorize('property',  '[')
        symbols.cbracket    = colorize('property',  ']')
        symbols.comma       = colorize('sep',       ', ')
        symbols.equals      = colorize('sep',       ' = ')

    else
        symbols.quote       = "'"
        symbols.quote2      = "'"
        symbols.dquote      = '"'
        symbols.dquote2     = '"'
        symbols.obrace      = "{"
        symbols.cbrace      = "}"
        symbols.obracket    = "["
        symbols.cbracket    = "]"
        symbols.comma       = ", "
        symbols.equals      = " = "
    end

    -------------------------------------------
    -- controls

    local special = {
        [7]         = 'a',
        [8]         = 'b',
        [9]         = 't',
        [10]        = 'n',
        [11]        = 'v',
        [12]        = 'f',
        [13]        = 'r'
    }

    for i = 0, 31 do
        local c = special[i]
        if c then
            controls[i] = '\\' .. c
        else
            controls[i] = '.'
        end
    end

    controls[39] = "\\'"

    for i = 128, 255 do
        controls[i] = '.'
    end
end

function exports.color(colorName)
    if (not useColors) then
        return ''
    end

    return '\27[' ..(theme[colorName] or '0') .. 'm'
end

function exports.colorize(colorName, string, resetName)
    local color = exports.color
    return color(colorName) .. tostring(string) .. color(resetName)
end

-- 打印所有可用的主题颜色
function exports.colors()
    local color = exports.color

    local index = 1
    for k, v in pairs(theme) do
        print(index .. '. ' .. color(k) .. k .. color())
        index = index + 1
    end
end

function exports.colorful(text)
    local color = exports.color
    local ret = text:gsub('${([^}]+)}', function(c) return color(c) end)
    return ret
end

-------------------------------------------------------------------------------

function exports.dump(value, recurse, nocolor)

    local function stringEscape(c)
        return controls[string.byte(c, 1)]
    end

    local seen   = { }
    local output = { }
    local indent = 0

    local _process_value
    local colorize = exports.colorize
    local color = exports.color

    local _write = function (text, length)
        if (text) then
            output[#output + 1] = text
        end
    end

    local _process_string = function (localValue, raw)
        if (raw) then
            _write(color('string'))
            _write(localValue:gsub('[%c\\]',  stringEscape))
            _write(color())

        elseif localValue:match("'") and not localValue:match('"') then
            _write(symbols.dquote)
            --_write(localValue:gsub('[%c\\\128-\255]',  stringEscape))
            _write(localValue:gsub('[%c\\]',  stringEscape))
            _write(symbols.dquote2)

        else
            _write(symbols.quote)
            --_write(localValue:gsub("[%c\\'\128-\255]", stringEscape))
            _write(localValue:gsub("[%c\\']", stringEscape))
            _write(symbols.quote2)
        end
    end

    local _process_table = function (localValue)
        indent = indent + 1

        local LIMIT = 2

        -- Count the number of keys so we know when to
        -- stop adding commas
        local total = 0

        -- keys
        local keys = {}
        for k, v in pairs(localValue) do
            total = total + 1

            if (type(k) ~= 'string') then
                table.insert(keys, k)

            elseif (not k:startsWith('_')) then
                table.insert(keys, k)
            end
        end

        table.sort( keys, function(a, b)
            return tostring(a) < tostring(b)
        end)

        -- start table
        _write(symbols.obrace) -- {
        if (total > LIMIT) then
            _write('\n')
        end

        -- table key, value
        local nextIndex = 1
        for i = 1, #keys do
            local k = keys[i]
            local v = localValue[k]

            if (total > LIMIT) then
                _write(string.rep('  ', indent))
            end

            if k == nextIndex then
                -- array item
                -- if the key matches the last numerical index + 1
                -- This is how lists print without keys
                nextIndex = k + 1
                _process_value(v)

            else
                -- object item
                if type(k) == "string" and string.find(k, "^[%a_][%a%d_]*$") then
                    _write(colorize("property", k))
                    _write(symbols.equals)

                else
                    _write(symbols.obracket)
                    _process_value(k)
                    _write(symbols.cbracket)
                    _write(symbols.equals)
                end

                _process_value(v)
            end

            if i < total then
                _write(symbols.comma) -- ,

                if (total > LIMIT) then
                    _write('\n')
                end
            end
        end

        -- end table
        indent = indent - 1
        if (total > LIMIT) then
            _write('\n')
            _write(string.rep('  ', indent))
        else
            _write(' ')
        end

        _write(symbols.cbrace) -- }
    end

    _process_value = function (localValue)
        local valueType = type(localValue)
        if (valueType == 'string') then
            _process_string(localValue)

        elseif (valueType == 'table') and not seen[localValue] then
            if not recurse then seen[localValue] = true end
            _process_table(localValue)

        else
            _write(colorize(valueType, tostring(localValue)))
        end
    end

    local _process_top_value = function (localValue)
        local valueType = type(localValue)
        if (valueType == 'string') then
            _process_string(localValue, true)

        elseif (valueType == 'table') and not seen[localValue] then
            if not recurse then seen[localValue] = true end
            _process_table(localValue)

        else
            _write(colorize(valueType, tostring(localValue)))
        end
    end

    _process_top_value(value)

    local text = table.concat(output, "")
    return nocolor and exports.strip(text) or text
end

function exports.printr(...)
    local arguments = { ... }

    local total = 0
    for index, value in pairs(arguments) do
        if (total < index) then total = index end
        arguments[index] = exports.dump(value)
    end

    for i = 1, total do
        if (arguments[i] == nil) then
            arguments[i] = exports.dump(nil)
        end
    end

    local stdout = process._stdout
    uv.write(stdout, table.concat(arguments, "\t"))
    uv.write(stdout, "\n")
end

exports.dir = exports.printr

function exports.printBuffer(text, limit)
    limit = limit or 255
    local list = {}
    for i = 1, #text do
        local ch = text:byte(i)
        table.insert(list, string.format("%02X", ch, ch))

        if (i % 4 == 0) then
            table.insert(list, ' ')
        end

        if (i % 16 == 0) then
            table.insert(list, ' ')
        end

        if (i % 32 == 0) then
            table.insert(list, '\r\n')
        end

        if (i > limit) then
            table.insert(list, '... ')
            break
        end
    end

    print(table.concat(list))
end

function exports.strip(str)
    if (not str) then
        return nil
    end

    return str:gsub('\027%[[^m]*m', '')
end

function exports.time(label)
    if (not exports.times) then
        exports.times = {}
    end

    exports.times[label] = process.hrtime() // 1000000
end

function exports.timeEnd(label)
    local last = nil
    if (exports.times) then
        last = exports.times[label]
    end

    if (not last) then
        return
    end

    local now = process.hrtime() // 1000000
    local colorize = exports.colorize
    print('timeEnd:', colorize("quotes", label), now - last)
end

function exports.trace(message, ...)
    local traceInfo = debug.traceback()
    if (message) then print(message) end
    print(traceInfo)
end

function exports.traceHandler(message)
    print(message)
    exports.trace()
end

function exports.write(...)
    local stdout = process._stdout
    local n = select('#', ...)
    local arguments = { ... }
    for i = 1, n do
        local value = arguments[i]
        if (value ~= nil) then
            uv.write(stdout, tostring(value))
        end
    end
end

-------------------------------------------------------------------------------

function exports.getFileLine()
    local file, line = util.filename(4)
    local path = require('path')
    local dirname = path.dirname(file)
    file = path.basename(file) or ''
    if (dirname and #dirname > 0) then
        file = path.basename(dirname) .. '/' .. file
    end
    return file .. ':' .. (line or 0)
end

function exports.log(message, ...)
    local colorize = exports.colorize
    print(colorize("sep", '- ' .. exports.getFileLine()))
    exports.printr(message, ...)
end

function exports.error(message, ...)
    local colorize = exports.colorize
    print(colorize("err", '! ' .. exports.getFileLine()))
    exports.printr(message, ...)
end

function exports.info(message, ...)
    local colorize = exports.colorize
    print(colorize("quotes", '= ' .. exports.getFileLine()))
    exports.printr(message, ...)
end

function exports.warn(message, ...)
    local colorize = exports.colorize
    print(colorize("number", '# ' .. exports.getFileLine()))
    exports.printr(message, ...)
end

function exports.assert(value, message, ...)
    if (value) then
        return
    end

    local colorize = exports.colorize
    print(colorize("sep", '- ' .. exports.getFileLine()))
    exports.printr(message, ...)
end

function exports.clear()
    console.print(symbols.clear)
end

function exports.winsize()
    return uv.tty_get_winsize(process._stdin)
end

-------------------------------------------------------------------------------
-- print

if (not exports.print) then

    -- Print replacement that goes through libuv.  This is useful on windows
    -- to use libuv's code to translate ansi escape codes to windows API calls.

    exports.print = _G.print
    _G.print = function(...)
        local n = select('#', ...)
        local arguments = { ... }
        for i = 1, n do
            arguments[i] = tostring(arguments[i])
        end

        local stdout = process._stdout
        uv.write(stdout, table.concat(arguments, "\t"))
        uv.write(stdout, "\n")
    end

    if (process.isTTY) then
         -- auto-detect when 16 color mode should be used
        local term = os.getenv("TERM")
        if term == 'xterm' or term == 'xterm-256color' then
            defaultTheme = 256

        else
            defaultTheme = 16
        end
    end
end

exports.loadColors()

-------------------------------------------------------------------------------
--

exports.theme = theme
exports.defaultTheme = defaultTheme

return exports
