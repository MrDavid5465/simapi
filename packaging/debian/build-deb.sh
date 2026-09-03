#!/usr/bin/env bash
# Builds a .deb from an already-configured build tree.
#
#   build-deb.sh <build-dir> <version> <output.deb>
#
# Dependencies are computed by dpkg-shlibdeps from the built binaries rather
# than maintained by hand: library package names drift between releases, and a
# stale hand-written list still builds fine, failing only at install time on
# someone else's machine.
set -euo pipefail

builddir=${1:?build dir}
version=${2:?version}
output=${3:?output .deb}

pkgroot=$(mktemp -d)
trap 'rm -rf "$pkgroot"' EXIT

DESTDIR="$pkgroot" cmake --install "$builddir" >/dev/null

# Upstream's CMake installs its systemd unit from simd/conf/simd.service, which
# hardcodes ExecStart=%h/.local/bin/simd and Type=simple against a daemon that
# double-forks. Replace it with the packaged one: /usr/bin/simd -n, supervised
# by systemd rather than by a fork it cannot see.
install -Dm644 packaging/simd.service "$pkgroot/usr/lib/systemd/user/simd.service"

mkdir -p "$pkgroot/DEBIAN"
cat > "$pkgroot/DEBIAN/control" <<CTRL
Package: simd
Version: $version
Section: misc
Priority: optional
Architecture: amd64
Maintainer: David Scott <david@davidallanscott.ca>
Description: SimAPI telemetry daemon for racing simulators
 simd watches for a running racing simulator, maps its telemetry, and
 republishes it as a universal shared memory map at /dev/shm/SIMAPI.DAT
 for other applications to read.
 .
 Ships libsimapi alongside it, which simd links at runtime.
CTRL

# shlibdeps needs the shipped library on its search path to resolve simd's own
# dependency on it; without -l it reports libsimapi.so.1 as an unknown symbol
# source and refuses to emit a Depends line at all.
( cd "$pkgroot" && dpkg-shlibdeps -l"$pkgroot/usr/lib" \
    -O usr/bin/simd usr/lib/libsimapi.so.1.0.1 ) > "$pkgroot/shlibdeps.txt"
deps=$(sed -e 's/^shlibs:Depends=//' "$pkgroot/shlibdeps.txt")
rm -f "$pkgroot/shlibdeps.txt"
echo "Depends: $deps" >> "$pkgroot/DEBIAN/control"

echo "--- control ---"
cat "$pkgroot/DEBIAN/control"

dpkg-deb --build "$pkgroot" "$output"
