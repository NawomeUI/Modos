-- Modos · Addons: qué addons se prenden en cada modo.
--
-- En 3.3.5 un addon no se puede prender ni apagar en caliente: el cambio toma
-- efecto con /reload. Por eso, al terminar un cambio de modo, si algún addon
-- tiene que cambiar, Modos lo prende o apaga (solo para este personaje, como
-- la lista de addons de la pantalla de personajes) y recarga la interfaz.
--
-- De fábrica (la UI preconfigurada): Cell, DBM, MRT, xCT+ y MerfinUI solo en PvE.
-- EasyFrames solo en PvP (en PvE: marcos de ElvUI y casteo de la WA de clase).
-- (1.0.36) Quartz en los dos: en PvE hace los casteos del objetivo y del foco.
-- Compact Raid Frames con Enhanced Raid Frames, Gladius, OmniBar, Diminishing
-- Returns, TrinketCDs, SoundAlerter (o GladiatorlosSA) y BattlegroundTargets solo en PvP.
-- Lo que no está en la lista no se toca nunca.
-- Cada personaje puede cambiar cualquiera en la ventana "Addons por modo":
-- PvE, PvP o Ambos (Ambos = Modos no lo toca).

local _, NS = ...

local A = {}
NS.addons = A

A.FABRICA = {
    Cell = "PvE",
    MerfinUI = "PvE",
    MRT = "PvE",                       -- Method Raid Tools (lo configura MerfinUI)
    ["xCT+"] = "PvE",                  -- texto de combate de MerfinUI
    PallyPower = "PvE",                -- (1.0.1) bendiciones de paladín en banda
    CompactRaidFrame = "PvP",
    EnhancedRaidFrames = "PvP",
    Gladius = "PvP",
    OmniBar = "PvP",
    OmniBar_Options = "PvP",
    DiminishingReturns = "PvP",
    DiminishingReturns_Config = "PvP",
    TrinketCDs = "PvP",
    SoundAlerter = "PvP",              -- voces de los CDs enemigos (el que usa él)
    GladiatorlosSA = "PvP",            -- lo mismo, por si algún personaje lo tiene
    BattlegroundTargets = "PvP",       -- lista de enemigos en campos de batalla
    -- (12/10) en PvE los marcos son los de ElvUI y el casteo lo hace la WA de clase
    EasyFrames = "PvP",
    Quartz = "ambos",                  -- (1.0.36) en PvE: objetivo y foco

}
-- por comienzo del nombre: DBM-Core y todos sus módulos
A.PREFIJOS = { { "DBM-", "PvE" } }
A.REGLAS = { "PvE", "PvP", "ambos" }

local function reglas()
    local pj = NS.pj
    pj.addons = pj.addons or {}
    return pj.addons
end

-- Barras: cada personaje elige una vez si usa Bartender4 o las barras de
-- Blizzard (por ejemplo, uno con todos los binds puestos en las de Blizzard).
-- "bartender": Bartender4 prendido en los dos modos. "blizzard": apagado
-- siempre, y la UI armada no le toca nada. Sin elegir: Modos no lo toca.
A.BT = "Bartender4"
local function reglaBarras(nombre)
    if nombre ~= A.BT or not NS.pj then return nil end
    local b = NS.pj.barras
    if b == "blizzard" then return "nunca" elseif b == "bartender" then return "ambos" end
    return nil
end

-- la regla de un addon: la del personaje, la de fábrica o nil (no se toca)
function A.regla(nombre)
    local rb = reglaBarras(nombre)
    if rb then return rb end
    local r = NS.pj and reglas()[nombre]
    if r then return r end
    if A.FABRICA[nombre] then return A.FABRICA[nombre] end
    for _, p in ipairs(A.PREFIJOS) do
        if nombre:sub(1, #p[1]) == p[1] then return p[2] end
    end
    return nil
end

-- el addon con ese nombre de carpeta: índice y si está prendido
local function buscar(nombre)
    for i = 1, GetNumAddOns() do
        local n, _, _, prendido = GetAddOnInfo(i)
        if n == nombre then return i, prendido and true or false end
    end
    return nil
end

local function deseado(regla, m)
    return regla == "ambos" or regla == m
end

-- ¿está instalado (prendido o no)?
function A.instalado(nombre)
    return buscar(nombre) ~= nil
end

-- ¿este addon queda apagado en el modo m? (Perfiles no le cambia el perfil)
function A.vaApagado(nombre, m)
    if not (nombre and m) then return false end
    local r = A.regla(nombre)
    return r ~= nil and not deseado(r, m) and buscar(nombre) ~= nil
end

-- ¿este addon va a estar prendido en el modo m? (instalado, y según su regla o,
-- si Modos no lo maneja, según esté prendido ahora)
function A.vaPrendido(nombre, m)
    local i, prendido = buscar(nombre)
    if not i then return false end
    local r = A.regla(nombre)
    if r then return deseado(r, m) end
    return prendido
end

-- los addons instalados que maneja Modos, ordenados por nombre. Bartender4
-- elegido con la pregunta de las barras no va en la ventana (todos = true lo suma)
function A.lista(todos)
    local l = {}
    for i = 1, GetNumAddOns() do
        local n, titulo, _, prendido = GetAddOnInfo(i)
        local r = n and A.regla(n)
        if r and (todos or not reglaBarras(n)) then
            l[#l + 1] = { nombre = n, titulo = titulo, regla = r, prendido = prendido and true or false,
                          propia = NS.pj and reglas()[n] ~= nil }
        end
    end
    table.sort(l, function(a, b) return a.nombre:lower() < b.nombre:lower() end)
    return l
end

-- cambia la regla de un addon para este personaje ("PvE", "PvP" o "ambos").
-- Si es la de fábrica, no se guarda nada aparte.
function A.ponerRegla(nombre, r)
    local d = reglas()
    d[nombre] = nil
    if A.regla(nombre) ~= r then d[nombre] = r end
    if NS.alCambiar then NS.alCambiar() end
end

-- prende y apaga lo que haga falta para el modo m. Devuelve los que prendió y
-- los que apagó (si hay alguno, hace falta recargar).
function A.aplicar(m)
    local prendidos, apagados = {}, {}
    if not NS.pj then return prendidos, apagados end
    for _, x in ipairs(A.lista(true)) do
        local quiero = deseado(x.regla, m)
        if quiero and not x.prendido then
            EnableAddOn(x.nombre)
            prendidos[#prendidos + 1] = x.nombre
        elseif not quiero and x.prendido then
            DisableAddOn(x.nombre)
            apagados[#apagados + 1] = x.nombre
        end
    end
    return prendidos, apagados
end

-- (1.0.31) los que tienen que estar cargados sí o sí, en los dos modos: sin
-- MerfinPlus la WA de Merfin "Equipped Items" (los abalorios y procs sobre tu
-- marco) no sabe nada de los abalorios y no muestra ninguno ("MerfinPlus is not
-- loaded" en el chat). Si está apagado, Modos lo prende y pide recargar.
A.NECESARIOS = {
    { "MerfinPlus", "tus abalorios sobre tu marco (Equipped Items de Merfin) y las texturas de Merfin" },
    -- (1.0.36) en PvE los casteos del objetivo y del foco son de Quartz (si lo dejaste
    -- en "solo PvP" en Addons por modo, no se toca)
    { "Quartz", "los casteos del objetivo y del foco", modo = "PvE" },
}
A.MOTIVOS = {
    DEP_DISABLED = "uno de los addons que necesita está apagado",
    DEP_MISSING = "falta uno de los addons que necesita",
    INTERFACE_VERSION = "dice que está desactualizado (en la lista de addons tildá \"Cargar addons desactualizados\")",
    CORRUPT = "está roto (volvé a copiarlo del pack)",
    INCOMPATIBLE = "es de otra versión del juego (volvé a copiarlo del pack)",
}
-- devuelve { { nombre, que = "prendido" | "falta" | motivo, para } }
function A.revisarNecesarios()
    local l = {}
    if not (GetAddOnInfo and IsAddOnLoaded) then return l end
    local m = NS.pj and NS.pj.activo
    for _, x in ipairs(A.NECESARIOS) do
        local n = x[1]
        local r = A.regla(n)
        local toca = (not x.modo or x.modo == m) and not (r and m and not deseado(r, m))
        if toca and not IsAddOnLoaded(n) then
            local nombre, _, _, prendido, _, motivo = GetAddOnInfo(n)
            if not nombre or motivo == "MISSING" then
                l[#l + 1] = { nombre = n, que = "falta", para = x[2] }
            elseif not prendido then
                EnableAddOn(n)
                l[#l + 1] = { nombre = n, que = "prendido", para = x[2] }
            else
                l[#l + 1] = { nombre = n, que = motivo or "?", para = x[2] }
            end
        end
    end
    return l
end
-- lo revisa al entrar y avisa (pide recargar si prendió alguno)
function A.necesariosAlEntrar()
    local decir = NS.decir or function() end
    local prendidos = {}
    for _, r in ipairs(A.revisarNecesarios()) do
        if r.que == "prendido" then
            prendidos[#prendidos + 1] = r.nombre
            decir(r.nombre .. " estaba apagado y lo prendí: sin él no aparecen " .. r.para .. ".")
        elseif r.que == "falta" then
            decir("Falta " .. r.nombre .. " en tu carpeta AddOns (viene en el pack de Modos): sin él no aparecen "
                .. r.para .. ".")
        else
            decir(r.nombre .. " no cargó: " .. (A.MOTIVOS[r.que] or r.que) .. ". Sin él no aparecen " .. r.para .. ".")
        end
    end
    if #prendidos > 0 and StaticPopupDialogs then
        StaticPopupDialogs["MODOS_RECARGAR_NECESARIOS"] = StaticPopupDialogs["MODOS_RECARGAR_NECESARIOS"] or {
            text = "Modos: prendí %s (estaba apagado). Hay que recargar para que ande.",
            button1 = "Recargar", button2 = "Después",
            OnAccept = function() ReloadUI() end,
            timeout = 0, whileDead = 1, hideOnEscape = true,
        }
        if NS.pedirRecarga then NS.pedirRecarga("MODOS_RECARGAR_NECESARIOS", table.concat(prendidos, ", "))
        elseif StaticPopup_Show then StaticPopup_Show("MODOS_RECARGAR_NECESARIOS", table.concat(prendidos, ", ")) end
    end
    return prendidos
end

-- resumen corto para el chat: "Cell, DBM (14)" en vez de todos los módulos
function A.resumen(l)
    local dbm, otros = 0, {}
    for _, n in ipairs(l) do
        if n:sub(1, 4) == "DBM-" then dbm = dbm + 1 else otros[#otros + 1] = n end
    end
    if dbm > 0 then otros[#otros + 1] = "DBM ("..dbm..")" end
    return table.concat(otros, ", ")
end

-- ------------------------------------------------------------ barras
-- elige Bartender4 o las barras de Blizzard para este personaje y prende o
-- apaga Bartender4 (solo él: sirve aunque todavía no haya modo elegido).
-- Devuelve true si hace falta recargar.
function A.elegirBarras(b)
    local pj = NS.pj
    if not pj or (b ~= "bartender" and b ~= "blizzard") then return false end
    local antes = pj.barras
    pj.barras = b
    -- si la UI armada se puso sin Bartender4, su parte de Bartender4 queda
    -- pendiente para cuando vuelva a estar cargado
    if b == "bartender" and antes == "blizzard" and pj.presets then
        pj.btPend = pj.btPend or {}
        for m in pairs(pj.presets) do pj.btPend[m] = true end
    end
    local i, prendido = buscar(A.BT)
    if not i then return false end
    local quiero = b == "bartender"
    if quiero and not prendido then EnableAddOn(A.BT); return true end
    if not quiero and prendido then DisableAddOn(A.BT); return true end
    return false
end

-- (0.9.2) la pregunta la hace Barras.lua: con o sin Bartender, y las barras a
-- la vista o escondidas
function A.preguntarBarras() if NS.barras then NS.barras.preguntar() end end
function A.faltaBarras() return NS.barras and NS.barras.falta() or false end
