#!/bin/sh
#version 3.1.0

#Zip code is parsed from command line. If no zip, we'll do all the ones in the array. If
#from the command line, format is getweather.sh 12345 67890 for as many as you like.

#Set Options Here--------------------------------------------------------------------------------------------------------
weatherdir="/Users/majorsl/Scripts/GitHub/weather/weather/" #root of this script.
weatherfeeddir="/Users/majorsl/Scripts/GitHub/weather/weather/weatherfeeds/" #temp storage of weather feeds.
weatherdatadir="/Users/majorsl/Scripts/GitHub/weather/weather/weatherdata/" #where the output txt files for the html goes.
weatherimagedir="/Users/majorsl/Scripts/GitHub/weather/weather/weatherimages/" #location of weather widgets.
wkhtmltoimagedir="/usr/local/bin/" #location of wkhtmltoimage binary.
wgetdir="/usr/local/bin/" #location of wget binary.
wundergroundapi="/Users/majorsl/Scripts/wundergroundapi.txt" #location of your wunderground api.
terminalnotifier="/Applications/" #location of terminal-notifier.app.
#-------------------------------------------------------------------------------------------------------------------------

if [ "$#" -eq 0 ]; then
  echo "**Exiting, please provide zipcode(s) for processing.**"
  "$terminalnotifier"terminal-notifier.app/Contents/MacOS/terminal-notifier -title 'Weather Update' -message "Failed, please provide zipcode(s) for processing." -contentImage "$weatherimagedir"weather"$ZIPCODE".jpg
else
  arr=("$@")
fi

for ZIPCODE in "${arr[@]}"
do

"$terminalnotifier"terminal-notifier.app/Contents/MacOS/terminal-notifier -title 'Weather Update' -message "Processing $ZIPCODE." -contentImage "$weatherimagedir"weather"$ZIPCODE".jpg

#Get time for sunrise/set comparison and date for special icons.
TIME=`date +%H%M`
DATE=`date +%m%d`

#Get data from wunderground.com.
API=$(cat "$wundergroundapi")
cd "$weatherfeeddir"
"$wgetdir"wget -O weatherfeed$ZIPCODE.json -q --timestamping "http://api.wunderground.com/api/$API/conditions/astronomy/forecast7day/alerts/almanac/hourly/q/$ZIPCODE.json"

#Check for zero or little data from the json file and abort if it's too small or 0 bytes, we'll try again at the next interval.
SIZE=`ls -s weatherfeed$ZIPCODE.json | cut -d " " -f1`
if [ "$SIZE" -lt "9" ]; then
	echo "**$ZIPCODE - Bad weather data or no network connection. Will try again at next interval.**"
	"$terminalnotifier"terminal-notifier.app/Contents/MacOS/terminal-notifier -title 'Weather Update' -message "$ZIPCODE Failed. Bad calendar data or no network connection. Will try again at next interval." -contentImage /Users/majorsl/Sites/weather/weatherimages/weather"$ZIPCODE".jpg
	exit
fi

ECHO "**$ZIPCODE - Feed retrieved. Beginning data processing.**"

#Load weather data to single variable.
WeatherFile="weatherfeed$ZIPCODE.json"
WeatherData=""
WeatherData=`cat $WeatherFile`

#Change to weather directory and extract data.
cd "$weatherdir"

#Current Conditions/Temp - round current temp to nearest int with awk. Pretty current condition. Make hyphen nowrap character &#8209;
CURRENTCOND=`echo "$WeatherData" | grep -e '"weather"' | sed 's/.*\:"//' | cut -d '"' -f1 | sed 's/and/\&/'`
CURRENTTEMP=`echo "$WeatherData" | grep -e '"temp_f"' | sed 's/.*\://' | cut -d ',' -f1 | sed 's/$//' | awk '{print int($1+0.5)}'`
if [ "$CURRENTTEMP" = "-0" ]; then
	CURRENTTEMP="0"
fi
CURRENTTEMP=`echo "$CURRENTTEMP" | sed 's/-/\&#8209;/'`

#Output Conditions & Pretty up some strings without altering original data. There is an Unknown that pops-up sometimes. This keeps the last set until it goes away.
CURRENTCONDITIONPRETTY=`echo $CURRENTCOND | sed 's/ mist/ \& mist/' | sed 's/ fog/ \& fog/'`

if [ "$CURRENTCONDITIONPRETTY" != "Unknown" ] || [ "$CURRENTCONDITIONPRETTY" != "" ]; then
		ECHO "$CURRENTTEMP&deg" > "$weatherdatadir"currenttemp.txt
		ECHO "$CURRENTCONDITIONPRETTY" > "$weatherdatadir"currentcondition.txt
fi

#Feels Like: First, look for windchill and use that, then heat index and use that, then current temp.
WINDCHILL=`echo "$WeatherData" | grep -e '"windchill_f"' | sed 's/.*\://' | cut -d ',' -f1 | sed 's/"//g'`
HEATINDEX=`echo "$WeatherData" | grep -e '"heat_index_f"' | sed 's/.*\://' | cut -d ',' -f1 | sed 's/"//g'`

FEELLIKE="$CURRENTTEMP"
if [ "$WINDCHILL" != "NA" ]; then
	FEELLIKE="$WINDCHILL"
elif [ "$HEATINDEX" != "NA" ]; then
	FEELLIKE="$HEATINDEX"
fi

#Feels Like - color font at 100+ degrees, italics for below 0.
FEELCOLOR=""
FEELCOLOR2=""
if [ "$FEELLIKE" -gt "99" ]; then
	FEELCOLOR="<font color=orange>"
elif [ "$FEELLIKE" -gt "104" ]; then
	FEELCOLOR="<font color=yellow>"
