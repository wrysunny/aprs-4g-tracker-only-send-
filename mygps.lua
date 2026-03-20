local TAG                = "4G-TRACKER" -- 本应用的 GPS 标记
--local GPS_Check_Interval = 5 * 1000     -- 5秒钟检查一次

local function gpsPowerCtrl(state)
    if state then
        pmd.ldoset(15, pmd.LDO_VIBR)
        rtos.sys32k_clk_out(1)
        log.info("GPS", "供电已开启")
    else
        pmd.ldoset(0, pmd.LDO_VIBR)
        rtos.sys32k_clk_out(0)
        log.warn("GPS", "供电已关闭")
    end
end

function GpsIsReady()
    return gpsZkw.isFix()
end


-- 订阅 GPS_STATE，由 gpsZkw 驱动在定位成功/失败时发布
sys.subscribe("GPS_STATE", function(state)
    if state == "LOCATION_SUCCESS" then
        log.info("GPS", "定位成功")
    elseif state == "OPEN" then
        log.info("GPS", "已打开")
        -- 这里发布aprs消息订阅，connect接收到时 执行获取beacon就行了
        --sys.wait(500) -- 等一下
        -- beacon.spd 这里的调整下，根据速度 进行调整推送频率，注意速度是节 不是km/h
        -- sys.publish("APRS_MSG")
        --DynamicRate()
    else
        log.warn("GPS", "定位丢失，state =", state)
    end
end)

--gpsZkw.open(gpsZkw.DEFAULT, { tag = TAG })
--log.info("GPS", "已开启，等待定位...")

-- GPS 管理任务
-- 上电 → 一直保持开启，永久等待定位，永不关闭 省不了多少电 不如加大电池容量
sys.taskInit(function()
    -- 初始化串口和供电回调，必须在第一次 open 前完成
    gpsZkw.setPowerCbFnc(gpsPowerCtrl)
    -- 这是那个坑，uart3接口
    gpsZkw.setUart(3, 9600, 8, uart.PAR_NONE, uart.STOP_1)
    sys.wait(5000)
    gpsZkw.open(gpsZkw.DEFAULT, { tag = TAG })
    log.info("GPS", "已开启，等待定位...")
    
end)