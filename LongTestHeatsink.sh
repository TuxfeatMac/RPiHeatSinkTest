#!/bin/bash
#
VERSION='0.9.4'
#
# To Do List #
# [ ] Check inputs
# [ ]
#
# Features #
# [ ] more comments ?
# [ ] -d as $1 as debugfunktion ?
# [X] add HeatsinkName to Graph
# [ ] add Throthelcount to rrd / csv?
# [X] interactive timesettings for phases ?
# [ ] dynamic compenstae for cmd execution time to improve accuracy ?
# [ ] V2.0 with data every 15s ?
#

#DEFINE FUNKTIONS ======================================================================
infotxt() {
 printf "RPi HeatSinkTest by Joachim Träuble V$VERSION\n"
}
# GET USER INPUT  ======================================================================
sethsname() {
 read -p "HeatSinkName?:" HSNAME
}
setstresstime() {
 read -p "Stres Test Duration ? in seconds:" STRESSTIME
}
setidletime() {
 read -p "Idle Time ? in seconds:" IDLETIME
}
setcooltime() {
 read -p "Dynamic Cooldown time until reaching Ideletemps again ? y/n:" CONFIRM
 if [ "$CONFIRM" == "n" ]
  then
   read -p "Cooldown Time ? in seconds:" COOLTIME
 fi
}
# GET DATA  ============================================================================
getcooltime() {
 COOLTIME=$(($TESTTIME-$STRESSTIME-$IDLETIME))
}
gettesttime() {
 COLUMS=$(tail -n 2 $HSNAME.csv | cut -d ',' -f 1 | head -n 1)
 TESTTIME=$(($COLUMS+1))
}
gettemp() {
 TEMP=$(cat /sys/class/thermal/thermal_zone0/temp)
 TEMP=${TEMP#*=}
 TEMP=$(($TEMP/1000))
}
getidletemp() {
 OFFSET=$(($IDLETIME + 2))
printf "$OFFSET $IDLETIME\n"
 SUM=$(head -n $OFFSET $HSNAME.csv | cut -d ',' -f 2 | tail -n $IDLETIME | awk '{ SUM += $1} END { print SUM }')
 IDLETEMP=$(($SUM / $IDLETIME))
# printf "SUM: $SUM\n"
 printf "IDLETEMP: $IDLETEMP\n"
}
getclock() {
 CLOCK=$(vcgencmd measure_clock arm)
 CLOCK=${CLOCK#*=}
 CLOCK=$(($CLOCK/1000000))
}
getthrot() {
 THROT=$(vcgencmd get_throttled)
 THROT=${THROT#*=}
}
chkthrot() {
case $THROT in
 0x0)
	THROT=0
	WASTHROT="NO";;
 0x20000)
	THROT=0
	WASTHROT="YES"
	if [ "$THROTTIME" == "" ]; then
	 THROTTIME=$(($TIME-60)) #must match MAIN idle time
	fi
	printf "!%s %s reboot required!\n" $WASTHROT $THROTTIME;;
 0x20002)
	THROT=1
        THROTCOUNT=$(($THROTCOUNT+1))
	printf "!Throtteling  BAD HEATSINK! - ThrCount: $THROTCOUNT\n";;
 *)
	printf "%s unset debug pls\n" $THROT;;
esac
}

# STRESS =================================================================================
stopstress() {
 killall sysbench > /dev/null 2>&1
}
startstress() {
 printf "START CPU STRESS TEST\n"
 sysbench --num-threads=4 --test=cpu --cpu-max-prime=1000000000 --max-time=1200 run > /dev/null 2>&1 &
}
onkill() {
# if [ ]
  echo "Killing sysbench.."
  sudo killall sysbench
#  echo "graphing heat.png.."
#  graprrd generate graph no mater what not working
}

# CSV ===================================================================================
intcsv() {
 if [ -f "$HSNAME.csv" ]
  then
   printf "An old CSV exits. Delete it? y/n \n"
   read -n 1 -p ":" CONFIRM
   if [ "$CONFIRM" == "y" ]
    then
     rm $HSNAME.csv >/dev/null 2>&1
     printf "\nDELETED OLD CSV\n"
    else
     printf "\nRENAME OLD CSV\n"
     exit
   fi
 fi
 printf "CREATE NEW CSV\n"
 TIMESTAMP=$(date)
 printf "$TIMESTAMP" | paste >> $HSNAME.csv
 printf "sec,tmp,clk,thr\n" | paste >> $HSNAME.csv
}

endcsv() {
 TIMESTAMP=$(date)
 printf "WRITE END TIMESTAMP CSV\n"
 printf "$TIMESTAMP" | paste >> $HSNAME.csv
}

