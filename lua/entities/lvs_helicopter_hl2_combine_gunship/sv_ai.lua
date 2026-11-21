--- Autopilot of the gunship. The original flies along path tracks laid out by the map; without them the autopilot circles its enemy at cannon range, facing it the whole time, and leaves the firing to the cannon, which picks its own moments like the original. Every few bursts it hangs still above an enemy on the ground and blasts it with the belly cannon, and it shoots down missiles that come at it.

DEFINE_BASECLASS("lvs_base_helicopter")

--- Horizontal distance the autopilot keeps from its enemy, between the closest the cannon fires at and GUNSHIP_MAX_GUN_DIST.
local AI_STANDOFF = 1500

--- Height above an enemy on the ground the autopilot keeps.
local AI_HEIGHT = 700

--- Degrees along its circle the autopilot aims ahead of itself, which is what keeps it circling.
local AI_ORBIT_LEAD = 30

--- Shortest and longest seconds before the autopilot may reverse the direction it circles in.
local AI_ORBIT_FLIP_MIN = 8
local AI_ORBIT_FLIP_MAX = 16

--- Seconds the autopilot waits before it may reverse its circling again because of an obstacle.
local AI_BLOCKED_FLIP_INTERVAL = 2

--- Bursts of the cannon after which the autopilot blasts an enemy on the ground with the belly cannon.
local AI_BURSTS_PER_BELLY_BLAST = 3

--- Longest seconds the autopilot tries to get above its enemy for the belly cannon before it gives up.
local AI_BELLY_RUN_TIME = 15

--- Farthest a missile may be for the autopilot to notice it.
local AI_MISSILE_RANGE = 4096

--- Seconds between two looks for missiles.
local AI_MISSILE_SEARCH_INTERVAL = 0.2

--- Prepares the autopilot state.
function ENT:InitAI()
    self.aiOrbitDirection = 1
    self.aiNextOrbitFlip = 0
    self.aiNextBlockedFlip = 0
    self.aiBurstsSinceBlast = 0
    self.aiBellyRunEnd = 0
    self.aiNextMissileSearch = 0
    self.bAIWasFiring = false
    self.aiMissile = nil
end

--- Returns what the autopilot turns to face: the missile or enemy its cannon is after, from CNPC_CombineGunship::UpdateFacingDirection.
---@return Entity|nil target
function ENT:GetAIFaceTarget()
    return self:GetCannonEnemy()
end

--- Returns whether a missile is a threat: fired by an enemy, in sight and flying towards the gunship.
---@param missile Entity
---@return boolean bThreat
function ENT:IsAIMissileThreat(missile)
    if ( !IsValid(missile) ) then return false end

    local owner = missile:GetOwner()
    if ( IsValid(owner) and ( owner == self or !self:IsEnemy(owner) ) ) then return false end

    local toGunship = self:WorldSpaceCenter() - missile:GetPos()
    if ( toGunship:LengthSqr() > AI_MISSILE_RANGE * AI_MISSILE_RANGE ) then return false end
    if ( missile:GetVelocity():Dot(toGunship) <= 0 ) then return false end

    return self:AICanSee(missile)
end

--- Looks for the nearest missile coming at the gunship, which the cannon then shoots at instead of the enemy, as the original hates every rpg_missile above all else.
function ENT:UpdateAIMissile()
    local now = CurTime()
    if ( now < self.aiNextMissileSearch ) then return end

    self.aiNextMissileSearch = now + AI_MISSILE_SEARCH_INTERVAL

    if ( self.bCannonFiring and self:IsAIMissileThreat(self.aiMissile) ) then return end

    local pos = self:WorldSpaceCenter()
    local nearest, nearestDistance

    for class in pairs(self.MissileClasses) do
        for _, missile in ipairs(ents.FindByClass(class)) do
            if ( !self:IsAIMissileThreat(missile) ) then continue end

            local distance = pos:DistToSqr(missile:GetPos())

            if ( !nearest or distance < nearestDistance ) then
                nearest = missile
                nearestDistance = distance
            end
        end
    end

    self.aiMissile = nearest
end

--- Counts the bursts the cannon has finished since the last belly blast.
function ENT:CountAIBursts()
    if ( self.bAIWasFiring and !self.bCannonFiring ) then
        self.aiBurstsSinceBlast = self.aiBurstsSinceBlast + 1
    end

    self.bAIWasFiring = self.bCannonFiring
