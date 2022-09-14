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
    User    Displayname            Passwordlastset      ExpiryDate           Lockedout LockoutTime LastFailedAuth       Server
    ----    -----------            ---------------      ----------           --------- ----------- --------------       ------
    JohnS   Smith, John            2/13/2020 3:44:03 PM 4/13/2020 4:44:03 PM     False             3/16/2020 7:16:02 AM contoso.local
    .Example
    Get-ADPasswordInfo -User JohnS,JohnD,JaneM -Server contoso2.local
    .Example
    Get-ADPasswordIfno -User JohnS,JohnD -Server Contoso.local,Osotnoc.Local
    .Example
    $people | Get-ADPasswordInfo   # where $people is an array of usernames. Will return a table with all results
    .NOTES
    Version:    2.6
    Author:     C. Bodett
    Creation Date: 9/14/2022
    #>
    [Cmdletbinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $true, Mandatory = $true)]
        [Alias('Username','Identity')]
        [String[]]$User,
        [Parameter(Position = 1)]
        [Alias('Domain')]
        [String[]]$Server
    )
    
    Begin {
        # check to make sure the AD module is loaded
        If (!(Get-module -name ActiveDirectory)){
            Try {
                Import-Module -Name ActiveDirectory -ErrorAction Stop
            } Catch {
                Throw "Could not import the ActiveDirectory module."
            }
        }

        If (-not($Server)){
            $Server = (Get-CimInstance -ClassName CIM_ComputerSystem).Domain
            If ($Server -eq "WORKGROUP"){
                Throw "This computer is not joined to a domain. Please specify a domain, or server manually with -Server"
            }
        }

        # define our 'select-object' properties to make the command easier to read down below
        $SelObjArgs = [ordered]@{
            Property = @("DisplayName",
                        "PasswordLastSet",
                        @{Name="ExpiryDate";Expression={[datetime]::fromfiletime($_."msds-userpasswordexpirytimecomputed")}},
                        "Lockedout",
                        @{Name="LockoutTime";Expression={ $_.accountlockouttime }},
                        @{Name="LastFailedAuth";Expression={ $_.lastbadpasswordattempt}}
                        @{Name="Server";Expression={$ADServer}}
            )
        }
        # an array to store our results in
        $Results = [System.Collections.Generic.List[Object]]::New()
    }
    
    Process {
        Foreach ($ADUser in $User) {
            Foreach ($ADServer in $Server) {
                # our command parameters, defined ahead of time for easier reading down below. This needs to be in the 'process' block so that the $user variable can be defined/updated from pipelineinput
                $GetADUserArgs = [ordered]@{
                    Identity = $ADUser
                    Server = $ADServer
                    Properties = @('Displayname','PasswordLastSet','Badpasswordtime','msDS-userpasswordexpirytimecomputed','lockedout','accountlockouttime','LastBadPasswordAttempt')
                }
                # do the query and then append the info to the results array
                Try {
                    $ADInfo = Get-ADUser @GetADUserArgs -ErrorAction Stop | Select-Object  @SelObjArgs
                    $Results.Add($ADInfo)
                } Catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]{
                    Write-Warning "$ADUser not found in domain: $ADServer"
                } Catch{
                    $Error[0].Exception
                }
            }
        }  
    }
    
    End {
        $Results
    }
}