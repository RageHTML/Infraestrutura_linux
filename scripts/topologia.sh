#!/usr/bin/env bash
set -euo pipefail

declare -A SUBNET=( [wan]=10.0.9 [dmz]=10.0.1 [lan]=10.0.2 [db]=10.0.3 [files]=10.0.4 )
declare -A HOSTID=( [wan]=10 [dmz]=10 [lan]=20 [db]=10 [files]=10 )
ZONES=(wan dmz lan db files)

down() {
  for ns in "${ZONES[@]}" fw; do ip netns del "$ns" 2>/dev/null || true; done
}

up() {
  down
  ip netns add fw
  ip -n fw link set lo up
  ip netns exec fw sysctl -qw net.ipv4.ip_forward=1
  for z in "${ZONES[@]}"; do
    net=${SUBNET[$z]}
    ip netns add "$z"
    ip -n "$z" link set lo up
    ip link add "fw-$z" netns fw type veth peer name eth0 netns "$z"
    ip -n fw addr add "$net.1/24" dev "fw-$z"
    ip -n fw link set "fw-$z" up
    ip -n "$z" addr add "$net.${HOSTID[$z]}/24" dev eth0
    ip -n "$z" link set eth0 up
    ip -n "$z" route add default via "$net.1"
  done
  ip -n lan addr add 10.0.2.5/24 dev eth0   # IP do admin
}

case "${1:-}" in
  up) up ;;
  down) down ;;
  *) echo "uso: sudo $0 up|down"; exit 1 ;;
esac
