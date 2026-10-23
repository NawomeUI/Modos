-- Modos · Rol de PvE (12/10): Tank, DPS o Heal para cada talento.
--
-- La primera vez que entrás en PvE con un talento sin rol, Modos pregunta.
-- Después: /modos rol tank, /modos rol dps, /modos rol heal (para el talento en
-- uso) o el botón de la ventana. Según el rol del talento en uso:
--   * ElvUI: tu marco, el objetivo, el foco y sus casteos en el lugar de Merfin
--     (Presets.lua, PR.MOVERS). Se acomodan en el momento, también al cambiar de
--     talento.
--   * Cell: la primera vez importa el perfil de Cell de Merfin (dejando tus clics)
--     y acomoda sus diseños: DPS/Tank al costado izquierdo, Heal abajo al medio en
--     5 columnas (una por grupo). Cell cambia solo de diseño con cada talento.
--   * Mis CDs PvE: debajo de la WA de clase (DPS/Tank) o debajo del Cell (Heal).
-- Todo esto solo en PvE; en PvP no se toca nada.

local _, NS = ...
local E = NS.E

local R = {}
NS.rol = R

R.ROLES = { "Tank", "DPS", "Heal" }
local VIEJOS = { ["DPS/Tank"] = "DPS", Healer = "Heal" }      -- de cuando eran los perfiles de MerfinUI

function R.grupo()
    return GetActiveTalentGroup and GetActiveTalentGroup() or 1
end

local function tabla()
    local pj = NS.pj
    if not pj then return nil end
    if type(pj.rolPvE) == "string" then
        local v = VIEJOS[pj.rolPvE] or pj.rolPvE
        pj.rolPvE = { [1] = v, [2] = v }
    end
    pj.rolPvE = pj.rolPvE or {}
    return pj.rolPvE
end

-- (1.0.13) solo los roles que la clase puede hacer (un pícaro con Heal dejaba todo
-- desacomodado: los marcos de heal y la WA de clase de DPS)
R.PUEDE = {
    WARRIOR = { Tank = true, DPS = true }, PALADIN = { Tank = true, DPS = true, Heal = true },
    DEATHKNIGHT = { Tank = true, DPS = true }, DRUID = { Tank = true, DPS = true, Heal = true },
    PRIEST = { DPS = true, Heal = true }, SHAMAN = { DPS = true, Heal = true },
    ROGUE = { DPS = true }, MAGE = { DPS = true }, WARLOCK = { DPS = true }, HUNTER = { DPS = true },
}
local function clase()
    if not UnitClass then return nil end
    local _, c = UnitClass("player")
    return c
end
function R.puede(rol)
    local p = R.PUEDE[clase() or ""]
    return not p or p[rol] == true
