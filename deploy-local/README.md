# Chuck-Stack Local Deployment

This directory provides a **persistent local deployment** solution for the chuck-stack application framework. Unlike the temporary test environment, deploy-local creates long-lived instances in `/opt/` that survive shell exits and provide isolated development environments.

## Prerequisites

### Required Software
- **Nix Package Manager**: Install from https://nixos.org/download.html
- **sudo access**: Must be able to run `sudo` commands without password prompts
  - Test with: `sudo -n true` (should complete without asking for password)
  - If needed, add to `/etc/sudoers`: `your-username ALL=(ALL) NOPASSWD: ALL`

### System Requirements
- Linux or macOS with Nix support
- At least 2GB free space in `/opt/` for each instance
- Network access for downloading PostgreSQL and dependencies

## Quick Start

### Create Your First Instance

```bash
# Navigate to the deploy-local template directory
cd path/to/stk-app-sql/deploy-local/

# Create a new instance (auto-named with timestamp)
nix-shell
# → Creates: /opt/stk-local-default-YYYYMMDD-HHMMSS/

# Or create a named instance
STK_INSTANCE_NAME=myproject nix-shell
# → Creates: /opt/stk-local-myproject/
```

### Start Working with Your Instance

```bash
# Navigate to your instance directory
cd /opt/stk-local-myproject/

# Start the chuck-stack environment
nix-shell
# PostgreSQL starts, migrations run, ready for development!

# Use the database
psql
# Or use aichat with database integration
aix $f -- show me all api.stk_actors
```

### Stop Working (Data Persists)

```bash
# Exit the nix-shell
exit
# PostgreSQL stops, but all data remains for next restart
```

## User Workflows

### Creating New Instances

```bash
cd stk-app-sql/deploy-local/

# Default instance (timestamp-named)
nix-shell

# Named instance  
STK_INSTANCE_NAME=project-alpha nix-shell

# Development instance
STK_INSTANCE_NAME=dev-branch nix-shell

# Client-specific instance
STK_INSTANCE_NAME=client-xyz nix-shell
```

### Working with Existing Instances

```bash
# List all instances
ls /opt/stk-local-*/

# Restart any instance
cd /opt/stk-local-{instance-name}/
nix-shell
```

### Running Multiple Instances Concurrently

```bash
# Terminal 1: Start project-alpha
cd /opt/stk-local-project-alpha/
nix-shell

# Terminal 2: Start project-beta  
cd /opt/stk-local-project-beta/
nix-shell

# Both run independently with separate databases
```

## Features

### Persistent Data
- PostgreSQL database survives shell exit
- Command history preserved
- Schema changes persist between sessions
- Generated configurations saved

### Version Isolation
- Each instance frozen at chuck-stack version when created
- Core framework updates don't affect existing instances
- Safe to upgrade chuck-stack without breaking existing work

### Self-Contained Deployment
- All dependencies copied to instance directory
- No external file dependencies after creation
- Can be backed up/restored as single directory

### Multiple Concurrent Instances
- No port conflicts (uses Unix sockets)
- Independent databases and configurations
- Only PostgREST needs manual port adjustment if used

## Database Usage

### Basic Operations

```bash
# Connect to database
psql

# Insert test data
insert into api.stk_request (name) values ('test request');

# View data with auto-populated columns
select * from api.stk_request;
```

### Role Management

```bash
# Default user (limited permissions)
echo $PGUSER  # shows: stk_login

# Switch to API role
export STK_PG_ROLE=stk_api_role
psql
show role;  # verifies current role

# Switch to private role (more permissions)
export STK_PG_ROLE=stk_private_role

# Switch to superuser (DDL changes)
export PGUSER=stk_superuser
export STK_PG_ROLE=stk_superuser
```

### AI Chat Integration

```bash
# Basic schema-aware chat
aix $f -- show me all tables

# Detailed convention-aware chat  
aix-conv-detail $f -- create a new entity called product

# Summary convention chat
aix-conv-sum $f -- explain the naming conventions
```

