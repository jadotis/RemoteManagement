#########################################################

<#    James Otis 7/12/2017 jotis@acadian-asset.com     #>
#########################################################

<#
This script is used for the backend of the deployment portal
.Arguments:
    -Arguments are fed in through a commandblock of the structure:
          {
            "username"
            "password"
            "source"
            "destination"
            "serviceName"
          }
.Usage:
    -CopyFiles between two remote hosts specified by two path's

.Version:
    -Version 1.0 (7/31/2017)
        -Initial Creation
    -Version 2.0 (8/01/2017)
        -Error Checking for Parameters
        -Fixed issue with Files Still being copied
        -Won't cancel out on error
    -Version 3.0 (9/21/2017)
        -Fixed backup issues
        -Made backup optional based on leaves
        -Replaced some True variables with the appropriate $True
        -Fixed minute issues that had issues with performance
        -Cleaned and removed unnecessary code.
        -Early exits on conditions that should cause a termination
#>
param(
      [Parameter(Mandatory=$true)]$source,
      [Parameter(Mandatory=$true)]$destination,
      [Parameter(Mandatory=$true)]$serviceName
      )
echo "Extracting Source and Destination Computers";
$srcComputer = "";
$destComputer = "";
$i = 2;
if($source -like "*.*"){
    try{
        while($source[$i] -ne "\"){
            $srcComputer += $source[$i];
            $i += 1;
        }
    }
    catch{Write-Error -Message "Invalid Source Path"; return;}
}
else{
    #Check to see if there is not a trailing '\'
    if($source[$source.length - 1] -ne "\"){
        $source += "\";
    }
    $i = 2;
    try{
        while($source[$i] -ne "\"){
            $srcComputer += $source[$i];
            $i += 1;
        }
    }
    catch{Write-Error -Message "Invalid Source Path"; return;}

}
if($destination -like "*.*"){
    try{
        $i = 2;
        while($destination[$i] -ne "\"){
            $destComputer += $destination[$i];
            $i += 1;
        }
    }
    catch{Write-Error -Message "Invalid Destination Path"; return;}
}
else{
    #Check to see if there is not a trailing '\'
    if($destination[$destination.length - 1] -ne "\"){
        $destination += "\";
    }
    $i = 2;
    try{
        while($destination[$i] -ne "\"){
            $destComputer += $destination[$i];
            $i += 1;
        }
    }
    catch{Write-Error -Message "Invalid Source Path"; return;}

}

#Check for connection to the two specified servers
if(Test-Connection -ComputerName $srcComputer -Quiet){
    echo "Source Computer Found!: $srcComputer";
}
else{
    Write-Error -Message ($srcComputer + " is not online or is invalid");
    return;
}
if(Test-Connection -ComputerName $destComputer -Quiet){
    echo "Destination Computer Found!: $destComputer";
}
else{
   Write-Error -Message ($destComputer +" is not online or is invalid");
   return;
}
if(!(Test-Path -Path $source)){
    Write-Error -Message "Unable to find Source: Check path";
    return;
}
if(!(Test-Path -Path $destination)){
    echo "The path does not exist, creating folder...";
    $backup = $false;
    $folderName = Split-Path $destination -Leaf;
    $parent = Split-Path $destination -Parent;
    try{
        mkdir -Path $parent -Name $folderName;
    }catch{
        Write-Error -Message "Unable to create the destination folder... Exiting....";
        exit;
    }
}
else{
    $backup = $true;
    $folderName = Split-Path $destination -Leaf;
    $parent = Split-Path $destination -Parent;
    echo "creating a backup for the folder: $foldername";
    mkdir -Path $parent -name "backup" -ErrorAction Stop;
    Copy-Item -Path "$destination/*" -Destination "$parent/backup";
    remove-item -Path "$destination/*" -Force -Recurse -ErrorAction Stop;
}
#End confirmation and prep steps.


