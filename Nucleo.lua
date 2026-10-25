-- Modos · Núcleo (0.3.0)
--
-- Cada personaje tiene dos modos, PvE y PvP. Un modo guarda los binds (todas
-- las teclas), los perfiles de otros addons (Perfiles.lua) y las barras de acción (los 144 botones, menos los de posesión,
-- del 121 al 132). Las barras se guardan por talento, porque con dual spec el
-- juego ya tiene barras distintas en cada talento.
--
-- De quién son las barras: el server guarda las barras de cada talento, y
-- pj.enGrupo[talento] dice de qué modo son las que están ahí ahora. Antes de
-- pisarlas, siempre se guardan en ese modo. Así no se pierde nada, aunque
-- cambies de talento sin cambiar de modo.
--
-- Cada botón que cambia es un aviso al server. Van de a 20 cada medio
-- segundo, porque algunos servers echan al que manda demasiados juntos.
-- pj.aMedias[talento] anota qué modo se estaba poniendo ahí: si se corta (un
-- /reload, un cambio de talento, el juego que se cierra), se termina después.
--
-- Lo que no se puede poner (un ítem que no tenés, una macro borrada, un
-- hechizo de otro talento, una tecla de un addon apagado) no se pierde: queda
-- anotado y se pone solo cuando se puede. Los ítems que no tenés no se tocan,
-- porque en algunos servers ponerlos en la barra desconecta. Nunca se cambia
-- nada en combate.
--
-- Desde 0.3.0 cada modo además prende y apaga addons (Addons.lua) y tiene su
-- parte privada de ElvUI (Perfiles.lua). Las dos cosas toman efecto con
-- /reload: al terminar el cambio, si hace falta, Modos recarga la interfaz.

local ADDON, NS = ...
NS = NS or {}

NS.VERSION = "1.0.25"
NS.MODOS = { "PvE", "PvP" }

local DESDE_POSESION, HASTA_POSESION, ULTIMO = 121, 132, 144
local MACROS_MAX = 54                   -- 36 de la cuenta y 18 del personaje
local LIBRO = BOOKTYPE_SPELL or "spell"
local BINDS_DEL_PJ = 2                  -- CHARACTER_BINDINGS: binds propios de este personaje
local TANDA, PAUSA = 20, 0.5            -- botones por tanda y segundos entre tandas

-- ------------------------------------------------------------ utilidades
local function decir(msg)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff5aa9e6Modos|r: "..msg) end
end
NS.decir = decir

local function copiar(t)
    if type(t) ~= "table" then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = copiar(v) end
    return r
end
NS.copiar = copiar

local function contar(t)
    local n = 0
    if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
    return n
end
NS.contar = contar

local function refrescar()
    if NS.alCambiar then NS.alCambiar() end
end

local function grupoActual()
    return (GetActiveTalentGroup and GetActiveTalentGroup()) or 1
end
NS.grupoActual = grupoActual

local function hayDual()
    return ((GetNumTalentGroups and GetNumTalentGroups()) or 1) >= 2
end
NS.hayDual = hayDual

local function modo(m)
    local pj = NS.pj
    pj.modos[m] = pj.modos[m] or {}
    return pj.modos[m]
end
NS.modo = modo

local function otro(m)
    if m == "PvP" then return "PvE" end
    return "PvP"
end
NS.otro = otro

-- "hoy 18:20" o "24/09 18:20"
local function cuando(t)
    if not t then return "nunca" end
    if date("%d/%m/%y", t) == date("%d/%m/%y") then return "hoy "..date("%H:%M", t) end
    return date("%d/%m %H:%M", t)
end
NS.cuando = cuando

-- ------------------------------------------------------------ reloj
-- tareas con nombre: si se vuelve a pedir la misma, se corre el horario
local reloj = CreateFrame("Frame")
reloj:Hide()
local tareas = {}
local function despues(seg, nombre, fn)
    tareas[nombre] = { t = GetTime() + seg, fn = fn }
    reloj:Show()
end
NS.despues = despues

-- (1.0.15) las ventanitas de "hay que recargar": con el asistente de primeros pasos
-- abierto no se abren (se apilaban arriba del panel y lo tapaban). El asistente
-- anota el motivo y marca su botón Recargar. Al tocar Listo con una recarga
-- pendiente sale una sola ventanita. Sin el asistente, como siempre.
NS.RECARGAS = { MODOS_RECARGAR = "el modo", MODOS_RECARGAR_BARRAS = "las barras", MODOS_RECARGAR_ROL = "Cell",
                MODOS_RECARGAR_AURAS = "las WeakAuras", MODOS_RECARGAR_ESCALA = "la escala" }
function NS.pedirRecarga(nombre, arg)
    local I = NS.instalar
    if I and I.abierto and I.abierto() then
        I.anotarRecarga(NS.RECARGAS[nombre] or nombre)
        return true
    end
    if StaticPopup_Show then StaticPopup_Show(nombre, arg) end
    return true
end

