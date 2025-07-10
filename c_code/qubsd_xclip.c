/*
 * qubsd_xclip - A clipboard broker for quBSD
 *
 * This program facilitates secure, just-in-time clipboard transfers between
 * different X displays, primarily between Xephyr sessions and/or to/from host.
 * It operates via a single, short-lived background process, on just the host.
 *
 * Written for quBSD Xephyr X11 segregation, but could be used in other contexts.
 *
 * Compilation:
 *   clang -Wall -Wextra -Werror -std=c11 -pedantic -I/usr/local/include /home/disp1/qubsd_xclip.c -o qubsd_xclip -L/usr/local/lib -lX11 -lXext
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <signal.h>
#include <errno.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/Xutil.h>

// --- Debug Setup ---
#ifdef DEBUG
  #define DLOG(...) fprintf(stderr, __VA_ARGS__)
#else
  #define DLOG(...) ((void)0)
#endif

// --- Configuration ---
#define TIME_TO_LIVE 10
#define MAX_TARGETS 128
#define MAX_COMMAND_LEN 512
#define MAX_DISPLAY_LEN 64
#define LOCK_FILE_TEMPLATE "/tmp/qubsd_xclip.lock.%d"
#define FIFO_TEMPLATE "/tmp/qubsd_xclip_fifo.%d"

// --- State Structure ---
typedef struct {
    Display *source_dpy;
    Display *dest_dpy;
    Window broker_window;
    char *source_display;
    char *destin_display;
    time_t last_activity_time;

    // New: Store target names as strings from the source
    char *target_names[MAX_TARGETS];
    // This now stores atoms valid for the DESTINATION display
    Atom targets[MAX_TARGETS];

    int num_targets;
    char lock_file_path[256];
    char fifo_path[256];
    int fifo_fd;
} BrokerState;

// Global pointer for signal handler cleanup
static BrokerState *g_state = NULL;
// Global flag for safe signal handling
static volatile sig_atomic_t g_terminate_flag = 0;

// Declare global Atom variables (or pass them around as needed)
Atom atom_clipboard;
Atom atom_targets;

// --- Function Prototypes ---
void run_copy_mode(void);
void run_paste_mode(void);
void handle_existing_process(const char *lock_file);
void daemonize(void);
char* detect_host_display(void);
char* get_active_window_display(Display *dpy);
void fetch_source_targets(BrokerState *state);
void arm_for_paste(BrokerState *state);
void handle_selection_request(BrokerState *state, XSelectionRequestEvent *req);
void main_event_loop(BrokerState *state);
void cleanup_and_exit(int signum);
void safe_signal_handler(int);

// --- Main Function ---
int main(int argc, char *argv[]) {
    if (argc != 2) {
        DLOG("Usage: %s copy | paste\n", argv[0]);
        return 1;
    }
    if (strcmp(argv[1], "copy") == 0) {
        run_copy_mode();
    } else if (strcmp(argv[1], "paste") == 0) {
        run_paste_mode();
    } else {
        DLOG("Usage: %s copy | paste\n", argv[0]);
        return 1;
    }
    return 0;
}

// --- Implementation ---
void run_paste_mode(void) {
    char fifo_path[256];
    snprintf(fifo_path, sizeof(fifo_path), FIFO_TEMPLATE, getuid());

    int fifo_fd = open(fifo_path, O_WRONLY | O_NONBLOCK);
    if (fifo_fd == -1) {
        if (errno != ENXIO && errno != ENOENT) {
            perror("Error opening FIFO");
        }
        // Fail silently if daemon isn't running.
        return;
    }

    write(fifo_fd, "PASTE", 6); // Write "PASTE" with null terminator
    close(fifo_fd);
}

void run_copy_mode(void) {
    // These paths are needed for both setup and cleanup.
    char lock_file_path[256];
    char fifo_path[256];
    snprintf(lock_file_path, sizeof(lock_file_path), LOCK_FILE_TEMPLATE, getuid());
    snprintf(fifo_path, sizeof(fifo_path), FIFO_TEMPLATE, getuid());

    handle_existing_process(lock_file_path);

    daemonize();

    // From here on, we are the background process.
    // Create the lock file.
    FILE *lock_fp = fopen(lock_file_path, "w");
    if (lock_fp) {
        fprintf(lock_fp, "%d", getpid());
        fclose(lock_fp);
    }

    DLOG("DEBUG: Daemon started (PID: %d)\n", getpid());

    BrokerState state = {0};
    g_state = &state; // Set global pointer

    // CRITICAL FIX: Populate the state struct with the paths for cleanup.
    strncpy(state.lock_file_path, lock_file_path, sizeof(state.lock_file_path) - 1);
    strncpy(state.fifo_path, fifo_path, sizeof(state.fifo_path) - 1);

    // CRITICAL FIX: Set the SAFE signal handlers and REMOVE the unsafe ones.
    signal(SIGTERM, safe_signal_handler);
    signal(SIGINT, safe_signal_handler);

    char *host_display = detect_host_display();
    if (!host_display) {
        cleanup_and_exit(1);
    }

    Display *temp_dpy = XOpenDisplay(host_display);
    if (!temp_dpy) {
        DLOG("Error: Could not open host display '%s'\n", host_display);
        free(host_display);
        cleanup_and_exit(1);
    }

    state.source_display = get_active_window_display(temp_dpy);
    XCloseDisplay(temp_dpy);
    free(host_display);

    if (!state.source_display) {
        DLOG("Error: Failed to determine source display.\n");
        cleanup_and_exit(1);
    }

    state.source_dpy = XOpenDisplay(state.source_display);
    if (!state.source_dpy) {
        DLOG("Error: Could not open source display '%s'\n", state.source_display);
        cleanup_and_exit(1);
    }

    fetch_source_targets(&state);
    if (state.num_targets == 0) {
        DLOG("Error: Could not fetch any clipboard targets from source '%s'.\n", state.source_display);
        cleanup_and_exit(1);
    }

    DLOG("DEBUG: Source display detected: '%s'. Targets fetched: %d.\n",
        state.source_display, state.num_targets);

    // Setup FIFO
    unlink(state.fifo_path); // Remove old FIFO if it exists
    if (mkfifo(state.fifo_path, 0600) == -1) {
        perror("mkfifo failed");
        cleanup_and_exit(1);
    }

    state.fifo_fd = open(state.fifo_path, O_RDONLY | O_NONBLOCK);
    if (state.fifo_fd == -1) {
        perror("open FIFO for reading failed");
        cleanup_and_exit(1);
    }

    main_event_loop(&state);

    // This is now the single point of exit. It runs after the main loop
    // breaks due to TTL, signal, or error.
    cleanup_and_exit(0);
}

void safe_signal_handler(int signum) {
    (void)signum; // Unused parameter
    g_terminate_flag = 1;
}

void cleanup_and_exit(int signum) {
    if (g_state) {
        if (g_state->dest_dpy) {
            XSetSelectionOwner(g_state->dest_dpy, atom_clipboard, None, CurrentTime);
            if (g_state->broker_window) XDestroyWindow(g_state->dest_dpy, g_state->broker_window);
            XCloseDisplay(g_state->dest_dpy);
        }
        if (g_state->source_dpy) XCloseDisplay(g_state->source_dpy);
        if (g_state->fifo_fd > 0) close(g_state->fifo_fd);
        unlink(g_state->fifo_path);
        unlink(g_state->lock_file_path);
        free(g_state->source_display);
        free(g_state->destin_display);
    }
    exit(signum > 0 ? signum : 0);
}

void handle_existing_process(const char *lock_file) {
    FILE *fp = fopen(lock_file, "r");
    if (fp) {
        pid_t old_pid;
        if (fscanf(fp, "%d", &old_pid) == 1) {
            kill(old_pid, SIGTERM);
            // Give it a moment to die and clean up
            usleep(100000); 
        }
        fclose(fp);
    }
}

void daemonize(void) {
    pid_t pid = fork();
    if (pid < 0) {
        exit(EXIT_FAILURE);
    }
    if (pid > 0) {
        exit(EXIT_SUCCESS); // Parent exits successfully.
    }

    // Child becomes session leader
    if (setsid() < 0) {
        exit(EXIT_FAILURE);
    }

    // Ignore SIGHUP signal
    signal(SIGHUP, SIG_IGN);

    // Fork again to ensure the daemon cannot reacquire a terminal
    pid = fork();
    if (pid < 0) {
        exit(EXIT_FAILURE);
    }
    if (pid > 0) {
        exit(EXIT_SUCCESS);
    }

    // Change the current working directory to the root directory
    chdir("/");

    // Close stdin, and redirect stdout/stderr to our log file for debugging.
    // This is the safe way to detach from the terminal.
    close(STDIN_FILENO);

    #ifdef DEBUG
      FILE *log_fp = freopen("/tmp/qubsd_xclip.log", "a", stdout);
      if (!log_fp) {
          freopen("/dev/null", "w", stdout); // Fallback if log fails
      }
      freopen("/tmp/qubsd_xclip.log", "a", stderr);
      setbuf(stdout, NULL);
      setbuf(stderr, NULL);
    #else
      freopen("/dev/null", "w", stdout);
      freopen("/dev/null", "w", stderr);
    #endif
}

char* detect_host_display(void) {
    char *display = getenv("DISPLAY");
    if (display && strlen(display) > 0) {
        return strdup(display);
    }

    char command[] = "ps -ax -o command | grep 'Xorg.*:[:digit:]' | head -n 1";
    FILE *pipe = popen(command, "r");
    if (!pipe) return NULL;

    char line[256];
    if (fgets(line, sizeof(line), pipe)) {
        char *display_start = strrchr(line, ':');
        if (display_start) {
            char *display_end = strchr(display_start, ' ');
            if (display_end) *display_end = '\0';
            pclose(pipe);
            return strdup(display_start);
        }
    }
    pclose(pipe);
    DLOG("Warning: Could not detect host display, falling back to ':0'\n");
    return strdup(":0");
}

char* get_active_window_display(Display *dpy) {
    Window active_window_id = None;
    Atom net_active_window_atom = XInternAtom(dpy, "_NET_ACTIVE_WINDOW", False);
    Atom actual_type;
    int actual_format;
    unsigned long nitems, bytes_after;
    unsigned char *prop_data = NULL;

    if (XGetWindowProperty(dpy, DefaultRootWindow(dpy), net_active_window_atom, 0, 1, False, XA_WINDOW,
                &actual_type, &actual_format, &nitems, &bytes_after, &prop_data) == Success && nitems > 0) {
        active_window_id = *((Window *)prop_data);
        XFree(prop_data);
    } else {
        DLOG("Fatal: Could not determine active window.\n");
        return NULL;
    }

    if (active_window_id == 0 || active_window_id == DefaultRootWindow(dpy)) {
        return strdup(DisplayString(dpy));
    }

    XTextProperty wm_name_prop;
    if (XGetWMName(dpy, active_window_id, &wm_name_prop) && wm_name_prop.value) {
        char *wm_name = (char *)wm_name_prop.value;
        char *xephyr_prefix = strstr(wm_name, "Xephyr on :");
        if (xephyr_prefix) {
            char *display_start = xephyr_prefix + strlen("Xephyr on ");
            char *display_end = strchr(display_start, ' ');
            if (display_end) {
                char *result = malloc(display_end - display_start + 1);
                strncpy(result, display_start, display_end - display_start);
                result[display_end - display_start] = '\0';
                XFree(wm_name_prop.value);
                return result;
            }
        }
        XFree(wm_name_prop.value);
    }

    return strdup(DisplayString(dpy));
}

void fetch_source_targets(BrokerState *state) {
    int pipe_fds[2];
    if (pipe(pipe_fds) == -1) {
        perror("pipe failed");
        return;
    }

    pid_t pid = fork();
    if (pid == -1) {
        perror("fork failed");
        close(pipe_fds[0]);
        close(pipe_fds[1]);
        return;
    }

    if (pid == 0) { // Child process
        close(pipe_fds[0]);
        dup2(pipe_fds[1], STDOUT_FILENO);
        close(pipe_fds[1]);

        #ifdef DEBUG
          FILE *log_fp = freopen("/tmp/qubsd_xclip.log", "a", stderr);
          if (log_fp) setbuf(stderr, NULL);
        #endif

        DLOG("DEBUG CHILD (fetch_targets): Child process attempting execvp. CMD: xclip "
                "-display %s -o -selection clipboard -t TARGETS\n", state->source_display);

        char *argv[] = {
            "xclip",
            "-display", state->source_display,
            "-o",
            "-selection", "clipboard",
            "-t", "TARGETS",
            NULL
        };
        execvp("xclip", argv);
        perror("execvp for xclip TARGETS failed");
        exit(127);
    } else { // Parent process
        close(pipe_fds[1]);

        FILE *stream = fdopen(pipe_fds[0], "r");
        if (stream) {
            char line[256];
            state->num_targets = 0;
            while (fgets(line, sizeof(line), stream) != NULL && state->num_targets < MAX_TARGETS) {
                line[strcspn(line, "\n")] = 0;
                if (strlen(line) > 0) {
                    // Store the string name, NOT the atom
                    state->target_names[state->num_targets++] = strdup(line);
                }
            }
            fclose(stream);
        }

        int status;
        waitpid(pid, &status, 0);
        DLOG("DEBUG PARENT (fetch_targets): xclip child for TARGETS exited with status %d.\n",
                WEXITSTATUS(status));
        close(pipe_fds[0]);
    }
}

void arm_for_paste(BrokerState *state) {
    DLOG("DEBUG: arm_for_paste called (from FIFO). Attempting to take ownership on new destin_display.\n");

    free(state->destin_display);
    if(state->dest_dpy) {
        XSetSelectionOwner(state->dest_dpy, atom_clipboard, None, CurrentTime);
        if (state->broker_window) XDestroyWindow(state->dest_dpy, state->broker_window);
        XCloseDisplay(state->dest_dpy);
        state->dest_dpy = NULL;
        state->broker_window = 0;
    }

    char *host_display = detect_host_display();
    if (!host_display) return;

    Display *temp_dpy = XOpenDisplay(host_display);
    if (!temp_dpy) { free(host_display); return; }

    state->destin_display = get_active_window_display(temp_dpy);
    XCloseDisplay(temp_dpy);
    free(host_display);

    if (!state->destin_display) return;

    if (strcmp(state->source_display, state->destin_display) == 0) {
        DLOG("INFO: arm_for_paste: Source '%s' and destination '%s' are same, doing nothing.\n",
                state->source_display, state->destin_display);
        return;
    }

    state->dest_dpy = XOpenDisplay(state->destin_display);
    if (!state->dest_dpy) return;

    // --- NEW LOGIC: Intern atoms on the destination display ---
    atom_clipboard = XInternAtom(state->dest_dpy, "CLIPBOARD", False);
    atom_targets = XInternAtom(state->dest_dpy, "TARGETS", False);

    for (int i = 0; i < state->num_targets; i++) {
        state->targets[i] = XInternAtom(state->dest_dpy, state->target_names[i], False);
    }
    // --- END NEW LOGIC ---

    state->broker_window = XCreateSimpleWindow(state->dest_dpy,
            DefaultRootWindow(state->dest_dpy), 0, 0, 1, 1, 0, 0, 0);
    XSetSelectionOwner(state->dest_dpy, atom_clipboard, state->broker_window, CurrentTime);

    // This diagnostic now has a valid dest_dpy to check against
    DLOG("DEBUG: Ownership on destin_display '%s' acquired: %s.\n", state->destin_display,
        (XGetSelectionOwner(state->dest_dpy, atom_clipboard) == state->broker_window) ? "YES" : "NO");

    if (XGetSelectionOwner(state->dest_dpy, atom_clipboard) != state->broker_window) {
        XCloseDisplay(state->dest_dpy);
        state->dest_dpy = NULL;
    }
}

void main_event_loop(BrokerState *state) {
    state->last_activity_time = time(NULL);

    // The loop condition now directly and safely checks the termination flag.
    while (!g_terminate_flag) {
        time_t current_time = time(NULL);
        if (current_time - state->last_activity_time >= TIME_TO_LIVE) {
            DLOG("DEBUG: TTL expired. Exiting.\n");
            break; // Exit the loop to trigger cleanup
        }

        fd_set fds;
        FD_ZERO(&fds);
        FD_SET(state->fifo_fd, &fds);
        int max_fd = state->fifo_fd;
        int x11_fd = -1;

        if (state->dest_dpy) {
            x11_fd = ConnectionNumber(state->dest_dpy);
            FD_SET(x11_fd, &fds);
            if(x11_fd > max_fd) max_fd = x11_fd;
        }

        struct timeval tv;
        tv.tv_sec = 1; // Short timeout to ensure the g_terminate_flag is checked regularly
        tv.tv_usec = 0;

        int ret = select(max_fd + 1, &fds, NULL, NULL, &tv);

        if (ret < 0) {
            // If select() was interrupted by our signal, just continue.
            // The loop condition (!g_terminate_flag) will handle the exit.
            if (errno == EINTR) {
                continue;
            }
            perror("select failed");
            break; // Exit on other select errors
        }

        // Handle X11 events if the destination display is active and has data
        if (state->dest_dpy && FD_ISSET(x11_fd, &fds)) {
            XEvent event;
            // Process all pending events from the X server
            while (XPending(state->dest_dpy)) {
                XNextEvent(state->dest_dpy, &event);
                if (event.type == SelectionRequest) {
                    handle_selection_request(state, &event.xselectionrequest);
                } else if (event.type == SelectionClear) {
                    DLOG("DEBUG: SelectionClear received. Exiting gracefully.\n");
                    g_terminate_flag = 1;   // Critical SAFE part: just set the flag.
                    break;        // Break from the inner loop. Outer loop will handle exit.
                }
            }
        }

        // Handle FIFO commands if there is data
        if (FD_ISSET(state->fifo_fd, &fds)) {
            char buffer[16];
            if (read(state->fifo_fd, buffer, sizeof(buffer) - 1) > 0) {
                if(strncmp(buffer, "PASTE", 5) == 0) {
                    arm_for_paste(state);
                    state->last_activity_time = time(NULL); // Reset timer
                }
            }
        }
    }
}

void handle_selection_request(BrokerState *state, XSelectionRequestEvent *req) {
    state->last_activity_time = time(NULL);

    // Diagnostic must be done carefully as XGetAtomName can be slow or return NULL
    char *debug_target_name = XGetAtomName(state->dest_dpy, req->target);
    DLOG("DEBUG: SelectionRequest received for target '%s' (Atom ID: %lu).\n",
            debug_target_name ? debug_target_name : "UNKNOWN", (unsigned long)req->target);
    if (debug_target_name) XFree(debug_target_name);

    XSelectionEvent notify_event = {0};
    notify_event.type = SelectionNotify;
    notify_event.display = req->display;
    notify_event.requestor = req->requestor;
    notify_event.selection = req->selection;
    notify_event.time = req->time;
    notify_event.target = req->target;
    notify_event.property = None;

    if (req->target == atom_targets) {
        DLOG("DEBUG: handle_selection_request: Responding to TARGETS request with %d targets.\n",
                state->num_targets);
        XChangeProperty(state->dest_dpy, req->requestor, req->property, XA_ATOM, 32,
                PropModeReplace, (unsigned char *)state->targets, state->num_targets);
        notify_event.property = req->property;
        XSendEvent(state->dest_dpy, req->requestor, True, NoEventMask, (XEvent *)&notify_event);
        return;
    }

    // --- NEW LOGIC: Find the string name corresponding to the requested destination atom ---
    char *target_name = NULL;
    for (int i = 0; i < state->num_targets; i++) {
        if (state->targets[i] == req->target) {
            target_name = state->target_names[i];
            break;
        }
    }
    // --- END NEW LOGIC ---

    if (target_name) {
        char tmp_file_path[] = "/tmp/qubsd_xclip_data_XXXXXX";
        int tmp_fd = mkstemp(tmp_file_path);
        if (tmp_fd != -1) {
            pid_t pid = fork();
            if (pid == -1) {
                perror("fork failed");
                close(tmp_fd);
                unlink(tmp_file_path);
            } else if (pid == 0) { // Child process
                dup2(tmp_fd, STDOUT_FILENO);
                close(tmp_fd);
                #ifdef DEBUG
                  FILE *log_fp = freopen("/tmp/qubsd_xclip.log", "a", stderr);
                  if (log_fp) setbuf(stderr, NULL);
                #endif
                DLOG("DEBUG CHILD (selection_request): ...\n");

                char *argv[] = {"xclip", "-display", state->source_display, "-o", "-selection",
                    "clipboard", "-t", target_name, NULL};
                execvp("xclip", argv);
                perror("execvp for xclip data failed");
                exit(127);
            } else { // Parent process
                close(tmp_fd);
                int status;
                waitpid(pid, &status, 0);

                if (WIFEXITED(status) && WEXITSTATUS(status) == 0) {
                    FILE *fp = fopen(tmp_file_path, "rb");
                    if (fp) {
                        fseek(fp, 0, SEEK_END);
                        long size = ftell(fp);
                        fseek(fp, 0, SEEK_SET);
                        if (size > 0) {
                            unsigned char *buffer = malloc(size);
                            if (buffer) {
                                if (fread(buffer, 1, size, fp) == (size_t)size) {
                                    XChangeProperty(state->dest_dpy, req->requestor, req->property,
                                        req->target, 8, PropModeReplace, buffer, size);
                                    notify_event.property = req->property;
                                }
                                free(buffer);
                            }
                        }
                        fclose(fp);
                    }
                }

                DLOG("DEBUG: xclip child for '%s' exited with status %d. Data transfer to property %s.\n",
                        target_name, WEXITSTATUS(status),
                        (WIFEXITED(status) && WEXITSTATUS(status) == 0 && notify_event.property != None) ?
                        "succeeded" : "FAILED");
            }
            unlink(tmp_file_path);
        }
    }

    XSendEvent(state->dest_dpy, req->requestor, True, NoEventMask, (XEvent *)&notify_event);
}
