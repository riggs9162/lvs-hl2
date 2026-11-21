--- A small Soviet saloon with its air-cooled engine and drive at the rear.

include("lvs_hl2/sh_civilian.lua")

ENT.Base = "lvs_base_wheeldrive"
ENT.PrintName = "ZAZ-968 Zaporozhets"
ENT.Author = "Riggs"
ENT.Information = ""
ENT.Category = "[LVS] - Half Life 2"
ENT.IconOverride = "materials/entities/lvs/hl2/civilian_zaz968.png"

ENT.AITEAM = 0
ENT.AdminSpawnable = false
ENT.EngineCurve = 0.4
ENT.EngineTorque = 120
ENT.MDL = "models/source_vehicles/car005a.mdl"
ENT.MaxHealth = 700
ENT.MaxVelocity = 1300
ENT.PhysicsMass = 800
ENT.SpawnNormalOffset = 14
ENT.Spawnable = true
ENT.TransGears = 4
ENT.TransGearsReverse = 1
ENT.VehicleCategory = "Half Life 2"
ENT.VehicleSubCategory = "Civilian"

ENT.HornSound = "lvs/horn5.wav"
ENT.HornPos = Vector(75, 0, 30)

ENT.EngineSounds = lvsHL2.BuildEngineSounds(100, 30)
ENT.TireSoundTypes = lvsHL2.BuildCarTireSounds()

ENT.ExhaustPositions = {
    {
        pos = Vector(-102, -28, 15),
        ang = Angle(0, 180, 0),
    },
}

ENT.Lights = lvsHL2.BuildCarLights({
    headlights = lvsHL2.Pair(Vector(79.5, 30.5, 32.7)),
    taillights = lvsHL2.Pair(Vector(-102, 23.7, 29.9)),
    reverse = lvsHL2.Pair(Vector(-102, 18.8, 29.9)),
})
