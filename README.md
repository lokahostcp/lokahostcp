<h1 align="center"><a href="https://www.lokahost.com/">Lokahost Control Panel</a></h1>

![lokahostcp Web Interface screenshot](https://storage.lokahost.com/lokahostscreen.png)

<h2 align="center">Lightweight and powerful control panel for the modern web</h2>

<p align="center"><strong>Latest stable release:</strong> Version 1.8.10 | <a href="https://github.com/lokahostcp/lokahostcp/blob/release/CHANGELOG.md">View Changelog</a></p>

<p align="center">
	<a href="https://www.lokahost.com/">Lokahost</a> |
	<a href="https://docs.lokahost.com/">Documentation</a> |
	<a href="https://forum.lokahost.com/">Forum</a>
	<br/><br/>
	<a href="https://drone.lokahost.com/lokahostcp/lokahostcp">
		<img src="https://drone.lokahost.com/api/badges/lokahostcp/lokahostcp/status.svg?ref=refs/heads/main" alt="Drone Status"/>
	</a>
	<a href="https://github.com/lokahostcp/lokahostcp/actions/workflows/lint.yml">
		<img src="https://github.com/lokahostcp/lokahostcp/actions/workflows/lint.yml/badge.svg" alt="Lint Status"/>
	</a>
</p>

## **Welcome!**

Lokahost Control Panel is designed to provide administrators an easy to use web and command line interface, enabling them to quickly deploy and manage web domains, mail accounts, DNS zones, and databases from one central dashboard without the hassle of manually deploying and configuring individual components or services.

## Donate
<br />
Bitcoin (BTC): 3D3h9bn8sGFTpH8prZZ5NYtY8CUBywPzjr<br>
Ethereum (ERC20): 0x7a8d7f7da88e94bcf90ecba94ded6ab318e14ef5<br>
Binance Smart Chain (BEP20): 0xc998315a5e739007ddb0b2c9762fb7c1bff4004d<br>
Solana (SOL): DDQbkwghHxDTngPuiBCCF9eC6HpsEutm3Ryywnscrfp5<br>

## Features and Services

- Apache2 and NGINX with PHP-FPM
- Multiple PHP versions (5.6 - 8.2, 8.1 as default)
- DNS Server (Bind) with clustering capabilities
- POP/IMAP/SMTP mail services with Anti-Virus, Anti-Spam, and Webmail (ClamAV, SpamAssassin, Sieve, Roundcube)
- MariaDB/MySQL and/or PostgreSQL databases
- Let's Encrypt SSL support with wildcard certificates
- Firewall with brute-force attack detection and IP lists (iptables, fail2ban, and ipset).

## Supported platforms and operating systems

- **Debian:** 12, 11, or 10
- **Ubuntu:** 22.04 LTS, 20.04 LTS

**NOTES:**

- Lokahost Control Panel does not support 32 bit operating systems!
- Lokahost Control Panel in combination with OpenVZ 7 or lower might have issues with DNS and/or firewall. If you use a Virtual Private Server we strongly advice you to use something based on KVM or LXC!

## Installing Lokahost Control Panel

- **NOTE:** You must install Lokahost Control Panel on top of a fresh operating system installation to ensure proper functionality.

While we have taken every effort to make the installation process and the control panel interface as friendly as possible (even for new users), it is assumed that you will have some prior knowledge and understanding in the basics how to set up a Linux server before continuing.

### Step 1: Log in

To start the installation, you will need to be logged in as **root** or a user with super-user privileges. You can perform the installation either directly from the command line console or remotely via SSH:

```bash
ssh root@your.server
```

### Step 2: Download

Download the installation script for the latest release:

```bash
wget https://raw.githubusercontent.com/lokahostcp/lokahostcp/release/install/lcp-install.sh
```

If the download fails due to an SSL validation error, please be sure you've installed the ca-certificate package on your system - you can do this with the following command:

```bash
apt-get update && apt-get install ca-certificates
```

### Step 3: Run

To begin the installation process, simply run the script and follow the on-screen prompts:

```bash
bash lcp-install.sh
```

You will receive a welcome email at the address specified during installation (if applicable) and on-screen instructions after the installation is completed to log in and access your server.

### Custom installation

You may specify a number of various flags during installation to only install the features in which you need. To view a list of available options, run:

```bash
bash lcp-install.sh -h
```

Alternatively, You can use <https://lokahost.com/install.html> which allows you to easily generate the installation command via GUI.

## How to upgrade an existing installation

Automatic Updates are enabled by default on new installations of Lokahost Control Panel and can be managed from **Server Settings > Updates**. To manually check for and install available updates, use the apt package manager:

```bash
apt-get update
apt-get upgrade
```

## Issues & Support Requests

- If you encounter a general problem while using Lokahost Control Panel and need help, please [visit our forum](https://forum.lokahost.com/) to search for potential solutions or post a new thread where community members can assist.
- Bugs and other reproducible issues should be filed via GitHub by [creating a new issue report](https://github.com/lokahostcp/lokahostcp/issues) so that our developers can investigate further. Please note that requests for support will be redirected to our forum.

**IMPORTANT: We _cannot_ provide support for requests that do not describe the troubleshooting steps that have already been performed, or for third-party applications not related to Lokahost Control Panel (such as WordPress). Please make sure that you include as much information as possible in your forum posts or issue reports!**

## Contributions

If you would like to contribute to the project, please [read our Contribution Guidelines](https://github.com/lokahostcp/lokahostcp/blob/release/CONTRIBUTING.md) for a brief overview of our development process and standards.

## Copyright

"Lokahost Control Panel", "lokahostcp", and the Lokahost logo are original copyright of lokahost.com and the following restrictions apply:

**You are allowed to:**

- use the names "Lokahost Control Panel", "lokahostcp", or the Lokahost logo in any context directly related to the application or the project. This includes the application itself, local communities and news or blog posts.

**You are not allowed to:**

- sell or redistribute the application under the name "Lokahost Control Panel", "lokahostcp", or similar derivatives, including the use of the Lokahost logo in any brand or marketing materials related to revenue generating activities,
- use the names "Lokahost Control Panel", "lokahostcp", or the Lokahost logo in any context that is not related to the project,
- alter the name "Lokahost Control Panel", "lokahostcp", or the Lokahost logo in any way.

## License

Lokahost Control Panel is licensed under [GPL v3](https://github.com/lokahostcp/lokahostcp/blob/release/LICENSE) license, and is based on the [VestaCP](https://vestacp.com/) project.<br>
