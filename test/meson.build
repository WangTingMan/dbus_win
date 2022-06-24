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

###############################################################################
# Tests installation

install_tests = get_option('installed_tests')

test_exec_dir = get_option('libexecdir') / 'installed-tests' / 'dbus'
test_meta_dir = get_option('datadir') / 'installed-tests' / 'dbus'

###############################################################################
# Test configuration needs some specific keys

test_data_config = configuration_data()
test_data_config.merge_from(data_config)

test_data_config.set('DBUS_SESSION_BUS_LISTEN_ADDRESS', test_listen)
test_data_config.set('EXEEXT', exe_ext)
# / '' to convert \-separated dir to /-separated dir on win32
test_data_config.set('DBUS_TEST_EXEC', meson.current_build_dir() / '')
test_data_config.set('DBUS_TEST_DATA', meson.current_build_dir() / 'data')


test_env = environment()

test_env.set('DBUS_TOP_SRCDIR',     meson.project_source_root())
test_env.set('DBUS_TEST_HOMEDIR',   meson.project_source_root() / 'dbus')
test_env.set('HOME',                meson.project_source_root() / 'dbus')
test_env.set('DBUS_TEST_SRCDIR',    meson.current_source_dir())

test_env.set('DBUS_TOP_BUILDDIR',   meson.project_build_root())
# Tests in bus/config-parser.c rely on this specific value
test_env.set('DBUS_TEST_BUILDDIR',  meson.current_build_dir())
test_env.set('DBUS_TEST_EXEC',      meson.current_build_dir())
test_env.set('DBUS_TEST_DATA',      meson.current_build_dir() / 'data')

test_env.set('DBUS_TEST_DAEMON',        dbus_daemon.full_path())
test_env.set('DBUS_TEST_DBUS_LAUNCH',   dbus_launch.full_path())
test_env.set('DBUS_TEST_DBUS_MONITOR',  dbus_monitor.full_path())
test_env.set('DBUS_TEST_DBUS_SEND',     dbus_send.full_path())

if platform_unix
    test_env.set('DBUS_TEST_DBUS_UUIDGEN', dbus_uuidgen.full_path())
endif

# Tests in bus/config-parser.c rely on these specific values for XDG_*
test_env.set('XDG_DATA_HOME',       meson.current_build_dir() / 'XDG_DATA_HOME')
test_env.set('XDG_RUNTIME_DIR',     meson.current_build_dir() / 'XDG_RUNTIME_DIR')
xdg_data_dirs = [
    meson.current_build_dir() / 'XDG_DATA_DIRS',
    meson.current_build_dir() / 'XDG_DATA_DIRS2'
]
test_env.set('XDG_DATA_DIRS',       xdg_data_dirs)

test_env.set('DBUS_SESSION_BUS_ADDRESS', 'do-not-use-real-session:')

test_env.set('DBUS_FATAL_WARNINGS', '1')
test_env.set('DBUS_TEST_UNINSTALLED', '1')

xdgdir = custom_target('gen-xdgdir',
    command: [
        python,
        files('mkdir-m700.py'),
        meson.current_build_dir() / 'XDG_RUNTIME_DIR',
    ],
    output: 'XDG_RUNTIME_DIR'
)

installed_tests = []

###############################################################################
# Dbus testutils


libdbus_testutils_sources = [
    'disable-crash-handling.c',
    'test-utils.c',
]

if use_glib
    libdbus_testutils_sources += 'test-utils-glib.c'
endif

libdbus_testutils = static_library('dbus-testutils',
    libdbus_testutils_sources,

    include_directories: root_include,
    link_with: [
        libdbus,
        libdbus_internal,
    ],
    dependencies: [
        glib,
        dbus_dependencies,
    ],
)


###############################################################################
# Test tools

# these binaries are used in tests but are not themselves tests
test_exit = executable('test-exit',
    'test-exit.c',
    include_directories: root_include,
    link_with: libdbus_testutils,
    dependencies: dbus_dependencies,
)
test_names = executable('test-names',
    'test-names.c',
    include_directories: root_include,
    link_with: libdbus_testutils,
    dependencies: dbus_dependencies,
)
test_privserver = executable('test-privserver',
    'test-privserver.c',
    include_directories: root_include,
    link_with: libdbus_testutils,
    dependencies: dbus_dependencies,
)
# This helper is meant to crash, so if we're compiling the rest with
# AddressSanitizer, we need to stop it from catching the SIGSEGV and
# turning it into _exit(1).
# We have to compile a separate copy of disable-crash-handling.c for
# test-segfault rather than using libdbus-testutils, because
# otherwise it would fail to link when using the AddressSanitizer.
test_segfault = executable('test-segfault',
    'test-segfault.c', 'disable-crash-handling.c',
    include_directories: root_include,
    dependencies: dbus_dependencies,
    override_options: ['b_sanitize=none'],
)
test_shell_service = executable('test-shell-service',
    'test-shell-service.c',
    include_directories: root_include,
    link_with: libdbus_testutils,
    dependencies: dbus_dependencies,
)

