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
    loadTracks("$CONTENT_DATA/Effects/Database/EffectSets/custom_events.effectset")

    table.sort(customRadio.tracks)

    Utilities.loadPlaylists(customRadio)
    Utilities.initCustomTracks(customRadio)
end

function Utilities.extractPlaylistData(raw)
    if type(raw) ~= "table" then
        return nil, nil
    end

    if type(raw.Tracks) == "table" then
        local tracks = {}
        for _, trackName in ipairs(raw.Tracks) do
            if type(trackName) == "string" then
                table.insert(tracks, trackName)
            end
        end
        local info = {
            Name = raw.Name,
            Author = raw.Author,
            Image = raw.Image,
            ModUUID = raw.ModUUID
        }
        return tracks, info
    end

    local tracks = {}
    for _, trackName in ipairs(raw) do
        if type(trackName) == "string" then
            table.insert(tracks, trackName)
        end
    end
    return tracks, nil
end

function Utilities.formatTime(ms)
    ms = tonumber(ms) or 0
    if ms < 0 then
        ms = 0
    end

    local totalSeconds = math.floor(ms / 1000)
    local minutes = math.floor(totalSeconds / 60)
    local seconds = totalSeconds % 60

    return string.format("%d:%02d", minutes, seconds)
end

function Utilities.buildTrackKey(name, modUUID)
    if modUUID and tostring(modUUID) ~= "" then
        return tostring(modUUID) .. name
    end
    return name
end

function Utilities.getPlaylistInfo(customRadio, playlistName)
    return (customRadio.playlistInfo and playlistName and customRadio.playlistInfo[playlistName]) or {
        Name = playlistName or "Unknown",
        Author = "",
        Image = "Gui/Icons/default_image.png"
    }
end

function Utilities.initCustomTracks(customRadio)
    print("(Radio Mod) Loading tracks from registered mods")

    sm.radioMod = sm.radioMod or {}
    sm.radioMod.tracks = sm.radioMod.tracks or {}
    sm.radioMod.playlists = sm.radioMod.playlists or {}

    for _, entry in ipairs(sm.radioMod.tracks) do
        local name = entry.Name
        local trackInfo = entry.TrackInfo
        local modUUID = entry.ModUUID

        if type(name) == "string" and name:gsub(":", "") == name then
            local key = Utilities.buildTrackKey(name, modUUID)

            table.insert(customRadio.tracks, key)
            if trackInfo then
                customRadio.trackInfo[key] = {
                    Name = trackInfo.Name or name,
                    Author = trackInfo.Author or "Unknown",
                    Image = trackInfo.Image or "Gui/Icons/default_image.png",
                    Duration = trackInfo.Duration or 0,
                    ModUUID = modUUID
                }
            end
        end
    end

    for playlistName, rawEntry in pairs(sm.radioMod.playlists) do
        if type(playlistName) == "string" and type(rawEntry) == "table" then
            local rawTracks, info = Utilities.extractPlaylistData(rawEntry)

            if rawTracks and #rawTracks > 0 then
                local playlistModUUID = info and info.ModUUID
                local tracks = {}
                for _, t in ipairs(rawTracks) do
                    table.insert(tracks, Utilities.buildTrackKey(t, playlistModUUID))
                end

                if customRadio.playlists[playlistName] then
                    for _, t in ipairs(tracks) do
                        table.insert(customRadio.playlists[playlistName], t)
                    end
                else
                    customRadio.playlists[playlistName] = tracks
                    table.insert(customRadio.playlistNames, playlistName)
                end
                for _, t in ipairs(tracks) do
                    local found = false
                    for _, existing in ipairs(customRadio.playlists["All Tracks"]) do
                        if existing == t then
                            found = true
                            break
                        end
                    end
                    if not found then
                        table.insert(customRadio.playlists["All Tracks"], t)
                    end
                end

                if not customRadio.playlistInfo[playlistName] then
                    customRadio.playlistInfo[playlistName] = {
                        Name = (info and info.Name) or playlistName,
                        Author = (info and info.Author) or "Unknown",
                        Image = (info and info.Image) or "Gui/Icons/default_image.png",
                        ModUUID = info and info.ModUUID
                    }
                end
            end
        end
    end
end

