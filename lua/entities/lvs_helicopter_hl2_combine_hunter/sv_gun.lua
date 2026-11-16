--- Pulse gun of the hunter-chopper, ported from FireGun and its DoGunIdle, DoGunCharging and DoGunFiring states of the Half-Life 2 attack helicopter (npc_attackchopper.cpp).

--- The gun waits for the trigger and for its cooldown.
local GUN_STATE_IDLE = 0

--- The gun plays its charge sound and is about to fire.
local GUN_STATE_CHARGING = 1

--- The gun fires its bursts until none are left.
local GUN_STATE_FIRING = 2

--- Seconds between two gun thinks, which is also the time between two bursts.
local GUN_THINK_INTERVAL = 0.1

--- Degrees the gun can turn per think on each axis.
local GUN_TURN_STEP = 12

--- Average seconds between the charge sound and the first burst, the original g_helicopter_chargetime.
local GUN_CHARGE_TIME = 2

--- Average seconds the gun rests after firing, the original g_helicopter_idletime.
local GUN_IDLE_TIME = 3

--- Share of the charge and idle times that is randomised in either direction.
local GUN_TIME_VARIANCE = 0.1

--- Extra seconds of rest for every burst fired beyond the minimum burst count.
local GUN_IDLE_TIME_PER_BURST = 0.1

--- Fewest bursts fired after charging, the original sk_helicopter_burstcount; the most is twice as many.
local GUN_BURST_COUNT = 12

--- Rounds fired per burst, the original sk_helicopter_roundsperburst.
local GUN_ROUNDS_PER_BURST = 5

--- Spread of the rounds as the sine of half the original 20 degree sk_helicopter_firingcone.
local GUN_SPREAD = math.sin(math.rad(10))

--- Cosine of the angle the gun must be within of its target before it starts charging.
local GUN_CHARGE_CONE = math.cos(math.rad(15))

--- Farthest an autopilot target can be for the gun to start charging, the original g_helicopter_maxfiringdist.
local GUN_MAX_FIRING_DISTANCE = 2500

--- Distance the rounds travel.
local GUN_BULLET_DISTANCE = 8192

--- Prepares the gun state, its attachments, its turning limits and its firing sound.
function ENT:InitGun()
    local pitchMin, pitchMax = self:GetPoseParameterRange(self:LookupPoseParameter("weapon_pitch"))
    local yawMin, yawMax = self:GetPoseParameterRange(self:LookupPoseParameter("weapon_yaw"))

    self.gunState = GUN_STATE_IDLE
    self.gunAngles = Angle(0, 0, 0)
    self.gunPitchMin = -pitchMax
    self.gunPitchMax = -pitchMin
    self.gunYawMin = yawMin
    self.gunYawMax = yawMax
    self.gunNextThink = 0
    self.gunNextAttack = 0
    self.gunChargeTime = 0
    self.gunCooldown = 0
    self.gunRemainingBursts = 0
    self.gunTotalBursts = 0
    self.gunIdleTimeDelay = 0
    self.gunBaseAttachment = self:LookupAttachment("Gun")
    self.gunTipAttachment = self:LookupAttachment("Muzzle")
    self.gunFireSound = CreateSound(self, "NPC_AttackHelicopter.FireGun")

    self.gunBulletCallback = function(attacker, trace, dmginfo)
        self:OnGunBulletHit(trace, dmginfo)
    end
end

--- Returns whether the gun has fired its bursts and is waiting out its cooldown.
---@return boolean bResting
function ENT:IsGunResting()
    return self.gunState == GUN_STATE_IDLE and self.gunNextAttack > CurTime()
end

--- Returns whether the gun is idle with its cooldown over, so that it can start charging.
---@return boolean bReady
function ENT:IsGunReady()
    return self.gunState == GUN_STATE_IDLE and self.gunNextAttack <= CurTime()
end

--- Returns the entity the autopilot is shooting at, or nil when a player flies or there is no target.
---@return Entity|nil target
function ENT:GetGunTarget()
    if ( !self:GetAI() ) then return nil end

    local target = self:AIGetTarget()
    if ( !IsValid(target) ) then return nil end

    return target
end

--- Returns the direction from the gun to what the pilot or the autopilot aims at.
---@param basePos Vector Position of the gun mount.
---@return Vector direction
function ENT:GetGunTargetDirection(basePos)
    local target = self:GetGunTarget()
    if ( target ) then return (target:WorldSpaceCenter() - basePos):GetNormalized() end

    return (self:GetEyeTrace().HitPos - basePos):GetNormalized()
end

