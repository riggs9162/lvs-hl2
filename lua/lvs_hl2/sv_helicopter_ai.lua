--- Autopilot helpers shared by the Half-Life 2 helicopters: obstacle probes that push the goal away from walls, a way over obstacles, a patrol height limit and small queries used by their attack patterns.

--- Lowest the autopilot's goal may be above the ground.
local AI_MIN_ALTITUDE = 350

--- Height between two of the levels the autopilot tries when it looks for a way over an obstacle.
local AI_DETOUR_STEP = 300

--- Number of levels above its goal the autopilot tries when it looks for a way over an obstacle.
local AI_DETOUR_STEPS = 5

--- Farthest below a level the helicopter may still be to start crossing the obstacle on it.
local AI_DETOUR_TOLERANCE = 150

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

--- Horizontal directions the probes sweep in.
local AI_PROBE_DIRECTIONS = {}

for yaw = 0, 315, 45 do
    AI_PROBE_DIRECTIONS[#AI_PROBE_DIRECTIONS + 1] = Angle(0, yaw, 0):Forward()
end

--- Highest above the ground a patrolling helicopter's waypoint may be.
local AI_PATROL_MAX_ALTITUDE = 1200

--- Distance below a patrolling helicopter in which the ground is looked for.
local AI_PATROL_GROUND_RANGE = 16000

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
    if ( now < (self.aiNextProbe or 0) ) then return end

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
