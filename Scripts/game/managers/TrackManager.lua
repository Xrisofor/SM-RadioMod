TrackManager = class()

REPEAT_NONE = 0
REPEAT_TRACK = 1
REPEAT_PLAYLIST = 2

function TrackManager.buildTrackInfo( source, key, fallbackName, modUUID )
    return {
        Key = key,
        Name = source.Name or fallbackName,
        Author = source.Author or "Unknown",
        Image = source.Image or "Gui/Icons/default_image.png",
        Duration = source.Duration or 0,
        BeatData = source.BeatData,
        ModUUID = modUUID
    }
end

local function addTrack( object, key, record )
    if object.trackIndex[ key ] then
        return
    end

    record = record or {
        Key = key,
        Name = key,
        Author = "Unknown",
        Image = "Gui/Icons/default_image.png",
        Duration = 0
    }

    table.insert( object.tracks, record )
    object.trackIndex[ key ] = #object.tracks
end

function TrackManager.sv_onCreate( self )
    TrackManager.loadCustomMusicTracks( self )
end

function TrackManager.cl_onCreate( self )
    self.cl_currentAudio = nil
    self.cl_playState = false
    self.cl_currentPlaylist = "All Tracks"
end

function TrackManager.loadCustomMusicTracks( object )
    object.tracks = {}
    object.trackIndex = {}

    local function loadTracks( filePath )
        if not sm.json.fileExists( filePath ) then
            print( "(Custom Radio / Radio Mod) File not found: " .. filePath )
            return
        end

        local success, data = pcall( sm.json.open, filePath )
        if not success or type( data ) ~= "table" then
            print( "(Custom Radio / Radio Mod) Failed to parse file (invalid format): " .. filePath )
            return
        end

        local isEffectSet = false
        for k, _ in pairs( data ) do
            if type( k ) == "string" then
                isEffectSet = true
            end
            break
        end

        if isEffectSet then
            for name, effect in pairs( data ) do
                if type( name ) == "string" and name:gsub( ":", "" ) == name then
                    local record = effect.radioMod and TrackManager.buildTrackInfo( effect.radioMod, name, name )
                    addTrack( object, name, record )
                end
            end
        else
            for _, file in ipairs( data ) do
                local fullPath = "$CONTENT_DATA/Effects/Database/EffectSets/" .. file
                if sm.json.fileExists( fullPath ) then
                    local success2, effects = pcall( sm.json.open, fullPath )
                    if success2 and type( effects ) == "table" then
                        for name, effect in pairs( effects ) do
                            if type( name ) == "string" and name:gsub( ":", "" ) == name then
                                local record = effect.radioMod and TrackManager.buildTrackInfo( effect.radioMod, name, name )
                                addTrack( object, name, record )
                            end
                        end
                    else
                        print( "(Custom Radio / Radio Mod) Failed to load effects from: " .. fullPath )
                    end
                else
                    print( "(Custom Radio / Radio Mod) File not found: " .. fullPath )
                end
            end
        end
    end

    loadTracks( "$CONTENT_DATA/Effects/Database/EffectSets/game.effectset" )
    loadTracks( "$CONTENT_DATA/Effects/Database/EffectSets/events.effectset" )
    loadTracks( "$CONTENT_DATA/Effects/Database/EffectSets/custom_events.effectset" )

    table.sort( object.tracks, function( a, b ) return a.Key < b.Key end )
    for i, t in ipairs( object.tracks ) do
        object.trackIndex[t.Key] = i
    end

    TrackManager.loadPlaylists( object )
    TrackManager.initCustomTracks( object )
end

function TrackManager.extractPlaylistData( raw )
    if type( raw ) ~= "table" then
        return nil, nil
    end

    if type( raw.Tracks ) == "table" then
        local tracks = {}
        for _, trackName in ipairs( raw.Tracks ) do
            if type( trackName ) == "string" then
                table.insert( tracks, trackName )
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
    for _, trackName in ipairs( raw ) do
        if type( trackName ) == "string" then
            table.insert( tracks, trackName )
        end
    end
    return tracks, nil
end

function TrackManager.formatTime( ms )
    ms = tonumber( ms ) or 0
    if ms < 0 then
        ms = 0
    end

    local totalSeconds = math.floor( ms / 1000 )
    local minutes = math.floor( totalSeconds / 60 )
    local seconds = totalSeconds % 60

    return string.format( "%d:%02d", minutes, seconds )
