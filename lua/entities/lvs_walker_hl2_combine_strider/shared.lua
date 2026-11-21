ENT.Base = "lvs_base_fakehover"
ENT.PrintName = "Combine Strider"
ENT.Author = "Riggs"
ENT.Information = "Combine Strider from Half Life 2 + Episodes. Walks on its three legs, mows down infantry with its minigun, blasts vehicles with its warp cannon and skewers whoever comes too close. Jump crouches and stands."
ENT.Category = "[LVS] - Half Life 2"
ENT.IconOverride = "materials/entities/lvs/hl2/combine_strider.png"

ENT.VehicleCategory = "Half Life 2"
ENT.VehicleSubCategory = "Combine"

ENT.Spawnable = true
ENT.AdminSpawnable = false

ENT.MDL = "models/combine_strider.mdl"

ENT.AITEAM = 1

--- Health of the original, sk_strider_health.
ENT.MaxHealth = 350

ENT.DisableBallistics = true

--- Height the strider is spawned at, so that it stands on its feet right away.
ENT.SpawnNormalOffset = 490

--- Speed the throttle of the HUD is measured against, about the ground speed of the original's run animation while standing. The strider itself walks and runs exactly as fast as its animations carry it.
ENT.MaxVelocityX = 200
ENT.MaxVelocityY = 200
ENT.BoostAddVelocityX = 0
ENT.BoostAddVelocityY = 0

--- The original's body height pose parameter is measured from the top of this model, GetMaxHeightModel.
ENT.ModelHeight = 500

--- Body height while standing and while crouching, GetMaxHeight and GetMinHeight.
ENT.StandHeight = 490
ENT.CrouchHeight = 200

--- How the strider hangs under the Combine dropship: its model where the original's npc_strider hangs, a hundred units down, with its body the model's height less the stand height below that.
ENT.HL2DropshipCargo = {
    offset = Vector(0, 0, -110),
    angles = Angle(0, 0, 0),
}

--- Weapon slot of the minigun.
ENT.WEAPON_MINIGUN = 1

--- Weapon slot of the warp cannon.
ENT.WEAPON_CANNON = 2

--- Weapon slot of the skewer.
ENT.WEAPON_SKEWER = 3

--- Colour of a crosshair the weapon cannot use right now.
local color_red = Color(255, 0, 0)

function ENT:OnSetupDataTables()
    self:AddDT("Float", "BodyHeight")
    self:AddDT("Float", "SkeletonZ")
    self:AddDT("Bool", "CannonCharging")
    self:AddDT("Vector", "CannonHitPos")
    self:AddDT("Vector", "MinigunAimPos")
    self:AddDT("Entity", "Carrier")
    self:AddDT("Float", "NextCannonTime")
end

--- Returns the dropship carrying the strider, if any.
---@return Entity|nil carrier
function ENT:GetCarryingDropship()
    local carrier = self:GetCarrier()
    if ( !IsValid(carrier) ) then return nil end

    return carrier
end

--- Draws the crosshair where the minigun points, and the aim in the middle.
---@param ent Entity Strider.
local function PaintMinigunCrosshair(ent)
    local muzzle = ent:GetAttachment(ent:LookupAttachment("MiniGun"))
    local aimPos = ent:GetEyeTrace().HitPos

    if ( muzzle ) then
        local trace = util.TraceLine({
            start = muzzle.Pos,
            endpos = muzzle.Pos + muzzle.Ang:Forward() * 50000,
            filter = ent:GetCrosshairFilterEnts(),
        })

        ent:PaintCrosshairOuter(trace.HitPos:ToScreen(), color_white)
    end

    ent:PaintCrosshairCenter(aimPos:ToScreen(), color_white)
    ent:LVSPaintHitMarker(aimPos:ToScreen())
end

--- Draws the crosshair of the warp cannon, red while it recharges.
---@param ent Entity Strider.
local function PaintCannonCrosshair(ent)
    local aimPos = ent:GetEyeTrace().HitPos
    local bReady = CurTime() >= ent:GetNextCannonTime() and !ent:GetCannonCharging()

    ent:PaintCrosshairSquare(aimPos:ToScreen(), bReady and color_white or color_red)
    ent:LVSPaintHitMarker(aimPos:ToScreen())
end

--- Plays the sound of switching to a weapon.
---@param ent Entity
local function PlaySelectSound(ent)
    ent:EmitSound("physics/metal/weapon_impact_soft3.wav")
end

--- Registers the minigun, which fires in bursts as long as the trigger is held.
function ENT:AddMinigunWeapon()
    self:AddWeapon({
        Icon = Material("lvs/weapons/mg.png"),
        Ammo = -1,
        Delay = 0,
        HeatRateUp = 0,
        HeatRateDown = 0,
        OnThink = function(ent, bActive)
            if ( ent.SetMinigunTrigger ) then
                ent:SetMinigunTrigger(bActive and ent:WeaponsShouldFire() == true)
            end
        end,
        OnSelect = PlaySelectSound,
        HudPaint = PaintMinigunCrosshair,
    })
end

--- Registers the warp cannon, which charges for a moment and then blasts where the pilot aims.
function ENT:AddCannonWeapon()
    self:AddWeapon({
        Icon = Material("lvs/weapons/warplaser.png"),
        UseableByAI = false,
        Ammo = -1,
        Delay = 0,
        HeatRateUp = 0,
        HeatRateDown = 0,
        StartAttack = function(ent)
            if ( ent.TryFireCannon ) then
                ent:TryFireCannon()
            end
        end,
        OnThink = function(ent)
            if ( ent.UpdateCannonHeat ) then
                ent:UpdateCannonHeat()
            end
        end,
        OnSelect = PlaySelectSound,
        HudPaint = PaintCannonCrosshair,
    })
end

--- Registers the skewer, which stabs with the left leg.
function ENT:AddSkewerWeapon()
    self:AddWeapon({
        Icon = Material("lvs/weapons/dropship_grabber.png"),
        UseableByAI = false,
        Ammo = -1,
        Delay = 0,
        HeatRateUp = 0,
        HeatRateDown = 0,
        StartAttack = function(ent)
            if ( ent.TryStomp ) then
                ent:TryStomp()
            end
        end,
        OnThink = function(ent)
            if ( ent.UpdateStompHeat ) then
                ent:UpdateStompHeat()
            end
        end,
        OnSelect = PlaySelectSound,
    })
end

function ENT:InitWeapons()
    self:AddMinigunWeapon()
    self:AddCannonWeapon()
    self:AddSkewerWeapon()
end

--- Returns the vertical offset of the model's origin above the entity's origin, the middle of the body: the original keeps its origin at the top of the model and lowers the body below it with the body height pose parameter.
---@param height number Body height.
---@return number offset
function ENT:GetSkeletonOffset(height)
    return self.ModelHeight - height
end

--- Returns an attachment where it is on the model as drawn. The clients draw the model raised by its skeleton offset, so the server raises its attachments by the same.
---@param name string
---@return table|nil attachment
function ENT:GetStriderAttachment(name)
    local attachment = self:GetAttachment(self:LookupAttachment(name))
    if ( CLIENT or !attachment ) then return attachment end

    attachment.Pos = attachment.Pos + self:GetUp() * self:GetSkeletonOffset(self:GetHeight())

    return attachment
end