elif [ "$FEELLIKE" -lt "1" ]; then
	FEELCOLOR="<i>"
	FEELCOLOR2="</i>"
fi
ECHO "$FEELCOLOR""Feels Like: ""$FEELLIKE""&deg""$FEELCOLOR2" > "$weatherdatadir"feelslike.txt

#Moon
MOONICON=`echo "$WeatherData" | grep -e '"ageOfMoon"' | sed 's/.*\:"//' | cut -d '"' -f1 | sed 's/and/\&/'`

#Sunrise/Set
SUNSETHR=`echo "$WeatherData" | grep -e '"sunset"' -A1 | tail -n 1 | sed 's/.*\:"//' | cut -d '"' -f1`
SUNSETHRSTD=`expr $SUNSETHR - "12"`
SUNSETMIN=`echo "$WeatherData" | grep -e '"sunset"' -A2 | tail -n 1 | sed 's/.*\:"//' | cut -d '"' -f1`
SUNSET="$SUNSETHRSTD:$SUNSETMIN PM"

SUNRISEHR=`echo "$WeatherData" | grep -e '"sunrise"' -A1 | tail -n 1 | sed 's/.*\:"//' | cut -d '"' -f1`
SUNRISEMIN=`echo "$WeatherData" | grep -e '"sunrise"' -A2 | tail -n 1 | sed 's/.*\:"//' | cut -d '"' -f1`
SUNRISE="$SUNRISEHR:$SUNRISEMIN AM"

SUNSETNUM=`echo $SUNSET | sed -e 's/://' | cut -d " " -f1`
SUNSETMIL="$SUNSETHR$SUNSETMIN"
SUNRISENUM="$SUNRISEHR$SUNRISEMIN"

#Check for after 2pm which puts "Today" grid into "Tonight" mode.
NA=""
if [ "$TIME" -gt "1400" ]; then
	NA="NAFound"
fi

#Forcast & character count for smaller font. NA determines Forecast data, switching to night forecast afer 2pm.
PERIOD=0
FORECASTTITLE=`echo "$WeatherData" | grep -m 2 '"period":0' -A3 | sed 's/.*\:"//' | tail -n 1 | cut -d '"' -f1`
FORECAST=`echo "$WeatherData" | grep -m 2 '"period":0' -A4 | sed 's/.*\:"//' | tail -n 1 | cut -d '"' -f1 | sed 's/ percent/%/' | sed 's/thunderstorm/Tstorm/g' | sed 's/ mph/mph/g' | sed 's/rainfall/rain/g' | sed 's/southwest/SW/g' | sed 's/Southwest/SW/g' |sed 's/southeast/SE/g' | sed 's/northwest/NW/g' | sed 's/Northwest/NW/g' | sed 's/northeast/NE/g' | sed 's/midnight/12/g' | sed 's/with gusts up to/gusting to/g' | sed 's/Gusts up to/Gusts to/g' | sed 's/Northeast/NE/g' | sed 's/Southeast/SE/g' | sed 's/zero/0/g'`
if [ "$NA" = "NAFound" ]; then
	PERIOD=1
	FORECASTTITLE=`echo "$WeatherData" | grep -m 2 '"forecast":{' -A 18 | sed 's/.*\:"//' | tail -n 1 | cut -d '"' -f1`
	FORECAST=`echo "$WeatherData" | grep -m 2 '"forecast":{' -A 19 | sed 's/.*\:"//' | tail -n 1 | cut -d '"' -f1 | sed 's/ percent/%/' | sed 's/thunderstorm/Tstorm/g' | sed 's/ mph/mph/g' | sed 's/rainfall/rain/g' | sed 's/southwest/SW/g' | sed 's/Southwest/SW/g' |sed 's/southeast/SE/g' | sed 's/northwest/NW/g' | sed 's/Northwest/NW/g' | sed 's/northeast/NE/g' | sed 's/midnight/12/g' | sed 's/with gusts up to/gusting to/g' | sed 's/Gusts up to/Gusts to/g' | sed 's/Northeast/NE/g' | sed 's/Southeast/SE/g' | sed 's/zero/0/g'`
fi

l2=`echo $FORECAST | wc -m | tr -d ' '`
#error out if little or no forecast data, probably a malformed json file. Else, adjust forcast font size.
if [ "$l2" -lt "10" ]; then
	echo "**$ZIPCODE - Bad weather data or no network connection. Will try again at next interval.**"
	"$terminalnotifier"terminal-notifier.app/Contents/MacOS/terminal-notifier -title 'Weather Update' -message "$ZIPCODE Failed. Bad calendar data or no network connection. Will try again at next interval." -contentImage "$weatherimagedir"weather"$ZIPCODE".jpg
	exit
fi
if [ "$l2" -gt "100" ] && [ "$l2" -lt "154" ]; then
	FORECAST='<div class="forecast2">'$FORECAST'</div>'
fi
if [ "$l2" -gt "153" ]; then
	FORECAST='<div class="forecast3">'$FORECAST'</div>'
fi

#Big Weather Icon
BIGICON="$CURRENTCOND"
if [ "$TIME" -gt "$SUNSETMIL" ] || [ "$TIME" -lt "$SUNRISENUM" ]; then
	NIGHTICON="night"
fi

#Humidity
TODAYHUMID=`echo "$WeatherData" | grep -e '"relative_humidity"' | sed 's/.*\:"//' | cut -d '%' -f1`

#Visibility
TODAYVIS=`echo "$WeatherData" | grep -e '"visibility_mi"' | sed 's/.*\:"//' | cut -d '"' -f1`

