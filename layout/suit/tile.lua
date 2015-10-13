local awful = {
    tag = require "awful.tag"
}
local layout = require "awesome-leaved.layout.layout"
local Guitree = require "awesome-leaved.guitree"
local utils = require "awesome-leaved.utils"
local logger = utils.cmdlogger('fatal')

local tile = setmetatable({class="tile"}, {__index=layout})

function tile:init(top)
    top:setOrder(self.order)
end

--special draw functions
--draws a column in the tile layout
local function draw_column(rows, order, screen, geometry, hides)
    --figure out if we're distributing over width or height
    local dimension, invariant, offset
    if order == Guitree.vert then
        dimension = "width"
        invariant = "y"
        offset = "x"
    else
        dimension = "height"
        invariant = "x"
        offset = "y"
    end


    --new vars
    local geo = geometry
    local current_offset = geo[offset]

    local used = 0
    local unused = geo[dimension]
    local remaining_fact = 0

    --figure out how many windows will be rendered
    for _, s in ipairs(rows) do
        remaining_fact = remaining_fact +
            (s:inTree() and s.data.geometry.fact or 0)
    end
    --read just according to the minimum size hints
    for _, s in ipairs(rows) do
        --retrieve size hints
        local sh = s.data.geometry.hints or s:getSizeHints()
        if logger.fine then
            print("Size hints: w: " .. sh.width .. " h: " .. sh.height)
        end
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
    for _, s in ipairs(rows) do
        local sub_geo = { width=geo.width, height=geo.height,
                          x=geo.x, y=geo.y }
        if s:inTree() then
            local sub_fact = s.data.geometry.fact
            sub_geo[invariant] = geo[invariant]
            sub_geo[offset] = current_offset
            sub_geo[dimension] = math.floor(sub_fact/remaining_fact*unused)

            local real_geo = layout.draw_tree(screen, s, sub_geo, hides)

            used = used + real_geo[dimension]
            current_offset = current_offset + real_geo[dimension]
            unused = unused - real_geo[dimension]
            remaining_fact = remaining_fact - sub_fact
        else
            layout.draw_tree(screen,  s, sub_geo, hides)
        end
    end
    geo[dimension] = used
    return geo
end

function tile:redraw(screen, node, geometry, hides)
    --organize containers
    local nmaster = awful.tag.getnmaster(t)
    local masters = {fact=1}
    local index = 1
    while #masters < nmaster and index <= #node.children do
        if node.children[index]:inTree() then
            table.insert(masters, node.children[index])
        else
            --TODO: Change in other parts, important for min'd containers
            local sub_geo = { width=0, height=0, x=0, y=0 }
            layout.draw_tree(screen, node.children[index], sub_geo, hides)
        end
        index = index + 1
    end
    local queue = {}
    while index <= #node.children do
        if node.children[index]:inTree() then
            table.insert(queue, node.children[index])
        end
        index = index + 1
    end

    --sort columns
    local ncol = awful.tag.getncol(t)
    local max_per_col = math.ceil(#queue/ncol)
    local col_num = 1
    local cols = #queue > 0 and {{fact = 1}} or {}
    local remaining_fact = 1

    for i, s in ipairs(queue) do
        if s:inTree() then
            table.insert(cols[col_num], s)
        else
            --draw_tree with 0 geo
        end
        if #cols[col_num] == max_per_col then
            col_num = self.flip and (col_num) or col_num + 1
            if i < #queue then
                remaining_fact = remaining_fact+1
                table.insert(cols,
                             self.flip and 1 or #cols+1,
                             {fact = 1})
            end
        end
    end

    if #cols > 0 and #masters > 0 then
        local mwmultip = awful.tag.getmwfact(t)
        masters.fact = mwmultip*remaining_fact/(1-mwmultip)
        remaining_fact = remaining_fact + masters.fact
    end

    --start drawing
    local dimension, invariant, offset
    if node.data.order == Guitree.horiz then
        dimension = "width"
        invariant = "y"
        offset = "x"
    else
        dimension = "height"
        invariant = "x"
        offset = "y"
    end
    local geo = screen.workarea
    local used = 0
    local unused = geo[dimension]
    local current_offset = geo[offset]

    --add masters
    if #masters > 0 then
        table.insert(cols, self.flip and #cols+1 or 1, masters)
    end

    --draw columns
    for _, col in ipairs(cols) do
        local sub_geo = { width=geo.width, height=geo.height,
                          x=geo.x, y=geo.y }
        sub_geo[invariant] = geo[invariant]
        sub_geo[offset] = current_offset

        sub_geo[dimension] = math.floor(col.fact/remaining_fact*unused)

        local real_geo = draw_column(col, node.data.order, screen, sub_geo, {})
        used = used + real_geo[dimension]
        current_offset = current_offset + real_geo[dimension]
        unused = unused - real_geo[dimension]
        remaining_fact = remaining_fact - col.fact
    end
end


function tile:handleChanged(p, tree, lastFocusNode, initLayout)
    local top = tree.top
    local t = awful.tag.selected(p.screen)

    local cls = p.clients
    local newTip

    for i, c in ipairs(p.clients) do
        --maybe unnecessarily slow? could maintain a list of tracked clients
        local possibleChild = top:findWith("window", c.window)
        if not possibleChild then
            newTip = Guitree:newClient(c)

            if lastFocusNode and self.forceNextOrder then
                local lastFocusParent = lastFocusNode.parent
                local lastFocusOrder= lastFocusParent:getOrder()

                lastFocusNode:add(newTip)
                newTip.parent:setOrder(self.forceNextOrder)
            else
                top:add(newTip)
                lastFocusNode = newTip
            end
        elseif not lastFocusNode then
            lastFocusNode = possibleChild
        end
    end
    return newTip
end

function tile:new(order, flip, name)
    return setmetatable({order=order, flip=flip, name=name}, {__index=self})
end

tile.right=tile:new(Guitree.horiz, false, 'leavedright')
tile.left=tile:new(Guitree.horiz, true, 'leavedleft')
tile.bottom=tile:new(Guitree.vert, false, 'leavedbottom')
tile.top=tile:new(Guitree.vert, true, 'leavedtop')

return tile
