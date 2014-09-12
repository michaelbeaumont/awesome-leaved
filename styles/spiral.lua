local Guitree = require "awesome-leaved.guitree"

local spiral = {}

function spiral.nextOrient(initLayout, lastFocusNode, requestedOrient)
    local ret
    if initLayout then
        if spiral.lastOrient == Guitree.horiz then
            spiral.lastOrient = Guitree.vert
        else
            spiral.lastOrient = Guitree.horiz
        end
        return spiral.lastOrient
    end

    local lastFocusGeo = lastFocusNode.data.c:geometry()

    local nextOrient = requestedOrient
    if not nextOrient then
        if (lastFocusGeo.width <= lastFocusGeo.height) then
            nextOrient = Guitree.vert
        else
            nextOrient = Guitree.horiz
        end
    elseif nextOrient == Guitree.opp then
        if lastFocusOrientation == Guitree.horiz then
            nextOrient = Guitree.vert
        elseif lastFocusOrientation == Guitree.vert then
            nextOrient = Guitree.horiz
        else
            nextOrient = lastFocusOrientation
        end
    end
    return nextOrient
end

function spiral.manage(p, tree, lastFocusNode, initLayout, requestedOrient)
    local top = tree.top

    for i, c in ipairs(p.clients) do
        --maybe unnecessarily slow? could maintain a list of tracked clients
        local possibleChild = top:findWith("window", c.window)
        if not possibleChild then
            local newTip = Guitree:newClient(c)

            if lastFocusNode then
                local lastFocusParent = lastFocusNode.parent
                local lastFocusOrientation = lastFocusParent:getOrientation()

                local nextOrient = spiral.nextOrient(initLayout, lastFocusNode, requestedOrient)

                if lastFocusOrientation ~= nextOrient then
                    lastFocusNode:add(newTip)
                    newTip.parent:setOrientation(nextOrient)
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
end

return spiral
