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
  # Steps take literals only, so the bundle version is cut from `{{version}}`
  # at install time. They run in Homebrew's sandbox (no network, no home
  # directory) unless `sudo: true`, hence `network_access:`/`writable_paths:`.
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
    run "/bin/sh",
        args:         ["-ec", <<~SH, "sh", "{{appdir}}/vphone-launchpad.app", "{{staged_path}}"],
          label=com.vphone.launchpad.helper
          trap '[ $? -eq 0 ] || echo "Warning: Could not install the Launchpad helper;" \
            "install it from Host Setup in the window instead." >&2' EXIT
          /usr/bin/install -o root -g wheel -m 0544 \
            "$1/Contents/Library/LaunchServices/$label" "/Library/PrivilegedHelperTools/$label"
          /usr/bin/install -o root -g wheel -m 0644 "$2/$label.plist" "/Library/LaunchDaemons/$label.plist"
          /bin/launchctl bootstrap system "/Library/LaunchDaemons/$label.plist"
        SH
        sudo:         true,
        must_succeed: false
    remove "com.vphone.launchpad.helper.plist"

    # Fetch, verify and unpack the bundle, then write its receipt. The last
    # argument is the sha256 of VPhone-<bundle>.zip.
    run "/bin/sh",
        args:           ["-ec", <<~SH, "sh", "{{version}}",
          version="${1#*,}"
          [ ! -e "/Library/Application Support/vphone-launchpad/Bundles/$version" ] || exit 0
          trap '[ $? -eq 0 ] || echo "Warning: Could not fetch VPhone.bundle $version;" \
            "install it from Core Bundle in the window instead." >&2' EXIT
          /usr/bin/curl --fail --location --silent --show-error --output VPhone-bundle.zip \
            "https://github.com/Lakr233/vphone-cli/releases/download/$version/VPhone-$version.zip"
          echo "$2  VPhone-bundle.zip" | /usr/bin/shasum -a 256 -c - >/dev/null
          /usr/bin/ditto -x -k VPhone-bundle.zip VPhone-bundle
          cdhash() {
            /usr/bin/codesign -dvvv "VPhone-bundle/VPhone.bundle/Contents/MacOS/$1" 2>&1 |
              /usr/bin/sed -n 's/^CDHash=//p'
          }
          cli=$(cdhash vphone-cli)
          vm=$(cdhash vphone-vm)
          [ -n "$cli" ] && [ -n "$vm" ]
          /bin/cat >VPhone-bundle/receipt.json <<JSON
          {
            "cdhashes": {
              "vphone-cli": "$cli",
              "vphone-vm": "$vm"
            },
            "installedAt": "$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)",
            "sha256": "$2",
            "version": "$version"
          }
          JSON
        SH
                         "3aa6b4e97278b2fa4d0cede80569f135316310d69daf75ecd5a4ccfdd0b317e9"],
        chdir:          ".",
        network_access: true,
        must_succeed:   false
    if_path_exists "VPhone-bundle/receipt.json" do
      run "/bin/sh",
          args:         ["-ec", <<~SH, "sh", "{{version}}", "{{staged_path}}/VPhone-bundle"],
            store="/Library/Application Support/vphone-launchpad/Bundles/${1#*,}"
            trap '[ $? -eq 0 ] || echo "Warning: Could not install VPhone.bundle into Launchpad;" \
              "install it from Core Bundle in the window instead." >&2' EXIT
            /bin/mkdir -p "$store"
            /usr/bin/ditto "$2/VPhone.bundle" "$store/VPhone.bundle"
            /bin/cp "$2/receipt.json" "$store/receipt.json"
            /usr/sbin/chown -R root:wheel "$store"
          SH
          sudo:         true,
          must_succeed: false
    end
    remove ["VPhone-bundle.zip", "VPhone-bundle"], recursive: true

    run "/bin/sh",
        args:           ["-ec", <<~SH, "sh", "{{version}}"],
          version="${1#*,}"
          [ -d "/Library/Application Support/vphone-launchpad/Bundles/$version" ] || exit 0
          /usr/bin/defaults write com.vphone.launchpad VPhoneLaunchpadActiveBundleVersion "$version"
        SH
        must_succeed:   false,
        writable_paths: ["~/Library/Preferences/com.vphone.launchpad.plist"]
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
