-- Modos · Reactivos (1.0.46): los hechizos que solo se pueden usar en ciertos momentos
-- (Execute, Kill Shot, Hammer of Wrath, Overpower, Revenge, Victory Rush, Mongoose
-- Bite, Counterattack, Riposte, Rune Strike) brillan cuando están listos: se pueden
-- usar y no están en recarga. Lo pidió (01/11): "todos los executes, o spells que se
-- activen en determinado momento pero no estén siempre activos, que se vean un poco
-- más claro cuando están disponibles".
-- Dónde: en las WeakAuras que pone Modos (la de tu clase y Mis CDs, en PvE y en PvP).
-- Cómo: al cargar, antes de que WeakAuras arme las auras (como el rojo fuera de rango
-- de Auras.lua), a cada ícono de esos hechizos se le suma un brillo dorado y la
-- condición que lo prende. A Mis CDs, además, el dato "reactivo" en su disparador (lo
-- da ModosMisCDsUso, CDs.lua). Se revisa en cada carga: si un paquete se actualiza, el
-- brillo se vuelve a poner. Lo que no reconoce, no lo toca.

local _, NS = ...

local R = {}
NS.reactivos = R
R.IDS = { 5308, 7384, 6572, 34428, 24275, 53351, 1495, 19306, 14251, 56815 }
R.INGLES = { "Execute", "Overpower", "Revenge", "Victory Rush", "Hammer of Wrath", "Kill Shot",
             "Mongoose Bite", "Counterattack", "Riposte", "Rune Strike" }
R.COLOR = { 1, 0.82, 0.2, 1 }

local nombres
function R.nombres()
    if nombres then return nombres end
    nombres = {}
    for _, n in ipairs(R.INGLES) do nombres[n] = true end
    for _, id in ipairs(R.IDS) do
        local n = GetSpellInfo and GetSpellInfo(id)
        if n then nombres[n] = true end
    end
    return nombres
end
function R.es(nombre) return type(nombre) == "string" and R.nombres()[nombre] == true end

-- el brillo que se suma (glow apagado: lo prende la condición)
local function brillo()
    return { type = "subglow", glow = false, glowType = "Pixel", useGlowColor = true,
             glowColor = { R.COLOR[1], R.COLOR[2], R.COLOR[3], R.COLOR[4] }, glowLines = 8, glowFrequency = 0.25,
             glowLength = 8, glowThickness = 2, glowScale = 1, glowBorder = false, glowXOffset = 0, glowYOffset = 0,
             glow_anchor = "region", modosReactivo = true }
end
local function yaTiene(d)
    for _, sr in ipairs(type(d.subRegions) == "table" and d.subRegions or {}) do
        if type(sr) == "table" and sr.modosReactivo then return true end
    end
    return false
