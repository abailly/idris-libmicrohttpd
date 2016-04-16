||| Following tutorial C.7 - sessions.c
module Main

import MHD.Daemon
import MHD.Response
import MHD.POST
import MHD.Connection
import HTTP.Status_codes
import HTTP.Headers
import System
import CFFI
import Data.AVL.Dict
import Data.String

%include C "sessions.h"
%link C "lmh.o"
%link C "/usr/lib64/libmicrohttpd.so"

string_to_c : String -> IO Ptr
string_to_c str = foreign FFI_C "string_to_c" (String -> IO Ptr) str

string_from_c : Ptr -> IO String
string_from_c str = foreign FFI_C "make_string_2" (Ptr -> IO String) str

method_error : String
method_error = "<html><head><title>Illegal request</title></head><body>Go away.</body></html>"

not_found_error : String
not_found_error = "<html><head><title>Not found</title></head><body>Go away.</body></html>"

||| Test of HTML page where U needs to be changed to the v1 value
main_page : String
main_page = "<html><head><title>Welcome</title></head><body><form action=\"/2\" method=\"post\">What is your name? <input type=\"text\" name=\"v1\" value=\"U\" /><input type=\"submit\" value=\"Next\" /></body></html>"

||| Test of HTML page where U and V need to be changed to the v1 and v2 values respectively
second_page : String
second_page = "<html><head><title>Tell me more</title></head><body><a href=\"/\">previous</a> <form action=\"/S\" method=\"post\">U, what is your job? <input type=\"text\" name=\"v2\" value=\"V\" /><input type=\"submit\" value=\"Next\" /></body></html>"

submit_page : String
submit_page = "<html><head><title>Ready to submit?</title></head><body><form action=\"/F\" method=\"post\"><a href=\"/2\">previous </a> <input type=\"hidden\" name=\"DONE\" value=\"yes\" /><input type=\"submit\" value=\"Submit\" /></body></html>"

last_page : String
last_page = "<html><head><title>Thank you</title></head><body>Thank you.</body></html>"

initialize_random_generator : IO ()
initialize_random_generator = foreign FFI_C "initialize_random_generator" (IO ())

sessions_struct : Composite
sessions_struct = STRUCT [PTR, ARRAY 33 I8, I64, ARRAY 64 I8, ARRAY 64 I8]

||| Access to data passed between invocations of the request handler callback
sessions : IO Ptr
sessions = foreign FFI_C "get_sessions" (IO Ptr)

||| Set access to data passed between invocations of the request handler callback
set_sessions : Ptr -> IO ()
set_sessions next = foreign FFI_C "set_sessions" (Ptr -> IO ()) next

||| Set next session in chain
set_next_session : Ptr -> Ptr -> IO ()
set_next_session session next = foreign FFI_C "set_next_session" (Ptr -> Ptr -> IO ()) session next

increment_reference_count : Ptr -> IO ()
increment_reference_count session = foreign FFI_C "increment_session_count" (Ptr -> IO ()) session

decrement_reference_count : Ptr -> IO ()
decrement_reference_count session = foreign FFI_C "decrement_session_count" (Ptr -> IO ()) session
  
