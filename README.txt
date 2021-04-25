Raspberry Pi 4 - Heat Sink Test - V0.9.5

- measures the RPi SoC temperature every second
- checks for CPU throttling
- generate a CSV file with CPU Temp, Freq, Time, 
- generate a RRD Database
- generate a graph as PNG with rrdtools
- duration variable, dynamic, adjustable

Run
- ./LongTestHeatsink.sh

Dependencies
- vcgencmd, rrdtool, sysbench
- sudo apt update && sudo apt upgrade && sudo apt install rrdtool sysbench

Install
- git clone https://github.com/TuxfeatMac/RPiHeatSinkTest
- chmod +x LongTestHeatsink.sh

Add Features 
[ ] more comments ?
[ ] false input protection ?
[ ] -d as $1 as debugfunktion ?
[X] add HeatsinkName to Graph ?
[ ] add ThrotheCount to rrd / csv ?
[X] interactive timesettings for phases ?
[X] automatic timesettings back to idle temps ?
[ ] dynamic compenstae for cmd execution time to improve accuracy ?
[ ] V2.0 with data every 15s ?
[ ] 
[ ] 
