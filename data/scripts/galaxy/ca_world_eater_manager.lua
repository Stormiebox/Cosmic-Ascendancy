package.path = package.path .. ";data/scripts/lib/?.lua"
include("stringutility")
include("data/scripts/lib/callable")
local CosmicAscendancyNews = include("ca_news")
local CosmicVaultData = include("cosmicvaultdata")
local EncounterBridge = include("ca_encounter_bridge")
local OWNER = "data/scripts/galaxy/ca_world_eater_manager.lua"

-- namespace WorldEaterManager
WorldEaterManager = {}
WorldEaterManager.timer = 0
WorldEaterManager.activeEvent = nil -- {x=x, y=y, timeLeft=900}

local function publishWorldEaterStatus(event, encounter, engaged)
    if not event or not encounter then return end
    local title = engaged and "CRITICAL: World-Eater Materialized!"
        or "CRITICAL: World-Eater Signature Detected!"
    local content
    if engaged then
        content = "The Eclipse World-Eater has materialized and been verified at ["
            .. event.x .. ":" .. event.y .. "]. The doomsday countdown stopped when defenders engaged it."
    else
        content = "A massive Eclipse signature has been detected at [" .. event.x .. ":"
            .. event.y .. "]. The source is preparing a sector-annihilation weapon; forces have 20 minutes to reach it."
    end
    CosmicAscendancyNews.Upsert({
        kind = "encounter",
        eventId = event.encounterId,
        threadId = event.encounterId,
        eventType = "ascendancy.world_eater.active",
        topic = "threat",
        severity = "critical",
        breaking = true,
        location = {x = event.x, y = event.y, radius = 0},
        expiresAt = engaged and nil or encounter.deadlineAt,
        recordType = "ca_encounters_v1",
        recordId = event.encounterId,
        sourceRevision = encounter.revision or 1,
        sourceState = encounter.state,
        article = {title = title, content = content, category = "Galactic Dread"},
    })
end

local function publishDoomsdayQueued(encounterId, annihilationId, x, y, sourceRevision)
    CosmicAscendancyNews.Resolve("encounter", encounterId,
        "The World-Eater's deadline elapsed and its annihilation sequence was dispatched.")
    CosmicAscendancyNews.Publish({
        kind = "encounter",
        eventId = encounterId .. ":doomsday",
        threadId = encounterId,
        eventType = "ascendancy.world_eater.doomsday_dispatched",
        topic = "threat",
        severity = "critical",
        breaking = true,
        location = {x = x, y = y, radius = 0},
        recordType = "ca_receipts_v1",
        recordId = encounterId .. ":doomsday",
        sourceRevision = sourceRevision or 1,
        sourceState = "succeeded",
        provenance = {
            recordType = "ca_receipts_v1",
            recordId = tostring(encounterId .. ":doomsday"),
            encounterId = tostring(encounterId),
            annihilationEncounterId = tostring(annihilationId or "unknown"),
            sourceRevision = sourceRevision or 1,
            sourceState = "succeeded",
        },
        article = {
            title = "DOOMSDAY: Annihilation Sequence Dispatched",
            content = "The World-Eater has fired at sector [" .. x .. ":" .. y
                .. "]. An annihilation operation is now queued for materialization; final sector-state confirmation is pending.",
            category = "Galactic Dread",
        },
    })
end

local function publishWorldEaterVictory(event, encounter)
    if not event or not encounter then return end
    CosmicAscendancyNews.Resolve("encounter", event.encounterId,
        "The verified World-Eater was destroyed by participating defenders.")
    CosmicAscendancyNews.Publish({
        kind = "encounter",
        eventId = event.encounterId .. ":victory",
        threadId = event.encounterId,
        eventType = "ascendancy.world_eater.destroyed",
        topic = "conflict",
        severity = "info",
        location = {x = event.x, y = event.y, radius = 0},
        recordType = "ca_encounters_v1",
        recordId = event.encounterId,
        sourceRevision = encounter.revision or 1,
        sourceState = "succeeded",
        article = {
            title = "World-Eater Destroyed!",
            content = "Heroic forces have obliterated the Eclipse World-Eater, preventing the destruction of the sector. The Eclipse has retreated, granting the galaxy a 10-hour Grace Period.",
            category = "Heroic Victories",
        },
    })
