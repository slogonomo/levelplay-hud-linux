#!/bin/sh
# Install or remove the levelplay-hud feeder as a systemd service.
#   sudo ./install.sh            install and start
#   sudo ./install.sh uninstall  stop and remove
set -e
cd "$(dirname "$0")"

if [ "$(id -u)" -ne 0 ]; then
    echo "run as root: sudo $0 $*" >&2
    exit 1
fi

if [ "$1" = uninstall ]; then
    systemctl disable --now levelplay-hud.service 2>/dev/null || true
    rm -f /usr/local/bin/levelplay-hud /etc/systemd/system/levelplay-hud.service
    systemctl daemon-reload
    echo "removed"
    exit 0
fi

install -m755 levelplay-hud /usr/local/bin/levelplay-hud
install -m644 levelplay-hud.service /etc/systemd/system/levelplay-hud.service
systemctl daemon-reload
systemctl enable levelplay-hud.service
systemctl restart levelplay-hud.service
echo "installed; check with: systemctl status levelplay-hud"
