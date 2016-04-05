||| Functions for start_daemonng a libmicrohttpd Daemon
module MHD.Daemon

import Data.Vect
import CFFI
import Control.Monad.State

%include C "lmh.h"

||| Allow connection
export MHD_YES : Int
MHD_YES = 1

||| Disallow connection
export MHD_NO : Int
MHD_NO = 0

||| Run using an internal thread (or thread pool) doing select().
export MHD_USE_SELECT_INTERNALLY : Bits32
MHD_USE_SELECT_INTERNALLY = 8

||| Type of request handlers - these should return MHD_yes or MHD_no
|||
||| cls              - argument given along with function pointer when registering callback
||| connection       - currently treated as a black-box
||| url              - name of the resource for the request being handled
||| method           - HTTP verb used to invoke the request
||| version          - e.g. HTTP/1.1
||| upload_data      - POST (e.g., or PUT) data. Excludes headers. (for a POST that fits into memory and that is encoded with a supported encoding, the POST data will NOT be given in upload_data and is instead available as part of MHD_get_connection_values (TODO); very large POST data will be made available incrementally in upload_data)
|||upload_data_size  - set initially to the size of the upload_data provided; handler must update this value to the number of bytes NOT processed;
||| con_cls          - pointer that the callback can set to some address and that will be preserved by MHD for future calls for this request; since the access handler may be called many times (i.e., for a PUT/POST operation with plenty of upload data) this allows the application to easily associate some request-specific state. If necessary, this state can be cleaned up in the global MHD_RequestCompletedCallback (which can be set with the MHD_OPTION_NOTIFY_COMPLETED). Initially, *con_cls will be null.
public export Request_handler : Type
Request_handler = (cls : Ptr) -> (connection : Ptr) -> (url : String) -> (method : String) -> (version : String) -> (upload_data : String) -> (upload_data_size : Ptr) -> (con_cls : Ptr) -> Int

-- Termination reasons follow

||| We finished sending the response.
MHD_REQUEST_TERMINATED_COMPLETED_OK : Int
MHD_REQUEST_TERMINATED_COMPLETED_OK = 0

||| Error handling the connection (resources exhausted, other side closed connection, application error accepting request, etc.)
MHD_REQUEST_TERMINATED_WITH_ERROR : Int
MHD_REQUEST_TERMINATED_WITH_ERROR = 1

||| No activity on the connection for the number of seconds specified using MHD_OPTION_CONNECTION_TIMEOUT.
MHD_REQUEST_TERMINATED_TIMEOUT_REACHED : Int
MHD_REQUEST_TERMINATED_TIMEOUT_REACHED = 2

||| We had to close the session since MHD was being shut down.
MHD_REQUEST_TERMINATED_DAEMON_SHUTDOWN : Int
MHD_REQUEST_TERMINATED_DAEMON_SHUTDOWN = 3

||| We tried to read additional data, but the other side closed the connection. This error is similar to MHD_REQUEST_TERMINATED_WITH_ERROR, but specific to the case where the connection died because the other side did not send expected data.
MHD_REQUEST_TERMINATED_READ_ERROR : Int
MHD_REQUEST_TERMINATED_READ_ERROR = 4

||| The client terminated the connection by closing the socket for writing (TCP half-closed); MHD aborted sending the response according to RFC 2616, section 8.1.4.
MHD_REQUEST_TERMINATED_CLIENT_ABORT : Int
MHD_REQUEST_TERMINATED_CLIENT_ABORT = 5


||| Type of handlers for notification on request completed
|||
||| cls              - argument given along with function pointer when registering callback
||| connection       - currently treated as a black-box
||| con_cls          - as set in last call to the Request_handler callback
||| toe              - termination reason
public export Request_completed_handler : Type
Request_completed_handler = (cls : Ptr) -> (conn : Ptr) -> (con_cls : Ptr) -> (toe : Int) -> ()

||| Start listening on a port - No key-value parameter list is passed
|||
||| @flags   - Any combination of MHD_FLAG enumeration
||| @port    - the port to listen on
||| @apc     - callback to check which clients will be allowed to connect - pass null to allow all clients
||| @apc_cls - extra argument to @apc
||| @handler - handler for all requests - this must be a function pointer of type Request_handler
||| @arg     - argument to be passed to @handler
||| Result is a handle to the daemon (null on error)
export start_daemon : (flags : Bits32) -> (port : Bits16) -> (apc : Ptr) -> (apc_cls : Ptr) -> (handler : Ptr) -> (arg : Ptr) -> IO Ptr
start_daemon flags port apc apc_cls handler arg = do
  daemon <- foreign FFI_C "C_start_daemon" (Bits32 -> Bits16 -> Ptr -> Ptr -> Ptr -> Ptr -> IO Ptr) flags port apc apc_cls handler arg
  pure daemon
  
