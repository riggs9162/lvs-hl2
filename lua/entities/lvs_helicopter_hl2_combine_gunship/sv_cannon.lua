--- Pulse cannon of the gunship, ported from CNPC_CombineGunship::FireGun, StartCannonBurst, UpdateEnemyTarget, FireCannonRound and StopCannonBurst. The autopilot walks its rounds across the ground towards its enemy like the original; a pilot fires straight at the crosshair.

--- Speed in units per second at which the autopilot's rounds walk towards their target, BASE_STITCH_VELOCITY.
local BASE_STITCH_VELOCITY = 800

--- Closest horizontal distance to an enemy the gunship opens fire at, and where its rounds start walking from when the enemy is close, GUNSHIP_STITCH_MIN.
local GUNSHIP_STITCH_MIN = 512

--- Hits after which a burst no longer chases its target, GUNSHIP_MAX_HITS_PER_BURST.
local GUNSHIP_MAX_HITS_PER_BURST = 5

--- Seconds the cannon may wait before it answers a missile, GUNSHIP_MISSILE_MAX_RESPONSE_TIME.
local GUNSHIP_MISSILE_MAX_RESPONSE_TIME = 0.4

--- Seconds of the warm-up sound before the first burst, from CNPC_CombineGunship::FireGun.
local PREFIRE_TIME = 0.5

--- Seconds between two rounds of a burst. The original only fires once per think, so this comes down to one round every think.
local ROUND_INTERVAL = 0.05

--- Seconds of the pause after a full burst at full health, m_flBurstDelay.
local BURST_DELAY = 2

--- Shortest pause after a full burst, however damaged the gunship is.
local BURST_DELAY_MIN = 0.5

--- Smallest cosine between the muzzle and its target at which a burst starts.
local START_BURST_DOT = 0.9

--- Seconds the enemy's movement is predicted ahead to place the start of a burst.
local BURST_PREDICT_TIME = 2

--- Least and most degrees to the side of the enemy a burst starts walking from.
local BURST_OFFSET_MIN = 15
local BURST_OFFSET_MAX = 30

--- Most degrees per round a walking burst turns towards a player, and towards anything else.
local STITCH_TURN_PLAYER = 6
local STITCH_TURN_OTHER = 30

--- Distance within which a walking burst counts as on its target and stays on it.
local STITCH_LOCK_DISTANCE = 64

--- Seconds of a stitch step, one original think.
local STITCH_STEP_TIME = 0.1

--- Distance a round flies.
local ROUND_DISTANCE = 56756

--- Speed of the tracer, from CNPC_CombineGunship::MakeTracer.
local TRACER_SPEED = 8000

--- Flag of the tracer effect that makes rounds whiz past the listener.
local TRACER_FLAG_WHIZ = 1

--- Spread of the shots fired at a missile, VECTOR_CONE_5DEGREES.
local MISSILE_SHOT_SPREAD = 0.04362

--- Smallest cosine between a missile's heading and the way to the gunship for a shot to bring it down.
local MISSILE_THREAT_DOT = 0.95

--- Farthest a missile can be for a shot to bring it down.
local MISSILE_THREAT_DISTANCE = 1024

--- Damage a shot that brings a missile down deals to it.
local MISSILE_DEFENSE_DAMAGE = 200

--- Damage of a round that hit a player after the burst already hit as often as it may.
local SPENT_PLAYER_DAMAGE = 1

--- Seconds after the last trigger signal of the weapon for which the trigger still counts as held.
local TRIGGER_HOLD_TIME = 0.2

--- Seconds the cannon waits after a missile burst before it may fire again.
local MISSILE_BURST_PAUSE = 0.5

--- Returns the value of a skill setting of the original, or a fallback when it does not exist.
---@param name string Console variable.
---@param fallback number
---@return number value
local function GetSkillSetting(name, fallback)
    local convar = GetConVar(name)
    if ( !convar ) then return fallback end

    return convar:GetFloat()
end

--- Returns the number of rounds in a burst, sk_gunship_burst_size.
---@return number size
local function GetBurstSize()
    return math.floor(GetSkillSetting("sk_gunship_burst_size", 15))
