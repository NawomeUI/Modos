-- Modos · Listo para el pull (1.0.15) y aviso de durabilidad.
--
-- En una mazmorra o banda muestra arriba del centro lo que te falta antes de
-- pelear, en una fila de íconos con su nombre. Sale al entrar a la instancia (un
-- rato), con la revisión de listos (ready check), al empezar la cuenta del pull de
-- DBM y con /modos listo. Se va al entrar en combate, cuando ya no falta nada o al
-- terminar el tiempo. Lo que revisa:
--   * en banda: frasco o elixires y comida;
--   * buffs de banda de las clases que hay en el grupo (Marca, Entereza, Intelecto
--     si usás maná, una Bendición);
--   * lo de tu clase: aura y sello del paladín (y Furia justa si tanqueás), presencia
--     del DK, aspecto del cazador, venenos del pícaro, imbuir del chamán, armadura
--     del mago y del brujo, Fuego interno del sacerdote;
--   * piedra de salud si hay un brujo;
--   * el equipo con poca durabilidad.
-- Durabilidad: al entrar a una mazmorra o banda, si algo está por debajo del 30%
-- (o roto) lo dice en el chat y en grande arriba. Los números de las listas son
-- los de las auras de 3.3.5 (sacados de las tablas de MRT).

local _, NS = ...
local E = NS.E

local L = {}
NS.listo = L

local function conjunto(...)
    local t = {}
    for _, v in ipairs({ ... }) do t[v] = true end
    return t
end

-- comida (Bien alimentado) y frascos/elixires de TBC y WotLK
L.COMIDA = conjunto(33257, 35272, 45245, 33254, 33268, 33263, 33259, 33261, 33256, 43764, 43722, 33265, 45619, 46682,
    44104, 44098, 44101, 44099, 44102, 44106, 44105, 44097, 44100, 43771, 33272, 46899, 40323, 42293, 57367, 57327, 57294,
    57360, 57291, 57332, 57356, 57325, 57358, 57365, 57329, 57334, 57371, 57079, 57097, 57139, 57286, 57100, 57102, 57288,
    53284, 57111, 57107, 57363, 57399, 65410, 65412, 65414, 65415, 65416, 66623, 25661)
L.FRASCO = conjunto(28518, 28540, 28520, 28521, 28519, 42735, 41609, 46837, 41608, 46839, 41610, 41611, 40572, 40576,
    40567, 40568, 40573, 40575, 28503, 38954, 28497, 28501, 28493, 28491, 33726, 28490, 33721, 33720, 28514, 28509, 28502,
    39628, 39627, 39626, 39625, 28496, 28489, 28515, 38910, 38927, 28511, 28537, 28513, 28512, 28536, 28538, 53760, 53755,
    67019, 67016, 67017, 67018, 53758, 54212, 62380, 53752, 60347, 53749, 60346, 53746, 60345, 53764, 53748, 60344, 60341,
    53763, 53751, 60340, 53747, 60343, 63729)
