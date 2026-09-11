cat README.md## Database Restore Procedure

To restore the PostgreSQL database from a backup archive:

1. Identify the backup file:
   ls -l /var/backups/db/

2. Restore it into the running container:
   sudo zcat /var/backups/db/db_backup_<TIMESTAMP>.sql.gz | \
       docker exec -i devops-db psql -U devopsuser -d devopsdb

3. Verify the restore:
   docker exec -it devops-db psql -U devopsuser -d devopsdb -c '\dt'
