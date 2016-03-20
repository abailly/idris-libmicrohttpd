#include <sys/types.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <microhttpd.h>

struct MHD_Daemon * C_start_daemon (unsigned int flags, uint16_t port, MHD_AcceptPolicyCallback apc, void * apc_cls,
				    MHD_AccessHandlerCallback dh, void * dh_cls);

struct stat * C_fstat (int fd);

off_t C_file_size (struct stat * sbuf);

char * make_string (char ** str);
