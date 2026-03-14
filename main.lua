PROJECT = "AIR820_APRS_TRACKER_COMMERCIAL"
VERSION = "4.6"
sys = require("sys")
log = require("log").create("APRS")
CONFIG = require("config")
codec = require("aprs_codec")
smart = require("smartbeacon")
tele = require("telemetry")
power = require("power")
local mobile = require("mobile")
local gps = require("gps")
local socket = require("socket")
local wdt = require("wdt") -- 硬件看门狗
-- ================== 本地变量 ==================
local gps_data = { lat = 0, lon = 0, speed = 0, course = 0, valid = false }
local sock = nil
local connected = false
local function init_gps()
    gps.start()
    gps.on("gps", function(data)
        if data.fix == 1 then
            gps_data.lat    = data.lat or 0
            gps_data.lon    = data.lng or data.lon or 0
            gps_data.speed  = data.speed or 0
            gps_data.course = data.course or 0
            gps_data.valid  = true
            log.info("GPS", "Fix!", gps_data.lat, gps_data.lon, "Speed:", gps_data.speed * 1.852)
        else
            gps_data.valid = false
        end
    end)
end
local function wait_network()
    log.info("NET", "等待SIM注册...")
    while true do
        local status = mobile.status()
        if status == mobile.READY then
            log.info("NET", "4G 已就绪")
            break
        end
        sys.wait(1000)
    end
end
-- ================== APRS-IS 协程任务（极简纯发送版） ==================
local function aprs_task()
    while true do
        if sock then
            sock:close()
            sock = nil
        end
        connected = false
        sock = socket.tcp()
        log.info("APRS", "正在连接服务器...", CONFIG.APRS_SERVER, CONFIG.APRS_PORT)
        local connect_ok = sock:connect(CONFIG.APRS_SERVER, CONFIG.APRS_PORT, 15000)
        if connect_ok then
            connected = true
            local login = string.format("user %s-%d pass %s vers %s %s\r\n",
                CONFIG.CALLSIGN, CONFIG.SSID, CONFIG.PASSCODE, PROJECT, VERSION)
            sock:send(login)
            log.info("APRS", "登录成功（纯发送模式，无接收过滤器）")
            -- 仅接收数据防粘包/保持连接，不解析任何消息
            while connected do
                local data = sock:recv(1000)
                if data == nil then
                    log.warn("APRS", "服务器断开，准备重连")
                    connected = false
                    break
                end
                sys.wait(10)
            end
        else
            log.warn("APRS", "连接失败，10秒后重试")
        end
        sys.wait(10000)
    end
end
local last_tele = 0
local function beacon_loop()
    while true do
        power.update(gps_data)
        if gps_data.valid and smart.should(gps_data, CONFIG) then
            local pos = codec.pos(gps_data.lat, gps_data.lon)
            local pkt = string.format("%s-%d>APRS,%s,TCPIP*:%s%s%s%s   T tracker",
                CONFIG.CALLSIGN, CONFIG.SSID, CONFIG.PATH,
                "!", CONFIG.SYMBOL_TABLE, pos, CONFIG.SYMBOL)
            if os.time() - last_tele > 600 then
                pkt = pkt .. "\r\n" .. tele.frame(codec)
                last_tele = os.time()
            end
            if connected and sock then
                sock:send(pkt .. "\r\n")
                log.info("BEACON", "发送位置", gps_data.lat, gps_data.lon)
            end
            smart.update(gps_data)
        end
        sys.wait(2000)
    end
end
-- ================== 启动（添加死机保护） ==================
sys.taskInit(function()
    wdt.init(30000) -- 30秒硬件看门狗，死机自动重启
    ble_start(CONFIG)
    wait_network()
    init_gps()
    sys.taskInit(aprs_task)
    sys.taskInit(beacon_loop)
    log.info(PROJECT, "商业级互联网APRS Tracker（纯发送版）已启动 v" .. VERSION)
end)
sys.run()
