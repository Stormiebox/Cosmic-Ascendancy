package.path = package.path .. ";data/scripts/lib/?.lua"
include ("galaxy")
include ("utility")
include ("stringutility")
include ("faction")

local CitadelBlocker = {}
CitadelBlocker.pulseTimer = 0
CitadelBlocker.isBlocking = true

function CitadelBlocker.getUpdateInterval()
    return 2.0
end

function CitadelBlocker.updateServer(timeStep)
    CitadelBlocker.pulseTimer = CitadelBlocker.pulseTimer + timeStep

    -- Pacing: 60 seconds blocking, 30 seconds window to escape
    if CitadelBlocker.isBlocking then
        if CitadelBlocker.pulseTimer >= 60.0 then
            CitadelBlocker.isBlocking = false
            CitadelBlocker.pulseTimer = 0.0
            Sector():broadcastChatMessage(Entity().title, 0, "LOCKDOWN MATRIX RECHARGING. HYPERSPACE WINDOW OPEN.")
        else
            -- Block all hyperspace engines in 25 km range
            local position = Entity().translationf
            local threshold = 2500 -- 25 km
            threshold = threshold * threshold

            local entities = {Sector():getEntitiesByComponent(ComponentType.HyperspaceEngine)}

            for _, entity in pairs(entities) do
                local d = distance2(position, entity.translationf)
                if d <= threshold then
                    entity:blockHyperspace(2.5)
                end
            end
        end
    else
        if CitadelBlocker.pulseTimer >= 30.0 then
            CitadelBlocker.isBlocking = true
            CitadelBlocker.pulseTimer = 0.0
            Sector():broadcastChatMessage(Entity().title, 2, "LOCKDOWN MATRIX ENGAGED. HYPERSPACE BLOCKED.")
        end
    end
end

function CitadelBlocker.secure()
    return {
        pulseTimer = CitadelBlocker.pulseTimer,
        isBlocking = CitadelBlocker.isBlocking
    }
end

function CitadelBlocker.restore(data)
    data = data or {}
    CitadelBlocker.pulseTimer = data.pulseTimer or 0
    CitadelBlocker.isBlocking = data.isBlocking or false
end

function getUpdateInterval(...) return CitadelBlocker.getUpdateInterval(...) end
function updateServer(...) return CitadelBlocker.updateServer(...) end
function secure(...) return CitadelBlocker.secure(...) end
function restore(...) return CitadelBlocker.restore(...) end
