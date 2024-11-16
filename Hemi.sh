#!/bin/bash

# Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Dynamic Variables
HEMI_VERSION="v0.5.0"
HEMI_URL="https://github.com/hemilabs/heminetwork/releases/download/$HEMI_VERSION/heminetwork_${HEMI_VERSION}_linux_amd64.tar.gz"
HEMI_DIR="/root/heminetwork_${HEMI_VERSION}_linux_amd64"
ADDRESS_FILE="$HOME/popm-address.json"
BACKUP_FILE="$HOME/popm-address.json.bak"

# Showing Logo
echo -e "${CYAN}Showing Animation...${NC}"
wget -q -O loader.sh https://raw.githubusercontent.com/rmndkyl/MandaNode/main/WM/loader.sh && chmod +x loader.sh && sed -i 's/\r$//' loader.sh && ./loader.sh
rm -f loader.sh
wget -q -O logo.sh https://raw.githubusercontent.com/rmndkyl/MandaNode/main/WM/logo.sh && chmod +x logo.sh && sed -i 's/\r$//' logo.sh && ./logo.sh
rm -f logo.sh
sleep 4

# Automatically install missing dependencies (git, make, and jq)
install_dependencies() {
    echo -e "${CYAN}Checking and installing missing dependencies...${NC}"
    dependencies=(git make jq)

    for dep in "${dependencies[@]}"; do
        if ! command -v $dep &> /dev/null; then
            echo -e "${YELLOW}Installing missing dependency: $dep...${NC}"
            sudo apt install -y $dep
        else
            echo -e "${GREEN}$dep is already installed.${NC}"
        fi
    done
    echo -e "${GREEN}All dependencies are installed.${NC}"
}

# Check if Go version is >= 1.22.2
check_go_version() {
    if command -v go &> /dev/null; then
        CURRENT_GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
        MINIMUM_GO_VERSION="1.22.2"
        if [ "$(printf '%s\n' "$MINIMUM_GO_VERSION" "$CURRENT_GO_VERSION" | sort -V | head -n1)" = "$MINIMUM_GO_VERSION" ]; then
            echo -e "${GREEN}Go version meets the requirement: $CURRENT_GO_VERSION${NC}"
        else
            echo -e "${YELLOW}Go version ($CURRENT_GO_VERSION) is below the required version ($MINIMUM_GO_VERSION). Updating...${NC}"
            install_go
        fi
    else
        echo -e "${YELLOW}Go is not installed. Installing now...${NC}"
        install_go
    fi
}

install_go() {
    echo -e "${CYAN}Installing Go...${NC}"
    wget -q https://go.dev/dl/go1.22.2.linux-amd64.tar.gz
    sudo tar -C /usr/local -xzf go1.22.2.linux-amd64.tar.gz
    export PATH=$PATH:/usr/local/go/bin
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    source ~/.bashrc
    echo -e "${GREEN}Go installation completed: $(go version)${NC}"
}

# Install Node.js and npm
install_node() {
    echo -e "${CYAN}Checking Node.js and npm installation...${NC}"
    if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
        echo -e "${YELLOW}Installing Node.js and npm...${NC}"
        curl -fsSL https://deb.nodesource.com/setup_current.x | sudo -E bash -
        sudo apt install -y nodejs
        echo -e "${GREEN}Node.js and npm installed successfully.${NC}"
    else
        echo -e "${GREEN}Node.js and npm are already installed.${NC}"
    fi
}

# Install pm2
install_pm2() {
    if ! command -v pm2 &> /dev/null; then
        echo -e "${YELLOW}Installing pm2...${NC}"
        npm install -g pm2
    else
        echo -e "${GREEN}pm2 is already installed.${NC}"
    fi
}

# Generate Key
generate_key() {
    install_dependencies
    check_go_version
    install_pm2

    echo -e "${CYAN}Downloading Hemi Network files...${NC}"
    wget -q "$HEMI_URL" -O "heminetwork_${HEMI_VERSION}_linux_amd64.tar.gz" || {
        echo -e "${RED}Failed to download Hemi Network files.${NC}"
        exit 1
    }

    echo -e "${CYAN}Extracting files...${NC}"
    tar -xzf "heminetwork_${HEMI_VERSION}_linux_amd64.tar.gz" -C /root || {
        echo -e "${RED}Failed to extract Hemi Network files.${NC}"
        exit 1
    }
    rm -f "heminetwork_${HEMI_VERSION}_linux_amd64.tar.gz"

    echo -e "${CYAN}Generating key...${NC}"
    cd "$HEMI_DIR" || { echo -e "${RED}Directory not found: $HEMI_DIR${NC}"; exit 1; }
    chmod +x keygen
    ./keygen -secp256k1 -json -net="testnet" > "$ADDRESS_FILE" || {
        echo -e "${RED}Failed to generate key.${NC}"
        exit 1
    }

    echo -e "${GREEN}Key generation complete. Output file:${NC} $ADDRESS_FILE"
    cat "$ADDRESS_FILE"
    echo -e "${CYAN}Press any key to return to the main menu...${NC}"
    read -n 1 -s
}

