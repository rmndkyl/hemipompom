#!/bin/bash

echo "Showing Animation.."
wget -O loader.sh https://raw.githubusercontent.com/rmndkyl/MandaNode/main/WM/loader.sh && chmod +x loader.sh && sed -i 's/\r$//' loader.sh && ./loader.sh
wget -O logo.sh https://raw.githubusercontent.com/rmndkyl/MandaNode/main/WM/logo.sh && chmod +x logo.sh && sed -i 's/\r$//' logo.sh && ./logo.sh
rm -rf logo.sh loader.sh
sleep 4

echo "Updating package list and upgrading installed packages..."
sudo apt update && sudo apt upgrade -y
if [ $? -ne 0 ]; then
  echo "Error updating and upgrading packages. Exiting..."
  exit 1
fi

# Function to print info messages
print_info() {
    echo -e "\e[32m[INFO] $1\e[0m"
}

# Function to print error messages
print_error() {
    echo -e "\e[31m[ERROR] $1\e[0m"
}

# Function to set up the node
setup_node() {
    print_info "Updating system and installing jq..."
    sudo apt-get update && sudo apt-get install -y jq

    print_info "Creating directory /root/hemi..."
    mkdir -p /root/hemi
    cd /root/hemi || { print_error "Failed to change directory to /root/hemi"; exit 1; }

    print_info "Downloading heminetwork..."
    wget --quiet --show-progress https://github.com/hemilabs/heminetwork/releases/download/v0.11.5/heminetwork_v0.11.5_linux_amd64.tar.gz -O heminetwork_v0.11.5_linux_amd64.tar.gz
    if [ $? -ne 0 ]; then
        print_error "Failed to download heminetwork."
        exit 1
    fi

    print_info "Extracting heminetwork..."
    tar -xzf heminetwork_v0.11.5_linux_amd64.tar.gz
    if [ $? -ne 0 ]; then
        print_error "Failed to extract heminetwork."
        exit 1
    fi

    print_info "Changing directory to heminetwork_v0.11.5_linux_amd64..."
    cd heminetwork_v0.11.5_linux_amd64 || { print_error "Failed to change directory to heminetwork_v0.11.5_linux_amd64"; exit 1; }

    print_info "Node setup completed successfully!"

    # Call the node_menu function
    node_menu
}

# Function to create a wallet
create_wallet() {
    if [ -f ~/popm-address.json ]; then
        print_info "Your Wallet Copying to /root/hemi..."
        cp ~/popm-address.json /root/hemi/
        print_info "Wallet already exists at ~/popm-address.json and has been copied to /root/hemi."
    else
        print_info "Creating wallet..."
        cd /root/hemi/heminetwork_v0.11.5_linux_amd64 || { print_error "Failed to change directory"; exit 1; }
        ./keygen -secp256k1 -json -net="testnet" > ~/popm-address.json
        if [ $? -ne 0 ]; then
            print_error "Failed to create wallet."
            exit 1
        fi
        print_info "Wallet created successfully at ~/popm-address.json"
        
        # Copy the newly created wallet to /root/hemi
        sudo cp ~/popm-address.json /root/hemi/
        print_info "Wallet created successfully!"
    fi

    # Call the node_menu function
    node_menu
}

# Function to import an existing wallet from private key
import_wallet() {
    print_info "Import an existing wallet using a private key."
    read -p "Enter your private key: " private_key
    
    if [ -z "$private_key" ]; then
        print_error "Private key cannot be empty."
        node_menu
        return
    fi
    
    # Optionally prompt for other fields
    read -p "Enter Ethereum address (optional): " eth_address
    read -p "Enter public key (optional): " public_key
    read -p "Enter pubkey hash (optional): " pubkey_hash
    
    # Create the JSON structure for the wallet with the complete format
    mkdir -p /root/hemi
    
    cat > ~/popm-address.json <<EOF
{
  "ethereum_address": "$eth_address",
  "network": "testnet",
  "private_key": "$private_key",
  "public_key": "$public_key",
  "pubkey_hash": "$pubkey_hash"
}
EOF
    
    # Copy to the hemi directory
    cp ~/popm-address.json /root/hemi/
    
    print_info "Wallet imported successfully!"
    node_menu
}

