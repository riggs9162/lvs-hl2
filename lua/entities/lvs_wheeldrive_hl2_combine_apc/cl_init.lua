include("shared.lua")
include("cl_sounds.lua")

--- How fast the rear doors swing, as the share of their full travel per second.
local REAR_DOORS_SPEED = 1.6

--- Where the lamp of the troop bay hangs, under the middle of its ceiling.
local TROOP_BAY_LIGHT = Vector(-70, 0, 84)

function ENT:UpdatePoseParameters(steer, speed_kmh, engine_rpm, throttle, brake, handbrake, clutch, gear, temperature, fuel, oil, ammeter)
    self:SetPoseParameter("vehicle_steer", steer)
    self:UpdateHL2EngineSound(throttle)
end

--- Swings the rear doors towards open while troops climb in or out, and shut again after.
function ENT:UpdateRearDoors()
    if ( !self.GetRearDoorsOpenUntil ) then return end

    local now = RealTime()
    local delta = now - (self.RearDoorsUpdated or now)
    self.RearDoorsUpdated = now

    local target = self:GetRearDoorsOpenUntil() > CurTime() and 1 or 0
    self.RearDoors = math.Approach(self.RearDoors or 0, target, delta * REAR_DOORS_SPEED)

    self:SetPoseParameter("vehicle_rear_doors", self.RearDoors)
end

--- Whether the local player rides in the troop bay and looks out of their own eyes.
---@return boolean
function ENT:IsViewedFromTroopBay()
    local client = LocalPlayer()
    local vehicle = client:GetVehicle()
    if ( !IsValid(vehicle) or client:lvsGetVehicle() != self or self:GetDriver() == client ) then return false end

    return !vehicle:GetThirdPersonMode()
end

--- Lights the troop bay for the troops riding in it.
function ENT:DrawTroopBayLight()
    if ( !system.HasFocus() or !self:IsViewedFromTroopBay() ) then return end

    local light = DynamicLight(self:EntIndex(), true)
    if ( !light ) then return end

    light.pos = self:LocalToWorld(TROOP_BAY_LIGHT)
    light.r = 140
    light.g = 200
    light.b = 50
    light.brightness = 2
    light.size = 128
    light.decay = 1000
    light.dietime = CurTime() + 1
end

function ENT:Draw()
    if ( self:GetHornEnabled() ) then
        if ( !self.HornSound ) then
            self.HornSound = CreateSound(self, "ambient/alarms/apc_alarm_loop1.wav")
            self.HornSound:SetSoundLevel(80)
        elseif ( !self.HornSound:IsPlaying() ) then
            self.HornSound:Play()
        end
    else
        if ( self.HornSound ) then
            self.HornSound:FadeOut(1)
            self.HornSound = nil
        end
    end

    self:UpdateRearDoors()
    self:DrawModel()
    self:DrawTroopBayLight()
end

function ENT:OnRemoved()
    self:StopHL2EngineSound()
end
