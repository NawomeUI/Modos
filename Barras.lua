-- Modos · Barras (12/10): con o sin Bartender, y a la vista o escondidas.
--
-- Cada personaje elige una vez (y cambia cuando quiere con /modos barras):
--   * Bartender o barras de Blizzard (Bartender se prende o apaga en ese personaje).
--   * A la vista: 4 barras abajo al centro (dos filas de dos) y 2 columnas a la
--     derecha, todo visible. En PvE Mis CDs no se muestra (las barras ya tienen los CDs).
--   * Escondidas: las barras no se ven (los binds andan igual) y abajo al centro
--     va Mis CDs, con los hechizos que elijas (/modos cds).
-- Con Bartender, cada forma es una UI armada distinta (Presets.lua). Con las de
-- Blizzard, Modos las arregla al entrar:
--   * sin los grifos, el marco de fondo ni las flechitas de cambiar de barra;
--   * menú y bolsas abajo a la derecha, un 10% más chicos;
--   * una barra más (la página 2, casilleros 13 a 24) en el hueco que queda al
--     lado de la principal, con binds propios (Key Bindings, "Modos: barra de más");
--   * las 4 barras de más de Blizzard prendidas (abajo a la izquierda y a la
--     derecha, y las dos del costado);
--   * escondidas: las de abajo invisibles y sin mouse, las del costado aparecen
--     con el mouse encima;
--   * en PvE: posturas/formas, mascota y totems abajo, cerca de las barras (como con
--     Bartender, 1.0.13): a la vista, posturas y totems arriba de la barra de arriba a
--     la izquierda y la mascota arriba de la de la derecha; escondidas, a los costados
--     de Mis CDs. Nunca arriba del chat (quedaban colgadas);
--   * la barra de experiencia y la de reputación arriba de todo (0.9.7).

local _, NS = ...
local E = NS.E

local B = {}
NS.barras = B

-- los binds de la barra de más, en Key Bindings
BINDING_HEADER_MODOSBARRA = "Modos: barra de más (sin Bartender)"
for i = 1, 12 do _G["BINDING_NAME_CLICK ModosBarraExtraBoton" .. i .. ":LeftButton"] = "Barra de más, botón " .. i end

B.ESCALA_MENU = 0.9
B.MENU = { "BOTTOMRIGHT", -455, 2 }         -- el botón de personaje (los demás van al lado)
B.BOLSAS = { "BOTTOMRIGHT", -10, 6 }        -- la mochila (las otras bolsas a su izquierda)
-- PvE: esquina de abajo a la izquierda de cada barra chica, en unidades de pantalla
-- (1.0.13) x: borde izquierdo de cada barra desde el medio de abajo; abajo: su
-- borde de abajo (los mismos lugares que con Bartender: arriba en 116, a escala 0,8)
-- La de la mascota de Blizzard es más ancha (10 de 30 con 8 de separación): a la
-- vista termina en el borde derecho de la barra de arriba (448,4); escondidas, más
-- chica para no llegar a Details.
B.APARTE = { escala = 0.8, abajo = 92,
             visibles = { postura = -463.6, totems = -463.6, mascota = 144, escalaMascota = 0.8 },
             escondidas = { postura = -480, totems = -480, mascota = 262, escalaMascota = 0.6 } }
local ARTE = { "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap", "MainMenuBarTexture0", "MainMenuBarTexture1",
               "MainMenuBarTexture2", "MainMenuBarTexture3", "MainMenuMaxLevelBar0", "MainMenuMaxLevelBar1",
               "MainMenuMaxLevelBar2", "MainMenuMaxLevelBar3", "ShapeshiftBarLeft", "ShapeshiftBarMiddle",
               "ShapeshiftBarRight", "SlidingActionBarTexture0", "SlidingActionBarTexture1",
               "BonusActionBarTexture0", "BonusActionBarTexture1" }
local FLECHAS = { "ActionBarUpButton", "ActionBarDownButton", "MainMenuBarPageNumber" }
local MENU = { "CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton", "AchievementMicroButton",
               "QuestLogMicroButton", "SocialsMicroButton", "PVPMicroButton", "LFDMicroButton",
               "MainMenuMicroButton", "HelpMicroButton" }
local BOLSAS = { "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot",
                 "CharacterBag3Slot", "KeyRingButton" }

