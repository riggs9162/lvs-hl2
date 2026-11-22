--- Navigation of the strider's autopilot. It plans its routes over the map's navigation mesh, keeping to the open areas a walker of its size fits through and leaving out those under a roof, and checks the way ahead for walls at the height of its legs and of its body, so that it walks around buildings instead of into them. Without a navigation mesh it still steers around the walls in front of it.

--- Seconds between two plans of a route, and the distance the goal may move before the route is planned again sooner.
local NAV_REPLAN_INTERVAL = 2
local NAV_GOAL_MOVED = 400

--- Most areas the planner looks at for one route, so that a route across a large map does not stall the server.
local NAV_MAX_EXPANSIONS = 3000

--- Farthest a start or a goal may be from the navigation mesh for the planner to use it.
local NAV_SNAP_DISTANCE = 600

--- Highest step up between two areas the strider's legs can take.
local NAV_MAX_CLIMB = 160

--- Free height above an area the strider's body needs, and the half width of the column checked for it.
local NAV_CLEAR_HEIGHT = 560
local NAV_CLEAR_RADIUS = 32

--- Distance at which a waypoint counts as reached.
local NAV_WAYPOINT_RADIUS = 180

--- Most waypoints the strider looks past for a straight walk to a later one on one think.
local NAV_SHORTCUT_CHECKS = 3

--- Heights above the ground the way ahead is checked for walls at, those of its body, and the half width of the strider checked with. Its legs step over and around anything lower, such as cars, fences and street lamps, which stand between its feet.
local WALK_PROBE_HEIGHTS = {420}
local WALK_PROBE_RADIUS = 64

--- Distance ahead the strider checks for walls, and the turns off its heading it tries when the way is blocked.
local WALK_PROBE_DISTANCE = 500
local WALK_DETOURS = {0, 30, -30, 60, -60, 90, -90, 120, -120}

--- Seconds the strider keeps a heading it found free before it checks the way again.
local WALK_HEADING_INTERVAL = 0.2

--- Seconds the strider may walk without getting this far before it counts as stuck and looks for another way.
local WALK_STUCK_TIME = 4
local WALK_STUCK_DISTANCE = 60

--- Shortest and longest distance of a spot the strider wanders to.
local WANDER_MIN_DISTANCE = 1200
local WANDER_MAX_DISTANCE = 4000

--- Whether each navigation area, by its id, has room for the strider's body above it.
local areaClearance = {}

--- Returns whether the strider fits above a navigation area: nothing solid in a column the height of its body, so that it stays out of buildings, under bridges and in tunnels.
---@param area CNavArea
---@return boolean bClear
local function IsAreaClear(area)
    local id = area:GetID()
    local cached = areaClearance[id]
    if ( cached != nil ) then return cached end

    local center = area:GetCenter()
    local trace = util.TraceHull({
        start = center + Vector(0, 0, 24),
        endpos = center + Vector(0, 0, NAV_CLEAR_HEIGHT),
        mins = Vector(-NAV_CLEAR_RADIUS, -NAV_CLEAR_RADIUS, 0),
        maxs = Vector(NAV_CLEAR_RADIUS, NAV_CLEAR_RADIUS, 1),
        mask = MASK_NPCSOLID_BRUSHONLY,
    })

    local bClear = !trace.Hit and !area:IsUnderwater()
    areaClearance[id] = bClear

    return bClear
end

--- Pushes an area onto the open list of the planner, a binary heap ordered by estimated cost.
---@param heap table
---@param area CNavArea
---@param cost number
local function HeapPush(heap, area, cost)
    local index = #heap + 1
    heap[index] = {area = area, cost = cost}

    while ( index > 1 ) do
        local parent = math.floor(index / 2)
        if ( heap[parent].cost <= heap[index].cost ) then break end

        heap[parent], heap[index] = heap[index], heap[parent]
        index = parent
    end
end

--- Takes the area with the lowest estimated cost off the open list of the planner.
---@param heap table
---@return CNavArea|nil area
local function HeapPop(heap)
    local count = #heap
    if ( count == 0 ) then return nil end

    local top = heap[1]
    heap[1] = heap[count]
    heap[count] = nil
    count = count - 1

    local index = 1

    while ( true ) do
        local left = index * 2
        local right = left + 1
        local smallest = index

        if ( left <= count and heap[left].cost < heap[smallest].cost ) then
            smallest = left
        end

        if ( right <= count and heap[right].cost < heap[smallest].cost ) then
            smallest = right
        end

        if ( smallest == index ) then break end

        heap[smallest], heap[index] = heap[index], heap[smallest]
        index = smallest
    end

    return top.area
end

