package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("utility")
include("stringutility")
include("faction")

local CosmicVaultData = include("cosmicvaultdata")
local cv_news = include("cosmicvaultnews")
local cw_bridge = include("cosmicwarbridge")
local cv_buffs = include("cosmicvaultbuffs")
local CAState = include("ca_state")

-- namespace AscendancyBeacon
AscendancyBeacon = {}

local COORDINATOR = "data/scripts/galaxy/ca_state_coordinator.lua"
local OWNER = "data/scripts/entity/ascendancybeacon.lua"
local RECORD_KEY = "ca_beacon_v1"
local UPKEEP_INTERVAL = 45 * 60
local SANCTUARY_RADIUS_BY_TIER = {[3] = 5, [4] = 8, [5] = 12}

local record
local active = false
local currentTier = 1

local function now()
    return Server().unpausedRuntime
end

local function newRecord()
    return {
        schemaVersion = 1,
        revision = 0,
        state = "inactive",
        beaconId = Entity().id.string,
        ownerFactionIndex = Entity().factionIndex,
        tier = 1,
        lastUpkeepTime = now(),
        lastSiegeTime = now(),
        nextSiegeInterval = random():getInt(3, 6) * 3600,
        treasury = 0,
        pendingOperation = nil,
        migration = {source = "new", migratedAt = now()},
        lastError = nil,
        repairRequired = nil,
        updatedAt = now()
    }
end

local function refreshMirrors()
    active = record and record.state == "active" or false
    currentTier = record and record.tier or 1
    AscendancyBeacon.treasury = record and record.treasury or 0
end

local function saveRecord(nextRecord)
    local persisted = CAState.DeepCopy(nextRecord or record)
    persisted.revision = (persisted.revision or 0) + 1
    persisted.updatedAt = now()
    local saved, err = CosmicVaultData.SetRecord(Entity(), RECORD_KEY, persisted)
    if not saved then return nil, err end
    record = persisted
    refreshMirrors()
    return true, nil
end

local function loadRecord()
    local stored, err = CosmicVaultData.GetRecord(Entity(), RECORD_KEY, 1)
    if stored then
        record = stored
    else
        record = newRecord()
        if err and err ~= "missing" then
            record.state = "repair_required"
            record.lastError = err
            record.repairRequired = "beacon_record_" .. tostring(err)
        end
        saveRecord()
    end
    if record.state == "activation_prepared" or record.state == "upgrade_prepared"
            or record.state == "upkeep_prepared" or record.state == "deactivation_prepared"
            or record.state == "treasury_prepared" or record.state == "siege_prepared" then
        record.state = "repair_required"
        record.lastError = "restart_during_prepared_operation"
        record.repairRequired = record.pendingOperation and record.pendingOperation.operationId
            or "unidentified_prepared_operation"
        saveRecord()
    end
    refreshMirrors()
end

local function coordinator(functionName, ...)
    local resultCode, first, second = Galaxy():invokeFunction(COORDINATOR, functionName, ...)
    if resultCode ~= 0 then return nil, "coordinator_unavailable" end
    return first, second
end

local function claimPayload(tier)
    local x, y = Sector():getCoordinates()
    return {
        beaconId = record.beaconId,
        ownerFactionIndex = record.ownerFactionIndex,
        x = x,
        y = y,
        tier = tier or record.tier,
        sanctuaryRadius = SANCTUARY_RADIUS_BY_TIER[tier or record.tier],
        entityScript = OWNER
    }
end

local function requestClaim(operation, payload)
    local revisions, err = coordinator("getRegistryRevisions")
    if not revisions then return nil, err end
    local revision, summary = coordinator("requestBeaconClaim", OWNER, revisions.state,
        operation, payload or claimPayload())
    if revision then return revision, summary end
    if summary ~= "revision_mismatch" then return nil, summary end
    revisions, err = coordinator("getRegistryRevisions")
    if not revisions then return nil, err end
    return coordinator("requestBeaconClaim", OWNER, revisions.state,
        operation, payload or claimPayload())
