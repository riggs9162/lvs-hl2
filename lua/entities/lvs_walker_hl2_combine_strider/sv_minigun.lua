--- Minigun of the strider, ported from CStriderMinigun and CNPC_Strider::ShootMinigun. The gun turns on its mount towards its target and fires bursts of a few seconds with a pause after each. The autopilot walks its rounds towards its enemy like the original; a pilot fires at the crosshair.

--- Firing states of the minigun.
local MINIGUN_OFF = 0
local MINIGUN_SHOOTING = 1

--- Rounds per second, STRIDER_DEFAULT_RATE_OF_FIRE.
local RATE_OF_FIRE = 5

--- Seconds of a burst, the extra seconds it may randomly last, and the pause after it, STRIDER_DEFAULT_SHOOT_DURATION, STRIDER_SHOOT_VARIATION and STRIDER_SHOOT_DOWNTIME.
local SHOOT_DURATION = 2.5
local SHOOT_VARIATION = 1
local SHOOT_DOWNTIME = 1

--- Seconds at the end of a burst the autopilot fires straight at its enemy instead of walking the rounds towards it, STRIDER_SHOOT_ON_TARGET_TIME.
local SHOOT_ON_TARGET_TIME = 0.5

--- Turning limits of the gun in degrees, MINIGUN_MIN_YAW to MINIGUN_MAX_PITCH.
local MIN_YAW, MAX_YAW = -90, 90
local MIN_PITCH, MAX_PITCH = -45, 45

--- Degrees per second the gun turns sideways and up or down.
local YAW_RATE = 360
local PITCH_RATE = 180

--- Share of the angle between the gun and its target the gun's goal moves by on every think.
local AIM_SHARE = 0.5

--- Distance a round flies.
local ROUND_DISTANCE = 8192

--- Speed of the tracer, from CNPC_Strider::MakeTracer.
local TRACER_SPEED = 5000

--- Flag of the tracer effect that makes rounds whiz past the listener.
local TRACER_FLAG_WHIZ = 1

--- Seconds after the last trigger signal of the weapon for which the trigger still counts as held.
local TRIGGER_HOLD_TIME = 0.2

--- Smallest cosine between the strider's facing and its enemy at which the autopilot starts a burst.
local START_SHOOTING_DOT = 0.707

--- Seconds the gun first waits before it looks around without a target, and the least and most it waits between looks.
local TWITCH_DELAY_MIN = 2
local TWITCH_DELAY_MAX = 4
local TWITCH_INTERVAL_MIN = 0.3
local TWITCH_INTERVAL_MAX = 2

--- Moves an angle of the gun towards its goal.
---@param control table Angle with current, target and rate.
---@param dt number
local function UpdateControl(control, dt)
    control.current = math.Approach(control.current, control.target, control.rate * dt)
end

--- Gives an angle of the gun a random goal and turning speed, to look around.
---@param control table
---@param minTarget number
---@param maxTarget number
---@param minRate number
---@param maxRate number
local function RandomControl(control, minTarget, maxTarget, minRate, maxRate)
    control.target = math.Rand(minTarget, maxTarget)
    control.rate = math.Rand(minRate, maxRate)
end

--- Prepares the minigun state, from CStriderMinigun::Init.
function ENT:InitMinigun()
    local now = CurTime()

    self.minigun = {
        yaw = {current = 0, target = 0, rate = YAW_RATE},
        pitch = {current = 0, target = 0, rate = PITCH_RATE},
        state = MINIGUN_OFF,
        burstTime = now,
        nextBulletTime = math.huge,
        shootDuration = SHOOT_DURATION,
        nextTwitchTime = now,
        bRandomState = false,
        triggerTime = 0,
    }

    self.minigunBulletCallback = function(attacker, trace, dmginfo)
        self:OnMinigunRoundHit(trace, dmginfo)
    end
end

--- Records that the pilot or the autopilot holds the minigun's trigger, sent on every tick the minigun is selected.
---@param bTrigger boolean
function ENT:SetMinigunTrigger(bTrigger)
    if ( !bTrigger ) then return end

    self.minigun.triggerTime = CurTime()
end

--- Returns whether the minigun's trigger is held.
---@return boolean bTrigger
function ENT:IsMinigunTriggerHeld()
    if ( self:GetSelectedWeapon() != self.WEAPON_MINIGUN ) then return false end

    return CurTime() - self.minigun.triggerTime < TRIGGER_HOLD_TIME
end

--- Returns whether the gun is turned as far as it goes, any way but up, from CStriderMinigun::IsPegged.
---@return boolean bPegged
function ENT:IsMinigunPegged()
    local minigun = self.minigun
    local bUp = minigun.pitch.current <= MIN_PITCH + 1
    local bAny = bUp or minigun.yaw.current >= MAX_YAW - 1 or minigun.yaw.current <= MIN_YAW + 1 or minigun.pitch.current >= MAX_PITCH - 1

    return bAny and !bUp
end

