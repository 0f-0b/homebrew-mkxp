class RgssScriptEditor < Formula
  desc "Editor for RPGMaker script archives"
  homepage "https://github.com/Ancurio/rgss_script_editor"
  url "https://github.com/Ancurio/rgss_script_editor.git",
    revision: "e7483ee191a6823d32b3df0694392a45ccacfe5d"
  version "0+20201020"
  head "https://github.com/Ancurio/rgss_script_editor.git", branch: "master"

  depends_on "cmake" => :build
  depends_on "qscintilla2"
  depends_on "qt@5"

  def install
    ENV.cxx11

    system "cmake", ".", *std_cmake_args
    system "make"
    bin.install "bin/rgss_script_editor"
    bin.install "bin/rgss_script_editor_cli"
  end

  test do
    (testpath/"000").write("rgss_main {}\n")
    (testpath/"index").write("Main\n")
    system bin/"rgss_script_editor_cli", ".", "Scripts.rvdata2"
  end
end
