#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Trap for script interruption
trap 'echo -e "${RED}Script interrupted.${NC}"; exit 1' INT TERM

# Function to print colored status messages
print_status() {
    echo -e "${BLUE}[*] ${NC}$1"
}

print_success() {
    echo -e "${GREEN}[✓] $1${NC}"
}

print_error() {
    echo -e "${RED}[✗] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[!] $1${NC}"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check system requirements
check_system() {
    print_status "Checking system requirements..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        print_warning "This script must be run as root or with sudo privileges"
        exit 1
    fi

    # Check Ubuntu version
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        if [[ "$ID" != "ubuntu" ]]; then
            print_warning "This script is optimized for Ubuntu. Your system: $ID"
        fi
    fi
}

# Function to check system resources
check_resources() {
    print_status "Checking system resources..."
    
    # Check available memory
    total_mem=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$total_mem" -lt 4 ]; then
        print_warning "Recommended minimum 4GB RAM, you have ${total_mem}GB"
    fi
    
    # Check disk space
    free_space=$(df -h . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "${free_space%.*}" -lt 10 ]; then
        print_warning "Low disk space. Recommended minimum 10GB free"
    fi
}

# Function to check for updates
check_updates() {
    print_status "Checking for updates..."
    
    if [ -d "hemi-go" ]; then
        cd hemi-go
        git fetch origin
        local_version=$(git rev-parse HEAD)
        remote_version=$(git rev-parse origin/main)
        
        if [ "$local_version" != "$remote_version" ]; then
            print_warning "New version available. Update? (y/n)"
            read -r update_choice
            if [[ "$update_choice" =~ ^[Yy]$ ]]; then
                git pull origin main
                print_success "Updated to latest version"
            fi
        fi
        cd ..
    fi
}

# Function to install prerequisites
install_prerequisites() {
    print_status "Installing prerequisites..."
    
    # Update package list
    apt-get update -qq
    
    # Install required packages
    PACKAGES="git make snapd curl jq htop"
    apt-get install -y $PACKAGES
    
    if ! command_exists go; then
        print_status "Installing Go..."
        snap install go --classic
    fi
    
    print_success "Prerequisites installed successfully"
}

# Function to backup environment file
backup_env() {
    if [ -f ".env" ]; then
        backup_dir="$HOME/.hemi_backup"
        mkdir -p "$backup_dir"
        cp .env "$backup_dir/.env.backup_$(date +%Y%m%d_%H%M%S)"
        print_success "Environment file backed up"
    fi
}

# Enhanced function to setup Hemi miner with account management
setup_hemi() {
    print_status "Setting up base Hemi miner..."
    
    # Create a base directory for all Hemi instances
    BASE_DIR="$HOME/hemi-miners"
    mkdir -p "$BASE_DIR"
    cd "$BASE_DIR"

    # Clone repository with retry if it doesn't exist
    if [ ! -d "hemi-go-base" ]; then
        if ! git clone https://github.com/rmndkyl/hemi-go.git hemi-go-base; then
            print_error "Failed to clone repository. Retrying..."
            sleep 2
            git clone https://github.com/rmndkyl/hemi-go.git hemi-go-base
        fi
    fi
}

# Function to create and configure a new account instance
create_account_instance() {
    local account_name="$1"
    local account_dir="$BASE_DIR/hemi-$account_name"
    
    print_status "Creating instance for account: $account_name"
    
    # Create new directory and copy base files
    if [ ! -d "$account_dir" ]; then
        cp -r "$BASE_DIR/hemi-go-base" "$account_dir"
        cd "$account_dir"
        
        # Create .env file
        cat > .env << EOL
POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public
EVM_PRIVKEY=your_evm_wallet_private_key
POPM_BTC_PRIVKEY=your_btc_wallet_private_key
POPM_STATIC_FEE=2000
EOL
        print_warning "Please configure wallet keys for $account_name"
        sleep 1
        nano .env
        
        chmod +x start_popmd.sh
        print_success "Instance $account_name created successfully"
    else
        print_warning "Instance $account_name already exists"
    fi
}

# Enhanced function to manage multiple accounts
manage_accounts() {
    while true; do
        clear
        echo -e "${PURPLE}================================${NC}"
        echo -e "${CYAN}    Hemi Account Manager    ${NC}"
        echo -e "${PURPLE}================================${NC}"
        echo -e "${YELLOW}1. Create new account instance${NC}"
        echo -e "${YELLOW}2. List all accounts${NC}"
        echo -e "${YELLOW}3. Start specific account${NC}"
        echo -e "${YELLOW}4. Start all accounts${NC}"
        echo -e "${YELLOW}5. Stop specific account${NC}"
        echo -e "${YELLOW}6. Stop all accounts${NC}"
        echo -e "${YELLOW}7. Check accounts status${NC}"
        echo -e "${YELLOW}8. Edit account configuration${NC}"
        echo -e "${YELLOW}9. Monitor performance${NC}"
        echo -e "${YELLOW}10. Exit${NC}"
        
        read -p "Select an option: " choice
        
        case $choice in
            1)
                read -p "Enter account name (e.g., acc1): " acc_name
                create_account_instance "$acc_name"
                ;;
            2)
                list_accounts
                ;;
            3)
                list_accounts
                read -p "Enter account name to start: " acc_name
                start_specific_account "$acc_name"
                ;;
            4)
                start_all_accounts
                ;;
            5)
                list_accounts
                read -p "Enter account name to stop: " acc_name
                stop_specific_account "$acc_name"
                ;;
            6)
                stop_all_accounts
                ;;
            7)
                check_accounts_status
                ;;
            8)
                edit_account_config
                ;;
            9)
                monitor_all_accounts
                ;;
            10)
                print_success "Exiting account manager"
                exit 0
                ;;
            *)
                print_error "Invalid option"
                ;;
        esac
        
        read -p "Press Enter to continue..."
    done
}

