# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

function Check-SubscriptionLogIn
{
    param (
        [object] $SubscriptionId,
        [object] $AzKVaultName
    )

    if("string" -ne $SubscriptionId.GetType().Name)
    {
        throw "The type of SubscriptionId should be string, current is " + $SubscriptionId.GetType().Name + ". Please check registration information by 'Get-SecretVault | fl'"
    }

    if("string" -ne $AzKVaultName.GetType().Name)
    {
        throw "The type of AzKVaultName should be string, current is " + $AzKVaultName.GetType().Name + ". Please check registration information by 'Get-SecretVault | fl'"
    }

    $azContext = Az.Accounts\Get-AzContext
    if (($null -eq $azContext) -or ($azContext.Subscription.Id -ne $SubscriptionId))
    {
        try
        {
            Set-AzContext -SubscriptionId ${SubscriptionId} -ErrorAction Stop
        }
        catch
        {
            throw $_.ToString() + "To use Azure vault named '${AzKVaultName}', please try 'Connect-AzAccount -SubscriptionId {SubscriptionId}' to log into Azure account subscription '${SubscriptionId}'." 
        }
    }
}

function Get-Secret
{
    param (
        [string] $Name,
        [string] $VaultName,
        [hashtable] $AdditionalParameters
    )

    $secret = Az.KeyVault\Get-AzKeyVaultSecret -Name $Name -VaultName $AdditionalParameters.AZKVaultName
    if ($null -ne $secret)
    {
        switch ($secret.ContentType) {
            'ByteArray' 
            {  
                $SecretValue = Get-ByteArray $Secret
            }
            'String'
            {
                $SecretValue = Get-String $Secret
            }
            'PSCredential' 
            {
                $SecretValue = Get-PSCredential $Secret
            }
            'Hashtable' 
            {  
                $SecretValue = Get-Hashtable $Secret
            }
            Default 
            {
                $SecretValue = Get-SecureString $Secret
            }
        }
        return $SecretValue
    }
}

function Get-ByteArray
{
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [object] $Secret
    )
    $secretValueText = Get-String $Secret
    return [System.Text.Encoding]::ASCII.GetBytes($secretValueText)
}

function Get-String
{
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [object] $Secret
    )

    $ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secret.SecretValue)
    try {
        $secretValueText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ssPtr)
    } finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ssPtr)
    }
    return $secretValueText
}

function Get-SecureString
{
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [object] $Secret
    )

    return $Secret.SecretValue
}

function Get-PSCredential
{
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [object] $Secret
    )

    $secretHashTable = Get-Hashtable $Secret
    return [System.Management.Automation.PSCredential]::new($secretHashTable["UserName"], ($secretHashTable["Password"] | ConvertTo-SecureString -AsPlainText -Force)) 
}

function Get-Hashtable
{
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [object] $Secret
    )

    $jsonObject = Get-String $Secret | ConvertFrom-Json
    $hashtable = @{}
    $jsonObject.psobject.Properties | foreach { $hashtable[$_.Name] = $_.Value }
    return $hashtable
}

function Set-Secret
{
    param (
        [string] $Name,
        [object] $Secret,
        [string] $VaultName,
        [hashtable] $AdditionalParameters
    )

    switch ($Secret.GetType().Name) {
        'Byte[]' 
        {
            Set-ByteArray -Name $Name -Secret $Secret -AZKVaultName $AdditionalParameters.AZKVaultName -ContentType 'ByteArray'
        }
        'String'
        {
            Set-String -Name $Name -Secret $Secret -AZKVaultName $AdditionalParameters.AZKVaultName -ContentType 'String'
        }
        'SecureString'
        {
            Set-SecureString -Name $Name -Secret $Secret -AZKVaultName $AdditionalParameters.AZKVaultName -ContentType 'SecureString'
        }
        'PSCredential' 
        {
            Set-PSCredential -Name $Name -Secret $Secret -AZKVaultName $AdditionalParameters.AZKVaultName -ContentType 'PSCredential'
        }
        'Hashtable' 
        {  
            Set-Hashtable -Name $Name -Secret $Secret -AZKVaultName $AdditionalParameters.AZKVaultName -ContentType 'Hashtable'
        }
        Default
        {
            throw "Invalid type. Types supported: byte[], string, SecureString, PSCredential, Hashtable";
        }
    }

    return $?
}

