-- Modos · Interfaz: la barrita con los botones PvE y PvP (se mueve desde los
-- puntitos de la izquierda) y la ventana con el estado de cada modo.

local _, NS = ...
local E = NS.E
local C = E.C

local barrita, ventana, vPerfiles, vAddons
local ALTO = 524   -- alto de la ventana principal (1.0.28: +24, la fila de las barras)

-- ------------------------------------------------------------ posición
-- la posición la guarda Modos (el juego no, para que no haya dos que la pisen)
local function guardarPos(f, clave)
    if f.SetUserPlaced then f:SetUserPlaced(false) end
    local p, _, rp, x, y = f:GetPoint()
    if p then ModosDB.ui[clave] = { p, rp, x, y } end
end

local function ponerPos(f, clave, p, rp, x, y)
    local g = ModosDB.ui[clave]
    f:ClearAllPoints()
    if type(g) == "table" and g[1] then
        f:SetPoint(g[1], UIParent, g[2], g[3], g[4])
    else
        f:SetPoint(p, UIParent, rp, x, y)
    end
end

-- ------------------------------------------------------------ botones de modo
local function ayudaModo(self)
    local m, pj = self.modo, NS.pj
    if not pj then return end
    if not pj.activo then
        return E.ayuda(self, m, "Tocalo si lo que tenés ahora (binds y barras) es tu configuración de "..m
            ..". Se guarda así, sin cambiar nada.")
    end
    local i = NS.info(m)
    if i.activo then
        local ocupado = NS.ocupado and "Todavía estoy acomodando las barras." or nil
        local espera = NS.pendiente and ("Esperando que salgas de combate para pasar a "..NS.pendiente
            ..". Tocá "..m.." para quedarte.") or nil
        local faltan = (i.faltan > 0) and ("Faltan "..i.faltan..": "..table.concat(i.nombresFaltan, ", ")
            ..". Van a aparecer en su lugar apenas se pueda.") or nil
        return E.ayuda(self, "Estás en "..m, ocupado, espera, faltan)
    end
    local l1 = "Tocá para pasar a "..m..". Lo de ahora queda guardado en "..pj.activo.."."
    local l2 = i.guardado and ("Guardado "..NS.cuando(i.guardado)..".") or ("La primera vez arranca como copia de "..pj.activo..".")
    local l3 = (i.talento and NS.hayDual() and i.talento ~= NS.grupoActual())
        and ("También cambia al "..i.talento.."° talento.") or nil
    E.ayuda(self, m, l1, l2, l3)
end

local function botonModo(parent, m, ancho, alto)
    local b = E.boton(parent, m, ancho, alto)
    b.modo = m
    b:SetScript("OnClick", function() NS.pedir(m) end)
    b:SetScript("OnEnter", ayudaModo)
    b:SetScript("OnLeave", E.sinAyuda)
    return b
end

local function pintarModo(b)
    local pj = NS.pj
    if pj and pj.activo == b.modo then b:SetTipo("pri")
    elseif NS.pendiente == b.modo then b:SetTipo("riesgo")
    else b:SetTipo(nil) end
end

-- ------------------------------------------------------------ barrita
local function refrescarBarrita()
    if not barrita then return end
    if ModosDB.ui.oculta then barrita:Hide() else barrita:Show() end
    pintarModo(barrita.bPvE)
    pintarModo(barrita.bPvP)
end

