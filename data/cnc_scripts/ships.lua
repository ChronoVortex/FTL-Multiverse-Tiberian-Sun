if not mods or not mods.vertexutil then
    error("Couldn't find Vertex Tags and Utility Functions! Make sure it's above mods which depend on it in the Slipstream load order")
end

local vter = mods.vertexutil.vter
local ShowTutorialArrow = mods.vertexutil.ShowTutorialArrow
local HideTutorialArrow = mods.vertexutil.HideTutorialArrow

mods.cnconquer = {}

-- Handle full specrum targeting
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
    -- Make sure weapons exist
    local weapons = nil
    pcall(function() weapons = ship.weaponSystem.weapons end)
    if weapons then
        -- Check for cloak charge
        local cloakCharge = false
        if ship:HasAugmentation("TARGET_SCANNERS") > 0 then
            pcall(function()
                local otherShip = Hyperspace.Global.GetInstance():GetShipManager((ship.iShipId + 1)%2)
                cloakCharge = Hyperspace.ships.enemy.cloakSystem.bTurnedOn
            end)
        end
        
        -- Manually manage weapon cooldown for cloak charge
        if cloakCharge then
            for weapon in vter(weapons) do
                if weapon.powered and weapon.cooldown.first < weapon.cooldown.second then
                    local currentCharge = weapon.cooldown.first + Hyperspace.FPS.SpeedFactor/16
                    if currentCharge >= weapon.cooldown.second then
                        if weapon.chargeLevel < weapon.weaponVisual.iChargeLevels then
                            weapon.chargeLevel = weapon.chargeLevel + 1
                            if weapon.chargeLevel == weapon.weaponVisual.iChargeLevels then
                                weapon.cooldown.first = weapon.cooldown.second
                            else
                                weapon.cooldown.first = 0
                            end
                        else
                            weapon:ForceCoolup()
                        end
                    else
                        weapon.cooldown.first = currentCharge
                    end
                end
            end
        end
    end
end)

-- Handle prism beams
mods.cnconquer.prismBeams = {}
local prismBeams = mods.cnconquer.prismBeams
prismBeams["BEAM_PRISM_1"] = {
    refractions = 3,
    blueprints = {
        Hyperspace.Global.GetInstance():GetBlueprints():GetWeaponBlueprint("BEAM_PRISM_REFRACT")
    }
}
script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
    local prismData = prismBeams[projectile.extend.name]
    if prismData and realNewTile then
        -- Make any room cell orthogonally adjecent to the targeted room a potential target
        local targetShipGraph = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId)
        local originRoomShape = targetShipGraph:GetRoomShape(targetShipGraph:GetSelectedRoom(location.x, location.y, false))
        local validTargets = {}
        local currentX = nil
        local currentY = nil
        for offset = 0, originRoomShape.w - 35, 35 do
            currentX = originRoomShape.x + offset + 17
            currentY = originRoomShape.y - 17
            if targetShipGraph:GetSelectedRoom(currentX, currentY, false) > -1 then
                table.insert(validTargets, Hyperspace.Pointf(currentX, currentY))
            end
            currentY = originRoomShape.y + originRoomShape.h + 17
            if targetShipGraph:GetSelectedRoom(currentX, currentY, false) > -1 then
                table.insert(validTargets, Hyperspace.Pointf(currentX, currentY))
            end
        end
        for offset = 0, originRoomShape.h - 35, 35 do
            currentY = originRoomShape.y + offset + 17
            currentX = originRoomShape.x - 17
            if targetShipGraph:GetSelectedRoom(currentX, currentY, false) > -1 then
                table.insert(validTargets, Hyperspace.Pointf(currentX, currentY))
            end
            currentX = originRoomShape.x + originRoomShape.w + 17
            if targetShipGraph:GetSelectedRoom(currentX, currentY, false) > -1 then
                table.insert(validTargets, Hyperspace.Pointf(currentX, currentY))
            end
        end
        
        -- Pick from the list of targets until there are no more or until all refraction projectiles are created
        local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
        local validTargetCount = #validTargets
        while #validTargets > 0 and #validTargets + prismData.refractions > validTargetCount do
            local targetIndex = Hyperspace.random32()%#validTargets + 1
            local refractIndex = 1
            if #(prismData.blueprints) > 1 then refractIndex = Hyperspace.random32()%#(prismData.blueprints) + 1 end
            spaceManager:CreateBeam(
                prismData.blueprints[refractIndex],
                location,
                shipManager.iShipId,
                (shipManager.iShipId + 1)%2,
                validTargets[targetIndex], Hyperspace.Pointf(validTargets[targetIndex].x, validTargets[targetIndex].y + 1),
                shipManager.iShipId,
                1, 0 --(math.atan(location.y - target.y, location.x - target.x)*180)/math.pi - 90
            )
            table.remove(validTargets, targetIndex)
        end
    end
    return Defines.Chain.CONTINUE, beamHitType