function Set-ByteArray
{
    param (
        [string] $Name,
        [Byte[]] $Secret,
        [string] $AZKVaultName,
        [string] $ContentType
    )

    $SecretString = [System.Text.Encoding]::ASCII.GetString($Secret)
    Set-String -Name $Name -Secret $SecretString -AZKVaultName $AZKVaultName -ContentType $ContentType
}

function Set-String
{
    param (
        [string] $Name,
        [string] $Secret,
        [string] $AZKVaultName,
        [string] $ContentType
    )
    $SecureSecret = ConvertTo-SecureString -String $Secret -AsPlainText -Force
    $null = Az.KeyVault\Set-AzKeyVaultSecret -Name $Name -SecretValue $SecureSecret -VaultName $AZKVaultName -ContentType $ContentType
}

function Set-SecureString
{
    param (
        [string] $Name,
        [SecureString] $Secret,
        [string] $AZKVaultName,
        [string] $ContentType
    )
    
    $null = Az.KeyVault\Set-AzKeyVaultSecret -Name $Name -SecretValue $Secret -VaultName $AZKVaultName -ContentType $ContentType
}

function Set-PSCredential
{
    param (
        [string] $Name,
        [PSCredential] $Secret,
        [string] $AZKVaultName,
        [string] $ContentType
    )
    $secretHashTable = @{"UserName" = $Secret.UserName; "Password" = $Secret.GetNetworkCredential().Password}
    $SecretString = ConvertTo-Json $secretHashTable
    Set-String -Name $Name -Secret $SecretString -AZKVaultName $AZKVaultName -ContentType $ContentType
}

function Set-Hashtable
{
    param (
        [string] $Name,
        [Hashtable] $Secret,
        [string] $AZKVaultName,
        [string] $ContentType
    )
    $SecretString = ConvertTo-Json $Secret
    Set-String -Name $Name -Secret $SecretString -AZKVaultName $AZKVaultName -ContentType $ContentType
}

function Remove-Secret
{
    param (
        [string] $Name,
        [string] $VaultName,
        [hashtable] $AdditionalParameters
    )

    $null = Az.KeyVault\Remove-AzKeyVaultSecret -Name $Name -VaultName $AdditionalParameters.AZKVaultName -Force
    return $?
}

function Get-SecretInfo
{
    param (
        [string] $Filter,
        [string] $VaultName,
        [hashtable] $AdditionalParameters
    )
   
    if ([string]::IsNullOrEmpty($Filter))
    {
        $Filter = "*"
    }

    $pattern = [WildcardPattern]::new($Filter)

    $vaultSecretInfos = Az.KeyVault\Get-AzKeyVaultSecret -VaultName $AdditionalParameters.AZKVaultName

    foreach ($vaultSecretInfo in $vaultSecretInfos)
    {
        if ($pattern.IsMatch($vaultSecretInfo.Name))
        {
            [Microsoft.PowerShell.SecretManagement.SecretType]$secretType = New-Object Microsoft.PowerShell.SecretManagement.SecretType
            if (![System.Enum]::TryParse($vaultSecretInfo.ContentType, $true, [ref]$secretType))
            {
                $secretType = "Unknown"
            }
            Write-Output (
                [Microsoft.PowerShell.SecretManagement.SecretInformation]::new(
                    $vaultSecretInfo.Name,
                    $secretType,
                    $VaultName)
            )
        }
    }
}

