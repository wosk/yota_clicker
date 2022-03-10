#!/bin/sh
# Script for autoclick "Resume on 64 kbit/s" for YOTA

# Add to crontab to run every minute
# */1 * * * * /root/yota64.sh >> /tmp/log/yota.log


die (){
  echo "YOTA64 die: $1"
  exit 1
}

click_resume () {
  CODE=$1

  cmd="curl $URL $HDRS --data-raw '{\"serviceCode\":\"$CODE\"}' -sw '%{http_code}' -o /dev/null"

  #echo === CMD: $cmd
  RESP_CODE=$(eval $cmd -sw '%{http_code}' -o /dev/null)
  [ $? -eq 0 ] || die "Connection error $? to yota.ru"
  if [ $RESP_CODE -eq 200 ]; then
    return 0
  else
    echo "This method failed with HTTP response $RESP_CODE"
    return 1
  fi
}

# Sometimes curl returns -1, that's why try few times
check_web () {
  [ -x "$(command -v curl)" ] || die "curl required"

  t=1
  while [ $t -lt 5 ]
  do
    REDIR=$(curl -sw "%{redirect_url}" http://ya.ru) # -v to debug
    if [ $? -eq 0 ]; then
      if [[ $REDIR == https://ya.ru* ]] || [[ $REDIR == http://ya.ru* ]] ; then
        #echo "=== Internet detected on $t time ==="
        return 0
      else
        echo "Got redirection to captive portal $REDIR"
        break
      fi
    fi

    [ $t -eq 5 ] && die "Connection to ya.ru failed after $t times"
    sleep 1s
    #echo "=== Try #$t ya.ru ==="
    t=$(( $t + 1 ))
  done
  return $t
}

UUID="$(cat /proc/sys/kernel/random/uuid)"
URL="https://hello.yota.ru/wa/v1/service/temp"
AGENT='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36'
HDRS="-H Content-Type:application/json -H x-transactionid:$UUID -A \"$AGENT\""

FREE_TARIFF_CODE="light"
ZERO_MONEY_CODE="sa"

check_web && exit 0

echo `date`
echo "=== There is no Internet connection ==="

# TODO fetch service code from redirect url
# https://hello.yota.ru/sa?redirurl=http:%2F%2Fya.ru%2F

echo "=== Try click to resume for free tariff ==="
click_resume $FREE_TARIFF_CODE

if [ $? -ne 0 ]; then
  echo "=== Try click to resume on out of money ==="
  click_resume $ZERO_MONEY_CODE || die "Enabling Internet failed: ret $?"
fi

check_web || exit $?