#Remote Management and Script blocks
$scriptContent1 = {
    #Stops the specified Service.
    $source = $args[0];
    $destination = $args[1];
    $serviceName = $args[2];

    $service = Get-Service -Name $serviceName;
    try{
        echo "Attempting to stop Service based on 'Name'";
        if($service.Status -eq "stopped"){
            echo ("Specified Service: " + $service.name  +" is already stopped...");
        }
        else{
            Stop-Service -name $service.Name -Force;
            echo ("success stopping Service: " + $service.Name);
            echo "Confirming....";
            $service = Get-Service -name $serviceName;
            Start-Sleep -s 2;
            if($service.Status -eq "stopped"){
                echo "stop confirmed!";
            }
            else{
                echo ("unsuccessfully stopped " + $_.Exception);
                exit;
            }

            }
       }
    catch{
        echo $_.Exception ;
        echo "service could not be found by Name... Trying DisplayName...";
        $service = Get-Service -DisplayName $serviceName;
        try{
            echo "Attempting to stop Service based on 'DisplayName'...";
            Stop-Service -DisplayName $service -Force;
            echo ("Success with Displayname: " + $service.DisplayName);
            echo "Confirming....";
            Start-Sleep -s 2;
            $service = Get-Service -DisplayName $servicename;
            if($service.Status -eq "stopped"){
                echo "stop confirmed!";
            }
            else{
                echo ("unsuccessfully stopped: " + $_.Exception);
            }
            }
            catch{
                Write-Error -Message "could not find the service under DisplayName...";
                return "error";
            }
    }

}
$scriptContent2 = {
        #restarts the service Specified
        $serviceName = $args[0];
        $service = Get-Service -Name $serviceName;

        try{
            echo ("restarting service: " + $service.Name);
            Start-Service -name $serviceName;
            echo ("Service " + $service.Name + " restarted successfully");
            echo "Confirming...";
            Start-Sleep -s 2;
            $service = Get-Service -name $serviceName
            if($service.Status -eq "Running"){
                echo "Service is confirmed Running...";
            }
            else{
                echo ("unsuccessfully started: " + $_.Exception);
            }
            }
            catch{
                echo ("No service able to be started with" + $serviceName + ".... trying DisplayName...");         
                try{
                    Start-Service -DisplayName $serviceName;
                    echo ("Restarted Successfully using the displayName: " + $service.DisplayName + "...");
                    echo "Confirming...";
                    Start-Sleep -s 2;
                    $service = Get-Service -DisplayName $serviceName;
                    if($service.Status -eq "Running"){
                        echo "Service is confirmed Running...";
                    }
                    else{
                        echo ("unsuccessfully started: " + $_.Exception);
                    }
                }
                catch{
                    Write-Error -Message $_.Exception;
                }

        }
}

try{ 
    echo "trying a session with service Account Credentials";
    $session = New-PSSession -ComputerName $destComputer;
    echo "Authentication Successful with local Credentials, executing...";
    $results = Invoke-Command -Session $session -ScriptBlock $scriptContent1 -ArgumentList $source,$destination,$serviceName;
    echo $results;
} 
catch
{ 
    echo "Service Account Does not have access to the specified Server...";
    echo $_.Exception;
    $results =  "error";
}
if(($results -ne "error")){ 
    try{ 
        ##stop the service.
        Invoke-Command -Session $session -ScriptBlock $scriptContent1 -ArgumentList $source,$destination,$serviceName;
    }catch{
        $results = "error";}
        echo $_.Exception;
}

#Begin to copy files now that the service is Stopped
if($results -ne "error"){
        try{
            echo "Beginning to copy files...";
            $filesCopied = (Get-ChildItem $source -Recurse | Measure-Object ).Count;
            $values = (Get-ChildItem $source -Recurse | Measure-Object -property length -sum);
            $test = $values.sum / 1MB;
            $values = ("{0:N2}" -f ($values.sum / 1MB)) + "MB"
            if($test -gt 250){                                       #Value can be changed
                Write-Error -Message "File sizes too large, max of 250MB";
                return;
            }
            Copy-Item -path $source -Destination $destination -Force -Recurse;
            echo "Files copied successfully: $filesCopied ($values)";
            if($backup){
                echo "Removing backup files..."
                Remove-Item -Path "$parent/backup" -Recurse -Force;
            }
        }catch{
        if($backup){
            echo $_.Exception;
            echo "Restoring backup...."
            Remove-Item -Path "$destination/*"  -Force -Recurse;
            Copy-Item -Path "$parent/backup/*" -Destination $destination;
            Remove-Item -Path "$parent/backup" -Force -Recurse;
            return;
        }
    }    

    ##restart the service
    $res = Invoke-Command -Session $session -ScriptBlock $scriptContent2 -ArgumentList $serviceName;
    echo $res;
}
else{
    echo ("Script terminated with exception:  " + $_.Exception);
}

echo "Script Terminating...";
Remove-PSSession -Session $session;
return;





