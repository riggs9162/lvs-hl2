AddCSLuaFile("cl_init.lua")
AddCSLuaFile("cl_sounds.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")
include("lvs_hl2/sv_wheeldrive_ai.lua")
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

--- The seats, as the model's attachments that mark them. Each attachment faces where its occupant looks.
--- The positions are fallbacks for a model without the attachments.
local DRIVER_SEAT = {attachment = "seat_driver", pos = Vector(-30, 0, 65), facing = 0}
local PASSENGER_SEATS = {
    {attachment = "seat_passenger1", pos = Vector(-50, -23, 50), facing = 90},
    {attachment = "seat_passenger2", pos = Vector(-69, -23, 50), facing = 90},
    {attachment = "seat_passenger3", pos = Vector(-88, -23, 50), facing = 90},
    {attachment = "seat_passenger4", pos = Vector(-50, 23, 50), facing = -90},
    {attachment = "seat_passenger5", pos = Vector(-69, 23, 50), facing = -90},
    {attachment = "seat_passenger6", pos = Vector(-88, 23, 50), facing = -90},
}

--- Returns where a seat goes and how its pod is turned, in the vehicle's own space.
--- A pod's occupant looks along its +Y, a quarter turn left of the attachment's forward.
---@param seat table An entry of DRIVER_SEAT or PASSENGER_SEATS.
---@return Vector pos
---@return Angle ang
function ENT:GetSeatPlacement(seat)
    local id = self:LookupAttachment(seat.attachment)
    local data = id and id > 0 and self:GetAttachment(id)

    if ( data ) then
        local pos = self:WorldToLocal(data.Pos)
        local ang = self:WorldToLocalAngles(data.Ang)

        return pos, Angle(0, ang.y - 90, 0)
    end

    return seat.pos, Angle(0, seat.facing - 90, 0)
end

--- Where troops step out, behind the rear doors.
local REAR_EXIT_X = -160
local REAR_EXIT_Z = 40

--- Seconds the rear doors stay open after a troop gets in or out.
local REAR_DOORS_OPEN_TIME = 2.5

--- Opens the rear doors for a moment.
function ENT:OpenRearDoors()
    if ( !self.SetRearDoorsOpenUntil ) then return end

    local wasClosed = self:GetRearDoorsOpenUntil() < CurTime()

    self:SetRearDoorsOpenUntil(CurTime() + REAR_DOORS_OPEN_TIME)

    if ( wasClosed ) then
        self:EmitSound("doors/doormove2.wav", 70, 110)
    end
end

--- Returns the APC whose passenger seat the vehicle is, if any.
---@param vehicle Vehicle
---@return Entity|nil
local function GetTroopAPC(vehicle)
    if ( !IsValid(vehicle) ) then return end

    local apc = vehicle:GetParent()
    if ( !IsValid(apc) or !apc.OpenRearDoors or apc:GetModel() != apc.MDL ) then return end
    if ( IsValid(apc.GetDriverSeat and apc:GetDriverSeat()) and apc:GetDriverSeat() == vehicle ) then return end

    return apc
end

hook.Add("PlayerEnteredVehicle", "lvs_hl2_combine_apc_rear_doors", function(client, vehicle)
    local apc = GetTroopAPC(vehicle)
    if ( apc ) then apc:OpenRearDoors() end
end)

hook.Add("PlayerLeaveVehicle", "lvs_hl2_combine_apc_rear_doors", function(client, vehicle)
    local apc = GetTroopAPC(vehicle)
    if ( apc ) then apc:OpenRearDoors() end
end)

function ENT:OnSpawn(PObj)
    -- Read the seat attachments in the pose the APC idles in, as the frame bone turns in its animations.
    -- The server works out attachment positions from the current sequence when asked.
    self:ResetSequence(self:LookupSequence("idle"))
    self:SetCycle(0)

    local DriverSeat = self:AddDriverSeat(self:GetSeatPlacement(DRIVER_SEAT))
    DriverSeat.ExitPos = Vector(-44.58, 13.57, 69.06)

    -- Six troops on the two benches of the troop bay, facing each other across the aisle.
    for _, seat in ipairs(PASSENGER_SEATS) do
        local pos, ang = self:GetSeatPlacement(seat)
        local PassengerSeat = self:AddPassengerSeat(pos, ang)
        PassengerSeat.ExitPos = Vector(REAR_EXIT_X, pos.y * 0.6, REAR_EXIT_Z)
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
