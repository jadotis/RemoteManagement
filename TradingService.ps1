<#
This script is used to identify the user currently using the trading service.
Author: James Otis
Date: 10/15/2017
For more information on IBM MQ runmsqc:
    https://www.ibm.com/support/knowledgecenter/en/SSFKSJ_7.5.0/

Notes: 
    - Script only works for the trading service, in order to change this, the 'Where' clause:
    $process.StandardInput.WriteLine("DISPLAY CONN(*) CONNAME WHERE (APPLTAG EQ '\Server\Trading.Svc.Host.exe')");
    will have to be replaced with the APPLTAG of the app. In order to find these you can run:
        "DISPLAY CONN(*) ALL", which will show all connections to the queue.
    - Permission issues will be thrown if the user executing does not have access to the running the 
    'runmqsc' application on bos-devmq03.
    - Important to note that bos-devmq01 does not exist, and is an alias for bos-devmq03.
    - While only one user can use the queue at one time, multiple users can be using the queue manager at one time,
    these are the users that will be returned in the output of the script.
    - Resolve-DNS is used instead of NSlookup, as the output nslookup does not return an easily parsable object
    - "bos-devtrading01" and "bos-devmacstrd01" are removed from the list of IPs that are checked.

Potential Problems:
    - Undefined behavior will occur from the DNS-lookup if the user is not on the domain. (Haven't tested this)
    - If changes to the Queue are made, there may be a change to the output text, which will not match the strings 
    that get replace via direct replacement or regex. (This can be simply fixed by taking a look at the output, and 
    manually changing the strings that are replaced).


#>

#Initialize a powershell session to bos-devmq03
try{
    $session = New-PSSession -ComputerName "bos-devmq03" -ErrorAction SilentlyContinue;
    }
catch{
    echo "Unable to connect to the server bos-devmq03, please execute this script locally...";
    return;
}
if($session -eq $null){
    echo "You do not have access to remote access to bos-devmq03";
    echo "Please contact a sys-admin for access"
    exit;
}

#Body of remote command is contained within a script block.
$scriptBlock = {

#Create a new Process Info object that we can pull the stdOutput stream from.
$ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo; 
$ProcessInfo.FileName = "runmqsc"; 
$ProcessInfo.RedirectStandardError = $true; 
$ProcessInfo.RedirectStandardOutput = $true; 
$ProcessInfo.RedirectStandardInput = $true;
$ProcessInfo.UseShellExecute = $false;
$ProcessInfo.Arguments = "QM1";
$process =[diagnostics.process]::start($ProcessInfo);
#command will be excecuted as <runmqsc QM1>
$process.StandardInput.WriteLine("DISPLAY CONN(*) CONNAME WHERE (APPLTAG EQ '\Server\Trading.Svc.Host.exe')");
$process.StandardInput.WriteLine("EXIT");
#run the DISPLAY CONN and retrieve the IP addresses where the Appl Tag corresponds to the trading service.
[string[]] $values = New-Object string[] 100;
while($true){
    $readValue = $process.StandardOutput.ReadLine(); #Read one loop at a time.
    if($readValue -eq $null){
        }
        try{
            while($index = $readValue.IndexOf("CONNAME(") -eq -1){
                $readValue = $process.StandardOutput.ReadLine();
                }
            }
            catch{
                
                break;
                }
    #Replace all of the plaintext junk from the output stream.
    $readValue = $readValue.Replace("APPLTAG(\Server\Trading.Svc.Host.exe","");
    $readValue = $readValue.Replace("CONNAME(","");
    $readValue = $readValue.Replace("AMQ8276: Display Connection details.","");
    $readValue = $readValue.Replace("5724-H72 (C) Copyright IBM Corp. 1994, 2016.","");
    $readValue = $readValue.Replace(")","");
    $readValue = $readValue.trim();
    $readValue = $readValue.TrimEnd();
    $readValue = $readValue.TrimStart();
    $readValue = $readValue -replace '(^\s+|\s+$)','' -replace '\s+',' ';
    #Regex to remove the extra whitespace.
    $values = $values + $readValue;
}

$values = $values | select -Unique; #Remove the repeated values from the list.
$values = $values[1..($values.Length - 1)]; #remove the first value that is always null
$outCount = 0;
foreach($i in $values){
        $value = Resolve-DnsName $i #run a nslookup (Resolve-DnsName) on each Ip returned
        $value =  $value.NameHost.replace(".acadian-asset.com","");
        if($value -eq "bos-devtrading01" -or $value -eq "bos-devmacstrd01"){
            continue; 
        }
        else{
            echo $value;
            $outCount++;
        }
        
}
if($outCount -eq 0){ #Will only occur when no one is running the services.
    echo "No one currently has the Queue";
}
}

invoke-command -Session $session -ScriptBlock $scriptBlock;