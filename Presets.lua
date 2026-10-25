-- Modos · Presets: la UI armada de cada modo (por ahora PvE).
--
-- Estética de WoW: de ElvUI las placas y el tooltip (como la UI "friskes"). Chat,
-- buffs, minimapa y bolsas de Blizzard, barras de Bartender4. En PvE además los
-- marcos de ElvUI de Merfin (12/10). La pantalla de su cliente mide 1920 x 1080 unidades.
--
-- Se aplica la primera vez que entrás al modo y cada vez que cambia VERSION
-- (para ir puliéndolo). Se escribe en los perfiles propios de este personaje
-- para ese modo (no toca los de otros personajes) y toma efecto al recargar.
-- /modos preset lo vuelve a aplicar.

local _, NS = ...

local PR = {}
NS.presets = PR

PR.VERSION = { PvE = 11, PvP = 14 }

-- (0.9.4) todo está pensado para una pantalla de 1080 unidades de alto (la escala
-- de interfaz 0,711 de ElvUI, que pone Aspecto.lua). Así se ve igual en 1080p,
-- 1440p o 4K. En pantallas más anchas o más angostas que 16:9 cambia el ancho:
-- lo de los costados va pegado a los bordes y lo del medio, relativo al centro.
PR.ESCALA = 768 / 1080
function PR.ancho()
    local w, h = GetScreenWidth and GetScreenWidth(), GetScreenHeight and GetScreenHeight()
    if w and h and h > 0 then return 1080 * w / h end
    return 1920
end
-- una x guardada desde el borde izquierdo, que tiene que quedar a la misma
-- distancia del centro en cualquier ancho (se calcula al poner el preset)
local function centrado(x) return function() return x + (PR.ancho() - 1920) / 2 end end

-- barras: botones de 36 con 2 de separación, 12 por columna = 454 de alto.
-- La posición de Bartender4 es la esquina de arriba a la izquierda de la barra.
local LARGO = 12 * 36 + 11 * 2
-- columnas pegadas al borde derecho, centradas en alto (la 1 es la del borde)
local function costado(col)
    return { point = "RIGHT", x = -(16 + 40 * col), y = LARGO / 2, scale = 1,
             growHorizontal = "RIGHT", growVertical = "DOWN" }
end
-- invisible: solo aparece con el mouse encima (los binds andan igual)
local function invisible(t)
    t.fadeout, t.fadeoutalpha, t.fadeoutdelay, t.alpha = true, 0, 0.2, 1
    return t
end
-- escondida: no se ve nunca y el mouse la atraviesa (no se puede tocar sin
-- querer en una arena). Los binds andan igual. Para acomodarla: /bt4.
local function escondida(t)
    t.fadeout, t.alpha, t.clickthrough = false, 0, true
    return t
end
-- (1.0.25) a la vista y se puede tocar (la de profesiones, monturas y mascotas)
local function aLaVista(t)
    t.enabled, t.fadeout, t.alpha, t.clickthrough = true, false, 1, false
    return t
end
-- una barra como la de su cuenta principal: a la vista, tamaño normal, se puede tocar
local function bypass(pos, filas)
    pos.scale = 1
    pos.growHorizontal, pos.growVertical = "RIGHT", "DOWN"
    return { enabled = true, position = pos, rows = filas, fadeout = false, alpha = 1, clickthrough = false }
end
-- columnas chicas pegadas al borde derecho (escala 0,6). Las posiciones de
-- Bartender4 van en unidades de pantalla (LibWindow las divide por la escala).
local function costadoChico(col)
    local e = 0.6
    return { point = "RIGHT", x = -(4 + 24 * col), y = LARGO * e / 2, scale = e,
             growHorizontal = "RIGHT", growVertical = "DOWN" }
end

