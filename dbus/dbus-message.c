/* -*- mode: C; c-file-style: "gnu" -*- */
/* dbus-message.c  DBusMessage object
 *
 * Copyright (C) 2002  Red Hat Inc.
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

#include "dbus-internals.h"
#include "dbus-message.h"
#include "dbus-message-internal.h"
#include "dbus-memory.h"
#include "dbus-list.h"
#include <string.h>

/**
 * @defgroup DBusMessageInternals DBusMessage implementation details
 * @ingroup DBusInternals
 * @brief DBusMessage private implementation details.
 *
 * The guts of DBusMessage and its methods.
 *
 * @{
 */

/**
 * @brief Internals of DBusMessage
 * 
 * Object representing a message received from or to be sent to
 * another application. This is an opaque object, all members
 * are private.
 */
struct DBusMessage
{
  int refcount; /**< Reference count */

  unsigned char *header; /**< Header network data, stored
                          * separately from body so we can
                          * independently realloc it.
                          */
  int header_len;        /**< Length of header data. */

  unsigned char *body;   /**< Body network data. */
  int body_len;          /**< Length of body data. */

  unsigned int locked : 1; /**< Message being sent, no modifications allowed. */
};

/**
 * Gets the data to be sent over the network for this message.
 * The header and then the body should be written out.
 * This function is guaranteed to always return the same
 * data once a message is locked (with _dbus_message_lock()).
 *
 * @param message the message.
 * @param header return location for message header data.
 * @param header_len return location for header length in bytes.
 * @param body return location for message body data.
 * @param body_len return location for body length in bytes.
 */
void
_dbus_message_get_network_data (DBusMessage          *message,
                                const unsigned char **header,
                                int                  *header_len,
                                const unsigned char **body,
                                int                  *body_len)
{
  _dbus_assert (message->locked);
  
  *header = message->header;
  *header_len = message->header_len;
  *body = message->body;
  *body_len = message->body_len;
}

/**
 * Locks a message. Allows checking that applications don't keep a
 * reference to a message in the outgoing queue and change it
 * underneath us. Messages are locked when they enter the outgoing
 * queue (dbus_connection_send_message()), and the library complains
 * if the message is modified while locked.
 *
 * @param message the message to lock.
 */
void
_dbus_message_lock (DBusMessage *message)
{
  message->locked = TRUE;
}

/** @} */

/**
 * @defgroup DBusMessage DBusMessage
 * @ingroup  DBus
 * @brief Message to be sent or received over a DBusConnection.
 *
 * A DBusMessage is the most basic unit of communication over a
 * DBusConnection. A DBusConnection represents a stream of messages
 * received from a remote application, and a stream of messages
 * sent to a remote application.
 *
 * @{
 */

/**
 * @typedef DBusMessage
 *
 * Opaque data type representing a message received from or to be
 * sent to another application.
 */

/**
 * Constructs a new message. Returns #NULL if memory
 * can't be allocated for the message.
 * 
 * @return a new DBusMessage, free with dbus_message_unref()
 * @see dbus_message_unref()
 */
DBusMessage*
dbus_message_new (void)
{
  DBusMessage *message;

  message = dbus_new0 (DBusMessage, 1);
  if (message == NULL)
    return NULL;
  
  message->refcount = 1;

  /* We need to decide what a message contains. ;-) */
  message->header = _dbus_strdup ("H");
  message->header_len = 2;
  message->body = _dbus_strdup ("Body");
  message->body_len = 5;
  
  return message;
}


/**
 * Increments the reference count of a DBusMessage.
 *
 * @param message The message
 * @see dbus_message_unref
 */
void
dbus_message_ref (DBusMessage *message)
{
  message->refcount += 1;
}

/**
 * Decrements the reference count of a DBusMessage.
 *
 * @param message The message
 * @see dbus_message_ref
 */
void
dbus_message_unref (DBusMessage *message)
{
  _dbus_assert (message != NULL);
  _dbus_assert (message->refcount > 0);

  message->refcount -= 1;
  if (message->refcount == 0)
    {
      
      dbus_free (message);
    }
}

/** @} */

/**
 * @addtogroup DBusMessageInternals
 *
 * @{
 */
/**
 * @typedef DBusMessageLoader
 *
 * The DBusMessageLoader object encapsulates the process of converting
 * a byte stream into a series of DBusMessage. It buffers the incoming
 * bytes as efficiently as possible, and generates a queue of
 * messages. DBusMessageLoader is typically used as part of a
 * DBusTransport implementation. The DBusTransport then hands off
 * the loaded messages to a DBusConnection, making the messages
 * visible to the application.
 * 
 */

/**
 * Implementation details of DBusMessageLoader.
 * All members are private.
 */
struct DBusMessageLoader
{
  int refcount;        /**< Reference count. */
  
  int allocated;       /**< Allocated size of "data" */
  int length;          /**< Used size of "data" */

  unsigned char *data; /**< Buffered data. */

  DBusList *messages;  /**< Complete messages. */
  
  unsigned int buffer_outstanding : 1; /**< Someone is using the buffer to read */
};

/**
 * The initial buffer size of the message loader.
 * 
 * @todo this should be based on min header size plus some average
 * body size, or something. Or rather, the min header size only, if we
 * want to try to read only the header, store that in a DBusMessage,
 * then read only the body and store that, etc., depends on
 * how we optimize _dbus_message_loader_get_buffer() and what
 * the exact message format is.
 */
