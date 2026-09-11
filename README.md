# IT Infrastructure & DevOps Trainee — Practical Implementation

A hands-on Linux administration, containerization, automation, and
monitoring project built across two virtualized machines, demonstrating
end-to-end DevOps practices from server hardening to disaster recovery.

## Environment

Built and tested across two VirtualBox virtual machines on a single
host, connected via a Bridged Network Adapter so both machines sit on
the same LAN with independent IPs.

| Role | OS | Purpose |
|---|---|---|
| Server (server01) | Ubuntu Server 26.04 LTS | Hosts the Docker stack: Nginx, Flask app, PostgreSQL, monitoring |
| Client / Workstation | Debian (Desktop) | Remote administration over SSH, browser verification of web/TLS routing and dashboards |

- Hypervisor: Oracle VM VirtualBox
- Networking: Bridged Adapter mode on both VMs (real LAN IPs via DHCP)
- Server IP: 192.168.1.133
- All server administration performed remotely from the Debian client over SSH; no work done at the server's own console after initial provisioning

## Architecture

```
Debian (client) --SSH (port 2222)--> Ubuntu Server (192.168.1.133)

                        Nginx (80/443, only exposed service)
                              |
                              v
                        Flask App (internal :5000)
                              |
                              v
                        PostgreSQL (internal :5432, persistent volume)

                        Prometheus (:9090)
                          |-> scrapes Node Exporter (:9100)
                          |-> scrapes cAdvisor (:8080)
```

## Port Mapping

| Service | Container Port | Host Port | Exposure |
|---|---|---|---|
| Nginx | 80, 443 | 80, 443 | Public (only service exposed to host) |
| Flask app | 5000 | — | Internal only (Docker network) |
| PostgreSQL | 5432 | — | Internal only (Docker network) |
| Node Exporter | 9100 | 9100 | Public (metrics endpoint) |
| cAdvisor | 8080 | — | Internal only (scraped by Prometheus) |
| Prometheus | 9090 | 9090 | Public (dashboard) |
| SSH | 22 | 2222 | Public (hardened, key-only) |

## Repository Structure

```
devops-trainee-assignment/
├── app/                  Flask application (Dockerfile, app.py, requirements.txt)
├── nginx/                Reverse proxy config + self-signed TLS certs
├── prometheus/           Prometheus scrape configuration
├── scripts/               Automation: health check, backup, cert generation
├── setup/                 Provisioning script and cron job definitions
├── screenshots/           Evidence for every task (see below)
├── docker-compose.yml    Full service stack definition
├── .env.example           Template for required environment variables
├── .gitignore              Excludes .env, TLS private keys, and backup archives from version control
└── README.md              This runbook
```

---

## Requirement Verification Checklist

| # | Requirement | Command | Evidence |
|---|---|---|---|
| 1 | Non-root sudo user | `id trainee` | 01_trainee_user_setup.png |
| 2 | SSH key-based auth, port 2222 | `sudo sshd -T \| grep -E "port\|permitrootlogin\|passwordauthentication"` | 04_ssh_hardening_config.png |
| 3 | UFW restricted to 2222/80/443 | `sudo ufw status verbose` | 06_ufw_firewall_status.png |
| 4 | Nginx reverse proxy on host :80 | `docker compose ps` | 07_volume_and_containers_status.png |
| 5 | Flask app internal only | `docker compose ps` (no published port for app) | 07_volume_and_containers_status.png |
| 6 | PostgreSQL with persistent volume | `docker volume inspect devops-trainee-assignment_db_data` | 07_volume_and_containers_status.png |
| 7 | Reverse proxy routing works | `curl http://localhost/` | 09_terminal_routing.png, 08_browser_http_https.png |
| 8 | Health check script + thresholds | `sudo /opt/scripts/infra_health_check.sh` | 10_health_check_full.png |
| 9 | Cron job every 15 minutes | `cat /etc/cron.d/infra-health-check` | 10_health_check_full.png |
| 10 | DB backup, compressed, timestamped | `sudo /opt/scripts/db_backup.sh && ls -l /var/backups/db/` | 11_backup_restore_full.png |
| 11 | Documented restore procedure | See Task 4 below | 12_restore_command_documented.png |
| 12 | End-to-end DR test (destroy + restore) | See Task 4 below | 11_backup_restore_full.png |
| 13 | Prometheus + Node Exporter + cAdvisor | Browser: `:9090/targets` | 13_prometheus_targets_up.png |
| 14 | Git branches, merges, clean history | `git log --oneline --graph --all` | 14_git_log_and_status.png |

