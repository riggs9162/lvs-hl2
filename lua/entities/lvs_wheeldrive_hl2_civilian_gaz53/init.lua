AddCSLuaFile("cl_init.lua")
AddCSLuaFile("lvs_hl2/sh_civilian.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")
include("lvs_hl2/sv_wheeldrive_ai.lua")

local SEATS = {
    {pos = Vector(-11.7, 20.4, 42.4)},
    {pos = Vector(-6.7, -20.4, 51.1)},
}

local DRIVE = {
    frontTorque = 0,
    rearTorque = 1,
    steerAngle = 35,
}

--- Adds the seats, engine, fuel tank and rigged wheels once the vehicle has spawned.
---@param PObj PhysObj Physics object of the vehicle.
function ENT:OnSpawn(PObj)
    lvsHL2.AddSeats(self, SEATS, 90)

    self:AddEngine(Vector(56.2, 0, 60.7))
    self:AddFuelTank(Vector(-60, 45, 30), Angle(0, 0, 0), 1000, LVS.FUELTYPE_PETROL)

    lvsHL2.AddRiggedWheels(self, 19.2, 22.5, DRIVE)
end
