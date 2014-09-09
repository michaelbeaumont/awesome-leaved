-- rosetree.lua
-- Represents a generic rose tree
local Rosetree = {}

function Rosetree:new(data, children, strong)
    local node
    if not children then
        node = {
            tip = true,
            data = data,
            index = nil,
            parent = nil,
        }
    else
        node = {
            tip = false,
            strong = strong or false,
            data = data,
            children = children,
            index = nil,
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
        self:destroy()
        self.tip = false
        self.strong = false
        local cont = self:newContainer()
        self.children = {}
        local oldData = self.data
        self.data = cont.data
        local child = self:newTip(oldData)
        self:add(child)
    end
    --reassign parent
    child.parent = self

    --add child
    if ind and ind <= #self.children then
        for i=ind,#self.children do
            self.children[i].index = i
        end
        table.insert(self.children, ind, child)
        child.index = ind
    else
        table.insert(self.children, child)
        child.index = #self.children
    end
    child.index = ind or #self.children
end

function Rosetree:detach(ind)
    if not ind or self.tip then return end
    for i=ind+1,#self.children do
        self.children[i-1] = self.children[i]
        self.children[i-1].index = i-1
    end
    self.children[#self.children] = nil
    return self.children[ind]
end

function Rosetree:swap(node)
    local own_par = self.parent
    local node_par = node.parent
    if node == self
        or not own_par
        or not node_par then
        return
    else
        local test = self
        local testee = node
        local caught
        for i = 1,2 do
            while test and test ~= testee do
                test = test.parent
            end
            caught = caught or test == testee
            test = node
            testee = self
        end
        if caught then return end
    end
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
    node.index = oi
    self.index = ni
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
        if #self.children == 0 then
            self:destroy()
            return self.strong and self or nil
        elseif #self.children == 1 and not self.strong then
            self:destroy()
            self.children[1].parent = self.parent
            return self.children[1]
        else
            return self
        end
    else
        return self
    end
end


function Rosetree:traverse(f, p, level)
    if level == nil then
        level = 0
    end
    if p == nil then
        p = function() return true end
    end
    f(self, level)

    if not self.tip and p(self) then
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
