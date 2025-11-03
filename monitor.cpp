// temperature_monitor.cpp
#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <ctime>
#include <algorithm>
#include <sstream>
#include <iomanip>
#include <thread>
#include <chrono>

struct TemperatureRecord {
    time_t timestamp;
    double temperature;
};

class TemperatureMonitor {
private:
    std::string portFile;
    std::string allMeasurementsLog;
    std::string hourlyAverageLog;
    std::string dailyAverageLog;

    std::vector<TemperatureRecord> currentHourData;
    std::vector<TemperatureRecord> currentDayData;
    time_t lastHourProcess;
    time_t lastDayProcess;

    std::ifstream::pos_type lastPosition;

public:
    TemperatureMonitor(const std::string& port)
        : portFile(port),
          allMeasurementsLog("all_measurements.log"),
          hourlyAverageLog("hourly_average.log"),
          dailyAverageLog("daily_average.log"),
          lastPosition(0) {

        time_t now = time(nullptr);
        struct tm* timeinfo = localtime(&now);
        timeinfo->tm_min = 0;
        timeinfo->tm_sec = 0;
        lastHourProcess = mktime(timeinfo);

        timeinfo->tm_hour = 0;
        lastDayProcess = mktime(timeinfo);
    }

    void run() {
        std::cout << "Монитор температуры запущен" << std::endl;

        while (true) {
            readFromPort();
            checkHourlyAverage();
            checkDailyAverage();
            cleanupLogs();

            std::this_thread::sleep_for(std::chrono::seconds(10));
        }
    }

private:
    std::string formatTime(time_t timestamp) {
        char buffer[80];
        struct tm* timeinfo = localtime(&timestamp);
        strftime(buffer, sizeof(buffer), "%d.%m.%Y %H:%M:%S", timeinfo);
        return std::string(buffer);
    }

    void readFromPort() {
        std::ifstream portStream(portFile);
        if (!portStream.is_open()) {
            std::cerr << "Ошибка: не могу открыть " << portFile << std::endl;
            return;
        }

        portStream.seekg(lastPosition);

        std::string line;
        while (std::getline(portStream, line)) {
            if (line.empty()) continue;

            std::cout << "DEBUG: Прочитана строка: " << line << std::endl;

            std::istringstream iss(line);
            std::string dateStr, timeStr;
            double temperature;

            if (iss >> dateStr >> timeStr >> temperature) {
                std::cout << "DEBUG: Распарсено - дата: " << dateStr
                          << ", время: " << timeStr
                          << ", темп: " << temperature << std::endl;

                // Парсим дату и время обратно в time_t
                struct tm tm_info = {};
                strptime(dateStr.c_str(), "%d.%m.%Y", &tm_info);
                strptime(timeStr.c_str(), "%H:%M:%S", &tm_info);

                TemperatureRecord record;
                record.timestamp = mktime(&tm_info);
                record.temperature = temperature;

                writeToAllMeasurements(record);
                currentHourData.push_back(record);
                currentDayData.push_back(record);

                std::cout << "Получено: " << record.temperature << "°C" << std::endl;
            } else {
                std::cerr << "DEBUG: Не удалось распарсить строку" << std::endl;
            }
        }

        lastPosition = portStream.tellg();
        portStream.close();
    }

    void writeToAllMeasurements(const TemperatureRecord& record) {
        std::cout << "DEBUG: Попытка записи в " << allMeasurementsLog << std::endl;
        std::ofstream logFile(allMeasurementsLog, std::ios::app);
        if (logFile.is_open()) {
            std::string formattedTime = formatTime(record.timestamp);
            std::cout << "DEBUG: Форматированное время: " << formattedTime << std::endl;
            logFile << formattedTime << " "
                    << std::fixed << std::setprecision(2)
                    << record.temperature << std::endl;
            logFile.flush();
            logFile.close();
            std::cout << "DEBUG: Успешно записано" << std::endl;
        } else {
            std::cerr << "DEBUG: Ошибка открытия файла " << allMeasurementsLog << std::endl;
        }
    }