--- Moves the gun's goal halfway towards a point, from CStriderMinigun::AimAtPoint.
---@param point Vector
function ENT:AimMinigunAtPoint(point)
    local base = self:GetStriderAttachment("MiniGunBase")
    if ( !base ) then return end

    local localPoint = WorldToLocal(point, angle_zero, base.Pos, base.Ang)
    local localAngles = localPoint:Angle()
    local minigun = self.minigun

    minigun.pitch.target = math.Clamp(minigun.pitch.target + AIM_SHARE * math.NormalizeAngle(localAngles.p), MIN_PITCH, MAX_PITCH)
    minigun.yaw.target = math.Clamp(minigun.yaw.target - AIM_SHARE * math.NormalizeAngle(localAngles.y), MIN_YAW, MAX_YAW)
end

--- Starts a burst. The autopilot starts its rounds to one side of and below its enemy, or where a player who does not see it can see them land, from CStriderMinigun::StartShooting.
---@param target Entity|nil Enemy of the autopilot.
---@param duration number Seconds of the burst.
function ENT:StartMinigunBurst(target, duration)
    local minigun = self.minigun
    local now = CurTime()

    minigun.state = MINIGUN_SHOOTING
    minigun.nextBulletTime = now
    minigun.burstTime = now + duration
    minigun.shootDuration = duration
    minigun.nextTwitchTime = math.huge
    minigun.bWarned = false

    if ( !IsValid(target) ) then return end

    if ( target:IsPlayer() and !target:IsLineOfSightClear(self) ) then
        minigun.anchor = target:EyePos() + Vector(0, 0, math.Rand(160, 240)) + target:GetRight() * math.Rand(-100, 100)

        return
    end

    local offset = target:GetRight() * math.Rand(60, 120)

    if ( math.random(0, 1) == 0 ) then
        offset = -offset
    end

    minigun.anchor = target:WorldSpaceCenter() + offset - Vector(0, 0, math.Rand(80, 200))
end

--- Ends the burst and holds the gun back for a while, from CStriderMinigun::StopShootingForSeconds.
---@param duration number
function ENT:StopMinigunForSeconds(duration)
    local minigun = self.minigun
    local now = CurTime()

    minigun.state = MINIGUN_OFF
    minigun.burstTime = now + duration
    minigun.nextBulletTime = math.huge
    minigun.nextTwitchTime = now + math.Rand(TWITCH_DELAY_MIN, TWITCH_DELAY_MAX)
end

--- Returns whether the autopilot may start a burst at its enemy: the pause is over, it sees the enemy and the enemy is fairly well in front, from CStriderMinigun::CanStartShooting.
---@param target Entity
---@return boolean bCanStart
function ENT:CanStartMinigunBurst(target)
    if ( CurTime() < self.minigun.burstTime ) then return false end
    if ( !IsValid(target) or !self:AICanSee(target) ) then return false end

    local toTarget = target:WorldSpaceCenter() - self:GetPos()
    toTarget.z = 0
    toTarget:Normalize()

    local forward = self:GetForward()
    forward.z = 0
    forward:Normalize()

    return toTarget:Dot(forward) > START_SHOOTING_DOT
end

--- Draws the strider's tracer of a round that hit and gives it the LVS damage type.
---@param trace table
---@param dmginfo CTakeDamageInfo
function ENT:OnMinigunRoundHit(trace, dmginfo)
    local effectData = EffectData()
    effectData:SetStart(trace.StartPos)
    effectData:SetOrigin(trace.HitPos)
    effectData:SetScale(TRACER_SPEED)
    effectData:SetFlags(TRACER_FLAG_WHIZ)
    util.Effect("StriderTracer", effectData)

    dmginfo:SetDamageType(DMG_AIRBOAT)
end

--- Adds the halo and the energy splash of the original's rounds to the usual impact, from CNPC_Strider::DoImpactEffect.
---@param trace table
---@return boolean bHandled
function ENT:DoImpactEffect(trace)
    local effectData = EffectData()
    effectData:SetOrigin(trace.HitPos)
    effectData:SetNormal(trace.HitNormal)
    util.Effect("lvs_hl2_strider_impact", effectData)

    return false
end

--- Fires one round at a point, with the muzzle flash and the sound of the original, from CNPC_Strider::ShootMinigun.
---@param point Vector
function ENT:ShootMinigun(point)
    local muzzle = self:GetStriderAttachment("MiniGun")
    if ( !muzzle ) then return end

    local attacker = self:GetDriver()

    if ( !IsValid(attacker) ) then
        attacker = self
    end

    self:FireBullets({
        Attacker = attacker,
        Num = 1,
        Src = muzzle.Pos,
        Dir = (point - muzzle.Pos):GetNormalized(),
        Spread = vector_origin,
        Tracer = 0,
        TracerName = "none",
        AmmoType = "StriderMinigun",
        Force = 1,
        Distance = ROUND_DISTANCE,
        IgnoreEntity = self,
        Callback = self.minigunBulletCallback,
    })

    local effectData = EffectData()
    effectData:SetEntity(self)
    effectData:SetAttachment(self:LookupAttachment("MiniGun"))
    util.Effect("StriderMuzzleFlash", effectData)

    self:EmitSound("NPC_Strider.FireMinigun")
end

