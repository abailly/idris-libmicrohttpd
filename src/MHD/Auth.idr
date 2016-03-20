||| Basic and digest authorization functions
module Auth

%include C "lmh.h"

||| Get the username and password from the basic authorization header sent by the client
||| Returns the username if found, or null
|||
||| @conn         - the connection on which to get the credentials
||| @pass         - pointer for the password
export basic_auth_get_username_password : (conn : Ptr) -> (pass : Ptr) -> IO String
basic_auth_get_username_password conn pass = 
  foreign FFI_C "MHD_basic_auth_get_username_password" (Ptr -> Ptr -> IO String) conn pass

||| Queues a response to request basic authentication from the client The given response object is expected to include the payload for the response; the "WWW-Authenticate" header will be added and the response queued with the 'UNAUTHORIZED' status code.
||| Returns MHD_YES on success, MHD_NO otherwise
|||
||| @conn  - the connection on which authorization failed
||| @realm - the name of the authentication realm
||| @resp  - response object to midfy and queue
export queue_basic_auth_fail_response : (conn : Ptr) -> (realm : String) -> (resp : Ptr) -> IO Int
queue_basic_auth_fail_response conn realm resp = 
  foreign FFI_C "MHD_queue_basic_auth_fail_response" (Ptr -> String -> Ptr -> IO Int) conn realm resp