    void checkHourlyAverage() {
        time_t now = time(nullptr);

        if (difftime(now, lastHourProcess) >= 10) {
            // 3600
            if (!currentHourData.empty()) {
                double sum = 0.0;
                for (const auto& record : currentHourData) {
                    sum += record.temperature;
                }
                double average = sum / currentHourData.size();

                writeHourlyAverage(lastHourProcess, average);
                std::cout << "Средняя температура за час: "
                          << average << "°C" << std::endl;

                currentHourData.clear();
            }

            lastHourProcess = now - (now % 3600);
        }
    }

    void checkDailyAverage() {
        time_t now = time(nullptr);
        struct tm* timeinfo = localtime(&now);

        if (timeinfo->tm_hour == 0 && timeinfo->tm_min == 0) {
            if (!currentDayData.empty() &&
                difftime(now, lastDayProcess) >= 30) {
                // 86400
                double sum = 0.0;
                for (const auto& record : currentDayData) {
                    sum += record.temperature;
                }
                double average = sum / currentDayData.size();

                writeDailyAverage(lastDayProcess, average);
                std::cout << "Средняя температура за день: "
                          << average << "°C" << std::endl;

                currentDayData.clear();
                lastDayProcess = now;
            }
        }
    }

    void writeHourlyAverage(time_t timestamp, double average) {
        std::ofstream logFile(hourlyAverageLog, std::ios::app);
        if (logFile.is_open()) {
            logFile << formatTime(timestamp) << " "
                    << std::fixed << std::setprecision(2)
                    << average << std::endl;
            logFile.close();
        }
    }

    void writeDailyAverage(time_t timestamp, double average) {
        std::ofstream logFile(dailyAverageLog, std::ios::app);
        if (logFile.is_open()) {
            logFile << formatTime(timestamp) << " "
                    << std::fixed << std::setprecision(2)
                    << average << std::endl;
            logFile.close();
        }
    }

    void cleanupLogs() {
        time_t now = time(nullptr);

        // Очистка all_measurements.log (24 часа)
        cleanupLogFile(allMeasurementsLog, now - 86400);

        // Очистка hourly_average.log (30 дней)
        cleanupLogFile(hourlyAverageLog, now - (30 * 86400));

        // Очистка daily_average.log (только за текущий год)
        struct tm* timeinfo = localtime(&now);
        timeinfo->tm_mon = 0;
        timeinfo->tm_mday = 1;
        timeinfo->tm_hour = 0;
        timeinfo->tm_min = 0;
        timeinfo->tm_sec = 0;
        time_t yearStart = mktime(timeinfo);

        cleanupLogFile(dailyAverageLog, yearStart);
    }

    void cleanupLogFile(const std::string& filename, time_t cutoffTime) {
        std::ifstream inFile(filename);
        if (!inFile.is_open()) return;

        std::vector<std::string> validLines;
        std::string line;

        while (std::getline(inFile, line)) {
            if (line.empty()) continue;

            std::istringstream iss(line);
            std::string dateStr, timeStr;
            double temperature;

            if (iss >> dateStr >> timeStr >> temperature) {
                // Парсим дату и время обратно в time_t
                struct tm tm_info = {};
                strptime(dateStr.c_str(), "%d.%m.%Y", &tm_info);
                strptime(timeStr.c_str(), "%H:%M:%S", &tm_info);
                time_t timestamp = mktime(&tm_info);

                if (timestamp >= cutoffTime) {
                    validLines.push_back(line);
                }
            }
        }
        inFile.close();

        std::ofstream outFile(filename, std::ios::trunc);
        if (outFile.is_open()) {
            for (const auto& validLine : validLines) {
                outFile << validLine << std::endl;
            }
            outFile.close();
        }
    }
};

int main(int argc, char* argv[]) {
    std::string portFile = "virtual_port.txt";

    if (argc > 1) {
        portFile = argv[1];
    }

    try {
        TemperatureMonitor monitor(portFile);
        monitor.run();
    } catch (const std::exception& e) {
        std::cerr << "Ошибка: " << e.what() << std::endl;
        return 1;
    }
    
    return 0;
}
