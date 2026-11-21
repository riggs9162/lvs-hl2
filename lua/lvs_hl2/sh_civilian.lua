--- Shared builders for the Half-Life 2 civilian vehicles, so every car describes its lamps, engine and tyre sounds the same way.

lvsHL2 = lvsHL2 or {}

local HEADLIGHT_BLUE = 200
local LAMP_ALPHA = 150

---@class lvsHL2CarLamps
---@field headlights Vector[] Headlight positions, used for the dipped beam, the main beam and the front turn signals.
---@field taillights Vector[] Tail light positions, lit with the headlights, brighter while braking, and used for the rear turn signals.
---@field reverse Vector[]|nil Reverse light positions, the tail lights are used when this is left out.
---@field dipPitch number|nil How far the dipped beam points down in degrees, 10 by default.

--- Returns the given position together with its copy on the other side of the vehicle.
---@realm shared
---@param pos Vector Lamp position on one side of the vehicle.
---@return Vector[] pair The lamp and its mirrored twin.
function lvsHL2.Pair(pos)
    return {pos, Vector(pos.x, -pos.y, pos.z)}
end

--- Builds a list of glow sprites for the given lamp positions.
---@realm shared
---@param positions Vector[] Lamp positions.
---@param colorG number Green channel of the glow.
---@param colorB number Blue channel of the glow.
---@return table sprites Sprite entries for an LVS light.
local function BuildSprites(positions, colorG, colorB)
    local sprites = {}

    for _, pos in ipairs(positions) do
        sprites[#sprites + 1] = {
            pos = pos,
            colorG = colorG,
            colorB = colorB,
            colorA = LAMP_ALPHA,
        }
    end

    return sprites
end

--- Builds the projected beams that the headlights throw onto the road ahead.
---@realm shared
---@param positions Vector[] Headlight positions.
---@param pitch number How far the beam points down in degrees.
---@param farZ number How far the beam reaches.
---@return table textures Projected texture entries for an LVS light.
local function BuildBeams(positions, pitch, farZ)
    local textures = {}

    for _, pos in ipairs(positions) do
        textures[#textures + 1] = {
            pos = pos,
            ang = Angle(pitch, 0, 0),
            colorB = HEADLIGHT_BLUE,
            colorA = LAMP_ALPHA,
            shadows = false,
            farz = farZ,
        }
    end

    return textures
end

