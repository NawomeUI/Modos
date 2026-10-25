-- Modos · Instalar (0.9.5, 1.0): el asistente de primeros pasos.
-- Aparece solo la primera vez en cada personaje (y con /modos instalar). En una
-- sola ventana, de arriba a abajo:
--   1. Addons: avisa si falta alguno de los que usa Modos.
--   2. Modo: en qué modo estás ahora (PvE o PvP).
--   3. Barras: con o sin Bartender, a la vista o escondidas (Barras.lua).
--   4. Rol en PvE: tank, DPS o heal del talento en uso (Rol.lua).
--   5. WeakAuras: (1.0) se instalan solas al entrar con cada personaje, también
--      la de su clase (Auras.lua). Acá se ve si están. Los botones las vuelven a
--      importar con la ventana de WeakAuras (por si borraste alguna o para
--      actualizarlas): una ventana por paquete, tocás "Importar" en cada una.
-- Mientras el asistente está pendiente, las preguntas sueltas de barras y rol
-- no aparecen: se contestan desde acá.

local _, NS = ...
local E = NS.E
local C = E and E.C

local I = {}
NS.instalar = I
I.VERSION = 1

-- los addons que usa Modos. opcional: anda sin él (se avisa en gris)
I.ADDONS = {
    { "ElvUI", "los dos modos" }, { "ElvUI_OptionsUI", "los dos modos" },
    { "WeakAuras", "los dos modos" }, { "WeakAurasOptions", "los dos modos" },
    { "OmniCC", "los dos modos" }, { "MerfinPlus", "PvE" },
    { "Cell", "PvE" }, { "DBM-Core", "PvE" },
    { "Gladius", "PvP" }, { "EasyFrames", "PvP" }, { "Quartz", "PvP" },
    { "CompactRaidFrame", "PvP" }, { "!!!ClassicAPI", "PvP" }, { "EnhancedRaidFrames", "PvP" },
    { "Bagnon", "los dos modos", true }, { "Details", "los dos modos", true },
    { "MinimapButtonFrame", "los dos modos", true }, { "MRT", "PvE", true }, { "xCT+", "PvE", true },
    { "SoundAlerter", "PvP", true }, { "TabPvP", "PvP", true },
    { "Talented", "los dos modos", true }, { "ActionBarSaver", "los dos modos", true },
    { "GearScoreLite", "los dos modos", true }, { "CombatLogFix", "los dos modos", true },
    { "PallyPower", "PvE, paladines", true },
    { "AtlasLoot", "los dos modos", true },        -- (1.0.25) lo sumó él (25/10)
}

local function instalado(n)
    if not GetAddOnInfo then return true end
    local nombre, _, _, _, _, motivo = GetAddOnInfo(n)
    return nombre ~= nil and motivo ~= "MISSING"
end

