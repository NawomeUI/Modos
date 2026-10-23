-- Modos · Ventanas (1.0.13): Details en su lugar y el botón para esconder el chat.
--
-- Details: Modos ya le cambia el perfil por modo, pero no ubicaba la ventana (la
-- acomodaba a mano). Va abajo a la derecha, a la izquierda de las columnas de
-- barras y arriba del menú y las bolsas, donde la tenía él (18/10). En PvP una
-- ventana de daño. En PvE dos: daño arriba y curación abajo. Cada modo tiene su
-- perfil de Details, así que cada uno guarda sus ventanas.
--
-- Chat: un botoncito rectangular abajo a la izquierda (como el de FriskesUI) que
-- esconde y vuelve a mostrar el chat. Se acuerda por personaje. Escondido, los
-- mensajes siguen llegando y Enter abre igual la línea para escribir.

local _, NS = ...
local E = NS.E

local V = {}
NS.ventanas = V

-- ------------------------------------------------------------ Details
function V.hayDetails()
    local D = _detalhes
    return type(D) == "table" and type(D.GetInstance) == "function" and type(D.CreateInstance) == "function"
end

-- pone las ventanas de Details del modo m (PR.DETAILS). Devuelve true si quedaron.
function V.details(m)
    local pr = NS.presets
    local c = pr and pr.DETAILS
    local lista = c and c[m]
    if not (lista and V.hayDetails()) then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    local D = _detalhes
    -- de abajo para arriba: la última de la lista va abajo de todo
    local y = c.abajo
    local puestas = {}
    for i = #lista, 1, -1 do
        local v = lista[i]
        local inst = D:GetInstance(i)
        if not inst then
            local ok, nueva = pcall(D.CreateInstance, D, true)
            inst = ok and nueva or nil
        elseif inst.IsEnabled and not inst:IsEnabled() and inst.EnableInstance then
            pcall(inst.EnableInstance, inst)
        end
        local f = inst and inst.baseframe
        if not f then return false end
        local s = (f.GetScale and f:GetScale()) or 1
        if not s or s <= 0 then s = 1 end
        f:ClearAllPoints()
        f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -c.margenDer / s, y / s)
        f:SetWidth(c.ancho / s)
        f:SetHeight(v.alto / s)
        if inst.SaveMainWindowPosition then pcall(inst.SaveMainWindowPosition, inst) end
        if v.atributo and inst.SetDisplay then pcall(inst.SetDisplay, inst, 0, v.atributo, 1) end
        puestas[i] = true
        y = y + v.alto + c.titulo + c.separacion
    end
    -- las que sobran (por ejemplo la de curación en PvP), cerradas
    local total = D.GetNumInstancesAmount and D:GetNumInstancesAmount() or #lista
    for i = #lista + 1, total do
        local inst = D:GetInstance(i)
        if inst and inst.IsEnabled and inst:IsEnabled() and inst.ShutDown then pcall(inst.ShutDown, inst) end
    end
    return true
end

-- ------------------------------------------------------------ chat
V.CHAT_EXTRAS = { "GeneralDockManager", "ChatFrameMenuButton", "FriendsMicroButton" }
local estaban = {}

local function marcos(fn)
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        for _, sufijo in ipairs({ "", "Tab", "ButtonFrame" }) do
            local f = _G["ChatFrame" .. i .. sufijo]
            if f and f.Hide then fn(f) end
        end
    end
    for _, n in ipairs(V.CHAT_EXTRAS) do
        local f = _G[n]
        if f and f.Hide then fn(f) end
    end
end

-- la línea para escribir de cada chat cuelga de su chat: con el chat escondido no se
-- vería al apretar Enter. Mientras está escondido cuelga de la pantalla (mismo lugar).
local padres = {}
local function lineas(ocultar)
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local eb, cf = _G["ChatFrame" .. i .. "EditBox"], _G["ChatFrame" .. i]
        if eb and eb.GetParent and eb.SetParent then
            if ocultar then
                if cf and eb:GetParent() == cf then padres[eb] = cf; eb:SetParent(UIParent) end
            elseif padres[eb] then
                eb:SetParent(padres[eb])
                padres[eb] = nil
            end
        end
    end
end

function V.chatOculto()
    return NS.pj and NS.pj.chatOculto and true or false
end

-- esconde (true) o vuelve a mostrar (false) el chat
function V.ponerChat(oculto)
    lineas(oculto)
    if oculto then
        marcos(function(f)
            if f:IsShown() then estaban[f] = true; f:Hide() end
        end)
    else
        marcos(function(f)
            if estaban[f] then f:Show() end
        end)
        estaban = {}
    end
    if V.boton then V.boton:SetText(oculto and "chat +" or "chat") end
end

function V.alternarChat()
    if not NS.pj then return end
    NS.pj.chatOculto = not NS.pj.chatOculto or nil
    V.ponerChat(V.chatOculto())
end

function V.crearBoton()
    if V.boton or not E then return V.boton end
    local b = E.boton(UIParent, "chat", 46, 14, nil, "ModosChatBoton")
    b:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 6, 6)
    b:SetFrameStrata("LOW")
    b:SetAlpha(0.6)
    b:SetScript("OnClick", function() V.alternarChat() end)
    b:SetScript("OnEnter", function(self)
        self:SetAlpha(1)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
            GameTooltip:SetText(V.chatOculto() and "Mostrar el chat" or "Esconder el chat")
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self)
        self:SetAlpha(0.6)
        if GameTooltip then GameTooltip:Hide() end
    end)
    V.boton = b
    return b
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function()
    V.crearBoton()
    -- el chat se arma al entrar: se esconde un momento después
    if V.chatOculto() and NS.despues then
        NS.despues(1, "chat", function() V.ponerChat(true) end)
    elseif V.chatOculto() then
        V.ponerChat(true)
    end
end)