# Function to show private key
show_priv_key() {
    if [ -f /root/hemi/popm-address.json ]; then
        # Extract all fields from the wallet file
        private_key=$(jq -r '.private_key // "Not available"' /root/hemi/popm-address.json)
        ethereum_address=$(jq -r '.ethereum_address // "Not available"' /root/hemi/popm-address.json)
        pubkey_hash=$(jq -r '.pubkey_hash // "Not available"' /root/hemi/popm-address.json)
        public_key=$(jq -r '.public_key // "Not available"' /root/hemi/popm-address.json)
        network=$(jq -r '.network // "testnet"' /root/hemi/popm-address.json)
        
        print_info ""
        print_info "Wallet Details:"
        print_info "==============="
        print_info "Network: $network"
        print_info "Private key: $private_key"
        print_info "Ethereum address: $ethereum_address"
        print_info "Public key: $public_key"
        print_info "Public key hash: $pubkey_hash"
        print_info ""
    else
        print_error "Wallet file not found at /root/hemi/popm-address.json."
    fi

    # Call the node_menu function
    node_menu
}

# Function to update service with private key - for a single miner
service_update_single() {
    if [ -f /root/hemi/popm-address.json ]; then
        private_key=$(jq -r '.private_key' /root/hemi/popm-address.json)
        print_info "Setting up Hemi service with private key..."

        # Prompt the user to enter the fee
        read -p "Enter the fee for POPM_STATIC_FEE (default is 8000): " user_fee
        user_fee=${user_fee:-8000} # Use default fee if the user doesn't input a value

        print_info "Using POPM_STATIC_FEE=$user_fee"

        # Define the service file path
        service_file="/etc/systemd/system/hemid.service"

        # Delete the old service file if it exists
        if [ -f $service_file ]; then
            sudo rm -rf $service_file
            print_info "Old Hemi service file deleted."
        fi

        # Write the new service file in the background without echoing
        sudo bash -c "cat > $service_file" <<-EOF
[Unit]
Description=Hemi testnet pop tx Service
After=network.target

[Service]
WorkingDirectory=/root/hemi/heminetwork_v0.11.5_linux_amd64
ExecStart=/root/hemi/heminetwork_v0.11.5_linux_amd64/popmd
Environment="POPM_BTC_PRIVKEY=$private_key"
Environment="POPM_STATIC_FEE=$user_fee"
Environment="POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public"
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

        print_info "Hemi service setup complete."
        
        # Reload systemd and start the service
        sudo systemctl daemon-reload
        sudo systemctl enable hemid
        sudo systemctl start hemid
        print_info "Hemi service started successfully."
    else
        print_error "Wallet file not found at /root/hemi/popm-address.json. Cannot set up service."
    fi

    # Call the node_menu function
    node_menu
}

# Function to update service with multiple miners
service_update_multiple() {
    if [ -f /root/hemi/popm-address.json ]; then
        private_key=$(jq -r '.private_key' /root/hemi/popm-address.json)
        print_info "Setting up multiple Hemi miners..."

        # Prompt the user to enter the fee
        read -p "Enter the fee for POPM_STATIC_FEE (default is 8000): " user_fee
        user_fee=${user_fee:-8000} # Use default fee if the user doesn't input a value

        # Prompt the user for number of miners
        read -p "Enter the number of miners you want to run (1-10): " num_miners
        
        # Validate input
        if ! [[ "$num_miners" =~ ^[1-9]$|^10$ ]]; then
            print_error "Invalid number. Please enter a number between 1 and 10."
            service_update_multiple
            return
        fi

        print_info "Setting up $num_miners miners with POPM_STATIC_FEE=$user_fee"

        # Stop and disable any existing miners
        sudo systemctl stop 'hemid@*' 2>/dev/null
        sudo systemctl disable 'hemid@*' 2>/dev/null

        # Create the template service file
        template_file="/etc/systemd/system/hemid@.service"
        
        sudo bash -c "cat > $template_file" <<-EOF
[Unit]
Description=Hemi testnet pop tx Service %i
After=network.target

[Service]
WorkingDirectory=/root/hemi/heminetwork_v0.11.5_linux_amd64
ExecStart=/root/hemi/heminetwork_v0.11.5_linux_amd64/popmd
Environment="POPM_BTC_PRIVKEY=$private_key"
Environment="POPM_STATIC_FEE=$user_fee"
Environment="POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public"
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

        # Reload systemd
        sudo systemctl daemon-reload

        # Start and enable miners
        for ((i=1; i<=$num_miners; i++)); do
            print_info "Starting miner $i..."
            sudo systemctl enable "hemid@$i"
            sudo systemctl start "hemid@$i"
        done

        print_info "$num_miners Hemi miners started successfully."
    else
        print_error "Wallet file not found at /root/hemi/popm-address.json. Cannot set up service."
    fi

    # Call the node_menu function
    node_menu
}

