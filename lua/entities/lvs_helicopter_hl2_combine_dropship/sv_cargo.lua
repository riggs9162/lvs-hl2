--- Cargo of the dropship, from the pickup, carry and drop code of npc_combinedropship.cpp (InputPickup, the swooping landing state, DropSoldierContainer, InputDropStrider and InputDropAPC). Cargo of this addon is held to its place by a physics shadow as in the original (lvs_hl2/sv_dropship_cargo.lua), so that the dropship flies as if it weighed nothing; any other physical cargo is welded on, loses its weight and is moved along with the dropship on every tick; NPCs are parented and frozen, as the original parents them.

--- Farthest the cargo may be from where it would hang for the grabber to latch on to it.
local PICKUP_REACH = 300

--- Radius around the dropship in which the grabber looks for cargo.
local CARGO_SEARCH_RADIUS = 800

--- Share of the way to its place a parented cargo moves on every think, from CNPC_CombineDropship::Flight.
local SETTLE_SHARE = 0.05

--- Seconds after the release during which the cargo still passes through the dropship.
local NOCOLLIDE_RELEASE_TIME = 1

--- How each kind of cargo hangs under the dropship, from CNPC_CombineDropship::Spawn. Any entity may also offer itself as cargo with an HL2DropshipCargo table of the same form. A parented NPC with a deploy sequence plays it backwards while it is picked up and forwards once it is set down, and stays frozen until it has finished.
local CARGO_TYPES = {
    lvs_hl2_dropship_container = {
        offset = Vector(0, 0, 0),
        angles = Angle(0, 0, 0),
    },
    npc_strider = {
        offset = Vector(0, 0, -100),
        angles = Angle(0, 0, 0),
        bParent = true,
        sequence = "carried",
        deploySequence = "deploy",
    },
    lvs_wheeldrive_hl2_combine_apc = {
        offset = Vector(0, 0, -25),
        bAlignForward = true,
        bStopOnRelease = true,
    },
    prop_vehicle_apc = {
        offset = Vector(0, 0, -25),
        angles = Angle(0, -90, 0),
        bStopOnRelease = true,
    },
}

--- Returns how far an NPC is through playing its deploy sequence, from 0 to 1.
---@param ent Entity
---@param sequence number
---@param startTime number
---@return number progress
local function GetDeployProgress(ent, sequence, startTime)
    return math.Clamp((CurTime() - startTime) / ent:SequenceDuration(sequence), 0, 1)
end

--- Shows an NPC at a point of its deploy sequence, held still so that the clients show the same frame.
---@param ent Entity
---@param sequence number
---@param cycle number
local function SetDeployCycle(ent, sequence, cycle)
    if ( ent:GetSequence() != sequence ) then
        ent:ResetSequence(sequence)
    end

    ent:SetPlaybackRate(0)
    ent:SetCycle(cycle)
end

--- Returns when a deploy sequence played in a direction would have started to be where the NPC is in it now, so that folding up and unfolding carry on from each other.
---@param ent Entity
---@param sequence number
---@param bForward boolean
---@return number startTime
local function GetDeployStartTime(ent, sequence, bForward)
    if ( ent:GetSequence() != sequence ) then return CurTime() end

    local cycle = ent:GetCycle()
    local progress = bForward and cycle or 1 - cycle

    return CurTime() - progress * ent:SequenceDuration(sequence)
end

--- Freezes a carried NPC and stops its thinking, so that its own animations do not fight the ones the dropship plays on it.
---@param ent Entity
local function HoldCargoNPC(ent)
    if ( !ent:IsNPC() ) then return end

    ent:SetCondition(COND_NPC_FREEZE)
    ent:AddEFlags(EFL_NO_THINK_FUNCTION)
end

--- Lets a released NPC think and move again.
---@param ent Entity
local function ResumeCargoNPC(ent)
    ent:SetPlaybackRate(1)

    if ( !ent:IsNPC() ) then return end

    ent:RemoveEFlags(EFL_NO_THINK_FUNCTION)
    ent:SetCondition(COND_NPC_UNFREEZE)
    ent:NextThink(CurTime())
