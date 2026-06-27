package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("randomext")
include("utility")
local EclipseGenerator = include("eclipsegenerator")

-- namespace CAWorldEater
CAWorldEater = {}

local data = {}
data.dreadnoughtIds = {}
data.abilityTimer = 0
data.tetherLasers = {}

local activeGlows = {}
local activeAnomalies = {}

data.phasesTriggered = {
    p80 = false,
    p70 = false,
    p60 = false,
    p50 = false,
    p35 = false
}

function CAWorldEater.initialize()
    local entity = Entity()
    if onServer() then
        -- Register boss healthbar globally
        registerBoss(entity.index)
        
        -- Make boss invincible initially until tether logic runs
        entity.invincible = true
        
        -- Spawn the tethering dreadnoughts
        CAWorldEater.spawnTethers()
        
        entity:registerCallback("onDestroyed", "onDestroyed")
    end
end

function CAWorldEater.spawnTethers()
    if not onServer() then return end
    
    local sector = Sector()
    local boss = Entity()
    
    -- Spawn 4 Juggernauts to act as Tethers
    for i = 1, 4 do
        local angle = (math.pi / 2) * i
        local dist = 1500
        
        local look = vec3(math.cos(angle), 0, math.sin(angle))
        local up = vec3(0, 1, 0)
        local pos = boss.translationf + look * dist
        
        local matrix = MatrixLookUpPosition(look, up, pos)
        local dreadnought = EclipseGenerator.createJuggernaut(matrix)
        
        if dreadnought then
            dreadnought:setValue("is_worldeater_tether", true)
            dreadnought.title = "Eclipse Anchor Pylon"%_T
            
            -- Prevent them from warping away
            dreadnought:addScriptOnce("utility/aiundockable.lua")
            
            table.insert(data.dreadnoughtIds, dreadnought.id.string)
        end
    end
end

function CAWorldEater.getUpdateInterval()
    return 1.0
end

function CAWorldEater.updateServer(timeStep)
    local boss = Entity()
    local sector = Sector()
    
    -- Update Tethers & Invulnerability
    local activeTethers = 0
    for _, idStr in pairs(data.dreadnoughtIds) do
        local tether = sector:getEntity(Uuid(idStr))
        if tether then
            activeTethers = activeTethers + 1
        end
    end
    
    if activeTethers > 0 then
        boss.invincible = true
    else
        if boss.invincible then
            boss.invincible = false
            sector:broadcastChatMessage(boss.title, 0, "ANCHOR PYLONS DESTROYED. VOID SHIELD DEACTIVATED.")
        end
    end
    
    -- Visual Lasers
    CAWorldEater.updateLasers()
    
    -- Boss Abilities
    data.abilityTimer = data.abilityTimer + timeStep
    
    -- Every 15 seconds, pick an ability
    if data.abilityTimer >= 15.0 then
        data.abilityTimer = 0
        CAWorldEater.castRandomAbility()
    end
    
    -- Process Anomalies (Gravity Pull & EMP Detonations)
    CAWorldEater.processHazards(timeStep)
    
    -- Process 6-Phase HP Gauntlet
    CAWorldEater.checkPhases()
end

