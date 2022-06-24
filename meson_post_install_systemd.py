#!/usr/bin/env python3
# Copyright © 2019-2020 Salamandar <felix@piedallu.me>
# SPDX-License-Identifier: MIT
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

from meson_post_install import *

import os, sys

###############################################################################

systemd_system_dir  = to_destdir(sys.argv[1])
systemd_user_dir    = to_destdir(sys.argv[2])

def force_symlink(src, dst):
    try:
        os.unlink(dst)
    except OSError:
        pass
    os.symlink(src, dst)

def post_install_data():
    # Install dbus.socket as default implementation of a D-Bus stack.
    # Unconditionally enable D-Bus on systemd installations
    #
    # TODO meson >=0.61 has install_symlink()

    (systemd_system_dir / 'sockets.target.wants')   .mkdir(parents=True, exist_ok=True)
    (systemd_system_dir / 'multi-user.target.wants').mkdir(parents=True, exist_ok=True)
    force_symlink('../dbus.socket',    systemd_system_dir / 'sockets.target.wants' / 'dbus.socket')
    force_symlink('../dbus.service',   systemd_system_dir / 'multi-user.target.wants' / 'dbus.service')

    if get_option('user_session'):
        (systemd_user_dir / 'sockets.target.wants') .mkdir(parents=True, exist_ok=True)
        force_symlink('../dbus.socket',systemd_user_dir / 'sockets.target.wants' / 'dbus.socket')

if __name__ == "__main__":
    post_install_data()
