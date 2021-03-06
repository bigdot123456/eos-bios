#!/bin/sh

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;35m'
NC='\033[0m' # No Color

PRIV_HEX=$(openssl rand -hex 32)

PRIV=$(python -c '
import sys
import bitcoin as b
print b.encode_privkey(sys.argv[1],"wif")
' $PRIV_HEX)

ACCOUNT=$(openssl rand -hex 32 | base32 | tr '[:upper:]' '[:lower:]' | head -c12)
ADDY=$(python get_eth_address.py $PRIV)
AMOUNT=$(python -c 'import random; print "%.4f" % (random.random()*1000)')

echo "########################################################################"
echo "# Simulating claim of $GREEN$AMOUNT$NC for account $GREEN$ACCOUNT$NC"
echo "# using private-key: $RED$PRIV$NC "
echo "########################################################################"

MAXEOS=$(cleos get table eosio.unregd eosio.unregd settings | jq -r '.rows[0].max_eos_for_8k_of_ram')
echo "* Max amount of EOS for 8kb of RAM $RED$MAXEOS$NC"

# Add test unregd data for this address
echo "* Adding $GREEN$ACCOUNT$NC to eosio.unregd db with $GREEN$AMOUNT EOS$NC"
cleos push action eosio.unregd add '["'$ADDY'","'$AMOUNT' EOS"]' -p eosio.unregd > /dev/null 2>&1
# cleos transfer eosio eosio.unregd "$AMOUNT EOS" -p eosio > /dev/null 2>&1

# Print eosio.unregd balance
SUPPLY_BEFORE=$(cleos get currency stats eosio.token eos | jq -r '.EOS.supply')
echo "* EOS supply before claim $BLUE$SUPPLY_BEFORE$NC"

EOSIOREGRAM_BEFORE=$(cleos get currency balance eosio.token eosio.regram EOS)
echo "* $BLUE""eosio.regram$NC balance before claim $BLUE$EOSIOREGRAM_BEFORE$NC"
EOSIOUNREGD_BEFORE=$(cleos get currency balance eosio.token eosio.unregd EOS)
echo "* $BLUE""eosio.unregd$NC balance before claim $BLUE$EOSIOUNREGD_BEFORE$NC"

TMP=$(mktemp)
cleos create key > $TMP
EOSPRIV=$(head -n1 $TMP | awk '{n=split($0,a," "); print a[n];}')
EOSPUB=$(tail -n1 $TMP | awk '{n=split($0,a," "); print a[n];}')

echo "* Using $RED$EOSPUB$NC for account $GREEN$ACCOUNT$NC"

# Claim
while true; do
  RES=$(python claim.py $PRIV_HEX $ACCOUNT $EOSPUB)
  if [ $? -eq 0 ]; then
    break
  fi
  #echo "Error: press ENTER to try again"
  #read dummy
done
#echo $RES
USAGE=$(cat $RES | jq '.processed.receipt.cpu_usage_us')
echo "* $GREEN$ACCOUNT$NC claimed $GREEN$AMOUNT EOS$NC in $YELLOW$USAGE$NC [us]"

# TOTAL_ISSUED=$(cat $RES |  jq -r '.processed.action_traces[].inline_traces[0].act.data.quantity')
# echo "* Total new EOS issued $RED$TOTAL_ISSUED$NC"

RAMCOST=$(cat $RES | jq -r '.processed.action_traces[].inline_traces[1].act.data.quant')
echo "* EOS payed for 8192 [bytes] of RAM $RED$RAMCOST$NC"

# Print eosio balance
SUPPLY_AFTER=$(cleos get currency stats eosio.token eos | jq -r '.EOS.supply')
echo "* EOS supply after claim $BLUE$SUPPLY_AFTER$NC"
EOSIOREGRAM_AFTER=$(cleos get currency balance eosio.token eosio.regram EOS)
echo "* $BLUE""eosio.regram$NC balance after claim $BLUE$EOSIOREGRAM_AFTER$NC"
EOSIOUNREGD_AFTER=$(cleos get currency balance eosio.token eosio.unregd EOS)
echo "* $BLUE""eosio.unregd$NC balance after claim $BLUE$EOSIOUNREGD_AFTER$NC"

# Print account RAM
RAMQUOTA=$(cleos get account -j $ACCOUNT | jq -r '.ram_quota')
echo "* $ACCOUNT ram quota $YELLOW$RAMQUOTA$NC [bytes]"

# Transfer to test privkey
echo -n "* Using private key to make a transfer on EOS .... "
cleos wallet import --private-key $EOSPRIV > /dev/null 2>&1
cleos transfer $ACCOUNT thisisatesta "0.0001 EOS" > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "$GREEN""OK$NC"
else
  echo "$RED""ERROR$NC"
fi

# #!/bin/bash
# python -c '
# import sys

# def red(s):
#   sys.stdout.write("\b\x1b[0;31m" + s + "\x1b[0m\n")
#   sys.stdout.flush()

# def green(s):
#   sys.stdout.write("\b\x1b[0;32m" + s + "\x1b[0m\n")
#   sys.stdout.flush()

# def asset2int(amountstr):
#   try:
#     parts = amountstr.split()
#     if len(parts) != 2 or not parts[1].isupper() or len(parts[1]) > 7: raise
#     inx = parts[0].rindex(".")
#     if parts[0].index(".") != inx: raise
#     if len(parts[0]) - inx - 1 != 4: raise
#     v = parts[0].replace(".","")
#     return int(v)
#   except:
#     raise Exception("Invalid string amount '%s'" % amountstr)

# def int2asset(amountint, symbol="EOS"):
#   s = "%d" % amountint
#   if( len(s) < 5 ):
#     s = (5-len(s))*"0" + s
#   return s[:-4] +"."+ s[-4:] + " " + symbol

# diff=int2asset(asset2int(sys.argv[1])-asset2int(sys.argv[2]))
# sys.stdout.write("* EOS supply difference :  "); red(diff)

# diff2=int2asset(asset2int(sys.argv[1])-asset2int(sys.argv[2])-asset2int(sys.argv[3]))
# sys.stdout.write("* EOS supply difference without RAM costs :  "); green(diff2)
# ' "$SUPPLY_AFTER" "$SUPPLY_BEFORE" "$RAMCOST"

#echo $GREEN
echo
echo "run $GREEN""cleos get account $ACCOUNT$NC"" to get the full account information"