#UV
TODAYUV=`echo "$WeatherData" | grep -e '"UV"' | sed 's/.*\:"//' | cut -d '"' -f1`

#Offset is the number of lines for data between days. When the source adds new items, this increases on occasion. IPOINT is the first day line number to start the offset.
OFFSET=74

#Mini Icon Names
IPOINT=29
IDAY0=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\:"//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET
IDAY1=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\:"//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET
IDAY2=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\:"//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET
IDAY3=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\:"//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET
IDAY4=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\:"//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET
IDAY5=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\:"//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET
IDAY6=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\:"//' | cut -d '"' -f1`

#Days
IPOINT=14
DDAY0=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\:"//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET
DDAY1=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\:"//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET
DDAY2=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\:"//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET
DDAY3=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\:"//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET
DDAY4=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\:"//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET
DDAY5=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\:"//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET
DDAY6=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\:"//' | cut -d '"' -f1`

#Highs
IPOINT=22
HDAY0=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\:"//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET
HDAY1=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\:"//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET
HDAY2=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\:"//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET
HDAY3=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\:"//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET
HDAY4=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\:"//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET
HDAY5=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\:"//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET
HDAY6=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\:"//' | cut -d '"' -f1`

HDAY0=`echo "$HDAY0" | sed 's/-/\&#8209;/'`
HDAY1=`echo "$HDAY1" | sed 's/-/\&#8209;/'`
HDAY2=`echo "$HDAY2" | sed 's/-/\&#8209;/'`
HDAY3=`echo "$HDAY3" | sed 's/-/\&#8209;/'`
HDAY4=`echo "$HDAY4" | sed 's/-/\&#8209;/'`
HDAY5=`echo "$HDAY5" | sed 's/-/\&#8209;/'`
HDAY6=`echo "$HDAY6" | sed 's/-/\&#8209;/'`

#Lows
IPOINT=26
LDAY0=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\:"//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET
LDAY1=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\:"//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET
LDAY2=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\:"//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET
LDAY3=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\:"//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET
LDAY4=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\:"//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET
LDAY5=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\:"//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET
LDAY6=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\:"//' | cut -d '"' -f1`

LDAY0=`echo "$LDAY0" | sed 's/-/\&#8209;/'`
LDAY1=`echo "$LDAY1" | sed 's/-/\&#8209;/'`
LDAY2=`echo "$LDAY2" | sed 's/-/\&#8209;/'`
LDAY3=`echo "$LDAY3" | sed 's/-/\&#8209;/'`
LDAY4=`echo "$LDAY4" | sed 's/-/\&#8209;/'`
LDAY5=`echo "$LDAY5" | sed 's/-/\&#8209;/'`
LDAY6=`echo "$LDAY6" | sed 's/-/\&#8209;/'`

#Possibility of Precip
IPOINT=33
PDAY0=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\"://' | cut -d ',' -f1`
let IPOINT=$IPOINT+$OFFSET
PDAY1=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\"://' | cut -d ',' -f1`
let IPOINT=$IPOINT+$OFFSET
PDAY2=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\"://' | cut -d ',' -f1`
let IPOINT=$IPOINT+$OFFSET
PDAY3=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\"://' | cut -d ',' -f1`
let IPOINT=$IPOINT+$OFFSET
PDAY4=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\"://' | cut -d ',' -f1`
let IPOINT=$IPOINT+$OFFSET
PDAY5=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\"://' | cut -d ',' -f1`
let IPOINT=$IPOINT+$OFFSET
PDAY6=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\"://' | cut -d ',' -f1`

#Average Humidity
IPOINT=70
HUDAY0=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\": //' | cut -d ',' -f1`
let IPOINT=$IPOINT+$OFFSET
HUDAY1=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\": //' | cut -d ',' -f1`
let IPOINT=$IPOINT+$OFFSET
HUDAY2=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\": //' | cut -d ',' -f1`
let IPOINT=$IPOINT+$OFFSET
HUDAY3=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\": //' | cut -d ',' -f1`
let IPOINT=$IPOINT+$OFFSET
HUDAY4=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\": //' | cut -d ',' -f1`
let IPOINT=$IPOINT+$OFFSET
HUDAY5=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\": //' | cut -d ',' -f1`
let IPOINT=$IPOINT+$OFFSET
HUDAY6=`echo "$WeatherData" | grep -m3 '"forecastday":' -A $IPOINT | tail -n 1 | sed 's/.*\": //' | cut -d ',' -f1`

#Wind right now, round wind speed to nearest mph with awk.
DAYWIND=`echo "$WeatherData" | grep -e '"wind_mph"' | sed 's/.*\://' | cut -d ',' -f1 | awk '{print int($1+0.5)}'`"mph"
DAYWINDIR=`echo "$WeatherData" | grep -e '"wind_dir"' | sed 's/.*\:"//' | cut -d '"' -f1`
DAYWINDGUST=`echo "$WeatherData" | grep -e '"wind_gust_mph"' | sed 's/.*\://' | cut -d ',' -f1 | sed 's/"//g' | awk '{print int($1+0.5)}'`

if [ "$DAYWIND" = "0mph" ]; then
	DAYWIND=""
	DAYWINDIR="Calm"
	DAYWINDGUST="0"
fi

