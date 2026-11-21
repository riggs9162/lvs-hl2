--- Machine gun, rockets, death volley and weapon choice of the armed Combine APC, ported from CPropAPC and npc_apcdriver in the Half-Life 2 code (vehicle_apc.cpp, npc_apcdriver.cpp).

DEFINE_BASECLASS("lvs_wheeldrive_hl2_combine_apc")

--- Class of the rockets the APC fires.
local MISSILE_CLASS = "lvs_hl2_apc_missile"

--- Rounds in one burst of the machine gun, and seconds between two of them.
local MACHINE_GUN_BURST_SIZE = 10
local MACHINE_GUN_BURST_TIME = 0.075

--- Seconds the machine gun pauses after each burst.
local MACHINE_GUN_BURST_PAUSE_TIME = 2

--- Speed the machine gun tracers fly at.
local MACHINE_GUN_TRACER_SPEED = 5000

--- Distance the machine gun rounds travel.
local MACHINE_GUN_RANGE = 56756

--- Rockets in one salvo, seconds between two of them, and the shortest and longest pause after a salvo.
local ROCKET_SALVO_SIZE = 5
local ROCKET_DELAY_TIME = 1.5
local ROCKET_MIN_BURST_PAUSE_TIME = 3
local ROCKET_MAX_BURST_PAUSE_TIME = 4

--- Speed the rockets leave the launcher with.
local ROCKET_SPEED = 800

--- How far each rocket of a salvo leans to the left of straight up, as the sine of its lean; negative leans to the right.
local ROCKET_SIDES = {0.966, 0.866, 0.5, -0.5, -0.866, -0.966}

--- Rockets fired in every direction when the APC is destroyed.
local DEATH_VOLLEY_ROCKET_COUNT = 4

--- Shortest and longest seconds between two rockets of the death volley.
local DEATH_VOLLEY_MIN_FIRE_TIME = 0.166
local DEATH_VOLLEY_MAX_FIRE_TIME = 0.333

--- Chance that a rocket of the death volley blows up in the air instead of spinning out of control.
local DEATH_VOLLEY_EXPLODE_CHANCE = 0.3

--- Farthest an enemy may be for the autopilot to use the machine gun, and the range band it uses the rockets in.
local MACHINE_GUN_ATTACK_RANGE_MAX = 1250
local ROCKET_ATTACK_RANGE_MIN = 1250
local ROCKET_ATTACK_RANGE_MAX = 5500

--- Cosine of the angle the machine gun must be within of the enemy for the autopilot to fire it.
local MACHINE_GUN_FIRING_CONE = math.cos(math.rad(4))

--- Returns the value of an addon setting, or a fallback when it does not exist.
---@param name string
---@param fallback number
---@return number value
local function GetSetting(name, fallback)
    local convar = GetConVar(name)

    return convar and convar:GetFloat() or fallback
end

--- Writes a heat value for one weapon slot, which the LVS HUD shows as that weapon's ring.
---@param id number Weapon slot.
---@param heat number Heat between 0 and 1.
function ENT:SetWeaponHeat(id, heat)
    local weapon = self.WEAPONS[1][id]
    if ( !weapon ) then return end

    heat = math.Clamp(heat, 0, 1)
    weapon._CurHeat = heat

    if ( self:GetSelectedWeapon() == id and self:GetNWHeat() != heat ) then
        self:SetNWHeat(heat)
    end
end

--- Returns the pilot, or the APC itself when nobody is driving, to credit damage to.
---@return Entity attacker
function ENT:GetWeaponAttacker()
    local driver = self:GetDriver()

    return IsValid(driver) and driver or self
end

--- Fires the next round of the machine gun, pausing after every burst of ten, from CPropAPC::FireMachineGun. Each round is timed from when the last one was due rather than from when it went off, so the burst keeps its pace even though the vehicle only thinks once per tick.
function ENT:FireMachineGun()
    local now = CurTime()
    local nextTime = self.machineGunTime or 0
    if ( now < nextTime ) then return end

    local fireTime = now - nextTime < MACHINE_GUN_BURST_TIME and nextTime or now

    self.machineGunBurstLeft = (self.machineGunBurstLeft or MACHINE_GUN_BURST_SIZE) - 1

    if ( self.machineGunBurstLeft > 0 ) then
        self.machineGunTime = fireTime + MACHINE_GUN_BURST_TIME
    else
        self.machineGunBurstLeft = MACHINE_GUN_BURST_SIZE
        self.machineGunTime = fireTime + MACHINE_GUN_BURST_PAUSE_TIME
    end

    local attachment = self:LookupAttachment("muzzle")
    local muzzle = self:GetAttachment(attachment)
    if ( !muzzle ) then return end

    local spread = GetSetting("lvs_car_hl2_combineapc_spread", 0.06976)

    self:FireBullets({
        Attacker = self:GetWeaponAttacker(),
        Num = 1,
        Src = muzzle.Pos,
        Dir = muzzle.Ang:Forward(),
        Spread = Vector(spread, spread, 0),
        Tracer = 0,
        TracerName = "none",
        AmmoType = "AR2",
        Damage = GetSetting("lvs_car_hl2_combineapc_damage", 3),
        Distance = MACHINE_GUN_RANGE,
        IgnoreEntity = self,
        Callback = function(attacker, trace, dmginfo)
            self:DrawMachineGunTracer(muzzle.Pos, trace.HitPos)
            self:OnMachineGunHit(trace, dmginfo)
        end,
    })

    local effectData = EffectData()
    effectData:SetEntity(self)
    effectData:SetAttachment(attachment)
    effectData:SetScale(1)
    util.Effect("ChopperMuzzleFlash", effectData)

    self:EmitSound("Weapon_AR2.Single")
