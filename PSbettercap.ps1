﻿$Host.UI.RawUI.WindowTitle = "PSBettercap"
clear

# $DebugPreference = 'SilentlyContinue'
$DebugPreference = 'Continue'
$base=$(if ($psISE) {Split-Path -Path $psISE.CurrentFile.FullPath} else {$(if ($global:PSScriptRoot.Length -gt 0) {$global:PSScriptRoot} else {$global:pwd.Path})})

$Sessionfile = $base + "\session.xml"
$nodefile = $base + "\nodes.xml"
$csvfile = $base + "\log-$((get-date).ToString("yyyyMMdd-HHmmss")).csv"

$global:events  =@()
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
$global:objAPs | Select-Object mac,hostname,vendor,channel,encryption,auth,clients,handshake,latitude,longitude,last_seen,detectedby | export-csv -Path $csvfile
##
}
function Write-HostCenter {
 param($Message) Write-Host ("{0}{1}" -f (' ' * (([Math]::Max(0, $Host.UI.RawUI.BufferSize.Width / 2) - [Math]::Floor($Message.Length / 2)))), $Message) }

function Get-GPS {   
        write-host $global:objNodes | format-table  
        foreach ($objNode in $global:objNodes){
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
        foreach ($objNode in $global:objNodes){
        ### Loop through nodes
                $objApiResult = $null
                $uri = $objnode.protocol + '://' + $objNode.ip + ':' + $objNode.port + '/api/session'
                try {$objApiResult = Invoke-RestMethod -Uri $uri -TimeoutSec 5}catch{}
                $uri = $objnode.protocol + '://' + $objNode.ip + ':' + $objNode.port + '/api/events'
                try {$objApiEventsResult = Invoke-RestMethod -Uri $uri -TimeoutSec 5}catch{}
                try {Invoke-RestMethod -Method Delete -Uri $uri -TimeoutSec 5}catch{}

                if ($objApiResult -eq $null){
                    $UpdateNode=$global:objNodes | Where-Object {$_.ip -eq $objNode.ip}
                    $updatenode.online = $false


                    } else {
                    
                    $UpdateNode=$global:objNodes | Where-Object {$_.ip -eq $objNode.ip}
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
                                    mac            = $ap.mac
                                    alias          = $ap.alias
                                    auth           = $ap.authentication
                                    channel        = $ap.channel
                                    cipher         = $ap.cipher
                                    clients        = $ap.clients.count
                                    clientsdetails = $ap.clients
                                    encryption     = $ap.encryption
                                    first_seen     = $ap.first_seen.Split("\.")[0]
                                    frequency      = $ap.frequency
                                    handshake      = $ap.handshake
                                    pmkid          = ""
                                    hostname       = $ap.hostname
                                    ipv4           = $ap.ipv4
                                    ipv6           = $ap.ipv6
                                    last_seen      = $ap.last_seen.Split("\.")[0]
                                    meta           = $ap.meta
                                    received       = $ap.received
                                    rssi           = $ap.rssi
                                    sent           = $ap.sent
                                    vendor         = $ap.vendor
                                    wps            = $ap.wps
                                    detectedby     = $objnode.ip + ':'+ $objnode.port 
                                    latitude       = $objGPS.latitude
                                    longitude      = $objGPS.Longitude
                                    rssigpsupdate  = $ap.rssi
                                }
                            #Clear-Variable objApiResult
                        #$global:objAPs += $objAP
                        }}


                ### Loop Trough all events
                foreach ($objEvent in $objApiEventsResult){
   
                        if ($objevent.tag -eq "wifi.client.handshake"){
        
                                if (($objevent | Select-Object -ExpandProperty data |select-object -ExpandProperty pmkid) -ne $null){
                                    $objPMKID = ($objevent | Select-Object -ExpandProperty data |select-object -ExpandProperty pmkid)
                                    $objPMKIDStation = ($objevent | Select-Object -ExpandProperty data |select-object -ExpandProperty station)
                                    $objPMKIDAP = ($objevent | Select-Object -ExpandProperty data |select-object -ExpandProperty ap)
                                    

                                        if (($global:objAPs) -and ($global:objAPs.mac.Contains($objPMKIDAP))){
                                        new-event "$((get-date).ToString("HH:mm:ss"))|$($objPMKIDAP)| PMKID captured" "black" "green"


                                        $UpdateAP=$global:objAPs | Where-Object {$_.mac -eq $objPMKIDAP}
                                        $UpdateAP.pmkid=$objPMKID




                                        }
                                }
                        }

                    #$objStation = $null
                    #$objPMKID = $null
    
                    }



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
       Write-host "nodes show    = show bettercap nodes"
       Write-host "nodes add     = add bettercap nodes"
       Write-host "nodes int     = Config bettercap node interface"
       Write-host "nodes channel = Config bettercap node channel"
       Write-host "nodes ttl     = Config bettercap node ttl"
       Write-host "nodes del     = del bettercap nodes"
       Write-host "nodes start   = start all bettercap nodes"
       Write-host "nodes stop    = stop all bettercap nodes"
       Write-host "show          = show networks"
       Write-host "start         = start session with the nodes"
       Write-host "help          = help"
       Write-host "exit          = quit"
    }
