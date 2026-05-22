CustomAntenna = class()

CustomAntenna.maxParentCount = 1
CustomAntenna.maxChildCount = 0
CustomAntenna.connectionInput = sm.interactable.connectionType.logic + (sm.interactable.connectionType.composite or 0)
CustomAntenna.colorNormal = sm.color.new("#df6d2d")
CustomAntenna.colorHighlight = sm.color.new("#c84c05")

if not fmdata then
    fmdata = {}
end

if not fmantenna then
    fmantenna = {}
end

-- ─────────────────────────────────────────────
--  HELPERS
-- ─────────────────────────────────────────────

function CustomAntenna:isConnected()
    local list = fmdata[self.cl_frequency]
    if not list then
        return false
    end

    for _, entry in pairs(list) do
        if entry and entry.track then
            return true
        end
    end

    return false
end

-- ─────────────────────────────────────────────
--  SERVER
-- ─────────────────────────────────────────────

function CustomAntenna.server_onCreate(self)
    local stored = self.storage:load() or {}
    self.sv_frequency = stored.frequency or 0
    self.storage:save({
        frequency = self.sv_frequency
    })
end

function CustomAntenna.server_onRefresh(self)
    self:server_onCreate()
end

function CustomAntenna.sv_setFrequency(self, freq)
    self.sv_frequency = math.floor(tonumber(freq) or 0)
    self.storage:save({
        frequency = self.sv_frequency
    })
    self.network:sendToClients("cl_setFrequency", self.sv_frequency)
end

function CustomAntenna.sv_requestInfo(self, _, player)
    self.network:sendToClient(player, "cl_setFrequency", self.sv_frequency)
end

-- ─────────────────────────────────────────────
--  CLIENT
-- ─────────────────────────────────────────────

function CustomAntenna.client_onCreate(self)
    self.cl_frequency = 0
    self.cl_lastFreq = nil
    self.cl_antennaId = self.interactable.id
    self.network:sendToServer("sv_requestInfo")
end

function CustomAntenna.cl_setFrequency(self, freq)
    self.cl_frequency = freq
end

function CustomAntenna.client_onFixedUpdate(self)
    local freq = self.cl_frequency
    local id = self.cl_antennaId

    fmantenna[id] = freq

    self.cl_lastFreq = freq
end

function CustomAntenna.client_onDestroy(self)
    fmantenna[self.cl_antennaId] = nil
end

function CustomAntenna.client_onInteract(self, char, lookAt)
    if not lookAt then
        return
    end

    if not sm.exists(self.gui) then
        self:cl_createGui()
    end

    self.gui:setText("FmFrequencyLabel", "FM " .. tostring(self.cl_frequency))
    self.gui:setText("StatusValue", self:isConnected() and "Broadcast Active" or "Broadcast Ready")

    self.gui:open()
end

function CustomAntenna:cl_createGui()
    self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/Antenna.layout")

    self.gui:setButtonCallback("FmFrequencyUp", "onFmFrequencyUp")
    self.gui:setButtonCallback("FmFrequencyDown", "onFmFrequencyDown")
end

function CustomAntenna:onFmFrequencyUp()
    local next = math.min(255, self.cl_frequency + 1)
    self.network:sendToServer("sv_setFrequency", next)
    self.cl_frequency = next

    if sm.exists(self.gui) then
        self.gui:setText("FmFrequencyLabel", "FM " .. tostring(self.cl_frequency))
    end
end

function CustomAntenna:onFmFrequencyDown()
    local next = math.max(0, self.cl_frequency - 1)
    self.network:sendToServer("sv_setFrequency", next)
    self.cl_frequency = next

    if sm.exists(self.gui) then
        self.gui:setText("FmFrequencyLabel", "FM " .. tostring(self.cl_frequency))
    end
end