--- Turns the gun one step towards a direction, within the limits of its mount.
---@param targetDir Vector World space direction to aim along.
function ENT:PoseGunTowardDirection(targetDir)
    local angles = self:WorldToLocal(self:GetPos() + targetDir):Angle()
    angles:Normalize()

    local gunAngles = self.gunAngles
    gunAngles.p = math.Approach(gunAngles.p, math.Clamp(angles.p, self.gunPitchMin, self.gunPitchMax), GUN_TURN_STEP)
    gunAngles.y = math.Approach(gunAngles.y, math.Clamp(angles.y, self.gunYawMin, self.gunYawMax), GUN_TURN_STEP)

    self:SetPoseParameter("weapon_pitch", -gunAngles.p)
    self:SetPoseParameter("weapon_yaw", gunAngles.y)
end

--- Returns the direction the gun barrel currently points along.
---@return Vector direction
function ENT:GetGunDirection()
    return self:LocalToWorldAngles(self.gunAngles):Forward()
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

--- Shows the progress of the running burst, or the rest of the cooldown, as the gun's heat.
function ENT:UpdateGunHeat()
    if ( self.gunState == GUN_STATE_FIRING ) then
        self:SetWeaponHeat(self.WEAPON_GUN, 1 - self.gunRemainingBursts / self.gunTotalBursts)

        return
    end

    local remaining = self.gunNextAttack - CurTime()

    if ( self.gunState == GUN_STATE_CHARGING or remaining <= 0 or self.gunCooldown <= 0 ) then
        self:SetWeaponHeat(self.WEAPON_GUN, 0)

        return
    end

    self:SetWeaponHeat(self.WEAPON_GUN, remaining / self.gunCooldown)
end

--- Adjusts a round that hit something: LVS damage type and force, the lower damage against players, and the original impact effect.
---@param trace table Trace result of the round.
---@param dmginfo CTakeDamageInfo Damage the round is about to deal.
function ENT:OnGunBulletHit(trace, dmginfo)
    local hit = trace.Entity

    dmginfo:SetDamageType(DMG_AIRBOAT)
    dmginfo:SetDamageForce(trace.Normal * self.GunForce)

    if ( IsValid(hit) ) then
        if ( hit:GetParent() == self ) then
            dmginfo:SetDamage(0)
        elseif ( hit:IsPlayer() ) then
            dmginfo:SetDamage(self.GunDamagePlayer)
        end
    end

    local effectData = EffectData()
    effectData:SetOrigin(trace.HitPos)
    effectData:SetStart(trace.StartPos)
    effectData:SetSurfaceProp(trace.SurfaceProps)
    effectData:SetDamageType(DMG_BULLET)
    effectData:SetHitBox(trace.HitBox)
    effectData:SetEntity(hit)
    util.Effect("HelicopterImpact", effectData)
end

--- Fires pulse rounds from the muzzle.
---@param src Vector Position the rounds start at.
---@param dir Vector Direction the rounds are fired along.
---@param count number Number of rounds.
---@param spread number Spread as the sine of half the cone angle.
function ENT:FireGunBullets(src, dir, count, spread)
    if ( count <= 0 ) then return end

    local attacker = self:GetDriver()

    if ( !IsValid(attacker) ) then
        attacker = self
    end

    self:FireBullets({
        Attacker = attacker,
        Num = count,
        Src = src,
        Dir = dir,
        Spread = Vector(spread, spread, 0),
        Tracer = 1,
        TracerName = "HelicopterTracer",
        Damage = self.GunDamage,
        Force = 1,
        Distance = GUN_BULLET_DISTANCE,
        IgnoreEntity = self,
        Callback = self.gunBulletCallback,
    })
end

--- Shows the original muzzle flash on the gun.
function ENT:DoGunMuzzleFlash()
    local effectData = EffectData()
    effectData:SetEntity(self)
    effectData:SetAttachment(self.gunTipAttachment)
    util.Effect("ChopperMuzzleFlash", effectData)
end

--- Fires one burst where the gun points, sending the first round straight at the autopilot's target when it is inside the cone.
---@param src Vector Position of the muzzle.
---@param gunDir Vector Direction the gun points along.
function ENT:ShootAtFacingDirection(src, gunDir)
    local shots = GUN_ROUNDS_PER_BURST
    local target = self:GetGunTarget()

    if ( target ) then
        local delta = target:WorldSpaceCenter() - src
        local distance = delta:Length()
        local along = delta:Dot(gunDir)

        if ( along > 0 and distance > 0 and (delta - gunDir * along):Length() / distance <= GUN_SPREAD ) then
            self:FireGunBullets(src, delta / distance, 1, 0)
            shots = shots - 1
        end
    end

    self:DoGunMuzzleFlash()
    self:FireGunBullets(src, gunDir, shots, GUN_SPREAD)
