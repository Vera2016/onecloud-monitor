# onecloud-monitor
玩客云 温度传感器、cpu、内存、/tmp 、/ 监听脚本

玩客云刷了armbian后，总是无故死机。对于我的机器来说，目前看不是温度导致的，可能是swap导致的，写个脚本监听数据并写入本地日志。再看吧...

脚本参数如下：

- LOG_PATH="YOUR_PATH/onecloud_monitor.log"  # 日志文件路径

- INTERVAL=4         # 监测间隔时间（秒）

- MAX_LOG_SIZE=5        # 日志文件最大大小 (MB)

- SENSOR_LIST="iio_hwmon,soc"    # 传感器列表，以逗号分隔，默认就是玩客云的传感器 其他设备可以在 /sys/class/hwmon/* 下查找
  也可以通过如下代码查找

  ```
  for dir in /sys/class/hwmon/*; do
    if [[ -d "$dir" ]]; then
      echo "--- $dir ---"
      cat "$dir/name" 2>/dev/null
    fi
  done
  ```

  
