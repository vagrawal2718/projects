
user/_mlfq:     file format elf64-littleriscv


Disassembly of section .text:

0000000000000000 <io_bound>:
#include "kernel/stat.h"
#include "user/user.h"

#define NUM_PROCESSES 5

void io_bound(int id) {
   0:	1101                	addi	sp,sp,-32
   2:	ec06                	sd	ra,24(sp)
   4:	e822                	sd	s0,16(sp)
   6:	e426                	sd	s1,8(sp)
   8:	1000                	addi	s0,sp,32
   a:	06400493          	li	s1,100
    for (int i = 0; i < 100; i++) {
        sleep(1);  // Simulate I/O operation
   e:	4505                	li	a0,1
  10:	00000097          	auipc	ra,0x0
  14:	424080e7          	jalr	1060(ra) # 434 <sleep>
    for (int i = 0; i < 100; i++) {
  18:	34fd                	addiw	s1,s1,-1
  1a:	f8f5                	bnez	s1,e <io_bound+0xe>
        //printf("IO-bound process %d: iteration %d\n", id, i);
    }
    exit(0);
  1c:	4501                	li	a0,0
  1e:	00000097          	auipc	ra,0x0
  22:	386080e7          	jalr	902(ra) # 3a4 <exit>

0000000000000026 <cpu_bound>:
}

void cpu_bound(int id) {
  26:	1141                	addi	sp,sp,-16
  28:	e422                	sd	s0,8(sp)
  2a:	0800                	addi	s0,sp,16
    for (int i = 0; i < 10000000000; i++) {
  2c:	a001                	j	2c <cpu_bound+0x6>

000000000000002e <mixed>:
        }
    }
    exit(0);
}

