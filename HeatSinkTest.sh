#!/bin/bash
VERSION='0.9.6'

#DEFINE FUNKTIONS ======================================================================
infotxt() {
 printf "\nRPi HeatSinkTest by Joachim Träuble V$VERSION\n\n"
}

# GET USER INPUT  ======================================================================
sethsname() {
 read -p "HeatSinkName ?                            : " HSNAME
 case $HSNAME in
  "")
   HSNAME="DEFAULT";;
 esac
}

setidletime() {
 read -p "Up Front Idle Time ?     in seconds  [40] : " IDLETIME
 case $IDLETIME in
  "")
   IDLETIME="40";;
  "*")
   printf "\ninvalid input\n"
   exit;;
  [0-9])
   printf "\nminimum 10\n"
   exit;;
  [0-9][0-9][0-9][0-9]);;
 esac
}

setstresstime() {
 read -p "Stress Test Time ?       in seconds [600] : " STRESSTIME
 case $STRESSTIME in
  "")
   STRESSTIME="600";;
  "*")
   printf "\ninvalid input\n"
   exit;;
  [0-9])
   printf "\nminimum 10\n"
   exit;;
  [0-9][0-9][0-9][0-9]);;
 esac
}

setcooltime() {
 read -p "Cooldown Time ? in seconds dynamic=d [60] : " COOLTIME
 case $COOLTIME in
  "")
   COOLTIME="60";;
  "*")
   printf "\ninvalid input\n"
   exit;;
  [0-9])
   printf "\nminimum 10\n"
   exit;;
  [0-9][0-9][0-9][0-9]);;
 esac
}

# EXIT CLEANUP ROUTINE  ===============================================================
onkill() {
 printf "\nQUITING HEATSINKTEST...\n"
 SYSBENCH=$(pgrep sysbench)
 if [ "$SYSBENCH" != "" ]
  then
   printf "KILLING SYSBENCH...\n"
   sudo killall sysbench
 fi
 if [ -f $HSNAME.png ]
  then
   printf "ALL DONE, BYE...\n"
  else
   endcsv
   gettesttime
   graphrrd
   printf "FINALY DONE, BYE...\n"
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
 SUM=$(head -n $OFFSET $HSNAME.csv | cut -d ',' -f 2 | tail -n $IDLETIME | awk '{ SUM += $1} END { print SUM }')
 IDLETEMP=$(($SUM / $IDLETIME))
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
	 THROTTIME=$(($TIME-$IDLETIME)) ##
         THROTHVRULE=$(date +%s)
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
 sysbench --num-threads=4 --test=cpu --cpu-max-prime=1000000000 --max-time=3600 run > /dev/null 2>&1 &
}

# CONSOLE =====================================================================
prntcli() {
 printf "%s\t%s\t%s\t%s\n" $TIME $TEMP $CLOCK $THROT
}
prntinfo() {
 printf "TIME\tTEMP\tCLOCK\tTHROT\n"
}

# CSV ===================================================================================
intcsv() {
 if [ -f "$HSNAME.csv" ]
  then
   read -p "An PNG / CSV / RRD exits! Delete ?  y / n : " CONFIRM
   if [ "$CONFIRM" == "y" ]
    then
     rm $HSNAME.png >/dev/null 2>&1
     printf "\nDELETED OLD PNG\n"
     rm $HSNAME.csv >/dev/null 2>&1
     printf "DELETED OLD CSV\n"
    else
     printf "\nRENAME OLD CSV / RRD...\n"
     exit
   fi
 fi
 printf "CREATE NEW CSV\n"
 TIMESTAMP=$(date)
# STARTTIME=$(date +%m-%d-%Y%H:%M:%S)
 STARTTIME=$(date +%s)
 printf "$TIMESTAMP" | paste >> $HSNAME.csv
 printf "sec,tmp,clk,thr\n" | paste >> $HSNAME.csv
}
endcsv() {
 if [ -f "$HSNAME.csv" ]
  then
   TIMESTAMP=$(date)
   ENDTIME=$(date +%s)
   printf "WRITE END TIMESTAMP CSV\n"
   printf "$TIMESTAMP" | paste >> $HSNAME.csv
 fi
}
prntcsv() {
 printf "%s,%s,%s,%s\n" $TIME $TEMP $CLOCK $THROT | paste >> $HSNAME.csv
}

# RRD ===================================================================================
intrrd() {
 if [ "$CONFIRM" == "y" ]
  then
   printf "DELETE OLD RRD\n"
   rm $HSNAME.rrd >/dev/null 2>&1
 fi
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
 #convert vars for RRD
 THROT=$(($THROT*10))
 CLOCK=$(($CLOCK/100))
 #printf "%s\t%s\t%s\t%s\n" $TIME $TEMP $CLOCK $THROT
 rrdtool update $HSNAME.rrd N:$TEMP:$CLOCK:$THROT
}
graphrrd() {
 if [ "$THROTHVRULE" == "" ]
  then
   THROTHVRULE=0
 fi
 printf "GENERATING GRAPH\n"
 rrdtool graph $HSNAME.png \
 --end $ENDTIME-1s \
 --start $STARTTIME+1s \
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
 AREA:thro#e11110:"Throttled = $WASTHROT @ ${THROTTIME}s x${THROTCOUNT}" \
 HRULE:80#e11110 \
 VRULE:$THROTHVRULE#e11110
}

# COMBINE  ==============================================================================
setvars() {
 sethsname
 setidletime
 setstresstime
 setcooltime
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
infotxt
trap onkill EXIT
setvars
intcsv
intrrd

# WARMUP PHASE ==========================================================================
printf "\nIDLE DATA FOR: ${IDLETIME}s\n"
prntinfo
for ((TIME=0; TIME<$IDLETIME; TIME=TIME+1)); do
 getdata
 prntdata
 sleep 0.89 # compensate...
done
getidletemp

# STRESS PHASE ==========================================================================
printf "STRESS DATA FOR: ${STRESSTIME}s\n"
prntinfo
startstress
for ((TIME=$TIME; TIME<$STRESSTIME+$IDLETIME; TIME=TIME+1)); do
 getdata
 prntdata
 sleep 0.88 # compensate...
done
stopstress

# COOLDOWN PHASE ========================================================================
prntinfo
if [ "$COOLTIME" == "d" ]
 then # Dynamic
  printf "COOL DOWN DATA DYNAMIC TILL ${IDLETEMP}°C\n"
  for ((TIME=$TIME; $TEMP>$IDLETEMP; TIME=TIME+1)); do
   getdata
   prntdata
   sleep 0.89 # compensate...
  done
  endcsv
  gettesttime
  getcooltime
 else # SetTime
  printf "COOL DOWN DATA FOR: ${COOLTIME}s\n"
  for ((TIME=$TIME; TIME<$COOLTIME+$STRESSTIME+$IDLETIME; TIME=TIME+1)); do
   getdata
   prntdata
   sleep 0.89 # compensate...
  done
  endcsv
  gettesttime
fi

# GENERATE GRAPH =======================================================================
graphrrd
#END MAIN ==============================================================================


#EOF ===================================================================================
