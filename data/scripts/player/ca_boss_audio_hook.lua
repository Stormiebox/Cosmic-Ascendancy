package.path = package.path .. ";data/scripts/lib/?.lua"
include("callable")

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
        musicPath = "data/music/world_eater_phase1.ogg"
    elseif phase == 2 then
        musicPath = "data/music/world_eater_enraged.ogg"
    end

    if musicPath ~= "" then
        Music():fadeOut(1.0)
        Music():playTrack(musicPath, true, 1.0)
    end
    print("Cosmic Ascendancy Hook: Playing boss music " .. musicPath)
end

function CaBossAudioHook.stopBossMusic()
    if onServer() then return end
    CaBossAudioHook.bossPhase = 0
    Music():fadeOut(3.0)
    print("Cosmic Ascendancy Hook: Stopping boss music.")
end

function CaBossAudioHook.playGuardianFellMusic()
    if onServer() then return end
    -- Immediately kill the vanilla combat/background music so it doesn't overlap
    Music():stop()
    -- Start the Forge The Ascendant OST
    Music():playTrack("data/music/special/forge_the_ascendant.ogg", false, 1.0)
    print("Cosmic Ascendancy Hook: Playing Forge The Ascendant OST.")
end



-- Server-to-Client Bridge Functions
function CaBossAudioHook.triggerGuardianFellMusic()
    if onClient() then return end
    invokeClientFunction(Player(), "playGuardianFellMusic")
end

function CaBossAudioHook.triggerCinematicBanner(text, soundPath)
    if onClient() then return end
    invokeClientFunction(Player(), "showCinematicBanner", text, soundPath)
end

function CaBossAudioHook.triggerBossMusic(phase)
    if onClient() then return end
    invokeClientFunction(Player(), "playBossMusic", phase)
end

function CaBossAudioHook.triggerStopBossMusic()
    if onClient() then return end
    invokeClientFunction(Player(), "stopBossMusic")
end
callable(CaBossAudioHook, "showCinematicBanner")
callable(CaBossAudioHook, "playBossMusic")
callable(CaBossAudioHook, "stopBossMusic")
callable(CaBossAudioHook, "playGuardianFellMusic")

callable(CaBossAudioHook, "triggerGuardianFellMusic")
callable(CaBossAudioHook, "triggerCinematicBanner")
callable(CaBossAudioHook, "triggerBossMusic")
callable(CaBossAudioHook, "triggerStopBossMusic")

return CaBossAudioHook
