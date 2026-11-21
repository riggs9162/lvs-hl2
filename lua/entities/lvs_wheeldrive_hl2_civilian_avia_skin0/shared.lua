--- A Czechoslovak flatbed lorry with room for passengers on the bed.

include("lvs_hl2/sh_civilian.lua")

ENT.Base = "lvs_wheeldrive_truckbase"
ENT.PrintName = "Avia A31 (Blue)"
ENT.Author = "Riggs"
ENT.Information = ""
ENT.Category = "[LVS] - Half Life 2"
ENT.IconOverride = "materials/entities/lvs/hl2/civilian_avia_skin0.png"

ENT.AITEAM = 0
ENT.AdminSpawnable = false
ENT.EngineCurve = 0.25
ENT.EngineTorque = 260
ENT.MDL = "models/source_vehicles/truck001c_01.mdl"
ENT.MaxHealth = 1400
ENT.MaxVelocity = 1250
ENT.PhysicsMass = 2600
ENT.PhysicsInertia = Vector(3900, 3900, 1950)
ENT.WheelPhysicsMass = 150
ENT.SpawnNormalOffset = 20
ENT.Spawnable = true
ENT.TransGears = 5
ENT.TransGearsReverse = 1
ENT.VehicleCategory = "Half Life 2"
ENT.VehicleSubCategory = "Civilian"

ENT.HornSound = "lvs/horn4.wav"
ENT.HornPos = Vector(120, 0, 40)

ENT.EngineSounds = lvsHL2.BuildEngineSounds(65, 20)

ENT.ExhaustPositions = {
    {
        pos = Vector(40, -42, 20),
        ang = Angle(0, 270, 0),
    },
}

ENT.Lights = lvsHL2.BuildCarLights({
    headlights = lvsHL2.Pair(Vector(118.1, 32.3, 41)),
    taillights = lvsHL2.Pair(Vector(-117, 19.8, 22.7)),
    reverse = lvsHL2.Pair(Vector(-117, 14, 22.7)),
})
