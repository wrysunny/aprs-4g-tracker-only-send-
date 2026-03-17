-- 默认配置（所有值在 cfg.ini 中可覆盖）
mycfg = {
    ["CALLSIGN"]        = nil,
    ["PASSCODE"]        = nil,
    ["SSID"]            = "4G",
    ["SERVER"]          = "china.aprs2.net",
    ["PORT"]            = 14580,
    ["TABLE"]           = "/",
    ["SYMBOL"]          = ">",
    ["BEACON"]          = string.format("4G-Tracker ver%s", VERSION),
    ["BEACON_INTERVAL"] = 60,
    -- 以下为 Tracker 扩展配置
    ["PATH"]            = "TCPIP*",
    ["COMMENT"]         = "4G APRS Tracker",
    ["ADD_VOLTAGE"]     = "false",
    ["SMART_FAST"]      = 60,
    ["SMART_SLOW"]      = 5,
    ["SMART_TURN"]      = 28,
    ["BEACON_FAST"]     = 10,
    ["BEACON_SLOW"]     = 50,
}

-- APRS 验证码算法
local function pwdCal(callin)
    local call = string.upper(callin)
    local hash = 0x73e2
    local i = 1
    while i <= string.len(call) do
        hash = bit.bxor(hash, string.byte(call, i) * 0x100)
        i = i + 1
        if i <= string.len(call) then
            hash = bit.bxor(hash, string.byte(call, i))
            i = i + 1
        end
    end
    return bit.band(hash, 0x7fff)
end

