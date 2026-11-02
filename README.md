# zqxwce/homebrew-tap

Homebrew tap for the vPhone tools — boot and manage virtual iPhones via Apple's
Virtualization.framework.

## vphone-launchpad

[Launchpad](https://github.com/Lakr233/vphone-cli) — the macOS app that creates,
manages and runs virtual iPhones.

```bash
brew install zqxwce/tap/vphone-launchpad
```

The cask tracks the newest **notarized** Launchpad (not every release ships
one; a non-notarized build will not open), together with the newest
`VPhone.bundle` of the same major version, which it installs into Launchpad's
bundle store as the default. Upgrading adds newer bundles and keeps the old
ones. It also puts `vphone-launchpad-cli` on your PATH.
Host Setup (Developer Tools access, the helper) is still done in the app on
first launch.

## vphone-cli

`VPhone.bundle` — the core bundle that Launchpad drives, for terminal use.

```bash
brew install zqxwce/tap/vphone-cli
```

The bundle stays in the Caskroom; `vphone-cli`, `vphone-vm` and
`vphone-escalator` from its `Contents/MacOS/` are linked onto your PATH.
Relaxing SIP/AMFI is a manual step — see the cask caveats and the
[host setup guide](https://github.com/Lakr233/vphone-cli/blob/main/Documents/Guides/host-setup.md).

## vphone-cli-legacy

The 1.x `vphone-cli.app` (1.0.14). VMs created by 1.x do not start in 2.x.

```bash
brew install zqxwce/tap/vphone-cli-legacy
```

It conflicts with `vphone-cli` (both provide the `vphone-cli` command).

## vphone-ws

[`vphone-ws`](https://github.com/zqxwce/vphone-ws) — vPhone Workstation, the
native macOS GUI front-end for `vphone-cli`.

```bash
brew install zqxwce/tap/vphone-ws
```

It depends on `vphone-cli-legacy`, so Homebrew installs that automatically as
part of the same command.

> **Note — Apple quarantine.** The app is ad-hoc signed (not notarized), so under
> Homebrew's quarantine flag macOS refuses to open it with the "'vphone-ws.app'
> is damaged and can't be opened" Gatekeeper error. Homebrew has since removed
> the `--no-quarantine` install flag, so the cask includes a `postflight` script
> that clears the `com.apple.quarantine` attribute on install, letting the app
> launch normally.
