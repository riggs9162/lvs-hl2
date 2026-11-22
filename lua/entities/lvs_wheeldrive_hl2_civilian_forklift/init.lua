AddCSLuaFile("cl_init.lua")
AddCSLuaFile("lvs_hl2/sh_civilian.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")
include("lvs_hl2/sv_wheeldrive_ai.lua")

local SEATS = {
    {pos = Vector(-40.4, -0.5, 64.1)},
}

local DRIVE = {
    frontTorque = 1,
    rearTorque = 0,
    steerAngle = 45,
    bRearSteer = true,
    drop = 10,
    height = 10,
    travel = 6,
}

--- Adds the seats, engine, fuel tank and rigged wheels once the vehicle has spawned.
---@param PObj PhysObj Physics object of the vehicle.
function ENT:OnSpawn(PObj)
    lvsHL2.AddSeats(self, SEATS, 70)

    self:AddEngine(Vector(-81.1, -0.5, 52.4))
    self:AddFuelTank(Vector(-60, 0, 40), Angle(0, 0, 0), 500, LVS.FUELTYPE_DIESEL)
    self:AddReverseSound(Vector(-90, 0, 60))

    lvsHL2.AddRiggedWheels(self, 19.2, 15.2, DRIVE)
end
