AddCSLuaFile("cl_init.lua")
AddCSLuaFile("lvs_hl2/sh_civilian.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local SEATS = {
    {pos = Vector(-14.4, 19.7, 18.4)},
    {pos = Vector(-11.9, -19.7, 23.1)},
    {pos = Vector(-55, 19.8, 23.1)},
    {pos = Vector(-55, -19.8, 23.1)},
}

local DRIVE = {
    frontTorque = 0,
    rearTorque = 1,
    steerAngle = 30,
}

--- Adds the seats, engine, fuel tank and rigged wheels once the vehicle has spawned.
---@param PObj PhysObj Physics object of the vehicle.
function ENT:OnSpawn(PObj)
    lvsHL2.AddSeats(self, SEATS, 70)

    self:AddEngine(Vector(-86.5, 0, 31.8))
    self:AddFuelTank(Vector(60, 0, 25), Angle(0, 0, 0), 450, LVS.FUELTYPE_PETROL)

    lvsHL2.AddRiggedWheels(self, 14.7, 14.7, DRIVE)
end
