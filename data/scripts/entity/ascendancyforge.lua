package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
include("utility")
include("stringutility")
include("faction")
include("goods")
local PlanGenerator = include("plangenerator")
local ShipGenerator = include("shipgenerator")
local TurretGenerator = include("turretgenerator")
-- Removed hard dependency on cosmicwar_bridge
local cv_news = include("cosmicvaultnews")
local cv_buffs = include("cosmicvaultbuffs")
local cv_goods = include("cosmicvaultgoods")

local isForging = false
local forgeFinishTime = 0
local hasCompletedItem = false
local willSucceed = false
local selectedType = 1

local FORGE_TIME = 24 * 3600

-- namespace AscendancyForge
AscendancyForge = {}

local weaponChoices = {
    {name = "Ascendant Chaingun", value = 1},
    {name = "Ascendant Point Defense", value = 2},
    {name = "Ascendant Anti-Fighter", value = 12},
    {name = "Ascendant Bolter", value = 13},
    {name = "Ascendant Laser", value = 3},
    {name = "Ascendant Plasma", value = 8},
    {name = "Ascendant Rocket", value = 9},
    {name = "Ascendant Cannon", value = 10},
    {name = "Ascendant Railgun", value = 11},
    {name = "Ascendant Tesla", value = 15},
    {name = "Ascendant Lightning", value = 14},
    {name = "Ascendant Pulse Cannon", value = 17},
    {name = "Ascendant War-Drive", value = "data/scripts/systems/ascendantwardrive.lua"},
    {name = "Ascendant Aegis Matrix", value = "data/scripts/systems/ascendantaegis.lua"},
    {name = "Ascendant Slipstream Core", value = "data/scripts/systems/ascendantslipstream.lua"},
    {name = "Ascendant Omni-Sensor", value = "data/scripts/systems/ascendantomnisensor.lua"},
    {name = "Ascendant Swarm Nexus", value = "data/scripts/systems/ascendantswarmnexus.lua"},
    {name = "Ascendant Void-Drill", value = "data/scripts/systems/ascendantvoiddrill.lua"},
    {name = "Ascendant Neural Implant", value = "data/scripts/systems/ascendantneuralimplant.lua"},
    {name = "Ascendant World-Breaker (Titan Coaxial)", value = "titan_worldbreaker"},
}

function AscendancyForge.interactionPossible(playerIndex, option)
    if not Player(playerIndex):getValue("ca_forge_unlocked") then return false end
    return checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageStations)
end

function AscendancyForge.getIcon()
    return "data/textures/icons/forge.png"
end

function AscendancyForge.initUI()
    local res = getResolution()
    local size = vec2(850, 650)
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

    AscendancyForge.sync()
end

function AscendancyForge.onComboChanged(comboBox, selectedIndex)
    if not onClient() then return end
    selectedType = weaponChoices[selectedIndex + 1].value
    invokeServerFunction("updateSelectedType", selectedType)
end

function AscendancyForge.updateSelectedType(typ)
    selectedType = typ
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
    invokeServerFunction("startForging", itemIndices)
end

function AscendancyForge.startForging(itemIndices)
    if not onServer() then return end
    if isForging or hasCompletedItem then return end

    local owner, craft, player = getInteractingFaction(callingPlayer, AlliancePrivilege.ManageStations, AlliancePrivilege.SpendResources)
    if not owner then return end
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
    if itemIndices then
        for index, amount in pairs(itemIndices) do
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
        end
    end

    local scrapNeeded = math.max(0, math.ceil((100 - successRate) / 2))
    local scrapAmount = craft:getCargoAmount("Ascendant Scrap") or 0
    local scrapToConsume = math.min(scrapAmount, scrapNeeded)

    successRate = successRate + (scrapToConsume * 2)

    -- Consume Costs
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

    -- Roll RNG
    if random():getInt(1, 100) <= successRate then
        willSucceed = true
        isForging = true
        -- during server downtime. Use unpausedRuntime so the 24h only ticks during active gameplay.
        forgeFinishTime = Server().unpausedRuntime + FORGE_TIME
        owner:sendChatMessage("Stellar Forge"%_t, 0, "The Stellar Forge has ignited! Your weapon will be ready in 24 hours."%_t)
    else
        willSucceed = false
        owner:sendChatMessage("Stellar Forge"%_t, 1, "The Forge failed to stabilize the Ascendant Matter! Your materials were consumed."%_t)
        -- Give Ascendant Scrap
        if cv_goods.registerGood then
            craft:addCargo(goods["Ascendant Scrap"], random():getInt(10, 50))
            owner:sendChatMessage("Stellar Forge"%_t, 2, "You salvaged some Ascendant Scrap from the failure.")
        end
    end

    AscendancyForge.sync()
end

function AscendancyForge.onClaimPressed()
    if onClient() then invokeServerFunction("claimWeapon"); return end
end

