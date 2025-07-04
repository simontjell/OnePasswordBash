# OnePasswordBash
A very simple bash function that helps find passwords using the 1Password CLI.

![Demo](demo_cropped.gif)
(This recording was made with [terminalizer](https://github.com/faressoft/terminalizer))

## Usage
```bash
opp Github
```

If there is a single match for 'Github', the password will be copied to the clipboard. If no clipboard utility is found, the raw password can be displayed by using an explicit flag:

```bash
opp Github --reveal
```

NOTE: If the `--reveal` flag is used, it disables clipboard functionality entirely and displays the raw password instead.

You can also extract TOTP (Time-based One-Time Password) codes:

```bash
opp Github --totp
```

This will copy the TOTP code to the clipboard, just like passwords.

If there are no matches, this is reported as an error.

If multiple matches are found, the items are provided as an indexed list. Use the index to get the specific item:

```bash
opp Github 2
```

An item can also be fetched with its full content:
```bash
opp Github 2 --raw
```

Or for a single match:
```bash
opp Github --raw
```

This will provide the item in JSON format.

You can also get TOTP codes from indexed matches:
```bash
opp Github 2 --totp
```

## Installation

This script requires the following dependencies:

- [1Password CLI (op)](https://developer.1password.com/docs/cli/): Used to access your 1Password vault from the command line.
- [jq](https://stedolan.github.io/jq/): For parsing JSON output from the 1Password CLI.
- [xclip](https://github.com/astrand/xclip) (Linux) or `pbcopy` (macOS): For copying passwords to the clipboard.

### Install on Linux
```bash
sudo apt install jq xclip # Debian/Ubuntu
# OR
sudo dnf install jq xclip # Fedora
# Download and install 1Password CLI from https://developer.1password.com/docs/cli/get-started/
```

### Install on macOS
```bash
brew install 1password-cli
brew install jq
```

### Install on Windows

1. Install [1Password CLI](https://developer.1password.com/docs/cli/get-started/) (download the Windows release and add it to your PATH).
2. Install [jq for Windows](https://stedolan.github.io/jq/download/).
3. For clipboard support, install [Win32yank](https://github.com/equalsraf/win32yank) or use [clip.exe](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/clip) (included in Windows 10+).


## Sourcing the script

After installing dependencies, source the script in e.g. your Bash profile:
```bash
source /path/to/opp.sh
```