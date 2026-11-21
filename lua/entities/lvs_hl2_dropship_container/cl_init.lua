include("shared.lua")

--- Degrees per second the gun turns, ten on every original think.
local GUN_TURN_RATE = 100

--- Pitch and yaw limits of the gun, the ranges of its pose parameters.
local GUN_PITCH_MIN, GUN_PITCH_MAX = -90, 30
local GUN_YAW_MIN, GUN_YAW_MAX = -60, 60

--- Offset of the spotlight from the gun's reference point, along its forward, right and up axes.
local LIGHT_OFFSET = Vector(-9, -5, -7.5)

--- Length of the visible spotlight beam.
local LIGHT_BEAM_LENGTH = 64

ENT.LightMaterial = Material("effects/lvs/heli_spotlight")
ENT.GlowMaterial = Material("sprites/light_glow02_add")

--- Returns the point the gun turns to on this client: the local pilot's or gunner's own crosshair, or the aim the server reports.
---@return Vector|nil aimPos
function ENT:GetClientGunAimPos()
    local client = LocalPlayer()
    local carrier = self:GetCarryingDropship()

    if ( carrier and carrier:GetDriver() == client ) then return carrier:GetEyeTrace().HitPos end
    if ( !carrier and self:GetDriver() == client ) then return self:GetEyeTrace().HitPos end

    local aimPos = self:GetGunAimPos()
    if ( aimPos:IsZero() ) then return nil end

    return aimPos
end

--- Turns the gun on every frame as the server does on its think, so that it moves smoothly instead of in the steps of the server's think and the network.
function ENT:AnimGun()
    self.clientGunPitch = self.clientGunPitch or 0
    self.clientGunYaw = self.clientGunYaw or 0

    self:SetPoseParameter("weapon_pitch", self.clientGunPitch)
    self:SetPoseParameter("weapon_yaw", self.clientGunYaw)
    self:InvalidateBoneCache()

    local aimPos = self:GetClientGunAimPos()

    if ( aimPos and self:GetHP() > 0 ) then
        local pitch, yaw = self:GetGunAngles(aimPos)

        if ( pitch ) then
            local step = GUN_TURN_RATE * RealFrameTime()

            self.clientGunPitch = math.Clamp(math.ApproachAngle(self.clientGunPitch, pitch, step), GUN_PITCH_MIN, GUN_PITCH_MAX)
            self.clientGunYaw = math.Clamp(math.ApproachAngle(self.clientGunYaw, yaw, step), GUN_YAW_MIN, GUN_YAW_MAX)
        end
    end

    self:SetPoseParameter("weapon_pitch", self.clientGunPitch)
    self:SetPoseParameter("weapon_yaw", self.clientGunYaw)
    self:InvalidateBoneCache()
end

function ENT:OnFrame()
    self:AnimGun()
end

--- Removes the light the spotlight casts.
function ENT:RemoveLight()
    if ( !IsValid(self.projector) ) then return end

    self.projector:Remove()
    self.projector = nil
end

--- Returns the light the spotlight casts, creating it on first use.
---@return ProjectedTexture projector
function ENT:GetLight()
    if ( IsValid(self.projector) ) then return self.projector end

    local projector = ProjectedTexture()
    projector:SetBrightness(5)
    projector:SetTexture("effects/flashlight/soft")
    projector:SetColor(color_white)
    projector:SetEnableShadows(true)
    projector:SetFarZ(2500)
    projector:SetNearZ(75)
    projector:SetFOV(75)

    self.projector = projector

    return projector
end

function ENT:PreDrawTranslucent()
    if ( !self:GetLightsEnabled() ) then
        self:RemoveLight()

        return false
    end

    local ref = self:GetAttachment(self:LookupAttachment("Gun_Ref"))
    if ( !ref ) then return false end

    local forward = ref.Ang:Forward()
    local pos = ref.Pos + forward * LIGHT_OFFSET.x + ref.Ang:Right() * LIGHT_OFFSET.y + ref.Ang:Up() * LIGHT_OFFSET.z

    render.SetMaterial(self.GlowMaterial)
    render.DrawSprite(pos, 32, 32, color_white)
    render.SetMaterial(self.LightMaterial)
    render.DrawBeam(pos, pos + forward * (LIGHT_BEAM_LENGTH - LIGHT_OFFSET.x), 32, 0, 0.99, Color(100, 100, 100, 255))

    local projector = self:GetLight()
    projector:SetPos(pos)
    projector:SetAngles(ref.Ang)
    projector:Update()

    return false
end

function ENT:OnRemoved()
    self:RemoveLight()
end
