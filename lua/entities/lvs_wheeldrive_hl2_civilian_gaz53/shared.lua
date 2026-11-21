--- A Soviet medium lorry fitted with a skip loader frame.

include("lvs_hl2/sh_civilian.lua")

ENT.Base = "lvs_wheeldrive_truckbase"
ENT.PrintName = "GAZ-53 Skip Loader"
ENT.Author = "Riggs"
ENT.Information = ""
ENT.Category = "[LVS] - Half Life 2"
ENT.IconOverride = "materials/entities/lvs/hl2/civilian_gaz53.png"

ENT.AITEAM = 0
ENT.AdminSpawnable = false
ENT.EngineCurve = 0.25
ENT.EngineTorque = 300
ENT.MDL = "models/source_vehicles/truck003a_01.mdl"
ENT.MassCenterOverride = Vector(-40, 0, 40)
ENT.MaxHealth = 1600
ENT.MaxVelocity = 1200
ENT.PhysicsMass = 3200
ENT.PhysicsInertia = Vector(4800, 4800, 2400)
ENT.WheelPhysicsMass = 200
ENT.SpawnNormalOffset = 20
ENT.Spawnable = true
ENT.TransGears = 4
ENT.TransGearsReverse = 1
ENT.VehicleCategory = "Half Life 2"
ENT.VehicleSubCategory = "Civilian"

ENT.HornSound = "lvs/horn4.wav"
ENT.HornPos = Vector(90, 0, 40)

ENT.EngineSounds = lvsHL2.BuildEngineSounds(60, 20, 80)

ENT.ExhaustPositions = {
    {
        pos = Vector(-30, -50, 25),
        ang = Angle(0, 270, 0),
    },
}

ENT.Lights = lvsHL2.BuildCarLights({
    headlights = lvsHL2.Pair(Vector(88, 36.9, 40.4)),
    taillights = lvsHL2.Pair(Vector(-194, 42.8, 16.1)),
    reverse = lvsHL2.Pair(Vector(-194, 42.8, 21.7)),
})
