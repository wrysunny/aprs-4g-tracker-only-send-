local M = {}
local last_send = 0
local last_course = 0
function M.should(gps, config)
    if not gps.valid then return false end
    local speed = gps.speed * 1.852
    local now = os.time()
    local interval = config.BEACON_SLOW
    if speed > config.SMART_FAST then
        interval = config.BEACON_FAST
    elseif speed < config.SMART_SLOW then
        interval = config.BEACON_SLOW
    end
    if now - last_send > interval then
        return true
    end
    -- 【致命修复】航向 360° 循环处理
    local delta = math.abs(gps.course - last_course)
    local turn = math.min(delta, 360 - delta)
    if turn > config.SMART_TURN and speed > config.SMART_SLOW then
        return true
    end
    return false
end

function M.update(gps)
    last_send = os.time()
    last_course = gps.course
end

return M
