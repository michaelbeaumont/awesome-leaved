local awful = require "awful"
local capi = { mouse = mouse }
local utils = {}

function utils.logger(level)
    local levels = {off=0, info=30, fine=50}
    local l = {level=level}
    l.mt = {}
    l.mt.__index = function(table, key)
        if not levels[key] or not levels[table.level] then
            error("Logging level not found")
        end
        return levels[key] <= levels[table.level]
    end
    l.print = function(level, ...)
        if l[level] then
            print(...)
        end
    end
    return setmetatable(l, l.mt)
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
