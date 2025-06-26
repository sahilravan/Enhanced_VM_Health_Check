#!/bin/bash

# enhanced_vm_health_check.sh - Enhanced Virtual Machine Health Check Script
# This script checks CPU, memory, and disk utilization on an Ubuntu VM
# Features: Dynamic thresholds, logging, notifications, and automation support

# Configuration file path
CONFIG_FILE="/etc/vm_health_check.conf"
LOG_FILE="/var/log/vm_health_check.log"

# Default thresholds (can be overridden by config file or command line)
DEFAULT_CPU_THRESHOLD=60
DEFAULT_MEMORY_THRESHOLD=60
DEFAULT_DISK_THRESHOLD=60

# SNS Configuration (set these in config file or environment variables)
SNS_TOPIC_ARN=""
AWS_REGION="us-east-1"

# Function to display usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  explain                    Display detailed explanation of health status"
    echo "  --cpu-threshold N          Set CPU threshold percentage (default: 60)"
    echo "  --memory-threshold N       Set memory threshold percentage (default: 60)"
    echo "  --disk-threshold N         Set disk threshold percentage (default: 60)"
    echo "  --config FILE              Use specific configuration file"
    echo "  --log FILE                 Use specific log file"
    echo "  --notify                   Send SNS notifications if unhealthy"
    echo "  --silent                   Run in silent mode (no output, only logging)"
    echo "  --setup-cron               Setup automated cron job"
    echo "  --help                     Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0 explain --notify"
    echo "  $0 --cpu-threshold 80 --memory-threshold 70"
    echo "  $0 --silent --notify"
    exit 1
}

# Function to log messages
log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" >> "$LOG_FILE"
}

# Function to load configuration from file
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        log_message "Configuration loaded from $CONFIG_FILE"
    fi
}

# Function to get CPU utilization percentage
get_cpu_usage() {
    # Get CPU idle percentage and subtract from 100 to get utilization
    cpu_idle=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | sed 's/%id,//')
    if [ -z "$cpu_idle" ]; then
        cpu_idle=$(top -bn1 | grep "%Cpu" | awk '{print $8}' | sed 's/%id,//')
    fi
    cpu_usage=$(echo "100 - $cpu_idle" | bc 2>/dev/null)
    if [ -z "$cpu_usage" ]; then
        cpu_usage=0
    fi
    printf "%.0f" $cpu_usage
}

# Function to get memory utilization percentage
get_memory_usage() {
    # Use free command to get memory stats
    memory_info=$(free | grep Mem)
    total_memory=$(echo $memory_info | awk '{print $2}')
    used_memory=$(echo $memory_info | awk '{print $3}')
    if [ "$total_memory" -gt 0 ]; then
        memory_usage=$(echo "scale=2; $used_memory * 100 / $total_memory" | bc 2>/dev/null)
    else
        memory_usage=0
    fi
    printf "%.0f" $memory_usage
}

# Function to get disk utilization percentage
get_disk_usage() {
    # Get usage of root filesystem
    disk_usage=$(df / | grep -E '/$' | awk '{print $5}' | sed 's/%//')
    if [ -z "$disk_usage" ]; then
        disk_usage=0
    fi
    echo $disk_usage
}

# Function to determine threshold level and severity
get_threshold_level() {
    local usage=$1
    local warning_threshold=$2
    local critical_threshold=$((warning_threshold + 20))
    
    if [ "$usage" -ge "$critical_threshold" ]; then
        echo "CRITICAL"
    elif [ "$usage" -ge "$warning_threshold" ]; then
        echo "WARNING"
    else
        echo "OK"
    fi
}

# Function to send SNS notification
send_sns_notification() {
    local subject="$1"
    local message="$2"
    
    if [ -n "$SNS_TOPIC_ARN" ] && command -v aws >/dev/null 2>&1; then
        aws sns publish \
            --topic-arn "$SNS_TOPIC_ARN" \
            --subject "$subject" \
            --message "$message" \
            --region "$AWS_REGION" >/dev/null 2>&1
        
        if [ $? -eq 0 ]; then
            log_message "SNS notification sent successfully"
        else
            log_message "Failed to send SNS notification"
        fi
    else
        log_message "SNS notification skipped - AWS CLI not available or SNS_TOPIC_ARN not set"
    fi
}

