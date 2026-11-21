--- Rocket of the Combine APC, ported from CAPCMissile and the CMissile it builds on in the Half-Life 2 RPG code (weapon_rpg.cpp). It leaves the launcher sideways and upwards, lights its motor after a moment and then homes in on the laser dot of the APC that fired it: the spot under the pilot's crosshair, or the enemy the autopilot is after.

AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "APC Rocket"
ENT.Spawnable = false
ENT.AdminSpawnable = false
ENT.DoNotDuplicate = true

ENT.lvsProjectile = true

ENT.VJ_ID_Danger = true

if ( CLIENT ) then return end

--- Model of the rocket in flight.
local MISSILE_MODEL = "models/weapons/w_missile.mdl"

--- Length in seconds of one think of the original, which its per-think homing shares are measured in.
local SOURCE_TICK = 0.015

--- Seconds after launch before the rocket turns solid and starts to home in.
local IGNITE_DELAY = 0.3

--- Share of the way to the dot a rocket turns per original think when its dot is not on an entity, as an RPG rocket does.
local RPG_HOMING_SPEED = 0.125

--- Share a rocket turns per original think towards an entity right after launch.
local APC_LAUNCH_HOMING_SPEED = 0.1

--- Share a rocket turns per original think towards an entity once it has dropped onto it.
local APC_HOMING_SPEED = 0.025

--- Distance from the dot inside which a rocket guided by the pilot chases the laser line instead of the dot.
local LASER_LINE_CHASE_DISTANCE = 512

--- Distance along the laser line ahead of its nearest point that such a rocket chases.
local LASER_LINE_LEAD = 256

--- Distances between which homing on an entity fades out the closer the rocket gets, for most of the flight.
local MIN_HOMING_DISTANCE = 1250
local MAX_HOMING_DISTANCE = 2250

--- The same distances while the rocket is still dropping onto its target.
local MIN_NEAR_HOMING_DISTANCE = 1000
local MAX_NEAR_HOMING_DISTANCE = 1750

--- Seconds after ignition before the rocket starts to correct its height towards the target.
local DOWNWARD_BLEND_TIME_START = 0.2

--- Seconds after ignition before homing starts to fade with distance.
local DISTANCE_BLEND_TIME_START = 0.6

--- Heights above its target between which a rocket aims further out to come down on it at an angle.
local MIN_HEIGHT_DIFFERENCE = 250
local MAX_HEIGHT_DIFFERENCE = 550

--- Distance ahead of itself a high rocket aims while it still has a long way to go.
local HIGH_ROCKET_FORWARD_OFFSET = 2000

--- Seconds over which homing eases in once the rocket has come down to its target's height.
local CORRECTION_TIME = 0.2

--- Health of a rocket, and how much of it may be lost before it spins out of control.
local MISSILE_HEALTH = 100
local AUGER_DAMAGE = 25

--- Seconds a rocket that was shot down spins before it blows up.
local SHOT_DOWN_AUGER_TIME = 1.5

--- Most degrees per spin step a rocket out of control turns sideways, and up or down.
local AUGER_YAW_DEVIANCE = 20
local AUGER_PITCH_UP_DEVIANCE = 8
local AUGER_PITCH_DOWN_DEVIANCE = 1

--- Seconds between two spin steps and speed of a rocket out of control.
local AUGER_STEP = 0.05
local AUGER_SPEED = 1000

--- Seconds between two danger sounds a rocket makes where it is headed, so that NPCs get out of the way.
local DANGER_SOUND_INTERVAL = 0.2

--- Settings of the smoke trail behind a rocket, from CMissile::CreateSmokeTrail.
local TRAIL_SETTINGS = {
    m_Opacity = 0.2,
    m_SpawnRate = 100,
    m_ParticleLifetime = 0.5,
    m_StartColor = Vector(0.65, 0.65, 0.65),
    m_EndColor = Vector(0, 0, 0),
    m_StartSize = 8,
    m_EndSize = 32,
    m_SpawnRadius = 4,
    m_MinSpeed = 2,
    m_MaxSpeed = 16,
}

--- Seconds a smoke trail lingers after its rocket is gone.
local TRAIL_LINGER = 1

