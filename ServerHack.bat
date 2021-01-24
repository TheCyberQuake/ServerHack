@echo off
color 3f
title Minecraft Server Redirection Hack v1.2.1

:: We escalate to Admin due to being a requirement for AdGuard Home

:::::::::::::::::::::::::::::
::Privilege Check/Escalation
:::::::::::::::::::::::::::::

:init
 setlocal DisableDelayedExpansion
 set cmdInvoke=1
 set winSysFolder=System32
 set "batchPath=%~0"
 for %%k in (%0) do set batchName=%%~nk
 set "vbsGetPrivileges=%temp%\OEgetPriv_%batchName%.vbs"
 setlocal EnableDelayedExpansion

:checkPrivileges
  NET FILE 1>NUL 2>NUL
  if '%errorlevel%' == '0' ( goto gotPrivileges ) else ( goto getPrivileges )

:getPrivileges
  if '%1'=='ELEV' (echo ELEV & shift /1 & goto gotPrivileges)

  ECHO Set UAC = CreateObject^("Shell.Application"^) > "%vbsGetPrivileges%"
  ECHO args = "ELEV " >> "%vbsGetPrivileges%"
  ECHO For Each strArg in WScript.Arguments >> "%vbsGetPrivileges%"
  ECHO args = args ^& strArg ^& " "  >> "%vbsGetPrivileges%"
  ECHO Next >> "%vbsGetPrivileges%"

  if '%cmdInvoke%'=='1' goto InvokeCmd 

  ECHO UAC.ShellExecute "!batchPath!", args, "", "runas", 1 >> "%vbsGetPrivileges%"
  goto ExecElevation