#Trying to keep the widget wind to 2 lines, if we have no Gusts, then use spelled out compass points.
if [ "$DAYWINDGUST" = "0" ]; then
	if [ "$DAYWINDIR" = "WSW" ]; then
		DAYWINDIR="West-Southwest"
	fi
	if [ "$DAYWINDIR" = "NW" ]; then
		DAYWINDIR="Northwest"
	fi
	if [ "$DAYWINDIR" = "NE" ]; then
		DAYWINDIR="Northeast"
	fi
	if [ "$DAYWINDIR" = "SW" ]; then
		DAYWINDIR="Southwest"
	fi
	if [ "$DAYWINDIR" = "SE" ]; then
		DAYWINDIR="Southeast"
	fi
	if [ "$DAYWINDIR" = "NNW" ]; then
		DAYWINDIR="North-Northwest"
	fi
	if [ "$DAYWINDIR" = "SSE" ]; then
		DAYWINDIR="South-Southeast"
	fi
	if [ "$DAYWINDIR" = "SSW" ]; then
		DAYWINDIR="South-Southwest"
	fi
	if [ "$DAYWINDIR" = "NNE" ]; then
		DAYWINDIR="North-Northeast"
	fi
	if [ "$DAYWINDIR" = "ENE" ]; then
		DAYWINDIR="East-Northeast"
	fi
	if [ "$DAYWINDIR" = "East-Southeast" ]; then
		DAYWINDIR="East-SE"
	fi
	if [ "$DAYWINDIR" = "WNW" ]; then
		DAYWINDIR="West-Northwest"
	fi
fi

#Windgust fun, formatting for table in weather widget. Check the number of characters in the string.
if [ "$DAYWINDGUST" = "0" ] || [ "$DAYWINDIR" = "Calm" ]; then
	DAYGUST=""
else
	DAYGUST=" <i>Gusting ""$DAYWINDGUST""mph</i>"
fi

WINDCOUNT="$DAYWINDIR $DAYWIND$DAYGUST"
WINDNOW="$WINDCOUNT"

#Hourly forecast: OFFSET2 is the number of lines for data between hours. When the source adds new items, this increases on occasion. IPOINT is the first day line number to start the offset.
OFFSET2=25

#Hour
IPOINT=3
HOUR0=`echo "$WeatherData" | grep -m3 '"hourly_forecast":' -A $IPOINT | tail -n 1 | cut -c 12-15 | cut -d '"' -f1`
HOUR0MIL="$HOUR0""00"
NIGHTICON0=""
MOONTIME0="empty"
if [ "$HOUR0MIL" -gt "$SUNSETMIL" ] || [ "$HOUR0MIL" -lt "$SUNRISENUM" ]; then
	NIGHTICON0="night"
	MOONTIME0="$MOONICON"
fi
let IPOINT=$IPOINT+$OFFSET2
#
HOUR1=`echo "$WeatherData" | grep -m3 '"hourly_forecast":' -A $IPOINT | tail -n 1 | cut -c 12-15 | cut -d '"' -f1`
HOUR1MIL="$HOUR1""00"
NIGHTICON1=""
MOONTIME1="empty"
if [ "$HOUR1MIL" -gt "$SUNSETMIL" ] || [ "$HOUR1MIL" -lt "$SUNRISENUM" ]; then
	NIGHTICON1="night"
	MOONTIME1="$MOONICON"
fi
let IPOINT=$IPOINT+$OFFSET2
#
HOUR2=`echo "$WeatherData" | grep -m3 '"hourly_forecast":' -A $IPOINT | tail -n 1 | cut -c 12-15 | cut -d '"' -f1`
HOUR2MIL="$HOUR2""00"
NIGHTICON2=""
MOONTIME2="empty"
if [ "$HOUR2MIL" -gt "$SUNSETMIL" ] || [ "$HOUR2MIL" -lt "$SUNRISENUM" ]; then
	NIGHTICON2="night"
	MOONTIME2="$MOONICON"
fi
let IPOINT=$IPOINT+$OFFSET2
#
HOUR3=`echo "$WeatherData" | grep -m3 '"hourly_forecast":' -A $IPOINT | tail -n 1 | cut -c 12-15 | cut -d '"' -f1`
HOUR3MIL="$HOUR3""00"
NIGHTICON3=""
MOONTIME3="empty"
if [ "$HOUR3MIL" -gt "$SUNSETMIL" ] || [ "$HOUR3MIL" -lt "$SUNRISENUM" ]; then
	NIGHTICON3="night"
	MOONTIME3="$MOONICON"
fi
let IPOINT=$IPOINT+$OFFSET2
#
HOUR4=`echo "$WeatherData" | grep -m3 '"hourly_forecast":' -A $IPOINT | tail -n 1 | cut -c 12-15 | cut -d '"' -f1`
HOUR4MIL="$HOUR4""00"
NIGHTICON4=""
MOONTIME4="empty"
if [ "$HOUR4MIL" -gt "$SUNSETMIL" ] || [ "$HOUR4MIL" -lt "$SUNRISENUM" ]; then
	NIGHTICON4="night"
	MOONTIME4="$MOONICON"
fi
let IPOINT=$IPOINT+$OFFSET2
#
HOUR5=`echo "$WeatherData" | grep -m3 '"hourly_forecast":' -A $IPOINT | tail -n 1 | cut -c 12-15 | cut -d '"' -f1`
HOUR5MIL="$HOUR5""00"
NIGHTICON5=""
MOONTIME5="empty"
if [ "$HOUR5MIL" -gt "$SUNSETMIL" ] || [ "$HOUR5MIL" -lt "$SUNRISENUM" ]; then
	NIGHTICON5="night"
	MOONTIME5="$MOONICON"
fi
let IPOINT=$IPOINT+$OFFSET2
#
HOUR6=`echo "$WeatherData" | grep -m3 '"hourly_forecast":' -A $IPOINT | tail -n 1 | cut -c 12-15 | cut -d '"' -f1`
HOUR6MIL="$HOUR6""00"
NIGHTICON6=""
MOONTIME6="empty"
if [ "$HOUR6MIL" -gt "$SUNSETMIL" ] || [ "$HOUR6MIL" -lt "$SUNRISENUM" ]; then
	NIGHTICON6="night"
	MOONTIME6="$MOONICON"
