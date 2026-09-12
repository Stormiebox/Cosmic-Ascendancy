package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
local CosmicVaultData = include("cosmicvaultdata")
local CAState = include("ca_state")
local CAMigration = include("ca_migration")

-- namespace AscendancyCampaign
AscendancyCampaign = {}

local CAMPAIGN_KEY = "ca_campaign_v2"
local CONTROLLER_PATH = "data/scripts/player/background/ca_campaign_controller.lua"
local COORDINATOR_PATH = "data/scripts/galaxy/ca_state_coordinator.lua"
local campaign
local loadError

local rewards = {
    [1] = {credits = 2500000, turrets = 2, systems = 1, rarity = RarityType.Rare},
    [2] = {credits = 5000000, turrets = 2, systems = 2, rarity = RarityType.Exceptional},
    [3] = {
        credits = 7500000,
        turrets = 2,
        systems = 1,
        rarity = RarityType.Exotic,
        uniqueSystem = "data/scripts/systems/ascendanteclipsebane.lua"
    },
    [4] = {credits = 10000000, turrets = 3, systems = 2, rarity = RarityType.Exotic},
    [5] = {credits = 25000000, turrets = 5, systems = 3, rarity = RarityType.Legendary}
}

local function now()
    return Server().unpausedRuntime
end

local function saveCampaign(nextCampaign)
    local working = CAState.DeepCopy(nextCampaign)
    CAState.Touch(working, now())
    local saved, err = CosmicVaultData.SetRecord(Player(), CAMPAIGN_KEY, working)
    if not saved then return nil, err end
    campaign = working
    loadError = nil
    return true, nil
end

local function legacyEvidence(player)
    local attached = {}
    for _, script in pairs({player:getScripts()}) do attached[script] = true end
    local values = {}
    for _, key in pairs(CAMigration.DebriefByChapter) do values[key] = player:getValue(key) end
    local missionTargets = {}
    for chapter, script in pairs(CAMigration.MissionByChapter) do
        if attached[script] then
            local resultCode, x, y = player:invokeFunction(script, "getCampaignMigrationTarget")
            if resultCode == 0 and type(x) == "number" and type(y) == "number" then
                missionTargets[chapter] = {x = x, y = y}
            end
        end
    end
    return {
        completed = player:getValue("ca_campaign_completed") == true,
        attachedMissions = attached,
        missionTargets = missionTargets,
        values = values,
        forgeUnlocked = player:getValue("ca_forge_unlocked") == true
    }
end

local function guardianConfirmed()
    local state = CosmicVaultData.GetRecord(Server(), "ca_state_v2", 2)
    return state and state.guardian and state.guardian.state == "confirmed" or false
end

local function reconcilePreparedReward()
    if not campaign or campaign.phase ~= "reward_prepared" or not campaign.pendingReward then
        return nil, "invalid_campaign_state"
    end
    local receiptRegistry, receiptError = CosmicVaultData.GetRecord(Server(), "ca_receipts_v1", 1)
    if receiptRegistry and type(receiptRegistry.receipts) ~= "table" then
        receiptRegistry = nil
        receiptError = "corrupt"
    end
    local receipt = receiptRegistry and receiptRegistry.receipts[campaign.pendingReward.operationId]
    local working = CAState.DeepCopy(campaign)
    if receipt and receipt.state == "succeeded" then
        working.phase = "chapter_complete"
        working.pendingReward.state = "succeeded"
        working.pendingReward.completedAt = receipt.completedAt
        working.pendingReward.evidence = CAState.DeepCopy(receipt.evidence)
    elseif receiptError == "missing" or (receiptRegistry and not receipt) then
        -- The globally owned preparation never happened, so delivery cannot have begun.
        working.phase = "debrief_pending"
        working.pendingReward = nil
    else
        working.phase = "repair_required"
        working.repairRequired = "reward_delivery_ambiguous_after_restart"
        working.lastError = receiptError or (receipt and receipt.state) or "receipt_unavailable"
    end
    return saveCampaign(working)
end

