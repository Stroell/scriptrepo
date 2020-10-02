#************************************************************************************************************
# Disclaimer
#
# This sample script is not supported under any Microsoft standard support program or service. This sample
# script is provided AS IS without warranty of any kind. Microsoft further disclaims all implied warranties
# including, without limitation, any implied warranties of merchantability or of fitness for a particular
# purpose. The entire risk arising out of the use or performance of this sample script and documentation
# remains with you. In no event shall Microsoft, its authors, or anyone else involved in the creation,
# production, or delivery of this script be liable for any damages whatsoever (including, without limitation,
# damages for loss of business profits, business interruption, loss of business information, or other
# pecuniary loss) arising out of the use of or inability to use this sample script or documentation, even
# if Microsoft has been advised of the possibility of such damages.
#
#************************************************************************************************************

[CmdletBinding()]
param
(
    [switch]$InfoMode,
    [switch]$CipherChecks
)

$commandName = $MyInvocation.MyCommand.Name
#region Base checklist
<#
Site servers (central, primary, or secondary)
- Update .NET Framework (Version prüfen)
 - - NET Framework 4.6.2 and later supports TLS 1.1 and TLS 1.2. Confirm the registry settings, but no additional changes are required.
 - - Update NET Framework 4.6 and earlier versions to support TLS 1.1 and TLS 1.2. For more information, see .NET Framework versions and dependencies.
 - - If you're using .NET Framework 4.5.1 or 4.5.2 on Windows 8.1 or Windows Server 2012, the relevant updates and details are also available from the Download Center.
- Verify strong cryptography settings (Registry settings)

Site database server	
- Update SQL Server and its client components. Version: "11.*.7001.0"
- Microsoft SQL Server 2016 and later support TLS 1.1 and TLS 1.2. Earlier versions and dependent libraries might require updates. For more information, see KB 3135244: TLS 1.2 support for Microsoft SQL Server.

- SQL Server 2014 SP3 is the only supported service pack. Version: 12.0.6024.0
- SQL Server 2012 SP4 is the only supported service pack. Version: 11.0.7001.0
- SQL Server 2016 and above is okay: 13.0.1601.5 (-ge 13)

Secondary site servers 
- Update SQL Server and its client components to a compliant version of SQL Express
- Secondary site servers need to use at least SQL Server 2016 Express with Service Pack 2 (13.2.5026.0) or later.

Site system roles (also SMS Provider)
- Update .NET Framework 
- Verify strong cryptography settings
- Update SQL Server and its client components on roles that require it, including the SQL Server Native Client

Reporting services point
- Update .NET Framework on the site server, the SQL Reporting Services servers, and any computer with the console
- Restart the SMS_Executive service as necessary
- Check SQL Version

Software update point
- Update WSUS
- For WSUS server that's running Windows Server 2012, install update 4022721 or a later rollup update.
- For WSUS server that's running Windows Server 2012 R2, install update 4022720 or a later rollup update

Cloud management gateway
- Enforce TLS 1.2 (check console setting)

Configuration Manager console	
- Update .NET Framework
- Verify strong cryptography settings

Configuration Manager client with HTTPS site system roles
- Update Windows to support TLS 1.2 for client-server communications by using WinHTTP

Software Center
- Update .NET Framework
- Verify strong cryptography settings

Windows 7 clients
- Before you enable TLS 1.2 on any server components, update Windows to support TLS 1.2 for client-server communications by using WinHTTP. If you enable TLS 1.2 on server components first, you can orphan earlier versions of clients.
#>
#endregion

#region Test-SQLClientVersion
<#
.Synopsis
   Test-SQLClientVersion
.DESCRIPTION
   Minor versions schould not be checked, since the minor version varies: "11.*.7001.0"
   Major  Minor  Build  Revision
   -----  -----  -----  --------
   11     *      7001   0  
.EXAMPLE
   Test-SQLClientVersion
.EXAMPLE
   Test-SQLClientVersion -MinSQLClientVersion '11.4.7462.6'
.EXAMPLE
   Test-SQLClientVersion -Verbose
#>
function Test-SQLClientVersion
{
    [CmdletBinding()]
    [OutputType([object])]
    param
    (
        [version]$MinSQLClientVersion = "11.4.7004.0"
    )

    $commandName = $MyInvocation.MyCommand.Name
    Write-Verbose "$commandName`: "
    Write-Verbose "$commandName`: https://docs.microsoft.com/en-us/mem/configmgr/core/plan-design/security/enable-tls-1-2-server#bkmk_sql"

    $outObj = New-Object psobject | Select-Object InstalledVersion, MinRequiredVersion, TestResult
    $outObj.MinRequiredVersion = $MinSQLClientVersion.ToString()
    Write-Verbose "$commandName`: Minimum SQL ClientVersion: $($MinSQLClientVersion.ToString())"
    $SQLNCLI11RegPath = "HKLM:SOFTWARE\Microsoft\SQLNCLI11"
    If (Test-Path $SQLNCLI11RegPath)
    {
        [version]$InstalledVersion = (Get-ItemProperty $SQLNCLI11RegPath -ErrorAction SilentlyContinue)."InstalledVersion"
        if ($InstalledVersion)
        {
            $outObj.InstalledVersion = $InstalledVersion.ToString()
            # leaving minor version out
            Write-Verbose "$commandName`: Installed SQL ClientVersion: $($InstalledVersion.ToString())"
            if (($InstalledVersion.Major -ge $MinSQLClientVersion.Major) -and ($InstalledVersion.Build -ge $MinSQLClientVersion.Build) -and ($InstalledVersion.Revision -ge $MinSQLClientVersion.Revision))
            {
                $outObj.TestResult = $true
                return $outObj
            }
            else
            {
                Write-Verbose "$commandName`: Versions doen't match"
                $outObj.TestResult = $false
                return $outObj
            }
        }
        else
        {
            Write-Verbose "$commandName`: No SQL client version found in registry"
            $outObj.TestResult = $false
            return $outObj
        } 
    }
    else
    {
        Write-Verbose "$commandName`: RegPath not found `"$SQLNCLI11RegPath`""
        $outObj.TestResult = $false
        return $outObj
    }
}
#endregion

#region Test-NetFrameworkVersion
<#
.Synopsis
   Test-NetFrameworkVersion
.DESCRIPTION
   #
.EXAMPLE
   Test-NetFrameworkVersion
.EXAMPLE
   Test-NetFrameworkVersion -MinNetFrameworkRelease 393295
.EXAMPLE
   Test-NetFrameworkVersion -Verbose
#>
function Test-NetFrameworkVersion
{
    [CmdletBinding()]
    [OutputType([bool])]
    param
    (
        [int32]$MinNetFrameworkRelease = 393295
    )

    $commandName = $MyInvocation.MyCommand.Name
    Write-Verbose "$commandName`: "
    Write-Verbose "$commandName`: https://docs.microsoft.com/en-us/mem/configmgr/core/plan-design/security/enable-tls-1-2-server#bkmk_net"

    $outObj = New-Object psobject | Select-Object InstalledVersion, MinRequiredVersion, TestResult
    $outObj.MinRequiredVersion = $MinNetFrameworkRelease

    Write-Verbose "$commandName`: Minimum .Net Framework release: $MinNetFrameworkRelease"
    $NetFrameWorkRegPath = "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\"
    If (Test-Path $NetFrameWorkRegPath)
    {
        [int32]$ReleaseRegValue = (Get-ItemProperty $NetFrameWorkRegPath -ErrorAction SilentlyContinue).Release
        if ($ReleaseRegValue)
        {
            $outObj.InstalledVersion = $ReleaseRegValue
            Write-Verbose "$commandName`: Installed .Net Framework release: $MinNetFrameworkRelease"
            if ($ReleaseRegValue -ge $MinNetFrameworkRelease)
            {
                $outObj.TestResult = $true
                return $outObj
            }
            else
            {
                Write-Verbose "$commandName`: Versions doen't match"
                $outObj.TestResult = $false
                return $outObj
            }
            
        }
        else
        {
            Write-Verbose "$commandName`: No .Net version found in registry"
            $outObj.TestResult = $false
            return $outObj
        }
        
    }
    else
    {
        Write-Verbose "$commandName`: RegPath not found `"$NetFrameWorkRegPath`""
        $outObj.TestResult = $false
        return $outObj
    }
}
#endregion

#region Test-NetFrameworkSettings
<#
.Synopsis
   Test-NetFrameworkSettings
.DESCRIPTION
   #
.EXAMPLE
   Test-NetFrameworkSettings
.EXAMPLE
   Test-NetFrameworkSettings -Verbose
#>
function Test-NetFrameworkSettings
{
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $commandName = $MyInvocation.MyCommand.Name
    Write-Verbose "$commandName`: "
    Write-Verbose "$commandName`: https://docs.microsoft.com/en-us/mem/configmgr/core/plan-design/security/enable-tls-1-2-server#bkmk_net"

    [array]$dotNetVersionList = ('v2.0.50727','v4.0.30319')
    [array]$regPathPrefixList = ('HKLM:\SOFTWARE\Microsoft\.NETFramework','HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework')

    [bool]$expectedValuesSet = $true
    foreach ($dotNetVersion in $dotNetVersionList)
    {
        foreach ($regPathPrefix in $regPathPrefixList)
        {
            $regPath = "{0}\{1}" -f $regPathPrefix, $dotNetVersion
            Write-Verbose "$commandName`: Working on: `"$regPath`""
            $regProperties = Get-ItemProperty $regPath -ErrorAction SilentlyContinue
            if ($regProperties)
            {
                Write-Verbose "$commandName`: SystemDefaultTlsVersions = $($regProperties.SystemDefaultTlsVersions)"
                Write-Verbose "$commandName`: SchUseStrongCrypto = $($regProperties.SchUseStrongCrypto)"
                if (($regProperties.SystemDefaultTlsVersions -ne 1) -and ($regProperties.SchUseStrongCrypto -ne 1))
                {
                    $expectedValuesSet = $false
                    Write-Verbose "$commandName`: Wrong settings"
                }   
                else
                {
                    Write-Verbose "$commandName`: Settings okay"
                }        
            }
            else
            {
                $expectedValuesSet = $false
                Write-Verbose "$commandName`: No values found"
            }
        }
    }
    return $expectedValuesSet
}
#endregion

#region Test-SQLServerVersion
<#
.Synopsis
   Test-SQLServerVersion
.DESCRIPTION
    - Microsoft SQL Server 2016 and later support TLS 1.1 and TLS 1.2. Earlier versions and dependent libraries might require updates. 
      For more information, see KB 3135244: TLS 1.2 support for Microsoft SQL Server.
    - SQL Server 2014 SP3 is the only supported SP at the moment. Version: 12.0.6024.0
    - SQL Server 2012 SP4 is the only supported SP at the moment. Version: 11.0.7001.0
    - SQL Server 2016 and above is okay: 13.0.1601.5
    - Secondary site servers need to use at least SQL Server 2016 Express with Service Pack 2 (13.2.5026.0) or later.

    Using EngineEdition (int) to detect SQL Express
    1 = Personal or Desktop Engine (Not available in SQL Server 2005 (9.x) and later versions.)
    2 = Standard (This is returned for Standard, Web, and Business Intelligence.)
    3 = Enterprise (This is returned for Evaluation, Developer, and Enterprise editions.)
    4 = Express (This is returned for Express, Express with Tools, and Express with Advanced Services)
    5 = SQL Database
    6 = Microsoft Azure Synapse Analytics (formerly SQL Data Warehouse)
    8 = Azure SQL Managed Instance
    9 = Azure SQL Edge (this is returned for both editions of Azure SQL Edge

.EXAMPLE
   Test-SQLServerVersion
.EXAMPLE
   Test-SQLServerVersion -Verbose
#>
function Test-SQLServerVersion
{
    [CmdletBinding()]
    [OutputType([bool])]
    param
    (
        [string]$SQLServerName
    )

    $commandName = $MyInvocation.MyCommand.Name
    Write-Verbose "$commandName`: "
    Write-Verbose "$commandName`: https://docs.microsoft.com/en-us/mem/configmgr/core/plan-design/security/enable-tls-1-2"
    Write-Verbose "$commandName`: For SQL Express: https://docs.microsoft.com/en-us/mem/configmgr/core/plan-design/hierarchy/security-and-privacy-for-site-administration#update-sql-server-express-at-secondary-sites"
    $outObj = New-Object psobject | Select-Object InstalledVersion, MinRequiredVersion, TestResult

    $connectionString = "Server=$SQLServerName;Database=master;Integrated Security=True"
    Write-Verbose "$commandName`: Connecting to SQL: `"$connectionString`""
    $SqlQuery = "Select SERVERPROPERTY('ProductVersion') as 'Version', SERVERPROPERTY('EngineEdition') as 'EngineEdition'"
    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = $connectionString
    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
    $SqlCmd.Connection = $SqlConnection
    $SqlCmd.CommandText = $SqlQuery
    $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
    Write-Verbose "$commandName`: Running Query: `"$SqlQuery`""
    $SqlAdapter.SelectCommand = $SqlCmd
    $ds = New-Object System.Data.DataSet
    $SqlAdapter.Fill($ds) | Out-Null
    $SQLOutput = $ds.Tables[0]
    $SqlCmd.Dispose()
    [version]$SQLVersion = $SQLOutput.Version
    [int]$SQLEngineEdition = $SQLOutput.EngineEdition
    Write-Verbose "$commandName`: SQL EngineEdition: $SQLEngineEdition"
    Write-Verbose "$commandName`: SQL Version:$($SQLVersion.ToString())"
    $outObj.InstalledVersion = $SQLVersion.ToString()

    if ($SQLVersion -and $SQLEngineEdition)
    {
        switch ($SQLVersion.Major)
        {
            11 
            {
                [version]$minSQLVersion = '11.0.7001.0' #SQL Server 2012 SP4
                Write-Verbose "$commandName`: Minimum version for SQL Server 2012 SP4: $($minSQLVersion.ToString())"
            }

            12 
            {
                [version]$minSQLVersion = '12.0.6024.0' #SQL Server 2014 SP3
                Write-Verbose "$commandName`: Minimum version for SQL Server 2014 SP3: $($minSQLVersion.ToString())"
            }

            13 
            {
                if ($SQLEngineEdition -eq 4) # 4 = Express Edition
                {
                    [version]$minSQLVersion = '13.2.5026.0' # SQL Server 2016 SP2 Express and higher
                    Write-Verbose "$commandName`: Minimum version for SQL Server 2016 SP2 Express and higher: $($minSQLVersion.ToString())"
                }
                else
                {
                    [version]$minSQLVersion = '13.0.1601.5' #SQL Server 2016 and higher
                    Write-Verbose "$commandName`: Minimum version for SQL Server 2016 and higher: $($minSQLVersion.ToString())"
                }
            }
            
            Default
            {
                [version]$minSQLVersion = '14.0.0.0' #SQL Server 2017 and higher
                Write-Verbose "$commandName`: Minimum version for SQL Server 2017 and higher: $($minSQLVersion.ToString())"         
            }
        } # end switch

        $outObj.MinRequiredVersion = $minSQLVersion.ToString()
        if ($SQLVersion -ge $minSQLVersion)
        {
            $outObj.TestResult = $true
            return $outObj
        }
        else
        {
            $outObj.TestResult = $false
            return $outObj
        } 

    }
    else
    {
        Write-Verbose "$commandName`: Failed to get SQL version and EngineEdition!"
        $outObj.TestResult = $False
        return $outObj
    }
}
#endregion

#region Test-WSUSVersion
<#
.Synopsis
   Test-WSUSVersion
.DESCRIPTION
   #
.EXAMPLE
   Test-WSUSVersion
.EXAMPLE
   Test-WSUSVersion -Verbose
#>
function Test-WSUSVersion
{
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $commandName = $MyInvocation.MyCommand.Name
    # only applicable to Server 2012 or 2012 R2, higher versions are TLS 1.2 capable
    # https://docs.microsoft.com/en-us/windows/win32/cimwin32prov/win32-operatingsystem
    Write-Verbose "$commandName`: "
    Write-Verbose "$commandName`: https://docs.microsoft.com/en-us/mem/configmgr/core/plan-design/security/enable-tls-1-2" 
    Write-Verbose "$commandName`: Getting OS version"
    $wmiQuery = "SELECT * FROM Win32_OperatingSystem WHERE ProductType<>'1'"
    Write-Verbose "$commandName`: Get-WmiObject -Namespace `"root\cimv2`" `"$wmiQuery`""

    $serverOS = Get-WmiObject -Namespace "root\cimv2" -query "$wmiQuery" -ErrorAction SilentlyContinue
    if ($serverOS)
    {
        [version]$serverOSVersion = $serverOS.Version
        Write-Verbose "$commandName`: Server OS version: $($serverOSVersion.ToString())"
    }

    $outObj = New-Object psobject | Select-Object InstalledVersion, MinRequiredVersion, TestResult
    
    Write-Verbose "$commandName`: Getting WsusService.exe version"    
    $regPath = "HKLM:\SOFTWARE\Microsoft\Update Services\Server\Setup"
    $wsusServiceEntries = Get-ItemProperty $regPath -ErrorAction SilentlyContinue 
    if ($wsusServiceEntries)
    {
        $WsusServicePath = "{0}{1}" -f ($wsusServiceEntries.TargetDir), "Services\WsusService.exe"
        $WsusServiceFile = Get-Item $WsusServicePath -ErrorAction SilentlyContinue
        [version]$WsusServiceFileVersion = $WsusServiceFile.VersionInfo.FileVersion
        Write-Verbose "$commandName`: WsusService.exe version: $($WsusServiceFileVersion.ToString())"
        $outObj.InstalledVersion = $WsusServiceFileVersion.ToString()

        if($wsusServiceEntries.UsingSSL -ne 1)
        {
            Write-Warning "$commandName`: WSUS configuration not following best practices. SSL should be enabled. UsingSSL = $($wsusServiceEntries.UsingSSL)"
        }   

        # only applicable to Server 2012 or 2012 R2, higher versions are TLS 1.2 capable
        $majorMinor = "{0}.{1}" -f ($WsusServiceFileVersion.Major), ($WsusServiceFileVersion.Minor)

        switch ($majorMinor)
        {
            '6.0' # Windows Server 2008
            {
                [version]$minWsusServiceVersion = '0.0'
                $outObj.MinRequiredVersion = $minWsusServiceVersion.ToString()
            }
            '6.1' # Windows Server 2008 R2
            {
                [version]$minWsusServiceVersion = '0.0'
                $outObj.MinRequiredVersion = $minWsusServiceVersion.ToString()
            }
            '6.2' # Windows Server 2012
            {
                [version]$minWsusServiceVersion = '6.2.9200.22167'
                $outObj.MinRequiredVersion = $minWsusServiceVersion.ToString()

            }
            '6.3' # Windows Server 2012 R2
            {
                [version]$minWsusServiceVersion = '6.3.9600.18694'
                $outObj.MinRequiredVersion = $minWsusServiceVersion.ToString()

            }
            '10.0' # Windows Server 2016 and higher
            {
                [version]$minWsusServiceVersion =  '10.0'
                $outObj.MinRequiredVersion = $minWsusServiceVersion.ToString()
            }
            Default
            {
                Write-Warning "$commandName`:Unknown OS version: $majorMinor"
                [version]$wsusServiceVersion = '0.0'
                $outObj.MinRequiredVersion = $minWsusServiceVersion.ToString()
            }
        }

        if($WsusServiceFileVersion -ge $minWsusServiceVersion)
        {
            $outObj.TestResult = $true
            return $outObj
        }
        else
        {
            $outObj.TestResult = $false
            return $outObj
        }

    }
}
#endregion

#region Test-CMGSettings
<#
.Synopsis
   Test-CMGSettings
.DESCRIPTION
   #
.EXAMPLE
   Test-CMGSettings
.EXAMPLE
   Test-CMGSettings -Verbose
#>
function Test-CMGSettings
{
    [CmdletBinding()]
    [OutputType([bool])]
    param()


    $commandName = $MyInvocation.MyCommand.Name
    Write-Verbose "$commandName`: "
    [bool]$expectedValuesSet = $true
    # getting sitecode first
    $query = "SELECT * FROM SMS_ProviderLocation WHERE Machine like '$($env:computername)%' AND ProviderForLocalSite = 'True'"
    Write-Verbose "$commandName`: Running: `"$query`""
    $SiteCode = Get-WmiObject -Namespace "root\sms" -Query $query | Select-Object SiteCode -ExpandProperty SiteCode
    Write-Verbose "$commandName`: SiteCode: $SiteCode"
    # getting cmg info
    $query = "SELECT * FROM SMS_AzureService WHERE ServiceType = 'CloudProxyService'"
    Write-Verbose "$commandName`: Running: `"$query`""
    [array]$azureServices = Get-WmiObject -Namespace "root\sms\site_$SiteCode" -Query $query
    if ($azureServices)
    {
        $azureServices | ForEach-Object {
        
            if (-NOT($_.ClientCertRevocationEnabled))
            {
                Write-Verbose "$commandName`: CMG not using certificate best practices. ClientCertRevocationEnabled = $($_.ClientCertRevocationEnabled)"
            }

            if($_.ProxySecurityProtocol -eq 3072)
            {
                Write-Verbose "$commandName`: CMG `"$($_.Name)`" set to enforce TLS 1.2"
            }
            else
            {
                Write-Verbose "$commandName`: CMG `"$($_.Name)`" not set to enforce TLS 1.2"
                $expectedValuesSet = $false          
            }
         }
    }
    else
    {
        Write-Verbose "$commandName`: No Cloud Management Gateway (CMG) found!"
        return
    }
    
    if (-NOT($expectedValuesSet))
    {
        Write-verbose "$commandName`: https://docs.microsoft.com/en-us/mem/configmgr/core/clients/manage/cmg/setup-cloud-management-gateway"
        return $false
    }
    else
    {
        return $true
    }
}
#endregion

