--- Engine sounds of the Combine APC, ported from the sound state machine of the Half-Life 2 vehicles (CBaseServerVehicle::SoundState_ChooseState in vehicle_baseserver.cpp) with the states and gears of the APC as Half-Life 2 drives it (scripts/vehicles/apc_npc.txt).

--- Speed shares of the top speed at which each sound gear begins, and how fast per second the sound may climb into it.
local SOUND_GEARS = {
    {minSpeed = 0, approachFactor = 1},
    {minSpeed = 0.1, approachFactor = 1},
    {minSpeed = 0.2, approachFactor = 0.9},
}

--- Sound and least seconds of each sound state, from the vehicle script.
local SOUND_STATES = {
    SHUTDOWN = {sound = "apc_engine_stop"},
    START_IDLE = {sound = "apc_engine_start"},
    REVERSE = {sound = "apc_firstgear", minTime = 0.7},
    IDLE = {sound = "apc_engine_idle"},
    GEAR_0 = {sound = "apc_engine_idle", minTime = 0.2},
    GEAR_0_RESUME = {sound = "apc_engine_idle", minTime = 0.2},
    GEAR_1 = {sound = "apc_engine_idle", minTime = 0.2},
    GEAR_1_RESUME = {sound = "apc_engine_idle", minTime = 0.2},
    GEAR_2 = {sound = "apc_firstgear", minTime = 1},
    GEAR_2_RESUME = {sound = "apc_firstgear_resume", minTime = 2.5},
    SLOWDOWN_HIGHSPEED = {sound = "apc_throttleoff_fastspeed"},
    SLOWDOWN = {sound = "apc_throttleoff_slowspeed"},
}

--- Seconds over which a looping engine sound fades out when the next one starts.
local LOOP_FADE_TIME = 0.25

--- Throttle above which the throttle counts as held down.
local THROTTLE_DOWN = 0.1

--- Returns the sound state a gear moves on to.
---@param gear number Sound gear, counted from zero.
---@param bReverse boolean Whether the vehicle is reversing.
---@return string state
local function MapGearToState(gear, bReverse)
    if ( gear == 0 ) then return bReverse and "REVERSE" or "GEAR_0" end

    return "GEAR_" .. math.min(gear, 2)
end

--- Returns the sound state a gear resumes in after the throttle was let off.
---@param gear number Sound gear, counted from zero.
---@param bReverse boolean Whether the vehicle is reversing.
---@return string state
local function MapGearToMidState(gear, bReverse)
    if ( gear == 0 ) then return bReverse and "REVERSE" or "GEAR_0_RESUME" end

    return "GEAR_" .. math.min(gear, 2) .. "_RESUME"
end

--- Fades out the looping engine sound that is playing, if any.
function ENT:StopEngineLoop()
    if ( !self.engineLoop ) then return end

    self.engineLoop:FadeOut(LOOP_FADE_TIME)
    self.engineLoop = nil
    self.engineLoopName = nil
end

--- Starts a looping engine sound, keeping the current one if it is the same sound.
---@param name string|nil Sound script name, or nil for silence.
function ENT:PlayEngineLoop(name)
    if ( name and name == self.engineLoopName ) then return end

    self:StopEngineLoop()

    if ( !name ) then return end

    local patch = CreateSound(self, name)
    patch:PlayEx(LVS.EngineVolume or 1, 100)

    self.engineLoop = patch
    self.engineLoopName = name
end

--- Plays the sound that belongs to a new sound state, from CBaseServerVehicle::SoundState_OnNewState.
---@param state string
function ENT:OnEngineSoundState(state)
    self.engineSoundState = state
    self.engineSoundStateTime = CurTime()

    if ( state == "SHUTDOWN" ) then
        self:StopEngineLoop()
        self:EmitSound(SOUND_STATES.SHUTDOWN.sound)

        return
    end

    if ( state == "SLOWDOWN" or state == "SLOWDOWN_HIGHSPEED" ) then
        self:PlayEngineLoop(SOUND_STATES[(self.engineSoundGear or 0) < 2 and "SLOWDOWN" or "SLOWDOWN_HIGHSPEED"].sound)

        return
    end

    local data = SOUND_STATES[state]

    self:PlayEngineLoop(data and data.sound)
end