--- Remaps a value between two ranges along a smooth curve, as the original SimpleSplineRemapVal does.
---@param value number Value to remap.
---@param a number Start of the input range.
---@param b number End of the input range.
---@param c number Output at the start of the range.
---@param d number Output at the end of the range.
---@return number remapped
local function SimpleSplineRemapVal(value, a, b, c, d)
    if ( a == b ) then return value >= b and d or c end

    local t = (value - a) / (b - a)
    local s = t * t * (3 - 2 * t)

    return c + (d - c) * s
end

--- Returns the point on a line through two points that is nearest to a third point.
---@param a Vector First point of the line.
---@param b Vector Second point of the line.
---@param point Vector Point to measure from.
---@return Vector nearest
local function PointOnLineNearestPoint(a, b, point)
    local line = b - a
    local lengthSqr = line:LengthSqr()
    if ( lengthSqr == 0 ) then return Vector(a) end

    return a + line * ((point - a):Dot(line) / lengthSqr)
end

function ENT:Initialize()
    self:SetModel(MISSILE_MODEL)
    self:SetMoveType(MOVETYPE_FLY)
    self:SetSolid(SOLID_BBOX)
    self:SetCollisionBounds(Vector(-4, -4, -4), Vector(4, 4, 4))
    self:SetCollisionGroup(COLLISION_GROUP_PROJECTILE)
    self:AddEFlags(EFL_NO_ROTORWASH_PUSH)
    self:DrawShadow(false)
    self:AddFlags(FL_NOTARGET)

    self:SetHealth(MISSILE_HEALTH)
    self:SetMaxHealth(MISSILE_HEALTH)

    self.speed = 0
    self.ignitionTime = CurTime()
    self.reachedTargetTime = 0
    self.lastHomingSpeed = APC_HOMING_SPEED
    self.nextDangerSound = 0
    self.lastPos = self:GetPos()
    self.bSolid = true

    self:CreateSmokeTrail()
end

--- Sets the speed and heading the rocket flies with.
---@param velocity Vector
function ENT:SetMissileVelocity(velocity)
    self.speed = velocity:Length()
    self:SetAngles(velocity:Angle())
    self:SetLocalVelocity(velocity)
end

--- Sets who gets the credit for the rocket's explosion and the damage and radius it explodes with.
---@param attacker Entity Pilot, or the vehicle when nobody is driving.
---@param damage number Damage at the centre of the explosion.
---@param radius number Radius of the explosion.
function ENT:SetExplosion(attacker, damage, radius)
    self.attacker = attacker
    self.damage = damage
    self.radius = radius
end

--- Sets the function the rocket asks every think where its laser dot is. It returns the dot position, the entity the dot is on or nil, and the position the laser is aimed from, or nothing once there is no dot.
---@param getDot function
function ENT:SetLaserSource(getDot)
    self.getDot = getDot
end

--- Leaves the rocket unguided and not solid for a moment after launch, then lets it home in, as CAPCMissile::IgniteDelay does.
function ENT:IgniteDelay()
    self.ignitionTime = CurTime() + IGNITE_DELAY
    self.state = "launch"
    self:SetNotSolid(true)
    self.bSolid = false
    self:StartMotorSound()
end

--- Sends the rocket off unguided and lets it spin out of control after a delay, as the death volley of a destroyed APC does.
---@param delay number Seconds before it starts to spin.
function ENT:AugerDelay(delay)
    self.ignitionTime = CurTime()
    self.bGuidingDisabled = true
    self.state = "unguided"
    self.augerStartTime = CurTime() + delay
    self:StartMotorSound()
end

--- Sends the rocket off unguided and blows it up after a delay, as the death volley of a destroyed APC does.
---@param delay number Seconds before it explodes.
function ENT:ExplodeDelay(delay)
    self.ignitionTime = CurTime()
    self.bGuidingDisabled = true
    self.state = "unguided"
    self.explodeTime = CurTime() + delay
    self:StartMotorSound()
end

--- Plays the looping sound of the rocket motor.
function ENT:StartMotorSound()
    self:EmitSound("Missile.Ignite")
end

--- Attaches the smoke trail of the original rocket.
function ENT:CreateSmokeTrail()
    local trail = ents.Create("env_rockettrail")
    if ( !IsValid(trail) ) then return end

    for key, value in pairs(TRAIL_SETTINGS) do
        trail:SetSaveValue(key, value)
    end

    trail:SetPos(self:GetPos())
    trail:SetAngles(self:GetAngles())
    trail:SetParent(self)
    trail:Spawn()
    trail:Activate()

    self.trail = trail
