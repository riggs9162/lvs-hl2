--- Autopilot of the strider. The original walks along paths and to spots with a line of fire laid out by the map; without them the autopilot finds its way over the navigation mesh to its enemy until it is in range and in sight, faces it while its minigun fires, blasts enemy vehicles with the cannon, skewers enemies that come too close, and wanders while it has no enemy.

--- Distances to its enemy the autopilot keeps between: it walks closer from beyond the far one and backs off within the near one.
local AI_ENGAGE_NEAR = 900
local AI_ENGAGE_FAR = 2500

--- Farthest an enemy vehicle can be for the autopilot to use the cannon on it.
local AI_CANNON_RANGE = 4096

--- Seconds between two alert calls, from CNPC_Strider::AlertSound.
local AI_ALERT_INTERVAL = 2

--- Shortest and longest seconds the autopilot heads for one spot while it wanders, and the distance at which it counts the spot as reached.
local AI_WANDER_TIME_MIN = 8
local AI_WANDER_TIME_MAX = 20
local AI_WANDER_REACHED = 250

--- Distance the autopilot backs off by when its enemy comes too close.
local AI_BACK_OFF_DISTANCE = 600

--- Prepares the autopilot state.
function ENT:InitAI()
    self.aiNextAlert = 0
    self.aiNextWanderTurn = 0
    self.aiWanderSpot = nil
    self:ClearNavRoute()
end

--- Returns the enemy the autopilot's minigun is after, or nil.
---@return Entity|nil target
function ENT:GetMinigunAITarget()
    local target = self:AIGetTarget()
    if ( !IsValid(target) ) then return nil end

    return target
end

--- Calls out when the autopilot spots a new enemy, from CNPC_Strider::AlertSound.
---@param target Entity
function ENT:AlertAI(target)
    if ( target == self.aiLastTarget ) then return end

    self.aiLastTarget = target

    local now = CurTime()
    if ( now < self.aiNextAlert ) then return end

    self.aiNextAlert = now + AI_ALERT_INTERVAL
    self:EmitSound("NPC_Strider.Alert")
end

--- Wanders without an enemy, as the original walks its paths: heads for a spot in the open picked from the navigation mesh, or straight on without one, and walks around the walls in the way.
function ENT:RunAIWander()
    local now = CurTime()
    local pos = self:GetPos()
    local spot = self.aiWanderSpot

    if ( !spot or now > self.aiNextWanderTurn or spot:Distance2D(pos) < AI_WANDER_REACHED ) then
        spot = self:FindNavWanderSpot() or pos + Angle(0, self:GetAngles().y + math.Rand(-90, 90), 0):Forward() * 2000
        self.aiWanderSpot = spot
        self.aiNextWanderTurn = now + math.Rand(AI_WANDER_TIME_MIN, AI_WANDER_TIME_MAX)
        self:ClearNavRoute()
    end

    if ( !self:NavigateTo(spot, nil, false) ) then
        self.aiWanderSpot = nil
    end

    self:SetAIAimVector(self:GetForward())
end

--- Fights an enemy: runs closer along the navigation mesh while it is out of range or out of sight as the original chases, walks back while it is too close, keeps it in front, lets the minigun fire at it, uses the cannon on vehicles and skewers it when it comes within reach.
---@param target Entity
function ENT:RunAIAttack(target)
    local pos = self:GetPos()
    local toTarget = target:GetPos() - pos
    local distance = toTarget:Length2D()
    local targetYaw = toTarget:Angle().y
    local bCanSee = self:AICanSee(target)

    if ( distance > AI_ENGAGE_FAR or !bCanSee ) then
        self:NavigateTo(target:GetPos(), bCanSee and targetYaw or nil, distance > AI_ENGAGE_FAR)
    elseif ( distance < AI_ENGAGE_NEAR ) then
        self:ClearNavRoute()
        self:WalkTowards(pos - toTarget:GetNormalized() * AI_BACK_OFF_DISTANCE, targetYaw, false)
    else
        self:ClearNavRoute()
        self:SetSteerTo(targetYaw)
        self:SetMove(0, 0)
    end

    self:SetAIAimVector((target:WorldSpaceCenter() - pos):GetNormalized())

    if ( target.LVS and distance < AI_CANNON_RANGE and bCanSee and self:CanFireCannon() ) then
        self:StartCannonCharge(target)

        return
    end

    if ( target:IsNPC() and self:CanStomp() ) then
        local spike = self:GetStriderAttachment("left skewer")

        if ( spike and target:GetPos():Distance(spike.Pos) < 260 ) then
            self:StartStomp()
        end
    end
end

--- Runs the autopilot.
function ENT:RunAI()
    if ( self:GetCarryingDropship() or self:IsStomping() ) then
        self:SetMove(0, 0)

        return
    end

    local target = self:AIGetTarget()

    if ( !IsValid(target) ) then
        self.aiLastTarget = nil
        self:RunAIWander()

        return
    end

    self:AlertAI(target)
    self:RunAIAttack(target)
end
