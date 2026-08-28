package.path = package.path .. ";data/scripts/lib/?.lua"
include("stringutility")
local cv_news = include("cosmicvaultnews")

-- namespace WorldEaterManager
WorldEaterManager = {}
WorldEaterManager.timer = 0
WorldEaterManager.activeEvent = nil -- {x=x, y=y, timeLeft=900}

function WorldEaterManager.getUpdateInterval() return 30.0 end -- Check every 30s

function WorldEaterManager.initialize()
end

function WorldEaterManager.updateServer(timeStep)
    if not Server():getValue("eclipse_fully_awake") then return end

    -- Pause the Doomsday clock if no players are online (protects dedicated servers)
    local players = {Server():getOnlinePlayers()}
    if #players == 0 then return end

    if WorldEaterManager.activeEvent then
        WorldEaterManager.activeEvent.timeLeft = WorldEaterManager.activeEvent.timeLeft - timeStep

        if WorldEaterManager.activeEvent.timeLeft <= 0 then
            WorldEaterManager.executeDoomsday()
        else
            -- the update interval is 30s, meaning the check can overshoot the boundary window
            -- silently and never broadcast. Instead, track the last interval we broadcast at.
            -- We broadcast once per 5-minute (300s) interval by comparing the current interval
            -- index to the last one we announced.
            local tx = WorldEaterManager.activeEvent.x
            local ty = WorldEaterManager.activeEvent.y
            local timeLeft = WorldEaterManager.activeEvent.timeLeft
            local currentInterval = math.floor(timeLeft / 300) -- Which 5-min block are we in?
            local lastInterval = WorldEaterManager.activeEvent.lastWarningInterval or -1

            -- Fire exactly once when we enter each new 5-minute interval
            if currentInterval ~= lastInterval then
                WorldEaterManager.activeEvent.lastWarningInterval = currentInterval
                local minsLeft = math.ceil(timeLeft / 60)
                Server():broadcastChatMessage("The Eclipse", 2, "WARNING: Doomsday weapon firing at [" .. tx .. ":" .. ty .. "] in " .. minsLeft .. " minute(s).")
                for _, p in pairs({Server():getOnlinePlayers()}) do
                    p:addScriptOnce("data/scripts/player/ca_boss_audio_hook.lua")
                    p:invokeFunction("data/scripts/player/ca_boss_audio_hook.lua", "triggerCinematicBanner", "DOOMSDAY EVENT - " .. minsLeft .. " MINS", "data/sounds/siren.ogg")
                end
            end
        end

        -- Check if any player is in the targeted sector to inject the actual boss ship
        for _, player in pairs({Server():getOnlinePlayers()}) do
            local px, py = player:getSectorCoordinates()
            if px == WorldEaterManager.activeEvent.x and py == WorldEaterManager.activeEvent.y then
                WorldEaterManager.injectSectorScript(px, py)
            end
        end
    else
        local graceEnd = Server():getValue("eclipse_world_eater_grace_end") or 0
        if Server().unpausedRuntime > graceEnd then
            WorldEaterManager.threshold = WorldEaterManager.threshold or random():getInt(10800, 18000)
            WorldEaterManager.timer = WorldEaterManager.timer + timeStep
            if WorldEaterManager.timer > WorldEaterManager.threshold then
                WorldEaterManager.timer = 0
                WorldEaterManager.threshold = nil
                WorldEaterManager.triggerEvent()
            end
        end
    end
end

