package.path = package.path .. ";data/scripts/lib/?.lua"

local cv_news = include("cosmicvaultnews")
local cv_fleet = include("cosmicvaultfleet")
local cv_anomalies = include("cosmicvaultanomalies")

-- namespace EclipseBossBehavior
EclipseBossBehavior = {}
local self = EclipseBossBehavior

function EclipseBossBehavior.initialize()
    if onServer() then
        Entity():registerCallback("onDestroyed", "onDestroyed")
        Entity():registerCallback("onDamaged", "onDamaged")

        if cv_fleet.orderAttackEnemies then
            cv_fleet.orderAttackEnemies(Entity().index, true)
        end
    end
end

function EclipseBossBehavior.getUpdateInterval()
    return 10
end

function EclipseBossBehavior.updateClient()
    registerBoss(Entity().index)
end

function EclipseBossBehavior.updateServer()
    local entity = Entity()
    if cv_fleet.orderAttackEnemies then
        cv_fleet.orderAttackEnemies(entity.index, true)
    end
end

local triggeredWarning = false
function EclipseBossBehavior.onDamaged(objectIndex, amount, inflictor)
    if not triggeredWarning then
        local ratio = Entity().durability / Entity().maxDurability
        if ratio < 0.5 then
            triggeredWarning = true
            Sector():broadcastChatMessage(Entity().name, 2, "PATHETIC. THE OBLIVION ENGINE CANNOT BE STOPPED. INITIATING OMEGA PURGE."%_t)
        end
    end
end

function EclipseBossBehavior.onDestroyed(index, lastDamageInflictor)
    local sector = Sector()
    local x, y = sector:getCoordinates()

    Server():broadcastChatMessage("System"%_T, 0, "The Eclipse Oblivion Engine has been destroyed in sector \\s(%1%:%2%)!"%_T, x, y)
    Server():setValue("eclipse_annihilator_dead", true)

    if cv_news.publishArticle then
        cv_news.publishArticle({
            title = "Oblivion Engine Neutralized!",
            content = "In an impossible feat of galactic coordination, the Eclipse superweapon known as The Eclipse Oblivion Engine has been destroyed in sector [" .. x .. ":" .. y .. "]. Trillions of lives have been saved.",
            category = "Galactic War"
        })
    end

    local players = {sector:getPlayers()}
    for _, player in pairs(players) do
        player:receive("Eclipse Oblivion Bounty", 5000000000)
        player:sendChatMessage("Recovered Datapad", 0, "'The Oblivion Engine operates at peak efficiency. The galaxy will be purged, just as the architect intended. Project Stormbox is a complete success.'")
    end

    -- Synergy: Post-Boss Anomaly Generation
    if cv_anomalies and cv_anomalies.spawnAnomaly then
        cv_anomalies.spawnAnomaly(x, y, "PrecursorWreck", Entity().translationf)
    end
end

function initialize(...)
    if EclipseBossBehavior.initialize then return EclipseBossBehavior.initialize(...) end
end
function getUpdateInterval(...)
    if EclipseBossBehavior.getUpdateInterval then return EclipseBossBehavior.getUpdateInterval(...) end
end
function updateClient(...)
    if EclipseBossBehavior.updateClient then return EclipseBossBehavior.updateClient(...) end
end
function updateServer(...)
    if EclipseBossBehavior.updateServer then return EclipseBossBehavior.updateServer(...) end
end

-- Global Event Callbacks
function onDestroyed(...)
    if EclipseBossBehavior.onDestroyed then return EclipseBossBehavior.onDestroyed(...) end
end
function onDamaged(...)
    if EclipseBossBehavior.onDamaged then return EclipseBossBehavior.onDamaged(...) end
end

return EclipseBossBehavior