function command-nodes { 
    param ($a)
       if ($a -like "nodes show") {
            write-host $global:objNodes.count "Bettercap node(s) configured"
            write-host "----------"
            show-nodes
             }
       if ($a -like "nodes add") {add-node}
       if ($a -like "nodes del") {remove-node}
       if ($a -like "nodes int") {choose-nodeinterface}
       if ($a -like "nodes channel") {set-nodechannels}
       if ($a -like "nodes ttl") {set-nodettl}
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
function show-banner {
Write-Host "                                                                                   "
Write-Host "            ............................                                           "
Write-Host "          ╔▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓                                            "
Write-Host "          ▓▓▓▓▓▓▌   ▀▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓                                            "
Write-Host "         ▐▓▓▓▓▓▓▓▄    ▀▓▓▓▓╢███▓╢▓▓▓▓▓C                              ,,▄,          "
Write-Host "         ▓▓▓▓▓▓▓▓▓▓▄    ▓███▀▀▀████╢▓▓                            ▄███▀▀███▄       "
Write-Host "        ▐▓▓▓▓▓▓▓▓▓▓▓▓▄ ╒██▀░░▄▄▄░▀███        ,▄▄▄▄▄▄▄▄▄▄,       ▄██▀░▄▄▄▄░▀██      "
Write-Host "        ▓▓▓▓▓▓▓▓▓▓▓▓▓▓╜██░░░░░▀▀██░▀██  ▄▄█████▓▓▓▓▓▓▓██████▄, ██▀░▄██▀░░░░░██     "
Write-Host "       ▐▓▓▓▓▓▓▓▓▓▓▓▀   ██░░░░░░░▐███████▓▓████████ ▓▀▀█████▓▓█████▄█▌░░░░░░░██     "
Write-Host "       ▓▓▓▓▓▓▓▓▓▀   ,▄▓██░░░░░░▄███████████████▌▓∞²█╜▀██████████▓████▄░░░░░░██     "
Write-Host "      ▓▓▓▓▓▓▓▀   ,▄▓   ▐██░░░▄████████████████▓▓█▄▄▄▄██████████████████▄░░░██▀     "
Write-Host "      ▓▓▓▓▓▓▓,,▄▓▓▓▓▄▄╦▄▓██▄███▀▀███████████████████▓▓█████████▓████▀▀███╓██▀      "
Write-Host "     ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓╢████-     ▀▀▀▀██████████████████████▀▀▀'    `███▀        "
Write-Host "                            █▌  ████▄         ▐█░░░░░█▌         ▄███▄  ▐█          "
Write-Host "                           ▐█  ▐█████         ▐█░░░░░█⌐         █████   █▌         "
Write-Host "                           ██▌   ▀▀`          ▐█░░░░░█▌          ▀▀▀   ▐██         " 
Write-Host "                          ██▀█               ╓█░░░░░░╙█▄              ,█▌█▌        "
Write-Host "                          ██░▀█▄            ▄█⌡▄▄███▄▄░█▄            ▄█▀░▐█        "
Write-Host "                         ▐██░░░▀██▄,    ,▄██▀░██▓▓█▓██▌░▀██▄,    ,▄██▀░░░░█▌       "
Write-Host "                         ████▄░░░░▀▀▀▀▀▀▀▀⌠▄█████████████▄▌▀▀▀▀▀▀▀▀░░░░░▄██▌       "
Write-Host "                         ██▓█████▄▄▄▄▄▄██████▓████████▓▓██████▄▄▄▄▄▄▄████▓██       "
Write-Host "                         ██▓██▓▓▓█████▓▓▓███████████████████▓▓▓▓▓▓▓▓████████       "
Write-Host "                         █████████████▓▓▓████████████████████████████████▓██       "
Write-Host "                         █████████▓▓▓███████████████████████████████████████       "
Write-Host "                         ▀██████████████████████████████████████████████▓█▀        "
Write-Host "                           '▀████████████████▓▓▓▓▓▓██████████████▓▓██▀▀▀           "
Write-Host "                                       ``▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀"
Write-Host
Write-Host
Write-Host "   https://github.com/MelroyB/PSBettercap"}
function load-session {
    if (Test-Path -Path $Sessionfile) {
       write-host "Previous session found and imported - $Sessionfile" -ForegroundColor Green
       $global:objAPs = @(import-clixml $Sessionfile)
    
     } else {
        write-host "No previous session found" -ForegroundColor Green
        $global:objAPs = @()   
     }
}
function save-session {
$global:objAPs | export-clixml $Sessionfile -Force
}

function add-node{
    show-nodes

    $addNodeIP      = Read-Host -Prompt 'Hostname/IP'
    $addNodePort    = if(($result = Read-Host "REST API Port [8081]") -eq ''){"8081"}else{$result}
    $addNodeProt    = if(($result = Read-Host "HTTP or HTTPS [http]") -eq ''){"http"}else{$result}
    $addNodeChan    = if(($result = Read-Host "Channels to scan [all]") -eq ''){"all"}else{$result}
    $addNodeComment = Read-Host -Prompt 'Comment'
    $addNodeAPttl   = if(($result = Read-Host "AP TTL [300]") -eq ''){"300"}else{$result}
    $addNodeSTAttl  = if(($result = Read-Host "STA.TTL [300]") -eq ''){"300"}else{$result}


    $global:objNodes += new-object psobject -property @{
                                    "ip"       = $addNodeIP
                                    "port"     = $addNodePort
                                    "protocol" = $addNodeProt
                                    "channel"  = $addNodeChan
                                    "comment"  = $addNodeComment
                                    "online"   = ""
                                    "interface"= ""
                                    "ap.ttl"   = $addNodeAPttl
                                    "sta.ttl"  = $addNodeSTAttl
                                }
    save-nodes

}
function load-nodes {
        ### load node file
        if (Test-Path -Path $nodefile) {
           write-host "Previous nodes found and imported - $nodefile" -ForegroundColor Green
            
           $global:objNodes = @(import-clixml $nodefile)
    
         } else {
            write-host "No previous nodes found" -ForegroundColor Green
            $global:objNodes = @()   
         }
}
function save-nodes {
$global:objNodes | export-clixml $nodefile -Force
}
function remove-node{
$SelectNode = $null
$count = 0
    $global:objNodes | select-object ip,port,comment| ForEach-Object {
    $_ |  Select-Object @{Name = 'ID'; Expression = {$count}}, *
    $count++} | Format-Table -AutoSize
    $SelectNode = Read-Host -Prompt 'ID to remove'

    $global:objNodes= @($global:objNodes | where ({$_.port -ne $global:objNodes[$SelectNode].port -or $_.ip -ne $global:objNodes[$SelectNode].ip}))
    save-nodes
    load-nodes
}
function show-nodes{
($global:objNodes | format-table online,ip,port,interface,channel,comment,"ap.ttl","sta.ttl"| Format-Table  | Out-String).Trim()
}
function choose-nodeinterface{

                $SelectNode = $null
                $count = 0
                $global:objNodes | select-object ip,port,channel,interface,comment| ForEach-Object {
                    $_ |  Select-Object @{Name = 'ID'; Expression = {$count}}, *
                    $count++} | Format-Table -AutoSize

                    $SelectNode = Read-Host -Prompt 'ID to change interface'
                    $uri = $global:objNodes[$SelectNode].protocol + '://' + $global:objNodes[$SelectNode].ip + ':' + $global:objNodes[$SelectNode].port + '/api/session'

                    $objApiResult = $null
                    $objApiResult = Invoke-RestMethod -Uri $uri -TimeoutSec 5
                        
                         if ($objApiResult -eq $null){
                            
                            } else {
                            
                                 $selection = $objApiResult.interfaces #| Where-Object {$_.name -like "wl*"}
                            
                                If($selection.Count -gt 0){
                                    $title = "Interfaces"
                                    $message = "Which interface would you like to use?"

                                    # Build the choices menu
                                    $choices = @()
                                    For($index = 0; $index -lt $selection.Count; $index++){
                                        $choices += New-Object System.Management.Automation.Host.ChoiceDescription ($selection[$index]).Name, ($selection[$index]).FullName}

                                    $options = [System.Management.Automation.Host.ChoiceDescription[]]$choices
                                    $result = $host.ui.PromptForChoice($title, $message, $options, 0) 

                                    $UpdateNode=$global:objNodes | Where-Object {$_.ip -eq $global:objNodes[$SelectNode].ip} | Where-Object {$_.port -eq $global:objNodes[$SelectNode].port}
                                    $UpdateNode.interface = $selection[$result].name

                                    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
                                    $headers.Add("Content-Type", "application/json")
                                    try {Invoke-RestMethod -uri $uri -Method 'POST' -Headers $headers -Body "{`"cmd`": `"set wifi.interface $($updatenode.interface)`"}" -TimeoutSec 5}catch{write-host offline}
                                }

                             }

                    save-nodes

 
                   }
function set-nodechannels{


$SelectNode = $null
$count = 0
$global:objNodes | select-object ip,port,channel,interface,comment| ForEach-Object {
    $_ |  Select-Object @{Name = 'ID'; Expression = {$count}}, *
    $count++} | Format-Table -AutoSize

    $SelectNode = Read-Host -Prompt 'ID to change channel'

    $UpdateNode= $global:objNodes | where ({$_.port -eq $global:objNodes[$SelectNode].port -and $_.ip -eq $global:objNodes[$SelectNode].ip})
    $UpdateNode.channel =if(($result = Read-Host "Channels to scan [all]") -eq ''){"all"}else{$result}

    save-nodes

    ## send new config to node

    $uri = $global:objNodes[$selectnode].protocol + '://' + $global:objNodes[$selectnode].ip + ':' + $global:objNodes[$selectnode].port + '/api/session'
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/json")

    if ($UpdateNode.channel -eq "all"){
        Invoke-RestMethod -uri $uri -Method 'POST' -Headers $headers -Body "{`"cmd`": `"wifi.recon.channel clear`"}"
        } else {
        Invoke-RestMethod -uri $uri -Method 'POST' -Headers $headers -Body "{`"cmd`": `"wifi.recon.channel $($UpdateNode.channel)`"}"
        }


   }
