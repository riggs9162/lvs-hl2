AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("cl_sounds.lua")
AddCSLuaFile("cl_body.lua")
AddCSLuaFile("sh_body.lua")
include("shared.lua")
include("lvs_hl2/sv_helicopter_flight.lua")
include("sv_flight.lua")
include("sv_body.lua")
include("sv_cannon.lua")
include("sv_bellyblast.lua")
include("sv_damage.lua")
include("sv_sounds.lua")
include("lvs_hl2/sv_helicopter_ai.lua")
include("sv_ai.lua")

--- Seconds between two thinks of the original, HELICOPTER_THINK_INTERVAL, at which the gunship aims, fires and pings.
local THINK_INTERVAL = 0.1

--- Position of the pilot's seat.
local SEAT_POS = Vector(200, 0, 0)

--- Position of the rotor.
local ROTOR_POS = Vector(-133, 0, 55)

--- Colour of the spotlight.
local color_cyan = Color(0, 255, 255)

--- Creates the animated body that is drawn in place of the physics hull.
function ENT:CreateBody()
    local body = ents.Create("lvs_gunship_body")
    body:SetPos(self:GetPos())
    body:SetAngles(self:GetAngles())
    body:Spawn()
    body:Activate()
    body:SetParent(self)

    self:DeleteOnRemove(body)
    self:TransferCPPI(body)
    self:SetBody(body)

    return body
end

--- Creates the spotlight and its glow on the cannon's muzzle, both switched off.
---@param body Entity Body of the gunship.
function ENT:CreateSpotlight(body)
    local id = body:LookupAttachment("muzzle")
    local muzzle = body:GetAttachment(id)
    if ( !muzzle ) then return end

    local spotlight = ents.Create("point_spotlight")

    if ( IsValid(spotlight) ) then
        spotlight:SetPos(muzzle.Pos)
        spotlight:SetAngles(muzzle.Ang)
        spotlight:SetParent(body, id)
        spotlight:SetKeyValue("spotlightlength", "1024")
        spotlight:SetKeyValue("spotlightwidth", "512")
        spotlight:AddSpawnFlags(2)
        spotlight:SetColor(color_cyan)
        spotlight:Spawn()
        spotlight:Activate()
        spotlight:Fire("LightOff")

        self.spotlight = spotlight
    end

    local sprite = ents.Create("env_sprite")

    if ( IsValid(sprite) ) then
        sprite:SetPos(muzzle.Pos)
        sprite:SetParent(body, id)
        sprite:RemoveSpawnFlags(1)
        sprite:SetKeyValue("rendermode", 9)
        sprite:SetKeyValue("model", "sprites/light_ignorez.vmt")
        sprite:SetKeyValue("scale", 2)
        sprite:SetColor(color_cyan)
        sprite:Spawn()
        sprite:Activate()
        sprite:Fire("HideSprite")

        self.spotlightSprite = sprite
    end
end

--- Switches the spotlight on or off.
---@param bEnabled boolean
function ENT:SetSpotlight(bEnabled)
    self:SetSpotlightEnabled(bEnabled)

    if ( IsValid(self.spotlight) ) then
        self.spotlight:Fire(bEnabled and "LightOn" or "LightOff")
    end

    if ( IsValid(self.spotlightSprite) ) then
        self.spotlightSprite:Fire(bEnabled and "ShowSprite" or "HideSprite")
    end
end

function ENT:OnSpawn(phys)
    local driverSeat = self:AddDriverSeat(SEAT_POS, Angle(0, -90, 0))
    driverSeat:SetCameraDistance(0.2)
    driverSeat.HidePlayer = true

    self:DrawShadow(false)

    local rotor = self:AddRotor(ROTOR_POS, angle_zero, 0, 4000)
    rotor:SetRotorEffects(true)

    local body = self:CreateBody()
    self:CreateSpotlight(body)

    self:InitBody()
    self:InitCannon()
    self:InitGroundAttack()
    self:InitDamage()
    self:InitSounds()
    self:InitAI()

    self.nextGunshipThink = 0

    if ( self.PostOnSpawn ) then
        self:PostOnSpawn(phys)
    end
end

--- Runs the combat of one think: the cries at new enemies, the belly cannon and the pulse cannon, from CNPC_CombineGunship::DoCombat and the FireGun call of CBaseHelicopter::HelicopterThink.
function ENT:DoCombat()
    self:UpdateEnemySounds()
    self:GroundAttackCombat()
    self:CannonCombat()
end

--- Runs what the original does on every think: the combat, the head, the pings and the explosions of a dying gunship, from CNPC_CombineGunship::PrescheduleThink.
function ENT:GunshipThink()
    if ( self:IsDestroyed() ) then
        self:DyingThink()

        return
    end

    self:Ping()
    self:DoCombat()
    self:MoveHead(THINK_INTERVAL)
end

function ENT:OnTick()
    local now = CurTime()
    if ( now < (self.nextGunshipThink or 0) ) then return end

    self.nextGunshipThink = now + THINK_INTERVAL
    self:GunshipThink()
end

function ENT:OnRemoved()
    self:StopLoopingSounds()
end