end

--- Draws the original tracer of a machine gun round from the muzzle to where it hit. The engine's own tracer would start at the model's first attachment, which on this model sits at the front of the hull, and the tracer rate of zero is turned back into one by the time the bullets are fired, so the bullets are given a tracer effect that does not exist instead.
---@param startPos Vector Position of the muzzle.
---@param endPos Vector Where the round hit.
function ENT:DrawMachineGunTracer(startPos, endPos)
    local effectData = EffectData()
    effectData:SetStart(startPos)
    effectData:SetOrigin(endPos)
    effectData:SetScale(MACHINE_GUN_TRACER_SPEED)
    util.Effect("HelicopterTracer", effectData)
end

--- Lets a machine gun round damage vehicles the way LVS guns do and shows the original impact effect.
---@param trace table Trace result of the round.
---@param dmginfo CTakeDamageInfo Damage the round is about to deal.
function ENT:OnMachineGunHit(trace, dmginfo)
    local hit = trace.Entity

    dmginfo:SetDamageType(DMG_AIRBOAT)

    if ( IsValid(hit) and hit:GetParent() == self ) then
        dmginfo:SetDamage(0)
    end

    local effectData = EffectData()
    effectData:SetOrigin(trace.HitPos)
    effectData:SetStart(trace.StartPos)
    effectData:SetSurfaceProp(trace.SurfaceProps)
    effectData:SetDamageType(DMG_BULLET)
    effectData:SetHitBox(trace.HitBox)
    effectData:SetEntity(hit)
    util.Effect("HelicopterImpact", effectData)
end

--- Shows how much of the burst is used up, or the rest of the pause after it, as the machine gun's heat.
function ENT:UpdateMachineGunHeat()
    local burstLeft = self.machineGunBurstLeft or MACHINE_GUN_BURST_SIZE
    local remaining = (self.machineGunTime or 0) - CurTime()

    if ( burstLeft == MACHINE_GUN_BURST_SIZE and remaining > MACHINE_GUN_BURST_TIME ) then
        self:SetWeaponHeat(self.WEAPON_MACHINE_GUN, remaining / MACHINE_GUN_BURST_PAUSE_TIME)

        return
    end

    self:SetWeaponHeat(self.WEAPON_MACHINE_GUN, (MACHINE_GUN_BURST_SIZE - burstLeft) / MACHINE_GUN_BURST_SIZE)
end

--- Returns where the rockets of this APC home in on: the enemy of the autopilot, or the spot under the pilot's crosshair, together with the position the laser is aimed from. Returns nothing once there is nothing to aim at, and the rockets fly on straight.
---@return Vector|nil dotPos
---@return Entity|nil target
---@return Vector|nil shootPos
function ENT:GetRocketDot()
    if ( !IsValid(self) or self:IsDestroyed() ) then return end

    if ( self:GetAI() ) then
        local target = self:AIGetTarget()
        if ( !IsValid(target) ) then return end

        return target:WorldSpaceCenter(), target, self:WorldSpaceCenter()
    end

    if ( !IsValid(self:GetDriver()) ) then return end

    return self:GetEyeTrace().HitPos, nil, self:WorldSpaceCenter()
end

--- Launches one rocket from the launcher on the roof.
---@param velocity Vector Velocity it leaves with.
---@return Entity|nil missile
function ENT:LaunchMissile(velocity)
    local muzzle = self:GetAttachment(self:LookupAttachment("cannon_muzzle"))
    if ( !muzzle ) then return nil end

    local missile = ents.Create(MISSILE_CLASS)
    if ( !IsValid(missile) ) then return nil end

    missile:SetPos(muzzle.Pos)
    missile:SetAngles(velocity:Angle())
    missile:SetOwner(self)
    missile:Spawn()
    missile:Activate()
    missile:SetMissileVelocity(velocity)
    missile:SetExplosion(self:GetWeaponAttacker(), GetSetting("lvs_car_hl2_combineapc_rocketdamage", 50), GetSetting("lvs_car_hl2_combineapc_rocketradius", 100))

    return missile
end

