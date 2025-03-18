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

输出日志like this
 ```
 tail -f /var/log/onecloud_monitor.log
[20250318 18:09:01] | iio_hwmon: 45.93℃ | soc: 45.93℃ | CPU: 25.00% | Mem: 72.42% | Swap: 60.09% | /tmp: 0.00% | /: 27.57%
[20250318 18:09:06] | iio_hwmon: 45.00℃ | soc: 45.31℃ | CPU: 20.00% | Mem: 72.66% | Swap: 60.09% | /tmp: 0.00% | /: 27.57%
[20250318 18:09:10] | iio_hwmon: 45.31℃ | soc: 44.37℃ | CPU: 26.70% | Mem: 72.55% | Swap: 60.09% | /tmp: 0.00% | /: 27.57%
[20250318 18:09:15] | iio_hwmon: 45.31℃ | soc: 46.87℃ | CPU: 26.70% | Mem: 72.81% | Swap: 60.09% | /tmp: 0.00% | /: 27.57%
[20250318 18:09:19] | iio_hwmon: 43.75℃ | soc: 45.00℃ | CPU: 33.30% | Mem: 72.61% | Swap: 60.09% | /tmp: 1.00% | /: 27.57%
[20250318 18:09:24] | iio_hwmon: 44.37℃ | soc: 45.93℃ | CPU: 31.20% | Mem: 72.80% | Swap: 60.09% | /tmp: 0.00% | /: 27.57%
```
