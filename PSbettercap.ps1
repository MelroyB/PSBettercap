$Host.UI.RawUI.WindowTitle = "PSBettercap"
# $DebugPreference = 'SilentlyContinue'
$DebugPreference = 'Continue'

$Sessionfile = 'c:\github\PSBettercap\session.xml'
$nodefile = 'c:\github\PSBettercap\nodes.xml'

##turn on hotspot
#$connectionProfile = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetInternetConnectionProfile()
#$tetheringManager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]::CreateFromConnectionProfile($connectionProfile)
#$tetheringManager.TetheringOperationalState


### load node file
if (Test-Path -Path $nodefile) {
   write-host "Previous nodes found and imported" -ForegroundColor Green
   $objNodes = import-clixml $nodefile
    
 } else {
    write-host "No previous nodes found" -ForegroundColor Green
    $objNodes = @()   
 }

### load session file
if (Test-Path -Path $Sessionfile) {
   write-host "Previous session found and imported" -ForegroundColor Green
   $global:objAPs = import-clixml $Sessionfile
    
 } else {
    write-host "No previous session found" -ForegroundColor Green
    $global:objAPs = @()   
 }

$global:events=@()
$global:events += new-object psobject -property @{
                                    message="Starting PSBettercap"
                                    color="green"
                                    bcolor="black"
                                }



$objAP = @()


function create-map{
#### Skip no location
#### descriptions

$kml = @"
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
<Document>
	<name>project</name> 

"@


        foreach ($objAP in $objAPS) {
        $strKMLname=$objAp.hostname
        $strKMLmac=$objAp.mac
        $strKMLlatitude=$objAP.latitude
        $strKMLlongitude=$objAP.longitude

        $kml += @"
<Placemark>
    <name>$strKMLmac</name>
    <description>123</description>
    <Point>
    <coordinates>$strKMLlongitude,$strKMLlatitude</coordinates>
    </Point>
</Placemark>

"@
}

$kml += @"
</Document>
</kml>

"@




$kml | Out-File -Force -Encoding ascii ("c:\temp\log-$((get-date).ToString("yyyyMMdd-HHmmss")).kml")


}
function export-results{
#Convert to CSV
$global:objAPs | Select-Object mac,hostname,vendor,channel,encryption,auth,clients,handshake,latitude,longitude,last_seen,detectedby | export-csv -Path C:\temp\log-$((get-date).ToString("yyyyMMdd-HHmmss")).csv
##
}
function Write-HostCenter {
 param($Message) Write-Host ("{0}{1}" -f (' ' * (([Math]::Max(0, $Host.UI.RawUI.BufferSize.Width / 2) - [Math]::Floor($Message.Length / 2)))), $Message) }

function Get-GPS {   
        write-host $objnodes | format-table  
        foreach ($objNode in $objNodes){
                $uri = $objnode.protocol + '://' + $objNode.ip + ':' + $objNode.port + '/api/session'            
                $all = Invoke-RestMethod -Uri $uri -TimeoutSec 5
                $all.gps.Altitude
                $all.gps.Longitude
                $all.gps.FixQuality
                $all.gps.NumSatellites
                #clear-variable all
                }
        }  
