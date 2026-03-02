local iui      --- @type IUILib
local system   --- @type LovrIUISystem
local graphics --- @type LovrIUIGraphics
local input    --- @type LovrIUIVRInput

--- @class (exact) IUIWorldWindowProps
--- @field center? Vec3 Defaults to { x = 0, y = 1.5, z = -1 }
--- @field rotation? Quat Defaults to { 0, 0, 0, 1 }
--- @field ppm? number Defaults to 1000
--- @field w? number Defaults to 1280
--- @field h? number Defaults to 720

--- @class LovrIUIWorldWindow
--- @field context IUIRootContext The root context the window operates in
--- @field center Vec3 The center of the window, in worldspace
--- @field rotation Quat The direction the window is facing
--- @field ppm number The scale of the window, in points per meter
--- @field w number The width of the window, in points
--- @field h number The height of the window, in points
local WorldWindow = {}
WorldWindow.__index = WorldWindow

--- @param lib IUILib
--- @param backend LovrIUIBackend
function WorldWindow.load(lib, backend)
    iui = lib
    system = backend.system
    graphics = backend.graphics
    input = backend.input
end

--- @param props? IUIWorldWindowProps
--- @return LovrIUIWorldWindow
function WorldWindow.new(props)
    props = props or {}

    --- @type LovrIUIWorldWindow
    local output = {
        context = iui.newRootContext(),
        center = props.center or Vec3(0, 1.5, -1),
        rotation = props.rotation or Quat(),
        ppm = props.ppm or 1000,
        w = props.w or 1280,
        h = props.h or 720,
    }
    setmetatable(output, WorldWindow)

    return output
end

--- @param x number
--- @param y number
--- @return number insideAmount
function WorldWindow:fuzzyInside(x, y)
    local overflow = 60
    local inside = 1

    local closestX = iui.utils.clamp(x, 0, self.w)
    local closestY = iui.utils.clamp(y, 0, self.h)
    local dx, dy = closestX - x, closestY - y
    local d = math.sqrt(dx * dx + dy * dy)

    inside = iui.utils.clamp(1 - d / overflow, 0, 1)

    return inside
end

function WorldWindow:recenter()
    local headPos = vec3(lovr.headset.getPosition("head"))
    local headDir = vec3(lovr.headset.getDirection("head"))
    local targetPos = headPos + (headDir * 1)

    local yaw = math.atan2(-headDir[1], -headDir[3])
    local pitch = -math.asin(-headDir[2])

    self.center = Vec3(targetPos)
    self.rotation = Quat(quat():setEuler(pitch, yaw, 0))
end

--- @return boolean
function WorldWindow:beginFrame()
    iui.setRootContext(self.context)
    self.context:beginFrame()
    iui.beginWindow(self.w, self.h)
    input.beginWindow(self)

    return true
end

function WorldWindow:endFrame()
    input.endWindow(self)
    iui.endWindow()
    self.context:endFrame()
end

--- @param pass Pass
function WorldWindow:draw(pass)
    graphics.setWindow(self)
    graphics.pass = pass

    pass:push()

    -- pass:setDepthOffset(-100, 0)
    -- pass:setDepthWrite(false)
    -- pass:setDepthTest()
    pass:setMaterial()
    pass:translate(self.center)
    pass:rotate(self.rotation)
    pass:scale(1 / self.ppm)
    pass:translate(-self.w / 2, -self.h / 2, 0)

    -- Backface
    pass:setDepthTest("gequal")
    pass:setDepthWrite(true)
    pass:setColor(1, 1, 1, 0.5)
    pass:setFaceCull("front")
    pass:roundrect(
        self.w / 2, self.h / 2, 0,
        self.w, self.h, 0,
        0, 0, 0, 0,
        iui.style["vrWindowCornerRadius"]
    )
    pass:setFaceCull()

    -- Widgets do not write depth
    pass:setDepthWrite(false)
    pass:setFaceCull("back")

    iui.setRootContext(self.context)
    iui.draw()

    -- pass:setDepthOffset(0, 0)
    input.draw(pass, self)

    -- Front depth face
    pass:setDepthWrite(true)
    pass:setColorWrite(false)
    pass:roundrect(
        self.w / 2, self.h / 2, 0,
        self.w, self.h, 0,
        0, 0, 0, 0,
        iui.style["vrWindowCornerRadius"]
    )
    pass:setColorWrite(true)

    pass:setFaceCull()

    pass:pop()
end

return WorldWindow
