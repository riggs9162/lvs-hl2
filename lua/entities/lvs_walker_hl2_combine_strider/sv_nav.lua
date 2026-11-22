--- Navigation of the strider's autopilot, on the shared ground navigation (lvs_hl2/sv_ground_nav.lua). It keeps to open areas a walker of its size fits through, leaving out those under a roof, and checks the way ahead for walls at the height of its body only: its legs step over and around anything lower, such as cars, fences and street lamps, which stand between its feet.

include("lvs_hl2/sv_ground_nav.lua")

--- Size of the strider for the navigation: the free height its body needs above an area, the steps its legs take, and the way ahead checked at the height of its body.
ENT.NavProfile = {
    clearHeight = 560,
    clearRadius = 32,
    maxClimb = 160,
    avoidAttributes = 0,
    probeHeights = {420},
    probeRadius = 64,
    probeDistance = 500,
    waypointRadius = 180,
    wanderMin = 1200,
    wanderMax = 4000,
}

--- Returns where the strider's feet stand, below the middle of its body.
---@return Vector groundPos
function ENT:GetNavGroundPos()
    local pos = self:GetPos()

    return Vector(pos.x, pos.y, self.groundZ or pos.z - self.StandHeight)
end

--- Walks towards a point around the walls in the way, facing a heading of its own or the way it walks.
---@param point Vector
---@param faceYaw number|nil Heading to face, or nil to face the way it walks.
---@param bBoost boolean Whether to run.
---@return boolean bMoving Whether a way was free.
function ENT:WalkTowards(point, faceYaw, bBoost)
    local heading = self:GetNavHeading(point)

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

--- Walks to a goal along the navigation mesh and around the walls in the way, and gives up on the route when it gets stuck.
---@param goalPos Vector
---@param faceYaw number|nil Heading to face, or nil to face the way it walks.
---@param bBoost boolean Whether to run.
---@return boolean bMoving Whether a way was free and the strider is not stuck.
function ENT:NavigateTo(goalPos, faceYaw, bBoost)
    if ( self:IsNavStuck(!self:GetMove():IsZero()) ) then
        self:ClearNavRoute()
        self:SetMove(0, 0)

        return false
    end

    local point = self:GetNavMoveTarget(goalPos)

    if ( !point ) then
        self:SetSteerTo(faceYaw or self:GetAngles().y)
        self:SetMove(0, 0)

        return false
    end

    return self:WalkTowards(point, faceYaw, bBoost)
end
