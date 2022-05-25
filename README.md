## Main Features
* Control multiple [Bettercap](https://github.com/bettercap/bettercap) nodes through REST API 
* Runs in Windows and Linux (pwsh)
* Change wifi adapter, channel(s), ttl per node
* Saves individual node settings
* Save GPS location with accesspoint
* Generate KML file 
* Generate csv File
* Save and resume sessions

## Todo
* REST API authentication (for now use no user /pass)
* Save handshakes central (for now they are saved local on the node)
* Cleanup code

## Node Configuration
run bettercap
set api.rest.address <ip or 0.0.0.0> (bind to all interfaces)
api.rest on

![nodes](https://github.com/MelroyB/PSBettercap/raw/main/screenshots/bettercap_node.png)

## Commands
### nodes show
Show configured nodes
![nodes show](https://github.com/MelroyB/PSBettercap/raw/main/screenshots/nodes_show.png)
### nodes add
Add a node
![nodes add](https://github.com/MelroyB/PSBettercap/raw/main/screenshots/nodes_add.png)
### nodes remove
Remove a node
### nodes int
Change node interface
![nodes del](https://github.com/MelroyB/PSBettercap/raw/main/screenshots/nodes_int.png)
### nodes ttl
Change node ttl settings
### nodes start
Send configuration (interface, channel, ttl) and start wifi.recon on node
### start
Start retrieving data from nodes
### exit
Saves session, Export CSV, Export KML and exit

