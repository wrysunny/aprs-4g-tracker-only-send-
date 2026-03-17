msgTab = {}

local beaconTime = 0

-- 将位置点转换为 Base91 压缩 APRS 帧（用户的编码方式）
local function point2msg(pt)
    local pos = codec.pos(pt.lat, pt.lon, pt.speed, pt.course)

    local comment = mycfg.COMMENT or ""

    -- 附加遥测（电压/温度）
    if tostring(mycfg.ADD_VOLTAGE) == "true" then
        comment = comment .. tele.frame()
    end

    return string.format("%s>APRS,%s:!%s%s\r\n",
        sourceCall,
        mycfg.PATH or "TCPIP*",
        pos,
        comment)
end

sys.taskInit(function()
    sys.waitUntil("CFGLOADED")

    -- 周期性状态信标（纯文本，非位置）
    local beaconMsg = string.format("%s>APRS:>%s\r\n", sourceCall, mycfg.BEACON)

    while true do
        -- 状态信标定时插入
        if mycfg.BEACON_INTERVAL ~= 0 and
           os.time() - beaconTime >= mycfg.BEACON_INTERVAL * 60 then
            beaconTime = os.time()
            table.insert(msgTab, beaconMsg)
        end

        -- 位置点队列消费
        if pointTab and #pointTab > 0 then
            table.insert(msgTab, point2msg(pointTab[1]))
            table.remove(pointTab, 1)
        end

        sys.wait(100)
    end
end)