export stop_daemon : Ptr -> IO ()
stop_daemon daemon = foreign FFI_C "MHD_stop_daemon" (Ptr -> IO ()) daemon

||| Default memory allowed per connection.
MHD_POOL_SIZE_DEFAULT : Bits64
MHD_POOL_SIZE_DEFAULT = 32 * 1024

||| Options that can be passed to start_daemon_with_options
public export record Start_options where
  constructor Make_start_options 
  ||| Maximum memory size per connection. Default is 32 kb (MHD_POOL_SIZE_DEFAULT). Values above 128k are unlikely to result in much benefit, as half of the memory will be typically used for IO, and TCP buffers are unlikely to support window sizes above 64k on most systems.
  connection_memory_limit : Bits64
  ||| Maximum number of concurrent connections to accept (default 10 - this wrapper only)
  connection_limit : Bits32
  ||| After how many seconds of inactivity should a connection automatically be timed out? (default 0 = no timeout)
  connection_timeout : Bits32
  ||| Register a function that should be called whenever a request has been completed (this can be used for application-specific clean up). Requests that have never been presented to the application (via Request_handler) will not result in notifications.
  ||| This option should be followed by TWO pointers. First a pointer to a function of type Request_completed_handler and second a pointer to a closure to pass to the request completed callback. The second pointer maybe null.
  notify_completed : (Ptr, Ptr)
  ||| Limit on the number of (concurrent) connections made to the server from the same IP address. Can be used to prevent one IP from taking over all of the allowed connections. If the same IP tries to establish more than the specified number of connections, they will be immediately rejected. 
  ||| The default is zero, which means no limit on the number of connections from the same IP address.
  per_ip_connection_limit : Bits32
  ||| Bind daemon to the supplied struct sockaddr. This option should be followed by a struct sockaddr *. If MHD_USE_IPv6 is specified, the struct sockaddr* should point to a struct sockaddr_in6, otherwise to a struct sockaddr_in.
  socket_address : Ptr
  ||| Specify a function that should be called before parsing the URI from the client. The specified callback function can be used for processing the URI (including the options) before it is parsed. 
  ||| The URI after parsing will no longer contain the options, which maybe inconvenient for logging. This option should be followed by two arguments, the first one must be of the form
  ||| void * my_logger(void *cls, const char *uri, struct MHD_Connection *con)
  ||| where the return value will be passed as (* con_cls) in calls to the Request_handler when this request is processed later
  ||| returning a value of null has no special significance (however, note that if you return non-null, you can no longer rely on the first call to the access handler having null == *con_cls on entry;)
  ||| "cls" will be set to the second argument. Finally, uri will be the 0-terminated URI of the request.
  ||| Note that during the time of this call, most of the connection's state is not initialized (as we have not yet parsed he headers). However, information about the connecting client (IP, socket) is available.
  uri_log_callback : (Ptr, Ptr)
  ||| Memory pointer for the private key (key.pem) to be used by the HTTPS daemon. This option should be followed by a const char * argument. This should be used in conjunction with https_mem_cert.
  https_mem_key : String
  ||| Memory pointer for the certificate (cert.pem) to be used by the HTTPS daemon. This option should be followed by a const char * argument. This should be used in conjunction with https_mem_key.
  https_mem_cert : String
  ||| Daemon credentials type. Followed by an argument of type gnutls_credentials_type_t.
  https_cred_type : Ptr
  ||| Memory pointer to a const char * specifying the cipher algorithm (default: "NORMAL").
  https_priorities : String
  ||| Pass a listen socket for MHD to use (systemd-style). If this option is used, MHD will not open its own listen socket(s). The argument passed must be of type int and refer to an existing socket that has been bound to a port and is listening.
  listen_socket : Int
  ||| Use the given function for logging error messages. This option must be followed by two arguments; the first must be a pointer to a function of type MHD_LogCallback and the second a pointer void * which will be passed as the first argument to the log callback.
  ||| Note that MHD will not generate any log messages if it was compiled without the "--enable-messages" flag being set.
  external_logger : (Ptr, Ptr)
  ||| Number of threads in thread pool. Enable thread pooling by setting this value to to something greater than 1. Currently, thread model must be MHD_USE_SELECT_INTERNALLY if thread pooling is enabled (start_daemon_with_options returns null for an unsupported thread model).
  thread_pool_size : Bits32
  ||| Specify a function that should be called for unescaping escape sequences in URIs and URI arguments. Note that this function will NOT be used by the struct MHD_PostProcessor. If this option is not specified, the default method will be used which decodes escape sequences of the form "%HH". This option should be followed by two arguments, the first one must be of the form
  |||
  ||| size_t my_unescaper(void *cls,
  |||                  struct MHD_Connection *c,
  |||                  char *s)
  ||| where the return value must be "strlen(s)" and "s" should be updated. Note that the unescape function must not lengthen "s" (the result must be shorter than the input and still be 0-terminated). "cls" will be set to the second argument following MHD_OPTION_UNESCAPE_CALLBACK.
  unescape_callback : (Ptr, Ptr)
  ||| Memory pointer for the random values to be used by the Digest Auth module. This option should be followed by two arguments. First an integer of type size_t which specifies the size of the buffer pointed to by the second argument in bytes. Note that the application must ensure that the buffer of the second argument remains allocated and unmodified while the deamon is running.
  digest_auth_random : String
  ||| Size of the internal array holding the map of the nonce and the nonce counter.
  nonce_nc_size : Bits32
  ||| Desired size of the stack for threads created by MHD. Use 0 for system default.
  thread_stack_size : Bits64
  ||| Memory pointer for the certificate (ca.pem) to be used by the HTTPS daemon for client authentification. 
  https_mem_trust : String
  ||| Increment to use for growing the read buffer. Must fit within connection_memory_limit.
  connection_memory_increment : Bits64
  ||| Use a callback to determine which X.509 certificate should be used for a given HTTPS connection. This option should be followed by a argument of type gnutls_certificate_retrieve_function2 *. This option provides an alternative to MHD_OPTION_HTTPS_MEM_KEY, MHD_OPTION_HTTPS_MEM_CERT. You must use this version if multiple domains are to be hosted at the same IP address using TLS's Server Name Indication (SNI) extension. In this case, the callback is expected to select the correct certificate based on the SNI information provided. The callback is expected to access the SNI data using gnutls_server_name_get(). Using this option requires GnuTLS 3.0 or higher.
  https_cert_callback : Ptr
  ||| When using MHD_USE_TCP_FASTOPEN, this option changes the default TCP fastopen queue length of 50. Note that having a larger queue size can cause resource exhaustion attack as the TCP stack has to now allocate resources for the SYN packet along with its DATA. 
  tcp_fastopen_queue_size : Bits32
  ||| Memory pointer for the Diffie-Hellman parameters (dh.pem) to be used by the HTTPS daemon for key exchange.
  https_mem_dhparams : String
  ||| If present and set to true, allow reusing address:port socket (by using SO_REUSEPORT on most platform, or platform-specific ways). If present and set to false, disallow reusing address:port socket (does nothing on most plaform, but uses SO_EXCLUSIVEADDRUSE on Windows). 
  listening_address_reuse : Maybe Bool
  
