
user/_cowtest1:     file format elf64-littleriscv


Disassembly of section .text:

0000000000000000 <readonly_test>:
#include "kernel/memlayout.h"
//#include "kernel/defs.h"

#define PGSIZE 4096

void readonly_test() {
   0:	1101                	addi	sp,sp,-32
   2:	ec06                	sd	ra,24(sp)
   4:	e822                	sd	s0,16(sp)
   6:	1000                	addi	s0,sp,32
    printf("Running Read-Only Test\n");
   8:	00001517          	auipc	a0,0x1
   c:	8f850513          	addi	a0,a0,-1800 # 900 <malloc+0x100>
  10:	00000097          	auipc	ra,0x0
  14:	738080e7          	jalr	1848(ra) # 748 <printf>

    int pid = fork();
  18:	00000097          	auipc	ra,0x0
  1c:	3a0080e7          	jalr	928(ra) # 3b8 <fork>
    if (pid < 0) {
  20:	02054a63          	bltz	a0,54 <readonly_test+0x54>
        printf("Fork failed\n");
        return;
    } else if (pid == 0) {
  24:	e931                	bnez	a0,78 <readonly_test+0x78>
        // Child process: read from allocated memory without modifying
        char *mem = sbrk(PGSIZE);
  26:	6505                	lui	a0,0x1
  28:	00000097          	auipc	ra,0x0
  2c:	420080e7          	jalr	1056(ra) # 448 <sbrk>
        if (mem == (char *)-1) {
  30:	57fd                	li	a5,-1
  32:	02f50a63          	beq	a0,a5,66 <readonly_test+0x66>
            printf("sbrk failed\n");
            return;
        }
        // Read the memory to ensure no COW is triggered
        volatile char value = mem[0];
  36:	00054783          	lbu	a5,0(a0) # 1000 <freep>
  3a:	fef407a3          	sb	a5,-17(s0)
        printf("Child read value: %d\n", value);
  3e:	fef44583          	lbu	a1,-17(s0)
  42:	00001517          	auipc	a0,0x1
  46:	8fe50513          	addi	a0,a0,-1794 # 940 <malloc+0x140>
  4a:	00000097          	auipc	ra,0x0
  4e:	6fe080e7          	jalr	1790(ra) # 748 <printf>
        return;
  52:	a805                	j	82 <readonly_test+0x82>
        printf("Fork failed\n");
  54:	00001517          	auipc	a0,0x1
  58:	8c450513          	addi	a0,a0,-1852 # 918 <malloc+0x118>
  5c:	00000097          	auipc	ra,0x0
  60:	6ec080e7          	jalr	1772(ra) # 748 <printf>
        return;
  64:	a839                	j	82 <readonly_test+0x82>
            printf("sbrk failed\n");
  66:	00001517          	auipc	a0,0x1
  6a:	8ca50513          	addi	a0,a0,-1846 # 930 <malloc+0x130>
  6e:	00000097          	auipc	ra,0x0
  72:	6da080e7          	jalr	1754(ra) # 748 <printf>
            return;
  76:	a031                	j	82 <readonly_test+0x82>
    } else {
        // Parent process: wait for the child to complete
        wait((int *)0);
  78:	4501                	li	a0,0
  7a:	00000097          	auipc	ra,0x0
  7e:	34e080e7          	jalr	846(ra) # 3c8 <wait>
    }
}
  82:	60e2                	ld	ra,24(sp)
  84:	6442                	ld	s0,16(sp)
  86:	6105                	addi	sp,sp,32
  88:	8082                	ret

000000000000008a <write_test>:

void write_test() {
  8a:	1141                	addi	sp,sp,-16
  8c:	e406                	sd	ra,8(sp)
  8e:	e022                	sd	s0,0(sp)
  90:	0800                	addi	s0,sp,16
    printf("Running Write Test\n");
  92:	00001517          	auipc	a0,0x1
  96:	8c650513          	addi	a0,a0,-1850 # 958 <malloc+0x158>
  9a:	00000097          	auipc	ra,0x0
  9e:	6ae080e7          	jalr	1710(ra) # 748 <printf>

    int pid = fork();
  a2:	00000097          	auipc	ra,0x0
  a6:	316080e7          	jalr	790(ra) # 3b8 <fork>
    if (pid < 0) {
  aa:	02054863          	bltz	a0,da <write_test+0x50>
        printf("Fork failed\n");
        return;
    } else if (pid == 0) {
  ae:	e921                	bnez	a0,fe <write_test+0x74>
        // Child process: write to allocated memory to trigger COW
        char *mem = sbrk(PGSIZE);
  b0:	6505                	lui	a0,0x1
  b2:	00000097          	auipc	ra,0x0
  b6:	396080e7          	jalr	918(ra) # 448 <sbrk>
        if (mem == (char *)-1) {
  ba:	57fd                	li	a5,-1
  bc:	02f50863          	beq	a0,a5,ec <write_test+0x62>
            printf("sbrk failed\n");
            return;
        }
        // Write to the memory to trigger COW
        mem[0] = 'A';
  c0:	04100793          	li	a5,65
  c4:	00f50023          	sb	a5,0(a0) # 1000 <freep>
        printf("Child wrote to memory\n");
  c8:	00001517          	auipc	a0,0x1
  cc:	8a850513          	addi	a0,a0,-1880 # 970 <malloc+0x170>
  d0:	00000097          	auipc	ra,0x0
  d4:	678080e7          	jalr	1656(ra) # 748 <printf>
        return;
  d8:	a805                	j	108 <write_test+0x7e>
        printf("Fork failed\n");
  da:	00001517          	auipc	a0,0x1
  de:	83e50513          	addi	a0,a0,-1986 # 918 <malloc+0x118>
  e2:	00000097          	auipc	ra,0x0
  e6:	666080e7          	jalr	1638(ra) # 748 <printf>
        return;
  ea:	a839                	j	108 <write_test+0x7e>
            printf("sbrk failed\n");
  ec:	00001517          	auipc	a0,0x1
  f0:	84450513          	addi	a0,a0,-1980 # 930 <malloc+0x130>
  f4:	00000097          	auipc	ra,0x0
  f8:	654080e7          	jalr	1620(ra) # 748 <printf>
            return;
  fc:	a031                	j	108 <write_test+0x7e>
    } else {
        // Parent process: wait for the child to complete
        wait((int *)0);
  fe:	4501                	li	a0,0
 100:	00000097          	auipc	ra,0x0
 104:	2c8080e7          	jalr	712(ra) # 3c8 <wait>
    }
}
 108:	60a2                	ld	ra,8(sp)
 10a:	6402                	ld	s0,0(sp)
 10c:	0141                	addi	sp,sp,16
 10e:	8082                	ret

0000000000000110 <main>:

int main(void) {
 110:	1141                	addi	sp,sp,-16
 112:	e406                	sd	ra,8(sp)
 114:	e022                	sd	s0,0(sp)
 116:	0800                	addi	s0,sp,16
    //total_fault_count = 0;
    //cow_fault_count = 0;
    // Run the read-only test
    readonly_test();
 118:	00000097          	auipc	ra,0x0
 11c:	ee8080e7          	jalr	-280(ra) # 0 <readonly_test>

    // Run the write test
    write_test();
 120:	00000097          	auipc	ra,0x0
 124:	f6a080e7          	jalr	-150(ra) # 8a <write_test>

    // Retrieve and print the fault counts using the new system call
    get_fault_counts();
 128:	00000097          	auipc	ra,0x0
 12c:	340080e7          	jalr	832(ra) # 468 <get_fault_counts>

    return 0;
}
 130:	4501                	li	a0,0
 132:	60a2                	ld	ra,8(sp)
 134:	6402                	ld	s0,0(sp)
 136:	0141                	addi	sp,sp,16
 138:	8082                	ret

