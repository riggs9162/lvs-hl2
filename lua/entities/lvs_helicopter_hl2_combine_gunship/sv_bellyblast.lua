--- Belly cannon of the gunship, ported from CNPC_CombineGunship::StartGroundAttack, ManageWarningBeam, StopGroundAttack, DoGroundAttackExplosion and DoBellyBlastDamage: it charges for three seconds while it hangs still in the air and then blasts the ground straight below.

--- Seconds the belly cannon charges before it fires.
local CHARGE_TIME = 3

--- Seconds after a blast before the belly cannon can charge again.
local RECHARGE_TIME = 4

--- Seconds after a blast before the pulse cannon can fire again.
local CANNON_PAUSE = 2

--- Share of the velocity the gunship loses per think while it charges, so that it comes to a stop over its target.
local CHARGE_DRAG = 0.05

--- Upward kick the blast gives the gunship.
local RECOIL_SPEED = 200

--- Radius of the blast, GUNSHIP_BELLY_BLAST_RADIUS.
local BLAST_RADIUS = 256

--- Height of the blast above the ground.
local BLAST_HEIGHT = 96

--- Half the width of the beam that hits everything between the gunship and the ground.
local BEAM_HALF_WIDTH = 16

--- Damage of the blast to everything but players.
local BLAST_DAMAGE = 150

--- Damage of the blast to a player at its centre, falling to nothing at the edge of BLAST_PLAYER_RANGE.
local BLAST_PLAYER_DAMAGE = 200

--- Distance from the centre of the blast at which it no longer hurts players.
local BLAST_PLAYER_RANGE = 300

--- Force the blast throws things with.
local BLAST_FORCE = 25000

--- Most solid things the charging beam punches through on its way down, BELLY_BLAST_MAX_PUNCH.
local BEAM_MAX_PUNCH = 5

--- Seconds before the blast in which the charging beam splashes energy where it punches through.
local BEAM_SPLASH_TIME = 2

--- Height above its target at which the gunship charges, GUNSHIP_BELLYBLAST_TARGET_HEIGHT.
local TARGET_HEIGHT = 512

--- Farthest from its charging point the gunship may be to start charging.
local TARGET_REACH = 100

--- Highest speed relative to its target at which the gunship may start charging.
local TARGET_SPEED = 200

--- Distance the belly cannon's straight-down trace reaches.
local TRACE_LENGTH = 56756

--- Prepares the state of the belly cannon.
function ENT:InitGroundAttack()
    self.groundAttackTime = 0
    self.nextGroundAttack = 0
    self.groundAttackTarget = nil
end

--- Returns where the gunship hangs to blast its ground attack target.
---@return Vector|nil pos
function ENT:GetGroundAttackPosition()
    local target = self.groundAttackTarget
    if ( !IsValid(target) ) then return nil end

    return target:GetPos() + Vector(0, 0, TARGET_HEIGHT)
end

--- Picks something on the ground for the autopilot to fly over and blast, or clears it.
---@param target Entity|nil
function ENT:SetGroundAttackTarget(target)
    self.groundAttackTarget = target
end

--- Returns whether the belly cannon can charge.
---@return boolean bReady
function ENT:CanGroundAttack()
    if ( self:GetGroundAttacking() or self:IsDestroyed() or self.bCannonFiring ) then return false end

    return CurTime() >= self.nextGroundAttack
end

--- Starts charging the belly cannon when the pilot pulls the trigger and it is ready.
function ENT:TryGroundAttack()
    if ( self:GetAI() or !self:CanGroundAttack() ) then return end

    self:StartGroundAttack()
end

--- Shows the charge, or the rest of the wait until the next one, as the belly cannon's heat.
function ENT:UpdateGroundAttackHeat()
    local now = CurTime()

    if ( self:GetGroundAttacking() ) then
        self:SetWeaponHeat(self.WEAPON_BELLY_CANNON, 1 - (self.groundAttackTime - now) / CHARGE_TIME)

        return
    end

    self:SetWeaponHeat(self.WEAPON_BELLY_CANNON, math.max(self.nextGroundAttack - now, 0) / RECHARGE_TIME)
end

--- Returns where the blast strikes: straight below the belly cannon, at the height of the ground attack target if there is one, from CNPC_CombineGunship::GetGroundAttackHitPosition.
---@return Vector|nil hitPos
function ENT:GetGroundAttackTargetPos()
    local hitPos = self:GetGroundAttackHitPosition()
    if ( !hitPos ) then return nil end

    local target = self.groundAttackTarget

    if ( IsValid(target) ) then
        return Vector(hitPos.x, hitPos.y, target:WorldSpaceCenter().z)
    end

    return hitPos
end

