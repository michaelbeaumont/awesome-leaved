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
    
Add `leaved` to the `layouts` table in rc.lua

Keybindings
-----------

There are a couple of available keybindings.
To switch the orientation of the current container use `horizontalize` and `verticalize`.

    awful.key({ modkey }, "h", leaved.horizontalize),
    awful.key({ modkey }, "v", leaved.verticalize),

To switch between no tabs, tabs and stack use `reorder`

    awful.key({ modkey, "Shift" }, "t", leaved.reorder),


To scale windows there are two options, use vertical and horizontal scaling and include the percentage points to scale as an argument:

    awful.key({ modkey, "Shift" }, "]", leaved.vscale(-5)),
    awful.key({ modkey, "Shift" }, "[", leaved.vscale(5)),
    awful.key({ modkey }, "]", leaved.hscale(-5)),
    awful.key({ modkey }, "[", leaved.hscale(5))

Or scale based on the focused client and its opposite direction:

    awful.key({ modkey, "Shift" }, "]", leaved.oppositeScale(-5)),
    awful.key({ modkey, "Shift" }, "[", leaved.oppositeScale(5)),
    awful.key({ modkey }, "]", leaved.focusedScale(-5)),
    awful.key({ modkey }, "[", leaved.focusedScale(5))

`focusedScale` will always make the current client bigger or smaller in its container and `oppositeScale` will always scale in the opposing direction.

TODO
----

This project is incomplete, there are a couple (a lot of) things missing and just as many bugs

* Properly track last focused node for subcontainers
* Add ability to swap clients/containers. My current plan is to show transparent numbers over all windows and wait for a choice, pentadactyl style
* Honor client size minimums
* Add mouse scaling support
* Add client focusing with respect to containers, i.e. rotate through siblings of the focused client
* And more

Bugs
----

* Spacing between clients can be a bit uneven, not sure yet exactly why this is happening.
* Trying to switch to a container by clicking on the tab will not work, this is on the todo
* Properly clean up on layout switch
