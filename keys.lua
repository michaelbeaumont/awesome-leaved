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

local logger = utils.logger('fatal')

local keys = { }

function keys.wrap(mod, _key, normal_press, leaved_press)
    local function wrapped(...)
        normal_press = normal_press or function() end
        local screen_index = capi.mouse.screen
        local tag = awful.tag.selected(screen_index)
        if layout.is_active() then
            leaved_press(...)
        else
            normal_press(...)
        end

    end
    return awful.key(mod, _key, wrapped)
end

--Additional functions for keybindings
function keys.splitH() layout.forceNextOrder = Guitree.horiz end
function keys.splitV() layout.forceNextOrder = Guitree.vert end
function keys.splitOpp() layout.forceNextOrder = Guitree.opp end

local function change_focused(changer)
    --get all the boring local variables
    --TODO use p.screen instead of 1
    local lastFocus = awful.client.focus.history.get(1, 0)
    local screen_index = capi.mouse.screen
    local tag = awful.tag.selected(screen_index)
    local tree = layout.get_active_tree()
    if tree then
        --find the focused client
        local node = tree.top:findWith('window', lastFocus.window)

        --apply function
        changer(node)
        --force rearrange
        awful.layout.arrange(screen_index)
    end
end

function keys.min_container()
    change_focused(function(node) 
        node.parent:minimize(true)
    end)
end

local function reorder(order) change_focused(
    function(node)
         node.parent:setOrder(order)
     end)
end

function keys.horizontalize() reorder(Guitree.horiz) end
function keys.verticalize() reorder(Guitree.vert) end

function keys.shiftOrder()
    change_focused(
        function(node)
            node.parent:shiftOrder()
        end)
end

function keys.shiftStyle()
    change_focused(
        function(node)
            node.parent:shiftStyle()
        end)
    awesome.emit_signal("refresh")
end


function keys.scale(pc, orientation)
    local f
    if orientation then
        if orientation == Guitree.opp then
            f = function(node) node.parent:scaleNode(pc) end
        else
            f = function(node)
                if node.parent.data.order == orientation then
                    node:scaleNode(pc) 
                else
                    node.parent:scaleNode(pc)
                end
            end
        end
    else
        f = function(node) node:scaleNode(pc) end
    end
    return utils.partial(change_focused, f)
end

function keys.scaleFocused(pc)
    return keys.scale(pc, nil)
end
function keys.scaleOpposite(pc)
    return keys.scale(pc, Guitree.opp)
end

function keys.scaleH(pc)
    return keys.scale(pc, Guitree.horiz)
end
function keys.scaleV(pc)
    return keys.scale(pc, Guitree.vert)
end

local function make_vimkeygrabber(func_map)
    local keys = {}

    local collect
    collect = keygrabber.run(function(mod, key, event)
        if event == "release" then return end

        logger.print("fine", "Got key: " .. key)
        local choice
        if func_map[key] or tonumber(key) and func_map.number then
            table.insert(keys, key) 
            logger.print("fine", "Found callback")
            func_map[key].callback(keys)
            if func_map[key].wait then
                logger.print("fine", "Keep collecting...")
                return
            else
                logger.print("fine", "Finished collecting...")
            end
        else
            logger.print("fine", "Found no callback")
        end
        keygrabber.stop(collect)
        if func_map.cleanup then func_map.cleanup() end
    end)
end