PR.PvE = {
    -- parte privada de ElvUI: qué módulos andan. Desde la versión 3, como la UI
    -- "friskes" que le gusta (10/10): de ElvUI solo las placas. Chat y tooltip de
    -- Blizzard (el chat de ElvUI no se podía mover ni se veía lo que escribís).
    privado = {
        unitframe = { enable = false },          -- marcos de Blizzard
        actionbar = { enable = false },          -- barras de Bartender4
        bags = { enable = false },               -- bolsas de Blizzard (o Bagnon)
        -- buffs de Blizzard: ElvUI los esconde de fábrica aunque su módulo esté
        -- apagado (disableBlizzard). Por eso no se veían tus buffs y debuffs.
        auras = { enable = false, disableBlizzard = false },
        chat = { enable = false },               -- chat de Blizzard
        nameplates = { enable = true },
        tooltip = { enable = true },             -- tooltip de ElvUI (lo pidió, 11/10)
        -- hideCalendar: ElvUI esconde el calendario del minimapa de fábrica aunque su
        -- minimapa esté apagado (Bypass lo tiene a la vista, 11/10)
        general = { minimap = { enable = false, hideCalendar = false }, replaceBlizzFonts = false, loot = false,
                    lootRoll = false, raidUtility = false },
        skins = { blizzard = { enable = false }, ace3 = { enable = false } },
    },
    -- perfil de ElvUI: chat que parece el original y sin barras de datos
    ElvDB = {
        hideTutorial = true,                     -- sin los "consejos" de ElvUI al entrar (12/10)
        chat = {
            panelBackdrop = "HIDEBOTH", panelTabBackdrop = false, panelTabTransparency = true,
            font = "Friz Quadrata TT", tabFont = "Friz Quadrata TT",
            fontOutline = "NONE", tabFontOutline = "NONE",
        },
        datatexts = {
            leftChatPanel = false, rightChatPanel = false, minimapPanels = false,
            panelBackdrop = false, panelTransparency = true, font = "Friz Quadrata TT",
        },
        -- sin la barra negra de abajo (ni la de arriba), sin AFK ni mensaje al entrar.
        -- Minimapa como Bypass (perfil friskes de su cuenta): ElvUI acomoda los botones
        -- del minimapa de Blizzard aunque su minimapa esté apagado. De fábrica pone el
        -- de BG abajo a la derecha: ahí estaba la diferencia (11/10).
        general = { bottomPanel = false, topPanel = false, afk = false, loginmessage = false,
                    threat = { enable = false }, cropIcon = 0, hideErrorFrame = false, enhancedPvpMessages = false,
                    minimap = { size = 170, locationText = "SHOW", locationFont = "Expressway", icons = {
                        battlefield = { position = "BOTTOMLEFT", xOffset = -26, yOffset = -5 },
                        lfgEye = { position = "BOTTOMLEFT", xOffset = -28, yOffset = 17 },
                        calendar = { position = "BOTTOMRIGHT", scale = 0.9, xOffset = 3, yOffset = -3 },
                        mail = { scale = 1.1, xOffset = 8, yOffset = -23 },
                        difficulty = { xOffset = -37, yOffset = 5 },
                        vehicleLeave = { xOffset = 0, yOffset = 0 },
                    } } },
        tooltip = { cursorAnchor = true, cursorAnchorType = "ANCHOR_CURSOR_LEFT" },   -- como friskes
        -- (1.0.13) sin la barra de experiencia de la mascota de ElvUI (quedaba suelta)
        databars = { experience = { enable = false }, petExperience = { enable = false } },
        cooldown = { enable = false },           -- los números los pone OmniCC
        -- placas como friskes: finas, con auras a los costados (no encima), casteo con ícono
        -- a la izquierda y sin texto, nombre arriba, sin nivel, sin transparencia
        nameplates = {
            statusbar = "Smooth", targetScale = 1.05, nonTargetTransparency = 1, fadeIn = false,
            lowHealthThreshold = 0, alwaysShowTargetHealth = false,
            plateSize = { enemyWidth = 130, enemyHeight = 20, friendlyWidth = 50, friendlyHeight = 15 },
            threat = { useThreatColor = false, goodScale = 1, badScale = 1 },
            units = {
                -- enemigos: tus CC y dots arriba del nombre (1.0.4: a la izquierda de la
                -- barra se encimaban con tus marcos), sus buffs importantes (defensivos)
                -- a la derecha, chicos y en una fila (10/10). TOPRIGHT en esta ElvUI: el
                -- grupo va centrado arriba de la barra y los íconos crecen a la derecha.
                -- 18 arriba de la barra: el nombre ocupa de 3 a 16.
                ENEMY_PLAYER = {
                    debuffs = { enable = true, attachTo = "FRAME", anchorPoint = "TOPRIGHT", growthX = "RIGHT",
                                growthY = "UP", xOffset = 0, yOffset = 18, size = 22, perrow = 4, numrows = 1,
                                spacing = 1, durationFontSize = 11, countFontSize = 10,
                                filters = { priority = "Blacklist,blockNoDuration,Personal,CCDebuffs" } },
                    buffs = { enable = true, attachTo = "FRAME", anchorPoint = "RIGHT", growthX = "RIGHT",
                              growthY = "UP", xOffset = 3, yOffset = 0, size = 22, perrow = 4, numrows = 1,
                              spacing = 1, durationFontSize = 11, countFontSize = 10,
                              filters = { maxDuration = 300, priority = "Blacklist,PlayerBuffs,TurtleBuffs" } },
                    markHealers = false,
                    health = { width = 130 },
                    castbar = { width = 130, height = 15, hideSpellName = true, hideTime = true,
                                iconPosition = "LEFT", iconSize = 27, iconOffsetX = -2 },
                    level = { enable = false },
                    name = { font = "Expressway", fontSize = 12, parent = "Nameplate", position = "TOP", yOffset = 3 },
                },
                ENEMY_NPC = {
                    buffs = { enable = false }, debuffs = { enable = false },
                    health = { width = 130 },
                    castbar = { width = 130, height = 15, hideSpellName = true, hideTime = true,
                                iconPosition = "LEFT", iconSize = 27, iconOffsetX = -2 },
                    level = { enable = false },
                    name = { font = "Expressway", fontSize = 12, parent = "Nameplate", position = "TOP", yOffset = 3 },
                },
                FRIENDLY_PLAYER = {
                    buffs = { enable = false }, debuffs = { enable = false }, castbar = { enable = false },
                    health = { enable = true, width = 50 },
                    name = { font = "Expressway", fontSize = 12, parent = "Nameplate", position = "TOP", yOffset = 3 },
                },
                FRIENDLY_NPC = {
                    buffs = { enable = false }, debuffs = { enable = false }, castbar = { enable = false },
                    health = { enable = true, width = 50 }, level = { enable = false },
                    name = { font = "Expressway", fontSize = 12, parent = "Nameplate", position = "TOP", yOffset = 3 },
                },
                TARGET = { glowStyle = "style1", comboPoints = { enable = false } },
            },
        },
    },
    -- Bartender4: en PvE nada en el medio. Las barras 1 a 6 en columnas a la
    -- derecha, invisibles (aparecen con el mouse encima para acomodar hechizos).
    -- (1.0.25) lo pidió (25/10): una barra a la vista en la columna del borde para
    -- profesiones, monturas y mascotas, la 10 (ninguna postura la cambia: Bartender pasa
    -- la 1 a la 7, 8 o 9 con las posturas, nunca a la 10), y las escondidas juntas a su
    -- izquierda, así al ponerlas a la vista para bindear (/modos barras ver) se ven todas.
    -- (1.0.28) cambió (25/10): la que queda a la vista es la 2 (tampoco la cambia
    -- ninguna postura) y las otras escondidas del todo, sin aparecer con el mouse
    -- ("no habíamos descartado eso?"). Para bindear o acomodar hechizos: /modos barras ver
    -- (o el botón Barras de la ventana de Modos). La 10 apagada otra vez.
    Bartender4 = {
        ActionBars = { actionbars = {
            [2] = aLaVista({ position = costado(1), rows = 12 }),
            [1] = escondida({ position = costado(2), rows = 12 }),
            [3] = escondida({ position = costado(3), rows = 12 }),
            [4] = escondida({ position = costado(4), rows = 12 }),
            [5] = escondida({ position = costado(5), rows = 12 }),
            [6] = escondida({ position = costado(6), rows = 12 }),
            -- (1.0.13) las barras 7 a 9 (páginas de posturas) apagadas: la 1 ya cambia
            -- sola con la postura. No aparecen ni con el mouse.
            [7] = { enabled = false }, [8] = { enabled = false }, [9] = { enabled = false }, [10] = { enabled = false },
        } },
        -- (12/10) posturas/formas/auras de pala, pet y totems: abajo a la izquierda,
        -- arriba del chat y fuera del medio (ahí van la WA de clase y Mis CDs).
        -- Semitransparentes; con el mouse encima se ven del todo. Los binds andan igual.
        -- (1.0.13) con las barras escondidas: posturas/formas y totems abajo, a la
        -- izquierda de Mis CDs (que va de -256 a 256) sin llegar al chat, y la mascota
        -- abajo a la derecha de Mis CDs, más chica (0,7) para no llegar a Details.
        -- Nada arriba del chat (quedaban colgadas, en todas las clases).
        StanceBar = { fadeout = true, fadeoutalpha = 0.35, alpha = 1,
                      position = { point = "BOTTOM", x = -480, y = 116, scale = 0.8 } },
        PetBar = { fadeout = true, fadeoutalpha = 0.35, alpha = 1,
                   position = { point = "BOTTOM", x = 262, y = 116, scale = 0.7 } },
        MultiCast = { fadeout = true, fadeoutalpha = 0.35, alpha = 1,
                      position = { point = "BOTTOM", x = -480, y = 116, scale = 0.8 } },
        -- menú y bolsas lado a lado sin encimarse (11/10)
        MicroMenu = { position = { point = "BOTTOMRIGHT", x = -420, y = 40, scale = 0.8 } },
        BagBar = { position = { point = "BOTTOMRIGHT", x = -190, y = 40, scale = 0.8 } },
    },
    -- (12/10) los marcos son los de ElvUI (PresetPvE.lua), en el lugar de Merfin
    -- según el rol (Rol.lua): los de Blizzard quedan escondidos.
}
-- (0.9.2) PvE con las barras a la vista (/modos barras): como las de Blizzard
-- sin Bartender. Abajo al centro la 1 y la 2, arriba de ellas la 6 y la 5 (los
-- mismos casilleros que la principal, la de más y las de abajo de Blizzard), y la
-- 3 y la 4 en columnas a la derecha. Posturas, mascota, totems, menú y bolsas
-- donde en la otra forma. Mis CDs no se muestra.
PR.PvE.Bartender4Visible = {
    ActionBars = { actionbars = {
        [1] = bypass({ point = "BOTTOM", x = -463.6, y = 42 }, 1),
        [2] = bypass({ point = "BOTTOM", x = -7.3, y = 42 }, 1),
        [6] = bypass({ point = "BOTTOM", x = -463.6, y = 82 }, 1),
        [5] = bypass({ point = "BOTTOM", x = -5.6, y = 82 }, 1),
        [3] = bypass({ point = "RIGHT", x = -42, y = 43 }, 12),
        [4] = bypass({ point = "RIGHT", x = -82, y = 43.3 }, 12),
        [7] = { enabled = false }, [8] = { enabled = false }, [9] = { enabled = false }, [10] = { enabled = false },
    } },
}
for k, v in pairs(PR.PvE.Bartender4) do
    if k ~= "ActionBars" then PR.PvE.Bartender4Visible[k] = v end