function set-nodettl{


$SelectNode = $null
$count = 0
$global:objNodes | select-object ip,port,channel,interface,comment| ForEach-Object {
    $_ |  Select-Object @{Name = 'ID'; Expression = {$count}}, *
    $count++} | Format-Table -AutoSize

    $SelectNode = Read-Host -Prompt 'ID to change TTL'
        $UpdateNode= $global:objNodes | where ({$_.port -eq $global:objNodes[$SelectNode].port -and $_.ip -eq $global:objNodes[$SelectNode].ip})
    
    $updateNode.'ap.ttl'  = if(($result = Read-Host "AP TTL [300]") -eq ''){"300"}else{$result}
    $updateNode.'sta.ttl' = if(($result = Read-Host "STA.TTL [300]") -eq ''){"300"}else{$result}

    save-nodes

    ## send new config to node

    $uri = $global:objNodes[$selectnode].protocol + '://' + $global:objNodes[$selectnode].ip + ':' + $global:objNodes[$selectnode].port + '/api/session'
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/json")

        Invoke-RestMethod -uri $uri -Method 'POST' -Headers $headers -Body "{`"cmd`": `"set wifi.ap.ttl $($updateNode.'ap.ttl')`"}"
        Invoke-RestMethod -uri $uri -Method 'POST' -Headers $headers -Body "{`"cmd`": `"set wifi.sta.ttl $($updateNode.'sta.ttl')`"}"
     


   }
