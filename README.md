# service.borg
Service submodule to integrate borg backup

./service borg <options>

### Possible options

Some commands accept "latest" or "auto" to use the newest backup, or create a new backup with the hostname and the current timestamp.

- `init`: Create a new remote repository if none exists.

- `info`: Display information about the borg backup repository.

- `list`: List all backups.

- `backup <name>`: Create a new backup with the specified name. Accepts "latest".

- `restore <name>`: Restore data from backup with the specified name. Accepts "latest".

- `export <file> <name>`: Export a backup with the specified name to a .tar file. Accepts "latest".

- `delete <name>`: Delete a backup with the specified name. Does **NOT** accept "latest", but expects a name.

- `compact`: Compact the repository to save space.

- `prune`: Prune old backups. Doesn't touch backups made in the last 24 hours, and executes "borg compact" after.

- `break-lock`: Break the repository lock. **USE WITH CAUTION!**
