package.path = package.path .. ";data/scripts/lib/?.lua"
local cv_news = include("cosmicvaultnews")

local WorldEaterManager = {}
WorldEaterManager.timer = 0
WorldEaterManager.activeEvent = nil -- {x=x, y=y, timeLeft=900}

function WorldEaterManager.getUpdateInterval() return 30.0 end -- Check every 30s

function WorldEaterManager.initialize()
end

function WorldEaterManager.updateServer(timeStep)
    if not Server():getValue("eclipse_fully_awake") then return end

    if WorldEaterManager.activeEvent then
        WorldEaterManager.activeEvent.timeLeft = WorldEaterManager.activeEvent.timeLeft - timeStep

        if WorldEaterManager.activeEvent.timeLeft <= 0 then
            WorldEaterManager.executeDoomsday()
        elseif WorldEaterManager.activeEvent.timeLeft % 300 < 30 then
            -- Broadcast warning around every 5 minutes
            local tx = WorldEaterManager.activeEvent.x
            local ty = WorldEaterManager.activeEvent.y
            Server():broadcastChatMessage("The Eclipse", 2, "WARNING: Doomsday weapon firing at [" .. tx .. ":" .. ty .. "] in " .. math.floor(WorldEaterManager.activeEvent.timeLeft / 60) .. " minutes.")
        end

        -- Check if any player is in the sector to inject the actual boss
        for _, player in pairs({Server():getPlayers()}) do
            local px, py = player:getSectorCoordinates()
            if px == WorldEaterManager.activeEvent.x and py == WorldEaterManager.activeEvent.y then
                WorldEaterManager.injectSectorScript(px, py)
            end
        end
    else
        WorldEaterManager.timer = WorldEaterManager.timer + timeStep
        if WorldEaterManager.timer > random():getInt(7200, 10800) then -- 2 to 3 hours
            WorldEaterManager.timer = 0
            WorldEaterManager.triggerEvent()
        end
    end
end

function WorldEaterManager.triggerEvent()
    local players = {Server():getPlayers()}
    if #players == 0 then return end

    local player = players[random():getInt(1, #players)]
    local knownSectors = {player:getKnownSectors()}
    if #knownSectors == 0 then return end

    local targetSector = knownSectors[random():getInt(1, #knownSectors)]
    local tx, ty = targetSector.x, targetSector.y

    WorldEaterManager.activeEvent = {x = tx, y = ty, timeLeft = 900}

    Server():broadcastChatMessage("Galactic News", 0, "CRITICAL ALERT: An Eclipse World-Eater has warped to coordinates [" .. tx .. ":" .. ty .. "]! 15 minutes to total annihilation!")
    if cv_news.publishArticle then
        cv_news.publishArticle({
            title = "CRITICAL: World-Eater Detected!",
            content = "A massive Eclipse super-structure has materialized at [" .. tx .. ":" .. ty .. "]. Energy signatures indicate it is charging a weapon capable of obliterating the entire sector. Forces have 15 minutes to intercept.",
            category = "Galactic Dread"
        })
    end

    -- If loaded, inject sector script
    local sector = Sector()
    if sector and sector:getCoordinates() == tx and sector:getCoordinates() == ty then
        WorldEaterManager.injectSectorScript(tx, ty)
    end
end

function WorldEaterManager.injectSectorScript(x, y)
    local sector = Sector()
    if not sector then return end
    if not sector:hasScript("events/ca_world_eater_event.lua") then
        sector:addScript("data/scripts/events/ca_world_eater_event.lua", WorldEaterManager.activeEvent.timeLeft)
    end
end

function WorldEaterManager.executeDoomsday()
    local tx = WorldEaterManager.activeEvent.x
    local ty = WorldEaterManager.activeEvent.y
    WorldEaterManager.activeEvent = nil

    local EclipseGenerator = include("eclipsegenerator")
    local eclipseFaction = EclipseGenerator.getFaction()

    Server():broadcastChatMessage("The Eclipse", 2, "Doomsday Sequence Complete. Sector [" .. tx .. ":" .. ty .. "] has been purged.")

    if cv_news.publishArticle then
        cv_news.publishArticle({
            title = "DOOMSDAY: Sector [" .. tx .. ":" .. ty .. "] Erased",
            content = "The World-Eater has fired. Trillions are dead. There is nothing left but dust and dark matter.",
            category = "Galactic Dread"
        })
    end

    local galaxy = Galaxy()
    galaxy:setFaction(tx, ty, eclipseFaction.index)

    local sector = Sector()
    if sector then
        local cx, cy = sector:getCoordinates()
        if cx == tx and cy == ty then
            local entities = {sector:getEntities()}
            for _, entity in pairs(entities) do
                if entity.factionIndex ~= eclipseFaction.index and not entity.isPlayer then
                    sector:deleteEntity(entity)
                elseif entity.isPlayer then
                    entity.durability = 1
                end
            end
        end
    end
end

function WorldEaterManager.cancelEvent()
    if not WorldEaterManager.activeEvent then return end
    WorldEaterManager.activeEvent = nil
    Server():broadcastChatMessage("Galactic News", 0, "The World-Eater has been destroyed! The sector is safe.")

    if cv_news.publishArticle then
        cv_news.publishArticle({
            title = "World-Eater Destroyed!",
            content = "Heroic forces have obliterated the Eclipse World-Eater, preventing the destruction of the sector.",
            category = "Heroic Victories"
        })
    end
end
callable(WorldEaterManager, "cancelEvent")

function WorldEaterManager.secure()
    return WorldEaterManager.activeEvent
end

function WorldEaterManager.restore(data)
    WorldEaterManager.activeEvent = data
end

function getUpdateInterval(...)
    if WorldEaterManager.getUpdateInterval then return WorldEaterManager.getUpdateInterval(...) end
end
function initialize(...)
    if WorldEaterManager.initialize then return WorldEaterManager.initialize(...) end
end
function updateServer(...)
    if WorldEaterManager.updateServer then return WorldEaterManager.updateServer(...) end
end
function secure(...)
    if WorldEaterManager.secure then return WorldEaterManager.secure(...) end
end
function restore(...)
    if WorldEaterManager.restore then return WorldEaterManager.restore(...) end
end