fi
let IPOINT=$IPOINT+$OFFSET2
#
HOUR7=`echo "$WeatherData" | grep -m3 '"hourly_forecast":' -A $IPOINT | tail -n 1 | cut -c 12-15 | cut -d '"' -f1`
HOUR7MIL="$HOUR7""00"
NIGHTICON7=""
MOONTIME7="empty"
if [ "$HOUR7MIL" -gt "$SUNSETMIL" ] || [ "$HOUR7MIL" -lt "$SUNRISENUM" ]; then
	NIGHTICON7="night"
	MOONTIME7="$MOONICON"
fi
let IPOINT=$IPOINT+$OFFSET2
#
HOUR8=`echo "$WeatherData" | grep -m3 '"hourly_forecast":' -A $IPOINT | tail -n 1 | cut -c 12-15 | cut -d '"' -f1`
HOUR8MIL="$HOUR8""00"
NIGHTICON8=""
MOONTIME8="empty"
if [ "$HOUR8MIL" -gt "$SUNSETMIL" ] || [ "$HOUR8MIL" -lt "$SUNRISENUM" ]; then
	NIGHTICON8="night"
	MOONTIME8="$MOONICON"
fi
let IPOINT=$IPOINT+$OFFSET2
#
HOUR9=`echo "$WeatherData" | grep -m3 '"hourly_forecast":' -A $IPOINT | tail -n 1 | cut -c 12-15 | cut -d '"' -f1`
HOUR9MIL="$HOUR9""00"
NIGHTICON9=""
MOONTIME9="empty"
if [ "$HOUR9MIL" -gt "$SUNSETMIL" ] || [ "$HOUR9MIL" -lt "$SUNRISENUM" ]; then
	NIGHTICON9="night"
	MOONTIME9="$MOONICON"
fi

declare -a HOURS
HOURS=( $HOUR0  $HOUR1 $HOUR2 $HOUR3 $HOUR4 $HOUR5 $HOUR6 $HOUR7 $HOUR8 $HOUR9 )

#Sort out am/pm for each hour.
x=0
while [ $x -lt 10 ]
do
if [ "${HOURS[${x}]}" -gt "12" ]; then
	let HOURS[$x]=HOURS[$x]-12
	HOURS[$x]="${HOURS[${x}]}""pm"
else
	HOURS[$x]="${HOURS[${x}]}""am"
fi
if [ "${HOURS[${x}]}" = "12am" ]; then
	HOURS[$x]="12pm"
fi
if [ "${HOURS[${x}]}" = "0am" ]; then
	HOURS[$x]="12am"
fi
let x=$x+1
done

