local print, tostring = print, tostring
local ipairs, pairs = ipairs, pairs
local setmetatable = setmetatable
local table = table
local math = math
local awesome = awesome
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
local layout = require "awesome-leaved.layout"
local utils = require "awesome-leaved.utils"
local partial = utils.partial

local logger = utils.logger('info')

local keys = { }

--Additional functions for keybindings
function keys.splitH() layout.forceNextOrient = Guitree.horiz end
function keys.splitV() layout.forceNextOrient = Guitree.vert end
function keys.splitOpp() layout.forceNextOrient = Guitree.opp end

local function change_focused(changer)
    --get all the boring local variables
    local lastFocus = awful.client.focus.history.get(1, 0)
    local screen_index = capi.mouse.screen
    local tag = awful.tag.selected(screen_index)
    local top = layout.trees[tag].top
    --find the focused client
    local node = top:findWith('window', lastFocus.window)

    --apply function
    changer(node)
    --force rearrange
    awful.layout.arrange(screen_index)
end

function keys.minContainer()
    change_focused(function(node) 
        layout.arrange_lock = true
        node.parent:minimize(true)
        layout.arrange_lock = false
    end)
end

local function reorient(orientation) change_focused(
    function(node)
         node.parent:setOrientation(orientation)
     end)
end

function keys.horizontalize() reorient(Guitree.horiz) end
function keys.verticalize() reorient(Guitree.vert) end

function keys.reorder() 
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


function keys.scale(pc, orientation)
    local f = function(node)
        if orientation == 'opposite' then
            if node.parent:isHorizontal() then
                node:scaleNode(pc, Guitree.vert)
            else
                node:scaleNode(pc, Guitree.horiz)
            end
        else
            node:scaleNode(pc, orientation)
        end
    end
    return partial(change_focused, f)
end

function keys.scaleFocused(pc)
    return keys.scale(pc, nil)
end
function keys.scaleOpposite(pc)
    return keys.scale(pc, 'opposite')
end

function keys.scaleH(pc)
    return keys.scale(pc, Guitree.horiz)
end
function keys.scaleV(pc)
    return keys.scale(pc, Guitree.vert)
end

local function make_keygrabber(screen, cls_map, callback)
    local digits = cls_map.digits

    local keys = {}

    local function hide_others(choice)
        for k, c in pairs(cls_map) do
            if tonumber(k)
                and not (tostring(k):find(choice) or choice:find(k)) then
                c.label.visible = false
            end
        end
    end

    local collect
    collect = keygrabber.run(function(mod, key, event)
        if event == "release" then return end

        logger.print("fine", "Got key: " .. key)
        local choice
        if tonumber(key) then
            table.insert(keys, tonumber(key)) 
            if #keys < digits then
                logger.print("fine", "Waiting for more keys")
                choice = table.concat(keys)
                hide_others(choice)
                return 
            end
        elseif key ~= "Return" and key ~= "KP_Enter" then
            keys = {}
        end
        keygrabber.stop(collect)
        choice = table.concat(keys)
        if choice then
            logger.print("fine", "Chosen: " .. choice)
            if cls_map[choice] then
                callback(cls_map[cls_map.current].node, cls_map[choice].node)
                --force rearrange
                awful.layout.arrange(screen)
            end
        end
        for k, c in pairs(cls_map) do
            if tonumber(k) then
                c.label.visible = false
            end
        end
    end)
end

local function select_node(callback, label_containers, only_containers)
    local cls_map = {curr={}, digits=0}
    cls_map.curr[0] = 0
    local screen = capi.mouse.screen
    local tag = awful.tag.selected(screen)
    local lastFocus = awful.client.focus.history.get(1, 0)
    local function wrap_text(text, size)
        local font = "sans " .. size
        local wrapped = {"<span color='#ffffff' font_desc='"..font.."'>"}
        table.insert(wrapped, text)
        table.insert(wrapped, "</span>")
        return table.concat(wrapped)
    end
    local function p() return true end
    local function make_box(c_geo, node, name)

        local label = wibox.widget.textbox()
        label:set_ellipsize('none')

        local font_size
        local wi, he = c_geo.width, c_geo.height
        if not node.tip then
            label:set_align('left')
            label:set_valign('top')
            wi = c_geo.width*0.9
            he = c_geo.height*0.9
            local text = wrap_text(name, 16)
            label:set_markup(text)
        else
            label:set_align('center')
            label:set_valign('center')
            font_size = c_geo.height/1.5
            while wi >= c_geo.width or he >= c_geo.height do

                font_size = font_size/2
                local text = wrap_text(name, font_size)

                --TODO wibox only on one tag
                label:set_markup(text)

                wi, he = label:fit(c_geo.width, c_geo.height)
            end
        end
        local geo = { 
            x = c_geo.x + c_geo.width/2 - wi/2,
            y = c_geo.y + c_geo.height/2 - he/2
        }
        if not node.tip and not awesome.composite_manager_running then
            wi, he = label:fit(c_geo.width, c_geo.height)
        end
        geo.width = wi
        geo.height = he
        local box = wibox({screen = screen,
                           ontop=true,
                           visible=true})

        box:set_widget(label)
        box:geometry(geo)
        local color = '#000000'
        local alpha
        if awesome.composite_manager_running then
            alpha = '44'
        else
            alpha = 'ff'
        end
        box:set_bg(color .. alpha)


        cls_map[name] = {node=node, label=box}
        if node.data.c == lastFocus then
            cls_map.current = name
        end

        return box
    end
    local function f(node, level)
        local name = cls_map.curr[level] or cls_map.curr[level-1]*10
        name = name+1
        cls_map.curr[level] = name
        cls_map.digits = math.max(cls_map.digits, level+1)
        if (node.tip and not only_containers)
            or (not node.tip 
                and label_containers) then
            if node:isOrdered() then
                --handle ordered containers
                make_box(node.data.geometry.last, node, tostring(name))
            else
                make_box(node.data.geometry.last, node, tostring(name))
            end
        end
    end
    if layout.trees[tag] then
        layout.trees[tag].top:traverse(f)
    end

    make_keygrabber(screen, cls_map, callback)
end

local function select_all(callback) select_node(callback, true, false) end
local function select_client(callback) select_node(callback, false, false) end
local function select_container(callback) select_node(callback, false, true) end

function keys.swap()
    local function c(current, choice)
        current:swap(choice)
    end
    select_client(c)
end

function keys.focus(all)
    local function c(current, choice)
        capi.client.focus = choice:getLastFocusedClient()
    end
    if all then
        return utils.partial(select_all, c)
    elseif all == nil then
        select_client(c)
    else
        return utils.partial(select_client, c)
    end
end

function keys.select_active_container()
    --select container
    --select orientation (show with overlays)
    --then next window created is added accordingly
    local function c(current, choice)
        layout.active_container = choice 
    end
    select_container(c)
end
return keys
