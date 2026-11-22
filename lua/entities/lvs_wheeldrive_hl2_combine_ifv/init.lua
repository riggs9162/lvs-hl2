AddCSLuaFile("cl_init.lua")
AddCSLuaFile("lvs_hl2/cl_engine_sounds.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")
include("lvs_hl2/sv_wheeldrive_ai.lua")

function ENT:OnSpawn(PObj)
    local DriverSeat = self:AddDriverSeat(Vector(30, -25, 104), Angle(0, 270, 0))
    DriverSeat.HidePlayer = true
    DriverSeat.ExitPos = Vector(30, -90, 30)

    local PassengerSeat = self:AddPassengerSeat(Vector(30, 25, 104), Angle(0, 270, 0))
        PassengerSeat.HidePlayer = true
    PassengerSeat.ExitPos = Vector(30, 90, 30)

    -- the rear compartment holds 10 troops, two benches of 5 facing each other
    for i = 1, 10 do
        local pos, ang = Vector(-20, 30, 60), Angle(0, 180, 0)
        pos.x = pos.x - (i - 1) * 26

        if ( i > 5 ) then
            pos.x = -20 - (i - 6) * 26
            pos.y = -pos.y
            ang.y = 0
        end

        PassengerSeat = self:AddPassengerSeat(pos, ang)
        PassengerSeat.HidePlayer = true
        PassengerSeat.ExitPos = Vector(-190, 0, 30)
    end

    self:AddEngine(Vector(108, 0, 37))
    self:AddFuelTank(Vector(30, -60, 70), Angle(0, 0, 0), 600, LVS.FUELTYPE_DIESEL)

    local WheelFrontLeft = self:AddWheel({
        pos = Vector(77, 40, 24),
        hide = true,
        radius = 12,
    })

    local WheelFrontRight = self:AddWheel({
        pos = Vector(77, -40, 24),
        hide = true,
        radius = 12,
    })

    local WheelMiddleLeft = self:AddWheel({
        pos = Vector(-43, 40, 23),
        hide = true,
        radius = 12,
    })

    local WheelMiddleRight = self:AddWheel({
        pos = Vector(-43, -40, 23),
        hide = true,
        radius = 12,
    })

    local WheelRearLeft = self:AddWheel({
        pos = Vector(-95, 40, 23),
        hide = true,
        radius = 12,
    })

    local WheelRearRight = self:AddWheel({
        pos = Vector(-95, -40, 23),
        hide = true,
        radius = 12,
    })

    local SuspensionSettings = {
        Height = 20,
        MaxTravel = 15,
        ControlArmLength = 60,
        SpringConstant = 50000,
        SpringDamping = 3000,
        SpringRelativeDamping = 3000,
    }

    self:DefineAxle({
        Axle = {
            ForwardAngle = Angle(0, 0, 0),
            SteerType = LVS.WHEEL_STEER_FRONT,
            SteerAngle = 35,
            TorqueFactor = 0.4,
            BrakeFactor = 1,
        },
        Wheels = {WheelFrontLeft, WheelFrontRight},
        Suspension = SuspensionSettings,
    })

    self:DefineAxle({
        Axle = {
            ForwardAngle = Angle(0, 0, 0),
            SteerType = LVS.WHEEL_STEER_NONE,
            TorqueFactor = 0.3,
            BrakeFactor = 1,
        },
        Wheels = {WheelMiddleLeft, WheelMiddleRight},
        Suspension = SuspensionSettings,
    })

    self:DefineAxle({
        Axle = {
            ForwardAngle = Angle(0, 0, 0),
            SteerType = LVS.WHEEL_STEER_NONE,
            TorqueFactor = 0.3,
            BrakeFactor = 1,
            UseHandbrake = true,
        },
        Wheels = {WheelRearLeft, WheelRearRight},
        Suspension = SuspensionSettings,
    })

    local var = GetConVar("lvs_car_hl2_combineifv_health") and GetConVar("lvs_car_hl2_combineifv_health"):GetInt() or 2000
    self.MaxHealth = var
    self:SetHP(var)
end