void mixed(int id) {
  2e:	7179                	addi	sp,sp,-48
  30:	f406                	sd	ra,40(sp)
  32:	f022                	sd	s0,32(sp)
  34:	ec26                	sd	s1,24(sp)
  36:	e84a                	sd	s2,16(sp)
  38:	e44e                	sd	s3,8(sp)
  3a:	1800                	addi	s0,sp,48
    for (int i = 0; i < 100; i++) {
  3c:	4481                	li	s1,0
  3e:	004c59b7          	lui	s3,0x4c5
  42:	b4098993          	addi	s3,s3,-1216 # 4c4b40 <base+0x4c3b30>
  46:	06400913          	li	s2,100
  4a:	a801                	j	5a <mixed+0x2c>
  4c:	87ce                	mv	a5,s3
        if (i % 2 == 0) {
            sleep(1);  // Simulate I/O operation
        } else {
            for (int j = 0; j < 5000000; j++) { asm volatile("nop"); } // Optionally use 'nop' to prevent optimization}  // CPU-intensive work
  4e:	0001                	nop
  50:	37fd                	addiw	a5,a5,-1
  52:	fff5                	bnez	a5,4e <mixed+0x20>
    for (int i = 0; i < 100; i++) {
  54:	2485                	addiw	s1,s1,1
  56:	01248b63          	beq	s1,s2,6c <mixed+0x3e>
        if (i % 2 == 0) {
  5a:	0014f793          	andi	a5,s1,1
  5e:	f7fd                	bnez	a5,4c <mixed+0x1e>
            sleep(1);  // Simulate I/O operation
  60:	4505                	li	a0,1
  62:	00000097          	auipc	ra,0x0
  66:	3d2080e7          	jalr	978(ra) # 434 <sleep>
  6a:	b7ed                	j	54 <mixed+0x26>

        }
        //printf("Mixed process %d: iteration %d\n", id, i);
    }
    exit(0);
  6c:	4501                	li	a0,0
  6e:	00000097          	auipc	ra,0x0
  72:	336080e7          	jalr	822(ra) # 3a4 <exit>

0000000000000076 <main>:
}

int main(int argc, char *argv[]) {
  76:	1101                	addi	sp,sp,-32
  78:	ec06                	sd	ra,24(sp)
  7a:	e822                	sd	s0,16(sp)
  7c:	e426                	sd	s1,8(sp)
  7e:	1000                	addi	s0,sp,32
    int pids[NUM_PROCESSES];

    for (int i = 0; i < NUM_PROCESSES; i++) {
  80:	4481                	li	s1,0
        pids[i] = fork();
  82:	00000097          	auipc	ra,0x0
  86:	31a080e7          	jalr	794(ra) # 39c <fork>
        if (pids[i] < 0) {
  8a:	02054363          	bltz	a0,b0 <main+0x3a>
            printf("Fork failed\n");
            exit(1);
        } else if (pids[i] == 0) {
  8e:	e521                	bnez	a0,d6 <main+0x60>
            // Child process
            switch (i) {
  90:	478d                	li	a5,3
  92:	0297cd63          	blt	a5,s1,cc <main+0x56>
  96:	4785                	li	a5,1
  98:	0297c963          	blt	a5,s1,ca <main+0x54>
  9c:	0004879b          	sext.w	a5,s1
  a0:	4705                	li	a4,1
  a2:	06f76c63          	bltu	a4,a5,11a <main+0xa4>
                case 0:
                case 1:
                    io_bound(i);
  a6:	8526                	mv	a0,s1
  a8:	00000097          	auipc	ra,0x0
  ac:	f58080e7          	jalr	-168(ra) # 0 <io_bound>
            printf("Fork failed\n");
  b0:	00001517          	auipc	a0,0x1
  b4:	84050513          	addi	a0,a0,-1984 # 8f0 <malloc+0x104>
  b8:	00000097          	auipc	ra,0x0
  bc:	67c080e7          	jalr	1660(ra) # 734 <printf>
            exit(1);
  c0:	4505                	li	a0,1
  c2:	00000097          	auipc	ra,0x0
  c6:	2e2080e7          	jalr	738(ra) # 3a4 <exit>
  ca:	a001                	j	ca <main+0x54>
                case 2:
                case 3:
                    cpu_bound(i);
                    break;
                case 4:
                    mixed(i);
  cc:	4511                	li	a0,4
  ce:	00000097          	auipc	ra,0x0
  d2:	f60080e7          	jalr	-160(ra) # 2e <mixed>
    for (int i = 0; i < NUM_PROCESSES; i++) {
  d6:	2485                	addiw	s1,s1,1
  d8:	4795                	li	a5,5
  da:	faf494e3          	bne	s1,a5,82 <main+0xc>
        }
    }

    // Parent process
    for (int i = 0; i < NUM_PROCESSES; i++) {
        wait(0);
  de:	4501                	li	a0,0
  e0:	00000097          	auipc	ra,0x0
  e4:	2cc080e7          	jalr	716(ra) # 3ac <wait>
  e8:	4501                	li	a0,0
  ea:	00000097          	auipc	ra,0x0
  ee:	2c2080e7          	jalr	706(ra) # 3ac <wait>
  f2:	4501                	li	a0,0
  f4:	00000097          	auipc	ra,0x0
  f8:	2b8080e7          	jalr	696(ra) # 3ac <wait>
  fc:	4501                	li	a0,0
  fe:	00000097          	auipc	ra,0x0
 102:	2ae080e7          	jalr	686(ra) # 3ac <wait>
 106:	4501                	li	a0,0
 108:	00000097          	auipc	ra,0x0
 10c:	2a4080e7          	jalr	676(ra) # 3ac <wait>
    }

    //printf("All processes completed\n");
    exit(0);
 110:	4501                	li	a0,0
 112:	00000097          	auipc	ra,0x0
 116:	292080e7          	jalr	658(ra) # 3a4 <exit>
    for (int i = 0; i < NUM_PROCESSES; i++) {
 11a:	2485                	addiw	s1,s1,1
 11c:	b79d                	j	82 <main+0xc>

000000000000011e <_main>:
//
// wrapper so that it's OK if main() does not call exit().
//
void
_main()
{
 11e:	1141                	addi	sp,sp,-16
 120:	e406                	sd	ra,8(sp)
 122:	e022                	sd	s0,0(sp)
 124:	0800                	addi	s0,sp,16
  extern int main();
  main();
 126:	00000097          	auipc	ra,0x0
 12a:	f50080e7          	jalr	-176(ra) # 76 <main>
  exit(0);
 12e:	4501                	li	a0,0
 130:	00000097          	auipc	ra,0x0
 134:	274080e7          	jalr	628(ra) # 3a4 <exit>

0000000000000138 <strcpy>:
}

char*
strcpy(char *s, const char *t)
{
 138:	1141                	addi	sp,sp,-16
 13a:	e422                	sd	s0,8(sp)
 13c:	0800                	addi	s0,sp,16
  char *os;

  os = s;
  while((*s++ = *t++) != 0)
 13e:	87aa                	mv	a5,a0
 140:	0585                	addi	a1,a1,1
 142:	0785                	addi	a5,a5,1
 144:	fff5c703          	lbu	a4,-1(a1)
 148:	fee78fa3          	sb	a4,-1(a5)
 14c:	fb75                	bnez	a4,140 <strcpy+0x8>
    ;
  return os;
}
 14e:	6422                	ld	s0,8(sp)
 150:	0141                	addi	sp,sp,16
 152:	8082                	ret

0000000000000154 <strcmp>:

int
strcmp(const char *p, const char *q)
{
 154:	1141                	addi	sp,sp,-16
 156:	e422                	sd	s0,8(sp)
 158:	0800                	addi	s0,sp,16
  while(*p && *p == *q)
 15a:	00054783          	lbu	a5,0(a0)
 15e:	cb91                	beqz	a5,172 <strcmp+0x1e>
 160:	0005c703          	lbu	a4,0(a1)
 164:	00f71763          	bne	a4,a5,172 <strcmp+0x1e>
    p++, q++;
 168:	0505                	addi	a0,a0,1
 16a:	0585                	addi	a1,a1,1
  while(*p && *p == *q)
 16c:	00054783          	lbu	a5,0(a0)
 170:	fbe5                	bnez	a5,160 <strcmp+0xc>
  return (uchar)*p - (uchar)*q;
 172:	0005c503          	lbu	a0,0(a1)
}
 176:	40a7853b          	subw	a0,a5,a0
 17a:	6422                	ld	s0,8(sp)
 17c:	0141                	addi	sp,sp,16
 17e:	8082                	ret

0000000000000180 <strlen>:

uint
strlen(const char *s)
{
 180:	1141                	addi	sp,sp,-16
 182:	e422                	sd	s0,8(sp)
 184:	0800                	addi	s0,sp,16
  int n;

  for(n = 0; s[n]; n++)
 186:	00054783          	lbu	a5,0(a0)
 18a:	cf91                	beqz	a5,1a6 <strlen+0x26>
 18c:	0505                	addi	a0,a0,1
 18e:	87aa                	mv	a5,a0
 190:	86be                	mv	a3,a5
 192:	0785                	addi	a5,a5,1
 194:	fff7c703          	lbu	a4,-1(a5)
 198:	ff65                	bnez	a4,190 <strlen+0x10>
 19a:	40a6853b          	subw	a0,a3,a0
 19e:	2505                	addiw	a0,a0,1
    ;
  return n;
}
 1a0:	6422                	ld	s0,8(sp)
 1a2:	0141                	addi	sp,sp,16
 1a4:	8082                	ret
  for(n = 0; s[n]; n++)
 1a6:	4501                	li	a0,0
 1a8:	bfe5                	j	1a0 <strlen+0x20>

00000000000001aa <memset>:

void*
memset(void *dst, int c, uint n)
{
 1aa:	1141                	addi	sp,sp,-16
 1ac:	e422                	sd	s0,8(sp)
 1ae:	0800                	addi	s0,sp,16
  char *cdst = (char *) dst;
  int i;
  for(i = 0; i < n; i++){
 1b0:	ca19                	beqz	a2,1c6 <memset+0x1c>
 1b2:	87aa                	mv	a5,a0
 1b4:	1602                	slli	a2,a2,0x20
 1b6:	9201                	srli	a2,a2,0x20
 1b8:	00a60733          	add	a4,a2,a0
    cdst[i] = c;
 1bc:	00b78023          	sb	a1,0(a5)
  for(i = 0; i < n; i++){
 1c0:	0785                	addi	a5,a5,1
 1c2:	fee79de3          	bne	a5,a4,1bc <memset+0x12>
  }
  return dst;
}
 1c6:	6422                	ld	s0,8(sp)
 1c8:	0141                	addi	sp,sp,16
 1ca:	8082                	ret

00000000000001cc <strchr>:

char*
strchr(const char *s, char c)
{
 1cc:	1141                	addi	sp,sp,-16
 1ce:	e422                	sd	s0,8(sp)
 1d0:	0800                	addi	s0,sp,16
  for(; *s; s++)
 1d2:	00054783          	lbu	a5,0(a0)
 1d6:	cb99                	beqz	a5,1ec <strchr+0x20>
    if(*s == c)
 1d8:	00f58763          	beq	a1,a5,1e6 <strchr+0x1a>
  for(; *s; s++)
 1dc:	0505                	addi	a0,a0,1
 1de:	00054783          	lbu	a5,0(a0)
 1e2:	fbfd                	bnez	a5,1d8 <strchr+0xc>
      return (char*)s;
  return 0;
 1e4:	4501                	li	a0,0
}
 1e6:	6422                	ld	s0,8(sp)
 1e8:	0141                	addi	sp,sp,16
 1ea:	8082                	ret
  return 0;
 1ec:	4501                	li	a0,0
 1ee:	bfe5                	j	1e6 <strchr+0x1a>

00000000000001f0 <gets>:

char*
gets(char *buf, int max)
{
 1f0:	711d                	addi	sp,sp,-96
 1f2:	ec86                	sd	ra,88(sp)
 1f4:	e8a2                	sd	s0,80(sp)
 1f6:	e4a6                	sd	s1,72(sp)
 1f8:	e0ca                	sd	s2,64(sp)
 1fa:	fc4e                	sd	s3,56(sp)
 1fc:	f852                	sd	s4,48(sp)
 1fe:	f456                	sd	s5,40(sp)
 200:	f05a                	sd	s6,32(sp)
 202:	ec5e                	sd	s7,24(sp)
 204:	1080                	addi	s0,sp,96
 206:	8baa                	mv	s7,a0
 208:	8a2e                	mv	s4,a1
  int i, cc;
  char c;

  for(i=0; i+1 < max; ){
 20a:	892a                	mv	s2,a0
 20c:	4481                	li	s1,0
    cc = read(0, &c, 1);
    if(cc < 1)
      break;
    buf[i++] = c;
    if(c == '\n' || c == '\r')
 20e:	4aa9                	li	s5,10
 210:	4b35                	li	s6,13
  for(i=0; i+1 < max; ){
 212:	89a6                	mv	s3,s1
 214:	2485                	addiw	s1,s1,1
 216:	0344d863          	bge	s1,s4,246 <gets+0x56>
    cc = read(0, &c, 1);
 21a:	4605                	li	a2,1
 21c:	faf40593          	addi	a1,s0,-81
 220:	4501                	li	a0,0
 222:	00000097          	auipc	ra,0x0
 226:	19a080e7          	jalr	410(ra) # 3bc <read>
    if(cc < 1)
 22a:	00a05e63          	blez	a0,246 <gets+0x56>
    buf[i++] = c;
 22e:	faf44783          	lbu	a5,-81(s0)
 232:	00f90023          	sb	a5,0(s2)
    if(c == '\n' || c == '\r')
 236:	01578763          	beq	a5,s5,244 <gets+0x54>
 23a:	0905                	addi	s2,s2,1
 23c:	fd679be3          	bne	a5,s6,212 <gets+0x22>
    buf[i++] = c;
 240:	89a6                	mv	s3,s1
 242:	a011                	j	246 <gets+0x56>
 244:	89a6                	mv	s3,s1
      break;
  }
  buf[i] = '\0';
 246:	99de                	add	s3,s3,s7
 248:	00098023          	sb	zero,0(s3)
  return buf;
}
 24c:	855e                	mv	a0,s7
 24e:	60e6                	ld	ra,88(sp)
 250:	6446                	ld	s0,80(sp)
 252:	64a6                	ld	s1,72(sp)
 254:	6906                	ld	s2,64(sp)
 256:	79e2                	ld	s3,56(sp)
 258:	7a42                	ld	s4,48(sp)
 25a:	7aa2                	ld	s5,40(sp)
 25c:	7b02                	ld	s6,32(sp)
 25e:	6be2                	ld	s7,24(sp)
 260:	6125                	addi	sp,sp,96
 262:	8082                	ret

0000000000000264 <stat>:

int
stat(const char *n, struct stat *st)
{
 264:	1101                	addi	sp,sp,-32
 266:	ec06                	sd	ra,24(sp)
 268:	e822                	sd	s0,16(sp)
 26a:	e04a                	sd	s2,0(sp)
 26c:	1000                	addi	s0,sp,32
 26e:	892e                	mv	s2,a1
  int fd;
  int r;

  fd = open(n, O_RDONLY);
 270:	4581                	li	a1,0
 272:	00000097          	auipc	ra,0x0
 276:	172080e7          	jalr	370(ra) # 3e4 <open>
  if(fd < 0)
 27a:	02054663          	bltz	a0,2a6 <stat+0x42>
 27e:	e426                	sd	s1,8(sp)
 280:	84aa                	mv	s1,a0
    return -1;
  r = fstat(fd, st);
 282:	85ca                	mv	a1,s2
 284:	00000097          	auipc	ra,0x0
 288:	178080e7          	jalr	376(ra) # 3fc <fstat>
 28c:	892a                	mv	s2,a0
  close(fd);
 28e:	8526                	mv	a0,s1
 290:	00000097          	auipc	ra,0x0
 294:	13c080e7          	jalr	316(ra) # 3cc <close>
  return r;
 298:	64a2                	ld	s1,8(sp)
}
 29a:	854a                	mv	a0,s2
 29c:	60e2                	ld	ra,24(sp)
 29e:	6442                	ld	s0,16(sp)
 2a0:	6902                	ld	s2,0(sp)
 2a2:	6105                	addi	sp,sp,32
 2a4:	8082                	ret
    return -1;
 2a6:	597d                	li	s2,-1
 2a8:	bfcd                	j	29a <stat+0x36>

00000000000002aa <atoi>:

int
atoi(const char *s)
{
 2aa:	1141                	addi	sp,sp,-16
 2ac:	e422                	sd	s0,8(sp)
 2ae:	0800                	addi	s0,sp,16
  int n;

  n = 0;
  while('0' <= *s && *s <= '9')
 2b0:	00054683          	lbu	a3,0(a0)
 2b4:	fd06879b          	addiw	a5,a3,-48
 2b8:	0ff7f793          	zext.b	a5,a5
 2bc:	4625                	li	a2,9
 2be:	02f66863          	bltu	a2,a5,2ee <atoi+0x44>
 2c2:	872a                	mv	a4,a0
  n = 0;
 2c4:	4501                	li	a0,0
    n = n*10 + *s++ - '0';
 2c6:	0705                	addi	a4,a4,1
 2c8:	0025179b          	slliw	a5,a0,0x2
 2cc:	9fa9                	addw	a5,a5,a0
 2ce:	0017979b          	slliw	a5,a5,0x1
 2d2:	9fb5                	addw	a5,a5,a3
 2d4:	fd07851b          	addiw	a0,a5,-48
  while('0' <= *s && *s <= '9')
 2d8:	00074683          	lbu	a3,0(a4)
 2dc:	fd06879b          	addiw	a5,a3,-48
 2e0:	0ff7f793          	zext.b	a5,a5
 2e4:	fef671e3          	bgeu	a2,a5,2c6 <atoi+0x1c>
  return n;
}
 2e8:	6422                	ld	s0,8(sp)
 2ea:	0141                	addi	sp,sp,16
 2ec:	8082                	ret
  n = 0;
 2ee:	4501                	li	a0,0
 2f0:	bfe5                	j	2e8 <atoi+0x3e>

00000000000002f2 <memmove>:

void*
memmove(void *vdst, const void *vsrc, int n)
{
 2f2:	1141                	addi	sp,sp,-16
 2f4:	e422                	sd	s0,8(sp)
 2f6:	0800                	addi	s0,sp,16
  char *dst;
  const char *src;

  dst = vdst;
  src = vsrc;
  if (src > dst) {
 2f8:	02b57463          	bgeu	a0,a1,320 <memmove+0x2e>
    while(n-- > 0)
 2fc:	00c05f63          	blez	a2,31a <memmove+0x28>
 300:	1602                	slli	a2,a2,0x20
 302:	9201                	srli	a2,a2,0x20
 304:	00c507b3          	add	a5,a0,a2
  dst = vdst;
 308:	872a                	mv	a4,a0
      *dst++ = *src++;
 30a:	0585                	addi	a1,a1,1
 30c:	0705                	addi	a4,a4,1
 30e:	fff5c683          	lbu	a3,-1(a1)
 312:	fed70fa3          	sb	a3,-1(a4)
    while(n-- > 0)
 316:	fef71ae3          	bne	a4,a5,30a <memmove+0x18>
    src += n;
    while(n-- > 0)
      *--dst = *--src;
  }
  return vdst;
}
 31a:	6422                	ld	s0,8(sp)
 31c:	0141                	addi	sp,sp,16
 31e:	8082                	ret
    dst += n;
 320:	00c50733          	add	a4,a0,a2
    src += n;
 324:	95b2                	add	a1,a1,a2
    while(n-- > 0)
 326:	fec05ae3          	blez	a2,31a <memmove+0x28>
 32a:	fff6079b          	addiw	a5,a2,-1
 32e:	1782                	slli	a5,a5,0x20
 330:	9381                	srli	a5,a5,0x20
 332:	fff7c793          	not	a5,a5
 336:	97ba                	add	a5,a5,a4
      *--dst = *--src;
 338:	15fd                	addi	a1,a1,-1
 33a:	177d                	addi	a4,a4,-1
 33c:	0005c683          	lbu	a3,0(a1)
 340:	00d70023          	sb	a3,0(a4)
    while(n-- > 0)
 344:	fee79ae3          	bne	a5,a4,338 <memmove+0x46>
 348:	bfc9                	j	31a <memmove+0x28>

000000000000034a <memcmp>:

int
memcmp(const void *s1, const void *s2, uint n)
{
 34a:	1141                	addi	sp,sp,-16
 34c:	e422                	sd	s0,8(sp)
 34e:	0800                	addi	s0,sp,16
  const char *p1 = s1, *p2 = s2;
  while (n-- > 0) {
 350:	ca05                	beqz	a2,380 <memcmp+0x36>
 352:	fff6069b          	addiw	a3,a2,-1
 356:	1682                	slli	a3,a3,0x20
 358:	9281                	srli	a3,a3,0x20
 35a:	0685                	addi	a3,a3,1
 35c:	96aa                	add	a3,a3,a0
    if (*p1 != *p2) {
 35e:	00054783          	lbu	a5,0(a0)
 362:	0005c703          	lbu	a4,0(a1)
 366:	00e79863          	bne	a5,a4,376 <memcmp+0x2c>
      return *p1 - *p2;
    }
    p1++;
 36a:	0505                	addi	a0,a0,1
    p2++;
 36c:	0585                	addi	a1,a1,1
  while (n-- > 0) {
 36e:	fed518e3          	bne	a0,a3,35e <memcmp+0x14>
  }
  return 0;
 372:	4501                	li	a0,0
 374:	a019                	j	37a <memcmp+0x30>
      return *p1 - *p2;
 376:	40e7853b          	subw	a0,a5,a4
}
 37a:	6422                	ld	s0,8(sp)
 37c:	0141                	addi	sp,sp,16
 37e:	8082                	ret
  return 0;
 380:	4501                	li	a0,0
 382:	bfe5                	j	37a <memcmp+0x30>

0000000000000384 <memcpy>:

void *
memcpy(void *dst, const void *src, uint n)
{
 384:	1141                	addi	sp,sp,-16
 386:	e406                	sd	ra,8(sp)
 388:	e022                	sd	s0,0(sp)
 38a:	0800                	addi	s0,sp,16
  return memmove(dst, src, n);
 38c:	00000097          	auipc	ra,0x0
 390:	f66080e7          	jalr	-154(ra) # 2f2 <memmove>
}
 394:	60a2                	ld	ra,8(sp)
 396:	6402                	ld	s0,0(sp)
 398:	0141                	addi	sp,sp,16
 39a:	8082                	ret

000000000000039c <fork>:
# generated by usys.pl - do not edit
#include "kernel/syscall.h"
.global fork
fork:
 li a7, SYS_fork
 39c:	4885                	li	a7,1
 ecall
 39e:	00000073          	ecall
 ret
 3a2:	8082                	ret

00000000000003a4 <exit>:
.global exit
exit:
 li a7, SYS_exit
 3a4:	4889                	li	a7,2
 ecall
 3a6:	00000073          	ecall
 ret
 3aa:	8082                	ret

00000000000003ac <wait>:
.global wait
wait:
 li a7, SYS_wait
 3ac:	488d                	li	a7,3
 ecall
 3ae:	00000073          	ecall
 ret
 3b2:	8082                	ret

00000000000003b4 <pipe>:
.global pipe
pipe:
 li a7, SYS_pipe
 3b4:	4891                	li	a7,4
 ecall
 3b6:	00000073          	ecall
 ret
 3ba:	8082                	ret

00000000000003bc <read>:
.global read
read:
 li a7, SYS_read
 3bc:	4895                	li	a7,5
 ecall
 3be:	00000073          	ecall
 ret
 3c2:	8082                	ret

00000000000003c4 <write>:
.global write
write:
 li a7, SYS_write
 3c4:	48c1                	li	a7,16
 ecall
 3c6:	00000073          	ecall
 ret
 3ca:	8082                	ret

00000000000003cc <close>:
.global close
close:
 li a7, SYS_close
 3cc:	48d5                	li	a7,21
 ecall
 3ce:	00000073          	ecall
 ret
 3d2:	8082                	ret

00000000000003d4 <kill>:
.global kill
kill:
 li a7, SYS_kill
 3d4:	4899                	li	a7,6
 ecall
 3d6:	00000073          	ecall
 ret
 3da:	8082                	ret

00000000000003dc <exec>:
.global exec
exec:
 li a7, SYS_exec
 3dc:	489d                	li	a7,7
 ecall
 3de:	00000073          	ecall
 ret
 3e2:	8082                	ret

00000000000003e4 <open>:
.global open
open:
 li a7, SYS_open
 3e4:	48bd                	li	a7,15
 ecall
 3e6:	00000073          	ecall
 ret
 3ea:	8082                	ret

00000000000003ec <mknod>:
.global mknod
mknod:
 li a7, SYS_mknod
 3ec:	48c5                	li	a7,17
 ecall
 3ee:	00000073          	ecall
 ret
 3f2:	8082                	ret

00000000000003f4 <unlink>:
.global unlink
unlink:
 li a7, SYS_unlink
 3f4:	48c9                	li	a7,18
 ecall
 3f6:	00000073          	ecall
 ret
 3fa:	8082                	ret

00000000000003fc <fstat>:
.global fstat
fstat:
 li a7, SYS_fstat
 3fc:	48a1                	li	a7,8
 ecall
 3fe:	00000073          	ecall
 ret
 402:	8082                	ret

0000000000000404 <link>:
.global link
link:
 li a7, SYS_link
 404:	48cd                	li	a7,19
 ecall
 406:	00000073          	ecall
 ret
 40a:	8082                	ret

000000000000040c <mkdir>:
.global mkdir
mkdir:
 li a7, SYS_mkdir
 40c:	48d1                	li	a7,20
 ecall
 40e:	00000073          	ecall
 ret
 412:	8082                	ret

0000000000000414 <chdir>:
.global chdir
chdir:
 li a7, SYS_chdir
 414:	48a5                	li	a7,9
 ecall
 416:	00000073          	ecall
 ret
 41a:	8082                	ret

000000000000041c <dup>:
.global dup
dup:
 li a7, SYS_dup
 41c:	48a9                	li	a7,10
 ecall
 41e:	00000073          	ecall
 ret
 422:	8082                	ret

0000000000000424 <getpid>:
.global getpid
getpid:
 li a7, SYS_getpid
 424:	48ad                	li	a7,11
 ecall
 426:	00000073          	ecall
 ret
 42a:	8082                	ret

000000000000042c <sbrk>:
.global sbrk
sbrk:
 li a7, SYS_sbrk
 42c:	48b1                	li	a7,12
 ecall
 42e:	00000073          	ecall
 ret
 432:	8082                	ret

0000000000000434 <sleep>:
.global sleep
sleep:
 li a7, SYS_sleep
 434:	48b5                	li	a7,13
 ecall
 436:	00000073          	ecall
 ret
 43a:	8082                	ret

000000000000043c <uptime>:
.global uptime
uptime:
 li a7, SYS_uptime
 43c:	48b9                	li	a7,14
 ecall
 43e:	00000073          	ecall
 ret
 442:	8082                	ret

0000000000000444 <waitx>:
.global waitx
waitx:
 li a7, SYS_waitx
 444:	48d9                	li	a7,22
 ecall
 446:	00000073          	ecall
 ret
 44a:	8082                	ret

000000000000044c <getSysCount>:
.global getSysCount
getSysCount:
 li a7, SYS_getSysCount
 44c:	48dd                	li	a7,23
 ecall
 44e:	00000073          	ecall
 ret
 452:	8082                	ret

0000000000000454 <sigalarm>:
.global sigalarm
sigalarm:
 li a7, SYS_sigalarm
 454:	48e1                	li	a7,24
 ecall
 456:	00000073          	ecall
 ret
 45a:	8082                	ret

000000000000045c <sigreturn>:
.global sigreturn
sigreturn:
 li a7, SYS_sigreturn
 45c:	48e5                	li	a7,25
 ecall
 45e:	00000073          	ecall
 ret
 462:	8082                	ret

0000000000000464 <settickets>:
.global settickets
settickets:
 li a7, SYS_settickets
 464:	48e9                	li	a7,26
 ecall
 466:	00000073          	ecall
 ret
 46a:	8082                	ret

000000000000046c <putc>:

static char digits[] = "0123456789ABCDEF";

static void
putc(int fd, char c)
{
 46c:	1101                	addi	sp,sp,-32
 46e:	ec06                	sd	ra,24(sp)
 470:	e822                	sd	s0,16(sp)
 472:	1000                	addi	s0,sp,32
 474:	feb407a3          	sb	a1,-17(s0)
  write(fd, &c, 1);
 478:	4605                	li	a2,1
 47a:	fef40593          	addi	a1,s0,-17
 47e:	00000097          	auipc	ra,0x0
 482:	f46080e7          	jalr	-186(ra) # 3c4 <write>
}
 486:	60e2                	ld	ra,24(sp)
 488:	6442                	ld	s0,16(sp)
 48a:	6105                	addi	sp,sp,32
 48c:	8082                	ret

000000000000048e <printint>:

static void
printint(int fd, int xx, int base, int sgn)
{
 48e:	7139                	addi	sp,sp,-64
 490:	fc06                	sd	ra,56(sp)
 492:	f822                	sd	s0,48(sp)
 494:	f426                	sd	s1,40(sp)
 496:	0080                	addi	s0,sp,64
 498:	84aa                	mv	s1,a0
  char buf[16];
  int i, neg;
  uint x;

  neg = 0;
  if(sgn && xx < 0){
 49a:	c299                	beqz	a3,4a0 <printint+0x12>
 49c:	0805cb63          	bltz	a1,532 <printint+0xa4>
    neg = 1;
    x = -xx;
  } else {
    x = xx;
 4a0:	2581                	sext.w	a1,a1
  neg = 0;
 4a2:	4881                	li	a7,0
 4a4:	fc040693          	addi	a3,s0,-64
  }

  i = 0;
 4a8:	4701                	li	a4,0
  do{
    buf[i++] = digits[x % base];
 4aa:	2601                	sext.w	a2,a2
 4ac:	00000517          	auipc	a0,0x0
 4b0:	4b450513          	addi	a0,a0,1204 # 960 <digits>
 4b4:	883a                	mv	a6,a4
 4b6:	2705                	addiw	a4,a4,1
 4b8:	02c5f7bb          	remuw	a5,a1,a2
 4bc:	1782                	slli	a5,a5,0x20
 4be:	9381                	srli	a5,a5,0x20
 4c0:	97aa                	add	a5,a5,a0
 4c2:	0007c783          	lbu	a5,0(a5)
 4c6:	00f68023          	sb	a5,0(a3)
  }while((x /= base) != 0);
 4ca:	0005879b          	sext.w	a5,a1
 4ce:	02c5d5bb          	divuw	a1,a1,a2
 4d2:	0685                	addi	a3,a3,1
 4d4:	fec7f0e3          	bgeu	a5,a2,4b4 <printint+0x26>
  if(neg)
 4d8:	00088c63          	beqz	a7,4f0 <printint+0x62>
    buf[i++] = '-';
 4dc:	fd070793          	addi	a5,a4,-48
 4e0:	00878733          	add	a4,a5,s0
 4e4:	02d00793          	li	a5,45
 4e8:	fef70823          	sb	a5,-16(a4)
 4ec:	0028071b          	addiw	a4,a6,2

  while(--i >= 0)
 4f0:	02e05c63          	blez	a4,528 <printint+0x9a>
 4f4:	f04a                	sd	s2,32(sp)
 4f6:	ec4e                	sd	s3,24(sp)
 4f8:	fc040793          	addi	a5,s0,-64
 4fc:	00e78933          	add	s2,a5,a4
 500:	fff78993          	addi	s3,a5,-1
 504:	99ba                	add	s3,s3,a4
 506:	377d                	addiw	a4,a4,-1
 508:	1702                	slli	a4,a4,0x20
 50a:	9301                	srli	a4,a4,0x20
 50c:	40e989b3          	sub	s3,s3,a4
    putc(fd, buf[i]);
 510:	fff94583          	lbu	a1,-1(s2)
 514:	8526                	mv	a0,s1
 516:	00000097          	auipc	ra,0x0
 51a:	f56080e7          	jalr	-170(ra) # 46c <putc>
  while(--i >= 0)
 51e:	197d                	addi	s2,s2,-1
 520:	ff3918e3          	bne	s2,s3,510 <printint+0x82>
 524:	7902                	ld	s2,32(sp)
 526:	69e2                	ld	s3,24(sp)
}
 528:	70e2                	ld	ra,56(sp)
 52a:	7442                	ld	s0,48(sp)
 52c:	74a2                	ld	s1,40(sp)
 52e:	6121                	addi	sp,sp,64
 530:	8082                	ret
    x = -xx;
 532:	40b005bb          	negw	a1,a1
    neg = 1;
 536:	4885                	li	a7,1
    x = -xx;
 538:	b7b5                	j	4a4 <printint+0x16>

000000000000053a <vprintf>:
}

// Print to the given fd. Only understands %d, %x, %p, %s.
void
vprintf(int fd, const char *fmt, va_list ap)
{
 53a:	715d                	addi	sp,sp,-80
 53c:	e486                	sd	ra,72(sp)
 53e:	e0a2                	sd	s0,64(sp)
 540:	f84a                	sd	s2,48(sp)
 542:	0880                	addi	s0,sp,80
  char *s;
  int c, i, state;

  state = 0;
  for(i = 0; fmt[i]; i++){
 544:	0005c903          	lbu	s2,0(a1)
 548:	1a090a63          	beqz	s2,6fc <vprintf+0x1c2>
 54c:	fc26                	sd	s1,56(sp)
 54e:	f44e                	sd	s3,40(sp)
 550:	f052                	sd	s4,32(sp)
 552:	ec56                	sd	s5,24(sp)
 554:	e85a                	sd	s6,16(sp)
 556:	e45e                	sd	s7,8(sp)
 558:	8aaa                	mv	s5,a0
 55a:	8bb2                	mv	s7,a2
 55c:	00158493          	addi	s1,a1,1
  state = 0;
 560:	4981                	li	s3,0
      if(c == '%'){
        state = '%';
      } else {
        putc(fd, c);
      }
    } else if(state == '%'){
 562:	02500a13          	li	s4,37
 566:	4b55                	li	s6,21
 568:	a839                	j	586 <vprintf+0x4c>
        putc(fd, c);
 56a:	85ca                	mv	a1,s2
 56c:	8556                	mv	a0,s5
 56e:	00000097          	auipc	ra,0x0
 572:	efe080e7          	jalr	-258(ra) # 46c <putc>
 576:	a019                	j	57c <vprintf+0x42>
    } else if(state == '%'){
 578:	01498d63          	beq	s3,s4,592 <vprintf+0x58>
  for(i = 0; fmt[i]; i++){
 57c:	0485                	addi	s1,s1,1
 57e:	fff4c903          	lbu	s2,-1(s1)
 582:	16090763          	beqz	s2,6f0 <vprintf+0x1b6>
    if(state == 0){
 586:	fe0999e3          	bnez	s3,578 <vprintf+0x3e>
      if(c == '%'){
 58a:	ff4910e3          	bne	s2,s4,56a <vprintf+0x30>
        state = '%';
 58e:	89d2                	mv	s3,s4
 590:	b7f5                	j	57c <vprintf+0x42>
      if(c == 'd'){
 592:	13490463          	beq	s2,s4,6ba <vprintf+0x180>
 596:	f9d9079b          	addiw	a5,s2,-99
 59a:	0ff7f793          	zext.b	a5,a5
 59e:	12fb6763          	bltu	s6,a5,6cc <vprintf+0x192>
 5a2:	f9d9079b          	addiw	a5,s2,-99
 5a6:	0ff7f713          	zext.b	a4,a5
 5aa:	12eb6163          	bltu	s6,a4,6cc <vprintf+0x192>
 5ae:	00271793          	slli	a5,a4,0x2
 5b2:	00000717          	auipc	a4,0x0
 5b6:	35670713          	addi	a4,a4,854 # 908 <malloc+0x11c>
 5ba:	97ba                	add	a5,a5,a4
 5bc:	439c                	lw	a5,0(a5)
 5be:	97ba                	add	a5,a5,a4
 5c0:	8782                	jr	a5
        printint(fd, va_arg(ap, int), 10, 1);
 5c2:	008b8913          	addi	s2,s7,8
 5c6:	4685                	li	a3,1
 5c8:	4629                	li	a2,10
 5ca:	000ba583          	lw	a1,0(s7)
 5ce:	8556                	mv	a0,s5
 5d0:	00000097          	auipc	ra,0x0
 5d4:	ebe080e7          	jalr	-322(ra) # 48e <printint>
 5d8:	8bca                	mv	s7,s2
      } else {
        // Unknown % sequence.  Print it to draw attention.
        putc(fd, '%');
        putc(fd, c);
      }
      state = 0;
 5da:	4981                	li	s3,0
 5dc:	b745                	j	57c <vprintf+0x42>
        printint(fd, va_arg(ap, uint64), 10, 0);
 5de:	008b8913          	addi	s2,s7,8
 5e2:	4681                	li	a3,0
 5e4:	4629                	li	a2,10
 5e6:	000ba583          	lw	a1,0(s7)
 5ea:	8556                	mv	a0,s5
 5ec:	00000097          	auipc	ra,0x0
 5f0:	ea2080e7          	jalr	-350(ra) # 48e <printint>
 5f4:	8bca                	mv	s7,s2
      state = 0;
 5f6:	4981                	li	s3,0
 5f8:	b751                	j	57c <vprintf+0x42>
        printint(fd, va_arg(ap, int), 16, 0);
 5fa:	008b8913          	addi	s2,s7,8
 5fe:	4681                	li	a3,0
 600:	4641                	li	a2,16
 602:	000ba583          	lw	a1,0(s7)
 606:	8556                	mv	a0,s5
 608:	00000097          	auipc	ra,0x0
 60c:	e86080e7          	jalr	-378(ra) # 48e <printint>
 610:	8bca                	mv	s7,s2
      state = 0;
 612:	4981                	li	s3,0
 614:	b7a5                	j	57c <vprintf+0x42>
 616:	e062                	sd	s8,0(sp)
        printptr(fd, va_arg(ap, uint64));
 618:	008b8c13          	addi	s8,s7,8
 61c:	000bb983          	ld	s3,0(s7)
  putc(fd, '0');
 620:	03000593          	li	a1,48
 624:	8556                	mv	a0,s5
 626:	00000097          	auipc	ra,0x0
 62a:	e46080e7          	jalr	-442(ra) # 46c <putc>
  putc(fd, 'x');
 62e:	07800593          	li	a1,120
 632:	8556                	mv	a0,s5
 634:	00000097          	auipc	ra,0x0
 638:	e38080e7          	jalr	-456(ra) # 46c <putc>
 63c:	4941                	li	s2,16
    putc(fd, digits[x >> (sizeof(uint64) * 8 - 4)]);
 63e:	00000b97          	auipc	s7,0x0
 642:	322b8b93          	addi	s7,s7,802 # 960 <digits>
 646:	03c9d793          	srli	a5,s3,0x3c
 64a:	97de                	add	a5,a5,s7
 64c:	0007c583          	lbu	a1,0(a5)
 650:	8556                	mv	a0,s5
 652:	00000097          	auipc	ra,0x0
 656:	e1a080e7          	jalr	-486(ra) # 46c <putc>
  for (i = 0; i < (sizeof(uint64) * 2); i++, x <<= 4)
 65a:	0992                	slli	s3,s3,0x4
 65c:	397d                	addiw	s2,s2,-1
 65e:	fe0914e3          	bnez	s2,646 <vprintf+0x10c>
        printptr(fd, va_arg(ap, uint64));
 662:	8be2                	mv	s7,s8
      state = 0;
 664:	4981                	li	s3,0
 666:	6c02                	ld	s8,0(sp)
 668:	bf11                	j	57c <vprintf+0x42>
        s = va_arg(ap, char*);
 66a:	008b8993          	addi	s3,s7,8
 66e:	000bb903          	ld	s2,0(s7)
        if(s == 0)
 672:	02090163          	beqz	s2,694 <vprintf+0x15a>
        while(*s != 0){
 676:	00094583          	lbu	a1,0(s2)
 67a:	c9a5                	beqz	a1,6ea <vprintf+0x1b0>
          putc(fd, *s);
 67c:	8556                	mv	a0,s5
 67e:	00000097          	auipc	ra,0x0
 682:	dee080e7          	jalr	-530(ra) # 46c <putc>
          s++;
 686:	0905                	addi	s2,s2,1
        while(*s != 0){
 688:	00094583          	lbu	a1,0(s2)
 68c:	f9e5                	bnez	a1,67c <vprintf+0x142>
        s = va_arg(ap, char*);
 68e:	8bce                	mv	s7,s3
      state = 0;
 690:	4981                	li	s3,0
 692:	b5ed                	j	57c <vprintf+0x42>
          s = "(null)";
 694:	00000917          	auipc	s2,0x0
 698:	26c90913          	addi	s2,s2,620 # 900 <malloc+0x114>
        while(*s != 0){
 69c:	02800593          	li	a1,40
 6a0:	bff1                	j	67c <vprintf+0x142>
        putc(fd, va_arg(ap, uint));
 6a2:	008b8913          	addi	s2,s7,8
 6a6:	000bc583          	lbu	a1,0(s7)
 6aa:	8556                	mv	a0,s5
 6ac:	00000097          	auipc	ra,0x0
 6b0:	dc0080e7          	jalr	-576(ra) # 46c <putc>
 6b4:	8bca                	mv	s7,s2
      state = 0;
 6b6:	4981                	li	s3,0
 6b8:	b5d1                	j	57c <vprintf+0x42>
        putc(fd, c);
 6ba:	02500593          	li	a1,37
 6be:	8556                	mv	a0,s5
 6c0:	00000097          	auipc	ra,0x0
 6c4:	dac080e7          	jalr	-596(ra) # 46c <putc>
      state = 0;
 6c8:	4981                	li	s3,0
 6ca:	bd4d                	j	57c <vprintf+0x42>
        putc(fd, '%');
 6cc:	02500593          	li	a1,37
 6d0:	8556                	mv	a0,s5
 6d2:	00000097          	auipc	ra,0x0
 6d6:	d9a080e7          	jalr	-614(ra) # 46c <putc>
        putc(fd, c);
 6da:	85ca                	mv	a1,s2
 6dc:	8556                	mv	a0,s5
 6de:	00000097          	auipc	ra,0x0
 6e2:	d8e080e7          	jalr	-626(ra) # 46c <putc>
      state = 0;
 6e6:	4981                	li	s3,0
 6e8:	bd51                	j	57c <vprintf+0x42>
        s = va_arg(ap, char*);
 6ea:	8bce                	mv	s7,s3
      state = 0;
 6ec:	4981                	li	s3,0
 6ee:	b579                	j	57c <vprintf+0x42>
 6f0:	74e2                	ld	s1,56(sp)
 6f2:	79a2                	ld	s3,40(sp)
 6f4:	7a02                	ld	s4,32(sp)
 6f6:	6ae2                	ld	s5,24(sp)
 6f8:	6b42                	ld	s6,16(sp)
 6fa:	6ba2                	ld	s7,8(sp)
    }
  }
}
 6fc:	60a6                	ld	ra,72(sp)
 6fe:	6406                	ld	s0,64(sp)
 700:	7942                	ld	s2,48(sp)
 702:	6161                	addi	sp,sp,80
 704:	8082                	ret

0000000000000706 <fprintf>:

void
fprintf(int fd, const char *fmt, ...)
{
 706:	715d                	addi	sp,sp,-80
 708:	ec06                	sd	ra,24(sp)
 70a:	e822                	sd	s0,16(sp)
 70c:	1000                	addi	s0,sp,32
 70e:	e010                	sd	a2,0(s0)
 710:	e414                	sd	a3,8(s0)
 712:	e818                	sd	a4,16(s0)
 714:	ec1c                	sd	a5,24(s0)
 716:	03043023          	sd	a6,32(s0)
 71a:	03143423          	sd	a7,40(s0)
  va_list ap;

  va_start(ap, fmt);
 71e:	fe843423          	sd	s0,-24(s0)
  vprintf(fd, fmt, ap);
 722:	8622                	mv	a2,s0
 724:	00000097          	auipc	ra,0x0
 728:	e16080e7          	jalr	-490(ra) # 53a <vprintf>
}
 72c:	60e2                	ld	ra,24(sp)
 72e:	6442                	ld	s0,16(sp)
 730:	6161                	addi	sp,sp,80
 732:	8082                	ret

0000000000000734 <printf>:

void
printf(const char *fmt, ...)
{
 734:	711d                	addi	sp,sp,-96
 736:	ec06                	sd	ra,24(sp)
 738:	e822                	sd	s0,16(sp)
 73a:	1000                	addi	s0,sp,32
 73c:	e40c                	sd	a1,8(s0)
 73e:	e810                	sd	a2,16(s0)
 740:	ec14                	sd	a3,24(s0)
 742:	f018                	sd	a4,32(s0)
 744:	f41c                	sd	a5,40(s0)
 746:	03043823          	sd	a6,48(s0)
 74a:	03143c23          	sd	a7,56(s0)
  va_list ap;

  va_start(ap, fmt);
 74e:	00840613          	addi	a2,s0,8
 752:	fec43423          	sd	a2,-24(s0)
  vprintf(1, fmt, ap);
 756:	85aa                	mv	a1,a0
 758:	4505                	li	a0,1
 75a:	00000097          	auipc	ra,0x0
 75e:	de0080e7          	jalr	-544(ra) # 53a <vprintf>
}
 762:	60e2                	ld	ra,24(sp)
 764:	6442                	ld	s0,16(sp)
 766:	6125                	addi	sp,sp,96
 768:	8082                	ret

000000000000076a <free>:
static Header base;
static Header *freep;

void
free(void *ap)
{
 76a:	1141                	addi	sp,sp,-16
 76c:	e422                	sd	s0,8(sp)
 76e:	0800                	addi	s0,sp,16
  Header *bp, *p;

  bp = (Header*)ap - 1;
 770:	ff050693          	addi	a3,a0,-16
  for(p = freep; !(bp > p && bp < p->s.ptr); p = p->s.ptr)
 774:	00001797          	auipc	a5,0x1
 778:	88c7b783          	ld	a5,-1908(a5) # 1000 <freep>
 77c:	a02d                	j	7a6 <free+0x3c>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
      break;
  if(bp + bp->s.size == p->s.ptr){
    bp->s.size += p->s.ptr->s.size;
 77e:	4618                	lw	a4,8(a2)
 780:	9f2d                	addw	a4,a4,a1
 782:	fee52c23          	sw	a4,-8(a0)
    bp->s.ptr = p->s.ptr->s.ptr;
 786:	6398                	ld	a4,0(a5)
 788:	6310                	ld	a2,0(a4)
 78a:	a83d                	j	7c8 <free+0x5e>
  } else
    bp->s.ptr = p->s.ptr;
  if(p + p->s.size == bp){
    p->s.size += bp->s.size;
 78c:	ff852703          	lw	a4,-8(a0)
 790:	9f31                	addw	a4,a4,a2
 792:	c798                	sw	a4,8(a5)
    p->s.ptr = bp->s.ptr;
 794:	ff053683          	ld	a3,-16(a0)
 798:	a091                	j	7dc <free+0x72>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
 79a:	6398                	ld	a4,0(a5)
 79c:	00e7e463          	bltu	a5,a4,7a4 <free+0x3a>
 7a0:	00e6ea63          	bltu	a3,a4,7b4 <free+0x4a>
{
 7a4:	87ba                	mv	a5,a4
  for(p = freep; !(bp > p && bp < p->s.ptr); p = p->s.ptr)
 7a6:	fed7fae3          	bgeu	a5,a3,79a <free+0x30>
 7aa:	6398                	ld	a4,0(a5)
 7ac:	00e6e463          	bltu	a3,a4,7b4 <free+0x4a>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
 7b0:	fee7eae3          	bltu	a5,a4,7a4 <free+0x3a>
  if(bp + bp->s.size == p->s.ptr){
 7b4:	ff852583          	lw	a1,-8(a0)
 7b8:	6390                	ld	a2,0(a5)
 7ba:	02059813          	slli	a6,a1,0x20
 7be:	01c85713          	srli	a4,a6,0x1c
 7c2:	9736                	add	a4,a4,a3
 7c4:	fae60de3          	beq	a2,a4,77e <free+0x14>
    bp->s.ptr = p->s.ptr->s.ptr;
 7c8:	fec53823          	sd	a2,-16(a0)
  if(p + p->s.size == bp){
 7cc:	4790                	lw	a2,8(a5)
 7ce:	02061593          	slli	a1,a2,0x20
 7d2:	01c5d713          	srli	a4,a1,0x1c
 7d6:	973e                	add	a4,a4,a5
 7d8:	fae68ae3          	beq	a3,a4,78c <free+0x22>
    p->s.ptr = bp->s.ptr;
 7dc:	e394                	sd	a3,0(a5)
  } else
    p->s.ptr = bp;
  freep = p;
 7de:	00001717          	auipc	a4,0x1
 7e2:	82f73123          	sd	a5,-2014(a4) # 1000 <freep>
}
 7e6:	6422                	ld	s0,8(sp)
 7e8:	0141                	addi	sp,sp,16
 7ea:	8082                	ret

00000000000007ec <malloc>:
  return freep;
}

void*
malloc(uint nbytes)
{
 7ec:	7139                	addi	sp,sp,-64
 7ee:	fc06                	sd	ra,56(sp)
 7f0:	f822                	sd	s0,48(sp)
 7f2:	f426                	sd	s1,40(sp)
 7f4:	ec4e                	sd	s3,24(sp)
 7f6:	0080                	addi	s0,sp,64
  Header *p, *prevp;
  uint nunits;

  nunits = (nbytes + sizeof(Header) - 1)/sizeof(Header) + 1;
 7f8:	02051493          	slli	s1,a0,0x20
 7fc:	9081                	srli	s1,s1,0x20
 7fe:	04bd                	addi	s1,s1,15
 800:	8091                	srli	s1,s1,0x4
 802:	0014899b          	addiw	s3,s1,1
 806:	0485                	addi	s1,s1,1
  if((prevp = freep) == 0){
 808:	00000517          	auipc	a0,0x0
 80c:	7f853503          	ld	a0,2040(a0) # 1000 <freep>
 810:	c915                	beqz	a0,844 <malloc+0x58>
    base.s.ptr = freep = prevp = &base;
    base.s.size = 0;
  }
  for(p = prevp->s.ptr; ; prevp = p, p = p->s.ptr){
 812:	611c                	ld	a5,0(a0)
    if(p->s.size >= nunits){
 814:	4798                	lw	a4,8(a5)
 816:	08977e63          	bgeu	a4,s1,8b2 <malloc+0xc6>
 81a:	f04a                	sd	s2,32(sp)
 81c:	e852                	sd	s4,16(sp)
 81e:	e456                	sd	s5,8(sp)
 820:	e05a                	sd	s6,0(sp)
  if(nu < 4096)
 822:	8a4e                	mv	s4,s3
 824:	0009871b          	sext.w	a4,s3
 828:	6685                	lui	a3,0x1
 82a:	00d77363          	bgeu	a4,a3,830 <malloc+0x44>
 82e:	6a05                	lui	s4,0x1
 830:	000a0b1b          	sext.w	s6,s4
  p = sbrk(nu * sizeof(Header));
 834:	004a1a1b          	slliw	s4,s4,0x4
        p->s.size = nunits;
      }
      freep = prevp;
      return (void*)(p + 1);
    }
    if(p == freep)
 838:	00000917          	auipc	s2,0x0
 83c:	7c890913          	addi	s2,s2,1992 # 1000 <freep>
  if(p == (char*)-1)
 840:	5afd                	li	s5,-1
 842:	a091                	j	886 <malloc+0x9a>
 844:	f04a                	sd	s2,32(sp)
 846:	e852                	sd	s4,16(sp)
 848:	e456                	sd	s5,8(sp)
 84a:	e05a                	sd	s6,0(sp)
    base.s.ptr = freep = prevp = &base;
 84c:	00000797          	auipc	a5,0x0
 850:	7c478793          	addi	a5,a5,1988 # 1010 <base>
 854:	00000717          	auipc	a4,0x0
 858:	7af73623          	sd	a5,1964(a4) # 1000 <freep>
 85c:	e39c                	sd	a5,0(a5)
    base.s.size = 0;
 85e:	0007a423          	sw	zero,8(a5)
    if(p->s.size >= nunits){
 862:	b7c1                	j	822 <malloc+0x36>
        prevp->s.ptr = p->s.ptr;
 864:	6398                	ld	a4,0(a5)
 866:	e118                	sd	a4,0(a0)
 868:	a08d                	j	8ca <malloc+0xde>
  hp->s.size = nu;
 86a:	01652423          	sw	s6,8(a0)
  free((void*)(hp + 1));
 86e:	0541                	addi	a0,a0,16
 870:	00000097          	auipc	ra,0x0
 874:	efa080e7          	jalr	-262(ra) # 76a <free>
  return freep;
 878:	00093503          	ld	a0,0(s2)
      if((p = morecore(nunits)) == 0)
 87c:	c13d                	beqz	a0,8e2 <malloc+0xf6>
  for(p = prevp->s.ptr; ; prevp = p, p = p->s.ptr){
 87e:	611c                	ld	a5,0(a0)
    if(p->s.size >= nunits){
 880:	4798                	lw	a4,8(a5)
 882:	02977463          	bgeu	a4,s1,8aa <malloc+0xbe>
    if(p == freep)
 886:	00093703          	ld	a4,0(s2)
 88a:	853e                	mv	a0,a5
 88c:	fef719e3          	bne	a4,a5,87e <malloc+0x92>
  p = sbrk(nu * sizeof(Header));
 890:	8552                	mv	a0,s4
 892:	00000097          	auipc	ra,0x0
 896:	b9a080e7          	jalr	-1126(ra) # 42c <sbrk>
  if(p == (char*)-1)
 89a:	fd5518e3          	bne	a0,s5,86a <malloc+0x7e>
        return 0;
 89e:	4501                	li	a0,0
 8a0:	7902                	ld	s2,32(sp)
 8a2:	6a42                	ld	s4,16(sp)
 8a4:	6aa2                	ld	s5,8(sp)
 8a6:	6b02                	ld	s6,0(sp)
 8a8:	a03d                	j	8d6 <malloc+0xea>
 8aa:	7902                	ld	s2,32(sp)
 8ac:	6a42                	ld	s4,16(sp)
 8ae:	6aa2                	ld	s5,8(sp)
 8b0:	6b02                	ld	s6,0(sp)
      if(p->s.size == nunits)
 8b2:	fae489e3          	beq	s1,a4,864 <malloc+0x78>
        p->s.size -= nunits;
 8b6:	4137073b          	subw	a4,a4,s3
 8ba:	c798                	sw	a4,8(a5)
        p += p->s.size;
 8bc:	02071693          	slli	a3,a4,0x20
 8c0:	01c6d713          	srli	a4,a3,0x1c
 8c4:	97ba                	add	a5,a5,a4
        p->s.size = nunits;
 8c6:	0137a423          	sw	s3,8(a5)
      freep = prevp;
 8ca:	00000717          	auipc	a4,0x0
 8ce:	72a73b23          	sd	a0,1846(a4) # 1000 <freep>
      return (void*)(p + 1);
 8d2:	01078513          	addi	a0,a5,16
  }
}
 8d6:	70e2                	ld	ra,56(sp)
 8d8:	7442                	ld	s0,48(sp)
 8da:	74a2                	ld	s1,40(sp)
 8dc:	69e2                	ld	s3,24(sp)
 8de:	6121                	addi	sp,sp,64
 8e0:	8082                	ret
 8e2:	7902                	ld	s2,32(sp)
 8e4:	6a42                	ld	s4,16(sp)
 8e6:	6aa2                	ld	s5,8(sp)
 8e8:	6b02                	ld	s6,0(sp)
 8ea:	b7f5                	j	8d6 <malloc+0xea>