end

function TrackManager.buildTrackKey( name, modUUID )
    if modUUID and tostring( modUUID ) ~= "" then
        return tostring( modUUID ) .. name
    end
    return name
end

function TrackManager.getPlaylistInfo( object, playlistKey )
    local idx = object.playlistIndex and playlistKey and object.playlistIndex[playlistKey]
    local playlist = idx and object.playlists[idx]
    return playlist or {
        Key = playlistKey,
        Name = playlistKey or "Unknown",
        Author = "",
        Image = "Gui/Icons/default_image.png",
        Tracks = {}
    }
end

local function getOrCreatePlaylist( object, key, defaults )
    local idx = object.playlistIndex[ key ]

    if idx then
        return object.playlists[ idx ], false
    end

    table.insert( object.playlists, defaults )
    object.playlistIndex[ key ] = #object.playlists

    return defaults, true
end

function TrackManager.initCustomTracks( object )
    print( "(Custom Radio / Radio Mod) Loading tracks from registered mods" )

    sm.radioMod = sm.radioMod or {}
    sm.radioMod.tracks = sm.radioMod.tracks or {}
    sm.radioMod.playlists = sm.radioMod.playlists or {}

    for _, entry in ipairs( sm.radioMod.tracks ) do
        local name = entry.Name
        local trackInfo = entry.TrackInfo
        local modUUID = entry.ModUUID

        if type( name ) == "string" and name:gsub( ":", "" ) == name then
            local key = TrackManager.buildTrackKey( name, modUUID )
            local record = trackInfo and TrackManager.buildTrackInfo( trackInfo, key, name, modUUID )
            addTrack( object, key, record )
        end
    end

    for playlistName, rawEntry in pairs( sm.radioMod.playlists ) do
        if type( playlistName ) == "string" and type( rawEntry ) == "table" then
            local rawTracks, info = TrackManager.extractPlaylistData( rawEntry )

            if rawTracks and #rawTracks > 0 then
                local playlistModUUID = info and info.ModUUID
                local tracks = {}
                for _, t in ipairs( rawTracks ) do
                    table.insert( tracks, TrackManager.buildTrackKey( t, playlistModUUID ) )
                end

                local playlist, isNew = getOrCreatePlaylist( object, playlistName, {
                    Key = playlistName,
                    Name = ( info and info.Name ) or playlistName,
                    Author = ( info and info.Author ) or "Unknown",
                    Image = ( info and info.Image ) or "Gui/Icons/default_image.png",
                    ModUUID = info and info.ModUUID,
                    Tracks = tracks
                } )
                if not isNew then
                    for _, t in ipairs( tracks ) do
                        table.insert( playlist.Tracks, t )
                    end
                end

                local allTracks = TrackManager.getPlaylistInfo( object, "All Tracks" ).Tracks
                for _, t in ipairs( tracks ) do
                    local found = false
                    for _, existing in ipairs( allTracks ) do
                        if existing == t then
                            found = true
                            break
                        end
                    end
                    if not found then
                        table.insert( allTracks, t )
                    end
                end
            end
        end
    end
end

