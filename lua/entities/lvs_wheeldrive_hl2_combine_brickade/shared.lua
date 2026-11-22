local headlightOuterL = Vector(150, 51, 1)
local headlightOuterR = Vector(150, -51, 1)
local headlightInnerL = Vector(152, 37.5, 1)
local headlightInnerR = Vector(152, -37.5, 1)
local taillightL = Vector(-140, 45.5, 69)
local taillightR = Vector(-140, -45.5, 69)
local brakelightL = Vector(-140, 45.5, 10)
local brakelightR = Vector(-140, -45.5, 10)
local signalL = Vector(-140, 45.5, 21)
local signalR = Vector(-140, -45.5, 21)

ENT.Base = "lvs_base_wheeldrive"
ENT.PrintName = "HVY Brickade (Civil Protection)"
ENT.Author = "Riggs"
ENT.Information = "Requires Exidnost's Shared GTA V Content for glass and wheel textures."
ENT.Category = "[LVS] - Half Life 2"
ENT.IconOverride = "materials/entities/lvs/hl2/combine_brickade.png"

ENT.AITEAM = 1
ENT.AdminSpawnable = false
ENT.EngineCurve = 0.3
ENT.EngineTorque = 400
ENT.GibModels = {"models/glide/gtav/hvy_brickade_3/wheel_c17.mdl", "models/glide/gtav/hvy_brickade_3/wheel_c17.mdl", "models/gibs/helicopter_brokenpiece_01.mdl", "models/props_c17/TrapPropeller_Engine.mdl"}
ENT.MDL = "models/glide/gtav/hvy_brickade_3/hvy_brickade_3_c17.mdl"
ENT.MaxVelocity = 1300
ENT.MaxVelocityReverse = 400
ENT.PhysicsMass = 2000
ENT.SpawnNormalOffset = 32
ENT.Spawnable = true
ENT.TransGears = 6
ENT.TransGearsReverse = 1
ENT.VehicleCategory = "Half Life 2"
ENT.VehicleSubCategory = "Combine"

ENT.HornSound = "ambient/alarms/razortrain_horn1.wav"
ENT.HornPos = Vector(140, 0, 30)
ENT.SirenPos = Vector(107, 0, 99)
ENT.SirenSound = {
    {
        siren = "ambient/alarms/apc_alarm_loop1.wav",
        horn = "ambient/alarms/razortrain_horn1.wav",
    },
    {
        siren = "ambient/alarms/combine_bank_alarm_loop4.wav",
        horn = "ambient/alarms/razortrain_horn1.wav",
    },
}

ENT.EngineSounds = {}

ENT.TireSoundTypes = {
    ["roll"] = "lvs/vehicles/generic/wheel_roll.wav",
    ["roll_racing"] = "lvs/vehicles/generic/wheel_roll.wav",
    ["roll_dirt"] = "lvs/vehicles/generic/wheel_roll_dirt.wav",
    ["roll_wet"] = "lvs/vehicles/generic/wheel_roll_wet.wav",
    ["roll_damaged"] = "lvs/wheel_damaged_loop.wav",
    ["skid"] = "vehicles/v8/skid_highfriction.wav",
    ["skid_racing"] = "vehicles/v8/skid_normalfriction.wav",
    ["skid_dirt"] = "vehicles/v8/skid_lowfriction.wav",
    ["skid_wet"] = "vehicles/v8/skid_highfriction.wav",
    ["tire_damage_layer"] = "lvs/wheel_destroyed_loop.wav",
}

ENT.ExhaustPositions = {
    {
        pos = Vector(153, 0, 20),
        ang = Angle(-70, 0, 0),
    },
}

ENT.Lights = {
    {
        Trigger = "main",
        Sprites = {
            {
                pos = headlightOuterL,
                colorB = 200,
                colorA = 150
            },
            {
                pos = headlightOuterR,
                colorB = 200,
                colorA = 150
            },
            {
                pos = taillightL,
                colorG = 0,
                colorB = 0,
                colorA = 150,
                size = 20
            },
            {
                pos = taillightR,
                colorG = 0,
                colorB = 0,
                colorA = 150,
                size = 20
            },
        },
        ProjectedTextures = {
            {
                pos = headlightOuterL,
                ang = Angle(12, 0, 0),
                colorB = 200,
                colorA = 150,
                shadows = false,
                farz = 1000
            },
            {
                pos = headlightOuterR,
                ang = Angle(12, 0, 0),
                colorB = 200,
                colorA = 150,
                shadows = false,
                farz = 1000
            },
        },
    },
    {
        Trigger = "high",
        Sprites = {
            {
                pos = headlightInnerL,
                colorB = 200,
                colorA = 150
            },
            {
                pos = headlightInnerR,
                colorB = 200,
                colorA = 150
            },
        },
        ProjectedTextures = {
            {
                pos = headlightInnerL,
                ang = Angle(0, 0, 0),
                colorB = 200,
                colorA = 150,
                shadows = false,
                farz = 2000
            },
            {
                pos = headlightInnerR,
                ang = Angle(0, 0, 0),
                colorB = 200,
                colorA = 150,
                shadows = false,
                farz = 2000
            },
        },
    },
    {
        Trigger = "main+brake",
        Sprites = {
            {
                pos = brakelightL,
                colorG = 0,
                colorB = 0,
                colorA = 150
            },
            {
                pos = brakelightR,
                colorG = 0,
                colorB = 0,
                colorA = 150
            },
        },
    },
    {
        Trigger = "reverse",
        Sprites = {
            {
                pos = brakelightL,
                colorB = 200,
                colorA = 150
            },
            {
                pos = brakelightR,
                colorB = 200,
                colorA = 150
            },
        },
    },
    {
        Trigger = "turnleft",
        Sprites = {
            {
                pos = signalL,
                colorR = 220,
                colorG = 120,
                colorB = 0,
                colorA = 150
            },
        },
    },
    {
        Trigger = "turnright",
        Sprites = {
            {
                pos = signalR,
                colorR = 220,
                colorG = 120,
                colorB = 0,
                colorA = 150
            },
        },
    },
    {
        Trigger = "1100",
        Siren = true,
        Sprites = {
            {
                pos = Vector(113, 14, 99),
                colorR = 0,
                colorG = 100,
                colorA = 255,
                size = 30
            },
            {
                pos = Vector(107, 23, 99),
                colorR = 0,
                colorG = 100,
                colorA = 255,
                size = 30
            },
            {
                pos = Vector(102, 32, 99),
                colorR = 0,
                colorG = 100,
                colorA = 255,
                size = 30
            },
        },
    },
    {
        Trigger = "0011",
        Siren = true,
        Sprites = {
            {
                pos = Vector(113, -14, 99),
                colorR = 0,
                colorG = 100,
                colorA = 255,
                size = 30
            },
            {
                pos = Vector(107, -23, 99),
                colorR = 0,
                colorG = 100,
                colorA = 255,
                size = 30
            },
            {
                pos = Vector(102, -32, 99),
                colorR = 0,
                colorG = 100,
                colorA = 255,
                size = 30
            },
        },
    },
}
