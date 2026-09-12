package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
include("utility")
include("stringutility")
include("faction")
include("goods")
include("weapontypeutility")
local TurretGenerator = include("turretgenerator")
-- Removed hard dependency on cosmicwar_bridge
local cv_buffs = include("cosmicvaultbuffs")
local cv_goods = include("cosmicvaultgoods")
local CosmicVaultData = include("cosmicvaultdata")
local CosmicVaultEconomy = include("cosmicvaulteconomy")
local CAState = include("ca_state")

local ORDER_KEY = "ca_forge_v1"
local order
local selectedRecipeId = 1
local clientIsForging = false
local clientHasCompletedItem = false

local FORGE_TIME = 24 * 3600
local COORDINATOR = "data/scripts/galaxy/ca_state_coordinator.lua"
local OWNER = "data/scripts/entity/ascendancyforge.lua"

-- namespace AscendancyForge
AscendancyForge = {}

local weaponChoices = {
    {name = "Ascendant Chaingun", value = WeaponType.ChainGun},
    {name = "Ascendant Point Defense", value = WeaponType.PointDefenseChainGun},
    {name = "Ascendant Anti-Fighter", value = WeaponType.AntiFighter},
    {name = "Ascendant Bolter", value = WeaponType.Bolter},
    {name = "Ascendant Laser", value = WeaponType.Laser},
    {name = "Ascendant Plasma", value = WeaponType.PlasmaGun},
    {name = "Ascendant Rocket", value = WeaponType.RocketLauncher},
    {name = "Ascendant Cannon", value = WeaponType.Cannon},
    {name = "Ascendant Railgun", value = WeaponType.RailGun},
    {name = "Ascendant Tesla", value = WeaponType.TeslaGun},
    {name = "Ascendant Lightning", value = WeaponType.LightningGun},
    {name = "Ascendant Pulse Cannon", value = WeaponType.PulseCannon},
    {name = "Ascendant War-Drive", value = "data/scripts/systems/ascendantwardrive.lua"},
    {name = "Ascendant Aegis Matrix", value = "data/scripts/systems/ascendantaegis.lua"},
    {name = "Ascendant Slipstream Core", value = "data/scripts/systems/ascendantslipstream.lua"},
    {name = "Ascendant Omni-Sensor", value = "data/scripts/systems/ascendantomnisensor.lua"},
    {name = "Ascendant Swarm Nexus", value = "data/scripts/systems/ascendantswarmnexus.lua"},
    {name = "Ascendant Void-Drill", value = "data/scripts/systems/ascendantvoiddrill.lua"},
    {name = "Ascendant Neural Implant", value = "data/scripts/systems/ascendantneuralimplant.lua"},
    {name = "Ascendant World-Breaker (Titan Coaxial)", value = "titan_worldbreaker"},
}

for recipeId, recipe in ipairs(weaponChoices) do recipe.id = recipeId end

local function now() return Server().unpausedRuntime end

local function repairCoordinator(functionName, ...)
    local resultCode, first, second = Galaxy():invokeFunction(COORDINATOR, functionName, ...)
    if resultCode ~= 0 then return nil, "coordinator_unavailable" end
    return first, second
end

local function reportOrderRepair()
    if not order then return end
    if order.state == "repair_required" then
        local x, y = Sector():getCoordinates()
        repairCoordinator("requestEntityRepair", OWNER, "upsert", {
            entityId = Entity().id.string,
            kind = "forge",
            ownerFactionIndex = Entity().factionIndex,
            x = x,
            y = y,
            recordRevision = order.revision,
            reason = order.repairRequired or order.lastError
        })
    else
        repairCoordinator("requestEntityRepair", OWNER, "resolve", {
            entityId = Entity().id.string,
            recordRevision = order.revision
        })
    end
end

local function newOrderRecord()
    return {
        schemaVersion = 1, revision = 0, state = "idle", updatedAt = now(),
        orderId = nil, recipeId = nil, ownerFactionIndex = nil,
        requestingPlayerIndex = nil, weaponType = nil, seed = nil,
        costs = nil, sacrifices = nil, successRoll = nil, successRate = nil,
        intendedOutput = nil, createdAt = nil, completionAt = nil,
        receipt = nil, migration = {source = "new"}, repairRequired = nil, lastError = nil
    }
end

local function saveOrder(nextOrder)
    local persisted = CAState.DeepCopy(nextOrder)
    persisted.revision = (persisted.revision or 0) + 1
    persisted.updatedAt = now()
    local saved, err = CosmicVaultData.SetRecord(Entity(), ORDER_KEY, persisted)
    if not saved then return nil, err end
    order = persisted
    reportOrderRepair()
    return true, nil
end

local function persistAfterSideEffect(nextOrder, reason)
    local saved, err = saveOrder(nextOrder)
    if saved then return true, nil end

    order = CAState.DeepCopy(nextOrder)
    order.state = "repair_required"
    order.repairRequired = reason
    order.lastError = "record_write_failed_after_side_effect:" .. tostring(err)
    order.updatedAt = now()
    reportOrderRepair()
    return nil, err
