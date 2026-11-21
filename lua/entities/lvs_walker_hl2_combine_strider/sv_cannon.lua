--- Warp cannon of the strider, ported from CNPC_Strider::AimCannonAt, FireCannon and CannonHitThink, the TASK_STRIDER_AIM task and CreateConcussiveBlast in weapon_cguard.cpp: the head charges for a moment while it aims, fires a beam and a fifth of a second later the point it hit bursts in a blast that dissolves whatever it kills.

--- Seconds the cannon charges and aims before it fires, from SCHED_STRIDER_RANGE_ATTACK2.
local CHARGE_TIME = 1.25

--- Seconds between the shot and the blast at the point it hit.
local HIT_DELAY = 0.2

--- Seconds before the cannon can fire again, m_nextShootTime.
local RECHARGE_TIME = 5

--- How fast the head closes in on its aim on every think, and the fewest degrees it turns by.
local AIM_SPEED = 16
local AIM_MIN_STEP = 5

--- Seconds of a think, which the original's aiming always assumes.
local AIM_INTERVAL = 0.1

--- Turning limits of the head, the ranges of its yaw and pitch pose parameters.
local AIM_YAW_MIN, AIM_YAW_MAX = -37.82, 45.34
local AIM_PITCH_MIN, AIM_PITCH_MAX = -30.3, 49.8

--- Distance the blast lands off the surface it hit.
local BLAST_SURFACE_OFFSET = 16

--- Damage and radius of the blast, from CConcussiveBlast::Explode.
local BLAST_DAMAGE = 200
local BLAST_RADIUS = 256

--- Strength of the strider's blast, which scales its shockwave.
local BLAST_MAGNITUDE = 2.5

--- Seconds the minigun holds back while the cannon charges, and after the blast.
local MINIGUN_HOLD_CHARGE = 5
local MINIGUN_HOLD_HIT = 1

--- Distance the cannon's beam reaches.
local BEAM_LENGTH = 56756

--- Prepares the state of the cannon.
function ENT:InitCannon()
    self.cannonAimYaw = 0
    self.cannonAimPitch = 0
    self:SetNextCannonTime(0)
    self:SetCannonCharging(false)
end

--- Returns whether the cannon is ready to charge.
---@return boolean bReady
function ENT:CanFireCannon()
    if ( self:GetCannonCharging() or CurTime() < self:GetNextCannonTime() ) then return false end
    if ( self:GetHP() <= 0 or self:GetCarryingDropship() or self:IsStomping() ) then return false end

    return true
end

--- Starts charging the cannon at the pilot's crosshair when it is ready.
function ENT:TryFireCannon()
    if ( self:GetAI() or !self:CanFireCannon() ) then return end

    self:StartCannonCharge(nil)
end

--- Returns the point the cannon aims at: the autopilot's target, or the pilot's crosshair.
---@return Vector pos
function ENT:GetCannonAimPos()
    if ( IsValid(self.cannonTarget) ) then return self.cannonTarget:WorldSpaceCenter() end

    return self:GetEyeTrace().HitPos
end

--- Starts charging: the minigun stops, the head lines up from the front and the charge glows on the gun, from TASK_STRIDER_AIM.
---@param target Entity|nil Target of the autopilot, or nil for the pilot's crosshair.
function ENT:StartCannonCharge(target)
    self.cannonTarget = target
    self.cannonFireTime = CurTime() + CHARGE_TIME
    self.cannonAimYaw = 0
    self.cannonAimPitch = 0

    self:SetPoseParameter("yaw", 0)
    self:SetPoseParameter("pitch", 0)
    self:SetCannonHitPos(self:GetCannonAimPos())
    self:SetCannonCharging(true)
    self:HoldMinigun(MINIGUN_HOLD_CHARGE)

    local effectData = EffectData()
    effectData:SetEntity(self)
    effectData:SetOrigin(self:GetPos())
    util.Effect("lvs_hl2_strider_cannon", effectData, true, true)

    self:EmitSound("NPC_Strider.Charge")
end

--- Turns the head one step towards a point, closing in fast while it is far off and slowly once it is close, from CNPC_Strider::AimCannonAt.
---@param pos Vector
function ENT:AimCannonAt(pos)
    local gun = self:GetStriderAttachment("BigGun")
    if ( !gun ) then return end

    local localAngles = WorldToLocal(pos, angle_zero, gun.Pos, gun.Ang):Angle()
    local pitchDiff = math.NormalizeAngle(localAngles.p)
    local yawDiff = math.NormalizeAngle(localAngles.y)
    local yawStep = math.max(math.abs(AIM_SPEED * AIM_INTERVAL * yawDiff), AIM_MIN_STEP)
    local pitchStep = math.max(math.abs(AIM_SPEED * AIM_INTERVAL * pitchDiff), AIM_MIN_STEP)

    self.cannonAimYaw = math.Clamp(math.Approach(self.cannonAimYaw, self.cannonAimYaw + yawDiff, yawStep), AIM_YAW_MIN, AIM_YAW_MAX)
    self.cannonAimPitch = math.Clamp(math.Approach(self.cannonAimPitch, self.cannonAimPitch + pitchDiff, pitchStep), AIM_PITCH_MIN, AIM_PITCH_MAX)

    self:SetPoseParameter("yaw", self.cannonAimYaw)
    self:SetPoseParameter("pitch", self.cannonAimPitch)
end

--- Stops a charge without firing, as when the strider dies or is picked up.
function ENT:AbortCannon()
    if ( !self:GetCannonCharging() ) then return end

    self:SetCannonCharging(false)
    self.cannonTarget = nil
end

--- Fires the cannon: the beam reaches out along the head's aim to the first thing in the way and the blast follows a moment later, from CNPC_Strider::FireCannon.
function ENT:FireCannon()
    local now = CurTime()

    self:SetCannonCharging(false)
    self:SetNextCannonTime(now + RECHARGE_TIME)

    local gun = self:GetStriderAttachment("BigGun")
    if ( !gun ) then return end

    local direction = (self:GetCannonAimPos() - gun.Pos):GetNormalized()
    local trace = util.TraceLine({
        start = gun.Pos,
        endpos = gun.Pos + direction * BEAM_LENGTH,
        mask = MASK_SHOT,
        filter = self:GetCrosshairFilterEnts(),
    })

    local blastPos = trace.HitPos + trace.HitNormal * BLAST_SURFACE_OFFSET
    local blastNormal = trace.HitNormal

    self:SetCannonHitPos(trace.HitPos)
    self:EmitSound("NPC_Strider.Shoot")

    timer.Simple(HIT_DELAY, function()
        if ( IsValid(self) ) then
            self:CannonHit(blastPos, blastNormal)
        end
    end)
end

--- Bursts the point the beam hit: a shockwave and a blast that hurts and dissolves everything around it, from CNPC_Strider::CannonHitThink and CConcussiveBlast::Explode.
---@param pos Vector
---@param normal Vector
function ENT:CannonHit(pos, normal)
    local effectData = EffectData()
    effectData:SetOrigin(pos)
    effectData:SetNormal(normal)
    effectData:SetMagnitude(BLAST_MAGNITUDE)
    util.Effect("lvs_hl2_strider_blast", effectData, true, true)

    local attacker = self:GetDriver()

    if ( !IsValid(attacker) ) then
        attacker = self
    end

    local dmginfo = DamageInfo()
    dmginfo:SetAttacker(attacker)
    dmginfo:SetInflictor(self)
    dmginfo:SetDamage(BLAST_DAMAGE)
    dmginfo:SetDamageType(bit.bor(DMG_BLAST, DMG_DISSOLVE))
    util.BlastDamageInfo(dmginfo, pos, BLAST_RADIUS)

    self.cannonTarget = nil
    self:HoldMinigun(MINIGUN_HOLD_HIT)
end

--- Aims a charging cannon and fires it once the charge is full.
---@param interval number Seconds since the last think.
function ENT:CannonThink(interval)
    if ( !self:GetCannonCharging() ) then return end

    if ( self:GetHP() <= 0 or self:GetCarryingDropship() or ( self.cannonTarget != nil and !IsValid(self.cannonTarget) ) ) then
        self:AbortCannon()

        return
    end

    local aimPos = self:GetCannonAimPos()

    self:SetCannonHitPos(aimPos)
    self:AimCannonAt(aimPos)

    if ( CurTime() >= self.cannonFireTime ) then
        self:FireCannon()
    end
end

--- Shows the charge, or the rest of the recharge, as the cannon's heat.
function ENT:UpdateCannonHeat()
    local now = CurTime()

    if ( self:GetCannonCharging() ) then
        self:SetWeaponHeat(self.WEAPON_CANNON, 1 - math.max(self.cannonFireTime - now, 0) / CHARGE_TIME)

        return
    end

    self:SetWeaponHeat(self.WEAPON_CANNON, math.max(self:GetNextCannonTime() - now, 0) / RECHARGE_TIME)
end
