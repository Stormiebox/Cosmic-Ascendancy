package.path = package.path .. ";data/scripts/lib/?.lua"

include ("utility")
include ("stringutility")
local TurretGenerator = include("turretgenerator")
local cv_news = include("cosmicvaultnews")
local cw_bridge = include("cosmicwarbridge")
local cv_buffs = include("cosmicvaultbuffs")

AscendancyForge = {}

local isForging = false
local forgeFinishTime = 0
local hasCompletedItem = false
local selectedType = 1
local FORGE_TIME = 24 * 3600 -- 24 real-world/playtime hours

local weaponChoices = {
    {name = "Ascendant Chaingun", value = 1},
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
    local size = vec2(600, 350)
    local menu = ScriptUI()
    local window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    window.caption = "The Stellar Forge"%_t
    window.showCloseButton = 1
    window.moveable = 1
    menu:registerWindow(window, "Stellar Forge"%_t, 11)

    window:createLabel(Rect(10, 10, size.x - 10, 30), "Ascendant Weapon Blueprint:"%_t, 14)
    AscendancyForge.combo = window:createComboBox(Rect(10, 35, size.x - 10, 65), "onComboChanged")
    for _, choice in pairs(weaponChoices) do
        AscendancyForge.combo:addEntry(choice.name)
    end

    AscendancyForge.costLabel = window:createLabel(Rect(10, 80, size.x - 10, 160), "", 14)
    AscendancyForge.statusLabel = window:createLabel(Rect(10, 180, size.x - 10, 220), "", 18)

    AscendancyForge.forgeBtn = window:createButton(Rect(size.x * 0.5 - 200, 250, size.x * 0.5 - 10, 290), "Ignite Forge"%_t, "onForgePressed")
    AscendancyForge.claimBtn = window:createButton(Rect(size.x * 0.5 + 10, 250, size.x * 0.5 + 200, 290), "Claim Weapon"%_t, "onClaimPressed")

    AscendancyForge.tierLabel = window:createLabel(Rect(10, 300, size.x * 0.5, 340), "Global Ascendancy Tier: 0", 16)
    AscendancyForge.decryptBtn = window:createButton(Rect(size.x * 0.5, 300, size.x - 10, 340), "Decrypt Eclipse Datacore"%_t, "onDecryptPressed")

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
callable(AscendancyForge, "updateSelectedType")

function AscendancyForge.onShowWindow()
    AscendancyForge.sync()
end

function AscendancyForge.getCosts()
    local x, y = Sector():getCoordinates()
    local dist = length(vec2(x, y))
    local scale = math.max(1, 6 - (dist / 100)) -- 1x at 500, up to ~6x at core

    local creditCost = math.floor(1000000000 * scale)
    local matCost = random():getInt(100, 500)

    return creditCost, "Ascendant Matter", matCost
end

function AscendancyForge.syncCosts()
    if not onServer() then return end
    local creditCost, mat, matCost = AscendancyForge.getCosts()
    invokeClientFunction(Player(callingPlayer), "receiveCosts", creditCost, mat.name, matCost)
end
callable(AscendancyForge, "syncCosts")

function AscendancyForge.receiveCosts(creditCost, matName, matCost)
    if not AscendancyForge.costLabel then return end
    AscendancyForge.costLabel.caption = string.format("Forging Costs:\n%s Credits\n%s %s\n\nCrafting Time: 24 Hours", createMonetaryString(creditCost), createMonetaryString(matCost), matName)
end

function AscendancyForge.sync(data)
    if onServer() then
        local pt = Server().playtime
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
            elseif hasCompletedItem then
                AscendancyForge.statusLabel.caption = "WEAPON READY FOR CLAIM!"
                AscendancyForge.statusLabel.color = ColorRGB(0, 1, 0)
                AscendancyForge.forgeBtn.active = false
                AscendancyForge.claimBtn.active = true
                AscendancyForge.combo.active = false
            else
                AscendancyForge.statusLabel.caption = "FORGE IDLE"
                AscendancyForge.statusLabel.color = ColorRGB(0.5, 0.5, 0.5)
                AscendancyForge.forgeBtn.active = true
                AscendancyForge.claimBtn.active = false
                AscendancyForge.combo.active = true
            end
            if data.tier then
                AscendancyForge.tierLabel.caption = "Global Ascendancy Tier: " .. tostring(data.tier)
            end
            if isForging then
                AscendancyForge.statusLabel.caption = "FORGING... Remaining: " .. math.floor(data.remaining / 3600) .. "h " .. math.floor((data.remaining % 3600) / 60) .. "m"
                AscendancyForge.forgeBtn.active = false
                AscendancyForge.claimBtn.active = false
                AscendancyForge.combo.active = false
            elseif hasCompletedItem then
                AscendancyForge.statusLabel.caption = "WEAPON READY FOR CLAIM!"
                AscendancyForge.statusLabel.color = ColorRGB(0, 1, 0)
                AscendancyForge.forgeBtn.active = false
                AscendancyForge.claimBtn.active = true
                AscendancyForge.combo.active = false
            else
                AscendancyForge.statusLabel.caption = "FORGE IDLE"
                AscendancyForge.statusLabel.color = ColorRGB(0.5, 0.5, 0.5)
                AscendancyForge.forgeBtn.active = true
                AscendancyForge.claimBtn.active = false
                AscendancyForge.combo.active = true
            end
        end
        invokeServerFunction("syncCosts")
    end
end
callable(AscendancyForge, "sync")

function AscendancyForge.onForgePressed()
    if onClient() then invokeServerFunction("startForging"); return end
end

function AscendancyForge.startForging()
    if not onServer() then return end
    if isForging or hasCompletedItem then return end

    local owner = Faction(Entity().factionIndex)
    if not owner then return end

    local creditCost, mat, matCost = AscendancyForge.getCosts()
    if owner.money < creditCost or owner:getInventory():getAmount(mat.value) < matCost then
        owner:sendChatMessage("Stellar Forge"%_t, 1, "Insufficient resources!"%_t)
        return
    end

    owner:pay(creditCost)
    owner:getInventory():remove(mat.value, matCost)

    isForging = true
    forgeFinishTime = Server().playtime + FORGE_TIME

    owner:sendChatMessage("Stellar Forge"%_t, 0, "The Stellar Forge has ignited! Your weapon will be ready in 24 hours."%_t)

    if cv_news.publishArticle then
        local x, y = Sector():getCoordinates()
        cv_news.publishArticle({
            title = "Stellar Forge Ignited in [" .. x .. ":" .. y .. "]",
            content = "Astronomical energy readings detected as the " .. owner.name .. " Empire initiates their Stellar Forge. They are constructing an apocalyptic super-weapon.",
            category = "Galactic Expansion"
        })
    end

    AscendancyForge.sync()
end
callable(AscendancyForge, "startForging")

function AscendancyForge.onClaimPressed()
    if onClient() then invokeServerFunction("claimWeapon"); return end
end

function AscendancyForge.claimWeapon()
    if not onServer() then return end
    if not hasCompletedItem then return end

    local owner = Faction(Entity().factionIndex)
    if not owner then return end

    if type(selectedType) == "string" then
        -- Construct Living Relic Subsystem
        local system = SystemUpgradeTemplate(selectedType, Rarity(5), random():createSeed())
        owner:getInventory():add(system)
        owner:sendChatMessage("Stellar Forge"%_t, 3, "Claimed " .. system.name .. "!")
    else
        -- Generate God-Tier Weapon
        local rarity = Rarity(5) -- Legendary
        local material = Material(6) -- Avorion
        local dps = 15000

        -- Use highest possible tech
        local turret = TurretGenerator.generateSeeded(random():createSeed(), selectedType, dps, 52, rarity, material, true)

        -- Compute Multipliers
        local x, y = Sector():getCoordinates()
        local distBonus = 1.0 + (math.max(0, 500 - length(vec2(x, y))) / 250) -- +200% at core

        local warBonus = 1.0
        if cw_bridge.getFactionWarHeat then
            local heat = cw_bridge.getFactionWarHeat(owner.index)
            if heat > 0 then
                warBonus = 1.0 + (heat * 1.5) -- Up to +150% during massive wars
            end
        end

        local finalMult = 3.0 * distBonus * warBonus

        -- Inject custom properties
        local weapons = {turret:getWeapons()}
        turret:clearWeapons()
        for _, w in pairs(weapons) do
            w.damage = w.damage * finalMult
            w.reach = math.min(30000, w.reach * 2.0)
            turret:addWeapon(w)
        end

        turret.title = "Ascendant " .. turret.title
        turret.coaxial = false -- Ensure it can be mounted normally or coaxially if user wants, but we'll leave it as normal
        turret.slots = 1 -- Reduce slot cost as a supreme benefit

        -- Give to player
        owner:getInventory():add(turret)
        owner:sendChatMessage("Stellar Forge"%_t, 3, "Claimed " .. turret.title .. "!")
    end

    hasCompletedItem = false
    isForging = false
    AscendancyForge.sync()
end
callable(AscendancyForge, "claimWeapon")

function AscendancyForge.getUpdateInterval()
    return 60
end

function AscendancyForge.updateServer(timeStep)
    if isForging then
        local pt = Server().playtime
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
        selectedType = selectedType
    }
