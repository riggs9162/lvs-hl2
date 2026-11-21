--- Server side of the gunship's body: the head that aims the cannon, and what the clients need to animate the body themselves.

--- Length of one original think tick in seconds, which turns the rotor push of the flight model into the original's units.
local HELICOPTER_TICK = 0.1

--- Prepares the head state.
function ENT:InitBody()
    self.head = {yaw = 0, pitch = 0}
end

--- Returns the point the head looks at: the cannon's target while the autopilot has an enemy, or the crosshair for a pilot.
---@return Vector|nil targetPos
function ENT:GetHeadAimPos()
    if ( self:GetAI() ) then
        if ( !self:GetCannonEnemy() ) then return nil end

        return self:GetCannonTarget()
    end
    if ( !IsValid(self:GetDriver()) ) then return nil end

    return self:GetEyeTrace().HitPos
end

--- Turns the head on the server's think, which the cannon's muzzle follows, and tells the clients where it looks and how hard the rotor pushes.
---@param deltatime number Seconds since the last think.
function ENT:MoveHead(deltatime)
    local body = self:GetBody()
    if ( !IsValid(body) ) then return end

    local targetPos = self:GetHeadAimPos()
    local phys = self:GetPhysicsObject()
    local turnRate = IsValid(phys) and phys:GetAngleVelocity() or vector_origin

    self:TurnHead(self.head, self:GetBodyAttachment("muzzle"), targetPos, turnRate, deltatime)
    self:PoseHead(body, self.head)

    self:SetHeadTarget(targetPos or vector_origin)
    self:SetRotorForce((self.flightLift or 0) * HELICOPTER_TICK)
end