--- Returns the lamps that sit on the left or the right side of the vehicle.
---@realm shared
---@param positions Vector[] Lamp positions.
---@param bLeft boolean True for the left side, false for the right side.
---@return Vector[] side Lamp positions on that side.
local function FilterSide(positions, bLeft)
    local side = {}

    for _, pos in ipairs(positions) do
        if ( (pos.y > 0) == bLeft ) then
            side[#side + 1] = pos
        end
    end

    return side
end

--- Builds an amber turn signal light for one side of the vehicle from its headlights and tail lights.
---@realm shared
---@param lamps lvsHL2CarLamps Lamp layout of the vehicle.
---@param trigger string Either "turnleft" or "turnright".
---@return table light LVS light entry.
local function BuildTurnSignal(lamps, trigger)
    local bLeft = trigger == "turnleft"
    local positions = FilterSide(lamps.headlights, bLeft)

    for _, pos in ipairs(FilterSide(lamps.taillights, bLeft)) do
        positions[#positions + 1] = pos
    end

    return {
        Trigger = trigger,
        Sprites = BuildSprites(positions, 135, 0),
    }
end

--- Builds a complete ENT.Lights table with dipped and main beams, tail and brake lights, reverse lights and turn signals.
---@realm shared
---@param lamps lvsHL2CarLamps Lamp layout of the vehicle.
---@return table lights Value for ENT.Lights.
function lvsHL2.BuildCarLights(lamps)
    local dipPitch = lamps.dipPitch or 10

    return {
        {
            Trigger = "high",
            Sprites = BuildSprites(lamps.headlights, 255, HEADLIGHT_BLUE),
            ProjectedTextures = BuildBeams(lamps.headlights, 0, 2000),
        },
        {
            Trigger = "main",
            Sprites = BuildSprites(lamps.headlights, 255, HEADLIGHT_BLUE),
            ProjectedTextures = BuildBeams(lamps.headlights, dipPitch, 1000),
        },
        {
            Trigger = "main+brake",
            Sprites = BuildSprites(lamps.taillights, 0, 0),
        },
        {
            Trigger = "reverse",
            Sprites = BuildSprites(lamps.reverse or lamps.taillights, 255, HEADLIGHT_BLUE),
        },
        BuildTurnSignal(lamps, "turnleft"),
        BuildTurnSignal(lamps, "turnright"),
    }
end

--- Builds the three layer engine sound table of a civilian vehicle, pitched to suit its engine.
---@realm shared
---@param pitch number Base pitch of every layer, lower sounds bigger and slower.
---@param pitchMul number How far the pitch climbs as the engine revs.
---@param soundLevel number|nil Sound level of the engine, 75 by default.
---@return table sounds Value for ENT.EngineSounds.
function lvsHL2.BuildEngineSounds(pitch, pitchMul, soundLevel)
    soundLevel = soundLevel or 75

    return {
        {
            sound = "lvs/hl2/cars/generic/eng_idle_loop.wav",
            Volume = 1,
            Pitch = pitch,
            PitchMul = pitchMul,
            SoundLevel = soundLevel,
            SoundType = LVS.SOUNDTYPE_IDLE_ONLY,
        },
        {
            sound = "lvs/hl2/cars/generic/eng_loop.wav",
            Volume = 1,
            Pitch = pitch,
            PitchMul = pitchMul,
            SoundLevel = soundLevel,
            SoundType = LVS.SOUNDTYPE_REV_UP,
            UseDoppler = true,
        },
        {
            sound = "lvs/hl2/cars/generic/eng_revdown_loop.wav",
            Volume = 1,
            Pitch = pitch,
            PitchMul = pitchMul,
            SoundLevel = soundLevel,
            SoundType = LVS.SOUNDTYPE_REV_DOWN,
            UseDoppler = true,
        },
    }
end

--- Builds the tyre sound table used by the civilian cars, trucks keep the heavier sounds of the LVS truck base.
---@realm shared
---@return table sounds Value for ENT.TireSoundTypes.
function lvsHL2.BuildCarTireSounds()
    return {
        ["roll"] = "lvs/vehicles/generic/wheel_roll.wav",
        ["roll_racing"] = "lvs/vehicles/generic/wheel_roll.wav",
        ["roll_dirt"] = "lvs/vehicles/generic/wheel_roll_dirt.wav",
        ["roll_wet"] = "lvs/vehicles/generic/wheel_roll_wet.wav",
        ["roll_damaged"] = "lvs/wheel_damaged_loop.wav",
        ["skid"] = "vehicles/v8/skid_lowfriction.wav",
        ["skid_racing"] = "vehicles/v8/skid_highfriction.wav",
        ["skid_dirt"] = "vehicles/v8/skid_lowfriction.wav",
        ["skid_wet"] = "vehicles/v8/skid_highfriction.wav",
        ["tire_damage_layer"] = "lvs/wheel_destroyed_loop.wav",
    }
end

---@class lvsHL2Seat
---@field pos Vector Seat position, the seated player's feet sit about 6 units and their eyes about 33 units above it.
---@field exit Vector|nil Where the player is placed when leaving, beside the seat by default.

--- Adds the driver seat and every passenger seat of a civilian vehicle, all facing forward along the model.
---@realm server
---@param vehicle Entity The LVS vehicle being spawned.
---@param seats lvsHL2Seat[] Seats in order, the first one belongs to the driver.
---@param exitWidth number How far beside the centre line players are placed when they get out.
function lvsHL2.AddSeats(vehicle, seats, exitWidth)
    for index, seat in ipairs(seats) do
        local pod

        if ( index == 1 ) then
            pod = vehicle:AddDriverSeat(seat.pos, Angle(0, 270, 0))
        else
            pod = vehicle:AddPassengerSeat(seat.pos, Angle(0, 270, 0))
        end

        if ( !IsValid(pod) ) then continue end

        local side = seat.pos.y >= 0 and 1 or -1
        pod.ExitPos = seat.exit or Vector(seat.pos.x, side * exitWidth, seat.pos.z + 10)
    end
end

--- Defines the two axles of a four wheeled civilian vehicle with springs scaled to its mass.
---@realm server
---@param vehicle Entity The LVS vehicle being spawned.
---@param wheels table Wheels and their forward angle, keyed fl, fr, rl, rr and forward.
---@param drive table Axle setup: frontTorque, rearTorque, steerAngle, bRearSteer, drop, height, travel and stiffness.
function lvsHL2.DefineAxles(vehicle, wheels, drive)
    local mass = (vehicle.PhysicsMass or 1000) * (drive.stiffness or 2)
    local suspension = {
        Height = drive.height or 5,
        MaxTravel = drive.travel or 6,
        ControlArmLength = 30,
        SpringConstant = mass * 22,
        SpringDamping = mass * 3,
        SpringRelativeDamping = mass * 3,
    }

    vehicle:DefineAxle({
        Axle = {
            ForwardAngle = wheels.forward,
            SteerType = drive.bRearSteer and LVS.WHEEL_STEER_NONE or LVS.WHEEL_STEER_FRONT,
            SteerAngle = drive.steerAngle or 30,
            TorqueFactor = drive.frontTorque or 0,
            BrakeFactor = 1,
            UseHandbrake = drive.bRearSteer == true,
        },
        Wheels = {wheels.fl, wheels.fr},
        Suspension = suspension,
    })

    vehicle:DefineAxle({
        Axle = {
            ForwardAngle = wheels.forward,
            SteerType = drive.bRearSteer and LVS.WHEEL_STEER_REAR or LVS.WHEEL_STEER_NONE,
            SteerAngle = drive.steerAngle or 30,
            TorqueFactor = drive.rearTorque or 0,
            BrakeFactor = 1,
            UseHandbrake = drive.bRearSteer != true,
        },
        Wheels = {wheels.rl, wheels.rr},
        Suspension = suspension,
    })
end

local RIG_WHEELS = {"fl", "fr", "rl", "rr"}

--- Moves every wheel height pose parameter of a rigged model to the same value.
---@realm server
---@param ent Entity Entity showing the rigged model.
---@param value number Pose value from 0 to 1.
local function SetRigHeights(ent, value)
    for _, name in ipairs(RIG_WHEELS) do
        ent:SetPoseParameter("vehicle_wheel_" .. name .. "_height", value)
    end
end

--- Reads the wheel attachment positions of a rigged model in its local space.
---@realm server
---@param ent Entity Entity showing the rigged model.
---@return table positions Local positions keyed fl, fr, rl and rr.
local function ReadRigPositions(ent)
    local positions = {}

    for _, name in ipairs(RIG_WHEELS) do
        local attachment = ent:GetAttachment(ent:LookupAttachment("wheel_" .. name))
        positions[name] = attachment and ent:WorldToLocal(attachment.Pos) or vector_origin
    end

    return positions
end

--- Adds the rigged wheels of a civilian vehicle and defines its axles, hanging the wheels below the fully compressed rig pose so the body rides clear of them.
---@realm server
---@param vehicle Entity The LVS vehicle being spawned.
---@param frontRadius number Radius of the front tyres.
---@param rearRadius number Radius of the rear tyres.
---@param drive table Axle setup, see lvsHL2.DefineAxles; drop sets how far below the compressed rig pose the wheels hang, 7 by default.
function lvsHL2.AddRiggedWheels(vehicle, frontRadius, rearRadius, drive)
    local drop = drive.drop or 7
    local body = ents.Create("prop_dynamic")
    body:SetModel(vehicle:GetModel())
    body:SetPos(vehicle:GetPos())
    body:SetAngles(vehicle:GetAngles())
    body:SetMoveType(MOVETYPE_NONE)
    body:Spawn()
    body:SetNoDraw(true)
    body:SetNotSolid(true)

    SetRigHeights(body, 0)

    local compressed = ReadRigPositions(body)
    local wheels = {}

    for _, name in ipairs(RIG_WHEELS) do
        wheels[name] = vehicle:AddWheel({
            hide = true,
            pos = compressed[name] - Vector(0, 0, drop),
            radius = (name == "fl" or name == "fr") and frontRadius or rearRadius,
        })
    end

    local forward = ((compressed.fl + compressed.fr) / 2 - (compressed.rl + compressed.rr) / 2):Angle()
    wheels.forward = Angle(0, math.Round(forward.y), 0)

    SetRigHeights(body, 1)

    timer.Simple(0.15, function()
        if ( !IsValid(body) ) then return end

        local extended = ReadRigPositions(body)
        body:Remove()

        if ( !IsValid(vehicle) ) then return end

        for _, name in ipairs(RIG_WHEELS) do
            vehicle:CreateRigControler(name, wheels[name], compressed[name].z, extended[name].z)
        end
    end)

    lvsHL2.DefineAxles(vehicle, wheels, drive)
end