end

function AscendancyForge.restore(data)
    isForging = data.isForging or false
    forgeFinishTime = data.forgeFinishTime or 0
    hasCompletedItem = data.hasCompletedItem or false
    selectedType = data.selectedType or 1
end

function AscendancyForge.onDecryptPressed()
    if onClient() then invokeServerFunction("decryptDatacore"); return end
end

function AscendancyForge.decryptDatacore()
    if not onServer() then return end
    local owner = Faction(Entity().factionIndex)
    if not owner then return end

    local amount = owner:getInventory():getAmount("Eclipse Datacore")
    if amount < 1 then
        owner:sendChatMessage("Stellar Forge"%_t, 1, "You do not have any Eclipse Datacores!"%_t)
        return
    end

    owner:getInventory():remove("Eclipse Datacore", 1)

    if cv_buffs.setGlobalTier then
        local currentTier = cv_buffs.getGlobalTier(owner.index)
        cv_buffs.setGlobalTier(owner.index, currentTier + 1)
        owner:sendChatMessage("Stellar Forge"%_t, 0, "Datacore Decrypted! Global Ascendancy Tier increased to " .. (currentTier + 1) .. "!")

        -- Apply stats globally via a script we will attach to the player
        if owner.isPlayer then
            local p = Player(owner.index)
            if not p:hasScript("data/scripts/player/ca_global_tier_manager.lua") then
                p:addScript("data/scripts/player/ca_global_tier_manager.lua")
            end
        end
    end

    AscendancyForge.sync()
end
callable(AscendancyForge, "decryptDatacore")


function getUpdateInterval(...)
    if AscendancyForge.getUpdateInterval then return AscendancyForge.getUpdateInterval(...) end
end
function updateServer(...)
    if AscendancyForge.updateServer then return AscendancyForge.updateServer(...) end
end
function secure(...)
    if AscendancyForge.secure then return AscendancyForge.secure(...) end
end
function restore(...)
    if AscendancyForge.restore then return AscendancyForge.restore(...) end
end

return AscendancyForge
