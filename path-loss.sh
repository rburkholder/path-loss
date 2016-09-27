#!/bin/bash

# rburkholder@quovadis.bm

# raymond@burkholder.net
# http://blog.raymond.burkholder.net

# requires use of:
# https://github.com/juanpabloaj/slacker-cli but install with pip
# https://api.slack.com/bot-users
# https://my.slack.com/apps/build/custom-integration, choose bots, create new one, and add token
# https://my.slack.com/admin#disabled)  to delete test bots
# apt-get install python-pip
# pip install slacker-cli
# #git clone https://pypi.python.org/pypi/slacker-cli/

# user defined settings
txtEmail="name@example.com"
txtSubject="Path Loss Report"
txtSeparator="==============================\n"
nTrigger=4
nAttempts=5
txtPdServiceKey="000000000000000"
txtSlackBotToken="xoxb-something-or-other"
txtSlackChannel="pathloss"

declare -A nodes
nodes=( \
  [8.8.8.8]="google1 member" \
  [8.8.4.4]="google2" \
  )

# local variables
status="|"
cntNotify=0
tmpLog=$(mktemp)
tmpPing=$(mktemp)
cntNodes=0
cntNodesDown=0
cntMembers=0
cntMembersDown=0
declare -a items

# preload output
date > ${tmpLog}

# loop through nodes and test
for node in  ${!nodes[*]}; do

  ((cntNodes++))

  # split out node details
  # 0: alias/name
  # 1: optional 'member' for determining edge outage
  info=${nodes[${node}]}
  items[1]="none"
  ix=0
  for arg in ${info}; do
    items[ix]=${arg}
    ((ix++))
    done

  name="${items[0]}"

  echo -e ${txtSeparator} >> ${tmpLog};
  echo "checking node ${name}:" >> ${tmpLog};
  echo "" >> ${tmpLog}

  ping -W 1 -c ${nAttempts} ${node} > ${tmpPing}
  cat ${tmpPing} >> ${tmpLog}

  value=$(grep transmitted ${tmpPing} | cut -d ' ' -f 4)
  if [[ nTrigger -ge value ]]; then
    flagNxt="dn"
    ((cntNodesDown++))
  else
    flagNxt="up"
    fi

  if test "member" == "${items[1]}"; then
    ((cntMembers++))
    if test "dn" = "${flagNxt}"; then ((cntMembersDown++)); fi
    fi

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
    status="${status} ${name} ${flagPrv}>${flagNxt} |"
    echo "" >> ${tmpLog}
    echo "Above State Change: ${flagPrv}>${flagNxt}" >> ${tmpLog}
    fi

  done

# footer
echo -e ${txtSeparator} >> ${tmpLog}
date >> ${tmpLog}

# notify on failure
if [[ cntNodes -eq cntNodesDown ]]; then
  logger "path-loss - all nodes unreachable"
else
  # if something to notify
  if [[ cntNotify -gt 0 ]]; then
    # need a pagerduty alert if all important members are down
    if [[ cntMembers -eq cntMembersDown ]]; then
      response=$(cat ${tmpLog} | ./pd-trigger.sh -L -s "${txtPdServiceKey}" -d "${status}")
      fi
    # attempt an email
    #cat ${tmpLog} | mail -s "${txtSubject}:${status}" ${txtEmail};
    cat ${tmpLog} | /usr/local/bin/slacker -c ${txtSlackChannel} -t ${txtSlackBotToken}
    fi
  fi

# clean up
rm ${tmpLog}
rm ${tmpPing}
