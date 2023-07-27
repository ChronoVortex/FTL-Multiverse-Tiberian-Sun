----------------------
-- HELPER FUNCTIONS --
----------------------

local vter = mods.vertexutil.vter

local function string_starts(str, start)
    return string.sub(str, 1, string.len(start)) == start
end

local function should_track_achievement(achievement, ship, shipClassName)
    return Hyperspace.CustomAchievementTracker.instance:GetAchievementStatus(achievement) < Hyperspace.Settings.difficulty and
           ship and string_starts(ship.myBlueprint.blueprintName, shipClassName)
end

local function count_ship_achievements(achPrefix)
    local count = 0
    for i = 1, 3 do
        if Hyperspace.CustomAchievementTracker.instance:GetAchievementStatus(achPrefix.."_"..tostring(i)) > -1 then
            count = count + 1
        end
    end
    return count
end

------------
-- KODIAK --
------------

-- Easy
local onlyUsedIonCannon = true
script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(ship, projectile, damage, response)
    if ship.iShipId == 1 then
        onlyUsedIonCannon = false
    end
end)
script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(ship, projectile, location, damage, realNewTile, beamHitType)
    if ship.iShipId == 1 and not (projectile and projectile.extend and projectile.extend.name == "ION_CANNON") then
        onlyUsedIonCannon = false
    end
end)
script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
    if weapon.iShipId == 0 and not (weapon and weapon.blueprint and weapon.blueprint.name == "ION_CANNON") then
        onlyUsedIonCannon = false
    end
end)
do
    local function check_ion_cannon_ach(playerShip, enemyShip)
        return enemyShip and
               enemyShip.bDestroyed and
               Hyperspace.Global.GetInstance():GetCApp().world.space.bStorm and
               onlyUsedIonCannon and
               should_track_achievement("ACH_SHIP_KODIAK_1", playerShip, "PLAYER_SHIP_KODIAK")
    end
    script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
        if ship.iShipId == 0 then
            if ship.bJumping then
                onlyUsedIonCannon = true
            elseif check_ion_cannon_ach(ship, Hyperspace.ships.enemy) then
                Hyperspace.CustomAchievementTracker.instance:SetAchievement("ACH_SHIP_KODIAK_1", false)
            end
        end
    end)
end

-- Normal
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
    if ship.iShipId == 1 and should_track_achievement("ACH_SHIP_KODIAK_2", Hyperspace.ships.player, "PLAYER_SHIP_KODIAK") then
        local boarderCount = 0
        for crew in vter(ship.vCrewList) do
            if crew.iShipId == 0 then boarderCount = boarderCount + 1 end
            if boarderCount >= 10 then
                Hyperspace.CustomAchievementTracker.instance:SetAchievement("ACH_SHIP_KODIAK_2", false)
                break
            end
        end
    end
end)

-- Hard
do
    local function check_no_cloak_shields_ach(ship)
        return ship.iShipId == 0 and
               Hyperspace.playerVariables.loc_sector_count > 3 and
               not ship.cloakSystem and
               (not ship.shieldSystem or ship.shieldSystem.shields.power.second <= 0) and
               should_track_achievement("ACH_SHIP_KODIAK_3", ship, "PLAYER_SHIP_KODIAK")
    end
    script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
        if check_no_cloak_shields_ach(ship) then
            Hyperspace.CustomAchievementTracker.instance:SetAchievement("ACH_SHIP_KODIAK_3", false)
        end
    end)
end

-- C layout unlock
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    local unlockTracker = Hyperspace.CustomShipUnlocks.instance
    if not unlockTracker:GetCustomShipUnlocked("PLAYER_SHIP_KODIAK_3") and count_ship_achievements("ACH_SHIP_KODIAK") >= 2 then
        unlockTracker:UnlockShip("PLAYER_SHIP_KODIAK_3", false)
    end
end)
