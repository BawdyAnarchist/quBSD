/*
 * xephyr_clipboard – secure, event-driven clipboard broker for Xephyr instances
 *
 * Build example (debug build; creates /tmp/xephyr_clipboard.log):
 *   cc -DDEBUG -Wall -Wextra -Werror -std=c11 -g -I/usr/local/include xephyr_clipboard.c \
 *      -L/usr/local/lib -lX11 -lXi -lXfixes -o xephyr_clipboard
 *
 * Build example (quiet release build):
 *   cc -O2 -pipe -Wall -Wextra -std=c11 -I/usr/local/include xephyr_clipboard.c \
 *      -L/usr/local/lib -lX11 -lXi -lXfixes -o xephyr_clipboard
 */

#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/Xutil.h>
#include <X11/extensions/Xfixes.h>
#include <X11/extensions/XInput2.h>
#include <X11/keysym.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <dirent.h>
#include <errno.h>
#include <signal.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/event.h>

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
#define _POSIX_C_SOURCE   200809L
#define _XOPEN_SOURCE     700                  // for usleep(), daemon()
#define MAX_NESTS         512
#define MAX_TARGETS       128
#define COPY_TTL_SEC      10
#define PASTE_WINDOW_MS   500                  // Set large for testing, reduce in production
#define MAX_KEVENT_EVENTS 128
#define TIMESPEC_MS(ts)   ((long long)(ts.tv_sec) * 1000 + (ts.tv_nsec) / 1000000)
#define MAX_CLIP_BYTES    (16 * 1024 * 1024)   // 16MB

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
    Nest    *source;          // nest with the last SelectionNotify
    Nest    *focused;         // nest with the _NET_ACTIVE_WINDOW
    Nest    *owned;           // nest of owned clipboard (daemon's proxy window)
    long long t_copy;         // monotonic time of last copy event (ms)
    long long t_owned;        // monotonic time of clipboard ownership acquisition (ms)
    long long t_paste;        // monotonic time of raw ctrl-v detection (ms)
    int      n_targets;       // number of active targets
    char    *targets[MAX_TARGETS];  // Available clipboard formats (atoms as text)
} Clip;

static int     kq_fd = -1;               // kqueue file descriptor for init, cleanup, kevents
static Nest    nests[MAX_NESTS];         // Arbitrary but needs a number. Will dynamically compact
static int     n_nests = 0;
static Clip    g_clip;
static int     host_xi_opcode = 0;       // XI2 vars. We want to replicate all ctrl-c actions
static int     host_ctrl_l_keycode = 0;
static int     host_ctrl_r_keycode = 0;
static int     host_shift_l_keycode = 0;
static int     host_shift_r_keycode = 0;
static int     host_insert_keycode  = 0;
static int     ctrl_is_down = 0;         // 0 = up, 1 = down
static int     host_v_keycode = 0;
static int     shift_is_down        = 0;
static Display *host_dpy = NULL;      // X11 calls are always made from host display
static Atom    host_atom_active_win;  // The `atom` of _NET_ACTIVE_WINDOW for host display
static volatile sig_atomic_t quit_flag = 0;
static const struct timespec kevent_timeout_ts =
    { .tv_sec = 0, .tv_nsec = 500000000L };     // blocking time in main kevent

/* ----------------- prototype forward declarations ---------------- */
static void  reset_g_clip(int mode);
static void  initialize_host_x_connection(void);
static void  initialize_displays(void);
static void  setup_kqueue_filters(int kq_fd);
static void  add_display(const char *name);
static void  del_display(const char *name);
static void  synchronize_nests_to_sockets(void);
static Nest *fetch_focused_display(void);
static void  handle_focus_change(void);
static void  create_new_lease(Nest *n, XFixesSelectionNotifyEvent *ev);
static void  service_selection_request(Nest *n, XSelectionRequestEvent *req);
static void  cleanup_resources(int kq_fd);
static void  process_x_events(Nest *n, XEvent *event);

