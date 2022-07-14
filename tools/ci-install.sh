#!/bin/bash

# Copyright © 2015-2016 Collabora Ltd.
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

# ci_distro:
# OS distribution in which we are testing
# Typical values: auto, ubuntu, debian, ; maybe fedora in future
: "${ci_distro:=auto}"

# ci_docker:
# If non-empty, this is the name of a Docker image. ci-install.sh will
# fetch it with "docker pull" and use it as a base for a new Docker image
# named "ci-image" in which we will do our testing.
: "${ci_docker:=}"

# ci_host:
# Either "native", or an Autoconf --host argument to cross-compile
# the package
: "${ci_host:=native}"

# ci_in_docker:
# Used internally by ci-install.sh. If yes, we are inside the Docker image
# (ci_docker is empty in this case).
: "${ci_in_docker:=no}"

# ci_local_packages:
# prefer local packages instead of distribution
: "${ci_local_packages:=yes}"

# ci_suite:
# OS suite (release, branch) in which we are testing.
# Typical values: auto (detect at runtime), ci_distro=debian: bullseye, buster, ci_distro=fedora: 35, rawhide
: "${ci_suite:=auto}"

# ci_variant:
# One of debug, reduced, legacy, production
: "${ci_variant:=production}"

echo "ci_distro=$ci_distro ci_docker=$ci_docker ci_in_docker=$ci_in_docker ci_host=$ci_host ci_local_packages=$ci_local_packages ci_suite=$ci_suite ci_variant=$ci_variant $0"

if [ $(id -u) = 0 ]; then
    sudo=
else
    sudo=sudo
fi


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
    sed \
        -e "s/@ci_distro@/${ci_distro}/" \
        -e "s/@ci_docker@/${ci_docker}/" \
        -e "s/@ci_suite@/${ci_suite}/" \
        < tools/ci-Dockerfile.in > Dockerfile
    exec docker build -t ci-image .
fi

case "$ci_distro" in
    (debian*|ubuntu*)
        # Don't ask questions, just do it
        sudo="$sudo env DEBIAN_FRONTEND=noninteractive"

        # Debian Docker images use httpredir.debian.org but it seems to be
        # unreliable; use a CDN instead
        $sudo sed -i -e 's/httpredir\.debian\.org/deb.debian.org/g' \
            /etc/apt/sources.list

        case "$ci_host" in
            (i686-w64-mingw32)
                $sudo dpkg --add-architecture i386
                ;;
            (x86_64-w64-mingw32)
                # assume the host or container is x86_64 already
                ;;
        esac

        $sudo apt-get -qq -y update
        packages=()

        case "$ci_host" in
            (i686-w64-mingw32)
                packages=(
                    "${packages[@]}"
                    binutils-mingw-w64-i686
                    g++-mingw-w64-i686
                    wine32 wine
                )
                ;;
            (x86_64-w64-mingw32)
                packages=(
                    "${packages[@]}"
                    binutils-mingw-w64-x86-64
                    g++-mingw-w64-x86-64
                    wine64 wine
                )
                ;;
        esac

        if [ "$ci_host/$ci_variant/$ci_suite" = "native/production/buster" ]; then
            packages=(
                "${packages[@]}"
                qttools5-dev-tools
                qt5-default
            )
        fi

        packages=(
            "${packages[@]}"
            adduser
            autoconf-archive
            automake
            autotools-dev
            ca-certificates
            ccache
            cmake
            debhelper
            dh-autoreconf
            dh-exec
            docbook-xml
            docbook-xsl
            doxygen
            dpkg-dev
            ducktype
            g++
            gcc
            git
            gnome-desktop-testing
            libapparmor-dev
            libaudit-dev
            libcap-ng-dev
            libexpat-dev
            libglib2.0-dev
            libselinux1-dev
            libsystemd-dev
            libx11-dev
            meson
            ninja-build
            sudo
            valgrind
            wget
            xauth
            xmlto
            xsltproc
            xvfb
            yelp-tools
            zstd
        )

        $sudo apt-get -qq -y --no-install-recommends install "${packages[@]}"

        if [ "$ci_in_docker" = yes ]; then
            # Add the user that we will use to do the build inside the
            # Docker container, and let them use sudo
            adduser --disabled-password --gecos "" user
            echo "user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/nopasswd
            chmod 0440 /etc/sudoers.d/nopasswd
        fi
        ;;

    (opensuse*)
        zypper="/usr/bin/zypper --non-interactive"
        # system
        packages=(
            sudo
        )

        # build system
        packages=(
            "${packages[@]}"
            autoconf
            autoconf-archive
            automake
            cmake
            libtool
            meson
        )

        # docs
        packages=(
            "${packages[@]}"
            docbook_4
            docbook-xsl-stylesheets
            doxygen
            libqt5-qttools
            libxslt-tools
            yelp-tools
        )

        # dbus (autogen.sh)
        packages=(
            "${packages[@]}"
            which
        )

        # choose distribution
        id=$(. /etc/os-release; echo ${ID} | sed 's, ,_,g')
        case "$id" in
            (opensuse-leap)
                version=$(. /etc/os-release; echo ${VERSION_ID} | sed 's, ,_,g')
                repo="openSUSE_Leap_$version"
                # Use a newer CMake (3.21) version for JUnit XML support on openSUSE Leap.
                if ! zypper lr cmake > /dev/null; then
                    $zypper ar --refresh --no-gpgcheck --name cmake \
                        "https://download.opensuse.org/repositories/devel:tools:building/$version/devel:tools:building.repo"
                fi
                ;;
            (opensuse-tumbleweed)
                repo="openSUSE_Tumbleweed"
                ;;
            (*)
                echo "ci_suite not specified, please choose one from 'leap' or 'tumbleweed'"
                exit 1
                ;;
        esac

        case "$ci_host" in
            (*-w64-mingw32)
                # cross
                packages=(
                    "${packages[@]}"
                    wine
                    xvfb-run
                )

                # add required repos
                if [ "${ci_host%%-*}" = x86_64 ]; then
                    bits="64"
                else
                    bits="32"
                fi
                (
                    p=$(zypper lr | grep "windows_mingw_win${bits}" || true)
                    if [ -z "$p" ]; then
                        $zypper ar --refresh --no-gpgcheck \
                            "https://download.opensuse.org/repositories/windows:/mingw/$repo/windows:mingw.repo"
                        $zypper ar --refresh --no-gpgcheck \
                            "https://download.opensuse.org/repositories/windows:/mingw:/win${bits}/$repo/windows:mingw:win${bits}.repo"
                    fi
                )
                packages=(
                    "${packages[@]}"
                    mingw${bits}-cross-gcc-c++
                    mingw${bits}-cross-pkgconf
                    mingw${bits}-libexpat-devel
                    mingw${bits}-glib2-devel
                    mingw${bits}-cross-meson
                )
                ;;

            (*)
                packages=(
                    "${packages[@]}"
                    gcc-c++
                    libexpat-devel
                    glib2-devel
                    libX11-devel
                    systemd-devel
                )
                ;;
        esac
        $zypper install --allow-vendor-change "${packages[@]}"

        if [ "$ci_in_docker" = yes ]; then
            # Add the user that we will use to do the build inside the
            # Docker container, and let them use sudo
            useradd -m user
            passwd -ud user
            echo "user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/nopasswd
            chmod 0440 /etc/sudoers.d/nopasswd
        fi
        ;;
