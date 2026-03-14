function M.read()
    local volt = adc.read(0) -- 读取电压
    local temp = mcu.temp()
    local batt = math.floor((volt - 3300) / 900 * 100) -- 电量百分比计算
    return batt, temp, volt -- 返回电量，温度与电压值
end

function M.frame(codec)
    local b, t, v = M.read()
    local imei = mobile.imei() or "UNKNOWN" -- 获取IMEI码
    local rssi = mobile.rssi() or 0        -- 信号强度
    local sat_used, sat_total = gps.sats() -- 当前卫星数据
    -- 将数据封装为APRS Telemetry字符串
    return codec.tele("seq", b, t, v) ..
        string.format(" IMEI:%s RSSI:%ddBm Sat:%d/%d", imei, rssi, sat_used, sat_total)
end