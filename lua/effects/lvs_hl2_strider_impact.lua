--- Impact of the strider's minigun rounds, from CNPC_Strider::DoImpactEffect: a fading halo spreads from where the round hit, with a splash of energy.

local HALO_MATERIAL = "sprites/physbeam.vmt"

--- Flag of a beam that fades out over its life.
local FBEAM_FADEOUT = 128

function EFFECT:Init(data)
    local origin = data:GetOrigin()

    effects.BeamRingPoint(origin, 0.2, 0, 64, 10, 0, Color(255, 255, 255, 50), {
        speed = 0,
        spread = 0,
        delay = 0,
        flags = FBEAM_FADEOUT,
        framerate = 0,
        material = HALO_MATERIAL,
    })

    local splash = EffectData()
    splash:SetOrigin(origin)
    splash:SetNormal(data:GetNormal())
    util.Effect("AR2Impact", splash)
end

function EFFECT:Think()
    return false
end

function EFFECT:Render()
end
