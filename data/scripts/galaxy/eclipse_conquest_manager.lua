package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local CosmicVaultTerritory = nil
local cv_goods_success, cv_goods = pcall(require, "cosmicvaultgoods")
local cv_news_success, cv_news = pcall(require, "cosmicvaultnews")
pcall(function() CosmicVaultTerritory = include("cosmicvaultterritory") end)

local EclipseConquestManager = {}
EclipseConquestManager.timer = 0

function EclipseConquestManager.getUpdateInterval()
    return 60.0
end

function EclipseConquestManager.initialize()
    if cv_goods_success and cv_goods.registerGood then
        cv_goods.registerGood({
            name = "Ascendant Matter",
            description = "A hyper-dense dark energy composite synthesized by Eclipse Harvesters.",
            price = 500000,
            size = 2.5,
            icon = "data/textures/icons/PHOTON.png",
            illegal = true,
            dangerous = true,
            tags = {ascendant = true}
        })
        cv_goods.registerGood({
            name = "Eclipse Datacore",
            description = "An encrypted quantum datacore extracted from a high-ranking Eclipse vessel.",
            price = 1000000,
            size = 5.0,
            icon = "data/textures/icons/circuit-board.png",
            illegal = true,
            tags = {ascendant = true}
        })
    end
    
    if not Server():getValue("eclipse_fully_awake") then return end
end
end

function EclipseConquestManager.updateServer(timeStep)
    if not Server():getValue("eclipse_fully_awake") then return end
    
    EclipseConquestManager.timer = EclipseConquestManager.timer + timeStep
    
    -- Every 30 to 45 minutes, the Eclipse expand
    if EclipseConquestManager.timer > random():getInt(30, 45) * 60 then
        EclipseConquestManager.timer = 0
        EclipseConquestManager.expandEmpire()
    end
end

function EclipseConquestManager.expandEmpire()
    -- Find a target sector to invade. We'll pick a random player's known sector to ensure it's a sector that actually exists and is inhabited.
    local players = {Server():getPlayers()}
    if #players == 0 then return end
    
    local player = players[random():getInt(1, #players)]
    local knownSectors = {player:getKnownSectors()}
    if #knownSectors == 0 then return end
    
    local targetSector = knownSectors[random():getInt(1, #knownSectors)]
    local tx, ty = targetSector.x, targetSector.y
    
    local EclipseGenerator = include("eclipsegenerator")
    local eclipseFaction = EclipseGenerator.getFaction()
    
    -- 40% chance to Conquest (Boarding/Siege via Cosmic War)
    -- 60% chance to Annihilation (Total wipe)
    if random():getFloat() < 0.4 then
        -- CONQUEST
        if CosmicVaultTerritory and CosmicVaultTerritory.addContestedZone then
            CosmicVaultTerritory.addContestedZone(tx, ty, eclipseFaction.index)
            Server():broadcastChatMessage("The Eclipse", 2, "Commencing assimilation of coordinates (" .. tx .. ":" .. ty .. "). Resistance is biologically inefficient.")
            
            -- If the sector is currently loaded in memory, inject the siege event immediately
            local sector = Sector()
            if sector and sector:getCoordinates() == tx and sector:getCoordinates() == ty then
                if not sector:hasScript("events/siegeevent.lua") then
                    sector:addScript("data/scripts/events/siegeevent.lua")
                    sector:invokeFunction("events/siegeevent.lua", "initialize")
                end
            end
        else
            -- Cosmic War not installed or hooked, fallback to Annihilation
            EclipseConquestManager.annihilateSector(tx, ty, eclipseFaction)
        end
    else
        -- ANNIHILATION
        EclipseConquestManager.annihilateSector(tx, ty, eclipseFaction)
    end
end

function EclipseConquestManager.annihilateSector(x, y, eclipseFaction)
    Server():broadcastChatMessage("The Eclipse", 2, "Coordinates (" .. x .. ":" .. y .. ") have been judged unworthy of Ascendancy. Initiating total atomic annihilation.")
    
    if cv_news_success and cv_news.publishArticle then
        cv_news.publishArticle({
            title = "Sector Annihilated: [" .. x .. ":" .. y .. "]",
            content = "The Eclipse has completely wiped coordinates [" .. x .. ":" .. y .. "] from the map. Billions are feared dead as all stations and ships were atomically disintegrated.",
            category = "Galactic Dread"
        })
    end
    
    -- Change the territory to The Eclipse globally on the galaxy map
    local galaxy = Galaxy()
    galaxy:setFaction(x, y, eclipseFaction.index)
    
    -- If the sector is currently loaded in memory, literally wipe everything
    local sector = Sector()
    if sector then
        local cx, cy = sector:getCoordinates()
        if cx == x and cy == y then
            local entities = {sector:getEntities()}
            for _, entity in pairs(entities) do
                if entity.type == EntityType.Station or entity.type == EntityType.Ship then
                    if entity.factionIndex ~= eclipseFaction.index then
                        sector:deleteEntity(entity)
                    end
                end
            end
            
            -- Spawn an Obliterator to show who did it
            local EclipseGenerator = include("eclipsegenerator")
            local ship = EclipseGenerator.createShip(Matrix(), "monolith")
            ship:setTitle("Eclipse Obliterator", {})
            
            -- Attach the heroic defense tracker in case the player fights back
            ship:addScriptOnce("data/scripts/entity/ca_heroic_defense.lua")
        end
    end
end

return EclipseConquestManager