-- { faltan = {...}, opcionales = {...} }
function I.faltan()
    local r = { faltan = {}, opcionales = {} }
    for _, a in ipairs(I.ADDONS) do
        if not instalado(a[1]) then
            local l = a[3] and r.opcionales or r.faltan
            l[#l + 1] = a[1] .. " (" .. a[2] .. ")"
        end
    end
    -- Bartender solo hace falta si lo eligió
    if NS.pj and NS.pj.barras == "bartender" and not instalado("Bartender4") then
        r.faltan[#r.faltan + 1] = "Bartender4 (elegiste barras con Bartender)"
    end
    return r
end

-- ------------------------------------------------------------ auras
function I.clase()
    if not UnitClass then return nil end
    local _, c = UnitClass("player")
    return c
end

I.CLASES = { DEATHKNIGHT = "Caballero de la Muerte", DRUID = "Druida", HUNTER = "Cazador", MAGE = "Mago",
             PALADIN = "Paladín", PRIEST = "Sacerdote", ROGUE = "Pícaro", SHAMAN = "Chamán",
             WARLOCK = "Brujo", WARRIOR = "Guerrero" }

-- lo que hay para importar en cada modo (PvE: lo común más la de tu clase)
function I.paquetes(m)
    local d = NS.AURAS_DATOS
    if not d then return {} end
    local l = {}
    for _, x in ipairs(d[m] or {}) do l[#l + 1] = x end
    if m == "PvE" then
        local c = I.clase()
        if c and d.clases[c] then
            l[#l + 1] = { nombre = "WA de tu clase (" .. (I.CLASES[c] or c) .. ")", texto = d.clases[c],
                          uid = d.claseUid and d.claseUid[c], id = d.claseId and d.claseId[c], clase = true }
        end
    end
    return l
end

-- (0.9.9) los paquetes de este modo que todavía no están en tus WeakAuras (por
-- uid). La cuenta comparte las WeakAuras: con otro personaje de otra clase
-- puede estar todo menos la WA de su clase.
function I.faltanAuras(m)
    local ds = type(WeakAurasSaved) == "table" and WeakAurasSaved.displays
    local hay, arriba = {}, {}
    if type(ds) == "table" then
        for id, d in pairs(ds) do
            if type(d) == "table" then
                if d.uid then hay[d.uid] = true end
                -- (1.0) también por nombre del grupo de arriba (o su copia "Nombre 2")
                if type(id) == "string" and not d.parent then arriba[id] = true; arriba[id:match("^(.-) %d+$") or id] = true end
            end
        end
    end
    local r = {}
    for _, x in ipairs(I.paquetes(m)) do
        if not ((x.uid and hay[x.uid]) or (x.id and arriba[x.id])) then r[#r + 1] = x end
    end
    return r
end

-- importa en cadena: una ventana de WeakAuras por paquete
function I.importar(m)
    if not (WeakAuras and WeakAuras.Import) then
        NS.decir("Falta WeakAuras: instalalo y volvé a probar.")
        return false
    end
    -- solo lo que falta (si está todo, todo de nuevo: sirve para actualizar)
    local l = I.faltanAuras(m)
    if #l == 0 then l = I.paquetes(m) end
    if #l == 0 then return false end
    local i, hechas = 0, 0
    local function siguiente(ok)
        if ok then hechas = hechas + 1 end
        i = i + 1
        local x = l[i]
        if not x then
            I.importando = nil
            NS.decir(("Auras de %s: importaste %d de %d. Recargá (/reload) para que Modos las deje cargando solo en su modo.")
                :format(m, hechas, #l))
            if I.ventana and I.ventana:IsShown() then I.refrescar() end
            return
        end
        I.importando = m
        NS.decir(("Importando %s (%d de %d): tocá Importar en la ventana de WeakAuras."):format(x.nombre, i, #l))
        local okc, r, err = pcall(WeakAuras.Import, x.texto, nil, function(exito) siguiente(exito) end)
        -- si no abrió la ventana (texto malo o error), sigue con el próximo
        if not okc or (r == nil and err) or r == false then
            NS.decir("No pude abrir " .. x.nombre .. ": " .. tostring(okc and err or r))
            siguiente(false)
        end
    end
    siguiente(nil)
    return true
end

-- ------------------------------------------------------------ estado
function I.pendiente()
    return NS.pj and NS.pj.asistente == nil or false
end

-- (1.0.15) recargas pedidas mientras está abierto: en vez de una ventanita por cada
-- cosa (tapaban el panel), se anotan y se marca el botón Recargar
I.recargas = {}
function I.abierto() return I.ventana ~= nil and I.ventana:IsShown() and true or false end
function I.anotarRecarga(motivo)
    for _, m in ipairs(I.recargas) do if m == motivo then return end end
    I.recargas[#I.recargas + 1] = motivo
    if I.ventana then I.refrescar() end
end
-- las ventanitas de Modos que ya estaban abiertas al abrir el asistente
local function juntarRecargas()
    if not (StaticPopup_Visible and StaticPopup_Hide and NS.RECARGAS) then return end
    for n, motivo in pairs(NS.RECARGAS) do
        if StaticPopup_Visible(n) then
            StaticPopup_Hide(n)
            I.anotarRecarga(motivo)
        end
    end
end

-- al cerrarlo (Listo o la X) con una recarga pendiente: una sola ventanita
local function alCerrar()
    if #I.recargas == 0 or not (StaticPopupDialogs and StaticPopup_Show) then return end
    StaticPopupDialogs["MODOS_RECARGAR_ASISTENTE"] = StaticPopupDialogs["MODOS_RECARGAR_ASISTENTE"] or {
        text = "Modos: para terminar hay que recargar la interfaz (%s).",
        button1 = "Recargar",
        OnAccept = function() ReloadUI() end,
        timeout = 0, whileDead = 1, hideOnEscape = false, showAlert = 1,
    }
    StaticPopup_Show("MODOS_RECARGAR_ASISTENTE", table.concat(I.recargas, ", "))
end
I.alCerrar = alCerrar

function I.terminar()
    if NS.pj then NS.pj.asistente = I.VERSION end
    local falta = #I.recargas > 0
    if I.ventana then I.ventana:Hide() end
    NS.decir("Listo." .. (falta and " Falta recargar la interfaz." or "") .. " El asistente se vuelve a abrir con /modos instalar.")
end

local function bien(t) return C and E.cod(C.ok, t) or t end
local function mal(t) return C and E.cod(C.malo, t) or t end
local function gris(t) return C and E.cod(C.apagado, t) or t end

-- el texto de cada paso
function I.estados()
    local pj = NS.pj or {}
    local r = {}
    local f = I.faltan()
    if #f.faltan == 0 then
        r.addons = bien("Están todos.") .. (#f.opcionales > 0 and gris(" Opcionales que no están: " .. table.concat(f.opcionales, ", ") .. ".") or "")
    else
        r.addons = mal("Faltan: " .. table.concat(f.faltan, ", ") .. ".")
    end
    r.modo = pj.activo and bien("Estás en " .. pj.activo .. ".") or mal("Sin elegir: tocá el modo en que estás ahora.")
    local B = NS.barras
    if B and pj.barras and pj.barrasVista then
        r.barras = bien((pj.barras == "bartender" and "Bartender" or "Blizzard") .. ", "
            .. (pj.barrasVista == "visibles" and "a la vista" or "escondidas") .. ".")
    else
        r.barras = mal("Sin elegir.")
    end
    local R = NS.rol
    local rol = R and R.actual()
    r.rol = rol and bien(rol .. " (talento " .. (R.grupo() or 1) .. "). El otro talento se elige cuando lo uses.")
        or mal("Sin elegir para este talento.")
    local function estado(m)
        local total, faltan = #I.paquetes(m), I.faltanAuras(m)
        if #faltan == 0 then return bien("Instaladas.") end
        if #faltan == total then return mal("Sin instalar.") end
        if #faltan == 1 and faltan[1].clase then return mal("Falta la de tu clase.") end
        return mal(("Faltan %d de %d."):format(#faltan, total))
    end
    r.aurasPvE, r.aurasPvP = estado("PvE"), estado("PvP")
    return r
end

-- ------------------------------------------------------------ ventana
local ANCHO = 520
local function fila(f, y, titulo)
    local t = E.texto(f, "titulo")
    t:SetPoint("TOPLEFT", 14, y)
    t:SetText(titulo)
    local x = E.texto(f, "chico")
    x:SetPoint("TOPLEFT", 14, y - 20)
    x:SetWidth(ANCHO - 180)
    return x
end

function I.refrescar()
    local f = I.ventana
    if not f then return end
    local e = I.estados()
    f.addons:SetText(e.addons)
    f.modo:SetText(e.modo)
    f.barras:SetText(e.barras)
    f.rol:SetText(e.rol)
    f.auras:SetText("PvE: " .. e.aurasPvE .. "   PvP: " .. e.aurasPvP .. "\n" .. gris("Se instalan solas con cada personaje. Si borraste alguna: Importar (o /modos auras reinstalar)."))
    local activo = NS.pj and NS.pj.activo
    f.bPvE:SetText(activo == "PvE" and bien("PvE") or "PvE")
    f.bPvP:SetText(activo == "PvP" and bien("PvP") or "PvP")
    if #I.recargas > 0 then
        f.nota:SetText(mal("Hace falta recargar (" .. table.concat(I.recargas, ", ") .. "): seguí con los pasos y tocá Recargar al final."))
        if f.rec.SetTipo then f.rec:SetTipo("pri") end
    else
        f.nota:SetText(gris("Cuando termines: Recargar. Cada modo prende sus addons y carga sus auras solo. Comandos: /modos (ayuda)."))
    end
end

function I.abrir()
    if not (E and NS.pj) then return end
    if not I.ventana then
        local f = CreateFrame("Frame", "ModosInstalar", UIParent)
        f:SetWidth(ANCHO); f:SetHeight(430)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
        E.ventana(f)
        f:SetFrameStrata("DIALOG")
        f:SetToplevel(true)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        E.cerrar(f)
        local t = E.texto(f, "titulo")
        t:SetPoint("TOPLEFT", 14, -12)
        t:SetText("Modos · primeros pasos")
        local s = E.texto(f, "chico")
        s:SetPoint("TOPLEFT", 14, -32)
        s:SetWidth(ANCHO - 28)
        s:SetText("De arriba a abajo. Lo que ya está hecho aparece en verde. Se vuelve a abrir con /modos instalar.")

        f.addons = fila(f, -62, "1. Addons")
        f.modo = fila(f, -122, "2. ¿En qué modo estás ahora?")
        f.bPvE = E.boton(f, "PvE", 70, 22)
        f.bPvE:SetPoint("TOPRIGHT", -90, -126)
        f.bPvE:SetScript("OnClick", function() if NS.pedir then NS.pedir("PvE") end end)
        f.bPvP = E.boton(f, "PvP", 70, 22)
        f.bPvP:SetPoint("TOPRIGHT", -14, -126)
        f.bPvP:SetScript("OnClick", function() if NS.pedir then NS.pedir("PvP") end end)

        f.barras = fila(f, -172, "3. Barras de acción")
        local bb = E.boton(f, "Elegir", 146, 22)
        bb:SetPoint("TOPRIGHT", -14, -176)
        bb:SetScript("OnClick", function() if NS.barras then NS.barras.preguntar() end end)

        f.rol = fila(f, -222, "4. Rol en PvE")
        local br = E.boton(f, "Elegir", 146, 22)
        br:SetPoint("TOPRIGHT", -14, -226)
        br:SetScript("OnClick", function() if NS.rol then NS.rol.preguntar() end end)

        f.auras = fila(f, -272, "5. WeakAuras")
        local ba = E.boton(f, "Importar las de PvE", 146, 22)
        ba:SetPoint("TOPRIGHT", -14, -270)
        ba:SetScript("OnClick", function() I.importar("PvE") end)
        local bp = E.boton(f, "Importar las de PvP", 146, 22)
        bp:SetPoint("TOPRIGHT", -14, -296)
        bp:SetScript("OnClick", function() I.importar("PvP") end)

        local nota = E.texto(f, "chico")
        nota:SetPoint("BOTTOMLEFT", 14, 46)
        nota:SetWidth(ANCHO - 28)
        f.nota = nota
        local listo = E.boton(f, "Listo", 110, 24, "pri")
        listo:SetPoint("BOTTOMRIGHT", -14, 14)
        listo:SetScript("OnClick", I.terminar)
        local rec = E.boton(f, "Recargar", 110, 24)
        rec:SetPoint("RIGHT", listo, "LEFT", -8, 0)
        rec:SetScript("OnClick", function() if NS.pj then NS.pj.asistente = I.VERSION end; ReloadUI() end)
        f.rec = rec

        -- se refresca solo mientras está abierta (los otros pasos se contestan en sus ventanas)
        local t0 = 0
        f:SetScript("OnUpdate", function(_, dt)
            t0 = t0 + dt
            if t0 < 1 then return end
            t0 = 0
            I.refrescar()
        end)
        f:SetScript("OnHide", alCerrar)
        I.ventana = f
    end
    I.ventana:Show()
    juntarRecargas()
    I.refrescar()
end

-- ------------------------------------------------------------ al entrar
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
local visto = false
ev:SetScript("OnEvent", function(self)
    if visto then return end
    visto = true
    -- un momento después, cuando terminó de cargar todo
    local espera = 5
    self:SetScript("OnUpdate", function(s, dt)
        espera = espera - dt
        if espera > 0 then return end
        if InCombatLockdown and InCombatLockdown() then espera = 2; return end
        s:SetScript("OnUpdate", nil)
        if I.pendiente() then
            I.abrir()
        elseif NS.pj and NS.pj.activo == "PvE" and WeakAuras then
            -- (0.9.9) falta la WA de esta clase. (1.0) Se pone sola: solo avisa si no se
            -- pudo (si la borraste a propósito, no insiste)
            local hechos = ModosDB and ModosDB.auras and ModosDB.auras.instalados or {}
            for _, x in ipairs(I.faltanAuras("PvE")) do
                if x.clase and not hechos[x.uid or ""] then
                    NS.decir("Falta la WeakAura de tu clase: escribí /modos auras reinstalar (o /modos instalar y \"Importar las de PvE\").")
                    break
                end
            end
        end
    end)
end)
