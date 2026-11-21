--- Dust a strider's foot kicks up when it comes down, from the three puffs of CNPC_Strider::FootFX.

local DUST_MATERIAL = "particle/particle_smokegrenade"

--- Number of puffs, spread evenly around the foot.
local PUFF_COUNT = 3

--- Particles in every puff.
local PARTICLES_PER_PUFF = 4

--- Size and speed of the dust, from the original's Dust( pos, dir, 12, 50 ).
local DUST_SIZE = 12
local DUST_SPEED = 50

function EFFECT:Init(data)
    local origin = data:GetOrigin()
    local emitter = ParticleEmitter(origin)
    if ( !emitter ) then return end

    local yaw = math.random(0, 120)

    for puff = 0, PUFF_COUNT - 1 do
        local direction = Angle(0, yaw + puff * 120, 0):Forward()
        direction.z = 0.25
        direction:Normalize()

        for _ = 1, PARTICLES_PER_PUFF do
            local particle = emitter:Add(DUST_MATERIAL, origin + VectorRand(-4, 4))

            if ( particle ) then
                local shade = math.random(150, 180)

                particle:SetVelocity((direction + VectorRand(-0.2, 0.2)) * DUST_SPEED * math.Rand(0.5, 1.5))
                particle:SetDieTime(math.Rand(1, 1.5))
                particle:SetStartSize(DUST_SIZE)
                particle:SetEndSize(DUST_SIZE * 3)
                particle:SetStartAlpha(math.random(96, 128))
                particle:SetEndAlpha(0)
                particle:SetRoll(math.Rand(0, 360))
                particle:SetRollDelta(math.Rand(-1, 1))
                particle:SetColor(shade, shade * 0.95, shade * 0.85)
                particle:SetAirResistance(20)
            end
        end
    end

    emitter:Finish()
end

function EFFECT:Think()
    return false
end

function EFFECT:Render()
end
