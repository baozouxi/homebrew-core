# Fix extraction on case-insensitive file systems.
# Reported 4 Sep 2017 https://bugs.launchpad.net/qemu/+bug/1714750
# This is actually an issue with u-boot and may take some time to sort out.
class QemuDownloadStrategy < CurlDownloadStrategy
  def stage
    exclude = "#{name}-#{version}/roms/u-boot/scripts/Kconfig"
    safe_system "tar", "xjf", cached_location, "--exclude", exclude
    chdir
  end
end

class Qemu < Formula
  desc "x86 and PowerPC Emulator"
  homepage "https://www.qemu.org/"
  url "https://download.qemu.org/qemu-2.10.0.tar.bz2",
      :using => QemuDownloadStrategy
  sha256 "7e9f39e1306e6dcc595494e91c1464d4b03f55ddd2053183e0e1b69f7f776d48"
  head "https://git.qemu.org/git/qemu.git"

  bottle do
    sha256 "18bea3a233228b280efacef8391757fa7e8cb27e5298c53e0a040cdabe595a64" => :high_sierra
    sha256 "638634a91a1aaafc5c0575a531686e35406188d374213940f99dfaeedcb8b611" => :sierra
    sha256 "fc975e3d3797567c3fd7b4c0c8091025e560ea11a5c4f5ddfa1cde2a166d1e45" => :el_capitan
    sha256 "754ba01f27583feba282efef4de01507ffa84564bd89ddc2c236b98074d7bb0f" => :yosemite
  end

  depends_on "pkg-config" => :build
  depends_on "libtool" => :build
  depends_on "jpeg"
  depends_on "gnutls"
  depends_on "glib"
  depends_on "ncurses"
  depends_on "pixman"
  depends_on "libpng" => :recommended
  depends_on "vde" => :optional
  depends_on "sdl2" => :optional
  depends_on "gtk+" => :optional
  depends_on "libssh2" => :optional

  deprecated_option "with-sdl" => "with-sdl2"

  fails_with :gcc_4_0 do
    cause "qemu requires a compiler with support for the __thread specifier"
  end

  fails_with :gcc do
    cause "qemu requires a compiler with support for the __thread specifier"
  end

  # 820KB floppy disk image file of FreeDOS 1.2, used to test QEMU
  resource "test-image" do
    url "https://dl.bintray.com/homebrew/mirror/FD12FLOPPY.zip"
    sha256 "81237c7b42dc0ffc8b32a2f5734e3480a3f9a470c50c14a9c4576a2561a35807"
  end

  def install
    ENV["LIBTOOL"] = "glibtool"

    # Fixes "dyld: lazy symbol binding failed: Symbol not found: _clock_gettime"
    if MacOS.version == "10.11" && MacOS::Xcode.installed? && MacOS::Xcode.version >= "8.0"
      inreplace %w[hw/i386/kvm/i8254.c include/qemu/timer.h linux-user/strace.c
                   roms/skiboot/external/pflash/progress.c
                   roms/u-boot/arch/sandbox/cpu/os.c ui/spice-display.c
                   util/qemu-timer-common.c], "CLOCK_MONOTONIC", "NOT_A_SYMBOL"
    end

    args = %W[
      --prefix=#{prefix}
      --cc=#{ENV.cc}
      --host-cc=#{ENV.cc}
      --disable-bsd-user
      --disable-guest-agent
      --enable-curses
      --extra-cflags=-DNCURSES_WIDECHAR=1
    ]

    # Cocoa and SDL2/GTK+ UIs cannot both be enabled at once.
    if build.with?("sdl2") || build.with?("gtk+")
      args << "--disable-cocoa"
    else
      args << "--enable-cocoa"
    end

    args << (build.with?("vde") ? "--enable-vde" : "--disable-vde")
    args << (build.with?("sdl2") ? "--enable-sdl" : "--disable-sdl")
    args << (build.with?("gtk+") ? "--enable-gtk" : "--disable-gtk")
    args << (build.with?("libssh2") ? "--enable-libssh2" : "--disable-libssh2")

    system "./configure", *args
    system "make", "V=1", "install"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/qemu-system-i386 --version")
    resource("test-image").stage testpath
    assert_match "file format: raw", shell_output("#{bin}/qemu-img info FLOPPY.img")
  end
end
