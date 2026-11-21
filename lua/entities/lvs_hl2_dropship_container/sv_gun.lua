--- Cannon of the dropship container, ported from CNPC_CombineDropship::UpdateContainerGunFacing, FireCannonRound, StartCannon and StopCannon. A carrying dropship's pilot, the container's gunner or its AI feed it a point to aim at and a trigger.

--- Most degrees the gun turns on one think, DROPSHIP_GUN_SPEED.
local GUN_TURN_STEP = 10

--- Smallest cosine between the gun and its target at which it fires, DOT_15DEGREE.
local GUN_FIRE_DOT = math.cos(math.rad(15))

--- Rounds of the first burst.
local FIRST_BURST_ROUNDS = 15

--- Fewest and most rounds of every later burst; the gun pauses a tenth of a second per round before it.
local BURST_ROUNDS_MIN = 10
local BURST_ROUNDS_MAX = 20

--- Seconds of pause per round of the next burst.
local RELOAD_TIME_PER_ROUND = 0.1

--- Seconds between two rounds, which comes down to one round on every think.
local ROUND_INTERVAL = 0.05

--- Seconds the gun waits before it checks its aim again after missing the cone.
local AIM_RETRY_TIME = 0.1

--- Spread of the rounds, VECTOR_CONE_2DEGREES.
local ROUND_SPREAD = 0.01745

--- Distance a round flies.
local ROUND_DISTANCE = 8192

--- Speed of the tracer, from CNPC_CombineDropship::MakeTracer.
local TRACER_SPEED = 16000

--- Flag of the tracer effect that makes rounds whiz past the listener.
local TRACER_FLAG_WHIZ = 1

--- Seconds after the last input for which the gun still follows it.
local INPUT_HOLD_TIME = 0.2

--- Pitch and yaw limits of the gun, the ranges of its pose parameters.
local GUN_PITCH_MIN, GUN_PITCH_MAX = -90, 30
local GUN_YAW_MIN, GUN_YAW_MAX = -60, 60

--- Returns the damage of one round, sk_npc_dmg_dropship.
---@return number damage
local function GetRoundDamage()
    local convar = GetConVar("sk_npc_dmg_dropship")

    return convar and convar:GetFloat() or 5
end

--- Prepares the gun state.
function ENT:InitGun()
    self.gunPitch = 0
    self.gunYaw = 0
    self.gunBurstRounds = FIRST_BURST_ROUNDS
    self.gunNextAttack = 0
    self.gunInputTime = 0
    self.bGunFiring = false

    self.gunBulletCallback = function(attacker, trace, dmginfo)
        self:OnGunRoundHit(trace, dmginfo)
    end
end

--- Gives the gun a point to aim at and says whether to fire.
---@param aimPos Vector|nil Point to aim at, or nil to rest.
---@param bTrigger boolean Whether to fire.
function ENT:SetGunInput(aimPos, bTrigger)
    self.gunAimPos = aimPos
    self.bGunTrigger = aimPos != nil and bTrigger
    self.gunInputTime = CurTime()

    if ( aimPos ) then
        self:SetGunAimPos(aimPos)
    end
end

--- Turns the gun one step towards a point.
---@param targetPos Vector
function ENT:TurnGun(targetPos)
    local pitch, yaw = self:GetGunAngles(targetPos)
    if ( !pitch ) then return end

    self.gunPitch = math.Clamp(math.ApproachAngle(self.gunPitch, pitch, GUN_TURN_STEP), GUN_PITCH_MIN, GUN_PITCH_MAX)
    self.gunYaw = math.Clamp(math.ApproachAngle(self.gunYaw, yaw, GUN_TURN_STEP), GUN_YAW_MIN, GUN_YAW_MAX)

    self:SetPoseParameter("weapon_pitch", self.gunPitch)
    self:SetPoseParameter("weapon_yaw", self.gunYaw)
end

--- Starts the firing loop, from CNPC_CombineDropship::StartCannon.
function ENT:StartGunSound()
    if ( self.bGunFiring ) then return end

    self.bGunFiring = true
    self.gunSound = self.gunSound or CreateSound(self, "NPC_CombineDropship.FireLoop")
    self.gunSound:Stop()
    self.gunSound:Play()
end

