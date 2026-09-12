package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

-- =========================================================================
-- COSMIC ASCENDANCY: DELAYED SECTOR ANNIHILATION WIPER
-- =========================================================================
-- This script is attached to unloaded sectors by the Galaxy conquest manager.
-- When a player finally visits this sector, this script boots up, physically
-- annihilates all entities, applies Dark Matter Fog, and terminates.
-- =========================================================================

include("stringutility")
local CosmicVaultTerritory = include("cosmicvaultterritory")
local CosmicVaultData = include("cosmicvaultdata")
local EncounterBridge = include("ca_encounter_bridge")
local OWNER = "data/scripts/sector/ca_delayed_annihilation.lua"

local function completeEncounter(encounterId, resolution)
    if not encounterId then return true end
    local encounter = EncounterBridge.Get(encounterId)
    if not encounter then return nil, "missing_encounter" end
    if encounter.state == "succeeded" then return true end
    if encounter.state == "materializing" then
        local resolving, resolvingError = EncounterBridge.Transition(
            OWNER, encounterId, "resolving", {resolution = resolution})
        if not resolving then return nil, resolvingError end
        encounter = resolving
    end
    if encounter.state ~= "resolving" then return nil, "invalid_encounter_state" end
    local succeeded, succeededError = EncounterBridge.Transition(
        OWNER, encounterId, "succeeded", {resolution = resolution})
    if not succeeded then
        EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
            lastError = "annihilation_terminal_transition_failed"
        })
        return nil, succeededError
    end
    return true
end