local function crearBarrita()
    if barrita then return end
    local f = CreateFrame("Frame", "ModosBarrita", UIParent)
    f:SetWidth(144); f:SetHeight(28)
    E.ventana(f)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    ponerPos(f, "barrita", "TOP", "TOP", -300, -14)

    -- puntitos para arrastrar
    local grip = CreateFrame("Frame", nil, f)
    grip:SetWidth(14); grip:SetHeight(28)
    grip:SetPoint("LEFT", 0, 0)
    grip:EnableMouse(true)
    grip:RegisterForDrag("LeftButton")
    grip.puntos = {}
    for fila = 0, 2 do
        for col = 0, 1 do
            local t = grip:CreateTexture(nil, "OVERLAY")
            t:SetWidth(2); t:SetHeight(2)
            t:SetPoint("CENTER", grip, "CENTER", -2 + col * 4, 4 - fila * 4)
            t:SetTexture(C.inactivo[1], C.inactivo[2], C.inactivo[3], 1)
            grip.puntos[#grip.puntos + 1] = t
        end
    end
    local function colorPuntos(col)
        for _, t in ipairs(grip.puntos) do t:SetTexture(col[1], col[2], col[3], 1) end
    end
    grip:SetScript("OnDragStart", function()
        if not ModosDB.ui.fija then f:StartMoving() end
    end)
    grip:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        guardarPos(f, "barrita")
    end)
    grip:SetScript("OnEnter", function(self)
        colorPuntos(C.titulo)
        E.ayuda(self, "Modos", ModosDB.ui.fija and "La barrita está fija. Se suelta en la ventana de Modos."
            or "Arrastrá desde acá para moverla.")
    end)
    grip:SetScript("OnLeave", function() colorPuntos(C.inactivo); E.sinAyuda() end)

    f.bPvE = botonModo(f, "PvE", 48, 20)
    f.bPvE:SetPoint("LEFT", 14, 0)
    f.bPvP = botonModo(f, "PvP", 48, 20)
    f.bPvP:SetPoint("LEFT", f.bPvE, "RIGHT", 4, 0)

    local op = E.boton(f, nil, 22, 20)
    op:SetPoint("LEFT", f.bPvP, "RIGHT", 4, 0)
    local ic = op:CreateTexture(nil, "ARTWORK")
    ic:SetWidth(14); ic:SetHeight(14)
    ic:SetPoint("CENTER", 0, 0)
    ic:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
    ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if ic.SetDesaturated then ic:SetDesaturated(true) end
    ic:SetVertexColor(C.textoBoton[1], C.textoBoton[2], C.textoBoton[3])
    op:SetScript("OnClick", function() NS.abrirVentana() end)
    op:SetScript("OnEnter", function(self) E.ayuda(self, "Modos", "Ver cómo está guardado cada modo y las opciones.") end)
    op:SetScript("OnLeave", E.sinAyuda)
    f.op = op
    barrita = f
    NS.barrita = f
end

-- ------------------------------------------------------------ ventana
local function crearBloque(parent, m, y)
    local b = {}
    b.nombre = E.texto(parent, "seccion")
    b.nombre:SetPoint("TOPLEFT", 16, y)
    b.nombre:SetText(m)
    b.estado = E.texto(parent, "texto")
    b.estado:SetPoint("TOPLEFT", 64, y)
    b.detalle = E.texto(parent, "chico")
    b.detalle:SetPoint("TOPLEFT", 64, y - 20)
    b.detalle:SetWidth(300)

    b.talento = E.boton(parent, "Talento: no", 110, 20)
    b.talento:SetPoint("TOPLEFT", 64, y - 42)
    b.talento:SetScript("OnClick", function()
        local t = NS.modo(m).talento
        local sig
        if t == nil then sig = 1 elseif t == 1 then sig = 2 end
        NS.vincular(m, sig)
    end)
    b.talento:SetScript("OnEnter", function(self)
        if not NS.hayDual() then
            return E.ayuda(self, "Talento", "Hace falta tener dos talentos (dual spec).")
        end
        E.ayuda(self, "Atar "..m.." a un talento",
            "Al cambiar a ese talento, pasás solo a "..m..". Y al tocar "..m..", también cambia de talento.",
            "Tocá para elegir: no, 1° o 2°.")
    end)
    b.talento:SetScript("OnLeave", E.sinAyuda)

    b.anterior = E.boton(parent, "Versión anterior", 130, 20)
    b.anterior:SetPoint("LEFT", b.talento, "RIGHT", 6, 0)
    b.anterior:SetScript("OnClick", function() NS.deshacer(m) end)
    b.anterior:SetScript("OnEnter", function(self)
        local i = NS.info(m)
        if not i.anterior then
            return E.ayuda(self, "Versión anterior", "Todavía no hay. Se arma sola cada vez que "..m.." se guarda.")
        end
        E.ayuda(self, "Versión anterior de "..m,
            "Vuelve a como estaba "..m.." antes del último guardado (versión de "..NS.cuando(i.anterior)..").",
            i.activo and "Como es el modo en uso, se pone ahora mismo." or "Se usa la próxima vez que pases a "..m..".",
            "Tocá de nuevo para deshacer.")
    end)
    b.anterior:SetScript("OnLeave", E.sinAyuda)
    return b
