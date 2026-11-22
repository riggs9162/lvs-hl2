AddCSLuaFile("cl_init.lua")
AddCSLuaFile("lvs_hl2/cl_engine_sounds.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")
include("lvs_hl2/sv_wheeldrive_ai.lua")

function ENT:OnSpawn(PObj)
    local DriverSeat = self:AddDriverSeat(Vector(85, 27, 32), Angle(0, 270, 0))
    DriverSeat.ExitPos = Vector(85, 90, 40)

    local PassengerSeat = self:AddPassengerSeat(Vector(97, -27, 33), Angle(0, 270, 0))
    PassengerSeat.ExitPos = Vector(97, -90, 40)

    -- rear compartment, two benches facing each other
    local rearSeats = {
        {pos = Vector(-30, -23, 24), ang = Angle(0, 270, 0)},
        {pos = Vector(-30, 23, 24), ang = Angle(0, 270, 0)},
        {pos = Vector(-30, 0, 24), ang = Angle(0, 270, 0)},
        {pos = Vector(30, -31, 24), ang = Angle(0, 90, 0)},
        {pos = Vector(30, 31, 24), ang = Angle(0, 90, 0)},
        {pos = Vector(30, 0, 24), ang = Angle(0, 90, 0)},
    }

    for _, seat in ipairs(rearSeats) do
        PassengerSeat = self:AddPassengerSeat(seat.pos, seat.ang)
        PassengerSeat.ExitPos = Vector(-160, 0, 40)
    end

    self:AddEngine(Vector(140, 0, 30))
    self:AddFuelTank(Vector(-60, 0, 15), Angle(0, 0, 0), 700, LVS.FUELTYPE_DIESEL)

    local WheelModel = "models/glide/gtav/hvy_brickade_3/wheel_c17.mdl"
    local WheelFrontLeft = self:AddWheel({
        pos = Vector(79, 46, -12),
        mdl = WheelModel,
        mdl_ang = Angle(0, 90, 0),
        radius = 24,
        width = 13,
    })

    local WheelFrontRight = self:AddWheel({
        pos = Vector(79, -46, -12),
        mdl = WheelModel,
        mdl_ang = Angle(0, 270, 0),
        radius = 24,
        width = 13,
    })

    local WheelRearLeft = self:AddWheel({
        pos = Vector(-79, 46, -12),
        mdl = WheelModel,
        mdl_ang = Angle(0, 90, 0),
        radius = 24,
        width = 13,
    })

    local WheelRearRight = self:AddWheel({
        pos = Vector(-79, -46, -12),
        mdl = WheelModel,
        mdl_ang = Angle(0, 270, 0),
        radius = 24,
        width = 13,
    })

    local SuspensionSettings = {
        Height = 15,
        MaxTravel = 10,
        ControlArmLength = 60,
        SpringConstant = 70000,
        SpringDamping = 6000,
        SpringRelativeDamping = 6000,
    }

    self:DefineAxle({
        Axle = {
            ForwardAngle = Angle(0, 0, 0),
            SteerType = LVS.WHEEL_STEER_FRONT,
            SteerAngle = 25,
            TorqueFactor = 0.1,
            BrakeFactor = 1,
        },
        Wheels = {WheelFrontLeft, WheelFrontRight},
        Suspension = SuspensionSettings,
    })

    self:DefineAxle({
        Axle = {
            ForwardAngle = Angle(0, 0, 0),
            SteerType = LVS.WHEEL_STEER_NONE,
            TorqueFactor = 0.9,
            BrakeFactor = 1,
            UseHandbrake = true,
        },
        Wheels = {WheelRearLeft, WheelRearRight},
        Suspension = SuspensionSettings,
    })

    self:SetColor(Color(25, 25, 25, 255))
    self:SetBodygroup(6, math.random(0, 1))
    self:SetBodygroup(7, math.random(0, 1))

    local var = GetConVar("lvs_car_hl2_combinebrickade_health") and GetConVar("lvs_car_hl2_combinebrickade_health"):GetInt() or 2500
    self.MaxHealth = var
    self:SetHP(var)
end
