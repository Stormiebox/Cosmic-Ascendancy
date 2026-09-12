local COORDINATOR = "data/scripts/galaxy/ca_state_coordinator.lua"

local function reply(player, message)
    player:sendChatMessage("Ascendancy Repair", 0, message)
end

local function invoke(functionName, ...)
    local resultCode, result, err = Galaxy():invokeFunction(COORDINATOR, functionName, ...)
    if resultCode ~= 0 then return nil, "coordinator_unavailable" end
    return result, err
end

function execute(sender, commandName, ...)
    local player = Player(sender)
    if not player then return 0, "", "" end
    if not Server():hasAdminPrivileges(player) then
        reply(player, "Administrator privileges are required.")
        return 0, "", ""
    end

    local args = {...}
    local action = string.lower(tostring(args[1] or "status"))
    if action == "scan" then
        local scope = string.lower(tostring(args[2] or "all"))
        local playerIndex
        if scope == "player" then
            playerIndex = tonumber(args[3])
            if not playerIndex then
                reply(player, "Usage: /ascendancyrepair scan player <index>")
                return 0, "", ""
            end
        end
        local allowed = {all = true, galaxy = true, player = true, encounters = true,
            queues = true, beacons = true, forges = true}
        if not allowed[scope] then
            reply(player, "Unknown scan scope: " .. scope)
            return 0, "", ""
        end

        local repair, err = invoke("scanRepair", scope, playerIndex)
        if not repair then reply(player, "Scan failed: " .. tostring(err)); return 0, "", "" end
        reply(player, string.format("Dry-run scan %s found %d item(s). No state was changed.",
            repair.repairId, #(repair.findings or {})))
        for _, finding in ipairs(repair.findings or {}) do
            local permitted = table.concat(finding.permittedActions or {}, ", ")
            reply(player, string.format("%s%s: %s | actions: %s", finding.kind,
                finding.itemId and (" [" .. finding.itemId .. "]") or "",
                tostring(finding.evidence), permitted ~= "" and permitted or "none"))
        end
    elseif action == "status" then
        local repair, err = invoke("getRepairStatus", args[2])
        if not repair then reply(player, "Status failed: " .. tostring(err)); return 0, "", "" end
        reply(player, string.format("%s is %s with %d finding(s).",
            repair.repairId, repair.state, #(repair.findings or {})))
    elseif action == "history" then
        local history, err = invoke("getRepairHistory", args[2])
        if not history then reply(player, "History failed: " .. tostring(err)); return 0, "", "" end
        for _, entry in ipairs(history) do
            reply(player, string.format("%s: %s (%s)", tostring(entry.at),
                tostring(entry.action), tostring(entry.result)))
        end
    elseif action == "apply" then
        local repairId = args[2]
        local selectedAction = args[3]
        if not repairId or not selectedAction then
            reply(player, "Usage: /ascendancyrepair apply <repairId> <resume|retry|mark-complete|reissue|abandon>")
            return 0, "", ""
        end
        local repair, err = invoke("applyRepair", repairId, selectedAction, sender)
        if not repair then reply(player, "Apply failed: " .. tostring(err)); return 0, "", "" end
        reply(player, string.format("%s applied to %s: %s",
            selectedAction, repairId, tostring(repair.result)))
    else
        reply(player, "Usage: /ascendancyrepair <scan|status|apply|history> ...")
    end

    return 0, "", ""
end

function getDescription()
    return "Scans and repairs Cosmic Ascendancy's versioned persistent state. Administrator only."
end

function getHelp()
    return "/ascendancyrepair scan [all|galaxy|player <index>|encounters|queues|beacons|forges]\n"
        .. "/ascendancyrepair status [repairId]\n"
        .. "/ascendancyrepair apply <repairId> <resume|retry|mark-complete|reissue|abandon>\n"
        .. "/ascendancyrepair history [repairId]"
end
