--- Large wreck piece of a destroyed hunter-chopper, ported from CHelicopterChunk of the Half-Life 2 attack helicopter (npc_attackchopper.cpp).

AddCSLuaFile()

ENT.Type = "anim"
ENT.Spawnable = false
ENT.AdminSpawnable = false
ENT.DoNotDuplicate = true

--- Seconds the piece stays in the world.
ENT.Lifetime = 30

if ( CLIENT ) then return end

--- Seconds between two thinks of a falling piece.
local FALL_THINK_INTERVAL = 0.1

--- Chance per think, as one in this many, that a falling piece sets off an explosion.
local FALL_EXPLOSION_CHANCE = 9

--- Farthest from the piece on each axis that its explosions appear.
local FALL_EXPLOSION_SPREAD = 64

--- Seconds the dust cloud of the crash lingers.
local DUST_LIFETIME = 10

function ENT:Initialize()
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE)

    local phys = self:GetPhysicsObject()

    if ( IsValid(phys) ) then
        phys:EnableMotion(true)
        phys:Wake()
    end

    self.bLanded = false

    SafeRemoveEntityDelayed(self, self.Lifetime)
end

--- Sets the piece that decides when the whole wreck counts as landed.
---@param master Entity Body piece of the same wreck.
function ENT:SetMaster(master)
    self.master = master
end

--- Shakes the falling piece with random explosions until it has landed.
function ENT:Think()
    if ( self.bLanded ) then return end

    if ( math.random(1, FALL_EXPLOSION_CHANCE) == 1 ) then
        local effectData = EffectData()
        effectData:SetOrigin(self:GetPos() + VectorRand(-FALL_EXPLOSION_SPREAD, FALL_EXPLOSION_SPREAD))
        util.Effect("HelicopterMegaBomb", effectData)

        self:EmitSound("BaseExplosionEffect.Sound")
    end

    self:NextThink(CurTime() + FALL_THINK_INTERVAL)

    return true
end

--- Handles a piece of the wreck reaching the ground: the body lets go of the other pieces, raises a dust cloud and plays the crash, and every other piece passes the call on to the body.
function ENT:CollisionCallback()
    if ( self.bLanded ) then return end

    if ( IsValid(self.master) ) then
        self.master:CollisionCallback()

        return
    end

    constraint.RemoveConstraints(self, "Weld")

    local dust = ents.Create("env_ar2explosion")

    if ( IsValid(dust) ) then
        dust:SetPos(self:GetPos())
        dust:Spawn()
        dust:Activate()
        dust:Fire("Explode")

        SafeRemoveEntityDelayed(dust, DUST_LIFETIME)
    end

    self:EmitSound("NPC_AttackHelicopter.Crash")
    self.bLanded = true
end

function ENT:PhysicsCollide(data)
    if ( self.bLanded or !data.HitEntity:IsWorld() ) then return end

    self:CollisionCallback()
    self.bLanded = true
end
