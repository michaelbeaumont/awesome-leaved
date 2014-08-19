local capi = { screen = screen,
               client = client }
local util = require "awful.util"
local beautiful = require "beautiful"
local client = require "awful.client"

local Rosetree = require "awesome-leaved.rosetree"

local Guitree = Rosetree:new()
Guitree.super = Rosetree

Guitree.vert = 'V'
Guitree.horiz = 'H'
Guitree.stack = 'stack'
Guitree.tabs = 'tabs'

local function default_container()
    return {
        order=nil,
        orientation=Guitree.horiz,
        lastFocus=nil,
        tabbox=nil,
        label="",
        max = {h = false, v = false},
        geometry = { pc = 100 },
        callbacks={}
    }
end

function Guitree:newClient(c)
    local data = {
        c=c,
        lastFocus=c,
        label=c.name,
        geometry = { pc = 100 },
        callbacks={}
    }
    return self:newTip(data)
end

function Guitree:newTip(data)

    local newNode = self.super.newTip(self, data)
    local c = data.c

    local u = function ()
        newNode:refreshLabel()
    end
    local callbacks = {}
    callbacks['property::urgent']=u
    callbacks['property::sticky']=u
    callbacks['property::ontop']=u
    callbacks['property::floating']=function()
        newNode:breakOff(client.floating.get(c), function()
            if newNode.parent.data.lastFocus == newNode then
                --for now choose random client
                local i = 1
                while newNode.parent.children[i] == newNode do
                    i = i + 1
                end
                newNode.parent.data.lastFocus = newNode.parent.children[i]
            end
        end)
        u()
    end
    callbacks['property::maximized_horizontal']=function()
        newNode:breakOff(newNode.data.c.maximized_horizontal)
        newNode.parent:max('h', newNode.data.c.maximized_horizontal)
        u()
    end
    callbacks['property::maximized_vertical']=function()
        newNode:breakOff(newNode.data.c.maximized_vertical)
        newNode.parent:max('v', newNode.data.c.maximized_vertical)
        u()
    end
    callbacks['property::minimized']=function()
        newNode:breakOff(newNode.data.c.minimized)
        u()
    end
    callbacks['property::name']=u
    callbacks['property::icon_name']=u
    callbacks['property::icon']=u
    callbacks['property::skip_taskbar']=u
    callbacks['property::screen']=u
    callbacks['property::hidden']=u
    callbacks['focus']=function() newNode:focus() u() end
    callbacks['unfocus']=u
        
    for k, v in pairs(callbacks) do
        c:connect_signal(k, v)
    end

    newNode.data.lastFocus = newNode
    newNode.data.callbacks = callbacks

    return newNode
end

function Guitree:newContainer(strong)
    return self.super.newInner(self, default_container(), {}, strong or false)
end

function Guitree:destroy()
    if self.tip then
        for k, v in pairs(self.data.callbacks) do
            self.data.c:disconnect_signal(k, v)
        end
    else
        if self.data.tabbox then
            self.data.tabbox.destroy()
            self.data.tabbox = nil
        end
    end
end

--Getters and setters
function Guitree:setOrder(order)
    self.data.order = order
end
function Guitree:unOrder()
    self.data.order = nil
    self.data.tabbox.destroy()
    self.data.tabbox = nil
end
function Guitree:setStacked()
    self.data.order = Guitree.stack
end
function Guitree:setTabbed()
    self.data.order = Guitree.tabs
end
function Guitree:getOrder()
    return self.data.order
end
function Guitree:isStacked()
    return self.data.order == Guitree.stack
end
function Guitree:isTabbed()
    return self.data.order == Guitree.tabs
end
function Guitree:isOrdered()
    return self.data.order ~= nil
end
function Guitree:setOrientation(orient)
    self.data.orientation = orient
end
function Guitree:getOrientation()
    return self.data.orientation
end
function Guitree:isHorizontal()
    return self.data.orientation == Guitree.horiz 
end
function Guitree:isVertical()
    return self.data.orientation == Guitree.vert
end

--make the tree "ignore" this node so to speak
function Guitree:breakOff(condition, action)
    local geo = self.data.geometry
    if condition and geo.pc ~= 0 then
        if action then action() end
        geo._pc = geo.pc
        geo.pc = 0
    else
        geo.pc = geo._pc
    end
end

function Guitree:focus(node)
    --do nothing when focusing "ignored" clients
    if self.data.geometry.pc == 0 then
        return
    end
    if self.data.tabbox then
        self.data.tabbox.container.visible = true
    end
    if self.parent then
        self.parent:focus(self)
    end
    self.data.lastFocus = node or self
end

function Guitree:max(o, val)
    self.data.max[o] = val
    self:breakOff(val)
end

--Insert and node manipulation
function Guitree:add(child, ind)
    local old_num = #self.children
    self.super.add(self, child, ind)
    local fact = old_num/#self.children
    for _, c in ipairs(self.children) do
        c.data.geometry.pc = c.data.geometry.pc * fact
    end
    child.data.geometry.pc = 100/#self.children
    child:refreshLabel()
    if old_num == 0 then
        self.data.lastFocus = child
    end
end

--we have to always take on the old geometry
function Guitree:pushdownTip()
    local pc = self.data.geometry.pc
    local new = self.super.pushdownTip(self, false, default_container())
    new.data.geometry.pc = pc
    return new
end

function Guitree:pullupTip()
    local pc = self.data.geometry.pc
    local new = self.super.pullupTip(self)
    new.data.geometry.pc = pc
    new:refreshLabel()
    return new
end

function Guitree:swap(node)
    local old_geo = self.data.geometry
    self.super.swap(self, node)
    self.data.geometry = node.data.geometry
    node.data.geometry = old_geo
end

