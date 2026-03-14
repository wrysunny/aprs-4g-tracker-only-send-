local M = {}

-------------------------------------------------
-- BASE91
-------------------------------------------------

local function b91(v)
    local s = ""

    for i = 1, 4 do
        s = string.char(v % 91 + 33) .. s
        v = math.floor(v / 91)
    end

    return s
end

-------------------------------------------------
-- COMPRESSED POSITION
-------------------------------------------------

function M.pos(lat, lon)
    local y = math.floor(380926 * (90 - lat))
    local x = math.floor(190463 * (180 + lon))

    return b91(y) .. b91(x)
end

-------------------------------------------------
-- MESSAGE
-------------------------------------------------

function M.msg(src, dst, text)
    return ":" ..
        string.format("%-9s", dst) ..
        ":" .. text
end

-------------------------------------------------
-- TELEMETRY
-------------------------------------------------

function M.tele(seq, b, t, v)
    return "T#" .. string.format("%03d", seq) ..
        "," .. b ..
        "," .. t ..
        "," .. v ..
        ",0,0,00000000"
end

return M
