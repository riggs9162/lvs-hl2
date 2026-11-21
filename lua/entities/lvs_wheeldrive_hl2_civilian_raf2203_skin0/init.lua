AddCSLuaFile("cl_init.lua")
AddCSLuaFile("lvs_hl2/sh_civilian.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local SEATS = {
    {pos = Vector(27, 23.5, 28.3)},
    {pos = Vector(32, -23.5, 35)},
    {pos = Vector(-25, 23, 35)},
    {pos = Vector(-25, -23, 35)},
    {pos = Vector(-75, 23, 35)},
    {pos = Vector(-75, -23, 35)},
}

local DRIVE = {
    frontTorque = 0,
    rearTorque = 1,
    steerAngle = 32,
}

--- Adds the seats, engine, fuel tank and rigged wheels once the vehicle has spawned.
---@param PObj PhysObj Physics object of the vehicle.
function ENT:OnSpawn(PObj)
    lvsHL2.AddSeats(self, SEATS, 85)

    self:AddEngine(Vector(86, 0, 41.4))
    self:AddFuelTank(Vector(-90, 0, 22), Angle(0, 0, 0), 700, LVS.FUELTYPE_PETROL)

    lvsHL2.AddRiggedWheels(self, 16.3, 16.3, DRIVE)
end