end

--- Unfolds a released NPC by playing its deploy sequence, and lets it move again once it stands.
---@param ent Entity
---@param sequence number
local function DeployReleasedNPC(ent, sequence)
    local startTime = GetDeployStartTime(ent, sequence, true)
    local timerName = "lvs_hl2_dropship_deploy_" .. ent:EntIndex()

    timer.Create(timerName, 0, 0, function()
        if ( !IsValid(ent) or IsValid(ent.hl2DropshipCarrier) ) then
            timer.Remove(timerName)

            return
        end

        local progress = GetDeployProgress(ent, sequence, startTime)
        SetDeployCycle(ent, sequence, progress)

        if ( progress < 1 ) then return end

        timer.Remove(timerName)
        ResumeCargoNPC(ent)
    end)
end

--- Returns how an entity hangs under the dropship, or nil when it cannot be carried.
---@param ent Entity
---@return table|nil config
function ENT:GetCargoConfig(ent)
    if ( !IsValid(ent) or ent == self ) then return nil end
    if ( istable(ent.HL2DropshipCargo) ) then return ent.HL2DropshipCargo end

    local class = ent:GetClass()

    for cargoClass, config in pairs(CARGO_TYPES) do
        if ( class == cargoClass or scripted_ents.IsBasedOn(class, cargoClass) ) then return config end
    end

    return nil
end

--- Returns the angles a cargo hangs at relative to the dropship; LVS vehicles are turned so that they face the dropship's way.
---@param ent Entity
---@param config table
---@return Angle angles
function ENT:GetCargoLocalAngles(ent, config)
    if ( config.bAlignForward and ent.ForwardAngle ) then return Angle(0, -ent.ForwardAngle.y, 0) end

    return config.angles or angle_zero
end

--- Returns the cargo below the dropship closest to where it would hang, within the grabber's reach.
---@return Entity|nil cargo
function ENT:FindCargo()
    local best
    local bestDistance = PICKUP_REACH

    for _, ent in ipairs(ents.FindInSphere(self:GetPos(), CARGO_SEARCH_RADIUS)) do
        local config = self:GetCargoConfig(ent)
        if ( !config or IsValid(ent.hl2DropshipCarrier) or IsValid(ent:GetParent()) ) then continue end

        local distance = ent:GetPos():Distance(self:LocalToWorld(config.offset))

        if ( distance < bestDistance ) then
            best = ent
            bestDistance = distance
        end
    end

    return best
end

--- Moves a physical cargo and everything constrained to it to a new place, keeping their layout.
---@param parts table Entities of the cargo, keyed by entity.
---@param root Entity Entity whose new place is given.
---@param pos Vector
---@param angles Angle
---@param velocity Vector
local function MoveParts(parts, root, pos, angles, velocity)
    local rootPos, rootAngles = root:GetPos(), root:GetAngles()
    local moves = {}

    for part in pairs(parts) do
        local localPos, localAngles = WorldToLocal(part:GetPos(), part:GetAngles(), rootPos, rootAngles)
        local newPos, newAngles = LocalToWorld(localPos, localAngles, pos, angles)

        moves[part] = {pos = newPos, angles = newAngles}
    end

    for part, move in pairs(moves) do
        local phys = part:GetPhysicsObject()

        if ( IsValid(phys) ) then
            phys:SetPos(move.pos)
            phys:SetAngles(move.angles)
            phys:SetVelocity(velocity)
            phys:Wake()
        else
            part:SetPos(move.pos)
            part:SetAngles(move.angles)
        end
    end
end

