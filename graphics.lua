local iui                           --- @type IUILib

local colorClipShader               --- @type Shader
local fontClipShader                --- @type Shader
local imageClipShader               --- @type Shader
local imageUnclippedShader          --- @type Shader

local nearestImageSampler           --- @type Sampler
local linearImageSampler            --- @type Sampler

local currentImageFilter = "linear" --- @type IUIImageFilter
local currentShader = nil           --- @type Shader?
local isFilterDirty = false         --- @type boolean
local isClipDirty = false           --- @type boolean
local currentClip = nil             --- @type number[]?

local currentWindow                 --- @type LovrIUIWorldWindow
local windowWidth                   --- @type number
local windowHeight                  --- @type number

--- @alias LovrIUIShaderName "color" | "font" | "image"

--- @class LovrIUIGraphics: IUIGraphicsBackend
--- @field pass Pass
local graphics = {}

--- @param shader LovrIUIShaderName
local function setShader(shader)
    local targetShader = nil --- @type Shader?
    if shader == "color" then
        if currentClip then
            targetShader = colorClipShader
        end
    elseif shader == "font" then
        if currentClip then
            targetShader = fontClipShader
        end
    elseif shader == "image" then
        if currentClip then
            targetShader = imageClipShader
        else
            targetShader = imageUnclippedShader
        end
    end

    local targetSampler = linearImageSampler

    if currentImageFilter == "nearest" then
        targetSampler = nearestImageSampler
    end

    if targetShader ~= currentShader then
        graphics.pass:setShader(targetShader --[[@as any]])
        currentShader = targetShader

        if shader == "image" then
            graphics.pass:send("useAAUV", currentImageFilter == "smooth")
            graphics.pass:send("imageSampler", targetSampler)
            isFilterDirty = false
        end
    end

    if isFilterDirty then
        graphics.pass:send("useAAUV", currentImageFilter == "smooth")
        graphics.pass:send("imageSampler", targetSampler)
        isFilterDirty = false
    end

    if currentShader and currentClip and isClipDirty then
        local windowCenter = currentWindow.center

        isClipDirty = false

        local left = currentClip[1]
        local top = currentClip[2]
        local right = left + currentClip[3]
        local bottom = top + currentClip[4]

        left = (left - (currentWindow.w / 2)) / currentWindow.ppm
        top = -(top - (currentWindow.h / 2)) / currentWindow.ppm
        right = (right - (currentWindow.w / 2)) / currentWindow.ppm
        bottom = -(bottom - (currentWindow.h / 2)) / currentWindow.ppm

        local q = currentWindow.rotation

        local leftDir = vec3(1, 0, 0):rotate(q)
        local topDir = vec3(0, -1, 0):rotate(q)
        local rightDir = vec3(-1, 0, 0):rotate(q)
        local bottomDir = vec3(0, 1, 0):rotate(q)

        local topLeftVector = vec3(left, top, 0)
        local bottomRightVector = vec3(right, bottom, 0)

        topLeftVector = topLeftVector:rotate(q)
        bottomRightVector = bottomRightVector:rotate(q)

        topLeftVector = topLeftVector + windowCenter
        bottomRightVector = bottomRightVector + windowCenter

        graphics.pass:send("ClipPlanes", {
            centers = {
                topLeftVector,
                topLeftVector,
                bottomRightVector,
                bottomRightVector,
            },
            directions = {
                leftDir,
                topDir,
                rightDir,
                bottomDir,
            }
        })
    end
end

--- @param clip number[]?
local function setClip(clip)
    if clip ~= nil then
        if currentClip == nil then
            isClipDirty = true
        else
            for i = 1, #clip do
                if clip[i] ~= currentClip[i] then
                    isClipDirty = true
                    break
                end
            end
        end
    end

    currentClip = clip
end

--- @param filter IUIImageFilter
local function setFilter(filter)
    if filter ~= currentImageFilter then
        currentImageFilter = filter
        isFilterDirty = true
    end
end

