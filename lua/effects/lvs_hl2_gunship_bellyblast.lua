--- Charge and shot of the gunship's belly cannon, ported from C_GunshipFX and its envelope in c_npc_combinegunship.cpp: a blue flare grows on the belly while a narrow beam reaches down to the ground, and both flash and fade when the cannon fires.

--- Seconds of the envelope at which the shot happens; the charge is held here until the cannon fires, GUNSHIPFX_BIG_SHOT_TIME.
local BIG_SHOT_TIME = 3

--- Seconds of the envelope after which nothing is left to draw.
local END_TIME = 5

--- Half the width of the narrow beam at full size, NARROW_BEAM_WIDTH.
local NARROW_BEAM_WIDTH = 32

--- Size of the flare at full size, FLARE_SIZE.
local FLARE_SIZE = 128

--- Radius and colour of the glow the charge casts.
local AFTERGLOW_RADIUS = 128
local AFTERGLOW_COLOR = Vector(40, 60, 255)

local BEAM_MATERIAL = Material("sprites/bluelaser1")
local FLARE_MATERIAL = Material("effects/blueblackflash")

local KEY_LINEAR = 0
local KEY_SPLINE = 1
local KEY_ACCELERATE = 2
local KEY_DECELERATE = 3

--- Keys of the envelope as time, interpolation into the key and value, from CGunshipFXEnvelope.
local ENVELOPE = {
    flareColor = {{0, KEY_LINEAR, 0}, {0.5, KEY_SPLINE, 1}, {2.9, KEY_LINEAR, 1}, {3.2, KEY_DECELERATE, 0}},
    flareSize = {{0, KEY_LINEAR, 0}, {2.9, KEY_ACCELERATE, 1}, {5, KEY_LINEAR, 1}},
    narrowBeamColor = {{0, KEY_LINEAR, 0}, {2.5, KEY_SPLINE, 1}, {3, KEY_LINEAR, 1}, {3.2, KEY_ACCELERATE, 0}},
    narrowBeamSize = {{0, KEY_LINEAR, 0}, {2.5, KEY_SPLINE, 0.25}, {2.8, KEY_ACCELERATE, 1}, {3, KEY_ACCELERATE, 4}, {3.2, KEY_DECELERATE, 0}},
    afterglowColor = {{0, KEY_LINEAR, 0}, {3, KEY_LINEAR, 1}, {5, KEY_SPLINE, 0}},
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

function EFFECT:Init(data)
    self.Gunship = data:GetEntity()
    self.Time = 0
    self.bFired = false
    self.bSeenCharging = false
    self.PixVis = util.GetPixelVisibleHandle()

    if ( IsValid(self.Gunship) ) then
        self.BeamEnd = self.Gunship:GetPos()
        self:SetRenderBoundsWS(self.BeamEnd, self.BeamEnd - Vector(0, 0, 8192))
    end
end

--- Returns the belly cannon's attachment on the gunship's body.
---@return table|nil attachment
function EFFECT:GetMuzzle()
    local gunship = self.Gunship
    if ( !IsValid(gunship) or !gunship.GetBodyAttachment ) then return nil end

    return gunship:GetBodyAttachment("bellygun")
end

function EFFECT:Think()
    local gunship = self.Gunship
    if ( !IsValid(gunship) ) then return false end

    local bCharging = gunship:GetGroundAttacking()

    if ( bCharging ) then
        self.bSeenCharging = true
    elseif ( self.bSeenCharging and !self.bFired ) then
        self.bFired = true
        self.Time = BIG_SHOT_TIME
    end

    self.Time = self.Time + FrameTime()

    if ( !self.bFired ) then
        self.Time = math.min(self.Time, BIG_SHOT_TIME)

        local muzzle = self:GetMuzzle()

        if ( muzzle ) then
            self.BeamEnd = muzzle.Pos
        end
    end

    self.Target = gunship:GetGroundAttackHitPos()

    if ( self.BeamEnd and self.Target ) then
        self:SetRenderBoundsWS(self.BeamEnd, self.Target, Vector(256, 256, 256))
    end

    return self.Time < END_TIME
end

function EFFECT:Render()
    local muzzle = self:GetMuzzle()
    if ( !muzzle or !self.BeamEnd or !self.Target ) then return end

    local t = self.Time
    local beamColor = Interp(ENVELOPE.narrowBeamColor, t)
    local beamSize = Interp(ENVELOPE.narrowBeamSize, t)

    if ( beamColor and beamSize ) then
        local bright = 255 * beamColor

        render.SetMaterial(BEAM_MATERIAL)
        render.DrawBeam(self.BeamEnd, self.Target, 2 * NARROW_BEAM_WIDTH * beamSize, 0, 1, Color(bright, bright, bright, bright))
    end

    local flareColor = Interp(ENVELOPE.flareColor, t)
    local flareSize = Interp(ENVELOPE.flareSize, t)

    if ( flareColor and flareSize and util.PixelVisible(muzzle.Pos, 4, self.PixVis) > 0 ) then
        local bright = 255 * flareColor
        local size = FLARE_SIZE * flareSize

        render.SetMaterial(FLARE_MATERIAL)
        render.DrawSprite(muzzle.Pos, size, size, Color(bright, bright, bright, 255))
    end

    local afterglow = Interp(ENVELOPE.afterglowColor, t)
    if ( !afterglow ) then return end

    local light = DynamicLight(self.Gunship:EntIndex())
    if ( !light ) then return end

    light.pos = muzzle.Pos
    light.r = AFTERGLOW_COLOR.x * afterglow
    light.g = AFTERGLOW_COLOR.y * afterglow
    light.b = AFTERGLOW_COLOR.z * afterglow
    light.brightness = 5
    light.size = AFTERGLOW_RADIUS
    light.decay = 0
    light.dietime = CurTime() + 0.1
end
