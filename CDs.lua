-- Modos · Mis CDs: elegís qué hechizos y abalorios querés ver al medio de la
-- pantalla (/modos cds) y en qué lugar de dos filas de 12 (botón Orden). La
-- lista es de cada personaje y de cada modo (una para PvE y otra para PvP, 12/10):
-- /modos cds edita la del modo en uso.
-- (1.0.22) perfiles con nombre, como Action Bar Saver (24/10: "reseteo mucho los
-- talentos para PvE, PvP, distintos tipos de contenido y builds... quiero guardar un
-- perfil como si fuera ABS"): guardás la lista con un nombre y la cargás cuando
-- quieras. Son de tu clase (todos tus personajes de esa clase los ven). La 1.0.21
-- cambiaba sola por rama de talentos: se sacó (no sirve si cambiás de build seguido). Las auras la leen con ModosMisCDs(modo)
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
local function copia(t)
    local r = {}
    for k, v in pairs(t or {}) do r[k] = v end
    return r
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
    local d = pj.misCDsPor[m]
    -- (1.0.22) la de la 1.0.21 (una por rama de talentos): queda la del último que usaste
    if d.ramas then
        local u = d.ultima and d.ramas[d.ultima]
        if u then d.lista, d.orden = u.lista or {}, u.orden or {} end
        d.ramas, d.ultima = nil, nil
    end
    return d
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

-- todo lo que se puede elegir: los dos abalorios, los hechizos que no son pasivos
-- y (1.0.32) los de tu mascota, de cualquier clase (Call of the Wild, Spell Lock,
-- Gnaw, Freeze...): salen del libro de la mascota que tengas afuera ("pet"), así
-- que aparecen con ella y se van si la guardás o sacás otra que no los tiene
function CD.disponibles()
    local l, visto = {}, {}
    for t = 1, (GetNumSpellTabs and GetNumSpellTabs() or 0) do
        local _, _, desde, cuantos = GetSpellTabInfo(t)
        for i = (desde or 0) + 1, (desde or 0) + (cuantos or 0) do
            local nombre = GetSpellName(i, "spell")
            local pasivo = IsPassiveSpell and IsPassiveSpell(i, "spell")
            if nombre and not pasivo and not visto[nombre] then
                visto[nombre] = true
                l[#l + 1] = { clave = "s:" .. nombre, nombre = nombre, indice = i, libro = "spell",
                              icono = GetSpellTexture and GetSpellTexture(i, "spell") }
            end
        end
    end
    local deMascota = HasPetSpells and HasPetSpells() or 0
    local vistoM = {}
    for i = 1, tonumber(deMascota) or 0 do
        local nombre = GetSpellName(i, "pet")
        local pasivo = IsPassiveSpell and IsPassiveSpell(i, "pet")
        if nombre and not pasivo and not vistoM[nombre] then
            vistoM[nombre] = true
            l[#l + 1] = { clave = "p:" .. nombre, nombre = nombre, etiqueta = "Mascota: " .. nombre, indice = i,
                          libro = "pet", icono = GetSpellTexture and GetSpellTexture(i, "pet") }
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
-- (1.0.32) los de la mascota van en la barra de la mascota (10 botones)
local function teclaMascota(x)
    if not (GetPetActionInfo and GetBindingKey) then return nil end
    for i = 1, 10 do
        local nombre, _, _, esFicha = GetPetActionInfo(i)
        if nombre and not esFicha and nombre == x.nombre then
            local k = GetBindingKey("BONUSACTIONBUTTON" .. i) or GetBindingKey("CLICK BT4PetButton" .. i .. ":LeftButton")
            if k then return corta(k) end
        end
    end
end
function CD.tecla(x)
    if x.libro == "pet" then return teclaMascota(x) end
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
    local ck = m
    if cache[ck] then return cache[ck] end
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
                              tipo = x.ranura and "ranura" or (x.libro == "pet" and "mascota" or "hechizo"),
                              libro = x.libro, tecla = CD.tecla(x), icono = x.icono }
            end
        end
    end
    cache[ck] = l
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
    -- (1.0.25) mientras ponés binds con todas las barras a la vista, tampoco (no las tapa)
    if NS.barras and NS.barras.todasAVista and NS.barras.todasAVista() then return {} end
    return CD.lista(m)