#region Test-WinHTTPSettings
<#
.Synopsis
   Test-WinHTTPSettings
.DESCRIPTION
   Windows 8.1, Windows Server 2012 R2, Windows 10, Windows Server 2016, and later versions of Windows natively support TLS 1.2 
   for client-server communications over WinHTTP. 
   Earlier versions of Windows, such as Windows 7 or Windows Server 2012, don't enable TLS 1.1 or TLS 1.2 by default for secure 
   communications using WinHTTP. For these earlier versions of Windows, install Update 3140245 to enable the registry values below, 
   which can be set to add TLS 1.1 and TLS 1.2 to the default secure protocols list for WinHTTP. With the patch installed, create the following registry values:
   HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp\
   DefaultSecureProtocols = (DWORD): 0xAA0
   HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp\
   DefaultSecureProtocols = (DWORD): 0xAA0
   https://docs.microsoft.com/en-us/mem/configmgr/core/plan-design/security/enable-tls-1-2-client#bkmk_winhttp
.EXAMPLE
   Test-WinHTTPSettings
.EXAMPLE
   Test-WinHTTPSettings -Verbose
#>
function Test-WinHTTPSettings
{
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $commandName = $MyInvocation.MyCommand.Name
    #Write-Verbose "$commandName`: "
    # Check for update: http://support.microsoft.com/kb/3140245
    # in quickfixengineering 
    # plus reg key check

}
#endregion

