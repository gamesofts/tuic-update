VERSION="$(/usr/bin/tuic-server --version | awk 'NR==1 {print substr($2,1)}')"
CURRENT_VERSION="v${VERSION#v}"

TMP_FILE="$(mktemp)"
if ! wget -q 'https://api.github.com/repos/Itsusinn/tuic/releases/latest' -O "$TMP_FILE"; then
  "rm" "$TMP_FILE"
  echo 'error: Failed to get release list, please check your network.'
  exit 1
fi
RELEASE_LATEST="$(sed 'y/,/\n/' "$TMP_FILE" | grep 'tag_name' | awk -F '"' '{print substr($4,2)}')"
"rm" "$TMP_FILE"

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --version)
            shift
            if [[ -z "$1" || "$1" == --* ]]; then
                echo "Error: Please specify the correct version."
                exit 1
            fi
            RELEASE_LATEST="$1"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

RELEASE_VERSION="v${RELEASE_LATEST#v}"
if [[ "$RELEASE_VERSION" == "$CURRENT_VERSION" ]]; then
  echo "info: No new version. The current version of tuic server is $CURRENT_VERSION ."
  exit 1
fi

DOWNLOAD_LINK="https://github.com/Itsusinn/tuic/releases/download/${RELEASE_VERSION}/tuic-server-x86_64-linux"
echo "Downloading Tuic Server archive: $DOWNLOAD_LINK"

TMP_DIRECTORY="$(mktemp -d)"
TUIC_FILE="${TMP_DIRECTORY}/tuic-server-x86_64-linux"

if ! wget -q "$DOWNLOAD_LINK" -O "$TUIC_FILE"; then
  echo 'error: Download failed! Please check your network or try again.'
  "rm" -r "$TMP_DIRECTORY"
  exit 1
fi

install -m 755 "${TUIC_FILE}" "/usr/bin/tuic-server"
rm -r "$TMP_DIRECTORY"

if [[ ! -f "/etc/systemd/system/tuic-server.service" ]]; then
  cat >"/etc/systemd/system/tuic-server.service" <<'EOF'
[Unit]
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
ExecStart=/usr/bin/tuic-server -c /etc/tuic/config.toml
Restart=on-failure
RestartSec=10
LimitNPROC=512
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
systemctl enable tuic-server.service
fi

echo "info: tuic server $RELEASE_VERSION is installed."