end
-- (1.0.13) a la vista: posturas/formas y totems justo arriba de la barra 6 (arriba
-- a la izquierda, empieza en -463.6 y su borde de arriba está en 82), y la mascota
-- arriba de la barra 5, pegada a su borde derecho (448.4): 10 botones de 30 con 2
-- de separación a escala 0,8 = 254. Ninguna clase tiene posturas y totems a la vez.
PR.PvE.Bartender4Visible.StanceBar = { fadeout = true, fadeoutalpha = 0.35, alpha = 1,
    position = { point = "BOTTOM", x = -463.6, y = 116, scale = 0.8 } }
PR.PvE.Bartender4Visible.MultiCast = { fadeout = true, fadeoutalpha = 0.35, alpha = 1,
    position = { point = "BOTTOM", x = -463.6, y = 116, scale = 0.8 } }
PR.PvE.Bartender4Visible.PetBar = { fadeout = true, fadeoutalpha = 0.35, alpha = 1,
    position = { point = "BOTTOM", x = 194, y = 116, scale = 0.8 } }

-- ------------------------------------------------------------ PvP
-- Misma estética que PvE (de ElvUI solo las placas). Barras 1 a 6 chicas y
-- escondidas al costado (ni con el mouse aparecen), en el medio solo las de CDs (9 y 10) bien abajo y la
-- de posturas a la vista. Marcos más chicos arriba a la izquierda (jugador y
-- objetivo juntos, foco abajo del objetivo), como el dibujo del 09/10, corridos
-- para no tapar la columna de alertas del centro (maqueta del 10/10).
-- Gladius y Quartz también (versión 2): casteos de arena más grandes y el
-- casteo del foco arriba del tuyo. Compact Raid Frames lo acomoda él.
local function centro(fila)           -- filas de CDs abajo al centro, chicas
    local escala = 0.85
    return { point = "BOTTOM", x = -(12 * 36 + 11 * 2) / 2 * escala, y = 8 + (36 + (fila - 1) * 40) * escala,
             scale = escala, growHorizontal = "RIGHT", growVertical = "DOWN" }
end

