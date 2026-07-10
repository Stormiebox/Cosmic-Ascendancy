package.path = package.path .. ";data/scripts/lib/?.lua"

local CaBossAudioHook = {}
CaBossAudioHook.bossPhase = 0

function CaBossAudioHook.initialize()
    if onServer() then return end
end

-- Invoked by the server to show the Cinematic UI Banner for Doomsday
function CaBossAudioHook.showCinematicBanner(text, soundPath)
    if onServer() then return end
    local CosmicVaultUI = include("cosmicvaultui")
    if CosmicVaultUI and CosmicVaultUI.ShowCinematicBanner then
        CosmicVaultUI.ShowCinematicBanner(Player(), text, ColorRGB(1, 0, 0), soundPath or "data/sounds/siren.ogg", 5)
    end
end

-- Invoked when entering the sector or when phase changes
function CaBossAudioHook.playBossMusic(phase)
    if onServer() then return end
    CaBossAudioHook.bossPhase = phase

    local musicPath = ""
    if phase == 1 then
        musicPath = "data/sounds/music/world_eater_phase1.ogg"
    elseif phase == 2 then
        musicPath = "data/sounds/music/world_eater_enraged.ogg"
    end
    
    -- In a real implementation, you would use Avorion's Sound() API or Music() API.
    -- Placeholder for the Boss Audio hook:
    -- Music():play(musicPath)
    print("Cosmic Ascendancy Hook: Playing boss music " .. musicPath)
end

function CaBossAudioHook.stopBossMusic()
    if onServer() then return end
    CaBossAudioHook.bossPhase = 0
    print("Cosmic Ascendancy Hook: Stopping boss music.")
end

callable(CaBossAudioHook, "showCinematicBanner")
callable(CaBossAudioHook, "playBossMusic")
callable(CaBossAudioHook, "stopBossMusic")

function initialize(...)
    if CaBossAudioHook.initialize then return CaBossAudioHook.initialize(...) end
end

return CaBossAudioHook
