# XML-RPC and Database Migrations - Enabled by Default

## Summary

This document describes the changes made to enable XML-RPC by default and implement automatic database migrations.

## Changes Made

### 1. XML-RPC Enabled by Default

**Files Modified:**
- `core/defs_lib/defs_defaults.py`
- `db/defs.sql`

**Changes:**
- Changed `IBS_SERVER_IP` from `"127.0.0.1"` to `"0.0.0.0"`
- This allows XML-RPC server to listen on all network interfaces by default
- Enables remote access to XML-RPC API

**Impact:**
- XML-RPC server now accessible from remote hosts (not just localhost)
- **Security Note**: Ensure firewall rules are properly configured
- PHP web interface can still connect via localhost (127.0.0.1) on the same server

### 2. Database Migration System

**New Files:**
- `core/db/db_migration.py` - Complete migration system

**Files Modified:**
- `core/db/db_main.py` - Integrated migration system into initialization

**Features:**
- Automatic version tracking in `ibs_states` table
- Automatically runs upgrade SQL files in order
- Tracks current database version
- Only runs pending migrations
- Runs automatically during system startup

**How It Works:**

1. **Version Tracking:**
   - Stores current database version in `ibs_states` table with key `db_version`
   - Current version: `A1.23`

2. **Migration Detection:**
   - Scans `db/` directory for files matching pattern: `from_VERSION_upgrade.sql`
   - Sorts migrations by version number
   - Compares current version with available migrations

3. **Automatic Execution:**
   - Runs during `db_main.init()` (system startup)
   - Executes only pending migrations (newer than current version)
   - Updates version after each successful migration
   - Logs all migration activities

4. **Migration Files:**
   - Located in `/usr/local/IBSng/db/`
   - Format: `from_A1.XX_upgrade.sql` or `from_alpha-YYYY-MM-DD_upgrade.sql`
   - Examples:
     - `from_A1.04_upgrade.sql`
     - `from_A1.08_upgrade.sql`
     - `from_A1.23_upgrade.sql`

## Usage

### XML-RPC

No configuration needed - XML-RPC is now enabled by default on all interfaces.

**To restrict access:**
1. Edit `core/defs_lib/defs_defaults.py` and change `IBS_SERVER_IP` back to `"127.0.0.1"`
2. Or configure firewall rules to restrict access to port 1235

### Database Migrations

Migrations run automatically during system startup. No manual intervention required.

**Manual Migration (if needed):**
```python
from core.db import db_migration
db_migration.runMigrations()
```

**Check Current Version:**
```python
from core.db import db_migration
version = db_migration.getCurrentVersion()
print("Current database version: %s" % version)
```

## Migration File Format

Migration files should follow this naming convention:
- `from_A1.XX_upgrade.sql` for version A1.XX
- `from_alpha-YYYY-MM-DD_upgrade.sql` for alpha versions

Example migration file:
```sql
-- Migration from A1.22 to A1.23
alter table tariff_prefix_list drop CONSTRAINT tariff_prefix_list_prefix_code_key;
insert into defs (name,value) VALUES ('RADIUS_SERVER_CLEANUP_TIME','I20');
```

## Security Considerations

### XML-RPC

1. **Firewall Configuration:**
   - Restrict access to port 1235 (XML-RPC port) to trusted IPs
   - Example: `firewall-cmd --add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" port port="1235" protocol="tcp" accept'`

2. **Network Security:**
   - XML-RPC is not encrypted by default
   - Consider using VPN or SSH tunnel for remote access
   - Use trusted clients configuration in `TRUSTED_CLIENTS`

3. **Authentication:**
   - Ensure proper authentication is configured
   - Use strong passwords for admin accounts

### Database Migrations

1. **Backup Before Migrations:**
   - Always backup database before running migrations
   - Migrations are automatic but backups are recommended

2. **Migration Safety:**
   - Migrations run in transactions when possible
   - Failed migrations are logged but don't stop system startup
   - Check logs after startup to verify migrations completed

## Testing

### Test XML-RPC Access

From remote machine:
```bash
# Test connection
telnet <server-ip> 1235

# Test XML-RPC call (using Python)
python -c "
import xmlrpclib
server = xmlrpclib.ServerProxy('http://<server-ip>:1235')
print server.system.listMethods()
"
```

### Test Migrations

1. **Check current version:**
   ```sql
   SELECT * FROM ibs_states WHERE name = 'db_version';
   ```

2. **Verify migrations ran:**
   - Check logs: `/var/log/IBSng/ibs_server.log`
   - Look for "Checking for database migrations..." messages

3. **Test new migration:**
   - Create a test migration file
   - Restart IBSng service
   - Verify migration executed

## Rollback

### XML-RPC

To revert XML-RPC to localhost only:
```python
# Edit core/defs_lib/defs_defaults.py
IBS_SERVER_IP="127.0.0.1"
```

Then regenerate defs.sql:
```bash
/usr/local/IBSng/core/defs_lib/defs2sql.py -i /usr/local/IBSng/core/defs_lib/defs_defaults.py /usr/local/IBSng/db/defs.sql
```

### Migrations

Migrations cannot be automatically rolled back. To revert:
1. Restore from backup
2. Or manually reverse migration changes

## Troubleshooting

### XML-RPC Not Accessible

1. Check firewall rules
2. Verify server is listening: `netstat -tlnp | grep 1235`
3. Check server logs for errors
4. Verify `IBS_SERVER_IP` is set to `0.0.0.0` in defs table

### Migrations Not Running

1. Check database connection
2. Verify `ibs_states` table exists
3. Check logs for migration errors
4. Verify migration files are in correct location
5. Check file permissions on migration directory

### Migration Errors

1. Check migration SQL syntax
2. Verify database user has proper permissions
3. Review logs for specific error messages
4. Some migration errors may be expected (e.g., constraint already exists)

## Future Enhancements

1. **Migration Rollback Support:**
   - Add ability to rollback migrations
   - Store rollback scripts

2. **Migration Validation:**
   - Validate migration SQL before execution
   - Check for common errors

3. **Migration Logging:**
   - Enhanced logging of migration steps
   - Migration history table

4. **XML-RPC Security:**
   - SSL/TLS support for XML-RPC
   - API key authentication

---

**Date**: $(date)
**Status**: ✅ Enabled by Default
**Version**: 1.0