PR.PvP = {
    privado = PR.PvE.privado,
    ElvDB = PR.PvE.ElvDB,
    -- (11/10) las barras como en su cuenta principal (perfil Bypass): 1, 6, 5 y 3
    -- abajo al centro en dos filas, 2 y 4 en columnas a la derecha, menú y bolsas
    -- escondidos (aparecen con el mouse). Sus CDs a mano los muestra el aura Mis CDs.
    Bartender4 = {
        ActionBars = { actionbars = {
            [1] = bypass({ point = "BOTTOM", x = -463.6, y = 42 }, 1),
            [6] = bypass({ point = "BOTTOM", x = -7.3, y = 42 }, 1),
            [5] = bypass({ point = "BOTTOM", x = -463.6, y = 82 }, 1),
            [3] = bypass({ point = "BOTTOM", x = -5.6, y = 82 }, 1),
            [2] = bypass({ point = "RIGHT", x = -42, y = 43 }, 12),
            [4] = bypass({ point = "RIGHT", x = -82, y = 43.3 }, 12),
            -- (1.0.13) la 7 (venía de Bypass, aparecía con el mouse arriba a la
            -- derecha) y la 8 apagadas: no las quiere ni con el mouse
            [7] = { enabled = false }, [8] = { enabled = false },
            [9] = { enabled = false },
            [10] = { enabled = false },
        } },
        StanceBar = { fadeout = false, alpha = 1, padding = 8,
                      position = { point = "BOTTOM", x = -115.5, y = 115.4, scale = 1 } },
        -- (1.0.13) los totems donde las posturas (ninguna clase tiene las dos)
        MultiCast = { fadeout = false, alpha = 1, position = { point = "BOTTOM", x = -115.5, y = 116, scale = 1 } },
        PetBar = { fadeout = false, alpha = 1, position = { point = "BOTTOM", x = -465, y = 116, scale = 1 } },
        MicroMenu = { fadeout = true, fadeoutalpha = 0, alpha = 1,
                      position = { point = "BOTTOMRIGHT", x = -256.5, y = 40.5, scale = 1 } },
        BagBar = { fadeout = true, fadeoutalpha = 0, alpha = 1,
                   position = { point = "BOTTOMRIGHT", x = -164, y = 79.6, scale = 1 } },
    },
    -- { punto, punto de la pantalla, x, y, escala }. Con escala, x e y van en la
    -- escala del marco: en pantalla quedan en x*0,85 e y*0,85.
    marcos = {
        -- (11/10) más separados y el foco más abajo. Si EasyFrames los agranda,
        -- Modos corre el jugador a la izquierda para que no se encime con el objetivo.
        -- (1.0.4) 120 más a la izquierda (los quería más lejos del centro)
        PlayerFrame = { "CENTER", "CENTER", -600 / 0.85, 200 / 0.85, 0.85 },
        TargetFrame = { "CENTER", "CENTER", -355 / 0.85, 200 / 0.85, 0.85 },
        -- (1.0.13) 18 más arriba: con EasyFrames (1,08) la esquina de abajo a la derecha
        -- tocaba la primera fila de Mis CDs
        FocusFrame = { "CENTER", "CENTER", -355 / 0.85, -122 / 0.85, 0.85 },      -- bien abajo (11/10)
    },
    -- opciones del juego: sin los marcos de arena de Blizzard (los muestra Gladius).
    -- Toma efecto al recargar.
    cvars = { showArenaEnemyFrames = "0" },   -- más las comunes (texto de combate)
    -- otros addons con AceDB: se escriben en el perfil propio de PvP de este
    -- personaje. Si el addon está apagado en ese momento, se pone al entrar.
    sv = {
        -- Gladius: tu configuración de siempre (perfil Bypass), con los casteos
        -- de los enemigos más grandes para cortar cómodo
        -- de los enemigos grandes al costado (a la izquierda de cada marco, hacia el
        -- centro). Corrido a la derecha para que esos casteos no tapen la columna de
        -- alertas del centro, y sin el fondo que se veía como un recuadro (11/10).
        GladiusDB = { addon = "Gladius", perfil = {
            -- sin los CDs usados a la derecha (eso lo muestran las auras): ahí van los DR
            -- (1.0.4) trinket y DR a la izquierda del marco (entre el casteo y la vida),
            -- un poco más grandes. Gladius pone el trinket grande siempre a la
            -- derecha: lo corre ArenaGladius.lua.
            -- (1.0.6) lo quería 40 a la izquierda, no a la derecha: de 1000 a 960
            -- (la 1.0.4 lo había puesto en 1040). Todo 10% más grande (frameScale)
            -- y los casteos más anchos y gruesos (150x18 a 160x21, letra 12).
            locked = true, x = centrado(960), y = 545, frameScale = 1.1, trinketDisplay = "bigIcon", cooldown = false,
            bigTrinketScale = 1.15, drCooldown = true, drCooldownPos = "LEFT",
            trinketUpAnnounce = true, trinketUsedAnnounce = true,
            castBar = true, castBarPos = "LEFT", castBarHeight = 21, castBarWidth = 160, castBarFontSize = 12,
            frameColor = { r = 0, g = 0, b = 0, a = 0 },
            castBarBgColor = { r = 0, g = 0, b = 0, a = 0 },      -- sin fondo: sin casteo no se ve nada (12/10)
        } },
        -- Quartz: solo tu casteo, al centro abajo (x e y = esquina de abajo a la
        -- izquierda, en una pantalla de 1365 x 768). El del foco lo muestra su marco
        -- (había casteos por todos lados, 11/10): módulo Focus apagado.
        -- (11/10) en el lugar de su cuenta principal (Bypass): centrado, un poco
        -- más arriba. La pantalla de su cliente mide 1920 x 1080 unidades.
        -- (0.9.7) sin el módulo Buff (barras de buffs del objetivo y el foco): lo pidió
        Quartz3DB = { addon = "Quartz", perfil = { modules = { Focus = false, Buff = false },
                      backgroundcolor = { 0, 0, 0 }, backgroundalpha = 1 }, ns = {
            Player = { x = centrado(843), y = 173 },
        } },
    },
}

-- EasyFrames (los dos modos): vida en "27k" en vez de "27T" (formato propio,
-- como lo tiene en su cuenta principal), barras lisas como allá, y jugador,
-- objetivo y foco 10% más chicos que los de fábrica (1,2 -> 1,08). 11/10.
PR.EASYFRAMES = { addon = "EasyFrames", perfil = {
    player = { scaleFrame = 1.08, healthFormat = "custom" },
    target = { scaleFrame = 1.08, healthFormat = "custom" },
    focus = { scaleFrame = 1.08, healthFormat = "custom" },
    boss = { healthFormat = "custom" },
    general = { forceManaBarTexture = true, barTexture = "ElvUI Blank" },
} }
-- (12/10) en PvE ni EasyFrames ni Quartz: marcos de ElvUI y el casteo lo hace la WA de clase
PR.PvE.sv = {}

-- (1.0.2) xCT+ (solo PvE): solo el daño que hacés. Al cambiar de forma el druida
-- veía 6 líneas (buffs ganados y perdidos, energía y furia): sin buffs, combate,
-- reputación, vida o maná bajo, ni el daño y la curación que recibís, ni poder,
-- procs, botín y puntos de combo. Lo que sale: tu daño (golpes, hechizos, dots,
-- mascota) y los críticos aparte, sin curaciones. La fusión de spam (varios
-- golpes del mismo hechizo en una línea "x5") queda prendida.
-- secondaryFrame = 0: lo de un marco apagado no se pasa a otro.
-- (1.0.3, lo pidió) también: fallos (miss, dodge, parry, block, resist, inmune),
-- números abreviados (12.5K), golpes de menos de 300 escondidos (el filtro va
-- golpe por golpe antes de juntarlos: con 1000 se perdían los ticks de dots) y
-- "Interrumpido: X" cuando tu corte pega (el marco general solo con eso).
local function umbralXCT()
    local nivel = UnitLevel and UnitLevel("player") or 80
    return (nivel or 80) >= 80 and 300 or 0          -- subiendo de nivel se ve todo
