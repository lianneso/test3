@echo off
REM ###############################################################################################
REM Iguana Sudo-Autoinstaller for Windows, using Powershell/DOS.
REM Enter Install Parameters Here
setlocal EnableDelayedExpansion
SET downloadLink="https://dl.interfaceware.com/iguana/windows/6_1_5/iguana_noinstaller_6_1_5_windows_x64.zip"
SET dlName=iguana_noinstaller_6_1_5_windows_x64.zip
SET downloadFolder="C:\Downloads"
SET baseDir="C:\Iguana"
SET installDirBase="ApplicationDir"
SET wDir="C:\Iguana\WorkingDir"
SET Logs="C:\Iguana\LogDir"
SET sName=Iguana 6.1.5
SET sDName=Iguana 6.1.5
SET port=6543
SET RULE_NAME="Iguana Open Port %port%"
REM ###############################################################################################

echo 1. Create Iguana Directories and files
mkdir %baseDir%
mkdir %wDir%
mkdir %Logs%
mkdir %downloadFolder%
cd /d %~dp0
if exist IguanaMainRepo xcopy IguanaMainRepo %wDir%\IguanaMainRepo /e /h /i /y
if exist IguanaEnv.txt xcopy IguanaEnv.txt %wDir%

echo 2. Download and Extract Iguana app files
powershell -Command ^ [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; ^"(New-Object Net.WebClient).DownloadFile('%downloadlink%', '%downloadFolder%\%dlName%')"
@TIMEOUT /t 1 /nobreak>nul
powershell.exe -nologo -noprofile -command "& { Add-Type -A 'System.IO.Compression.FileSystem'; [IO.Compression.ZipFile]::ExtractToDirectory('%downloadFolder%\%dlName%', '%downloadFolder%\%dlName:~0,-4%'); }"
@TIMEOUT /t 1 /nobreak>nul 
cd %downloadFolder%\%dlName:~0,-4%
move iNTERFACEWARE-Iguana %baseDir%
cd %baseDir%
ren iNTERFACEWARE-Iguana %installDirBase%
SET installDIR=%baseDir%\%installDirBase%

echo 3.  Modify the service file to the Iguana working directory
setlocal enableextensions
cd %installDIR%
powershell -Command "(Get-Content iguana_service.hdf).replace('command_line=iguana.exe', 'command_line=iguana.exe --working_dir ""%wDir%""') | Set-Content iguana_service.hdf"
powershell -Command "(Get-Content iguana_service.hdf).replace('service_display_name=iNTERFACEWARE Iguana', 'service_display_name=%sDName%') | Set-Content iguana_service.hdf"
powershell -Command "(Get-Content iguana_service.hdf).replace('service_name=Iguana', 'service_name=%sName%') | Set-Content iguana_service.hdf"
echo Working directory will be %wDir%.
@TIMEOUT /t 1 /nobreak>nul


echo 4. Start and stop Iguana to generate IguanaConfigurationRepo
(
echo cd %installDIR%
echo iguana.exe --run --working_dir %wDir%
echo pause
)>run-iguana.bat
start "run-iguana.bat" run-iguana.bat
@TIMEOUT /t 8 /nobreak>nul
powershell -Command "Get-Process | Where-Object { $_.Name -like 'iguana' } | Stop-Process -Force"
powershell -Command "Get-Process | Where-Object { $_.MainWindowTitle -like '*run-iguana.bat' } | Stop-Process -Force"
@TIMEOUT /t 1 /nobreak>nul

echo 5. Modify the IguanaConfiguration.xml to the update the Iguana log directory
cd %wDir%\IguanaConfigurationRepo
powershell -Command "([regex]'port=.*').Replace((Get-Content 'IguanaConfiguration.xml' -Raw), 'port=""""%port%""""', 1) | Set-Content 'IguanaConfiguration.xml'"
powershell -Command "([regex]'log_directory=.*').Replace((Get-Content 'IguanaConfiguration.xml' -Raw), 'log_directory=""%Logs%"" ', 1) | Set-Content 'IguanaConfiguration.xml'"
@TIMEOUT /t 3 /nobreak>nul


echo 6. Run Iguana Service and install Iguana Services crontab for autostart
cd "%installDIR%"
(
echo cd %installDIR%
echo iguana_service.exe --install
echo pause
)>start-iguana_service.bat
start "start-iguana_service.bat" start-iguana_service.bat
@TIMEOUT /t 3 /nobreak>nul
powershell -Command "Get-Process | Where-Object { $_.MainWindowTitle -like '*start-iguana_service.bat' } | Stop-Process"
net start "%sDName%"

echo 7. Open up the ports in the firewall
netsh advfirewall firewall add rule name=%RULE_NAME% dir=in action=allow protocol=TCP localport=%port%


echo 8. Clean up process
rmdir /s /q %downloadFolder%\%dlName:~0,-4%
del /s /q %downloadFolder%\%dlName%
echo To start using Iguana:
echo         1. Open your Internet browser 
echo         2. Navigate to localhost:%port%  
echo         3. Login and start configuring your Iguana.
echo.
echo If needed, shut down Iguana from Windows Services to change additional parameters.
pause
(goto) 2>nul
