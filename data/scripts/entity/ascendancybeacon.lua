package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("utility")
include ("stringutility")
include ("faction")

-- Cosmic Integrations
local cv_success, cv_news = true, require("cosmicvaultnews")
local cw_success, cw_bridge = true, require("cosmicwarbridge")

-- namespace AscendancyBeacon
AscendancyBeacon = {}

local active = false
local currentTier = 1
local lastUpkeepTime = 0
local UPKEEP_INTERVAL = 45 * 60 -- 45 minutes
local lastSiegeTime = 0
local nextSiegeInterval = 0

function AscendancyBeacon.initialize()
    if onServer() then
        -- Register destruction callback to unregister the beacon safely
        Entity():registerCallback("onDestroyed", "onDestroyed")
        Sector():registerCallback("onEntityEntered", "onEntityEntered")
        lastUpkeepTime = Server().playtime
        lastSiegeTime = Server().playtime
        nextSiegeInterval = random():getInt(3, 6) * 3600 -- 3 to 6 hours
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
    menu:registerWindow(window, "Manage Beacon"%_t, 10);

    -- Status Labels
    window:createLabel(Rect(10, 10, size.x - 10, 30), "Ascendancy Status:"%_t, 16)
    AscendancyBeacon.statusLabel = window:createLabel(Rect(180, 10, size.x - 10, 30), "", 16)
    
    -- Tier Label
    AscendancyBeacon.tierLabel = window:createLabel(Rect(10, 40, size.x - 10, 60), "", 16)
    
    -- Costs
    window:createLabel(Rect(10, 70, size.x - 10, 90), "Billing Cycle: 45 Minutes"%_t, 14)
    AscendancyBeacon.costLabel = window:createLabel(Rect(10, 100, size.x - 10, 200), "", 14)

    -- Buttons
    AscendancyBeacon.toggleBtn = window:createButton(Rect(size.x * 0.5 - 210, 220, size.x * 0.5 - 10, 260), "Activate Beacon"%_t, "onTogglePressed")
    AscendancyBeacon.upgradeBtn = window:createButton(Rect(size.x * 0.5 + 10, 220, size.x * 0.5 + 210, 260), "Upgrade Tier"%_t, "onUpgradePressed")
    
    AscendancyBeacon.sync()
end

function AscendancyBeacon.onShowWindow()
    AscendancyBeacon.sync()
end

function AscendancyBeacon.onTogglePressed()
    if onClient() then
        invokeServerFunction("toggleBeacon")
        return
    end
end

function AscendancyBeacon.onUpgradePressed()
    if onClient() then
        invokeServerFunction("upgradeTier")
        return
    end
end

function AscendancyBeacon.getUpgradeCost(targetTier)
    if targetTier == 2 then return 50000000, Material(1), 2000000 end
    if targetTier == 3 then return 200000000, Material(3), 5000000 end
    if targetTier == 4 then return 500000000, Material(4), 10000000 end
    if targetTier == 5 then return 1000000000, Material(5), 20000000 end
    return 0, Material(0), 0
end

function AscendancyBeacon.getUpkeepCost()
    local owner = Faction(Entity().factionIndex)
    if not owner then return 0, Material(1), 0 end
    
    local currentCount = owner:getValue("ascendancy_beacons_count") or 0
    -- If currently inactive, preview cost for the *next* beacon
    if not active then currentCount = currentCount + 1 end
    -- Fallback to at least 1 multiplier
    if currentCount < 1 then currentCount = 1 end
    
    local mult = currentCount * currentCount -- 1x, 4x, 9x
    local x, y = Sector():getCoordinates()
    local d = length(vec2(x, y))
    
    local mat
    if d > 400 then mat = Material(1)
    elseif d > 300 then mat = Material(2)
    elseif d > 200 then mat = Material(3)
    elseif d > 100 then mat = Material(4)
    elseif d > 50 then mat = Material(5)
    else mat = Material(6)
    end
    
    local creditCost = 10000000 * mult
    local matCost = 500000 * mult
    
    return creditCost, mat, matCost
