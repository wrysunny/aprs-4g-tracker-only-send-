--[[
    BLE 配置接口（Air820 内置 BLE 从机模式）
    设备名称为呼号（sourceCall），手机用 nRF Connect 等 APP 即可连接。

    GATT 服务：
      Service UUID : 0xFFE0
      特征 0xFFE1  : 可写（手机 → 模块，发送指令）
      特征 0xFFE2  : 通知（模块 → 手机，回复结果）

    指令协议（UTF-8 文本，换行结束）：
      KEY=VALUE    → 修改配置并保存，回复 OK 或 ERR:xxx
      GET KEY      → 查询单项，回复 KEY=VALUE
      LIST         → 列出所有配置，最后一行 END
]]

local bleHandle = nil
local recvBuf   = ""

-- 将 mycfg 保存到 cfgsave.ini
local function save()
    local f = io.open("cfgsave.ini", "w")
    if not f then
        log.error("BLE CFG", "打开 cfgsave.ini 失败")
        return false
    end
    for k, v in pairs(mycfg) do
        if type(v) ~= "function" then
            f:write(k .. "=" .. tostring(v) .. "\n")
        end
    end
    f:close()
    log.info("BLE CFG", "配置已保存")
    return true
end

-- 通过 0xFFE2 特征通知手机
local function bleSend(str)
    if not bleHandle then return end
    -- send(data, uuid, handle)
    btcore.send(str, 0xffe2, bleHandle)
end

-- 解析并执行一条指令
local function execCmd(line)
    line = line:gsub("[\r\n]", "")
    if line == "" then return end
    log.info("BLE CFG", "收到", line)

    -- LIST
    if line == "LIST" then
        for k, v in pairs(mycfg) do
            if type(v) ~= "function" then
                bleSend(k .. "=" .. tostring(v) .. "\r\n")
            end
        end
        bleSend("END\r\n")
        return
    end

    -- GET KEY
    local qkey = line:match("^GET%s+(%w+)$")
    if qkey then
        if mycfg[qkey] ~= nil then
            bleSend(qkey .. "=" .. tostring(mycfg[qkey]) .. "\r\n")
        else
            bleSend("ERR:UNKNOWN_KEY\r\n")
        end
        return
    end

    -- KEY=VALUE
    local k, v = line:match("^(%w+)=(.+)$")
    if k and v then
        if mycfg[k] ~= nil then
            local num = tonumber(v)
            mycfg[k] = num and num or v
            if save() then
                bleSend("OK\r\n")
                log.info("BLE CFG", "更新", k, "=", tostring(mycfg[k]))
            else
                bleSend("ERR:SAVE_FAIL\r\n")
            end
        else
            bleSend("ERR:UNKNOWN_KEY\r\n")
        end
        return
    end

    bleSend("ERR:BAD_CMD\r\n")
end

-- 从 btcore 收取数据并按行执行
local function onData()
    while true do
        local _, chunk, len = btcore.recv(3)
        if not len or len == 0 then break end
        recvBuf = recvBuf .. chunk
    end
    while true do
        local nl = recvBuf:find("\n")
        if not nl then break end
        local line = recvBuf:sub(1, nl)
        recvBuf    = recvBuf:sub(nl + 1)
        execCmd(line)
    end
end

sys.taskInit(function()
    sys.waitUntil("CFGLOADED")

    -- 注册蓝牙事件回调
    rtos.on(rtos.MSG_BLUETOOTH, function(msg)
        if msg.event == btcore.MSG_OPEN_CNF then
            sys.publish("BLE_OPEN_CNF", msg.result)

        elseif msg.event == btcore.MSG_BLE_CONNECT_CNF then
            bleHandle = msg.handle
            recvBuf   = ""
            log.info("BLE CFG", "已连接，addr =", msg.addr)

        elseif msg.event == btcore.MSG_BLE_DISCONNECT_CNF then
            bleHandle = nil
            recvBuf   = ""
            log.info("BLE CFG", "已断开")

        elseif msg.event == btcore.MSG_BLE_DATA_IND then
            sys.publish("BLE_DATA_IND")
        end
    end)

    -- 以从机模式开启 BLE
    btcore.open(0)
    local _, result = sys.waitUntil("BLE_OPEN_CNF", 5000)
    if result ~= 0 then
        log.error("BLE CFG", "BLE 开启失败，result =", tostring(result))
        return
    end

    -- 设备名 = 呼号，例如 BA4TGG-4G
    btcore.setname(sourceCall)

    -- 广播参数：间隔 80~100ms，可连接非定向广播，全信道，不过滤
    btcore.setadvparam(0x80, 0xa0, 0, 0, 0x07, 0)

    -- 添加 GATT 服务和特征
    btcore.addservice(0xffe0)
    btcore.addcharacteristic(0xffe1, 0x08, 0x0002)   -- 可写（手机写入指令）
    btcore.addcharacteristic(0xffe2, 0x10, 0x0001)   -- 通知（模块回复结果）
    btcore.adddescriptor(0x2902, 0x0001)

    -- 开始广播
    btcore.advertising(1)
    log.info("BLE CFG", "广播已启动，设备名：" .. sourceCall)

    -- 数据接收循环
    while true do
        sys.waitUntil("BLE_DATA_IND")
        if bleHandle then
            onData()
        end
    end
end)