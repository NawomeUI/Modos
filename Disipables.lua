-- Modos · Disipables (1.0.33): los buffs de Magia de un enemigo marcados en tu
-- objetivo de PvE, como hace ExtrasUI en PvP.
-- Lo pidió (25/10): "no me marca las cosas dispelleables, que era de las cosas que
-- más me gustaban de Extras". ExtrasUI prende el borde de "robable" de Blizzard en el
-- marco del objetivo de Blizzard (el de PvP, con EasyFrames). En PvE el objetivo y el
-- foco son de ElvUI: ElvUI solo marca lo que un mago puede robar (isStealable) y con
-- los filtros de Merfin ni siquiera mostraba los buffs de un enemigo.
-- Acá: cada buff de Magia de alguien que podés atacar lleva el mismo brillo de
-- Blizzard alrededor del ícono. Sigue la opción de ExtrasUI (/extras dispel): si la
-- apagaste allá, acá tampoco se marca.

local _, NS = ...

local D = {}
NS.disipables = D
D.TEXTURA = "Interface\\TargetingFrame\\UI-TargetingFrame-Stealable"
D.MARCOS = { "ElvUF_Target", "ElvUF_Focus" }
D.BORDE = 2

function D.prendido()
    if type(ExtrasUIDB) == "table" and ExtrasUIDB.dispel == false then return false end
    return true
end

-- ¿se marca este buff? Magia, de alguien que podés atacar (no vos)
function D.marca(unit, esDebuff, tipo)
    if esDebuff or tipo ~= "Magic" or not unit or not D.prendido() then return false end
    if UnitIsUnit and UnitIsUnit("player", unit) then return false end
    return (UnitCanAttack and UnitCanAttack("player", unit)) and true or false
end

function D.pintar(button, unit, tipo)
    if not button then return end
    local si = D.marca(unit, button.isDebuff, tipo or button.dtype)
    local b = button.modosDisipable
    if si and not b and button.CreateTexture then
        b = button:CreateTexture(nil, "OVERLAY")
        b:SetTexture(D.TEXTURA)
        b:SetBlendMode("ADD")
        b:SetPoint("TOPLEFT", button, "TOPLEFT", -D.BORDE, D.BORDE)
        b:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", D.BORDE, -D.BORDE)
        button.modosDisipable = b
    end
    if b then
        if si then b:Show() else b:Hide() end
    end
end

-- los buffs de ese marco de ElvUI pasan por acá después de que ElvUI los pinta.
-- ElvUI guarda su PostUpdateIcon al armar el marco (no alcanza con engancharle la
-- función a UF): se envuelve la del marco.
function D.envolver(nombre)
    local f = _G[nombre]
    local el = f and f.Buffs
    if not el or el.modosDisipables then return false end
    local orig = el.PostUpdateIcon
    el.PostUpdateIcon = function(self, unit, button, index, position, duration, expiration, tipo, ...)
        if orig then orig(self, unit, button, index, position, duration, expiration, tipo, ...) end
        D.pintar(button, unit, tipo)
    end
    el.modosDisipables = true
    if el.ForceUpdate then pcall(el.ForceUpdate, el) end
    return true
end

function D.enganchar()
    local n = 0
    for _, nombre in ipairs(D.MARCOS) do
        if D.envolver(nombre) then n = n + 1 end
    end
    return n
end

-- ElvUI arma sus marcos en PLAYER_LOGIN: se engancha al entrar (y otra vez un rato
-- después, por si alguno se armó tarde)
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function()
    D.enganchar()
    if NS.despues then NS.despues(3, "disipables", D.enganchar) end
end)
