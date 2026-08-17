package.path = package.path .. ";data/scripts/lib/?.lua"

local cv_news = include("cosmicvaultnews")
local cv_fleet = include("cosmicvaultfleet")
local cv_anomalies = include("cosmicvaultanomalies")

-- namespace EclipseBossBehavior
include("stringutility")
EclipseBossBehavior = {}
local self = EclipseBossBehavior

function EclipseBossBehavior.initialize()
    -- Register the boss to the UI once when the script first loads on the client.
    if onClient() then
        registerBoss(Entity().index)
    end

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
    -- registerBoss() has been moved to initialize() — no longer needed here.
    -- Keeping the function registered to avoid a nil callback error if another system references it.
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
            Sector():broadcastChatMessage(Entity().name, 2, "PATHETIC. THE INEVITABLE CANNOT BE STOPPED. INITIATING OMEGA PURGE."%_t)
        end
    end
end

function EclipseBossBehavior.onDestroyed(index, lastDamageInflictor)
    local sector = Sector()
    local x, y = sector:getCoordinates()

    Server():broadcastChatMessage("System"%_T, 0, "The World Eater has been destroyed in sector \\s(%1%:%2%)!"%_T, x, y)
    Server():setValue("eclipse_annihilator_dead", true)

    if cv_news.publishArticle then
        cv_news.publishArticle({
            title = "World Eater Neutralized!",
            content = "In an impossible feat of galactic coordination, the Eclipse superweapon known as The World Eater has been destroyed in sector [" .. x .. ":" .. y .. "]. Trillions of lives have been saved.",
            category = "Galactic War"
        })
    end

    local players = {sector:getPlayers()}
    for _, player in pairs(players) do
        player.money = player.money + 5000000000
        player:sendChatMessage("System", 0, "Received 5,000,000,000 Credits bounty.")
        player:sendChatMessage("Recovered Datapad", 0, "'The World Eater operates at peak efficiency. The galaxy will be purged, just as the architect intended. Project Stormbox is a complete success.'")
    end

    -- Synergy: Post-Boss Anomaly Generation
    if cv_anomalies and cv_anomalies.spawnAnomaly then
        cv_anomalies.spawnAnomaly(x, y, "PrecursorWreck", Entity().translationf)
    end
end

