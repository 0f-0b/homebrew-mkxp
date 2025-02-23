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
diff --git a/src/ruby_data.cxx b/src/ruby_data.cxx
index 4eb2786..fe0063c 100644
--- a/src/ruby_data.cxx
+++ b/src/ruby_data.cxx
@@ -266,22 +266,22 @@ static void writeFixnum(QIODevice &dev, int value)

   if (value > 0) {
     /* Positive number */
-    if (value <= 0x7F)
+    if (value <= 0xFF)
       len = 1;
-    else if (value <= 0x7FFF)
+    else if (value <= 0xFFFF)
       len = 2;
-    else if (value <= 0x7FFFFF)
+    else if (value <= 0xFFFFFF)
       len = 3;
     else
       len = 4;
   }
   else {
     /* Negative number */
-    if (value >= (int) 0x80)
+    if (value >= ~0xFF)
       len = -1;
-    else if (value >= (int) 0x8000)
+    else if (value >= ~0xFFFF)
       len = -2;
-    else if (value <= (int) 0x800000)
+    else if (value >= ~0xFFFFFF)
       len = -3;
     else
       len = -4;
@@ -308,7 +308,7 @@ static void writeString(QIODevice &dev, const QByteArray &data)
     throw QByteArray("Error writing data");
 }

-static void writeIVARString(QIODevice &dev, const QByteArray &data)
+static void writeIVARString(QIODevice &dev, const QByteArray &data, bool first)
 {
   /* Write inner string */
   writeByte(dev, '"');
@@ -318,14 +318,19 @@ static void writeIVARString(QIODevice &dev, const QByteArray &data)
   writeFixnum(dev, 1);
   // XXX It's no big deal, but maybe we should symlink all
   // further references to ':E' as Ruby would do?
-  writeByte(dev, ':');
-  writeString(dev, "E");
+  if (first) {
+    writeByte(dev, ':');
+    writeString(dev, "E");
+  } else {
+    writeByte(dev, ';');
+    writeByte(dev, 0);
+  }
   /* Always write Utf8 encoding */
   writeByte(dev, 'T');
 }

 static void writeRubyString(QIODevice &dev, const QByteArray &data,
-                            Script::Format format)
+                            Script::Format format, bool first)
 {
   if (format == Script::XP) {
     writeByte(dev, '"');
@@ -333,12 +338,12 @@ static void writeRubyString(QIODevice &dev, const QByteArray &data,
   }
   else { /* format == ScriptArchive::VXAce */
     writeByte(dev, 'I');
-    writeIVARString(dev, data);
+    writeIVARString(dev, data, first);
   }
 }

 static void writeScript(QIODevice &dev, const Script &script,
-                        Script::Format format)
+                        Script::Format format, bool first)
 {
   /* Write array prologue */
   writeByte(dev, '[');
@@ -349,7 +354,7 @@ static void writeScript(QIODevice &dev, const Script &script,
   writeFixnum(dev, script.magic);

   /* Write name */
-  writeRubyString(dev, script.name.toUtf8(), format);
+  writeRubyString(dev, script.name.toUtf8(), format, first);

   /* Convert line endings: Unix -> Windows (for compat) */
   QString sdata;
@@ -368,7 +373,7 @@ static void writeScript(QIODevice &dev, const Script &script,
   /* Write script data */
   QByteArray data = sdata.toUtf8();
   data = compressData(data);
-  writeRubyString(dev, data, format);
+  writeRubyString(dev, data, format, false);
 }

 ScriptList readScripts(QIODevice &dev)
@@ -407,7 +412,7 @@ void writeScripts(const ScriptList &scripts,

   /* Write scripts */
   for (int i = 0; i < scripts.count(); ++i)
-    writeScript(dev, scripts[i], format);
+    writeScript(dev, scripts[i], format, i == 0);
 }

 int generateMagic(const ScriptList &scripts)
