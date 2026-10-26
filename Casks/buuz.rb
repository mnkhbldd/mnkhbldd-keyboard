cask "buuz" do
  version "1.0.12"
  sha256 "888f3030eba4e30764b4a6135d28ce8803efe5f23f2eca945cb8277dc6ae6046"

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
