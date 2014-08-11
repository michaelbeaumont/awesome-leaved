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
local keygrabber = require("awful.keygrabber")
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

local leaved = { name = 'leaved' }

-- Globals
local debug = false
local trees = {}
local forceNextOrient = nil

--little utility functions
local function partial(f, ...)
    local oarg = {...}
    return function(...)
        f(unpack(oarg), unpack({...}))
    end
end

local function dbg_print(f)
    if debug then
        print(f())
    end
end

--draw and arrange functions
local function redraw(self, p, geometry)
    if not self.tip then
        if self:isOrdered() and not self.data.tabbox then
            self.data.tabbox = Tabbox:new(p.index, geometry)
        end
        local num = #self.children
        local tabbox_height = 0
        if self.data.tabbox then
            self.data.tabbox:resize(p, geometry, self)
            tabbox_height = self.data.tabbox.container.height
        end
        local width = geometry.width
        local height = geometry.height - tabbox_height
        local diff_x, diff_y = 0, 0
        local current_x = geometry.x
        local current_y = geometry.y + tabbox_height

        
        for i, c in ipairs(self.children) do
            local sub_geo = { width=width, height=height, x=current_x,
            y=current_y }
            if not self:isOrdered() then
                local pc = c.data.geometry.pc/100
                if self:isHorizontal() then
                    diff_x = math.floor(pc*width)
                    sub_geo.width = diff_x
                else
                    diff_y = math.floor(pc*height)
                    sub_geo.height = diff_y
                end
                current_x = current_x + diff_x
                current_y = current_y + diff_y
            elseif self.data.lastFocus ~= c then
                sub_geo.width = 0
                sub_geo.height = 0
            end
            redraw(c, p, sub_geo) 
        end
    else
        if geometry.width ~= 0 and geometry.height ~= 0 then
            geometry.width = geometry.width - self.data.c.border_width
            geometry.height = geometry.height - self.data.c.border_width
            self.data.c:geometry(geometry)
            self.data.c:raise()
        end
    end
end

function leaved.arrange(p)
    if arrange_lock then
        return
    end
    arrange_lock = true

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
        local nextOrient = forceNextOrient

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
                        lastFocusNode:pairWith(newClient)
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
        forceNextOrient = nil
    end

    if n >= 1 then
        redraw(top, p, area)
    end

    if debug then
        top:show()
    end

    arrange_lock = false
end

--Additional functions for keybindings
function leaved.splitH() forceNextOrient = Guitree.horiz end
function leaved.splitV() forceNextOrient = Guitree.vert end

local function change_focused(changer)
    --get all the boring local variables
    local lastFocus = awful.client.focus.history.get(1, 0)
    local screen_index = capi.mouse.screen
    local tag = awful.tag.selected(screen_index)
    local top = trees[tag].top
    --find the focused client
    local node = top:findWith('window', lastFocus.window)

    --apply function
    changer(node)
    --force rearrange
    awful.layout.arrange(screen_index)
end

local function reorient(orientation) change_focused(
    function(node)
         node.parent:setOrientation(orientation)
     end)
end

function leaved.horizontalize() reorient(Guitree.horiz) end
function leaved.verticalize() reorient(Guitree.vert) end

function leaved.reorder() 
    change_focused(
        function(node)
            local parent = node.parent
            if parent:isTabbed() then
                parent:setStacked()
            elseif parent:isStacked() then
                parent:unOrder()
            else
                parent:setTabbed()
            end
        end)
end

local function scaleNode(pc, node, orientation)
    if not node.parent then
        return
    elseif not orientation or node.parent.data.orientation == orientation then
        if (node.data.geometry.pc >= 100 and pc > 0) or
            (node.data.geometry.pc <= 0 and pc < 0) then
            return
        end
        local siblings = node.parent.children
        local fact = pc/(100 - node.data.geometry.pc)
        for _, c in ipairs(siblings) do
            if c ~= node then
                local geo = c.data.geometry.pc
                if geo == 0 then
                    c.data.geometry.pc = -pc
                else
                    c.data.geometry.pc = geo - geo*fact
                end
            end
        end
        node.data.geometry.pc = node.data.geometry.pc + pc
    else
        scaleNode(pc, node.parent, orientation)
    end

