-- Modos · Mis CDs: elegís qué hechizos y abalorios querés ver al medio de la
-- pantalla (/modos cds) y en qué lugar de dos filas de 12 (botón Orden). La
-- lista es de cada personaje y de cada modo (una para PvE y otra para PvP, 12/10):
-- /modos cds edita la del modo en uso. Las auras la leen con ModosMisCDs(modo)
-- ("Mis CDs PvE" del paquete Modos PvE, "Mis CDs" de Alertas PvP Equipo): cada
-- uno con su casilla (1 a 24) y el bind de cada uno si está en una barra.

local _, NS = ...
local E = NS.E
local C = E.C

local CD = {}
NS.cds = CD

local cache = {}
CD.CASILLAS = 24

-- el modo que se edita y se muestra: el que está en uso (PvP si todavía no hay)
function CD.modo()
    return NS.pj and NS.pj.activo or "PvP"
end
-- lista y orden de un modo. La lista de antes (una sola) pasa a ser la de PvP.
local function datos(m)
    local pj = NS.pj
    if not pj then return nil end
    m = m or CD.modo()
    pj.misCDsPor = pj.misCDsPor or {}
    if pj.misCDs or pj.misCDsOrden then
        pj.misCDsPor.PvP = pj.misCDsPor.PvP or { lista = pj.misCDs or {}, orden = pj.misCDsOrden or {} }
        pj.misCDs, pj.misCDsOrden = nil, nil
    end
    pj.misCDsPor[m] = pj.misCDsPor[m] or { lista = {}, orden = {} }
    return pj.misCDsPor[m]
end
CD.datos = datos

-- las 24 casillas: casilla -> clave (o nada)
local function orden(m)
    local d = datos(m)
    return d and d.orden
end
CD.orden = orden
local function casillaDe(clave, m)
    local o = orden(m)
    for i = 1, CD.CASILLAS do if o[i] == clave then return i end end
end
local function primeraLibre(m)
    local o = orden(m)
    for i = 1, CD.CASILLAS do if not o[i] then return i end end
end

local function elegidos(m)
    local d = datos(m)
    return d and d.lista
end

-- todo lo que se puede elegir: los dos abalorios y los hechizos que no son pasivos
function CD.disponibles()
    local l, visto = {}, {}
    for t = 1, (GetNumSpellTabs and GetNumSpellTabs() or 0) do
        local _, _, desde, cuantos = GetSpellTabInfo(t)
        for i = (desde or 0) + 1, (desde or 0) + (cuantos or 0) do
            local nombre = GetSpellName(i, "spell")
            local pasivo = IsPassiveSpell and IsPassiveSpell(i, "spell")
            if nombre and not pasivo and not visto[nombre] then
                visto[nombre] = true
                l[#l + 1] = { clave = "s:" .. nombre, nombre = nombre, indice = i,
                              icono = GetSpellTexture and GetSpellTexture(i, "spell") }
            end
        end
    end
    for n, ranura in ipairs({ 13, 14 }) do
        local id = GetInventoryItemID and GetInventoryItemID("player", ranura)
        local nombre = id and GetItemInfo and GetItemInfo(id)
        l[#l + 1] = { clave = "r:" .. ranura, nombre = "Abalorio " .. n .. (nombre and (": " .. nombre) or ""),
                      ranura = ranura, icono = GetInventoryItemTexture and GetInventoryItemTexture("player", ranura) }
    end
    return l
end

-- el nombre corto de una tecla: SHIFT-1 -> S1, CTRL-ALT-F -> CAF, BUTTON4 -> M4
local function corta(k)
    if not k or k == "" then return nil end
    k = k:gsub("SHIFT%-", "S"):gsub("CTRL%-", "C"):gsub("ALT%-", "A")
    k = k:gsub("MOUSEWHEELUP", "WU"):gsub("MOUSEWHEELDOWN", "WD"):gsub("BUTTON", "M"):gsub("NUMPAD", "N")
    return k
end

-- la tecla del botón de barra que tiene ese hechizo o abalorio (Bartender4 o Blizzard)
local BLIZZ = { { 1, "ACTIONBUTTON" }, { 25, "MULTIACTIONBAR3BUTTON" }, { 37, "MULTIACTIONBAR4BUTTON" },
                { 49, "MULTIACTIONBAR2BUTTON" }, { 61, "MULTIACTIONBAR1BUTTON" } }
