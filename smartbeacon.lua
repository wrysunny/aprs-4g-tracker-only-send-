smart = {}

local last_send   = 0
local last_course = 0

local function calc(speed)
    local slow   = tonumber(mycfg.SMART_SLOW)   or 5
    local fast   = tonumber(mycfg.SMART_FAST)   or 60
    local b_slow = tonumber(mycfg.BEACON_SLOW)  or 50
    local b_fast = tonumber(mycfg.BEACON_FAST)  or 10

    if speed <= slow then return b_slow end
    if speed >= fast then return b_fast end

    local r = (speed - slow) / (fast - slow)
    return math.floor(b_slow + r * (b_fast - b_slow))
end

function smart.should(data)
    if not data.valid then return false end

    -- speed 单位：节，转换为 km/h 用于和阈值比较
    local speed    = data.speed * 1.852
    local now      = os.time()
    local interval = calc(speed)

    if now - last_send >= interval then
        return true
    end

    local delta = math.abs(data.course - last_course)
    local turn  = math.min(delta, 360 - delta)
    local slow  = tonumber(mycfg.SMART_SLOW)  or 5
    local sturn = tonumber(mycfg.SMART_TURN)  or 28

    if turn >= sturn and speed > slow then
        return true
    end

    return false
end

function smart.update(data)
    last_send   = os.time()
    last_course = data.course
end
