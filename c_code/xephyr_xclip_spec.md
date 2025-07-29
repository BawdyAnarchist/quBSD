### Architectural Overview: The Persistent Clipboard Broker

The `xephyr_xclip` is a persistent background daemon. Its facilitates secure, just-in-time clipboard sharing between a host X11 session and one or more isolated, nested Xephyr sessions for FreeBSD jails. The architecture is event-driven, and providing a seamless user experience without compromising isolation.

#### Core Components and State

1. **The Daemon Process:** A single, long-running background process. It starts once and manages all clipboard brokering until it is explicitly terminated.

2. **Display Monitoring:** On startup, the daemon will:

    - Detect the primary host display (e.g., `:0`).

    - Scan `/tmp/.X11-unix/` to discover all active X server sockets and establish a connection to each one.

    - Set event notification on this directory to dynamically connect to newly created Xephyr sessions and disconnect from terminated ones.

    - Listen on each display for selection notify events.

    <!-- -->

3. **Centralized State:** The daemon will maintain an in-memory state that includes:

    - A list of all currently monitored displays, and the daemon's relationship to them.

    - Metadata for the most recent `ctrl+c` copy action, including its display number, and a list of available formats (TARGETS).

    - A "Time-To-Live" (TTL) timer, acting as a 10-second lease on clipboard metadata.

    - Crucially - The clipboard data is not cached, and remains on the source display until an actual user paste `ctrl+v` is performed.

    <!-- -->


<!-- -->

#### Event-Driven Workflow

The daemon operates on a main event loop driven by `kevent()`, waiting for activity on multiple sources without busy-waiting or polling.

**1\. The "Copy" Action: Automatic Data Acquisition**

- **Trigger:** When the user performs a copy action (e.g., `Ctrl+C` or "Edit -> Copy") within any application on any monitored display.

- **Mechanism:** The daemon uses the **XFixes extension** to subscribe to clipboard ownership changes on every display. A copy action generates an `XFixesSelectionNotify` event.

- **Daemon's Response:**

    1. Upon receiving the notification, the daemon verifies it was not self-generated.

    2. It immediately connects to the source display to fetch the source's available data formats (the `TARGETS` list).

    3. The 10-second TTL "lease" for this data begins, enforced by the same function that resets g_clip

    <!-- -->

<!-- -->

**2\. The "Focus Change" Action: Real-Time Ownership Transfer**

- **Trigger:** When the user moves keyboard focus from a window on one display to a window on another (e.g., from a host terminal to a Xephyr window).

- **Mechanism:** The daemon monitors the `_NET_ACTIVE_WINDOW` property on the **host display's root window**. A focus change triggers a `PropertyNotify` event.

- **Daemon's Response:**

    1. The daemon identifies which display has just gained focus.

    2. If the daemon is holding clipboard metadata (i.e., the 10-second lease is active), it will:

        - **Instantly claim ownership** of the clipboard on the newly focused display.

        - **Simultaneously relinquish ownership** on any other display where it might have previously been the owner.

        <!-- -->

    3. This ensures that the clipboard "follows" the user's focus seamlessly and is only ever "armed for paste" on the single, active display.

    <!-- -->

<!-- -->

**3\. The "Paste" Action: Secure, Validated Data Delivery**

- **Trigger:** When the user initiates a paste action (e.g., `Ctrl+V`) in the focused application.

- **Mechanism:** The application sends a standard `SelectionRequest` to the current clipboard owner, which is now our daemon. Concurrently, the daemon uses **raw XI2** to listen for an X11 ctrl+v event **on host display only**.

- **Daemon's Response (Security Gate):**

    1. Before responding to the `SelectionRequest`, the daemon performs a series of rapid, mandatory checks:

        - **Host-Side Input Verification:** Did `Ctrl+V` raw XI2 event occur on the *host* X server within the last 50 milliseconds? This proves the action was initiated by the host keyboard not a forged event from within a jail.

        - **Focus Verification:** Does the window making the request match the current window focused? 

        - \*Note: Primary security occurs via detection of ctrl+v raw XI2 event on the host display. Timing heuristics are a secondary mechanism. Thus, 50ms is sufficient time for oddball programs that lag the event registration to a `SelectionRequest`.\*

        <!-- -->

    2. **Outcome:**

        - If **both checks pass**, the daemon will fetch the actual clipboard data from the source, write to the tmp file, and forward from the tmp to the destination (your existing code logic still holds).

        - If **either check fails**, the daemon denies the request by replying with an empty property, effectively preventing the paste. This is the primary defense against malicious, unsolicited data requests.

        <!-- -->

    <!-- -->


<!-- -->

#### Data Security and Cleanup

- **Time-To-Live (TTL) Expiration:** If 10 seconds pass after a copy action without a successful paste, the daemon's lease expires. It will then:

    1. Proactively wipe the source display number and `TARGETS` list from its in-memory metadata

    2. Explicitly relinquish clipboard ownership on any display it currently owns.

    <!-- -->

- **Isolation by Design:** The architecture ensures that an unfocused jail's X session is never made aware that new clipboard data is available. The combination of focus-tracking and host-side key press validation prevents a malicious (but focused) jail from stealing clipboard data without a legitimate, user-initiated paste action. The system is designed to be safe against both passive snooping and active, forged requests.

#### BREAK FOR LLM INSTRUCTIONS

This is the project overview. We will ALWAYS discuss spec/design FIRST. You will NEVER spit out dozens or hundreds of lines of code on your own. You will only produce code if EXPLICITLY requested. You will only produce code inside of major code blocks with triple backticks. Maintain my comments, stylism, spacing. Minimal non-verbose comments. Whenever isolated lines of code are requested, use rev-tracking style inside of a code block. For example:
```
unchanged line1
unchanged line2
- remove
+ add
```

ACK this and I will provide the code. 

YOU ARE NEVER to reproduce the entirety of this code or a whole function, without an EXPLICIT request.

