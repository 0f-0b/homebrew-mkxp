class RgssScriptEditor < Formula
  desc "Editor for RPGMaker script archives"
  homepage "https://github.com/Ancurio/rgss_script_editor"
  url "https://github.com/Ancurio/rgss_script_editor.git",
    revision: "e7483ee191a6823d32b3df0694392a45ccacfe5d"
  version "0+20201020"
  head "https://github.com/Ancurio/rgss_script_editor.git", branch: "master"

  depends_on "cmake" => :build
  depends_on "qt@5"

  resource "qscintilla2" do
    url "https://riverbankcomputing.com/static/Downloads/QScintilla/2.14.1/QScintilla_src-2.14.1.tar.gz"
    sha256 "dfe13c6acc9d85dfcba76ccc8061e71a223957a6c02f3c343b30a9d43a4cdd4d"
  end

  patch :DATA

  def install
    ENV.cxx11

    qsci = libexec/"qscintilla2"
    qsci.mkpath

    resource("qscintilla2").stage do
      qt5 = Formula["qt@5"].opt_prefix

      cd "src" do
        inreplace "qscintilla.pro" do |s|
          s.gsub! "QMAKE_POST_LINK += install_name_tool -id @rpath/$(TARGET1) $(TARGET)",
            "QMAKE_POST_LINK += install_name_tool -id #{qsci}/lib/$(TARGET1) $(TARGET)"
          s.gsub! "$$[QT_INSTALL_LIBS]", qsci/"lib"
          s.gsub! "$$[QT_INSTALL_HEADERS]", qsci/"include"
          s.gsub! "$$[QT_INSTALL_TRANSLATIONS]", qsci/"trans"
          s.gsub! "$$[QT_INSTALL_DATA]", qsci/"data"
          s.gsub! "$$[QT_HOST_DATA]", qsci/"data"
        end

        inreplace "features/qscintilla2.prf" do |s|
          s.gsub! "$$[QT_INSTALL_LIBS]", qsci/"lib"
          s.gsub! "$$[QT_INSTALL_HEADERS]", qsci/"include"
        end

        system "#{qt5}/bin/qmake"
        system "make"
        system "make", "install"
      end
    end

    system "cmake", ".", *std_cmake_args, "-DCMAKE_PREFIX_PATH=#{qsci}"
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
__END__
diff --git a/Modules/FindQScintilla.cmake b/Modules/FindQScintilla.cmake
index b3d79bd..d7882ae 100644
--- a/Modules/FindQScintilla.cmake
+++ b/Modules/FindQScintilla.cmake
@@ -15,7 +15,7 @@ if(Qt5Core_FOUND)

   if(QSCINTILLA_INCLUDE_INTERNAL AND QSCINTILLA_LIBRARY)
     set(QScintilla_FOUND TRUE)
-    set(QSCINTILLA_INCLUDE_DIRS "${QSCINTILLA_INCLUDE_INTERNAL}/Qsci")
+    set(QSCINTILLA_INCLUDE_DIRS "${QSCINTILLA_INCLUDE_INTERNAL}")
     message(STATUS "QScintilla found: ${QSCINTILLA_LIBRARY}")
   else()
     set(QScintilla_FOUND FALSE)
