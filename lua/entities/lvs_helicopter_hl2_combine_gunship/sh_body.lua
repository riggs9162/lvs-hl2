--- Head of the gunship's body, from CNPC_CombineGunship::MoveHead. The server turns the head on its think so that the cannon fires where the head points, and every client turns its own copy of the head on every frame, so that it moves smoothly instead of in the steps of the server's think and the network.

--- Smallest cosine between the gunship's facing and its target at which the head turns to the target instead of into the turn.
local HEAD_TRACK_DOT = 0.3

--- Share of the angle between the muzzle and its target the head closes on one original think.
local HEAD_TRACK_SHARE = 0.9

--- Most degrees per second the head turns towards its target, five on every original think.
local HEAD_TRACK_RATE = 50

--- Degrees per second the head turns while it follows the gunship's own turning.
local HEAD_FOLLOW_RATE = 20

--- Furthest the head can turn in degrees, the range of its pose parameters.
local HEAD_LIMIT = 75

--- Length of one original think tick in seconds.
local HELICOPTER_TICK = 0.1

--- Returns the share of an error a controller that closes HEAD_TRACK_SHARE of it per original think closes in a given time.
---@param deltatime number
---@return number share
local function GetTrackShare(deltatime)
    return 1 - (1 - HEAD_TRACK_SHARE) ^ (deltatime / HELICOPTER_TICK)
end

--- Turns a head towards its target while the target is in front, or else lets it lean into the gunship's turning.
---@param head table Head state with yaw and pitch.
---@param muzzle table|nil Attachment of the cannon's muzzle.
---@param targetPos Vector|nil Point the head looks at.
---@param turnRate Vector Pitch and yaw rate of the gunship in degrees per second, as y and z.
---@param deltatime number Seconds since the last turn.
function ENT:TurnHead(head, muzzle, targetPos, turnRate, deltatime)
    local bTracking = false

    if ( targetPos and muzzle ) then
        local toTarget = targetPos - muzzle.Pos

        if ( self:GetForward():Dot(toTarget:GetNormalized()) > HEAD_TRACK_DOT ) then
            local targetAngles = toTarget:Angle()
            local share = GetTrackShare(deltatime)
            local maxStep = HEAD_TRACK_RATE * deltatime

            head.yaw = math.Approach(head.yaw, head.yaw + math.AngleDifference(targetAngles.y, muzzle.Ang.y) * share, maxStep)
            head.pitch = math.Approach(head.pitch, head.pitch + math.AngleDifference(targetAngles.p, muzzle.Ang.p) * share, maxStep)
            bTracking = true
        end
    end

    if ( !bTracking ) then
        head.yaw = math.Approach(head.yaw, turnRate.z, HEAD_FOLLOW_RATE * deltatime)
        head.pitch = math.Approach(head.pitch, turnRate.y, HEAD_FOLLOW_RATE * deltatime)
    end

    head.yaw = math.Clamp(head.yaw, -HEAD_LIMIT, HEAD_LIMIT)
    head.pitch = math.Clamp(head.pitch, -HEAD_LIMIT, HEAD_LIMIT)
end

--- Sets the head's pose parameters on the body.
---@param body Entity
---@param head table Head state with yaw and pitch.
function ENT:PoseHead(body, head)
    body:SetPoseParameter("flex_horz", head.yaw)
    body:SetPoseParameter("flex_vert", head.pitch)
end
