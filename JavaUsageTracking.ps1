$LogFile = (Get-ItemProperty -Path "HKLM:\Software\Microsoft\SMS\Client\Configuration\Client Properties" -Name "Local SMS Path").'Local SMS Path' + "Logs\CM_JavaUsageLogging.log"
$LoggingEnable = $True
$UTLogFileName = ".java_usage_cm"

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


function Create-CMJavaUsageTracking {
  <#
  .SYNOPSIS
  Create Java usagetracking WMI Class
  #>
  process {
    try {
      $newClass = New-Object System.Management.ManagementClass("root\cimv2", [String]::Empty, $null); 

      $newClass["__CLASS"] = "CM_JavaUsageTracking"; 

      $newClass.Properties.Add("User", [System.Management.CimType]::String, $false)
      $newClass.Properties.Add("Type", [System.Management.CimType]::String, $false)
      $newClass.Properties.Add("DateTime", [System.Management.CimType]::String, $false)
      $newClass.Properties["DateTime"].Qualifiers.Add("Key", $true)
      $newClass.Properties.Add("HostIP", [System.Management.CimType]::String, $false)
      $newClass.Properties.Add("Command", [System.Management.CimType]::String, $false)
      $newClass.Properties.Add("JREPath", [System.Management.CimType]::String, $false)
      $newClass.Properties.Add("JavaVer", [System.Management.CimType]::String, $false)
      $newClass.Properties.Add("JREVer", [System.Management.CimType]::String, $false)
      $newClass.Properties.Add("JavaVen", [System.Management.CimType]::String, $false)
      $newClass.Properties.Add("JVMVen", [System.Management.CimType]::String, $false)

      $newClass.Put()
      IF ($LoggingEnable -eq $true) {Log-ScriptEvent -Value "CM_JavaUsageTracking class creation complete." -Severity 1}
    } CATCH {
      IF ($LoggingEnable -eq $true) {Log-ScriptEvent -Value "CM_JavaUsageTracking class creation error." -Severity 3}
    }
  }
}

 
Function Create-UsageTrackingProps { 
    <#
    .SYNOPSIS
    Create Java usagetracking.properties config file in specified path.
    #>
    [CmdletBinding()] 
    Param( 
      #The information to log 
      [parameter(Mandatory=$True)] 
      [String]$UTPath
      ) 
    process {
        $utprops=@'
# UsageTracker template properties file.
# Copy to JRE/lib/management/usagetracker.properties and edit,
# For more info reference http://docs.oracle.com/javacomponents/usage-tracker/overview/index.html

# Settings for logging to a file:
# Use forward slashes (/) because backslash is an escape character in a
# properties file.
com.oracle.usagetracker.logToFile = ${user.home}/.java_usage_cm
 
# (Optional) Specify a file size limit in bytes:
com.oracle.usagetracker.logFileMaxSize = 10000000

# Additional options:
# com.oracle.usagetracker.verbose = true
com.oracle.usagetracker.separator = ^
com.oracle.usagetracker.innerQuote = '
com.oracle.usagetracker.quote = " 
'@

        $utprops | Out-File -Encoding "UTF8" $UTPath
    }
}

########################################################################################################## 

IF ($LoggingEnable -eq $true) {Log-ScriptEvent -Value "Starting Java logging discovery." -Severity 1}

#Set Variables
$header = "Type","DateTime","HostIP","Command","JREPath","JavaVer","JREVer","JavaVen","JVMVen","OS","Arch","OSVer","JVMArg","ClassPath"
$DataSet = @()
$JREPaths = @("C:\Program Files (x86)\Java\jre7")

#Enable Java logging by enumerating the JREs from the registry
$Keys = Get-ChildItem "HKLM:\Software\WOW6432Node\JavaSoft\Java Runtime Environment"
$JREs = $Keys | Foreach-Object {Get-ItemProperty $_.PsPath }
ForEach ($JRE in $JREs) {
    IF ($LoggingEnable -eq $true) {Log-ScriptEvent -Value "Interogating JRE path $($JRE.JavaHome)" -Severity 1}
    $JREPath = test-path "$($JRE.JavaHome)\lib\management"
    if ($JREPath) {
        $UTProps = test-path "$($JRE.JavaHome)\lib\management\usagetracker.properties"
        if (-Not $UTProps) {
            IF ($LoggingEnable -eq $true) {Log-ScriptEvent -Value "Creating $($JRE.JavaHome)\lib\management\usagetracker.properties" -Severity 1}
            Create-UsageTrackingProps -UTPath "$($JRE.JavaHome)\lib\management\usagetracker.properties"
        } else {
            IF ($LoggingEnable -eq $true) {Log-ScriptEvent -Value "$($JRE.JavaHome)\lib\management\usagetracker.properties exists" -Severity 1}
        }
    }
}

