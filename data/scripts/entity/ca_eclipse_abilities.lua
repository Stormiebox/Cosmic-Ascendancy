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

        EclipseAbilities.isSiphon = string.match(name, "void%-weaver") or string.match(name, "carrier") or string.match(name, "juggernaut") or string.match(name, "dreadnought") or string.match(name, "cruiser") or string.match(name, "harbinger") or string.match(name, "world%-eater")
        EclipseAbilities.isEthereal = string.match(name, "phantom") or string.match(name, "interceptor")
        EclipseAbilities.isAdaptive = string.match(name, "defiler") or string.match(name, "artillery") or string.match(name, "singularity")
        EclipseAbilities.isSingularity = string.match(name, "carrier") or string.match(name, "juggernaut") or string.match(name, "dreadnought") or string.match(name, "cruiser") or string.match(name, "harbinger") or string.match(name, "world%-eater")

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

    -- Void Siphon Aura: drains 1% max shield per tick from nearby players and heals self
    if EclipseAbilities.isSiphon then
        local sector = Sector()
        local players = {sector:getPlayers()}
        local healAmount = 0

        for _, player in pairs(players) do
            local pShip = player.craft
            if pShip and pShip.factionIndex ~= entity.factionIndex then
                local dist = distance(entity.translationf, pShip.translationf)
                if dist <= 300.0 then -- 3km aura radius
                    -- Access shield properties directly on the entity object.
                    local pShieldMax = pShip.shieldMaxDurability or 0
                    if pShieldMax > 0 and pShip.shieldDurability > 0 then
                        local drain = pShieldMax * 0.01 -- Drain 1% of max shield per 0.5s tick
                        drain = math.min(drain, pShip.shieldDurability) -- Never drain more than what's left
                        pShip.shieldDurability = pShip.shieldDurability - drain
                        healAmount = healAmount + drain
                    end
                end
            end
        end

        -- Transfer all drained shield energy to the Eclipse entity as healing
        if healAmount > 0 then
            local bossShieldMax = entity.shieldMaxDurability or 0
            if bossShieldMax > 0 then
                entity.shieldDurability = math.min(bossShieldMax, entity.shieldDurability + healAmount)
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

    local maxShield = entity.shieldMaxDurability or 0

    -- Blink trigger: if entity lost 15% of max HP or max Shields in a 1-second burst
    local blinkTriggered = false
    if maxShield > 0 and EclipseAbilities.burstDamageTracker > (maxShield * 0.15) then
        blinkTriggered = true
    end
    if EclipseAbilities.burstDamageTracker > (entity.maxDurability * 0.15) then
        blinkTriggered = true
    end

    if blinkTriggered then
        EclipseAbilities.triggerBlink()
        EclipseAbilities.burstDamageTracker = 0
    end

    -- Adaptive Resistance: after absorbing 5% max HP of a single element, resist it for 15s
    if EclipseAbilities.isAdaptive then
        if now > EclipseAbilities.resistanceEndTime then
            EclipseAbilities.activeResistance = nil -- Resistance expired, reset
        end

        if damageType and damageTypes[damageType] then
            EclipseAbilities.elementalTracker[damageType] = (EclipseAbilities.elementalTracker[damageType] or 0) + amount

            if EclipseAbilities.elementalTracker[damageType] > (entity.maxDurability * 0.05) then
                if EclipseAbilities.activeResistance ~= damageType then
                    EclipseAbilities.activeResistance = damageType
                    EclipseAbilities.resistanceEndTime = now + 15.0
                    Sector():broadcastChatMessage(entity.title, 2, "ADAPTIVE ARMOR ENGAGED: RESISTING " .. string.upper(damageTypes[damageType]))
                    EclipseAbilities.elementalTracker = {} -- Reset tracker after adapting
                end
            end
        end

        -- While the active resistance is engaged, heal back 75% of damage taken from that element
        if EclipseAbilities.activeResistance == damageType and damageType ~= DamageType.Physical then
             entity.durability = math.min(entity.maxDurability, entity.durability + (amount * 0.75))
        end
    end

    -- Ethereal Phase Shift: triggers once when shields hit zero
    if EclipseAbilities.isEthereal and not EclipseAbilities.hasPhased then
        if maxShield > 0 and entity.shieldDurability <= 0 then
            EclipseAbilities.triggerPhaseShift()
        end
    end
end