local function loadCampaign()
    local loaded, err = CosmicVaultData.GetRecord(Player(), CAMPAIGN_KEY, 2)
    if loaded then
        local valid, validationError = CAState.ValidateCampaignState(loaded)
        if not valid then
            campaign = nil
            loadError = validationError
            return nil, validationError
        end
        campaign = loaded
        if campaign.phase == "reward_reissue_prepared" then
            local working = CAState.DeepCopy(campaign)
            working.phase = "repair_required"
            working.repairRequired = "administrator_reissue_ambiguous_after_restart"
            working.lastError = "reward_delivery_cannot_be_proven"
            return saveCampaign(working)
        end
        if campaign.phase == "reward_prepared" and campaign.pendingReward then
            return reconcilePreparedReward()
        end
        if campaign.phase == "active" and campaign.mission and campaign.mission.script
                and not Player():hasScript(campaign.mission.script) then
            local working = CAState.DeepCopy(campaign)
            working.phase = "repair_required"
            working.repairRequired = "active_mission_missing"
            working.lastError = "mission_completion_or_attachment_cannot_be_proven"
            return saveCampaign(working)
        end
        return true
    end
    if err ~= "missing" then
        loadError = err
        return nil, err
    end

    local migrated = CAMigration.AnalyzeCampaign(legacyEvidence(Player()), guardianConfirmed(), now())
    if (migrated.phase == "active" or migrated.phase == "debrief_pending") and migrated.target == nil then
        migrated.phase = "repair_required"
        migrated.repairRequired = "legacy_mission_target_unavailable"
    elseif migrated.phase == "contact_pending" and Player():getValue("ca_forge_unlocked") then
        migrated.phase = "repair_required"
        migrated.repairRequired = "unprovable_legacy_reward_gap"
    end
    return saveCampaign(migrated)
end

local function chooseTarget(chapter)
    local x, y = Player():getSectorCoordinates()
    if type(x) ~= "number" or type(y) ~= "number" then x, y = 0, 0 end
    if chapter == 3 then return {x = x, y = y} end

    local MissionUT = include("missionutility")
    local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
    local targetX, targetY = MissionUT.getEmptySector(x, y, 5, 30, insideBarrier)
    if not targetX or not targetY then
        local rand = Random()
        local offsetX, offsetY
        repeat
            offsetX = rand:getInt(-30, 30)
            offsetY = rand:getInt(-30, 30)
        until offsetX ~= 0 or offsetY ~= 0
        targetX, targetY = x + offsetX, y + offsetY
    end
    return {x = targetX, y = targetY}
end

local function mailId(chapter)
    return "ca_v2_campaign_chapter_" .. tostring(chapter) .. "_rendezvous"
end

local function sendChapterMail(record)
    local id = mailId(record.chapter)
    local existing = {Player():getMailsById(id)}
    if #existing > 0 then return true end

    local mail = Mail()
    mail.id = id
    mail.header = Format("Secure Transmission"%_T)
    mail.sender = Format("Aegis"%_T)
    mail.text = Format(
        "Commander, proceed to the secured Ascendancy coordinates (%1%:%2%). The next operation is ready."%_T,
        record.target.x,
        record.target.y)
    Player():addMail(mail)
    return #{Player():getMailsById(id)} > 0
end

local function prepareChapter(chapter)
    if not campaign or campaign.phase ~= "contact_pending" then return nil, "invalid_phase" end
    local working = CAState.DeepCopy(campaign)
    working.chapter = chapter
    working.phase = "contact_prepared"
    working.target = chooseTarget(chapter)
    working.mail = {id = mailId(chapter), state = "prepared"}
    working.mission = {script = CAMigration.MissionByChapter[chapter], state = "prepared"}
    local saved, err = saveCampaign(working)
    if not saved then return nil, err end
    return true
end

local function attachPreparedChapter()
    if not campaign or campaign.phase ~= "contact_prepared" then return nil, "invalid_phase" end
    if not campaign.target or type(campaign.target.x) ~= "number" or type(campaign.target.y) ~= "number" then
        local working = CAState.DeepCopy(campaign)
        working.phase = "repair_required"
        working.repairRequired = "missing_campaign_target"
        saveCampaign(working)
        return nil, "missing_campaign_target"
    end

    if not sendChapterMail(campaign) then return nil, "mail_not_verified" end
    local working = CAState.DeepCopy(campaign)
    working.mail.state = "sent"
    saveCampaign(working)

    local script = campaign.mission.script
    Player():addScriptOnce(script)
    if not Player():hasScript(script) then return nil, "mission_not_verified" end

    working = CAState.DeepCopy(campaign)
    working.phase = "active"
    working.mission.state = "attached"
    working.aegis = {state = "unknown", encounterId = nil}
    working.repairRequired = nil
    working.lastError = nil
    saveCampaign(working)
    return true
end