end
PR.XCT = { addon = "xCT+", perfil = {
    showStartupText = false,
    frames = {
        general = { enabledFrame = true, secondaryFrame = 0, showInterrupts = true,
                    showDispells = false, showPartyKills = false, showBuffs = false, showDebuffs = false,
                    showLowManaHealth = false, showCombatState = false, showRepChanges = false, showHonorGains = false },
        damage = { enabledFrame = false, secondaryFrame = 0 },
        healing = { enabledFrame = false, secondaryFrame = 0 },
        power = { enabledFrame = false, secondaryFrame = 0 },
        procs = { enabledFrame = false, secondaryFrame = 0 },
        loot = { enabledFrame = false, secondaryFrame = 0 },
        class = { enabledFrame = false },
        outgoing = { enabledFrame = true, enableOutDmg = true, enablePetDmg = true, enableAutoAttack = true,
                     enableDotDmg = true, enableOutHeal = false, enableHots = false,
                     enableMisses = true, enableImmunes = true, megaDamage = true },
        critical = { enabledFrame = true, megaDamage = true },
    },
    spells = { enableMerger = true, formatAbbreviate = true },
    spellFilter = { filterOutgoingDamageValue = umbralXCT },
} }
PR.PvE.sv.xCTSavedDB = PR.XCT

-- (1.0.4) partes del preset que cambiaron: se ponen solas, sin volver a poner
-- todo el modo (que pisaría lo que acomodaste). Cada una una vez por personaje y
-- modo: pj.partes["PvP:gladius"] = versión. Las del preset (sv, placas, marcos)
-- en un personaje nuevo van con el preset entero (PR.marcar las da por puestas).
-- Las "siempre" (Compact y OmniCC) no son del preset: van en todos.
--   sv: ese addon con AceDB (se pone con P.ponerPendientes, con recarga)
--   placas: las placas de ElvUI del preset (ENEMY_PLAYER)
--   marcos: tu marco, el objetivo y el foco donde los pone el preset
--   compact: los marcos de tu equipo (PR.COMPACT: tamaño, colores y lugar)
--   omnicc: los números de los CDs (1.0.12: los de OmniCC en todo, apenas más chicos)
--   compactVida (1.0.5): la vida que le queda a cada uno en los marcos de tu equipo
--   compactAlto (1.0.6): solo el alto de los marcos de tu equipo (PR.COMPACT), sin moverlos
--   elv (1.0.9): un pedazo del perfil de ElvUI del modo (PR.AJUSTES_ELV[x.elv][modo])
--   bt (1.0.9): una barra de Bartender4 del preset (su namespace, por ejemplo MultiCast). Desde
--     la 1.0.13 puede ser una lista, y toma la forma a la vista o escondida que use el personaje
--   btApagar (1.0.13): barras de ActionBars a apagar (solo enabled = false)
--   btEscondidas (1.0.13): en PvP, si eligió escondidas, las barras 1 a 6 escondidas (sin moverlas)
--   mrt (1.0.9): los raid cooldowns de MRT (PR.MRT)
--   btBase (1.0.10): lo general de Bartender4 (PR.BT_BASE), en el perfil del modo
-- una = true: va una sola vez por personaje, no una por modo (pj.partes["*:id"])
PR.PARTES = {
    { id = "xct", v = 2, modos = { PvE = true }, sv = "xCTSavedDB" },
    { id = "gladius", v = 2, modos = { PvP = true }, sv = "GladiusDB" },          -- 1.0.6: a la izquierda y más grande
    { id = "placas", v = 1, modos = { PvE = true, PvP = true }, placas = true },
    { id = "marcos", v = 3, modos = { PvP = true }, marcos = true },     -- 1.0.13: el foco 18 más arriba
    { id = "compact", v = 2, modos = { PvP = true }, compact = true, siempre = true },
    { id = "omnicc", v = 2, modos = { PvE = true, PvP = true }, omnicc = true, siempre = true },   -- 1.0.12: como viene
    { id = "crfvida", v = 1, modos = { PvE = true, PvP = true }, compactVida = true, siempre = true, una = true },
    { id = "crfalto", v = 1, modos = { PvP = true }, compactAlto = true, siempre = true },
    -- (1.0.9) tooltip quieto y escondido en combate, maná y tus debuffs en PvE,
    -- totems arriba de las barras y raid cooldowns con color de clase
    { id = "tooltip", v = 1, modos = { PvE = true, PvP = true }, elv = "tooltip" },
    { id = "pve1", v = 1, modos = { PvE = true }, elv = "pve1" },
    { id = "totems", v = 1, modos = { PvE = true }, bt = "MultiCast" },
    { id = "mrt", v = 2, modos = { PvE = true }, mrt = true, siempre = true, una = true },   -- 1.0.11: en la esquina
    -- (1.0.10) fuera de rango, el botón entero rojo (no solo el número)
    { id = "rango", v = 1, modos = { PvE = true, PvP = true }, btBase = true, siempre = true },
    -- (1.0.13) barras 7 a 10 apagadas, posturas/mascota/totems sin colgar arriba del
    -- chat (y donde corresponde a la vista o escondidas), PvP escondidas si lo eligió,
    -- y sin los totems ni la experiencia de la mascota de ElvUI
    { id = "barras2", v = 1, modos = { PvE = true, PvP = true }, bt = { "StanceBar", "PetBar", "MultiCast" },
      btApagar = { 7, 8, 9 }, btEscondidas = true },   -- (1.0.25) la 10 ya no: es la de profesiones
    { id = "sueltas", v = 1, modos = { PvE = true, PvP = true }, elv = "sueltas" },
    { id = "pve2", v = 1, modos = { PvE = true }, elv = "pve2" },
    { id = "details", v = 2, modos = { PvE = true, PvP = true }, details = true, siempre = true },   -- 1.0.24: PvP también con curación
    -- (1.0.24) MinimapButtonFrame en una sola columna: crece para abajo, no para el costado
    { id = "mbf", v = 1, modos = { PvE = true, PvP = true }, mbf = true, siempre = true, una = true },
    -- (1.0.25) con Bartender escondidas: la 10 a la vista en el borde y las escondidas
    -- juntas a su izquierda (todas las barras de acción del preset, una vez)
    -- (1.0.28) v2: la 2 a la vista y las otras escondidas del todo (sin el mouse)
    { id = "barras3", v = 2, modos = { PvE = true, PvP = true }, bt = { "ActionBars" }, soloEscondidas = true },
    -- (1.0.26) el foco de PvE más grande y con retrato
    { id = "foco", v = 1, modos = { PvE = true }, elv = "foco" },
    -- (1.0.33) las auras del objetivo de PvE más grandes y los buffs de un enemigo a la vista
    { id = "objetivo", v = 1, modos = { PvE = true }, elv = "objetivo" },
}
-- (1.0.24) MinimapButtonFrame como lo puso él: los botones en una sola columna
PR.MBF = { columns_or_rows = 1, sort_by_rows = false }
-- (1.0.10) Bartender4: fuera de rango se pone rojo el botón entero, como en su
-- cuenta principal (con "hotkey" solo se ponía rojo el número del bind)
PR.BT_BASE = { outofrange = "button" }