--- Latches on to a cargo: NPCs are parented and frozen in their carried pose, cargo that supports it is held by a physics shadow, and everything else is welded on, loses its weight and is moved along with the dropship.
---@param ent Entity
---@param bDefault boolean|nil Whether the dropship spawned with it, which removes it together with the dropship while it is carried.
function ENT:GrabCargo(ent, bDefault)
    local config = self:GetCargoConfig(ent)
    if ( !config or self.cargo ) then return end

    local localAngles = self:GetCargoLocalAngles(ent, config)
    local data = {ent = ent, config = config, bDefault = bDefault}

    if ( config.bParent ) then
        data.moveType = ent:GetMoveType()

        ent:SetOwner(self)
        ent:SetParent(self)
        ent:SetLocalAngles(localAngles)
        ent:SetMoveType(MOVETYPE_NONE)
        HoldCargoNPC(ent)

        local deploySequence = config.deploySequence and ent:LookupSequence(config.deploySequence) or -1
        local sequence = config.sequence and ent:LookupSequence(config.sequence) or -1

        if ( deploySequence >= 0 and !bDefault ) then
            data.deploySequence = deploySequence
            data.foldStart = GetDeployStartTime(ent, deploySequence, false)
            SetDeployCycle(ent, deploySequence, 1 - GetDeployProgress(ent, deploySequence, data.foldStart))
        elseif ( sequence >= 0 ) then
            ent:ResetSequence(sequence)
        end
    else
        local parts = constraint.GetAllConstrainedEntities(ent)
        local velocity = self:GetVelocity()

        parts[self] = nil
        data.parts = {}
        data.noCollides = {}

        for part in pairs(parts) do
            data.noCollides[#data.noCollides + 1] = constraint.NoCollide(self, part, 0, 0)
        end

        MoveParts(parts, ent, self:LocalToWorld(config.offset), self:LocalToWorldAngles(localAngles), velocity)

        for part in pairs(parts) do
            local phys = part:GetPhysicsObject()
            if ( !IsValid(phys) ) then continue end

            data.parts[part] = {bGravity = phys:IsGravityEnabled()}
            phys:EnableGravity(false)
        end

        if ( ent.bHL2DropshipShadowCargo ) then
            data.bShadow = true
            ent:SetHL2DropshipCarry(self, config.offset, localAngles)
        else
            data.weld = constraint.Weld(self, ent, 0, 0, 0, true, false)
        end
    end

    ent.hl2DropshipCarrier = self

    if ( ent.SetCarrier ) then
        ent:SetCarrier(self)
    end

    if ( bDefault ) then
        self:DeleteOnRemove(ent)
    end

    self.cargo = data
    self:SetCargo(ent)
    self:ResetSequence(self:LookupSequence("cargo_idle"))
    self:EmitSound("doors/door_metal_medium_open1.wav")
end

--- Lets go of the cargo. A container keeps falling as it was moving, an APC that still works stops dead, and an NPC is set upright and unfolds before it moves again, from DropSoldierContainer, InputDropAPC and InputDropStrider.
function ENT:ReleaseCargo()
    local data = self.cargo
    if ( !data ) then return end

    self.cargo = nil
    self:SetCargo(NULL)
    self:ResetSequence(self:LookupSequence("idle_exagg"))

    local ent = data.ent
    if ( !IsValid(ent) ) then return end

    ent.hl2DropshipCarrier = nil

    if ( ent.SetCarrier ) then
        ent:SetCarrier(NULL)
    end

    if ( data.bDefault ) then
        self:DontDeleteOnRemove(ent)
    end

    self:EmitSound("buttons/lever8.wav")

    if ( data.config.bParent ) then
        local angles = ent:GetAngles()
        local pos = ent:GetPos()

        angles.p = 0
        angles.r = 0

        ent:SetParent(NULL)
        ent:SetOwner(NULL)
        ent:SetPos(pos)
        ent:SetAngles(angles)
        ent:SetMoveType(data.moveType)

        local deploySequence = data.config.deploySequence and ent:LookupSequence(data.config.deploySequence) or -1

        if ( deploySequence >= 0 and ent:Health() > 0 ) then
            DeployReleasedNPC(ent, deploySequence)
        else
            ResumeCargoNPC(ent)
        end

        return
    end

    if ( data.bShadow ) then
        ent:SetHL2DropshipCarry(nil)
    else
        SafeRemoveEntity(data.weld)
    end

    local velocity = self:GetVelocity()
    velocity.z = math.min(velocity.z, 0)

    local health = ent.GetHP and ent:GetHP() or ent:Health()

    if ( data.config.bStopOnRelease and health > 0 ) then
        velocity = Vector(0, 0, 0)
    end

    for part, saved in pairs(data.parts) do
        local phys = IsValid(part) and part:GetPhysicsObject()

        if ( IsValid(phys) ) then
            phys:EnableGravity(saved.bGravity)
            phys:SetVelocity(velocity)
            phys:Wake()
        end
    end

    timer.Simple(NOCOLLIDE_RELEASE_TIME, function()
        for _, noCollide in ipairs(data.noCollides) do
            SafeRemoveEntity(noCollide)
        end
    end)
end

--- Moves every part of a welded cargo along with the dropship, as if it were part of it, so that its weight and inertia do not drag on the dropship's flight.
function ENT:FollowCargo()
    local data = self.cargo
    if ( !data or !data.parts or data.bShadow ) then return end

    local selfPhys = self:GetPhysicsObject()
    if ( !IsValid(selfPhys) ) then return end

    local angVelocity = selfPhys:LocalToWorldVector(selfPhys:GetAngleVelocity())

    for part in pairs(data.parts) do
        local phys = IsValid(part) and part:GetPhysicsObject()

        if ( IsValid(phys) ) then
            phys:SetVelocityInstantaneous(selfPhys:GetVelocityAtPoint(phys:LocalToWorld(phys:GetMassCenter())))
            phys:SetAngleVelocityInstantaneous(phys:WorldToLocalVector(angVelocity))
        end
    end
end

--- Latches on to the cargo below, or lets go of the cargo carried.
function ENT:ToggleCargo()
    if ( self.cargo ) then
        self:ReleaseCargo()

        return
    end

    local ent = self:FindCargo()

    if ( !ent ) then
        self:EmitSound("buttons/button10.wav")

        return
    end

    self:GrabCargo(ent)
end

--- Keeps the cargo state up to date on every think: forgets cargo that is gone, lets go of a dead NPC, draws a parented cargo slowly into its place, from CNPC_CombineDropship::Flight, folds up an NPC that was just picked up and then holds it in its carried pose.
function ENT:CargoThink()
    local data = self.cargo
    if ( !data ) then return end

    local ent = data.ent

    if ( !IsValid(ent) ) then
        self.cargo = nil
        self:SetCargo(NULL)
        self:ResetSequence(self:LookupSequence("idle_exagg"))

        return
    end

    if ( !data.config.bParent ) then return end

    if ( ent:IsNPC() and ent:Health() <= 0 ) then
        self:ReleaseCargo()

        return
    end

    ent:SetLocalPos(LerpVector(SETTLE_SHARE, ent:GetLocalPos(), data.config.offset))

    if ( data.foldStart ) then
        local progress = GetDeployProgress(ent, data.deploySequence, data.foldStart)
        SetDeployCycle(ent, data.deploySequence, 1 - progress)

        if ( progress < 1 ) then return end

        data.foldStart = nil
        ent:SetPlaybackRate(1)
    end

    local sequence = data.config.sequence and ent:LookupSequence(data.config.sequence) or -1

    if ( sequence >= 0 and ent:GetSequence() != sequence ) then
        ent:ResetSequence(sequence)
    end
end

--- Passes damage on to the cargo, since the dropship itself cannot be hurt: everything to a container, only vehicle guns to anything else, from CNPC_CombineDropship::OnTakeDamage_Alive.
---@param dmginfo CTakeDamageInfo
function ENT:OnTakeDamage(dmginfo)
    local data = self.cargo
    if ( !data or !IsValid(data.ent) ) then return end

    if ( self:GetContainer() or dmginfo:IsDamageType(DMG_AIRBOAT) ) then
        data.ent:TakeDamageInfo(dmginfo)
    end
end
