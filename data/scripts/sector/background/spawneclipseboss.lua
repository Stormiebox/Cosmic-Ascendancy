package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local EclipseGenerator = include("eclipsegenerator")
local SectorGenerator = include ("SectorGenerator")

SpawnEclipseBoss = {}
local self = SpawnEclipseBoss

function SpawnEclipseBoss.initialize()
    if onServer() then
        self.createBoss()
    end
end

function SpawnEclipseBoss.createBoss()
    local sector = Sector()
    local position = MatrixLookUpPosition(vec3(0,0,1), vec3(0,1,0), vec3(500, 500, 500))
    
    local boss = EclipseGenerator.createShip(position, "monolith")
    boss.title = "Eclipse Oblivion Engine"%_T
    boss.name = "Eclipse Oblivion Engine"%_T
    
    boss:addMultiplyableFactor(StatsBonuses.ShieldDurability, 500.0) 
    
    local damageBonuses = {StatsBonuses.EnergyDamage, StatsBonuses.ElectricDamage, StatsBonuses.PlasmaDamage, StatsBonuses.AntiMatterDamage, StatsBonuses.FragmentsDamage, StatsBonuses.PhysicalDamage}
    for _, stat in pairs(damageBonuses) do
        boss:addMultiplyableFactor(stat, 50.0)
    end
    
    boss:addMultiplyableFactor(StatsBonuses.ArmedTurrets, 200.0)
    boss:addMultiplyableFactor(StatsBonuses.Velocity, 3.0) 
    
    boss:setValue("stormbox_boss", true)
    
    local SectorTurretGenerator = include("sectorturretgenerator")
    local UpgradeGenerator = include("upgradegenerator")
    local ugen = UpgradeGenerator()
    local tgen = SectorTurretGenerator()
    
    for i = 1, 25 do
        Loot(boss):insert(ugen:generateSectorSystem(150, 0, Rarity(RarityType.Legendary)))
        
        local turret = tgen:generateArmed(150, 0, 0, Rarity(RarityType.Legendary))
        local weapons = {turret:getWeapons()}
        turret:clearWeapons()
        for _, w in pairs(weapons) do
            w.damage = w.damage * 3
            w.reach = w.reach * 2
            turret:addWeapon(w)
        end
        Loot(boss):insert(InventoryTurret(turret))
    end
    
    boss:addScriptOnce("entity/background/eclipsebossbehavior.lua")
    ShipAI(boss):setAggressive(true, false)
end

function SpawnEclipseBoss.finish()
    local sector = Sector()
    local boss = sector:getEntitiesByScriptValue("stormbox_boss")
    if not boss then terminate() return end

    sector:deleteEntityJumped(boss)
    
    local x, y = sector:getCoordinates()
    
    if random():getFloat() < 0.1 then
        local generator = SectorGenerator(x, y)
        local wormhole = generator:createWormhole(random():getInt(-500, 500), random():getInt(-500, 500), ColorRGB(0, 0, 0), 100)
        Server():broadcastChatMessage("System"%_T, 1, "The Eclipse Oblivion Engine has left a dimensional tear in sector \\s(%1%:%2%)!"%_T, x, y)
    else
        Server():broadcastChatMessage("System"%_T, 1, "The Eclipse Oblivion Engine has vanished from sector \\s(%1%:%2%), leaving only dust."%_T, x, y)
    end

    if not sector:getPlayers() then
        local generator = SectorGenerator(x, y)
        local entities = {sector:getEntitiesByComponent(ComponentType.Owner)}
        for _, entity in pairs(entities) do
            if entity:hasComponent(ComponentType.Durability) and entity.aiOwned then
                local blockPlan = Plan(entity.id):getMove()
                local wreckage = generator:createWreckage(nil, blockPlan)
                entity:clearCargoBay()
                sector:deleteEntity(entity)
            end
        end
    end

    terminate()
end

return SpawnEclipseBoss