||| A Start_options record with all values set to defaults
export default_options : Start_options
default_options = Make_start_options MHD_POOL_SIZE_DEFAULT 10 0 (null, null) 0 null (null, null) "" "" null "" 0 (null, null) 1 (null, null) "" 0 0 "" 0 null 50 "" Nothing

||| Second field can be an I64 instead.
option_struct : Composite
option_struct = STRUCT [I32, PTR, PTR]

ops : Int -> Composite
ops n = ARRAY n option_struct

||| Which non-defaultable options are selected?
|||
||| @opts - all options, with or without defaults
selected_options : (opts : Start_options) -> Vect 16 Bool
selected_options opts = [(fst (notify_completed opts)) /= null,
                                 (socket_address opts) /= null,
                                 (fst (uri_log_callback opts)) /= null,
                                 (length (https_mem_key opts)) > 0,
                                 (length (https_mem_cert opts)) > 0,
                                 (https_cred_type opts) /= null,
                                 (length (https_priorities opts)) > 0,
                                 (listen_socket opts) /= 0,
                                 (fst (external_logger opts)) /= null,
                                 (fst (unescape_callback opts)) /= null,
                                 (length (digest_auth_random opts)) > 0,
                                 (length (https_mem_trust opts)) > 0,
                                 (connection_memory_increment opts) > 0,
                                 (https_cert_callback opts) /= null,
                                 (length (https_mem_dhparams opts)) > 0,
                                 (listening_address_reuse opts) /= Nothing]

