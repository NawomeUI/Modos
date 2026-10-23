-- Modos · Aspecto: el minimapa y los marcos como en Bypass, sin FriskesUI.
-- Copia lo que hacía FriskesUI (TexturesColor e ImprovedMaps, con las opciones
-- que tenía Bypass: texturescolor1 y texturescolor2):
--   * bordes de Blizzard oscuros (0,3): minimapa, reloj, calendario, marcos de
--     jugador, objetivo, foco, grupo y barras de casteo
--   * bordes de los botones de acción oscuros (0,4)
--   * minimapa sin los botones + y -, zoom con la rueda del mouse, nombre de quien
--     hace ping, y el número del calendario en blanco
-- Además deja los botones del minimapa (calendario, BG, correo, LFG, dificultad)
-- donde los pone Blizzard: ElvUI los mueve aunque tenga su minimapa apagado.
-- Se apaga con /modos oscuro (toma efecto al recargar).
-- Las barras de Blizzard (sin Bartender) las arregla Barras.lua.

local _, NS = ...

local A = {}
NS.aspecto = A

-- (0.9.5) ElvUI recién instalado (WTF limpia o un usuario nuevo): sin su
-- instalador, sin sus consejos y sin el cartel de "addon incompatible" por
-- Mapster. La UI la arma Modos. ElvUI carga antes que Modos y arma todo en
-- PLAYER_LOGIN: acá ya están sus ajustes y todavía no los usó.
function A.prepararElvUI()
    local E1 = ElvUI and ElvUI[1]
    if not (E1 and type(E1.private) == "table" and type(E1.db) == "table") then return false end
    if not E1.private.install_complete then E1.private.install_complete = E1.version or "6.09" end
    E1.db.hideTutorial = true
    local wm = E1.private.worldmap
    if type(wm) == "table" and wm.enable and E1.IsAddOnEnabled and E1:IsAddOnEnabled("Mapster") then wm.enable = false end
    return true
end
A.prepararElvUI()

local OSCURO, BOTONES = 0.3, 0.4

function A.prendido()
    return not (ModosDB and ModosDB.aspecto and ModosDB.aspecto.apagado)
end

-- ------------------------------------------------------------ botones del minimapa
-- el lugar de Blizzard se anota al cargar Modos: ElvUI los mueve recién al entrar
local BOTONES_MM = { "GameTimeFrame", "MiniMapBattlefieldFrame", "MiniMapLFGFrame", "MiniMapMailFrame",
                     "MiniMapInstanceDifficulty" }
local original = {}
local function anotar()
    for _, n in ipairs(BOTONES_MM) do
        local f = _G[n]
        if f and f.GetNumPoints and not original[n] then
            local pts = {}
            for i = 1, f:GetNumPoints() do pts[i] = { f:GetPoint(i) } end
            original[n] = { puntos = pts, escala = f.GetScale and f:GetScale() or 1 }
        end
    end
end
anotar()
A.original = original
A.anotar = anotar

function A.ponerBotones()
    if not A.prendido() then return end
    for n, o in pairs(original) do
        local f = _G[n]
        if f and #o.puntos > 0 then
            pcall(function()
                f:ClearAllPoints()
                for _, p in ipairs(o.puntos) do f:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
                if f.SetScale then f:SetScale(o.escala or 1) end
            end)
        end
    end
    if GameTimeFrame and GameTimeFrame.Show then GameTimeFrame:Show() end
end

-- ------------------------------------------------------------ texturas oscuras
local function oscurecer(t, v)
    if t and t.SetVertexColor then t:SetVertexColor(v, v, v, 1) end
end

