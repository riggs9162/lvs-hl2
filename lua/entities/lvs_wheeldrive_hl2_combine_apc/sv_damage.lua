--- Damage, destruction and the smaller habits of the Combine APC, ported from CPropAPC in the Half-Life 2 code (vehicle_apc.cpp): it only takes damage from explosions and vehicle guns, smokes and throws burning chunks as it gets hurt, keeps its crew safe from bullets and blasts, warns NPCs out of its way, and goes down in a series of explosions before it falls apart.

DEFINE_BASECLASS("lvs_base_wheeldrive")

--- Number of smoke trails a damaged APC puts out, one more for every quarter of its health lost.
local MAX_SMOKE_TRAILS = 4

--- Number of explosions spread evenly over the APC's health.
local MAX_EXPLOSIONS = 4

--- Flags of the explosions the APC throws while it gets hurt: no damage, sparks, light, smoke or fireball smoke.
local DAMAGE_EXPLOSION_FLAGS = 1 + 8 + 32 + 256 + 1024

--- Strength of the fireball of those explosions.
local DAMAGE_EXPLOSION_MAGNITUDE = 1000

--- Settings of the grey smoke a damaged APC puts out, from CPropAPC::AddSmokeTrail.
local DAMAGE_SMOKE_KEYS = {
    spawnrate = "4",
    lifetime = "5",
    startsize = "32",
    endsize = "64",
    spawnradius = "4",
    opacity = "0.5",
    minspeed = "16",
    maxspeed = "16",
    mindirectedspeed = "16",
    maxdirectedspeed = "16",
}

--- Colours of that smoke.
local DAMAGE_SMOKE_START_COLOR = Vector(0.7, 0.7, 0.7)
local DAMAGE_SMOKE_END_COLOR = Vector(0.6, 0.6, 0.6)

--- Seconds each damage smoke trail keeps putting out smoke.
local DAMAGE_SMOKE_DURATION = 5

--- Burning chunks the APC throws when it is hurt and when it is destroyed.
local CHUNK_MODELS = {
    "models/gibs/helicopter_brokenpiece_01.mdl",
    "models/gibs/helicopter_brokenpiece_02.mdl",
    "models/gibs/helicopter_brokenpiece_03.mdl",
}

--- Wreck pieces the APC falls apart into, besides its hull which stays behind as the vehicle itself.
local GIB_MODELS = {
    "models/combine_apc_destroyed_gib02.mdl",
    "models/combine_apc_destroyed_gib03.mdl",
    "models/combine_apc_destroyed_gib04.mdl",
    "models/combine_apc_destroyed_gib05.mdl",
    "models/combine_apc_destroyed_gib06.mdl",
}

--- Wreck pieces lighter than this are blown away from the hull.
local GIB_KICK_MAX_MASS = 200

--- Seconds the wreck and its pieces burn.
local WRECK_BURN_TIME = 60

--- Number of explosions that go off across the APC when it is destroyed.
local DEATH_EXPLOSIONS = 5

--- Seconds the death explosions are spread over.
local DEATH_EXPLOSION_SPREAD = 1

--- Seconds before a destroyed APC without rockets falls apart, about as long as the death volley of one with rockets.
local DEATH_DELAY = 1

--- Damage types the APC takes damage from: explosions and vehicle guns.
local DAMAGE_TYPES = bit.bor(DMG_BLAST, DMG_AIRBOAT)

--- Damage types its crew is safe from.
local CREW_PROTECTED_TYPES = bit.bor(DMG_BULLET, DMG_SLASH, DMG_CLUB, DMG_BLAST)

--- Seconds between two rounds of danger sounds ahead of a moving APC.
local DANGER_SOUND_INTERVAL = 0.3

--- Returns which of a number of equal health steps a health value falls into, as CPropAPC::ShouldTriggerDamageEffect counts them.
---@param health number Health to sort.
---@param maxHealth number Full health.
---@param count number Number of steps.
---@return number range
local function GetHealthRange(health, maxHealth, count)
    return math.floor(math.max(health, 0) / maxHealth * count)