function initialize(kind, queueX, queueY, claimant, queueId, queueCreatedAt, encounterId,
        criticalPlayerShips)
    if onServer() then
        local sector = Sector()
        local receiptKey = "ca_annihilation_receipt"
        local queueReceipt = queueId and (queueId .. ":" .. tostring(queueCreatedAt or 0)) or nil
        if encounterId then
            local encounter = EncounterBridge.Get(encounterId)
            if encounter and encounter.state == "retryable" then
                local prepared = EncounterBridge.Transition(
                    OWNER, encounterId, "prepared", {x = queueX, y = queueY})
                if not prepared then
                    if queueId then CosmicVaultTerritory.RetryMaterialization(
                        kind, queueX, queueY, claimant, "encounter_prepare_failed", 60) end
                    terminate()
                    return
                end
                encounter = EncounterBridge.Get(encounterId)
            end
            if encounter and encounter.state == "prepared" then
                local materializing = EncounterBridge.Transition(
                    OWNER, encounterId, "materializing", {x = queueX, y = queueY})
                if not materializing then
                    if queueId then CosmicVaultTerritory.RetryMaterialization(
                        kind, queueX, queueY, claimant, "encounter_materialization_failed", 60) end
                    terminate()
                    return
                end
                encounter = materializing
            end
            if not encounter or encounter.state ~= "materializing" then
                if queueId then CosmicVaultTerritory.RequireMaterializationRepair(
                    kind, queueX, queueY, claimant, "annihilation_encounter_correlation_failed") end
                terminate()
                return
            end
        end
        if queueReceipt and sector:getValue(receiptKey) == queueReceipt then
            local queueCompleted = CosmicVaultTerritory.CompleteMaterialization(
                kind, queueX, queueY, claimant, {
                sectorReceipt = queueId, verified = true
            })
            if queueCompleted then
                completeEncounter(encounterId, {
                    reason = "recovered_sector_receipt", queueId = queueId
                })
            end
            terminate()
            return
        end
        local eclipseFaction = Galaxy():findFaction("The Eclipse")
        if not eclipseFaction then
            if queueId then CosmicVaultTerritory.RetryMaterialization(
                kind, queueX, queueY, claimant, "eclipse_faction_missing", 60) end
            if encounterId then EncounterBridge.Transition(OWNER, encounterId, "retryable", {
                lastError = "eclipse_faction_missing"}) end
            terminate()
            return
        end

        -- Forcefully clear any existing weather that might block Dark Matter Fog
        if sector:hasScript("sector/cv_weather_controller.lua") then
            sector:removeScript("sector/cv_weather_controller.lua")
        end
        sector:addScriptOnce("data/scripts/sector/cv_weather_controller.lua", "DarkMatterFog", -1)

        -- Eclipse Wastes: the fog + permanent Obliterator guardian below
        -- already made this a visually hostile zone, but nothing made it mechanically dangerous
        -- to linger in -- ca_rift_hazard.lua (the same shield-drain hazard used for Dark Sectors
        -- near the core) closes that gap with no new code needed, just attaching it here too.
        sector:addScriptOnce("data/scripts/sector/ca_rift_hazard.lua")
        if not sector:hasScript("data/scripts/sector/cv_weather_controller.lua")
                or not sector:hasScript("data/scripts/sector/ca_rift_hazard.lua") then
            if queueId then CosmicVaultTerritory.RetryMaterialization(
                kind, queueX, queueY, claimant, "annihilation_script_attachment_failed", 60) end
            if encounterId then EncounterBridge.Transition(OWNER, encounterId, "retryable", {
                lastError = "annihilation_script_attachment_failed"}) end
            terminate()
            return
        end

        -- Reclaimed ships: capture each deleted entity's faction/position
        -- before it's gone, then have a small chance to spawn a normal Eclipse ship near where
        -- one stood, flavor-tagged with whose it was. Not an attempt to convert the actual wreck
        -- object -- that's uncertain API territory, and the entities are about to be deleted
        -- anyway -- just a thematically-linked new spawn using the same createShip() pipeline
        -- already proven safe everywhere else in this file.
        local reclaimCandidates = {}
        local criticalShips = 0
        local entities = {sector:getEntities()}
        for _, entity in pairs(entities) do
            if entity.type == EntityType.Station or entity.type == EntityType.Ship then
                if entity.factionIndex ~= eclipseFaction.index then
                    if criticalPlayerShips and entity.type == EntityType.Ship
                            and (entity.playerOwned or entity.allianceOwned) then
                        entity.shieldDurability = 0
                        entity.durability = 1
                        criticalShips = criticalShips + 1
                    elseif not entity.playerOwned and not entity.allianceOwned then
                        local owner = Faction(entity.factionIndex)
                        if owner and entity.type == EntityType.Ship then
                            table.insert(reclaimCandidates, {pos = entity.translationf, factionName = owner.translatedName})
                        end
                        sector:deleteEntity(entity)
                    end
                end
            end
        end

        local EclipseGenerator = include("eclipsegenerator")

        if #reclaimCandidates > 0 and random():getFloat() < 0.15 then
            local candidate = reclaimCandidates[random():getInt(1, #reclaimCandidates)]
            local mat = MatrixLookUpPosition(vec3(0, 0, 1), vec3(0, 1, 0), candidate.pos)
            local reclaimed = EclipseGenerator.createInterceptor(mat)
            if reclaimed then
                reclaimed:setTitle(Format("Reclaimed %1% Vessel"%_T, candidate.factionName), {})
                reclaimed:addScriptOnce("ai/patrol.lua")
            end
        end

        -- A player is guaranteed to be physically present here (this script only runs "when a
        -- player finally visits this sector", per the header comment above), so spawn the guardian
        -- with a small offset rather than at literal sector origin -- matches the spread already
        -- used for the Eclipse Stronghold defenders in ascendancyplayer.lua.
        local guardianPos = MatrixLookUpPosition(vec3(0, 0, 1), vec3(0, 1, 0), vec3(random():getFloat(-500, 500), random():getFloat(-500, 500), random():getFloat(-500, 500)))
        local ship = EclipseGenerator.createShip(guardianPos, "ca_obliterator")
        if ship then
            ship:setTitle("Eclipse Obliterator", {})
            ship:addScriptOnce("data/scripts/entity/ca_heroic_defense.lua")
        else
            if queueId then CosmicVaultTerritory.RequireMaterializationRepair(
                kind, queueX, queueY, claimant, "annihilation_guardian_spawn_failed_after_wipe") end
            if encounterId then EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
                lastError = "annihilation_guardian_spawn_failed_after_wipe"}) end
            terminate()
            return
        end

        local completed
        if queueId then
            sector:setValue(receiptKey, queueReceipt)
            completed = CosmicVaultTerritory.CompleteMaterialization(
                kind, queueX, queueY, claimant, {
                    sectorReceipt = queueId,
                    guardianId = ship and ship.id.string or nil,
                    criticalPlayerShipsApplied = criticalPlayerShips == true,
                    criticalShipCount = criticalShips,
                    verified = sector:getValue(receiptKey) == queueReceipt
                })
            if not completed then
                print("[Cosmic Ascendancy] Annihilation completed but queue receipt needs repair: "
                    .. tostring(queueId))
            end
        end
        if encounterId and (not queueId or completed) then
            local encounterCompleted = completeEncounter(encounterId, {
                reason = "sector_receipt_verified", queueId = queueId
            })
            if not encounterCompleted then
                print("[Cosmic Ascendancy] Annihilation queue completed but encounter needs repair: "
                    .. tostring(encounterId))
            end
        end
        local sx, sy = sector:getCoordinates()
        local controlling = Galaxy():getControllingFaction(sx, sy)
        local controllingIndex = type(controlling) == "number" and controlling
            or (controlling and controlling.index)
        local state = CosmicVaultData.GetRecord(Server(), "ca_state_v2", 2)
        if state and controllingIndex == eclipseFaction.index then
            Galaxy():invokeFunction("data/scripts/galaxy/ca_state_coordinator.lua",
                "requestTerritoryState", "data/scripts/sector/ca_delayed_annihilation.lua",
                state.revision, "claim", {x = sx, y = sy,
                    eclipseFactionIndex = eclipseFaction.index, source = "annihilation_receipt"})
        end
        terminate()
    end
end
