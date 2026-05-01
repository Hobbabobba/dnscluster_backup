# Technitium DNS Server – Restore-Anleitung

**Gültig für:** Frisch installierter Technitium DNS Server  
**Backup erstellt mit:** `dns-backup.sh` / API-Endpunkt `/api/settings/backup`  
**Restore-Skript:** `dns-restore.sh`

---

## Voraussetzungen

- Debian-System mit den Skripten unter `/home/stefan/`
- Backup-Datei vorhanden unter `/home/stefan/dns-backups/`
- Zugang zum Webinterface des neuen/leeren Servers

---

## Schritt-für-Schritt

### Schritt 1 – Technitium installieren

Falls noch nicht geschehen, Technitium auf dem neuen Server installieren:

```bash
curl -sSL https://download.technitium.com/dns/install.sh | sudo bash
```

Webinterface aufrufen: `http://NEUE-IP:5380`

---

### Schritt 2 – Erstes Login & Passwort setzen

1. Im Browser `http://NEUE-IP:5380` öffnen
2. Login mit Standardzugangsdaten: **admin / admin**
3. Sofort ein neues Passwort vergeben

---

### Schritt 3 – API-Token erstellen

1. Oben rechts auf den Benutzernamen klicken → **Sessions**
2. **Create Token** klicken
3. Einen Namen vergeben (z. B. `restore-script`)
4. Den generierten Token-Wert **kopieren und sicher notieren**

---

### Schritt 4 – Restore-Skript anpassen

Auf dem Debian-System die Datei `/home/stefan/dns-restore.sh` öffnen und die
beiden Variablen oben auf den **neuen Zielserver** anpassen:

```bash
DNS_HOST="http://NEUE-IP:5380"
API_TOKEN="NEUER_TOKEN_VOM_SCHRITT_3"
```

---

### Schritt 5 – Neuestes Backup auswählen

```bash
# Verfügbare Backups anzeigen:
ls -lht /home/stefan/dns-backups/technitium_backup_*.zip | head -5
```

Die neueste Datei (ganz oben) merken, z. B.:
```
technitium_backup_20250501_150000.zip
```

---

### Schritt 6 – Restore ausführen

```bash
/home/stefan/dns-restore.sh /home/stefan/dns-backups/technitium_backup_20250501_150000.zip
```

Das Skript zeigt eine Sicherheitsabfrage – mit `ja` bestätigen.  
Danach wartet das Skript automatisch auf den Server-Neustart (~15 Sekunden).

---

### Schritt 7 – Ergebnis prüfen

Nach dem Restore im Webinterface kontrollieren:

| Bereich | Was prüfen |
|---|---|
| **Zones** | Alle Zonen und Records vorhanden? |
| **Settings** | Forwarder, DNS-Domain, Protokolle korrekt? |
| **Administration** | Benutzer und Token wiederhergestellt? |
| **Apps** | Installierte Apps vorhanden? |

---

### Schritt 8 – Cluster neu verbinden (falls Cluster-Betrieb)

Da der neue Server eine neue Identität hat, muss er dem Cluster manuell
wieder beitreten:

1. Im Webinterface: **Administration → Cluster**
2. **Join Cluster** mit den Daten der verbleibenden Nodes
3. Synchronisation abwarten

---

## Fehlerbehebung

**Server nicht erreichbar / Token ungültig**  
→ Schritt 2 und 3 wiederholen, Token neu anlegen und ins Skript eintragen.

**Restore schlägt fehl (HTTP-Fehler)**  
→ Prüfen ob die ZIP-Datei vollständig ist:
```bash
file /home/stefan/dns-backups/technitium_backup_*.zip
# Erwartete Ausgabe: "Zip archive data"
```

**Server startet nach Restore nicht neu**  
→ Dienst manuell neu starten:
```bash
sudo systemctl restart technitium-dns-server
```

**Backup-Datei nicht auf dem Debian-System vorhanden**  
→ Von einem anderen Ort kopieren:
```bash
scp user@nas:/pfad/backup.zip /home/stefan/dns-backups/
```

---

## Wichtige Hinweise

> Das Restore **überschreibt alle bestehenden Daten** auf dem Zielserver
> (Zonen, Settings, Apps, Benutzer). Auf einem leeren Frisch-System ist das
> gewünscht – auf einem produktiven System mit Bedacht einsetzen.

> Der API-Token aus dem Backup wird **ebenfalls wiederhergestellt**.
> Nach dem Restore kann der alte Token aus dem ursprünglichen Cluster wieder
> verwendet werden.

> Die Backup-Dateien enthalten Konfigurationen und TSIG-Keys –
> **sicher aufbewahren** und nicht in öffentliche Repositories einchecken.