function WorldEaterManager.triggerEvent()
    local players = {Server():getOnlinePlayers()}
    if #players == 0 then return end

    local player = players[random():getInt(1, #players)]
    local knownSectors = {player:getKnownSectors()}
    if #knownSectors == 0 then return end

    local targetSector = nil
    local validSectors = {}
    for _, view in pairs(knownSectors) do
        if view and (view.stations or 0) > 0 then
            table.insert(validSectors, view)
        end
    end

    if #validSectors > 0 then
        targetSector = validSectors[random():getInt(1, #validSectors)]
    else
        targetSector = knownSectors[random():getInt(1, #knownSectors)]
    end
    
    local tx, ty = targetSector:getCoordinates()

    WorldEaterManager.activeEvent = {x = tx, y = ty, timeLeft = 1200}

    Server():broadcastChatMessage("Galactic News", 0, "CRITICAL ALERT: An Eclipse World-Eater has warped to coordinates [" .. tx .. ":" .. ty .. "]! 20 minutes to total annihilation!")
    if cv_news.publishArticle then
        cv_news.publishArticle({
            title = "CRITICAL: World-Eater Detected!",
            content = "A massive Eclipse super-structure has materialized at [" .. tx .. ":" .. ty .. "]. Energy signatures indicate it is charging a weapon capable of obliterating the entire sector. Forces have 20 minutes to intercept.",
            category = "Galactic Dread"
        })
    end

    -- If loaded, inject sector script
    if Galaxy():sectorLoaded(tx, ty) then
        WorldEaterManager.injectSectorScript(tx, ty)
    end
end

function WorldEaterManager.injectSectorScript(x, y)
    local timeLeft = WorldEaterManager.activeEvent and WorldEaterManager.activeEvent.timeLeft or 1200
    local code = [[
        function run(timeLeft)
            if not Sector():hasScript("events/ca_world_eater_event.lua") then
                Sector():addScriptOnce("data/scripts/events/ca_world_eater_event.lua", timeLeft)
            end
        end
    ]]
    runSectorCode(x, y, true, code, "run", timeLeft)
end

function WorldEaterManager.executeDoomsday()
    local tx = WorldEaterManager.activeEvent.x
    local ty = WorldEaterManager.activeEvent.y
    WorldEaterManager.activeEvent = nil
    Server():setValue("eclipse_world_eater_grace_end", Server().unpausedRuntime + 36000)

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

    local CosmicVaultEconomy = include("cosmicvaulteconomy")
    if CosmicVaultEconomy then
        local nearestFaction = Galaxy():getNearestFaction(tx, ty)
        if nearestFaction and nearestFaction.isAIFaction then
            CosmicVaultEconomy.addFamineScore(nearestFaction.index, 250)
        end
        CosmicVaultEconomy.TriggerMarketEvent("All", 0, -50, 10, "crash")
    end

    -- Safely execute sector annihilation via local sector thread
    local code = [[
        function run()
            Sector():setValue("eclipse_wiped_graveyard", true)
            if not Sector():hasScript("sector/ca_delayed_annihilation.lua") then
                Sector():addScriptOnce("data/scripts/sector/ca_delayed_annihilation.lua")
            end
        end
    ]]
    runSectorCode(tx, ty, true, code, "run")
end

function WorldEaterManager.cancelEvent()
    if not WorldEaterManager.activeEvent then return end
    local tx, ty = WorldEaterManager.activeEvent.x, WorldEaterManager.activeEvent.y
    WorldEaterManager.activeEvent = nil
    Server():setValue("eclipse_world_eater_grace_end", Server().unpausedRuntime + 36000)
    Server():broadcastChatMessage("Galactic News", 0, "The World-Eater has been destroyed! The galaxy enters a 10-hour Grace Period.")

    if cv_news.publishArticle then
        cv_news.publishArticle({
            title = "World-Eater Destroyed!",
            content = "Heroic forces have obliterated the Eclipse World-Eater, preventing the destruction of the sector. The Eclipse has retreated, granting the galaxy a 10-hour Grace Period.",
            category = "Heroic Victories"
        })
    end

    local reward = 50000000
    for _, player in pairs({Server():getOnlinePlayers()}) do
        local px, py = player:getSectorCoordinates()
        if px == tx and py == ty then
            player:receive("Received %1% Credits for destroying the World-Eater!"%_T, reward)
            player:invokeFunction("data/scripts/player/ca_boss_audio_hook.lua", "triggerStopBossMusic")
        end
    end
end

function WorldEaterManager.secure()
    return {
        activeEvent = WorldEaterManager.activeEvent,
        timer = WorldEaterManager.timer,
        threshold = WorldEaterManager.threshold
    }
end

function WorldEaterManager.restore(data)
    if data then
        if data.x then
            -- Old save format: data itself is the activeEvent
            WorldEaterManager.activeEvent = data
            WorldEaterManager.timer = 0
        else
            -- New save format
            WorldEaterManager.activeEvent = data.activeEvent
            WorldEaterManager.timer = data.timer or 0
            WorldEaterManager.threshold = data.threshold
        end
    end
end

callable(WorldEaterManager, "cancelEvent")

