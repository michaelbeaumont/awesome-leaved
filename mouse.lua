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
                if awful.client.floating.get(c) then
                    local x = _mouse.x - dist_x
                    local y = _mouse.y - dist_y
                    c:geometry(awful.mouse.client.snap(c, snap, x, y, fixed_x, fixed_y))
                else
                    -- Only move the client to the mouse
                    -- screen if the target screen is not
                    -- floating.
                    -- Otherwise, we move if via geometry.
                    if awful.layout.get(capi.mouse.screen) == awful.layout.suit.floating then
                        local x = _mouse.x - dist_x
                        local y = _mouse.y - dist_y
                        c:geometry(awful.mouse.client.snap(c, snap, x, y, fixed_x, fixed_y))
                    else
                        c.screen = capi.mouse.screen
                    end
                    local c_u_m = awful.mouse.client_under_pointer()
                    if c_u_m and not awful.client.floating.get(c_u_m) then
                        if c_u_m ~= c then
                            node:swap(layout.node_from_client(c_u_m))
                            awful.layout.arrange(c.screen)
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

--- Unmodified from awful.mouse
local function client_resize_magnifier(c, corner)
    local corner, x, y = awful.mouse.client.corner(c, corner)
    capi.mouse.coords({ x = x, y = y })

    local wa = capi.screen[c.screen].workarea
    local center_x = wa.x + wa.width / 2
    local center_y = wa.y + wa.height / 2
    local maxdist_pow = (wa.width^2 + wa.height^2) / 4

    capi.mousegrabber.run(function (_mouse)
                              for k, v in ipairs(_mouse.buttons) do
                                  if v then
                                      local dx = center_x - _mouse.x
                                      local dy = center_y - _mouse.y
                                      local dist = dx^2 + dy^2

                                      -- New master width factor
                                      local mwfact = dist / maxdist_pow
                                      awful.tag.setmwfact(math.min(math.max(0.01, mwfact), 0.99), awful.tag.selected(c.screen))
                                      return true
                                  end
                              end
                              return false
                          end, corner .. "_corner")
end
local function client_resize_tiled(c, lay)
    local wa = capi.screen[c.screen].workarea
    local mwfact = awful.tag.getmwfact()
    local cursor
    local g = c:geometry()
    local offset = 0
    local x,y
    if lay == awful.layout.suit.tile then
        cursor = "cross"
        if g.height+15 > wa.height then
            offset = g.height * .5
            cursor = "sb_h_double_arrow"
        elseif not (g.y+g.height+15 > wa.y+wa.height) then
            offset = g.height
        end
        capi.mouse.coords({ x = wa.x + wa.width * mwfact, y = g.y + offset })
    elseif lay == awful.layout.suit.tile.left then
        cursor = "cross"
        if g.height+15 >= wa.height then
            offset = g.height * .5
            cursor = "sb_h_double_arrow"
        elseif not (g.y+g.height+15 > wa.y+wa.height) then
            offset = g.height
        end
        capi.mouse.coords({ x = wa.x + wa.width * (1 - mwfact), y = g.y + offset })
    elseif lay == awful.layout.suit.tile.bottom then
        cursor = "cross"
        if g.width+15 >= wa.width then
            offset = g.width * .5
            cursor = "sb_v_double_arrow"
        elseif not (g.x+g.width+15 > wa.x+wa.width) then
            offset = g.width
        end
        capi.mouse.coords({ y = wa.y + wa.height * mwfact, x = g.x + offset})
    else
        cursor = "cross"
        if g.width+15 >= wa.width then
            offset = g.width * .5
            cursor = "sb_v_double_arrow"
        elseif not (g.x+g.width+15 > wa.x+wa.width) then
            offset = g.width
        end
        capi.mouse.coords({ y = wa.y + wa.height * (1 - mwfact), x= g.x + offset })
    end

    capi.mousegrabber.run(function (_mouse)
                              for k, v in ipairs(_mouse.buttons) do
                                  if v then
                                      local fact_x = (_mouse.x - wa.x) / wa.width
                                      local fact_y = (_mouse.y - wa.y) / wa.height
                                      local mwfact

                                      local g = c:geometry()


                                      -- we have to make sure we're not on the last visible client where we have to use different settings.
                                      local wfact
                                      local wfact_x, wfact_y
                                      if (g.y+g.height+15) > (wa.y+wa.height) then
                                          wfact_y = (g.y + g.height - _mouse.y) / wa.height
                                      else
                                          wfact_y = (_mouse.y - g.y) / wa.height
                                      end

                                      if (g.x+g.width+15) > (wa.x+wa.width) then
                                          wfact_x = (g.x + g.width - _mouse.x) / wa.width
                                      else
                                          wfact_x = (_mouse.x - g.x) / wa.width
                                      end


                                      if lay == awful.layout.suit.tile then
                                          mwfact = fact_x
                                          wfact = wfact_y
                                      elseif lay == awful.layout.suit.tile.left then
                                          mwfact = 1 - fact_x
                                          wfact = wfact_y
                                      elseif lay == awful.layout.suit.tile.bottom then
                                          mwfact = fact_y
                                          wfact = wfact_x
                                      else
                                          mwfact = 1 - fact_y
                                          wfact = wfact_x
                                      end

                                      awful.tag.setmwfact(math.min(math.max(mwfact, 0.01), 0.99), awful.tag.selected(c.screen))
                                      awful.client.setwfact(math.min(math.max(wfact,0.01), 0.99), c)
                                      return true
                                  end
                              end
                              return false
                          end, cursor)
