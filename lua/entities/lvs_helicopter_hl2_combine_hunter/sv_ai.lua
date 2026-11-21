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

--- Height above an enemy in the air the autopilot keeps while using the gun; none, so that two helicopters fighting each other do not climb to get above one another.
local AI_GUN_HEIGHT_AIR = 0

--- Least height the helicopter must have over an enemy on the ground to bomb it.
local AI_BOMB_MIN_HEIGHT = 150

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

--- Distance beyond its enemy the autopilot flies to on a bombing pass or a carpet bombing run, so that it crosses over the enemy instead of stopping above it.
local AI_RUN_OVERSHOOT = 1500

--- Share of that distance beyond its enemy after which the pass or run counts as flown.
local AI_RUN_DONE_FRACTION = 0.75

--- Closest horizontal distance to its enemy at which the autopilot starts charging the gun; any closer and it backs off to its circle first instead of shooting straight down.
local AI_GUN_MIN_RANGE = 800

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

--- Height between two of the levels the autopilot tries when it looks for a way over an obstacle.
local AI_DETOUR_STEP = 300

--- Number of levels above its goal the autopilot tries when it looks for a way over an obstacle.
local AI_DETOUR_STEPS = 5

--- Farthest below a level the helicopter may still be to start crossing the obstacle on it.
local AI_DETOUR_TOLERANCE = 150

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

--- Distance the probes below and above the helicopter reach.
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

--- Highest above the ground a patrolling helicopter's waypoint may be.
local AI_PATROL_MAX_ALTITUDE = 1200

--- Distance below a patrolling helicopter in which the ground is looked for.
local AI_PATROL_GROUND_RANGE = 16000

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
---@return number fraction Free share of the way between 0 and 1, or 1 when the helicopter already touches something and the sweep says nothing. The edge of the map counts as an obstacle like any other.
local function Probe(origin, direction, range, filter)
    local trace = util.TraceHull({
        start = origin,
        endpos = origin + direction * range,
        mins = Vector(-AI_PROBE_WIDTH, -AI_PROBE_WIDTH, -AI_PROBE_HEIGHT),
        maxs = Vector(AI_PROBE_WIDTH, AI_PROBE_WIDTH, AI_PROBE_HEIGHT),
        mask = MASK_SOLID,
        filter = filter,
    })

    if ( trace.StartSolid ) then return 1 end

    return trace.Fraction
end

