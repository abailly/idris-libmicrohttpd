||| Functions for processing POST requests
module MHD.POST

import MHD.Connection -- for value kinds

||| Type of iterators across key-value pairs (POST data)
||| these should return MHD_YES to continue iterating or MHD_NO to abort iteration.
|||
||| cls               - argument given along with function pointer when registering callback
||| kind              - Type of values to iterate over - always MHD_POSTDATA_KIND
||| key               - The name of the value
||| file_name         - name of uploaded file (null if not known)
||| content_type      - MIME-type of the data (null if not known)
||| transfer_encoding - encoding type of the data (null if not known)
||| post_data         - @size bytes of data at the specified offset
||| offset            - offset of data in the overall value
||| size              - number of bytes of @post_data available
public export POST_processor : Type
POST_processor = (cls : Ptr) -> (kind : Int) -> (key : String) -> (file_name : String) ->  (content_type : String) -> (transfer_encoding : String) -> (post_data : String) -> (offset : Bits64) -> (size : Bits64) -> Int

export destroy_post_processor : Ptr -> IO ()
destroy_post_processor pp = foreign FFI_C "MHD_destroy_post_processor" (Ptr -> IO ()) pp

||| Parse and process POST data. Call this function when POST data is available (usually during an MHD_AccessHandlerCallback) with the "upload_data" and "upload_data_size". Whenever possible, this will then cause calls to the MHD_PostDataIterator.
|||
||| @pp               - the POST processor callback
||| @post_data        - the POSTed data
||| @post_data_length - length of @post_data
export post_process : (pp : Ptr) -> (post_data : String) -> (post_data_length : Bits64) -> IO Int
post_process pp post_data len = foreign FFI_C "MHD_post_process" (Ptr -> String -> Bits64 -> IO Int) pp post_data len

||| Create a struct MHD_PostProcessor.
||| A struct MHD_PostProcessor can be used to (incrementally) parse the data portion of a POST request. Note that some buggy browsers fail to set the encoding type. If you want to support those, you may have to call MHD_set_connection_value with the proper encoding type before creating a post processor (if no supported encoding type is set, this function will fail).
|||
||| Returns null on error (out of memory, unsupported encoding), otherwise a PP handle
||| @conn	 - the connection on which the POST is happening (used to determine the POST format)
||| @buffer_size - maximum number of bytes to use for internal buffering (used only for the parsing, specifically the parsing of the keys). A tiny value (256-1024) should be sufficient. Do NOT use a value smaller than 256. For good performance, use 32 or 64k (i.e. 65536).
||| @iter	 - iterator to be called with the parsed data, Must NOT be NULL.
||| @iter_cls	 - first argument to iter
export create_post_processor : (conn : Ptr) -> (buffer_size : Bits64) -> (iter : Ptr) -> (iter_cls : Ptr) -> IO Ptr
create_post_processor conn sz iter iter_cls = foreign FFI_C "MHD_create_post_processor" (Ptr -> Bits64 -> Ptr -> Ptr -> IO Ptr) conn sz iter iter_cls