end

--- Turns the smoke trail black, as it does on a rocket that is out of control.
function ENT:DamageSmokeTrail()
    if ( !IsValid(self.trail) ) then return end

    self.trail:SetSaveValue("m_bDamaged", true)
end

--- Works out where the rocket should fly to and how sharply it may turn there, from CMissile::ComputeActualDotPosition and its CAPCMissile override.
---@param dotPos Vector Position of the laser dot.
---@param target Entity|nil Entity the dot is on.
---@param shootPos Vector Position the laser is aimed from.
---@return Vector aimPos
---@return number homingSpeed Share of the way to turn per original think.
function ENT:ComputeActualDotPosition(dotPos, target, shootPos)
    local pos = self:GetPos()

    if ( self.bGuidingDisabled ) then
        self.lastHomingSpeed = 0

        return pos, 0
    end

    if ( !IsValid(target) ) then
        local laserDir = dotPos - shootPos
        local laserLength = laserDir:Length()

        laserDir:Normalize()

        if ( pos:Distance(shootPos) < laserLength or pos:Distance(dotPos) <= LASER_LINE_CHASE_DISTANCE ) then
            return PointOnLineNearestPoint(shootPos, dotPos, pos) + laserDir * LASER_LINE_LEAD, RPG_HOMING_SPEED
        end

        return dotPos, RPG_HOMING_SPEED
    end

    local targetPos = target:WorldSpaceCenter()
    local aimPos = self:ComputeLeadingPosition(pos, target)
    local targetToMissile = pos - targetPos
    local targetToShooter = shootPos - targetPos
    local homingSpeed = APC_LAUNCH_HOMING_SPEED
    local minHomingDistance = MIN_HOMING_DISTANCE
    local maxHomingDistance = MAX_HOMING_DISTANCE
    local blendTime = CurTime() - self.ignitionTime

    if ( blendTime > DOWNWARD_BLEND_TIME_START ) then
        if ( self.reachedTargetTime != 0 ) then
            local deltaTime = math.Clamp(CurTime() - self.reachedTargetTime, 0, CORRECTION_TIME)

            homingSpeed = SimpleSplineRemapVal(deltaTime, 0, CORRECTION_TIME, 0.2, APC_HOMING_SPEED)
            minHomingDistance = SimpleSplineRemapVal(deltaTime, 0, CORRECTION_TIME, MIN_NEAR_HOMING_DISTANCE, MIN_HOMING_DISTANCE)
            maxHomingDistance = SimpleSplineRemapVal(deltaTime, 0, CORRECTION_TIME, MAX_NEAR_HOMING_DISTANCE, MAX_HOMING_DISTANCE)
        else
            minHomingDistance = MIN_NEAR_HOMING_DISTANCE
            maxHomingDistance = MAX_NEAR_HOMING_DISTANCE

            local delta = pos - aimPos

            if ( delta.z > MIN_HEIGHT_DIFFERENCE ) then
                local heightFactor = SimpleSplineRemapVal(math.Clamp(delta.z, MIN_HEIGHT_DIFFERENCE, MAX_HEIGHT_DIFFERENCE), MIN_HEIGHT_DIFFERENCE, MAX_HEIGHT_DIFFERENCE, 0, 1)

                delta.z = 0

                local flatDistance = delta:Length()

                if ( flatDistance > HIGH_ROCKET_FORWARD_OFFSET ) then
                    delta:Normalize()

                    local offsetPos = pos - delta * HIGH_ROCKET_FORWARD_OFFSET
                    offsetPos.z = aimPos.z

                    aimPos = LerpVector(heightFactor, aimPos, offsetPos)
                end
            else
                self.reachedTargetTime = CurTime()
            end
        end

        if ( blendTime > DISTANCE_BLEND_TIME_START ) then
            local targetLength = math.Clamp(pos:Distance(targetPos), minHomingDistance, maxHomingDistance)

            homingSpeed = SimpleSplineRemapVal(targetLength, maxHomingDistance, minHomingDistance, homingSpeed, 0.01)
        end
    end

    if ( targetToShooter.x * targetToMissile.x + targetToShooter.y * targetToMissile.y < 0 ) then
        homingSpeed = 0
    end

    self.lastHomingSpeed = homingSpeed

    return aimPos, homingSpeed
end

