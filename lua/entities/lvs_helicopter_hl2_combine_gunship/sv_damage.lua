--- Damage and death of the gunship, ported from CNPC_CombineGunship::TraceAttack, OnTakeDamage_Alive, Event_Killed, BeginCrash, BeginDestruct, CreateSmokeTrail and SelfDestruct. Like the original it shrugs off bullets and small blasts, loses a fixed share of its health to every strong blast, and once shot down sinks for three seconds, shaken by explosions, before it bursts apart.

DEFINE_BASECLASS("lvs_base_helicopter")

--- Weakest blast that hurts the gunship, GUNSHIP_MIN_DAMAGE_THRESHOLD.
local MIN_DAMAGE_THRESHOLD = 50

--- Speed at which a blast knocks the gunship away.
local BLAST_KNOCKBACK = 200

--- Chance of one in this many that a bullet glances off the hull with a visible ricochet.
local RICOCHET_CHANCE = 3

--- Length and speed of a ricochet tracer.
local RICOCHET_LENGTH = 1024
local RICOCHET_SPEED = 3500

--- Seconds a damaged gunship smokes after one of its first hits.
local SMOKE_SHORT_LIFETIME = 8

--- Number of metal scraps a hit throws out, and the number the final burst throws out.
local HIT_GIB_COUNT = 10
local DEATH_GIB_COUNT = 20

--- Seconds a metal scrap lasts.
local SCRAP_LIFETIME = 2.5

--- Speed at which the scraps of a hit fly off against the blast.
local HIT_GIB_SPEED = 200

--- Highest speed of a scrap of the final burst along each axis.
local DEATH_GIB_SPEED = 1000

--- Seconds a shot down gunship sinks before it bursts apart, from CNPC_CombineGunship::BeginDestruct.
local DESTRUCT_TIME = 3

--- Seconds left of the sinking below which the explosions on the hull come more often.
local DESTRUCT_LATE_TIME = 1.5

--- Chance of one in this many of an explosion on every think while sinking, early and late.
local DYING_EXPLOSION_CHANCE_EARLY = 4
local DYING_EXPLOSION_CHANCE_LATE = 3

--- Magnitude and radius of an explosion on the hull of a sinking gunship.
local DYING_EXPLOSION_MAGNITUDE = 100
local DYING_EXPLOSION_RADIUS = 128

--- Speed at which an explosion on the hull knocks a sinking gunship away.
local DYING_EXPLOSION_PUSH = 128

--- Number of explosions, their spread and magnitude when the gunship bursts apart.
local DEATH_EXPLOSION_COUNT = 6
local DEATH_EXPLOSION_SPREAD = 200
local DEATH_EXPLOSION_MAGNITUDE = 10

--- Seconds the large pieces of the wreck last.
local GIB_LIFETIME = 30

--- Spawn flag of env_explosion that keeps it from hurting anything.
local EXPLOSION_NO_DAMAGE = 1

--- Small metal scraps of the original's MetalChunks.
local SCRAP_MODELS = {
    "models/gibs/metal_gib1.mdl",
    "models/gibs/metal_gib2.mdl",
    "models/gibs/metal_gib3.mdl",
    "models/gibs/metal_gib4.mdl",
    "models/gibs/metal_gib5.mdl",
}

--- Settings of the smoke trail of a damaged gunship.
local DAMAGE_SMOKE = {
    spawnrate = "48",
    lifetime = "2.5",
    startcolor = "0.25 0.25 0.25",
    endcolor = "0 0 0",
    startsize = "24",
    endsize = "128",
    spawnradius = "4",
    minspeed = "8",
    maxspeed = "64",
    opacity = "0.2",
}

--- Settings of the thicker smoke trail of a shot down gunship.
local DYING_SMOKE = {
    spawnrate = "48",
    lifetime = "2.5",
    startcolor = "0.25 0.25 0.25",
    endcolor = "0 0 0",
    startsize = "64",
    endsize = "128",
    spawnradius = "4",
    minspeed = "8",
    maxspeed = "64",
    opacity = "0.5",
}

--- Sets off an explosion that hurts nothing, as ExplosionCreate does when told not to do damage.
---@param pos Vector
---@param magnitude number
---@param radius number|nil
local function HarmlessExplosion(pos, magnitude, radius)
    local explosion = ents.Create("env_explosion")
    if ( !IsValid(explosion) ) then return end

    explosion:SetPos(pos)
    explosion:SetKeyValue("spawnflags", tostring(EXPLOSION_NO_DAMAGE))
    explosion:SetKeyValue("iMagnitude", tostring(magnitude))

    if ( radius ) then
        explosion:SetKeyValue("iRadiusOverride", tostring(radius))
    end

    explosion:Spawn()
    explosion:Fire("Explode")
end