end

--- Returns the health of what the cannon is shooting at.
---@param target Entity
---@return number health
local function GetTargetHealth(target)
    if ( target.GetHP ) then return target:GetHP() end

    return target:Health()
end

--- Classes of the missiles the gunship hunts down like the rpg_missile it hates in the original.
local MISSILE_CLASSES = {
    rpg_missile = true,
    lvs_missile = true,
    lvs_hl2_apc_missile = true,
}

ENT.MissileClasses = MISSILE_CLASSES

--- Returns whether an entity is a missile the gunship shoots down.
---@param ent Entity|nil
---@return boolean bMissile
local function IsMissile(ent)
    return IsValid(ent) and MISSILE_CLASSES[ent:GetClass()] == true
end

--- Prepares the cannon state and its firing sound.
function ENT:InitCannon()
    self.cannonBurstSize = 0
    self.cannonBurstHits = 0
    self.cannonNextAttack = CurTime()
    self.cannonTriggerTime = 0
    self.bCannonFiring = false
    self.bCannonPreFire = false
    self.attackPos = self:GetPos()
    self.attackVelocity = Vector(0, 0, 0)

    self.cannonBulletCallback = function(attacker, trace, dmginfo)
        self:OnCannonRoundHit(trace, dmginfo)
    end
end

--- Records that the pilot or the autopilot holds the trigger of the cannon, sent on every tick the cannon is selected.
---@param bTrigger boolean
function ENT:CannonThink(bTrigger)
    if ( !bTrigger ) then return end

    self.cannonTriggerTime = CurTime()
end

--- Returns whether the trigger of the cannon is held.
---@return boolean bTrigger
function ENT:IsCannonTriggerHeld()
    if ( self:GetSelectedWeapon() != self.WEAPON_CANNON ) then return false end

    return CurTime() - self.cannonTriggerTime < TRIGGER_HOLD_TIME
end

--- Returns what the cannon shoots at: the autopilot's missile or enemy, or nothing while a pilot aims.
---@return Entity|nil enemy
function ENT:GetCannonEnemy()
    if ( !self:GetAI() ) then return nil end
    if ( IsMissile(self.aiMissile) ) then return self.aiMissile end

    local target = self:AIGetTarget()
    if ( !IsValid(target) ) then return nil end

    return target
end

--- Returns whether the cannon is after a missile.
---@return boolean bMissile
function ENT:IsTargettingMissile()
    return IsMissile(self:GetCannonEnemy())
end

--- Returns the point of an enemy the cannon aims at: the centre of a vehicle or of a player in one, or the eyes of anyone else, from CNPC_CombineGunship::UpdateEnemyTarget.
---@param enemy Entity
---@return Vector pos
local function GetEnemyAimPos(enemy)
    if ( enemy.LVS or ( enemy:IsPlayer() and enemy:InVehicle() ) ) then return enemy:WorldSpaceCenter() end

    return enemy:EyePos()
end

--- Returns where the cannon fires its next round, from CNPC_CombineGunship::GetEnemyTarget: at a missile itself, at the walking aim point of the autopilot, or at the pilot's crosshair.
---@return Vector|nil targetPos
function ENT:GetCannonTarget()
    local enemy = self:GetCannonEnemy()

    if ( IsMissile(enemy) ) then return enemy:GetPos() end
    if ( self:GetAI() ) then return self.attackPos end
    if ( !IsValid(self:GetDriver()) ) then return nil end

    return self:GetEyeTrace().HitPos
end

--- Writes a heat value for one weapon slot, which the LVS HUD shows as that weapon's ring.
---@param id number Weapon slot.
---@param heat number Heat between 0 and 1.
function ENT:SetWeaponHeat(id, heat)
    local weapon = self.WEAPONS[1][id]
    if ( !weapon ) then return end

    heat = math.Clamp(heat, 0, 1)
    weapon._CurHeat = heat

    if ( self:GetSelectedWeapon() == id and self:GetNWHeat() != heat ) then
        self:SetNWHeat(heat)
    end
