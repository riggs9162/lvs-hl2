local spotlight = Vector(118, 0, 78)

ENT.Base = "lvs_base_wheeldrive"
ENT.PrintName = "Combine IFV"
ENT.Author = "Riggs"
ENT.Information = ""
ENT.Category = "[LVS] - Half Life 2"
ENT.IconOverride = "materials/entities/lvs/hl2/combine_ifv.png"

ENT.AITEAM = 1
ENT.AdminSpawnable = false
ENT.EngineCurve = 0.25
ENT.EngineTorque = 500
ENT.GibModels = {"models/combine_ifv_destroyed_gib02.mdl", "models/combine_ifv_destroyed_gib03.mdl", "models/combine_ifv_destroyed_gib04.mdl", "models/combine_ifv_destroyed_gib05.mdl", "models/combine_ifv_destroyed_gib06.mdl", "models/combine_ifv_destroyed_gib07.mdl", "models/combine_ifv_destroyed_gib08.mdl", "models/combine_ifv_destroyed_gib09.mdl", "models/combine_ifv_destroyed_gib10.mdl"}
ENT.MDL = "models/vehicles_pyro/combine_ifv.mdl"
ENT.MDL_DESTROYED = "models/combine_ifv_destroyed_gib01.mdl"
ENT.MaxVelocity = 1600
ENT.MaxVelocityReverse = 500
ENT.PhysicsMass = 2000
ENT.SpawnNormalOffset = 10
ENT.Spawnable = true
ENT.TransGears = 3
ENT.TransGearsReverse = 1
ENT.VehicleCategory = "Half Life 2"
ENT.VehicleSubCategory = "Combine"

ENT.EngineSounds = {}

ENT.TireSoundTypes = {
    ["roll"] = "lvs/vehicles/generic/wheel_roll.wav",
    ["roll_racing"] = "lvs/vehicles/generic/wheel_roll.wav",
    ["roll_dirt"] = "lvs/vehicles/generic/wheel_roll_dirt.wav",
    ["roll_wet"] = "lvs/vehicles/generic/wheel_roll_wet.wav",
    ["roll_damaged"] = "lvs/wheel_damaged_loop.wav",
    ["skid"] = "vehicles/v8/skid_highfriction.wav",
    ["skid_racing"] = "vehicles/v8/skid_normalfriction.wav",
    ["skid_dirt"] = "vehicles/v8/skid_lowfriction.wav",
    ["skid_wet"] = "vehicles/v8/skid_highfriction.wav",
    ["tire_damage_layer"] = "lvs/wheel_destroyed_loop.wav",
}

ENT.Lights = {
    {
        Trigger = "main",
        Sprites = {
            {
                pos = spotlight,
                colorR = 0,
                colorG = 180,
                colorB = 220,
                colorA = 150,
                size = 60
            },
        },
        ProjectedTextures = {
            {
                pos = spotlight,
                ang = Angle(10, 0, 0),
                colorR = 0,
                colorG = 180,
                colorB = 220,
                colorA = 150,
                shadows = false,
                brightness = 4,
                farz = 3072,
                fov = 90
            },
        },
    },
    {
        Trigger = "high",
        Sprites = {
            {
                pos = spotlight,
                colorR = 0,
                colorG = 180,
                colorB = 220,
                colorA = 150,
                size = 60
            },
        },
        ProjectedTextures = {
            {
                pos = spotlight,
                ang = Angle(0, 0, 0),
                colorR = 0,
                colorG = 180,
                colorB = 220,
                colorA = 150,
                shadows = false,
                brightness = 10,
                farz = 3072,
                fov = 90
            },
        },
    },
}

include("entities/lvs_tank_wheeldrive/modules/sh_turret.lua")
include("entities/lvs_tank_wheeldrive/modules/sh_turret_ballistics.lua")

