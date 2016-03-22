||| Following tutorial C.5 - simplepost.c
module Main

import MHD.Daemon
import MHD.Response
import MHD.POST
import HTTP.Status_codes
import System
import CFFI

%include C "simple_post.h"
%link C "lmh.o"
%link C "/usr/lib64/libmicrohttpd.so"

string_to_c : String -> IO Ptr
string_to_c str = foreign FFI_C "string_to_c" (String -> IO Ptr) str

string_from_c : Ptr -> IO String
string_from_c str = foreign FFI_C "make_string" (Ptr -> IO String) str

||| HTML text response for the initial GET inquiry
ask_page : String
ask_page = "<html><body>What's your name, Sir?<br><form action=\"/namepost\" method=\"post\"><input name=\"name\" type=\"text\"<input type=\"submit\" value=\" Send \"></form></body></html>" 

||| HTML text response for greeting the successful POST-er
greeting_page : String -> String
greeting_page s = concat ["<html><body><h1><center>Welcome, ", s, "!</center></h1></body></html>"]

||| HTML test response for requests other than GET and correct POSTs
error_page : String
error_page = "<html><body>This doesn't seem to be right.</body></html>"

||| Format of data passed between invocations of the request handler callback
connection_information_struct : Composite
connection_information_struct = STRUCT [I8, PTR, PTR]

||| Access to data passed between invocations of the request handler callback
connection_information : IO Ptr
connection_information = foreign FFI_C "&connection_information" (IO Ptr)

||| Send and HTML page as a response over the connection
send_page : Ptr -> String -> IO Int
send_page conn page = do
  response <- create_response_from_buffer page MHD_RESPMEM_PERSISTENT
  is_null <- nullPtr response
  if is_null then
    pure MHD_NO
  else do
    ret <- queue_response conn HTTP_ok response
    destroy_response response
    pure ret

||| Longest name we allow
maximum_name_size : Bits64
maximum_name_size = 20

||| Longest response size we allow
maximum_answer_size : Nat
maximum_answer_size = 512

||| maximum number of bytes to use for internal buffering by POST processor
post_buffer_size : Bits64
post_buffer_size = 512

||| POST processor
iterate_post : POST_processor
iterate_post cls kind key file_name content_type transfer_encoding post_data offset size = unsafePerformIO $ do
  if key == "name" then do
    if (size > 0) && (size < maximum_name_size) then do
      let answer = substr 0 maximum_answer_size $ greeting_page post_data
      fld_1 <- pure $ (connection_information_struct#1) cls
      str <- string_to_c answer
      poke PTR fld_1 str
      pure MHD_NO
    else do
      fld_1 <- pure $ (connection_information_struct#1) cls
      poke PTR fld_1 null
      pure MHD_NO
  else pure MHD_YES

||| Request method
POST_type : Bits8
POST_type = 1

||| Request method
GET_type : Bits8
GET_type = 0

||| Termination notification handler
request_completed : Request_completed_handler
request_completed cls conn con_cls toe = unsafePerformIO $ do
  conn_info <- peek PTR con_cls
  if conn_info == null then
    pure ()
  else do
    fld_0 <- pure $ (connection_information_struct#0) conn_info
    connection_type <- peek I8 fld_0
    if connection_type == POST_type then do
      fld_2 <- pure $ (connection_information_struct#2) conn_info
      pp <- peek PTR fld_2
      destroy_post_processor pp
      fld_1 <- pure $ (connection_information_struct#1) conn_info
      answer <- peek PTR fld_1
      mfree answer
      clean_up conn_info
    else clean_up conn_info
 where
   clean_up : Ptr -> IO ()
   clean_up conn_info = do
     free conn_info
     poke PTR con_cls null
     pure ()


iterator_wrapper : IO Ptr
iterator_wrapper = foreign FFI_C "%wrapper" ((CFnPtr POST_processor) -> IO Ptr) (MkCFnPtr iterate_post)

||| Create the connection_information_struct
|||
||| @conn    - the connection the request is running on
||| @method  - the request method
||| @con_cls - request callback-specific data
create_connection_information : (conn : Ptr) -> (method : String) -> (con_cls : Ptr) -> IO Int
create_connection_information conn method con_cls = do
  CPt conn_info _ <- alloc connection_information_struct
  if conn_info == null then
    pure MHD_NO
  else do
    fld_1 <- pure $ (connection_information_struct#1) conn_info
    poke PTR fld_1 null
    if method == "POST" then do
      wr <- iterator_wrapper
      pp <- create_post_processor conn post_buffer_size wr conn_info
      if pp == null then do
        free conn_info
        pure MHD_NO
      else do
        success conn_info con_cls POST_type     
    else
      success conn_info con_cls GET_type
 where
   success : Ptr -> Ptr -> Bits8 -> IO Int
   success conn_info con_cls type = do 
     fld_0 <- pure $ (connection_information_struct#0) conn_info
     poke I8 fld_0 type
     poke PTR con_cls conn_info
     pure MHD_YES

||| Our URL handler
answer_to_connection : Request_handler
answer_to_connection cls conn url method version up_d up_d_sz con_cls = unsafePerformIO $ do
  conn_info <- peek PTR con_cls
  if conn_info == null then
    create_connection_information conn method con_cls
  else
    if method == "GET" then do
      send_page conn ask_page
    else 
      if method == "POST" then do
        size <- peek I64 up_d_sz
        if size /= 0 then do
          fld_2 <- pure $ (connection_information_struct#2) conn_info
          pp <- peek PTR fld_2
          ret <- post_process pp up_d size
          poke I64 up_d_sz 0
          pure ret
        else do
          fld_1 <- pure $ (connection_information_struct#1) conn_info
          answer <- peek PTR fld_1
          if answer /= null then do
            str <- string_from_c answer
            send_page conn str
          else
            send_page conn error_page
      else do
        send_page conn error_page
   

wrapper : IO Ptr
wrapper = foreign FFI_C "%wrapper" ((CFnPtr Request_handler) -> IO Ptr) (MkCFnPtr answer_to_connection)
         
main : IO ()
main = do
  wr <- wrapper
  daemon <- start_daemon MHD_USE_SELECT_INTERNALLY 8912 null null (wr) null -- TODO need to pass the notify routine and need options
  case daemon == null of
    True  => exit 1
    False => do
      x <- getChar
      stop_daemon daemon
      pure ()
