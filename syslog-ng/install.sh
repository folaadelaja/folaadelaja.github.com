#!/usr/bin/env bash
set -euo pipefail

# Variables — adjust as needed
SYSLOG_FILE="/var/log/syslog-ng/network.log"
SYSLOG_CONF="/etc/syslog-ng/syslog-ng.conf"
LISTEN_IP="0.0.0.0"
UDP_PORT=514
TCP_PORT=514

echo "Updating package lists…"
apt update

echo "Installing syslog-ng…"
DEBIAN_FRONTEND=noninteractive apt install -y syslog-ng

echo "Backing up original configuration…"
cp "${SYSLOG_CONF}" "${SYSLOG_CONF}.bak"

echo "Writing new configuration to listen on UDP & TCP ports ${UDP_PORT}/${TCP_PORT} on ${LISTEN_IP}…"
cat > "${SYSLOG_CONF}" <<EOF
@version: 3.5

source s_local { system(); internal(); };

source s_network {
    udp(ip("${LISTEN_IP}") port(${UDP_PORT}));
    tcp(ip("${LISTEN_IP}") port(${TCP_PORT}));
};

destination d_netlogs {
    file("${SYSLOG_FILE}"
         log_fifo_size(1000)
         flags(no-parse));
};

log {
    source(s_network);
    destination(d_netlogs);
};
EOF

echo "Creating log file and setting permissions…"
mkdir -p "$(dirname ${SYSLOG_FILE})"
touch "${SYSLOG_FILE}"
chown syslog:adm "${SYSLOG_FILE}"
chmod 640 "${SYSLOG_FILE}"

echo "Configuring firewall (ufw)…"
if command -v ufw >/dev/null 2>&1; then
    ufw allow ${UDP_PORT}/udp
    ufw allow ${TCP_PORT}/tcp
else
    echo "ufw not found – skipping firewall rule creation; ensure ports ${UDP_PORT}/${TCP_PORT} are open."
fi

echo "Restarting syslog-ng service…"
systemctl enable syslog-ng
systemctl restart syslog-ng

echo "Setup complete. Listening on ${LISTEN_IP}:${UDP_PORT} (UDP) and ${LISTEN_IP}:${TCP_PORT} (TCP)."
echo "Incoming logs will be written to: ${SYSLOG_FILE}"
echo "You can monitor with: tail -f ${SYSLOG_FILE}"