--Generating labels for nodes
--Taken from awful.widget.tasklist
local function tasklist_label(c, args)
    if not args then args = {} end
    local theme = beautiful.get()
    local fg_normal = args.fg_normal or theme.tasklist_fg_normal or theme.fg_normal or "#ffffff"
    local bg_normal = args.bg_normal or theme.tasklist_bg_normal or theme.bg_normal or "#000000"
    local fg_focus = args.fg_focus or theme.tasklist_fg_focus or theme.fg_focus
    local bg_focus = args.bg_focus or theme.tasklist_bg_focus or theme.bg_focus
    local fg_urgent = args.fg_urgent or theme.tasklist_fg_urgent or theme.fg_urgent
    local bg_urgent = args.bg_urgent or theme.tasklist_bg_urgent or theme.bg_urgent
    local fg_minimize = args.fg_minimize or theme.tasklist_fg_minimize or theme.fg_minimize
    local bg_minimize = args.bg_minimize or theme.tasklist_bg_minimize or theme.bg_minimize
    local bg_image_normal = args.bg_image_normal or theme.bg_image_normal
    local bg_image_focus = args.bg_image_focus or theme.bg_image_focus
    local bg_image_urgent = args.bg_image_urgent or theme.bg_image_urgent
    local bg_image_minimize = args.bg_image_minimize or theme.bg_image_minimize
    local tasklist_disable_icon = args.tasklist_disable_icon or theme.tasklist_disable_icon or false
    local font = args.font or theme.tasklist_font or theme.font or ""
    local bg = nil
    local text = "<span font_desc='"..font.."'>"
    local name = ""
    local bg_image = nil

    -- symbol to use to indicate certain client properties
    local sticky = args.sticky or theme.tasklist_sticky or "▪"
    local ontop = args.ontop or theme.tasklist_ontop or '⌃'
    local floating = args.floating or theme.tasklist_floating or '✈'
    local maximized_horizontal = args.maximized_horizontal or theme.tasklist_maximized_horizontal or '⬌'
    local maximized_vertical = args.maximized_vertical or theme.tasklist_maximized_vertical or '⬍'

    if not theme.tasklist_plain_task_name then
        if c.sticky then name = name .. sticky end
        if c.ontop then name = name .. ontop end
        if client.floating.get(c) then name = name .. floating end
        if c.maximized_horizontal then name = name .. maximized_horizontal end
        if c.maximized_vertical then name = name .. maximized_vertical end
    end

    if c.minimized then
        name = name .. (util.escape(c.icon_name) or util.escape(c.name) or util.escape("<untitled>"))
    else
        name = name .. (util.escape(c.name) or util.escape("<untitled>"))
    end
    if capi.client.focus == c then
        bg = bg_focus
        bg_image = bg_image_focus
        if fg_focus then
            text = text .. "<span color='"..util.color_strip_alpha(fg_focus).."'>"..name.."</span>"
        else
            text = text .. "<span color='"..util.color_strip_alpha(fg_normal).."'>"..name.."</span>"
        end
    elseif c.urgent and fg_urgent then
        bg = bg_urgent
        text = text .. "<span color='"..util.color_strip_alpha(fg_urgent).."'>"..name.."</span>"
        bg_image = bg_image_urgent
    elseif c.minimized and fg_minimize and bg_minimize then
        bg = bg_minimize
        text = text .. "<span color='"..util.color_strip_alpha(fg_minimize).."'>"..name.."</span>"
        bg_image = bg_image_minimize
    else
        bg = bg_normal
        text = text .. "<span color='"..util.color_strip_alpha(fg_normal).."'>"..name.."</span>"
        bg_image = bg_image_normal
    end
    text = text .. "</span>"
    return text, bg, bg_image, not tasklist_disable_icon and c.icon or nil
end

function Guitree:refreshLabel()
    if self.tip then
        local text, bg, bg_image, icon = tasklist_label(self.data.c)
        self.data.label = text
        self.data.bg = bg
        self.data.bg_image = bg_image
        self.data.icon = icon
        
        self.parent:refreshLabel()
    else
        local labels = {}

        labels[1] = self:getOrientation() .. " ["
        
        for i, c in ipairs(self.children) do
            labels[i+1] = c.data.label
        end
        table.insert(labels, "]")

        self.data.label = table.concat(labels, " ")

        if self.data.tabbox then
            self.data.tabbox:rename(self)
        end

        if self.parent then
            self.parent:refreshLabel()
        end
    end
end


--Search and filter guitrees
function hasClientAttribute(attr, value) 
    return function(node)
        return node.tip and node.data.c and node.data.c[attr] == value 
    end
end

function Guitree:filterClientAttr(attr, value, action)
    local f
    if action then
        f = function(node)
            if hasClientAttribute(attr, value)(node) then
                action(node)
                return true
            else
                return false
            end
        end
    else
        f = hasClientAttribute(attr, value)
    end
    return self:filter(f)
end

function Guitree:findWith(attr, value)
    return self:find(hasClientAttribute(attr, value))
end

function Guitree:show(level)
    local function window_shower(node, level)
        local output, name
        if node.tip then
            name = "Client["
            output = tostring(node.data.c.window .. "|" .. "Size: " .. node.data.geometry.pc .. "|" .. tostring(node))
        else
            name = "Container["
            output = tostring(tostring(node.data.order) .. ":" .. node.data.orientation .. ' ' .. #node.children .. "|" .. "Size: " .. node.data.geometry.pc .. "|" .. tostring(node.data.lastFocus) .. "|" .. "hmax: " .. tostring(node.data.max.h))
        end
        print(string.rep(" ", level) .. name .. output .. "]")
    end
    self:traverse(window_shower, function() return true end, level)
end
return Guitree
