local iui --- @type IUILib

local currentPath = (...):gsub('%.init$', '') .. "."
local resourcePath = currentPath:gsub("%.", "/")

--- @type LovrIUISystem
local system = require(currentPath .. "system")

--- @type LovrIUIGraphics
local graphics = require(currentPath .. "graphics")

--- @type LovrIUIWorldWindow
local worldWindow = require(currentPath .. "world-window")

--- @type LovrIUIVRInput
local input = require(currentPath .. "vr-input")

local desktopRootContext --- @type IUIRootContext

--- @class LovrIUIBackend: IUIBackend
--- @field mouse any
local backend = {
    graphics = graphics,
    system = system,
    resourcePath = resourcePath,
    worldWindow = worldWindow,
    input = input,
}

function backend.config(config)
    if not config.idiom then
        if lovr.headset then
            config.idiom = "vr"
        else
            config.idiom = "desktop"
        end
    end

    if not config.detail then
        if config.idiom == "vr" then
            config.detail = "high"
        else
            if lovr.system.getWindowDensity() > 1 then
                config.detail = "high"
            else
                config.detail = "low"
            end
        end
    end
end

function backend.load(lib)
    iui = lib

    system.load(lib, backend)
    graphics.load(lib, backend)
    input.load(lib, backend)
    worldWindow.load(lib, backend)

    if iui.idiom == "desktop" then
        desktopRootContext = iui.newRootContext()
        iui.setRootContext(desktopRootContext)
    end
end

--- @param dt number
function backend.beginFrame(dt)
    if iui.idiom == "desktop" then
        desktopRootContext:beginFrame()
    elseif iui.idiom == "vr" then
        input.beginFrame(dt)
    end
end

function backend.endFrame()
    if iui.idiom == "desktop" then
        desktopRootContext:endFrame()
    elseif iui.idiom == "vr" then
        input.endFrame()
    end
end

--- @param x number
--- @param y number
--- @param dx number
--- @param dy number
function backend.mousemoved(x, y, dx, dy)
    iui.input.mouse("move", 0, x, y, dx, dy)
end

--- @param x number
--- @param y number
--- @param button number
function backend.mousepressed(x, y, button)
    iui.input.mouse("down", button, x, y, 0, 0)
end

--- @param x number
--- @param y number
--- @param button number
function backend.mousereleased(x, y, button)
    iui.input.mouse("up", button, x, y, 0, 0)
end

--- @param x number
--- @param y number
function backend.wheelmoved(x, y)
    iui.input.mouse("scroll", 0, 0, 0, x, y)
end

--- @param key KeyCode
--- @param scancode number
--- @param isRepeat boolean
function backend.keypressed(key, scancode, isRepeat)
    iui.input.keyboard("down", key, isRepeat)
end

--- @param key KeyCode
--- @param scancode number
function backend.keyreleased(key, scancode)
    iui.input.keyboard("up", key, false)
end

--- @param text string
function backend.textinput(text)
    iui.input.text(text)
end

return backend