end

-- (1.0.23) como las barras de acción: si está fuera de rango del objetivo, si no
-- tenés maná y si no se puede usar todavía (Kill Shot o Execute con el objetivo arriba
-- del 20%, otra postura, Revenge sin bloquear...). Lo usan las auras de Mis CDs para el
-- color del ícono. x: uno de la lista de ModosMisCDs. Devuelve lejos, sinMana, inusable.
function ModosMisCDsUso(x)
    if type(x) ~= "table" then return false, false, false end
    local hayObjetivo = UnitExists and UnitExists("target")
    local lejos, sinMana, usable = false, false, true
    if x.tipo == "ranura" then
        local id = GetInventoryItemID and GetInventoryItemID("player", x.ranura)
        if id and IsUsableItem then usable = IsUsableItem(id) and true or false end
        if id and hayObjetivo and IsItemInRange then lejos = IsItemInRange(id, "target") == 0 end
    elseif x.indice then
        local libro = x.libro or "spell"
        if IsUsableSpell then
            local u, m = IsUsableSpell(x.indice, libro)
            usable = u and true or false
            sinMana = (not u) and m and true or false
        end
        if hayObjetivo and IsSpellInRange then lejos = IsSpellInRange(x.indice, libro, "target") == 0 end
    end
    return lejos and true or false, sinMana, (not usable) and not sinMana
end

-- (1.0.32) la recarga y el ícono de uno de la lista, sea hechizo tuyo, de la
-- mascota o abalorio. Lo usan las auras de Mis CDs (así un tipo nuevo no pide
-- cambiar las auras). Devuelve inicio, duración, prendido, ícono.
function ModosMisCDsCD(x)
    if type(x) ~= "table" then return 0, 0, 1, nil end
    if x.tipo == "ranura" then
        local a, b, c = GetInventoryItemCooldown("player", x.ranura)
        return a, b, c, GetInventoryItemTexture("player", x.ranura)
    end
    local libro = x.libro or "spell"
    if not x.indice then return 0, 0, 1, x.icono end
    local a, b, c = GetSpellCooldown(x.indice, libro)
    return a, b, c, (GetSpellTexture and GetSpellTexture(x.indice, libro)) or x.icono
end

-- el rango cambia al moverte y no hay evento para eso: con objetivo, cada 0,2 s se
-- les avisa a las auras de Mis CDs (como hacen las barras de acción)
CD.CADA = 0.2
-- (1.0.32) cuándo termina la primera recarga de la mascota de la lista: al terminar
-- no llega ningún evento, así que el reloj les avisa a las auras en ese momento
function CD.calcularFinMascota()
    local fin, ahora = nil, GetTime and GetTime() or 0
    for _, x in ipairs(NS.pj and CD.lista() or {}) do
        if x.libro == "pet" and x.indice and GetSpellCooldown then
            local a, b, c = GetSpellCooldown(x.indice, "pet")
            if c == 1 and b and b > 1.6 and a and a + b > ahora and (not fin or a + b < fin) then fin = a + b end
        end
    end
    CD.finMascota = fin
    return fin
end
local reloj = CreateFrame("Frame")
local espera = 0
reloj:SetScript("OnUpdate", function(_, dt)
    espera = espera - (dt or 0)
    if espera > 0 then return end
    espera = CD.CADA
    if CD.finMascota and GetTime and GetTime() >= CD.finMascota then
        CD.calcularFinMascota()
        if WeakAuras and WeakAuras.ScanEvents then pcall(WeakAuras.ScanEvents, "MODOS_MISCDS_USO") end
    end
    if not (WeakAuras and WeakAuras.ScanEvents and UnitExists and UnitExists("target")) then return end
    local l = NS.pj and ModosMisCDs(CD.modo())
    if l and #l > 0 then pcall(WeakAuras.ScanEvents, "MODOS_MISCDS_USO") end
end)
CD.reloj = reloj

