Function Get-ADPasswordInfo {
    <#
    .Synopsis
    Query Active Directory for general info related to a user's password
    .Description
    Checks AD for a provided username and returns the last time they set their password, when it expires/expired, if they're locked out and if so when they locked out
    Supports pipeline input so you can do multiple lookups and return a table
    .Parameter User
    This is how you provide the username to lookup. It's the first parameter so the parameter name can be omitted
    .Parameter Server
    This is the domain/server to perform the AD lookup with. The function will attempt to obtain this on it own, but will throw an error if it fails and may require providing this parameter.
    .Example
    Get-ADPasswordInfo -User JohnS 

    Displayname            Passwordlastset      ExpiryDate           Lockedout LockoutTime LastFailedAuth
    -----------            ---------------      ----------           --------- ----------- --------------
    Smith, John            2/13/2020 3:44:03 PM 4/13/2020 4:44:03 PM     False             3/16/2020 7:16:02 AM
    .Example
    Get-ADPasswordInfo -User JohnS -server contoso.com  
    .Example
    $people | Get-ADPasswordInfo   

    # in the above example $people is an array of usernames. The function will return a table with all results
    .NOTES
        Version:    2.1
        Author:     C. Bodett
        Creation Date: 2/27/2020
    #>
    Param(
        [cmdletbinding()]
        [Parameter(Position = 0, ValueFromPipeline,Mandatory=$true)]
        [Alias('Username')]
        $User,
        [Parameter(Position = 1, Mandatory = $false)]
        [string]$Server
    )

    Begin {
        # check to make sure the AD module is loaded
        If (!(Get-module -name ActiveDirectory)){
            Import-Module -Name ActiveDirectory
        }

        If (-not($Server)){
            $Server = (Get-CimInstance -ClassName CIM_ComputerSystem).Domain
            If ($Server -eq "WORKGROUP"){
                Throw "This computer is not joined to a domain. Please specify a domain, or server manually with -Server"
            }
        }

        # define our 'select-object' properties to make the command easier to read down below
        $SelObjArgs = [ordered]@{
            Property = @("Displayname",
                        "Passwordlastset",
                        @{Name="ExpiryDate";Expression={[datetime]::fromfiletime($_."msds-userpasswordexpirytimecomputed")}},
                        "Lockedout",
                        @{Name="LockoutTime";Expression={ $_.accountlockouttime }},
                        @{Name="LastFailedAuth";Expression={ $_.lastbadpasswordattempt}}
            )
        }
        # an array to store our results in
        $Results = @()
    }

    Process {
        # our command parameters, defined ahead of time for easier reading down below. This needs to be in the 'process' block so that the $user variable can be defined/updated from pipelineinput
        $GetADUserArgs = [ordered]@{
            Identity = $User
            Server = $server
            Properties = @(
                'Displayname',
                'Passwordlastset',
                'Badpasswordtime',
                'msDS-userpasswordexpirytimecomputed',
                'lockedout',
                'accountlockouttime',
                'LastBadPasswordAttempt'
                )
        }
        # do the query and then append the info to the results array
        Try{
            $ADinfo = Get-ADUser @GetADUserArgs -ErrorAction SilentlyContinue | Select-Object  @SelObjArgs
        }Catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]{
            Write-Host "$User not found in domain: $Server" -ForegroundColor Yellow
        }Catch{
            $Error[0].Exception
        }
        $Results+=$ADinfo
    }

    End {
        $Results | Format-Table
    }
}