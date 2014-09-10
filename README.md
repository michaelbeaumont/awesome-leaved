awesome-leaved
==============

Layout for AwesomeWM based on i3 and arranging clients into containers

Features
--------

Similar to i3, clients can be ordered within containers and vertically or horizontally arranged. They can also be "stacked" or "tabbed", and the focused window (client or container) and a list of windows in the container will be shown above, as a stack or tabs.

Instructions
------------

Put the awesome-leaved directory in the same location as rc.lua and include the library in rc.lua:

    local leaved = require "awesome-leaved"
    
Add `leaved.layout` to the `layouts` table in rc.lua

Additionally, add the following to your beautiful theme:

    theme.layout_leaved = "~/.config/awesome/awesome-leaved/leaved.png"

using the correct path to the image file.

Keybindings
-----------

There are a few important keybindings for leaved.

To switch the orientation of the current container use `horizontalize` and `verticalize`.

    awful.key({ modkey }, "h", leaved.horizontalize),
    awful.key({ modkey }, "v", leaved.verticalize),

To force the current container to split in a certain direction, bind any or all of the following functions:

    awful.key({ modkey, "Shift" }, "h", leaved.splitH), --split next horizontal
    awful.key({ modkey, "Shift" }, "v", leaved.splitV), --split next vertical
    awful.key({ modkey, "Shift" }, "o", leaved.splitOpp), --split in opposing direction

To switch between no tabs, tabs and stack use `reorder`:

    awful.key({ modkey, "Shift" }, "t", leaved.reorder),

To scale windows there are two options, use vertical and horizontal scaling and include the percentage points to scale as an argument:

    awful.key({ modkey, "Shift" }, "]", leaved.scaleV(-5)),
    awful.key({ modkey, "Shift" }, "[", leaved.scaleV(5)),
    awful.key({ modkey }, "]", leaved.scaleH(-5)),
    awful.key({ modkey }, "[", leaved.scaleH(5))

Or scale based on the focused client and its opposite direction:

    awful.key({ modkey, "Shift" }, "]", leaved.scaleOpposite(-5)),
    awful.key({ modkey, "Shift" }, "[", leaved.scaleOpposite(5)),
    awful.key({ modkey }, "]", leaved.scaleFocused(-5)),
    awful.key({ modkey }, "[", leaved.scaleFocused(5))

`focusedScale` will always make the current client bigger or smaller in its container and `oppositeScale` will always scale in the opposing direction.

To swap two clients in the tree, use `swap`:

    awful.key({ modkey }, "'", leaved.swap)

To select a client with the keyboard, use `focus`:

    awful.key({ modkey }, ";", leaved.focus)

or (to allow focusing containers as well)

    awful.key({ modkey }, ";", leaved.focus(true))

To minimize an entire container, use `minContainer`:

    awful.key({ modkey, "Shift" }, "n", leaved.keys.minContainer)

TODO
----

This project is incomplete, there are a couple (a lot of) things missing and just as many bugs

* Best way to hide non selected tab?
* Configurable tree creation, i.e. tile by default
* Allowing changing how nodes are labelled when using swap/focus
* Add more using containers support
* Add mouse scaling support
* And more

Bugs
----

* Properly clean up on layout switch
* Couple bugs with client size minimums, figure out better resizing rules
* A couple display bugs after redrawing
