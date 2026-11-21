include("shared.lua")
include("cl_sounds.lua")
include("cl_body.lua")

--- Bone of the body that carries the rotor.
local ROTOR_BONE = 19

--- Rotor speed at full throttle in degrees per second.
local ROTOR_SPEED = 1250

--- Colour of the spotlight.
local color_cyan = Color(0, 255, 255)

function ENT:Initialize()
end

--- Creates the projected texture of the spotlight, switched off.
---@param muzzle table Attachment of the cannon's muzzle.
function ENT:CreateSpotlightTexture(muzzle)
    local texture = ProjectedTexture()
    texture:SetPos(muzzle.Pos)
    texture:SetAngles(muzzle.Ang)
    texture:SetTexture("effects/flashlight/soft")
    texture:SetFarZ(1024 * 16)
    texture:SetNearZ(16)
    texture:SetFOV(30)
    texture:SetColor(color_black)
    texture:SetBrightness(16)
    texture:SetEnableShadows(true)
    texture:Update()

    self.projTexture = texture
end

function ENT:PreDraw()
    local body = self:GetBody()
    if ( !IsValid(body) ) then return false end

    self:AnimateBody(body)
    body:DrawModel()

    if ( !self.projTexture ) then
        local muzzle = self:GetBodyAttachment("muzzle")

        if ( muzzle ) then
            self:CreateSpotlightTexture(muzzle)
        end
    end

    return false
end

function ENT:PreDrawTranslucent()
    return false
end

--- Keeps the spotlight on the cannon's muzzle.
function ENT:UpdateSpotlight()
    if ( !self.projTexture ) then return end

    local muzzle = self:GetBodyAttachment("muzzle")
    if ( !muzzle ) then return end

    self.projTexture:SetPos(muzzle.Pos)
    self.projTexture:SetAngles(muzzle.Ang)
    self.projTexture:SetColor(self:GetSpotlightEnabled() and color_cyan or color_black)
    self.projTexture:Update()
end

--- Spins the rotor with the throttle.
function ENT:AnimRotor()
    local body = self:GetBody()
    if ( !IsValid(body) ) then return end

    self.rotorAngle = ((self.rotorAngle or 0) + self:GetThrottle() * ROTOR_SPEED * RealFrameTime()) % 360

    body:ManipulateBoneAngles(ROTOR_BONE, Angle(-self.rotorAngle, 0, 0))
end

function ENT:OnFrame()
    self:AnimRotor()
    self:UpdateSpotlight()
    self:UpdateGunshipSounds()
end

function ENT:OnRemoved()
    if ( self.projTexture ) then
        self.projTexture:Remove()
        self.projTexture = nil
    end

    self:StopGunshipSounds()
end

--- Draws a square crosshair with a shadow.
---@param pos2D table Screen position.
---@param color Color|nil
function ENT:PaintCrosshairSquare(pos2D, color)
    local size = 20

    for pass = 1, 2 do
        local x = pos2D.x + (pass == 1 and 1 or 0)
        local y = pos2D.y + (pass == 1 and 1 or 0)

        if ( pass == 1 ) then
            surface.SetDrawColor(0, 0, 0, 80)
        elseif ( color ) then
            surface.SetDrawColor(color.r, color.g, color.b, color.a)
        else
            surface.SetDrawColor(255, 255, 255, 255)
        end

        surface.DrawLine(x - size, y + size, x - size * 0.5, y + size)
        surface.DrawLine(x + size, y + size, x + size * 0.5, y + size)
        surface.DrawLine(x - size, y + size, x - size, y + size * 0.5)
        surface.DrawLine(x - size, y - size, x - size, y - size * 0.5)
        surface.DrawLine(x + size, y + size, x + size, y + size * 0.5)
        surface.DrawLine(x + size, y - size, x + size, y - size * 0.5)
        surface.DrawLine(x - size, y - size, x - size * 0.5, y - size)
        surface.DrawLine(x + size, y - size, x + size * 0.5, y - size)
    end

    self:PaintCrosshairCenter(pos2D, color)
end
