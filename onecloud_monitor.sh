#!/bin/bash
# 依賴如下：date find bc
# LOG_PATH  日志文件路径
# INTERVAL  监测间隔时间（秒）
# MAX_LOG_SIZE 日志文件最大大小 (MB)
# SENSOR_LIST 传感器列表，以逗号分隔,在 /sys/class/hwmon/* 下查找
# 温度监测脚本 - 针对 /sys/class/hwmon/ 目录，使用 SENSOR_LIST 指定传感器
# 执行权限：需 root 权限运行

# --- 定义全局变量 ---
LOG_PATH="/var/log/onecloud_monitor.log"  # 日志文件路径
INTERVAL=4                              # 监测间隔时间（秒）
MAX_LOG_SIZE=5                           # 日志文件最大大小 (MB)
# --- 定义传感器匹配规则 ---
SENSOR_LIST="iio_hwmon,soc"          # 传感器列表，以逗号分隔 在 /sys/class/hwmon/* 下查找

# --- 创建日志文件（如果不存在） ---
if ! touch "$LOG_PATH"; then
  echo "Error: Could not create log file '$LOG_PATH' 1>&2"
  exit 1
fi

if ! chmod 644 "$LOG_PATH"; then
  echo "Error: Could not set permissions on new log file '$LOG_PATH' 1>&2"
  exit 1
fi

# --- 检查日志文件大小的函数 ---
rotate_log() {
  local log_file="$1"
  local max_size="$2"  # 以 MB 为单位

  # 获取日志文件大小 (以 MB 为单位)
  local log_size_mb=$(du -m "$log_file" | awk '{print $1}')
  if [ "$log_size_mb" -gt "$max_size" ]; then
    # 日志轮转
    local timestamp=$(date "+%Y%m%d%H%M%S")
    local rotated_log="$log_file.$timestamp"

    if ! mv "$log_file" "$rotated_log"; then
      echo "Error: Could not rotate log file '$log_file' to '$rotated_log'" >> "$LOG_PATH"
      return 1 # Indicate failure
    fi

    if ! touch "$log_file"; then
      echo "Error: Could not create new log file '$log_file'" >> "$LOG_PATH"
      return 1 # Indicate failure
    fi

    if ! chmod 644 "$log_file"; then
      echo "Error: Could not set permissions on new log file '$log_file'" >> "$LOG_PATH"
      return 1 # Indicate failure
    fi
    echo "Log file '$log_file' rotated to '$rotated_log' and new log file created." >> "$LOG_PATH"
  fi
  return 0  # Indicate success
}