-- ------------------------------------------------------------ qué eligió
function B.estilo() return NS.pj and NS.pj.barras end          -- "bartender" o "blizzard"
-- a la vista o escondidas. Los que eligieron antes de que existiera: Bartender
-- escondidas, Blizzard a la vista (como estaban).
function B.vista()
    local pj = NS.pj
    if not pj then return nil end
    if pj.barrasVista then return pj.barrasVista end
    if pj.barras == "bartender" then return "escondidas" end
    if pj.barras == "blizzard" then return "visibles" end
    return nil
end
function B.visibles() return B.vista() == "visibles" end
function ModosBarrasVisibles() return B.visibles() end

function B.sinBartender()
    return B.estilo() == "blizzard" and not (IsAddOnLoaded and IsAddOnLoaded("Bartender4"))
end

local function enPvE() return ModosModoActivo and ModosModoActivo() == "PvE" or false end

-- en combate los marcos de las barras no se pueden tocar: se hace todo al salir
local function hacerAlCombate(fn)
    if InCombatLockdown and InCombatLockdown() then B.pendiente = true; return false end
    fn()
    return true
end

-- ------------------------------------------------------------ menú y bolsas
local function ponerMenu()
    if not (B.sinBartender() and _G.CharacterMicroButton and _G.MainMenuBarBackpackButton) then return end
    -- en un vehículo el menú lo maneja el juego
    if VehicleMenuBar and VehicleMenuBar.IsShown and VehicleMenuBar:IsShown() then return end
    local e = B.ESCALA_MENU
    for _, n in ipairs(MENU) do if _G[n] and _G[n].SetScale then _G[n]:SetScale(e) end end
    for _, n in ipairs(BOLSAS) do if _G[n] and _G[n].SetScale then _G[n]:SetScale(e) end end
    CharacterMicroButton:ClearAllPoints()
    CharacterMicroButton:SetPoint("BOTTOMLEFT", UIParent, B.MENU[1], B.MENU[2] / e, B.MENU[3] / e)
    MainMenuBarBackpackButton:ClearAllPoints()
    MainMenuBarBackpackButton:SetPoint(B.BOLSAS[1], UIParent, B.BOLSAS[1], B.BOLSAS[2] / e, B.BOLSAS[3] / e)
end
B.ponerMenu = ponerMenu

-- ------------------------------------------------------------ la barra de más (página 2)
B.EXTRA = 12
local extra
function B.crearExtra()
    if extra or not (CreateFrame and _G.MainMenuBar and _G.ActionButton12) then return extra end
    if InCombatLockdown and InCombatLockdown() then B.pendiente = true; return nil end
    -- hija de la barra principal: se esconde con ella (por ejemplo en un vehículo)
    local f = CreateFrame("Frame", "ModosBarraExtra", MainMenuBar)
    f.botones = {}
    for i = 1, B.EXTRA do
        local b = CreateFrame("CheckButton", "ModosBarraExtraBoton" .. i, f, "ActionBarButtonTemplate")
        b:SetAttribute("action", 12 + i)
        b.modosExtra = true
        if ActionButton_UpdateAction then pcall(ActionButton_UpdateAction, b) end
        f.botones[i] = b
    end
    -- la tecla de cada botón (la del juego busca ACTIONBUTTON0)
    if hooksecurefunc and ActionButton_UpdateHotkeys then
        hooksecurefunc("ActionButton_UpdateHotkeys", function(self)
            if not (self and self.modosExtra) then return end
            local hk = _G[self:GetName() .. "HotKey"]
            local k = GetBindingKey and GetBindingKey("CLICK " .. self:GetName() .. ":LeftButton")
            if hk then
                if k then
                    hk:SetText(GetBindingText and GetBindingText(k, "KEY_", 1) or k)
                    hk:Show()
                else
                    hk:Hide()
                end
            end
        end)
        for _, b in ipairs(f.botones) do pcall(ActionButton_UpdateHotkeys, b, b.buttonType) end
    end
    extra = f
    return f
end

-- en el hueco al lado de la principal, alineada con la de abajo a la derecha.
-- Siempre está (escondida es invisible y sin mouse): así sus binds andan igual.
function B.ponerExtra()
    local f = B.crearExtra()
    if not f then return false end
    return hacerAlCombate(function()
        local b1 = f.botones[1]
        b1:ClearAllPoints()
        local dx = 6
        local izq = _G.MultiBarBottomRightButton1 and MultiBarBottomRightButton1.GetLeft and MultiBarBottomRightButton1:GetLeft()
        local der = ActionButton12.GetRight and ActionButton12:GetRight()
        if izq and der then dx = izq - der end
        b1:SetPoint("LEFT", ActionButton12, "RIGHT", dx, 0)
        for i = 2, #f.botones do
            f.botones[i]:ClearAllPoints()
            f.botones[i]:SetPoint("LEFT", f.botones[i - 1], "RIGHT", 6, 0)
        end
        f:Show()
    end)
end

-- ------------------------------------------------------------ posturas, mascota y totems (PvE)
function B.apartar()
    if not (B.sinBartender() and enPvE()) then return false end
    return hacerAlCombate(function()
        local e = B.APARTE.escala
        local a = B.visibles() and B.APARTE.visibles or B.APARTE.escondidas
        local abajo = B.APARTE.abajo
        -- el primer botón de posturas va 10 a la derecha y 3 arriba de su barra
        local st = _G.ShapeshiftBarFrame
        if st then
            st:SetScale(e)
            st:ClearAllPoints()
            st:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", a.postura / e - 10, abajo / e - 3)
        end
        local mc = _G.MultiCastActionBarFrame
        if mc then
            mc:SetScale(e)
            mc:ClearAllPoints()
            mc:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", a.totems / e, abajo / e - 3)
        end
        -- la de la mascota se desliza a su lugar cada vez que aparece: se corren
        -- los botones (el marco que se mueva, que no tiene nada a la vista)
        local pb, p1 = _G.PetActionBarFrame, _G.PetActionButton1
        if pb and p1 then
            local em = a.escalaMascota or e
            pb:SetScale(em)
            p1:ClearAllPoints()
            p1:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", a.mascota / em, abajo / em)
        end
    end)
end

-- el juego las vuelve a poner en su lugar cada vez que acomoda la pantalla
-- (0.9.7) la barra de experiencia y la de reputación arriba de todo, pegadas al
-- borde de arriba (lo pidió). Si están las dos, la de experiencia arriba y la de
-- reputación justo debajo. No son marcos protegidos: se pueden mover en combate.
function B.barraXP()
    if not B.sinBartender() then return false end
    local xp, rep = _G.MainMenuExpBar, _G.ReputationWatchBar
    if not (xp and rep and xp.SetPoint) then return false end
    xp:ClearAllPoints()
    xp:SetPoint("TOP", UIParent, "TOP", 0, 0)
    rep:ClearAllPoints()
    if xp:IsShown() then
        rep:SetPoint("TOP", xp, "BOTTOM", 0, 0)
    else
        rep:SetPoint("TOP", UIParent, "TOP", 0, 0)
    end
    return true
end

local enganchado = false
local function enganchar()
    if enganchado or not hooksecurefunc then return end
    enganchado = true
    if UIParent_ManageFramePositions then
        hooksecurefunc("UIParent_ManageFramePositions", function() B.apartar(); B.barraXP() end)
    end
    -- los totems también se deslizan al aparecer: al terminar se vuelven a correr
    local mc = _G.MultiCastActionBarFrame
    -- el juego vuelve a poner experiencia y reputación sobre la barra principal
    for _, fn in ipairs({ "ReputationWatchBar_Update", "MainMenuExpBar_Update", "MainMenuBar_UpdateExperienceBars" }) do
        if _G[fn] then hooksecurefunc(fn, function() B.barraXP() end) end
    end
    if mc and mc.HookScript then
        mc:HookScript("OnUpdate", function(self)
            if not enPvE() then return end
            if self.slideTimer and self.timeToSlide and self.slideTimer < self.timeToSlide then return end
            local _, rel = self:GetPoint(1)
            if rel ~= UIParent and not (InCombatLockdown and InCombatLockdown()) then B.apartar() end
        end)
    end
end

-- ------------------------------------------------------------ a la vista o escondidas (Blizzard)
local ABAJO = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton" }
local COSTADO = { "MultiBarRight", "MultiBarLeft" }
local function botonesAbajo(fn)
    for _, pre in ipairs(ABAJO) do
        for i = 1, 12 do local b = _G[pre .. i]; if b then fn(b) end end
    end
end
local vigia
local function costadoConMouse(si)
    if not si then
        if vigia then vigia:SetScript("OnUpdate", nil) end
        for _, n in ipairs(COSTADO) do if _G[n] then _G[n]:SetAlpha(1) end end
        return
    end
    vigia = vigia or CreateFrame("Frame")
    local t = 0
    vigia:SetScript("OnUpdate", function(_, dt)
        t = t + dt
        if t < 0.1 then return end
        t = 0
        for _, n in ipairs(COSTADO) do
            local f = _G[n]
            if f then f:SetAlpha((MouseIsOver and MouseIsOver(f)) and 1 or 0) end
        end
    end)
