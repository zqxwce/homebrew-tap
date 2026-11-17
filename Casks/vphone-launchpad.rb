cask "vphone-launchpad" do
  # "<launchpad>,<bundle>". Only notarized Launchpad builds open under
  # Gatekeeper and not every release ships one, so Launchpad is pinned to the
  # newest `-notarized` asset; the bundle is the newest release of its minor.
  version "2.17.1,2.17.1"
  sha256 "c501d33e1e4d94a9a45595567045c255f928388c360916fc08820a06e2348dfc"

  url "https://github.com/Lakr233/vphone-cli/releases/download/#{version.csv.first}/vphone-launchpad-#{version.csv.first}-notarized.zip"
  name "vphone Launchpad"
  desc "Create, manage and run virtual iPhones"
  homepage "https://github.com/Lakr233/vphone-cli"

  livecheck do
    url :url
    strategy :github_releases do |json|
      assets = json.reject { |release| release["draft"] || release["prerelease"] }
                   .flat_map { |release| release["assets"]&.map { |asset| asset["name"] } || [] }
      launchpad = assets.filter_map { |name| name[/^vphone-launchpad[._-]v?(\d+(?:\.\d+)+)-notarized\.zip$/i, 1] }
                        .max_by { |v| Version.new(v) }
      next if launchpad.nil?

      bundle = assets.filter_map { |name| name[/^VPhone[._-]v?(\d+(?:\.\d+)+)\.zip$/i, 1] }
                     .select { |v| Version.new(v).major_minor == Version.new(launchpad).major_minor }
                     .max_by { |v| Version.new(v) }
      next if bundle.nil?

      "#{launchpad},#{bundle}"
    end
  end

  depends_on arch: :arm64
  depends_on macos: :sequoia # macOS 15+

  app "vphone-launchpad.app"
  binary "#{appdir}/vphone-launchpad.app/Contents/MacOS/vphone-launchpad-cli"

  # Install Launchpad's privileged helper as its SMJobBless call does (the app's
  # helper binary plus its embedded launchd plist with Program added), so Host
  # Setup does not have to after every install and upgrade.
  #
  # Then install the pinned VPhone.bundle into Launchpad's root-owned bundle
  # store, laid out as Launchpad's helper does (Bundles/<version>/VPhone.bundle
  # plus a receipt), and make it the default. Older bundles are kept: machines
  # stay bound to theirs. Non-fatal: never block install.
  #
  # Steps take literals only: on a bump, update the bundle version (2.17.1) and
  # the sha256 of VPhone-<bundle>.zip below along with `version`.
  postflight_steps do
    write_file "com.vphone.launchpad.helper.plist", <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>com.vphone.launchpad.helper</string>
        <key>MachServices</key>
        <dict>
          <key>com.vphone.launchpad.helper</key>
          <true/>
        </dict>
        <key>Program</key>
        <string>/Library/PrivilegedHelperTools/com.vphone.launchpad.helper</string>
        <key>ProgramArguments</key>
        <array>
          <string>/Library/PrivilegedHelperTools/com.vphone.launchpad.helper</string>
        </array>
      </dict>
      </plist>
    XML
    run "/bin/launchctl",
        args:         ["bootout", "system/com.vphone.launchpad.helper"],
        sudo:         true,
        must_succeed: false,
        print_stderr: false
    run "/usr/bin/install",
        args:         ["-o", "root", "-g", "wheel", "-m", "0544",
                       "{{appdir}}/vphone-launchpad.app/Contents/Library/LaunchServices/com.vphone.launchpad.helper",
                       "/Library/PrivilegedHelperTools/com.vphone.launchpad.helper"],
        sudo:         true,
        must_succeed: false
    run "/usr/bin/install",
        args:         ["-o", "root", "-g", "wheel", "-m", "0644",
                       "{{staged_path}}/com.vphone.launchpad.helper.plist",
                       "/Library/LaunchDaemons/com.vphone.launchpad.helper.plist"],
        sudo:         true,
        must_succeed: false
    run "/bin/launchctl",
        args:         ["bootstrap", "system", "/Library/LaunchDaemons/com.vphone.launchpad.helper.plist"],
        sudo:         true,
        must_succeed: false
    remove "com.vphone.launchpad.helper.plist"

    unless_path_exists "/Library/Application Support/vphone-launchpad/Bundles/2.17.1" do
      run "/usr/bin/curl",
          args:           ["--fail", "--location", "--silent", "--show-error",
                           "--output", "{{staged_path}}/VPhone.zip",
                           "https://github.com/Lakr233/vphone-cli/releases/download/2.17.1/VPhone-2.17.1.zip"],
          network_access: true,
          must_succeed:   false
      # Verify, extract, and write the receipt Launchpad's helper checks.
      run "/bin/zsh",
          args:         ["-ec", <<~'ZSH', "zsh", "{{staged_path}}", "2.17.1",
            dir=$1 version=$2 sha256=$3
            trap 'print -u2 -- "Could not install VPhone.bundle $version into Launchpad; install it from Core Bundle in the window instead."' ZERR
            print -r -- "$sha256  $dir/VPhone.zip" | /usr/bin/shasum -a 256 -c -s
            /usr/bin/ditto -x -k "$dir/VPhone.zip" "$dir/VPhone"
            cdhash() {
              /usr/bin/codesign -dvvv "$dir/VPhone/VPhone.bundle/Contents/MacOS/$1" 2>&1 | /usr/bin/sed -n 's/^CDHash=//p'
            }
            cli=$(cdhash vphone-cli) vm=$(cdhash vphone-vm)
            [[ -n $cli && -n $vm ]]
            print -r -- "{
              \"cdhashes\": { \"vphone-cli\": \"$cli\", \"vphone-vm\": \"$vm\" },
              \"installedAt\": \"$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)\",
              \"sha256\": \"$sha256\",
              \"version\": \"$version\"
            }" > "$dir/VPhone/receipt.json"
          ZSH
                         "3aa6b4e97278b2fa4d0cede80569f135316310d69daf75ecd5a4ccfdd0b317e9"],
          must_succeed: false
      if_path_exists "VPhone/receipt.json" do
        run "/bin/mkdir",
            args:         ["-p", "/Library/Application Support/vphone-launchpad/Bundles/2.17.1"],
            sudo:         true,
            must_succeed: false
        run "/usr/bin/ditto",
            args: ["{{staged_path}}/VPhone/VPhone.bundle",
                   "/Library/Application Support/vphone-launchpad/Bundles/2.17.1/VPhone.bundle"],
            sudo: true, must_succeed: false
        run "/bin/cp",
            args: ["{{staged_path}}/VPhone/receipt.json",
                   "/Library/Application Support/vphone-launchpad/Bundles/2.17.1/receipt.json"],
            sudo: true, must_succeed: false
        run "/usr/sbin/chown",
            args: ["-R", "root:wheel", "/Library/Application Support/vphone-launchpad/Bundles/2.17.1"],
            sudo: true, must_succeed: false
      end
      remove ["VPhone.zip", "VPhone"], recursive: true
    end

    if_path_exists "/Library/Application Support/vphone-launchpad/Bundles/2.17.1/receipt.json" do
      run "/usr/bin/defaults",
          args:           ["write", "com.vphone.launchpad", "VPhoneLaunchpadActiveBundleVersion", "2.17.1"],
          writable_paths: ["~/Library/Preferences"]
    end
  end

  uninstall launchctl: "com.vphone.launchpad.helper",
            quit:      "com.vphone.launchpad",
            delete:    "/Library/PrivilegedHelperTools/com.vphone.launchpad.helper"

  zap trash: [
    "/Library/Application Support/vphone-launchpad",
    "~/Library/Application Support/vphone-launchpad",
    "~/Library/Caches/com.vphone.launchpad",
    "~/Library/HTTPStorages/com.vphone.launchpad",
    "~/Library/Logs/vphone-launchpad",
    "~/Library/Preferences/com.vphone.launchpad.plist",
  ]

  caveats <<~EOS
    On first launch, grant Developer Tools access in Host Setup. This cask
    installs Launchpad's helper itself.

    This cask also installs VPhone.bundle #{version.csv.second} into Launchpad and
    makes it the default. Upgrading adds newer bundles; old ones are kept, as
    machines are bound to them (also on uninstall; `--zap` removes them).
  EOS
end
