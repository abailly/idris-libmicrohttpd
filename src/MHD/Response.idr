||| Functions for dealing with response objects
module MHD.Response

||| Buffer is a persistent (static/global) buffer that won't change for at least the lifetime of the response, MHD should just use it, not free it, not copy it, just keep an alias to it.
export MHD_RESPMEM_PERSISTENT : Int
MHD_RESPMEM_PERSISTENT = 0

||| Buffer is heap-allocated with malloc() (or equivalent) and should be freed by MHD after processing the response has concluded (response reference counter reaches zero).
export MHD_RESPMEM_MUST_FREE : Int
MHD_RESPMEM_MUST_FREE = 1

||| Buffer is in transient memory, but not on the heap (for example, on the stack or non-malloc() allocated) and only valid during the call to MHD_create_response_from_buffer. MHD must make its own private copy of the data for processing.  
export MHD_RESPMEM_MUST_COPY : Int
MHD_RESPMEM_MUST_COPY = 2  

export queue_response : Ptr -> Int -> Ptr -> IO Int
queue_response conn code resp = foreign FFI_C "MHD_queue_response" (Ptr -> Bits32 -> Ptr -> IO Int) conn (prim__zextInt_B32 code) resp

export destroy_response : Ptr -> IO ()
destroy_response resp = foreign FFI_C "MHD_destroy_response" (Ptr -> IO ()) resp

||| Create an MHD_Response (for now treated as an opaque data type) from a buffer.
export create_response_from_buffer : (buffer : String) -> (memory_mode : Int) -> IO Ptr
create_response_from_buffer buffer mode =
  foreign FFI_C "MHD_create_response_from_buffer" (Bits64 -> String -> Bits32 -> IO Ptr) 
    (prim__zextInt_B64 $ toIntNat $ Prelude.Strings.length buffer) 
      buffer (prim__zextInt_B32 mode)