-- Compact Raid Frames en PvP (1.0.4): lo tenía que acomodar a mano. Se pone en el
-- perfil de Compact que usa en PvP: tamaño de cada marco (como lo tenía en su
-- arena), color de clase, barra de maná, mascotas y borde, y el lugar: arriba a
-- la izquierda, debajo de tu marco (TOP 420 hasta TOP 760, LEFT 300, en unidades
-- de 1080 de alto, como lo guarda Compact). A la izquierda queda lugar para los
-- íconos de "Mi equipo" (hasta 8).
-- (1.0.6) los marcos un poco más altos: de 60 a 70 (las mascotas, la mitad). Con
-- 3 compañeros y 3 mascotas son 315 de los 340 que tiene de lugar.
PR.COMPACT = {
    opciones = { frameWidth = 145, frameHeight = 70, useClassColors = true, displayPowerBar = true,
                 displayPets = true, displayBorder = true, displayNonBossDebuffs = true },
    lugar = { "TOP", 420, "TOP", 760, "LEFT", 300 },
}

-- OmniCC (1.0.4): los números de los CDs le tapaban el ícono. Se achicaron (18 a
-- 14, sin agrandarse al final) y se apagaban en las alertas de Modos, que ponían su
-- propio tiempo abajo, en blanco.
-- (1.0.12) pidió OmniCC en todo y como viene (con sus colores y agrandándose al
-- final), apenas más chico si tapa el ícono entero: 16 (de fábrica 18) y "soon" y
-- "controlled" a 1,3 (de fábrica 1,5). Los colores quedan los de OmniCC. Las alertas
-- de Modos ya no traen su número: lo pone OmniCC. La regla y el tema de la 1.0.4 se sacan.
PR.OMNICC = {
    fontSize = 16,
    textStyles = { soon = { scale = 1.3 }, controlled = { scale = 1.3 } },
    temaViejo = "ModosSinNumeros", reglaVieja = "modos_wa_con_tiempo",
}
function PR.patronWA(id)
    local n = ("WeakAurasCooldown" .. id:lower():gsub(" ", "_")):gsub("([%%%-%.%+%*%?%[%]%^%$%(%)])", "%%%1")
    return "^" .. n
end

-- opciones del juego en los dos modos: texto de combate como Bypass (sin los
-- avisos propios en el centro: "<Trueshot Aura>", "fades", etc.)
PR.CVARS = { enableCombatText = "0" }
PR.PvE.cvars = {}
for k, v in pairs(PR.CVARS) do PR.PvE.cvars[k] = v; PR.PvP.cvars[k] = v end
PR.PvP.sv.EasyFramesDB = PR.EASYFRAMES

-- ------------------------------------------------------------ PvE con ElvUI (12/10)
-- PvE desde cero con lo mejor de MerfinUI: marcos de ElvUI de Merfin (tu marco y
-- el objetivo centrados abajo, la WA de tu clase entre los dos) y Cell para el
-- grupo. Cada uno con su parte privada y su perfil: lo de PvP no cambia.
local function copia(t)
    if type(t) ~= "table" then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = copia(v) end
    return r
end
PR.PvP.privado = copia(PR.PvE.privado)
PR.PvP.ElvDB = copia(PR.PvE.ElvDB)
PR.PvP.ElvDB.general.totems = { enable = false }       -- (1.0.13) los totems de ElvUI quedaban sueltos a la izquierda
-- (1.0.13) PvP con barras a la vista (las de Bypass, como hasta ahora) o escondidas:
-- no se ven nunca y el mouse las atraviesa, los binds andan igual y los CDs los
-- muestra Mis CDs. Escondidas solo para quien lo eligió (pj.barrasVista).
PR.PvP.Bartender4Visible = PR.PvP.Bartender4
PR.PvP.Bartender4 = copia(PR.PvP.Bartender4Visible)
for i = 1, 6 do escondida(PR.PvP.Bartender4.ActionBars.actionbars[i]) end
-- (1.0.25) escondidas como en PvE: juntas en columnas al costado derecho.
-- (1.0.28) la 2 a la vista en el borde (profesiones, monturas, mascotas) y las otras a
-- su izquierda, escondidas del todo
for i, col in pairs({ [2] = 1, [1] = 2, [3] = 3, [4] = 4, [5] = 5, [6] = 6 }) do
    local b = PR.PvP.Bartender4.ActionBars.actionbars[i]
    b.position, b.rows = costado(col), 12
