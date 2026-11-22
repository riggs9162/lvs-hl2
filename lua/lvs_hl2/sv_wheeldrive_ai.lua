--- Autopilot of the Half-Life 2 wheeled vehicles: the LVS wheeldrive autopilot, with its driving, aiming and weapon choice, finding its way over the navigation mesh (lvs_hl2/sv_ground_nav.lua) instead of driving straight at its goal. It keeps to areas the vehicle fits through and stays off stairs, steers around walls, slows down for corners, backs up and tries another way when it gets stuck, and wanders between spots on the mesh while it has no enemy.

include("lvs_hl2/sv_ground_nav.lua")

--- Distance the autopilot stops short of an enemy's spot, as the LVS autopilot does, and short of a spot it wanders to.
local AI_FIGHT_STOP_DISTANCE = 500
local AI_WANDER_STOP_DISTANCE = 150

--- Farthest from its enemy an armed autopilot keeps, and the shortest and longest seconds it keeps one spot to fight from.
local AI_FIGHT_RANGE = 2000
local AI_FIGHT_SPOT_TIME_MIN = 4
local AI_FIGHT_SPOT_TIME_MAX = 8

--- Shortest and longest seconds the autopilot heads for one spot while it wanders, and the distance at which it counts the spot as reached.
local AI_WANDER_TIME_MIN = 10
local AI_WANDER_TIME_MAX = 25
local AI_WANDER_REACHED = 400

--- Seconds the autopilot backs up for once it is stuck, and how far behind it the point it backs up towards lies.
local AI_REVERSE_TIME = 2.5
local AI_REVERSE_DISTANCE = 1000

--- Farthest behind the vehicle a point may be for the autopilot to back up to it; it turns around for anything farther.
local AI_REVERSE_REACH = 400

--- Throttle the autopilot keeps in the sharpest corners, and the turn in degrees from which it slows down the most.
local AI_CORNER_THROTTLE = 0.35
local AI_CORNER_ANGLE = 90

--- Vehicle types the autopilot does not chase when it can turn on the spot, but turns to face instead.
local AI_DONT_CHASE = {
    starfighter = true,
    repulsorlift = true,
    plane = true,
    helicopter = true,
}

--- Returns the heading the vehicle drives forwards in.
---@param pod Entity Driver seat.
---@return number yaw
local function GetDriveYaw(pod)
    return pod:GetAngles().y + 90
end

--- Returns where the autopilot fights an enemy from: an armed vehicle keeps its distance at a spot it picks now and then, an unarmed one drives right at the enemy, as the LVS autopilot does. An enemy out of sight is looked for where it is.
---@param target Entity
---@return Vector goalPos
function ENT:GetAIFightGoal(target)
    local targetPos = target:GetPos()
    if ( !self:AIHasWeapon(1) or !self:AICanSee(target) ) then return targetPos end

    local now = CurTime()
    if ( self.aiFightSpot and now < self.aiFightSpotTime ) then return self.aiFightSpot end

    local away = self:GetPos() - targetPos

    self.aiFightSpot = targetPos + away:GetNormalized() * math.min(AI_FIGHT_RANGE, away:Length())
    self.aiFightSpotTime = now + math.Rand(AI_FIGHT_SPOT_TIME_MIN, AI_FIGHT_SPOT_TIME_MAX)

    return self.aiFightSpot
end

--- Returns the spot the autopilot wanders to: one on the navigation mesh, or a free way ahead without one, picked again once it is reached, after a while or when the vehicle got stuck on the way.
---@param pod Entity Driver seat.
---@return Vector goalPos
function ENT:GetAIWanderGoal(pod)
    local now = CurTime()
    local spot = self.aiWanderSpot

    if ( !spot or now > (self.aiWanderTime or 0) or spot:Distance2D(self:GetPos()) < AI_WANDER_REACHED ) then
        local yaw = GetDriveYaw(pod) + math.Rand(-60, 60)

        spot = self:FindNavWanderSpot() or self:GetPos() + Angle(0, yaw, 0):Forward() * self:GetNavProfile().wanderMin
        self.aiWanderSpot = spot
        self.aiWanderTime = now + math.Rand(AI_WANDER_TIME_MIN, AI_WANDER_TIME_MAX)
        self:ClearNavRoute()
    end

    return spot
end

--- Returns the point the autopilot drives to on this tick, how far short of it it stops and whether it backs up: it backs up while it frees itself, and otherwise drives to the next point on the way to its goal, around the walls in the way.
---@param pod Entity Driver seat.
---@param goalPos Vector
---@param goalStopDistance number Distance to stop short of the goal itself.
---@return Vector drivePos
---@return number stopDistance
---@return boolean bBackUp
function ENT:GetAIDrivePoint(pod, goalPos, goalStopDistance)
    local now = CurTime()
    local behind = pod:LocalToWorld(pod:OBBCenter()) - Angle(0, GetDriveYaw(pod), 0):Forward() * AI_REVERSE_DISTANCE

    if ( now < (self.aiReverseTime or 0) ) then return behind, 0, true end

    if ( self:IsNavStuck(self:GetThrottle() > 0.1) ) then
        self.aiReverseTime = now + AI_REVERSE_TIME
        self.aiWanderSpot = nil
        self:ClearNavRoute()

        return behind, 0, true
    end

    local point, bGoal = self:GetNavMoveTarget(goalPos)
    if ( !point ) then return behind, 0, true end

    return point, bGoal and goalStopDistance or 0, false
end

