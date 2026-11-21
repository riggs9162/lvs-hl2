--- Damage and destruction of the dropship container, ported from CCombineDropshipContainer::OnTakeDamage, AddSmokeTrail, ThrowFlamingGib and CreateCorpse. Only explosions and vehicle guns hurt it; every rocket takes a quarter of its health.

--- Rocket hits that destroy the container, DROPSHIP_CRATE_ROCKET_HITS.
local ROCKET_HITS = 4

--- Number of smoke trails and of explosions spread over the container's health.
local MAX_SMOKE_TRAILS = 4
local MAX_EXPLOSIONS = 4

--- Magnitude and radius of the harmless explosions on the hull.
local HULL_EXPLOSION_MAGNITUDE = 1000
local HULL_EXPLOSION_RADIUS = 500

--- Spawn flags of env_explosion: no damage, no sparks, no light and no smoke.
local HULL_EXPLOSION_FLAGS = 1 + 256 + 512 + 2

--- Fewest and most burning chunks thrown out when the container is destroyed.
local DEATH_CHUNKS_MIN = 4
local DEATH_CHUNKS_MAX = 6

--- Shortest and longest seconds a burning chunk lasts.
local CHUNK_LIFETIME_MIN = 6
local CHUNK_LIFETIME_MAX = 8

--- Seconds a smoke trail of the hull lasts.
local SMOKE_TRAIL_LIFETIME = 5

--- Seconds the large wreck pieces last.
local GIB_LIFETIME = 30

--- Burning chunks the container throws out, s_pChunkModelName.
local CHUNK_MODELS = {
    "models/gibs/helicopter_brokenpiece_01.mdl",
    "models/gibs/helicopter_brokenpiece_02.mdl",
    "models/gibs/helicopter_brokenpiece_03.mdl",
}

--- Settings of the smoke trail of a damaged container.
local HULL_SMOKE = {
    spawnrate = "20",
    lifetime = "4",
    startcolor = "0.7 0.7 0.7",
    endcolor = "0.6 0.6 0.6",
    startsize = "15",
    endsize = "50",
    spawnradius = "15",
    opacity = "0.75",
    minspeed = "10",
    maxspeed = "20",
}

--- Settings of the smoke trail of a burning chunk.
local CHUNK_SMOKE = {
    spawnrate = "80",
    lifetime = "0.8",
    startcolor = "0.3 0.3 0.3",
    endcolor = "0.5 0.5 0.5",
    startsize = "10",
    endsize = "40",
    spawnradius = "5",
    opacity = "0.4",
    minspeed = "15",
    maxspeed = "25",
}

--- Sets off an explosion on the hull that hurts nothing and shakes the screen.
---@param pos Vector
local function HullExplosion(pos)
    local explosion = ents.Create("env_explosion")

    if ( IsValid(explosion) ) then
        explosion:SetPos(pos)
        explosion:SetKeyValue("spawnflags", tostring(HULL_EXPLOSION_FLAGS))
        explosion:SetKeyValue("iMagnitude", tostring(HULL_EXPLOSION_MAGNITUDE))
        explosion:SetKeyValue("iRadiusOverride", tostring(HULL_EXPLOSION_RADIUS))
        explosion:Spawn()
        explosion:Fire("Explode")
    end

    util.ScreenShake(pos, 25, 150, 1, 750)
end

--- Creates a smoke trail on an entity.
---@param parent Entity
---@param settings table
---@param lifetime number
---@param attachmentName string|nil
---@param pos Vector|nil Position when there is no attachment.
local function CreateSmokeTrail(parent, settings, lifetime, attachmentName, pos)
    local trail = ents.Create("env_smoketrail")
    if ( !IsValid(trail) ) then return end

    for key, value in pairs(settings) do
        trail:SetKeyValue(key, value)
    end

    local attachment = attachmentName and parent:GetAttachment(parent:LookupAttachment(attachmentName))

    trail:SetPos(attachment and attachment.Pos or pos or parent:GetPos())
    trail:SetParent(parent)
    trail:Spawn()
    trail:Activate()

    if ( attachment ) then
        trail:Fire("SetParentAttachment", attachmentName)
    end

    SafeRemoveEntityDelayed(trail, lifetime)
    parent:DeleteOnRemove(trail)
end

--- Returns a random point inside the container's bounds.
---@param ent Entity
---@return Vector pos
local function RandomPointInBounds(ent)
    local mins, maxs = ent:OBBMins(), ent:OBBMaxs()

    return ent:LocalToWorld(Vector(math.Rand(mins.x, maxs.x), math.Rand(mins.y, maxs.y), math.Rand(mins.z, maxs.z)))
end

--- Prepares the damage state.
function ENT:InitDamage()
    self.smokeTrailCount = 0
end

--- Returns whether the health crossed one of the steps of an effect.
---@param previousHealth number
---@param count number Number of steps.
---@return boolean bTrigger
function ENT:ShouldTriggerDamageEffect(previousHealth, count)
    local maxHealth = self:GetMaxHP()

    return math.floor(previousHealth / maxHealth * count) != math.floor(math.max(self:GetHP(), 0) / maxHealth * count)
end

