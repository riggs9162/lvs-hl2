--- Walking of the strider, ported from how the original NPC moves. Like the NPC it walks exactly as fast as its walk animation carries it, so that its planted feet do not slide, turns at its fixed yaw speed and steps around with a turning gesture when it turns on the spot. Its model keeps the original's origin at the stand height above the ground while the body height pose parameter lowers the body, from CAI_Motor::MoveFlyExecute, MoveFacing and UpdateYaw, CBaseAnimating::StudioFrameAdvance and CNPC_Strider::OverrideMove, MaintainTurnActivity and MaxYawSpeed.

--- Animations of standing, walking, running and hanging under a dropship, ACT_IDLE, ACT_WALK, ACT_RUN and ACT_STRIDER_CARRIED.
local IDLE_SEQUENCE = "Idle01"
local WALK_SEQUENCE = "walk_all"
local RUN_SEQUENCE = "fastwalk_all"
local CARRIED_SEQUENCE = "carried"

--- Gestures of stepping around on the spot, ACT_GESTURE_TURN_LEFT and ACT_GESTURE_TURN_RIGHT.
local TURN_LEFT_SEQUENCE = "turnleft"
local TURN_RIGHT_SEQUENCE = "turnright"

--- Sum of the turning the original adds up on every think before it steps around, and above which it steps faster.
local TURN_GESTURE_THRESHOLD = 180
local TURN_GESTURE_FAST_THRESHOLD = 360

--- Pace of a fast turning gesture, its layer priority and the wait before trying again when no layer is free.
local TURN_GESTURE_FAST_RATE = 1.5
local TURN_GESTURE_PRIORITY = 100
local TURN_GESTURE_RETRY = 0.5

--- Seconds a turning gesture takes to fade out once the strider walks or skewers.
local TURN_GESTURE_FADE = 0.2

--- Smallest change of heading in degrees that counts as turning, so that the jitter of the physics does not.
local TURN_MIN_STEP = 0.5

--- Fastest the strider turns, in degrees per second: the original's yaw speed of ten, ten times a second.
local YAW_SPEED = 100

--- Share per second of the turn still to go that the strider turns at near the end of a turn, and how fast its turning speed follows.
local YAW_RESPONSE = 10
local YAW_RATE_RESPONSE = 20

--- Fastest and slowest the body rises or sinks while it changes height, in units per second.
local HEIGHT_MAX_VELOCITY = 300
local HEIGHT_MIN_VELOCITY = 10

--- Share of its speed the body keeps on every think while it slows down at the end of a height change.
local HEIGHT_INV_DECAY = 0.8

--- Seconds of slowing down the body plans for at the end of a height change, the sum of HEIGHT_INV_DECAY over the cycles.
local HEIGHT_DECAY_TIME = 0.4161

--- Share of the way to its top speed the body speeds up by on every think while it changes height.
local HEIGHT_ACCEL = 0.5

--- How fast the walking speed follows the animation's, per second, and the strongest acceleration. The original changes speed at once.
local MOVE_RESPONSE = 12
local MOVE_ACCEL_MAX = 3000

--- Spring and damping that hold the body at its height.
local HOVER_SPRING = 30
local HOVER_DAMPING = 11

--- Spring and damping that keep the body level.
local LEVEL_SPRING = 40
local LEVEL_DAMPING = 12

--- Distance below the body, on top of its height, in which the ground still carries the strider.
local GROUND_REACH = 200

--- Distance from the middle of the body and directions from its heading at which the ground is looked for where the feet stand.
local GROUND_SAMPLE_RADIUS = 150
local GROUND_SAMPLE_YAWS = {60, -60, 180}

--- How fast the height of the ground the strider walks on follows the ground below it, per second, and its fastest change in units per second.
local GROUND_RESPONSE = 3
local GROUND_MAX_RATE = 300

--- Distance from the ground the pilot is let out at.
local EXIT_HEIGHT = 16

--- Prepares the walking state.
function ENT:InitWalk()
    self.bodyHeight = self.StandHeight
    self.idealHeight = self.StandHeight
    self.heightVelocity = 0
    self.bOnGround = false
    self.bWalking = false
    self.walkVelocity = Vector(0, 0, 0)
    self.turnLeft = 0
    self.turnRight = 0
    self.turnTotal = 0
    self.nextTurnGesture = 0

    self:SetBodyHeight(self.bodyHeight)
    self:SetPoseParameter("body_height", self.bodyHeight)
    self:UpdateGround(0)
