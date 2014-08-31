-- Awesome-Leaved: Layout for AwesomeWM based on i3's behavior
-- 2014, Michael Beaumont, mjboamail@gmail.com
---------------------------------------------------

local print, tostring = print, tostring
local ipairs, pairs = ipairs, pairs
local setmetatable = setmetatable
local table = table
local math = math
local awful = require "awful"
local wibox = require "wibox"

local capi =
{
    client = client,
    screen = screen,
    mouse = mouse,
    button = button
}

local Rosetree = require "awesome-leaved.rosetree"
local Guitree = require "awesome-leaved.guitree"
local Tabbox = require "awesome-leaved.tabbox"
local utils = require "awesome-leaved.utils"

local layout = { name = 'leaved',
    trees = {},
    forceNextOrient = nil,
    arrange_lock = false}

-- Globals
local debug = true
-- alias layout.trees
local trees = layout.trees


--draw and arrange functions
local function redraw(self, screen, geometry, hides)
    if not self.tip then
        local maximized = self.data.max.h and self.data.max.v
        local geo = maximized and screen.workarea or geometry

        if not self.data.geometry.in_tree then
            geo.width = 0
            geo.height = 0
        end

        --Handle the tabbox
        local tabbox_height = 0
        if self:isOrdered() then
            if not self.data.tabbox then
                self.data.tabbox = Tabbox:new(screen.index)
            end
            self.data.tabbox:redraw(screen, geo, self)
            tabbox_height = self.data.tabbox.container.height
        end
        geo.height = geo.height - tabbox_height
        geo.y = geo.y + tabbox_height


        --if we are tabbed or stacked then render only the focused node
        if self:isOrdered() then
            for _, s in ipairs(self.children) do
                if s.data.geometry.in_tree then
                    local sub_geo = { x=geometry.x, y=geometry.y }
                    if self.data.lastFocus ~= s then
                        sub_geo.width = 0
                        sub_geo.height = 0
                        redraw(s, screen, sub_geo, hides)
                    else
                        sub_geo.width = geo.width
                        sub_geo.height = geo.height
                        local real_geo = redraw(s, screen, sub_geo, hides)
                        geo.height = real_geo.height
                        geo.width = real_geo.width
                    end
                    
                end
            end
            geo.height = geo.height + tabbox_height
        else
            --figure out if we're distributing over width or height            
            local dimension, invariant, offset
            if self:isHorizontal() then
                dimension = "width"
                invariant = "y"
                offset = "x"
            else
                dimension = "height"
                invariant = "x"
                offset = "y"
            end


            local current_offset = geo[offset]
            
            --new vars
            local used = 0
            local unused = geo[dimension]
            local remaining_fact = 0

            --figure out how many windows will be rendered
            for _, s in ipairs(self.children) do
                remaining_fact = remaining_fact + 
                (s.data.geometry.in_tree and s.data.geometry.fact or 0)
            end
            --read just according to the minimum size hints
            for _, s in ipairs(self.children) do
                --retrieve size hints
                local sh = s.data.geometry.hints or s:getSizeHints()
                s.data.geometry.hints = nil

                --calculate possible readjustment
                --calculate new_f:
                --new_f / ((rest_f - curr_f) + new_f) = hint / total
                local rest_fact = remaining_fact - s.data.geometry.fact
                local pc = sh[dimension] / geo[dimension]
                local pot_fact = pc*rest_fact/(1-pc)
                if pot_fact > s.data.geometry.fact then
                    remaining_fact = remaining_fact
                                     - s.data.geometry.fact
                                     + pot_fact
                    s.data.geometry.fact = pot_fact
                end
            end
            --traverse the subtree and render child nodes
            for _, s in ipairs(self.children) do
                local sub_geo = { width=geo.width, height=geo.height,
                                    x=geo.x, y=geo.y }
                if s.data.geometry.in_tree then
                    local sub_fact = s.data.geometry.in_tree and s.data.geometry.fact or 0
                    sub_geo[invariant] = geo[invariant]
                    sub_geo[offset] = current_offset
                    sub_geo[dimension] = math.floor(sub_fact/remaining_fact*unused)

                    local real_geo = redraw(s, screen, sub_geo, hides)

                    used = used + real_geo[dimension]
                    current_offset = current_offset + real_geo[dimension]
                    unused = unused - real_geo[dimension]
                    remaining_fact = remaining_fact - sub_fact
                else
                    redraw(s, screen, sub_geo, hides)
                end
            end
            geo[dimension] = used
        end
        return geo
    else
        local c = self.data.c
        if awful.client.floating.get(c) then
            geometry.width = 0
            geometry.height = 0
            return geometry
        end
        if geometry.width > 0 and geometry.height > 0 then
            local border = 2*c.border_width
            geometry.width = geometry.width - border
            geometry.height = geometry.height - border

            --take size hints into account
            --if self.parent:isHorizontal() then
            --    dimension = "width"
            --else
            --    dimension = "height"
            --end
            --local size_hints = c.size_hints
            --local size_hint = size_hints["min_"..dimension] or size_hints["base_"..dimension] or 0
            --geometry[dimension] = math.max(size_hint, geometry[dimension])

            --apply geometry
            geometry = self.data.c:geometry(geometry)

            --use last used geometry for stashing hidden clients
            hides.space = geometry

            --add back borders for reporting used size
            geometry.width = geometry.width + border
            geometry.height = geometry.height + border

        elseif self.data.geometry.in_tree then
            --self.data.geometry.minimized = true
            --c.minimized = true
            --self.data.geometry.minimized = false
            --horrible hack due to wiboxes otherwise being under all windows
            table.insert(hides, c)
        end

        return geometry
    end
