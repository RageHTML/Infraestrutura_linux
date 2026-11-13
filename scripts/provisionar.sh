#!/bin/bash
echo "Instalando dependências de rede e serviços..."
apt-get update && apt-get install -y isc-dhcp-server bind9 samba quota
echo "Provisionamento concluído com sucesso."
