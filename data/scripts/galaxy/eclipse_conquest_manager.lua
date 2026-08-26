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
            icon = "data/textures/icons/AscendantMatter.png",
            illegal = true,
            dangerous = true,
            tags = {ascendant = true}
        })
        cv_goods.registerGood({
            name = "Eclipse Datacore",
            description = "An encrypted quantum datacore extracted from a high-ranking Eclipse vessel.",
            price = 1000000,
            size = 5.0,
            icon = "data/textures/icons/EclipseDatacore.png",
            illegal = true,
            tags = {ascendant = true}
        })
        cv_goods.registerGood({
            name = "Ascendant Scrap",
            description = "Failed remnants of an Ascendant forging process. Highly sought after by underground tech brokers.",
            price = 100000,
            size = 1.0,
            icon = "data/textures/icons/AscendantScrap.png",
            illegal = true,
            tags = {ascendant = true}
        })
    end

    if not Server():getValue("eclipse_fully_awake") then return end
end
function EclipseConquestManager.updateServer(timeStep)
    if not Server():getValue("eclipse_fully_awake") then return end

    -- Pause expansion if no players are online (protects 24/7 dedicated servers from offline wipes)
    local players = {Server():getOnlinePlayers()}
    if #players == 0 then return end

    local conqueredCount = Server():getValue("eclipse_conquered_sectors") or 0
    local threat = Server():getValue("eclipse_threat") or 0
    
    -- Threat generation: Base 300 per minute + (20 per held sector per minute)
    local threatPerSecond = (300 + (conqueredCount * 20)) / 60.0
    threat = threat + (threatPerSecond * timeStep)
    Server():setValue("eclipse_threat", threat)

    if threat >= 10000 then
        Server():setValue("eclipse_threat", threat - 10000)
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
    local crusadeTargetFound = false

    if isFallenEmpire then
        -- Crusade Logic: Seek out an AI Faction Capital
        -- We randomly sample coordinates to find an active, non-eradicated AI faction
        local targets = {}
        local cpuTimer = HighResolutionTimer()
        cpuTimer:start()
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
            
            -- CPU Tick Safety: Abort if loop takes longer than 50ms
            if cpuTimer.seconds > 0.05 then break end
        end

        if #targets > 0 then
            local target = targets[random():getInt(1, #targets)]
            tx, ty = target.x, target.y
            Server():broadcastChatMessage("The Eclipse", 2, "Crusade designated. Sector (" .. tx .. ":" .. ty .. ") has been marked for priority assimilation.")
            crusadeTargetFound = true
        end
    end

    if not crusadeTargetFound then
        -- Normal Logic: Geographic Infection Spread
        local territoryString = Server():getValue("eclipse_held_territory") or ""
        local coords = {}
        for match in string.gmatch(territoryString, "(%-?%d+_%-?%d+),") do
            table.insert(coords, match)
        end
        
        if #coords > 0 then
            local maxAttempts = 10
            for attempt = 1, maxAttempts do
                local target = coords[random():getInt(1, #coords)]
                local ox, oy = string.match(target, "(%-?%d+)_(%-?%d+)")
                ox, oy = tonumber(ox), tonumber(oy)
                tx = ox + random():getInt(-3, 3)
                ty = oy + random():getInt(-3, 3)
                
                local checkString = tx .. "_" .. ty .. ","
                if not string.find(territoryString, checkString, 1, true) then
                    break -- Valid target
                end
            end
        end

        -- Fallback: Random player known sector if no territory is held or random selection failed
        if not tx or not ty then
            local players = {Server():getOnlinePlayers()}
            if #players == 0 then return end
            local player = players[random():getInt(1, #players)]
            local knownSectors = {player:getKnownSectors()}
            if #knownSectors == 0 then return end
            local targetSector = knownSectors[random():getInt(1, #knownSectors)]
            tx, ty = targetSector:getCoordinates()
        end
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

            -- PROGRESSIVE MATERIALIZATION (Lag Fix)
            local pendingSieges = Server():getValue("eclipse_pending_sieges") or ""
            local entry = tx .. "_" .. ty .. ","
            if not string.find(pendingSieges, entry, 1, true) then
                Server():setValue("eclipse_pending_sieges", pendingSieges .. entry)
            end

            -- Increment counter since it's a conquest attempt that will turn the sector
            Server():setValue("eclipse_conquered_sectors", conqueredCount + 1)
            
            -- Track for geographic expansion
            local held = Server():getValue("eclipse_held_territory") or ""
            if not string.find(held, entry, 1, true) then
                Server():setValue("eclipse_held_territory", held .. entry)
            end
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

    -- PROGRESSIVE MATERIALIZATION (Lag Fix)
    -- Instead of forcefully loading the sector and causing CPU spikes, we append it to the pending list.
    local pending = Server():getValue("eclipse_pending_annihilations") or ""
    local entry = x .. "_" .. y .. ","
    if not string.find(pending, entry, 1, true) then
        Server():setValue("eclipse_pending_annihilations", pending .. entry)
    end
    
    -- Also track for geographic expansion
    local held = Server():getValue("eclipse_held_territory") or ""
    if not string.find(held, entry, 1, true) then
        Server():setValue("eclipse_held_territory", held .. entry)
    end
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