--- Returns the route from one area to another as the areas' centres, or towards the reachable area closest to the goal when the goal itself cannot be reached.
---@param startArea CNavArea
---@param goalArea CNavArea
---@param goalPos Vector
---@return table|nil points
local function PlanRoute(startArea, goalArea, goalPos)
    local startId = startArea:GetID()
    local goalId = goalArea:GetID()
    local cameFrom = {}
    local costSoFar = {[startId] = 0}
    local closed = {}
    local heap = {}
    local bestArea = startArea
    local bestDistance = startArea:GetCenter():DistToSqr(goalPos)
    local expansions = 0

    HeapPush(heap, startArea, 0)

    while ( expansions < NAV_MAX_EXPANSIONS ) do
        local area = HeapPop(heap)
        if ( !area ) then break end

        local id = area:GetID()

        if ( !closed[id] ) then
            closed[id] = true
            expansions = expansions + 1

            local center = area:GetCenter()
            local distance = center:DistToSqr(goalPos)

            if ( distance < bestDistance ) then
                bestArea = area
                bestDistance = distance
            end

            if ( id == goalId ) then
                bestArea = area

                break
            end

            for _, neighbor in ipairs(area:GetAdjacentAreas()) do
                local neighborId = neighbor:GetID()

                if ( !closed[neighborId] and area:ComputeAdjacentConnectionHeightChange(neighbor) <= NAV_MAX_CLIMB and IsAreaClear(neighbor) ) then
                    local cost = costSoFar[id] + center:Distance(neighbor:GetCenter())

                    if ( !costSoFar[neighborId] or cost < costSoFar[neighborId] ) then
                        costSoFar[neighborId] = cost
                        cameFrom[neighborId] = area
                        HeapPush(heap, neighbor, cost + neighbor:GetCenter():Distance(goalPos))
                    end
                end
            end
        end
    end

    local bestId = bestArea:GetID()
    if ( bestId == startId ) then return nil end

    local points = {}
    local area = bestArea

    while ( area and area:GetID() != startId ) do
        table.insert(points, 1, area:GetCenter())
        area = cameFrom[area:GetID()]
    end

    if ( bestId == goalId ) then
        points[#points] = goalPos
    end

    return points
end

--- Returns where the strider's feet stand, below the middle of its body.
---@return Vector groundPos
function ENT:GetNavGroundPos()
    local pos = self:GetPos()

    return Vector(pos.x, pos.y, self.groundZ or pos.z - self.StandHeight)
end

--- Returns whether the strider can walk straight from where it stands to a point: no wall in the way of its body. A check that starts inside something, such as a tree the strider stands over, does not count.
---@param point Vector
---@return boolean bClear
function ENT:IsWalkClear(point)
    local groundPos = self:GetNavGroundPos()
    local target = Vector(point.x, point.y, groundPos.z)
    local mins = Vector(-WALK_PROBE_RADIUS, -WALK_PROBE_RADIUS, 0)
    local maxs = Vector(WALK_PROBE_RADIUS, WALK_PROBE_RADIUS, WALK_PROBE_RADIUS)

    for _, height in ipairs(WALK_PROBE_HEIGHTS) do
        local offset = Vector(0, 0, height)
        local trace = util.TraceHull({
            start = groundPos + offset,
            endpos = target + offset,
            mins = mins,
            maxs = maxs,
            mask = MASK_NPCSOLID_BRUSHONLY,
        })

        if ( trace.Hit and !trace.StartSolid ) then return false end
    end

    return true
end

--- Returns the heading closest to the one wanted that is free of walls for a while ahead, or nil when every way is blocked.
---@param yaw number Heading wanted.
---@param distance number Distance ahead to check, at most the usual probe distance.
---@return number|nil yaw
function ENT:GetClearHeading(yaw, distance)
    local groundPos = self:GetNavGroundPos()
    local probe = math.Clamp(distance, WALK_PROBE_RADIUS, WALK_PROBE_DISTANCE)

    for _, detour in ipairs(WALK_DETOURS) do
        local heading = yaw + detour

        if ( self:IsWalkClear(groundPos + Angle(0, heading, 0):Forward() * probe) ) then
            return heading
        end
    end

    return nil
end

--- Forgets the route, so that the next one is planned from scratch.
function ENT:ClearNavRoute()
    self.navRoute = nil
    self.navGoal = nil
    self.navNextPlan = 0
    self.navWaypoint = nil
end

--- Plans a route to a point over the navigation mesh, or returns nil when the map has none or no route leads closer.
---@param goalPos Vector
---@return table|nil points
function ENT:PlanNavRoute(goalPos)
    if ( !navmesh.IsLoaded() ) then return nil end

    local startArea = navmesh.GetNearestNavArea(self:GetNavGroundPos(), false, NAV_SNAP_DISTANCE, false, true)
    local goalArea = navmesh.GetNearestNavArea(goalPos, false, NAV_SNAP_DISTANCE, false, true)
    if ( !IsValid(startArea) or !IsValid(goalArea) ) then return nil end
    if ( startArea:GetID() == goalArea:GetID() ) then return {goalPos} end

    return PlanRoute(startArea, goalArea, goalPos)
end

--- Returns the next point to walk to on the way to a goal: the goal itself while the way there is clear, otherwise the next waypoint of a route over the navigation mesh, planned again now and then and whenever the goal moves away.
---@param goalPos Vector
---@return Vector|nil point
function ENT:GetNavWaypoint(goalPos)
    if ( self:IsWalkClear(goalPos) ) then
        self.navRoute = nil

        return goalPos
    end

    local now = CurTime()

    if ( !self.navRoute or now >= (self.navNextPlan or 0) or !self.navGoal or self.navGoal:Distance(goalPos) > NAV_GOAL_MOVED ) then
        self.navRoute = self:PlanNavRoute(goalPos)
        self.navIndex = 1
        self.navGoal = goalPos
        self.navNextPlan = now + NAV_REPLAN_INTERVAL * math.Rand(0.8, 1.2)
    end

    local route = self.navRoute
    if ( !route ) then return goalPos end

    local groundPos = self:GetNavGroundPos()

    while ( self.navIndex < #route and groundPos:Distance2D(route[self.navIndex]) < NAV_WAYPOINT_RADIUS ) do
        self.navIndex = self.navIndex + 1
    end

    for _ = 1, NAV_SHORTCUT_CHECKS do
        if ( self.navIndex >= #route or !self:IsWalkClear(route[self.navIndex + 1]) ) then break end

        self.navIndex = self.navIndex + 1
    end

    return route[self.navIndex]
end

--- Returns the heading to walk towards a point on, around the walls in the way, checking the way again only now and then because each check traces several times.
---@param point Vector
---@return number|nil yaw
function ENT:GetWalkHeading(point)
    local now = CurTime()
    if ( now < (self.walkHeadingTime or 0) ) then return self.walkHeading end

    local toPoint = point - self:GetPos()
    toPoint.z = 0

    self.walkHeading = self:GetClearHeading(toPoint:Angle().y, toPoint:Length())
    self.walkHeadingTime = now + WALK_HEADING_INTERVAL

    return self.walkHeading
end

--- Walks towards a point around the walls in the way, facing a heading of its own or the way it walks.
---@param point Vector
---@param faceYaw number|nil Heading to face, or nil to face the way it walks.
---@param bBoost boolean Whether to run.
---@return boolean bMoving Whether a way was free.
function ENT:WalkTowards(point, faceYaw, bBoost)
    local heading = self:GetWalkHeading(point)

    if ( !heading ) then
        self:SetSteerTo(faceYaw or self:GetAngles().y)
        self:SetMove(0, 0)

        return false
    end

    self:SetSteerTo(faceYaw or heading)

    local localYaw = math.rad(math.AngleDifference(heading, self:GetAngles().y))
    self:SetMove(math.cos(localYaw), math.sin(localYaw), bBoost)

    return true
end

--- Returns whether the strider has kept walking for a while without getting anywhere, and starts the next while over when it has got somewhere.
---@return boolean bStuck
function ENT:IsWalkStuck()
    local now = CurTime()
    local pos = self:GetPos()

    if ( !self.walkProgressPos or self.walkProgressPos:Distance2D(pos) > WALK_STUCK_DISTANCE or self:GetMove():IsZero() ) then
        self.walkProgressPos = pos
        self.walkProgressTime = now

        return false
    end

    if ( now - self.walkProgressTime < WALK_STUCK_TIME ) then return false end

    self.walkProgressPos = nil

    return true
end

--- Walks to a goal along the navigation mesh and around the walls in the way.
---@param goalPos Vector
---@param faceYaw number|nil Heading to face, or nil to face the way it walks.
---@param bBoost boolean Whether to run.
---@return boolean bMoving Whether a way was free and the strider is not stuck.
function ENT:NavigateTo(goalPos, faceYaw, bBoost)
    local now = CurTime()

    if ( self:IsWalkStuck() ) then
        self:ClearNavRoute()
        self:SetMove(0, 0)

        return false
    end

    if ( !self.navWaypoint or now >= (self.navWaypointTime or 0) ) then
        self.navWaypoint = self:GetNavWaypoint(goalPos)
        self.navWaypointTime = now + WALK_HEADING_INTERVAL
    end

    return self:WalkTowards(self.navWaypoint, faceYaw, bBoost)
end

--- Returns a spot in the open to wander to, from the navigation mesh, or nil when the map has none.
---@return Vector|nil spot
function ENT:FindWanderSpot()
    if ( !navmesh.IsLoaded() ) then return nil end

    local groundPos = self:GetNavGroundPos()
    local areas = navmesh.Find(groundPos, WANDER_MAX_DISTANCE, NAV_CLEAR_HEIGHT, NAV_CLEAR_HEIGHT)
    local count = #areas

    for _ = 1, math.min(count, 24) do
        local area = areas[math.random(count)]
        local center = area:GetCenter()

        if ( center:Distance2D(groundPos) >= WANDER_MIN_DISTANCE and IsAreaClear(area) ) then
            return center
        end
    end

    return nil
end