#Hour Temps
IPOINT=5
TEMPHOUR0=`echo "$WeatherData" | grep -m3 '"hourly_forecast":' -A $IPOINT | tail -n 1 | cut -c 24-27 | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET2
TEMPHOUR1=`echo "$WeatherData" | grep -m3 '"hourly_forecast":' -A $IPOINT | tail -n 1 | cut -c 24-27 | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET2
TEMPHOUR2=`echo "$WeatherData" | grep -m3 '"hourly_forecast":' -A $IPOINT | tail -n 1 | cut -c 24-27 | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET2
TEMPHOUR3=`echo "$WeatherData" | grep -m3 '"hourly_forecast":' -A $IPOINT | tail -n 1 | cut -c 24-27 | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET2
TEMPHOUR4=`echo "$WeatherData" | grep -m3 '"hourly_forecast":' -A $IPOINT | tail -n 1 | cut -c 24-27 | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET2
TEMPHOUR5=`echo "$WeatherData" | grep -m3 '"hourly_forecast":' -A $IPOINT | tail -n 1 | cut -c 24-27 | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET2
TEMPHOUR6=`echo "$WeatherData" | grep -m3 '"hourly_forecast":' -A $IPOINT | tail -n 1 | cut -c 24-27 | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET2
TEMPHOUR7=`echo "$WeatherData" | grep -m3 '"hourly_forecast":' -A $IPOINT | tail -n 1 | cut -c 24-27 | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET2
TEMPHOUR8=`echo "$WeatherData" | grep -m3 '"hourly_forecast":' -A $IPOINT | tail -n 1 | cut -c 24-27 | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET2
TEMPHOUR9=`echo "$WeatherData" | grep -m3 '"hourly_forecast":' -A $IPOINT | tail -n 1 | cut -c 24-27 | cut -d '"' -f1`

#Hour Icons
IPOINT=7
ICONHOUR0=`echo "$WeatherData" | grep -m3 '"hourly_forecast":' -A $IPOINT | tail -n 1 | sed 's/.*\: "//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET2
ICONHOUR1=`echo "$WeatherData" | grep -m3 '"hourly_forecast":' -A $IPOINT | tail -n 1 | sed 's/.*\: "//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET2
ICONHOUR2=`echo "$WeatherData" | grep -m3 '"hourly_forecast":' -A $IPOINT | tail -n 1 | sed 's/.*\: "//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET2
ICONHOUR3=`echo "$WeatherData" | grep -m3 '"hourly_forecast":' -A $IPOINT | tail -n 1 | sed 's/.*\: "//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET2
ICONHOUR4=`echo "$WeatherData" | grep -m3 '"hourly_forecast":' -A $IPOINT | tail -n 1 | sed 's/.*\: "//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET2
ICONHOUR5=`echo "$WeatherData" | grep -m3 '"hourly_forecast":' -A $IPOINT | tail -n 1 | sed 's/.*\: "//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET2
ICONHOUR6=`echo "$WeatherData" | grep -m3 '"hourly_forecast":' -A $IPOINT | tail -n 1 | sed 's/.*\: "//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET2
ICONHOUR7=`echo "$WeatherData" | grep -m3 '"hourly_forecast":' -A $IPOINT | tail -n 1 | sed 's/.*\: "//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET2
ICONHOUR8=`echo "$WeatherData" | grep -m3 '"hourly_forecast":' -A $IPOINT | tail -n 1 | sed 's/.*\: "//' | cut -d '"' -f1`
let IPOINT=$IPOINT+$OFFSET2
ICONHOUR9=`echo "$WeatherData" | grep -m3 '"hourly_forecast":' -A $IPOINT | tail -n 1 | sed 's/.*\: "//' | cut -d '"' -f1`

#Set Moonsize icon based on sunrise/set and stars on the backgrounds as well as backgrounds. DAYNIGHT controls the symlink to the backgrounds.
MOONPHASEDIR="moonphasessm"
DAYNIGHTSIG="blogweatherblue.css"
DAYNIGHT="weatherblue.css"

#Time variables for backgrounds
SUNSETPLUSONE=`expr $SUNSETMIL + "100"`
SUNRISEMINUSONE=`expr $SUNRISENUM - "100"`

#Lets try a grey background for overcast/fog days at daytime.
if [ "$CURRENTCOND" = "Overcast" ]; then
	DAYNIGHT="weathergrey.css"
	DAYNIGHTSIG="blogweathergrey.css"
fi
if [ "$CURRENTCOND" = "Fog" ]; then
	DAYNIGHT="weathergrey.css"
	DAYNIGHTSIG="blogweathergrey.css"
fi


if [ "$CURRENTCOND" = "Clear" ]; then
	DAYNIGHT="weatherbluebright.css"
	DAYNIGHTSIG="blogweatherbluebright.css"
fi

#Set twilight backgrounds TDB
if [ "$TIME" -gt "$SUNSETMIL" ]; then
	MOONPHASEDIR="moonphases"
	DAYNIGHTSIG="blogweatherbluestars.css"
	DAYNIGHT="weatherbluestars.css"
fi
if [ "$TIME" -lt "$SUNRISENUM" ]; then
	MOONPHASEDIR="moonphases"
	DAYNIGHTSIG="blogweatherbluestars.css"
	DAYNIGHT="weatherbluestars.css"
fi

#Set night-time star backgrounds.
if [ "$TIME" -gt "$SUNSETPLUSONE" ]; then
	MOONPHASEDIR="moonphases"
	DAYNIGHTSIG="blogweatherblack.css"
	DAYNIGHT="weatherblack.css"
fi
if [ "$TIME" -lt "$SUNRISEMINUSONE" ]; then
	MOONPHASEDIR="moonphases"
	DAYNIGHTSIG="blogweatherblack.css"
	DAYNIGHT="weatherblack.css"
fi

#Output for css customization
cd "$weatherdir"
ln -sf "$DAYNIGHT" weather.css
ln -sf "$DAYNIGHTSIG" blogweather.css

#Output Text Data
cd "$weatherdir"

#Highs - From up top, if != NAFound then we're NOT after 2pm and retain the high today number.  Else, see below.
if [ "$NA" != "NAFound" ]; then
	ECHO -n "$HDAY0""&deg" > "$weatherdatadir"highday0.txt
fi
ECHO -n "$HDAY1""&deg" > "$weatherdatadir"highday1.txt
ECHO -n "$HDAY2""&deg" > "$weatherdatadir"highday2.txt
ECHO -n "$HDAY3""&deg" > "$weatherdatadir"highday3.txt
ECHO -n "$HDAY4""&deg" > "$weatherdatadir"highday4.txt
ECHO -n "$HDAY5""&deg" > "$weatherdatadir"highday5.txt
ECHO -n "$HDAY6""&deg" > "$weatherdatadir"highday6.txt

#Lows
ECHO -n "$LDAY0""&deg" > "$weatherdatadir"lowday0.txt
ECHO -n "$LDAY1""&deg" > "$weatherdatadir"lowday1.txt
ECHO -n "$LDAY2""&deg" > "$weatherdatadir"lowday2.txt
ECHO -n "$LDAY3""&deg" > "$weatherdatadir"lowday3.txt
ECHO -n "$LDAY4""&deg" > "$weatherdatadir"lowday4.txt
ECHO -n "$LDAY5""&deg" > "$weatherdatadir"lowday5.txt
ECHO -n "$LDAY6""&deg" > "$weatherdatadir"lowday6.txt

#Today/Tonight Change-Overs
#(enable below for actual day, non relative & disable the static "Today".)
#ECHO "$DDAY0" > day0.txt
DDAY0="Today"

#NAFound from up top means we're in night mode and the Tonight icon gets a night icon w/mini moon background instead of the empty.png, High is the current temp with down-arrow "&#8595" indicating dropping, we turn off displaying sunrise & UV (Sunrise & UV is on for the new grid), and DAY0HUMID changes to TONIGHTHUMID.
DISPLAYMOONPHASE=""
MOONICON2="empty"
NAICON=""
if [ "$NA" = "NAFound" ]; then
	DDAY0="Tonight"
	ECHO -n "$CURRENTTEMP""&deg" > "$weatherdatadir"highday0.txt
	MOONICON2="$MOONICON"
	NAICON="night"
fi

#Output forecast data
ECHO -n "$FORECAST" > "$weatherdatadir"forecasttoday.txt
ECHO -n "$FORECASTTITLE" > "$weatherdatadir"forecasttitle.txt
if [ "$TODAYVIS" != "N/A" ]; then
	ECHO -n "$TODAYVIS" > "$weatherdatadir"visibilitynow.txt
fi
ECHO -n "$TODAYUV" > "$weatherdatadir"uvnow.txt
ECHO -n "$WINDNOW" > "$weatherdatadir"windnow.txt
#ECHO -n "$DAYGUST" > "$weatherdatadir"windgustnow.txt
ECHO -n "$SUNRISE" > "$weatherdatadir"sunrise.txt
ECHO -n "$SUNSET" > "$weatherdatadir"sunset.txt
#ECHO -n "$MOONPHASE" > "$weatherdatadir"moonphase.txt

ECHO -n "$DDAY0" > "$weatherdatadir"day0.txt
ECHO -n "$DDAY1" > "$weatherdatadir"day1.txt
ECHO -n "$DDAY2" > "$weatherdatadir"day2.txt
ECHO -n "$DDAY3" > "$weatherdatadir"day3.txt
ECHO -n "$DDAY4" > "$weatherdatadir"day4.txt
ECHO -n "$DDAY5" > "$weatherdatadir"day5.txt
ECHO -n "$DDAY6" > "$weatherdatadir"day6.txt

ECHO -n "&#9730;""$PDAY0" > "$weatherdatadir"pop0.txt
ECHO -n "&#9730;""$PDAY1" > "$weatherdatadir"pop1.txt
ECHO -n "&#9730;""$PDAY2" > "$weatherdatadir"pop2.txt
ECHO -n "&#9730;""$PDAY3" > "$weatherdatadir"pop3.txt
ECHO -n "&#9730;""$PDAY4" > "$weatherdatadir"pop4.txt
ECHO -n "&#9730;""$PDAY5" > "$weatherdatadir"pop5.txt
ECHO -n "&#9730;""$PDAY6" > "$weatherdatadir"pop6.txt

#Output Humidity, with error checking. Keep the previous data if its wrong.
if [ "$TODAYHUMID" -gt "0" ] && [ "$TODAYHUMID" -lt "101" ]; then
	ECHO -n "&#8776;""$TODAYHUMID" > "$weatherdatadir"humiditynow.txt
fi
ECHO -n "&#8776;""$HUDAY0" > "$weatherdatadir"humid0.txt
ECHO -n "&#8776;""$HUDAY1" > "$weatherdatadir"humid1.txt
ECHO -n "&#8776;""$HUDAY2" > "$weatherdatadir"humid2.txt
ECHO -n "&#8776;""$HUDAY3" > "$weatherdatadir"humid3.txt
ECHO -n "&#8776;""$HUDAY4" > "$weatherdatadir"humid4.txt
ECHO -n "&#8776;""$HUDAY5" > "$weatherdatadir"humid5.txt
ECHO -n "&#8776;""$HUDAY6" > "$weatherdatadir"humid6.txt

#Set small weather icons.
cd "$weatherdir"weathericonssm
ln -sf "$IDAY0""$NAICON".png day0.png
ln -sf "$IDAY1".png day1.png
ln -sf "$IDAY2".png day2.png
ln -sf "$IDAY3".png day3.png
ln -sf "$IDAY4".png day4.png
ln -sf "$IDAY5".png day5.png
ln -sf "$IDAY6".png day6.png

ln -sf "$ICONHOUR0""$NIGHTICON0".png iconhour0.png
ln -sf "$ICONHOUR1""$NIGHTICON1".png iconhour1.png
ln -sf "$ICONHOUR2""$NIGHTICON2".png iconhour2.png
ln -sf "$ICONHOUR3""$NIGHTICON3".png iconhour3.png
ln -sf "$ICONHOUR4""$NIGHTICON4".png iconhour4.png
ln -sf "$ICONHOUR5""$NIGHTICON5".png iconhour5.png
ln -sf "$ICONHOUR6""$NIGHTICON6".png iconhour6.png
ln -sf "$ICONHOUR7""$NIGHTICON7".png iconhour7.png
ln -sf "$ICONHOUR8""$NIGHTICON8".png iconhour8.png
ln -sf "$ICONHOUR9""$NIGHTICON9".png iconhour9.png

#Set hourly hours.
ECHO -n ${HOURS[0]} > "$weatherdatadir"hour0.txt
ECHO -n ${HOURS[1]} > "$weatherdatadir"hour1.txt
ECHO -n ${HOURS[2]} > "$weatherdatadir"hour2.txt
ECHO -n ${HOURS[3]} > "$weatherdatadir"hour3.txt
ECHO -n ${HOURS[4]} > "$weatherdatadir"hour4.txt
ECHO -n ${HOURS[5]} > "$weatherdatadir"hour5.txt
ECHO -n ${HOURS[6]} > "$weatherdatadir"hour6.txt
ECHO -n ${HOURS[7]} > "$weatherdatadir"hour7.txt
ECHO -n ${HOURS[8]} > "$weatherdatadir"hour8.txt
ECHO -n ${HOURS[9]} > "$weatherdatadir"hour9.txt

#Set hourly temps.
ECHO -n "$TEMPHOUR0""&deg" > "$weatherdatadir"temphour0.txt
ECHO -n "$TEMPHOUR1""&deg" > "$weatherdatadir"temphour1.txt
ECHO -n "$TEMPHOUR2""&deg" > "$weatherdatadir"temphour2.txt
ECHO -n "$TEMPHOUR3""&deg" > "$weatherdatadir"temphour3.txt
ECHO -n "$TEMPHOUR4""&deg" > "$weatherdatadir"temphour4.txt
ECHO -n "$TEMPHOUR5""&deg" > "$weatherdatadir"temphour5.txt
ECHO -n "$TEMPHOUR6""&deg" > "$weatherdatadir"temphour6.txt
ECHO -n "$TEMPHOUR7""&deg" > "$weatherdatadir"temphour7.txt
ECHO -n "$TEMPHOUR8""&deg" > "$weatherdatadir"temphour8.txt
ECHO -n "$TEMPHOUR9""&deg" > "$weatherdatadir"temphour9.txt

#Set large weather icon, error check if the large current condition icon is Unknown then lets use the icon for today, if that icon is Unknown also, keep the last known one until the next interval check.
if [ "$BIGICON" = "Unknown" ]; then
	BIGICON="$IDAY0"
	ECHO "**Big icon flipped to daily.**"
fi
if [ "$BIGICON" != "Unknown" ]; then
	cd "$weatherdir"weathericons
	ln -sf "$BIGICON""$NIGHTICON".png weather.png
	/usr/local/bin/setlabel Blue weather.png
fi

#Set moonphase icon.
cd "$weatherdir"moonphasessm
ln -sf "$MOONICON".png phase.png
cd "$weatherdir"moonphases
ln -sf "$MOONICON".png phase.png
cd "$weatherdir"
ln -sf "$MOONPHASEDIR/$MOONICON".png phase.png
cd "$weatherdir"moonphasesexsm
ln -sf "$MOONICON2".png phase.png

#moonphases for time line.
ln -sf "$MOONTIME0".png timephase0.png
ln -sf "$MOONTIME1".png timephase1.png
ln -sf "$MOONTIME2".png timephase2.png
ln -sf "$MOONTIME3".png timephase3.png
ln -sf "$MOONTIME4".png timephase4.png
ln -sf "$MOONTIME5".png timephase5.png
ln -sf "$MOONTIME6".png timephase6.png
ln -sf "$MOONTIME7".png timephase7.png
ln -sf "$MOONTIME8".png timephase8.png
ln -sf "$MOONTIME9".png timephase9.png

#Set any specials events e.g. Christmas.
cd "$weatherdir"images

if [ "$DATE" = "1224" ] || [ "$DATE" = "1225" ]; then
	ln -sf santa.png eventabove.png
fi
if [ "$DATE" = "0101" ]; then
	ln -sf newyears.png eventbelow.png
fi
if [ "$DATE" = "0510" ] || [ "$DATE" = "0517" ] || [ "$DATE" = "0717" ] || [ "$DATE" = "0709" ]; then
	ln -sf balloons.png eventabove.png
fi
if [ "$DATE" = "0704" ]; then
	ln -sf fireworks.png eventabove.png
fi
if [ "$DATE" = "1031" ]; then
	ln -sf ghost.png eventabove.png
fi
if [ "$DATE" = "1101" ] || [ "$DATE" = "0718" ] || [ "$DATE" = "0705" ] || [ "$DATE" = "0518" ] || [ "$DATE" = "0710" ] || [ "$DATE" = "0511" ] || [ "$DATE" = "0102" ] || [ "$DATE" = "1226" ]; then
	ln -sf empty.png eventabove.png
	ln -sf empty.png eventbelow.png
fi
	
#Weather Warnings
cd "$weatherdir"

WARNING=" - "`echo "$WeatherData" | grep -m 3 '"alerts"' -A3 | sed 's/.*\: "//' | tail -n 1 | cut -d '"' -f1`

#If warnings equal one of these, there might be an additional statement title in the next block we should use.
if [ "$WARNING" = " - Special Statement" ] || [ "$WARNING" = " - Special Weather Statement" ]; then
	WARNING=" - "`echo "$WeatherData" | grep -m 2 '"alerts"' -A15 | sed 's/.*\: "//' | tail -n 1 | cut -d '"' -f1`
fi

#Check the string length of the warning. Less than 5 means garbage or no warning in string or we've failed over to the Special Statement string and it's not correct e.g. passes - KMSS.
l2=`echo $WARNING | wc -m`
if [ "$l2" -lt "8" ]; then
	WARNING=""
fi

#Shorten some long strings/remove irrelevant warnings
if [ "$WARNING" = " - Severe Thunderstorm Watch" ]; then
	WARNING="- Severe Tstorm Watch"
fi
if [ "$WARNING" = " - Severe Thunderstorm Warning" ]; then
	WARNING="- Severe Tstorm Warning"
fi
if [ "$WARNING" = " - Small Craft Advisory" ]; then
	WARNING=""
fi
ECHO -n "$WARNING" > "$weatherdatadir"warning.txt

#Almanac what is the historic average temp
HISTORIC=`echo "$WeatherData" | grep -m 2 '"almanac": {' -A4 | tail -n1 | sed 's/.*\: "//' | cut -d '"' -f1`
ECHO -n "$HISTORIC""&deg" > "$weatherdatadir"historic.txt

#Save the newly created data as an image from the HTML.
"$wkhtmltoimagedir"wkhtmltoimage -q --height 355 --width 296 --quality 100 http://weather.themajorshome.com/weather/weather.shtml "$weatherimagedir"weather$ZIPCODE.jpg
"$wkhtmltoimagedir"wkhtmltoimage -q --height 205 --width 250 --quality 100 http://weather.themajorshome.com/weather/blogweather.shtml "$weatherimagedir"weatherweb$ZIPCODE.jpg

#Notification Center alert that we were successful.
"$terminalnotifier"terminal-notifier.app/Contents/MacOS/terminal-notifier -title 'Weather Update' -message "$ZIPCODE Updated" -contentImage "$weatherimagedir"weather"$ZIPCODE".jpg

#Done parsing zip codes
done
