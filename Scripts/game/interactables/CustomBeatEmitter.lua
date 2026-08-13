dofile( "$CONTENT_DATA/Scripts/game/managers/TrackManager.lua" )

CustomBeatEmitter = class()

CustomBeatEmitter.maxParentCount = 1
CustomBeatEmitter.maxChildCount = 255
CustomBeatEmitter.poseWeightCount = 1
CustomBeatEmitter.connectionInput = sm.interactable.connectionType.logic
CustomBeatEmitter.connectionOutput = sm.interactable.connectionType.logic + sm.interactable.connectionType.power
CustomBeatEmitter.colorNormal = sm.color.new( "#df6d2d" )
CustomBeatEmitter.colorHighlight = sm.color.new( "#c84c05" )

local PULSE_ON_RATIO = 10 / 15
local PULSE_OFF_RATIO = 6 / 15
local POWER_SEND_EPSILON_FALLBACK = 1 / 30

function CustomBeatEmitter.server_onCreate( self )
    self.interactable:setActive( false )
    self.interactable:setPower( 0 )
end

function CustomBeatEmitter.server_onRefresh( self )
    self:server_onCreate()
end

function CustomBeatEmitter.sv_setActive( self, state )
    self.interactable:setActive( state )
end

function CustomBeatEmitter.sv_setPower( self, value )
    self.interactable:setPower( value )
end

function CustomBeatEmitter.client_onCreate( self )
    self.cl_currentAudio = nil
    self.cl_playState = false
    self.cl_playSpeed = 1
    self.cl_trackPosition = 0

    self.cl_beatData = nil
    self.cl_beatDataPath = nil

    self.cl_pulseActive = false
    self.cl_lastSentActive = false
    self.cl_lastSentPower = 0

    self.interactable:setPoseWeight( 0, 0 )
end

function CustomBeatEmitter.client_onFixedUpdate( self, timeStep )
    local parent = self.interactable:getSingleParent()
    if not sm.exists( parent ) then
        self:remote_radio_controller_destroy()
        return
    end

    if self.cl_playState then
        local dt = timeStep or ( 1 / 40 )
        local speed = ( self.cl_playSpeed and self.cl_playSpeed > 0 ) and self.cl_playSpeed or 1
        self.cl_trackPosition = ( self.cl_trackPosition or 0 ) + dt * 1000 * speed
    end

    self:cl_updatePower()
end

function CustomBeatEmitter.client_onDestroy( self )
    self:remote_radio_controller_destroy()
end

-- ─────────────────────────────────────────────
--  RADIO PROTOCOL
-- ─────────────────────────────────────────────

function CustomBeatEmitter.remote_radio_controller( self, params )
    local newAudio = params[ "currentAudio" ]
    local newState = params[ "currentPlayState" ]
    local newPosition = params[ "currentPosition" ] or 0
    local newBeatPath = params[ "beatData" ]

    local trackChanged = newAudio ~= self.cl_currentAudio

    self.cl_currentAudio = newAudio
    self.cl_playState = newState

    if trackChanged then
        self.cl_trackPosition = newPosition
        self:cl_setBeatDataPath( newBeatPath )
    end

    if not newState or newAudio == nil or newAudio == "" then
        self:cl_setPowerLevel( 0 )
    end
end

function CustomBeatEmitter.remote_radio_controller_seek( self, positionMs )
    self.cl_trackPosition = positionMs or 0
end

function CustomBeatEmitter.remote_radio_controller_speed( self, param )
    self.cl_playSpeed = param
end

function CustomBeatEmitter.remote_radio_controller_destroy( self )
    self.cl_currentAudio = nil
    self.cl_playState = false
    self.cl_trackPosition = 0
    self:cl_setBeatDataPath( nil )
    self:cl_setPowerLevel(0)
end

-- ─────────────────────────────────────────────
--  POWER / PULSE
-- ─────────────────────────────────────────────

function CustomBeatEmitter:cl_setBeatDataPath( path )
    if path == self.cl_beatDataPath then
        return
    end

    self.cl_beatDataPath = path
    self.cl_beatData = path and TrackManager.loadBeatData( path ) or nil
end

function CustomBeatEmitter:cl_updatePower()
    if not self.cl_playState or not self.cl_beatData then
        self:cl_setPowerLevel( 0 )
        return
    end

    local value = TrackManager.getBeatValue( self.cl_beatData, self.cl_trackPosition, "BeatData" )
    self:cl_setPowerLevel( value )
end

function CustomBeatEmitter:cl_setPowerLevel( value )
    value = value or 0

    self.interactable:setPoseWeight( 0, self.interactable.active and 1 or 0 )
    self.interactable:setUvFrameIndex( self.interactable.active and 6 or 0 )

    local levels = TrackManager.getBeatLevels( self.cl_beatData )
    local power = math.min( 1, math.max( 0, value / levels ) )

    local epsilon = math.min( POWER_SEND_EPSILON_FALLBACK, 0.5 / levels )
    if math.abs( power - self.cl_lastSentPower ) > epsilon then
        self.cl_lastSentPower = power
        self.network:sendToServer( "sv_setPower", power )
    end

    if self.cl_pulseActive then
        if value <= PULSE_OFF_RATIO * levels then
            self.cl_pulseActive = false
        end
    else
        if value >= PULSE_ON_RATIO * levels then
            self.cl_pulseActive = true
        end
    end

    if self.cl_pulseActive ~= self.cl_lastSentActive then
        self.cl_lastSentActive = self.cl_pulseActive
        self.network:sendToServer( "sv_setActive", self.cl_pulseActive )
    end
end