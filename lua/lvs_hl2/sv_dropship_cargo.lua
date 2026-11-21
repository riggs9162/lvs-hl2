--- Lets an entity be carried by the Combine dropship the way the original carries its cargo, from CNPC_CombineDropship::Spawn and the swooping landing state: a strong physics shadow holds the cargo to its place under the dropship, so that the dropship flies as if the cargo weighed nothing, while the cargo itself still bumps into the world. An entity that includes this file has to call SimulateHL2DropshipCarry from its own PhysicsSimulate.

--- Seconds in which the shadow brings the cargo to its place.
local SHADOW_SECONDS_TO_ARRIVE = 0.05

--- Highest speed and turn rate of the shadow, high enough that it always keeps up, as the original's SetShadow( 1e4, 1e4 ).
local SHADOW_MAX_SPEED = 100000
local SHADOW_MAX_ANGULAR = 100000

--- Share of the cargo's own movement the shadow takes out on every step.
local SHADOW_DAMP_FACTOR = 0.8

--- Distance from its place beyond which the cargo is moved there at once.
local SHADOW_TELEPORT_DISTANCE = 500

--- Marks the entity as cargo the dropship holds with a physics shadow instead of welding it on.
ENT.bHL2DropshipShadowCargo = true

--- Starts or stops holding the entity under a dropship.
---@param carrier Entity|nil Dropship, or nil to let go.
---@param localPos Vector|nil Place of the entity relative to the dropship.
---@param localAngles Angle|nil Angles of the entity relative to the dropship.
function ENT:SetHL2DropshipCarry(carrier, localPos, localAngles)
    if ( !IsValid(carrier) ) then
        self.hl2DropshipCarry = nil

        return
    end

    self.hl2DropshipCarry = {
        carrier = carrier,
        pos = localPos,
        angles = localAngles,
        params = {},
    }
end

--- Returns whether a dropship holds the entity.
---@return boolean bCarried
function ENT:IsHL2DropshipCarried()
    local carry = self.hl2DropshipCarry

    return carry != nil and IsValid(carry.carrier)
end

--- Holds the entity to its place under the dropship for one physics step.
---@param phys PhysObj Physics object of the entity.
---@param deltatime number Length of the physics step in seconds.
---@return Vector|nil angularAccel Nil while no dropship holds the entity.
---@return Vector|nil linearAccel
---@return number|nil simulate
function ENT:SimulateHL2DropshipCarry(phys, deltatime)
    local carry = self.hl2DropshipCarry
    if ( !carry ) then return nil end

    local carrier = carry.carrier

    if ( !IsValid(carrier) ) then
        self.hl2DropshipCarry = nil

        return nil
    end

    phys:Wake()

    local params = carry.params
    params.secondstoarrive = SHADOW_SECONDS_TO_ARRIVE
    params.pos = carrier:LocalToWorld(carry.pos) + carrier:GetVelocity() * (SHADOW_SECONDS_TO_ARRIVE + deltatime)
    params.angle = carrier:LocalToWorldAngles(carry.angles)
    params.maxspeed = SHADOW_MAX_SPEED
    params.maxangular = SHADOW_MAX_ANGULAR
    params.maxspeeddamp = SHADOW_MAX_SPEED
    params.maxangulardamp = SHADOW_MAX_ANGULAR
    params.dampfactor = SHADOW_DAMP_FACTOR
    params.teleportdistance = SHADOW_TELEPORT_DISTANCE
    params.deltatime = deltatime

    return phys:ComputeShadowControl(params)
end
