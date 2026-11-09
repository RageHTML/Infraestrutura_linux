#!/usr/bin/env bash

PASS=0; FAIL=0

probe() {  
  local out
  out=$(ip netns exec "$1" nc -z -w 3 -s "$2" "$3" "$4" 2>&1) && { echo open; return; }
  grep -qi refused <<<"$out" && echo refused || echo filtered
}

t() { 
  local got; got=$(probe "$2" "$3" "$4" "$5")
  if [[ $got == "$6" ]]; then r=PASS; ((PASS++)); else r=FAIL; ((FAIL++)); fi
  printf '%-5s %-46s esperado=%-9s obtido=%s\n' "$r" "$1" "$6" "$got"
}

WAN=10.0.9.10; WEB=10.0.1.10; DB=10.0.3.10; FIL=10.0.4.10
USR=10.0.2.20; ADM=10.0.2.5

echo "== R1: WAN -> DMZ 80/443 =="
t "R1  WAN -> DMZ :80"                     wan $WAN $WEB 80   open
t "R1  WAN -> DMZ :443"                    wan $WAN $WEB 443  open
t "R1- WAN -> DMZ :8080 (fora da matriz)"  wan $WAN $WEB 8080 filtered
t "R1- WAN -> DMZ :22"                     wan $WAN $WEB 22   filtered

echo "== R2: DMZ -> DB 5432 =="
t "R2  DMZ -> DB :5432"                    dmz $WEB $DB 5432 open
t "R2- DMZ -> DB :22"                      dmz $WEB $DB 22   filtered
t "R2- DMZ -> Files :445"                  dmz $WEB $FIL 445 filtered

echo "== R3: LAN -> Files 139/445 =="
t "R3  LAN usuario -> Files :445"          lan $USR $FIL 445 open
t "R3  LAN usuario -> Files :139"          lan $USR $FIL 139 open
t "R3- LAN usuario -> Files :22"           lan $USR $FIL 22  filtered
t "R3- LAN usuario -> DB :5432"            lan $USR $DB 5432 filtered

echo "== R4: LAN admin -> todas as zonas 22 =="
t "R4  Admin -> DMZ :22"                   lan $ADM $WEB 22 open
t "R4  Admin -> DB :22"                    lan $ADM $DB  22 open
t "R4  Admin -> Files :22"                 lan $ADM $FIL 22 open
t "R4- LAN usuario -> DMZ :22"             lan $USR $WEB 22 filtered
t "R4- LAN usuario -> DB :22"              lan $USR $DB  22 filtered

echo "== R5: DMZ/WAN -> DB (DROP) =="
t "R5  WAN -> DB :5432"                    wan $WAN $DB 5432 filtered
t "R5  WAN -> DB :22"                      wan $WAN $DB 22   filtered

echo "== SSH somente por chave =="
SSHO="-o BatchMode=yes -o StrictHostKeyChecking=accept-new -b $ADM"
if ip netns exec lan sudo -u "$SUDO_USER" ssh $SSHO admin@$WEB true >/dev/null 2>&1
then echo "PASS  SSH com chave entra";  ((PASS++)); else echo "FAIL  SSH com chave entra";  ((FAIL++)); fi
if ip netns exec lan sudo -u "$SUDO_USER" ssh $SSHO -o PubkeyAuthentication=no admin@$WEB true 2>&1 | grep -q "Permission denied (publickey)"
then echo "PASS  SSH sem chave recusado"; ((PASS++)); else echo "FAIL  SSH sem chave recusado"; ((FAIL++)); fi

echo
echo "RESULTADO: $PASS PASS / $FAIL FAIL"
