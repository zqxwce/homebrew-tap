# zqxwce/homebrew-tap

Homebrew tap for the vPhone tools — boot and manage virtual iPhones via Apple's
Virtualization.framework.

## vphone-cli

[`vphone-cli`](https://github.com/Lakr233/vphone-cli) — the command-line tool.

```bash
brew install zqxwce/tap/vphone-cli
```

This installs `vphone-cli.app` and puts the `vphone-cli` command on your PATH.
The runtime tools it shells out to (`ipsw`, `gtar`, `ldid`, `zstd`, `aria2c`,
`sshpass`, `keystone`, …) are declared as cask dependencies, so Homebrew installs
them automatically. Relaxing SIP/AMFI is still a manual step — see the cask
caveats (shown on install) and the
[project README](https://github.com/Lakr233/vphone-cli).

## vphone-ws

[`vphone-ws`](https://github.com/zqxwce/vphone-ws) — vPhone Workstation, the
native macOS GUI front-end for `vphone-cli`.

```bash
brew install zqxwce/tap/vphone-ws
```

It depends on `vphone-cli`, so Homebrew installs that automatically as part of
the same command.

> **Note — Apple quarantine.** The app is ad-hoc signed (not notarized), so under
> Homebrew's quarantine flag macOS refuses to open it with the "'vphone-ws.app'
> is damaged and can't be opened" Gatekeeper error. Homebrew has since removed
> the `--no-quarantine` install flag, so the cask includes a `postflight` script
> that clears the `com.apple.quarantine` attribute on install, letting the app
> launch normally.
