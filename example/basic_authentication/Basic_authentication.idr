||| Following tutorial C.4 - basicauthentication.c
module Main

import MHD.Daemon
import MHD.Response
import MHD.Auth
import HTTP.Status_codes
import System
import CFFI

%link C "lmh.o"
%link C "/usr/lib64/libmicrohttpd.so"
 
string_from_c : Ptr -> IO String
string_from_c str = foreign FFI_C "make_string" (Ptr -> IO String) str

||| Our URL handler
answer_to_connection : Request_handler
answer_to_connection cls conn url method version up_d up_d_sz con_cls = unsafePerformIO $ do
  if method /= "GET" then 
    pure MHD_NO
  else do
    cc <- peek PTR con_cls
    if cc == null then do
      poke PTR con_cls conn 
      pure MHD_YES
    else do
      passwd <- alloc (T PTR)
      user <- basic_auth_get_username_password conn passwd
      null_str <- Prelude.Strings.nullStr user
      pass <- string_from_c passwd
      let fail = null_str || (user /= "root") || (pass /= "pa$$word")
      free passwd
      if fail then
        negative_response conn
      else
        positive_response conn
 where
   negative_response : Ptr -> IO Int
   negative_response conn = do
     response <- create_response_from_buffer "<html><body>Go away.</body></html>" MHD_RESPMEM_PERSISTENT
     ret <- queue_basic_auth_fail_response conn "my realm" response
     destroy_response response
     pure ret       
   positive_response : Ptr -> IO Int
   positive_response conn = do
     response <- create_response_from_buffer "<html><body>A secret.</body></html>" MHD_RESPMEM_PERSISTENT
     ret <- queue_response conn HTTP_ok response
     destroy_response response
     pure ret       

handler : IO Ptr
handler = foreign FFI_C "%wrapper" ((CFnPtr Request_handler) -> IO Ptr) (MkCFnPtr answer_to_connection)

main : IO ()
main = do
  wr <- handler
  daemon <- start_daemon MHD_USE_SELECT_INTERNALLY 8912 null null (wr) null
  case daemon == null of
    True  => exit 1
    False => do
      x <- getChar
      stop_daemon daemon
      pure ()
