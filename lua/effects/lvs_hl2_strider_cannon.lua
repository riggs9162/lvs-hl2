--- Charge and shot of the strider's warp cannon, ported from C_StriderFX and its envelope in c_strider.cpp: the air warps and darkens around the gun while a thin beam reaches out to the target, then a wide beam fires, a bubble of warped air rushes down it and the gun glows on afterwards.

--- Seconds of the envelope at which the shot happens; the charge is held here until the cannon fires, STRIDERFX_BIG_SHOT_TIME.
local BIG_SHOT_TIME = 1.25

--- Seconds of the envelope at which everything is over, STRIDERFX_END_ALL_TIME.
local END_ALL_TIME = 4

--- Half widths of the beams and sizes of the sprites, from c_strider.cpp.
local NARROW_BEAM_WIDTH = 2
local WIDE_BEAM_WIDTH = 16
local FLARE_SIZE = 128
local AFTERGLOW_SIZE = 64
local WARP_SIZE = 512
local WARP_REFRACT = 0.075
local WARP_BUBBLE_SIZE = 256
local WARP_BUBBLE_REFRACT = 1

--- Radius and colour of the glow on the gun.
local AFTERGLOW_RADIUS = 128
local AFTERGLOW_COLOR = Vector(40, 60, 255)

local NARROW_BEAM_MATERIAL = Material("sprites/bluelaser1")
local WIDE_BEAM_MATERIAL = Material("effects/blueblacklargebeam")
local FLARE_MATERIAL = Material("effects/blueblackflash")
local PINCH_MATERIAL = Material("effects/strider_pinch_dudv")
local BULGE_MATERIAL = Material("effects/strider_bulge_dudv")

local KEY_LINEAR = 0
local KEY_SPLINE = 1
local KEY_ACCELERATE = 2
local KEY_DECELERATE = 3

--- Keys of the envelope as time, interpolation into the key and value, from CStriderFXEnvelope.
local ENVELOPE = {
    warpScale = {{0, KEY_LINEAR, 0}, {1.25, KEY_ACCELERATE, 1}, {1.25, KEY_LINEAR, 1}, {1.3, KEY_LINEAR, 0}},
    darkness = {{0, KEY_LINEAR, 0}, {0.5, KEY_SPLINE, 1}, {1, KEY_LINEAR, 1}, {1.25, KEY_SPLINE, 0}, {2, KEY_SPLINE, 0}},
    flareColor = {{0, KEY_LINEAR, 0}, {0.5, KEY_LINEAR, 0}, {1.25, KEY_ACCELERATE, 1}, {1.5, KEY_LINEAR, 1}, {2, KEY_SPLINE, 0}},
    flareSize = {{0, KEY_LINEAR, 0}, {1, KEY_LINEAR, 1}, {2, KEY_LINEAR, 1}},
    bubbleSize = {{1.3, KEY_LINEAR, 0.5}, {2, KEY_DECELERATE, 2}},
    bubbleRefract = {{1.3, KEY_LINEAR, 1}, {2, KEY_LINEAR, 0}},
    narrowBeamColor = {{0, KEY_LINEAR, 0}, {1.25, KEY_ACCELERATE, 1}, {1.5, KEY_SPLINE, 0}},
    narrowBeamSize = {{0, KEY_LINEAR, 0}, {0.5, KEY_ACCELERATE, 1}, {1.25, KEY_LINEAR, 1}, {1.5, KEY_DECELERATE, 2}},
    wideBeamColor = {{1.25, KEY_LINEAR, 0}, {1.5, KEY_SPLINE, 1}, {1.75, KEY_LINEAR, 1}, {2.1, KEY_SPLINE, 0}},
    wideBeamSize = {{1.25, KEY_LINEAR, 1}, {2.1, KEY_LINEAR, 1}},
    afterglowColor = {{1, KEY_LINEAR, 0}, {1.25, KEY_SPLINE, 1}, {3, KEY_LINEAR, 1}, {3.5, KEY_ACCELERATE, 0}},
    wideBeamLength = {{1.25, KEY_LINEAR, 1}, {1.5, KEY_ACCELERATE, 0}, {2.1, KEY_LINEAR, 0}},
}

--- Reads one parameter of the envelope at a time, from CSimpleKeyList::Interp.
---@param keys table Keys of the parameter.
---@param t number Seconds into the envelope.
---@return number|nil value Nil before the first and after the last key.
local function Interp(keys, t)
    for index = 2, #keys do
        local endKey = keys[index]

        if ( t < endKey[1] ) then
            local startKey = keys[index - 1]
            if ( t < startKey[1] ) then return nil end

            local delta = endKey[1] - startKey[1]
            local unit = delta > 0 and math.Clamp((t - startKey[1]) / delta, 0, 1) or 1
            local interp = endKey[2]

            if ( interp == KEY_SPLINE ) then
                unit = unit * unit * (3 - 2 * unit)
            elseif ( interp == KEY_ACCELERATE ) then
                unit = unit * unit
            elseif ( interp == KEY_DECELERATE ) then
                unit = math.sqrt(unit)
            end

            return Lerp(unit, startKey[3], endKey[3])
        end
    end

    return nil
end

--- Returns a white colour scaled by a brightness.
---@param bright number
---@param alpha number|nil
---@return Color color
local function White(bright, alpha)
    local value = math.Clamp(255 * bright, 0, 255)

    return Color(value, value, value, alpha or value)