--- @param lib IUILib
--- @param backend LovrIUIBackend
function graphics.load(lib, backend)
    iui = lib

    colorClipShader = lovr.graphics.newShader(
        backend.resourcePath .. "shaders/ui-clip.glsl", "unlit"
    )

    fontClipShader = lovr.graphics.newShader(
        backend.resourcePath .. "shaders/ui-clip.glsl", "font"
    )

    imageClipShader = lovr.graphics.newShader(
        backend.resourcePath .. "shaders/ui-clip.glsl",
        backend.resourcePath .. "shaders/ui-image.glsl"
    )

    imageUnclippedShader = lovr.graphics.newShader(
        "unlit",
        backend.resourcePath .. "shaders/ui-image.glsl"
    )

    nearestImageSampler = lovr.graphics.newSampler {
        wrap = { "clamp", "clamp", "clamp" },
        filter = { "nearest", "nearest", "linear" },
    }

    linearImageSampler = lovr.graphics.newSampler {
        wrap = { "clamp", "clamp", "clamp" },
    }
end

--- @param window LovrIUIWorldWindow
function graphics.setWindow(window)
    currentWindow = window
end

function graphics.beginDraw(width, height)
    windowWidth = width
    windowHeight = height
    currentImageFilter = "linear"
    currentShader = nil
    currentClip = nil
    isFilterDirty = false
    isClipDirty = false

    if iui.idiom == "desktop" then
        local pass = graphics.pass

        pass:push()
        pass:setDepthTest()
        pass:setMaterial()

        pass:setViewPose(1, mat4():identity(), false)
        pass:setProjection(1, mat4():orthographic(
            0, windowWidth, windowHeight, 0, -10, 10)
        )
    end
end

function graphics.endDraw()
    if iui.idiom == "desktop" then
        graphics.pass:pop()
    end

    graphics.pass:setShader()
end

function graphics.newFont(size, hinting, dpiscale)
    local baseFontSize = 32
    local font = lovr.graphics.newFont(baseFontSize)
    font:setPixelDensity(baseFontSize / size)
    return font
end

--- @param image Texture
function graphics.getImageDimensions(image)
    return image:getDimensions()
end

function graphics.clip(x, y, w, h)
    if iui.idiom == "desktop" then
        if x then
            local wx, wy, ww, wh = 0, 0, windowWidth, windowHeight
            local wmx, wmy = wx + ww, wy + wh
            local mx, my = x + w, y + h

            local dminX, dminY = math.max(x, wx), math.max(y, wy)
            local dmaxX, dmaxY = math.min(mx, wmx), math.min(my, wmy)
            local dx, dy, dw, dh = dminX, dminY, dmaxX - dminX, dmaxY - dminY

            if dx < 0 or dy < 0 or dw < 0 or dh < 0 then
                graphics.pass:setScissor(0, 0, 0, 0)
            else
                local dpi = lovr.system.getWindowDensity()
                graphics.pass:setScissor(dx * dpi, dy * dpi, dw * dpi, dh * dpi)
            end
        else
            graphics.pass:setScissor()
        end
    else
        if x then
            setClip({ x, y, w, h })
        else
            setClip(nil)
        end
    end
end

function graphics.setColor(r, g, b, a)
    graphics.pass:setColor(r, g, b, a)
end

function graphics.rectangle(x, y, w, h, rx, ry)
    setShader("color")
    if (rx or 0) == 0 and (ry or 0) == 0 then
        graphics.pass:setBlendMode()
    end
    graphics.pass:roundrect(x + w * 0.5, windowHeight - (y + h * 0.5), 0, w, h, 0, 0, 0, 0, 0, rx)
    graphics.pass:setBlendMode("alpha", "alphamultiply")
end

function graphics.circle(x, y, r)
    setShader("color")
    graphics.pass:circle(x, windowHeight - y, 0, r)
end

function graphics.setFont(f)
    graphics.pass:setFont(f)
end

function graphics.print(s, x, y)
    setShader("font")
    graphics.pass:text(s, x, windowHeight - y, 0, 1, 0, 0, 1, 0, 0, "left", "top")
end

--- @param image Texture
function graphics.image(image, filter, x, y, w, h)
    setFilter(filter)
    setShader("image")
    graphics.pass:setMaterial(image)
    graphics.pass:plane(x + w * 0.5, windowHeight - (y + h * 0.5), 0, w, h)
    graphics.pass:setMaterial()
end

return graphics
