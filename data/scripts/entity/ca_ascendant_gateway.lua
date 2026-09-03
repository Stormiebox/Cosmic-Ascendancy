package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local PlanGenerator = include("plangenerator")

function getUpdateInterval() return 5.0 end

function updateServer(timeStep)
    local sector = Sector()
    local x, y = sector:getCoordinates()
    
    -- Scan for enemies
    local enemiesPresent = false
    local playerFaction = Faction(Entity().factionIndex)
    
    if not playerFaction then return end
    
    local factions = {sector:getPresentFactions()}
    for _, f in pairs(factions) do
        if f ~= playerFaction.index and playerFaction:getRelations(f) < -10000 then
            local ships = {sector:getEntitiesByFaction(f)}
            for _, ship in pairs(ships) do
                if ship.isShip then
                    enemiesPresent = true
                    break
                end
            end
        end
        if enemiesPresent then break end
    end
    
    if enemiesPresent then
        -- Check cooldown (7200 seconds = 2 hours)
        local lastSummon = Entity():getValue("last_ascendant_summon") or 0
        local serverTime = Server().unpausedRuntime
        
        if serverTime - lastSummon > 7200 then
            Entity():setValue("last_ascendant_summon", serverTime)
            
            sector:broadcastChatMessage("Ascendant Gateway", 0, "Hostiles detected. Summoning Ascendant Defense Fleet...")
            
            local gatewayPos = Entity().translationf
            
            -- Summon allied fleet
            for i = 1, 3 do
                -- makeShipPlan(faction, volume, styleName, material) -- styleName (3rd) must be a
                -- string/nil, material (4th) is the Material object; passing the Material into the
                -- styleName slot fed a userdata into Seed()/getPlanStyle() and silently dropped the
                -- intended Ogonite material (makeAsyncShipPlan falls back to selectMaterial() when
                -- material is nil).
                local plan = PlanGenerator.makeShipPlan(playerFaction, Balancing_GetSectorShipVolume(x, y) * 2, nil, Material(MaterialType.Ogonite))
                local m = Matrix()
                local angle = (math.pi * 2 / 3) * i
                m.translation = gatewayPos + vec3(math.cos(angle), 0, math.sin(angle)) * 800
                
                local defender = sector:createShip(playerFaction, "", plan, m, EntityArrivalType.Jump)
                defender.title = "Ascendant Guardian"
                defender.crew = defender.idealCrew
                defender:addScriptOnce("ai/patrol.lua")
                -- Apply a permanent multiplicative bonus to fire rate to act as a 3x DPS multiplier
                -- since modifying the damageMultiplier property directly is discarded by the engine.
                defender:addBaseMultiplier(StatsBonuses.FireRate, 2.0)
                defender:addBaseMultiplier(StatsBonuses.ShieldDurability, 3.0)
                
                -- Fill shields to max so defenders spawn battle-ready
                defender.shieldDurability = defender.shieldMaxDurability
            end
        end
    end
end
