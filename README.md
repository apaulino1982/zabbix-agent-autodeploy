# Zabbix Agent Auto-Deploy for Windows

![PowerShell](https://img.shields.io/badge/PowerShell-%235391FE.svg?style=for-the-badge&logo=powershell&logoColor=white)
![Zabbix](https://img.shields.io/badge/Zabbix-%23CC0000.svg?style=for-the-badge&logo=zabbix&logoColor=white)

Automated deployment script for Zabbix Agent on Windows systems using network share distribution.

## ⚡ Features

- ✅ Automatic elevation to Administrator
- ✅ Network share-based distribution
- ✅ Auto-registration with HostMetadata
- ✅ Clean removal of previous versions
- ✅ Comprehensive logging and error handling
- ✅ Service configuration and automatic startup

## 🛠️ Pre-requisites

### 1. Network Share Setup
Create a network share containing:

\SERVER\Scripts\ZabbixAgent
├── zabbix_agent-7.2.3-windows-amd64-openssl.msi
└── (other agent versions if needed)

### 2. Zabbix Server Configuration
Configure auto-registration on your Zabbix Server:

**Actions → Auto registration → Create Action**

**Conditions:**
- Host metadata contains `Windows`

**Operations:**
- Add to hosts: `Windows Servers`
- Link to template: `Template OS Windows by Zabbix agent`

## 🚀 Quick Start

### Basic Usage
```powershell
.\deploy-zabbix-agent.ps1 -ZabbixServer "192.168.1.100" -SharePath "\\fileserver\Scripts\ZabbixAgent"

Advanced Usage
.\deploy-zabbix-agent.ps1 -ZabbixServer "zabbix.company.com" -SharePath "\\nas\Deploy\Zabbix" -HostMetadata "Windows-Servers"

📋 Parameters
Parameter	      Required	Description
ZabbixServer	    ✅	    Zabbix server IP/hostname
SharePath	        ✅	    Network path to MSI installer
HostMetadata	    ❌	    Auto-registration group

🔧 Configuration
The script automatically configures:

HostMetadata for auto-registration

Service for automatic startup

Comprehensive logging

🐛 Troubleshooting
Check these logs if you have issues:

C:\Windows\Temp\zabbix_install.log

C:\Windows\Temp\zabbix_msi_install.log

📄 License
MIT License - see LICENSE file for details