function EclipseAbilities.onShieldDamaged(objectIndex, amount, inflictor, damageSource, damageType)
    local entity = Entity()
    local now = Server().unpausedRuntime

    if EclipseAbilities.isPhasing then return end

    if now - EclipseAbilities.lastDamageTime > 1.0 then
        EclipseAbilities.burstDamageTracker = 0 -- Reset burst window when more than 1 second passes between hits
    end
    EclipseAbilities.burstDamageTracker = EclipseAbilities.burstDamageTracker + amount
    EclipseAbilities.lastDamageTime = now

    -- Read shield stats directly from the entity object instead.
    local maxShield = entity.shieldMaxDurability or 0

    if maxShield > 0 then
        -- Void Shields Mechanic: Eclipse ships absorb 90% of incoming physical damage on shields
        -- This makes them highly resistant to kinetic weapons while their shields are up
        if damageType == DamageType.Physical then
            local mitigated = amount * 0.90
            entity.shieldDurability = math.min(maxShield, entity.shieldDurability + mitigated)
        end

        -- Blink trigger: if shield burst damage exceeds 15% of max shield in 1 second
        if EclipseAbilities.burstDamageTracker > (maxShield * 0.15) then
            EclipseAbilities.triggerBlink()
            EclipseAbilities.burstDamageTracker = 0
        end
    end

    -- Adaptive resistance logic for shields
    if EclipseAbilities.isAdaptive then
        if now > EclipseAbilities.resistanceEndTime then
            EclipseAbilities.activeResistance = nil -- Resistance window expired
        end

        if damageType and damageTypes[damageType] then
            EclipseAbilities.elementalTracker[damageType] = (EclipseAbilities.elementalTracker[damageType] or 0) + amount
            -- Trigger adaptation if a single element exceeds 5% of max shield total
            if maxShield > 0 and EclipseAbilities.elementalTracker[damageType] > (maxShield * 0.05) then
                if EclipseAbilities.activeResistance ~= damageType then
                    EclipseAbilities.activeResistance = damageType
                    EclipseAbilities.resistanceEndTime = now + 15.0
                    Sector():broadcastChatMessage(entity.title, 2, "ADAPTIVE SHIELDS ENGAGED: RESISTING " .. string.upper(damageTypes[damageType]))
                    EclipseAbilities.elementalTracker = {} -- Reset tracker after adapting
                end
            end
        end

        -- While adapted to an element, heal back 75% of that element's damage to shields
        if EclipseAbilities.activeResistance == damageType and damageType ~= DamageType.Physical then
            entity.shieldDurability = math.min(maxShield, entity.shieldDurability + (amount * 0.75))
        end
    end

    -- Ethereal Phase Shift: triggers once when shield is fully depleted
    if EclipseAbilities.isEthereal and not EclipseAbilities.hasPhased then
        if maxShield > 0 and entity.shieldDurability <= 0 then
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
    sector:createHyperspaceJumpAnimation(entity, entity.look, ColorRGB(0.5, 0.0, 1.0), 0.5)

    local random = random()
    local dir = normalize(vec3(random:getFloat() - 0.5, random:getFloat() - 0.5, random:getFloat() - 0.5))
    local dist = random:getInt(500, 1000) -- 5km to 10km

    entity.position = MatrixLookUpPosition(entity.look, entity.up, entity.translationf + dir * dist)

    -- Reappear VFX
    sector:createHyperspaceJumpAnimation(entity, entity.look, ColorRGB(0.5, 0.0, 1.0), 0.5)
end

function EclipseAbilities.triggerPhaseShift()
    local entity = Entity()
    local now = Server().unpausedRuntime

    -- Mark as phased (hasPhased is a one-time flag — phase shift only triggers once per ship lifetime)
    EclipseAbilities.hasPhased = true
    EclipseAbilities.isPhasing = true
    -- Phase ends 4 seconds after trigger — updateServer will clear invincibility at phaseEndTime
    EclipseAbilities.phaseEndTime = now + 4.0

    entity.invincible = true
    Sector():createHyperspaceJumpAnimation(entity, entity.look, ColorRGB(0.1, 0.1, 0.1), 1.0)

    -- Only register it here for non-Siphon ships so the phase expiry timer runs.
    -- Registering twice would cause the update to fire twice per tick.
    if not EclipseAbilities.isSiphon then
        entity:registerCallback("updateServer", "updateServer")
    end
end

function EclipseAbilities.onDestroyed()
    local entity = Entity()
    local sector = Sector()
    local pos = entity.translationf

    -- 25% chance to drop 1-3 Ascendant Matter on death
    -- Use sector:dropLoot with a CargoLoot wrapper object instead.
    if random():getFloat() < 0.25 then
        sector:dropLoot(pos, CargoLoot(Good("Ascendant Matter"), random():getInt(1, 3)))
    end

    -- Singularity ships trigger a 3-second delayed explosion on death
    if EclipseAbilities.isSingularity then
        sector:broadcastChatMessage("The Eclipse", 1, "WARNING: SINGULARITY CORE COLLAPSE IMMINENT.")
        -- Pass the position as 3 separate float args because the sector script stores them individually
        sector:addScriptOnce("data/scripts/sector/ca_singularity_detonation.lua", pos.x, pos.y, pos.z)
    end
end

function initialize(...)
    if EclipseAbilities.initialize then return EclipseAbilities.initialize(...) end
end
function getUpdateInterval(...)
    if EclipseAbilities.getUpdateInterval then return EclipseAbilities.getUpdateInterval(...) end
end
function updateServer(...)
    if EclipseAbilities.updateServer then return EclipseAbilities.updateServer(...) end
end

-- Global Event Callbacks
function onDamaged(...)
    if EclipseAbilities.onDamaged then return EclipseAbilities.onDamaged(...) end
end
function onShieldDamaged(...)
    if EclipseAbilities.onShieldDamaged then return EclipseAbilities.onShieldDamaged(...) end
end
function onDestroyed(...)
    if EclipseAbilities.onDestroyed then return EclipseAbilities.onDestroyed(...) end
end
