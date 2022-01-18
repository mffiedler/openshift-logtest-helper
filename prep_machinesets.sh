#!/bin/bash
set -e

# https://docs.openshift.com/container-platform/4.9/machine_management/manually-scaling-machineset.html
# Pass args as env vars

[ -z "$ELS_INSTANCE_TYPE" ] && echo "ELS_INSTANCE_TYPE not defined, exiting" && exit 1
[ -z "$FLUENTD_INSTANCE_TYPE" ] && echo "FLUENTD_INSTANCE_TYPE not defined, exiting" && exit 1
[ -z "$NUM_FLUENTD_NODES" ] && echo "NUM_FLUENTD_NODES not defined, exiting" && exit 1


for i in $(oc get machinesets -n openshift-machine-api -o json | jq -r '.items[].metadata.name'); do
  echo "$i"
  instance_type=$(oc get machineset "$i" -o json -n openshift-machine-api | jq -r '.spec.template.spec.providerSpec.value.instanceType')
  echo "$instance_type"
  if [[ $i == *a ]]; then
    if [[ $instance_type != "$ELS_INSTANCE_TYPE" ]]; then
      echo "*a not $ELS_INSTANCE_TYPE"
      oc patch -n openshift-machine-api machineset "$i" --type='merge' -p "{\"spec\":{\"template\":{\"spec\":{\"providerSpec\":{\"value\":{\"instanceType\":\"$ELS_INSTANCE_TYPE\"}}}}}}"
      oc scale -n openshift-machine-api --replicas=0 machineset "$i"
      sleep 15
      oc scale -n openshift-machine-api --replicas=3 machineset "$i"
      sleep 1m
    fi
  elif [[ $i == *b ]]; then
    oc scale -n openshift-machine-api --replicas=0 machineset "$i"
    sleep 30
    if [[ $instance_type != "$FLUENTD_INSTANCE_TYPE" ]]; then
      echo "*b not $ELS_INSTANCE_TYPE"
      oc patch -n openshift-machine-api machineset "$i" --type='merge' -p "{\"spec\":{\"template\":{\"spec\":{\"providerSpec\":{\"value\":{\"instanceType\":\"$FLUENTD_INSTANCE_TYPE\"}}}}}}"
    fi
    oc scale -n openshift-machine-api --replicas="$NUM_FLUENTD_NODES" machineset "$i"
  else
    echo "Patching instancetype and scaling down"
    # oc patch -n openshift-machine-api machineset "$i" --type='merge' -p '{"spec":{"template":{"spec":{"providerSpec":{"value":{"instanceType":"m6i.large"}}}}}}'
    oc scale -n openshift-machine-api --replicas=0 machineset "$i"
  fi
done
