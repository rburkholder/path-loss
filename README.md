# path-loss

Bash script to ping a series a nodes, and on failure, generates a traceroute, then generates an alert via Slack, with an possible escalation to PagerDuty.

This script was designed to offer a test external to a network to detect for a significant network outage.

## description

Each node has a series of pings sent to it.  If there is a loss of pings greater than some count, as defined in a script variable, then an mtr will be generated for that node.

If any nodes show a loss of pings and have had an mtr generated, then a log of all nodes and their results will be sent to a Slack channel of your choice.  Slack bot token and channel name need to be supplied in the script variables.

When all pings have returned to normal, another report to Slack is generated.

```
nodes=( \
  [8.8.8.8]="google1 member" \
  [8.8.4.4]="google2" \
)
```

Update the 'nodes' list with your list of nodes to be monitored (given an ip address, the node description, and an optional 'member' indicator).  Two example nodes are shown, but you can change and add as you need.

The 'member' indicator is used in a test such that if all members are unreachable, then a PagerDuty alert is generated.  There should be at least one non-member node.   This allows another test:  if all nodes (members and non-members) are unreachable, that typically means that there is a local network issue, so the event is logged to syslog and no Slack or PagerDuty events are generated.
