-- 格式：CALL>APLUA2,TCPIP*:@DDHHMMz纬度/经度[CSE/SPD/A=ALT 注释
function BuildBeaconPacket()
    local utc = gpsZkw.getUtcTime()
    local ts  = "000000"
    if utc then
        ts = string.format("%02d%02d%02d", utc.hour, utc.min, utc.sec)
    end
    local cse, spd = "000", "000"
    cse = string.format("%03d", math.floor(beacon.course or 0))
    spd = string.format("%03d", math.floor(beacon.spd or 0))

    local altStr = ""
    altStr = string.format("/A=%06d", beacon.alt or 0)

    local comment = ""
    -- 静态注释
    comment = config.beacon_comment     -- "Air820UG APRS Tracker, Power by wrysunny."
    -- 动态追加：电压 / 信号 / 卫星数
    comment = comment .. string.format(
        "[model:%s Temp:%.1f℃ imei:%s RSSI:%ddBm Batt:%.1fV Sat:%d/%d]",
        beacon.model or "Air820UG",
        beacon.temp or 0.0,
        beacon.imei or "*0000",
        beacon.rssi or -50,
        beacon.vbatt or 4.2,
        beacon.satUsed or 0,
        beacon.sat or 0
    )

    local posInfo = string.format(
        "@%sz%s%s%s%s%s/%s%s %s",
        ts,
        beacon.lat or "0000.00N",
        config.symbol_table,
        beacon.long or "00000.00E",
        config.symbol_symbol,
        cse, spd,
        altStr,
        comment
    )
    local CALLSIGN = config.CALL .. "-" .. config.SSID
    return string.format("%s>APLUA2,TCPIP*:%s\r\n", CALLSIGN, posInfo)
end

-- sys.publish("APRS_MSG")
