-- Modos · Estilo: la misma paleta fría y las piezas planas de SubastaLog
-- (botones, casillas, ventana), con letras propias para no chocar entre sí.

local _, NS = ...
NS = NS or {}
local E = {}
NS.E = E

E.FUENTE = "Fonts\\ARIALN.TTF"
E.PLANO = "Interface\\Buttons\\WHITE8X8"
E.BD = { bgFile = E.PLANO, edgeFile = E.PLANO, edgeSize = 1,
         insets = { left = 1, right = 1, top = 1, bottom = 1 } }

local function color(h)
    return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255,
             tonumber(h:sub(5, 6), 16) / 255, h = h }
end
E.C = {
    fondo = color("10141c"), borde = color("243044"), fila = color("151b26"),
    boton = color("1a2231"), bordeBoton = color("2a3850"), sel = color("1c2d43"),
    acento = color("5aa9e6"), sobreAcento = color("0b2236"), titulo = color("7fbef0"),
    texto = color("e3ebf5"), textoBoton = color("cdd6e2"), apagado = color("8d97a6"),
    inactivo = color("6f7a8c"), riesgo = color("e5a55a"), bordeRiesgo = color("5a4424"),
    ok = color("8fcf8f"), malo = color("e57373"), textoOff = color("545e6e"), caja = color("0b0e14"),
}
local C = E.C
E.BLANCO = { 1, 1, 1, h = "ffffff" }

function E.cod(col, texto) return "|cff"..col.h..texto.."|r" end

local function fuente(nombre, tam, col)
    local f = CreateFont(nombre)
    f:SetFont(E.FUENTE, tam, "")
    f:SetTextColor(col[1], col[2], col[3])
    return f
end
E.F = {
    titulo   = fuente("ModosF_Titulo", 16, C.titulo),
    seccion  = fuente("ModosF_Seccion", 15, C.titulo),
    texto    = fuente("ModosF_Texto", 14, C.texto),
    chico    = fuente("ModosF_Chico", 13, C.apagado),
    boton    = fuente("ModosF_Boton", 13, C.textoBoton),
    botonHL  = fuente("ModosF_BotonHL", 13, E.BLANCO),
    botonOff = fuente("ModosF_BotonOff", 13, C.textoOff),
    botonPri = fuente("ModosF_BotonPri", 13, C.sobreAcento),
    botonRie = fuente("ModosF_BotonRiesgo", 13, C.riesgo),
    cerrar   = fuente("ModosF_Cerrar", 20, C.inactivo),
    cerrarHL = fuente("ModosF_CerrarHL", 20, E.BLANCO),
}

function E.texto(parent, tipo, capa)
    local fs = parent:CreateFontString(nil, capa or "OVERLAY")
    fs:SetFontObject(E.F[tipo or "texto"])
    fs:SetJustifyH("LEFT")
    return fs
end

function E.ventana(f)
    f:SetBackdrop(E.BD)
    f:SetBackdropColor(C.fondo[1], C.fondo[2], C.fondo[3], 0.97)
    f:SetBackdropBorderColor(C.borde[1], C.borde[2], C.borde[3], 1)
end

function E.cerrar(f, alCerrar)
    local b = CreateFrame("Button", nil, f)
    b:SetWidth(24); b:SetHeight(24)
    b:SetPoint("TOPRIGHT", -4, -4)
    b:SetNormalFontObject(E.F.cerrar)
    b:SetHighlightFontObject(E.F.cerrarHL)
    b:SetText("×")
    b:SetScript("OnClick", function() if alCerrar then alCerrar() else f:Hide() end end)
    return b
end

function E.linea(parent, y, izq, der)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetTexture(C.borde[1], C.borde[2], C.borde[3], 1)
    t:SetHeight(1)
    t:SetPoint("TOPLEFT", izq or 1, y)
    t:SetPoint("TOPRIGHT", -(der or 1), y)
    return t
end

-- tipo: nil (normal), "pri" (el modo en uso, con relleno de acento),
-- "riesgo" (letra naranja: el modo que espera que salgas de combate)
local function pintar(b)
    local bg, bd, fn, fh
    if b.tipo == "pri" then
        bg, bd, fn, fh = C.acento, C.acento, E.F.botonPri, E.F.botonPri
    elseif b.tipo == "riesgo" then
        bg, bd, fn, fh = C.boton, C.riesgo, E.F.botonRie, E.F.botonRie
    else
        bg, bd, fn, fh = C.boton, C.bordeBoton, E.F.boton, E.F.botonHL
    end
    b:SetBackdropColor(bg[1], bg[2], bg[3], 1)
    b:SetBackdropBorderColor(bd[1], bd[2], bd[3], 1)
    b:SetNormalFontObject(fn)
    b:SetHighlightFontObject(fh)
    b:SetDisabledFontObject(E.F.botonOff)
end
local function setTipo(self, t) if self.tipo ~= t then self.tipo = t; pintar(self) end end

function E.boton(parent, texto, ancho, alto, tipo, nombre)
    local b = CreateFrame("Button", nombre, parent)
    b:SetWidth(ancho or 100); b:SetHeight(alto or 22)
    b:SetBackdrop(E.BD)
    local h = b:CreateTexture(nil, "HIGHLIGHT")
    h:SetPoint("TOPLEFT", 1, -1); h:SetPoint("BOTTOMRIGHT", -1, 1)
    h:SetTexture(1, 1, 1, 0.08)
    b.tipo = tipo
    pintar(b)
    b:SetPushedTextOffset(1, -1)
    b.SetTipo = setTipo
    if texto then b:SetText(texto) end
    return b
end

function E.casilla(parent, tam)
    tam = tam or 16
    local c = CreateFrame("CheckButton", nil, parent)
    c:SetWidth(tam); c:SetHeight(tam)
    c:SetBackdrop(E.BD)
    c:SetBackdropColor(C.caja[1], C.caja[2], C.caja[3], 1)
    c:SetBackdropBorderColor(C.bordeBoton[1], C.bordeBoton[2], C.bordeBoton[3], 1)
    c:SetCheckedTexture(E.PLANO)
    local t = c:GetCheckedTexture()
    if type(t) == "table" then
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", 3, -3); t:SetPoint("BOTTOMRIGHT", -3, 3)
        t:SetVertexColor(C.acento[1], C.acento[2], C.acento[3], 1)
    end
    local h = c:CreateTexture(nil, "HIGHLIGHT")
    h:SetAllPoints(c); h:SetTexture(1, 1, 1, 0.10)
    return c
end

-- tooltip corto: título y renglones
function E.ayuda(owner, titulo, ...)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(titulo, C.titulo[1], C.titulo[2], C.titulo[3])
    for i = 1, select("#", ...) do
        local l = select(i, ...)
        if l and l ~= "" then GameTooltip:AddLine(l, C.texto[1], C.texto[2], C.texto[3], true) end
    end
    GameTooltip:Show()
end
function E.sinAyuda() if GameTooltip then GameTooltip:Hide() end end