end

function WorldEaterManager.getUpdateInterval() return 30.0 end -- Check every 30s

function WorldEaterManager.initialize()
end

function WorldEaterManager.updateServer(timeStep)
    local canonical = CosmicVaultData.GetRecord(Server(), "ca_state_v2", 2)
    if not canonical or canonical.eclipse.state ~= "fully_awake" then return end

    if WorldEaterManager.activeEvent and not WorldEaterManager.activeEvent.encounterId then
        local legacy = WorldEaterManager.activeEvent
        local legacyId = EncounterBridge.MakeId("natural_world_eater", "galaxy",
            legacy.x, legacy.y, "legacy")
        local migrated = EncounterBridge.Create(OWNER, {
            encounterId = legacyId,
            kind = "natural_world_eater",
            concurrencyKey = "natural_world_eater:galaxy",
            scope = "galaxy",
            x = legacy.x,
            y = legacy.y,
            state = "repair_required",
            repairRequired = "legacy_world_eater_correlation_unverified"
        })
        if migrated then
            legacy.encounterId = legacyId
            legacy.repairRequired = "legacy_world_eater_correlation_unverified"
        end
        return
    end

    -- Pause the Doomsday clock if no players are online (protects dedicated servers)
    local players = {Server():getOnlinePlayers()}
    if #players == 0 then return end

    if WorldEaterManager.activeEvent then
        local registered = EncounterBridge.Get(WorldEaterManager.activeEvent.encounterId)
        if registered and registered.state == "resolving" then
            WorldEaterManager.resolveEvent(WorldEaterManager.activeEvent.encounterId,
                WorldEaterManager.activeEvent.entityId)
            return
        elseif registered and registered.state == "succeeded" then
            local recorded = WorldEaterManager.recordOutcome(
                WorldEaterManager.activeEvent.encounterId, "world_eater_succeeded")
            if recorded then
                publishWorldEaterVictory(WorldEaterManager.activeEvent, registered)
                WorldEaterManager.activeEvent = nil
            end
            return
        elseif registered and registered.state == "abandoned" then
            local recorded = WorldEaterManager.recordOutcome(
                WorldEaterManager.activeEvent.encounterId, "world_eater_abandoned")
            if recorded then
                local receiptRegistry = CosmicVaultData.GetRecord(Server(), "ca_receipts_v1", 1)
                local operationId = WorldEaterManager.activeEvent.encounterId .. ":doomsday"
        local receipt = receiptRegistry and receiptRegistry.receipts
            and receiptRegistry.receipts[operationId]
                if receipt and receipt.state == "succeeded" then
                    publishDoomsdayQueued(WorldEaterManager.activeEvent.encounterId,
                        receipt.evidence and receipt.evidence.annihilationEncounterId,
                        WorldEaterManager.activeEvent.x, WorldEaterManager.activeEvent.y,
                        receipt.revision or 1)
                else
                    CosmicAscendancyNews.Resolve("encounter",
                        WorldEaterManager.activeEvent.encounterId,
                        "The World-Eater encounter was abandoned without a verified victory.")
                end
                WorldEaterManager.activeEvent = nil
            end
            return
        elseif registered and registered.state == "repair_required" then
            return
        end
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
                    if not WorldEaterManager.activeEvent.engaged
                            and not WorldEaterManager.activeEvent.materializing then
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
                        local abandoned = WorldEaterManager.activeEvent
                        local transitioned = EncounterBridge.Transition(OWNER, abandoned.encounterId, "abandoned", {
                            resolution = {reason = "empty_sector_timeout", at = Server().unpausedRuntime}
                        })
                        local recorded = transitioned and WorldEaterManager.recordOutcome(
                            abandoned.encounterId, "world_eater_abandoned")
                        if recorded then
                            CosmicAscendancyNews.Resolve("encounter", abandoned.encounterId,
                                "The engaged World-Eater was abandoned after the target sector remained empty for two hours.")
                            WorldEaterManager.activeEvent = nil
                        end
                    end
                end
            end

            if WorldEaterManager.activeEvent and WorldEaterManager.activeEvent.materializing
                    and Server().unpausedRuntime - WorldEaterManager.activeEvent.materializingAt > 60 then
                WorldEaterManager.reportMaterializationFailure(
                    WorldEaterManager.activeEvent.encounterId, "materialization_confirmation_timeout")
            end
        end
    else
        local graceEnd = canonical.timers.worldEaterGraceUntil or 0
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

    local encounterId = EncounterBridge.MakeId(
        "natural_world_eater", "galaxy", tx, ty, math.floor(Server().unpausedRuntime))
    local encounter, encounterError = EncounterBridge.Create(OWNER, {
        encounterId = encounterId,
        kind = "natural_world_eater",
        concurrencyKey = "natural_world_eater:galaxy",
        scope = "galaxy",
        x = tx,
        y = ty,
        deadlineAt = Server().unpausedRuntime + 1200,
        state = "prepared"
    })
    if not encounter then
        print("[Cosmic Ascendancy] Unable to prepare natural World-Eater: " .. tostring(encounterError))
        return
    end

    WorldEaterManager.activeEvent = {
        encounterId = encounterId, x = tx, y = ty, timeLeft = 1200,
        spawnAttempts = 0, materializing = false
    }

    Server():broadcastChatMessage("Galactic News"%_T, 0, "CRITICAL ALERT: An Eclipse World-Eater has warped to coordinates [" .. tx .. ":" .. ty .. "]! 20 minutes to total annihilation!")
    publishWorldEaterStatus(WorldEaterManager.activeEvent, encounter, false)

    -- If loaded, inject sector script
    if Galaxy():sectorLoaded(tx, ty) then
        WorldEaterManager.injectSectorScript(tx, ty)
    end
