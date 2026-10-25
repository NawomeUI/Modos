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
R.CELL_VERSION = 9
R.CELL = {
    Heal = { party = "Healer: Party || Full HD", raid = "Healer: Raid10-25 || Full HD", raid40 = "Healer: Raid40 || Full HD" },
    DPS = { party = "DPS/Tank: Party || Full HD", raid = "DPS/Tank: Raid10-25 || Full HD", raid40 = "DPS/Tank: Raid40 || Full HD" },
}
R.CELL.Tank = R.CELL.DPS
-- Un grupo por columna (12/10), de a 5 (una grilla de 5 x 5 en 25). En heal, desde la
-- 1.0.19, un grupo por fila (ver abajo).
-- El ancla de Cell es un cuadradito de 20 x 10: con anchor TOPLEFT los marcos
-- empiezan 4 debajo de su borde de abajo y su BOTTOM queda 10 a la derecha del
-- borde izquierdo de los marcos. Con BOTTOMLEFT empiezan 4 arriba de su borde de arriba.
-- (1.0.15) al estilo de la captura de banda que mandó (21:41 del 18/10).
-- (1.0.16) más grandes (le seguían quedando chicos) y sin hueco entre marcos (el borde
-- de 1 de cada uno hace la línea oscura de 2, como en la captura; antes se veía el
-- fondo del juego entre marcos):
--   Heal: abajo al medio, de 352 (justo debajo del casteo de la WA de heal, 357) a 122
--   (arriba de las posturas y la mascota a la vista, que llegan a 116). Empieza en -255:
--   a la izquierda, debajo de tu marco, van los CDs chicos de la WA de heal (de -469 a
--   -265). Crece a la derecha hasta antes de Details (503 a 1920 de ancho).
-- (1.0.17) MÁS GRANDES. Lo que se veía chico en Dalaran (24/10) era el diseño de 40:
--   Cell lo usaba con cualquier banda fuera de una instancia (raid_outdoor), y yo lo
--   había hecho angosto. Ahora fuera de instancia va el de banda, y el de 40 queda solo
--   para los campos de batalla de 40.
--   Heal: banda 128x46 (5 columnas, de -255 a 385), grupo 160x46, 40 en 92x46 (hasta 481).
--   DPS/Tank: a la izquierda desde 349: banda 130x56, grupo 160x56, 40 en 100x46.
-- (1.0.18) banda de heal 150x46 (de -255 a 495, antes de Details) y de DPS 150x56,
--   para que el nombre entre con los íconos grandes al costado.
-- (1.0.19) heal como las UIs de heal que mandó (24/10) y como venía el Cell de heal de
--   Merfin (100x50, un grupo por fila): la grilla centrada justo debajo del casteo de la
--   WA de heal, cada grupo una fila de 5 (en grupo, 5 en fila; en 10, dos filas; en 25,
--   la grilla de 5 x 5) y los marcos más altos, con lo de adentro en tres filas.
--   De -257 a 258 (a la izquierda, debajo de tu marco, siguen los CDs chicos de la WA de
--   heal, hasta -265, y las auras de pala de Blizzard a la vista, hasta -257,2) y de 352 a
--   87: abajo quedan las barras a la vista (hasta 82) o Mis CDs (que en heal bajan al
--   borde de la pantalla). La mascota a la vista se corre a la derecha del Cell
--   (R.ponerMascota).
--   Banda 103x53, grupo 103x60, 40 (campos de batalla de 40) 103x33 en 8 filas.
R.CELL_DISENOS = {
    ["Healer: Raid10-25 || Full HD"] = { orientation = "horizontal", size = { 103, 53 }, anchor = "TOPLEFT",
        position = { "BOTTOM", -247, 356 }, spacingX = 0, spacingY = 0, unitsPerColumn = 5, maxColumns = 8, powerSize = 4 },
    ["Healer: Party || Full HD"] = { orientation = "horizontal", size = { 103, 60 }, anchor = "TOPLEFT",
        position = { "BOTTOM", -247, 356 }, spacingX = 0, spacingY = 0, unitsPerColumn = 5, maxColumns = 8, powerSize = 4 },
    ["Healer: Raid40 || Full HD"] = { orientation = "horizontal", size = { 103, 33 }, anchor = "TOPLEFT",
        position = { "BOTTOM", -247, 356 }, spacingX = 0, spacingY = 0, unitsPerColumn = 5, maxColumns = 8, powerSize = 3 },
    -- (1.0.39) DPS/Tank más chicos (25/10, en una banda de 10 desparramada en 5 grupos:
    -- "está bien que te dije que los quería grandes, pero ¿no están enormes?"): banda de
    -- 150x56 a 120x46 y grupo de 160x56 a 130x48, y en banda todos juntos de a 5 por
    -- columna (combineGroups), sin una columna por grupo: en 10, dos columnas.
    ["DPS/Tank: Party || Full HD"] = { orientation = "vertical", size = { 130, 48 }, anchor = "BOTTOMLEFT",
        position = { "BOTTOMLEFT", 4, 335 }, spacingX = 0, spacingY = 0, unitsPerColumn = 5, maxColumns = 8, powerSize = 4 },
    ["DPS/Tank: Raid10-25 || Full HD"] = { orientation = "vertical", size = { 120, 46 }, anchor = "BOTTOMLEFT",
        position = { "BOTTOMLEFT", 4, 335 }, spacingX = 0, spacingY = 0, unitsPerColumn = 5, maxColumns = 8, powerSize = 4,
        combineGroups = true },
    ["DPS/Tank: Raid40 || Full HD"] = { orientation = "vertical", size = { 100, 46 }, anchor = "BOTTOMLEFT",
        position = { "BOTTOMLEFT", 4, 335 }, spacingX = 0, spacingY = 0, unitsPerColumn = 5, maxColumns = 8, powerSize = 4 },
}
-- cuántos marcos de ancho y de alto tiene la grilla entera con g grupos
function R.grillaCell(nombre, g)
    local d = R.CELL_DISENOS[nombre]
    if not d then return nil end
    local cols, filas = g, 5
    if d.orientation == "horizontal" then cols, filas = 5, g end
    return cols * d.size[1] + (cols - 1) * (d.spacingX or 0), filas * d.size[2] + (filas - 1) * (d.spacingY or 0)