end
aLaVista(PR.PvP.Bartender4.ActionBars.actionbars[2])
PR.PvP.Bartender4.ActionBars.actionbars[10] = { enabled = false }
PR.PvE.privado.unitframe = { enable = true }
PR.PvE.ElvDB.general.totems = { enable = false }       -- los totems los muestra la WA del chamán
-- dónde van los marcos según el rol (los de Merfin para 1080p). Tank y DPS: tu
-- marco y el objetivo a los costados de la WA de clase. Heal: más arriba, a los
-- costados del Cell (que va abajo al medio en 5 columnas) y con el maná, los CDs
-- y el casteo de la WA de clase arriba del Cell. Casteo del objetivo y del foco
-- justo debajo de su marco.
-- (1.0.13) marcos un 20% más chicos (217x53, objetivo del objetivo 64, foco 120): el
-- borde de adentro queda donde estaba (DPS a 147,5 del medio, heal a 252) y todo
-- lo demás se corre hacia adentro sin encimarse.
-- (1.0.14) a lo alto: el borde de abajo de tu marco y del objetivo a la altura del
-- piso de la WA de clase (lo de abajo de su fila de íconos grande), como lo marcó
-- él (18/10, "el piso de la WA donde está el pisito azul"). El piso cambia con la
-- clase (y en el chamán con la rama): lo da NS.PISOS_WA (PisosWA.lua, sacado de las
-- WA) y Rol.lua corre todo el grupo (marcos, objetivo del objetivo, foco, mascota y
-- casteos) lo que haga falta. Acá van para un piso de 275 en DPS y 376 en heal.
PR.MOVERS_PISO = { DPS = 275, Heal = 376 }
PR.MOVERS = {
    DPS = {
        ElvUF_PlayerMover = "BOTTOM,ElvUIParent,BOTTOM,-256,275",
        ElvUF_TargetMover = "BOTTOM,ElvUIParent,BOTTOM,256,275",
        ElvUF_TargetTargetMover = "BOTTOM,ElvUIParent,BOTTOM,404,275",
        ElvUF_FocusMover = "BOTTOM,ElvUIParent,BOTTOM,524,275",
        ElvUF_PetMover = "BOTTOM,ElvUIParent,BOTTOM,-258,227",
        ElvUF_TargetCastbarMover = "BOTTOM,ElvUIParent,BOTTOM,229.5,255",
        ElvUF_FocusCastbarMover = "BOTTOM,ElvUIParent,BOTTOM,524,253",
        ElvUF_PlayerCastbarMover = "BOTTOM,ElvUIParent,BOTTOM,0,220",
        BossHeaderMover = "TOPRIGHT,ElvUIParent,TOPRIGHT,-351,-411",
    },
    Heal = {
        ElvUF_PlayerMover = "BOTTOM,ElvUIParent,BOTTOM,-360.5,376",
        ElvUF_TargetMover = "BOTTOM,ElvUIParent,BOTTOM,360.5,376",
        ElvUF_TargetTargetMover = "BOTTOM,ElvUIParent,BOTTOM,501,376",
        -- (1.0.26) el foco (ahora 160x36) debajo del objetivo, a la derecha del Cell: a la
        -- derecha del objetivo del objetivo no entra sin tocar las barras del costado
        ElvUF_FocusMover = "BOTTOM,ElvUIParent,BOTTOM,400,300",
        ElvUF_PetMover = "BOTTOM,ElvUIParent,BOTTOM,501,357",
        ElvUF_TargetCastbarMover = "BOTTOM,ElvUIParent,BOTTOM,334,356",
        ElvUF_FocusCastbarMover = "BOTTOM,ElvUIParent,BOTTOM,400,280",
        ElvUF_PlayerCastbarMover = "BOTTOM,ElvUIParent,BOTTOM,0,74",
        -- (1.0.13) 24 más a la derecha: con 3 filas de buffs del objetivo se tocaban
        BossHeaderMover = "TOPRIGHT,ElvUIParent,TOPRIGHT,-327,-411",
    },
}
PR.MOVERS.Tank = PR.MOVERS.DPS
PR.PvE.ElvDB.movers = copia(PR.MOVERS.DPS)

-- (1.0.9) lo que pidió jugando PvE (17/10, captura en Pit of Saron):
--   tooltip: quieto arriba a la izquierda (en PvE debajo de los raid cooldowns de
--   MRT, que llegan hasta unos 255) y escondido en combate, en los dos modos
--   maná: tu marco de PvE con su barra (Merfin la saca porque la muestra la WA de clase)
--   tus debuffs: en el marco del objetivo (Merfin solo los mostraba en amigos) y en
--   las placas de los enemigos de PvE, arriba del nombre como en PvP
PR.TOOLTIP = { cursorAnchor = false, visibility = { combat = true, combatOverride = "ALL" } }
PR.TOOLTIP_LUGAR = { PvE = "TOPLEFT,ElvUIParent,TOPLEFT,4,-262", PvP = "TOPLEFT,ElvUIParent,TOPLEFT,4,-4" }
-- (1.0.13) un 20% más chicos (pidió): tu marco y el objetivo de 271x66 a 217x53 con
-- retrato de 53, foco, objetivo del objetivo y mascota igual, casteos y auras del
-- objetivo también. En tu marco tu nombre (arriba a la izquierda) y tu recurso
-- (maná, energía, furia o poder rúnico) sobre su barra.
local PR_AURA_OBJETIVO = 26
PR.UF_AJUSTES = { units = {
    player = { width = 217, height = 53, portrait = { width = 53 },
               power = { enable = true, detachFromFrame = false, height = 10 },
               customTexts = { UnitName = { enable = true, justifyH = "LEFT", xOffset = 4, yOffset = 10, size = 13 },
                               UnitPower = { enable = true, size = 12 } } },
    -- los buffs y tus debuffs iban los dos arriba a la derecha del objetivo: en un amigo
    -- con buffs y debuffs se encimaban. Ahora tus debuffs van arriba de los buffs (sin
    -- buffs, en su lugar)
    -- (1.0.33) las auras del objetivo más grandes (pidió, 25/10: "se ven muy chiquitas"):
    -- de 18 a 26 (8 por fila ocupan 201 de los 217 del marco). Y los buffs de un enemigo
    -- a la vista (Merfin solo mostraba los de un amigo): ahí se marcan los de Magia
    -- (Disipables.lua)
    target = { width = 217, height = 53, portrait = { width = 53 }, castbar = { width = 164, height = 16 },
               smartAuraPosition = "FLUID_DEBUFFS_ON_BUFFS",
               buffs = { sizeOverride = PR_AURA_OBJETIVO, priority = "Blacklist,Personal,nonPersonal" },
               debuffs = { enable = true, sizeOverride = PR_AURA_OBJETIVO,
        priority = "Blacklist,Personal,Friendly:RaidDebuffs,Friendly:CCDebuffs,Friendly:Dispellable,Friendly:notCastByUnit,Friendly:CastByNPC" } },
    -- (1.0.26) el foco más grande y con retrato (lo pidió, 25/10: "muy chiquito y sin
    -- marco/retrato"): 160x36 con retrato de 36, sin el número de recurso (se encimaba
    -- con la vida en la barrita de 6). El nombre arriba y la vida en % como antes.
    focus = { width = 160, height = 36, castbar = { width = 160 },
              portrait = { enable = true, overlay = false, fullOverlay = false, style = "3D", width = 36 },
              power = { height = 6 }, customTexts = { UnitPower = { enable = false } } },
    targettarget = { width = 64, height = 14 },
    pet = { width = 64, height = 16 },
} }
PR.PLACAS_NPC = { debuffs = copia(PR.PvE.ElvDB.nameplates.units.ENEMY_PLAYER.debuffs) }
PR.PLACAS_NPC.debuffs.filters = { priority = "Blacklist,blockNoDuration,Personal" }
-- lo que ponen las partes "tooltip" y "pve1" en los personajes que ya tienen la UI
PR.AJUSTES_ELV = {
    tooltip = {
        PvE = { tooltip = PR.TOOLTIP, movers = { ElvTooltipMover = PR.TOOLTIP_LUGAR.PvE } },
        PvP = { tooltip = PR.TOOLTIP, movers = { ElvTooltipMover = PR.TOOLTIP_LUGAR.PvP } },
    },
    pve1 = { PvE = { unitframe = PR.UF_AJUSTES, nameplates = { units = { ENEMY_NPC = PR.PLACAS_NPC } } } },
    pve2 = { PvE = { unitframe = PR.UF_AJUSTES } },          -- (1.0.13) marcos más chicos, nombre y recurso
    foco = { PvE = { unitframe = { units = { focus = PR.UF_AJUSTES.units.focus } } } },   -- (1.0.26)
    -- (1.0.33) solo las auras del objetivo (tamaño y los buffs de un enemigo)
    objetivo = { PvE = { unitframe = { units = { target = {
        buffs = { sizeOverride = PR.UF_AJUSTES.units.target.buffs.sizeOverride,
                  priority = PR.UF_AJUSTES.units.target.buffs.priority },
        debuffs = { sizeOverride = PR.UF_AJUSTES.units.target.debuffs.sizeOverride } } } } } },
    -- (1.0.13) sin los totems de ElvUI (PvE ya los tenía apagados) ni la experiencia de la mascota
    sueltas = {
        PvE = { general = { totems = { enable = false } }, databars = { petExperience = { enable = false } } },
        PvP = { general = { totems = { enable = false } }, databars = { petExperience = { enable = false } } },
    },
}
-- los marcos de PvE los arma PresetPvE.lua (después de este archivo): los ajustes
-- se le suman ahí, con esto
function PR.ajustarUF()
    if type(PR.PvE.ElvDB.unitframe) == "table" then PR.mezclar(PR.PvE.ElvDB.unitframe, PR.UF_AJUSTES) end
