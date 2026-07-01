package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

-- namespace AscendancyKeepAlive
AscendancyKeepAlive = {}
local data = {}
data.activeBeacons = {}

function AscendancyKeepAlive.initialize()
    if onServer() then
        -- Register to listen for Ascendancy Beacon pings from any sector
        Galaxy():registerCallback("onAscendancyBeaconPing", "onAscendancyBeaconPing")
        Galaxy():registerCallback("onAscendancyBeaconActivated", "onAscendancyBeaconActivated")
        Galaxy():registerCallback("onAscendancyBeaconDeactivated", "onAscendancyBeaconDeactivated")
        
        -- On server restart, force load all active beacons so their scripts wake up
        for coords, _ in pairs(data.activeBeacons) do
            local parts = {coords:match("([^:]+):([^:]+)")}
            if #parts == 2 then
                local cx = tonumber(parts[1])
                local cy = tonumber(parts[2])
                if cx and cy then
                    Galaxy():keepOrGetSector(cx, cy, 90)
                end
            end
        end
    end
end

function AscendancyKeepAlive.onAscendancyBeaconPing(beaconId, factionIndex, x, y)
    if not x or not y then return end

    local coords = tostring(x) .. ":" .. tostring(y)
    if not data.activeBeacons[coords] then
        data.activeBeacons[coords] = true
    end

    -- Force the engine to keep this sector simulated for 90 seconds.
    -- Since the beacon pings every 60 seconds, this guarantees the sector never unloads
    -- as long as the beacon has power and is active.
    Galaxy():keepOrGetSector(x, y, 90)
end

function AscendancyKeepAlive.onAscendancyBeaconActivated(x, y)
    if not x or not y then return end
    local coords = tostring(x) .. ":" .. tostring(y)
    data.activeBeacons[coords] = true
end

function AscendancyKeepAlive.onAscendancyBeaconDeactivated(x, y)
    if not x or not y then return end
    local coords = tostring(x) .. ":" .. tostring(y)
    data.activeBeacons[coords] = nil
end

function AscendancyKeepAlive.secure()
    return data
end

function AscendancyKeepAlive.restore(data_in)
    data = data_in or {}
    data.activeBeacons = data.activeBeacons or {}
end


function initialize(...)
    if AscendancyKeepAlive.initialize then return AscendancyKeepAlive.initialize(...) end
end


-- Global Event Callbacks
function onAscendancyBeaconPing(...)
    if AscendancyKeepAlive.onAscendancyBeaconPing then return AscendancyKeepAlive.onAscendancyBeaconPing(...) end
end
function onAscendancyBeaconActivated(...)
    if AscendancyKeepAlive.onAscendancyBeaconActivated then return AscendancyKeepAlive.onAscendancyBeaconActivated(...) end
end
function onAscendancyBeaconDeactivated(...)
    if AscendancyKeepAlive.onAscendancyBeaconDeactivated then return AscendancyKeepAlive.onAscendancyBeaconDeactivated(...) end
end
function secure(...)
    if AscendancyKeepAlive.secure then return AscendancyKeepAlive.secure(...) end
end
function restore(...)
    if AscendancyKeepAlive.restore then return AscendancyKeepAlive.restore(...) end
end

return AscendancyKeepAlive
