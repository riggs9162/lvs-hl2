include("shared.lua")

--- Rotor revolutions per minute at full throttle, as far as the animation is concerned.
local ROTOR_RPM = 2500

--- Bone of the blurred main rotor disc.
local BONE_ROTOR_BLUR = 2

--- Bone of the main rotor hub.
local BONE_BLADE_HULL = 3

--- Bone of the tail rotor.
local BONE_BLADE_TAIL = 5

--- Yaw rate in degrees per second at which the rudder is fully deflected.
local RUDDER_YAW_RATE = 30

--- Rudder pose at full deflection.
local RUDDER_POSE = 45

--- Number of red position lights on the hull.
local MAX_HELICOPTER_LIGHTS = 3

--- Seconds a position light stays bright, and seconds it then takes to dim.
local LIGHT_BLINK_TIME_SHORT = 0.1

--- Seconds the position lights stay dim after every second flash.
local LIGHT_BLINK_TIME = 1

--- Scale of a position light while it is bright.
local LIGHT_SCALE_ON = 0.5

--- Scale of a position light while it is dim.
local LIGHT_SCALE_DIM = 0.1

--- World size of a position light sprite at a scale of one.
local LIGHT_SPRITE_SIZE = 128

--- Colour of the position lights.
local LIGHT_COLOR = Color(255, 255, 255, 200)

--- Colour of the visible spotlight beam.
local SPOTLIGHT_BEAM_COLOR = Color(100, 100, 100, 200)

--- Length of the visible spotlight beam.
local SPOTLIGHT_BEAM_LENGTH = 256

--- Width of the visible spotlight beam and of the glow at its source.
local SPOTLIGHT_BEAM_WIDTH = 64

ENT.LightSpriteMaterial = Material("sprites/redglow1")
ENT.SpotlightBeamMaterial = Material("effects/lvs/heli_spotlight")
ENT.SpotlightGlowMaterial = Material("sprites/light_glow02_add")

--- Returns the scale of the position lights at a point in time: two short flashes, each dimming again right after, followed by a long dim pause.
---@param time number Time in seconds.
---@return number scale
local function GetBlinkScale(time)
    local phase = time % (4 * LIGHT_BLINK_TIME_SHORT + LIGHT_BLINK_TIME)
    if ( phase >= 4 * LIGHT_BLINK_TIME_SHORT ) then return LIGHT_SCALE_DIM end

    local step = phase % (2 * LIGHT_BLINK_TIME_SHORT)
    if ( step < LIGHT_BLINK_TIME_SHORT ) then return LIGHT_SCALE_ON end

    return Lerp((step - LIGHT_BLINK_TIME_SHORT) / LIGHT_BLINK_TIME_SHORT, LIGHT_SCALE_ON, LIGHT_SCALE_DIM)
end

--- Degrees per second the gun turns, twelve on every original think.
local GUN_TURN_RATE = 120

function ENT:OnFrame()
    self:AnimRotor()
    self:AnimGun()
    self:AnimTail()
end

--- Returns the point the gun turns to on this client: the local pilot's own crosshair, or the aim the server reports.
---@return Vector|nil targetPos
function ENT:GetClientGunAimPos()
    if ( self:GetDriver() == LocalPlayer() ) then return self:GetEyeTrace().HitPos end

    local aimPos = self:GetGunAimPos()
    if ( aimPos:IsZero() ) then return nil end

    return aimPos
end

--- Turns the gun on every frame as the server does on its think, so that it moves smoothly instead of in the steps of the server's think and the network.
function ENT:AnimGun()
    if ( !self.clientGunAngles ) then
        local pitchMin, pitchMax = self:GetPoseParameterRange(self:LookupPoseParameter("weapon_pitch"))
        local yawMin, yawMax = self:GetPoseParameterRange(self:LookupPoseParameter("weapon_yaw"))

        self.clientGunAngles = Angle(0, 0, 0)
        self.clientGunLimits = {pitchMin = -pitchMax, pitchMax = -pitchMin, yawMin = yawMin, yawMax = yawMax}
    end

    local gunAngles = self.clientGunAngles
    local targetPos = self:GetClientGunAimPos()
    local base = self:GetAttachment(self:LookupAttachment("Gun"))

    if ( targetPos and base and self:GetSelectedWeapon() == self.WEAPON_GUN and self:GetHP() > 0 ) then
        local limits = self.clientGunLimits
        local step = GUN_TURN_RATE * RealFrameTime()
        local angles = self:WorldToLocal(self:GetPos() + (targetPos - base.Pos):GetNormalized()):Angle()

        angles:Normalize()

        gunAngles.p = math.Approach(gunAngles.p, math.Clamp(angles.p, limits.pitchMin, limits.pitchMax), step)
        gunAngles.y = math.Approach(gunAngles.y, math.Clamp(angles.y, limits.yawMin, limits.yawMax), step)
    end

    self:SetPoseParameter("weapon_pitch", -gunAngles.p)
    self:SetPoseParameter("weapon_yaw", gunAngles.y)