local function isValidIP(ipStr)
    if type(ipStr) ~= "string" then return false end
    local len = string.len(ipStr)
    if len < 7 or len > 15 then return false end
    local dotCnt = 0
    local p = string.find(ipStr, "%p", 1)
    while p ~= nil do
        if string.sub(ipStr, p, p) ~= "." then return false end
        dotCnt = dotCnt + 1
        if dotCnt > 3 then return false end
        p = string.find(ipStr, "%p", p + 1)
    end
    if dotCnt ~= 3 then return false end
    local num = {}
    for w in string.gmatch(ipStr, "%d+") do
        num[#num + 1] = w
        local n = tonumber(w)
        if not n or n > 255 then return false end
    end
    return #num == 4 and ipStr
end

local function iniChk(cfgfile)
    local file = io.open(cfgfile)
    if file == nil then
        log.warn("配置校验", "文件 " .. cfgfile .. " 不存在")
        return false
    end
    local ini = {}
    for line in file:lines() do
        if not line:match('^%s*;') then
            local n = string.find(line, '%s*;')
            if not n then n = string.find(line, '%s*%c*$') end
            if n then line = string.sub(line, 1, n - 1) end
            local param, value = line:match('^%s*([^%s]+)%s*=%s*(.-)$')
            if param and value ~= nil then
                ini[param] = value
                log.info("读取配置", param .. ": " .. value)
            end
        end
    end
    file:close()

    -- 必填：呼号
    if not ini.CALLSIGN then
        log.error("配置校验", "呼号未设置"); return false
    end
    ini.CALLSIGN = string.upper(ini.CALLSIGN)
    if not (ini.CALLSIGN:match('^[1-9]%u%u?%d%u%u?%u?%u?$') or
            ini.CALLSIGN:match('^%u[2-9A-Z]?%d%u%u?%u?%u?$')) then
        log.error("配置校验", "呼号不合法"); return false
    end
    if #ini.CALLSIGN < 3 or #ini.CALLSIGN > 7 then
        log.error("配置校验", "呼号长度需在 3-7 个字符"); return false
    end

    -- 必填：验证码
    if not ini.PASSCODE then
        log.error("配置校验", "验证码未设置"); return false
    end
    local pscode = pwdCal(ini.CALLSIGN)
    if not tonumber(ini.PASSCODE) or tonumber(ini.PASSCODE) ~= pscode then
        log.error("配置校验", "验证码错误，正确值为 " .. pscode); return false
    end
    ini.PASSCODE = pscode

    -- 选填：SSID
    if ini.SSID then
        ini.SSID = string.upper(ini.SSID)
        if not (ini.SSID:match('^%d%u?$') or ini.SSID:match('^[1][0-5]$') or
                ini.SSID:match('^%u%w?$')) then
            log.error("配置校验", "SSID 不合法"); return false
        end
        if #ini.CALLSIGN + #ini.SSID > 8 then
            log.error("配置校验", "呼号+SSID 总长度不能超过 8 个字符"); return false
        end
    end

    -- 选填：服务器
    if ini.SERVER then
        if not (ini.SERVER:match('%.*%w[%w%-]*%.%a%a%a?%a?%a?%a?$') or isValidIP(ini.SERVER)) then
            log.error("配置校验", "服务器地址非法"); return false
        end
    end

    -- 选填：端口
    if ini.PORT then
        local p = tonumber(ini.PORT)
        if not p or p < 1024 or p > 49151 then
            log.error("配置校验", "端口号需在 1024-49151 之间"); return false
        end
        ini.PORT = p
    end

    -- 选填：图标
    if ini.TABLE then
        ini.TABLE = string.upper(ini.TABLE)
        if not ini.TABLE:match('^[/\\2DEGIRY]$') then
            log.error("配置校验", "TABLE 设置错误"); return false
        end
    end
    if ini.SYMBOL then
        if not ini.SYMBOL:match('^[%w%p]$') then
            log.error("配置校验", "SYMBOL 设置错误"); return false
        end
    end

    -- 选填：信标文本
    if ini.BEACON and ini.BEACON:len() > 62 then
        log.error("配置校验", "BEACON 长度超过 62 个字符"); return false
    end

    -- 选填：信标间隔（分钟）
    if ini.BEACON_INTERVAL then
        local v = tonumber(ini.BEACON_INTERVAL)
        if not v or ((v < 10 or v > 600) and v ~= 0) then
            log.error("配置校验", "BEACON_INTERVAL 需在 10-600 分钟或为 0"); return false
        end
        ini.BEACON_INTERVAL = v
    end


    -- 选填：SmartBeacon 参数（数值类）
    for _, k in ipairs({"SMART_FAST","SMART_SLOW","SMART_TURN","BEACON_FAST","BEACON_SLOW"}) do
        if ini[k] then
            local v = tonumber(ini[k])
            if not v or v < 0 then
                log.error("配置校验", k .. " 必须为非负数字"); return false
            end
            ini[k] = v
        end
    end

    -- 选填：ADD_VOLTAGE（"true"/"false"）
    if ini.ADD_VOLTAGE then
        if ini.ADD_VOLTAGE ~= "true" and ini.ADD_VOLTAGE ~= "false" then
            log.error("配置校验", "ADD_VOLTAGE 只能为 true 或 false"); return false
        end
    end

    log.info("配置校验", "校验已通过")
    return true, ini
end

local function cfgRead()
    local res, ini = iniChk("cfgsave.ini")
    if not res then
        log.warn("读取配置", '读取 cfgsave.ini 失败，将读取 /lua/cfg.ini')
        res, ini = iniChk("/lua/cfg.ini")
        if not res then
            log.error("读取配置", '读取 /lua/cfg.ini 失败')
            return false
        end
        local f = io.open("cfgsave.ini", "w")
        for k, v in pairs(ini) do
            mycfg[k] = v
            f:write(k .. "=" .. tostring(v) .. "\n")
        end
        f:close()
        log.info("读取配置", '已保存副本到 cfgsave.ini')
    else
        log.info("读取配置", '读取 cfgsave.ini 成功')
        for k, v in pairs(ini) do
            mycfg[k] = v
        end
    end
    return true
end

sys.taskInit(function()
    sys.wait(5000)
    if not cfgRead() then
        log.error("加载配置", "加载失败，系统已停止")
        while true do sys.wait(1000) end
    end
    if not mycfg.BTNAME then
        mycfg.BTNAME = mycfg.CALLSIGN .. '-7'
    end
    if mycfg.SSID == '0' then
        sourceCall = mycfg.CALLSIGN
    else
        sourceCall = mycfg.CALLSIGN .. '-' .. mycfg.SSID
    end
    log.info("加载配置", "完成，本机呼号：" .. sourceCall)
    sys.publish("CFGLOADED")
end)