end

local function loadOrder()
    local loaded, err = CosmicVaultData.GetRecord(Entity(), ORDER_KEY, 1)
    if loaded then
        order = loaded
        if order.state == "debit_prepared" or order.state == "claim_prepared" then
            local working = CAState.DeepCopy(order)
            working.state = "repair_required"
            working.repairRequired = order.state .. "_restart_ambiguity"
            working.lastError = "side_effect_completion_cannot_be_proven"
            saveOrder(working)
        end
        return
    end
    if err ~= "missing" then
        order = newOrderRecord()
        order.state = "repair_required"
        order.repairRequired = "forge_record_" .. tostring(err)
        order.lastError = tostring(err)
        return
    end
    saveOrder(newOrderRecord())
end

function AscendancyForge.initialize()
    if onServer() then
        loadOrder()
        reportOrderRepair()
    end
end

function AscendancyForge.interactionPossible(playerIndex, option)
    if not Player(playerIndex):getValue("ca_forge_unlocked") then return false end
    return checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageStations)
end

function AscendancyForge.getIcon()
    return "data/textures/icons/forge.png"
end

function AscendancyForge.initUI()
    local res = getResolution()
    -- +70px over the original 650 height, reserved entirely for the Ascendant Ward row below --
    -- added space rather than fitting into the already-dense existing 650px layout, since there's
    -- no way to visually verify a tighter fit without a running game to check against.
    local size = vec2(850, 720)
    local menu = ScriptUI()
    local window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    window.caption = "The Stellar Forge"%_t
    window.showCloseButton = 1
    window.moveable = 1
    menu:registerWindow(window, "Stellar Forge"%_t, 11)

    local hsplit = UIHorizontalSplitter(Rect(window.size), 10, 10, 0.45)

    AscendancyForge.inventory = window:createInventorySelection(hsplit.bottom, 12)
    AscendancyForge.inventory:setShowScrollArrows(true, true, 1.0)
    AscendancyForge.inventory.dragFromEnabled = 1
    AscendancyForge.inventory.onClickedFunction = "onInventoryClicked"

    local topSplit = UIVerticalSplitter(hsplit.top, 10, 10, 0.4)

    window:createLabel(Rect(topSplit.left.lower.x, topSplit.left.lower.y, topSplit.left.upper.x, topSplit.left.lower.y + 25), "Blueprint:"%_t, 14)
    AscendancyForge.combo = window:createComboBox(Rect(topSplit.left.lower.x, topSplit.left.lower.y + 30, topSplit.left.upper.x, topSplit.left.lower.y + 60), "onComboChanged")
    for _, choice in pairs(weaponChoices) do
        AscendancyForge.combo:addEntry(choice.name)
    end

    AscendancyForge.costLabel = window:createLabel(Rect(topSplit.left.lower.x, topSplit.left.lower.y + 70, topSplit.left.upper.x, topSplit.left.lower.y + 220), "", 12)

    window:createLabel(Rect(topSplit.right.lower.x, topSplit.right.lower.y, topSplit.right.upper.x, topSplit.right.lower.y + 25), "Sacrifice Legendary/Exotic Subsystems:", 14)

    AscendancyForge.sacrificeSelection = window:createSelection(Rect(topSplit.right.lower.x, topSplit.right.lower.y + 30, topSplit.right.lower.x + 350, topSplit.right.lower.y + 90), 5)
    AscendancyForge.sacrificeSelection.dropIntoEnabled = 1
    AscendancyForge.sacrificeSelection.entriesSelectable = 0
    AscendancyForge.sacrificeSelection.onReceivedFunction = "onSacrificeReceived"
    AscendancyForge.sacrificeSelection.onClickedFunction = "onSacrificeClicked"

    AscendancyForge.successRateLabel = window:createLabel(Rect(topSplit.right.lower.x, topSplit.right.lower.y + 100, topSplit.right.upper.x, topSplit.right.lower.y + 130), "Success Rate: 0%", 16)
    AscendancyForge.successRateLabel.color = ColorRGB(1, 0.5, 0)

    AscendancyForge.forgeBtn = window:createButton(Rect(topSplit.right.lower.x, topSplit.right.lower.y + 140, topSplit.right.lower.x + 180, topSplit.right.lower.y + 180), "Ignite Forge"%_t, "onForgePressed")
    AscendancyForge.claimBtn = window:createButton(Rect(topSplit.right.lower.x + 190, topSplit.right.lower.y + 140, topSplit.right.lower.x + 370, topSplit.right.lower.y + 180), "Claim Weapon"%_t, "onClaimPressed")

    AscendancyForge.statusLabel = window:createLabel(Rect(topSplit.right.lower.x, topSplit.right.lower.y + 190, topSplit.right.upper.x, topSplit.right.lower.y + 230), "", 16)

    AscendancyForge.tierLabel = window:createLabel(Rect(topSplit.left.lower.x, topSplit.left.lower.y + 230, topSplit.left.upper.x, topSplit.left.lower.y + 250), "Global Ascendancy Tier: 0", 14)
    AscendancyForge.decryptBtn = window:createButton(Rect(topSplit.left.lower.x, topSplit.left.lower.y + 255, topSplit.left.upper.x, topSplit.left.lower.y + 285), "Decrypt Eclipse Datacore"%_t, "onDecryptPressed")

    -- Ascendant Ward: instant craft, deliberately separate from the 24-hour weapon-forging queue
    -- above (that queue's claimWeapon() dispatch has no output path for a consumable item, and
    -- a Ward taking 24 hours to produce wouldn't fit its purpose as a quick tactical tool anyway).
    window:createFrame(Rect(10, 655, 840, 657))
    AscendancyForge.wardLabel = window:createLabel(vec2(10, 665), "Ascendant Ward: 10 Ascendant Matter + 20 Ascendant Scrap -- suppresses The Eclipse's own hunting behavior against you for 30 minutes."%_t, 13)
    AscendancyForge.wardBtn = window:createButton(Rect(660, 660, 840, 692), "Craft Ward"%_t, "onCraftWardPressed")

    AscendancyForge.sync()
end

function AscendancyForge.onComboChanged(comboBox, selectedIndex)
    if not onClient() then return end
    selectedRecipeId = selectedIndex + 1
end

function AscendancyForge.updateSelectedType(typ)
    -- Compatibility no-op. The server resolves recipeId from its fixed catalog at startForging().
end

function AscendancyForge.onShowWindow()
    AscendancyForge.sync()
    AscendancyForge.updateSuccessRate()
end

function AscendancyForge.updateSuccessRate()
    local rate = 0
    for _, item in pairs(AscendancyForge.sacrificeSelection:getItems()) do
        if item.item then
            if item.item.rarity.value == RarityType.Legendary then rate = rate + 20
            elseif item.item.rarity.value == RarityType.Exotic then rate = rate + 10 end
        end
    end

    local scrapNeeded = math.max(0, math.ceil((100 - rate) / 2))
    local craft = Player().craft
    local scrapToConsume = 0
    if craft then
        local scrapAmount = craft:getCargoAmount("Ascendant Scrap") or 0
        scrapToConsume = math.min(scrapAmount, scrapNeeded)
    end
    rate = rate + (scrapToConsume * 2)

    rate = math.min(100, rate)
    AscendancyForge.successRateLabel.caption = "Success Rate: " .. tostring(rate) .. "%"
    if rate >= 100 then
        AscendancyForge.successRateLabel.color = ColorRGB(0, 1, 0)
    elseif rate >= 50 then
        AscendancyForge.successRateLabel.color = ColorRGB(1, 1, 0)
    else
        AscendancyForge.successRateLabel.color = ColorRGB(1, 0.5, 0)
    end
end

-- Drag and Drop Handlers
function AscendancyForge.removeItemFromMainSelection(key)
    local item = AscendancyForge.inventory:getItem(key)
    if not item then return end
    if item.amount then
        item.amount = item.amount - 1
        AscendancyForge.inventory:add(item, key)
    end
end

function AscendancyForge.addItemToMainSelection(item)
    if not item or not item.item then return end
    if item.item.stackable then
        local key = AscendancyForge.inventory:find(item.item)
        if key then
            local existing = AscendancyForge.inventory:getItem(key)
            existing.amount = existing.amount + 1
            AscendancyForge.inventory:add(existing, key)
            return
        end
    end
    item.amount = 1
    AscendancyForge.inventory:add(item)
end

function AscendancyForge.moveItem(item, from, to, fkey, tkey)
    if not item then return end
    if from.index == AscendancyForge.inventory.index then
        if item.favorite then return end
        if tkey then
            AscendancyForge.addItemToMainSelection(to:getItem(tkey))
            to:remove(tkey)
        end
        AscendancyForge.removeItemFromMainSelection(fkey)
        item.amount = nil
        to:add(item, tkey)
    elseif to.index == AscendancyForge.inventory.index then
        AscendancyForge.addItemToMainSelection(item)
        from:remove(fkey)
    end
end

function AscendancyForge.onSacrificeReceived(selectionIndex, fkx, fky, item, fromIndex, toIndex, tkx, tky)
    if not item then return end
    if fromIndex == AscendancyForge.sacrificeSelection.index then return end

    if item.item.rarity.value < RarityType.Exotic then
        -- Reject anything below exotic
        return
    end

    AscendancyForge.moveItem(item, AscendancyForge.inventory, Selection(selectionIndex), ivec2(fkx, fky), ivec2(tkx, tky))
    AscendancyForge.updateSuccessRate()
end

function AscendancyForge.onSacrificeClicked(selectionIndex, fkx, fky, item, button)
    if button == 3 or button == 2 then
        AscendancyForge.moveItem(item, Selection(selectionIndex), AscendancyForge.inventory, ivec2(fkx, fky), nil)
        AscendancyForge.updateSuccessRate()
    end
end

function AscendancyForge.onInventoryClicked(selectionIndex, kx, ky, item, button)
    if button == 2 or button == 3 then
        if item.item.rarity.value < RarityType.Exotic then return end
        if item.favorite then return end

        local items = AscendancyForge.sacrificeSelection:getItems()
        if tablelength(items) < 5 then
            AscendancyForge.moveItem(item, AscendancyForge.inventory, AscendancyForge.sacrificeSelection, ivec2(kx, ky), nil)
            AscendancyForge.updateSuccessRate()
        end
    end
end

-- Server side logic
function AscendancyForge.getCosts()
    local x, y = Sector():getCoordinates()
    local dist = length(vec2(x, y))
    local scale = math.max(1, 6 - (dist / 100))

    local creditCost = math.floor(50000000 * scale)
    local matCost = random():getInt(25, 50)

    local ores = {}
    ores[1] = math.floor(1000000 * scale) -- Iron
    ores[2] = math.floor(800000 * scale)  -- Titanium
    ores[3] = math.floor(700000 * scale)  -- Naonite
    ores[4] = math.floor(600000 * scale)  -- Trinium
    ores[5] = math.floor(550000 * scale)  -- Xanion
    ores[6] = math.floor(520000 * scale)  -- Ogonite
    ores[7] = math.floor(500000 * scale)  -- Avorion

    return creditCost, "Ascendant Matter", matCost, ores
end

function AscendancyForge.syncCosts()
    if not onServer() then return end
    local creditCost, matName, matCost, ores = AscendancyForge.getCosts()
    invokeClientFunction(Player(callingPlayer), "receiveCosts", creditCost, matName, matCost, ores)
end

function AscendancyForge.receiveCosts(creditCost, matName, matCost, ores)
    if not AscendancyForge.costLabel then return end
    local caption = string.format("Forging Costs:\n%s Credits\n%s %s", createMonetaryString(creditCost), createMonetaryString(matCost), matName)
    local matNames = {"Iron", "Titanium", "Naonite", "Trinium", "Xanion", "Ogonite", "Avorion"}
    for i = 1, 7 do
        if ores[i] > 0 then
            caption = caption .. string.format("\n%s %s", createMonetaryString(ores[i]), matNames[i])
        end
    end
    caption = caption .. "\n\nCrafting Time: 24 Hours\nRequires sacrificing Legendary/Exotic subsystems to increase Success Rate."
    AscendancyForge.costLabel.caption = caption
end

function AscendancyForge.onForgePressed()
    if not onClient() then return end
    local itemIndices = {}
    for _, item in pairs(AscendancyForge.sacrificeSelection:getItems()) do
        if item.item then
            local amount = itemIndices[item.index] or 0
            amount = amount + 1
            itemIndices[item.index] = amount
        end
    end
    invokeServerFunction("startForging", itemIndices, selectedRecipeId)
end

function AscendancyForge.startForging(itemIndices, recipeId)
    if not onServer() then return end
    if not order then loadOrder() end
    if order.state == "running" or order.state == "ready_to_claim"
            or order.state == "debit_prepared" or order.state == "claim_prepared"
            or order.state == "repair_required" then return end
    if type(recipeId) ~= "number" or recipeId ~= math.floor(recipeId)
            or not weaponChoices[recipeId] then return end

    local owner, craft, player = getInteractingFaction(callingPlayer, AlliancePrivilege.ManageStations, AlliancePrivilege.SpendResources)
    if not owner then return end
    if not player or player.index ~= callingPlayer then return end
    if Entity().factionIndex ~= owner.index then
        player:sendChatMessage("Stellar Forge"%_t, 1, "Your faction does not own this Forge."%_t)
        return
    end
    if not craft then
        local p = Player(callingPlayer)
        if p then p:sendChatMessage("Stellar Forge"%_t, 1, "You must be inside a ship to ignite the forge."%_t) end
        return
    end

    local creditCost, matName, matCost, ores = AscendancyForge.getCosts()
    if owner.money < creditCost then
        owner:sendChatMessage("Stellar Forge"%_t, 1, "Insufficient credits!"%_t)
        return
    end
    local p_iron, p_tit, p_nao, p_tri, p_xan, p_ogo, p_avo = owner:getResources()
    if p_iron < ores[1] or p_tit < ores[2] or p_nao < ores[3] or p_tri < ores[4] or p_xan < ores[5] or p_ogo < ores[6] or p_avo < ores[7] then
        owner:sendChatMessage("Stellar Forge"%_t, 1, "Insufficient Ores to fuel the Forge!"%_t)
        return
    end

    local cargoAmount = craft:getCargoAmount(matName) or 0
    if cargoAmount < matCost then
        owner:sendChatMessage("Stellar Forge"%_t, 1, "Insufficient %s in your ship's cargo hold!"%_t, matName)
        return
    end

    -- Verify Sacrificed Items
    local successRate = 0
    local sacrifices = {}
    local sacrificeCount = 0
    if itemIndices then
        for index, amount in pairs(itemIndices) do
            if type(index) ~= "number" or type(amount) ~= "number" or amount < 1
                    or amount ~= math.floor(amount) then return end
            sacrificeCount = sacrificeCount + amount
            if sacrificeCount > 5 then return end
            local item = owner:getInventory():find(index)
            local has = owner:getInventory():amount(index)
            if not item or has < amount then
                player:sendChatMessage("Stellar Forge"%_t, 1, "You don't have the sacrificed items!"%_t)
                return
            end
            if item.rarity.value == RarityType.Legendary then
                successRate = successRate + (20 * amount)
            elseif item.rarity.value == RarityType.Exotic then
                successRate = successRate + (10 * amount)
            end
            table.insert(sacrifices, {index = index, amount = amount,
                rarity = item.rarity.value, beforeAmount = has})
        end
    end

    local scrapNeeded = math.max(0, math.ceil((100 - successRate) / 2))
    local scrapAmount = craft:getCargoAmount("Ascendant Scrap") or 0
    local scrapToConsume = math.min(scrapAmount, scrapNeeded)

    successRate = successRate + (scrapToConsume * 2)

    local recipe = weaponChoices[recipeId]
    local x, y = Sector():getCoordinates()
    local distBonus = 1.0 + (math.max(0, 500 - length(vec2(x, y))) / 250)
    local hostility = CosmicVaultEconomy.getGalacticHostilityIndex()
    local warBonus = math.min(10.0, 1.0 + math.max(0, hostility or 0) * 0.01)
    local successRoll = random():getInt(1, 100)
    local seed = random():getInt(1, 2147483646)
    local working = newOrderRecord()
    working.orderId = "forge:" .. Entity().id.string .. ":" .. tostring(math.floor(now()))
        .. ":" .. tostring(seed)
    working.recipeId = recipeId
    working.ownerFactionIndex = owner.index
    working.requestingPlayerIndex = callingPlayer
    working.weaponType = recipe.value
    working.seed = seed
    working.costs = {credits = creditCost, matterName = matName, matter = matCost,
        ores = ores, scrap = scrapToConsume}
    working.sacrifices = sacrifices
    working.successRoll = successRoll
    working.successRate = math.min(100, successRate)
    working.intendedOutput = {recipeName = recipe.name, value = recipe.value,
        distBonus = distBonus, warBonus = warBonus,
        failureScrap = random():getInt(10, 50)}
    working.createdAt = now()
    working.completionAt = working.createdAt + FORGE_TIME
    working.state = "debit_prepared"
    working.receipt = {operationId = working.orderId .. ":debit", state = "prepared"}
    local prepared, prepareError = saveOrder(working)
    if not prepared then return end

    -- Consume Costs
    local beforeMoney = owner.money
    local beforeResources = {owner:getResources()}
    owner:pay(creditCost, ores[1], ores[2], ores[3], ores[4], ores[5], ores[6], ores[7])
    craft:removeCargo(goods[matName], matCost)

    if scrapToConsume > 0 then
        craft:removeCargo(goods["Ascendant Scrap"], scrapToConsume)
    end

    if itemIndices then
        for index, amount in pairs(itemIndices) do
            for i = 1, amount do
                owner:getInventory():take(index)
            end
        end
    end

    local debitVerified = owner.money <= beforeMoney - creditCost
        and (craft:getCargoAmount(matName) or 0) <= cargoAmount - matCost
        and (craft:getCargoAmount("Ascendant Scrap") or 0) <= scrapAmount - scrapToConsume
    local afterResources = {owner:getResources()}
    for index = 1, 7 do
        if (afterResources[index] or 0) > (beforeResources[index] or 0) - ores[index] then
            debitVerified = false
        end
    end
    for _, sacrifice in ipairs(sacrifices) do
        if owner:getInventory():amount(sacrifice.index) > sacrifice.beforeAmount - sacrifice.amount then
            debitVerified = false
        end
    end
    if not debitVerified then
        working = CAState.DeepCopy(order)
        working.state = "repair_required"
        working.repairRequired = "forge_debit_unverified"
        working.lastError = "one_or_more_costs_could_not_be_verified"
        persistAfterSideEffect(working, "forge_debit_verification_persistence_failed")
        return
    end

    -- Roll RNG
    working = CAState.DeepCopy(order)
    working.receipt.state = "succeeded"
    working.receipt.completedAt = now()
    if successRoll <= successRate then
        working.state = "running"
        if not persistAfterSideEffect(working, "forge_debit_completion_persistence_failed") then return end
        owner:sendChatMessage("Stellar Forge"%_t, 0, "The Stellar Forge has ignited! Your weapon will be ready in 24 hours."%_t)
    else
        working.state = "failed_permanent"
        owner:sendChatMessage("Stellar Forge"%_t, 1, "The Forge failed to stabilize the Ascendant Matter! Your materials were consumed."%_t)
        -- Give Ascendant Scrap
        if cv_goods.registerGood then
            craft:addCargo(goods["Ascendant Scrap"], working.intendedOutput.failureScrap)
            owner:sendChatMessage("Stellar Forge"%_t, 2, "You salvaged some Ascendant Scrap from the failure.")
        end
        if not persistAfterSideEffect(working, "forge_failure_result_persistence_failed") then return end
    end

    AscendancyForge.sync()
end

function AscendancyForge.onClaimPressed()
    if onClient() then invokeServerFunction("claimWeapon"); return end
end

function AscendancyForge.claimWeapon()
    if not onServer() then return end
    if not order then loadOrder() end
    if order.state ~= "ready_to_claim" then return end
    local owner, craft, player = getInteractingFaction(callingPlayer, AlliancePrivilege.ManageStations)
    if not owner then return end
    if not player or player.index ~= callingPlayer then return end
    if Entity().factionIndex ~= owner.index or owner.index ~= order.ownerFactionIndex then return end
    local destinationInventory = owner:getInventory()
    if destinationInventory.occupiedSlots >= destinationInventory.maxSlots then
        player:sendChatMessage("Stellar Forge"%_t, 1,
            "The owning faction inventory has no room for the forged item."%_t)
        return
    end

    local working = CAState.DeepCopy(order)
    working.state = "claim_prepared"
    working.receipt = {operationId = order.orderId .. ":claim", state = "prepared"}
    if not saveOrder(working) then return end

    -- Core-proximity / War Heat scaling, computed once and shared by both the Titan World-Breaker
    -- and the standard weapon path below -- the Titan branch used to skip this entirely and always
    -- hand out a flat 250,000 damage, which a standard roll could already exceed 5x over at high
    -- war heat near the core, undercutting its framing as the Forge's top-tier reward.
    local distBonus = order.intendedOutput.distBonus
    local warBonus = order.intendedOutput.warBonus
    local selectedType = order.weaponType
    local output

    if type(selectedType) == "string" then
        if selectedType == "titan_worldbreaker" then
            local CosmicVaultArsenal = include("cosmicvaultarsenal")
            local titanDamage = 250000 * math.max(1.0, distBonus * warBonus)
            local config = {
                rarity = Rarity(RarityType.Legendary),
                material = Material(MaterialType.Avorion),
                weaponType = WeaponType.Laser,
                seed = Seed(order.seed),
                dps = titanDamage,
                tech = 52,
                coaxialAllowed = true,
                title = "Ascendant World-Breaker",
                icon = "data/textures/icons/laser-gun.png",
                size = 10.0,
                slots = 6
            }
            local turret, generationError = CosmicVaultArsenal.GenerateTypedTurret(config)
            if not turret or WeaponTypes.getTypeOfItem(turret) ~= WeaponType.Laser then
                owner:sendChatMessage("Stellar Forge"%_t, 1,
                    "The World-Breaker could not be materialized safely: " .. tostring(generationError or "weapon_type_mismatch"))
                working = CAState.DeepCopy(order)
                working.state = "repair_required"
                working.repairRequired = "forge_typed_output_unverified"
                working.lastError = tostring(generationError or "weapon_type_mismatch")
                persistAfterSideEffect(working, "forge_generation_failure_persistence_failed")
                return
            end

            turret.coaxial = true
            output = turret
            owner:sendChatMessage("Stellar Forge"%_t, 3, "Claimed Ascendant World-Breaker!")
        else
            local system = SystemUpgradeTemplate(selectedType, Rarity(5), Seed(order.seed))
            output = system
            owner:sendChatMessage("Stellar Forge"%_t, 3, "Claimed " .. system.name .. "!")
        end
    else
        local rarity = Rarity(5)
        local material = Material(6)
        local dps = 15000
        local turret = TurretGenerator.generateSeeded(Seed(order.seed), selectedType, dps, 52, rarity, material, true)
        if not turret then
            working = CAState.DeepCopy(order)
            working.state = "repair_required"
            working.repairRequired = "forge_output_generation_failed"
            working.lastError = "seeded_turret_generator_returned_nil"
            persistAfterSideEffect(working, "forge_generation_failure_persistence_failed")
            return
        end

        local finalMult = 3.0 * distBonus * warBonus
        local weapons = {turret:getWeapons()}
        turret:clearWeapons()
        for _, w in pairs(weapons) do
            w.damage = w.damage * finalMult
            w.reach = math.min(30000, w.reach * 2.0)
            turret:addWeapon(w)
        end
        turret.title = "Ascendant " .. turret.title
        turret.coaxial = false
        turret.slots = 1

        output = turret
        owner:sendChatMessage("Stellar Forge"%_t, 3, "Claimed " .. turret.title .. "!")
    end

    local inserted = output and destinationInventory:add(output)
    if type(inserted) ~= "number" or destinationInventory:amount(inserted) < 1 then
        working = CAState.DeepCopy(order)
        working.state = "repair_required"
        working.repairRequired = "forge_claim_unverified"
        working.lastError = "inventory_insertion_not_verified"
        persistAfterSideEffect(working, "forge_claim_verification_persistence_failed")
        return
    end
    working = CAState.DeepCopy(order)
    working.state = "claimed"
    working.receipt.state = "succeeded"
    working.receipt.completedAt = now()
    working.receipt.inventoryIndex = inserted
    if not persistAfterSideEffect(working, "forge_claim_completion_persistence_failed") then return end
    AscendancyForge.sync()
end

local function processRepairAction()
    if not order or order.state ~= "repair_required" then return end
    local action = repairCoordinator("getEntityRepairAction", OWNER,
        Entity().id.string, order.revision)
    if not action then return end
    local working = CAState.DeepCopy(order)
    if action == "abandon" then
        working.state = "abandoned"
    elseif action == "mark-complete" then
        working.state = "claimed"
        working.receipt = working.receipt or {operationId = working.orderId .. ":claim"}
        working.receipt.state = "succeeded"
        working.receipt.completedAt = now()
        working.receipt.evidence = "administrator_mark_complete"
    elseif action == "reissue" then
        working.state = "ready_to_claim"
        working.receipt = nil
    elseif action == "resume" then
        working.receipt = working.receipt or {operationId = working.orderId .. ":debit"}
        working.receipt.state = "succeeded"
        working.receipt.completedAt = now()
        working.receipt.evidence = "administrator_resume"
        if working.completionAt and working.completionAt <= now() then
            working.state = "ready_to_claim"
        else
            working.state = "running"
        end
    else
        return
    end
    working.repairRequired = nil
    working.lastError = nil
    saveOrder(working)
end

function AscendancyForge.getUpdateInterval() return 60 end

function AscendancyForge.updateServer(timeStep)
    if order and order.state == "repair_required" then processRepairAction() end
    if order and order.state == "running" then
        local pt = now()
        if pt >= order.completionAt then
            local working = CAState.DeepCopy(order)
            working.state = "ready_to_claim"
            local saved = saveOrder(working)
            if not saved then return end
            local owner = Faction(Entity().factionIndex)
            if owner then
                owner:sendChatMessage("Stellar Forge"%_t, 0, "Your Ascendant Weapon is ready to be claimed!"%_t)
            end
        end
    end
end

function AscendancyForge.secure()
    return {order = order}
end

function AscendancyForge.restore(data)
    data = data or {}
    if data.order and data.order.schemaVersion == 1 then
        if not order or order.orderId ~= data.order.orderId
                or (data.order.revision or 0) > (order.revision or 0) then
            saveOrder(CAState.DeepCopy(data.order))
        end
    elseif data.isForging or data.hasCompletedItem then
        local recipeId = 1
        for index, recipe in ipairs(weaponChoices) do
            if recipe.value == data.selectedType then recipeId = index; break end
        end
        order = newOrderRecord()
        order.orderId = "forge:" .. Entity().id.string .. ":legacy"
        order.recipeId = recipeId
        order.ownerFactionIndex = Entity().factionIndex
        order.requestingPlayerIndex = nil
        order.weaponType = weaponChoices[recipeId].value
        order.seed = random():getInt(1, 2147483646)
        order.createdAt = now()
        order.completionAt = data.forgeFinishTime or now()
        order.successRoll = data.willSucceed and 1 or 100
        order.successRate = data.willSucceed and 100 or 0
        order.intendedOutput = {recipeName = weaponChoices[recipeId].name,
            value = weaponChoices[recipeId].value, distBonus = 1, warBonus = 1}
        if data.isForging and data.hasCompletedItem then
            order.state = "repair_required"
            order.repairRequired = "contradictory_legacy_forge_state"
        elseif data.hasCompletedItem then
            order.state = "ready_to_claim"
        else
            order.state = "running"
        end
        order.migration = {source = "legacy_secure"}
        saveOrder(order)
    elseif not order then
        saveOrder(newOrderRecord())
    end
    if order and (order.state == "debit_prepared" or order.state == "claim_prepared") then
        local working = CAState.DeepCopy(order)
        working.state = "repair_required"
        working.repairRequired = order.state .. "_restart_ambiguity"
        working.lastError = "side_effect_completion_cannot_be_proven"
        saveOrder(working)
    end
end

function AscendancyForge.onDecryptPressed()
    if onClient() then invokeServerFunction("decryptDatacore"); return end
end

function AscendancyForge.decryptDatacore()
    if not onServer() then return end
    local owner, craft, player = getInteractingFaction(callingPlayer, AlliancePrivilege.ManageStations, AlliancePrivilege.SpendResources)
    if not owner then return end
    if not player or player.index ~= callingPlayer or owner.index ~= Entity().factionIndex then return end
    if not craft then
        local p = Player(callingPlayer)
        if p then p:sendChatMessage("Stellar Forge"%_t, 1, "You must be inside a ship to decrypt datacores."%_t) end
        return
    end

    local amount = craft:getCargoAmount("Eclipse Datacore") or 0
    if amount < 1 then
        player:sendChatMessage("Stellar Forge"%_t, 1, "You do not have any Eclipse Datacores in your ship's cargo hold!"%_t)
        return
    end

    craft:removeCargo(goods["Eclipse Datacore"], 1)

    local p = Player(callingPlayer)
    if p then
        p:setValue("ca_forge_unlocked", true)
        p:sendChatMessage("Stellar Forge"%_t, 0,
            "Datacore decrypted. Forge access is permanently unlocked for your account.")
    end
    AscendancyForge.sync()
end

function AscendancyForge.onCraftWardPressed()
    if onClient() then invokeServerFunction("craftWard"); return end
end

function AscendancyForge.craftWard()
    if not onServer() then return end
    local owner, craft, player = getInteractingFaction(callingPlayer, AlliancePrivilege.ManageStations, AlliancePrivilege.SpendResources)
    if not owner then return end
    if not player or player.index ~= callingPlayer or owner.index ~= Entity().factionIndex then return end
    if not craft then
        local p = Player(callingPlayer)
        if p then p:sendChatMessage("Stellar Forge"%_t, 1, "You must be inside a ship to craft a Ward."%_t) end
        return
    end

    local matAmount = craft:getCargoAmount("Ascendant Matter") or 0
    local scrapAmount = craft:getCargoAmount("Ascendant Scrap") or 0
    if matAmount < 10 or scrapAmount < 20 then
        player:sendChatMessage("Stellar Forge"%_t, 1, "Requires 10 Ascendant Matter and 20 Ascendant Scrap in your ship's cargo hold."%_t)
        return
    end

    craft:removeCargo(goods["Ascendant Matter"], 10)
    craft:removeCargo(goods["Ascendant Scrap"], 20)

    owner:getInventory():add(UsableInventoryItem("ca_eclipse_ward.lua", Rarity(RarityType.Rare)))
    player:sendChatMessage("Stellar Forge"%_t, 0, "Crafted an Ascendant Ward."%_t)
end

callable(AscendancyForge, "craftWard")

function AscendancyForge.sync(data)
    if onServer() then
        local pt = Server().unpausedRuntime
        local remaining = order and math.max(0, (order.completionAt or pt) - pt) or 0
        local tier = 0
        if cv_buffs.getGlobalTier then
            tier = cv_buffs.getGlobalTier(Entity().factionIndex)
        end
        invokeClientFunction(Player(callingPlayer), "sync", {
            isForging = order and order.state == "running" or false,
            hasCompletedItem = order and order.state == "ready_to_claim" or false,
            repairRequired = order and order.state == "repair_required" or false,
            remaining = remaining,
            tier = tier
        })
    else
        if data then
            clientIsForging = data.isForging
            clientHasCompletedItem = data.hasCompletedItem

            if clientIsForging then
                AscendancyForge.statusLabel.caption = "FORGING... Remaining: " .. math.floor(data.remaining / 3600) .. "h " .. math.floor((data.remaining % 3600) / 60) .. "m"
                AscendancyForge.statusLabel.color = ColorRGB(1, 1, 0)
                AscendancyForge.forgeBtn.active = false
                AscendancyForge.claimBtn.active = false
                AscendancyForge.combo.active = false
                AscendancyForge.sacrificeSelection.dropIntoEnabled = 0
            elseif clientHasCompletedItem then
                AscendancyForge.statusLabel.caption = "WEAPON READY FOR CLAIM!"
                AscendancyForge.statusLabel.color = ColorRGB(0, 1, 0)
                AscendancyForge.forgeBtn.active = false
                AscendancyForge.claimBtn.active = true
                AscendancyForge.combo.active = false
                AscendancyForge.sacrificeSelection.dropIntoEnabled = 0
            elseif data.repairRequired then
                AscendancyForge.statusLabel.caption = "FORGE REQUIRES ADMINISTRATOR REPAIR"
                AscendancyForge.statusLabel.color = ColorRGB(1, 0.25, 0.25)
                AscendancyForge.forgeBtn.active = false
                AscendancyForge.claimBtn.active = false
                AscendancyForge.combo.active = false
                AscendancyForge.sacrificeSelection.dropIntoEnabled = 0
            else
                AscendancyForge.statusLabel.caption = "FORGE IDLE"
                AscendancyForge.statusLabel.color = ColorRGB(0.5, 0.5, 0.5)
                AscendancyForge.forgeBtn.active = true
                AscendancyForge.claimBtn.active = false
                AscendancyForge.combo.active = true
                AscendancyForge.sacrificeSelection.dropIntoEnabled = 1
            end
            if data.tier then
                AscendancyForge.tierLabel.caption = "Global Ascendancy Tier: " .. tostring(data.tier)
            end
        end
        invokeServerFunction("syncCosts")
    end
end

callable(AscendancyForge, "updateSelectedType")
callable(AscendancyForge, "syncCosts")
callable(AscendancyForge, "startForging")
callable(AscendancyForge, "claimWeapon")
callable(AscendancyForge, "decryptDatacore")
callable(AscendancyForge, "sync")
