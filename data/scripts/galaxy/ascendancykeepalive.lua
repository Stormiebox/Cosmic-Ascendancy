package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

-- namespace AscendancyKeepAlive
AscendancyKeepAlive = {}

function AscendancyKeepAlive.initialize()
    if onServer() then
        -- Register to listen for Ascendancy Beacon pings from any sector
        Galaxy():registerCallback("onAscendancyBeaconPing", "onAscendancyBeaconPing")
    end
end

function AscendancyKeepAlive.onAscendancyBeaconPing(beaconId, factionIndex, x, y)
    if not x or not y then return end

    -- Force the engine to keep this sector simulated for 90 seconds.
    -- Since the beacon pings every 60 seconds, this guarantees the sector never unloads
    -- as long as the beacon has power and is active.
    Galaxy():keepOrGetSector(x, y, 90)
end


function initialize(...)
    if AscendancyKeepAlive.initialize then return AscendancyKeepAlive.initialize(...) end
end


-- Global Event Callbacks
function onAscendancyBeaconPing(...)
    if AscendancyKeepAlive.onAscendancyBeaconPing then return AscendancyKeepAlive.onAscendancyBeaconPing(...) end
end
