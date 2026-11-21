--- Engine sounds of the gunship, ported from CNPC_CombineGunship::InitializeRotorSound and UpdateRotorSoundPitch and the doppler shift of CBaseHelicopter::UpdatePlayerDopplerShift. The rotor whine is heard from everywhere, the exhaust only up close and the roar of the rotor blast only right below, and all of them shift in pitch as the gunship passes.

--- Speed of sound in units per second, as the original uses for its doppler shift.
local SPEED_OF_SOUND = 13049

--- Lowest and highest pitch of the doppler shift.
local PITCH_MIN = 50
local PITCH_MAX = 250

--- Horizontal distance up to which the exhaust is heard fully, and beyond which it is not heard at all.
local EXHAUST_NEAR = 900
local EXHAUST_FAR = 1800

--- Horizontal distance up to which the rotor blast is heard fully, and beyond which it is not heard at all.
local BLAST_NEAR = 600
local BLAST_FAR = 700

--- Seconds the rotor takes to spin up from silence to full volume, from CBaseHelicopter::UpdateRotorWashVolume.
local ROTOR_RAMP_TIME = 3

--- Seconds over which a pitch or volume change is spread.
local CHANGE_TIME = 0.1

--- Sound scripts of the loops.
local ROTOR_SOUND = "NPC_CombineGunship.RotorSound"
local DYING_SOUND = "NPC_CombineGunship.DyingSound"
local EXHAUST_SOUND = "NPC_CombineGunship.ExhaustSound"
local BLAST_SOUND = "NPC_CombineGunship.RotorBlastSound"

--- Returns a volume that is full up to one distance and silent beyond another, from the original's RemapVal on squared distances.
---@param distanceSqr number Squared horizontal distance to the listener.
---@param near number
---@param far number
---@return number volume
local function FadeWithDistance(distanceSqr, near, far)
    return math.Clamp(math.Remap(distanceSqr, near * near, far * far, 1, 0), 0, 1)
end

--- Starts a loop at silence, or returns the one that is already playing.
---@param patch CSoundPatch|nil
---@param ent Entity
---@param name string Sound script.
---@return CSoundPatch patch
local function StartLoop(patch, ent, name)
    if ( patch and patch:IsPlaying() ) then return patch end

    patch = CreateSound(ent, name)
    patch:PlayEx(0, 100)

    return patch
end

--- Returns the pitch of the doppler shift between the gunship and the local player.
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

--- Runs the engine sounds of the gunship.
function ENT:UpdateGunshipSounds()
    local bDying = self:GetHP() <= 0
    local bRunning = self:GetEngineActive() or bDying

    self.rotorVolume = math.Approach(self.rotorVolume or 0, bRunning and 1 or 0, RealFrameTime() / ROTOR_RAMP_TIME)

    if ( self.rotorVolume <= 0 ) then
        self:StopGunshipSounds()

        return
    end

    local rotorName = bDying and DYING_SOUND or ROTOR_SOUND

    if ( self.rotorSoundName != rotorName and self.rotorSound ) then
        self.rotorSound:Stop()
        self.rotorSound = nil
    end

    self.rotorSoundName = rotorName
    self.rotorSound = StartLoop(self.rotorSound, self, rotorName)
    self.exhaustSound = StartLoop(self.exhaustSound, self, EXHAUST_SOUND)
    self.blastSound = StartLoop(self.blastSound, self, BLAST_SOUND)

    local listenerPos = LocalPlayer():EyePos()
    local rotor = self:GetBodyAttachment("rotor")
    local rotorPos = rotor and rotor.Pos or self:GetPos()
    local distanceSqr = (listenerPos - rotorPos):Length2DSqr()
    local pitch = self:GetDopplerPitch(listenerPos)

    if ( bDying ) then
        self.rotorSound:ChangeVolume(1, CHANGE_TIME)
        self.rotorSound:ChangePitch(100, CHANGE_TIME)
    else
        self.rotorSound:ChangeVolume(self.rotorVolume, CHANGE_TIME)
        self.rotorSound:ChangePitch(pitch, CHANGE_TIME)
    end

    self.exhaustSound:ChangePitch(pitch, CHANGE_TIME)
    self.exhaustSound:ChangeVolume(FadeWithDistance(distanceSqr, EXHAUST_NEAR, EXHAUST_FAR) * self.rotorVolume, CHANGE_TIME)
    self.blastSound:ChangeVolume(FadeWithDistance(distanceSqr, BLAST_NEAR, BLAST_FAR) * self.rotorVolume, CHANGE_TIME)
end

--- Stops every engine sound at once.
function ENT:StopGunshipSounds()
    for _, key in ipairs({"rotorSound", "exhaustSound", "blastSound"}) do
        local patch = self[key]

        if ( patch ) then
            patch:Stop()
            self[key] = nil
        end
    end

    self.rotorSoundName = nil
end