end
-- dónde sale el cartelito al pasar el mouse por Cell, para que no lo tape: en heal
-- a la derecha de la grilla (a la izquierda están los CDs chicos de la WA de heal),
-- en DPS/Tank arriba (las columnas crecen a la derecha y cambian con el tamaño del
-- grupo: arriba no tapa ninguna). Se ancla al primer marco (arriba a la izquierda).
R.CELL_TOOLTIP = {
    Heal = { "TOPLEFT", "Cell", "TOPLEFT", 5 * 103 + 6, 0 },
    DPS = { "BOTTOMLEFT", "Cell", "BOTTOMLEFT", 0, 5 * 48 + 6 },
}
R.CELL_TOOLTIP.Tank = R.CELL_TOOLTIP.DPS

-- colores de clase (el "Class Theme" de Merfin): barra del color de la clase, lo
-- perdido oscuro y el nombre en blanco.
-- (1.0.16) sólidos (se veía el pasto a través: fondo y lo perdido iban medio
-- transparentes), los que están lejos al 65% (Cell trae 45%: en un campo de batalla
-- casi todos quedaban lavados) y los muertos en rojo oscuro (sin el texto GHOST/DEAD)
R.CELL_LEJOS = 0.65
local function temaClase()
    CellDB.appearance = CellDB.appearance or {}
    local ap = CellDB.appearance
    ap.barAlpha, ap.bgAlpha, ap.lossAlpha = 1, 1, 1
    ap.outOfRangeAlpha = R.CELL_LEJOS
    ap.barColor = { "class_color", { 0.82, 0.68, 0.68 } }
    ap.lossColor = { "custom", { 0.12, 0.1, 0.1 } }
    ap.deathColor = { true, { 0.4, 0.08, 0.08 } }
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
-- (1.0.15) lo de adentro de cada marco, sin que nada se pise (lo pidió: "lo más
-- importante es que no se overlapee nada, y que lo importante de cada clase se vea
-- claro"). (1.0.16) rehecho después de verlo en un campo de batalla.
-- (1.0.18) íconos grandes ("siguen siendo diminutos"): dos filas en vez de tres, con
-- los íconos a los costados del texto en vez de arriba y abajo, así entran del alto
-- de media fila (18 en heal, 22 en DPS, antes 12):
--   arriba: rol y marca de banda chicos, el nombre en blanco y a la derecha tus HoTs,
--           escudos y efectos (3, o 2 donde no entran más)
--   abajo:  el debuff de banda, el ícono del debuff que podés sacar y el aura suelta de
--           tu clase (Weakened Soul, Soulstone...) a la izquierda, la vida en número y
--           los CDs de afuera/defensivos a la derecha
--   y la barra de maná. Agro: el borde. Muerto: el marco en rojo oscuro.
-- (1.0.19) heal en tres filas (los marcos de heal ahora son más altos y angostos):
--   arriba: rol, marca y el aura suelta de tu clase a la izquierda, tus HoTs a la derecha
--   medio:  el nombre, de lado a lado
--   abajo:  el debuff de banda y el que podés sacar a la izquierda, la vida en número y
--           los CDs de afuera/defensivos a la derecha
--   El de 40 de heal (marcos bajos, 8 filas) sigue en dos filas.
-- filas: 2 o 3, ic: íconos, rol: el rol y la marca, fn: letra del nombre, fv: letra de
-- la vida, hots: cuántos, cds: cuántos CDs de afuera (2), sinCds: sin CDs de afuera (la
-- vida va a la derecha), sinMarca
R.CELL_ESTILO_VERSION = 6
R.CELL_MEDIDAS = {
    ["Healer: Raid10-25 || Full HD"] = { filas = 3, ic = 16, rol = 12, fn = 13, fv = 11, hots = 3, cds = 2 },
    ["Healer: Party || Full HD"] = { filas = 3, ic = 18, rol = 13, fn = 14, fv = 12, hots = 3, cds = 1 },
    ["Healer: Raid40 || Full HD"] = { ic = 14, rol = 11, fn = 11, fv = 10, hots = 2, sinCds = true, sinMarca = true },
    -- (1.0.39) más chicos: íconos de 18 y 20, un solo HoT/escudo (en DPS casi no hay)
    -- para que el nombre tenga lugar
    ["DPS/Tank: Raid10-25 || Full HD"] = { ic = 18, rol = 13, fn = 13, fv = 11, hots = 1 },
    ["DPS/Tank: Party || Full HD"] = { ic = 20, rol = 14, fn = 14, fv = 12, hots = 1 },
    ["DPS/Tank: Raid40 || Full HD"] = { ic = 16, rol = 12, fn = 12, fv = 10, hots = 2, sinCds = true, sinMarca = true },
}
-- las cajas de cada cosa dentro del marco (x, y desde arriba a la izquierda, ancho y
-- alto), para la prueba y para poner las posiciones de Cell
function R.cajasCell(nombre)
    local d, m = R.CELL_DISENOS[nombre], R.CELL_MEDIDAS[nombre]
    if not (d and m) then return nil end
    local w, h, p = d.size[1], d.size[2], d.powerSize or 0
    local I, r = m.ic, m.rol
    local nc = m.sinCds and 0 or (m.cds or 2)
    local y2 = h - p - 1 - I                          -- la fila de abajo, pegada a la barra de maná
    local yr = 1 + (I - r) / 2                        -- rol y marca, al medio de la fila de arriba
    local c = {
        rol = { 1, yr, r, r }, hots = { w - 1 - m.hots * I, 1, m.hots * I, I },
        banda = { 1, y2, I, I }, dispel = { I + 2, y2, I, I },
        mana = { 0, h - p, w, p },
    }
    if not m.sinMarca then c.marca = { r + 2, yr, r, r } end
    if nc > 0 then c.cds = { w - 1 - nc * I, y2, nc * I, I } end
    local xV1 = (nc > 0) and (w - 2 - nc * I) or (w - 1)
    local xV0
    if m.filas == 3 then
        local xS = m.sinMarca and (r + 2) or (2 * r + 3)
        c.suelta = { xS, 1, I, I }
        local y1 = 1 + I                              -- el nombre entre la fila de arriba y la de abajo
        c.nombre = { 2, y1 + (y2 - y1 - m.fn) / 2, w - 4, m.fn }
        xV0 = 2 * I + 3                               -- la vida: después de banda y dispel
    else
        c.suelta = { 2 * I + 3, y2, I, I }
        local xN0 = m.sinMarca and (r + 3) or (2 * r + 4) -- el nombre empieza después del rol (y la marca)
        local xN1 = w - 2 - m.hots * I                    -- y termina antes de los HoTs
        c.nombre = { xN0, 1 + (I - m.fn) / 2, xN1 - xN0, m.fn }
        xV0 = 3 + 3 * I                               -- la vida: después de banda, dispel y aura suelta
    end
    c.vida = { xV0, y2 + (I - m.fv) / 2, xV1 - xV0, m.fv }
    return c, { w = w, h = h, p = p, I = I, r = r, nc = nc, yr = yr, y2 = y2,
                xN0 = c.nombre[1], xN1 = c.nombre[1] + c.nombre[3], xV0 = xV0, xV1 = xV1 }
end

local function fuente(t, tam)
    t.font = type(t.font) == "table" and t.font or {}
    t.font[1], t.font[2], t.font[3], t.font[4] = t.font[1] or "Cell Default", tam, "Outline", false
end
-- dónde va cada cosa en Cell, sacado de su caja: lo de la izquierda por su esquina de
-- arriba a la izquierda, lo que crece hacia la izquierda (HoTs y CDs) por la de arriba
-- a la derecha, y los textos por su centro
local function izq(b) return { "TOPLEFT", "button", "TOPLEFT", b[1], -b[2] } end
local function der(b, w) return { "TOPRIGHT", "button", "TOPRIGHT", b[1] + b[3] - w, -b[2] } end
local function centro(b) return { "CENTER", "button", "TOPLEFT", b[1] + b[3] / 2, -(b[2] + b[4] / 2) } end
R.posCell = { izq = izq, der = der, centro = centro }
function R.estiloCell()
    if not R.cellListo() then return false end
    if CellDB.modosEstilo == R.CELL_ESTILO_VERSION then return false end
    for nombre, m in pairs(R.CELL_MEDIDAS) do
        local l = CellDB.layouts[nombre]
        local c, k = R.cajasCell(nombre)
        if type(l) == "table" and type(l.indicators) == "table" and k then
            local p, I, r, w = k.p, k.I, k.r, k.w
            local por = {}
            for _, ind in ipairs(l.indicators) do
                if type(ind) == "table" and ind.indicatorName then por[ind.indicatorName] = ind end
            end
            local function poner(n, t)
                local ind = por[n]
                if not ind then return end
                for kk, v in pairs(t) do ind[kk] = v end
            end
            poner("roleIcon", { enabled = true, position = izq(c.rol), size = { r, r } })
            poner("playerRaidIcon", { enabled = c.marca and true or false, position = izq(c.marca or c.rol), size = { r, r } })
            local i1, i2 = por.indicator1, por.indicator2
            if i1 and type(i1.auras) == "table" and i2 and type(i2.auras) == "table" then
                local ya = {}
                for _, id in ipairs(i1.auras) do ya[id] = true end
                for _, id in ipairs(i2.auras) do if not ya[id] then i1.auras[#i1.auras + 1] = id; ya[id] = true end end
            end
            poner("indicator1", { position = der(c.hots, w), size = { I, I }, num = m.hots, orientation = "right-to-left" })
            poner("indicator2", { enabled = false })
            poner("nameText", { enabled = true, position = centro(c.nombre),
                                textWidth = { "percentage", c.nombre[3] / (w - 2) } })
            if por.nameText then fuente(por.nameText, m.fn) end
            poner("raidDebuffs", { enabled = true, position = izq(c.banda), size = { I, I }, num = 1, orientation = "left-to-right" })
            poner("dispels", { enabled = true, highlightType = "none", iconStyle = "blizzard",
                               position = izq(c.dispel), size = { I, I }, orientation = "left-to-right" })
            -- el aura suelta de tu clase (Weakened Soul, Soulstone...)
            for i = 3, 6 do poner("indicator" .. i, { position = izq(c.suelta), size = { I, I } }) end
            poner("healthText", { enabled = true, position = centro(c.vida) })
            if por.healthText then fuente(por.healthText, m.fv) end
            poner("allCooldowns", { enabled = c.cds and true or false, position = der(c.cds or c.hots, w),
                                    size = { I, I }, num = k.nc > 0 and k.nc or 1, orientation = "right-to-left" })
            -- lo que aparece solo un momento (resurrección, listo): al medio
            poner("statusIcon", { position = { "CENTER", "button", "CENTER", 0, 0 }, size = { I, I } })
            poner("readyCheckIcon", { position = { "CENTER", "button", "CENTER", 0, 0 }, size = { I, I } })
            -- afuera: lo que se pisaba con otros íconos o se salía del marco
            for _, n in ipairs({ "leaderIcon", "aggroBar", "aggroBlink", "targetRaidIcon", "combatIcon", "targetCounter",
                                 "externalCooldowns", "defensiveCooldowns", "debuffs", "missingBuffs", "powerWordShield",
                                 "powerText", "targetedSpells", "statusText" }) do
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
                    raid_outdoor = L.raid, battleground40 = L.raid40, solo = "hide" }
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

-- ------------------------------------------------------------ la barra de la mascota
-- (1.0.19) a la vista iba arriba de la barra 5 (de 198 a 452, de 89 a 113), donde ahora
-- llega el Cell de heal: en heal va donde con las barras escondidas, a la derecha del
-- Cell y más chica (de 265 a 488). En DPS y Tank queda donde estaba.
function R.mascotaBT(rol, vista)
    local pv = NS.presets and NS.presets.PvE
    if not pv then return nil end
    local v = (vista == "visibles" and rol ~= "Heal") and (pv.Bartender4Visible or pv.Bartender4) or pv.Bartender4
    return v.PetBar and v.PetBar.position
end
local function mismoLugar(a, b)
    if not (type(a) == "table" and type(b) == "table") then return false end
    local function cerca(x, y) return tonumber(x) and tonumber(y) and math.abs(x - y) < 0.5 end
    return a.point == b.point and cerca(a.x, b.x) and cerca(a.y, b.y) and cerca(a.scale or 1, b.scale or 1)
end
-- con Bartender4 y las barras a la vista, en el momento (fuera de combate). Si la
-- moviste vos a otro lado no se toca.
function R.ponerMascota()
    local B = NS.barras
    if not (B and B.estilo and B.estilo() == "bartender" and B.visibles()) then return false end
    if not (Bartender4 and Bartender4.GetModule) then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    local ok, mod = pcall(Bartender4.GetModule, Bartender4, "PetBar", true)
    local pos = ok and mod and mod.db and mod.db.profile and mod.db.profile.position
    local quiero = R.mascotaBT(R.actual(), "visibles")
    if not (type(pos) == "table" and quiero) or mismoLugar(pos, quiero) then return false end
    if not (mismoLugar(pos, R.mascotaBT("DPS", "visibles")) or mismoLugar(pos, R.mascotaBT("Heal", "visibles"))) then
        return false
    end
    pos.point, pos.x, pos.y, pos.scale = quiero.point, quiero.x, quiero.y, quiero.scale
    if mod.ApplyConfig then pcall(mod.ApplyConfig, mod) end
    return true
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
    R.ponerMascota()
    if NS.barras and NS.barras.apartar then NS.barras.apartar() end
    -- (1.0.36) los casteos de Quartz debajo del objetivo y del foco (los movers cambian con el rol)
    if NS.casteos and NS.despues then NS.despues(1, "casteosRol", NS.casteos.acomodar) end
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
