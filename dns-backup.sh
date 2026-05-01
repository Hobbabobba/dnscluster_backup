#!/bin/bash
# =============================================================
# Technitium DNS Server – Backup-Skript
# Speicherort: /home/stefan/dns-backup.sh
# =============================================================

# --- Konfiguration -------------------------------------------
DNS_HOST="http://192.168.0.7:5380"
API_TOKEN="DEIN_API_TOKEN_HIER"          # Administration → Sessions → Token erstellen
BACKUP_DIR="/home/stefan/dns-backups"
KEEP_DAYS=30                              # Backups älter als X Tage werden gelöscht
LOG_FILE="/home/stefan/dns-backups/backup.log"
# -------------------------------------------------------------

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/technitium_backup_$DATE.zip"

# Verzeichnis anlegen falls nicht vorhanden
mkdir -p "$BACKUP_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "====== Technitium DNS Backup gestartet ======"

# Prüfen ob DNS-Server erreichbar ist und Token gültig
RESPONSE=$(curl -s --max-time 10 "$DNS_HOST/api/zones/list?token=$API_TOKEN")
if echo "$RESPONSE" | grep -q '"status":"error"'; then
    log "FEHLER: Token ungültig! Serverantwort: $RESPONSE"
    exit 1
elif ! echo "$RESPONSE" | grep -q '"status":"ok"'; then
    log "FEHLER: DNS-Server unter $DNS_HOST nicht erreichbar!"
    exit 1
fi

log "DNS-Server erreichbar. Starte Backup..."

# Backup abrufen
HTTP_STATUS=$(curl -s -w "%{http_code}" \
    --max-time 60 \
    -o "$BACKUP_FILE" \
    "$DNS_HOST/api/settings/backup?token=$API_TOKEN\
&blockLists=true\
&logs=false\
&scopes=true\
&stats=false\
&zones=true\
&allowedZones=true\
&blockedZones=true\
&dnsSettings=true\
&logSettings=true\
&authConfig=true\
&apps=true")

if [ "$HTTP_STATUS" -ne 200 ]; then
    log "FEHLER: Backup fehlgeschlagen! HTTP-Status: $HTTP_STATUS"
    rm -f "$BACKUP_FILE"
    exit 1
fi

# Prüfen ob die Datei eine echte ZIP ist
if ! file "$BACKUP_FILE" | grep -q "Zip archive"; then
    log "FEHLER: Heruntergeladene Datei ist keine gültige ZIP-Datei!"
    log "Serverantwort: $(cat "$BACKUP_FILE")"
    rm -f "$BACKUP_FILE"
    exit 1
fi

FILESIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
log "Backup erfolgreich gespeichert: $BACKUP_FILE ($FILESIZE)"

# Alte Backups aufräumen
log "Lösche Backups älter als $KEEP_DAYS Tage..."
DELETED=$(find "$BACKUP_DIR" -name "technitium_backup_*.zip" -mtime +$KEEP_DAYS -print -delete | wc -l)
log "$DELETED alte Backup(s) gelöscht."

log "====== Backup abgeschlossen ======"
exit 0
