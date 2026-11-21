AddCSLuaFile("cl_init.lua")
AddCSLuaFile("lvs_hl2/sh_civilian.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local SEATS = {
    {pos = Vector(-13.4, 17.7, 15.4)},
    {pos = Vector(-8.4, -17.7, 17.6)},
    {pos = Vector(-50, 17.7, 17.6)},
    {pos = Vector(-50, -17.7, 17.6)},
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

    self:AddEngine(Vector(61.3, 0, 34.5))
    self:AddFuelTank(Vector(-85, 0, 20), Angle(0, 0, 0), 600, LVS.FUELTYPE_PETROL)

    lvsHL2.AddRiggedWheels(self, 14.7, 14.7, DRIVE)
end
