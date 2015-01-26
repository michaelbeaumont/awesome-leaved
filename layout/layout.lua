-- Awesome-Leaved: Layout for AwesomeWM based on i3's behavior
-- 2014, Michael Beaumont, mjboamail@gmail.com
---------------------------------------------------

local print, tostring = print, tostring
local ipairs, pairs = ipairs, pairs
local setmetatable = setmetatable
local table = table
local math = math
local awful = require "awful"
local wibox = require "wibox"
local naughty = require "naughty"

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
local utils = require "awesome-leaved.utils"


local layout = { name = 'leaved',
                 trees = {},
                 arrange_lock = false}

-- Globals
local logger = utils.logger('off')

--draw and arrange functions
function layout.draw_tree(self, screen, geometry, hides)
    if not self.tip and #self.children > 0 then
        local maximized = self.data.geometry.max.h and self.data.geometry.max.v
        local geo = maximized and screen.workarea or geometry

        if not self:inTree() then
            geo.width = 0
            geo.height = 0
        end

        --Handle the tabbox
        local tabbox_height = 0
        if self:isStyled() then
            if not self.data.tabbox then
                self.data.tabbox = Tabbox:new(screen.index)
            end
            self.data.tabbox:redraw(screen, geo, self)
            tabbox_height = self.data.tabbox.container.height
        end
        geo.height = geo.height - tabbox_height
        geo.y = geo.y + tabbox_height


        --if we are tabbed or stacked then render only the focused node
        if self:isStyled() then
            for _, s in ipairs(self.children) do
                if s:inTree() then
                    local sub_geo = { x=geometry.x, y=geometry.y }
                    if self.data.lastFocus ~= s then
                        sub_geo.width = 0
                        sub_geo.height = 0
                        layout.draw_tree(s, screen, sub_geo, hides)
                    else
                        sub_geo.width = geo.width
                        sub_geo.height = geo.height
                        local real_geo = layout.draw_tree(s, screen, sub_geo, hides)
                        geo.height = real_geo.height
                        geo.width = real_geo.width
                    end

                end
            end
            geo.height = geo.height + tabbox_height
            geo.y = geo.y - tabbox_height
        else
            --figure out if we're distributing over width or height
            local dimension, invariant, offset
            if self:isHorizontal() then
                dimension = "width"
                invariant = "y"
                offset = "x"
            else
                dimension = "height"
                invariant = "x"
                offset = "y"
            end


            local current_offset = geo[offset]

            --new vars
            local used = 0
            local unused = geo[dimension]
            local remaining_fact = 0

            --figure out how many windows will be rendered
            for _, s in ipairs(self.children) do
                remaining_fact = remaining_fact +
                (s:inTree() and s.data.geometry.fact or 0)
            end
            --read just according to the minimum size hints
            for _, s in ipairs(self.children) do
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
            for _, s in ipairs(self.children) do
                local sub_geo = { width=geo.width, height=geo.height,
                                    x=geo.x, y=geo.y }
                if s:inTree() then
                    local sub_fact = s:inTree() and s.data.geometry.fact or 0
                    sub_geo[invariant] = geo[invariant]
                    sub_geo[offset] = current_offset
                    sub_geo[dimension] = math.floor(sub_fact/remaining_fact*unused)

                    local real_geo = layout.draw_tree(s, screen, sub_geo, hides)

                    used = used + real_geo[dimension]
                    current_offset = current_offset + real_geo[dimension]
                    unused = unused - real_geo[dimension]
                    remaining_fact = remaining_fact - sub_fact
                else
                    layout.draw_tree(s, screen, sub_geo, hides)
                end
            end
            geo[dimension] = used
        end
        self.data.geometry.last = geo
        return geo
    elseif self.tip then
        local c = self.data.c
        if awful.client.floating.get(c) then
            geometry.width = 0
            geometry.height = 0
            self.data.geometry.last = self.data.c:geometry()
            return geometry
        end
        if geometry.width > 0 and geometry.height > 0 then
            local border = 2*c.border_width
            geometry.width = geometry.width - border
            geometry.height = geometry.height - border

            geometry = self.data.c:geometry(geometry)

            self.data.geometry.last = geometry
            hides.space = geometry
            --use last used geometry for stashing hidden clients

            --add back borders for reporting used size
            geometry.width = geometry.width + border
            geometry.height = geometry.height + border

        elseif self:inTree() then
            --horrible hack due to wiboxes otherwise being under all windows
            table.insert(hides, c)
        end

        return geometry
    end
end

function layout.arrange(p)
    if layout.arrange_lock then
        logger.print('fine', "Encountered arrange lock")
        return
    end
    layout.arrange_lock = true

    local area = p.workarea
    local n = #p.clients

    local tag = awful.tag.selected(capi.mouse.screen)
    local builder = awful.tag.getproperty(tag, "layout")

    local trees = layout.trees
    if not trees[tag] then trees[tag] = {} end
    if not trees[tag][builder.class] then
        trees[tag][builder.class] = {
            clients = nil,
            total_num = 0,
            top = Guitree:newContainer(true)
        }
        builder:init(trees[tag][builder.class].top)
    end

    local our_tree = trees[tag][builder.class]
    local top = our_tree.top

    local old_num = our_tree.total_num
    local changed = n - old_num
    local initLayout
    if math.abs(changed) > 1 then
        initLayout = true
    end
    our_tree.total_num = n

    if changed > 0 then
        local lastFocusNode
        local lastFocus = awful.client.focus.history.get(1, 0)
        if lastFocus and not awful.client.floating.get(lastFocus) then
            lastFocusNode = top:findWith("window", lastFocus.window)
        end

        --we have new clients
        builder:handleNew(p,
                       our_tree,
                       lastFocusNode,
                       initLayout)

        layout.forceNextOrder = nil
    end

    hides = {space = p.workarea}
    if n >= 1 then
        builder:redraw(top, p, area, hides)
    end
    for _, c in ipairs(hides) do
        c:geometry({width=1, height=1, x=hides.space.x, y = hides.space.y})
        c.below = true
    end

    if logger.info then top:show() end

    layout.arrange_lock = false
end

function layout.is_active()
    local screen_index = capi.mouse.screen
    local tag = awful.tag.selected(screen_index)
    return awful.tag.getproperty(tag, "layout").name == "leaved"
end

function layout.get_active_tree()
    local screen = capi.mouse.screen
    local tag = awful.tag.selected(screen)
    local builder = awful.tag.getproperty(tag, "layout")

    return layout.trees[tag] and layout.trees[tag][builder.class]
end

function layout.node_from_client(c)
    local our_tree = layout.get_active_tree()
    return our_tree.top:findWith("window", c.window)
end

--Function to remove a client from a tag's tree
local function clean_from_tag(c, tag)
    local tagstree = layout.trees[tag]
    if tagstree then
        for _, tree in pairs(tagstree) do
            tree.top:filterClientAttr("window", c.window)
        end
    end
end

--Initialize the layout
local initialized = {}
local function handle_signals(t)
    if awful.tag.getproperty(t, "layout").name == "leaved"
    and not initialized[t] then
        initialized[t] = true
        capi.client.connect_signal("untagged", clean_from_tag)
    end
end


awful.tag.attached_connect_signal(s, "property::layout", handle_signals)

return layout