esac

#
# manual package setup
#
case "$ci_distro" in
    (debian*|ubuntu*)

        # Make sure we have a messagebus user, even if the dbus package
        # isn't installed
        $sudo adduser --system --quiet --home /nonexistent --no-create-home \
            --disabled-password --group messagebus
        ;;

    (opensuse*)
        # test-bus depends on group 'bin'
        $sudo getent group bin >/dev/null || /usr/sbin/groupadd -r bin
        ;;

    (*)
        echo "Don't know how to set up ${ci_distro}" >&2
        exit 1
        ;;
esac

if [ "$ci_local_packages" = yes ]; then
    case "$ci_host" in
        (*-w64-mingw32)
            mirror=https://repo.msys2.org/mingw/${ci_host%%-*}
            dep_prefix=$(pwd)/${ci_host}-prefix
            # clean install dir, if present
            rm -rf ${dep_prefix}
            install -d "${dep_prefix}"
            wget -O files.lst ${mirror}
            sed 's,^<a href=",,g;s,">.*$,,g' files.lst | grep -v "\.db" | grep -v "\.files" | grep ".*zst$" | sort > filenames.lst
            packages=(
                bzip2-1.0
                expat-2.2
                gcc-libs-10.2
                gettext-0.19
                glib2-2.66
                iconv-1.16
                libffi-3.3
                libiconv-1.16
                libwinpthread-git-8.0.0
                pcre-8.44
                zlib-1.2
            )
            for pkg in "${packages[@]}" ; do
                filename=$(grep ${pkg} filenames.lst | tail -1)
                if [ -z ${filename} ]; then
                    echo "could not find filename for package '${pkg}'"
                    exit 1
                fi
                # Remove previously downloaded file, which can happen
                # when run locally
                if [ -f ${filename} ]; then
                    rm -rf ${filename}
                fi
                wget ${mirror}/${filename}
                tar -C ${dep_prefix} --strip-components=1 -xvf ${filename}
            done

            # limit access rights
            if [ "$ci_in_docker" = yes ]; then
                chown -R user "${dep_prefix}"
            fi
            ;;
    esac
fi

# vim:set sw=4 sts=4 et:
