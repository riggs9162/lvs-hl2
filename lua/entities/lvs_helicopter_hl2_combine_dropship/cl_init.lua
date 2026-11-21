include("shared.lua")
include("cl_sounds.lua")

--- Push of the rotor at which the body is bent all the way, in the original's units per think.
local FIN_FULL_FORCE = 60

--- Share of its full bend the body moves per second, a tenth on every original think.
local FIN_RATE = 1

--- Downward push of gravity per original think.
local GRAVITY_PER_TICK = 38.4

--- Eases a value into the range of -1 to 1 along an S-curve, from SimpleSplineRemapVal with a range of -FIN_FULL_FORCE to FIN_FULL_FORCE.
---@param value number
---@return number blend
local function FinBlend(value)
    local fraction = math.Clamp((value + FIN_FULL_FORCE) / (2 * FIN_FULL_FORCE), 0, 1)

    return -1 + 2 * fraction * fraction * (3 - 2 * fraction)
end

--- Bends the body with how hard the rotor pushes along and across the dropship's movement, and tucks in its back end while it lands, on every frame, from the end of CNPC_CombineDropship::Flight.
function ENT:AnimBody()
    local deltatime = RealFrameTime()
    local force = self:GetRotorForce()
    local impulse = self:GetUp() * force

    impulse.z = impulse.z - GRAVITY_PER_TICK

    local accelDir = impulse:GetNormalized()
    local velocityDir = self:GetVelocity():GetNormalized()
    local right = self:GetRight()

    accelDir.z = 0
    velocityDir.z = 0
    right.z = 0

    local finSpeed = force * velocityDir:Dot(accelDir)
    local swaySpeed = force * velocityDir:Dot(right)

    if ( self:GetDeploying() ) then
        finSpeed = -FIN_FULL_FORCE
    end

    self.bodyAccel = math.Approach(self.bodyAccel or 0, FinBlend(finSpeed), FIN_RATE * deltatime)
    self.bodySway = math.Approach(self.bodySway or 0, FinBlend(swaySpeed), FIN_RATE * deltatime)

    local bCargo = IsValid(self:GetCargo())
    local accelPose = bCargo and "cargo_body_accel" or "body_accel"
    local swayPose = bCargo and "cargo_body_sway" or "body_sway"

    self:SetPoseParameter(bCargo and "body_accel" or "cargo_body_accel", 0)
    self:SetPoseParameter(bCargo and "body_sway" or "cargo_body_sway", 0)
    self:SetPoseParameter(accelPose, self.bodyAccel)
    self:SetPoseParameter(swayPose, self.bodySway)
    self:InvalidateBoneCache()
end

function ENT:OnFrame()
    self:AnimBody()
    self:UpdateDropshipSounds()
end

function ENT:OnRemoved()
    self:StopDropshipSounds()
end