end

local function syncFactionTier(owner, summary)
    if owner and cv_buffs and cv_buffs.setGlobalTier then
        cv_buffs.setGlobalTier(owner.index, summary and summary.maxTier or 0)
    end
end

local function authorize(requireSpend)
    local owner, craft, player
    if requireSpend then
        owner, craft, player = getInteractingFaction(callingPlayer,
            AlliancePrivilege.ManageStations, AlliancePrivilege.SpendResources)
    else
        owner, craft, player = getInteractingFaction(callingPlayer,
            AlliancePrivilege.ManageStations)
    end
    if not owner or not player or player.index ~= callingPlayer then return nil, nil end
    if owner.index ~= Entity().factionIndex or owner.index ~= record.ownerFactionIndex then
        player:sendChatMessage("Beacon"%_t, 1, "Your faction does not own this Beacon."%_t)
        return nil, nil
    end
    return owner, player
end

local function enterRepair(reason)
    local working = CAState.DeepCopy(record)
    working.state = "repair_required"
    working.lastError = reason
    working.repairRequired = reason
    local saved = saveRecord(working)
    if not saved then
        record = working
        refreshMirrors()
    end
    local x, y = Sector():getCoordinates()
    coordinator("requestEntityRepair", OWNER, "upsert", {
        entityId = record.beaconId,
        kind = "beacon",
        ownerFactionIndex = record.ownerFactionIndex,
        x = x,
        y = y,
        recordRevision = record.revision,
        reason = reason
    })
end

local function persistAfterSideEffect(nextRecord, reason)
    local saved, err = saveRecord(nextRecord)
    if saved then return true, nil end
    record = CAState.DeepCopy(nextRecord)
    record.state = "repair_required"
    record.lastError = "record_write_failed_after_side_effect:" .. tostring(err)
    record.repairRequired = reason
    refreshMirrors()
    local x, y = Sector():getCoordinates()
    coordinator("requestEntityRepair", OWNER, "upsert", {
        entityId = record.beaconId, kind = "beacon",
        ownerFactionIndex = record.ownerFactionIndex, x = x, y = y,
        recordRevision = record.revision, reason = reason
    })
    return nil, err
end

local function processRepairAction()
    if not record or record.state ~= "repair_required" then return end
    local action = coordinator("getEntityRepairAction", OWNER,
        record.beaconId, record.revision)
    if not action then return end
    local operation = record.pendingOperation or {}
    local working = CAState.DeepCopy(record)
    local summary
    if action == "abandon" then
        local removed, result = requestClaim("remove")
        if not removed and result ~= "missing" then return end
        summary = result
        working.state = "inactive"
    elseif action == "resume" or action == "mark-complete" then
        if string.find(tostring(operation.operationId), ":deactivate:", 1, true) then
            local removed, result = requestClaim("remove")
            if not removed and result ~= "missing" then return end
            summary = result
            working.state = "inactive"
        else
            local targetTier = operation.targetTier or working.tier
            local claimed, result = requestClaim("upsert", claimPayload(targetTier))
            if not claimed then return end
            summary = result
            working.tier = targetTier
            working.state = "active"
            if string.find(tostring(operation.operationId), ":upkeep:", 1, true) then
                working.lastUpkeepTime = now()
            elseif string.find(tostring(operation.operationId), ":treasury:", 1, true) then
                working.treasury = 0
            end
        end
    else
        return
    end
    working.pendingOperation = nil
    working.repairRequired = nil
    working.lastError = nil
    if not persistAfterSideEffect(working, "beacon_repair_completion_persistence_failed") then return end
    coordinator("requestEntityRepair", OWNER, "resolve", {
        entityId = record.beaconId, recordRevision = record.revision
    })
    syncFactionTier(Faction(record.ownerFactionIndex), summary)
end

