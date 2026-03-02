# LÖVR-IUI

A LÖVR backend for the [IUI](https://github.com/DonaldHays/iui) immediate mode
GUI library.

## Installation

This library provides the backend for [IUI](https://github.com/DonaldHays/iui)
for use in LÖVR projects. Both `iui` and `lovr-iui` must be added to your LÖVR
project.

If you are using the desktop idiom, you must also include the
[lovr-mouse](https://github.com/bjornbytes/lovr-mouse) library in your project.

## Minimal Desktop Sample

### conf.lua
```lua
function lovr.conf(t)
    t.modules.headset = nil
end
```

### main.lua
```lua
local iui = require "iui"
local backend = require "lovr-iui"
local mouse = require "lovr-mouse"

local labelText = "Click the button!"

function lovr.load()
    backend.mouse = mouse

    iui.load(backend)
end

function lovr.update(dt)
    iui.beginFrame(dt)
    iui.beginWindow(lovr.system.getWindowDimensions())

    iui.panelBackground()
    iui.label(labelText)
    if iui.button("Say Hello") then
        labelText = "Hello, World!"
    end

    iui.endWindow()
    iui.endFrame()
end

function lovr.draw(pass)
    backend.graphics.pass = pass

    iui.draw()
end

function lovr.mousemoved(x, y, dx, dy)
    backend.mousemoved(x, y, dx, dy)
end

function lovr.mousepressed(x, y, button)
    backend.mousepressed(x, y, button)
end

function lovr.mousereleased(x, y, button)
    backend.mousereleased(x, y, button)
end

function lovr.wheelmoved(x, y)
    backend.wheelmoved(x, y)
end

function lovr.keypressed(key, scancode, isRepeat)
    backend.keypressed(key, scancode, isRepeat)
end

function lovr.keyreleased(key, scancode)
    backend.keyreleased(key, scancode)
end

function lovr.textinput(text)
    backend.textinput(text)
end
```

## Minimal VR Sample