end
function R.posibles()
    local l = {}
    for _, rol in ipairs(R.ROLES) do if R.puede(rol) then l[#l + 1] = rol end end
    return l
end
local NOMBRE_CLASE = { WARRIOR = "un guerrero", PALADIN = "un paladín", DEATHKNIGHT = "un caballero de la muerte",
    DRUID = "un druida", PRIEST = "un sacerdote", SHAMAN = "un chamán", ROGUE = "un pícaro", MAGE = "un mago",
    WARLOCK = "un brujo", HUNTER = "un cazador" }
local function quien() return NOMBRE_CLASE[clase() or ""] or "esta clase" end

-- el rol de un talento (nil si no lo elegiste). (1.0.13) Si la clase puede hacer
-- un solo rol, es ese (sin preguntar). Si tenía guardado uno que no puede (de antes
-- de la 1.0.13), queda como DPS y avisa una vez.
function R.de(g)
    local t = tabla()
    if not t then return nil end
    g = g or R.grupo()
    local v = t[g]
    if v and not R.puede(v) then
        t[g] = "DPS"
        NS.decir(("Rol en PvE: %s no puede ser %s. Quedó como DPS (talento %d)."):format(quien(), v, g))
        return "DPS"
    end
    if not v then
        local l = R.posibles()
        if #l == 1 then t[g] = l[1]; return l[1] end
    end
    return v
end
function R.actual() return R.de(R.grupo()) end

local function enPvE() return NS.pj and NS.pj.activo == "PvE" end

-- ------------------------------------------------------------ ElvUI
-- (1.0.14) la rama de talentos con más puntos del talento en uso (1 a 3)
local function rama()
    if not GetTalentTabInfo then return nil end
    local g = R.grupo()
    local mejor, max = nil, -1
    for i = 1, 3 do
        local _, _, puntos = GetTalentTabInfo(i, false, false, g)
        puntos = tonumber(puntos) or 0
        if puntos > max then mejor, max = i, puntos end
    end
    return mejor
end
R.rama = rama

-- el piso de la WA de clase de este personaje para ese rol (nil: no se sabe)
function R.piso(rol)
    local t = NS.PISOS_WA and NS.PISOS_WA[(rol == "Heal") and "Heal" or "DPS"]
    local v = t and t[clase() or ""]
    if type(v) == "table" then
        local r = rama()
        v = (r and v[r]) or v[1] or v[2] or v[3]
    end
    return v
end

-- los movers del rol, con tu marco y el objetivo apoyados en el piso de la WA de
-- clase: todo lo anclado abajo al medio se corre lo mismo (los jefes no)
function R.movers(rol)
    local pr = NS.presets
    local base = pr and pr.MOVERS and (pr.MOVERS[rol or "DPS"] or pr.MOVERS.DPS)
    if not base then return nil end
    local piso = R.piso(rol)
    local ref = pr.MOVERS_PISO and pr.MOVERS_PISO[(rol == "Heal") and "Heal" or "DPS"]
    if not (piso and ref) or piso == ref then return base end
    local r = {}
    for k, v in pairs(base) do
        local a, x, y = v:match("^(BOTTOM,ElvUIParent,BOTTOM),([-%d.]+),([-%d.]+)$")
        r[k] = a and ("%s,%s,%s"):format(a, x, tostring(tonumber(y) + piso - ref)) or v
    end
    return r
end

function R.ponerElvUI()
    if not enPvE() then return false end
    local E1 = ElvUI and ElvUI[1]
    if not (E1 and E1.db and E1.private and E1.private.unitframe and E1.private.unitframe.enable) then return false end
    E1.db.movers = E1.db.movers or {}
    for k, v in pairs(R.movers(R.actual())) do E1.db.movers[k] = v end
    if E1.SetMoversPositions then pcall(E1.SetMoversPositions, E1) end
    return true
end

-- ------------------------------------------------------------ Cell
R.CELL_VERSION = 4
R.CELL = {
    Heal = { party = "Healer: Party || Full HD", raid = "Healer: Raid10-25 || Full HD", raid40 = "Healer: Raid40 || Full HD" },
    DPS = { party = "DPS/Tank: Party || Full HD", raid = "DPS/Tank: Raid10-25 || Full HD", raid40 = "DPS/Tank: Raid40 || Full HD" },
}
R.CELL.Tank = R.CELL.DPS
-- Siempre un grupo por columna (12/10), de a 5 (una grilla de 5 x 5 en 25).
-- El ancla de Cell es un cuadradito de 20 x 10: con anchor TOPLEFT los marcos
-- empiezan 4 debajo de su borde de abajo y su BOTTOM queda 10 a la derecha del
-- borde izquierdo de los marcos. Con BOTTOMLEFT empiezan 4 arriba de su borde de arriba.
-- (1.0.15) al estilo de la captura de banda que mandó (21:41 del 18/10): marcos
-- compactos con 2 de separación, la vida del color de la clase, el nombre al medio.
--   Heal: abajo al medio, de 344 a 126 (Mis CDs de heal empieza en 125). Banda 80x42
--   (5 columnas, 408 de ancho), grupo 100x42 (una columna), 40 en 80x36 (8 columnas).
--   DPS/Tank: a la izquierda, arriba del chat (que llega a 239), desde 349 para arriba.
--   El grupo de 5 de DPS ya no queda chico (era 105x29 debajo de tu marco): 100x42.
R.CELL_DISENOS = {
    ["Healer: Raid10-25 || Full HD"] = { orientation = "vertical", size = { 80, 42 }, anchor = "TOPLEFT",
        position = { "BOTTOM", -194, 348 }, spacingX = 2, spacingY = 2, unitsPerColumn = 5, maxColumns = 8, powerSize = 4 },
    ["Healer: Party || Full HD"] = { orientation = "vertical", size = { 100, 42 }, anchor = "TOPLEFT",
        position = { "BOTTOM", -40, 348 }, spacingX = 2, spacingY = 2, unitsPerColumn = 5, maxColumns = 8, powerSize = 4 },
    ["Healer: Raid40 || Full HD"] = { orientation = "vertical", size = { 80, 36 }, anchor = "TOPLEFT",
        position = { "BOTTOM", -317, 348 }, spacingX = 2, spacingY = 2, unitsPerColumn = 5, maxColumns = 8, powerSize = 3 },
    ["DPS/Tank: Party || Full HD"] = { orientation = "vertical", size = { 100, 42 }, anchor = "BOTTOMLEFT",
        position = { "BOTTOMLEFT", 4, 335 }, spacingX = 2, spacingY = 2, unitsPerColumn = 5, maxColumns = 8, powerSize = 4 },
    ["DPS/Tank: Raid10-25 || Full HD"] = { orientation = "vertical", size = { 80, 42 }, anchor = "BOTTOMLEFT",
        position = { "BOTTOMLEFT", 4, 335 }, spacingX = 2, spacingY = 2, unitsPerColumn = 5, maxColumns = 8, powerSize = 4 },
    ["DPS/Tank: Raid40 || Full HD"] = { orientation = "vertical", size = { 80, 36 }, anchor = "BOTTOMLEFT",
        position = { "BOTTOMLEFT", 4, 335 }, spacingX = 2, spacingY = 2, unitsPerColumn = 5, maxColumns = 8, powerSize = 3 },
}
-- dónde sale el cartelito al pasar el mouse por Cell, para que no lo tape: en heal
-- a la izquierda del Cell, en DPS/Tank arriba (las columnas crecen a la derecha y
-- cambian con el tamaño del grupo: arriba no tapa ninguna)
R.CELL_TOOLTIP = {
    Heal = { "TOPRIGHT", "Cell", "TOPLEFT", -6, 0 },
    DPS = { "BOTTOMLEFT", "Cell", "BOTTOMLEFT", 0, 224 },
}
R.CELL_TOOLTIP.Tank = R.CELL_TOOLTIP.DPS

-- colores de clase (el "Class Theme" de Merfin): barra del color de la clase, lo
-- perdido oscuro y el nombre en blanco
local function temaClase()
    CellDB.appearance = CellDB.appearance or {}
    local ap = CellDB.appearance
    ap.barAlpha, ap.bgAlpha, ap.lossAlpha = 1, 0.5, 0.8
    ap.barColor = { "class_color", { 0.82, 0.68, 0.68 } }
    ap.lossColor = { "custom", { 0.19, 0.157, 0.157 } }
    for _, l in pairs(CellDB.layouts) do
        for _, ind in ipairs(type(l) == "table" and l.indicators or {}) do
            if ind.indicatorName == "nameText" then
                ind.color = { "custom_color", { 1, 1, 1 } }
            elseif ind.indicatorName == "roleIcon" and type(ind.roleTexture) == "table" then
                ind.roleTexture[1] = "blizzard3"
            end
        end
    end
end

function R.cellListo()
    return CellDB and CellDB.layouts and CellDB.layouts["Healer: Raid10-25 || Full HD"] ~= nil
end

-- importa el perfil de Merfin una vez (deja tus clics de Cell). Devuelve true si importó.
function R.importarCell()
    if R.cellListo() then return false end
    if not (Cell and Cell.ImportProfile and NS.CELL_MERFIN) then return false end
    local tenia = CellCharacterDB and type(CellCharacterDB.clickCastings) == "table"
    local ok, hecho = pcall(Cell.ImportProfile, NS.CELL_MERFIN, "Modos", { clickCastings = tenia or nil })
    return ok and hecho and R.cellListo() and true or false
end

function R.ajustarCell()
    if not R.cellListo() then return false end
    if CellDB.modos == R.CELL_VERSION then return false end
    for nombre, t in pairs(R.CELL_DISENOS) do
        local l = CellDB.layouts[nombre]
        if l and l.main then
            for k, v in pairs(t) do
                if type(v) == "table" then
                    l.main[k] = {}
                    for i, x in ipairs(v) do l.main[k][i] = x end
                else
                    l.main[k] = v
                end
            end
        end
    end
    temaClase()
    CellDB.modos = R.CELL_VERSION
    return true
end

-- (1.0.10) lo pidió el 17/10: la vida en número en cada marco de Cell (aunque
-- después la tapen buffs o debuffs) y la barra de maná. Merfin trae la vida
-- apagada y la barra en 0. Sin agrandar los marcos: el nombre sube 6 y la vida
-- va debajo ("26.5k"), la barra de 4 abajo. En todos los diseños, una vez.
R.CELL_VIDA_VERSION = 1
R.CELL_MANA = 4
function R.vidaCell()
    if not R.cellListo() then return false end
    if CellDB.modosVida == R.CELL_VIDA_VERSION then return false end
    for _, l in pairs(CellDB.layouts) do
        if type(l) == "table" and type(l.main) == "table" then
            l.main.powerSize = R.CELL_MANA
            for _, k in ipairs({ "pet", "npc" }) do
                if type(l[k]) == "table" then l[k].powerSize = R.CELL_MANA end
            end
            for _, ind in ipairs(type(l.indicators) == "table" and l.indicators or {}) do
                if ind.indicatorName == "healthText" then
                    ind.enabled = true
                    ind.position = { "TOP", "button", "CENTER", 0, -1 }
                    ind.format = type(ind.format) == "table" and ind.format or {}
                    ind.format.health1 = type(ind.format.health1) == "table" and ind.format.health1 or {}
                    ind.format.health1.format = "health_short"
                    ind.format.health1.hideIfEmptyOrFull = false
                    if not ind.format.health1.color then ind.format.health1.color = { "custom_color", { 1, 1, 1 } } end
                elseif ind.indicatorName == "nameText" then
                    ind.position = { "CENTER", "healthBar", "CENTER", 0, 6 }
                end
            end
        end
    end
    CellDB.modosVida = R.CELL_VIDA_VERSION
    return true
end
-- (1.0.15) lo de adentro de cada marco, en filas, sin que nada se pise (lo pidió:
-- "lo más importante es que no se overlapee nada, y que lo importante de cada clase
-- se vea claro"):
--   arriba: rol, el aura suelta de tu clase (Weakened Soul, Soulstone...), la marca
--           de banda y a la derecha tus HoTs/escudos (hasta 4, de derecha a izquierda)
--   medio:  el debuff de banda a la izquierda, el nombre al medio (se corta si no
--           entra) y el hechizo que te apunta a la derecha
--   abajo:  tus buffs chicos a la izquierda (Earthliving, Divine Aegis...), la vida
--           en número al medio y los CDs de afuera/defensivos a la derecha
--   y la barra de maná. Lo que se saca: lo dice el color del marco (dispels), el
--   borde (agro, en vez de la barrita de arriba que se metía en el marco de arriba).
-- icA: íconos de arriba, icB: los del medio, icC: los de abajo, fn: letra del nombre,
-- fv: letra de la vida
R.CELL_ESTILO_VERSION = 1
R.CELL_MEDIDAS = {
    ["Healer: Raid10-25 || Full HD"] = { icA = 11, icB = 13, icC = 10, fn = 11, fv = 9 },
    ["DPS/Tank: Raid10-25 || Full HD"] = { icA = 11, icB = 13, icC = 10, fn = 11, fv = 9 },
    ["Healer: Party || Full HD"] = { icA = 12, icB = 13, icC = 10, fn = 12, fv = 10 },
    ["DPS/Tank: Party || Full HD"] = { icA = 12, icB = 13, icC = 10, fn = 12, fv = 10 },
    ["Healer: Raid40 || Full HD"] = { icA = 9, icB = 11, icC = 9, fn = 10, fv = 8 },
    ["DPS/Tank: Raid40 || Full HD"] = { icA = 9, icB = 11, icC = 9, fn = 10, fv = 8 },
}
-- las cajas de cada cosa dentro del marco (x e y desde arriba a la izquierda), para
-- la prueba y para poner las posiciones de Cell
function R.cajasCell(nombre)
    local d, m = R.CELL_DISENOS[nombre], R.CELL_MEDIDAS[nombre]
    if not (d and m) then return nil end
    local w, h, p = d.size[1], d.size[2], d.powerSize or 0
    local A, B, C = m.icA, m.icB, m.icC
    local finA = 1 + A                             -- fila de arriba: de 1 a 1 + icA
    local altoB = h - p - 1 - C - finA - 1         -- lo que queda para el nombre
    local yB = h / 2 - (finA + 1 + altoB / 2)      -- el medio de esa fila, desde el medio del marco
    local c = {
        rol = { 1, 1, A - 1, A - 1 }, suelta = { A + 1, 1, A, A }, marca = { 2 * A + 2, 1, A, A },
        hots = { w - 1 - 4 * (A - 1), 1, 4 * (A - 1), A - 1 },
        banda = { 1, h / 2 - yB - B / 2, B, B }, apunta = { w - 1 - B, h / 2 - yB - B / 2, B, B },
        nombre = { 2 + B + 2, h / 2 - yB - m.fn / 2, w - 2 * (B + 4), m.fn },
        chicos = { 1, h - p - 1 - C, 2 * C, C }, vida = { w / 2 - 2 * m.fv, h - p - 1 - m.fv, 4 * m.fv, m.fv },
        cds = { w - 1 - 2 * C, h - p - 1 - C, 2 * C, C }, mana = { 0, h - p, w, p },
    }
    return c, { w = w, h = h, p = p, yB = yB, ancho = (w - 2 * (B + 4)) / (w - 2) }
end

local function fuente(t, tam)
    t.font = type(t.font) == "table" and t.font or {}
    t.font[1], t.font[2], t.font[3], t.font[4] = t.font[1] or "Cell Default", tam, "Outline", false
end
function R.estiloCell()
    if not R.cellListo() then return false end
    if CellDB.modosEstilo == R.CELL_ESTILO_VERSION then return false end
    for nombre, m in pairs(R.CELL_MEDIDAS) do
        local l = CellDB.layouts[nombre]
        local _, med = R.cajasCell(nombre)
        if type(l) == "table" and type(l.indicators) == "table" and med then
            local p, yB, A, B, C = med.p, med.yB, m.icA, m.icB, m.icC
            local por = {}
            for _, ind in ipairs(l.indicators) do
                if type(ind) == "table" and ind.indicatorName then por[ind.indicatorName] = ind end
            end
            local function poner(n, t)
                local ind = por[n]
                if not ind then return end
                for k, v in pairs(t) do ind[k] = v end
            end
            poner("roleIcon", { enabled = true, position = { "TOPLEFT", "button", "TOPLEFT", 1, -1 }, size = { A - 1, A - 1 } })
            for i = 3, 6 do
                poner("indicator" .. i, { position = { "TOPLEFT", "button", "TOPLEFT", A + 1, -1 }, size = { A, A } })
            end
            poner("playerRaidIcon", { enabled = true, position = { "TOPLEFT", "button", "TOPLEFT", 2 * A + 2, -1 }, size = { A, A } })
            poner("indicator1", { position = { "TOPRIGHT", "button", "TOPRIGHT", -1, -1 }, size = { A - 1, A - 1 }, num = 4,
                                  orientation = "right-to-left" })
            poner("raidDebuffs", { enabled = true, position = { "LEFT", "button", "LEFT", 1, yB }, size = { B, B }, num = 1,
                                   orientation = "left-to-right" })
            poner("targetedSpells", { enabled = true, position = { "RIGHT", "button", "RIGHT", -1, yB }, size = { B, B }, num = 1 })
            poner("nameText", { enabled = true, position = { "CENTER", "button", "CENTER", 0, yB },
                                textWidth = { "percentage", med.ancho } })
            if por.nameText then fuente(por.nameText, m.fn) end
            poner("healthText", { enabled = true, position = { "BOTTOM", "button", "BOTTOM", 0, p + 1 } })
            if por.healthText then fuente(por.healthText, m.fv) end
            poner("statusText", { position = { "BOTTOM", p + 1, "justify" } })
            poner("indicator2", { position = { "BOTTOMLEFT", "button", "BOTTOMLEFT", 1, p + 1 }, size = { C, C }, num = 2,
                                  orientation = "left-to-right" })
            poner("allCooldowns", { enabled = true, position = { "BOTTOMRIGHT", "button", "BOTTOMRIGHT", -1, p + 1 }, size = { C, C },
                                    num = 2, orientation = "right-to-left" })
            -- lo que aparece solo un momento (muerto, resurrección, listo): en el medio
            poner("statusIcon", { position = { "CENTER", "button", "CENTER", 0, yB }, size = { B + 2, B + 2 } })
            poner("readyCheckIcon", { position = { "CENTER", "button", "CENTER", 0, yB }, size = { B + 2, B + 2 } })
            poner("dispels", { enabled = true, iconStyle = "none" })
            -- afuera: lo que se pisaba con otros íconos o se salía del marco
            for _, n in ipairs({ "leaderIcon", "aggroBar", "aggroBlink", "targetRaidIcon", "combatIcon", "targetCounter",
                                 "externalCooldowns", "defensiveCooldowns", "debuffs", "missingBuffs", "powerWordShield",
                                 "powerText" }) do
                poner(n, { enabled = false })
            end
            poner("aggroBorder", { enabled = true })
            if type(l.main) == "table" then l.main.powerSize = p end
        end
    end
    CellDB.modosEstilo = R.CELL_ESTILO_VERSION
    return true
end

function R.ponerCellTooltip()
    if not (CellDB and CellDB.general) then return false end
    local t = R.CELL_TOOLTIP[R.actual() or "DPS"]
    CellDB.general.tooltipsPosition = { t[1], t[2], t[3], t[4], t[5] }
    return true
end

-- qué diseño usa Cell en cada situación, según el rol de cada talento
function R.ponerCellRoles()
    if not (R.cellListo() and CellCharacterDB) then return false end
    CellCharacterDB.layoutAutoSwitch = CellCharacterDB.layoutAutoSwitch or {}
    local cambio = false
    for g = 1, 2 do
        local rol = R.de(g) or R.actual() or "DPS"
        local L = R.CELL[rol]
        local t = { party = L.party, arena = L.party, raid10 = L.raid, raid25 = L.raid, battleground15 = L.raid,
                    raid_outdoor = L.raid40, battleground40 = L.raid40, solo = "hide" }
        local viejo = CellCharacterDB.layoutAutoSwitch[g]
        local igual = type(viejo) == "table"
        if igual then for k, v in pairs(t) do if viejo[k] ~= v then igual = false end end end
        if not igual then CellCharacterDB.layoutAutoSwitch[g] = t; cambio = true end
    end
    if cambio and Cell and Cell.funcs and Cell.funcs.UpdateLayout and Cell.vars and Cell.vars.layoutGroupType then
        pcall(Cell.funcs.UpdateLayout, Cell.vars.layoutGroupType)
    end
    return cambio
end

local function recargar(motivo)
    NS.decir(motivo .. " Hay que recargar la interfaz.")
    if not (StaticPopupDialogs and StaticPopup_Show) then return end
    StaticPopupDialogs["MODOS_RECARGAR_ROL"] = StaticPopupDialogs["MODOS_RECARGAR_ROL"] or {
        text = "Modos: hay que recargar la interfaz para terminar de armar Cell.",
        button1 = "Recargar",
        OnAccept = function() ReloadUI() end,
        timeout = 0, whileDead = 1, hideOnEscape = false, showAlert = 1,
    }
    NS.pedirRecarga("MODOS_RECARGAR_ROL")
end

-- ------------------------------------------------------------ aplicar
function R.avisarAuras()
    if WeakAuras and WeakAuras.ScanEvents then pcall(WeakAuras.ScanEvents, "MODOS_MISCDS") end
end

-- pone todo según el rol del talento en uso. Devuelve true si hizo falta recargar.
function R.aplicar()
    if not (enPvE() and R.actual()) then return false end
    R.ponerElvUI()
    local importo = R.importarCell()
    local ajusto = R.ajustarCell()
    local vida = R.vidaCell()
    local estilo = R.estiloCell()
    R.ponerCellRoles()
    R.ponerCellTooltip()
    R.avisarAuras()
    if importo or ajusto or vida or estilo then
        recargar(importo and "Importé el Cell de Merfin y lo acomodé para tu rol."
                 or ajusto and "Acomodé los diseños de Cell."
                 or vida and "Puse la vida y la barra de maná en los marcos de Cell."
                 or "Acomodé lo de adentro de los marcos de Cell.")
        return true
    end
    return false
end

-- elegir el rol del talento en uso (o de otro)
function R.poner(rol, g)
    local t = tabla()
    if not t then return end
    if rol and not R.puede(rol) then
        NS.decir(("Rol en PvE: %s no puede ser %s."):format(quien(), rol))
        return
    end
    g = g or R.grupo()
    t[g] = rol
    if rol then
        NS.decir(("Rol en PvE del talento %d: %s."):format(g, rol))
        if enPvE() then
            if InCombatLockdown and InCombatLockdown() then
                R.pendiente = true
                NS.decir("En combate no: se acomoda al salir de combate.")
            else
                R.aplicar()
            end
        end
    else
        NS.decir(("Rol en PvE del talento %d: sin elegir."):format(g))
    end
    if R.ventana then R.ventana:Hide() end
    if NS.alCambiar then NS.alCambiar() end
end

-- el siguiente rol (botón de la ventana): Tank, DPS, Heal y de nuevo
function R.siguiente()
    local a = R.actual()
    local l = R.posibles()
    local i = 0
    for k, v in ipairs(l) do if v == a then i = k end end
    R.poner(l[i % #l + 1])
end

-- ------------------------------------------------------------ la pregunta
function R.preguntar()
    if not E then return end
    -- (1.0.13) con un solo rol posible no hay nada que preguntar
    local l = R.posibles()
    if #l == 1 then R.poner(l[1]); return end
    if not R.ventana then
        local f = CreateFrame("Frame", "ModosRol", UIParent)
        f:SetWidth(340); f:SetHeight(116)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
        E.ventana(f)
        f:SetFrameStrata("DIALOG")
        f:SetToplevel(true)
        f:EnableMouse(true)
        local t = E.texto(f, "titulo")
        t:SetPoint("TOPLEFT", 14, -12)
        t:SetText("Modos · rol en PvE")
        f.texto = E.texto(f, "chico")
        f.texto:SetPoint("TOPLEFT", 14, -36)
        f.texto:SetWidth(312)
        f.botones = {}
        for i, rol in ipairs(R.ROLES) do
            local b = E.boton(f, rol, 96, 24)
            b:SetPoint("BOTTOMLEFT", 14 + (i - 1) * 106, 14)
            b:SetScript("OnClick", function() R.poner(rol) end)
            f.botones[rol] = b
        end
        R.ventana = f
    end
    -- (1.0.13) solo los botones de los roles que puede hacer la clase
    local n = 0
    for _, rol in ipairs(R.ROLES) do
        local b = R.ventana.botones[rol]
        if R.puede(rol) then
            b:ClearAllPoints()
            b:SetPoint("BOTTOMLEFT", 14 + n * 106, 14)
            b:Show()
            n = n + 1
        else
            b:Hide()
        end
    end
    R.ventana.texto:SetText(("¿Qué hacés con este talento (%d)? Acomoda tu marco, el objetivo, Cell y Mis CDs. Se cambia con /modos rol."):format(R.grupo()))
    R.ventana:Show()
end

-- ------------------------------------------------------------ globales para las auras
function ModosModoActivo()
    return NS.pj and NS.pj.activo
end

function ModosMisCDsY()
    local pr = NS.presets
    local y = pr and pr.MISCDS_Y
    return y and y[R.actual() or "DPS"] or -375
end

-- ------------------------------------------------------------ eventos
local espera, fn = 0, nil
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
local function revisar()
    if not enPvE() then return end
    if InCombatLockdown and InCombatLockdown() then R.pendiente = true; return end
    if not R.actual() then
        -- con el asistente de primeros pasos pendiente, el rol se elige ahí
        if NS.instalar and NS.instalar.pendiente() then return end
        R.preguntar()
    else
        R.aplicar()
    end
end
ev:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if R.pendiente then R.pendiente = nil; revisar() end
        return
    end
    -- un momento después: que termine de cargar ElvUI y Cell (y el talento)
    espera, fn = event == "PLAYER_ENTERING_WORLD" and 3 or 1.5, revisar
    self:SetScript("OnUpdate", function(s, dt)
        espera = espera - dt
        if espera > 0 then return end
        s:SetScript("OnUpdate", nil)
        if fn then local f = fn; fn = nil; f() end
    end)
end)
R.revisar = revisar
