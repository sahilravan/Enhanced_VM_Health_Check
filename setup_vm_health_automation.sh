# VM Health Check Configuration File
# /etc/vm_health_check.conf

# ===========================================
# THRESHOLD CONFIGURATION
# ===========================================
# Set different threshold levels for each resource
# Values should be between 0-100 (percentage)

# CPU utilization thresholds
CPU_THRESHOLD=60

# Memory utilization thresholds  
MEMORY_THRESHOLD=60

# Disk utilization thresholds
DISK_THRESHOLD=60

# ===========================================
# AWS SNS NOTIFICATION CONFIGURATION
# ===========================================
# Configure AWS SNS for sending notifications
# Make sure AWS CLI is installed and configured

# SNS Topic ARN (replace with your actual topic ARN)
SNS_TOPIC_ARN="arn:aws:sns:us-east-1:123456789012:vm-health-alerts"

# AWS Region
AWS_REGION="us-east-1"

# ===========================================
# LOGGING CONFIGURATION
# ===========================================
# Log file path
LOG_FILE="/var/log/vm_health_check.log"

# ===========================================
# ADVANCED THRESHOLD CONFIGURATION
# ===========================================
# You can set different thresholds for different times
# Uncomment and modify as needed

# Business hours thresholds (9 AM - 5 PM)
# BUSINESS_HOURS_CPU_THRESHOLD=70
# BUSINESS_HOURS_MEMORY_THRESHOLD=70
# BUSINESS_HOURS_DISK_THRESHOLD=80

# Off-hours thresholds (5 PM - 9 AM)
# OFF_HOURS_CPU_THRESHOLD=50
# OFF_HOURS_MEMORY_THRESHOLD=50
# OFF_HOURS_DISK_THRESHOLD=60
