--- Shared setup for the Half-Life 2 LVS vehicles: server settings for the Combine vehicles and a check that the LVS base is installed.

CreateConVar("lvs_car_hl2_combineapc_damage", 3, nil, "Controls the damage of the main gun from the Combine APC.")
CreateConVar("lvs_car_hl2_combineapc_rocketdamage", 50, nil, "Controls the damage of the Missle from the Combine APC.")
CreateConVar("lvs_car_hl2_combineapc_rocketradius", 100, nil, "Controls the splash radius of the Missle from the Combine APC.")
CreateConVar("lvs_car_hl2_combineapc_rocketspeed", 800, nil, "Controls the speed of the Missle from the Combine APC.")
CreateConVar("lvs_car_hl2_combineapc_health", 750, nil, "Controls the health of the Combine APC.")
CreateConVar("lvs_car_hl2_combineapc_spread", 0.06976, nil, "Controls the spread of the main gun from the Combine APC.")

CreateConVar("lvs_car_hl2_combinetransport_health", 1800, nil, "Controls the health of the Combine Transport.")

--- Reports once the map has loaded whether the LVS base is installed, since none of the vehicles work without it.
local function CheckLVSInstalled()
    if ( !LVS ) then
        print("[LVS] - Unable to load Half Life 2 Vehicles, LVS not found.")

        return
    end

    print("[LVS] - Half Life 2 Vehicles loaded.")
end

hook.Add("InitPostEntity", "LVS.HL2", CheckLVSInstalled)