end

-- las 4 barras de más de Blizzard (Interfaz, Barras de acción) prendidas
local function prenderBarras()
    if not (GetActionBarToggles and SetActionBarToggles) then return false end
    local a, b, c, d, siempre = GetActionBarToggles()
    if a and b and c and d then return false end
    SetActionBarToggles(1, 1, 1, 1, siempre)
    SHOW_MULTI_ACTIONBAR_1, SHOW_MULTI_ACTIONBAR_2, SHOW_MULTI_ACTIONBAR_3, SHOW_MULTI_ACTIONBAR_4 = 1, 1, 1, 1
    if MultiActionBar_Update then MultiActionBar_Update() end
    if UIParent_ManageFramePositions then UIParent_ManageFramePositions() end
    return true
end
B.prenderBarras = prenderBarras

function B.ponerVista()
    if not B.sinBartender() then return false end
    local ver = B.visibles()
    return hacerAlCombate(function()
        prenderBarras()
        local function poner(b)
            b:SetAlpha(ver and 1 or 0)
            if b.EnableMouse then b:EnableMouse(ver and true or false) end
        end
        botonesAbajo(poner)
        B.ponerExtra()
        if extra then for _, b in ipairs(extra.botones) do poner(b) end end
        costadoConMouse(not ver)
    end)
end

-- ------------------------------------------------------------ limpiar (Blizzard)
local limpias = false
function B.limpiar()
    if not B.sinBartender() then return false end
    for _, n in ipairs(ARTE) do
        local t = _G[n]
        if t then
            if t.SetTexture then t:SetTexture(nil) end
            if t.SetAlpha then t:SetAlpha(0) end
        end
    end
    if _G.MainMenuBarMaxLevelBar and MainMenuBarMaxLevelBar.SetAlpha then MainMenuBarMaxLevelBar:SetAlpha(0) end
    for _, n in ipairs(FLECHAS) do
        local f = _G[n]
        if f then
            if f.SetAlpha then f:SetAlpha(0) end
            if f.EnableMouse then f:EnableMouse(false) end
            if f.Hide then f:Hide() end
        end
    end
    ponerMenu()
    B.ponerVista()
    B.apartar()
    B.barraXP()
    enganchar()
    if not limpias and hooksecurefunc and MoveMicroButtons then
        -- al bajar de un vehículo el juego vuelve a poner el menú en su lugar
        hooksecurefunc("MoveMicroButtons", function() ponerMenu() end)
    end
    limpias = true
    return true
end

-- ------------------------------------------------------------ elegir
-- estilo: "bartender" o "blizzard"; vista: "visibles" o "escondidas".
-- Devuelve true si hace falta recargar.
function B.elegir(estilo, vista)
    local pj = NS.pj
    if not pj then return false end
    local A = NS.addons
    if estilo == "bartender" and A and A.instalado and not A.instalado(A.BT) then
        NS.decir("Bartender4 no está instalado en este juego: elegí las barras de Blizzard.")
        return false
    end
    local antes = { estilo = B.estilo(), vista = B.vista() }
    pj.barrasVista = vista
    local recargar = A and A.elegirBarras(estilo) or false
    -- con Bartender, la otra forma es otra UI armada: se escribe en su perfil
    if estilo == "bartender" and antes.estilo == "bartender" and antes.vista ~= vista then
        pj.btPend = pj.btPend or {}
        for m in pairs(pj.presets or {}) do pj.btPend[m] = true end
        if NS.perfiles and pj.activo and NS.perfiles.ponerBT and IsAddOnLoaded and IsAddOnLoaded("Bartender4") then
            if NS.perfiles.ponerBT(pj.activo) then recargar = true end
        end
    end
    if estilo == "blizzard" and not recargar then B.limpiar() end
    if NS.cds and NS.cds.avisar then NS.cds.avisar() end
    if B.ventana then B.ventana:Hide() end
    local txt = (estilo == "bartender" and "Bartender" or "barras de Blizzard") .. ", " .. (vista == "visibles"
        and "a la vista (en PvE sin Mis CDs)" or "escondidas (con Mis CDs abajo al centro)")
    NS.decir("Barras: " .. txt .. "." .. (recargar and " Hay que recargar." or ""))
    if recargar and StaticPopupDialogs and StaticPopup_Show then
        NS.recargando = true
        StaticPopupDialogs["MODOS_RECARGAR_BARRAS"] = StaticPopupDialogs["MODOS_RECARGAR_BARRAS"] or {
            text = "Modos: hay que recargar la interfaz para cambiar las barras.",
            button1 = "Recargar",
            OnAccept = function() ReloadUI() end,
            timeout = 0, whileDead = 1, hideOnEscape = false, showAlert = 1,
        }
        NS.pedirRecarga("MODOS_RECARGAR_BARRAS")
    end
    if NS.alCambiar then NS.alCambiar() end
    return recargar
