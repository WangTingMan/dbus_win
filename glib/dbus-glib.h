/* -*- mode: C; c-file-style: "gnu" -*- */
/* dbus-glib.h GLib integration
 *
 * Copyright (C) 2002  CodeFactory AB
 *
 * Licensed under the Academic Free License version 1.2
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
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 */
#ifndef DBUS_GLIB_H
#define DBUS_GLIB_H

#include <dbus/dbus.h>
#include <glib.h>

typedef void (*DBusMessageHandler) (DBusConnection *connection,
				    DBusMessage    *message,
				    gpointer        data);

void gdbus_threads_init (void);
void dbus_glib_init     (void);


GSource *dbus_connection_gsource_new (DBusConnection *connection);


#endif /* DBUS_GLIB_H */
