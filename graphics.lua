local iui                           --- @type IUILib

local colorClipShader               --- @type Shader
local fontClipShader                --- @type Shader
local imageClipShader               --- @type Shader
local imageUnclippedShader          --- @type Shader
local msdfImageClipShader           --- @type Shader
local msdfImageUnclippedShader      --- @type Shader

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

--- @alias LovrIUIShaderName "color" | "font" | "image" | "msdf"

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
    elseif shader == "msdf" then
        if currentClip then
            targetShader = msdfImageClipShader
        else
            targetShader = msdfImageUnclippedShader
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
        elseif shader == "msdf" then
            graphics.pass:send("msdfSampler", targetSampler)
        end
    end

    if isFilterDirty then
        if shader == "image" then
            graphics.pass:send("useAAUV", currentImageFilter == "smooth")
            graphics.pass:send("imageSampler", targetSampler)
        elseif shader == "msdf" then
            graphics.pass:send("msdfSampler", targetSampler)
        end
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

    msdfImageClipShader = lovr.graphics.newShader(
        backend.resourcePath .. "shaders/ui-clip.glsl",
        backend.resourcePath .. "shaders/ui-msdf.glsl"
    )

    msdfImageUnclippedShader = lovr.graphics.newShader(
        "unlit",
        backend.resourcePath .. "shaders/ui-msdf.glsl"
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

    local pass = graphics.pass

    pass:setShader()
    pass:setMaterial()

    if iui.idiom == "desktop" then
        pass:push()
        pass:setDepthTest()

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

function graphics.nineSlice(nineSlice, filter, x, y, w, h)
    local image = nineSlice.image --- @type Texture

    local iw, ih = image:getDimensions()

    local l, t, r, b = nineSlice.l, nineSlice.t, nineSlice.r, nineSlice.b
    local uvl, uvt, uvr, uvb = l / iw, t / ih, (iw - r) / iw, (ih - b) / ih
    local wh = windowHeight

    local mesh = lovr.graphics.newMesh(
        {
            { "VertexPosition", "vec2" },
            { "VertexUV",       "vec2" },
        },
        {
            { x,         wh - (y),         0,   0 },
            { x + l,     wh - (y),         uvl, 0 },
            { x + w - r, wh - (y),         uvr, 0 },
            { x + w,     wh - (y),         1,   0 },

            { x,         wh - (y + t),     0,   uvt },
            { x + l,     wh - (y + t),     uvl, uvt },
            { x + w - r, wh - (y + t),     uvr, uvt },
            { x + w,     wh - (y + t),     1,   uvt },

            { x,         wh - (y + h - b), 0,   uvb },
            { x + l,     wh - (y + h - b), uvl, uvb },
            { x + w - r, wh - (y + h - b), uvr, uvb },
            { x + w,     wh - (y + h - b), 1,   uvb },

            { x,         wh - (y + h),     0,   1 },
            { x + l,     wh - (y + h),     uvl, 1 },
            { x + w - r, wh - (y + h),     uvr, 1 },
            { x + w,     wh - (y + h),     1,   1 },
        }
    )

    mesh:setIndices({
        1, 5, 2, 2, 5, 6,
        2, 6, 3, 3, 6, 7,
        3, 7, 4, 4, 7, 8,

        5, 9, 6, 6, 9, 10,
        6, 10, 7, 7, 10, 11,
        7, 11, 8, 8, 11, 12,

        9, 13, 10, 10, 13, 14,
        10, 14, 11, 11, 14, 15,
        11, 15, 12, 12, 15, 16,
    })

    setFilter(filter)
    setShader("image")

    graphics.pass:setMaterial(image)

    graphics.pass:draw(mesh)
    graphics.pass:setMaterial()
end

function graphics.msdfImage(image, x, y, w, h)
    setFilter("linear")
    setShader("msdf")
    graphics.pass:setMaterial(image)
    graphics.pass:plane(x + w * 0.5, windowHeight - (y + h * 0.5), 0, w, h)
    graphics.pass:setMaterial()
end

return graphics