# Function to setup cron job
setup_cron() {
    local script_path=$(realpath "$0")
    local cron_entry="*/5 * * * * $script_path --silent --notify"
    
    echo "Setting up cron job for automated monitoring..."
    
    # Add cron job if it doesn't exist
    (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
    
    if [ $? -eq 0 ]; then
        echo "Cron job added successfully. The script will run every 5 minutes."
        echo "Cron entry: $cron_entry"
        log_message "Cron job setup completed"
    else
        echo "Failed to setup cron job"
        log_message "Failed to setup cron job"
        exit 1
    fi
}

# Function to create default configuration file
create_default_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        sudo tee "$CONFIG_FILE" > /dev/null <<EOF
# VM Health Check Configuration File
# Threshold values (percentage)
CPU_THRESHOLD=60
MEMORY_THRESHOLD=60
DISK_THRESHOLD=60

# SNS Configuration
SNS_TOPIC_ARN=""
AWS_REGION="us-east-1"

# Logging
LOG_FILE="/var/log/vm_health_check.log"
EOF
        echo "Default configuration file created at $CONFIG_FILE"
        echo "Please edit the configuration file to set your SNS topic ARN and other preferences."
    fi
}

# Initialize variables
explain=false
notify=false
silent=false
cpu_threshold=$DEFAULT_CPU_THRESHOLD
memory_threshold=$DEFAULT_MEMORY_THRESHOLD
disk_threshold=$DEFAULT_DISK_THRESHOLD

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        explain)
            explain=true
            shift
            ;;
        --cpu-threshold)
            cpu_threshold="$2"
            shift 2
            ;;
        --memory-threshold)
            memory_threshold="$2"
            shift 2
            ;;
        --disk-threshold)
            disk_threshold="$2"
            shift 2
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --log)
            LOG_FILE="$2"
            shift 2
            ;;
        --notify)
            notify=true
            shift
            ;;
        --silent)
            silent=true
            shift
            ;;
        --setup-cron)
            setup_cron
            exit 0
            ;;
        --help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Load configuration file
load_config

# Override with config file values if they exist
cpu_threshold=${CPU_THRESHOLD:-$cpu_threshold}
memory_threshold=${MEMORY_THRESHOLD:-$memory_threshold}
disk_threshold=${DISK_THRESHOLD:-$disk_threshold}

# Ensure log directory exists
sudo mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
sudo touch "$LOG_FILE" 2>/dev/null

# Get utilization values
cpu_usage=$(get_cpu_usage)
memory_usage=$(get_memory_usage)
disk_usage=$(get_disk_usage)

# Log the check
log_message "Health check started - CPU: ${cpu_usage}%, Memory: ${memory_usage}%, Disk: ${disk_usage}%"

# Determine health status using if-else logic for different threshold levels
cpu_level=$(get_threshold_level "$cpu_usage" "$cpu_threshold")
memory_level=$(get_threshold_level "$memory_usage" "$memory_threshold")
disk_level=$(get_threshold_level "$disk_usage" "$disk_threshold")

# Determine overall health status
if [ "$cpu_level" = "CRITICAL" ] || [ "$memory_level" = "CRITICAL" ] || [ "$disk_level" = "CRITICAL" ]; then
    health_status="CRITICAL"
    status_message="Critical resource utilization detected"
elif [ "$cpu_level" = "WARNING" ] || [ "$memory_level" = "WARNING" ] || [ "$disk_level" = "WARNING" ]; then
    health_status="WARNING"
    status_message="Warning: High resource utilization"
else
    health_status="HEALTHY"
    status_message="All resources within normal limits"
fi

# Create notification message if needed
if [ "$health_status" != "HEALTHY" ] && [ "$notify" = true ]; then
    notification_subject="VM Health Alert: $health_status"
    notification_message="VM Health Status: $health_status

Resource Utilization:
- CPU: ${cpu_usage}% (Threshold: ${cpu_threshold}%) - $cpu_level
- Memory: ${memory_usage}% (Threshold: ${memory_threshold}%) - $memory_level
- Disk: ${disk_usage}% (Threshold: ${disk_threshold}%) - $disk_level

$status_message

Timestamp: $(date)"

    send_sns_notification "$notification_subject" "$notification_message"
fi

# Display output unless in silent mode
if [ "$silent" = false ]; then
    echo "VM Health Status: $health_status"
    
    if [ "$explain" = true ]; then
        echo ""
        echo "Health Status Explanation:"
        echo "-------------------------"
        echo "CPU Usage: ${cpu_usage}% (Threshold: ${cpu_threshold}%) - $cpu_level"
        echo "Memory Usage: ${memory_usage}% (Threshold: ${memory_threshold}%) - $memory_level"
        echo "Disk Usage: ${disk_usage}% (Threshold: ${disk_threshold}%) - $disk_level"
        echo ""
        echo "Overall Status: $status_message"
        
        if [ "$health_status" != "HEALTHY" ]; then
            echo ""
            echo "Recommendations:"
            [ "$cpu_level" != "OK" ] && echo "- CPU: Consider optimizing CPU-intensive processes or scaling up CPU resources"
            [ "$memory_level" != "OK" ] && echo "- Memory: Consider freeing up memory or adding more RAM"
            [ "$disk_level" != "OK" ] && echo "- Disk: Consider cleaning up disk space or expanding storage"
        fi
    fi
fi

# Log the result
log_message "Health check completed - Status: $health_status"

exit 0