ENT.TurretBallisticsMuzzleAttachment = "muzzle_1"
ENT.TurretAimRate = 250
ENT.TurretRotationSound = "vehicles/tank_turret_loop1.wav"
ENT.TurretPitchPoseParameterName = "gun_aim_pitch"
ENT.TurretPitchMin = -12
ENT.TurretPitchMax = 15
ENT.TurretPitchMul = -1
ENT.TurretPitchOffset = 0
ENT.TurretYawPoseParameterName = "gun_aim_yaw"
ENT.TurretYawMin = -25
ENT.TurretYawMax = 25
ENT.TurretYawMul = 1
ENT.TurretYawOffset = 0

function ENT:TurretInRange()
    local ID = self:LookupAttachment("muzzle_1")
    local muzzle = self:GetAttachment(ID)
    if ( !muzzle ) then return true end

    local Dir1 = muzzle.Ang:Forward()
    local Dir2 = self:GetAimVector()

    return self:AngleBetweenNormal(Dir1, Dir2) < 5
end

function ENT:InitWeapons()
    local weapon = {}
    weapon.Icon = Material("lvs/weapons/bullet.png")
    weapon.Ammo = -1
    weapon.Delay = 0.09
    weapon.HeatRateUp = 0.11
    weapon.HeatRateDown = 0.15
    weapon.Attack = function(ent)
        local muzzle = ent:GetAttachment(ent:LookupAttachment("muzzle_1"))
        if ( !muzzle ) then return end

        local spread = tonumber(GetConVar("lvs_car_hl2_combineifv_spread"):GetString())
        local bullet = {}
        bullet.Src = muzzle.Pos
        bullet.Dir = muzzle.Ang:Forward()
        bullet.Spread = Vector(spread, spread, spread)
        bullet.TracerName = "none"
        bullet.Force = 100
        bullet.HullSize = 5
        bullet.Damage = GetConVar("lvs_car_hl2_combineifv_damage"):GetInt()
        bullet.Velocity = 30000
        bullet.Attacker = ent:GetDriver()
        bullet.Callback = function(att, tr, dmginfo)
            local effectData = EffectData()
            effectData:SetEntity(ent)
            effectData:SetAttachment(ent:LookupAttachment("muzzle_1"))
            effectData:SetStart(muzzle.Pos)
            effectData:SetOrigin(tr.HitPos)
            effectData:SetScale(6000)
            util.Effect("AR2Tracer", effectData)

            effectData = EffectData()
            effectData:SetOrigin(tr.HitPos + tr.HitNormal)
            effectData:SetNormal(tr.HitNormal)
            util.Effect("AR2Impact", effectData, true, true)
        end

        local effectData = EffectData()
        effectData:SetEntity(ent)
        effectData:SetAttachment(ent:LookupAttachment("muzzle_1"))
        effectData:SetOrigin(muzzle.Pos)
        effectData:SetAngles(muzzle.Ang)
        effectData:SetScale(1)
        util.Effect("AirboatMuzzleFlash", effectData, true, true)

        ent:EmitSound("Weapon_AR2.Single")
        ent:LVSFireBullet(bullet)
        ent:TakeAmmo(1)
    end

    weapon.OnOverheat = function(ent) ent:EmitSound("weapons/airboat/airboat_gun_energy" .. math.random(1, 2) .. ".wav") end
    weapon.HudPaint = function(ent, X, Y, client)
        local muzzle = ent:GetAttachment(ent:LookupAttachment("muzzle_1"))
        if ( !muzzle ) then return end

        local traceTurret = util.TraceLine({
            start = muzzle.Pos,
            endpos = muzzle.Pos + muzzle.Ang:Forward() * 50000,
            filter = ent:GetCrosshairFilterEnts()
        })

        local muzzlePos2D = traceTurret.HitPos:ToScreen()
        local color = ent:TurretInRange() and COLOR_WHITE or Color(255, 0, 0, 255)
        ent:PaintCrosshairOuter(muzzlePos2D, color)
        ent:LVSPaintHitMarker(muzzlePos2D)
    end

    self:AddWeapon(weapon)

    weapon = {}
    weapon.Icon = Material("lvs/weapons/missile.png")
    weapon.Ammo = -1
    weapon.Delay = 1.25
    weapon.HeatRateUp = 1
    weapon.HeatRateDown = 0.75
    weapon.Attack = function(ent)
        local chosen = ent._NextCannonMuzzle or "cannon_muzzle_1"
        local muzzle = ent:GetAttachment(ent:LookupAttachment(chosen))
        if ( !muzzle ) then return end

        ent._NextCannonMuzzle = chosen == "cannon_muzzle_1" and "cannon_muzzle_2" or "cannon_muzzle_1"

        ent:EmitSound("PropAPC.FireCannon")

        local driver = ent:GetDriver()
        local target = ent:GetEyeTrace().HitPos
        local projectile = ents.Create("lvs_missile")
        projectile:SetPos(muzzle.Pos)
        projectile:SetAngles(muzzle.Ang)
        projectile:SetParent(ent)
        projectile:Spawn()
        projectile:Activate()
        projectile.GetTarget = function(missile) return missile end
        projectile.GetTargetPos = function(missile)
            if ( missile.HasReachedTarget ) then return missile:LocalToWorld(Vector(100, 0, 0)) end
            if ( (missile:GetPos() - target):Length() < 100 ) then missile.HasReachedTarget = true end

            return target
        end

        projectile:SetAttacker(IsValid(driver) and driver or ent)
        projectile:SetEntityFilter(ent:GetCrosshairFilterEnts())
        projectile:SetSpeed(ent:GetVelocity():Length() + tonumber(GetConVar("lvs_car_hl2_combineifv_rocketspeed"):GetString()))
        projectile:SetDamage(tonumber(GetConVar("lvs_car_hl2_combineifv_rocketdamage"):GetString()))
        projectile:SetRadius(tonumber(GetConVar("lvs_car_hl2_combineifv_rocketradius"):GetString()))
        projectile:Enable()

        local physicsObject = ent:GetPhysicsObject()
        if ( IsValid(physicsObject) ) then physicsObject:ApplyForceOffset(-muzzle.Ang:Forward() * 50000, muzzle.Pos) end

        local effectData = EffectData()
        effectData:SetOrigin(muzzle.Pos)
        effectData:SetNormal(muzzle.Ang:Forward())
        effectData:SetEntity(ent)
        util.Effect("lvs_muzzle", effectData)
        ent:TakeAmmo(1)
    end

    weapon.HudPaint = function(ent, X, Y, client)
        local Pos2D = ent:GetEyeTrace().HitPos:ToScreen()
        ent:PaintCrosshairOuter(Pos2D, COLOR_WHITE)
        ent:LVSPaintHitMarker(Pos2D)
    end

    self:AddWeapon(weapon)

    weapon = {}
    weapon.Icon = Material("lvs/weapons/tank_noturret.png")
    weapon.Ammo = -1
    weapon.Delay = 0
    weapon.HeatRateUp = 0
    weapon.HeatRateDown = 0
    weapon.OnSelect = function(ent) if ( ent.SetTurretEnabled ) then ent:SetTurretEnabled(false) end end
    weapon.OnDeselect = function(ent) if ( ent.SetTurretEnabled ) then ent:SetTurretEnabled(true) end end

    self:AddWeapon(weapon)

    weapon = {}
    weapon.Icon = Material("lvs/weapons/horn.png")
    weapon.Ammo = -1
    weapon.Delay = 2
    weapon.HeatRateUp = 0
    weapon.HeatRateDown = 0
    weapon.Attack = function(ent) ent:EmitSound("ambient/alarms/apc_alarm_pass1.wav", 85, 100) end

    self:AddWeapon(weapon)
end
