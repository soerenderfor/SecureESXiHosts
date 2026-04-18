#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Configure-ESXi-Hosts

    This script is used to configure ESXi hosts and VMs according to the DISA STIG for VMware vSphere 8.0.3.

.DESCRIPTION
    The script will connect to ESXi hosts defined in a CSV file and configure them with the following settings.

    The script will harden ESXi hosts according to the DISA STIG for VMware vSphere 8.0.3.

    It will also harden the VMs on the ESXi hosts according to the DISA STIG for VMware vSphere 8.0.3.

    The script will also remove unnecessary hardware devices from the VMs and configure specific hardware settings.

.PARAMETER esxiHostSettings
    Path to ESXi hosts settings file

.PARAMETER RemediateVMs
    Use -RemediateVMs option to remediate all VMs on the vSphere/vCenter host.

.PARAMETER requiredModules
    Required PowerShell modules to import

.EXAMPLE
    The script can be run without any parameters

    PS> .\Configure-ESXi-Hosts.ps1

.COMPONENT
    Powershell 5.1 or higher
    Modules:
        VMware.PowerCLI, Helpdesk.CIS
    PowerCLI Settings:
        Set-PowerCLIConfiguration -ParticipateInCEIP $false -InvalidCertificateAction Ignore -ErrorAction SilentlyContinue

.NOTES
    Version:        2.3.9
    Author:         Soeren Kahr
    Creation Date:  2025-02-18
    Changed Date:   2025-09-20
#>

# Scirpt requirements
#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false,
        HelpMessage = 'Path to ESXi hosts settings file')]
    [ValidateNotNullOrEmpty()]
    [String]$esxiHostSettings = 'D:\CISHOMELAB\Configure-ESXi-Hosts\esxiHostSettings.csv',

    [Parameter(Mandatory = $false,
        HelpMessage = 'Use -RemediateVMs option to remediate all VMs on the ESXi/vCenter host')]
    [ValidateNotNullOrEmpty()]
    [switch]$RemediateVMs = $false,

    [Parameter(Mandatory = $false,
        HelpMessage = 'Import required modules')]
    [String[]]$requiredModules = @( 'VMware.PowerCLI' , 'Helpdesk.CIS' )
)

# Import modules
foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-LogMessage -Message "$module is not installed - for more information ask MA: 503010 1CISDET (HELPDESK)" -Level 'ERROR'
        exit
    }
}

# If you need a log file, you can use uncomment the next line
#Enable-Log

# Disconnect from all ESXi Hosts and vCenter servers
if ($global:DefaultVIServers) {
    [Void](Disconnect-VIServer * -Confirm:$false -ErrorAction Ignore)
}

# Check if the script is running on vSphere 8.0.3
function Confirm-HostVersion {
    <#
.SYNOPSIS
    Confirm-HostVersion

    This function is used to check if the script is running on vSphere 8.0.3.

.DESCRIPTION
    The function will check the version of the ESXi hosts and exit if the version is not 8.0.3.

.PARAMETER RequiredVersion
    The required vSphere version. Default is '8.0.3'.

.NOTES
    Version:        1.0
    Author:         Soeren Kahr
    Creation Date:  2025-07-22
    Changed Date:   2025-07-22
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false,
            HelpMessage = 'Required vSphere version')]
        [String]$RequiredVersion = '8.0.3'
    )

    $ESXi = Get-VMHost
    foreach ($esxihost in $ESXi) {
        if ($esxihost.Version -ne $RequiredVersion) {
            Write-LogMessage -Message "This script requires vSphere $RequiredVersion throughout the environment." -Level 'ERROR'
            Write-LogMessage -Message "Host $($esxihost.Name) has unsupported version: $($esxihost.Version). Exiting." -Level 'ERROR'
            exit
        }
    }
}

# Welcome message to be displayed. V-258729
$WelcomeMessage = @'

---------------
{bgcolor:black} {/color}{align:left}{bgcolor:black}{color:yellow}Host: {hostname} {ip}{/color}{/bgcolor}{/align}
{bgcolor:black} {/color}{align:left}{bgcolor:black}{color:yellow}ESXi Server Version: {esxversion}{/color}{/bgcolor}{/align}
{bgcolor:black} {/color}{align:left}{bgcolor:black}{color:yellow}Product: {esxproduct}{/color}{/bgcolor}{/align}
{bgcolor:black} {/color}{align:left}{bgcolor:black}{color:yellow}{memory} RAM{/color}{/bgcolor}{/align}
---------------

## Warning: Authorized Users Only

**This service is restricted to authorized users only.**

Your **IP**, **Login Time**, **Username** has been logged!

*All activities* are monitored and **trespassing violators** will be reported to system administrators.

**If you are not an authorized user of this system, exit the system at this time.**


