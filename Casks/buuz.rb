cask "buuz" do
  version "1.0.5"
  sha256 "8ebeb0deabc25f148e4a35de84a962169bc0b14c1f265c3f5a7758bf9e718650"

  url "https://github.com/mnkhbldd/mnkhbldd-keyboard/releases/download/v#{version}/Buuz-#{version}.zip"
  name "Buuz"
  desc "Mongolian Cyrillic input method — type Latin, get Cyrillic"
  homepage "https://github.com/mnkhbldd/mnkhbldd-keyboard"

  input_method "Buuz.app"

  # Ad-hoc signed build: clear quarantine so Input Method Kit can load it.
  postflight do
    app = Pathname.new(Dir.home)/"Library/Input Methods/Buuz.app"
    system_command "/usr/bin/xattr", args: ["-cr", app.to_s], sudo: false
    system_command "/usr/bin/codesign",
                   args: ["--force", "--deep", "--sign", "-", app.to_s],
                   sudo: false
  end

  zap trash: "~/Library/Input Methods/Buuz.app"

  caveats <<~EOS
    Enable Buuz:
      System Settings → Keyboard → Input Sources → + → Buuz

    If it does not appear, log out and back in once.

    No Xcode required — this cask installs a prebuilt app.
  EOS
end
