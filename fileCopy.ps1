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



param([Parameter(Mandatory=$true)]$username,
      [Parameter(Mandatory=$true)]$password,
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
    $Dir = mkdir -path $destination;
}

try{
    echo "Beginning to copy files..."
    Copy-Item -Path $source -Destination $destination -Force -Recurse
    $filesCopied = (Get-ChildItem $source | Measure-Object ).Count;
    $values = (Get-ChildItem $source -Recurse | Measure-Object -property length -sum)
    $values = ("{0:N2}" -f ($values.sum / 1MB)) + "MB"
    echo "Files copied successfully: $filesCopied ($values)";
    echo "Script terminated Successfully";
    echo $LASTEXITCODE;
    return;

}catch{
    echo $LASTEXITCODE
    return;
}





