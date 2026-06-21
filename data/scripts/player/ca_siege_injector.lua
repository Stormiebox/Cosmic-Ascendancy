package.path = package.path .. ";data/scripts/lib/?.lua"

function initialize()
    if onServer() then
        local sector = Sector()
        if sector then
            if not sector:hasScript("events/siegeevent.lua") then
                sector:addScript("data/scripts/events/siegeevent.lua")
                sector:invokeFunction("events/siegeevent.lua", "initialize")
            end
        end
        terminate()
    end
end