end
local function client_resize_floating(c, corner, fixed_x, fixed_y)
    local corner, x, y = awful.mouse.client.corner(c, corner)
    local g = c:geometry()

    -- Warp mouse pointer
    capi.mouse.coords({ x = x, y = y })

    capi.mousegrabber.run(function (_mouse)
                              for k, v in ipairs(_mouse.buttons) do
                                  if v then
                                      local ng
                                      if corner == "bottom_right" then
                                          ng = { width = _mouse.x - g.x,
                                                 height = _mouse.y - g.y }
                                      elseif corner == "bottom_left" then
                                          ng = { x = _mouse.x,
                                                 width = (g.x + g.width) - _mouse.x,
                                                 height = _mouse.y - g.y }
                                      elseif corner == "top_left" then
                                          ng = { x = _mouse.x,
                                                 width = (g.x + g.width) - _mouse.x,
                                                 y = _mouse.y,
                                                 height = (g.y + g.height) - _mouse.y }
                                      else
                                          ng = { width = _mouse.x - g.x,
                                                 y = _mouse.y,
                                                 height = (g.y + g.height) - _mouse.y }
                                      end
                                      if ng.width <= 0 then ng.width = nil end
                                      if ng.height <= 0 then ng.height = nil end
                                      if fixed_x then ng.width = g.width ng.x = g.x end
                                      if fixed_y then ng.height = g.height ng.y = g.y end
                                      c:geometry(ng)
                                      -- Get real geometry that has been applied
                                      -- in case we honor size hints
                                      -- XXX: This should be rewritten when size
                                      -- hints are available from Lua.
                                      local rg = c:geometry()

                                      if corner == "bottom_right" then
                                          ng = {}
                                      elseif corner == "bottom_left" then
                                          ng = { x = (g.x + g.width) - rg.width  }
                                      elseif corner == "top_left" then
                                          ng = { x = (g.x + g.width) - rg.width,
                                                 y = (g.y + g.height) - rg.height }
                                      else
                                          ng = { y = (g.y + g.height) - rg.height }
                                      end
                                      c:geometry({ x = ng.x, y = ng.y })
                                      return true
                                  end
                              end
                              return false
                          end, corner .. "_corner")
end