end

local function refrescarVentana()
    if not (ventana and ventana:IsShown() and NS.pj) then return end
    pintarModo(ventana.bPvE)
    pintarModo(ventana.bPvP)
    local pj = NS.pj
    ventana.talentoAhora:SetText(NS.hayDual() and ("Talento en uso: "..NS.grupoActual().."°") or "")
    for _, m in ipairs(NS.MODOS) do
        local b, i = ventana.bloques[m], NS.info(m)
        local partes = {}
        if i.activo then partes[#partes + 1] = E.cod(C.ok, "En uso") end
        if NS.pendiente == m then partes[#partes + 1] = E.cod(C.riesgo, "espera que salgas de combate") end
        partes[#partes + 1] = i.guardado and ("guardado "..NS.cuando(i.guardado)) or "sin guardar"
        b.estado:SetText(table.concat(partes, " · "))
        if i.guardado then
            local d = (i.botones and (i.botones.." botones") or "sin barras en este talento").." · "..(i.teclas or 0).." teclas"
            if i.faltan > 0 then d = d.." · "..E.cod(C.riesgo, "faltan "..i.faltan) end
            b.detalle:SetText(d)
        elseif pj.activo then
            b.detalle:SetText("La primera vez arranca como copia de "..pj.activo..".")
        else
            b.detalle:SetText("Tocá el modo que corresponde a lo que tenés ahora.")
        end
        if NS.hayDual() then
            b.talento:Enable()
            b.talento:SetText("Talento: "..(i.talento and (i.talento.."°") or "no"))
        else
            b.talento:Disable()
            b.talento:SetText("Talento: no")
        end
        if i.anterior then b.anterior:Enable() else b.anterior:Disable() end
    end

    local u = pj.ultimo
    local t1, t2, t3 = "Último cambio", "Todavía ninguno.", ""
    if u and u.adoptado then
        t1 = "Primer guardado · "..NS.cuando(u.cuando)
        t2 = "Tu configuración quedó guardada como "..u.a.."."
    elseif u and u.origen == "anterior" then
        t1 = "Versión anterior · "..NS.cuando(u.cuando)
        t2 = u.a..": cambiaron "..(u.botones or 0).." botones y "..(u.teclas or 0).." teclas."
    elseif u then
        t1 = "Último cambio · "..NS.cuando(u.cuando)
        t2 = "De "..tostring(u.de).." a "..u.a
        if u.copia then t2 = t2..": arrancó como copia de "..u.copia.."."
        else t2 = t2..": cambiaron "..(u.botones or 0).." botones y "..(u.teclas or 0).." teclas." end
        if u.origen == "talento" then t2 = t2.." Fue por el cambio de talento." end
    end
    if pj.activo then
        local i = NS.info(pj.activo)
        if i.faltan > 0 then
            t3 = E.cod(C.riesgo, "Faltan "..i.faltan..": ")..table.concat(i.nombresFaltan, ", ")
                ..". Van a aparecer en su lugar apenas se pueda."
        end
    end
    ventana.ultimoT:SetText(t1)
    ventana.ultimo1:SetText(t2)
    ventana.ultimo2:SetText(t3)
    if NS.perfiles then
        local l = NS.perfiles.lista()
        local n = 0
        for _, x in ipairs(l) do if x.sigue then n = n + 1 end end
        if #l == 0 then
            ventana.perfilesT:SetText("Perfiles de addons: no hay ninguno cargado.")
            ventana.bPerfiles:Disable()
        else
            ventana.perfilesT:SetText("Perfiles de addons: "..n.." de "..#l.." cambian con el modo.")
            ventana.bPerfiles:Enable()
        end
    end
    if NS.addons then
        local l = NS.addons.lista()
        local pve, pvp = 0, 0
        for _, x in ipairs(l) do
            if x.regla == "PvE" then pve = pve + 1 elseif x.regla == "PvP" then pvp = pvp + 1 end
        end
        ventana.addonsT:SetText(#l == 0 and "Addons por modo: ninguno instalado de la lista."
            or ("Addons por modo: "..pve.." solo en PvE, "..pvp.." solo en PvP."))
    end
    if ventana.barrasT and NS.barras then
        local B = NS.barras
        local es, vi = B.estilo(), B.vista()
        local nom = (es == "bartender" and "Bartender" or (es == "blizzard" and "Blizzard") or "sin elegir")
            .. (vi and (", " .. (vi == "visibles" and "a la vista" or "escondidas")) or "")
        local todas = B.todasAVista and B.todasAVista()
        ventana.barrasT:SetText("Barras: " .. nom .. (todas and E.cod(C.ok, " · todas a la vista") or ""))
        ventana.bBarras:SetText(todas and "Esconder" or "Ver todas")
        if es then ventana.bBarras:Enable() else ventana.bBarras:Disable() end
    end
    local rol = NS.rol and NS.rol.actual()
    ventana.rolT:SetText("Rol en PvE (talento "..(NS.rol and NS.rol.grupo() or 1).."): "..(rol or "sin elegir"))
    ventana.bRol:SetText(rol or "Elegir")
    ventana.chkMostrar:SetChecked(not ModosDB.ui.oculta)
    ventana.chkFijar:SetChecked(ModosDB.ui.fija and true or false)
end

local function casillaConTexto(parent, texto, x, y, alClic)
    local c = E.casilla(parent, 16)
    c:SetPoint("BOTTOMLEFT", x, y)
    local t = E.texto(parent, "texto")
    t:SetPoint("LEFT", c, "RIGHT", 6, 0)
    t:SetText(texto)
    c:SetScript("OnClick", function(self) alClic(self:GetChecked() and true or false) end)
    return c
end

local function crearVentana()
    if ventana then return end
    local f = CreateFrame("Frame", "ModosVentana", UIParent)
    f:SetWidth(390); f:SetHeight(ALTO)
    ponerPos(f, "ventana", "CENTER", "CENTER", 0, 60)
    E.ventana(f)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); guardarPos(self, "ventana") end)
    if UISpecialFrames then table.insert(UISpecialFrames, "ModosVentana") end   -- Escape la cierra

    local tit = E.texto(f, "titulo")
    tit:SetPoint("TOPLEFT", 14, -10)
    tit:SetText("Modos  "..E.cod(C.inactivo, "· "..(UnitName("player") or "")))
    local ver = E.texto(f, "chico")
    ver:SetPoint("BOTTOMLEFT", tit, "BOTTOMRIGHT", 8, 1)
    ver:SetText("v"..NS.VERSION)
    E.cerrar(f)
    E.linea(f, -36)

    local lbl = E.texto(f, "texto")
    lbl:SetPoint("TOPLEFT", 16, -53)
    lbl:SetText("Pasar a")
    f.bPvE = botonModo(f, "PvE", 70, 24)
    f.bPvE:SetPoint("TOPLEFT", 72, -48)
    f.bPvP = botonModo(f, "PvP", 70, 24)
    f.bPvP:SetPoint("LEFT", f.bPvE, "RIGHT", 6, 0)
    f.talentoAhora = E.texto(f, "chico")
    f.talentoAhora:SetPoint("LEFT", f.bPvP, "RIGHT", 14, 0)
    E.linea(f, -84)

    f.bloques = {}
    local y = -96
    for _, m in ipairs(NS.MODOS) do
        f.bloques[m] = crearBloque(f, m, y)
        y = y - 74
    end
    E.linea(f, y + 6)

    f.ultimoT = E.texto(f, "texto")
    f.ultimoT:SetPoint("TOPLEFT", 16, y - 4)
    f.ultimo1 = E.texto(f, "chico")
    f.ultimo1:SetPoint("TOPLEFT", 16, y - 24)
    f.ultimo1:SetWidth(358)
    f.ultimo2 = E.texto(f, "chico")
    f.ultimo2:SetPoint("TOPLEFT", f.ultimo1, "BOTTOMLEFT", 0, -4)
    f.ultimo2:SetWidth(358)

    -- (1.0.28) todas las barras a la vista para poner binds o acomodar hechizos
    f.barrasT = E.texto(f, "chico")
    f.barrasT:SetPoint("BOTTOMLEFT", 16, 152)
    f.bBarras = E.boton(f, "Ver todas", 70, 20)
    f.bBarras:SetPoint("BOTTOMRIGHT", -16, 148)
    f.bBarras:SetScript("OnClick", function()
        if NS.barras and NS.barras.alternarTodas then NS.barras.alternarTodas() end
        refrescarVentana()
    end)
    f.bBarras:SetScript("OnEnter", function(self)
        E.ayuda(self, "Barras",
            "Pone todas las barras a la vista y se pueden tocar, para poner binds o acomodar hechizos.",
            "Tocalo de nuevo para dejarlas como estaban. También: /modos barras ver y /modos barras esconder.")
    end)
    f.bBarras:SetScript("OnLeave", E.sinAyuda)

    f.rolT = E.texto(f, "chico")
    f.rolT:SetPoint("BOTTOMLEFT", 16, 128)
    f.bRol = E.boton(f, "DPS/Tank", 70, 20)
    f.bRol:SetPoint("BOTTOMRIGHT", -16, 124)
    f.bRol:SetScript("OnClick", function()
        if NS.rol then NS.rol.siguiente() end
    end)
    f.bRol:SetScript("OnEnter", function(self)
        E.ayuda(self, "Rol en PvE",
            "Tank, DPS o Heal para el talento en uso: acomoda tu marco, el objetivo, Cell y Mis CDs.",
            "Tank y DPS: Cell al costado. Heal: Cell abajo al medio, debajo del casteo, un grupo por fila.",
            "Tocá para pasar al siguiente. También: /modos rol tank, dps o heal.")
    end)
    f.bRol:SetScript("OnLeave", E.sinAyuda)

    f.addonsT = E.texto(f, "chico")
    f.addonsT:SetPoint("BOTTOMLEFT", 16, 104)
    f.bAddons = E.boton(f, "Elegir", 70, 20)
    f.bAddons:SetPoint("BOTTOMRIGHT", -16, 100)
    f.bAddons:SetScript("OnClick", function() NS.abrirAddons() end)
    f.bAddons:SetScript("OnEnter", function(self)
        E.ayuda(self, "Addons por modo",
            "Qué addons se prenden en cada modo (Cell y DBM en PvE, Gladius y Compact Raid Frames en PvP...).",
            "Cuando un cambio de modo prende o apaga alguno, Modos recarga la interfaz.")
    end)
    f.bAddons:SetScript("OnLeave", E.sinAyuda)

    f.perfilesT = E.texto(f, "chico")
    f.perfilesT:SetPoint("BOTTOMLEFT", 16, 76)
    f.bPerfiles = E.boton(f, "Elegir", 70, 20)
    f.bPerfiles:SetPoint("BOTTOMRIGHT", -16, 72)
    f.bPerfiles:SetScript("OnClick", function() NS.abrirPerfiles() end)
    f.bPerfiles:SetScript("OnEnter", function(self)
        E.ayuda(self, "Perfiles de addons",
            "Bartender4, OmniBar, Gladius, EasyFrames, Diminishing Returns, Omen, Quartz, ElvUI, Compact Raid Frames, Details y MoveAnything pueden tener un perfil para cada modo.",
            "Elegí cuáles cambian con el modo.")
    end)
    f.bPerfiles:SetScript("OnLeave", E.sinAyuda)
    E.linea(f, -(ALTO - 174))
    E.linea(f, -(ALTO - 66))

    f.chkMostrar = casillaConTexto(f, "Mostrar la barrita", 16, 42, function(v)
        ModosDB.ui.oculta = not v
        refrescarBarrita()
    end)
    f.chkFijar = casillaConTexto(f, "Fijar la barrita", 190, 42, function(v)
        ModosDB.ui.fija = v or nil
    end)
    E.linea(f, -(ALTO - 32))
    local nota = E.texto(f, "chico")
    nota:SetPoint("BOTTOMLEFT", 16, 12)
    nota:SetText("El modo que dejás se guarda solo. En combate, espera a que salgas.")

    f:SetScript("OnShow", refrescarVentana)
    f:Hide()
    ventana = f
    NS.ventana = f
end

-- ------------------------------------------------------------ perfiles de addons
local ANCHO_P = 520

local function refrescarPerfiles()
    if not (vPerfiles and vPerfiles:IsShown() and NS.pj and NS.perfiles) then return end
    local l = NS.perfiles.lista()
    local activo = NS.pj.activo
    for i, fila in ipairs(vPerfiles.filas) do
        local x = l[i]
        if x then
            fila.clave = x.clave
            fila.chk:SetChecked(x.sigue)
            fila.nombre:SetText(x.sigue and x.nombre or E.cod(C.inactivo, x.nombre))
            for _, m in ipairs(NS.MODOS) do
                local t = x[m] or (x.sigue and activo and m ~= activo and "se arma al pasar a "..m) or "—"
                if m == activo and x.sigue then t = E.cod(C.ok, x.actual or t) end
                fila[m:lower()]:SetText(t)
            end
            fila:Show()
        else
            fila.clave = nil
            fila:Hide()
        end
    end
    vPerfiles.nada:SetText(#l == 0 and "No hay addons con perfiles cargados." or "")
end

local function crearFilaPerfil(parent, i)
    local fila = CreateFrame("Frame", nil, parent)
    fila:SetWidth(ANCHO_P - 32); fila:SetHeight(22)
    fila:SetPoint("TOPLEFT", 16, -84 - (i - 1) * 24)
    fila.chk = E.casilla(fila, 16)
    fila.chk:SetPoint("LEFT", 0, 0)
    fila.chk:SetScript("OnClick", function(self)
        if not fila.clave then return end
        local e = NS.perfiles.entrada(fila.clave)
        NS.perfiles.seguir(fila.clave, not e.sigue)
        refrescarPerfiles()
    end)
    fila.chk:SetScript("OnEnter", function(self)
        E.ayuda(self, "Cambia con el modo",
            "Marcado: este addon tiene un perfil para cada modo y cambia solo.",
            "Desmarcado: Modos no lo toca.")
    end)
    fila.chk:SetScript("OnLeave", E.sinAyuda)
    fila.nombre = E.texto(fila, "texto")
    fila.nombre:SetPoint("LEFT", 24, 0)
    fila.pve = E.texto(fila, "chico")
    fila.pve:SetPoint("LEFT", 180, 0)
    fila.pve:SetWidth(150)
    fila.pvp = E.texto(fila, "chico")
    fila.pvp:SetPoint("LEFT", 334, 0)
    fila.pvp:SetWidth(150)
    return fila
end

local function crearPerfiles()
    if vPerfiles then return end
    local n = #NS.perfiles.CONOCIDOS + #NS.perfiles.OTROS
    local f = CreateFrame("Frame", "ModosPerfiles", UIParent)
    f:SetWidth(ANCHO_P); f:SetHeight(84 + n * 24 + 70)
    ponerPos(f, "perfiles", "CENTER", "CENTER", 0, 40)
    E.ventana(f)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); guardarPos(self, "perfiles") end)
    if UISpecialFrames then table.insert(UISpecialFrames, "ModosPerfiles") end

    local tit = E.texto(f, "titulo")
    tit:SetPoint("TOPLEFT", 14, -10)
    tit:SetText("Perfiles de addons  "..E.cod(C.inactivo, "· "..(UnitName("player") or "")))
    E.cerrar(f)
    E.linea(f, -36)
    local h1 = E.texto(f, "seccion")
    h1:SetPoint("TOPLEFT", 40, -52)
    h1:SetText("Addon")
    local h2 = E.texto(f, "seccion")
    h2:SetPoint("TOPLEFT", 196, -52)
    h2:SetText("PvE")
    local h3 = E.texto(f, "seccion")
    h3:SetPoint("TOPLEFT", 350, -52)
    h3:SetText("PvP")
    E.linea(f, -74)
    f.filas = {}
    for i = 1, n do f.filas[i] = crearFilaPerfil(f, i) end
    f.nada = E.texto(f, "chico")
    f.nada:SetPoint("TOPLEFT", 16, -90)
    E.linea(f, -(84 + n * 24 + 4))
    local nota = E.texto(f, "chico")
    nota:SetPoint("TOPLEFT", 16, -(84 + n * 24 + 14))
    nota:SetWidth(ANCHO_P - 32)
    nota:SetText("En verde, el perfil en uso. La primera vez que pasás a un modo, cada addon marcado arranca con un perfil propio de este personaje, copiado del que tenía. En Compact Raid Frames elegí el perfil estando en cada modo: Modos se acuerda.")
    f:SetScript("OnShow", refrescarPerfiles)
    f:Hide()
    vPerfiles = f
end

function NS.abrirPerfiles()
    if not NS.perfiles then return end
    crearPerfiles()
    if vPerfiles:IsShown() then vPerfiles:Hide() else vPerfiles:Show(); refrescarPerfiles() end
end

-- ------------------------------------------------------------ addons por modo
-- Una fila por addon de la lista (DBM y todos sus módulos van en una sola),
-- con tres botones: PvE, PvP o Ambos.
local FILAS_A = 14
local ANCHO_A = 400

local function listaAddons()
    local l, dbm = {}, nil
    for _, x in ipairs(NS.addons.lista()) do
        if x.nombre:sub(1, 4) == "DBM-" then
            if not dbm then
                dbm = { nombre = "DBM", titulo = "DBM", regla = x.regla, modulos = {} }
                l[#l + 1] = dbm
            end
            dbm.modulos[#dbm.modulos + 1] = x.nombre
            if x.nombre == "DBM-Core" then dbm.regla = x.regla end
        else
            l[#l + 1] = x
        end
    end
    if dbm then dbm.titulo = "DBM ("..#dbm.modulos.." módulos)" end
    return l
end

local function refrescarAddons()
    if not (vAddons and vAddons:IsShown() and NS.pj and NS.addons) then return end
    local l = listaAddons()
    for i, fila in ipairs(vAddons.filas) do
        local x = l[i]
        fila.x = x
        if x then
            fila.nombre:SetText(x.nombre == "DBM" and x.titulo or x.nombre)
            for _, r in ipairs(NS.addons.REGLAS) do
                fila[r]:SetTipo(x.regla == r and "pri" or nil)
            end
            fila:Show()
        else
            fila:Hide()
        end
    end
    vAddons.nada:SetText(#l == 0 and "No hay instalado ningún addon de la lista." or "")
end

local function crearFilaAddon(parent, i)
    local fila = CreateFrame("Frame", nil, parent)
    fila:SetWidth(ANCHO_A - 32); fila:SetHeight(22)
    fila:SetPoint("TOPLEFT", 16, -84 - (i - 1) * 24)
    fila.nombre = E.texto(fila, "texto")
    fila.nombre:SetPoint("LEFT", 0, 0)
    local antes
    for _, r in ipairs({ "ambos", "PvP", "PvE" }) do
        local b = E.boton(fila, r == "ambos" and "Ambos" or r, 56, 20)
        if antes then b:SetPoint("RIGHT", antes, "LEFT", -4, 0) else b:SetPoint("RIGHT", 0, 0) end
        antes = b
        b:SetScript("OnClick", function()
            local x = fila.x
            if not x then return end
            for _, n in ipairs(x.modulos or { x.nombre }) do NS.addons.ponerRegla(n, r) end
            refrescarAddons()
        end)
        b:SetScript("OnEnter", function(self)
            E.ayuda(self, r == "ambos" and "Ambos" or ("Solo en "..r),
                r == "ambos" and "Queda prendido en los dos modos: Modos no lo toca."
                or ("Se prende en "..r.." y se apaga en el otro. Toma efecto al cambiar de modo (con recarga)."))
        end)
        b:SetScript("OnLeave", E.sinAyuda)
        fila[r] = b
    end
    return fila
end

local function crearAddons()
    if vAddons then return end
    local f = CreateFrame("Frame", "ModosAddons", UIParent)
    f:SetWidth(ANCHO_A); f:SetHeight(84 + FILAS_A * 24 + 60)
    ponerPos(f, "addons", "CENTER", "CENTER", 0, 40)
    E.ventana(f)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); guardarPos(self, "addons") end)
    if UISpecialFrames then table.insert(UISpecialFrames, "ModosAddons") end

    local tit = E.texto(f, "titulo")
    tit:SetPoint("TOPLEFT", 14, -10)
    tit:SetText("Addons por modo  "..E.cod(C.inactivo, "· "..(UnitName("player") or "")))
    E.cerrar(f)
    E.linea(f, -36)
    local h1 = E.texto(f, "seccion")
    h1:SetPoint("TOPLEFT", 16, -52)
    h1:SetText("Addon")
    local h2 = E.texto(f, "seccion")
    h2:SetPoint("TOPRIGHT", -16, -52)
    h2:SetText("Prendido en")
    E.linea(f, -74)
    f.filas = {}
    for i = 1, FILAS_A do f.filas[i] = crearFilaAddon(f, i) end
    f.nada = E.texto(f, "chico")
    f.nada:SetPoint("TOPLEFT", 16, -90)
    E.linea(f, -(84 + FILAS_A * 24 + 4))
    local nota = E.texto(f, "chico")
    nota:SetPoint("TOPLEFT", 16, -(84 + FILAS_A * 24 + 14))
    nota:SetWidth(ANCHO_A - 32)
    nota:SetText("Los cambios toman efecto la próxima vez que cambies de modo: Modos prende y apaga lo que haga falta y recarga la interfaz. Los addons que no están acá no se tocan.")
    f:SetScript("OnShow", refrescarAddons)
    f:Hide()
    vAddons = f
end

function NS.abrirAddons()
    if not NS.addons then return end
    crearAddons()
    if vAddons:IsShown() then vAddons:Hide() else vAddons:Show(); refrescarAddons() end
end

-- ------------------------------------------------------------ pregunta
-- Aparece solo si al entrar lo que tenés se parece más al otro modo (pasa si
-- el juego se cerró justo después de un cambio). Hasta que contestes no se
-- cambia nada.
local pregunta

function NS.preguntarModo(sugerido, actual, alElegir)
    if not pregunta then
        local f = CreateFrame("Frame", "ModosPregunta", UIParent)
        f:SetWidth(360); f:SetHeight(150)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
        E.ventana(f)
        f:SetFrameStrata("DIALOG")
        f:SetToplevel(true)
        f:EnableMouse(true)
        local t = E.texto(f, "titulo")
        t:SetPoint("TOPLEFT", 14, -10)
        t:SetText("Modos")
        f.texto = E.texto(f, "texto")
        f.texto:SetPoint("TOPLEFT", 14, -36)
        f.texto:SetWidth(332)
        f.b1 = E.boton(f, "", 110, 24, "pri")
        f.b1:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -4, 14)
        f.b2 = E.boton(f, "", 110, 24)
        f.b2:SetPoint("BOTTOMLEFT", f, "BOTTOM", 4, 14)
        pregunta = f
        NS.pregunta = f
    end
    local f = pregunta
    f.texto:SetText("Lo que tenés ahora (binds y barras) se parece más a "..sugerido.." que a "..actual
        ..", que es el que figuraba en uso. Pasa si el juego se cerró justo después de cambiar de modo. ¿En qué modo estás?")
    f.b1:SetText("Estoy en "..sugerido)
    f.b2:SetText("Estoy en "..actual)
    f.b1:SetScript("OnClick", function() f:Hide(); alElegir(sugerido) end)
    f.b2:SetScript("OnClick", function() f:Hide(); alElegir(actual) end)
    f:Show()
end

function NS.repreguntar()
    if pregunta then pregunta:Show() end
    NS.decir("Primero contestá en qué modo estás, en la ventanita de Modos.")
end

-- ------------------------------------------------------------ lo que usa el núcleo
function NS.abrirVentana()
    crearVentana()
    if ventana:IsShown() then ventana:Hide() else ventana:Show(); refrescarVentana() end
end

function NS.alternarBarrita()
    ModosDB.ui.oculta = not ModosDB.ui.oculta or nil
    refrescarBarrita()
    refrescarVentana()
    NS.decir(ModosDB.ui.oculta and "Barrita oculta. /modos barrita la vuelve a mostrar." or "Barrita visible.")
end

function NS.armarInterfaz()
    crearBarrita()
end

NS.alCambiar = function()
    refrescarBarrita()
    refrescarVentana()
    refrescarPerfiles()
    refrescarAddons()
end