end

--- Sets the body height the strider rises or sinks to, from CNPC_Strider::SetIdealHeight.
---@param height number
function ENT:SetIdealHeight(height)
    self.idealHeight = math.Clamp(height, self.CrouchHeight, self.StandHeight)
end

--- Returns the body height.
---@return number height
function ENT:GetHeight()
    return self.bodyHeight or self.StandHeight
end

--- Returns how high the entity's origin, the middle of the body, hovers above the ground: the original's origin stays at its stand height above the ground and its body hangs below it by the model's height less the body height.
---@return number clearance
function ENT:GetGroundClearance()
    return self:GetHeight() - (self.ModelHeight - self.StandHeight)
end

--- Returns whether the strider is crouched, from CNPC_Strider::IsInCrouchedPosture.
---@return boolean bCrouched
function ENT:IsInCrouchedPosture()
    return (self.idealHeight or self.StandHeight) < self.StandHeight * 0.5
end

--- Moves the body towards its ideal height, speeding up and slowing down like the original, from CNPC_Strider::OverrideMove.
---@param interval number Seconds since the last think.
function ENT:UpdateHeight(interval)
    if ( self:GetCarryingDropship() ) then
        self:SetIdealHeight(self.StandHeight)
    end

    local heightMove = self.idealHeight - self.bodyHeight
    local sign = heightMove < 0 and -1 or 1

    heightMove = math.abs(heightMove)

    if ( heightMove > 0.01 ) then
        local velocity = self.heightVelocity

        if ( math.abs(velocity) < HEIGHT_MIN_VELOCITY ) then
            velocity = HEIGHT_MIN_VELOCITY * sign
        end

        if ( heightMove < velocity * sign * HEIGHT_DECAY_TIME ) then
            velocity = velocity * HEIGHT_INV_DECAY

            if ( heightMove < velocity * sign * interval ) then
                velocity = heightMove * sign / interval
            end
        else
            velocity = velocity * (1 - HEIGHT_ACCEL) + HEIGHT_MAX_VELOCITY * HEIGHT_ACCEL * sign

            if ( heightMove < velocity * sign * HEIGHT_DECAY_TIME ) then
                velocity = heightMove * sign / HEIGHT_DECAY_TIME
            end
        end

        self.heightVelocity = velocity
        self.bodyHeight = math.Clamp(self.bodyHeight + velocity * interval, self.CrouchHeight, self.StandHeight)
    end

    self:SetBodyHeight(self.bodyHeight)
    self:SetPoseParameter("body_height", self.bodyHeight)

    if ( IsValid(self.driverSeat) ) then
        self.driverSeat.ExitPos = Vector(0, 0, EXIT_HEIGHT - self:GetGroundClearance())
    end
end

--- Returns the height of the ground below a point, within the reach of the legs.
---@param x number
---@param y number
---@return number|nil groundZ
function ENT:TraceGroundZ(x, y)
    local top = self:GetPos().z
    local trace = util.TraceLine({
        start = Vector(x, y, top),
        endpos = Vector(x, y, top - self:GetHeight() - GROUND_REACH),
        mask = MASK_NPCSOLID_BRUSHONLY,
        filter = self:GetCrosshairFilterEnts(),
    })

    if ( !trace.Hit or trace.StartSolid ) then return nil end

    return trace.HitPos.z
end

--- Finds the ground below the body and where the feet stand, and follows its height smoothly, as the original walks along the even height of its path while its feet find the ground on their own. Then tells the clients where the model's origin is, at the stand height above that ground.
---@param deltatime number
function ENT:UpdateGround(deltatime)
    local pos = self:GetPos()
    local yaw = self:GetAngles().y
    local total, count = 0, 0
    local centerZ = self:TraceGroundZ(pos.x, pos.y)

    if ( centerZ ) then
        total, count = centerZ, 1
    end

    for _, sampleYaw in ipairs(GROUND_SAMPLE_YAWS) do
        local offset = Angle(0, yaw + sampleYaw, 0):Forward() * GROUND_SAMPLE_RADIUS
        local sampleZ = self:TraceGroundZ(pos.x + offset.x, pos.y + offset.y)

        if ( sampleZ ) then
            total, count = total + sampleZ, count + 1
        end
    end

    local bOnGround = count > 0 and !self:GetCarryingDropship()

    if ( bOnGround ) then
        local groundZ = total / count

        if ( !self.bOnGround or !self.groundZ ) then
            self.groundZ = groundZ
        else
            local maxStep = GROUND_MAX_RATE * deltatime

            self.groundZ = self.groundZ + math.Clamp((groundZ - self.groundZ) * math.min(GROUND_RESPONSE * deltatime, 1), -maxStep, maxStep)
        end

        self:SetSkeletonZ(self.groundZ + self.StandHeight)
    else
        self:SetSkeletonZ(pos.z + self:GetSkeletonOffset(self:GetHeight()))
    end

    self.bOnGround = bOnGround
