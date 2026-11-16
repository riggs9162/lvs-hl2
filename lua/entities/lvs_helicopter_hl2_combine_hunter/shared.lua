ENT.Base = "lvs_base_helicopter"
ENT.PrintName = "Combine Hunter-Chopper"
ENT.Author = "Riggs"
ENT.Information = "Combine Attack Helicopter from Half Life 2 + Episodes"
ENT.Category = "[LVS] - Half Life 2"
ENT.IconOverride = "materials/entities/lvs/hl2/combine_helicopter.png"

ENT.VehicleCategory = "Half Life 2"
ENT.VehicleSubCategory = "Combine"

ENT.Spawnable = true
ENT.AdminSpawnable = false

ENT.MDL = "models/Combine_Helicopter.mdl"
ENT.GibModels = {
    "models/gibs/helicopter_brokenpiece_01.mdl",
    "models/gibs/helicopter_brokenpiece_02.mdl",
    "models/gibs/helicopter_brokenpiece_03.mdl",
    "models/gibs/helicopter_brokenpiece_06_body.mdl",
    "models/gibs/helicopter_brokenpiece_04_cockpit.mdl",
    "models/gibs/helicopter_brokenpiece_05_tailfan.mdl",
}

ENT.AITEAM = 1
ENT.MaxHealth = 1600
ENT.MaxVelocity = 1056
ENT.DisableBallistics = true

ENT.ThrottleRateUp = 0.15
ENT.ThrottleRateDown = 0.15
ENT.ThrustRate = 1.0
ENT.TurnRatePitch = 1
ENT.TurnRateRoll = 0.75

--- Damage one pulse round deals to everything but players, the original sk_npc_dmg_helicopter.
ENT.GunDamage = 6

--- Damage one pulse round deals to players, the original sk_npc_dmg_helicopter_to_plr.
ENT.GunDamagePlayer = 3

--- Physics force one pulse round carries, which LVS armour compares against its own threshold.
ENT.GunForce = 1000

--- Number of bombs thrown back with the gravity gun that destroy the helicopter, the original sk_helicopter_num_bombs2.
ENT.ThrownBombKillCount = 5

--- Materials that replace the bomb's own, indexed like its material slots, or nil to keep them.
ENT.BombSubMaterials = nil

--- Model of the gunner that falls out when the helicopter is badly hit.
ENT.CorpseModel = "models/combine_soldier.mdl"

ENT.EngineSounds = {
    {
        sound = "^npc/attack_helicopter/aheli_rotor_loop1.wav",
        Pitch = 0,
        PitchMin = 0,
        PitchMax = 255,
        PitchMul = 100,
        Volume = 1,
        VolumeMin = 0,
        VolumeMax = 1,
        SoundLevel = 125,
        UseDoppler = true,
    },
    {
        sound = "npc/attack_helicopter/aheli_wash_loop3.wav",
        sound_int = "lvs/vehicles/helicopter/loop_interior.wav",
        Pitch = 0,
        PitchMin = 0,
        PitchMax = 255,
        PitchMul = 100,
        Volume = 1,
        VolumeMin = 0,
        VolumeMax = 1,
        SoundLevel = 75,
        UseDoppler = true,
    },
}

--- Weapon slot of the pulse gun.
ENT.WEAPON_GUN = 1

--- Weapon slot of the single bombs.
ENT.WEAPON_BOMBS = 2

--- Weapon slot of the carpet bombing run.
ENT.WEAPON_CARPET_BOMBS = 3

--- Weapon slot of the light switch.
ENT.WEAPON_LIGHTS = 4

--- Seconds between two volleys of a carpet bombing run, as in the original.
local CARPET_BOMB_INTERVAL = 0.2

--- Seconds a carpet bombing run can last before it has to cool down.
local CARPET_BOMB_DURATION = 5

--- Seconds a carpet bombing run takes to cool down completely.
local CARPET_BOMB_COOLDOWN = 20

--- Does nothing, for weapons whose pacing is not a real overheat.
local function IgnoreOverheat()
end

function ENT:OnSetupDataTables()
    self:AddDT("Bool", "LightsEnabled")
end

--- Registers the pulse gun, which charges up and then fires a fixed number of bursts by itself.
function ENT:AddGunWeapon()
    self:AddWeapon({
        Icon = Material("lvs/weapons/mg.png"),
        Ammo = -1,
        Delay = 0,
        HeatRateUp = 0,
        HeatRateDown = 0,
        OnThink = function(ent, bActive)
            ent:GunThink(bActive and ent:WeaponsShouldFire() == true)
        end,
        OnSelect = function(ent)
            ent:EmitSound("physics/metal/weapon_impact_soft3.wav")
        end,
        OnDeselect = function(ent)
            ent:GunShutdown()
        end,
        OnOverheat = IgnoreOverheat,
    })
end

--- Registers the bombs, dropped one at a time in sticks for as long as the trigger is held.
function ENT:AddBombWeapon()
    self:AddWeapon({
        Icon = Material("lvs/weapons/bomb.png"),
        Ammo = -1,
        Delay = 0,
        HeatRateUp = 0,
        HeatRateDown = 0,
        Attack = function(ent)
            ent:DropBombs()
        end,
        OnThink = function(ent)
            ent:UpdateBombHeat()
        end,
        OnOverheat = IgnoreOverheat,
    })
end

--- Registers the carpet bombing run, which sounds the alert and then drops volleys while the trigger is held.
function ENT:AddCarpetBombWeapon()
    self:AddWeapon({
        Icon = Material("lvs/weapons/dropship_grabber.png"),
        UseableByAI = false,
        Ammo = -1,
        Delay = CARPET_BOMB_INTERVAL,
        HeatRateUp = 1 / CARPET_BOMB_DURATION,
        HeatRateDown = 1 / CARPET_BOMB_COOLDOWN,
        StartAttack = function(ent)
            ent:StartCarpetBombing()
        end,
        Attack = function(ent)
            ent:DropCarpetBombs()
        end,
    })
end

--- Registers the switch for the blinking position lights and the spotlight.
function ENT:AddLightWeapon()
    self:AddWeapon({
        Icon = Material("lvs/weapons/light.png"),
        UseableByAI = false,
        Ammo = -1,
        Delay = 0,
        HeatRateUp = 0,
        HeatRateDown = 1,
        StartAttack = function(ent)
            if ( ent:GetAI() ) then return end

            ent:SetLightsEnabled(!ent:GetLightsEnabled())
            ent:EmitSound("items/flashlight1.wav", 75, 105)
        end,
    })
end

function ENT:InitWeapons()
    self:AddGunWeapon()
    self:AddBombWeapon()
    self:AddCarpetBombWeapon()
    self:AddLightWeapon()
end
