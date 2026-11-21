--- Damage and death of the strider, ported from CNPC_Strider::TraceAttack, OnTakeDamage_Alive, TakeDamageFromCombineBall, StartSmoking, BecomeRagdoll and RagdollDeathEffect. Bullets glance off; only strong blasts close to the body hurt it, a player's rocket far more than anyone else's, and once dead it collapses into a smoking wreck.

--- Health the original measures a rocket's share of its health against, m_iMaxHealth.
local ORIGINAL_MAX_HEALTH = 500

--- Damage of a blast from anyone but a player.
local NPC_BLAST_DAMAGE = 20

--- Weakest blast that hurts the strider.
local MIN_BLAST_DAMAGE = 50

--- Farthest from the body a blast can go off and still hurt it.
local BLAST_REACH = 200

--- Damage of a pulse rifle's energy ball, strider_ar2_altfire_dmg.
local AR2_BALL_DAMAGE = 25

--- Seconds the minigun holds back while the strider flinches.
local FLINCH_MINIGUN_HOLD = 1.1

--- Health below which a spark now and then flies off the hull, and the chance of one in this many on every think.
local SPARK_HEALTH = 50
local SPARK_CHANCE = 21

--- Seconds the smoke of a damaged strider and of its wreck last.
local SMOKE_LIFETIME = 500
local WRECK_SMOKE_LIFETIME = 600

--- Settings of the smoke a badly damaged strider trails, from CNPC_Strider::StartSmoking.
local DAMAGE_SMOKE = {
    spawnrate = "32",
    lifetime = "3",
    startsize = "16",
    endsize = "64",
    spawnradius = "20",
    minspeed = "8",
    maxspeed = "64",
    opacity = "0.3",
    startcolor = "0.25 0.25 0.25",
    endcolor = "0 0 0",
}

--- Settings of the two smoke trails of the wreck, from CNPC_Strider::RagdollDeathEffect.
local WRECK_SMOKE = {
    {
        attachment = "MiniGunBase",
        settings = {spawnrate = "16", opacity = "0.25", startcolor = "0.45 0.45 0.45", lifetime = "3", startsize = "16", endsize = "64", spawnradius = "20", minspeed = "8", maxspeed = "64", endcolor = "0 0 0"},
    },
    {
        attachment = "vehicle_driver_eyes",
        settings = {spawnrate = "32", opacity = "0.3", startcolor = "0.5 0.5 0.5", lifetime = "3", startsize = "16", endsize = "64", spawnradius = "20", minspeed = "8", maxspeed = "64", endcolor = "0 0 0"},
    },
}

--- Creates a smoke trail on an attachment of an entity.
---@param parent Entity
---@param attachmentName string
---@param settings table
---@param lifetime number
---@return Entity|nil trail
local function CreateSmokeTrail(parent, attachmentName, settings, lifetime)
    local trail = ents.Create("env_smoketrail")
    if ( !IsValid(trail) ) then return nil end

    for key, value in pairs(settings) do
        trail:SetKeyValue(key, value)
    end

    local attachment = parent:GetAttachment(parent:LookupAttachment(attachmentName))

    trail:SetPos(attachment and attachment.Pos or parent:GetPos())
    trail:SetParent(parent)
    trail:Spawn()
    trail:Activate()

    if ( attachment ) then
        trail:Fire("SetParentAttachment", attachmentName)
    end

    SafeRemoveEntityDelayed(trail, lifetime)
    parent:DeleteOnRemove(trail)

    return trail
end

--- Prepares the damage state.
function ENT:InitDamage()
    self.smokeTrail = nil
end

--- Returns how much a blast hurts: a player's rocket takes the share of the health the skill level allows, anyone else's twenty points, from CNPC_Strider::OnTakeDamage_Alive.
---@param attacker Entity
---@return number damage
function ENT:GetBlastDamage(attacker)
    if ( !IsValid(attacker) or !attacker:IsPlayer() ) then return NPC_BLAST_DAMAGE end

    local skill = game.GetSkillLevel()
    local convar = GetConVar(skill == 1 and "sk_strider_num_missiles1" or skill == 3 and "sk_strider_num_missiles3" or "sk_strider_num_missiles2")
    local missiles = convar and convar:GetFloat() or 7

    return ORIGINAL_MAX_HEALTH / math.max(missiles, 1)
end

--- Lets smoke pour from the minigun's mount, from CNPC_Strider::StartSmoking.
function ENT:StartSmoking()
    if ( IsValid(self.smokeTrail) ) then return end

    self.smokeTrail = CreateSmokeTrail(self, "MiniGunBase", DAMAGE_SMOKE, SMOKE_LIFETIME)
end

--- Shows a bullet glancing off the hull.
---@param dmginfo CTakeDamageInfo
function ENT:Ricochet(dmginfo)
    local pos = dmginfo:GetDamagePosition()
    if ( pos:IsZero() ) then return end

    local effectData = EffectData()
    effectData:SetOrigin(pos)
    effectData:SetNormal(-dmginfo:GetDamageForce():GetNormalized())
    util.Effect("MetalSpark", effectData)
