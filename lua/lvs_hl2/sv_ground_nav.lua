--- Navigation shared by the autopilots of the Half-Life 2 ground vehicles and walkers. An entity that includes this file plans its routes over the map's navigation mesh, keeping to the areas it fits through, checks the way ahead for walls and turns around them, notices when it is stuck, and picks spots to wander to. Without a navigation mesh it still steers around the walls in front of it.
---
--- An entity describes its size with an ENT.NavProfile table; anything left out is worked out from its collision bounds. The autopilot then asks GetNavMoveTarget or GetNavWaypoint and GetNavHeading where to go next, and drives there its own way.

---@class lvsHL2NavProfile
---@field clearHeight number|nil Free height above an area the entity needs, so that it stays out from under roofs and out of tunnels too low for it.
---@field clearRadius number|nil Half width of the column checked for that free height, so that it stays out of passages too narrow for it.
---@field maxClimb number|nil Highest step up between two areas it can take.
---@field avoidAttributes number|nil NAV_MESH_ attributes of areas it never enters, such as stairs for wheeled vehicles.
---@field probeHeights number[]|nil Heights above the ground the way ahead is checked for walls at.
---@field probeRadius number|nil Half width of the box the way ahead is checked with.
---@field probeDistance number|nil Farthest ahead the way is checked.
---@field waypointRadius number|nil Distance at which a waypoint counts as reached.
---@field wanderMin number|nil Shortest distance of a spot to wander to.
---@field wanderMax number|nil Longest distance of a spot to wander to.

--- Seconds between two plans of a route, and the distance the goal may move before the route is planned again sooner.
local NAV_REPLAN_INTERVAL = 2
local NAV_GOAL_MOVED = 400

--- Most areas the planner looks at for one route, so that a route across a large map does not stall the server.
local NAV_MAX_EXPANSIONS = 3000

--- Farthest a start or a goal may be from the navigation mesh for the planner to use it.
local NAV_SNAP_DISTANCE = 600

--- Most waypoints looked past for a straight way to a later one on one update.
local NAV_SHORTCUT_CHECKS = 3

--- Turns off the wanted heading tried, in order, when the way ahead is blocked.
local NAV_DETOURS = {0, 30, -30, 60, -60, 90, -90, 120, -120}

--- Seconds a waypoint and a heading found free are kept before the way is checked again.
local NAV_UPDATE_INTERVAL = 0.2

--- Seconds the entity may try to move without getting this far before it counts as stuck.
local NAV_STUCK_TIME = 4
local NAV_STUCK_DISTANCE = 60

--- Smallest upward slant of a surface the way-ahead check takes for ground to drive or walk up rather than a wall.
local NAV_GROUND_NORMAL_Z = 0.6

--- Farthest below the entity the ground is looked for.
local NAV_GROUND_REACH = 1000

--- Most areas tried when picking a spot to wander to.
local NAV_WANDER_TRIES = 24

--- How many times longer a way through an area under a roof counts, so that routes keep to the open and only pass through tunnels and under bridges when there is no other way, and the height the sky is looked for up to.
local NAV_COVERED_COST = 4
local NAV_SKY_REACH = 8192

--- Whether each navigation area, by its id, lies under the open sky.
local areaOpenSky = {}

--- Whether each navigation area, by its id, has room for an entity of a size, by the size's key.
local areaClearance = {}

--- Returns the cache of area clearances for a profile.
---@param profile table
---@return table cache
local function GetClearanceCache(profile)
    local key = profile.key
    local cache = areaClearance[key]

    if ( !cache ) then
        cache = {}
        areaClearance[key] = cache
    end

    return cache
end

--- Returns whether an entity of a profile fits into a navigation area: not one of the kinds it avoids, not under water, and nothing solid in a column of its height and width above the area's centre.
---@param area CNavArea
---@param profile table
---@return boolean bClear
local function IsAreaClear(area, profile)
    local cache = GetClearanceCache(profile)
    local id = area:GetID()
    local cached = cache[id]
    if ( cached != nil ) then return cached end

    local bClear = !area:IsUnderwater() and ( profile.avoidAttributes == 0 or !area:HasAttributes(profile.avoidAttributes) )

    if ( bClear ) then
        local center = area:GetCenter()
        local radius = profile.clearRadius
        local trace = util.TraceHull({
            start = center + Vector(0, 0, 24),
            endpos = center + Vector(0, 0, profile.clearHeight),
            mins = Vector(-radius, -radius, 0),
            maxs = Vector(radius, radius, 1),
            mask = MASK_NPCSOLID_BRUSHONLY,
        })

        bClear = !trace.Hit
    end

    cache[id] = bClear

    return bClear
end

