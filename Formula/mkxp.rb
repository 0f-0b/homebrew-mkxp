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
  end

  resource "sdl_sound" do
    url "https://github.com/Ancurio/SDL_sound.git",
      branch:   "master",
      revision: "04798ba55dccd18b094c0f6a2630c2fe7b15aa86"
  end

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
      system "./configure", "--prefix=#{libexec}", "--enable-shared", "--with-out-ext=openssl"
      system "make"
      system "make", "install"
    end

    resource("sdl_sound").stage do
      system "./bootstrap"
      system "./configure", "--prefix=#{libexec}"
      system "make", "install"
    end

    boost = Formula["boost"].opt_prefix
    qt5 = Formula["qt@5"].opt_prefix
    system "#{qt5}/bin/qmake", "BOOST_I=#{boost}/include", "BOOST_L=#{boost}/lib",
      "CONFIG+=INI_ENCODING", "DEFINES+=WORKDIR_CURRENT", "MRIVERSION=2.2"
    system "make"
    prefix.install "mkxp.app"
    bin.write_exec_script "#{prefix}/mkxp.app/Contents/MacOS/mkxp"
  end

  test do
    system "true"
  end
end