000000000000013a <_main>:
//
// wrapper so that it's OK if main() does not call exit().
//
void
_main()
{
 13a:	1141                	addi	sp,sp,-16
 13c:	e406                	sd	ra,8(sp)
 13e:	e022                	sd	s0,0(sp)
 140:	0800                	addi	s0,sp,16
  extern int main();
  main();
 142:	00000097          	auipc	ra,0x0
 146:	fce080e7          	jalr	-50(ra) # 110 <main>
  exit(0);
 14a:	4501                	li	a0,0
 14c:	00000097          	auipc	ra,0x0
 150:	274080e7          	jalr	628(ra) # 3c0 <exit>

0000000000000154 <strcpy>:
}

char*
strcpy(char *s, const char *t)
{
 154:	1141                	addi	sp,sp,-16
 156:	e422                	sd	s0,8(sp)
 158:	0800                	addi	s0,sp,16
  char *os;

  os = s;
  while((*s++ = *t++) != 0)
 15a:	87aa                	mv	a5,a0
 15c:	0585                	addi	a1,a1,1
 15e:	0785                	addi	a5,a5,1
 160:	fff5c703          	lbu	a4,-1(a1)
 164:	fee78fa3          	sb	a4,-1(a5)
 168:	fb75                	bnez	a4,15c <strcpy+0x8>
    ;
  return os;
}
 16a:	6422                	ld	s0,8(sp)
 16c:	0141                	addi	sp,sp,16
 16e:	8082                	ret

0000000000000170 <strcmp>:

int
strcmp(const char *p, const char *q)
{
 170:	1141                	addi	sp,sp,-16
 172:	e422                	sd	s0,8(sp)
 174:	0800                	addi	s0,sp,16
  while(*p && *p == *q)
 176:	00054783          	lbu	a5,0(a0)
 17a:	cb91                	beqz	a5,18e <strcmp+0x1e>
 17c:	0005c703          	lbu	a4,0(a1)
 180:	00f71763          	bne	a4,a5,18e <strcmp+0x1e>
    p++, q++;
 184:	0505                	addi	a0,a0,1
 186:	0585                	addi	a1,a1,1
  while(*p && *p == *q)
 188:	00054783          	lbu	a5,0(a0)
 18c:	fbe5                	bnez	a5,17c <strcmp+0xc>
  return (uchar)*p - (uchar)*q;
 18e:	0005c503          	lbu	a0,0(a1)
}
 192:	40a7853b          	subw	a0,a5,a0
 196:	6422                	ld	s0,8(sp)
 198:	0141                	addi	sp,sp,16
 19a:	8082                	ret

000000000000019c <strlen>:

uint
strlen(const char *s)
{
 19c:	1141                	addi	sp,sp,-16
 19e:	e422                	sd	s0,8(sp)
 1a0:	0800                	addi	s0,sp,16
  int n;

  for(n = 0; s[n]; n++)
 1a2:	00054783          	lbu	a5,0(a0)
 1a6:	cf91                	beqz	a5,1c2 <strlen+0x26>
 1a8:	0505                	addi	a0,a0,1
 1aa:	87aa                	mv	a5,a0
 1ac:	86be                	mv	a3,a5
 1ae:	0785                	addi	a5,a5,1
 1b0:	fff7c703          	lbu	a4,-1(a5)
 1b4:	ff65                	bnez	a4,1ac <strlen+0x10>
 1b6:	40a6853b          	subw	a0,a3,a0
 1ba:	2505                	addiw	a0,a0,1
    ;
  return n;
}
 1bc:	6422                	ld	s0,8(sp)
 1be:	0141                	addi	sp,sp,16
 1c0:	8082                	ret
  for(n = 0; s[n]; n++)
 1c2:	4501                	li	a0,0
 1c4:	bfe5                	j	1bc <strlen+0x20>

00000000000001c6 <memset>:

