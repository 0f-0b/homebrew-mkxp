class Mkxp < Formula
  desc "Free Software implementation of the Ruby Game Scripting System (RGSS)"
  homepage "https://github.com/Ancurio/mkxp"
  url "https://github.com/Ancurio/mkxp.git",
    revision: "380b676777b101a7d6648a8e6b9a226a8984bbc0"
  version "0+20211105"
  head "https://github.com/Ancurio/mkxp.git", branch: "master"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "pkg-config" => :build
  depends_on "qt@5" => :build
  depends_on "boost"
  depends_on "libogg"
  depends_on "libsigc++@2"
  depends_on "libvorbis"
  depends_on "openal-soft"
  depends_on "physfs"
  depends_on "pixman"
  depends_on "sdl2"
  depends_on "sdl2_image"
  depends_on "sdl2_sound"
  depends_on "sdl2_ttf"
  depends_on "fluid-synth" => :optional

  resource "libguess" do
    url "https://github.com/kaniini/libguess.git",
      branch:   "master",
      revision: "b44a240c57ddce98f772ae7d9f2cf11a5972d8c2"
  end

  resource "ruby" do
    url "https://cache.ruby-lang.org/pub/ruby/2.2/ruby-2.2.10.tar.bz2"
    sha256 "a54204d2728283c9eff0cf81d654f245fa5b3447d0824f1a6bc3b2c5c827381e"
    patch <<~PATCH
      diff --git a/configure b/configure
      index b6914a2..7a9635e 100755
      --- a/configure
      +++ b/configure
      @@ -5599,6 +5599,9 @@ $as_echo_n "checking for real target cpu... " >&6; }
       #ifdef __ppc64__
       "processor-name=powerpc64"
       #endif
      +#ifdef __arm64__
      +"processor-name=arm64"
      +#endif
       EOF
       	    sed -n 's/^"processor-name=\\(.*\\)"/\\1/p'`
       	    target="$target_cpu${target}"
    PATCH
  end

  patch :DATA

  def install
    ENV.cxx11

    ENV.prepend "CFLAGS", "-I#{libexec}/include"
    ENV.prepend "LDFLAGS", "-L#{libexec}/lib"
    ENV.prepend_create_path "PKG_CONFIG_PATH", "#{libexec}/lib/pkgconfig"

    resource("libguess").stage do
      system "./autogen.sh"
      system "./configure", "--prefix=#{libexec}"
      system "make"
      system "make", "install"
    end

    resource("ruby").stage do
      ENV.prepend "CFLAGS", "-std=gnu89"

      system "./configure", "--prefix=#{libexec}", "--enable-shared", "--with-out-ext=fiddle,openssl"
      system "make"
      system "make", "install"
    end

    boost = Formula["boost"].opt_prefix
    qt5 = Formula["qt@5"].opt_prefix

    qmake_args = [
      "LIBS=#{OS.mac? ? "-liconv" : ""}",
      "BOOST_I=#{boost}/include",
      "BOOST_L=#{boost}/lib",
      "CONFIG+=INI_ENCODING",
      "DEFINES+=WORKDIR_CURRENT",
      "MRIVERSION=2.2",
    ]
    qmake_args << "CONFIG+=SHARED_FLUID" if build.with? "fluid-synth"

    system "#{qt5}/bin/qmake", *qmake_args
    system "make"

    if OS.mac?
      prefix.install "mkxp.app"
      bin.write_exec_script "#{prefix}/mkxp.app/Contents/MacOS/mkxp"
    else
      bin.install "mkxp"
    end
  end

  test do
    return
  end
end
__END__
diff --git a/mkxp.pro b/mkxp.pro
index ae229d7..e40f5c8 100644
--- a/mkxp.pro
+++ b/mkxp.pro
@@ -46,7 +46,7 @@ contains(BINDING, NULL) {
 unix {
 	CONFIG += link_pkgconfig
 	PKGCONFIG += sigc++-2.0 pixman-1 zlib physfs vorbisfile \
-	             sdl2 SDL2_image SDL2_ttf SDL_sound openal
+	             sdl2 SDL2_image SDL2_ttf SDL2_sound openal

 	SHARED_FLUID {
 		PKGCONFIG += fluidsynth
diff --git a/src/fluid-fun.h b/src/fluid-fun.h
index 005bdf7..6ea3fdb 100644
--- a/src/fluid-fun.h
+++ b/src/fluid-fun.h
@@ -10,6 +10,7 @@
 typedef struct _fluid_hashtable_t fluid_settings_t;
 typedef struct _fluid_synth_t fluid_synth_t;

+typedef int (*FLUIDSETTINGSSETINTPROC)(fluid_settings_t* settings, const char *name, int val);
 typedef int (*FLUIDSETTINGSSETNUMPROC)(fluid_settings_t* settings, const char *name, double val);
 typedef int (*FLUIDSETTINGSSETSTRPROC)(fluid_settings_t* settings, const char *name, const char *str);
 typedef int (*FLUIDSYNTHSFLOADPROC)(fluid_synth_t* synth, const char* filename, int reset_presets);
@@ -33,6 +34,7 @@ typedef void (*DELETEFLUIDSYNTHPROC)(fluid_synth_t* synth);
 #endif

 #define FLUID_FUNCS \
+	FLUID_FUN(settings_setint, FLUIDSETTINGSSETINTPROC) \
 	FLUID_FUN(settings_setnum, FLUIDSETTINGSSETNUMPROC) \
 	FLUID_FUN(settings_setstr, FLUIDSETTINGSSETSTRPROC) \
 	FLUID_FUN(synth_sfload, FLUIDSYNTHSFLOADPROC) \
diff --git a/src/font.cpp b/src/font.cpp
index 5c1d304..0ef685a 100644
--- a/src/font.cpp
+++ b/src/font.cpp
@@ -129,7 +129,7 @@ void SharedFontState::initFontSetCB(SDL_RWops &ops,
 		set.other = filename;
 }

-_TTF_Font *SharedFontState::getFont(std::string family,
+TTF_Font *SharedFontState::getFont(std::string family,
                                     int size)
 {
 	/* Check for substitutions */
@@ -195,7 +195,7 @@ bool SharedFontState::fontPresent(std::string family) const
 	return !(set.regular.empty() && set.other.empty());
 }

-_TTF_Font *SharedFontState::openBundled(int size)
+TTF_Font *SharedFontState::openBundled(int size)
 {
 	SDL_RWops *ops = openBundledFont();

@@ -441,7 +441,7 @@ void Font::initDefaults(const SharedFontState &sfs)
 	FontPrivate::defaultShadow  = (rgssVer == 2 ? true : false);
 }

-_TTF_Font *Font::getSdlFont()
+TTF_Font *Font::getSdlFont()
 {
 	if (!p->sdlFont)
 		p->sdlFont = shState->fontState().getFont(p->name.c_str(),
diff --git a/src/font.h b/src/font.h
index d6ca485..3557728 100644
--- a/src/font.h
+++ b/src/font.h
@@ -28,8 +28,9 @@
 #include <vector>
 #include <string>

+#include <SDL_ttf.h>
+
 struct SDL_RWops;
-struct _TTF_Font;
 struct Config;

 struct SharedFontStatePrivate;
@@ -47,12 +48,12 @@ public:
 	void initFontSetCB(SDL_RWops &ops,
 	                   const std::string &filename);

-	_TTF_Font *getFont(std::string family,
+	TTF_Font *getFont(std::string family,
 	                   int size);

 	bool fontPresent(std::string family) const;

-	static _TTF_Font *openBundled(int size);
+	static TTF_Font *openBundled(int size);

 private:
 	SharedFontStatePrivate *p;
@@ -112,7 +113,7 @@ public:
 	static void initDefaults(const SharedFontState &sfs);

 	/* internal */
-	_TTF_Font *getSdlFont();
+	TTF_Font *getSdlFont();

 private:
 	FontPrivate *p;
diff --git a/src/sharedmidistate.h b/src/sharedmidistate.h
index f1fb35a..ebb76c0 100644
--- a/src/sharedmidistate.h
+++ b/src/sharedmidistate.h
@@ -82,8 +82,8 @@ struct SharedMidiState
 		flSettings = fluid.new_settings();
 		fluid.settings_setnum(flSettings, "synth.gain", 1.0f);
 		fluid.settings_setnum(flSettings, "synth.sample-rate", SYNTH_SAMPLERATE);
-		fluid.settings_setstr(flSettings, "synth.chorus.active", conf.midi.chorus ? "yes" : "no");
-		fluid.settings_setstr(flSettings, "synth.reverb.active", conf.midi.reverb ? "yes" : "no");
+		fluid.settings_setint(flSettings, "synth.chorus.active", conf.midi.chorus);
+		fluid.settings_setint(flSettings, "synth.reverb.active", conf.midi.reverb);

 		for (size_t i = 0; i < SYNTH_INIT_COUNT; ++i)
 			addSynth(false);
