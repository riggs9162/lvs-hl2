include("shared.lua")
include("lvs_hl2/cl_engine_sounds.lua")

ENT.EngineSoundFolder = "lvs/hl2/cars/ifv"

-- radius of the wheel meshes baked into the model, used to match the spin rate to ground speed
local VISUAL_WHEEL_RADIUS = 22

-- rest heights of the wheel centers in local space, sorted front to rear, taken from the models bind pose
local suspensionRestHeights = {24, 23, 23}

local suspensionPoseParameters = {
    [1] = {"suspension_left_1", "suspension_left_2", "suspension_left_3"},
    [-1] = {"suspension_right_1", "suspension_right_2", "suspension_right_3"},
}

function ENT:GetSideWheels()
    if ( self.sideWheels ) then return self.sideWheels end

    local wheels = {[1] = {}, [-1] = {}}
    for _, wheel in ipairs(ents.FindByClass("lvs_wheeldrive_wheel")) do
        if ( wheel:GetBase() != self ) then continue end

        local side = self:WorldToLocal(wheel:GetPos()).y > 0 and 1 or -1
        table.insert(wheels[side], wheel)
    end

    if ( #wheels[1] != 3 or #wheels[-1] != 3 ) then return end

    -- sort each side front to rear so the index matches the suspension pose parameters
    for _, sideWheels in pairs(wheels) do
        table.sort(sideWheels, function(a, b) return self:WorldToLocal(a:GetPos()).x > self:WorldToLocal(b:GetPos()).x end)
    end

    self.sideWheels = wheels
    return wheels
end

function ENT:UpdatePoseParameters(steer, speed_kmh, engine_rpm, throttle, brake, handbrake, clutch, gear, temperature, fuel, oil, ammeter)
    self:SetPoseParameter("vehicle_steer", steer)

    local wheels = self:GetSideWheels()
    if ( wheels ) then
        for side, sideWheels in pairs(wheels) do
            for i, wheel in ipairs(sideWheels) do
                if ( !IsValid(wheel) ) then self.sideWheels = nil return end

                local localHeight = self:WorldToLocal(wheel:GetPos()).z
                local extension = math.Clamp(suspensionRestHeights[i] - localHeight, -4, 4)
                self:SetPoseParameter(suspensionPoseParameters[side][i], extension)
            end
        end
    end

    -- spin the wheels from actual ground velocity so they hold still when parked
    local forwardVelocity = self:GetVelocity():Dot(self:GetForward())
    if ( math.abs(forwardVelocity) > 1 ) then
        local spin = (self.wheelSpin or 0) + (forwardVelocity / VISUAL_WHEEL_RADIUS) * 57.2958 * FrameTime()
        spin = (spin + 180) % 360 - 180
        self.wheelSpin = spin
        self:SetPoseParameter("spin_wheels_left", spin)
        self:SetPoseParameter("spin_wheels_right", spin)
    end

    self:EngineSoundsThink()
end