end


function leaved.scale(pc, orientation)
    local f = function(node)
        if orientation == 'opposite' then
            if node.parent:isHorizontal() then
                scaleNode(pc, node, Guitree.vert)
            else
                scaleNode(pc, node, Guitree.horiz)
            end
        else
            scaleNode(pc, node, orientation)
        end
    end
    return partial(change_focused, f)
end

function leaved.scaleFocused(pc)
    return leaved.scale(pc, nil)
end
function leaved.scaleOpposite(pc)
    return leaved.scale(pc, 'opposite')
end

function leaved.scaleH(pc)
    return leaved.scale(pc, Guitree.horiz)
end
function leaved.scaleV(pc)
    return leaved.scale(pc, Guitree.vert)
end

function leaved.swap()
    local cls_map = {}
    local screen = capi.mouse.screen
    local tag = awful.tag.selected(screen)
    local lastFocus = awful.client.focus.history.get(1, 0)
    local p = function() return true end
    local f = function(node, level)
        if node.tip then
            local c_geo = node.data.c:geometry()

            local label = wibox.widget.textbox()
            label:set_ellipsize('none')
            label:set_align('center')
            label:set_valign('center')

            local font_size = c_geo.height
            local wi, he = c_geo.width, c_geo.height
            while wi >= c_geo.width or he >= c_geo.height do
                
                font_size = font_size/2
                local font = "sans " .. font_size
                local text = {"<span font_desc='"..font.."'>"}
                table.insert(text, #cls_map+1)
                table.insert(text, "</span>")

                --TODO wibox only on one tag
                label:set_markup(table.concat(text))

                wi, he = label:fit(c_geo.width, c_geo.height)
            end
            local geo = { 
                height=he,
                width=wi,
                x = c_geo.x + c_geo.width/2 - wi/2,
                y = c_geo.y + c_geo.height/2 - he/2
            }

            local box = wibox({screen = screen,
                               ontop=true,
                               visible=true,
                               opacity=0.3})

            box:set_widget(label)
            box:geometry(geo)

            table.insert(cls_map, {node=node, label=box})
            if node.data.c == lastFocus then
                cls_map.current = #cls_map
            end
        end
    end
    if trees[tag] then
        trees[tag].top:traverse(f, p, 0)
    end

    local res = #cls_map/10
    local digits = 1
    while res >= 1 do
        res = res/10
        digits = digits + 1
    end

    local keys = {}
    local collect
    collect = keygrabber.run(function(mod, key, event)
        if event == "release" then return end

        print(key)
        if tonumber(key) then
            if debug then print("Got key: " .. tonumber(key)) end
            table.insert(keys, tonumber(key)) 
            if #keys < digits then
                if debug then print("Waiting for more keys") end
                return 
            end
        elseif key ~= "Return" and key ~= "KP_Enter" then
            keys = {}
        end
        keygrabber.stop(collect)
        local choice = tonumber(table.concat(keys))
        if choice then
            if debug then print("Chosen: " .. choice) end
            cls_map[cls_map.current].node:swap(cls_map[choice].node)
            --force rearrange
            awful.layout.arrange(screen)
        end
        for i, c in ipairs(cls_map) do
            c.label.visible = false
        end
    end)
end

--Function called when a client is unmanaged
local function clean_tree(c)
    arrange_lock = true
    local function scale(node)
        local pc = node.data.geometry.pc
        scaleNode(-pc, node)
    end
    for i, _ in pairs(trees) do
        if trees[i] then
            trees[i].top:filterClientAttr("window", c.window, scale)
        end
    end
    arrange_lock = false
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

return leaved
