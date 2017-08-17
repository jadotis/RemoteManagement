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


#now begin copying
if(!(Test-Path -Path $source)){
    Write-Error -Message "Unable to find Source Destination: Check path";
    return;
}
if(!(Test-path -path $destination)){
    Echo "Creating Folder in Destination: $destination";
    try{
        $Dir = mkdir -path $destination -ErrorAction stop;
    }catch{
        Write-Error -Message $_.Exception;
    }
}

try{
    echo "Creating a backup of the files in destination directory.....";
    $parent = Split-Path -parent $destination;
    echo $parent;
    mkdir -Path $parent -Name "backup" -ErrorAction SilentlyContinue;
    Copy-Item -Path $destination -Destination "$parent/backup" -Recurse -Force;
    echo "backup created Successfully!";
}
catch
{
    Write-Error -Message "Error creating backup....Exiting...";
    return;
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
    echo "Removing backup files...."
    Remove-Item -Path "$parent/backup" -Recurse -Force;
}catch{
    echo $_.Exception;
    echo "Restoring backup...."
    Remove-Item -Path $destination  -Force -Recurse;
    Copy-Item -Path "$parent/backup" -Destination $destination;
    #Remove-Item -Path "$parent/backup" -Force -Recurse;
    return;
}    