-- (1.0.13) /modos reiniciar: pregunta antes, porque lo que acomodaste a mano en ese
-- modo se pierde
function NS.reiniciarYa(m)
    if InCombatLockdown and InCombatLockdown() then decir("En combate no."); return false end
    if not (NS.perfiles and NS.perfiles.reiniciar) then return false end
    local rp, lista = NS.perfiles.reiniciar(m)
    decir(("Reinicié el modo %s%s."):format(m, (#lista > 0) and (" (" .. table.concat(lista, ", ") .. " de fábrica y armados de nuevo)") or ""))
    rp = rp or {}
    rp.recargar = true
    if NS.perfiles.avisar then NS.perfiles.avisar(rp, m, m) end
    if NS.recargarSiHace then NS.recargarSiHace(m, rp) end
    return true
end
function NS.preguntarReiniciar(m)
    if not (StaticPopupDialogs and StaticPopup_Show) then return NS.reiniciarYa(m) end
    StaticPopupDialogs["MODOS_REINICIAR"] = {
        text = "Modos: ¿armar el modo %s desde cero?\n\nTus barras, marcos, ElvUI y lo demás de este modo vuelven a como vienen y se pone toda la UI de Modos de nuevo. Lo que acomodaste a mano en este modo se pierde. El otro modo no se toca. Después recarga.",
        button1 = "Reiniciar", button2 = "Cancelar",
        OnAccept = function(self, modo) NS.reiniciarYa(modo or (NS.pj and NS.pj.activo)) end,
        timeout = 0, whileDead = 1, hideOnEscape = true, showAlert = 1,
    }
    local d = StaticPopup_Show("MODOS_REINICIAR", m)
    if d then d.data = m end
    return d
end
reloj:SetScript("OnUpdate", function(self)
    local ahora, listas = GetTime(), nil
    for n, t in pairs(tareas) do
        if ahora >= t.t then
            listas = listas or {}
            listas[#listas + 1] = t.fn
            tareas[n] = nil
        end
    end
    if not next(tareas) then self:Hide() end
    if listas then for _, fn in ipairs(listas) do fn() end end
end)

-- sin el ruidito de cada botón mientras se acomodan las barras. Se apaga y se
-- prende dentro de la misma tanda, así nunca queda apagado.
local function callar()
    local antes = GetCVar and GetCVar("Sound_EnableAllSound")
    if antes and SetCVar then SetCVar("Sound_EnableAllSound", "0") end
    return antes
end
local function devolverSonido(antes)
    if antes and SetCVar then SetCVar("Sound_EnableAllSound", antes) end
end

-- ------------------------------------------------------------ libro de hechizos y macros
local function contexto()
    local ctx = { idx = {}, maxIdx = {}, maxRango = {} }
    local tabs = (GetNumSpellTabs and GetNumSpellTabs()) or MAX_SKILLLINE_TABS or 8
    for tab = 1, tabs do
        local nombre, _, desde, cuantos = GetSpellTabInfo(tab)
        if nombre and desde and cuantos then
            for i = desde + 1, desde + cuantos do
                local n, r = GetSpellName(i, LIBRO)
                if n then
                    r = r or ""
                    ctx.idx[n] = ctx.idx[n] or {}
                    ctx.idx[n][r] = i
                    -- los rangos vienen de menor a mayor: el último es el más alto
                    ctx.maxIdx[n], ctx.maxRango[n] = i, r
                end
            end
        end
    end
    return ctx
end

local function listaMacros(ctx)
    if not ctx.macros then
        local l = {}
        for i = 1, MACROS_MAX do
            local n, _, cuerpo = GetMacroInfo(i)
            if n then l[#l + 1] = { i = i, n = n, b = cuerpo } end
        end
        ctx.macros = l
    end
    return ctx.macros
end

-- la macro por nombre y texto, después solo por texto, después solo por nombre
local function buscarMacro(e, ctx)
    local porCuerpo, porNombre
    for _, x in ipairs(listaMacros(ctx)) do
        if x.n == e.n and x.b == e.b then return x.i end
        if e.b and x.b == e.b and not porCuerpo then porCuerpo = x.i end
        if x.n == e.n and not porNombre then porNombre = x.i end
    end
    return porCuerpo or porNombre
end

local function buscarCompanero(e)
    if not (e.ct and GetNumCompanions) then return nil end
    local n = GetNumCompanions(e.ct) or 0
    local porNombre
    for i = 1, n do
        local cid, nombre, sid = GetCompanionInfo(e.ct, i)
        if e.sid and (sid == e.sid or cid == e.sid) then return i end
        if e.n and nombre == e.n and not porNombre then porNombre = i end
    end
    if porNombre then return porNombre end
    if not e.sid and not e.n and e.idx and e.idx <= n then return e.idx end
    return nil
end

local function buscarSet(nombre)
    local n = (GetNumEquipmentSets and GetNumEquipmentSets()) or 0
    for i = 1, n do
        if GetEquipmentSetInfo(i) == nombre then return i end
    end
    return nil
end

-- ------------------------------------------------------------ barras
local function esPosesion(s) return s >= DESDE_POSESION and s <= HASTA_POSESION end

local function leerBoton(s, ctx)
    local tipo, id, sub, extra = GetActionInfo(s)
    if not tipo then return nil end
    if tipo == "spell" then
        local n, r
        if id and id > 0 then n, r = GetSpellName(id, LIBRO) end
        if not n and extra and GetSpellInfo then n, r = GetSpellInfo(extra) end
        if not n then return { t = "raro", tipo = tipo, id = id } end
        return { t = "spell", n = n, r = r or "", sid = extra, max = (id and ctx.maxIdx[n] == id) or nil }
    elseif tipo == "item" then
        return { t = "item", id = id, n = (GetItemInfo(id)) }
    elseif tipo == "macro" then
        local n, icono, cuerpo = GetMacroInfo(id)
        if not n then return { t = "raro", tipo = tipo, id = id } end
        return { t = "macro", n = n, i = icono, b = cuerpo, idx = id }
    elseif tipo == "companion" then
        local nombre
        if GetCompanionInfo and sub and id then
            local _, cn = GetCompanionInfo(sub, id)
            nombre = cn
        end
        return { t = "companion", ct = sub, idx = id, sid = extra, n = nombre }
    elseif tipo == "equipmentset" then
        return { t = "equipmentset", n = id }
    end
    return { t = "raro", tipo = tipo, id = id, sub = sub }
end

local function leerBarras(ctx)
    ctx = ctx or contexto()
    local t = {}
    for s = 1, ULTIMO do
        if not esPosesion(s) then t[s] = leerBoton(s, ctx) end
    end
    return t
end
NS.leerBarras = leerBarras

-- el rango que se quiere: si era el más alto, el más alto de hoy
local function rangoDeseado(e, ctx)
    if e.max and ctx.maxRango[e.n] then return ctx.maxRango[e.n] end
    return e.r or ""
end

local function tieneItem(x)
    if not x then return false end
    if (GetItemCount(x) or 0) > 0 then return true end
    return (IsEquippedItem and IsEquippedItem(x)) and true or false
end

local function igual(e, a, ctx)
    if e == nil or a == nil then return e == a end
    if e.t ~= a.t then return false end
    local t = e.t
    if t == "spell" then return e.n == a.n and rangoDeseado(e, ctx) == (a.r or "") end
    -- dos ítems con el mismo nombre valen lo mismo (las Healthstone tienen
    -- varios), salvo que tengas el guardado y no el que está puesto
    if t == "item" then
        return e.id == a.id or (e.n ~= nil and e.n == a.n and not tieneItem(e.id))
    end
    if t == "macro" then return buscarMacro(e, ctx) == a.idx end
    if t == "companion" then
        if e.sid and a.sid then return e.sid == a.sid end
        return e.ct == a.ct and e.idx == a.idx
    end
    if t == "equipmentset" then return e.n == a.n end
    return e.tipo == a.tipo and e.id == a.id
end

-- ¿se puede poner ahora? (sin tocar el cursor)
local function disponible(e, ctx)
    local t = e.t
    if t == "spell" then return ctx.idx[e.n] ~= nil end
    if t == "item" then return tieneItem(e.id) or tieneItem(e.n) end
    if t == "macro" then return buscarMacro(e, ctx) ~= nil end
    if t == "companion" then return buscarCompanero(e) ~= nil end
    if t == "equipmentset" then return buscarSet(e.n) ~= nil end
    return false
end

-- deja e en el cursor. false si no se puede (no lo tenés o no existe)
local function tomar(e, ctx)
    local t = e.t
    if t == "spell" then
        local rangos = ctx.idx[e.n]
        if not rangos then return false end
        local i = (e.max and ctx.maxIdx[e.n]) or rangos[e.r or ""] or ctx.maxIdx[e.n]
        PickupSpell(i, LIBRO)
        return GetCursorInfo() == "spell"
    elseif t == "item" then
        local cual
        if tieneItem(e.id) then cual = e.id
        elseif tieneItem(e.n) then cual = e.n end     -- otro rango del mismo ítem (Healthstone)
        if not cual then return false end
        PickupItem(cual)
        return GetCursorInfo() == "item"
    elseif t == "macro" then
        local i = buscarMacro(e, ctx)
        if not i then return false end
        PickupMacro(i)
        return GetCursorInfo() == "macro"
    elseif t == "companion" then
        local i = buscarCompanero(e)
        if not i then return false end
        PickupCompanion(e.ct, i)
        return GetCursorInfo() == "companion"
    elseif t == "equipmentset" then
        local i = buscarSet(e.n)
        if not i then return false end
        if PickupEquipmentSet then PickupEquipmentSet(i) else PickupEquipmentSetByName(e.n) end
        return GetCursorInfo() == "equipmentset"
    end
    return false
end

-- pone e en el botón s con un solo aviso al server: si había algo, se
-- intercambia y lo viejo (que queda en el cursor) se descarta.
-- true si quedó puesto: el cursor ya no tiene lo que se levantó.
local function colocar(s, e, ctx)
    if e.t == "raro" then return false end
    if not tomar(e, ctx) then ClearCursor(); return false end
    local t1, i1 = GetCursorInfo()
    PlaceAction(s)
    local t2, i2 = GetCursorInfo()
    ClearCursor()
    return not (t2 == t1 and i2 == i1)
end

-- barras en tandas: a lo sumo TANDA botones cada PAUSA segundos
local trabajo

local function terminarTrabajo(ok, err)
    local w = trabajo
    trabajo = nil
    NS.ocupado = nil
    w.v.faltan = w.v.faltan or {}
    w.v.faltan[w.g] = next(w.faltan) and w.faltan or nil
    if w.fin then w.fin(w.cambios, w.v.faltan[w.g], (not ok) and tostring(err) or nil) end
    refrescar()
end

local seguirTrabajo
seguirTrabajo = function()
    local w = trabajo
    if not w then return end
    -- cambiaste de talento a mitad de camino: estas barras se terminan cuando
    -- vuelvas a ese talento (queda anotado en pj.aMedias)
    if grupoActual() ~= w.g then
        trabajo = nil
        NS.ocupado, NS.trabajoEnPausa = nil, nil
        refrescar()
        return
    end
    -- si entraste en combate a mitad de camino, se sigue al salir
    if InCombatLockdown and InCombatLockdown() then
        if not NS.trabajoEnPausa then
            NS.trabajoEnPausa = true
            decir("Entraste en combate: termino de acomodar las barras cuando salgas.")
        end
        return
    end
    NS.trabajoEnPausa = nil
    -- si tenés algo agarrado con el mouse, se espera a que lo sueltes
    if GetCursorInfo() then despues(0.2, "barras", seguirTrabajo); return end
    local ctx = contexto()
    local sonido = callar()
    local ok, err = pcall(function()
        local hechos = 0
        while w.pos <= #w.lista and hechos < TANDA do
            local s = w.lista[w.pos]
            w.pos = w.pos + 1
            local e, a = w.foto[s], leerBoton(s, ctx)
            if not igual(e, a, ctx) then
                hechos = hechos + 1
                if e and colocar(s, e, ctx) then
                    w.cambios = w.cambios + 1
                else
                    -- lo que no se puede leer nunca se va a poder poner: no se anota
                    if e and e.t ~= "raro" then w.faltan[s] = e end
                    -- lo que había es del otro modo: se saca
                    if GetActionInfo(s) then
                        PickupAction(s)
                        ClearCursor()
                        w.cambios = w.cambios + 1
                    end
                end
            end
        end
    end)
    ClearCursor()
    devolverSonido(sonido)
    if not ok or w.pos > #w.lista then return terminarTrabajo(ok, err) end
    despues(PAUSA, "barras", seguirTrabajo)
end

-- pone las barras guardadas de v para el talento g y al final llama a
-- fin(botones que cambiaron, lo que no se pudo poner, error si hubo)
local function ponerBarras(v, g, fin)
    local foto = v.barras and v.barras[g]
    if not foto then
        if fin then fin(0, nil, nil) end
        return
    end
    local ctx = contexto()
    local lista = {}
    for s = 1, ULTIMO do
        if not esPosesion(s) and not igual(foto[s], leerBoton(s, ctx), ctx) then lista[#lista + 1] = s end
    end
    trabajo = { v = v, g = g, foto = foto, lista = lista, pos = 1, cambios = 0, faltan = {}, fin = fin }
    NS.ocupado = true
    seguirTrabajo()
end

-- pone las barras del modo m en el talento g y deja anotado que las barras de
-- g son de m. Hasta que termina queda en pj.aMedias, por si se corta.
local function ponerBarrasDe(m, g, fin)
    local pj = NS.pj
    pj.enGrupo[g] = m
    pj.aMedias[g] = m
    ponerBarras(modo(m).actual, g, function(n, faltan, err)
        pj.aMedias[g] = nil
        if fin then fin(n, faltan, err) end
    end)
end

-- guarda en v las barras de ahora del talento g. Lo que faltaba y sigue sin
-- ponerse (el botón quedó vacío) se conserva.
local function guardarBarras(v, g)
    local nuevo = leerBarras()
    local viejo = v.barras and v.barras[g]
    local f, sigue = v.faltan and v.faltan[g], nil
    if f then
        for s, e in pairs(f) do
            if nuevo[s] == nil then
                nuevo[s] = e
                sigue = sigue or {}
                sigue[s] = e
            end
        end
    end
    -- un botón que no se puede leer (por ejemplo una macro que ya no existe)
    -- no pisa lo que estaba guardado: queda como faltante
    if viejo then
        for s, e in pairs(nuevo) do
            local antes = viejo[s]
            if e.t == "raro" and antes and antes.t ~= "raro" then
                nuevo[s] = antes
                sigue = sigue or {}
                sigue[s] = antes
            end
        end
    end
    v.barras = v.barras or {}
    v.barras[g] = nuevo
    v.faltan = v.faltan or {}
    v.faltan[g] = sigue
end

-- ------------------------------------------------------------ binds
-- No hay forma de pedirle al juego "todas las teclas con algo". Se prueban
-- todas las teclas conocidas con sus modificadores (en el orden que usa el
-- juego: ALT, CTRL, SHIFT), más las de cada comando de la lista del juego.
-- Incluye las teclas de los teclados en español (ñ, ´, +, <, ¿, |...).
-- El juego guarda la ñ en minúscula (visto en su bindings-cache.wtf).
local TECLAS
local function teclas()
    if TECLAS then return TECLAS end
    local base = {}
    for c in ("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"):gmatch(".") do base[#base + 1] = c end
    for i = 1, 24 do base[#base + 1] = "F"..i end
    for i = 0, 9 do base[#base + 1] = "NUMPAD"..i end
    for i = 1, 31 do base[#base + 1] = "BUTTON"..i end
    local otras = { "NUMPADDIVIDE", "NUMPADMULTIPLY", "NUMPADMINUS", "NUMPADPLUS", "NUMPADDECIMAL",
        "NUMPADENTER", "ESCAPE", "TAB", "CAPSLOCK", "SPACE", "BACKSPACE", "ENTER", "INSERT", "DELETE",
        "HOME", "END", "PAGEUP", "PAGEDOWN", "UP", "DOWN", "LEFT", "RIGHT", "PRINTSCREEN", "SCROLLLOCK",
        "PAUSE", "NUMLOCK", "MOUSEWHEELUP", "MOUSEWHEELDOWN", "`", "-", "=", "[", "]", "\\", ";", "'",
        ",", ".", "/", "LSHIFT", "RSHIFT", "LCTRL", "RCTRL", "LALT", "RALT",
        "ñ", "Ñ", "ç", "Ç", "´", "¨", "+", "*", "<", ">", "¿", "¡", "?", "!", "º", "ª", "°", "|", "¬", "{", "}",
        "^", "~", "&", "(", ")", "_", ":", "\"", "#", "$", "%", "@" }
    for _, k in ipairs(otras) do base[#base + 1] = k end
    local mods = { "", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "ALT-CTRL-", "ALT-CTRL-SHIFT-" }
    TECLAS = {}
    for _, m in ipairs(mods) do
        for _, b in ipairs(base) do TECLAS[#TECLAS + 1] = m..b end
    end
    return TECLAS
end

local function leerBinds()
    local t, visto = {}, {}
    local function mirar(k)
        if type(k) ~= "string" or k == "" or visto[k] then return end
        visto[k] = true
        local a = GetBindingAction(k)
        if a and a ~= "" then t[k] = a end
    end
    local function mirarVarias(...)
        for j = 1, select("#", ...) do mirar((select(j, ...))) end
    end
    for _, k in ipairs(teclas()) do mirar(k) end
    for i = 1, ((GetNumBindings and GetNumBindings()) or 0) do
        mirarVarias(select(2, GetBinding(i)))
    end
    return t
end
NS.leerBinds = leerBinds

-- los comandos de Modos (Alternar, Pasar a PvE, Pasar a PvP) nunca cambian
local function esNuestro(a) return type(a) == "string" and a:find("^MODOS_") ~= nil end

-- pone una tecla. true si quedó puesta (el juego no avisa con un error:
-- se mira cómo quedó)
local function ponerUno(k, a)
    local boton, raton = a:match("^CLICK (.+):([^:]+)$")
    local resto
    if boton then SetBindingClick(k, boton, raton)
    else
        resto = a:match("^SPELL (.+)$")
        if resto then SetBindingSpell(k, resto)
        else
            resto = a:match("^MACRO (.+)$")
            if resto then SetBindingMacro(k, resto)
            else
                resto = a:match("^ITEM (.+)$")
                if resto and SetBindingItem then SetBindingItem(k, resto) else SetBinding(k, a) end
            end
        end
    end
    return GetBindingAction(k) == a
end

local function aplicarBinds(deseados, actuales)
    local cambian, fallidos = {}, {}
    for k, a in pairs(actuales) do
        if not esNuestro(a) and deseados[k] ~= a then SetBinding(k); cambian[k] = true end
    end
    for k, a in pairs(deseados) do
        if not esNuestro(a) and not esNuestro(actuales[k]) and actuales[k] ~= a then
            if ponerUno(k, a) then cambian[k] = true else fallidos[k] = a end
        end
    end
    return contar(cambian), fallidos
end

-- pone los binds de un modo. Devuelve cuántas teclas cambiaron, el error si
-- algo explotó (en ese caso vuelve todo como estaba y no guarda nada) y las
-- teclas que el juego no aceptó (quedan anotadas y se reintentan).
local function ponerBinds(deseados)
    if type(deseados) ~= "table" then return 0 end
    local actuales = leerBinds()
    local ok, res, fallidos = pcall(aplicarBinds, deseados, actuales)
    if not ok then
        pcall(aplicarBinds, actuales, leerBinds())
        return 0, tostring(res)
    end
    if res > 0 then SaveBindings(BINDS_DEL_PJ) end
    return res, nil, (fallidos and next(fallidos)) and fallidos or nil
end

-- guarda en v los binds de ahora. Las teclas que no se pudieron poner y
-- siguen libres se conservan.
local function guardarBinds(v)
    local nuevos = leerBinds()
    local f, sigue = v.bindsFaltan, nil
    if f then
        for k, a in pairs(f) do
            if nuevos[k] == nil then
                nuevos[k] = a
                sigue = sigue or {}
                sigue[k] = a
            end
        end
    end
    v.binds, v.bindsFaltan = nuevos, sigue
end

-- cuántas teclas cambian entre dos juegos de binds (sin contar las de Modos
-- ni las que quedaron anotadas sin poner)
local function diferenciaBinds(vivos, guardados, faltan)
    local n, vistos = 0, {}
    local function mirar(k)
        if vistos[k] then return end
        vistos[k] = true
        local a, b = vivos[k], guardados[k]
        if esNuestro(a) or esNuestro(b) then return end
        if faltan and faltan[k] and a == nil then return end
        if a ~= b then n = n + 1 end
    end
    for k in pairs(vivos) do mirar(k) end
    for k in pairs(guardados) do mirar(k) end
    return n
end

-- ------------------------------------------------------------ avisos
local ESPERA = "Esperá un segundo: todavía estoy acomodando las barras."

local function sePuede()
    if NS.ocupado then return false, ESPERA end
    if InCombatLockdown and InCombatLockdown() then return false, "combate" end
    if GetCursorInfo() then return false, "Soltá lo que tenés agarrado con el mouse y probá de nuevo." end
    if UnitCastingInfo and UnitCastingInfo("player") then
        return false, "Esperá a que termine lo que estás lanzando y probá de nuevo."
    end
    if KeyBindingFrame and KeyBindingFrame:IsShown() then
        return false, "Cerrá la ventana de teclas (Key Bindings) y probá de nuevo."
    end
    return true
end

local function respaldar(md)
    if md.actual then md.respaldo = copiar(md.actual) end
end

local function nombreDe(e)
    if e.t == "spell" then return e.n end
    if e.t == "item" then return e.n or (GetItemInfo(e.id)) or ("ítem "..tostring(e.id)) end
    if e.t == "macro" then return "macro "..tostring(e.n) end
    if e.t == "companion" then return e.n or "compañero" end
    if e.t == "equipmentset" then return "set "..tostring(e.n) end
    return "botón "..tostring(e.tipo)
end

local function nombres(f)
    local l, visto = {}, {}
    if f then
        local slots = {}
        for s in pairs(f) do slots[#slots + 1] = s end
        table.sort(slots)
        for _, s in ipairs(slots) do
            local n = nombreDe(f[s])
            if not visto[n] then visto[n] = true; l[#l + 1] = n end
        end
    end
    return l
end

-- "SHIFT-2 (MACRO Trinket)"
local function nombresTeclas(f)
    local l = {}
    if f then
        for k, a in pairs(f) do l[#l + 1] = k.." ("..a..")" end
        table.sort(l)
    end
    return l
end

local function avisoCentro(m)
    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        UIErrorsFrame:AddMessage("Modo "..m, 0.36, 0.66, 0.9)
    end
end

local function avisarFaltan(l)
    if #l == 0 then return end
    if #l == 1 then
        decir("No pude poner "..l[1].." porque ahora no está disponible. Va a aparecer en su lugar apenas se pueda.")
    else
        decir("No pude poner "..#l.." cosas porque ahora no están disponibles: "..table.concat(l, ", ")
            ..". Van a aparecer en su lugar apenas se pueda.")
    end
end

local function avisarTeclas(f)
    local l = nombresTeclas(f)
    if #l == 0 then return end
    decir((#l == 1 and "Una tecla no se pudo poner: " or (#l.." teclas no se pudieron poner: "))
        ..table.concat(l, ", ")..". Se ponen solas apenas se pueda.")
end

-- "14 botones y 22 teclas", "1 botón", "3 teclas", "14 botones, 2 teclas y 7 perfiles"
local function cuantos(botones, teclasN, perfilesN)
    local p = {}
    if botones > 0 then p[#p + 1] = botones..(botones == 1 and " botón" or " botones") end
    if teclasN > 0 then p[#p + 1] = teclasN..(teclasN == 1 and " tecla" or " teclas") end
    if (perfilesN or 0) > 0 then p[#p + 1] = perfilesN..(perfilesN == 1 and " perfil" or " perfiles") end
    if #p <= 1 then return p[1] or "" end
    return table.concat(p, ", ", 1, #p - 1).." y "..p[#p]
end

-- ------------------------------------------------------------ recarga
-- Prende y apaga los addons del modo m. Si cambió algún addon o la parte
-- privada de ElvUI, recarga la interfaz en un momento (ModosDB ya quedó al día:
-- el juego lo graba al recargar).
local function recargarSiHace(m, rp)
    local pren, apag = {}, {}
    if NS.addons then pren, apag = NS.addons.aplicar(m) end
    local privado = rp and rp.recargar
    -- (0.9.3) las WeakAuras de cada modo cargan solo en su modo (Auras.lua)
    local auras = NS.auras and NS.auras.hace(m)
    if #pren == 0 and #apag == 0 and not privado and not auras then return false end
    local partes = {}
    if #pren > 0 then partes[#partes + 1] = "prendo "..NS.addons.resumen(pren) end
    if #apag > 0 then partes[#partes + 1] = "apago "..NS.addons.resumen(apag) end
    if rp and rp.recargarPrivado then partes[#partes + 1] = "pongo la parte de ElvUI de "..m end
    if rp and rp.preset then partes[#partes + 1] = "armo la UI de "..m..(#rp.preset > 0 and (" ("..table.concat(rp.preset, ", ")..")") or "") end
    if auras then partes[#partes + 1] = "cargo las WeakAuras de "..m end
    decir("Para terminar de pasar a "..m.." hay que recargar la interfaz: "..table.concat(partes, ", ")..".")
    NS.recargando = true
    -- ReloadUI solo anda desde un clic (si no: "Interface action failed because
    -- of an AddOn"), así que se pide con una ventanita
    StaticPopupDialogs["MODOS_RECARGAR"] = StaticPopupDialogs["MODOS_RECARGAR"] or {
        text = "Modos: para terminar de pasar a %s hay que recargar la interfaz.",
        button1 = "Recargar",
        OnAccept = function() ReloadUI() end,
        timeout = 0, whileDead = 1, hideOnEscape = false, showAlert = 1,
    }
    NS.pedirRecarga("MODOS_RECARGAR", m)
    return true
end

-- ------------------------------------------------------------ cambiar de modo
-- la primera vez: lo de ahora queda guardado como el modo m (binds, barras y
-- perfiles). Después se prenden los addons de ese modo y se arma su parte
-- privada de ElvUI, con recarga si hace falta.
NS.recargarSiHace = recargarSiHace

local function adoptar(m)
    local pj = NS.pj
    local g = grupoActual()
    local md = modo(m)
    md.actual = { binds = leerBinds(), barras = { [g] = leerBarras() }, cuando = time() }
    pj.activo, pj.grupo = m, g
    pj.enGrupo[g] = m
    if NS.perfiles then NS.perfiles.adoptar(m) end
    pj.ultimo = { a = m, cuando = time(), adoptado = true, faltan = {} }
    decir("Listo: tu configuración de ahora quedó guardada como "..m..". Tocá "..otro(m)
        .." para armar el otro modo. Arranca como copia de este.")
    local rp = NS.perfiles and NS.perfiles.aplicar(m)
    if rp then NS.perfiles.avisar(rp, m, m) end
    recargarSiHace(m, rp)
    refrescar()
end

-- si las barras de este talento quedaron a medias, se terminan. Después
-- llama a luego(). false si no había nada pendiente.
local function retomar(g, luego)
    local pj = NS.pj
    local m0 = pj.aMedias[g]
    if not m0 then return false end
    local v = pj.modos[m0] and pj.modos[m0].actual
    if not (v and v.barras and v.barras[g]) then
        pj.aMedias[g] = nil
        return false
    end
    ponerBarrasDe(m0, g, function(n, faltan, err)
        if err then
            decir("No pude terminar de poner las barras de "..m0.." ("..err.."). Si algo quedó mal, usá Versión anterior.")
        elseif n > 0 then
            decir("Las barras de "..m0.." habían quedado a medias. Ya están completas.")
        end
        avisarFaltan(nombres(faltan))
        if luego then luego() end
    end)
    return true
end

-- antes de cambiar, las barras a medias de este talento se terminan
local function hayQueTerminar(g, reintento)
    local pj = NS.pj
    if not pj.aMedias[g] or NS.ocupado then return false end
    retomar(g)
    if NS.ocupado or pj.aMedias[g] then
        if reintento then despues(1, "cambioDemorado", reintento) else decir(ESPERA) end
        return true
    end
    return false
end

-- el modo atado a un talento, si hay (si todavía no existe, se arma como copia)
local function vinculado(g)
    if not hayDual() then return nil end
    for _, m in ipairs(NS.MODOS) do
        local md = NS.pj.modos[m]
        if md and md.talento == g then return m end
    end
    return nil
end

local cambiar
cambiar = function(nuevo, origen)
    local pj = NS.pj
    if not pj.activo then return adoptar(nuevo) end
    if NS.preguntando then
        if origen == "botón" then NS.repreguntar() end
        return
    end
    local automatico = origen ~= "botón"
    -- un cambio que vino solo y quedó para después se hace solo si sigue
    -- haciendo falta (no si mientras tanto elegiste quedarte)
    local function otraVez()
        if origen == "combate" and NS.pendiente ~= nuevo then return end
        if (origen == "talento" or origen == "inicio") and vinculado(grupoActual()) ~= nuevo then return end
        cambiar(nuevo, origen)
    end
    if hayQueTerminar(grupoActual(), automatico and otraVez or nil) then return end
    local ok, motivo = sePuede()
    if not ok then
        if motivo == "combate" then
            NS.pendiente = nuevo
            if not automatico or origen == "talento" then decir("Estás en combate: paso a "..nuevo.." apenas salgas.") end
        elseif automatico then
            despues(1, "cambioDemorado", otraVez)
        else
            decir(motivo)
        end
        refrescar()
        return
    end
    NS.pendiente = nil
    local g = grupoActual()
    local viejo = pj.activo
    local mv = modo(viejo)
    if not mv.actual then mv.actual = { binds = {}, barras = {}, cuando = time() } end

    -- 1) lo que dejás queda guardado: los binds son del modo en uso y las
    --    barras de este talento son del modo que figura como dueño
    respaldar(mv)
    guardarBinds(mv.actual)
    mv.actual.cuando = time()
    local dueno = pj.enGrupo[g] or viejo
    local mdu = modo(dueno)
    if dueno ~= viejo then
        respaldar(mdu)
        mdu.actual = mdu.actual or { binds = {}, barras = {} }
    end
    guardarBarras(mdu.actual, g)
    mdu.actual.cuando = time()

    -- 2) el modo nuevo, la primera vez, es una copia del que dejás
    local md = modo(nuevo)
    local copia
    if not md.actual then
        md.actual = copiar(mv.actual)
        copia = viejo
    end

    -- 3) binds del modo nuevo. Si algo explota, vuelven como estaban y no se
    --    cambia nada más: seguís en el modo que tenías.
    local teclasN, errB, fallidos = ponerBinds(md.actual.binds)
    if errB then
        decir("No pude pasar a "..nuevo..": falló un bind ("..errB.."). Quedó todo como estaba, seguís en "..viejo..".")
        refrescar()
        return
    end
    md.actual.bindsFaltan = fallidos

    -- 4) perfiles de los otros addons (Bartender4, OmniBar, Gladius...). Antes
    --    se anota en el modo que dejás el perfil que tenía cada uno.
    local rp = NS.perfiles and NS.perfiles.aplicar(nuevo, viejo)
    local perfilesN = rp and #rp.cambiados or 0

    -- 5) barras del modo nuevo, en tandas. Mientras tanto ya figura el modo
    --    nuevo. Si algo falla, vuelve todo al modo que tenías.
    pj.activo, pj.grupo = nuevo, g
    local function alTerminar(botonesN, faltan, errBar)
        if errBar then
            pj.activo = viejo
            local _, _, f2 = ponerBinds(mv.actual.binds)
            mv.actual.bindsFaltan = f2
            if NS.perfiles then NS.perfiles.aplicar(viejo) end
            ponerBarrasDe(dueno, g, function()
                decir("No pude pasar a "..nuevo..": falló algo en las barras ("..errBar.."). Volví todo a "..viejo..".")
            end)
            return
        end
        local l = nombres(faltan)
        pj.ultimo = { de = viejo, a = nuevo, cuando = time(), origen = origen, copia = copia,
                      botones = botonesN, teclas = teclasN, faltan = l, perfiles = perfilesN }
        local pre = ""
        if origen == "talento" then pre = "Cambiaste de talento. "
        elseif origen == "inicio" then pre = "Estás en el "..g.."° talento. "
        elseif origen == "combate" then pre = "Saliste de combate. " end
        if copia then
            decir(pre..nuevo.." arrancó como copia de "..copia..". Acomodá binds y barras a gusto: se guardan solos cuando vuelvas a "..copia..".")
        elseif botonesN == 0 and teclasN == 0 and perfilesN == 0 then
            decir(pre.."Modo "..nuevo..". Ya estaba todo igual.")
        else
            decir(pre.."Modo "..nuevo..": cambiaron "..cuantos(botonesN, teclasN, perfilesN)..".")
        end
        if rp then NS.perfiles.avisar(rp, nuevo, viejo) end
        avisarFaltan(l)
        avisarTeclas(fallidos)
        avisoCentro(nuevo)
        recargarSiHace(nuevo, rp)
    end
    if md.actual.barras and md.actual.barras[g] then
        ponerBarrasDe(nuevo, g, alTerminar)
    else
        -- este talento todavía no tenía barras en este modo: quedan las de ahora
        md.actual.barras = md.actual.barras or {}
        md.actual.barras[g] = leerBarras()
        pj.enGrupo[g] = nuevo
        alTerminar(0, nil, nil)
    end
    refrescar()
end

-- cuántos botones cambian entre las barras de ahora y unas guardadas
local function diferenciaBarras(vivas, guardadas, ctx)
    local n = 0
    for s = 1, ULTIMO do
        if not esPosesion(s) and not igual(guardadas[s], vivas[s], ctx) then n = n + 1 end
    end
    return n
end

-- Si el juego se cerró de golpe justo después de un cambio, ModosDB quedó
-- con el modo anterior (se guarda al salir o al recargar), pero en el juego
-- ya están los binds y las barras del otro modo. Si lo de ahora se parece más
-- al otro modo que al guardado como en uso, se pregunta. No se toca nada
-- hasta que contestes. true si preguntó.
local function revisarCierre(luego)
    local pj = NS.pj
    local a, o = pj.activo, otro(pj.activo)
    local va = pj.modos[a] and pj.modos[a].actual
    local vo = pj.modos[o] and pj.modos[o].actual
    if not (va and vo) or not NS.preguntarModo then return false end
    local g = grupoActual()
    local vivos = leerBinds()
    local bA = diferenciaBinds(vivos, va.binds or {}, va.bindsFaltan)
    local bO = diferenciaBinds(vivos, vo.binds or {}, vo.bindsFaltan)
    local cA, cO = 0, 0
    local fa, fo = va.barras and va.barras[g], vo.barras and vo.barras[g]
    local conBarras = (pj.enGrupo[g] or a) == a and fa and fo
    if conBarras then
        local ctx = contexto()
        local vivas = leerBarras(ctx)
        cA, cO = diferenciaBarras(vivas, fa, ctx), diferenciaBarras(vivas, fo, ctx)
    end
    if not (bO < bA or cO < cA) then return false end
    NS.preguntando = true
    NS.preguntarModo(o, a, function(elegido)
        NS.preguntando = nil
        if elegido == o then
            pj.activo = o
            pj.enGrupo[g] = o
            decir("Listo: seguís en "..o..". No cambié nada.")
            -- lo que quedó sin poner del cambio que se cortó (botones que siguen
            -- como en "a" y que "o" quiere distintos) se completa
            if conBarras then
                local ctx = contexto()
                local vivas = leerBarras(ctx)
                local foto, hay = {}, false
                for s = 1, ULTIMO do
                    if not esPosesion(s) then
                        if not igual(fo[s], vivas[s], ctx) and igual(fa[s], vivas[s], ctx) then
                            foto[s], hay = fo[s], true
                        else
                            foto[s] = vivas[s]
                        end
                    end
                end
                if hay then
                    local temp = { barras = { [g] = foto } }
                    ponerBarras(temp, g, function(n, faltan)
                        if faltan then
                            vo.faltan = vo.faltan or {}
                            vo.faltan[g] = vo.faltan[g] or {}
                            for s, e in pairs(faltan) do vo.faltan[g][s] = e end
                        end
                        if n > 0 then decir("Completé "..cuantos(n, 0).." que habían quedado a medias.") end
                        if luego then luego() end
                    end)
                    return
                end
            end
        else
            decir("Listo: seguís en "..a..". No cambié nada.")
        end
        refrescar()
        if luego then luego() end
    end)
    return true
end

-- Después de cambiar de talento (o al entrar): primero se terminan las barras
-- que hayan quedado a medias. Si hay un modo atado a este talento, se pasa a
-- ese. Si no, las barras de este talento se ponen como las tiene el modo en
-- uso, guardando antes las que estaban en su dueño.
local revisarGrupo
revisarGrupo = function(origen)
    local pj = NS.pj
    if not (pj and pj.activo) then return end
    local function otraVez() revisarGrupo(origen) end
    if NS.preguntando then return end    -- al contestar se sigue desde acá
    if NS.ocupado then despues(1, "grupo", otraVez); return end
    if InCombatLockdown and InCombatLockdown() then
        NS.revisarLuego = origen
        return
    end
    if GetCursorInfo() or (UnitCastingInfo and UnitCastingInfo("player")) then
        despues(1, "grupo", otraVez)
        return
    end
    NS.revisarLuego = nil
    -- una vez por sesión, en la primera revisión. Si hay barras anotadas a
    -- medias, ModosDB sabe lo que pasó y no hace falta preguntar.
    if not NS.cierreRevisado then
        NS.cierreRevisado = true
        if not pj.aMedias[grupoActual()] and revisarCierre(otraVez) then return end
    end
    local g = grupoActual()
    pj.grupo = g
    if retomar(g, otraVez) then return end
    local vinc = vinculado(g)
    if vinc and vinc ~= pj.activo then return cambiar(vinc, origen) end
    local activo = pj.activo
    local dueno = pj.enGrupo[g]
    if dueno == activo then return end
    local md = modo(activo)
    md.actual = md.actual or { binds = {}, barras = {} }
    md.actual.barras = md.actual.barras or {}
    if dueno == nil then
        -- talento que nunca se vio con Modos: sus barras pasan a ser del modo en uso
        if md.actual.barras[g] then respaldar(md) end
        md.actual.barras[g] = leerBarras()
        pj.enGrupo[g] = activo
        refrescar()
        return
    end
    local mdu = modo(dueno)
    respaldar(mdu)
    mdu.actual = mdu.actual or { binds = {}, barras = {} }
    guardarBarras(mdu.actual, g)
    if not md.actual.barras[g] then
        md.actual.barras[g] = leerBarras()
        pj.enGrupo[g] = activo
        refrescar()
        return
    end
    ponerBarrasDe(activo, g, function(n, faltan, err)
        if err then
            ponerBarrasDe(dueno, g, function()
                decir("No pude poner las barras de "..activo.." en el "..g.."° talento ("..err.."). Quedaron las de "..dueno..".")
            end)
            return
        end
        if n > 0 then decir("Barras de "..activo.." puestas en el "..g.."° talento: cambiaron "..cuantos(n, 0)..".") end
        avisarFaltan(nombres(faltan))
    end)
end
NS.revisarGrupo = revisarGrupo

-- teclas que no se pudieron poner: se reintentan si la tecla sigue libre
local function reintentarBinds(v)
    local f = v.bindsFaltan
    if not (f and next(f)) then return end
    local puestas = {}
    for k, a in pairs(f) do
        local ahora = GetBindingAction(k)
        if ahora == a then
            f[k] = nil
        elseif ahora ~= "" and ahora ~= nil then
            f[k] = nil                         -- pusiste otra cosa en esa tecla: queda lo tuyo
        elseif ponerUno(k, a) then
            f[k] = nil
            puestas[#puestas + 1] = k
        end
    end
    if not next(f) then v.bindsFaltan = nil end
    if #puestas > 0 then
        SaveBindings(BINDS_DEL_PJ)
        table.sort(puestas)
        decir("Puse las teclas que faltaban: "..table.concat(puestas, ", ")..".")
    end
end

-- pone lo que faltaba si ya se puede (llegó el ítem, aprendiste el hechizo,
-- volviste a crear la macro). Solo en botones que siguen vacíos, y de a tandas.
local reintentar
reintentar = function()
    local pj = NS.pj
    if not (pj and pj.activo) or NS.ocupado or NS.preguntando then return end
    if (InCombatLockdown and InCombatLockdown()) or GetCursorInfo() then return end
    local v = modo(pj.activo).actual
    if not v then return end
    reintentarBinds(v)
    local g = grupoActual()
    if pj.enGrupo[g] ~= pj.activo or pj.aMedias[g] then return end
    local f = v.faltan and v.faltan[g]
    if not (f and next(f)) then return end
    local ctx, listos, quedan = contexto(), {}, false
    for s, e in pairs(f) do
        local a = leerBoton(s, ctx)
        if a and a.t ~= "raro" then
            f[s] = nil                         -- pusiste otra cosa ahí: queda lo tuyo
        elseif disponible(e, ctx) then
            if #listos < TANDA then listos[#listos + 1] = s else quedan = true end
        end
    end
    if #listos > 0 then
        local puestos = {}
        local sonido = callar()
        pcall(function()
            for _, s in ipairs(listos) do
                if colocar(s, f[s], ctx) then
                    puestos[#puestos + 1] = nombreDe(f[s])
                    f[s] = nil
                end
            end
        end)
        ClearCursor()
        devolverSonido(sonido)
        if #puestos > 0 then decir("Puse en tu barra lo que faltaba: "..table.concat(puestos, ", ")..".") end
    end
    if not next(f) then v.faltan[g] = nil end
    refrescar()
    if quedan then despues(PAUSA, "faltan", reintentar) end
end
NS.reintentar = reintentar

-- ------------------------------------------------------------ lo que usan los botones
function NS.pedir(m)
    local pj = NS.pj
    if not pj then return end
    if not pj.activo then return adoptar(m) end
    if NS.preguntando then NS.repreguntar(); return end
    if m == pj.activo then
        if NS.pendiente then
            NS.pendiente = nil
            decir("Listo, te quedás en "..m..".")
            refrescar()
        elseif not NS.ocupado then
            decir("Ya estás en "..m..".")
        end
        return
    end
    if NS.ocupado then decir(ESPERA); return end
    if NS.recargando then
        decir("Primero recargá la interfaz (botón Recargar o /reload).")
        NS.pedirRecarga("MODOS_RECARGAR", pj.activo)
        return
    end
    local t = modo(m).talento
    if t and hayDual() and t ~= grupoActual() then
        if InCombatLockdown and InCombatLockdown() then
            decir("En combate no se puede cambiar de talento. Probá cuando salgas.")
            return
        end
        if UnitCastingInfo and UnitCastingInfo("player") then
            decir("Ya estás lanzando algo. Esperá a que termine.")
            return
        end
        decir("Cambiando al "..t.."° talento. Cuando termine, paso a "..m..".")
        SetActiveTalentGroup(t)
        return
    end
    cambiar(m, "botón")
end

function NS.alternar()
    local pj = NS.pj
    if not pj then return end
    if not pj.activo then
        decir("Primero elegí qué modo es tu configuración de ahora: tocá PvE o PvP.")
        return
    end
    NS.pedir(otro(NS.pendiente or pj.activo))
end

-- Versión anterior: cambia la versión guardada por la de antes del último
-- guardado. Si es el modo en uso, la pone. Tocar de nuevo deshace.
function NS.deshacer(m)
    local pj = NS.pj
    if not pj then return end
    m = m or pj.activo
    if not m then decir("Todavía no hay modos guardados."); return end
    local md = modo(m)
    if not md.respaldo then decir(m.." no tiene una versión anterior."); return end
    if NS.preguntando then NS.repreguntar(); return end
    if m ~= pj.activo then
        md.actual, md.respaldo = md.respaldo, md.actual
        decir(m..": volviste a la versión de "..cuando(md.actual.cuando)..". Se usa la próxima vez que pases a "..m..".")
        refrescar()
        return
    end
    local g = grupoActual()
    if hayQueTerminar(g) then return end
    local ok, motivo = sePuede()
    if not ok then
        decir(motivo == "combate" and "En combate no. Probá cuando salgas." or motivo)
        return
    end
    if (pj.enGrupo[g] or m) ~= m then
        -- las barras de este talento todavía son de otro modo: primero se acomodan
        decir(ESPERA)
        revisarGrupo("talento")
        return
    end
    local vivo = copiar(md.actual) or {}
    guardarBinds(vivo)
    guardarBarras(vivo, g)
    vivo.cuando = time()
    local ant = md.respaldo
    local teclasN, errB, fallidos = ponerBinds(ant.binds)
    if errB then
        decir("No pude volver a la versión anterior: falló un bind ("..errB.."). Quedó todo como estaba.")
        refrescar()
        return
    end
    ant.bindsFaltan = fallidos
    md.actual, md.respaldo = ant, vivo
    ant.barras = ant.barras or {}
    if not ant.barras[g] then ant.barras[g] = copiar(vivo.barras[g]) end
    ponerBarrasDe(m, g, function(botonesN, faltan, errBar)
        if errBar then
            md.actual, md.respaldo = vivo, ant
            local _, _, f2 = ponerBinds(vivo.binds)
            vivo.bindsFaltan = f2
            ponerBarrasDe(m, g, function()
                decir("No pude volver a la versión anterior: falló algo en las barras ("..errBar.."). Quedó todo como estaba.")
            end)
            return
        end
        local l = nombres(faltan)
        pj.ultimo = { de = m, a = m, cuando = time(), origen = "anterior", botones = botonesN, teclas = teclasN, faltan = l }
        local c = cuantos(botonesN, teclasN)
        decir(m..": volviste a la versión de "..cuando(ant.cuando)..". "
            ..(c ~= "" and ("Cambiaron "..c..". ") or "Ya estaba todo igual. ")
            .."Tocá Versión anterior de nuevo para deshacer.")
        avisarFaltan(l)
        avisarTeclas(fallidos)
    end)
    refrescar()
end

-- ata un modo a un talento (1 o 2), o lo suelta (nil)
function NS.vincular(m, t)
    local pj = NS.pj
    if not pj then return end
    if t then
        for _, x in ipairs(NS.MODOS) do
            if x ~= m and modo(x).talento == t then modo(x).talento = nil end
        end
    end
    modo(m).talento = t
    refrescar()
end

function NS.info(m)
    local md = modo(m)
    local v = md.actual
    local g = grupoActual()
    local f = v and v.faltan and v.faltan[g]
    local fb = v and v.bindsFaltan
    local lista = nombres(f)
    for _, t in ipairs(nombresTeclas(fb)) do lista[#lista + 1] = "tecla "..t end
    return {
        activo = NS.pj.activo == m,
        guardado = v and v.cuando,
        botones = v and v.barras and v.barras[g] and contar(v.barras[g]) or nil,
        teclas = v and v.binds and contar(v.binds) or nil,
        faltan = contar(f) + contar(fb),
        nombresFaltan = lista,
        talento = md.talento,
        anterior = md.respaldo and md.respaldo.cuando,
    }
end

function NS.imprimirEstado()
    local pj = NS.pj
    if not pj then return end
    decir("Versión "..NS.VERSION..". En uso: "..(pj.activo or "ninguno todavía")
        ..(hayDual() and (" · talento "..grupoActual().."°") or ""))
    for _, m in ipairs(NS.MODOS) do
        local i = NS.info(m)
        if i.guardado then
            decir(m..": guardado "..cuando(i.guardado)..", "..(i.botones or 0).." botones, "..(i.teclas or 0).." teclas"
                ..(i.faltan > 0 and (", faltan "..i.faltan) or "")
                ..(i.talento and (", atado al "..i.talento.."° talento") or ""))
        else
            decir(m..": sin guardar.")
        end
    end
end

-- ------------------------------------------------------------ eventos
local function iniciarDB()
    if type(ModosDB) ~= "table" then ModosDB = {} end
    ModosDB.pj = ModosDB.pj or {}
    ModosDB.ui = ModosDB.ui or {}
    ModosDB.v = 1
    NS.db = ModosDB
end

local function iniciarPJ()
    local clave = (UnitName("player") or "?").." - "..(GetRealmName() or "?")
    ModosDB.pj[clave] = ModosDB.pj[clave] or {}
    local pj = ModosDB.pj[clave]
    pj.modos = pj.modos or {}
    pj.enGrupo = pj.enGrupo or {}
    if type(pj.aMedias) ~= "table" or pj.aMedias.g then pj.aMedias = {} end
    NS.pj, NS.clave = pj, clave
    if not pj.activo and not pj.saludado then
        pj.saludado = true
        decir("Tocá PvE o PvP en la barrita para guardar lo que tenés ahora como ese modo. /modos ayuda explica el resto.")
    end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
                     "ACTIVE_TALENT_GROUP_CHANGED", "BAG_UPDATE", "LEARNED_SPELL_IN_TAB", "UPDATE_MACROS",
                     "COMPANION_LEARNED", "EQUIPMENT_SETS_CHANGED", "PLAYER_EQUIPMENT_CHANGED" }) do
    ev:RegisterEvent(e)
end
ev:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local nombre = ...
        if nombre == ADDON then iniciarDB() end
        return
    end
    if event == "PLAYER_LOGIN" then
        if not NS.db then iniciarDB() end
        iniciarPJ()
        if NS.perfiles and NS.perfiles.perfilAlEntrar then NS.perfiles.perfilAlEntrar() end
        if NS.armarInterfaz then NS.armarInterfaz() end
        refrescar()
        return
    end
    if not NS.pj then return end
    if event == "PLAYER_ENTERING_WORLD" then
        if not NS.entro then
            NS.entro = true
            despues(3, "grupo", function() revisarGrupo("inicio") end)
            -- la primera vez en este personaje: ¿barras con Bartender o de Blizzard?
            -- (con el asistente de primeros pasos pendiente, se contesta ahí)
            if NS.barras and NS.barras.falta() and not (NS.instalar and NS.instalar.pendiente()) then
                despues(4, "barras", function()
                    if NS.barras.falta() then NS.barras.preguntar() end
                end)
            end
        end
        -- MoveAnything reacomoda todo en cada pantalla de carga con su tabla de
        -- siempre: después se vuelve a poner la del modo en uso
        if NS.perfiles then despues(2, "moveanything", NS.perfiles.alEntrar) end
    elseif event == "ACTIVE_TALENT_GROUP_CHANGED" then
        -- se espera un momento a que el juego termine de cargar las barras del talento
        despues(1.5, "grupo", function() revisarGrupo("talento") end)
    elseif event == "PLAYER_REGEN_ENABLED" then
        despues(0.5, "combate", function()
            if NS.trabajoEnPausa then seguirTrabajo() end
            if NS.revisarLuego then revisarGrupo(NS.revisarLuego) end
            if NS.perfiles and NS.perfiles.entrarLuego then NS.perfiles.alEntrar() end
            if NS.pendiente then
                local m = NS.pendiente
                if m ~= NS.pj.activo then cambiar(m, "combate") else NS.pendiente = nil; refrescar() end
            end
            reintentar()
        end)
    else
        despues(1, "faltan", reintentar)
    end
end)

-- ------------------------------------------------------------ teclas y comandos
BINDING_HEADER_MODOS = "Modos"
BINDING_NAME_MODOS_ALTERNAR = "Alternar PvE y PvP"
BINDING_NAME_MODOS_PVE = "Pasar a PvE"
BINDING_NAME_MODOS_PVP = "Pasar a PvP"
function Modos_Alternar() NS.alternar() end
function Modos_Pasar(m) NS.pedir(m) end

SLASH_MODOS1 = "/modos"
SLASH_MODOS2 = "/modo"
SlashCmdList["MODOS"] = function(msg)
    if not NS.pj then return end
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if cmd == "pvp" then NS.pedir("PvP")
    elseif cmd == "pve" then NS.pedir("PvE")
    elseif cmd == "alternar" or cmd == "cambiar" then NS.alternar()
    elseif cmd == "anterior" or cmd == "deshacer" then
        NS.deshacer((arg == "pvp" and "PvP") or (arg == "pve" and "PvE") or nil)
    elseif cmd == "barrita" then
        if NS.alternarBarrita then NS.alternarBarrita() end
    elseif cmd == "estado" then NS.imprimirEstado()
    elseif cmd == "preset" then
        -- vuelve a poner la UI armada del modo en uso
        if not NS.pj.activo or not (NS.presets and NS.presets[NS.pj.activo]) then
            decir("Este modo no tiene UI armada todavía.")
        elseif InCombatLockdown and InCombatLockdown() then
            decir("En combate no.")
        else
            NS.pj.presets = NS.pj.presets or {}
            NS.pj.presets[NS.pj.activo] = nil
            local rp = NS.perfiles.aplicar(NS.pj.activo)
            NS.perfiles.avisar(rp, NS.pj.activo, NS.pj.activo)
            NS.recargarSiHace(NS.pj.activo, rp)
        end
    elseif cmd == "listo" then
        -- (1.0.15) lo que te falta antes del pull
        if NS.listo then NS.listo.comando() end
    elseif cmd == "reiniciar" then
        -- (1.0.13) el modo en uso desde cero (pregunta antes)
        if not NS.pj.activo or not (NS.presets and NS.presets[NS.pj.activo]) then
            decir("Este modo no tiene UI armada todavía.")
        elseif InCombatLockdown and InCombatLockdown() then
            decir("En combate no.")
        else
            NS.preguntarReiniciar(NS.pj.activo)
        end
    elseif cmd == "addons" then
        if NS.abrirAddons then NS.abrirAddons() end
    elseif cmd == "oscuro" then
        if NS.aspecto then
            local si = NS.aspecto.alternar()
            decir("Aspecto de Bypass (bordes oscuros y minimapa) "..(si and "prendido" or "apagado")..". Toma efecto al recargar (/reload).")
        end
    elseif cmd == "barras" then
        -- (1.0.24) /modos barras ver: todas a la vista para binds. esconder: como estaban
        if NS.barras and (arg == "ver" or arg == "mostrar" or arg == "bind" or arg == "binds") then NS.barras.verTodas(true)
        elseif NS.barras and (arg == "esconder" or arg == "ocultar") then
            if not NS.barras.verTodas(false) then decir("Barras: ya estaban como las dejaste.") end
        elseif NS.barras then NS.barras.preguntar() end
    elseif cmd == "instalar" or cmd == "asistente" then
        if NS.instalar then NS.instalar.abrir() end
    elseif cmd == "escala" then
        if NS.aspecto then
            local fija = NS.aspecto.alternarEscala()
            decir(fija and "Escala de la interfaz: la de Modos (1080 de alto). Si cambió, hay que recargar."
                or "Escala de la interfaz: libre, Modos no la toca. Ojo: las posiciones de Modos están pensadas para 1080 de alto.")
        end
    elseif cmd == "auras" then
        -- (0.9.3) qué paquetes de WeakAuras encontró y en qué modo cargan
        -- (1.0) /modos auras reinstalar: vuelve a poner las que borraste
        if NS.auras and (arg == "reinstalar" or arg == "instalar") then
            NS.auras.reinstalar()
        elseif NS.auras then
            local r = NS.auras.resumen()
            decir("WeakAuras de PvE (cargan solo en PvE): "..(#r.PvE > 0 and table.concat(r.PvE, ", ") or "ninguna")..".")
            decir("WeakAuras de PvP (cargan solo en PvP): "..(#r.PvP > 0 and table.concat(r.PvP, ", ") or "ninguna")..".")
            decir("Las demás (anclas, raids, utilidades y las tuyas) cargan siempre. Se instalan solas con cada personaje (también la de su clase). Si borraste alguna: /modos auras reinstalar.")
            if NS.pj and NS.pj.activo and NS.auras.hace(NS.pj.activo) then
                decir("Hay auras que todavía no están acomodadas a "..NS.pj.activo..": se acomodan al recargar (/reload).")
            end
        end
    elseif cmd == "cds" or cmd == "cd" then
        -- (1.0.22) con guardar, cargar, borrar o perfiles: los perfiles (el nombre como lo escribiste)
        if NS.cds and NS.cds.comando then NS.cds.comando((msg or ""):match("^%s*%S+%s*(.-)%s*$"))
        elseif NS.abrirCDs then NS.abrirCDs() end
    elseif cmd == "rol" then
        -- rol de PvE del talento en uso (sin nada: pregunta)
        local rol = (arg == "tank" or arg == "tanque") and "Tank" or (arg == "dps" and "DPS")
            or ((arg == "heal" or arg == "healer") and "Heal") or nil
        if NS.rol then
            if rol then NS.rol.poner(rol) else NS.rol.preguntar() end
        end
    elseif cmd == "ayuda" then
        decir("/modos abre la ventana. /modos pve y /modos pvp cambian de modo. /modos alternar pasa al otro.")
        decir("/modos anterior vuelve a la versión anterior del modo en uso. /modos barrita la muestra u oculta. /modos estado resume lo guardado.")
        decir("/modos cds elige qué hechizos y abalorios ves al medio (aura Mis CDs). /modos cds guardar <nombre> y /modos cds cargar <nombre> guardan y ponen perfiles de Mis CDs (como ABS). /modos addons elige qué addons van en cada modo. /modos barras elige barras con Bartender o de Blizzard, a la vista o escondidas. /modos barras ver pone todas a la vista para poner binds (/modos barras esconder las deja como estaban). /modos instalar abre el asistente de primeros pasos (addons, modo, barras y rol). /modos auras muestra qué WeakAuras van con cada modo (se instalan solas, también la de tu clase). /modos auras reinstalar vuelve a poner las que borraste. /modos escala deja libre (o vuelve a fijar) la escala de la interfaz. /modos rol tank, /modos rol dps o /modos rol heal elige el rol de PvE del talento en uso (sin nada: pregunta).")
        decir("/modos listo muestra lo que te falta antes del pull (frasco, comida, buffs, lo de tu clase, piedra, reparar). Sale solo en mazmorras y bandas al entrar, con la revisión de listos y con la cuenta del pull de DBM.")
        decir("/modos preset vuelve a poner encima la UI armada del modo en uso. /modos reiniciar la arma desde cero: los perfiles de Modos de ese modo vuelven a como vienen y se pone todo de nuevo (pregunta antes).")
        decir("También podés ponerle teclas en Key Bindings, sección Modos. Esas teclas nunca cambian con el modo.")
    else
        if NS.abrirVentana then NS.abrirVentana() end
    end
end
