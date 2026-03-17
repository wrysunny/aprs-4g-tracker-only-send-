local noNetCnt = 0

local function netProcess()
    if not socket.isReady() then
        noNetCnt = noNetCnt + 1
        if noNetCnt >= 5 then
            noNetCnt = 0
            log.warn("网络", "长时间未就绪，尝试重启网络")
            net.switchFly(true)
            sys.wait(10000)
            net.switchFly(false)
        else
            log.warn("网络", "未就绪，等待重试")
            sys.waitUntil("IP_READY_IND", 60000)
        end
        return false
    end
    noNetCnt = 0

    local sc = socket.tcp()
    if not sc:connect(mycfg.SERVER, mycfg.PORT, 10) then
        log.warn("服务器", "TCP 连接失败，稍后重试")
        return false
    end

    local loginSent, recvCnt = false, 0

    while true do
        local result, data = sc:recv(10000)
        if result then
            if not loginSent then
                if string.find(data, "aprsc") or string.find(data, "javAPRSSrvr") then
                    log.info("服务器", "正在登录...")
                    if sc:send(string.format(
                        "user %s pass %d vers AIR820-TRACKER %s\r\n",
                        sourceCall, mycfg.PASSCODE, VERSION), 10) then
                        loginSent = true
                        recvCnt   = 0
                    else
                        log.warn("服务器", "登录发送超时")
                        break
                    end
                end
            else
                if string.find(data, " verified") then
                    log.info("服务器", "登录成功")
                    local lastTime, lastCall = os.time(), " "
                    while os.time() - lastTime <= 18 do
                        if #msgTab > 0 then
                            local msgCall = string.sub(msgTab[1], 1,
                                string.find(msgTab[1], '>') - 1)
                            while lastCall == msgCall and os.time() - lastTime <= 5 do
                                sys.wait(100)
                            end
                            if sc:send(msgTab[1], 10) then
                                lastTime = os.time()
                                lastCall = msgCall
                                log.info("已发送", msgTab[1])
                                table.remove(msgTab, 1)
                            else
                                sc:close()
                                return false
                            end
                        end
                        result, data = sc:recv(100)
                    end
                    sc:close()
                    return true
                elseif string.find(data, "unverified") then
                    log.warn("服务器", "验证失败，请检查呼号和验证码")
                    break
                elseif string.find(data, "full") then
                    log.warn("服务器", "服务器已满")
                    break
                end
            end
            recvCnt = recvCnt + 1
            if recvCnt >= 5 then
                log.warn("服务器", "未收到期望数据")
                break
            end
        else
            log.warn("服务器", "接收超时")
            break
        end
    end
    sc:close()
    return false
end

sys.taskInit(function()
    sys.waitUntil("CFGLOADED")
    while true do
        if msgTab and #msgTab > 0 and not netProcess() then
            sys.wait(10000)
        end
        sys.wait(100)
    end
end)
