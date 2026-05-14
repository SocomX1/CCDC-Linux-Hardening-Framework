# CCDC-Resources

## About

### Problem Statement

As we learned from the 2025-2026 WRCCDC season, effective performance in this competition requires automation. Red team obtains default credentials at or very shortly after they are distributed to blue team, and they begin leveraging them to launch attacks by minute 20. This necessitates the ability to remove default credentials across the entire environment without having to interact with each host manually.

### Tech Stack

- Shell scripts use `/usr/bin/env sh` as their shebang. It is important that these scripts be as portable as possible across Linux distributions and versions, so `sh` is preferable over `bash`.
- Coordinate (https://git.sr.ht/~sourque/coordinate) is used to handle remote deployment of the scripts.
  - Coordinate is written in Go, which `setup.sh` will attempt to automatically install if necessary.
- Git is used by `setup.sh` to clone this repository and the Coordinate repository.

## Components

- `failsafe_creator.sh`: creates or normalizes the `failsafe` admin account,
  installs its SSH public key, configures passwordless sudo, and verifies that
  sudo actually works before returning success.
- `root_locker.sh`: locks the root account, clears root SSH authorized keys, and
  disables root SSH login.
- `user_locker.sh`: locks local login-capable user accounts that are not on an
  allowlist, removes supplementary groups, and backs up/removes their SSH
  authorized key files.
- `run_all.sh`: host-side runner that executes the three hardening scripts in
  the intended order.
- `deploy/coordinate_deploy.sh`: Coordinate deployment wrapper for concurrent
  remote execution.
- `setup.sh`: operator-box bootstrap script that installs Coordinate
  and clones this repository.

## Remote Deployment With Coordinate

1. On the operator box, run the bootstrap script:

   ```sh
   sh ./setup.sh
   ```

   If you are starting from a clean machine and do not have this repo yet, fetch
   and run the script directly:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/SocomX1/CCDC-Resources/main/setup.sh | sh
   ```

   The script installs missing `git`/Go build dependencies where supported,
   builds Coordinate into `/usr/local/bin` when root/sudo is available, and
   clones this repo to `$HOME/CCDC-Resources`. If it cannot use a system binary
   directory, it falls back to `$HOME/.local/bin`.

2. Enter the resources repo:

   ```sh
   cd "$HOME/CCDC-Resources"
   ```

3. Edit `deploy/allowlist.txt` so it contains the authorized/PCR accounts for the
   target systems.
4. Edit the public key in `failsafe_creator.sh`. This is the public key that will be used for root authentication.
   The script fails if the resulting `failsafe` account cannot use sudo non-interactively.
5. Make sure Coordinate is available:

   ```sh
   coordinate -h
   ```

   If the script used the `$HOME/.local/bin` fallback and `coordinate` is not
   found in the current terminal, run:

   ```sh
   export PATH="$HOME/.local/bin:$PATH"
   ```

   The setup script also adds this local PATH entry to `$HOME/.profile` for
   future shells when the fallback path is used.

6. Run Coordinate with the supplied root password:

   ```sh
   coordinate -y -t <targets> -u root -p 'DEFAULT_ROOT_PASSWORD' -T 90 deploy/coordinate_deploy.sh
   ```

You can target individual hosts, ranges, CIDRs, or hostnames:

```sh
coordinate -y -t 10.0.0.5,10.0.0.10-10.0.0.20,web01 -u root -p 'DEFAULT_ROOT_PASSWORD' -T 90 deploy/coordinate_deploy.sh
```

Security note: passing `-p` can expose the password in shell history and process
arguments. If operationally possible, omit `-p` and let Coordinate prompt for the
password interactively:

```sh
coordinate -y -t 10.0.0.0/24 -u root -T 90 deploy/coordinate_deploy.sh
```

The Coordinate wrapper creates `/tmp/ccdc` on each target, drops the scripts and
allowlist there, then runs:

```sh
sh /tmp/ccdc/run_all.sh /tmp/ccdc/allowlist.txt
```

On each target, the hardening sequence:

- creates or verifies the `failsafe` admin account
- verifies `failsafe` has usable passwordless sudo
- locks the root password
- disables SSH root login using an `sshd_config.d` drop-in when included, or a
  managed main `sshd_config` update otherwise
- backs up and clears root SSH authorized key files
- locks non-allowlisted local login-capable users
- removes supplementary groups from those users
- backs up and removes their `authorized_keys` and `authorized_keys2` files

## Local Usage

Create an allowlist containing one authorized local account per line:

```text
alice
bob
failsafe
```

Then run the full hardening sequence as root:

```sh
sh ./run_all.sh ./deploy/allowlist.txt
```

`run_all.sh` executes `failsafe_creator.sh`, `root_locker.sh`, and
`user_locker.sh --yes` in that order.

`user_locker.sh` still supports interactive review by default:

```sh
sh ./user_locker.sh ./deploy/allowlist.txt
```

For automation, use `--yes`:

```sh
sh ./user_locker.sh --yes ./deploy/allowlist.txt
```

Useful `user_locker.sh` options:

```text
-y, --yes              run without interactive review or confirmation
-n, --dry-run          print target accounts without changing the system
    --exclude USERS    comma-separated usernames to exclude from lockdown
    --admin USERNAME   admin account to always exclude; default is failsafe
```

## Notes

- Run a dry run on one representative host before broad deployment:

  ```sh
  sh ./user_locker.sh --dry-run ./deploy/allowlist.txt
  ```

- `root_locker.sh` is intended to run after `failsafe_creator.sh` so an alternate
  admin path exists before root is locked. `run_all.sh` enforces this order.
- `user_locker.sh` always skips `root` and the configured admin account.
- The scripts create timestamped `.bak.YYYYMMDD-HHMMSS` backups before editing
  sensitive account, sudoers, SSH config, and authorized key files.
