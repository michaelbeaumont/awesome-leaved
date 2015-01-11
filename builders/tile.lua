local awful = {
    tag = require "awful.tag"
}
local Guitree = require "awesome-leaved.guitree"
local utils = require "awesome-leaved.utils"
local logger = utils.logger('off')

local tile = {
}

function tile:init(p, tree)
    local top_order = Guitree.flip_order(self.order)

    --add master container
    tree.top:setOrder(top_order)
    tree.top:add(Guitree:newContainer(true))
    tree.top.children[1]:setOrder(self.order)
end

local function flatten_treetop(top, flip)
    local queue = {}
    local colstart = flip and #top.children or 1
    local colend = flip and 1 or #top.children
    local direction = flip and -1 or 1
    for _, m in ipairs(top.children[colstart].children) do
        table.insert(queue, m)
    end
    if #top.children < 2 then return queue end

    colstart = colstart+direction
    local row = 1
    --return queue
    while row do
        for i=colstart,colend,direction do
            local column = top.children[i]
            local nex = column.children[row]
            if nex then
                table.insert(queue, nex)
            else
                return queue
            end
        end
        row = row+1
    end
end

function tile:reorder(p, tree)
    local t = awful.tag.selected(p.screen)
    local nmaster = awful.tag.getnmaster(t)
    local ncol = awful.tag.getncol(t)

    local queue = flatten_treetop(tree.top, self.flip)
    local top = tree.top

    tree.top:detach(1,#tree.top.children)

    local new_slave_index = self.flip and 1 or nil

    local new_master = Guitree:newContainer(true)

    for i=1,nmaster do
        local nex = table.remove(queue, 1)
        if nex then
            new_master:add(nex)
        end
    end

    local max_per_slave = math.ceil(#queue / ncol)
    local new_slaves = {}

    for j=1,max_per_slave do
        for i=1,ncol do
            local nex = table.remove(queue, 1)
            if nex then
                if not new_slaves[i] then
                    new_slaves[i] = Guitree:newContainer(true)
                    new_slaves[i]:setOrder(self.order)
                end
                new_slaves[i]:add(nex) 
            else
                break
            end
        end
    end

    for _, s in ipairs(new_slaves) do
        top:add(s, new_slave_index)
    end
    new_master:setOrder(self.order)
    top:add(new_master, not self.flip and 1 or nil)
end

function tile:refactor(tree, mwfact)
    --calculate fact for the master container with mwfact
    local real_ncol = #tree.top.children-1
    if real_ncol > 0 then
        local master_index = self.flip and #tree.top.children or 1
        local colstart = flip and #tree.top.children-1 or 2
        local colend = flip and 1 or #tree.top.children
        local direction = flip and -1 or 1
        local visible_cols = 0
        for i=colstart,colend,direction do
            if tree.top.children[i]:inTree() then
                visible_cols = visible_cols+1
            end
        end
        tree.top.children[master_index].data.geometry.fact = mwfact*visible_cols/(1-mwfact)
    end
end

function tile:handleNew(p, tree, lastFocusNode, initLayout, requestedOrder)
    self.handled_new = true
    local top = tree.top
    local t = awful.tag.selected(p.screen)

    local cls = p.clients
    local maxnmaster = awful.tag.getnmaster(t)
    local nmaster = math.min(maxnmaster, #cls)
    local mwfact = awful.tag.getmwfact(t)
    local ncol = awful.tag.getncol(t)
    local master_i, _, _ = self:get_range(tree)

    for i, c in ipairs(p.clients) do
        --maybe unnecessarily slow? could maintain a list of tracked clients
        local possibleChild = top:findWith("window", c.window)
        if not possibleChild then
            local newTip = Guitree:newClient(c)

            if requestedOrder == Guitree.opp then
                local parentOrder = lastFocusNode.parent:getOrder()
                lastFocusNode:add(newTip)
            elseif #tree.top.children[master_i].children < maxnmaster then
                tree.top.children[master_i]:add(newTip)
            else
                local strt, endd, inc = self:get_range(tree)
                local cntr = strt+inc
                local first_slave = self.flip and #tree.top.children-1 or 2

                while cntr >= #tree.top.children-(ncol) and cntr <= ncol+1 do
                    if not tree.top.children[cntr] then
                        cntr = self:new_slave_index(tree)
                        tree.top:add(Guitree:newContainer(true), cntr)
                        tree.top.children[cntr]:setOrder(self.order)
                        first_slave = self.flip and #tree.top.children-1 or 2
                        break
                    elseif #tree.top.children[cntr].children
                            < #tree.top.children[first_slave].children then
                        break
                    end
                    cntr=cntr+inc
                end
                if not (cntr >= 1 and cntr <= ncol+1) then
                    cntr = first_slave
                end
                tree.top.children[cntr]:add(newTip)
            end
        end
    end
    self:refactor(tree, mwfact)
end

function tile:cleanup(p, tree)
    local ncol = awful.tag.getncol(t)
    local col_diff = #tree.top.children-1 - ncol
    local nmaster = awful.tag.getnmaster(t)
    local master_index = self.flip and #tree.top.children or 1
    local mast_diff = #tree.top.children[master_index].children - nmaster
    if (col_diff ~= 0 or mast_diff ~= 0) and not self.handled_new then
        self:reorder(p, tree)
    end
    self.handled_new = false
    local mwfact = awful.tag.getmwfact(t)
    self:refactor(tree, mwfact)
end

function tile:new_slave_index(tree)
    if self.flip then
        return 1
    else
        return #tree.top.children+1
    end
end

function tile:get_range(tree)
    --return (start, end, inc)
    if self.flip then
        return #tree.top.children, 1, -1
    else
        return 1, #tree.top.children, 1
    end
end

function tile:new(order, flip)
    self.__index = self
    return setmetatable({
                         order=order, flip=flip,
                        }, self)
end

tile.versions = {
    left=tile:new(1, false),
    right=tile:new(1, true),
}

return tile
