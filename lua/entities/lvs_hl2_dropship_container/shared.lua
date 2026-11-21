ENT.Base = "lvs_base"
ENT.PrintName = "Combine Dropship Container"
ENT.Author = "Riggs"
ENT.Information = "Troop container of the Combine Dropship from Half Life 2, carried by a dropship or set down on its own. Enter through the open door, or noclip in."
ENT.Category = "[LVS] - Half Life 2"
ENT.IconOverride = "materials/entities/lvs/hl2/combine_dropship.png"

ENT.VehicleCategory = "Half Life 2"
ENT.VehicleSubCategory = "Combine"

ENT.Spawnable = true
ENT.AdminSpawnable = false

ENT.MDL = "models/combine_dropship_container.mdl"
ENT.GibModels = {
    "models/container_chunk01.mdl",
    "models/container_chunk02.mdl",
    "models/container_chunk03.mdl",
    "models/container_chunk04.mdl",
    "models/container_chunk05.mdl",
}

ENT.AITEAM = 1

--- Health of the original container, sk_dropship_container_health.
ENT.MaxHealth = 750

ENT.SpawnNormalOffset = 50

--- Whether players may only get in through the open door or while noclipping.
ENT.bDoorRequired = true

--- Weapon slot of the cannon.
ENT.WEAPON_GUN = 1

--- Weapon slot of the door switch.
ENT.WEAPON_DOOR = 2

--- Weapon slot of the spotlight switch.
ENT.WEAPON_LIGHT = 3

--- Colour of a crosshair the gun cannot reach.
local color_red = Color(255, 0, 0)

function ENT:OnSetupDataTables()
    self:AddDT("Bool", "Door")
    self:AddDT("Bool", "LightsEnabled")
    self:AddDT("Vector", "GunAimPos")
    self:AddDT("Entity", "Carrier")
end

--- Returns the dropship carrying the container, if any.
---@return Entity|nil carrier
function ENT:GetCarryingDropship()
    local carrier = self:GetCarrier()
    if ( !IsValid(carrier) ) then return nil end

    return carrier
end

--- Returns the direction the gunner looks.
---@return Vector direction
function ENT:GetAimVector()
    if ( self:GetAI() ) then return (self:GetGunAimPos() - self:WorldSpaceCenter()):GetNormalized() end

    local driver = self:GetDriver()
    if ( !IsValid(driver) ) then return self:GetForward() end

    if ( SERVER ) then
        local pod = self:GetDriverSeat()
        if ( !IsValid(pod) ) then return driver:EyeAngles():Forward() end

        return pod:WorldToLocalAngles(driver:EyeAngles()):Forward()
    end

    return driver:EyeAngles():Forward()
end

--- Returns what the gunner looks at.
---@return table trace
function ENT:GetEyeTrace()
    local startPos = self:WorldSpaceCenter()
    local pod = self:GetDriverSeat()

    if ( IsValid(pod) ) then
        startPos = pod:LocalToWorld(pod:OBBCenter())
    end

    return util.TraceLine({
        start = startPos,
        endpos = startPos + self:GetAimVector() * 50000,
        filter = self:GetCrosshairFilterEnts(),
    })
end

--- Returns the angles the gun's pose parameters need to point its offset barrel at a point, from CNPC_CombineDropship::UpdateContainerGunFacing.
---@param targetPos Vector
---@return number|nil pitch
---@return number|nil yaw
function ENT:GetGunAngles(targetPos)
    local muzzle = self:GetAttachment(self:LookupAttachment("Muzzle"))
    local ref = self:GetAttachment(self:LookupAttachment("Gun_Ref"))
    local base = self:GetAttachment(self:LookupAttachment("Gun_Base"))
    if ( !muzzle or !ref or !base ) then return nil end

    local barrel = WorldToLocal(muzzle.Pos, angle_zero, ref.Pos, ref.Ang)
    local target = WorldToLocal(targetPos, angle_zero, base.Pos, base.Ang)
    local quadTarget = target:LengthSqr()

    if ( quadTarget <= barrel:LengthSqr() ) then return nil end

    local quadTargetXY = target.x * target.x + target.y * target.y
    local targetToCenterYaw = math.atan2(target.y, target.x)
    local centerToGunYaw = math.atan2(barrel.y, math.sqrt(quadTarget - barrel.y * barrel.y))
    local targetToCenterPitch = math.atan2(target.z, math.sqrt(quadTargetXY))
    local centerToGunPitch = math.atan2(-barrel.z, math.sqrt(quadTarget - barrel.z * barrel.z))

    return math.deg(targetToCenterPitch + centerToGunPitch), math.deg(targetToCenterYaw + centerToGunYaw)
end

--- Draws the crosshair where the cannon points, red while a dropship has the gun.
---@param ent Entity Container.
local function PaintGunCrosshair(ent)
    local muzzle = ent:GetAttachment(ent:LookupAttachment("Muzzle"))
    if ( !muzzle ) then return end

    local trace = util.TraceLine({
        start = muzzle.Pos,
        endpos = muzzle.Pos + muzzle.Ang:Forward() * 50000,
        filter = ent:GetCrosshairFilterEnts(),
    })

    local color = ent:GetCarryingDropship() and color_red or color_white

    ent:PaintCrosshairOuter(trace.HitPos:ToScreen(), color)
    ent:PaintCrosshairCenter(ent:GetEyeTrace().HitPos:ToScreen(), color)
    ent:LVSPaintHitMarker(trace.HitPos:ToScreen())
end

--- Plays the sound of switching to a weapon.
---@param ent Entity
local function PlaySelectSound(ent)
    ent:EmitSound("physics/metal/weapon_impact_soft3.wav")
end

--- Registers the cannon, which the gunner fires while the container stands on its own.
function ENT:AddGunWeapon()
    self:AddWeapon({
        Icon = Material("lvs/weapons/mg.png"),
        Ammo = -1,
        Delay = 0,
        HeatRateUp = 0,
        HeatRateDown = 0,
        OnThink = function(ent, bActive)
            if ( !ent.SetGunInput or ent:GetCarryingDropship() or ent:GetAI() or !IsValid(ent:GetDriver()) ) then return end

            ent:SetGunInput(ent:GetEyeTrace().HitPos, bActive and ent:WeaponsShouldFire() == true)
        end,
        OnSelect = PlaySelectSound,
        HudPaint = PaintGunCrosshair,
    })
end

--- Registers the door switch, which only works while no dropship carries the container.
function ENT:AddDoorWeapon()
    self:AddWeapon({
        Icon = Material("lvs/weapons/gunship_reardoor.png"),
        UseableByAI = false,
        Ammo = -1,
        Delay = 0,
        HeatRateUp = 0,
        HeatRateDown = 0,
        StartAttack = function(ent)
            if ( !ent.SetDoorOpen or ent:GetCarryingDropship() ) then return end

            ent:SetDoorOpen(!ent:GetDoor())
        end,
    })
end

--- Registers the spotlight switch.
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

            ent:SetLightsEnabled(!ent:GetLightsEnabled())
            ent:EmitSound("items/flashlight1.wav", 75, 105)
        end,
    })
end

function ENT:InitWeapons()
    self:AddGunWeapon()
    self:AddDoorWeapon()
    self:AddLightWeapon()
end
