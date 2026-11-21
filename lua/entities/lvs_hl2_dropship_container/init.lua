AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")
include("sv_gun.lua")
include("sv_damage.lua")

--- Seconds between two thinks of the gun and the door, the original's think interval.
local THINK_INTERVAL = 0.1

--- Position and angles of the gunner's seat.
local GUNNER_SEAT_POS = Vector(100, 50, 0)
local GUNNER_SEAT_ANGLES = Angle(0, -90, 0)

--- Position and angles of the troop seats along both walls.
local TROOP_SEATS = {
    {Vector(-30, -20, 0), Angle(0, 0, 0)},
    {Vector(0, -20, 0), Angle(0, 0, 0)},
    {Vector(30, -20, 0), Angle(0, 0, 0)},
    {Vector(60, -20, 0), Angle(0, 0, 0)},
    {Vector(-30, 20, 0), Angle(0, 180, 0)},
    {Vector(0, 20, 0), Angle(0, 180, 0)},
    {Vector(30, 20, 0), Angle(0, 180, 0)},
    {Vector(60, 20, 0), Angle(0, 180, 0)},
}

--- Where players leave the container.
local EXIT_POS = Vector(125, 0, 0)

--- Farthest an enemy may be for the container's own gunner AI to fire at it, the original's default gun range.
local AI_GUN_RANGE = 2048

function ENT:OnSpawn(phys)
    local gunnerSeat = self:AddDriverSeat(GUNNER_SEAT_POS, GUNNER_SEAT_ANGLES)
    gunnerSeat:SetCameraDistance(0.5)
    gunnerSeat.ExitPos = EXIT_POS

    for _, seat in ipairs(TROOP_SEATS) do
        local troopSeat = self:AddPassengerSeat(seat[1], seat[2])
        troopSeat.ExitPos = EXIT_POS
    end

    local convar = GetConVar("sk_dropship_container_health")
    local health = convar and convar:GetFloat() or self.MaxHealth

    self.MaxHealth = health
    self:SetHP(health)

    self:ResetSequence(self:LookupSequence("close_idle"))

    self:InitGun()
    self:InitDamage()

    self.nextContainerThink = 0
end

--- Opens or closes the door with its animation.
---@param bOpen boolean
function ENT:SetDoorOpen(bOpen)
    if ( self:GetDoor() == bOpen ) then return end

    self:SetDoor(bOpen)
    self:ResetSequence(self:LookupSequence(bOpen and "open" or "close"))
    self:EmitSound("doors/door_metal_thin_move1.wav", 75, bOpen and 90 or 100)
end

--- Lets a player in only through the open door or while noclipping, then seats them like any LVS vehicle.
---@param client Player
function ENT:SetPassenger(client)
    if ( !IsValid(client) ) then return end

    if ( self.bDoorRequired and client:GetMoveType() != MOVETYPE_NOCLIP and !self:GetDoor() and !client:InVehicle() ) then
        self:EmitSound("doors/default_locked.wav")
        client:PrintMessage(HUD_PRINTCENTER, "The door is closed, you must be noclipped or the door must be open to enter!")

        return
    end

    local bAI = self:GetAI()
    local gunnerSeat = self:GetDriverSeat()
    local bMayGun = hook.Run("LVS.CanPlayerDrive", client, self) != false

    if ( IsValid(gunnerSeat) and !IsValid(gunnerSeat:GetDriver()) and !client:KeyDown(IN_WALK) and !bAI and bMayGun ) then
        client:EnterVehicle(gunnerSeat)

        return
    end

    local closest
    local closestDistance = math.huge

    for _, seat in pairs(self:GetPassengerSeats()) do
        if ( !IsValid(seat) or IsValid(seat:GetDriver()) or seat:GetNWInt("pPodIndex") == -1 ) then continue end

        local distance = seat:GetPos():DistToSqr(client:GetPos())

        if ( distance < closestDistance ) then
            closest = seat
            closestDistance = distance
        end
    end

    if ( IsValid(closest) ) then
        client:EnterVehicle(closest)

        return
    end

    self:EmitSound("doors/default_locked.wav")
    client:PrintMessage(HUD_PRINTCENTER, "No available seats!")
end

--- Lets the container's own gunner AI fire at enemies in range while no dropship carries it.
function ENT:RunAI()
    if ( self:GetCarryingDropship() ) then return end

    local target = self:AIGetTarget()

    if ( !IsValid(target) or target:GetPos():DistToSqr(self:GetPos()) > AI_GUN_RANGE * AI_GUN_RANGE ) then
        self:SetGunInput(nil, false)

        return
    end

    self:SetGunInput(target:WorldSpaceCenter(), self:AICanSee(target))
end

--- Plays the idle of the door's state once it has finished opening or closing.
function ENT:UpdateDoorSequence()
    local idle = self:LookupSequence(self:GetDoor() and "open_idle" or "close_idle")
    if ( self:GetSequence() == idle or !self:IsSequenceFinished() ) then return end

    self:ResetSequence(idle)
end

function ENT:OnTick()
    local now = CurTime()
    if ( now < self.nextContainerThink ) then return end

    self.nextContainerThink = now + THINK_INTERVAL

    self:UpdateDoorSequence()
    self:GunThink()
end

function ENT:OnRemoved()
    self:StopGunSound()

    local carrier = self:GetCarryingDropship()

    if ( carrier and carrier.ReleaseCargo ) then
        carrier:ReleaseCargo()
    end
end
