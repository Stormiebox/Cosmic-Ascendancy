
package.path = package.path .. ";data/scripts/lib/?.lua"

if onServer() then
    local oldInit = initialize or function() end
    function initialize()
        oldInit()
        Galaxy():addScriptOnce("data/scripts/galaxy/ca_state_coordinator.lua")
    end
end



