--- Tones down how NPCs react to LVS vehicles. Whenever a vehicle's autopilot switches on, it gets a pilot or a new NPC spawns, LVS tells every hostile NPC on the map where the vehicle is and makes it their first choice over any other enemy, so NPCs drop the fight in front of them and run towards vehicles far away. This keeps them hostile, but treats the vehicle like any other enemy and only lets them know about it when it is close and in sight.

--- Farthest an NPC may be from a vehicle to be told where it is when the two become enemies; any farther and the NPC has to spot it by itself first.
local NPC_AWARENESS_RANGE = 3000

--- Priority of the hatred NPCs feel for a vehicle, the same as for any other enemy, so that they keep fighting what is closest instead of always going for the vehicle.
local NPC_HATE_PRIORITY = 0

--- Seconds to wait after LVS has updated a relationship, which it does itself after a tenth of a second.
local RELATIONSHIP_DELAY = 0.2

--- Keeps an NPC hostile to a vehicle at an ordinary priority, and makes it forget the vehicle again unless it is close and in sight.
---@param npc NPC NPC to adjust.
---@param vehicle Entity LVS vehicle it was set against.
local function RelaxNPCRelationship(npc, vehicle)
    if ( !IsValid(npc) or !IsValid(vehicle) ) then return end
    if ( npc:Disposition(vehicle) != D_HT ) then return end

    npc:AddEntityRelationship(vehicle, D_HT, NPC_HATE_PRIORITY)

    if ( npc:GetPos():DistToSqr(vehicle:GetPos()) <= NPC_AWARENESS_RANGE * NPC_AWARENESS_RANGE and npc:Visible(vehicle) ) then return end

    npc:ClearEnemyMemory(vehicle)
end

--- Applies the relaxed relationship after LVS has set up its own, for a vehicle against every NPC or for a new NPC against every vehicle.
---@param ent Entity Vehicle or NPC whose relationships LVS has just updated.
local function OnRelationshipUpdated(ent)
    if ( !IsValid(ent) or !LVS ) then return end

    if ( ent:IsNPC() ) then
        for _, vehicle in pairs(LVS:GetVehicles()) do
            RelaxNPCRelationship(ent, vehicle)
        end

        return
    end

    for _, npc in pairs(LVS:GetNPCs()) do
        RelaxNPCRelationship(npc, ent)
    end
end

hook.Add("LVS.UpdateRelationship", "LVS.HL2.NPCRelationship", function(ent)
    timer.Simple(RELATIONSHIP_DELAY, function()
        OnRelationshipUpdated(ent)
    end)
end)
