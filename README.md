# GrubPac ERPNext + HRMS (Docker)

Deploy-only repo for ERPNext v16 with HRMS on Docker.

## Start

```bash
cd ~/erpnext
docker compose -f docker-compose.yml -f docker-compose.hrms.yml up -d
```

## HRMS (first time on server)

```bash
mkdir -p apps
git clone -b version-16 https://github.com/frappe/hrms.git apps/hrms
docker compose -f docker-compose.yml -f docker-compose.hrms.yml up -d
```

Or: `bash scripts/setup-hrms.sh`

## HRMS persistence (survives restart)

- `apps/hrms` is mounted from the host (not in git)
- All HRMS workers run `pip install -e apps/hrms` on start
- `scripts/sync-hrms-assets.sh` copies HRMS icons/CSS/JS into `sites/assets/hrms` on **backend** and **frontend** start (fixes broken icons after `docker compose down/up`)

After changing HRMS or running `bench build --app hrms`, restart:

```bash
docker compose -f docker-compose.yml -f docker-compose.hrms.yml up -d
```

## Updates from git

```bash
cd ~/erpnext && git pull
docker compose -f docker-compose.yml -f docker-compose.hrms.yml up -d
```

## Backups

### Manual backup

```bash
bash scripts/backup-erpnext.sh
```

Backs up database + files, saves to `BACKUP_DIR`, uploads to S3.

### Daily cron (on EC2 host)

```bash
bash scripts/install-backup-cron.sh
```

Runs daily at 02:00 UTC. Requires `aws configure` on the host.

### Docker backup scheduler (alternative)

```bash
docker compose -f docker-compose.yml -f docker-compose.hrms.yml -f docker-compose.backup.yml up -d backup-scheduler
```

Requires `~/.aws` credentials on the host.

### Verify S3 backups

```bash
aws s3 ls s3://grubpac-erpnext-backups/
```

## Important

- Site data lives in Docker volumes (`sites`, `db-data`), not in git
- Use the Docker image `frappe/erpnext:v16` — do not clone full ERPNext source on the server
