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

    local boss = EclipseGenerator.createShip(position, "ca_worldeater")
    boss.title = "World Eater"%_T
    boss.name = "World Eater"%_T

    boss:addMultiplyableBias(StatsBonuses.ShieldDurability, 500.0)
    boss:addMultiplyableBias(StatsBonuses.ArbitraryTurrets, 50.0)
    boss:addMultiplyableBias(StatsBonuses.ArmedTurrets, 400.0)
    boss:addMultiplyableBias(StatsBonuses.Velocity, 3.0)

    boss:setValue("stormbox_boss", true)

    local SectorTurretGenerator = include("sectorturretgenerator")
    local UpgradeGenerator = include("upgradegenerator")
    local ugen = UpgradeGenerator()
    -- Must pass actual sector coordinates so pre-loaded loot scales to the correct material tier.
    local cx, cy = sector:getCoordinates()
    local tgen = SectorTurretGenerator(Sector().seed)

    for i = 1, 25 do
        -- Generate and insert a legendary upgrade into the boss's loot pool
        Loot(boss):insert(ugen:generateSectorSystem(cx, cy, Rarity(RarityType.Legendary)))

        local turret = tgen:generateArmed(cx, cy, 0, Rarity(RarityType.Legendary))
        if turret then
            -- tech level scales natively with cx, cy
            Loot(boss):insert(InventoryTurret(turret))
        end
    end

    boss:addScriptOnce("entity/background/eclipsebossbehavior.lua")
    -- Force the boss into an aggressive AI state
    ShipAI(boss.index):setAggressive()
end

function SpawnEclipseBoss.finish()
    local sector = Sector()
    local bossEntities = {sector:getEntitiesByScriptValue("stormbox_boss")}
    if #bossEntities == 0 then terminate() return end

    sector:deleteEntityJumped(bossEntities[1])

    local x, y = sector:getCoordinates()

    if random():getFloat() < 0.1 then
        local desc = WormholeDescriptor()
        desc.position = MatrixLookUpPosition(vec3(0, 1, 0), vec3(1, 0, 0), vec3(random():getInt(-500, 500), random():getInt(-500, 500), random():getInt(-500, 500)))
        local wormholeComponent = desc:getComponent(ComponentType.WormHole)
        wormholeComponent:setTargetCoordinates(random():getInt(-400, 400), random():getInt(-400, 400))
        wormholeComponent.visible = true
        wormholeComponent.visualSize = 100
        sector:createEntity(desc)

        Server():broadcastChatMessage("System"%_T, 1, "The World Eater has left a dimensional tear in sector \\s(%1%:%2%)!"%_T, x, y)
    else
        Server():broadcastChatMessage("System"%_T, 1, "The World Eater has vanished from sector \\s(%1%:%2%), leaving only dust."%_T, x, y)
    end

    -- `if not sector:getPlayers()` tests the truthiness of the first return value,
    -- which is semantically wrong and accidentally works only in the zero-player case.
    -- Collect into a table and check the count explicitly.
    local players = {sector:getPlayers()}
    if #players == 0 then
        local generator = SectorGenerator(x, y)
        local entities = {sector:getEntitiesByComponent(ComponentType.Owner)}
        for _, entity in pairs(entities) do
            if entity:hasComponent(ComponentType.Durability) and entity.aiOwned then
                -- SectorGenerator:createWreckage(faction, plan, breaks) takes the Plan directly.
                local plan = Plan(entity.id)
                local wreckage = generator:createWreckage(nil, plan, 0)
                entity:clearCargoBay()
                sector:deleteEntity(entity)
            end
        end
    end

    terminate()
end

function initialize(...)
    if SpawnEclipseBoss.initialize then return SpawnEclipseBoss.initialize(...) end
end

return SpawnEclipseBoss
