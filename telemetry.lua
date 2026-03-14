local M = {}
-- 【修复】ADC 必须先 open，否则读 nil/乱码
adc.open(0)
local seq = 0
function M.read()
    local volt = adc.read(0)
    local temp = mcu.temp()
    local batt = math.floor((volt - 3300) / 900 * 100)
    return batt, temp, volt
end

function M.frame(codec)
    seq = (seq + 1) % 999
    local b, t, v = M.read()
    return codec.tele(seq, b, t, v)
end

return M
