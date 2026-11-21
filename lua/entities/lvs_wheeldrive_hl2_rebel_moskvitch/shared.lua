include("lvs_hl2/sh_civilian.lua")

ENT.Base = "lvs_wheeldrive_hl2_civilian_moskvitch"
ENT.PrintName = "Moskvitch 2140 (Resistance)"
ENT.Author = "Riggs"
ENT.Information = ""
ENT.Category = "[LVS] - Half Life 2"
ENT.IconOverride = "materials/entities/lvs/hl2/rebel_moskvitch.png"

ENT.AITEAM = 2
ENT.AdminSpawnable = false
ENT.MDL = "models/source_vehicles/car003b_rebel.mdl"
ENT.Spawnable = true
ENT.VehicleCategory = "Half Life 2"
ENT.VehicleSubCategory = "Resistance"

ENT.Lights = lvsHL2.BuildCarLights({
    headlights = {Vector(75.2, -28.4, 29.6)},
    taillights = lvsHL2.Pair(Vector(-100, 23.3, 28.9)),
    reverse = lvsHL2.Pair(Vector(-100, 18.9, 28.8)),
})