--- Returns whether a navigation area lies under the open sky rather than under a roof, a bridge or in a building.
---@param area CNavArea
---@return boolean bOpen
local function IsAreaOpenSky(area)
    local id = area:GetID()
    local cached = areaOpenSky[id]
    if ( cached != nil ) then return cached end

    local center = area:GetCenter()
    local trace = util.TraceLine({
        start = center + Vector(0, 0, 32),
        endpos = center + Vector(0, 0, NAV_SKY_REACH),
        mask = MASK_NPCSOLID_BRUSHONLY,
    })

    local bOpen = !trace.Hit or trace.HitSky
    areaOpenSky[id] = bOpen

    return bOpen
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

--- Returns the route from one area to another as the areas' centres, or towards the reachable area closest to the goal when the goal itself cannot be reached. Ways under a roof count as longer, so that the route keeps to the open where it can.
---@param startArea CNavArea
---@param goalArea CNavArea
---@param goalPos Vector
---@param profile table
---@return table|nil points
local function PlanRoute(startArea, goalArea, goalPos, profile)
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

                if ( !closed[neighborId] and area:ComputeAdjacentConnectionHeightChange(neighbor) <= profile.maxClimb and IsAreaClear(neighbor, profile) ) then
                    local cost = costSoFar[id] + center:Distance(neighbor:GetCenter()) * (IsAreaOpenSky(neighbor) and 1 or NAV_COVERED_COST)

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

--- Returns the entity's navigation profile: its ENT.NavProfile with everything left out worked out from its collision bounds.
---@return table profile
function ENT:GetNavProfile()
    local profile = self.navProfile
    if ( profile ) then return profile end

    local overrides = self.NavProfile or {}
    local mins, maxs = self:OBBMins(), self:OBBMaxs()
    local size = maxs - mins
    local halfWidth = math.min(size.x, size.y) * 0.5
    local height = size.z

    profile = {
        clearHeight = overrides.clearHeight or height + 16,
        clearRadius = overrides.clearRadius or math.Clamp(halfWidth * 0.75, 16, 96),
        maxClimb = overrides.maxClimb or 40,
        avoidAttributes = overrides.avoidAttributes or bit.bor(NAV_MESH_JUMP, NAV_MESH_CROUCH, NAV_MESH_STAIRS),
        probeHeights = overrides.probeHeights or {math.max(height * 0.5, 32)},
        probeRadius = overrides.probeRadius or math.Clamp(halfWidth * 0.8, 16, 128),
        probeDistance = overrides.probeDistance or 500,
        waypointRadius = overrides.waypointRadius or math.max(halfWidth * 2, 150),
        wanderMin = overrides.wanderMin or 1200,
        wanderMax = overrides.wanderMax or 4000,
    }

    profile.key = string.format("%d_%d_%d_%d", profile.clearHeight, profile.clearRadius, profile.maxClimb, profile.avoidAttributes)
    self.navProfile = profile

    return profile
end

--- Returns where the entity stands on the ground, below the middle of its body.
---@return Vector groundPos
function ENT:GetNavGroundPos()
    local center = self:WorldSpaceCenter()
    local trace = util.TraceLine({
        start = center,
        endpos = center - Vector(0, 0, NAV_GROUND_REACH),
        mask = MASK_NPCSOLID_BRUSHONLY,
        filter = self:GetCrosshairFilterEnts(),
    })

    return trace.HitPos
end

--- Returns whether the entity can go straight from where it stands to a point: no wall in its way. Ground it would drive or walk up does not count, and neither does a check that starts inside something.
---@param point Vector
---@return boolean bClear
function ENT:IsNavPathClear(point)
    local profile = self:GetNavProfile()
    local groundPos = self:GetNavGroundPos()
    local target = Vector(point.x, point.y, groundPos.z)
    local radius = profile.probeRadius
    local mins = Vector(-radius, -radius, 0)
    local maxs = Vector(radius, radius, radius)

    for _, height in ipairs(profile.probeHeights) do
        local offset = Vector(0, 0, height)
        local trace = util.TraceHull({
            start = groundPos + offset,
            endpos = target + offset,
            mins = mins,
            maxs = maxs,
            mask = MASK_NPCSOLID_BRUSHONLY,
        })

        if ( trace.Hit and !trace.StartSolid and trace.HitNormal.z < NAV_GROUND_NORMAL_Z ) then return false end
    end

    return true
end

--- Returns the heading closest to the one wanted that is free of walls for a while ahead, or nil when every way is blocked.
---@param yaw number Heading wanted.
---@param distance number Distance ahead to check, at most the profile's probe distance.
---@return number|nil yaw
function ENT:GetNavClearHeading(yaw, distance)
    local profile = self:GetNavProfile()
    local groundPos = self:GetNavGroundPos()
    local probe = math.Clamp(distance, profile.probeRadius, profile.probeDistance)

    for _, detour in ipairs(NAV_DETOURS) do
        local heading = yaw + detour

        if ( self:IsNavPathClear(groundPos + Angle(0, heading, 0):Forward() * probe) ) then
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
    self.navHeadingTime = 0
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

    return PlanRoute(startArea, goalArea, goalPos, self:GetNavProfile())
