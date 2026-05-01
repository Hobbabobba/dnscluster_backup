#!/bin/bash
# =============================================================
# Technitium DNS Server – Restore-Skript
# Speicherort: /home/stefan/dns-restore.sh
# Aufruf:      ./dns-restore.sh /home/stefan/dns-backups/technitium_backup_20250501_150000.zip
# =============================================================

# --- Konfiguration -------------------------------------------
DNS_HOST="http://192.168.0.7:5380"
API_TOKEN="DEIN_API_TOKEN_HIER"          # Muss auf dem Zielserver gültig sein!
# -------------------------------------------------------------

BACKUP_FILE="$1"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# --- Eingabe prüfen ------------------------------------------
if [ -z "$BACKUP_FILE" ]; then
    echo ""
    echo "Aufruf: $0 <pfad-zur-backup.zip>"
    echo "Beispiel: $0 /home/stefan/dns-backups/technitium_backup_20250501_150000.zip"
    echo ""
    # Verfügbare Backups anzeigen
    echo "Verfügbare Backups:"
    ls -lh /home/stefan/dns-backups/technitium_backup_*.zip 2>/dev/null || echo "  (keine gefunden)"
    echo ""
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    log "FEHLER: Datei nicht gefunden: $BACKUP_FILE"
    exit 1
fi

if ! file "$BACKUP_FILE" | grep -q "Zip archive"; then
    log "FEHLER: Die angegebene Datei ist keine gültige ZIP-Datei!"
    exit 1
fi

FILESIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
log "====== Technitium DNS Restore ======"
log "Backup-Datei : $BACKUP_FILE ($FILESIZE)"
log "Ziel-Server  : $DNS_HOST"
echo ""

# --- Sicherheitsabfrage --------------------------------------
echo "ACHTUNG: Alle bestehenden Einstellungen und Zonen auf dem Zielserver"
echo "         werden durch das Backup überschrieben!"
echo ""
read -r -p "Restore wirklich durchführen? [ja/NEIN]: " CONFIRM
if [ "$CONFIRM" != "ja" ]; then
    log "Restore abgebrochen."
    exit 0
fi

# --- Server-Erreichbarkeit prüfen ----------------------------
log "Prüfe Server-Erreichbarkeit..."
if ! curl -sf --max-time 10 "$DNS_HOST/api/user/session/status?token=$API_TOKEN" > /dev/null; then
    log "FEHLER: Server $DNS_HOST nicht erreichbar oder Token ungültig!"
    log "Tipp: Auf einem Frisch-System erst im Webinterface einen Token anlegen."
    exit 1
fi

log "Server erreichbar. Starte Restore..."

# --- Restore durchführen -------------------------------------
RESPONSE=$(curl -s \
    --max-time 120 \
    -w "\n%{http_code}" \
    -F "file=@$BACKUP_FILE" \
    "$DNS_HOST/api/settings/restore?token=$API_TOKEN\
&blockLists=true\
&logs=false\
&scopes=true\
&stats=false\
&zones=true\
&allowedZones=true\
&blockedZones=true\
&dnsSettings=true\
&logSettings=true\
&deleteExistingFiles=true\
&authConfig=true\
&apps=true")

HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n -1)

if [ "$HTTP_STATUS" -ne 200 ]; then
    log "FEHLER: Restore fehlgeschlagen! HTTP-Status: $HTTP_STATUS"
    log "Antwort: $BODY"
    exit 1
fi

# Auf Fehler im JSON-Body prüfen
if echo "$BODY" | grep -q '"status":"error"'; then
    log "FEHLER: Server meldet Fehler:"
    log "$BODY"
    exit 1
fi

log "Restore gesendet. Warte 15 Sekunden auf Server-Neustart..."
sleep 15

# Prüfen ob Server wieder erreichbar ist
if curl -sf --max-time 15 "$DNS_HOST/api/user/session/status?token=$API_TOKEN" > /dev/null; then
    log "Server ist wieder erreichbar."
    log "====== Restore erfolgreich abgeschlossen! ======"
else
    log "Server antwortet noch nicht (kann normal sein – kurz warten und manuell prüfen)."
    log "Webinterface: $DNS_HOST"
fi

exit 0
