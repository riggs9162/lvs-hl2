AddCSLuaFile("cl_init.lua")
AddCSLuaFile("lvs_hl2/sh_civilian.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")
include("lvs_hl2/sv_wheeldrive_ai.lua")

local SEATS = {
    {pos = Vector(-16.8, 16.1, 14.7)},
    {pos = Vector(-11.8, -16.1, 18.4)},
    {pos = Vector(-52, 17.8, 18.4)},
    {pos = Vector(-52, -17.8, 18.4)},
}

local DRIVE = {
    frontTorque = 0,
    rearTorque = 1,
    steerAngle = 30,
}

--- Adds the seats, engine, fuel tank and rigged wheels once the vehicle has spawned.
---@param PObj PhysObj Physics object of the vehicle.
function ENT:OnSpawn(PObj)
    lvsHL2.AddSeats(self, SEATS, 65)

    self:AddEngine(Vector(53.8, 0, 36.1))
    self:AddFuelTank(Vector(-75, 0, 20), Angle(0, 0, 0), 550, LVS.FUELTYPE_PETROL)

    lvsHL2.AddRiggedWheels(self, 14.9, 14.9, DRIVE)
end
