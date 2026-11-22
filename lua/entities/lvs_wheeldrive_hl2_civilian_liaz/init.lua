AddCSLuaFile("cl_init.lua")
AddCSLuaFile("lvs_hl2/sh_civilian.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")
include("lvs_hl2/sv_wheeldrive_ai.lua")

local SEATS = {
    {pos = Vector(55, 24.5, 54.8)},
    {pos = Vector(55, -24.5, 66)},
}

local DRIVE = {
    frontTorque = 0,
    rearTorque = 1,
    steerAngle = 35,
    drop = 14,
}

--- Adds the seats, engine, fuel tank and rigged wheels once the vehicle has spawned.
---@param PObj PhysObj Physics object of the vehicle.
function ENT:OnSpawn(PObj)
    lvsHL2.AddSeats(self, SEATS, 95)

    self:AddEngine(Vector(111.5, 0, 63.4))
    self:AddFuelTank(Vector(-5, 45, 40), Angle(0, 0, 0), 1200, LVS.FUELTYPE_DIESEL)

    lvsHL2.AddRiggedWheels(self, 24, 24, DRIVE)
end
