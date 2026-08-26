package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("randomext")
include ("galaxy")
include ("stringutility")
include ("faction")
include ("callable")
local UpgradeGenerator = include ("upgradegenerator")
local SectorTurretGenerator = include ("sectorturretgenerator")

-- namespace CaAnomalyStash
CaAnomalyStash = {}
CaAnomalyStash.interactionDistance = 20

function CaAnomalyStash.interactionPossible(playerIndex, option)
    local player = Player(playerIndex)
    local craft = player.craft
    if not craft then return false end

    local self = Entity()
    local dist = craft:getNearestDistance(self)
    if dist < CaAnomalyStash.interactionDistance then
        return true
    end

    return false, "You're not close enough to decrypt the databank."%_t
end

function CaAnomalyStash.initialize()
    Entity():setValue("valuable_object", RarityType.Exceptional)
end

function CaAnomalyStash.initUI()
    ScriptUI():registerInteraction("Decrypt Databank"%_t, "onOpenPressed", 5)
end

function CaAnomalyStash.onOpenPressed()
    if onClient() then
        invokeServerFunction("onOpenPressed")
        return
    end

    local entity = Entity()
    local sector = Sector()
    local position = entity.translationf
    local x, y = sector:getCoordinates()

    local player = Player(callingPlayer)
    local faction = Faction(player.craft.factionIndex)
    if not faction then faction = player end

    local distMat = entity:getValue("ca_anomaly_mat") or 1
    local amount = entity:getValue("ca_anomaly_amt") or 10000
    local numUpgrades = entity:getValue("ca_anomaly_upgrades") or 1

    -- Drop scaling materials directly
    sector:dropResources(position, faction, nil, Material(distMat), amount)

    -- Drop generic scalable loot (upgrades and turrets)
    local uGen = UpgradeGenerator()
    local tGen = SectorTurretGenerator()
    
    for i = 1, numUpgrades do
        local rarityType = random():getInt(1, 3) -- Uncommon to Exceptional
        
        -- 50% chance for Turret, 50% chance for Upgrade
        if random():getFloat() < 0.5 then
            tGen.minRarity = Rarity(rarityType)
            local turret = tGen:generate(x, y)
            sector:dropTurret(position, faction, nil, turret)
        else
            uGen.minRarity = Rarity(rarityType)
            local upgrade = uGen:generateSectorSystem(x, y)
            sector:dropUpgrade(position, faction, nil, upgrade)
        end
    end

    -- Anomaly Resurgence (10% chance)
    if random():getFloat() < 0.10 then
        player:sendChatMessage("Ship Sensors", 3, "The anomaly has resonated, revealing another fragment nearby!")
        local resPos = position + vec3(random():getFloat(20, 50), random():getFloat(20, 50), random():getFloat(20, 50))
        local generator = SectorGenerator(x, y)
        local stash2 = generator:createContainer(nil, MatrixLookUpPosition(vec3(0,1,0), vec3(1,0,0), resPos), 0)
        stash2.title = "Resonated Databank Stash"%_t
        stash2:setValue("ca_anomaly_mat", distMat)
        stash2:setValue("ca_anomaly_amt", math.floor(amount * 0.5))
        stash2:setValue("ca_anomaly_upgrades", 1)
        stash2:addScriptOnce("data/scripts/entity/ca_anomaly_stash.lua")
    end

    -- Delete the stash after dropping the loot
    sector:deleteEntity(entity)
end
callable(CaAnomalyStash, "onOpenPressed")
