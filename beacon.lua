beacon = {} -- 全局变量 其他程序要读取

local function getTemperatureCb(temp)
    log.info("Temperature Update:", temp)
    -- 更新全局变量，这样其他程序读取 beacon.temp 就是最新的了
    beacon.temp = temp 
end
sys.timerLoopStart(misc.getTemperature, 5000, getTemperatureCb)

local function Devicebeacon()
    if not GpsIsReady() then
        return
    end
    beacon.vbatt = misc.getVbatt() / 1000               -- 电池电压(V)
    --beacon.temp = misc.getTemperature()                 -- mcu温度(℃) 使用回调
    beacon.model = rtos.get_version()                   -- 模块型号
    beacon.imei = "*" .. string.sub(misc.getImei(), -4) -- imei 串号
    beacon.rssi = 2 * net.getRssi() - 113               -- 信号

    return beacon
end

local function Gpsbeacon()
    if not GpsIsReady() then
        --log.warn("beacon", "GPS 尚未定位，跳过本次 GPS 采集")
        return
    end
    local loc = gpsZkw.getLocation("DEGREE_MINUTE")  -- 返回{lngType="E",lng="12128.44954",latType="N",lat="3114.50931"}
    if not loc or not loc.lat or not loc.lng then
        return  -- 数据不完整时直接返回，保护程序
    end
    log.info("beacon", "GPS定位成功：纬度="..loc.lat, "经度="..loc.lng)

    beacon.lat = string.format("%07.2f", tonumber(loc.lat)) .. loc.latType  -- 纬度，例如 "3112.34N"
    beacon.long = string.format("%08.2f", tonumber(loc.lng)) .. loc.lngType -- 经度，例如 "12112.34E"
    beacon.speed_kmh, beacon.spd = gpsZkw.getSpeed()    -- 海里/h                                   -- 速度 (第一个参数km/h 第二个参数 节)
    beacon.sat = gpsZkw.getViewedSateCnt()                                  -- 卫星数
    beacon.satUsed = gpsZkw.getUsedSateCnt()                                -- 参与定位的卫星数
    beacon.alt = math.floor(gpsZkw.getAltitude() * 3.28084 + 0.5)           -- 海拔 (m) 转换为英尺ft
    beacon.course = gpsZkw.getCourse()                                      -- 方向角 (°)

    return beacon
end

-- 一次性获取完整信标数据
function GetFullBeacon()
    -- 设备刚开机有些数据拿不到，要等会
    Devicebeacon()
    Gpsbeacon()
    --return beacon
end

-- 定时上报任务：每 1 秒采集并打印一次
sys.taskInit(function()
    -- 开机后先等设备数据稳定（GSM 注网等需要几秒）
    sys.wait(10000)
    while true do
        GetFullBeacon()
        --log.info("beacon:", beacon)
        if type(DynamicRate) == "function" and GpsIsReady() then
            DynamicRate()
        end
        sys.wait(3000)
    end
end)
