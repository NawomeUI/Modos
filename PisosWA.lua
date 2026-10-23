-- Modos · el piso de la WA de clase (lo de abajo de su fila de íconos grande) en
-- cada clase, por rol (DPS/Tank o Heal) y rama de talentos cuando cambia. Ahí va el
-- borde de abajo de tu marco y el del objetivo de ElvUI en PvE (Rol.lua).
-- Lo arma herramientas/pisos_wa.lua: no editar a mano.

local _, NS = ...

NS.PISOS_WA = {
    DPS = {
        DEATHKNIGHT = 273,
        DRUID = 267,
        HUNTER = 277,
        MAGE = 275,
        PALADIN = 277,
        PRIEST = 265,
        ROGUE = 267,
        SHAMAN = { [1] = 273, [2] = 265 },
        WARLOCK = 273,
        WARRIOR = 278,
    },
    Heal = {
        DRUID = 378,
        PALADIN = 378,
        PRIEST = 379,
        SHAMAN = 379,
    },
}
