ENT.Base = "lvs_wheeldrive_hl2_combine_apc"
ENT.PrintName = "Combine APC (Armed)"
ENT.Category = "[LVS] - Half Life 2"
ENT.IconOverride = "materials/entities/lvs/hl2/combine_apc_armed.png"

ENT.Spawnable = true
ENT.VehicleCategory = "Half Life 2"
ENT.VehicleSubCategory = "Combine"

DEFINE_BASECLASS("lvs_wheeldrive_hl2_combine_apc")

include("entities/lvs_tank_wheeldrive/modules/sh_turret.lua")
include("entities/lvs_tank_wheeldrive/modules/sh_turret_ballistics.lua")

if ( CLIENT ) then
    --- Aims the turret on every frame for everyone watching, not only for its gunner as the turret module does, so that it turns smoothly instead of in the steps the server sends, and then runs the APC's own steering animation and engine sounds, which the turret module would otherwise replace.
    function ENT:UpdatePoseParameters(...)
        self:AimTurret()

        BaseClass.UpdatePoseParameters(self, ...)
    end
else
    --- Aims the turret and then runs the APC's own tick, which the turret module would otherwise replace.
    function ENT:OnTick()
        self:AimTurret()

        BaseClass.OnTick(self)
    end
end

ENT.TurretBallisticsMuzzleAttachment = "muzzle"
ENT.TurretAimRate = 100
ENT.TurretRotationSound = "vehicles/tank_turret_loop1.wav"
ENT.TurretPitchPoseParameterName = "vehicle_weapon_pitch"
ENT.TurretPitchMin = -15
ENT.TurretPitchMax = 15
ENT.TurretPitchMul = 1
ENT.TurretPitchOffset = 0
ENT.TurretYawPoseParameterName = "vehicle_weapon_yaw"
ENT.TurretYawMin = -100
ENT.TurretYawMax = 170
ENT.TurretYawMul = 1
ENT.TurretYawOffset = 0

--- Weapon slot of the machine gun.
ENT.WEAPON_MACHINE_GUN = 1

--- Weapon slot of the rockets.
ENT.WEAPON_ROCKETS = 2

--- Does nothing, for weapons whose pacing is not a real overheat.
local function IgnoreOverheat()
end

--- Draws the crosshair where the machine gun points.
---@param ent Entity APC.
local function PaintGunCrosshair(ent)
    local muzzle = ent:GetAttachment(ent:LookupAttachment("muzzle"))
    if ( !muzzle ) then return end

    local trace = util.TraceLine({
        start = muzzle.Pos,
        endpos = muzzle.Pos + muzzle.Ang:Forward() * 50000,
        filter = ent:GetCrosshairFilterEnts(),
    })

    local screenPos = trace.HitPos:ToScreen()

    ent:PaintCrosshairOuter(screenPos, color_white)
    ent:LVSPaintHitMarker(screenPos)
end

--- Draws the crosshair on the spot the rockets home in on.
---@param ent Entity APC.
local function PaintRocketCrosshair(ent)
    local screenPos = ent:GetEyeTrace().HitPos:ToScreen()

    ent:PaintCrosshairCenter(screenPos, color_white)
    ent:LVSPaintHitMarker(screenPos)
end

function ENT:OnSetupDataTables()
    self:AddDT("Bool", "HornEnabled")
end

--- Registers the machine gun, which fires bursts of ten rounds with a pause after each, as long as the trigger is held.
function ENT:AddMachineGunWeapon()
    self:AddWeapon({
        Icon = Material("lvs/weapons/bullet.png"),
        Ammo = -1,
        Delay = 0,
        HeatRateUp = 0,
        HeatRateDown = 0,
        Attack = function(ent)
            ent:FireMachineGun()
        end,
        OnThink = function(ent)
            if ( ent.UpdateMachineGunHeat ) then
                ent:UpdateMachineGunHeat()
            end
        end,
        OnOverheat = IgnoreOverheat,
        HudPaint = PaintGunCrosshair,
    })
end

--- Registers the rockets, fired in salvos of five that home in on the crosshair, with a pause after each salvo.
function ENT:AddRocketWeapon()
    self:AddWeapon({
        Icon = Material("lvs/weapons/missile.png"),
        Ammo = -1,
        Delay = 0,
        HeatRateUp = 0,
        HeatRateDown = 0,
        Attack = function(ent)
            ent:FireRocket()
        end,
        OnThink = function(ent)
            if ( ent.UpdateRocketHeat ) then
                ent:UpdateRocketHeat()
            end
        end,
        OnOverheat = IgnoreOverheat,
        HudPaint = PaintRocketCrosshair,
    })
end

--- Registers the switch that locks the turret straight ahead.
function ENT:AddTurretLockWeapon()
    self:AddWeapon({
        Icon = Material("lvs/weapons/tank_noturret.png"),
        UseableByAI = false,
        Ammo = -1,
        Delay = 0,
        HeatRateUp = 0,
        HeatRateDown = 0,
        OnSelect = function(ent)
            if ( ent.SetTurretEnabled ) then
                ent:SetTurretEnabled(false)
            end
        end,
        OnDeselect = function(ent)
            if ( ent.SetTurretEnabled ) then
                ent:SetTurretEnabled(true)
            end
        end,
    })
end

--- Registers the alarm siren.
function ENT:AddHornWeapon()
    self:AddWeapon({
        Icon = Material("lvs/weapons/horn.png"),
        UseableByAI = false,
        Ammo = -1,
        Delay = 1,
        HeatRateUp = 0,
        HeatRateDown = 0,
        Attack = function(ent)
            ent:SetHornEnabled(!ent:GetHornEnabled())
        end,
    })
end

function ENT:InitWeapons()
    self:AddMachineGunWeapon()
    self:AddRocketWeapon()
    self:AddTurretLockWeapon()
    self:AddHornWeapon()
end
