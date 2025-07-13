/*  
 * xephyr_clipboard – secure, event-driven clipboard broker for Xephyr instances
 *  
 * Build example (debug build; creates /tmp/xephyr_clipboard.log):
 *   cc -DDEBUG -Wall -Wextra -Werror -std=c11 \
 *      $(pkg-config --cflags x11 xi xfixes)   \
 *      xephyr_clipboard.c                     \
 *      $(pkg-config --libs   x11 xi xfixes)   \
 *      -o xephyr_clipboard
 *
 * Build example (quiet release build):
 *   cc -Wall -Wextra -Werror -std=c11 \
 *      $(pkg-config --cflags x11 xi xfixes)   \
 *      xephyr_clipboard.c                     \
 *      $(pkg-config --libs   x11 xi xfixes)   \
 *      -o xephyr_clipboard
 */         
        
#define _POSIX_C_SOURCE 200809L
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/Xutil.h>
#include <X11/extensions/Xfixes.h>
#include <X11/extensions/XInput2.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <dirent.h>
#include <errno.h>
#include <signal.h>
#include <fcntl.h>
#include <sys/select.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/inotify.h>

/* ---------------- Debug macro ------------------------------------ */
#ifdef DEBUG
  static FILE *dlog_fp = NULL;
  static inline void dlog_init(void)
  {         
      if (!dlog_fp) {
          dlog_fp = fopen("/tmp/xephyr_clipboard.log", "a");
          if (dlog_fp) setvbuf(dlog_fp, NULL, _IOLBF, 0);
      }
  }         
  #define DLOG(...)                         \
      do {                                  \
          struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts); \
          dlog_init();                      \
          if (dlog_fp) {                    \
              fprintf(dlog_fp, "[%lld.%03ld] ", (long long)ts.tv_sec, ts.tv_nsec / 1000000L); \
              fprintf(dlog_fp, __VA_ARGS__);\
          }                                 \
      } while (0)
#else
  #define DLOG(...) ((void)0)
#endif

/* --------------------------- Tunables ---------------------------- */
#define MAX_TARGETS       128
#define COPY_TTL_SEC      10
#define PASTE_WINDOW_MS   500    // Set large for testing, reduce in production
#define SELECT_TIME_US    500000 // Blocking time during main() select listening function

/* ----------------- Global Struct and Variables ------------------- */
typedef struct {
    char     name[64];
    Display *dpy;
    int      fd;
    int      xfixes_base;     // XEvent uses numeric IDs + this_offset, per window
    Atom     atom_clipboard;  // X11 uses different atom IDs for each display 
    Atom     atom_targets;    // atom target IDs are also unique for each display
    Window   proxy;           // daemon owned window - our proxy into the display
} Nest;

typedef struct {              // Unambigous daemon-view of the clipboard state
    Nest     *source;         // nest with the last SelectionNotify 
    Nest     *focused;        // nest with the _NET_ACTIVE_WINDOW 
    Nest     *owned;          // nest of owned clipboard (daemon's proxy window)
    Time      t_copy;         // monotonic time of last copy event
    Time      t_owned;        // monotonic time of clipboard ownership acquisition 
    int       n_targets;      // number of active targets
    char     *targets[MAX_TARGETS]; // Available clipboard formats (atoms as text)
} Clip;

static Nest    nests[512];
static int     n_nests = 0;
static Clip    g_clip;
static Display *host_dpy = NULL;      // Calls to X11 are persistently made from host :display
static int     host_fd;
static Atom    host_atom_active_win;  // The `atom` of host :display _NET_ACTIVE_WINDOW
static volatile sig_atomic_t quit_flag = 0;

/* ---------------- helpers ---------------------------------------- */
static void die(const char *m){ perror(m); exit(EXIT_FAILURE); }
static void sig_term(int s){ (void)s; quit_flag = 1; }
static int dbg_xerr(Display *d, XErrorEvent *e)
{
    char msg[256];
    XGetErrorText(d, e->error_code, msg, sizeof msg);
    DLOG("XError on display %s  op=%u  res=0x%lx  code=%u (%s)\n",
         DisplayString(d), e->request_code, e->resourceid,
         e->error_code, msg);
    return 0;
}