end

function WorldEaterManager.injectSectorScript(x, y)
    if not WorldEaterManager.activeEvent then return end
    local event = WorldEaterManager.activeEvent
    local encounter = EncounterBridge.Get(event.encounterId)
    if encounter and encounter.state == "retryable" then
        local prepared = EncounterBridge.Transition(OWNER, event.encounterId, "prepared")
        if not prepared then return end
    end
    event.spawnAttempts = (event.spawnAttempts or 0) + 1
    event.materializing = true
    event.materializingAt = Server().unpausedRuntime
    local timeLeft = WorldEaterManager.activeEvent and WorldEaterManager.activeEvent.timeLeft or 1200
    local code = [[
        function run(timeLeft, encounterId)
            if not Sector():hasScript("events/ca_world_eater_event.lua") then
                Sector():addScriptOnce("data/scripts/events/ca_world_eater_event.lua", timeLeft, encounterId)
            end
        end
    ]]
    runSectorCode(x, y, true, code, "run", timeLeft, event.encounterId)
end

function WorldEaterManager.confirmEngaged(encounterId, bossId)
    local event = WorldEaterManager.activeEvent
    if not event or event.encounterId ~= encounterId or type(bossId) ~= "string" then
        return nil, "encounter_mismatch"
    end
    local existing = EncounterBridge.Get(encounterId)
    local activated, err
    if existing and existing.state == "active" and existing.entityId == bossId then
        activated = existing
    else
        activated, err = EncounterBridge.Transition(OWNER, encounterId, "active", {
            entityId = bossId,
            engagedAt = Server().unpausedRuntime
        })
    end
    if not activated then return nil, err end
    event.entityId = bossId
    event.engaged = true
    event.materializing = false
    event.engagedAt = Server().unpausedRuntime
    publishWorldEaterStatus(event, activated, true)
    return true, nil
end

