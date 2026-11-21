--- A rusted Yugoslav hatchback with front wheel drive.

include("lvs_hl2/sh_civilian.lua")

ENT.Base = "lvs_base_wheeldrive"
ENT.PrintName = "Zastava Yugo (Rust)"
ENT.Author = "Riggs"
ENT.Information = ""
ENT.Category = "[LVS] - Half Life 2"
ENT.IconOverride = "materials/entities/lvs/hl2/civilian_yugo_skin0.png"

ENT.AITEAM = 0
ENT.AdminSpawnable = false
ENT.EngineCurve = 0.4
ENT.EngineTorque = 110
ENT.MDL = "models/source_vehicles/car001a_hatchback_skin0.mdl"
ENT.MaxHealth = 600
ENT.MaxVelocity = 1300
ENT.PhysicsMass = 800
ENT.SpawnNormalOffset = 14
ENT.Spawnable = true
ENT.TransGears = 4
ENT.TransGearsReverse = 1
ENT.VehicleCategory = "Half Life 2"
ENT.VehicleSubCategory = "Civilian"

ENT.HornSound = "lvs/horn5.wav"
ENT.HornPos = Vector(65, 0, 30)

ENT.EngineSounds = lvsHL2.BuildEngineSounds(95, 30)
ENT.TireSoundTypes = lvsHL2.BuildCarTireSounds()

ENT.ExhaustPositions = {
    {
        pos = Vector(-74, -18, 14),
        ang = Angle(0, 180, 0),
    },
}

ENT.Lights = lvsHL2.BuildCarLights({
    headlights = lvsHL2.Pair(Vector(68.7, 23.2, 29)),
    taillights = lvsHL2.Pair(Vector(-76, 26.4, 36.4)),
    reverse = lvsHL2.Pair(Vector(-76, 23.2, 36.4)),
})
