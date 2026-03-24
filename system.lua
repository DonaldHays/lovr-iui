local iui --- @type IUILib

local mouse

--- @param filename string
--- @return Texture
local function loadLinearTexture(filename)
    return lovr.graphics.newTexture(iui.resourcePath .. filename, {
        linear = true, mipmaps = false
    })
end

--- @class LovrIUISystem: IUISystemBackend
--- @field defaultCursor Texture
--- @field currentCursor Texture?
--- @field inactiveCursor Texture
local system = {}

--- @param lib IUILib
--- @param backend LovrIUIBackend
function system.load(lib, backend)
    iui = lib

    system.defaultCursor = loadLinearTexture("assets/cursor-default_sdf.png")
    system.inactiveCursor = loadLinearTexture("assets/cursor-inactive_sdf.png")
    system.currentCursor = system.defaultCursor

    if iui.idiom == "desktop" then
        mouse = backend.mouse

        if not mouse then
            error("Backend requires `mouse` library in desktop mode")
        end
    end
end

function system.getTimestamp()
    return lovr.timer.getTime()
end

function system.getSystemCursor(name)
    if iui.idiom == "desktop" then
        return mouse.getSystemCursor(name)
    end

    name = "assets/cursor-" .. name .. "_sdf.png"

    return loadLinearTexture(name)
end

function system.setCursor(cursor)
    if iui.idiom == "desktop" then
        mouse.setCursor(cursor)
    end

    system.currentCursor = (cursor --[[@as any]]) or system.defaultCursor
end

function system.getDPI()
    return lovr.system.getWindowDensity()
end

function system.quit()
    lovr.event.quit()
end

return system
