-- Only set up the namespace if it hasn't already been set up
if not mods.cnconquer then mods.cnconquer = {} end

-- Functions to execute on all player weapons
if not mods.cnconquer.allPlayerWeaponsFuncs then mods.cnconquer.allPlayerWeaponsFuncs = {} end

-- Force weapons to charge while enemy is cloaked
mods.cnconquer.allPlayerWeaponsFuncs["HANDLE_TARGET_SCANNERS"] = function(weapon)
    local cloakCharge = false
    if Hyperspace.ships.player:HasAugmentation("TARGET_SCANNERS") > 0 then
        pcall(function() cloakCharge = Hyperspace.ships.enemy.cloakSystem.bTurnedOn end)
    end
    if cloakCharge then
        local maxCharge = weapon.cooldown.second - Hyperspace.FPS.SpeedFactor/16
        weapon.cooldown.first = math.min(weapon.cooldown.first + Hyperspace.FPS.SpeedFactor/16, maxCharge)
        if math.abs(maxCharge - weapon.cooldown.first) < 0.001 and weapon.chargeLevel <weapon.weaponVisual.iChargeLevels - 1 then
            weapon.cooldown.first = 0
            weapon.chargeLevel = weapon.chargeLevel + 1
        end
    end
end

-- All ontick code for C&C
-- Manage combat chronosphere
if not mods.cnconquer.OnTick then
    function mods.cnconquer.OnTick()
        -- We only need to do any of this if the game isn't paused
        if not Hyperspace.Global.GetInstance():GetCApp().world.space.gamePaused then
            -- Check for weapons
            local weapons = nil
            pcall(function() weapons = Hyperspace.ships.player.weaponSystem.weapons end)
            
            -- Only manage weapons if there're weapons to manage
            if weapons then
                local combatChronosPowered = 0
                for weapon in mods.chronoutil.vter(weapons) do
                    -- Execute all genral weapon functions
                    for name, func in pairs(mods.cnconquer.allPlayerWeaponsFuncs) do
                        func(weapon)
                    end
                    
                    -- Get the number of combat chronospheres powered
                    if weapon.name:sub(1, 19) == "Combat Chronosphere" and weapon.powered then
                        combatChronosPowered = combatChronosPowered + 1
                    end
                end
                
                -- Make cooldown augments equal to number of powered spheres
                local diff = combatChronosPowered - Hyperspace.ships.player:HasAugmentation("COMBAT_CHRONO_COOLDOWN")
                if diff > 0 then
                    for i = 1, diff do
                        Hyperspace.ships.player:AddAugmentation("HIDDEN COMBAT_CHRONO_COOLDOWN")
                    end
                elseif diff < 0 then
                    for i = diff, -1 do
                        Hyperspace.ships.player:RemoveAugmentation("HIDDEN COMBAT_CHRONO_COOLDOWN")
                    end
                end
            end
        end
    end
    script.on_internal_event(Defines.InternalEvents.ON_TICK, mods.cnconquer.OnTick)
end

-- Handle crew mind controlled via a weapon
if not mods.cnconquer.CrewLoop then
    function mods.cnconquer.CrewLoop(crewmem)
        local crewmemData = mods.chronoutil.crew_data(crewmem)
        if crewmemData.mcTime then
            if crewmem.bDead then
                crewmemData.mcTime = nil
            else
                crewmemData.mcTime = math.max(crewmemData.mcTime - Hyperspace.FPS.SpeedFactor/16, 0)
                if crewmemData.mcTime == 0 then
                    crewmem:SetMindControl(false)
                    crewmemData.mcTime = nil
                    Hyperspace.Global.GetInstance():GetSoundControl():PlaySoundMix("psiRelease", 0.18, false)
                end
            end
        end
    end
    script.on_internal_event(Defines.InternalEvents.CREW_LOOP, mods.cnconquer.CrewLoop)
end

-- Mind control beam list and duration of MC (in seconds)
mods.cnconquer.mcBeamTimes = {}
mods.cnconquer.mcBeamTimes["FOCUS_MC_COMBAT"] = 9
mods.cnconquer.mcBeamTimes["FOCUS_MC_SABOTAGE"] = 9
mods.cnconquer.mcBeamTimes["BEAM_MC_COMBAT"] = 12
mods.cnconquer.mcBeamTimes["BEAM_MC_SABOTAGE"] = 12