function WorldEaterManager.reportMaterializationFailure(encounterId, errorText)
    local event = WorldEaterManager.activeEvent
    if not event or event.encounterId ~= encounterId or event.engaged then
        return nil, "encounter_mismatch"
    end
    event.materializing = false
    if (event.spawnAttempts or 0) >= 5 then
        event.repairRequired = "world_eater_materialization_failed"
        local repaired, repairError = EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
            lastError = errorText or "spawn_failed"
        })
        if repaired then
            CosmicAscendancyNews.Upsert({
                kind = "encounter",
                eventId = encounterId,
                threadId = encounterId,
                eventType = "ascendancy.world_eater.active",
                topic = "threat",
                severity = "warning",
                location = {x = event.x, y = event.y, radius = 0},
                recordType = "ca_encounters_v1",
                recordId = encounterId,
                sourceRevision = repaired.revision or 1,
                sourceState = "repair_required",
                article = {
                    title = "World-Eater Signal Requires Investigation",
                    content = "The Eclipse signature at [" .. event.x .. ":" .. event.y
                        .. "] could not be materialized after five attempts. No victory or destruction has been inferred; administrator review is required.",
                    category = "Galactic Dread",
                },
            })
        end
        return repaired, repairError
    end
    return EncounterBridge.Transition(OWNER, encounterId, "retryable", {
        lastError = errorText or "spawn_failed"
    })
end

function WorldEaterManager.reportMissingBoss(encounterId, bossId)
    local event = WorldEaterManager.activeEvent
    if not event or event.encounterId ~= encounterId or event.entityId ~= bossId then
        return nil, "encounter_mismatch"
    end
    event.repairRequired = "engaged_world_eater_missing"
    local repaired, repairError = EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
        lastError = "loaded_sector_missing_registered_boss"
    })
    if repaired then
        CosmicAscendancyNews.Upsert({
            kind = "encounter",
            eventId = encounterId,
            threadId = encounterId,
            eventType = "ascendancy.world_eater.active",
            topic = "threat",
            severity = "warning",
            location = {x = event.x, y = event.y, radius = 0},
            recordType = "ca_encounters_v1",
            recordId = encounterId,
            sourceRevision = repaired.revision or 1,
            sourceState = "repair_required",
            article = {
                title = "World-Eater Correlation Lost",
                content = "The registered World-Eater at [" .. event.x .. ":" .. event.y
                    .. "] is missing from its loaded sector. No victory has been inferred; administrator review is required.",
                category = "Galactic Dread",
            },
        })
    end
    return repaired, repairError
end