local function coordinatorCall(functionName, ...)
    local resultCode, first, second = Galaxy():invokeFunction(COORDINATOR_PATH, functionName, ...)
    if resultCode ~= 0 then return nil, "coordinator_unavailable" end
    return first, second
end

local function receiptRevision()
    local revisions, err = coordinatorCall("getRegistryRevisions")
    if not revisions then return nil, err end
    return revisions.receipts
end

local function deliverReward(chapter, operationId)
    local reward = rewards[chapter]
    if not reward then return true, {credits = 0, inventoryItems = 0} end

    local player = Player()
    local beforeMoney = player.money or 0
    local x, y = player:getSectorCoordinates()
    local generator = include("sectorturretgenerator")(Sector().seed)
    local UpgradeGenerator = include("upgradegenerator")
    local inserted = 0

    player:receive(chapter == 5 and "Ascendant Heritage" or "Ascendant Support Funding", reward.credits)
    for _ = 1, reward.turrets do
        local turret = generator:generateArmed(x, y, 0, Rarity(reward.rarity))
        local index = player:getInventory():add(InventoryTurret(turret))
        if type(index) == "number" then inserted = inserted + 1 end
    end
    for _ = 1, reward.systems do
        local system = UpgradeGenerator():generateSectorSystem(x, y, Rarity(reward.rarity))
        local index = player:getInventory():add(system)
        if type(index) == "number" then inserted = inserted + 1 end
    end
    if reward.uniqueSystem then
        local system = SystemUpgradeTemplate(reward.uniqueSystem, Rarity(5), Seed(123))
        local index = player:getInventory():add(system)
        if type(index) == "number" then inserted = inserted + 1 end
    end

    local expectedItems = reward.turrets + reward.systems + (reward.uniqueSystem and 1 or 0)
    local moneyVerified = (player.money or 0) >= beforeMoney + reward.credits
    if not moneyVerified or inserted ~= expectedItems then
        return nil, {
            operationId = operationId,
            creditsObserved = (player.money or 0) - beforeMoney,
            inventoryItemsObserved = inserted,
            expectedItems = expectedItems
        }
    end
    return true, {operationId = operationId, credits = reward.credits, inventoryItems = inserted}
end

local function finalizeCompletedChapter(chapter)
    local working = CAState.DeepCopy(campaign)
    if chapter == 5 then
        working.phase = "campaign_complete"
        working.completedAt = now()
        working.target = nil
        working.mission = {script = nil, state = "none"}
        local state = CosmicVaultData.GetRecord(Server(), "ca_state_v2", 2)
        if not state then
            working.phase = "repair_required"
            working.repairRequired = "global_activation_state_unavailable"
            working.lastError = "ca_state_v2_unavailable"
            return saveCampaign(working)
        end
        local activated, activationError = coordinatorCall("requestCampaignCompletion",
            CONTROLLER_PATH, state.revision, Player().index)
        if not activated then
            working.phase = "repair_required"
            working.repairRequired = "global_activation_unverified"
            working.lastError = tostring(activationError)
        end
        return saveCampaign(working)
    end

    working.chapter = chapter + 1
    working.phase = "contact_pending"
    working.target = nil
    working.mail = {id = nil, state = "none"}
    working.mission = {script = nil, state = "none"}
    working.aegis = {state = "unknown", encounterId = nil}
    working.pendingReward = nil
    local saved, err = saveCampaign(working)
    if not saved then return nil, err end
    local prepared, prepareError = prepareChapter(chapter + 1)
    if not prepared then return nil, prepareError end
    return attachPreparedChapter()
end

