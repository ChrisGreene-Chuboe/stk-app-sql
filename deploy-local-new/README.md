# Chuck-Stack Deploy Local (New)

This is a persistent local deployment environment for chuck-stack, based on the proven test environment pattern but with data persistence.

## Architecture & Responsibilities

### Clear Separation of Concerns

**shell.nix handles all setup:**
- Creates all directories with proper permissions
- Copies all files (migrations, modules, scripts, configuration)
- Sets up migration utility from GitHub
- Configures all environment variables
- Makes /opt/ directories completely self-contained (no symlinks back to template)

**start-deploy.nu handles database operations only:**
- Verifies prerequisites exist (errors if missing)
- PostgreSQL initialization and startup
- Database migrations using chuck-stack-nushell-psql-migration
- Schema documentation generation
- PostgREST configuration
- Documentation setup

This eliminates duplication and ensures clear responsibilities.

## Usage

### Creating a New Instance

From this directory:
```bash
nix-shell
```

This will:
1. Create a new instance in `/opt/stk-local-{timestamp}/`
2. Copy ALL necessary files to the instance directory (no dependencies on original)
3. Set up migration utility from GitHub source
4. Exit with instructions to cd to the instance directory

### Working with an Instance

```bash
cd /opt/stk-local-{your-instance-name}/
nix-shell
```

This will:
1. Set up environment variables for the instance
2. Verify all prerequisites exist (fails fast if missing)
3. Initialize PostgreSQL (or restart if existing)
4. Run migrations using chuck-stack-nushell-psql-migration
5. Generate schema documentation
6. Configure PostgREST
7. Set up aichat integration
8. Drop you into the environment as `stk_login` user

### Custom Instance Names

```bash
STK_INSTANCE_NAME=my-project nix-shell
```

## Self-Contained Design

Each `/opt/stk-local-*` directory is completely independent:

- **No symlinks**: Everything is copied, not linked
- **No dependencies**: Instance works even if template directory is deleted
- **Full migration history**: Complete migrations directory copied to each instance
- **Independent updates**: Each instance can be updated independently

## Key Features

- **Persistent**: Data survives across shell sessions
- **Location**: Lives in `/opt/` instead of `/tmp/`
- **Cleanup**: Only stops PostgreSQL on exit, preserves all data
- **Instance Management**: Supports multiple named instances
- **Uses latest migration tool**: chuck-stack-nushell-psql-migration with idempotent fixes
- **Error handling**: Fails fast with clear error messages if prerequisites missing

## Migration Commands

Once in an instance:
```bash
migrate status ./migrations       # Show migration status
migrate history ./migrations      # Show migration history  
migrate run ./migrations --dry-run # Test without applying
migrate add ./migrations <description> # Create new migration
```

## Troubleshooting

### Prerequisites Missing
If you see errors about missing directories or files, the shell.nix setup didn't complete properly. This should not happen in normal usage.

### Permission Issues
All directories are created with proper permissions by shell.nix. If you see permission errors, check that the instance directory was created correctly.

### Database Connection Issues
The migration utility requires all environment variables to be set properly by shell.nix. The nushell script verifies these prerequisites before attempting database operations.

## Removing an Instance

```bash
sudo rm -rf /opt/stk-local-{instance-name}
```

Each instance is completely independent, so removing one doesn't affect others.