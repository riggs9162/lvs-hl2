--- A slow warehouse forklift that steers with its rear wheels.

include("lvs_hl2/sh_civilian.lua")

ENT.Base = "lvs_wheeldrive_truckbase"
ENT.PrintName = "Forklift (Episode 2)"
ENT.Author = "Riggs"
ENT.Information = ""
ENT.Category = "[LVS] - Half Life 2"
ENT.IconOverride = "materials/entities/lvs/hl2/civilian_forklift.png"

ENT.AITEAM = 0
ENT.AdminSpawnable = false
ENT.EngineCurve = 0.2
ENT.EngineTorque = 220
ENT.MDL = "models/source_vehicles/forklift_ep2.mdl"
ENT.MaxHealth = 800
ENT.MaxVelocity = 450
ENT.MaxVelocityReverse = 300
ENT.PhysicsMass = 2500
ENT.PhysicsInertia = Vector(3750, 3750, 1875)
ENT.WheelPhysicsMass = 150
ENT.SpawnNormalOffset = 20
ENT.Spawnable = true
ENT.TransGears = 1
ENT.TransGearsReverse = 1
ENT.VehicleCategory = "Half Life 2"
ENT.VehicleSubCategory = "Civilian"

ENT.HornSound = "lvs/horn5.wav"
ENT.HornPos = Vector(0, 0, 60)

ENT.EngineSounds = lvsHL2.BuildEngineSounds(70, 30)

ENT.ExhaustPositions = {
    {
        pos = Vector(-95, 15, 30),
        ang = Angle(0, 180, 0),
    },
}
