
user/_cowtest3:     file format elf64-littleriscv


Disassembly of section .text:

0000000000000000 <readonly_test>:
#include "kernel/memlayout.h"

#define PGSIZE 4096
#define NUM_PAGES 10

void readonly_test() {
   0:	7139                	addi	sp,sp,-64
   2:	fc06                	sd	ra,56(sp)
   4:	f822                	sd	s0,48(sp)
   6:	0080                	addi	s0,sp,64
    printf("Running Read-Only Test\n");
   8:	00001517          	auipc	a0,0x1
   c:	aa850513          	addi	a0,a0,-1368 # ab0 <malloc+0x10e>
  10:	00001097          	auipc	ra,0x1
  14:	8da080e7          	jalr	-1830(ra) # 8ea <printf>

    int pid = fork();
  18:	00000097          	auipc	ra,0x0
  1c:	542080e7          	jalr	1346(ra) # 55a <fork>
    if (pid < 0) {
  20:	04054f63          	bltz	a0,7e <readonly_test+0x7e>
  24:	f426                	sd	s1,40(sp)
  26:	84aa                	mv	s1,a0
        printf("Fork failed\n");
        return;
    } else if (pid == 0) {
  28:	ed51                	bnez	a0,c4 <readonly_test+0xc4>
  2a:	f04a                	sd	s2,32(sp)
  2c:	ec4e                	sd	s3,24(sp)
  2e:	e852                	sd	s4,16(sp)
        // Child process: read from multiple pages of allocated memory without modifying
        for (int i = 0; i < NUM_PAGES; i++) {
            char *mem = sbrk(PGSIZE);
            if (mem == (char *)-1) {
  30:	597d                	li	s2,-1
                printf("sbrk failed\n");
                return;
            }
            // Read the memory to ensure no COW is triggered
            volatile char value = mem[0];
            printf("Child read value from page %d: %d\n", i, value);
  32:	00001a17          	auipc	s4,0x1
  36:	abea0a13          	addi	s4,s4,-1346 # af0 <malloc+0x14e>
        for (int i = 0; i < NUM_PAGES; i++) {
  3a:	49a9                	li	s3,10
            char *mem = sbrk(PGSIZE);
  3c:	6505                	lui	a0,0x1
  3e:	00000097          	auipc	ra,0x0
  42:	5ac080e7          	jalr	1452(ra) # 5ea <sbrk>
            if (mem == (char *)-1) {
  46:	05250563          	beq	a0,s2,90 <readonly_test+0x90>
            volatile char value = mem[0];
  4a:	00054783          	lbu	a5,0(a0) # 1000 <freep>
  4e:	fcf407a3          	sb	a5,-49(s0)
            printf("Child read value from page %d: %d\n", i, value);
  52:	fcf44603          	lbu	a2,-49(s0)
  56:	85a6                	mv	a1,s1
  58:	8552                	mv	a0,s4
  5a:	00001097          	auipc	ra,0x1
  5e:	890080e7          	jalr	-1904(ra) # 8ea <printf>
        for (int i = 0; i < NUM_PAGES; i++) {
  62:	2485                	addiw	s1,s1,1
  64:	fd349ce3          	bne	s1,s3,3c <readonly_test+0x3c>
        }
        // Retrieve and print the fault counts for this process
        if (get_fault_counts() < 0) {
  68:	00000097          	auipc	ra,0x0
  6c:	5a2080e7          	jalr	1442(ra) # 60a <get_fault_counts>
  70:	02054d63          	bltz	a0,aa <readonly_test+0xaa>
  74:	74a2                	ld	s1,40(sp)
  76:	7902                	ld	s2,32(sp)
  78:	69e2                	ld	s3,24(sp)
  7a:	6a42                	ld	s4,16(sp)
  7c:	a891                	j	d0 <readonly_test+0xd0>
        printf("Fork failed\n");
  7e:	00001517          	auipc	a0,0x1
  82:	a4a50513          	addi	a0,a0,-1462 # ac8 <malloc+0x126>
  86:	00001097          	auipc	ra,0x1
  8a:	864080e7          	jalr	-1948(ra) # 8ea <printf>
        return;
  8e:	a089                	j	d0 <readonly_test+0xd0>
                printf("sbrk failed\n");
  90:	00001517          	auipc	a0,0x1
  94:	a5050513          	addi	a0,a0,-1456 # ae0 <malloc+0x13e>
  98:	00001097          	auipc	ra,0x1
  9c:	852080e7          	jalr	-1966(ra) # 8ea <printf>
                return;
  a0:	74a2                	ld	s1,40(sp)
  a2:	7902                	ld	s2,32(sp)
  a4:	69e2                	ld	s3,24(sp)
  a6:	6a42                	ld	s4,16(sp)
  a8:	a025                	j	d0 <readonly_test+0xd0>
            printf("Failed to get fault counts\n");
  aa:	00001517          	auipc	a0,0x1
  ae:	a6e50513          	addi	a0,a0,-1426 # b18 <malloc+0x176>
  b2:	00001097          	auipc	ra,0x1
  b6:	838080e7          	jalr	-1992(ra) # 8ea <printf>
  ba:	74a2                	ld	s1,40(sp)
  bc:	7902                	ld	s2,32(sp)
  be:	69e2                	ld	s3,24(sp)
  c0:	6a42                	ld	s4,16(sp)
  c2:	a039                	j	d0 <readonly_test+0xd0>
        }
        return;
    } else {
        // Parent process: wait for the child to complete
        wait((int *)0);
  c4:	4501                	li	a0,0
  c6:	00000097          	auipc	ra,0x0
  ca:	4a4080e7          	jalr	1188(ra) # 56a <wait>
  ce:	74a2                	ld	s1,40(sp)
    }
}
  d0:	70e2                	ld	ra,56(sp)
  d2:	7442                	ld	s0,48(sp)
  d4:	6121                	addi	sp,sp,64
  d6:	8082                	ret

00000000000000d8 <write_test>:

void write_test() {
  d8:	7179                	addi	sp,sp,-48
  da:	f406                	sd	ra,40(sp)
  dc:	f022                	sd	s0,32(sp)
  de:	1800                	addi	s0,sp,48
    printf("Running Write Test\n");
  e0:	00001517          	auipc	a0,0x1
  e4:	a5850513          	addi	a0,a0,-1448 # b38 <malloc+0x196>
  e8:	00001097          	auipc	ra,0x1
  ec:	802080e7          	jalr	-2046(ra) # 8ea <printf>

    int pid = fork();
  f0:	00000097          	auipc	ra,0x0
  f4:	46a080e7          	jalr	1130(ra) # 55a <fork>
    if (pid < 0) {
  f8:	04054d63          	bltz	a0,152 <write_test+0x7a>
  fc:	ec26                	sd	s1,24(sp)
  fe:	84aa                	mv	s1,a0
        printf("Fork failed\n");
        return;
    } else if (pid == 0) {
 100:	ed41                	bnez	a0,198 <write_test+0xc0>
 102:	e84a                	sd	s2,16(sp)
 104:	e44e                	sd	s3,8(sp)
 106:	e052                	sd	s4,0(sp)
        // Child process: write to multiple pages of allocated memory to trigger COW
        for (int i = 0; i < NUM_PAGES; i++) {
            char *mem = sbrk(PGSIZE);
            if (mem == (char *)-1) {
 108:	597d                	li	s2,-1
                printf("sbrk failed\n");
                return;
            }
            // Write to the memory to trigger COW
            mem[0] = 'A' + i;
            printf("Child wrote to memory on page %d\n", i);
 10a:	00001a17          	auipc	s4,0x1
 10e:	a46a0a13          	addi	s4,s4,-1466 # b50 <malloc+0x1ae>
        for (int i = 0; i < NUM_PAGES; i++) {
 112:	49a9                	li	s3,10
            char *mem = sbrk(PGSIZE);
 114:	6505                	lui	a0,0x1
 116:	00000097          	auipc	ra,0x0
 11a:	4d4080e7          	jalr	1236(ra) # 5ea <sbrk>
            if (mem == (char *)-1) {
 11e:	05250363          	beq	a0,s2,164 <write_test+0x8c>
            mem[0] = 'A' + i;
 122:	0414879b          	addiw	a5,s1,65
 126:	00f50023          	sb	a5,0(a0) # 1000 <freep>
            printf("Child wrote to memory on page %d\n", i);
 12a:	85a6                	mv	a1,s1
 12c:	8552                	mv	a0,s4
 12e:	00000097          	auipc	ra,0x0
 132:	7bc080e7          	jalr	1980(ra) # 8ea <printf>
        for (int i = 0; i < NUM_PAGES; i++) {
 136:	2485                	addiw	s1,s1,1
 138:	fd349ee3          	bne	s1,s3,114 <write_test+0x3c>
        }
        // Retrieve and print the fault counts for this process
        if (get_fault_counts() < 0) {
 13c:	00000097          	auipc	ra,0x0
 140:	4ce080e7          	jalr	1230(ra) # 60a <get_fault_counts>
 144:	02054d63          	bltz	a0,17e <write_test+0xa6>
 148:	64e2                	ld	s1,24(sp)
 14a:	6942                	ld	s2,16(sp)
 14c:	69a2                	ld	s3,8(sp)
 14e:	6a02                	ld	s4,0(sp)
 150:	a891                	j	1a4 <write_test+0xcc>
        printf("Fork failed\n");
 152:	00001517          	auipc	a0,0x1
 156:	97650513          	addi	a0,a0,-1674 # ac8 <malloc+0x126>
 15a:	00000097          	auipc	ra,0x0
 15e:	790080e7          	jalr	1936(ra) # 8ea <printf>
        return;
 162:	a089                	j	1a4 <write_test+0xcc>
                printf("sbrk failed\n");
 164:	00001517          	auipc	a0,0x1
 168:	97c50513          	addi	a0,a0,-1668 # ae0 <malloc+0x13e>
 16c:	00000097          	auipc	ra,0x0
 170:	77e080e7          	jalr	1918(ra) # 8ea <printf>
                return;
 174:	64e2                	ld	s1,24(sp)
 176:	6942                	ld	s2,16(sp)
 178:	69a2                	ld	s3,8(sp)
 17a:	6a02                	ld	s4,0(sp)
 17c:	a025                	j	1a4 <write_test+0xcc>
            printf("Failed to get fault counts\n");
 17e:	00001517          	auipc	a0,0x1
 182:	99a50513          	addi	a0,a0,-1638 # b18 <malloc+0x176>
 186:	00000097          	auipc	ra,0x0
 18a:	764080e7          	jalr	1892(ra) # 8ea <printf>
 18e:	64e2                	ld	s1,24(sp)
 190:	6942                	ld	s2,16(sp)
 192:	69a2                	ld	s3,8(sp)
 194:	6a02                	ld	s4,0(sp)
 196:	a039                	j	1a4 <write_test+0xcc>
        }
        return;
    } else {
        // Parent process: wait for the child to complete
        wait((int *)0);
 198:	4501                	li	a0,0
 19a:	00000097          	auipc	ra,0x0
 19e:	3d0080e7          	jalr	976(ra) # 56a <wait>
 1a2:	64e2                	ld	s1,24(sp)
    }
}
 1a4:	70a2                	ld	ra,40(sp)
 1a6:	7402                	ld	s0,32(sp)
 1a8:	6145                	addi	sp,sp,48
 1aa:	8082                	ret

00000000000001ac <mixed_test>:

void mixed_test() {
 1ac:	715d                	addi	sp,sp,-80
 1ae:	e486                	sd	ra,72(sp)
 1b0:	e0a2                	sd	s0,64(sp)
 1b2:	0880                	addi	s0,sp,80
    printf("Running Mixed Read/Write Test\n");
 1b4:	00001517          	auipc	a0,0x1
 1b8:	9c450513          	addi	a0,a0,-1596 # b78 <malloc+0x1d6>
 1bc:	00000097          	auipc	ra,0x0
 1c0:	72e080e7          	jalr	1838(ra) # 8ea <printf>

    int pid = fork();
 1c4:	00000097          	auipc	ra,0x0
 1c8:	396080e7          	jalr	918(ra) # 55a <fork>
    if (pid < 0) {
 1cc:	02054463          	bltz	a0,1f4 <mixed_test+0x48>
 1d0:	fc26                	sd	s1,56(sp)
 1d2:	84aa                	mv	s1,a0
        printf("Fork failed\n");
        return;
    } else if (pid == 0) {
 1d4:	e569                	bnez	a0,29e <mixed_test+0xf2>
 1d6:	f84a                	sd	s2,48(sp)
 1d8:	f44e                	sd	s3,40(sp)
 1da:	f052                	sd	s4,32(sp)
 1dc:	ec56                	sd	s5,24(sp)
        // Child process: alternate between reading and writing to pages
        for (int i = 0; i < NUM_PAGES; i++) {
            char *mem = sbrk(PGSIZE);
            if (mem == (char *)-1) {
 1de:	597d                	li	s2,-1
                volatile char value = mem[0];
                printf("Child read value from page %d: %d\n", i, value);
            } else {
                // Write to the page
                mem[0] = 'A' + i;
                printf("Child wrote to memory on page %d\n", i);
 1e0:	00001a97          	auipc	s5,0x1
 1e4:	970a8a93          	addi	s5,s5,-1680 # b50 <malloc+0x1ae>
                printf("Child read value from page %d: %d\n", i, value);
 1e8:	00001a17          	auipc	s4,0x1
 1ec:	908a0a13          	addi	s4,s4,-1784 # af0 <malloc+0x14e>
        for (int i = 0; i < NUM_PAGES; i++) {
 1f0:	49a9                	li	s3,10
 1f2:	a0a9                	j	23c <mixed_test+0x90>
        printf("Fork failed\n");
 1f4:	00001517          	auipc	a0,0x1
 1f8:	8d450513          	addi	a0,a0,-1836 # ac8 <malloc+0x126>
 1fc:	00000097          	auipc	ra,0x0
 200:	6ee080e7          	jalr	1774(ra) # 8ea <printf>
        return;
 204:	a05d                	j	2aa <mixed_test+0xfe>
                printf("sbrk failed\n");
 206:	00001517          	auipc	a0,0x1
 20a:	8da50513          	addi	a0,a0,-1830 # ae0 <malloc+0x13e>
 20e:	00000097          	auipc	ra,0x0
 212:	6dc080e7          	jalr	1756(ra) # 8ea <printf>
                return;
 216:	74e2                	ld	s1,56(sp)
 218:	7942                	ld	s2,48(sp)
 21a:	79a2                	ld	s3,40(sp)
 21c:	7a02                	ld	s4,32(sp)
 21e:	6ae2                	ld	s5,24(sp)
 220:	a069                	j	2aa <mixed_test+0xfe>
                mem[0] = 'A' + i;
 222:	0414879b          	addiw	a5,s1,65
 226:	00f50023          	sb	a5,0(a0)
                printf("Child wrote to memory on page %d\n", i);
 22a:	85a6                	mv	a1,s1
 22c:	8556                	mv	a0,s5
 22e:	00000097          	auipc	ra,0x0
 232:	6bc080e7          	jalr	1724(ra) # 8ea <printf>
        for (int i = 0; i < NUM_PAGES; i++) {
 236:	2485                	addiw	s1,s1,1
 238:	03348963          	beq	s1,s3,26a <mixed_test+0xbe>
            char *mem = sbrk(PGSIZE);
 23c:	6505                	lui	a0,0x1
 23e:	00000097          	auipc	ra,0x0
 242:	3ac080e7          	jalr	940(ra) # 5ea <sbrk>
            if (mem == (char *)-1) {
 246:	fd2500e3          	beq	a0,s2,206 <mixed_test+0x5a>
            if (i % 2 == 0) {
 24a:	0014f793          	andi	a5,s1,1
 24e:	fbf1                	bnez	a5,222 <mixed_test+0x76>
                volatile char value = mem[0];
 250:	00054783          	lbu	a5,0(a0) # 1000 <freep>
 254:	faf40fa3          	sb	a5,-65(s0)
                printf("Child read value from page %d: %d\n", i, value);
 258:	fbf44603          	lbu	a2,-65(s0)
 25c:	85a6                	mv	a1,s1
 25e:	8552                	mv	a0,s4
 260:	00000097          	auipc	ra,0x0
 264:	68a080e7          	jalr	1674(ra) # 8ea <printf>
 268:	b7f9                	j	236 <mixed_test+0x8a>
            }
        }
        // Retrieve and print the fault counts for this process
        if (get_fault_counts() < 0) {
 26a:	00000097          	auipc	ra,0x0
 26e:	3a0080e7          	jalr	928(ra) # 60a <get_fault_counts>
 272:	00054863          	bltz	a0,282 <mixed_test+0xd6>
 276:	74e2                	ld	s1,56(sp)
 278:	7942                	ld	s2,48(sp)
 27a:	79a2                	ld	s3,40(sp)
 27c:	7a02                	ld	s4,32(sp)
 27e:	6ae2                	ld	s5,24(sp)
 280:	a02d                	j	2aa <mixed_test+0xfe>
            printf("Failed to get fault counts\n");
 282:	00001517          	auipc	a0,0x1
 286:	89650513          	addi	a0,a0,-1898 # b18 <malloc+0x176>
 28a:	00000097          	auipc	ra,0x0
 28e:	660080e7          	jalr	1632(ra) # 8ea <printf>
 292:	74e2                	ld	s1,56(sp)
 294:	7942                	ld	s2,48(sp)
 296:	79a2                	ld	s3,40(sp)
 298:	7a02                	ld	s4,32(sp)
 29a:	6ae2                	ld	s5,24(sp)
 29c:	a039                	j	2aa <mixed_test+0xfe>
        }
        return;
    } else {
        // Parent process: wait for the child to complete
        wait((int *)0);
 29e:	4501                	li	a0,0
 2a0:	00000097          	auipc	ra,0x0
 2a4:	2ca080e7          	jalr	714(ra) # 56a <wait>
 2a8:	74e2                	ld	s1,56(sp)
    }
}
 2aa:	60a6                	ld	ra,72(sp)
 2ac:	6406                	ld	s0,64(sp)
 2ae:	6161                	addi	sp,sp,80
 2b0:	8082                	ret

00000000000002b2 <main>:

int main(void) {
 2b2:	1141                	addi	sp,sp,-16
 2b4:	e406                	sd	ra,8(sp)
 2b6:	e022                	sd	s0,0(sp)
 2b8:	0800                	addi	s0,sp,16
    // Run the read-only test
    readonly_test();
 2ba:	00000097          	auipc	ra,0x0
 2be:	d46080e7          	jalr	-698(ra) # 0 <readonly_test>

    // Run the write test
    write_test();
 2c2:	00000097          	auipc	ra,0x0
 2c6:	e16080e7          	jalr	-490(ra) # d8 <write_test>

    // Run the mixed read/write test
    mixed_test();
 2ca:	00000097          	auipc	ra,0x0
 2ce:	ee2080e7          	jalr	-286(ra) # 1ac <mixed_test>

    return 0;
}
 2d2:	4501                	li	a0,0
 2d4:	60a2                	ld	ra,8(sp)
 2d6:	6402                	ld	s0,0(sp)
 2d8:	0141                	addi	sp,sp,16
 2da:	8082                	ret

00000000000002dc <_main>:
//
// wrapper so that it's OK if main() does not call exit().
//
void
_main()
{
 2dc:	1141                	addi	sp,sp,-16
 2de:	e406                	sd	ra,8(sp)
 2e0:	e022                	sd	s0,0(sp)
 2e2:	0800                	addi	s0,sp,16
  extern int main();
  main();
 2e4:	00000097          	auipc	ra,0x0
 2e8:	fce080e7          	jalr	-50(ra) # 2b2 <main>
  exit(0);
 2ec:	4501                	li	a0,0
 2ee:	00000097          	auipc	ra,0x0
 2f2:	274080e7          	jalr	628(ra) # 562 <exit>

00000000000002f6 <strcpy>:
}

char*
strcpy(char *s, const char *t)
{
 2f6:	1141                	addi	sp,sp,-16
 2f8:	e422                	sd	s0,8(sp)
 2fa:	0800                	addi	s0,sp,16
  char *os;

  os = s;
  while((*s++ = *t++) != 0)
 2fc:	87aa                	mv	a5,a0
 2fe:	0585                	addi	a1,a1,1
 300:	0785                	addi	a5,a5,1
 302:	fff5c703          	lbu	a4,-1(a1)
 306:	fee78fa3          	sb	a4,-1(a5)
 30a:	fb75                	bnez	a4,2fe <strcpy+0x8>
    ;
  return os;
}
 30c:	6422                	ld	s0,8(sp)
 30e:	0141                	addi	sp,sp,16
 310:	8082                	ret

0000000000000312 <strcmp>:

int
strcmp(const char *p, const char *q)
{
 312:	1141                	addi	sp,sp,-16
 314:	e422                	sd	s0,8(sp)
 316:	0800                	addi	s0,sp,16
  while(*p && *p == *q)
 318:	00054783          	lbu	a5,0(a0)
 31c:	cb91                	beqz	a5,330 <strcmp+0x1e>
 31e:	0005c703          	lbu	a4,0(a1)
 322:	00f71763          	bne	a4,a5,330 <strcmp+0x1e>
    p++, q++;
 326:	0505                	addi	a0,a0,1
 328:	0585                	addi	a1,a1,1
  while(*p && *p == *q)
 32a:	00054783          	lbu	a5,0(a0)
 32e:	fbe5                	bnez	a5,31e <strcmp+0xc>
  return (uchar)*p - (uchar)*q;
 330:	0005c503          	lbu	a0,0(a1)
}
 334:	40a7853b          	subw	a0,a5,a0
 338:	6422                	ld	s0,8(sp)
 33a:	0141                	addi	sp,sp,16
 33c:	8082                	ret

000000000000033e <strlen>:

uint
strlen(const char *s)
{
 33e:	1141                	addi	sp,sp,-16
 340:	e422                	sd	s0,8(sp)
 342:	0800                	addi	s0,sp,16
  int n;

  for(n = 0; s[n]; n++)
 344:	00054783          	lbu	a5,0(a0)
 348:	cf91                	beqz	a5,364 <strlen+0x26>
 34a:	0505                	addi	a0,a0,1
 34c:	87aa                	mv	a5,a0
 34e:	86be                	mv	a3,a5
 350:	0785                	addi	a5,a5,1
 352:	fff7c703          	lbu	a4,-1(a5)
 356:	ff65                	bnez	a4,34e <strlen+0x10>
 358:	40a6853b          	subw	a0,a3,a0
 35c:	2505                	addiw	a0,a0,1
    ;
  return n;
}
 35e:	6422                	ld	s0,8(sp)
 360:	0141                	addi	sp,sp,16
 362:	8082                	ret
  for(n = 0; s[n]; n++)
 364:	4501                	li	a0,0
 366:	bfe5                	j	35e <strlen+0x20>

0000000000000368 <memset>:

void*
memset(void *dst, int c, uint n)
{
 368:	1141                	addi	sp,sp,-16
 36a:	e422                	sd	s0,8(sp)
 36c:	0800                	addi	s0,sp,16
  char *cdst = (char *) dst;
  int i;
  for(i = 0; i < n; i++){
 36e:	ca19                	beqz	a2,384 <memset+0x1c>
 370:	87aa                	mv	a5,a0
 372:	1602                	slli	a2,a2,0x20
 374:	9201                	srli	a2,a2,0x20
 376:	00a60733          	add	a4,a2,a0
    cdst[i] = c;
 37a:	00b78023          	sb	a1,0(a5)
  for(i = 0; i < n; i++){
 37e:	0785                	addi	a5,a5,1
 380:	fee79de3          	bne	a5,a4,37a <memset+0x12>
  }
  return dst;
}
 384:	6422                	ld	s0,8(sp)
 386:	0141                	addi	sp,sp,16
 388:	8082                	ret

000000000000038a <strchr>:

char*
strchr(const char *s, char c)
{
 38a:	1141                	addi	sp,sp,-16
 38c:	e422                	sd	s0,8(sp)
 38e:	0800                	addi	s0,sp,16
  for(; *s; s++)
 390:	00054783          	lbu	a5,0(a0)
 394:	cb99                	beqz	a5,3aa <strchr+0x20>
    if(*s == c)
 396:	00f58763          	beq	a1,a5,3a4 <strchr+0x1a>
  for(; *s; s++)
 39a:	0505                	addi	a0,a0,1
 39c:	00054783          	lbu	a5,0(a0)
 3a0:	fbfd                	bnez	a5,396 <strchr+0xc>
      return (char*)s;
  return 0;
 3a2:	4501                	li	a0,0
}
 3a4:	6422                	ld	s0,8(sp)
 3a6:	0141                	addi	sp,sp,16
 3a8:	8082                	ret
  return 0;
 3aa:	4501                	li	a0,0
 3ac:	bfe5                	j	3a4 <strchr+0x1a>

00000000000003ae <gets>:

char*
gets(char *buf, int max)
{
 3ae:	711d                	addi	sp,sp,-96
 3b0:	ec86                	sd	ra,88(sp)
 3b2:	e8a2                	sd	s0,80(sp)
 3b4:	e4a6                	sd	s1,72(sp)
 3b6:	e0ca                	sd	s2,64(sp)
 3b8:	fc4e                	sd	s3,56(sp)
 3ba:	f852                	sd	s4,48(sp)
 3bc:	f456                	sd	s5,40(sp)
 3be:	f05a                	sd	s6,32(sp)
 3c0:	ec5e                	sd	s7,24(sp)
 3c2:	1080                	addi	s0,sp,96
 3c4:	8baa                	mv	s7,a0
 3c6:	8a2e                	mv	s4,a1
  int i, cc;
  char c;

  for(i=0; i+1 < max; ){
 3c8:	892a                	mv	s2,a0
 3ca:	4481                	li	s1,0
    cc = read(0, &c, 1);
    if(cc < 1)
      break;
    buf[i++] = c;
    if(c == '\n' || c == '\r')
 3cc:	4aa9                	li	s5,10
 3ce:	4b35                	li	s6,13
  for(i=0; i+1 < max; ){
 3d0:	89a6                	mv	s3,s1
 3d2:	2485                	addiw	s1,s1,1
 3d4:	0344d863          	bge	s1,s4,404 <gets+0x56>
    cc = read(0, &c, 1);
 3d8:	4605                	li	a2,1
 3da:	faf40593          	addi	a1,s0,-81
 3de:	4501                	li	a0,0
 3e0:	00000097          	auipc	ra,0x0
 3e4:	19a080e7          	jalr	410(ra) # 57a <read>
    if(cc < 1)
 3e8:	00a05e63          	blez	a0,404 <gets+0x56>
    buf[i++] = c;
 3ec:	faf44783          	lbu	a5,-81(s0)
 3f0:	00f90023          	sb	a5,0(s2)
    if(c == '\n' || c == '\r')
 3f4:	01578763          	beq	a5,s5,402 <gets+0x54>
 3f8:	0905                	addi	s2,s2,1
 3fa:	fd679be3          	bne	a5,s6,3d0 <gets+0x22>
    buf[i++] = c;
 3fe:	89a6                	mv	s3,s1
 400:	a011                	j	404 <gets+0x56>
 402:	89a6                	mv	s3,s1
      break;
  }
  buf[i] = '\0';
 404:	99de                	add	s3,s3,s7
 406:	00098023          	sb	zero,0(s3)
  return buf;
}
 40a:	855e                	mv	a0,s7
 40c:	60e6                	ld	ra,88(sp)
 40e:	6446                	ld	s0,80(sp)
 410:	64a6                	ld	s1,72(sp)
 412:	6906                	ld	s2,64(sp)
 414:	79e2                	ld	s3,56(sp)
 416:	7a42                	ld	s4,48(sp)
 418:	7aa2                	ld	s5,40(sp)
 41a:	7b02                	ld	s6,32(sp)
 41c:	6be2                	ld	s7,24(sp)
 41e:	6125                	addi	sp,sp,96
 420:	8082                	ret

0000000000000422 <stat>:

int
stat(const char *n, struct stat *st)
{
 422:	1101                	addi	sp,sp,-32
 424:	ec06                	sd	ra,24(sp)
 426:	e822                	sd	s0,16(sp)
 428:	e04a                	sd	s2,0(sp)
 42a:	1000                	addi	s0,sp,32
 42c:	892e                	mv	s2,a1
  int fd;
  int r;

  fd = open(n, O_RDONLY);
 42e:	4581                	li	a1,0
 430:	00000097          	auipc	ra,0x0
 434:	172080e7          	jalr	370(ra) # 5a2 <open>
  if(fd < 0)
 438:	02054663          	bltz	a0,464 <stat+0x42>
 43c:	e426                	sd	s1,8(sp)
 43e:	84aa                	mv	s1,a0
    return -1;
  r = fstat(fd, st);
 440:	85ca                	mv	a1,s2
 442:	00000097          	auipc	ra,0x0
 446:	178080e7          	jalr	376(ra) # 5ba <fstat>
 44a:	892a                	mv	s2,a0
  close(fd);
 44c:	8526                	mv	a0,s1
 44e:	00000097          	auipc	ra,0x0
 452:	13c080e7          	jalr	316(ra) # 58a <close>
  return r;
 456:	64a2                	ld	s1,8(sp)
}
 458:	854a                	mv	a0,s2
 45a:	60e2                	ld	ra,24(sp)
 45c:	6442                	ld	s0,16(sp)
 45e:	6902                	ld	s2,0(sp)
 460:	6105                	addi	sp,sp,32
 462:	8082                	ret
    return -1;
 464:	597d                	li	s2,-1
 466:	bfcd                	j	458 <stat+0x36>

0000000000000468 <atoi>:

int
atoi(const char *s)
{
 468:	1141                	addi	sp,sp,-16
 46a:	e422                	sd	s0,8(sp)
 46c:	0800                	addi	s0,sp,16
  int n;

  n = 0;
  while('0' <= *s && *s <= '9')
 46e:	00054683          	lbu	a3,0(a0)
 472:	fd06879b          	addiw	a5,a3,-48
 476:	0ff7f793          	zext.b	a5,a5
 47a:	4625                	li	a2,9
 47c:	02f66863          	bltu	a2,a5,4ac <atoi+0x44>
 480:	872a                	mv	a4,a0
  n = 0;
 482:	4501                	li	a0,0
    n = n*10 + *s++ - '0';
 484:	0705                	addi	a4,a4,1
 486:	0025179b          	slliw	a5,a0,0x2
 48a:	9fa9                	addw	a5,a5,a0
 48c:	0017979b          	slliw	a5,a5,0x1
 490:	9fb5                	addw	a5,a5,a3
 492:	fd07851b          	addiw	a0,a5,-48
  while('0' <= *s && *s <= '9')
 496:	00074683          	lbu	a3,0(a4)
 49a:	fd06879b          	addiw	a5,a3,-48
 49e:	0ff7f793          	zext.b	a5,a5
 4a2:	fef671e3          	bgeu	a2,a5,484 <atoi+0x1c>
  return n;
}
 4a6:	6422                	ld	s0,8(sp)
 4a8:	0141                	addi	sp,sp,16
 4aa:	8082                	ret
  n = 0;
 4ac:	4501                	li	a0,0
 4ae:	bfe5                	j	4a6 <atoi+0x3e>

00000000000004b0 <memmove>:

void*
memmove(void *vdst, const void *vsrc, int n)
{
 4b0:	1141                	addi	sp,sp,-16
 4b2:	e422                	sd	s0,8(sp)
 4b4:	0800                	addi	s0,sp,16
  char *dst;
  const char *src;

  dst = vdst;
  src = vsrc;
  if (src > dst) {
 4b6:	02b57463          	bgeu	a0,a1,4de <memmove+0x2e>
    while(n-- > 0)
 4ba:	00c05f63          	blez	a2,4d8 <memmove+0x28>
 4be:	1602                	slli	a2,a2,0x20
 4c0:	9201                	srli	a2,a2,0x20
 4c2:	00c507b3          	add	a5,a0,a2
  dst = vdst;
 4c6:	872a                	mv	a4,a0
      *dst++ = *src++;
 4c8:	0585                	addi	a1,a1,1
 4ca:	0705                	addi	a4,a4,1
 4cc:	fff5c683          	lbu	a3,-1(a1)
 4d0:	fed70fa3          	sb	a3,-1(a4)
    while(n-- > 0)
 4d4:	fef71ae3          	bne	a4,a5,4c8 <memmove+0x18>
    src += n;
    while(n-- > 0)
      *--dst = *--src;
  }
  return vdst;
}
 4d8:	6422                	ld	s0,8(sp)
 4da:	0141                	addi	sp,sp,16
 4dc:	8082                	ret
    dst += n;
 4de:	00c50733          	add	a4,a0,a2
    src += n;
 4e2:	95b2                	add	a1,a1,a2
    while(n-- > 0)
 4e4:	fec05ae3          	blez	a2,4d8 <memmove+0x28>
 4e8:	fff6079b          	addiw	a5,a2,-1
 4ec:	1782                	slli	a5,a5,0x20
 4ee:	9381                	srli	a5,a5,0x20
 4f0:	fff7c793          	not	a5,a5
 4f4:	97ba                	add	a5,a5,a4
      *--dst = *--src;
 4f6:	15fd                	addi	a1,a1,-1
 4f8:	177d                	addi	a4,a4,-1
 4fa:	0005c683          	lbu	a3,0(a1)
 4fe:	00d70023          	sb	a3,0(a4)
    while(n-- > 0)
 502:	fee79ae3          	bne	a5,a4,4f6 <memmove+0x46>
 506:	bfc9                	j	4d8 <memmove+0x28>

0000000000000508 <memcmp>:

int
memcmp(const void *s1, const void *s2, uint n)
{
 508:	1141                	addi	sp,sp,-16
 50a:	e422                	sd	s0,8(sp)
 50c:	0800                	addi	s0,sp,16
  const char *p1 = s1, *p2 = s2;
  while (n-- > 0) {
 50e:	ca05                	beqz	a2,53e <memcmp+0x36>
 510:	fff6069b          	addiw	a3,a2,-1
 514:	1682                	slli	a3,a3,0x20
 516:	9281                	srli	a3,a3,0x20
 518:	0685                	addi	a3,a3,1
 51a:	96aa                	add	a3,a3,a0
    if (*p1 != *p2) {
 51c:	00054783          	lbu	a5,0(a0)
 520:	0005c703          	lbu	a4,0(a1)
 524:	00e79863          	bne	a5,a4,534 <memcmp+0x2c>
      return *p1 - *p2;
    }
    p1++;
 528:	0505                	addi	a0,a0,1
    p2++;
 52a:	0585                	addi	a1,a1,1
  while (n-- > 0) {
 52c:	fed518e3          	bne	a0,a3,51c <memcmp+0x14>
  }
  return 0;
 530:	4501                	li	a0,0
 532:	a019                	j	538 <memcmp+0x30>
      return *p1 - *p2;
 534:	40e7853b          	subw	a0,a5,a4
}
 538:	6422                	ld	s0,8(sp)
 53a:	0141                	addi	sp,sp,16
 53c:	8082                	ret
  return 0;
 53e:	4501                	li	a0,0
 540:	bfe5                	j	538 <memcmp+0x30>

0000000000000542 <memcpy>:

void *
memcpy(void *dst, const void *src, uint n)
{
 542:	1141                	addi	sp,sp,-16
 544:	e406                	sd	ra,8(sp)
 546:	e022                	sd	s0,0(sp)
 548:	0800                	addi	s0,sp,16
  return memmove(dst, src, n);
 54a:	00000097          	auipc	ra,0x0
 54e:	f66080e7          	jalr	-154(ra) # 4b0 <memmove>
}
 552:	60a2                	ld	ra,8(sp)
 554:	6402                	ld	s0,0(sp)
 556:	0141                	addi	sp,sp,16
 558:	8082                	ret

000000000000055a <fork>:
# generated by usys.pl - do not edit
#include "kernel/syscall.h"
.global fork
fork:
 li a7, SYS_fork
 55a:	4885                	li	a7,1
 ecall
 55c:	00000073          	ecall
 ret
 560:	8082                	ret

0000000000000562 <exit>:
.global exit
exit:
 li a7, SYS_exit
 562:	4889                	li	a7,2
 ecall
 564:	00000073          	ecall
 ret
 568:	8082                	ret

000000000000056a <wait>:
.global wait
wait:
 li a7, SYS_wait
 56a:	488d                	li	a7,3
 ecall
 56c:	00000073          	ecall
 ret
 570:	8082                	ret

0000000000000572 <pipe>:
.global pipe
pipe:
 li a7, SYS_pipe
 572:	4891                	li	a7,4
 ecall
 574:	00000073          	ecall
 ret
 578:	8082                	ret

000000000000057a <read>:
.global read
read:
 li a7, SYS_read
 57a:	4895                	li	a7,5
 ecall
 57c:	00000073          	ecall
 ret
 580:	8082                	ret

0000000000000582 <write>:
.global write
write:
 li a7, SYS_write
 582:	48c1                	li	a7,16
 ecall
 584:	00000073          	ecall
 ret
 588:	8082                	ret

000000000000058a <close>:
.global close
close:
 li a7, SYS_close
 58a:	48d5                	li	a7,21
 ecall
 58c:	00000073          	ecall
 ret
 590:	8082                	ret

0000000000000592 <kill>:
.global kill
kill:
 li a7, SYS_kill
 592:	4899                	li	a7,6
 ecall
 594:	00000073          	ecall
 ret
 598:	8082                	ret

000000000000059a <exec>:
.global exec
exec:
 li a7, SYS_exec
 59a:	489d                	li	a7,7
 ecall
 59c:	00000073          	ecall
 ret
 5a0:	8082                	ret

00000000000005a2 <open>:
.global open
open:
 li a7, SYS_open
 5a2:	48bd                	li	a7,15
 ecall
 5a4:	00000073          	ecall
 ret
 5a8:	8082                	ret

00000000000005aa <mknod>:
.global mknod
mknod:
 li a7, SYS_mknod
 5aa:	48c5                	li	a7,17
 ecall
 5ac:	00000073          	ecall
 ret
 5b0:	8082                	ret

00000000000005b2 <unlink>:
.global unlink
unlink:
 li a7, SYS_unlink
 5b2:	48c9                	li	a7,18
 ecall
 5b4:	00000073          	ecall
 ret
 5b8:	8082                	ret

00000000000005ba <fstat>:
.global fstat
fstat:
 li a7, SYS_fstat
 5ba:	48a1                	li	a7,8
 ecall
 5bc:	00000073          	ecall
 ret
 5c0:	8082                	ret

00000000000005c2 <link>:
.global link
link:
 li a7, SYS_link
 5c2:	48cd                	li	a7,19
 ecall
 5c4:	00000073          	ecall
 ret
 5c8:	8082                	ret

00000000000005ca <mkdir>:
.global mkdir
mkdir:
 li a7, SYS_mkdir
 5ca:	48d1                	li	a7,20
 ecall
 5cc:	00000073          	ecall
 ret
 5d0:	8082                	ret

00000000000005d2 <chdir>:
.global chdir
chdir:
 li a7, SYS_chdir
 5d2:	48a5                	li	a7,9
 ecall
 5d4:	00000073          	ecall
 ret
 5d8:	8082                	ret

00000000000005da <dup>:
.global dup
dup:
 li a7, SYS_dup
 5da:	48a9                	li	a7,10
 ecall
 5dc:	00000073          	ecall
 ret
 5e0:	8082                	ret

00000000000005e2 <getpid>:
.global getpid
getpid:
 li a7, SYS_getpid
 5e2:	48ad                	li	a7,11
 ecall
 5e4:	00000073          	ecall
 ret
 5e8:	8082                	ret

00000000000005ea <sbrk>:
.global sbrk
sbrk:
 li a7, SYS_sbrk
 5ea:	48b1                	li	a7,12
 ecall
 5ec:	00000073          	ecall
 ret
 5f0:	8082                	ret

00000000000005f2 <sleep>:
.global sleep
sleep:
 li a7, SYS_sleep
 5f2:	48b5                	li	a7,13
 ecall
 5f4:	00000073          	ecall
 ret
 5f8:	8082                	ret

00000000000005fa <uptime>:
.global uptime
uptime:
 li a7, SYS_uptime
 5fa:	48b9                	li	a7,14
 ecall
 5fc:	00000073          	ecall
 ret
 600:	8082                	ret

0000000000000602 <waitx>:
.global waitx
waitx:
 li a7, SYS_waitx
 602:	48d9                	li	a7,22
 ecall
 604:	00000073          	ecall
 ret
 608:	8082                	ret

000000000000060a <get_fault_counts>:
.global get_fault_counts
get_fault_counts:
 li a7, SYS_get_fault_counts
 60a:	48dd                	li	a7,23
 ecall
 60c:	00000073          	ecall
 ret
 610:	8082                	ret

0000000000000612 <get_total_fault_counts>:
.global get_total_fault_counts
get_total_fault_counts:
 li a7, SYS_get_total_fault_counts
 612:	48e1                	li	a7,24
 ecall
 614:	00000073          	ecall
 ret
 618:	8082                	ret

000000000000061a <get_cow_faults>:
.global get_cow_faults
get_cow_faults:
 li a7, SYS_get_cow_faults
 61a:	48e5                	li	a7,25
 ecall
 61c:	00000073          	ecall
 ret
 620:	8082                	ret

0000000000000622 <putc>:

static char digits[] = "0123456789ABCDEF";

static void
putc(int fd, char c)
{
 622:	1101                	addi	sp,sp,-32
 624:	ec06                	sd	ra,24(sp)
 626:	e822                	sd	s0,16(sp)
 628:	1000                	addi	s0,sp,32
 62a:	feb407a3          	sb	a1,-17(s0)
  write(fd, &c, 1);
 62e:	4605                	li	a2,1
 630:	fef40593          	addi	a1,s0,-17
 634:	00000097          	auipc	ra,0x0
 638:	f4e080e7          	jalr	-178(ra) # 582 <write>
}
 63c:	60e2                	ld	ra,24(sp)
 63e:	6442                	ld	s0,16(sp)
 640:	6105                	addi	sp,sp,32
 642:	8082                	ret

0000000000000644 <printint>:

static void
printint(int fd, int xx, int base, int sgn)
{
 644:	7139                	addi	sp,sp,-64
 646:	fc06                	sd	ra,56(sp)
 648:	f822                	sd	s0,48(sp)
 64a:	f426                	sd	s1,40(sp)
 64c:	0080                	addi	s0,sp,64
 64e:	84aa                	mv	s1,a0
  char buf[16];
  int i, neg;
  uint x;

  neg = 0;
  if(sgn && xx < 0){
 650:	c299                	beqz	a3,656 <printint+0x12>
 652:	0805cb63          	bltz	a1,6e8 <printint+0xa4>
    neg = 1;
    x = -xx;
  } else {
    x = xx;
 656:	2581                	sext.w	a1,a1
  neg = 0;
 658:	4881                	li	a7,0
 65a:	fc040693          	addi	a3,s0,-64
  }

  i = 0;
 65e:	4701                	li	a4,0
  do{
    buf[i++] = digits[x % base];
 660:	2601                	sext.w	a2,a2
 662:	00000517          	auipc	a0,0x0
 666:	59650513          	addi	a0,a0,1430 # bf8 <digits>
 66a:	883a                	mv	a6,a4
 66c:	2705                	addiw	a4,a4,1
 66e:	02c5f7bb          	remuw	a5,a1,a2
 672:	1782                	slli	a5,a5,0x20
 674:	9381                	srli	a5,a5,0x20
 676:	97aa                	add	a5,a5,a0
 678:	0007c783          	lbu	a5,0(a5)
 67c:	00f68023          	sb	a5,0(a3)
  }while((x /= base) != 0);
 680:	0005879b          	sext.w	a5,a1
 684:	02c5d5bb          	divuw	a1,a1,a2
 688:	0685                	addi	a3,a3,1
 68a:	fec7f0e3          	bgeu	a5,a2,66a <printint+0x26>
  if(neg)
 68e:	00088c63          	beqz	a7,6a6 <printint+0x62>
    buf[i++] = '-';
 692:	fd070793          	addi	a5,a4,-48
 696:	00878733          	add	a4,a5,s0
 69a:	02d00793          	li	a5,45
 69e:	fef70823          	sb	a5,-16(a4)
 6a2:	0028071b          	addiw	a4,a6,2

  while(--i >= 0)
 6a6:	02e05c63          	blez	a4,6de <printint+0x9a>
 6aa:	f04a                	sd	s2,32(sp)
 6ac:	ec4e                	sd	s3,24(sp)
 6ae:	fc040793          	addi	a5,s0,-64
 6b2:	00e78933          	add	s2,a5,a4
 6b6:	fff78993          	addi	s3,a5,-1
 6ba:	99ba                	add	s3,s3,a4
 6bc:	377d                	addiw	a4,a4,-1
 6be:	1702                	slli	a4,a4,0x20
 6c0:	9301                	srli	a4,a4,0x20
 6c2:	40e989b3          	sub	s3,s3,a4
    putc(fd, buf[i]);
 6c6:	fff94583          	lbu	a1,-1(s2)
 6ca:	8526                	mv	a0,s1
 6cc:	00000097          	auipc	ra,0x0
 6d0:	f56080e7          	jalr	-170(ra) # 622 <putc>
  while(--i >= 0)
 6d4:	197d                	addi	s2,s2,-1
 6d6:	ff3918e3          	bne	s2,s3,6c6 <printint+0x82>
 6da:	7902                	ld	s2,32(sp)
 6dc:	69e2                	ld	s3,24(sp)
}
 6de:	70e2                	ld	ra,56(sp)
 6e0:	7442                	ld	s0,48(sp)
 6e2:	74a2                	ld	s1,40(sp)
 6e4:	6121                	addi	sp,sp,64
 6e6:	8082                	ret
    x = -xx;
 6e8:	40b005bb          	negw	a1,a1
    neg = 1;
 6ec:	4885                	li	a7,1
    x = -xx;
 6ee:	b7b5                	j	65a <printint+0x16>

00000000000006f0 <vprintf>:
}

// Print to the given fd. Only understands %d, %x, %p, %s.
void
vprintf(int fd, const char *fmt, va_list ap)
{
 6f0:	715d                	addi	sp,sp,-80
 6f2:	e486                	sd	ra,72(sp)
 6f4:	e0a2                	sd	s0,64(sp)
 6f6:	f84a                	sd	s2,48(sp)
 6f8:	0880                	addi	s0,sp,80
  char *s;
  int c, i, state;

  state = 0;
  for(i = 0; fmt[i]; i++){
 6fa:	0005c903          	lbu	s2,0(a1)
 6fe:	1a090a63          	beqz	s2,8b2 <vprintf+0x1c2>
 702:	fc26                	sd	s1,56(sp)
 704:	f44e                	sd	s3,40(sp)
 706:	f052                	sd	s4,32(sp)
 708:	ec56                	sd	s5,24(sp)
 70a:	e85a                	sd	s6,16(sp)
 70c:	e45e                	sd	s7,8(sp)
 70e:	8aaa                	mv	s5,a0
 710:	8bb2                	mv	s7,a2
 712:	00158493          	addi	s1,a1,1
  state = 0;
 716:	4981                	li	s3,0
      if(c == '%'){
        state = '%';
      } else {
        putc(fd, c);
      }
    } else if(state == '%'){
 718:	02500a13          	li	s4,37
 71c:	4b55                	li	s6,21
 71e:	a839                	j	73c <vprintf+0x4c>
        putc(fd, c);
 720:	85ca                	mv	a1,s2
 722:	8556                	mv	a0,s5
 724:	00000097          	auipc	ra,0x0
 728:	efe080e7          	jalr	-258(ra) # 622 <putc>
 72c:	a019                	j	732 <vprintf+0x42>
    } else if(state == '%'){
 72e:	01498d63          	beq	s3,s4,748 <vprintf+0x58>
  for(i = 0; fmt[i]; i++){
 732:	0485                	addi	s1,s1,1
 734:	fff4c903          	lbu	s2,-1(s1)
 738:	16090763          	beqz	s2,8a6 <vprintf+0x1b6>
    if(state == 0){
 73c:	fe0999e3          	bnez	s3,72e <vprintf+0x3e>
      if(c == '%'){
 740:	ff4910e3          	bne	s2,s4,720 <vprintf+0x30>
        state = '%';
 744:	89d2                	mv	s3,s4
 746:	b7f5                	j	732 <vprintf+0x42>
      if(c == 'd'){
 748:	13490463          	beq	s2,s4,870 <vprintf+0x180>
 74c:	f9d9079b          	addiw	a5,s2,-99
 750:	0ff7f793          	zext.b	a5,a5
 754:	12fb6763          	bltu	s6,a5,882 <vprintf+0x192>
 758:	f9d9079b          	addiw	a5,s2,-99
 75c:	0ff7f713          	zext.b	a4,a5
 760:	12eb6163          	bltu	s6,a4,882 <vprintf+0x192>
 764:	00271793          	slli	a5,a4,0x2
 768:	00000717          	auipc	a4,0x0
 76c:	43870713          	addi	a4,a4,1080 # ba0 <malloc+0x1fe>
 770:	97ba                	add	a5,a5,a4
 772:	439c                	lw	a5,0(a5)
 774:	97ba                	add	a5,a5,a4
 776:	8782                	jr	a5
        printint(fd, va_arg(ap, int), 10, 1);
 778:	008b8913          	addi	s2,s7,8
 77c:	4685                	li	a3,1
 77e:	4629                	li	a2,10
 780:	000ba583          	lw	a1,0(s7)
 784:	8556                	mv	a0,s5
 786:	00000097          	auipc	ra,0x0
 78a:	ebe080e7          	jalr	-322(ra) # 644 <printint>
 78e:	8bca                	mv	s7,s2
      } else {
        // Unknown % sequence.  Print it to draw attention.
        putc(fd, '%');
        putc(fd, c);
      }
      state = 0;
 790:	4981                	li	s3,0
 792:	b745                	j	732 <vprintf+0x42>
        printint(fd, va_arg(ap, uint64), 10, 0);
 794:	008b8913          	addi	s2,s7,8
 798:	4681                	li	a3,0
 79a:	4629                	li	a2,10
 79c:	000ba583          	lw	a1,0(s7)
 7a0:	8556                	mv	a0,s5
 7a2:	00000097          	auipc	ra,0x0
 7a6:	ea2080e7          	jalr	-350(ra) # 644 <printint>
 7aa:	8bca                	mv	s7,s2
      state = 0;
 7ac:	4981                	li	s3,0
 7ae:	b751                	j	732 <vprintf+0x42>
        printint(fd, va_arg(ap, int), 16, 0);
 7b0:	008b8913          	addi	s2,s7,8
 7b4:	4681                	li	a3,0
 7b6:	4641                	li	a2,16
 7b8:	000ba583          	lw	a1,0(s7)
 7bc:	8556                	mv	a0,s5
 7be:	00000097          	auipc	ra,0x0
 7c2:	e86080e7          	jalr	-378(ra) # 644 <printint>
 7c6:	8bca                	mv	s7,s2
      state = 0;
 7c8:	4981                	li	s3,0
 7ca:	b7a5                	j	732 <vprintf+0x42>
 7cc:	e062                	sd	s8,0(sp)
        printptr(fd, va_arg(ap, uint64));
 7ce:	008b8c13          	addi	s8,s7,8
 7d2:	000bb983          	ld	s3,0(s7)
  putc(fd, '0');
 7d6:	03000593          	li	a1,48
 7da:	8556                	mv	a0,s5
 7dc:	00000097          	auipc	ra,0x0
 7e0:	e46080e7          	jalr	-442(ra) # 622 <putc>
  putc(fd, 'x');
 7e4:	07800593          	li	a1,120
 7e8:	8556                	mv	a0,s5
 7ea:	00000097          	auipc	ra,0x0
 7ee:	e38080e7          	jalr	-456(ra) # 622 <putc>
 7f2:	4941                	li	s2,16
    putc(fd, digits[x >> (sizeof(uint64) * 8 - 4)]);
 7f4:	00000b97          	auipc	s7,0x0
 7f8:	404b8b93          	addi	s7,s7,1028 # bf8 <digits>
 7fc:	03c9d793          	srli	a5,s3,0x3c
 800:	97de                	add	a5,a5,s7
 802:	0007c583          	lbu	a1,0(a5)
 806:	8556                	mv	a0,s5
 808:	00000097          	auipc	ra,0x0
 80c:	e1a080e7          	jalr	-486(ra) # 622 <putc>
  for (i = 0; i < (sizeof(uint64) * 2); i++, x <<= 4)
 810:	0992                	slli	s3,s3,0x4
 812:	397d                	addiw	s2,s2,-1
 814:	fe0914e3          	bnez	s2,7fc <vprintf+0x10c>
        printptr(fd, va_arg(ap, uint64));
 818:	8be2                	mv	s7,s8
      state = 0;
 81a:	4981                	li	s3,0
 81c:	6c02                	ld	s8,0(sp)
 81e:	bf11                	j	732 <vprintf+0x42>
        s = va_arg(ap, char*);
 820:	008b8993          	addi	s3,s7,8
 824:	000bb903          	ld	s2,0(s7)
        if(s == 0)
 828:	02090163          	beqz	s2,84a <vprintf+0x15a>
        while(*s != 0){
 82c:	00094583          	lbu	a1,0(s2)
 830:	c9a5                	beqz	a1,8a0 <vprintf+0x1b0>
          putc(fd, *s);
 832:	8556                	mv	a0,s5
 834:	00000097          	auipc	ra,0x0
 838:	dee080e7          	jalr	-530(ra) # 622 <putc>
          s++;
 83c:	0905                	addi	s2,s2,1
        while(*s != 0){
 83e:	00094583          	lbu	a1,0(s2)
 842:	f9e5                	bnez	a1,832 <vprintf+0x142>
        s = va_arg(ap, char*);
 844:	8bce                	mv	s7,s3
      state = 0;
 846:	4981                	li	s3,0
 848:	b5ed                	j	732 <vprintf+0x42>
          s = "(null)";
 84a:	00000917          	auipc	s2,0x0
 84e:	34e90913          	addi	s2,s2,846 # b98 <malloc+0x1f6>
        while(*s != 0){
 852:	02800593          	li	a1,40
 856:	bff1                	j	832 <vprintf+0x142>
        putc(fd, va_arg(ap, uint));
 858:	008b8913          	addi	s2,s7,8
 85c:	000bc583          	lbu	a1,0(s7)
 860:	8556                	mv	a0,s5
 862:	00000097          	auipc	ra,0x0
 866:	dc0080e7          	jalr	-576(ra) # 622 <putc>
 86a:	8bca                	mv	s7,s2
      state = 0;
 86c:	4981                	li	s3,0
 86e:	b5d1                	j	732 <vprintf+0x42>
        putc(fd, c);
 870:	02500593          	li	a1,37
 874:	8556                	mv	a0,s5
 876:	00000097          	auipc	ra,0x0
 87a:	dac080e7          	jalr	-596(ra) # 622 <putc>
      state = 0;
 87e:	4981                	li	s3,0
 880:	bd4d                	j	732 <vprintf+0x42>
        putc(fd, '%');
 882:	02500593          	li	a1,37
 886:	8556                	mv	a0,s5
 888:	00000097          	auipc	ra,0x0
 88c:	d9a080e7          	jalr	-614(ra) # 622 <putc>
        putc(fd, c);
 890:	85ca                	mv	a1,s2
 892:	8556                	mv	a0,s5
 894:	00000097          	auipc	ra,0x0
 898:	d8e080e7          	jalr	-626(ra) # 622 <putc>
      state = 0;
 89c:	4981                	li	s3,0
 89e:	bd51                	j	732 <vprintf+0x42>
        s = va_arg(ap, char*);
 8a0:	8bce                	mv	s7,s3
      state = 0;
 8a2:	4981                	li	s3,0
 8a4:	b579                	j	732 <vprintf+0x42>
 8a6:	74e2                	ld	s1,56(sp)
 8a8:	79a2                	ld	s3,40(sp)
 8aa:	7a02                	ld	s4,32(sp)
 8ac:	6ae2                	ld	s5,24(sp)
 8ae:	6b42                	ld	s6,16(sp)
 8b0:	6ba2                	ld	s7,8(sp)
    }
  }
}
 8b2:	60a6                	ld	ra,72(sp)
 8b4:	6406                	ld	s0,64(sp)
 8b6:	7942                	ld	s2,48(sp)
 8b8:	6161                	addi	sp,sp,80
 8ba:	8082                	ret

00000000000008bc <fprintf>:

void
fprintf(int fd, const char *fmt, ...)
{
 8bc:	715d                	addi	sp,sp,-80
 8be:	ec06                	sd	ra,24(sp)
 8c0:	e822                	sd	s0,16(sp)
 8c2:	1000                	addi	s0,sp,32
 8c4:	e010                	sd	a2,0(s0)
 8c6:	e414                	sd	a3,8(s0)
 8c8:	e818                	sd	a4,16(s0)
 8ca:	ec1c                	sd	a5,24(s0)
 8cc:	03043023          	sd	a6,32(s0)
 8d0:	03143423          	sd	a7,40(s0)
  va_list ap;

  va_start(ap, fmt);
 8d4:	fe843423          	sd	s0,-24(s0)
  vprintf(fd, fmt, ap);
 8d8:	8622                	mv	a2,s0
 8da:	00000097          	auipc	ra,0x0
 8de:	e16080e7          	jalr	-490(ra) # 6f0 <vprintf>
}
 8e2:	60e2                	ld	ra,24(sp)
 8e4:	6442                	ld	s0,16(sp)
 8e6:	6161                	addi	sp,sp,80
 8e8:	8082                	ret

00000000000008ea <printf>:

void
printf(const char *fmt, ...)
{
 8ea:	711d                	addi	sp,sp,-96
 8ec:	ec06                	sd	ra,24(sp)
 8ee:	e822                	sd	s0,16(sp)
 8f0:	1000                	addi	s0,sp,32
 8f2:	e40c                	sd	a1,8(s0)
 8f4:	e810                	sd	a2,16(s0)
 8f6:	ec14                	sd	a3,24(s0)
 8f8:	f018                	sd	a4,32(s0)
 8fa:	f41c                	sd	a5,40(s0)
 8fc:	03043823          	sd	a6,48(s0)
 900:	03143c23          	sd	a7,56(s0)
  va_list ap;

  va_start(ap, fmt);
 904:	00840613          	addi	a2,s0,8
 908:	fec43423          	sd	a2,-24(s0)
  vprintf(1, fmt, ap);
 90c:	85aa                	mv	a1,a0
 90e:	4505                	li	a0,1
 910:	00000097          	auipc	ra,0x0
 914:	de0080e7          	jalr	-544(ra) # 6f0 <vprintf>
}
 918:	60e2                	ld	ra,24(sp)
 91a:	6442                	ld	s0,16(sp)
 91c:	6125                	addi	sp,sp,96
 91e:	8082                	ret

0000000000000920 <free>:
static Header base;
static Header *freep;

void
free(void *ap)
{
 920:	1141                	addi	sp,sp,-16
 922:	e422                	sd	s0,8(sp)
 924:	0800                	addi	s0,sp,16
  Header *bp, *p;

  bp = (Header*)ap - 1;
 926:	ff050693          	addi	a3,a0,-16
  for(p = freep; !(bp > p && bp < p->s.ptr); p = p->s.ptr)
 92a:	00000797          	auipc	a5,0x0
 92e:	6d67b783          	ld	a5,1750(a5) # 1000 <freep>
 932:	a02d                	j	95c <free+0x3c>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
      break;
  if(bp + bp->s.size == p->s.ptr){
    bp->s.size += p->s.ptr->s.size;
 934:	4618                	lw	a4,8(a2)
 936:	9f2d                	addw	a4,a4,a1
 938:	fee52c23          	sw	a4,-8(a0)
    bp->s.ptr = p->s.ptr->s.ptr;
 93c:	6398                	ld	a4,0(a5)
 93e:	6310                	ld	a2,0(a4)
 940:	a83d                	j	97e <free+0x5e>
  } else
    bp->s.ptr = p->s.ptr;
  if(p + p->s.size == bp){
    p->s.size += bp->s.size;
 942:	ff852703          	lw	a4,-8(a0)
 946:	9f31                	addw	a4,a4,a2
 948:	c798                	sw	a4,8(a5)
    p->s.ptr = bp->s.ptr;
 94a:	ff053683          	ld	a3,-16(a0)
 94e:	a091                	j	992 <free+0x72>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
 950:	6398                	ld	a4,0(a5)
 952:	00e7e463          	bltu	a5,a4,95a <free+0x3a>
 956:	00e6ea63          	bltu	a3,a4,96a <free+0x4a>
{
 95a:	87ba                	mv	a5,a4
  for(p = freep; !(bp > p && bp < p->s.ptr); p = p->s.ptr)
 95c:	fed7fae3          	bgeu	a5,a3,950 <free+0x30>
 960:	6398                	ld	a4,0(a5)
 962:	00e6e463          	bltu	a3,a4,96a <free+0x4a>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
 966:	fee7eae3          	bltu	a5,a4,95a <free+0x3a>
  if(bp + bp->s.size == p->s.ptr){
 96a:	ff852583          	lw	a1,-8(a0)
 96e:	6390                	ld	a2,0(a5)
 970:	02059813          	slli	a6,a1,0x20
 974:	01c85713          	srli	a4,a6,0x1c
 978:	9736                	add	a4,a4,a3
 97a:	fae60de3          	beq	a2,a4,934 <free+0x14>
    bp->s.ptr = p->s.ptr->s.ptr;
 97e:	fec53823          	sd	a2,-16(a0)
  if(p + p->s.size == bp){
 982:	4790                	lw	a2,8(a5)
 984:	02061593          	slli	a1,a2,0x20
 988:	01c5d713          	srli	a4,a1,0x1c
 98c:	973e                	add	a4,a4,a5
 98e:	fae68ae3          	beq	a3,a4,942 <free+0x22>
    p->s.ptr = bp->s.ptr;
 992:	e394                	sd	a3,0(a5)
  } else
    p->s.ptr = bp;
  freep = p;
 994:	00000717          	auipc	a4,0x0
 998:	66f73623          	sd	a5,1644(a4) # 1000 <freep>
}
 99c:	6422                	ld	s0,8(sp)
 99e:	0141                	addi	sp,sp,16
 9a0:	8082                	ret

00000000000009a2 <malloc>:
  return freep;
}

void*
malloc(uint nbytes)
{
 9a2:	7139                	addi	sp,sp,-64
 9a4:	fc06                	sd	ra,56(sp)
 9a6:	f822                	sd	s0,48(sp)
 9a8:	f426                	sd	s1,40(sp)
 9aa:	ec4e                	sd	s3,24(sp)
 9ac:	0080                	addi	s0,sp,64
  Header *p, *prevp;
  uint nunits;

  nunits = (nbytes + sizeof(Header) - 1)/sizeof(Header) + 1;
 9ae:	02051493          	slli	s1,a0,0x20
 9b2:	9081                	srli	s1,s1,0x20
 9b4:	04bd                	addi	s1,s1,15
 9b6:	8091                	srli	s1,s1,0x4
 9b8:	0014899b          	addiw	s3,s1,1
 9bc:	0485                	addi	s1,s1,1
  if((prevp = freep) == 0){
 9be:	00000517          	auipc	a0,0x0
 9c2:	64253503          	ld	a0,1602(a0) # 1000 <freep>
 9c6:	c915                	beqz	a0,9fa <malloc+0x58>
    base.s.ptr = freep = prevp = &base;
    base.s.size = 0;
  }
  for(p = prevp->s.ptr; ; prevp = p, p = p->s.ptr){
 9c8:	611c                	ld	a5,0(a0)
    if(p->s.size >= nunits){
 9ca:	4798                	lw	a4,8(a5)
 9cc:	08977e63          	bgeu	a4,s1,a68 <malloc+0xc6>
 9d0:	f04a                	sd	s2,32(sp)
 9d2:	e852                	sd	s4,16(sp)
 9d4:	e456                	sd	s5,8(sp)
 9d6:	e05a                	sd	s6,0(sp)
  if(nu < 4096)
 9d8:	8a4e                	mv	s4,s3
 9da:	0009871b          	sext.w	a4,s3
 9de:	6685                	lui	a3,0x1
 9e0:	00d77363          	bgeu	a4,a3,9e6 <malloc+0x44>
 9e4:	6a05                	lui	s4,0x1
 9e6:	000a0b1b          	sext.w	s6,s4
  p = sbrk(nu * sizeof(Header));
 9ea:	004a1a1b          	slliw	s4,s4,0x4
        p->s.size = nunits;
      }
      freep = prevp;
      return (void*)(p + 1);
    }
    if(p == freep)
 9ee:	00000917          	auipc	s2,0x0
 9f2:	61290913          	addi	s2,s2,1554 # 1000 <freep>
  if(p == (char*)-1)
 9f6:	5afd                	li	s5,-1
 9f8:	a091                	j	a3c <malloc+0x9a>
 9fa:	f04a                	sd	s2,32(sp)
 9fc:	e852                	sd	s4,16(sp)
 9fe:	e456                	sd	s5,8(sp)
 a00:	e05a                	sd	s6,0(sp)
    base.s.ptr = freep = prevp = &base;
 a02:	00000797          	auipc	a5,0x0
 a06:	60e78793          	addi	a5,a5,1550 # 1010 <base>
 a0a:	00000717          	auipc	a4,0x0
 a0e:	5ef73b23          	sd	a5,1526(a4) # 1000 <freep>
 a12:	e39c                	sd	a5,0(a5)
    base.s.size = 0;
 a14:	0007a423          	sw	zero,8(a5)
    if(p->s.size >= nunits){
 a18:	b7c1                	j	9d8 <malloc+0x36>
        prevp->s.ptr = p->s.ptr;
 a1a:	6398                	ld	a4,0(a5)
 a1c:	e118                	sd	a4,0(a0)
 a1e:	a08d                	j	a80 <malloc+0xde>
  hp->s.size = nu;
 a20:	01652423          	sw	s6,8(a0)
  free((void*)(hp + 1));
 a24:	0541                	addi	a0,a0,16
 a26:	00000097          	auipc	ra,0x0
 a2a:	efa080e7          	jalr	-262(ra) # 920 <free>
  return freep;
 a2e:	00093503          	ld	a0,0(s2)
      if((p = morecore(nunits)) == 0)
 a32:	c13d                	beqz	a0,a98 <malloc+0xf6>
  for(p = prevp->s.ptr; ; prevp = p, p = p->s.ptr){
 a34:	611c                	ld	a5,0(a0)
    if(p->s.size >= nunits){
 a36:	4798                	lw	a4,8(a5)
 a38:	02977463          	bgeu	a4,s1,a60 <malloc+0xbe>
    if(p == freep)
 a3c:	00093703          	ld	a4,0(s2)
 a40:	853e                	mv	a0,a5
 a42:	fef719e3          	bne	a4,a5,a34 <malloc+0x92>
  p = sbrk(nu * sizeof(Header));
 a46:	8552                	mv	a0,s4
 a48:	00000097          	auipc	ra,0x0
 a4c:	ba2080e7          	jalr	-1118(ra) # 5ea <sbrk>
  if(p == (char*)-1)
 a50:	fd5518e3          	bne	a0,s5,a20 <malloc+0x7e>
        return 0;
 a54:	4501                	li	a0,0
 a56:	7902                	ld	s2,32(sp)
 a58:	6a42                	ld	s4,16(sp)
 a5a:	6aa2                	ld	s5,8(sp)
 a5c:	6b02                	ld	s6,0(sp)
 a5e:	a03d                	j	a8c <malloc+0xea>
 a60:	7902                	ld	s2,32(sp)
 a62:	6a42                	ld	s4,16(sp)
 a64:	6aa2                	ld	s5,8(sp)
 a66:	6b02                	ld	s6,0(sp)
      if(p->s.size == nunits)
 a68:	fae489e3          	beq	s1,a4,a1a <malloc+0x78>
        p->s.size -= nunits;
 a6c:	4137073b          	subw	a4,a4,s3
 a70:	c798                	sw	a4,8(a5)
        p += p->s.size;
 a72:	02071693          	slli	a3,a4,0x20
 a76:	01c6d713          	srli	a4,a3,0x1c
 a7a:	97ba                	add	a5,a5,a4
        p->s.size = nunits;
 a7c:	0137a423          	sw	s3,8(a5)
      freep = prevp;
 a80:	00000717          	auipc	a4,0x0
 a84:	58a73023          	sd	a0,1408(a4) # 1000 <freep>
      return (void*)(p + 1);
 a88:	01078513          	addi	a0,a5,16
  }
}
 a8c:	70e2                	ld	ra,56(sp)
 a8e:	7442                	ld	s0,48(sp)
 a90:	74a2                	ld	s1,40(sp)
 a92:	69e2                	ld	s3,24(sp)
 a94:	6121                	addi	sp,sp,64
 a96:	8082                	ret
 a98:	7902                	ld	s2,32(sp)
 a9a:	6a42                	ld	s4,16(sp)
 a9c:	6aa2                	ld	s5,8(sp)
 a9e:	6b02                	ld	s6,0(sp)
 aa0:	b7f5                	j	a8c <malloc+0xea>
