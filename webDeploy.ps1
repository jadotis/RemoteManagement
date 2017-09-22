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
            "appPool"
            "source"
            "destination"
          }
.Usage:
    -CopyFiles between two remote hosts specified by two path's

.Version:
    -Version 1.0 (7/31/2017)
        -Initial Creation
    -Version 2.0 (8/01/2017)
        -Fully Working
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
      [Parameter(Mandatory=$true)]$appPool
      )

Import-Module WebAdministration -ErrorAction Ignore;
echo "Extracting Source and Destination Computers";
$srcComputer = "";
$destComputer = "";
$i = 2;

#Parse the incoming path and extract the servers.
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
    if($source[$source.length] -ne "\"){
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
    if($destination[$destination.length] -ne "\"){
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

#Check for connections to the servers
if(Test-Connection -ComputerName $srcComputer -Quiet){
    echo "Source Computer Found!: $srcComputer";
}
else{
    Write-Error -Message ($srcComputer + " is not online or is invalid")
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







#Script Blocks
$scriptContent1 = {

    $source = $args[0];
    $destination = $args[1];
    $appPool = $args[2];
    try{
        echo "importing necessary modules on remote server...";
        Import-Module WebAdministration;
    }catch{
        echo "WebAdministration is not available...";
        return "error";
    }
    $webSite = Get-Website | Where-Object {$_.Name -eq $appPool};
    if(!$webSite){
        Write-Error -Message "The appPool: $appPool could not be found";
        return "error";
    }
    if($webSite.state -eq "Stopped"){
        echo -Verbose "The appPool: $appPool is already stopped";
        }
    else{
        echo "Now Stopping AppPools...";
        try{
            Stop-Website -name $website.name ;
            Stop-WebAppPool -name $website.applicationPool;
            echo ("The status of $appPool is: " + (get-website -Name $appPool).state);
        }
        catch{
            Write-Error -Message "Unable to stop the AppPool: $appPool..."
            return "error"
        }
    }
}
$scriptContent2 = {
   $appPool = $args[0];
   $website = Get-Website -Name $appPool;
   echo "Restarting appPool and Website";
   try{
        start-Website -name $website.name;
        start-WebAppPool -name $website.applicationPool;
        echo ("$appPool restarted successfully (" + $website.state + ")");
      }
   catch{
        Write-Error $_.Exception;
        return;
      }
}

#Begin to copy files now that the website is stopped.


echo "Testing Credentials....";
try{ 
    $session = New-PSSession -ComputerName $destComputer;
    echo "Invoking command with Local Credentials";
    echo "authentication successful";
    $results = Invoke-Command -Session $session -ScriptBlock $scriptContent1 -ArgumentList $source,$destination,$appPool;
} 
catch
{ 
    echo "Service Account Does not have access to the specified Server...";
    echo $_.Exception;
    $results =  "error";
}
if(!($results -like "error")){
        try{
            echo "Beginning to copy files...";
            $filesCopied = (Get-ChildItem $source -Recurse | Measure-Object ).Count;
            $values = (Get-ChildItem $source -Recurse | Measure-Object -property length -sum);
            $test = $values.sum / 1MB;
            $values = ("{0:N2}" -f ($values.sum / 1MB)) + "MB";
            if($test -gt 250){       #Value can be changed
                Write-Error -Message "File sizes too large, max of 250MB";
                return;
            }
            Copy-Item -path $source -Destination $destination -Force -Recurse;
            echo "Files copied successfully: $filesCopied ($values)";
            if($backup){
                echo "Removing backup files...";
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
    Invoke-Command -Session $session -ScriptBlock $scriptContent2 -ArgumentList $appPool;
}
else{
    echo "The script terminated as there was no AppPool to stop";
}
echo "Script Terminating...";
Remove-PSSession -Session $session;
return;





