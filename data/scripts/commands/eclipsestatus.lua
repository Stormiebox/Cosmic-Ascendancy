package.path = package.path .. ";data/scripts/lib/?.lua"

local function formatDuration(seconds)
    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    return hours, mins
end

function execute(sender, commandName, ...)
    local server = Server()
    local player = Player(sender)
    if not player then return 0, "", "" end

    if not server:getValue("eclipse_fully_awake") then
        player:sendChatMessage("Server", 0, "The Eclipse has not yet awakened.")
        return 0, "", ""
    end

    local msg = "=== The Eclipse: Global Status ===\n\n"

    -- 1. Check Citadel Suppression Field
    local citadelDestroyed = server:getValue("eclipse_citadel_destroyed_time") or 0
    local conqueredCount = server:getValue("eclipse_conquered_sectors") or 0
    local suppressionDuration = (6 + math.floor(conqueredCount / 10) * 2) * 3600

    local timeSinceDestroyed = server.unpausedRuntime - citadelDestroyed

    if timeSinceDestroyed < suppressionDuration then
        local remaining = suppressionDuration - timeSinceDestroyed
        local hours, mins = formatDuration(remaining)
        msg = msg .. "[Citadel Suppression Field]: ACTIVE\n"
        msg = msg .. string.format("Eclipse invasions are halted for another %d hour(s) and %d minute(s).\n\n", hours, mins)
    else
        msg = msg .. "[Citadel Suppression Field]: INACTIVE\n"
        msg = msg .. "The Eclipse is currently free to launch invasions.\n\n"
    end

    -- 2. Check World-Eater Grace Period
    local graceEnd = server:getValue("eclipse_world_eater_grace_end") or 0
    if server.unpausedRuntime < graceEnd then
        local remaining = graceEnd - server.unpausedRuntime
        local hours, mins = formatDuration(remaining)
        msg = msg .. "[World-Eater Grace Period]: ACTIVE\n"
        msg = msg .. string.format("The Doomsday clock is paused for another %d hour(s) and %d minute(s).\n\n", hours, mins)
    else
        msg = msg .. "[World-Eater Grace Period]: INACTIVE\n"
        msg = msg .. "The Eclipse is actively constructing the next World-Eater.\n\n"
    end

    -- 3. Territory & Threat
    local threat = server:getValue("eclipse_threat") or 0
    local threatPct = math.floor(math.min(100, (threat / 10000) * 100))
    msg = msg .. "[Eclipse Holdings]: " .. conqueredCount .. " sector(s) conquered or annihilated.\n"
    msg = msg .. "[Expansion Threat]: " .. threatPct .. "% toward the next expansion attempt.\n\n"

    -- 4. Fallen Empire status
    if server:getValue("eclipse_fallen_empire") then
        msg = msg .. "[Fallen Empire]: ACTIVE\n"
        msg = msg .. "The Eclipse has consolidated into a unified empire and now launches deliberate Crusades.\n"

        local lastCrusade = server:getValue("eclipse_last_crusade_target")
        if lastCrusade then
            local hours, mins = formatDuration(server.unpausedRuntime - lastCrusade.time)
            local kindText = (lastCrusade.kind == "player") and "a player/alliance sector" or "an AI faction capital"
            msg = msg .. string.format("Last Crusade target: (%d:%d), %s, %d hour(s) and %d minute(s) ago.\n\n", lastCrusade.x, lastCrusade.y, kindText, hours, mins)
        else
            msg = msg .. "\n"
        end
    else
        msg = msg .. "[Fallen Empire]: INACTIVE (" .. conqueredCount .. "/75 sectors)\n\n"
    end

    -- 5. Nemesis Hunt
    local hunt = server:getValue("eclipse_nemesis_hunt")
    if hunt then
        msg = msg .. "[Nemesis Signature]: DETECTED\n"
        msg = msg .. string.format("A wounded Eclipse Dread-Lord was last tracked to sector (%d:%d).\n\n", hunt.x, hunt.y)
    else
        msg = msg .. "[Nemesis Signature]: NONE\n"
        msg = msg .. "No Eclipse Dread-Lord is currently known to be fleeing at reduced strength.\n\n"
    end

    -- 6. Remnant Escalation
    local EclipseGenerator = include("eclipsegenerator")
    local remnantTier = EclipseGenerator.getRemnantTier()
    local worldEatersKilled = server:getValue("eclipse_world_eaters_killed") or 0
    local citadelsKilled = server:getValue("eclipse_citadels_killed") or 0
    if remnantTier > 0 then
        msg = msg .. "[Remnant Escalation]: TIER " .. remnantTier .. "\n"
        msg = msg .. "Surviving Eclipse World-Eaters and Citadels are measurably stronger and more frequent as a result.\n"
    else
        msg = msg .. "[Remnant Escalation]: TIER 0\n"
    end
    msg = msg .. string.format("Confirmed kills: %d World-Eater(s), %d Citadel(s).\n", worldEatersKilled, citadelsKilled)

    player:sendChatMessage("Server", 0, msg)
    return 0, "", ""
end

function getDescription()
    return "Checks the current status of The Eclipse, including territory, threat, Fallen Empire crusades, any tracked Nemesis, and Remnant Escalation."
end

function getHelp()
    return "Usage: /eclipsestatus\nDisplays the Eclipse's current holdings, expansion threat, Citadel Suppression Field and World-Eater Grace Period cooldowns, Fallen Empire Crusade status, any currently tracked wounded Nemesis, and the current Remnant Escalation Tier."
end
