# Homebrew cask for Developer Edge.
#
# Host this in your own tap (e.g. github.com/your-org/homebrew-tap) so users can:
#   brew tap your-org/tap
#   brew install --cask developer-edge
#
# On each release, update `version` and `sha256` (shasum -a 256 DeveloperEdge.dmg)
# and the download `url` to point at the GitHub release asset.
cask "developer-edge" do
  version "0.1.0"
  sha256 "REPLACE_WITH_DMG_SHA256"

  url "https://github.com/your-org/developer-edge/releases/download/v#{version}/DeveloperEdge.dmg"
  name "Developer Edge"
  desc "Configurable macOS menu-bar companion for fullstack teams"
  homepage "https://github.com/your-org/developer-edge"

  depends_on macos: ">= :ventura"

  app "Developer Edge.app"

  zap trash: [
    "~/Library/Preferences/com.developeredge.app.plist",
    "~/.config/developer-edge",
  ]
end