function Get-BettercapAPs {   
        foreach ($objNode in $objNodes){
        ### Loop through nodes
                $objApiResult = $null
                $uri = $objnode.protocol + '://' + $objNode.ip + ':' + $objNode.port + '/api/session'
                try {$objApiResult = Invoke-RestMethod -Uri $uri -TimeoutSec 5}catch{}

                if ($objApiResult -eq $null){
                    $UpdateNode=$objNodes | Where-Object {$_.ip -eq $objNode.ip}
                    $updatenode.online = $false


                    } else {
                    
                    $UpdateNode=$objNodes | Where-Object {$_.ip -eq $objNode.ip}
                    $updatenode.online = $true
                    }
                
                ### Only set objects if gpsfix            
                if ($objApiResult.gps.FixQuality -cgt 0){
                $objApiResult.gps.Latitude = [math]::Round($objApiResult.gps.Latitude,5)
                $objApiResult.gps.Latitude = $objApiResult.gps.Latitude -replace ',', '.'
                $objApiResult.gps.Longitude = [math]::Round($objApiResult.gps.Longitude,5)
                $objApiResult.gps.Longitude = $objApiResult.gps.Longitude -replace ',', '.'
                    
                    $global:objGPS = New-Object PSObject -property @{
                                    Longitude = $objApiResult.gps.Longitude
                                    Latitude = $objApiResult.gps.Latitude
                                    NumSatellites = $objApiResult.gps.NumSatellites
                                    }
                                  }else{
                    $global:objGPS = New-Object PSObject -property @{
                                    Longitude = $null
                                    Latitude = $null
                                    NumSatellites = $objApiResult.gps.NumSatellites
                                    }
                                  }
                
                ### Loop Through all AccessPoints
                foreach ($ap in $objApiResult.wifi.aps){ 
                          
                          ### Check if AP is already in the table
                          if (($global:objAPs) -and ($global:objAPs.mac.Contains($ap.mac))){
                            $UpdateAP=$global:objAPs | Where-Object {$_.mac -eq $ap.mac}
                              if (($UpdateAP.handshake -eq $false) -and ($ap.handshake -eq $true)){
                                    new-event "$((get-date).ToString("HH:mm:ss"))|$($ap.mac)|$($ap.hostname) Handshake captured" "black" "green"
                                    $UpdateAP.handshake=$ap.handshake
                                    }

                            $UpdateAP.last_seen=$ap.last_seen.Split("\.")[0]
                            $UpdateAP.detectedby=$objnode.ip + ':' +  $objnode.port
                            $UpdateAP.received=$ap.received
                            $UpdateAP.sent=$ap.sent
                            $UpdateAP.clients=$ap.clients.count
                            ###write-host $ap.mac "signaal" $ap.rssi "was eerder" $updateAp.rssi

                          ### Check if AP signal is better before update GPS location
                                 if (($updateAP.rssigpsupdate -lt $ap.rssi) -and ($objApiResult.gps.FixQuality -cgt 0)){
                                        new-event "$((get-date).ToString("HH:mm:ss"))|$($ap.mac)|$($ap.hostname) GPS location updated" "green" "black"
                                        $updateAP.latitude=$objGPS.latitude
                                        $updateAP.longitude=$objGPS.Longitude
                                        $updateAP.rssigpsupdate=$ap.rssi
                                        $updateAp.rssi=$ap.rssi 
                                       }else{

                                       ###Write-host $ap.mac "Minder bereik, GPS geupdate bij " $updateAP.rssigpsupdate  " nu " $ap.rssi
                                        $updateAp.rssi=$ap.rssi
                                        }

                                  }else {
                                    new-event "$((get-date).ToString("HH:mm:ss"))|$($ap.mac)|$($ap.hostname) Found new AP" "green" "black"              
                                    $global:objAPs += New-Object PSObject -property @{
                                    mac=$ap.mac
                                    alias= $ap.alias
                                    auth = $ap.authentication
                                    channel = $ap.channel
                                    cipher = $ap.cipher
                                    clients = $ap.clients.count
                                    clientsdetails = $ap.clients
                                    encryption = $ap.encryption
                                    first_seen = $ap.first_seen.Split("\.")[0]
                                    frequency = $ap.frequency
                                    handshake = $ap.handshake
                                    hostname = $ap.hostname
                                    ipv4 = $ap.ipv4
                                    ipv6 = $ap.ipv6
                                    last_seen = $ap.last_seen.Split("\.")[0]
                                    meta = $ap.meta
                                    received = $ap.received
                                    rssi = $ap.rssi
                                    sent = $ap.sent
                                    vendor = $ap.vendor
                                    wps = $ap.wps
                                    detectedby = $objnode.ip + ':'+ $objnode.port 
                                    latitude = $objGPS.latitude
                                    longitude = $objGPS.Longitude
                                    rssigpsupdate= $ap.rssi
                                }
                            #Clear-Variable objApiResult
                        #$global:objAPs += $objAP
                        }}
                }
                ###$global:objAPs | Format-table -Property mac,hostname,channel,detectedby,latitude,longitude,rssi,rssigpsupdate
       

        }    
