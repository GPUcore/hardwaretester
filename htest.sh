#!/bin/bash
# hardwaretester (https://github.com/GPUcore/hardwaretester)
# author: GPUcore

LOG_DIR="hardware_test_logs"
mkdir -p "$LOG_DIR"

VALID_TESTS=("cpu" "ram" "ssd" "motherboard")

echo "~~~~~~Hardware Test Configuration~~~~~~"
echo "Available tests: cpu, ram, ssd, motherboard"
echo "  (1) cpu"
echo "  (2) ram"
echo "  (3) ssd"
echo "  (4) motherboard"
echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n"

echo -e "Please install all of the following packages before running:\n"
echo "sudo apt update"
echo -e "sudo apt install stress stress-ng memtester fio dmidecode\n"

read -p "Enter the tests to run in order (comma-separated): " test_order
test_order=$(echo "$test_order" | tr -d '[:space:]')

IFS=',' read -ra tests <<< "$test_order"
for test in "${tests[@]}"; do
    if [[ ! " ${VALID_TESTS[*]} " =~ " $test " ]]; then
        echo "Error: Invalid test name '$test'. Please use only: ${VALID_TESTS[*]}"
        exit 1
    fi
done

if [[ " ${tests[*]} " =~ " cpu " ]]; then
    while true; do
        read -p "How many CPU cores would you like to test? " cpu_cores
        if [[ "$cpu_cores" =~ ^[1-9][0-9]*$ ]]; then
            break
        else
            echo "Please enter a positive integer for CPU cores."
        fi
    done
fi

if [[ " ${tests[*]} " =~ " ram " ]]; then
    while true; do
        read -p "How many GB of RAM would you like to test? " ram_gb
        if [[ "$ram_gb" =~ ^[1-9][0-9]*$ ]]; then
            break
        else
            echo "Please enter a positive integer for RAM size."
        fi
    done
fi

echo -e "\nStarting hardware tests... Logs saved in $LOG_DIR"

run_cpu_test() {
    SECONDS=0
    echo "Running CPU test with $cpu_cores core(s)..."
    if ! command -v stress &> /dev/null && ! command -v stress-ng &> /dev/null; then
        echo "'stress' or 'stress-ng' not found. Please install one (e.g. sudo apt install stress)"
        return
    fi
    log_file="$LOG_DIR/cpu_test.log"
    if command -v stress &> /dev/null; then
        stress --cpu "$cpu_cores" --timeout 30s &> "$log_file"
    else
        stress-ng --cpu "$cpu_cores" --timeout 30 --metrics-brief &> "$log_file"
    fi
    echo "CPU test completed. Log: $log_file"
    duration=$SECONDS
    echo "Time taken: ${duration}s"
}

run_ram_test() {
    SECONDS=0
    echo "Running RAM test with $ram_gb GB..."
    if ! command -v memtester &> /dev/null; then
        echo "'memtester' not found. Install it with: sudo apt install memtester"
        return
    fi
    log_file="$LOG_DIR/ram_test.log"
    sudo memtester "${ram_gb}G" 1 &> "$log_file"
    echo "RAM test completed. Log: $log_file"
    duration=$SECONDS
    echo "Time taken: ${duration}s"
}

run_ssd_test() {
    SECONDS=0
    echo "Running SSD test using fio..."
    if ! command -v fio &> /dev/null; then
        echo "'fio' not found. Install it with: sudo apt install fio"
        return
    fi
    log_file="$LOG_DIR/ssd_test.log"
    fio --name=ssdtest --filename=tempfile --size=512M --bs=4k --rw=readwrite \
        --direct=1 --numjobs=1 --time_based --runtime=30s &> "$log_file"
    rm -f tempfile
    echo "SSD test completed. Log: $log_file"
    duration=$SECONDS
    echo "Time taken: ${duration}s"
}

run_motherboard_test() {
    SECONDS=0
    echo "Gathering motherboard information..."
    if ! command -v dmidecode &> /dev/null; then
        echo "'dmidecode' not found. Install it with: sudo apt install dmidecode"
        return
    fi
    log_file="$LOG_DIR/motherboard_info.log"
    sudo dmidecode -t baseboard &> "$log_file"
    echo "Motherboard info saved. Log: $log_file"
    duration=$SECONDS
    echo "Time taken: ${duration}s"
}

for test in "${tests[@]}"; do
    case "$test" in
        "cpu") run_cpu_test ;;
        "ram") run_ram_test ;;
        "ssd") run_ssd_test ;;
        "motherboard") run_motherboard_test ;;
    esac
done

echo -e "\nAll selected tests completed!"