-- Prism beam list and refraction count
mods.cnconquer.prismRefractCount = {}
mods.cnconquer.prismRefractCount["BEAM_PRISM_1"] = 3
mods.cnconquer.prismRefrectBlueprint = Hyperspace.Global.GetInstance():GetBlueprints():GetWeaponBlueprint("BEAM_PRISM_REFRACT")

-- Handle special beams
if not mods.cnconquer.BeamDamage then
    function mods.cnconquer.BeamDamage(shipManager, projectile, location, damage, realNewTile, beamHitType)
        -- Mind control beams
        local thisMcTime = mods.cnconquer.mcBeamTimes[Hyperspace.Get_Projectile_Extend(projectile).name]
        if thisMcTime then -- Doesn't check realNewTile anymore 'cause the beam kept missing crew that were on the move
            for i, crewmem in ipairs(mods.chronoutil.get_ship_crew_point(shipManager, location.x, location.y)) do
                if not (crewmem:IsTelepathic() or crewmem:IsDrone()) and not mods.chronoutil.under_mind_system(crewmem) then
                    crewmem:SetMindControl(true)
                    mods.chronoutil.crew_data(crewmem).mcTime = thisMcTime
                end
            end
        end
        
        -- Prism beams
        local refractions = mods.cnconquer.prismRefractCount[Hyperspace.Get_Projectile_Extend(projectile).name]
        if refractions and realNewTile then
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
            while #validTargets > 0 and #validTargets + refractions > validTargetCount do
                local targetIndex = Hyperspace.random32()%#validTargets + 1
                spaceManager:CreateBeam(
                    mods.cnconquer.prismRefrectBlueprint,
                    location,
                    shipManager.iShipId,
                    (shipManager.iShipId + 1)%2,
                    validTargets[targetIndex], validTargets[targetIndex],
                    shipManager.iShipId,
                    1, 0 --(math.atan(location.y - target.y, location.x - target.x)*180)/math.pi - 90
                )
                table.remove(validTargets, targetIndex)
            end
        end
    end
    script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, mods.cnconquer.BeamDamage)
end

-- Adepts stun themselves for 4 seconds when they use their power
if not mods.cnconquer.ActivatePower then
    function mods.cnconquer.ActivatePower(power, shipManager)
        local crewmem = power.crew
        if crewmem:GetSpecies() == "human_adept" then
            crewmem.fStunTime = math.max(crewmem.fStunTime, 4)
        end
    end
    script.on_internal_event(Defines.InternalEvents.ACTIVATE_POWER, mods.cnconquer.ActivatePower)
end

-- Make the ion cannon target a specific system
if not mods.cnconquer.SetIonCannonTarget then
    function mods.cnconquer.SetIonCannonTarget()
        local targetsys = Hyperspace.ships.player:HasEquipment("loc_ioncannon_target_room")
        if Hyperspace.ships.enemy:HasSystem(targetsys) then
            local retarget = 
                Hyperspace.ships.enemy:GetRoomCenter(Hyperspace.ships.enemy:GetSystemRoom(targetsys))
            for proj in mods.chronoutil.vter(Hyperspace.ships.player.superBarrage) do
                proj.target = retarget
                proj:ComputeHeading()
            end
        end
    end
    script.on_game_event("LUA_SET_IONCANNON_TARGET", false, mods.cnconquer.SetIonCannonTarget)
end

-- Point out the iron curtain button when the game starts
if not mods.cnconquer.StartBeaconIronCurtain then
    function mods.cnconquer.StartBeaconIronCurtain() mods.chronoutil.ShowTutorialArrow(2, 132, 79) end
    script.on_game_event("INITIAL_START_BEACON_IRON_CURTAIN", false, mods.cnconquer.StartBeaconIronCurtain)
    script.on_game_event("START_BEACON_PREP_LOAD", false, mods.chronoutil.HideTutorialArrow)
end

-- Regenerate a super shield bubble for iron curtain
if not mods.cnconquer.IronCurtainActivate then
    function mods.cnconquer.IronCurtainActivate()
        local shields = nil
        if pcall(function()
            shields = Hyperspace.ships.player.shieldSystem
        end) and shields then
            shields:AddSuperShield(shields.center)
        end
    end
    script.on_game_event("LUA_IRON_CURTAIN", false, mods.cnconquer.IronCurtainActivate)
end
