#!/bin/bash

# Showing Logo
echo "Showing Animation.."
wget -O loader.sh https://raw.githubusercontent.com/rmndkyl/MandaNode/main/WM/loader.sh && chmod +x loader.sh && sed -i 's/\r$//' loader.sh && ./loader.sh
wget -O logo.sh https://raw.githubusercontent.com/rmndkyl/MandaNode/main/WM/logo.sh && chmod +x logo.sh && sed -i 's/\r$//' logo.sh && ./logo.sh
sleep 4

# Function: Automatically install missing dependencies (git and make)
install_dependencies() {
    for cmd in git make; do
        if ! command -v $cmd &> /dev/null; then
            echo "$cmd is not installed. Installing $cmd..."

            # Detect the OS type and execute the corresponding installation command
            if [[ "$OSTYPE" == "linux-gnu"* ]]; then
                sudo apt update
                sudo apt install -y $cmd
            elif [[ "$OSTYPE" == "darwin"* ]]; then
                brew install $cmd
            else
                echo "Unsupported OS. Please manually install $cmd."
                exit 1
            fi
        fi
    done
    echo "All dependencies have been installed."
}

# Function: Check if Go version >= 1.22.2
check_go_version() {
    if command -v go >/dev/null 2>&1; then
        CURRENT_GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
        MINIMUM_GO_VERSION="1.22.2"

        if [ "$(printf '%s\n' "$MINIMUM_GO_VERSION" "$CURRENT_GO_VERSION" | sort -V | head -n1)" = "$MINIMUM_GO_VERSION" ]; then
            echo "Current Go version meets the requirement: $CURRENT_GO_VERSION"
        else
            echo "Current Go version ($CURRENT_GO_VERSION) is below the required version ($MINIMUM_GO_VERSION). Installing the latest Go."
            install_go
        fi
    else
        echo "Go is not detected. Installing Go."
        install_go
    fi
}

install_go() {
    wget https://go.dev/dl/go1.22.2.linux-amd64.tar.gz
    sudo tar -C /usr/local -xzf go1.22.2.linux-amd64.tar.gz
    export PATH=$PATH:/usr/local/go/bin
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    source ~/.bashrc
    echo "Go installation completed, version: $(go version)"
}

# Function: Check and install Node.js and npm
install_node() {
    echo "npm is not installed. Installing Node.js and npm..."

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        curl -fsSL https://deb.nodesource.com/setup_current.x | sudo -E bash -
        sudo apt-get install -y nodejs
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install node
    else
        echo "Unsupported OS. Please manually install Node.js and npm."
        exit 1
    fi

    echo "Node.js and npm installation completed."
}

# Function: Install pm2
install_pm2() {
    if ! command -v npm &> /dev/null; then
        echo "npm is not installed."
        install_node
    fi

    if ! command -v pm2 &> /dev/null; then
        echo "pm2 is not installed. Installing pm2..."
        npm install -g pm2
    else
        echo "pm2 is already installed."
    fi
}

# Check and automatically install git, make, and Go
install_dependencies
check_go_version
install_pm2

# Function 1: Download, extract, and run help command
download_and_setup() {
    wget https://github.com/hemilabs/heminetwork/releases/download/v0.3.2/heminetwork_v0.3.2_linux_amd64.tar.gz

    # Create target directory (if not exists)
    TARGET_DIR="$HOME/heminetwork"
    mkdir -p "$TARGET_DIR"

    # Extract files to target directory
    tar -xvf heminetwork_v0.3.2_linux_amd64.tar.gz -C "$TARGET_DIR"

    # Change to target directory
    cd "$TARGET_DIR"
    ./popmd --help
    ./keygen -secp256k1 -json -net="testnet" > ~/popm-address.json
}

# Function 2: Set environment variables
setup_environment() {
    cd "$HOME/heminetwork"
    cat ~/popm-address.json

    # Prompt user for private_key and sats/vB values
    read -p "Enter the private_key value: " POPM_BTC_PRIVKEY
    read -p "Enter the sats/vB value: " POPM_STATIC_FEE

    export POPM_BTC_PRIVKEY=$POPM_BTC_PRIVKEY
    export POPM_STATIC_FEE=$POPM_STATIC_FEE
    export POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public
}

# Function 3: Start popmd using pm2
start_popmd() {
    cd "$HOME/heminetwork"
    pm2 start ./popmd --name popmd
    pm2 save
    echo "popmd has been started with pm2."
}

# Function 4: Backup popm-address.json
backup_address() {
    echo "Please save the following locally:"
    cat ~/popm-address.json
}

# Function 5: View logs
view_logs() {
    cd "$HOME/heminetwork"
    pm2 logs popmd
}

# Main menu
main_menu() {
    while true; do
        clear
        echo "Script and tutorial written by Telegram user @rmndkyl, free and open source, do not believe in paid versions"
        echo "============================ Hemi Pop Miner Installation ===================================="
        echo "Node community Telegram channel: https://t.me/layerairdrop"
        echo "Node community Telegram group: https://t.me/layerairdropdiskusi"
        echo "Please select an option:"
        echo "1. Download and setup Heminetwork"
        echo "2. Input private_key and sats/vB"
        echo "3. Start popmd"
        echo "4. Backup address information"
        echo "5. View logs"
        echo "6. Exit"

        read -p "Enter your choice (1-6): " choice

        case $choice in
            1)
                download_and_setup
                ;;
            2)
                setup_environment
                ;;
            3)
                start_popmd
                ;;
            4)
                backup_address
                ;;
            5)
                view_logs
                ;;
            6)
                echo "Exiting the script."
                exit 0
                ;;
            *)
                echo "Invalid option, please try again."
                ;;
        esac
    done
}

# Start main menu
main_menu
