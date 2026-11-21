--- Flight model for the hunter-chopper, ported from ComputeVelocity and ComputeAngularVelocity of the Half-Life 2 attack helicopter (npc_attackchopper.cpp) and the drag helpers of its base class (cbasehelicopter.cpp).

--- Gravity the original helicopter flies under, in units per second squared.
local HELICOPTER_GRAVITY = 384

--- Length of one original think tick in seconds, used to convert per-tick factors into rates.
local HELICOPTER_TICK = 0.1

--- Share of the previous rotor force the original keeps on every think tick.
local HELICOPTER_FORCE_BLEND = 0.8

--- Height below the helicopter at which the goal starts to dampen horizontal acceleration.
local HELICOPTER_MIN_DZ_DAMP = -500

--- Height below the helicopter at which horizontal acceleration is fully dampened.
local HELICOPTER_MAX_DZ_DAMP = -1000

--- Speed the autopilot's goal may run ahead of its current speed, in units per second.
local CHOPPER_ACCEL_RATE = 500

--- Smallest cosine of the nose tilt the rotor force is raised for, which caps the extra force at two and a half times the normal one.
local PITCH_LIFT_MIN_COS = 0.4

--- Share of the horizontal acceleration that is added to the rotor force.
local HORIZONTAL_LIFT_FACTOR = 0.1

--- Velocity lost per second along the sideways axis, equal to five percent per think tick.
local SIDEWAYS_DRAG_RATE = 0.05 / HELICOPTER_TICK

--- Velocity lost per second in every direction, equal to half a percent per think tick.
local GENERAL_DRAG_RATE = 0.005 / HELICOPTER_TICK

--- Handling of the autopilot, which keeps the values of the original helicopter.
local HANDLING_AI = {
    accelRate = CHOPPER_ACCEL_RATE,
    forceBlend = HELICOPTER_FORCE_BLEND,
    pitchScale = 0.75,
    rollScale = 1,
    pitchMin = -30,
    pitchMax = 45,
    rollMax = 45,
    reachTime = 0.6,
    tiltAccelMax = 300,
    yawAccelMax = 120,
    yawRateMax = 120,
    jerkMax = 1000,
}

--- Highest yaw rate in degrees per second of the uncontrolled spin after losing the tail rotor.
local YAW_RATE_MAX = HANDLING_AI.yawRateMax

--- Weakest yaw acceleration of the uncontrolled spin after losing the tail rotor.
local SPIN_ACCEL_MIN = 50

--- Strongest yaw acceleration of the uncontrolled spin after losing the tail rotor.
local SPIN_ACCEL_MAX = 120

--- Amount per second by which the roll offset left by a blast wears off, the original 2 per think.
local ROLL_DAMAGE_DECAY = 2 / HELICOPTER_TICK

--- Share of the rotor's sideways pull that a dying helicopter keeps.
local DYING_SIDEWAYS_PULL = 0.1

--- Largest pitch and roll in degrees a dying helicopter drifts towards.
local DYING_LEVEL_ANGLE = 5

--- Share of the remaining pitch and roll error a dying helicopter turns through per second.
local DYING_LEVEL_RATE = 0.1

--- Farthest above or below itself the autopilot's goal may be, which caps how fast it climbs and sinks and keeps it from overshooting its height by far.
local AI_CLIMB_REACH = 400

--- Horizontal distance below which the autopilot keeps its facing instead of turning to its goal.
local FACE_GOAL_MIN_DISTANCE = 50

--- Share of its full range per second by which a direct input pilot's movement demand follows the steering.
local DIRECT_DEMAND_RATE = 1.5

--- Yaw offset in degrees the helicopter chases while a turn input is held.
local TURN_LEAD = 60

--- Returns the angular acceleration that closes an angle error within the reach time.
---@param difference number Remaining angle to the goal in degrees.
---@param rate number Current angular rate in degrees per second.
---@param reachTime number Seconds within which the error should be closed.
---@param limit number Highest acceleration allowed in degrees per second squared.
---@return number acceleration
local function SolveAngularAccel(difference, rate, reachTime, limit)
    local accel = 2 * (difference - rate * reachTime) / (reachTime * reachTime)

    return math.Clamp(accel, -limit, limit)
end

--- Returns the handling the helicopter flies with: the original values for the autopilot, the more responsive ones of the entity's PilotHandling for a player.
---@return table handling
function ENT:GetFlightHandling()
    if ( self:GetAI() ) then return HANDLING_AI end

    return self.PilotHandling
end