end

--- Shows the progress of the running burst, or the rest of the pause after it, as the cannon's heat.
function ENT:UpdateCannonHeat()
    if ( self.bCannonFiring ) then
        self:SetWeaponHeat(self.WEAPON_CANNON, 1 - self.cannonBurstSize / GetBurstSize())

        return
    end

    local remaining = self.cannonNextAttack - CurTime()

    if ( self.bCannonPreFire or remaining <= 0 or (self.cannonPause or 0) <= 0 ) then
        self:SetWeaponHeat(self.WEAPON_CANNON, 0)

        return
    end

    self:SetWeaponHeat(self.WEAPON_CANNON, remaining / self.cannonPause)
end

--- Starts a burst. The autopilot places the first round to one side of where its enemy is heading and lets the rounds walk towards it, from CNPC_CombineGunship::StartCannonBurst.
---@param burstSize number Rounds in the burst.
function ENT:StartCannonBurst(burstSize)
    self.cannonBurstSize = burstSize
    self.cannonBurstHits = 0
    self.cannonNextAttack = CurTime()
    self.bCannonFiring = true

    local body = self:GetBody()

    if ( IsValid(body) ) then
        self.cannonSound = self.cannonSound or CreateSound(body, "NPC_CombineGunship.CannonSound")
        self.cannonSound:Stop()
        self.cannonSound:Play()
    end

    local enemy = self:GetCannonEnemy()
    if ( !enemy ) then return end

    local enemyPos = enemy:GetPos() + enemy:GetVelocity() * BURST_PREDICT_TIME
    local offsetAngles = (self:WorldSpaceCenter() - enemyPos):Angle()
    local angleOffset = math.random(BURST_OFFSET_MIN, BURST_OFFSET_MAX)

    if ( math.random(0, 1) == 1 ) then
        angleOffset = -angleOffset
    end

    offsetAngles.y = offsetAngles.y + angleOffset
    offsetAngles.p = 0
    offsetAngles.r = 0

    local offsetDir = offsetAngles:Forward()
    local stitchOffset = GetSkillSetting("sk_gunship_burst_dist", 768)
    local enemyDistance = (self:GetPos() - enemy:GetPos()):Length2D()

    if ( enemyDistance < stitchOffset + GUNSHIP_STITCH_MIN ) then
        stitchOffset = GUNSHIP_STITCH_MIN
    end

    self.attackPos = enemyPos + offsetDir * stitchOffset
    self.attackPos.z = enemyPos.z
    self.attackVelocity = -offsetDir * BASE_STITCH_VELOCITY

    sound.EmitHint(bit.bor(SOUND_DANGER, SOUND_CONTEXT_REACT_TO_SOURCE), enemyPos, 512, 0.2, self)
end

--- Ends the burst and waits before the next, the shorter the more damaged the gunship is and the fewer rounds it fired, from CNPC_CombineGunship::StopCannonBurst.
function ENT:StopCannonBurst()
    if ( !self.bCannonFiring and !self.bCannonPreFire ) then return end

    local bWasFiring = self.bCannonFiring
    local healthShare = math.max(self:GetHP(), 0) / self:GetMaxHP()
    local delay = math.Clamp(healthShare * BURST_DELAY, BURST_DELAY_MIN, BURST_DELAY)

    delay = delay * (1 - self.cannonBurstSize / GetBurstSize())

    self.cannonBurstHits = 0
    self.bCannonFiring = false
    self.bCannonPreFire = false
    self.cannonPause = delay
    self.cannonNextAttack = CurTime() + delay
    self.cannonBurstSize = 0

    if ( self.cannonSound ) then
        self.cannonSound:FadeOut(0.05)
    end

    if ( bWasFiring ) then
        self:EmitSound("NPC_CombineGunship.CannonStopSound")
    end
end

