local iui          --- @type IUILib
local system       --- @type LovrIUISystem

local cursorShader --- @type Shader

local cursorSampler = lovr.graphics.newSampler {
    wrap = { "clamp", "clamp", "clamp" }
}

--- @class (exact) TrackedIntersection
--- @field worldPos Vec3
--- @field uiPos Vec2
--- @field dist number
--- @field fuzzyInside number
--- @field window LovrIUIWorldWindow

--- @class (exact) InputWindowSession
--- @field activeHand? Device
--- @field hadHover boolean
--- @field hadActive boolean

--- @type Device[]
local devices = {}

--- @type table<Device, TrackedIntersection[]>
local intersections = {}

--- @type table<LovrIUIWorldWindow, InputWindowSession>
local windowSessions = {}

--- @type table<LovrIUIWorldWindow, InputWindowSession>
local newWindowSessions = {}

--- @type table<Device, LovrIUIWorldWindow>
local hoveredWindows = {}

--- @param rayPos Vec3
--- @param rayDir Vec3
--- @param planePos Vec3
--- @param planeDir Vec3
--- @return Vec3? intersection, number distance
local function raycast(rayPos, rayDir, planePos, planeDir)
    local dot = rayDir:dot(planeDir)
    -- Reject glancing rays, and rays coming from behind the plane.
    if dot >= -0.001 then
        return nil, 0
    else
        --- @type number
        local distance = (planePos - rayPos):dot(planeDir) / dot
        if distance > 0 then
            return rayPos + rayDir * distance, distance
        else
            return nil, 0
        end
    end
end

--- @class LovrIUIVRInput
local input = {}

--- @param lib IUILib
--- @param backend LovrIUIBackend
function input.load(lib, backend)
    iui = lib

    system = backend.system

    if iui.idiom == "vr" then
        cursorShader = lovr.graphics.newShader(
            "font", backend.resourcePath .. "shaders/ui-msdf.glsl"
        )

        devices = {
            "hand/right",
            "hand/left",
        }
    end
end

--- @param dt number
function input.beginFrame(dt)
    intersections = {}
    newWindowSessions = {}
end

function input.endFrame()
    -- The window sessions table consists of only the windows we encountered
    -- this frame.
    windowSessions = newWindowSessions

    -- Buzz controllers on hover.
    for window, session in pairs(windowSessions) do
        local ctx = window.context
        local hasHover, hasActive = ctx.hoverID ~= nil, ctx.activeID ~= nil
        hasHover = hasHover or hasActive

        if session.activeHand then
            if hasHover and hasHover ~= session.hadHover then
                lovr.headset.vibrate(session.activeHand, 0.2, 0.025)
            end

            if hasActive ~= session.hadActive then
                lovr.headset.vibrate(session.activeHand, 0.4, 0.03)
            end
        end

        session.hadHover, session.hadActive = hasHover, hasActive
    end

    -- Empty the `hoveredWindows` table, but only for hands that aren't the
    -- `activeHand` of a window that has an `activeID`.
    for device, window in pairs(hoveredWindows) do
        local ctx = window.context
        local isActiveHand = false

        if ctx.activeID ~= nil then
            for _, session in pairs(windowSessions) do
                if session.activeHand == device then
                    isActiveHand = true
                    break
                end
            end
        end

        if not isActiveHand then
            hoveredWindows[device] = nil
        end
    end

    -- Update the window associated with each hand.
    for device, ints in pairs(intersections) do
        -- If this device is in `hoveredWindows`, then it's the `activeHand` of
        -- a window, so we don't change its assignment.
        if hoveredWindows[device] then
            goto continue
        end

        -- Find the closest intersection.
        local closest = ints[1]
        for _, int in ipairs(ints) do
            if int.fuzzyInside == closest.fuzzyInside then
                if int.dist < closest.dist then
                    closest = int
                end
            elseif int.fuzzyInside > closest.fuzzyInside then
                closest = int
            end
        end

        -- Assign the hand to the window
        hoveredWindows[device] = closest.window

        ::continue::
    end
