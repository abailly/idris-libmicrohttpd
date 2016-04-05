#include <sys/types.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <microhttpd.h>

struct MHD_Daemon * C_start_daemon (unsigned int flags, uint16_t port, MHD_AcceptPolicyCallback apc, void * apc_cls,
				    MHD_AccessHandlerCallback dh, void * dh_cls);

struct MHD_Daemon * C_start_daemon_with_options (unsigned int flags, uint16_t port, MHD_AcceptPolicyCallback apc, void * apc_cls,
						 MHD_AccessHandlerCallback dh, void * dh_cls, size_t connection_memory_limit,
						 unsigned int connect_limit, unsigned int connect_timeout, unsigned int ip_connection_limit,
						 unsigned int thread_pool_size, size_t thread_stack_size, unsigned int fastopen_queue_size,
						 struct MHD_OptionItem ops[]);

struct stat * C_fstat (int fd);

off_t C_file_size (struct stat * sbuf);

char * make_string (char ** str);

char * make_string_2 (char * str);

char * string_to_c (char * str);
