--- Blast of the strider's warp cannon, ported from FX_ConcussiveExplosion in fx_sparks.cpp and the shockwave of CConcussiveBlast::Explode: a puff of pale smoke, a quick blue flash, streaks of light flying apart, bouncing sparks and a ring rushing outwards.

local SMOKE_MATERIAL = "particle/particle_noisesphere"
local FLARE_MATERIAL = "effects/blueflare1"
local RING_MATERIAL = "sprites/lgtning.vmt"

--- Radius of the shockwave per unit of the blast's strength.
local RING_RADIUS_PER_MAGNITUDE = 300

--- Gravity of the bouncing sparks.
local SPARK_GRAVITY = Vector(0, 0, -400)

--- Adds a particle that starts and ends at given sizes and alphas.
---@param emitter CLuaEmitter
---@param material string
---@param pos Vector
---@param dieTime number
---@param startSize number
---@param endSize number
---@param startAlpha number
---@param endAlpha number
---@param color number Grey value.
---@return CLuaParticle|nil particle
local function AddParticle(emitter, material, pos, dieTime, startSize, endSize, startAlpha, endAlpha, color)
    local particle = emitter:Add(material, pos)
    if ( !particle ) then return nil end

    particle:SetDieTime(dieTime)
    particle:SetStartSize(startSize)
    particle:SetEndSize(endSize)
    particle:SetStartAlpha(startAlpha)
    particle:SetEndAlpha(endAlpha)
    particle:SetColor(color, color, color)

    return particle
end

--- Adds a streak of light flying out from the blast.
---@param emitter CLuaEmitter
---@param pos Vector
---@param velocity Vector
---@param dieTime number
local function AddStreak(emitter, pos, velocity, dieTime)
    local particle = emitter:Add(FLARE_MATERIAL, pos)
    if ( !particle ) then return nil end

    local ramp = math.Rand(0.75, 1) * 255

    particle:SetVelocity(velocity)
    particle:SetDieTime(dieTime)
    particle:SetStartSize(math.Rand(1, 2))
    particle:SetEndSize(0)
    particle:SetStartLength(velocity:Length() * math.Rand(0.01, 0.1))
    particle:SetEndLength(0)
    particle:SetStartAlpha(255)
    particle:SetEndAlpha(0)
    particle:SetColor(ramp, ramp, 255)

    return particle
end

function EFFECT:Init(data)
    local origin = data:GetOrigin()
    local normal = data:GetNormal()
    local magnitude = data:GetMagnitude()
    local offset = origin + normal * 2
    local emitter = ParticleEmitter(offset)

    if ( emitter ) then
        for _ = 1, 16 do
            local particle = AddParticle(emitter, SMOKE_MATERIAL, offset, math.Rand(0.2, 0.4), math.random(4, 8), math.random(32, 64), math.random(64, 128), 0, math.random(235, 255))

            if ( particle ) then
                particle:SetVelocity(VectorRand() * math.Rand(64, 128))
                particle:SetRoll(math.Rand(180, 360))
                particle:SetRollDelta(math.Rand(-4, 4))
            end
        end

        for _ = 1, 2 do
            local particle = AddParticle(emitter, SMOKE_MATERIAL, offset, math.Rand(1, 2), math.random(32, 64), math.random(100, 128), math.random(32, 64), 0, math.random(235, 255))

            if ( particle ) then
                particle:SetVelocity((normal + VectorRand(-0.8, 0.8)) * math.Rand(16, 32))
                particle:SetRoll(math.Rand(180, 360))
                particle:SetRollDelta(math.Rand(-1, 1))
            end
        end

        AddParticle(emitter, FLARE_MATERIAL, offset, 0.1, 16, 64, 255, 0, 128)
        AddParticle(emitter, FLARE_MATERIAL, offset, 0.2, 64, 128, 64, 0, 32)

        for _ = 1, math.random(16, 32) do
            AddStreak(emitter, offset, VectorRand():GetNormalized() * math.Rand(800, 1000), math.Rand(0.1, 0.2))
        end

        for _ = 1, math.random(8, 16) do
            local direction = VectorRand()
            direction.z = math.Rand(0, 0.75)

            local particle = AddStreak(emitter, offset, direction * math.Rand(128, 512), math.Rand(0.2, 1))

            if ( particle ) then
                particle:SetGravity(SPARK_GRAVITY)
                particle:SetCollide(true)
                particle:SetBounce(0.3)
            end
        end

        emitter:Finish()
    end

    local light = DynamicLight(0)

    if ( light ) then
        light.pos = offset
        light.r = 64
        light.g = 64
        light.b = 64
        light.brightness = 1
        light.size = math.Rand(128, 256)
        light.decay = 0
        light.dietime = CurTime() + 0.1
    end

    local ramp = math.random(128, 255)

    effects.BeamRingPoint(origin, 0.3, 16, RING_RADIUS_PER_MAGNITUDE * magnitude, 128, 0, Color(ramp, ramp, 255, 24), {
        speed = 128,
        spread = 16,
        delay = 0,
        framerate = 2,
        material = RING_MATERIAL,
    })
end

function EFFECT:Think()
    return false
end

function EFFECT:Render()
end
