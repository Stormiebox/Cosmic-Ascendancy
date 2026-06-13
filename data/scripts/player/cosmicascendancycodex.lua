package.path = package.path .. ";data/scripts/lib/?.lua"

include("utility")

function initialize()
    if onClient() then
        Player():registerCallback("onCosmicCodexGatherData", "onCosmicCodexGatherData")
    end
end

function onCosmicCodexGatherData()
    include("codex/infoCa")
    infoCa_injectToCodex()
end