--- Adds a smoke trail at the next damage point, started with a bang, from CCombineDropshipContainer::AddSmokeTrail.
---@param pos Vector
function ENT:AddSmokeTrail(pos)
    HullExplosion(pos)

    if ( self.smokeTrailCount >= MAX_SMOKE_TRAILS ) then return end

    local attachmentName = "damage" .. self.smokeTrailCount

    self.smokeTrailCount = self.smokeTrailCount + 1

    CreateSmokeTrail(self, HULL_SMOKE, SMOKE_TRAIL_LIFETIME, self:LookupAttachment(attachmentName) > 0 and attachmentName or nil, pos)
end

--- Throws a burning, smoking chunk out of the container, from CCombineDropshipContainer::ThrowFlamingGib.
function ENT:ThrowFlamingGib()
    local chunk = ents.Create("prop_physics")
    if ( !IsValid(chunk) ) then return end

    local lifetime = math.Rand(CHUNK_LIFETIME_MIN, CHUNK_LIFETIME_MAX)

    chunk:SetModel(CHUNK_MODELS[math.random(#CHUNK_MODELS)])
    chunk:SetPos(RandomPointInBounds(self))
    chunk:SetAngles(AngleRand(-90, 90))
    chunk:Spawn()
    chunk:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    chunk:Ignite(lifetime)

    local phys = chunk:GetPhysicsObject()

    if ( IsValid(phys) ) then
        phys:SetVelocity(Angle(math.Rand(-20, 20), math.Rand(0, 360), 0):Forward() * math.Rand(300, 900) + self:GetVelocity())
        phys:AddAngleVelocity(VectorRand(-180, 180))
    end

    CreateSmokeTrail(chunk, CHUNK_SMOKE, lifetime)
    SafeRemoveEntityDelayed(chunk, lifetime)
end

--- Takes damage only from explosions and vehicle guns; a rocket takes a fixed quarter of the health, counted once even when its blast also hits the dropship, from CCombineDropshipContainer::OnTakeDamage.
---@param dmginfo CTakeDamageInfo
function ENT:OnTakeDamage(dmginfo)
    if ( self:GetHP() <= 0 ) then return end
    if ( bit.band(dmginfo:GetDamageType(), bit.bor(DMG_BLAST, DMG_AIRBOAT)) == 0 ) then return end

    local previousHealth = self:GetHP()
    local now = CurTime()

    if ( dmginfo:IsDamageType(DMG_BLAST) ) then
        local inflictor = dmginfo:GetInflictor()

        if ( inflictor != self.lastInflictor or now != self.lastHitTime ) then
            self:SetHP(previousHealth - (self:GetMaxHP() / ROCKET_HITS + 1))
            self.lastInflictor = inflictor
            self.lastHitTime = now
        end
    else
        self:SetHP(previousHealth - dmginfo:GetDamage())
    end

    local attacker = dmginfo:GetAttacker()

    if ( IsValid(attacker) and attacker:IsPlayer() ) then
        net.Start("lvs_hitmarker")
        net.WriteBool(false)
        net.Send(attacker)
    end

    if ( self:GetHP() <= 0 ) then
        self:SetHP(0)
        self.FinalAttacker = attacker
        self.FinalInflictor = dmginfo:GetInflictor()
        self:Explode()

        return
    end

    if ( previousHealth == self:GetHP() ) then return end

    local pos = dmginfo:GetDamagePosition()

    if ( pos:IsZero() ) then
        pos = self:WorldSpaceCenter()
    end

    if ( self:ShouldTriggerDamageEffect(previousHealth, MAX_SMOKE_TRAILS) ) then
        self:AddSmokeTrail(pos)
    end

    if ( self:ShouldTriggerDamageEffect(previousHealth, MAX_EXPLOSIONS) ) then
        HullExplosion(pos)
        self:ThrowFlamingGib()
    end
end

--- Bursts the container: an explosion, its wreck pieces and a few burning chunks, from CCombineDropshipContainer::CreateCorpse. A dropship carrying it lets go first.
function ENT:OnFinishExplosion()
    local carrier = self:GetCarryingDropship()

    if ( carrier and carrier.ReleaseCargo ) then
        carrier:ReleaseCargo()
    end

    local explosion = ents.Create("env_explosion")

    if ( IsValid(explosion) ) then
        explosion:SetPos(RandomPointInBounds(self))
        explosion:SetKeyValue("spawnflags", "1")
        explosion:SetKeyValue("iMagnitude", tostring(math.random(4, 10) * 10))
        explosion:Spawn()
        explosion:Fire("Explode")
    end

    local velocity = self:GetVelocity()

    for _, model in ipairs(self.GibModels) do
        local gib = ents.Create("prop_physics")
        if ( !IsValid(gib) ) then continue end

        gib:SetModel(model)
        gib:SetPos(self:GetPos())
        gib:SetAngles(self:GetAngles())
        gib:Spawn()
        gib:SetCollisionGroup(COLLISION_GROUP_NPC)

        local phys = gib:GetPhysicsObject()

        if ( IsValid(phys) ) then
            phys:SetVelocity(velocity + (gib:WorldSpaceCenter() - self:WorldSpaceCenter()):GetNormalized() * math.Rand(50, 250))
        end

        SafeRemoveEntityDelayed(gib, GIB_LIFETIME)
    end

    for _ = 1, math.random(DEATH_CHUNKS_MIN, DEATH_CHUNKS_MAX) do
        self:ThrowFlamingGib()
    end
end
