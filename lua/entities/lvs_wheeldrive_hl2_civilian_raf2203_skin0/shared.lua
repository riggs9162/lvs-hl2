--- A Latvian minibus with seats for six.

include("lvs_hl2/sh_civilian.lua")

ENT.Base = "lvs_base_wheeldrive"
ENT.PrintName = "RAF-2203 Latvija (White)"
ENT.Author = "Riggs"
ENT.Information = ""
ENT.Category = "[LVS] - Half Life 2"
ENT.IconOverride = "materials/entities/lvs/hl2/civilian_raf2203_skin0.png"

ENT.AITEAM = 0
ENT.AdminSpawnable = false
ENT.EngineCurve = 0.35
ENT.EngineTorque = 170
ENT.MDL = "models/source_vehicles/van001a_01.mdl"
ENT.MaxHealth = 1000
ENT.MaxVelocity = 1350
ENT.PhysicsMass = 1600
ENT.PhysicsInertia = Vector(2400, 2400, 1200)
ENT.WheelPhysicsMass = 150
ENT.SpawnNormalOffset = 14
ENT.Spawnable = true
ENT.TransGears = 4
ENT.TransGearsReverse = 1
ENT.VehicleCategory = "Half Life 2"
ENT.VehicleSubCategory = "Civilian"

ENT.HornSound = "lvs/horn2.wav"
ENT.HornPos = Vector(95, 0, 35)

ENT.EngineSounds = lvsHL2.BuildEngineSounds(80, 25)
ENT.TireSoundTypes = lvsHL2.BuildCarTireSounds()

ENT.ExhaustPositions = {
    {
        pos = Vector(-120, -25, 15),
        ang = Angle(0, 180, 0),
    },
}

ENT.Lights = lvsHL2.BuildCarLights({
    headlights = lvsHL2.Pair(Vector(94.1, 36.3, 32.9)),
    taillights = lvsHL2.Pair(Vector(-124, 31.3, 39.4)),
    reverse = lvsHL2.Pair(Vector(-124, 31.3, 35)),
})
