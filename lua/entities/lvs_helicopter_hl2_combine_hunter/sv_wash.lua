--- Rotor wash of the hunter-chopper that blows light physics objects away from underneath it, ported from DoRotorPhysicsPush and DoWashPush of the Half-Life 2 base helicopter (cbasehelicopter.cpp).

--- Seconds between two wash thinks.
local WASH_THINK_INTERVAL = 0.1

--- Height below the helicopter within which its wash reaches the ground.
local WASH_ALTITUDE = 1024

--- Height above the ground at which the wash is centred.
local WASH_ORIGIN_RAISE = 64

--- Radius around the wash centre in which objects are pushed.
local WASH_RADIUS = 256

--- Farthest above or below the wash centre an object can be to get picked up, which keeps the wash from reaching through roofs.
local WASH_MAX_HEIGHT_DIFFERENCE = 96

--- Push strength on an object that has just entered the wash.
local WASH_PUSH_MIN = 30

--- Push strength on an object after the ramp time.
local WASH_PUSH_MAX = 40

--- Seconds the push takes to grow from its weakest to its strongest.
local WASH_RAMP_TIME = 1

--- Heaviest object the wash tries to move.
local WASH_MAX_MASS = 300

--- Mass above which the push stops growing, so heavy objects get blown less than light ones.
local WASH_MASS_CLAMP = 30

--- Most objects pushed at the same time.
local WASH_MAX_OBJECTS = 6

--- Seconds between two searches for new objects to push.
local WASH_SEARCH_INTERVAL = 0.5

--- Seconds after which a pushed object is let go to give lighter ones nearby a chance.
local WASH_MAX_PUSH_TIME = 2

--- Factor that turns the push strength into the impulse of one think, the original 0.015 / 0.1.
local WASH_FORCE_SCALE = 0.15

--- Throttle above which the rotor is fast enough to produce wash.
local WASH_MIN_THROTTLE = 0.5

--- Seconds the wash blast sound takes to fade in or out.
local WASH_SOUND_FADE_TIME = 1

--- Prepares the wash state and its blast sound.
function ENT:InitRotorWash()
    self.washEntities = {}
    self.washNextThink = 0
    self.washNextSearch = 0
    self.washBlastSound = CreateSound(self, "NPC_AttackHelicopter.RotorBlast")
end

--- Returns whether the wash may push an entity at all.
---@param entity Entity Entity to check.
---@return boolean bPushable
function ENT:CanWashPush(entity)
    if ( entity == self or entity:GetParent() == self ) then return false end
    if ( entity:IsPlayer() or entity:IsEFlagSet(EFL_NO_ROTORWASH_PUSH) ) then return false end
    if ( entity:GetMoveType() != MOVETYPE_VPHYSICS ) then return false end

    local phys = entity:GetPhysicsObject()

    return IsValid(phys) and phys:GetMass() <= WASH_MAX_MASS
end

--- Pushes one object away from the wash centre.
---@param wash table Entry of the pushed object with its entity and the time it entered the wash.
---@param washOrigin Vector Centre of the wash.
---@return boolean bKeep Whether the object stays in the wash for the next think.
function ENT:DoWashPush(wash, washOrigin)
    local entity = wash.entity
    if ( !IsValid(entity) or entity:IsEFlagSet(EFL_NO_ROTORWASH_PUSH) ) then return false end

    local phys = entity:GetPhysicsObject()
    if ( !IsValid(phys) ) then return false end

    local toSpot = entity:WorldSpaceCenter() - washOrigin
    toSpot.z = 0

    local distance = toSpot:Length()
    if ( distance > WASH_RADIUS ) then return false end

    toSpot:Normalize()

    local pushTime = CurTime() - wash.startTime
    local washAmount = math.Remap(math.Clamp(pushTime, 0, WASH_RAMP_TIME), 0, WASH_RAMP_TIME, WASH_PUSH_MIN, WASH_PUSH_MAX)
    local mass = math.min(phys:GetMass(), WASH_MASS_CLAMP)

    phys:Wake()
    phys:ApplyForceOffset(toSpot * (WASH_FORCE_SCALE * washAmount * mass), washOrigin)

    return pushTime <= WASH_MAX_PUSH_TIME
end

--- Adds objects near the wash centre to the pushed ones, each lighter than the one found before it, until all slots are taken.
---@param washOrigin Vector Centre of the wash.
function ENT:FindWashEntities(washOrigin)
    local washEntities = self.washEntities
    local pushed = {}

    for _, wash in ipairs(washEntities) do
        pushed[wash.entity] = true
    end

    local lightestMass = math.huge

    for _, entity in ipairs(ents.FindInSphere(washOrigin, WASH_RADIUS)) do
        if ( #washEntities >= WASH_MAX_OBJECTS ) then break end
        if ( pushed[entity] or !self:CanWashPush(entity) ) then continue end

        local mass = entity:GetPhysicsObject():GetMass()
        if ( mass > lightestMass ) then continue end

        local toSpot = entity:WorldSpaceCenter() - washOrigin
        if ( math.abs(toSpot.z) > WASH_MAX_HEIGHT_DIFFERENCE ) then continue end
        if ( toSpot:Length2D() > WASH_RADIUS ) then continue end

        lightestMass = mass
        washEntities[#washEntities + 1] = {
            entity = entity,
            startTime = CurTime(),
        }
    end
end

--- Lets go of everything in the wash and fades the blast sound out.
function ENT:StopRotorWash()
    if ( !self.washEntities ) then return end

    if ( #self.washEntities > 0 ) then
        self.washEntities = {}
        self.washBlastSound:ChangeVolume(0, WASH_SOUND_FADE_TIME)
    end
end

--- Runs the wash: pushes the objects already caught in it, looks for new ones, and fades the blast sound with them.
function ENT:RotorWashThink()
    if ( !self.washEntities ) then return end

    local now = CurTime()
    if ( now < self.washNextThink ) then return end

    self.washNextThink = now + WASH_THINK_INTERVAL

    if ( self:IsDestroyed() or self:GetThrottle() < WASH_MIN_THROTTLE ) then
        self:StopRotorWash()

        return
    end

    local origin = self:GetPos()
    local trace = util.TraceLine({
        start = origin,
        endpos = origin - Vector(0, 0, WASH_ALTITUDE),
        mask = bit.bor(MASK_SOLID_BRUSHONLY, CONTENTS_WATER),
    })

    local washOrigin = trace.HitPos + Vector(0, 0, WASH_ORIGIN_RAISE)
    local washEntities = self.washEntities
    local bWasPushing = #washEntities > 0

    for index = #washEntities, 1, -1 do
        if ( !self:DoWashPush(washEntities[index], washOrigin) ) then
            table.remove(washEntities, index)
        end
    end

    if ( now >= self.washNextSearch ) then
        self.washNextSearch = now + WASH_SEARCH_INTERVAL
        self:FindWashEntities(washOrigin)
    end

    local bPushing = #washEntities > 0
    if ( bPushing == bWasPushing ) then return end

    if ( bPushing ) then
        if ( !self.washBlastSound:IsPlaying() ) then
            self.washBlastSound:PlayEx(0, 100)
        end

        self.washBlastSound:ChangeVolume(1, WASH_SOUND_FADE_TIME)
    else
        self.washBlastSound:ChangeVolume(0, WASH_SOUND_FADE_TIME)
    end
end
