--- A large Soviet saloon with rear wheel drive.

include("lvs_hl2/sh_civilian.lua")

ENT.Base = "lvs_base_wheeldrive"
ENT.PrintName = "GAZ-24 Volga"
ENT.Author = "Riggs"
ENT.Information = ""
ENT.Category = "[LVS] - Half Life 2"
ENT.IconOverride = "materials/entities/lvs/hl2/civilian_gaz24.png"

ENT.AITEAM = 0
ENT.AdminSpawnable = false
ENT.EngineCurve = 0.3
ENT.EngineTorque = 180
ENT.MDL = "models/source_vehicles/car004a.mdl"
ENT.MaxHealth = 900
ENT.MaxVelocity = 1550
ENT.PhysicsMass = 1400
ENT.SpawnNormalOffset = 14
ENT.Spawnable = true
ENT.TransGears = 4
ENT.TransGearsReverse = 1
ENT.VehicleCategory = "Half Life 2"
ENT.VehicleSubCategory = "Civilian"

ENT.HornSound = "lvs/horn1.wav"
ENT.HornPos = Vector(84, 0, 30)

ENT.EngineSounds = lvsHL2.BuildEngineSounds(75, 25)
ENT.TireSoundTypes = lvsHL2.BuildCarTireSounds()

ENT.ExhaustPositions = {
    {
        pos = Vector(-106, -20, 16),
        ang = Angle(0, 180, 0),
    },
}

ENT.Lights = lvsHL2.BuildCarLights({
    headlights = lvsHL2.Pair(Vector(84.5, 30.3, 28.7)),
    taillights = lvsHL2.Pair(Vector(-110, 30, 33)),
    reverse = lvsHL2.Pair(Vector(-110, 30, 28.8)),
})
