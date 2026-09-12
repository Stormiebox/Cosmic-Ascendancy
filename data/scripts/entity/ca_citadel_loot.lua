package.path = package.path .. ";data/scripts/lib/?.lua"

local cv_news = include("cosmicvaultnews")
local CosmicVaultData = include("cosmicvaultdata")
local EncounterBridge = include("ca_encounter_bridge")
include("goods")

local OWNER = "data/scripts/entity/ca_citadel_loot.lua"
local COORDINATOR = "data/scripts/galaxy/ca_state_coordinator.lua"

function initialize()
    if not onServer() then return end
    Entity():registerCallback("onDestroyed", "onDestroyed")
    deferredCallback(0.1, "ensureEncounter")
end

function ensureEncounter()
    local entity = Entity()
    if not valid(entity) then return nil end
    local encounterId = entity:getValue("ca_encounter_id")
    if encounterId and EncounterBridge.Get(encounterId) then return encounterId end
    local x, y = Sector():getCoordinates()
    encounterId = "citadel:" .. x .. ":" .. y .. ":" .. entity.id.string
    local prepared = EncounterBridge.Create(OWNER, {
        encounterId = encounterId, kind = "citadel",
        concurrencyKey = encounterId, scope = "sector",
        x = x, y = y, state = "prepared"
    })
    if not prepared then return nil end
    local active = EncounterBridge.TagAndActivate(OWNER, encounterId, entity)
    return active and encounterId or nil
end

local function requireRepair(encounterId, errorText)
    return EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
        lastError = errorText, repairRequired = errorText
    })
end

function onDestroyed()
    if not onServer() then return end
    local sector = Sector()
    local entity = Entity()
    local encounterId = entity:getValue("ca_encounter_id") or ensureEncounter()
    local encounter = encounterId and EncounterBridge.Get(encounterId)
    if not encounter or encounter.entityId ~= entity.id.string then return end

    local participants = {}
    for _, player in pairs({sector:getPlayers()}) do table.insert(participants, player.index) end
    table.sort(participants)
    if encounter.state == "active" then
        if not EncounterBridge.Transition(OWNER, encounterId, "resolving", {
                participants = participants,
                resolution = {reason = "verified_destroyed", entityId = entity.id.string}}) then return end
    elseif encounter.state ~= "resolving" and encounter.state ~= "succeeded" then
        return
    end

    local receipts = {}
    for _, playerIndex in ipairs(participants) do
        local operationId = encounterId .. ":player:" .. playerIndex .. ":shared-loot"
        local receipt = EncounterBridge.PrepareReceipt(OWNER, {
            operationId = operationId, kind = "citadel_shared_loot",
            encounterId = encounterId, recipient = {playerIndex = playerIndex},
            reissue = {mode = "none"}
        })
        if not receipt then
            requireRepair(encounterId, "shared_loot_receipt_prepare_failed:" .. operationId)
            return
        end
        table.insert(receipts, operationId)
    end

    local pos = entity.translationf
    local citadelX, citadelY = sector:getCoordinates()
    sector:dropCargo(pos, nil, nil, goods["Ascendant Matter"], 0, random():getInt(100, 250))
    for _ = 1, random():getInt(3, 5) do
        sector:dropCargo(pos, nil, nil, goods["Eclipse Datacore"], 0, 1)
    end

    local SectorTurretGenerator = include("sectorturretgenerator")
    local UpgradeGenerator = include("upgradegenerator")
    local ugen = UpgradeGenerator()
    local tgen = SectorTurretGenerator(sector.seed)
    local turretDrops, upgradeDrops = 0, 0
    for _ = 1, random():getInt(8, 12) do
        local turret = tgen:generateArmed(citadelX, citadelY, 0, Rarity(RarityType.Legendary))
        if turret then sector:dropTurret(pos, nil, nil, turret); turretDrops = turretDrops + 1 end
    end
    for _ = 1, random():getInt(8, 12) do
        local upgrade = ugen:generateSectorSystem(citadelX, citadelY, Rarity(RarityType.Legendary))
        if upgrade then sector:dropUpgrade(pos, nil, nil, upgrade); upgradeDrops = upgradeDrops + 1 end
    end

    for _, operationId in ipairs(receipts) do
        if not EncounterBridge.CompleteReceipt(OWNER, operationId, {
                sharedSectorLoot = true, turretDrops = turretDrops, upgradeDrops = upgradeDrops}) then
            requireRepair(encounterId, "shared_loot_receipt_completion_ambiguous:" .. operationId)
            return
        end
    end

    local state = CosmicVaultData.GetRecord(Server(), "ca_state_v2", 2)
    if not state then
        requireRepair(encounterId, "citadel_outcome_state_unavailable")
        return
    end
    local outcomeCode, outcomeResult = Galaxy():invokeFunction(
        COORDINATOR, "requestEncounterOutcome", OWNER, state.revision,
            encounterId, "citadel_succeeded", {
                suppressionUntil = Server().unpausedRuntime
                    + (6 + math.floor((state.territory.conqueredCount or 0) / 10) * 2) * 3600,
                x = citadelX, y = citadelY, releaseRadius = 15
            })
    if outcomeCode ~= 0 or not outcomeResult then
        requireRepair(encounterId, "citadel_outcome_persistence_failed")
        return
    end
    encounter = EncounterBridge.Get(encounterId)
    if encounter and encounter.state == "resolving" then
        if not EncounterBridge.Transition(OWNER, encounterId, "succeeded", {
                participants = participants,
                resolution = {reason = "verified_destroyed", entityId = entity.id.string}}) then
            requireRepair(encounterId, "citadel_terminal_transition_failed")
            return
        end
    end
    sector:broadcastChatMessage("Eclipse Citadel", 2,
        "The Citadel's destruction has generated a massive suppression field. Eclipse invasions halted.")
    if cv_news.publishArticle then
        cv_news.publishArticle({
            title = "Sectors Liberated From The Eclipse!",
            content = "The fall of an Eclipse Citadel has pushed the frontier back within fifteen sectors.",
            category = "Heroic Victories"
        })
    end
end