#region Test-SCHANNELKeyExchangeAlgorithms
<#
.Synopsis
   Test-SCHANNELKeyExchangeAlgorithms
.DESCRIPTION
   # https://docs.microsoft.com/en-us/dotnet/framework/network-programming/tls#configuring-schannel-protocols-in-the-windows-registry
   # https://docs.microsoft.com/en-us/troubleshoot/windows-server/windows-security/restrict-cryptographic-algorithms-protocols-schannel
.EXAMPLE
   Test-SCHANNELKeyExchangeAlgorithms
.EXAMPLE
   Test-SCHANNELKeyExchangeAlgorithms -Verbose
#>
function Test-SCHANNELKeyExchangeAlgorithms
{
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $commandName = $MyInvocation.MyCommand.Name
    Write-Verbose "$commandName`: "
    Write-Verbose "$commandName`: https://docs.microsoft.com/en-us/troubleshoot/windows-server/windows-security/restrict-cryptographic-algorithms-protocols-schannel"
    
    $desiredKeyExchangeAlgorithmStates = [ordered]@{
        "Diffie-Hellman" = "Enabled"; 
        "PKCS" = "Enabled"; 
        "ECDH" = "Enabled"; 
    }
    $DiffieHellmanServerMinKeyBitLength = 2048

    $expectedValuesSet = $true
    $desiredKeyExchangeAlgorithmStates.GetEnumerator() | ForEach-Object {
        
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\KeyExchangeAlgorithms\{0}" -f ($_.Name)
        Write-Verbose "$commandName`: Working on: `"$regPath`""
        $regProperties = Get-ItemProperty $regPath -ErrorAction SilentlyContinue
        if ($regProperties)
        {
            $enabledValue = if ($_.Value -eq 'Enabled'){4294967295}else{0} # enabled is decimal 4294967295 or hex 0xffffffff

            if ($_.Name -eq 'Diffie-Hellman')
            {
                if ($regProperties.ServerMinKeyBitLength -ne $DiffieHellmanServerMinKeyBitLength)
                {
                    Write-Verbose "$commandName`: Diffie-Hellman ServerMinKeyBitLength is set to: $($regProperties.ServerMinKeyBitLength)" 
                    Write-Verbose "$commandName`: Expected value: $DiffieHellmanServerMinKeyBitLength"
                    $expectedValuesSet = $false
                }
                else
                {
                    Write-Verbose "$commandName`: Diffie-Hellman ServerMinKeyBitLength is set correctly to: $($regProperties.ServerMinKeyBitLength)"    
                }
            }


            Write-Verbose "$commandName`: Enabled = $($regProperties.Enabled)"
            if ($regProperties.Enabled -ne $enabledValue)
            {
                $expectedValuesSet = $false
                Write-Verbose "$commandName`: Wrong settings"
            }
            else
            {
                Write-Verbose "$commandName`: Settings okay"
            }  

        }
        else
        {
            $expectedValuesSet = $false
            Write-Verbose "$commandName`: No values found"
        }
   
    }
    return $expectedValuesSet
}
#endregion

