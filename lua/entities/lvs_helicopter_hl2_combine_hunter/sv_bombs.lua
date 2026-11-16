--- Bombs of the hunter-chopper, ported from CreateBomb, DropBombs and BullrushBombs of the Half-Life 2 attack helicopter (npc_attackchopper.cpp). The bombs themselves are the engine's own grenade_helicopter entities.

--- Class of the engine entity the original helicopter drops.
local BOMB_CLASS = "grenade_helicopter"

--- Spawnflag that turns a bomb into the bouncing, silent kind used for carpet bombing.
local SF_GRENADE_HELICOPTER_MEGABOMB = 1

--- Bombs in one stick before the longer pause, the original CHOPPER_BOMB_DROP_COUNT.
local BOMB_DROP_COUNT = 6

--- Shortest seconds between two bombs of a stick.
local BOMB_INTERVAL_MIN = 0.8

--- Longest seconds between two bombs of a stick.
local BOMB_INTERVAL_MAX = 1.1

--- Shortest extra seconds of pause after a full stick.
local BOMB_STICK_PAUSE_MIN = 1.5

--- Longest extra seconds of pause after a full stick.
local BOMB_STICK_PAUSE_MAX = 3

--- Slowest sideways speed a single bomb is nudged with so that a stick does not land in one line.
local BOMB_ACROSS_SPEED_MIN = 10

--- Fastest sideways speed a single bomb is nudged with.
local BOMB_ACROSS_SPEED_MAX = 30

--- Seconds between two volleys of a carpet bombing run.
local CARPET_BOMB_INTERVAL = 0.2

--- Slowest sideways speed of the paired bombs in a carpet bombing run.
local CARPET_ACROSS_SPEED_MIN = 300

--- Fastest sideways speed of the paired bombs in a carpet bombing run.
local CARPET_ACROSS_SPEED_MAX = 500

--- Prepares the bomb state and the attachment the bombs leave from.
function ENT:InitBombs()
    self.bombAttachment = self:LookupAttachment("Bomb")
    self.bombsLeftInStick = BOMB_DROP_COUNT
    self.bombsDropped = 0
    self.bombNextAttack = 0
    self.bombPause = 0
    self.bCarpetBombPair = false
    self.carpetBombNextTime = 0
end

--- Returns the helicopter's velocity for a bomb that is let go, without any upward part, and the sideways direction to it.
---@return Vector velocity
---@return Vector across Normalised horizontal direction at a right angle to the velocity.
function ENT:GetBombReleaseVelocity()
    local velocity = self:GetVelocity()
    local across = velocity:Cross(vector_up)
    across:Normalize()

    if ( velocity.z > 0 ) then
        velocity.z = 0
    end

    return velocity, across
end

--- Drops one bomb from the bomb bay.
---@param velocity Vector Velocity the bomb starts with.
---@param bMegaBomb boolean Whether to drop the carpet bombing kind.
---@return Entity|nil bomb
function ENT:CreateBomb(velocity, bMegaBomb)
    local attachment = self:GetAttachment(self.bombAttachment)
    if ( !attachment ) then return nil end

    local bomb = ents.Create(BOMB_CLASS)
    if ( !IsValid(bomb) ) then return nil end

    self:AddGestureSequence(self:LookupSequence("deploy"))
    self:EmitSound("NPC_AttackHelicopter.DropMine")

    bomb:SetPos(attachment.Pos)
    bomb:SetOwner(self)

    if ( bMegaBomb ) then
        bomb:SetKeyValue("spawnflags", tostring(SF_GRENADE_HELICOPTER_MEGABOMB))
    end

    bomb:Spawn()

    local phys = bomb:GetPhysicsObject()

    if ( bomb:GetMoveType() == MOVETYPE_VPHYSICS and IsValid(phys) ) then
        phys:SetVelocity(velocity)
    else
        bomb:SetLocalVelocity(velocity)
    end

    if ( self.BombSubMaterials ) then
        for index, material in pairs(self.BombSubMaterials) do
            bomb:SetSubMaterial(index, material)
        end
    end

    bomb.lvsHunterChopper = self
    bomb.lvsHunterAttacker = self:GetDriver()

    return bomb
end

