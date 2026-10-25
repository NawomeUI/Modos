-- Modos · Auras (0.9.3, 1.0): las WeakAuras de cada paquete se instalan solas
-- (abajo de todo: "se instalan solas") y cargan solo en su modo, así PvE y PvP no
-- se pisan en la pantalla.
--   * PvE: Modos PvE (Mis CDs y pociones), la de tu clase (Merfin o Modos) y
--     los abalorios de Merfin sobre tu marco.
--   * PvP: Alertas PvP, Alertas PvP CDs, Alertas PvP Equipo (con Mis CDs) y
--     Alertas PvP Extra.
--   * Siempre: las anclas de Merfin, los packs de raid, las utilidades y las
--     auras tuyas (las que no son de estos paquetes).
-- Cómo: al cargar (ADDON_LOADED de Modos o de WeakAuras, lo que llegue último),
-- antes de que WeakAuras arme las auras, a las del otro modo se les marca "Nunca"
-- en Cargar y a las de este se les saca. (0.9.8: antes se hacía en PLAYER_LOGIN y
-- llegaba tarde: WeakAuras arma todo de una en su PLAYER_LOGIN, y como MerfinPlus
-- lo pide de dependencia carga antes que Modos. Quedaba al revés: en PvP las de
-- PvE y en PvE nada, hasta la recarga siguiente.) Solo se les saca a las que marcó Modos (ModosDB.auras.apagadas):
-- si vos pusiste alguna en Nunca, queda así. Al cambiar de modo hace falta
-- recargar (lo pide Nucleo). /modos auras muestra qué encontró.

local _, NS = ...

local AU = {}
NS.auras = AU

-- los grupos de arriba de cada paquete: por uid (el que traen al importar) o por
-- nombre (también "Nombre 2" si se importó como copia)
AU.PAQUETES = {
    PvE = {
        { uid = "mMdPvEG0001", id = "Modos PvE" },
        { uid = "E1Xnp6Tvu35", id = "[Merfin] Equipped Items" },
        { uid = "OV5S7tx2l6e", id = "[Merfin] Death Knight (1080p)" },
        { uid = "IyNEeEpbQVA", id = "[Merfin] Druid (1080p)" },
        { uid = "mMdHun00001", id = "[Modos] Cazador (1080p)" },
        { uid = "9by0eIlZSSA", id = "[Merfin] Mage (1080p)" },
        { uid = "mMdPal00001", id = "[Modos] Paladín (1080p)" },
        { uid = "7yeA0POd6IR", id = "[Merfin] Priest (1080p)" },
        { uid = "mMdRog00001", id = "[Modos] Pícaro (1080p)" },
        { uid = "ft6uUi17aBq", id = "[Merfin] Shaman (1080p)" },
        { uid = "N39QXJ7hVuN", id = "[Merfin] Warlock (1080p)" },
        { uid = "lQgyxPDDTcK", id = "[Merfin] Class: Warrior (1080p)" },
    },
    PvP = {
        { uid = "mPvPAlrt001", id = "Alertas PvP" },
        { uid = "mPvPCDsG016", id = "Alertas PvP CDs" },
        { uid = "mPvPEqui023", id = "Alertas PvP Equipo" },
        { uid = "mPvPExtr015", id = "Alertas PvP Extra" },
    },
}

local function displays()
    return type(WeakAurasSaved) == "table" and type(WeakAurasSaved.displays) == "table" and WeakAurasSaved.displays or nil
end

-- ¿de qué modo es este grupo de arriba? (nil: de ninguno, carga siempre)
local porUid, porId = {}, {}
for m, l in pairs(AU.PAQUETES) do
    for _, p in ipairs(l) do porUid[p.uid] = m; porId[p.id] = m end
end
function AU.modoDe(id, d)
    if d.uid and porUid[d.uid] then return porUid[d.uid] end
    if porId[id] then return porId[id] end
    local base = id:match("^(.-) %d+$")
    return base and porId[base] or nil
end

-- el grupo y todo lo de adentro
local function recorrer(ds, id, fn, vistos)
    if vistos[id] then return end
    vistos[id] = true
    local d = ds[id]
    if type(d) ~= "table" then return end
    fn(d)
    if type(d.controlledChildren) == "table" then
        for _, h in ipairs(d.controlledChildren) do recorrer(ds, h, fn, vistos) end
    end
end

-- los grupos de arriba de cada modo: { [id] = modo }
function AU.grupos()
    local ds, r = displays(), {}
    if not ds then return r end
    for id, d in pairs(ds) do
        if type(id) == "string" and type(d) == "table" and not d.parent then
            local m = AU.modoDe(id, d)
            if m then r[id] = m end
        end
    end
    return r
end

local function apagadas()
    ModosDB.auras = ModosDB.auras or {}
    ModosDB.auras.apagadas = ModosDB.auras.apagadas or {}
    return ModosDB.auras.apagadas
end

-- qué hay que cambiar para el modo m: { { d = aura, apagar = true/false }, ... }
local function cambios(m)
    local ds = displays()
    if not (ds and m and ModosDB) then return {} end
    local ap = ModosDB.auras and ModosDB.auras.apagadas or {}
    local l, vistos = {}, {}
    for id, mm in pairs(AU.grupos()) do
        local apagar = mm ~= m
        recorrer(ds, id, function(d)
            if type(d.controlledChildren) == "table" then return end     -- los grupos cargan si carga algo de adentro
            local nunca = type(d.load) == "table" and d.load.use_never
            if apagar and not nunca then
                l[#l + 1] = { d = d, apagar = true }
            elseif not apagar and nunca and ap[d.uid or d.id or ""] then
                l[#l + 1] = { d = d, apagar = false }
            end
        end, vistos)
    end
    return l
end

-- ¿al pasar a m cambian las auras que cargan? (entonces hay que recargar)
function AU.hace(m) return #cambios(m) > 0 end

-- deja cargando solo las del modo m. Devuelve cuántas cambió.
function AU.aplicar(m)
    local l = cambios(m)
    if #l == 0 then return 0 end
    local ap = apagadas()
    for _, x in ipairs(l) do
        local d = x.d
        if type(d.load) ~= "table" then d.load = {} end
        local clave = d.uid or d.id
        if x.apagar then
            d.load.use_never = true
            if clave then ap[clave] = true end
        else
            d.load.use_never = false
            if clave then ap[clave] = nil end
        end
    end
    return #l
end

-- /modos auras: qué paquetes encontró y en qué modo cargan
function AU.resumen()
    local por = { PvE = {}, PvP = {} }
    for id, m in pairs(AU.grupos()) do por[m][#por[m] + 1] = id end
    for _, m in ipairs({ "PvE", "PvP" }) do table.sort(por[m]) end
    return por
end

-- ------------------------------------------------------------ (1.0) se instalan solas
-- Al entrar con cada personaje, antes de que WeakAuras arme las auras, Modos pone
-- en tus WeakAuras los paquetes que falten: los de PvE (anclas, Modos PvE y
-- abalorios), el de la clase de ese personaje y los de PvP. WeakAuras los carga
-- como si los hubieras importado (sin ventanas). Cada paquete puesto queda
-- anotado en ModosDB.auras.instalados: si después lo borrás, no vuelve solo
-- (/modos auras reinstalar lo vuelve a poner).

function AU.clase()
    if not UnitClass then return nil end
    local _, c = UnitClass("player")
    return c
end

-- los paquetes de este personaje: { nombre, uid, id, texto, clase }
function AU.paquetesDe(clase)
    local D, l = NS.AURAS_DATOS, {}
    if not D then return l end
    for _, x in ipairs(D.PvE or {}) do l[#l + 1] = x end
    if clase and D.clases and D.clases[clase] then
        -- (1.0.32) las que arma Modos (cazador, paladín, pícaro) tienen versión: se
        -- actualizan solas y quedan donde las tenías
        local v = D.claseVersion and D.claseVersion[clase]
        l[#l + 1] = { nombre = "la de tu clase", uid = D.claseUid and D.claseUid[clase],
                      id = D.claseId and D.claseId[clase], texto = D.clases[clase], clase = true,
                      version = v, modos = v and true or nil, lugar = v and true or nil }
    end
    for _, x in ipairs(D.PvP or {}) do l[#l + 1] = x end
    -- (1.0.29) las de Modos para tu clase (el rastreo del cazador)
    for _, x in ipairs(clase and D.extras and D.extras[clase] or {}) do l[#l + 1] = x end
    return l
end

-- ¿están las librerías de WeakAuras para leer los textos?
function AU.puedeInstalar()
    if not (LibStub and type(WeakAuras) == "table") then return false end
    return LibStub("LibDeflate", true) ~= nil and LibStub("LibSerialize", true) ~= nil
end

-- el texto "!WA:2!..." a tabla, como lo lee WeakAuras al importar
function AU.leer(texto)
    local LD, LS = LibStub("LibDeflate", true), LibStub("LibSerialize", true)
    local cuerpo = type(texto) == "string" and texto:match("^!WA:2!(.+)$")
    if not (LD and LS and cuerpo) then return nil end
    local a = LD:DecodeForPrint(cuerpo)
    local b = a and LD:DecompressDeflate(a)
    if not b then return nil end
    local ok, t = LS:Deserialize(b)
    if ok and type(t) == "table" and t.m == "d" and type(t.d) == "table" and type(t.d.id) == "string" then return t end
    return nil
end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789()"
local function uidNuevo(uids)
    local u
    repeat
        if WeakAuras and WeakAuras.GenerateUniqueID then
            u = WeakAuras.GenerateUniqueID()
        else
            local t = {}
            for i = 1, 11 do local n = math.random(1, 64); t[i] = B64:sub(n, n) end
            u = table.concat(t)
        end
    until not uids[u]
    return u
end

-- pone un paquete leído en ds, como el "Importar" de WeakAuras: nombres libres
-- ("Nombre 2" si ya hay uno), uid propio para cada aura y grupos con sus hijos.
-- Si algo falla no queda nada a medias (se escribe todo al final).
function AU.poner(ds, t, uids)
    local d, c = t.d, type(t.c) == "table" and t.c or {}
    local lista = { d }
    for _, x in ipairs(c) do
        if type(x) == "table" and type(x.id) == "string" then lista[#lista + 1] = x end
    end
    -- textos viejos (antes de la versión 2000): el grupo con sus hijos directos
    if (tonumber(t.v) or 0) < 2000 and #lista > 1 then
        d.controlledChildren = {}
        for i = 2, #lista do
            d.controlledChildren[#d.controlledChildren + 1] = lista[i].id
            lista[i].parent = d.id
        end
    end
    local nuevo, tomados = {}, {}
    for _, x in ipairs(lista) do
        local id, n = x.id, 2
        while ds[id] or tomados[id] do id = x.id .. " " .. n; n = n + 1 end
        tomados[id] = true
        if id ~= x.id then nuevo[x.id] = id end
    end
    local usados = {}
    for _, x in ipairs(lista) do
        x.id = nuevo[x.id] or x.id
        if x.parent then x.parent = nuevo[x.parent] or x.parent end
        if type(x.controlledChildren) == "table" then
            for i, h in ipairs(x.controlledChildren) do x.controlledChildren[i] = nuevo[h] or h end
        end
        if type(x.sortHybridTable) == "table" then
            local s = {}
            for k, v in pairs(x.sortHybridTable) do s[nuevo[k] or k] = v end
            x.sortHybridTable = s
        end
        if type(x.anchorFrameFrame) == "string" then
            local a = x.anchorFrameFrame:match("^WeakAuras:(.+)$")
            if a and nuevo[a] then x.anchorFrameFrame = "WeakAuras:" .. nuevo[a] end
        end
        if type(x.uid) ~= "string" or uids[x.uid] or usados[x.uid] then x.uid = uidNuevo(uids) end
        usados[x.uid] = true
        x.preferToUpdate = false
        x.authorMode = nil
    end
    for _, x in ipairs(lista) do
        ds[x.id] = x
        uids[x.uid] = true
    end
    return #lista
end

-- (1.0.4) un paquete de Modos con versión nueva: se saca el viejo (el grupo de
-- arriba y todo lo de adentro) y se pone el nuevo. Si algo falla, queda el viejo.
-- (1.0.30) lugar: cada aura nueva queda donde tenías la vieja (por su uid).
AU.LUGAR = { "xOffset", "yOffset", "anchorPoint", "selfPoint", "anchorFrameType", "anchorFrameFrame", "frameStrata" }
local function reemplazar(ds, idViejo, t, uids, lugar)
    local ids = {}
    recorrer(ds, idViejo, function(d) ids[#ids + 1] = d.id end, {})
    local guardado, donde = {}, {}
    for _, id in ipairs(ids) do
        local d = ds[id]
        if type(d) == "table" then
            guardado[id] = d
            if type(d.uid) == "string" then
                uids[d.uid] = nil
                if lugar then
                    local p = {}
                    for _, k in ipairs(AU.LUGAR) do p[k] = d[k] end
                    donde[d.uid] = p
                end
            end
            ds[id] = nil
        end
    end
    if pcall(AU.poner, ds, t, uids) then
        -- (1.0.32) las nuevas vienen de fábrica: los arreglos de Modos (arreglarModos)
        -- se les vuelven a hacer
        local hechos = type(ModosDB) == "table" and ModosDB.auras and ModosDB.auras.arreglados
        if hechos then
            local nuevas = { t.d }
            for _, x in ipairs(type(t.c) == "table" and t.c or {}) do nuevas[#nuevas + 1] = x end
            for _, x in ipairs(nuevas) do
                if type(x) == "table" and type(x.uid) == "string" then hechos[x.uid] = nil end
            end
        end
        if lugar then
            for _, d in pairs(ds) do
                local p = type(d) == "table" and type(d.uid) == "string" and donde[d.uid]
                if p then
                    for _, k in ipairs(AU.LUGAR) do d[k] = p[k] end
                end
            end
        end
        return true
    end
    for id, d in pairs(guardado) do
        ds[id] = d
        if type(d.uid) == "string" then uids[d.uid] = true end
    end
    return false
end

-- pone los paquetes que falten. forzar: también los que ya puso y borraste.
-- (1.0.4) y actualiza los de Modos (x.modos) que tengas en una versión vieja.
-- Devuelve cuántos puso o actualizó (los nombres en AU.puestas y AU.actualizadas).
function AU.instalar(forzar)
    local ds = displays()
    AU.puestas, AU.actualizadas = {}, {}
    if not (ds and AU.puedeInstalar()) then return 0 end
    if type(ModosDB) ~= "table" then ModosDB = {} end
    ModosDB.auras = ModosDB.auras or {}
    ModosDB.auras.instalados = ModosDB.auras.instalados or {}
    ModosDB.auras.versiones = ModosDB.auras.versiones or {}
    local hechos, versiones = ModosDB.auras.instalados, ModosDB.auras.versiones
    local uids, arriba, arribaUid = {}, {}, {}
    for id, d in pairs(ds) do
        if type(d) == "table" then
            if type(d.uid) == "string" then uids[d.uid] = true end
            if type(id) == "string" and not d.parent then
                arriba[id] = true
                local b = id:match("^(.-) %d+$")
                if b then arriba[b] = true end
                if type(d.uid) == "string" then arribaUid[d.uid] = id end
            end
        end
    end
    for _, x in ipairs(AU.paquetesDe(AU.clase())) do
        local clave = x.uid or x.id
        if (x.uid and uids[x.uid]) or (x.id and arriba[x.id]) then
            if clave then hechos[clave] = true end                    -- ya estaba (importada a mano)
            -- los que no tienen versión anotada son de antes de la 1.0.4: la 1
            local tiene = clave and versiones[clave] or 1
            if x.modos and x.version and tiene < x.version and x.uid and arribaUid[x.uid] then
                local okl, t = pcall(AU.leer, x.texto)
                if okl and t and reemplazar(ds, arribaUid[x.uid], t, uids, x.lugar) then
                    versiones[clave] = x.version
                    AU.actualizadas[#AU.actualizadas + 1] = x.nombre
                end
            elseif clave and not versiones[clave] then
                versiones[clave] = math.min(tiene, x.version or 1)
            end
        elseif clave and (forzar or not hechos[clave]) then
            local okl, t = pcall(AU.leer, x.texto)
            if okl and t and pcall(AU.poner, ds, t, uids) then
                hechos[clave] = true
                versiones[clave] = x.version or 1
                AU.puestas[#AU.puestas + 1] = x.nombre
            end
        end
    end
    return #AU.puestas + #AU.actualizadas
end

-- (1.0.14) la WA de clase vuelve al lugar del paquete, una vez: cada aura de los
-- paquetes de clase que tengas puestos con su x e y de fábrica (la del pícaro estaba
-- corrida a mano y ahora tu marco y el objetivo se apoyan en el piso de la WA).
-- Solo las que encuentra por su uid. Devuelve cuántas movió.
AU.LUGAR_CLASE = 1
function AU.reubicarClases(ds)
    local D = NS.AURAS_DATOS
    if not (ds and D and D.clases and D.claseUid and AU.puedeInstalar()) then return 0 end
    local porUid = {}
    for _, d in pairs(ds) do
        if type(d) == "table" and type(d.uid) == "string" then porUid[d.uid] = d end
    end
    local n = 0
    for clase, texto in pairs(D.clases) do
        if porUid[D.claseUid[clase] or ""] then
            local okl, t = pcall(AU.leer, texto)
            if okl and t then
                local lista = { t.d }
                for _, c in ipairs(t.c or {}) do lista[#lista + 1] = c end
                for _, x in ipairs(lista) do
                    local d = type(x.uid) == "string" and porUid[x.uid]
                    if d and (d.xOffset ~= x.xOffset or d.yOffset ~= x.yOffset) then
                        d.xOffset, d.yOffset = x.xOffset, x.yOffset
                        n = n + 1
                    end
                end
            end
        end
    end
    return n
end

-- (1.0.26) arreglos en las auras que puso Modos (las de clase, las de Merfin y las
-- de Modos), una vez por aura (ModosDB.auras.arreglados[uid]): si después cambiás algo
-- a mano en WeakAuras, no se vuelve a tocar. Lo pidió (25/10, paladín): "en el sello se
-- ve todo raro como con muchos números colapsados".
--   * el tiempo doble: estas WeakAuras no le avisan a OmniCC que ponen su propio
--     número (no usan noCooldownCount), así que en los íconos con la recarga a la
--     vista salían los dos (29:55 de la aura y 29m de OmniCC encimados). Queda el de
--     OmniCC, como en todo lo demás (1.0.12).
--   * el maná de la barra de clase en miles con "T" (3.0T): con "K", como tus marcos.
--   * los íconos de arriba de la barra de clase (Top Panel) 6 más arriba: el número
--     de la barra (arriba de ella) quedaba debajo del ícono.
AU.ARREGLO = 1
AU.TOP_PANEL = { antes = 10, ahora = 16 }
local function arreglar(d)
    local hizo = false
    if d.regionType == "icon" and d.cooldown and type(d.subRegions) == "table" then
        for _, sr in ipairs(d.subRegions) do
            if type(sr) == "table" and sr.type == "subtext" and sr.text_text == "%p" and sr.text_visible ~= false then
                sr.text_visible = false
                hizo = true
            end
        end
    elseif d.regionType == "aurabar" and type(d.config) == "table" and d.config.sign_value == "T" then
        d.config.sign_value = "K"
        hizo = true
    elseif d.regionType == "dynamicgroup" and type(d.id) == "string" and d.id:find("Top Panel$")
           and d.yOffset == AU.TOP_PANEL.antes then
        d.yOffset = AU.TOP_PANEL.ahora
        hizo = true
    end
    return hizo
end
AU.arreglarAura = arreglar
function AU.arreglarModos(ds)
    if not (ds and type(ModosDB) == "table" and ModosDB.auras) then return 0 end
    local inst = ModosDB.auras.instalados or {}
    ModosDB.auras.arreglados = ModosDB.auras.arreglados or {}
    local hechos = ModosDB.auras.arreglados
    local function arriba(d)
        local n = 0
        while type(d) == "table" and type(d.parent) == "string" and type(ds[d.parent]) == "table" and n < 20 do
            d, n = ds[d.parent], n + 1
        end
        return d
    end
    local n = 0
    for _, d in pairs(ds) do
        if type(d) == "table" and type(d.uid) == "string" and (hechos[d.uid] or 0) < AU.ARREGLO then
            local top = arriba(d)
            if type(top) == "table" and ((type(top.uid) == "string" and inst[top.uid]) or (top.id and inst[top.id])) then
                if arreglar(d) then n = n + 1 end
                hechos[d.uid] = AU.ARREGLO
            end
        end
    end
    return n
end

-- ------------------------------------------------------------ al cargar
-- el modo en uso de este personaje, leído directo de ModosDB (todavía no está NS.pj)
function AU.modoGuardado()
    if type(ModosDB) ~= "table" or type(ModosDB.pj) ~= "table" then return nil end
    local n = UnitName and UnitName("player")
    local r = GetRealmName and GetRealmName()
    if not (n and r) then return nil end
    local pj = ModosDB.pj[n .. " - " .. r]
    return type(pj) == "table" and pj.activo or nil
end

-- instala lo que falte y deja cargando solo lo del modo (sin modo elegido: PvE)
local function preparar(m)
    local forzar = type(ModosDB) == "table" and ModosDB.auras and ModosDB.auras.reinstalar
    local puestas = AU.instalar(forzar)
    if forzar and AU.puedeInstalar() then ModosDB.auras.reinstalar = nil end
    AU.reubicadas = 0
    if type(ModosDB) == "table" and ModosDB.auras and ModosDB.auras.lugarClase ~= AU.LUGAR_CLASE and AU.puedeInstalar() then
        AU.reubicadas = AU.reubicarClases(displays())
        ModosDB.auras.lugarClase = AU.LUGAR_CLASE
    end
    AU.arregladas = AU.arreglarModos(displays())
    return puestas + AU.reubicadas + AU.arregladas, AU.aplicar(m or "PvE")
end

AU.aplicadoAntes = false
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, nombre)
    if event == "ADDON_LOADED" then
        if AU.aplicadoAntes or (nombre ~= "Modos" and nombre ~= "WeakAuras") then return end
        -- WeakAuras recién instalado (sin sus datos guardados todavía): se los empieza Modos
        if nombre == "WeakAuras" and WeakAurasSaved == nil and AU.puedeInstalar() then
            WeakAurasSaved = { displays = {} }
        end
        if displays() then
            preparar(AU.modoGuardado())
            AU.aplicadoAntes = true
        end
        return
    end
    -- por si no se pudo antes: WeakAuras ya las armó, se acomodan y se pide recargar
    local pj = NS.pj
    if AU.aplicadoAntes then
        if AU.puestas and #AU.puestas > 0 then
            NS.decir("Puse en tus WeakAuras " .. table.concat(AU.puestas, ", ") .. ". Cargan solas en su modo.")
        end
        if AU.actualizadas and #AU.actualizadas > 0 then
            NS.decir("Actualicé en tus WeakAuras " .. table.concat(AU.actualizadas, ", ") .. " (versión nueva de Modos).")
        end
        if AU.reubicadas and AU.reubicadas > 0 then
            NS.decir("Volví la WA de tu clase a su lugar (estaba corrida a mano). Tu marco y el objetivo se apoyan en su piso.")
        end
        if AU.arregladas and AU.arregladas > 0 then
            NS.decir("Arreglé las WeakAuras de clase: un solo número de tiempo en cada ícono (el de OmniCC) y el maná en K.")
        end
        return
    end
    if not displays() then return end
    local puestas, cambiadas = preparar(pj and pj.activo)
    AU.aplicadoAntes = true
    if puestas + cambiadas > 0 and StaticPopupDialogs and StaticPopup_Show then
        NS.decir("Acomodé las WeakAuras de " .. ((pj and pj.activo) or "PvE") .. ": hay que recargar para que se vean bien.")
        NS.recargando = true
        StaticPopupDialogs["MODOS_RECARGAR_AURAS"] = StaticPopupDialogs["MODOS_RECARGAR_AURAS"] or {
            text = "Modos: acomodé las WeakAuras de tu modo. Hay que recargar.",
            button1 = "Recargar",
            OnAccept = function() ReloadUI() end,
            timeout = 0, whileDead = 1, hideOnEscape = false, showAlert = 1,
        }
        if NS.pedirRecarga then NS.pedirRecarga("MODOS_RECARGAR_AURAS") else StaticPopup_Show("MODOS_RECARGAR_AURAS") end
    end
end)

-- /modos auras reinstalar: vuelve a poner (al recargar) los paquetes que borraste
function AU.reinstalar()
    if type(ModosDB) ~= "table" then return end
    ModosDB.auras = ModosDB.auras or {}
    ModosDB.auras.reinstalar = true
    NS.decir("Al recargar vuelvo a poner las WeakAuras que falten (las de PvE, la de tu clase y las de PvP).")
    if ReloadUI then ReloadUI() end
end
