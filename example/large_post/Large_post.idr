||| Following tutorial C.6 - largepost.c
module Main

import MHD.Daemon
import MHD.Response
import MHD.POST
import HTTP.Status_codes
import System
import CFFI

%include C "large_post.h"
%link C "lmh.o"
%link C "/usr/lib64/libmicrohttpd.so"

string_to_c : String -> IO Ptr
string_to_c str = foreign FFI_C "string_to_c" (String -> IO Ptr) str

string_from_c : Ptr -> IO String
string_from_c str = foreign FFI_C "make_string_2" (Ptr -> IO String) str

||| Maximum number of clients we permit to simultaneously upload files
maximum_client_count : Bits32
maximum_client_count = 2

||| Number of clients simultaneously uploading files
uploading_client_count : IO Bits32
uploading_client_count = foreign FFI_C "uploading_client_count" (IO Bits32)

||| Increase the count of clients uploading files
increment_uploading_client_count : IO ()
increment_uploading_client_count = foreign FFI_C "increment_uploading_clients" (IO ())

||| Decrease the count of clients uploading files
decrement_uploading_client_count : IO ()
decrement_uploading_client_count = foreign FFI_C "decrement_uploading_clients" (IO ())

||| Response given when maximum_clients would be exceeded
busy_page : String
busy_page = "<html><body>This server is busy, please try again later.</body></html>"

||| Form to request a file to be uploaded
|||
||| @u - the number of clients currently uploading
ask_page : (u : Bits32) -> String
ask_page u = concat (the (List String) ["<html><body>Upload a file, please!<br>There are ",
  (show u),
  " clients uploading at the moment.<br><form action=\"/filepost\" method=\"post\" enctype=\"multipart/form-data\"><input name=\"file\" type=\"file\"><input type=\"submit\" value=\" Send \"></form></body></html>"])
         
||| Response for successful file upload        
complete_page : String                                     
complete_page = "<html><body>The upload has been completed.</body></html>"

||| HTML text response for requests other than GET and correct POSTs
error_page : String
error_page = "<html><body>This doesn't seem to be right.</body></html>"

server_error_page : String                       
server_error_page  = "<html><body>An internal server error has occured.</body></html>"

file_exists_page : String
file_exists_page = "<html><body>This file already exists.</body></html>"


||| Send and HTML page as a response over the connection
|||
||| @conn - the connection handle
||| @text - text of the response page
||| @code - status code with which to respond
send_page : (conn : Ptr) -> (text : String) -> (code : Int) -> IO Int
send_page conn page code = do
  response <- create_response_from_buffer page MHD_RESPMEM_MUST_COPY
  is_null <- nullPtr response
  if is_null then
    pure MHD_NO
  else do
    ret <- queue_response conn code response
    destroy_response response
    pure ret
    
||| Format of data passed between invocations of the request handler callback
|||
||| Fields are:
||| Connection type
||| Answer string
||| POST processor
||| FILE pointer
||| Response code to accompany answer string
connection_information_struct : Composite
connection_information_struct = STRUCT [I8, PTR, PTR, PTR, I32]

||| Access to data passed between invocations of the request handler callback
connection_information : IO Ptr
connection_information = foreign FFI_C "&connection_information" (IO Ptr)

||| Request method
POST_type : Bits8
POST_type = 1

||| Request method
GET_type : Bits8
GET_type = 0

||| Longest name we allow
maximum_name_size : Bits64
maximum_name_size = 20

||| Longest response size we allow
maximum_answer_size : Nat
maximum_answer_size = 512

||| maximum number of bytes to use for internal buffering by POST processor
post_buffer_size : Bits64
post_buffer_size = 512

