--- Damage reactions and destruction of the hunter-chopper, ported from OnTakeDamage, OnTakeDamage_Alive, AddSmokeTrail, ExplodeAndThrowChunk, DropCorpse and Chopper_BecomeChunks of the Half-Life 2 attack helicopter (npc_attackchopper.cpp).

DEFINE_BASECLASS("lvs_base_helicopter")

--- Class of the bombs the helicopter drops.
local BOMB_CLASS = "grenade_helicopter"

--- Class of the three large wreck pieces the helicopter breaks into.
local DEATH_CHUNK_CLASS = "lvs_helicopter_hl2_combine_hunter_chunk"

--- Seconds between two thinks of the damage effects.
local DAMAGE_THINK_INTERVAL = 0.1

--- Number of smoke and fire trails a nearly destroyed helicopter drags along, one more for every fifth of its health lost.
local MAX_SMOKE_TRAILS = 5

--- Number of explosions spread evenly over the helicopter's health.
local MAX_EXPLOSIONS = 13

--- Number of gunners that can fall out, spread evenly over the helicopter's health.
local MAX_CORPSES = 2

--- Number of health steps at which the damage alarm sounds.
local MAX_DAMAGE_ALERTS = 4

--- Speed a blast knocks the helicopter away with.
local BLAST_PUSH_SPEED = 500

--- Smallest roll goal offset a blast leaves behind.
local BLAST_ROLL_MIN = 10

--- Largest roll goal offset a blast leaves behind.
local BLAST_ROLL_MAX = 30

--- Seconds that must pass between two gunners falling out.
local CORPSE_INTERVAL = 3

--- Largest damage that still adds to the force a gunner is thrown out with.
local CORPSE_MAX_DAMAGE = 250

--- Force a gunner is thrown out with per point of damage.
local CORPSE_FORCE_PER_DAMAGE = 300

--- Seconds a fallen gunner stays in the world.
local CORPSE_LIFETIME = 15

--- Seconds a large flaming chunk stays in the world.
local CHUNK_LIFETIME = 5

--- Seconds the fire on a wreck piece burns.
local DEATH_CHUNK_FIRE_LIFETIME = 10

--- Chance per think, as one in this many, that a falling helicopter throws another explosion.
local DYING_EXPLOSION_CHANCE = 5

--- Flaming chunks that break off the helicopter.
local CHUNK_MODELS = {
    "models/gibs/helicopter_brokenpiece_01.mdl",
    "models/gibs/helicopter_brokenpiece_02.mdl",
    "models/gibs/helicopter_brokenpiece_03.mdl",
}

--- Small metal scraps that carry the short fire trails of an explosion.
local SMALL_CHUNK_MODELS = {
    "models/gibs/metal_gib1.mdl",
    "models/gibs/metal_gib2.mdl",
    "models/gibs/metal_gib3.mdl",
    "models/gibs/metal_gib4.mdl",
    "models/gibs/metal_gib5.mdl",
}

--- Wreck piece that is the helicopter's body.
local DEATH_CHUNK_BODY = "models/gibs/helicopter_brokenpiece_06_body.mdl"

--- Wreck piece that is the helicopter's cockpit.
local DEATH_CHUNK_COCKPIT = "models/gibs/helicopter_brokenpiece_04_cockpit.mdl"

--- Wreck piece that is the helicopter's tail.
local DEATH_CHUNK_TAIL = "models/gibs/helicopter_brokenpiece_05_tailfan.mdl"

--- Settings of the dark smoke a damaged helicopter trails.
local DAMAGE_SMOKE = {
    spawnrate = "48",
    lifetime = "0.5",
    startcolor = "0.15 0.15 0.15",
    endcolor = "0 0 0",
    startsize = "24",
    endsize = "80",
    spawnradius = "8",
    opacity = "0.2",
    minspeed = "16",
    maxspeed = "64",
}

--- Settings of the grey smoke a falling wreck piece trails.
local DEATH_CHUNK_SMOKE = {
    spawnrate = "4",
    lifetime = "2",
    startcolor = "0.7 0.7 0.7",
    endcolor = "0.6 0.6 0.6",
    startsize = "32",
    endsize = "64",
    spawnradius = "8",
    opacity = "0.35",
    minspeed = "0",
    maxspeed = "8",
}

