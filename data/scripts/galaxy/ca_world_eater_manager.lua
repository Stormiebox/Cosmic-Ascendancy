package.path = package.path .. ";data/scripts/lib/?.lua"
include("stringutility")
include("callable")
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
        -- Once a player has actually reached the target sector and the fight is confirmed
        -- injected, the 20-minute countdown has done its job (the deadline was to REACH the
        -- World-Eater in time, not to kill it in time) -- so it must stop being able to fire
        -- executeDoomsday() out from under an in-progress fight. Without this, a fight that runs
        -- longer than whatever time happened to be left on the clock got its sector silently
        -- annihilated mid-battle, ending the encounter by deleting it instead of by winning or
        -- losing it -- unlike every other World-Eater encounter in the mod (the story boss, the
        -- player-summoned Raid Boss), neither of which carries any wipe timer once the fight
        -- has actually begun.
        if not WorldEaterManager.activeEvent.engaged then
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
                    Server():broadcastChatMessage("The Eclipse"%_T, 2, "WARNING: Doomsday weapon firing at [" .. tx .. ":" .. ty .. "] in " .. minsLeft .. " minute(s).")
                    for _, p in pairs({Server():getOnlinePlayers()}) do
                        p:addScriptOnce("data/scripts/player/ca_boss_audio_hook.lua")
                        p:invokeFunction("data/scripts/player/ca_boss_audio_hook.lua", "triggerCinematicBanner", "DOOMSDAY EVENT - " .. minsLeft .. " MINS", "data/sounds/siren.ogg")
                    end
                end
            end
        end

        -- Check if any player is in the targeted sector to inject the actual boss ship. Once this
        -- fires successfully, the encounter is "engaged" and the countdown above stops for good --
        -- cancelEvent() (called from ca_world_eater_event.lua's onWorldEaterDestroyed) is the only
        -- way this activeEvent ever clears from this point on, other than the abandonment backstop
        -- immediately below.
        if WorldEaterManager.activeEvent then
            local anyoneInSector = false
            for _, player in pairs({Server():getOnlinePlayers()}) do
                local px, py = player:getSectorCoordinates()
                if px == WorldEaterManager.activeEvent.x and py == WorldEaterManager.activeEvent.y then
                    anyoneInSector = true
                    if not WorldEaterManager.activeEvent.engaged then
                        WorldEaterManager.activeEvent.engaged = true
                        WorldEaterManager.injectSectorScript(px, py)
                    end
                end
            end

            -- Abandonment backstop: once engaged, the only normal exit is killing the boss -- if
            -- every defender leaves (or the boss is engaged but never actually reached, e.g. a
            -- stale save) and nobody returns for a long time, the encounter would otherwise block
            -- every future natural Doomsday Event for this galaxy forever. Track how long the
            -- target sector has been empty of players and force-cancel (no kill reward) once that
            -- exceeds 2 hours -- long enough to never interrupt a real fight with a normal amount of
            -- regrouping/refitting, short enough that one abandoned attempt doesn't lock the mechanic
            -- out indefinitely.
            if WorldEaterManager.activeEvent.engaged then
                if anyoneInSector then
                    WorldEaterManager.activeEvent.emptySince = nil
                else
                    WorldEaterManager.activeEvent.emptySince = WorldEaterManager.activeEvent.emptySince or Server().unpausedRuntime
                    if Server().unpausedRuntime - WorldEaterManager.activeEvent.emptySince > 7200 then
                        Server():broadcastChatMessage("The Eclipse"%_T, 0, "The abandoned World-Eater engagement has been stood down."%_T)
                        WorldEaterManager.activeEvent = nil
                        Server():setValue("eclipse_world_eater_grace_end", Server().unpausedRuntime + 36000)
                    end
                end
            end
        end
    else
        local graceEnd = Server():getValue("eclipse_world_eater_grace_end") or 0
        if Server().unpausedRuntime > graceEnd then
            if not WorldEaterManager.threshold then
                -- Eclipse Remnant Escalation: shrink the 3-5hr window by up to 15 minutes per
                -- Remnant Tier (up to 75 minutes at REMNANT_MAX_TIER=5, eclipsegenerator.lua),
                -- giving a real max-tier window of 1h45m-3h45m today. math.max's 1.5hr/2.5hr floors
                -- don't bind at the current tier cap -- they're headroom in case that cap is ever
                -- raised, not the value actually reached now.
                local EclipseGenerator = include("eclipsegenerator")
                local reduction = EclipseGenerator.getRemnantTier() * 900
                local minSeconds = math.max(5400, 10800 - reduction)
                local maxSeconds = math.max(9000, 18000 - reduction)
                WorldEaterManager.threshold = random():getInt(minSeconds, maxSeconds)
            end
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

    Server():broadcastChatMessage("Galactic News"%_T, 0, "CRITICAL ALERT: An Eclipse World-Eater has warped to coordinates [" .. tx .. ":" .. ty .. "]! 20 minutes to total annihilation!")
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

    Server():broadcastChatMessage("The Eclipse"%_T, 2, "Doomsday Sequence Complete. Sector [" .. tx .. ":" .. ty .. "] has been purged.")

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

    -- ca_delayed_annihilation.lua deliberately spares player/alliance-owned ships and stations --
    -- correct for the general Eclipse conquest/annihilation case it's shared with (matching the
    -- WIKI's own "player- and alliance-owned entities are never deleted by an Annihilation roll").
    -- But the World-Eater's own Doomsday failure is supposed to carry a real, personal stake for
    -- whoever failed to stop it in time ("player ships reduced to 1 HP"), so that consequence is
    -- applied here, separately and specifically to this path, rather than changing the shared
    -- script's asset-sparing behavior for every other Eclipse annihilation in the mod.
    local criticalCode = [[
        function run()
            local sector = Sector()
            if not sector then return end
            for _, entity in pairs({sector:getEntities()}) do
                if valid(entity) and entity.type == EntityType.Ship and (entity.playerOwned or entity.allianceOwned) then
                    entity.shieldDurability = 0
                    entity.durability = 1
                end
            end
        end
    ]]
    runSectorCode(tx, ty, true, criticalCode, "run")
end

function WorldEaterManager.cancelEvent()
    if not WorldEaterManager.activeEvent then return end
    local tx, ty = WorldEaterManager.activeEvent.x, WorldEaterManager.activeEvent.y
    WorldEaterManager.activeEvent = nil
    Server():setValue("eclipse_world_eater_grace_end", Server().unpausedRuntime + 36000)
    Server():broadcastChatMessage("Galactic News"%_T, 0, "The World-Eater has been destroyed! The galaxy enters a 10-hour Grace Period."%_T)

    -- Eclipse Remnant Escalation: cancelEvent() only ever fires from WorldEaterEvent.onWorldEaterDestroyed
    -- (confirmed the only caller), so this is a genuine kill, not an admin/debug cancel.
    Server():setValue("eclipse_world_eaters_killed", (Server():getValue("eclipse_world_eaters_killed") or 0) + 1)
    local EclipseGenerator = include("eclipsegenerator")
    EclipseGenerator.checkRemnantEscalation()

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

