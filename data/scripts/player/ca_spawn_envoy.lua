package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local timer = 0
local CONTROLLER = "data/scripts/player/background/ca_campaign_controller.lua"

function getUpdateInterval()
    return 1.0
end

function updateServer(timeStep)
    timer = timer + timeStep
    if timer >= 10 then
        local player = Player()
        player:addScriptOnce(CONTROLLER)
        if player:hasScript(CONTROLLER) then
            local resultCode, started, err = player:invokeFunction(CONTROLLER, "beginEligibleCampaign")
            if resultCode == 0 and (started or err == "not_eligible") then
                terminate()
                return
            end
        end

        if player:hasScript(CONTROLLER) then
            -- The controller owns retry timing once it has attached successfully.
            terminate()
        else
            timer = 0
        end
    end
end

function secure()
    return {timer = timer}
end

function restore(data)
    if data then
        timer = data.timer or 0
    end
end
