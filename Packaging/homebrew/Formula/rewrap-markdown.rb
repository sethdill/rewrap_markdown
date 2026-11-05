class RewrapMarkdown < Formula
  desc "Reflow Markdown prose while preserving its structure"
  homepage "https://github.com/sethdill/rewrap_markdown"
  url "https://github.com/sethdill/rewrap_markdown/archive/97b8ff23352ce8b46fcdc372404d3d0300265edb.tar.gz"
  version "0.3"
  sha256 "8f4d8a94d87d0c44934b18b9b891eaa6671a93d745719e46987701a7da578e61"
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
