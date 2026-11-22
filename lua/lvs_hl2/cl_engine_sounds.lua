--- Clientside engine sound mixin for start/loop/end sound sets, included from a vehicle's cl_init.lua and configured through ENT.EngineSoundFolder, which must contain eng_idle_start/loop/end.wav, eng_loaded_start/loop/end.wav and eng_interior_loop.wav.

--- Speed above which a throttling vehicle switches to the loaded sound set.
local SPEED_LOADED_ENTER = 100

--- Speed below which a vehicle drops back to the idle sound set.
local SPEED_LOADED_EXIT = 20

--- Returns the looping sound patch for one sound of the set, creating it on first use.
---@param name string Sound name without folder or extension, such as "eng_idle_loop".
---@return CSoundPatch patch Sound patch attached to the vehicle.
function ENT:GetEngineSoundPatch(name)
    if ( !self.engineSoundPatches ) then
        self.engineSoundPatches = {}
    end

    local patch = self.engineSoundPatches[name]
    if ( !patch ) then
        patch = CreateSound(self, self.EngineSoundFolder .. "/" .. name .. ".wav")
        patch:SetSoundLevel(85)
        self.engineSoundPatches[name] = patch
    end

    return patch
end

--- Restarts a looping sound quietly and fades it up to the LVS engine volume.
---@param name string Sound name without folder or extension.
---@param time number Fade duration in seconds.
---@return CSoundPatch patch Sound patch that is now playing.
function ENT:EngineSoundFadeIn(name, time)
    local patch = self:GetEngineSoundPatch(name)
    patch:Stop()
    patch:PlayEx(0.01, 100)
    patch:ChangeVolume(LVS.EngineVolume, time)

    return patch
end

--- Silences every engine sound at once and resets the sound state to off.
function ENT:EngineSoundsStopAll()
    self:StopSound(self.EngineSoundFolder .. "/eng_idle_start.wav")
    self:StopSound(self.EngineSoundFolder .. "/eng_loaded_start.wav")

    if ( self.engineSoundPatches ) then
        for _, patch in pairs(self.engineSoundPatches) do
            patch:Stop()
        end
    end

    self.bInteriorPlaying = false
    self.engineSoundState = "off"
end

--- Stops the engine sounds and plays the shutdown sound if the engine was running.
function ENT:EngineSoundsShutdown()
    local bWasRunning = tobool(self.engineSoundState) and self.engineSoundState != "off"
    self:EngineSoundsStopAll()

    if ( bWasRunning ) then
        self:EmitSound(self.EngineSoundFolder .. "/eng_idle_end.wav", 85, 100, LVS.EngineVolume)
    end
end

--- Plays the start sound when the engine turns on and the shutdown sound when it turns off.
---@param bActive boolean Whether the engine is now running.
function ENT:OnEngineActiveChanged(bActive)
    if ( bActive ) then
        self:EngineSoundsStopAll()

        local startSound = self.EngineSoundFolder .. "/eng_idle_start.wav"
        self:EmitSound(startSound, 85, 100, LVS.EngineVolume)
        self.engineSoundState = "starting"
        self.engineSoundNextLoop = CurTime() + SoundDuration(startSound) - 0.1
    else
        self:EngineSoundsShutdown()
    end
end

--- Advances the engine sound state each frame: a vehicle spawned with its engine running skips the start sound, finished start sounds move into their loops, throttling above SPEED_LOADED_ENTER switches to the loaded set, slowing below SPEED_LOADED_EXIT or braking off the throttle switches back to idle, and the interior loop only plays while the local player sits in this vehicle in first person.
function ENT:EngineSoundsThink()
    if ( !self:GetEngineActive() ) then return end

    local speed = self:GetVelocity():Length()
    local throttle = self:GetThrottle()
    local brake = self:GetBrake()

    self.engineSoundLastSpeed = speed

    local state = self.engineSoundState or "off"
    local curTime = CurTime()

    if ( state == "off" ) then
        state = "starting"
        self.engineSoundState = state
        self.engineSoundNextLoop = curTime
    end

    if ( state == "starting" and curTime >= self.engineSoundNextLoop ) then
        self:EngineSoundFadeIn("eng_idle_loop", 1)
        state = "idle"
        self.engineSoundState = state
    elseif ( state == "loading" and curTime >= self.engineSoundNextLoop ) then
        local loadedLoop = self:GetEngineSoundPatch("eng_loaded_loop")
        loadedLoop:Stop()
        loadedLoop:PlayEx(LVS.EngineVolume, 100)
        state = "loaded"
        self.engineSoundState = state
    end

    local bBrakingDown = throttle <= 0 and speed < 200 or brake > 0
    if ( (state == "idle" or state == "starting") and speed > SPEED_LOADED_ENTER and throttle > 0 ) then
        self:StopSound(self.EngineSoundFolder .. "/eng_idle_start.wav")
        self:GetEngineSoundPatch("eng_idle_loop"):FadeOut(1)

        local startSound = self.EngineSoundFolder .. "/eng_loaded_start.wav"
        self:EmitSound(startSound, 85, 100, LVS.EngineVolume)
        self.engineSoundState = "loading"
        self.engineSoundNextLoop = curTime + SoundDuration(startSound) - 0.1
    elseif ( (state == "loaded" or state == "loading") and (speed < SPEED_LOADED_EXIT or bBrakingDown) ) then
        self:StopSound(self.EngineSoundFolder .. "/eng_loaded_start.wav")
        self:GetEngineSoundPatch("eng_loaded_loop"):FadeOut(1)

        self:EmitSound(self.EngineSoundFolder .. "/eng_loaded_end.wav", 85, 100, LVS.EngineVolume)
        self:EngineSoundFadeIn("eng_idle_loop", 1)
        self.engineSoundState = "idle"
    end

    local bInside = LocalPlayer():lvsGetVehicle() == self and !LocalPlayer():GetVehicle():GetThirdPersonMode()
    if ( bInside ) then
        if ( !self.bInteriorPlaying ) then
            self:GetEngineSoundPatch("eng_interior_loop"):PlayEx(LVS.EngineVolume, 100)
            self.bInteriorPlaying = true
        end
    else
        if ( self.bInteriorPlaying ) then
            self:GetEngineSoundPatch("eng_interior_loop"):Stop()
            self.bInteriorPlaying = false
        end
    end
end

--- Stops every engine sound when the vehicle is removed.
function ENT:OnRemoved()
    self:EngineSoundsStopAll()
end