local function resourcesAvailable(owner, material, amount)
    local resources = {owner:getResources()}
    return (resources[material.value + 1] or 0) >= amount, resources
end

local function debitAndVerify(owner, reason, creditCost, material, materialCost)
    local beforeMoney = owner.money
    local _, beforeResources = resourcesAvailable(owner, material, materialCost)
    owner:pay(reason, creditCost)
    owner:payResource(reason, material, materialCost)
    local afterResources = {owner:getResources()}
    return owner.money <= beforeMoney - creditCost
        and (afterResources[material.value + 1] or 0)
            <= (beforeResources[material.value + 1] or 0) - materialCost
end

local function deactivateInternal(reason)
    if record.state ~= "active" and record.state ~= "deactivation_prepared" then return true end
    local working = CAState.DeepCopy(record)
    working.state = "deactivation_prepared"
    working.pendingOperation = {
        operationId = record.beaconId .. ":deactivate:" .. tostring(record.revision + 1),
        reason = reason or "manual"
    }
    if not saveRecord(working) then return nil, "prepare_persistence_failed" end
    local revision, summary = requestClaim("remove")
    if not revision then
        enterRepair("beacon_claim_removal_unconfirmed:" .. tostring(summary))
        return nil
    end
    local owner = Faction(record.ownerFactionIndex)
    working = CAState.DeepCopy(record)
    working.state = "inactive"
    working.pendingOperation = nil
    working.lastError = nil
    working.repairRequired = nil
    if not persistAfterSideEffect(working, "beacon_deactivation_persistence_failed") then return nil end
    syncFactionTier(owner, summary)
    local x, y = Sector():getCoordinates()
    Galaxy():sendCallback("onAscendancyBeaconDeactivated", record.beaconId, x, y)
    return true
end

function AscendancyBeacon.initialize()
    if not onServer() then return end
    loadRecord()
    Entity():registerCallback("onDestroyed", "onDestroyed")
    Sector():registerCallback("onEntityEntered", "onEntityEntered")
    if record.ownerFactionIndex ~= Entity().factionIndex then
        local oldState = record.state
        if oldState == "inactive" then
            local working = CAState.DeepCopy(record)
            working.ownerFactionIndex = Entity().factionIndex
            if not saveRecord(working) then return end
        else
            local previousOwner = record.ownerFactionIndex
            local removed, previousSummary = requestClaim("remove")
            if removed then syncFactionTier(Faction(previousOwner), previousSummary) end
            record.ownerFactionIndex = Entity().factionIndex
            record.pendingOperation = {
                operationId = record.beaconId .. ":owner-change:" .. tostring(record.revision + 1),
                targetTier = record.tier
            }
            enterRepair("beacon_owner_changed")
            return
        end
    end
    if record.state == "active" then
        local revision, summary = requestClaim("upsert")
        if not revision then
            enterRepair(summary == "limit_reached" and "legacy_beacon_limit_exceeded"
                or "beacon_claim_reconciliation_failed:" .. tostring(summary))
        else
            syncFactionTier(Faction(record.ownerFactionIndex), summary)
        end
    elseif record.state == "repair_required" then
        local x, y = Sector():getCoordinates()
        coordinator("requestEntityRepair", OWNER, "upsert", {
            entityId = record.beaconId, kind = "beacon",
            ownerFactionIndex = record.ownerFactionIndex, x = x, y = y,
            recordRevision = record.revision, reason = record.repairRequired
        })
    end
end

function AscendancyBeacon.interactionPossible(playerIndex, option)
    return checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageStations)
end

function AscendancyBeacon.getIcon()
    return "data/textures/icons/star-cycle.png"
end

