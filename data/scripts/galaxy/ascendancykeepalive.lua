package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

-- namespace AscendancyKeepAlive
AscendancyKeepAlive = {}

local OWNER = "data/scripts/galaxy/ascendancykeepalive.lua"
local COORDINATOR = "data/scripts/galaxy/ca_state_coordinator.lua"
local BEACON_SCRIPT = "data/scripts/entity/ascendancybeacon.lua"
local LEASE_SECONDS = 90
local RECONCILIATION_BATCH = 2
local MAX_LOAD_ATTEMPTS = 5

local data = {
    schemaVersion = 2,
    leases = {},
    reconciliationQueue = {},
    metrics = {
        renewals = 0,
        reconciliationFailures = 0,
        reconciliationDuration = 0,
        renewalCost = 0
    },
    nextMetricsAt = 0
}

local function now()
    return Server().unpausedRuntime
end

local function coordinator(functionName, ...)
    local resultCode, first, second = Galaxy():invokeFunction(COORDINATOR, functionName, ...)
    if resultCode ~= 0 then return nil, "coordinator_unavailable" end
    return first, second
end

local function canonicalClaim(beaconId)
    local snapshot = coordinator("getCanonicalSnapshot")
    local claim = snapshot and snapshot.beacons and snapshot.beacons.claims[beaconId]
    if not claim or claim.state ~= "active" then return nil end
    return claim
end

local function renew(claim)
    local startedAt = now()
    Galaxy():keepOrGetSector(claim.x, claim.y, LEASE_SECONDS)
    local finishedAt = now()
    data.leases[claim.beaconId] = {
        beaconId = claim.beaconId,
        ownerFactionIndex = claim.ownerFactionIndex,
        x = claim.x,
        y = claim.y,
        renewedAt = finishedAt,
        expiresAt = finishedAt + LEASE_SECONDS
    }
    data.metrics.renewals = (data.metrics.renewals or 0) + 1
    data.metrics.renewalCost = (data.metrics.renewalCost or 0) + 1
    data.metrics.reconciliationDuration = (data.metrics.reconciliationDuration or 0)
        + math.max(0, finishedAt - startedAt)
end

local function publishMetrics()
    local activeLeases = 0
    for _ in pairs(data.leases) do activeLeases = activeLeases + 1 end
    coordinator("requestBeaconReconciliation", OWNER, nil, "metrics", {
        activeLeases = activeLeases,
        renewals = data.metrics.renewals,
        reconciliationFailures = data.metrics.reconciliationFailures,
        reconciliationDuration = data.metrics.reconciliationDuration,
        renewalCost = data.metrics.renewalCost
    })
end

local function queueCanonicalClaims()
    data.reconciliationQueue = {}
    local snapshot = coordinator("getCanonicalSnapshot")
    if not snapshot or not snapshot.beacons then return end
    for beaconId, claim in pairs(snapshot.beacons.claims) do
        if claim.state == "active" then
            table.insert(data.reconciliationQueue, {
                beaconId = beaconId,
                ownerFactionIndex = claim.ownerFactionIndex,
                x = claim.x,
                y = claim.y,
                attempts = 0
            })
        end
    end
end

function AscendancyKeepAlive.initialize()
    if not onServer() then return end
    Galaxy():registerCallback("onAscendancyBeaconPing", "onAscendancyBeaconPing")
    Galaxy():registerCallback("onAscendancyBeaconActivated", "onAscendancyBeaconActivated")
    Galaxy():registerCallback("onAscendancyBeaconDeactivated", "onAscendancyBeaconDeactivated")
    queueCanonicalClaims()
end

function AscendancyKeepAlive.onAscendancyBeaconPing(beaconId, factionIndex, x, y, revision)
    if type(beaconId) ~= "string" then return end
    local claim = canonicalClaim(beaconId)
    if not claim or claim.ownerFactionIndex ~= factionIndex or claim.x ~= x or claim.y ~= y then return end
    renew(claim)
end

