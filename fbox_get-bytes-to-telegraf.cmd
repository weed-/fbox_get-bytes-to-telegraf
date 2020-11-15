@echo off
REM /*
REM     Liesst daten aus der FritzBox aus (TR064/UPNP) und schiebt diese in telegraf
REM     20190404 b.stromberg@data-systems.de
REM */

REM --- CONFIG: Die Fritz!Box
set fboxlanv4=192.168.42.1

REM --- CONFIG: Telegraf Ziel
set telegrafurl=http://localhost:8086/write?db=fritzbox

REM "Besorgt" UNIX Zeit aus WMIC und legt sie in %ss% ab. Tolles Script von
REM https://stackoverflow.com/questions/11124572/what-is-the-windows-equivalent-of-the-command-dates
REM ACHTUNG: explodiert 2038-01-19
set ts=
for /f "skip=1 delims=" %%A in ('wmic os get localdatetime') do if not defined ts set "ts=%%A"
set /a "yy=10000%ts:~0,4% %% 10000, mm=100%ts:~4,2% %% 100, dd=100%ts:~6,2% %% 100"
set /a "dd=dd-2472663+1461*(yy+4800+(mm-14)/12)/4+367*(mm-2-(mm-14)/12*12)/12-3*((yy+4900+(mm-14)/12)/100)/4"
set /a ss=(((1%ts:~8,2%*60)+1%ts:~10,2%)*60)+1%ts:~12,2%-366100-%ts:~21,1%((1%ts:~22,3%*60)-60000)
set /a ss+=dd*86400

REM Werte aus fritzbox in fbox_tempxml.xml holen
curl -s "http://%fboxlanv4%%:49000/igdupnp/control/WANCommonIFC1" -H "Content-Type: text/xml; charset="utf-8"" -H "SoapAction:urn:schemas-upnp-org:service:WANCommonInterfaceConfig:1#GetAddonInfos" -d "@fbox_WANCommonInterfaceConfig.xml" > fbox_tempxml.xml

REM XML parsen
for /f %%i in ('fbox_xml.exe sel -t -v "//NewByteSendRate" fbox_tempxml.xml') do set NewByteSendRate=%%i
for /f %%i in ('fbox_xml.exe sel -t -v "//NewByteReceiveRate" fbox_tempxml.xml') do set NewByteReceiveRate=%%i
for /f %%i in ('fbox_xml.exe sel -t -v "//NewTotalBytesSent" fbox_tempxml.xml') do set NewTotalBytesSent=%%i
for /f %%i in ('fbox_xml.exe sel -t -v "//NewTotalBytesReceived" fbox_tempxml.xml') do set NewTotalBytesReceived=%%i
for /f %%i in ('fbox_xml.exe sel -t -v "//NewX_AVM_DE_TotalBytesSent64" fbox_tempxml.xml') do set NewX_AVM_DE_TotalBytesSent64=%%i
for /f %%i in ('fbox_xml.exe sel -t -v "//NewX_AVM_DE_TotalBytesReceived64" fbox_tempxml.xml') do set NewX_AVM_DE_TotalBytesReceived64=%%i

REM Ab in influxdb
curl -i -XPOST "%telegrafurl%" --data-binary "Interface,host=fritzbox NewByteSendRate=%NewByteSendRate%,NewByteReceiveRate=%NewByteReceiveRate%,NewTotalBytesSent=%NewTotalBytesSent%,NewTotalBytesReceived=%NewTotalBytesReceived%,NewX_AVM_DE_TotalBytesSent64=%NewX_AVM_DE_TotalBytesSent64%,NewX_AVM_DE_TotalBytesReceived64=%NewX_AVM_DE_TotalBytesReceived64%"

REM aufraeumen
del /s /q fbox_tempxml.xml
