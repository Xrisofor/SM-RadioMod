dofile("$CONTENT_40639a2c-bb9f-4d4f-b88c-41bfe264ffa8/Scripts/ModDatabase.lua")

Utilities = class()

MAIN_LAYOUT = "$CONTENT_DATA/Gui/Layouts/Scrapify.layout"
TRACK_ITEM_LAYOUT = "$CONTENT_DATA/Gui/Layouts/TrackItem.layout"

PLAY_ICON = "$CONTENT_DATA/Gui/Layouts/play-circle.png"
STOP_ICON = "$CONTENT_DATA/Gui/Layouts/stop-circle.png"

VOLUME_ON_ICON = "$CONTENT_DATA/Gui/Layouts/volume-up.png"
VOLUME_OFF_ICON = "$CONTENT_DATA/Gui/Layouts/volume-off.png"

REPEAT_NONE = 0
REPEAT_TRACK = 1
REPEAT_PLAYLIST = 2

function Utilities.checkCAE()
    if sm.cae_injected == nil then
        sm.gui.chatMessage("(Radio Mod) You have not installed " .. "#ff0000SM-CustomAudioExtension#ffffff, " .. "all music will not be played until you install the library!")
    end
end

function Utilities.loadCustomMusicTracks(customRadio)
    customRadio.trackInfo = {}
    customRadio.tracks = {}

    local function loadTracks(filePath)
        if not sm.json.fileExists(filePath) then
            print("File not found: " .. filePath)
            return
        end

        local success, data = pcall(sm.json.open, filePath)
        if not success or type(data) ~= "table" then
            print("Failed to open or invalid format: " .. filePath)
            return
        end

        local isEffectSet = false
        for k, _ in pairs(data) do
            if type(k) == "string" then
                isEffectSet = true
            end
            break
        end

        if isEffectSet then
            for name, effect in pairs(data) do
                if type(name) == "string" and name:gsub(":", "") == name then
                    table.insert(customRadio.tracks, name)
                    if effect.radioMod then
                        customRadio.trackInfo[name] = {
                            Name = effect.radioMod.Name or name,
                            Author = effect.radioMod.Author or "Unknown",
                            Image = effect.radioMod.Image or "Gui/Icons/default_image.png",
                            Duration = effect.radioMod.Duration or 0
                        }
                    end
                end
            end
        else
            for _, file in ipairs(data) do
                local fullPath = "$CONTENT_DATA/Effects/Database/EffectSets/" .. file
                if sm.json.fileExists(fullPath) then
                    local success2, effects = pcall(sm.json.open, fullPath)
                    if success2 and type(effects) == "table" then
                        for name, effect in pairs(effects) do
                            if type(name) == "string" and name:gsub(":", "") == name then
                                table.insert(customRadio.tracks, name)
                                if effect.radioMod then
                                    customRadio.trackInfo[name] = {
                                        Name = effect.radioMod.Name or name,
                                        Author = effect.radioMod.Author or "Unknown",
                                        Image = effect.radioMod.Image or "Gui/Icons/default_image.png",
                                        Duration = effect.radioMod.Duration or 0
                                    }
                                end
                            end
                        end
                    else
                        print("Failed to load effects from: " .. fullPath)
                    end
                else
                    print("File not found: " .. fullPath)
                end
            end
        end
    end

    loadTracks("$CONTENT_DATA/Effects/Database/EffectSets/game.effectset")
    loadTracks("$CONTENT_DATA/Effects/Database/EffectSets/events.effectset")
    loadTracks("$CONTENT_DATA/Effects/custom_effects.json")

    Utilities.initCustomTracks(customRadio)

    table.sort(customRadio.tracks)

    Utilities.loadPlaylists(customRadio)
end

function Utilities.initCustomTracks(customRadio)
    print("Load Custom Tracks")

    ModDatabase.loadShapesets()
    local loadedMods = ModDatabase.getAllLoadedMods()

    for _, localId in ipairs(loadedMods) do
        if localId ~= sm.uuid.new("e8d9c47d-8029-4441-b662-95ef4ccd55be") then
            local modPath = "$CONTENT_" .. localId
            local customEffectsPath = modPath .. "/Effects/custom_effects.json"

            sm.log.info(customEffectsPath)

            if sm.json.fileExists(customEffectsPath) then
                print("Find 'custom_effects.json' in " .. localId)

                local success, effectList = pcall(sm.json.open, customEffectsPath)
                if success and type(effectList) == "table" then
                    for _, filename in ipairs(effectList) do
                        local fullPath = modPath .. "/Effects/Database/EffectSets/" .. filename
                        if sm.json.fileExists(fullPath) then
                            local success2, effects = pcall(sm.json.open, fullPath)
                            if success2 and type(effects) == "table" then
                                for name, effect in pairs(effects) do
                                    if type(name) == "string" and name:gsub(":", "") == name then
                                        table.insert(customRadio.tracks, name)
                                        if effect.radioMod then
                                            customRadio.trackInfo[name] = {
                                                Name = effect.radioMod.Name or name,
                                                Author = effect.radioMod.Author or "Unknown",
                                                Image = effect.radioMod.Image or "Gui/Icons/default_image.png",
                                                Duration = effect.radioMod.Duration or 0,
                                                ModUUID = localId
                                            }
                                        end
                                    end
                                end
                            else
                                print("Couldn't load effects from: " .. fullPath)
                            end
                        else
                            print("File not found: " .. fullPath)
                        end
                    end
                else
                    print("Couldn't load list of effects from: " .. customEffectsPath)
                end
            end

            local modPlaylistPath = modPath .. "/Effects/playlists.json"
            if sm.json.fileExists(modPlaylistPath) then
                print("Find 'playlists.json' in " .. localId)
                Utilities._loadPlaylistFile(customRadio, modPlaylistPath)
            end
        end
    end

    ModDatabase.unloadShapesets()