/* ---------------- helpers ---------------------------------------- */
static void die(const char *m) { fprintf(stderr, "%s: %s\n", m, strerror(errno)); exit(EXIT_FAILURE); }
static void sig_term(int s)    { (void)s; quit_flag = 1; }
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
void reset_g_clip(int mode)
{
    if (mode == 1 && g_clip.t_copy != 0) {          // mode 1 (lease check) actions
        struct timespec ts_now;
        clock_gettime(CLOCK_MONOTONIC, &ts_now);
        if (TIMESPEC_MS(ts_now) < (g_clip.t_copy + (COPY_TTL_SEC * 1000))) return;

        if (g_clip.owned) {                           // Clear ownership of the clipboard
            XSetSelectionOwner(g_clip.owned->dpy, g_clip.owned->atom_clipboard, None, CurrentTime);
            XFlush(g_clip.owned->dpy);
        }
        for (int i = 0; i < g_clip.n_targets; i++) {  // Clear targets memory
            free(g_clip.targets[i]);
            g_clip.targets[i] = NULL;
        }
    }
    // Actions common to mode 0 initialization and lease-check
    g_clip.source     = NULL;
    g_clip.focused    = NULL;
    g_clip.owned      = NULL;
    g_clip.t_copy     = 0;
    g_clip.t_owned    = 0;
    g_clip.t_paste    = 0;
    g_clip.n_targets  = 0;
}

void initialize_host_x_connection(void)
{
    // Open connection to the host display. Check, then set fd.
    host_dpy = XOpenDisplay(NULL);
    if (!host_dpy) {
        die("initialize_host_x_connection: Failed to open host display");
    }

    XSetErrorHandler(dbg_xerr);                         // Set custom X error handler
    // XI2 raw-event subscription (Ctrl-V & Button2 only)
    int xi_evt, xi_err;
    if (!XQueryExtension(host_dpy, "XInputExtension", &host_xi_opcode, &xi_evt, &xi_err))
        die("XInput2 not available on host display");
    int xi_major = 2, xi_minor = 0;
    XIQueryVersion(host_dpy, &xi_major, &xi_minor);   // require ≥2.0

    unsigned char xi_mask_bytes[2] = {0};
    XIEventMask xi_mask = { .deviceid = XIAllMasterDevices,
                            .mask_len = sizeof(xi_mask_bytes), .mask = xi_mask_bytes };
    XISetMask(xi_mask.mask, XI_RawKeyPress);
    XISetMask(xi_mask.mask, XI_RawKeyRelease);
    XISetMask(xi_mask.mask, XI_RawButtonPress);
    XISelectEvents(host_dpy, DefaultRootWindow(host_dpy), &xi_mask, 1);

    // Get the host atom for the active window, and set Notify events
    host_atom_active_win = XInternAtom(host_dpy, "_NET_ACTIVE_WINDOW", False);
    XSelectInput(host_dpy, DefaultRootWindow(host_dpy), PropertyChangeMask);
    XFlush(host_dpy);
    host_v_keycode = XKeysymToKeycode(host_dpy, XStringToKeysym("v"));
    host_ctrl_l_keycode = XKeysymToKeycode(host_dpy, XStringToKeysym("Control_L"));
    host_ctrl_r_keycode = XKeysymToKeycode(host_dpy, XStringToKeysym("Control_R"));
    host_shift_l_keycode = XKeysymToKeycode(host_dpy, XStringToKeysym("Shift_L"));
    host_shift_r_keycode = XKeysymToKeycode(host_dpy, XStringToKeysym("Shift_R"));
    host_insert_keycode  = XKeysymToKeycode(host_dpy, XStringToKeysym("Insert"));

    DLOG("Host X connection initialized (display: %s, fd: %d). Ctrl+V grab installed.\n",
          DisplayString(host_dpy), ConnectionNumber(host_dpy));
}

