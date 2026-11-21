--- Client side animation of the gunship's body, run on every frame so that the head, fins and antennas move smoothly: the head as in CNPC_CombineGunship::MoveHead, the fins as at the end of CNPC_CombineGunship::Flight.

--- Push of the rotor at which the fins are bent all the way, in the original's units per think.
local FIN_FULL_FORCE = 60

--- Share of their full bend the fins move per second, half of it on every original think.
local FIN_RATE = 5

--- Downward push of gravity per original think.
local GRAVITY_PER_TICK = 38.4

--- Rate per second at which the antennas follow the gunship's movement.
local ANTENNA_FOLLOW_RATE = 10

--- Bend of the antennas per unit of forward and sideways speed.
local ANTENNA_SPEED_SCALE = 0.005

--- Rate per second at which the measured turning of the gunship settles, which hides the jitter of the network.
local TURN_RATE_SMOOTHING = 10

--- Eases a value into the range of -1 to 1 along an S-curve, from SimpleSplineRemapVal with a range of -FIN_FULL_FORCE to FIN_FULL_FORCE.
---@param value number
---@return number blend
local function FinBlend(value)
    local fraction = math.Clamp((value + FIN_FULL_FORCE) / (2 * FIN_FULL_FORCE), 0, 1)

    return -1 + 2 * fraction * fraction * (3 - 2 * fraction)
end

--- Returns the point the head looks at: the local pilot's own crosshair, or the target the server reports.
---@return Vector|nil targetPos
function ENT:GetClientHeadTarget()
    if ( self:GetDriver() == LocalPlayer() ) then return self:GetEyeTrace().HitPos end

    local targetPos = self:GetHeadTarget()
    if ( targetPos:IsZero() ) then return nil end

    return targetPos
end

--- Measures how fast the gunship pitches and yaws, from the change of its angles since the last frame.
---@param deltatime number
---@return Vector turnRate Pitch and yaw rate in degrees per second, as y and z.
function ENT:GetClientTurnRate(deltatime)
    local angles = self:GetAngles()
    local last = self.lastBodyAngles or angles
    local change = self:WorldToLocalAngles(last)
    local measured = Vector(0, -change.p / deltatime, -change.y / deltatime)

    self.lastBodyAngles = angles
    self.clientTurnRate = LerpVector(math.min(TURN_RATE_SMOOTHING * deltatime, 1), self.clientTurnRate or measured, measured)

    return self.clientTurnRate
end

--- Moves the head, fins and antennas one frame on.
---@param deltatime number
function ENT:StepBodyAnimation(deltatime)
    local anim = self.bodyAnim

    self:TurnHead(anim.head, self:GetBodyAttachment("muzzle"), self:GetClientHeadTarget(), self:GetClientTurnRate(deltatime), deltatime)

    local force = self:GetRotorForce()
    local impulse = self:GetUp() * force
    impulse.z = impulse.z - GRAVITY_PER_TICK

    local accelDir = impulse:GetNormalized()
    local velocity = self:GetVelocity()
    local velocityDir = velocity:GetNormalized()
    local right = self:GetRight()

    accelDir.z = 0
    velocityDir.z = 0
    right.z = 0

    anim.finAccel = math.Approach(anim.finAccel, FinBlend(force * velocityDir:Dot(accelDir)), FIN_RATE * deltatime)
    anim.finSway = math.Approach(anim.finSway, FinBlend(force * velocityDir:Dot(right)), FIN_RATE * deltatime)

    local localVelocity = self:WorldToLocal(self:GetPos() + velocity)

    anim.antennaVelocity = LerpVector(math.min(ANTENNA_FOLLOW_RATE * deltatime, 1), anim.antennaVelocity, localVelocity)
end

--- Animates the body once per frame and sets its pose parameters, which replace the ones the server sends for its own aiming.
---@param body Entity
function ENT:AnimateBody(body)
    self.bodyAnim = self.bodyAnim or {
        head = {yaw = 0, pitch = 0},
        finAccel = 0,
        finSway = 0,
        antennaVelocity = Vector(0, 0, 0),
    }

    local frame = FrameNumber()
    local deltatime = FrameTime()

    local anim = self.bodyAnim

    if ( self.bodyAnimFrame != frame and deltatime > 0 ) then
        self.bodyAnimFrame = frame
        self:PoseHead(body, anim.head)
        body:InvalidateBoneCache()
        self:StepBodyAnimation(deltatime)
    end

    self:PoseHead(body, anim.head)
    body:SetPoseParameter("fin_accel", anim.finAccel)
    body:SetPoseParameter("fin_sway", anim.finSway)
    body:SetPoseParameter("antenna_accel", anim.antennaVelocity.x * ANTENNA_SPEED_SCALE)
    body:SetPoseParameter("antenna_sway", -anim.antennaVelocity.y * ANTENNA_SPEED_SCALE)
    body:InvalidateBoneCache()
end