--- Returns which of a number of equal health steps a health value falls into, counted from zero at no health.
---@param health number Health to sort.
---@param maxHealth number Full health.
---@param count number Number of steps.
---@return number range
local function GetHealthRange(health, maxHealth, count)
    return math.floor(math.max(health, 0) / maxHealth * count)
end

--- Attaches an engine particle trail to an entity.
---@param class string Class of the trail entity.
---@param parent Entity Entity the trail follows.
---@param attachmentName string|nil Attachment of the parent to follow, or nil for its origin.
---@param keyValues table|nil Settings of the trail.
---@param lifetime number|nil Seconds after which the trail is removed, or nil to keep it as long as the parent.
---@return Entity|nil trail
local function CreateTrail(class, parent, attachmentName, keyValues, lifetime)
    local trail = ents.Create(class)
    if ( !IsValid(trail) ) then return nil end

    local attachment = attachmentName and parent:GetAttachment(parent:LookupAttachment(attachmentName))

    for key, value in pairs(keyValues or {}) do
        trail:SetKeyValue(key, value)
    end

    trail:SetPos(attachment and attachment.Pos or parent:GetPos())
    trail:SetParent(parent)
    trail:Spawn()
    trail:Activate()

    if ( attachment ) then
        trail:Fire("SetParentAttachment", attachmentName)
    end

    if ( lifetime ) then
        SafeRemoveEntityDelayed(trail, lifetime)
    end

    parent:DeleteOnRemove(trail)

    return trail
end

--- Holds a wreck piece to the body until one of them lands, and makes it report its landing to the body.
---@param body Entity Body piece.
---@param piece Entity|nil Piece to hold, ignored when it could not be created.
local function WeldToBody(body, piece)
    if ( !IsValid(piece) ) then return end

    piece:SetMaster(body)
    constraint.Weld(body, piece, 0, 0, 0, true, false)
end

--- Prepares the state of the damage effects.
function ENT:InitDamageEffects()
    self.smokeTrails = {}
    self.damageNextThink = 0
    self.nextCorpseTime = 0
end

--- Takes a fixed share of the helicopter's health from a bomb thrown back with the gravity gun, and reacts to whatever damage gets through.
---@param dmginfo CTakeDamageInfo Damage being dealt.
function ENT:OnTakeDamage(dmginfo)
    local inflictor = dmginfo:GetInflictor()

    if ( IsValid(inflictor) and inflictor:GetClass() == BOMB_CLASS ) then
        local owner = inflictor:GetOwner()

        if ( IsValid(owner) and owner:IsPlayer() ) then
            dmginfo:SetDamage(math.ceil(self:GetMaxHP() / self.ThrownBombKillCount))
        end
    end

    local previousHealth = self:GetHP()

    BaseClass.OnTakeDamage(self, dmginfo)

    self:ReactToDamage(previousHealth, dmginfo)
end

--- Knocks the helicopter away from a blast and off its level towards the side that was hit.
---@param force Vector Force of the blast.
function ENT:ReactToBlast(force)
    local direction = force:GetNormalized()
    if ( direction:IsZero() ) then return end

    local phys = self:GetPhysicsObject()

    if ( IsValid(phys) ) then
        phys:AddVelocity(direction * BLAST_PUSH_SPEED)
    end

    local side = direction:Dot(self:GetRight()) <= 0 and -1 or 1
    self.flightRollDamage = math.Rand(BLAST_ROLL_MIN, BLAST_ROLL_MAX) * side
end

--- Plays the effects that belong to the health the helicopter has just lost.
---@param previousHealth number Health before the damage.
---@param dmginfo CTakeDamageInfo Damage that was dealt.
function ENT:ReactToDamage(previousHealth, dmginfo)
    if ( dmginfo:IsDamageType(DMG_BLAST) and dmginfo:GetDamage() > 0 ) then
        self:ReactToBlast(dmginfo:GetDamageForce())
    end

    local health = self:GetHP()
    if ( health >= previousHealth or self:IsDestroyed() ) then return end

    local maxHealth = self:GetMaxHP()

    if ( math.ceil(previousHealth / maxHealth * MAX_DAMAGE_ALERTS) != math.ceil(math.max(health, 0) / maxHealth * MAX_DAMAGE_ALERTS) ) then
        self:EmitSound("NPC_AttackHelicopter.BadlyDamagedAlert")
    end

    if ( previousHealth != maxHealth and GetHealthRange(previousHealth, maxHealth, MAX_CORPSES) != GetHealthRange(health, maxHealth, MAX_CORPSES) ) then
        self:DropCorpse(dmginfo:GetDamage())
    end

    if ( GetHealthRange(previousHealth, maxHealth, MAX_EXPLOSIONS) != GetHealthRange(health, maxHealth, MAX_EXPLOSIONS) ) then
        local position = dmginfo:GetDamagePosition()

        if ( position:IsZero() ) then
            position = self:WorldSpaceCenter()
        end

        self:ExplodeAndThrowChunk(position)
    end