function AscendancyBeacon.initUI()
    local res = getResolution()
    local size = vec2(600, 400)
    local menu = ScriptUI()
    local window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    window.caption = "Ascendancy Beacon Status"%_t
    window.showCloseButton = 1
    window.moveable = 1
    menu:registerWindow(window, "Manage Beacon"%_t, 10)
    window:createLabel(Rect(10, 10, size.x - 10, 30), "Ascendancy Status:"%_t, 16)
    AscendancyBeacon.statusLabel = window:createLabel(Rect(180, 10, size.x - 10, 30), "", 16)
    AscendancyBeacon.tierLabel = window:createLabel(Rect(10, 40, size.x - 10, 60), "", 16)
    window:createLabel(Rect(10, 70, size.x - 10, 90), "Billing Cycle: 45 Minutes"%_t, 14)
    AscendancyBeacon.costLabel = window:createLabel(Rect(10, 100, size.x - 10, 200), "", 14)
    AscendancyBeacon.toggleBtn = window:createButton(Rect(size.x * 0.5 - 210, 220,
        size.x * 0.5 - 10, 260), "Activate Beacon"%_t, "onTogglePressed")
    AscendancyBeacon.upgradeBtn = window:createButton(Rect(size.x * 0.5 + 10, 220,
        size.x * 0.5 + 210, 260), "Upgrade Tier"%_t, "onUpgradePressed")
    AscendancyBeacon.sync()
end

function AscendancyBeacon.onShowWindow()
    AscendancyBeacon.sync()
end

function AscendancyBeacon.onTogglePressed()
    if onClient() then invokeServerFunction("toggleBeacon") end
end

function AscendancyBeacon.onUpgradePressed()
    if onClient() then invokeServerFunction("upgradeTier") end
end

function AscendancyBeacon.getUpgradeCost(targetTier)
    if targetTier == 2 then return 50000000, Material(2), 2000000 end
    if targetTier == 3 then return 150000000, Material(3), 4000000 end
    if targetTier == 4 then return 400000000, Material(4), 7500000 end
    if targetTier == 5 then return 1000000000, Material(6), 10000000 end
    return 0, Material(0), 0
end

function AscendancyBeacon.getUpkeepCost()
    local snapshot = coordinator("getCanonicalSnapshot")
    local summary = snapshot and snapshot.beacons
        and snapshot.beacons.byFaction[tostring(Entity().factionIndex)] or nil
    local registryAvailable = snapshot ~= nil
        and not (snapshot.recordErrors and snapshot.recordErrors.ca_state_v2)
    local count = summary and summary.activeCount or (registryAvailable and 0 or 3)
    if not record or record.state ~= "active" then count = count + 1 end
    count = math.max(1, math.min(3, count))
    local multiplier = count * count
    local x, y = Sector():getCoordinates()
    local distance = length(vec2(x, y))
    local material
    if distance > 400 then material = Material(1)
    elseif distance > 300 then material = Material(2)
    elseif distance > 200 then material = Material(3)
    elseif distance > 100 then material = Material(4)
    elseif distance > 50 then material = Material(5)
    else material = Material(6) end
    return 10000000 * multiplier, material, 500000 * multiplier, registryAvailable
end

function AscendancyBeacon.onEntityEntered(entityId)
    if not onServer() or record.state ~= "active" then return end
    local entity = Entity(entityId)
    if not entity or not entity.isShip then return end
    local ownerFaction = Faction(record.ownerFactionIndex)
    local enteringFaction = Faction(entity.factionIndex)
    if not ownerFaction or not enteringFaction or not enteringFaction.isAIFaction then return end
    if ownerFaction:getRelations(enteringFaction.index) < -10000 then return end
    local baseTolls = {10000, 50000, 100000, 250000, 500000}
    local heatModifier = 1
    if cw_bridge and cw_bridge.getFactionWarHeat then
        local heat = cw_bridge.getFactionWarHeat(enteringFaction.index)
        if heat and heat > 0 then heatModifier = 1 + math.min(0.5, heat * 0.5) end
    end
    local working = CAState.DeepCopy(record)
    working.treasury = (working.treasury or 0)
        + math.floor((baseTolls[record.tier] or 0) * heatModifier)
    saveRecord(working)
end