local function completeChapter(chapter)
    if chapter == 0 then
        local working = CAState.DeepCopy(campaign)
        working.chapter = 1
        working.phase = "contact_pending"
        working.target = nil
        working.pendingReward = nil
        saveCampaign(working)
        return prepareChapter(1) and attachPreparedChapter()
    end

    local playerIndex = Player().index
    local operationId = tostring(playerIndex) .. ":campaign:" .. tostring(chapter) .. ":reward"
    local working = CAState.DeepCopy(campaign)
    working.phase = "reward_prepared"
    working.pendingReward = {
        schemaVersion = 1,
        revision = 0,
        operationId = operationId,
        chapter = chapter,
        state = "prepared",
        preparedAt = now()
    }
    local saved, saveError = saveCampaign(working)
    if not saved then return nil, saveError end

    local revision, revisionError = receiptRevision()
    if not revision then
        working = CAState.DeepCopy(campaign)
        working.phase = "debrief_pending"
        working.pendingReward = nil
        working.lastError = tostring(revisionError)
        saveCampaign(working)
        return nil, revisionError
    end
    local receipt, nextRevision = coordinatorCall("requestReceipt", CONTROLLER_PATH, revision, "prepare", {
        operationId = operationId,
        kind = "campaign_reward",
        recipient = {playerIndex = playerIndex},
        reissue = {mode = "campaign_controller"}
    })
    if not receipt then
        working = CAState.DeepCopy(campaign)
        working.phase = "repair_required"
        working.repairRequired = "reward_receipt_ambiguous"
        working.lastError = tostring(nextRevision)
        saveCampaign(working)
        return nil, nextRevision
    end

    local delivered, evidence = deliverReward(chapter, operationId)
    if not delivered then
        working = CAState.DeepCopy(campaign)
        working.phase = "repair_required"
        working.repairRequired = "reward_delivery_unverified"
        working.lastError = "reward_delivery_unverified"
        working.pendingReward.evidence = evidence
        saveCampaign(working)
        return nil, "reward_delivery_unverified"
    end

    local completed, completionError = coordinatorCall("requestReceipt", CONTROLLER_PATH,
        nextRevision, "complete", {operationId = operationId, evidence = evidence})
    if not completed then
        working = CAState.DeepCopy(campaign)
        working.phase = "repair_required"
        working.repairRequired = "reward_receipt_completion_ambiguous"
        working.lastError = tostring(completionError)
        working.pendingReward.evidence = evidence
        saveCampaign(working)
        return nil, completionError
    end

    working = CAState.DeepCopy(campaign)
    working.phase = "chapter_complete"
    working.pendingReward.state = "succeeded"
    working.pendingReward.completedAt = now()
    working.pendingReward.evidence = evidence
    saved, saveError = saveCampaign(working)
    if not saved then return nil, saveError end
    return finalizeCompletedChapter(chapter)
end

local function processAdministratorRepair()
    if not campaign or campaign.phase ~= "repair_required" then return end
    local originalRevision = campaign.revision
    local request = coordinatorCall("getCampaignRepairAction", CONTROLLER_PATH,
        Player().index, originalRevision)
    if not request then return end
    local working = CAState.DeepCopy(campaign)
    if request.action == "abandon" then
        working.phase = "repair_abandoned"
        working.pendingReward = nil
    elseif request.action == "mark-complete" then
        working.phase = "chapter_complete"
        if working.pendingReward then
            working.pendingReward.state = "administrator_mark_complete"
        end
    elseif request.action == "resume" then
        if working.repairRequired == "multiple_campaign_missions" then
            for _, script in pairs(CAMigration.MissionByChapter) do
                if script ~= working.mission.script and Player():hasScript(script) then
                    Player():removeScript(script)
                end
            end
            working.phase = Player():hasScript(working.mission.script)
                and "active" or "contact_prepared"
        elseif working.repairRequired == "active_mission_missing"
                or working.repairRequired == "missing_campaign_target"
                or working.repairRequired == "legacy_mission_target_unavailable" then
            working.target = working.target or chooseTarget(working.chapter)
            working.mail = working.mail or {id = mailId(working.chapter), state = "prepared"}
            working.mission = {
                script = CAMigration.MissionByChapter[working.chapter], state = "prepared"
            }
            working.phase = "contact_prepared"
        else
            working.phase = "chapter_complete"
        end
    elseif request.action == "reissue" then
        local pending = working.pendingReward
        if not pending or not pending.operationId then return end
        working.phase = "reward_reissue_prepared"
        working.repairRequired = "administrator_reissue_in_progress"
        if not saveCampaign(working) then return end
        working = CAState.DeepCopy(campaign)
        local delivered, evidence = deliverReward(working.chapter, pending.operationId)
        if not delivered then
            working.phase = "repair_required"
            working.repairRequired = "administrator_reissue_delivery_unverified"
            working.lastError = "reward_delivery_unverified"
            saveCampaign(working)
            return
        end
        local revision = receiptRevision()
        if not revision then
            working.phase = "repair_required"
            working.repairRequired = "administrator_reissue_receipt_unavailable"
            saveCampaign(working)
            return
        end
        local completed = coordinatorCall("requestReceipt", CONTROLLER_PATH,
            revision, "complete", {operationId = pending.operationId, evidence = evidence})
        if not completed then
            working.phase = "repair_required"
            working.repairRequired = "administrator_reissue_completion_ambiguous"
            saveCampaign(working)
            return
        end
        working.phase = "chapter_complete"
        working.pendingReward.state = "succeeded"
        working.pendingReward.completedAt = now()
        working.pendingReward.evidence = evidence
    else
        return
    end
    working.repairRequired = nil
    working.lastError = nil
    local saved = saveCampaign(working)
    if not saved then return end
    coordinatorCall("acknowledgeCampaignRepair", CONTROLLER_PATH,
        Player().index, originalRevision)