function Show-BettercapAPs { 
        $global:objAPs | Format-table -Property first_seen,last_seen,mac,hostname,vendor,channel,encryption,cipher,auth,handshake,clients,detectedby
        Write-host "total Aps:" $global:objAPs.count
    }
function Show-handshakes{

### TODO

$Handshakes = $WifiAps | Where-Object -FilterScript {$_.handshake -EQ 'True'}
    foreach ($handshake in $Handshakes){

        $uri = 'http://' + $nodeip + ':' + $ApiPort + '/api/session/wifi/' + $handshake.mac
        $temp = Invoke-RestMethod -Uri $uri -TimeoutSec 5

        }

}
function Show-Help { 
       Write-host "nodes show = show bettercap nodes"
       Write-host "nodes add = add bettercap nodes"
       Write-host "nodes int = Config bettercap node interface"
       Write-host "nodes channel = Config bettercap node channel"
       Write-host "nodes del = del bettercap nodes"
       Write-host "nodes start = start all bettercap nodes"
       Write-host "nodes stop = stop all bettercap nodes"
       Write-host "show = show networks"
       Write-host "help = help"
       Write-host "q = quit"
    }
function command-nodes { 
    param ($a)
       if ($a -like "nodes show") {
            write-host $objNodes.count "Bettercap node(s) configured"
            write-host "----------"
            ($objNodes | format-table online,ip,port,interface,channel,comment| Format-Table  | Out-String).Trim()
             }
       if ($a -like "nodes add") {
            write-host add command
                    $IPPattern = '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
                     Write-Host "IP: " -NoNewline
                    do {
                        $NodeIP = Read-Host
                        $ok = $NodeIP -match $IPPattern
                            if ($ok -eq $false) {
                                    Write-Warning ("'{0}' is not an IP address." -f $NodeIP)
                                    write-host "Please Enter IP: " -NoNewline
                                    }
                                    <#Condition#>
                                    } until ( $ok )

                    ### Protocol
	                    $NodeProtocol=Read-Host "Protocol (h)ttp or http(s)" 
	                    Switch ($NodeProtocol)
	                    {
		                    H {$NodeProtocol="HTTP"}
                            HTTP {$NodeProtocol="HTTP"}
		                    S {$NodeProtocol="HTTPS"}
                            HTTPS {$NodeProtocol="HTTPS"}
		                    }
                    $nodePort=Read-Host -Prompt 'Port:'
                    $nodeChannel=Read-Host -Prompt 'Comma separated list of channels to hop on or all:'
                    $nodeComment=Read-Host -Prompt 'Comment:'

                     $objNodes += new-object psobject -property @{
                                                        ip=$NodeIP
                                                        port=$nodePort
                                                        protocol=$NodeProtocol
                                                        channel=$nodeChannel
                                                        comment=$nodeComment
                                                    }
               }
       if ($a -like "nodes del") {


            $testIP= Read-Host -Prompt 'IP>'
            $testPort = Read-Host -Prompt 'Port>'

             $delNodes = $objNodes | Where-Object {($_.IP -eq $testIP) -and ($_.Port -eq $testport) } 
             $objNodes = $objNodes  | Where-Object { $_ -ne $delNodes    }}
       if ($a -like "nodes int") {choose-nodeinterface}
       if ($a -like "nodes channel") {set-nodechannels}
       if ($a -like "nodes start") {Start-Nodes}
       if ($a -like "nodes stop") {Stop-Nodes}
    }
    
   
function Out-Debug{
    Param
    (
        [System.Management.Automation.InvocationInfo]$Invocation,

        [Parameter(ValueFromPipeline = $true)]
        [string[]]$Variable,

        [string]$Scope = 1
    )

    Process
    {
        foreach($var in $Variable)
        {
            @(
                "Origin: $($Invocation.MyCommand.Name)",
                "Variable: $var",
                'Value:',
                (Get-Variable -Name $var -Scope $Scope -ValueOnly |
                    Format-Table -AutoSize -Wrap | Out-String)
            ) | Write-Debug
        }
    }
}
function save-session {
$global:objAPs | export-clixml $Sessionfile -Force
}