--- Starts the engine while the autopilot wanders, unless it is destroyed, as the LVS autopilot does.
function ENT:KeepAIEngineRunning()
    if ( self:GetEngineActive() ) then return end

    local engine = self:GetEngine()
    if ( IsValid(engine) and engine:GetDestroyed() ) then return end

    self:StartEngine()
end

--- Turns on the spot to face the aim, for vehicles that can, as the LVS autopilot does while it holds still.
---@param pod Entity Driver seat.
function ENT:PivotAITowardsAim(pod)
    local angles = self:GetAngles()
    angles.y = pod:GetAngles().y + 90

    local steer = math.Clamp((self:AngleBetweenNormal(self:GetAimVector(), angles:Right()) - 90) / 10, -1, 1)
    local throttle = math.abs(steer) ^ 2

    if ( throttle < 0.1 ) then
        throttle = 0
        steer = 0
    end

    self:SetSteer(0)
    self:SetPivotSteer(-steer)
    self:LerpThrottle(throttle)
    self:LerpBrake(0)
end

--- Drives towards a point, slowing down for corners and braking once it is there, as the LVS autopilot drives. It backs up only to free itself or to a point close behind it, and turns around for anything farther.
---@param pod Entity Driver seat.
---@param drivePos Vector
---@param stopDistance number
---@param bBackUp boolean Whether to back up to the point.
---@param target Entity|nil Enemy of the autopilot.
function ENT:DriveAITowards(pod, drivePos, stopDistance, bBackUp, target)
    local localPos = pod:WorldToLocal(drivePos)
    local throttle = math.min(math.max(localPos:Length() - stopDistance, 0) / 10, 1)
    local bPivot = self.PivotSteerEnable
    local bHold = bPivot and throttle == 0

    if ( bPivot and IsValid(target) and target.LVS and target.GetVehicleType and AI_DONT_CHASE[target:GetVehicleType()] ) then
        bHold = true
    end

    self:PhysWake()

    if ( bHold ) then
        self:PivotAITowardsAim(pod)

        return
    end

    local bReverse = localPos.y < 0 and ( bBackUp or localPos:Length() < AI_REVERSE_REACH )

    if ( !bReverse ) then
        local toPoint = drivePos - self:GetPos()
        local turn = math.abs(math.AngleDifference(toPoint:Angle().y, GetDriveYaw(pod)))

        throttle = throttle * Lerp(math.min(turn / AI_CORNER_ANGLE, 1), 1, AI_CORNER_THROTTLE)
    end

    self:SetPivotSteer(0)

    if ( self:IsLegalInput() ) then
        self:LerpThrottle(throttle)
        self:LerpBrake(throttle == 0 and 1 or 0)
    else
        self:LerpThrottle(0)
        self:LerpBrake(throttle)
    end

    self:SetReverse(bReverse)
    self:ApproachTargetAngle(pod:LocalToWorldAngles((drivePos - self:GetPos()):Angle()))
end

--- Aims at the enemy and picks the weapon to fire with, as the LVS autopilot does.
---@param pod Entity Driver seat.
---@param target Entity|nil Enemy of the autopilot.
---@param aimPos Vector Point to aim at without an enemy.
function ENT:AimAIWeapons(pod, target, aimPos)
    self._AIFireInput = false

    local lockTarget = self:GetHardLockTarget()

    if ( IsValid(lockTarget) ) then
        target = lockTarget
        aimPos = lockTarget:LocalToWorld(lockTarget:OBBCenter())
        self._AIFireInput = true
    elseif ( IsValid(target) ) then
        local phys = target:GetPhysicsObject()
        aimPos = IsValid(phys) and target:LocalToWorld(phys:GetMassCenter()) or target:LocalToWorld(target:OBBCenter())

        if ( self:AIHasWeapon(1) or self:AIHasWeapon(2) ) then
            self._AIFireInput = true
        end

        local heat = self:GetNWHeat()
        local weapon = self:GetSelectedWeapon()

        if ( weapon > 2 ) then
            self:AISelectWeapon(1)
        elseif ( heat < 0.9 ) then
            if ( weapon == 1 and self:AIHasWeapon(2) ) then
                self:AISelectWeapon(2)
            elseif ( weapon == 2 ) then
                self:AISelectWeapon(1)
            end
        elseif ( heat == 0 and math.cos(CurTime()) > 0 ) then
            self:AISelectWeapon(1)
        end
    end

    local sway = CurTime() + self:EntIndex() * 1.337
    local startPos = pod:LocalToWorld(pod:OBBCenter())

    self:SetAIAimVector((aimPos + Vector(0, math.sin(sway * 0.5) * 30, math.cos(sway * 2) * 30) - startPos):GetNormalized())
end

--- Runs the autopilot: picks a goal, the enemy or a spot to wander to, finds its way there over the navigation mesh, drives and fights.
function ENT:RunAI()
    local pod = self:GetDriverSeat()

    if ( !IsValid(pod) ) then
        self:SetAI(false)

        return
    end

    local target = self:AIGetTarget(180)
    local goalPos, goalStopDistance

    if ( IsValid(target) ) then
        goalPos = self:GetAIFightGoal(target)
        goalStopDistance = AI_FIGHT_STOP_DISTANCE
    else
        self:KeepAIEngineRunning()
        goalPos = self:GetAIWanderGoal(pod)
        goalStopDistance = AI_WANDER_STOP_DISTANCE
    end

    local drivePos, stopDistance, bBackUp = self:GetAIDrivePoint(pod, goalPos, goalStopDistance)

    self:DriveAITowards(pod, drivePos, stopDistance, bBackUp, target)
    self:ReleaseHandbrake()
    self:AimAIWeapons(pod, target, goalPos)
end
