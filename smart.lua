local last_tx_time = 0      -- 上次发送的时间 (秒)
local last_tx_heading = 0   -- 上次发送时的航向角

function DynamicRate() -- 动态速度
    local speed_kmh = beacon.speed_kmh -- 第一个参数才是km/h
    local heading = beacon.course
    local current_time = os.time()
    -- 防御性容错，确保取到的是数字
    speed_kmh = tonumber(speed_kmh) or 0
    heading = tonumber(heading) or 0
    local time_since_last = current_time - last_tx_time

    local need_tx = false
    local tx_reason = ""
    -- 当速度大于低速阈值时
    if speed_kmh > config.slow_speed then
        local heading_diff = math.abs(heading - last_tx_heading)
        -- 处理 360 度跨越的问题 (例如从 350度 转到 10度)
        if heading_diff > 180 then
            heading_diff = 360 - heading_diff
        end

        -- 如果转弯角度达标，且过了冷却时间
        if heading_diff >= config.turn_angle and time_since_last >= config.turn_time then
            need_tx = true
            tx_reason = "Corner"
        end
    end
    -- 2. 动态速率逻辑 (Dynamic Rate)
    if not need_tx then
        local target_rate = config.slow_rate

        if speed_kmh <= config.slow_speed then
            target_rate = config.slow_rate
        elseif speed_kmh >= config.fast_speed then
            target_rate = config.fast_rate
        else
            -- 线性插值计算：速度在 5 ~ 90 之间时，平滑计算发送间隔
            local speed_ratio = (speed_kmh - config.slow_speed) / (config.fast_speed - config.slow_speed)
            target_rate = config.slow_rate - speed_ratio * (config.slow_rate - config.fast_rate)
        end

        if time_since_last >= target_rate then
            need_tx = true
            tx_reason = "Dynamic(" .. math.floor(target_rate) .. "s)"
        end
    end

    -- 3. 触发发送
    if need_tx then
        last_tx_time = current_time
        last_tx_heading = heading
        log.info("SmartBeacon", string.format("触发! 理由:%s, 速度:%.1fkm/h, 航向:%d°", tx_reason, speed_kmh, math.floor(heading)))
        sys.publish("APRS_MSG") -- 通知 connect.lua 发包
    end

end