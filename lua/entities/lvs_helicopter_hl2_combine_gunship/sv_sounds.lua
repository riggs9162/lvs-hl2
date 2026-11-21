--- Voice of the gunship, ported from CNPC_CombineGunship::Ping and the new enemy handling of CNPC_CombineGunship::DoCombat.

--- Seconds between two pings.
local PING_INTERVAL = 3

--- Seconds before the gunship cries out at a new enemy again.
local SEE_ENEMY_INTERVAL = 5

--- Prepares the state of the voice.
function ENT:InitSounds()
    local now = CurTime()

    self.nextPing = now + 2
    self.nextSeeEnemySound = now
    self.lastEnemy = nil
end

--- Pings while the gunship searches for an enemy it has lost sight of, or while it patrols without one.
function ENT:Ping()
    if ( !self:GetEngineActive() ) then return end

    local now = CurTime()
    if ( now <= self.nextPing ) then return end

    local enemy = self:GetCannonEnemy()

    if ( enemy ) then
        if ( self:AICanSee(enemy) ) then return end

        self:EmitSound("NPC_CombineGunship.SearchPing")
    else
        self:EmitSound("NPC_CombineGunship.PatrolPing")
    end

    self.nextPing = now + PING_INTERVAL
end

--- Returns whether an enemy is a player or carries one, the only enemies the original cries out at.
---@param enemy Entity
---@return boolean bPlayer
local function IsPlayerEnemy(enemy)
    if ( enemy:IsPlayer() ) then return true end

    return enemy.LVS == true and IsValid(enemy:GetDriver())
end

--- Returns the enemy the gunship is facing now: the autopilot's target, or what is under a pilot's crosshair.
---@return Entity|nil enemy
function ENT:GetVoiceEnemy()
    if ( self:GetAI() ) then return self:GetCannonEnemy() end
    if ( !IsValid(self:GetDriver()) ) then return nil end

    local hit = self:GetEyeTrace().Entity
    if ( !IsValid(hit) or !self:IsEnemy(hit) ) then return nil end

    return hit
end

--- Cries out at a new enemy and answers a new missile at once.
function ENT:UpdateEnemySounds()
    local enemy = self:GetVoiceEnemy()
    if ( enemy == self.lastEnemy ) then return end

    self.lastEnemy = enemy

    if ( !enemy ) then return end

    if ( self:IsTargettingMissile() ) then
        self:OnSeeMissile()

        return
    end

    local now = CurTime()
    if ( !IsPlayerEnemy(enemy) or now < self.nextSeeEnemySound ) then return end

    self.nextSeeEnemySound = now + SEE_ENEMY_INTERVAL
    self:EmitSound("NPC_CombineGunship.SeeEnemy")
end
