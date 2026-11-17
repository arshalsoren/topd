# Install and run

## Requirements

- macOS 14 or later
- Xcode Command Line Tools: `xcode-select --install`

## Steps

```sh
git clone https://github.com/arshalsoren/topd.git
cd topd
./run.sh
```

`run.sh` builds a release app, wraps it as `.build/topd.app`, signs it locally, and starts it.
The first build takes a few minutes. Look for the topd icon in the menu bar. There is no Dock icon.

## Stop, restart, update

```sh
pkill -x topd                       # stop
pkill -x topd; ./run.sh             # restart after changes
git pull && pkill -x topd; ./run.sh # update
```

## Optional alias

```sh
alias topd='/absolute/path/to/topd/run.sh'
```

Add it to `~/.zshrc`, then run `source ~/.zshrc`.