end

function AscendancyBeacon.onEntityEntered(entityId)
    if not active then return end
    if not onServer() then return end
    
    local entity = Entity(entityId)
    if not entity or not entity.isShip then return end
    
    local ownerFaction = Faction(Entity().factionIndex)
    local enteringFaction = Faction(entity.factionIndex)
    
    -- Restrict toll to AI Factions only (prevent griefing real players)
    if not enteringFaction or not enteringFaction.isAIFaction then return end
    
    -- Do not tax hostile invading factions
    if ownerFaction:getRelations(enteringFaction.index) < -10000 then return end
    
    -- Calculate Base Toll based on Tier
    local baseToll = 0
    if currentTier == 1 then baseToll = 10000 end
    if currentTier == 2 then baseToll = 50000 end
    if currentTier == 3 then baseToll = 100000 end
    if currentTier == 4 then baseToll = 250000 end
    if currentTier == 5 then baseToll = 500000 end
    
    -- Dynamic Modifier: War Heat (Wartime Premium Tax for seeking Safe Haven)
    local heatMod = 1.0
    if cv_bridge_success and cw_bridge.getFactionWarHeat then
        local heat = cw_bridge.getFactionWarHeat(enteringFaction.index)
        if heat > 0 then
            heatMod = 1.0 + (heat * 0.5) -- Up to 50% extra toll during intense wars
        end
    end
    
    local finalToll = math.floor(baseToll * heatMod)
    
    -- Collect the Toll
    ownerFaction:receive(string.format("Grand Toll collected from %s", enteringFaction.name), finalToll)
    
    -- Visual Feedback
    Sector():broadcastChatMessage("Ascendancy Beacon"%_t, 3, string.format("Collected %s Credits from %s", createMonetaryString(finalToll), entity.translatedTitle or "Ship"))
end

callable(AscendancyBeacon, "toggleBeacon")
function AscendancyBeacon.toggleBeacon()
    if not onServer() then return end
    local owner = Faction(Entity().factionIndex)
    if not owner then return end
    
    if active then
        -- Deactivate
        AscendancyBeacon.deactivate()
    else
        -- Activate
        local count = owner:getValue("ascendancy_beacons_count") or 0
        if count >= 3 then
            owner:sendChatMessage("Beacon"%_t, 1, "Empire Limit Reached! You can only maintain 3 Ascendancy Beacons."%_t)
            return
        end
        
        local creditCost, mat, matCost = AscendancyBeacon.getUpkeepCost()
        
        -- Try initial payment
        if owner.money < creditCost or owner:getInventory():getAmount(mat.value) < matCost then
            owner:sendChatMessage("Beacon"%_t, 1, "Insufficient resources to activate beacon."%_t)
            return
        end
        
        owner:pay(creditCost)
        owner:getInventory():remove(mat.value, matCost)
        
        owner:setValue("ascendancy_beacons_count", count + 1)
        active = true
        lastUpkeepTime = Server().playtime
        
        local x, y = Sector():getCoordinates()
        Galaxy():sendCallback("onAscendancyBeaconActivated", x, y)
        
        -- Cosmic Integrations!
        if cv_success and cv_news.publishArticle then
            cv_news.publishArticle({
                title = "Galactic Milestone: New Ascendant Capital",
                content = "The " .. owner.name .. " Empire has constructed a massive Ascendancy Beacon in sector [" .. x .. ":" .. y .. "]! This region of space has been permanently claimed as an Ascendant Capital.",
                category = "Galactic Expansion"
            })
        end
        
        if cw_success and cw_bridge.addWarHeat then
            -- Find nearest hostile AI faction and add war heat
            local factions = {Sector():getPresentFactions()}
            for _, f in pairs(factions) do
                if f.isAIFaction and f:getTrait("aggressive") then
                    cw_bridge.addWarHeat(f, 50)
                end
            end
        end
        
        if not Entity():hasScript("entity/ascendancyforge.lua") then
            Entity():addScript("entity/ascendancyforge.lua")
        end
        
        owner:sendChatMessage("Beacon"%_t, 0, "Beacon Activated. Sector is now permanently simulated."%_t)
    end
    
    AscendancyBeacon.sync()