function CAWorldEater.castRandomAbility()
    local sector = Sector()
    local players = {sector:getPlayers()}
    if #players == 0 then return end
    
    local targetPlayer = players[random():getInt(1, #players)]
    local targetShip = targetPlayer.craft
    if not targetShip then return end
    
    local choice = random():getInt(1, 2)
    local boss = Entity()
    
    if choice == 1 then
        -- Telegraphed EMP
        sector:broadcastChatMessage(boss.title, 2, "INITIATING QUANTUM EMP.")
        
        -- Store the hazard
        table.insert(activeGlows, {
            position = targetShip.translationf,
            timer = 3.0, -- detonates in 3 seconds
            radius = 3000
        })
        
        -- Sync to client for visual glow
        broadcastInvokeClientFunction("createEmpGlow", targetShip.translationf, 3000)
    else
        -- Gravity Anomaly
        sector:broadcastChatMessage(boss.title, 2, "DEPLOYING GRAVITY ANOMALY.")
        
        -- Spawn the anomaly at their current position
        table.insert(activeAnomalies, {
            position = targetShip.translationf,
            timer = 15.0, -- lasts 15 seconds
            radius = 4000,
            pullStrength = 200.0
        })
        
        broadcastInvokeClientFunction("createAnomalyGlow", targetShip.translationf, 4000)
    end
end

function CAWorldEater.processHazards(timeStep)
    local sector = Sector()
    local boss = Entity()
    
    -- Process EMPs
    for i = #activeGlows, 1, -1 do
        local emp = activeGlows[i]
        emp.timer = emp.timer - timeStep
        if emp.timer <= 0 then
            -- Detonate!
            sector:createExplosion(emp.position, 1000, false)
            
            local ships = {sector:getEntitiesByLocation(Sphere(emp.position, emp.radius))}
            for _, ship in pairs(ships) do
                if ship.factionIndex ~= boss.factionIndex then
                    local shield = Shield(ship.id)
                    if shield then
                        shield.durability = 0 -- Instantly strip all shields
                    end
                    local durability = Durability(ship.id)
                    if durability then
                        durability:inflictDamage(1000000, 1, DamageType.Energy, boss.id)
                    end
                end
            end
            
            table.remove(activeGlows, i)
        end
    end
    
    -- Process Gravity Anomalies
    for i = #activeAnomalies, 1, -1 do
        local anom = activeAnomalies[i]
        anom.timer = anom.timer - timeStep
        if anom.timer <= 0 then
            table.remove(activeAnomalies, i)
        else
            local ships = {sector:getEntitiesByLocation(Sphere(anom.position, anom.radius))}
            for _, ship in pairs(ships) do
                if ship.factionIndex ~= boss.factionIndex and ship.isShip then
                    local velComponent = Velocity(ship.id)
                    if velComponent then
                        -- Pull ship towards anomaly center
                        local dir = normalize(anom.position - ship.translationf)
                        velComponent:addVelocity(dir * anom.pullStrength * timeStep)
                    end
                    
                    -- Damage over time inside the anomaly
                    local durability = Durability(ship.id)
                    if durability then
                        durability:inflictDamage(50000 * timeStep, 1, DamageType.Physical, boss.id)
                    end
                end
            end
        end
    end
end

-- Client Side Visuals
function CAWorldEater.createEmpGlow(pos, radius)
    if onClient() then
        Sector():createGlow(pos, radius, ColorRGB(0.0, 1.0, 1.0))
    end
end
callable(CAWorldEater, "createEmpGlow")

function CAWorldEater.createAnomalyGlow(pos, radius)
    if onClient() then
        -- A dark purple glow for a black hole
        Sector():createGlow(pos, radius / 2, ColorRGB(0.2, 0.0, 0.4))
    end
end
callable(CAWorldEater, "createAnomalyGlow")

function CAWorldEater.updateLasers(tetherIds)
    if onClient() then
        local sector = Sector()
        local boss = Entity()
        
        -- Rebuild visual lasers
        for _, laser in pairs(data.tetherLasers) do
            if valid(laser) then sector:removeLaser(laser) end
        end
        data.tetherLasers = {}
        
        if tetherIds then
            for _, idStr in pairs(tetherIds) do
                local tether = sector:getEntity(Uuid(idStr))
                if tether then
                    -- Thick purple laser
                    local laser = sector:createLaser(tether.translationf, boss.translationf, ColorRGB(0.6, 0.0, 1.0), 35.0)
                    laser.collision = false
                    table.insert(data.tetherLasers, laser)
                end
            end
        end
    else
        broadcastInvokeClientFunction("updateLasers", data.dreadnoughtIds)
    end
end
callable(CAWorldEater, "updateLasers")


function CAWorldEater.checkPhases()
    local boss = Entity()
    local sector = Sector()
    
    local hpPct = boss.durability / boss.maxDurability
    
    if hpPct <= 0.8 and not data.phasesTriggered.p80 then
        data.phasesTriggered.p80 = true
        sector:broadcastChatMessage(boss.title, 2, "DEFENSIVE PROTOCOLS ACTIVE. DEPLOYING ESCORTS.")
        -- Spawn 5 Defilers
        for i = 1, 5 do
            local dir = vec3(random():getFloat(-1, 1), random():getFloat(-1, 1), random():getFloat(-1, 1))
            local pos = boss.translationf + normalize(dir) * 1500
            local m = MatrixLookUpPosition(dir, vec3(0,1,0), pos)
            local esc = EclipseGenerator.createDefiler(m)
            if esc then
                sector:createHyperspaceJumpAnimation(esc, esc.look, ColorRGB(0.5, 0.0, 1.0), 0.5)
            end
        end
    end
    
    if hpPct <= 0.7 and not data.phasesTriggered.p70 then
        data.phasesTriggered.p70 = true
        sector:broadcastChatMessage(boss.title, 2, "GLOBAL SHIELD ANNIHILATION PULSE CHARGED.")
        local players = {sector:getPlayers()}
        for _, p in pairs(players) do
            local ship = p.craft
            if ship then
                local s = Shield(ship.id)
                if s then
                    s.durability = s.durability * 0.5
                end
            end
        end
        broadcastInvokeClientFunction("createGlobalEmpGlow", boss.translationf)
    end
    
    if hpPct <= 0.6 and not data.phasesTriggered.p60 then
        data.phasesTriggered.p60 = true
        sector:broadcastChatMessage(boss.title, 2, "DEPLOYING HUNTER KILLER SQUADRON.")
        -- Spawn 4 Destroyers (Assassins)
        for i = 1, 4 do
            local dir = vec3(random():getFloat(-1, 1), random():getFloat(-1, 1), random():getFloat(-1, 1))
            local pos = boss.translationf + normalize(dir) * 1500
            local m = MatrixLookUpPosition(dir, vec3(0,1,0), pos)
            local esc = EclipseGenerator.createAssassin(m)
            if esc then
                sector:createHyperspaceJumpAnimation(esc, esc.look, ColorRGB(0.5, 0.0, 1.0), 0.5)
            end
        end
    end
    
    if hpPct <= 0.5 and not data.phasesTriggered.p50 then
        data.phasesTriggered.p50 = true
        sector:broadcastChatMessage(boss.title, 2, "EMERGENCY REPAIRS INITIATED.")
        CAWorldEater.triggerBlink()
        boss.durability = math.min(boss.maxDurability, boss.durability + (boss.maxDurability * 0.1))
    end
    
    if hpPct <= 0.35 and not data.phasesTriggered.p35 then
        data.phasesTriggered.p35 = true
        sector:broadcastChatMessage(boss.title, 2, "CRITICAL DAMAGE DETECTED. ENRAGE PROTOCOL ENGAGED.")
        CAWorldEater.triggerBlink()
        
        -- Second EMP
        local players = {sector:getPlayers()}
        for _, p in pairs(players) do
            local ship = p.craft
            if ship then
                local s = Shield(ship.id)
                if s then
                    s.durability = s.durability * 0.5
                end
            end
        end
        broadcastInvokeClientFunction("createGlobalEmpGlow", boss.translationf)
        
        -- Enrage
        boss.damageMultiplier = (boss.damageMultiplier or 1.0) * 1.5
        boss:addMultiplyableBias(StatsBonuses.FireRate, 0.5)
    end
end

function CAWorldEater.triggerBlink()
    local entity = Entity()
    local sector = Sector()
    sector:createHyperspaceJumpAnimation(entity, entity.translationf, ColorRGB(0.5, 0.0, 1.0), 0.5)
    local dir = normalize(vec3(random():getFloat() - 0.5, random():getFloat() - 0.5, random():getFloat() - 0.5))
    local dist = random():getInt(5000, 10000)
    entity.position = MatrixLookUpPosition(entity.look, entity.up, entity.translationf + dir * dist)
    sector:createHyperspaceJumpAnimation(entity, entity.translationf, ColorRGB(0.5, 0.0, 1.0), 0.5)
end

function CAWorldEater.createGlobalEmpGlow(pos)
    if onClient() then
        Sector():createGlow(pos, 50000, ColorRGB(0.0, 1.0, 1.0))
    end
end
callable(CAWorldEater, "createGlobalEmpGlow")

function CAWorldEater.onDestroyed()
    if not onServer() then return end
    local entity = Entity()
    local sector = Sector()
    local pos = entity.translationf

    -- Drop massive amounts of Ascendant Matter (100 - 250)
    sector:dropCargo(pos, nil, nil, Good("Ascendant Matter"), 0, random():getInt(100, 250))

    -- Boss drops legendary weapons, upgrades, and high tier turrets
    
    -- Drop 5-10 max tech legendary weapons
    for i = 1, random():getInt(5, 10) do
        local turret = SectorTurretGenerator():generateArmed(0, 0, 0, Rarity(RarityType.Legendary))
        if turret then
            turret.tech = 52
            sector:dropTurret(pos, nil, nil, turret)
        end
    end
    
    -- Drop 5-10 legendary system upgrades
    local UpgradeGenerator = include("upgradegenerator")
    local generator = UpgradeGenerator()
    for i = 1, random():getInt(5, 10) do
        local upgrade = generator:generateSystem(Rarity(RarityType.Legendary))
        if upgrade then
            sector:dropUpgrade(pos, nil, nil, upgrade)
        end
    end
    
    sector:broadcastChatMessage("System", 0, "The World Eater has been completely eradicated. The Void is calm once more.")
end

function getUpdateInterval(...)
    if CAWorldEater.getUpdateInterval then return CAWorldEater.getUpdateInterval(...) end
end
function updateServer(...)
    if CAWorldEater.updateServer then return CAWorldEater.updateServer(...) end
end
function initialize(...)
    if CAWorldEater.initialize then return CAWorldEater.initialize(...) end
end
function createEmpGlow(...)
    if CAWorldEater.createEmpGlow then return CAWorldEater.createEmpGlow(...) end
end
function createAnomalyGlow(...)
    if CAWorldEater.createAnomalyGlow then return CAWorldEater.createAnomalyGlow(...) end
end
function updateLasers(...)
    if CAWorldEater.updateLasers then return CAWorldEater.updateLasers(...) end
end
function createGlobalEmpGlow(...)
    if CAWorldEater.createGlobalEmpGlow then return CAWorldEater.createGlobalEmpGlow(...) end
end
function onDestroyed(...)
    if CAWorldEater.onDestroyed then return CAWorldEater.onDestroyed(...) end
end

