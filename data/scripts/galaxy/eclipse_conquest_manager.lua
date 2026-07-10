package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local CosmicVaultTerritory = nil
local cv_goods = include("cosmicvaultgoods")
local cv_news = include("cosmicvaultnews")
local FactionEradicationUtility = include("factioneradicationutility")
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
            price = 250000,
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
        cv_goods.registerGood({
            name = "Ascendant Scrap",
            description = "Failed remnants of an Ascendant forging process. Highly sought after by underground tech brokers.",
            price = 100000,
            size = 1.0,
            icon = "data/textures/icons/metal-scales.png",
            illegal = true,
            tags = {ascendant = true}
        })
    end

    if not Server():getValue("eclipse_fully_awake") then return end
end
function EclipseConquestManager.updateServer(timeStep)
    if not Server():getValue("eclipse_fully_awake") then return end

    -- Pause expansion if no players are online (protects 24/7 dedicated servers from offline wipes)
    local players = {Server():getPlayers()}
    if #players == 0 then return end

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
    
    -- Suppression Field Logic: Halt invasions dynamically (6 hours base + 2 hours per 10 sectors owned) after a Citadel dies
    local citadelDestroyed = Server():getValue("eclipse_citadel_destroyed_time") or 0
    local suppressionDuration = (6 + math.floor(conqueredCount / 10) * 2) * 3600
    if Server().unpausedRuntime - citadelDestroyed < suppressionDuration then
        return -- Suppressed
    end

    -- Check if we should awaken
    if conqueredCount >= 75 and not isFallenEmpire then
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
        -- We randomly sample coordinates to find an active, non-eradicated AI faction
        local targets = {}
        for i = 1, 100 do
            local sx = random():getInt(-490, 490)
            local sy = random():getInt(-490, 490)
            local faction = Galaxy():getControllingFaction(sx, sy)
            
            if faction and faction.isAIFaction and not faction:getValue("is_eclipse") and faction.name ~= "The Eclipse" then
                local isEradicated = false
                if FactionEradicationUtility and FactionEradicationUtility.isFactionEradicated then
                    isEradicated = FactionEradicationUtility.isFactionEradicated(faction.index)
                end
                
                if not isEradicated then
                    local hx, hy = faction:getHomeSectorCoordinates()
                    if hx and hy and (hx ~= 0 or hy ~= 0) then
                        table.insert(targets, {x=hx, y=hy, faction=faction})
                    end
                end
            end
            
            -- Stop once we have enough valid crusade candidates
            if #targets >= 5 then break end
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
            tx, ty = targetSector:getCoordinates()
        end
    else
        -- Normal Logic: Random player known sector
        local players = {Server():getPlayers()}
        if #players == 0 then return end
        local player = players[random():getInt(1, #players)]
        local knownSectors = {player:getKnownSectors()}
        if #knownSectors == 0 then return end
        local targetSector = knownSectors[random():getInt(1, #knownSectors)]
        tx, ty = targetSector:getCoordinates()
    end

    -- 40% chance to Conquest (Boarding/Siege via Cosmic War)
    -- 60% chance to Annihilation (Total wipe)
    if random():getFloat() < 0.4 then
        -- CONQUEST
        if CosmicVaultTerritory and CosmicVaultTerritory.setContestedZone then
            local defFactionObj = Galaxy():getControllingFaction(tx, ty)
            local defFactionIndex = defFactionObj and defFactionObj.index or 0
            CosmicVaultTerritory.setContestedZone(tx, ty, eclipseFaction.index, defFactionIndex, 120)
            Server():broadcastChatMessage("The Eclipse", 2, "Commencing assimilation of coordinates (" .. tx .. ":" .. ty .. "). Resistance is biologically inefficient.")

              -- Inject the siege event safely into the sector thread
              local code = [[
                  function run()
                      if not Sector():hasScript("events/siegeevent.lua") then
                          Sector():addScriptOnce("data/scripts/events/siegeevent.lua")
                      end
                  end
              ]]
              runSectorCode(tx, ty, true, code, "run")

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

    -- To forcefully strip faction ownership, we briefly force the server to load the sector.
    -- This guarantees the `ca_delayed_annihilation.lua` script fires immediately and physically destroys the stations,
    -- which naturally recalculates the map ownership to Neutral, preventing Ghost claims.
    
    local code = [[
        function run()
            if not Sector():hasScript("sector/ca_delayed_annihilation.lua") then
                Sector():addScriptOnce("data/scripts/sector/ca_delayed_annihilation.lua")
            end
        end
    ]]
    runSectorCode(x, y, true, code, "run")
end

function EclipseConquestManager.secure()
    return {timer = EclipseConquestManager.timer}
end

function EclipseConquestManager.restore(data)
    if data then
        EclipseConquestManager.timer = data.timer or 0
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
function secure(...)
    if EclipseConquestManager.secure then return EclipseConquestManager.secure(...) end
end
function restore(...)
    if EclipseConquestManager.restore then return EclipseConquestManager.restore(...) end
end