end


function layout.arrange(p)
    if layout.arrange_lock then
        print("Encountered arrange lock")
        return
    end
    layout.arrange_lock = true

    local area = p.workarea
    local n = #p.clients

    local tag = awful.tag.selected(capi.mouse.screen)
    if not trees[tag] then
        trees[tag] = {
            clients = nil,
            total_num = 0,
            top = Guitree:newContainer(true)
        }
    end

    local top = trees[tag].top

    local old_num = trees[tag].total_num
    local changed = n - old_num
    if math.abs(changed) > 1 then
        initLayout = true
    end
    trees[tag].total_num = n

    if changed > 0 then
        local lastFocusNode, lastFocusParent, lastFocusGeo
        local lastFocus = awful.client.focus.history.get(1, 0)
        if lastFocus and not awful.client.floating.get(lastFocus) then
            lastFocusNode = top:findWith("window", lastFocus.window)
            if lastFocusNode then
                lastFocusParent = lastFocusNode.parent
                lastFocusGeo = lastFocusNode.data.c:geometry()
            end
        end

        local initLayout = false

        local prevClient = nil
        local splitHoriz = false
        local nextOrient = layout.forceNextOrient

        for i, c in ipairs(p.clients) do
            --maybe unnecessarily slow? could maintain a list of tracked clients
            local possibleChild = top:findWith("window", c.window)
            if not possibleChild then
                local newClient = Guitree:newClient(c)

                if lastFocusNode then
                    if not nextOrient then
                        if (lastFocusGeo.width <= lastFocusGeo.height) then
                            nextOrient = Guitree.vert
                        else
                            nextOrient = Guitree.horiz
                        end
                    end
                    
                    if lastFocusParent:getOrientation() ~= nextOrient then
                        lastFocusNode:add(newClient)
                        lastFocusNode:setOrientation(nextOrient)
                    else
                        lastFocusParent:add(newClient)
                    end
                else
                    top:add(newClient)
                end
                prevClient = newClient
            else
                prevClient = possibleChild
            end
            --ready for next iteration
            lastFocusNode = prevClient
            lastFocusParent = lastFocusNode.parent
            lastFocusGeo = lastFocusNode.data.c:geometry()
            if nextOrient == Guitree.horiz then
                nextOrient = Guitree.vert
            else
                nextOrient = Guitree.horiz
            end
        end
        layout.forceNextOrient = nil
    end

    hides = {}
    if n >= 1 then
        redraw(top, p, area, hides)
    end
    for _, c in ipairs(hides) do
        c:geometry({width=1, height=1, x=hides.space.x, y = hides.space.y})
        c:lower()
    end

    if debug then top:show() end

    layout.arrange_lock = false
end


--Function called when a client is unmanaged
local function clean_tree(c)
    layout.arrange_lock = true
    local function scale(node)
        local fact = node.data.geometry.fact
    end
    for i, _ in pairs(trees) do
        if trees[i] then
            trees[i].top:filterClientAttr("window", c.window, scale)
        end
    end
    layout.arrange_lock = false
end

--Initialize the layout
local function handle_signals(t)
    if awful.tag.getproperty(t, "layout").name == "leaved" then
        capi.client.connect_signal("unmanage", clean_tree)
    elseif trees[t] then
        capi.client.disconnect_signal("unmanage", clean_tree)
        trees[t] = nil
    end
end

awful.tag.attached_connect_signal(s, "property::layout", handle_signals)

return layout