--- Converts the pitch of the view into a forward movement demand.
---@param pitch number View pitch in degrees, positive looking down.
---@return number demand Forward demand between -1 and 1.
function ENT:PitchToDemand(pitch)
    local handling = self.PilotHandling
    local magnitude = math.Clamp(math.Remap(math.abs(pitch), handling.aimPitchDeadzone, handling.aimPitchFull, 0, 1), 0, 1)

    return pitch < 0 and -magnitude or magnitude
end

--- Turns movement demands into the offset of the position the helicopter tries to reach within one second.
---@param forward number Forward demand between -1 and 1.
---@param strafe number Rightward demand between -1 and 1.
---@param frameYaw number Yaw in degrees of the frame the demands are given in.
---@param reach number Distance the goal may lie away from the helicopter.
---@return Vector delta World space offset to the goal position.
function ENT:FlightDemandToDelta(forward, strafe, frameYaw, reach)
    local demand = Vector(forward, -strafe, self:GetThrust())

    if ( demand:LengthSqr() > 1 ) then
        demand:Normalize()
    end

    demand:Rotate(Angle(0, frameYaw, 0))
    demand:Mul(reach)

    return demand
end

--- Returns the goal of the autopilot, which flies to its waypoint while facing its enemy, or facing its waypoint on a bombing pass, and is pushed away from the obstacles around it.
---@param reach number Distance the goal may lie away from the helicopter.
---@return Vector delta World space offset to the goal position.
---@return number faceYaw Yaw in degrees the helicopter should face.
function ENT:GetFlightGoalAI(reach)
    local faceYaw = self:GetAngles().y
    local targetPos = self._lvsTargetPos
    if ( !targetPos ) then return Vector(0, 0, 0), faceYaw end

    local pos = self:GetPos()
    local delta = targetPos - pos
    local distance = delta:Length()

    reach = math.min(reach, self.aiSpeedLimit or reach)

    if ( distance > reach ) then
        delta:Mul(reach / distance)
    end

    delta.z = math.Clamp(delta.z, -AI_CLIMB_REACH, AI_CLIMB_REACH)

    delta:Add(self:GetAIAvoidance())

    local enemy = self:AIGetTarget()
    local bFarFromGoal = delta:Length2DSqr() > FACE_GOAL_MIN_DISTANCE * FACE_GOAL_MIN_DISTANCE

    if ( self.bAIFaceTravel and bFarFromGoal ) then
        faceYaw = delta:Angle().y
    elseif ( IsValid(enemy) ) then
        faceYaw = (enemy:GetPos() - pos):Angle().y
    elseif ( bFarFromGoal ) then
        faceYaw = delta:Angle().y
    end

    self:SetThrust(math.Clamp(delta.z / CHOPPER_ACCEL_RATE, -1, 1))

    return delta, faceYaw
end

--- Returns the goal of a mouse aim pilot: the view steers and sets the facing, the keys move.
---@param client Player Pilot of the helicopter.
---@param reach number Distance the goal may lie away from the helicopter.
---@param deltatime number Length of the physics step in seconds.
---@return Vector delta World space offset to the goal position.
---@return number faceYaw Yaw in degrees the helicopter should face.
function ENT:GetFlightGoalMouseAim(client, reach, deltatime)
    local eyeAngles = self:GetDriverSeat():WorldToLocalAngles(client:EyeAngles())

    if ( !client:lvsKeyDown("FREELOOK") ) then
        self.StoredEyeAngles = eyeAngles
    elseif ( isangle(self.StoredEyeAngles) ) then
        eyeAngles = self.StoredEyeAngles
    end

    local forward = self:PitchToDemand(eyeAngles.p)
    local pitchKeys = (client:lvsKeyDown("-PITCH_HELI") and 1 or 0) - (client:lvsKeyDown("+PITCH_HELI") and 1 or 0)

    if ( pitchKeys != 0 ) then
        forward = pitchKeys
    end

    local strafe = (client:lvsKeyDown("+ROLL_HELI") and 1 or 0) - (client:lvsKeyDown("-ROLL_HELI") and 1 or 0)
    local faceYaw = eyeAngles.y
    local yawKeys = (client:lvsKeyDown("-YAW_HELI") and 1 or 0) - (client:lvsKeyDown("+YAW_HELI") and 1 or 0)

    if ( yawKeys != 0 ) then
        faceYaw = self:GetAngles().y + yawKeys * TURN_LEAD
    end

    if ( client:lvsKeyDown("HELI_HOVER") ) then
        forward = 0
        strafe = 0
    end

    self:CalcThrust(client:lvsKeyDown("+THRUST_HELI"), client:lvsKeyDown("-THRUST_HELI"), deltatime)

    return self:FlightDemandToDelta(forward, strafe, faceYaw, reach), faceYaw
