class AppPilot < Formula
  desc "User-friendly application installer with a dynamic catalogue"
  homepage "https://github.com/cloudberrypitech/app-pilot"
  url "https://github.com/cloudberrypitech/app-pilot.git", branch: "main"
  version "1.1.0"
  license "MIT"

  depends_on "bash"

  def install
    libexec.install "bin", "lib", "VERSION", "LICENSE"
    libexec.install "downloads" if File.directory?("downloads")
    (bin/"cbapp").write <<~SH
      #!/bin/sh
      exec "#{Formula["bash"].opt_bin}/bash" "#{libexec}/bin/cbapp" "$@"
    SH
    chmod 0755, bin/"cbapp"
    bin.install_symlink "cbapp" => "alp"
  end

  test do
    assert_match "Cloudberry Pi AppPilot", shell_output("#{bin}/cbapp version")
    assert_match "Usage:", shell_output("#{bin}/cbapp help")
  end
end