--special function for leaved
local function client_resize_leaved(c, lay)
    local wa = capi.screen[c.screen].workarea
    local mwfact = awful.tag.getmwfact()
    local cursor = "cross"
    local g = c:geometry()
    local offset = 0
    local x,y
    if lay == layout.suit.tile.right then
        if g.height+15 > wa.height then
            offset = g.height * .5
            cursor = "sb_h_double_arrow"
        elseif not (g.y+g.height+15 > wa.y+wa.height) then
            offset = g.height
        end
        capi.mouse.coords({ x = wa.x + wa.width * mwfact, y = g.y + offset })
    elseif lay == layout.suit.tile.left then
        if g.height+15 >= wa.height then
            offset = g.height * .5
            cursor = "sb_h_double_arrow"
        elseif not (g.y+g.height+15 > wa.y+wa.height) then
            offset = g.height
        end
        capi.mouse.coords({ x = wa.x + wa.width * (1 - mwfact), y = g.y + offset })
    elseif lay == layout.suit.tile.bottom then
        if g.width+15 >= wa.width then
            offset = g.width * .5
            cursor = "sb_v_double_arrow"
        elseif not (g.x+g.width+15 > wa.x+wa.width) then
            offset = g.width
        end
        capi.mouse.coords({ y = wa.y + wa.height * mwfact, x = g.x + offset})
    else
        if g.width+15 >= wa.width then
            offset = g.width * .5
            cursor = "sb_v_double_arrow"
        elseif not (g.x+g.width+15 > wa.x+wa.width) then
            offset = g.width
        end
        capi.mouse.coords({ y = wa.y + wa.height * (1 - mwfact), x= g.x + offset })
    end

    capi.mousegrabber.run(function (_mouse)
                              for k, v in ipairs(_mouse.buttons) do
                                  if v then
                                      local fact_x = (_mouse.x - wa.x) / wa.width
                                      local fact_y = (_mouse.y - wa.y) / wa.height
                                      local mwfact

                                      local g = c:geometry()


                                      -- we have to make sure we're not on the last visible client where we have to use different settings.
                                      local wfact
                                      local wfact_x, wfact_y
                                      if (g.y+g.height+15) > (wa.y+wa.height) then
                                          wfact_y = (g.y + g.height - _mouse.y) / wa.height
                                      else
                                          wfact_y = (_mouse.y - g.y) / wa.height
                                      end

                                      if (g.x+g.width+15) > (wa.x+wa.width) then
                                          wfact_x = (g.x + g.width - _mouse.x) / wa.width
                                      else
                                          wfact_x = (_mouse.x - g.x) / wa.width
                                      end


                                      if lay == layout.suit.tile.right then--lay == layout.suit.tile then
                                          mwfact = fact_x
                                          wfact = wfact_y
                                      elseif lay == layout.suit.tile.left then
                                          mwfact = 1 - fact_x
                                          wfact = wfact_y
                                      elseif lay == layout.suit.tile.bottom then
                                          mwfact = fact_y
                                          wfact = wfact_x
                                      else
                                          mwfact = 1 - fact_y
                                          wfact = wfact_x
                                      end

                                      awful.tag.setmwfact(math.min(math.max(mwfact, 0.01), 0.99), awful.tag.selected(c.screen))
                                      local node = layout.node_from_client(c)
                                      node.data.geometry.fact = math.min(math.max(wfact,0.01), 0.99)
                                      --aclient.setwfact(math.min(math.max(wfact,0.01), 0.99), c)
                                      --get client node, set fact
                                      return true
                                  end
                              end
                              return false
                          end, cursor)
end

--- Resize a client.
-- @param c The client to resize, or the focused one by default.
-- @param corner The corner to grab on resize. Auto detected by default.
function mouse.resize(c, corner)
    local c = c or capi.client.focus

    if not c then return end

    if c.fullscreen
        or c.type == "desktop"
        or c.type == "splash"
        or c.type == "dock" then
        return
    end

    -- Do not allow maximized clients to be resized by mouse
    local fixed_x = c.maximized_horizontal
    local fixed_y = c.maximized_vertical

    local lay = awful.layout.get(c.screen)

    if lay == awful.layout.suit.floating or awful.client.floating.get(c) then
        return client_resize_floating(c, corner, fixed_x, fixed_y)
    elseif lay == awful.layout.suit.tile
        or lay == awful.layout.suit.tile.left
        or lay == awful.layout.suit.tile.top
        or lay == awful.layout.suit.tile.bottom
    then
        return client_resize_tiled(c, lay)
    elseif layout.is_active() then
        return client_resize_leaved(c, lay)
    elseif lay == awful.layout.suit.magnifier then
        return client_resize_magnifier(c, corner)
    end
end

return mouse
