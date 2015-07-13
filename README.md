awesome-leaved
==============

Layout for AwesomeWM based on i3 and arranging clients into containers

Features
--------

Similar to i3, clients can be ordered within containers and vertically or horizontally arranged. They can also be "stacked" or "tabbed", and the focused window (client or container) and a list of windows in the container will be shown above, as a stack or tabs.

**Note**: This library is developed using the git version of awesome, there may be bugs caused by using earlier versions

Instructions
------------

Put the awesome-leaved directory in the same location as rc.lua and include the library in rc.lua:

    local leaved = require "awesome-leaved"
    
There are currently two different types of layout, one that tiles and one that acts like the spiral layout from awful, splitting containers along the shortest axis 

Add some of the following to the `layouts` table in rc.lua

    leaved.layout.suit.tile.right
    leaved.layout.suit.tile.left
    leaved.layout.suit.tile.bottom
    leaved.layout.suit.tile.top

Additionally, add the following to your beautiful theme:

    theme.layout_leavedright = "~/.config/awesome/awesome-leaved/icons/leavedright.png"
    theme.layout_leavedleft = "~/.config/awesome/awesome-leaved/icons/leavedleft.png"
    theme.layout_leavedbottom = "~/.config/awesome/awesome-leaved/icons/leavedbottom.png"
    theme.layout_leavedtop = "~/.config/awesome/awesome-leaved/icons/leavedtop.png"

using the correct path to the image file in this repository.

Keybindings
-----------

There are a few important keybindings for leaved.

To switch the orientation of the current container use `shiftOrder`:

    awful.key({ modkey }, "o", leaved.keys.shiftOrder),

To force the current container to split in a certain direction, bind any or all of the following functions:

    awful.key({ modkey, "Shift" }, "h", leaved.keys.splitH), --split next horizontal
    awful.key({ modkey, "Shift" }, "v", leaved.keys.splitV), --split next vertical
    awful.key({ modkey, "Shift" }, "o", leaved.keys.splitOpp), --split in opposing direction

To switch between no tabs, tabs and stack use `shiftStyle`:

    awful.key({ modkey, "Shift" }, "t", leaved.keys.shiftStyle),

To scale windows there are two options, use vertical and horizontal scaling and include the percentage points to scale as an argument:

    awful.key({ modkey, "Shift" }, "]", leaved.keys.scaleV(-5)),
    awful.key({ modkey, "Shift" }, "[", leaved.keys.scaleV(5)),
    awful.key({ modkey }, "]", leaved.keys.scaleH(-5)),
    awful.key({ modkey }, "[", leaved.keys.scaleH(5))

Or scale based on the focused client and its opposite direction:

    awful.key({ modkey, "Shift" }, "]", leaved.keys.scaleOpposite(-5)),
    awful.key({ modkey, "Shift" }, "[", leaved.keys.scaleOpposite(5)),
    awful.key({ modkey }, "]", leaved.keys.scaleFocused(-5)),
    awful.key({ modkey }, "[", leaved.keys.scaleFocused(5))

`focusedScale` will always make the current client bigger or smaller in its container and `oppositeScale` will always scale in the opposing direction.

To swap the active client with another in the tree, use `swap`:

    awful.key({ modkey }, "'", leaved.keys.swap)

To select a client with the keyboard, use `focus`:

    awful.key({ modkey }, ";", leaved.keys.focus)

or (to allow focusing containers as well)

    awful.key({ modkey }, ";", leaved.keys.focus_container)

To minimize the container of the current client, use `min_container`:

    awful.key({ modkey, "Shift" }, "n", leaved.keys.min_container)

*Experimental* To select and move clients around, bind `select_use_container`:

    awful.key({ modkey, "Shift" }, "u", leaved.keys.select_use_container)

Mouse actions
-------------

*Experimental*

Unfortunately different functions are needed at the moment to support shifting clients around and scaling while using a leaved layout.

Change the following under `clientbuttons` or however you set mouse button bindings for clients:

    --awful.button({ modkey }, 1, awful.mouse.client.move),
    awful.button({ modkey }, 1, leaved.mouse.move),
    --awful.button({ modkey }, 3, awful.mouse.client.resize))
    awful.button({ modkey }, 3, leaved.mouse.resize))

TODO
----

This project is incomplete, there are a ~~couple~~ a lot of things missing and just as many bugs

* Best way to hide non selected tab?
* Complete visual mode (e.g. labeling)
* Add more using containers support
* Add mouse scaling support
* Add replacing node with new window
* Switch tile.lua back to using full tree support not hacked up version
* And more

Bugs
----

* Properly clean up on layout switch
* Couple bugs with client size minimums, figure out better resizing rules
* A couple display bugs after redrawing