--- Returns where the autopilot fires its next round: walking from its starting point towards the enemy over the burst and staying on the enemy at its end, from CStriderMinigun::Think.
---@param target Entity
---@return Vector point
function ENT:GetMinigunStitchPoint(target)
    local minigun = self.minigun
    local remaining = minigun.burstTime - CurTime()
    local factor = math.max((remaining - SHOOT_ON_TARGET_TIME) / minigun.shootDuration, 0)
    local targetPos = target:WorldSpaceCenter()
    local anchor = minigun.anchor or targetPos
    local point = targetPos + (anchor - targetPos) * factor

    if ( factor == 0 ) then
        minigun.anchor = point
    end

    if ( factor <= 0.5 and !minigun.bWarned ) then
        minigun.bWarned = true

        sound.EmitHint(bit.bor(SOUND_DANGER, SOUND_CONTEXT_REACT_TO_SOURCE), target:EyePos() + Vector(0, 0, 1), 120, math.max(1, remaining), self)
    end

    return point
end

--- Looks around while the autopilot has no target, from CStriderMinigun::Think.
function ENT:TwitchMinigun()
    local minigun = self.minigun
    local now = CurTime()
    if ( now < minigun.nextTwitchTime ) then return end

    minigun.bRandomState = !minigun.bRandomState

    if ( minigun.bRandomState ) then
        RandomControl(minigun.yaw, MIN_YAW, MAX_YAW, 360, 720)
        minigun.pitch.target = -minigun.pitch.target
    else
        RandomControl(minigun.pitch, MIN_PITCH, MAX_PITCH, 270, 360)
        minigun.yaw.target = -minigun.yaw.target
    end

    minigun.nextTwitchTime = now + math.Rand(TWITCH_INTERVAL_MIN, TWITCH_INTERVAL_MAX)
end

--- Shows the progress of a burst, or the rest of the pause after it, as the minigun's heat.
function ENT:UpdateMinigunHeat()
    local minigun = self.minigun
    local now = CurTime()
    local heat = 0

    if ( minigun.state == MINIGUN_SHOOTING ) then
        heat = 1 - math.max(minigun.burstTime - now, 0) / minigun.shootDuration
    elseif ( minigun.burstTime > now ) then
        heat = (minigun.burstTime - now) / SHOOT_DOWNTIME
    end

    self:SetWeaponHeat(self.WEAPON_MINIGUN, heat)
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

--- Runs the minigun on every think: it follows its target, starts and ends bursts and fires their rounds, from CStriderMinigun::Think.
---@param dt number Seconds since the last think.
function ENT:MinigunThink(dt)
    local minigun = self.minigun
    if ( self:GetHP() <= 0 or self:GetCarryingDropship() ) then return end

    local now = CurTime()
    local bAI = self:GetAI()
    local target = bAI and self:GetMinigunAITarget() or nil
    local aimPoint

    if ( bAI ) then
        if ( target ) then
            aimPoint = target:WorldSpaceCenter()
        else
            self:TwitchMinigun()
        end
    elseif ( IsValid(self:GetDriver()) ) then
        aimPoint = self:GetEyeTrace().HitPos
    end

    if ( aimPoint ) then
        self:AimMinigunAtPoint(aimPoint)
        self:SetMinigunAimPos(aimPoint)
    else
        self:SetMinigunAimPos(vector_origin)
    end

    UpdateControl(minigun.yaw, dt)
    UpdateControl(minigun.pitch, dt)

    self:SetPoseParameter("minigunYaw", minigun.yaw.current)
    self:SetPoseParameter("minigunPitch", minigun.pitch.current)

    if ( minigun.state == MINIGUN_SHOOTING ) then
        if ( now > minigun.burstTime ) then
            self:StopMinigunForSeconds(SHOOT_DOWNTIME)
        elseif ( ( bAI and !target ) or ( !bAI and !self:IsMinigunTriggerHeld() ) ) then
            self:StopMinigunForSeconds(bAI and SHOOT_DOWNTIME or 0)
        end
    elseif ( bAI and self:CanStartMinigunBurst(target) ) then
        self:StartMinigunBurst(target, SHOOT_DURATION + math.Rand(0, SHOOT_VARIATION))
    elseif ( !bAI and self:IsMinigunTriggerHeld() and now >= minigun.burstTime ) then
        self:StartMinigunBurst(nil, SHOOT_DURATION + math.Rand(0, SHOOT_VARIATION))
    end

    if ( minigun.state == MINIGUN_SHOOTING and minigun.nextBulletTime <= now and !self:IsMinigunPegged() ) then
        local point = bAI and self:GetMinigunStitchPoint(target) or self:GetEyeTrace().HitPos

        self:ShootMinigun(point)

        minigun.nextBulletTime = now + 1 / RATE_OF_FIRE
    end

    self:UpdateMinigunHeat()
end

--- Holds the minigun back, as the original does while its cannon fires or it flinches.
---@param duration number
function ENT:HoldMinigun(duration)
    self:StopMinigunForSeconds(duration)
end

--- Stops the minigun for good.
function ENT:StopMinigun()
    if ( !self.minigun ) then return end

    self.minigun.state = MINIGUN_OFF
end
