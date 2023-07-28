----------------------
-- HELPER FUNCTIONS --
----------------------

local vter = mods.vertexutil.vter
local is_first_shot = mods.vertexutil.is_first_shot
local userdata_table = mods.vertexutil.userdata_table

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
               not ship:HasSystem(0) and
               not ship:HasSystem(10) and
               should_track_achievement("ACH_SHIP_KODIAK_3", ship, "PLAYER_SHIP_KODIAK")
    end
    script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
        if check_no_cloak_shields_ach(ship) then
            Hyperspace.CustomAchievementTracker.instance:SetAchievement("ACH_SHIP_KODIAK_3", false)
        end
    end)
end

-------------
-- BANSHEE --
-------------

-- Easy
local cloakShotCount = 0
local function is_ship_cloaked(ship)
    return ship.cloakSystem and ship.cloakSystem.bTurnedOn
end
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
    if ship.iShipId == 0 and not is_ship_cloaked(ship) then
        cloakShotCount = 0
    end
end)
script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
    local playerShip = Hyperspace.ships.player
    local checkCloakShot = weapon.iShipId == 0 and
                           is_ship_cloaked(playerShip) and
                           playerShip:HasAugmentation("CLOAK_FIRE") <= 0 and
                           playerShip:GetAugmentationValue("CLOAK_FIRE") <= 0 and
                           (weapon.blueprint.typeName == "BEAM" or is_first_shot(weapon, true)) and
                           should_track_achievement("ACH_SHIP_BANSHEE_1", playerShip, "PLAYER_SHIP_BANSHEE")
    if checkCloakShot then
        cloakShotCount = cloakShotCount + 1
        if cloakShotCount >= 10 then
            Hyperspace.CustomAchievementTracker.instance:SetAchievement("ACH_SHIP_BANSHEE_1", false)
        end
    end
end)

-- Normal
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if should_track_achievement("ACH_SHIP_BANSHEE_2", Hyperspace.ships.player, "PLAYER_SHIP_BANSHEE") then
        local playerVars = Hyperspace.playerVariables
        local metaVars = Hyperspace.metaVariables
        local generalRep = playerVars.rep_general
        if generalRep > playerVars.loc_rep_general_last then
            playerVars.loc_banshee_evil_score = playerVars.loc_banshee_evil_score + generalRep - playerVars.loc_rep_general_last
        end
        if metaVars.prof_finalsector > playerVars.loc_finalsector_last then
            if playerVars.loc_banshee_evil_score >= 4 and generalRep <= 0 then
                Hyperspace.CustomAchievementTracker.instance:SetAchievement("ACH_SHIP_BANSHEE_2", false)
            end
        end
        playerVars.loc_finalsector_last = metaVars.prof_finalsector
        playerVars.loc_rep_general_last = generalRep
    end
end)

-- Hard
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
    local shipAchData = userdata_table(ship, "mods.cnc.achTracking")
    if ship.iShipId == 1 and not shipAchData.systemFiresCounted and should_track_achievement("ACH_SHIP_BANSHEE_3", Hyperspace.ships.player, "PLAYER_SHIP_BANSHEE") then
        for system in vter(ship.vSystemList) do
            if ship:HasSystem(system:GetId()) and not system.bOnFire then return end
        end
        shipAchData.systemFiresCounted = true
        Hyperspace.playerVariables.loc_banshee_fire_score = Hyperspace.playerVariables.loc_banshee_fire_score + 1
        print(Hyperspace.playerVariables.loc_banshee_fire_score)
        if Hyperspace.playerVariables.loc_banshee_fire_score >= 4 then
            Hyperspace.CustomAchievementTracker.instance:SetAchievement("ACH_SHIP_BANSHEE_3", false)
        end
    end
end)

-------------------------------------
-- LAYOUT UNLOCKS FOR ACHIEVEMENTS --
-------------------------------------

local achLayoutUnlocks = {
    {
        achPrefix = "ACH_SHIP_KODIAK",
        unlockShip = "PLAYER_SHIP_KODIAK_3"
    },
    {
        achPrefix = "ACH_SHIP_BANSHEE",
        unlockShip = "PLAYER_SHIP_BANSHEE_3"
    }
}

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    local unlockTracker = Hyperspace.CustomShipUnlocks.instance
    for _, unlockData in ipairs(achLayoutUnlocks) do
        if not unlockTracker:GetCustomShipUnlocked(unlockData.unlockShip) and count_ship_achievements(unlockData.achPrefix) >= 2 then
            unlockTracker:UnlockShip(unlockData.unlockShip, false)
        end
    end
end)