local NOMBRES = {
    "MinimapBorder", "MiniMapTrackingButtonBorder", "MiniMapLFGFrameBorder", "MiniMapBattlefieldBorder",
    "MiniMapMailBorder", "MinimapBorderTop", "MiniMapWorldBorder",
    "PlayerFrameVehicleTexture", "TargetFrameTextureFrameTexture", "FocusFrameTextureFrameTexture", "PetFrameTexture",
    "PartyMemberFrame1Texture", "PartyMemberFrame2Texture", "PartyMemberFrame3Texture", "PartyMemberFrame4Texture",
    "PartyMemberFrame1PetFrameTexture", "PartyMemberFrame2PetFrameTexture", "PartyMemberFrame3PetFrameTexture",
    "PartyMemberFrame4PetFrameTexture", "TargetFrameToTTextureFrameTexture", "FocusFrameToTTextureFrameTexture",
    "CastingBarFrameBorder", "TargetFrameSpellBarBorder", "FocusFrameSpellBarBorder",
    "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap", "ShapeshiftBarLeft", "ShapeshiftBarMiddle", "ShapeshiftBarRight",
}
local hecho = false
function A.oscurecer()
    if hecho or not A.prendido() then return end
    hecho = true
    for _, n in ipairs(NOMBRES) do oscurecer(_G[n], OSCURO) end
    if TimeManagerClockButton and TimeManagerClockButton.GetRegions then
        oscurecer((select(1, TimeManagerClockButton:GetRegions())), OSCURO)
    end
    if GameTimeFrame and GameTimeFrame.GetRegions then
        oscurecer((select(6, GameTimeFrame:GetRegions())), OSCURO)
    end
    if MinimapZoomIn then MinimapZoomIn:Hide() end
    if MinimapZoomOut then MinimapZoomOut:Hide() end
end

-- el número del calendario en blanco
local function fechaBlanca()
    if not (A.prendido() and GameTimeFrame and CalendarGetDate) then return end
    local _, _, dia = CalendarGetDate()
    if dia then GameTimeFrame:SetText(("|cffffffff%d|r"):format(dia)) end
end

-- bordes de los botones de acción
local function bordeBoton(self)
    if not A.prendido() or not (self and self.GetName and self:GetName()) then return end
    local t = _G[self:GetName() .. "NormalTexture"]
    if t and t.SetGradientAlpha then
        t:SetGradientAlpha("VERTICAL", BOTONES, BOTONES, BOTONES, 1, BOTONES, BOTONES, BOTONES, 1)
    end
end

-- ------------------------------------------------------------ minimapa
local function minimapa()
    if not (A.prendido() and Minimap) then return end
    -- zoom con la rueda
    if Minimap.EnableMouseWheel then
        Minimap:EnableMouseWheel(true)
        Minimap:SetScript("OnMouseWheel", function(_, delta)
            if delta > 0 then Minimap_ZoomIn() else Minimap_ZoomOut() end
        end)
    end
    -- nombre (con color de clase) de quien hace ping
    if MinimapPing and MinimapPing.HookScript and CreateFrame then
        local tip = CreateFrame("GameTooltip", "ModosPingTip", MinimapPing, "GameTooltipTemplate")
        MinimapPing:HookScript("OnEvent", function(_, event, unit)
            if event ~= "MINIMAP_PING" or not unit then return end
            local _, clase = UnitClass(unit)
            local c = clase and RAID_CLASS_COLORS and RAID_CLASS_COLORS[clase]
            tip:SetOwner(MinimapPing, "ANCHOR_BOTTOM", 0, 15)
            if c then tip:SetText(UnitName(unit), c.r, c.g, c.b) else tip:SetText(UnitName(unit)) end
            tip:Show()
        end)
    end
end

-- ------------------------------------------------------------ chat
-- (0.9.2) el chat de Blizzard como en PvP: abajo a la izquierda, sin encimarse
-- con las barras de abajo al centro. Una sola vez por personaje (después, si lo
-- movés o lo agrandás, queda como lo dejes). Con el chat de ElvUI no se toca.
A.CHAT = { x = 35, y = 83, ancho = 395, alto = 117, version = 1 }
function A.ponerChat()
    local pj, cf = NS.pj, _G.ChatFrame1
    if not (pj and cf and cf.SetPoint) or pj.chat == A.CHAT.version then return false end
    local E1 = ElvUI and ElvUI[1]
    if E1 and E1.private and E1.private.chat and E1.private.chat.enable then return false end
    cf:ClearAllPoints()
    cf:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", A.CHAT.x, A.CHAT.y)
    cf:SetWidth(A.CHAT.ancho)
    cf:SetHeight(A.CHAT.alto)
    if cf.SetUserPlaced then cf:SetUserPlaced(true) end
    if FCF_SavePositionAndDimensions then pcall(FCF_SavePositionAndDimensions, cf) end
    pj.chat = A.CHAT.version
    return true
end

