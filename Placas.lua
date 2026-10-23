-- Modos · Placas (1.0.8): arreglo de las placas de ElvUI 6.09 con el foco.
-- En 3.3.5 las placas no tienen unidad propia: ElvUI le pone a cada placa la
-- unidad que encuentra por el nombre (compañero, arena o foco). Al cambiar el
-- foco de un jugador a otro, ElvUI anota el nuevo pero no borra el viejo
-- (Nameplates.lua, NP:PLAYER_FOCUS_CHANGED): la placa del que era foco sigue
-- leyendo "focus" y muestra los debuffs y los casteos del foco nuevo. Pasaba en
-- arena: el paladín enemigo con los stacks de Holy Vengeance del guerrero.
-- Antes de que ElvUI anote el foco nuevo, Modos borra el viejo y vuelve a armar
-- su placa (toma su unidad de arena o de tu grupo, como cualquier otra).

local _, NS = ...

local PL = {}
NS.placas = PL

-- el nombre del foco nuevo, como lo toma ElvUI (solo jugadores que no sos vos)
local function focoNuevo()
    if UnitIsPlayer("focus") and not UnitIsUnit("focus", "player") then return UnitName("focus") end
end

function PL.enganchar()
    local E = type(ElvUI) == "table" and ElvUI[1]
    if type(E) ~= "table" or type(E.GetModule) ~= "function" then return false end
    local ok, NP = pcall(E.GetModule, E, "NamePlates", true)
    if not ok or type(NP) ~= "table" or type(NP.PLAYER_FOCUS_CHANGED) ~= "function" then return false end
    if NP.modosFoco then return true end
    local original = NP.PLAYER_FOCUS_CHANGED
    -- ElvUI registra el evento sin función propia: AceEvent busca NP.PLAYER_FOCUS_CHANGED
    -- cada vez que llega, así que alcanza con reemplazarla
    NP.PLAYER_FOCUS_CHANGED = function(self, ...)
        local viejo = type(self.NameByUnit) == "table" and self.NameByUnit.focus
        if viejo and viejo ~= focoNuevo() then
            if type(self.UnitByName) == "table" and self.UnitByName[viejo] == "focus" then
                self.UnitByName[viejo] = nil
            end
            self.NameByUnit.focus = nil
            if type(self.UpdateAllFrame) == "function" then
                for frame in pairs(self.VisiblePlates or {}) do
                    if frame.UnitName == viejo then pcall(self.UpdateAllFrame, self, frame, nil, true) end
                end
            end
        end
        return original(self, ...)
    end
    NP.modosFoco = true
    return true
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function() pcall(PL.enganchar) end)