--- Drops the next bomb of a stick once its interval is over, pausing longer after every full stick.
function ENT:DropBombs()
    local now = CurTime()
    if ( self.bombNextAttack > now ) then return end

    local velocity, across = self:GetBombReleaseVelocity()
    local side = math.Rand(0, 1) < 0.5 and 1 or -1

    velocity:Add(across * math.Rand(BOMB_ACROSS_SPEED_MIN, BOMB_ACROSS_SPEED_MAX) * side)
    self:CreateBomb(velocity, false)

    self.bombPause = math.Rand(BOMB_INTERVAL_MIN, BOMB_INTERVAL_MAX)
    self.bombsLeftInStick = self.bombsLeftInStick - 1
    self.bombsDropped = self.bombsDropped + 1

    if ( self.bombsLeftInStick <= 0 ) then
        self.bombsLeftInStick = BOMB_DROP_COUNT
        self.bombPause = self.bombPause + math.Rand(BOMB_STICK_PAUSE_MIN, BOMB_STICK_PAUSE_MAX)
    end

    self.bombNextAttack = now + self.bombPause
end

--- Shows how much of the current stick is used up, or the rest of the pause after a full stick, as the bomb weapon's heat.
function ENT:UpdateBombHeat()
    if ( !self.bombsLeftInStick ) then return end

    local used = (BOMB_DROP_COUNT - self.bombsLeftInStick) / BOMB_DROP_COUNT
    local remaining = self.bombNextAttack - CurTime()

    if ( self.bombsLeftInStick < BOMB_DROP_COUNT or remaining <= 0 or self.bombPause <= 0 ) then
        self:SetWeaponHeat(self.WEAPON_BOMBS, used)

        return
    end

    self:SetWeaponHeat(self.WEAPON_BOMBS, remaining / self.bombPause)
end

--- Sounds the alert that announces a carpet bombing run and resets its volley pattern.
function ENT:StartCarpetBombing()
    self:EmitSound("NPC_AttackHelicopter.MegabombAlert")
    self.bCarpetBombPair = false
    self.carpetBombNextTime = CurTime()
end

--- Drops the next volley of a carpet bombing run, alternating between a pair thrown out to both sides and a single bomb straight down the middle.
function ENT:DropCarpetBombs()
    local now = CurTime()
    if ( now < self.carpetBombNextTime ) then return end

    local velocity, across = self:GetBombReleaseVelocity()

    if ( self.bCarpetBombPair ) then
        across:Mul(math.Rand(CARPET_ACROSS_SPEED_MIN, CARPET_ACROSS_SPEED_MAX))

        self:CreateBomb(velocity + across, true)
        self:CreateBomb(velocity - across, true)
    else
        local side = math.Rand(0, 1) < 0.5 and 1 or -1

        self:CreateBomb(velocity + across * math.Rand(BOMB_ACROSS_SPEED_MIN, BOMB_ACROSS_SPEED_MAX) * side, true)
    end

    self.bCarpetBombPair = !self.bCarpetBombPair
    self.carpetBombNextTime = now + CARPET_BOMB_INTERVAL
end

--- Keeps a helicopter's bomb from hurting that helicopter or anything mounted on it, and credits its damage to the pilot who dropped it instead of to the helicopter. A bomb caught with the gravity gun no longer belongs to the helicopter and is left alone.
---@param target Entity Entity taking the damage.
---@param dmginfo CTakeDamageInfo Damage being dealt.
---@return boolean|nil bBlock True to block the damage.
local function HandleBombDamage(target, dmginfo)
    local bomb = dmginfo:GetInflictor()
    if ( !IsValid(bomb) or !bomb.lvsHunterChopper ) then return end

    local chopper = bomb.lvsHunterChopper
    if ( bomb:GetOwner() != chopper ) then return end
    if ( target == chopper or target:GetParent() == chopper ) then return true end

    local pilot = bomb.lvsHunterAttacker
    if ( !IsValid(pilot) ) then return end

    dmginfo:SetAttacker(pilot)
end

hook.Add("EntityTakeDamage", "LVS.HL2.HunterChopper.BombDamage", function(target, dmginfo)
    return HandleBombDamage(target, dmginfo)
end)