end

--- Returns whether the legs reach the ground.
---@return boolean bOnGround
function ENT:HitGround()
    return self.bOnGround == true
end

--- Returns whether the strider has to stand still, while it fires its cannon or skewers, as the original stops moving for both.
---@return boolean bHold
function ENT:IsHoldingStill()
    return self:GetCannonCharging() or self:IsStomping()
end

--- Plays an animation from its start unless it is playing already, at its normal pace.
---@param name string
---@return number sequence
function ENT:PlayStriderSequence(name)
    local sequence = self:LookupSequence(name)

    if ( self:GetSequence() != sequence ) then
        self:ResetSequence(sequence)
    end

    self:SetPlaybackRate(1)

    return sequence
end

--- Fades out the turning gesture.
---@param deltatime number
function ENT:FadeTurnGesture(deltatime)
    local layer = self.turnGestureLayer
    if ( !layer ) then return end

    if ( !self:IsValidLayer(layer) or self:GetLayerSequence(layer) != self.turnGestureSequence ) then
        self.turnGestureLayer = nil

        return
    end

    local weight = self:GetLayerWeight(layer) - deltatime / TURN_GESTURE_FADE

    if ( weight <= 0 ) then
        self:RemoveLayer(layer)
        self.turnGestureLayer = nil

        return
    end

    self:SetLayerWeight(layer, weight)
end

--- Picks the animation and the velocity: the walk, or the run while boosting, in the direction of the input and exactly as fast as the animation carries the strider, as the original moves at the ground speed of its walk; the idle while it stands, and the legs folded while a dropship carries it.
---@param deltatime number
function ENT:UpdateWalk(deltatime)
    self.walkVelocity = Vector(0, 0, 0)
    self.bWalking = false

    if ( self:IsStomping() ) then
        self:FadeTurnGesture(deltatime)

        return
    end

    if ( self:GetCarryingDropship() ) then
        self:PlayStriderSequence(CARRIED_SEQUENCE)

        return
    end

    local move = self:GetMove()
    local direction = Vector(move.x, move.y, 0)

    if ( !self.bOnGround or self:IsHoldingStill() or direction:LengthSqr() < 0.01 ) then
        self:PlayStriderSequence(IDLE_SEQUENCE)

        return
    end

    local moveYaw = math.deg(math.atan2(direction.y, direction.x))
    local sequence = self:PlayStriderSequence(move.z > 0 and RUN_SEQUENCE or WALK_SEQUENCE)

    self:SetPoseParameter("move_yaw", moveYaw)

    self.walkVelocity = Angle(0, self:GetAngles().y + moveYaw, 0):Forward() * self:GetSequenceGroundSpeed(sequence)
    self.bWalking = true

    self:FadeTurnGesture(deltatime)
end

--- Steps around with a turning gesture once the strider has turned far enough on the spot, adding up its turning the way the original does, from CNPC_Strider::MaintainTurnActivity.
function ENT:MaintainTurnActivity()
    local yaw = self:GetAngles().y
    local difference = math.AngleDifference(self.prevYaw or yaw, yaw)

    if ( math.abs(difference) >= TURN_MIN_STEP ) then
        if ( difference < 0 ) then
            self.turnLeft = self.turnLeft - difference
        else
            self.turnRight = self.turnRight + difference
        end

        self.prevYaw = yaw
    elseif ( !self.prevYaw ) then
        self.prevYaw = yaw
    end

    self.turnTotal = self.turnTotal + self.turnLeft + self.turnRight

    local now = CurTime()
    if ( self.bWalking or self:IsStomping() or self.turnTotal <= TURN_GESTURE_THRESHOLD or now < self.nextTurnGesture ) then return end

    local sequence = self:LookupSequence(self.turnLeft > self.turnRight and TURN_LEFT_SEQUENCE or TURN_RIGHT_SEQUENCE)
    local layer = sequence >= 0 and self:AddGestureSequence(sequence, true) or -1

    if ( layer >= 0 ) then
        self:SetLayerPriority(layer, TURN_GESTURE_PRIORITY)

        if ( self.turnTotal > TURN_GESTURE_FAST_THRESHOLD ) then
            self:SetLayerPlaybackRate(layer, TURN_GESTURE_FAST_RATE)
        end

        self.turnGestureLayer = layer
        self.turnGestureSequence = sequence
        self.nextTurnGesture = now + self:GetLayerDuration(layer)
    else
        self.nextTurnGesture = now + TURN_GESTURE_RETRY
    end

    self.turnTotal = 0
    self.turnLeft = 0
    self.turnRight = 0