local function teclaDeRanura(slot)
    if not GetBindingKey then return nil end
    local k = GetBindingKey("CLICK BT4Button" .. slot .. ":LeftButton")
    if k then return k end
    -- la barra de más de Modos (página 2, sin Bartender)
    if slot >= 13 and slot <= 24 then return GetBindingKey("CLICK ModosBarraExtraBoton" .. (slot - 12) .. ":LeftButton") end
    for _, b in ipairs(BLIZZ) do
        if slot >= b[1] and slot < b[1] + 12 then return GetBindingKey(b[2] .. (slot - b[1] + 1)) end
    end
end
function CD.tecla(x)
    if not GetActionInfo then return nil end
    local item = x.ranura and GetInventoryItemID and GetInventoryItemID("player", x.ranura)
    for slot = 1, 120 do
        local tipo, id = GetActionInfo(slot)
        local es = (tipo == "spell" and x.nombre and id and GetSpellName(id, "spell") == x.nombre)
                or (tipo == "item" and item and id == item)
        if es then
            local k = teclaDeRanura(slot)
            if k then return corta(k) end
        end
    end
end

function CD.esta(clave, m)
    local e = elegidos(m)
    return e and e[clave] and true or false
end

local function avisar()
    cache = {}
    if WeakAuras and WeakAuras.ScanEvents then pcall(WeakAuras.ScanEvents, "MODOS_MISCDS") end
end
CD.avisar = avisar

function CD.poner(clave, si)
    local e = elegidos()
    if not e then return end
    e[clave] = si and true or nil
    local o, i = orden(), casillaDe(clave)
    if si and not i then
        local libre = primeraLibre()
        if libre then o[libre] = clave end
    elseif not si and i then
        o[i] = nil
    end
    avisar()
end

-- cambia de lugar dos casillas (con algo o vacías)
function CD.cambiar(a, b)
    local o = orden()
    if not o or a == b then return end
    o[a], o[b] = o[b], o[a]
    avisar()
end

-- la lista para el aura: cada elegido con su casilla, el índice del libro o la
-- ranura y la tecla. Los elegidos que no tienen casilla (de antes de que
-- existiera el orden) van a las primeras libres, en el orden del libro.
function CD.lista(m)
    m = m or CD.modo()
    if cache[m] then return cache[m] end
    local l = {}
    if elegidos(m) then
        local o, porClave = orden(m), {}
        local disp = CD.disponibles()
        for _, x in ipairs(disp) do porClave[x.clave] = x end
        for _, x in ipairs(disp) do
            if CD.esta(x.clave, m) and not casillaDe(x.clave, m) then
                local libre = primeraLibre(m)
                if libre then o[libre] = x.clave end
            end
        end
        for i = 1, CD.CASILLAS do
            local x = o[i] and porClave[o[i]]
            if x and CD.esta(x.clave, m) then
                l[#l + 1] = { clave = x.clave, nombre = x.nombre, indice = x.indice, ranura = x.ranura, casilla = i,
                              tipo = x.ranura and "ranura" or "hechizo", tecla = CD.tecla(x), icono = x.icono }
            end
        end
    end
    cache[m] = l
    return l
end

-- la lista de un modo (sin modo: la del que está en uso)
function ModosMisCDs(m)
    if not NS.pj then return nil end
    -- (0.9.3) sin modo la pide el aura Mis CDs de PvP (Alertas PvP Equipo): en PvE
    -- no muestra nada (ahí está la de Modos PvE, que pide "PvE")
    if m == nil and CD.modo() == "PvE" then return {} end
    -- (0.9.2) en PvE con las barras a la vista no se muestra: los CDs están en las barras
    if (m or CD.modo()) == "PvE" and ModosBarrasVisibles and ModosBarrasVisibles() then return {} end
    return CD.lista(m)
end

-- cambió el libro, las barras, los binds o lo que tenés puesto: se arma de nuevo
local ev = CreateFrame("Frame")
for _, e in ipairs({ "SPELLS_CHANGED", "ACTIONBAR_SLOT_CHANGED", "UPDATE_BINDINGS", "PLAYER_EQUIPMENT_CHANGED",
                     "PLAYER_ENTERING_WORLD" }) do ev:RegisterEvent(e) end