end

--- Takes damage like the original: its own weapons never hurt it, a pulse rifle's energy ball and the npc_kill kind always do, strong blasts close to the body take a fixed share, and bullets only glance off.
---@param dmginfo CTakeDamageInfo
function ENT:OnTakeDamage(dmginfo)
    if ( self:GetHP() <= 0 ) then return end

    local inflictor = dmginfo:GetInflictor()
    local attacker = dmginfo:GetAttacker()

    if ( inflictor == self or attacker == self or ( IsValid(inflictor) and inflictor:GetOwner() == self ) ) then return end

    local damage = 0

    if ( IsValid(inflictor) and inflictor:GetClass() == "prop_combine_ball" ) then
        damage = AR2_BALL_DAMAGE
    elseif ( dmginfo:GetDamageType() == DMG_GENERIC ) then
        damage = dmginfo:GetDamage()
    elseif ( dmginfo:IsDamageType(DMG_BLAST) and math.max(dmginfo:GetMaxDamage(), dmginfo:GetDamage()) > MIN_BLAST_DAMAGE ) then
        local pos = dmginfo:GetDamagePosition()

        if ( pos:IsZero() ) then
            pos = self:GetPos()
        end

        if ( self:NearestPoint(pos):Distance(pos) < BLAST_REACH ) then
            damage = self:GetBlastDamage(attacker)
        end
    elseif ( dmginfo:IsDamageType(DMG_BULLET) or dmginfo:IsDamageType(DMG_AIRBOAT) or dmginfo:IsDamageType(DMG_BUCKSHOT) ) then
        self:Ricochet(dmginfo)

        return
    end

    if ( damage <= 0 ) then return end

    local health = self:GetHP() - damage

    self:SetHP(health)

    if ( IsValid(attacker) and attacker:IsPlayer() ) then
        net.Start("lvs_hitmarker")
        net.WriteBool(false)
        net.Send(attacker)
    end

    if ( health <= 0 ) then
        self:Die(dmginfo)

        return
    end

    self:EmitSound("NPC_Strider.Pain")
    self:HoldMinigun(FLINCH_MINIGUN_HOLD)

    if ( health <= self.MaxHealth / 2 ) then
        self:StartSmoking()
    end
end

--- Throws a spark off the hull now and then once the next rocket would finish the strider off, from CNPC_Strider::PrescheduleThink.
function ENT:SparkThink()
    if ( self:GetHP() > SPARK_HEALTH or self:GetHP() <= 0 ) then return end
    if ( math.random(1, SPARK_CHANCE) != 1 ) then return end

    local spark = ents.Create("sparktrail")
    if ( !IsValid(spark) ) then return end

    spark:SetOwner(self)
    spark:Spawn()
end

--- Kills the strider: the pilot dies with it and it collapses.
---@param dmginfo CTakeDamageInfo
function ENT:Die(dmginfo)
    self.FinalAttacker = dmginfo:GetAttacker()
    self.FinalInflictor = dmginfo:GetInflictor()

    self:AbortCannon()
    self:StopMinigun()
    self:SetDestroyed(false)
    self:Explode()
end

--- Skips the LVS explosion, since the strider collapses instead.
function ENT:OnStartExplosion()
end

--- Collapses the strider into a ragdoll in the pose it died in, smoking from its gun mount and its head, with a crash that shakes the ground, from CNPC_Strider::BecomeRagdoll and RagdollDeathEffect.
function ENT:OnFinishExplosion()
    local pos = self:GetPos()

    EmitSound("NPC_Strider.Death", pos)
    util.ScreenShake(pos, 50, 150, 1, 1024)

    local ragdoll = ents.Create("prop_ragdoll")
    if ( !IsValid(ragdoll) ) then return end

    local skeletonOffset = self:GetUp() * self:GetSkeletonOffset(self:GetHeight())

    ragdoll:SetModel(self:GetModel())
    ragdoll:SetPos(pos + skeletonOffset)
    ragdoll:SetAngles(self:GetAngles())
    ragdoll:Spawn()
    ragdoll:Activate()

    local velocity = self:GetVelocity()

    for index = 0, ragdoll:GetPhysicsObjectCount() - 1 do
        local phys = ragdoll:GetPhysicsObjectNum(index)
        local bone = ragdoll:TranslatePhysBoneToBone(index)
        local bonePos, boneAngles = self:GetBonePosition(bone)

        if ( IsValid(phys) and bonePos ) then
            phys:SetPos(bonePos + skeletonOffset)
            phys:SetAngles(boneAngles)
            phys:SetVelocity(velocity)
            phys:Wake()
        end
    end

    if ( self.CPPIGetOwner and ragdoll.CPPISetOwner ) then
        ragdoll:CPPISetOwner(self:CPPIGetOwner())
    end

    for _, smoke in ipairs(WRECK_SMOKE) do
        CreateSmokeTrail(ragdoll, smoke.attachment, smoke.settings, WRECK_SMOKE_LIFETIME)
    end
end
