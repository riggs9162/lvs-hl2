--- Flight of a gunship that has been shot down, from CNPC_CombineGunship::Flight and ApplySidewaysDrag while the gunship is dying without a crash point to fly to. The rest of its flight is the shared helicopter flight model with the gunship's numbers from shared.lua.

--- Speed the goal position may run ahead of the current speed, GUNSHIP_ACCEL_RATE.
local GUNSHIP_ACCEL_RATE = 500

--- Downward acceleration of a dying gunship in units per second squared: the original replaces the upward part of its rotor push with ten units downwards on every think.
local DYING_SINK_ACCEL = 100

--- Share of the velocity along each world axis a dying gunship loses per think tick to sideways drag.
local DYING_SIDEWAYS_DRAG = Vector(0.03, 0.03, 0.09)

--- Lets a shot down gunship sink while it keeps steering towards its goal: its rotor still pushes it sideways and turns it, but no longer holds it up.
---@param phys PhysObj Physics object of the gunship.
---@param velocity Vector Current world space velocity.
---@param deltatime number Length of the physics step in seconds.
---@return Vector angularAccel Local angular acceleration.
---@return Vector linearAccel Local linear acceleration.
---@return number simulate Simulation mode for the motion controller.
function ENT:SimulateDyingFlight(phys, velocity, deltatime)
    local reach = math.min(velocity:Length() + GUNSHIP_ACCEL_RATE, self.MaxVelocity)
    local delta, faceYaw = self:GetFlightGoal(reach, deltatime)
    local goalAccel = self:UpdateFlightLift(delta, velocity, deltatime)
    local lift = self:GetUp() * self.flightLift
    local linearAccel = Vector(lift.x, lift.y, self:GetWorldGravity() - DYING_SINK_ACCEL)

    linearAccel:Sub(self:GetFlightDrag(velocity, DYING_SIDEWAYS_DRAG))

    local angularAccel = self:GetFlightAngularAccel(phys, goalAccel, faceYaw, deltatime)

    return self:PhysicsSimulateOverride(angularAccel, phys:WorldToLocalVector(linearAccel), phys, deltatime, SIM_LOCAL_ACCELERATION)
end

--- Gives the gunship a sudden push, as ApplyAbsVelocityImpulse does in the original.
---@param impulse Vector World space change of velocity.
function ENT:ApplyVelocityImpulse(impulse)
    local phys = self:GetPhysicsObject()
    if ( !IsValid(phys) ) then return end

    phys:AddVelocity(impulse)
end