end

function AscendancyBeacon.deactivate()
    if not active then return end
    active = false
    local owner = Faction(Entity().factionIndex)
    if owner then
        local count = owner:getValue("ascendancy_beacons_count") or 0
        if count > 0 then
            owner:setValue("ascendancy_beacons_count", count - 1)
        end
        owner:sendChatMessage("Beacon"%_t, 2, "Beacon Deactivated. Sector will now unload normally."%_t)
        
        -- Downgrade global tier if this was our highest beacon
        if cv_success and cv_buffs.setGlobalTier then
            cv_buffs.setGlobalTier(owner.index, 0) -- For now, we just reset it to 0. A full check of other beacons could be added.
        end
    end
    
    local x, y = Sector():getCoordinates()
    Galaxy():sendCallback("onAscendancyBeaconDeactivated", x, y)
    AscendancyBeacon.sync()
end

callable(AscendancyBeacon, "upgradeTier")
function AscendancyBeacon.upgradeTier()
    if not onServer() then return end
    if not active then return end
    if currentTier >= 5 then return end
    
    local owner = Faction(Entity().factionIndex)
    if not owner then return end
    
    local nextTier = currentTier + 1
    local creditCost, mat, matCost = AscendancyBeacon.getUpgradeCost(nextTier)
    
    if owner.money < creditCost or owner:getInventory():getAmount(mat.value) < matCost then
        owner:sendChatMessage("Beacon"%_t, 1, "Insufficient resources to upgrade to Tier %1%."%_t, nextTier)
        return
    end
    
    owner:pay(creditCost)
    owner:getInventory():remove(mat.value, matCost)
    
    currentTier = nextTier
    
    if cv_success and cv_buffs.setGlobalTier then
        -- Set global tier (assuming this beacon is the highest)
        local globalTier = cv_buffs.getGlobalTier(owner.index)
        if currentTier > globalTier then
            cv_buffs.setGlobalTier(owner.index, currentTier)
        end
    end
    
    owner:sendChatMessage("Beacon"%_t, 0, "Ascendancy Beacon upgraded to Tier %1%!"%_t, currentTier)
    
    if cv_success and cv_news.publishArticle then
        cv_news.publishArticle({
            title = "Empire Ascends to Tier " .. currentTier,
            content = "The " .. owner.name .. " Empire has poured astronomical resources into upgrading their Ascendancy Beacon to Tier " .. currentTier .. ". Their fleet's global power has increased significantly.",
            category = "Galactic Expansion"
        })
    end
    
    AscendancyBeacon.sync()
end

function AscendancyBeacon.onDestroyed()
    if active then AscendancyBeacon.deactivate() end
end

function AscendancyBeacon.getUpdateInterval()
    return 60 -- Check every minute
end

function AscendancyBeacon.updateServer(timeStep)
    if not active then return end
    
    -- Ping the galaxy to keep sector alive
    local owner = Faction(Entity().factionIndex)
    if owner then
        local x, y = Sector():getCoordinates()
        Galaxy():sendCallback("onAscendancyBeaconPing", Entity().id.string, owner.index, x, y)
    end
    
    local now = Server().playtime
    if now - lastUpkeepTime >= UPKEEP_INTERVAL then
        -- Time to pay!
        local creditCost, mat, matCost = AscendancyBeacon.getUpkeepCost()
        local owner = Faction(Entity().factionIndex)
        
        if owner and owner.money >= creditCost and owner:getInventory():getAmount(mat.value) >= matCost then
            owner:pay(creditCost)
            owner:getInventory():remove(mat.value, matCost)
            lastUpkeepTime = now
            owner:sendChatMessage("Beacon"%_t, 3, "Ascendancy Beacon Upkeep Paid: %1% Cr, %2% %3%", createMonetaryString(creditCost), createMonetaryString(matCost), mat.name)
        else
            -- Bankrupt!
            if owner then
                owner:sendChatMessage("Beacon"%_t, 1, "Ascendancy Beacon lost power! Upkeep failed. Sector will unload."%_t)
            end
            AscendancyBeacon.deactivate()
        end
    end
    
    if now > lastSiegeTime + nextSiegeInterval then
        lastSiegeTime = now
        nextSiegeInterval = random():getInt(3, 6) * 3600
        
        local owner = Faction(Entity().factionIndex)
        if owner then
            Sector():addScript("events/ascendancysiege.lua", currentTier, owner.index)
        end
    end
