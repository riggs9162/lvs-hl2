--- A Soviet family saloon with rear wheel drive.

include("lvs_hl2/sh_civilian.lua")

ENT.Base = "lvs_base_wheeldrive"
ENT.PrintName = "Moskvitch 2140"
ENT.Author = "Riggs"
ENT.Information = ""
ENT.Category = "[LVS] - Half Life 2"
ENT.IconOverride = "materials/entities/lvs/hl2/civilian_moskvitch.png"

ENT.AITEAM = 0
ENT.AdminSpawnable = false
ENT.EngineCurve = 0.3
ENT.EngineTorque = 150
ENT.MDL = "models/source_vehicles/car003a.mdl"
ENT.MaxHealth = 800
ENT.MaxVelocity = 1450
ENT.PhysicsMass = 1050
ENT.SpawnNormalOffset = 14
ENT.Spawnable = true
ENT.TransGears = 4
ENT.TransGearsReverse = 1
ENT.VehicleCategory = "Half Life 2"
ENT.VehicleSubCategory = "Civilian"

ENT.HornSound = "lvs/horn1.wav"
ENT.HornPos = Vector(75, 0, 30)

ENT.EngineSounds = lvsHL2.BuildEngineSounds(85, 25)
ENT.TireSoundTypes = lvsHL2.BuildCarTireSounds()

ENT.ExhaustPositions = {
    {
        pos = Vector(-96, -18, 14),
        ang = Angle(0, 180, 0),
    },
}

ENT.Lights = lvsHL2.BuildCarLights({
    headlights = lvsHL2.Pair(Vector(75.2, 28.4, 29.6)),
    taillights = lvsHL2.Pair(Vector(-99, 24.3, 28.6)),
    reverse = lvsHL2.Pair(Vector(-99, 19, 28.6)),
})