end
local function sumarBrillo(d, check)
    if type(d.subRegions) ~= "table" then d.subRegions = {} end
    d.subRegions[#d.subRegions + 1] = brillo()
    if type(d.conditions) ~= "table" then d.conditions = {} end
    d.conditions[#d.conditions + 1] = { check = check,
        changes = { { property = "sub." .. #d.subRegions .. ".glow", value = true } } }
end

-- el hechizo de un disparador de hechizo de un ícono: índice, nombre y tipo
-- ("Cooldown Progress (Spell)": siempre a la vista; "Action Usable": aparece cuando se puede)
local EVENTOS = { ["Cooldown Progress (Spell)"] = true, ["Action Usable"] = true }
local function hechizoDe(d)
    for i, tr in ipairs(type(d.triggers) == "table" and d.triggers or {}) do
        local t = type(tr) == "table" and tr.trigger
        if type(t) == "table" and t.type == "spell" and EVENTOS[t.event] then
            local n = t.realSpellName
            if type(t.spellName) == "number" then n = (GetSpellInfo and GetSpellInfo(t.spellName)) or n
            elseif type(t.spellName) == "string" and t.spellName ~= "" then n = t.spellName end
            if R.es(n) then return i, n, t.event end
        end
    end
end

-- un ícono de la WA de clase: brilla si se puede usar y no está en recarga
function R.ponerClase(d)
    if type(d) ~= "table" or d.regionType ~= "icon" or yaTiene(d) then return false end
    local i, n, ev = hechizoDe(d)
    if not i then return false end
    if ev == "Action Usable" then
        sumarBrillo(d, { trigger = i, variable = "show", value = 1 })      -- solo aparece cuando se puede
    else
        sumarBrillo(d, { trigger = -2, variable = "AND", checks = {
            { trigger = i, variable = "spellUsable", value = 1 },
            { trigger = i, variable = "onCooldown", value = 0 },
        } })
    end
    return true
end

-- Mis CDs: el disparador de Modos lee ModosMisCDsUso; se le suma "reactivo" (4° valor)
R.MIS_CDS = {
    { "local lejos, sinMana, inusable = false, false, false",
      "local lejos, sinMana, inusable, reactivo = false, false, false, false" },
    { "lejos, sinMana, inusable = ModosMisCDsUso(x)",
      "lejos, sinMana, inusable, reactivo = ModosMisCDsUso(x)" },
    { "and st.inusable == inusable) then",
      "and st.inusable == inusable and st.reactivo == reactivo) then" },
    { "inusable = inusable }",
      "inusable = inusable, reactivo = reactivo }" },
}
local function reemplazarUnaVez(s, a, b)
    local i, j = s:find(a, 1, true)
    if not i or s:find(a, j + 1, true) then return nil end
    return s:sub(1, i - 1) .. b .. s:sub(j + 1)
end
function R.ponerMisCDs(d)
    if type(d) ~= "table" or d.regionType ~= "icon" or yaTiene(d) then return false end
    local tr = type(d.triggers) == "table" and d.triggers[1]
    local t = type(tr) == "table" and tr.trigger
    if not (type(t) == "table" and t.type == "custom" and type(t.custom) == "string"
            and t.custom:find("ModosMisCDsUso(x)", 1, true)) then return false end
    local codigo = t.custom
    for _, p in ipairs(R.MIS_CDS) do
        codigo = reemplazarUnaVez(codigo, p[1], p[2])
        if not codigo then return false end                -- no es el que conozco: no se toca
    end
    if loadstring and not loadstring("return " .. codigo) then return false end
    local vars = type(t.customVariables) == "string" and t.customVariables or ""
    local nuevas = vars:gsub("}%s*$", ", reactivo = 'bool' }", 1)
    if nuevas == vars or not nuevas:find("reactivo", 1, true) then return false end
    t.custom, t.customVariables = codigo, nuevas
    sumarBrillo(d, { trigger = -2, variable = "AND", checks = {
        { trigger = 1, variable = "reactivo", value = 1 },
        { trigger = 1, variable = "enCD", value = 0 },
    } })
    return true
end

-- todas las auras de los paquetes que puso Modos. Devuelve cuántas tocó.
function R.arreglar(ds)
    if type(ds) ~= "table" or type(ModosDB) ~= "table" or type(ModosDB.auras) ~= "table" then return 0 end
    local inst = ModosDB.auras.instalados or {}
    local function arriba(d)
        local n = 0
        while type(d) == "table" and type(d.parent) == "string" and type(ds[d.parent]) == "table" and n < 20 do
            d, n = ds[d.parent], n + 1
        end
        return d
    end
    local n = 0
    for _, d in pairs(ds) do
        if type(d) == "table" and d.regionType == "icon" and not yaTiene(d) then
            local top = arriba(d)
            if type(top) == "table" and ((type(top.uid) == "string" and inst[top.uid]) or (top.id and inst[top.id])) then
                local ok, hizo = pcall(R.ponerMisCDs, d)
                if not (ok and hizo) then ok, hizo = pcall(R.ponerClase, d) end
                if ok and hizo then n = n + 1 end
            end
        end
    end
    return n
end

-- al cargar Modos o WeakAuras (lo que llegue con los dos), después de que Auras.lua
-- puso o actualizó los paquetes y antes de que WeakAuras arme las auras
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(_, _, nombre)
    if nombre ~= "Modos" and nombre ~= "WeakAuras" then return end
    local ds = type(WeakAurasSaved) == "table" and WeakAurasSaved.displays
    if type(ds) == "table" then R.hechas = (R.hechas or 0) + R.arreglar(ds) end
end)
