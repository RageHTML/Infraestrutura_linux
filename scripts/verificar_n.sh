#!/usr/bin/env bash
# Verificação do estado do projeto. SOMENTE LEITURA: não altera nada e não imprime senhas.
# Uso (na raiz do repositório):  sudo bash scripts/verificar.sh 2>&1 | tee /tmp/verificacao.txt
export LC_ALL=C
if [ "$(id -u)" -ne 0 ]; then
  echo "Este script precisa de root. Rode:  sudo bash $0 2>&1 | tee /tmp/verificacao.txt"
  exit 1
fi
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO" || exit 1

sec() { printf '\n===== %s =====\n' "$1"; }
ns()  { ip netns exec "$@"; }
g()   { sudo -u "${SUDO_USER:-root}" git "$@"; }      # git como o dono do repositório
lst() { awk '{print $4}' | sort -u | tr '\n' ' '; echo; }

echo "Verificação em $(date '+%F %T') | repositório: $REPO"

sec "1. Namespaces"
ip netns list | awk '{print $1}' | sort | tr '\n' ' '; echo
echo "ip_forward no fw: $(ns fw sysctl -n net.ipv4.ip_forward 2>&1)"

sec "2. Firewall (política, regras e contadores)"
ns fw nft list chain inet projeto forward 2>&1 | grep -E 'policy|comment|DROP-OTHER' | sed 's/^[[:space:]]*//' | cut -c1-170

sec "3. Serviços escutando em cada zona"
for z in dmz db files; do printf -- '-- %s: ' "$z"; ns "$z" ss -tlnH 2>&1 | lst; done
printf -- '-- host (22/53/80/443/445/5432/8000): '
ss -tlnH | awk '{print $4}' | grep -E ':(22|53|80|443|445|5432|8000)$' | sort -u | tr '\n' ' '; echo

sec "4. PostgreSQL"
ns dmz pg_isready -h 10.0.3.10 -p 5432 2>&1
grep -HE '^listen_addresses' /etc/postgresql/17/main/postgresql.conf /etc/postgresql/17/main/conf.d/*.conf 2>/dev/null
grep -nE '^host' /etc/postgresql/17/main/pg_hba.conf
echo "roles (nome | superusuário):"
runuser -u postgres -- psql -Atc "select rolname||' | '||rolsuper from pg_roles where rolname !~ '^pg_'" 2>&1
echo "bancos: $(runuser -u postgres -- psql -Atc "select string_agg(datname, ', ') from pg_database where not datistemplate" 2>&1)"
echo "tabelas em 'banco': $(runuser -u postgres -- psql -d banco -Atc "select count(*) from information_schema.tables where table_schema='public'" 2>&1)"

sec "5. Aplicação"
echo ".env -> $(sed -E 's#(://)[^@]*@#\1***@#' servidor-web/.env 2>/dev/null | head -1)"
if ns dmz ss -tlnH 2>/dev/null | grep -q '127.0.0.1:8000'
then echo "uvicorn: escutando em 127.0.0.1:8000 (dmz)"; else echo "uvicorn: NAO está rodando na dmz"; fi
echo "HTTPS pela WAN: $(ns wan curl -sk -o /dev/null -m 5 -w '%{http_code}' https://10.0.1.10/)"
echo "HTTP  pela WAN: $(ns wan curl -s  -o /dev/null -m 5 -w '%{http_code}' http://10.0.1.10/)  (esperado 301)"

sec "6. Samba (pastas, grupos e usuários)"
testparm -s 2>/dev/null | grep -E '^\[|path =|valid users|write list|force group|interfaces' | sed 's/^[[:space:]]*//'
ls -ld /compartilhado/* 2>&1
for gr in devs mkt diretoria backup_mgr; do getent group "$gr" || echo "grupo $gr: NAO existe"; done
echo "usuários Samba: $(pdbedit -L 2>&1 | cut -d: -f1 | tr '\n' ' ')"
cmp -s configs/samba/smb.conf /etc/samba/smb.conf && echo "smb.conf do repo = /etc/samba/smb.conf" || echo "smb.conf do repo DIFERE do /etc/samba/smb.conf"

sec "7. Cotas de disco"
findmnt -T /srv/arquivos 2>&1 | tail -1
findmnt -T /compartilhado 2>&1 | tail -1
mount | grep -iE 'quota' || echo "nenhuma montagem com opção de quota"
repquota -a 2>&1 | head -12

sec "8. DNS"
for s in named bind9 unbound dnsmasq; do printf '%s: %s\n' "$s" "$(systemctl is-active "$s" 2>&1)"; done
named-checkconf 2>&1 && echo "named-checkconf: OK"
grep -rhE '^\s*zone ' /etc/bind/ 2>/dev/null | sed 's/^[[:space:]]*//' | head
grep -vE '^\s*(//|#|$)' /etc/bind/named.conf.local 2>/dev/null | head -25
echo "NS fastservice.local:  $(dig @127.0.0.1 +short +time=2 NS fastservice.local 2>&1 | head -2 | tr '\n' ' ')"
echo "SOA reversa 10.0.2:    $(dig @127.0.0.1 +short +time=2 SOA 2.0.10.in-addr.arpa 2>&1 | head -1)"
printf 'escuta :53 no host: '; ss -tulnH | awk '{print $5}' | grep ':53$' | sort -u | tr '\n' ' '; echo
for z in dmz lan db files; do printf '  %s: ' "$z"; ns "$z" ss -tulnH 2>/dev/null | awk '{print $5}' | grep ':53$' | sort -u | tr '\n' ' '; echo; done