#region Test-SCHANNEHashes
<#
.Synopsis
   Test-SCHANNEHashes
.DESCRIPTION
   # https://docs.microsoft.com/en-us/dotnet/framework/network-programming/tls#configuring-schannel-protocols-in-the-windows-registry
   # https://docs.microsoft.com/en-us/troubleshoot/windows-server/windows-security/restrict-cryptographic-algorithms-protocols-schannel
.EXAMPLE
   Test-SCHANNEHashes
.EXAMPLE
   Test-SCHANNEHashes -Verbose
#>
function Test-SCHANNELHashes
{
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $commandName = $MyInvocation.MyCommand.Name
    Write-Verbose "$commandName`: "
    Write-Verbose "$commandName`: https://docs.microsoft.com/en-us/troubleshoot/windows-server/windows-security/restrict-cryptographic-algorithms-protocols-schannel"

    $desiredHashStates = [ordered]@{
        "SHA256" = "Enabled"; 
        "SHA384" = "Enabled"; 
        "SHA512" = "Enabled"; 
    }

    $expectedValuesSet = $true
    $desiredHashStates.GetEnumerator() | ForEach-Object {
        
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Hashes\{0}" -f ($_.Name)
        Write-Verbose "$commandName`: Working on: `"$regPath`""
        $regProperties = Get-ItemProperty $regPath -ErrorAction SilentlyContinue
        if ($regProperties)
        {
            $enabledValue = if ($_.Value -eq 'Enabled'){4294967295}else{0} # enabled is decimal 4294967295 or hex 0xffffffff

            Write-Verbose "$commandName`: Enabled = $($regProperties.Enabled)"
            if ($regProperties.Enabled -ne $enabledValue)
            {
                $expectedValuesSet = $false
                Write-Verbose "$commandName`: Wrong settings"
            }
            else
            {
                Write-Verbose "$commandName`: Settings okay"
            }  

        }
        else
        {
            $expectedValuesSet = $false
            Write-Verbose "$commandName`: No values found"
        }     
    }
    return $expectedValuesSet
}
#endregion

