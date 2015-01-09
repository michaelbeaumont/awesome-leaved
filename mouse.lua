local print, tostring = print, tostring
local ipairs, pairs = ipairs, pairs
local setmetatable = setmetatable
local table = table
local math = math
local awful = require "awful"
local capi =
    {
        client = client,
        screen = screen,
        mouse = mouse,
        mousegrabber = mousegrabber,
    }

local layout = require "awesome-leaved.layout"
local utils = require "awesome-leaved.utils"

local logger = utils.logger('off')

local mouse = { }


--- Edited from awful/mouse
--- Move a client.
-- @param c The client to move, or the focused one if nil.
-- @param snap The pixel to snap clients.
local function move(c, snap)
    local c = c or capi.client.focus
    local node = layout.node_from_client(c)

    if not c
        or c.fullscreen
        or c.type == "desktop"
        or c.type == "splash"
    or c.type == "dock" then
        return
    end

    local orig = c:geometry()
    local m_c = capi.mouse.coords()
    local dist_x = m_c.x - orig.x
    local dist_y = m_c.y - orig.y
    -- Only allow moving in the non-maximized directions
    local fixed_x = c.maximized_horizontal
    local fixed_y = c.maximized_vertical

    local function grabber(_mouse)
        for k, v in ipairs(_mouse.buttons) do
            if v then
                local lay = awful.layout.get(c.screen)
                if lay == awful.layout.suit.floating or awful.client.floating.get(c) then
                    local x = _mouse.x - dist_x
                    local y = _mouse.y - dist_y
                    c:geometry(mouse.client.snap(c, snap, x, y, fixed_x, fixed_y))
                elseif lay ~= awful.layout.suit.magnifier then
                    -- Only move the client to the mouse
                    -- screen if the target screen is not
                    -- floating.
                    -- Otherwise, we move if via geometry.
                    if awful.layout.get(capi.mouse.screen) == awful.layout.suit.floating then
                        local x = _mouse.x - dist_x
                        local y = _mouse.y - dist_y
                        c:geometry(mouse.client.snap(c, snap, x, y, fixed_x, fixed_y))
                    else
                        c.screen = capi.mouse.screen
                    end
                    if awful.layout.get(c.screen) ~= awful.layout.suit.floating then
                        local c_u_m = awful.mouse.client_under_pointer()
                        if c_u_m and not awful.client.floating.get(c_u_m) then
                            if c_u_m ~= c then
                                --here do something 
                                --local n_u_m = find node for c_u_m
                                node:swap(layout.node_from_client(c_u_m))
                                awful.layout.arrange(c.screen)
                            end
                        end
                    end
                end
                return true
            end
        end
        return false
    end
    capi.mousegrabber.run(grabber, "fleur")
end

--- The exposed functions
mouse.move = utils.guard(move, awful.mouse.client.move)

return mouse