end

function EFFECT:Init(data)
    self.Strider = data:GetEntity()
    self.Time = 0
    self.StartTime = CurTime()
    self.bFired = false
    self.bSeenCharging = false
    self.GunVis = util.GetPixelVisibleHandle()
    self.EndVis = util.GetPixelVisibleHandle()

    if ( IsValid(self.Strider) ) then
        self:SetRenderBoundsWS(self.Strider:GetPos(), self.Strider:GetPos() + Vector(0, 0, 1), Vector(512, 512, 512))
    end
end

--- Returns the gun's attachment on the strider.
---@return table|nil attachment
function EFFECT:GetGun()
    local strider = self.Strider
    if ( !IsValid(strider) ) then return nil end

    return strider:GetAttachment(strider:LookupAttachment("BigGun"))
end

function EFFECT:Think()
    local strider = self.Strider
    if ( !IsValid(strider) or strider:GetHP() <= 0 ) then return false end

    local now = CurTime()

    if ( strider:GetCannonCharging() ) then
        self.bSeenCharging = true
        self.Time = math.min(now - self.StartTime, BIG_SHOT_TIME)
    elseif ( self.bSeenCharging and !self.bFired ) then
        self.bFired = true
        self.FireTime = now
    elseif ( !self.bSeenCharging and now - self.StartTime > 1 ) then
        return false
    end

    if ( self.bFired ) then
        self.Time = math.min(BIG_SHOT_TIME + (now - self.FireTime), END_ALL_TIME)
    end

    local gun = self:GetGun()

    if ( gun ) then
        self.BeamEnd = gun.Pos
    end

    self.Target = strider:GetCannonHitPos()

    if ( self.BeamEnd and self.Target ) then
        self:SetRenderBoundsWS(self.BeamEnd, self.Target, Vector(512, 512, 512))
    end

    return self.Time < END_ALL_TIME
end

function EFFECT:Render()
    local gun = self:GetGun()
    if ( !gun or !self.BeamEnd or !self.Target ) then return end

    local t = self.Time
    local params = {}

    for name, keys in pairs(ENVELOPE) do
        params[name] = Interp(keys, t)
    end

    local gunVisible = util.PixelVisible(gun.Pos, 4, self.GunVis)
    local wideBeamEnd = self.BeamEnd

    if ( params.wideBeamLength ) then
        wideBeamEnd = self.BeamEnd * params.wideBeamLength + self.Target * (1 - params.wideBeamLength)
    end

    if ( params.narrowBeamColor and params.narrowBeamSize ) then
        render.SetMaterial(NARROW_BEAM_MATERIAL)
        render.DrawBeam(self.BeamEnd, self.Target, 2 * NARROW_BEAM_WIDTH * params.narrowBeamSize, 0, 1, White(params.narrowBeamColor))
    end

    if ( params.wideBeamColor and params.wideBeamSize ) then
        render.SetMaterial(WIDE_BEAM_MATERIAL)
        render.DrawBeam(wideBeamEnd, self.Target, 2 * WIDE_BEAM_WIDTH * params.wideBeamSize, 0, 1, White(params.wideBeamColor))
    end

    if ( params.warpScale and !params.bubbleSize and gunVisible > 0 ) then
        render.UpdateRefractTexture()
        PINCH_MATERIAL:SetFloat("$refractamount", params.warpScale * WARP_REFRACT * gunVisible)
        render.SetMaterial(PINCH_MATERIAL)
        render.DrawSprite(gun.Pos, WARP_SIZE, WARP_SIZE, color_white)
    end

    if ( params.flareColor and params.flareSize and params.darkness and gunVisible > 0 ) then
        local size = FLARE_SIZE * params.flareSize

        render.SetMaterial(FLARE_MATERIAL)
        render.DrawSprite(gun.Pos, size, size, White(params.flareColor * gunVisible, 255 * params.darkness))
    end

    if ( params.bubbleSize ) then
        local endVisible = util.PixelVisible(wideBeamEnd, 4, self.EndVis)

        if ( endVisible > 0 ) then
            local size = WARP_BUBBLE_SIZE * params.bubbleSize

            render.UpdateRefractTexture()
            BULGE_MATERIAL:SetFloat("$refractamount", endVisible * WARP_BUBBLE_REFRACT * (params.bubbleRefract or 0))
            render.SetMaterial(BULGE_MATERIAL)
            render.DrawSprite(wideBeamEnd, size, size, color_white)
        end
    end

    if ( params.afterglowColor and gunVisible > 0 ) then
        local bright = params.afterglowColor * gunVisible

        render.SetMaterial(FLARE_MATERIAL)
        render.DrawSprite(gun.Pos, AFTERGLOW_SIZE, AFTERGLOW_SIZE, White(bright))

        local light = DynamicLight(self.Strider:EntIndex())

        if ( light ) then
            light.pos = gun.Pos
            light.r = AFTERGLOW_COLOR.x
            light.g = AFTERGLOW_COLOR.y
            light.b = AFTERGLOW_COLOR.z
            light.brightness = 5
            light.size = bright * AFTERGLOW_RADIUS
            light.decay = 0
            light.dietime = CurTime() + 0.1
        end
    end
end