function Utilities._loadPlaylistFile(customRadio, filePath)
    local success, data = pcall(sm.json.open, filePath)
    if not success or type(data) ~= "table" then
        print("Failed to load playlists from: " .. filePath)
        return
    end

    for playlistName, rawEntry in pairs(data) do
        if type(playlistName) == "string" and type(rawEntry) == "table" then
            local rawTracks, info = Utilities.extractPlaylistData(rawEntry)

            if rawTracks and #rawTracks > 0 then
                local playlistModUUID = info and info.ModUUID
                local tracks = {}
                for _, t in ipairs(rawTracks) do
                    table.insert(tracks, Utilities.buildTrackKey(t, playlistModUUID))
                end

                if customRadio.playlists[playlistName] then
                    for _, t in ipairs(tracks) do
                        table.insert(customRadio.playlists[playlistName], t)
                    end
                    print("Merged playlist '" .. playlistName .. "' from " .. filePath)
                else
                    customRadio.playlists[playlistName] = tracks
                    table.insert(customRadio.playlistNames, playlistName)
                    print("Loaded playlist '" .. playlistName .. "' (" .. #tracks .. " tracks) from " .. filePath)
                end

                if info and not customRadio.playlistInfo[playlistName] then
                    customRadio.playlistInfo[playlistName] = {
                        Name = info.Name or playlistName,
                        Author = info.Author or "Unknown",
                        Image = info.Image or "Gui/Icons/default_image.png",
                        ModUUID = info.ModUUID
                    }
                end
            end
        end
    end
end

function Utilities.loadPlaylists(customRadio)
    customRadio.playlists = {}
    customRadio.playlistNames = {}
    customRadio.playlistInfo = {}

    customRadio.playlists["All Tracks"] = {}
    customRadio.playlistNames[1] = "All Tracks"
    for _, t in ipairs(customRadio.tracks) do
        table.insert(customRadio.playlists["All Tracks"], t)
    end
    customRadio.playlistInfo["All Tracks"] = {
        Name = "All Tracks",
        Author = "You",
        Image = "Gui/Icons/default_image.png"
    }

    local ownPath = "$CONTENT_DATA/Effects/playlists.json"
    if sm.json.fileExists(ownPath) then
        Utilities._loadPlaylistFile(customRadio, ownPath)
    else
        print("(Radio Mod) No playlists.json found at " .. ownPath .. " - only 'All Tracks' available")
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

function Utilities.getTrackInfo(customRadio, trackName)
    return (customRadio.trackInfo and trackName and customRadio.trackInfo[trackName]) or {
        Name = trackName or "Unknown",
        Author = "Unknown",
        Image = "Gui/Icons/default_image.png",
        Duration = 0
    }
end

function Utilities.rebuildShuffleQueue(customRadio)
    local tracks = customRadio.tracks or {}
    local pool = {}

    for _, t in ipairs(tracks) do
        if t ~= customRadio.cl_currentAudioName then
            table.insert(pool, t)
        end
    end

    for i = #pool, 2, -1 do
        local j = math.random(1, i)
        pool[i], pool[j] = pool[j], pool[i]
    end

    customRadio.cl_shuffleQueue = pool
end

function Utilities.nextShuffleTrack(customRadio)
    if #(customRadio.cl_shuffleQueue or {}) == 0 then
        Utilities.rebuildShuffleQueue(customRadio)
    end

    if #customRadio.cl_shuffleQueue == 0 then
        return nil
    end

    local track = customRadio.cl_shuffleQueue[1]
    table.remove(customRadio.cl_shuffleQueue, 1)
    return track
end

function Utilities.selectRandomTrack(customRadio, callback)
    local tracks = customRadio.tracks or {}

    if #tracks == 0 then
        return
    end

    callback(tracks[math.random(1, #tracks)])
end

function Utilities.changeSound(customRadio, direction, tracks, callback)
    if not tracks or #tracks == 0 then
        return
    end

    if customRadio.cl_shuffle then
        local next = Utilities.nextShuffleTrack(customRadio)
        if next then
            callback(next)
        end
        return
    end

    local currentIndex = nil
    for i, track in ipairs(tracks) do
        if track == customRadio.cl_currentAudioName then
            currentIndex = i
            break
        end
    end

    if not currentIndex then
        callback(tracks[1])
        return
    end

    local newIndex = ((currentIndex - 1 + direction) % #tracks) + 1
    callback(tracks[newIndex])
end