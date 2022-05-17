# $DebugPreference = 'SilentlyContinue'
$DebugPreference = 'Continue'

$objGPS
$objAP = @()
$global:objAPs = @()
 $objNodes = @()
 #$objNodes += New-Object PSObject -property @{
 #                                   ip="192.168.188.128"
 #                                   port="8081"
 #                                   protocol="http"
 #                                   channel="all"
 #                                   comment="comment node 1"
 #                               }
 $objNodes += new-object psobject -property @{
                                    ip="192.168.137.14"
                                    port="8081"
                                    protocol="http"
                                    channel="6"
                                    comment="comment node 2"
                                }


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
function Start-Nodes {
            $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $headers.Add("Content-Type", "application/json")
            foreach ($objNode in $objNodes){
                $uri = $objnode.protocol + '://' + $objNode.ip + ':' + $objNode.port + '/api/session'  
                Invoke-RestMethod -uri $uri -Method 'POST' -Headers $headers -Body "{`"cmd`": `"wifi.recon on`"}" -TimeoutSec 5
                }
            }
function set-nodechannels{
### all channels
            $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $headers.Add("Content-Type", "application/json")
            foreach ($objNode in $objNodes){
                $nodeChannel = $objNodes.channel
                $uri = $objnode.protocol + '://' + $objNode.ip + ':' + $objNode.port + '/api/session' 
                Invoke-RestMethod -uri $uri -Method 'POST' -Headers $headers -Body "{`"cmd`": `"wifi.recon.channel $nodeChannel`"}" -TimeoutSec 5
                $nodeChannel = $null
                }
            }
function Stop-Nodes {
            $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $headers.Add("Content-Type", "application/json")
            foreach ($objNode in $objNodes){
                $uri = $objnode.protocol + '://' + $objNode.ip + ':' + $objNode.port + '/api/session' 
                Invoke-RestMethod -uri $uri -Method 'POST' -Headers $headers -Body "{`"cmd`": `"wifi.recon off`"}" -TimeoutSec 5
                }
            }
function Get-GPS {   
        write-host $objnodes | format-table  
        foreach ($objNode in $objNodes){
                $uri = $objnode.protocol + '://' + $objNode.ip + ':' + $objNode.port + '/api/session'
                
                $uri
                
                
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
                $uri = $objnode.protocol + '://' + $objNode.ip + ':' + $objNode.port + '/api/session'
                $objApiResult = Invoke-RestMethod -Uri $uri -TimeoutSec 5
                
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
                            $UpdateAP=$global:objAPs | where {$_.mac -eq $ap.mac}
                            $UpdateAP.last_seen=$ap.last_seen.Split("\.")[0]
                            $UpdateAP.handshake=$ap.handshake
                            $UpdateAP.detectedby=$objnode.ip + ':' +  $objnode.port
                            $UpdateAP.received=$ap.received
                            $UpdateAP.sent=$ap.sent
                            $UpdateAP.clients=$ap.clients.count
                            ###write-host $ap.mac "signaal" $ap.rssi "was eerder" $updateAp.rssi

                          ### Check if AP signal is better before update GPS location
                                 if ($updateAP.rssigpsupdate -lt $ap.rssi){
                                        Write-host $ap.mac "Meer bereik,GPS geupdate bij " $updateAP.rssigpsupdate  " nu " $ap.rssi
                                        $updateAP.latitude=$objGPS.latitude
                                        $updateAP.longitude=$objGPS.Longitude
                                        $updateAP.rssigpsupdate=$ap.rssi
                                        $updateAp.rssi=$ap.rssi 
                                       }else{

                                       ###Write-host $ap.mac "Minder bereik, GPS geupdate bij " $updateAP.rssigpsupdate  " nu " $ap.rssi
                                        $updateAp.rssi=$ap.rssi

}
                                  }else {
                                    Write-host $ap.mac $ap.hostname "nieuw gevonden"                
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
                                    latitude = $null
                                    longitude = $null
                                    rssigpsupdate= -1000
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
            $objNodes | Format-Table ip,port,protocol, comment
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
             $objNodes = $objNodes  | Where-Object { $_ -ne $delNodes    }
       if ($a -like "nodes start") {Start-Nodes}
       if ($a -like "nodes stop") {Stop-Nodes}
    }}
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


### Commandprompt loop

### Export
### Create map
### handshakes
### Nodes del

$continue = $true
$continue2 = $true
while ($continue) {
    $prompt = Read-Host -Prompt '>'
    if ($prompt -eq "q") {$continue = $false}
    if ($prompt -eq "show") {Show-BettercapAPs}
    if ($prompt -like "nodes*") {command-nodes $prompt}
    if ($prompt -eq "help") {show-help}

    if ($prompt -eq "start") {
        do {
        
        clear
        $global:objAPs | Format-table -Property last_seen,mac,hostname,channel,encryption,auth,handshake,clients,detectedby
        Get-BettercapAPs
        Write-host "-----------------------"
        Write-host $global:objAPs.count "Accesspoints"
        Write-host $OBJgps.NumSatellites "GPS Sattelites"
        Write-host "press key to cancel"
        sleep 5
        } until ([System.Console]::KeyAvailable) 
    
    }



} 

## save log at exit

#Convert to CSV

##
create-map
export-results