-- buffs de banda: de qué clase y qué auras cuentan
L.BANDA = {
    { clase = "DRUID", nombre = "Marca", icono = "Interface\\Icons\\Spell_Nature_Regeneration",
      auras = conjunto(1126, 5232, 6756, 5234, 8907, 9884, 9885, 26990, 48469, 21849, 21850, 26991, 48470, 69381) },
    { clase = "PRIEST", nombre = "Entereza", icono = "Interface\\Icons\\Spell_Holy_WordFortitude",
      auras = conjunto(1243, 1244, 1245, 2791, 10937, 10938, 25389, 48161, 21562, 21564, 25392, 48162, 69377) },
    { clase = "MAGE", nombre = "Intelecto", icono = "Interface\\Icons\\Spell_Holy_MagicalSentry", mana = true,
      auras = conjunto(1459, 1460, 1461, 10156, 10157, 27126, 42995, 23028, 27127, 43002, 61316, 61024) },
    { clase = "PALADIN", nombre = "Bendición", icono = "Interface\\Icons\\Spell_Holy_FistOfJustice",
      auras = conjunto(19740, 19834, 19835, 19836, 19837, 19838, 25291, 27140, 48931, 48932, 25782, 25916, 27141, 48933,
          48934, 19742, 19850, 19852, 19853, 19854, 25290, 27142, 48935, 48936, 25894, 25918, 27143, 48937, 48938, 20217,
          25898, 69378, 25899, 20911) },
}
-- lo de cada clase. forma: la postura/aura/presencia (GetShapeshiftForm), auras: alguna
-- de esas, arma: algo en el arma (venenos, imbuir), tanque: solo con rol Tank
L.CLASE = {
    PALADIN = {
        { nombre = "Aura", icono = "Interface\\Icons\\Spell_Holy_DevotionAura", forma = true },
        { nombre = "Sello", icono = "Interface\\Icons\\Ability_ThunderBolt",
          auras = conjunto(21084, 20154, 20375, 20165, 20166, 20164, 31801, 53736, 31892, 53720) },
        { nombre = "Furia justa", icono = "Interface\\Icons\\Spell_Holy_SealOfFury", tanque = true, auras = conjunto(25780) },
    },
    DEATHKNIGHT = { { nombre = "Presencia", icono = "Interface\\Icons\\Spell_Deathknight_BloodPresence", forma = true } },
    HUNTER = { { nombre = "Aspecto", icono = "Interface\\Icons\\Ability_Hunter_Pet_Dragonhawk",
                 auras = conjunto(61846, 61847, 13165, 14318, 14319, 14320, 14321, 14322, 25296, 27044, 34074, 13163,
                     5118, 13159, 13161, 20043, 20190, 27045, 49071) } },
    ROGUE = { { nombre = "Venenos", icono = "Interface\\Icons\\Ability_Poisons", arma = true } },
    SHAMAN = { { nombre = "Imbuir", icono = "Interface\\Icons\\Spell_Fire_FlameTounge", arma = true } },
    MAGE = { { nombre = "Armadura", icono = "Interface\\Icons\\Ability_Mage_MoltenArmor",
               auras = conjunto(30482, 43045, 43046, 168, 7300, 7301, 7302, 7320, 10219, 10220, 27124, 43008, 6117,
                   22782, 22783, 27125, 43023, 43024) } },
    WARLOCK = { { nombre = "Armadura", icono = "Interface\\Icons\\Spell_Shadow_FelArmour",
                  auras = conjunto(28176, 28189, 47892, 47893, 687, 696, 706, 1086, 11733, 11734, 11735, 27260, 47793, 47889) } },
    PRIEST = { { nombre = "Fuego interno", icono = "Interface\\Icons\\Spell_Holy_InnerFire",
                 auras = conjunto(588, 7128, 602, 1006, 10951, 10952, 25431, 48040, 48168) } },
}
L.PIEDRAS = { 36892, 36893, 36894, 22103, 22104, 22105, 9421, 19012, 19013, 5512, 19004, 19005, 5511, 19006, 19007,
              5509, 19008, 19009, 5510, 19010, 19011 }
L.DURABILIDAD = 0.3            -- por debajo de esto, a reparar
L.TIEMPO = 20                  -- cuánto se ve al entrar o con /modos listo

-- ------------------------------------------------------------ qué falta
local function enInstancia()
    if not IsInInstance then return nil end
    local adentro, tipo = IsInInstance()
    if adentro and (tipo == "party" or tipo == "raid") then return tipo end
    return nil
end
L.enInstancia = enInstancia

local function misAuras()
    local t = {}
    if not UnitAura then return t end
    for i = 1, 40 do
        local nombre, _, _, _, _, _, _, _, _, _, id = UnitAura("player", i, "HELPFUL")
        if not nombre then break end
        if id then t[id] = true end
    end
    return t
end
local function tiene(auras, set)
    for id in pairs(set) do if auras[id] then return true end end
    return false
end

-- clases en el grupo (vos incluido)
local function clasesDelGrupo()
    local t = {}
    local _, yo = UnitClass("player")
    if yo then t[yo] = true end
    local nr = GetNumRaidMembers and GetNumRaidMembers() or 0
    local np = GetNumPartyMembers and GetNumPartyMembers() or 0
    if nr > 0 then
        for i = 1, nr do local _, c = UnitClass("raid" .. i); if c then t[c] = true end end
    else
        for i = 1, np do local _, c = UnitClass("party" .. i); if c then t[c] = true end end
    end
    return t
end

