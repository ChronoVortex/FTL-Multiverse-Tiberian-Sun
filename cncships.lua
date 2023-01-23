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

-- Prism cannon tracking stuff
mods.cnconquer.prismProjectiles = {}
mods.cnconquer.prismProjLifetimes = {}

-- All ontick code for C&C
-- Manage prism cannon and combat chronosphere
if not mods.cnconquer.OnTick then
    function mods.cnconquer.OnTick()
        -- We only need to do any of this if the game isn't paused
        if not Hyperspace.Global.GetInstance():GetCApp().world.space.gamePaused then
            -- Garbage collect saved projectiles
            local toRemove = {}
            for i, projectile in ipairs(mods.cnconquer.prismProjectiles) do
                mods.cnconquer.prismProjLifetimes[i] = mods.cnconquer.prismProjLifetimes[i] - Hyperspace.FPS.SpeedFactor/16
                if projectile:Dead() or projectile.missed then
                    mods.cnconquer.prismProjLifetimes[i] = math.min(mods.cnconquer.prismProjLifetimes[i], Hyperspace.FPS.SpeedFactor/8)
                end
                if mods.cnconquer.prismProjLifetimes[i] <= 0 then
                    table.insert(toRemove, 1, i)
                end
            end
            for i, index in ipairs(toRemove) do
                table.remove(mods.cnconquer.prismProjectiles, index)
                table.remove(mods.cnconquer.prismProjLifetimes, index)
            end
            
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
                    
                    -- Capture projectiles fired by prism cannon
                    if weapon.name == "Prism Cannon" then
                        local projectile = weapon:GetProjectile()
                        if projectile then
                            Hyperspace.Global.GetInstance():GetCApp().world.space.projectiles:push_back(projectile)
                            table.insert(mods.cnconquer.prismProjectiles, projectile)
                            table.insert(mods.cnconquer.prismProjLifetimes, 20)
                        end
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

-- Make prism surge look like it came from the triggering projectile
if not mods.cnconquer.MovePrismSurge then
    function mods.cnconquer.MovePrismSurge()
        -- The projectile which is closest to its target will likely
        -- be the triggering projectile
        local closestDist = 999999
        local originPoint = nil
        local removeIndex = -1
        for i, projectile in ipairs(mods.cnconquer.prismProjectiles) do
            local dist = math.sqrt((projectile.target.x - projectile.position.x)^2 + (projectile.target.y - projectile.position.y)^2)
            if dist < closestDist then
                closestDist = dist
                originPoint = projectile.position
                removeIndex = i
            end
        end
        
        -- Move all barrage projectiles to triggering projectile
        if originPoint then
            table.remove(mods.cnconquer.prismProjectiles, removeIndex)
            table.remove(mods.cnconquer.prismProjLifetimes, removeIndex)
            for proj in mods.chronoutil.vter(Hyperspace.ships.player.superBarrage) do
                proj:EnterDestinationSpace()
                proj.position = originPoint
                proj:ComputeHeading()
            end
        end
    end
    script.on_game_event("LUA_MOVE_PRISM_SURGE", false, mods.cnconquer.MovePrismSurge)
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
