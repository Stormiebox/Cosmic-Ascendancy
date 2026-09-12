package.path = package.path .. ";data/scripts/lib/?.lua"

-- Required before any %_T/%_t usage below (see the proximity stinger in onSectorEntered) --
-- stringutility.lua's top level installs the __mod metamethod that routes "..."%_t through
-- translation at all; nothing else this file includes reaches it before that point is used.
include("stringutility")

local CosmicVaultData = include("cosmicvaultdata")
local CosmicVaultTerritory = include("cosmicvaultterritory")
local COORDINATOR = "data/scripts/galaxy/ca_state_coordinator.lua"
local OWNER = "data/scripts/player/ascendancyplayer.lua"
local EncounterBridge = include("ca_encounter_bridge")
include("cosmicascendancyconfig")
-- namespace AscendancyPlayer
AscendancyPlayer = {}

function AscendancyPlayer.initialize()
    if onServer() then Player():addScriptOnce("data/scripts/player/background/ca_campaign_controller.lua") end
    if onServer() then Player():addScriptOnce("data/scripts/player/background/ca_darksector_generator.lua") end
    if onServer() then Player():addScriptOnce("data/scripts/player/background/ca_nemesis_hunt.lua") end
    if onServer() then
        Player():registerCallback("onSectorEntered", "onSectorEntered")
        Player():registerCallback("onShipChanged", "onShipChanged")
        Player():addScriptOnce("data/scripts/player/cosmicascendancycodex.lua")
    end
end

local function applyToEntity(entityId, playerIndex)
    local entity = Entity(entityId)
    if not entity then return end

    if entity.type ~= EntityType.Ship and entity.type ~= EntityType.Station then return end

    local p = Player(playerIndex)
    if not p then return end

    -- Apply to ships/stations owned by the player, OR their alliance!
    local ownerIndex = entity.factionIndex
    if ownerIndex ~= p.index then
        local allianceIndex = p.allianceIndex
        if not allianceIndex or ownerIndex ~= allianceIndex then return end
    end

    entity:addScriptOnce("data/scripts/entity/ca_ascendancy_ship_buff.lua")
    
    if entity.isStation then
        entity:addScriptOnce("data/scripts/entity/ca_station_overdrive.lua")
    end
end