--- Fades out the firing loop, from CNPC_CombineDropship::StopCannon.
function ENT:StopGunSound()
    if ( !self.bGunFiring ) then return end

    self.bGunFiring = false

    if ( self.gunSound ) then
        self.gunSound:FadeOut(0.1)
    end
end

--- Draws the gunship tracer the original borrows for the container's rounds.
---@param startPos Vector
---@param endPos Vector
function ENT:DrawGunTracer(startPos, endPos)
    local effectData = EffectData()
    effectData:SetStart(startPos)
    effectData:SetOrigin(endPos)
    effectData:SetScale(TRACER_SPEED)
    effectData:SetFlags(TRACER_FLAG_WHIZ)
    util.Effect("GunshipTracer", effectData)
end

--- Draws the tracer of a round that hit and keeps it off the container itself.
---@param trace table
---@param dmginfo CTakeDamageInfo
function ENT:OnGunRoundHit(trace, dmginfo)
    self:DrawGunTracer(trace.StartPos, trace.HitPos)

    local hit = trace.Entity

    if ( IsValid(hit) and ( hit == self:GetCarryingDropship() or hit:GetParent() == self ) ) then
        dmginfo:SetDamage(0)
    end
end

--- Warns everyone near where the rounds land, from CNPC_CombineDropship::DoImpactEffect.
---@param trace table
---@param damageType number
---@return boolean bHandled
function ENT:DoImpactEffect(trace, damageType)
    sound.EmitHint(bit.bor(SOUND_DANGER, SOUND_CONTEXT_REACT_TO_SOURCE), trace.HitPos, 120, 0.3, self)

    return false
end

--- Returns who is credited with the gun's rounds.
---@return Entity attacker
function ENT:GetGunAttacker()
    local carrier = self:GetCarryingDropship()
    local driver = carrier and carrier:GetDriver() or self:GetDriver()

    if ( IsValid(driver) ) then return driver end

    return carrier or self
end

--- Fires one round at the target if the gun points close enough at it, with a pause between bursts, from CNPC_CombineDropship::FireCannonRound.
---@param targetPos Vector
---@return boolean bFiring Whether the gun is still firing, so that its sound keeps playing.
function ENT:FireGunRound(targetPos)
    local muzzle = self:GetAttachment(self:LookupAttachment("Muzzle"))
    if ( !muzzle ) then return false end

    local now = CurTime()
    local toTarget = (targetPos - muzzle.Pos):GetNormalized()

    if ( toTarget:Dot(muzzle.Ang:Forward()) < GUN_FIRE_DOT ) then
        self.gunNextAttack = now + AIM_RETRY_TIME

        return false
    end

    if ( self.gunBurstRounds <= 0 ) then
        self.gunBurstRounds = math.random(BURST_ROUNDS_MIN, BURST_ROUNDS_MAX)
        self.gunNextAttack = now + self.gunBurstRounds * RELOAD_TIME_PER_ROUND

        return false
    end

    if ( self.gunNextAttack > now ) then return true end

    self.gunBurstRounds = self.gunBurstRounds - 1
    self:StartGunSound()

    local effectData = EffectData()
    effectData:SetEntity(self)
    effectData:SetAttachment(self:LookupAttachment("Muzzle"))
    util.Effect("GunshipMuzzleFlash", effectData)

    self.gunNextAttack = now + ROUND_INTERVAL

    self:FireBullets({
        Attacker = self:GetGunAttacker(),
        Num = 1,
        Src = muzzle.Pos,
        Dir = toTarget,
        Spread = Vector(ROUND_SPREAD, ROUND_SPREAD, 0),
        Tracer = 0,
        TracerName = "none",
        AmmoType = "CombineCannon",
        Damage = GetRoundDamage(),
        Force = 1,
        Distance = ROUND_DISTANCE,
        IgnoreEntity = self,
        Callback = self.gunBulletCallback,
    })

    return true
end

--- Aims the gun at its input and fires while the trigger is held, on every think.
function ENT:GunThink()
    if ( self:GetHP() <= 0 ) then return end

    local bFresh = CurTime() - self.gunInputTime < INPUT_HOLD_TIME
    local aimPos = bFresh and self.gunAimPos or nil

    if ( aimPos ) then
        self:TurnGun(aimPos)
    end

    local bFiring = aimPos != nil and self.bGunTrigger and self:FireGunRound(aimPos)

    if ( !bFiring ) then
        self:StopGunSound()
    end
end
