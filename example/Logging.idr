module Main

import MHD.Daemon
import MHD.Connection
import System

%link C "lmh.o"
%link C "/usr/lib64/libmicrohttpd.so"

||| Print out HTTP header (name-value pair)
print_key : (unused : Ptr) ->  (kind : Int) -> (key : String) -> (value : String) -> Int
print_key _ _ key value = unsafePerformIO $ do
  putStrLn $ key ++ ": " ++ value
  pure MHD_YES
  
print_wrapper : IO Ptr
print_wrapper = foreign FFI_C "%wrapper" ((CFnPtr (Ptr -> Int -> String -> String -> Int)) -> IO Ptr) (MkCFnPtr print_key)
 
||| Our URL handler
answer_to_connection : Request_handler
answer_to_connection cls conn url method version up_d up_d_sz con_cls = unsafePerformIO $ do
  putStrLn $ "New request " ++ method ++ " for " ++ url ++ " using version " ++ version
  wr <- print_wrapper
  count <- get_connection_values conn MHD_HEADER_KIND (wr) null
  pure MHD_NO

answer_wrapper : IO Ptr
answer_wrapper = foreign FFI_C "%wrapper" ((CFnPtr Request_handler) -> IO Ptr) (MkCFnPtr  answer_to_connection)

main : IO ()
main = do
  wr <- answer_wrapper
  daemon <- start_daemon MHD_USE_SELECT_INTERNALLY 8912 null null (wr) null
  case daemon == null of
    True  => exit 1
    False => do
      x <- getChar
      stop_daemon daemon
      pure ()
