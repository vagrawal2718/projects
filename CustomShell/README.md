# My Custom Shell

A custom shell built in C that mimics some functionality of standard UNIX shells, with several custom commands and features.

---

## Implemented Features

This checklist tracks the implementation status of each feature specification.

- [x] **Spec 1 & 2:** Core Shell Loop & Helpers (`shell.c`, `helper.c`)
- [x] **Spec 3:** `hop` - Directory navigation utility (`hop.c`)
- [x] **Spec 4:** `reveal` - `ls` alternative (`reveal.c`)
- [x] **Spec 5:** `log` - Command history manager (`log.c`)
- [x] **Spec 6:** System Command Execution (`sys_command.c`)
- [x] **Spec 7:** `proclore` - Process information display (`proclore.c`)
- [x] **Spec 8:** `seek` - File and directory search utility (`seek.c`)
- [x] **Spec 10:** I/O Redirection (`io_redirection.c`)
- [x] **Spec 11 & 12:** Pipes (`pipe.c`)
- [x] **Spec 13:** `activities` - Background process monitor (`activities.c`)
- [x] **Spec 14:** Signal Handling (`signals.c`)
- [x] **Spec 15:** Basic Foreground/Background Job Control (`fg_bg.c`)
- [x] **Spec 17:** `iMan` - Man page viewer using HTTP requests (`iMan.c`)
- [ ] **Spec 9:** Startup Script (`myshrc`) - *Not functional*
- [ ] **Spec 16:** *Skipped*

---

## Usage Examples

Below are some of the working commands that have been tested.

### Basic Operations
- Run commands in the background: `gedit &`
- Execute multiple commands sequentially: `sleep 5 & ; echo "Lorem Ipsum"`
- Handle invalid commands: `sleeeep 6`
- Execute system commands with foreground and background support: `ping google.com`, `gedit &`

### Custom Commands
- **`hop`**: `hop test`, `hop ~`, `hop ../tutorial`
- **`reveal`**: `reveal -al`, `reveal -a`, `reveal -l`, `reveal -lala`, `reveal -l -a`
- **`log`**: `log`, `log execute 3`, `log purge`
- **`proclore`**: `proclore`, `proclore <pid>`
- **`seek`**: `seek -f log.h`, `seek -ef log.h`, `seek -de test`, `seek -d assignment`
- **`activities`**: `activities`
- **`iMan`**: `iMan sleep`, `iMan wc`

### I/O Redirection and Pipes
- Output redirection: `echo "Hello world" > a.txt`
- Input redirection: `wc < a.txt`
- Input and output redirection: `wc < b.txt > a.txt`
- Piping commands: `echo "Lorem Ipsum" | wc`
- Piping with redirection: `echo "Hello World" | wc > c.txt`

### Signal Handling
- Works for some cases, e.g., running `emacs` and using `Ctrl-C` or `Ctrl-D`.
- Send signals to background jobs: Start `gedit &` and then use `kill -9 <pid>` or `kill -19 <pid>`.

---

## Assumptions

1.  In the `seek` command, all searches are performed relative to the home directory (`~`).
2.  Processes that are **stopped** (e.g., via `Ctrl-Z` or signal 19) are not kicked out of the background process list shown by `activities`.
3.  The man page content fetched by `iMan` is presented as-is from the HTTP GET request.

---

## Known Issues

- The `fg` and `bg` commands for job control are inconsistent and do not work reliably.
- The startup script `myshrc` is not functional.
- I/O redirection with the system `cat` command does not work as expected.

---

## Acknowledgements

Parts of this code were developed with assistance and conceptual understanding provided by AI tools, including ChatGPT and Google Gemini.
