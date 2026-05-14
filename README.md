# CCDC-Resources

## About

This project is intended to serve as a framework for automating the hardening of CCDC Linux systems. In the event that future Cyber Defense Team generations are interested in using this, feel free to fork the repository and merge it into https://github.com/SDSU-Cyber-Defense-Team/competitions-info (or whatever repo you guys are using to host CCDC stuff on). If you wish to add additional automation, simply create a new .sh file and edit `run_all.sh` and `coordinate_deploy.sh` to include logic for executing it.

Created by Alexander Zucker as a project for the Spring CS 574 course.

### Problem Statement

As we learned from the 2025-2026 WRCCDC season, effective performance in this competition requires automation. The red team obtains default credentials at or very shortly after they are distributed to the blue team, and they begin leveraging them to launch attacks by minute 20. This necessitates the ability to remove default credentials across the entire environment without having to interact with each host manually. Additionally, we cannot afford to waste time performing tasks like establishing our failsafe administrator account or pruning extraneous local users.

### Tech Stack

- Shell scripts use `/usr/bin/env sh` as their shebang. It is important that these scripts be as portable as possible across Linux distributions and versions, so I opted for `sh` over `bash`.
- Coordinate (https://git.sr.ht/~sourque/coordinate) is used to handle remote deployment of the scripts.
  - Coordinate is written in Go, which `setup.sh` will attempt to automatically install if necessary.
- Git is used by `setup.sh` to clone this repository and the Coordinate repository.

### Components

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
4. Edit the global variable `PUBKEY=` in `failsafe_creator.sh`. This is the public key that
   will be used for `failsafe` authentication. DO NOT FORGET TO SET THIS, OR YOU WILL HAVE A VERY BAD TIME.
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

6. Run Coordinate. If prompting for the root password causes problems, specify
   the password by adding `-p <password>` to the command.

   ```sh
   coordinate -y -t <targets> -u root -T 90 deploy/coordinate_deploy.sh
   ```

### Notes

You can target individual hosts, ranges, CIDRs, or hostnames:

```sh
coordinate -y -t 10.0.0.5,10.0.0.10-10.0.0.20,web01 -u root -T 90 deploy/coordinate_deploy.sh
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

In the event that remote deployment via Coordinate fails, it is still possible to
execute the scripts locally on each host.

1. Edit `deploy/allowlist.txt` so it contains the authorized/PCR accounts for
   the target system.

2. Edit the public key in `failsafe_creator.sh`.

3. Run the full hardening sequence as root:

   ```sh
   sh ./run_all.sh ./deploy/allowlist.txt
   ```

   `run_all.sh` executes `failsafe_creator.sh`, `root_locker.sh`, and
   `user_locker.sh --yes` in that order.

4. To run only the user-locking step with interactive review:

   ```sh
   sh ./user_locker.sh ./deploy/allowlist.txt
   ```

5. To run only the user-locking step without interactive review:

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