{bgcolor:black} {/color}{bgcolor:dark-grey}{color:black}                                                              {/color}{/bgcolor}
{bgcolor:black} {/color}{bgcolor:dark-grey}{color:black}                                                              {/color}{/bgcolor}
{bgcolor:black} {/color}{bgcolor:dark-grey}{color:black}                                                              {/color}{/bgcolor}
{bgcolor:black} {/color}{bgcolor:dark-grey}{color:black}                                                              {/color}{/bgcolor}
{bgcolor:black} {/color}{bgcolor:dark-grey}{color:black}                                                              {/color}{/bgcolor}
{bgcolor:black} {/color}{bgcolor:dark-grey}{color:black}                                                              {/color}{/bgcolor}
{bgcolor:black} {/color}{bgcolor:dark-grey}{color:black}                                                              {/color}{/bgcolor}
{bgcolor:black} {/color}{bgcolor:dark-grey}{color:black}                                                              {/color}{/bgcolor}
{bgcolor:black} {/color}{bgcolor:dark-grey}{color:black}                                                              {/color}{/bgcolor}
{bgcolor:black} {/color}{bgcolor:dark-grey}{color:black}                                                              {/color}{/bgcolor}
{bgcolor:black} {/color}{bgcolor:dark-grey}{color:black}                                                              {/color}{/bgcolor}
{bgcolor:black} {/color}{bgcolor:dark-grey}{color:black}                                                              {/color}{/bgcolor}
{bgcolor:black} {/color}{bgcolor:dark-grey}{color:black}                                                              {/color}{/bgcolor}
{bgcolor:black} {/color}{bgcolor:dark-grey}{color:black}                                                              {/color}{/bgcolor}
{bgcolor:black} {/color}{bgcolor:dark-grey}{color:black}                                                              {/color}{/bgcolor}
{bgcolor:black} {/color}{bgcolor:dark-grey}{color:black}                                                              {/color}{/bgcolor}
{bgcolor:black} {/color}{bgcolor:dark-grey}{color:black}                                                              {/color}{/bgcolor}
{bgcolor:black} {/color}{align:left}{bgcolor:dark-grey}{color:white}  <F2> Accept Conditions and Customize System / View Logs{/align}{align:right}<F12> Accept Conditions and Shut Down/Restart  {bgcolor:black} {/color}{/color}{/bgcolor}{/align}
{bgcolor:black} {/color}{bgcolor:dark-grey}{color:black}                                                              {/color}{/bgcolor}

'@

# SSH issue banner to be displayed. V-258752
$sshissueBanner = "

#################################################################
#                   _    _           _   _                      #
#                  / \  | | ___ _ __| |_| |                     #
#                 / _ \ | |/ _ \ '__| __| |                     #
#                / ___ \| |  __/ |  | |_|_|                     #
#               /_/   \_\_|\___|_|   \__(_)                     #
#                                                               #
#  You are entering into a secured area! Your IP, Login Time,   #
#   Username has been noted and has been sent to the server     #
#                       administrator!                          #
#   This service is restricted to authorized users only. All    #
#            activities on this system are logged.              #
#  Unauthorized access will be fully investigated and reported  #
#        to the appropriate law enforcement agencies.           #
#################################################################

"

#'Syslog.global.certificate.checkSSLCerts'        = $true
#'Syslog.global.certificate.strictX509Compliance' = $true

# Connect and configure ESXi hosts
$esxiHosts = Import-Csv -Path $esxiHostSettings

$hostconfig = [ordered]@{
    # Hardening/DISA STIG Settings
    hostAdvSettings = [ordered]@{
        'Security.AccountUnlockTime'                   = 900
        'Security.AccountLockFailures'                 = 5
        'Security.PasswordQualityControl'              = 'similar=deny retry=3 min=disabled,disabled,disabled,disabled,15 max=64'
        'Security.PasswordHistory'                     = 5
        'Security.PasswordMaxDays'                     = 9999
        'Config.HostAgent.vmacore.soap.sessionTimeout' = 30
        'Config.HostAgent.plugins.solo.enableMob'      = $false
        'UserVars.DcuiTimeOut'                         = 600
        'UserVars.SuppressHyperthreadWarning'          = 0
        'UserVars.SuppressShellWarning'                = 0
        'UserVars.HostClientSessionTimeout'            = 900
        'Net.BMCNetworkEnable'                         = 0
        'DCUI.Access'                                  = 'root'
        'Config.HostAgent.log.level'                   = 'info'
        'Net.BlockGuestBPDU'                           = 1
        'Net.DVFilterBindIpAddress'                    = ''
        'UserVars.ESXiShellInteractiveTimeOut'         = 900
        'UserVars.ESXiShellTimeOut'                    = 600
        'UserVars.ESXiVPsDisabledProtocols'            = 'sslv3,tlsv1,tlsv1.1'
        'Mem.ShareForceSalting'                        = 2
        'VMkernel.Boot.execInstalledOnly'              = $true
        'Mem.MemEagerZero'                             = 1
        'Syslog.global.logLevel'                       = 'info'
        'Syslog.global.auditRecord.storageEnable'      = $true
        'Syslog.global.auditRecord.storageCapacity'    = 100
        'Syslog.global.auditRecord.remoteEnable'       = $true
    }
}

