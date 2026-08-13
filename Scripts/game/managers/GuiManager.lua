dofile( "$CONTENT_DATA/Scripts/game/managers/CustomGridScrollView.lua" )

GuiManager = class()

local GUI_JSON = dofile( "$CONTENT_DATA/Gui/JsonGui/Scrapify.gui" )
ReplaceSubLayouts( GUI_JSON )
local SubTitle = FindWidget( GUI_JSON, "SubTitle" )

local PLAY_ICON = "Gui/Layouts/play-circle.png"
local PAUSE_ICON = "Gui/Layouts/stop-circle.png"

local MIN_PLAY_TIME_BEFORE_DONE = 0.3
local MAX_TRACK_START_RETRIES = 6

local PlaybackControls = {
    Track = {
        Image = FindWidget( GUI_JSON, "TrackImage" ),
        Name = FindWidget( GUI_JSON, "TrackName" ),
        Author = FindWidget( GUI_JSON, "TrackAuthor" ),
    },
    Play = FindWidget( GUI_JSON, "PlayIcon" ),
    Progress = {
        Handle = FindWidget( GUI_JSON, "Handle" ),
        Time = FindWidget( GUI_JSON, "Progress Time" ),
    }
}

-- Track Item
local TRACK_JSON = dofile( "$CONTENT_DATA/Gui/JsonGui/Track.gui" )
local TrackItem = {
    Button = FindWidget( TRACK_JSON, "Button" ),
    Image = FindWidget( TRACK_JSON, "Image" ),
    Name = FindWidget( TRACK_JSON, "Name" ),
    Author = FindWidget( TRACK_JSON, "Author" ),
    Duration = FindWidget( TRACK_JSON, "Duration" )
}

-- Playlist Item
local PLAYLIST_JSON = dofile( "$CONTENT_DATA/Gui/JsonGui/Playlist.gui" )
local PlaylistItem = {
    Button = FindWidget( PLAYLIST_JSON, "Button" ),
    Image = FindWidget( PLAYLIST_JSON, "Image" ),
    Name = FindWidget( PLAYLIST_JSON, "Name" ),
    Author = FindWidget( PLAYLIST_JSON, "Author" ),
    Duration = FindWidget( PLAYLIST_JSON, "Duration" )
}

function GuiManager.cl_onCreate( self )
    self.cl_jsonGui = nil
    self.cl_gridViews = {}
end

local function createGridScrollView( self, name, guiJson, holderName, gridItemSize, scrollStrength )
    assert( self.cl_jsonGui, "(Custom Radio / Radio Mod) jsonGui must be created before calling createGridScrollView" )

    local grid = CustomGridScrollView()
    local holder = FindWidget( guiJson, holderName )
    assert( holder, "(Custom Radio / Radio Mod) Widget holder not found: " .. tostring( holderName ) )

    grid:setup( holder, self.cl_jsonGui, name )

    if gridItemSize then
        grid:setGridItemSize( gridItemSize.width, gridItemSize.height )
    end

    grid:setScrollStrength( scrollStrength or 1 )
    grid:clearGrid()
    grid:resetScroll()

    self.cl_gridViews[ name ] = grid

    return grid
end

function GuiManager.refreshPlaylistGrid( self )
    local playlistGrid = self.cl_gridViews[ "Playlist" ]
    if not playlistGrid then return end

    playlistGrid:clearGrid()
    playlistGrid:resetScroll()

    local playlists = TrackManager.getPlaylists( self )
    for index, playlist in ipairs( playlists ) do
        local itemModPrefix = playlist.ModUUID and ("$CONTENT_" .. tostring(playlist.ModUUID)) or getContentPath()

        PlaylistItem.Button.Name = "Button_" .. index

        PlaylistItem.Name.Caption = playlist.Name or "Unknown"
        PlaylistItem.Author.Caption = playlist.Author or "Unknown"
        PlaylistItem.Image.ImageTexture = itemModPrefix .. "/" .. (playlist.Image or "Gui/Icons/default_image.png")

        local trackCount = playlist.Tracks and #playlist.Tracks or 0
        PlaylistItem.Duration.Caption = tostring( trackCount ) .. (trackCount == 1 and " track" or " tracks")

        playlistGrid:addGridItem( PLAYLIST_JSON )
    end