#region Test-SCHANNECiphers
<#
.Synopsis
   Test-SCHANNECiphers
.DESCRIPTION
   # https://docs.microsoft.com/en-us/dotnet/framework/network-programming/tls#configuring-schannel-protocols-in-the-windows-registry
   # https://docs.microsoft.com/en-us/troubleshoot/windows-server/windows-security/restrict-cryptographic-algorithms-protocols-schannel
.EXAMPLE
   Test-SCHANNECiphers
.EXAMPLE
   Test-SCHANNECiphers -Verbose
#>
function Test-SCHANNELCiphers
{
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $commandName = $MyInvocation.MyCommand.Name
    Write-Verbose "$commandName`: "
    Write-Verbose "$commandName`: https://docs.microsoft.com/en-us/troubleshoot/windows-server/windows-security/restrict-cryptographic-algorithms-protocols-schannel"

    $desiredCipherStates = [ordered]@{
        "NULL" = "Disabled"; 
        "DES 56/56" = "Disabled"; 
        "RC2 40/128" = "Disabled"; 
        "RC2 56/128" = "Disabled"; 
        "RC2 128/128" = "Disabled";
        "RC4 40/128" = "Disabled";
        "RC4 56/128" = "Disabled";
        "RC4 64/128" = "Disabled";
        "RC4 128/128" = "Disabled";
        "Triple DES 168" = "Enabled";
        "AES 128/128" = "Enabled";
        "AES 256/256" = "Enabled"
    }

    $expectedValuesSet = $true
    $desiredCipherStates.GetEnumerator() | ForEach-Object {
        
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\{0}" -f ($_.Name)
        Write-Verbose "$commandName`: Working on: `"$regPath`""
        $regProperties = Get-ItemProperty $regPath -ErrorAction SilentlyContinue
        if ($regProperties)
        {
            $enabledValue = if ($_.Value -eq 'Enabled'){4294967295}else{0} # enabled is decimal 4294967295 or hex 0xffffffff

            Write-Verbose "$commandName`: Enabled = $($regProperties.Enabled)"
            if ($regProperties.Enabled -ne $enabledValue)
            {
                $expectedValuesSet = $false
                Write-Verbose "$commandName`: Wrong settings"
            }
            else
            {
                Write-Verbose "$commandName`: Settings okay"
            }  

        }
        else
        {
            $expectedValuesSet = $false
            Write-Verbose "$commandName`: No values found"
        }     
    }
    return $expectedValuesSet
}
#endregion

#region Test-CipherSuites
<#
.Synopsis
   Test-CipherSuites
