local awful = {
    tag = require "awful.tag"
}
local Guitree = require "awesome-leaved.guitree"

local tile = {
}


function tile:init(p, tree)
    local top_order = Guitree.flip_order(self.order)

    --add master container
    tree.top:setOrder(top_order)
    tree.top:add(Guitree:newContainer(true))
    tree.top.children[1]:setOrder(self.order)
end

function tile:refactor(tree, mwfact)
    --calculate fact for the master container with mwfact
    local real_ncol = #tree.top.children-1
    if real_ncol > 0 then
        tree.top.children[1].data.geometry.fact = mwfact*real_ncol/(1-mwfact)
    end
end

function tile:manage(p, tree)
    --reset tree if the ncol has changed
    local t = awful.tag.selected(p.screen)
    local ncol = awful.tag.getncol(t)
    local diff = #tree.top.children-1 - ncol
    if diff ~= 0 then
        tree.top:detach(2,#tree.top.children)
        tree.total_num = #tree.top.children[1].children
    end
end

function tile:handleNew(p, tree, lastFocusNode, initLayout, requestedOrder)
    local top = tree.top
    local t = awful.tag.selected(p.screen)

    local cls = p.clients
    local maxnmaster = awful.tag.getnmaster(t)
    local nmaster = math.min(maxnmaster, #cls)
    local mwfact = awful.tag.getmwfact(t)
    local ncol = awful.tag.getncol(t)

    for i, c in ipairs(p.clients) do
        --maybe unnecessarily slow? could maintain a list of tracked clients
        local possibleChild = top:findWith("window", c.window)
        if not possibleChild then
            local newTip = Guitree:newClient(c)

            if requestedOrder == Guitree.opp then
                local parentOrder = lastFocusNode.parent:getOrder()
                lastFocusNode:add(newTip)
            elseif #tree.top.children[1].children < maxnmaster then
                tree.top.children[1]:add(newTip)
            else
                local ind = self.flip and 1
                local i = 2
                while i <= ncol+1 do
                    if not tree.top.children[i] then
                        tree.top:add(Guitree:newContainer(true))
                        tree.top.children[i]:setOrder(self.order)
                        break
                    elseif #tree.top.children[i].children
                        < #tree.top.children[2].children then
                        break
                    else
                        i=i+1
                    end
                end
                if i > ncol+1 then i = 2 end
                tree.top.children[i]:add(newTip)
            end
        end
    end
    tile:refactor(tree, mwfact)
end

function tile:new(order, flip)
    self.__index = self
    return setmetatable({order=order, flip=flip}, self)
end

tile.versions = {
    left=tile:new(Guitree.vert, false),
    right=tile:new(Guitree.vert, true),
}

return tile