end

function Utilities._loadPlaylistFile(customRadio, filePath)
    local success, data = pcall(sm.json.open, filePath)
    if not success or type(data) ~= "table" then
        print("Failed to load playlists from: " .. filePath)
        return
    end

    for playlistName, trackList in pairs(data) do
        if type(playlistName) == "string" and type(trackList) == "table" then
            local validated = {}
            for _, trackName in ipairs(trackList) do
                if type(trackName) == "string" then
                    table.insert(validated, trackName)
                end
            end

            if #validated > 0 then
                if customRadio.playlists[playlistName] then
                    for _, t in ipairs(validated) do
                        table.insert(customRadio.playlists[playlistName], t)
                    end
                    print("Merged playlist '" .. playlistName .. "' from " .. filePath)
                else
                    customRadio.playlists[playlistName] = validated
                    table.insert(customRadio.playlistNames, playlistName)
                    print("Loaded playlist '" .. playlistName .. "' (" .. #validated .. " tracks) from " .. filePath)
                end
            end
        end
    end
end

function Utilities.loadPlaylists(customRadio)
    customRadio.playlists = {}
    customRadio.playlistNames = {}

    customRadio.playlists["All Tracks"] = {}
    customRadio.playlistNames[1] = "All Tracks"
    for _, t in ipairs(customRadio.tracks) do
        table.insert(customRadio.playlists["All Tracks"], t)
    end

    local ownPath = "$CONTENT_DATA/Effects/playlists.json"
    if sm.json.fileExists(ownPath) then
        Utilities._loadPlaylistFile(customRadio, ownPath)
    else
        print("(Radio Mod) No playlists.json found at " .. ownPath .. " — only 'All Tracks' available")
    end

    local extras = {}
    for i = 2, #customRadio.playlistNames do
        table.insert(extras, customRadio.playlistNames[i])
    end
    
    table.sort(extras)
    for i, name in ipairs(extras) do
        customRadio.playlistNames[i + 1] = name
    end

    print("(Radio Mod) Loaded " .. #customRadio.playlistNames .. " playlist(s)")
end

function Utilities.getPlaylistTracks(customRadio, playlistName)
    if customRadio.playlists and playlistName and customRadio.playlists[playlistName] then
        return customRadio.playlists[playlistName]
    end

    return customRadio.tracks or {}
end

function Utilities.getTrackInfo(radioObj, trackName)
    return (radioObj.trackInfo and trackName and radioObj.trackInfo[trackName]) or {
        Name = trackName or "Unknown",
        Author = "Unknown",
        Image = "Gui/Icons/default_image.png",
        Duration = 0
    }
end

function Utilities.rebuildShuffleQueue(radioObj)
    local tracks = radioObj.tracks or {}
    local pool = {}

    for _, t in ipairs(tracks) do
        if t ~= radioObj.cl_currentAudioName then
            table.insert(pool, t)
        end
    end

    for i = #pool, 2, -1 do
        local j = math.random(1, i)
        pool[i], pool[j] = pool[j], pool[i]
    end

    radioObj.cl_shuffleQueue = pool
end

function Utilities.nextShuffleTrack(radioObj)
    if #(radioObj.cl_shuffleQueue or {}) == 0 then
        Utilities.rebuildShuffleQueue(radioObj)
    end

    if #radioObj.cl_shuffleQueue == 0 then
        return nil
    end

    local track = radioObj.cl_shuffleQueue[1]
    table.remove(radioObj.cl_shuffleQueue, 1)
    return track
end

function Utilities.selectRandomTrack(radioObj, callback)
    local tracks = radioObj.tracks or {}

    if #tracks == 0 then
        return
    end

    callback(tracks[math.random(1, #tracks)])
end

function Utilities.changeSound(radioObj, direction, tracks, callback)
    if not tracks or #tracks == 0 then
        return
    end

    if radioObj.cl_shuffle then
        local next = Utilities.nextShuffleTrack(radioObj)
        if next then
            callback(next)
        end
        return
    end

    local currentIndex = table.indexOf(tracks, radioObj.cl_currentAudioName)

    if not currentIndex then
        callback(tracks[1])
        return
    end

    local newIndex = ((currentIndex - 1 + direction) % #tracks) + 1
    callback(tracks[newIndex])
end