end)

-- Adepts stun themselves for 4 seconds when they use their power
script.on_internal_event(Defines.InternalEvents.ACTIVATE_POWER, function(power, shipManager)
    local crewmem = power.crew
    if crewmem:GetSpecies() == "human_adept" then
        crewmem.fStunTime = math.max(crewmem.fStunTime, 4)
    end
end)

-- Make the ion cannon target a specific system
script.on_game_event("LUA_SET_IONCANNON_TARGET", false, function()
    local targetsys = Hyperspace.ships.player:HasEquipment("loc_ioncannon_target_room")
    if Hyperspace.ships.enemy:HasSystem(targetsys) then
        local retarget = 
            Hyperspace.ships.enemy:GetRoomCenter(Hyperspace.ships.enemy:GetSystemRoom(targetsys))
        for proj in vter(Hyperspace.ships.player.superBarrage) do
            proj.target = retarget
            proj:ComputeHeading()
        end
    end
end)

-- Point out the iron curtain button when the game starts
script.on_game_event("INITIAL_START_BEACON_IRON_CURTAIN", false, function() ShowTutorialArrow(2, 132, 79) end)
script.on_game_event("LIGHTSPEED_DROPPOINT", false, HideTutorialArrow)

-- Regenerate a super shield bubble for iron curtain
script.on_game_event("LUA_IRON_CURTAIN", false, function()
    local shields = nil
    if pcall(function()
        shields = Hyperspace.ships.player.shieldSystem
    end) and shields then
        shields:AddSuperShield(shields.center)
    end
end)

-- Iron curtain hotkey
script.on_init(function()
    if Hyperspace.metaVariables.prof_hotkey_iron_curtain == 0 then Hyperspace.metaVariables.prof_hotkey_iron_curtain = 96 end
end)
local settingIronCurtainKey = false
script.on_game_event("COMBAT_CHECK_HOTKEYS_IRON_CURTAIN_START", false, function() settingIronCurtainKey = true end)
script.on_game_event("COMBAT_CHECK_HOTKEYS_IRON_CURTAIN_END_1", false, function() settingIronCurtainKey = false end)
script.on_game_event("COMBAT_CHECK_HOTKEYS_IRON_CURTAIN_END_2", false, function() settingIronCurtainKey = false end)
script.on_internal_event(Defines.InternalEvents.ON_KEY_DOWN, function(key)
    -- Allow player to reconfigure the hotkeys
    if settingIronCurtainKey then Hyperspace.metaVariables.prof_hotkey_iron_curtain = key end

    -- Do stuff if a hotkey is pressed
    local cmdGui = Hyperspace.Global.GetInstance():GetCApp().gui
    local playerShip = Hyperspace.ships.player
    if playerShip and key == Hyperspace.metaVariables.prof_hotkey_iron_curtain and Hyperspace.playerVariables.loc_iron_curtain_charged > 0 and not (playerShip.bJumping or cmdGui.event_pause or cmdGui.menu_pause) then
        Hyperspace.CustomEventsParser.GetInstance():LoadEvent(Hyperspace.Global.GetInstance():GetCApp().world, "LUA_IRON_CURTAIN", false, -1)
    end
end)

-- Iron curtain automation
script.on_game_event("IRON_CURTAIN_CHARGE_POST", false, function()
    if Hyperspace.metaVariables.prof_auto_iron_curtain > 0 then
        Hyperspace.CustomEventsParser.GetInstance():LoadEvent(Hyperspace.Global.GetInstance():GetCApp().world, "LUA_IRON_CURTAIN", false, -1)
    end
end)
