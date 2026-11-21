AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")
include("sv_weapons.lua")

function ENT:PostOnSpawn(PObj)
    self:ManipulateBoneScale(self:LookupBone("APC.Gun_Base"), Vector(1, 1, 1))
end
