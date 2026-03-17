tele = {}

local seq = 0

function tele.read()
    -- adc.read() 返回两个值：(原始值, 换算值)
    -- CH_VBAT 换算值单位 mV；CH_CPU 换算值单位 0.001°C
    adc.open(adc.CH_VBAT)
    local _, volt = adc.read(adc.CH_VBAT)
    adc.close(adc.CH_VBAT)

    adc.open(adc.CH_CPU)
    local _, temp_raw = adc.read(adc.CH_CPU)
    adc.close(adc.CH_CPU)

    local temp = math.floor((temp_raw or 0) / 1000)

    -- 3300mV = 0%，4200mV = 100%
    local batt = math.floor((volt - 3300) / 900 * 100)
    batt = math.max(0, math.min(100, batt))

    return batt, temp, volt
end

function tele.frame()
    seq = (seq + 1) % 1000

    local b, t, v = tele.read()

    local imei  = string.sub(misc.getImei(), -4, -1) or "0000"
    local rssi  = net.getRssi() or 0
    local used, total = gpsGetSats()

    return codec.tele(seq, b, t, v) ..
        string.format(" IMEI:%s RSSI:%d Sat:%d/%d", imei, rssi, used, total)
end
