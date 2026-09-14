# Carlos' Dotfiles

Your dotfiles is how you personalize your system. These are mine.

I use this repository to set up all my computers, Ubuntu and macOS, from a fresh install. Everything needed to install my preferred setup of macOS is detailed in this readme. As Holman said, [dotfiles are meant to be forked.](https://zachholman.com/2010/08/dotfiles-are-meant-to-be-forked/)

## Bootstrap

**Phase 1** — open Terminal on the fresh machine and run:

```sh
curl -fsSL https://raw.githubusercontent.com/ctejada10/tilde/master/setup.sh | bash
```

This installs Xcode CLT and Homebrew, installs everything in the Brewfile
(binaries, casks, fonts, Mac App Store apps, VS Code extensions — Dropbox
included), installs oh-my-zsh, and applies the macOS defaults.

Mac App Store apps need you to be signed in to the App Store. If you were not,
sign in and re-run:

```sh
brew bundle install --file=~/Repositories/tilde/scripts/Brewfile
```

**Phase 2** — sign into Dropbox, wait for `repositories/` to finish syncing, then:

```sh
bash ~/Library/CloudStorage/Dropbox/repositories/tilde/scripts/finish.sh
```

This creates the `~/Repositories` and `~/src` symlinks (both pointing at the
Dropbox repositories folder), restores the SSH keys from `secrets/` (see
below), links all dotfiles with stow, installs the MonoLisa fonts, and verifies
every link.

Anything already in `$HOME` that would collide with a stowed file is moved to
`scripts/stow-backups/<timestamp>/` rather than silently overwritten.

**Phase 3** — the manual leftovers:

  - Import Raycast settings from `assets/raycast.rayconfig`.
  - Check `ssh -T git@github.com` works, then `git log --show-signature -1` to
    confirm commit signing.
  - Restart to let the remaining macOS defaults take effect.

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

## Fresh macOS install
This repository assumes we're working with a fresh OS install, but before we go formatting drives, we should make sure we didn't forget anything, like:

### Before you install

  - Did you commit and push any changes/branches to your git repositories?
  - **Did you push this repository?** Phase 1 clones `master` from GitHub, so
    any unpushed fix to `scripts/` will not run on the new machine.
  - Did you run `scripts/update-brewfile.sh` and commit the result, so the
    Brewfile matches what is actually installed?
  - **Did you run `scripts/secrets.sh op-store`?** The age key exists only on
    this machine. Without it in 1Password, `secrets/` is unrecoverable and the
    SSH keys are gone.
  - Did you re-run `scripts/secrets.sh seal` after changing any key?
  - Does `bash tests/run.sh` pass?
  - Did you remember to save all important documents from non-iCloud directories?
  - Did you save all of your work from apps which aren't synced through iCloud?
  - Did you remember to export important data from your local database?

### Installing macOS

After going to our checklist above and making sure you backed everything up, we're going to cleanly install macOS with the latest release. Follow [this article](https://www.imore.com/how-do-clean-install-macos) to cleanly install the latest macOS version.

## Inspiration
I took inspiration from various sources to build this setup. These are
some:

  - [This](https://www.reddit.com/r/unixporn/comments/5vke7s/osx_iterm2_tmux_vim/) reddit post inspired my tmux setup.
  - [Drie's dotfiles](https://github.com/driesvints/dotfiles) have very cool stuff.
  - [Holman did dotfiles](https://github.com/holman/dotfiles), and he did it well.