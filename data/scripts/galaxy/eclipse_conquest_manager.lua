package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local CosmicVaultTerritory = nil
local cv_goods = include("cosmicvaultgoods")
local cv_news = include("cosmicvaultnews")
CosmicVaultTerritory = include("cosmicvaultterritory")

local EclipseConquestManager = {}
EclipseConquestManager.timer = 0

function EclipseConquestManager.getUpdateInterval()
    return 60.0
end

function EclipseConquestManager.initialize()
    if cv_goods.registerGood then
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
    local EclipseGenerator = include("eclipsegenerator")
    local eclipseFaction = EclipseGenerator.getFaction()

    local conqueredCount = Server():getValue("eclipse_conquered_sectors") or 0
    local isFallenEmpire = Server():getValue("eclipse_fallen_empire")

    -- Check if we should awaken
    if conqueredCount >= 10 and not isFallenEmpire then
        Server():setValue("eclipse_fallen_empire", true)
        isFallenEmpire = true
        if cv_news.publishArticle then
            cv_news.publishArticle({
                title = "GALACTIC THREAT: The Eclipse Awakens",
                content = "The algorithmic nightmare known as The Eclipse has consolidated enough territory to form a unified, highly organized empire. They have ceased random raids and are now actively launching Crusades to systematically eradicate all major AI faction capitals. We must unite, or we will perish.",
                category = "Galactic Dread"
            })
        end
    end

    local tx, ty

    if isFallenEmpire then
        -- Crusade Logic: Seek out an AI Faction Capital
        -- We will scan factions and find one with a home sector
        local factions = {Galaxy():getFactions()}
        local targets = {}
        for _, faction in pairs(factions) do
            if not faction.isPlayer and not faction.isAlliance and not faction:getValue("is_eclipse") and faction.name ~= "The Eclipse" then
                local hx, hy = faction:getHomeSectorCoordinates()
                if hx and hy and (hx ~= 0 or hy ~= 0) then
                    table.insert(targets, {x=hx, y=hy, faction=faction})
                end
            end
        end

        if #targets > 0 then
            local target = targets[random():getInt(1, #targets)]
            tx, ty = target.x, target.y
            Server():broadcastChatMessage("The Eclipse", 2, "Crusade designated. Sector (" .. tx .. ":" .. ty .. ") has been marked for priority assimilation.")
        else
            -- No AI capitals left, fallback to player hunt
            local players = {Server():getPlayers()}
            if #players == 0 then return end
            local player = players[random():getInt(1, #players)]
            local knownSectors = {player:getKnownSectors()}
            if #knownSectors == 0 then return end
            local targetSector = knownSectors[random():getInt(1, #knownSectors)]
            tx, ty = targetSector.x, targetSector.y
        end
    else
        -- Normal Logic: Random player known sector
        local players = {Server():getPlayers()}
        if #players == 0 then return end
        local player = players[random():getInt(1, #players)]
        local knownSectors = {player:getKnownSectors()}
        if #knownSectors == 0 then return end
        local targetSector = knownSectors[random():getInt(1, #knownSectors)]
        tx, ty = targetSector.x, targetSector.y
    end

    -- 40% chance to Conquest (Boarding/Siege via Cosmic War)
    -- 60% chance to Annihilation (Total wipe)
    if random():getFloat() < 0.4 then
        -- CONQUEST
        if CosmicVaultTerritory and CosmicVaultTerritory.addContestedZone then
            CosmicVaultTerritory.addContestedZone(tx, ty, eclipseFaction.index)
            Server():broadcastChatMessage("The Eclipse", 2, "Commencing assimilation of coordinates (" .. tx .. ":" .. ty .. "). Resistance is biologically inefficient.")

            -- If the sector is currently loaded in memory, inject the siege event safely via a player currently inside it
            for _, p in pairs({Server():getPlayers()}) do
                local px, py = p:getSectorCoordinates()
                if px == tx and py == ty then
                    p:addScriptOnce("data/scripts/player/ca_siege_injector.lua")
                    break
                end
            end

            -- Increment counter since it's a conquest attempt that will turn the sector
            Server():setValue("eclipse_conquered_sectors", conqueredCount + 1)
        else
            -- Cosmic War not installed or hooked, fallback to Annihilation
            EclipseConquestManager.annihilateSector(tx, ty, eclipseFaction, conqueredCount)
        end
    else
        -- ANNIHILATION
        EclipseConquestManager.annihilateSector(tx, ty, eclipseFaction, conqueredCount)
    end
end

function EclipseConquestManager.annihilateSector(x, y, eclipseFaction, conqueredCount)
    Server():broadcastChatMessage("The Eclipse", 2, "Coordinates (" .. x .. ":" .. y .. ") have been judged unworthy of Ascendancy. Initiating total atomic annihilation.")

    if cv_news.publishArticle then
        cv_news.publishArticle({
            title = "Sector Annihilated: [" .. x .. ":" .. y .. "]",
            content = "The Eclipse has completely wiped coordinates [" .. x .. ":" .. y .. "] from the map. Billions are feared dead as all stations and ships were atomically disintegrated.",
            category = "Galactic Dread"
        })
    end

    -- Increment global conquest tracker
    Server():setValue("eclipse_conquered_sectors", (conqueredCount or Server():getValue("eclipse_conquered_sectors") or 0) + 1)

    -- IMPORTANT ARCHITECTURE NOTE:
    -- In Avorion, calling `Sector()` inside a Galaxy-level or Server-level background script
    -- will instantly crash the dedicated server. To physically wipe a sector, we must delegate 
    -- the task to a Player or Sector script instance.
    -- If a player is in the sector, we attach a one-time wipe script to their client.
    for _, p in pairs({Server():getPlayers()}) do
        local px, py = p:getSectorCoordinates()
        if px == x and py == y then
            p:addScriptOnce("data/scripts/player/ca_annihilation_wiper.lua")
        end
    end
end

function getUpdateInterval(...)
    if EclipseConquestManager.getUpdateInterval then return EclipseConquestManager.getUpdateInterval(...) end
end
function initialize(...)
    if EclipseConquestManager.initialize then return EclipseConquestManager.initialize(...) end
end
function updateServer(...)
    if EclipseConquestManager.updateServer then return EclipseConquestManager.updateServer(...) end
end
