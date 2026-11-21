--- Autopilot of the strider. The original walks along paths and to spots with a line of fire laid out by the map; without them the autopilot walks towards its enemy until it is in range, faces it while its minigun fires, blasts enemy vehicles with the cannon, skewers enemies that come too close, and wanders while it has no enemy.

--- Distances to its enemy the autopilot keeps between: it walks closer from beyond the far one and backs off within the near one.
local AI_ENGAGE_NEAR = 900
local AI_ENGAGE_FAR = 2500

--- Farthest an enemy vehicle can be for the autopilot to use the cannon on it.
local AI_CANNON_RANGE = 4096

--- Seconds between two alert calls, from CNPC_Strider::AlertSound.
local AI_ALERT_INTERVAL = 2

--- Distance ahead of the body the autopilot looks for walls in while it wanders.
local AI_WALL_PROBE = 600

--- Shortest and longest seconds the autopilot keeps its heading while it wanders.
local AI_WANDER_TIME_MIN = 4
local AI_WANDER_TIME_MAX = 10

--- Prepares the autopilot state.
function ENT:InitAI()
    self.aiNextAlert = 0
    self.aiNextWanderTurn = 0
    self.aiWanderYaw = nil
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

--- Wanders without an enemy: walks along, turning now and then or when the body is about to walk into a wall, as the original walks its paths.
function ENT:RunAIWander()
    local now = CurTime()
    local pos = self:GetPos()
    local wall = util.TraceLine({
        start = pos,
        endpos = pos + self:GetForward() * AI_WALL_PROBE,
        mask = MASK_SOLID_BRUSHONLY,
    })

    if ( !self.aiWanderYaw or now > self.aiNextWanderTurn or wall.Hit ) then
        self.aiWanderYaw = self:GetAngles().y + math.Rand(90, 270) * (wall.Hit and 1 or math.Rand(-0.5, 0.5))
        self.aiNextWanderTurn = now + math.Rand(AI_WANDER_TIME_MIN, AI_WANDER_TIME_MAX)
    end

    self:SetSteerTo(self.aiWanderYaw)
    self:SetMove(1, 0, false)
    self:SetAIAimVector(self:GetForward())
end

--- Fights an enemy: runs closer while it is out of range as the original chases, walks back while it is too close, keeps it in front, lets the minigun fire at it, uses the cannon on vehicles and skewers it when it comes within reach.
---@param target Entity
function ENT:RunAIAttack(target)
    local pos = self:GetPos()
    local toTarget = target:GetPos() - pos
    local distance = toTarget:Length2D()
    local move = 0

    if ( distance > AI_ENGAGE_FAR ) then
        move = 1
    elseif ( distance < AI_ENGAGE_NEAR ) then
        move = -1
    end

    self:SetSteerTo(toTarget:Angle().y)
    self:SetMove(move, 0, move > 0)
    self:SetAIAimVector((target:WorldSpaceCenter() - pos):GetNormalized())

    if ( target.LVS and distance < AI_CANNON_RANGE and self:CanFireCannon() and self:AICanSee(target) ) then
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