end

local function processUnreadableCampaignRepair()
    if campaign or not loadError then return end
    local request = coordinatorCall("getCampaignRepairAction", CONTROLLER_PATH,
        Player().index, -1)
    if not request or request.action ~= "abandon" or request.unreadableRecord ~= true then return end

    local replacement = CAState.NewCampaignState(now())
    replacement.phase = "repair_abandoned"
    replacement.migrationVersion = 2
    replacement.migration.sources = {"administrator_abandoned_unreadable_ca_campaign_v2"}
    replacement.migration.warnings = {
        "The unreadable campaign record was explicitly abandoned by an administrator."
    }
    replacement.lastError = nil
    replacement.repairRequired = nil
    local saved = saveCampaign(replacement)
    if not saved then return end
    coordinatorCall("acknowledgeCampaignRepair", CONTROLLER_PATH, Player().index, -1)
end

function AscendancyCampaign.initialize()
    if not onServer() then return end
    loadCampaign()
    Player():registerCallback("onSectorEntered", "onSectorEntered")
end

function AscendancyCampaign.getUpdateInterval()
    return 5
end

function AscendancyCampaign.updateServer(timeStep)
    if loadError or not campaign then
        processUnreadableCampaignRepair()
        return
    end
    if campaign.phase == "repair_required" then processAdministratorRepair() end
    if campaign.phase == "locked" and guardianConfirmed() then
        local working = CAState.DeepCopy(campaign)
        working.phase = "contact_pending"
        saveCampaign(working)
    end
    if campaign.phase == "contact_pending" then prepareChapter(campaign.chapter) end
    if campaign.phase == "contact_prepared" then attachPreparedChapter() end
    if campaign.phase == "reward_prepared" then reconcilePreparedReward() end
    if campaign.phase == "chapter_complete" then finalizeCompletedChapter(campaign.chapter) end
end

function AscendancyCampaign.onSectorEntered(playerIndex, x, y, changeType)
    local LoreAnomalies = include("player/background/ca_story_lore_anomalies")
    if LoreAnomalies and LoreAnomalies.onSectorEntered then
        LoreAnomalies.onSectorEntered(playerIndex, x, y, changeType or SectorChangeType.Jump)
    end
end

function AscendancyCampaign.getSnapshot()
    if not campaign then return nil, loadError or "not_initialized" end
    return CAState.Snapshot(campaign), nil
end

function AscendancyCampaign.requestDebrief(chapter, targetX, targetY, expectedRevision)
    if not onServer() then return nil, "server_only" end
    if not campaign or campaign.revision ~= expectedRevision then return nil, "revision_mismatch" end
    if campaign.chapter ~= chapter or campaign.phase ~= "active" then return nil, "invalid_campaign_state" end
    if type(targetX) ~= "number" or type(targetY) ~= "number" then return nil, "invalid_target" end

    local working = CAState.DeepCopy(campaign)
    working.phase = "debrief_pending"
    working.target = {x = targetX, y = targetY}
    working.aegis = {state = "materialized", encounterId = nil}
    local saved, err = saveCampaign(working)
    if not saved then return nil, err end
    return campaign.revision, nil
end

function AscendancyCampaign.acceptDebrief(chapter, expectedRevision, interactingPlayerIndex)
    if not onServer() then return nil, "server_only" end
    if interactingPlayerIndex ~= Player().index then return nil, "caller_mismatch" end
    if not campaign or campaign.revision ~= expectedRevision then return nil, "revision_mismatch" end
    if campaign.chapter ~= chapter or campaign.phase ~= "debrief_pending" then
        return nil, "invalid_campaign_state"
    end
    return completeChapter(chapter)
end

function AscendancyCampaign.beginEligibleCampaign()
    if not campaign or campaign.phase ~= "locked" or not guardianConfirmed() then return nil, "not_eligible" end
    local working = CAState.DeepCopy(campaign)
    working.phase = "contact_pending"
    return saveCampaign(working)
end
