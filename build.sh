#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Конфигурация
PROJECT_DIR="lab4"
BUILD_DIR="build"
SIM_NAME="simulator"
MON_NAME="monitor"

echo -e "${YELLOW}=== Скрипт сборки и запуска проекта ===${NC}"

# Проверка наличия необходимых инструментов
check_dependencies() {
    if ! command -v git &> /dev/null; then
        echo -e "${RED}Ошибка: git не установлен${NC}"
        exit 1
    fi

    if ! command -v cmake &> /dev/null; then
        echo -e "${RED}Ошибка: cmake не установлен${NC}"
        exit 1
    fi

    if ! command -v make &> /dev/null; then
        echo -e "${RED}Ошибка: make не установлен${NC}"
        exit 1
    fi

    if ! command -v g++ &> /dev/null && ! command -v clang++ &> /dev/null; then
        echo -e "${RED}Ошибка: g++ или clang++ не установлены${NC}"
        exit 1
    fi

    echo -e "${GREEN}Все необходимые инструменты найдены${NC}"
}

# Клонирование или обновление репозитория
pull_from_github() {
    echo -e "${YELLOW}=== Получение исходного кода ===${NC}"
    git pull origin main
}

# Сборка проекта
build_project() {
    echo -e "${YELLOW}=== Сборка проекта ===${NC}"

    # Удаление старой директории сборки
    if [ -d "$BUILD_DIR" ]; then
        echo "Удаление старой сборки..."
        rm -rf "$BUILD_DIR"
    fi

    # Создание директории сборки
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    # Запуск CMake
    echo "Запуск CMake..."
    cmake ..

    if [ $? -ne 0 ]; then
        echo -e "${RED}Ошибка при выполнении CMake${NC}"
        exit 1
    fi

    # Компиляция
    echo "Компиляция проекта..."
    make

    if [ $? -ne 0 ]; then
        echo -e "${RED}Ошибка при компиляции${NC}"
        exit 1
    fi

    cd ../..
    echo -e "${GREEN}Проект успешно собран${NC}"
}

# Запуск проекта
run_project() {
    echo -e "${YELLOW}=== Запуск проекта ===${NC}"

    # Проверка всех возможных путей расположения исполняемых файлов
    DEVICE_SIM=""
    MONITOR=""

    # Проверяем различные варианты расположения
    for path in "$PROJECT_DIR/$BUILD_DIR/$SIM_NAME" \
                "$PROJECT_DIR/$BUILD_DIR/bin/$SIM_NAME" \
                "$PROJECT_DIR/$BUILD_DIR/Release/$SIM_NAME" \
                "./$PROJECT_DIR/$BUILD_DIR/$SIM_NAME"; do
        if [ -f "$path" ]; then
            DEVICE_SIM="$path"
            break
        fi
    done

    for path in "$PROJECT_DIR/$BUILD_DIR/$MON_NAME" \
                "$PROJECT_DIR/$BUILD_DIR/bin/$MON_NAME" \
                "$PROJECT_DIR/$BUILD_DIR/Release/$MON_NAME" \
                "./$PROJECT_DIR/$BUILD_DIR/$MON_NAME"; do
        if [ -f "$path" ]; then
            MONITOR="$path"
            break
        fi
    done

    # Проверка наличия исполняемых файлов
    if [ -z "$DEVICE_SIM" ] || [ ! -f "$DEVICE_SIM" ]; then
        echo -e "${RED}Ошибка: $SIM_NAME не найден${NC}"
        echo -e "${YELLOW}Содержимое $PROJECT_DIR/$BUILD_DIR/:${NC}"
        ls -la "$PROJECT_DIR/$BUILD_DIR/" 2>/dev/null || echo "Директория не найдена"
        exit 1
    fi

    if [ -z "$MONITOR" ] || [ ! -f "$MONITOR" ]; then
        echo -e "${RED}Ошибка: $MON_NAME не найден${NC}"
        echo -e "${YELLOW}Содержимое $PROJECT_DIR/$BUILD_DIR/:${NC}"
        ls -la "$PROJECT_DIR/$BUILD_DIR/" 2>/dev/null || echo "Директория не найдена"
        exit 1
    fi

    echo -e "${GREEN}Исполняемые файлы найдены:${NC}"
    echo "  Симулятор: $DEVICE_SIM"
    echo "  Монитор: $MONITOR"
    echo ""

    # Переход в директорию проекта для создания логов
    cd "$PROJECT_DIR/$BUILD_DIR"

    echo -e "${YELLOW}Запуск симулятора устройства...${NC}"
    "./$SIM_NAME" &
    DEVICE_PID=$!
    echo -e "${GREEN}Симулятор запущен (PID: $DEVICE_PID)${NC}"

    # Небольшая задержка для создания виртуального порта
    sleep 2

    echo -e "${YELLOW}Запуск монитора температуры...${NC}"
    "./$MON_NAME" &
    MONITOR_PID=$!
    echo -e "${GREEN}Монитор запущен (PID: $MONITOR_PID)${NC}"

    cd ../../

    echo ""
    echo -e "${GREEN}=== Проект успешно запущен ===${NC}"
    echo -e "PID симулятора: ${YELLOW}$DEVICE_PID${NC}"
    echo -e "PID монитора: ${YELLOW}$MONITOR_PID${NC}"
    echo ""
    echo -e "${YELLOW}Для остановки проекта выполните:${NC}"
    echo "kill $DEVICE_PID $MONITOR_PID"
    echo ""
    echo -e "${YELLOW}Лог-файлы находятся в:${NC}"
    echo "$PROJECT_DIR/$BUILD_DIR/"
    echo "  - all_measurements.log (все измерения за 24 часа)"
    echo "  - hourly_average.log (средние значения за час за месяц)"
    echo "  - daily_average.log (средние значения за день за год)"
}

# Главная функция
main() {
    check_dependencies
    pull_from_github
    build_project
    run_project
}

# Запуск
main
