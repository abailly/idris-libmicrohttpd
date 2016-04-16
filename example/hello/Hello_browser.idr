||| Following tutorial C.1 - hellobrowser.c
module Main

import MHD.Daemon
import MHD.Response
import HTTP.Status_codes
import System

%link C "lmh.o"
%link C "/usr/lib64/libmicrohttpd.so"

||| Our URL handler
answer_to_connection : Request_handler
answer_to_connection cls conn url method version up_d up_d_sz con_cls = unsafePerformIO $ do
  response <- create_response_from_buffer page MHD_RESPMEM_PERSISTENT
  ret <- queue_response conn HTTP_ok response
  destroy_response response
  pure ret
  
 where page : String
       page = "<html><body>Hello, browser!</body></html>"


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
