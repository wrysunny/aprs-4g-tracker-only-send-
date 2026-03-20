PROJECT = "4G_APRS_Tracker"
VERSION = "2.2.1"

require "misc"
require "log"
LOG_LEVEL = log.LOGLEVEL_TRACE
require "sys"
require "net"
require "socket"
require "netLed"
require "gpsZkw"
require "agpsZkw" -- 每4小时下载星历

-- 这边是自己实现的lua
require "config"
require "mygps" -- gps采集
require "beacon" -- 信标
require "connect"
require "smart"
require "aprs"

--加载网络指示灯和LTE指示灯功能模块
pmd.ldoset(2,pmd.LDO_VLCD)
netLed.setup(true,pio.P0_1,pio.P0_4)
--每1分钟查询一次GSM信号强度
net.startQueryAll(60000, 60000)
--此处关闭RNDIS网卡功能
ril.request("AT+RNDISCALL=0,1")


--启动系统框架
sys.init(0, 0)
sys.run()