prntcsv() {
 printf "%s,%s,%s,%s\n" $TIME $TEMP $CLOCK $THROT | paste >> $HSNAME.csv
}

prntcli() {
 printf "%s\t%s\t%s\t%s\n" $TIME $TEMP $CLOCK $THROT
}

prntinfo() {
 printf "TIME\tTEMP\tCLOCK\tTHROT\n"
}

# RRD ===================================================================================
intrrd() {
# if [ -f $HSNAME.rrd ]
#  then
#   delete rrd if csv also deleted
 printf "DELETE OLD RRD\n"
 rm $HSNAME.rrd >/dev/null 2>&1
 printf "CREATE NEW RRD\n"
 rrdtool create $HSNAME.rrd --step 1 \
 DS:temp:GAUGE:2:0:100 \
 DS:clk:GAUGE:2:0:100 \
 DS:thro:GAUGE:2:0:100 \
 RRA:AVERAGE:0.8:1:3600 \
 RRA:MIN:0.8:1:3600 \
 RRA:MAX:0.8:1:3600
}
prntrrd() {
 #Variabelen anpassen fuer RRD
 THROT=$(($THROT*10))
 CLOCK=$(($CLOCK/100))
 #Debug Output
 #date
 #printf "%s\t%s\t%s\t%s\n" $TIME $TEMP $CLOCK $THROT
 #Update RRD
 rrdtool update $HSNAME.rrd N:$TEMP:$CLOCK:$THROT
}
graphrrd() {
 rrdtool graph $HSNAME.png \
 --end now-1s\
 --start end-${TESTTIME}s+1s \
 --full-size-mode \
 --slope-mode \
 --width 1000 \
 --height 600 \
 --upper-limit 85 \
 --lower-limit 0 \
 --title "Heatsink Test   -> $HSNAME <-   ${IDLETIME}s IDLE | ${STRESSTIME}s STRESS | ${COOLTIME}s COOLDOWN | ${TESTTIME}s TOTAL" \
 DEF:temp=$HSNAME.rrd:temp:MAX \
 DEF:clk=$HSNAME.rrd:clk:MAX \
 DEF:thro=$HSNAME.rrd:thro:MAX \
 AREA:temp#03bd10:"Temp in °C    Idle=$IDLETEMP°C" \
 GPRINT:temp:MIN:"Min=%2.0lf°C" \
 GPRINT:temp:MAX:"Max=%2.0lf°C   " \
 AREA:clk#0223ca:"Clock in MHz x100" \
 GPRINT:clk:MIN:"Min=%.0lf00MHz" \
 GPRINT:clk:MAX:"Max=%.0lf00MHz   " \
 AREA:thro#e11110:"Throttled = $WASTHROT @ ${THROTTIME}s x${THROTCOUNT}"
# VRULE:now-${THROTTIME}s#e11110
}

# COMBINE  ==============================================================================
getdata() {
 gettemp
 getclock
 getthrot
 chkthrot
}

prntdata() {
 prntcli
 prntcsv
 prntrrd
}
#END FUNCTIONS ==========================================================================


#MAIN ===================================================================================
trap onkill EXIT
clear
infotxt
sethsname
setidletime
setstresstime
setcooltime
intcsv
intrrd

# WARMUP PHASE ==========================================================================
printf "IDLE DATA FOR: ${IDLETIME}s\n"
prntinfo
for ((TIME=0; TIME<$IDLETIME; TIME=TIME+1)); do
 getdata
 prntdata
 sleep 0.9 # compensate...
done
getidletemp

# STRESS PHASE ==========================================================================
printf "STRESS DATA FOR: ${STRESSTIME}s\n"
prntinfo
startstress
for ((TIME=$TIME; TIME<$STRESSTIME+$IDLETIME; TIME=TIME+1)); do
 getdata
 prntdata
 sleep 0.9 # compensate...
done
stopstress

# COOLDOWN PHASE ========================================================================
prntinfo
if [ "$COOLTIME" == "" ]
 then
  printf "COOL DOWN DATA DYNAMIC TILL ${IDLETEMP}°C\n"
  for ((TIME=$TIME; $TEMP>$IDLETEMP; TIME=TIME+1)); do
   getdata
   prntdata
   sleep 0.9 # compensate...
  done
  endcsv
  gettesttime
  getcooltime
 else
  printf "COOL DOWN DATA FOR: ${COOLTIME}s\n"
  for ((TIME=$TIME; TIME<$COOLTIME+$STRESSTIME+$IDLETIME; TIME=TIME+1)); do
   getdata
   prntdata
   sleep 0.9 # compensate...
  done
  endcsv
  gettesttime
fi

# GENERATE GRAPH =======================================================================
printf "GENERATING GRAPH\n"
graphrrd

#END MAIN ==============================================================================


#EOF ===================================================================================
