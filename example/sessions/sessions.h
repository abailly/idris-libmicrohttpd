#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <microhttpd.h>

struct Session {struct Session * next; char sid [33]; unsigned int rc; uint64_t start; char value_1 [64]; char value_2 [64];};

struct Request {struct Session * session; struct MHD_PostProcessor * pp; const char * post_url;};

static struct Session *sessions;

void increment_session_count (struct Session * sess) {sess->rc++; }

struct Session * next_session (struct Session * sess) {return sess->next; }

void link_up_session (struct Session * sess)
{
  sess->next = sessions;
  sessions = sess;
}

void set_new_session_id (struct Session * sess)
{
  snprintf (sess->sid,
	    sizeof (sess->sid),
	    "%X%X%X%X",
	    (unsigned int) rand (),
	    (unsigned int) rand (),
	    (unsigned int) rand (),
	    (unsigned int) rand ());
}

typedef int (*PageHandler)(const void *cls,
			   const char *mime,
			   struct Session *session,
			   struct MHD_Connection *connection);

struct Page {const char *url; const char *mime; PageHandler handler; const void *handler_cls;};

void set_session_value_1 (struct Session * sess, uint64_t off, const char * data, uint64_t size)
{
  if (size + off > sizeof (sess->value_1))
	size = sizeof (sess->value_1) - off;
  memcpy (&sess->value_1[off],
	  data,
	  size);
  if (size + off < sizeof (sess->value_1))
    sess->value_1[size+off] = '\0';
}

void set_session_value_2 (struct Session * sess, uint64_t off, const char * data, uint64_t size)
{
  if (size + off > sizeof (sess->value_2))
	size = sizeof (sess->value_2) - off;
  memcpy (&sess->value_2[off],
	  data,
	  size);
  if (size + off < sizeof (sess->value_2))
    sess->value_2[size+off] = '\0';
}
