--- Clientside setup for the Half-Life 2 LVS vehicles: spawn menu category icons and hiding passengers inside enclosed Combine vehicles.

list.Set("ContentCategoryIcons", "[LVS] - Half Life 2", "icon16/lvs_resistance.png")
list.Set("ContentCategoryIcons", "[LVS] - Half Life 2 - Civilian", "icon16/lvs_civilian.png")
list.Set("ContentCategoryIcons", "[LVS] - Half Life 2 - Combine", "icon16/lvs_combine.png")
list.Set("ContentCategoryIcons", "[LVS] - Half Life 2 - Resistance", "icon16/lvs_resistance.png")

--- Vehicles whose passengers sit inside a closed hull and should not show through it.
local ENCLOSED_VEHICLES = {
    ["lvs_wheeldrive_hl2_combine_transport"] = true
}

--- Hides passengers of enclosed Combine vehicles from players on foot and from anyone in a third-person seat, while the driver and players seated in first person still see them.
---@param client Player Player about to be drawn.
---@return boolean|nil bHide True to skip drawing the player.
local function ShouldHidePassenger(client)
    if ( !LVS ) then return end
    if ( !IsValid(client) or !client:Alive() ) then return end

    local vehicle = client:lvsGetVehicle()
    if ( !IsValid(vehicle) or !ENCLOSED_VEHICLES[vehicle:GetClass()] ) then return end
    if ( vehicle:GetDriver() == client ) then return end

    local localPlayer = LocalPlayer()
    local seat = localPlayer:GetVehicle()
    if ( IsValid(seat) and seat:GetThirdPersonMode() ) then return true end
    if ( localPlayer:lvsGetVehicle() == vehicle ) then return end
    if ( IsValid(seat) ) then return end

    return true
end

hook.Add("PrePlayerDraw", "LVS.HL2", ShouldHidePassenger)
