#!/bin/bash

# Copyright © 2015-2016 Collabora Ltd.
# Copyright © 2020 Ralf Habacker <ralf.habacker@freenet.de>
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation files
# (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -euo pipefail
set -x

NULL=

##
## initialize support to run cross compiled executables
##
# syntax: init_wine <path1> [<path2> ... [<pathn>]]
# @param  path1..n  pathes for adding to wine executable search path
#
# The function exits the shell script in case of errors
#
init_wine() {
    if ! command -v wineboot >/dev/null; then
        echo "wineboot not found"
        exit 1
    fi

    # run without X11 display to avoid that wineboot shows dialogs
    wineboot -fi

    # add local paths to wine user path
    local addpath="" d="" i
    for i in "$@"; do
        local wb=$(winepath -w "$i")
        addpath="$addpath$d$wb"
        d=";"
    done

    # create registry file from template
    local wineaddpath=$(echo "$addpath" | sed 's,\\,\\\\\\\\,g')
    sed "s,@PATH@,$wineaddpath,g" ../tools/user-path.reg.in > user-path.reg

    # add path to registry
    wine regedit /C user-path.reg

    # check if path(s) has been set and break if not
    local o=$(wine cmd /C "echo %PATH%")
    case "$o" in
        (*z:* | *Z:*)
            # OK
            ;;
        (*)
            echo "Failed to add Unix paths '$*' to path: Wine %PATH% = $o" >&2
            exit 1
            ;;
    esac
}

# ci_buildsys:
# Build system under test: autotools or cmake
: "${ci_buildsys:=autotools}"

# ci_distro:
# OS distribution in which we are testing
# Typical values: auto (detect at runtime), ubuntu, debian; maybe fedora in future
: "${ci_distro:=auto}"

# ci_docker:
# If non-empty, this is the name of a Docker image. ci-install.sh will
# fetch it with "docker pull" and use it as a base for a new Docker image
# named "ci-image" in which we will do our testing.
#
# If empty, we test on "bare metal".
# Typical values: ubuntu:xenial, debian:jessie-slim
: "${ci_docker:=}"

# ci_host:
# See ci-install.sh
: "${ci_host:=native}"

# ci_local_packages:
# prefer local packages instead of distribution
# See ci-install.sh
: "${ci_local_packages:=yes}"

# ci_parallel:
# A number of parallel jobs, passed to make -j
: "${ci_parallel:=1}"

# ci_sudo:
# If yes, assume we can get root using sudo; if no, only use current user
: "${ci_sudo:=no}"

# ci_suite:
# OS suite (release, branch) in which we are testing.
# Typical values: auto (detect at runtime), ci_distro=debian: bullseye, buster, ci_distro=fedora: 35, rawhide
: "${ci_suite:=auto}"

# ci_test:
# If yes, run tests; if no, just build
: "${ci_test:=yes}"

# ci_cmake_junit_output:
# If non-empty, emit JUnit XML output from CTest tests to that file
# Note: requires CMake 3.21 or newer.
: "${ci_cmake_junit_output:=}"

# ci_test_fatal:
# If yes, test failures break the build; if no, they are reported but ignored
: "${ci_test_fatal:=yes}"

# ci_variant:
# One of debug, reduced, legacy, production
: "${ci_variant:=production}"

# ci_runtime:
# One of static, shared; used for windows cross builds
: "${ci_runtime:=static}"

echo "ci_buildsys=$ci_buildsys ci_distro=$ci_distro ci_docker=$ci_docker ci_host=$ci_host ci_local_packages=$ci_local_packages ci_parallel=$ci_parallel ci_suite=$ci_suite ci_test=$ci_test ci_test_fatal=$ci_test_fatal ci_variant=$ci_variant ci_runtime=$ci_runtime $0"

# choose distribution
if [ "$ci_distro" = "auto" ]; then
    ci_distro=$(. /etc/os-release; echo ${ID} | sed 's, ,_,g')
    echo "detected ci_distro as '${ci_distro}'"
fi

# choose suite
if [ "$ci_suite" = "auto" ]; then
    ci_suite=$(. /etc/os-release; if test -v VERSION_CODENAME; then echo ${VERSION_CODENAME}; else echo ${VERSION_ID}; fi)
    echo "detected ci_suite as '${ci_suite}'"
fi

if [ -n "$ci_docker" ]; then
    exec docker run \
        --env=ci_buildsys="${ci_buildsys}" \
        --env=ci_docker="" \
        --env=ci_host="${ci_host}" \
        --env=ci_parallel="${ci_parallel}" \
        --env=ci_sudo=yes \
        --env=ci_test="${ci_test}" \
        --env=ci_test_fatal="${ci_test_fatal}" \
        --env=ci_variant="${ci_variant}" \
        --env=ci_runtime="${ci_runtime}" \
        --privileged \
        ci-image \
        tools/ci-build.sh
