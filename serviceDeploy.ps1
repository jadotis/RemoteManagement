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
#>
param([Parameter(Mandatory=$true)]$username,
      [Parameter(Mandatory=$true)]$password,
      [Parameter(Mandatory=$true)]$source,
      [Parameter(Mandatory=$true)]$destination,
      [Parameter(Mandatory=$true)]$serviceName
      )
echo "Extracting Source and Destination Computers";
$srcComputer = "";
$destComputer = "";
$i = 2;
$securePass = ConvertTo-SecureString $password -AsPlainText -Force;
$credentials = New-Object System.Management.Automation.PSCredential("ACADIAN\$username",$securePass);

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


$session = New-PSSession -ComputerName $destComputer -Credential $credentials;
if($session -eq $null){
    echo "Invalid User Credentials";
    $results = "creds";
}
if($results -eq "creds"){
    echo "trying a session with service Account Credentials";
    try{ 
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
}
else{
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
        Copy-Item -path $source -Destination $destination -Force -Recurse;
        $filesCopied = (Get-ChildItem $source | Measure-Object ).Count;
        $values = (Get-ChildItem $source -Recurse | Measure-Object -property length -sum);
        $values = ("{0:N2}" -f ($values.sum / 1MB)) + "MB";
        echo "Files copied successfully: $filesCopied ($values)";
    }catch{
        echo $_.Exception;
        return;
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





