CustomAudio = class()

local modUUID = sm.json.open("$CONTENT_DATA/description.json").localId

sm.radioMod = sm.radioMod or {}
sm.radioMod.tracks = sm.radioMod.tracks or {}
sm.radioMod.playlists = sm.radioMod.playlists or {}

local myTracks = {
    {
        Name = "Effect Name", -- The name of the effect to play
        ModUUID = modUUID, -- The UUID of the mod that contains the effect
        TrackInfo = {
            Name = "Track Name", -- The name of the track to display in the radio
            Author = "Track Author", -- The author of the track
            Image = "Gui/Icons/default_image.png", -- The image to display for the track
            Duration = 24 -- Appear in future updates
        }
    },
}
for _, track in ipairs(myTracks) do
    table.insert(sm.radioMod.tracks, track)
end

sm.radioMod.playlists["Playlist Name"] = {
    Tracks = { -- List of tracks to play in the playlist
        "Effect Name", -- The name of the effect to play
    },
    Name = "Playlist Name", -- The name of the playlist to display in the radio
    Author = "Playlist Author", -- The author of the playlist
    Image = "Gui/Icons/default_image.png", -- The image to display for the playlist
    ModUUID = modUUID -- The UUID of the mod that contains the playlist
}