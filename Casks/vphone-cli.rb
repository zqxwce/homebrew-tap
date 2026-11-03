cask "vphone-cli" do
  version "2.15.0"
  sha256 "ffc0dd8124f83d116586c6c554b8f4852b9185f1d406a18ef2ebdb60fc75d426"

  url "https://github.com/Lakr233/vphone-cli/releases/download/#{version}/VPhone-#{version}.zip"
  name "VPhone.bundle"
  desc "Core bundle for booting virtual iPhones: vphone-cli, vphone-vm, vphone-escalator"
  homepage "https://github.com/Lakr233/vphone-cli"

  livecheck do
    url :url
    strategy :github_latest
  end

  conflicts_with cask: "zqxwce/tap/vphone-cli-legacy"
  depends_on arch: :arm64
  depends_on macos: :sequoia # macOS 15+

  # VPhone.bundle is not an app, so it stays in the Caskroom; only its
  # executables are linked onto the PATH. They resolve their frameworks and
  # resources through the symlink, so the bundle must stay intact.
  binary "VPhone.bundle/Contents/MacOS/vphone-cli"
  binary "VPhone.bundle/Contents/MacOS/vphone-escalator"
  binary "VPhone.bundle/Contents/MacOS/vphone-vm"

  # The bundle is ad-hoc signed (not notarized), so quarantined executables are
  # refused by Gatekeeper. Use the absolute Apple xattr — a shadowing `xattr`
  # without `-r` may be earlier on PATH. Non-fatal: never block install.
  postflight do
    system_command "/usr/bin/xattr",
                   args:         ["-r", "-d", "com.apple.quarantine", "#{staged_path}/VPhone.bundle"],
                   must_succeed: false,
                   print_stderr: false
  end

  zap trash: [
    "~/.vphone",
    "~/Library/Preferences/com.vphone.bundle.plist",
  ]

  caveats <<~EOS
    This installs VPhone.bundle for terminal use. vphone-launchpad keeps its
    own copies of the bundle and does not use this one.

    vphone-vm carries private entitlements, so the host must be relaxed in
    Recovery first — pick ONE path (both need research guests):
         # A (most permissive):
         csrutil disable && csrutil allow-research-guests enable
         #   then, back in macOS:
         sudo nvram boot-args="amfi_get_out_of_my_way=1 -v"   # reboot after
         # B (minimal):
         csrutil enable --without debug && csrutil allow-research-guests enable
         #   then allowlist this build's vphone-vm through amfid:
         sudo vphone-escalator allow #{staged_path}/VPhone.bundle/Contents/MacOS/vphone-vm

    VMs created by 1.x do not start in 2.x; use vphone-cli-legacy for those.
    VMs live under ~/.vphone.

    Full guide: https://github.com/Lakr233/vphone-cli/blob/main/Documents/Guides/host-setup.md
  EOS
end
