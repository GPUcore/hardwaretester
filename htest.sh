#!/bin/bash
# hardwaretester (https://github.com/GPUcore/hardwaretester)
# Improved by: ChatGPT
# Description: Perform CPU, RAM, SSD, and motherboard tests with logging and validation.

LOG_DIR="hardware_test_logs"
mkdir -p "$LOG_DIR"

VALID_TESTS=("cpu" "ram" "ssd" "motherboard")
declare -A TEST_RESULTS

# Colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
RESET="\e[0m"

print_header() {
    echo -e "${CYAN}~~~~~~ Hardware Test Configuration ~~~~~~${RESET}"
    echo "Available tests:"
    for i in "${!VALID_TESTS[@]}"; do
        printf "  (%d) %s\n" $((i + 1)) "${VALID_TESTS[$i]}"
    done
    echo -e "${CYAN}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${RESET}\n"
}

print_requirements() {
    echo -e "${YELLOW}Please ensure the following packages are installed:${RESET}"
    echo "  sudo apt update"
    echo "  sudo apt install stress stress-ng memtester fio dmidecode"
    echo
}

is_valid_test() {
    for valid in "${VALID_TESTS[@]}"; do
        [[ "$valid" == "$1" ]] && return 0
    done
    return 1
}

prompt_for_inputs() {
    read -p "Enter the tests to run in order (comma-separated): " test_order
    test_order=$(echo "$test_order" | tr -d '[:space:]')
    IFS=',' read -ra tests <<< "$test_order"

    for test in "${tests[@]}"; do
        if ! is_valid_test "$test"; then
            echo -e "${RED}Error: Invalid test '$test'. Valid options: ${VALID_TESTS[*]}${RESET}"
            exit 1
        fi
    done

    if [[ " ${tests[*]} " =~ " cpu " ]]; then
        while true; do
            read -p "How many CPU cores to test? " cpu_cores
            [[ "$cpu_cores" =~ ^[1-9][0-9]*$ ]] && break
            echo "Enter a valid positive integer."
        done
    fi

    if [[ " ${tests[*]} " =~ " ram " ]]; then
        while true; do
            read -p "How many GB of RAM to test? " ram_gb
            [[ "$ram_gb" =~ ^[1-9][0-9]*$ ]] && break
            echo "Enter a valid positive integer."
        done
    fi
}

run_cpu_test() {
    SECONDS=0
    echo -e "${CYAN}Running CPU test on $cpu_cores core(s)...${RESET}"
    log_file="$LOG_DIR/cpu_test.log"

    if command -v stress &>/dev/null; then
        stress --cpu "$cpu_cores" --timeout 30s &> "$log_file"
    elif command -v stress-ng &>/dev/null; then
        stress-ng --cpu "$cpu_cores" --timeout 30 --metrics-brief &> "$log_file"
    else
        echo -e "${RED}Missing 'stress' or 'stress-ng'.${RESET}"
        TEST_RESULTS[cpu]="FAIL"
        return
    fi
    echo -e "${GREEN}CPU test complete. Log: $log_file${RESET}"
    TEST_RESULTS[cpu]="PASS"
    echo "Duration: ${SECONDS}s"
}

run_ram_test() {
    SECONDS=0
    echo -e "${CYAN}Running RAM test with $ram_gb GB...${RESET}"
    log_file="$LOG_DIR/ram_test.log"

    if ! command -v memtester &>/dev/null; then
        echo -e "${RED}'memtester' not found.${RESET}"
        TEST_RESULTS[ram]="FAIL"
        return
    fi

    sudo memtester "${ram_gb}G" 1 &> "$log_file"
    echo -e "${GREEN}RAM test complete. Log: $log_file${RESET}"
    TEST_RESULTS[ram]="PASS"
    echo "Duration: ${SECONDS}s"
}

run_ssd_test() {
    SECONDS=0
    echo -e "${CYAN}Running SSD test...${RESET}"
    log_file="$LOG_DIR/ssd_test.log"

    if ! command -v fio &>/dev/null; then
        echo -e "${RED}'fio' not found.${RESET}"
        TEST_RESULTS[ssd]="FAIL"
        return
    fi

    tmpfile=$(mktemp tempfile.XXXXXX)
    fio --name=ssdtest --filename="$tmpfile" --size=512M --bs=4k --rw=readwrite \
        --direct=1 --numjobs=1 --time_based --runtime=30s &> "$log_file"
    rm -f "$tmpfile"

    echo -e "${GREEN}SSD test complete. Log: $log_file${RESET}"
    TEST_RESULTS[ssd]="PASS"
    echo "Duration: ${SECONDS}s"
}

run_motherboard_test() {
    SECONDS=0
    echo -e "${CYAN}Collecting motherboard info...${RESET}"
    log_file="$LOG_DIR/motherboard_info.log"

    if ! command -v dmidecode &>/dev/null; then
        echo -e "${RED}'dmidecode' not found.${RESET}"
        TEST_RESULTS[motherboard]="FAIL"
        return
    fi

    sudo dmidecode -t baseboard &> "$log_file"
    echo -e "${GREEN}Motherboard info saved. Log: $log_file${RESET}"
    TEST_RESULTS[motherboard]="PASS"
    echo "Duration: ${SECONDS}s"
}

print_summary() {
    echo -e "\n${CYAN}======= Test Summary =======${RESET}"
    for test in "${tests[@]}"; do
        result="${TEST_RESULTS[$test]:-SKIPPED}"
        color="${GREEN}"
        [[ "$result" == "FAIL" ]] && color="${RED}"
        printf "%-12s : ${color}%s${RESET}\n" "$test" "$result"
    done
    echo -e "${CYAN}=============================${RESET}\n"
}

# ------------- MAIN SCRIPT START -------------

print_header
print_requirements

# CLI flag: --auto=cpu,ram
if [[ "$1" == --auto=* ]]; then
    IFS=',' read -ra tests <<< "${1#--auto=}"
    for test in "${tests[@]}"; do
        if ! is_valid_test "$test"; then
            echo -e "${RED}Invalid test in auto mode: '$test'${RESET}"
            exit 1
        fi
    done
    cpu_cores=2
    ram_gb=1
else
    prompt_for_inputs
fi

echo -e "\n${CYAN}Starting hardware tests... Logs in $LOG_DIR${RESET}"

for test in "${tests[@]}"; do
    case "$test" in
        cpu) run_cpu_test ;;
        ram) run_ram_test ;;
        ssd) run_ssd_test ;;
        motherboard) run_motherboard_test ;;
    esac
done

print_summary