-- cambió el libro, las barras, los binds o lo que tenés puesto: se arma de nuevo
-- (1.0.32) y la mascota: la sacás, la guardás, cambiás de mascota o de su barra.
-- Su recarga (PET_BAR_UPDATE_COOLDOWN) solo vuelve a mirar los íconos
local ev = CreateFrame("Frame")
for _, e in ipairs({ "SPELLS_CHANGED", "ACTIONBAR_SLOT_CHANGED", "UPDATE_BINDINGS", "PLAYER_EQUIPMENT_CHANGED",
                     "PLAYER_ENTERING_WORLD", "UNIT_PET", "PET_BAR_UPDATE", "PET_BAR_UPDATE_COOLDOWN" }) do
    ev:RegisterEvent(e)
end
ev:SetScript("OnEvent", function(_, event, unidad)
    if event == "UNIT_PET" and unidad ~= "player" then return end
    if event == "PET_BAR_UPDATE_COOLDOWN" then
        CD.calcularFinMascota()
        if WeakAuras and WeakAuras.ScanEvents then pcall(WeakAuras.ScanEvents, "MODOS_MISCDS_USO") end
        return
    end
    avisar()
    if (event == "UNIT_PET" or event == "PET_BAR_UPDATE") and CD.refrescar then CD.refrescar() end
end)

-- ------------------------------------------------------------ perfiles (como ABS)
-- ModosDB.cdsPerfiles[clase][nombre en minúscula] = { nombre, lista, orden, cuando }
local function clase()
    if not UnitClass then return "?" end
    local _, c = UnitClass("player")
    return c or "?"
end
local function perfilesClase(crear)
    if not ModosDB then return nil end
    if crear then
        ModosDB.cdsPerfiles = ModosDB.cdsPerfiles or {}
        ModosDB.cdsPerfiles[clase()] = ModosDB.cdsPerfiles[clase()] or {}
    end
    return ModosDB.cdsPerfiles and ModosDB.cdsPerfiles[clase()]