function Test-SecretVault
{
    param (
        [string] $VaultName,
        [hashtable] $AdditionalParameters
    )

    try
    {
        Check-SubscriptionLogIn $AdditionalParameters.SubscriptionId $AdditionalParameters.AZKVaultName
    }
    catch
    {
        Write-Error $_
        return $false
    }

    return $true
}
# SIG # Begin signature block
# MIInbgYJKoZIhvcNAQcCoIInXzCCJ1sCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCyKy+DlRs3fTBA
# u5XhgR3udHDfTLCuiuI7TkzA4f8+cKCCDMkwggYEMIID7KADAgECAhMzAAACHPrN
# xZvoL37EAAAAAAIcMA0GCSqGSIb3DQEBCwUAMFcxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBD
# b2RlIFNpZ25pbmcgUENBIDIwMjQwHhcNMjYwNDE2MTg1OTQxWhcNMjcwNDE1MTg1
# OTQxWjB0MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYD
# VQQDExVNaWNyb3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IB
# DwAwggEKAoIBAQDVsZfgOKmM31HPfoWOoNEiw0SlCiIxUMC0I9NMWbucKOw/e9lP
# oAoehQVu6SG65V4EPzrYsnBnFPNoi4/HoOdjhz1qkrEt4I6tEcxXU6oOeY9zGveC
# /3iBeuhLYxM3M/PkcUoebF+Nednm8OkdSPoDu8imViHPQq/8CQUu0WRR4rE+dMRf
# rpVqfmNi2qWCX94T4MsepijGVkwE//tJg0ryAiYdHT34LSnlG/RSBZmQRGWZ5g8j
# qnKjRParSqMft1gvjuUTVgtWNZfgcLFSK5Wa0myrq8OPcgTGGsRgun+tnSS+IxDT
# xVsAPH1OzvPjwomguByhUe/OcvUN0D5Wmp7xAgMBAAGjggGqMIIBpjAOBgNVHQ8B
# Af8EBAMCB4AwHwYDVR0lBBgwFgYKKwYBBAGCN0wIAQYIKwYBBQUHAwMwHQYDVR0O
# BBYEFNoH7a2YDjOSwpkp6DHcmUS7J+0yMFQGA1UdEQRNMEukSTBHMS0wKwYDVQQL
# EyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxFjAUBgNVBAUT
# DTIzMDAxMis1MDc1NjkwHwYDVR0jBBgwFoAUf1k/VCHarU/vBeXmo9ctBpQSCDEw
# YAYDVR0fBFkwVzBVoFOgUYZPaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jcmwvTWljcm9zb2Z0JTIwQ29kZSUyMFNpZ25pbmclMjBQQ0ElMjAyMDI0LmNy
# bDBtBggrBgEFBQcBAQRhMF8wXQYIKwYBBQUHMAKGUWh0dHA6Ly93d3cubWljcm9z
# b2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwQ29kZSUyMFNpZ25pbmcl
# MjBQQ0ElMjAyMDI0LmNydDAMBgNVHRMBAf8EAjAAMA0GCSqGSIb3DQEBCwUAA4IC
# AQAUnEqhaRXe0T3hIJjvdQErEkrA/7bByjn6t5IArODkkRjzkYwtKMc2yYj2quaN
# rLutWw2YZcngKPy1b71YyDJQTy4NDRwaSh9Tw5thrk3NmcPrAHia5vtcBJ1CgtKK
# 7mQbIcQ22d/N3813ayCDDFewu1+jsZmX+r/aTEqaOM4TVxVtRSkuCy8nAXKuChOK
# Li/zA4XuH8iEYqIsj2YoNaeSxVmeGiERXpKdo3dDmYi0kO5w2D8VS4c3+9h6gElY
# BaAAg/dYErBg27qT3vv0zRDJhJufvCNylA8S7/+8H5E/PV5cng6na9VV/w9OV3qu
# uND6zdGa2EX38Glp50F9AIQk3p2xXmcvorDeM4XJ7UlWYBi6g80J1SSOQnInCYFE
# msfUNn3+1AaTJKSJL83quKArTac2pKhu0Yzzzrzo6HrsRiQKzpnRBb1/dMa6P3hz
# 75XbMRBctNsFhZC07WCmjExdLg2eHW5uV0TY8D5+6wozJf7vF3+WHkYPO85Z+BC6
# U4FkNbYNycZ9cE4j1tXRdyDCfml6c0HWPHjNVDObrv9lKt3qUqFpX38VCqVCyNOO
# 1UcXfQiVjJw32U2WUKZjt/neJKHEBsm9kFsLuWzkQ53+qcaSaytmsCnk2gOglrlD
# 5d3kKyvvAw+rzm0lT8K38P6PLxfZQHhu4W8dV7Av8N2ZmDCCBr0wggSloAMCAQIC
# EzMAAAA5O7Y3Gb8GHWcAAAAAADkwDQYJKoZIhvcNAQEMBQAwgYgxCzAJBgNVBAYT
# AlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBS
# b290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDExMB4XDTI0MDgwODIwNTQxOFoX
# DTM2MDMyMjIyMTMwNFowVzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9zb2Z0IENvZGUgU2lnbmluZyBQ
# Q0EgMjAyNDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBANgBnB7jOMeq
# lRYHNa265v4IY9fH8TKhemHfPINe1gpLaV3dhg324WwH06LcHbpnsBukCDNitryo
# 0dtS/EW6I/yEL/bLSY8hKpbfQuWusBPr9qazYcDxCW/qnjb5JsI1s8bNOg3bVATv
# QVL4tcf03aTycsz8QeCdM0l/yHRObJ9QqazM1r6VPEOJ7LL+uEEb73w6QCuhs89a
# 1uv1zerOYMnsneRRwCbpyW11IcggU0cRKDDq1pjVJzIbIF6+oiXXbReOsgeI8zu1
# FyQfK0fVkaya8SmVHQ/tOf23mZ4W9k0Ri22QW9p3UgSC5OUDktKxxcCmGL6tXLfO
# GSWHIIV4YrTJTT6PNty5REojHJuZHArkF9VnHTERWoTjAzfI3kP+5b4alUdhgAZ7
# ttOu1bVnXfHaqPYl2rPs20ji03LOVWsh/radgE17es5hL+t6lV0eVHrVhsssROWJ
# uz2MXMCt7iw7lFPG9LXKGjsmonn2gotGdHIuEg5JnJMJVmixd5LRlkmgYRZKzhxS
# CwyoGIq0PhaA7Y+VPct5pCHkijcIIDm0nlkK+0KyepolcqGm0T/GYQRMhHJlGOOm
# VQop36wUVUYklUy++vDWeEgEo4s7hxN6mIbf2MSIQ/iIfMZgJxC69oukMUXCrOC3
# SkE/xIkgpfl22MM1itkZ35nNXkMolU1lAgMBAAGjggFOMIIBSjAOBgNVHQ8BAf8E
# BAMCAYYwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFH9ZP1Qh2q1P7wXl5qPX
# LQaUEggxMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMA8GA1UdEwEB/wQFMAMB
# Af8wHwYDVR0jBBgwFoAUci06AjGQQ7kUBU7h6qfHMdEjiTQwWgYDVR0fBFMwUTBP
# oE2gS4ZJaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMv
# TWljUm9vQ2VyQXV0MjAxMV8yMDExXzAzXzIyLmNybDBeBggrBgEFBQcBAQRSMFAw
# TgYIKwYBBQUHMAKGQmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMv
# TWljUm9vQ2VyQXV0MjAxMV8yMDExXzAzXzIyLmNydDANBgkqhkiG9w0BAQwFAAOC
# AgEAFJQfOChP7onn6fLIMKrSlN1WYKwDFgAddymOUO3FrM8d7B/W/iQ6DxXsDn7D
# 5W4wMwYeLystcEqfkjz4NURRgazyMu5yRzQh4LqjA4tStTcJh1opExo7nn5PuPBY
# nbu0+THSuVHTe0VTTPVhily/piFrDo3axQ9P4C+Ol5yet+2gTfekICS5xS+cYfSI
# vgn0JksVBVMYVI5QFu/qhnLhsEFEUzG8fvv0hjgkO+lkpV9ty6GkN4vdnd7ya6Q6
# aR9y34aiM1qmxaxBi6OUnyNl6fkuun/diTFnYDLTppOkr/mg5WSfCiDVMNCxtj4w
# PKC5OmHm1DQIt/MNokbbH3UGsFP1QbzsLocuSqLCvH09Io3fDPTmscR9Y75G4qX7
# RTX8AdBPo0I6OEojf39zuFZt0qOHm65YWQE69cZM2ueE1MB05dNNgHK9gTE7zKvK
# /fg8B2qjW88MT/WF5V5uvZGtqa9FSL2RazArA+rDPuf6JGYz4HpgMZHB4S6szWSK
# YBv0VisCzfxgeU+dquXW9bd0auYlOB58DPcOYKdc3Se94g+xL4pcEhbB54JOgAkw
# YTu/9dLeH2pDqeJZAABVDWRQCaXfO5LgyKwKCLYXpigrZYCjUSBcr+Ve8PFWMhVT
# Ql0v4q8J/AUmQN5W4n101cY2L4A7GTQG1h32HHAvfQESWP0xghn7MIIZ9wIBATBu
# MFcxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# KDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMjQCEzMAAAIc
# +s3Fm+gvfsQAAAAAAhwwDQYJYIZIAWUDBAIBBQCgga4wGQYJKoZIhvcNAQkDMQwG
# CisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZI
# hvcNAQkEMSIEIM34xkFm1fD1pKv4+nrAj2xvHhFVBQvPagnKrJ6UmKIaMEIGCisG
# AQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAEggEAZbJ7XEsil/xakwU6eTvY
# WMQBKnd/0YtWFdAZTEAYwlSsTbX+Dg/6UQKEJ8bsQVeZiG53Kup1gbXlHnbroD7/
# WXvymwTzATBWch/u8dpx8m3vbanmLe1nLXTHj9yyM7m7SplhfxFHqXQ6LSEXf6Y5
# vJ9aThHARPLmbwHXeMb5WkWC0RyoG8NG3imVPDmgKMV7ulPSTGyy5IEEqXBwI0Ae
# 6KkNNpHOk8q8wTSfgGvEGRwiMM1l4kl6Ifu2roiMlCcMJCiAWuAnaZu1ZjYbkETc
# iVDxnf3Kf6zeF5/LDie+zH870bq8GGTRSiVPJkbMX0fVhCepX65LVPbhODOZyDJ+
# S6GCF60wghepBgorBgEEAYI3AwMBMYIXmTCCF5UGCSqGSIb3DQEHAqCCF4YwgheC
# AgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFaBgsqhkiG9w0BCRABBKCCAUkEggFFMIIB
# QQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQCAQUABCDR0coDZP22nL3y3dri
# u8oZX0bKIAtPNHtmgZLv9QZPQQIGamOFTqAfGBMyMDI2MDczMTAzMjIxMy43NDZa
# MASAAgH0oIHZpIHWMIHTMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExpbWl0
# ZWQxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo0QzFBLTA1RTAtRDk0NzElMCMG
# A1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaCCEfswggcoMIIFEKAD
# AgECAhMzAAACGCXZkgXi5+XkAAEAAAIYMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNV
# BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29m
# dCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4XDTI1MDgxNDE4NDgyNVoXDTI2MTExMzE4
# NDgyNVowgdMxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTAr
# BgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEnMCUG
# A1UECxMeblNoaWVsZCBUU1MgRVNOOjRDMUEtMDVFMC1EOTQ3MSUwIwYDVQQDExxN
# aWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNlMIICIjANBgkqhkiG9w0BAQEFAAOC
# Ag8AMIICCgKCAgEAsdzo6uuQJqAfxLnvEBfIvj6knK+p6bnMXEFZ/QjPOFywlcjD
# fzI8Dg1nzDlxm7/pqbvjWhyvazKmFyO6qbPwClfRnI57h5OCixgpOOCGJJQIZSTi
# Mgui3B8DPiFtJPcfzRt3FsnxjLXwBIjGgnjGfmQl7zejA1WoYL/qBmQhw/FDFTWe
# bxfo4m0RCCOxf2qwj31aOjc2aYUePtLMXHsXKPFH0tp5SKIF/9tJxRSg0NYEvQqV
# ilje8aQkPd3qzAux2Mc5HMSK4NMTtVVCYAWDUZ4p+6iDI9t5BNCBIsf5ooFNUWtx
# CqnpFYiLYkHfFfxhVUBZ8LGGxYsA36snD65s2Hf4t86k0e8WelH/usfhYqOM3z2y
# aI8rg08631IkwqUzyQoEPqMsHgBem1xpmOGSIUnVvTsAv+lmECL2RqrcOZlZax8K
# 0aiij8h6UkWBN2IA/ikackTSGVRBQmWWZuLFWV/T4xuNzscC0X7xo4fetgpsqaEA
# 0jY/QevkTvLv4OlNN9eOL8LNh7Vm0R65P7oabOQDqtUFAwCgjgPJ0iV/jQCaMAcO
# 3SYpG5wSAYiJkk4XLjNSlNxU2Idjs1sORhl7s7LC6hOb7bVAHVwON74GxfFNiEIA
# 6BfudANjpQJ0nUc/ppEXpT4pgDBHsYtV8OyKSjKsIxOdFR7fIJIjDc8DvUkCAwEA
# AaOCAUkwggFFMB0GA1UdDgQWBBQkLqHEXDobY7dHuoQCBa4sX7aL0TAfBgNVHSME
# GDAWgBSfpxVdAF5iXYP05dJlpxtTNRnpcjBfBgNVHR8EWDBWMFSgUqBQhk5odHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBUaW1l
# LVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcmwwbAYIKwYBBQUHAQEEYDBeMFwGCCsG
# AQUFBzAChlBodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01p
# Y3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNydDAMBgNVHRMB
# Af8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIHgDAN
# BgkqhkiG9w0BAQsFAAOCAgEAnkjRhjwPgdoIpvt4YioT/j0LWuBxF3ARBKXDENgg
# raKvC0oRPwbjAmsXnPEmtuo5MD8uJ9Xw9eYrxqqkK4DF9snZMrHMfooxCa++1irL
# z8YoozC4tci+a4N37Sbke1pt1xs9qZtvkPgZGWn5BcwVfmAwSZLHi2CuZ06Y0/X+
# t6fNBnrbMVovNaDX4WPdyI9GEzxfIggDsck2Ipo4VXL/Arcz7p2F7bEZGRuyxjgM
# C+woCkDJaH/yk/wcZpAsixe4POdN0DW6Zb35O3Dg3+a6prANMc3WIdvfKDl75P0a
# qcQbQAR7b0f4gH4NMkUct0Wm4GN5KhsE1YK7V/wAqDKmK4jx3zLz3a8Hsxa9HB3G
# yitlmC5sDhOl4QTGN5kRi6oCoV4hK+kIFgnkWjHhSRNomz36QnbCSG/BHLEm2GRU
# 9u3/I4zUd9E1AC97IJEGfwb+0NWb3QEcrkypdGdWwl0LEObhrQR9B1V7+edcyNms
# X0p2BX0rFpd1PkXJSbxf8IcEiw/bkNgagZE+VlDtxXeruLdo5k3lGOv7rPYuOEao
# ZYxDvZtpHP9P36wmW4INjR6NInn2UM+krP/xeLnRbDBkm9RslnoDhVraliKDH62B
# xhcgL9tiRgOHlcI0wqvVWLdv8yW8rxkawOlhCRqT3EKECW8ktUAPwNbBULkT+oWc
# vBcwggdxMIIFWaADAgECAhMzAAAAFcXna54Cm0mZAAAAAAAVMA0GCSqGSIb3DQEB
# CwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYD
# VQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAxMDAe
# Fw0yMTA5MzAxODIyMjVaFw0zMDA5MzAxODMyMjVaMHwxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFBDQSAyMDEwMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA5OGm
# TOe0ciELeaLL1yR5vQ7VgtP97pwHB9KpbE51yMo1V/YBf2xK4OK9uT4XYDP/XE/H
# ZveVU3Fa4n5KWv64NmeFRiMMtY0Tz3cywBAY6GB9alKDRLemjkZrBxTzxXb1hlDc
# wUTIcVxRMTegCjhuje3XD9gmU3w5YQJ6xKr9cmmvHaus9ja+NSZk2pg7uhp7M62A
# W36MEBydUv626GIl3GoPz130/o5Tz9bshVZN7928jaTjkY+yOSxRnOlwaQ3KNi1w
# jjHINSi947SHJMPgyY9+tVSP3PoFVZhtaDuaRr3tpK56KTesy+uDRedGbsoy1cCG
# MFxPLOJiss254o2I5JasAUq7vnGpF1tnYN74kpEeHT39IM9zfUGaRnXNxF803RKJ
# 1v2lIH1+/NmeRd+2ci/bfV+AutuqfjbsNkz2K26oElHovwUDo9Fzpk03dJQcNIIP
# 8BDyt0cY7afomXw/TNuvXsLz1dhzPUNOwTM5TI4CvEJoLhDqhFFG4tG9ahhaYQFz
# ymeiXtcodgLiMxhy16cg8ML6EgrXY28MyTZki1ugpoMhXV8wdJGUlNi5UPkLiWHz
# NgY1GIRH29wb0f2y1BzFa/ZcUlFdEtsluq9QBXpsxREdcu+N+VLEhReTwDwV2xo3
# xwgVGD94q0W29R6HXtqPnhZyacaue7e3PmriLq0CAwEAAaOCAd0wggHZMBIGCSsG
# AQQBgjcVAQQFAgMBAAEwIwYJKwYBBAGCNxUCBBYEFCqnUv5kxJq+gpE8RjUpzxD/
# LwTuMB0GA1UdDgQWBBSfpxVdAF5iXYP05dJlpxtTNRnpcjBcBgNVHSAEVTBTMFEG
# DCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNodHRwOi8vd3d3Lm1pY3Jvc29m
# dC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0wEwYDVR0lBAwwCgYIKwYB
# BQUHAwgwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8G
# A1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAU1fZWy4/oolxiaNE9lJBb186aGMQw
# VgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9j
# cmwvcHJvZHVjdHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3JsMFoGCCsGAQUF
# BwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3Br
# aS9jZXJ0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcnQwDQYJKoZIhvcNAQEL
# BQADggIBAJ1VffwqreEsH2cBMSRb4Z5yS/ypb+pcFLY+TkdkeLEGk5c9MTO1OdfC
# cTY/2mRsfNB1OW27DzHkwo/7bNGhlBgi7ulmZzpTTd2YurYeeNg2LpypglYAA7AF
# vonoaeC6Ce5732pvvinLbtg/SHUB2RjebYIM9W0jVOR4U3UkV7ndn/OOPcbzaN9l
# 9qRWqveVtihVJ9AkvUCgvxm2EhIRXT0n4ECWOKz3+SmJw7wXsFSFQrP8DJ6LGYnn
# 8AtqgcKBGUIZUnWKNsIdw2FzLixre24/LAl4FOmRsqlb30mjdAy87JGA0j3mSj5m
# O0+7hvoyGtmW9I/2kQH2zsZ0/fZMcm8Qq3UwxTSwethQ/gpY3UA8x1RtnWN0SCyx
# TkctwRQEcb9k+SS+c23Kjgm9swFXSVRk2XPXfx5bRAGOWhmRaw2fpCjcZxkoJLo4
# S5pu+yFUa2pFEUep8beuyOiJXk+d0tBMdrVXVAmxaQFEfnyhYWxz/gq77EFmPWn9
# y8FBSX5+k77L+DvktxW/tM4+pTFRhLy/AsGConsXHRWJjXD+57XQKBqJC4822rpM
# +Zv/Cuk0+CQ1ZyvgDbjmjJnW4SLq8CdCPSWU5nR0W2rRnj7tfqAxM328y+l7vzhw
# RNGQ8cirOoo6CGJ/2XBjU02N7oJtpQUQwXEGahC0HVUzWLOhcGbyoYIDVjCCAj4C
# AQEwggEBoYHZpIHWMIHTMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExpbWl0
# ZWQxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo0QzFBLTA1RTAtRDk0NzElMCMG
# A1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcGBSsOAwIa
# AxUAnWtGrXWiuNE8QrKfm4CtGr57z+mggYMwgYCkfjB8MQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1T
# dGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQsFAAIFAO4V7D0wIhgPMjAyNjA3MzAx
# NTI5MDFaGA8yMDI2MDczMTE1MjkwMVowdDA6BgorBgEEAYRZCgQBMSwwKjAKAgUA
# 7hXsPQIBADAHAgEAAgIRLTAHAgEAAgIUrjAKAgUA7hc9vQIBADA2BgorBgEEAYRZ
# CgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIBAAIDB6EgoQowCAIBAAIDAYagMA0G
# CSqGSIb3DQEBCwUAA4IBAQC5AAFVXKYYotbXYVoFwzqtIjp3EN9V2SY+Cdehpbm0
# TZT59te3ubnqrEOSfrOv36wVGYDP7U4+4z0O24m/dYuHeNfiw8aYsSKYnF0qmNdt
# UBkpnmZHNdcP3fYSVbCyoxxDqPaU7q7SrQKSsGVLD7Acz7N7wQCpmgFo5btcrOel
# 8PtGvsurIU9U7sX1Uaruk+qdaGyWDO4cUrYIk56W9a8GfnSpnFlc/KZiN0wNqfPv
# oGwz1Zwo/ADY6ggqLZdhxRZ4vkZwwx49tKUdeGG620B1GtijOe6omsuSp55+g5kf
# zofUKfPmPeHN++6a+SToiu7anhyJXMPltfcntFO/8qiQMYIEDTCCBAkCAQEwgZMw
# fDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1Jl
# ZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMd
# TWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAIYJdmSBeLn5eQAAQAA
# AhgwDQYJYIZIAWUDBAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRAB
# BDAvBgkqhkiG9w0BCQQxIgQg/5wbI22kEOAKOzBV5Hzsxy7Robrx++DrsWrxdEAP
# n0QwgfoGCyqGSIb3DQEJEAIvMYHqMIHnMIHkMIG9BCCZE9yJuOTItIwWaES6lzGK
# K1XcSoz1ynRzaOVzx9eFajCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBD
# QSAyMDEwAhMzAAACGCXZkgXi5+XkAAEAAAIYMCIEIBKgGL6QzjT7qVpTOTSAN9IU
# xdd2mr/bH7d7XhDqaJzhMA0GCSqGSIb3DQEBCwUABIICAA5BXajwDSJa+YMRHiFe
# CfDlhlMIVUYEG2Vlye9b6Bt6pvMygOc3FiyllRYjs2Ry2tsGzChbf8B3rJ13o0qh
# +fqXR2zGQCxDRL2TDwmes9HicEdrGa7trp9HGJvSnlo6GOTQJ4hp0tAMLvSIFyEb
# VWN5LjLnmlL+AivAZt+4pd2dAbKYRvVMI/aeXt0RKFj5DwcQtFRmyETt9GjqWsXS
# nc3+5vDMZPzmvG17QaSpq5YmhP9kTCTakdJAiJVm+7EOmIdkyjQG/Cgz1TQ7UpwW
# t6KRAv9k2j9ivkoTdlMRj6JD2BptwFvuw7+upIC7rqnrCDydrRovc8gceddK36bb
# 7YX5XC9nbQ4sECouDvRWYKvulRZotpAOaxnzxB7z2Oq2JZxYKDZz+qwJw4+95vpi
# RyNEB7GiLkk35kmeZ5tmPX8ZzXO79QfWdg0OdgXFKKJnrsqtJBNQ+BAraL5TGghA
# cfeJ+u7SkG27xA938gq16fupbrhz+V9zJ9bUPvY3j3niLHdFSafDOr6SxHT4gdOh
# lqK3gtroH1rUCt9tGnMVBypHzFSQjcNhD14lCprQ8eDxXkXpD63tbXE9Qcy5bjeJ
# 6PXDROogpu6N559hMIsj+kiqmTrexvbZtdK/y/EfLZ/H1JJGOh8ewWvaHl6Aoqx/
# 1PaDca/qLXaELNuY0CECcHse
# SIG # End signature block
