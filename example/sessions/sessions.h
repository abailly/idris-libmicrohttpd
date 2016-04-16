#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <time.h>
#include <microhttpd.h>

void initialize_random_generator ()
{
  srand ((unsigned int) time (NULL));
}

struct Session {struct Session * next; char sid [33]; unsigned int rc; uint64_t start; char value_1 [64]; char value_2 [64];};

struct Request {struct Session * session; struct MHD_PostProcessor * pp; const char * post_url;};

static struct Session *sessions;

struct Session * get_sessions () { return sessions;}

void set_sessions (struct Session * sess) {sessions = sess;}

void increment_session_count (struct Session * sess) {sess->rc++;}

void decrement_session_count (struct Session * sess) {sess->rc--;}

struct Session * next_session (struct Session * sess) {return sess->next;}

void set_next_session (struct Session * sess, struct Session * next) {sess->next = next;}

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

static int alive;

void mark_alive () { alive = 1;}

static struct timeval tv;
static struct timeval *tvp;
static fd_set rs;
static fd_set ws;
static fd_set es;
static MHD_socket max;
static MHD_UNSIGNED_LONG_LONG mhd_timeout;

int is_loop_running () { return alive;}

void run_loop (struct MHD_Daemon * d)
{
  printf ("Running loop iteration\n");
  alive = 1;
  max = 0;
  FD_ZERO (&rs);
  FD_ZERO (&ws);
  FD_ZERO (&es);
  if (MHD_YES != MHD_get_fdset (d, &rs, &ws, &es, &max))
    alive = 0; /* fatal internal error */
  if (alive)
    {
      printf ("About to check timeout\n");
      if (MHD_get_timeout (d, &mhd_timeout) == MHD_YES)
	{
	  tv.tv_sec = mhd_timeout / 1000;
	  tv.tv_usec = (mhd_timeout - (tv.tv_sec * 1000)) * 1000;
	  tvp = &tv;
	}
      else
	tvp = NULL;
      printf ("About to call select\n");
      if (-1 == select (max + 1, &rs, &ws, &es, tvp))
	{
	  if (EINTR != errno)
	    fprintf (stderr,
		     "Aborting due to error during select: %s\n",
		     strerror (errno));
	  alive = 0;
	}
      if (alive) {
	printf ("About to run MHD with daemon pointer set to %x...\n", d);
	int ret = MHD_run (d);
	printf ("About to run MHD...DONE. return code is %i\n", ret);
      }
    }
}
