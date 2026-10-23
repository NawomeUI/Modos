-- Modos · ArenaGladius (1.0.4): en Gladius, el trinket grande y el DR a la
-- izquierda de cada marco (entre el casteo y la vida), un poco más grandes.
-- Gladius 1.2.0 pone el trinket grande siempre a la derecha del marco: después
-- de que arma sus marcos (Gladius:UpdateFrame) Modos lo corre a la izquierda,
-- pega el DR a su lado (drCooldownPos = "LEFT" en Presets.lua: los íconos crecen
-- hacia la izquierda) y corre el casteo (castBarPos = "LEFT") para dejarles
-- lugar. El trinket más grande lo hace Gladius (bigTrinketScale).

local _, NS = ...

local G = {}
NS.gladius = G
G.ESPACIO = 3        -- entre el marco, el trinket, el DR y el casteo
G.DR_LUGAR = 3       -- íconos de DR que entran entre el trinket y el casteo
G.DR_ESCALA = 1.15   -- los íconos de DR, un poco más grandes

local function ancho(f)
    local w = f and f.GetWidth and f:GetWidth() or 0
    return w or 0
end

-- acomoda los marcos de Gladius que ya existen
function G.acomodar()
    local gl = Gladius
    if type(gl) ~= "table" or type(gl.buttons) ~= "table" then return false end
    local db = gl.db and gl.db.profile
    if type(db) ~= "table" then return false end
    local hecho = false
    for _, b in pairs(gl.buttons) do
        if type(b) == "table" and b.bigTrinket and b.SetPoint then
            local izq, ocupado = b, 0
            -- el trinket, pegado a la izquierda del marco
            if db.trinketDisplay == "bigIcon" and db.trinketStatus then
                b.bigTrinket:ClearAllPoints()
                b.bigTrinket:SetPoint("TOPRIGHT", b, "TOPLEFT", -G.ESPACIO, 0)
                izq = b.bigTrinket
                ocupado = ancho(b.bigTrinket) + G.ESPACIO
            end
            -- el DR, a la izquierda del trinket
            local dr = b.drCooldownFrame
            if db.drCooldown and dr and db.drCooldownPos == "LEFT" then
                if dr.SetScale then dr:SetScale(G.DR_ESCALA) end
                dr:ClearAllPoints()
                dr:SetPoint("TOPRIGHT", izq, "TOPLEFT", -G.ESPACIO / G.DR_ESCALA, -1 / G.DR_ESCALA)
                local icono = dr.icon1
                local lado = (ancho(icono) > 0 and ancho(icono) or ancho(dr)) * G.DR_ESCALA
                ocupado = ocupado + G.ESPACIO + G.DR_LUGAR * (lado + (db.drMargin or 5) - 5)
            end
            -- el casteo, a la izquierda de todo eso
            local cb = b.castBar
            if cb and db.castBar and db.castBarPos == "LEFT" then
                cb:ClearAllPoints()
                cb:SetPoint("TOPRIGHT", b, "TOPLEFT", -(ocupado + G.ESPACIO), 0)
            end
            hecho = true
        end
    end
    return hecho
end

local enganchado = false
function G.enganchar()
    if enganchado then return true end
    local gl = Gladius
    if type(gl) ~= "table" or type(gl.UpdateFrame) ~= "function" or not hooksecurefunc then return false end
    hooksecurefunc(gl, "UpdateFrame", function() pcall(G.acomodar) end)
    enganchado = true
    pcall(G.acomodar)
    return true
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function() G.enganchar() end)