.DESCRIPTION
   # https://docs.microsoft.com/en-us/troubleshoot/windows-server/windows-security/restrict-cryptographic-algorithms-protocols-schannel
   # https://docs.microsoft.com/en-us/windows/win32/secauthn/cipher-suites-in-schannel
    TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384_P384

    ECDHE = Key Exchnage
    ECDSA = Signature
    AES_256_GCM = Bulk Encryption (Cypther)
    SHA384 = Message Authentication
    P384 = Elliptic Curve
.EXAMPLE
   Test-CipherSuites
.EXAMPLE
   Test-CipherSuites -Verbose
#>
function Test-CipherSuites
{
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $commandName = $MyInvocation.MyCommand.Name
    Write-Verbose "$commandName`: "
    Write-Verbose "$commandName`: https://docs.microsoft.com/en-us/windows/win32/secauthn/cipher-suites-in-schannel"

    $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Cryptography\Configuration\SSL\00010002"
    # ONLY SERVER 2016 currently
    $desiredCipherSuiteStates = [ordered]@{
        "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384" = "Enabled";
        "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256" = "Enabled";
        "TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384" = "Enabled";
        "TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256" = "Enabled";
        "TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA" = "Enabled";
        "TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA" = "Enabled";
        "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384" = "Enabled";
        "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256" = "Enabled";
        "TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384" = "Enabled";
        "TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256" = "Enabled";
        "TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA" = "Enabled";
        "TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA" = "Enabled";
        "TLS_RSA_WITH_AES_256_GCM_SHA384" = "Enabled";
        "TLS_RSA_WITH_AES_128_GCM_SHA256" = "Enabled";
        "TLS_RSA_WITH_AES_256_CBC_SHA256" = "Enabled";
        "TLS_RSA_WITH_AES_128_CBC_SHA256" = "Enabled";
        "TLS_RSA_WITH_AES_256_CBC_SHA" = "Enabled";
        "TLS_RSA_WITH_AES_128_CBC_SHA" = "Enabled";
        "TLS_DHE_RSA_WITH_AES_256_GCM_SHA384" = "Disabled";
        "TLS_DHE_RSA_WITH_AES_128_GCM_SHA256" = "Disabled";
        "TLS_DHE_RSA_WITH_AES_256_CBC_SHA" = "Disabled";
        "TLS_DHE_RSA_WITH_AES_128_CBC_SHA" = "Disabled";
        "TLS_RSA_WITH_3DES_EDE_CBC_SHA" = "Disabled";
        "TLS_DHE_DSS_WITH_AES_256_CBC_SHA256" = "Disabled";
        "TLS_DHE_DSS_WITH_AES_128_CBC_SHA256" = "Disabled";
        "TLS_DHE_DSS_WITH_AES_256_CBC_SHA" = "Disabled";
        "TLS_DHE_DSS_WITH_AES_128_CBC_SHA" = "Disabled";
        "TLS_DHE_DSS_WITH_3DES_EDE_CBC_SHA" = "Disabled";
        "TLS_RSA_WITH_RC4_128_SHA" = "Disabled";
        "TLS_RSA_WITH_RC4_128_MD5" = "Disabled";
        "TLS_RSA_WITH_NULL_SHA256" = "Disabled";
        "TLS_RSA_WITH_NULL_SHA" = "Disabled";
        "TLS_PSK_WITH_AES_256_GCM_SHA384" = "Disabled";
        "TLS_PSK_WITH_AES_128_GCM_SHA256" = "Disabled";
        "TLS_PSK_WITH_AES_256_CBC_SHA384" = "Disabled";
        "TLS_PSK_WITH_AES_128_CBC_SHA256" = "Disabled";
        "TLS_PSK_WITH_NULL_SHA384" = "Disabled";
        "TLS_PSK_WITH_NULL_SHA256" = "Disabled"
    }



    # building string from hashtable, because the value ist stored that way in the registry
    # the hashtable is just an easy way of ordering and enabling or disabling cipher suites
    [string]$desiredCipherSuiteStateString = ""
    $desiredCipherSuiteStates.GetEnumerator() | ForEach-Object {

        if ($_.Value -eq 'Enabled')
        {
            $desiredCipherSuiteStateString += "{0}," -f $_.Name
        }
    }
    #removing last comma
    $desiredCipherSuiteStateString = $desiredCipherSuiteStateString -replace '.$'

    Write-Verbose "$commandName`: Cipher suite order can be adjusted using the following registry path."
    Write-Verbose "$commandName`: IMPORTANT: the value is just an example and you might need to adjust the values for your environment."
    Write-Verbose "$commandName`: Path: `"$regPath`""
    Write-Verbose "$commandName`: REG_SZ: `"Functions`""
    Write-Verbose "$commandName`: Value: `"$desiredCipherSuiteStateString`""


    # getting current cipher suite configuration
    [array]$currentCipherSuites = Get-TlsCipherSuite -ErrorAction SilentlyContinue
    if (-NOT($currentCipherSuites))
    {
        Write-Verbose "$commandName`: No cipher suite settings found with: `"Get-TlsCipherSuite`""
        return $false
    }
    else
    {
        # list of active cipher suites has to have the same entry count as the desired state
        $enabledCipherSuites = $desiredCipherSuiteStates.GetEnumerator() | Where-Object {$_.Value -eq 'Enabled'}
        if(-NOT($currentCipherSuites.Count -eq  $enabledCipherSuites.Count))
        {
            Write-Verbose "$commandName`: Current cipherSuites not in desired state"
            return $false
        }
        else
        {
            # checking cipher suite order

            $i = 0
            $desiredStateSet = $true
            $enabledcipherSuites | ForEach-Object {
                if (-NOT($_.Name -eq $currentcipherSuites[$i].Name))
                {
                    $desiredStateSet = $false
                }
                $i++
            }
            if ($desiredStateSet)
            {
                Write-Verbose "$commandName`: cipher suite order set as desired"
                return $true
            }
            else
            {
                Write-Verbose "$commandName`: cipher suite order NOT set as desired"
                return $false
            }
        }     
    }
}
#endregion

