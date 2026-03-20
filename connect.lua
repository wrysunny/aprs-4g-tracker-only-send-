local conn       = nil      -- 当前 TCP socket

local CALLSIGN = config.CALL .. "-" .. config.SSID
local CHECK_ITV      = 3  * 1000   -- 3 秒检测一次连接状态
local HOST = config.aprs_host or "rotate.aprs2.net"
local PORT = tonumber(config.aprs_port or 14580)


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
    local i = 0
    if not socket.isReady() then
        -- 网络没就绪
        net_fail_count = net_fail_count + 1
        if net_fail_count >= 5 then
            net_fail_count = 0
            net.switchFly(true) -- 开启飞行模式
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
        log.error("socket","创建socket失败")
        return false
    end
    if conn.settimeout then
        conn:settimeout(30000)
    end
    local ok = conn:connect(HOST, PORT,10)
    if not ok then
        conn:close()
        conn = nil
        return false
    end
    local loginOk = conn:send(LOGIN_STR,10) -- 超时10秒
    if not loginOk then
        conn:close()
        conn = nil
        return false
    end
    local result, data = conn:recv(10000) -- 接收10秒超时
    if result and data then
        if string.find(data, " verified") then
            log.info("APRS服务器", "登录已成功")
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