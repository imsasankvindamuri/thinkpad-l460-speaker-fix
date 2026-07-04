#!/usr/bin/env bash
set -euo pipefail

SERVICE_FILE="/etc/systemd/system/fix-speaker.service"
SCRIPT_FILE="/usr/local/libexec/fix-speaker.sh"
SLEEP_HOOK="/usr/lib/systemd/system-sleep/fix-speaker"

if [[ $EUID -ne 0 ]]; then
    echo "Error: Please run this script as root."
    exit 1
fi

uninstall() {
    echo "Removing ThinkPad speaker workaround..."

    systemctl disable --now fix-speaker.service 2>/dev/null || true

    rm -f "$SERVICE_FILE"
    rm -f "$SCRIPT_FILE"
    rm -f "$SLEEP_HOOK"

    systemctl daemon-reload
    systemctl reset-failed

    echo "Done."
}

install() {
    echo "Installing ThinkPad speaker workaround..."

    mkdir -p /usr/local/libexec

    cat >"$SCRIPT_FILE" <<'EOF'
#!/usr/bin/env bash
set -e

sleep 2

/usr/bin/amixer -q -c0 set Speaker 100% unmute
EOF

    chmod 755 "$SCRIPT_FILE"

    cat >"$SERVICE_FILE" <<'EOF'
[Unit]
Description=Restore internal speaker volume after boot
After=sound.target

[Service]
Type=oneshot
ExecStart=/usr/local/libexec/fix-speaker.sh

[Install]
WantedBy=multi-user.target
EOF

    mkdir -p /usr/lib/systemd/system-sleep

    cat >"$SLEEP_HOOK" <<'EOF'
#!/bin/sh

case "$1" in
    post)
        /usr/local/libexec/fix-speaker.sh
        ;;
esac
EOF

    chmod 755 "$SLEEP_HOOK"

    systemctl daemon-reload
    systemctl enable fix-speaker.service

    echo
    echo "Installation complete."
    echo
    echo "This workaround will:"
    echo "  • wait 2 seconds after boot,"
    echo "  • set the Speaker control to 100%,"
    echo "  • unmute the Speaker control,"
    echo "  • repeat the same operation after every suspend/resume."
}

case "${1:-}" in
    --uninstall)
        uninstall
        ;;
    ""|--install)
        install
        ;;
    *)
        cat <<EOF
Usage:
  sudo $0            Install the workaround
  sudo $0 --install  Install the workaround
  sudo $0 --uninstall  Remove the workaround
EOF
        exit 1
        ;;
esac
