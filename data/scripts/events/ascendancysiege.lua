package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local PirateGenerator = include("pirategenerator")
local Xsotan = include("story/xsotan")
local ShipGenerator = include("shipgenerator")
local Placer = include("placer")

local cv_success, cv_news = pcall(require, "cosmicvaultnews")
local cw_success, cw_bridge = pcall(require, "cosmicwarbridge")

-- namespace AscendancySiege
AscendancySiege = {}

local tier = 1
local targetFactionIndex = 0
local attackers = {}
local attackerFaction = 0
local typeName = "Pirates"
local active = false

function AscendancySiege.initialize(t, ownerIndex)
    if not onServer() then return end
    tier = t or 1
    targetFactionIndex = ownerIndex or 0
    active = true
    
    -- Choose attacker type
    local r = math.random()
    if cw_success and cw_bridge.getFactionWarHeat then
        local factions = {Sector():getPresentFactions()}
        local warFaction = nil
        for _, f in pairs(factions) do
            if f.isAIFaction and f:getRelations(targetFactionIndex) < -40000 then
                warFaction = f
                break
            end
        end
        if warFaction and r < 0.4 then
            attackerFaction = warFaction.index
            typeName = warFaction.name
        elseif r < 0.7 then
            typeName = "Xsotan"
        else
            typeName = "Pirates"
        end
    else
        if r < 0.5 then typeName = "Xsotan" else typeName = "Pirates" end
    end
    
    AscendancySiege.spawnFleet()
    AscendancySiege.broadcastWarning()
end

function AscendancySiege.spawnFleet()
    local dir = normalize(vec3(getFloat(-1, 1), getFloat(-1, 1), getFloat(-1, 1)))
    local up = vec3(0, 1, 0)
    local right = normalize(cross(dir, up))
    local pos = dir * 1500
    
    local numShips = 3 + (tier * 2)
    local numBosses = math.max(0, tier - 2)
    
    local faction
    if typeName == "Xsotan" then
        faction = Xsotan.getFaction()
    elseif typeName == "Pirates" then
        faction = PirateGenerator.getFaction()
    else
        faction = Faction(attackerFaction)
    end
    
    -- Spawn Bosses (Battleships/Dreadnoughts)
    for i = 1, numBosses do
        local shipPos = MatrixLookUpPosition(-dir, up, pos + right * getFloat(-500, 500) + up * getFloat(-500, 500))
        local ship
        if typeName == "Xsotan" then
            ship = Xsotan.createDreadnought(shipPos)
        elseif typeName == "Pirates" then
            ship = PirateGenerator.createBoss(shipPos)
        else
            local volume = ShipGenerator.getMilitaryShipVolume(faction, 10) * (1 + (tier * 0.5))
            ship = ShipGenerator.createMilitaryShip(faction, shipPos, volume)
        end
        ship:addScript("ai/patrol.lua")
        ship:setValue("is_ascendancy_siege", true)
        table.insert(attackers, ship.id.string)
    end
    
    -- Spawn Standard Fleet
    for i = 1, numShips do
        local shipPos = MatrixLookUpPosition(-dir, up, pos + right * getFloat(-500, 500) + up * getFloat(-500, 500))
        local ship
        if typeName == "Xsotan" then
            ship = Xsotan.createShip(shipPos)
        elseif typeName == "Pirates" then
            ship = PirateGenerator.createPirate(shipPos)
        else
            local volume = ShipGenerator.getMilitaryShipVolume(faction, 5) * (1 + (tier * 0.2))
            ship = ShipGenerator.createMilitaryShip(faction, shipPos, volume)
        end
        ship:addScript("ai/patrol.lua")
        ship:setValue("is_ascendancy_siege", true)
        table.insert(attackers, ship.id.string)
    end
    
    Placer.resolveIntersections()
end

function AscendancySiege.broadcastWarning()
    local x, y = Sector():getCoordinates()
    Sector():broadcastChatMessage("System"%_t, 1, "WARNING! Massive %1% siege fleet detected entering the sector!"%_t, typeName)
    
    if cv_success and cv_news.publishArticle then
        local owner = Faction(targetFactionIndex)
        local ownerName = owner and owner.name or "Unknown"
        cv_news.publishArticle({
            title = "Capital Siege: " .. typeName .. " Invade " .. ownerName .. " Empire",
            content = "A gargantuan fleet belonging to the " .. typeName .. " has initiated a massive siege against the Ascendant Capital in sector [" .. x .. ":" .. y .. "]. Defense fleets are scrambling.",
            category = "Galactic War"
        })
    end
end

function AscendancySiege.getUpdateInterval()
    return 5
end

function AscendancySiege.updateServer(timeStep)
    if not active then return end
    
    -- Check if beacon is still alive
    local beaconAlive = false
    local entities = {Sector():getEntitiesByScript("data/scripts/entity/ascendancybeacon.lua")}
    for _, entity in pairs(entities) do
        if entity.factionIndex == targetFactionIndex then
            beaconAlive = true
            break
        end
    end
    
    if not beaconAlive then
        -- Beacon was destroyed!
        AscendancySiege.onDefeat()
        return
    end
    
    -- Check attackers
    local attackersAlive = false
    local newAttackers = {}
    for _, id in pairs(attackers) do
        local ship = Entity(Uuid(id))
        if ship and not ship.isDestroyed then
            table.insert(newAttackers, id)
            attackersAlive = true
        end
    end
    attackers = newAttackers
    
    if not attackersAlive then
        AscendancySiege.onVictory()
    end
end

function AscendancySiege.onVictory()
    active = false
    local x, y = Sector():getCoordinates()
    Sector():broadcastChatMessage("System"%_t, 3, "Siege Defeated! The Ascendant Capital stands strong."%_t)
    
    -- Spawn massive loot explosion at sector center
    local generator = include("weapongenerator")
    local upgGenerator = include("upgradegenerator")
    for i = 1, 5 + tier * 2 do
        Sector():dropTurret(vec3(0,0,0), nil, nil, generator.generate(x, y, 0, Rarity(math.min(5, tier + 1))))
        Sector():dropUpgrade(vec3(0,0,0), nil, nil, upgGenerator.generate(x, y, 0, Rarity(math.min(5, tier + 1))))
    end
    
    local owner = Faction(targetFactionIndex)
    if owner then
        owner:receive("Ascendant Siege Defense Reward", tier * 2500000)
    end
    
    terminate()
end

function AscendancySiege.onDefeat()
    active = false
    local x, y = Sector():getCoordinates()
    Sector():broadcastChatMessage("System"%_t, 1, "The Ascendant Capital has fallen..."%_t)
    
    if cv_success and cv_news.publishArticle then
        cv_news.publishArticle({
            title = "Capital Falls to " .. typeName,
            content = "The Ascendancy Beacon in sector [" .. x .. ":" .. y .. "] has been completely destroyed. The surrounding empire's global power has collapsed.",
            category = "Galactic War"
        })
    end
    
    -- Jump the attackers away since they won
    for _, id in pairs(attackers) do
        local ship = Entity(Uuid(id))
        if ship and not ship.isDestroyed then
            ship:addScriptOnce("entity/utility/delayedjump.lua")
        end
    end
    
    terminate()
end
