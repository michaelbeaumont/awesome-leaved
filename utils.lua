local utils = {}

--little utility functions
function utils.partial(f, ...)
    local oarg = {...}
    return function(...)
        f(unpack(oarg), unpack({...}))
    end
end

function utils.dbg(f)
    if debug then
        print(f())
    end
end
function utils.dbg_print(...)
    if debug then
        print(...)
    end
end

return utils
