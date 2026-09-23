# mac-cleanup.sh

This script finds files that use space in "System Data" on macOS. It can also remove the files that are not necessary.

## What the script does

The script has two modes:

- **Scan mode.** The script shows the size of each item. It does not remove files.
- **Clean mode.** The script shows each item and asks you what to do with it.

The script does not show items that are empty (0 bytes).

## Types of items

The script puts items into three groups.

**1. Junk.** The script removes these items permanently. The applications make them again when necessary.

- User caches and logs
- Time Machine local snapshots (the backups on your external disk do not change)
- Xcode build files, device support files and old simulators
- Homebrew, npm, yarn, pip and gradle caches
- Unused Docker and OrbStack images (the script does not remove volumes)

**2. Recoverable items.** The script moves these items to the Trash. You can put them back if necessary.

- Screen recordings and screenshots that macOS did not complete
- Application data folders that are larger than 500 MB

**3. Report only.** The script shows the size of these items. It does not remove them.

- iPhone and iPad backups
- Messages attachments
- Xcode archives

## Protected items

The script never removes these items:

- Apple folders (`com.apple.*`)
- Password manager data (for example, 1Password)
- iCloud, Mail and Messages data
- System files, swap files and `/private/var/folders`

## Before you start

1. Open **System Settings > Privacy & Security > Full Disk Access**.
2. Turn on Full Disk Access for **Terminal**. If you do not do this, the sizes that the script shows can be too small.
3. Quit all applications that you want to clean.

## How to use the script

1. Open **Terminal**.
2. Make the script executable:

   ```bash
   chmod +x ~/Downloads/mac-cleanup.sh
   ```

3. Do a scan first:

   ```bash
   ~/Downloads/mac-cleanup.sh
   ```

4. Read the results.
5. Start clean mode:

   ```bash
   ~/Downloads/mac-cleanup.sh --clean
   ```

6. Answer each question.

## How to answer the questions

For junk items, the script asks: `Clean this? [y/N]`

- Type `y` to remove the item.
- Push **Return** to keep the item.

For recoverable items, the script shows three options:

- Type `t` to move the item to the Trash.
- Type `o` to open the folder in Finder. Then the script asks again.
- Type `s` or push **Return** to keep the item.

For Time Machine snapshots, the script asks for your password.

## Options

| Option | Function |
|---|---|
| `--clean` | Starts clean mode. |
| `--min-mb N` | Shows application folders that are larger than N MB. The default is 500. |
| `--help` | Shows the help text. |

Example:

```bash
~/Downloads/mac-cleanup.sh --clean --min-mb 100
```

## After you clean

1. Open the Trash.
2. Make sure that you do not need the items in it.
3. Empty the Trash. The disk space is not free until you do this.
4. Restart your Mac. The storage values in System Settings can be old until you restart.

## Warnings

**WARNING: If you move an application folder to the Trash, the application resets. You lose its logins, settings and downloaded content.**

**WARNING: You cannot recover junk items after the script removes them.**

## Docker and OrbStack

If you have both Docker Desktop and OrbStack installed, the script tells you. Each one uses its own disk space. If you use only one of them, remove the other one to get more space.

- To remove Docker Desktop, open it and click **Troubleshoot > Uninstall**.
- To remove OrbStack, open its menu and click **Uninstall**.

The application must be running before the script can remove its unused images.
