-- Modos · Perfiles: los perfiles de otros addons cambian con el modo.
--
-- Addons con perfiles Ace3 (Bartender4, OmniBar, Gladius, EasyFrames,
-- Diminishing Returns, Omen, Quartz y ElvUI), los perfiles de Compact Raid
-- Frames y de Details, y las posiciones de MoveAnything. Todos se actualizan solos al cambiarles el perfil, sin /reload.
--
-- Cómo se guarda: por personaje y por addon, qué perfil va con cada modo.
-- Al dejar un modo se anota el perfil que tenía cada addon en ese momento (así
-- se respeta si lo cambiaste a mano). La primera vez que se entra a un modo,
-- se crea un perfil propio de este personaje ("Bypass - PvP") copiado del que
-- tenía, para que lo que edites ahí no les cambie nada a otros personajes que
-- compartían el perfil. En Compact Raid Frames no se crean perfiles (tiene un
-- máximo de 5): el modo nuevo arranca con el mismo y elegís otro estando ahí.
--
-- MoveAnything (11.b2) no tiene perfiles con nombre: usa "default" o uno por
-- personaje. Sus posiciones están en MoveAnything_CharacterSettings[nombre] y
-- la que usa es MovAny.frameOptions. Modos le da una tabla por modo ("Andes
-- Bypass - PvP", copiada de la que tenía) y la cambia como hace su /moveimport:
-- ResetProfile(true), frameOptions = la del modo y SyncAllFrames(true). Después
-- de un /reload MoveAnything vuelve a leer la suya, así que al entrar Modos
-- vuelve a poner la del modo en uso.
--
-- ElvUI tiene además una parte "privada" por personaje (ElvPrivateDB: qué
-- módulos andan, por ejemplo los marcos). Cambiarla toma efecto con /reload, así
-- que va con la recarga de Addons.lua. Cada modo tiene la suya propia, copiada
-- de la que tenías: en PvE con los marcos de ElvUI prendidos (los de MerfinUI).
--
-- Los addons que quedan apagados en el modo nuevo (Addons.lua) no cambian de
-- perfil: quedan con el del modo en que se usan.
--
-- Rol en PvE (DPS/Tank o Healer): al pasar a PvE, ElvUI usa el perfil de
-- MerfinUI de ese rol, si ya lo instalaste con su instalador.
--
-- Nunca en combate: lo llama el cambio de modo, que ya espera a que salgas.

local _, NS = ...

local P = {}
NS.perfiles = P

-- addon: la carpeta (para saber si queda apagado en un modo). privado: la parte
-- privada de ElvUI (siempre un perfil propio por modo, cambia con /reload).
-- Va después de ElvDB: el cambio de perfil de ElvDB actualiza ElvUI con la
-- parte privada que tiene cargada, que tiene que ser la vieja hasta recargar.
local CONOCIDOS = {
    { sv = "Bartender4DB", nombre = "Bartender4", addon = "Bartender4" },
    { sv = "OmniBarDatabase", nombre = "OmniBar", addon = "OmniBar" },
    { sv = "GladiusDB", nombre = "Gladius", addon = "Gladius" },
    { sv = "EasyFramesDB", nombre = "EasyFrames", addon = "EasyFrames" },
    { sv = "DiminishingReturnsDB", nombre = "Diminishing Returns", addon = "DiminishingReturns" },
    { sv = "Omen3DB", nombre = "Omen", addon = "Omen" },
    { sv = "Quartz3DB", nombre = "Quartz", addon = "Quartz" },
    { sv = "ElvDB", nombre = "ElvUI", addon = "ElvUI" },
    { sv = "ElvPrivateDB", nombre = "ElvUI (privado)", addon = "ElvUI", privado = true },
}
P.CONOCIDOS = CONOCIDOS
local CRF = "CompactRaidFrame"
P.CRF = CRF
local MA = "MoveAnything"
P.MA = MA

local function datos()
    local pj = NS.pj
    pj.perfiles = pj.perfiles or {}
    return pj.perfiles
end

local function entrada(clave)
    local d = datos()
    if not d[clave] then d[clave] = { sigue = true } end
    return d[clave]
end
P.entrada = entrada

-- la base AceDB de un addon (sin los namespaces), o nil si no está cargado
local function baseDe(sv)
    local AceDB = LibStub and LibStub("AceDB-3.0", true)
    local tabla = _G[sv]
    if not (AceDB and AceDB.db_registry and type(tabla) == "table") then return nil end
    for db in pairs(AceDB.db_registry) do
        if not db.parent and db.sv == tabla then return db end
    end
    return nil
end
P.baseDe = baseDe

local function existe(db, nombre)
    if db.sv and db.sv.profiles and db.sv.profiles[nombre] then return true end
    if db.profiles and rawget(db.profiles, nombre) then return true end
    return false
end

local function hayCRF()
    return type(GetActiveRaidProfile) == "function" and type(RaidProfileExists) == "function"
        and type(CompactUnitFrameProfiles_ActivateRaidProfile) == "function"
        and type(HasLoadedCUFProfiles) == "function" and HasLoadedCUFProfiles()
end

-- nombre del perfil propio de este personaje para un modo: "Bypass - PvP"
local function nombrePropio(m)
    return (UnitName("player") or "?").." - "..m
end
P.nombrePropio = nombrePropio

-- la parte privada de ElvUI es por personaje: "Bypass - Andes - PvE"
local function nombrePrivado(m)
    return (UnitName("player") or "?").." - "..(GetRealmName() or "?").." - "..m
end
P.nombrePrivado = nombrePrivado

-- lo que trae de fábrica la parte privada de cada modo. Se revisa en cada
-- cambio (no solo al crearla), por si después sumaste Bartender4 o EasyFrames.
-- Devuelve true si cambió algo.
local function prendidoEn(addon, m)
    return NS.addons and NS.addons.vaPrendido(addon, m) or false
end
-- addons que hacen lo mismo que un módulo de ElvUI (los que ElvUI marca como
-- incompatibles en Core.lua, más Bagnon para las bolsas)
local REEMPLAZOS = {
    Mapster = "worldmap", ["Prat-3.0"] = "chat", Chatter = "chat", TipTac = "tooltip",
    Aloft = "nameplates", TidyPlates = "nameplates", ["Healers-Have-To-Die"] = "nameplates",
    Bagnon = "bags",
    EasyFrames = "unitframe",          -- marcos de Blizzard con EasyFrames
}
local function ajustarPrivado(p, m)
    local cambio = false
    local function poner(seccion, v)
        p[seccion] = p[seccion] or {}
        if p[seccion].enable ~= v then p[seccion].enable = v; cambio = true end
    end
    -- con Bartender4, las barras de ElvUI apagadas (si no, se ven las dos)
    if prendidoEn("Bartender4", m) then poner("actionbar", false) end
    -- si usás otro addon para lo mismo, el módulo de ElvUI se apaga (si no,
    -- ElvUI pregunta en cada carga cuál querés)
    for addon, modulo in pairs(REEMPLAZOS) do
        if prendidoEn(addon, m) then poner(modulo, false) end
    end
    return cambio
end

local function apagadoEn(addon, m)
    return NS.addons and NS.addons.vaApagado(addon, m)
end

-- Gladius muestra su marco de prueba cada vez que le cambian el perfil
local function arreglarGladius()
    if not (Gladius and type(Gladius.HideFrame) == "function") then return end
    local _, tipo = IsInInstance()
    if tipo ~= "arena" then pcall(Gladius.HideFrame, Gladius) end
end

-- ------------------------------------------------------------ MoveAnything
local function hayMA()
    return type(MovAny) == "table" and type(MoveAnything_CharacterSettings) == "table"
        and type(MovAny.SyncAllFrames) == "function" and type(MovAny.ResetProfile) == "function"
        and MovAny.inited and type(MovAny.frameOptions) == "table"
end

-- el nombre de la tabla que está usando MoveAnything ahora
local function actualMA()
    for n, t in pairs(MoveAnything_CharacterSettings) do
        if t == MovAny.frameOptions then return n end
    end
    return nil
end

local function nombreMA(m)
    return ((GetCVar and GetCVar("realmName")) or GetRealmName() or "?").." "..(UnitName("player") or "?").." - "..m
end

-- pasa MoveAnything a la tabla "nombre" (si no existe, copiada de "fuente")
local function ponerMA(nombre, fuente)
    local cs = MoveAnything_CharacterSettings
    if not cs[nombre] then
        cs[nombre] = {}
        if fuente and cs[fuente] and type(MovAny.CopySettings) == "function" then
            MovAny:CopySettings(fuente, nombre)
        end
    end
    if MovAny.frameOptions == cs[nombre] then return false end
    MovAny:ResetProfile(true)
    MovAny.frameOptions = cs[nombre]
    MovAny:SyncAllFrames(true)
    if type(MovAny.UpdateGUIIfShown) == "function" then MovAny:UpdateGUIIfShown(true) end
    return true
end

-- ------------------------------------------------------------ Details
local function hayDetails()
    return type(_detalhes) == "table" and type(_detalhes.ApplyProfile) == "function"
        and type(_detalhes.GetCurrentProfileName) == "function" and type(_detalhes.SaveProfile) == "function"
        and type(_detalhes_global) == "table" and type(_detalhes_global.__profiles) == "table"
end

-- ApplyProfile guarda antes el perfil que deja. Si el perfil no existe, se
-- arma con SaveProfile(nombre), que copia lo que tiene ahora.
local function ponerDetails(nombre)
    if nombre == _detalhes:GetCurrentProfileName() then return false end
    if not _detalhes_global.__profiles[nombre] then _detalhes:SaveProfile(nombre) end
    if _detalhes:ApplyProfile(nombre) == false then error("no encontró el perfil") end
    return true
end

-- ------------------------------------------------------------ los que no son Ace3
-- crea: si la primera vez se arma uno propio copiado (Compact Raid Frames no,
-- porque tiene un máximo de 5 perfiles)
local OTROS = {
    { clave = CRF, nombre = "Compact Raid Frames", addon = "CompactRaidFrame", hay = hayCRF, crea = false,
      actual = function() return GetActiveRaidProfile() end,
      existe = function(n) return RaidProfileExists(n) and true or false end,
      poner = function(n) CompactUnitFrameProfiles_ActivateRaidProfile(n); return true end },
    { clave = MA, nombre = "MoveAnything", addon = "MoveAnything", hay = hayMA, crea = true, propio = nombreMA,
      actual = actualMA,
      existe = function(n) return MoveAnything_CharacterSettings[n] ~= nil end,
      poner = ponerMA },
    { clave = "Details", nombre = "Details", addon = "Details", hay = hayDetails, crea = true, propio = nombrePropio,
      actual = function() return _detalhes:GetCurrentProfileName() end,
      existe = function(n) return _detalhes_global.__profiles[n] ~= nil end,
      poner = ponerDetails },
}
P.OTROS = OTROS

-- la parte privada que va a usar ElvUI (la que quedó anotada para la recarga)
local function privadoActual(db)
    local k = (UnitName("player") or "?").." - "..(GetRealmName() or "?")
    return (db.sv.profileKeys and db.sv.profileKeys[k]) or db:GetCurrentProfile()
end

-- lo que se muestra en la ventana: addons cargados, con sus perfiles
function P.lista()
    local l = {}
    if not NS.pj then return l end
    for _, c in ipairs(CONOCIDOS) do
        local db = baseDe(c.sv)
        if db then
            local e = entrada(c.sv)
            l[#l + 1] = { clave = c.sv, nombre = c.nombre, sigue = e.sigue, PvE = e.PvE, PvP = e.PvP,
                          actual = c.privado and privadoActual(db) or db:GetCurrentProfile() }
        end
    end
    for _, a in ipairs(OTROS) do
        if a.hay() then
            local e = entrada(a.clave)
            l[#l + 1] = { clave = a.clave, nombre = a.nombre, sigue = e.sigue, PvE = e.PvE, PvP = e.PvP,
                          actual = a.actual() }
        end
    end
    return l
end

-- cuántos addons siguen el modo (para la ventana)
function P.cuantos()
    local n = 0
    for _, x in ipairs(P.lista()) do if x.sigue then n = n + 1 end end
    return n
end

-- el perfil de ahora de un addon (para anotarlo en un modo)
local function actualDe(clave)
    for _, a in ipairs(OTROS) do
        if a.clave == clave then return a.hay() and a.actual() or nil end
    end
    local db = baseDe(clave)
    return db and db:GetCurrentProfile()
end

-- prende o apaga "cambia con el modo". Al prender, el perfil de ahora queda
-- como el del modo en uso.
function P.seguir(clave, si)
    local e = entrada(clave)
    e.sigue = si and true or false
    if si and NS.pj.activo then e[NS.pj.activo] = actualDe(clave) end
    if NS.alCambiar then NS.alCambiar() end
end

local function esPrivado(clave)
    for _, c in ipairs(CONOCIDOS) do
        if c.sv == clave then return c.privado end
    end
end

-- la primera vez: los perfiles de ahora quedan como los del modo m. La parte
-- privada de ElvUI no: cada modo arma la suya con P.aplicar, copiada de la que
-- tenías antes de Modos (origen), para que la de un modo no herede la del otro.
function P.adoptar(m)
    for _, x in ipairs(P.lista()) do
        if x.sigue then
            local e = entrada(x.clave)
            if esPrivado(x.clave) then e.origen = e.origen or x.actual
            else e[m] = x.actual end
        end
    end
end

-- un addon que no es Ace3
local function aplicarOtro(a, e, nuevo, desde, r)
    local ahora = a.actual()
    if desde and ahora then e[desde] = ahora end
    if apagadoEn(a.addon, nuevo) then return end
    local objetivo = e[nuevo]
    if not a.crea then
        if not objetivo then
            e[nuevo] = ahora
        elseif objetivo ~= ahora then
            if a.existe(objetivo) then
                local ok, err = pcall(a.poner, objetivo)
                if ok then r.cambiados[#r.cambiados + 1] = a.nombre
                else r.errores[#r.errores + 1] = a.nombre..": "..tostring(err) end
            else
                r.errores[#r.errores + 1] = a.nombre..": el perfil \""..objetivo.."\" ya no existe, quedó \""..tostring(ahora).."\""
                e[nuevo] = ahora
            end
        end
        return
    end
    if not objetivo or not a.existe(objetivo) then
        if objetivo and objetivo ~= a.propio(nuevo) then
            r.errores[#r.errores + 1] = a.nombre..": el perfil \""..objetivo.."\" ya no existe, armé uno nuevo"
        end
        objetivo = a.propio(nuevo)
        if not a.existe(objetivo) then r.creados[#r.creados + 1] = a.nombre end
    end
    local ok, res = pcall(a.poner, objetivo, ahora)
    if ok then
        e[nuevo] = objetivo
        if res then r.cambiados[#r.cambiados + 1] = a.nombre end
    else
        r.errores[#r.errores + 1] = a.nombre..": "..tostring(res)
        if ahora then pcall(a.poner, ahora) end
    end
end

local function copiaProfunda(t)
    if type(t) ~= "table" then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = copiaProfunda(v) end
    return r
end

-- La parte privada de ElvUI NO se cambia en caliente: SetProfile de AceDB le
-- borra los valores de fábrica a la tabla que ElvUI sigue usando (E.private) y
-- ElvUI tira errores (Tooltip.lua: 'tooltip' a nil value). Se escribe directo en
-- ElvPrivateDB (profileKeys y profiles) y toma efecto al recargar. AceDB no
-- vuelve a escribir profileKeys al salir.
local function aplicarPrivado(db, e, nuevo, desde, r)
    local sv = db.sv
    sv.profileKeys = sv.profileKeys or {}
    sv.profiles = sv.profiles or {}
    local k = (UnitName("player") or "?").." - "..(GetRealmName() or "?")
    local ahora = sv.profileKeys[k] or db:GetCurrentProfile()
    if desde then e[desde] = ahora end
    e.origen = e.origen or ahora
    local objetivo = e[nuevo]
    if not objetivo or not sv.profiles[objetivo] then
        objetivo = nombrePrivado(nuevo)
        if not sv.profiles[objetivo] then
            sv.profiles[objetivo] = copiaProfunda(sv.profiles[e.origen] or sv.profiles[ahora] or {})
        end
    end
    e[nuevo] = objetivo
    -- la UI armada del modo (Presets.lua), la primera vez o si cambió
    local pr = NS.presets
    local conPreset = pr and pr.falta(nuevo) and pr[nuevo].privado
    if conPreset then
        pr.mezclar(sv.profiles[objetivo], pr[nuevo].privado)
        r.presetPrivado = true
    end
    -- (1.0.15) sin el instalador de ElvUI: la parte privada nueva lleva la marca de
    -- instalación hecha (en un personaje nuevo la copia podía quedar sin ella)
    if sv.profiles[objetivo].install_complete == nil then
        local E1 = ElvUI and ElvUI[1]
        sv.profiles[objetivo].install_complete = (E1 and E1.version) or "6.09"
    end
    local ajustada = ajustarPrivado(sv.profiles[objetivo], nuevo) or conPreset
    if objetivo ~= ahora or ajustada then
        sv.profileKeys[k] = objetivo
        r.recargar = true
        r.recargarPrivado = true
        r.cambiados[#r.cambiados + 1] = "ElvUI (privado)"
    end
end

-- (1.0.15) al entrar (PLAYER_LOGIN, todavía con la pantalla de carga): si Bartender4
-- arrancó con otro perfil que el del modo en uso, se le pone el del modo. Así no se ve
-- unos segundos la forma de antes hasta que Modos lo acomoda (19/10, Pandia).
function P.perfilAlEntrar()
    local pj = NS.pj
    local m = pj and pj.activo
    if not m or (InCombatLockdown and InCombatLockdown()) then return false end
    local db = baseDe("Bartender4DB")
    local e = db and pj.perfiles and pj.perfiles.Bartender4DB
    local objetivo = e and e.sigue and e[m]
    if not objetivo or apagadoEn("Bartender4", m) or db:GetCurrentProfile() == objetivo or not existe(db, objetivo) then
        return false
    end
    return pcall(db.SetProfile, db, objetivo) and true or false
end

-- Pone los perfiles del modo "nuevo". Si viene "desde", antes anota en ese modo
-- los perfiles de ahora. Devuelve un resumen: cambiados, creados y errores.
function P.aplicar(nuevo, desde)
    local r = { cambiados = {}, creados = {}, errores = {}, dual = {} }
    if not NS.pj then return r end
    -- dónde quedaron los marcos en el modo que dejás (antes de tocar nada)
    if desde then P.anotarMarcos(desde) end
    for _, c in ipairs(CONOCIDOS) do
        local db = baseDe(c.sv)
        local e = db and entrada(c.sv)
        if db and e.sigue and c.privado then
            aplicarPrivado(db, e, nuevo, desde, r)
        elseif db and e.sigue then
            local ahora = db:GetCurrentProfile()
            if desde then e[desde] = ahora end
            if apagadoEn(c.addon, nuevo) then
                -- queda apagado en el modo nuevo: sigue con el perfil del modo en que se usa
            else
            -- el cambio de perfil por talento del propio addon pisaría a Modos
            if type(db.IsDualSpecEnabled) == "function" and db:IsDualSpecEnabled() then
                pcall(db.SetDualSpecEnabled, db, false)
                r.dual[#r.dual + 1] = c.nombre
            end
            local propio = nombrePropio(nuevo)
            local objetivo = e[nuevo]
            local crear = false
            if not objetivo or not existe(db, objetivo) then
                if objetivo and objetivo ~= propio then
                    r.errores[#r.errores + 1] = c.nombre..": el perfil \""..objetivo.."\" ya no existe, armé uno nuevo"
                end
                objetivo = propio
                crear = not existe(db, objetivo)
            end
            if objetivo ~= ahora then
                local ok, err = pcall(function()
                    db:SetProfile(objetivo)
                    if crear then db:CopyProfile(ahora) end
                end)
                if ok then
                    e[nuevo] = objetivo
                    r.cambiados[#r.cambiados + 1] = c.nombre
                    if crear then r.creados[#r.creados + 1] = c.nombre end
                else
                    pcall(db.SetProfile, db, ahora)
                    r.errores[#r.errores + 1] = c.nombre..": "..tostring(err)
                end
                if c.sv == "GladiusDB" then arreglarGladius() end
            else
                e[nuevo] = objetivo
            end
            end
        end
        -- el rol de PvE elige el perfil de ElvUI (antes de tocar la parte privada)
        if c.sv == "ElvDB" and nuevo == "PvE" and db and e.sigue then P.ponerRol(r) end
    end
    for _, a in ipairs(OTROS) do
        local e = datos()[a.clave]
        if e and e.sigue and a.hay() then aplicarOtro(a, e, nuevo, desde, r) end
    end
    P.aplicarPreset(nuevo, r)
    if NS.pj.marcos then
        if not NS.pj.marcos.origen then P.anotarMarcos(nil) end
        P.ponerMarcos(nuevo)
    end
    return r
end

-- La UI armada del modo (Presets.lua): se escribe en los perfiles de este modo
-- (ElvUI, Bartender4 y MoveAnything) y toma efecto al recargar.
-- el perfil propio de este personaje para el modo m. Si el modo usaba uno
-- compartido (por ejemplo "friskes"), se arma una copia: la UI armada nunca
-- se escribe en un perfil que usan otros personajes. Toma efecto al recargar.
local function propio(sv, m)
    local clave = (UnitName("player") or "?").." - "..(GetRealmName() or "?")
    local db = baseDe(sv)
    local e = datos()[sv]
    if not (db and e and e.sigue) then return nil end
    local svt = db.sv
    svt.profiles = svt.profiles or {}
    local actual = e[m] or db:GetCurrentProfile()
    local n = nombrePropio(m)
    if actual ~= n and not svt.profiles[n] then
        svt.profiles[n] = copiaProfunda(svt.profiles[actual] or {})
        for _, t in pairs(svt.namespaces or {}) do
            if type(t) == "table" and t.profiles and t.profiles[actual] then
                t.profiles[n] = copiaProfunda(t.profiles[actual])
            end
        end
    end
    e[m] = n
    svt.profileKeys = svt.profileKeys or {}
    svt.profileKeys[clave] = n
    svt.profiles[n] = svt.profiles[n] or {}
    return db, n
end

-- Los otros addons con AceDB del preset (Gladius, Quartz...): se ponen si están
-- cargados. Los que están instalados pero apagados ahora (por ejemplo Gladius
-- al pasar de PvE a PvP) quedan pendientes y se ponen al entrar, con recarga.
function P.ponerPendientes(m, hecho)
    local pj = NS.pj
    local pend = pj and pj.presetPend and pj.presetPend[m]
    local pr = NS.presets
    local p = pr and pr[m]
    if not (pend and p and p.sv) then return end
    for sv in pairs(pend) do
        local t = p.sv[sv]
        local e = datos()[sv]
        if not t or (NS.addons and not NS.addons.instalado(t.addon)) or (e and not e.sigue) then
            pend[sv] = nil      -- no está o no lo maneja Modos: nada que poner
        elseif not apagadoEn(t.addon, m) and baseDe(sv) then
            entrada(sv)
            local db, n = propio(sv, m)
            if db then
                if t.perfil then pr.mezclar(db.sv.profiles[n], t.perfil) end
                if t.ns then
                    db.sv.namespaces = db.sv.namespaces or {}
                    for ns, v in pairs(t.ns) do
                        db.sv.namespaces[ns] = db.sv.namespaces[ns] or {}
                        local x = db.sv.namespaces[ns]
                        x.profiles = x.profiles or {}
                        x.profiles[n] = x.profiles[n] or {}
                        pr.mezclar(x.profiles[n], v)
                    end
                end
                pend[sv] = nil
                hecho[#hecho + 1] = t.addon
            end
        end
    end
    if not next(pend) then pj.presetPend[m] = nil end
end

-- opciones del juego del preset (por ejemplo, sin marcos de arena de Blizzard)
function P.ponerCVars(m)
    local p = NS.presets and NS.presets[m]
    if not (p and p.cvars and GetCVar and SetCVar) then return false end
    local cambio = false
    for k, v in pairs(p.cvars) do
        if GetCVar(k) ~= nil and GetCVar(k) ~= v then pcall(SetCVar, k, v); cambio = true end
    end
    return cambio
end

-- la parte de Bartender4 de la UI armada del modo m (si está cargado y Modos
-- maneja su perfil). Devuelve true si la puso.
-- (1.0.13) la forma de Bartender4 del preset del modo m: a la vista o escondida.
-- En PvE manda lo que eligió (los de antes: Bartender escondidas). En PvP hasta la
-- 1.0.12 siempre eran a la vista: escondidas solo si lo eligió de verdad.
function P.btVariante(m)
    local p = NS.presets and NS.presets[m]
    if not p then return nil end
    if not p.Bartender4Visible then return p.Bartender4 end
    local vis
    if m == "PvP" then vis = not (NS.pj and NS.pj.barrasVista == "escondidas")
    else vis = ModosBarrasVisibles and ModosBarrasVisibles() or false end
    return vis and p.Bartender4Visible or p.Bartender4
end

local function ponerBT(m)
    local pr = NS.presets
    local p = pr and pr[m]
    if not (p and p.Bartender4) or apagadoEn("Bartender4", m) then return false end
    local db, n = propio("Bartender4DB", m)
    if not db then return false end
    -- (0.9.2) en PvE, con las barras a la vista, la otra forma armada
    local bt = P.btVariante(m)
    db.sv.namespaces = db.sv.namespaces or {}
    for ns, t in pairs(bt) do
        db.sv.namespaces[ns] = db.sv.namespaces[ns] or {}
        local sns = db.sv.namespaces[ns]
        sns.profiles = sns.profiles or {}
        sns.profiles[n] = sns.profiles[n] or {}
        pr.mezclar(sns.profiles[n], t)
    end
    if NS.pj.btPend then
        NS.pj.btPend[m] = nil
        if not next(NS.pj.btPend) then NS.pj.btPend = nil end
    end
    return true
end
P.ponerBT = ponerBT

-- (1.0.20) la forma de Bartender4 (a la vista o escondidas) de cada modo ya armado
-- tiene que ser la que elegiste. Fallaba al elegir el modo antes que las barras (en el
-- asistente): el modo se armaba con la forma de fábrica (en PvP, a la vista) y elegir
-- las barras después no la cambiaba (solo se reescribía si ya tenías Bartender y
-- cambiabas de forma). Ahora, al entrar, si la barra 1 del perfil de un modo está como
-- la otra forma (y no como la elegida) se vuelve a poner. Solo se mira lo que cambia
-- entre las dos formas (en PvP, que se vea y que la atraviese el mouse; en PvE, dónde
-- está y si aparece con el mouse): si la acomodaste a mano, no se toca.
local BT_FABRICA = { alpha = 1, fadeout = false, fadeoutalpha = 0.1, fadeoutdelay = 0.2, clickthrough = false,
                     enabled = true, rows = 1, padding = 2, ["position.scale"] = 1,
                     ["position.growVertical"] = "DOWN", ["position.growHorizontal"] = "RIGHT" }
local function plano(t, pre, r)
    r = r or {}
    for k, v in pairs(type(t) == "table" and t or {}) do
        local kk = pre and (pre .. "." .. tostring(k)) or tostring(k)
        if type(v) == "table" then plano(v, kk, r) else r[kk] = v end
    end
    return r
end
local function mismo(a, b)
    if type(a) == "number" and type(b) == "number" then return math.abs(a - b) < 0.01 end
    return a == b
end
-- ¿la barra b está como la forma "como" (y no como "no")?
function P.pareceForma(b, como, no)
    local fc, fn, fb = plano(como), plano(no), plano(b)
    local claves = {}
    for k in pairs(fc) do claves[k] = true end
    for k in pairs(fn) do claves[k] = true end
    local hay = false
    for k in pairs(claves) do
        local vc = fc[k]; if vc == nil then vc = BT_FABRICA[k] end
        local vn = fn[k]; if vn == nil then vn = BT_FABRICA[k] end
        if not mismo(vc, vn) then
            hay = true
            local vb = fb[k]; if vb == nil then vb = BT_FABRICA[k] end
            if not mismo(vb, vc) then return false end
        end
    end
    return hay
end
function P.revisarFormaBT()
    local pj, pr = NS.pj, NS.presets
    if not (pj and pj.presets and pr and NS.barras and NS.barras.estilo() == "bartender") then return false end
    local db = baseDe("Bartender4DB")
    local e = datos().Bartender4DB
    if not (db and e and e.sigue) then return false end
    local ab = db.sv.namespaces and db.sv.namespaces.ActionBars
    local hubo = false
    for m in pairs(pj.presets) do
        local p, n = pr[m], e[m]
        local quiero = p and p.Bartender4Visible and P.btVariante(m)
        local perfil = n and ab and ab.profiles and ab.profiles[n]
        local b1 = perfil and type(perfil.actionbars) == "table" and perfil.actionbars[1]
        if quiero and type(b1) == "table" then
            local otra = (quiero == p.Bartender4Visible) and p.Bartender4 or p.Bartender4Visible
            local q1, o1 = quiero.ActionBars.actionbars[1], otra.ActionBars.actionbars[1]
            if P.pareceForma(b1, o1, q1) then
                pj.btPend = pj.btPend or {}
                pj.btPend[m] = true
                hubo = true
            end
        end
    end
    return hubo
end

-- si pasó de las barras de Blizzard a Bartender4 con la UI ya armada, falta
-- poner la parte de Bartender4 (con recarga)
function P.ponerBTPendiente(m, r)
    local pj = NS.pj
    if not (pj and pj.btPend and pj.btPend[m]) then return false end
    if NS.presets and NS.presets.falta(m) then return false end     -- la pone el preset entero
    if not ponerBT(m) then return false end
    r.recargar = true
    r.preset = r.preset or {}
    r.preset[#r.preset + 1] = "Bartender4"
    return true
end

function P.aplicarPreset(m, r)
    local pr = NS.presets
    if pr and not pr.falta(m) then P.ponerBTPendiente(m, r) end
    if not (pr and pr.falta(m)) then return end
    local p = pr[m]
    local hecho = {}
    if r.presetPrivado then hecho[#hecho + 1] = "ElvUI privado" end
    if p.ElvDB then
        local db, n = propio("ElvDB", m)
        if db then
            pr.mezclar(db.sv.profiles[n], p.ElvDB)
            hecho[#hecho + 1] = "ElvUI"
        end
    end
    if ponerBT(m) then hecho[#hecho + 1] = "Bartender4" end
    if p.MoveAnything and hayMA() then
        local e = datos()[MA]
        if e and e.sigue then
            -- tabla propia del modo, copiada de la que tenía (como al crearla)
            local n = nombreMA(m)
            local ok = pcall(ponerMA, n, e[m] or actualMA())
            if ok and MoveAnything_CharacterSettings[n] then
                e[m] = n
                for marco, t in pairs(p.MoveAnything) do
                    MoveAnything_CharacterSettings[n][marco] = pr.mezclar({}, t)
                end
                hecho[#hecho + 1] = "MoveAnything"
            end
        end
    end
    if p.sv then
        local pj = NS.pj
        pj.presetPend = pj.presetPend or {}
        pj.presetPend[m] = {}
        for sv in pairs(p.sv) do pj.presetPend[m][sv] = true end
        P.ponerPendientes(m, hecho)
        -- los que quedaron pendientes (addon apagado ahora) se ponen al entrar
        if pj.presetPend[m] then
            local l = {}
            for sv in pairs(pj.presetPend[m]) do l[#l + 1] = p.sv[sv].addon end
            table.sort(l)
            hecho[#hecho + 1] = table.concat(l, ", ").." al volver a entrar"
        end
    end
    if p.cvars and P.ponerCVars(m) then hecho[#hecho + 1] = "opciones del juego" end
    if p.marcos then
        local pj = NS.pj
        pj.marcos = pj.marcos or {}
        if not pj.marcos.origen then P.anotarMarcos(nil) end
        pj.marcos[m] = pr.mezclar({}, p.marcos)
        hecho[#hecho + 1] = "marcos"
    end
    -- si no había nada cargado para armar, se intenta la próxima vez
    if #hecho == 0 then return end
    pr.marcar(m)
    -- los marcos se mueven en el momento; lo demás toma efecto al recargar
    if #hecho > 1 or hecho[1] ~= "marcos" then
        r.recargar = true
        r.preset = hecho
    end
end

-- ------------------------------------------------------------ rol en PvE
P.ROLES = { "Tank", "DPS", "Heal" }

-- el perfil de ElvUI que armó el instalador de MerfinUI para ese rol, por
-- ejemplo "MerfinUI (DPS/Tank) (1080) v7.8". Si hay varios, el de versión más alta.
function P.perfilMerfin(rol)
    local db = baseDe("ElvDB")
    if not (db and rol) then return nil end
    local patron = rol == "Healer" and "^MerfinUI %(Healer" or "^MerfinUI %(DPS/Tank%)"
    local mejor, vMejor
    for _, n in ipairs(db:GetProfiles({})) do
        if n:find(patron) then
            local v = tonumber(n:match("v([%d%.]+)$") or "") or 0
            if not mejor or v > vMejor then mejor, vMejor = n, v end
        end
    end
    return mejor
end

-- en PvE, ElvUI pasa al perfil de MerfinUI del rol elegido (si no hay rol
-- elegido, queda el que tenía PvE)
function P.ponerRol(r)
    -- (12/10) el rol de PvE ya no cambia el perfil de ElvUI: lo maneja Rol.lua
end

-- elegir el rol de PvE del talento en uso ("Tank", "DPS" o "Heal"; también los
-- nombres viejos de MerfinUI). Sin rol: pregunta.
function P.cambiarRol(rol)
    rol = ({ ["DPS/Tank"] = "DPS", Healer = "Heal" })[rol] or rol
    if not NS.rol then return end
    if rol then NS.rol.poner(rol) else NS.rol.preguntar() end
end

-- ------------------------------------------------------------ marcos por modo
-- Jugador, objetivo y foco: cada modo puede tener su lugar (el de la UI
-- armada). Al dejar un modo se anota dónde estaban (respeta si los moviste).
-- Un modo sin lugar propio vuelve a donde estaban antes de Modos (origen). Si
-- MoveAnything maneja ese marco, lo deja a MoveAnything.
P.MARCOS = { "PlayerFrame", "TargetFrame", "FocusFrame" }

local function deMA(n)
    return hayMA() and MovAny.frameOptions and MovAny.frameOptions[n] ~= nil
end

local function leerMarco(n)
    local f = _G[n]
    if not (f and f.GetPoint) then return nil end
    local p, rel, rp, x, y = f:GetPoint()
    if not p then return nil end
    if rel and rel ~= UIParent then return nil end   -- anclado a otro marco: no se toca
    return { p, rp or p, x or 0, y or 0, f.GetScale and f:GetScale() or 1 }
end

function P.anotarMarcos(m)
    local pj = NS.pj
    if not (pj and pj.marcos) then return end
    -- antes de mover nada por primera vez, el lugar de origen
    if not pj.marcos.origen then
        pj.marcos.origen = {}
        for _, n in ipairs(P.MARCOS) do pj.marcos.origen[n] = leerMarco(n) end
    end
    if m and pj.marcos[m] then
        for _, n in ipairs(P.MARCOS) do
            if pj.marcos[m][n] and not deMA(n) then pj.marcos[m][n] = leerMarco(n) or pj.marcos[m][n] end
        end
    end
end

-- cuánto mide en pantalla (unidades de UIParent) una unidad del marco
local function relacion(f)
    if f.GetEffectiveScale and UIParent and UIParent.GetEffectiveScale then
        local u = UIParent:GetEffectiveScale()
        if u and u > 0 then return f:GetEffectiveScale() / u end
    end
    return f.GetScale and f:GetScale() or 1
end

-- si EasyFrames cambia el tamaño de un marco, se vuelve a poner en su lugar
local enganchados = {}
local function engancharEscala(f)
    if enganchados[f] or not hooksecurefunc or not f.SetScale then return end
    enganchados[f] = true
    hooksecurefunc(f, "SetScale", function()
        if P.poniendo or not (IsAddOnLoaded and IsAddOnLoaded("EasyFrames")) then return end
        if InCombatLockdown and InCombatLockdown() then P.entrarLuego = true; return end
        if NS.pj and NS.pj.activo then P.ponerMarcos(NS.pj.activo) end
    end)
end

-- (1.0.37) MoveAnything con el jugador, el objetivo o el foco guardados: los pone él y
-- Modos no los toca (25/10, en PvP su marco quedaba abajo al medio, TOPLEFT 474,-673 de
-- MoveAnything: la tabla de PvP de Modos es una copia de la "default" de su UI de antes,
-- que traía esos marcos). Si la tabla en uso es la de Modos para ese modo y el modo tiene
-- su lugar (la UI armada), se sacan de ahí una vez (si después los movés con
-- MoveAnything a propósito, quedan). Si es otra (la de siempre), se avisa y se ofrece
-- apagarlo: MoveAnything no viene en el pack.
P.NOMBRES_MARCOS = { PlayerFrame = "tu marco", TargetFrame = "el objetivo", FocusFrame = "el foco" }
function P.soltarDeMA(m)
    local pj = NS.pj
    if not (m and pj and pj.marcos and pj.marcos[m] and hayMA()) then return false end
    pj.maSoltado = pj.maSoltado or {}
    if pj.maSoltado[m] then return false end
    local n = actualMA()
    local t = n and MoveAnything_CharacterSettings[n]
    if not (t and n == nombreMA(m)) then return false end
    local saco = false
    for _, f in ipairs(P.MARCOS) do
        if pj.marcos[m][f] and t[f] ~= nil then t[f] = nil; saco = true end
    end
    pj.maSoltado[m] = true
    if saco then
        pcall(function()
            MovAny:ResetProfile(true)
            MovAny.frameOptions = t
            MovAny:SyncAllFrames(true)
        end)
    end
    return saco
end
function P.avisarMA(lista)
    local pj = NS.pj
    if #lista == 0 or P.avisoMA or (pj and pj.dejarMA) then return end
    P.avisoMA = true
    local que = table.concat(lista, ", ")
    if NS.decir then
        NS.decir("MoveAnything (de tu UI de antes, no viene en el pack) está poniendo " .. que
            .. " en otro lugar, y ahí Modos no los mueve.")
    end
    if not (StaticPopupDialogs and StaticPopup_Show) then return end
    StaticPopupDialogs["MODOS_APAGAR_MA"] = StaticPopupDialogs["MODOS_APAGAR_MA"] or {
        text = "Modos: MoveAnything (de tu UI de antes, no viene en el pack) está poniendo %s en otro lugar. ¿Lo apago? Se recarga la interfaz.",
        button1 = "Apagar y recargar", button2 = "Dejarlo",
        OnAccept = function() if DisableAddOn then DisableAddOn("MoveAnything") end; ReloadUI() end,
        OnCancel = function() if NS.pj then NS.pj.dejarMA = true end end,
        timeout = 0, whileDead = 1, hideOnEscape = true,
    }
    StaticPopup_Show("MODOS_APAGAR_MA", que)
end

function P.ponerMarcos(m)
    local pj = NS.pj
    if not (pj and pj.marcos and m) then return end
    if InCombatLockdown and InCombatLockdown() then P.entrarLuego = true; return end
    if not pj.marcos.origen then P.anotarMarcos(nil) end
    P.soltarDeMA(m)
    local t = pj.marcos[m] or pj.marcos.origen
    local deOtro = {}
    -- con EasyFrames el tamaño lo pone él: se respeta y se corre el punto para que
    -- en pantalla quede en el mismo lugar. Sin él, Modos pone el tamaño del preset.
    local conEF = IsAddOnLoaded and IsAddOnLoaded("EasyFrames")
    -- dónde va cada marco en la pantalla
    local pos = {}
    for _, n in ipairs(P.MARCOS) do
        local f, l = _G[n], t[n]
        if f and l and not deMA(n) then
            local e = l[5] or 1
            pos[n] = { f = f, l = l, x = l[3] * e, y = l[4] * e, r = conEF and relacion(f) or e }
        elseif f and l and pj.marcos[m] then
            deOtro[#deOtro + 1] = P.NOMBRES_MARCOS[n] or n
        end
    end
    P.avisarMA(deOtro)
    -- jugador y objetivo lado a lado: que no se encimen aunque sean más grandes
    local pj_, ob = pos.PlayerFrame, pos.TargetFrame
    if pj_ and ob and pj_.l[1] == "CENTER" and pj_.l[2] == "CENTER" and ob.l[1] == "CENTER" and ob.l[2] == "CENTER"
        and pj_.x < ob.x and math.abs(pj_.y - ob.y) < 60 and pj_.f.GetWidth and ob.f.GetWidth then
        local hace = ((pj_.f:GetWidth() or 0) * pj_.r + (ob.f:GetWidth() or 0) * ob.r) / 2 + 6
        if ob.x - pj_.x < hace then pj_.x = ob.x - hace end
    end
    P.poniendo = true
    for _, n in ipairs(P.MARCOS) do
        local d = pos[n]
        if d then
            local f, l = d.f, d.l
            -- cada marco por separado: si uno falla, los demás y el cambio de modo siguen
            local ok, err = pcall(function()
                f:ClearAllPoints()
                if not conEF and f.SetScale then f:SetScale(l[5] or 1) end
                local r = (d.r and d.r > 0) and d.r or 1
                f:SetPoint(l[1], UIParent, l[2], d.x / r, d.y / r)
                -- el juego no deja marcar como "puesto por el jugador" un marco que no
                -- es movible (TargetFrame): primero se lo hace movible
                if f.SetMovable then f:SetMovable(true) end
                if f.SetUserPlaced then f:SetUserPlaced(true) end
            end)
            if not ok and NS.decir then NS.decir("No pude acomodar "..n..": "..tostring(err)) end
            engancharEscala(f)
        end
    end
    P.poniendo = nil
end

-- (1.0.4) una parte del preset que cambió (Presets.lua: PR.PARTES). Devuelve
-- true si quedó hecha (o no hay nada que hacer), false para probar en la próxima
-- entrada (el addon no está cargado todavía). hecho: lo que pide recargar.
-- movidos: lo que se corrió en el momento (para avisar).
-- (1.0.9) suma un addon a la lista de lo que pide recargar, sin repetirlo
local function anotar(hecho, nombre)
    for _, h in ipairs(hecho) do if h == nombre then return end end
    hecho[#hecho + 1] = nombre
end

function P.ponerParte(m, x, hecho, movidos)
    local pr = NS.presets
    local p = pr and pr[m]
    local pj = NS.pj
    if not (p and pj) then return false end
    if x.sv then
        if not (p.sv and p.sv[x.sv]) then return true end
        pj.presetPend = pj.presetPend or {}
        pj.presetPend[m] = pj.presetPend[m] or {}
        pj.presetPend[m][x.sv] = true            -- lo pone ponerPendientes, con recarga
        return true
    elseif x.placas then
        local np = p.ElvDB and p.ElvDB.nameplates and p.ElvDB.nameplates.units
        if not (np and np.ENEMY_PLAYER) then return true end
        local e = datos().ElvDB
        if e and not e.sigue then return true end  -- ElvUI no lo maneja Modos
        local db, n = propio("ElvDB", m)
        if not db then return false end
        local perfil = db.sv.profiles[n]
        perfil.nameplates = perfil.nameplates or {}
        perfil.nameplates.units = perfil.nameplates.units or {}
        perfil.nameplates.units.ENEMY_PLAYER = perfil.nameplates.units.ENEMY_PLAYER or {}
        local ep = perfil.nameplates.units.ENEMY_PLAYER
        ep.debuffs = ep.debuffs or {}
        pr.mezclar(ep.debuffs, np.ENEMY_PLAYER.debuffs)
        hecho[#hecho + 1] = "placas de ElvUI"
        return true
    elseif x.marcos then
        -- donde los pone el preset (los pone ponerMarcos, al final de alEntrar)
        local t = pj.marcos and pj.marcos[m]
        if not (t and p.marcos) then return true end   -- todavía no hay: van con el preset
        for n, l in pairs(p.marcos) do t[n] = pr.mezclar({}, l) end
        movidos[#movidos + 1] = "tu marco, el objetivo y el foco"
        return true
    elseif x.compactVida then
        -- (1.0.5) la vida que le queda a cada uno ("Salud restante"), en todos
        -- los perfiles de Compact de este personaje (el de PvP, el de raid...)
        if not (hayCRF() and SetRaidProfileOption and GetNumRaidProfiles and GetRaidProfileName
                and CompactUnitFrameProfiles_ApplyCurrentSettings) then
            return false
        end
        if InCombatLockdown and InCombatLockdown() then return false end
        local n = GetNumRaidProfiles() or 0
        if n < 1 then return false end
        for i = 1, n do
            local perfil = GetRaidProfileName(i)
            if perfil then SetRaidProfileOption(perfil, "healthText", "health") end
        end
        CompactUnitFrameProfiles_ApplyCurrentSettings()
        NS.decir("Puse la vida que le queda a cada uno en los marcos de tu equipo (Compact).")
        return true
    elseif x.elv then
        -- (1.0.9) un pedazo del perfil de ElvUI de este modo (con recarga)
        local t = pr.AJUSTES_ELV and pr.AJUSTES_ELV[x.elv] and pr.AJUSTES_ELV[x.elv][m]
        if not t then return true end
        local e = datos().ElvDB
        if e and not e.sigue then return true end      -- ElvUI no lo maneja Modos
        local db, n = propio("ElvDB", m)
        if not db then return false end
        pr.mezclar(db.sv.profiles[n], t)
        anotar(hecho, "ElvUI")
        return true
    elseif x.bt or x.btApagar or x.btEscondidas then
        -- (1.0.9) barras de Bartender4 del preset, sin tocar las otras (con recarga).
        -- (1.0.13) de la forma que usa (a la vista o escondidas), apagar barras, y en
        -- PvP esconder 1 a 6 si eligió escondidas
        if apagadoEn("Bartender4", m) then return true end
        local e = datos().Bartender4DB
        if e and not e.sigue then return true end
        -- (1.0.25) las que son solo para la forma escondida de Bartender
        if x.soloEscondidas and not (NS.barras and NS.barras.estilo() == "bartender" and p.Bartender4
                                     and P.btVariante(m) == p.Bartender4) then
            return true
        end
        local db, n = propio("Bartender4DB", m)
        if not db then return false end
        local fuente = P.btVariante(m) or {}
        db.sv.namespaces = db.sv.namespaces or {}
        local function perfilDe(ns)
            db.sv.namespaces[ns] = db.sv.namespaces[ns] or {}
            local sns = db.sv.namespaces[ns]
            sns.profiles = sns.profiles or {}
            sns.profiles[n] = sns.profiles[n] or {}
            return sns.profiles[n]
        end
        local lista = type(x.bt) == "table" and x.bt or (x.bt and { x.bt }) or {}
        for _, ns in ipairs(lista) do
            if fuente[ns] then pr.mezclar(perfilDe(ns), fuente[ns]) end
        end
        if x.btApagar or (x.btEscondidas and m == "PvP" and NS.pj.barrasVista == "escondidas") then
            local ab = perfilDe("ActionBars")
            ab.actionbars = ab.actionbars or {}
            for _, i in ipairs(x.btApagar or {}) do
                ab.actionbars[i] = ab.actionbars[i] or {}
                ab.actionbars[i].enabled = false
            end
            if x.btEscondidas and m == "PvP" and NS.pj.barrasVista == "escondidas" then
                for i = 1, 6 do
                    ab.actionbars[i] = ab.actionbars[i] or {}
                    pr.mezclar(ab.actionbars[i], { fadeout = false, alpha = 0, clickthrough = true })
                end
            end
        end
        anotar(hecho, "Bartender4")
        return true
    elseif x.btBase then
        -- (1.0.10) lo general de Bartender4 en el perfil del modo (con recarga). Si ya
        -- está (o no hay nada guardado: Bartender4 trae "button" de fábrica) no pide recargar
        if apagadoEn("Bartender4", m) or not pr.BT_BASE then return true end
        local e = datos().Bartender4DB
        if e and not e.sigue then return true end
        local db, n = propio("Bartender4DB", m)
        if not db then return false end
        local perfil = db.sv.profiles[n]
        local cambio = false
        for k, v in pairs(pr.BT_BASE) do
            if perfil[k] ~= nil and perfil[k] ~= v then perfil[k] = v; cambio = true end
        end
        if cambio then anotar(hecho, "Bartender4") end
        return true
    elseif x.mrt then
        -- (1.0.9) raid cooldowns de MRT: color de clase y lo listo primero. VMRT es de
        -- toda la cuenta: si otro personaje ya lo puso, no pide recargar
        local v = type(VMRT) == "table" and VMRT.ExCD2
        if not (type(v) == "table" and type(v.colSet) == "table" and pr.MRT) then return false end
        local cambio = false
        for i = 1, 11 do
            local c = v.colSet[i]
            if type(c) == "table" then
                for k, val in pairs(pr.MRT) do
                    if c[k] ~= val then c[k] = val; cambio = true end
                end
            end
        end
        -- (1.0.11) arriba a la izquierda: la ventana de MRT se ancla por su esquina de
        -- arriba a la izquierda (Left, Top desde abajo a la izquierda, en su escala)
        local lugar = pr.MRT_LUGAR
        if lugar and not v.SplitOpt then
            local general = type(v.colSet[11]) == "table" and v.colSet[11] or {}
            local esc = (tonumber(general.frameScale) or 100) / 100
            local alto = GetScreenHeight and GetScreenHeight() or 1080
            if not alto or alto <= 0 then alto = 1080 end
            local x, y = lugar.x / esc, (alto + lugar.y) / esc
            if not (v.Left and v.Top and math.abs(v.Left - x) < 1 and math.abs(v.Top - y) < 1) then
                v.Left, v.Top = x, y
                cambio = true
            end
        end
        if cambio then anotar(hecho, "MRT") end
        return true
    elseif x.details then
        -- (1.0.13) las ventanas de Details del modo en su lugar (sin recargar)
        local e = datos().Details
        if e and not e.sigue then return true end
        local V = NS.ventanas
        if not V then return true end
        if not V.hayDetails() then return false end
        local ok = V.details(m)
        if ok then NS.decir("Acomodé Details abajo a la derecha (daño arriba y curación abajo).") end
        return ok
    elseif x.mbf then
        -- (1.0.24) MinimapButtonFrame en una columna (en el momento). Sin MBF instalado, nada.
        local MBF = _G.MBF
        if not (type(MBF) == "table" and MBF.db and MBF.db.profile and pr.MBF) then
            return not (NS.addons and NS.addons.instalado and NS.addons.instalado("MinimapButtonFrame"))
        end
        local cambio = false
        for k, v in pairs(pr.MBF) do
            if MBF.db.profile[k] ~= v then MBF.db.profile[k] = v; cambio = true end
        end
        if cambio and MBF.Scan then pcall(MBF.Scan, MBF) end
        return true
    elseif x.compactAlto then
        -- (1.0.6) solo el alto de los marcos de tu equipo, en el perfil de Compact
        -- que usás ahora: el lugar y lo demás quedan como estaban
        if not (hayCRF() and SetRaidProfileOption and GetActiveRaidProfile
                and CompactUnitFrameProfiles_ApplyCurrentSettings) then
            return false
        end
        if InCombatLockdown and InCombatLockdown() then return false end
        local perfil = GetActiveRaidProfile()
        if not perfil then return false end
        SetRaidProfileOption(perfil, "frameHeight", pr.COMPACT.opciones.frameHeight)
        CompactUnitFrameProfiles_ApplyCurrentSettings()
        NS.decir("Hice un poco más altos los marcos de tu equipo (Compact).")
        return true
    elseif x.compact then
        if not (hayCRF() and SetRaidProfileSavedPosition and SetRaidProfileOption
                and CompactUnitFrameProfiles_ApplyCurrentSettings) then
            return false
        end
        if InCombatLockdown and InCombatLockdown() then return false end
        local perfil = GetActiveRaidProfile()
        if not perfil then return false end
        local c = pr.COMPACT
        for k, v in pairs(c.opciones) do SetRaidProfileOption(perfil, k, v) end
        local l = c.lugar
        SetRaidProfileSavedPosition(perfil, false, l[1], l[2], l[3], l[4], l[5], l[6])
        CompactUnitFrameProfiles_ApplyCurrentSettings()
        movidos[#movidos + 1] = "los marcos de tu equipo"
        return true
    elseif x.omnicc then
        -- (1.0.12) OmniCC como viene (con sus colores, y se agranda al final), apenas
        -- más chico para que no tape el ícono entero, y en todo: sin la regla de la
        -- 1.0.4 que le sacaba el número a las alertas de Modos (ahora no traen el suyo)
        local sv = OmniCCDB
        if type(sv) ~= "table" then return false end
        local c = pr.OMNICC
        local def = DEFAULT or "Default"
        local clave = (UnitName("player") or "?").." - "..(GetRealmName() or "?")
        local nombre = sv.profileKeys and sv.profileKeys[clave] or def
        sv.profiles = sv.profiles or {}
        sv.profiles[nombre] = sv.profiles[nombre] or {}
        local prof = sv.profiles[nombre]
        prof.themes = prof.themes or {}
        local tema = prof.defaultTheme or def
        prof.themes[tema] = prof.themes[tema] or { name = tema }
        local t = prof.themes[tema]
        -- ¿ya estaba? (el perfil de OmniCC suele ser uno solo para los dos modos y
        -- todos los personajes: no se pide recargar dos veces por lo mismo)
        local st = type(t.textStyles) == "table" and t.textStyles or {}
        local cambio = t.fontSize ~= c.fontSize
        for k, v in pairs(c.textStyles) do
            if not (type(st[k]) == "table" and st[k].scale == v.scale) then cambio = true end
        end
        pr.mezclar(t, { fontSize = c.fontSize, textStyles = c.textStyles })
        -- lo de la 1.0.4: la regla y el tema sin números, afuera
        for i = #(prof.rules or {}), 1, -1 do
            local r = prof.rules[i]
            if type(r) == "table" and r.id == c.reglaVieja then table.remove(prof.rules, i); cambio = true end
        end
        for i, r in ipairs(prof.rules or {}) do if type(r) == "table" then r.priority = i end end
        if prof.themes[c.temaViejo] then prof.themes[c.temaViejo] = nil; cambio = true end
        if cambio then anotar(hecho, "OmniCC") end
        return true
    end
    return true
end

-- (1.0.13) /modos reiniciar: el modo m desde cero. Los perfiles propios de este
-- modo (los "Pj - Modo" de Modos, nunca uno compartido con otros personajes) vuelven
-- a como vienen de fábrica, y después se pone toda la UI armada del modo y las
-- partes, como en un personaje nuevo. Cell (en PvE) se vuelve a acomodar. Devuelve
-- lo que hay que avisar (como aplicar) y la lista de perfiles reiniciados.
function P.reiniciar(m)
    local pj = NS.pj
    if not pj then return nil, {} end
    local reiniciados = {}
    local n = nombrePropio(m)
    for _, c in ipairs(CONOCIDOS) do
        local db = not c.privado and baseDe(c.sv)
        local e = datos()[c.sv]
        if db and e and e.sigue and e[m] == n and db:GetCurrentProfile() == n then
            if pcall(db.ResetProfile, db) then reiniciados[#reiniciados + 1] = c.nombre end
        end
    end
    pj.presets = pj.presets or {}
    pj.presets[m] = nil
    if pj.presetPend then pj.presetPend[m] = nil end
    if pj.btPend then pj.btPend[m] = nil end
    if pj.partes then
        for k in pairs(pj.partes) do
            if k:sub(1, #m + 1) == m .. ":" then pj.partes[k] = nil end
        end
    end
    if m == "PvE" and type(CellDB) == "table" then CellDB.modos, CellDB.modosVida = nil, nil end
    local rp = P.aplicar(m)
    return rp, reiniciados
end

-- Al entrar (o después de un /reload): MoveAnything vuelve a usar su tabla de
-- siempre. Si el modo en uso tiene otra, se vuelve a poner.
function P.alEntrar()
    local pj = NS.pj
    -- las opciones del juego del modo (si alguien las volvió a cambiar)
    if pj and pj.activo and pj.presets and pj.presets[pj.activo] then P.ponerCVars(pj.activo) end
    -- (1.0.3) xCT+ lee de las opciones del juego si muestra vida o maná bajo y
    -- entrar o salir de combate, y solo las ajusta a su perfil al tocar su
    -- configuración: se hace acá, para que coincidan con lo que puso Modos
    if pj and pj.activo == "PvE" and type(xCT_Plus) == "table" and type(xCT_Plus.cvar_udpate) == "function"
       and xCT_Plus.db then
        pcall(xCT_Plus.cvar_udpate)
    end
    -- (1.0.4) partes del preset que cambiaron (Presets.lua: PR.PARTES), solo esas
    local hecho, movidos = {}, {}
    if pj and pj.activo and NS.presets and NS.presets.partesNuevas and not NS.recargando then
        for _, x in ipairs(NS.presets.partesNuevas(pj.activo)) do
            local ok, listo = pcall(P.ponerParte, pj.activo, x, hecho, movidos)
            if ok and listo then NS.presets.parteHecha(pj.activo, x) end
        end
        if #movidos > 0 then NS.decir("Acomodé " .. table.concat(movidos, " y ") .. " (más a la izquierda).") end
    end
    -- lo del preset que quedó pendiente porque el addon estaba apagado
    if pj and pj.activo and pj.presetPend and pj.presetPend[pj.activo] and not NS.recargando then
        P.ponerPendientes(pj.activo, hecho)
        local rb = {}
        if P.ponerBTPendiente(pj.activo, rb) then hecho[#hecho + 1] = "Bartender4" end
    end
    if #hecho > 0 and NS.recargarSiHace then
        NS.recargarSiHace(pj.activo, { recargar = true, preset = hecho })
    end
    if pj and pj.activo and not NS.recargando then P.revisarFormaBT() end
    if pj and pj.activo and pj.btPend and pj.btPend[pj.activo] and not NS.recargando then
        local rb = {}
        if P.ponerBTPendiente(pj.activo, rb) and NS.recargarSiHace then NS.recargarSiHace(pj.activo, rb) end
    end
    -- (1.0.37) primero la tabla de MoveAnything del modo y después los marcos. Al revés,
    -- después de un /reload MoveAnything todavía tenía la de siempre y Modos no los movía
    P.ponerMAModo()
    if pj and pj.activo and pj.marcos then
        if InCombatLockdown and InCombatLockdown() then P.entrarLuego = true
        else P.ponerMarcos(pj.activo) end
    end
end

-- al entrar, MoveAnything vuelve a su tabla de siempre: se pone la del modo en uso
function P.ponerMAModo()
    local pj = NS.pj
    if not (pj and pj.activo and hayMA()) then return end
    local ea = datos()[MA]
    local objetivo = ea and ea.sigue and ea[pj.activo]
    if not (objetivo and MoveAnything_CharacterSettings[objetivo]) then return end
    if MovAny.frameOptions == MoveAnything_CharacterSettings[objetivo] then return end
    if InCombatLockdown and InCombatLockdown() then
        P.entrarLuego = true
        return
    end
    P.entrarLuego = nil
    local ok, err = pcall(ponerMA, objetivo)
    if not ok then NS.decir("MoveAnything: no pude poner las posiciones de "..pj.activo.." ("..tostring(err)..").") end
end

-- los avisos en el chat después de un cambio
function P.avisar(r, nuevo, viejo)
    if #r.creados > 0 then
        NS.decir("Armé perfiles \""..nombrePropio(nuevo).."\" copiados de los de "..viejo.." en: "
            ..table.concat(r.creados, ", ")..". Lo que cambies ahí no toca a "..viejo.." ni a tus otros personajes.")
    end
    if #r.dual > 0 then
        NS.decir("Apagué el cambio de perfil por talento de "..table.concat(r.dual, ", ")
            ..", porque ahora lo maneja Modos.")
    end
    for _, x in ipairs(r.errores) do NS.decir("Perfiles: "..x..".") end
    for _, x in ipairs(r.avisos or {}) do NS.decir(x) end
end