void*
memset(void *dst, int c, uint n)
{
 1c6:	1141                	addi	sp,sp,-16
 1c8:	e422                	sd	s0,8(sp)
 1ca:	0800                	addi	s0,sp,16
  char *cdst = (char *) dst;
  int i;
  for(i = 0; i < n; i++){
 1cc:	ca19                	beqz	a2,1e2 <memset+0x1c>
 1ce:	87aa                	mv	a5,a0
 1d0:	1602                	slli	a2,a2,0x20
 1d2:	9201                	srli	a2,a2,0x20
 1d4:	00a60733          	add	a4,a2,a0
    cdst[i] = c;
 1d8:	00b78023          	sb	a1,0(a5)
  for(i = 0; i < n; i++){
 1dc:	0785                	addi	a5,a5,1
 1de:	fee79de3          	bne	a5,a4,1d8 <memset+0x12>
  }
  return dst;
}
 1e2:	6422                	ld	s0,8(sp)
 1e4:	0141                	addi	sp,sp,16
 1e6:	8082                	ret

00000000000001e8 <strchr>:

char*
strchr(const char *s, char c)
{
 1e8:	1141                	addi	sp,sp,-16
 1ea:	e422                	sd	s0,8(sp)
 1ec:	0800                	addi	s0,sp,16
  for(; *s; s++)
 1ee:	00054783          	lbu	a5,0(a0)
 1f2:	cb99                	beqz	a5,208 <strchr+0x20>
    if(*s == c)
 1f4:	00f58763          	beq	a1,a5,202 <strchr+0x1a>
  for(; *s; s++)
 1f8:	0505                	addi	a0,a0,1
 1fa:	00054783          	lbu	a5,0(a0)
 1fe:	fbfd                	bnez	a5,1f4 <strchr+0xc>
      return (char*)s;
  return 0;
 200:	4501                	li	a0,0
}
 202:	6422                	ld	s0,8(sp)
 204:	0141                	addi	sp,sp,16
 206:	8082                	ret
  return 0;
 208:	4501                	li	a0,0
 20a:	bfe5                	j	202 <strchr+0x1a>

000000000000020c <gets>:

char*
gets(char *buf, int max)
{
 20c:	711d                	addi	sp,sp,-96
 20e:	ec86                	sd	ra,88(sp)
 210:	e8a2                	sd	s0,80(sp)
 212:	e4a6                	sd	s1,72(sp)
 214:	e0ca                	sd	s2,64(sp)
 216:	fc4e                	sd	s3,56(sp)
 218:	f852                	sd	s4,48(sp)
 21a:	f456                	sd	s5,40(sp)
 21c:	f05a                	sd	s6,32(sp)
 21e:	ec5e                	sd	s7,24(sp)
 220:	1080                	addi	s0,sp,96
 222:	8baa                	mv	s7,a0
 224:	8a2e                	mv	s4,a1
  int i, cc;
  char c;

  for(i=0; i+1 < max; ){
 226:	892a                	mv	s2,a0
 228:	4481                	li	s1,0
    cc = read(0, &c, 1);
    if(cc < 1)
      break;
    buf[i++] = c;
    if(c == '\n' || c == '\r')
 22a:	4aa9                	li	s5,10
 22c:	4b35                	li	s6,13
  for(i=0; i+1 < max; ){
 22e:	89a6                	mv	s3,s1
 230:	2485                	addiw	s1,s1,1
 232:	0344d863          	bge	s1,s4,262 <gets+0x56>
    cc = read(0, &c, 1);
 236:	4605                	li	a2,1
 238:	faf40593          	addi	a1,s0,-81
 23c:	4501                	li	a0,0
 23e:	00000097          	auipc	ra,0x0
 242:	19a080e7          	jalr	410(ra) # 3d8 <read>
    if(cc < 1)
 246:	00a05e63          	blez	a0,262 <gets+0x56>
    buf[i++] = c;
 24a:	faf44783          	lbu	a5,-81(s0)
 24e:	00f90023          	sb	a5,0(s2)
    if(c == '\n' || c == '\r')
 252:	01578763          	beq	a5,s5,260 <gets+0x54>
 256:	0905                	addi	s2,s2,1
 258:	fd679be3          	bne	a5,s6,22e <gets+0x22>
    buf[i++] = c;
 25c:	89a6                	mv	s3,s1
 25e:	a011                	j	262 <gets+0x56>
 260:	89a6                	mv	s3,s1
      break;
  }
  buf[i] = '\0';
 262:	99de                	add	s3,s3,s7
 264:	00098023          	sb	zero,0(s3)
  return buf;
}
 268:	855e                	mv	a0,s7
 26a:	60e6                	ld	ra,88(sp)
 26c:	6446                	ld	s0,80(sp)
 26e:	64a6                	ld	s1,72(sp)
 270:	6906                	ld	s2,64(sp)
 272:	79e2                	ld	s3,56(sp)
 274:	7a42                	ld	s4,48(sp)
 276:	7aa2                	ld	s5,40(sp)
 278:	7b02                	ld	s6,32(sp)
 27a:	6be2                	ld	s7,24(sp)
 27c:	6125                	addi	sp,sp,96
 27e:	8082                	ret

0000000000000280 <stat>:

int
stat(const char *n, struct stat *st)
{
 280:	1101                	addi	sp,sp,-32
 282:	ec06                	sd	ra,24(sp)
 284:	e822                	sd	s0,16(sp)
 286:	e04a                	sd	s2,0(sp)
 288:	1000                	addi	s0,sp,32
 28a:	892e                	mv	s2,a1
  int fd;
  int r;

  fd = open(n, O_RDONLY);
 28c:	4581                	li	a1,0
 28e:	00000097          	auipc	ra,0x0
 292:	172080e7          	jalr	370(ra) # 400 <open>
  if(fd < 0)
 296:	02054663          	bltz	a0,2c2 <stat+0x42>
 29a:	e426                	sd	s1,8(sp)
 29c:	84aa                	mv	s1,a0
    return -1;
  r = fstat(fd, st);
 29e:	85ca                	mv	a1,s2
 2a0:	00000097          	auipc	ra,0x0
 2a4:	178080e7          	jalr	376(ra) # 418 <fstat>
 2a8:	892a                	mv	s2,a0
  close(fd);
 2aa:	8526                	mv	a0,s1
 2ac:	00000097          	auipc	ra,0x0
 2b0:	13c080e7          	jalr	316(ra) # 3e8 <close>
  return r;
 2b4:	64a2                	ld	s1,8(sp)
}
 2b6:	854a                	mv	a0,s2
 2b8:	60e2                	ld	ra,24(sp)
 2ba:	6442                	ld	s0,16(sp)
 2bc:	6902                	ld	s2,0(sp)
 2be:	6105                	addi	sp,sp,32
 2c0:	8082                	ret
    return -1;
 2c2:	597d                	li	s2,-1
 2c4:	bfcd                	j	2b6 <stat+0x36>

00000000000002c6 <atoi>:

int
atoi(const char *s)
{
 2c6:	1141                	addi	sp,sp,-16
 2c8:	e422                	sd	s0,8(sp)
 2ca:	0800                	addi	s0,sp,16
  int n;

  n = 0;
  while('0' <= *s && *s <= '9')
 2cc:	00054683          	lbu	a3,0(a0)
 2d0:	fd06879b          	addiw	a5,a3,-48
 2d4:	0ff7f793          	zext.b	a5,a5
 2d8:	4625                	li	a2,9
 2da:	02f66863          	bltu	a2,a5,30a <atoi+0x44>
 2de:	872a                	mv	a4,a0
  n = 0;
 2e0:	4501                	li	a0,0
    n = n*10 + *s++ - '0';
 2e2:	0705                	addi	a4,a4,1
 2e4:	0025179b          	slliw	a5,a0,0x2
 2e8:	9fa9                	addw	a5,a5,a0
 2ea:	0017979b          	slliw	a5,a5,0x1
 2ee:	9fb5                	addw	a5,a5,a3
 2f0:	fd07851b          	addiw	a0,a5,-48
  while('0' <= *s && *s <= '9')
 2f4:	00074683          	lbu	a3,0(a4)
 2f8:	fd06879b          	addiw	a5,a3,-48
 2fc:	0ff7f793          	zext.b	a5,a5
 300:	fef671e3          	bgeu	a2,a5,2e2 <atoi+0x1c>
  return n;
}
 304:	6422                	ld	s0,8(sp)
 306:	0141                	addi	sp,sp,16
 308:	8082                	ret
  n = 0;
 30a:	4501                	li	a0,0
 30c:	bfe5                	j	304 <atoi+0x3e>

000000000000030e <memmove>:

void*
memmove(void *vdst, const void *vsrc, int n)
{
 30e:	1141                	addi	sp,sp,-16
 310:	e422                	sd	s0,8(sp)
 312:	0800                	addi	s0,sp,16
  char *dst;
  const char *src;

  dst = vdst;
  src = vsrc;
  if (src > dst) {
 314:	02b57463          	bgeu	a0,a1,33c <memmove+0x2e>
    while(n-- > 0)
 318:	00c05f63          	blez	a2,336 <memmove+0x28>
 31c:	1602                	slli	a2,a2,0x20
 31e:	9201                	srli	a2,a2,0x20
 320:	00c507b3          	add	a5,a0,a2
  dst = vdst;
 324:	872a                	mv	a4,a0
      *dst++ = *src++;
 326:	0585                	addi	a1,a1,1
 328:	0705                	addi	a4,a4,1
 32a:	fff5c683          	lbu	a3,-1(a1)
 32e:	fed70fa3          	sb	a3,-1(a4)
    while(n-- > 0)
 332:	fef71ae3          	bne	a4,a5,326 <memmove+0x18>
    src += n;
    while(n-- > 0)
      *--dst = *--src;
  }
  return vdst;
}
 336:	6422                	ld	s0,8(sp)
 338:	0141                	addi	sp,sp,16
 33a:	8082                	ret
    dst += n;
 33c:	00c50733          	add	a4,a0,a2
    src += n;
 340:	95b2                	add	a1,a1,a2
    while(n-- > 0)
 342:	fec05ae3          	blez	a2,336 <memmove+0x28>
 346:	fff6079b          	addiw	a5,a2,-1
 34a:	1782                	slli	a5,a5,0x20
 34c:	9381                	srli	a5,a5,0x20
 34e:	fff7c793          	not	a5,a5
 352:	97ba                	add	a5,a5,a4
      *--dst = *--src;
 354:	15fd                	addi	a1,a1,-1
 356:	177d                	addi	a4,a4,-1
 358:	0005c683          	lbu	a3,0(a1)
 35c:	00d70023          	sb	a3,0(a4)
    while(n-- > 0)
 360:	fee79ae3          	bne	a5,a4,354 <memmove+0x46>
 364:	bfc9                	j	336 <memmove+0x28>

0000000000000366 <memcmp>:

int
memcmp(const void *s1, const void *s2, uint n)
{
 366:	1141                	addi	sp,sp,-16
 368:	e422                	sd	s0,8(sp)
 36a:	0800                	addi	s0,sp,16
  const char *p1 = s1, *p2 = s2;
  while (n-- > 0) {
 36c:	ca05                	beqz	a2,39c <memcmp+0x36>
 36e:	fff6069b          	addiw	a3,a2,-1
 372:	1682                	slli	a3,a3,0x20
 374:	9281                	srli	a3,a3,0x20
 376:	0685                	addi	a3,a3,1
 378:	96aa                	add	a3,a3,a0
    if (*p1 != *p2) {
 37a:	00054783          	lbu	a5,0(a0)
 37e:	0005c703          	lbu	a4,0(a1)
 382:	00e79863          	bne	a5,a4,392 <memcmp+0x2c>
      return *p1 - *p2;
    }
    p1++;
 386:	0505                	addi	a0,a0,1
    p2++;
 388:	0585                	addi	a1,a1,1
  while (n-- > 0) {
 38a:	fed518e3          	bne	a0,a3,37a <memcmp+0x14>
  }
  return 0;
 38e:	4501                	li	a0,0
 390:	a019                	j	396 <memcmp+0x30>
      return *p1 - *p2;
 392:	40e7853b          	subw	a0,a5,a4
}
 396:	6422                	ld	s0,8(sp)
 398:	0141                	addi	sp,sp,16
 39a:	8082                	ret
  return 0;
 39c:	4501                	li	a0,0
 39e:	bfe5                	j	396 <memcmp+0x30>

00000000000003a0 <memcpy>:

void *
memcpy(void *dst, const void *src, uint n)
{
 3a0:	1141                	addi	sp,sp,-16
 3a2:	e406                	sd	ra,8(sp)
 3a4:	e022                	sd	s0,0(sp)
 3a6:	0800                	addi	s0,sp,16
  return memmove(dst, src, n);
 3a8:	00000097          	auipc	ra,0x0
 3ac:	f66080e7          	jalr	-154(ra) # 30e <memmove>
}
 3b0:	60a2                	ld	ra,8(sp)
 3b2:	6402                	ld	s0,0(sp)
 3b4:	0141                	addi	sp,sp,16
 3b6:	8082                	ret

00000000000003b8 <fork>:
# generated by usys.pl - do not edit
#include "kernel/syscall.h"
.global fork
fork:
 li a7, SYS_fork
 3b8:	4885                	li	a7,1
 ecall
 3ba:	00000073          	ecall
 ret
 3be:	8082                	ret

00000000000003c0 <exit>:
.global exit
exit:
 li a7, SYS_exit
 3c0:	4889                	li	a7,2
 ecall
 3c2:	00000073          	ecall
 ret
 3c6:	8082                	ret

00000000000003c8 <wait>:
.global wait
wait:
 li a7, SYS_wait
 3c8:	488d                	li	a7,3
 ecall
 3ca:	00000073          	ecall
 ret
 3ce:	8082                	ret

00000000000003d0 <pipe>:
.global pipe
pipe:
 li a7, SYS_pipe
 3d0:	4891                	li	a7,4
 ecall
 3d2:	00000073          	ecall
 ret
 3d6:	8082                	ret

00000000000003d8 <read>:
.global read
read:
 li a7, SYS_read
 3d8:	4895                	li	a7,5
 ecall
 3da:	00000073          	ecall
 ret
 3de:	8082                	ret

00000000000003e0 <write>:
.global write
write:
 li a7, SYS_write
 3e0:	48c1                	li	a7,16
 ecall
 3e2:	00000073          	ecall
 ret
 3e6:	8082                	ret

00000000000003e8 <close>:
.global close
close:
 li a7, SYS_close
 3e8:	48d5                	li	a7,21
 ecall
 3ea:	00000073          	ecall
 ret
 3ee:	8082                	ret

00000000000003f0 <kill>:
.global kill
kill:
 li a7, SYS_kill
 3f0:	4899                	li	a7,6
 ecall
 3f2:	00000073          	ecall
 ret
 3f6:	8082                	ret

00000000000003f8 <exec>:
.global exec
exec:
 li a7, SYS_exec
 3f8:	489d                	li	a7,7
 ecall
 3fa:	00000073          	ecall
 ret
 3fe:	8082                	ret

0000000000000400 <open>:
.global open
open:
 li a7, SYS_open
 400:	48bd                	li	a7,15
 ecall
 402:	00000073          	ecall
 ret
 406:	8082                	ret

0000000000000408 <mknod>:
.global mknod
mknod:
 li a7, SYS_mknod
 408:	48c5                	li	a7,17
 ecall
 40a:	00000073          	ecall
 ret
 40e:	8082                	ret

0000000000000410 <unlink>:
.global unlink
unlink:
 li a7, SYS_unlink
 410:	48c9                	li	a7,18
 ecall
 412:	00000073          	ecall
 ret
 416:	8082                	ret

0000000000000418 <fstat>:
.global fstat
fstat:
 li a7, SYS_fstat
 418:	48a1                	li	a7,8
 ecall
 41a:	00000073          	ecall
 ret
 41e:	8082                	ret

0000000000000420 <link>:
.global link
link:
 li a7, SYS_link
 420:	48cd                	li	a7,19
 ecall
 422:	00000073          	ecall
 ret
 426:	8082                	ret

0000000000000428 <mkdir>:
.global mkdir
mkdir:
 li a7, SYS_mkdir
 428:	48d1                	li	a7,20
 ecall
 42a:	00000073          	ecall
 ret
 42e:	8082                	ret

0000000000000430 <chdir>:
.global chdir
chdir:
 li a7, SYS_chdir
 430:	48a5                	li	a7,9
 ecall
 432:	00000073          	ecall
 ret
 436:	8082                	ret

0000000000000438 <dup>:
.global dup
dup:
 li a7, SYS_dup
 438:	48a9                	li	a7,10
 ecall
 43a:	00000073          	ecall
 ret
 43e:	8082                	ret

0000000000000440 <getpid>:
.global getpid
getpid:
 li a7, SYS_getpid
 440:	48ad                	li	a7,11
 ecall
 442:	00000073          	ecall
 ret
 446:	8082                	ret

0000000000000448 <sbrk>:
.global sbrk
sbrk:
 li a7, SYS_sbrk
 448:	48b1                	li	a7,12
 ecall
 44a:	00000073          	ecall
 ret
 44e:	8082                	ret

0000000000000450 <sleep>:
.global sleep
sleep:
 li a7, SYS_sleep
 450:	48b5                	li	a7,13
 ecall
 452:	00000073          	ecall
 ret
 456:	8082                	ret

0000000000000458 <uptime>:
.global uptime
uptime:
 li a7, SYS_uptime
 458:	48b9                	li	a7,14
 ecall
 45a:	00000073          	ecall
 ret
 45e:	8082                	ret

0000000000000460 <waitx>:
.global waitx
waitx:
 li a7, SYS_waitx
 460:	48d9                	li	a7,22
 ecall
 462:	00000073          	ecall
 ret
 466:	8082                	ret

0000000000000468 <get_fault_counts>:
.global get_fault_counts
get_fault_counts:
 li a7, SYS_get_fault_counts
 468:	48dd                	li	a7,23
 ecall
 46a:	00000073          	ecall
 ret
 46e:	8082                	ret

0000000000000470 <get_total_fault_counts>:
.global get_total_fault_counts
get_total_fault_counts:
 li a7, SYS_get_total_fault_counts
 470:	48e1                	li	a7,24
 ecall
 472:	00000073          	ecall
 ret
 476:	8082                	ret

0000000000000478 <get_cow_faults>:
.global get_cow_faults
get_cow_faults:
 li a7, SYS_get_cow_faults
 478:	48e5                	li	a7,25
 ecall
 47a:	00000073          	ecall
 ret
 47e:	8082                	ret

0000000000000480 <putc>:

static char digits[] = "0123456789ABCDEF";

static void
putc(int fd, char c)
{
 480:	1101                	addi	sp,sp,-32
 482:	ec06                	sd	ra,24(sp)
 484:	e822                	sd	s0,16(sp)
 486:	1000                	addi	s0,sp,32
 488:	feb407a3          	sb	a1,-17(s0)
  write(fd, &c, 1);
 48c:	4605                	li	a2,1
 48e:	fef40593          	addi	a1,s0,-17
 492:	00000097          	auipc	ra,0x0
 496:	f4e080e7          	jalr	-178(ra) # 3e0 <write>
}
 49a:	60e2                	ld	ra,24(sp)
 49c:	6442                	ld	s0,16(sp)
 49e:	6105                	addi	sp,sp,32
 4a0:	8082                	ret

00000000000004a2 <printint>:

static void
printint(int fd, int xx, int base, int sgn)
{
 4a2:	7139                	addi	sp,sp,-64
 4a4:	fc06                	sd	ra,56(sp)
 4a6:	f822                	sd	s0,48(sp)
 4a8:	f426                	sd	s1,40(sp)
 4aa:	0080                	addi	s0,sp,64
 4ac:	84aa                	mv	s1,a0
  char buf[16];
  int i, neg;
  uint x;

  neg = 0;
  if(sgn && xx < 0){
 4ae:	c299                	beqz	a3,4b4 <printint+0x12>
 4b0:	0805cb63          	bltz	a1,546 <printint+0xa4>
    neg = 1;
    x = -xx;
  } else {
    x = xx;
 4b4:	2581                	sext.w	a1,a1
  neg = 0;
 4b6:	4881                	li	a7,0
 4b8:	fc040693          	addi	a3,s0,-64
  }

  i = 0;
 4bc:	4701                	li	a4,0
  do{
    buf[i++] = digits[x % base];
 4be:	2601                	sext.w	a2,a2
 4c0:	00000517          	auipc	a0,0x0
 4c4:	52850513          	addi	a0,a0,1320 # 9e8 <digits>
 4c8:	883a                	mv	a6,a4
 4ca:	2705                	addiw	a4,a4,1
 4cc:	02c5f7bb          	remuw	a5,a1,a2
 4d0:	1782                	slli	a5,a5,0x20
 4d2:	9381                	srli	a5,a5,0x20
 4d4:	97aa                	add	a5,a5,a0
 4d6:	0007c783          	lbu	a5,0(a5)
 4da:	00f68023          	sb	a5,0(a3)
  }while((x /= base) != 0);
 4de:	0005879b          	sext.w	a5,a1
 4e2:	02c5d5bb          	divuw	a1,a1,a2
 4e6:	0685                	addi	a3,a3,1
 4e8:	fec7f0e3          	bgeu	a5,a2,4c8 <printint+0x26>
  if(neg)
 4ec:	00088c63          	beqz	a7,504 <printint+0x62>
    buf[i++] = '-';
 4f0:	fd070793          	addi	a5,a4,-48
 4f4:	00878733          	add	a4,a5,s0
 4f8:	02d00793          	li	a5,45
 4fc:	fef70823          	sb	a5,-16(a4)
 500:	0028071b          	addiw	a4,a6,2

  while(--i >= 0)
 504:	02e05c63          	blez	a4,53c <printint+0x9a>
 508:	f04a                	sd	s2,32(sp)
 50a:	ec4e                	sd	s3,24(sp)
 50c:	fc040793          	addi	a5,s0,-64
 510:	00e78933          	add	s2,a5,a4
 514:	fff78993          	addi	s3,a5,-1
 518:	99ba                	add	s3,s3,a4
 51a:	377d                	addiw	a4,a4,-1
 51c:	1702                	slli	a4,a4,0x20
 51e:	9301                	srli	a4,a4,0x20
 520:	40e989b3          	sub	s3,s3,a4
    putc(fd, buf[i]);
 524:	fff94583          	lbu	a1,-1(s2)
 528:	8526                	mv	a0,s1
 52a:	00000097          	auipc	ra,0x0
 52e:	f56080e7          	jalr	-170(ra) # 480 <putc>
  while(--i >= 0)
 532:	197d                	addi	s2,s2,-1
 534:	ff3918e3          	bne	s2,s3,524 <printint+0x82>
 538:	7902                	ld	s2,32(sp)
 53a:	69e2                	ld	s3,24(sp)
}
 53c:	70e2                	ld	ra,56(sp)
 53e:	7442                	ld	s0,48(sp)
 540:	74a2                	ld	s1,40(sp)
 542:	6121                	addi	sp,sp,64
 544:	8082                	ret
    x = -xx;
 546:	40b005bb          	negw	a1,a1
    neg = 1;
 54a:	4885                	li	a7,1
    x = -xx;
 54c:	b7b5                	j	4b8 <printint+0x16>

000000000000054e <vprintf>:
}

// Print to the given fd. Only understands %d, %x, %p, %s.
void
vprintf(int fd, const char *fmt, va_list ap)
{
 54e:	715d                	addi	sp,sp,-80
 550:	e486                	sd	ra,72(sp)
 552:	e0a2                	sd	s0,64(sp)
 554:	f84a                	sd	s2,48(sp)
 556:	0880                	addi	s0,sp,80
  char *s;
  int c, i, state;

  state = 0;
  for(i = 0; fmt[i]; i++){
 558:	0005c903          	lbu	s2,0(a1)
 55c:	1a090a63          	beqz	s2,710 <vprintf+0x1c2>
 560:	fc26                	sd	s1,56(sp)
 562:	f44e                	sd	s3,40(sp)
 564:	f052                	sd	s4,32(sp)
 566:	ec56                	sd	s5,24(sp)
 568:	e85a                	sd	s6,16(sp)
 56a:	e45e                	sd	s7,8(sp)
 56c:	8aaa                	mv	s5,a0
 56e:	8bb2                	mv	s7,a2
 570:	00158493          	addi	s1,a1,1
  state = 0;
 574:	4981                	li	s3,0
      if(c == '%'){
        state = '%';
      } else {
        putc(fd, c);
      }
    } else if(state == '%'){
 576:	02500a13          	li	s4,37
 57a:	4b55                	li	s6,21
 57c:	a839                	j	59a <vprintf+0x4c>
        putc(fd, c);
 57e:	85ca                	mv	a1,s2
 580:	8556                	mv	a0,s5
 582:	00000097          	auipc	ra,0x0
 586:	efe080e7          	jalr	-258(ra) # 480 <putc>
 58a:	a019                	j	590 <vprintf+0x42>
    } else if(state == '%'){
 58c:	01498d63          	beq	s3,s4,5a6 <vprintf+0x58>
  for(i = 0; fmt[i]; i++){
 590:	0485                	addi	s1,s1,1
 592:	fff4c903          	lbu	s2,-1(s1)
 596:	16090763          	beqz	s2,704 <vprintf+0x1b6>
    if(state == 0){
 59a:	fe0999e3          	bnez	s3,58c <vprintf+0x3e>
      if(c == '%'){
 59e:	ff4910e3          	bne	s2,s4,57e <vprintf+0x30>
        state = '%';
 5a2:	89d2                	mv	s3,s4
 5a4:	b7f5                	j	590 <vprintf+0x42>
      if(c == 'd'){
 5a6:	13490463          	beq	s2,s4,6ce <vprintf+0x180>
 5aa:	f9d9079b          	addiw	a5,s2,-99
 5ae:	0ff7f793          	zext.b	a5,a5
 5b2:	12fb6763          	bltu	s6,a5,6e0 <vprintf+0x192>
 5b6:	f9d9079b          	addiw	a5,s2,-99
 5ba:	0ff7f713          	zext.b	a4,a5
 5be:	12eb6163          	bltu	s6,a4,6e0 <vprintf+0x192>
 5c2:	00271793          	slli	a5,a4,0x2
 5c6:	00000717          	auipc	a4,0x0
 5ca:	3ca70713          	addi	a4,a4,970 # 990 <malloc+0x190>
 5ce:	97ba                	add	a5,a5,a4
 5d0:	439c                	lw	a5,0(a5)
 5d2:	97ba                	add	a5,a5,a4
 5d4:	8782                	jr	a5
        printint(fd, va_arg(ap, int), 10, 1);
 5d6:	008b8913          	addi	s2,s7,8
 5da:	4685                	li	a3,1
 5dc:	4629                	li	a2,10
 5de:	000ba583          	lw	a1,0(s7)
 5e2:	8556                	mv	a0,s5
 5e4:	00000097          	auipc	ra,0x0
 5e8:	ebe080e7          	jalr	-322(ra) # 4a2 <printint>
 5ec:	8bca                	mv	s7,s2
      } else {
        // Unknown % sequence.  Print it to draw attention.
        putc(fd, '%');
        putc(fd, c);
      }
      state = 0;
 5ee:	4981                	li	s3,0
 5f0:	b745                	j	590 <vprintf+0x42>
        printint(fd, va_arg(ap, uint64), 10, 0);
 5f2:	008b8913          	addi	s2,s7,8
 5f6:	4681                	li	a3,0
 5f8:	4629                	li	a2,10
 5fa:	000ba583          	lw	a1,0(s7)
 5fe:	8556                	mv	a0,s5
 600:	00000097          	auipc	ra,0x0
 604:	ea2080e7          	jalr	-350(ra) # 4a2 <printint>
 608:	8bca                	mv	s7,s2
      state = 0;
 60a:	4981                	li	s3,0
 60c:	b751                	j	590 <vprintf+0x42>
        printint(fd, va_arg(ap, int), 16, 0);
 60e:	008b8913          	addi	s2,s7,8
 612:	4681                	li	a3,0
 614:	4641                	li	a2,16
 616:	000ba583          	lw	a1,0(s7)
 61a:	8556                	mv	a0,s5
 61c:	00000097          	auipc	ra,0x0
 620:	e86080e7          	jalr	-378(ra) # 4a2 <printint>
 624:	8bca                	mv	s7,s2
      state = 0;
 626:	4981                	li	s3,0
 628:	b7a5                	j	590 <vprintf+0x42>
 62a:	e062                	sd	s8,0(sp)
        printptr(fd, va_arg(ap, uint64));
 62c:	008b8c13          	addi	s8,s7,8
 630:	000bb983          	ld	s3,0(s7)
  putc(fd, '0');
 634:	03000593          	li	a1,48
 638:	8556                	mv	a0,s5
 63a:	00000097          	auipc	ra,0x0
 63e:	e46080e7          	jalr	-442(ra) # 480 <putc>
  putc(fd, 'x');
 642:	07800593          	li	a1,120
 646:	8556                	mv	a0,s5
 648:	00000097          	auipc	ra,0x0
 64c:	e38080e7          	jalr	-456(ra) # 480 <putc>
 650:	4941                	li	s2,16
    putc(fd, digits[x >> (sizeof(uint64) * 8 - 4)]);
 652:	00000b97          	auipc	s7,0x0
 656:	396b8b93          	addi	s7,s7,918 # 9e8 <digits>
 65a:	03c9d793          	srli	a5,s3,0x3c
 65e:	97de                	add	a5,a5,s7
 660:	0007c583          	lbu	a1,0(a5)
 664:	8556                	mv	a0,s5
 666:	00000097          	auipc	ra,0x0
 66a:	e1a080e7          	jalr	-486(ra) # 480 <putc>
  for (i = 0; i < (sizeof(uint64) * 2); i++, x <<= 4)
 66e:	0992                	slli	s3,s3,0x4
 670:	397d                	addiw	s2,s2,-1
 672:	fe0914e3          	bnez	s2,65a <vprintf+0x10c>
        printptr(fd, va_arg(ap, uint64));
 676:	8be2                	mv	s7,s8
      state = 0;
 678:	4981                	li	s3,0
 67a:	6c02                	ld	s8,0(sp)
 67c:	bf11                	j	590 <vprintf+0x42>
        s = va_arg(ap, char*);
 67e:	008b8993          	addi	s3,s7,8
 682:	000bb903          	ld	s2,0(s7)
        if(s == 0)
 686:	02090163          	beqz	s2,6a8 <vprintf+0x15a>
        while(*s != 0){
 68a:	00094583          	lbu	a1,0(s2)
 68e:	c9a5                	beqz	a1,6fe <vprintf+0x1b0>
          putc(fd, *s);
 690:	8556                	mv	a0,s5
 692:	00000097          	auipc	ra,0x0
 696:	dee080e7          	jalr	-530(ra) # 480 <putc>
          s++;
 69a:	0905                	addi	s2,s2,1
        while(*s != 0){
 69c:	00094583          	lbu	a1,0(s2)
 6a0:	f9e5                	bnez	a1,690 <vprintf+0x142>
        s = va_arg(ap, char*);
 6a2:	8bce                	mv	s7,s3
      state = 0;
 6a4:	4981                	li	s3,0
 6a6:	b5ed                	j	590 <vprintf+0x42>
          s = "(null)";
 6a8:	00000917          	auipc	s2,0x0
 6ac:	2e090913          	addi	s2,s2,736 # 988 <malloc+0x188>
        while(*s != 0){
 6b0:	02800593          	li	a1,40
 6b4:	bff1                	j	690 <vprintf+0x142>
        putc(fd, va_arg(ap, uint));
 6b6:	008b8913          	addi	s2,s7,8
 6ba:	000bc583          	lbu	a1,0(s7)
 6be:	8556                	mv	a0,s5
 6c0:	00000097          	auipc	ra,0x0
 6c4:	dc0080e7          	jalr	-576(ra) # 480 <putc>
 6c8:	8bca                	mv	s7,s2
      state = 0;
 6ca:	4981                	li	s3,0
 6cc:	b5d1                	j	590 <vprintf+0x42>
        putc(fd, c);
 6ce:	02500593          	li	a1,37
 6d2:	8556                	mv	a0,s5
 6d4:	00000097          	auipc	ra,0x0
 6d8:	dac080e7          	jalr	-596(ra) # 480 <putc>
      state = 0;
 6dc:	4981                	li	s3,0
 6de:	bd4d                	j	590 <vprintf+0x42>
        putc(fd, '%');
 6e0:	02500593          	li	a1,37
 6e4:	8556                	mv	a0,s5
 6e6:	00000097          	auipc	ra,0x0
 6ea:	d9a080e7          	jalr	-614(ra) # 480 <putc>
        putc(fd, c);
 6ee:	85ca                	mv	a1,s2
 6f0:	8556                	mv	a0,s5
 6f2:	00000097          	auipc	ra,0x0
 6f6:	d8e080e7          	jalr	-626(ra) # 480 <putc>
      state = 0;
 6fa:	4981                	li	s3,0
 6fc:	bd51                	j	590 <vprintf+0x42>
        s = va_arg(ap, char*);
 6fe:	8bce                	mv	s7,s3
      state = 0;
 700:	4981                	li	s3,0
 702:	b579                	j	590 <vprintf+0x42>
 704:	74e2                	ld	s1,56(sp)
 706:	79a2                	ld	s3,40(sp)
 708:	7a02                	ld	s4,32(sp)
 70a:	6ae2                	ld	s5,24(sp)
 70c:	6b42                	ld	s6,16(sp)
 70e:	6ba2                	ld	s7,8(sp)
    }
  }
}
 710:	60a6                	ld	ra,72(sp)
 712:	6406                	ld	s0,64(sp)
 714:	7942                	ld	s2,48(sp)
 716:	6161                	addi	sp,sp,80
 718:	8082                	ret

000000000000071a <fprintf>:

void
fprintf(int fd, const char *fmt, ...)
{
 71a:	715d                	addi	sp,sp,-80
 71c:	ec06                	sd	ra,24(sp)
 71e:	e822                	sd	s0,16(sp)
 720:	1000                	addi	s0,sp,32
 722:	e010                	sd	a2,0(s0)
 724:	e414                	sd	a3,8(s0)
 726:	e818                	sd	a4,16(s0)
 728:	ec1c                	sd	a5,24(s0)
 72a:	03043023          	sd	a6,32(s0)
 72e:	03143423          	sd	a7,40(s0)
  va_list ap;

  va_start(ap, fmt);
 732:	fe843423          	sd	s0,-24(s0)
  vprintf(fd, fmt, ap);
 736:	8622                	mv	a2,s0
 738:	00000097          	auipc	ra,0x0
 73c:	e16080e7          	jalr	-490(ra) # 54e <vprintf>
}
 740:	60e2                	ld	ra,24(sp)
 742:	6442                	ld	s0,16(sp)
 744:	6161                	addi	sp,sp,80
 746:	8082                	ret

0000000000000748 <printf>:

void
printf(const char *fmt, ...)
{
 748:	711d                	addi	sp,sp,-96
 74a:	ec06                	sd	ra,24(sp)
 74c:	e822                	sd	s0,16(sp)
 74e:	1000                	addi	s0,sp,32
 750:	e40c                	sd	a1,8(s0)
 752:	e810                	sd	a2,16(s0)
 754:	ec14                	sd	a3,24(s0)
 756:	f018                	sd	a4,32(s0)
 758:	f41c                	sd	a5,40(s0)
 75a:	03043823          	sd	a6,48(s0)
 75e:	03143c23          	sd	a7,56(s0)
  va_list ap;

  va_start(ap, fmt);
 762:	00840613          	addi	a2,s0,8
 766:	fec43423          	sd	a2,-24(s0)
  vprintf(1, fmt, ap);
 76a:	85aa                	mv	a1,a0
 76c:	4505                	li	a0,1
 76e:	00000097          	auipc	ra,0x0
 772:	de0080e7          	jalr	-544(ra) # 54e <vprintf>
}
 776:	60e2                	ld	ra,24(sp)
 778:	6442                	ld	s0,16(sp)
 77a:	6125                	addi	sp,sp,96
 77c:	8082                	ret

000000000000077e <free>:
static Header base;
static Header *freep;

void
free(void *ap)
{
 77e:	1141                	addi	sp,sp,-16
 780:	e422                	sd	s0,8(sp)
 782:	0800                	addi	s0,sp,16
  Header *bp, *p;

  bp = (Header*)ap - 1;
 784:	ff050693          	addi	a3,a0,-16
  for(p = freep; !(bp > p && bp < p->s.ptr); p = p->s.ptr)
 788:	00001797          	auipc	a5,0x1
 78c:	8787b783          	ld	a5,-1928(a5) # 1000 <freep>
 790:	a02d                	j	7ba <free+0x3c>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
      break;
  if(bp + bp->s.size == p->s.ptr){
    bp->s.size += p->s.ptr->s.size;
 792:	4618                	lw	a4,8(a2)
 794:	9f2d                	addw	a4,a4,a1
 796:	fee52c23          	sw	a4,-8(a0)
    bp->s.ptr = p->s.ptr->s.ptr;
 79a:	6398                	ld	a4,0(a5)
 79c:	6310                	ld	a2,0(a4)
 79e:	a83d                	j	7dc <free+0x5e>
  } else
    bp->s.ptr = p->s.ptr;
  if(p + p->s.size == bp){
    p->s.size += bp->s.size;
 7a0:	ff852703          	lw	a4,-8(a0)
 7a4:	9f31                	addw	a4,a4,a2
 7a6:	c798                	sw	a4,8(a5)
    p->s.ptr = bp->s.ptr;
 7a8:	ff053683          	ld	a3,-16(a0)
 7ac:	a091                	j	7f0 <free+0x72>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
 7ae:	6398                	ld	a4,0(a5)
 7b0:	00e7e463          	bltu	a5,a4,7b8 <free+0x3a>
 7b4:	00e6ea63          	bltu	a3,a4,7c8 <free+0x4a>
{
 7b8:	87ba                	mv	a5,a4
  for(p = freep; !(bp > p && bp < p->s.ptr); p = p->s.ptr)
 7ba:	fed7fae3          	bgeu	a5,a3,7ae <free+0x30>
 7be:	6398                	ld	a4,0(a5)
 7c0:	00e6e463          	bltu	a3,a4,7c8 <free+0x4a>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
 7c4:	fee7eae3          	bltu	a5,a4,7b8 <free+0x3a>
  if(bp + bp->s.size == p->s.ptr){
 7c8:	ff852583          	lw	a1,-8(a0)
 7cc:	6390                	ld	a2,0(a5)
 7ce:	02059813          	slli	a6,a1,0x20
 7d2:	01c85713          	srli	a4,a6,0x1c
 7d6:	9736                	add	a4,a4,a3
 7d8:	fae60de3          	beq	a2,a4,792 <free+0x14>
    bp->s.ptr = p->s.ptr->s.ptr;
 7dc:	fec53823          	sd	a2,-16(a0)
  if(p + p->s.size == bp){
 7e0:	4790                	lw	a2,8(a5)
 7e2:	02061593          	slli	a1,a2,0x20
 7e6:	01c5d713          	srli	a4,a1,0x1c
 7ea:	973e                	add	a4,a4,a5
 7ec:	fae68ae3          	beq	a3,a4,7a0 <free+0x22>
    p->s.ptr = bp->s.ptr;
 7f0:	e394                	sd	a3,0(a5)
  } else
    p->s.ptr = bp;
  freep = p;
 7f2:	00001717          	auipc	a4,0x1
 7f6:	80f73723          	sd	a5,-2034(a4) # 1000 <freep>
}
 7fa:	6422                	ld	s0,8(sp)
 7fc:	0141                	addi	sp,sp,16
 7fe:	8082                	ret

0000000000000800 <malloc>:
  return freep;
}

void*
malloc(uint nbytes)
{
 800:	7139                	addi	sp,sp,-64
 802:	fc06                	sd	ra,56(sp)
 804:	f822                	sd	s0,48(sp)
 806:	f426                	sd	s1,40(sp)
 808:	ec4e                	sd	s3,24(sp)
 80a:	0080                	addi	s0,sp,64
  Header *p, *prevp;
  uint nunits;

  nunits = (nbytes + sizeof(Header) - 1)/sizeof(Header) + 1;
 80c:	02051493          	slli	s1,a0,0x20
 810:	9081                	srli	s1,s1,0x20
 812:	04bd                	addi	s1,s1,15
 814:	8091                	srli	s1,s1,0x4
 816:	0014899b          	addiw	s3,s1,1
 81a:	0485                	addi	s1,s1,1
  if((prevp = freep) == 0){
 81c:	00000517          	auipc	a0,0x0
 820:	7e453503          	ld	a0,2020(a0) # 1000 <freep>
 824:	c915                	beqz	a0,858 <malloc+0x58>
    base.s.ptr = freep = prevp = &base;
    base.s.size = 0;
  }
  for(p = prevp->s.ptr; ; prevp = p, p = p->s.ptr){
 826:	611c                	ld	a5,0(a0)
    if(p->s.size >= nunits){
 828:	4798                	lw	a4,8(a5)
 82a:	08977e63          	bgeu	a4,s1,8c6 <malloc+0xc6>
 82e:	f04a                	sd	s2,32(sp)
 830:	e852                	sd	s4,16(sp)
 832:	e456                	sd	s5,8(sp)
 834:	e05a                	sd	s6,0(sp)
  if(nu < 4096)
 836:	8a4e                	mv	s4,s3
 838:	0009871b          	sext.w	a4,s3
 83c:	6685                	lui	a3,0x1
 83e:	00d77363          	bgeu	a4,a3,844 <malloc+0x44>
 842:	6a05                	lui	s4,0x1
 844:	000a0b1b          	sext.w	s6,s4
  p = sbrk(nu * sizeof(Header));
 848:	004a1a1b          	slliw	s4,s4,0x4
        p->s.size = nunits;
      }
      freep = prevp;
      return (void*)(p + 1);
    }
    if(p == freep)
 84c:	00000917          	auipc	s2,0x0
 850:	7b490913          	addi	s2,s2,1972 # 1000 <freep>
  if(p == (char*)-1)
 854:	5afd                	li	s5,-1
 856:	a091                	j	89a <malloc+0x9a>
 858:	f04a                	sd	s2,32(sp)
 85a:	e852                	sd	s4,16(sp)
 85c:	e456                	sd	s5,8(sp)
 85e:	e05a                	sd	s6,0(sp)
    base.s.ptr = freep = prevp = &base;
 860:	00000797          	auipc	a5,0x0
 864:	7b078793          	addi	a5,a5,1968 # 1010 <base>
 868:	00000717          	auipc	a4,0x0
 86c:	78f73c23          	sd	a5,1944(a4) # 1000 <freep>
 870:	e39c                	sd	a5,0(a5)
    base.s.size = 0;
 872:	0007a423          	sw	zero,8(a5)
    if(p->s.size >= nunits){
 876:	b7c1                	j	836 <malloc+0x36>
        prevp->s.ptr = p->s.ptr;
 878:	6398                	ld	a4,0(a5)
 87a:	e118                	sd	a4,0(a0)
 87c:	a08d                	j	8de <malloc+0xde>
  hp->s.size = nu;
 87e:	01652423          	sw	s6,8(a0)
  free((void*)(hp + 1));
 882:	0541                	addi	a0,a0,16
 884:	00000097          	auipc	ra,0x0
 888:	efa080e7          	jalr	-262(ra) # 77e <free>
  return freep;
 88c:	00093503          	ld	a0,0(s2)
      if((p = morecore(nunits)) == 0)
 890:	c13d                	beqz	a0,8f6 <malloc+0xf6>
  for(p = prevp->s.ptr; ; prevp = p, p = p->s.ptr){
 892:	611c                	ld	a5,0(a0)
    if(p->s.size >= nunits){
 894:	4798                	lw	a4,8(a5)
 896:	02977463          	bgeu	a4,s1,8be <malloc+0xbe>
    if(p == freep)
 89a:	00093703          	ld	a4,0(s2)
 89e:	853e                	mv	a0,a5
 8a0:	fef719e3          	bne	a4,a5,892 <malloc+0x92>
  p = sbrk(nu * sizeof(Header));
 8a4:	8552                	mv	a0,s4
 8a6:	00000097          	auipc	ra,0x0
 8aa:	ba2080e7          	jalr	-1118(ra) # 448 <sbrk>
  if(p == (char*)-1)
 8ae:	fd5518e3          	bne	a0,s5,87e <malloc+0x7e>
        return 0;
 8b2:	4501                	li	a0,0
 8b4:	7902                	ld	s2,32(sp)
 8b6:	6a42                	ld	s4,16(sp)
 8b8:	6aa2                	ld	s5,8(sp)
 8ba:	6b02                	ld	s6,0(sp)
 8bc:	a03d                	j	8ea <malloc+0xea>
 8be:	7902                	ld	s2,32(sp)
 8c0:	6a42                	ld	s4,16(sp)
 8c2:	6aa2                	ld	s5,8(sp)
 8c4:	6b02                	ld	s6,0(sp)
      if(p->s.size == nunits)
 8c6:	fae489e3          	beq	s1,a4,878 <malloc+0x78>
        p->s.size -= nunits;
 8ca:	4137073b          	subw	a4,a4,s3
 8ce:	c798                	sw	a4,8(a5)
        p += p->s.size;
 8d0:	02071693          	slli	a3,a4,0x20
 8d4:	01c6d713          	srli	a4,a3,0x1c
 8d8:	97ba                	add	a5,a5,a4
        p->s.size = nunits;
 8da:	0137a423          	sw	s3,8(a5)
      freep = prevp;
 8de:	00000717          	auipc	a4,0x0
 8e2:	72a73123          	sd	a0,1826(a4) # 1000 <freep>
      return (void*)(p + 1);
 8e6:	01078513          	addi	a0,a5,16
  }
}
 8ea:	70e2                	ld	ra,56(sp)
 8ec:	7442                	ld	s0,48(sp)
 8ee:	74a2                	ld	s1,40(sp)
 8f0:	69e2                	ld	s3,24(sp)
 8f2:	6121                	addi	sp,sp,64
 8f4:	8082                	ret
 8f6:	7902                	ld	s2,32(sp)
 8f8:	6a42                	ld	s4,16(sp)
 8fa:	6aa2                	ld	s5,8(sp)
 8fc:	6b02                	ld	s6,0(sp)
 8fe:	b7f5                	j	8ea <malloc+0xea>
