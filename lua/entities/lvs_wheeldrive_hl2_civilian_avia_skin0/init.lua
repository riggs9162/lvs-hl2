AddCSLuaFile("cl_init.lua")
AddCSLuaFile("lvs_hl2/sh_civilian.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local SEATS = {
    {pos = Vector(65.6, 20.7, 43.5)},
    {pos = Vector(70.6, -20.7, 50.2)},
    {pos = Vector(10, 22, 46)},
    {pos = Vector(10, -22, 46)},
    {pos = Vector(-45, 22, 46)},
    {pos = Vector(-45, -22, 46)},
}

local DRIVE = {
    frontTorque = 0,
    rearTorque = 1,
    steerAngle = 35,
}

--- Adds the seats, engine, fuel tank and rigged wheels once the vehicle has spawned.
---@param PObj PhysObj Physics object of the vehicle.
function ENT:OnSpawn(PObj)
    lvsHL2.AddSeats(self, SEATS, 85)

    self:AddEngine(Vector(79.9, 0, 43.3))
    self:AddFuelTank(Vector(0, -38, 25), Angle(0, 0, 0), 1000, LVS.FUELTYPE_DIESEL)

    lvsHL2.AddRiggedWheels(self, 16.5, 16.5, DRIVE)
end