:InvokeCmd
  ECHO args = "/c """ + "!batchPath!" + """ " + args >> "%vbsGetPrivileges%"
  ECHO UAC.ShellExecute "%SystemRoot%\%winSysFolder%\cmd.exe", args, "", "runas", 1 >> "%vbsGetPrivileges%"

:ExecElevation
 "%SystemRoot%\%winSysFolder%\WScript.exe" "%vbsGetPrivileges%" %*
 exit /B

:gotPrivileges
 setlocal & cd /d %~dp0
 if '%1'=='ELEV' (del "%vbsGetPrivileges%" 1>nul 2>nul  &  shift /1)

:::::::::::::::::::::::::::::
::Script Start
:::::::::::::::::::::::::::::

set /a ipchanged=0

if not exist "%CD%\DNS\AdGuardHome\AdGuardHome.exe" (
  color 8f
  echo Downloading AdGuard Home...
  powershell -nologo -noprofile -Command "(New-Object Net.WebClient).DownloadFile('https://github.com/AdguardTeam/AdGuardHome/releases/latest/download/AdGuardHome_Windows_amd64.zip', 'DNS.zip')"
  powershell -nologo -noprofile -Command "Invoke-WebRequest https://github.com/AdguardTeam/AdGuardHome/releases/latest/download/AdGuardHome_Windows_amd64.zip -OutFile DNS.zip"
  if not exist DNS mkdir DNS && echo Creating DNS folder
  echo Decompressing download...
  powershell.exe -nologo -noprofile -command "& { $shell = New-Object -COM Shell.Application; $target = $shell.NameSpace('%CD%\DNS'); $zip = $shell.NameSpace('%CD%\DNS.zip'); $target.CopyHere($zip.Items(), 16); }
  del "%CD%\DNS.zip"
  goto launch
)


:: Variable to keep track of when we need to skip lines
set skipnow = 0

:: Set working directory to the location of this script, fix for running as admin
cd /d "%~dp0"

:: Clear previous query log
copy /y NUL "%CD%\DNS\AdGuardHome\data\querylog.json" >NUL

:: Create Server.txt if it doesn't exist, prevents error at next step
if not exist "%CD%\Server.txt" copy /y NUL Server.txt >NUL
if not exist "%CD%\lastIP.txt" copy /y NUL lastIP.txt >NUL

:: Pull saved server, if exists bypass asking for server info
set /p saved=<"%CD%\Server.txt"
if "%saved%" == "" (
  set /p server="What server do you wish to connect to?: "
) else (
  set server=%saved%
)

cls

:: Get the IP of the Server
for /f "tokens=2,3 delims= " %%A in ('ping -4 -n 1 %server% ^| find "Pinging"') do ( 
  if "%%B" == "with" (
    set ServerIP=%%A
  ) else (
    set str=%%B
    set ServerIP=!str:~1,-1!
  )
)

:: Get IP of current machine
for /f "delims=[] tokens=2" %%A in ('ping -4 -n 1 %ComputerName% ^| findstr [') do set NetworkIP=%%A
set /p lastIP=<"%CD%\lastIP.txt"

if not "%lastIP%" == "" (
  if not "%lastIP%" == "%NetworkIP%" (
    color 5f
	set /a ipchanged=1
	echo %NetworkIP%>lastIP.txt
  )
) else (
  echo %NetworkIP%>lastIP.txt
)

:: Ensure the Server is valid and reachable (responds to pings)
if not "%ServerIP%" == "" (
  cls
  ping -4 -n 1 !ServerIP! | find "TTL=" >nul
  if errorlevel 1 (
    color 4f
    echo ERROR: Could not resolve IP for %server%. Is it a valid address?
    if not "%saved%" == "" echo Delete Server.txt if you wish to stop auto-connecting to this server
    pause
    exit /B 1
  )
) else (
  color 4f
  echo ERROR: Could not resolve IP for %server%. Is it a valid address?
  if not "%saved%" == "" echo Delete Server.txt if you wish to stop auto-connecting to this server
  pause
  exit /B 1
)


:: Give server info, as well as dialog on how to stop auto-connect if currently active
echo Set to connect to %server%
if not "%saved%" == "" echo Delete Server.txt if you wish to stop auto-connecting to this server

:: Rename AdGuardHome.yaml to .bak, prepares for writing new ruleset
move /Y "%cd%\DNS\AdGuardHome\AdGuardHome.yaml" "%CD%\DNS\AdGuardHome\AdGuardHome.yaml.bak" >NUL

:: Go through the old yaml.bak line by line, modify what's needed to update the ruleset, output to new file
for /F "usebackq delims=" %%A in ("%cd%\DNS\AdGuardHome\AdGuardHome.yaml.bak") do (
  if "%%A" == "user_rules: []" (
    echo user_rules:>> "%cd%\DNS\AdGuardHome\AdGuardHome.yaml"
    echo - %ServerIP% hivebedrock.network>> "%cd%\DNS\AdGuardHome\AdGuardHome.yaml"
  ) else (
    if "%%A" == "user_rules:" (
      echo user_rules:>> "%cd%\DNS\AdGuardHome\AdGuardHome.yaml"
      echo - %ServerIP% hivebedrock.network>> "%cd%\DNS\AdGuardHome\AdGuardHome.yaml"
      set /a skipnow=1
	) else (
      if "!skipnow!" == "0" (
        echo.%%A>> "%cd%\DNS\AdGuardHome\AdGuardHome.yaml"
      ) else (
        set /a skipnow=0
      )
    )
  )
)

:: Put the ruleset in filters, probably not necessary
echo %ServerIP% hivebedrock.network>"%CD%\DNS\AdGuardHome\data\filters\0.txt"
echo.

:: Tell user what settings to use for DNS on device
if %ipchanged% == 1 (
  echo DNS SERVER IP CHANGE DETECTED. PLEASE CHANGE YOUR DEVICE DNS SETTINGS.
)
echo.
echo Please add "%NetworkIP%" as the primary DNS on your device,
echo and add "1.1.1.1" as the secondary DNS
echo.
echo.

:launch
  :: Open firstrun.rtf for Instructions for initial AdGuard setup
  if not exist "%CD%\DNS\AdGuardHome\AdGuardHome.yaml" (
    color 8f
    write.exe firstrun.rtf
  )
  
  :: Launch AdGuardHome to do the DNS server
  "%CD%\DNS\AdGuardHome\AdGuardHome.exe"
  pause