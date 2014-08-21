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
        }
    else
        node = {
            tip = false,
            strong = strong or false,
            data = data,
            children = children,
            parent = nil,
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
    else
        table.insert(self.children, child)
    end
end

function Rosetree:pushdownTip(strong, newOwnData)
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

function Rosetree:pairWith(child)
    self:pushdownTip()
    self:add(child)
end

function Rosetree:pullupTip()
    local child = self.children[1]
    self:destroy()
    return child
--    self.tip = child.tip
--    self.data = child.data
--    self.children = child.children
--    return self
end

function Rosetree:swap(node)
    if node == self then return end
    local own_par = self.parent
    local node_par = node.parent
    local ni, oi
    for i, c in ipairs(own_par.children) do
        if c == self then
            oi = i
        end
    end
    for i, c in ipairs(node_par.children) do
        if c == node then
            ni = i
        end
    end
    node_par.children[ni] = self
    own_par.children[oi] = node
    node.parent = own_par
    self.parent = node_par
    node:refreshLabel()
    self:refreshLabel()
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
        --self:refreshLabel()
        if #self.children > 1 then
            return self
        elseif #self.children == 0 then
            self:destroy()
            return self.strong and self or nil
        elseif #self.children == 1 and not self.strong then
            self:destroy()
            return self:pullupTip()
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