#define INITIAL_LOADER_DATA_LEN 32

/**
 * Creates a new message loader. Returns #NULL if memory can't
 * be allocated.
 *
 * @returns new loader, or #NULL.
 */
DBusMessageLoader*
_dbus_message_loader_new (void)
{
  DBusMessageLoader *loader;

  loader = dbus_new0 (DBusMessageLoader, 1);
  if (loader == NULL)
    return NULL;
  
  loader->refcount = 1;  
  
  /* Header, plus room for averagish other fields */
  loader->allocated = INITIAL_LOADER_DATA_LEN;
  loader->data = dbus_malloc (loader->allocated);
  if (loader->data == NULL)
    loader->allocated = 0;
  
  loader->length = 0;
  
  return loader;
}

/**
 * Increments the reference count of the loader.
 *
 * @param loader the loader.
 */
void
_dbus_message_loader_ref (DBusMessageLoader *loader)
{
  loader->refcount += 1;
}

/**
 * Decrements the reference count of the loader and finalizes the
 * loader when the count reaches zero.
 *
 * @param loader the loader.
 */
void
_dbus_message_loader_unref (DBusMessageLoader *loader)
{
  loader->refcount -= 1;
  if (loader->refcount == 0)
    {
      _dbus_list_foreach (&loader->messages,
                          (DBusForeachFunction) dbus_message_unref,
                          NULL);
      _dbus_list_clear (&loader->messages);
      dbus_free (loader->data);
      dbus_free (loader);
    }
}

/**
 * Gets the buffer to use for reading data from the network.  Network
 * data is read directly into an allocated buffer, which is then used
 * in the DBusMessage, to avoid as many extra memcpy's as possible.
 * The buffer must always be returned immediately using
 * _dbus_message_loader_return_buffer(), even if no bytes are
 * successfully read.
 *
 * @todo this function can be a lot more clever. For example
 * it can probably always return a buffer size to read exactly
 * the body of the next message, thus avoiding any memory wastage
 * or reallocs.
 * 
 * @param loader the message loader.
 * @param buffer address to store the buffer.
 * @param buffer_len address to store the buffer length.
 * @returns #FALSE if no buffer can be allocated.
 */
dbus_bool_t
_dbus_message_loader_get_buffer (DBusMessageLoader  *loader,
                                 unsigned char     **buffer,
                                 int                *buffer_len)
{
  _dbus_assert (!loader->buffer_outstanding);
  
#define MIN_BUFSIZE INITIAL_LOADER_DATA_LEN
  
  if ((loader->length + MIN_BUFSIZE) >= loader->allocated)
    {
      unsigned char *buf;
      int new_allocated;

      /* double (and add MIN_BUFSIZE, in case allocated == 0) */
      new_allocated = MIN_BUFSIZE + loader->allocated * 2;

      if (new_allocated <= loader->allocated)
        {
          /* ugh, overflow. Maybe someone is trying to screw us. */
          /* (we could overflow so far that new_allocated > loader->allocated
           *  but nothing should break in that case)
           */
          return FALSE;
        }
      
      buf = dbus_realloc (loader->data, new_allocated);
      if (buf == NULL)
        return FALSE;

      loader->data = buf;
      loader->allocated = new_allocated;
    }

  *buffer = loader->data + loader->length;
  *buffer_len = loader->allocated - loader->length;
  
  loader->buffer_outstanding = TRUE;

  return TRUE;
}

/**
 * Returns a buffer obtained from _dbus_message_loader_get_buffer(),
 * indicating to the loader how many bytes of the buffer were filled
 * in. This function must always be called, even if no bytes were
 * successfully read.
 *
 * @param loader the loader.
 * @param buffer the buffer.
 * @param bytes_read number of bytes that were read into the buffer.
 */
void
_dbus_message_loader_return_buffer (DBusMessageLoader  *loader,
                                    unsigned char      *buffer,
                                    int                 bytes_read)
{
  _dbus_assert (loader->buffer_outstanding);

  /* FIXME fake implementation just creates a message for every 7
   * bytes. The real implementation will pass ownership of
   * loader->data to new messages, to avoid memcpy.  We can also
   * smart-realloc loader->data to shrink it if it's too big, though
   * _dbus_message_loader_get_buffer() could strategically arrange for
   * that to usually not happen.
   */
  
  loader->length += bytes_read;

  loader->buffer_outstanding = FALSE;

  while (loader->length >= 7)
    {
      DBusMessage *message;
      
      message = dbus_message_new ();
      if (message == NULL)
        break; /* ugh, postpone this I guess. */

      _dbus_list_append (&loader->messages, message);

      memmove (loader->data, loader->data + 7,
               loader->length - 7);
      loader->length -= 7;

      _dbus_verbose ("Loaded message %p\n", message);
    }
}

/**
 * Pops a loaded message (passing ownership of the message
 * to the caller). Returns #NULL if no messages have been
 * loaded.
 *
 * @param loader the loader.
 * @returns the next message, or #NULL if none.
 */
DBusMessage*
_dbus_message_loader_pop_message (DBusMessageLoader *loader)
{
  return _dbus_list_pop_first (&loader->messages);
}

/** @} */