--- Feels for walls, ground, ceilings, props and other vehicles around the helicopter and along its path, and works out how far the autopilot's goal has to be pushed away from them. Its own enemy is left out, since the attack already keeps its distance to it and two helicopters fighting each other would otherwise climb away from one another without end.
function ENT:UpdateAIAvoidance()
    local now = CurTime()
    if ( now < self.aiNextProbe ) then return end

    self.aiNextProbe = now + AI_PROBE_INTERVAL

    local origin = self:WorldSpaceCenter()
    local filter = table.Copy(self:GetCrosshairFilterEnts())
    local avoidance = Vector(0, 0, 0)

    filter[#filter + 1] = self:AIGetTarget()

    for _, direction in ipairs(AI_PROBE_DIRECTIONS) do
        local blocked = 1 - Probe(origin, direction, AI_PROBE_RANGE, filter)

        avoidance:Sub(direction * (blocked * AI_AVOID_STRENGTH))
    end

    avoidance.z = avoidance.z + (1 - Probe(origin, Vector(0, 0, -1), AI_PROBE_RANGE_DOWN, filter)) * AI_AVOID_STRENGTH
    avoidance.z = avoidance.z - (1 - Probe(origin, Vector(0, 0, 1), AI_PROBE_RANGE_DOWN, filter)) * AI_AVOID_STRENGTH

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

--- Returns whether an enemy is on the ground rather than in the air.
---@param targetPos Vector Centre of the enemy.
---@return boolean bOnGround
function ENT:IsAITargetOnGround(targetPos)
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

--- Picks what the autopilot does next: it stays on the gun until a burst is over, then flies a bombing pass, or a carpet bombing run if it has lost enough health, and returns to the gun when the pass is done. Enemies in the air, or not far enough below the helicopter, are only ever fought with the gun.
---@param targetPos Vector Centre of the enemy.
function ENT:UpdateAIMode(targetPos)
    local now = CurTime()
    local bCanBomb = targetPos.z < self:GetPos().z - AI_BOMB_MIN_HEIGHT and self:IsAITargetOnGround(targetPos)

    if ( self.aiMode != AI_MODE_GUN ) then
        local bDone = now > self.aiModeEndTime or !bCanBomb

        if ( self.aiMode == AI_MODE_BOMB and self:GetAIBombsDropped() >= AI_BOMBS_PER_PASS ) then
            bDone = true
        end

        if ( (self:GetPos() - targetPos):Dot(self.aiRunDirection) > AI_RUN_OVERSHOOT * AI_RUN_DONE_FRACTION ) then
            bDone = true
        end

        if ( bDone ) then
            self.aiMode = AI_MODE_GUN
            self.aiNextBombPass = now + AI_BOMB_PASS_INTERVAL
        end

        return
    end

    if ( !bCanBomb or !self:IsGunResting() ) then return end

    local direction = targetPos - self:GetPos()
    direction.z = 0
    direction:Normalize()

    if ( self:GetHP() <= self:GetMaxHP() * self.aiNextCarpetHealth ) then
        self.aiNextCarpetHealth = self.aiNextCarpetHealth - AI_CARPET_HEALTH_STEP
        self.aiRunDirection = direction
        self.aiMode = AI_MODE_CARPET
        self.aiModeEndTime = now + AI_CARPET_RUN_TIME

        return
    end

    if ( now < self.aiNextBombPass ) then return end

    self.aiRunDirection = direction
    self.aiMode = AI_MODE_BOMB
    self.aiModeEndTime = now + AI_BOMB_PASS_TIME
    self.aiStickMark = self.bombsDropped
end

--- Circles the enemy at gun range, turning around when something blocks the way, and holds still on that circle while the gun charges and fires. It only starts charging from far enough out to shoot at the enemy from the side, and it meets an enemy in the air at that enemy's own height, measured centre to centre so that two helicopters do not each try to get above the other.
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
    self._AIFireInput = bearing:LengthSqr() >= AI_GUN_MIN_RANGE * AI_GUN_MIN_RANGE and self:AICanSee(target)
    self.bAIFaceTravel = false

    local height = AI_GUN_HEIGHT

    if ( !self:IsAITargetOnGround(targetPos) ) then
        height = AI_GUN_HEIGHT_AIR - (self:WorldSpaceCenter().z - self:GetPos().z)
    end

    return targetPos + Angle(0, yaw, 0):Forward() * AI_GUN_STANDOFF + Vector(0, 0, height)
end

--- Flies a straight pass over where the enemy is going to be and on beyond it, letting a bomb go whenever it would land close enough.
---@param target Entity Enemy.
---@param targetPos Vector Centre of the enemy.
---@return Vector goal Position to fly to.
function ENT:RunAIBombing(target, targetPos)
    local targetVelocity = target:GetVelocity()
    local distance = (targetPos - self:GetPos()):Length2D()
    local leadTime = math.Clamp(distance / math.max(self:GetVelocity():Length2D(), AI_MIN_APPROACH_SPEED), 0, AI_MAX_LEAD_TIME)

    self:SetAIWeapon(self.WEAPON_BOMBS)
    self._AIFireInput = self:GetAIBombMissDistance(targetPos, targetVelocity, physenv.GetGravity():Length()) < AI_BOMB_RELEASE_RADIUS
    self.bAIFaceTravel = true

    return targetPos + targetVelocity * leadTime + self.aiRunDirection * AI_RUN_OVERSHOOT + Vector(0, 0, AI_BOMB_HEIGHT)
end

--- Rushes in a straight line over the enemy and beyond, carpet bombing everything around it on the way.
---@param target Entity Enemy.
---@param targetPos Vector Centre of the enemy.
---@return Vector goal Position to fly to.
function ENT:RunAICarpetBombing(target, targetPos)
    self:SetAIWeapon(self.WEAPON_CARPET_BOMBS)
    self._AIFireInput = self:GetAIBombMissDistance(targetPos, target:GetVelocity(), AI_CARPET_BOMB_GRAVITY) < AI_CARPET_RELEASE_RADIUS
    self.bAIFaceTravel = true

    return targetPos + self.aiRunDirection * AI_RUN_OVERSHOOT + Vector(0, 0, AI_GUN_HEIGHT)
end

--- Returns whether the helicopter fits through the straight way between two points.
---@param from Vector Start of the way.
---@param to Vector End of the way.
---@return boolean bClear
local function IsPathClear(from, to)
    local trace = util.TraceHull({
        start = from,
        endpos = to,
        mins = Vector(-AI_PROBE_WIDTH, -AI_PROBE_WIDTH, -AI_PROBE_HEIGHT),
        maxs = Vector(AI_PROBE_WIDTH, AI_PROBE_WIDTH, AI_PROBE_HEIGHT),
        mask = MASK_SOLID_BRUSHONLY,
    })

    return !trace.Hit or trace.HitSky or trace.StartSolid
end

--- Lifts a goal so that it stays clear of the ground, and finds a way over whatever stands between it and the helicopter: the lowest level above the goal on which the way across is free. The helicopter first climbs or sinks to that level where it is, then crosses on it, and comes down once the straight way to the goal is free. When no level is free it heads for the goal anyway and leaves it to its probes to keep it off the obstacle.
---@param goal Vector Position the autopilot wants to fly to.
---@return Vector goal Position that is safe to fly to next.
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

    if ( IsPathClear(pos, goal) ) then return goal end

    for step = 1, AI_DETOUR_STEPS do
        local level = goal.z + step * AI_DETOUR_STEP

        if ( IsPathClear(Vector(pos.x, pos.y, level), Vector(goal.x, goal.y, level)) ) then
            if ( math.abs(pos.z - level) > AI_DETOUR_TOLERANCE ) then return Vector(pos.x, pos.y, level) end

            return Vector(goal.x, goal.y, level)
        end
    end

    return goal
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

--- Brings the waypoint of a wandering helicopter down to patrol height above the ground below it, since the stock wandering otherwise drifts up to the top of the map.
function ENT:LimitAIPatrolAltitude()
    local waypoint = self._lvsTargetPos
    if ( !waypoint ) then return end

    local pos = self:GetPos()
    local ground = util.TraceLine({
        start = pos,
        endpos = pos - Vector(0, 0, AI_PATROL_GROUND_RANGE),
        mask = MASK_SOLID_BRUSHONLY,
    })

    if ( !ground.Hit ) then return end

    waypoint.z = math.min(waypoint.z, ground.HitPos.z + AI_PATROL_MAX_ALTITUDE)
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
        self:LimitAIPatrolAltitude()

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

--- Farthest an NPC may be from a hunter-chopper to be told where it is when the two become enemies; any farther and the NPC has to spot it by itself first.
local NPC_AWARENESS_RANGE = 3000

--- Priority of the hatred NPCs feel for a hunter-chopper, the same as for any other enemy, so that they keep fighting what is closest instead of always going for the helicopter.
local NPC_HATE_PRIORITY = 0

--- Undoes the parts of the LVS enemy setup that pull every hostile NPC on the map towards a hunter-chopper: it keeps the NPC hostile, but at an ordinary priority, and makes it forget the helicopter again unless it is close and in sight.
---@param npc NPC NPC to adjust.
---@param chopper Entity Hunter-chopper it was set against.
local function RelaxNPCRelationship(npc, chopper)
    if ( !IsValid(npc) or !IsValid(chopper) ) then return end
    if ( npc:Disposition(chopper) != D_HT ) then return end

    npc:AddEntityRelationship(chopper, D_HT, NPC_HATE_PRIORITY)

    if ( npc:GetPos():DistToSqr(chopper:GetPos()) <= NPC_AWARENESS_RANGE * NPC_AWARENESS_RANGE and npc:Visible(chopper) ) then return end

    npc:ClearEnemyMemory(chopper)
end

--- Applies the relaxed NPC relationship after LVS has set up its own, for a hunter-chopper against every NPC or for a new NPC against every hunter-chopper.
---@param ent Entity Vehicle or NPC whose relationships LVS has just updated.
local function OnRelationshipUpdated(ent)
    if ( !IsValid(ent) ) then return end

    if ( ent:IsNPC() ) then
        for _, vehicle in pairs(LVS:GetVehicles()) do
            if ( IsValid(vehicle) and vehicle.bHunterChopper ) then
                RelaxNPCRelationship(ent, vehicle)
            end
        end

        return
    end

    if ( !ent.bHunterChopper ) then return end

    for _, npc in pairs(LVS:GetNPCs()) do
        RelaxNPCRelationship(npc, ent)
    end
end

hook.Add("LVS.UpdateRelationship", "LVS.HL2.HunterChopper.Relationship", function(ent)
    timer.Simple(0.2, function()
        OnRelationshipUpdated(ent)
    end)
end)