function AscendancyBeacon.toggleBeacon()
    if not onServer() then return end
    if not record then loadRecord() end
    if record.state == "repair_required" then return end
    local owner, player = authorize(record.state ~= "active")
    if not owner then return end
    if record.state == "active" then
        if deactivateInternal("manual") then
            player:sendChatMessage("Beacon"%_t, 2,
                "Beacon Deactivated. Sector will now unload normally."%_t)
        end
        AscendancyBeacon.sync()
        return
    end
    if record.state ~= "inactive" then return end

    local creditCost, material, materialCost, registryAvailable = AscendancyBeacon.getUpkeepCost()
    if not registryAvailable then
        player:sendChatMessage("Beacon"%_t, 1,
            "Beacon registry is unavailable; no payment was taken."%_t)
        return
    end
    local enough = resourcesAvailable(owner, material, materialCost)
    if owner.money < creditCost or not enough then
        player:sendChatMessage("Beacon"%_t, 1,
            "Insufficient resources to activate beacon."%_t)
        return
    end
    local working = CAState.DeepCopy(record)
    working.state = "activation_prepared"
    working.pendingOperation = {
        operationId = record.beaconId .. ":activate:" .. tostring(record.revision + 1),
        creditCost = creditCost, material = material.value, materialCost = materialCost
    }
    if not saveRecord(working) then return end
    local reserved, reserveResult = requestClaim("reserve")
    if not reserved then
        working = CAState.DeepCopy(record)
        working.state = "inactive"
        working.pendingOperation = nil
        working.lastError = reserveResult
        if not saveRecord(working) then return end
        player:sendChatMessage("Beacon"%_t, 1, reserveResult == "limit_reached"
            and "Empire Limit Reached! You can only maintain 3 Ascendancy Beacons."%_t
            or "Beacon registry is unavailable; no payment was taken."%_t)
        return
    end
    if not debitAndVerify(owner, "Ascendancy Beacon Activation"%_t,
            creditCost, material, materialCost) then
        enterRepair("activation_debit_unverified")
        return
    end
    local activated, summary = requestClaim("upsert")
    if not activated then
        enterRepair("activation_claim_unverified:" .. tostring(summary))
        return
    end
    working = CAState.DeepCopy(record)
    working.state = "active"
    working.lastUpkeepTime = now()
    working.pendingOperation = nil
    working.lastError = nil
    working.repairRequired = nil
    if not persistAfterSideEffect(working, "beacon_activation_persistence_failed") then return end
    syncFactionTier(owner, summary)
    local x, y = Sector():getCoordinates()
    Galaxy():sendCallback("onAscendancyBeaconActivated", record.beaconId,
        owner.index, x, y)
    Entity():addScriptOnce("data/scripts/entity/ascendancyforge.lua")
    player:sendChatMessage("Beacon"%_t, 0,
        "Beacon Activated. Sector simulation lease is online."%_t)
    if cv_news and cv_news.publishArticle then
        cv_news.publishArticle({
            title = "Galactic Milestone: New Ascendant Capital",
            content = "The " .. owner.name .. " Empire has constructed a massive Ascendancy Beacon in sector ["
                .. x .. ":" .. y .. "]! This region of space has been claimed as an Ascendant Capital.",
            category = "Galactic Expansion"
        })
    end
    if cw_bridge and cw_bridge.addWarHeat then
        for _, index in pairs({Sector():getPresentFactions()}) do
            local faction = Faction(index)
            if faction and faction.isAIFaction and (faction:getTrait("aggressive") or 0) > 0.5 then
                cw_bridge.addWarHeat(faction, 50)
            end
        end
    end
    AscendancyBeacon.sync()
end
callable(AscendancyBeacon, "toggleBeacon")