ev:SetScript("OnEvent", function() avisar() end)

-- ------------------------------------------------------------ ventana
local COLS, FILAS = 3, 14
local ANCHO, ALTO_FILA = 600, 22
local v

-- en 3.3.5 no existe SetShown
local function mostrar(f, si) if si then f:Show() else f:Hide() end end

local function refrescarOrden()
    local l = CD.lista()
    local porCasilla = {}
    for _, x in ipairs(l) do porCasilla[x.casilla] = x end
    for i, b in ipairs(v.slots) do
        local x = porCasilla[i]
        b.x = x
        b.icono:SetTexture(x and x.icono or nil)
        mostrar(b.marca, v.elegida == i)
        mostrar(b.vacio, not x)
    end
end

local function refrescar()
    if not (v and v:IsShown()) then return end
    if v.titulo then
        v.titulo:SetText("Mis CDs " .. CD.modo() .. "  " .. E.cod(C.inactivo, "· " .. (UnitName("player") or "")))
    end
    local ordenando = v.ordenando
    for _, c in ipairs(v.casillas) do if ordenando then c:Hide(); c.icono:Hide(); c.texto:Hide() end end
    for _, b in ipairs(v.slots) do if ordenando then b:Show() else b:Hide() end end
    mostrar(v.ayudaOrden, ordenando)
    v.botonOrden:SetText(ordenando and "Lista" or "Orden")
    if ordenando then
        v.ant:Hide(); v.sig:Hide(); v.pag:SetText("")
        refrescarOrden()
        return
    end
    local l = CD.disponibles()
    v.lista = l
    local porPagina = COLS * FILAS
    v.paginas = math.max(1, math.ceil(#l / porPagina))
    if v.pagina > v.paginas then v.pagina = v.paginas end
    local base = (v.pagina - 1) * porPagina
    for i, c in ipairs(v.casillas) do
        local x = l[base + i]
        c.x = x
        if x then
            c.icono:SetTexture(x.icono)
            c.texto:SetText(x.nombre)
            c:SetChecked(CD.esta(x.clave))
            c:Show(); c.icono:Show(); c.texto:Show()
        else
            c:Hide(); c.icono:Hide(); c.texto:Hide()
        end
    end
    v.pag:SetText(v.paginas > 1 and (v.pagina .. " / " .. v.paginas) or "")
    if v.paginas > 1 then v.ant:Show(); v.sig:Show() else v.ant:Hide(); v.sig:Hide() end
end
CD.refrescar = refrescar

local function crear()
    if v then return end
    local f = CreateFrame("Frame", "ModosCDs", UIParent)
    f:SetWidth(ANCHO); f:SetHeight(84 + FILAS * ALTO_FILA + 56)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    E.ventana(f)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    if UISpecialFrames then table.insert(UISpecialFrames, "ModosCDs") end
    local tit = E.texto(f, "titulo")
    tit:SetPoint("TOPLEFT", 14, -10)
    tit:SetText("Mis CDs  " .. E.cod(C.inactivo, "· " .. (UnitName("player") or "")))
    f.titulo = tit
    E.cerrar(f)
    E.linea(f, -36)
    local h = E.texto(f, "chico")
    h:SetPoint("TOPLEFT", 16, -46)
    h:SetWidth(ANCHO - 32)
    h:SetText("Tildá lo que querés ver con su CD (aura Mis CDs). Abalorios al final de la lista. Con Orden elegís el lugar de cada uno. Se guarda para este personaje y este modo (PvE y PvP tienen cada uno su lista).")
    E.linea(f, -74)
    f.casillas = {}
    local anchoCol = (ANCHO - 32) / COLS
    for i = 1, COLS * FILAS do
        local col = math.floor((i - 1) / FILAS)
        local fila = (i - 1) % FILAS
        local c = E.casilla(f, 16)
        c:SetPoint("TOPLEFT", 16 + col * anchoCol, -84 - fila * ALTO_FILA)
        c.icono = f:CreateTexture(nil, "ARTWORK")
        c.icono:SetWidth(16); c.icono:SetHeight(16)
        c.icono:SetPoint("LEFT", c, "RIGHT", 4, 0)
        c.texto = E.texto(f, "texto")
        c.texto:SetPoint("LEFT", c.icono, "RIGHT", 4, 0)
        c.texto:SetWidth(anchoCol - 46)
        c:SetScript("OnClick", function(self)
            if self.x then CD.poner(self.x.clave, self:GetChecked() and true or false) end
        end)
        f.casillas[i] = c
    end
    E.linea(f, -(84 + FILAS * ALTO_FILA + 4))
    f.ant = E.boton(f, "<", 28, 20)
    f.ant:SetPoint("BOTTOMLEFT", 16, 14)
    f.ant:SetScript("OnClick", function() if f.pagina > 1 then f.pagina = f.pagina - 1; refrescar() end end)
    f.sig = E.boton(f, ">", 28, 20)
    f.sig:SetPoint("LEFT", f.ant, "RIGHT", 4, 0)
    f.sig:SetScript("OnClick", function() if f.pagina < f.paginas then f.pagina = f.pagina + 1; refrescar() end end)
    f.pag = E.texto(f, "chico")
    f.pag:SetPoint("LEFT", f.sig, "RIGHT", 8, 0)
    -- vista Orden: las 24 casillas como van a quedar (dos filas de 12). Tocás una
    -- y después otra, y se cambian de lugar (también con casillas vacías).
    f.slots = {}
    local LADO = 40
    local x0 = (ANCHO - (12 * LADO + 11 * 4)) / 2
    for i = 1, CD.CASILLAS do
        local col, fila = (i - 1) % 12, math.floor((i - 1) / 12)
        local b = CreateFrame("Button", nil, f)
        b:SetWidth(LADO); b:SetHeight(LADO)
        b:SetPoint("TOPLEFT", x0 + col * (LADO + 4), -110 - fila * (LADO + 10))
        b.vacio = b:CreateTexture(nil, "BACKGROUND")
        b.vacio:SetAllPoints(b)
        b.vacio:SetTexture(0.2, 0.2, 0.25, 0.8)
        b.icono = b:CreateTexture(nil, "ARTWORK")
        b.icono:SetAllPoints(b)
        b.marca = b:CreateTexture(nil, "OVERLAY")
        b.marca:SetPoint("TOPLEFT", -3, 3); b.marca:SetPoint("BOTTOMRIGHT", 3, -3)
        b.marca:SetTexture(1, 0.82, 0, 0.45)
        b:SetScript("OnClick", function()
            if f.elegida then
                CD.cambiar(f.elegida, i)
                f.elegida = nil
            else
                f.elegida = i
            end
            refrescarOrden()
        end)
        b:SetScript("OnEnter", function(self)
            if self.x and E.ayuda then E.ayuda(self, self.x.nombre, "Casilla " .. i) end
        end)
        if E.sinAyuda then b:SetScript("OnLeave", E.sinAyuda) end
        b:Hide()
        f.slots[i] = b
    end
    f.ayudaOrden = E.texto(f, "chico")
    f.ayudaOrden:SetPoint("TOPLEFT", 16, -84)
    f.ayudaOrden:SetWidth(ANCHO - 32)
    f.ayudaOrden:SetText("Así quedan al medio de la pantalla. Tocá uno y después otro lugar para cambiarlos (también a una casilla vacía, para dejar huecos o pasarlo a la fila de abajo).")
    f.ayudaOrden:Hide()
    f.botonOrden = E.boton(f, "Orden", 80, 20)
    f.botonOrden:SetPoint("BOTTOMRIGHT", -102, 14)
    f.botonOrden:SetScript("OnClick", function()
        f.ordenando = not f.ordenando
        f.elegida = nil
        refrescar()
    end)
    local limpiar = E.boton(f, "Ninguno", 80, 20)
    limpiar:SetPoint("BOTTOMRIGHT", -16, 14)
    limpiar:SetScript("OnClick", function()
        local e, o = elegidos(), orden()
        if e then for k in pairs(e) do e[k] = nil end end
        if o then for k in pairs(o) do o[k] = nil end end
        avisar(); refrescar()
    end)
    f.pagina = 1
    f:SetScript("OnShow", refrescar)
    f:Hide()
    v = f
end

function NS.abrirCDs()
    if not NS.pj then return end
    crear()
    if v:IsShown() then v:Hide() else v:Show(); refrescar() end
end
