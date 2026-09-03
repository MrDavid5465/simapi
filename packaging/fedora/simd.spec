Name:           simd
Version:        %{?_version}%{!?_version:0.0.0}
Release:        1%{?dist}
Summary:        SimAPI telemetry daemon for racing simulators
License:        LGPL-3.0-or-later
URL:            https://github.com/Spacefreak18/simapi

BuildRequires:  gcc cmake pkgconfig
BuildRequires:  libuv-devel yder-devel argtable-devel libconfig-devel procps-ng-devel

%description
simd watches for a running racing simulator, maps its telemetry, and
republishes it as a universal shared memory map at /dev/shm/SIMAPI.DAT for
other applications to read. Ships libsimapi alongside it, which simd links
at runtime.

# Builds whatever tree has been staged at %{_sourcedir}/simapi. CI stages the
# checked-out tree so an rpm's contents are the commit it was built from,
# rather than whatever the default branch happened to be at build time.
%prep
rm -rf %{_builddir}/simapi
cp -r %{_sourcedir}/simapi %{_builddir}/

%build
cd %{_builddir}/simapi
# The two *_DIR variables are upstream cache paths that default under
# $ENV{HOME} -- fine for a developer's own install, but a package must never
# write into a user's home. Redirected here rather than patched upstream.
cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_INSTALL_LIBDIR=%{_lib} \
  -DSYSTEMD_USER_UNIT_DIR=/usr/lib/systemd/user \
  -DSIMD_CONFIG_DIR=/usr/share/simd
cmake --build build -j$(nproc)

%install
cd %{_builddir}/simapi
DESTDIR=%{buildroot} cmake --install build
# Upstream's unit hardcodes ExecStart=%%h/.local/bin/simd with Type=simple
# against a daemon that double-forks; the packaged one runs /usr/bin/simd -n
# under systemd's own supervision.
install -Dm644 packaging/simd.service %{buildroot}/usr/lib/systemd/user/simd.service

%files
/usr/bin/simd
/usr/%{_lib}/libsimapi.so*
/usr/lib/systemd/user/simd.service
/usr/share/simd/simd.config
/usr/include/*.h
/usr/share/pkgconfig/simapi.pc
%license LICENSE.rst