function Start-Nodes {
            $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $headers.Add("Content-Type", "application/json")
            foreach ($objNode in $global:objNodes){
                $uri = $objnode.protocol + '://' + $objNode.ip + ':' + $objNode.port + '/api/session'  
                      
               if ($objNode.channel -eq "all"){
                try {Invoke-RestMethod -uri $uri -Method 'POST' -Headers $headers -Body "{`"cmd`": `"wifi.recon.channel clear`"}"}catch{}
                } else {
                try {Invoke-RestMethod -uri $uri -Method 'POST' -Headers $headers -Body "{`"cmd`": `"wifi.recon.channel $($objNode.channel)`"}" -TimeoutSec 5}catch{}
                }             
                
                
                try {Invoke-RestMethod -uri $uri -Method 'POST' -Headers $headers -Body "{`"cmd`": `"set wifi.ap.ttl $($objNode.'ap.ttl')`"}" -TimeoutSec 5}catch{}
                try {Invoke-RestMethod -uri $uri -Method 'POST' -Headers $headers -Body "{`"cmd`": `"set wifi.sta.ttl $($objNode.'sta.ttl')`"}" -TimeoutSec 5}catch{}       
                try {Invoke-RestMethod -uri $uri -Method 'POST' -Headers $headers -Body "{`"cmd`": `"set wifi.interface $($objNode.interface)`"}" -TimeoutSec 5}catch{}
                try {Invoke-RestMethod -uri $uri -Method 'POST' -Headers $headers -Body "{`"cmd`": `"wifi.recon on`"}" -TimeoutSec 5}catch{}
          
                }
            }
