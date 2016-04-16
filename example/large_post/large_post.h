#include <stdint.h>
#include <stdio.h>
#include <microhttpd.h>

struct {int8_t connection_type; char *answer_string; struct MHD_PostProcessor *post_processor; FILE *fp; int answer_code;} connection_information;

static unsigned int number_uploading_clients = 0;

// these should really have synchronization:
void increment_uploading_clients () { number_uploading_clients += 1;}
void decrement_uploading_clients () { number_uploading_clients -= 1;}

unsigned int uploading_client_count () {return number_uploading_clients;}
