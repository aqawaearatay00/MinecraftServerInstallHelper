#!/bin/bash

echo "Would you like to:"
echo "1) Install the latest version of Java Minecraft server"
echo "2) Run your Minecraft server"
echo "3) Exit"

read -p "Choose 1-3: " choice

case "$choice" in
    1)
        echo "Server install selected..."

        # === Prompt for install folder and RAM ===
        read -p "Enter install folder name: " install_folder
        read -p "Enter RAM amount in MB (e.g., 2048): " ram_amount

        # === Install Java, curl, and jq silently ===
        sudo apt update > /dev/null 2>&1 && sudo apt install -y default-jdk curl jq > /dev/null 2>&1
        echo "Updated and installed Java, curl, and jq"

        # === Validate inputs ===
        if [ -z "$install_folder" ]; then
            echo "No folder name provided. Exiting."
            exit 1
        fi

        if ! [[ "$ram_amount" =~ ^[0-9]+$ ]]; then
            echo "Invalid RAM amount. Must be a number. Exiting."
            exit 1
        fi

        # === Detect main non-system user ===
        main_user=$(awk -F: '$3 >= 1000 && $3 < 65534 && $6 ~ /^\/home\// {print $1; exit}' /etc/passwd)
        home_path="/home/$main_user"

        cd "$home_path" || { echo "Failed to cd to $home_path"; exit 1; }
        echo "Now in $PWD"

        # === Create and enter server folder ===
        mkdir -p "$install_folder"
        cd "$install_folder" || { echo "Failed to cd into $install_folder"; exit 1; }
        echo "Made and entered \"$install_folder\""

        # === Fetch latest Minecraft server.jar ===
        latest_version=$(curl -s https://launchermeta.mojang.com/mc/game/version_manifest.json | jq -r '.latest.release')
        version_url=$(curl -s https://launchermeta.mojang.com/mc/game/version_manifest.json | jq -r --arg ver "$latest_version" '.versions[] | select(.id == $ver) | .url')
        server_jar_url=$(curl -s "$version_url" | jq -r '.downloads.server.url')

        curl -s -O "$server_jar_url"
        echo "Downloaded Minecraft server.jar for version $latest_version"

        # === Run server once to generate eula.txt ===
        echo "Launching server briefly to generate eula.txt..."
        java -Xmx${ram_amount}M -Xms${ram_amount}M -jar server.jar nogui > /dev/null 2>&1 &
        server_pid=$!

        timeout=10
        while [ ! -f eula.txt ] && [ $timeout -gt 0 ]; do
            sleep 1
            ((timeout--))
        done

        kill "$server_pid" 2>/dev/null
        sleep 1

        # === Accept EULA ===
        if [ -f eula.txt ]; then
            sed -i 's/eula=false/eula=true/' eula.txt
            echo "Accepted EULA"
        else
            echo "eula.txt not found—doesn't exist"
            exit 1
        fi

        # === Start server silently ===
        echo "Starting server with ${ram_amount}MB RAM...; This may take a while"
        java -Xmx${ram_amount}M -Xms${ram_amount}M -jar server.jar > /dev/null 2>&1 &

        # === Interactive menu ===
        while true; do
            echo ""
            echo "Choose an option:"
            echo "1) Edit server.properties"
            echo "2) Install Playit tunnel"
            echo "3) Run Playit"
            echo "4) Exit"

            read -p "Enter your choice [1-4]: " subchoice

            case "$subchoice" in
                1)
                    if [ -f server.properties ]; then
                        nano server.properties
                    else
                        echo "server.properties not found. Has the server run at least once?"
                    fi
                    ;;
                2)
                    echo "Installing Playit tunnel via apt..."
                    sudo apt update > /dev/null 2>&1 && sudo apt install -y playit > /dev/null 2>&1
                    ;;
                3)
                    echo "Starting Playit"
                    playit
                    ;;
                4)
                    echo "Exiting..."
                    break
                    ;;
                *)
                    echo "Invalid choice. Try again."
                    ;;
            esac
        done
        ;;

    2)
        echo "Server start selected..."
        read -p "Enter folder name where installed: " install_folder
        read -p "Enter RAM amount in MB (e.g., 2048): " ram_amount

        # === Detect main non-system user ===
        main_user=$(awk -F: '$3 >= 1000 && $3 < 65534 && $6 ~ /^\/home\// {print $1; exit}' /etc/passwd)
        home_path="/home/$main_user"

        cd "$home_path" || {
            echo "Failed to cd to $home_path"
            read -p "Press Enter to exit..."
            exit 1
        }

        # === Validate folder name ===
        if [ -z "$install_folder" ]; then
            echo "No folder name provided. Exiting."
            read -p "Press Enter to exit..."
            exit 1
        fi

        # === Enter install folder ===
        cd "$install_folder" || {
            echo "Failed to cd into $install_folder"
            read -p "Press Enter to exit..."
            exit 1
        }

        echo "Now in $PWD"

        if [ ! -f server.jar ]; then
            echo "server.jar not found in $install_folder. Exiting."
            read -p "Press Enter to exit..."
            exit 1
        fi

        echo "Starting server with ${ram_amount}MB RAM; this may take a while..."
        java -Xmx${ram_amount}M -Xms${ram_amount}M -jar server.jar > /dev/null 2>&1 &

        echo "Server is starting; This may take a while"
        sleep 3
        echo "Server has started; Press enter to close"
        read
        ;;
    3)
        echo "Exiting"
        
    ;;

    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac
