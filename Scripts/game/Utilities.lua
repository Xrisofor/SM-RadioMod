MAIN_LAYOUT = "$CONTENT_DATA/Gui/Layouts/Scrapify.layout"
TRACK_ITEM_LAYOUT = "$CONTENT_DATA/Gui/Layouts/TrackItem.layout"

PLAY_ICON = "$CONTENT_DATA/Gui/Layouts/play-circle.png"
STOP_ICON = "$CONTENT_DATA/Gui/Layouts/stop-circle.png"

VOLUME_ON_ICON = "$CONTENT_DATA/Gui/Layouts/volume-up.png"
VOLUME_OFF_ICON = "$CONTENT_DATA/Gui/Layouts/volume-off.png"

function checkCAE()
    if sm.cae_injected == nil then
        sm.gui.chatMessage( "(Radio Mod) You have not installed " .. "#ff0000SM-CustomAudioExtension#ffffff, " .. "all music will not be played until you install the library!" )
    end
end

function getModUUID()
    return sm.json.open("$CONTENT_DATA/description.json").localId
end

function getContentPath()
    return "$CONTENT_" .. getModUUID()
end