end

-- UI Sync
function AscendancyBeacon.sync(data)
    if onServer() then
        invokeClientFunction(Player(callingPlayer), "sync", {active = active, currentTier = currentTier})
    else
        if data then 
            active = data.active 
            currentTier = data.currentTier or 1
        end
        if not AscendancyBeacon.statusLabel then return end
        
        AscendancyBeacon.tierLabel.caption = "Current Tier: " .. currentTier
        
        if active then
            AscendancyBeacon.statusLabel.caption = "ONLINE (Sector kept alive)"%_t
            AscendancyBeacon.statusLabel.color = ColorRGB(0, 1, 0)
            AscendancyBeacon.toggleBtn.caption = "Deactivate"%_t
        else
            AscendancyBeacon.statusLabel.caption = "OFFLINE"%_t
            AscendancyBeacon.statusLabel.color = ColorRGB(1, 0, 0)
            AscendancyBeacon.toggleBtn.caption = "Activate"%_t
        end
        
        if currentTier >= 5 then
            AscendancyBeacon.upgradeBtn.caption = "Max Tier Reached"%_t
            AscendancyBeacon.upgradeBtn.active = false
        else
            AscendancyBeacon.upgradeBtn.caption = "Upgrade to Tier " .. (currentTier + 1)
            AscendancyBeacon.upgradeBtn.active = active -- Only upgrade if online
        end
        
        invokeServerFunction("syncCosts")
    end
end
callable(AscendancyBeacon, "sync")

function AscendancyBeacon.syncCosts()
    if not onServer() then return end
    local creditCost, mat, matCost = AscendancyBeacon.getUpkeepCost()
    
    local upCreditCost, upMat, upMatCost = 0, Material(0), 0
    if currentTier < 5 then
        upCreditCost, upMat, upMatCost = AscendancyBeacon.getUpgradeCost(currentTier + 1)
    end
    
    invokeClientFunction(Player(callingPlayer), "receiveCosts", creditCost, mat.name, matCost, upCreditCost, upMat.name, upMatCost)
end
callable(AscendancyBeacon, "syncCosts")

function AscendancyBeacon.receiveCosts(creditCost, matName, matCost, upCreditCost, upMatName, upMatCost)
    if not AscendancyBeacon.costLabel then return end
    local txt = "Upkeep per 45 Minutes:\n" .. createMonetaryString(creditCost) .. " Credits\n" .. createMonetaryString(matCost) .. " " .. matName
    if currentTier < 5 then
        txt = txt .. "\n\nUpgrade Cost (Tier " .. (currentTier + 1) .. "):\n"
        txt = txt .. createMonetaryString(upCreditCost) .. " Credits\n" .. createMonetaryString(upMatCost) .. " " .. upMatName
    end
    AscendancyBeacon.costLabel.caption = txt
end

function AscendancyBeacon.secure()
    return {
        active = active,
        currentTier = currentTier,
        lastUpkeepTime = lastUpkeepTime,
        lastSiegeTime = lastSiegeTime,
        nextSiegeInterval = nextSiegeInterval
    }
end

function AscendancyBeacon.restore(data)
    active = data.active or false
    currentTier = data.currentTier or 1
    lastUpkeepTime = data.lastUpkeepTime or Server().playtime
    lastSiegeTime = data.lastSiegeTime or Server().playtime
    nextSiegeInterval = data.nextSiegeInterval or random():getInt(3, 6) * 3600
end