# Function to refresh all Hemi node services
refresh_node() {
    print_info "Refreshing all Hemi node services..."

    # Reload systemd configuration
    sudo systemctl daemon-reload
    
    # Check if we're using multiple miners
    if systemctl list-units --all | grep -q 'hemid@'; then
        # Restart all instances of the hemid service
        for service in $(systemctl list-units --all | grep 'hemid@' | awk '{print $1}'); do
            sudo systemctl restart "$service"
            print_info "Restarted $service"
        done
    else
        # Restart the single hemid service if it exists
        if systemctl list-units --all | grep -q 'hemid.service'; then
            sudo systemctl restart hemid.service
            print_info "Restarted hemid.service"
        else
            print_error "No Hemi services found to restart."
        fi
    fi
    
    print_info "Hemi node services refreshed and restarted successfully."

    # Call the node_menu function
    node_menu
}

# Function to check logs of the Hemi node services
logs_checker() {
    print_info "Checking logs for Hemi node services..."

    # Check if we're using multiple miners
    if systemctl list-units --all | grep -q 'hemid@'; then
        print_info "Multiple miners detected. Choose an option:"
        print_info "1. Check logs for a specific miner"
        print_info "2. Check logs for all miners"
        read -p "Enter your choice (1 or 2): " log_choice
        
        case $log_choice in
            1)
                read -p "Enter the miner number to check logs for: " miner_num
                if systemctl list-units --all | grep -q "hemid@$miner_num.service"; then
                    sudo journalctl -u "hemid@$miner_num.service" -f -n 50
                else
                    print_error "Miner $miner_num not found."
                    logs_checker
                fi
                ;;
            2)
                # Get all miner service names
                miners=$(systemctl list-units --all | grep 'hemid@' | awk '{print $1}')
                for miner in $miners; do
                    print_info "=== Logs for $miner ==="
                    sudo journalctl -u "$miner" -n 20
                    echo "" # Add a blank line between different miners' logs
                done
                read -p "Press Enter to continue..." dummy
                ;;
            *)
                print_error "Invalid choice."
                logs_checker
                ;;
        esac
    else
        # Display logs for the single hemid service
        sudo journalctl -u hemid.service -f -n 50
    fi

    # Call the node_menu function
    node_menu
}

# Function to stop all miners
stop_miners() {
    print_info "Stopping all Hemi miners..."
    
    # Check if we're using multiple miners
    if systemctl list-units --all | grep -q 'hemid@'; then
        # Stop all instances of the hemid service
        for service in $(systemctl list-units --all | grep 'hemid@' | awk '{print $1}'); do
            sudo systemctl stop "$service"
            sudo systemctl disable "$service"
            print_info "Stopped and disabled $service"
        done
    fi
    
    # Stop the single hemid service if it exists
    if systemctl list-units --all | grep -q 'hemid.service'; then
        sudo systemctl stop hemid.service
        sudo systemctl disable hemid.service
        print_info "Stopped and disabled hemid.service"
    fi
    
    print_info "All Hemi miners stopped successfully."

    # Call the node_menu function
    node_menu
}

# Function to display menu and handle user input
node_menu() {
    print_info "====================================="
    print_info "  Hemi Node Tool Menu    "
    print_info "====================================="
    print_info ""
    print_info "1. Setup-Node"
    print_info "2. Create New Wallet"
    print_info "3. Import Existing Wallet"
    print_info "4. Key-Checker"
    print_info "5. Start Single Miner"
    print_info "6. Start Multiple Miners"
    print_info "7. Refresh All Miners"
    print_info "8. Logs-Checker"
    print_info "9. Stop All Miners"
    print_info "10. Exit"
    print_info ""
    print_info "==============================="
    print_info " Created By : LayerAirdrop "
    print_info "==============================="
    print_info ""  

    # Prompt the user for input
    read -p "Enter your choice (1 to 10): " user_choice
    
    # Handle user input
    case $user_choice in
        1)
            setup_node
            ;;
        2)
            create_wallet
            ;;
        3)
            import_wallet
            ;;
        4)
            show_priv_key
            ;;
        5)
            service_update_single
            ;;
        6)
            service_update_multiple
            ;;
        7)
            refresh_node
            ;;
        8)
            logs_checker
            ;;
        9)
            stop_miners
            ;;
        10)
            print_info "Exiting the script. Goodbye!"
            exit 0
            ;;
        *)
            print_error "Invalid choice. Please enter a number between 1 and 10."
            node_menu # Re-prompt if invalid input
            ;;
    esac
}

# Call the node_menu function
node_menu