function AscendancyBeacon.upgradeTier()
    if not onServer() or not record or record.state ~= "active" or record.tier >= 5 then return end
    local owner, player = authorize(true)
    if not owner then return end
    local targetTier = record.tier + 1
    local creditCost, material, materialCost = AscendancyBeacon.getUpgradeCost(targetTier)
    local enough = resourcesAvailable(owner, material, materialCost)
    if owner.money < creditCost or not enough then
        player:sendChatMessage("Beacon"%_t, 1,
            "Insufficient resources to upgrade to Tier %1%."%_t, targetTier)
        return
    end
    local working = CAState.DeepCopy(record)
    working.state = "upgrade_prepared"
    working.pendingOperation = {
        operationId = record.beaconId .. ":upgrade:" .. tostring(targetTier),
        targetTier = targetTier, creditCost = creditCost,
        material = material.value, materialCost = materialCost
    }
    if not saveRecord(working) then return end
    if not debitAndVerify(owner, "Ascendancy Beacon Upgrade"%_t,
            creditCost, material, materialCost) then
        enterRepair("upgrade_debit_unverified")
        return
    end
    local upgraded, summary = requestClaim("upsert", claimPayload(targetTier))
    if not upgraded then
        enterRepair("upgrade_claim_unverified:" .. tostring(summary))
        return
    end
    working = CAState.DeepCopy(record)
    working.tier = targetTier
    working.state = "active"
    working.pendingOperation = nil
    working.lastError = nil
    working.repairRequired = nil
    if not persistAfterSideEffect(working, "beacon_upgrade_persistence_failed") then return end
    syncFactionTier(owner, summary)
    player:sendChatMessage("Beacon"%_t, 0,
        "Ascendancy Beacon upgraded to Tier %1%!"%_t, targetTier)
    if targetTier == 3 then
        player:sendChatMessage("Beacon"%_t, 0,
            "Sanctuary Field online! Nearby Eclipse conquest attempts will now be repelled."%_t)
    end
    if cv_news and cv_news.publishArticle then
        cv_news.publishArticle({
            title = "Empire Ascends to Tier " .. targetTier,
            content = "The " .. owner.name .. " Empire has upgraded an Ascendancy Beacon to Tier "
                .. targetTier .. ". Their fleet's global power has increased significantly.",
            category = "Galactic Expansion"
        })
    end
    AscendancyBeacon.sync()
end
callable(AscendancyBeacon, "upgradeTier")

function AscendancyBeacon.onDestroyed()
    if not onServer() or not record then return end
    deactivateInternal("destroyed")
end

function AscendancyBeacon.getUpdateInterval()
    return 60
end

function AscendancyBeacon.getLeaseState()
    return record and record.state == "active", record and record.revision
end

