# ERPNext + HRMS — Operations Commands (AWS)

Run all commands from `~/erpnext` unless noted otherwise.

Always use both compose files:

```bash
cd ~/erpnext
COMPOSE="docker compose -f docker-compose.yml -f docker-compose.hrms.yml"
```

Default site: `erp.localhost` (override in `.env` as `SITE_NAME`).

---

## Daily operations

### Start stack

```bash
cd ~/erpnext
docker compose -f docker-compose.yml -f docker-compose.hrms.yml up -d
```

### Stop stack

```bash
cd ~/erpnext
docker compose -f docker-compose.yml -f docker-compose.hrms.yml down
```

### Restart stack (safe — HRMS and icons auto-recover)

```bash
cd ~/erpnext
docker compose -f docker-compose.yml -f docker-compose.hrms.yml down
docker compose -f docker-compose.yml -f docker-compose.hrms.yml up -d
```

### Update from GitHub

```bash
cd ~/erpnext && git pull
docker compose -f docker-compose.yml -f docker-compose.hrms.yml up -d
```

### Container status

```bash
docker compose -f docker-compose.yml -f docker-compose.hrms.yml ps
```

---

## Health checks

### Installed apps (must show frappe, erpnext, hrms)

```bash
docker compose -f docker-compose.yml -f docker-compose.hrms.yml exec backend \
  bench --site erp.localhost list-apps
```

### HRMS icons/assets (expect HTTP/1.1 200 OK)

```bash
curl -I http://127.0.0.1/assets/hrms/images/frappe-hr-logo.svg -H "Host: erp.localhost"
```

### Scheduler running (attendance cron)

```bash
docker top $(docker compose -f docker-compose.yml -f docker-compose.hrms.yml ps -q scheduler)
```

Expect: `frappe.utils.bench_helper frappe schedule`

### HRMS import in scheduler

```bash
docker compose -f docker-compose.yml -f docker-compose.hrms.yml exec scheduler bash -c \
  'cd /home/frappe/frappe-bench && ./env/bin/python -c "import hrms; print(\"HRMS OK\")"'
```

### queue-long worker (attendance background jobs)

```bash
docker compose -f docker-compose.yml -f docker-compose.hrms.yml logs queue-long --tail 20
```

### Clear site cache

```bash
docker compose -f docker-compose.yml -f docker-compose.hrms.yml exec backend \
  bench --site erp.localhost clear-cache
```

---

## Logs

```bash
# Backend
docker compose -f docker-compose.yml -f docker-compose.hrms.yml logs backend --tail 50

# Scheduler
docker compose -f docker-compose.yml -f docker-compose.hrms.yml logs scheduler --tail 50

# queue-long (attendance jobs)
docker compose -f docker-compose.yml -f docker-compose.hrms.yml logs queue-long --tail 50

# Frontend (nginx)
docker compose -f docker-compose.yml -f docker-compose.hrms.yml logs frontend --tail 50

# Follow live
docker compose -f docker-compose.yml -f docker-compose.hrms.yml logs -f scheduler
```

---

## Database access

### Option A — Frappe bench MariaDB (recommended)

Connects to the **site database** automatically:

```bash
docker compose -f docker-compose.yml -f docker-compose.hrms.yml exec backend \
  bench --site erp.localhost mariadb
```

Inside MariaDB shell:

```sql
SHOW TABLES LIKE 'tab%';
SELECT name, employee_name, status FROM tabEmployee LIMIT 10;
SELECT name, employee, attendance_date, status FROM tabAttendance ORDER BY creation DESC LIMIT 20;
SELECT name, employee, time, log_type FROM tabEmployee Checkin ORDER BY time DESC LIMIT 20;
EXIT;
```

Note: table `tabEmployee Checkin` has a space — use backticks:

```sql
SELECT name, employee, time, log_type FROM `tabEmployee Checkin` ORDER BY time DESC LIMIT 20;
```

### Option B — Root MySQL shell (all databases)

```bash
docker compose -f docker-compose.yml -f docker-compose.hrms.yml exec db \
  mysql -uroot -padmin
```