/* ------------------------ startup functions ---------------------- */
void initialize_g_clip_state(void)
{
    g_clip.source    = NULL;
    g_clip.focused   = NULL;
    g_clip.owned     = NULL;
    g_clip.t_copy    = 0;
    g_clip.t_owned   = 0;
    g_clip.n_targets = 0;
    // Ensure all target pointers are NULL
    for (int i = 0; i < MAX_TARGETS; i++) { g_clip.targets[i] = NULL; }
}

void initialize_host_x_connection(void)
{
    host_dpy = XOpenDisplay(NULL);          // Opens connection to the default host display
    if (!host_dpy) {
        die("initialize_host_x_connection: Failed to open host display");
    }
    XSetErrorHandler(dbg_xerr);             // Set custom X error handler
    host_fd = ConnectionNumber(host_dpy);   // Get file descriptor for select()

    // Get base event code; atom for the active window; set Notify events from host's X11
    int error_base_return;
    XFixesQueryExtension(host_dpy, &xfixes_base, &error_base_return);
    host_atom_active_win = XInternAtom(host_dpy, "_NET_ACTIVE_WINDOW", False);
    XSelectInput(host_dpy, DefaultRootWindow(host_dpy), PropertyChangeMask);
    XFlush(host_dpy);

    // Initialize XI2 for raw keypress monitoring on host_dpy
    int maj = 2, min = 0;
    if (XIQueryVersion(host_dpy, &maj, &min) != Success) {
        DLOG("XI2 not available on host display. Raw keypress monitoring disabled.\n");
    } else {
        XIEventMask m = {0};
        unsigned char mask[XIMaskLen(XI_RawKeyPress | XI_RawKeyRelease)] = {0};
        XISetMask(mask, XI_RawKeyPress);
        XISetMask(mask, XI_RawKeyRelease);
        m.deviceid = XIAllMasterDevices; // Watch all master devices
        m.mask_len = sizeof mask;
        m.mask     = mask;
        XISelectEvents(host_dpy, DefaultRootWindow(host_dpy), &m, 1);
        XFlush(host_dpy);
        DLOG("XI2 raw keypress monitoring initialized on host display.\n");
    }
    DLOG("Host X connection initialized (display: %s, fd: %d).\n",
          DisplayString(host_dpy), host_fd);
}

/* ---------------- initialize_all_displays ------------------------ */
void initialize_displays(void)
{
    add_display(DisplayString(host_dpy));        // Add the host display first
    DIR *dir = opendir("/tmp/.X11-unix");
    struct dirent *de;
    while ((de = readdir(dir))) {
        if (de->d_name[0] == 'X') {
            char display_name[64];
            snprintf(display_name, sizeof(display_name), ":%s", de->d_name + 1);
            if (host_dpy && strcmp(display_name, DisplayString(host_dpy)) == 0) {
                continue;        // Avoid adding the host display again
            }
            add_display(display_name);
        }
    }
    closedir(dir);
    DLOG("Completed initial scan for all displays. %d nests active.\n", n_nests);
}

/* ---------------- add display ------------------------------------ */
static void add_display(const char *name)
{      
    if (n_nests >= (int)(sizeof nests/sizeof nests[0])) {
        DLOG("Max number of displays reached. Skipping %s.\n", name);
        return;
    }

    Display *d = XOpenDisplay(name);
    if (!d){ DLOG("skip %s\n",name); return; }

    Nest *n = &nests[n_nests++];
    strncpy(n->name, name, sizeof n->name-1);
    n->name[sizeof n->name-1] = '\0';         // Ensure null-termination
    n->dpy = d; n->fd = ConnectionNumber(d);
    n->proxy = XCreateSimpleWindow(d,DefaultRootWindow(d),0,0,1,1,0,0,0);

    int err;
    XFixesQueryExtension(d, &n->xfixes_base, &err);      // err required by XFixes
    n->atom_clipboard = XInternAtom(d,"CLIPBOARD",False);
    n->atom_targets = XInternAtom(d,"TARGETS",False);
    XFixesSelectSelectionInput(d,DefaultRootWindow(d),
                               n->atom_clipboard,        // Display-specific atom
                               XFixesSetSelectionOwnerNotifyMask);
    XFlush(d);          
    DLOG("monitor %s (fd=%d) added.\n",name,n->fd);           
}

