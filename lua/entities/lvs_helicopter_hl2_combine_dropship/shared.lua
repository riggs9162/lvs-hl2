ENT.Base = "lvs_base_helicopter"
ENT.PrintName = "Combine Dropship"
ENT.Author = "Riggs"
ENT.Information = "Combine Synth Dropship from Half Life 2 + Episodes. Carries a troop container, a strider or an APC: hover low over the cargo and use the grabber to latch on or let go."
ENT.Category = "[LVS] - Half Life 2"
ENT.IconOverride = "materials/entities/lvs/hl2/combine_dropship.png"

ENT.VehicleCategory = "Half Life 2"
ENT.VehicleSubCategory = "Combine"

ENT.Spawnable = true
ENT.AdminSpawnable = false

ENT.MDL = "models/combine_dropship.mdl"
ENT.AutomaticFrameAdvance = true

ENT.AITEAM = 1
ENT.MaxHealth = 1000
ENT.DisableBallistics = true
ENT.SpawnNormalOffset = 80

--- Top speed of the original, DROPSHIP_MAX_SPEED.
ENT.MaxVelocity = 1056

--- Speed the goal may run ahead of the current speed, DROPSHIP_ACCEL_RATE.
ENT.FlightAccelRate = 300

--- The dropship leans fully into its goal acceleration, unlike the attack helicopter.
ENT.FlightGoalPitchScale = 1

--- Steepest nose-up and nose-down pitch goals of the original in degrees.
ENT.FlightGoalPitchMin = -45
ENT.FlightGoalPitchMax = 60

--- The dropship does not hold back its horizontal acceleration while it dives.
ENT.bFlightHeightDampening = false

ENT.ThrottleRateUp = 0.1
ENT.ThrottleRateDown = 0.1
ENT.ThrustRate = 1

--- No LVS engine sounds; the dropship plays the rotor loops of the original itself.
ENT.EngineSounds = {}

--- Cargo the dropship spawns with, or false to spawn empty.
ENT.DefaultCargoClass = "lvs_hl2_dropship_container"

--- Weapon slot of the container's cannon.
ENT.WEAPON_CONTAINER_GUN = 1

--- Weapon slot of the cargo grabber.
ENT.WEAPON_GRABBER = 2

--- Weapon slot of the landing mode, which sounds the warning and opens the container near the ground.
ENT.WEAPON_DEPLOY = 3

--- Weapon slot of the container's spotlight.
ENT.WEAPON_LIGHT = 4

--- Weapon slot that holds everything back.
ENT.WEAPON_NONE = 5

--- Colour of a crosshair the weapon cannot use.
local color_red = Color(255, 0, 0)

function ENT:OnSetupDataTables()
    self:AddDT("Entity", "Cargo")
    self:AddDT("Bool", "Deploying")
    self:AddDT("Float", "RotorForce")
end

--- Returns the container the dropship carries, if it carries one.
---@return Entity|nil container
function ENT:GetContainer()
    local cargo = self:GetCargo()
    if ( !IsValid(cargo) or !cargo.GetGunAngles ) then return nil end

    return cargo
end

--- Draws the crosshair where the container's cannon points, red without a container.
---@param ent Entity Dropship.
local function PaintContainerGunCrosshair(ent)
    local container = ent:GetContainer()
    local aimPos = ent:GetEyeTrace().HitPos

    if ( !container ) then
        ent:PaintCrosshairCenter(aimPos:ToScreen(), color_red)

        return
    end

    local muzzle = container:GetAttachment(container:LookupAttachment("Muzzle"))
    if ( !muzzle ) then return end

    local trace = util.TraceLine({
        start = muzzle.Pos,
        endpos = muzzle.Pos + muzzle.Ang:Forward() * 50000,
        filter = ent:GetCrosshairFilterEnts(),
    })

    ent:PaintCrosshairOuter(trace.HitPos:ToScreen(), color_white)
    ent:PaintCrosshairCenter(aimPos:ToScreen(), color_white)
    ent:LVSPaintHitMarker(trace.HitPos:ToScreen())
end

--- Plays the sound of switching to a weapon.
---@param ent Entity
local function PlaySelectSound(ent)
    ent:EmitSound("physics/metal/weapon_impact_soft3.wav")
end

--- Registers the container's cannon, which the pilot fires while a container hangs underneath.
function ENT:AddContainerGunWeapon()
    self:AddWeapon({
        Icon = Material("lvs/weapons/mg.png"),
        Ammo = -1,
        Delay = 0,
        HeatRateUp = 0,
        HeatRateDown = 0,
        OnThink = function(ent, bActive)
            if ( ent.ContainerGunThink ) then
                ent:ContainerGunThink(bActive and ent:WeaponsShouldFire() == true)
            end
        end,
        OnSelect = PlaySelectSound,
        HudPaint = PaintContainerGunCrosshair,
    })
end

--- Registers the grabber, which latches on to the cargo below or lets it go.
function ENT:AddGrabberWeapon()
    self:AddWeapon({
        Icon = Material("lvs/weapons/dropship_grabber.png"),
        UseableByAI = false,
        Ammo = -1,
        Delay = 0,
        HeatRateUp = 0,
        HeatRateDown = 0,
        StartAttack = function(ent)
            if ( ent.ToggleCargo ) then
                ent:ToggleCargo()
            end
        end,
        OnSelect = PlaySelectSound,
    })
end

--- Registers the landing mode.
function ENT:AddDeployWeapon()
    self:AddWeapon({
        Icon = Material("lvs/weapons/gunship_reardoor.png"),
        UseableByAI = false,
        Ammo = -1,
        Delay = 0,
        HeatRateUp = 0,
        HeatRateDown = 0,
        StartAttack = function(ent)
            if ( CLIENT ) then return end

            ent:SetDeploying(!ent:GetDeploying())
        end,
        OnSelect = PlaySelectSound,
    })
end

--- Registers the switch for the container's spotlight.
function ENT:AddLightWeapon()
    self:AddWeapon({
        Icon = Material("lvs/weapons/light.png"),
        UseableByAI = false,
        Ammo = -1,
        Delay = 0,
        HeatRateUp = 0,
        HeatRateDown = 0,
        StartAttack = function(ent)
            if ( CLIENT or ent:GetAI() ) then return end

            local container = ent:GetContainer()
            if ( !container ) then return end

            container:SetLightsEnabled(!container:GetLightsEnabled())
            ent:EmitSound("items/flashlight1.wav", 75, 105)
        end,
    })
end

--- Registers the empty slot.
function ENT:AddHolsterWeapon()
    self:AddWeapon({
        Icon = Material("lvs/weapons/tank_noturret.png"),
        Ammo = -1,
        Delay = 0,
        HeatRateUp = 0,
        HeatRateDown = 0,
    })
end

function ENT:InitWeapons()
    self:AddContainerGunWeapon()
    self:AddGrabberWeapon()
    self:AddDeployWeapon()
    self:AddLightWeapon()
    self:AddHolsterWeapon()
end
