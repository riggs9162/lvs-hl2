AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("cl_sounds.lua")
include("shared.lua")
include("lvs_hl2/sv_helicopter_flight.lua")
include("sv_cargo.lua")
include("lvs_hl2/sv_helicopter_ai.lua")
include("sv_ai.lua")

--- Seconds between two thinks of the original.
local THINK_INTERVAL = 0.1

--- Length of one original think tick in seconds, which turns the rotor push of the flight model into the original's units.
local HELICOPTER_TICK = 0.1

--- Position of the pilot's seat inside the hull.
local SEAT_POS = Vector(150, 0, 60)

--- Position of the rotor hub, from CNPC_CombineDropship::DoRotorWash.
local ROTOR_POS = Vector(-64, 0, 0)

--- Height above the ground below which the container opens its door in landing mode.
local DOOR_OPEN_HEIGHT = 100

function ENT:OnSpawn(phys)
    local driverSeat = self:AddDriverSeat(SEAT_POS, Angle(0, -90, 0))
    driverSeat:SetCameraDistance(0.5)
    driverSeat.HidePlayer = true

    local rotor = self:AddRotor(ROTOR_POS, angle_zero, 0, 4000)
    rotor:SetRotorEffects(true)

    self:DrawShadow(false)
    self:ResetSequence(self:LookupSequence("idle_exagg"))

    self.nextDropshipThink = 0

    self:InitAI()

    if ( self.DefaultCargoClass ) then
        timer.Simple(0, function()
            if ( IsValid(self) ) then
                self:SpawnDefaultCargo()
            end
        end)
    end

    if ( self.PostOnSpawn ) then
        self:PostOnSpawn(phys)
    end
end

--- Creates the cargo the dropship spawns with and latches on to it.
function ENT:SpawnDefaultCargo()
    local cargo = ents.Create(self.DefaultCargoClass)
    if ( !IsValid(cargo) ) then return end

    cargo:SetPos(self:GetPos())
    cargo:SetAngles(self:GetAngles())
    cargo:Spawn()
    cargo:Activate()

    if ( cargo.SetAITEAM ) then
        cargo:SetAITEAM(self:GetAITEAM())
    end

    self:TransferCPPI(cargo)
    self:GrabCargo(cargo, true)
end

--- Feeds the pilot's aim and trigger to the container's cannon while a container hangs underneath.
---@param bTrigger boolean
function ENT:ContainerGunThink(bTrigger)
    local container = self:GetContainer()
    if ( !container or !container.SetGunInput ) then return end

    container:SetGunInput(self:GetEyeTrace().HitPos, bTrigger)
end

--- Opens the container's door while the dropship is in landing mode with the container close to the ground, and closes it otherwise.
function ENT:DeployThink()
    local container = self:GetContainer()
    if ( !container or !container.SetDoorOpen ) then return end

    local pos = container:GetPos()
    local trace = util.TraceLine({
        start = pos,
        endpos = pos - Vector(0, 0, DOOR_OPEN_HEIGHT),
        filter = {self, container},
    })

    container:SetDoorOpen(self:GetDeploying() and trace.Hit)
end

function ENT:OnTick()
    self:FollowCargo()

    local now = CurTime()
    if ( now < self.nextDropshipThink ) then return end

    self.nextDropshipThink = now + THINK_INTERVAL

    self:CargoThink()
    self:DeployThink()
    self:SetRotorForce((self.flightLift or 0) * HELICOPTER_TICK)
end

--- Lets go of the cargo when the dropship is removed, except the cargo it spawned with, which goes with it.
function ENT:OnRemoved()
    if ( self.cargo and self.cargo.bDefault ) then return end

    self:ReleaseCargo()
end
