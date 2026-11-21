--- Autopilot of the dropship. The original only flies along path tracks laid out by the map and lets its container's cannon fire at enemies in range; without path tracks the autopilot wanders like any LVS helicopter, kept to patrol height and clear of obstacles, always facing where it flies, from CNPC_CombineDropship::Hunt and DoCombatStuff.

DEFINE_BASECLASS("lvs_base_helicopter")

--- Farthest an enemy may be for the container's cannon to fire at it, the original's default GunRange.
local AI_GUN_RANGE = 2048

--- Prepares the autopilot state.
function ENT:InitAI()
    self.bAIFaceTravel = true
end

--- Wanders, and fires the container's cannon at an enemy that is in range and in sight.
function ENT:RunAI()
    self:UpdateAIAvoidance()

    BaseClass.RunAI(self)

    self:LimitAIPatrolAltitude()
    self:SetAIWeapon(self.WEAPON_CONTAINER_GUN)
    self.bAIFaceTravel = true

    local target = self:AIGetTarget()
    local bInRange = IsValid(target) and target:GetPos():DistToSqr(self:GetPos()) <= AI_GUN_RANGE * AI_GUN_RANGE

    self._AIFireInput = bInRange and self:GetContainer() != nil and self:AICanSee(target)

    if ( !IsValid(target) ) then return end

    local pod = self:GetDriverSeat()
    local eyePos = IsValid(pod) and pod:LocalToWorld(pod:OBBCenter()) or self:WorldSpaceCenter()

    self:SetAIAimVector((target:WorldSpaceCenter() - eyePos):GetNormalized())
end
