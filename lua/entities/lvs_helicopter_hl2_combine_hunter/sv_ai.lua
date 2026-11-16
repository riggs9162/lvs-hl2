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

--- Seconds between two rounds of the probes that feel for obstacles around the helicopter.
local AI_PROBE_INTERVAL = 0.1

--- Half the width and depth of the box the probes sweep, a little over half the rotor's reach.
local AI_PROBE_WIDTH = 200

--- Half the height of the box the probes sweep.
local AI_PROBE_HEIGHT = 60

--- Distance the probes reach to every side.
local AI_PROBE_RANGE = 700

--- Distance the probe below the helicopter reaches.
local AI_PROBE_RANGE_DOWN = 350

--- Seconds of flight the probe along the helicopter's path looks ahead, on top of the range to every side.
local AI_PROBE_LOOKAHEAD_TIME = 1.5

--- Distance the autopilot's goal is pushed away from an obstacle that touches the helicopter, fading to nothing at the end of a probe.
local AI_AVOID_STRENGTH = 900

--- Height the autopilot's goal is raised by an obstacle right in the helicopter's path, so that it climbs over walls instead of only braking.
local AI_AVOID_CLIMB = 700

--- Share of the probe along the helicopter's path that must be free for the path to count as open.
local AI_PATH_OPEN_FRACTION = 0.6

--- Seconds the autopilot waits before it may reverse its circling again because of an obstacle.
local AI_BLOCKED_FLIP_INTERVAL = 2

--- Horizontal directions the probes sweep in.
local AI_PROBE_DIRECTIONS = {}

