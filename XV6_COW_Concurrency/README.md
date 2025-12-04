# Advanced XV6 & Concurrency

**Course:** Operating Systems and Networks, IIIT Hyderabad  
**Team:** 73

## Overview

Implementation of Copy-On-Write fork in xv6 and multi-threaded file management/sorting systems.

## Structure
```
├── initial-xv6/src/        # COW fork implementation
├── concurrency/            # Multi-threaded programs
│   ├── lazy_read_write.c   # File manager (25 marks)
│   └── lazy_sort.c         # Distributed sorting (35 marks)
└── Report.pdf              # Performance analysis
```

## Components

### 1. Copy-On-Write Fork (25 marks)
Memory-efficient fork that shares pages until write occurs.

**Run:**
```bash
cd initial-xv6/src && make qemu
# In xv6: lazytest
```

### 2. LAZY File Manager (25 marks)
Real-time concurrent file operation simulator with READ/WRITE/DELETE operations.

**Run:**
```bash
cd concurrency
gcc lazy_read_write.c -pthread -o lazy_rw
./lazy_rw < input.txt
```

### 3. Distributed Sorting (35 marks)
Adaptive sorting: Count Sort (<42 files) or Merge Sort (≥42 files).

**Run:**
```bash
cd concurrency
gcc lazy_sort.c -pthread -o lazy_sort
./lazy_sort < files.txt
```

## Key Features

**COW Fork:**
- Shared page mapping with PTE_COW flag
- Page fault handler for write operations
- Reference counting for physical pages

**File Manager:**
- Concurrent READs, exclusive WRITEs
- DELETE blocks all operations
- User timeout cancellations

**Distributed Sort:**
- Multi-threaded parallel sorting
- Dynamic algorithm selection
- Sorts by Name/ID/Timestamp

## Testing
```bash
# XV6
make qemu
lazytest, cowtest1, cowtest2, cowtest3

# Concurrency
./lazy_rw < test_input.txt
./lazy_sort < files.txt
```

## Modified Files

**Kernel:** `kalloc.c`, `trap.c`, `vm.c`, `riscv.h`  
**User:** `lazytest.c`, `cowtest[1-3].c`

## Dependencies

- QEMU, RISC-V toolchain
- GCC with pthread support

---

**Report:** See `Report.pdf` for implementation details, performance graphs, and COW analysis.
