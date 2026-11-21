AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")
include("lvs_hl2/sv_helicopter_flight.lua")
include("sv_gun.lua")
include("sv_bombs.lua")
include("sv_wash.lua")
include("sv_damage.lua")
include("lvs_hl2/sv_helicopter_ai.lua")
include("sv_ai.lua")

--- Position of the pilot's seat.
local SEAT_POS = Vector(120, 0, -40)

--- Position of the main rotor.
local ROTOR_POS = Vector(0, 0, 65)

--- Tilt of the main rotor.
local ROTOR_ANGLE = Angle(15, 0, 0)

--- Position of the tail rotor.
local TAIL_ROTOR_POS = Vector(-218, 4, -1.8)

--- Tilt of the tail rotor.
local TAIL_ROTOR_ANGLE = Angle(0, 0, 90)

--- Position the tail breaks off at.
local TAIL_BREAK_POS = Vector(-153.476349, 1.618453, 3.479492)

--- Bones hidden once the tail has broken off.
local TAIL_BONES = {
    "Chopper.Tail",
    "Chopper.Blade_Tail",
}

--- Speed a crash must take off the helicopter before the part that hit takes damage.
local COLLISION_DAMAGE_SPEED = 200

--- Damage a hard crash deals to the part that hit.
local COLLISION_DAMAGE = 200

--- Adds the main rotor, whose loss shuts the engine down.
function ENT:AddMainRotor()
    local rotor = self:AddRotor(ROTOR_POS, ROTOR_ANGLE, 310, -4000)
    rotor:SetRotorEffects(true)
    rotor:SetHP(50)

    function rotor:OnDestroyed(base)
        base:ManipulateBoneScale(base:LookupBone("Chopper.Rotor_Blur"), vector_origin)
        base:DestroyEngine()
        self:EmitSound("physics/metal/metal_box_break2.wav")
    end

    self.Rotor = rotor
end

--- Adds the tail rotor and the hit zone of the tail, whose loss sends the helicopter into a spin.
function ENT:AddTailRotor()
    local rotor = self:AddRotor(TAIL_ROTOR_POS, TAIL_ROTOR_ANGLE, 25, -6000)
    rotor:SetHP(100)

    function rotor:OnDestroyed(base)
        base:DestroySteering(-2.5)
        base:SnapTailRotor()
        self:EmitSound("physics/metal/metal_box_break2.wav")
    end

    self.TailRotor = rotor

    self:AddDS({
        pos = TAIL_ROTOR_POS,
        ang = angle_zero,
        mins = Vector(-45, -15, -40),
        maxs = Vector(75, 15, 60),
        Callback = function(part, ent, dmginfo)
            if ( dmginfo:GetDamage() <= 0 ) then return end

            ent.TailRotor:TakeDamageInfo(dmginfo)
        end,
    })
end

function ENT:OnSpawn(phys)
    local driverSeat = self:AddDriverSeat(SEAT_POS, Angle(0, -90, 0))
    driverSeat:SetCameraDistance(0.2)

    self:AddEngineSound(vector_origin)
    self:AddMainRotor()
    self:AddTailRotor()

    self:InitGun()
    self:InitBombs()
    self:InitRotorWash()
    self:InitDamageEffects()
    self:InitAI()

    if ( self.PostOnSpawn ) then
        self:PostOnSpawn(phys)
    end
end

--- Breaks the tail off as a burning piece of wreckage and hides it on the helicopter.
function ENT:SnapTailRotor()
    if ( self.bTailDestroyed ) then return end

    self.bTailDestroyed = true

    for _, name in ipairs(TAIL_BONES) do
        self:ManipulateBoneScale(self:LookupBone(name), vector_origin)
    end

    local tail = ents.Create("prop_physics")
    if ( !IsValid(tail) ) then return end

    tail:SetModel("models/gibs/helicopter_brokenpiece_05_tailfan.mdl")
    tail:SetPos(self:LocalToWorld(TAIL_BREAK_POS))
    tail:SetAngles(self:GetAngles())
    tail:Spawn()
    tail:Activate()
    tail:SetRenderMode(RENDERMODE_TRANSALPHA)
    tail:SetCollisionGroup(COLLISION_GROUP_WORLD)
    self:DeleteOnRemove(tail)

    local phys = tail:GetPhysicsObject()
    if ( !IsValid(phys) ) then return end

    phys:SetVelocityInstantaneous(self:GetVelocity())
    phys:AddAngleVelocity(VectorRand() * 500)
    phys:EnableDrag(false)

    local effectData = EffectData()
    effectData:SetOrigin(tail:GetPos())
    effectData:SetStart(phys:GetMassCenter())
    effectData:SetEntity(tail)
    effectData:SetScale(0.25)
    effectData:SetMagnitude(5)
    util.Effect("lvs_firetrail", effectData)
end

function ENT:GetMissileOffset()
    return Vector(-60, 0, 0)
end

function ENT:OnEngineActiveChanged(bActive)
    if ( !bActive ) then return end

    self:EmitSound("lvs/vehicles/helicopter/start.wav")
end

function ENT:OnTick()
    self:RotorWashThink()
    self:DamageEffectsThink()
end

function ENT:OnRemoved()
    self:StopLoopingSounds()
end

--- Passes a hard crash on to the part of the helicopter that hit, so that a tail strike can break the tail rotor.
---@param data table Collision data.
---@param phys PhysObj Physics object of the helicopter.
---@return boolean bHandled Always false, so the base still applies its own collision damage.
function ENT:OnCollision(data, phys)
    if ( self:IsPlayerHolding() ) then return false end
    if ( data.Speed <= 60 or data.DeltaTime <= 0.2 ) then return false end
    if ( data.OurOldVelocity:Length() - data.OurNewVelocity:Length() <= COLLISION_DAMAGE_SPEED ) then return false end

    local part = self:FindDS(data.HitPos - data.OurOldVelocity:GetNormalized() * 25)
    if ( !part ) then return false end

    local dmginfo = DamageInfo()
    dmginfo:SetDamage(COLLISION_DAMAGE)
    dmginfo:SetDamageType(DMG_CRUSH)
    part:Callback(self, dmginfo)

    return false
end
