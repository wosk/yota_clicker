#!/bin/sh
# Script for autoclick "Resume on 64 kbit/s" for YOTA

# Add to crontab to run every minute
# */1 * * * * /root/yota64.sh >> /tmp/log/yota.log

FREE_TARIFF_CODE="light"
ZERO_MONEY_CODE="sa"

die () {
  echo "YOTA64 die: $1"
  exit 1
}

bump_date () {
  # Set recent date to avoid curl error:
  # "SSL_connect failed with error -150: ASN date error, current date before"
  last_upd_date=`date -r $0 +%s`
  cur_date=`date +%s`
  if [ $last_upd_date -gt $cur_date ]
  then
    date -s @`date -r $0 +%s`
    echo New date: `date`
  fi
}

click_resume () {
  AUTH_URL="https://hi.yota.ru/wa/v1/auth/authDeviceByIp"
  HDRS="-H Content-Type:application/json"
  TOKEN=$(curl $AUTH_URL $HDRS -s | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')

  CODE=$1
  CLICK_URL="https://hi.yota.ru/wa/v1/service/temp"
  AGENT='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36'
  HDRS=$HDRS" -H 'Authorization: Bearer "$TOKEN"' -A \"$AGENT\""
  cmd="curl $CLICK_URL $HDRS --data-raw '{\"serviceCode\":\"$CODE\"}'"

  echo "=== Click resume for $1 mode ==="
  #echo === CMD: $cmd
  RESP_CODE=$(eval $cmd -sw '%{http_code}' -o /dev/null)
  [ $? -eq 0 ] || die "Connection error $? to yota.ru"
  if [ $RESP_CODE -eq 200 ]; then
    return 0
  else
    echo "Click for $1 failed with HTTP response $RESP_CODE"
    return 1
  fi
}

# Sometimes curl returns -1, that's why try few times
check_web () {
  [ -x "$(command -v curl)" ] || die "curl required"

  t=1
  while [ $t -lt 5 ]
  do
    REDIR=$(curl -s -L -I -w "%{url_effective}" http://ya.ru -o /dev/null) # -v to debug
    if [ $? -ne 0 ]; then
      [ $t -eq 5 ] && die "Connection to ya.ru failed after $t times"
      sleep 1s
      #echo "=== Try #$t ya.ru ==="
      t=$(( $t + 1 ))
      continue
    fi

    if [[ $REDIR == https://ya.ru* ]] || [[ $REDIR == http://ya.ru* ]] ; then
      #echo "=== Internet detected on $t time ==="
      exit 0
    fi

    echo `date`
    echo "=== There is no Internet connection ==="
    bump_date

    case $REDIR in
      # https://hi.yota.ru/light?redirurl=http%3A%2F%2Fya%2Eru%2F
      https://hi.yota.ru/light*)
        click_resume $FREE_TARIFF_CODE || die "Resuming Internet failed: ret $?"
        return 0
        ;;

      # https://hi.yota.ru/sa?redirurl=http:%2F%2Fya.ru%2F
      https://hi.yota.ru/sa*)
        click_resume $ZERO_MONEY_CODE || die "Resuming Internet failed: ret $?"
        return 0
        ;;
      
      *)
        die "Got unexpected redirection URL $REDIR"
        ;;
    esac

  done

  echo "No connection"
  return $t
}

check_web || exit $?

ntpd -nqN -p ru.pool.ntp.org
touch $0
