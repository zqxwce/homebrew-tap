cask "vphone-launchpad" do
  # "<launchpad>,<bundle>". Only notarized Launchpad builds open under
  # Gatekeeper and not every release ships one, so Launchpad is pinned to the
  # newest `-notarized` asset; the bundle is the newest release of its major.
  version "2.15.0,2.15.2"
  sha256 "952cdc5232d589159f58e41eb9060bb4631889af5b9ed451dfbfc7cddf5c231d"

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
                     .select { |v| Version.new(v).major == Version.new(launchpad).major }
                     .max_by { |v| Version.new(v) }
      next if bundle.nil?

      "#{launchpad},#{bundle}"
    end
  end

  depends_on arch: :arm64
  depends_on macos: :sequoia # macOS 15+

  app "vphone-launchpad.app"
  binary "#{appdir}/vphone-launchpad.app/Contents/MacOS/vphone-launchpad-cli"

  # sha256 of VPhone-<bundle>.zip.
  bundle_sha256 = "d43af99a3cbf4e8fe7268cb4ecdde78cadae4302d064887dd6b3fb3f32f971bf"

  # Install Launchpad's privileged helper as its SMJobBless call does (the app's
  # helper binary plus its embedded launchd plist with Program added), so Host
  # Setup does not have to after every install and upgrade.
  #
  # Then install the pinned VPhone.bundle into Launchpad's root-owned bundle
  # store, laid out as Launchpad's helper does (Bundles/<version>/VPhone.bundle
  # plus a receipt), and make it the default. Older bundles are kept: machines
  # stay bound to theirs. Non-fatal: never block install.
  postflight do
    helper_label = "com.vphone.launchpad.helper"
    helper = "/Library/PrivilegedHelperTools/#{helper_label}"
    daemon_plist = "/Library/LaunchDaemons/#{helper_label}.plist"
    begin
      plist = staged_path/"#{helper_label}.plist"
      plist.write <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>Label</key>
          <string>#{helper_label}</string>
          <key>MachServices</key>
          <dict>
            <key>#{helper_label}</key>
            <true/>
          </dict>
          <key>Program</key>
          <string>#{helper}</string>
          <key>ProgramArguments</key>
          <array>
            <string>#{helper}</string>
          </array>
        </dict>
        </plist>
      XML

      system_command "/bin/launchctl", args: ["bootout", "system/#{helper_label}"],
                                       sudo: true, must_succeed: false, print_stderr: false
      system_command "/usr/bin/install",
                     args: ["-o", "root", "-g", "wheel", "-m", "0544",
                            "#{appdir}/vphone-launchpad.app/Contents/Library/LaunchServices/#{helper_label}", helper],
                     sudo: true
      system_command "/usr/bin/install", args: ["-o", "root", "-g", "wheel", "-m", "0644", plist, daemon_plist],
                                         sudo: true
      system_command "/bin/launchctl", args: ["bootstrap", "system", daemon_plist], sudo: true
    rescue => e
      opoo "Could not install Launchpad's helper (#{e.message.lines.first&.strip}); " \
           "install it from Host Setup in the window instead."
    ensure
      plist&.unlink if plist&.exist?
    end

    bundle_version = version.csv.second
    store = Pathname("/Library/Application Support/vphone-launchpad/Bundles")/bundle_version
    if store.exist?
      ohai "Launchpad already has VPhone.bundle #{bundle_version}"
    else
      archive = staged_path/"VPhone-#{bundle_version}.zip"
      extracted = staged_path/"VPhone-#{bundle_version}"
      begin
        system_command "/usr/bin/curl",
                       args: ["--fail", "--location", "--silent", "--show-error", "--output", archive,
                              "https://github.com/Lakr233/vphone-cli/releases/download/#{bundle_version}/VPhone-#{bundle_version}.zip"]
        raise "SHA-256 mismatch for #{archive.basename}" if archive.sha256 != bundle_sha256

        system_command "/usr/bin/ditto", args: ["-x", "-k", archive, extracted]
        source = extracted/"VPhone.bundle"

        cdhashes = %w[vphone-cli vphone-vm].to_h do |exe|
          info = system_command("/usr/bin/codesign",
                                args:         ["-dvvv", source/"Contents/MacOS"/exe],
                                print_stderr: false)
          [exe, info.merged_output[/^CDHash=(\h+)$/, 1]]
        end
        receipt = extracted/"receipt.json"
        receipt.write JSON.pretty_generate(
          "cdhashes"    => cdhashes,
          "installedAt" => Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
          "sha256"      => bundle_sha256,
          "version"     => bundle_version,
        )

        system_command "/bin/mkdir", args: ["-p", store], sudo: true
        system_command "/usr/bin/ditto", args: [source, store/"VPhone.bundle"], sudo: true
        system_command "/bin/cp", args: [receipt, store/"receipt.json"], sudo: true
        system_command "/usr/sbin/chown", args: ["-R", "root:wheel", store], sudo: true
      ensure
        FileUtils.rm_r [archive, extracted].select(&:exist?)
      end
    end

    system_command "/usr/bin/defaults",
                   args: ["write", "com.vphone.launchpad", "VPhoneLaunchpadActiveBundleVersion", bundle_version]
  rescue => e
    opoo "Could not install VPhone.bundle into Launchpad (#{e.message.lines.first&.strip}); " \
         "install it from Core Bundle in the window instead."
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
