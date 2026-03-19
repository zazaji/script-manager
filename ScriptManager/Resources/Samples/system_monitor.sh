# ScriptManager/Resources/Samples/system_monitor.sh
#!/bin/bash
# @Name: System Monitor
# @Desc: Monitors system resources including CPU, Memory, and Disk usage.
# @Author: ScriptManager
# @Version: 1.0.0
# @Param: interval | string | false | 2 | Update interval in seconds
# @Param: count | string | false | 5 | Number of times to update

INTERVAL=${1:-2}
COUNT=${2:-5}

echo "🖥️ Starting System Monitor..."
echo "Interval: $INTERVAL seconds, Count: $COUNT"
echo "----------------------------------------"

for ((i=1; i<=COUNT; i++)); do
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Update $i/$COUNT"
    
    # CPU Usage (macOS specific)
    CPU_IDLE=$(top -l 1 | awk '/CPU usage/ {print $7}' | sed 's/%//')
    CPU_USAGE=$(echo "100 - $CPU_IDLE" | bc)
    echo "📊 CPU Usage: $CPU_USAGE%"
    
    # Memory Usage
    MEM_USED=$(top -l 1 | awk '/PhysMem/ {print $2}')
    MEM_FREE=$(top -l 1 | awk '/PhysMem/ {print $6}')
    echo "🧠 Memory: Used $MEM_USED, Free $MEM_FREE"
    
    # Disk Usage
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}')
    echo "💾 Disk Usage (/): $DISK_USAGE"
    
    echo "----------------------------------------"
    if [ $i -lt $COUNT ]; then
        sleep $INTERVAL
    fi
done

echo "✅ Monitoring completed."