end

--- Returns the next point to go to on the way to a goal: the goal itself while the way there is clear, otherwise the next waypoint of a route over the navigation mesh, planned again now and then and whenever the goal moves away. Also returns whether that point is the goal.
---@param goalPos Vector
---@return Vector point
---@return boolean bGoal
function ENT:GetNavWaypoint(goalPos)
    if ( self:IsNavPathClear(goalPos) ) then
        self.navRoute = nil

        return goalPos, true
    end

    local now = CurTime()

    if ( !self.navRoute or now >= (self.navNextPlan or 0) or !self.navGoal or self.navGoal:Distance(goalPos) > NAV_GOAL_MOVED ) then
        self.navRoute = self:PlanNavRoute(goalPos)
        self.navIndex = 1
        self.navGoal = goalPos
        self.navNextPlan = now + NAV_REPLAN_INTERVAL * math.Rand(0.8, 1.2)
    end

    local route = self.navRoute
    if ( !route ) then return goalPos, true end

    local groundPos = self:GetNavGroundPos()
    local reach = self:GetNavProfile().waypointRadius

    while ( self.navIndex < #route and groundPos:Distance2D(route[self.navIndex]) < reach ) do
        self.navIndex = self.navIndex + 1
    end

    for _ = 1, NAV_SHORTCUT_CHECKS do
        if ( self.navIndex >= #route or !self:IsNavPathClear(route[self.navIndex + 1]) ) then break end

        self.navIndex = self.navIndex + 1
    end

    return route[self.navIndex], self.navIndex == #route and route[#route] == goalPos
end

--- Returns the heading towards a point around the walls in the way, or nil when every way is blocked. The way is checked again only now and then, because each check traces several times.
---@param point Vector
---@return number|nil yaw
function ENT:GetNavHeading(point)
    local now = CurTime()
    if ( now < (self.navHeadingTime or 0) ) then return self.navHeading end

    local toPoint = point - self:GetPos()
    toPoint.z = 0

    self.navHeading = self:GetNavClearHeading(toPoint:Angle().y, toPoint:Length())
    self.navHeadingTime = now + NAV_UPDATE_INTERVAL

    return self.navHeading
end

--- Returns the point to head for on the way to a goal, along the route and around the walls in the way, kept for a moment between checks. Returns nil when every way is blocked, and also whether the point is on the way straight to the goal.
---@param goalPos Vector
---@return Vector|nil point
---@return boolean bGoal
function ENT:GetNavMoveTarget(goalPos)
    local now = CurTime()

    if ( !self.navWaypoint or now >= (self.navWaypointTime or 0) ) then
        self.navWaypoint, self.bNavWaypointGoal = self:GetNavWaypoint(goalPos)
        self.navWaypointTime = now + NAV_UPDATE_INTERVAL
    end

    local waypoint = self.navWaypoint
    local heading = self:GetNavHeading(waypoint)
    if ( !heading ) then return nil, false end

    local pos = self:GetPos()
    local distance = pos:Distance2D(waypoint)
    local point = pos + Angle(0, heading, 0):Forward() * distance
    point.z = waypoint.z

    return point, self.bNavWaypointGoal == true
end

--- Returns whether the entity has been trying to move for a while without getting anywhere, and starts the next while over when it has got somewhere or stopped trying.
---@param bTrying boolean Whether the entity tries to move right now.
---@return boolean bStuck
function ENT:IsNavStuck(bTrying)
    local now = CurTime()
    local pos = self:GetPos()

    if ( !bTrying or !self.navProgressPos or self.navProgressPos:Distance2D(pos) > NAV_STUCK_DISTANCE ) then
        self.navProgressPos = pos
        self.navProgressTime = now

        return false
    end

    if ( now - self.navProgressTime < NAV_STUCK_TIME ) then return false end

    self.navProgressPos = nil

    return true
end

--- Returns a spot to wander to from the navigation mesh, one in the open that the entity fits into, or nil when the map has none.
---@return Vector|nil spot
function ENT:FindNavWanderSpot()
    if ( !navmesh.IsLoaded() ) then return nil end

    local profile = self:GetNavProfile()
    local groundPos = self:GetNavGroundPos()
    local areas = navmesh.Find(groundPos, profile.wanderMax, profile.clearHeight, profile.clearHeight)
    local count = #areas

    for _ = 1, math.min(count, NAV_WANDER_TRIES) do
        local area = areas[math.random(count)]
        local center = area:GetCenter()

        if ( center:Distance2D(groundPos) >= profile.wanderMin and IsAreaClear(area, profile) and IsAreaOpenSky(area) ) then
            return center
        end
    end

    return nil
end