||| Start daemon option for notification callback
MHD_OPTION_NOTIFY_COMPLETED : Bits32
MHD_OPTION_NOTIFY_COMPLETED = 4

||| Start daemon option for end of options list
MHD_OPTION_END : Bits32
MHD_OPTION_END = 0

||| Fill @array pointed to by @array_ptr with a notification callback
|||
||| @array_ptr - same as @array
||| @array     - ARRAY of size = selected options in @options
||| @options   - Options to be passed to daemon
fill_notify_completed : (array_ptr : CPtr) -> (array : Composite) -> (options : Start_options) -> StateT Nat IO ()
fill_notify_completed array_ptr array options = do
  let (callback, arg) = notify_completed options
  let fld = array # !get
  modify (+ (the Nat 1))
  let fld_0 = option_struct # 0
  let fld_1 = option_struct # 1
  let fld_2 = option_struct # 2
  lift $ poke I32 (fld_0 (fld array_ptr)) MHD_OPTION_NOTIFY_COMPLETED
  lift $ poke PTR (fld_1 (fld array_ptr)) callback
  lift $ poke PTR (fld_2 (fld array_ptr)) arg
  pure ()

||| Fill @array with those items of @ops that are True
|||
||| @array_ptr - same as @array
||| @array     - ARRAY of size = selected options in @ops
||| @opts      - Indices of selected_options which are selected
||| @options   - Options to be passed to daemon
fill_array : (array_ptr : CPtr) -> (array : Composite) -> (opts : Vect 16 Bool) -> (options : Start_options) -> StateT Nat IO ()
fill_array array_ptr array opts options = do
  if (index 0 opts) then do
    fill_notify_completed array_ptr array options
    let fld = array # !get
    let fld_0 = option_struct # 0
    let fld_1 = option_struct # 1
    let fld_2 = option_struct # 2
    lift $ poke I32 (fld_0 (fld array_ptr)) MHD_OPTION_END
    lift $ poke I64 (fld_1 (fld array_ptr)) 0 
    lift $ poke PTR (fld_2 (fld array_ptr)) null
  else do
    pure ()
  
||| Number of additional options in @opts that need to be passed to ops
|||
||| @opts - which options have been selected
option_count : (opts : Vect 16 Bool) -> Int
option_count opts = toIntNat $ fst $ filter (\x => x == True) opts

||| Start listening on a port - a key-value parameter list is built from @options
|||
||| @flags   - Any combination of MHD_FLAG enumeration
||| @port    - the port to listen on
||| @apc     - callback to check which clients will be allowed to connect - pass null to allow all clients
||| @apc_cls - extra argument to @apc
||| @handler - handler for all requests - this must be a function pointer of type Request_handler
||| @arg     - argument to be passed to @handler
||| @options - options governing the behaviour of the daemon
||| Result is a handle to the daemon (null on error)
export start_daemon_with_options : (flags : Bits32) -> (port : Bits16) -> (apc : Ptr) -> (apc_cls : Ptr) -> (handler : Ptr) -> (arg : Ptr) -> (options : Start_options) -> IO Ptr
start_daemon_with_options flags port apc apc_cls handler arg options = do
  let selected = selected_options options
  let array = ops (option_count (selected) + 1) -- +1 for the MHD_OPTION_END
  op_array <- alloc array
  runStateT (fill_array op_array array selected options) 0
  daemon <- foreign FFI_C "C_start_daemon_with_options" (Bits32 -> Bits16 -> Ptr -> Ptr -> Ptr -> Ptr -> Bits64 -> Bits32 -> Bits32 -> Bits32 ->
      Bits32 -> Bits64 -> Bits32 -> Ptr -> IO Ptr) flags port apc apc_cls handler arg (connection_memory_limit options) (connection_limit options) (connection_timeout options)  (per_ip_connection_limit options) (thread_pool_size options) (thread_stack_size options) (tcp_fastopen_queue_size options) op_array
  free op_array
  pure daemon

 
 
 