--- Picks the next sound state, from CBaseServerVehicle::SoundState_ChooseState.
---@param bEngineOn boolean Whether the engine is running.
---@param bThrottle boolean Whether the throttle is held down.
---@param bReverse boolean Whether the vehicle is reversing.
---@return string|nil state
function ENT:ChooseEngineSoundState(bEngineOn, bThrottle, bReverse)
    local state = self.engineSoundState
    local gear = self.engineSoundGear or 0
    local data = SOUND_STATES[state]
    local bMinTime = !data or CurTime() - (self.engineSoundStateTime or 0) > (data.minTime or 0)

    if ( !bEngineOn ) then
        if ( state == nil or state == "SHUTDOWN" ) then return state end

        return "SHUTDOWN"
    end

    if ( state == nil or state == "SHUTDOWN" ) then return "START_IDLE" end

    if ( state == "START_IDLE" ) then
        if ( bMinTime or bThrottle ) then return "IDLE" end
    elseif ( state == "IDLE" ) then
        if ( bMinTime and bThrottle ) then return bReverse and "REVERSE" or "GEAR_0" end
    elseif ( state == "GEAR_0" or state == "GEAR_0_RESUME" ) then
        if ( ( bMinTime and !bThrottle ) or bReverse ) then return "IDLE" end
        if ( gear > 0 ) then return "GEAR_1" end
    elseif ( state == "GEAR_1" or state == "GEAR_1_RESUME" ) then
        if ( bMinTime and !bThrottle ) then return "SLOWDOWN" end
        if ( gear != 1 ) then return MapGearToState(gear, bReverse) end
    elseif ( state == "GEAR_2" or state == "GEAR_2_RESUME" ) then
        if ( bMinTime ) then
            if ( !bThrottle ) then return "SLOWDOWN" end
            if ( gear != 2 ) then return MapGearToState(gear, bReverse) end
        end
    elseif ( state == "REVERSE" ) then
        if ( bMinTime and !bReverse ) then return "SLOWDOWN" end
    elseif ( state == "SLOWDOWN" or state == "SLOWDOWN_HIGHSPEED" ) then
        if ( bThrottle ) then return MapGearToMidState(gear, bReverse) end
        if ( gear == 0 ) then return "IDLE" end
    end

    return state
end

--- Works out the sound gear from the speed, letting the sound climb only slowly and only while the throttle is down, from CBaseServerVehicle::SoundUpdate and RecalculateSoundGear.
---@param bThrottle boolean Whether the throttle is held down.
---@param bReverse boolean Whether the vehicle is reversing.
function ENT:UpdateEngineSoundGear(bThrottle, bReverse)
    local speedShare = self:GetVelocity():Length() / self.MaxVelocity
    local current = self.engineSoundSpeed or 0
    local gear = self.engineSoundGear or 0

    if ( speedShare > current ) then
        if ( !bThrottle ) then
            speedShare = current
        end

        speedShare = math.Approach(current, speedShare, RealFrameTime() * SOUND_GEARS[gear + 1].approachFactor)
    end

    self.engineSoundSpeed = math.Clamp(speedShare, 0, 1)

    for index = #SOUND_GEARS, 1, -1 do
        if ( self.engineSoundSpeed > SOUND_GEARS[index].minSpeed ) then
            gear = index - 1

            break
        end
    end

    self.engineSoundGear = bReverse and 0 or gear
end

--- Runs the engine sounds of the Half-Life 2 APC.
---@param throttle number Throttle between 0 and 1.
function ENT:UpdateHL2EngineSound(throttle)
    local bEngineOn = self:GetEngineActive() and self:GetHP() > 0
    local bThrottle = throttle > THROTTLE_DOWN
    local bReverse = self:GetReverse()

    self:UpdateEngineSoundGear(bThrottle, bReverse)

    local state = self:ChooseEngineSoundState(bEngineOn, bThrottle, bReverse)

    if ( state != self.engineSoundState ) then
        self:OnEngineSoundState(state)
    end
end

--- Stops every engine sound at once, as when the vehicle is removed.
function ENT:StopHL2EngineSound()
    if ( self.engineLoop ) then
        self.engineLoop:Stop()
        self.engineLoop = nil
    end

    self.engineLoopName = nil
    self.engineSoundState = nil
end
