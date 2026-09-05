package.path = package.path .. ";data/scripts/lib/?.lua"

include("goods")

-- namespace EclipseAbilities
EclipseAbilities = {}

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
-- Separate accumulators for hull vs. shield elemental damage: onDamaged/onShieldDamaged used to
-- both accumulate into this one shared table but check it against two different denominators
-- (maxDurability vs. shieldMaxDurability), so raw damage against one surface could trip the other
-- surface's much smaller or larger threshold. Each callback now owns its own table.
EclipseAbilities.elementalTrackerHull = {}
EclipseAbilities.elementalTrackerShield = {}

-- siphon/ethereal/adaptive/singularity are passed in directly by eclipsegenerator.lua's createShip
-- (via addScriptOnce's extra-args forwarding) rather than derived by pattern-matching entity.title
-- here -- createShip() attaches this script before most callers set the ship's real title, so a
-- title-string match at this point would read the wrong, placeholder title for every class except
-- Harbinger/Obliterator.
function EclipseAbilities.initialize(siphon, ethereal, adaptive, singularity)
    if onServer() then
        local entity = Entity()
        if not entity then return end

        entity:registerCallback("onDamaged", "onDamaged")
        entity:registerCallback("onShieldDamaged", "onShieldDamaged")
        entity:registerCallback("onDestroyed", "onDestroyed")

        EclipseAbilities.isSiphon = siphon or false
        EclipseAbilities.isEthereal = ethereal or false
        EclipseAbilities.isAdaptive = adaptive or false
        EclipseAbilities.isSingularity = singularity or false

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

    -- Void Siphon Aura: drains shields or hull from nearby players/ships and heals self
    if EclipseAbilities.isSiphon then
        local sector = Sector()
        local ships = {sector:getEntitiesByType(EntityType.Ship)}
        local stations = {sector:getEntitiesByType(EntityType.Station)}
        local healAmount = 0

        local function siphonTarget(target)
            if target and target.factionIndex ~= entity.factionIndex then
                -- Ascendant Ward: a directly player-owned ship (target.factionIndex is that
                -- player's own index) whose owner currently has an active Ward is skipped
                -- entirely. Alliance-owned craft aren't covered -- there's no single owning
                -- player to check a personal Ward against, and the item is framed as a personal
                -- tool, not a fleet-wide one.
                if target.playerOwned then
                    local owner = Player(target.factionIndex)
                    if owner then
                        local wardUntil = owner:getValue("eclipse_ward_until")
                        if wardUntil and Server().unpausedRuntime < wardUntil then
                            return
                        end
                    end
                end

                local dist = distance(entity.translationf, target.translationf)
                if dist <= 1000.0 then -- 10km aura radius
                    local pShieldMax = target.shieldMaxDurability or 0
                    if pShieldMax > 0 and target.shieldDurability > 0 then
                        local drain = pShieldMax * 0.01 -- Drain 1% of max shield per 0.5s tick
                        drain = math.min(drain, target.shieldDurability)
                        target.shieldDurability = target.shieldDurability - drain
                        healAmount = healAmount + drain
                    else
                        -- Shield is 0, drain hull instead
                        local pHullMax = target.maxDurability or 0
                        if pHullMax > 0 and target.durability > 1 then
                            local drain = pHullMax * 0.005 -- Drain 0.5% max hull
                            drain = math.min(drain, target.durability - 1)
                            -- inflicting damage directly
                            target:inflictDamage(drain, 1, DamageType.Energy, 0, target.translationf, entity.id)
                            healAmount = healAmount + drain
                        end
                    end
                end
            end
        end

        for _, s in pairs(ships) do siphonTarget(s) end
        for _, s in pairs(stations) do siphonTarget(s) end

        -- Transfer drained energy to shields first, then hull (Heals for 25% of damage drained)
        if healAmount > 0 then
            local adjustedHeal = healAmount * 0.25
            local bossShieldMax = entity.shieldMaxDurability or 0
            if bossShieldMax > 0 and entity.shieldDurability < bossShieldMax then
                local shieldSpace = bossShieldMax - entity.shieldDurability
                local toShields = math.min(shieldSpace, adjustedHeal)
                entity.shieldDurability = entity.shieldDurability + toShields
                adjustedHeal = adjustedHeal - toShields
            end
            if adjustedHeal > 0 then
                entity.durability = math.min(entity.maxDurability, entity.durability + adjustedHeal)
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

    -- Track elemental decay
    if not EclipseAbilities.lastElementalTime then EclipseAbilities.lastElementalTime = {} end
    if not EclipseAbilities.lastElementalTime[damageType] then EclipseAbilities.lastElementalTime[damageType] = 0 end
    
    if now - EclipseAbilities.lastElementalTime[damageType] > 3.0 then
        -- Decay memory if not hit by this element in 3 seconds
        EclipseAbilities.elementalTrackerHull[damageType] = 0
    end
    EclipseAbilities.lastElementalTime[damageType] = now

    -- Adaptive Resistance: after absorbing 5% max HP of a single element, resist it for 15s
    if EclipseAbilities.isAdaptive then
        if now > EclipseAbilities.resistanceEndTime then
            EclipseAbilities.activeResistance = nil -- Resistance expired, reset
        end

        if damageType and damageTypes[damageType] then
            EclipseAbilities.elementalTrackerHull[damageType] = (EclipseAbilities.elementalTrackerHull[damageType] or 0) + amount

            if EclipseAbilities.elementalTrackerHull[damageType] > (entity.maxDurability * 0.05) then
                if EclipseAbilities.activeResistance ~= damageType then
                    EclipseAbilities.activeResistance = damageType
                    EclipseAbilities.resistanceEndTime = now + 15.0
                    Sector():broadcastChatMessage(entity.title, 2, "ADAPTIVE ARMOR ENGAGED: RESISTING " .. string.upper(damageTypes[damageType]))
                    EclipseAbilities.elementalTrackerHull = {} -- Reset tracker after adapting
                end
            end
        end

        -- While the active resistance is engaged, heal back 50% of damage taken from that element
        if EclipseAbilities.activeResistance == damageType and damageType ~= DamageType.Physical then
             entity.durability = math.min(entity.maxDurability, entity.durability + (amount * 0.50))
        end
    end

    -- Ethereal Phase Shift: triggers once when shields hit zero
    if EclipseAbilities.isEthereal and not EclipseAbilities.hasPhased then
        if maxShield > 0 and entity.shieldDurability <= 0 then
            EclipseAbilities.triggerPhaseShift()
        end
    end
end

function EclipseAbilities.onShieldDamaged(objectIndex, amount, damageType, inflictor)
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
        -- Void Shields Mechanic: Eclipse ships absorb 80% of incoming physical damage on shields
        -- This makes them highly resistant to kinetic weapons while their shields are up
        if damageType == DamageType.Physical then
            local mitigated = amount * 0.80
            entity.shieldDurability = math.min(maxShield, entity.shieldDurability + mitigated)
        end

        -- Blink trigger: if shield burst damage exceeds 15% of max shield in 1 second
        if EclipseAbilities.burstDamageTracker > (maxShield * 0.15) then
            EclipseAbilities.triggerBlink()
            EclipseAbilities.burstDamageTracker = 0
        end
    end

    -- Track elemental decay
    if not EclipseAbilities.lastElementalTime then EclipseAbilities.lastElementalTime = {} end
    if not EclipseAbilities.lastElementalTime[damageType] then EclipseAbilities.lastElementalTime[damageType] = 0 end
    
    if now - EclipseAbilities.lastElementalTime[damageType] > 3.0 then
        -- Decay memory if not hit by this element in 3 seconds
        EclipseAbilities.elementalTrackerShield[damageType] = 0
    end
    EclipseAbilities.lastElementalTime[damageType] = now

    -- Adaptive resistance logic for shields
    if EclipseAbilities.isAdaptive then
        if now > EclipseAbilities.resistanceEndTime then
            EclipseAbilities.activeResistance = nil -- Resistance window expired
        end

        if damageType and damageTypes[damageType] then
            EclipseAbilities.elementalTrackerShield[damageType] = (EclipseAbilities.elementalTrackerShield[damageType] or 0) + amount
            -- Trigger adaptation if a single element exceeds 5% of max shield total
            if maxShield > 0 and EclipseAbilities.elementalTrackerShield[damageType] > (maxShield * 0.05) then
                if EclipseAbilities.activeResistance ~= damageType then
                    EclipseAbilities.activeResistance = damageType
                    EclipseAbilities.resistanceEndTime = now + 15.0
                    Sector():broadcastChatMessage(entity.title, 2, "ADAPTIVE SHIELDS ENGAGED: RESISTING " .. string.upper(damageTypes[damageType]))
                    EclipseAbilities.elementalTrackerShield = {} -- Reset tracker after adapting
                end
            end
        end

        -- While adapted to an element, heal back 50% of that element's damage to shields
        if EclipseAbilities.activeResistance == damageType and damageType ~= DamageType.Physical then
            entity.shieldDurability = math.min(maxShield, entity.shieldDurability + (amount * 0.50))
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

    if now - EclipseAbilities.lastBlink < 45.0 then return end
    EclipseAbilities.lastBlink = now

    -- Void Rift VFX
    broadcastInvokeClientFunction("playVoidRiftVFX", entity, 0.5, 0.0, 1.0, 0.5)

    local random = random()
    local dir = normalize(vec3(random:getFloat() - 0.5, random:getFloat() - 0.5, random:getFloat() - 0.5))
    local dist = random:getInt(500, 1000) -- 5km to 10km

    entity.position = MatrixLookUpPosition(entity.look, entity.up, entity.translationf + dir * dist)

    -- Reappear VFX
    broadcastInvokeClientFunction("playVoidRiftVFX", entity, 0.5, 0.0, 1.0, 0.5)
end

-- Sector:createHyperspaceJumpAnimation is a CLIENT-ONLY function (see Sector [Client].html in the
-- API docs -- it is absent from the server-side Sector object despite appearing in the merged
-- Avorion Stubs/Sector.lua). onShieldDamaged/triggerBlink/triggerPhaseShift all run on the server,
-- so the VFX call must be relayed to clients via RPC instead of called directly.
function EclipseAbilities.playVoidRiftVFX(entity, r, g, b, intensity)
    if onClient() then
        Sector():createHyperspaceJumpAnimation(entity, entity.look, ColorRGB(r, g, b), intensity)
    end
end
callable(EclipseAbilities, "playVoidRiftVFX")

function EclipseAbilities.triggerPhaseShift()
    local entity = Entity()
    local now = Server().unpausedRuntime

    -- Mark as phased (hasPhased is a one-time flag — phase shift only triggers once per ship lifetime)
    EclipseAbilities.hasPhased = true
    EclipseAbilities.isPhasing = true
    -- Phase ends 4 seconds after trigger — updateServer will clear invincibility at phaseEndTime
    EclipseAbilities.phaseEndTime = now + 4.0

    entity.invincible = true
    broadcastInvokeClientFunction("playVoidRiftVFX", entity, 0.1, 0.1, 0.1, 1.0)
    
    -- Regenerate 25% of max shields when phasing
    local maxShield = entity.shieldMaxDurability or 0
    if maxShield > 0 then
        entity.shieldDurability = math.min(maxShield, entity.shieldDurability + (maxShield * 0.25))
    end

    -- Only register it here for non-Siphon ships so the phase expiry timer runs.
    -- Registering twice would cause the update to fire twice per tick.
    if not EclipseAbilities.isSiphon then
        entity:registerCallback("updateServer", "updateServer")
    end
end

-- hasPhased is a genuine once-per-ship-lifetime flag (see triggerPhaseShift) -- without persisting
-- it, an Ethereal (Phantom/Interceptor) ship that survives a sector unload/reload mid-fight would
-- forget it already used its one Phase Shift and could trigger it again. The other tracked fields
-- (lastBlink, isPhasing, burstDamageTracker, elementalTracker, etc.) are all short combat-window
-- timers measured in seconds -- safe to reset to their fresh-start defaults on reload, matching how
-- this codebase treats other purely transient per-tick trackers.
function EclipseAbilities.secure()
    return {
        hasPhased = EclipseAbilities.hasPhased
    }
end

function EclipseAbilities.restore(data)
    if data then
        EclipseAbilities.hasPhased = data.hasPhased or false
    end

    -- Ethereal Phase Shift (triggerPhaseShift, only ever set true for isEthereal ships) is a
    -- 4-second combat window that can never legitimately still be active by the time a sector
    -- reloads. isPhasing/phaseEndTime are intentionally NOT persisted above (always safe to reset),
    -- but entity.invincible IS a real, DB-persisted entity property -- if the sector happened to
    -- unload during that exact 4-second window, the entity would reload with invincible still true
    -- and no script-side isPhasing flag left to ever clear it again, leaving the ship permanently
    -- unkillable. Only touches Ethereal ships -- other classes (e.g. the World-Eater in
    -- ca_worldeater_behavior.lua) manage their own entity.invincible independently and must not be
    -- overridden here. initialize() always runs before restore(), so isEthereal is already set.
    if EclipseAbilities.isEthereal then
        local entity = Entity()
        if entity then entity.invincible = false end
    end
end

function EclipseAbilities.onDestroyed()
    local entity = Entity()
    local sector = Sector()
    local pos = entity.translationf

    -- Eclipse Remembers: credit every player physically present in the sector at the moment of
    -- death, mirroring the same "who's here right now" attribution ca_world_eater_manager.lua's
    -- cancelEvent() already uses for reward payouts -- avoids needing precise per-shot damage
    -- attribution just to answer "did this player help kill an Eclipse ship." Weighted by class:
    -- Siphon/Singularity-tier ships (Carriers, Juggernauts, Harbingers, World-Eaters -- the mod's
    -- own "bigger" designation, see initialize()'s isSiphon/isSingularity classification) are
    -- worth more toward a player's score than a rank-and-file hull.
    local scoreValue = (EclipseAbilities.isSiphon or EclipseAbilities.isSingularity) and 3 or 1
    for _, player in pairs({sector:getPlayers()}) do
        player:setValue("eclipse_kill_score", (player:getValue("eclipse_kill_score") or 0) + scoreValue)
    end

    -- 25% chance to drop 1-3 Ascendant Matter on death
    -- Use sector:dropLoot with a CargoLoot wrapper object instead.
    if random():getFloat() < 0.25 then
        sector:dropCargo(pos, nil, nil, goods["Ascendant Matter"], 0, random():getInt(1, 3))
    end

    -- Singularity ships trigger a 3-second delayed explosion on death
    if EclipseAbilities.isSingularity then
        sector:broadcastChatMessage("The Eclipse", 1, "WARNING: SINGULARITY CORE COLLAPSE IMMINENT.")
        -- Pass the position as 3 separate float args because the sector script stores them individually, plus the faction index
        sector:addScriptOnce("data/scripts/sector/ca_singularity_detonation.lua", pos.x, pos.y, pos.z, entity.factionIndex)
    end
end

