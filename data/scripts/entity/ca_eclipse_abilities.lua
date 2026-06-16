package.path = package.path .. ";data/scripts/lib/?.lua"

local EclipseAbilities = {}

-- State tracking
EclipseAbilities.lastBlink = 0
EclipseAbilities.hasPhased = false
EclipseAbilities.phaseEndTime = 0
EclipseAbilities.isPhasing = false
EclipseAbilities.lastDamageTime = 0
EclipseAbilities.burstDamageTracker = 0
EclipseAbilities.activeResistance = nil
EclipseAbilities.resistanceEndTime = 0

-- Elemental types
local damageTypes = {
    [DamageType.Physical] = "Physical",
    [DamageType.Plasma] = "Plasma",
    [DamageType.Electric] = "Electric",
    [DamageType.Energy] = "Energy",
    [DamageType.AntiMatter] = "AntiMatter",
    [DamageType.Fragments] = "Fragments"
}
EclipseAbilities.elementalTracker = {}

function EclipseAbilities.initialize()
    if onServer() then
        local entity = Entity()
        if not entity then return end

        entity:registerCallback("onDamaged", "onDamaged")
        entity:registerCallback("onShieldDamaged", "onShieldDamaged")
        entity:registerCallback("onDestroyed", "onDestroyed")
        
        -- Identify class based on title
        local title = entity.title or ""
        local translatedTitle = entity.translatedTitle or ""
        local name = string.lower(title .. " " .. translatedTitle)
        
        EclipseAbilities.isSiphon = string.match(name, "void%-weaver") or string.match(name, "juggernaut") or string.match(name, "dreadnought") or string.match(name, "cruiser") or string.match(name, "harbinger") or string.match(name, "world%-eater")
        EclipseAbilities.isEthereal = string.match(name, "phantom") or string.match(name, "interceptor")
        EclipseAbilities.isAdaptive = string.match(name, "defiler") or string.match(name, "singularity")
        EclipseAbilities.isSingularity = string.match(name, "juggernaut") or string.match(name, "dreadnought") or string.match(name, "cruiser") or string.match(name, "harbinger") or string.match(name, "world%-eater")
        
        -- Initial aura loop if it has it
        if EclipseAbilities.isSiphon then
            entity:registerCallback("updateServer", "updateServer")
        end
    end
end

function EclipseAbilities.getUpdateInterval()
    return 0.5 -- Fast interval for aura / phase tracking
end

function EclipseAbilities.updateServer(timeStep)
    local entity = Entity()
    if not entity then return end
    
    local now = Server().unpausedRuntime
    
    -- Handle Phasing state removal
    if EclipseAbilities.isPhasing and now > EclipseAbilities.phaseEndTime then
        EclipseAbilities.isPhasing = false
        entity.invincible = false
    end
    
    -- Void Siphon Aura
    if EclipseAbilities.isSiphon then
        local sector = Sector()
        local players = {sector:getPlayers()}
        local healAmount = 0
        
        for _, player in pairs(players) do
            local pShip = player.craft
            if pShip and pShip.factionIndex ~= entity.factionIndex then
                local dist = distance(entity.translationf, pShip.translationf)
                if dist <= 300.0 then -- 3km
                    local pShield = Shield(pShip.id)
                    if pShield and pShield.durability > 0 then
                        local drain = pShield.maximum * 0.01 -- 1% shield drain per 0.5 seconds
                        drain = math.min(drain, pShield.durability)
                        pShield.durability = pShield.durability - drain
                        healAmount = healAmount + drain
                    end
                end
            end
        end
        
        if healAmount > 0 then
            local eShield = Shield(entity.id)
            if eShield then
                eShield.durability = math.min(eShield.maximum, eShield.durability + healAmount)
            end
        end
    end
end

function EclipseAbilities.onDamaged(objectIndex, amount, inflictor, damageSource, damageType)
    local entity = Entity()
    local now = Server().unpausedRuntime
    
    if EclipseAbilities.isPhasing then return end
    
    -- Track burst damage for Blink
    if now - EclipseAbilities.lastDamageTime > 1.0 then
        EclipseAbilities.burstDamageTracker = 0
    end
    EclipseAbilities.burstDamageTracker = EclipseAbilities.burstDamageTracker + amount
    EclipseAbilities.lastDamageTime = now
    
    local eShield = Shield(entity.id)
    local maxShield = 1000
    if eShield then maxShield = eShield.maximum end
    
    -- If lost 15% HP or Shields in 1 second
    if EclipseAbilities.burstDamageTracker > (maxShield * 0.15) or EclipseAbilities.burstDamageTracker > (entity.maxDurability * 0.15) then
        EclipseAbilities.triggerBlink()
        EclipseAbilities.burstDamageTracker = 0
    end
    
    -- Adaptive Resistance tracking
    if EclipseAbilities.isAdaptive then
        if now > EclipseAbilities.resistanceEndTime then
            EclipseAbilities.activeResistance = nil
        end
        
        if damageType and damageTypes[damageType] then
            EclipseAbilities.elementalTracker[damageType] = (EclipseAbilities.elementalTracker[damageType] or 0) + amount
            
            if EclipseAbilities.elementalTracker[damageType] > (entity.maxDurability * 0.05) then
                if EclipseAbilities.activeResistance ~= damageType then
                    EclipseAbilities.activeResistance = damageType
                    EclipseAbilities.resistanceEndTime = now + 15.0
                    Sector():broadcastChatMessage(entity.title, 2, "ADAPTIVE ARMOR ENGAGED: RESISTING " .. string.upper(damageTypes[damageType]))
                    EclipseAbilities.elementalTracker = {}
                end
            end
        end
        
        if EclipseAbilities.activeResistance == damageType and damageType ~= DamageType.Physical then
             entity.durability = math.min(entity.maxDurability, entity.durability + (amount * 0.75))
        end
    end
    
    -- Ethereal Phase Shift
    if EclipseAbilities.isEthereal and not EclipseAbilities.hasPhased then
        if eShield and eShield.durability <= 0 then
            EclipseAbilities.triggerPhaseShift()
        end
    end