if use_traditional_activation
    test_spawn = executable('test-spawn',
        'spawn-test.c',
        include_directories: root_include,
        link_with: libdbus_testutils,
        dependencies: dbus_dependencies,
    )
endif
if use_traditional_activation and platform_unix
    launch_helper_for_tests = executable('launch-helper-for-tests',
        'bus/launch-helper-for-tests.c',
        include_directories: root_include,
        link_with: liblaunch_helper_internal,
        dependencies: dbus_dependencies,
    )
    test_data_config.set('TEST_LAUNCH_HELPER_BINARY', launch_helper_for_tests.full_path())
else
    # Dummy value, should not be used in practice
    test_data_config.set('TEST_LAUNCH_HELPER_BINARY', '/bin/false')
endif

if platform_unix and use_glib
    test_apparmor_activation = executable('test-apparmor-activation',
        'sd-activation.c',
        include_directories: root_include,
        c_args: '-DDBUS_TEST_APPARMOR_ACTIVATION',
        link_with: libdbus_testutils,
        dependencies: [
            glib, gio,
            apparmor,
        ],
        install: install_tests,
        install_dir: test_exec_dir,
    )
endif

###############################################################################
# Subdirectories need utilities above.

subdir('data')

# the "name-test" subdir in fact contains a bunch of tests now that need a
# temporary bus to be running to do stuff with. The directory should be renamed.
subdir('name-test')

tests = []

if embedded_tests

    tests += [
        {
            'name': 'bus',
            'srcs': [ 'bus/main.c' ],
            'link': [ libdbus_testutils, libdbus_daemon_internal, ],
            'install': false,
        },
        {
            'name': 'bus-dispatch-sha1',
            'srcs': [ 'bus/dispatch-sha1.c' ],
            'link': [ libdbus_testutils, libdbus_daemon_internal, ],
            'install': false,
            'timeout': 120,
        },
        {
            'name': 'bus-dispatch',
            'srcs': [ 'bus/dispatch.c' ],
            'link': [ libdbus_testutils, libdbus_daemon_internal, ],
            'install': false,
            'timeout': 120,
        },
        {
            'name': 'marshal-recursive',
            'srcs': [
                'internals/dbus-marshal-recursive-util.c',
                'internals/marshal-recursive.c',
            ],
            'link': [ libdbus_testutils, ],
            'install': false,
        },
        {
            'name': 'message-internals',
            'srcs': [
                'internals/dbus-marshal-recursive-util.c',
                'internals/dbus-message-factory.c',
                'internals/dbus-message-util.c',
                'internals/message-internals.c',
            ],
            'link': [ libdbus_testutils, ],
            'install': false,
        },
    ]

    if use_traditional_activation and platform_unix
        tests += [
            {
                'name': 'bus-launch-helper-oom',
                'srcs': [ 'bus/launch-helper-oom.c' ],
                'link': [ libdbus_testutils, liblaunch_helper_internal, ],
                'install': false,
            },
            {
                'name': 'bus-system',
                'srcs': [ 'bus/system.c', ],
                'link': [ libdbus_testutils, liblaunch_helper_internal, ],
                'install': false,
            },
            {
                'name': 'spawn-oom',
                'srcs': [ 'internals/spawn-oom.c', ],
                'link': [ libdbus_testutils, ],
                'install': false,
            }
        ]
    endif
endif

tests += [
    {
        'name': 'service',
        'srcs': [ 'test-service.c' ],
        'link': [ libdbus_testutils, ],
        'install': true,
        'test': false,
    },
    {
        'name': 'sleep-forever',
        'srcs': [ 'test-sleep-forever.c' ],
        'link': [ libdbus_testutils, ],
        'install': true,
        'test': false,
    }
]