end

--- Adds or removes trails so that their number matches the health lost, alternating between fire and dark smoke along the hull.
function ENT:UpdateSmokeTrails()
    local trails = self.smokeTrails
    local health = self:GetHP()
    local maxHealth = self:GetMaxHP()
    local desired = 0

    if ( health < maxHealth ) then
        desired = MAX_SMOKE_TRAILS - GetHealthRange(health, maxHealth, MAX_SMOKE_TRAILS)
    end

    while ( #trails > desired ) do
        SafeRemoveEntity(table.remove(trails))
    end

    while ( #trails < desired ) do
        local index = #trails
        local attachmentName = "Damage" .. index
        local trail

        if ( index == 0 or index % 2 == 1 ) then
            trail = CreateTrail("env_fire_trail", self, attachmentName)
        else
            trail = CreateTrail("env_smoketrail", self, attachmentName, DAMAGE_SMOKE)
        end

        if ( !trail ) then break end

        trails[#trails + 1] = trail
    end
end

--- Throws a burning chunk out of the helicopter.
---@param pos Vector Position the chunk starts at.
---@param model string Model of the chunk.
---@param bSmall boolean Whether the chunk is only an invisible carrier for a short fire trail.
---@return Entity|nil chunk
function ENT:CreateChunk(pos, model, bSmall)
    local chunk = ents.Create("prop_physics")
    if ( !IsValid(chunk) ) then return nil end

    local lifetime = bSmall and math.Rand(0.5, 1) or CHUNK_LIFETIME

    chunk:SetModel(model)
    chunk:SetPos(pos)
    chunk:SetAngles(AngleRand())
    chunk:Spawn()
    chunk:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

    if ( bSmall ) then
        chunk:SetRenderMode(RENDERMODE_TRANSCOLOR)
        chunk:SetColor(Color(255, 255, 255, 0))
        chunk:DrawShadow(false)
        chunk:SetNotSolid(true)
    end

    local phys = chunk:GetPhysicsObject()

    if ( IsValid(phys) ) then
        local direction = Angle(math.Rand(-70, 20), math.Rand(0, 360), 0):Forward()

        phys:SetVelocity(direction * math.Rand(550, 800) + self:GetVelocity())
        phys:AddAngleVelocity(VectorRand(-180, 180))
    end

    CreateTrail("env_fire_trail", chunk, nil, nil, lifetime)
    SafeRemoveEntityDelayed(chunk, lifetime)

    return chunk
end

--- Sets off an explosion on the hull that shakes the screen and throws either two short fire trails or, less often, a burning chunk.
---@param pos Vector Position of the explosion.
function ENT:ExplodeAndThrowChunk(pos)
    local effectData = EffectData()
    effectData:SetOrigin(pos)
    util.Effect("HelicopterMegaBomb", effectData)

    self:EmitSound("BaseExplosionEffect.Sound")
    util.ScreenShake(pos, 25, 150, 1, 750)

    if ( math.random(0, 4) == 0 ) then
        self:CreateChunk(pos, CHUNK_MODELS[1], false)

        return
    end

    for _ = 1, 2 do
        self:CreateChunk(pos, SMALL_CHUNK_MODELS[math.random(#SMALL_CHUNK_MODELS)], true)
    end
end

--- Throws the gunner out of the helicopter as a ragdoll.
---@param damage number Damage that knocked the gunner out, which decides how hard the body is thrown.
function ENT:DropCorpse(damage)
    local now = CurTime()
    if ( self.nextCorpseTime > now ) then return end

    self.nextCorpseTime = now + CORPSE_INTERVAL

    local corpse = ents.Create("prop_ragdoll")
    if ( !IsValid(corpse) ) then return end

    corpse:SetModel(self.CorpseModel)
    corpse:SetPos(self:GetPos())
    corpse:SetAngles(self:GetAngles())
    corpse:Spawn()
    corpse:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

    local force = VectorRand(-1, 1)
    force.z = 0.5
    force:Mul(math.min(damage, CORPSE_MAX_DAMAGE) * CORPSE_FORCE_PER_DAMAGE)

    local count = corpse:GetPhysicsObjectCount()

    for index = 0, count - 1 do
        local phys = corpse:GetPhysicsObjectNum(index)

        if ( IsValid(phys) ) then
            phys:SetVelocity(self:GetVelocity())
            phys:ApplyForceCenter(force / count)
        end
    end

    SafeRemoveEntityDelayed(corpse, CORPSE_LIFETIME)
end

--- Runs the damage effects: keeps the trails in step with the health and shakes a falling helicopter with explosions.
function ENT:DamageEffectsThink()
    if ( !self.smokeTrails ) then return end

    local now = CurTime()
    if ( now < self.damageNextThink ) then return end

    self.damageNextThink = now + DAMAGE_THINK_INTERVAL
    self:UpdateSmokeTrails()

    if ( !self:IsDestroyed() or math.random(1, DYING_EXPLOSION_CHANCE) != 1 ) then return end

    local mins, maxs = self:OBBMins(), self:OBBMaxs()
    local point = Vector(
        Lerp(math.Rand(0.25, 0.75), mins.x, maxs.x),
        Lerp(math.Rand(0.25, 0.75), mins.y, maxs.y),
        Lerp(math.Rand(0.25, 0.75), mins.z, maxs.z)
    )

    self:ExplodeAndThrowChunk(self:LocalToWorld(point))
end

--- Silences the weapons and starts the failing engine sound of a helicopter that has been shot down and is falling.
function ENT:OnDestroyed()
    self:GunShutdown()
    self:StopRotorWash()

    self.engineFailureSound = CreateSound(self, "NPC_AttackHelicopter.EngineFailure")
    self.engineFailureSound:Play()
end

--- Creates one of the three large wreck pieces with its smoke and fire.
---@param pos Vector Position of the piece.
---@param angles Angle Angles of the piece.
---@param velocity Vector Velocity the piece starts with.
---@param model string Model of the piece.
---@return Entity|nil chunk
function ENT:CreateDeathChunk(pos, angles, velocity, model)
    local chunk = ents.Create(DEATH_CHUNK_CLASS)
    if ( !IsValid(chunk) ) then return nil end

    chunk:SetModel(model)
    chunk:SetPos(pos)
    chunk:SetAngles(angles)
    chunk:Spawn()
    chunk:Activate()

    local phys = chunk:GetPhysicsObject()

    if ( IsValid(phys) ) then
        phys:SetVelocity(velocity)
    end

    local attachmentName = chunk:LookupAttachment("damage") > 0 and "damage" or nil

    CreateTrail("env_smoketrail", chunk, attachmentName, DEATH_CHUNK_SMOKE)
    CreateTrail("env_fire_trail", chunk, attachmentName, nil, DEATH_CHUNK_FIRE_LIFETIME)

    return chunk
end

--- Breaks the helicopter into its body, cockpit and tail, held together until the first of them hits the ground, each with a burning chunk flying off.
function ENT:OnFinishExplosion()
    local pos = self:GetPos()
    local angles = self:GetAngles()
    local velocity = self:GetVelocity()
    local cockpitPos = pos + self:GetForward() * 100 - self:GetUp() * 38
    local tailPos = pos - self:GetForward() * 175

    local body = self:CreateDeathChunk(pos, angles, velocity, DEATH_CHUNK_BODY)
    local cockpit = self:CreateDeathChunk(cockpitPos, angles, velocity, DEATH_CHUNK_COCKPIT)
    local tail = self:CreateDeathChunk(tailPos, angles, velocity, DEATH_CHUNK_TAIL)

    for _, chunkPos in ipairs({pos, cockpitPos, tailPos}) do
        self:CreateChunk(chunkPos, CHUNK_MODELS[math.random(#CHUNK_MODELS)], false)
    end

    if ( !body ) then return end

    body:EmitSound("NPC_CombineGunship.Explode")
    WeldToBody(body, cockpit)
    WeldToBody(body, tail)
end

--- Stops the looping sounds that belong to the helicopter.
function ENT:StopLoopingSounds()
    for _, key in ipairs({"gunFireSound", "washBlastSound", "engineFailureSound"}) do
        local patch = self[key]

        if ( patch ) then
            patch:Stop()
        end
    end
end