--- Returns where a moving target will be when the rocket reaches it at its current speed, from CAPCMissile::ComputeLeadingPosition.
---@param shootPos Vector Position of the rocket.
---@param target Entity Target to lead.
---@return Vector leadPos
function ENT:ComputeLeadingPosition(shootPos, target)
    local targetPos = target:WorldSpaceCenter()
    local shotSpeed = self.speed
    if ( shotSpeed == 0 ) then return targetPos end

    local targetVelocity = target:GetVelocity()
    targetVelocity.z = 0

    local targetSpeed = targetVelocity:Length()
    if ( targetSpeed > 0 ) then
        targetVelocity:Normalize()
    end

    local delta = shootPos - targetPos
    local targetToShooter = delta:Length()

    delta:Normalize()

    local cosTheta = delta:Dot(targetVelocity)
    local a = targetSpeed * targetSpeed - shotSpeed * shotSpeed
    local b = -2 * targetToShooter * cosTheta * targetSpeed
    local c = targetToShooter * targetToShooter
    local discriminant = b * b - 4 * a * c
    if ( discriminant < 0 or a == 0 ) then return targetPos end

    discriminant = math.sqrt(discriminant)

    local time = math.max((-b + discriminant) / (2 * a), (-b - discriminant) / (2 * a))
    if ( time <= 0 ) then return targetPos end

    return targetPos + targetVelocity * targetSpeed * time
end

--- Turns the rocket towards its dot, from CMissile::SeekThink; without a dot it flies on straight at its launch speed, as CAPCMissile::APCSeekThink lets it.
---@param deltatime number Seconds since the last think.
function ENT:SeekThink(deltatime)
    local dotPos, target, shootPos

    if ( self.getDot ) then
        dotPos, target, shootPos = self.getDot()
    end

    if ( !dotPos ) then
        self.state = "unguided"

        return
    end

    local aimPos, homingSpeed = self:ComputeActualDotPosition(dotPos, target, shootPos)
    local targetDir = aimPos - self:GetPos()
    local distance = targetDir:Length()

    targetDir:Normalize()

    local dir = self:GetVelocity():GetNormalized()
    local share = 1 - (1 - homingSpeed) ^ (deltatime / SOURCE_TICK)
    local newDir = targetDir * share + dir * (1 - share)

    if ( newDir:Length() < 1e-3 ) then
        newDir = distance != 0 and targetDir or dir
    end

    newDir:Normalize()

    self:SetAngles(newDir:Angle())
    self:SetLocalVelocity(newDir * self.speed)
end

--- Spins the rocket out of control for a while, from CMissile::AugerThink.
function ENT:AugerThink()
    local now = CurTime()

    if ( now >= self.augerEndTime ) then
        self:Explode()

        return
    end

    if ( now < (self.nextAugerStep or 0) ) then return end

    self.nextAugerStep = now + AUGER_STEP

    local angles = self:GetAngles()
    angles.y = angles.y + math.Rand(-AUGER_YAW_DEVIANCE, AUGER_YAW_DEVIANCE)
    angles.p = angles.p + math.Rand(-AUGER_PITCH_DOWN_DEVIANCE, AUGER_PITCH_UP_DEVIANCE)

    self:SetAngles(angles)
    self:SetLocalVelocity(angles:Forward() * AUGER_SPEED)
end

--- Lets the rocket spin out of control for a number of seconds.
---@param duration number
function ENT:StartAuger(duration)
    self.state = "auger"
    self.augerEndTime = CurTime() + duration
    self:DamageSmokeTrail()
end

--- Makes a danger sound where the rocket is headed, so that NPCs get out of the way.
function ENT:MakeDangerSound()
    local now = CurTime()
    if ( now < self.nextDangerSound ) then return end

    self.nextDangerSound = now + DANGER_SOUND_INTERVAL

    local pos = self:GetPos()
    local trace = util.TraceLine({
        start = pos,
        endpos = pos + self:GetVelocity() * 0.5,
        mask = MASK_SOLID,
        filter = self,
    })

    sound.EmitHint(SOUND_DANGER, trace.HitPos, 100, DANGER_SOUND_INTERVAL, self)
end

--- Returns whether an entity the rocket ran into should set it off.
---@param entity Entity
---@return boolean bHit
function ENT:ShouldHit(entity)
    if ( !IsValid(entity) ) then return true end
    if ( entity == self:GetOwner() or entity:GetParent() == self:GetOwner() ) then return false end
    if ( entity.lvsProjectile ) then return false end

    return entity:IsSolid() or entity:IsSolidFlagSet(FSOLID_VOLUME_CONTENTS)
