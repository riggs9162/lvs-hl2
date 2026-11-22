include("shared.lua")
include("lvs_hl2/cl_engine_sounds.lua")

ENT.EngineSoundFolder = "lvs/hl2/cars/brickade"

-- rest height of the wheel centers in local space, taken from the models bind pose
local WHEEL_REST_HEIGHT = -12

local manipulatePos = Vector()
local manipulateAng = Angle()

function ENT:GetAxleWheels()
    if ( self.axleWheels ) then return self.axleWheels end

    local wheels = {front = {}, rear = {}}
    for _, wheel in ipairs(ents.FindByClass("lvs_wheeldrive_wheel")) do
        if ( wheel:GetBase() != self ) then continue end

        local localPos = self:WorldToLocal(wheel:GetPos())
        local axle = localPos.x > 0 and wheels.front or wheels.rear

        -- store left wheel first so the axle roll direction is consistent
        if ( localPos.y > 0 ) then
            table.insert(axle, 1, wheel)
        else
            table.insert(axle, wheel)
        end
    end

    if ( #wheels.front != 2 or #wheels.rear != 2 ) then return end

    self.axleWheels = wheels
    return wheels
end

function ENT:UpdateTransmissionBone(boneId, axle)
    if ( !boneId ) then return end

    local wheelLeft, wheelRight = axle[1], axle[2]
    if ( !IsValid(wheelLeft) or !IsValid(wheelRight) ) then self.axleWheels = nil return end

    local offsetLeft = self:WorldToLocal(wheelLeft:GetPos()).z - WHEEL_REST_HEIGHT
    local offsetRight = self:WorldToLocal(wheelRight:GetPos()).z - WHEEL_REST_HEIGHT

    local avgZ = (offsetLeft + offsetRight) * 0.5
    local diff = offsetRight - offsetLeft

    manipulatePos.x = 0
    manipulatePos.y = 0
    manipulatePos.z = avgZ

    manipulateAng.p = -diff
    manipulateAng.y = 0
    manipulateAng.r = 0

    self:ManipulateBonePosition(boneId, manipulatePos)
    self:ManipulateBoneAngles(boneId, manipulateAng)
end

function ENT:UpdatePoseParameters(steer, speed_kmh, engine_rpm, throttle, brake, handbrake, clutch, gear, temperature, fuel, oil, ammeter)
    self:SetPoseParameter("vehicle_steer", steer)
    self:SetPoseParameter("vehicle_guage", math.Clamp(speed_kmh / 366, 0, 1))
    self:SetPoseParameter("vehicle_tacho", math.Clamp(engine_rpm / self.EngineMaxRPM, 0, 1))

    if ( !self.transBoneF ) then
        self.transBoneF = self:LookupBone("transmission_f")
        self.transBoneR = self:LookupBone("transmission_r")
    end

    local wheels = self:GetAxleWheels()
    if ( wheels ) then
        self:UpdateTransmissionBone(self.transBoneF, wheels.front)
        self:UpdateTransmissionBone(self.transBoneR, wheels.rear)
    end

    -- light up the model's light meshes to match the light handler state
    local lights = self:GetLightsHandler()
    if ( IsValid(lights) ) then
        local bLightsOn = lights:GetActive()
        self:SetBodygroup(1, bLightsOn and 1 or 0)
        self:SetBodygroup(2, bLightsOn and 1 or 0)
        self:SetBodygroup(3, brake > 0 and 1 or 0)

        local turnMode = self:GetTurnMode()
        local bFlash = self:GetTurnFlasher()
        self:SetBodygroup(4, (bFlash and (turnMode == 2 or turnMode == 3)) and 1 or 0)
        self:SetBodygroup(5, (bFlash and (turnMode == 1 or turnMode == 3)) and 1 or 0)
    end

    self:EngineSoundsThink()
end
