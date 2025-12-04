
user/_cowtest2:     file format elf64-littleriscv


Disassembly of section .text:

0000000000000000 <readonly_test>:
        // Parent process: wait for the child to complete
        wait((int *)0);
    }
}*/

void readonly_test() {
   0:	715d                	addi	sp,sp,-80
   2:	e486                	sd	ra,72(sp)
   4:	e0a2                	sd	s0,64(sp)
   6:	fc26                	sd	s1,56(sp)
   8:	f84a                	sd	s2,48(sp)
   a:	0880                	addi	s0,sp,80
    printf("Running Read-Only Test\n");
   c:	00001517          	auipc	a0,0x1
  10:	b9450513          	addi	a0,a0,-1132 # ba0 <malloc+0x104>
  14:	00001097          	auipc	ra,0x1
  18:	9d0080e7          	jalr	-1584(ra) # 9e4 <printf>
  1c:	44a9                	li	s1,10

    // Allocate and initialize all pages in the parent
    for (int i = 0; i < NUM_PAGES; i++) {
        char *mem = sbrk(PGSIZE);
        if (mem == (char *)-1) {
  1e:	597d                	li	s2,-1
        char *mem = sbrk(PGSIZE);
  20:	6505                	lui	a0,0x1
  22:	00000097          	auipc	ra,0x0
  26:	6c2080e7          	jalr	1730(ra) # 6e4 <sbrk>
        if (mem == (char *)-1) {
  2a:	03250963          	beq	a0,s2,5c <readonly_test+0x5c>
            printf("sbrk failed\n");
            return;
        }
        mem[0] = 0; // Initialize memory to ensure it's fully mapped
  2e:	00050023          	sb	zero,0(a0) # 1000 <freep>
    for (int i = 0; i < NUM_PAGES; i++) {
  32:	34fd                	addiw	s1,s1,-1
  34:	f4f5                	bnez	s1,20 <readonly_test+0x20>
    }

    int pid = fork();
  36:	00000097          	auipc	ra,0x0
  3a:	61e080e7          	jalr	1566(ra) # 654 <fork>
  3e:	84aa                	mv	s1,a0
    if (pid < 0) {
  40:	02054763          	bltz	a0,6e <readonly_test+0x6e>
        printf("Fork failed\n");
        return;
    } else if (pid == 0) {
  44:	cd15                	beqz	a0,80 <readonly_test+0x80>
            volatile char value = mem[0]; // Read the memory to ensure no COW is triggered
            printf("Child read value from page %d: %d\n", i, value);
        }
        exit(0);
    } else {
        wait((int *)0); // Parent process waits for child completion
  46:	4501                	li	a0,0
  48:	00000097          	auipc	ra,0x0
  4c:	61c080e7          	jalr	1564(ra) # 664 <wait>
    }
}
  50:	60a6                	ld	ra,72(sp)
  52:	6406                	ld	s0,64(sp)
  54:	74e2                	ld	s1,56(sp)
  56:	7942                	ld	s2,48(sp)
  58:	6161                	addi	sp,sp,80
  5a:	8082                	ret
            printf("sbrk failed\n");
  5c:	00001517          	auipc	a0,0x1
  60:	b5c50513          	addi	a0,a0,-1188 # bb8 <malloc+0x11c>
  64:	00001097          	auipc	ra,0x1
  68:	980080e7          	jalr	-1664(ra) # 9e4 <printf>
            return;
  6c:	b7d5                	j	50 <readonly_test+0x50>
        printf("Fork failed\n");
  6e:	00001517          	auipc	a0,0x1
  72:	b6250513          	addi	a0,a0,-1182 # bd0 <malloc+0x134>
  76:	00001097          	auipc	ra,0x1
  7a:	96e080e7          	jalr	-1682(ra) # 9e4 <printf>
        return;
  7e:	bfc9                	j	50 <readonly_test+0x50>
  80:	f44e                	sd	s3,40(sp)
  82:	f052                	sd	s4,32(sp)
  84:	ec56                	sd	s5,24(sp)
  86:	6929                	lui	s2,0xa
            printf("Child read value from page %d: %d\n", i, value);
  88:	00001a97          	auipc	s5,0x1
  8c:	b58a8a93          	addi	s5,s5,-1192 # be0 <malloc+0x144>
        for (int i = 0; i < NUM_PAGES; i++) {
  90:	7a7d                	lui	s4,0xfffff
  92:	49a9                	li	s3,10
            char *mem = (char *)((uintptr_t)sbrk(0) - PGSIZE * (NUM_PAGES - i)); // Access previously allocated memory
  94:	4501                	li	a0,0
  96:	00000097          	auipc	ra,0x0
  9a:	64e080e7          	jalr	1614(ra) # 6e4 <sbrk>
  9e:	412507b3          	sub	a5,a0,s2
            volatile char value = mem[0]; // Read the memory to ensure no COW is triggered
  a2:	0007c783          	lbu	a5,0(a5)
  a6:	faf40fa3          	sb	a5,-65(s0)
            printf("Child read value from page %d: %d\n", i, value);
  aa:	fbf44603          	lbu	a2,-65(s0)
  ae:	85a6                	mv	a1,s1
  b0:	8556                	mv	a0,s5
  b2:	00001097          	auipc	ra,0x1
  b6:	932080e7          	jalr	-1742(ra) # 9e4 <printf>
        for (int i = 0; i < NUM_PAGES; i++) {
  ba:	2485                	addiw	s1,s1,1
  bc:	9952                	add	s2,s2,s4
  be:	fd349be3          	bne	s1,s3,94 <readonly_test+0x94>
        exit(0);
  c2:	4501                	li	a0,0
  c4:	00000097          	auipc	ra,0x0
  c8:	598080e7          	jalr	1432(ra) # 65c <exit>

00000000000000cc <write_test>:


void write_test() {
  cc:	7139                	addi	sp,sp,-64
  ce:	fc06                	sd	ra,56(sp)
  d0:	f822                	sd	s0,48(sp)
  d2:	0080                	addi	s0,sp,64
    printf("Running Write Test\n");
  d4:	00001517          	auipc	a0,0x1
  d8:	b3450513          	addi	a0,a0,-1228 # c08 <malloc+0x16c>
  dc:	00001097          	auipc	ra,0x1
  e0:	908080e7          	jalr	-1784(ra) # 9e4 <printf>

    int pid = fork();
  e4:	00000097          	auipc	ra,0x0
  e8:	570080e7          	jalr	1392(ra) # 654 <fork>
    if (pid < 0) {
  ec:	04054b63          	bltz	a0,142 <write_test+0x76>
        printf("Fork failed\n");
        return;
    } else if (pid == 0) {
  f0:	e141                	bnez	a0,170 <write_test+0xa4>
  f2:	f426                	sd	s1,40(sp)
  f4:	f04a                	sd	s2,32(sp)
  f6:	ec4e                	sd	s3,24(sp)
  f8:	e852                	sd	s4,16(sp)
  fa:	e456                	sd	s5,8(sp)
  fc:	04100493          	li	s1,65
        // Child process: write to multiple pages of allocated memory to trigger COW
        for (int i = 0; i < NUM_PAGES; i++) {
            char *mem = sbrk(PGSIZE);
            if (mem == (char *)-1) {
 100:	59fd                	li	s3,-1
                printf("sbrk failed\n");
                return;
            }
            // Write to the memory to trigger COW
            mem[0] = 'A' + i;
            printf("Child wrote to memory on page %d mem[0] %d\n", i, mem[0]);
 102:	00001a97          	auipc	s5,0x1
 106:	b1ea8a93          	addi	s5,s5,-1250 # c20 <malloc+0x184>
        for (int i = 0; i < NUM_PAGES; i++) {
 10a:	04b00a13          	li	s4,75
 10e:	fbf4891b          	addiw	s2,s1,-65
            char *mem = sbrk(PGSIZE);
 112:	6505                	lui	a0,0x1
 114:	00000097          	auipc	ra,0x0
 118:	5d0080e7          	jalr	1488(ra) # 6e4 <sbrk>
            if (mem == (char *)-1) {
 11c:	03350c63          	beq	a0,s3,154 <write_test+0x88>
            mem[0] = 'A' + i;
 120:	00950023          	sb	s1,0(a0) # 1000 <freep>
            printf("Child wrote to memory on page %d mem[0] %d\n", i, mem[0]);
 124:	8626                	mv	a2,s1
 126:	85ca                	mv	a1,s2
 128:	8556                	mv	a0,s5
 12a:	00001097          	auipc	ra,0x1
 12e:	8ba080e7          	jalr	-1862(ra) # 9e4 <printf>
        for (int i = 0; i < NUM_PAGES; i++) {
 132:	2485                	addiw	s1,s1,1
 134:	fd449de3          	bne	s1,s4,10e <write_test+0x42>
        }
        //return;
        exit(0);
 138:	4501                	li	a0,0
 13a:	00000097          	auipc	ra,0x0
 13e:	522080e7          	jalr	1314(ra) # 65c <exit>
        printf("Fork failed\n");
 142:	00001517          	auipc	a0,0x1
 146:	a8e50513          	addi	a0,a0,-1394 # bd0 <malloc+0x134>
 14a:	00001097          	auipc	ra,0x1
 14e:	89a080e7          	jalr	-1894(ra) # 9e4 <printf>
        return;
 152:	a025                	j	17a <write_test+0xae>
                printf("sbrk failed\n");
 154:	00001517          	auipc	a0,0x1
 158:	a6450513          	addi	a0,a0,-1436 # bb8 <malloc+0x11c>
 15c:	00001097          	auipc	ra,0x1
 160:	888080e7          	jalr	-1912(ra) # 9e4 <printf>
                return;
 164:	74a2                	ld	s1,40(sp)
 166:	7902                	ld	s2,32(sp)
 168:	69e2                	ld	s3,24(sp)
 16a:	6a42                	ld	s4,16(sp)
 16c:	6aa2                	ld	s5,8(sp)
 16e:	a031                	j	17a <write_test+0xae>
    } else {
        // Parent process: wait for the child to complete
        wait((int *)0);
 170:	4501                	li	a0,0
 172:	00000097          	auipc	ra,0x0
 176:	4f2080e7          	jalr	1266(ra) # 664 <wait>
    }
}
 17a:	70e2                	ld	ra,56(sp)
 17c:	7442                	ld	s0,48(sp)
 17e:	6121                	addi	sp,sp,64
 180:	8082                	ret

0000000000000182 <mixed_test>:

void mixed_test() {
 182:	715d                	addi	sp,sp,-80
 184:	e486                	sd	ra,72(sp)
 186:	e0a2                	sd	s0,64(sp)
 188:	0880                	addi	s0,sp,80
    printf("Running Mixed Read/Write Test\n");
 18a:	00001517          	auipc	a0,0x1
 18e:	ac650513          	addi	a0,a0,-1338 # c50 <malloc+0x1b4>
 192:	00001097          	auipc	ra,0x1
 196:	852080e7          	jalr	-1966(ra) # 9e4 <printf>

    int pid = fork();
 19a:	00000097          	auipc	ra,0x0
 19e:	4ba080e7          	jalr	1210(ra) # 654 <fork>
    if (pid < 0) {
 1a2:	02054463          	bltz	a0,1ca <mixed_test+0x48>
 1a6:	fc26                	sd	s1,56(sp)
 1a8:	84aa                	mv	s1,a0
        printf("Fork failed\n");
        return;
    } else if (pid == 0) {
 1aa:	e145                	bnez	a0,24a <mixed_test+0xc8>
 1ac:	f84a                	sd	s2,48(sp)
 1ae:	f44e                	sd	s3,40(sp)
 1b0:	f052                	sd	s4,32(sp)
 1b2:	ec56                	sd	s5,24(sp)
        // Child process: alternate between reading and writing to pages
        for (int i = 0; i < NUM_PAGES; i++) {
            char *mem = sbrk(PGSIZE);
            if (mem == (char *)-1) {
 1b4:	597d                	li	s2,-1
                volatile char value = mem[0];
                printf("Child read value from page %d: %d\n", i, value);
            } else {
                // Write to the page
                mem[0] = 'A' + i;
                printf("Child wrote to memory on page %d\n", i);
 1b6:	00001a97          	auipc	s5,0x1
 1ba:	abaa8a93          	addi	s5,s5,-1350 # c70 <malloc+0x1d4>
                printf("Child read value from page %d: %d\n", i, value);
 1be:	00001a17          	auipc	s4,0x1
 1c2:	a22a0a13          	addi	s4,s4,-1502 # be0 <malloc+0x144>
        for (int i = 0; i < NUM_PAGES; i++) {
 1c6:	49a9                	li	s3,10
 1c8:	a0a9                	j	212 <mixed_test+0x90>
        printf("Fork failed\n");
 1ca:	00001517          	auipc	a0,0x1
 1ce:	a0650513          	addi	a0,a0,-1530 # bd0 <malloc+0x134>
 1d2:	00001097          	auipc	ra,0x1
 1d6:	812080e7          	jalr	-2030(ra) # 9e4 <printf>
        return;
 1da:	a8b5                	j	256 <mixed_test+0xd4>
                printf("sbrk failed\n");
 1dc:	00001517          	auipc	a0,0x1
 1e0:	9dc50513          	addi	a0,a0,-1572 # bb8 <malloc+0x11c>
 1e4:	00001097          	auipc	ra,0x1
 1e8:	800080e7          	jalr	-2048(ra) # 9e4 <printf>
                return;
 1ec:	74e2                	ld	s1,56(sp)
 1ee:	7942                	ld	s2,48(sp)
 1f0:	79a2                	ld	s3,40(sp)
 1f2:	7a02                	ld	s4,32(sp)
 1f4:	6ae2                	ld	s5,24(sp)
 1f6:	a085                	j	256 <mixed_test+0xd4>
                mem[0] = 'A' + i;
 1f8:	0414879b          	addiw	a5,s1,65
 1fc:	00f50023          	sb	a5,0(a0)
                printf("Child wrote to memory on page %d\n", i);
 200:	85a6                	mv	a1,s1
 202:	8556                	mv	a0,s5
 204:	00000097          	auipc	ra,0x0
 208:	7e0080e7          	jalr	2016(ra) # 9e4 <printf>
        for (int i = 0; i < NUM_PAGES; i++) {
 20c:	2485                	addiw	s1,s1,1
 20e:	03348963          	beq	s1,s3,240 <mixed_test+0xbe>
            char *mem = sbrk(PGSIZE);
 212:	6505                	lui	a0,0x1
 214:	00000097          	auipc	ra,0x0
 218:	4d0080e7          	jalr	1232(ra) # 6e4 <sbrk>
            if (mem == (char *)-1) {
 21c:	fd2500e3          	beq	a0,s2,1dc <mixed_test+0x5a>
            if (i % 2 == 0) {
 220:	0014f793          	andi	a5,s1,1
 224:	fbf1                	bnez	a5,1f8 <mixed_test+0x76>
                volatile char value = mem[0];
 226:	00054783          	lbu	a5,0(a0) # 1000 <freep>
 22a:	faf40fa3          	sb	a5,-65(s0)
                printf("Child read value from page %d: %d\n", i, value);
 22e:	fbf44603          	lbu	a2,-65(s0)
 232:	85a6                	mv	a1,s1
 234:	8552                	mv	a0,s4
 236:	00000097          	auipc	ra,0x0
 23a:	7ae080e7          	jalr	1966(ra) # 9e4 <printf>
 23e:	b7f9                	j	20c <mixed_test+0x8a>
            }
        }
        //return;
        exit(0);
 240:	4501                	li	a0,0
 242:	00000097          	auipc	ra,0x0
 246:	41a080e7          	jalr	1050(ra) # 65c <exit>
    } else {
        // Parent process: wait for the child to complete
        wait((int *)0);
 24a:	4501                	li	a0,0
 24c:	00000097          	auipc	ra,0x0
 250:	418080e7          	jalr	1048(ra) # 664 <wait>
 254:	74e2                	ld	s1,56(sp)
    }
}
 256:	60a6                	ld	ra,72(sp)
 258:	6406                	ld	s0,64(sp)
 25a:	6161                	addi	sp,sp,80
 25c:	8082                	ret

000000000000025e <main>:

int main(void) {
 25e:	711d                	addi	sp,sp,-96
 260:	ec86                	sd	ra,88(sp)
 262:	e8a2                	sd	s0,80(sp)
 264:	e4a6                	sd	s1,72(sp)
 266:	e0ca                	sd	s2,64(sp)
 268:	fc4e                	sd	s3,56(sp)
 26a:	f852                	sd	s4,48(sp)
 26c:	f456                	sd	s5,40(sp)
 26e:	f05a                	sd	s6,32(sp)
 270:	ec5e                	sd	s7,24(sp)
 272:	e862                	sd	s8,16(sp)
 274:	e466                	sd	s9,8(sp)
 276:	e06a                	sd	s10,0(sp)
 278:	1080                	addi	s0,sp,96
    int total_fault_count_initial = 0;
    int total_fault_count_read = 0;
    int total_fault_count_write = 0;
    int total_fault_count_mixed = 0;

    cow_fault_count_initial = get_fault_counts();
 27a:	00000097          	auipc	ra,0x0
 27e:	48a080e7          	jalr	1162(ra) # 704 <get_fault_counts>
 282:	8a2a                	mv	s4,a0
    total_fault_count_initial = get_total_fault_counts();
 284:	00000097          	auipc	ra,0x0
 288:	488080e7          	jalr	1160(ra) # 70c <get_total_fault_counts>
 28c:	892a                	mv	s2,a0
  
    printf("Before: Cow Fault Count for Initial: %d Read: %d; Write: %d, Mixed: %d\n", cow_fault_count_initial, cow_fault_count_read, cow_fault_count_write, cow_fault_count_mixed);
 28e:	4701                	li	a4,0
 290:	4681                	li	a3,0
 292:	4601                	li	a2,0
 294:	85d2                	mv	a1,s4
 296:	00001517          	auipc	a0,0x1
 29a:	a0250513          	addi	a0,a0,-1534 # c98 <malloc+0x1fc>
 29e:	00000097          	auipc	ra,0x0
 2a2:	746080e7          	jalr	1862(ra) # 9e4 <printf>
    printf("Before: Total Fault Count for Initial %d, Read: %d; Write: %d, Mixed: %d\n", total_fault_count_initial, total_fault_count_read, total_fault_count_write, total_fault_count_mixed);
 2a6:	4701                	li	a4,0
 2a8:	4681                	li	a3,0
 2aa:	4601                	li	a2,0
 2ac:	85ca                	mv	a1,s2
 2ae:	00001517          	auipc	a0,0x1
 2b2:	a3250513          	addi	a0,a0,-1486 # ce0 <malloc+0x244>
 2b6:	00000097          	auipc	ra,0x0
 2ba:	72e080e7          	jalr	1838(ra) # 9e4 <printf>

    // Run the read-only test
    readonly_test();
 2be:	00000097          	auipc	ra,0x0
 2c2:	d42080e7          	jalr	-702(ra) # 0 <readonly_test>
    // Retrieve and print the fault counts using the new system call
    cow_fault_count_read = get_fault_counts()-cow_fault_count_initial;
 2c6:	00000097          	auipc	ra,0x0
 2ca:	43e080e7          	jalr	1086(ra) # 704 <get_fault_counts>
 2ce:	414504bb          	subw	s1,a0,s4
 2d2:	00048a9b          	sext.w	s5,s1
    total_fault_count_read = get_total_fault_counts()-total_fault_count_initial;
 2d6:	00000097          	auipc	ra,0x0
 2da:	436080e7          	jalr	1078(ra) # 70c <get_total_fault_counts>
 2de:	41250cbb          	subw	s9,a0,s2
 2e2:	000c8b9b          	sext.w	s7,s9
    if (cow_fault_count_read < 0) {
 2e6:	0a0acd63          	bltz	s5,3a0 <main+0x142>
        printf("Failed to get fault counts\n");
    }
    // Run the write test
    write_test();
 2ea:	00000097          	auipc	ra,0x0
 2ee:	de2080e7          	jalr	-542(ra) # cc <write_test>
    // Retrieve and print the fault counts using the new system call
    cow_fault_count_write = get_fault_counts()-cow_fault_count_read-cow_fault_count_initial;
 2f2:	00000097          	auipc	ra,0x0
 2f6:	412080e7          	jalr	1042(ra) # 704 <get_fault_counts>
 2fa:	40950d3b          	subw	s10,a0,s1
 2fe:	414d0d3b          	subw	s10,s10,s4
 302:	000d0b1b          	sext.w	s6,s10
    total_fault_count_write = get_total_fault_counts()-total_fault_count_read-total_fault_count_initial;
 306:	00000097          	auipc	ra,0x0
 30a:	406080e7          	jalr	1030(ra) # 70c <get_total_fault_counts>
 30e:	419509bb          	subw	s3,a0,s9
 312:	412989bb          	subw	s3,s3,s2
 316:	00098c1b          	sext.w	s8,s3
    if (cow_fault_count_write < 0) {
 31a:	080b4c63          	bltz	s6,3b2 <main+0x154>
        printf("Failed to get fault counts\n");
    }

    // Run the mixed read/write test
    mixed_test();
 31e:	00000097          	auipc	ra,0x0
 322:	e64080e7          	jalr	-412(ra) # 182 <mixed_test>
    cow_fault_count_mixed = get_fault_counts()-cow_fault_count_read-cow_fault_count_write-cow_fault_count_initial;
 326:	00000097          	auipc	ra,0x0
 32a:	3de080e7          	jalr	990(ra) # 704 <get_fault_counts>
 32e:	409504bb          	subw	s1,a0,s1
 332:	41a484bb          	subw	s1,s1,s10
 336:	414484bb          	subw	s1,s1,s4
    total_fault_count_mixed = get_total_fault_counts()-total_fault_count_write-total_fault_count_read-total_fault_count_initial;
 33a:	00000097          	auipc	ra,0x0
 33e:	3d2080e7          	jalr	978(ra) # 70c <get_total_fault_counts>
 342:	413509bb          	subw	s3,a0,s3
 346:	419989bb          	subw	s3,s3,s9
 34a:	412989bb          	subw	s3,s3,s2
    // Retrieve and print the fault counts using the new system call
    if (cow_fault_count_mixed < 0) {
 34e:	0604cb63          	bltz	s1,3c4 <main+0x166>
        printf("Failed to get fault counts\n");
    }

    printf("After: Cow Fault Count for Initial %d, Read: %d; Write: %d, Mixed: %d\n", cow_fault_count_initial, cow_fault_count_read, cow_fault_count_write, cow_fault_count_mixed);
 352:	8726                	mv	a4,s1
 354:	86da                	mv	a3,s6
 356:	8656                	mv	a2,s5
 358:	85d2                	mv	a1,s4
 35a:	00001517          	auipc	a0,0x1
 35e:	9f650513          	addi	a0,a0,-1546 # d50 <malloc+0x2b4>
 362:	00000097          	auipc	ra,0x0
 366:	682080e7          	jalr	1666(ra) # 9e4 <printf>
    printf("After: Total Fault Count for Initial %d, Read: %d; Write: %d, Mixed: %d\n", total_fault_count_initial, total_fault_count_read, total_fault_count_write, total_fault_count_mixed);
 36a:	874e                	mv	a4,s3
 36c:	86e2                	mv	a3,s8
 36e:	865e                	mv	a2,s7
 370:	85ca                	mv	a1,s2
 372:	00001517          	auipc	a0,0x1
 376:	a2650513          	addi	a0,a0,-1498 # d98 <malloc+0x2fc>
 37a:	00000097          	auipc	ra,0x0
 37e:	66a080e7          	jalr	1642(ra) # 9e4 <printf>

    return 0;
}
 382:	4501                	li	a0,0
 384:	60e6                	ld	ra,88(sp)
 386:	6446                	ld	s0,80(sp)
 388:	64a6                	ld	s1,72(sp)
 38a:	6906                	ld	s2,64(sp)
 38c:	79e2                	ld	s3,56(sp)
 38e:	7a42                	ld	s4,48(sp)
 390:	7aa2                	ld	s5,40(sp)
 392:	7b02                	ld	s6,32(sp)
 394:	6be2                	ld	s7,24(sp)
 396:	6c42                	ld	s8,16(sp)
 398:	6ca2                	ld	s9,8(sp)
 39a:	6d02                	ld	s10,0(sp)
 39c:	6125                	addi	sp,sp,96
 39e:	8082                	ret
        printf("Failed to get fault counts\n");
 3a0:	00001517          	auipc	a0,0x1
 3a4:	99050513          	addi	a0,a0,-1648 # d30 <malloc+0x294>
 3a8:	00000097          	auipc	ra,0x0
 3ac:	63c080e7          	jalr	1596(ra) # 9e4 <printf>
 3b0:	bf2d                	j	2ea <main+0x8c>
        printf("Failed to get fault counts\n");
 3b2:	00001517          	auipc	a0,0x1
 3b6:	97e50513          	addi	a0,a0,-1666 # d30 <malloc+0x294>
 3ba:	00000097          	auipc	ra,0x0
 3be:	62a080e7          	jalr	1578(ra) # 9e4 <printf>
 3c2:	bfb1                	j	31e <main+0xc0>
        printf("Failed to get fault counts\n");
 3c4:	00001517          	auipc	a0,0x1
 3c8:	96c50513          	addi	a0,a0,-1684 # d30 <malloc+0x294>
 3cc:	00000097          	auipc	ra,0x0
 3d0:	618080e7          	jalr	1560(ra) # 9e4 <printf>
 3d4:	bfbd                	j	352 <main+0xf4>

00000000000003d6 <_main>:
//
// wrapper so that it's OK if main() does not call exit().
//
void
_main()
{
 3d6:	1141                	addi	sp,sp,-16
 3d8:	e406                	sd	ra,8(sp)
 3da:	e022                	sd	s0,0(sp)
 3dc:	0800                	addi	s0,sp,16
  extern int main();
  main();
 3de:	00000097          	auipc	ra,0x0
 3e2:	e80080e7          	jalr	-384(ra) # 25e <main>
  exit(0);
 3e6:	4501                	li	a0,0
 3e8:	00000097          	auipc	ra,0x0
 3ec:	274080e7          	jalr	628(ra) # 65c <exit>

00000000000003f0 <strcpy>:
}

char*
strcpy(char *s, const char *t)
{
 3f0:	1141                	addi	sp,sp,-16
 3f2:	e422                	sd	s0,8(sp)
 3f4:	0800                	addi	s0,sp,16
  char *os;

  os = s;
  while((*s++ = *t++) != 0)
 3f6:	87aa                	mv	a5,a0
 3f8:	0585                	addi	a1,a1,1
 3fa:	0785                	addi	a5,a5,1
 3fc:	fff5c703          	lbu	a4,-1(a1)
 400:	fee78fa3          	sb	a4,-1(a5)
 404:	fb75                	bnez	a4,3f8 <strcpy+0x8>
    ;
  return os;
}
 406:	6422                	ld	s0,8(sp)
 408:	0141                	addi	sp,sp,16
 40a:	8082                	ret

000000000000040c <strcmp>:

int
strcmp(const char *p, const char *q)
{
 40c:	1141                	addi	sp,sp,-16
 40e:	e422                	sd	s0,8(sp)
 410:	0800                	addi	s0,sp,16
  while(*p && *p == *q)
 412:	00054783          	lbu	a5,0(a0)
 416:	cb91                	beqz	a5,42a <strcmp+0x1e>
 418:	0005c703          	lbu	a4,0(a1)
 41c:	00f71763          	bne	a4,a5,42a <strcmp+0x1e>
    p++, q++;
 420:	0505                	addi	a0,a0,1
 422:	0585                	addi	a1,a1,1
  while(*p && *p == *q)
 424:	00054783          	lbu	a5,0(a0)
 428:	fbe5                	bnez	a5,418 <strcmp+0xc>
  return (uchar)*p - (uchar)*q;
 42a:	0005c503          	lbu	a0,0(a1)
}
 42e:	40a7853b          	subw	a0,a5,a0
 432:	6422                	ld	s0,8(sp)
 434:	0141                	addi	sp,sp,16
 436:	8082                	ret

0000000000000438 <strlen>:

uint
strlen(const char *s)
{
 438:	1141                	addi	sp,sp,-16
 43a:	e422                	sd	s0,8(sp)
 43c:	0800                	addi	s0,sp,16
  int n;

  for(n = 0; s[n]; n++)
 43e:	00054783          	lbu	a5,0(a0)
 442:	cf91                	beqz	a5,45e <strlen+0x26>
 444:	0505                	addi	a0,a0,1
 446:	87aa                	mv	a5,a0
 448:	86be                	mv	a3,a5
 44a:	0785                	addi	a5,a5,1
 44c:	fff7c703          	lbu	a4,-1(a5)
 450:	ff65                	bnez	a4,448 <strlen+0x10>
 452:	40a6853b          	subw	a0,a3,a0
 456:	2505                	addiw	a0,a0,1
    ;
  return n;
}
 458:	6422                	ld	s0,8(sp)
 45a:	0141                	addi	sp,sp,16
 45c:	8082                	ret
  for(n = 0; s[n]; n++)
 45e:	4501                	li	a0,0
 460:	bfe5                	j	458 <strlen+0x20>

0000000000000462 <memset>:

void*
memset(void *dst, int c, uint n)
{
 462:	1141                	addi	sp,sp,-16
 464:	e422                	sd	s0,8(sp)
 466:	0800                	addi	s0,sp,16
  char *cdst = (char *) dst;
  int i;
  for(i = 0; i < n; i++){
 468:	ca19                	beqz	a2,47e <memset+0x1c>
 46a:	87aa                	mv	a5,a0
 46c:	1602                	slli	a2,a2,0x20
 46e:	9201                	srli	a2,a2,0x20
 470:	00a60733          	add	a4,a2,a0
    cdst[i] = c;
 474:	00b78023          	sb	a1,0(a5)
  for(i = 0; i < n; i++){
 478:	0785                	addi	a5,a5,1
 47a:	fee79de3          	bne	a5,a4,474 <memset+0x12>
  }
  return dst;
}
 47e:	6422                	ld	s0,8(sp)
 480:	0141                	addi	sp,sp,16
 482:	8082                	ret

0000000000000484 <strchr>:

char*
strchr(const char *s, char c)
{
 484:	1141                	addi	sp,sp,-16
 486:	e422                	sd	s0,8(sp)
 488:	0800                	addi	s0,sp,16
  for(; *s; s++)
 48a:	00054783          	lbu	a5,0(a0)
 48e:	cb99                	beqz	a5,4a4 <strchr+0x20>
    if(*s == c)
 490:	00f58763          	beq	a1,a5,49e <strchr+0x1a>
  for(; *s; s++)
 494:	0505                	addi	a0,a0,1
 496:	00054783          	lbu	a5,0(a0)
 49a:	fbfd                	bnez	a5,490 <strchr+0xc>
      return (char*)s;
  return 0;
 49c:	4501                	li	a0,0
}
 49e:	6422                	ld	s0,8(sp)
 4a0:	0141                	addi	sp,sp,16
 4a2:	8082                	ret
  return 0;
 4a4:	4501                	li	a0,0
 4a6:	bfe5                	j	49e <strchr+0x1a>

00000000000004a8 <gets>:

char*
gets(char *buf, int max)
{
 4a8:	711d                	addi	sp,sp,-96
 4aa:	ec86                	sd	ra,88(sp)
 4ac:	e8a2                	sd	s0,80(sp)
 4ae:	e4a6                	sd	s1,72(sp)
 4b0:	e0ca                	sd	s2,64(sp)
 4b2:	fc4e                	sd	s3,56(sp)
 4b4:	f852                	sd	s4,48(sp)
 4b6:	f456                	sd	s5,40(sp)
 4b8:	f05a                	sd	s6,32(sp)
 4ba:	ec5e                	sd	s7,24(sp)
 4bc:	1080                	addi	s0,sp,96
 4be:	8baa                	mv	s7,a0
 4c0:	8a2e                	mv	s4,a1
  int i, cc;
  char c;

  for(i=0; i+1 < max; ){
 4c2:	892a                	mv	s2,a0
 4c4:	4481                	li	s1,0
    cc = read(0, &c, 1);
    if(cc < 1)
      break;
    buf[i++] = c;
    if(c == '\n' || c == '\r')
 4c6:	4aa9                	li	s5,10
 4c8:	4b35                	li	s6,13
  for(i=0; i+1 < max; ){
 4ca:	89a6                	mv	s3,s1
 4cc:	2485                	addiw	s1,s1,1
 4ce:	0344d863          	bge	s1,s4,4fe <gets+0x56>
    cc = read(0, &c, 1);
 4d2:	4605                	li	a2,1
 4d4:	faf40593          	addi	a1,s0,-81
 4d8:	4501                	li	a0,0
 4da:	00000097          	auipc	ra,0x0
 4de:	19a080e7          	jalr	410(ra) # 674 <read>
    if(cc < 1)
 4e2:	00a05e63          	blez	a0,4fe <gets+0x56>
    buf[i++] = c;
 4e6:	faf44783          	lbu	a5,-81(s0)
 4ea:	00f90023          	sb	a5,0(s2) # a000 <base+0x8ff0>
    if(c == '\n' || c == '\r')
 4ee:	01578763          	beq	a5,s5,4fc <gets+0x54>
 4f2:	0905                	addi	s2,s2,1
 4f4:	fd679be3          	bne	a5,s6,4ca <gets+0x22>
    buf[i++] = c;
 4f8:	89a6                	mv	s3,s1
 4fa:	a011                	j	4fe <gets+0x56>
 4fc:	89a6                	mv	s3,s1
      break;
  }
  buf[i] = '\0';
 4fe:	99de                	add	s3,s3,s7
 500:	00098023          	sb	zero,0(s3)
  return buf;
}
 504:	855e                	mv	a0,s7
 506:	60e6                	ld	ra,88(sp)
 508:	6446                	ld	s0,80(sp)
 50a:	64a6                	ld	s1,72(sp)
 50c:	6906                	ld	s2,64(sp)
 50e:	79e2                	ld	s3,56(sp)
 510:	7a42                	ld	s4,48(sp)
 512:	7aa2                	ld	s5,40(sp)
 514:	7b02                	ld	s6,32(sp)
 516:	6be2                	ld	s7,24(sp)
 518:	6125                	addi	sp,sp,96
 51a:	8082                	ret

000000000000051c <stat>:

int
stat(const char *n, struct stat *st)
{
 51c:	1101                	addi	sp,sp,-32
 51e:	ec06                	sd	ra,24(sp)
 520:	e822                	sd	s0,16(sp)
 522:	e04a                	sd	s2,0(sp)
 524:	1000                	addi	s0,sp,32
 526:	892e                	mv	s2,a1
  int fd;
  int r;

  fd = open(n, O_RDONLY);
 528:	4581                	li	a1,0
 52a:	00000097          	auipc	ra,0x0
 52e:	172080e7          	jalr	370(ra) # 69c <open>
  if(fd < 0)
 532:	02054663          	bltz	a0,55e <stat+0x42>
 536:	e426                	sd	s1,8(sp)
 538:	84aa                	mv	s1,a0
    return -1;
  r = fstat(fd, st);
 53a:	85ca                	mv	a1,s2
 53c:	00000097          	auipc	ra,0x0
 540:	178080e7          	jalr	376(ra) # 6b4 <fstat>
 544:	892a                	mv	s2,a0
  close(fd);
 546:	8526                	mv	a0,s1
 548:	00000097          	auipc	ra,0x0
 54c:	13c080e7          	jalr	316(ra) # 684 <close>
  return r;
 550:	64a2                	ld	s1,8(sp)
}
 552:	854a                	mv	a0,s2
 554:	60e2                	ld	ra,24(sp)
 556:	6442                	ld	s0,16(sp)
 558:	6902                	ld	s2,0(sp)
 55a:	6105                	addi	sp,sp,32
 55c:	8082                	ret
    return -1;
 55e:	597d                	li	s2,-1
 560:	bfcd                	j	552 <stat+0x36>

0000000000000562 <atoi>:

int
atoi(const char *s)
{
 562:	1141                	addi	sp,sp,-16
 564:	e422                	sd	s0,8(sp)
 566:	0800                	addi	s0,sp,16
  int n;

  n = 0;
  while('0' <= *s && *s <= '9')
 568:	00054683          	lbu	a3,0(a0)
 56c:	fd06879b          	addiw	a5,a3,-48
 570:	0ff7f793          	zext.b	a5,a5
 574:	4625                	li	a2,9
 576:	02f66863          	bltu	a2,a5,5a6 <atoi+0x44>
 57a:	872a                	mv	a4,a0
  n = 0;
 57c:	4501                	li	a0,0
    n = n*10 + *s++ - '0';
 57e:	0705                	addi	a4,a4,1
 580:	0025179b          	slliw	a5,a0,0x2
 584:	9fa9                	addw	a5,a5,a0
 586:	0017979b          	slliw	a5,a5,0x1
 58a:	9fb5                	addw	a5,a5,a3
 58c:	fd07851b          	addiw	a0,a5,-48
  while('0' <= *s && *s <= '9')
 590:	00074683          	lbu	a3,0(a4)
 594:	fd06879b          	addiw	a5,a3,-48
 598:	0ff7f793          	zext.b	a5,a5
 59c:	fef671e3          	bgeu	a2,a5,57e <atoi+0x1c>
  return n;
}
 5a0:	6422                	ld	s0,8(sp)
 5a2:	0141                	addi	sp,sp,16
 5a4:	8082                	ret
  n = 0;
 5a6:	4501                	li	a0,0
 5a8:	bfe5                	j	5a0 <atoi+0x3e>

00000000000005aa <memmove>:

void*
memmove(void *vdst, const void *vsrc, int n)
{
 5aa:	1141                	addi	sp,sp,-16
 5ac:	e422                	sd	s0,8(sp)
 5ae:	0800                	addi	s0,sp,16
  char *dst;
  const char *src;

  dst = vdst;
  src = vsrc;
  if (src > dst) {
 5b0:	02b57463          	bgeu	a0,a1,5d8 <memmove+0x2e>
    while(n-- > 0)
 5b4:	00c05f63          	blez	a2,5d2 <memmove+0x28>
 5b8:	1602                	slli	a2,a2,0x20
 5ba:	9201                	srli	a2,a2,0x20
 5bc:	00c507b3          	add	a5,a0,a2
  dst = vdst;
 5c0:	872a                	mv	a4,a0
      *dst++ = *src++;
 5c2:	0585                	addi	a1,a1,1
 5c4:	0705                	addi	a4,a4,1
 5c6:	fff5c683          	lbu	a3,-1(a1)
 5ca:	fed70fa3          	sb	a3,-1(a4)
    while(n-- > 0)
 5ce:	fef71ae3          	bne	a4,a5,5c2 <memmove+0x18>
    src += n;
    while(n-- > 0)
      *--dst = *--src;
  }
  return vdst;
}
 5d2:	6422                	ld	s0,8(sp)
 5d4:	0141                	addi	sp,sp,16
 5d6:	8082                	ret
    dst += n;
 5d8:	00c50733          	add	a4,a0,a2
    src += n;
 5dc:	95b2                	add	a1,a1,a2
    while(n-- > 0)
 5de:	fec05ae3          	blez	a2,5d2 <memmove+0x28>
 5e2:	fff6079b          	addiw	a5,a2,-1
 5e6:	1782                	slli	a5,a5,0x20
 5e8:	9381                	srli	a5,a5,0x20
 5ea:	fff7c793          	not	a5,a5
 5ee:	97ba                	add	a5,a5,a4
      *--dst = *--src;
 5f0:	15fd                	addi	a1,a1,-1
 5f2:	177d                	addi	a4,a4,-1
 5f4:	0005c683          	lbu	a3,0(a1)
 5f8:	00d70023          	sb	a3,0(a4)
    while(n-- > 0)
 5fc:	fee79ae3          	bne	a5,a4,5f0 <memmove+0x46>
 600:	bfc9                	j	5d2 <memmove+0x28>

0000000000000602 <memcmp>:

int
memcmp(const void *s1, const void *s2, uint n)
{
 602:	1141                	addi	sp,sp,-16
 604:	e422                	sd	s0,8(sp)
 606:	0800                	addi	s0,sp,16
  const char *p1 = s1, *p2 = s2;
  while (n-- > 0) {
 608:	ca05                	beqz	a2,638 <memcmp+0x36>
 60a:	fff6069b          	addiw	a3,a2,-1
 60e:	1682                	slli	a3,a3,0x20
 610:	9281                	srli	a3,a3,0x20
 612:	0685                	addi	a3,a3,1
 614:	96aa                	add	a3,a3,a0
    if (*p1 != *p2) {
 616:	00054783          	lbu	a5,0(a0)
 61a:	0005c703          	lbu	a4,0(a1)
 61e:	00e79863          	bne	a5,a4,62e <memcmp+0x2c>
      return *p1 - *p2;
    }
    p1++;
 622:	0505                	addi	a0,a0,1
    p2++;
 624:	0585                	addi	a1,a1,1
  while (n-- > 0) {
 626:	fed518e3          	bne	a0,a3,616 <memcmp+0x14>
  }
  return 0;
 62a:	4501                	li	a0,0
 62c:	a019                	j	632 <memcmp+0x30>
      return *p1 - *p2;
 62e:	40e7853b          	subw	a0,a5,a4
}
 632:	6422                	ld	s0,8(sp)
 634:	0141                	addi	sp,sp,16
 636:	8082                	ret
  return 0;
 638:	4501                	li	a0,0
 63a:	bfe5                	j	632 <memcmp+0x30>

000000000000063c <memcpy>:

void *
memcpy(void *dst, const void *src, uint n)
{
 63c:	1141                	addi	sp,sp,-16
 63e:	e406                	sd	ra,8(sp)
 640:	e022                	sd	s0,0(sp)
 642:	0800                	addi	s0,sp,16
  return memmove(dst, src, n);
 644:	00000097          	auipc	ra,0x0
 648:	f66080e7          	jalr	-154(ra) # 5aa <memmove>
}
 64c:	60a2                	ld	ra,8(sp)
 64e:	6402                	ld	s0,0(sp)
 650:	0141                	addi	sp,sp,16
 652:	8082                	ret

0000000000000654 <fork>:
# generated by usys.pl - do not edit
#include "kernel/syscall.h"
.global fork
fork:
 li a7, SYS_fork
 654:	4885                	li	a7,1
 ecall
 656:	00000073          	ecall
 ret
 65a:	8082                	ret

000000000000065c <exit>:
.global exit
exit:
 li a7, SYS_exit
 65c:	4889                	li	a7,2
 ecall
 65e:	00000073          	ecall
 ret
 662:	8082                	ret

0000000000000664 <wait>:
.global wait
wait:
 li a7, SYS_wait
 664:	488d                	li	a7,3
 ecall
 666:	00000073          	ecall
 ret
 66a:	8082                	ret

000000000000066c <pipe>:
.global pipe
pipe:
 li a7, SYS_pipe
 66c:	4891                	li	a7,4
 ecall
 66e:	00000073          	ecall
 ret
 672:	8082                	ret

0000000000000674 <read>:
.global read
read:
 li a7, SYS_read
 674:	4895                	li	a7,5
 ecall
 676:	00000073          	ecall
 ret
 67a:	8082                	ret

000000000000067c <write>:
.global write
write:
 li a7, SYS_write
 67c:	48c1                	li	a7,16
 ecall
 67e:	00000073          	ecall
 ret
 682:	8082                	ret

0000000000000684 <close>:
.global close
close:
 li a7, SYS_close
 684:	48d5                	li	a7,21
 ecall
 686:	00000073          	ecall
 ret
 68a:	8082                	ret

000000000000068c <kill>:
.global kill
kill:
 li a7, SYS_kill
 68c:	4899                	li	a7,6
 ecall
 68e:	00000073          	ecall
 ret
 692:	8082                	ret

0000000000000694 <exec>:
.global exec
exec:
 li a7, SYS_exec
 694:	489d                	li	a7,7
 ecall
 696:	00000073          	ecall
 ret
 69a:	8082                	ret

000000000000069c <open>:
.global open
open:
 li a7, SYS_open
 69c:	48bd                	li	a7,15
 ecall
 69e:	00000073          	ecall
 ret
 6a2:	8082                	ret

00000000000006a4 <mknod>:
.global mknod
mknod:
 li a7, SYS_mknod
 6a4:	48c5                	li	a7,17
 ecall
 6a6:	00000073          	ecall
 ret
 6aa:	8082                	ret

00000000000006ac <unlink>:
.global unlink
unlink:
 li a7, SYS_unlink
 6ac:	48c9                	li	a7,18
 ecall
 6ae:	00000073          	ecall
 ret
 6b2:	8082                	ret

00000000000006b4 <fstat>:
.global fstat
fstat:
 li a7, SYS_fstat
 6b4:	48a1                	li	a7,8
 ecall
 6b6:	00000073          	ecall
 ret
 6ba:	8082                	ret

00000000000006bc <link>:
.global link
link:
 li a7, SYS_link
 6bc:	48cd                	li	a7,19
 ecall
 6be:	00000073          	ecall
 ret
 6c2:	8082                	ret

00000000000006c4 <mkdir>:
.global mkdir
mkdir:
 li a7, SYS_mkdir
 6c4:	48d1                	li	a7,20
 ecall
 6c6:	00000073          	ecall
 ret
 6ca:	8082                	ret

00000000000006cc <chdir>:
.global chdir
chdir:
 li a7, SYS_chdir
 6cc:	48a5                	li	a7,9
 ecall
 6ce:	00000073          	ecall
 ret
 6d2:	8082                	ret

00000000000006d4 <dup>:
.global dup
dup:
 li a7, SYS_dup
 6d4:	48a9                	li	a7,10
 ecall
 6d6:	00000073          	ecall
 ret
 6da:	8082                	ret

00000000000006dc <getpid>:
.global getpid
getpid:
 li a7, SYS_getpid
 6dc:	48ad                	li	a7,11
 ecall
 6de:	00000073          	ecall
 ret
 6e2:	8082                	ret

00000000000006e4 <sbrk>:
.global sbrk
sbrk:
 li a7, SYS_sbrk
 6e4:	48b1                	li	a7,12
 ecall
 6e6:	00000073          	ecall
 ret
 6ea:	8082                	ret

00000000000006ec <sleep>:
.global sleep
sleep:
 li a7, SYS_sleep
 6ec:	48b5                	li	a7,13
 ecall
 6ee:	00000073          	ecall
 ret
 6f2:	8082                	ret

00000000000006f4 <uptime>:
.global uptime
uptime:
 li a7, SYS_uptime
 6f4:	48b9                	li	a7,14
 ecall
 6f6:	00000073          	ecall
 ret
 6fa:	8082                	ret

00000000000006fc <waitx>:
.global waitx
waitx:
 li a7, SYS_waitx
 6fc:	48d9                	li	a7,22
 ecall
 6fe:	00000073          	ecall
 ret
 702:	8082                	ret

0000000000000704 <get_fault_counts>:
.global get_fault_counts
get_fault_counts:
 li a7, SYS_get_fault_counts
 704:	48dd                	li	a7,23
 ecall
 706:	00000073          	ecall
 ret
 70a:	8082                	ret

000000000000070c <get_total_fault_counts>:
.global get_total_fault_counts
get_total_fault_counts:
 li a7, SYS_get_total_fault_counts
 70c:	48e1                	li	a7,24
 ecall
 70e:	00000073          	ecall
 ret
 712:	8082                	ret

0000000000000714 <get_cow_faults>:
.global get_cow_faults
get_cow_faults:
 li a7, SYS_get_cow_faults
 714:	48e5                	li	a7,25
 ecall
 716:	00000073          	ecall
 ret
 71a:	8082                	ret

000000000000071c <putc>:

static char digits[] = "0123456789ABCDEF";

static void
putc(int fd, char c)
{
 71c:	1101                	addi	sp,sp,-32
 71e:	ec06                	sd	ra,24(sp)
 720:	e822                	sd	s0,16(sp)
 722:	1000                	addi	s0,sp,32
 724:	feb407a3          	sb	a1,-17(s0)
  write(fd, &c, 1);
 728:	4605                	li	a2,1
 72a:	fef40593          	addi	a1,s0,-17
 72e:	00000097          	auipc	ra,0x0
 732:	f4e080e7          	jalr	-178(ra) # 67c <write>
}
 736:	60e2                	ld	ra,24(sp)
 738:	6442                	ld	s0,16(sp)
 73a:	6105                	addi	sp,sp,32
 73c:	8082                	ret

000000000000073e <printint>:

static void
printint(int fd, int xx, int base, int sgn)
{
 73e:	7139                	addi	sp,sp,-64
 740:	fc06                	sd	ra,56(sp)
 742:	f822                	sd	s0,48(sp)
 744:	f426                	sd	s1,40(sp)
 746:	0080                	addi	s0,sp,64
 748:	84aa                	mv	s1,a0
  char buf[16];
  int i, neg;
  uint x;

  neg = 0;
  if(sgn && xx < 0){
 74a:	c299                	beqz	a3,750 <printint+0x12>
 74c:	0805cb63          	bltz	a1,7e2 <printint+0xa4>
    neg = 1;
    x = -xx;
  } else {
    x = xx;
 750:	2581                	sext.w	a1,a1
  neg = 0;
 752:	4881                	li	a7,0
 754:	fc040693          	addi	a3,s0,-64
  }

  i = 0;
 758:	4701                	li	a4,0
  do{
    buf[i++] = digits[x % base];
 75a:	2601                	sext.w	a2,a2
 75c:	00000517          	auipc	a0,0x0
 760:	6ec50513          	addi	a0,a0,1772 # e48 <digits>
 764:	883a                	mv	a6,a4
 766:	2705                	addiw	a4,a4,1
 768:	02c5f7bb          	remuw	a5,a1,a2
 76c:	1782                	slli	a5,a5,0x20
 76e:	9381                	srli	a5,a5,0x20
 770:	97aa                	add	a5,a5,a0
 772:	0007c783          	lbu	a5,0(a5)
 776:	00f68023          	sb	a5,0(a3)
  }while((x /= base) != 0);
 77a:	0005879b          	sext.w	a5,a1
 77e:	02c5d5bb          	divuw	a1,a1,a2
 782:	0685                	addi	a3,a3,1
 784:	fec7f0e3          	bgeu	a5,a2,764 <printint+0x26>
  if(neg)
 788:	00088c63          	beqz	a7,7a0 <printint+0x62>
    buf[i++] = '-';
 78c:	fd070793          	addi	a5,a4,-48
 790:	00878733          	add	a4,a5,s0
 794:	02d00793          	li	a5,45
 798:	fef70823          	sb	a5,-16(a4)
 79c:	0028071b          	addiw	a4,a6,2

  while(--i >= 0)
 7a0:	02e05c63          	blez	a4,7d8 <printint+0x9a>
 7a4:	f04a                	sd	s2,32(sp)
 7a6:	ec4e                	sd	s3,24(sp)
 7a8:	fc040793          	addi	a5,s0,-64
 7ac:	00e78933          	add	s2,a5,a4
 7b0:	fff78993          	addi	s3,a5,-1
 7b4:	99ba                	add	s3,s3,a4
 7b6:	377d                	addiw	a4,a4,-1
 7b8:	1702                	slli	a4,a4,0x20
 7ba:	9301                	srli	a4,a4,0x20
 7bc:	40e989b3          	sub	s3,s3,a4
    putc(fd, buf[i]);
 7c0:	fff94583          	lbu	a1,-1(s2)
 7c4:	8526                	mv	a0,s1
 7c6:	00000097          	auipc	ra,0x0
 7ca:	f56080e7          	jalr	-170(ra) # 71c <putc>
  while(--i >= 0)
 7ce:	197d                	addi	s2,s2,-1
 7d0:	ff3918e3          	bne	s2,s3,7c0 <printint+0x82>
 7d4:	7902                	ld	s2,32(sp)
 7d6:	69e2                	ld	s3,24(sp)
}
 7d8:	70e2                	ld	ra,56(sp)
 7da:	7442                	ld	s0,48(sp)
 7dc:	74a2                	ld	s1,40(sp)
 7de:	6121                	addi	sp,sp,64
 7e0:	8082                	ret
    x = -xx;
 7e2:	40b005bb          	negw	a1,a1
    neg = 1;
 7e6:	4885                	li	a7,1
    x = -xx;
 7e8:	b7b5                	j	754 <printint+0x16>

00000000000007ea <vprintf>:
}

// Print to the given fd. Only understands %d, %x, %p, %s.
void
vprintf(int fd, const char *fmt, va_list ap)
{
 7ea:	715d                	addi	sp,sp,-80
 7ec:	e486                	sd	ra,72(sp)
 7ee:	e0a2                	sd	s0,64(sp)
 7f0:	f84a                	sd	s2,48(sp)
 7f2:	0880                	addi	s0,sp,80
  char *s;
  int c, i, state;

  state = 0;
  for(i = 0; fmt[i]; i++){
 7f4:	0005c903          	lbu	s2,0(a1)
 7f8:	1a090a63          	beqz	s2,9ac <vprintf+0x1c2>
 7fc:	fc26                	sd	s1,56(sp)
 7fe:	f44e                	sd	s3,40(sp)
 800:	f052                	sd	s4,32(sp)
 802:	ec56                	sd	s5,24(sp)
 804:	e85a                	sd	s6,16(sp)
 806:	e45e                	sd	s7,8(sp)
 808:	8aaa                	mv	s5,a0
 80a:	8bb2                	mv	s7,a2
 80c:	00158493          	addi	s1,a1,1
  state = 0;
 810:	4981                	li	s3,0
      if(c == '%'){
        state = '%';
      } else {
        putc(fd, c);
      }
    } else if(state == '%'){
 812:	02500a13          	li	s4,37
 816:	4b55                	li	s6,21
 818:	a839                	j	836 <vprintf+0x4c>
        putc(fd, c);
 81a:	85ca                	mv	a1,s2
 81c:	8556                	mv	a0,s5
 81e:	00000097          	auipc	ra,0x0
 822:	efe080e7          	jalr	-258(ra) # 71c <putc>
 826:	a019                	j	82c <vprintf+0x42>
    } else if(state == '%'){
 828:	01498d63          	beq	s3,s4,842 <vprintf+0x58>
  for(i = 0; fmt[i]; i++){
 82c:	0485                	addi	s1,s1,1
 82e:	fff4c903          	lbu	s2,-1(s1)
 832:	16090763          	beqz	s2,9a0 <vprintf+0x1b6>
    if(state == 0){
 836:	fe0999e3          	bnez	s3,828 <vprintf+0x3e>
      if(c == '%'){
 83a:	ff4910e3          	bne	s2,s4,81a <vprintf+0x30>
        state = '%';
 83e:	89d2                	mv	s3,s4
 840:	b7f5                	j	82c <vprintf+0x42>
      if(c == 'd'){
 842:	13490463          	beq	s2,s4,96a <vprintf+0x180>
 846:	f9d9079b          	addiw	a5,s2,-99
 84a:	0ff7f793          	zext.b	a5,a5
 84e:	12fb6763          	bltu	s6,a5,97c <vprintf+0x192>
 852:	f9d9079b          	addiw	a5,s2,-99
 856:	0ff7f713          	zext.b	a4,a5
 85a:	12eb6163          	bltu	s6,a4,97c <vprintf+0x192>
 85e:	00271793          	slli	a5,a4,0x2
 862:	00000717          	auipc	a4,0x0
 866:	58e70713          	addi	a4,a4,1422 # df0 <malloc+0x354>
 86a:	97ba                	add	a5,a5,a4
 86c:	439c                	lw	a5,0(a5)
 86e:	97ba                	add	a5,a5,a4
 870:	8782                	jr	a5
        printint(fd, va_arg(ap, int), 10, 1);
 872:	008b8913          	addi	s2,s7,8
 876:	4685                	li	a3,1
 878:	4629                	li	a2,10
 87a:	000ba583          	lw	a1,0(s7)
 87e:	8556                	mv	a0,s5
 880:	00000097          	auipc	ra,0x0
 884:	ebe080e7          	jalr	-322(ra) # 73e <printint>
 888:	8bca                	mv	s7,s2
      } else {
        // Unknown % sequence.  Print it to draw attention.
        putc(fd, '%');
        putc(fd, c);
      }
      state = 0;
 88a:	4981                	li	s3,0
 88c:	b745                	j	82c <vprintf+0x42>
        printint(fd, va_arg(ap, uint64), 10, 0);
 88e:	008b8913          	addi	s2,s7,8
 892:	4681                	li	a3,0
 894:	4629                	li	a2,10
 896:	000ba583          	lw	a1,0(s7)
 89a:	8556                	mv	a0,s5
 89c:	00000097          	auipc	ra,0x0
 8a0:	ea2080e7          	jalr	-350(ra) # 73e <printint>
 8a4:	8bca                	mv	s7,s2
      state = 0;
 8a6:	4981                	li	s3,0
 8a8:	b751                	j	82c <vprintf+0x42>
        printint(fd, va_arg(ap, int), 16, 0);
 8aa:	008b8913          	addi	s2,s7,8
 8ae:	4681                	li	a3,0
 8b0:	4641                	li	a2,16
 8b2:	000ba583          	lw	a1,0(s7)
 8b6:	8556                	mv	a0,s5
 8b8:	00000097          	auipc	ra,0x0
 8bc:	e86080e7          	jalr	-378(ra) # 73e <printint>
 8c0:	8bca                	mv	s7,s2
      state = 0;
 8c2:	4981                	li	s3,0
 8c4:	b7a5                	j	82c <vprintf+0x42>
 8c6:	e062                	sd	s8,0(sp)
        printptr(fd, va_arg(ap, uint64));
 8c8:	008b8c13          	addi	s8,s7,8
 8cc:	000bb983          	ld	s3,0(s7)
  putc(fd, '0');
 8d0:	03000593          	li	a1,48
 8d4:	8556                	mv	a0,s5
 8d6:	00000097          	auipc	ra,0x0
 8da:	e46080e7          	jalr	-442(ra) # 71c <putc>
  putc(fd, 'x');
 8de:	07800593          	li	a1,120
 8e2:	8556                	mv	a0,s5
 8e4:	00000097          	auipc	ra,0x0
 8e8:	e38080e7          	jalr	-456(ra) # 71c <putc>
 8ec:	4941                	li	s2,16
    putc(fd, digits[x >> (sizeof(uint64) * 8 - 4)]);
 8ee:	00000b97          	auipc	s7,0x0
 8f2:	55ab8b93          	addi	s7,s7,1370 # e48 <digits>
 8f6:	03c9d793          	srli	a5,s3,0x3c
 8fa:	97de                	add	a5,a5,s7
 8fc:	0007c583          	lbu	a1,0(a5)
 900:	8556                	mv	a0,s5
 902:	00000097          	auipc	ra,0x0
 906:	e1a080e7          	jalr	-486(ra) # 71c <putc>
  for (i = 0; i < (sizeof(uint64) * 2); i++, x <<= 4)
 90a:	0992                	slli	s3,s3,0x4
 90c:	397d                	addiw	s2,s2,-1
 90e:	fe0914e3          	bnez	s2,8f6 <vprintf+0x10c>
        printptr(fd, va_arg(ap, uint64));
 912:	8be2                	mv	s7,s8
      state = 0;
 914:	4981                	li	s3,0
 916:	6c02                	ld	s8,0(sp)
 918:	bf11                	j	82c <vprintf+0x42>
        s = va_arg(ap, char*);
 91a:	008b8993          	addi	s3,s7,8
 91e:	000bb903          	ld	s2,0(s7)
        if(s == 0)
 922:	02090163          	beqz	s2,944 <vprintf+0x15a>
        while(*s != 0){
 926:	00094583          	lbu	a1,0(s2)
 92a:	c9a5                	beqz	a1,99a <vprintf+0x1b0>
          putc(fd, *s);
 92c:	8556                	mv	a0,s5
 92e:	00000097          	auipc	ra,0x0
 932:	dee080e7          	jalr	-530(ra) # 71c <putc>
          s++;
 936:	0905                	addi	s2,s2,1
        while(*s != 0){
 938:	00094583          	lbu	a1,0(s2)
 93c:	f9e5                	bnez	a1,92c <vprintf+0x142>
        s = va_arg(ap, char*);
 93e:	8bce                	mv	s7,s3
      state = 0;
 940:	4981                	li	s3,0
 942:	b5ed                	j	82c <vprintf+0x42>
          s = "(null)";
 944:	00000917          	auipc	s2,0x0
 948:	4a490913          	addi	s2,s2,1188 # de8 <malloc+0x34c>
        while(*s != 0){
 94c:	02800593          	li	a1,40
 950:	bff1                	j	92c <vprintf+0x142>
        putc(fd, va_arg(ap, uint));
 952:	008b8913          	addi	s2,s7,8
 956:	000bc583          	lbu	a1,0(s7)
 95a:	8556                	mv	a0,s5
 95c:	00000097          	auipc	ra,0x0
 960:	dc0080e7          	jalr	-576(ra) # 71c <putc>
 964:	8bca                	mv	s7,s2
      state = 0;
 966:	4981                	li	s3,0
 968:	b5d1                	j	82c <vprintf+0x42>
        putc(fd, c);
 96a:	02500593          	li	a1,37
 96e:	8556                	mv	a0,s5
 970:	00000097          	auipc	ra,0x0
 974:	dac080e7          	jalr	-596(ra) # 71c <putc>
      state = 0;
 978:	4981                	li	s3,0
 97a:	bd4d                	j	82c <vprintf+0x42>
        putc(fd, '%');
 97c:	02500593          	li	a1,37
 980:	8556                	mv	a0,s5
 982:	00000097          	auipc	ra,0x0
 986:	d9a080e7          	jalr	-614(ra) # 71c <putc>
        putc(fd, c);
 98a:	85ca                	mv	a1,s2
 98c:	8556                	mv	a0,s5
 98e:	00000097          	auipc	ra,0x0
 992:	d8e080e7          	jalr	-626(ra) # 71c <putc>
      state = 0;
 996:	4981                	li	s3,0
 998:	bd51                	j	82c <vprintf+0x42>
        s = va_arg(ap, char*);
 99a:	8bce                	mv	s7,s3
      state = 0;
 99c:	4981                	li	s3,0
 99e:	b579                	j	82c <vprintf+0x42>
 9a0:	74e2                	ld	s1,56(sp)
 9a2:	79a2                	ld	s3,40(sp)
 9a4:	7a02                	ld	s4,32(sp)
 9a6:	6ae2                	ld	s5,24(sp)
 9a8:	6b42                	ld	s6,16(sp)
 9aa:	6ba2                	ld	s7,8(sp)
    }
  }
}
 9ac:	60a6                	ld	ra,72(sp)
 9ae:	6406                	ld	s0,64(sp)
 9b0:	7942                	ld	s2,48(sp)
 9b2:	6161                	addi	sp,sp,80
 9b4:	8082                	ret

00000000000009b6 <fprintf>:

void
fprintf(int fd, const char *fmt, ...)
{
 9b6:	715d                	addi	sp,sp,-80
 9b8:	ec06                	sd	ra,24(sp)
 9ba:	e822                	sd	s0,16(sp)
 9bc:	1000                	addi	s0,sp,32
 9be:	e010                	sd	a2,0(s0)
 9c0:	e414                	sd	a3,8(s0)
 9c2:	e818                	sd	a4,16(s0)
 9c4:	ec1c                	sd	a5,24(s0)
 9c6:	03043023          	sd	a6,32(s0)
 9ca:	03143423          	sd	a7,40(s0)
  va_list ap;

  va_start(ap, fmt);
 9ce:	fe843423          	sd	s0,-24(s0)
  vprintf(fd, fmt, ap);
 9d2:	8622                	mv	a2,s0
 9d4:	00000097          	auipc	ra,0x0
 9d8:	e16080e7          	jalr	-490(ra) # 7ea <vprintf>
}
 9dc:	60e2                	ld	ra,24(sp)
 9de:	6442                	ld	s0,16(sp)
 9e0:	6161                	addi	sp,sp,80
 9e2:	8082                	ret

00000000000009e4 <printf>:

void
printf(const char *fmt, ...)
{
 9e4:	711d                	addi	sp,sp,-96
 9e6:	ec06                	sd	ra,24(sp)
 9e8:	e822                	sd	s0,16(sp)
 9ea:	1000                	addi	s0,sp,32
 9ec:	e40c                	sd	a1,8(s0)
 9ee:	e810                	sd	a2,16(s0)
 9f0:	ec14                	sd	a3,24(s0)
 9f2:	f018                	sd	a4,32(s0)
 9f4:	f41c                	sd	a5,40(s0)
 9f6:	03043823          	sd	a6,48(s0)
 9fa:	03143c23          	sd	a7,56(s0)
  va_list ap;

  va_start(ap, fmt);
 9fe:	00840613          	addi	a2,s0,8
 a02:	fec43423          	sd	a2,-24(s0)
  vprintf(1, fmt, ap);
 a06:	85aa                	mv	a1,a0
 a08:	4505                	li	a0,1
 a0a:	00000097          	auipc	ra,0x0
 a0e:	de0080e7          	jalr	-544(ra) # 7ea <vprintf>
}
 a12:	60e2                	ld	ra,24(sp)
 a14:	6442                	ld	s0,16(sp)
 a16:	6125                	addi	sp,sp,96
 a18:	8082                	ret

0000000000000a1a <free>:
static Header base;
static Header *freep;

void
free(void *ap)
{
 a1a:	1141                	addi	sp,sp,-16
 a1c:	e422                	sd	s0,8(sp)
 a1e:	0800                	addi	s0,sp,16
  Header *bp, *p;

  bp = (Header*)ap - 1;
 a20:	ff050693          	addi	a3,a0,-16
  for(p = freep; !(bp > p && bp < p->s.ptr); p = p->s.ptr)
 a24:	00000797          	auipc	a5,0x0
 a28:	5dc7b783          	ld	a5,1500(a5) # 1000 <freep>
 a2c:	a02d                	j	a56 <free+0x3c>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
      break;
  if(bp + bp->s.size == p->s.ptr){
    bp->s.size += p->s.ptr->s.size;
 a2e:	4618                	lw	a4,8(a2)
 a30:	9f2d                	addw	a4,a4,a1
 a32:	fee52c23          	sw	a4,-8(a0)
    bp->s.ptr = p->s.ptr->s.ptr;
 a36:	6398                	ld	a4,0(a5)
 a38:	6310                	ld	a2,0(a4)
 a3a:	a83d                	j	a78 <free+0x5e>
  } else
    bp->s.ptr = p->s.ptr;
  if(p + p->s.size == bp){
    p->s.size += bp->s.size;
 a3c:	ff852703          	lw	a4,-8(a0)
 a40:	9f31                	addw	a4,a4,a2
 a42:	c798                	sw	a4,8(a5)
    p->s.ptr = bp->s.ptr;
 a44:	ff053683          	ld	a3,-16(a0)
 a48:	a091                	j	a8c <free+0x72>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
 a4a:	6398                	ld	a4,0(a5)
 a4c:	00e7e463          	bltu	a5,a4,a54 <free+0x3a>
 a50:	00e6ea63          	bltu	a3,a4,a64 <free+0x4a>
{
 a54:	87ba                	mv	a5,a4
  for(p = freep; !(bp > p && bp < p->s.ptr); p = p->s.ptr)
 a56:	fed7fae3          	bgeu	a5,a3,a4a <free+0x30>
 a5a:	6398                	ld	a4,0(a5)
 a5c:	00e6e463          	bltu	a3,a4,a64 <free+0x4a>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
 a60:	fee7eae3          	bltu	a5,a4,a54 <free+0x3a>
  if(bp + bp->s.size == p->s.ptr){
 a64:	ff852583          	lw	a1,-8(a0)
 a68:	6390                	ld	a2,0(a5)
 a6a:	02059813          	slli	a6,a1,0x20
 a6e:	01c85713          	srli	a4,a6,0x1c
 a72:	9736                	add	a4,a4,a3
 a74:	fae60de3          	beq	a2,a4,a2e <free+0x14>
    bp->s.ptr = p->s.ptr->s.ptr;
 a78:	fec53823          	sd	a2,-16(a0)
  if(p + p->s.size == bp){
 a7c:	4790                	lw	a2,8(a5)
 a7e:	02061593          	slli	a1,a2,0x20
 a82:	01c5d713          	srli	a4,a1,0x1c
 a86:	973e                	add	a4,a4,a5
 a88:	fae68ae3          	beq	a3,a4,a3c <free+0x22>
    p->s.ptr = bp->s.ptr;
 a8c:	e394                	sd	a3,0(a5)
  } else
    p->s.ptr = bp;
  freep = p;
 a8e:	00000717          	auipc	a4,0x0
 a92:	56f73923          	sd	a5,1394(a4) # 1000 <freep>
}
 a96:	6422                	ld	s0,8(sp)
 a98:	0141                	addi	sp,sp,16
 a9a:	8082                	ret

0000000000000a9c <malloc>:
  return freep;
}

void*
malloc(uint nbytes)
{
 a9c:	7139                	addi	sp,sp,-64
 a9e:	fc06                	sd	ra,56(sp)
 aa0:	f822                	sd	s0,48(sp)
 aa2:	f426                	sd	s1,40(sp)
 aa4:	ec4e                	sd	s3,24(sp)
 aa6:	0080                	addi	s0,sp,64
  Header *p, *prevp;
  uint nunits;

  nunits = (nbytes + sizeof(Header) - 1)/sizeof(Header) + 1;
 aa8:	02051493          	slli	s1,a0,0x20
 aac:	9081                	srli	s1,s1,0x20
 aae:	04bd                	addi	s1,s1,15
 ab0:	8091                	srli	s1,s1,0x4
 ab2:	0014899b          	addiw	s3,s1,1
 ab6:	0485                	addi	s1,s1,1
  if((prevp = freep) == 0){
 ab8:	00000517          	auipc	a0,0x0
 abc:	54853503          	ld	a0,1352(a0) # 1000 <freep>
 ac0:	c915                	beqz	a0,af4 <malloc+0x58>
    base.s.ptr = freep = prevp = &base;
    base.s.size = 0;
  }
  for(p = prevp->s.ptr; ; prevp = p, p = p->s.ptr){
 ac2:	611c                	ld	a5,0(a0)
    if(p->s.size >= nunits){
 ac4:	4798                	lw	a4,8(a5)
 ac6:	08977e63          	bgeu	a4,s1,b62 <malloc+0xc6>
 aca:	f04a                	sd	s2,32(sp)
 acc:	e852                	sd	s4,16(sp)
 ace:	e456                	sd	s5,8(sp)
 ad0:	e05a                	sd	s6,0(sp)
  if(nu < 4096)
 ad2:	8a4e                	mv	s4,s3
 ad4:	0009871b          	sext.w	a4,s3
 ad8:	6685                	lui	a3,0x1
 ada:	00d77363          	bgeu	a4,a3,ae0 <malloc+0x44>
 ade:	6a05                	lui	s4,0x1
 ae0:	000a0b1b          	sext.w	s6,s4
  p = sbrk(nu * sizeof(Header));
 ae4:	004a1a1b          	slliw	s4,s4,0x4
        p->s.size = nunits;
      }
      freep = prevp;
      return (void*)(p + 1);
    }
    if(p == freep)
 ae8:	00000917          	auipc	s2,0x0
 aec:	51890913          	addi	s2,s2,1304 # 1000 <freep>
  if(p == (char*)-1)
 af0:	5afd                	li	s5,-1
 af2:	a091                	j	b36 <malloc+0x9a>
 af4:	f04a                	sd	s2,32(sp)
 af6:	e852                	sd	s4,16(sp)
 af8:	e456                	sd	s5,8(sp)
 afa:	e05a                	sd	s6,0(sp)
    base.s.ptr = freep = prevp = &base;
 afc:	00000797          	auipc	a5,0x0
 b00:	51478793          	addi	a5,a5,1300 # 1010 <base>
 b04:	00000717          	auipc	a4,0x0
 b08:	4ef73e23          	sd	a5,1276(a4) # 1000 <freep>
 b0c:	e39c                	sd	a5,0(a5)
    base.s.size = 0;
 b0e:	0007a423          	sw	zero,8(a5)
    if(p->s.size >= nunits){
 b12:	b7c1                	j	ad2 <malloc+0x36>
        prevp->s.ptr = p->s.ptr;
 b14:	6398                	ld	a4,0(a5)
 b16:	e118                	sd	a4,0(a0)
 b18:	a08d                	j	b7a <malloc+0xde>
  hp->s.size = nu;
 b1a:	01652423          	sw	s6,8(a0)
  free((void*)(hp + 1));
 b1e:	0541                	addi	a0,a0,16
 b20:	00000097          	auipc	ra,0x0
 b24:	efa080e7          	jalr	-262(ra) # a1a <free>
  return freep;
 b28:	00093503          	ld	a0,0(s2)
      if((p = morecore(nunits)) == 0)
 b2c:	c13d                	beqz	a0,b92 <malloc+0xf6>
  for(p = prevp->s.ptr; ; prevp = p, p = p->s.ptr){
 b2e:	611c                	ld	a5,0(a0)
    if(p->s.size >= nunits){
 b30:	4798                	lw	a4,8(a5)
 b32:	02977463          	bgeu	a4,s1,b5a <malloc+0xbe>
    if(p == freep)
 b36:	00093703          	ld	a4,0(s2)
 b3a:	853e                	mv	a0,a5
 b3c:	fef719e3          	bne	a4,a5,b2e <malloc+0x92>
  p = sbrk(nu * sizeof(Header));
 b40:	8552                	mv	a0,s4
 b42:	00000097          	auipc	ra,0x0
 b46:	ba2080e7          	jalr	-1118(ra) # 6e4 <sbrk>
  if(p == (char*)-1)
 b4a:	fd5518e3          	bne	a0,s5,b1a <malloc+0x7e>
        return 0;
 b4e:	4501                	li	a0,0
 b50:	7902                	ld	s2,32(sp)
 b52:	6a42                	ld	s4,16(sp)
 b54:	6aa2                	ld	s5,8(sp)
 b56:	6b02                	ld	s6,0(sp)
 b58:	a03d                	j	b86 <malloc+0xea>
 b5a:	7902                	ld	s2,32(sp)
 b5c:	6a42                	ld	s4,16(sp)
 b5e:	6aa2                	ld	s5,8(sp)
 b60:	6b02                	ld	s6,0(sp)
      if(p->s.size == nunits)
 b62:	fae489e3          	beq	s1,a4,b14 <malloc+0x78>
        p->s.size -= nunits;
 b66:	4137073b          	subw	a4,a4,s3
 b6a:	c798                	sw	a4,8(a5)
        p += p->s.size;
 b6c:	02071693          	slli	a3,a4,0x20
 b70:	01c6d713          	srli	a4,a3,0x1c
 b74:	97ba                	add	a5,a5,a4
        p->s.size = nunits;
 b76:	0137a423          	sw	s3,8(a5)
      freep = prevp;
 b7a:	00000717          	auipc	a4,0x0
 b7e:	48a73323          	sd	a0,1158(a4) # 1000 <freep>
      return (void*)(p + 1);
 b82:	01078513          	addi	a0,a5,16
  }
}
 b86:	70e2                	ld	ra,56(sp)
 b88:	7442                	ld	s0,48(sp)
 b8a:	74a2                	ld	s1,40(sp)
 b8c:	69e2                	ld	s3,24(sp)
 b8e:	6121                	addi	sp,sp,64
 b90:	8082                	ret
 b92:	7902                	ld	s2,32(sp)
 b94:	6a42                	ld	s4,16(sp)
 b96:	6aa2                	ld	s5,8(sp)
 b98:	6b02                	ld	s6,0(sp)
 b9a:	b7f5                	j	b86 <malloc+0xea>