end

--- Returns the goal of a direct input pilot. The mouse works like a stick that stays where it was pushed: moving it builds up the forward and sideways demand, which holds until it is moved back or the hover key brings the helicopter to a stop.
---@param client Player|nil Pilot of the helicopter.
---@param reach number Distance the goal may lie away from the helicopter.
---@param deltatime number Length of the physics step in seconds.
---@return Vector delta World space offset to the goal position.
---@return number faceYaw Yaw in degrees the helicopter should face.
function ENT:GetFlightGoalDirect(client, reach, deltatime)
    local steer = self:GetSteer()
    local yaw = self:GetAngles().y
    local demand = self.directDemand or Vector(0, 0, 0)

    if ( IsValid(client) and client:lvsKeyDown("HELI_HOVER") ) then
        demand = Vector(0, 0, 0)
    else
        local rate = DIRECT_DEMAND_RATE * deltatime

        demand.x = math.Clamp(demand.x + math.Clamp(steer.y, -1, 1) * rate, -1, 1)
        demand.y = math.Clamp(demand.y + math.Clamp(steer.x, -1, 1) * rate, -1, 1)
    end

    self.directDemand = demand

    return self:FlightDemandToDelta(demand.x, demand.y, yaw, reach), yaw + math.Clamp(steer.z, -1, 1) * TURN_LEAD
end

--- Returns where the helicopter currently wants to go and which way it wants to face.
---@param reach number Distance the goal may lie away from the helicopter.
---@param deltatime number Length of the physics step in seconds.
---@return Vector delta World space offset to the goal position.
---@return number faceYaw Yaw in degrees the helicopter should face.
function ENT:GetFlightGoal(reach, deltatime)
    if ( self:GetAI() ) then return self:GetFlightGoalAI(reach) end

    local client = self:GetDriver()
    if ( IsValid(client) and client:lvsMouseAim() ) then return self:GetFlightGoalMouseAim(client, reach, deltatime) end

    return self:GetFlightGoalDirect(client, reach, deltatime)
end

--- Computes the acceleration needed to reach the goal within one second and blends the rotor force towards it.
---@param delta Vector World space offset to the goal position.
---@param velocity Vector Current world space velocity.
---@param deltatime number Length of the physics step in seconds.
---@param forceBlend number|nil Share of the previous rotor force kept per original think tick.
---@param bPitchLift boolean|nil Whether to raise the rotor force by as much as the nose is tilted down, so that the helicopter holds its height in a steep forward lean instead of sinking; the original's own allowance for leaning shrinks by the same amount so the two do not add up.
---@return Vector goalAccel Acceleration the helicopter leans into, gravity compensation included.
function ENT:UpdateFlightLift(delta, velocity, deltatime, forceBlend, bPitchLift)
    local goalAccel = (delta - velocity) * 2
    goalAccel.z = math.Clamp(goalAccel.z + HELICOPTER_GRAVITY, HELICOPTER_GRAVITY * 0.2, HELICOPTER_GRAVITY * 2)

    local horizontalLift = (math.abs(goalAccel.x) + math.abs(goalAccel.y)) * HORIZONTAL_LIFT_FACTOR

    if ( delta.z < HELICOPTER_MIN_DZ_DAMP and horizontalLift > 0 ) then
        local fraction = math.Clamp((HELICOPTER_MIN_DZ_DAMP - delta.z) / (HELICOPTER_MIN_DZ_DAMP - HELICOPTER_MAX_DZ_DAMP), 0, 1)
        local spline = fraction * fraction * (3 - 2 * fraction)
        local dampedLift = Lerp(spline, horizontalLift, 2.5 * HELICOPTER_GRAVITY * 0.2)

        if ( dampedLift < horizontalLift ) then
            local dampening = dampedLift / horizontalLift

            goalAccel.x = goalAccel.x * dampening
            goalAccel.y = goalAccel.y * dampening
            horizontalLift = dampedLift
        end
    end

    local lift = goalAccel.z + horizontalLift

    if ( bPitchLift ) then
        local noseDownCos = math.max(math.cos(math.rad(math.max(self:GetAngles().p, 0))), PITCH_LIFT_MIN_COS)

        lift = goalAccel.z / noseDownCos + horizontalLift * noseDownCos
    end

    local blend = 1 - (forceBlend or HELICOPTER_FORCE_BLEND) ^ (deltatime / HELICOPTER_TICK)
    self.flightLift = Lerp(blend, self.flightLift or 0, lift)

    return goalAccel
end

