# ============================
# ZABBIX AGENT AUTO-DEPLOY SCRIPT
# Windows Environment - Network Share Version
# ============================

param(
    [Parameter(Mandatory=$true)]
    [string]$ZabbixServer,
    
    [Parameter(Mandatory=$true)]
    [string]$SharePath,
    
    [Parameter(Mandatory=$false)]
    [string]$HostMetadata = "Windows",
    
    [Parameter(Mandatory=$false)]
    [string]$InstallDir = "C:\Program Files\Zabbix Agent"
)

# Verifica se está rodando como administrador
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Elevando privilégios para Administrador..."
    
    # Recria o processo com elevação
    $proc = Start-Process -FilePath "powershell.exe" `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -ZabbixServer `"$ZabbixServer`" -SharePath `"$SharePath`" -HostMetadata `"$HostMetadata`"" `
        -Verb RunAs -Wait -PassThru
    
    exit $proc.ExitCode
}

# Configurações
$Installer = "$SharePath\zabbix_agent-7.2.3-windows-amd64-openssl.msi"
$ConfigPath = "$InstallDir\zabbix_agentd.conf"
$LogFile = "C:\Windows\Temp\zabbix_install.log"

# Função de log
function Write-ZabbixLog {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Timestamp - $Message" | Out-File -FilePath $LogFile -Append -Encoding UTF8
    Write-Host $Message
}

Write-ZabbixLog "=== INICIANDO INSTALAÇÃO ZABBIX AGENT ==="
Write-ZabbixLog "Computador: $env:COMPUTERNAME"
Write-ZabbixLog "Usuário: $env:USERNAME"
Write-ZabbixLog "Servidor Zabbix: $ZabbixServer"
Write-ZabbixLog "Share Path: $SharePath"

# Verifica acesso ao compartilhamento
Write-ZabbixLog "Verificando acesso ao compartilhamento..."
if (!(Test-Path $SharePath)) {
    Write-ZabbixLog "ERRO: Não consegue acessar $SharePath"
    Write-ZabbixLog "Certifique-se de que:"
    Write-ZabbixLog "1. O caminho de rede está correto"
    Write-ZabbixLog "2. Você tem permissões de acesso"
    Write-ZabbixLog "3. O servidor de arquivos está acessível"
    exit 1
}

# Verifica instalador
if (!(Test-Path $Installer)) {
    Write-ZabbixLog "ERRO: Instalador não encontrado: $Installer"
    Write-ZabbixLog "Certifique-se de que o arquivo MSI está no compartilhamento"
    exit 1
}
Write-ZabbixLog "Instalador encontrado: $Installer"

# Para e remove versões antigas
Write-ZabbixLog "Verificando instalações anteriores..."
$ZabbixService = Get-Service | Where-Object { $_.Name -like "Zabbix*" -or $_.DisplayName -like "Zabbix*" }

if ($ZabbixService) {
    foreach ($Service in $ZabbixService) {
        Write-ZabbixLog "Parando serviço: $($Service.Name)"
        Stop-Service -Name $Service.Name -Force -ErrorAction SilentlyContinue
        
        # Desinstala via MSI se existir
        $Products = Get-WmiObject -Class Win32_Product | Where-Object { 
            $_.Name -like "Zabbix Agent*" 
        }
        
        foreach ($Product in $Products) {
            Write-ZabbixLog "Desinstalando: $($Product.Name)"
            $Product.Uninstall() | Out-Null
            Start-Sleep -Seconds 3
        }
    }
}