function WorldEaterManager.executeDoomsday()
    if not WorldEaterManager.activeEvent then return nil, "missing_active_event" end
    local tx = WorldEaterManager.activeEvent.x
    local ty = WorldEaterManager.activeEvent.y
    local encounterId = WorldEaterManager.activeEvent.encounterId
    local operationId = encounterId .. ":doomsday"
    local receiptRegistry = CosmicVaultData.GetRecord(Server(), "ca_receipts_v1", 1)
    local existingReceipt = receiptRegistry and receiptRegistry.receipts[operationId]

    if existingReceipt and existingReceipt.state == "prepared" then
        EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
            lastError = "doomsday_side_effects_ambiguous_after_restart"
        })
        return nil, "doomsday_side_effects_ambiguous_after_restart"
    end

    if existingReceipt and existingReceipt.state == "succeeded" then
        local encounter = EncounterBridge.Get(encounterId)
        if encounter and encounter.state ~= "abandoned" then
            local abandoned, abandonError = EncounterBridge.Transition(OWNER, encounterId, "abandoned", {
                resolution = {reason = "deadline_elapsed", x = tx, y = ty}
            })
            if not abandoned then return nil, abandonError end
        end
        local recorded, recordError = WorldEaterManager.recordOutcome(
            encounterId, "world_eater_abandoned")
        if not recorded then return nil, recordError end
        local annihilationId = existingReceipt.evidence
            and existingReceipt.evidence.annihilationEncounterId or nil
        publishDoomsdayQueued(encounterId, annihilationId, tx, ty,
            existingReceipt.revision or 1)
        WorldEaterManager.activeEvent = nil
        return true, nil
    end

    if existingReceipt then return nil, "invalid_doomsday_receipt_state" end
    local prepared, prepareError = EncounterBridge.PrepareReceipt(OWNER, {
        operationId = operationId,
        kind = "world_eater_doomsday",
        encounterId = encounterId,
        recipient = {scope = "sector", x = tx, y = ty},
        reissue = {mode = "none"}
    })
    if not prepared then
        EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
            lastError = "doomsday_receipt_prepare_failed:" .. tostring(prepareError)
        })
        return nil, prepareError
    end

    Server():broadcastChatMessage("The Eclipse"%_T, 2,
        "Doomsday Sequence Complete. Annihilation has been dispatched toward sector ["
            .. tx .. ":" .. ty .. "].")

    local CosmicVaultEconomy = include("cosmicvaulteconomy")
    if CosmicVaultEconomy then
        local nearestFaction = Galaxy():getNearestFaction(tx, ty)
        if nearestFaction and nearestFaction.isAIFaction then
            CosmicVaultEconomy.addFamineScore(nearestFaction.index, 250)
        end
        CosmicVaultEconomy.TriggerMarketEvent("All", tx, ty, 10, "crash")
    end

    local CosmicVaultTerritory = include("cosmicvaultterritory")
    local annihilationId = EncounterBridge.MakeId("annihilation", "sector", tx, ty,
        encounterId)
    local annihilation = EncounterBridge.Create(OWNER, {
        encounterId = annihilationId, kind = "annihilation",
        concurrencyKey = "annihilation:" .. tx .. ":" .. ty,
        scope = "sector", x = tx, y = ty, state = "prepared",
        sourceEncounterId = encounterId
    })
    if annihilation then
        local queued, queueError = CosmicVaultTerritory.QueueMaterialization("annihilation", tx, ty, {
            source = "natural_world_eater", encounterId = annihilationId,
            sourceEncounterId = encounterId, criticalPlayerShips = true
        })
        if not queued then
            EncounterBridge.Transition(OWNER, annihilationId, "repair_required", {
                lastError = "annihilation_queue_failed:" .. tostring(queueError)})
            EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
                lastError = "doomsday_annihilation_queue_failed:" .. tostring(queueError)})
            return nil, queueError
        end
    else
        EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
            lastError = "doomsday_annihilation_encounter_prepare_failed"
        })
        return nil, "annihilation_encounter_prepare_failed"
    end

    local completed, completionError = EncounterBridge.CompleteReceipt(OWNER, operationId, {
        famineScore = 250, marketCrash = true, annihilationEncounterId = annihilationId,
        criticalPlayerShips = true
    })
    if not completed then
        EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
            lastError = "doomsday_receipt_completion_ambiguous"
        })
        return nil, completionError
    end
    local abandoned, abandonError = EncounterBridge.Transition(OWNER, encounterId, "abandoned", {
        resolution = {reason = "deadline_elapsed", x = tx, y = ty}
    })
    if not abandoned then return nil, abandonError end
    local recorded, recordError = WorldEaterManager.recordOutcome(encounterId, "world_eater_abandoned")
    if not recorded then return nil, recordError end
    publishDoomsdayQueued(encounterId, annihilationId, tx, ty,
        completed.revision or abandoned.revision or 1)
    WorldEaterManager.activeEvent = nil
    return true, nil
end

function WorldEaterManager.recordOutcome(encounterId, outcome)
    local resultCode, stateRevisions = Galaxy():invokeFunction(
        "data/scripts/galaxy/ca_state_coordinator.lua", "getRegistryRevisions")
    if resultCode ~= 0 or not stateRevisions then return nil, "coordinator_unavailable" end
    local code, revision, err = Galaxy():invokeFunction(
        "data/scripts/galaxy/ca_state_coordinator.lua", "requestEncounterOutcome",
        OWNER, stateRevisions.state, encounterId, outcome,
        {graceUntil = Server().unpausedRuntime + 36000})
    if code ~= 0 then return nil, "coordinator_unavailable" end
    return revision, err
end

