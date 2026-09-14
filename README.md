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
Dropbox repositories folder), links all dotfiles with stow, repairs the SSH key
permissions Dropbox does not preserve, installs the MonoLisa fonts, and
verifies every link.

Anything already in `$HOME` that would collide with a stowed file is moved to
`scripts/stow-backups/<timestamp>/` rather than silently overwritten.

**Phase 3** — the manual leftovers:

  - Import Raycast settings from `assets/raycast.rayconfig`.
  - Check `ssh -T git@github.com` works, then `git log --show-signature -1` to
    confirm commit signing.
  - Restart to let the remaining macOS defaults take effect.

## Fresh macOS install
This repository assumes we're working with a fresh OS install, but before we go formatting drives, we should make sure we didn't forget anything, like:

### Before you install

  - Did you commit and push any changes/branches to your git repositories?
  - **Did you push this repository?** Phase 1 clones `master` from GitHub, so
    any unpushed fix to `scripts/` will not run on the new machine.
  - Did you run `scripts/update-brewfile.sh` and commit the result, so the
    Brewfile matches what is actually installed?
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