end

--- @param window LovrIUIWorldWindow
function input.beginWindow(window)
    --- @type InputWindowSession
    local session = windowSessions[window] or {
        hadHover = false,
        hadActive = false,
    }

    newWindowSessions[window] = session

    local center = window.center
    local rotation = window.rotation

    for _, device in ipairs(devices) do
        if lovr.headset.isTracked(device) then
            local rayPos = vec3(lovr.headset.getPosition(device .. '/point'))
            local rayDir = vec3(lovr.headset.getDirection(device .. '/point'))

            local hit, dist = raycast(rayPos, rayDir, center, rotation:direction() * -1)

            local mx, my = -1, -1
            if hit then
                -- hit is in worldspace, convert to ui space
                hit = (hit - center):rotate(quat(rotation):conjugate()) * window.ppm
                mx, my = hit.x + window.w / 2, window.h * 0.5 - hit.y
                local fuzzyInside = window:fuzzyInside(mx, my)

                if fuzzyInside > 0 then
                    if hoveredWindows[device] == window then
                        local canGrabActive = iui.activeID == nil
                        canGrabActive = canGrabActive and (lovr.headset.wasPressed(device, "trigger"))

                        if session.activeHand == nil or canGrabActive then
                            session.activeHand = device
                            iui.input.mouse.resetVelocity()
                        end
                    end

                    intersections[device] = intersections[device] or {}
                    table.insert(intersections[device], {
                        worldPos = hit,
                        uiPos = Vec2(mx, my),
                        dist = dist,
                        fuzzyInside = fuzzyInside,
                        window = window,
                    })

                    mx, my = math.floor(mx), math.floor(my)
                end

                if hoveredWindows[device] ~= window and session.activeHand == device then
                    session.activeHand = nil

                    iui.input.mouse("move", 0, -100, -100, 0, 0)
                end

                if session.activeHand == device then
                    local dx = mx - iui.input.mouse.x
                    local dy = my - iui.input.mouse.y
                    iui.input.mouse("move", 0, mx, my, dx, dy)

                    if lovr.headset.wasPressed(device, "trigger") then
                        iui.input.mouse("down", 1, mx, my, 0, 0)
                    end

                    if lovr.headset.wasReleased(device, "trigger") then
                        iui.input.mouse("up", 1, mx, my, 0, 0)
                    end

                    local sx, sy = lovr.headset.getAxis(device, "thumbstick")
                    iui.input.mouse.scrollX = sx
                    iui.input.mouse.scrollY = sy

                    if window:fuzzyInside(mx, my) <= 0 then
                        if iui.activeID == nil then
                            session.activeHand = nil
                        end
                    end
                end
            end
        end
    end
end

--- @param window LovrIUIWorldWindow
function input.endWindow(window)
end

--- @param pass Pass
--- @param window LovrIUIWorldWindow
function input.draw(pass, window)
    for device, testWindow in pairs(hoveredWindows) do
        if window ~= testWindow or intersections[device] == nil then
            goto outerContinue
        end

        for _, intersection in ipairs(intersections[device]) do
            if intersection.window ~= window then
                goto innerContinue
            end

            local opacity = intersection.fuzzyInside
            if opacity > 0 then
                pass:setColor(1, 1, 1, opacity * opacity)

                local session = windowSessions[window]

                local context = window.context

                local cursor = iui.getCursor(context.cursor) or system.defaultCursor
                if session.activeHand ~= device then
                    cursor = system.inactiveCursor
                end

                if cursor then
                    local mx, my = intersection.uiPos[1], intersection.uiPos[2]

                    pass:setShader(cursorShader)
                    pass:send("msdfSampler", cursorSampler)
                    pass:draw(cursor, mx, window.h - my, 0, 32)
                    pass:setShader()
                end
            end

            ::innerContinue::
        end

        ::outerContinue::
    end
end

return input