session_id : Ptr -> IO String
session_id session = do
  sid_fld <- pure $ (sessions_struct#1) session
  sid <- peek PTR sid_fld
  if sid == null then
    pure ""
  else
    string_from_c sid

cookie_name : String
cookie_name = "session"

next_session : Ptr -> IO Ptr
next_session session = foreign FFI_C "next_session" (Ptr -> IO Ptr) session

session_start_time : Ptr -> IO Bits64
session_start_time session = do
  start_fld <- pure $ (sessions_struct#3) session
  peek I64 start_fld
  
session_value_1 : Ptr -> IO String
session_value_1 session = do
  v1_fld <- pure $ (sessions_struct#4) session
  v1 <- peek PTR v1_fld
  s <- string_from_c v1
  pure $ substr 0 64 s

session_value_2 : Ptr -> IO String
session_value_2 session = do
  v2_fld <- pure $ (sessions_struct#5) session
  v2 <- peek PTR v2_fld
  s <- string_from_c v2
  pure $ substr 0 64 s
  
  
||| Search for an existing session whose session cookie matches @cookie
|||
||| @cookie - value of the session cookie
existing_session : (cookie : String) -> IO Ptr
existing_session cookie = do
  sess <- sessions
  if sess == null then
    pure null
  else do
    recurse cookie sess
 where 
   recurse : String -> Ptr -> IO Ptr
   recurse cookie sess = do
    sid <- session_id sess
    if sid == cookie then do
      increment_reference_count sess
      pure sess
    else do
      sess <- next_session sess
      if sess == null then
        pure null
      else
        recurse cookie sess
  
link_up_session : Ptr -> IO ()
link_up_session session = foreign FFI_C "link_up_session" (Ptr -> IO ()) session

set_new_session_id : Ptr -> IO ()
set_new_session_id session = foreign FFI_C "set_new_session_id" (Ptr -> IO ()) session

set_time : Ptr -> IO ()
set_time session = do
  t <- time
  let t2 = prim__truncBigInt_B64 t
  time_fld <- pure $ (sessions_struct#3) session  
  poke I64 time_fld t2

||| Create a fresh session and link it to the sessions list
fresh_session : IO Ptr
fresh_session = do
  CPt sess _ <- alloc sessions_struct
  if sess == null then do
    putStrLn "Out of memory allocating fresh session"
    pure null
  else do
    set_new_session_id sess
    increment_reference_count sess
    link_up_session sess
    set_time sess
    pure sess

||| Return the session handle for this connection, or create one if this is a new user.
|||
||| @conn - connection handle
get_session : (conn : Ptr) -> IO Ptr
get_session conn = do
  cookie <- lookup_connection_value conn MHD_COOKIE_KIND cookie_name
  b <- nullStr cookie
  if b then do
    ret <- existing_session cookie
    if ret == null then
      fresh_session
    else
      pure ret
  else
    fresh_session

||| Add a session cookie for @session to @response
|||
||| @session  - the session whose cookie we wish to set in the response headers
||| @response - the response being generated 
add_session_cookie : (session : Ptr) -> (response : Ptr) -> IO ()
add_session_cookie session response = do
  sid <- session_id session
  let sid2 = concat [cookie_name, "=", substr 0 256 sid]
  ret <- add_response_header response HTTP_set_cookie sid2
  pure ()
  
request_struct : Composite
request_struct = STRUCT [PTR, PTR, PTR]

||| Type of URL handlers    
|||
||| cls     - name of the web page to serve
||| mime    - content type to use
||| session - session handle (for adding session cookie)
||| conn    - connection over which we are responding
Handler : Type
Handler = (cls : String) -> (mime : String ) -> (session : Ptr) -> (conn : Ptr) -> IO Int

||| Handler that returns a simple static HTTP page that is passed in via @cls
serve_simple_form : Handler
serve_simple_form cls mime session conn = do
  response <- create_response_from_buffer cls MHD_RESPMEM_PERSISTENT
  add_session_cookie session response
  add_response_header response HTTP_content_encoding mime
  ret <- queue_response conn HTTP_ok response
  destroy_response response
  pure ret
  
||| Handler that adds the 'v1' value to the given HTML code.
fill_v1_form : Handler
fill_v1_form cls mime session conn = do
  v <- session_value_1 session
  let page_parts = unpack cls
  let page_part_strings = map singleton page_parts
  let replaced = replaceOn "U" v page_part_strings
  let page = concat replaced
  response <- create_response_from_buffer page MHD_RESPMEM_PERSISTENT
  add_session_cookie session response
  add_response_header response HTTP_content_encoding mime
  ret <- queue_response conn HTTP_ok response
  destroy_response response
  pure ret  

|||Handler that adds the 'v1' and 'v2' values to the given HTML code.
fill_v2_form : Handler
fill_v2_form cls mime session conn = do
  v1 <- session_value_1 session
  v2 <- session_value_2 session
  let page_parts = unpack cls
  let page_part_strings = map singleton page_parts
  let replaced = replaceOn "U" v1 page_part_strings
  let replaced_2 = replaceOn "V" v2 replaced
  let page = concat replaced_2
  response <- create_response_from_buffer page MHD_RESPMEM_PERSISTENT
  add_session_cookie session response
  add_response_header response HTTP_content_encoding mime
  ret <- queue_response conn HTTP_ok response
  destroy_response response
  pure ret  

|||Handler used to generate a 404 reply.
not_found_page : Handler
not_found_page ls mime session conn = do
  response <- create_response_from_buffer not_found_error MHD_RESPMEM_PERSISTENT
  add_session_cookie session response
  add_response_header response HTTP_content_encoding mime
  ret <- queue_response conn HTTP_not_found response
  destroy_response response
  pure ret  
  
set_session_value_1 : Ptr -> Bits64 -> String -> Bits64 -> IO ()
set_session_value_1 session offset post_data size = foreign FFI_C "set_session_value_1" (Ptr -> Bits64 -> String -> Bits64 -> IO ()) session offset post_data size
  
set_session_value_2 : Ptr -> Bits64 -> String -> Bits64 -> IO ()
set_session_value_2 session offset post_data size = foreign FFI_C "set_session_value_2" (Ptr -> Bits64 -> String -> Bits64 -> IO ()) session offset post_data size

||| POST processor
|||
||| cls               - struct Request *
||| kind              - type of value
||| file_name         - name of uploaded file - nullStr if not known
||| content_type      - MIME-type of the data - nullStr if not known
||| transfer_encoding - transfer encoding of the data - nullStr if not known
||| post_data         - @size bytes of data
||| offset            - offset of @post_data within the overall upload
||| size              - number of bytes in @post_data
iterate_post : POST_processor
iterate_post cls kind key file_name content_type transfer_encoding post_data offset size = unsafePerformIO $ do
  sess_fld <- pure $ (request_struct#0) cls
  sess <- peek PTR sess_fld
  v1 <- session_value_1 sess
  v2 <- session_value_2 sess
  sid <- session_id sess
  if key == "DONE" then do
     putStrLn $ concat ["Session ", sid, " submitted ", v1, ", ", v2]
     pure MHD_YES
  else 
    if key == "v1" then do
        set_session_value_1 sess offset post_data size
        pure MHD_YES
    else
      if key == "v2" then do
        set_session_value_2 sess offset post_data size
        pure MHD_YES       
      else do          
        putStrLn $ "Unsupported form value `" ++ key ++ "'"
        pure MHD_YES
 
iterator_wrapper : IO Ptr
iterator_wrapper = foreign FFI_C "%wrapper" ((CFnPtr POST_processor) -> IO Ptr) (MkCFnPtr iterate_post)
 
create_request : Ptr -> String -> String -> Ptr -> IO Int
create_request conn url method con_cls = do
  req <- alloc request_struct
  let request = toPtr req
  if request == null then do
    putStrLn "Failed to allocate request structure"
    pure MHD_NO
  else do
    poke PTR con_cls request
    if method == "POST" then do
      pp_fld <- pure $ (request_struct#1) request
      wr <- iterator_wrapper
      pp <- create_post_processor conn 1024 wr request
      if pp == null then do
        putStrLn $ "Failed to create POST processor for " ++ url
        pure MHD_NO
      else do
        poke PTR pp_fld pp
        pure MHD_YES
    else
      pure MHD_YES
  
set_session_for_request : (session : Ptr) -> (request : Ptr) -> IO ()
set_session_for_request session request = do
  sess_fld <- pure $ (request_struct#0) request
  poke PTR sess_fld session
  
||| Get post-processor from @request
|||
||| @request - the current request
post_processor_from_request : (request : Ptr) -> IO Ptr
post_processor_from_request request = do
  pp_fld <- pure $ (request_struct#1) request
  peek PTR pp_fld

||| Get post-url from @request
|||
||| @request - the current request
post_url_from_request : (request : Ptr) -> IO String
post_url_from_request request = do
  url_fld <- pure $ (request_struct#2) request
  url <- peek PTR url_fld
  string_from_c url
  
||| Map of URLs to (MIME-type, handler routine, page-skeleton) triples
pages : Dict String (String, Handler, String)
pages = fromList [
                  ("/", ("text/html", fill_v1_form, main_page)),
                  ("/2", ("text/html", fill_v2_form, second_page)),
                  ("/S", ("text/html", serve_simple_form, submit_page)),
                  ("/F", ("text/html", serve_simple_form, last_page))]
  
handle_get_head : (session : Ptr) -> (conn : Ptr) -> (url : String) -> IO Int
handle_get_head session conn url = do
  case lookup url pages of
    Nothing => do
      ret <- not_found_page "" "text/html" session conn
      finish ret url
    Just (mime, handler, page) => do
      ret <- handler page mime session conn
      finish ret url 
 where finish : Int -> String -> IO Int
       finish ret url = 
         if ret == MHD_YES then
           pure MHD_YES
         else do
           putStrLn $ "Failed to create page for " ++ url
           pure ret
  
handle_post : (request : Ptr) -> (session : Ptr) -> (conn : Ptr) -> (url : String) -> (up_d : String) -> (up_d_sz : Ptr) -> IO Int
handle_post request session conn url up_d up_d_sz = do
  pp <- post_processor_from_request request
  sz <- peek I64 up_d_sz
  post_process pp up_d sz
  if sz /= 0 then do
    poke I64 up_d_sz 0
    pure MHD_YES
  else do
    destroy_post_processor pp
    pp_fld <- pure $ (request_struct#1) request
    poke PTR pp_fld null
    post_url <- post_url_from_request request
    b <- nullStr post_url
    if b then
      handle_get_head session conn url
    else
      handle_get_head session conn post_url
 
handle_session : (request : Ptr) -> (session : Ptr) -> (conn : Ptr) -> (url : String) -> (method : String) -> (up_d : String) -> (up_d_sz : Ptr) -> IO Int
handle_session request session conn url method up_d up_d_sz = do
  set_time session
  if method == "POST" then do
    handle_post request session conn url up_d up_d_sz
  else
    if method == "GET" || method == "HEAD" then
      handle_get_head session conn url
    else do
      response <- create_response_from_buffer method_error MHD_RESPMEM_PERSISTENT
      ret <- queue_response conn HTTP_not_acceptable response
      destroy_response response
      pure ret
      
||| Our URL handler
answer_to_connection : Request_handler
answer_to_connection cls conn url method version up_d up_d_sz con_cls = unsafePerformIO $ do
  request <- peek PTR con_cls
  if request == null then
    create_request conn url method con_cls
  else do
    sess_fld <- pure $ (request_struct#0) request
    sess <- peek PTR sess_fld
    if sess == null then do
      sess <- get_session conn
      if sess == null then do
        putStrLn $ "Failed to set-up session for " ++ url
        pure MHD_NO
      else do
        set_session_for_request sess request
        handle_session request sess conn url method up_d up_d_sz
    else 
      handle_session request sess conn url method up_d up_d_sz
    
||| Termination notification handler
request_completed : Request_completed_handler
request_completed cls conn con_cls toe = unsafePerformIO $ do
  request <- peek PTR con_cls
  if request == null then
    pure ()
  else do
    sess_fld <- pure $ (request_struct#0) cls
    sess <- peek PTR sess_fld    
    if sess == null then
      pure ()
    else
      decrement_reference_count sess
    pp <- post_processor_from_request request
    destroy_post_processor pp
    free request
      
notify_completed_wrapper : IO Ptr
notify_completed_wrapper = foreign FFI_C "%wrapper" ((CFnPtr Request_completed_handler) -> IO Ptr) (MkCFnPtr request_completed)

start_options : Start_options
start_options = unsafePerformIO $ do 
  wr <- notify_completed_wrapper
  pure $ record {notify_completed = (wr, null), connection_timeout = 15, thread_pool_size = 0} default_options

||| Clean up handles of sessions that have been idle for too long.
expire_sessions : IO ()
expire_sessions = do
  putStrLn "About to get time"
  t <- time
  let t2 = prim__truncBigInt_B64 t
  putStrLn "About to get sessions"
  sess <- sessions
  if sess == null then
    pure ()
  else
    expire_session sess null t2
 where
   continue : Ptr -> Ptr -> Bits64 -> IO ()
   expire_session : Ptr -> Ptr -> Bits64 -> IO ()
   expire_session session prev now = do
     putStrLn "About to expire a session"
     next <- next_session session
     putStrLn "About to get start time"
     t <- session_start_time session
     if (prim__subB64 now t) > (60 * 60) then do
       if prev == null then do
         set_sessions next
       else
         set_next_session prev next
       free session
       continue next session now
     else
       continue next session now
   continue nx pv t =
     if nx == null then
       pure ()
     else
       expire_session nx pv t

wrapper : IO Ptr
wrapper = foreign FFI_C "%wrapper" ((CFnPtr Request_handler) -> IO Ptr) (MkCFnPtr answer_to_connection)

||| Run one iteration of the daemon listen loop
run_loop_C : Ptr -> IO ()
run_loop_C daemon = foreign FFI_C "run_loop" (Ptr -> IO ()) daemon

||| Is the daemon run-loop still alive?
is_loop_running_val : IO Int
is_loop_running_val = foreign FFI_C "is_loop_running" (IO Int)

||| Is the daemon run-loop still alive?
is_loop_running : IO Bool
is_loop_running = do
  b <- is_loop_running_val
  if b == 0 then
    pure False
  else
    pure True

mark_alive : IO ()
mark_alive = foreign FFI_C "mark_alive" (IO ())

||| Run one iteration of the daemon listen loop
run_loop : Ptr -> IO ()
run_loop daemon = do
  expire_sessions
  run_loop_C daemon
  
||| Run the server listening on @port
run_main : Bits16 -> IO ()
run_main port = do
  initialize_random_generator
  wr <- wrapper
  daemon <- start_daemon_with_options MHD_USE_DEBUG port null null (wr) null start_options
  case daemon == null of
    True => do
      putStrLn "Daemon failed to start"
      exit 2
    False => do
      mark_alive
      while is_loop_running (run_loop daemon)
      stop_daemon daemon
      pure ()
    
main : IO ()
main = do
  args <- getArgs
  case index' 1 args of
    Nothing => do
      putStrLn $ "Usage: sessions PORT" 
      exit 1
    (Just port) => do
      case length args == 2 of
        True => do
          case parsePositive {a=Bits16} port of
            Nothing => do
              putStrLn $ "Usage: sessions PORT" 
              exit 1
            Just p => run_main p        
        False => do
          putStrLn $ "Usage: sessions PORT" 
          exit 1
