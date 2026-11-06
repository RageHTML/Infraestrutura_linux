#!/bin/bash
set -euo pipefail
cd /tmp

DB="recadastro"
DIR="/var/backups/postgres"
DATA=$(date +%Y%m%d_%H%M%S)
SQL="${DB}_${DATA}.sql"
TAR="${DB}_${DATA}.tar.gz"
SMB_SERVER="10.0.4.10"
SMB_SHARE="backups"
SMB_CRED="/var/lib/postgresql/.smbcred"
LOG="$DIR/backup.log"

log() { echo "$(date '+%F %T') $1" >> "$LOG"; }
trap 'log "ERRO no backup (linha $LINENO)"' ERR

log "Inicio do backup de $DB"

pg_dump -d "$DB" -f "$DIR/$SQL"
tar -czf "$DIR/$TAR" -C "$DIR" "$SQL"
rm -f "$DIR/$SQL"

smbclient "//$SMB_SERVER/$SMB_SHARE" -A "$SMB_CRED" -c "put $DIR/$TAR $TAR"

find "$DIR" -name "${DB}_*.tar.gz" -mtime +7 -delete

log "Backup concluido e enviado: $TAR"