Replace `admin` with your `DB_ROOT_PASSWORD` from `.env` if changed.

```sql
SHOW DATABASES;
USE `_your_site_db_name`;
SHOW TABLES;
EXIT;
```

### Find site database name

```bash
docker compose -f docker-compose.yml -f docker-compose.hrms.yml exec backend \
  cat /home/frappe/frappe-bench/sites/erp.localhost/site_config.json
```

Look for `"db_name"`.

### Option C — Run one SQL query without interactive shell

```bash
docker compose -f docker-compose.yml -f docker-compose.hrms.yml exec backend \
  bench --site erp.localhost mariadb -e "SELECT name, employee, attendance_date, status FROM tabAttendance ORDER BY creation DESC LIMIT 10;"
```

---

## Useful ERPNext / HRMS queries

```sql
-- Employees
SELECT name, employee_name, status, company FROM tabEmployee;

-- Today's attendance
SELECT name, employee, attendance_date, status, shift
FROM tabAttendance
WHERE attendance_date = CURDATE();

-- Recent check-ins
SELECT name, employee, time, log_type, shift
FROM `tabEmployee Checkin`
ORDER BY time DESC
LIMIT 20;

-- Shift types with auto attendance
SELECT name, enable_auto_attendance, process_attendance_after, last_sync_of_checkin
FROM `tabShift Type`;

-- Scheduled jobs (HRMS attendance)
SELECT name, method, frequency, last_execution
FROM `tabScheduled Job Type`
WHERE method LIKE '%attendance%' OR method LIKE '%shift%';
```

---

## Frappe bench console (Python)

```bash
docker compose -f docker-compose.yml -f docker-compose.hrms.yml exec backend \
  bench --site erp.localhost console
```

Example:

```python
import frappe
frappe.get_all("Attendance", limit=5, order_by="creation desc")
frappe.get_all("Employee Checkin", limit=5, order_by="time desc")
exit()
```

---

## Backup & restore

### Manual backup (local + S3)

```bash
sudo /home/ubuntu/backup-erpnext.sh
```

### View cron

```bash
sudo crontab -l
```

### List S3 backups

```bash
aws s3 ls s3://grubpac-erpnext-backups/
```

### List local backups

```bash
ls -la /home/ubuntu/backups/
```

### Backup log

```bash
tail -50 /home/ubuntu/backups/backup.log
```

### Bench backup only (inside Docker, no S3)

```bash
docker compose -f docker-compose.yml -f docker-compose.hrms.yml exec backend \
  bench --site erp.localhost backup --with-files
```

---

## HRMS maintenance

### Rebuild HRMS assets (after HRMS update)

```bash
docker compose -f docker-compose.yml -f docker-compose.hrms.yml exec backend \
  bench --site erp.localhost build --app hrms
```

Then restart (asset sync runs on start):

```bash
docker compose -f docker-compose.yml -f docker-compose.hrms.yml up -d
```

### Migrate site (after app update)

```bash
docker compose -f docker-compose.yml -f docker-compose.hrms.yml exec backend \
  bench --site erp.localhost migrate
```

---

## Git (deploy repo)

```bash
cd ~/erpnext
git pull
git status
git remote -v
```

Remote should be: `https://github.com/himanshu-grubpac/erpnext-docker.git`

---

## Quick troubleshooting

| Problem | Command |
|---------|---------|
| HRMS missing | `list-apps` — should show hrms |
| Icons broken | `curl -I .../frappe-hr-logo.svg` — expect 200 |
| Scheduler dead | `docker top ... scheduler` — expect `frappe schedule` |
| HRMS import error | scheduler HRMS OK test (see Health checks) |
| Backup failed | `sudo ERP_DIR=/home/ubuntu/erpnext /home/ubuntu/backup-erpnext.sh` |

---

## PC (Windows) — push changes to GitHub

```powershell
cd "C:\Users\salun\Downloads\Company Data\erpnext-deploy-clean"
git add -A
git commit -m "Describe your change"
git push origin main
```

Then on AWS: `git pull` and `docker compose ... up -d`.