function AscendancyBeacon.updateServer(timeStep)
    if not record then return end
    if record.state == "repair_required" then processRepairAction() end
    if record.state ~= "active" then return end
    local x, y = Sector():getCoordinates()
    Galaxy():sendCallback("onAscendancyBeaconPing", record.beaconId,
        record.ownerFactionIndex, x, y, record.revision)
    local current = now()
    if current - record.lastUpkeepTime >= UPKEEP_INTERVAL then
        local owner = Faction(record.ownerFactionIndex)
        local creditCost, material, materialCost, registryAvailable = AscendancyBeacon.getUpkeepCost()
        if not registryAvailable then return end
        local enough = owner and resourcesAvailable(owner, material, materialCost)
        if not owner or owner.money < creditCost or not enough then
            if owner then owner:sendChatMessage("Beacon"%_t, 1,
                "Ascendancy Beacon lost power! Upkeep failed."%_t) end
            deactivateInternal("upkeep_failed")
            return
        end
        local working = CAState.DeepCopy(record)
        working.state = "upkeep_prepared"
        working.pendingOperation = {
            operationId = record.beaconId .. ":upkeep:" .. tostring(record.lastUpkeepTime),
            creditCost = creditCost, material = material.value, materialCost = materialCost
        }
        if not saveRecord(working) then return end
        if not debitAndVerify(owner, "Ascendancy Beacon Upkeep"%_t,
                creditCost, material, materialCost) then
            enterRepair("upkeep_debit_unverified")
            return
        end
        working = CAState.DeepCopy(record)
        working.state = "active"
        working.lastUpkeepTime = current
        working.pendingOperation = nil
        if not persistAfterSideEffect(working, "beacon_upkeep_persistence_failed") then return end
        owner:sendChatMessage("Beacon"%_t, 3,
            "Ascendancy Beacon upkeep paid: %1% Cr, %2% %3%",
            createMonetaryString(creditCost), createMonetaryString(materialCost), material.name)
        if record.treasury > 0 then
            local payout = record.treasury
            working = CAState.DeepCopy(record)
            working.state = "treasury_prepared"
            working.pendingOperation = {
                operationId = record.beaconId .. ":treasury:" .. tostring(record.revision + 1),
                amount = payout
            }
            if not saveRecord(working) then return end
            local beforeMoney = owner.money or 0
            owner:receive("Grand Toll Treasury Payout", payout)
            if (owner.money or 0) < beforeMoney + payout then
                enterRepair("treasury_payout_unverified")
                return
            end
            working = CAState.DeepCopy(record)
            working.treasury = 0
            working.state = "active"
            working.pendingOperation = nil
            if not persistAfterSideEffect(working, "beacon_treasury_persistence_failed") then return end
            owner:sendChatMessage("Beacon"%_t, 3,
                "Grand Toll Treasury payout: %1% credits received.",
                createMonetaryString(payout))
        end
    end
    if current > record.lastSiegeTime + record.nextSiegeInterval then
        local working = CAState.DeepCopy(record)
        working.state = "siege_prepared"
        working.lastSiegeTime = current
        working.nextSiegeInterval = random():getInt(3, 6) * 3600
        working.pendingOperation = {
            operationId = record.beaconId .. ":siege:" .. tostring(current),
            tier = record.tier, ownerFactionIndex = record.ownerFactionIndex
        }
        if not saveRecord(working) then return end
        Sector():addScriptOnce("data/scripts/events/ascendancysiege.lua",
            record.tier, record.ownerFactionIndex)
        if not Sector():hasScript("data/scripts/events/ascendancysiege.lua") then
            enterRepair("siege_script_attachment_failed")
            return
        end
        working = CAState.DeepCopy(record)
        working.state = "active"
        working.pendingOperation = nil
        if not persistAfterSideEffect(working, "beacon_siege_persistence_failed") then return end
    end
end

function AscendancyBeacon.sync(data)
    if onServer() then
        local player = Player(callingPlayer)
        if player then
            invokeClientFunction(player, "sync", {
                active = record and record.state == "active",
                currentTier = record and record.tier or 1,
                state = record and record.state or "unavailable",
                repairRequired = record and record.repairRequired
            })
        end
        return
    end
    if not data then
        invokeServerFunction("sync")
        return
    end

    active = data.active == true
    currentTier = data.currentTier or 1
    AscendancyBeacon.clientState = data.state
    AscendancyBeacon.clientRepair = data.repairRequired
    if not AscendancyBeacon.statusLabel then return end
    AscendancyBeacon.tierLabel.caption = "Current Tier: " .. currentTier
    if AscendancyBeacon.clientState == "repair_required" then
        AscendancyBeacon.statusLabel.caption = "REPAIR REQUIRED"%_t
        AscendancyBeacon.statusLabel.color = ColorRGB(1, 0.5, 0)
        AscendancyBeacon.toggleBtn.active = false
        AscendancyBeacon.upgradeBtn.active = false
    elseif active then
        AscendancyBeacon.statusLabel.caption = "ONLINE (renewable sector lease)"%_t
        AscendancyBeacon.statusLabel.color = ColorRGB(0, 1, 0)
        AscendancyBeacon.toggleBtn.caption = "Deactivate"%_t
        AscendancyBeacon.toggleBtn.active = true
        AscendancyBeacon.upgradeBtn.active = currentTier < 5
    else
        AscendancyBeacon.statusLabel.caption = "OFFLINE"%_t
        AscendancyBeacon.statusLabel.color = ColorRGB(1, 0, 0)
        AscendancyBeacon.toggleBtn.caption = "Activate"%_t
        AscendancyBeacon.toggleBtn.active = true
        AscendancyBeacon.upgradeBtn.active = false
    end
    if currentTier >= 5 then AscendancyBeacon.upgradeBtn.caption = "Max Tier Reached"%_t
    else AscendancyBeacon.upgradeBtn.caption = "Upgrade to Tier " .. (currentTier + 1) end
    invokeServerFunction("syncCosts")
