--- Autopilot of the hunter-chopper. It follows the attack pattern of the Half-Life 2 attack helicopter without needing its path tracks: it circles its enemy while the gun fires, flies bombing passes over it while the gun rests, and answers heavy damage with a carpet bombing run.

DEFINE_BASECLASS("lvs_base_helicopter")

--- The autopilot circles its enemy at a distance and uses the gun.
local AI_MODE_GUN = 0

--- The autopilot flies over its enemy and drops single bombs.
local AI_MODE_BOMB = 1

--- The autopilot rushes over its enemy and carpet bombs it.
local AI_MODE_CARPET = 2

--- Horizontal distance the autopilot keeps from its enemy while using the gun, well inside the gun's range.
local AI_GUN_STANDOFF = 1400

--- Height above its enemy the autopilot keeps while using the gun, the original g_helicopter_bullrush_shoot_height.
local AI_GUN_HEIGHT = 650

--- Degrees along its circle the autopilot aims ahead of itself, which is what keeps it circling.
local AI_ORBIT_LEAD = 30

--- Shortest seconds before the autopilot may reverse the direction it circles in.
local AI_ORBIT_FLIP_MIN = 8

--- Longest seconds before the autopilot may reverse the direction it circles in.
local AI_ORBIT_FLIP_MAX = 16

--- Height above its enemy the autopilot flies its bombing passes at.
local AI_BOMB_HEIGHT = 500

--- Farthest a bomb may be predicted to land from its enemy for the autopilot to release it.
local AI_BOMB_RELEASE_RADIUS = 350

--- Bombs the autopilot drops on one pass before it goes back to the gun.
local AI_BOMBS_PER_PASS = 3

--- Longest seconds a bombing pass may take.
local AI_BOMB_PASS_TIME = 10

--- Seconds the autopilot waits after a bombing pass before it starts another.
local AI_BOMB_PASS_INTERVAL = 6

--- Farthest a carpet bomb may be predicted to land from its enemy for the autopilot to release it.
local AI_CARPET_RELEASE_RADIUS = 1000

--- Distance beyond its enemy the autopilot flies to on a carpet bombing run.
local AI_CARPET_OVERSHOOT = 1500

--- Longest seconds a carpet bombing run may take.
local AI_CARPET_RUN_TIME = 8

--- Share of its health the helicopter must lose for every carpet bombing run, the original g_helicopter_bullrush_mega_bomb_health.
local AI_CARPET_HEALTH_STEP = 0.25

--- Longest seconds ahead the autopilot predicts its enemy's movement.
local AI_MAX_LEAD_TIME = 4

--- Slowest speed assumed when estimating how long the helicopter takes to reach its enemy.
local AI_MIN_APPROACH_SPEED = 300

--- Lowest the autopilot's goal may be above the ground.
local AI_MIN_ALTITUDE = 350

--- Height the autopilot adds above an obstacle between it and its goal.
local AI_OBSTACLE_CLEARANCE = 600

--- Gravity the carpet bombs fall under.
local AI_CARPET_BOMB_GRAVITY = 400

--- Prepares the autopilot state.
function ENT:InitAI()
    self.aiMode = AI_MODE_GUN
    self.aiModeEndTime = 0
    self.aiNextBombPass = 0
    self.aiStickMark = 0
    self.aiOrbitDirection = 1
    self.aiNextOrbitFlip = 0
    self.aiRunDirection = Vector(1, 0, 0)
    self.aiNextCarpetHealth = 1 - AI_CARPET_HEALTH_STEP
    self.bAIFaceTravel = false
end

--- Selects a weapon slot for the autopilot unless it is selected already.
---@param id number Weapon slot.
function ENT:SetAIWeapon(id)
    if ( self:GetSelectedWeapon() == id ) then return end

    self:SelectWeapon(id)
end

