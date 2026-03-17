codec = {}

local function b91(v)
    local s = ""
    for i = 1, 4 do
        s = string.char(v % 91 + 33) .. s
        v = math.floor(v / 91)
    end
    return s
end

local T_RAW = 32 + 16 + 8 + 4

-- Base91 压缩位置帧（含速度/航向/类型字节）
function codec.pos(lat, lon, speed, course)
    local y = math.floor(380926 * (90 - lat))
    local x = math.floor(190463 * (180 + lon))

    local c = 0
    if course and course > 0 then
        c = math.floor((course + 2) / 4) % 91
    end

    local s = 0
    if speed and speed > 0 then
        s = math.floor(math.log(speed + 1) / math.log(1.08) + 0.5) % 91
    end

    return b91(y) .. b91(x)
        .. string.char(c + 33)
        .. string.char(s + 33)
        .. string.char(T_RAW + 33)
end

-- 遥测注释字段，附加在位置帧注释区
function codec.tele(seq, batt, temp, volt)
    return string.format(" S%03d B%d%% T%dC V%dmV", seq, batt, temp, volt)
end