function add-node{
    show-nodes
    $objNodes += new-object psobject -property @{
                                    ip=Read-Host -Prompt 'Hostname/IP'
                                    port=Read-Host -Prompt 'REST API Port'
                                    protocol=Read-Host-Prompt 'HTTP or HTTPS'
                                    channel=Read-Host-Prompt 'Channels to scan or all'
                                    comment=Read-Host-Prompt 'Comment'
                                    online=$false
                                    interface=$null
                                }
    save-nodes

}
function save-nodes {
$objNodes | export-clixml $nodefile -Force
}
function remove-node{
$count = 0
    $objNodes | select-object ip,port,comment| ForEach-Object {
    $_ |  Select-Object @{Name = 'ID'; Expression = {$count}}, *
    $count++} | Format-Table -AutoSize
    $Delnode = Read-Host -Prompt 'ID to remove'

    $objnodes= $objnodes | where ({$_.port -ne $objnodes[$Delnode].port -or $_.ip -ne $objnodes[$Delnode].ip})
    save-nodes
}
function show-nodes{
($objNodes | format-table online,ip,port,interface,channel,comment| Format-Table  | Out-String).Trim()
}
function choose-nodeinterface{
        foreach ($objNode in $objNodes){

        $objApiResult = $null
        $uri = $objnode.protocol + '://' + $objNode.ip + ':' + $objNode.port + '/api/session'
        try {$objApiResult = Invoke-RestMethod -Uri $uri -TimeoutSec 5}catch{}
    

                            if ($objApiResult -eq $null){
                            write-host $objNode.ip "is offline"
                            } else {
                    
                            $selection = $objApiResult.interfaces | Where-Object {$_.name -like "wl*"}

                                If($selection.Count -gt 1){
                                    $title = "Interfaces"
                                    $message = "Which interface would you like to use?"

                                    # Build the choices menu
                                    $choices = @()
                                    For($index = 0; $index -lt $selection.Count; $index++){
                                        $choices += New-Object System.Management.Automation.Host.ChoiceDescription ($selection[$index]).Name, ($selection[$index]).FullName
                                    }

                                    $options = [System.Management.Automation.Host.ChoiceDescription[]]$choices
                                    $result = $host.ui.PromptForChoice($title, $message, $options, 0) 
                                                        
                            


                                    $UpdateNode=$objNodes | Where-Object {$_.ip -eq $objNode.ip} | Where-Object {$_.port -eq $objNode.port}
                                    $UpdateNode.interface = $selection[$result].name


                                    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
                                    $headers.Add("Content-Type", "application/json")
                                    try {Invoke-RestMethod -uri $uri -Method 'POST' -Headers $headers -Body "{`"cmd`": `"set wifi.interface $($updatenode.interface)`"}" -TimeoutSec 5}catch{}
                                }


                   
                            }

        }}
function set-nodechannels{


$SelectNode = $null
$count = 0
$objNodes | select-object ip,port,channel,comment| ForEach-Object {
    $_ |  Select-Object @{Name = 'ID'; Expression = {$count}}, *
    $count++} | Format-Table -AutoSize

    $SelectNode = Read-Host -Prompt 'ID to change channel'

    $UpdateNode= $objnodes | where ({$_.port -eq $objnodes[$SelectNode].port -and $_.ip -eq $objnodes[$SelectNode].ip})
    $UpdateNode.channel = Read-Host -Prompt 'Comma seperated channels or all'
    save-nodes
   }
function Start-Nodes {
            $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $headers.Add("Content-Type", "application/json")
            foreach ($objNode in $objNodes){
                $uri = $objnode.protocol + '://' + $objNode.ip + ':' + $objNode.port + '/api/session'  
                
                try {Invoke-RestMethod -uri $uri -Method 'POST' -Headers $headers -Body "{`"cmd`": `"set wifi.interface $($updatenode.interface)`"}" -TimeoutSec 5}catch{}
                try {Invoke-RestMethod -uri $uri -Method 'POST' -Headers $headers -Body "{`"cmd`": `"wifi.recon on`"}" -TimeoutSec 5}catch{}
                }
            }
