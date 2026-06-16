package.path = package.path .. ";data/scripts/lib/?.lua"

local cv_success, CosmicVaultBuffs = true, require("cosmicvaultbuffs")

-- Namespace WorldEater
WorldEater = {}
WorldEater.phases = {
    phase2 = false, -- 80% (5 Defilers)
    phase3 = false, -- 70% (EMP Pulse)
    phase4 = false, -- 60% (4 Destroyers)
    phase5 = false, -- 50% (Blink & Heal)
    phase6 = false  -- 35% (Blink, EMP, Enrage)
}
WorldEater.healPool = 0
WorldEater.healRate = 0

function WorldEater.initialize()
    if not onServer() then return end
    local entity = Entity()
    entity:registerCallback("onDamaged", "onDamaged")
end

function WorldEater.getUpdateInterval()
    return 1.0
end

function WorldEater.updateServer(timeStep)
    if WorldEater.healPool > 0 then
        local entity = Entity()
        local healAmount = math.min(WorldEater.healPool, WorldEater.healRate * timeStep)
        entity.durability = math.min(entity.maxDurability, entity.durability + healAmount)
        WorldEater.healPool = WorldEater.healPool - healAmount
    end
end

function WorldEater.onDamaged(objectIndex, amount, inflictor, damageSource, damageType)
    local entity = Entity()
    local hpPercent = entity.durability / entity.maxDurability
    local sector = Sector()

    -- Phase 2: 80% HP (5 Defilers)
    if hpPercent <= 0.80 and not WorldEater.phases.phase2 then
        WorldEater.phases.phase2 = true
        sector:broadcastChatMessage(entity.title, 2, "REINFORCEMENTS CALLED. ANNIHILATION PROTOCOL ADVANCING.")
        WorldEater.spawnEscorts("defiler", 5)
    end

    -- Phase 3: 70% HP (EMP Pulse)
    if hpPercent <= 0.70 and not WorldEater.phases.phase3 then
        WorldEater.phases.phase3 = true
        sector:broadcastChatMessage(entity.title, 1, "WARNING: MASSIVE DARK MATTER SURGE DETECTED.")
        WorldEater.empPulse()
    end

    -- Phase 4: 60% HP (4 Destroyers)
    if hpPercent <= 0.60 and not WorldEater.phases.phase4 then
        WorldEater.phases.phase4 = true
        sector:broadcastChatMessage(entity.title, 2, "HEAVY ESCORT DEPLOYED. CEASE YOUR RESISTANCE.")
        WorldEater.spawnEscorts("destroyer", 4)
    end

    -- Phase 5: 50% HP (Blink & Heal)
    if hpPercent <= 0.50 and not WorldEater.phases.phase5 then
        WorldEater.phases.phase5 = true
        sector:broadcastChatMessage(entity.title, 2, "CRITICAL DAMAGE. INITIATING EMERGENCY DISPLACEMENT AND REPAIRS.")
        WorldEater.blink()
        -- Heal 10% of Max HP over 60 seconds
        WorldEater.healPool = entity.maxDurability * 0.10
        WorldEater.healRate = WorldEater.healPool / 60.0
    end

    -- Phase 6: 35% HP (Blink, EMP, Enrage)
    if hpPercent <= 0.35 and not WorldEater.phases.phase6 then
        WorldEater.phases.phase6 = true
        sector:broadcastChatMessage(entity.title, 0, "ERROR. CORE INSTABILITY. ENRAGE PROTOCOL ENGAGED.")
        WorldEater.blink()
        WorldEater.empPulse()
        
        -- Enrage Buffs (+50% Fire Rate, +50% Damage)
        if cv_success and CosmicVaultBuffs then
            CosmicVaultBuffs.applyPermanentFactor(entity.id, StatsBonuses.FireRate, 1.5)
            
            local damageBonuses = {StatsBonuses.EnergyDamage, StatsBonuses.ElectricDamage, StatsBonuses.PlasmaDamage, StatsBonuses.AntiMatterDamage, StatsBonuses.FragmentsDamage, StatsBonuses.PhysicalDamage}
            for _, stat in pairs(damageBonuses) do
                CosmicVaultBuffs.applyPermanentFactor(entity.id, stat, 1.5)
            end
        end
    end
end

function WorldEater.spawnEscorts(shipType, count)
    local EclipseGenerator = include("eclipsegenerator")
    local entity = Entity()
    local dir = entity.look
    local up = entity.up
    local right = entity.right
    local center = entity.translationf
    
    for i = 1, count do
        local rx = (random():getFloat(-1, 1) * 2000)
        local ry = (random():getFloat(-1, 1) * 2000)
        local rz = (random():getFloat(500, 2000))
        local pos = center + vec3(rx, ry, rz)
        local cMat = MatrixLookUpPosition(up, dir, pos)
        
        if shipType == "defiler" then
            EclipseGenerator.createDefiler(cMat)
        elseif shipType == "destroyer" then
            EclipseGenerator.createDestroyer(cMat)
        end
    end
end

function WorldEater.empPulse()
    local sector = Sector()
    local players = {sector:getPlayers()}
    local myPos = Entity().translationf
    
    for _, player in pairs(players) do
        local craft = player.craft
        if craft and craft.shieldDurability then
            -- Strip 50% of the player's shield capacity directly
            craft.shieldDurability = craft.shieldDurability * 0.5
            
            -- Visual effect
            sector:createHyperspaceJumpAnimation(craft, craft.look, ColorRGB(0.5, 0.0, 1.0), 0.5)
            player:sendChatMessage("Ship Computer", 1, "WARNING: Dark Matter EMP has stripped 50% of our shields!")
        end
    end
end

function WorldEater.blink()
    local entity = Entity()
    local sector = Sector()
    
    -- Visual indication of jumping out
    sector:createHyperspaceJumpAnimation(entity, entity.look, ColorRGB(0.6, 0.5, 0.3), 1.0)
    
    -- Pick a random spot 15 to 25 km away from the center
    local dist = random():getFloat(15000, 25000)
    local rx = random():getFloat(-1, 1)
    local ry = random():getFloat(-1, 1)
    local rz = random():getFloat(-1, 1)
    local dir = normalize(vec3(rx, ry, rz))
    
    local newPos = dir * dist
    local mat = entity.position
    mat.translation = newPos
    entity.position = mat
    
    -- Visual indication of jumping in
    sector:createHyperspaceJumpAnimation(entity, entity.look, ColorRGB(0.6, 0.5, 0.3), 1.0)
end

function WorldEater.secure()
    return {
        phases = WorldEater.phases,
        healPool = WorldEater.healPool,
        healRate = WorldEater.healRate
    }
end

function WorldEater.restore(data)
    WorldEater.phases = data.phases or WorldEater.phases
    WorldEater.healPool = data.healPool or 0
    WorldEater.healRate = data.healRate or 0
end