void initialize_displays(void)
{
    // Add host display first. Use the existing host_dpy connection as nests[0]
    memset(&nests[0], 0, sizeof nests[0]);
    snprintf(nests[0].name, sizeof nests[0].name, "%s", DisplayString(host_dpy));
    nests[0].dpy   = host_dpy;
    nests[0].fd    = ConnectionNumber(host_dpy);
    nests[0].proxy = XCreateSimpleWindow(host_dpy, DefaultRootWindow(host_dpy), 0,0,1,1,0,0,0);
    int ev_base, err_base;
    XFixesQueryExtension(host_dpy, &ev_base, &err_base);
    nests[0].xfixes_base = ev_base;
    nests[0].atom_clipboard = XInternAtom(host_dpy, "CLIPBOARD", False);
    nests[0].atom_targets   = XInternAtom(host_dpy, "TARGETS",   False);

    /* same XFixes subscriptions the other nests get */
    XFixesSelectSelectionInput(host_dpy, DefaultRootWindow(host_dpy),
                               nests[0].atom_clipboard, XFixesSetSelectionOwnerNotifyMask);
    // we already called XSelectInput() and the grabs on host_dpy earlier
    XFlush(host_dpy);
    n_nests = 1;   // host is now the first and only nest so far

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

void setup_kqueue_filters(int kq_fd)
{
    struct kevent evs[MAX_KEVENT_EVENTS];
    int n = 0;

    // Catch shutdown signals
    EV_SET(&evs[n++], SIGTERM, EVFILT_SIGNAL, EV_ADD, 0, 0, NULL);
    EV_SET(&evs[n++], SIGINT,  EVFILT_SIGNAL, EV_ADD, 0, 0, NULL);

    // Watch directory that holds X11 socket files
    static int dir_fd = -1;
    if (dir_fd == -1) {
        dir_fd = open("/tmp/.X11-unix", O_RDONLY | O_CLOEXEC);
        if (dir_fd == -1) die("open /tmp/.X11-unix");
    }
    EV_SET(&evs[n++], dir_fd, EVFILT_VNODE, EV_ADD | EV_CLEAR,
           NOTE_WRITE | NOTE_EXTEND | NOTE_DELETE | NOTE_RENAME, 0, NULL);

    // One EVFILT_READ per live display
    for (int i = 0; i < n_nests; i++) {
        Nest *np = &nests[i];
        if (!np->dpy) continue;                    // vacant slot
        EV_SET(&evs[n++], np->fd, EVFILT_READ, EV_ADD, 0, 0, np);
    }

    if (kevent(kq_fd, evs, n, NULL, 0, NULL) == -1)
        die("kevent EV_ADD");
}

/* --------------------- core logic functions ---------------------- */
static void add_display(const char *name)
{
    if (!name || n_nests >= MAX_NESTS) return;

    // Mechanism so host is always nests[0], while new sockets get the first unused[idx]
    int idx = -1;
    for (int i = 0; i < MAX_NESTS; i++)
        if (nests[i].name[0] == '\0') { idx = i; break; }
    if (idx == -1) return;

    Display *d = XOpenDisplay(name);                 // Open display
    if (!d) { DLOG("skip %s\n",name); return; }

    // Initialize the nest's properties
    Nest *n = &nests[idx];
    memset(n, 0, sizeof *n);                         // wipe old contents
    snprintf(n->name, sizeof(n->name), "%s", name);  // mark active
    n->dpy  = d; n->fd = ConnectionNumber(d);
    n->proxy = XCreateSimpleWindow(d,DefaultRootWindow(d),0,0,1,1,0,0,0);
    int ev_base, err_base;
    XFixesQueryExtension(d, &ev_base, &err_base);
    n->xfixes_base = ev_base;          /* store event-base offset */
    (void)err_base;                    /* Silence -Werror for unused variable */
    n->atom_clipboard = XInternAtom(d,"CLIPBOARD",False);
    n->atom_targets   = XInternAtom(d,"TARGETS",False);

    // Get X11 event notifications for selection and paste events
    XFixesSelectSelectionInput(d,DefaultRootWindow(d),
                               n->atom_clipboard,XFixesSetSelectionOwnerNotifyMask);
    XFlush(d);

    if (idx >= n_nests) n_nests = idx + 1;       // extend logical size
    if (kq_fd != -1) {                           // add new FD to kqueue
        struct kevent ev;
        EV_SET(&ev, n->fd, EVFILT_READ, EV_ADD, 0, 0, n);
        kevent(kq_fd, &ev, 1, NULL, 0, NULL);
    }
    DLOG("monitor %s (fd=%d) added.\n",name,n->fd);
}

static void del_display(const char *name)
{
    if (!name) return;
    for (int i = 1; i < n_nests; i++) {                   // Iterate over all (potential) nests except 0
        Nest *n = &nests[i];
        if (n->name[0] && strcmp(n->name, name) == 0) {
            if (kq_fd != -1 && n->fd != -1) {
                if (g_clip.source == n || g_clip.focused == n || g_clip.owned == n) {
                    reset_g_clip(0);                      // Fully reset state if the nest at all active
                }
                struct kevent ev;                         // remove from kqueue
                EV_SET(&ev, n->fd, EVFILT_READ, EV_DELETE, 0, 0, NULL);
                kevent(kq_fd, &ev, 1, NULL, 0, NULL);
            }
            if (n->dpy) XCloseDisplay(n->dpy);
            memset(n, 0, sizeof *n);                      // mark slot free
            n->fd = -1;

            while (n_nests > 0 && nests[n_nests-1].name[0] == '\0')
                n_nests--;                                // trim tail holes
            break;
        }
    }
}

static void synchronize_nests_to_sockets(void)
{
    /* kevent only informs there was a change, but not what. Must check and sync */
    DIR *dir;
    struct dirent *de;
    char socket_name[64];
    int n_sockets;
    char (*socket_names)[64] = calloc(MAX_NESTS, sizeof(char[64]));
    if (!socket_names) return;

    n_sockets = 0;
    dir = opendir("/tmp/.X11-unix");
    if (!dir) { free(socket_names); return; }

    while ((de = readdir(dir))) {
        if (de->d_name[0] == 'X') {
            snprintf(socket_name, sizeof(socket_name), ":%s", de->d_name + 1);
            // Skip host display in directory scan; it's permanently nests[0]
            if (host_dpy && strcmp(socket_name, DisplayString(host_dpy)) == 0) continue;
            if (n_sockets < MAX_NESTS) {
                snprintf(socket_names[n_sockets], sizeof(socket_names[0]), "%s", socket_name);
                n_sockets++;
            }
        }
    }
    closedir(dir);
    for (int i = 1; i < n_nests; i++) {                // Nests with no socket (exlcuding host)
        Nest *n = &nests[i];
        if (n->name[0] == '\0') continue;              // Skip empty slots
        int found = 0;
        for (int j = 0; j < n_sockets; j++) {
            if (strcmp(n->name, socket_names[j]) == 0) {
                found = 1; break;
            }
        }
        if (!found) del_display(n->name);              // remove the nest
    }
    for (int i = 0; i < n_sockets; i++) {              // Sockets with no nest
        const char *potential_new_name = socket_names[i];
        int found = 0;
        for (int j = 0; j < n_nests; j++) {
            Nest *n = &nests[j];
            if (n->name[0] == '\0') continue;
            if (strcmp(n->name, potential_new_name) == 0) {
                found = 1; break;
            }
        }
        if (!found) add_display(potential_new_name);   // Add the display to nests[]
    }
    free(socket_names);
}

static Nest *fetch_focused_display(void)
{
    // Obtain host _NET_ACTIVE_WINDOW
    Atom type; int fmt; unsigned long n, l;
    unsigned char *data = NULL;
    if (XGetWindowProperty(host_dpy, DefaultRootWindow(host_dpy), host_atom_active_win, 0, 1,
                           False, XA_WINDOW, &type, &fmt, &n, &l, &data) != Success || !n)
        return &nests[0];
    Window aw = *(Window *)data;
    XFree(data);

    // Fetch the window title and extract :NNN from "Xephyr on :NNN.M …"
    char *title = NULL;
    if (!XFetchName(host_dpy, aw, &title) || !title) return &nests[0];   // Fast return if lacking title
    char parsed[64] = "";
    char *p = strstr(title, "Xephyr on ");
    if (p) {
        p += strlen("Xephyr on ");
        char *end = strpbrk(p, " ."); // Stop at first space or dot
        if (end) {
            size_t len = (size_t)(end - p);
            if (len >= sizeof parsed) len = sizeof parsed - 1;
            memcpy(parsed, p, len);
            parsed[len] = '\0';
        }
    }
    // Map parsed string to a monitored display
    if (*parsed) {
        for (int i = 0; i < n_nests; i++) {
            if (nests[i].name[0] && strcmp(nests[i].name, parsed) == 0) {
                XFree(title);
                return &nests[i];
            }
        }
    }
    XFree(title);
    return &nests[0];
}

static void handle_focus_change(void)
{
    if (g_clip.t_copy == 0) return;           // No active lease, nothing to transfer

    // Determine displays
    Nest *old_focus = g_clip.focused;
    Nest *old_owned = g_clip.owned;
    Nest *new_focus = fetch_focused_display();
    if (!new_focus) return;
    if (new_focus == old_focus) return;       // Display did not actually change
    g_clip.focused = new_focus;

    // Grab clipboard ownership of new focus
    if (XGetSelectionOwner(new_focus->dpy, new_focus->atom_clipboard) != new_focus->proxy
            && new_focus != g_clip.source) {
        XSetSelectionOwner(new_focus->dpy, new_focus->atom_clipboard, new_focus->proxy, CurrentTime);
        XFlush(new_focus->dpy);
    }
    g_clip.owned = new_focus;
    struct timespec ts_now; clock_gettime(CLOCK_MONOTONIC, &ts_now);
    g_clip.t_owned = TIMESPEC_MS(ts_now);

    // Relinquish on previous display
    if (old_owned && new_focus != old_owned && old_owned != g_clip.source
                  && XGetSelectionOwner(old_owned->dpy, old_owned->atom_clipboard) == old_owned->proxy) {
        XSetSelectionOwner(old_owned->dpy, old_owned->atom_clipboard, None, CurrentTime);
        XFlush(old_owned->dpy);
    }
    DLOG("Focus change: %s is now focused\n", new_focus->name);
}

static void create_new_lease(Nest *n, XFixesSelectionNotifyEvent *ev)
{
    /* This function intentionally blocks for 200ms to get targets, to prevent any possibility
       of unexpected interactions of races with other incoming XI2 or kevent signals.*/

    // Wipe previous targets before getting new ones
    if (ev->owner == n->proxy || ev->owner == None || ev->selection != n->atom_clipboard) return;
    for (int i = 0; i < g_clip.n_targets; i++) {
        free(g_clip.targets[i]);
        g_clip.targets[i] = NULL;
    }
    g_clip.source     = n;
    g_clip.n_targets  = 0;

    // Request TARGETS from the new owner via proxy with blocking listen - 200ms timeout
    Atom atom_new = XInternAtom(n->dpy, "XC_CLIP_PROP", False);
    XConvertSelection(n->dpy, ev->selection, n->atom_targets, atom_new, n->proxy, ev->timestamp);
    XFlush(n->dpy);
    XEvent event;
    struct timespec start, now;
    clock_gettime(CLOCK_MONOTONIC, &start);
    while (1) {
        if (XCheckTypedEvent(n->dpy, SelectionNotify, &event)) {
            if  (event.xselection.property == atom_new) break;  // Found our event
            else XPutBackEvent(n->dpy, &event);                 // Not ours put back on queue
        }
        clock_gettime(CLOCK_MONOTONIC, &now);
        if (TIMESPEC_MS(now) - TIMESPEC_MS(start) > 200) {
            XDeleteProperty(n->dpy, n->proxy, atom_new);
            return;
        }
        usleep(1000);
    }

    // Xlib is verbose. This is boilerplate for verification and retreival
    XSelectionEvent *sev = &event.xselection;
    if (sev->property == None) return;           // Nothing returned
    Atom type_ret;                               // Read TARGETS list from property proxy
    int fmt_ret;
    unsigned long n_items, bytes_after;
    unsigned char *data = NULL;
    XGetWindowProperty(n->dpy, n->proxy, atom_new, 0, MAX_TARGETS, False, XA_ATOM,
                       &type_ret, &fmt_ret, &n_items, &bytes_after, &data);
    XDeleteProperty(n->dpy, n->proxy, atom_new); // Clean up immediately
    if (!data || n_items == 0) { XFree(data); return; }

    // Update g_clip
    Atom *targets_list = (Atom *)data;                  // Add new targets
    for (unsigned long i = 0; i < n_items && g_clip.n_targets < MAX_TARGETS; i++) {
        char *atom_name = XGetAtomName(n->dpy, targets_list[i]);
        if (atom_name) {
            g_clip.targets[g_clip.n_targets++] = strdup(atom_name);
            XFree(atom_name);
        }
    }
    XFree(data);
    g_clip.t_copy = TIMESPEC_MS(now);
    DLOG("Lease created. Source=%s, Targets=%d, TTL=%ds\n", n->name, g_clip.n_targets, COPY_TTL_SEC);
}

static void service_selection_request(Nest *n, XSelectionRequestEvent *req)
{
    /* This function blocks for 200ms after serving targets to destination, waiting for response; and
       again to wait for source data. Prevents unexpected interactions/races with other events.*/

    // Pre filters: Fast-deny invalid / insecure requests
    struct timespec ts_now;
    clock_gettime(CLOCK_MONOTONIC, &ts_now);
    if (req->selection != n->atom_clipboard) goto deny;
    if (g_clip.t_paste == 0 || TIMESPEC_MS(ts_now) > g_clip.t_paste + PASTE_WINDOW_MS) {
        char *t_name = XGetAtomName(n->dpy, req->target);
        if (t_name) XFree(t_name);
        goto deny;
    }
    if (n != g_clip.focused || n != g_clip.owned) goto deny;
    // dest_prop must be valid for every success-path (incl. TARGETS branch)
    Atom dest_prop = req->property ? req->property : req->target;

    // TARGET resolution. Handle request for 'TARGETS' list
    if (req->target == n->atom_targets) {
        Atom target_atoms[MAX_TARGETS];
        int n_atoms = 0;
        for (int i = 0; i < g_clip.n_targets && i < MAX_TARGETS; i++)
            target_atoms[n_atoms++] = XInternAtom(n->dpy, g_clip.targets[i], False);
        XChangeProperty(n->dpy, req->requestor, dest_prop, XA_ATOM, 32,
                        PropModeReplace, (unsigned char *)target_atoms, n_atoms);

        // SEND SELECTIONNOTIFY FOR TARGETS
        XSelectionEvent se_target_ok = {0};
        se_target_ok.type = SelectionNotify; se_target_ok.display = req->display;
        se_target_ok.requestor = req->requestor; se_target_ok.selection = req->selection;
        se_target_ok.target = req->target; se_target_ok.property = dest_prop;
        se_target_ok.time = req->time;
        XSendEvent(n->dpy, req->requestor, False, 0, (XEvent *)&se_target_ok);
        XFlush(n->dpy);

        // BLOCK, waiting for the follow-up SelectionRequest
        XEvent follow_up_event;
        struct timespec start_wait; clock_gettime(CLOCK_MONOTONIC, &start_wait);
        while (1) {
            if (XCheckTypedEvent(n->dpy, SelectionRequest, &follow_up_event)) {
                XSelectionRequestEvent *next_req = &follow_up_event.xselectionrequest;
                if (next_req->requestor == req->requestor &&
                    next_req->selection == req->selection &&
                    next_req->target != n->atom_targets) {
                    *req = *next_req; // Overwrite original request with the real one
                    dest_prop = next_req->property ? next_req->property : next_req->target;
                    break;
                }
                XPutBackEvent(n->dpy, &follow_up_event); // Not ours, put back
            }
            struct timespec now_wait; clock_gettime(CLOCK_MONOTONIC, &now_wait);
            if (TIMESPEC_MS(now_wait) - TIMESPEC_MS(start_wait) > 200) {
                goto deny;
            }
            usleep(1000);
        }
    }

    // Fetch data from source
    char *target_name = XGetAtomName(n->dpy, req->target);
    if (!target_name) goto deny;
    int target_found = 0;
    for (int i = 0; i < g_clip.n_targets; i++) {
        if (strcmp(target_name, g_clip.targets[i]) == 0) { target_found = 1; break; }
    }
    if (!target_found) { XFree(target_name); goto deny; }

    // Request data from source display, placing it in a temporary property on our proxy
    Nest *source_nest = g_clip.source;
    Atom source_target_atom = XInternAtom(source_nest->dpy, target_name, False);
    Atom prop_atom = XInternAtom(source_nest->dpy, "XC_CLIP_FETCH_PROP", False);
    XFree(target_name);
    Atom sel = source_nest->atom_clipboard;
    XConvertSelection(source_nest->dpy, sel, source_target_atom, prop_atom, source_nest->proxy, req->time);
    XFlush(source_nest->dpy);

    // Block with a timeout waiting for the source to deliver the data
    XEvent event;
    clock_gettime(CLOCK_MONOTONIC, &ts_now);
    long start_ms = TIMESPEC_MS(ts_now);
    while (1) {
        if (XCheckTypedWindowEvent(source_nest->dpy, source_nest->proxy, SelectionNotify, &event)) {
            if (event.xselection.property == prop_atom) {
                break;                 // Correct event found, proceed.
            } else {                   // Stray/old SelectionNotify. Put it back.
                XPutBackEvent(source_nest->dpy, &event);
            }
        }
        clock_gettime(CLOCK_MONOTONIC, &ts_now);
        if (TIMESPEC_MS(ts_now) - start_ms > 200) {
            XDeleteProperty(source_nest->dpy, source_nest->proxy, prop_atom);
            goto deny;
        }
        usleep(1000);
    }

    // Read data from the temporary property
    if (event.xselection.property == None) goto deny;
    Atom type_ret;
    int fmt_ret;
    unsigned long n_items, bytes_after;
    unsigned char *data = NULL;
    XGetWindowProperty(source_nest->dpy, source_nest->proxy, prop_atom, 0, MAX_CLIP_BYTES / 4, False,
                       AnyPropertyType, &type_ret, &fmt_ret, &n_items, &bytes_after, &data);
    XDeleteProperty(source_nest->dpy, source_nest->proxy, prop_atom);
    if (!data || n_items == 0) { if (data) XFree(data); goto deny; }

    // Translate the property ‘type’ atom from source → dest
    char *type_name = XGetAtomName(source_nest->dpy, type_ret);
    Atom  dest_type = type_name ? XInternAtom(n->dpy, type_name, False) : type_ret; /* fallback */
    if (type_name) XFree(type_name);
    XChangeProperty(n->dpy, req->requestor, dest_prop, dest_type,
                    fmt_ret, PropModeReplace, data, n_items);
    XFree(data);
    g_clip.t_paste = 0;
    XSelectionEvent se = {0};
    se.type = SelectionNotify;
    se.display = req->display;
    se.requestor = req->requestor;
    se.selection = req->selection;
    se.target = req->target;
    se.property = dest_prop;           // must echo what we actually used
    se.time = req->time;
    XSendEvent(n->dpy, req->requestor, False, 0, (XEvent *)&se);
    XFlush(n->dpy);
    return;
    deny: {                            // On any failure, send a denial notification
        XSelectionEvent se = {0};
        se.type = SelectionNotify;
        se.display = req->display;
        se.requestor = req->requestor;
        se.selection = req->selection;
        se.target = req->target;
        se.property = None;            // Indicate failure
        se.time = req->time;
        XSendEvent(n->dpy, req->requestor, False, 0, (XEvent *)&se);
        XFlush(n->dpy);
        return;
    }
}

static void cleanup_resources(int kq)
{
    // Free heap strings
    for (int i = 0; i < g_clip.n_targets; i++) {
        free(g_clip.targets[i]);
        g_clip.targets[i] = NULL;
    }
    // X11 teardown
    for (int i = 0; i < n_nests; i++) {
        Nest *n = &nests[i];
        if (!n->dpy) continue;
        XSetSelectionOwner(n->dpy, n->atom_clipboard, None, CurrentTime);   // CLIPBOARD release
        if (n->proxy) XDestroyWindow(n->dpy, n->proxy);
        XFlush(n->dpy);          // Destroy proxy window & flush
        XCloseDisplay(n->dpy);   // Close display connection
        n->dpy = NULL;
    }
    if (kq != -1) close(kq);     // close kqueue & fd (kevent closes regs automatically)
#ifdef DEBUG
    if (dlog_fp) { fclose(dlog_fp); dlog_fp = NULL; }
#endif
}

static void process_x_events(Nest *n, XEvent *event)
{
    switch (event->type) {
        case PropertyNotify:                            // Window focus
            if (g_clip.t_copy > 0 && n == &nests[0] && event->xproperty.atom == host_atom_active_win) {
                handle_focus_change();
            }
            break;
        case GenericEvent: {                            // XI2 raw input
            XGenericEventCookie *c = &event->xcookie;
            if (c->extension != host_xi_opcode || !XGetEventData(n->dpy, c)) break;
            XIRawEvent *re = (XIRawEvent *)c->data;
            if (c->evtype == XI_RawKeyPress) {          // Raw Keypress detected
                /* Track modifier state -------------------------------------- */
                if (re->detail == host_ctrl_l_keycode || re->detail == host_ctrl_r_keycode) {
                    ctrl_is_down = 1;
                } else if (re->detail == host_shift_l_keycode || re->detail == host_shift_r_keycode) {
                    shift_is_down = 1;
                /* Ctrl-V ---------------------------------------------------- */
                } else if (re->detail == host_v_keycode && ctrl_is_down && g_clip.t_copy > 0) {
                    if (g_clip.t_paste == 0) {
                        struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);
                        g_clip.t_paste = TIMESPEC_MS(ts);
                    }
                /* Shift-Insert --------------------------------------------- */
                } else if (re->detail == host_insert_keycode && shift_is_down && g_clip.t_copy > 0) {
                    if (g_clip.t_paste == 0) {
                        struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);
                        g_clip.t_paste = TIMESPEC_MS(ts);
                    }
                }
            } else if (c->evtype == XI_RawKeyRelease) {  // Reset after release
                if (re->detail == host_ctrl_l_keycode || re->detail == host_ctrl_r_keycode) {
                    ctrl_is_down = 0;
                } else if (re->detail == host_shift_l_keycode || re->detail == host_shift_r_keycode) {
                    shift_is_down = 0;
                }
            } else if (c->evtype == XI_RawButtonPress) { // Middle-click paste
                if ((int)re->detail == Button2 && g_clip.t_copy > 0) {
                    if (g_clip.t_paste == 0) {
                        struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);
                        g_clip.t_paste = TIMESPEC_MS(ts);
                    }
                }
            }
            XFreeEventData(n->dpy, c);
            break;
        }
        case SelectionRequest:  // Window wants to paste from clipboard owner
            if (g_clip.t_copy > 0 && g_clip.source != NULL) {
                service_selection_request(n, &event->xselectionrequest);
            }
            break;
        default:                // X11 extension for owner change. Not a core-protocol ID, needs xfixes_base
            if (n->xfixes_base && event->type == n->xfixes_base + XFixesSelectionNotify)
                create_new_lease(n, (XFixesSelectionNotifyEvent *)event);
            break;
    }
}