# Function to list all accounts
list_accounts() {
    print_status "Available accounts:"
    for dir in "$BASE_DIR"/hemi-*/; do
        if [ -d "$dir" ]; then
            account_name=$(basename "$dir" | sed 's/hemi-//')
            if pgrep -f "hemi-$account_name/start_popmd" > /dev/null; then
                echo -e "${GREEN}● ${account_name} (Running)${NC}"
            else
                echo -e "${RED}○ ${account_name} (Stopped)${NC}"
            fi
        fi
    done
}

# Function to start specific account
start_specific_account() {
    local account_name="$1"
    local account_dir="$BASE_DIR/hemi-$account_name"
    
    if [ -d "$account_dir" ]; then
        cd "$account_dir"
        screen -dmS "hemi-$account_name" ./start_popmd.sh
        print_success "Started miner for account $account_name"
    else
        print_error "Account $account_name not found"
    fi
}

# Function to start all accounts
start_all_accounts() {
    for dir in "$BASE_DIR"/hemi-*/; do
        if [ -d "$dir" ]; then
            account_name=$(basename "$dir" | sed 's/hemi-//')
            start_specific_account "$account_name"
        fi
    done
}

# Function to stop specific account
stop_specific_account() {
    local account_name="$1"
    pkill -f "hemi-$account_name/start_popmd"
    print_success "Stopped miner for account $account_name"
}

# Function to stop all accounts
stop_all_accounts() {
    pkill -f "hemi-.*start_popmd"
    print_success "Stopped all miners"
}

# Function to check accounts status with detailed info
check_accounts_status() {
    print_status "Accounts Status:"
    for dir in "$BASE_DIR"/hemi-*/; do
        if [ -d "$dir" ]; then
            account_name=$(basename "$dir" | sed 's/hemi-//')
            if pgrep -f "hemi-$account_name/start_popmd" > /dev/null; then
                echo -e "${GREEN}● ${account_name}${NC}"
                screen -ls | grep "hemi-$account_name"
            else
                echo -e "${RED}○ ${account_name} (Stopped)${NC}"
            fi
        fi
    done
}

# Function to edit account configuration
edit_account_config() {
    list_accounts
    read -p "Enter account name to edit: " acc_name
    local account_dir="$BASE_DIR/hemi-$acc_name"
    
    if [ -d "$account_dir" ]; then
        backup_env
        nano "$account_dir/.env"
        print_success "Configuration updated for $acc_name"
    else
        print_error "Account $acc_name not found"
    fi
}

# Function to monitor all accounts performance
monitor_all_accounts() {
    print_status "Monitoring all accounts (Press Ctrl+C to stop)..."
    while true; do
        clear
        echo -e "${PURPLE}================================${NC}"
        echo -e "${CYAN}    Accounts Performance Monitor    ${NC}"
        echo -e "${PURPLE}================================${NC}"
        
        for dir in "$BASE_DIR"/hemi-*/; do
            if [ -d "$dir" ]; then
                account_name=$(basename "$dir" | sed 's/hemi-//')
                if pgrep -f "hemi-$account_name/start_popmd" > /dev/null; then
                    pid=$(pgrep -f "hemi-$account_name/start_popmd")
                    cpu=$(ps -p $pid -o %cpu | tail -n 1)
                    mem=$(ps -p $pid -o %mem | tail -n 1)
                    echo -e "${GREEN}● ${account_name}${NC}"
                    echo -e "   CPU: ${cpu}% | Memory: ${mem}%"
                else
                    echo -e "${RED}○ ${account_name} (Stopped)${NC}"
                fi
            fi
        done
        
        sleep 5
    done
}

# Main execution
clear
echo -e "${PURPLE}================================${NC}"
echo -e "${CYAN}    Hemi Multi-Account Manager     ${NC}"
echo -e "${PURPLE}================================${NC}"

# Execute initial setup
check_system
check_resources
check_updates
install_prerequisites
setup_hemi

# Launch account manager
manage_accounts
