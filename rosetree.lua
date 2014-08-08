-- rosetree.lua
-- Represents a generic rose tree
local Rosetree = {}

function Rosetree:new(data, children, strong)
    local node
    if not children then
        node = {
            tip = true,
            data = data,
            parent = nil,
            index = 0
        }
    else
        node = {
            tip = false,
            strong = strong or false,
            data = data,
            children = children,
            parent = nil,
            index = 0
        }
    end
    self.__index = self
    return setmetatable(node, self)
end

Rosetree.newTip = Rosetree.new
Rosetree.newInner = Rosetree.new

function Rosetree:destroy()
end

--Insert and node manipulation functions
function Rosetree:add(child, ind)
    --convert to inner
    if self.tip then
        self.tip = false
        self.children = {}
    end
    --reassign parent
    child.parent = self

    --add child
    if ind and ind <= #self.children then
        table.insert(self.children, ind, child)
        child.index = ind
    else
        table.insert(self.children, child)
        child.index = #self.children
    end
end

function Rosetree:liftLeaf(strong, newOwnData)
    if self.tip then
        self:destroy()
        self.tip = false
        self.strong = strong or false
        self.children = {}
        local oldOwnData = self.data
        self.data = newOwnData
        self:add(self:newTip(oldOwnData))
        return self
    end
end

function Rosetree:squashLeaf()
    local child = self.children[1]
    self:destroy()
    self.tip = child.tip
    self.data = child.data
    self.children = child.children
    return self
end

--Search and filter rosetrees
function Rosetree:find(compare)
    if self.tip then
        return compare(self) and self or nil
    else
        for _, c in ipairs(self.children) do
            local res = c:find(compare)
            if res then
                return res
            end
        end
    end
end

function Rosetree:filter(p, once)
    if p(self) then
        self:destroy()
        return nil
    elseif not self.tip then
        for i, child in ipairs(self.children) do
            local res = child:filter(p, once)
            if not res then
                table.remove(self.children, i)
                if once then
                    break
                end
            else
                self.children[i] = res
            end
        end
        self:refreshLabel()
        if self.strong or #self.children > 1 then
            self:destroy()
            return self
        elseif #self.children == 0 then
            self:destroy()
            return nil
        elseif #self.children == 1 then
            return self:squashLeaf()
        end
    else
        return self
    end
end


function Rosetree:traverse(f, p, level)
    if level == nil then
        level = 0
    end
    f(self, level)

    if not self.tip and p(self) then
        local l = self.children
        for _, c in ipairs(self.children) do
            c:traverse(f, p, level + 1)
        end
    end
end

function Rosetree:show(level)
    local function shower(node, level)
        local name 
        if node.tip then
            name = "Tip["
        else
            name = "Node["
        end
        print(string.rep(" ", level) .. name .. tostring(node.data) .. "]")
    end
    self:traverse(shower, function(o) return true end, level)
end

return Rosetree