function AscendancyForge.claimWeapon()
    if not onServer() then return end
    if not hasCompletedItem then return end
    local owner, craft, player = getInteractingFaction(callingPlayer, AlliancePrivilege.ManageStations)
    if not owner then return end

    if type(selectedType) == "string" then
        if selectedType == "titan_worldbreaker" then
            local CosmicVaultArsenal = include("cosmicvaultarsenal")
            local config = {
                rarity = Rarity(RarityType.Legendary),
                material = Material(MaterialType.Avorion),
                weaponType = WeaponType.Laser,
                damage = 250000,
                fireRate = 1.0,
                range = 15000,
                accuracy = 1.0,
                coaxial = true,
                color = ColorRGB(1, 0, 0),
                size = 10.0,
                slots = 6
            }
            local turret = CosmicVaultArsenal.GenerateTurret(config)
            if turret then
                turret.icon = "data/textures/icons/weapon/AscendantWorldBreaker.png"
                owner:getInventory():add(turret)
                owner:sendChatMessage("Stellar Forge"%_t, 3, "Claimed Ascendant World-Breaker!")
            end
        else
            local system = SystemUpgradeTemplate(selectedType, Rarity(5), random():createSeed())
            owner:getInventory():add(system)
            owner:sendChatMessage("Stellar Forge"%_t, 3, "Claimed " .. system.name .. "!")
        end
    else
        local rarity = Rarity(5)
        local material = Material(6)
        local dps = 15000
        local turret = TurretGenerator.generateSeeded(random():createSeed(), selectedType, dps, 52, rarity, material, true)

        local x, y = Sector():getCoordinates()
        local distBonus = 1.0 + (math.max(0, 500 - length(vec2(x, y))) / 250)
        local warBonus = 1.0
        local server = Server()
        if server then
            local snapshotStr = server:getValue("cw_war_heat_snapshot")
            if type(snapshotStr) == "string" and snapshotStr ~= "" then
                for pair in string.gmatch(snapshotStr, "([^,]+)") do
                    local idxStr, heatStr = string.match(pair, "(%d+):([%d%.]+)")
                    if idxStr and tonumber(idxStr) == owner.index and heatStr then
                        local heat = tonumber(heatStr) or 0
                        if heat > 0 then warBonus = 1.0 + (heat * 1.5) end
                        break
                    end
                end
            end
        end
        -- Hard cap warBonus to prevent infinite integer scaling
        warBonus = math.min(10.0, warBonus)

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

        owner:getInventory():add(turret)
        owner:sendChatMessage("Stellar Forge"%_t, 3, "Claimed " .. turret.title .. "!")
    end

    hasCompletedItem = false
    isForging = false
    willSucceed = false
    AscendancyForge.sync()
end

function AscendancyForge.getUpdateInterval() return 60 end

function AscendancyForge.updateServer(timeStep)
    if isForging then
        local pt = Server().unpausedRuntime
        if pt >= forgeFinishTime then
            isForging = false
            hasCompletedItem = true
            local owner = Faction(Entity().factionIndex)
            if owner then
                owner:sendChatMessage("Stellar Forge"%_t, 0, "Your Ascendant Weapon is ready to be claimed!"%_t)
            end
        end
    end
end

function AscendancyForge.secure()
    return {
        isForging = isForging,
        forgeFinishTime = forgeFinishTime,
        hasCompletedItem = hasCompletedItem,
        willSucceed = willSucceed,
        selectedType = selectedType
    }
end

function AscendancyForge.restore(data)
    data = data or {}
    isForging = data.isForging or false
    forgeFinishTime = data.forgeFinishTime or 0
    hasCompletedItem = data.hasCompletedItem or false
    willSucceed = data.willSucceed or false
    selectedType = data.selectedType or 1
end

function AscendancyForge.onDecryptPressed()
    if onClient() then invokeServerFunction("decryptDatacore"); return end
end

function AscendancyForge.decryptDatacore()
    if not onServer() then return end
    local owner, craft, player = getInteractingFaction(callingPlayer, AlliancePrivilege.ManageStations, AlliancePrivilege.SpendResources)
    if not owner then return end
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

    if cv_buffs.setGlobalTier then
        local currentTier = cv_buffs.getGlobalTier(owner.index)
        cv_buffs.setGlobalTier(owner.index, currentTier + 1)
        owner:sendChatMessage("Stellar Forge"%_t, 0, "Datacore Decrypted! Global Ascendancy Tier increased to " .. (currentTier + 1) .. "!")

        -- but never used it. Completed: mark the calling player's forge as unlocked and
        -- grant a personal notification. This enables the interactionPossible gate at L43-L44.
        local p = Player(callingPlayer)
        if p then
            p:setValue("ca_forge_unlocked", true)
            p:sendChatMessage("Stellar Forge"%_t, 0, "Forge access permanently unlocked for your account.")
        end
    end
    AscendancyForge.sync()
end

function AscendancyForge.sync(data)
    if onServer() then
        local pt = Server().unpausedRuntime
        local remaining = math.max(0, forgeFinishTime - pt)
        local tier = 0
        if cv_buffs.getGlobalTier then
            tier = cv_buffs.getGlobalTier(Entity().factionIndex)
        end
        invokeClientFunction(Player(callingPlayer), "sync", {
            isForging = isForging,
            hasCompletedItem = hasCompletedItem,
            remaining = remaining,
            tier = tier
        })
    else
        if data then
            isForging = data.isForging
            hasCompletedItem = data.hasCompletedItem

            if isForging then
                AscendancyForge.statusLabel.caption = "FORGING... Remaining: " .. math.floor(data.remaining / 3600) .. "h " .. math.floor((data.remaining % 3600) / 60) .. "m"
                AscendancyForge.statusLabel.color = ColorRGB(1, 1, 0)
                AscendancyForge.forgeBtn.active = false
                AscendancyForge.claimBtn.active = false
                AscendancyForge.combo.active = false
                AscendancyForge.sacrificeSelection.dropIntoEnabled = 0
            elseif hasCompletedItem then
                AscendancyForge.statusLabel.caption = "WEAPON READY FOR CLAIM!"
                AscendancyForge.statusLabel.color = ColorRGB(0, 1, 0)
                AscendancyForge.forgeBtn.active = false
                AscendancyForge.claimBtn.active = true
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
