cask "buuz" do
  version "1.0.7"
  sha256 "b29430803165d04984f3f2de7263b0e4492674d2cb62811937b2a30e896de997"

  url "https://github.com/mnkhbldd/mnkhbldd-keyboard/releases/download/v#{version}/Buuz-#{version}.zip"
  name "Buuz"
  desc "Mongolian Cyrillic input method — type Latin, get Cyrillic"
  homepage "https://github.com/mnkhbldd/mnkhbldd-keyboard"

  depends_on :macos

  input_method "Buuz.app"

  postflight do
    app = Pathname.new(Dir.home)/"Library/Input Methods/Buuz.app"

    # Ad-hoc signed build: clear quarantine so Input Method Kit can load it.
    system_command "/usr/bin/xattr", args: ["-cr", app.to_s], sudo: false
    system_command "/usr/bin/codesign",
                   args: ["--force", "--deep", "--sign", "-", app.to_s],
                   sudo: false

    # Input Method Kit keeps serving the previous binary until it is killed,
    # so an upgrade otherwise appears to do nothing until the next login.
    system_command "/usr/bin/pkill",
                   args:         ["-f", "Input Methods/Buuz.app"],
                   sudo:         false,
                   must_succeed: false
    sleep 1
    system_command "/usr/bin/open", args: [app.to_s], sudo: false
  end

  zap trash: "~/Library/Input Methods/Buuz.app"

  caveats <<~EOS
    Enable Buuz:
      System Settings → Keyboard → Input Sources → + → Buuz

    If it does not appear, log out and back in once.

    No Xcode required — this cask installs a prebuilt app.
  EOS
end
