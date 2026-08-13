dofile( "$CONTENT_DATA/Scripts/game/managers/GuiManager.lua" )
dofile( "$CONTENT_DATA/Scripts/game/managers/TrackManager.lua" )
dofile( "$CONTENT_DATA/Scripts/game/Utilities.lua" )

GuiTest = class()

function GuiTest.server_onCreate(self)
    TrackManager.sv_onCreate(self)
end

function GuiTest.client_onCreate(self)
    TrackManager.cl_onCreate(self)
    GuiManager.cl_onCreate(self)
end

function GuiTest.client_onInteract(self, char, state)
    GuiManager.cl_onInteract(self, char, state)
end

function GuiTest.client_onUpdate( self, dt )
    GuiManager.cl_onUpdate(self, dt)
end

function GuiTest.client_onDestroy(self)
    GuiManager.cl_onDestroy(self)
end

function GuiTest.cl_onClose( self )
    GuiManager.cl_onClose(self)
end

function GuiTest.cl_onTrackScroll( self, _, scrollValue )
    GuiManager.cl_onTrackScroll( self, _, scrollValue )
end

function GuiTest.cl_onPlaylistScroll( self, _, scrollValue )
    GuiManager.cl_onPlaylistScroll( self, _, scrollValue )
end

function GuiTest.cl_onTrackScrollButtonPressed( self, _, x, y )
    GuiManager.cl_onTrackScrollButtonPressed( self, _, x, y )
end

function GuiTest.cl_onPlaylistScrollButtonPressed( self, _, x, y )
    GuiManager.cl_onPlaylistScrollButtonPressed( self, _, x, y )
end

function GuiTest.cl_onTrackScrollButtonReleased( self, _, x, y )
    GuiManager.cl_onTrackScrollButtonReleased( self, _, x, y )
end

function GuiTest.cl_onPlaylistScrollButtonReleased( self, _, x, y )
    GuiManager.cl_onPlaylistScrollButtonReleased( self, _, x, y )
end

function GuiTest.cl_onTrackScrollButtonDrag( self, _, x, y )
    GuiManager.cl_onTrackScrollButtonDrag( self, _, x, y )
end

function GuiTest.cl_onPlaylistScrollButtonDrag( self, _, x, y )
    GuiManager.cl_onPlaylistScrollButtonDrag( self, _, x, y )
end

function GuiTest.cl_onTrackScrollBarPressed( self, _, x, y )
    GuiManager.cl_onTrackScrollBarPressed( self, _, x, y ) 
end

function GuiTest.cl_onPlaylistScrollBarPressed( self, _, x, y )
    GuiManager.cl_onPlaylistScrollBarPressed( self, _, x, y )
end

function GuiTest.cl_onSearchTextEdit( self, name, text )
    GuiManager.cl_onSearchTextEdit( self, name, text )
end

function GuiTest.cl_onSearchTextEnter( self, name, text )
    GuiManager.cl_onSearchTextEnter( self, name, text )
end

function GuiTest.cl_onTrackClick( self, name )
    GuiManager.cl_onTrackClick( self, name )
end

function GuiTest.cl_onPlaylistClick( self, name )
    GuiManager.cl_onPlaylistClick( self, name )
end

function GuiTest.cl_onPlayClick( self, _ )
    GuiManager.cl_onPlayClick( self )
end

function GuiTest.cl_onBackClick( self, _ )
    GuiManager.cl_onBackClick( self )
end

function GuiTest.cl_onNextClick( self, _ )
    GuiManager.cl_onNextClick( self )
end