end

function EclipseAbilities.onShieldDamaged(objectIndex, amount, inflictor, damageSource, damageType)
    local entity = Entity()
    local now = Server().unpausedRuntime
    
    if EclipseAbilities.isPhasing then return end

    if now - EclipseAbilities.lastDamageTime > 1.0 then
        EclipseAbilities.burstDamageTracker = 0
    end
    EclipseAbilities.burstDamageTracker = EclipseAbilities.burstDamageTracker + amount
    EclipseAbilities.lastDamageTime = now
    
    local eShield = Shield(entity.id)
    if eShield and EclipseAbilities.burstDamageTracker > (eShield.maximum * 0.15) then
        EclipseAbilities.triggerBlink()
        EclipseAbilities.burstDamageTracker = 0
    end
    
    -- Adaptive resistance logic for shields
    if EclipseAbilities.isAdaptive then
        if now > EclipseAbilities.resistanceEndTime then
            EclipseAbilities.activeResistance = nil
        end
        
        if damageType and damageTypes[damageType] then
            EclipseAbilities.elementalTracker[damageType] = (EclipseAbilities.elementalTracker[damageType] or 0) + amount
            if eShield and EclipseAbilities.elementalTracker[damageType] > (eShield.maximum * 0.05) then
                if EclipseAbilities.activeResistance ~= damageType then
                    EclipseAbilities.activeResistance = damageType
                    EclipseAbilities.resistanceEndTime = now + 15.0
                    Sector():broadcastChatMessage(entity.title, 2, "ADAPTIVE SHIELDS ENGAGED: RESISTING " .. string.upper(damageTypes[damageType]))
                    EclipseAbilities.elementalTracker = {}
                end
            end
        end
        
        if EclipseAbilities.activeResistance == damageType then
            eShield.durability = math.min(eShield.maximum, eShield.durability + (amount * 0.75))
        end
    end
    
    -- Ethereal Phase Shift
    if EclipseAbilities.isEthereal and not EclipseAbilities.hasPhased then
        if eShield and (eShield.durability - amount) <= 0 then
            EclipseAbilities.triggerPhaseShift()
        end
    end
end

function EclipseAbilities.triggerBlink()
    local entity = Entity()
    local now = Server().unpausedRuntime
    
    if now - EclipseAbilities.lastBlink < 30.0 then return end
    EclipseAbilities.lastBlink = now
    
    local sector = Sector()
    
    -- Void Rift VFX
    sector:createHyperspaceJumpAnimation(entity, entity.translationf, ColorRGB(0.5, 0.0, 1.0), 0.5)
    
    local dir = normalize(vec3(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5))
    local dist = math.random(500, 1000) -- 5km to 10km
    
    entity.position = MatrixLookUpPosition(entity.look, entity.up, entity.translationf + dir * dist)
    
    -- Reappear VFX
    sector:createHyperspaceJumpAnimation(entity, entity.translationf, ColorRGB(0.5, 0.0, 1.0), 0.5)
end

function EclipseAbilities.triggerPhaseShift()
    local entity = Entity()
    local now = Server().unpausedRuntime
    
    EclipseAbilities.hasPhased = true
    EclipseAbilities.isPhasing = true
    EclipseAbilities.phaseEndTime = now + 4.0
    
    entity.invincible = true
    Sector():createHyperspaceJumpAnimation(entity, entity.translationf, ColorRGB(0.1, 0.1, 0.1), 1.0)
    
    if not EclipseAbilities.isSiphon then
        entity:registerCallback("updateServer", "updateServer")
    end
end

function EclipseAbilities.onDestroyed()
    if EclipseAbilities.isSingularity then
        local entity = Entity()
        local sector = Sector()
        local pos = entity.translationf
        
        sector:broadcastChatMessage("The Eclipse", 1, "WARNING: SINGULARITY CORE COLLAPSE IMMINENT.")
        sector:addScript("data/scripts/sector/ca_singularity_detonation.lua", pos.x, pos.y, pos.z)
    end
end

return EclipseAbilities
