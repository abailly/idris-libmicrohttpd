#include <stdint.h>
#include <microhttpd.h>

struct {int8_t connection_type; char *answer_string; struct MHD_PostProcessor *post_processor;} connection_information;
