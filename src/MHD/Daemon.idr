||| Functions for starting a libmicrohttpd Daemon
module MHD.Daemon

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
||| TODO options argument
||| Result is a handle to the daemon (null on error)
export start_daemon : (flags : Bits32) -> (port : Bits16) -> (apc : Ptr) -> (apc_cls : Ptr) -> (handler : Ptr) -> (arg : Ptr) -> IO Ptr
start_daemon flags port apc apc_cls handler arg = do
  daemon <- foreign FFI_C "C_start_daemon" (Bits32 -> Bits16 -> Ptr -> Ptr -> Ptr -> Ptr -> IO Ptr) flags port apc apc_cls handler arg
  pure daemon
  
export stop_daemon : Ptr -> IO ()
stop_daemon daemon = foreign FFI_C "MHD_stop_daemon" (Ptr -> IO ()) daemon