--- Returns whether an enemy is on the ground below the helicopter, where bombs can reach it.
---@param targetPos Vector Centre of the enemy.
---@return boolean bOnGround
function ENT:IsAITargetOnGround(targetPos)
    if ( targetPos.z > self:GetPos().z - 150 ) then return false end

    local trace = util.TraceLine({
        start = targetPos,
        endpos = targetPos - Vector(0, 0, 400),
        mask = MASK_SOLID_BRUSHONLY,
    })

    return trace.Hit
end

--- Returns how far from a point a bomb let go right now would land, by the time it has fallen to that point's height.
---@param targetPos Vector Centre of the enemy.
---@param targetVelocity Vector Velocity of the enemy.
---@param gravity number Gravity the bomb falls under.
---@return number distance Horizontal distance between the impact and the enemy at the time of the impact.
function ENT:GetAIBombMissDistance(targetPos, targetVelocity, gravity)
    local pos = self:GetPos()
    local velocity = self:GetVelocity()
    local fallTime = math.sqrt(2 * math.max(pos.z - targetPos.z, 0) / gravity)
    local impact = pos + velocity * fallTime
    local targetThen = targetPos + targetVelocity * fallTime

    return (impact - targetThen):Length2D()
end

--- Number of bombs dropped since the current bombing pass began.
---@return number count
function ENT:GetAIBombsDropped()
    return self.bombsDropped - self.aiStickMark
end

--- Picks what the autopilot does next: it stays on the gun until a burst is over, then flies a bombing pass, or a carpet bombing run if it has lost enough health, and returns to the gun when the pass is done.
---@param targetPos Vector Centre of the enemy.
function ENT:UpdateAIMode(targetPos)
    local now = CurTime()
    local bOnGround = self:IsAITargetOnGround(targetPos)

    if ( self.aiMode != AI_MODE_GUN ) then
        local bDone = now > self.aiModeEndTime or !bOnGround

        if ( self.aiMode == AI_MODE_BOMB and self:GetAIBombsDropped() >= AI_BOMBS_PER_PASS ) then
            bDone = true
        end

        if ( self.aiMode == AI_MODE_CARPET and (self:GetPos() - targetPos):Dot(self.aiRunDirection) > AI_CARPET_OVERSHOOT * 0.75 ) then
            bDone = true
        end

        if ( bDone ) then
            self.aiMode = AI_MODE_GUN
            self.aiNextBombPass = now + AI_BOMB_PASS_INTERVAL
        end

        return
    end

    if ( !bOnGround or !self:IsGunResting() ) then return end

    if ( self:GetHP() <= self:GetMaxHP() * self.aiNextCarpetHealth ) then
        local direction = targetPos - self:GetPos()
        direction.z = 0
        direction:Normalize()

        self.aiNextCarpetHealth = self.aiNextCarpetHealth - AI_CARPET_HEALTH_STEP
        self.aiRunDirection = direction
        self.aiMode = AI_MODE_CARPET
        self.aiModeEndTime = now + AI_CARPET_RUN_TIME

        return
    end

    if ( now < self.aiNextBombPass ) then return end

    self.aiMode = AI_MODE_BOMB
    self.aiModeEndTime = now + AI_BOMB_PASS_TIME
    self.aiStickMark = self.bombsDropped
end

--- Circles the enemy at gun range and holds still on that circle while the gun charges and fires.
---@param target Entity Enemy.
---@param targetPos Vector Centre of the enemy.
---@return Vector goal Position to fly to.
function ENT:RunAIGun(target, targetPos)
    local now = CurTime()
    local bearing = self:GetPos() - targetPos
    bearing.z = 0

    local yaw = bearing:Angle().y

    if ( now > self.aiNextOrbitFlip ) then
        self.aiNextOrbitFlip = now + math.Rand(AI_ORBIT_FLIP_MIN, AI_ORBIT_FLIP_MAX)
        self.aiOrbitDirection = math.random(0, 1) == 0 and -1 or 1
    end

    if ( self:IsGunResting() or self:IsGunReady() ) then
        yaw = yaw + AI_ORBIT_LEAD * self.aiOrbitDirection
    end

    self:SetAIWeapon(self.WEAPON_GUN)
    self._AIFireInput = self:AICanSee(target)
    self.bAIFaceTravel = false

    return targetPos + Angle(0, yaw, 0):Forward() * AI_GUN_STANDOFF + Vector(0, 0, AI_GUN_HEIGHT)
