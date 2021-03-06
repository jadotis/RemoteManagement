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
          }
.Usage:
    -CopyFiles between two remote hosts specified by two path's

.Version:
    -Version 1.0 (7/12/2017)
        -Initial Creation
    -Version 2.0 (7/26/2017)
        -Changed to File Copy structure
    -Version 3.0 (7/28/2017)
        -Enhanaced logging to be passed to front end
        -Fixed a bunch of Write Error bugs
        -Added Catching for a Index-Outof-Bounds Exception
    -Version 4.0 (9/21/2017)
        -Fixed backup issues
        -Made backup optional based on leaves
        -Replaced some True variables with the appropriate $True
        -Fixed minute issues that had issues with performance
        -Cleaned and removed unnecessary code.
        -Early exits on conditions that should cause a termination


#>



param(
      [Parameter(Mandatory=$true)]$source,
      [Parameter(Mandatory=$true)]$destination
      )

#Both Echos and statements work as writes that are picked up;
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
if(!(Test-Path -path $source)){
    Write-Error -Message "The source path: $source could not be found exiting...."
    exit;
}

#now begin copying
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
    remove-item -Path "$destination/*" -Force -Recurse;
}
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
    Copy-Item -path $source -Destination $destination -Force -Recurse -ErrorAction Stop;
    echo "Files copied successfully: $filesCopied ($values)";
    if($backup){
        echo "Removing backup files..."
        Remove-Item -Path "$parent/backup" -Recurse -Force;
        }
    return;
}catch{
    if($backup){
        echo $_.Exception;
        echo "Restoring backup...."
        Remove-Item -Path "$destination/*"  -Force -Recurse;
        Copy-Item -Path "$parent/backup/*" -Destination $destination;
        Remove-Item -Path "$parent/backup" -Force -Recurse;
        return;
     }
    else{
       echo "No backup to be restored...Exiting..."
       exit;
    }
}    