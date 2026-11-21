--- Engine sounds of the dropship, ported from CNPC_CombineDropship::InitializeRotorSound, UpdateRotorWashVolume, UpdateRotorSoundPitch, UpdateGroundRotorWashSound and SetLandingState: a distant rotor loop that gives way to a near one as the dropship comes closer, the roar of the rotor wash close to the ground, and the warning loop while it lands.

--- Speed of sound in units per second, as the original uses for its doppler shift.
local SPEED_OF_SOUND = 13049

--- Lowest and highest pitch of the doppler shift.
local PITCH_MIN = 50
local PITCH_MAX = 250

--- Distance up to which only the near rotor loop is heard, and beyond which only the distant one is, DROPSHIP_NEAR_SOUND_MIN_DISTANCE and DROPSHIP_NEAR_SOUND_MAX_DISTANCE.
local NEAR_SOUND_MIN_DISTANCE = 1000
local NEAR_SOUND_MAX_DISTANCE = 2500

--- Altitude up to which the rotor wash is heard fully, and beyond which it is not heard at all, DROPSHIP_GROUND_WASH_MIN_ALTITUDE and DROPSHIP_GROUND_WASH_MAX_ALTITUDE.
local GROUND_WASH_MIN_ALTITUDE = 100
local GROUND_WASH_MAX_ALTITUDE = 750

--- Volume per second the rotor loops change by, a full change taking three seconds.
local ROTOR_VOLUME_RATE = 1 / 3

--- Volume per second the rotor wash changes by, a full change taking half a second.
local GROUND_VOLUME_RATE = 2

--- Volume per second the landing warning fades in by, a full change taking 0.3 seconds.
local WARNING_VOLUME_RATE = 1 / 0.3

--- Distance below the dropship in which the ground is looked for.
local ALTITUDE_TRACE_LENGTH = 4096

--- Sound scripts of the loops.
local LOOPS = {
    rotor = "NPC_CombineDropship.RotorLoop",
    near = "NPC_CombineDropship.NearRotorLoop",
    ground = "NPC_CombineDropship.OnGroundRotorLoop",
    warning = "NPC_CombineDropship.DescendingWarningLoop",
}

--- Returns the pitch of the doppler shift between the dropship and the local player.
---@param listenerPos Vector
---@return number pitch
function ENT:GetDopplerPitch(listenerPos)
    local client = LocalPlayer()
    local dir = (listenerPos - self:GetPos()):GetNormalized()
    local listenerVelocity = client:InVehicle() and client:GetVehicle():GetVelocity() or client:GetVelocity()
    local receiver = listenerVelocity:Dot(dir)
    local transmitter = -self:GetVelocity():Dot(dir)

    return math.Clamp(100 * ((1 - receiver / SPEED_OF_SOUND) / (1 + transmitter / SPEED_OF_SOUND)), PITCH_MIN, PITCH_MAX)
end

--- Returns the height of the dropship above the ground, from CNPC_CombineDropship::GetAltitude.
---@return number altitude
function ENT:GetAltitude()
    local pos = self:GetPos()
    local trace = util.TraceLine({
        start = pos,
        endpos = pos - Vector(0, 0, ALTITUDE_TRACE_LENGTH),
        mask = MASK_SOLID_BRUSHONLY,
    })

    return ALTITUDE_TRACE_LENGTH * trace.Fraction
end

--- Moves the volume of one loop towards a target at a rate, starting the loop if needed.
---@param key string Loop name.
---@param target number Target volume.
---@param rate number Volume change per second.
---@param pitch number
function ENT:UpdateLoop(key, target, rate, pitch)
    self.dropshipLoops = self.dropshipLoops or {}

    local loop = self.dropshipLoops[key]

    if ( !loop ) then
        loop = {patch = CreateSound(self, LOOPS[key]), volume = 0}
        loop.patch:PlayEx(0, 100)
        self.dropshipLoops[key] = loop
    end

    loop.volume = math.Approach(loop.volume, target, rate * RealFrameTime())
    loop.patch:ChangeVolume(loop.volume, 0)
    loop.patch:ChangePitch(pitch, 0.1)
end

--- Runs the engine sounds of the dropship.
function ENT:UpdateDropshipSounds()
    if ( !self:GetEngineActive() and !self.dropshipLoops ) then return end

    local thrust = self:GetEngineActive() and self:GetThrottle() or 0
    local listenerPos = LocalPlayer():EyePos()
    local distance = math.Clamp(listenerPos:Distance(self:GetPos()), NEAR_SOUND_MIN_DISTANCE, NEAR_SOUND_MAX_DISTANCE)
    local nearFactor = math.Remap(distance, NEAR_SOUND_MIN_DISTANCE, NEAR_SOUND_MAX_DISTANCE, 1, 0)
    local groundFactor = math.Clamp(math.Remap(self:GetAltitude(), GROUND_WASH_MIN_ALTITUDE, GROUND_WASH_MAX_ALTITUDE, 1, 0), 0, 1)
    local pitch = self:GetDopplerPitch(listenerPos) + 0.2 + thrust * 0.8

    self:UpdateLoop("rotor", thrust * (1 - nearFactor), ROTOR_VOLUME_RATE, pitch)
    self:UpdateLoop("near", thrust * nearFactor, ROTOR_VOLUME_RATE, pitch)
    self:UpdateLoop("ground", thrust * groundFactor, GROUND_VOLUME_RATE, pitch)
    self:UpdateLoop("warning", self:GetDeploying() and thrust > 0 and 1 or 0, WARNING_VOLUME_RATE, 100)
end

--- Stops every engine sound at once.
function ENT:StopDropshipSounds()
    for _, loop in pairs(self.dropshipLoops or {}) do
        loop.patch:Stop()
    end

    self.dropshipLoops = nil
end
