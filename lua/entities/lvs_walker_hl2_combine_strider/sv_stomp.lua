--- Skewer of the strider, ported from CNPC_Strider::MeleeAttack1Conditions, the stomp task and CNPC_Strider::StompHit: the strider stops, raises its left leg and stabs it down on whoever stands close to the spike.

--- Farthest from the spike a victim can be and still be stabbed, STRIDER_STOMP_RANGE.
local STOMP_RANGE = 260

--- Seconds before the strider can skewer again, m_nextStompTime.
local STOMP_INTERVAL = 5

--- Damage and push of the stab.
local STOMP_DAMAGE = 500
local STOMP_FORCE = 50 * 300

--- Animation of the stab with the left leg, ACT_STRIDER_STOMPL; the original only ever uses the left one.
local STOMP_SEQUENCE = "BighitL"

--- Prepares the state of the skewer.
function ENT:InitStomp()
    self.nextStompTime = 0
    self.stompEndTime = 0
end

--- Returns whether the strider is in the middle of a stab.
---@return boolean bStomping
function ENT:IsStomping()
    return CurTime() < (self.stompEndTime or 0)
end

--- Returns whether the strider can stab: not too soon after the last one, standing tall enough and not busy with its cannon, from CNPC_Strider::MeleeAttack1Conditions.
---@return boolean bCanStomp
function ENT:CanStomp()
    if ( self:IsStomping() or CurTime() < self.nextStompTime ) then return false end
    if ( self:GetHP() <= 0 or self:GetCarryingDropship() or self:GetCannonCharging() ) then return false end
    if ( self:IsInCrouchedPosture() ) then return false end

    return self:GetHeight() >= self.StandHeight - (self.StandHeight - self.CrouchHeight) / 2
end

--- Stabs when the pilot asks and the strider can.
function ENT:TryStomp()
    if ( self:GetAI() or !self:CanStomp() ) then return end

    self:StartStomp()
end

--- Starts the stab animation.
function ENT:StartStomp()
    local sequence = self:LookupSequence(STOMP_SEQUENCE)
    if ( sequence < 0 ) then return end

    local now = CurTime()

    self:ResetSequence(sequence)
    self:SetCycle(0)
    self:SetPlaybackRate(1)

    self.stompEndTime = now + self:SequenceDuration(sequence)
    self.nextStompTime = now + STOMP_INTERVAL
end

--- Returns whether an entity can be skewered.
---@param ent Entity
---@return boolean bValid
function ENT:IsStompVictim(ent)
    if ( !IsValid(ent) or ent == self or ent == self:GetDriver() ) then return false end
    if ( !( ent:IsNPC() or ent:IsPlayer() or ent:IsNextBot() ) ) then return false end
    if ( ent:Health() <= 0 or ( ent:IsPlayer() and ( !ent:Alive() or ent:InVehicle() ) ) ) then return false end

    return true
end

--- Lands the stab: whoever stands closest to the spike is run through, from CNPC_Strider::StompHit.
---@param attachmentName string Attachment of the spike that stabs.
function ENT:StompHit(attachmentName)
    local spike = self:GetStriderAttachment(attachmentName)
    if ( !spike ) then return end

    local victim
    local closest = STOMP_RANGE * STOMP_RANGE

    for _, ent in ipairs(ents.FindInSphere(spike.Pos, STOMP_RANGE)) do
        if ( !self:IsStompVictim(ent) ) then continue end

        local distance = ent:GetPos():DistToSqr(spike.Pos)

        if ( distance < closest ) then
            victim = ent
            closest = distance
        end
    end

    if ( !victim ) then return end

    local hitPos = victim:GetPos()
    local stabPos = (victim:WorldSpaceCenter() + victim:EyePos()) * 0.5
    local attacker = self:GetDriver()

    if ( !IsValid(attacker) ) then
        attacker = self
    end

    EmitSound("NPC_Strider.Skewer", hitPos)

    local dmginfo = DamageInfo()
    dmginfo:SetAttacker(attacker)
    dmginfo:SetInflictor(self)
    dmginfo:SetDamage(STOMP_DAMAGE)
    dmginfo:SetDamageType(DMG_CRUSH)
    dmginfo:SetDamagePosition(hitPos)
    dmginfo:SetDamageForce(-STOMP_FORCE * victim:GetForward())
    victim:TakeDamageInfo(dmginfo)

    local foot = self:GetFootPosition("left foot")
    local bloodDir = foot - stabPos
    bloodDir.z = 0
    bloodDir:Normalize()

    local effectData = EffectData()
    effectData:SetOrigin(stabPos + bloodDir * 4)
    effectData:SetNormal(bloodDir)
    effectData:SetColor(BLOOD_COLOR_RED)
    effectData:SetScale(8)
    effectData:SetFlags(3)
    util.Effect("bloodspray", effectData)
end

--- Shows the rest of the wait until the next stab as the skewer's heat.
function ENT:UpdateStompHeat()
    self:SetWeaponHeat(self.WEAPON_SKEWER, math.max(self.nextStompTime - CurTime(), 0) / STOMP_INTERVAL)
end