function AscendancyKeepAlive.onAscendancyBeaconActivated(beaconId, factionIndex, x, y)
    if type(beaconId) ~= "string" then return end
    local claim = canonicalClaim(beaconId)
    if claim and claim.ownerFactionIndex == factionIndex and claim.x == x and claim.y == y then
        renew(claim)
    end
end

function AscendancyKeepAlive.onAscendancyBeaconDeactivated(beaconId, x, y)
    if type(beaconId) ~= "string" then return end
    data.leases[beaconId] = nil
end

function AscendancyKeepAlive.reportReconciliation(beaconId, verified, entityId)
    local pending
    for index, item in ipairs(data.reconciliationQueue) do
        if item.beaconId == beaconId then
            pending = item
            table.remove(data.reconciliationQueue, index)
            break
        end
    end
    if not pending then return end
    if verified and entityId == beaconId then
        local claim = canonicalClaim(beaconId)
        if claim then renew(claim) end
        return
    end
    data.leases[beaconId] = nil
    data.metrics.reconciliationFailures = (data.metrics.reconciliationFailures or 0) + 1
    coordinator("requestBeaconReconciliation", OWNER, beaconId, "remove_stale", {
        reason = "beacon_entity_not_verified"
    })
end

local function inspectClaim(item)
    item.attempts = (item.attempts or 0) + 1
    local loaded = Galaxy():keepOrGetSector(item.x, item.y, LEASE_SECONDS)
    data.metrics.renewalCost = (data.metrics.renewalCost or 0) + 1
    if not loaded then
        if item.attempts >= MAX_LOAD_ATTEMPTS then
            AscendancyKeepAlive.reportReconciliation(item.beaconId, false)
        end
        return
    end
    local code = [[
        function run(beaconId, ownerFactionIndex, beaconScript)
            local verified = false
            local entityId = nil
            for _, entity in pairs({Sector():getEntitiesByScript(beaconScript)}) do
                if entity.id.string == beaconId and entity.factionIndex == ownerFactionIndex then
                    local result, leaseActive = entity:invokeFunction(beaconScript, "getLeaseState")
                    if result == 0 and leaseActive == true then
                        verified = true
                        entityId = entity.id.string
                        break
                    end
                end
            end
            Galaxy():invokeFunction("data/scripts/galaxy/ascendancykeepalive.lua",
                "reportReconciliation", beaconId, verified, entityId)
        end
    ]]
    local result = runSectorCode(item.x, item.y, true, code, "run",
        item.beaconId, item.ownerFactionIndex, BEACON_SCRIPT)
    if result == 1 and item.attempts >= MAX_LOAD_ATTEMPTS then
        AscendancyKeepAlive.reportReconciliation(item.beaconId, false)
    end
end

function AscendancyKeepAlive.getUpdateInterval()
    return 10
end

function AscendancyKeepAlive.updateServer(timeStep)
    local current = now()
    for beaconId, lease in pairs(data.leases) do
        if current >= (lease.expiresAt or 0) then data.leases[beaconId] = nil end
    end
    for _ = 1, RECONCILIATION_BATCH do
        local item = table.remove(data.reconciliationQueue, 1)
        if not item then break end
        table.insert(data.reconciliationQueue, item)
        inspectClaim(item)
    end
    if current >= (data.nextMetricsAt or 0) then
        publishMetrics()
        data.nextMetricsAt = current + 60
    end
end

function AscendancyKeepAlive.secure()
    return data
end

function AscendancyKeepAlive.restore(restored)
    if restored and restored.schemaVersion == 2 then
        data = restored
        data.leases = data.leases or {}
        data.metrics = data.metrics or {}
    else
        data = {
            schemaVersion = 2,
            leases = {},
            reconciliationQueue = {},
            metrics = {renewals = 0, reconciliationFailures = 0,
                reconciliationDuration = 0, renewalCost = 0},
            nextMetricsAt = 0,
            migration = {source = restored and "legacy_keepalive" or "new", migratedAt = now()}
        }
    end
    queueCanonicalClaims()
end