--- Moves the autopilot's aim point one step: it walks on at its speed, turning a little towards the enemy on every round, until it reaches the enemy and stays on it, or once the burst has hit often enough walks straight on past it, from CNPC_CombineGunship::UpdateEnemyTarget.
function ENT:UpdateEnemyTarget()
    if ( !self:GetAI() ) then return end

    local enemy = self:GetCannonEnemy()
    local enemyPos = self.attackPos
    local bTargettingPlayer = false

    if ( enemy ) then
        enemyPos = GetEnemyAimPos(enemy)
        bTargettingPlayer = enemy:IsPlayer() or ( enemy.LVS and IsValid(enemy:GetDriver()) )
    end

    local chaseAngles = (enemyPos - self.attackPos):Angle()
    local lastSpeed = self.attackVelocity:Length()
    local lastChaseYaw = self.attackVelocity:Angle().y
    local maxYaw = bTargettingPlayer and STITCH_TURN_PLAYER or STITCH_TURN_OTHER
    local yawDiff = math.Clamp(math.AngleDifference(lastChaseYaw, chaseAngles.y), -maxYaw, maxYaw)
    local bMaxHits = self.cannonBurstHits >= GUNSHIP_MAX_HITS_PER_BURST or ( enemy and GetTargetHealth(enemy) <= 0 )

    chaseAngles.p = 0
    chaseAngles.r = 0

    if ( bMaxHits ) then
        chaseAngles.y = lastChaseYaw
        lastSpeed = BASE_STITCH_VELOCITY
    else
        chaseAngles.y = lastChaseYaw - yawDiff
    end

    if ( !bMaxHits and self.attackPos:DistToSqr(enemyPos) <= STITCH_LOCK_DISTANCE * STITCH_LOCK_DISTANCE ) then
        self.attackPos = enemyPos

        return
    end

    self.attackVelocity = chaseAngles:Forward() * lastSpeed
    self.attackPos = self.attackPos + self.attackVelocity * STITCH_STEP_TIME
    self.attackPos.z = enemyPos.z
end

--- Shows the original muzzle flash on the cannon.
function ENT:DoCannonMuzzleFlash()
    local body = self:GetBody()
    if ( !IsValid(body) ) then return end

    local effectData = EffectData()
    effectData:SetEntity(body)
    effectData:SetAttachment(body:LookupAttachment("muzzle"))
    util.Effect("GunshipMuzzleFlash", effectData)
end

--- Draws the original blue tracer of a round, from CNPC_CombineGunship::MakeTracer.
---@param startPos Vector
---@param endPos Vector
function ENT:DrawCannonTracer(startPos, endPos)
    local effectData = EffectData()
    effectData:SetStart(startPos)
    effectData:SetOrigin(endPos)
    effectData:SetScale(TRACER_SPEED)
    effectData:SetFlags(TRACER_FLAG_WHIZ)
    util.Effect("GunshipTracer", effectData)
end

--- Adjusts a round that hit something: LVS damage type, no damage to the gunship's own parts, the lower damage against players and the original impact effect, from CNPC_CombineGunship::DoImpactEffect.
---@param trace table Trace result of the round.
---@param dmginfo CTakeDamageInfo Damage the round is about to deal.
function ENT:OnCannonRoundHit(trace, dmginfo)
    local hit = trace.Entity

    self:DrawCannonTracer(trace.StartPos, trace.HitPos)

    dmginfo:SetDamageType(DMG_AIRBOAT)

    if ( IsValid(hit) ) then
        if ( hit:GetParent() == self ) then
            dmginfo:SetDamage(0)
        elseif ( hit:IsPlayer() ) then
            dmginfo:SetDamage(self.cannonRoundPlayerDamage)
        end
    end
end

--- Replaces the stock impact of the cannon's rounds with the original one.
---@param trace table Trace result of the round.
---@param damageType number Damage type of the round.
---@return boolean bHandled
function ENT:DoImpactEffect(trace, damageType)
    if ( trace.HitSky ) then return true end

    local effectData = EffectData()
    effectData:SetOrigin(trace.HitPos)
    effectData:SetStart(trace.StartPos)
    effectData:SetSurfaceProp(trace.SurfaceProps)
    effectData:SetDamageType(damageType)
    effectData:SetHitBox(trace.HitBox)
    effectData:SetEntity(trace.Entity)
    util.Effect("ImpactGunship", effectData)

    return true