end

function GuiManager.refreshTrackGrid( self, filterQuery )
    local trackGrid = self.cl_gridViews[ "Track" ]
    if not trackGrid then return end

    trackGrid:clearGrid()
    trackGrid:resetScroll()

    self.cl_currentTrackKeys = {}

    local query = filterQuery and string.lower( filterQuery ) or ""
    local trackKeys = TrackManager.getPlaylistTracks( self, self.cl_currentPlaylist )

    for index, trackKey in ipairs( trackKeys ) do
        local trackInfo = TrackManager.getTrackInfo( self, trackKey )
        local name = trackInfo.Name or "Unknown"
        local author = trackInfo.Author or "Unknown"

        local matches = true
        if query ~= "" then
            matches = string.find( string.lower( name ), query, 1, true ) ~= nil or
                      string.find( string.lower( author ), query, 1, true ) ~= nil
        end

        if matches then
            local itemModPrefix = trackInfo.ModUUID and ("$CONTENT_" .. tostring(trackInfo.ModUUID)) or getContentPath()

            TrackItem.Button.Name = "Button_" .. index
            
            TrackItem.Name.Caption = name
            TrackItem.Author.Caption = author
            TrackItem.Duration.Caption = ( ( trackInfo.Duration or 0 ) > 0 ) and TrackManager.formatTime( trackInfo.Duration ) or "N/A"
            TrackItem.Image.ImageTexture = itemModPrefix .. "/" .. (trackInfo.Image or "Gui/Icons/default_image.png")

            self.cl_currentTrackKeys[ index ] = trackKey

            trackGrid:addGridItem( TRACK_JSON )
        end
    end
end

function GuiManager.refreshPlaybackGui( self )
    local trackKey = self.cl_currentAudioName or self.cl_currentAudio
    local info = TrackManager.getTrackInfo( self, trackKey )
    local modPrefix = info.ModUUID and ("$CONTENT_" .. tostring(info.ModUUID)) or getContentPath()

    PlaybackControls.Track.Name.Caption = info.Name
    PlaybackControls.Track.Author.Caption = info.Author
    PlaybackControls.Track.Image.ImageTexture = modPrefix .. "/" .. (info.Image or "Gui/Icons/default_image.png")
end

function GuiManager.refreshPlayIcon( self )
    local iconPath = self.cl_playState and PAUSE_ICON or PLAY_ICON
    PlaybackControls.Play.ImageTexture = getContentPath() .. "/" .. iconPath
end

function GuiManager.refreshTrackProgress( self )
    local duration = self.cl_trackDuration or 0
    local hasDuration = duration > 0

    if not hasDuration then
        PlaybackControls.Progress.Time.Caption = "Seeking unavailable"
        PlaybackControls.Progress.Handle.Visible = false
        return
    end

    PlaybackControls.Progress.Handle.Visible = true
    PlaybackControls.Progress.Time.Caption = TrackManager.formatTime( self.cl_trackPosition or 0 ) .. " / " .. TrackManager.formatTime( duration )
end

function GuiManager.getActiveTracks( self )
    return TrackManager.getPlaylistTracks( self, self.cl_currentPlaylist )
end

function GuiManager.onTrackEnded( self )
    TrackManager.onTrackEnded( self, GuiManager.getActiveTracks( self ),
        function( track )
            GuiManager.selectTrack( self, track )
        end,
        function()
            self.cl_playState = false
            TrackManager.updateAudioEffect( self, false )
            GuiManager.refreshPlayIcon( self )
        end,
        function()
            print( "(Custom Radio / Radio Mod) No tracks available to play after track ended." )
        end
    )
end

