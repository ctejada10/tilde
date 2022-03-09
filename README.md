# Carlos' Dotfiles

Your dotfiles is how you personalize your system. These are mine.

I use this repository to set up all my computers, Ubuntu and macOS, from a fresh install. Everything needed to install my preferred setup of macOS is detailed in this readme. As Holman said, [dotfiles are meant to be forked.](https://zachholman.com/2010/08/dotfiles-are-meant-to-be-forked/)

## Fresh macOS install
This repository assumes we're working with a fresh OS install, but before we go formatting drives, we should make sure we didn't forget anything, like:

### Before you install

  - Did you commit and push any changes/branches to your git repositories?
  - Did you remember to save all important documents from non-iCloud directories?
  - Did you save all of your work from apps which aren't synced through iCloud?
  - Did you remember to export important data from your local database?
  - Did you update [mackup](https://github.com/lra/mackup) to the latest version and ran `mackup backup`?

### Installing macOS

After going to our checklist above and making sure you backed everything up, we're going to cleanly install macOS with the latest release. Follow [this article](https://www.imore.com/how-do-clean-install-macos) to cleanly install the latest macOS version.

### Setting up

Once we have our freshly installed Mac, we can proceed to install our dotfiles. To do so, we:

  1. Update macOS.
  2. [Generate a new public and private SSH key](https://help.github.com/en/github/authenticating-to-github/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent) and add them to Github.
  3. Clone this repo.
  4. Run `scripts/macos` to setup and install pertinent apps and binaries.
  5. After mackupris synced with your cloud storage, restore preferences by running `mackup restore`.
  6. Restart your computer to finalize the process.

## Inspiration
I took inspiration from various sources to build this setup. These are
some:

  - [This](https://www.reddit.com/r/unixporn/comments/5vke7s/osx_iterm2_tmux_vim/) reddit post inspired my tmux setup.
  - [Drie's dotfiles](https://github.com/driesvints/dotfiles) have very cool stuff.
  - [Holman did dotfiles](https://github.com/holman/dotfiles), and he did it well.