||| Termination notification handler
request_completed : Request_completed_handler
request_completed cls conn con_cls toe = unsafePerformIO $ do
  conn_info <- peek PTR con_cls
  if conn_info == null then
    pure ()
  else do
    conn_fld <- pure $ (connection_information_struct#0) conn_info
    connection_type <- peek I8 conn_fld
    if connection_type == POST_type then do
      pp_fld <- pure $ (connection_information_struct#2) conn_info
      pp <- peek PTR pp_fld
      if pp /= null then do
        destroy_post_processor pp
        decrement_uploading_client_count
      else
        pure ()
      clean_up conn_info
    else clean_up conn_info
 where
   clean_up : Ptr -> IO ()
   clean_up conn_info = do
     free conn_info
     poke PTR con_cls null
     pure ()
  
notify_completed_wrapper : IO Ptr
notify_completed_wrapper = foreign FFI_C "%wrapper" ((CFnPtr Request_completed_handler) -> IO Ptr) (MkCFnPtr request_completed)

start_options : Start_options
start_options = unsafePerformIO $ do 
  wr <- notify_completed_wrapper
  pure $ record {notify_completed = (wr, null)} default_options

||| POST processor
iterate_post : POST_processor
iterate_post cls kind key file_name content_type transfer_encoding post_data offset size = unsafePerformIO $ do
  answer_fld <- pure $ (connection_information_struct#1) cls
  fp_fld <- pure $ (connection_information_struct#3) cls
  code_fld <- pure $ (connection_information_struct#4) cls
  str <- string_to_c server_error_page 
  poke PTR answer_fld str  
  poke I32 code_fld (prim__zextInt_B32 HTTP_internal_server_error)
  if key == "file" then do
    f_ptr <- peek PTR fp_fld
    if f_ptr == null then do
      ei <- openFile file_name Read
      case ei of
        Right fp => do
          closeFile fp
          str <- string_to_c file_exists_page
          poke PTR answer_fld str
          poke I32 code_fld (prim__zextInt_B32 HTTP_forbidden)
          pure MHD_NO
        Left _   => do
          ei2 <- openFile file_name WriteTruncate
          case ei2 of
            Left _    => pure MHD_NO
            Right (FHandle fp2) => do
              poke PTR fp_fld fp2
              do_upload
    else 
      do_upload
  else pure MHD_NO
 where complete : CPtr -> CPtr -> IO Int
       complete answer_fld code_fld = do
         str <- string_to_c complete_page
         poke PTR answer_fld str
         poke I32 code_fld (prim__zextInt_B32 HTTP_ok)
         pure MHD_YES
       do_upload : IO Int
       do_upload = do
         code_fld <- pure $ (connection_information_struct#4) cls
         fp_fld <- pure $ (connection_information_struct#3) cls
         answer_fld <- pure $ (connection_information_struct#1) cls
         if (size > 0) then do
           fh <- peek PTR fp_fld
           let sz = fromIntegerNat $ prim__zextB64_BigInt size
           let sub = substr 0 sz post_data
           ei3 <- fPutStr (FHandle fh) sub
           case ei3 of
             Left _  => pure MHD_NO
             Right _ => complete answer_fld code_fld
       else
         complete answer_fld code_fld       
 
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
    if method == "POST" then do
      wr <- iterator_wrapper
      pp <- create_post_processor conn post_buffer_size wr conn_info
      if pp == null then do
        free conn_info
        pure MHD_NO
      else do
        pp_fld <- pure $ (connection_information_struct#2) conn_info
        poke PTR pp_fld pp
        answer_fld <- pure $ (connection_information_struct#1) conn_info
        str <- string_to_c complete_page 
        poke PTR answer_fld str        
        success conn_info con_cls POST_type
    else
      success conn_info con_cls GET_type
 where
   success : Ptr -> Ptr -> Bits8 -> IO Int
   success conn_info con_cls type = do 
     conn_fld <- pure $ (connection_information_struct#0) conn_info
     poke I8 conn_fld type
     poke PTR con_cls conn_info
     pure MHD_YES

||| Our URL handler
answer_to_connection : Request_handler
answer_to_connection cls conn url method version up_d up_d_sz con_cls = unsafePerformIO $ do
  conn_info <- peek PTR con_cls
  client_count <- uploading_client_count
  if conn_info == null then
    if client_count >= maximum_client_count then
      send_page conn busy_page HTTP_service_unavailable
    else
      create_connection_information conn method con_cls
  else
    if method == "GET" then
      send_page conn (ask_page client_count) HTTP_ok
    else 
       if method == "POST" then do
        size <- peek I64 up_d_sz
        if size /= 0 then do
          pp_fld <- pure $ (connection_information_struct#2) conn_info
          pp <- peek PTR pp_fld
          ret <- post_process pp up_d size
          poke I64 up_d_sz 0
          pure MHD_YES
        else do
          answer_fld <- pure $ (connection_information_struct#1) conn_info
          fp_fld <- pure $ (connection_information_struct#3) conn_info
          code_fld <- pure $ (connection_information_struct#4) conn_info
          answer <- peek PTR answer_fld
          fp <- peek PTR fp_fld
          code <- peek I32 code_fld
          if fp /= null then do
            closeFile (FHandle fp)
            poke PTR fp_fld null
          else do
            pure ()
          if answer /= null then do
            str <- string_from_c answer
            send_page conn str (prim__zextB32_Int code)
          else
            send_page conn error_page HTTP_bad_request
      else do
        send_page conn error_page HTTP_bad_request
  
wrapper : IO Ptr
wrapper = foreign FFI_C "%wrapper" ((CFnPtr Request_handler) -> IO Ptr) (MkCFnPtr answer_to_connection)
         
main : IO ()
main = do
  wr <- wrapper
  daemon <- start_daemon_with_options MHD_USE_SELECT_INTERNALLY 8912 null null (wr) null start_options
  case daemon == null of
    True  => exit 1
    False => do
      x <- getChar
      stop_daemon daemon
      pure ()
