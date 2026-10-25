# Modos

Una UI para PvE y PvP en el mismo personaje, para WoW 3.3.5a. Cambiás de modo con un clic y Modos prende los addons, arma la interfaz, pone tus barras, binds y WeakAuras de ese modo. Cada modo recuerda lo suyo.

## Descarga

Bajá **Modos_Pack_Completo.zip** desde [Releases](https://github.com/NawomeUI/Modos/releases/latest). Ese zip trae Modos y todos los addons que usa, listos para instalar.

No uses el botón verde "Code → Download ZIP": genera una carpeta "Modos-main" que WoW no reconoce.

## Instalación (con el juego cerrado)

1. Descomprimí **Modos_Pack_Completo.zip** directo en `World of Warcraft\Interface\AddOns`. Adentro están las carpetas de todos los addons (PvE y PvP juntos, Modos prende los de cada modo solo). Si pregunta si reemplazar, decile que sí. No borres las carpetas que empiezan con `Blizzard_` (son del juego).
2. El archivo LEEME queda en AddOns. No molesta, lo podés borrar.
3. Entrá al juego.

## Primera vez en el juego

A los pocos segundos se abre "Modos - primeros pasos". De arriba a abajo:

1. **Addons:** te avisa si falta alguno.
2. **Modo:** tocá PvE o PvP, el modo en que estás ahora.
3. **Barras:** con Bartender o con las de Blizzard, a la vista o escondidas.
4. **Rol en PvE:** tank, DPS o heal (uno por talento).
5. **WeakAuras:** se instalan solas con cada personaje, también la de su clase (las 10 clases). No hay que importar nada. Si borrás alguna: `/modos auras reinstalar`.

Al final, Recargar. Listo.

Después cambiás de modo con la barrita de Modos o con un bind en Key Bindings, sección Modos.

### Barras escondidas

Con las barras escondidas (Bartender o Blizzard) queda una a la vista en el borde derecho para profesiones, monturas y mascotas. Con Bartender es la 2 (ninguna postura la cambia) y las escondidas quedan juntas a su izquierda. Con las de Blizzard es la de la derecha del todo. Las escondidas no aparecen ni con el mouse: para verlas, `/modos barras ver` o el botón Barras de la ventana de Modos.

### Antes de armar Mis CDs: primero tus binds

Mis CDs muestra cada hechizo con su bind, y el bind lo saca del botón de la barra donde está ese hechizo. Así que primero poné tus hechizos en las barras y tus binds, y después elegí Mis CDs (`/modos cds`). Los hechizos de tu mascota (de cualquier clase) aparecen en la lista como "Mascota: ..." mientras la tengas afuera, con el bind de la barra de la mascota.

Si tus barras están escondidas, `/modos barras ver` las pone todas a la vista (y se pueden tocar) para acomodar hechizos y binds. Cuando termines, `/modos barras esconder` las deja como estaban. También con el botón "Ver todas para bindear" de `/modos barras`.

## Comandos

| Comando | Qué hace |
|---|---|
| `/modos` | Ayuda |
| `/modos instalar` | Abre de nuevo los primeros pasos |
| `/modos barras` | Barras con o sin Bartender, a la vista o escondidas |
| `/modos barras ver` | Todas las barras a la vista, para poner binds |
| `/modos barras esconder` | Las deja como estaban |
| `/modos rol` | Rol de PvE del talento en uso |
| `/modos cds` | Qué hechizos, hechizos de tu mascota y abalorios ves en Mis CDs |
| `/modos cds guardar <nombre>` | Guarda tu lista de Mis CDs con un nombre (como ABS) |
| `/modos cds cargar <nombre>` | La vuelve a poner (sirve en una macro) |
| `/modos cds perfiles` | Los perfiles de Mis CDs de tu clase |
| `/modos addons` | Qué addons van en cada modo |
| `/modos auras` | Qué WeakAuras van con cada modo |
| `/modos auras reinstalar` | Vuelve a poner las WeakAuras que borraste |
| `/modos escala` | Deja libre la escala de la interfaz (Modos usa 1080 de alto) |
| `/tabpvp` | En arena y BG, Tab marca solo jugadores (prendido de fábrica) |

## Qué trae el pack

**Los dos modos:** Modos, ElvUI 6.09 (solo placas, tooltip y en PvE los marcos), WeakAuras 5.22 (NoM0Re), OmniCC, Bartender4, Bagnon, Details, MinimapButtonFrame, Mapster, !ClassColors, BugSack, Talented, Action Bar Saver (ABS), ExtrasUI, ItemLevelSimple, TabPvP, GearScoreLite 3x04, CombatLogFix, AtlasLoot 5.11.04, All Stats 1.1 (todas las estadísticas al lado del personaje).

**PvE:** MerfinPlus 2.83, Cell r279, DBM, MRT 5.1.4, xCT+ 3.7.1, PallyPower 3.2.21 (versión Improved, anda en Warmane).

**PvP:** Gladius 1.2.0, EasyFrames, Quartz 3.0.3.1, Compact Raid Frames 1.14 con !!!ClassicAPI 1.28 y Enhanced Raid Frames 1.8, SoundAlerter (corregido).

Cada addon del pack es de su autor. En este repositorio está solo el código de Modos.

## Notas

- Pensado para 1920x1080. En otras pantallas 16:9 (1600x900, 1366x768, 1440p, 4K) se ve igual (Modos fija la escala). En 16:10 (1440x900, 1680x1050) todavía no: algunas cosas se pisan.
- Son solo addons: no usa parches del cliente (como Awesome WotLK), así que sirve en servidores que no los permiten, como Warmane.
