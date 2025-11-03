@echo off
setlocal enabledelayedexpansion

REM Цвета для вывода (используем встроенные возможности Windows)
cls

REM Конфигурация
set PROJECT_DIR=temperature-monitoring
set BUILD_DIR=build
set SIM_NAME=device_simulator.exe
set MON_NAME=temperature_monitor.exe

echo.
echo ======================================
echo === Скрипт сборки и запуска проекта ===
echo ======================================
echo.

REM Проверка необходимых инструментов
call :check_dependencies

REM Получение кода из GitHub
call :pull_from_github

REM Сборка проекта
call :build_project

REM Запуск проекта
call :run_project

pause
exit /b 0

REM ========== ФУНКЦИИ ==========

:check_dependencies
    echo [*] Проверка необходимых инструментов...

    where git >nul 2>nul
    if errorlevel 1 (
        echo [ERROR] git не найден в PATH
        exit /b 1
    )

    where cmake >nul 2>nul
    if errorlevel 1 (
        echo [ERROR] cmake не найден в PATH
        exit /b 1
    )

    where cl.exe >nul 2>nul
    if errorlevel 1 (
        where g++ >nul 2>nul
        if errorlevel 1 (
            echo [ERROR] Компилятор не найден (установите Visual Studio или MinGW)
            exit /b 1
        )
    )

    echo [OK] Все необходимые инструменты найдены
    echo.
    exit /b 0

:pull_from_github
    echo [*] Получение исходного кода из GitHub...
    git pull origin main

    echo [OK] Репозиторий успешно получен
    echo.
    exit /b 0

:build_project
    echo [*] Сборка проекта...

    cd /d "%PROJECT_DIR%"

    if exist "%BUILD_DIR%" (
        echo [*] Удаление старой сборки...
        rmdir /s /q "%BUILD_DIR%"
    )

    echo [*] Создание директории сборки...
    mkdir "%BUILD_DIR%"
    cd /d "%BUILD_DIR%"

    echo [*] Запуск CMake...
    cmake ..
    if errorlevel 1 (
        echo [ERROR] Ошибка при выполнении CMake
        exit /b 1
    )

    echo [*] Компиляция проекта...
    if exist "Temperature-monitoring.sln" (
        msbuild Temperature-monitoring.sln /p:Configuration=Release
    ) else (
        cmake --build . --config Release
    )

    if errorlevel 1 (
        echo [ERROR] Ошибка при компиляции
        exit /b 1
    )

    cd ..
    cd ..
    echo [OK] Проект успешно собран
    echo.
    exit /b 0

:run_project
    echo [*] Запуск проекта...

    set DEVICE_SIM=%PROJECT_DIR%\%BUILD_DIR%\Release\%SIM_NAME%
    set MONITOR=%PROJECT_DIR%\%BUILD_DIR%\Release\%MON_NAME%

    if not exist "%DEVICE_SIM%" (
        set DEVICE_SIM=%PROJECT_DIR%\%BUILD_DIR%\%SIM_NAME%
    )

    if not exist "%MONITOR%" (
        set MONITOR=%PROJECT_DIR%\%BUILD_DIR%\%MON_NAME%
    )

    if not exist "%DEVICE_SIM%" (
        echo [ERROR] %DEVICE_SIM% не найден
        exit /b 1
    )

    if not exist "%MONITOR%" (
        echo [ERROR] %MONITOR% не найден
        exit /b 1
    )

    echo [OK] Все исполняемые файлы найдены
    echo.

    cd /d "%PROJECT_DIR%\%BUILD_DIR%"

    echo [*] Запуск симулятора устройства...
    start "Device Simulator" "%DEVICE_SIM%"
    timeout /t 2 /nobreak
    echo [OK] Симулятор запущен

    echo [*] Запуск монитора температуры...
    start "Temperature Monitor" "%MONITOR%"
    echo [OK] Монитор запущен

    cd ..\..

    echo.
    echo ======================================
    echo === Проект успешно запущен ===
    echo ======================================
    echo.
    echo Лог-файлы находятся в:
    echo %PROJECT_DIR%\%BUILD_DIR%\
    echo   - all_measurements.log (все измерения за 24 часа)
    echo   - hourly_average.log (средние значения за час за месяц)
    echo   - daily_average.log (средние значения за день за год)
    echo.
    exit /b 0
