#!/usr/bin/env bash
#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
FW="$DIR/../configs/firewall/firewall.nft"

"$DIR/topologia.sh" up                         
sysctl -qw net.netfilter.nf_log_all_netns=1     
modprobe nf_log_syslog
ip netns exec fw nft -f "$FW"                 

mkdir -p /run/sshd
for z in dmz db files; do                      
  ip netns exec "$z" /usr/sbin/sshd -o PidFile=/run/sshd-"$z".pid
done

systemctl restart nginx postgresql@17-main smbd
echo "Ambiente no ar. Teste com: sudo $DIR/testes.sh"
