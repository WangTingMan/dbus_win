/* qdbusmessage.h QDBusMessage private object
 *
 * Copyright (C) 2005 Harald Fernengel <harry@kdevelop.org>
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
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 */

#ifndef QDBUSMESSAGE_P_H
#define QDBUSMESSAGE_P_H

#include <QtCore/qatomic.h>
#include <QtCore/qstring.h>

struct DBusMessage;

class QDBusMessagePrivate
{
public:
    QDBusMessagePrivate(QDBusMessage *qq);
    ~QDBusMessagePrivate();

    QString path, interface, name, service, method, sender;
    DBusMessage *msg;
    DBusMessage *reply;
    QDBusMessage *q;
    int type;
    int timeout;
    QAtomic ref;
};

#endif