tests += [
    {
        'name': 'atomic',
        'srcs': [ 'internals/atomic.c' ],
        'link': [ libdbus_testutils, ],
    },
    {
        'name': 'hash',
        'srcs': [ 'internals/hash.c' ],
        'link': [ libdbus_testutils, ],
    },
    {
        'name': 'misc-internals',
        'srcs': [
            'internals/address.c',
            'internals/dbus-auth-script.c',
            'internals/dbus-auth-util.c',
            'internals/dbus-credentials-util.c',
            'internals/dbus-marshal-byteswap-util.c',
            'internals/dbus-marshal-recursive-util.c',
            'internals/dbus-marshal-validate-util.c',
            'internals/dbus-string-util.c',
            'internals/dbus-sysdeps-util.c',
            'internals/mempool.c',
            'internals/misc-internals.c',
            'internals/sha.c',
        ],
        'link': [ libdbus_testutils, ],
    },
    {
        'name': 'shell',
        'srcs': [ 'shell-test.c' ],
        'link': [ libdbus_testutils, ],
    },
    {
        'name': 'printf',
        'srcs': [ 'internals/printf.c' ],
        'link': [ libdbus_testutils, ],
    },
    {
        'name': 'manual-backtrace',
        'srcs': [ 'manual-backtrace.c' ],
        'link': [ libdbus_testutils, ],
        'test': false,
    },
    {
        'name': 'manual-dir-iter',
        'srcs': [ 'manual-dir-iter.c' ],
        'link': [ libdbus_testutils, ],
        'test': false,
    },
    {
        'name': 'manual-tcp',
        'srcs': [ 'manual-tcp.c' ],
        'link': [ libdbus_testutils, ],
        'test': false,
    }
]

if platform_windows
    tests += [
        {
            'name': 'manual-paths',
            'srcs': [ 'manual-paths.c' ],
            'link': [ libdbus_testutils, ],
            'test': false,
        }
    ]
endif

if use_glib
    tests += [
        {
            'name': 'assertions',
            'srcs': [ 'internals/assertions.c' ],
            'link': [ libdbus_testutils, ],
            'deps': [ glib, gio, ],
        },
        {
            'name': 'corrupt',
            'srcs': [ 'corrupt.c' ],
            'link': [ libdbus_testutils, ],
            'deps': [ glib, gio, ],
        },
        {
            'name': 'dbus-daemon',
            'srcs': [ 'dbus-daemon.c' ],
            'link': [ libdbus_testutils, ],
            'deps': [ glib, gio, ],
        },
        {
            'name': 'dbus-daemon-eavesdrop',
            'srcs': [ 'dbus-daemon-eavesdrop.c' ],
            'link': [ libdbus_testutils, ],
            'deps': [ glib, gio, ],
        },
        {
            'name': 'desktop-file',
            'srcs': [ 'internals/desktop-file.c' ],
            'link': [ libdbus_testutils, libdbus_internal, ],
            'deps': [ glib, gio, ],
        },
        {
            'name': 'fdpass',
            'srcs': [ 'fdpass.c' ],
            'link': [ libdbus_testutils, ],
            'deps': [ glib, gio, ],
        },
        {
            'name': 'header-fields',
            'srcs': [ 'header-fields.c' ],
            'link': [ libdbus_testutils, ],
            'deps': [ glib, gio, ],
            'timeout': 120,
        },
        {
            'name': 'message',
            'srcs': [ 'message.c' ],
            'link': [ libdbus_testutils, ],
            'deps': [ glib, gio, ],
        },
        {
            'name': 'monitor',
            'srcs': [ 'monitor.c' ],
            'link': [ libdbus_testutils, ],
            'deps': [ glib, gio, ],
        },
        {
            'name': 'loopback',
            'srcs': [ 'loopback.c' ],
            'link': [ libdbus_testutils, ],
            'deps': [ glib, gio, ],
        },
        {
            'name': 'marshal',
            'srcs': [ 'marshal.c' ],
            'link': [ libdbus_testutils, ],
            'deps': [ glib, gio, ],
        },
        {
            'name': 'refs',
            'srcs': [ 'internals/refs.c' ],
            'link': [ libdbus_testutils, ],
            'deps': [ glib, gio, ],
        },
        {
            'name': 'relay',
            'srcs': [ 'relay.c' ],
            'link': [ libdbus_testutils, ],
            'deps': [ glib, gio, ],
        },
        {
            'name': 'server-oom',
            'srcs': [ 'internals/server-oom.c' ],
            'link': [ libdbus_testutils, ],
            'deps': [ glib, gio, ],
        },
        {
            'name': 'syntax',
            'srcs': [ 'syntax.c' ],
            'link': [ libdbus_testutils, ],
            'deps': [ glib, gio, ],
        },
        {
            'name': 'sysdeps',
            'srcs': [ 'internals/sysdeps.c' ],
            'link': [ libdbus_testutils, ],
            'deps': [ glib, gio, ],
        },
        {
            'name': 'syslog',
            'srcs': [ 'internals/syslog.c' ],
            'link': [ libdbus_testutils, ],
            'deps': [ glib, gio, ],
        },
        {
            'name': 'uid-permissions',
            'srcs': [ 'uid-permissions.c' ],
            'link': [ libdbus_testutils, ],
            'deps': [ glib, gio, ],
        },
        {
            'name': 'variant',
            'srcs': [ 'internals/variant.c' ],
            'link': [ libdbus_testutils, ],
            'deps': [ glib, gio, ],
        },
        {
            'name': 'manual-authz',
            'srcs': [ 'manual-authz.c' ],
            'link': [ libdbus_testutils, ],
            'deps': [ glib, gio, ],
            'test': false,
        },
        {
            'name': 'manual-test-thread-blocking',
            'srcs': [ 'thread-blocking.c' ],
            'link': [ libdbus_testutils, ],
            'deps': [ glib, gio, ],
            'test': false,
        },
    ]

    if platform_unix
        tests += [
            {   'name': 'containers',
                'srcs': [ 'containers.c' ],
                'link': [ libdbus_testutils, ],
                'deps': [ glib, gio, ],
            },
            {   'name': 'sd-activation',
                'srcs': [ 'sd-activation.c' ],
                'link': [ libdbus_testutils, ],
                'deps': [ glib, gio, ],
            },
        ]

    endif
