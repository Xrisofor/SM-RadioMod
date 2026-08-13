dofile( "$CONTENT_DATA/Scripts/game/managers/TrackManager.lua" )

CustomRadioSpeaker = class()

CustomRadioSpeaker.maxParentCount = 1
CustomRadioSpeaker.poseWeightCount = 1
CustomRadioSpeaker.connectionInput = sm.interactable.connectionType.logic
CustomRadioSpeaker.colorNormal = sm.color.new( "#df6d2d" )
CustomRadioSpeaker.colorHighlight = sm.color.new( "#c84c05" )

local DRIFT_THRESHOLD_MS = 500

function CustomRadioSpeaker.client_onCreate( self )
    self.cl_currentAudio = nil
    self.cl_playState = false
    self.cl_playSpeed = 1
    self.cl_audio_effect = nil
    self.cl_trackPosition = 0
end

function CustomRadioSpeaker.client_onFixedUpdate( self, timeStep )
    local parent = self.interactable:getSingleParent()
    if not sm.exists( parent ) then
        self:remote_radio_controller_destroy()
        return
    end

    if self.cl_playState and TrackManager.isValidEffect( self ) then
        local dt = timeStep or ( 1 / 40 )
        local speed = ( self.cl_playSpeed and self.cl_playSpeed > 0 ) and self.cl_playSpeed or 1
        self.cl_trackPosition = ( self.cl_trackPosition or 0 ) + dt * 1000 * speed
    end
end

function CustomRadioSpeaker.remote_radio_controller( self, params )
    local newAudio = params[ "currentAudio"]
    local newState = params[ "currentPlayState" ]
    local newPosition = params[ "currentPosition" ] or 0

    local trackChanged = newAudio ~= self.cl_currentAudio
    local wasPlaying = TrackManager.isValidEffect( self ) and self.cl_audio_effect:isPlaying()

    if trackChanged then
        TrackManager.destroyEffect( self )
        self.cl_trackPosition = newPosition
    end

    self.cl_currentAudio = newAudio
    self.cl_playState = newState

    local isRealTrack = newAudio ~= nil and newAudio ~= ""

    if newState and isRealTrack then
        if not TrackManager.isValidEffect( self ) then
            TrackManager.createEffect( self, newAudio )
            self.cl_audio_effect:setParameter( "CAE_Position", (self.cl_trackPosition or 0) / 1000.0 )
        end
        if not self.cl_audio_effect:isPlaying() then
            self.cl_audio_effect:start()
            self.interactable:setPoseWeight( 0, 1 )

            if not wasPlaying then
                self.cl_trackPosition = newPosition
                self.cl_audio_effect:setParameter( "CAE_Position", self.cl_trackPosition / 1000.0 )
            end
        elseif not trackChanged then
            local drift = math.abs( ( self.cl_trackPosition or 0 ) - newPosition )
            if drift > DRIFT_THRESHOLD_MS then
                self.cl_trackPosition = newPosition
                self.cl_audio_effect:setParameter( "CAE_Position", self.cl_trackPosition / 1000.0 )
            end
        end
    else
        if TrackManager.isValidEffect( self ) and self.cl_audio_effect:isPlaying() then
            self.cl_audio_effect:stop()
        end
        self.interactable:setPoseWeight( 0, 0 )
    end
end

function CustomRadioSpeaker.remote_radio_controller_seek( self, positionMs )
    self.cl_trackPosition = positionMs or 0
    if TrackManager.isValidEffect( self ) then
        self.cl_audio_effect:setParameter( "CAE_Position", self.cl_trackPosition / 1000.0 )
    end
end

function CustomRadioSpeaker.remote_radio_controller_speed( self, param )
    self.cl_playSpeed = param
    if TrackManager.isValidEffect( self ) then
        self.cl_audio_effect:setParameter( "CAE_Pitch", param > 0 and param or 0.5 )
    end
end

function CustomRadioSpeaker.remote_radio_controller_destroy( self )
    TrackManager.destroyEffect( self )
    self.cl_currentAudio = nil
    self.cl_trackPosition = 0
    self.interactable:setPoseWeight( 0, 0 )
end