function WorldEaterManager.resolveEvent(encounterId, bossId)
    if not WorldEaterManager.activeEvent then return nil, "missing_active_event" end
    if WorldEaterManager.activeEvent.encounterId ~= encounterId
            or WorldEaterManager.activeEvent.entityId ~= bossId
            or not WorldEaterManager.activeEvent.engaged then return nil, "encounter_mismatch" end
    local tx, ty = WorldEaterManager.activeEvent.x, WorldEaterManager.activeEvent.y
    local registered = EncounterBridge.Get(encounterId)
    local participants = {}
    if registered and registered.state == "resolving" then
        for _, playerIndex in ipairs(registered.participants or {}) do
            table.insert(participants, playerIndex)
        end
    else
        for _, player in pairs({Server():getOnlinePlayers()}) do
            local px, py = player:getSectorCoordinates()
            if px == tx and py == ty then table.insert(participants, player.index) end
        end
        table.sort(participants)
        local resolving, resolvingError = EncounterBridge.Transition(OWNER, encounterId, "resolving", {
            participants = participants,
            resolution = {reason = "boss_destroyed", entityId = bossId}
        })
        if not resolving then return nil, resolvingError end
    end

    local reward = 50000000
    for _, playerIndex in ipairs(participants) do
        local player = Player(playerIndex)
        local operationId = encounterId .. ":player:" .. tostring(playerIndex) .. ":reward"
        local receiptRegistry = CosmicVaultData.GetRecord(Server(), "ca_receipts_v1", 1)
        local existingReceipt = receiptRegistry and receiptRegistry.receipts[operationId]
        if not existingReceipt then
            local receipt, receiptRevision = EncounterBridge.PrepareReceipt(OWNER, {
                operationId = operationId,
                kind = "natural_world_eater_reward",
                recipient = {playerIndex = playerIndex},
                encounterId = encounterId,
                reissue = {mode = "coordinator_credit", credits = reward,
                    reason = "World-Eater Reward"}
            })
            if not receipt then return nil, receiptRevision end
            local before = player.money or 0
            player:receive("Received %1% Credits for destroying the World-Eater!"%_T, reward)
            if (player.money or 0) < before + reward then
                EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
                    lastError = "reward_delivery_unverified:" .. operationId
                })
                return nil, "reward_delivery_unverified"
            end
            local completed, completionError = EncounterBridge.CompleteReceipt(OWNER, operationId, {
                credits = reward, before = before, after = player.money
            })
            if not completed then
                EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
                    lastError = "reward_receipt_completion_ambiguous:" .. operationId
                })
                return nil, completionError
            end
            player:invokeFunction("data/scripts/player/ca_boss_audio_hook.lua", "triggerStopBossMusic")
        elseif existingReceipt.state == "prepared" and existingReceipt.reissueAuthorized == true then
            local before = player.money or 0
            player:receive("Received %1% Credits for destroying the World-Eater!"%_T, reward)
            if (player.money or 0) < before + reward then return nil, "reward_delivery_unverified" end
            local completed, completionError = EncounterBridge.CompleteReceipt(OWNER, operationId, {
                credits = reward, before = before, after = player.money,
                administratorReissue = true
            })
            if not completed then return nil, completionError end
        elseif existingReceipt.state == "abandoned" then
            -- An administrator explicitly chose to finish the encounter without this reward.
        elseif existingReceipt.state ~= "succeeded" then
            EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
                lastError = "prepared_reward_delivery_ambiguous:" .. operationId
            })
            return nil, "prepared_reward_delivery_ambiguous"
        end
    end

    local recorded, recordError = WorldEaterManager.recordOutcome(
        encounterId, "world_eater_succeeded")
    if not recorded then
        EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
            lastError = "world_eater_outcome_persistence_failed:" .. tostring(recordError)
        })
        return nil, recordError
    end
    local succeeded, succeededError = EncounterBridge.Transition(OWNER, encounterId, "succeeded", {
        participants = participants,
        resolution = {reason = "boss_destroyed", entityId = bossId, rewardCount = #participants}
    })
    if not succeeded then return nil, succeededError end
    WorldEaterManager.activeEvent = nil
    Server():broadcastChatMessage("Galactic News"%_T, 0, "The World-Eater has been destroyed! The galaxy enters a 10-hour Grace Period."%_T)
    local EclipseGenerator = include("eclipsegenerator")
    EclipseGenerator.checkRemnantEscalation()

    publishWorldEaterVictory({encounterId = encounterId, x = tx, y = ty}, succeeded)

    return true, nil
end

function WorldEaterManager.cancelEvent(encounterId, bossId)
    return WorldEaterManager.resolveEvent(encounterId, bossId)
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
callable(WorldEaterManager, "confirmEngaged")
callable(WorldEaterManager, "reportMaterializationFailure")
callable(WorldEaterManager, "reportMissingBoss")
callable(WorldEaterManager, "resolveEvent")