local function make_keygrabber(screen, cls_map, callback)
    local digits = cls_map.digits

    local keys = {}

    local function hide_others(choice)
        local possible = false
        for k, c in pairs(cls_map) do
            if tonumber(k) then
                if tostring(k):find(choice) then
                    possible = true
                else
                    c.label.visible = false
                end
            end
        end
        return possible
    end

    local collect
    collect = keygrabber.run(function(mod, key, event)
            if event == "release"
                or key:find('Shift')
                or key:find('Control')
                or key:find('Alt')
                or key:find('Super')
            then
                return
            end

            logger.print("fine", "Got key: " .. key)
            local choice
            if tonumber(key) then
                table.insert(keys, tonumber(key)) 
                if #keys < digits then
                    logger.print("fine", "Waiting for more keys")
                    choice = table.concat(keys)
                    local possible = hide_others(choice)
                    if possible then return end
                end
            elseif key ~= "Return" and key ~= "KP_Enter" then
                keys = {}
            end
            keygrabber.stop(collect)
            choice = table.concat(keys)
            if choice then
                logger.print("fine", "Chosen: " .. choice)
                if cls_map[choice] then
                    local cur = cls_map[cls_map.current]
                    callback(cur and cur.node or nil, cls_map[choice].node)
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

local function wrap_text(text, size, color, font)
    size = size or 16
    color = color or '#ffffff'
    font = font or "sans"
    local wrapped = "<span color='" .. color ..
    "' font_desc='" .. font .. " " .. size .. "'>"
    .. text .. "</span>"
    return wrapped
end

local function select_node(callback, label_containers, label_only_containers)
    local cls_map = {curr={}, digits=-1}
    cls_map.curr[0] = 0
    local screen = capi.mouse.screen
    local tag = awful.tag.selected(screen)
    local lastFocus = awful.client.focus.history.get(1, 0)
    local function p() return true end
    local function make_box(c_geo, node, name)

        local label = wibox.widget.textbox()
        label:set_ellipsize('none')

        local font_size
        local wi, he = c_geo.width, c_geo.height
        if not node.tip then
            label:set_align('left')
            label:set_valign('top')
            wi = c_geo.width
            he = c_geo.height
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

                wi, he = label:fit(label, c_geo.width, c_geo.height)
            end
        end
        local geo = {
            x = math.floor(c_geo.x + c_geo.width/2 - wi/2),
            y = math.floor(c_geo.y + c_geo.height/2 - he/2)
        }
        if not node.tip and not awesome.composite_manager_running then
            wi, he = label:fit(label, c_geo.width, c_geo.height)
        end
        geo.width = wi
        geo.height = he
        --local offset = 0
        --if node.index == 1 then
            --local adjust = 20
            --local par_name = tostring(math.floor(name/10))
            --offset = cls_map[par_name].offset + 1
            --geo.x = geo.x+adjust*offset
            --geo.y = geo.y+adjust*offset
            --geo.width = geo.width-adjust*2*offset
            --geo.height = geo.height-adjust*2*offset
        --end
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


        cls_map[name] = {node=node, label=box, offset=offset}
        if node.data.c == lastFocus then
            cls_map.current = name
        end

        return box
    end
    local function f(node, level)
        if level == 0 then return end
        local name = cls_map.curr[level] or cls_map.curr[level-1]*10
        name = name+1
        cls_map.curr[level] = name
        if (node.tip and not label_only_containers)
            or (not node.tip 
                and label_containers) then

            cls_map.digits = math.max(cls_map.digits, level)
            if node:isStyled() then
                --handle ordered containers
                make_box(node.data.geometry.last, node, tostring(name))
            else
                make_box(node.data.geometry.last, node, tostring(name))
            end
        end
    end
    local tree = layout.get_active_tree()
    if tree then
        tree.top:traverse(f)
        make_keygrabber(screen, cls_map, callback)
    end

end

local function select_all(callback) select_node(callback, true, false) end
local function select_client(callback) select_node(callback, false, false) end
local function select_container(callback) select_node(callback, true, true) end

function keys.swap()
    local function c(current, choice)
        current:swap(choice)
    end
    select_client(c)
end

function keys.focus_node(all)
    local function c(current, choice)
        capi.client.focus = choice:getLastFocusedClient()
    end
    if all then
        select_all(c)
    else
        select_client(c)
    end
end

keys.focus = function() keys.focus_node() end
keys.focus_container = function() keys.focus_node(true) end

--TODO complete this mode
function keys.select_use_container()
    --select container
    --select orientation (show with overlays)
    --then next window created is added accordingly
    local active = {}
    local function outline(node, box)
        if box then box.visible = false end

        local c_geo = node.data.geometry.last
        local label = wibox.widget.textbox()
        label:set_ellipsize('none')

        local font_size
        local wi, he = c_geo.width, c_geo.height
        label:set_align('left')
        label:set_valign('top')
        wi = c_geo.width
        he = c_geo.height
        --local text = wrap_text(name, 16)
        --label:set_markup(text)
        local geo = {
            x = c_geo.x,
            y = c_geo.y
        }
        local box
        if true then --awesome.composite_manager_running then
            geo.width = wi
            geo.height = he
            if not box then
                box = wibox({screen = screen,
                             ontop=true,
                             visible=true})
                local bgb = wibox.widget.background()
                local frame = wibox.layout.margin(bgb, 10, 10, 10, 10)
                box:set_widget(frame)
                local color = '#000000'
                box:set_bg(color .. '00')
                bgb:set_bg(color .. '44')
                frame:set_color(color .. '55')
            end
            box:geometry(geo)
        else
            wi, he = label:fit(label, c_geo.width, c_geo.height)
        end
        box.visible = true

        return box
    end
    local screen_index = capi.mouse.screen
    --outline box
    local box
    --move clients on arrow key
    local direction = {
        callback=function(keys)
            local last = keys[#keys]
            local act_par = active.parent
            local rev = false
            if act_par and act_par:getOrder() == Guitree.vert then
                rev = true
            end
            if last == "Up" and not rev 
                or last == "Left" and rev then
                --up to the left
                if active.parent.parent then
                    act_par:detach(active.index)
                    local ind = act_par.index
                    act_par.parent:add(active, ind)
                end
            elseif last == "Down" and not rev 
                or last == "Right" and rev then
                --go down to the right
                if active.index < #act_par.children then
                    act_par:detach(active.index)
                    act_par.children[active.index]:add(active,1)
                end

            elseif last == "Left" and not rev
                or last == "Up" and rev then
                if active.index > 1 then
                    active:swap(act_par.children[active.index-1])
                end
            elseif last == "Right" and not rev
                or last == "Down" and rev then
                if active.index < #act_par.children then
                    active:swap(act_par.children[active.index+1])
                end
            end
            awful.layout.arrange(screen_index)
            awesome.emit_signal("refresh")
            box = outline(active, box)
        end,
        wait=true}
    --create key map
    local map = {d = {callback=function()
                            active:kill()
                        end},
                 s = {callback=function()
                         select_container(function(_, choice)
                                    active:swap(choice)
                         end)
                        end},
                 t = {callback=function()
                         active:shiftStyle()
                         awful.layout.arrange(screen_index)
                     end,
                     wait=true},
                 c = {callback=function()
                         active:shiftOrder()
                         awful.layout.arrange(screen_index)
                     end,
                     wait=true},
                 n = {callback=function()
                         active:minimize(true)
                     end},
                 Up = direction,
                 Down = direction,
                 Left = direction,
                 Right = direction,
                }
    map.x = map.d
    local function c(current, choice)
        layout.active_container = choice 
        active = choice

        map.cleanup = function() box.visible = false end
        box = outline(active)
        make_vimkeygrabber(map)
    end
    --select a container and start vim mode
    select_all(c)
end

return keys
