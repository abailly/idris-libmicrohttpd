||| Functions that manipulate a connection
module Connection

%include C "lmh.h"

string_to_c : String -> IO Ptr
string_to_c str = foreign FFI_C "string_to_c" (String -> IO Ptr) str

-- Possible values for kind arguement to get_connection_values follow:
||| Response header
export MHD_RESPONSE_HEADER_KIND : Int
MHD_RESPONSE_HEADER_KIND = 0

||| HTTP header
export MHD_HEADER_KIND : Int	
MHD_HEADER_KIND = 1

||| Cookies. Note that the original HTTP header containing the cookie(s) will still be available and intact.
export MHD_COOKIE_KIND : Int 	
MHD_COOKIE_KIND = 2

||| POST data. This is available only if a content encoding supported by MHD is used (currently only URL encoding), and only if the posted content fits within the available memory pool. Note that in that case, the upload data given to the MHD_AccessHandlerCallback will be empty (since it has already been processed).
export MHD_POSTDATA_KIND : Int
MHD_POSTDATA_KIND = 4

||| GET (URI) arguments.
export MHD_GET_ARGUMENT_KIND : Int
MHD_GET_ARGUMENT_KIND = 8

||| HTTP footer (only for HTTP 1.1 chunked encodings).
export MHD_FOOTER_KIND : Int
MHD_FOOTER_KIND = 16

||| Get all of the headers from the request. Return the count of all headers
|||
||| @conn         - the connection on which to get the header values
||| @kind         - Type of values to iterate over
||| @iterator     - callback called on each key-value pair. May pass null.
||| @iterator_cls - additional argument to @iterator_cls
export get_connection_values : (conn : Ptr) -> (kind : Int) -> (iterator : Ptr) -> (iterator_cls : Ptr) -> IO Int
get_connection_values conn kind callback cls = foreign FFI_C "MHD_get_connection_values" (Ptr -> Int -> Ptr -> Ptr -> IO Int) conn kind callback cls

||| Get a particular header value. If multiple values match the kind, return any one of them.
|||
||| @conn         - the connection on which to get the header values
||| @kind         - Type of values to iterate over
||| @key          - the header to look for
export lookup_connection_value :  (conn : Ptr) -> (kind : Int) -> (key: String) -> IO String
lookup_connection_value conn kind key = foreign FFI_C "MHD_lookup_connection_value" (Ptr -> Int -> String -> IO String) conn kind key
 
