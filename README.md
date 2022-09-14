# ActiveDirectoryPS
A collection of Powershell functions and scripts that I find useful with Active Directory.

# Get-ADPasswordInfo
A quick function that saved me some time while investigating why a user account lockout occurred. This will quickly show you if they changed their password recently which was mostly what I wanted out of it. 
```Powershell
    PS$> Get-ADPasswordInfo -User JohnS 

    User    Displayname            Passwordlastset      ExpiryDate           Lockedout LockoutTime LastFailedAuth       Server
    ----    -----------            ---------------      ----------           --------- ----------- --------------       ------
    JohnS   Smith, John            2/13/2020 3:44:03 PM 4/13/2020 4:44:03 PM     False             3/16/2020 7:16:02 AM Contoso.local
```
It accepts pipeline input so if you have an array of usernames you want to check it will produce a nice little table with all their info. Which means you can also actively search for locked out accounts and get more info about them.
```Powershell
    PS$> Search-ADaccount -LockedOut | Get-ADPasswordInfo
    User    Displayname            Passwordlastset      ExpiryDate           Lockedout LockoutTime              LastFailedAuth       Server
    ----    -----------            ---------------      ----------           --------- -----------              --------------       ------
    JohnS   Smith, John            2/13/2020 3:44:03 PM 4/13/2020 4:44:03 PM      True 3/16/2020 7:16:02 AM     3/16/2020 7:16:02 AM Contoso.local        
    JaneS   Smith, Jane            1/23/2020 3:44:03 PM 3/23/2020 4:54:03 PM      True 3/16/2020 7:16:02 AM                          Contoso.local
```  
The "LastFailedAuth" property is actually the "LastBadPasswordAttempt" property from AD. It's not super important, but I thought I would include it for fun.   
Added the ability to pass multiple values to both the "-User" and "-Server" parameter to allow for looking up multiple users across multiple domains in one execution.  
```Powershell
    PS$> Get-ADPasswordInfo JohnS,JaneS Contoso.local,Osotnoc.local
    WARNING: JaneS not found in domain: Osotnoc.local
    User    Displayname            Passwordlastset      ExpiryDate           Lockedout  LockoutTime              LastFailedAuth       Server
    ----    -----------            ---------------      ----------           ---------  -----------              --------------       ------
    JohnS   Smith, John            2/13/2020 3:44:03 PM 4/13/2020 4:44:03 PM      True  3/16/2020 7:16:02 AM     3/16/2020 7:16:02 AM Contoso.local
    JohnS   Smith, John            7/23/2021 3:44:03 PM 12/23/2021 4:44:03 PM     False                                               Osotnoc.local         
    JaneS   Smith, Jane            1/23/2020 3:44:03 PM 3/23/2020 4:54:03 PM      True  3/16/2020 7:16:02 AM                          Contoso.local
```  
In the above example you can also see that you can leverage parameter position to provide values in the order of "User(s)" and then "Server(s)" without having to name the parameters.  