# --- 主循环 ---
while true; do
  # 检查日志文件大小，如果超过限制则轮转
  rotate_log "$LOG_PATH" "$MAX_LOG_SIZE"

  # 获取当前时间戳
  timestamp=$(date "+%Y%m%d %H:%M:%S")

  # 初始化传感器温度字符串
  sensor_temps=""

  # 分割传感器列表
  IFS=',' read -r -a SENSORS <<< "$SENSOR_LIST"

  # 循环遍历传感器列表
  for sensor in "${SENSORS[@]}"; do
    # 构建传感器目录路径
    sensor_dir=""
    # 使用更简单的find 命令，方便调试
    for dir in /sys/class/hwmon/*; do
        if [[ -d "$dir" ]]; then
            name_file="$dir/name"
            if [[ -f "$name_file" ]]; then
                sensor_name=$(cat "$name_file" 2>/dev/null)
                #echo "Checking sensor $sensor in $dir, name is $sensor_name" >> "$LOG_PATH"
                if [[ "$sensor_name" == "$sensor" ]]; then
                    sensor_dir="$dir"
                 #   echo "Found sensor $sensor in $dir" >> "$LOG_PATH"
                    break
                fi
            else
                echo "Warning: $name_file does not exist or is not a file." >> "$LOG_PATH"
            fi
        fi
    done

    # 检查传感器目录是否存在
    if [[ -n "$sensor_dir" ]]; then
      # 构建温度文件路径 (请根据实际情况修改文件名)
        temp_file="$sensor_dir/temp1_input"

      # 检查温度文件是否存在
      if [[ -f "$temp_file" ]]; then
        # 读取温度值 (单位为千分之一摄氏度)
        temp_raw=$(cat "$temp_file" 2>/dev/null)
        temp_celsius=$(echo "scale=2; $temp_raw / 1000" | bc)
        if [[ -z "$temp_celsius" || ! "$temp_celsius" =~ ^[0-9.]+$ ]]; then
          temp_celsius="N/A"
          echo "Warning: Could not extract valid temperature value for sensor '$sensor'." >> "$LOG_PATH"
        else
          temp_celsius=$(printf "%.2f" "$temp_celsius")
        fi
        # 添加到传感器温度字符串
        sensor_temps+=" | ${sensor}: ${temp_celsius}℃"
      else
        sensor_temps+=" | ${sensor}: N/A (Temperature file not found)"
        echo "Warning: Temperature file not found for sensor '$sensor' in directory '$sensor_dir'." >> "$LOG_PATH"
      fi
    else
      sensor_temps+=" | ${sensor}: N/A (Sensor directory not found)"
      echo "Warning: Sensor directory not found for sensor '$sensor'." >> "$LOG_PATH"
    fi
  done

  # 获取 CPU 使用率
  cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\) id.*/\1/" | awk '{printf "%.1f", 100 - $1}')
  if [[ -z "$cpu_usage" || ! "$cpu_usage" =~ ^[0-9.]+$ ]]; then
    cpu_usage="N/A"
    echo "Warning: Could not extract valid cpu_usage value." >> "$LOG_PATH"
  else
    cpu_usage=$(printf "%.2f" "$cpu_usage") # 格式化为小数点后两位
  fi

  # 获取内存使用率 (不使用任何文本匹配)
  free_output=$(free | tail -n +2) # 跳过标题行
  mem_line=$(echo "$free_output" | head -n 1) # 获取第一行（内存信息）
  mem_total=$(echo "$mem_line" | awk '{print $2}') # 使用字段编号
  mem_used=$(echo "$mem_line" | awk '{print $3}')  # 使用字段编号

  # 检查 mem_total 是否为零或为空
  if [ -z "$mem_total" ] || [ "$mem_total" -eq "0" ]; then
    mem_usage="0.00"  # 如果 mem_total 为零或为空，则将 mem_usage 设置为 0
  else
    mem_usage=$(echo "scale=2; 100 * $mem_used / $mem_total" | bc) # 计算内存使用率并格式化
    mem_usage=$(printf "%.2f" "$mem_usage")
  fi
  if [[ -z "$mem_usage" || ! "$mem_usage" =~ ^[0-9.]+$ ]]; then
        mem_usage="N/A"
        echo "Warning: Could not extract valid mem_usage value." >> "$LOG_PATH"
  fi
  # 获取 Swap 使用率 (不使用任何文本匹配)
  swap_line=$(echo "$free_output" | tail -n 1) # 获取最后一行（Swap信息）
  swap_total=$(echo "$swap_line" | awk '{print $2}') # 使用字段编号
  swap_used=$(echo "$swap_line" | awk '{print $3}')  # 使用字段编号

  # 检查 mem_total 是否为零或为空
  if [ -z "$swap_total" ] || [ "$swap_total" -eq "0" ]; then
    swap_usage="0.00"
  else
    swap_usage=$(echo "scale=2; 100 * $swap_used / $swap_total" | bc)
    swap_usage=$(printf "%.2f" "$swap_usage")
  fi
  if [[ -z "$swap_usage" || ! "$swap_usage" =~ ^[0-9.]+$ ]]; then
          swap_usage="N/A"
          echo "Warning: Could not extract valid swap_usage value." >> "$LOG_PATH"
  fi

  # 获取 /tmp 磁盘使用率
  tmp_usage=$(df -h /tmp | grep '/tmp' | awk '{print $5}' | tr -d '%') # 删除百分号
  if [[ -z "$tmp_usage" || ! "$tmp_usage" =~ ^[0-9.]+$ ]]; then
      tmp_usage="N/A"
      echo "Warning: Could not extract valid tmp_usage value." >> "$LOG_PATH"
  else
    tmp_usage=$(printf "%.2f" "$tmp_usage")
  fi

  # 获取根目录 / 磁盘使用率
  df_output=$(df -k /)

  root_usage=$((df -k / | tail -n 1 | awk '{print ($3/$2) * 100}')  2>/dev/null)
  if [[ -z "$root_usage" || ! "$root_usage" =~ ^[0-9.]+$ ]]; then
    root_usage="N/A"
    echo "Warning: Could not extract valid root_usage value." >> "$LOG_PATH"
  else
    root_usage=$(printf "%.2f" "$root_usage") # 格式化为小数点后两位
  fi

  # 生成日志条目
  log_entry="[$timestamp]${sensor_temps} | CPU: ${cpu_usage}% | Mem: ${mem_usage}% | Swap: ${swap_usage}% | /tmp: ${tmp_usage}% | /: ${root_usage}%"

  # 写入日志文件
  echo "$log_entry" >> "$LOG_PATH"
  # 等待间隔时间
  sleep $INTERVAL
done
