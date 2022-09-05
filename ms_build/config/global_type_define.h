#ifndef GLOBAL_TYPE_DEFINE_H
#define GLOBAL_TYPE_DEFINE_H

#define SIZEOF_INT 4   /*sizeof(int)*/
#define SIZEOF_LONG 4  /*sizeof(long)*/
#define SIZEOF_LONG_LONG 8 /*sizeof(long long)*/
#define SIZEOF___INT64 8 /*sizeof( __int64 )*/

#if( SIZEOF_INT == 8 )

#define DBUS_INT64_TYPE int
#define DBUS_INT64_CONSTANT(val)  (val)
#define DBUS_UINT64_CONSTANT(val) (val##U)
#define DBUS_INT64_MODIFIER  "" )

#elif( SIZEOF_LONG == 8 )

#define DBUS_INT64_TYPE "long"
#define DBUS_INT64_CONSTANT(val)  (val##L)
#define DBUS_UINT64_CONSTANT(val) (val##UL)
#define DBUS_INT64_MODIFIER  "l"

#elif( SIZEOF_LONG_LONG == 8 )

#define DBUS_INT64_TYPE "long long"
#define DBUS_INT64_CONSTANT(val)  (val##LL)
#define DBUS_UINT64_CONSTANT(val) (val##ULL)
#define DBUS_INT64_MODIFIER  "ll"

#elif( SIZEOF___INT64 == 8 )

#define DBUS_INT64_TYPE "__int64"
#define DBUS_INT64_CONSTANT(val)  (val##i64)
#define DBUS_UINT64_CONSTANT(val) (val##ui64)
#define DBUS_INT64_MODIFIER  "I64" )

#else

#error("Please define right 8 char integer!")

#endif

#endif