--- Throws out small metal scraps that vanish after a moment, as the original's BreakModel temp entities do.
---@param pos Vector Position the scraps start at.
---@param count number Number of scraps.
---@param velocityFunc function Returns the velocity of each scrap.
local function ThrowScraps(pos, count, velocityFunc)
    for _ = 1, count do
        local scrap = ents.Create("prop_physics")
        if ( !IsValid(scrap) ) then return end

        scrap:SetModel(SCRAP_MODELS[math.random(#SCRAP_MODELS)])
        scrap:SetPos(pos + VectorRand(-40, 40))
        scrap:SetAngles(AngleRand())
        scrap:Spawn()
        scrap:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

        local phys = scrap:GetPhysicsObject()

        if ( IsValid(phys) ) then
            phys:SetVelocity(velocityFunc())
            phys:AddAngleVelocity(VectorRand(-400, 400))
        end

        SafeRemoveEntityDelayed(scrap, SCRAP_LIFETIME)
    end
end

--- Prepares the damage state.
function ENT:InitDamage()
    self.destructTime = nil
    self.bDestructOver = false
end

--- Returns how many strong blasts it takes to bring the gunship down on the current skill level, from sk_gunship_health_increments.
---@return number increments
function ENT:GetHealthIncrements()
    local convar = GetConVar("sk_gunship_health_increments")
    local increments = convar and convar:GetInt() or 5
    local skill = game.GetSkillLevel()

    if ( skill == 1 ) then
        increments = math.ceil(increments * 0.5)
    elseif ( skill == 3 ) then
        increments = math.floor(increments * 1.5)
    end

    return math.max(increments, 1)
end

--- Removes the smoke trail.
function ENT:RemoveSmokeTrail()
    SafeRemoveEntity(self.smokeTrail)
    self.smokeTrail = nil
end

--- Lets smoke pour from the left exhaust, either for a while or for good.
---@param settings table Settings of the trail.
---@param lifetime number|nil Seconds the trail lasts, or nil to keep it.
function ENT:CreateSmokeTrail(settings, lifetime)
    local body = self:GetBody()
    local parent = IsValid(body) and body or self
    local trail = ents.Create("env_smoketrail")
    if ( !IsValid(trail) ) then return end

    for key, value in pairs(settings) do
        trail:SetKeyValue(key, value)
    end

    local attachment = parent:GetAttachment(parent:LookupAttachment("exhaustl"))

    trail:SetPos(attachment and attachment.Pos or parent:GetPos())
    trail:SetParent(parent)
    trail:Spawn()
    trail:Activate()

    if ( attachment ) then
        trail:Fire("SetParentAttachment", "exhaustl")
    end

    if ( lifetime ) then
        SafeRemoveEntityDelayed(trail, lifetime)
    end

    self:DeleteOnRemove(trail)
    self.smokeTrail = trail
end

--- Draws a ricochet off the hull for one bullet in three, from CNPC_CombineGunship::TraceAttack.
---@param dmginfo CTakeDamageInfo
function ENT:Ricochet(dmginfo)
    if ( math.random(1, RICOCHET_CHANCE) != 1 ) then return end

    local pos = dmginfo:GetDamagePosition()
    local direction = dmginfo:GetDamageForce():GetNormalized()

    if ( pos:IsZero() or direction:IsZero() ) then return end

    local ricochet = -direction + VectorRand(-0.5, 0.5)
    ricochet:Normalize()

    local effectData = EffectData()
    effectData:SetStart(pos)
    effectData:SetOrigin(pos + ricochet * RICOCHET_LENGTH)
    effectData:SetScale(RICOCHET_SPEED)
    util.Effect("Tracer", effectData)
end

--- Takes a fixed share of the health from every blast strong enough to hurt the gunship, knocks it away, makes it cry out, smoke and throw out scraps, and lets bullets glance off, from CNPC_CombineGunship::OnTakeDamage_Alive.
---@param dmginfo CTakeDamageInfo
function ENT:OnTakeDamage(dmginfo)
    if ( self:IsDestroyed() ) then return end

    if ( dmginfo:GetDamageType() != DMG_GENERIC ) then
        if ( dmginfo:IsDamageType(DMG_BULLET) or dmginfo:IsDamageType(DMG_AIRBOAT) ) then
            self:Ricochet(dmginfo)
        end

        if ( !dmginfo:IsDamageType(DMG_BLAST) or dmginfo:GetDamage() < MIN_DAMAGE_THRESHOLD ) then return end
    end

    self:EmitSound("NPC_CombineGunship.Pain")

    local damageDir = dmginfo:GetDamageForce():GetNormalized()

    if ( !self:GetGroundAttacking() ) then
        self:ApplyVelocityImpulse(damageDir * BLAST_KNOCKBACK)
    end

    local maxHealth = self:GetMaxHP()
    local increments = self:GetHealthIncrements()
    local healthIncrement = math.floor(increments - self:GetHP() / (maxHealth / increments))

    if ( !IsValid(self.smokeTrail) ) then
        self:CreateSmokeTrail(DAMAGE_SMOKE, healthIncrement < 2 and SMOKE_SHORT_LIFETIME or nil)
    end

    local gibVelocity = self:GetVelocity() - damageDir * HIT_GIB_SPEED

    ThrowScraps(self:WorldSpaceCenter(), HIT_GIB_COUNT, function()
        return gibVelocity
    end)

    dmginfo:SetDamage(maxHealth / increments + 1)
    dmginfo:SetDamageForce(vector_origin)

    BaseClass.OnTakeDamage(self, dmginfo)
end

--- Silences the weapons and lets the gunship sink, smoking heavily, until it bursts apart three seconds later, from CNPC_CombineGunship::Event_Killed, BeginCrash and BeginDestruct.
function ENT:OnDestroyed()
    self:CannonShutdown()
    self:StopGroundAttack(false)

    self:RemoveSmokeTrail()
    self:CreateSmokeTrail(DYING_SMOKE)

    self.destructTime = CurTime() + DESTRUCT_TIME
end

--- Skips the LVS explosion and fire trail, since the gunship bursts apart on its own time.
---@return number explodeTime
function ENT:PreExplode()
    return DESTRUCT_TIME
end

--- Holds the LVS explosion back until a shot down gunship has finished sinking.
function ENT:Explode()
    if ( self.destructTime and !self.bDestructOver ) then return end

    BaseClass.Explode(self)
end

--- Shakes a sinking gunship with explosions, more often the closer it is to bursting, and bursts it once its time is up, from CNPC_CombineGunship::PrescheduleThink.
function ENT:DyingThink()
    if ( !self.destructTime ) then return end

    local timeLeft = self.destructTime - CurTime()

    if ( timeLeft <= 0 ) then
        self.bDestructOver = true
        self:Explode()

        return
    end

    local chance = timeLeft > DESTRUCT_LATE_TIME and DYING_EXPLOSION_CHANCE_EARLY or DYING_EXPLOSION_CHANCE_LATE
    if ( math.random(1, chance) != 1 ) then return end

    local mins, maxs = self:OBBMins(), self:OBBMaxs()
    local point = self:LocalToWorld(Vector(
        Lerp(math.Rand(0.25, 0.75), mins.x, maxs.x),
        Lerp(math.Rand(0.25, 0.75), mins.y, maxs.y),
        Lerp(math.Rand(0.25, 0.75), mins.z, maxs.z)
    ))

    self:ApplyVelocityImpulse((self:GetPos() - point):GetNormalized() * DYING_EXPLOSION_PUSH)

    HarmlessExplosion(point, DYING_EXPLOSION_MAGNITUDE, DYING_EXPLOSION_RADIUS)
end

--- Creates the large pieces of the wreck where the parts of the body were.
function ENT:CreateWreck()
    local body = self:GetBody()
    local source = IsValid(body) and body or self
    local pos = source:GetPos()
    local angles = source:GetAngles()
    local velocity = self:GetVelocity()

    velocity.z = 0

    for _, model in ipairs(self.GibModels) do
        local gib = ents.Create("prop_physics")
        if ( !IsValid(gib) ) then continue end

        gib:SetModel(model)
        gib:SetPos(pos)
        gib:SetAngles(angles)
        gib:Spawn()
        gib:Activate()
        gib:SetCollisionGroup(COLLISION_GROUP_NPC)

        local phys = gib:GetPhysicsObject()

        if ( IsValid(phys) ) then
            phys:SetVelocity(velocity + (gib:WorldSpaceCenter() - self:WorldSpaceCenter()):GetNormalized() * math.Rand(100, 300))
            phys:AddAngleVelocity(VectorRand(-90, 90))
        end

        SafeRemoveEntityDelayed(gib, GIB_LIFETIME)
    end
end

--- Bursts the gunship apart: explosions across the hull, a lasting cloud of pulse smoke, the large pieces of the wreck and a shower of scraps, from CNPC_CombineGunship::SelfDestruct.
function ENT:OnFinishExplosion()
    local pos = self:GetPos()

    EmitSound("NPC_CombineGunship.Explode", pos)

    for _ = 1, DEATH_EXPLOSION_COUNT do
        HarmlessExplosion(pos + VectorRand(-DEATH_EXPLOSION_SPREAD, DEATH_EXPLOSION_SPREAD), DEATH_EXPLOSION_MAGNITUDE)
    end

    local cloud = ents.Create("ar2explosion")

    if ( IsValid(cloud) ) then
        cloud:SetPos(pos)
        cloud:Spawn()
        cloud:Activate()
        SafeRemoveEntityDelayed(cloud, 10)
    end

    self:CreateWreck()

    ThrowScraps(pos, DEATH_GIB_COUNT, function()
        return VectorRand(-DEATH_GIB_SPEED, DEATH_GIB_SPEED)
    end)
end

--- Stops the looping sounds that belong to the gunship.
function ENT:StopLoopingSounds()
    if ( self.cannonSound ) then
        self.cannonSound:Stop()
    end
end