#region Test-SCHANNELSettings
<#
.Synopsis
   Test-SCHANNELSettings
.DESCRIPTION
   # https://docs.microsoft.com/en-us/dotnet/framework/network-programming/tls#configuring-schannel-protocols-in-the-windows-registry
   # https://docs.microsoft.com/en-us/troubleshoot/windows-server/windows-security/restrict-cryptographic-algorithms-protocols-schannel
.EXAMPLE
   Test-SCHANNELSettings
.EXAMPLE
   Test-SCHANNELSettings -Verbose
#>
function Test-SCHANNELSettings
{
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $commandName = $MyInvocation.MyCommand.Name
    Write-Verbose "$commandName`: "
    Write-Verbose "$commandName`: https://docs.microsoft.com/en-us/troubleshoot/windows-server/windows-security/restrict-cryptographic-algorithms-protocols-schannel"

    $desiredProtocolStates = [ordered]@{
        "SSL 2.0" = "Disabled"; # Disabled, will automatically validate DisabledByDefault with the opposite value, to ensure the same settings
        "SSL 3.0" = "Disabled"; # Disabled, will automatically validate DisabledByDefault with the opposite value, to ensure the same settings
        "TLS 1.0" = "Enabled"; # Disabled, will automatically validate DisabledByDefault with the opposite value, to ensure the same settings
        "TLS 1.1" = "Enabled"; # Disabled, will automatically validate DisabledByDefault with the opposite value, to ensure the same settings
        "TLS 1.2" = "Enabled"  # Enabled, will automatically validate DisabledByDefault with the opposite value, to ensure the same settings
    }

    [array]$subKeyCollection = ("Client","Server")
    [bool]$expectedValuesSet = $true

    $desiredProtocolStates.GetEnumerator() | ForEach-Object {

        foreach ($subKey in $subKeyCollection)
        {
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\{0}\{1}" -f ($_.Name), $subKey
            Write-Verbose "$commandName`: Working on: `"$regPath`""
            $regProperties = Get-ItemProperty $regPath -ErrorAction SilentlyContinue
            if ($regProperties)
            {
                $disabledByDefaultValue = if ($_.Value -eq 'Disabled'){1}else{0} 

                $enabledValue = if ($_.Value -eq 'Enabled'){4294967295}else{0} # enabled is decimal 4294967295 or hex 0xffffffff

                Write-Verbose "$commandName`: DisabledByDefault = $($regProperties.DisabledByDefault)"
                Write-Verbose "$commandName`: Enabled = $($regProperties.Enabled)"
                # both values schould be set
                if (($regProperties.DisabledByDefault -ne $disabledByDefaultValue) -or ($regProperties.Enabled -ne $enabledValue))
                {
                    $expectedValuesSet = $false
                    Write-Verbose "$commandName`: Wrong settings"
                }
                else
                {
                    Write-Verbose "$commandName`: Settings okay"
                }  

            }
            else
            {
                $expectedValuesSet = $false
                Write-Verbose "$commandName`: No values found"
            }
        }
    }
    return $expectedValuesSet
}
#endregion

#region Get-OSTypeInfo
<#
.Synopsis
   Get-OSTypeInfo
.DESCRIPTION
   Get-OSTypeInfo
.EXAMPLE
   Get-OSTypeInfo
.EXAMPLE
   Get-OSTypeInfo -Verbose
#>
function Get-OSTypeInfo
{
    [CmdletBinding()]
    [OutputType([object])]
    param()

    $commandName = $MyInvocation.MyCommand.Name
    Write-Verbose "$commandName`: "
    Write-Verbose "$commandName`: Getting OS type information"
    $wmiQuery = "SELECT * FROM Win32_OperatingSystem"
    Write-Verbose "$commandName`: Get-WmiObject -Namespace `"root\cimv2`" `"$wmiQuery`""
    $Win32OperatingSystem = Get-WmiObject -Namespace "root\cimv2" -query "$wmiQuery" -ErrorAction SilentlyContinue
    if ($Win32OperatingSystem)
    {
        switch ($Win32OperatingSystem.ProductType)
        {
            1 {$Win32OperatingSystem | Add-Member -Name 'ProductTypeName' -Value 'Workstation' -MemberType NoteProperty}
            2 {$Win32OperatingSystem | Add-Member -Name 'ProductTypeName' -Value 'Domain Controller' -MemberType NoteProperty}
            3 {$Win32OperatingSystem | Add-Member -Name 'ProductTypeName' -Value 'Server' -MemberType NoteProperty}
            Default {}
        }
        return $Win32OperatingSystem | Select-Object Caption, Version, ProductType, ProductTypeName
    }
    else
    {
        return $false
    }
}
#endregion