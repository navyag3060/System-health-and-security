#!/bin/bash

cpu_usage() {
    echo "CPU Usage:"
    top -b -n1 | grep "Cpu(s)" | awk '{print "  Usage: " $2 + $4 "%"}'
}

memory_usage() {
    echo "Memory Usage:"
    free -h | awk '/^Mem:/ {print "  Used: " $3 "/" $2}'
}

disk_usage() {
    echo "Disk Usage:"
    df -h | awk '$NF=="/"{print "  Used: " $3 "/" $2 " (" $5 " used)"}'
}

exit_script() {
    echo -e "\nExiting the script."
    exit 0
}


send_memory_usage_email() {
    memory_info=$(free -h | awk '/^Mem:/ {print "Memory Usage:\n  Used: " $3 "/" $2}')
    echo -e "$memory_info" | mail -s "Memory Usage Report" "$EMAIL_ADDRESS"
}

# Function to send an email for login failure
send_login_fail_email() {
    local message="A login attempt failed with incorrect credentials."
    echo "$message" | mail -s "Login Failure Alert" "$EMAIL_ADDRESS"
    if [ $? -eq 0 ]; then
        echo "Login failure email sent successfully."
    else
        echo "Failed to send login failure email. Check your email configuration."
    fi
}

# Authentication function
authenticate() {
    local correct_username="Navya"
    local correct_password="Navya@3060"

    read -p "Username: " username
    read -sp "Password: " password
    echo

    if [[ "$username" == "$correct_username" && "$password" == "$correct_password" ]]; then
        echo "Authentication successful!"
    else
        echo "Invalid credentials. Sending login failure email..."
        send_login_fail_email
        exit 1
    fi
}

trap exit_script SIGINT

read -p "Enter the email address to send login failure reports: " EMAIL_ADDRESS

authenticate

read -p "Do you want to receive memory usage emails? (y/n): " SEND_EMAIL

if [[ "$SEND_EMAIL" == "y" || "$SEND_EMAIL" == "Y" ]]; then
    read -p "Enter the interval in hours to send memory usage reports: " INTERVAL_HOURS
    INTERVAL_SECONDS=$((INTERVAL_HOURS * 3600))
    EMAIL_ENABLED=true
else
    EMAIL_ENABLED=false
fi

SECONDS=0

while true; do
    clear
    echo "System Resource Usage:"
    echo "-----------------------"
    cpu_usage
    memory_usage
    disk_usage
    echo -e "\nPress 'q' to exit."

    read -t 5 -n 1 key

    if $EMAIL_ENABLED && (( SECONDS >= INTERVAL_SECONDS )); then
        send_memory_usage_email
        SECONDS=0
    fi

    if [[ $key = "q" ]]; then
        exit_script
    fi
done


SUSPICIOUS_KEYWORDS=("phish" "malware" "scam" "fake" "secure-login" "verify")

send_alert_email() {
    local website=$1
    echo "Suspicious website detected: $website" | mail -s "Suspicious Website Alert" "$EMAIL_ADDRESS"
    echo "Alert sent for: $website"
}

monitor_traffic() {
    echo "Monitoring network traffic for suspicious websites..."
    echo "Press Ctrl+C to stop."

    sudo tcpdump -l -A 'tcp port 80 or port 53' 2>/dev/null | while read -r line; do
        if [[ "$line" =~ Host:\ ([a-zA-Z0-9.-]+) ]]; then
            url="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ([a-zA-Z0-9.-]+\.[a-zA-Z]{2,}) ]]; then
            url="${BASH_REMATCH[1]}"
        else
            continue
        fi

        for keyword in "${SUSPICIOUS_KEYWORDS[@]}"; do
            if [[ "$url" == *"$keyword"* ]]; then
                echo "Suspicious website detected: $url"
                send_alert_email "$url"
                break
            fi
        done
    done
}

trap "echo 'Exiting monitoring.'; exit 0" SIGINT

monitor_traffic