end

--- Returns a random point in the inner half of the APC's bounds.
---@param ent Entity APC.
---@return Vector point World position.
local function RandomPointInBounds(ent)
    local mins, maxs = ent:OBBMins(), ent:OBBMaxs()

    return ent:LocalToWorld(Vector(
        Lerp(math.Rand(0.25, 0.75), mins.x, maxs.x),
        Lerp(math.Rand(0.25, 0.75), mins.y, maxs.y),
        Lerp(math.Rand(0.25, 0.75), mins.z, maxs.z)
    ))
end

--- Sets off a fireball that hurts nothing and shakes the screen.
---@param pos Vector Position of the fireball.
local function HarmlessExplosion(pos)
    local explosion = ents.Create("env_explosion")
    if ( !IsValid(explosion) ) then return end

    explosion:SetPos(pos)
    explosion:SetKeyValue("spawnflags", tostring(DAMAGE_EXPLOSION_FLAGS))
    explosion:SetKeyValue("iMagnitude", tostring(DAMAGE_EXPLOSION_MAGNITUDE))
    explosion:Spawn()
    explosion:Fire("Explode")

    util.ScreenShake(pos, 25, 150, 1, 750)
end

--- Only lets explosions and vehicle guns through, as the original takes no damage from anything else, and plays the effects of the health that was lost.
---@param dmginfo CTakeDamageInfo
function ENT:OnTakeDamage(dmginfo)
    if ( !self.HL2APC ) then return BaseClass.OnTakeDamage(self, dmginfo) end
    if ( bit.band(dmginfo:GetDamageType(), DAMAGE_TYPES) == 0 ) then return end

    local previousHealth = self:GetHP()

    BaseClass.OnTakeDamage(self, dmginfo)

    self:ReactToDamage(previousHealth, dmginfo)
end

--- Adds a smoke trail and throws a burning chunk whenever the APC's health crosses one of their steps.
---@param previousHealth number Health before the damage.
---@param dmginfo CTakeDamageInfo Damage that was dealt.
function ENT:ReactToDamage(previousHealth, dmginfo)
    local health = self:GetHP()
    if ( health >= previousHealth or self:IsDestroyed() ) then return end

    local maxHealth = self:GetMaxHP()
    local pos = dmginfo:GetDamagePosition()

    if ( pos:IsZero() ) then
        pos = self:WorldSpaceCenter()
    end

    if ( GetHealthRange(previousHealth, maxHealth, MAX_SMOKE_TRAILS) != GetHealthRange(health, maxHealth, MAX_SMOKE_TRAILS) ) then
        self:AddSmokeTrail(pos)
    end

    if ( GetHealthRange(previousHealth, maxHealth, MAX_EXPLOSIONS) != GetHealthRange(health, maxHealth, MAX_EXPLOSIONS) ) then
        self:ExplodeAndThrowChunk(pos)
    end
end

--- Sets off a harmless explosion and starts a column of smoke at the next damage point of the hull, which dies down after a few seconds.
---@param pos Vector Where the damage hit, used when the model has no damage point left.
function ENT:AddSmokeTrail(pos)
    HarmlessExplosion(pos)

    local smokeTrailCount = self.smokeTrailCount or 0
    if ( smokeTrailCount >= MAX_SMOKE_TRAILS ) then return end

    local attachment = self:GetAttachment(self:LookupAttachment("damage" .. smokeTrailCount))

    self.smokeTrailCount = smokeTrailCount + 1

    local trail = ents.Create("env_smoketrail")
    if ( !IsValid(trail) ) then return end

    for key, value in pairs(DAMAGE_SMOKE_KEYS) do
        trail:SetKeyValue(key, value)
    end

    trail:SetSaveValue("m_StartColor", DAMAGE_SMOKE_START_COLOR)
    trail:SetSaveValue("m_EndColor", DAMAGE_SMOKE_END_COLOR)
    trail:SetPos(attachment and attachment.Pos or pos)
    trail:SetAngles(Angle(-90, 0, 0))
    trail:SetParent(self)
    trail:Spawn()
    trail:Activate()

    self:DeleteOnRemove(trail)

    timer.Simple(DAMAGE_SMOKE_DURATION, function()
        if ( !IsValid(trail) ) then return end

        trail:SetSaveValue("m_StopEmitTime", CurTime())
        SafeRemoveEntityDelayed(trail, 5)
    end)
