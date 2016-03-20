#include "lmh.h"

struct MHD_Daemon * C_start_daemon (unsigned int flags, uint16_t port, MHD_AcceptPolicyCallback apc, void * apc_cls,
				    MHD_AccessHandlerCallback dh, void * dh_cls)
{
  return MHD_start_daemon (flags, port, apc, apc_cls, dh, dh_cls, MHD_OPTION_END);
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