foreach ($esxiHost in $esxiHosts) {

    $srv = Connect-VIServer -Server $esxiHost.VMHost -User $esxiHost.User -Password $esxiHost.Pass

    $currentDateTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-LogMessage -Message 'VMware ESXi Host Security Settings Remediation' -Level 'INFO'
    Write-LogMessage -Message "Remediation of $($esxiHost.VMHost) started at $currentDateTime from $env:COMPUTERNAME by $env:USERNAME" -Level 'INFO'

    # Confirm the host version is 8.0.3
    Confirm-HostVersion

    if ($srv) {

        # Read the ESXi host into objects and views once to save time and resources
        $obj = Get-VMHost -Name $esxiHost.VMHost -ErrorAction Stop
        $view = Get-View -VIObject $obj
        $ESXcli = Get-EsxCli -VMHost $obj -V2

        # Set-VMHostAccount -UserAccount $_.User -Password $_.NewPass -Server $srv -Confirm:$false

        foreach ($setting in ($hostconfig.hostAdvSettings.GetEnumerator() | Sort-Object Name)) {
            # Pulling values for each setting specified
            $settingname = $setting.name
            $settingvalue = $setting.value
            if ($asetting = $obj | Get-AdvancedSetting -Name $settingname) {
                if ($asetting.value -eq $settingvalue) {
                    Write-LogMessage -Message "$($esxiHost.VMHost): Setting $settingname is already configured correctly to $settingvalue on $($esxiHost.VMHost)" -Level 'PASS'
                } else {
                    Write-LogMessage -Message "$($esxiHost.VMHost): ...Setting $settingname was incorrectly set to $($asetting.value) on $($esxiHost.VMHost) setting to $settingvalue" -Level 'UPDATE'
                    [Void]($asetting | Set-AdvancedSetting -Value $settingvalue -Confirm:$false)
                }
            } else {
                Write-LogMessage -Message "$($esxiHost.VMHost):...Setting $settingname does not exist on $($esxiHost.VMHost) creating setting..." -Level 'UPDATE'
                [Void]($obj | New-AdvancedSetting -Name $settingname -Value $settingvalue -Confirm:$false)
            }
        }

        # Configure VM Startup Policy on the host
        $startPolicyParams = @{
            Enabled          = $true
            StartDelay       = 30
            StopDelay        = 30
            StopAction       = 'GuestShutDown'
            WaitForHeartBeat = $false
            Confirm          = $false
        }
        [Void](Get-VMHostStartPolicy | Set-VMHostStartPolicy @startPolicyParams)
        Write-LogMessage -Message "$($esxiHost.VMHost): Configured startup policy on host." -Level 'UPDATE'

        # Set Power management to High Performance(1) other is Balanced(2) - Low Power(3) - Custom(4)
        $powerSetting = ((Get-View($view).ConfigManager.PowerSystem)).Info.CurrentPolicy.Key
        if ($powerSetting -ne 1) {
            (Get-View $view.ConfigManager.PowerSystem).ConfigurePowerPolicy(1)
            Write-LogMessage -Message "$($esxiHost.VMHost): Configuring Power management to High Performance on host." -Level 'UPDATE'
        } else {
            Write-LogMessage -Message "$($esxiHost.VMHost): Power management is already set to High Performance on host." -Level 'PASS'
        }

        # ESXi Services to disable - V-258783 - V-258755 - V-258786 - V-258767 - V-258754
        Write-LogMessage -Message "$($esxiHost.VMHost)`: ESXi Services to disable - V-258783 - V-258755 - V-258786 - V-258767 - V-258754" -Level 'INFO'
        $disableServices = 'sfcbd-watchdog', 'TSM', 'slpd', 'snmpd', 'TSM-SSH'
        foreach ($service in $disableServices) {
            $value = $obj | Get-VMHostService | Where-Object { $_.Key -eq $service } | Select-Object -ExpandProperty Running
            if ($value -ne $false) {
                [Void]($obj | Get-VMHostService | Where-Object { $_.Key -eq $service } | Stop-VMHostService -Confirm:$false)
                Write-LogMessage -Message "$($esxiHost.VMHost): Stopping service $service on host." -Level 'UPDATE'
            } else {
                Write-LogMessage -Message "$($esxiHost.VMHost): ...Service $service is already stopped on host." -Level 'PASS'
            }

            $value = $obj | Get-VMHostService | Where-Object { $_.Key -eq $service } | Select-Object -ExpandProperty Policy
            if ($value -ne 'off') {
                [Void]($obj | Get-VMHostService | Where-Object { $_.Key -eq $service } | Set-VMHostService -Policy 'off' -Confirm:$false)
                Write-LogMessage -Message "$($esxiHost.VMHost): Disable $service on host." -Level 'UPDATE'
            } else {
                Write-LogMessage -Message "$($esxiHost.VMHost): ...Service $service is already disabled on host." -Level 'PASS'
            }
        }

        # The ESXi host must synchronize internal information system clocks to an authoritative time source. V-258745
        [Void](Get-VMHost | Get-VMHostService | Where-Object { $_.Label -eq 'NTP Daemon' } | Stop-VMHostService -Confirm:$false)
        [Void](Get-VMHost | Get-VMHostNtpServer | ForEach-Object { Remove-VMHostNtpServer -NtpServer $_ -Confirm:$false })
        [Void](Get-VMHost | Add-VMHostNtpServer -NtpServer $esxiHost.Ntp1, $esxiHost.Ntp2, $esxiHost.Ntp3 -Confirm:$false)
        $enableServices = 'ntpd'
        foreach ($service in $enableServices) {
            $value = $obj | Get-VMHostService | Where-Object { $_.Key -eq $service } | Select-Object -ExpandProperty Running
            if ($value -ne $true) {
                [Void]($obj | Get-VMHostService | Where-Object { $_.Key -eq $service } | Start-VMHostService -Confirm:$false)
                Write-LogMessage -Message "$($esxiHost.VMHost): Enabling $service on host. V-258745" -Level 'UPDATE'
            } else {
                Write-LogMessage -Message "$($esxiHost.VMHost): ...Service $service is already started on host. V-258745" -Level 'PASS'
            }

            $value = $obj | Get-VMHostService | Where-Object { $_.Key -eq $service } | Select-Object -ExpandProperty Policy
            if ($value -ne 'on') {
                [Void]($obj | Get-VMHostService | Where-Object { $_.Key -eq $service } | Set-VMHostService -Policy 'on' -Confirm:$false)
                Write-LogMessage -Message "$($esxiHost.VMHost): Service $service is configured to be running on host. V-258745" -Level 'UPDATE'
            } else {
                Write-LogMessage -Message "$($esxiHost.VMHost): ...Service $service is already configured to be running on host. V-258745" -Level 'PASS'
            }
        }

        # The ESXi host Secure Shell (SSH) daemon must be configured to only use FIPS 140-2 validated ciphers. V-258750
        $value = $ESXcli.system.ssh.server.config.list.invoke() | Where-Object { $_.Key -eq 'ciphers' } | Select-Object -ExpandProperty Value
        if ($value -ne 'aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr') {
            Write-LogMessage -Message "$($esxiHost.VMHost)`: Configuring the ESXi host Secure Shell (SSH) daemon to only use FIPS 140-2 validated ciphers. V-258750" -Level 'UPDATE'
            $arguments = $ESXcli.system.ssh.server.config.set.CreateArgs()
            $arguments.keyword = 'ciphers'
            $arguments.value = 'aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr'
            [Void]($ESXcli.system.ssh.server.config.set.Invoke($arguments))
        } else {
            Write-LogMessage -Message "$($esxiHost.VMHost): The ESXi host Secure Shell (SSH) daemon is already configured to only use FIPS 140-2 validated ciphers. V-258750" -Level 'PASS'
        }

        # The ESXi host must not enable log filtering. V-258800
        $value = $ESXcli.system.syslog.config.logfilter.get.invoke() | Select-Object -ExpandProperty LogFilteringEnabled
        if ($value -ne 'false') {
            Write-LogMessage -Message "$($esxiHost.VMHost): Configuring the ESXi host to not enable log filtering. V-258800" -Level 'UPDATE'
            $arguments = $ESXcli.system.syslog.config.logfilter.set.CreateArgs()
            $arguments.logfilteringenabled = $false
            [Void]($ESXcli.system.syslog.config.logfilter.set.invoke($arguments))
        } else {
            Write-LogMessage -Message "$($esxiHost.VMHost): The ESXi host is already configured to not enable log filtering. V-258800" -Level 'PASS'
        }

        # Configuring the ESXi host DCUI to disable shell access. V-258747
        $value = $ESXcli.system.account.list.Invoke() | Where-Object { $_.UserID -eq 'dcui' } | Select-Object -ExpandProperty Shellaccess
        if ($value -ne 'false') {
            Write-LogMessage -Message "$($esxiHost.VMHost): Configuring the ESXi host DCUI to disable shell access. V-258747" -Level 'UPDATE'
            $arguments = $ESXcli.system.account.set.CreateArgs()
            $arguments.id = 'dcui'
            $arguments.shellaccess = $false
            [Void]($ESXcli.system.account.set.Invoke($arguments))
        } else {
            Write-LogMessage -Message "$($esxiHost.VMHost): The ESXi host DCUI is already configured to disable shell access. V-258747" -Level 'PASS'
        }

        # The ESXi host Secure Shell (SSH) daemon must disable stream local forwarding
        $value = $ESXcli.system.ssh.server.config.list.invoke() | Where-Object { $_.Key -eq 'allowstreamlocalforwarding' } | Select-Object -ExpandProperty Value
        if ($value -ne 'no') {
            Write-LogMessage -Message "$($esxiHost.VMHost): Configuring the ESXi host Secure Shell (SSH) daemon to disable stream local forwarding. V-258764" -Level 'UPDATE'
            $arguments = $ESXcli.system.ssh.server.config.set.CreateArgs()
            $arguments.keyword = 'allowstreamlocalforwarding'
            $arguments.value = 'no'
            [Void]($ESXcli.system.ssh.server.config.set.Invoke($arguments))
        } else {
            Write-LogMessage -Message "$($esxiHost.VMHost): The ESXi host Secure Shell (SSH) daemon is already configured to disable stream local forwarding. V-258764" -Level 'PASS'
        }

        # The ESXi host Secure Shell (SSH) daemon must disable TCP forwarding
        $value = $ESXcli.system.ssh.server.config.list.invoke() | Where-Object { $_.Key -eq 'allowtcpforwarding' } | Select-Object -ExpandProperty Value
        if ($value -ne 'no') {
            Write-LogMessage -Message "$($esxiHost.VMHost): Configuring the ESXi host Secure Shell (SSH) daemon to disable TCP forwarding. V-258763" -Level 'UPDATE'
            $arguments = $ESXcli.system.ssh.server.config.set.CreateArgs()
            $arguments.keyword = 'allowtcpforwarding'
            $arguments.value = 'no'
            [Void]($ESXcli.system.ssh.server.config.set.Invoke($arguments))
        } else {
            Write-LogMessage -Message "$($esxiHost.VMHost): The ESXi host Secure Shell (SSH) daemon is already configured to disable TCP forwarding. V-258763" -Level 'PASS'
        }

        # Configuring the ESXi host Secure Shell (SSH) daemon to not allow gateway ports. V-258739
        $value = $ESXcli.system.ssh.server.config.list.invoke() | Where-Object { $_.Key -eq 'gatewayports' } | Select-Object -ExpandProperty Value
        if ($value -ne 'no') {
            Write-LogMessage -Message "$($esxiHost.VMHost): Configuring the ESXi host Secure Shell (SSH) daemon to not allow gateway ports. V-258739" -Level 'UPDATE'
            $arguments = $ESXcli.system.ssh.server.config.set.CreateArgs()
            $arguments.keyword = 'gatewayports'
            $arguments.value = 'no'
            [Void]($ESXcli.system.ssh.server.config.set.Invoke($arguments))
        } else {
            Write-LogMessage -Message "$($esxiHost.VMHost): The ESXi host Secure Shell (SSH) daemon is already configured to not allow gateway ports. V-258739" -Level 'PASS'
        }

        # The ESXi host Secure Shell (SSH) daemon must ignore .rhosts files. V-258738
        $value = $ESXcli.system.ssh.server.config.list.invoke() | Where-Object { $_.Key -eq 'ignorerhosts' } | Select-Object -ExpandProperty Value
        if ($value -ne 'yes') {
            Write-LogMessage -Message "$($esxiHost.VMHost): Configuring the ESXi host Secure Shell (SSH) daemon to ignore .rhosts files. V-258738" -Level 'UPDATE'
            $arguments = $ESXcli.system.ssh.server.config.set.CreateArgs()
            $arguments.keyword = 'ignorerhosts'
            $arguments.value = 'yes'
            [Void]($ESXcli.system.ssh.server.config.set.Invoke($arguments))
        } else {
            Write-LogMessage -Message "$($esxiHost.VMHost): The ESXi host Secure Shell (SSH) daemon is already configured to ignore .rhosts files. V-258738" -Level 'PASS'
        }

        # The ESXi host Secure Shell (SSH) daemon must not allow host-based authentication
        $value = $ESXcli.system.ssh.server.config.list.invoke() | Where-Object { $_.Key -eq 'hostbasedauthentication' } | Select-Object -ExpandProperty Value
        if ($value -ne 'no') {
            Write-LogMessage -Message "$($esxiHost.VMHost): Configuring the ESXi host Secure Shell (SSH) daemon to not allow host-based authentication. V-258748" -Level 'UPDATE'
            $arguments = $ESXcli.system.ssh.server.config.set.CreateArgs()
            $arguments.keyword = 'hostbasedauthentication'
            $arguments.value = 'no'
            [Void]($ESXcli.system.ssh.server.config.set.Invoke($arguments))
        } else {
            Write-LogMessage -Message "$($esxiHost.VMHost): The ESXi host Secure Shell (SSH) daemon is already configured to not allow host-based authentication. V-258748" -Level 'PASS'
        }

        # The ESXi host Secure Shell (SSH) daemon must not permit tunnels
        $value = $ESXcli.system.ssh.server.config.list.invoke() | Where-Object { $_.Key -eq 'permittunnel' } | Select-Object -ExpandProperty Value
        if ($value -ne 'no') {
            Write-LogMessage -Message "$($esxiHost.VMHost): Configuring the ESXi host Secure Shell (SSH) daemon to not permit tunnels. V-258754" -Level 'UPDATE'
            $arguments = $ESXcli.system.ssh.server.config.set.CreateArgs()
            $arguments.keyword = 'permittunnel'
            $arguments.value = 'no'
            [Void]($ESXcli.system.ssh.server.config.set.Invoke($arguments))
        } else {
            Write-LogMessage -Message "$($esxiHost.VMHost): The ESXi host Secure Shell (SSH) daemon is already configured to not permit tunnels. V-258754" -Level 'PASS'
        }

        # The ESXi host Secure Shell (SSH) daemon must not permit user environment settings
        $value = $ESXcli.system.ssh.server.config.list.invoke() | Where-Object { $_.Key -eq 'permituserenvironment' } | Select-Object -ExpandProperty Value
        if ($value -ne 'no') {
            Write-LogMessage -Message "$($esxiHost.VMHost): Configuring the ESXi host Secure Shell (SSH) daemon to not permit user environment settings. V-258749" -Level 'UPDATE'
            $arguments = $ESXcli.system.ssh.server.config.set.CreateArgs()
            $arguments.keyword = 'permituserenvironment'
            $arguments.value = 'no'
            [Void]($ESXcli.system.ssh.server.config.set.Invoke($arguments))
        } else {
            Write-LogMessage -Message "$($esxiHost.VMHost): The ESXi host Secure Shell (SSH) daemon is already configured to not permit user environment settings. V-258749" -Level 'PASS'
        }

        # The ESXi host Secure Shell (SSH) daemon must set a timeout count on idle sessions. V-258765
        $value = $ESXcli.system.ssh.server.config.list.invoke() | Where-Object { $_.Key -eq 'clientalivecountmax' } | Select-Object -ExpandProperty Value
        if ($value -ne '3') {
            Write-LogMessage -Message "$($esxiHost.VMHost): Configuring the ESXi host Secure Shell (SSH) daemon to set a timeout count on idle sessions. V-258765" -Level 'UPDATE'
            $arguments = $ESXcli.system.ssh.server.config.set.CreateArgs()
            $arguments.keyword = 'clientalivecountmax'
            $arguments.value = '3'
            [Void]($ESXcli.system.ssh.server.config.set.Invoke($arguments))
        } else {
            Write-LogMessage -Message "$($esxiHost.VMHost): The ESXi host Secure Shell (SSH) daemon is already configured to set a timeout count on idle sessions. V-258765" -Level 'PASS'
        }

        # The ESXi host Secure Shell (SSH) daemon must set a timeout interval on idle sessions. V-258766
        $value = $ESXcli.system.ssh.server.config.list.invoke() | Where-Object { $_.Key -eq 'clientaliveinterval' } | Select-Object -ExpandProperty Value
        if ($value -ne '200') {
            Write-LogMessage -Message "$($esxiHost.VMHost): Configuring the ESXi host Secure Shell (SSH) daemon to set a timeout interval on idle sessions. V-258766" -Level 'UPDATE'
            $arguments = $ESXcli.system.ssh.server.config.set.CreateArgs()
            $arguments.keyword = 'clientaliveinterval'
            $arguments.value = '200'
            [Void]($ESXcli.system.ssh.server.config.set.Invoke($arguments))
        } else {
            Write-LogMessage -Message "$($esxiHost.VMHost): The ESXi host Secure Shell (SSH) daemon is already configured to set a timeout interval on idle sessions. V-258766" -Level 'PASS'
        }

        # The ESXi host Secure Shell (SSH) daemon must use FIPS 140-2 validated cryptographic to protect remote access sessions. V-258732
        $value = $ESXcli.system.security.fips140.ssh.get.invoke() | Select-Object -ExpandProperty Enabled
        if ($value -ne 'true') {
            Write-LogMessage -Message "$($esxiHost.VMHost): Configuring the ESXi host Secure Shell (SSH) daemon to use FIPS 140-2 validated cryptographic. V-258732" -Level 'UPDATE'
            $arguments = $ESXcli.system.security.fips140.ssh.set.CreateArgs()
            $arguments.enable = $true
            [Void]($ESXcli.system.security.fips140.ssh.set.Invoke($arguments))
        } else {
            Write-LogMessage -Message "$($esxiHost.VMHost): The ESXi host Secure Shell (SSH) daemon is already configured to use FIPS 140-2 validated cryptographic. V-258732" -Level 'PASS'
        }

        # The ESXi host Secure Shell (SSH) daemon must display the Standard Mandatory DOD Notice and Consent Banner. V-258753
        $value = $ESXcli.system.ssh.server.config.list.invoke() | Where-Object { $_.Key -eq 'banner' } | Select-Object -ExpandProperty Value
        if ($value -ne '/etc/issue') {
            Write-LogMessage -Message "$($esxiHost.VMHost): Configuring the ESXi host Secure Shell (SSH) daemon to display the Standard Mandatory DOD Notice and Consent Banner. V-258753" -Level 'UPDATE'
            $arguments = $ESXcli.system.ssh.server.config.set.CreateArgs()
            $arguments.keyword = 'banner'
            $arguments.value = '/etc/issue'
            [Void]($ESXcli.system.ssh.server.config.set.Invoke($arguments))
        } else {
            Write-LogMessage -Message "$($esxiHost.VMHost): The ESXi host Secure Shell (SSH) daemon is already configured to display the Standard Mandatory DOD Notice and Consent Banner. V-258753" -Level 'PASS'
        }

        # The ESXi host must maintain confidentiality and integrity of transmissions by enabling modern TLS ciphers: esxi-8.tls-profile
        $value = $ESXcli.system.tls.server.get.invoke() | Select-Object -ExpandProperty Profile
        if ($value -ne 'NIST_2024') {
            Write-LogMessage -Message "$($esxiHost.VMHost): Configuring the ESXi host to use the NIST_2024 TLS profile for incoming connections. V-258748" -Level 'UPDATE'
            $arguments = $ESXcli.system.tls.server.set.CreateArgs()
            $arguments.profile = 'NIST_2024'
            [Void]($ESXcli.system.tls.server.set.invoke($arguments))
        } else {
            Write-LogMessage -Message "$($esxiHost.VMHost): The ESXi host is already configured to use the NIST_2024 TLS profile for incoming connections. V-258748" -Level 'PASS'
        }

        # The ESXi host must configure virtual switch security policies to reject forged transmits. ESXI-80-000216
        foreach ($vSwitch in Get-VirtualSwitch -VMHost $obj) {
            $policy = Get-SecurityPolicy -VirtualSwitch $vSwitch
            if ($policy.ForgedTransmits -ne $false) {
                [Void](Set-SecurityPolicy -VirtualSwitch $vSwitch -ForgedTransmits $false -Confirm:$false)
                Write-LogMessage -Message "$($esxiHost.VMHost): Configuring virtual switch security policies to reject forged transmits. ESXI-80-000216" -Level 'UPDATE'
            } else {
                Write-LogMessage -Message "$($esxiHost.VMHost): The virtual switch security policies to reject forged transmits is already disabled on vSwitch '$($vSwitch.Name)'. ESXI-80-000216" -Level 'PASS'
            }
        }

        # The ESXi host must configure virtual port group security policies to reject forged transmits. ESXI-80-000216
        foreach ($pg in Get-VirtualPortGroup -VMHost $obj) {
            $policy = Get-SecurityPolicy -VirtualPortGroup $pg
            if ($policy.ForgedTransmitsInherited -ne $true) {
                [Void](Set-SecurityPolicy -VirtualPortGroup $pg -ForgedTransmitsInherited $true -Confirm:$false)
                Write-LogMessage -Message "$($esxiHost.VMHost): Configuring virtual port group security policies to reject forged transmits. ESXI-80-000216" -Level 'UPDATE'
            } else {
                Write-LogMessage -Message "$($esxiHost.VMHost): The virtual port group security policies to reject forged transmits is already disabled on Port Group '$($pg.Name)'. ESXI-80-000216" -Level 'PASS'
            }
        }

        # The ESXi host must configure virtual switch security policies to reject Media Access Control (MAC) address changes. V-258772
        foreach ($vSwitch in Get-VirtualSwitch -VMHost $obj) {
            $policy = Get-SecurityPolicy -VirtualSwitch $vSwitch
            if ($policy.MacChanges -ne $false) {
                [Void](Set-SecurityPolicy -VirtualSwitch $vSwitch -MacChanges $false -Confirm:$false)
                Write-LogMessage -Message "$($esxiHost.VMHost): Configuring virtual switch security policies to reject Media Access Control (MAC) address changes. ESXI-80-000204" -Level 'UPDATE'
            } else {
                Write-LogMessage -Message "$($esxiHost.VMHost): The virtual switch security policies to reject Media Access Control (MAC) address changes is already disabled on vSwitch '$($vSwitch.Name)'. V-258772" -Level 'PASS'
            }
        }

        # The ESXi host must configure virtual port group security policies to reject Media Access Control (MAC) address changes. V-258772
        foreach ($pg in Get-VirtualPortGroup -VMHost $obj) {
            $policy = Get-SecurityPolicy -VirtualPortGroup $pg
            if ($policy.MacChangesInherited -ne $true) {
                [Void](Set-SecurityPolicy -VirtualPortGroup $pg -MacChangesInherited $true -Confirm:$false)
                Write-LogMessage -Message "$($esxiHost.VMHost): Configuring virtual port group security policies to reject Media Access Control (MAC) address changes. V-258772" -Level 'UPDATE'
            } else {
                Write-LogMessage -Message "$($esxiHost.VMHost): The virtual port group security policies to reject Media Access Control (MAC) address changes is already disabled on Port Group '$($pg.Name)'. V-258772" -Level 'PASS'
            }
        }

        # The ESXi host must configure virtual switch security policies to reject promiscuous mode requests. V-258773
        foreach ($vSwitch in Get-VirtualSwitch -VMHost $obj) {
            $policy = Get-SecurityPolicy -VirtualSwitch $vSwitch
            if ($policy.AllowPromiscuous -ne $false) {
                [Void](Set-SecurityPolicy -VirtualSwitch $vSwitch -AllowPromiscuous $false -Confirm:$false)
                Write-LogMessage -Message "$($esxiHost.VMHost): Configuring virtual switch security policies to reject promiscuous mode requests. V-258773" -Level 'UPDATE'
            } else {
                Write-LogMessage -Message "$($esxiHost.VMHost): The virtual switch security policies to reject promiscuous is already disabled on vSwitch '$($vSwitch.Name)'. V-258773" -Level 'PASS'
            }
        }

        # The ESXi host must configure virtual port group security policies to reject promiscuous mode requests. V-258773
        foreach ($pg in Get-VirtualPortGroup -VMHost $obj) {
            $policy = Get-SecurityPolicy -VirtualPortGroup $pg
            if ($policy.AllowPromiscuousInherited -ne $true) {
                [Void](Set-SecurityPolicy -VirtualPortGroup $pg -AllowPromiscuousInherited $true -Confirm:$false)
                Write-LogMessage -Message "$($esxiHost.VMHost): Configuring virtual port group security policies to reject promiscuous mode requests. V-258773" -Level 'UPDATE'
            } else {
                Write-LogMessage -Message "$($esxiHost.VMHost): The virtual port group security policies to reject promiscuous is already disabled on Port Group '$($pg.Name)'. V-258773" -Level 'PASS'
            }
        }

        # The ESXi host must configure the firewall to block network traffic by default. V-258769
        $policy = Get-VMHostFirewallDefaultPolicy -VMHost $obj
        $firewallPolicy = Get-VMHostFirewallDefaultPolicy -VMHost $obj
        if ($firewallPolicy.IncomingEnabled -ne $false -or $firewallPolicy.OutgoingEnabled -ne $false) {
            [Void](Set-VMHostFirewallDefaultPolicy -Policy $policy -AllowIncoming $false -AllowOutgoing $false -Confirm:$false)
            Write-LogMessage -Message "$($esxiHost.VMHost): Configured the ESXi host firewall to block all incoming and outgoing traffic by default. V-258769" -Level 'UPDATE'
        } else {
            Write-LogMessage -Message "$($esxiHost.VMHost): ESXi host firewall is already configured to block traffic by default. V-258769" -Level 'PASS'
        }

        # The ESXi host must display the Consent Banner before granting access to the system via the Direct Console User Interface (DCUI) - V-258729
        $setting = Get-AdvancedSetting -Entity $obj -Name Annotations.WelcomeMessage
        if ($setting.Value -ne $WelcomeMessage) {
            [Void](Set-AdvancedSetting -AdvancedSetting $setting -Value $WelcomeMessage -Confirm:$false)
            Write-LogMessage -Message "$($esxiHost.VMHost): Configuring the ESXi host to display the Consent Banner before granting access to the system via the Direct Console User Interface (DCUI). V-258729" -Level 'UPDATE'
        } else {
            Write-LogMessage -Message "$($esxiHost.VMHost): The ESXi host is already configured to display the Consent Banner before granting access to the system via the Direct Console User Interface (DCUI). V-258729" -Level 'PASS'
        }

        # The ESXi host must display the Standard Mandatory DOD Notice and Consent Banner before granting access to the system via Secure Shell (SSH) - V-258752
        $setting = Get-AdvancedSetting -Entity $obj -Name Config.Etc.issue
        if ($setting.Value -ne $sshissueBanner) {
            [Void](Set-AdvancedSetting -AdvancedSetting $setting -Value $sshissueBanner -Confirm:$false)
            Write-LogMessage -Message "$($esxiHost.VMHost): Configuring the ESXi host to display the Standard Mandatory DOD Notice and Consent Banner before granting access to the system via Secure Shell (SSH). V-258752" -Level 'UPDATE'
        } else {
            Write-LogMessage -Message "$($esxiHost.VMHost): The ESXi host is already configured to display the Standard Mandatory DOD Notice and Consent Banner before granting access to the system via Secure Shell (SSH). V-258752" -Level 'PASS'
        }

        # The ESXi host must configure a persistent log location for all locally stored logs. V-258797
        $setting = Get-AdvancedSetting -Entity $obj -Name Syslog.global.logDir
        if ($setting.Value -ne $esxiHost.ESXiLogPath) {
            [Void](Set-AdvancedSetting -AdvancedSetting $setting -Value $esxiHost.ESXiLogPath -Confirm:$false)
            Write-LogMessage -Message "$($esxiHost.VMHost): Configuring the ESXi host to store logs in a persistent location. V-258797" -Level 'UPDATE'
        } else {
            Write-LogMessage -Message "$($esxiHost.VMHost): The ESXi host is already configured to store logs in a persistent location. V-258797" -Level 'PASS'
        }

        # Remediate VMs on the ESXi host
        if ($RemediateVMs) {
            # Read the VM into objects and views once to save time & resources
            $vms = Get-VM | Sort-Object Name | Where-Object { $_.Name -notlike 'vCLS*' }

            # VMware Hardening/VMware DISA STIG Settings
            $vmconfig = [ordered]@{
                # Hardening/DISA STIG Settings
                vmAdvSettings       = [ordered]@{
                    'isolation.tools.copy.disable'         = $true
                    'isolation.tools.dnd.disable'          = $true
                    'isolation.tools.paste.disable'        = $true
                    'isolation.tools.diskShrink.disable'   = $true
                    'isolation.tools.diskWiper.disable'    = $true
                    'RemoteDisplay.maxConnections'         = '1'
                    'tools.setInfo.sizeLimit'              = '1048576'
                    'isolation.device.connectable.disable' = $true
                    'tools.guestlib.enableHostInfo'        = $false
                    'tools.guest.desktop.autolock'         = $true
                    'mks.enable3d'                         = $false
                    'log.keepOld'                          = '10'
                    'log.rotateSize'                       = '2048000'
                    'numa.allowHotadd'                     = $true
                    'disk.EnableUUID'                      = $true
                    'bios.bootDeviceClasses'               = 'allow:hd'
                    'isolation.device.edit.disable'        = $true
                    'pciPassthru*.present'                 = ''
                }
                vmAdvSettingsRemove = ('sched.mem.pshare.salt')
            }

            # Remediate Virtual Machine advanced settings that are good by default
            foreach ($vm in $vms) {
                Write-LogMessage -Message "Configuring DISA STIG Settings on: $vm" -Level 'INFO'

                foreach ($setting in ($vmconfig.vmAdvSettings.GetEnumerator() | Sort-Object Name)) {
                    # Pulling values for each setting specified
                    $settingname = $setting.name
                    $settingvalue = $setting.value
                    if ($asetting = $vm | Get-AdvancedSetting -Name $settingname) {
                        if ($asetting.value -eq $settingvalue) {
                            Write-LogMessage -Message "$($vm.Name): Setting $settingname is already configured correctly to $settingvalue on $vm" -Level 'PASS'
                        } else {
                            Write-LogMessage -Message "$($vm.Name): ...Setting $settingname was incorrectly set to $($asetting.value) on $vm setting to $settingvalue" -Level 'UPDATE'
                            [Void]($asetting | Set-AdvancedSetting -Value $settingvalue -Confirm:$false)
                        }
                    } else {
                        Write-LogMessage -Message "$($vm.Name):...Setting $settingname does not exist on $vm creating setting..." -Level 'UPDATE'
                        [Void]($vm | New-AdvancedSetting -Name $settingname -Value $settingvalue -Confirm:$false)
                    }
                }

                # Remediate Virtual Machine advanced settings that must be removed
                Write-LogMessage -Message "Configuring DISA STIG Removing advanced settings if necessary on: $vm" -Level 'INFO'

                foreach ($setting in ($vmconfig.vmAdvSettingsRemove | Sort-Object Name)) {
                    # Checking to see if current setting exists
                    if ($asetting = $vm | Get-AdvancedSetting -Name $setting) {
                        Write-LogMessage -Message "$($vm.Name):...Setting $setting exists on $vm...removing setting" -Level 'UPDATE'
                        [Void]($asetting | Remove-AdvancedSetting -Confirm:$false)
                    } else {
                        Write-LogMessage -Message "$($vm.Name): Setting $setting does not exist on $vm" -Level 'PASS'
                    }
                }

                # Remove unnecessary virtual hardware from VMs
                Write-LogMessage -Message "Configuring DISA STIG - Removing unnecessary virtual hardware from: $vm" -Level 'INFO'

                # Remove USB controllers
                $usbDevices = Get-UsbDevice -VM $vm -ErrorAction SilentlyContinue
                if ($usbDevices) {
                    Write-LogMessage -Message "$($vm.Name): 7.12 (L1) Virtual machines must remove unnecessary USB/XHCI devices: USB devices found... removing them" -Level 'UPDATE'
                    [Void]($usbDevices | Remove-UsbDevice -Confirm:$false)
                } else {
                    Write-LogMessage -Message "$($vm.Name): No USB devices found" -Level 'PASS'
                }

                # Remove floppy drives
                $floppyDevices = Get-FloppyDrive -VM $vm -ErrorAction SilentlyContinue
                if ($floppyDevices) {
                    Write-LogMessage -Message "$($vm.Name): 7.16 (L1) Virtual machines must remove unnecessary floppy devices: Floppy drive found... removing it" -Level 'UPDATE'
                    [Void]($floppyDevices | Remove-FloppyDrive -Confirm:$false)
                } else {
                    Write-LogMessage -Message "$($vm.Name): No floppy drive found" -Level 'PASS'
                }

                # Remove CD/DVD drives
                $cdDevices = Get-CDDrive -VM $vm -ErrorAction SilentlyContinue
                if ($cdDevices) {
                    Write-LogMessage -Message "$($vm.Name): Virtual machines must remove unnecessary CD/DVD devices: CD/DVD drive found... removing it" -Level 'UPDATE'
                    [Void]($cdDevices | Set-CDDrive -NoMedia -Confirm:$false)
                } else {
                    Write-LogMessage -Message "$($vm.Name): No CD/DVD drive found" -Level 'PASS'
                }
            }

            # Configure VMs with specific hardware settings
            foreach ($vm in $vms) {
                $spec = [VMware.Vim.VirtualMachineConfigSpec]@{
                    CpuHotAddEnabled    = $false
                    MemoryHotAddEnabled = $true
                    NestedHVEnabled     = $false
                    Firmware            = [VMware.Vim.GuestOsDescriptorFirmwareType]::efi
                    BootOptions         = [VMware.Vim.VirtualMachineBootOptions]@{
                        EfiSecureBootEnabled = $true
                    }
                    Flags               = [VMware.Vim.VirtualMachineFlagInfo]@{
                        VvtdEnabled   = $true
                        EnableLogging = $true
                    }
                    VirtualNuma         = [VMware.Vim.VirtualMachineVirtualNuma]@{
                        ExposeVnumaOnCpuHotadd = $true
                    }
                    ExtraConfig         = [VMware.Vim.OptionValue]@{
                        key   = 'devices.hotplug'
                        Value = 'false'
                    }
                }
                [Void]($vm.ExtensionData.ReconfigVM_Task($spec))
                Write-LogMessage -Message "Configure Hardware Settings on: $vm" -Level 'INFO'
            }
        }

        # Complete
        Write-LogMessage -Message "Remediation of $($esxiHost.VMHost) completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level 'INFO'
        Write-LogMessage -Message 'Re-run the corresponding audit script to verify the remediation.' -Level 'INFO'

        # Disconnect from the ESXi host
        Disconnect-VIServer -Server $esxiHost.VMHost -Confirm:$false
        Write-LogMessage -Message "Disconnected from ESXi host $($esxiHost.VMHost)" -Level 'INFO'

    } else {

        # Disconnect from all ESXi Hosts and vCenter servers
        [Void](Disconnect-VIServer * -Confirm:$false -ErrorAction Ignore)
        Write-LogMessage -Message "Logon failed to ESXi host $($esxiHost.VMHost) - Still disconnect from all ESXi Hosts and vCenter servers" -Level 'ERROR'

        Write-LogMessage -Message "Logon failed $($esxiHost.VMHost) : $($_.Exception.Message)" -Level 'FAIL'

    }

}