fi

maybe_fail_tests () {
    if [ "$ci_test_fatal" = yes ]; then
        exit 1
    fi
}

# Generate config.h.in and configure. We do this for both Autotools and
# CMake builds, so that the CMake build can compare config.h.in with its
# own checks.
NOCONFIGURE=1 ./autogen.sh

# clean up directories from possible previous builds
rm -rf "$builddir"
rm -rf ci-build-dist
rm -rf src-from-dist

case "$ci_buildsys" in
    (cmake-dist|meson-dist)
        # Do an Autotools `make dist`, then build *that* with CMake or Meson,
        # to assert that our official release tarballs will be enough
        # to build with CMake or Meson.
        mkdir -p ci-build-dist
        ( cd ci-build-dist; ../configure )
        make -C ci-build-dist dist
        tar --xz -xvf ci-build-dist/dbus-1.*.tar.xz
        mv dbus-1.*/ src-from-dist
        srcdir="$(pwd)/src-from-dist"
        ;;
    (*)
        srcdir="$(pwd)"
        ;;
esac

mkdir -p "$builddir"
builddir="$(realpath "$builddir")"

#
# cross compile setup
#
case "$ci_host" in
    (*-w64-mingw32)
        if [ "$ci_local_packages" = yes ]; then
            dep_prefix=$(pwd)/${ci_host}-prefix
        else
            # assume the compiler was configured with a sysroot (e.g. openSUSE)
            sysroot=$("${ci_host}-gcc" --print-sysroot)
            # check if the prefix is a subdir of sysroot (e.g. openSUSE)
            if [ -d "${sysroot}/${ci_host}" ]; then
                dep_prefix="${sysroot}/${ci_host}"
            else
                # fallback: assume the dependency libraries were built with --prefix=/${ci_host}
                dep_prefix="/${ci_host}"
                export PKG_CONFIG_SYSROOT_DIR="${sysroot}"
            fi
        fi

        export PKG_CONFIG_LIBDIR="${dep_prefix}/lib/pkgconfig"
        export PKG_CONFIG_PATH=
        export PKG_CONFIG="pkg-config --define-variable=prefix=${dep_prefix}"
        unset CC
        unset CXX
        export TMPDIR=/tmp
        ;;
esac

cd "$builddir"

case "$ci_host" in
    (*-w64-mingw32)
        # If we're dynamically linking libgcc, make sure Wine will find it
        if [ "$ci_test" = yes ]; then
            if [ "${ci_distro%%-*}" = opensuse ] && [ "${ci_host%%-*}" = x86_64 ]; then
                export WINEARCH=win64
            fi
            libgcc_path=
            if [ "$ci_runtime" = "shared" ]; then
                libgcc_path=$(dirname "$("${ci_host}-gcc" -print-libgcc-file-name)")
            fi
            init_wine \
                "${builddir}/bin" \
                "${builddir}/subprojects/expat-2.4.8" \
                "${builddir}/subprojects/glib-2.72.2/gio" \
                "${builddir}/subprojects/glib-2.72.2/glib" \
                "${builddir}/subprojects/glib-2.72.2/gmodule" \
                "${builddir}/subprojects/glib-2.72.2/gobject" \
                "${builddir}/subprojects/glib-2.72.2/gthread" \
                "${dep_prefix}/bin" \
                ${libgcc_path:+"$libgcc_path"}
        fi
        ;;
esac

make="make -j${ci_parallel} V=1 VERBOSE=1"

