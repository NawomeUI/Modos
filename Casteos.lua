-- Modos · Casteos (1.0.36): en PvE los casteos del objetivo y del foco los hace Quartz,
-- en el mismo lugar que tenían los de ElvUI: debajo de cada marco, pegados a su borde
-- izquierdo, con el ícono a la izquierda y el mismo ancho total.
-- Lo pidió (25/10): "las barras de cast no me gustan en ElvUI, poneme exactamente como
-- están en PvE, pero todo hecho con Quartz". Tu casteo lo sigue haciendo la WA de clase.
-- El lugar se calcula al entrar (y al cambiar de rol) desde dónde quedaron los marcos de
-- ElvUI: cambia con la clase (el piso de su WA) y el rol. Quartz los pone con la esquina
-- de abajo a la izquierda (x, y) en la pantalla, y la barra va 5 adentro de su marco.

local _, NS = ...

local C = {}
NS.casteos = C
C.MARCOS = { Target = "ElvUF_Target", Focus = "ElvUF_Focus" }
C.HUECO = 6           -- entre el marco y la barra (el borde de Quartz no lo toca)

local function quartz()
    local A = LibStub and LibStub("AceAddon-3.0", true)
    return A and A:GetAddon("Quartz3", true)
end

-- dónde va la barra de Quartz del módulo mod (Target o Focus): x, y, ancho de la
-- barra y alto, o nil si el marco todavía no está
function C.lugar(mod, escala, hueco)
    local medida = NS.presets and NS.presets.QUARTZ_PVE and NS.presets.QUARTZ_PVE[mod]
    local f = _G[C.MARCOS[mod] or ""]
    if not (medida and f and f.GetLeft and UIParent) then return nil end
    local izq, abajo = f:GetLeft(), f:GetBottom()
    if not (izq and abajo) then return nil end
    local k = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    izq, abajo = izq * k, abajo * k
    local s = escala or 1
    local g = hueco or 4
    local alto = medida.alto
    local ancho = medida.ancho - alto - g          -- el ícono (alto x alto) y su hueco van a la izquierda
    local barraIzq = izq + alto + g
    local barraAbajo = abajo - C.HUECO - alto
    return barraIzq / s - 5, barraAbajo / s - 5, ancho, alto
end

-- pone las barras en su lugar (solo en PvE). Devuelve cuántas movió.
function C.acomodar()
    if not (NS.pj and NS.pj.activo == "PvE") then return 0 end
    local Q = quartz()
    if not (Q and Q.GetModule) then return 0 end
    local n = 0
    for mod in pairs(C.MARCOS) do
        local ok, m = pcall(Q.GetModule, Q, mod, true)
        local db = ok and m and m.db and m.db.profile
        if db then
            local x, y, w, h = C.lugar(mod, db.scale, db.icongap)
            if x and not (db.x and math.abs(db.x - x) < 0.5 and db.y and math.abs(db.y - y) < 0.5
                          and db.w == w and db.h == h and db.iconposition == "left") then
                db.x, db.y, db.w, db.h, db.iconposition = x, y, w, h, "left"
                if m.ApplySettings then pcall(m.ApplySettings, m) end
                n = n + 1
            end
        end
    end
    return n
end

-- ------------------------------------------------------------ tu casteo en PvE (1.0.47)
-- En PvE tu casteo lo hace la barra de casteo de la WA de clase, y Quartz lo tiene
-- apagado (y esconde el de Blizzard). Pero la de Merfin carga según el talento: sin
-- talentos, con un talento que la WA no reconoce o sin la WA de clase, no había ninguna
-- barra de casteo (le pasaba a Zia, 08/11). Ahora, si no hay ninguna cargada, tu casteo
-- lo hace Quartz (sin tocar su perfil). Cuando la de la WA vuelve a cargar, se apaga.

-- ¿es la barra de casteo de una WA? (barra con disparador de casteo tuyo, sin filtro
-- de hechizos: "[Holy] Cast Bar" sí, "[Mage] Flamestrike + Blizzard Casts" no)
function C.esCasteoWA(d)
    if type(d) ~= "table" or d.regionType ~= "aurabar" then return false end
    local tr = type(d.triggers) == "table" and d.triggers[1]
    local t = type(tr) == "table" and tr.trigger
    return type(t) == "table" and t.type == "unit" and t.event == "Cast" and t.unit == "player"
        and not t.use_spellNames and not t.use_spellName and not t.use_spellId or false
end

-- ¿hay alguna barra de casteo de WA cargada ahora?
function C.hayCasteoWA()
    local W = WeakAuras
    local ds = type(WeakAurasSaved) == "table" and WeakAurasSaved.displays
    if not (type(W) == "table" and type(W.IsAuraLoaded) == "function" and type(ds) == "table") then return false end
    for id, d in pairs(ds) do
        if C.esCasteoWA(d) then
            local ok, cargada = pcall(W.IsAuraLoaded, id)
            if ok and cargada then return true end
        end
    end
    return false
end

-- prende o apaga el casteo de Quartz según haya o no barra de la WA (solo en PvE y
-- solo si en su perfil está apagado). Devuelve "prendido", "apagado" o nil.
C.propio = false
function C.tuCasteo()
    if not (NS.pj and NS.pj.activo == "PvE") then return nil end
    local Q = quartz()
    if not (Q and Q.GetModule and Q.EnableModule and Q.DisableModule and Q.db and Q.db.profile) then return nil end
    local ok, m = pcall(Q.GetModule, Q, "Player", true)
    if not (ok and m and m.IsEnabled) then return nil end
    local mods = Q.db.profile.modules
    if mods and mods.Player then C.propio = false; return nil end     -- prendido en Quartz: no se toca
    local falta = not C.hayCasteoWA()
    if falta and not m:IsEnabled() then
        if pcall(Q.EnableModule, Q, "Player") then C.propio = true; return "prendido" end
    elseif not falta and C.propio and m:IsEnabled() then
        if pcall(Q.DisableModule, Q, "Player") then C.propio = false; return "apagado" end
    end
    return nil
end

-- cuando Quartz vuelve a leer su perfil (cambio de perfil, texturas) apagaría el
-- casteo: se revisa otra vez
local enganchado = false
function C.enganchar()
    local Q = quartz()
    if enganchado or not (Q and hooksecurefunc and type(Q.ApplySettings) == "function") then return enganchado end
    hooksecurefunc(Q, "ApplySettings", function() pcall(C.tuCasteo) end)
    enganchado = true
    return true
end

-- al entrar (ElvUI ya puso sus marcos) y otra vez un rato después, por si los movers
-- de tu rol se pusieron después. Tu casteo, cuando WeakAuras ya cargó sus auras, y al
-- cambiar de talento o de nivel (la WA de clase carga según el talento)
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_TALENT_UPDATE")
ev:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:SetScript("OnEvent", function(_, event)
    C.enganchar()
    if event == "PLAYER_ENTERING_WORLD" then
        if NS.despues then
            NS.despues(2, "casteos", C.acomodar)
            NS.despues(6, "casteos2", C.acomodar)
        else
            C.acomodar()
        end
    end
    if NS.despues then
        NS.despues(3, "tucasteo", C.tuCasteo)
        NS.despues(8, "tucasteo2", C.tuCasteo)
    else
        C.tuCasteo()
    end
end)