end

-- ¿hay que preguntar? (todavía no eligió, o eligió antes de que se pudiera
-- elegir a la vista o escondidas)
function B.falta()
    return NS.pj and NS.pj.barrasVista == nil or false
end

B.OPCIONES = {
    { "bartender", "visibles", "Bartender, a la vista" },
    { "bartender", "escondidas", "Bartender, escondidas" },
    { "blizzard", "visibles", "Blizzard, a la vista" },
    { "blizzard", "escondidas", "Blizzard, escondidas" },
}
local NOMBRE = { bartender = "Bartender", blizzard = "Blizzard", visibles = "a la vista", escondidas = "escondidas" }

-- (1.0.15) cómo queda cada opción, dibujado (pidió ejemplos visuales para el que se
-- lo descarga; cuando la UI esté cerrada se cambian por capturas). Una pantalla de
-- 1920 x 1080 en chico con las barras donde las pone Modos en PvE (sacadas del preset,
-- así siempre coincide), el chat y tus marcos para ubicarse, y Mis CDs donde va.
-- tipo: "barra" (se ve), "tenue" (aparece con el mouse), "cds" (Mis CDs), "fondo".
B.ESQUEMA = { W = 1920, H = 1080, ancho = 208, alto = 117 }
local function cajaBT(cfg, W, H)
    local pos = cfg.position
    local s = pos.scale or 1
    local px, py
    if pos.point == "BOTTOM" then px, py = W / 2 + pos.x, pos.y
    elseif pos.point == "RIGHT" then px, py = W + pos.x, H / 2 + pos.y
    elseif pos.point == "BOTTOMRIGHT" then px, py = W + pos.x, pos.y
    else px, py = pos.x, pos.y end
    local filas = math.min(cfg.rows or 1, 12)
    local porFila = math.ceil(12 / filas)
    filas = math.ceil(12 / porFila)
    local x0, y1 = px + 5 * s, py - 3 * s
    return x0, y1 - (38 * filas - 2) * s, x0 + (38 * porFila - 2) * s, y1
