# VPN Setup Manual

This manual provides step-by-step instructions for setting up a VPN connection on various operating systems including Linux, Windows, Android, and iOS. Please follow the instructions specific to your operating system.

## Build
1. git clone 
2. cp .env.example .env
3. Configuration .env. Add username and password, public ip (if the password is the same for everyone, then the password will be "login_password")
4. docker build -t ipsec .
5. Copy docker image name (e.g. docker.io/library/ipsec)
6. Add docker image name to docker-compose.yml (e.g. image: docker.io/library/ipsec)
7. docker compose up -d
8. Copy ca-certs.pem from data/cacerts/ca-cert.pem

## Linux Setup

For Linux users, it's essential to install certain packages and enable the option "Request an inner IP address". Execute the following commands in your terminal:

``` bash 
sudo apt install network-manager-strongswan strongswan strongswan-pki libcharon-extra-plugins libcharon-extauth-plugins
```


**Note:** Ensure that your VPN configuration includes the option to "Request an inner IP address".

## Windows Setup

Windows users need to import a certificate and configure the VPN connection using PowerShell commands. Follow these steps:

1. **Import the Certificate:**

   Open PowerShell as an administrator and execute the following command:


**Note:** Ensure that your VPN configuration includes the option to "Request an inner IP address".

## Windows Setup

Windows users need to import a certificate and configure the VPN connection using PowerShell commands. Follow these steps:

1. **Import the Certificate:**

   Open PowerShell as an administrator and execute the following command:

``` powershell 
Import-Certificate -CertStoreLocation cert:\LocalMachine\Root\ -FilePath C:\ca-cert.pem
```

2. **Add VPN Connection:**

   Still in PowerShell, add the VPN connection with the command below. Replace `"Your_IP_address"` with your actual VPN server IP address.

``` powershell 
Add-VpnConnection -Name "Custom Name Vpn" -ServerAddress "Your_IP_address" -TunnelType "IKEv2" -AuthenticationMethod "EAP" -EncryptionLevel "Maximum" ` -RememberCredential
```

3. **Verify VPN Connection:**

   To ensure the VPN connection was added successfully, use:

``` powershell
 Get-VpnConnection -Name "Custom Name Vpn"
```

4. **Set VPN Connection IPsec Configuration:**

   Finally, configure the IPsec settings with the following command:

``` powershell 
Set-VpnConnectionIPsecConfiguration -Name "Custom Name Vpn" -AuthenticationTransformConstants GCMAES256 -CipherTransformConstants GCMAES256 -DHGroup ECP384 -IntegrityCheckMethod SHA384 -PfsGroup ECP384 -EncryptionMethod GCMAES256
```

## Android Setup

For Android devices, the setup involves installing the StrongSwan VPN Client app from the Google Play Store. After installation, configure the app with your VPN details.

1. Download and install the **StrongSwan VPN Client** from the Google Play Store.
2. Open the app and configure it with your VPN server details.

## iOS Setup

Setting up a VPN on iOS requires downloading a certificate and manually creating a VPN connection.

1. **Download and Install the Certificate:**
   - Download the certificate to your device.
   - Open the downloaded file to initiate the installation.
   - Go to Settings and confirm the profile installation.

2. **Manually Create a VPN Connection:**
   - Go to Settings > General > VPN.
   - Tap on "Add VPN Configuration" and enter your VPN details.

---

**Note:** The instructions provided are based on the input data and are meant to serve as a general guide. Specific details like server addresses, authentication details, and certificate paths need to be replaced with your actual VPN configuration details.
