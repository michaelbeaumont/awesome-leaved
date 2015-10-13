local capi = { screen = screen,
               client = client }
local awful = {
    layout = require "awful.layout",
    --tag = require "awful.tag"
}
local util = require "awful.util"
local beautiful = require "beautiful"
local client = require "awful.client"

local Rosetree = require "awesome-leaved.rosetree"

local Guitree = Rosetree:new()
Guitree.super = Rosetree

Guitree.vert = 1
Guitree.horiz = 2
Guitree.orders = {[1]='v',[2]='h'}
function Guitree.flip_order(order)
    return (order % #Guitree.orders) + 1
end
Guitree.opp = 'opp'
Guitree.no_style = 1
Guitree.stack = 2
Guitree.tabs = 3
Guitree.styles = {[1]='none',[2]='stacked',[3]='tabbed'}

local function default_container()
    return {
        style=Guitree.no_style,
        order=Guitree.horiz,
        lastFocus=nil,
        tabbox=nil,
        label="",
        focused = false,
        geometry = { fact = 1,
                     floating = false,
                     minimized = false,
                     max = {h = false, v = false},
                     invisibles = 0 },
        callbacks={}
    }
end

function Guitree:newClient(c)
    local data = {
        c=c,
        lastFocus=c,
        label=c.name,
        geometry = { fact = 1,
                     floating = false,
                     minimized = false},
        callbacks={}
    }
    return self:newTip(data)
end

function Guitree:newTip(data)

    local newNode = self.super.newTip(self, data)
    local c = data.c

    local callbacks = {node = newNode}
    local u = function ()
        callbacks.node:refreshLabel()
    end
    callbacks['property::urgent']=function()
        callbacks.node:urgent(newNode.data.c.urgent)  
        u()
    end
    callbacks['property::sticky']=u
    callbacks['property::ontop']=u
    callbacks['property::floating']=function()
        callbacks.node:float(client.floating.get(newNode.data.c))
        u()
    end
    callbacks['property::maximized_horizontal']=u
    callbacks['property::maximized_vertical']=u
    callbacks['property::minimized']=function()
        callbacks.node:minimize(newNode.data.c.minimized)
        u()
    end
    callbacks['property::name']=u
    callbacks['property::icon_name']=u
    callbacks['property::icon']=u
    callbacks['property::skip_taskbar']=u
    callbacks['property::screen']=u
    callbacks['property::hidden']=u
    --TODO add arrange on size_hints changed
    callbacks['focus']=function() 
        local mind = newNode.data.c.minimized
        if callbacks.node.data.geometry.minimized == mind then
            callbacks.node:focus()
        end
        u()
    end
    callbacks['unfocus']=function()
        callbacks.node:unfocus()
        u()
    end
    callbacks['tagged']=u
    callbacks['untagged']=u
    callbacks['list']=u
    --awful.tag.attached_connect_signal(c.screen, "property::selected", u)
    --awful.tag.attached_connect_signal(c.screen, "property::activated", u)
    --TODO: Add tags added removed hook, to hide in that tree
        
    for k, v in pairs(callbacks) do
        if k ~= "node" then
            c:connect_signal(k, v)
        end
    end

    newNode.data.lastFocus = newNode
    newNode.data.callbacks = callbacks

    return newNode
end

function Guitree:newContainer(strong)
    return self.super.newInner(self, default_container(), {}, strong or false)
end

Guitree.newInner = Guitree.newContainer

function Guitree:overwrite(dest)
    self.super.overwrite(self, dest)
    if self.tip then
        dest.data.callbacks.node = dest
    end
end

--handle breaking nodes in and out of the tree
--all of these functions assume a consistent state of the tree
--ie for all nodes if the client is minimized, also geo.min is set
--and that the client is minimized before geo.min is set
local function reset_last_focused(node)
    local i = 0
    while not node.data.lastFocus:inTree()
        and i ~= #node.children do
        i = i + 1
        node.data.lastFocus = node.children[i]
    end
end

local function change_invisibles(node, num_changed)
    local geo = node.data.geometry
    geo.invisibles = geo.invisibles + num_changed
    reset_last_focused(node)
    if geo.invisibles == #node.children and num_changed > 0 then
        if node.parent then change_invisibles(node.parent, 1) end
    elseif geo.invisibles == #node.children-1 and num_changed < 0 then
        if node.parent then change_invisibles(node.parent, -1) end
    end
end

function Guitree:destroy()
    if self.tip then
        for k, v in pairs(self.data.callbacks) do
            if k ~= 'node' then
                self.data.c:disconnect_signal(k, v)
            end
        end
        self.data.callbacks = {}
    else
        if self.data.tabbox then
            self.data.tabbox.destroy()
            self.data.tabbox = nil
        end
        for _, c in ipairs(self.children) do
            c:destroy()
        end
    end
end

--Getters and setters
function Guitree:setStyle(style)
    self.data.style = style
end
function Guitree:shiftStyle()
    self.data.style = (self.data.style % #Guitree.styles) + 1
end
function Guitree:unStyle()
    self.data.style = Guitree.no_style
    self.data.tabbox.destroy()
    self.data.tabbox = nil
end
function Guitree:setStacked()
    self.data.style = Guitree.stack
end
function Guitree:setTabbed()
    self.data.style = Guitree.tabs
end
function Guitree:getStyle()
    return self.data.style
end
function Guitree:isStacked()
    return self.data.style == Guitree.stack
end
function Guitree:isTabbed()
    return self.data.style == Guitree.tabs
end
function Guitree:isStyled()
    return self.data.style ~= Guitree.no_style
end
function Guitree:setOrder(order)
    self.data.order = order
end
function Guitree:shiftOrder()
    self.data.order = (self.data.order % #Guitree.orders) + 1
end
function Guitree:getOrder()
    return self.data.order
end
function Guitree:isHorizontal()
    return self.data.order == Guitree.horiz
end
function Guitree:isVertical()
    return self.data.order == Guitree.vert
end
function Guitree:inTree()
    return not self.data.geometry.minimized
        and not self.data.geometry.floating
        and (self.tip or self.data.geometry.invisibles < #self.children)
    end

function Guitree:getLastFocusedClient()
    local node = self.data.lastFocus
    while not node.data.c do
       node = node.data.lastFocus 
    end
    return node.data.c
end

--
function Guitree:getSizeHints()
    local sh = {width=0, height=0}
    if self.tip then
        local size_hints = self.data.c.size_hints
        sh.width = size_hints["min_width"] or size_hints["base_width"] or 0
        sh.height = size_hints["min_height"] or size_hints["base_height"] or 0
    else
        for _, n in ipairs(self.children) do
            local sub_sh = n:getSizeHints()
            local dim
            if self:isHorizontal() then
                dim = "width"
                other = "height"
            else
                dim = "height"
                other = "width"
            end
            sh[dim] = sh[dim] + sub_sh[dim]
            sh[other] = math.max(sub_sh[other], sh[other])
        end
    end
    self.data.geometry.hints = sh
    return sh
end

function Guitree:scaleNode(pc)
    if not self.parent then
        return
    else
        local old_fact = self.data.geometry.fact
        local total_fact = 0
        for _, c in ipairs(self.parent.children) do
            total_fact = total_fact + c.data.geometry.fact
        end
        local old_pc = old_fact/total_fact
        if (old_pc >= 1 and pc > 0) or
            (old_pc <= 0 and pc < 0) then
            return
        end
        self.data.geometry.fact = old_fact * (1+pc/100)
    end
end


local function descendMinimize(urnode, min)
    urnode:traverse(function(node)
        node.data.geometry.minimized = min
    end)
    urnode:traverse(function(node)
        if node.tip then 
            node.data.c.minimized = min
        end
    end)
end

--make the tree "ignore" this node so to speak
function Guitree:float(val)
    local geo = self.data.geometry
    local changed = geo.floating ~= val
    geo.floating = val
    if self.parent and changed then
        change_invisibles(self.parent, geo.floating and -1 or 1)
    end
end

function Guitree:minimize(val)
    local geo = self.data.geometry
    local changed = geo.minimized ~= val
    if changed then
        if self.parent then
            if self.parent.data.geometry.minimized and not val then
                self.parent:minimize(val)
            else
                change_invisibles(self.parent, geo.minimized and -1 or 1)
            end
        end
        descendMinimize(self, val)
    end
        --if geo.in_tree and self.parent then
        --self.parent.data.lastFocus = self
        --end
end

function Guitree:focus(node)
    --do nothing when focusing "ignored" and not minimized clients
    --i.e. floating clients
    if not self:inTree()
        and not self.data.geometry.minimized then
        return
    end
    --we must focus all of our parents
    self.data.focused = true
    if self.data.tabbox then
        self.data.tabbox.container.visible = true
    end
    if self.parent then
        self.parent:focus(self)
    end
    self.data.lastFocus = node or self
end
function Guitree:unfocus()
    self.data.focused = false
    if self.parent then self.parent:unfocus() end
end

function Guitree:urgent(val)
    local curr = self
    while curr do
        curr.data.urgent = val
        curr = curr.parent
    end
end

function Guitree:kill()
    self:destroy()
    local kills = {}
    self:traverse(function(node)
        if node.tip then table.insert(kills, node.data.c) end
    end)
    for _, c in ipairs(kills) do
        c:kill()
    end
end



--Insert and node manipulation
function Guitree:add(child, ind)
    local fact
    if self.tip then
        fact = self.data.geometry.fact
    end

    local first_child = not self.tip and #self.children == 0

    self.super.add(self, child, ind)

    if fact then
        self.data.geometry.fact = fact
    end

    child:refreshLabel()

    if child.parent == self then
        self.data.lastFocus = child
        if not child:inTree() then
            change_invisibles(self,1)
        elseif first_child then
            --stupid hack
            self.data.geometry.invisibles = 1
            change_invisibles(self,-1)
        end
    end
end

--we have to always take on the old geometry
function Guitree:swap(node)
    local old_fact = self.data.geometry.fact
    self.super.swap(self, node)
    --TODO keep fact in parents, seems cleaner
    self.data.geometry.fact = node.data.geometry.fact
    node.data.geometry.fact = old_fact
end

--Generating labels for nodes
--Taken from awful.widget.tasklist
local function tasklist_label(node, args)
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
    local sticky_c = args.sticky or theme.tasklist_sticky or "▪"
    local ontop_c = args.ontop or theme.tasklist_ontop or '⌃'
    local floating_c = args.floating or theme.tasklist_floating or '✈'
    local maximized_horizontal_c = args.maximized_horizontal or theme.tasklist_maximized_horizontal or '⬌'
    local maximized_vertical_c = args.maximized_vertical or theme.tasklist_maximized_vertical or '⬍'

    local sticky = (node.tip and node.data.c.sticky)
    local ontop = (node.tip and node.data.c.ontop)
    local floating = (node.tip and client.floating.get(node.data.c))
    local max_h = (node.tip and node.data.c.maximized_horizontal)
    local max_v = (node.tip and node.data.c.maximized_vertical)
    local min = (node.tip and node.data.c.minimized)
             or node.data.geometry.minimized
    local focused = (node.tip and capi.client.focus == node.data.c)
             or node.data.focused
    local urgent = (node.tip and node.data.c.urgent)
             or node.data.urgent

    if not theme.tasklist_plain_task_name then
        if sticky then name = name .. sticky_c end
        if ontop then name = name .. ontop_c end
        if floating then name = name .. floating_c end
        if max_h then name = name .. maximized_horizontal_c end
        if max_v then name = name .. maximized_vertical_c end
    end

    --build title for node
    if not node.tip then
        local labels = {}

        labels[1] = Guitree.orders[node:getOrder()] .. " ["
        
        for i, c in ipairs(node.children) do
            labels[i+1] = c.data.label
        end
        table.insert(labels, "]")

        name = name .. table.concat(labels, " ")
    else
        local c = node.data.c
        if min then
            name = name .. (util.escape(c.icon_name) or util.escape(c.name) or util.escape("<untitled>"))
        else
            name = name .. (util.escape(c.name) or util.escape("<untitled>"))
        end
    end
    --determine colors
    if focused then
        bg = bg_focus
        bg_image = bg_image_focus
        if fg_focus then
            text = text .. "<span color='"..fg_focus.."'>"..name.."</span>"
        else
            text = text .. "<span color='"..fg_normal.."'>"..name.."</span>"
        end
    elseif urgent and fg_urgent then
        bg = bg_urgent
        text = text .. "<span color='"..fg_urgent.."'>"..name.."</span>"
        bg_image = bg_image_urgent
    elseif min and fg_minimize and bg_minimize then
        bg = bg_minimize
        text = text .. "<span color='"..fg_minimize.."'>"..name.."</span>"
        bg_image = bg_image_minimize
    else
        bg = bg_normal
        text = text .. "<span color='"..fg_normal.."'>"..name.."</span>"
        bg_image = bg_image_normal
    end
    text = text .. "</span>"
    return text, bg, bg_image, node.tip and not tasklist_disable_icon
end

function Guitree:refreshLabel()
    local text, bg, bg_image, use_icon = tasklist_label(self)
    self.data.label = text
    self.data.bg = bg
    self.data.bg_image = bg_image
    self.data.use_icon = use_icon

    if self.data.tabbox then
        self.data.tabbox:rename(self)
    end

    if self.parent then
        self.parent:refreshLabel()
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
        local index = ""
        if node.parent then index = node.index end
        if node.tip then
            name = "Client["..index.. " "
            output = tostring(node.data.c.window
            .. "| Fct:" .. node.data.geometry.fact
            .. "|" .. tostring(node)
            .. "| IT: " .. tostring(node:inTree()))
        else
            name = "Container["..index.. " "
            output = tostring(tostring(node)
                .. ":" .. node.data.order
                .. ' ' .. #node.children
                .. "| Fct: " .. node.data.geometry.fact
                .. "| LF: " .. tostring(node.data.lastFocus)
                .. "| Invis: " .. node.data.geometry.invisibles
                .. "| IT: " .. tostring(node:inTree()))
        end
        print(string.rep(" ", level) .. name .. output .. "]")
    end
    self:traverse(window_shower, function() return true end, level)
end

return Guitree
