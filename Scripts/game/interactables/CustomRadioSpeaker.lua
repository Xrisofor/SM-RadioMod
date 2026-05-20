CustomRadioSpeaker = class()

CustomRadioSpeaker.maxParentCount = 1
CustomRadioSpeaker.poseWeightCount = 1
CustomRadioSpeaker.connectionInput = sm.interactable.connectionType.logic
CustomRadioSpeaker.colorNormal = sm.color.new("#df6d2d")
CustomRadioSpeaker.colorHighlight = sm.color.new("#c84c05")

local function effectExists(e)
    return e ~= nil and sm.exists(e)
end

function CustomRadioSpeaker.client_onCreate(self)
    self.cl_currentAudioName = nil
    self.cl_currentAudioVolume = 1
    self.cl_playState = false
    self.cl_playSpeed = 1
    self.cl_audio_effect = nil
end

function CustomRadioSpeaker.client_onFixedUpdate(self)
    local parent = self.interactable:getSingleParent()
    if not sm.exists(parent) then
        self:remote_radio_controller_destroy()
    end
end

function CustomRadioSpeaker.remote_radio_controller(self, params)
    local newName = params["currentAudioName"]
    local newVolume = params["currentAudioVolume"]
    local newState = params["currentPlayState"]

    if newName ~= self.cl_currentAudioName then
        if effectExists(self.cl_audio_effect) then
            if self.cl_audio_effect:isPlaying() then
                self.cl_audio_effect:stop()
            end
            self.cl_audio_effect:destroy()
        end
        self.cl_audio_effect = nil
    end

    self.cl_currentAudioName = newName
    self.cl_currentAudioVolume = newVolume
    self.cl_playState = newState

    local isRealTrack = newName ~= nil and newName ~= ""

    if newState and isRealTrack then
        if not effectExists(self.cl_audio_effect) then
            self.cl_audio_effect = sm.effect.createEffect(newName, self.interactable)
            self.cl_audio_effect:setParameter("CAE_Volume", newVolume / 10.0)
        end
        if not self.cl_audio_effect:isPlaying() then
            self.cl_audio_effect:start()
            self.interactable:setPoseWeight(0, 1)
        end
    else
        if effectExists(self.cl_audio_effect) and self.cl_audio_effect:isPlaying() then
            self.cl_audio_effect:stop()
        end
        self.interactable:setPoseWeight(0, 0)
    end
end

function CustomRadioSpeaker.remote_radio_controller_volume(self, param)
    self.cl_currentAudioVolume = param
    if effectExists(self.cl_audio_effect) then
        self.cl_audio_effect:setParameter("CAE_Volume", param / 10.0)
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
    self.interactable:setPoseWeight(0, 0)
end