--- Fires the next rocket of a salvo, leaning each one a little further from one side to the other, and pauses after every five, from CPropAPC::FireRocket.
function ENT:FireRocket()
    local now = CurTime()
    if ( now < (self.rocketTime or 0) ) then return end

    self.rocketSalvoLeft = (self.rocketSalvoLeft or ROCKET_SALVO_SIZE) - 1

    if ( self.rocketSalvoLeft > 0 ) then
        self.rocketTime = now + ROCKET_DELAY_TIME
    else
        self.rocketSalvoLeft = ROCKET_SALVO_SIZE
        self.rocketTime = now + math.Rand(ROCKET_MIN_BURST_PAUSE_TIME, ROCKET_MAX_BURST_PAUSE_TIME)
    end

    self.rocketSide = ((self.rocketSide or 0) % #ROCKET_SIDES) + 1

    local side = ROCKET_SIDES[self.rocketSide]
    local direction = vector_up:Cross(self:GetForward())

    direction.x = direction.x * side
    direction.y = direction.y * side
    direction.z = 1
    direction:Normalize()

    local missile = self:LaunchMissile(direction * GetSetting("lvs_car_hl2_combineapc_rocketspeed", ROCKET_SPEED))
    if ( !missile ) then return end

    missile:SetLaserSource(function()
        return self:GetRocketDot()
    end)

    missile:IgniteDelay()

    self:EmitSound("PropAPC.FireRocket")
end

--- Shows how much of the salvo is used up, or the rest of the pause after it, as the rockets' heat.
function ENT:UpdateRocketHeat()
    local salvoLeft = self.rocketSalvoLeft or ROCKET_SALVO_SIZE
    local remaining = (self.rocketTime or 0) - CurTime()

    if ( salvoLeft == ROCKET_SALVO_SIZE and remaining > ROCKET_DELAY_TIME ) then
        self:SetWeaponHeat(self.WEAPON_ROCKETS, remaining / ROCKET_MAX_BURST_PAUSE_TIME)

        return
    end

    self:SetWeaponHeat(self.WEAPON_ROCKETS, (ROCKET_SALVO_SIZE - salvoLeft) / ROCKET_SALVO_SIZE)
end

--- Fires one rocket of the death volley in a random upward direction, which either blows up in the air or spins out of control, from CPropAPC::FireDying.
function ENT:FireDyingRocket()
    local direction = VectorRand(-1, 1)
    direction.z = math.abs(direction.z)
    direction:Normalize()

    local missile = self:LaunchMissile(direction * ROCKET_SPEED * math.Rand(0.75, 1.25))
    if ( !missile ) then return end

    local delay = math.Rand(0.3, 0.5)

    if ( math.Rand(0, 1) < DEATH_VOLLEY_EXPLODE_CHANCE ) then
        missile:ExplodeDelay(delay)
    else
        missile:AugerDelay(delay)
    end
end

--- Fires the death volley at erratic intervals and returns how long it takes, which is how long the APC holds together.
---@return number duration
function ENT:StartDeathVolley()
    local time = 0

    for _ = 1, DEATH_VOLLEY_ROCKET_COUNT do
        timer.Simple(time, function()
            if ( IsValid(self) ) then
                self:FireDyingRocket()
            end
        end)

        time = time + math.Rand(DEATH_VOLLEY_MIN_FIRE_TIME, DEATH_VOLLEY_MAX_FIRE_TIME)
    end

    return time
end

--- Returns whether the machine gun points close enough at a position for the autopilot to fire, as the original only fires once its gun is on target.
---@param targetPos Vector
---@return boolean bInCone
function ENT:IsInMachineGunCone(targetPos)
    local muzzle = self:GetAttachment(self:LookupAttachment("muzzle"))
    if ( !muzzle ) then return false end

    return muzzle.Ang:Forward():Dot((targetPos - muzzle.Pos):GetNormalized()) >= MACHINE_GUN_FIRING_CONE
end

--- Drives like any LVS vehicle, but picks its weapon by range as the APC driver of Half-Life 2 does: the machine gun up close once it is on target, the rockets further out, and nothing beyond rocket range.
function ENT:RunAI()
    BaseClass.RunAI(self)

    local target = self:AIGetTarget()

    if ( !IsValid(target) ) then
        self._AIFireInput = false

        return
    end

    local targetPos = target:WorldSpaceCenter()
    local distance = self:WorldSpaceCenter():Distance(targetPos)
    local weapon
    local bFire = false

    if ( distance <= MACHINE_GUN_ATTACK_RANGE_MAX ) then
        weapon = self.WEAPON_MACHINE_GUN
        bFire = self:IsInMachineGunCone(targetPos)
    elseif ( distance >= ROCKET_ATTACK_RANGE_MIN and distance <= ROCKET_ATTACK_RANGE_MAX ) then
        weapon = self.WEAPON_ROCKETS
        bFire = self:AICanSee(target)
    end

    if ( weapon and self:GetSelectedWeapon() != weapon ) then
        self:SelectWeapon(weapon)
    end

    self._AIFireInput = bFire
end
