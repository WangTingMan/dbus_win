/*
 * Copyright © 2019 Collabora Ltd.
 * SPDX-License-Identifier: AFL-2.1 or GPL-2.0-or-later
 *
 * Licensed under the Academic Free License version 2.1
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <https://www.gnu.org/licenses/>.
 */

#ifdef DBUS_INSIDE_DBUS_H
#error "You can't include dbus-macros-internal.h in the public header dbus.h"
#endif

#ifndef DBUS_MACROS_INTERNAL_H
#define DBUS_MACROS_INTERNAL_H

#include <dbus/dbus-macros.h>

#ifdef DBUS_ENABLE_EMBEDDED_TESTS
# define DBUS_EMBEDDED_TESTS_EXPORT DBUS_PRIVATE_EXPORT
#else
# define DBUS_EMBEDDED_TESTS_EXPORT /* nothing */
#endif

#endif