function TrackManager._loadPlaylistFile( object, filePath )
    local success, data = pcall( sm.json.open, filePath )
    if not success or type( data ) ~= "table" then
        print( "(Custom Radio / Radio Mod) Failed to load playlists from: " .. filePath )
        return
    end

    for playlistName, rawEntry in pairs( data ) do
        if type( playlistName ) == "string" and type( rawEntry ) == "table" then
            local rawTracks, info = TrackManager.extractPlaylistData( rawEntry )

            if rawTracks and #rawTracks > 0 then
                local playlistModUUID = info and info.ModUUID
                local tracks = {}
                for _, t in ipairs( rawTracks ) do
                    table.insert( tracks, TrackManager.buildTrackKey( t, playlistModUUID ) )
                end

                local playlist, isNew = getOrCreatePlaylist( object, playlistName, {
                    Key = playlistName,
                    Name = ( info and info.Name ) or playlistName,
                    Author = ( info and info.Author ) or "Unknown",
                    Image = ( info and info.Image ) or "Gui/Icons/default_image.png",
                    ModUUID = info and info.ModUUID,
                    Tracks = tracks
                } )
                if isNew then
                    print( "(Custom Radio / Radio Mod) Loaded playlist \"" .. playlistName .. "\" (" .. #tracks .. " tracks) from " .. filePath )
                else
                    for _, t in ipairs( tracks ) do
                        table.insert( playlist.Tracks, t )
                    end
                    print( "(Custom Radio / Radio Mod) Merged playlist \"" .. playlistName .. "\" from " .. filePath )
                end
            end
        end
    end
end

function TrackManager.loadPlaylists( object )
    object.playlists = {}
    object.playlistIndex = {}

    local allTracks = {}
    for _, t in ipairs( object.tracks ) do
        table.insert( allTracks, t.Key )
    end

    getOrCreatePlaylist( object, "All Tracks", {
        Key = "All Tracks",
        Name = "All Tracks",
        Author = "You",
        Image = "Gui/Icons/default_image.png",
        Tracks = allTracks
    } )

    local ownPath = "$CONTENT_DATA/Effects/playlists.json"
    if sm.json.fileExists( ownPath ) then
        TrackManager._loadPlaylistFile( object, ownPath )
    else
        print( "(Custom Radio / Radio Mod) No playlists.json found at " .. ownPath .. " - only \"All Tracks\" available" )
    end

    local extras = {}
    for i = 2, #object.playlists do
        table.insert( extras, object.playlists[i] )
    end
    table.sort( extras, function( a, b ) return a.Key < b.Key end )

    for i, playlist in ipairs( extras ) do
        object.playlists[i + 1] = playlist
        object.playlistIndex[playlist.Key] = i + 1
    end

    print( "(Custom Radio / Radio Mod) Loaded " .. #object.playlists .. " playlist(s)" )
end

function TrackManager.getPlaylists( object )
    return object.playlists or {}
end

function TrackManager.getPlaylistTracks( object, playlistKey )
    local idx = object.playlistIndex and playlistKey and object.playlistIndex[playlistKey]
    local playlist = idx and object.playlists[idx]
    if playlist then
        return playlist.Tracks
    end

    return TrackManager.getPlaylistInfo( object, "All Tracks" ).Tracks
end

function TrackManager.getTracks( object )
    return object.tracks or {}
end

function TrackManager.getTrackInfo( object, trackKey )
    local idx = object.trackIndex and trackKey and object.trackIndex[trackKey]
    local track = idx and object.tracks[idx]
    return track or {
        Key = trackKey,
        Name = trackKey or "Unknown",
        Author = "Unknown",
        Image = "Gui/Icons/default_image.png",
        Duration = 0
    }
end

function TrackManager.rebuildShuffleQueue( object, tracks )
    tracks = tracks or TrackManager.getPlaylistInfo( object, "All Tracks" ).Tracks
    local pool = {}

    for _, t in ipairs( tracks ) do
        if t ~= object.cl_currentAudio then
            table.insert( pool, t )
        end
    end

    for i = #pool, 2, -1 do
        local j = math.random( 1, i )
        pool[i], pool[j] = pool[j], pool[i]
    end

    object.cl_shuffleQueue = pool
end

function TrackManager.nextShuffleTrack( object, tracks )
    if #( object.cl_shuffleQueue or {} ) == 0 then
        TrackManager.rebuildShuffleQueue( object, tracks )
    end

    if #object.cl_shuffleQueue == 0 then
        return nil
    end

    local track = object.cl_shuffleQueue[1]
    table.remove( object.cl_shuffleQueue, 1 )
    return track
end

function TrackManager.selectRandomTrack( object, callback )
    local tracks = object.tracks or {}

    if #tracks == 0 then
        return
    end

    callback( tracks[math.random( 1, #tracks )].Key )
end

function TrackManager.changeSound( object, direction, tracks, callback )
    if not tracks or #tracks == 0 then
        return
    end

    if object.cl_shuffle then
        local next = TrackManager.nextShuffleTrack( object, tracks )
        if next then
            callback( next )
        end
        return
    end

    local currentIndex = nil
    for i, track in ipairs( tracks ) do
        if track == object.cl_currentAudio then
            currentIndex = i
            break
        end
    end

    if not currentIndex then
        callback( tracks[1] )
        return
    end

    local newIndex = ( ( currentIndex - 1 + direction ) % #tracks ) + 1
    callback( tracks[newIndex] )
end

-- ─────────────────────────────────────────────
--  BEAT SYNC DATA
-- ─────────────────────────────────────────────

function TrackManager.loadBeatData( path )
    if not path or path == "" then
        return nil
    end

    if not sm.json.fileExists( path ) then
        print( "(Custom Radio / Radio Mod) Light data file not found: " .. path )
        return nil
    end

    local success, data = pcall( sm.json.open, path )
    if not success or type( data ) ~= "table" then
        print( "(Custom Radio / Radio Mod) Failed to load light data: " .. path )
        return nil
    end

    return data
end

function TrackManager.getBeatValue( beatData, positionMs, key )
    if not beatData then
        return 0
    end

    local values = beatData[key or "BeatData"]
    if not values or #values == 0 then
        return 0
    end

    local step = beatData.BeatStep or 100
    local index = math.floor( ( positionMs or 0 ) / step ) + 1

    if index < 1 then
        index = 1
    elseif index > #values then
        index = #values
    end

    return values[index]
end

function TrackManager.getBeatLevels( beatData )
    local levels = beatData and beatData.BeatLevels
    if not levels or levels <= 0 then
        return 15
    end
    return levels
end

-- ─────────────────────────────────────────────
--  AUDIO EFFECT LIFECYCLE
-- ─────────────────────────────────────────────

function TrackManager.isValidEffect( object )
    return object.cl_audio_effect ~= nil and sm.exists( object.cl_audio_effect )
end

function TrackManager.hasRealTrack( object )
    return object.cl_currentAudio ~= nil and object.cl_currentAudio ~= ""
end

function TrackManager.destroyEffect( object )
    if TrackManager.isValidEffect( object ) then
        if object.cl_audio_effect:isPlaying() then
            object.cl_audio_effect:stop()
        end
        object.cl_audio_effect:destroy()
    end
    object.cl_audio_effect = nil
end

function TrackManager.createEffect( object, trackName )
    if trackName and trackName ~= "" then
        object.cl_audio_effect = sm.effect.createEffect( trackName, object.interactable )
    else
        object.cl_audio_effect = nil
    end
end

function TrackManager.changeTrack( object, newTrack, onDestroyed )
    if object.cl_currentAudio == newTrack then
        return false
    end

    local hadEffect = TrackManager.isValidEffect( object )
    TrackManager.destroyEffect( object )
    if hadEffect and onDestroyed then
        onDestroyed()
    end

    object.cl_effectJustStarted = false
    object.cl_currentAudio = newTrack

    TrackManager.createEffect( object, newTrack )

    local info = TrackManager.getTrackInfo( object, newTrack )
    object.cl_trackDuration = info.Duration or 0
    object.cl_trackPosition = 0
    object.cl_trackStartRetries = 0

    return true
end

function TrackManager.updateAudioEffect( object, play )
    if play then
        if TrackManager.hasRealTrack( object ) then
            if TrackManager.isValidEffect( object ) and not object.cl_audio_effect:isPlaying() then
                object.cl_audio_effect:start()
                object.cl_effectJustStarted = true
                object.cl_trackStartClock = object.cl_elapsedTime or 0
                
                if ( object.poseWeightCount or 0 ) > 0 then
                    object.interactable:setPoseWeight( 0, 1 )
                end

                if object.cl_trackPosition and object.cl_trackPosition > 0 then
                    object.cl_audio_effect:setParameter( "CAE_Position", object.cl_trackPosition / 1000.0 )
                end
            end
        else
            TrackManager.destroyEffect( object )

            if ( object.poseWeightCount or 0 ) > 0 then
                object.interactable:setPoseWeight( 0, 0 )
            end
        end
    else
        if TrackManager.isValidEffect( object ) then
            if object.cl_audio_effect:isPlaying() then
                object.cl_audio_effect:stop()
            end
            
            if ( object.poseWeightCount or 0 ) > 0 then
                object.interactable:setPoseWeight( 0, 0 )
            end
        end
    end
end

function TrackManager.retryCurrentTrack( object )
    object.cl_trackStartRetries = ( object.cl_trackStartRetries or 0 ) + 1
    TrackManager.destroyEffect( object )
    TrackManager.createEffect( object, object.cl_currentAudio )
    object.cl_effectJustStarted = false
end

function TrackManager.onTrackEnded( object, activeTracks, selectTrack, stopPlayback, onRestart )
    if object.cl_repeatMode == REPEAT_TRACK then
        TrackManager.destroyEffect( object )

        if onRestart then
            onRestart()
        end

        TrackManager.createEffect( object, object.cl_currentAudio )
        object.cl_effectJustStarted = true
        object.cl_trackPosition = 0
        object.cl_trackStartRetries = 0

        return
    end

    activeTracks = activeTracks or {}

    if object.cl_shuffle then
        local next = TrackManager.nextShuffleTrack( object, activeTracks )
        if next then
            selectTrack( next )
        end
        return
    end
    local idx = 0
    for i, t in ipairs( activeTracks ) do
        if t == object.cl_currentAudio then
            idx = i
            break
        end
    end

    if idx >= #activeTracks then
        if object.cl_repeatMode == REPEAT_PLAYLIST then
            selectTrack( activeTracks[1] )
        else
            stopPlayback()
        end
    else
        selectTrack( activeTracks[idx + 1] )
    end
end

function TrackManager.updateFmAudio( object, signal, shouldPlay, dt, driftThresholdMs, onTrackChanged )
    driftThresholdMs = driftThresholdMs or 500

    if not signal then
        if TrackManager.isValidEffect( object ) and object.cl_audio_effect:isPlaying() then
            object.cl_audio_effect:stop()
        end

        if ( object.poseWeightCount or 0 ) > 0 then
            object.interactable:setPoseWeight( 0, 0 )
        end

        object.cl_fmCurrentTrack = nil
        object.cl_fmTrackPosition = 0
        return false
    end

    local wasPlaying = TrackManager.isValidEffect( object ) and object.cl_audio_effect:isPlaying()
    local trackChanged = signal.track ~= object.cl_fmCurrentTrack

    if trackChanged then
        local hadEffect = TrackManager.isValidEffect( object )
        TrackManager.destroyEffect( object )

        if hadEffect and onTrackChanged then
            onTrackChanged()
        end

        object.cl_fmCurrentTrack = signal.track
        object.cl_fmTrackPosition = signal.position or 0

        if signal.track and signal.track ~= "" then
            TrackManager.createEffect( object, signal.track )
            if TrackManager.isValidEffect( object ) then
                object.cl_audio_effect:setParameter( "CAE_Position", object.cl_fmTrackPosition / 1000.0 )
            end
        end
    end

    local actualPlay = shouldPlay and signal.playState

    if actualPlay then
        if TrackManager.isValidEffect( object ) and not object.cl_audio_effect:isPlaying() then
            object.cl_audio_effect:start()

            if ( object.poseWeightCount or 0 ) > 0 then
                object.interactable:setPoseWeight( 0, 1 )
            end

            object.cl_fmTrackPosition = signal.position or 0
            object.cl_audio_effect:setParameter( "CAE_Position", object.cl_fmTrackPosition / 1000.0 )
        end
    else
        if TrackManager.isValidEffect( object ) and object.cl_audio_effect:isPlaying() then
            object.cl_audio_effect:stop()
        end

        if ( object.poseWeightCount or 0 ) > 0 then
            object.interactable:setPoseWeight( 0, 0 )
        end
    end

    if actualPlay and not trackChanged and wasPlaying then
        local speed = ( signal.playSpeed and signal.playSpeed > 0 ) and signal.playSpeed or 1
        object.cl_fmTrackPosition = ( object.cl_fmTrackPosition or 0 ) + dt * 1000 * speed

        local drift = math.abs( ( object.cl_fmTrackPosition or 0 ) - ( signal.position or 0 ) )
        if drift > driftThresholdMs then
            object.cl_fmTrackPosition = signal.position or 0
            if TrackManager.isValidEffect( object ) then
                object.cl_audio_effect:setParameter( "CAE_Position", object.cl_fmTrackPosition / 1000.0 )
            end
        end
    end

    if TrackManager.isValidEffect( object ) then
        local spd = signal.playSpeed or 1
        object.cl_audio_effect:setParameter( "CAE_Pitch", spd > 0 and spd or 0.5 )
    end

    return actualPlay
end