end

--- Flies over where the enemy is going to be and lets a bomb go whenever it would land close enough.
---@param target Entity Enemy.
---@param targetPos Vector Centre of the enemy.
---@return Vector goal Position to fly to.
function ENT:RunAIBombing(target, targetPos)
    local targetVelocity = target:GetVelocity()
    local distance = (targetPos - self:GetPos()):Length2D()
    local leadTime = math.Clamp(distance / math.max(self:GetVelocity():Length2D(), AI_MIN_APPROACH_SPEED), 0, AI_MAX_LEAD_TIME)

    self:SetAIWeapon(self.WEAPON_BOMBS)
    self._AIFireInput = self:GetAIBombMissDistance(targetPos, targetVelocity, physenv.GetGravity():Length()) < AI_BOMB_RELEASE_RADIUS
    self.bAIFaceTravel = distance > AI_BOMB_RELEASE_RADIUS

    return targetPos + targetVelocity * leadTime + Vector(0, 0, AI_BOMB_HEIGHT)
end

--- Rushes in a straight line over the enemy and beyond, carpet bombing everything around it on the way.
---@param target Entity Enemy.
---@param targetPos Vector Centre of the enemy.
---@return Vector goal Position to fly to.
function ENT:RunAICarpetBombing(target, targetPos)
    self:SetAIWeapon(self.WEAPON_CARPET_BOMBS)
    self._AIFireInput = self:GetAIBombMissDistance(targetPos, target:GetVelocity(), AI_CARPET_BOMB_GRAVITY) < AI_CARPET_RELEASE_RADIUS
    self.bAIFaceTravel = true

    return targetPos + self.aiRunDirection * AI_CARPET_OVERSHOOT + Vector(0, 0, AI_GUN_HEIGHT)
end

--- Lifts a goal so that it stays clear of the ground, and above whatever stands between it and the helicopter; when the way is blocked the helicopter climbs on the spot first.
---@param goal Vector Position the autopilot wants to fly to.
---@return Vector goal Position that is safe to fly to.
function ENT:ClearAIGoal(goal)
    local pos = self:GetPos()
    local ground = util.TraceLine({
        start = goal + Vector(0, 0, 1000),
        endpos = goal - Vector(0, 0, 2000),
        mask = MASK_SOLID_BRUSHONLY,
    })

    if ( ground.Hit and !ground.StartSolid ) then
        goal.z = math.max(goal.z, ground.HitPos.z + AI_MIN_ALTITUDE)
    end

    local blocker = util.TraceLine({
        start = pos,
        endpos = goal,
        mask = MASK_SOLID_BRUSHONLY,
    })

    if ( !blocker.Hit or blocker.HitSky ) then return goal end

    return Vector(pos.x, pos.y, math.max(goal.z, blocker.HitPos.z + AI_OBSTACLE_CLEARANCE))
end

--- Runs the autopilot: without an enemy it wanders like any LVS helicopter, with one it attacks in the mode it has picked.
function ENT:RunAI()
    local target = self:AIGetTarget()

    if ( !IsValid(target) or !self.aiMode ) then
        self.bAIFaceTravel = false

        BaseClass.RunAI(self)

        return
    end

    local targetPos = target:WorldSpaceCenter()
    local goal

    self:UpdateAIMode(targetPos)

    if ( self.aiMode == AI_MODE_CARPET ) then
        goal = self:RunAICarpetBombing(target, targetPos)
    elseif ( self.aiMode == AI_MODE_BOMB ) then
        goal = self:RunAIBombing(target, targetPos)
    else
        goal = self:RunAIGun(target, targetPos)
    end

    self._lvsTargetPos = self:ClearAIGoal(goal)
    self:SetAIAimVector((targetPos - self:GetPos()):GetNormalized())
end