--- Returns the world space acceleration from the rotor, the original gravity and both drag terms.
---@param velocity Vector Current world space velocity.
---@return Vector accel
function ENT:GetFlightLinearAccel(velocity)
    local right = self:GetRight()
    local accel = self:GetUp() * (self.flightLift or 0)

    accel.z = accel.z + self:GetWorldGravity() - HELICOPTER_GRAVITY
    accel.x = accel.x - velocity.x * (math.abs(right.x) * SIDEWAYS_DRAG_RATE + GENERAL_DRAG_RATE)
    accel.y = accel.y - velocity.y * (math.abs(right.y) * SIDEWAYS_DRAG_RATE + GENERAL_DRAG_RATE)
    accel.z = accel.z - velocity.z * (math.abs(right.z) * SIDEWAYS_DRAG_RATE + GENERAL_DRAG_RATE)

    return accel
end

--- Returns the local angular acceleration that leans the helicopter into its goal acceleration and turns it to its facing. The tilt goal is measured from the current attitude, so a scale of s settles at s / (1 + s) of the tilt the goal acceleration asks for: the original 0.75 leans the nose only three sevenths of the way. A recent blast adds its roll offset to the roll goal before the conversion to degrees, exactly as the original does, which pins the helicopter at its steepest roll until the offset has worn off.
---@param phys PhysObj Physics object of the helicopter.
---@param goalAccel Vector Acceleration the helicopter leans into.
---@param faceYaw number Yaw in degrees the helicopter should face.
---@param deltatime number Length of the physics step in seconds.
---@param handling table Handling values to fly with.
---@return Vector accel Angular acceleration around the local roll, pitch and yaw axes in degrees per second squared.
function ENT:GetFlightAngularAccel(phys, goalAccel, faceYaw, deltatime, handling)
    local angles = self:GetAngles()
    local goalUp = goalAccel:GetNormalized()
    local goalPitch = math.deg(math.asin(math.Clamp(self:GetForward():Dot(goalUp), -1, 1))) * handling.pitchScale
    local goalRoll = math.deg(math.asin(math.Clamp(self:GetRight():Dot(goalUp), -1, 1)) + (self.flightRollDamage or 0)) * handling.rollScale

    goalPitch = math.Clamp(goalPitch, handling.pitchMin, handling.pitchMax)
    goalRoll = math.Clamp(goalRoll, -handling.rollMax, handling.rollMax)

    local sinPitch = math.sin(math.rad(angles.p))
    local cosPitch = math.max(math.cos(math.rad(angles.p)), 0.1)
    local sinRoll = math.sin(math.rad(angles.r))
    local cosRoll = math.cos(math.rad(angles.r))

    local angVelocity = phys:GetAngleVelocity()
    local pitchRate = angVelocity.y * cosRoll - angVelocity.z * sinRoll
    local yawRate = (angVelocity.y * sinRoll + angVelocity.z * cosRoll) / cosPitch
    local rollRate = angVelocity.x + yawRate * sinPitch

    local reachTime = handling.reachTime
    local goalPitchAccel = SolveAngularAccel(math.AngleDifference(goalPitch, angles.p), pitchRate, reachTime, handling.tiltAccelMax)
    local goalYawAccel = SolveAngularAccel(math.AngleDifference(faceYaw, angles.y), yawRate, reachTime, handling.yawAccelMax)
    local goalRollAccel = SolveAngularAccel(math.AngleDifference(goalRoll, angles.r), rollRate, reachTime, handling.tiltAccelMax)

    if ( self:IsSteeringDestroyed() ) then
        goalYawAccel = math.Rand(SPIN_ACCEL_MIN, SPIN_ACCEL_MAX) * self:Sign(self._SteerOverrideMove or 1)
    end

    local current = self.flightAngAccel or Vector(0, 0, 0)
    local jerk = handling.jerkMax * deltatime
    local pitchAccel = math.Approach(current.x, goalPitchAccel, jerk)
    local yawAccel = math.Approach(current.y, goalYawAccel, jerk)
    local rollAccel = math.Approach(current.z, goalRollAccel, jerk)

    self.flightAngAccel = Vector(pitchAccel, yawAccel, rollAccel)

    local yawRateMax = handling.yawRateMax

    yawAccel = math.Clamp(yawAccel, (-yawRateMax - yawRate) / deltatime, (yawRateMax - yawRate) / deltatime)

    return Vector(
        rollAccel - yawAccel * sinPitch,
        pitchAccel * cosRoll + yawAccel * cosPitch * sinRoll,
        yawAccel * cosPitch * cosRoll - pitchAccel * sinRoll
    )
