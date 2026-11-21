--- A heavy Czechoslovak tractor unit with twin rear wheels.

include("lvs_hl2/sh_civilian.lua")

ENT.Base = "lvs_wheeldrive_truckbase"
ENT.PrintName = "LIAZ Skoda 706 RT"
ENT.Author = "Riggs"
ENT.Information = ""
ENT.Category = "[LVS] - Half Life 2"
ENT.IconOverride = "materials/entities/lvs/hl2/civilian_liaz.png"

ENT.AITEAM = 0
ENT.AdminSpawnable = false
ENT.EngineCurve = 0.2
ENT.EngineTorque = 380
ENT.MDL = "models/source_vehicles/truck002a_cab.mdl"
ENT.MaxHealth = 1800
ENT.MaxVelocity = 1150
ENT.PhysicsMass = 4000
ENT.PhysicsInertia = Vector(6000, 6000, 3000)
ENT.WheelPhysicsMass = 200
ENT.SpawnNormalOffset = 20
ENT.Spawnable = true
ENT.TransGears = 5
ENT.TransGearsReverse = 1
ENT.VehicleCategory = "Half Life 2"
ENT.VehicleSubCategory = "Civilian"

ENT.HornSound = "lvs/horn4.wav"
ENT.HornPos = Vector(125, 0, 45)

ENT.EngineSounds = lvsHL2.BuildEngineSounds(55, 18, 80)

ENT.ExhaustPositions = {
    {
        pos = Vector(15, -52, 35),
        ang = Angle(90, 0, 0),
    },
}

ENT.Lights = lvsHL2.BuildCarLights({
    headlights = lvsHL2.Pair(Vector(126.6, 33.7, 43.4)),
    taillights = lvsHL2.Pair(Vector(-118, 46, 35.7)),
    reverse = lvsHL2.Pair(Vector(-118, 34, 35.7)),
})