end

function ENT:OnRemoved()
    self:RemoveSpotlight()
end

--- Spins the main and tail rotors with the throttle.
function ENT:AnimRotor()
    self.rotorAngle = ((self.rotorAngle or 0) + self:GetThrottle() * ROTOR_RPM * RealFrameTime() * 0.5) % 360

    local hullAngles = Angle(0, 0, self.rotorAngle)

    self:ManipulateBoneAngles(BONE_ROTOR_BLUR, Angle(-self.rotorAngle, 0, 0))
    self:ManipulateBoneAngles(BONE_BLADE_HULL, hullAngles)
    self:ManipulateBoneAngles(BONE_BLADE_TAIL, hullAngles)
end

--- Deflects the rudder against the helicopter's turning, as the original does from its yaw rate.
function ENT:AnimTail()
    local yaw = self:GetAngles().y
    local frameTime = RealFrameTime()
    local yawRate = frameTime > 0 and math.AngleDifference(yaw, self.rudderLastYaw or yaw) / frameTime or 0

    self.rudderLastYaw = yaw
    self.rudderYawRate = Lerp(math.min(frameTime * 10, 1), self.rudderYawRate or 0, yawRate)

    local clamped = math.Clamp(self.rudderYawRate, -RUDDER_YAW_RATE, RUDDER_YAW_RATE)

    self:SetPoseParameter("rudder", math.Remap(clamped, -RUDDER_YAW_RATE, RUDDER_YAW_RATE, RUDDER_POSE, -RUDDER_POSE))
    self:InvalidateBoneCache()
end

--- Removes the light the spotlight casts.
function ENT:RemoveSpotlight()
    if ( !IsValid(self.spotlight) ) then return end

    self.spotlight:Remove()
    self.spotlight = nil
end

--- Returns the light the spotlight casts, creating it on first use.
---@return ProjectedTexture spotlight
function ENT:GetSpotlight()
    if ( IsValid(self.spotlight) ) then return self.spotlight end

    local spotlight = ProjectedTexture()
    spotlight:SetBrightness(32)
    spotlight:SetTexture("effects/flashlight/soft")
    spotlight:SetColor(color_white)
    spotlight:SetEnableShadows(true)
    spotlight:SetFarZ(16384)
    spotlight:SetNearZ(96)
    spotlight:SetFOV(45)

    self.spotlight = spotlight

    return spotlight
end

--- Draws the red position lights with their blink pattern.
function ENT:DrawPositionLights()
    local size = LIGHT_SPRITE_SIZE * GetBlinkScale(CurTime())

    render.SetMaterial(self.LightSpriteMaterial)

    for index = 0, MAX_HELICOPTER_LIGHTS - 1 do
        local light = self:GetAttachment(self:LookupAttachment("Light_Red" .. index))

        if ( light ) then
            render.DrawSprite(light.Pos, size, size, LIGHT_COLOR)
        end
    end
end

--- Draws the spotlight under the nose and moves the light it casts along with the gun.
function ENT:DrawSpotlight()
    local attachment = self:GetAttachment(self:LookupAttachment("Spotlight"))
    if ( !attachment ) then return end

    local direction = attachment.Ang:Forward()

    render.SetMaterial(self.SpotlightGlowMaterial)
    render.DrawSprite(attachment.Pos + direction * 5, SPOTLIGHT_BEAM_WIDTH, SPOTLIGHT_BEAM_WIDTH, color_white)

    render.SetMaterial(self.SpotlightBeamMaterial)
    render.DrawBeam(attachment.Pos, attachment.Pos + direction * SPOTLIGHT_BEAM_LENGTH, SPOTLIGHT_BEAM_WIDTH, 0, 0.99, SPOTLIGHT_BEAM_COLOR)

    local spotlight = self:GetSpotlight()
    spotlight:SetPos(attachment.Pos)
    spotlight:SetAngles(attachment.Ang)
    spotlight:Update()
end

function ENT:PreDrawTranslucent()
    if ( !self:GetLightsEnabled() ) then
        self:RemoveSpotlight()

        return true
    end

    self:DrawPositionLights()
    self:DrawSpotlight()

    return true
end
