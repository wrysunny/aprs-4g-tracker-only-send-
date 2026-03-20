local conn      = nil -- 当前 TCP socket

local CALLSIGN  = config.CALL .. "-" .. config.SSID
local CHECK_ITV = 3 * 1000 -- 3 秒检测一次连接状态
local HOST      = config.aprs_host or "rotate.aprs2.net"
local PORT      = tonumber(config.aprs_port or 14580)


-- 登录包字符串
local LOGIN_STR = string.format(
    "user %s pass %s vers %s %s\r\n",
    CALLSIGN, config.passcode, PROJECT, VERSION
)
-- 保活注释行字符串
local KEEPALIVE_STR = string.format("# %s keepalive\r\n", CALLSIGN)

local net_fail_count = 0 -- 记录网络未就绪的连续次数
-- socket连接，使用同步sync socket
local function connect()
    if not socket.isReady() then
        -- 网络没就绪
        net_fail_count = net_fail_count + 1
        if net_fail_count >= 5 then
            net_fail_count = 0
            net.switchFly(true)  -- 开启飞行模式
            sys.wait(10000)
            net.switchFly(false) -- 关闭飞行模式
        else
            sys.waitUntil("IP_READY_IND", 60000)
        end
        return false
    end
    net_fail_count = 0
    conn = socket.tcp()
    if not conn then
        log.error("socket", "创建socket失败")
        return false
    end
    if conn.settimeout then
        conn:settimeout(30000)
    end
    local ok = conn:connect(HOST, PORT, 10)
    if not ok then
        conn:close()
        conn = nil
        return false
    end

    local result, data = conn:recv(10000) -- 接收10秒超时
    if result and data then
        if string.find(data, "# aprsc") then
            local loginOk = conn:send(LOGIN_STR, 10) -- 超时10秒
            if not loginOk then
                conn:close()
                conn = nil
                return false
            end
        end
    end
    local result, data = conn:recv(10000) -- 接收10秒超时
    if result and data then
        if string.find(data, " verified") then
            log.info("APRS服务器", "登录已成功")
            return true
        elseif string.find(data, "# aprsc") and string.find(data, ":") then
            log.info("APRS服务器", "收到系统心跳包")
            return true
        else
            log.error("APRS服务器", "登录验证失败: " .. data)
        end
    end
    conn:close()
    conn = nil
    return false
end

sys.taskInit(function()
    local keepalive_tick = 0 -- 明确局部变量
    while true do
        if not socket.isReady() or not conn then
            log.info("网络", "尝试连接服务器...")
            connect()
            sys.wait(2000) -- 给一点缓冲时间
        end
        -- 1. 尝试接收服务器发来的 20秒一次的信息 (非阻塞/短超时)
        if conn then
            local r, d = conn:recv(200) -- 只等 200ms
            if r and d then
                log.info("服务器下发数据", d)
                -- 只要收到服务器任何数据，说明链路通畅，可以重置心跳计数
                keepalive_tick = 0
            end
        end
        -- 2. 处理业务逻辑 (发送位置包)
        local result, _ = sys.waitUntil("APRS_MSG", CHECK_ITV)
        if result then
            local data = BuildBeaconPacket()

            if conn and conn:send(data, 10) then
                log.info("socket", "位置包发送成功")
                keepalive_tick = 0
            else
                log.error("socket", "发送失败，关闭连接")
                if conn then conn:close() end
                conn = nil
            end
        else
            -- 3. 维护心跳
            keepalive_tick = keepalive_tick + 1
            if keepalive_tick >= 18 then
                -- 发送逻辑
                keepalive_tick = 0
                if conn then
                    local keep_ok = conn:send(KEEPALIVE_STR, 10)
                    if not keep_ok then
                        log.error("socket", "心跳包发送失败，准备重连")
                        conn:close()
                        conn = nil -- 触发下次循环重连
                    end
                else
                    log.warn("socket", "由于连接未建立，跳过本次心跳发送")
                end
            end
        end
    end
end)


--[[
    connect() -- 登录
    local keepalive_tick = 0
    while true do
        local result, _ = sys.waitUntil("APRS_MSG", CHECK_ITV)
        if result then
            if not socket.isReady() or not conn then
                connect() -- 如果有发送任务但没连接，先尝试抢救连接
            end
            keepalive_tick = 0  -- 重置心跳计数
            local data = BuildBeaconPacket()
            if conn then
                local send_ok = conn:send(data, 10)
                if not send_ok then
                    log.error("socket", "发送消息失败，准备重连")
                    conn:close()
                    conn = nil
                end
            end
        else
            keepalive_tick = keepalive_tick + 1
            if not socket.isReady() or not conn then
                log.info("网络", "检测到连接断开, 开始重连...")
                connect()
            else
                if keepalive_tick >= 18 then -- 54秒 - 60秒内发送心跳包
                    keepalive_tick = 0
                    local keep_ok = conn:send(KEEPALIVE_STR, 10)
                    if not keep_ok then
                        log.error("socket", "心跳包发送失败，准备重连")
                        conn:close()
                        conn = nil -- 触发下次循环重连
                    end
                end
            end
        end
    end
end)
]]
