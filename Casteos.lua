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

-- al entrar (ElvUI ya puso sus marcos) y otra vez un rato después, por si los movers
-- de tu rol se pusieron después
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function()
    if NS.despues then
        NS.despues(2, "casteos", C.acomodar)
        NS.despues(6, "casteos2", C.acomodar)
    else
        C.acomodar()
    end
end)
