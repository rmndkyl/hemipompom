#!/bin/bash

# Showing Logo
echo "Showing Animation.."
wget -O loader.sh https://raw.githubusercontent.com/rmndkyl/MandaNode/main/WM/loader.sh && chmod +x loader.sh && sed -i 's/\r$//' loader.sh && ./loader.sh
wget -O logo.sh https://raw.githubusercontent.com/rmndkyl/MandaNode/main/WM/logo.sh && chmod +x logo.sh && sed -i 's/\r$//' logo.sh && ./logo.sh
sleep 4

# Script save path
SCRIPT_PATH="$HOME/Hemi.sh"

# Automatically install missing dependencies (git, make, and jq)
install_dependencies() {
    echo "Updating package list..."
    sudo apt update

    for cmd in git make jq; do
        if ! command -v $cmd &> /dev/null; then
            echo "$cmd is not installed. Installing $cmd..."

            # Detect the OS type and run the appropriate install command
            if [[ "$OSTYPE" == "linux-gnu"* ]]; then
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

# Check if Go version is >= 1.22.2
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

# Check and install Node.js and npm
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

# Install pm2
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

# Generate key and install dependencies
generate_key() {
    install_dependencies
    check_go_version
    install_pm2

    URL="https://github.com/hemilabs/heminetwork/releases/download/v0.4.5/heminetwork_v0.4.5_linux_amd64.tar.gz"
    FILENAME="heminetwork_v0.4.5_linux_amd64.tar.gz"
    DIRECTORY="/root/heminetwork_v0.4.5_linux_amd64"
    OUTPUT_FILE="$HOME/popm-address.json"

    echo "Downloading $FILENAME..."
    wget -q "$URL" -O "$FILENAME"

    if [ $? -eq 0 ]; then
        echo "Download complete."
    else
        echo "Download failed."
        exit 1
    fi

    echo "Extracting $FILENAME..."
    tar -xzf "$FILENAME" -C /root

    if [ $? -eq 0 ]; then
        echo "Extraction complete."
    else
        echo "Extraction failed."
        exit 1
    fi

    echo "Removing archive..."
    rm -rf "$FILENAME"

    echo "Entering directory $DIRECTORY..."
    cd "$DIRECTORY" || { echo "Directory $DIRECTORY does not exist."; exit 1; }

    # Check and set permissions for keygen
    if [ -f "keygen" ]; then
        chmod +x "keygen"
    else
        echo "keygen file not found."
        exit 1
    fi
    
    echo "Generating public key..."
    ./keygen -secp256k1 -json -net="testnet" > "$OUTPUT_FILE"

    echo "Public key generated. Output file: $OUTPUT_FILE"
    echo "Displaying the contents of the key file..."
    cat "$OUTPUT_FILE"

    echo "Press any key to return to the main menu..."
    read -n 1 -s
}

# Run node function
run_node() {
    DIRECTORY="$HOME/heminetwork_v0.4.5_linux_amd64"

    echo "Entering directory $DIRECTORY..."
    cd "$DIRECTORY" || { echo "Directory $DIRECTORY does not exist."; exit 1; }

    # Set popm-address.json file permissions to read-write
    if [ -f "$HOME/popm-address.json" ]; then
        echo "Setting permissions for popm-address.json file..."
        chmod 600 "$HOME/popm-address.json"  # Read-write only for the current user
    else
        echo "$HOME/popm-address.json file does not exist."
        exit 1
    fi

    # Display file contents
    cat "$HOME/popm-address.json"

    # Import private_key
    POPM_BTC_PRIVKEY=$(jq -r '.private_key' "$HOME/popm-address.json")
    read -p "Check the sats/vB value on https://mempool.space/testnet and input: " POPM_STATIC_FEE

    export POPM_BTC_PRIVKEY=$POPM_BTC_PRIVKEY
    export POPM_STATIC_FEE=$POPM_STATIC_FEE
    export POPM_BFG_URL="wss://testnet.rpc.hemi.network/v1/ws/public"

    echo "Starting node..."
    pm2 start ./popmd --name popmd
    pm2 save

    echo "Press any key to return to the main menu..."
    read -n 1 -s
}

# Upgrade version function
upgrade_version() {
    URL="https://github.com/hemilabs/heminetwork/releases/download/v0.4.5/heminetwork_v0.4.5_linux_amd64.tar.gz"
    FILENAME="heminetwork_v0.4.3_linux_amd64.tar.gz"
    DIRECTORY="/root/heminetwork_v0.4.3_linux_amd64"
    ADDRESS_FILE="$HOME/popm-address.json"
    BACKUP_FILE="$HOME/popm-address.json.bak"

    echo "Backing up address.json file..."
    if [ -f "$ADDRESS_FILE" ]; then
        cp "$ADDRESS_FILE" "$BACKUP_FILE"
        echo "Backup completed: $BACKUP_FILE"
    else
        echo "address.json file not found, unable to backup."
    fi

    echo "Downloading new version $FILENAME..."
    wget -q "$URL" -O "$FILENAME"

    if [ $? -eq 0 ]; then
        echo "Download completed."
    else
        echo "Download failed."
        exit 1
    fi

    echo "Deleting old version directory..."
    rm -rf "$DIRECTORY"

    echo "Extracting new version..."
    tar -xzf "$FILENAME" -C /root

    if [ $? -eq 0 ]; then
        echo "Extraction completed."
    else
        echo "Extraction failed."
        exit 1
    fi

    echo "Removing archive..."
    rm -rf "$FILENAME"

    # Restore address.json file
    if [ -f "$BACKUP_FILE" ]; then
        cp "$BACKUP_FILE" "$ADDRESS_FILE"
        echo "Restored address.json file: $ADDRESS_FILE"
    else
        echo "Backup file does not exist, unable to restore."
    fi

    echo "Version upgrade completed!"
    echo "Press any key to return to the main menu..."
    read -n 1 -s
}

# Backup address.json function
backup_address_json() {
    ADDRESS_FILE="$HOME/popm-address.json"
    BACKUP_FILE="$HOME/popm-address.json.bak"

    echo "Backing up address.json file..."
    if [ -f "$ADDRESS_FILE" ]; then
        cp "$ADDRESS_FILE" "$BACKUP_FILE"
        echo "Backup completed: $BACKUP_FILE"
    else
        echo "address.json file not found, unable to backup."
    fi

    echo "Press any key to return to the main menu..."
    read -n 1 -s
}

# View logs function
view_logs() {
    DIRECTORY="heminetwork_v0.4.5_linux_amd64"

    echo "Entering directory $DIRECTORY..."
    cd "$HOME/$DIRECTORY" || { echo "Directory $DIRECTORY does not exist."; exit 1; }

    echo "Viewing pm2 logs..."
    pm2 logs popmd

    echo "Press any key to return to the main menu..."
    read -n 1 -s
}

# Main menu function
main_menu() {
    while true; do
        clear
        echo "Script and tutorial written by Telegram user @rmndkyl, free and open source, do not believe in paid versions"
        echo "============================ Hemi Pop Miner Installation ===================================="
        echo "Node community Telegram channel: https://t.me/layerairdrop"
        echo "Node community Telegram group: https://t.me/layerairdropdiskusi"
        echo "To exit the script, press ctrl + C on the keyboard to exit."
        echo "Please select an operation to perform:"
        echo "1) Generate Key"
        echo "2) Run Node"
        echo "3) Upgrade Version (0.4.5)"
        echo "4) Backup address.json"
        echo "5) View Logs"
        echo "6) Exit"
        read -p "Choose an option: " choice

        case $choice in
            1)
                generate_key
                ;;
            2)
                run_node
                ;;
            3)
                upgrade_version
                ;;
            4)
                backup_address_json
                ;;
            5)
                view_logs
                ;;
            6)
                exit 0
                ;;
            *)
                echo "Invalid option, please choose again."
                ;;
        esac
    done
}

# Start the main menu
main_menu
