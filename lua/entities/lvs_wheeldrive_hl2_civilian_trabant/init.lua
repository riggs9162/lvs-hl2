AddCSLuaFile("cl_init.lua")
AddCSLuaFile("lvs_hl2/sh_civilian.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local SEATS = {
    {pos = Vector(-11.6, 14.2, 12)},
    {pos = Vector(-9.1, -14.2, 16.7)},
}

local DRIVE = {
    frontTorque = 1,
    rearTorque = 0,
    steerAngle = 32,
}

--- Adds the seats, engine, fuel tank and rigged wheels once the vehicle has spawned.
---@param PObj PhysObj Physics object of the vehicle.
function ENT:OnSpawn(PObj)
    lvsHL2.AddSeats(self, SEATS, 60)

    self:AddEngine(Vector(51.3, 0, 36.2))
    self:AddFuelTank(Vector(40, 0, 30), Angle(0, 0, 0), 400, LVS.FUELTYPE_PETROL)

    lvsHL2.AddRiggedWheels(self, 12.3, 12.3, DRIVE)
end
