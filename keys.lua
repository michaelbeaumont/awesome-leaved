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
local layout = require "awesome-leaved.layout"
local utils = require "awesome-leaved.utils"
local dbg_print = utils.dbg_print
local partial = utils.partial

local keys = { }

--Additional functions for keybindings
function keys.splitH() layout.forceNextOrient = Guitree.horiz end
function keys.splitV() layout.forceNextOrient = Guitree.vert end

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
        node.parent:setIgnore(true, true)
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

local function select_client(callback)
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
    if layout.trees[tag] then
        layout.trees[tag].top:traverse(f, p, 0)
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

        --TODO hide all clients that can't be selected after this key
        --ie 1 is pressed show only 1, 10, 11, etc
        dbg_print("Got key: " .. key)
        if tonumber(key) then
            table.insert(keys, tonumber(key)) 
            if #keys < digits then
                dbg_print("Waiting for more keys")
                return 
            end
        elseif key ~= "Return" and key ~= "KP_Enter" then
            keys = {}
        end
        keygrabber.stop(collect)
        local choice = tonumber(table.concat(keys))
        if choice then
            dbg_print("Chosen: " .. choice)
            callback(cls_map[cls_map.current].node, cls_map[choice].node)
            --force rearrange
            awful.layout.arrange(screen)
        end
        for i, c in ipairs(cls_map) do
            c.label.visible = false
        end
    end)
end

function keys.swap()
    local function c(current, choice)
        current:swap(choice)
    end
    select_client(c)
end

function keys.focus()
    local function c(current, choice)
        capi.client.focus = choice.data.c
    end
    select_client(c)
end

return keys
