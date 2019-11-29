#!/bin/bash

log_warn() {
  echo "warn::: $1"
}

log_info() {
  echo "info::: $1"
}

log_error() {
  echo "error::: $1"
  exit 1
}

if [ -z "$1" ]; then
  log_error "Hostname was not provided"
  exit 1
else
  HOSTNAME=$1
fi

yum install bind-utils -y

# Test to see if the ELB DNS has been propagated
wait_for_dns_propagation() {
  hostname=$1
  log_info "Checking if $hostname has been propagated..."

  DNS_PROPAGATED=0
  # counters
  DNS_COUNTER=0
  # counters limit
  DNS_COUNTER_MAX=90
  # sleep seconds
  DNS_SLEEP_SECONDS=10

  log_info "Trying to perform a trace DNS query to prevent caching"
  dig +trace $hostname @8.8.8.8

  while [ "$DNS_PROPAGATED" -eq 0 ] && [ "$DNS_COUNTER" -le "$DNS_COUNTER_MAX" ]; do
    host $hostname 8.8.8.8
    if [ "$?" -eq 1 ]; then
      DNS_COUNTER=$((DNS_COUNTER + 1))
      log_info "DNS Not Propagated - Sleeping $DNS_SLEEP_SECONDS seconds"
      sleep "$DNS_SLEEP_SECONDS"

    else
      log_info "DNS Propagated"
      DNS_PROPAGATED=1
    fi
  done

  if [ $DNS_PROPAGATED -ne 1 ]; then
    log_error "DNS entry for ${hostname} did not propagate within expected time"
  fi
}

wait_for_dns_propagation $HOSTNAME