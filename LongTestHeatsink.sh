#!/bin/bash
# V0.9.3

#DEFINE FUNKTIONS ======================================================================
infotxt() {
 printf "RPi HeatSinkTest by TuxfeatMac / Tux_1024 - V 0.9.3\n"
}

# GET DATA  ============================================================================
gettemp() {
 TEMP=$(cat /sys/class/thermal/thermal_zone0/temp)
 TEMP=${TEMP#*=}
 TEMP=$(($TEMP/1000))
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
 if [ -f HTL.csv ]
  then
   printf "An old CSV exits. Delete it? y/n \n"
   read -n 1 -p ":" CONFIRM
   if [ "$CONFIRM" == "y" ]
    then
     rm HTL.csv >/dev/null 2>&1
     printf "\nDELETED OLD CSV\n"
    else
     printf "\nRENAME OLD CSV\n"
     exit
   fi
     printf "CREATE NEW CSV\n"
     TIMESTAMP=$(date)
     rm HTL.csv >/dev/null 2>&1
     printf "$TIMESTAMP" | paste >> HTL.csv
     printf "sec,tmp,clk,thr\n" | paste >> HTL.csv
 fi
}

endcsv() {
 TIMESTAMP=$(date)
 printf "WRITE END TIMESTAMP CSV\n"
 printf "$TIMESTAMP" | paste >> HTL.csv
}

prntcsv() {
 printf "%s,%s,%s,%s\n" $TIME $TEMP $CLOCK $THROT | paste >> HTL.csv
}

prntcli() {
 printf "%s\t%s\t%s\t%s\n" $TIME $TEMP $CLOCK $THROT
}

prntinfo() {
 printf "TIME\tTEMP\tCLOCK\tTHROT\n"
}

# RRD ===================================================================================
intrrd() {
# if [ -f heat.rrd ]
#  then
#   delete rrd if csv also deleted
 printf "DELETE OLD RRD\n"
 rm heat.rrd >/dev/null 2>&1
 printf "CREATE NEW RRD\n"
 rrdtool create heat.rrd --step 1 \
 DS:temp:GAUGE:2:0:100 \
 DS:clk:GAUGE:2:0:100 \
 DS:thro:GAUGE:2:0:100 \
 RRA:AVERAGE:0.8:1:1440 \
 RRA:MIN:0.8:1:1440 \
 RRA:MAX:0.8:1:1440
}

prntrrd() {
 #Variabelen anpassen fuer RRD
 THROT=$(($THROT*10))
 CLOCK=$(($CLOCK/100))
 #Debug Output
 #date
 #printf "%s\t%s\t%s\t%s\n" $TIME $TEMP $CLOCK $THROT
 #Update RRD
 rrdtool update heat.rrd N:$TEMP:$CLOCK:$THROT
}

graphrrd() {
 rrdtool graph heat.png \
 --end now \
 --start end-16m \
 --full-size-mode \
 --slope-mode \
 --width 1000 \
 --height 600 \
 --upper-limit 85 \
 --lower-limit 0 \
 --title "Long Heatsink Test - 1min IDLE | 10min STRESS | 4minCOOLDOWN" \
 DEF:temp=heat.rrd:temp:MAX \
 DEF:clk=heat.rrd:clk:MAX \
 DEF:thro=heat.rrd:thro:MAX \
 AREA:temp#03bd10:"Temperatur in °C" \
 GPRINT:temp:MIN:"Min=%2.0lf°C" \
 GPRINT:temp:MAX:"Max=%2.0lf°C\t" \
 AREA:clk#0223ca:"Clock in MHz x100" \
 GPRINT:clk:MIN:"Min=%.0lf00MHz" \
 GPRINT:clk:MAX:"Max=%.0lf00MHz\t" \
 AREA:thro#e11110:"Throttled = $WASTHROT @ ${THROTTIME}s x$THROTCOUNT" \
# VRULE:now-${THROTTIME}s#e11110
}

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
intcsv
intrrd

# WARMUP PHASE ==========================================================================
printf "IDLE DATA 1 MIN\n"
prntinfo
for ((TIME=0; TIME<60; TIME=TIME+1)); do
 getdata
 prntdata
 sleep 0.9 # compensate...
done

# STRESS PHASE ==========================================================================
printf "STRESS DATA 10 MIN\n"
startstress
prntinfo
for ((TIME=$TIME; TIME<660; TIME=TIME+1)); do
 getdata
 prntdata
 sleep 0.9 # compensate...
done
stopstress

# COOLDOWN PHASE ========================================================================
printf "COOL DOWN DATA 4 MIN\n"
prntinfo
for ((TIME=$TIME; TIME<900; TIME=TIME+1)); do
 getdata
 prntdata
 sleep 0.9 # compensate...
done

# GENERATE GRAPH =======================================================================
endcsv
printf "GENERATING GRAPH 20SEK\n"
sleep 15 # shift graph left..
graphrrd

#END MAIN ==============================================================================


#EOF ===================================================================================