function GuiManager.cl_onInteract( self, char, state )
    if not state then
        return
    end

    self.cl_jsonGui = sm.jsonGui.createGui( { isInteractive = true, bNeedsCursor = true } )

    createGridScrollView(
        self,
        "Playlist",
        GUI_JSON,
        "Playlist Holder",
        { width = 270, height = 75 },
        1
    )

    createGridScrollView(
        self,
        "Track",
        GUI_JSON,
        "Track Holder",
        { width = 375, height = 75 },
        1
    )

    GuiManager.refreshPlaybackGui( self )
    GuiManager.refreshPlayIcon( self )
    GuiManager.refreshTrackProgress( self )
    GuiManager.refreshPlaylistGrid( self )
    GuiManager.refreshTrackGrid( self, "" )

    SubTitle.Caption = ( ( self.maxChildCount or 0 ) > 0 ) and ( #self.interactable:getChildren() .. " / " .. self.maxChildCount ) or "Music is always nearby"

    self.cl_jsonGui:render( GUI_JSON )
end

function GuiManager.cl_onSearchTextEdit( self, name, text )
    GuiManager.refreshTrackGrid( self, text )
end

function GuiManager.cl_onSearchTextEnter( self, name, text )
    GuiManager.refreshTrackGrid( self, text )
end

function GuiManager.cl_onUpdate( self, dt )
    if not self.cl_jsonGui then
        return
    end

    self.cl_elapsedTime = ( self.cl_elapsedTime or 0 ) + dt

    if self.cl_playState and TrackManager.isValidEffect( self ) then
        if self.cl_effectJustStarted then
            if self.cl_audio_effect:isPlaying() then
                self.cl_effectJustStarted = false
            end
        elseif self.cl_audio_effect:isDone() then
            local playedFor = ( self.cl_elapsedTime or 0 ) - ( self.cl_trackStartClock or 0 )
            if playedFor < MIN_PLAY_TIME_BEFORE_DONE and ( self.cl_trackStartRetries or 0 ) < MAX_TRACK_START_RETRIES then
                TrackManager.retryCurrentTrack( self )
            else
                GuiManager.onTrackEnded( self )
            end
        else
            local durationMs = self.cl_trackDuration or 0
            local speed = ( self.cl_playSpeed and self.cl_playSpeed > 0 ) and self.cl_playSpeed or 1
            self.cl_trackPosition = ( self.cl_trackPosition or 0 ) + dt * 1000 * speed
            if durationMs > 0 and self.cl_trackPosition > durationMs then
                self.cl_trackPosition = durationMs
            end
        end
    end

    TrackManager.updateAudioEffect( self, self.cl_playState )
    GuiManager.refreshTrackProgress( self )

    self.cl_jsonGui:render( GUI_JSON )
end

function GuiManager.cl_onDestroy( self )
    if self.cl_jsonGui then
        self.cl_jsonGui:close()
        self.cl_jsonGui = nil
    end
    self.cl_gridViews = {}
end

function GuiManager.cl_onClose( self )
    if self.cl_jsonGui then
        self.cl_jsonGui:close()
        self.cl_jsonGui = nil
    end
    self.cl_gridViews = {}
end

function GuiManager.cl_onTrackScroll( self, _, scrollValue )
    local grid = self.cl_gridViews[ "Track" ]
    if grid then
        grid:handleScroll( scrollValue )
    end
end

function GuiManager.cl_onPlaylistScroll( self, _, scrollValue )
    local grid = self.cl_gridViews[ "Playlist" ]
    if grid then
        grid:handleScroll( scrollValue )
    end
end

function GuiManager.cl_onTrackScrollButtonPressed( self, _, x, y )
    local grid = self.cl_gridViews[ "Track" ]
    if grid then
        grid:handleScrollButtonPressed( x, y )
    end
end

function GuiManager.cl_onPlaylistScrollButtonPressed( self, _, x, y )
    local grid = self.cl_gridViews[ "Playlist" ]
    if grid then
        grid:handleScrollButtonPressed( x, y )
    end
end

function GuiManager.cl_onTrackScrollButtonReleased( self, _, x, y )
    local grid = self.cl_gridViews[ "Track" ]
    if grid then
        grid:handleScrollButtonReleased( x, y )
    end
end

function GuiManager.cl_onPlaylistScrollButtonReleased( self, _, x, y )
    local grid = self.cl_gridViews[ "Playlist" ]
    if grid then
        grid:handleScrollButtonReleased( x, y )
    end
end

function GuiManager.cl_onTrackScrollButtonDrag( self, _, x, y )
    local grid = self.cl_gridViews[ "Track" ]
    if grid then
        grid:handleScrollButtonDrag( x, y )
    end
end

function GuiManager.cl_onPlaylistScrollButtonDrag( self, _, x, y )
    local grid = self.cl_gridViews[ "Playlist" ]
    if grid then
        grid:handleScrollButtonDrag( x, y )
    end
end

function GuiManager.cl_onTrackScrollBarPressed( self, _, x, y )
    local grid = self.cl_gridViews[ "Track" ]
    if grid then
        grid:handleScrollBarPressed( x, y )
    end
end

function GuiManager.cl_onPlaylistScrollBarPressed( self, _, x, y )
    local grid = self.cl_gridViews[ "Playlist" ]
    if grid then
        grid:handleScrollBarPressed( x, y )
    end
end

function GuiManager.cl_onPlaylistClick( self, name )
    local index = tonumber( string.match( name, "Button_(%d+)" ) )
    print("Playlist Clicked: " .. name .. " (Index: " .. tostring(index) .. ")")
    if not index then return end

    local playlists = TrackManager.getPlaylists( self )
    local playlist = playlists[ index ]
    if playlist then
        self.cl_currentPlaylist = playlist.Key
        GuiManager.refreshTrackGrid( self, self.cl_currentSearch or "" )
    end
end

function GuiManager.cl_onTrackClick( self, name )
    local index = tonumber( string.match( name, "Button_(%d+)" ) )
    if not index then return end

    local trackKey = self.cl_currentTrackKeys and self.cl_currentTrackKeys[ index ]
    if not trackKey then return end

    GuiManager.selectTrack( self, trackKey )
end

function GuiManager.selectTrack( self, trackKey )
    if not trackKey or trackKey == "" then
        return
    end

    if self.cl_currentAudio == trackKey then
        self.cl_playState = true
        TrackManager.updateAudioEffect( self, true )
        GuiManager.refreshPlayIcon( self )
        return
    end

    local changed = TrackManager.changeTrack( self, trackKey, function()
        print( "(Custom Radio / Radio Mod) Track changed to: " .. tostring(trackKey) )
    end )

    if not changed then
        return
    end

    self.cl_playState = true
    TrackManager.updateAudioEffect( self, true )

    GuiManager.refreshPlaybackGui( self )
    GuiManager.refreshPlayIcon( self )
    GuiManager.refreshTrackProgress( self )
end

function GuiManager.cl_onPlayClick( self )
    local newState = not self.cl_playState

    if newState and not TrackManager.hasRealTrack( self ) then
        local trackKeys = GuiManager.getActiveTracks( self )
        if trackKeys and trackKeys[ 1 ] then
            GuiManager.selectTrack( self, trackKeys[ 1 ] )
        end
        return
    end

    self.cl_playState = newState
    TrackManager.updateAudioEffect( self, self.cl_playState )
    GuiManager.refreshPlayIcon( self )
end

function GuiManager.cl_onBackClick( self )
    TrackManager.changeSound( self, -1, GuiManager.getActiveTracks( self ), function( track )
        GuiManager.selectTrack( self, track )
    end )
end

function GuiManager.cl_onNextClick( self )
    TrackManager.changeSound( self, 1, GuiManager.getActiveTracks( self ), function( track )
        GuiManager.selectTrack( self, track )
    end )
end