endif

foreach test: tests
    name = test.get('name')
    srcs = test.get('srcs')
    link = test.get('link', [])
    deps = test.get('deps', [])
    timeout = test.get('timeout', 30)
    install = test.get('install', true)

    test_exe = executable('test-' + name,
        srcs,
        link_with: link,
        dependencies: deps,
        include_directories: root_include,
        install: install_tests and install,
        install_dir: test_exec_dir,
    )

    # Some binaries are used in tests but are not themselves tests,
    # and some might be "as-installed" integration tests that aren't
    # guaranteed to work at build-time
    if test.get('build_time_test', true) and test.get('test', true)
        test(name,
            test_exe,
            args: ['--tap'],
            env: test_env,
            protocol: 'tap',
            timeout: timeout,
        )
    endif

    if install and test.get('test', true)
        installed_tests += [{
            'name': 'test-' + test.get('name'),
            'exe': 'test-' + test.get('name') + exe_ext,
        }]
    endif
endforeach


###############################################################################
# Scripts

scripts = []

if platform_unix and use_glib
    scripts += [
        {   'name': 'test-dbus-daemon-fork.sh', },
        {   'name': 'transient-services.sh',
            'exec': 'integration/transient-services.sh',
            'build_time_test': false },
        {   'name': 'test-apparmor-activation.sh',
            'build_time_test': false },
    ]

    # Testing dbus-launch relies on special code in that binary.
    if embedded_tests
        scripts += { 'name': 'test-dbus-launch-eval.sh' }
    endif
    if embedded_tests and use_x11_autolaunch
        scripts += { 'name': 'test-dbus-launch-x11.sh' }
    endif
endif

foreach script: scripts
    name = script.get('name')
    exec = script.get('exec', script.get('name'))
    install = script.get('install', true)

    if install_tests and install
        install_data(exec,
            install_mode: 'rwxr-xr-x',
            install_dir: test_exec_dir,
        )
        installed_tests += [{
            'name': name,
            'exe': name,
        }]
    endif

    # Some scripts might be used in tests but not themselves tests,
    # and some are "as-installed" integration tests that aren't
    # guaranteed to work at build-time
    if script.get('build_time_test', true) and script.get('test', true)
        test(name,
            find_program(exec),
            env: test_env,
            depends: xdgdir,
        )
    endif
endforeach


foreach test_case: installed_tests
    name = test_case.get('name')
    exe = test_case.get('exe', name)

    meta_config = configuration_data()
    meta_config.set('command',
        'env @0@/@1@ --tap'.format(
            get_option('prefix') / test_exec_dir, exe,
    ))
    configure_file(
        input : 'meta_template.test.in',
        output: name + '.test',
        configuration: meta_config,
        install: install_tests,
        install_dir: test_meta_dir
    )

    meta_config = configuration_data()
    meta_config.set('command',
        'env DBUS_TEST_EXEC=@0@ DBUS_TEST_DATA=@0@/data @0@/@1@ --tap'.format(
            get_option('prefix') / test_exec_dir, exe,
    ))
    configure_file(
        input : 'meta_template.test.in',
        output: name + '_with_config.test',
        configuration: meta_config,
        install: install_tests,
        install_dir: test_meta_dir
    )

endforeach
