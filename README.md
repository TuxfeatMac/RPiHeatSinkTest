Raspberry Pi 4 - Heat Sink Test - V0.9.3

- measures the RPi SoC temperature every minute
- checks for CPU throttling
- generate a CSV file with CPU Temp, Freq, Time, 
- generate a RRD Database 
- generate a graph as PNG with rrdtools
- duration 15 minutes

Dependencies
- vcgencmd
- rrdtool
- sysbench
sudo apt update && sudo apt upgrade
sudo apt install rrdtool sysbench


Add Features 
[ ] more comments ?
[ ] -d as $1 as debugfunktion ?
[ ] add HeatsinkName to Graph ?
[ ] add ThrotheCount to rrd / csv ?
[ ] interactive timesettings for phases ?
[ ] dynamic compenstae for cmd execution time to improve accuracy ?
[ ] V2.0 with data every 15s ?


