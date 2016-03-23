#include "lmh.h"
#include <string.h>
#include <stdlib.h>

struct MHD_Daemon * C_start_daemon (unsigned int flags, uint16_t port, MHD_AcceptPolicyCallback apc, void * apc_cls,
				    MHD_AccessHandlerCallback dh, void * dh_cls)
{
  return MHD_start_daemon (flags, port, apc, apc_cls, dh, dh_cls, MHD_OPTION_END);
}

struct MHD_Daemon * C_start_daemon_with_options (unsigned int flags, uint16_t port, MHD_AcceptPolicyCallback apc, void * apc_cls,
						 MHD_AccessHandlerCallback dh, void * dh_cls, size_t connection_memory_limit,
						 unsigned int connect_limit, unsigned int connect_timeout, unsigned int ip_connection_limit,
						 unsigned int thread_pool_size, size_t thread_stack_size, unsigned int fastopen_queue_size,
						 struct MHD_OptionItem ops[])
{
  return MHD_start_daemon (flags, port, apc, apc_cls, dh, dh_cls, MHD_OPTION_CONNECTION_MEMORY_LIMIT, connection_memory_limit, MHD_OPTION_CONNECTION_LIMIT, connect_limit, MHD_OPTION_CONNECTION_TIMEOUT, connect_timeout,
			   MHD_OPTION_PER_IP_CONNECTION_LIMIT, ip_connection_limit, MHD_OPTION_THREAD_POOL_SIZE, thread_pool_size, MHD_OPTION_THREAD_STACK_SIZE, thread_stack_size,
			   MHD_OPTION_TCP_FASTOPEN_QUEUE_SIZE, fastopen_queue_size, MHD_OPTION_ARRAY, ops, MHD_OPTION_END);
}

struct stat sbuf;

struct stat * C_fstat (int fd)
{
  if (fstat (fd, &sbuf) == 0)
    {
      return &sbuf;
    }
  else
    return 0;
}

off_t C_file_size (struct stat * sbuf)
{
  return sbuf->st_size;
}

char * make_string (char ** str) {return *str;} 

char * string_to_c (char * str) {
  char * dest;
  dest = malloc (strlen (str) + 1);
  strcpy (dest, str);
  return dest;
}
