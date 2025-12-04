# XV6 Scheduling & Networking

**Roll Number:** Vishakha Agrawal
**Course:** Operating Systems and Networks, IIIT Hyderabad

## Overview

Implementation of custom system calls, scheduling algorithms in xv6, and networked applications using TCP/UDP.

## Structure
```
.
├── initial-xv6/
│   └── src/
│       ├── kernel/          # Modified kernel files
│       ├── user/            # User programs
│       └── Report.pdf
└── networks/
    ├── partA/
    │   ├── tcp/             # TCP Tic-Tac-Toe
    │   └── udp/             # UDP Tic-Tac-Toe
    └── partB/
        └── code.c           # Reliable UDP transfer
```

## XV6 Implementation

### System Calls

#### 1. syscount
Tracks system call invocations per process.

**Usage:**
```bash
syscount 32768 grep hello README
```

**Files Modified:**
- `kernel/proc.h` - Added `syscall_counts[]` array
- `kernel/syscall.c` - Increment counters
- `kernel/sysproc.c` - `sys_getSysCount()`

#### 2. sigalarm/sigreturn 
Periodic user-level interrupt handlers.

**Implementation:**
- `sigalarm(interval, handler)` - Set periodic callback
- `sigreturn()` - Restore process state
- Modified `kernel/trap.c` for alarm mechanism

### Scheduling Algorithms

#### Lottery-Based Scheduling (LBS) 
**Features:**
- Random selection proportional to ticket count
- `settickets(int)` system call
- Tie-breaking by arrival time
- Default: 1 ticket per process

**Compile:**
```bash
make clean && make qemu CPUS=2 SCHEDULER=LBS
```

#### Multi-Level Feedback Queue (MLFQ) 

**Design:**
- 4 priority queues (0=highest, 3=lowest)
- Time slices: 1, 4, 8, 16 ticks
- Priority boost every 48 ticks
- Demote on full time slice usage

**Compile:**
```bash
make clean && make qemu CPUS=1 SCHEDULER=MLFQ
```

### Performance Comparison

| Scheduler | Avg Runtime | Avg Wait Time |
|-----------|-------------|---------------|
| Round Robin | 11-12 ticks | 110 ticks |
| MLFQ | 12-15 ticks | 144-159 ticks |
| LBS | 14-15 ticks | 103 ticks |

## Networking

### Part A: Tic-Tac-Toe 

Multiplayer game with TCP and UDP implementations.

**Features:**
- Server manages 3×3 board
- 2 clients play simultaneously
- Win/draw detection
- Replay functionality

**TCP:**
```bash
cd networks/partA/tcp
./server          # Terminal 1
./client          # Terminal 2
./client          # Terminal 3
```

**UDP:**
```bash
cd networks/partA/udp
./server
./client
./client
```

### Part B: Reliable UDP 

TCP-like reliability over UDP with chunking and ACKs.

**Features:**
- 5-byte chunks with sequence numbers
- ACK packets for each chunk
- 0.1s timeout with retransmission
- Max 10 retransmissions

**Usage:**
```bash
cd networks/partB
./a.out 127.0.0.1 5000 5002    # Terminal 1
./a.out 127.0.0.1 5002 5000    # Terminal 2
```

## Quick Start

### XV6
```bash
cd initial-xv6/src
make qemu                              # Default RR
make clean && make qemu SCHEDULER=LBS  # Lottery
make clean && make qemu SCHEDULER=MLFQ # MLFQ
```

**Exit:** `Ctrl+A` then `X`

### Testing
```bash
# In xv6 shell
syscount 32768 grep hello README
alarmtest
schedulertest
mlfq
lbs
```

## Key Files

**XV6:**
- `kernel/proc.h` - Process structure modifications
- `kernel/proc.c` - Scheduler implementations
- `kernel/syscall.c` - System call handlers
- `kernel/trap.c` - Alarm mechanism
- `user/syscount.c`, `user/alarmtest.c`

**Networks:**
- `partA/tcp/{server,client}.c`
- `partA/udp/{server,client}.c`
- `partB/code.c`

## Implementation Highlights

**LBS:**
- Random lottery with ticket proportionality
- Arrival time tie-breaking
- Child inherits parent tickets

**MLFQ:**
- 4-level priority queues
- Dynamic priority adjustment
- Anti-starvation boost mechanism

**UDP Reliability:**
- Stop-and-wait ARQ protocol
- Non-blocking socket operations
- Simulated packet loss testing

## Report

See `initial-xv6/src/Report.pdf` for detailed implementation and MLFQ graphs.
