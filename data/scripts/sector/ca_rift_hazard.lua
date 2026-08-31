package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("randomext")

function initialize()
    if onServer() then
        Sector():registerCallback("onPlayerEntered", "onPlayerEntered")
    end
end

function onPlayerEntered(playerIndex)
    local player = Player(playerIndex)
    if not player then return end

    local craft = player.craft
    local eclipseFaction = Galaxy():findFaction("The Eclipse")
    local eclipseIndex = eclipseFaction and eclipseFaction.index or -1

    -- Only warn if the player's craft is vulnerable to the anomaly
    if not craft or craft.factionIndex ~= eclipseIndex then
        player:sendChatMessage("Rift Hazard", 2, "WARNING: Navigational hazard detected! Shields are actively draining.")
    end
end

function getUpdateInterval()
    return 2.0
end

local soundTimer = 0
local soundInterval = 5

function updateClient(timeStep)
    soundTimer = soundTimer + timeStep
    if soundTimer > soundInterval then
        local craft = Player().craft
        if craft then
            local position = craft.translationf + random():getDirection() * 10000
            local sounds = {"distant-thunder1", "distant-thunder2", "distant-thunder3", "distant-thunder4"}
            play3DSound(randomEntry(sounds), SoundType.Other, position, 200000, 1)
        end
        soundInterval = random():getFloat(5, 15)
        soundTimer = 0
    end
end

function updateServer(timeStep)
    -- Drain shields by 5% every 2 seconds for non-Eclipse ships
    local sector = Sector()
    local eclipseFaction = Galaxy():findFaction("The Eclipse")
    local eclipseIndex = eclipseFaction and eclipseFaction.index or -1

    local entities = {sector:getEntitiesByType(EntityType.Ship)}
    for _, entity in pairs(entities) do
        if valid(entity) and entity.factionIndex ~= eclipseIndex then
            local maxShield = entity.shieldMaxDurability or 0
            if maxShield > 0 then
                local drain = maxShield * 0.05
                -- Properly use inflictDamage for environmental drain (DamageSource 1 = environmental/unknown)
                -- Entity:inflictDamage(amount, damageSource, damageType, index, location, inflictorId) — the
                -- index arg (0 = whole-entity, not a specific block) was missing, which shifted translationf
                -- into the index slot and dropped the entity id out of the call entirely.
                entity:inflictDamage(drain, 1, DamageType.Energy, 0, entity.translationf, entity.id)
            end
        end
    end
end
