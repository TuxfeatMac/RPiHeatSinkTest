Raspberry Pi 4 - Heat Sink Test - V0.9.6

Runs a Stresstest via Sysbench on all 4 cores to generate heat on the SoC.
Measures the RPi SoC temperature and checks for CPU throttling every second.

Features
[X] set coustum idle|stress|cool timings
[X] generate a CSV file containing: Step, Time, Temp, Freq
[X] generate a RRD DataBase containing: Temp, Freq, Thro
[X] output graph as PNG with rrdtools
[ ]

Dependencies
- vcgencmd, rrdtool, sysbench
- sudo apt update && sudo apt upgrade && sudo apt install rrdtool sysbench

Install
- git clone https://github.com/TuxfeatMac/RPiHeatSinkTest
- chmod +x HeatSinkTest.sh

Run
- ./HeatSinkTest.sh
- hit x4 times ENTER for default name/settings 60|600|60

Add Features 
[ ] more comments ?
[ ] add time to csv
[ ] false input protection ?
[ ] add ThrotheCount to rrd / csv ?
[ ] -d as $1 as debugfunktion ?
[ ] V2.0 with data every 15s ?
[ ] dynamic compenstae for cmd execution time to improve accuracy ?
[ ] ad an one wire sensor for environment temp ?
[ ] detect cpu core count automaticali for copmatibility
