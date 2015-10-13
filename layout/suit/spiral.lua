local Guitree = require "awesome-leaved.guitree"

local spiral = setmetatable({}, {__index=layout})

function spiral:init() end

function spiral.nextOrder(initLayout, lastFocusNode)
    local ret
    if initLayout then
        if spiral.lastOrder == Guitree.horiz then
            spiral.lastOrder = Guitree.vert
        else
            spiral.lastOrder = Guitree.horiz
        end
        return spiral.lastOrder
    end

    local lastFocusGeo = lastFocusNode.data.c:geometry()

    local nextOrder = self.forceNextOrder
    if not nextOrder then
        if (lastFocusGeo.width <= lastFocusGeo.height) then
            nextOrder = Guitree.vert
        else
            nextOrder = Guitree.horiz
        end
    elseif nextOrder == Guitree.opp then
        if lastFocusOrder == Guitree.horiz then
            nextOrder = Guitree.vert
        elseif lastFocusOrder== Guitree.vert then
            nextOrder = Guitree.horiz
        else
            nextOrder = lastFocusOrder
        end
    end
    return nextOrder
end

function spiral:handleChanged(p, tree, lastFocusNode, initLayout)
    local top = tree.top
    local newTip

    for i, c in ipairs(p.clients) do
        --maybe unnecessarily slow? could maintain a list of tracked clients
        local possibleChild = top:findWith("window", c.window)
        if not possibleChild then
            newTip = Guitree:newClient(c)

            if lastFocusNode then
                local lastFocusParent = lastFocusNode.parent
                local lastFocusOrder= lastFocusParent:getOrder()

                local nextOrder = spiral.nextOrder(initLayout, lastFocusNode)

                if lastFocusOrder ~= nextOrder then
                    lastFocusNode:add(newTip)
                    newTip.parent:setOrder(nextOrder)
                else
                    lastFocusParent:add(newTip)
                end
            else
                top:add(newTip)
            end
            lastFocusNode = newTip
        else
            lastFocusNode = possibleChild
        end
    end
    return newTip
end

return spiral
