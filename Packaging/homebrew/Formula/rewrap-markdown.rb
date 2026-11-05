class RewrapMarkdown < Formula
  desc "Reflow Markdown prose while preserving its structure"
  homepage "https://github.com/sethdill/rewrap_markdown"
  url "https://github.com/sethdill/rewrap_markdown/archive/edbe983f49e62535004e32bd2c1edefb0bd4dd7f.tar.gz"
  version "0.3"
  sha256 "7cd5a0f63efd62622d046f6ff4751e689bbcc39f45cdbdb34749c296581d13b9"
  license "Apache-2.0"

  depends_on xcode: ["15.0", :build]

  on_linux do
    depends_on "swift"
  end

  def install
    system "swift", "build", "--configuration", "release", "--disable-sandbox"
    bin.install ".build/release/rewrap-markdown"
    prefix.install "LICENSE", "NOTICE"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/rewrap-markdown --version")
    assert_equal "alpha beta\ngamma delta\n", pipe_output("#{bin}/rewrap-markdown 12", "alpha beta gamma delta\n")
    assert_equal "alpha beta gamma delta\n",
                 pipe_output("#{bin}/rewrap-markdown --unwrap", "alpha beta\ngamma delta\n")
    message = "Keep this subject intact\n\nalpha beta gamma delta\n\nSigned-off-by: Test User <test@example.com>\n"
    expected = "Keep this subject intact\n\nalpha beta\ngamma delta\n\nSigned-off-by: Test User <test@example.com>\n"
    assert_equal expected, pipe_output("#{bin}/rewrap-markdown --commit 12", message)
  end
end
