#!/bin/bash


if [ -z "$1" ]; then
    echo "Usage: $0 <username>"
    exit 1
fi

USERNAME="$1"
USERDIR="/srv/vpn-users/$USERNAME"
SHAREDIR="$USERDIR/shared"
REALSHARE="/srv/vpn-users/shared"
EASYRSA_DIR="/home/debian/easy-rsa"

# =====================================================================
read -p "Enter the VPN server's IP address: " SERVER_IP

# =====================================================================
useradd -m -d "$USERDIR" -s /usr/sbin/nologin -G sftpusers "$USERNAME"
echo "User $USERNAME created. Set a password:"
passwd "$USERNAME"

# =====================================================================
chown root:root "$USERDIR"
chmod 755 "$USERDIR"
mkdir -p "$USERDIR/files"
chown "$USERNAME:sftpusers" "$USERDIR/files"

# =====================================================================
mkdir -p "$SHAREDIR"
mkdir -p "$REALSHARE"
mount --bind "$REALSHARE" "$SHAREDIR"

# =====================================================================
grep -q "$SHAREDIR" /etc/fstab || echo "$REALSHARE $SHAREDIR none bind 0 0" >> /etc/fstab

# =====================================================================
cd "$EASYRSA_DIR" || exit 1
echo yes | ./easyrsa build-client-full "$USERNAME" nopass

# =====================================================================
CLIENT_OVPN="/srv/vpn-users/${USERNAME}/${USERNAME}.ovpn"

cat <<EOF > "$CLIENT_OVPN"
client
dev tun
proto udp
remote $SERVER_IP 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
data-ciphers AES-256-CBC
auth SHA256
key-direction 1
verb 3

<ca>
$(cat $EASYRSA_DIR/pki/ca.crt)
</ca>

<cert>
$(cat $EASYRSA_DIR/pki/issued/$USERNAME.crt)
</cert>

<key>
$(cat $EASYRSA_DIR/pki/private/$USERNAME.key)
</key>

<tls-auth>
$(cat /etc/openvpn/server/ta.key)
</tls-auth>
EOF

echo "VPN user $USERNAME added and config saved to $CLIENT_OVPN"