/* ---------------- main ------------------------------------------- */
int main(void)
{
    // Initialize daemon, global state, X11 listeners, and displays
    if (daemon(0, 0) == -1) die("daemonize");
    reset_g_clip(0);
    initialize_host_x_connection();
    initialize_displays();
    if (host_xi_opcode == 0) die("XI2 extension not initialised");
    if (host_v_keycode == 0) die("Failed to resolve 'v' keycode");
    if (nests[0].dpy != host_dpy || nests[0].proxy == 0) die("Host-nest integrity failure");

    signal(SIGTERM, sig_term);
    signal(SIGINT,  sig_term);
    kq_fd = kqueue();                   // Setup kqueue filters for all relevant events
    if (kq_fd == -1) die("kqueue");
    setup_kqueue_filters(kq_fd);

    DLOG("Daemon started: %d displays monitored via kqueue (kq_fd: %d)\n", n_nests, kq_fd);

    // Main event loop for watching/handling events. Runs until quit_flag is set
    while (!quit_flag) {
        struct kevent event_list[MAX_KEVENT_EVENTS];

        // Block until events occur or timeout expires, similar to select()
        int num_events = kevent(kq_fd, NULL, 0, event_list, MAX_KEVENT_EVENTS, &kevent_timeout_ts);
        if (num_events < 0) {
            quit_flag = 1; continue;                         // Signal interrupt or unhandled err
        }
        if (num_events > 0) {
            for (int i = 0; i < num_events; i++) {
                struct kevent *e = &event_list[i];
                switch (e->filter) {
                case EVFILT_SIGNAL:                          // Interrupt
                    quit_flag = 1; break;
                case EVFILT_VNODE:                           // .X11-unix direcotry socket event
                    synchronize_nests_to_sockets(); break;
                case EVFILT_READ: {                          // X11 server events (host & Xephry)
                    Nest *n_event = (Nest *)e->udata;
                    if (!n_event || !n_event->dpy) break;    // No event or nest to operate on
                    XEvent event;
                    while (XPending(n_event->dpy)) {
                        XNextEvent(n_event->dpy, &event);
                        process_x_events(n_event, &event);
                    }
                    break;
                }
                default:
                    break;                                   // Unhandled filter
                }
            }
        }
        reset_g_clip(1);        // Checks lease & resets g_clip if expired
    }
    DLOG("Daemon shutting down\n");
    cleanup_resources(kq_fd);
    return 0;
}