end

--- Starts charging when the trigger is held, the cooldown is over and the gun points close enough at its target.
---@param gunDir Vector Direction the gun points along.
---@param targetDir Vector Direction from the gun to its target.
---@param bTrigger boolean Whether the pilot or the autopilot wants to fire.
function ENT:DoGunIdle(gunDir, targetDir, bTrigger)
    if ( !bTrigger ) then return end
    if ( self.gunNextAttack > CurTime() ) then return end

    if ( self:GetAI() ) then
        local target = self:GetGunTarget()
        if ( !target ) then return end
        if ( self:WorldSpaceCenter():DistToSqr(target:WorldSpaceCenter()) > GUN_MAX_FIRING_DISTANCE * GUN_MAX_FIRING_DISTANCE ) then return end
    end

    if ( gunDir:Dot(targetDir) < GUN_CHARGE_CONE ) then return end

    local variance = GUN_CHARGE_TIME * GUN_TIME_VARIANCE

    self:EmitSound("NPC_AttackHelicopter.ChargeGun")
    self.gunChargeTime = CurTime() + math.Rand(GUN_CHARGE_TIME - variance, GUN_CHARGE_TIME + variance)
    self.gunState = GUN_STATE_CHARGING
end

--- Switches from charging to firing once the charge time is over and rolls how many bursts follow.
---@return boolean bFiring Whether the gun is ready to fire.
function ENT:DoGunCharging()
    if ( self.gunChargeTime > CurTime() ) then return false end

    self.gunState = GUN_STATE_FIRING
    self.gunRemainingBursts = math.random(GUN_BURST_COUNT, 2 * GUN_BURST_COUNT)
    self.gunTotalBursts = self.gunRemainingBursts
    self.gunIdleTimeDelay = GUN_IDLE_TIME_PER_BURST * (self.gunRemainingBursts - GUN_BURST_COUNT)
    self.gunFireSound:Play()

    return true
end

--- Fires one burst and puts the gun to rest after the last one.
---@param gunDir Vector Direction the gun points along.
function ENT:DoGunFiring(gunDir)
    local tip = self:GetAttachment(self.gunTipAttachment)
    if ( !tip ) then return end

    self:ShootAtFacingDirection(tip.Pos, gunDir)

    self.gunRemainingBursts = self.gunRemainingBursts - 1
    if ( self.gunRemainingBursts > 0 ) then return end

    local variance = GUN_IDLE_TIME * GUN_TIME_VARIANCE

    self.gunFireSound:Stop()
    self.gunCooldown = self.gunIdleTimeDelay + math.Rand(GUN_IDLE_TIME - variance, GUN_IDLE_TIME + variance)
    self.gunNextAttack = CurTime() + self.gunCooldown
    self.gunState = GUN_STATE_IDLE
    self:SetWeaponHeat(self.WEAPON_GUN, 1)
end

--- Runs the gun: it follows the aim, charges when triggered, then fires its bursts without further input.
---@param bTrigger boolean Whether the pilot or the autopilot wants to fire.
function ENT:GunThink(bTrigger)
    if ( !self.gunAngles ) then return end

    local now = CurTime()
    if ( now < self.gunNextThink ) then return end

    self.gunNextThink = now + GUN_THINK_INTERVAL
    self:UpdateGunHeat()

    if ( self:IsDestroyed() ) then return end

    local base = self:GetAttachment(self.gunBaseAttachment)
    if ( !base ) then return end

    local targetDir = self:GetGunTargetDirection(base.Pos)
    self:PoseGunTowardDirection(targetDir)

    if ( self.gunState == GUN_STATE_CHARGING and !self:DoGunCharging() ) then return end

    local gunDir = self:GetGunDirection()

    if ( self.gunState == GUN_STATE_FIRING ) then
        self:DoGunFiring(gunDir)

        return
    end

    self:DoGunIdle(gunDir, targetDir, bTrigger)
end

--- Stops the gun at once, as when the weapon is put away or the helicopter is shot down, and starts its cooldown if it was firing.
function ENT:GunShutdown()
    if ( !self.gunAngles ) then return end

    self:StopSound("NPC_AttackHelicopter.ChargeGun")
    self.gunFireSound:Stop()

    if ( self.gunState == GUN_STATE_FIRING ) then
        self.gunCooldown = GUN_IDLE_TIME
        self.gunNextAttack = CurTime() + self.gunCooldown
    end

    self.gunState = GUN_STATE_IDLE
end
