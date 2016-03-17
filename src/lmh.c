#include "lmh.h"

struct MHD_Daemon * C_start_daemon (unsigned int flags, uint16_t port, MHD_AcceptPolicyCallback apc, void * apc_cls,
				    MHD_AccessHandlerCallback dh, void * dh_cls)
{
  return MHD_start_daemon (flags, port, apc, apc_cls, dh, dh_cls, MHD_OPTION_END);
}


