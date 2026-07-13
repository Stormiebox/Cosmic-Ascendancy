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
data.nemesisCooldown = 0
data.nemesisActive = false
data.damageHistory = {
    [DamageType.Physical] = 0,
    [DamageType.Energy] = 0,
    [DamageType.Plasma] = 0,
    [DamageType.Electric] = 0,
    [DamageType.AntiMatter] = 0,
    [DamageType.Fragments] = 0
}
data.activeNemesisType = -1
data.laserTargets = {}

local activeGlows = {}
local activeAnomalies = {}

data.phasesTriggered = {
    tethers50 = false,
    tethers25 = false,
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
        CAWorldEater.spawnTethers(4)

        entity:registerCallback("onDestroyed", "onDestroyed")
        entity:registerCallback("onDamaged", "onDamaged")
    else
        invokeServerFunction("syncLasers")
    end
end

function CAWorldEater.spawnTethers(count)
    if not onServer() then return end

    local sector = Sector()
    local boss = Entity()

        -- Spawn 4 Juggernauts to act as Tethers
    local spawnCount = count or 4
    for i = 1, spawnCount do
        local angle = (math.pi / 2) * i + random():getFloat(0, math.pi)
        -- Increased distance from 1500 to 4500 to prevent instant AoE wipes from Singularity collapse
        local dist = 4500

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

    -- Boss Abilities
    data.abilityTimer = data.abilityTimer + timeStep

    -- Every 15 seconds, pick an ability
    if data.abilityTimer >= 15.0 then
        data.abilityTimer = 0
        CAWorldEater.castRandomAbility()
    end

    -- Process Anomalies (Gravity Pull & EMP Detonations)
    CAWorldEater.processHazards(timeStep)

    -- Dark Matter Aura (Constant Pressure - Enrage Phase Only)
    if data.phasesTriggered.p35 then
        local allShips = {sector:getEntitiesByType(EntityType.Ship)}
        local allStations = {sector:getEntitiesByType(EntityType.Station)}
        for _, ship in pairs(allShips) do
            if valid(ship) and ship.factionIndex ~= boss.factionIndex then
                ship:inflictDamage(ship.maxDurability * 0.0025 * timeStep, 1, DamageType.Energy, 0, ship.translationf, boss.id)
            end
        end
        for _, station in pairs(allStations) do
            if valid(station) and station.factionIndex ~= boss.factionIndex then
                station:inflictDamage(station.maxDurability * 0.0025 * timeStep, 1, DamageType.Energy, 0, station.translationf, boss.id)
            end
        end
    end

    -- Process Nemesis Protocol Timers
    if data.nemesisActive then
        data.nemesisCooldown = data.nemesisCooldown - timeStep
        if data.nemesisCooldown <= 0 then
            data.nemesisActive = false
            sector:broadcastChatMessage(boss.title, 0, "ADAPTIVE RESISTANCE PROTOCOL TERMINATED.")
        end
    else
        -- Decay damage history over time
        for k, v in pairs(data.damageHistory) do
            data.damageHistory[k] = math.max(0, v - (boss.maxDurability * 0.005 * timeStep))
        end
    end

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

    local choice = random():getInt(1, 3)
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
    elseif choice == 2 then
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
    else
        -- World-Breaker Laser
        sector:broadcastChatMessage(boss.title, 2, "CHARGING WORLD-BREAKER LASER.")
        table.insert(data.laserTargets, {
            playerShipId = targetShip.id.string,
            timer = 5.0
        })
        broadcastInvokeClientFunction("createTargetLaserGlow", boss.translationf, targetShip.translationf)
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
                if valid(ship) and ship.factionIndex ~= boss.factionIndex then
                    -- Strip all shields directly on the entity
                    ship.shieldDurability = 0
                    -- Inflict raw Energy damage directly on the entity
                    ship:inflictDamage(1000000, 1, DamageType.Energy, 0, ship.translationf, boss.id)
                end
            end

            table.remove(activeGlows, i)
        end
    end

    -- Process World-Breaker Lasers
    for i = #data.laserTargets, 1, -1 do
        local target = data.laserTargets[i]
        target.timer = target.timer - timeStep
        if target.timer <= 0 then
            local ship = sector:getEntity(Uuid(target.playerShipId))
            if valid(ship) then
                -- Check distance
                local dist = distance(boss.translationf, ship.translationf)
                if dist < 20000 then -- 20km range
                    -- Detonate laser!
                    sector:createExplosion(ship.translationf, 200, false)
                    -- Deal massive damage
                    ship:inflictDamage(5000000, 1, DamageType.Energy, 0, ship.translationf, boss.id)
                end
            end
            table.remove(data.laserTargets, i)
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
                if valid(ship) and ship.factionIndex ~= boss.factionIndex and ship.isShip then
                    local dir = normalize(anom.position - ship.translationf)
                    local vel = Velocity(ship.id)
                    if valid(vel) then
                        vel.velocity = vel.velocity + (dir * anom.pullStrength * timeStep)
                        -- Severely dampen their current speed to simulate engine crippling (without permanent stat biases)
                        vel.velocity = vel.velocity * 0.1
                    end

                    -- Damage over time inside the anomaly
                    ship:inflictDamage(50000 * timeStep, 1, DamageType.Physical, 0, ship.translationf, boss.id)
                end
            end
        end
    end
end

-- Client Side Visuals
function CAWorldEater.createEmpGlow(pos, radius)
    if onClient() then
        Sector():createGlow(pos, radius, ColorRGB(0.0, 1.0, 1.0))
        playSound("interface/warning", SoundType.UI, 1.0)
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

function CAWorldEater.createTargetLaserGlow(from, to)
    if onClient() then
        -- Optional: spawn a temporary client-side laser beam
        -- It's complex without state, so we just draw a massive red glow at the target
        Sector():createGlow(to, 5000, ColorRGB(1.0, 0.0, 0.0))
        Sector():createGlow(from, 5000, ColorRGB(1.0, 0.0, 0.0))
    end
end
callable(CAWorldEater, "createTargetLaserGlow")

function CAWorldEater.syncLasers(tetherIds)
    if onServer() then
        broadcastInvokeClientFunction("syncLasers", data.dreadnoughtIds)
    else
        data.dreadnoughtIds = tetherIds or {}
    end
end
callable(CAWorldEater, "syncLasers")

function CAWorldEater.updateClient(timeStep)
    local sector = Sector()
    local boss = Entity()

    for _, idStr in pairs(data.dreadnoughtIds) do
        local tether = sector:getEntity(Uuid(idStr))
        local laser = data.tetherLasers[idStr]

        if tether then
            if not valid(laser) then
                laser = sector:createLaser(tether.translationf, boss.translationf, ColorRGB(0.6, 0.0, 1.0), 35.0)
                laser.collision = false
                data.tetherLasers[idStr] = laser
            end
            laser.from = tether.translationf
            laser.to = boss.translationf
            laser.aliveTime = 0
        else
            if valid(laser) then
                sector:removeLaser(laser)
            end
            data.tetherLasers[idStr] = nil
        end
    end
end

function CAWorldEater.secure()
    return data
end

function CAWorldEater.restore(data_in)
    data = data_in or data
end

function CAWorldEater.checkPhases()
    local boss = Entity()
    local sector = Sector()

    -- Early-out once all 5 phases are triggered to save processing time on idle math.
    local allTriggered = data.phasesTriggered.p80 and data.phasesTriggered.p70 and
                         data.phasesTriggered.p60 and data.phasesTriggered.p50 and
                         data.phasesTriggered.p35
    if allTriggered then return end

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
        local allShips = {sector:getEntitiesByType(EntityType.Ship)}
        local allStations = {sector:getEntitiesByType(EntityType.Station)}
        for _, ship in pairs(allShips) do
            if valid(ship) and ship.factionIndex ~= boss.factionIndex then
                ship.shieldDurability = ship.shieldDurability * 0.5
            end
        end
        for _, station in pairs(allStations) do
            if valid(station) and station.factionIndex ~= boss.factionIndex then
                station.shieldDurability = station.shieldDurability * 0.5
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

    if hpPct <= 0.5 and not data.phasesTriggered.tethers50 then
        data.phasesTriggered.tethers50 = true
        sector:broadcastChatMessage(boss.title, 2, "SPAWNING AUXILIARY ANCHOR PYLONS.")
        CAWorldEater.spawnTethers(2) -- Spawn 2
    end

    if hpPct <= 0.35 and not data.phasesTriggered.p35 then
        data.phasesTriggered.p35 = true
        sector:broadcastChatMessage(boss.title, 2, "CRITICAL DAMAGE DETECTED. ENRAGE PROTOCOL ENGAGED.")
        CAWorldEater.triggerBlink()

        -- Second EMP
        local allShips = {sector:getEntitiesByType(EntityType.Ship)}
        local allStations = {sector:getEntitiesByType(EntityType.Station)}
        for _, ship in pairs(allShips) do
            if valid(ship) and ship.factionIndex ~= boss.factionIndex then
                ship.shieldDurability = ship.shieldDurability * 0.5
            end
        end
        for _, station in pairs(allStations) do
            if valid(station) and station.factionIndex ~= boss.factionIndex then
                station.shieldDurability = station.shieldDurability * 0.5
            end
        end
        broadcastInvokeClientFunction("createGlobalEmpGlow", boss.translationf)

        -- Enrage: boost fire rate (key discarded intentionally - buff is permanent until boss death)
        boss:addMultiplyableBias(StatsBonuses.FireRate, 0.5)
    end

    if hpPct <= 0.25 and not data.phasesTriggered.tethers25 then
        data.phasesTriggered.tethers25 = true
        sector:broadcastChatMessage(boss.title, 2, "SPAWNING FINAL ANCHOR PYLONS.")
        CAWorldEater.spawnTethers(2) -- Spawn 2
    end
end

function CAWorldEater.triggerBlink()
    local entity = Entity()
    local sector = Sector()
    sector:createHyperspaceJumpAnimation(entity, entity.look, ColorRGB(0.5, 0.0, 1.0), 0.5)
    local dir = normalize(vec3(random():getFloat() - 0.5, random():getFloat() - 0.5, random():getFloat() - 0.5))
    local dist = random():getInt(5000, 10000)
    entity.position = MatrixLookUpPosition(entity.look, entity.up, entity.translationf + dir * dist)
    sector:createHyperspaceJumpAnimation(entity, entity.look, ColorRGB(0.5, 0.0, 1.0), 0.5)
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
    local cx, cy = Sector():getCoordinates()
    sector:dropCargo(pos, nil, nil, Good("Ascendant Matter"), 0, random():getInt(100, 250))

    -- Boss drops legendary weapons, upgrades, and high tier turrets

    -- Drop 5-10 max tech legendary weapons
    -- SectorTurretGenerator requires sector coordinates to determine material tier
    local turretGen = SectorTurretGenerator(Sector().seed)
    for i = 1, random():getInt(5, 10) do
        local turret = turretGen:generateArmed(cx, cy, 0, Rarity(RarityType.Legendary))
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

function CAWorldEater.onDamaged(objectIndex, amount, inflictor, damageSource, damageType)
    if not onServer() then return end
    if data.nemesisActive then
        if damageType == data.activeNemesisType then
            -- Heal back 90% of the damage (effectively 90% resistance)
            local boss = Entity()
            boss.durability = math.min(boss.maxDurability, boss.durability + (amount * 0.9))
        end
        return
    end

    if data.damageHistory[damageType] then
        data.damageHistory[damageType] = data.damageHistory[damageType] + amount
        local boss = Entity()
        -- If 5% of max HP is dealt in one damage type quickly, trigger Nemesis Protocol
        if data.damageHistory[damageType] > (boss.maxDurability * 0.05) then
            data.nemesisActive = true
            data.nemesisCooldown = 60.0 -- 60 seconds resistance
            data.activeNemesisType = damageType

            -- Clear history
            for k, v in pairs(data.damageHistory) do
                data.damageHistory[k] = 0
            end

            local typeNames = {
                [DamageType.Physical] = "PHYSICAL",
                [DamageType.Energy] = "ENERGY",
                [DamageType.Plasma] = "PLASMA",
                [DamageType.Electric] = "ELECTRIC",
                [DamageType.AntiMatter] = "ANTIMATTER",
                [DamageType.Fragments] = "FRAGMENTS"
            }
            local typeStr = typeNames[damageType] or "UNKNOWN"
            Sector():broadcastChatMessage(boss.title, 2, "NEMESIS PROTOCOL ENGAGED. 90% IMMUNITY TO " .. typeStr .. " DAMAGE.")
        end
    end
end
