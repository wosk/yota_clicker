#!/bin/sh
# Script for autoclick "Resume on 64 kbit/s" for YOTA

# Add to crontab to run every minute
# */1 * * * * /root/yota64.sh >> /tmp/log/yota.log


die (){
  echo "YOTA64 die: $1"
  exit 1
}

req (){
  CODE=$1

  cmd="curl $URL $HDRS --data-raw '{\"serviceCode\":\"$CODE\"}' -sw '%{http_code}' -o /dev/null"

  #echo === CMD: $cmd
  RESP_CODE=$(eval $cmd -sw '%{http_code}' -o /dev/null)
  [ $? -eq 0 ] || die "Connection issue: ret $?"
  if [ $RESP_CODE -eq 200 ]; then
    retun 0
  else
    echo "This method failed with HTTP response $RESP_CODE"
    return 1
  fi
}

UUID="$(cat /proc/sys/kernel/random/uuid)"
URL="https://hello.yota.ru/wa/v1/service/temp"
AGENT='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36'
HDRS="-H Content-Type:application/json -H x-transactionid:$UUID -A \"$AGENT\""

FREE_TARIFF_CODE="light"
ZERO_MONEY_CODE="sa"

[ -x "$(command -v curl)" ] || die "curl required"

REDIR=$(curl -sw "%{redirect_url}" http://ya.ru)
[ $? -eq 0 ] || die "Connection issue ret $?"
[ $REDIR == "https://ya.ru/" ] && exit 0

echo `date`
echo "=== There is no Internet connection ==="

# TODO fetch service code from redirect url
# https://hello.yota.ru/sa?redirurl=http:%2F%2Fya.ru%2F

echo "=== Try click to resume for free tariff ==="
req $FREE_TARIFF_CODE
[ $? -eq 0 ] || echo "Try next variant"

echo "=== Try click to resume on out of money ==="
# https://hello.yota.ru/sa?redirurl=http:%2F%2Fya.ru%2F
req $ZERO_MONEY_CODE
[ $? -eq 0 ] || die "Enabling Internet failed: ret $?"
