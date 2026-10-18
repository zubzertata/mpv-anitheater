@echo off
chcp 65001 >nul
echo ========================================================
echo  MPV Portable - Descargador de FFmpeg para Windows
echo ========================================================
echo.
echo FFmpeg es necesario para extraer pistas de subtitulos internas
echo de videos (MKV/MP4) para su traduccion automatica.
echo.
echo Comprobando si FFmpeg ya esta disponible en el sistema...
where ffmpeg >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo [OK] FFmpeg ya esta instalado en el sistema (PATH).
    echo No es necesario descargar nada.
    echo.
    pause
    exit /b 0
)

if exist "%~dp0portable_config\ffmpeg.exe" (
    echo [OK] ffmpeg.exe ya existe en portable_config\
    echo.
    pause
    exit /b 0
)

echo No se encontro FFmpeg en el sistema.
echo Descargando version ligera y portable de FFmpeg (GPL essentials)...
echo Espere un momento por favor...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ProgressPreference = 'SilentlyContinue';" ^
    "$url = 'https://github.com/GyanD/codexffmpeg/releases/download/7.1/ffmpeg-7.1-essentials_build.zip';" ^
    "$zip = Join-Path $env:TEMP 'ffmpeg_build.zip';" ^
    "$extract = Join-Path $env:TEMP 'ffmpeg_extracted';" ^
    "Write-Host 'Descargando archivo ZIP...';" ^
    "Invoke-WebRequest -Uri $url -OutFile $zip;" ^
    "Write-Host 'Extrayendo ffmpeg.exe...';" ^
    "Expand-Archive -Path $zip -DestinationPath $extract -Force;" ^
    "$bin = Get-ChildItem -Path $extract -Filter 'ffmpeg.exe' -Recurse | Select-Object -First 1;" ^
    "if ($bin) { Copy-Item $bin.FullName -Destination '%~dp0portable_config\ffmpeg.exe' -Force; Write-Host '[OK] ffmpeg.exe copiado exitosamente a portable_config\' -ForegroundColor Green } else { Write-Host '[ERROR] No se pudo extraer ffmpeg.exe' -ForegroundColor Red };" ^
    "Remove-Item $zip -Force -ErrorAction SilentlyContinue;" ^
    "Remove-Item $extract -Recurse -Force -ErrorAction SilentlyContinue;"

echo.
if exist "%~dp0portable_config\ffmpeg.exe" (
    echo Instalacion completada con exito.
) else (
    echo Ocurrio un inconveniente al descargar. Si tienes FFmpeg instalado en Windows,
    echo simplemente asegurate de que este en tu PATH.
)
echo.
pause
