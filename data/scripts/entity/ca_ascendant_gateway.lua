package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local ShipGenerator = include("shipgenerator")

function getUpdateInterval() return 5.0 end

function updateServer(timeStep)
    local sector = Sector()
    local x, y = sector:getCoordinates()
    
    -- Scan for enemies
    local enemiesPresent = false
    local playerFaction = Faction(Entity().factionIndex)
    
    if not playerFaction then return end
    
    local entities = {sector:getEntitiesByType(EntityType.Ship)}
    for _, ship in pairs(entities) do
        if ship.factionIndex ~= playerFaction.index then
            local otherFaction = Faction(ship.factionIndex)
            if otherFaction and playerFaction:getRelations(otherFaction.index) < -10000 then
                enemiesPresent = true
                break
            end
        end
    end
    
    if enemiesPresent then
        -- Check cooldown (7200 seconds = 2 hours)
        local lastSummon = Entity():getValue("last_ascendant_summon") or 0
        local serverTime = Server().unpausedRuntime
        
        if serverTime - lastSummon > 7200 then
            Entity():setValue("last_ascendant_summon", serverTime)
            
            sector:broadcastChatMessage("Ascendant Gateway", 0, "Hostiles detected. Summoning Ascendant Defense Fleet...")
            
            -- Summon allied fleet
            for i = 1, 3 do
                local plan = PlanGenerator.makeShipPlan(playerFaction, Balancing_GetSectorShipVolume(x, y) * 2, Material(MaterialType.Ogonite))
                local defender = sector:createShip(playerFaction, "", plan, Matrix(), EntityArrivalType.Jump)
                defender.title = "Ascendant Guardian"
                defender.crew = defender.idealCrew
                defender.shieldDurability = defender.shieldMaxDurability
                
                defender:addScriptOnce("ai/patrol.lua")
                local damageBonuses = {StatsBonuses.ArmedTurrets, StatsBonuses.ArbitraryTurrets}
                for _, stat in pairs(damageBonuses) do
                    defender:addMultiplyableBias(stat, 2.0)
                end
                defender:addMultiplyableBias(StatsBonuses.ShieldDurability, 2.0)
            end
        end
    end
end
