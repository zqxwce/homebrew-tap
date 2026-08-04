cask "vphone-ws" do
  version "0.0.1"
  sha256 "36d67ed87c8d48242ae7519ccad6f26f9bc51aaecd0466b00ef8540228fa8599"

  # Release tags are prefixed with "v"; the asset filename uses the bare version.
  url "https://github.com/zqxwce/vphone-ws/releases/download/v#{version}/vphone-ws-#{version}.zip",
      verified: "github.com/zqxwce/vphone-ws/"
  name "vPhone Workstation"
  desc "Browse, create, and boot virtual iPhones from a single window"
  homepage "https://github.com/zqxwce/vphone-ws"

  depends_on macos: :sequoia # macOS 15+
  # GUI front-end for vphone-cli; installing vphone-ws pulls it in automatically.
  depends_on cask: "zqxwce/tap/vphone-cli"

  app "vphone-ws.app"

  # The app is ad-hoc signed (not notarized), so a quarantined launch hits the
  # "damaged" Gatekeeper wall. `--no-quarantine` was removed from Homebrew, so
  # strip the flag here instead. Use the absolute Apple xattr — a shadowing
  # `xattr` without `-r` may be earlier on PATH. Non-fatal: never block install.
  postflight do
    system_command "/usr/bin/xattr",
                   args:         ["-r", "-d", "com.apple.quarantine", "#{appdir}/vphone-ws.app"],
                   must_succeed: false,
                   print_stderr: false
  end

  zap trash: [
    "~/Library/Application Support/com.vphone.ws",
    "~/Library/Caches/com.vphone.ws",
    "~/Library/HTTPStorages/com.vphone.ws",
    "~/Library/Preferences/com.vphone.ws.plist",
    "~/Library/Saved Application State/com.vphone.ws.savedState",
  ]

  caveats <<~EOS
    vphone-ws is the GUI front-end for vphone-cli, which Homebrew installs
    automatically as a dependency. Complete vphone-cli's one-time host setup
    (SIP/AMFI relaxation, runtime tools) before creating VMs — see its caveats:
         brew info vphone-cli

    The app is ad-hoc signed (not notarized); this cask clears its quarantine
    flag on install so it opens without the "damaged" Gatekeeper prompt.
  EOS
end