end

--- Fires one round of the cannon.
---@param src Vector Muzzle position.
---@param dir Vector Direction of the round.
---@param spread number Spread as the sine of half the cone angle.
---@param damage number Damage to everything but players.
---@param playerDamage number Damage to players.
function ENT:FireCannonBullet(src, dir, spread, damage, playerDamage)
    local attacker = self:GetDriver()

    if ( !IsValid(attacker) ) then
        attacker = self
    end

    self.cannonRoundPlayerDamage = playerDamage

    self:FireBullets({
        Attacker = attacker,
        Num = 1,
        Src = src,
        Dir = dir,
        Spread = Vector(spread, spread, 0),
        Tracer = 0,
        TracerName = "none",
        AmmoType = "CombineCannon",
        Damage = damage,
        Force = 1,
        Distance = ROUND_DISTANCE,
        IgnoreEntity = self,
        Callback = self.cannonBulletCallback,
    })
end

--- Shoots at a missile: the shot itself is only for show, but a missile heading straight at the gunship from close by is brought down every other shot, from CNPC_CombineGunship::FireCannonRound.
---@param missile Entity
---@param src Vector Muzzle position.
---@param dir Vector Direction to the missile.
function ENT:FireAtMissile(missile, src, dir)
    self:FireCannonBullet(src, dir, MISSILE_SHOT_SPREAD, 1, 1)

    local threatDir = self:WorldSpaceCenter() - missile:GetPos()
    local threatDistance = threatDir:Length()

    threatDir:Normalize()

    if ( missile:GetForward():Dot(threatDir) <= MISSILE_THREAT_DOT or threatDistance >= MISSILE_THREAT_DISTANCE ) then return end
    if ( math.random(0, 1) != 0 ) then return end

    self:ShootDownMissile(missile, -threatDir)
end

--- Brings a missile down the way its own kind is shot down.
---@param missile Entity
---@param direction Vector Direction of the hit.
function ENT:ShootDownMissile(missile, direction)
    if ( missile.Detonate and missile:GetClass() == "lvs_missile" ) then
        missile:Detonate()

        return
    end

    local dmginfo = DamageInfo()
    dmginfo:SetAttacker(self)
    dmginfo:SetInflictor(self)
    dmginfo:SetDamage(MISSILE_DEFENSE_DAMAGE)
    dmginfo:SetDamageType(bit.bor(DMG_MISSILEDEFENSE, DMG_AIRBOAT))
    dmginfo:SetDamageForce(direction * game.GetAmmoForce(game.GetAmmoID("CombineCannon")))
    dmginfo:SetDamagePosition(missile:GetPos())
    missile:TakeDamageInfo(dmginfo)
end

--- Fires one round of the burst at the cannon's target, or ends the burst when the target has left the muzzle's reach. Once a burst has hit its enemy as often as it may, further rounds only scratch players, from CNPC_CombineGunship::FireCannonRound.
function ENT:FireCannonRound()
    local muzzle = self:GetBodyAttachment("muzzle")
    local targetPos = self:GetCannonTarget()

    if ( !muzzle or !targetPos ) then
        self:StopCannonBurst()

        return
    end

    local aimDir = muzzle.Ang:Forward()
    local toTarget = (targetPos - muzzle.Pos):GetNormalized()
    local enemy = self:GetCannonEnemy()
    local dotCheck = toTarget

    if ( enemy ) then
        dotCheck = (enemy:GetPos() - muzzle.Pos):GetNormalized()
    end

    if ( dotCheck:Dot(aimDir) < self.CannonFireDot ) then
        self:StopCannonBurst()

        return
    end

    self:DoCannonMuzzleFlash()
    self.cannonNextAttack = CurTime() + ROUND_INTERVAL

    if ( IsMissile(enemy) ) then
        self:FireAtMissile(enemy, muzzle.Pos, toTarget)

        return
    end

    local previousHealth = enemy and GetTargetHealth(enemy)
    local playerDamage = GetSkillSetting("sk_npc_dmg_gunship_to_plr", 3)

    if ( self.cannonBurstHits >= GUNSHIP_MAX_HITS_PER_BURST ) then
        playerDamage = SPENT_PLAYER_DAMAGE
    end

    self.cannonBurstSize = self.cannonBurstSize - 1
    self:FireCannonBullet(muzzle.Pos, toTarget, 0, GetSkillSetting("sk_npc_dmg_gunship", 40), playerDamage)

    if ( enemy and IsValid(enemy) and GetTargetHealth(enemy) != previousHealth ) then
        self.cannonBurstHits = self.cannonBurstHits + 1
    end