function Stop-Nodes {
            $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $headers.Add("Content-Type", "application/json")
            foreach ($objNode in $objNodes){
                $uri = $objnode.protocol + '://' + $objNode.ip + ':' + $objNode.port + '/api/session' 
                Invoke-RestMethod -uri $uri -Method 'POST' -Headers $headers -Body "{`"cmd`": `"wifi.recon off`"}" -TimeoutSec 10
                }
            }
function PowerOff-Nodes {
            $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $headers.Add("Content-Type", "application/json")
            foreach ($objNode in $objNodes){
                $uri = $objnode.protocol + '://' + $objNode.ip + ':' + $objNode.port + '/api/session' 
                Invoke-RestMethod -uri $uri -Method 'POST' -Headers $headers -Body "{`"cmd`": `"!shutdown -h -t 0`"}" -TimeoutSec 10
                }
            }

function new-event($eventmessage,$eventcolor,$eventbcolor){
$global:events += new-object psobject -property @{message=$eventmessage; color=$eventcolor; bcolor=$eventbcolor}
}
function show-events{
    $global:events = $global:events | Select-Object -Last 15
    foreach ($objEvent in $global:events){write-host $objEvent.message -ForegroundColor $objEvent.color -BackgroundColor $objEvent.bcolor}
}

Function GetKeyPress([string]$regexPattern='[ynq]', [string]$message=$null, [int]$timeOutSeconds=0){
    $key = $null
    $Host.UI.RawUI.FlushInputBuffer() 

    if (![string]::IsNullOrEmpty($message))
    {Write-Host -NoNewLine $message}

    $counter = $timeOutSeconds * 1000 / 250
    while($key -eq $null -and ($timeOutSeconds -eq 0 -or $counter-- -gt 0)){
        if (($timeOutSeconds -eq 0) -or $Host.UI.RawUI.KeyAvailable)
        {                       
            $key_ = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,IncludeKeyUp")
            if ($key_.KeyDown -and $key_.Character -match $regexPattern)
            { $key = $key_ }
        }
        else
        {Start-Sleep -m 250  # Milliseconds }
    }                       

    if (-not ($key -eq $null))
    {        Write-Host -NoNewLine "$($key.Character)"}

    if (![string]::IsNullOrEmpty($message))
    {        Write-Host "" # newline}       

    return $(if ($key -eq $null) {$null} else {$key.Character})
}


### Commandprompt loop

### handshakes


$continue = $true
while ($continue) {
    $prompt = Read-Host -Prompt '>'
    if ($prompt -eq "q") {$continue = $false}
    if ($prompt -eq "show") {Show-BettercapAPs}
    if ($prompt -like "nodes*") {command-nodes $prompt}
    if ($prompt -eq "help") {show-help}

    if ($prompt -eq "start") {
        
        $continue2 = $true
        while ($continue2) {
        Get-BettercapAPs
        Clear-Host
        Write-HostCenter "######## Last 20 APS ########"
        ($global:objAPs |Sort-Object -Property last_seen |select -last 20 | Format-table -Property last_seen,mac,hostname,channel,encryption,auth,handshake,clients,detectedby,latitude,longitude| Format-Table  | Out-String).Trim()
        Write-HostCenter "########### Nodes ###########"
        show-nodes
        Write-HostCenter "########### Events ##########"
        show-events
        Write-HostCenter "#############################"
        Write-host $global:objAPs.count "Accesspoints / " -NoNewline
        Write-host $OBJgps.NumSatellites "GPS Sattelites"
        Write-host "press q to stop scanning " -NoNewline
        $key = GetKeyPress '[ynq]' "([y]/n/q)?" 2
                    if ($key -eq "q"){$continue2 = $false}
        }  
    }
} 





create-map
export-results
save-session
save-nodes
#PowerOff-Nodes


#### curl -X POST -F "email=SOME_VALID_EMAIL" -F "file=@/path/to/handshake.pcap" https://api.onlinehashcrack.com
# set wifi.ap.ttl 30
# set wifi.sta.ttl 30