end

--- Holds the body at its height above the ground, walks it at the velocity of its animation and turns it towards the steering at the original's yaw speed, keeping it level.
---@param phys PhysObj
---@param deltatime number
---@return Vector angularAccel
---@return Vector linearAccel
---@return number simulate
function ENT:SimulateWalk(phys, deltatime)
    phys:Wake()

    local pos = self:GetPos()
    local velocity = phys:GetVelocity()
    local angles = self:GetAngles()
    local angVelocity = phys:GetAngleVelocity()
    local linearAccel = Vector(0, 0, 0)

    if ( self.bOnGround and self.groundZ ) then
        local targetZ = self.groundZ + self:GetGroundClearance()
        local horizontal = (self.walkVelocity - Vector(velocity.x, velocity.y, 0)) * MOVE_RESPONSE

        if ( horizontal:Length() > MOVE_ACCEL_MAX ) then
            horizontal = horizontal:GetNormalized() * MOVE_ACCEL_MAX
        end

        linearAccel = horizontal
        linearAccel.z = (targetZ - pos.z) * HOVER_SPRING - velocity.z * HOVER_DAMPING + self:GetWorldGravity()
    end

    local yawDifference = math.AngleDifference(self:GetSteerTo(), angles.y)
    local yawRate = math.Clamp(yawDifference * YAW_RESPONSE, -YAW_SPEED, YAW_SPEED)
    local angularAccel = Vector(
        -angles.r * LEVEL_SPRING - angVelocity.x * LEVEL_DAMPING,
        -angles.p * LEVEL_SPRING - angVelocity.y * LEVEL_DAMPING,
        (yawRate - angVelocity.z) * YAW_RATE_RESPONSE
    )

    return angularAccel, phys:WorldToLocalVector(linearAccel), SIM_LOCAL_ACCELERATION
end

--- Returns where a foot is.
---@param name string Attachment of the foot.
---@return Vector pos
function ENT:GetFootPosition(name)
    local attachment = self:GetStriderAttachment(name)

    return attachment and attachment.Pos or self:GetPos()
end

--- Sets a foot down: the footstep, a puff of dust or a splash, a little shake and a warning to everyone nearby, from CNPC_Strider::LeftFootHit and FootFX.
---@param name string Attachment of the foot.
function ENT:FootHit(name)
    local foot = self:GetFootPosition(name)
    local start = Vector(foot.x, foot.y, self:GetPos().z)
    local trace = util.TraceLine({
        start = start,
        endpos = start - Vector(0, 0, self:GetHeight() + GROUND_REACH),
        mask = MASK_SOLID_BRUSHONLY,
        filter = self,
    })

    local pos = trace.Hit and trace.HitPos or foot

    EmitSound("NPC_Strider.Footstep", pos)

    local effectData = EffectData()

    if ( bit.band(util.PointContents(pos + Vector(0, 0, 1)), MASK_WATER) != 0 ) then
        local surface = util.TraceLine({start = pos + Vector(0, 0, 100), endpos = pos, mask = MASK_WATER})

        effectData:SetOrigin(Vector(pos.x, pos.y, surface.HitPos.z))
        effectData:SetNormal(Vector(0, 0, 1))
        effectData:SetScale(math.Rand(10, 14))
        util.Effect("watersplash", effectData)
    else
        effectData:SetOrigin(pos)
        util.Effect("lvs_hl2_strider_footstep", effectData)
    end

    util.ScreenShake(pos, 4, 1, 0.5, 1000)
    sound.EmitHint(bit.bor(SOUND_DANGER, SOUND_CONTEXT_EXCLUDE_COMBINE), pos, 512, 1, self)
end