---

## Task 1 — Linux Administration & Security

Server hardening performed via `setup/01_provision_server.sh`:
- Created a non-root `trainee` user with sudo privileges
- Installed SSH key-based authentication (password login disabled)
- Moved SSH to port `2222`, disabled root login
- Configured UFW to allow only `2222` (SSH), `80` (HTTP), `443` (HTTPS) — default deny on everything else

**Setup commands:**
```
ssh-keygen -t ed25519 -C "trainee@devops-assignment"
cat ~/.ssh/id_ed25519.pub

ssh -p 2222 trainee@192.168.1.133
sudo ufw status verbose
```

**Evidence:**

![Trainee User Setup](screenshots/01_trainee_user_setup.png)
*Non-root trainee user created with sudo privileges*

![SSH Key Generation](screenshots/02_ssh_keygen_pubkey.png)
*SSH keypair generated on the Debian client*

![SSH Login Verification](screenshots/03_ssh_login_verification.png)
*Key-based login succeeding, trainee sudo access verified*

![SSH Hardening](screenshots/04_ssh_hardening_config.png)
*sshd_config confirms port 2222, root login disabled, password auth disabled*

![SSH Port 2222](screenshots/05_ssh_port_2222.png)
*Successful remote connection on the hardened port*

![UFW Firewall Status](screenshots/06_ufw_firewall_status.png)
*Firewall restricted to 2222/80/443, default deny incoming*

---

## Task 2 — Containerization & Web Services

Three-tier stack deployed via Docker Compose:
- **Nginx** — reverse proxy, only service exposed on host ports 80/443
- **Flask app** — internal only (port 5000), reachable solely through the Docker `backend` network
- **PostgreSQL** — internal only (port 5432), data persisted via a named Docker volume

**Setup:**
```
cp .env.example .env
nano .env
chmod +x scripts/generate_self_signed_cert.sh
./scripts/generate_self_signed_cert.sh
docker compose up -d --build
docker compose ps
```

**Verification:**
```
curl http://localhost/
curl http://localhost/health
curl -k https://localhost/
docker volume inspect devops-trainee-assignment_db_data
```

**Evidence:**

![Volume and Container Status](screenshots/07_volume_and_containers_status.png)
*Persistent database volume confirmed, all containers healthy*

![Browser HTTP and HTTPS](screenshots/08_browser_http_https.png)
*Reverse-proxied application accessed via browser over HTTP and HTTPS (self-signed TLS)*

![Terminal Routing](screenshots/09_terminal_routing.png)
*curl verification of HTTP, health endpoint, and HTTPS routing through Nginx*

---

## Task 3 — Automation & Shell Scripting

`/opt/scripts/infra_health_check.sh` checks CPU, RAM, and disk usage,
Docker service status, and the application container's health. A
`[WARNING]` is logged if disk usage exceeds 85% or the app container is
not running; otherwise an `[INFO]` entry is logged.

**Manual run:**
```
sudo /opt/scripts/infra_health_check.sh
sudo tail -20 /var/log/infra_health.log
```

**Scheduled via cron**, every 15 minutes (`/etc/cron.d/infra-health-check`):
```
*/15 * * * * root /opt/scripts/infra_health_check.sh >> /var/log/infra_health_cron.log 2>&1
```

**Evidence:**

