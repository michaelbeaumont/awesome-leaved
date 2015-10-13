local awful = require "awful"
local naughty = require "naughty"
local capi = { mouse = mouse }
local utils = {}

function utils.map(table, f)
    for k, v in ipairs(table) do
        table[k] = f(v)
    end
end

function utils.popup(text)
    naughty.notify({ preset = naughty.config.presets.critical,
                     title = "Logger",
                     text = text})
end

local levels = {all=0, info=30, fine=50, fatal=99, off=100}

local mk_output = function(level, outputer)
    local logger = {level=level, mt={}}
    logger.mt.__index = function(table, key)
        if type(key) == 'number' then return key >= levels[table.level] end
        if not levels[key] or not levels[table.level] then
            return false
        end
        return levels[key] >= levels[table.level]
    end
    logger.write = outputer

    return setmetatable(logger, logger.mt)
end

local mk_logger = function(outputs)
    local logger = outputs

    logger.write = function(level, str)
        for k, v in pairs(outputs) do
            if k ~= 'print' and k ~= 'format' and k ~= 'write' and v[level] then
                v.write(str)
            end
        end
    end
    logger.print = function(level, ...)
        local str = ""
        for k, v in ipairs({...}) do
            str = str .. tostring(v)
        end
        logger.write(level, str)
    end
    logger.format = function(level, ...)
        local str = string.format(...)
        logger.write(level, str)
    end

    return logger
end

local popup_output = function(level)
    return mk_output(level, utils.popup)
end

local cmd_output = function(level)
    return mk_output(level, print)
end

function utils.popuplogger(level)
    return mk_logger({popup_output(level)})
end

function utils.cmdlogger(level)
    return mk_logger({cmd_output(level)})
end

function utils.logger(level, vlevel)
    local outs = {cmd=cmd_output(level), popup=popup_output(vlevel)}
    return mk_logger(outs)
end

--little utility functions
function utils.partial(f, ...)
    local oarg = {...}
    return function(...)
        f(unpack(oarg), unpack({...}))
    end
end

function utils.guard(f, g)
    return function(...)
        local tag = awful.tag.selected(capi.mouse.screen)
        if require "awesome-leaved.layout".is_active() then
            f(unpack({...}))
        else
            g(unpack({...}))
        end
    end
end
return utils
