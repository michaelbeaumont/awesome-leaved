local awful = require "awful"
local wibox = require "wibox"
local Guitree = require "awesome-leaved.guitree"

local capi =
{
    client = client,
    button = button
}

local tabbox = {}
tabbox.box_height=20

--Taken from awful.widget.common
local function create_buttons(buttons, object)
    if buttons then
        local btns = {}
        for kb, b in ipairs(buttons) do
            -- Create a proxy button object: it will receive the real
            -- press and release events, and will propagate them to the
            -- button object the user provided, but with the object as
            -- argument.
            local btn = capi.button { modifiers = b.modifiers, button = b.button }
            btn:connect_signal("press", function () b:emit_signal("press", object) end)
            btn:connect_signal("release", function () b:emit_signal("release", object) end)
            btns[#btns + 1] = btn
        end

        return btns
    end
end

local function label(data)
    return data.label, data.bg, data.bg_image, data.icon
end

function tabbox:rename(container)
    -- update the widgets, creating them if needed
    local w = self.layout
    local buttons = self.buttons
    local data = self.cache_data
    w:reset()
    for i, o in ipairs(container.children) do
        local cache = data[o]
        local ib, tb, bgb, m, l
        if cache then
            ib = cache.ib
            tb = cache.tb
            bgb = cache.bgb
            m   = cache.m
        else
            ib = wibox.widget.imagebox()
            tb = wibox.widget.textbox()
            bgb = wibox.widget.background()
            m = wibox.layout.margin(tb, 4, 4)
            l = wibox.layout.fixed.horizontal()

            -- All of this is added in a fixed widget
            l:fill_space(true)
            l:add(ib)
            l:add(m)

            -- And all of this gets a background
            bgb:set_widget(l)

            bgb:buttons(create_buttons(buttons, o))

            data[o] = {
                ib = ib,
                tb = tb,
                bgb = bgb,
                m   = m
            }
        end

        local text, bg, bg_image, icon = label(o.data)

        --The text might be invalid, so use pcall
        if not pcall(tb.set_markup, tb, text) then
            tb:set_markup("<i>&lt;Invalid text&gt;</i>")
        end
        bgb:set_bg(bg)
        if type(bg_image) == "function" then
            bg_image = bg_image(tb,o,m,objects,i)
        end
        bgb:set_bgimage(bg_image)
        ib:set_image(icon)
        if not pcall(tb.set_markup, tb, text) then
            tb:set_markup("<i>&lt;Invalid text&gt;</i>")
        end
        tb:set_markup(o.data.label)
        w:add(bgb)
    end
end

function tabbox:resize(p, geometry, node)
    local order = node:getOrder()
    if order ~= self.order then
        if order == Guitree.stack then
            self.layout = wibox.layout.flex.vertical()
        else
            self.layout = wibox.layout.flex.horizontal()
        end
        self.container:set_widget(self.layout)
        self.order = order
        self:rename(node)
    end
    local new_geo = { width = geometry.width,
                      x = geometry.x,
                      y = geometry.y }
    if self.order == Guitree.stack then
        new_geo.height = tabbox.box_height*(#node.children)
    else
        new_geo.height = self.box_height
    end
    self.container:geometry(new_geo)
    if geometry.width == 0 or geometry.height == 0 then
        self.container.visible = false 
    end
end

function tabbox:redraw(p, geometry, node)
    self:resize(p, geometry, node)
    self:rename(node)
end

function tabbox:new(screen, geometry)
    local tabbox = {}
    local container = wibox({screen = screen, ontop = true, visible=true})

    tabbox.buttons = awful.util.table.join(
                     awful.button({ }, 1, function (node)
                         while not node.data.lastFocus.data.c do
                             node = node.data.lastFocus
                         end
                         local c = node.data.lastFocus.data.c
                         capi.client.focus = c
                         c:raise()
                     end))

    tabbox.cache_data = setmetatable({}, { __mode = 'k' })
    tabbox.destroy = 
        function()
            tabbox.container.visible = false
        end

    tabbox.container = container
    tabbox.layout = layout

    self.__index = self
    setmetatable(tabbox, self)

    return tabbox
end

return tabbox
