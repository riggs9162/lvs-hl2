AddCSLuaFile("cl_init.lua")
AddCSLuaFile("cl_sounds.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")
include("sv_damage.lua")
include("lvs_hl2/sv_dropship_cargo.lua")

DEFINE_BASECLASS("lvs_base_wheeldrive")

--- Radius of the wheels, from the Half-Life 2 vehicle script (scripts/vehicles/apc.txt).
local WHEEL_RADIUS = 28

--- Degrees the front wheels steer, from the vehicle script.
local STEER_ANGLE = 26

--- Share of the engine torque on the front and rear wheels, from the vehicle script.
local FRONT_TORQUE_FACTOR = 0.8
local REAR_TORQUE_FACTOR = 0.2

--- Share of the brake force on each axle, from the vehicle script.
local BRAKE_FACTOR = 0.5

--- Suspension of both axles.
local SUSPENSION = {
    Height = 24,
    MaxTravel = 8,
    ControlArmLength = 128,
    SpringConstant = 5000,
    SpringDamping = 1000,
    SpringRelativeDamping = 1000,
}

--- Adds the wheels with the steering, drive and brakes of the Half-Life 2 vehicle script.
---@param frontRadius number|nil Radius of the front wheels, by default that of the script.
---@param rearRadius number|nil Radius of the rear wheels, by default that of the script.
function ENT:AddHL2Wheels(frontRadius, rearRadius)
    local FL, FR, RL, RR, ForwardAngle = self:AddWheelsUsingRig(frontRadius or WHEEL_RADIUS, rearRadius or WHEEL_RADIUS)

    self:DefineAxle({
        Axle = {
            ForwardAngle = ForwardAngle,
            SteerType = LVS.WHEEL_STEER_FRONT,
            SteerAngle = STEER_ANGLE,
            TorqueFactor = FRONT_TORQUE_FACTOR,
            BrakeFactor = BRAKE_FACTOR,
        },
        Wheels = {FL, FR},
        Suspension = table.Copy(SUSPENSION),
    })

    self:DefineAxle({
        Axle = {
            ForwardAngle = ForwardAngle,
            SteerType = LVS.WHEEL_STEER_NONE,
            TorqueFactor = REAR_TORQUE_FACTOR,
            BrakeFactor = BRAKE_FACTOR,
            UseHandbrake = true,
        },
        Wheels = {RL, RR},
        Suspension = table.Copy(SUSPENSION),
    })
end

function ENT:OnSpawn(PObj)
    local DriverSeat = self:AddDriverSeat(Vector(-30, 0, 65), Angle(0, 270, 0))
    DriverSeat.ExitPos = Vector(-44.58, 13.57, 69.06)

    -- add 6 seats
    local PassengerSeat

    for i = 1, 6 do
        local pos, ang = Vector(-52, -30, 50), Angle(0, 0, 0)
        pos.x = pos.x - (i - 1) * 24
        if ( i > 3 ) then
            pos.y = pos.y + 60
            pos.x = pos.x + 72
            ang.y = ang.y + 180
        end

        PassengerSeat = self:AddPassengerSeat(pos, ang)
        PassengerSeat.ExitPos = Vector(0, -170, 64)
    end

    self:AddEngine(Vector(80, 0, 50))
    self:AddHL2Wheels()

    self:ManipulateBoneScale(self:LookupBone("APC.Gun_Base"), vector_origin)

    local var = GetConVar("lvs_car_hl2_combineapc_health") and GetConVar("lvs_car_hl2_combineapc_health"):GetInt() or 750
    self.MaxHealth = var
    self:SetHP(var)

    if ( self.PostOnSpawn ) then self:PostOnSpawn(PObj) end
end

--- Holds the APC to its place while a dropship carries it, and otherwise drives it as any LVS vehicle.
---@param phys PhysObj
---@param deltatime number
function ENT:PhysicsSimulate(phys, deltatime)
    if ( phys:GetEntity() == self ) then
        local angularAccel, linearAccel, simulate = self:SimulateHL2DropshipCarry(phys, deltatime)

        if ( simulate ) then return angularAccel, linearAccel, simulate end
    end

    return BaseClass.PhysicsSimulate(self, phys, deltatime)
end

function ENT:OnDriverEnterVehicle(client)
    self:ResetSequence("enter" .. math.random(1, 2))

    if ( self.HL2APC ) then
        self:EmitSound("combine.door_lock")
    end
end

function ENT:OnDriverExitVehicle(client)
    self:ResetSequence("exit" .. math.random(1, 2))
end
