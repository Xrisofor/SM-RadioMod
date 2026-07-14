CustomRadioSpeaker = class()

CustomRadioSpeaker.maxParentCount = 1
CustomRadioSpeaker.poseWeightCount = 1
CustomRadioSpeaker.connectionInput = sm.interactable.connectionType.logic
CustomRadioSpeaker.colorNormal = sm.color.new("#df6d2d")
CustomRadioSpeaker.colorHighlight = sm.color.new("#c84c05")

local DRIFT_THRESHOLD_MS = 500

local function effectExists(e)
    return e ~= nil and sm.exists(e)
end

function CustomRadioSpeaker.client_onCreate(self)
    self.cl_currentAudioName = nil
    self.cl_currentAudioVolume = 1
    self.cl_playState = false
    self.cl_playSpeed = 1
    self.cl_audio_effect = nil
    self.cl_trackPosition = 0
end

function CustomRadioSpeaker.client_onFixedUpdate(self, timeStep)
    local parent = self.interactable:getSingleParent()
    if not sm.exists(parent) then
        self:remote_radio_controller_destroy()
        return
    end

    if self.cl_playState and effectExists(self.cl_audio_effect) then
        local dt = timeStep or (1 / 40)
        local speed = (self.cl_playSpeed and self.cl_playSpeed > 0) and self.cl_playSpeed or 1
        self.cl_trackPosition = (self.cl_trackPosition or 0) + dt * 1000 * speed
    end
end

function CustomRadioSpeaker.remote_radio_controller(self, params)
    local newName = params["currentAudioName"]
    local newVolume = params["currentAudioVolume"]
    local newState = params["currentPlayState"]
    local newPosition = params["currentPosition"] or 0

    local trackChanged = newName ~= self.cl_currentAudioName
    local wasPlaying = effectExists(self.cl_audio_effect) and self.cl_audio_effect:isPlaying()

    if trackChanged then
        if effectExists(self.cl_audio_effect) then
            if self.cl_audio_effect:isPlaying() then
                self.cl_audio_effect:stop()
            end
            self.cl_audio_effect:destroy()
        end
        self.cl_audio_effect = nil
        self.cl_trackPosition = newPosition
    end

    self.cl_currentAudioName = newName
    self.cl_currentAudioVolume = newVolume
    self.cl_playState = newState

    local isRealTrack = newName ~= nil and newName ~= ""

    if newState and isRealTrack then
        if not effectExists(self.cl_audio_effect) then
            self.cl_audio_effect = sm.effect.createEffect(newName, self.interactable)
            self.cl_audio_effect:setParameter("CAE_Volume", newVolume / 10.0)
            self.cl_audio_effect:setParameter("CAE_Position", (self.cl_trackPosition or 0) / 1000.0)
        end
        if not self.cl_audio_effect:isPlaying() then
            self.cl_audio_effect:start()
            self.interactable:setPoseWeight(0, 1)

            if not wasPlaying then
                self.cl_trackPosition = newPosition
                self.cl_audio_effect:setParameter("CAE_Position", self.cl_trackPosition / 1000.0)
            end
        elseif not trackChanged then
            local drift = math.abs((self.cl_trackPosition or 0) - newPosition)
            if drift > DRIFT_THRESHOLD_MS then
                self.cl_trackPosition = newPosition
                self.cl_audio_effect:setParameter("CAE_Position", self.cl_trackPosition / 1000.0)
            end
        end
    else
        if effectExists(self.cl_audio_effect) and self.cl_audio_effect:isPlaying() then
            self.cl_audio_effect:stop()
        end
        self.interactable:setPoseWeight(0, 0)
    end
end

function CustomRadioSpeaker.remote_radio_controller_seek(self, positionMs)
    self.cl_trackPosition = positionMs or 0
    if effectExists(self.cl_audio_effect) then
        self.cl_audio_effect:setParameter("CAE_Position", self.cl_trackPosition / 1000.0)
    end
end

function CustomRadioSpeaker.remote_radio_controller_volume(self, param)
    self.cl_currentAudioVolume = param
    if effectExists(self.cl_audio_effect) then
        self.cl_audio_effect:setParameter("CAE_Volume", param / 10.0)
        self.cl_audio_effect:setParameter("CAE_Position", (self.cl_trackPosition or 0) / 1000.0)
    end
end

function CustomRadioSpeaker.remote_radio_controller_speed(self, param)
    self.cl_playSpeed = param
    if effectExists(self.cl_audio_effect) then
        self.cl_audio_effect:setParameter("CAE_Pitch", param > 0 and param or 0.5)
    end
end

function CustomRadioSpeaker.remote_radio_controller_destroy(self)
    if effectExists(self.cl_audio_effect) then
        if self.cl_audio_effect:isPlaying() then
            self.cl_audio_effect:stop()
        end
        self.cl_audio_effect:destroy()
    end
    self.cl_audio_effect = nil
    self.cl_currentAudioName = nil
    self.cl_currentAudioVolume = 1
    self.cl_trackPosition = 0
    self.interactable:setPoseWeight(0, 0)
end