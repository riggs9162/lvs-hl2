ENT.Base = "lvs_base_helicopter"
ENT.PrintName = "Combine Gunship"
ENT.Author = "Riggs"
ENT.Information = "Combine Synth Gunship from Half Life 2 + Episodes"
ENT.Category = "[LVS] - Half Life 2"
ENT.IconOverride = "materials/entities/lvs/hl2/combine_gunship.png"

ENT.VehicleCategory = "Half Life 2"
ENT.VehicleSubCategory = "Combine"

ENT.Spawnable = true
ENT.AdminSpawnable = false

ENT.MDL = "models/riggs9162/vehicles/combine_gunship.mdl"
ENT.GibModels = {
    "models/gibs/gunship_gibs_engine.mdl",
    "models/gibs/gunship_gibs_eye.mdl",
    "models/gibs/gunship_gibs_headsection.mdl",
    "models/gibs/gunship_gibs_midsection.mdl",
    "models/gibs/gunship_gibs_nosegun.mdl",
    "models/gibs/gunship_gibs_sensorarray.mdl",
    "models/gibs/gunship_gibs_tailsection.mdl",
    "models/gibs/gunship_gibs_wing.mdl",
}

ENT.AITEAM = 1
ENT.MaxHealth = 1600
ENT.DisableBallistics = true

--- Top speed of the original, GUNSHIP_MAX_SPEED.
ENT.MaxVelocity = 1056

ENT.ThrottleRateUp = 0.2
ENT.ThrottleRateDown = 0.2
ENT.ThrustRate = 1

--- The gunship leans fully into its goal acceleration, unlike the attack helicopter, which only leans three quarters of the way.
ENT.FlightGoalPitchScale = 1

--- Steepest nose-up pitch goal of the original in degrees.
ENT.FlightGoalPitchMin = -45

--- Steepest nose-down pitch goal of the original in degrees.
ENT.FlightGoalPitchMax = 60

--- Share of the sideways velocity the original loses per think tick.
ENT.FlightSidewaysDrag = 0.04

--- The gunship does not hold back its horizontal acceleration while it dives, as the attack helicopter does.
ENT.bFlightHeightDampening = false

--- No LVS engine sounds; the gunship plays the rotor, exhaust and blast loops of the original itself.
ENT.EngineSounds = {}

include("sh_body.lua")

--- Weapon slot of the pulse cannon.
ENT.WEAPON_CANNON = 1

--- Weapon slot of the belly cannon.
ENT.WEAPON_BELLY_CANNON = 2

--- Weapon slot that holds both cannons back.
ENT.WEAPON_NONE = 3

--- Weapon slot of the spotlight switch.
ENT.WEAPON_SPOTLIGHT = 4

--- Colour of a crosshair the weapon cannot reach.
local color_red = Color(255, 0, 0)

--- Does nothing, for weapons whose pacing is not a real overheat.
local function IgnoreOverheat()
end

--- Plays the sound of switching to a weapon.
---@param ent Entity Gunship.
local function PlaySelectSound(ent)
    ent:EmitSound("physics/metal/weapon_impact_soft3.wav")
end

function ENT:OnSetupDataTables()
    self:AddDT("Entity", "Body")
    self:AddDT("Bool", "SpotlightEnabled")
    self:AddDT("Bool", "GroundAttacking")
    self:AddDT("Vector", "GroundAttackHitPos")
    self:AddDT("Vector", "HeadTarget")
    self:AddDT("Float", "RotorForce")
end

--- Returns the position and direction of an attachment of the gunship's body.
---@param name string Attachment name.
---@return table|nil attachment Table with Pos and Ang, or nil without a body.
function ENT:GetBodyAttachment(name)
    local body = self:GetBody()
    if ( !IsValid(body) ) then return nil end

    return body:GetAttachment(body:LookupAttachment(name))
end

--- Returns where the belly cannon would strike: straight below its muzzle, as in CNPC_CombineGunship::GetGroundAttackHitPosition.
---@return Vector|nil hitPos
---@return Vector|nil muzzlePos
function ENT:GetGroundAttackHitPosition()
    local muzzle = self:GetBodyAttachment("bellygun")
    if ( !muzzle ) then return nil end

    local trace = util.TraceLine({
        start = muzzle.Pos,
        endpos = muzzle.Pos - Vector(0, 0, 56756),
        mask = MASK_SHOT,
        filter = self:GetCrosshairFilterEnts(),
    })

    return trace.HitPos, muzzle.Pos