end
callable(AscendancyBeacon, "sync")

function AscendancyBeacon.syncCosts()
    if not onServer() then return end
    local player = Player(callingPlayer)
    if not player then return end
    local creditCost, material, materialCost = AscendancyBeacon.getUpkeepCost()
    local upgradeCredits, upgradeMaterial, upgradeMaterialCost = 0, Material(0), 0
    if record and record.tier < 5 then
        upgradeCredits, upgradeMaterial, upgradeMaterialCost =
            AscendancyBeacon.getUpgradeCost(record.tier + 1)
    end
    invokeClientFunction(player, "receiveCosts", creditCost, material.name,
        materialCost, upgradeCredits, upgradeMaterial.name, upgradeMaterialCost)
end
callable(AscendancyBeacon, "syncCosts")

function AscendancyBeacon.receiveCosts(creditCost, materialName, materialCost,
        upgradeCredits, upgradeMaterialName, upgradeMaterialCost)
    if not AscendancyBeacon.costLabel then return end
    local text = "Upkeep per 45 Minutes:\n" .. createMonetaryString(creditCost)
        .. " Credits\n" .. createMonetaryString(materialCost) .. " " .. materialName
    if currentTier < 5 then
        text = text .. "\n\nUpgrade Cost (Tier " .. (currentTier + 1) .. "):\n"
            .. createMonetaryString(upgradeCredits) .. " Credits\n"
            .. createMonetaryString(upgradeMaterialCost) .. " " .. upgradeMaterialName
    end
    AscendancyBeacon.costLabel.caption = text
end

function AscendancyBeacon.secure()
    return {record = record}
end

function AscendancyBeacon.restore(data)
    if not onServer() then return end
    data = data or {}
    if data.record and data.record.schemaVersion == 1 then
        record = data.record
        CosmicVaultData.SetRecord(Entity(), RECORD_KEY, record)
    elseif data.active ~= nil or data.currentTier ~= nil then
        record = newRecord()
        record.state = data.active and "active" or "inactive"
        record.tier = math.max(1, math.min(5, tonumber(data.currentTier) or 1))
        record.lastUpkeepTime = data.lastUpkeepTime or now()
        record.lastSiegeTime = data.lastSiegeTime or now()
        record.nextSiegeInterval = data.nextSiegeInterval or random():getInt(3, 6) * 3600
        record.treasury = math.max(0, tonumber(data.treasury) or 0)
        record.migration = {source = "legacy_secure", migratedAt = now()}
        saveRecord()
    elseif not record then
        loadRecord()
    end
    if record.state == "activation_prepared" or record.state == "upgrade_prepared"
            or record.state == "upkeep_prepared" or record.state == "deactivation_prepared"
            or record.state == "treasury_prepared" or record.state == "siege_prepared" then
        enterRepair("restart_during_prepared_operation")
        return
    end
    refreshMirrors()
    if record.state == "active" then
        local revision, summary = requestClaim("upsert")
        if not revision then
            enterRepair(summary == "limit_reached" and "legacy_beacon_limit_exceeded"
                or "beacon_claim_restore_failed:" .. tostring(summary))
        else
            syncFactionTier(Faction(record.ownerFactionIndex), summary)
        end
    end
end