--- Starts charging: the beam grows below the gunship, it warns everything below and slows to a stop, from CNPC_CombineGunship::StartGroundAttack.
function ENT:StartGroundAttack()
    local hitPos = self:GetGroundAttackTargetPos()
    if ( !hitPos ) then return end

    self:SetGroundAttacking(true)
    self:SetGroundAttackHitPos(hitPos)
    self.groundAttackTime = CurTime() + CHARGE_TIME
    self.flightGeneralDrag = CHARGE_DRAG

    local effectData = EffectData()
    effectData:SetEntity(self)
    effectData:SetOrigin(self:GetPos())
    util.Effect("lvs_hl2_gunship_bellyblast", effectData, true, true)

    self:EmitSound("NPC_Strider.Charge")
    sound.EmitHint(SOUND_DANGER, hitPos, 1024, 0.5, self)
end

--- Returns the entities the belly cannon must not hurt: the gunship and everything that belongs to it.
---@return table filter
function ENT:GetGroundAttackFilter()
    return self:GetCrosshairFilterEnts()
end

--- Lets the charging beam punch through whatever stands between the belly cannon and the ground, stinging it and throwing sparks where it comes out, from CNPC_CombineGunship::ManageWarningBeam.
---@param hitPos Vector Where the blast is going to strike.
function ENT:ManageWarningBeam(hitPos)
    local muzzle = self:GetBodyAttachment("bellygun")
    if ( !muzzle ) then return end

    local filter = table.Copy(self:GetGroundAttackFilter())
    local dir = (hitPos - muzzle.Pos):GetNormalized()
    local remaining = self.groundAttackTime - CurTime()

    if ( IsValid(self.groundAttackTarget) ) then
        filter[#filter + 1] = self.groundAttackTarget
    end

    local trace = util.TraceLine({start = muzzle.Pos, endpos = hitPos, mask = MASK_SOLID, filter = filter})

    for _ = 1, BEAM_MAX_PUNCH do
        if ( trace.Fraction >= 1 or trace.HitPos:DistToSqr(hitPos) < 1 ) then return end

        local hit = trace.Entity

        if ( IsValid(hit) ) then
            local dmginfo = DamageInfo()
            dmginfo:SetAttacker(self)
            dmginfo:SetInflictor(self)
            dmginfo:SetDamage(1)
            dmginfo:SetDamageType(DMG_ENERGYBEAM)
            dmginfo:SetDamagePosition(trace.HitPos + trace.HitNormal * 64)
            dmginfo:SetDamageForce((hit:WorldSpaceCenter() - trace.HitPos):GetNormalized() * 100)
            hit:TakeDamageInfo(dmginfo)
        end

        local punchStart = trace.HitPos + dir

        trace = util.TraceLine({start = punchStart, endpos = hitPos, mask = MASK_SOLID, filter = filter})

        if ( trace.StartSolid ) then
            local punchEnd = punchStart + dir * ((punchStart - trace.HitPos):Length() * trace.FractionLeftSolid)
            local back = util.TraceLine({start = punchEnd, endpos = punchEnd - dir * 2, mask = MASK_SOLID, filter = filter})

            trace = util.TraceLine({start = punchEnd, endpos = hitPos, mask = MASK_SOLID, filter = filter})

            if ( remaining <= BEAM_SPLASH_TIME ) then
                local splash = EffectData()
                splash:SetOrigin(back.HitPos + dir * 8)
                splash:SetNormal(back.HitNormal)
                util.Effect("AR2Impact", splash)
            end

            local sparks = EffectData()
            sparks:SetOrigin(back.HitPos)
            sparks:SetNormal(back.HitNormal)
            sparks:SetMagnitude(CHARGE_TIME - remaining)
            sparks:SetScale(CHARGE_TIME + 0.5 - remaining)
            util.Effect("Sparks", sparks)
        end
    end
end

--- Returns whether something hit by the blast should be dissolved once it has no health left: loose physics objects and ragdolls, but not vehicles, players or anything held by another entity.
---@param ent Entity
---@return boolean bDissolve
local function ShouldDissolve(ent)
    if ( ent.LVS or ent:IsPlayer() or ent:IsNPC() or IsValid(ent:GetParent()) ) then return false end
    if ( ent:GetMoveType() != MOVETYPE_VPHYSICS or ent:Health() > 0 ) then return false end

    return true
end

--- Hurts and dissolves everything inside a box on the blast's centre, from CNPC_CombineGunship::DoBellyBlastDamage.
---@param trace table Trace of the blast down to the ground.
---@param mins Vector Lower corner of the box relative to the blast's centre.
---@param maxs Vector Upper corner of the box relative to the blast's centre.
---@param hurt table Entities already hurt by this blast, which are skipped.
function ENT:DoBellyBlastDamage(trace, mins, maxs, hurt)
    local attacker = self:GetDriver()
    local filter = {}

    if ( !IsValid(attacker) ) then
        attacker = self
    end

    for _, ent in ipairs(self:GetGroundAttackFilter()) do
        filter[ent] = true
    end

    for _, ent in ipairs(ents.FindInBox(trace.HitPos + mins, trace.HitPos + maxs)) do
        if ( filter[ent] or hurt[ent] or !IsValid(ent) or ent:IsWorld() ) then continue end

        hurt[ent] = true

        local damage = BLAST_DAMAGE

        if ( ent:IsPlayer() ) then
            local distance = ent:GetPos():Distance(trace.HitPos)

            damage = math.Remap(math.Clamp(distance, 0, BLAST_PLAYER_RANGE), 0, BLAST_PLAYER_RANGE, BLAST_PLAYER_DAMAGE, 0)
        end

        local dmginfo = DamageInfo()
        dmginfo:SetAttacker(attacker)
        dmginfo:SetInflictor(self)
        dmginfo:SetDamage(damage)
        dmginfo:SetDamageType(DMG_DISSOLVE)
        dmginfo:SetDamagePosition(trace.HitPos + trace.HitNormal * 64)
        dmginfo:SetDamageForce((ent:WorldSpaceCenter() - trace.HitPos):GetNormalized() * BLAST_FORCE)
        ent:TakeDamageInfo(dmginfo)

        local ground = util.TraceLine({
            start = ent:GetPos(),
            endpos = ent:GetPos() - Vector(0, 0, 256),
            mask = MASK_SOLID,
            filter = ent,
        })

        local effectData = EffectData()
        effectData:SetOrigin(ground.HitPos)
        effectData:SetNormal(ground.HitNormal)
        effectData:SetRadius(BLAST_RADIUS * 0.5)
        util.Effect("AR2Explosion", effectData)

        if ( IsValid(ent) and ShouldDissolve(ent) ) then
            ent:Dissolve()
        end
    end
end

--- Fires the blast: it scorches the ground below and hits everything in the beam and in a wide, flat ring around its centre, from CNPC_CombineGunship::DoGroundAttackExplosion.
function ENT:DoGroundAttackExplosion()
    local muzzle = self:GetBodyAttachment("bellygun")
    if ( !muzzle ) then return end

    local src = muzzle.Pos
    local target = self.groundAttackTarget

    if ( IsValid(target) ) then
        src = target:GetPos()
    end

    local filter = self:GetGroundAttackFilter()
    local trace = util.TraceLine({start = src, endpos = src - Vector(0, 0, TRACE_LENGTH), mask = MASK_SHOT, filter = filter})

    util.Decal("Scorch", trace.HitPos + trace.HitNormal, trace.HitPos - trace.HitNormal, filter)

    if ( trace.HitWorld ) then
        local effectData = EffectData()
        effectData:SetOrigin(trace.HitPos)
        effectData:SetNormal(trace.HitNormal)
        effectData:SetRadius(BLAST_RADIUS)
        util.Effect("AR2Explosion", effectData)
    end

    local hurt = {}
    local beamHeight = muzzle.Pos.z - trace.HitPos.z

    self:DoBellyBlastDamage(trace, Vector(-BEAM_HALF_WIDTH, -BEAM_HALF_WIDTH, 0), Vector(BEAM_HALF_WIDTH, BEAM_HALF_WIDTH, beamHeight), hurt)
    self:DoBellyBlastDamage(trace, Vector(-BLAST_RADIUS, -BLAST_RADIUS, 0), Vector(BLAST_RADIUS, BLAST_RADIUS, BLAST_HEIGHT), hurt)
end

--- Ends the charge, and fires the blast if told to, from CNPC_CombineGunship::StopGroundAttack.
---@param bDoAttack boolean Whether to fire the blast.
function ENT:StopGroundAttack(bDoAttack)
    if ( !self:GetGroundAttacking() ) then return end

    local now = CurTime()

    self:SetGroundAttacking(false)
    self.nextGroundAttack = now + RECHARGE_TIME
    self.cannonNextAttack = math.max(self.cannonNextAttack or 0, now + CANNON_PAUSE)
    self.flightGeneralDrag = nil

    if ( bDoAttack ) then
        self:EmitSound("NPC_Strider.Shoot")
        self:ApplyVelocityImpulse(Vector(0, 0, RECOIL_SPEED))
        self:DoGroundAttackExplosion()
    end

    self.groundAttackTarget = nil
end

--- Runs the belly cannon on one think: the autopilot starts charging once it hangs still over its target, and a charging cannon keeps its beam on the ground below and fires when the charge is full, from CNPC_CombineGunship::DoCombat.
function ENT:GroundAttackCombat()
    local chargePos = self:GetGroundAttackPosition()

    if ( chargePos and !self:GetGroundAttacking() and self:CanGroundAttack() ) then
        local velocity = self:GetVelocity()
        local targetVelocity = self.groundAttackTarget:GetVelocity()

        velocity.z = 0
        targetVelocity.z = 0

        if ( self:GetPos():Distance(chargePos) < TARGET_REACH and (velocity - targetVelocity):Length() < TARGET_SPEED ) then
            self:StartGroundAttack()
        end
    end

    if ( !self:GetGroundAttacking() ) then return end

    local hitPos = self:GetGroundAttackTargetPos()

    if ( hitPos ) then
        self:SetGroundAttackHitPos(hitPos)
        self:ManageWarningBeam(hitPos)
    end

    if ( CurTime() > self.groundAttackTime ) then
        self:StopGroundAttack(true)
    end
end