# Cria diretório de instalação
if (!(Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    Write-ZabbixLog "Diretório criado: $InstallDir"
}

# Instala o agente
Write-ZabbixLog "Instalando Zabbix Agent..."
$InstallArgs = @(
    "/i", "`"$Installer`"",
    "/qn",
    "/norestart",
    "/L*v", "C:\Windows\Temp\zabbix_msi_install.log",
    "LOGTYPE=file",
    "LOGFILE=`"$InstallDir\zabbix_agentd.log`"",
    "SERVER=$ZabbixServer",
    "SERVERACTIVE=$ZabbixServer", 
    "HOSTNAME=$env:COMPUTERNAME",
    "INSTALLFOLDER=`"$InstallDir`""
)

try {
    $Process = Start-Process -FilePath "msiexec.exe" -ArgumentList $InstallArgs -Wait -PassThru
    
    if ($Process.ExitCode -eq 0) {
        Write-ZabbixLog "SUCESSO: MSI instalado com código: $($Process.ExitCode)"
    } else {
        Write-ZabbixLog "AVISO: MSI instalado com código: $($Process.ExitCode) - Verifique o log detalhado"
    }
} catch {
    Write-ZabbixLog "ERRO na instalação MSI: $($_.Exception.Message)"
    exit 1
}

# Aguarda instalação completar
Write-ZabbixLog "Aguardando instalação completar..."
Start-Sleep -Seconds 10

# 🔥 CONFIGURAÇÃO DO ARQUIVO DE CONFIGURAÇÃO
Write-ZabbixLog "Configurando arquivo de configuração do Zabbix Agent..."
$ConfigContent = @"
LogFile=$InstallDir\zabbix_agentd.log
Server=$ZabbixServer
ServerActive=$ZabbixServer
Hostname=$env:COMPUTERNAME
HostMetadata=$HostMetadata
Timeout=30
LogFileSize=10
EnableRemoteCommands=1
"@

try {
    Set-Content -Path $ConfigPath -Value $ConfigContent -Encoding ASCII -Force
    Write-ZabbixLog "✅ Arquivo de configuração atualizado com HostMetadata=$HostMetadata"
} catch {
    Write-ZabbixLog "ERRO ao atualizar arquivo de configuração: $($_.Exception.Message)"
}

# Verifica se serviço foi criado
Write-ZabbixLog "Verificando serviços Zabbix..."
$ZabbixService = Get-Service | Where-Object { $_.Name -like "Zabbix*" -or $_.DisplayName -like "Zabbix*" }

if (!$ZabbixService) {
    Write-ZabbixLog "ERRO: Serviço Zabbix não encontrado após instalação"
    Write-ZabbixLog "Verifique: C:\Windows\Temp\zabbix_msi_install.log"
    exit 1
}

Write-ZabbixLog "Serviço encontrado: $($ZabbixService.Name)"

# Configura serviço para inicialização automática
try {
    Set-Service -Name $ZabbixService.Name -StartupType Automatic -ErrorAction Stop
    Write-ZabbixLog "Serviço configurado para inicialização automática"
    
    # Inicia serviço
    Start-Service -Name $ZabbixService.Name -ErrorAction Stop
    Start-Sleep -Seconds 5
    
    # Verifica status
    $ServiceStatus = Get-Service -Name $ZabbixService.Name
    if ($ServiceStatus.Status -eq "Running") {
        Write-ZabbixLog "SUCESSO: Zabbix Agent instalado e rodando!"
        
        # Verifica se está respondendo
        $Process = Get-Process -Name "zabbix_agentd" -ErrorAction SilentlyContinue
        if ($Process) {
            Write-ZabbixLog "Processo zabbix_agentd está em execução (PID: $($Process.Id))"
        }
    } else {
        Write-ZabbixLog "AVISO: Serviço instalado mas não está rodando. Status: $($ServiceStatus.Status)"
    }
    
} catch {
    Write-ZabbixLog "ERRO ao configurar/iniciar serviço: $($_.Exception.Message)"
}

Write-ZabbixLog "=== INSTALAÇÃO FINALIZADA ==="
Write-ZabbixLog "Log detalhado: C:\Windows\Temp\zabbix_msi_install.log"
Write-ZabbixLog "Log agente: $InstallDir\zabbix_agentd.log"

# Resultado final
if (Get-Service -Name $ZabbixService.Name -ErrorAction SilentlyContinue) {
    Write-ZabbixLog "RESULTADO: INSTALAÇÃO BEM-SUCEDIDA"
    exit 0
} else {
    Write-ZabbixLog "RESULTADO: INSTALAÇÃO COM FALHA"
    exit 1
}