end

--- Throws a burning chunk out of the APC.
---@param pos Vector Position the chunk starts at.
---@param minPitch number Lowest angle above level it is thrown at, in degrees with negative being upwards.
---@param maxPitch number Highest such angle.
---@return Entity|nil chunk
function ENT:ThrowChunk(pos, minPitch, maxPitch)
    local chunk = ents.Create("prop_physics")
    if ( !IsValid(chunk) ) then return nil end

    local lifetime = math.Rand(6, 8)

    chunk:SetModel(CHUNK_MODELS[math.random(#CHUNK_MODELS)])
    chunk:SetPos(pos)
    chunk:SetAngles(Angle(math.Rand(-90, 90), math.Rand(-90, 90), math.Rand(-90, 90)))
    chunk:Spawn()
    chunk:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    chunk:Ignite(lifetime)

    local phys = chunk:GetPhysicsObject()

    if ( IsValid(phys) ) then
        local direction = Angle(math.Rand(minPitch, maxPitch), math.Rand(0, 360), 0):Forward()

        phys:SetVelocity(direction * math.Rand(300, 900) + self:GetVelocity())
        phys:AddAngleVelocity(VectorRand(-180, 180))
    end

    SafeRemoveEntityDelayed(chunk, lifetime)

    return chunk
end

--- Sets off a harmless explosion and throws a burning chunk, from CPropAPC::ExplodeAndThrowChunk.
---@param pos Vector Position of the explosion.
function ENT:ExplodeAndThrowChunk(pos)
    HarmlessExplosion(pos)
    self:ThrowChunk(pos, -40, 0)
end

--- Sets off the explosions across the APC when it is destroyed, throws a few burning chunks and sets it alight, from CPropAPC::Event_Killed.
function ENT:OnStartExplosion()
    if ( !self.HL2APC ) then return BaseClass.OnStartExplosion(self) end

    local lastPoint = self:WorldSpaceCenter()

    for index = 1, DEATH_EXPLOSIONS do
        local point = RandomPointInBounds(self)

        lastPoint = point

        timer.Simple(math.Rand(0, DEATH_EXPLOSION_SPREAD), function()
            local effectData = EffectData()
            effectData:SetOrigin(point)
            effectData:SetScale(math.random(4, 10))
            effectData:SetMagnitude(math.random(8, 15))
            effectData:SetFlags(index <= 2 and 0 or 1)
            util.Effect("Explosion", effectData, true, true)
        end)
    end

    for _ = 1, math.random(1, 4) do
        self:ThrowChunk(lastPoint, -20, 20)
    end

    util.ScreenShake(lastPoint, 25, 150, 1, 750)
    self:Ignite(WRECK_BURN_TIME)
end

--- Starts the death sequence instead of the LVS fire trail: the explosions across the hull, then the death volley of an armed APC, and only after that does it fall apart.
---@param explodeTime number Seconds the LVS base would wait.
---@return number explodeTime Seconds until the APC falls apart.
function ENT:PreExplode(explodeTime)
    if ( !self.HL2APC ) then return BaseClass.PreExplode(self, explodeTime) end

    self:OnStartExplosion()

    local delay = self.StartDeathVolley and self:StartDeathVolley() or DEATH_DELAY

    timer.Simple(delay, function()
        if ( IsValid(self) ) then
            self:FinishDeathSequence()
        end
    end)

    return delay
end

--- Holds the destroyed APC together until its death sequence is over, since the LVS base would otherwise break it apart as soon as it slows down.
function ENT:Explode()
    if ( self.HL2APC and !self.bDeathSequenceOver ) then return end

    BaseClass.Explode(self)
end

--- Ends the death sequence and lets the APC fall apart.
function ENT:FinishDeathSequence()
    self.bDeathSequenceOver = true
    self:Explode()
end

--- Breaks the wreck pieces off the hull, blowing the light ones away, and sets them all alight, from CPropAPC::CreateCorpse.
function ENT:OnFinishExplosion()
    if ( !self.HL2APC ) then return BaseClass.OnFinishExplosion(self) end

    local pos = self:GetPos()
    local angles = self:GetAngles()
    local velocity = self:GetVelocity()
    local center = self:WorldSpaceCenter()

    for _, model in ipairs(GIB_MODELS) do
        local gib = ents.Create("prop_physics")
        if ( !IsValid(gib) ) then continue end

        gib:SetModel(model)
        gib:SetPos(pos)
        gib:SetAngles(angles)
        gib:Spawn()
        gib:Ignite(WRECK_BURN_TIME)

        local phys = gib:GetPhysicsObject()
        if ( !IsValid(phys) ) then continue end

        phys:SetVelocity(velocity)

        local mass = phys:GetMass()
        if ( mass >= GIB_KICK_MAX_MASS ) then continue end

        local direction = gib:LocalToWorld(phys:GetMassCenter()) - center
        direction.z = math.abs(direction.z)
        direction:Normalize()

        local kick = direction * (100 * math.Rand(150, 300) / mass)
        kick.z = kick.z + 100

        phys:AddVelocity(kick)
        phys:AddAngleVelocity(VectorRand(-500, 500))
        gib:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    end
end

--- Lets the hull that stays behind burn as long as the original wreck does. The LVS base has just removed the flame it was burning with, so the old fire is put out first or the new one would not take.
function ENT:OnExploded()
    if ( !self.HL2APC ) then return BaseClass.OnExploded(self) end

    self:Extinguish()
    self:Ignite(WRECK_BURN_TIME)
end

--- Lays a path of danger sounds ahead of a driven APC, straight ahead and a little to both sides, so that NPCs get out of its way, from CPropAPC::ProcessMovement.
function ENT:MakeDangerSounds()
    local now = CurTime()
    if ( now < (self.nextDangerSound or 0) ) then return end
    if ( self:IsDestroyed() or ( !self:GetAI() and !IsValid(self:GetDriver()) ) ) then return end

    self.nextDangerSound = now + DANGER_SOUND_INTERVAL

    local pos = self:GetPos()
    local angles = self:GetAngles()

    sound.EmitHint(SOUND_DANGER, pos + self:GetForward() * 600, 400, 0.1, self)

    for _, offset in ipairs({20, -20}) do
        sound.EmitHint(SOUND_DANGER, pos + Angle(0, angles.y + offset, 0):Forward() * 400, 400, 0.1, self)
    end
end

function ENT:OnTick()
    if ( !self.HL2APC ) then return end

    self:MakeDangerSounds()
end

--- Keeps the crew of an APC safe from bullets, blades, blunt hits and blasts, from CPropAPC::PassengerDamageModifier.
---@param target Entity Entity taking the damage.
---@param dmginfo CTakeDamageInfo Damage being dealt.
---@return boolean|nil bBlock True to block the damage.
local function ProtectCrew(target, dmginfo)
    if ( !target:IsPlayer() or !target.lvsGetVehicle ) then return end

    local vehicle = target:lvsGetVehicle()
    if ( !IsValid(vehicle) or !vehicle.HL2APC ) then return end
    if ( bit.band(dmginfo:GetDamageType(), CREW_PROTECTED_TYPES) == 0 ) then return end

    return true
end

hook.Add("EntityTakeDamage", "LVS.HL2.CombineAPC.ProtectCrew", function(target, dmginfo)
    return ProtectCrew(target, dmginfo)
end)
