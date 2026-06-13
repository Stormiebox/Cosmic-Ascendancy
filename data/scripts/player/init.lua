
if onServer() then
    local oldInit = initialize or function() end
    function initialize()
        oldInit()
        Player():addScriptOnce("data/scripts/player/cosmicascendancycodex.lua")
    end
end
