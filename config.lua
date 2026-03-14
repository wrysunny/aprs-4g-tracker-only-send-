CONFIG_FILE = "/tracker_cfg.json"

local json = require("json")

CONFIG = {
    CALLSIGN = "BG7ABC",
    SSID = 9,
    PASSCODE = "12345",

    APRS_SERVER = "rotate.aprs2.net",
    APRS_PORT = 14580,

    PATH = "WIDE1-1,WIDE2-1",

    SYMBOL_TABLE = "/",
    SYMBOL = ">",

    SMART_FAST = 70,
    SMART_SLOW = 5,
    SMART_TURN = 28,

    BEACON_FAST = 30,
    BEACON_SLOW = 180,
    COMMENT = "Air820 APRS Tracker"
}

function cfg_load()
    local f = io.open(CONFIG_FILE)

    if not f then return end

    local d = f:read("*a")
    f:close()

    local j = json.decode(d)

    if j then CONFIG = j end
end

function cfg_save()
    local f = io.open(CONFIG_FILE, "w+")

    if not f then return end

    f:write(json.encode(CONFIG))
    f:close()
end

cfg_load()

return CONFIG