for yaw = 0, 315, 45 do
    AI_PROBE_DIRECTIONS[#AI_PROBE_DIRECTIONS + 1] = Angle(0, yaw, 0):Forward()
end

--- Farthest two hunter-choppers with the same enemy can be apart to attack as a group.
local AI_GROUP_RADIUS = 5000

--- Seconds between two checks of which helicopters belong to the group.
local AI_GROUP_UPDATE_INTERVAL = 0.5

--- Longest seconds one helicopter may keep the group's turn to attack.
local AI_TURN_MAX_TIME = 25

--- Horizontal distance the helicopters waiting for their turn keep from the enemy, outside the attacker's circle.
local AI_WAIT_STANDOFF = 2000

--- Height each further waiting helicopter adds on top of the one before it, so that they never share a level.
local AI_WAIT_HEIGHT_STEP = 200

--- Degrees per second the waiting helicopters move around the enemy.
local AI_WAIT_ORBIT_SPEED = 6

--- Distance a helicopter in a patrolling convoy keeps behind the one it follows, far enough that their obstacle probes do not touch.
local AI_CONVOY_SPACING = 1000

--- Speed the first helicopter of a convoy keeps to, slow enough for the others to catch up and hold their places.
local AI_CONVOY_LEAD_SPEED = 550

--- Seconds of the movement of the helicopter ahead that a follower aims in front of its place in the line, which makes up for the time its own flight takes to get there.
local AI_CONVOY_LEAD_TIME = 1.5

--- Speed below which the helicopter ahead is taken to point where it faces instead of where it moves.
local AI_CONVOY_MIN_SPEED = 50

--- Whose turn it is to attack each enemy, shared by all hunter-choppers and keyed by the enemy.
local groupTurns = setmetatable({}, {__mode = "k"})

--- Marks the entity as a hunter-chopper for others of its kind that look for a group.
ENT.bHunterChopper = true

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
    self.aiNextProbe = 0
    self.aiAvoidance = Vector(0, 0, 0)
    self.aiNextBlockedFlip = 0
    self.aiGroup = {}
    self.aiNextGroupUpdate = 0
    self.bAIPathBlocked = false
    self.bAITurnFired = false
    self.bAIFaceTravel = false
end

--- Sweeps a box from the helicopter in one direction and returns how much of the way is free.
---@param origin Vector Centre of the helicopter.
---@param direction Vector Direction to sweep in.
---@param range number Distance to sweep.
---@param filter table Entities the sweep ignores.
---@return number fraction Free share of the way between 0 and 1, or 1 when the helicopter already touches something and the sweep says nothing.
local function Probe(origin, direction, range, filter)
    local trace = util.TraceHull({
        start = origin,
        endpos = origin + direction * range,
        mins = Vector(-AI_PROBE_WIDTH, -AI_PROBE_WIDTH, -AI_PROBE_HEIGHT),
        maxs = Vector(AI_PROBE_WIDTH, AI_PROBE_WIDTH, AI_PROBE_HEIGHT),
        mask = MASK_SOLID,
        filter = filter,
    })

    if ( trace.StartSolid or trace.HitSky ) then return 1 end

    return trace.Fraction
end

--- Feels for walls, ground, props and other vehicles around the helicopter and along its path, and works out how far the autopilot's goal has to be pushed away from them.
function ENT:UpdateAIAvoidance()
    local now = CurTime()
    if ( now < self.aiNextProbe ) then return end

    self.aiNextProbe = now + AI_PROBE_INTERVAL

    local origin = self:WorldSpaceCenter()
    local filter = self:GetCrosshairFilterEnts()
    local avoidance = Vector(0, 0, 0)

    for _, direction in ipairs(AI_PROBE_DIRECTIONS) do
        local blocked = 1 - Probe(origin, direction, AI_PROBE_RANGE, filter)

        avoidance:Sub(direction * (blocked * AI_AVOID_STRENGTH))
    end

    avoidance.z = avoidance.z + (1 - Probe(origin, Vector(0, 0, -1), AI_PROBE_RANGE_DOWN, filter)) * AI_AVOID_STRENGTH

    local velocity = self:GetVelocity()
    local speed = velocity:Length()

    self.bAIPathBlocked = false

    if ( speed > 50 ) then
        local direction = velocity / speed
        local fraction = Probe(origin, direction, AI_PROBE_RANGE + speed * AI_PROBE_LOOKAHEAD_TIME, filter)
        local blocked = 1 - fraction

        avoidance:Sub(direction * (blocked * AI_AVOID_STRENGTH))
        avoidance.z = avoidance.z + blocked * AI_AVOID_CLIMB

        self.bAIPathBlocked = fraction < AI_PATH_OPEN_FRACTION
    end

    self.aiAvoidance = avoidance
end

--- Returns how far the autopilot's goal has to be pushed away from the obstacles around the helicopter.
---@return Vector avoidance
function ENT:GetAIAvoidance()
    return self.aiAvoidance or vector_origin
end

--- Returns the enemy a helicopter's autopilot is after, or nil when it has none.
---@param vehicle Entity Helicopter to ask.
---@return Entity|nil target
local function GetEnemy(vehicle)
    local target = vehicle:AIGetTarget()
    if ( !IsValid(target) ) then return nil end

    return target
end

--- Returns the hunter-choppers that are after the same enemy, or like this one after none, close enough to work as a group, this one included, in a fixed order.
---@param target Entity|nil Enemy, or nil for the helicopters on patrol.
---@return table group
function ENT:GetAIGroup(target)
    local now = CurTime()
    if ( now < self.aiNextGroupUpdate ) then return self.aiGroup end

    self.aiNextGroupUpdate = now + AI_GROUP_UPDATE_INTERVAL

    local group = {}
    local pos = self:GetPos()

    for _, vehicle in pairs(LVS:GetVehicles()) do
        if ( !IsValid(vehicle) or !vehicle.bHunterChopper ) then continue end
        if ( !vehicle:GetAI() or vehicle:IsDestroyed() or vehicle:GetAITEAM() != self:GetAITEAM() ) then continue end
        if ( vehicle != self and (GetEnemy(vehicle) != target or vehicle:GetPos():DistToSqr(pos) > AI_GROUP_RADIUS * AI_GROUP_RADIUS) ) then continue end

        group[#group + 1] = vehicle
    end

    table.sort(group, function(a, b)
        return a:EntIndex() < b:EntIndex()
    end)

    self.aiGroup = group

    return group
end

--- Returns whether a helicopter can still hold the turn to attack an enemy.
---@param holder Entity|nil Helicopter to check.
---@param target Entity Enemy.
---@return boolean bCanHold
local function CanHoldTurn(holder, target)
    if ( !IsValid(holder) or !holder:GetAI() or holder:IsDestroyed() ) then return false end

    return holder:AIGetTarget() == target
end

--- Returns the helicopter of the group whose turn it is to attack, passing the turn on to the next one in order when the last holder has finished, run out of time or dropped out.
---@param target Entity Enemy.
---@param group table Helicopters attacking the enemy together.
---@return Entity holder
function ENT:GetAITurnHolder(target, group)
    local now = CurTime()
    local turn = groupTurns[target]
    if ( turn and now < turn.endTime and CanHoldTurn(turn.holder, target) ) then return turn.holder end

    local holder = group[1]

    if ( turn ) then
        for _, member in ipairs(group) do
            if ( member:EntIndex() > turn.lastIndex ) then
                holder = member

                break
            end
        end
    end

    groupTurns[target] = {
        holder = holder,
        endTime = now + AI_TURN_MAX_TIME,
        lastIndex = holder:EntIndex(),
    }

    holder.bAITurnFired = false

    return holder
end

--- Gives up the turn to attack an enemy so that the next helicopter of the group can take it.
---@param target Entity Enemy.
function ENT:EndAITurn(target)
    local turn = groupTurns[target]
    if ( !turn or turn.holder != self ) then return end

    turn.endTime = 0
end

--- Returns whether the helicopter has used up its turn: its gun has fired its bursts and it is back from any bombing pass that followed.
---@return boolean bOver
function ENT:IsAITurnOver()
    if ( self:IsGunFiring() ) then
        self.bAITurnFired = true
    end

    return self.bAITurnFired and self.aiMode == AI_MODE_GUN and (self:IsGunResting() or self:IsGunReady())
end

--- Holds the helicopter outside the attacker's circle while it waits for its turn, each waiting helicopter at its own bearing and height, drifting slowly around the enemy with its weapons silent.
---@param targetPos Vector Centre of the enemy.
---@param group table Helicopters attacking the enemy together.
---@return Vector goal Position to fly to.
function ENT:RunAIWaiting(targetPos, group)
    local slot = 1

    for index, member in ipairs(group) do
        if ( member == self ) then
            slot = index

            break
        end
    end

    local yaw = 360 / #group * (slot - 1) + CurTime() * AI_WAIT_ORBIT_SPEED

    self.aiMode = AI_MODE_GUN
    self._AIFireInput = false
    self.bAIFaceTravel = false

    if ( !self:IsGunFiring() ) then
        self:SetAIWeapon(self.WEAPON_GUN)
    end

    return targetPos + Angle(0, yaw, 0):Forward() * AI_WAIT_STANDOFF + Vector(0, 0, AI_GUN_HEIGHT + AI_WAIT_HEIGHT_STEP * (slot - 1))
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

--- Circles the enemy at gun range, turning around when something blocks the way, and holds still on that circle while the gun charges and fires.
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

    if ( self.bAIPathBlocked and now > self.aiNextBlockedFlip ) then
        self.aiNextBlockedFlip = now + AI_BLOCKED_FLIP_INTERVAL
        self.aiOrbitDirection = -self.aiOrbitDirection
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
    local pos = self:WorldSpaceCenter()
    local ground = util.TraceLine({
        start = goal + Vector(0, 0, 1000),
        endpos = goal - Vector(0, 0, 2000),
        mask = MASK_SOLID_BRUSHONLY,
    })

    if ( ground.Hit and !ground.StartSolid ) then
        goal.z = math.max(goal.z, ground.HitPos.z + AI_MIN_ALTITUDE)
    end

    local blocker = util.TraceHull({
        start = pos,
        endpos = goal,
        mins = Vector(-AI_PROBE_WIDTH, -AI_PROBE_WIDTH, -AI_PROBE_HEIGHT),
        maxs = Vector(AI_PROBE_WIDTH, AI_PROBE_WIDTH, AI_PROBE_HEIGHT),
        mask = MASK_SOLID_BRUSHONLY,
    })

    if ( !blocker.Hit or blocker.HitSky or blocker.StartSolid ) then return goal end

    return Vector(pos.x, pos.y, math.max(goal.z, blocker.HitPos.z + AI_OBSTACLE_CLEARANCE))
end

--- Returns where the helicopter attacks from in the mode it has picked.
---@param target Entity Enemy.
---@param targetPos Vector Centre of the enemy.
---@return Vector goal Position to fly to.
function ENT:RunAIAttack(target, targetPos)
    if ( self.aiMode == AI_MODE_CARPET ) then return self:RunAICarpetBombing(target, targetPos) end
    if ( self.aiMode == AI_MODE_BOMB ) then return self:RunAIBombing(target, targetPos) end

    return self:RunAIGun(target, targetPos)
end

--- Patrols without an enemy: a lone helicopter, or the first of a group, wanders like any LVS helicopter, the first of a group at a reduced speed, and every other one of the group follows the one before it in a line, keeping its distance and matching its movement.
function ENT:RunAIPatrol()
    local group = self:GetAIGroup(nil)
    local ahead

    for index, member in ipairs(group) do
        if ( member == self ) then
            ahead = group[index - 1]

            break
        end
    end

    if ( !IsValid(ahead) ) then
        self.bAIFaceTravel = false
        self.aiSpeedLimit = #group > 1 and AI_CONVOY_LEAD_SPEED or nil

        BaseClass.RunAI(self)

        return
    end

    self.aiSpeedLimit = nil

    local velocity = ahead:GetVelocity()
    local direction = Vector(velocity.x, velocity.y, 0)

    if ( direction:LengthSqr() < AI_CONVOY_MIN_SPEED * AI_CONVOY_MIN_SPEED ) then
        direction = ahead:GetForward()
        direction.z = 0
    end

    direction:Normalize()

    self:SetAIWeapon(self.WEAPON_GUN)
    self._AIFireInput = false
    self.bAIFaceTravel = true
    self._lvsTargetPos = self:ClearAIGoal(ahead:GetPos() - direction * AI_CONVOY_SPACING + velocity * AI_CONVOY_LEAD_TIME)
    self:SetAIAimVector(self:GetForward())
end

--- Runs the autopilot: without an enemy it patrols, alone or in a convoy; with one it attacks, and several helicopters with the same enemy take turns attacking while the others wait around it.
function ENT:RunAI()
    if ( !self.aiMode ) then return BaseClass.RunAI(self) end

    self:UpdateAIAvoidance()

    local target = GetEnemy(self)

    if ( !target ) then
        self:RunAIPatrol()

        return
    end

    self.aiSpeedLimit = nil

    local targetPos = target:WorldSpaceCenter()
    local group = self:GetAIGroup(target)
    local bAttacking = #group <= 1 or self:GetAITurnHolder(target, group) == self
    local goal

    if ( bAttacking ) then
        self:UpdateAIMode(targetPos)

        if ( #group > 1 and self:IsAITurnOver() ) then
            self:EndAITurn(target)
            bAttacking = false
        end
    end

    if ( bAttacking ) then
        goal = self:RunAIAttack(target, targetPos)
    else
        goal = self:RunAIWaiting(targetPos, group)
    end

    self._lvsTargetPos = self:ClearAIGoal(goal)
    self:SetAIAimVector((targetPos - self:GetPos()):GetNormalized())
end
