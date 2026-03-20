config = {
    CALL = "BA4TGG", -- 呼号
    passcode = "17072", -- 验证码
    SSID = "7", -- SSID
    -- 信标发射设置
    beacon_comment  = "Air820UG APRS Tracker, Power by wrysunny.",  -- 自定义注释 静态信息
    -- APRS 图标（Symbol）
    symbol_table  = "/",           -- 图标表：/ 主表
    symbol_symbol = ">",           -- 图标：> = 车（向右）

    -- APRS-IS 服务器
    aprs_host  = "china.aprs2.net",
    aprs_port  = 14580,
    -- 定位速率设定
    slow_rate  = 60,  -- 慢速/静止状态下的发送间隔：1分钟 (秒)
    fast_rate  = 5,    -- 高速状态下的最短发送间隔：5秒
    slow_speed = 5,     -- 低速阈值 (km/h)：低于此速度认为静止或步行
    fast_speed = 80,    -- 高速阈值 (km/h)：高于此速度强制最高频率
    turn_angle = 28,    -- 触发发送的转弯累积角度 (度)
    turn_time  = 5     -- 两次转弯触发之间的最短冷却时间，防连发 (秒)
}