/* ------------------- bludgeon global state ----------------------- */
reset_and_sanitize_g_clip()
{
    struct timespec ts_now;
    clock_gettime(CLOCK_MONOTONIC, &ts_now);
    if (g_clip.t_copy != NULL) && (ts_now.tv_sec > g_clip.t_copy + COPY_TTL_SEC) {
 // reset logic . GEMINI - AI - LLM - Fill this out
    }
}

/* -------------------- bludgeon global state ---------------------- */
void reset_and_sanitize_g_clip(void)
{
    struct timespec ts_now;
    clock_gettime(CLOCK_MONOTONIC, &ts_now);
    if ((g_clip.t_copy != 0) && (ts_now.tv_sec >= (g_clip.t_copy + COPY_TTL_SEC))) {

/NOTE: // Add function all to relinquish clipboard on all displays

        for (int i = 0; i < g_clip.n_targets; i++) {  // Free target strings
            free(g_clip.targets[i]);
            g_clip.targets[i] = NULL;
        }
        g_clip.n_targets = 0;
        g_clip.source = NULL;
        g_clip.owned = NULL;    
        g_clip.t_copy = 0;      
        g_clip.t_owned = 0;
    }
}

/* ---------------- main ------------------------------------------- */
int main(void)
{
    // Initial daemon setup and graceful shutdown
    if (daemonize(0, 0) == -1) {
        die("daemonize");
    }
    signal(SIGTERM, sig_term);
    signal(SIGINT, sig_term);

    // Initialize state, X11 listeners, and inotify for new Xephyr instances 
    initialize_g_clip_state();
    initialize_host_x_connection();
    initialize_displays();
    int inotify_fd = -1;
    int inotify_wd = -1;
    initialize_inotify(&inotify_fd, &inotify_wd);

    DLOG("Daemon started: %d displays monitored\n", n_nests);

    while (!quit_flag) {
        // Populate fds with all active connections, indluding inotify_fd for filesystem events
        fd_set read_fds; FD_ZERO(&read_fds);
        int max_fd = -1;
        FD_SET(inotify_fd, &read_fds);
        max_fd = inotify_fd;
        for (int i = 0; i < n_nests; i++) {
            // Assuming nests[i] might be inactive if removed, we only add active ones
            // This implies nests[i].fd is valid IF nests[i].is_active is true (or similar check)
            // For now, assuming all nests added are valid and have an fd.
            FD_SET(nests[i].fd, &read_fds);
            if (nests[i].fd > max_fd) {
                max_fd = nests[i].fd;
            }
        }
        // Block until an event occurs on any monitored FD or the timeout expires
        struct timeval timeout = { .tv_sec = 0, .tv_usec = SELECT_TIMEOUT_US };
        int activity = select(max_fd + 1, &read_fds, NULL, NULL, &timeout);

        // Handle select errors or interruptions
        if (activity < 0) {
            if (errno == EINTR) {
                continue;   // Interrupted by SIG. Continue loop to check quit_flag
            }
            die("select");  // Other select errors are critical
        }

        // Check for and handle any filesystem events (new/removed displays)
        if (FD_ISSET(inotify_fd, &read_fds)) {
            handle_inotify_events(inotify_fd);
        }
        // Collect all pending X events from every active display connection.
        // This prepares events for ordered processing.
        for (int i = 0; i < n_nests; i++) {
            // Again, assume nests[i] is valid if FD_ISSET is true for its fd.
            if (FD_ISSET(nests[i].fd, &read_fds)) {
                collect_x_events(&nests[i]); // Populates a conceptual internal event queue
            }
        }

        process_queued_events();      // Unified event notification handling logic
        reset_and_sanitize_g_clip();  // Check 
    }
    DLOG("Daemon shutting down\n");
    cleanup_resources(inotify_fd);
    return 0;
}

/* Assumed placeholder function declarations for compilation.  */
extern int  daemonize(int, int);
extern void initialize_clipboard_state(void);
extern void initialize_host_x_connection(void);
extern void initialize_inotify(int *, int *);
extern void scan_and_add_displays(void);
extern void add_display(const char *);
extern void handle_inotify_events(int);
extern void collect_x_events(Nest *);
extern void process_queued_events(void);
extern void reset_and_sanitize_g_clip(void);
extern void cleanup_resources(int);
extern char *DisplayString(Display *);