end

--- Checks the path the rocket flew since the last think for anything it ran into.
function ENT:CheckImpact()
    local pos = self:GetPos()
    local owner = self:GetOwner()
    local filter = {self}

    if ( IsValid(owner) ) then
        filter = table.Copy(owner.GetCrosshairFilterEnts and owner:GetCrosshairFilterEnts() or {owner})
        filter[#filter + 1] = self
    end

    local trace = util.TraceLine({
        start = self.lastPos,
        endpos = pos + self:GetVelocity() * FrameTime(),
        mask = MASK_SHOT,
        filter = filter,
    })

    self.lastPos = pos

    if ( !trace.Hit or !self:ShouldHit(trace.Entity) ) then return end

    if ( trace.HitSky ) then
        self:Remove()

        return
    end

    self:SetPos(trace.HitPos)
    self:Explode()
end

function ENT:Touch(entity)
    if ( !self.bSolid or !self:ShouldHit(entity) ) then return end

    self:Explode()
end

function ENT:Think()
    local now = CurTime()
    local deltatime = FrameTime()

    self:NextThink(now)

    if ( self.bExploded ) then return true end

    if ( self.explodeTime and now >= self.explodeTime ) then
        self:Explode()

        return true
    end

    if ( self.augerStartTime and now >= self.augerStartTime ) then
        self.augerStartTime = nil
        self:StartAuger(math.Rand(1, 2))
    end

    if ( self.state == "launch" and now >= self.ignitionTime ) then
        self.state = "seek"
        self:SetNotSolid(false)
        self.bSolid = true
    end

    if ( self.state == "seek" ) then
        self:SeekThink(deltatime)
    elseif ( self.state == "auger" ) then
        self:AugerThink()
    end

    if ( self.bSolid ) then
        self:MakeDangerSound()
        self:CheckImpact()
    else
        self.lastPos = self:GetPos()
    end

    return true
end

--- Takes damage from the vehicle guns that can shoot rockets down, and sends the rocket into a spin once it has lost a quarter of its health.
---@param dmginfo CTakeDamageInfo
function ENT:OnTakeDamage(dmginfo)
    if ( self.bExploded or !dmginfo:IsDamageType(DMG_AIRBOAT) ) then return end

    local bWasDamaged = self:Health() <= MISSILE_HEALTH - AUGER_DAMAGE

    self:SetHealth(self:Health() - dmginfo:GetDamage())

    if ( bWasDamaged or self:Health() > MISSILE_HEALTH - AUGER_DAMAGE ) then return end

    local effectData = EffectData()
    effectData:SetOrigin(self:GetPos())
    util.Effect("RPGShotDown", effectData)

    self.bGuidingDisabled = true
    self:StartAuger(SHOT_DOWN_AUGER_TIME)
end

--- Blows the rocket up, with a splash in water, from CAPCMissile::DoExplosion.
function ENT:Explode()
    if ( self.bExploded ) then return end

    self.bExploded = true

    local pos = self:GetPos()

    if ( self:WaterLevel() > 0 ) then
        local effectData = EffectData()
        effectData:SetOrigin(self:WorldSpaceCenter())
        effectData:SetMagnitude(128)
        effectData:SetScale(128)
        effectData:SetFlags(0)
        util.Effect("WaterSurfaceExplosion", effectData)
    else
        local explosion = ents.Create("env_explosion")

        if ( IsValid(explosion) ) then
            local attacker = self.attacker

            explosion:SetPos(pos)
            explosion:SetOwner(IsValid(attacker) and attacker or self)
            explosion:SetKeyValue("iMagnitude", tostring(self.damage or 0))
            explosion:SetKeyValue("iRadiusOverride", tostring(self.radius or 0))
            explosion:Spawn()
            explosion:Fire("Explode")
        end
    end

    self:Remove()
end

function ENT:OnRemove()
    self:StopSound("Missile.Ignite")

    local trail = self.trail
    if ( !IsValid(trail) ) then return end

    trail:SetParent(NULL)
    trail:SetPos(self:GetPos())
    trail:SetSaveValue("m_StopEmitTime", CurTime())
    SafeRemoveEntityDelayed(trail, TRAIL_LINGER)
end