end
local function limpio(nombre)
    nombre = tostring(nombre or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if nombre == "" then return nil end
    return nombre, nombre:lower()
end
local function cuantos(lista)
    local n = 0
    for _ in pairs(lista or {}) do n = n + 1 end
    return n
end
-- los perfiles de tu clase, por nombre
function CD.perfiles()
    local l = {}
    for _, p in pairs(perfilesClase() or {}) do
        l[#l + 1] = { nombre = p.nombre, cuantos = cuantos(p.lista), cuando = p.cuando }
    end
    table.sort(l, function(a, b) return a.nombre:lower() < b.nombre:lower() end)
    return l
end
function CD.perfil(nombre)
    local _, k = limpio(nombre)
    local t = perfilesClase()
    return k and t and t[k]
end
-- el último perfil que guardaste o cargaste en este modo, y si la lista cambió desde entonces
function CD.perfilEnUso(m)
    local pj = NS.pj
    m = m or CD.modo()
    local n = pj and pj.cdsPerfil and pj.cdsPerfil[m]
    local p = n and CD.perfil(n)
    if not p then return nil end
    local d = datos(m)
    local igual = true
    for k in pairs(d.lista) do if not p.lista[k] then igual = false end end
    for k in pairs(p.lista) do if not d.lista[k] then igual = false end end
    for i = 1, CD.CASILLAS do if d.orden[i] ~= p.orden[i] then igual = false end end
    return p.nombre, igual
end
local function anotarEnUso(nombre)
    local pj = NS.pj
    pj.cdsPerfil = pj.cdsPerfil or {}
    pj.cdsPerfil[CD.modo()] = nombre
end
-- guarda la lista del modo en uso con ese nombre (si ya está, la reemplaza)
function CD.guardar(nombre)
    local n, k = limpio(nombre)
    local d = datos()
    if not (n and d) then return false end
    local t = perfilesClase(true)
    if not t then return false end
    local habia = t[k] ~= nil
    t[k] = { nombre = n, lista = copia(d.lista), orden = copia(d.orden), cuando = time and time() or nil }
    anotarEnUso(n)
    return true, habia
end
-- pone ese perfil como la lista del modo en uso
function CD.cargar(nombre)
    local p = CD.perfil(nombre)
    local d = datos()
    if not (p and d) then return false end
    d.lista, d.orden = copia(p.lista), copia(p.orden)
    anotarEnUso(p.nombre)
    avisar()
    return true, p.nombre
end
function CD.borrar(nombre)
    local _, k = limpio(nombre)
    local t = perfilesClase()
    if not (k and t and t[k]) then return false end
    local n = t[k].nombre
    t[k] = nil
    local pj = NS.pj
    for m, x in pairs(pj and pj.cdsPerfil or {}) do if x:lower() == k then pj.cdsPerfil[m] = nil end end
    return true, n
end

-- /modos cds [guardar|cargar|borrar|perfiles] [nombre]
local ALIAS = { guardar = "guardar", save = "guardar", cargar = "cargar", restore = "cargar", load = "cargar",
                poner = "cargar", borrar = "borrar", delete = "borrar", perfiles = "perfiles", lista = "perfiles",
                list = "perfiles" }
function CD.comando(texto)
    local sub, resto = (texto or ""):match("^%s*(%S*)%s*(.-)%s*$")
    local que = ALIAS[(sub or ""):lower()]
    local decir = NS.decir or function() end
    if not que then
        if NS.abrirCDs then NS.abrirCDs() end
        return
    end
    if que == "perfiles" then
        local l = CD.perfiles()
        if #l == 0 then decir("Mis CDs: no hay perfiles guardados de tu clase. /modos cds guardar <nombre>.") return end
        local t = {}
        for _, p in ipairs(l) do t[#t + 1] = p.nombre .. " (" .. p.cuantos .. ")" end
        decir("Perfiles de Mis CDs de tu clase: " .. table.concat(t, ", ") .. ".")
        return
    end
    if resto == "" then decir("Mis CDs: falta el nombre. Por ejemplo: /modos cds " .. que .. " Holy PvP") return end
    if que == "guardar" then
        local ok, habia = CD.guardar(resto)
        if ok then
            decir(("Mis CDs: guardé la lista de %s como \"%s\"%s."):format(CD.modo(), resto, habia and " (reemplacé la que había)" or ""))
        end
    elseif que == "cargar" then
        local ok, n = CD.cargar(resto)
        if ok then decir(("Mis CDs: puse \"%s\" en %s."):format(n, CD.modo()))
        else decir(("Mis CDs: no hay un perfil \"%s\" de tu clase. /modos cds perfiles los lista."):format(resto)) end
    elseif que == "borrar" then
        local ok, n = CD.borrar(resto)
        if ok then decir(("Mis CDs: borré \"%s\"."):format(n))
        else decir(("Mis CDs: no hay un perfil \"%s\" de tu clase."):format(resto)) end
    end
    if CD.refrescar then CD.refrescar() end
end

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

local FILAS_P = 9         -- perfiles por página
local function refrescarPerfiles()
    local l = CD.perfiles()
    local enUso, igual = CD.perfilEnUso()
    v.paginasP = math.max(1, math.ceil(#l / FILAS_P))
    if v.paginaP > v.paginasP then v.paginaP = v.paginasP end
    local base = (v.paginaP - 1) * FILAS_P
    for i, r in ipairs(v.filasP) do
        local p = l[base + i]
        r.p = p
        r.seguro = nil
        if p then
            local marca = (enUso and p.nombre == enUso) and E.cod(C.ok, igual and "  · en uso" or "  · en uso, con cambios sin guardar") or ""
            r.nombre:SetText(p.nombre .. marca)
            r.cuantos:SetText(p.cuantos .. (p.cuantos == 1 and " CD" or " CDs"))
            r.borrar:SetText("Borrar")
            r.nombre:Show(); r.cuantos:Show(); r.cargar:Show(); r.borrar:Show()
        else
            r.nombre:Hide(); r.cuantos:Hide(); r.cargar:Hide(); r.borrar:Hide()
        end
    end
    mostrar(v.sinPerfiles, #l == 0)
    v.pag:SetText(v.paginasP > 1 and (v.paginaP .. " / " .. v.paginasP) or "")
    if v.paginasP > 1 then v.ant:Show(); v.sig:Show() else v.ant:Hide(); v.sig:Hide() end
end

local function refrescar()
    if not (v and v:IsShown()) then return end
    if v.titulo then
        local enUso = CD.perfilEnUso()
        v.titulo:SetText("Mis CDs " .. CD.modo() .. (enUso and (" · " .. enUso) or "") .. "  "
            .. E.cod(C.inactivo, "· " .. (UnitName("player") or "")))
    end
    local ordenando, perfiles = v.ordenando, v.perfilesVista
    local lista = not (ordenando or perfiles)
    for _, c in ipairs(v.casillas) do if not lista then c:Hide(); c.icono:Hide(); c.texto:Hide() end end
    for _, b in ipairs(v.slots) do mostrar(b, ordenando) end
    mostrar(v.ayudaOrden, ordenando)
    for _, x in ipairs(v.piezasP) do mostrar(x, perfiles) end
    if not perfiles then
        for _, r in ipairs(v.filasP) do r.nombre:Hide(); r.cuantos:Hide(); r.cargar:Hide(); r.borrar:Hide() end
        v.sinPerfiles:Hide()
    end
    mostrar(v.limpiar, lista)
    v.botonOrden:SetText(ordenando and "Lista" or "Orden")
    v.botonPerfiles:SetText(perfiles and "Lista" or "Perfiles")
    if perfiles then refrescarPerfiles() return end
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
            c.texto:SetText(x.etiqueta or x.nombre)
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
    h:SetText("Tildá lo que querés ver con su CD (aura Mis CDs). Abalorios al final de la lista. Con Orden elegís el lugar de cada uno. Se guarda para este personaje y este modo. Con Perfiles la guardás con un nombre para cada build.")
    f.ayuda = h
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
    f.ant:SetScript("OnClick", function()
        if f.perfilesVista then
            if f.paginaP > 1 then f.paginaP = f.paginaP - 1; refrescar() end
        elseif f.pagina > 1 then f.pagina = f.pagina - 1; refrescar() end
    end)
    f.sig = E.boton(f, ">", 28, 20)
    f.sig:SetPoint("LEFT", f.ant, "RIGHT", 4, 0)
    f.sig:SetScript("OnClick", function()
        if f.perfilesVista then
            if f.paginaP < f.paginasP then f.paginaP = f.paginaP + 1; refrescar() end
        elseif f.pagina < f.paginas then f.pagina = f.pagina + 1; refrescar() end
    end)
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
        f.perfilesVista = nil
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
    f.limpiar = limpiar
    -- (1.0.22) perfiles con nombre (como Action Bar Saver)
    f.botonPerfiles = E.boton(f, "Perfiles", 80, 20)
    f.botonPerfiles:SetPoint("BOTTOMRIGHT", -188, 14)
    f.botonPerfiles:SetScript("OnClick", function()
        f.perfilesVista = not f.perfilesVista
        f.ordenando = nil
        f.elegida = nil
        refrescar()
    end)
    f.piezasP = {}
    local ayP = E.texto(f, "chico")
    ayP:SetPoint("TOPLEFT", 16, -84)
    ayP:SetWidth(ANCHO - 32)
    ayP:SetText("Guardá la lista de este modo con un nombre y cargala cuando cambies de build, como Action Bar Saver. Son de tu clase: los ven todos tus personajes de esa clase. En una macro: /modos cds cargar <nombre>.")
    f.piezasP[#f.piezasP + 1] = ayP
    local caja = CreateFrame("EditBox", "ModosCDsNombre", f)
    caja:SetWidth(300); caja:SetHeight(22)
    caja:SetPoint("TOPLEFT", 16, -124)
    caja:SetBackdrop(E.BD)
    caja:SetBackdropColor(C.caja[1], C.caja[2], C.caja[3], 1)
    caja:SetBackdropBorderColor(C.bordeBoton[1], C.bordeBoton[2], C.bordeBoton[3], 1)
    caja:SetFontObject(E.F.texto)
    caja:SetTextInsets(6, 6, 0, 0)
    caja:SetAutoFocus(false)
    caja:SetMaxLetters(40)
    local function guardarCaja()
        local n = caja:GetText()
        if CD.guardar(n) then
            caja:SetText("")
            caja:ClearFocus()
            if NS.decir then NS.decir(("Mis CDs: guardé la lista de %s como \"%s\"."):format(CD.modo(), (limpio(n)))) end
            refrescar()
        end
    end
    caja:SetScript("OnEnterPressed", guardarCaja)
    caja:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.caja = caja
    f.piezasP[#f.piezasP + 1] = caja
    local guardar = E.boton(f, "Guardar", 90, 22, "pri")
    guardar:SetPoint("LEFT", caja, "RIGHT", 8, 0)
    guardar:SetScript("OnClick", guardarCaja)
    guardar:SetScript("OnEnter", function(self)
        E.ayuda(self, "Guardar", "Guarda la lista de ahora con ese nombre. Si ya hay uno con ese nombre, lo reemplaza.")
    end)
    guardar:SetScript("OnLeave", E.sinAyuda)
    f.guardar = guardar
    f.piezasP[#f.piezasP + 1] = guardar
    f.sinPerfiles = E.texto(f, "chico")
    f.sinPerfiles:SetPoint("TOPLEFT", 16, -164)
    f.sinPerfiles:SetText("Todavía no guardaste ninguno.")
    f.filasP = {}
    for i = 1, FILAS_P do
        local y = -158 - (i - 1) * (ALTO_FILA + 4)
        local r = {}
        r.nombre = E.texto(f, "texto")
        r.nombre:SetPoint("TOPLEFT", 16, y - 3)
        r.nombre:SetWidth(330)
        r.cuantos = E.texto(f, "chico")
        r.cuantos:SetPoint("TOPLEFT", 356, y - 4)
        r.cargar = E.boton(f, "Cargar", 80, 20)
        r.cargar:SetPoint("TOPLEFT", 420, y)
        r.cargar:SetScript("OnClick", function()
            if r.p and CD.cargar(r.p.nombre) then
                if NS.decir then NS.decir(("Mis CDs: puse \"%s\" en %s."):format(r.p.nombre, CD.modo())) end
                refrescar()
            end
        end)
        r.borrar = E.boton(f, "Borrar", 80, 20, "riesgo")
        r.borrar:SetPoint("TOPLEFT", 504, y)
        -- dos clics para borrar (que no se borre sin querer)
        r.borrar:SetScript("OnClick", function()
            if not r.p then return end
            if not r.seguro then r.seguro = true; r.borrar:SetText("¿Seguro?") return end
            CD.borrar(r.p.nombre)
            refrescar()
        end)
        f.filasP[i] = r
    end
    f.pagina, f.paginaP = 1, 1
    f:SetScript("OnShow", refrescar)
    f:Hide()
    v = f
end

function NS.abrirCDs()
    if not NS.pj then return end
    crear()
    if v:IsShown() then v:Hide() else v:Show(); refrescar() end
end
