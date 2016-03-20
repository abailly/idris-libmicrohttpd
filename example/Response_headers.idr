||| Following tutorial C.3 - reponseheaders.c
module Main

import MHD.Daemon
import MHD.Response
import HTTP.Status_codes
import HTTP.Headers
import System


%link C "lmh.o"
%link C "/usr/lib64/libmicrohttpd.so"

||| Open file read-only
O_RDONLY : Int
O_RDONLY = 0

||| Open a file to get the file descriptor
open : (filename : String) -> (mode : Int) -> IO Int
open fnm mode = foreign FFI_C "open" (String -> Int -> IO Int) fnm mode

||| Close a file descriptor
fclose : Int -> IO ()
fclose fd = foreign FFI_C "close" (Int -> IO ()) fd

||| get file status
fstat : Int -> IO Ptr
fstat fd = foreign FFI_C "C_fstat" (Int -> IO Ptr) fd

||| get file size from file status
fsize : Ptr -> IO Bits64
fsize stat = foreign FFI_C "C_file_size" (Ptr -> IO Bits64) stat

respond_with_internal_server_error : Ptr -> IO Int
respond_with_internal_server_error conn = do
  response <- create_response_from_buffer "<html><body>An internal server error has occured!</body></html>" MHD_RESPMEM_PERSISTENT
  if response == null then
    pure MHD_NO
   else do
     ret <- queue_response conn HTTP_internal_server_error response
     destroy_response response
     pure ret
  
||| Our URL handler
answer_to_connection : Request_handler
answer_to_connection cls conn url method version up_d up_d_sz con_cls = unsafePerformIO $ do
  if method /= "GET" then
    pure MHD_NO
   else do
      fd <- open "GNU.png" O_RDONLY
      if fd < 0 then 
        do
          fclose fd
          respond_with_internal_server_error conn
       else do
          status <- fstat fd
          if status == null 
            then do
              fclose fd
              respond_with_internal_server_error conn
            else do
              size <- fsize status
              response <- create_response_from_fd_at_offset size fd 0
              add_response_header response HTTP_content_type "image/png"
              ret <- queue_response conn HTTP_ok response
              destroy_response response
              pure ret


wrapper : IO Ptr
wrapper = foreign FFI_C "%wrapper" ((CFnPtr Request_handler) -> IO Ptr) (MkCFnPtr  answer_to_connection)

main : IO ()
main = do
  wr <- wrapper
  daemon <- start_daemon MHD_USE_SELECT_INTERNALLY 8912 null null (wr) null
  case daemon == null of
    True  => exit 1
    False => do
      x <- getChar
      stop_daemon daemon
      pure ()
