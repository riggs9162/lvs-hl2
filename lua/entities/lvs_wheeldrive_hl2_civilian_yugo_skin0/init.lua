AddCSLuaFile("cl_init.lua")
AddCSLuaFile("lvs_hl2/sh_civilian.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local SEATS = {
    {pos = Vector(-14.9, 17.2, 12.6)},
    {pos = Vector(-10, -17.2, 17.3)},
    {pos = Vector(-40, 17.2, 17.3)},
    {pos = Vector(-40, -17.2, 17.3)},
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

    self:AddEngine(Vector(50.5, 0, 34.7))
    self:AddFuelTank(Vector(-55, 0, 20), Angle(0, 0, 0), 450, LVS.FUELTYPE_PETROL)

    lvsHL2.AddRiggedWheels(self, 12.3, 12.3, DRIVE)
end
