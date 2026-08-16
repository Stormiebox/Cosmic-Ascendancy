package.path = package.path .. ";data/scripts/lib/?.lua"

function initialize()
    if onServer() then
        Entity():registerCallback("onDestroyed", "onDestroyed")
    end
end

function onDestroyed()
    if not onServer() then return end
    
    local sector = Sector()
    local entity = Entity()
    local pos = entity.translationf

    -- Suppression Field: Halt all invasions globally for 6 hours
    Server():setValue("eclipse_citadel_destroyed_time", Server().unpausedRuntime)
    Sector():broadcastChatMessage("Eclipse Citadel", 2, "The Citadel's destruction has generated a massive suppression field. Eclipse invasions halted.")

    -- Ascendant Matter massive drop
    local matterAmount = random():getInt(100, 250)
    sector:dropCargo(pos, nil, nil, Good("Ascendant Matter"), 0, matterAmount)
    
    -- Eclipse Datacore drop
    local coreAmount = random():getInt(3, 5)
    for i = 1, coreAmount do
        sector:dropCargo(pos, nil, nil, Good("Eclipse Datacore"), 0, 1)
    end
    
    -- Legendary Weapons and Upgrades
    local SectorTurretGenerator = include("sectorturretgenerator")
    local UpgradeGenerator = include("upgradegenerator")
    local ugen = UpgradeGenerator()
    local cx, cy = sector:getCoordinates()
    local tgen = SectorTurretGenerator(sector.seed)
    
    for i = 1, random():getInt(8, 12) do
        local turret = tgen:generateArmed(cx, cy, 0, Rarity(RarityType.Legendary))
        if turret then
            -- tech level scales natively with cx, cy
            sector:dropTurret(pos, nil, nil, turret)
        end
    end
    
    for i = 1, random():getInt(8, 12) do
        local upgrade = ugen:generateSectorSystem(cx, cy, Rarity(RarityType.Legendary))
        if upgrade then
            sector:dropUpgrade(pos, nil, nil, upgrade)
        end
    end
end