end

--- Returns where the autopilot flies to blast its enemy with the belly cannon, or nil when it should not or no longer try.
---@param target Entity Enemy.
---@param targetPos Vector Centre of the enemy.
---@return Vector|nil goal
function ENT:RunAIBellyBlast(target, targetPos)
    local now = CurTime()

    if ( self:GetGroundAttacking() ) then return self:GetGroundAttackPosition() or self:GetPos() end

    if ( IsValid(self.groundAttackTarget) ) then
        if ( self.groundAttackTarget == target and now < self.aiBellyRunEnd and self:IsAITargetOnGround(targetPos) ) then return self:GetGroundAttackPosition() end

        self:SetGroundAttackTarget(nil)

        return nil
    end

    if ( self.aiBurstsSinceBlast < AI_BURSTS_PER_BELLY_BLAST or self.bCannonFiring or !self:CanGroundAttack() ) then return nil end
    if ( !self:IsAITargetOnGround(targetPos) ) then return nil end

    self.aiBurstsSinceBlast = 0
    self.aiBellyRunEnd = now + AI_BELLY_RUN_TIME
    self:SetGroundAttackTarget(target)

    return self:GetGroundAttackPosition()
end

--- Returns the point on the circle around the enemy the autopilot flies to, turning around now and then, or when something blocks the way. It meets an enemy in the air at that enemy's own height.
---@param targetPos Vector Centre of the enemy.
---@return Vector goal
function ENT:RunAIOrbit(targetPos)
    local now = CurTime()
    local bearing = self:GetPos() - targetPos
    bearing.z = 0

    if ( now > self.aiNextOrbitFlip ) then
        self.aiNextOrbitFlip = now + math.Rand(AI_ORBIT_FLIP_MIN, AI_ORBIT_FLIP_MAX)
        self.aiOrbitDirection = math.random(0, 1) == 0 and -1 or 1
    end

    if ( self.bAIPathBlocked and now > self.aiNextBlockedFlip ) then
        self.aiNextBlockedFlip = now + AI_BLOCKED_FLIP_INTERVAL
        self.aiOrbitDirection = -self.aiOrbitDirection
    end

    local yaw = bearing:Angle().y + AI_ORBIT_LEAD * self.aiOrbitDirection
    local height = AI_HEIGHT

    if ( !self:IsAITargetOnGround(targetPos) ) then
        height = -(self:WorldSpaceCenter().z - self:GetPos().z)
    end

    return targetPos + Angle(0, yaw, 0):Forward() * AI_STANDOFF + Vector(0, 0, height)
end

--- Patrols without an enemy like any LVS helicopter, kept to patrol height, still shooting at missiles that come at it.
function ENT:RunAIPatrol()
    if ( IsValid(self.groundAttackTarget) and !self:GetGroundAttacking() ) then
        self:SetGroundAttackTarget(nil)
    end

    self.bAIFaceTravel = false

    BaseClass.RunAI(self)
    self:LimitAIPatrolAltitude()

    self:SetAIWeapon(self.WEAPON_CANNON)
    self._AIFireInput = IsValid(self.aiMissile)

    if ( IsValid(self.aiMissile) ) then
        self:SetAIAimVector((self.aiMissile:GetPos() - self:GetPos()):GetNormalized())
    end
end

--- Runs the autopilot: patrols without an enemy, or circles it and lets the cannons work.
function ENT:RunAI()
    if ( !self.aiOrbitDirection ) then return BaseClass.RunAI(self) end

    self:UpdateAIAvoidance()
    self:UpdateAIMissile()
    self:CountAIBursts()

    local target = self:AIGetTarget()

    if ( !IsValid(target) ) then
        self:RunAIPatrol()

        return
    end

    local targetPos = target:WorldSpaceCenter()
    local goal = self:RunAIBellyBlast(target, targetPos) or self:RunAIOrbit(targetPos)

    self.bAIFaceTravel = false
    self._lvsTargetPos = self:ClearAIGoal(goal)
    self._AIFireInput = true
    self:SetAIWeapon(self.WEAPON_CANNON)

    local aimPos = self:GetCannonTarget() or targetPos

    self:SetAIAimVector((aimPos - self:GetPos()):GetNormalized())
end
