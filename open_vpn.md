# VPN + SFTP File Server User Provisioning Guide

This documentation outlines the process and automation script used to manage VPN users with unique file access restrictions and a shared folder setup. Each user gets:

- An OpenVPN certificate and `.ovpn` configuration
- A unique chrooted SFTP-accessible folder
- Access to a shared folder bind-mounted into their home

---

## What is a VPN?

### Visual Overview:

```
+-------------+         Encrypted Tunnel         +-------------+       +----------------------+
| VPN Client  | ───────────────────────────────> | VPN Server  | ────> | Internal File Access |
| (VMclient)  |                                  | (Debian)    |       | /srv/vpn-users/...   |
+-------------+                                  +-------------+       +----------------------+
```

A **VPN (Virtual Private Network)** creates a secure, encrypted tunnel between a client and a remote server over the internet or a private network. It ensures that all data transmitted between the client and the server is encrypted and protected from eavesdropping.

### Key Benefits:

- Encrypts all traffic between clients and the VPN server
- Masks client IP addresses
- Allows access to internal resources as if the client were on the same local network

---

## What is Easy-RSA?

**Easy-RSA** is a command-line tool that helps manage a Public Key Infrastructure (PKI). It is used to generate:

- A **Certificate Authority (CA)**
- **Server and client certificates**
- **Private keys** and **public certificates**

These components are essential for securing OpenVPN connections through mutual authentication.

---

## Overview of Certificates and Keys

Each OpenVPN connection uses several cryptographic files:

| File Type    | Purpose                                              |
| ------------ | ---------------------------------------------------- |
| `ca.crt`     | The public certificate of the Certificate Authority  |
| `server.crt` | The public certificate for the VPN server            |
| `server.key` | The private key for the VPN server                   |
| `client.crt` | The public certificate for the client                |
| `client.key` | The private key for the client                       |
| `ta.key`     | TLS Authentication key (adds another security layer) |

These files are embedded into the `.ovpn` configuration file used by each client to connect to the VPN.

---

## Key Components of the Project

### Overall System Architecture

```
Each Client VM:
   - Uses OpenVPN to connect to the server
   - Receives a private IP (e.g., 10.8.0.X)
   - Connects via SFTP to upload/download files

Server:
   - Provides encrypted VPN access via OpenVPN
   - Hosts user-specific folders in /srv/vpn-users/<username>/
   - Mounts a common /shared folder inside each user’s jail

Automation:
   - Script provisions new users, certs, folders, mounts, and config
```

- **OpenVPN Server**: Provides encrypted tunnels for clients, using certificate-based authentication generated via Easy-RSA.
- **SFTP over OpenSSH**: Used to give users secure file access. Each user is jailed (chrooted) to their personal folder.
- **Bind-mounted Shared Folder**: A central `/shared` directory is mounted inside each user's chroot so all users can access common files.
- **Automation Script**: A Bash script that creates Linux users, generates VPN credentials, sets permissions, mounts shared folders, and outputs `.ovpn` files.
- **User Isolation and Access Control**: Each VPN client has a private space and a shared space, with permissions ensuring no overlap.

---

## Folder Structure

```
/srv/vpn-users/
├── VMclient/              # User's SFTP jail root
│   ├── files/             # Private folder (read/write for user only)
│   └── shared/            # Bind-mount to global shared folder
├── VMclient2/
│   └── ...
└── shared/                # Shared folder (read/write for all VPN users)
```

---

## Requirements

- OpenVPN with Easy-RSA (cert-based auth)
- OpenSSH server
- Debian or compatible Linux environment
- `sftpusers` group created
- Shared directory: `/srv/vpn-users/shared` with `chmod 1777`

---

## Script: `add_vpn_user_prompt_ip.sh`

### Purpose

Automates the full user setup:

- Creates system user (SFTP-only, jailed)
- Sets file permissions
- Generates OpenVPN client cert & inline `.ovpn`
- Mounts shared folder into chroot
- Adds bind mount to `/etc/fstab`

### Location

Place script in server's admin directory:

```
/srv/scripts/add_vpn_user_prompt_ip.sh
```

Make it executable:

```bash
chmod +x add_vpn_user.sh
```

### How to Use

```bash
sudo ./add_vpn_user.sh <USERNAME>
```

You will be prompted:

```
Enter the VPN server's IP address:
```

The script will:

1. Create Linux user `<USERNAME>`
2. Configure their chroot to `/srv/vpn-users/<USERNAME>`
3. Set up `files/` folder and `shared/` mount
4. Generate OpenVPN certificate and save `.ovpn` to:
   ```
   /srv/vpn-users/<USERNAME>/<USERNAME>.ovpn
   ```

---

## Accessing the Server

### VPN Connection

- Connect using the generated `.ovpn` file
- Use OpenVPN GUI or CLI

### SFTP Connection

```bash
sftp <USERNAME>@10.8.0.1
```

Only the folders `/files/` and `/shared/` will be accessible.

---

## Example

```bash
sudo ./add_vpn_user_prompt_ip.sh VMclient5
```

- Sets up `/srv/vpn-users/VMclient5/`
- Shares `/srv/vpn-users/shared` to `/srv/vpn-users/VMclient5/shared`
- Outputs `/srv/vpn-users/VMclient5/VMclient5.ovpn`

---

## Notes

- The server IP is entered manually for flexibility.
- Each bind mount is appended to `/etc/fstab` automatically.
- Certificates are signed with `echo yes | ./easyrsa build-client-full` to avoid manual confirmation.
- The `.ovpn` file contains inline:
  - CA cert
  - Client cert
  - Client key
  - TLS key

---

## Future Improvements (Optional)

- Automatically send `.ovpn` file to email
- QR code for mobile import
- Centralized user tracking with SQLite or CSV export

---

End of Guide
