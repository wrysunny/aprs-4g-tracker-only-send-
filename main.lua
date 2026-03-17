PROJECT = "AIR820-TRACKER"
VERSION = "1.0"

require "sys"
require "net"
require "socket"
require "log"
require "netLed"
require "autoGPS"
require "cfg"
require "aprs_codec"
require "smartbeacon"
require "telemetry"
require "pos"
require "msg"
require "nets"
require "ble_config"

pmd.ldoset(2, pmd.LDO_VLCD)
netLed.setup(true, pio.P0_1, pio.P0_4)
LOG_LEVEL = log.LOGLEVEL_INFO
ril.request("AT+RNDISCALL=0,1")
sys.init(0, 0)
sys.run()
