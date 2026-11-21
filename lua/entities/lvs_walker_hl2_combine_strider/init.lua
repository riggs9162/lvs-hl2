AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")
include("lvs_hl2/sv_dropship_cargo.lua")
include("sv_walk.lua")
include("sv_minigun.lua")
include("sv_cannon.lua")
include("sv_stomp.lua")
include("sv_damage.lua")
include("sv_ai.lua")

--- Seconds between two thinks of the original NPC, at which it aims, fires and changes height.
local THINK_INTERVAL = 0.1

--- Animation events of the original's model, from npc_strider.cpp.
local AE_FOOTSTEP_LEFT = {[1] = true, [4] = true, [7] = true}
local AE_FOOTSTEP_RIGHT = {[2] = true, [5] = true, [8] = true}
local AE_FOOTSTEP_BACK = {[3] = true, [6] = true, [9] = true}
local AE_WHOOSH = {[11] = "left foot", [12] = "right foot", [13] = "back foot"}
local AE_CREAK = {[21] = true, [22] = true, [23] = true}
local AE_STOMPHITL = 110
local AE_STOMPHITR = 111

function ENT:OnSpawn(phys)
    local driverSeat = self:AddDriverSeat(Vector(0, 0, 0), Angle(0, -90, 0))
    driverSeat:SetCameraDistance(1)
    driverSeat.HidePlayer = true

    self.driverSeat = driverSeat

    self:InitWalk()
    self:InitMinigun()
    self:InitCannon()
    self:InitStomp()
    self:InitDamage()
    self:InitAI()

    self.nextStriderThink = 0
end

--- Runs what the original does on every think of the NPC: the height, the turning gestures, the minigun and the cannon, from CNPC_Strider::NPCThink and OverrideMove.
function ENT:StriderThink()
    self:UpdateHeight(THINK_INTERVAL)
    self:MaintainTurnActivity()
    self:MinigunThink(THINK_INTERVAL)
    self:CannonThink(THINK_INTERVAL)
    self:SparkThink()
end

function ENT:OnTick()
    local deltatime = FrameTime()

    self:UpdateGround(deltatime)
    self:UpdateWalk(deltatime)

    local now = CurTime()
    if ( now < self.nextStriderThink ) then return end

    self.nextStriderThink = now + THINK_INTERVAL
    self:StriderThink()
end

--- Plays the footsteps, the whoosh of the legs and the creaks of the joints the walk animation calls for, and lands the skewer, from CNPC_Strider::HandleAnimEvent.
---@param event number
---@return boolean bHandled
function ENT:HandleAnimEvent(event)
    if ( AE_FOOTSTEP_LEFT[event] ) then
        self:FootHit("left foot")
    elseif ( AE_FOOTSTEP_RIGHT[event] ) then
        self:FootHit("right foot")
    elseif ( AE_FOOTSTEP_BACK[event] ) then
        self:FootHit("back foot")
    elseif ( AE_WHOOSH[event] ) then
        EmitSound("NPC_Strider.Whoosh", self:GetFootPosition(AE_WHOOSH[event]))
    elseif ( AE_CREAK[event] ) then
        self:EmitSound("NPC_Strider.Creak")
    elseif ( event == AE_STOMPHITL or event == AE_STOMPHITR ) then
        self:StompHit(event == AE_STOMPHITL and "left skewer" or "right skewer")
    else
        return false
    end

    return true
end

--- Holds the strider to its place while a dropship carries it, and otherwise lets it walk.
---@param phys PhysObj
---@param deltatime number
function ENT:PhysicsSimulate(phys, deltatime)
    local angularAccel, linearAccel, simulate = self:SimulateHL2DropshipCarry(phys, deltatime)
    if ( simulate ) then return angularAccel, linearAccel, simulate end

    return self:SimulateWalk(phys, deltatime)
end

--- Crouches or stands back up, from the original's Crouch and Stand inputs.
---@param bActive boolean Whether to crouch.
function ENT:OnVehicleSpecificToggled(bActive)
    self:SetIdealHeight(bActive and self.CrouchHeight or self.StandHeight)
end

function ENT:OnRemoved()
    self:StopMinigun()
end