function Stop-Nodes {
            $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $headers.Add("Content-Type", "application/json")
            foreach ($objNode in $global:objNodes){
                $uri = $objnode.protocol + '://' + $objNode.ip + ':' + $objNode.port + '/api/session' 
                Invoke-RestMethod -uri $uri -Method 'POST' -Headers $headers -Body "{`"cmd`": `"wifi.recon off`"}" -TimeoutSec 10
                }
            }
function PowerOff-Nodes {
            $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $headers.Add("Content-Type", "application/json")
            foreach ($objNode in $global:objNodes){
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
    # $Host.UI.RawUI.FlushInputBuffer()   # Werkt niet met linux 

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
    } }                      

    if (-not ($key -eq $null)) {Write-Host -NoNewLine "$($key.Character)"}
    if (![string]::IsNullOrEmpty($message)) {Write-Host "" # newline}       

    return $(if ($key -eq $null) {$null} else {$key.Character})
}}


show-banner
load-session
load-nodes


$continue = $true
while ($continue) {
    $prompt = Read-Host -Prompt '>'
    if ($prompt -eq "exit") {$continue = $false}
    if ($prompt -eq "show") {Show-BettercapAPs}
    if ($prompt -like "nodes*") {command-nodes $prompt}
    if ($prompt -eq "help") {show-help}

    if ($prompt -eq "start") {
        Write-host "Retrieving data, please wait..."
        $continue2 = $true
        while ($continue2) {
        Get-BettercapAPs
        #Clear-Host
        clear
        write-HostCenter "######## Last 20 APS ########"
        ($global:objAPs |Sort-Object -Property last_seen |select -last 20 | Format-table -Property last_seen,mac,hostname,channel,encryption,auth,handshake,pmkid,clients,detectedby| Format-Table)
        Write-HostCenter "########### Nodes ###########"
        show-nodes
        Write-HostCenter "########### Events ##########"
        show-events
        Write-HostCenter "#############################"
        Write-host $global:objAPs.count "Accesspoints / " -NoNewline
        Write-host $OBJgps.NumSatellites "GPS Sattelites"
        Write-host "press q to return to prompt " -NoNewline
        $key = GetKeyPress '[q]' "(q)?" 2
                    if ($key -eq "q"){$continue2 = $false}
        }  
    
    
    }
} 



# Exit
create-map
export-results
save-session
save-nodes


# TODO
# curl -X POST -F "email=SOME_VALID_EMAIL" -F "file=@/path/to/handshake.pcap" https://api.onlinehashcrack.com