![Health Check Full Proof](screenshots/10_health_check_full.png)
*Normal run, log output, WARNING triggered by stopping the app container, and cron job confirmed installed*

---

## Task 4 — Monitoring, Backups & Disaster Recovery

**Backup script** `/opt/scripts/db_backup.sh` dumps the PostgreSQL
database with `pg_dump`, compresses it with `gzip`, and stores it in
`/var/backups/db/` with a timestamped filename
(`db_backup_YYYYMMDD_HHMMSS.sql.gz`). The added time-of-day component
prevents same-day backups from overwriting one another; backups older
than 7 days are pruned automatically.

**Restore procedure:**
```
ls -l /var/backups/db/
sudo zcat /var/backups/db/db_backup_TIMESTAMP.sql.gz | docker exec -i devops-db psql -U devopsuser -d devopsdb
docker exec -it devops-db psql -U devopsuser -d devopsdb -c "\dt"
```
(Replace `db_backup_TIMESTAMP.sql.gz` with the actual filename from `ls -l` above.)

**Disaster recovery was verified end-to-end**: a test table was
created, backed up, deliberately dropped to simulate data loss, then
successfully restored from the backup archive with data intact.

**Monitoring:** Prometheus scrapes Node Exporter (host metrics) and
cAdvisor (container metrics) every 15 seconds.
- Node Exporter: `http://192.168.1.133:9100/metrics`
- Prometheus targets: `http://192.168.1.133:9090/targets`

**Evidence:**

![Backup and Restore Full Proof](screenshots/11_backup_restore_full.png)
*Full disaster-recovery cycle: table created, backed up, dropped, restored, and verified intact*

![Restore Command Documented](screenshots/12_restore_command_documented.png)
*Restore procedure documented in this README*

![Prometheus Targets Up](screenshots/13_prometheus_targets_up.png)
*Node Exporter and cAdvisor targets both reporting UP in Prometheus*

---

## Task 5 — Git & Documentation

Work was organized into feature branches and merged into `main` with
explicit merge commits to preserve history:
```
feature/docker-setup  -> Nginx, Flask app, PostgreSQL, Prometheus config
feature/scripts       -> health check script, backup script, cron jobs
```

**Evidence:**

![Git Log and Status](screenshots/14_git_log_and_status.png)
*Branch/merge history and clean working tree*

---

## Security Notes

- SSH is key-only; password authentication and root login are both disabled at the `sshd` level, not just discouraged.
- UFW defaults to deny-incoming; only the three required ports are explicitly allowed.
- The TLS certificate used by Nginx is self-signed, appropriate for this lab/demo environment. In production this would be replaced with a certificate from a trusted CA (e.g., Let's Encrypt via certbot).
- Secrets (`.env`, private TLS key) are excluded from version control via `.gitignore` and never committed.
- The PostgreSQL and Flask containers are not published to the host — they are reachable only inside the Docker `backend` network, reducing attack surface.
- Backup archives are stored with `600` permissions (owner read/write only).

## Known Limitations & Possible Improvements

- Backup retention is a fixed 7-day window (configurable via `RETENTION_DAYS` in `db_backup.sh`); a production setup might tier retention (daily/weekly/monthly).
- No alerting is configured on top of Prometheus; adding Alertmanager would allow proactive notification on threshold breaches instead of relying on log review.
- The health check script currently checks a single named container (`devops-app`); it could be generalized to loop over all services in `docker-compose.yml`.
- TLS is self-signed for demo purposes only.

## Setup Summary

```
git clone https://github.com/RishavTh/it-infrastructure-devops.git
cd it-infrastructure-devops
cp .env.example .env
nano .env
chmod +x scripts/generate_self_signed_cert.sh
./scripts/generate_self_signed_cert.sh
docker compose up -d --build
docker compose ps
```

## Teardown

```
docker compose down              # stop and remove containers, keep data
docker compose down --volumes    # also wipe the database volume (destructive)
```
