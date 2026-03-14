local json = require("json")
function ble_start(config)
    ble.init()
    -- 【BLE MTU 优化建议】若 CONFIG JSON 过长被截断，取消下面注释（多数固件支持 DLE）
    -- ble.dle(true)          -- 开启 Data Length Extension（最高 251 字节）
    -- -- 或 ble.setmtu(251)   -- 部分固件使用此 API
    ble.advertising("APRS_TRACKER")
    ble.on("write", function(data)
        local cmd = json.decode(data)
        if cmd.cmd == "get" then
            ble.send(json.encode(config))
        elseif cmd.cmd == "set" then
            for k, v in pairs(cmd) do
                if config[k] then
                    config[k] = v
                end
            end
            cfg_save()
            ble.send("OK")
        end
    end)
end
