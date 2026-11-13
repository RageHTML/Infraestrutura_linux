#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
FW="$DIR/../configs/firewall/firewall.nft"

for z in dmz db files; do
  [ -f "/run/sshd-$z.pid" ] && kill "$(cat "/run/sshd-$z.pid")" 2>/dev/null || true
done

"$DIR/topologia.sh" up
sysctl -qw net.netfilter.nf_log_all_netns=1    
modprobe nf_log_syslog
ip netns exec fw nft -f "$FW"


for par in nginx:dmz postgresql@17-main:db smbd:files; do
  svc=${par%%:*}; ns=${par##*:}
  mkdir -p "/etc/systemd/system/$svc.service.d"
  printf '[Service]\nNetworkNamespacePath=/run/netns/%s\n' "$ns" \
    > "/etc/systemd/system/$svc.service.d/override.conf"
done
systemctl daemon-reload


mkdir -p /run/sshd
for z in dmz db files; do
  ip netns exec "$z" /usr/sbin/sshd -o PidFile="/run/sshd-$z.pid"
done

systemctl restart nginx postgresql@17-main smbd


ok=1
check() { 
  if ip netns exec "$1" ss -tln | grep -q ":$2 "; then
    echo "  OK     $3"
  else
    echo "  FALHA  $3 (nada escutando em $1:$2)"; ok=0
  fi
}
echo "Verificando serviços nas zonas:"
check dmz   443  "Nginx 443 na DMZ"
check db    5432 "PostgreSQL 5432 na DB Zone"
check files 445  "Samba 445 na Files"
check dmz   22   "SSH na DMZ"
check db    22   "SSH na DB Zone"
check files 22   "SSH na Files"

if [ "$ok" = 1 ]; then
  echo "Ambiente no ar. Teste com: sudo bash $DIR/testes.sh"
else
  echo "Há serviços fora do ar. Veja: systemctl status <serviço> e systemctl cat <serviço>"
  exit 1
fi