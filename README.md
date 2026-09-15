# Carlos' Dotfiles

Your dotfiles is how you personalize your system. These are mine.

I use this repository to set up all my computers, Ubuntu and macOS, from a fresh install. Everything needed to install my preferred setup of macOS is detailed in this readme. As Holman said, [dotfiles are meant to be forked.](https://zachholman.com/2010/08/dotfiles-are-meant-to-be-forked/)

## Before you erase anything

These steps cannot be done after the drive is wiped. Work down the list on the
old machine.

| # | Do this | Why it is irreversible |
|---|---------|------------------------|
| 1 | `git push origin master` | Phase 1 clones `master` from GitHub. Anything unpushed does not exist on the new machine. |
| 2 | `scripts/update-brewfile.sh` then commit | The Brewfile is the only record of what was installed. |
| 3 | `scripts/secrets.sh seal` then commit | Encrypts `dotfiles/ssh/.ssh` into `secrets/ssh.enc.json`. Only needed if a key changed, but harmless to repeat. |
| 4 | `scripts/secrets.sh lock-key` then commit | Encrypts the age key under your passphrase. **Without this the sealed secrets cannot be opened.** |
| 5 | `scripts/secrets.sh unlock-key` | Proves the passphrase you think you memorised is the one that works. Do it now, not tomorrow. |
| 6 | `scripts/secrets.sh op-store` | Puts the age key in 1Password as the backup route for a forgotten passphrase. |
| 7 | `bash tests/run.sh` and `bash tests/idempotence.sh` | 113 checks between them. Both should end `all passed`. |
| 8 | Put your 1Password Emergency Kit somewhere **not this laptop** | Account password + Secret Key are needed to sign into 1Password on the new machine. Printed, on your phone, or on another signed-in device. |

Write down your age public key so you can recognise a good restore:

```
age1qmu9ttwq35eqa34yl65368u83g98meaqk4pdgw6wkaq6d9e5mdtq3njavr
```

Also worth checking, unrelated to this repo: pushed branches in every other
repo, documents outside iCloud, anything exported from a local database.

## Restoring a machine from scratch

Five phases. Budget an hour, most of it waiting on downloads.

### Phase 1 — bootstrap

Fresh macOS, connected to wifi, signed into iCloud. Open **Terminal** — Ghostty
is not installed yet — and run:

```sh
curl -fsSL https://raw.githubusercontent.com/ctejada10/tilde/master/setup.sh | bash
```

In order, this:

1. Installs the Xcode Command Line Tools. **A dialog appears — click Install.**
   The script waits for it to finish.
2. Clones this repo to a temp directory.
3. Runs `scripts/macos`, which:
   - **asks for your admin password** and keeps the sudo timestamp alive,
   - installs Homebrew (non-interactive; it adds itself to the PATH),
   - installs everything in the Brewfile — 140-odd formulae, casks, fonts, Mac
     App Store apps and VS Code extensions. This is the slow part.
   - installs oh-my-zsh, then deletes the template `.zshrc` it leaves behind so
     stow can link the real one,
   - applies the macOS defaults, reporting each as `set` or leaving it alone if
     it already matches,
   - creates `~/Downloads/Documents`, `~/Downloads/Media/Images` and
     `~/Downloads/Media/Videos`,
   - restarts Finder, Dock and friends.

**Mac App Store apps will fail if you are not signed into the App Store.** That
is expected and does not stop the run. Sign in, then:

```sh
brew bundle install --file=~/Repositories/tilde/scripts/Brewfile
```

You will be told when phase 1 is done and what to do next.

### Phase 2 — Dropbox

Dropbox was installed by the Brewfile. Open it, sign in, and **wait for
`repositories/` to finish syncing completely.** A partial sync looks like a
successful one and produces confusing failures later. The Dropbox menu bar icon
should show no activity, and `~/Library/CloudStorage/Dropbox/repositories/tilde`
should contain `scripts/`, `dotfiles/` and `secrets/`.

### Phase 3 — dotfiles and keys

```sh
bash ~/Library/CloudStorage/Dropbox/repositories/tilde/scripts/finish.sh
```

It refuses to start if Dropbox has not synced, so a premature run is safe.

In order, it:

1. Puts Homebrew on the PATH. Phase 3 runs before `~/.zshrc` exists, so `stow`
   is not otherwise findable.
2. Creates `~/Repositories` and `~/src`, both pointing at the Dropbox
   repositories folder.
3. Restores the executable bits Dropbox does not preserve.
4. **Restores the SSH keys.** You get one prompt:

   ```
   Restoring SSH keys from the encrypted copy in git...
   Unlocking the age key from secrets/age-key.age
   Enter passphrase:
   ```

   Type the passphrase you memorised. On success:

   ```
     wrote arnor (600)
     wrote arnor.pub (644)
     wrote arnor_claude (600)
     wrote arnor_signing (600)
     wrote arnor_signing.pub (644)
     wrote known_hosts (644)
   Restored from git.
   ```

   If the passphrase fails it falls through to 1Password — see
   [If something goes wrong](#if-something-goes-wrong).
5. Links every dotfile with stow. Anything already in `$HOME` that would
   collide is moved to `scripts/stow-backups/<timestamp>/`, never overwritten.
6. Fixes the SSH key permissions, which Dropbox does not preserve and which
   `ssh` refuses to work without.
7. Links the Ghostty config into `~/Library/Application Support/`, so Ghostty
   finds it whichever of its two config locations it prefers.
8. Installs the MonoLisa fonts into `~/Library/Fonts`.
9. **Restores application settings** for the apps that sync nothing of their
   own. Anything not yet installed, or currently running, is skipped rather
   than clobbered — re-run `scripts/app-prefs.sh restore` afterwards to pick
   those up.
10. Verifies every link and prints `ok` or `MISSING` for each.

**It exits non-zero if anything is missing.** A setup that looks fine but has
no SSH keys is exactly the failure this catches, so read the last few lines.

### Phase 4 — verify

```sh
ssh -T git@github.com
```
→ `Hi ctejada10! You've successfully authenticated...`

```sh
git -C ~/Repositories/tilde log --show-signature -1
```
→ the signature line should show your key, and `git log --format='%G?' -1`
should print `G`.

```sh
bash ~/Repositories/tilde/scripts/macos --check
```
→ a dry run. It writes nothing. A freshly configured machine should report few
or no `would set` lines; a long list means phase 1 did not finish.

```sh
bash ~/Repositories/tilde/tests/run.sh
```
→ `all passed`.

Open a new terminal. The prompt should be the minimal theme, `ls` should be
`eza`, and `cat` should be `bat`.

### Phase 5 — the things no script can do

- **Grant Full Disk Access** to anything that watches folders. macOS will not
  let a script do this.
- Import Raycast settings from `assets/raycast.rayconfig`.
- Sign into 1Password, Adobe, Slack, Zoom and the rest.
- Restart, so the remaining macOS defaults take effect.

## If something goes wrong

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Error: ~/Library/CloudStorage/Dropbox/repositories/tilde not found` | Dropbox has not synced yet | Wait for it to finish, then re-run `finish.sh`. |
| `Error: stow not found` | Phase 1 did not complete, so Homebrew is missing | Re-run phase 1. |
| `could not decrypt the age key - wrong passphrase?` | Mistyped or forgotten passphrase | It falls through to 1Password automatically. If that also fails, see the next row. |
| `1Password CLI is not connected to the desktop app yet` | The CLI integration is off | Open 1Password, sign in with your Emergency Kit, then Settings → Developer → tick **Integrate with 1Password CLI**. Re-run `scripts/secrets.sh bootstrap`. |
| `could not read '<item>' from vault` | The age key was never stored | You are relying on the passphrase alone. If that is also gone, the sealed secrets are unrecoverable — generate new SSH keys and re-register them with GitHub. |
| `MISSING ~/.ssh/arnor` and a non-zero exit | The secrets restore failed but stow continued | Fix the secrets step, run `scripts/secrets.sh bootstrap`, then `finish.sh` again. It is safe to re-run. |
| `Error: ~/Repositories exists but is not a symlink` | A real directory is in the way | Move it aside, then re-run. |
| Mac App Store apps missing | Not signed into the App Store | Sign in, then `brew bundle install --file=~/Repositories/tilde/scripts/Brewfile`. |
| A dotfile you expected is a plain file, not a link | stow found a conflict and backed it up | Look in `scripts/stow-backups/<timestamp>/`. Nothing is deleted. |

Everything in phases 2 to 5 is safe to re-run. `finish.sh`, `.stow`,
`secrets.sh bootstrap` and `unseal` are covered by `tests/idempotence.sh`,
which runs each of them repeatedly and compares the resulting tree down to
link targets, permissions and content hashes. `scripts/macos` re-applies only
what has drifted, and `--check` shows you that without writing anything.

Re-running fixes what is broken and leaves the rest alone.

## Secrets

The SSH keys live in this repo, encrypted with [sops](https://github.com/getsops/sops)
and [age](https://github.com/FiloSottile/age), in `secrets/ssh.enc.json`. Field
names are readable so you can see what is stored; the values are not.

The age key that decrypts them is kept in 1Password and nowhere else:

```sh
scripts/secrets.sh status      # what is configured
scripts/secrets.sh seal        # encrypt dotfiles/ssh/.ssh into secrets/
scripts/secrets.sh lock-key    # encrypt the age key under a memorised passphrase
scripts/secrets.sh op-store    # also save the age key to 1Password, as backup
scripts/secrets.sh bootstrap   # on a new machine: get the key, decrypt everything
```

`bootstrap` finds the age key by the cheapest route available:

1. a key already on the machine,
2. `secrets/age-key.age`, unlocked with the passphrase you memorised — one
   prompt, and it ships in the repo, so this works before Dropbox has synced
   and without touching 1Password,
3. 1Password, as the fallback if you ever forget the passphrase.

That first prompt is the only manual step. Everything after it is automatic.

**The passphrase protects a file that is public.** The ciphertext can be
attacked offline forever, so use a long one — six random words beats anything
short and clever. If you forget it, route 3 is what saves you, which is why
`op-store` is worth doing as well.

For the 1Password fallback route, the CLI has to be connected first: sign into
the desktop app, then tick **Settings → Developer → Integrate with 1Password
CLI**. After that `op` unlocks with Touch ID. That first app sign-in needs your
account password and Secret Key from your Emergency Kit and cannot be
automated — which is exactly why the passphrase route exists as the primary
path.

Set `OP_SERVICE_ACCOUNT_TOKEN` to skip the interactive path entirely, for a
scripted or CI rebuild.

## Application settings

Most apps sync their own settings through an account or iCloud. A handful keep
everything locally, and those are captured here:

```sh
scripts/app-prefs.sh status     # what is captured, and what is installed
scripts/app-prefs.sh capture    # read this machine's settings into secrets/
scripts/app-prefs.sh restore    # write them onto a new machine
```

Preference domains are exported with `defaults export` rather than symlinked,
because `cfprefsd` writes preference files atomically and would replace a
symlink with a real file. Stow is the wrong tool for plists.

The store is encrypted with the same age key as the SSH keys, because several
of these carry paid licence keys — AlDente's `paddleLicense`, CleanShot's
`activationKey`, Lunar's `apiKey` — and this repo is public.

**Restore refuses to touch an app that is missing or running.** A missing app
means Homebrew has not installed it yet, and a preference file written before
the app exists can be discarded on first launch. A running app is worse:
`cfprefsd` caches each domain, and the live app can flush its cached copy back
over the import, silently undoing it. Both cases are skips, not failures.

## Checking what the macOS script would do

```sh
scripts/macos --check
```

A real dry run: no writes, no sudo prompt. It reports which settings differ
from what the script wants, which ones already match, and which are applied
unconditionally. Useful on a working machine to see what has drifted.

## Tests

```sh
bash tests/run.sh
```

Runs against a throwaway `$HOME`; nothing touches the real one. Covers lint,
the Brewfile, the macOS script's ordering invariants, stow, `finish.sh` end to
end, the idempotent defaults wrappers, the secrets round trip, and a guard
against committing plaintext key material.

## Installing macOS

Once the checklist in [Before you erase anything](#before-you-erase-anything)
is done, clean install the latest macOS following
[this article](https://www.imore.com/how-do-clean-install-macos), then start at
[Phase 1](#phase-1--bootstrap).

## Inspiration
I took inspiration from various sources to build this setup. These are
some:

  - [This](https://www.reddit.com/r/unixporn/comments/5vke7s/osx_iterm2_tmux_vim/) reddit post inspired my tmux setup.
  - [Drie's dotfiles](https://github.com/driesvints/dotfiles) have very cool stuff.
  - [Holman did dotfiles](https://github.com/holman/dotfiles), and he did it well.