end

--- Draws the crosshair where the cannon's muzzle points, red while the target is too far off the muzzle for the cannon to fire.
---@param ent Entity Gunship.
local function PaintCannonCrosshair(ent)
    local muzzle = ent:GetBodyAttachment("muzzle")
    if ( !muzzle ) then return end

    local aimPos = ent:GetEyeTrace().HitPos
    local trace = util.TraceLine({
        start = muzzle.Pos,
        endpos = muzzle.Pos + muzzle.Ang:Forward() * 50000,
        filter = ent:GetCrosshairFilterEnts(),
    })

    local bInCone = (aimPos - muzzle.Pos):GetNormalized():Dot(muzzle.Ang:Forward()) >= ent.CannonFireDot

    ent:PaintCrosshairOuter(trace.HitPos:ToScreen(), bInCone and color_white or color_red)
    ent:PaintCrosshairCenter(aimPos:ToScreen(), color_white)
    ent:LVSPaintHitMarker(aimPos:ToScreen())
end

--- Draws the crosshair on the spot right below the belly cannon.
---@param ent Entity Gunship.
local function PaintBellyCrosshair(ent)
    local hitPos = ent:GetGroundAttackHitPosition()
    if ( !hitPos ) then return end

    local screenPos = hitPos:ToScreen()

    ent:PaintCrosshairSquare(screenPos, color_white)
    ent:LVSPaintHitMarker(screenPos)
end

--- Smallest cosine between the cannon's muzzle and its target at which a round still leaves, from CNPC_CombineGunship::FireCannonRound.
ENT.CannonFireDot = 0.8

--- Registers the pulse cannon: holding the trigger warms it up and then fires bursts of rounds with a pause after each, as in the original.
function ENT:AddCannonWeapon()
    self:AddWeapon({
        Icon = Material("lvs/weapons/mg.png"),
        Ammo = -1,
        Delay = 0,
        HeatRateUp = 0,
        HeatRateDown = 0,
        OnThink = function(ent, bActive)
            if ( ent.CannonThink ) then
                ent:CannonThink(bActive and ent:WeaponsShouldFire() == true)
            end
        end,
        OnSelect = PlaySelectSound,
        OnDeselect = function(ent)
            if ( ent.StopCannonBurst ) then
                ent:StopCannonBurst()
            end
        end,
        OnOverheat = IgnoreOverheat,
        HudPaint = PaintCannonCrosshair,
    })
end

--- Registers the belly cannon, which charges for three seconds and then blasts the ground straight below.
function ENT:AddBellyCannonWeapon()
    self:AddWeapon({
        Icon = Material("lvs/weapons/warplaser.png"),
        Ammo = -1,
        Delay = 0,
        HeatRateUp = 0,
        HeatRateDown = 0,
        Attack = function(ent)
            if ( ent.TryGroundAttack ) then
                ent:TryGroundAttack()
            end
        end,
        OnThink = function(ent)
            if ( ent.UpdateGroundAttackHeat ) then
                ent:UpdateGroundAttackHeat()
            end
        end,
        OnSelect = PlaySelectSound,
        OnOverheat = IgnoreOverheat,
        HudPaint = PaintBellyCrosshair,
    })
end

--- Registers the empty slot that holds both cannons back.
function ENT:AddHolsterWeapon()
    self:AddWeapon({
        Icon = Material("lvs/weapons/tank_noturret.png"),
        Ammo = -1,
        Delay = 0,
        HeatRateUp = 0,
        HeatRateDown = 0,
    })
end

--- Registers the spotlight switch.
function ENT:AddSpotlightWeapon()
    self:AddWeapon({
        Icon = Material("lvs/weapons/light.png"),
        UseableByAI = false,
        Ammo = -1,
        Delay = 0,
        HeatRateUp = 0,
        HeatRateDown = 0,
        StartAttack = function(ent)
            if ( ent:GetAI() ) then return end

            ent:EmitSound("items/flashlight1.wav", 75, 105)

            if ( ent.SetSpotlight ) then
                ent:SetSpotlight(!ent:GetSpotlightEnabled())
            end
        end,
    })
end

function ENT:InitWeapons()
    self:AddCannonWeapon()
    self:AddBellyCannonWeapon()
    self:AddHolsterWeapon()
    self:AddSpotlightWeapon()
end
