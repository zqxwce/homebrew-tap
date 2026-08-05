cask "vphone-cli" do
  version "1.0.5"
  sha256 "da59eb37fd62fdbb454208c41d94d871205ab36b68c6d59382d99ebf5f4847d1"

  url "https://github.com/Lakr233/vphone-cli/releases/download/#{version}/vphone-cli-#{version}.zip",
      verified: "github.com/Lakr233/vphone-cli/"
  name "vphone-cli"
  desc "Boot a virtual iPhone via Apple's Virtualization.framework"
  homepage "https://github.com/Lakr233/vphone-cli"

  depends_on macos: :sequoia # macOS 15+
  # Tap-qualified deliberately: a bare name makes Formulary.resolve load the
  # installed keg's own tap, which aborts the install for anyone holding a
  # third-party build (ipsw in blacktop/tap, sshpass in hudochenkov/sshpass).
  depends_on formula: [
    "homebrew/core/aria2",
    "homebrew/core/cmake",
    "homebrew/core/gnu-tar",
    "homebrew/core/ipsw",
    "homebrew/core/keystone",
    "homebrew/core/ldid-procursus",
    "homebrew/core/libusb",
    "homebrew/core/openssl@3",
    "homebrew/core/python@3.13",
    "homebrew/core/sshpass",
    "homebrew/core/wget",
    "homebrew/core/zstd",
  ]

  # Install the .app bundle, and expose its inner CLI + the amfid allowlist
  # helper on the PATH so `vphone-cli` and `vphone-amfidont` work from the
  # terminal.
  app "vphone-cli.app"
  binary "#{appdir}/vphone-cli.app/Contents/MacOS/vphone-cli"
  binary "#{appdir}/vphone-cli.app/Contents/Resources/vphone-amfidont"

  zap trash: "~/.vphone"

  caveats <<~EOS
    The runtime tools are installed for you as cask dependencies. vphone-cli
    boots a Virtualization.framework guest with private PV=3 entitlements, so
    one manual step is still required:

    Relax SIP/AMFI in Recovery — pick ONE path (the two settings pair up):
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