case "$ci_buildsys" in
    (autotools)
        case "$ci_variant" in
            (debug)
                # Full developer/debug build.
                set _ "$@"
                set "$@" --enable-developer --enable-tests
                # Enable optional features that are off by default
                case "$ci_host" in
                    *-w64-mingw32)
                        ;;
                    *)
                        set "$@" --enable-user-session
                        set "$@" SANITIZE_CFLAGS="-fsanitize=address -fsanitize=undefined -fPIE -pie"
                        ;;
                esac
                shift
                # The test coverage for OOM-safety is too
                # verbose to be useful on travis-ci.
                export DBUS_TEST_MALLOC_FAILURES=0
                ;;

            (reduced)
                # A smaller configuration than normal, with
                # various features disabled; this emulates
                # an older system or one that does not have
                # all the optional libraries.
                set _ "$@"
                # No LSMs (the production build has both)
                set "$@" --disable-selinux --disable-apparmor
                # No inotify (we will use dnotify)
                set "$@" --disable-inotify
                # No epoll or kqueue (we will use poll)
                set "$@" --disable-epoll --disable-kqueue
                # No special init system support
                set "$@" --disable-launchd --disable-systemd
                # No libaudit or valgrind
                set "$@" --disable-libaudit --without-valgrind
                # Disable optional features, some of which are on by
                # default
                set "$@" --disable-stats
                set "$@" --disable-user-session
                shift
                ;;

            (legacy)
                # An unrealistically cut-down configuration,
                # to check that it compiles and works.
                set _ "$@"
                # Disable native atomic operations on Unix
                # (armv4, as used as the baseline for Debian
                # armel, is one architecture that really
                # doesn't have them)
                set "$@" dbus_cv_sync_sub_and_fetch=no
		# Disable getrandom syscall
                set "$@" ac_cv_func_getrandom=no
                # No epoll, kqueue or poll (we will fall back
                # to select, even on Unix where we would
                # usually at least have poll)
                set "$@" --disable-epoll --disable-kqueue
                set "$@" CPPFLAGS=-DBROKEN_POLL=1
                # Enable SELinux and AppArmor but not
                # libaudit - that configuration has sometimes
                # failed
                set "$@" --enable-selinux --enable-apparmor
                set "$@" --disable-libaudit --without-valgrind
                # No directory monitoring at all
                set "$@" --disable-inotify --disable-dnotify
                # No special init system support
                set "$@" --disable-launchd --disable-systemd
                # No X11 autolaunching
                set "$@" --disable-x11-autolaunch
                # Leave stats, user-session, etc. at default settings
                # to check that the defaults can compile on an old OS
                shift
                ;;

            (*)
                ;;
        esac

        case "$ci_host" in
            (*-w64-mingw32)
                set _ "$@"
                set "$@" --build="$(build-aux/config.guess)"
                set "$@" --host="${ci_host}"
                set "$@" CFLAGS=-${ci_runtime}-libgcc
                set "$@" CXXFLAGS=-${ci_runtime}-libgcc
                # don't run tests yet, Wine needs Xvfb and
                # more msys2 libraries
                ci_test=no
                # don't "make install" system-wide
                ci_sudo=no
                shift
                ;;
        esac

        ../configure \
            --enable-installed-tests \
            --enable-maintainer-mode \
            --enable-modular-tests \
            "$@"

        ${make}
        [ "$ci_test" = no ] || ${make} check || maybe_fail_tests
        cat test/test-suite.log || :
        [ "$ci_test" = no ] || ${make} distcheck || maybe_fail_tests

        ${make} install DESTDIR=$(pwd)/DESTDIR
        ( cd DESTDIR && find . -ls )

        ${make} -C doc dbus-docs.tar.xz
        tar -C $(pwd)/DESTDIR -xf doc/dbus-docs.tar.xz
        ( cd DESTDIR/dbus-docs && find . -ls )

        if [ "$ci_sudo" = yes ] && [ "$ci_test" = yes ]; then
            sudo ${make} install
            sudo env LD_LIBRARY_PATH=/usr/local/lib \
                /usr/local/bin/dbus-uuidgen --ensure
            LD_LIBRARY_PATH=/usr/local/lib ${make} installcheck || \
                maybe_fail_tests
            cat test/test-suite.log || :

            # re-run them with gnome-desktop-testing
            env LD_LIBRARY_PATH=/usr/local/lib \
            gnome-desktop-testing-runner -d /usr/local/share dbus/ || \
                maybe_fail_tests

            # these tests benefit from being re-run as root, and one
            # test needs a finite fd limit to be useful
            sudo env LD_LIBRARY_PATH=/usr/local/lib \
            bash -c 'ulimit -S -n 1024; ulimit -H -n 4096; exec "$@"' bash \
                gnome-desktop-testing-runner -d /usr/local/share \
                dbus/test-dbus-daemon_with_config.test \
                dbus/test-uid-permissions_with_config.test || \
                maybe_fail_tests
        fi
        ;;

    (cmake|cmake-dist)
        cmdwrapper=
        cmake=cmake
        case "$ci_host" in
            (*-w64-mingw32)
                # CFLAGS and CXXFLAGS does do work, checked with cmake 3.15
                export LDFLAGS="-${ci_runtime}-libgcc"
                if [ "${ci_distro%%-*}" = opensuse ]; then
                    if [ "${ci_host%%-*}" = x86_64 ]; then
                        cmake=mingw64-cmake
                    else
                        cmake=mingw32-cmake
                    fi
                    cmdwrapper="xvfb-run -a"
                fi
                set _ "$@"
                if [ "$ci_distro" != "opensuse" ]; then
                    set "$@" -D CMAKE_TOOLCHAIN_FILE="${srcdir}/cmake/${ci_host}.cmake"
                fi
                set "$@" -D CMAKE_PREFIX_PATH="${dep_prefix}"
                if [ "$ci_local_packages" = yes ]; then
                    set "$@" -D CMAKE_INCLUDE_PATH="${dep_prefix}/include"
                    set "$@" -D CMAKE_LIBRARY_PATH="${dep_prefix}/lib"
                    set "$@" -D EXPAT_LIBRARY="${dep_prefix}/lib/libexpat.dll.a"
                    set "$@" -D GLIB2_LIBRARIES="${dep_prefix}/lib/libglib-2.0.dll.a ${dep_prefix}/lib/libgobject-2.0.dll.a ${dep_prefix}/lib/libgio-2.0.dll.a"
                fi
                if [ "$ci_test" = yes ]; then
                    set "$@" -D DBUS_USE_WINE=1
                    # test-dbus-daemon needs more time on Windows
                    export DBUS_TEST_TIMEOUT_MULTIPLIER=2
                fi
                shift
                ;;
        esac

        $cmake -DCMAKE_VERBOSE_MAKEFILE=ON -DENABLE_WERROR=ON "$@" ..

        ${make}
        # The test coverage for OOM-safety is too verbose to be useful on
        # travis-ci.
        export DBUS_TEST_MALLOC_FAILURES=0
        ctest_args="-VV --timeout 180"
        if [ -n "$ci_cmake_junit_output" ]; then
            ctest_args="--output-junit $ci_cmake_junit_output $ctest_args"
        fi

        [ "$ci_test" = no ] || $cmdwrapper ctest $ctest_args || maybe_fail_tests
        ${make} install DESTDIR=$(pwd)/DESTDIR
        ( cd DESTDIR && find . -ls)
        ;;

    (meson|meson-dist)
        # The test coverage for OOM-safety is too verbose to be useful on
        # travis-ci, and too slow when running under wine.
        export DBUS_TEST_MALLOC_FAILURES=0

        meson_setup=
        cross_file=

        # openSUSE has convenience wrappers that run Meson with appropriate
        # cross options
        case "$ci_host" in
            (i686-w64-mingw32)
                meson_setup=mingw32-meson
                ;;
            (x86_64-w64-mingw32)
                meson_setup=mingw64-meson
                ;;
        esac

        case "$ci_host" in
            (*-w64-mingw32)
                cross_file="${srcdir}/maint/${ci_host}.txt"
                # openSUSE's wrappers are designed for building predictable
                # RPM packages, so they set --auto-features=enabled -
                # but that includes some things that make no sense on
                # Windows.
                set -- -Dapparmor=disabled "$@"
                set -- -Depoll=disabled "$@"
                set -- -Dinotify=disabled "$@"
                set -- -Dkqueue=disabled "$@"
                set -- -Dlaunchd=disabled "$@"
                set -- -Dlibaudit=disabled "$@"
                set -- -Dselinux=disabled "$@"
                set -- -Dsystemd=disabled "$@"
                set -- -Dx11_autolaunch=disabled "$@"
                # We seem to have trouble finding libexpat.dll when
                # cross-building for Windows and running tests with Wine.
                set -- -Dexpat:default_library=static "$@"
                ;;
        esac

        case "$ci_distro" in
            (debian*|ubuntu*)
                # We know how to install python3-mallard-ducktype
                ;;
            (*)
                # TODO: We don't know the openSUSE equivalent of
                # python3-mallard-ducktype
                set -- -Dducktype_docs=disabled "$@"
                ;;
        esac

        set -- -Dmodular_tests=enabled "$@"

        case "$ci_variant" in
            (debug)
                set -- -Dasserts=true "$@"
                set -- -Dembedded_tests=true "$@"
                set -- -Dverbose_mode=true "$@"

                case "$ci_host" in
                    (*-w64-mingw32)
                        ;;
                    (*)
                        set -- -Db_sanitize=address,undefined "$@"
                        set -- -Db_pie=true "$@"
                        set -- -Duser_session=true "$@"
                        ;;
                esac

                shift
                ;;
        esac

        # Debian doesn't have similar convenience wrappers, but we can use
        # a cross-file
        if [ -z "$meson_setup" ] || ! command -v "$meson_setup" >/dev/null; then
            meson_setup="meson setup"

            if [ -n "$cross_file" ]; then
                set -- --cross-file="$cross_file" "$@"
            fi
        fi

        # openSUSE's mingw*-meson wrappers are designed for self-contained
        # package building, so they include --wrap-mode=nodownload. Switch
        # the wrap mode back, so we can use wraps.
        set -- "$@" --wrap=default

        $meson_setup "$@" "$srcdir"
        meson compile -v
        [ "$ci_test" = no ] || meson test
        DESTDIR=DESTDIR meson install
        ( cd DESTDIR && find . -ls)
        ;;
esac

# vim:set sw=4 sts=4 et:
