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
#>
param([Parameter(Mandatory=$true)]$username,
      [Parameter(Mandatory=$true)]$password,
      [Parameter(Mandatory=$true)]$source,
      [Parameter(Mandatory=$true)]$destination,
      [Parameter(Mandatory=$true)]$appPool
      )

Import-Module WebAdministration -ErrorAction Ignore;
echo "Extracting Source and Destination Computers";
$srcComputer = "";
$destComputer = "";
$i = 2;
$securePass = ConvertTo-SecureString $password -AsPlainText -Force;
$credentials = New-Object System.Management.Automation.PSCredential("ACADIAN\$username",$securePass);

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

#Script Blocks
$scriptContent1 = {

    $source = $args[0];
    $destination = $args[1];
    $appPool = $args[2];

    try{
        echo "importing necessary modules on remote server...";
        Import-Module WebAdministration;
    }catch{ echo "modules are already installed... continuing";}
    $webSite = Get-Website -name $appPool;
    if(!$webSite){
        Write-Error -Message "The appPool: $appPool could not be found";
        return "error";
    }
    if($webSite.state -eq "Stopped"){
        echo -Verbose "The appPool: $appPool is already stopped";
        }
    else{
        echo "Now Stopping AppPools...";
        Stop-Website -name $website.name ;
        Stop-WebAppPool -name $website.applicationPool;
        echo ("The status of $appPool is: " + (get-website -Name $appPool).state);
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


$session = New-PSSession -ComputerName $destComputer -Credential $credentials;
if($session -eq $null){
    echo "Invalid User Credentials";
    $results = "creds";
}




#Begin to copy files now that the website is stopped.

if($results -eq "creds"){
    echo "trying a session with service Account Credentials";
    try{ 
        $session = New-PSSession -ComputerName $destComputer;
        echo "invoking command with Local Credentials";
        echo "authentication successful";
        $results = $output = Invoke-Command -Session $session -ScriptBlock $scriptContent1 -ArgumentList $source,$destination,$appPool;
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
    try{ Invoke-Command -Session $session -ScriptBlock $scriptContent1 -ArgumentList $source,$destination,$appPool;}
    catch{
        echo "failed with local Credentials";
        $results = "error";
    }    
}


if($results -ne "error"){

    try{
        echo "Beginning to copy files...";
        Copy-Item -path $source -Destination $destination -Force -Recurse;
        $filesCopied = (Get-ChildItem $source -Recurse | Measure-Object ).Count;
        $values = (Get-ChildItem $source -Recurse | Measure-Object -property length -sum);
        $values = ("{0:N2}" -f ($values.sum / 1MB)) + "MB";
        echo "Files copied successfully: $filesCopied ($values)";
    }catch{
        echo $_.Exception;
        return;
    }    
    Invoke-Command -Session $session -ScriptBlock $scriptContent2 -ArgumentList $appPool;
}
else{
    echo "The script terminated as there was no AppPool to stop";
}
echo "Script Terminating...";
Remove-PSSession -Session $session ;
return;