-- ------------------------------------------------------------ escala
-- (0.9.4) la escala de la interfaz que usa todo Modos: 1080 unidades de alto
-- (0,711, la de fábrica de ElvUI). Si alguien la cambió (por ejemplo con "Auto
-- Scale" del instalador de ElvUI en un monitor 1440p), las posiciones no
-- coinciden: Modos la vuelve a poner y pide recargar. /modos escala la deja libre.
function A.escalaLibre() return ModosDB and ModosDB.escalaLibre and true or false end
local function igual(a, b) return math.abs((tonumber(a) or 0) - b) < 0.0005 end
function A.ponerEscala()
    if A.escalaLibre() then return false end
    local v = NS.presets and NS.presets.ESCALA or 768 / 1080
    local E1 = ElvUI and ElvUI[1]
    if E1 and E1.global and E1.global.general then
        local g = E1.global.general
        if igual(g.UIScale, v) then return false end
        g.UIScale = v
        return true                      -- ElvUI la pone al cargar: hay que recargar
    end
    -- sin ElvUI, la del juego (se aplica en el momento)
    if GetCVar and SetCVar and not (GetCVar("useUiScale") == "1" and igual(GetCVar("uiScale"), v)) then
        SetCVar("useUiScale", "1")
        SetCVar("uiScale", tostring(v))
    end
    return false
end
local function avisarEscala()
    if not A.ponerEscala() then return end
    NS.decir("Puse la escala de la interfaz de Modos (1080 de alto) para que todo quede en su lugar. Hay que recargar. Para elegir otra: /modos escala.")
    if StaticPopupDialogs and StaticPopup_Show then
        NS.recargando = true
        StaticPopupDialogs["MODOS_RECARGAR_ESCALA"] = StaticPopupDialogs["MODOS_RECARGAR_ESCALA"] or {
            text = "Modos: ajusté la escala de la interfaz para que todo quede en su lugar. Hay que recargar.",
            button1 = "Recargar",
            OnAccept = function() ReloadUI() end,
            timeout = 0, whileDead = 1, hideOnEscape = false, showAlert = 1,
        }
        if NS.pedirRecarga then NS.pedirRecarga("MODOS_RECARGAR_ESCALA") else StaticPopup_Show("MODOS_RECARGAR_ESCALA") end
    end
end
A.avisarEscala = avisarEscala
function A.alternarEscala()
    ModosDB.escalaLibre = not ModosDB.escalaLibre or nil
    if not ModosDB.escalaLibre then avisarEscala() end
    return not ModosDB.escalaLibre
end

-- ------------------------------------------------------------ arranque
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
local enganchado = false
ev:SetScript("OnEvent", function(_, event, nombre)
    if event == "PLAYER_ENTERING_WORLD" then
        A.ponerChat()
        if not A.escalaVista then A.escalaVista = true; avisarEscala() end
    end
    if not A.prendido() then return end
    if event == "ADDON_LOADED" and nombre == "Blizzard_TimeManager" then
        A.oscurecer()
    elseif event == "PLAYER_LOGIN" then
        minimapa()
        if hooksecurefunc then
            if ActionButton_Update then hooksecurefunc("ActionButton_Update", bordeBoton) end
            if ActionButton_UpdateUsable then hooksecurefunc("ActionButton_UpdateUsable", bordeBoton) end
            if ActionButton_ShowGrid then hooksecurefunc("ActionButton_ShowGrid", bordeBoton) end
            if GameTimeFrame_SetDate then hooksecurefunc("GameTimeFrame_SetDate", fechaBlanca) end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if IsAddOnLoaded and IsAddOnLoaded("Blizzard_TimeManager") then A.oscurecer() end
        fechaBlanca()
        A.ponerBotones()
        -- cada vez que ElvUI vuelve a acomodar el minimapa, se vuelven a poner
        if not enganchado and hooksecurefunc and ElvUI and ElvUI[1] and ElvUI[1].GetModule then
            local ok, M = pcall(ElvUI[1].GetModule, ElvUI[1], "Minimap", true)
            if ok and M and M.UpdateSettings then
                hooksecurefunc(M, "UpdateSettings", A.ponerBotones)
                enganchado = true
            end
        end
    end
end)

function A.alternar()
    ModosDB.aspecto = ModosDB.aspecto or {}
    ModosDB.aspecto.apagado = not ModosDB.aspecto.apagado or nil
    return A.prendido()
end