## PostgREST API

### Starting PostgREST

```bash
# Configuration file created automatically
echo $STK_POSTGREST_CONFIG
# → /opt/stk-local-{instance}/postgrest-config/postgrest.conf

# Start PostgREST API server
postgrest $STK_POSTGREST_CONFIG

# Test with example curl
sh $STK_POSTGREST_CURL
```

### Multiple Instance Port Management

If running PostgREST in multiple instances simultaneously:

```bash
# Edit the config file in each instance
vim $STK_POSTGREST_CONFIG

# Change the port number:
# server-port = 3001  # Instance 1
# server-port = 3002  # Instance 2  
# server-port = 3003  # Instance 3
```

## Instance Management

### Listing Instances

```bash
# Show all instances
ls -la /opt/stk-local-*/

# Show instance disk usage
du -sh /opt/stk-local-*/
```

### Backing Up Instances

```bash
# Backup entire instance
sudo tar -czf backup-myproject-$(date +%Y%m%d).tar.gz /opt/stk-local-myproject/

# Backup just database
cd /opt/stk-local-myproject/
nix-shell --run "pg_dump stk_db > backup-$(date +%Y%m%d).sql"
```

### Removing Instances

```bash
# Remove instance when no longer needed
sudo rm -rf /opt/stk-local-old-project/

# Or move to archive location
sudo mv /opt/stk-local-completed-project/ /opt/archive/
```

## Troubleshooting

### Permission Issues

```bash
# Fix ownership if needed
sudo chown -R $USER:$USER /opt/stk-local-{instance}/

# Check sudo access
sudo -n true && echo "Sudo works" || echo "Sudo requires password"
```

### PostgreSQL Issues

```bash
# Check if PostgreSQL is running
ps aux | grep postgres

# Check PostgreSQL logs
tail -f /opt/stk-local-{instance}/pgdata/postgresql.log

# Manual PostgreSQL stop
cd /opt/stk-local-{instance}/
pg_ctl stop
```

### Nix Issues

```bash
# Verify Nix installation
nix --version

# Check shell.nix syntax
nix-instantiate --parse shell.nix
```

### Disk Space

```bash
# Check available space
df -h /opt/

# Clean up old PostgreSQL logs
find /opt/stk-local-*/pgdata/ -name "*.log" -mtime +7 -delete
```

## Advanced Usage

### Custom Instance Locations

If you don't have sudo access or prefer different locations, modify the shell.nix:

```bash
# Edit instance directory location
vim shell.nix

# Change this line:
export STK_LOCAL_DIR="/opt/stk-local-$INSTANCE_NAME"
# To:
export STK_LOCAL_DIR="$HOME/.local/share/stk-local-$INSTANCE_NAME"
```

### Development Workflow

```bash
# Create development instance from current state
cd stk-app-sql/deploy-local/
STK_INSTANCE_NAME=dev-$(git rev-parse --short HEAD) nix-shell

# Work in isolation
cd /opt/stk-local-dev-a1b2c3d/
nix-shell

# Make and test changes
# When satisfied, create a clean instance for testing
cd ../deploy-local/
STK_INSTANCE_NAME=test-feature-x nix-shell
```

## Documentation References

### Chuck-Stack Conventions
- PostgreSQL conventions: `bat /opt/chuckstack.github.io/src-ls/postgres-conventions.md`
- Detailed conventions: `bat /opt/chuckstack.github.io/src-ls/postgres-convention/*`

### Generated Schema Documentation
- API schema: `bat schema-details/schema-api.sql`
- Private tables: `bat schema-details/schema-private.sql`
- Enum values: `bat schema-details/schema-enum.txt`

---

## Summary

The deploy-local system provides production-like local development environments that:
- ✅ Persist data across shell sessions
- ✅ Isolate versions to prevent upgrade conflicts  
- ✅ Support multiple concurrent instances
- ✅ Provide complete chuck-stack functionality
- ✅ Enable safe experimentation and development

Perfect for local development, testing, client demos, and learning the chuck-stack framework.