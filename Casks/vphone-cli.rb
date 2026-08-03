cask "vphone-cli" do
  version "1.0.3"
  sha256 "96b65a2d778eac46407d3123256641ffa602dca2b1bee7368ceaf75a2860cee7"

  url "https://github.com/Lakr233/vphone-cli/releases/download/#{version}/vphone-cli-#{version}.zip",
      verified: "github.com/Lakr233/vphone-cli/"
  name "vphone-cli"
  desc "Boot a virtual iPhone via Apple's Virtualization.framework"
  homepage "https://github.com/Lakr233/vphone-cli"

  depends_on macos: :sequoia # macOS 15+

  # Install the .app bundle, and expose its inner CLI + the amfid allowlist
  # helper on the PATH so `vphone-cli` and `vphone-amfidont` work from the
  # terminal.
  app "vphone-cli.app"
  binary "#{appdir}/vphone-cli.app/Contents/MacOS/vphone-cli"
  binary "#{appdir}/vphone-cli.app/Contents/Resources/vphone-amfidont"

  zap trash: "~/.vphone"

  caveats <<~EOS
    vphone-cli boots a Virtualization.framework guest with private PV=3
    entitlements, so the host needs some one-time setup:

    1. Runtime tools (Homebrew — some come from third-party taps):
         brew install python@3.13 aria2 wget gnu-tar openssl@3 \\
           ldid-procursus sshpass keystone libusb ipsw zstd

    2. Relax SIP/AMFI in Recovery — pick ONE path (the two settings pair up):
         # A (most permissive):
         csrutil disable && csrutil allow-research-guests enable
         #   then, back in macOS:
         sudo nvram boot-args="amfi_get_out_of_my_way=1 -v"   # reboot after
         # B (minimal):
         csrutil enable --without debug && csrutil allow-research-guests enable
         #   then allowlist the app through amfid (installs amfidont if needed):
         vphone-amfidont

    On first use, vphone-cli provisions its own Python env at ~/.vphone/venv
    from a modern host python3 (3.11+); VMs live under ~/.vphone/VMs.
    Run `vphone-cli setup` to provision up front.

    The app is ad-hoc signed. If Gatekeeper blocks it, reinstall with:
         brew install --cask --no-quarantine vphone-cli

    Full guide: https://github.com/Lakr233/vphone-cli
  EOS
end