end

-- (1.0.9) raid cooldowns de MRT: que se vea claro qué está listo. Barra con el
-- color de la clase de cada uno cuando está listo, y la línea apagada (con el ícono
-- gris y el tiempo) cuando está en CD. Los listos primero. VMRT es de toda la
-- cuenta: se pone en todas las columnas y en la general (la 11).
PR.MRT = { textureClassBackground = true, textureAlphaBackground = 0.7, textureAlphaCooldown = 0.35,
           iconGray = true, methodsSortByAvailability = true }
-- (1.0.11) y fijos arriba a la izquierda, en la esquina (el tooltip de PvE va debajo)
PR.MRT_LUGAR = { x = 4, y = -4 }

-- (1.0.13) Details: abajo a la derecha, a la izquierda de las columnas de barras y
-- arriba del menú y las bolsas (donde lo puso él, 18/10: 216 del borde derecho,
-- 48 de abajo, 241 de ancho. 212 para no tocar las barras de Blizzard a 1920 de
-- ancho). PvP: una ventana de daño. PvE: daño arriba y curación abajo (con el
-- título, 20, terminan en 241: debajo del casteo del foco de PvE, que en el piso
-- más bajo de la WA de clase empieza en 243). Atributo 1 = daño, 2 = curación.
-- (1.0.24) PvP igual que PvE (lo pidió, 25/10): siempre daño y curación, del mismo
-- tamaño, abajo a la derecha.
PR.DETAILS = {
    margenDer = 212, abajo = 46, ancho = 241, titulo = 20, separacion = 1,
    PvP = { { atributo = 1, alto = 77 }, { atributo = 2, alto = 77 } },
    -- (1.0.14) 77 y desde 46: con los marcos en el piso de la WA (sacerdote sombras y
    -- chamán mejora, 265) el casteo del foco baja hasta 243
    PvE = { { atributo = 1, alto = 77 }, { atributo = 2, alto = 77 } },
}
-- Mis CDs PvE: altura de la primera fila (desde el centro de la pantalla). DPS/Tank:
-- debajo de la WA de clase. Heal: debajo del Cell (más bajo desde la 0.9.2, 44 de alto).
-- (1.0.16) Heal un poco más abajo (las dos filas de 37 a 120) para que el Cell de heal,
-- más grande, termine en 122.
-- (1.0.19) Heal al borde de abajo (las dos filas de 3 a 86): el Cell de heal llega a 87.
PR.MISCDS_Y = { DPS = -375, Tank = -375, Heal = -474 }

-- copia "de" adentro de "a" (sin borrar lo que no está en "de")
function PR.mezclar(a, de)
    for k, v in pairs(de) do
        if type(v) == "table" then
            if type(a[k]) ~= "table" then a[k] = {} end
            PR.mezclar(a[k], v)
        elseif type(v) == "function" then
            a[k] = v()              -- valores que dependen de la pantalla
        else
            a[k] = v
        end
    end
    return a
end
-- (1.0.9) los ajustes del 17/10 también en el preset (personajes nuevos)
for m, t in pairs(PR.AJUSTES_ELV.tooltip) do PR.mezclar(PR[m].ElvDB, t) end
PR.mezclar(PR.PvE.ElvDB.nameplates.units.ENEMY_NPC, PR.PLACAS_NPC)

-- ¿hay que aplicar el preset del modo m?
function PR.falta(m)
    local pj = NS.pj
    if not (pj and PR[m] and PR.VERSION[m]) then return false end
    pj.presets = pj.presets or {}
    return pj.presets[m] ~= PR.VERSION[m]
end

-- (1.0.5) dónde se anota una parte: por modo, o una sola vez si es "una"
function PR.clave(m, x)
    return (x.una and "*" or m) .. ":" .. x.id
end

function PR.marcar(m)
    NS.pj.presets = NS.pj.presets or {}
    NS.pj.presets[m] = PR.VERSION[m]
    -- las partes que van con el preset quedan al día (no se vuelven a poner sueltas)
    NS.pj.partes = NS.pj.partes or {}
    for _, x in ipairs(PR.PARTES) do
        if x.modos[m] and not x.siempre and (not x.sv or (PR[m].sv and PR[m].sv[x.sv])) then
            NS.pj.partes[PR.clave(m, x)] = x.v
        end
    end
end

-- (1.0.4) las partes del modo m que faltan poner en este personaje
function PR.partesNuevas(m)
    local pj = NS.pj
    local r = {}
    if not (pj and m and PR[m]) then return r end
    pj.partes = pj.partes or {}
    -- (1.0.2 y 1.0.3 anotaban solo xCT+ en pj.svVersion)
    if pj.svVersion and pj.svVersion.xCTSavedDB and not pj.partes["PvE:xct"] then
        pj.partes["PvE:xct"] = pj.svVersion.xCTSavedDB
    end
    local puesto = pj.presets and pj.presets[m]
    for _, x in ipairs(PR.PARTES) do
        if x.modos[m] and (puesto or x.siempre) and (pj.partes[PR.clave(m, x)] or 0) < x.v then
            r[#r + 1] = x
        end
    end
    return r
end

function PR.parteHecha(m, x)
    NS.pj.partes = NS.pj.partes or {}
    NS.pj.partes[PR.clave(m, x)] = x.v
end
