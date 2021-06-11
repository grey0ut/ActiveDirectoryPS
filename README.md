# ActiveDirectoryPS
A collection of Powershell functions and scripts that I find useful with Active Directory.

# Get-ADPasswordInfo
A quick function that saved me some time while investigating why a user account lockout occurred. This will quickly show you if they changed their password recently which was mostly what I wanted out of it. 
```Powershell
    PS$> Get-ADPasswordInfo -User JohnS 

    Displayname            Passwordlastset      ExpiryDate           Lockedout LockoutTime LastFailedAuth
    -----------            ---------------      ----------           --------- ----------- --------------
    Smith, John            2/13/2020 3:44:03 PM 4/13/2020 4:44:03 PM     False             3/16/2020 7:16:02 AM
```
It accepts pipeline input so if you have an array of usernames you want to check it will produce a nice little table with all their info. Which means you can also actively search for locked out accounts and get more info about them.
```Powershell
    PS$> Search-ADaccount -LockedOut | Get-ADPasswordInfo
    Displayname            Passwordlastset      ExpiryDate           Lockedout LockoutTime            LastFailedAuth
    -----------            ---------------      ----------           --------- -----------            --------------
    Smith, John            2/13/2020 3:44:03 PM 4/13/2020 4:44:03 PM     True  3/16/2020 7:16:02 AM   3/16/2020 7:16:02 AM
    Smith, Jane            1/23/2020 4:54:37 PM 3/23/2020 4:54:34 PM     True  3/16/2020 7:16:02 AM
```
The "LastFailedAuth" property is actually the "LastBadPasswordAttempt" property from AD. It's not super important, but I thought I would include it for fun.