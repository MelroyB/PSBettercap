## Main Features
* Control multiple [Bettercap](https://github.com/bettercap/bettercap) nodes through REST API 
* Change wifi adapter or channel per node
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
### nodes int
Change node interface
![nodes del](https://github.com/MelroyB/PSBettercap/raw/main/screenshots/nodes_int.png)