function AscendancyPlayer.onSectorEntered(playerIndex, x, y)
    local entities = {Sector():getEntitiesByFaction(playerIndex)}

    local p = Player(playerIndex)
    if p and p.allianceIndex then
        local allianceEntities = {Sector():getEntitiesByFaction(p.allianceIndex)}
        for _, e in pairs(allianceEntities) do
            table.insert(entities, e)
        end
    end

    for _, entity in pairs(entities) do
        applyToEntity(entity.id, playerIndex)
    end

    -- Spawn Eclipse Strongholds safely.
    -- We dynamically roll the Stronghold flag on first player entry to bypass impossible Server() generation hooks
    if onServer() then
        local sector = Sector()

        -- The Choir's proximity stinger: fires once, the first time this player's own script
        -- instance sees them cross into Eclipse-held territory. Deliberately NOT persisted via
        -- secure()/restore() (this file has neither) -- the absence of persistence is what makes
        -- this naturally "once per session" with no extra flag plumbing needed: a relog or server
        -- restart re-creates a fresh script instance with AscendancyPlayer.dreadStingerShown back
        -- at its default, same as intended.
        if not AscendancyPlayer.dreadStingerShown then
            local canonical = CosmicVaultData.GetRecord(Server(), "ca_state_v2", 2)
            local held = canonical and canonical.territory and canonical.territory.held or {}
            if held[tostring(x) .. ":" .. tostring(y)] then
                AscendancyPlayer.dreadStingerShown = true
                local player = Player(playerIndex)
                if player then
                    player:addScriptOnce("data/scripts/player/ca_boss_audio_hook.lua")
                    player:invokeFunction("data/scripts/player/ca_boss_audio_hook.lua", "triggerAmbientStinger", "...something is already here."%_t)
                end
            end
        end

        -- PROGRESSIVE MATERIALIZATION INTERCEPT (Lag Fix)
        local claimant = "ascendancy-player:" .. tostring(playerIndex) .. ":" .. x .. ":" .. y
        local annihilation = CosmicVaultTerritory.GetMaterialization("annihilation", x, y)
        if annihilation and annihilation.state == "materializing"
                and type(annihilation.claimUntil) == "number"
                and annihilation.claimUntil <= Server().unpausedRuntime then
            local expectedReceipt = annihilation.id .. ":" .. tostring(annihilation.createdAt or 0)
            if sector:getValue("ca_annihilation_receipt") ~= expectedReceipt then
                CosmicVaultTerritory.RequireMaterializationRepair(
                    "annihilation", x, y, annihilation.claimOwner,
                    "annihilation_side_effects_ambiguous_after_lease_expiry")
                annihilation = nil
            end
        end
        if annihilation and (annihilation.state == "pending" or annihilation.state == "retryable"
                or annihilation.state == "materializing") then
            local claimed = CosmicVaultTerritory.ClaimMaterialization(
                "annihilation", x, y, claimant, 300)
            if claimed then
                sector:addScriptOnce("data/scripts/sector/ca_delayed_annihilation.lua",
                    "annihilation", x, y, claimant, claimed.id,
                    claimed.createdAt,
                    claimed.payload and claimed.payload.encounterId,
                    claimed.payload and claimed.payload.criticalPlayerShips == true)
                if not sector:hasScript("sector/ca_delayed_annihilation.lua") then
                    CosmicVaultTerritory.RetryMaterialization(
                        "annihilation", x, y, claimant, "script_attachment_failed", 60)
                end
            end
        end

        local siege = CosmicVaultTerritory.GetMaterialization("siege", x, y)
        if siege and (siege.state == "pending" or siege.state == "retryable"
                or siege.state == "materializing") then
            local claimed = CosmicVaultTerritory.ClaimMaterialization("siege", x, y, claimant, 300)
            if claimed then
                sector:addScriptOnce("data/scripts/events/siegeevent.lua")
                if sector:hasScript("events/siegeevent.lua") then
                    local encounterId = claimed.payload and claimed.payload.encounterId
                    if encounterId then
                        EncounterBridge.Transition(OWNER, encounterId, "active", {
                            x = x, y = y, engagedAt = Server().unpausedRuntime
                        })
                        EncounterBridge.Transition(OWNER, encounterId, "resolving", {
                            resolution = {reason = "siege_script_verified"}
                        })
                        EncounterBridge.Transition(OWNER, encounterId, "succeeded", {
                            resolution = {reason = "siege_script_verified"}
                        })
                    end
                    CosmicVaultTerritory.CompleteMaterialization("siege", x, y, claimant, {
                        script = "data/scripts/events/siegeevent.lua", verified = true
                    })
                else
                    CosmicVaultTerritory.RetryMaterialization(
                        "siege", x, y, claimant, "script_attachment_failed", 60)
                end
            end
        end
        
        local state = CosmicVaultData.GetRecord(Server(), "ca_state_v2", 2)
        local eclipseFaction = Galaxy():findFaction("The Eclipse")
        local controlling = Galaxy():getControllingFaction(x, y)
        local controllingIndex = type(controlling) == "number" and controlling
            or (controlling and controlling.index)
        local coordinateKey = tostring(x) .. ":" .. tostring(y)
        if state and eclipseFaction and controllingIndex == eclipseFaction.index
                and not state.territory.held[coordinateKey] then
            Galaxy():invokeFunction(COORDINATOR, "requestTerritoryState", OWNER, state.revision,
                "claim", {x = x, y = y, eclipseFactionIndex = eclipseFaction.index,
                    source = "loaded_sector_reconciliation"})
            state = CosmicVaultData.GetRecord(Server(), "ca_state_v2", 2) or state
        elseif state and state.territory.held[coordinateKey]
                and (not controllingIndex or not eclipseFaction
                    or controllingIndex ~= eclipseFaction.index) then
            Galaxy():invokeFunction(COORDINATOR, "requestTerritoryState", OWNER, state.revision,
                "release", {x = x, y = y, source = "loaded_sector_reconciliation"})
            state = CosmicVaultData.GetRecord(Server(), "ca_state_v2", 2) or state
        end
        if state and state.eclipse.state == "fully_awake" and not sector:getValue("eclipse_stronghold_rolled") then
            sector:setValue("eclipse_stronghold_rolled", true)
            
            local SectorSpecifics = include("sectorspecifics")
            local specs = SectorSpecifics(x, y, Server().seed)
            if specs.regular then
                local dist = math.sqrt(x*x + y*y)
                local rand = Random(Seed(Server().seed + x + y))
                local chance = 0.0
                if dist <= 75 then chance = 0.50
                elseif dist <= 150 then chance = 0.25
                else chance = rand:getFloat(0.05, 0.15) end
                
                if rand:getFloat() < chance then
                    sector:setValue("is_eclipse_stronghold", true)
                end
            end
        end

        if sector:getValue("is_eclipse_stronghold") and not sector:getValue("eclipse_stronghold_spawned") then
            local encounterId = "stronghold:" .. tostring(x) .. ":" .. tostring(y)
            local encounter = EncounterBridge.Get(encounterId)
            if not encounter then
                encounter = EncounterBridge.Create(OWNER, {
                    encounterId = encounterId,
                    kind = "stronghold",
                    concurrencyKey = encounterId,
                    scope = "sector",
                    x = x, y = y, state = "prepared"
                })
            end
            if not encounter or encounter.state == "repair_required" then return end
            if encounter.state == "materializing" then
                EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
                    lastError = "restart_during_stronghold_materialization"
                })
                return
            end
            if encounter.state == "retryable" then
                encounter = EncounterBridge.Transition(OWNER, encounterId, "prepared")
            end
            if not encounter or not EncounterBridge.Transition(
                    OWNER, encounterId, "materializing") then return end

            local attempts = (sector:getValue("eclipse_stronghold_attempts") or 0) + 1
            sector:setValue("eclipse_stronghold_attempts", attempts)
            local EclipseGenerator = include("eclipsegenerator")
            local spawned = {}
            local station = EclipseGenerator.createStation(Matrix())
            if station then table.insert(spawned, station) end
                
                local defenderTypes = {"ca_obliterator", "ca_voidweaver", "ca_phantom", "ca_singularity", "ca_juggernaut", "ca_interceptor", "ca_harvester", "ca_defiler"}
                for i = 1, 4 do
                    local typeIdx = random():getInt(1, #defenderTypes)
                    local sType = defenderTypes[typeIdx]
                    local pos = MatrixLookUpPosition(vec3(0,0,1), vec3(0,1,0), vec3(random():getInt(-1000, 1000), 0, random():getInt(-1000, 1000)))
                    
                    local defender
                    if sType == "ca_voidweaver" then
                        defender = EclipseGenerator.createCarrier(pos)
                    elseif sType == "ca_phantom" then
                        defender = EclipseGenerator.createAssassin(pos)
                    elseif sType == "ca_singularity" then
                        defender = EclipseGenerator.createArtillery(pos)
                    elseif sType == "ca_juggernaut" then
                        defender = EclipseGenerator.createJuggernaut(pos)
                    elseif sType == "ca_interceptor" then
                        defender = EclipseGenerator.createInterceptor(pos)
                    elseif sType == "ca_harvester" then
                        defender = EclipseGenerator.createHarvester(pos)
                    elseif sType == "ca_defiler" then
                        defender = EclipseGenerator.createDefiler(pos)
                    else
                        defender = EclipseGenerator.createShip(pos, sType)
                    end
                    
                    -- Ensure the generator successfully created a defender before assigning AI scripts
                    if defender then
                        defender:addScriptOnce("data/scripts/entity/ai/patrol.lua")
                        table.insert(spawned, defender)
                    end
                end
            local spawnedIds = {}
            local tagsVerified = true
            for _, entity in ipairs(spawned) do
                entity:setValue("ca_encounter_id", encounterId)
                if entity:getValue("ca_encounter_id") ~= encounterId then tagsVerified = false end
                table.insert(spawnedIds, entity.id.string)
            end
            if station and #spawned == 5 and tagsVerified then
                local activated = EncounterBridge.Transition(
                    OWNER, encounterId, "active", {entityId = station.id.string,
                        entityIds = spawnedIds, attempts = attempts})
                if activated then
                    sector:setValue("eclipse_stronghold_spawned", true)
                else
                    EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
                        entityIds = spawnedIds, attempts = attempts,
                        lastError = "stronghold_activation_persistence_failed"
                    })
                end
            elseif #spawned > 0 then
                EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
                    entityIds = spawnedIds, attempts = attempts,
                    lastError = tagsVerified and "stronghold_partial_materialization"
                        or "stronghold_tag_verification_failed"
                })
            elseif attempts >= 5 then
                EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
                    attempts = attempts,
                    lastError = "stronghold_materialization_failed_after_five_attempts"
                })
            else
                EncounterBridge.Transition(OWNER, encounterId, "retryable", {
                    attempts = attempts,
                    lastError = "stronghold_materialization_failed"
                })
            end
            end
        

        
        -- Raid Summoner (Listens for Datacore jettisons)
        if not Sector():hasScript("data/scripts/sector/ca_raid_summoner.lua") then
            Sector():addScriptOnce("data/scripts/sector/ca_raid_summoner.lua")
        end
    end
end


function AscendancyPlayer.onShipChanged(playerIndex, craftId)
    applyToEntity(craftId, playerIndex)
end
