﻿#region localizeddata
if (Test-Path "${PSScriptRoot}\${PSUICulture}")
{
    Import-LocalizedData `
        -BindingVariable LocalizedData `
        -Filename MSFT_xCertificateCommon.strings.psd1 `
        -BaseDirectory "${PSScriptRoot}\${PSUICulture}"
}
else
{
    #fallback to en-US
    Import-LocalizedData `
        -BindingVariable LocalizedData `
        -Filename MSFT_xCertificateCommon.strings.psd1 `
        -BaseDirectory "${PSScriptRoot}\en-US"
}
#endregion

<#
.SYNOPSIS
 Validates the existence of a file at a specific path.

.PARAMETER Path
 The location of the file. Supports any path that Test-Path supports.

.PARAMETER Quiet
 Returns $false if the file does not exist. By default this function throws an exception if the
 file is missing.

.EXAMPLE
 Test-CertificatePath -Path '\\server\share\Certificates\mycert.cer'

.EXAMPLE
 Test-CertificatePath -Path 'C:\certs\my_missing.cer' -Quiet

.EXAMPLE
 'D:\CertRepo\a_cert.cer' | Test-CertificatePath

.EXAMPLE
 Get-ChildItem -Path D:\CertRepo\*.cer |
    Test-CertificatePath
#>
function Test-CertificatePath
{
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline
        )]
        [String[]]
        $Path,

        [Parameter()]
        [Switch]
        $Quiet
    )

    Process
    {
        foreach ($p in $Path)
        {
            if ($p | Test-Path -PathType Leaf)
            {
                $true
            }
            elseif ($Quiet)
            {
                $false
            }
            else
            {
                ThrowInvalidArgumentError `
                    -ErrorId 'CannotFindRootedPath' `
                    -ErrorMessage ($LocalizedData.FileNotFoundError -f $p)
            }
        }
    }
} # end function Test-CertificatePath

<#
.SYNOPSIS
  Validates whether a given certificate is valid based on the hash algoritms available on the
  system.

.PARAMETER Thumbprint
 One or more thumbprints to Test.

.PARAMETER Quiet
 Returns $false if the thumbprint is not valid. By default this function throws an exception if
 validation fails.

.EXAMPLE
 Test-Thumbprint fd94e3a5a7991cb6ed3cd5dd01045edf7e2284de

.EXAMPLE
 Test-Thumbprint `
    -Thumbprint fd94e3a5a7991cb6ed3cd5dd01045edf7e2284de,0000e3a5a7991cb6ed3cd5dd01045edf7e220000 `
    -Quiet

.EXAMPLE
 Get-ChildItem -Path Cert:\LocalMachine -Recurse |
    Where-Object -FilterScript { $_.Thumbprint } |
    Select-Object -Expression Thumbprint |
    Test-Thumbprint -Verbose
#>
function Test-Thumbprint
{
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline
        )]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $Thumbprint,

        [Parameter()]
        [Switch]
        $Quiet
    )

    Begin
    {
        # Get a list of all Valid Hash types and lengths into an array
        $validHashes = [System.AppDomain]::CurrentDomain.GetAssemblies().GetTypes() |
            Where-Object -FilterScript {
                $_.BaseType.BaseType -eq [System.Security.Cryptography.HashAlgorithm] -and
                ($_.Name -cmatch 'Managed$' -or $_.Name -cmatch 'Provider$')
            } |
            ForEach-Object -Process {
                New-Object -TypeName PSObject -Property @{
                    Hash    = $_.BaseType.Name
                    BitSize = ( New-Object -TypeName $_).HashSize
                } |
                    Add-Member -MemberType ScriptProperty -Name HexLength -Value {
                        $this.BitSize / 4
                    } -PassThru
            }
    }

    Process
    {
        foreach ($hash in $Thumbprint)
        {
            $isValid = $false

            foreach ($algorithm in $validHashes)
            {
                if ($hash -cmatch "^[a-fA-F0-9]{$($algorithm.HexLength)}$")
                {
                    Write-Verbose -Message ($LocalizedData.InvalidHashError `
                        -f $hash,$algorithm.Hash)
                    $isValid = $true
                }
            }

            if ($Quiet -or $isValid)
            {
                $isValid
            }
            else
            {
                ThrowInvalidArgumentError `
                    -ErrorId 'CannotFindRootedPath' `
                    -ErrorMessage ($LocalizedData.InvalidHashError -f $hash)
            }
        }
    }
} # end function Test-Thumbprint

function ThrowInvalidOperationError
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ErrorId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ErrorMessage
    )

    $exception = New-Object -TypeName System.InvalidOperationException `
        -ArgumentList $ErrorMessage;
    $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation;
    $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
        -ArgumentList $exception, $ErrorId, $errorCategory, $null;
    throw $errorRecord;
} # end function ThrowInvalidOperationError

function ThrowInvalidArgumentError
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ErrorId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ErrorMessage
    )

    $exception = New-Object -TypeName System.ArgumentException `
        -ArgumentList $ErrorMessage;
    $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument;
    $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
        -ArgumentList $exception, $ErrorId, $errorCategory, $null;
    throw $errorRecord;
} # end function ThrowInvalidArgumentError
