local M={}

local gps_sleep = false
local last_move = 0
local wake_timer = nil
local check_active = false
local sys = require("sys")  -- 定时器需要

local CHECK_INTERVAL = 600000  -- 睡眠时每10分钟检查一次（ms）
local CHECK_DURATION = 30000   -- 每次检查开启GPS 30秒

function M.update(gps)
    if gps.speed > 2 then
        last_move = os.time()
        if gps_sleep then
            gps.start()
            gps_sleep = false
            if wake_timer then
                sys.timerStop(wake_timer)
                wake_timer = nil
            end
            check_active = false
        end
    end

    local now = os.time()
    if now - last_move > 300 then
        -- 静止超过5分钟 → 关闭GPS
        if not gps_sleep then
            gps.stop()
            gps_sleep = true
            if not wake_timer then
                wake_timer = sys.timerLoopStart(function()
                    if gps_sleep and not check_active then
                        check_active = true
                        gps.start()
                        -- 30秒后若仍静止则关闭
                        sys.timerStart(function()
                            if gps_sleep and check_active then
                                gps.stop()
                                check_active = false
                            end
                        end, CHECK_DURATION)
                    end
                end, CHECK_INTERVAL)
            end
        end
    else
        if gps_sleep then
            gps.start()
            gps_sleep = false
            if wake_timer then
                sys.timerStop(wake_timer)
                wake_timer = nil
            end
            check_active = false
        end
    end
end

return M
