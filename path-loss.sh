#!/bin/bash

# rburkholder@quovadis.bm
# raymond@burkholder.net

# user defined settings
txtEmail="user@example.com"
txtSubject="Path Loss Report"
txtSeparator="==============================\n"
nTrigger=4
nAttempts=5

declare -A nodes
nodes=( \
  [8.8.8.8]="google1" \
  [8.8.4.4]="google2" \
  )

# local variables
cntNotify=0
status="|"
tmpLog=$(mktemp)
tmpPing=$(mktemp)

# preload output
date > ${tmpLog}

# loop through nodes and test
for node in  ${!nodes[*]}; do
  echo -e ${txtSeparator} >> ${tmpLog};
  echo "checking node ${nodes[${node}]}:" >> ${tmpLog};
  echo "" >> ${tmpLog}

  ping -W 1 -c ${nAttempts} ${node} > ${tmpPing}
  cat ${tmpPing} >> ${tmpLog}

  value=$(grep transmitted ${tmpPing} | cut -d ' ' -f 4)
  if [[ nTrigger -ge value ]]; then flagNxt="dn"
  else flagNxt="up"; fi

  flagPrv="na"

  if [[ -f /tmp/pl.dn.${node} ]]; then
    flagPrv="dn"
    if test "up" = "${flagNxt}"; then
      rm /tmp/pl.dn.${node}
    fi
  fi

  if [[ -f /tmp/pl.up.${node} ]]; then
    flagPrv="up"
    if test "dn" = "${flagNxt}"; then
      rm /tmp/pl.up.${node}
    fi
  fi

  if test "${flagPrv}" != "${flagNxt}"; then
    touch /tmp/pl.${flagNxt}.${node}
    ((cntNotify++));
    mtr -w -b --report ${node} >> ${tmpLog};
    status="${status} ${nodes[${node}]} ${flagPrv}>${flagNxt} |"
    echo "" >> ${tmpLog}
    echo "Above State Change: ${flagPrv}>${flagNxt}" >> ${tmpLog}
  fi

done

# footer
echo -e ${txtSeparator} >> ${tmpLog};
date >> ${tmpLog}

# notify on failure
if [[ cntNotify -gt 0 ]]; then
  cat ${tmpLog} | mail -s "${txtSubject}:${status}" ${txtEmail};
fi

# clean up
rm ${tmpLog}
rm ${tmpPing}