end

--- Returns the velocity without the gravity step the physics engine has already applied for the running tick, which would otherwise read as a constant sink and make the helicopter creep upwards.
---@param phys PhysObj Physics object of the helicopter.
---@param deltatime number Length of the physics step in seconds.
---@return Vector velocity
function ENT:GetFlightVelocity(phys, deltatime)
    local velocity = phys:GetVelocity()
    if ( !phys:IsGravityEnabled() ) then return velocity end

    return velocity - physenv.GetGravity() * deltatime
end

--- Lets a shot down helicopter fall the way the original does while it is dying: the rotor no longer lifts it, only a tenth of its sideways pull remains, it spins around its yaw axis and its pitch and roll drift towards level.
---@param phys PhysObj Physics object of the helicopter.
---@param velocity Vector Current world space velocity.
---@param deltatime number Length of the physics step in seconds.
---@return Vector angularAccel Local angular acceleration.
---@return Vector linearAccel Local linear acceleration.
---@return number simulate Simulation mode for the motion controller.
function ENT:SimulateDyingFlight(phys, velocity, deltatime)
    self:UpdateFlightLift(Vector(0, 0, 0), velocity, deltatime)

    local linearAccel = self:GetFlightLinearAccel(velocity)
    local lift = self:GetUp() * self.flightLift

    linearAccel.x = linearAccel.x - lift.x * (1 - DYING_SIDEWAYS_PULL)
    linearAccel.y = linearAccel.y - lift.y * (1 - DYING_SIDEWAYS_PULL)
    linearAccel.z = linearAccel.z - lift.z

    local angles = self:GetAngles()
    local angVelocity = phys:GetAngleVelocity()
    local spin = math.Rand(SPIN_ACCEL_MIN, SPIN_ACCEL_MAX) * self:Sign(self._SteerOverrideMove or 1)

    if ( math.abs(angVelocity.z) >= YAW_RATE_MAX ) then
        spin = 0
    end

    local angularAccel = Vector(
        ((math.Rand(-DYING_LEVEL_ANGLE, DYING_LEVEL_ANGLE) - angles.r) * DYING_LEVEL_RATE - angVelocity.x) / HELICOPTER_TICK,
        ((math.Rand(-DYING_LEVEL_ANGLE, DYING_LEVEL_ANGLE) - angles.p) * DYING_LEVEL_RATE - angVelocity.y) / HELICOPTER_TICK,
        spin
    )

    return self:PhysicsSimulateOverride(angularAccel, phys:WorldToLocalVector(linearAccel), phys, deltatime, SIM_LOCAL_ACCELERATION)
end

--- Flies the helicopter with the Half-Life 2 attack helicopter model instead of the LVS helicopter physics, with the original handling for the autopilot and a quicker one for a player.
---@param phys PhysObj Physics object of the helicopter.
---@param deltatime number Length of the physics step in seconds.
---@return Vector angularAccel Local angular acceleration.
---@return Vector linearAccel Local linear acceleration.
---@return number simulate Simulation mode for the motion controller.
function ENT:PhysicsSimulate(phys, deltatime)
    if ( self:GetEngineActive() ) then
        phys:Wake()
    end

    local velocity = self:GetFlightVelocity(phys, deltatime)
    if ( self:IsDestroyed() ) then return self:SimulateDyingFlight(phys, velocity, deltatime) end

    self.flightRollDamage = math.Approach(self.flightRollDamage or 0, 0, ROLL_DAMAGE_DECAY * deltatime)

    local handling = self:GetFlightHandling()
    local reach = math.min(velocity:Length() + handling.accelRate, self.MaxVelocity)
    local delta, faceYaw = self:GetFlightGoal(reach, deltatime)
    local throttle = self:GetThrottle()

    if ( throttle <= 0 or ( self:GetThrust() <= 0 and self:HitGround() ) ) then
        self.flightLift = 0
        self.flightAngAccel = nil
        self.directDemand = nil

        return self:PhysicsSimulateOverride(Vector(0, 0, 0), Vector(0, 0, 0), phys, deltatime, SIM_NOTHING)
    end

    local goalAccel = self:UpdateFlightLift(delta, velocity, deltatime, handling.forceBlend, handling.bPitchLift)
    local linearAccel = phys:WorldToLocalVector(self:GetFlightLinearAccel(velocity)) * throttle
    local angularAccel = self:GetFlightAngularAccel(phys, goalAccel, faceYaw, deltatime, handling) * throttle

    return self:PhysicsSimulateOverride(angularAccel, linearAccel, phys, deltatime, SIM_LOCAL_ACCELERATION)
end