-- la peor durabilidad del equipo puesto (0 a 1) o nil si no se sabe
function L.durabilidad()
    if not GetInventoryItemDurability then return nil end
    local peor
    for slot = 1, 18 do
        local actual, max = GetInventoryItemDurability(slot)
        if actual and max and max > 0 then
            local p = actual / max
            if not peor or p < peor then peor = p end
        end
    end
    return peor
end

local function armaCon(mano)                      -- mano: 16 o 17
    if not GetWeaponEnchantInfo then return true end
    local mh, _, _, oh = GetWeaponEnchantInfo()
    if mano == 16 then return mh and true or false end
    return oh and true or false
end
local function hayArma(slot)
    if not GetInventoryItemLink then return slot == 16 end
    local link = GetInventoryItemLink("player", slot)
    if not link then return false end
    if slot ~= 17 then return true end
    -- en la otra mano solo cuenta un arma (no un escudo ni un libro)
    local tipo
    if GetItemInfo then tipo = select(6, GetItemInfo(link)) end
    return tipo == nil or tipo == "Weapon" or tipo == "Arma"
end

-- lo que te falta: { { nombre, icono }, ... }
function L.faltan()
    local r = {}
    local tipo = enInstancia()
    local auras = misAuras()
    if tipo == "raid" then
        if not tiene(auras, L.FRASCO) then r[#r + 1] = { nombre = "Frasco", icono = "Interface\\Icons\\INV_Alchemy_EndlessFlask_06" } end
        if not tiene(auras, L.COMIDA) then r[#r + 1] = { nombre = "Comida", icono = "Interface\\Icons\\INV_Misc_Food_15" } end
    end
    local clases = clasesDelGrupo()
    local mana = UnitPowerType and UnitPowerType("player") == 0
    for _, b in ipairs(L.BANDA) do
        if clases[b.clase] and (not b.mana or mana) and not tiene(auras, b.auras) then
            r[#r + 1] = { nombre = b.nombre, icono = b.icono }
        end
    end
    local _, yo = UnitClass("player")
    local rol = NS.rol and NS.rol.actual and NS.rol.actual()
    for _, c in ipairs(L.CLASE[yo or ""] or {}) do
        local falta = false
        if c.tanque and rol ~= "Tank" then
            falta = false
        elseif c.forma then
            falta = GetShapeshiftForm and GetShapeshiftForm() == 0
        elseif c.arma then
            falta = (hayArma(16) and not armaCon(16)) or (hayArma(17) and not armaCon(17))
        elseif c.auras then
            falta = not tiene(auras, c.auras)
        end
        if falta then r[#r + 1] = { nombre = c.nombre, icono = c.icono } end
    end
    if clases.WARLOCK and GetItemCount then
        local hay = false
        for _, id in ipairs(L.PIEDRAS) do if (GetItemCount(id) or 0) > 0 then hay = true; break end end
        if not hay then r[#r + 1] = { nombre = "Piedra de salud", icono = "Interface\\Icons\\INV_Stone_04" } end
    end
    local d = L.durabilidad()
    if d and d < L.DURABILIDAD then
        r[#r + 1] = { nombre = ("Reparar (%d%%)"):format(math.floor(d * 100 + 0.5)), icono = "Interface\\Icons\\Trade_BlackSmithing" }
    end
    return r
end

-- ------------------------------------------------------------ cartel
-- arriba del centro, encima de tu personaje y de la WA de clase (no se pisa con nada
-- de la UI: prueba [37])
L.LUGAR = { y = 100, lado = 30, sep = 6, ancho = 70 }
function L.caja(n)
    local p = L.LUGAR
    local ancho = n * p.ancho + (n - 1) * p.sep + 16
    return -ancho / 2, 540 + p.y, ancho / 2, 540 + p.y + 22 + p.lado + 16
end

local hasta = 0
local function armar()
    if L.marco or not E then return L.marco end
    local f = CreateFrame("Frame", "ModosListo", UIParent)
    f:SetFrameStrata("MEDIUM")
    f:SetPoint("BOTTOM", UIParent, "CENTER", 0, L.LUGAR.y)
    E.ventana(f)
    f.titulo = E.texto(f, "chico")
    f.titulo:SetPoint("TOP", f, "TOP", 0, -6)
    f.iconos = {}
    f:Hide()
    f:SetScript("OnUpdate", function(self, dt)
        self.t = (self.t or 0) + dt
        if self.t < 0.5 then return end
        self.t = 0
        if GetTime() >= hasta then self:Hide(); return end
        L.refrescar()
    end)
    L.marco = f
    return f
end

local function icono(f, i)
    local b = f.iconos[i]
    if b then return b end
    b = CreateFrame("Frame", nil, f)
    b:SetWidth(L.LUGAR.ancho); b:SetHeight(L.LUGAR.lado + 14)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetWidth(L.LUGAR.lado); b.tex:SetHeight(L.LUGAR.lado)
    b.tex:SetPoint("TOP", b, "TOP", 0, 0)
    b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.txt = E.texto(b, "chico")
    b.txt:SetPoint("TOP", b.tex, "BOTTOM", 0, -2)
    b.txt:SetWidth(L.LUGAR.ancho)
    f.iconos[i] = b
    return b
end

-- vuelve a mirar qué falta. Sin nada pendiente (o en combate) se va.
function L.refrescar()
    local f = L.marco
    if not f or not f:IsShown() then return 0 end
    if InCombatLockdown and InCombatLockdown() then f:Hide(); return 0 end
    local l = L.faltan()
    if #l == 0 then f:Hide(); return 0 end
    local p = L.LUGAR
    f:SetWidth(#l * p.ancho + (#l - 1) * p.sep + 16)
    f:SetHeight(22 + p.lado + 16)
    f.titulo:SetText("Antes del pull te falta:")
    for i, x in ipairs(l) do
        local b = icono(f, i)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", f, "TOPLEFT", 8 + (i - 1) * (p.ancho + p.sep), -22)
        b.tex:SetTexture(x.icono)
        b.txt:SetText(x.nombre)
        b:Show()
    end
    for i = #l + 1, #f.iconos do f.iconos[i]:Hide() end
    return #l
end

-- lo muestra por seg segundos (si falta algo). Devuelve cuántas cosas faltan.
function L.mostrar(seg)
    if InCombatLockdown and InCombatLockdown() then return 0 end
    local f = armar()
    if not f then return 0 end
    hasta = math.max(hasta, GetTime() + (seg or L.TIEMPO))
    f:Show()
    return L.refrescar()
end

function L.ocultar()
    hasta = 0
    if L.marco then L.marco:Hide() end
end

-- /modos listo
function L.comando()
    local n = L.mostrar(L.TIEMPO)
    if n == 0 then NS.decir("Listo para el pull: no te falta nada.") end
end

-- ------------------------------------------------------------ durabilidad
function L.avisarDurabilidad()
    local d = L.durabilidad()
    if not d or d >= L.DURABILIDAD then return false end
    local txt = d <= 0 and "Tenés equipo roto: repará antes de pelear." or
        ("Durabilidad baja (%d%%): repará antes de pelear."):format(math.floor(d * 100 + 0.5))
    NS.decir(txt)
    if UIErrorsFrame and UIErrorsFrame.AddMessage then UIErrorsFrame:AddMessage(txt, 1, 0.3, 0.3) end
    return true
end

-- ------------------------------------------------------------ eventos
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("READY_CHECK")
ev:RegisterEvent("CHAT_MSG_ADDON")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
local dondeAntes
ev:SetScript("OnEvent", function(_, event, a1, a2)
    if not NS.pj or NS.pj.activo == "PvP" then return end
    if event == "PLAYER_REGEN_DISABLED" then
        L.ocultar()
    elseif event == "PLAYER_ENTERING_WORLD" then
        local tipo = enInstancia()
        local entro = tipo and dondeAntes ~= tipo
        dondeAntes = tipo
        if entro then
            L.avisarDurabilidad()
            if NS.despues then NS.despues(3, "listo", function() L.mostrar(L.TIEMPO) end) end
        end
    elseif event == "READY_CHECK" then
        if enInstancia() then L.mostrar(35) end
    elseif event == "CHAT_MSG_ADDON" then
        -- la cuenta del pull de DBM: "PT\t<segundos>"
        if a1 == "D4" and type(a2) == "string" then
            local seg = tonumber(a2:match("^PT\t(%d+)"))
            if seg and seg > 0 and enInstancia() then L.mostrar(seg) end
        end
    end
end)
