--- An East German two-stroke estate with front wheel drive.

include("lvs_hl2/sh_civilian.lua")

ENT.Base = "lvs_base_wheeldrive"
ENT.PrintName = "Trabant 601 Universal"
ENT.Author = "Riggs"
ENT.Information = ""
ENT.Category = "[LVS] - Half Life 2"
ENT.IconOverride = "materials/entities/lvs/hl2/civilian_trabant.png"

ENT.AITEAM = 0
ENT.AdminSpawnable = false
ENT.EngineCurve = 0.45
ENT.EngineTorque = 90
ENT.MDL = "models/source_vehicles/car002a.mdl"
ENT.MaxHealth = 500
ENT.MaxVelocity = 1150
ENT.PhysicsMass = 650
ENT.SpawnNormalOffset = 14
ENT.Spawnable = true
ENT.TransGears = 4
ENT.TransGearsReverse = 1
ENT.VehicleCategory = "Half Life 2"
ENT.VehicleSubCategory = "Civilian"

ENT.HornSound = "lvs/horn5.wav"
ENT.HornPos = Vector(65, 0, 30)

ENT.EngineSounds = lvsHL2.BuildEngineSounds(110, 35)
ENT.TireSoundTypes = lvsHL2.BuildCarTireSounds()

ENT.ExhaustPositions = {
    {
        pos = Vector(-74, -20, 14),
        ang = Angle(0, 180, 0),
    },
}

ENT.Lights = lvsHL2.BuildCarLights({
    headlights = lvsHL2.Pair(Vector(71.7, 28.7, 30.7)),
    taillights = lvsHL2.Pair(Vector(-76, 31, 25.8)),
    reverse = lvsHL2.Pair(Vector(-76, 30.9, 31.2)),
})