#Enumerate user profile folders from WMI
try {
    IF ($LoggingEnable -eq $true) {Log-ScriptEvent -Value "Gather user profile paths." -Severity 1}
    $users = gwmi win32_userprofile | select LocalPath
    } Catch {
    IF ($LoggingEnable -eq $true) {Log-ScriptEvent -Value "Error gather user profile paths." -Severity 3}
    Exit 5150
}

#Check each returned folder for a java uasge log.
Foreach ($user in $users) {
    Write-Host ($($user.LocalPath) -split '\\')[-1].ToString()
    IF ($LoggingEnable -eq $true) {Log-ScriptEvent -Value "Checking for $($user.LocalPath)\$($UTLogFileName)" -Severity 1}
    $path = test-path "$($user.LocalPath)\$($UTLogFileName)"
    
    if ($path) {
        IF ($LoggingEnable -eq $true) {Log-ScriptEvent -Value "Found $($user.LocalPath)\$($UTLogFileName), attempting to load data." -Severity 1}
            Try {
                $Data = import-csv "$($user.LocalPath)\$($UTLogFileName)" -Delimiter '^' -Header $header
                $Dataset += $Data | Select @{Name="User";Expression={($($user.LocalPath) -split '\\')[-1].ToString()}},Type,DateTime,HostIP,@{Name="Command";Expression={if($_.Command -like 'http*'){($_.Command -split ': ')[0].ToString() } else {($_.Command -split ':')[0]}}},JREPath,JavaVer,JREVer,JavaVen,JVMVen
                IF ($LoggingEnable -eq $true) {Log-ScriptEvent -Value "Parsing $($user.LocalPath)\$($UTLogFileName)" -Severity 1}
            } Catch {
                Write-Host "Wowzzers" #Wicked error here
                IF ($LoggingEnable -eq $true) {Log-ScriptEvent -Value "Error parsing $($user.LocalPath)\$($UTLogFileName)" -Severity 3}
            Exit 5150
        }
    }
}

IF ($LoggingEnable -eq $true) {Log-ScriptEvent -Value "Completed data discovery, writing data to WMI" -Severity 1}

#Check for WMI Class
IF ($LoggingEnable -eq $true) {
    Log-ScriptEvent -Value "Verifying WMI Class exists.." -Severity 1
}

$WMICheck = Get-WmiObject -Class 'CM_JavaUsageTracking' -List -Namespace 'root\cimv2'
If (($WMICheck -ne $null) -eq $false) {
    IF ($LoggingEnable -eq $true) {
        Log-ScriptEvent -Value "CM_JavaUsageTracking class not found, creating class." -Severity 1
    }
    Create-CMJavaUsageTracking
    #Validate created class
    $WMIVerify = Get-WmiObject -Class "CM_JavaUsageTracking" -List -Namespace 'root\cimv2'
    If (($WMIVerify -ne $null) -eq $false) {
        IF ($LoggingEnable -eq $true) {
            Log-ScriptEvent -Value "Error creating class." -Severity 3
        }
        Exit 5150
    } else {
        IF ($LoggingEnable -eq $true) {
            Log-ScriptEvent -Value "Verified CM_JavaUsageTracking class exists." -Severity 1
        }
    }
} else {
    IF ($LoggingEnable -eq $true) {
        Log-ScriptEvent -Value "Verified CM_JavaUsageTracking class exists." -Severity 1
    }
}

#Check if logged instances are in WMI
ForEach ($Record in $DataSet) {
    $Instance = Get-WmiObject -Query "select Type from CM_JavaUsageTracking where DateTime='$($Record.DateTime)'"
    if (($instance -ne $null) -eq $false) {
        #Add record when not found
        IF ($LoggingEnable -eq $true) {
            Log-ScriptEvent -Value "Adding record to WMI datastore..." -Severity 1
        }
        $Arguments = @{User ="$($Record.User)";`
                    Type = "$($Record.Type)";`
                    DateTime = "$($Record.DateTime)";`
                    HostIP = "$($Record.HostIP)";`
                    Command = "$($Record.Command)";`
                    JREPath = "$($Record.JREPath)";`
                    JavaVer = "$($Record.JavaVer)";`
                    JREVer = "$($Record.JREVer)";`
                    JavaVen = "$($Record.JavaVen)";`
                    JVMVen = "$($Record.JREVen)";}
        Try {
            Set-WmiInstance -Class CM_JavaUsageTracking -argument $Arguments
        } Catch {
            IF ($LoggingEnable -eq $true) {
                Log-ScriptEvent -Value "Error inserting record." -Severity 3
            }
            Exit 5150
        }
        } else {
        IF ($LoggingEnable -eq $true) {
            Log-ScriptEvent -Value "Record already inserted" -Severity 1
        }
    }
}