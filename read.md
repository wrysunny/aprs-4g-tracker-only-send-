beacon.lua中 gps、device需要开机等一会才能拿到数据。等gps定位成功再执行？
gps.lua 如果开机3钟没有定位成功，就关闭gps供电直到10分钟后打开gps尝试定位 这个节省不了多少电，不考虑了。
gps模块使用中科微 AT6558 系列（合宙模组标配 GPS 芯片） [GPS] 型号 530Z 波特率 9600 require "gpsZkw" require "agpsZkw"
使用sys.subscribe("GPS_STATE" 订阅gps有没有准备好


每 60 秒固定时间采集并打印一次deacon 后续高低速不妥 改为1秒 后期release可删除log调试 这样数据就不会显得“多”了 

beacon_comment 注释连发三个包 一个位置、高度等。一个设备信息 一个默认文本 （不必了，一个数据包 256字节够用的）