end
function B.esquema(estilo, vista)
    local W, H = B.ESQUEMA.W, B.ESQUEMA.H
    local cx = W / 2
    local l = {}
    local function mas(tipo, x0, y0, x1, y1) l[#l + 1] = { tipo = tipo, x0 = x0, y0 = y0, x1 = x1, y1 = y1 } end
    -- para ubicarse: el chat y tus marcos (DPS)
    mas("fondo", 0, 95, 457, 239)
    local PR = NS.presets
    local mv = PR and PR.MOVERS and PR.MOVERS.DPS
    for _, k in ipairs({ "ElvUF_PlayerMover", "ElvUF_TargetMover" }) do
        local x, y
        if mv and mv[k] then x, y = mv[k]:match(",([-%d.]+),([-%d.]+)$") end
        x, y = tonumber(x), tonumber(y)
        if x then mas("fondo", cx + x - 108.5, y, cx + x + 108.5, y + 53) end
    end
    local visibles = vista == "visibles"
    if estilo == "bartender" then
        local bt = PR and PR.PvE and (visibles and PR.PvE.Bartender4Visible or PR.PvE.Bartender4)
        local ab = bt and bt.ActionBars and bt.ActionBars.actionbars or {}
        for i = 1, 6 do
            local b = ab[i]
            if b and b.enabled ~= false and b.position then
                local x0, y0, x1, y1 = cajaBT(b, W, H)
                mas((b.fadeout and b.fadeoutalpha == 0) and "tenue" or "barra", x0, y0, x1, y1)
            end
        end
    else
        mas(visibles and "barra" or "tenue", W - 42, 98, W - 6, 596)
        mas(visibles and "barra" or "tenue", W - 84, 98, W - 48, 596)
        if visibles then
            mas("barra", cx - 504, 4, cx + 504, 40)
            mas("barra", cx - 504, 46, cx - 6, 82)
            mas("barra", cx + 6, 46, cx + 504, 82)
        end
    end
    if not visibles then
        local c1 = H / 2 + ((PR and PR.MISCDS_Y and PR.MISCDS_Y.DPS) or -375)
        mas("cds", cx - 256.5, c1 - 63, cx + 256.5, c1 + 20)
    end
    return l
end
local COLOR = { barra = { 0.35, 0.66, 0.9, 0.95 }, tenue = { 0.35, 0.66, 0.9, 0.25 }, cds = { 0.56, 0.81, 0.56, 0.9 },
                fondo = { 0.43, 0.48, 0.55, 0.45 } }
local function dibujar(parent, estilo, vista)
    local e = B.ESQUEMA
    local k = e.ancho / e.W
    local p = CreateFrame("Frame", nil, parent)
    p:SetWidth(e.ancho); p:SetHeight(e.alto)
    local bg = p:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(p)
    bg:SetTexture(0.04, 0.05, 0.08, 1)
    p.cajas = {}
    for _, c in ipairs(B.esquema(estilo, vista)) do
        local t = p:CreateTexture(nil, c.tipo == "fondo" and "BORDER" or "ARTWORK")
        t:SetTexture(unpack(COLOR[c.tipo]))
        t:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", c.x0 * k, c.y0 * k)
        t:SetWidth(math.max(1, (c.x1 - c.x0) * k)); t:SetHeight(math.max(1, (c.y1 - c.y0) * k))
        p.cajas[#p.cajas + 1] = t
    end
    return p
end

function B.preguntar()
    if not (E and NS.pj) then return end
    if not B.ventana then
        local e = B.ESQUEMA
        local ancho = 14 + 2 * (e.ancho + 14)
        local f = CreateFrame("Frame", "ModosBarras", UIParent)
        f:SetWidth(ancho); f:SetHeight(118 + 2 * (e.alto + 40))
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
        E.ventana(f)
        f:SetFrameStrata("DIALOG")
        f:SetToplevel(true)
        f:EnableMouse(true)
        local t = E.texto(f, "titulo")
        t:SetPoint("TOPLEFT", 14, -12)
        t:SetText("Modos · barras de acción")
        local x = E.texto(f, "chico")
        x:SetPoint("TOPLEFT", 14, -36)
        x:SetWidth(ancho - 28)
        x:SetText("Con Bartender o con las de Blizzard (si tus binds están ahí). Azul: se ve. Azul tenue: aparece con el mouse. Verde: Mis CDs. Los binds andan igual. Se cambia con /modos barras.")
        f.ahora = E.texto(f, "chico")
        f.ahora:SetPoint("TOPLEFT", 14, -88)
        f.botones, f.dibujos = {}, {}
        for i, o in ipairs(B.OPCIONES) do
            local col, fila = (i - 1) % 2, (i <= 2) and 0 or 1
            local d = dibujar(f, o[1], o[2])
            d:SetPoint("TOPLEFT", 14 + col * (e.ancho + 14), -108 - fila * (e.alto + 40))
            f.dibujos[o[1] .. "-" .. o[2]] = d
            local b = E.boton(f, o[3], e.ancho, 24)
            b:SetPoint("TOP", d, "BOTTOM", 0, -6)
            b:SetScript("OnClick", function() B.elegir(o[1], o[2]) end)
            f.botones[o[1] .. "-" .. o[2]] = b
        end
        B.ventana = f
    end
    local f, A = B.ventana, NS.addons
    local hayBT = not (A and A.instalado) or A.instalado(A.BT)
    for _, o in ipairs(B.OPCIONES) do
        local b = f.botones[o[1] .. "-" .. o[2]]
        if o[1] == "bartender" and not hayBT then b:Disable() else b:Enable() end
    end
    local es, vi = B.estilo(), B.vista()
    f.ahora:SetText(es and ("Ahora: " .. (NOMBRE[es] or es) .. ", " .. (NOMBRE[vi] or "?") .. ".")
        or (hayBT and "" or "Bartender4 no está instalado."))
    f:Show()
end

-- ------------------------------------------------------------ eventos
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if B.pendiente then B.pendiente = nil; B.limpiar() end
        return
    end
    B.limpiar()
end)