end

--- Answers a new missile at once, from CNPC_CombineGunship::DoCombat.
function ENT:OnSeeMissile()
    local now = CurTime()
    if ( self.cannonNextAttack <= now or self.cannonNextAttack - now <= GUNSHIP_MISSILE_MAX_RESPONSE_TIME ) then return end

    self.cannonNextAttack = now + GUNSHIP_MISSILE_MAX_RESPONSE_TIME
end

--- Starts a burst when the trigger is held and the pause is over: first the warm-up sound, then, once the target is in front of the muzzle, the burst itself. The autopilot holds its fire at enemies it cannot see or that are right below it, and answers missiles without warming up, from CNPC_CombineGunship::FireGun.
function ENT:FireGun()
    if ( self.bCannonFiring or self:GetGroundAttacking() ) then return end

    local now = CurTime()
    local bAI = self:GetAI()
    local enemy = self:GetCannonEnemy()
    local bTrigger = self:IsCannonTriggerHeld()

    if ( !bTrigger or ( bAI and !enemy ) ) then
        if ( self.bCannonPreFire and !bAI ) then
            self.bCannonPreFire = false
        end

        return
    end

    if ( now <= self.cannonNextAttack ) then return end

    local bTargettingMissile = IsMissile(enemy)

    if ( !bTargettingMissile and !self.bCannonPreFire ) then
        self.bCannonPreFire = true
        self.cannonNextAttack = now + PREFIRE_TIME
        self:EmitSound("NPC_CombineGunship.CannonStartSound")

        return
    end

    if ( enemy ) then
        if ( !self:AICanSee(enemy) ) then return end
        if ( !bTargettingMissile and (self:GetPos() - enemy:GetPos()):Length2D() < GUNSHIP_STITCH_MIN ) then return end
    end

    local muzzle = self:GetBodyAttachment("muzzle")
    local targetPos = self:GetCannonTarget()
    if ( !muzzle or !targetPos ) then return end

    if ( (targetPos - muzzle.Pos):GetNormalized():Dot(muzzle.Ang:Forward()) > START_BURST_DOT ) then
        self:StartCannonBurst(GetBurstSize())
    end
end

--- Runs the cannon on one think: fires the next round of a running burst, ends it when it is spent or the trigger is let go, or else keeps the aim on the enemy and tries to start a burst, from CNPC_CombineGunship::DoCombat.
function ENT:CannonCombat()
    local enemy = self:GetCannonEnemy()

    if ( self.bCannonFiring ) then
        if ( !self:GetAI() and !self:IsCannonTriggerHeld() ) then
            self:StopCannonBurst()
        elseif ( self.cannonBurstSize > 0 and CurTime() > self.cannonNextAttack ) then
            self:UpdateEnemyTarget()
            self:FireCannonRound()
        elseif ( self.cannonBurstSize < 1 ) then
            self:StopCannonBurst()

            if ( IsMissile(enemy) ) then
                self.cannonNextAttack = CurTime() + MISSILE_BURST_PAUSE
            end
        end
    elseif ( enemy ) then
        self.attackPos = GetEnemyAimPos(enemy)
    end

    self:FireGun()
    self:UpdateCannonHeat()
end

--- Silences the cannon for good, as when the gunship is shot down.
function ENT:CannonShutdown()
    self:StopCannonBurst()

    if ( self.cannonSound ) then
        self.cannonSound:Stop()
    end
end
