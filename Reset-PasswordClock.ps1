<#
.Synopsis
Script to reset an Active Directory account's password timer to the current date and time.  
.Description
This script will reset the 'pwdLastSet' attribute in Active Directory to the current date and time.  Useful for when an account has an expired password, but the user is remote and has no way to sign in to change their password.
.Parameter Username
The Identity of the user you wish to reset in Active Directory. This should be their SamAccountName. 
If provided with a domain prepended the 'Server' variable will be set to that domain, e.g. 'contoso\jsmith'
.Parameter Credential
A PSCredential object you would like to use instead of the current running user to authenticate the change
.Parameter Server
The domain name you wish to perform the action against if different than the domain you're currently on. 
.Parameter Shortcut
A switch parameter to be used in conjunction with a Windows shortcut. When used it keeps the Powershell window open after script execution until the user hits 'enter'
.EXAMPLE
PS> .\Reset-PasswordClock.ps1
Please provide a username: jsmith
User's current info:

User            : jsmith
DisplayName     : Smith, John
PasswordLastSet : 12/12/2022 7:42:01 AM
ExpiryDate      : 3/12/2023 8:42:01 AM
Lockedout       : False

------------------------------------------------
Would you like to reset the 'PasswordLastSet' to the current time? (y/n):y
Resetting password clock.
User's current info:

User            : jsmith
DisplayName     : Smith, John
PasswordLastSet : 3/15/2023 9:32:01 AM
ExpiryDate      : 6/15/2023 10:32:01 AM
Lockedout       : False

------------------------------------------------

.NOTES
Version:        1.1
Author:         C. Bodett
Creation Date:  1/09/2023
Purpose/Change: Added in a do-loop for repeated use
#>
#Requires -Modules 'ActiveDirectory'

Param (
    [CmdletBinding()]
    [Parameter(Position = 0)]
    [String]$Username,
    [Parameter(Position = 2)]
    [PSCredential]$Credential,
    [Parameter(Position = 1)]
    [String]$Server,
    [Switch]$Shortcut
)

If ($Shortcut) {
    $CurrentUser = $ENV:USERNAME
    Write-Host "Script running  as $CurrentUser"
    Do {
        Try {
        [ValidateSet('y','n')]$Answer = Read-Host -Prompt "Would you like to continue? Say 'n' to be prompted for different credentials (y/n)"
        $Continue = $true
        } Catch {
            Write-Host "Please answer with 'y' or 'n'" -ForegroundColor Red
            $Continue = $false
        }
    } Until ($Continue)
    If ($Answer -eq 'n') {
        $Credential = Get-Credential -Message "Provide credentials for executing Reset-PasswordClock"
        Write-Host "Continuing execution as $($Credential.Username)"
    }
}

$Loop = "y"
Do {
    # prompt for a userid to query if not provided at the command line
    If (-not $Username) {
        $Username = Read-Host -Prompt "Please provide a username"
    }

    # get our current domain if not provided by the -Server parameter
    If (-not $Server -and $Username -notmatch '\\') {
        $Server = Get-CimInstance -ClassName win32_computersystem | Select-Object -ExpandProperty Domain
    } ElseIf (-not $Server -and $Username -match '\\') {
        $Server = $Username.Split('\')[0]
    }

    # if username was provided with domain prepended, remove it at this point
    If ($Username -match '\\') {
        $Username = $Username.Split('\')[1]
    }

    # define our 'Select-Object' properties to make the command easier to read down below
    $SelObjArgs = [Ordered]@{
        Property = @(@{Name="User";Expression={$_.SamAccountName}},
                    "DisplayName",
                    "PasswordLastSet",
                    @{Name="ExpiryDate";Expression={[datetime]::fromfiletime($_."msds-userpasswordexpirytimecomputed")}},
                    "Lockedout"
        )
    }

    # our command parameters, defined ahead of time for easier reading down below
    $GetADUserArgs = [Ordered]@{
        Identity = $Username
        Server = $Server
        Properties = @('Displayname','Passwordlastset','msDS-userpasswordexpirytimecomputed','lockedout')
    }
    If ($Credential) {
        $GetADUserArgs.Add('Credential',$Credential)
    }

    # Check AD to see if the supplied username exists and then provide the current state of the account.
    Try {
        $ADInfo = Get-ADUser @GetADUserArgs -ErrorAction Stop | Select-Object  @SelObjArgs
    } Catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]{
        Write-Warning "$Username not found in domain: $Server"
        Exit
    } Catch{
        $Error[0].Exception
        Exit
    }

    Write-Host "User's current info:"
    $ADInfo
    Write-Host ('-'*48)

    Do {
        Try {
        [ValidateSet('y','n')]$Answer = Read-Host -Prompt "Would you like to reset the 'PasswordLastSet' to the current time? (y/n)"
        $Continue = $true
        } Catch {
            Write-Host "Please answer with 'y' or 'n'" -ForegroundColor Red
            $Continue = $false
        }
    } Until ($Continue)
    Remove-Variable Continue

    If ($Answer -eq "n") {
        Write-Host "Exiting..." -ForegroundColor Yellow
        Exit
    }

    <# Assigning a 0 to the 'pwdLastSet' attribute immediately expires the password, and is a prerequisite to the next step.
    Followed by assigning a -1. Because of the way 64-bit integers are saved, this is the largest possible value that
    can be saved in a LargeInteger attribute. It corresponds to a date far in the future. But the system will assign a 
    value corresponding to the current datetime the next time the user logs on. The password will then expire according 
    to the maximum password age policy that applies to the user.
    #>
    Write-Host "Resetting password clock."
    $SetADUserArgs = [Ordered]@{
        Identity = $Username
        Server = $Server
        ErrorAction = 'Stop'
    }
    If ($Credential) {
        $SetADUserArgs.Add('Credential',$Credential)
    }

    Try {
        Set-ADUser @SetADUserArgs -Replace @{pwdLastSet = 0} 
        Set-ADUser @SetADUserArgs -Replace @{pwdLastSet = -1} 
    } Catch {
        Write-Warning "Encountered an error. Unable to reset password expiration."
        $Error[0].Exception
    }

    # Re-Check AD
    Try {
        $ADInfo = Get-ADUser @GetADUserArgs -ErrorAction Stop | Select-Object  @SelObjArgs
    } Catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]{
        Write-Warning "$Username not found in domain: $Server"
        Exit
    } Catch{
        $Error[0].Exception
        Exit
    }

    Write-Host "User's current info:"
    $ADInfo
    Write-Host ('-'*48)

    # clear variables in case of loop
    Remove-Variable ADInfo,Username,Server
    # ask if the user would like to run the action again against a different user.
    Do {
        Try {
        [ValidateSet('y','n')]$Loop = Read-Host -Prompt "Would you like to work on another user (y/n)?"
        $Continue = $true
        } Catch {
            Write-Host "Please answer with 'y' or 'n'" -ForegroundColor Red
            $Continue = $false
        }
    } Until ($Continue)

} While ($Loop -eq "y")

If ($Shortcut){
    Write-Host "Press enter to close this window..." -ForegroundColor Yellow
    Read-Host
    Exit
}