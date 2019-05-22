#############################
## Author: Michaël De Bona
#############################

## This may not be required - see http://ckib.me/C7j2E for usage information.

$LogFile = (Get-ItemProperty -Path "HKLM:\Software\Microsoft\SMS\Client\Configuration\Client Properties" -Name "Local SMS Path").'Local SMS Path' + "Logs\CM_JavaUsageLogging.log"
$LoggingEnable = $True
$UTLogFileName = ".java_usage_cm"
$OverwriteUT = $false

########################################################################################################## 

Function Log-ScriptEvent { 
    #Thank you Ian Farr https://gallery.technet.microsoft.com/scriptcenter/Log-ScriptEvent-Function-ea238b85 
    #Define and validate parameters 
    [CmdletBinding()] 
    Param( 
        #The information to log 
        [parameter(Mandatory=$True)] 
        [String]$Value, 
    
        #The severity (1 - Information, 2- Warning, 3 - Error) 
        [parameter(Mandatory=$True)] 
        [ValidateRange(1,3)] 
        [Single]$Severity 
        ) 
    
    
    #Obtain UTC offset 
    $DateTime = New-Object -ComObject WbemScripting.SWbemDateTime  
    $DateTime.SetVarDate($(Get-Date)) 
    $UtcValue = $DateTime.Value 
    $UtcOffset = $UtcValue.Substring(21, $UtcValue.Length - 21) 
    
    
    #Create the line to be logged 
    $LogLine =  "<![LOG[$Value]LOG]!>" +`
                "<time=`"$(Get-Date -Format HH:mm:ss.fff)$($UtcOffset)`" " +`
                "date=`"$(Get-Date -Format M-d-yyyy)`" " +`
                "component=`"Java Compliance`" " +`
                "context=`"$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)`" " +`
                "type=`"$Severity`" " +`
                "thread=`"$([Threading.Thread]::CurrentThread.ManagedThreadId)`" " +`
                "file=`"`">" 
    
    #Write the line to the passed log file 
    Add-Content -Path $LogFile -Value $LogLine 
 
} 
########################################################################################################## 

#Enumerate user profile folders from WMI
try {
    If ($LoggingEnable -eq $true) {Log-ScriptEvent -Value "Gather user profile paths." -Severity 1}
    $users = Get-WMIObject win32_userprofile | Select-Object LocalPath, SID
} 
Catch {
    If ($LoggingEnable -eq $true) {
        Log-ScriptEvent -Value "Error gather user profile paths." -Severity 3
    }
    Exit 5150
}

#Create temporaty PSDrive to access HKEY_USERS hive
New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS | Out-Null

#Check each returned folder for a java uasge log.
Foreach ($user in $users) {
    Write-Host ($($user.LocalPath) -split '\\')[-1].ToString()
    $path = $null
    #Retrieve network path where UT file is stored
    $NetworkPath = (Get-ItemProperty -Path "HKU:\\$($user.SID)\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders\" -Name 'Desktop' -ErrorAction SilentlyContinue).Desktop -Replace '(.*)(\Desktop$)', {$1}
    If ($NetworkPath) {
        IF ($LoggingEnable -eq $true) {Log-ScriptEvent -Value "Checking for $NetworkPath\$($UTLogFileName)" -Severity 1}
        $path = test-path "$NetworkPath\$($UTLogFileName)"
    }    
    
    if ($path) {
        IF ($LoggingEnable -eq $true) {Log-ScriptEvent -Value "Found $NetworkPath\$($UTLogFileName)" -Severity 1}
        Copy-Item -Path "$NetworkPath$($UTLogFileName)" -Destination "$($env:USERPROFILE)\" -Force
        try {
            Copy-Item -Path "$NetworkPath$($UTLogFileName)" -Destination "$($env:USERPROFILE)\" -Force
        }
        Catch {
            Log-ScriptEvent -Value "$_" -Severity 1
            Get-PsDrive -Name HKU | Remove-PSDrive | Out-Null
        }
    }
}

Get-PsDrive -Name HKU | Remove-PSDrive | Out-Null