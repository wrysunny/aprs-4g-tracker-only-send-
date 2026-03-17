pointTab = {}

-- 当前 GPS 状态（供 smartbeacon 和 telemetry 读取）
gps_data = {
    valid  = false,
    lat    = 0,
    lon    = 0,
    speed  = 0,   -- 单位：节
    course = 0,
}

local gpsLib, agpsLib

-- 未定位/定位丢失超过此秒数则休眠 GPS，等待 autoGPS 重新初始化
local GPS_TIMEOUT = 600

-- 供 telemetry.lua 调用，避免直接依赖全局 gps 变量
function gpsGetSats()
    if not gpsLib then return 0, 0 end
    return gpsLib.getUsedSateCnt() or 0, gpsLib.getViewedSateCnt() or 0
end

local function gpsProcess()
    if not gpsLib or not gpsLib.isFix() then
        gps_data.valid = false
        return false   -- 未定位
    end

    local tLoc = gpsLib.getLocation("DEGREE_MINUTE")

    local timeLocal = os.time() - 8 * 60 * 60
    local timeGPS   = os.time(gpsLib.getUtcTime())
    local t = math.floor(math.abs(timeLocal - timeGPS)) < 10 and timeLocal or timeGPS

    local lat = tonumber(tLoc.lat)
    local lon = tonumber(tLoc.lng)
    if tLoc.latType == 'S' then lat = -lat end
    if tLoc.lngType == 'W' then lon = -lon end

    local spd  = tonumber(gpsLib.getOrgSpeed()) or 0
    local cour = gpsLib.getCourse()             or 0
    local alt  = (gpsLib.getAltitude() or 0) * 3.2808399

    -- 更新全局状态
    gps_data.valid  = true
    gps_data.lat    = lat
    gps_data.lon    = lon
    gps_data.speed  = spd
    gps_data.course = cour

    -- SmartBeacon 决策：是否将此点放入发送队列
    if smart.should(gps_data) then
        table.insert(pointTab, {
            time    = t,
            lat     = lat,
            lon     = lon,
            speed   = spd,
            course  = cour,
            alt     = alt,
            satuse  = gpsLib.getUsedSateCnt()  or 0,
            satview = gpsLib.getViewedSateCnt() or 0,
        })
        smart.update(gps_data)
        log.info("POS", string.format("入队 lat=%.4f lon=%.4f spd=%.1f cour=%d",
            lat, lon, spd, cour))
    end

    return true   -- 已定位
end

-- GPS 休眠：调用 unInit 并通知 autoGPS 重新走自适应流程
local function gpsSleep()
    log.warn("GPS", "长时间未定位，关闭 GPS 等待重启")
    gps_data.valid = false
    if type(gpsLib) == "table" and type(gpsLib.unInit) == "function" then
        gpsLib.unInit()
    end
    gpsLib = nil
    sys.publish("GPS_WORK_ABNORMAL_IND")
end

sys.taskInit(function()
    sys.waitUntil("CFGLOADED")

    while true do
        -- 等待 autoGPS 完成初始化并发布 AUTOGPS_READY
        while not gpsLib do
            sys.wait(1000)
        end

        -- 等待定位，超时则休眠
        local waitCnt = 0
        while not gpsLib.isFix() do
            sys.wait(1000)
            waitCnt = waitCnt + 1
            if waitCnt >= GPS_TIMEOUT then
                gpsSleep()
                break
            end
        end

        -- gpsSleep 后 gpsLib 为 nil，回到外层重新等待 AUTOGPS_READY
        if not gpsLib then
            sys.wait(5000)
        else
            log.info("GPS", "已定位，开始追踪")

            -- 追踪主循环，定位再次丢失超时同样触发休眠
            local noFixCnt = 0
            while gpsLib do
                local fixed = gpsProcess()
                if fixed then
                    noFixCnt = 0
                else
                    noFixCnt = noFixCnt + 1
                    if noFixCnt >= GPS_TIMEOUT then
                        gpsSleep()
                        break
                    end
                end
                sys.wait(1000)
            end
        end
    end
end)

sys.subscribe("AUTOGPS_READY", function(gLib, aLib, kind, baudrate)
    gpsLib  = gLib
    agpsLib = aLib
    gpsLib.setUart(3, baudrate, 8, uart.PAR_NONE, uart.STOP_1)
    gpsLib.setParseItem(1)
    gpsLib.open(gpsLib.DEFAULT, { tag = "AIR820-TRACKER" })
    log.info("GPS", "型号", kind, "波特率", baudrate, "已打开，等待定位")
end)