sec "9. DHCP"
for s in isc-dhcp-server dnsmasq; do printf '%s: %s\n' "$s" "$(systemctl is-active "$s" 2>&1)"; done
pgrep -a dhcpd
grep -vE '^\s*(#|$)' /etc/dhcp/dhcpd.conf 2>/dev/null | sed 's/^[[:space:]]*//' | head -40
grep -hE 'dhcp-range|dhcp-host' /etc/dnsmasq.conf /etc/dnsmasq.d/* 2>/dev/null | head

sec "10. Backup"
for u in root postgres admin; do echo "-- crontab de $u:"; crontab -u "$u" -l 2>&1 | grep -vE '^\s*#' | head -5; done
echo "-- agendamentos que citam backup:"
grep -rHn 'backup' /etc/crontab /etc/cron.d /var/spool/cron/crontabs 2>/dev/null | grep -v '^\s*#' | head
ls -l scripts/backup*.sh /home/admin/backup.sh /usr/local/bin/backup*.sh 2>/dev/null
echo "-- /usr/local/bin/backup_empresa.sh (senhas mascaradas):"
sed -E 's/(%|password=|PASSWORD=)[^ "]+/\1***/g' /usr/local/bin/backup_empresa.sh 2>/dev/null | head -30
ls -lt /srv/arquivos/backups /compartilhado/backups 2>/dev/null | head -10
tail -n 5 /var/backups/postgres/backup.log /home/admin/backup.log 2>/dev/null

sec "11. Repositório"
echo "branch: $(g branch --show-current)"
g status --short | head -15
g log --oneline -5
for f in README.md scripts/provisionar.sh scripts/subir.sh scripts/testes.sh servidor-web/.env.example; do
  [ -f "$f" ] && echo "OK     $f" || echo "FALTA  $f"
done
g check-ignore -q servidor-web/.env && echo ".env ignorado pelo git: OK" || echo ".env NAO está no .gitignore"
echo "arquivos com possível segredo (nomes):"
g grep --untracked -lEi 'BEGIN OPENSSH|PRIVATE KEY' -- . ':!servidor-web/.env' | head
echo "arquivos __pycache__/.pyc rastreados: $(g ls-files | grep -cE '__pycache__|\.pyc$')"
echo "arquivos em evidencias/: $(ls evidencias 2>/dev/null | wc -l)"

sec "12. Testes de firewall"
bash "$REPO/scripts/testes.sh" 2>&1 | grep -E 'FAIL|RESULTADO'

echo
echo "Fim da verificação."