# Run Node
run_node() {
    echo -e "${CYAN}Starting Hemi Node...${NC}"
    cd "$HEMI_DIR" || { echo -e "${RED}Directory not found: $HEMI_DIR${NC}"; exit 1; }
    chmod 600 "$ADDRESS_FILE"
    POPM_BTC_PRIVKEY=$(jq -r '.private_key' "$ADDRESS_FILE")

    read -p "Enter sats/vB value from https://mempool.space/testnet: " POPM_STATIC_FEE
    export POPM_BTC_PRIVKEY=$POPM_BTC_PRIVKEY
    export POPM_STATIC_FEE=$POPM_STATIC_FEE
    export POPM_BFG_URL="wss://testnet.rpc.hemi.network/v1/ws/public"

    pm2 start ./popmd --name popmd
    pm2 save
    echo -e "${GREEN}Node started successfully.${NC}"
    echo -e "${CYAN}Press any key to return to the main menu...${NC}"
    read -n 1 -s
}

# Backup Address File
backup_address_json() {
    echo -e "${CYAN}Backing up address file...${NC}"
    cp "$ADDRESS_FILE" "$BACKUP_FILE" && {
        echo -e "${GREEN}Backup completed: $BACKUP_FILE${NC}"
    } || {
        echo -e "${RED}Backup failed. File not found: $ADDRESS_FILE${NC}"
    }
    echo -e "${CYAN}Press any key to return to the main menu...${NC}"
    read -n 1 -s
}

# Import Wallet
import_wallet() {
    echo -e "${CYAN}Importing wallet from popm-address.json...${NC}"

    # Check if the file exists
    if [ ! -f "$ADDRESS_FILE" ]; then
        echo -e "${RED}Error: File not found: $ADDRESS_FILE${NC}"
        echo -e "${CYAN}Please ensure the file exists and try again.${NC}"
        return
    fi

    # Validate and extract wallet details
    local ethereum_address private_key public_key pubkey_hash network
    ethereum_address=$(jq -r '.ethereum_address' "$ADDRESS_FILE")
    private_key=$(jq -r '.private_key' "$ADDRESS_FILE")
    public_key=$(jq -r '.public_key' "$ADDRESS_FILE")
    pubkey_hash=$(jq -r '.pubkey_hash' "$ADDRESS_FILE")
    network=$(jq -r '.network' "$ADDRESS_FILE")

    # Validate extracted fields
    if [[ "$ethereum_address" == "null" || "$private_key" == "null" || "$public_key" == "null" || "$pubkey_hash" == "null" || "$network" == "null" ]]; then
        echo -e "${RED}Error: Invalid wallet file format. Ensure all required fields are present.${NC}"
        return
    fi

    # Display imported wallet details
    echo -e "${GREEN}Wallet successfully imported!${NC}"
    echo -e "${YELLOW}Ethereum Address:${NC} $ethereum_address"
    echo -e "${YELLOW}Network:${NC} $network"
    echo -e "${YELLOW}Private Key:${NC} $private_key"
    echo -e "${YELLOW}Public Key:${NC} $public_key"
    echo -e "${YELLOW}Pubkey Hash:${NC} $pubkey_hash"

    # Optional: Export variables if needed for further usage
    export ETHEREUM_ADDRESS=$ethereum_address
    export PRIVATE_KEY=$private_key
    export PUBLIC_KEY=$public_key
    export PUBKEY_HASH=$pubkey_hash
    export NETWORK=$network

    echo -e "${CYAN}Press any key to return to the main menu...${NC}"
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

# Main Menu
main_menu() {
    while true; do
        clear
        echo -e "${CYAN}Script and tutorial written by Telegram user @rmndkyl, free and open source, do not believe in paid versions${NC}"
        echo -e "${CYAN}============================ Hemi Pop Miner Installation ====================================${NC}"
        echo -e "${CYAN}Node community Telegram channel: https://t.me/layerairdrop${NC}"
        echo -e "${CYAN}Node community Telegram group: https://t.me/layerairdropdiskusi${NC}"
        echo -e "${CYAN}To exit the script, press ctrl + C on the keyboard to exit.${NC}"
        echo -e "${CYAN}Please select an operation to perform:${NC}"
        echo -e "${YELLOW}1) Generate Key/Wallet${NC}"
        echo -e "${YELLOW}2) Run Node${NC}"
        echo -e "${YELLOW}3) Backup/Export Wallet${NC}"
		echo -e "${YELLOW}4) Import Wallet${NC}"
		echo -e "${YELLOW}5) View Logs${NC}"
        echo -e "${YELLOW}6) Exit${NC}"
        read -p "Choose an option: " choice

        case $choice in
            1) generate_key ;;
            2) run_node ;;
            3) backup_address_json ;;
			4) import_wallet ;;
			5) view_logs ;;
            6) exit 0 ;;
            *) echo -e "${RED}Invalid option. Please try again.${NC}" ;;
        esac
    done
}

# Start Script
main_menu
