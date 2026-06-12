package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

-- namespace AscendancyKeepAlive
AscendancyKeepAlive = {}
local activeBeacons = {} -- [x_y] = {x = x, y = y}
local timer = 0

function AscendancyKeepAlive.initialize()
    if onServer() then
        -- Register callbacks so beacons can tell the galaxy to start keeping their sector alive
        Galaxy():registerCallback("onAscendancyBeaconActivated", "onAscendancyBeaconActivated")
        Galaxy():registerCallback("onAscendancyBeaconDeactivated", "onAscendancyBeaconDeactivated")
    end
end

function AscendancyKeepAlive.onAscendancyBeaconActivated(x, y)
    local key = tostring(x) .. "_" .. tostring(y)
    activeBeacons[key] = {x = x, y = y}
end

function AscendancyKeepAlive.onAscendancyBeaconDeactivated(x, y)
    local key = tostring(x) .. "_" .. tostring(y)
    activeBeacons[key] = nil
end

function AscendancyKeepAlive.update(timeStep)
    if not onServer() then return end
    
    timer = timer + timeStep
    if timer < 60 then return end
    timer = 0
    
    -- Every 60 seconds, keep all registered beacon sectors alive for 90 seconds
    for key, coords in pairs(activeBeacons) do
        Galaxy():keepOrGetSector(coords.x, coords.y, 90)
    end
end

function AscendancyKeepAlive.secure()
    return {
        timer = timer,
        activeBeacons = activeBeacons
    }
end

function AscendancyKeepAlive.restore(data)
    timer = data.timer or 0
    activeBeacons = data.activeBeacons or {}
end
