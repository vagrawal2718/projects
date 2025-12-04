
user/_write1:     file format elf64-littleriscv


Disassembly of section .text:

0000000000000000 <main>:
// writetest.c
#include "kernel/types.h"
#include "user/user.h"

int main()
{
   0:	1101                	addi	sp,sp,-32
   2:	ec06                	sd	ra,24(sp)
   4:	e822                	sd	s0,16(sp)
   6:	e426                	sd	s1,8(sp)
   8:	1000                	addi	s0,sp,32
    int sz = 4096 * 10;  // Allocate 10 pages
    char *p = sbrk(sz);  // Expand the heap by 10 pages
   a:	6529                	lui	a0,0xa
   c:	00000097          	auipc	ra,0x0
  10:	3c2080e7          	jalr	962(ra) # 3ce <sbrk>
  14:	84aa                	mv	s1,a0

    if (p == (char *)-1) {
  16:	577d                	li	a4,-1
  18:	4781                	li	a5,0
        printf("sbrk failed\n");
        exit(1);
    }

    // Initial write to each page to ensure allocation in the parent
    for (int i = 0; i < sz; i += 4096) {
  1a:	6605                	lui	a2,0x1
  1c:	66a9                	lui	a3,0xa
    if (p == (char *)-1) {
  1e:	04e50d63          	beq	a0,a4,78 <main+0x78>
        p[i] = i % 256;
  22:	00f48733          	add	a4,s1,a5
  26:	00f70023          	sb	a5,0(a4)
    for (int i = 0; i < sz; i += 4096) {
  2a:	97b2                	add	a5,a5,a2
  2c:	fed79be3          	bne	a5,a3,22 <main+0x22>
    }

    int pid = fork();
  30:	00000097          	auipc	ra,0x0
  34:	30e080e7          	jalr	782(ra) # 33e <fork>
    if (pid == 0) {
  38:	ed29                	bnez	a0,92 <main+0x92>
  3a:	6629                	lui	a2,0xa
  3c:	9626                	add	a2,a2,s1
  3e:	87a6                	mv	a5,s1
        // Child process writes to each page, causing COW page faults
        for (int i = 0; i < sz; i += 4096) {
            p[i] = (i + 1) % 256;  // Modify each page to trigger COW
  40:	4685                	li	a3,1
  42:	9e85                	subw	a3,a3,s1
        for (int i = 0; i < sz; i += 4096) {
  44:	6585                	lui	a1,0x1
            p[i] = (i + 1) % 256;  // Modify each page to trigger COW
  46:	00f6873b          	addw	a4,a3,a5
  4a:	00e78023          	sb	a4,0(a5)
        for (int i = 0; i < sz; i += 4096) {
  4e:	97ae                	add	a5,a5,a1
  50:	fec79be3          	bne	a5,a2,46 <main+0x46>
        }
        // Print COW fault count for the child, expected to be 10
        printf("Child process COW faults: %d\n", get_cow_faults());
  54:	00000097          	auipc	ra,0x0
  58:	3aa080e7          	jalr	938(ra) # 3fe <get_cow_faults>
  5c:	85aa                	mv	a1,a0
  5e:	00001517          	auipc	a0,0x1
  62:	84250513          	addi	a0,a0,-1982 # 8a0 <malloc+0x11a>
  66:	00000097          	auipc	ra,0x0
  6a:	668080e7          	jalr	1640(ra) # 6ce <printf>
        exit(0);
  6e:	4501                	li	a0,0
  70:	00000097          	auipc	ra,0x0
  74:	2d6080e7          	jalr	726(ra) # 346 <exit>
        printf("sbrk failed\n");
  78:	00001517          	auipc	a0,0x1
  7c:	81850513          	addi	a0,a0,-2024 # 890 <malloc+0x10a>
  80:	00000097          	auipc	ra,0x0
  84:	64e080e7          	jalr	1614(ra) # 6ce <printf>
        exit(1);
  88:	4505                	li	a0,1
  8a:	00000097          	auipc	ra,0x0
  8e:	2bc080e7          	jalr	700(ra) # 346 <exit>
    } else {
        // Parent waits for the child to finish
        wait(0);
  92:	4501                	li	a0,0
  94:	00000097          	auipc	ra,0x0
  98:	2ba080e7          	jalr	698(ra) # 34e <wait>
        // Print COW fault count for the parent, expected to be minimal or 0
        printf("Parent process COW faults: %d\n", get_cow_faults());
  9c:	00000097          	auipc	ra,0x0
  a0:	362080e7          	jalr	866(ra) # 3fe <get_cow_faults>
  a4:	85aa                	mv	a1,a0
  a6:	00001517          	auipc	a0,0x1
  aa:	81a50513          	addi	a0,a0,-2022 # 8c0 <malloc+0x13a>
  ae:	00000097          	auipc	ra,0x0
  b2:	620080e7          	jalr	1568(ra) # 6ce <printf>
    }

    exit(0);
  b6:	4501                	li	a0,0
  b8:	00000097          	auipc	ra,0x0
  bc:	28e080e7          	jalr	654(ra) # 346 <exit>

00000000000000c0 <_main>:
//
// wrapper so that it's OK if main() does not call exit().
//
void
_main()
{
  c0:	1141                	addi	sp,sp,-16
  c2:	e406                	sd	ra,8(sp)
  c4:	e022                	sd	s0,0(sp)
  c6:	0800                	addi	s0,sp,16
  extern int main();
  main();
  c8:	00000097          	auipc	ra,0x0
  cc:	f38080e7          	jalr	-200(ra) # 0 <main>
  exit(0);
  d0:	4501                	li	a0,0
  d2:	00000097          	auipc	ra,0x0
  d6:	274080e7          	jalr	628(ra) # 346 <exit>

00000000000000da <strcpy>:
}

char*
strcpy(char *s, const char *t)
{
  da:	1141                	addi	sp,sp,-16
  dc:	e422                	sd	s0,8(sp)
  de:	0800                	addi	s0,sp,16
  char *os;

  os = s;
  while((*s++ = *t++) != 0)
  e0:	87aa                	mv	a5,a0
  e2:	0585                	addi	a1,a1,1 # 1001 <freep+0x1>
  e4:	0785                	addi	a5,a5,1
  e6:	fff5c703          	lbu	a4,-1(a1)
  ea:	fee78fa3          	sb	a4,-1(a5)
  ee:	fb75                	bnez	a4,e2 <strcpy+0x8>
    ;
  return os;
}
  f0:	6422                	ld	s0,8(sp)
  f2:	0141                	addi	sp,sp,16
  f4:	8082                	ret

00000000000000f6 <strcmp>:

int
strcmp(const char *p, const char *q)
{
  f6:	1141                	addi	sp,sp,-16
  f8:	e422                	sd	s0,8(sp)
  fa:	0800                	addi	s0,sp,16
  while(*p && *p == *q)
  fc:	00054783          	lbu	a5,0(a0)
 100:	cb91                	beqz	a5,114 <strcmp+0x1e>
 102:	0005c703          	lbu	a4,0(a1)
 106:	00f71763          	bne	a4,a5,114 <strcmp+0x1e>
    p++, q++;
 10a:	0505                	addi	a0,a0,1
 10c:	0585                	addi	a1,a1,1
  while(*p && *p == *q)
 10e:	00054783          	lbu	a5,0(a0)
 112:	fbe5                	bnez	a5,102 <strcmp+0xc>
  return (uchar)*p - (uchar)*q;
 114:	0005c503          	lbu	a0,0(a1)
}
 118:	40a7853b          	subw	a0,a5,a0
 11c:	6422                	ld	s0,8(sp)
 11e:	0141                	addi	sp,sp,16
 120:	8082                	ret

0000000000000122 <strlen>:

uint
strlen(const char *s)
{
 122:	1141                	addi	sp,sp,-16
 124:	e422                	sd	s0,8(sp)
 126:	0800                	addi	s0,sp,16
  int n;

  for(n = 0; s[n]; n++)
 128:	00054783          	lbu	a5,0(a0)
 12c:	cf91                	beqz	a5,148 <strlen+0x26>
 12e:	0505                	addi	a0,a0,1
 130:	87aa                	mv	a5,a0
 132:	86be                	mv	a3,a5
 134:	0785                	addi	a5,a5,1
 136:	fff7c703          	lbu	a4,-1(a5)
 13a:	ff65                	bnez	a4,132 <strlen+0x10>
 13c:	40a6853b          	subw	a0,a3,a0
 140:	2505                	addiw	a0,a0,1
    ;
  return n;
}
 142:	6422                	ld	s0,8(sp)
 144:	0141                	addi	sp,sp,16
 146:	8082                	ret
  for(n = 0; s[n]; n++)
 148:	4501                	li	a0,0
 14a:	bfe5                	j	142 <strlen+0x20>

000000000000014c <memset>:

void*
memset(void *dst, int c, uint n)
{
 14c:	1141                	addi	sp,sp,-16
 14e:	e422                	sd	s0,8(sp)
 150:	0800                	addi	s0,sp,16
  char *cdst = (char *) dst;
  int i;
  for(i = 0; i < n; i++){
 152:	ca19                	beqz	a2,168 <memset+0x1c>
 154:	87aa                	mv	a5,a0
 156:	1602                	slli	a2,a2,0x20
 158:	9201                	srli	a2,a2,0x20
 15a:	00a60733          	add	a4,a2,a0
    cdst[i] = c;
 15e:	00b78023          	sb	a1,0(a5)
  for(i = 0; i < n; i++){
 162:	0785                	addi	a5,a5,1
 164:	fee79de3          	bne	a5,a4,15e <memset+0x12>
  }
  return dst;
}
 168:	6422                	ld	s0,8(sp)
 16a:	0141                	addi	sp,sp,16
 16c:	8082                	ret

000000000000016e <strchr>:

char*
strchr(const char *s, char c)
{
 16e:	1141                	addi	sp,sp,-16
 170:	e422                	sd	s0,8(sp)
 172:	0800                	addi	s0,sp,16
  for(; *s; s++)
 174:	00054783          	lbu	a5,0(a0)
 178:	cb99                	beqz	a5,18e <strchr+0x20>
    if(*s == c)
 17a:	00f58763          	beq	a1,a5,188 <strchr+0x1a>
  for(; *s; s++)
 17e:	0505                	addi	a0,a0,1
 180:	00054783          	lbu	a5,0(a0)
 184:	fbfd                	bnez	a5,17a <strchr+0xc>
      return (char*)s;
  return 0;
 186:	4501                	li	a0,0
}
 188:	6422                	ld	s0,8(sp)
 18a:	0141                	addi	sp,sp,16
 18c:	8082                	ret
  return 0;
 18e:	4501                	li	a0,0
 190:	bfe5                	j	188 <strchr+0x1a>

0000000000000192 <gets>:

char*
gets(char *buf, int max)
{
 192:	711d                	addi	sp,sp,-96
 194:	ec86                	sd	ra,88(sp)
 196:	e8a2                	sd	s0,80(sp)
 198:	e4a6                	sd	s1,72(sp)
 19a:	e0ca                	sd	s2,64(sp)
 19c:	fc4e                	sd	s3,56(sp)
 19e:	f852                	sd	s4,48(sp)
 1a0:	f456                	sd	s5,40(sp)
 1a2:	f05a                	sd	s6,32(sp)
 1a4:	ec5e                	sd	s7,24(sp)
 1a6:	1080                	addi	s0,sp,96
 1a8:	8baa                	mv	s7,a0
 1aa:	8a2e                	mv	s4,a1
  int i, cc;
  char c;

  for(i=0; i+1 < max; ){
 1ac:	892a                	mv	s2,a0
 1ae:	4481                	li	s1,0
    cc = read(0, &c, 1);
    if(cc < 1)
      break;
    buf[i++] = c;
    if(c == '\n' || c == '\r')
 1b0:	4aa9                	li	s5,10
 1b2:	4b35                	li	s6,13
  for(i=0; i+1 < max; ){
 1b4:	89a6                	mv	s3,s1
 1b6:	2485                	addiw	s1,s1,1
 1b8:	0344d863          	bge	s1,s4,1e8 <gets+0x56>
    cc = read(0, &c, 1);
 1bc:	4605                	li	a2,1
 1be:	faf40593          	addi	a1,s0,-81
 1c2:	4501                	li	a0,0
 1c4:	00000097          	auipc	ra,0x0
 1c8:	19a080e7          	jalr	410(ra) # 35e <read>
    if(cc < 1)
 1cc:	00a05e63          	blez	a0,1e8 <gets+0x56>
    buf[i++] = c;
 1d0:	faf44783          	lbu	a5,-81(s0)
 1d4:	00f90023          	sb	a5,0(s2)
    if(c == '\n' || c == '\r')
 1d8:	01578763          	beq	a5,s5,1e6 <gets+0x54>
 1dc:	0905                	addi	s2,s2,1
 1de:	fd679be3          	bne	a5,s6,1b4 <gets+0x22>
    buf[i++] = c;
 1e2:	89a6                	mv	s3,s1
 1e4:	a011                	j	1e8 <gets+0x56>
 1e6:	89a6                	mv	s3,s1
      break;
  }
  buf[i] = '\0';
 1e8:	99de                	add	s3,s3,s7
 1ea:	00098023          	sb	zero,0(s3)
  return buf;
}
 1ee:	855e                	mv	a0,s7
 1f0:	60e6                	ld	ra,88(sp)
 1f2:	6446                	ld	s0,80(sp)
 1f4:	64a6                	ld	s1,72(sp)
 1f6:	6906                	ld	s2,64(sp)
 1f8:	79e2                	ld	s3,56(sp)
 1fa:	7a42                	ld	s4,48(sp)
 1fc:	7aa2                	ld	s5,40(sp)
 1fe:	7b02                	ld	s6,32(sp)
 200:	6be2                	ld	s7,24(sp)
 202:	6125                	addi	sp,sp,96
 204:	8082                	ret

0000000000000206 <stat>:

int
stat(const char *n, struct stat *st)
{
 206:	1101                	addi	sp,sp,-32
 208:	ec06                	sd	ra,24(sp)
 20a:	e822                	sd	s0,16(sp)
 20c:	e04a                	sd	s2,0(sp)
 20e:	1000                	addi	s0,sp,32
 210:	892e                	mv	s2,a1
  int fd;
  int r;

  fd = open(n, O_RDONLY);
 212:	4581                	li	a1,0
 214:	00000097          	auipc	ra,0x0
 218:	172080e7          	jalr	370(ra) # 386 <open>
  if(fd < 0)
 21c:	02054663          	bltz	a0,248 <stat+0x42>
 220:	e426                	sd	s1,8(sp)
 222:	84aa                	mv	s1,a0
    return -1;
  r = fstat(fd, st);
 224:	85ca                	mv	a1,s2
 226:	00000097          	auipc	ra,0x0
 22a:	178080e7          	jalr	376(ra) # 39e <fstat>
 22e:	892a                	mv	s2,a0
  close(fd);
 230:	8526                	mv	a0,s1
 232:	00000097          	auipc	ra,0x0
 236:	13c080e7          	jalr	316(ra) # 36e <close>
  return r;
 23a:	64a2                	ld	s1,8(sp)
}
 23c:	854a                	mv	a0,s2
 23e:	60e2                	ld	ra,24(sp)
 240:	6442                	ld	s0,16(sp)
 242:	6902                	ld	s2,0(sp)
 244:	6105                	addi	sp,sp,32
 246:	8082                	ret
    return -1;
 248:	597d                	li	s2,-1
 24a:	bfcd                	j	23c <stat+0x36>

000000000000024c <atoi>:

int
atoi(const char *s)
{
 24c:	1141                	addi	sp,sp,-16
 24e:	e422                	sd	s0,8(sp)
 250:	0800                	addi	s0,sp,16
  int n;

  n = 0;
  while('0' <= *s && *s <= '9')
 252:	00054683          	lbu	a3,0(a0)
 256:	fd06879b          	addiw	a5,a3,-48 # 9fd0 <base+0x8fc0>
 25a:	0ff7f793          	zext.b	a5,a5
 25e:	4625                	li	a2,9
 260:	02f66863          	bltu	a2,a5,290 <atoi+0x44>
 264:	872a                	mv	a4,a0
  n = 0;
 266:	4501                	li	a0,0
    n = n*10 + *s++ - '0';
 268:	0705                	addi	a4,a4,1
 26a:	0025179b          	slliw	a5,a0,0x2
 26e:	9fa9                	addw	a5,a5,a0
 270:	0017979b          	slliw	a5,a5,0x1
 274:	9fb5                	addw	a5,a5,a3
 276:	fd07851b          	addiw	a0,a5,-48
  while('0' <= *s && *s <= '9')
 27a:	00074683          	lbu	a3,0(a4)
 27e:	fd06879b          	addiw	a5,a3,-48
 282:	0ff7f793          	zext.b	a5,a5
 286:	fef671e3          	bgeu	a2,a5,268 <atoi+0x1c>
  return n;
}
 28a:	6422                	ld	s0,8(sp)
 28c:	0141                	addi	sp,sp,16
 28e:	8082                	ret
  n = 0;
 290:	4501                	li	a0,0
 292:	bfe5                	j	28a <atoi+0x3e>

0000000000000294 <memmove>:

void*
memmove(void *vdst, const void *vsrc, int n)
{
 294:	1141                	addi	sp,sp,-16
 296:	e422                	sd	s0,8(sp)
 298:	0800                	addi	s0,sp,16
  char *dst;
  const char *src;

  dst = vdst;
  src = vsrc;
  if (src > dst) {
 29a:	02b57463          	bgeu	a0,a1,2c2 <memmove+0x2e>
    while(n-- > 0)
 29e:	00c05f63          	blez	a2,2bc <memmove+0x28>
 2a2:	1602                	slli	a2,a2,0x20
 2a4:	9201                	srli	a2,a2,0x20
 2a6:	00c507b3          	add	a5,a0,a2
  dst = vdst;
 2aa:	872a                	mv	a4,a0
      *dst++ = *src++;
 2ac:	0585                	addi	a1,a1,1
 2ae:	0705                	addi	a4,a4,1
 2b0:	fff5c683          	lbu	a3,-1(a1)
 2b4:	fed70fa3          	sb	a3,-1(a4)
    while(n-- > 0)
 2b8:	fef71ae3          	bne	a4,a5,2ac <memmove+0x18>
    src += n;
    while(n-- > 0)
      *--dst = *--src;
  }
  return vdst;
}
 2bc:	6422                	ld	s0,8(sp)
 2be:	0141                	addi	sp,sp,16
 2c0:	8082                	ret
    dst += n;
 2c2:	00c50733          	add	a4,a0,a2
    src += n;
 2c6:	95b2                	add	a1,a1,a2
    while(n-- > 0)
 2c8:	fec05ae3          	blez	a2,2bc <memmove+0x28>
 2cc:	fff6079b          	addiw	a5,a2,-1 # 9fff <base+0x8fef>
 2d0:	1782                	slli	a5,a5,0x20
 2d2:	9381                	srli	a5,a5,0x20
 2d4:	fff7c793          	not	a5,a5
 2d8:	97ba                	add	a5,a5,a4
      *--dst = *--src;
 2da:	15fd                	addi	a1,a1,-1
 2dc:	177d                	addi	a4,a4,-1
 2de:	0005c683          	lbu	a3,0(a1)
 2e2:	00d70023          	sb	a3,0(a4)
    while(n-- > 0)
 2e6:	fee79ae3          	bne	a5,a4,2da <memmove+0x46>
 2ea:	bfc9                	j	2bc <memmove+0x28>

00000000000002ec <memcmp>:

int
memcmp(const void *s1, const void *s2, uint n)
{
 2ec:	1141                	addi	sp,sp,-16
 2ee:	e422                	sd	s0,8(sp)
 2f0:	0800                	addi	s0,sp,16
  const char *p1 = s1, *p2 = s2;
  while (n-- > 0) {
 2f2:	ca05                	beqz	a2,322 <memcmp+0x36>
 2f4:	fff6069b          	addiw	a3,a2,-1
 2f8:	1682                	slli	a3,a3,0x20
 2fa:	9281                	srli	a3,a3,0x20
 2fc:	0685                	addi	a3,a3,1
 2fe:	96aa                	add	a3,a3,a0
    if (*p1 != *p2) {
 300:	00054783          	lbu	a5,0(a0)
 304:	0005c703          	lbu	a4,0(a1)
 308:	00e79863          	bne	a5,a4,318 <memcmp+0x2c>
      return *p1 - *p2;
    }
    p1++;
 30c:	0505                	addi	a0,a0,1
    p2++;
 30e:	0585                	addi	a1,a1,1
  while (n-- > 0) {
 310:	fed518e3          	bne	a0,a3,300 <memcmp+0x14>
  }
  return 0;
 314:	4501                	li	a0,0
 316:	a019                	j	31c <memcmp+0x30>
      return *p1 - *p2;
 318:	40e7853b          	subw	a0,a5,a4
}
 31c:	6422                	ld	s0,8(sp)
 31e:	0141                	addi	sp,sp,16
 320:	8082                	ret
  return 0;
 322:	4501                	li	a0,0
 324:	bfe5                	j	31c <memcmp+0x30>

0000000000000326 <memcpy>:

void *
memcpy(void *dst, const void *src, uint n)
{
 326:	1141                	addi	sp,sp,-16
 328:	e406                	sd	ra,8(sp)
 32a:	e022                	sd	s0,0(sp)
 32c:	0800                	addi	s0,sp,16
  return memmove(dst, src, n);
 32e:	00000097          	auipc	ra,0x0
 332:	f66080e7          	jalr	-154(ra) # 294 <memmove>
}
 336:	60a2                	ld	ra,8(sp)
 338:	6402                	ld	s0,0(sp)
 33a:	0141                	addi	sp,sp,16
 33c:	8082                	ret

000000000000033e <fork>:
# generated by usys.pl - do not edit
#include "kernel/syscall.h"
.global fork
fork:
 li a7, SYS_fork
 33e:	4885                	li	a7,1
 ecall
 340:	00000073          	ecall
 ret
 344:	8082                	ret

0000000000000346 <exit>:
.global exit
exit:
 li a7, SYS_exit
 346:	4889                	li	a7,2
 ecall
 348:	00000073          	ecall
 ret
 34c:	8082                	ret

000000000000034e <wait>:
.global wait
wait:
 li a7, SYS_wait
 34e:	488d                	li	a7,3
 ecall
 350:	00000073          	ecall
 ret
 354:	8082                	ret

0000000000000356 <pipe>:
.global pipe
pipe:
 li a7, SYS_pipe
 356:	4891                	li	a7,4
 ecall
 358:	00000073          	ecall
 ret
 35c:	8082                	ret

000000000000035e <read>:
.global read
read:
 li a7, SYS_read
 35e:	4895                	li	a7,5
 ecall
 360:	00000073          	ecall
 ret
 364:	8082                	ret

0000000000000366 <write>:
.global write
write:
 li a7, SYS_write
 366:	48c1                	li	a7,16
 ecall
 368:	00000073          	ecall
 ret
 36c:	8082                	ret

000000000000036e <close>:
.global close
close:
 li a7, SYS_close
 36e:	48d5                	li	a7,21
 ecall
 370:	00000073          	ecall
 ret
 374:	8082                	ret

0000000000000376 <kill>:
.global kill
kill:
 li a7, SYS_kill
 376:	4899                	li	a7,6
 ecall
 378:	00000073          	ecall
 ret
 37c:	8082                	ret

000000000000037e <exec>:
.global exec
exec:
 li a7, SYS_exec
 37e:	489d                	li	a7,7
 ecall
 380:	00000073          	ecall
 ret
 384:	8082                	ret

0000000000000386 <open>:
.global open
open:
 li a7, SYS_open
 386:	48bd                	li	a7,15
 ecall
 388:	00000073          	ecall
 ret
 38c:	8082                	ret

000000000000038e <mknod>:
.global mknod
mknod:
 li a7, SYS_mknod
 38e:	48c5                	li	a7,17
 ecall
 390:	00000073          	ecall
 ret
 394:	8082                	ret

0000000000000396 <unlink>:
.global unlink
unlink:
 li a7, SYS_unlink
 396:	48c9                	li	a7,18
 ecall
 398:	00000073          	ecall
 ret
 39c:	8082                	ret

000000000000039e <fstat>:
.global fstat
fstat:
 li a7, SYS_fstat
 39e:	48a1                	li	a7,8
 ecall
 3a0:	00000073          	ecall
 ret
 3a4:	8082                	ret

00000000000003a6 <link>:
.global link
link:
 li a7, SYS_link
 3a6:	48cd                	li	a7,19
 ecall
 3a8:	00000073          	ecall
 ret
 3ac:	8082                	ret

00000000000003ae <mkdir>:
.global mkdir
mkdir:
 li a7, SYS_mkdir
 3ae:	48d1                	li	a7,20
 ecall
 3b0:	00000073          	ecall
 ret
 3b4:	8082                	ret

00000000000003b6 <chdir>:
.global chdir
chdir:
 li a7, SYS_chdir
 3b6:	48a5                	li	a7,9
 ecall
 3b8:	00000073          	ecall
 ret
 3bc:	8082                	ret

00000000000003be <dup>:
.global dup
dup:
 li a7, SYS_dup
 3be:	48a9                	li	a7,10
 ecall
 3c0:	00000073          	ecall
 ret
 3c4:	8082                	ret

00000000000003c6 <getpid>:
.global getpid
getpid:
 li a7, SYS_getpid
 3c6:	48ad                	li	a7,11
 ecall
 3c8:	00000073          	ecall
 ret
 3cc:	8082                	ret

00000000000003ce <sbrk>:
.global sbrk
sbrk:
 li a7, SYS_sbrk
 3ce:	48b1                	li	a7,12
 ecall
 3d0:	00000073          	ecall
 ret
 3d4:	8082                	ret

00000000000003d6 <sleep>:
.global sleep
sleep:
 li a7, SYS_sleep
 3d6:	48b5                	li	a7,13
 ecall
 3d8:	00000073          	ecall
 ret
 3dc:	8082                	ret

00000000000003de <uptime>:
.global uptime
uptime:
 li a7, SYS_uptime
 3de:	48b9                	li	a7,14
 ecall
 3e0:	00000073          	ecall
 ret
 3e4:	8082                	ret

00000000000003e6 <waitx>:
.global waitx
waitx:
 li a7, SYS_waitx
 3e6:	48d9                	li	a7,22
 ecall
 3e8:	00000073          	ecall
 ret
 3ec:	8082                	ret

00000000000003ee <get_fault_counts>:
.global get_fault_counts
get_fault_counts:
 li a7, SYS_get_fault_counts
 3ee:	48dd                	li	a7,23
 ecall
 3f0:	00000073          	ecall
 ret
 3f4:	8082                	ret

00000000000003f6 <get_total_fault_counts>:
.global get_total_fault_counts
get_total_fault_counts:
 li a7, SYS_get_total_fault_counts
 3f6:	48e1                	li	a7,24
 ecall
 3f8:	00000073          	ecall
 ret
 3fc:	8082                	ret

00000000000003fe <get_cow_faults>:
.global get_cow_faults
get_cow_faults:
 li a7, SYS_get_cow_faults
 3fe:	48e5                	li	a7,25
 ecall
 400:	00000073          	ecall
 ret
 404:	8082                	ret

0000000000000406 <putc>:

static char digits[] = "0123456789ABCDEF";

static void
putc(int fd, char c)
{
 406:	1101                	addi	sp,sp,-32
 408:	ec06                	sd	ra,24(sp)
 40a:	e822                	sd	s0,16(sp)
 40c:	1000                	addi	s0,sp,32
 40e:	feb407a3          	sb	a1,-17(s0)
  write(fd, &c, 1);
 412:	4605                	li	a2,1
 414:	fef40593          	addi	a1,s0,-17
 418:	00000097          	auipc	ra,0x0
 41c:	f4e080e7          	jalr	-178(ra) # 366 <write>
}
 420:	60e2                	ld	ra,24(sp)
 422:	6442                	ld	s0,16(sp)
 424:	6105                	addi	sp,sp,32
 426:	8082                	ret

0000000000000428 <printint>:

static void
printint(int fd, int xx, int base, int sgn)
{
 428:	7139                	addi	sp,sp,-64
 42a:	fc06                	sd	ra,56(sp)
 42c:	f822                	sd	s0,48(sp)
 42e:	f426                	sd	s1,40(sp)
 430:	0080                	addi	s0,sp,64
 432:	84aa                	mv	s1,a0
  char buf[16];
  int i, neg;
  uint x;

  neg = 0;
  if(sgn && xx < 0){
 434:	c299                	beqz	a3,43a <printint+0x12>
 436:	0805cb63          	bltz	a1,4cc <printint+0xa4>
    neg = 1;
    x = -xx;
  } else {
    x = xx;
 43a:	2581                	sext.w	a1,a1
  neg = 0;
 43c:	4881                	li	a7,0
 43e:	fc040693          	addi	a3,s0,-64
  }

  i = 0;
 442:	4701                	li	a4,0
  do{
    buf[i++] = digits[x % base];
 444:	2601                	sext.w	a2,a2
 446:	00000517          	auipc	a0,0x0
 44a:	4fa50513          	addi	a0,a0,1274 # 940 <digits>
 44e:	883a                	mv	a6,a4
 450:	2705                	addiw	a4,a4,1
 452:	02c5f7bb          	remuw	a5,a1,a2
 456:	1782                	slli	a5,a5,0x20
 458:	9381                	srli	a5,a5,0x20
 45a:	97aa                	add	a5,a5,a0
 45c:	0007c783          	lbu	a5,0(a5)
 460:	00f68023          	sb	a5,0(a3)
  }while((x /= base) != 0);
 464:	0005879b          	sext.w	a5,a1
 468:	02c5d5bb          	divuw	a1,a1,a2
 46c:	0685                	addi	a3,a3,1
 46e:	fec7f0e3          	bgeu	a5,a2,44e <printint+0x26>
  if(neg)
 472:	00088c63          	beqz	a7,48a <printint+0x62>
    buf[i++] = '-';
 476:	fd070793          	addi	a5,a4,-48
 47a:	00878733          	add	a4,a5,s0
 47e:	02d00793          	li	a5,45
 482:	fef70823          	sb	a5,-16(a4)
 486:	0028071b          	addiw	a4,a6,2

  while(--i >= 0)
 48a:	02e05c63          	blez	a4,4c2 <printint+0x9a>
 48e:	f04a                	sd	s2,32(sp)
 490:	ec4e                	sd	s3,24(sp)
 492:	fc040793          	addi	a5,s0,-64
 496:	00e78933          	add	s2,a5,a4
 49a:	fff78993          	addi	s3,a5,-1
 49e:	99ba                	add	s3,s3,a4
 4a0:	377d                	addiw	a4,a4,-1
 4a2:	1702                	slli	a4,a4,0x20
 4a4:	9301                	srli	a4,a4,0x20
 4a6:	40e989b3          	sub	s3,s3,a4
    putc(fd, buf[i]);
 4aa:	fff94583          	lbu	a1,-1(s2)
 4ae:	8526                	mv	a0,s1
 4b0:	00000097          	auipc	ra,0x0
 4b4:	f56080e7          	jalr	-170(ra) # 406 <putc>
  while(--i >= 0)
 4b8:	197d                	addi	s2,s2,-1
 4ba:	ff3918e3          	bne	s2,s3,4aa <printint+0x82>
 4be:	7902                	ld	s2,32(sp)
 4c0:	69e2                	ld	s3,24(sp)
}
 4c2:	70e2                	ld	ra,56(sp)
 4c4:	7442                	ld	s0,48(sp)
 4c6:	74a2                	ld	s1,40(sp)
 4c8:	6121                	addi	sp,sp,64
 4ca:	8082                	ret
    x = -xx;
 4cc:	40b005bb          	negw	a1,a1
    neg = 1;
 4d0:	4885                	li	a7,1
    x = -xx;
 4d2:	b7b5                	j	43e <printint+0x16>

00000000000004d4 <vprintf>:
}

// Print to the given fd. Only understands %d, %x, %p, %s.
void
vprintf(int fd, const char *fmt, va_list ap)
{
 4d4:	715d                	addi	sp,sp,-80
 4d6:	e486                	sd	ra,72(sp)
 4d8:	e0a2                	sd	s0,64(sp)
 4da:	f84a                	sd	s2,48(sp)
 4dc:	0880                	addi	s0,sp,80
  char *s;
  int c, i, state;

  state = 0;
  for(i = 0; fmt[i]; i++){
 4de:	0005c903          	lbu	s2,0(a1)
 4e2:	1a090a63          	beqz	s2,696 <vprintf+0x1c2>
 4e6:	fc26                	sd	s1,56(sp)
 4e8:	f44e                	sd	s3,40(sp)
 4ea:	f052                	sd	s4,32(sp)
 4ec:	ec56                	sd	s5,24(sp)
 4ee:	e85a                	sd	s6,16(sp)
 4f0:	e45e                	sd	s7,8(sp)
 4f2:	8aaa                	mv	s5,a0
 4f4:	8bb2                	mv	s7,a2
 4f6:	00158493          	addi	s1,a1,1
  state = 0;
 4fa:	4981                	li	s3,0
      if(c == '%'){
        state = '%';
      } else {
        putc(fd, c);
      }
    } else if(state == '%'){
 4fc:	02500a13          	li	s4,37
 500:	4b55                	li	s6,21
 502:	a839                	j	520 <vprintf+0x4c>
        putc(fd, c);
 504:	85ca                	mv	a1,s2
 506:	8556                	mv	a0,s5
 508:	00000097          	auipc	ra,0x0
 50c:	efe080e7          	jalr	-258(ra) # 406 <putc>
 510:	a019                	j	516 <vprintf+0x42>
    } else if(state == '%'){
 512:	01498d63          	beq	s3,s4,52c <vprintf+0x58>
  for(i = 0; fmt[i]; i++){
 516:	0485                	addi	s1,s1,1
 518:	fff4c903          	lbu	s2,-1(s1)
 51c:	16090763          	beqz	s2,68a <vprintf+0x1b6>
    if(state == 0){
 520:	fe0999e3          	bnez	s3,512 <vprintf+0x3e>
      if(c == '%'){
 524:	ff4910e3          	bne	s2,s4,504 <vprintf+0x30>
        state = '%';
 528:	89d2                	mv	s3,s4
 52a:	b7f5                	j	516 <vprintf+0x42>
      if(c == 'd'){
 52c:	13490463          	beq	s2,s4,654 <vprintf+0x180>
 530:	f9d9079b          	addiw	a5,s2,-99
 534:	0ff7f793          	zext.b	a5,a5
 538:	12fb6763          	bltu	s6,a5,666 <vprintf+0x192>
 53c:	f9d9079b          	addiw	a5,s2,-99
 540:	0ff7f713          	zext.b	a4,a5
 544:	12eb6163          	bltu	s6,a4,666 <vprintf+0x192>
 548:	00271793          	slli	a5,a4,0x2
 54c:	00000717          	auipc	a4,0x0
 550:	39c70713          	addi	a4,a4,924 # 8e8 <malloc+0x162>
 554:	97ba                	add	a5,a5,a4
 556:	439c                	lw	a5,0(a5)
 558:	97ba                	add	a5,a5,a4
 55a:	8782                	jr	a5
        printint(fd, va_arg(ap, int), 10, 1);
 55c:	008b8913          	addi	s2,s7,8
 560:	4685                	li	a3,1
 562:	4629                	li	a2,10
 564:	000ba583          	lw	a1,0(s7)
 568:	8556                	mv	a0,s5
 56a:	00000097          	auipc	ra,0x0
 56e:	ebe080e7          	jalr	-322(ra) # 428 <printint>
 572:	8bca                	mv	s7,s2
      } else {
        // Unknown % sequence.  Print it to draw attention.
        putc(fd, '%');
        putc(fd, c);
      }
      state = 0;
 574:	4981                	li	s3,0
 576:	b745                	j	516 <vprintf+0x42>
        printint(fd, va_arg(ap, uint64), 10, 0);
 578:	008b8913          	addi	s2,s7,8
 57c:	4681                	li	a3,0
 57e:	4629                	li	a2,10
 580:	000ba583          	lw	a1,0(s7)
 584:	8556                	mv	a0,s5
 586:	00000097          	auipc	ra,0x0
 58a:	ea2080e7          	jalr	-350(ra) # 428 <printint>
 58e:	8bca                	mv	s7,s2
      state = 0;
 590:	4981                	li	s3,0
 592:	b751                	j	516 <vprintf+0x42>
        printint(fd, va_arg(ap, int), 16, 0);
 594:	008b8913          	addi	s2,s7,8
 598:	4681                	li	a3,0
 59a:	4641                	li	a2,16
 59c:	000ba583          	lw	a1,0(s7)
 5a0:	8556                	mv	a0,s5
 5a2:	00000097          	auipc	ra,0x0
 5a6:	e86080e7          	jalr	-378(ra) # 428 <printint>
 5aa:	8bca                	mv	s7,s2
      state = 0;
 5ac:	4981                	li	s3,0
 5ae:	b7a5                	j	516 <vprintf+0x42>
 5b0:	e062                	sd	s8,0(sp)
        printptr(fd, va_arg(ap, uint64));
 5b2:	008b8c13          	addi	s8,s7,8
 5b6:	000bb983          	ld	s3,0(s7)
  putc(fd, '0');
 5ba:	03000593          	li	a1,48
 5be:	8556                	mv	a0,s5
 5c0:	00000097          	auipc	ra,0x0
 5c4:	e46080e7          	jalr	-442(ra) # 406 <putc>
  putc(fd, 'x');
 5c8:	07800593          	li	a1,120
 5cc:	8556                	mv	a0,s5
 5ce:	00000097          	auipc	ra,0x0
 5d2:	e38080e7          	jalr	-456(ra) # 406 <putc>
 5d6:	4941                	li	s2,16
    putc(fd, digits[x >> (sizeof(uint64) * 8 - 4)]);
 5d8:	00000b97          	auipc	s7,0x0
 5dc:	368b8b93          	addi	s7,s7,872 # 940 <digits>
 5e0:	03c9d793          	srli	a5,s3,0x3c
 5e4:	97de                	add	a5,a5,s7
 5e6:	0007c583          	lbu	a1,0(a5)
 5ea:	8556                	mv	a0,s5
 5ec:	00000097          	auipc	ra,0x0
 5f0:	e1a080e7          	jalr	-486(ra) # 406 <putc>
  for (i = 0; i < (sizeof(uint64) * 2); i++, x <<= 4)
 5f4:	0992                	slli	s3,s3,0x4
 5f6:	397d                	addiw	s2,s2,-1
 5f8:	fe0914e3          	bnez	s2,5e0 <vprintf+0x10c>
        printptr(fd, va_arg(ap, uint64));
 5fc:	8be2                	mv	s7,s8
      state = 0;
 5fe:	4981                	li	s3,0
 600:	6c02                	ld	s8,0(sp)
 602:	bf11                	j	516 <vprintf+0x42>
        s = va_arg(ap, char*);
 604:	008b8993          	addi	s3,s7,8
 608:	000bb903          	ld	s2,0(s7)
        if(s == 0)
 60c:	02090163          	beqz	s2,62e <vprintf+0x15a>
        while(*s != 0){
 610:	00094583          	lbu	a1,0(s2)
 614:	c9a5                	beqz	a1,684 <vprintf+0x1b0>
          putc(fd, *s);
 616:	8556                	mv	a0,s5
 618:	00000097          	auipc	ra,0x0
 61c:	dee080e7          	jalr	-530(ra) # 406 <putc>
          s++;
 620:	0905                	addi	s2,s2,1
        while(*s != 0){
 622:	00094583          	lbu	a1,0(s2)
 626:	f9e5                	bnez	a1,616 <vprintf+0x142>
        s = va_arg(ap, char*);
 628:	8bce                	mv	s7,s3
      state = 0;
 62a:	4981                	li	s3,0
 62c:	b5ed                	j	516 <vprintf+0x42>
          s = "(null)";
 62e:	00000917          	auipc	s2,0x0
 632:	2b290913          	addi	s2,s2,690 # 8e0 <malloc+0x15a>
        while(*s != 0){
 636:	02800593          	li	a1,40
 63a:	bff1                	j	616 <vprintf+0x142>
        putc(fd, va_arg(ap, uint));
 63c:	008b8913          	addi	s2,s7,8
 640:	000bc583          	lbu	a1,0(s7)
 644:	8556                	mv	a0,s5
 646:	00000097          	auipc	ra,0x0
 64a:	dc0080e7          	jalr	-576(ra) # 406 <putc>
 64e:	8bca                	mv	s7,s2
      state = 0;
 650:	4981                	li	s3,0
 652:	b5d1                	j	516 <vprintf+0x42>
        putc(fd, c);
 654:	02500593          	li	a1,37
 658:	8556                	mv	a0,s5
 65a:	00000097          	auipc	ra,0x0
 65e:	dac080e7          	jalr	-596(ra) # 406 <putc>
      state = 0;
 662:	4981                	li	s3,0
 664:	bd4d                	j	516 <vprintf+0x42>
        putc(fd, '%');
 666:	02500593          	li	a1,37
 66a:	8556                	mv	a0,s5
 66c:	00000097          	auipc	ra,0x0
 670:	d9a080e7          	jalr	-614(ra) # 406 <putc>
        putc(fd, c);
 674:	85ca                	mv	a1,s2
 676:	8556                	mv	a0,s5
 678:	00000097          	auipc	ra,0x0
 67c:	d8e080e7          	jalr	-626(ra) # 406 <putc>
      state = 0;
 680:	4981                	li	s3,0
 682:	bd51                	j	516 <vprintf+0x42>
        s = va_arg(ap, char*);
 684:	8bce                	mv	s7,s3
      state = 0;
 686:	4981                	li	s3,0
 688:	b579                	j	516 <vprintf+0x42>
 68a:	74e2                	ld	s1,56(sp)
 68c:	79a2                	ld	s3,40(sp)
 68e:	7a02                	ld	s4,32(sp)
 690:	6ae2                	ld	s5,24(sp)
 692:	6b42                	ld	s6,16(sp)
 694:	6ba2                	ld	s7,8(sp)
    }
  }
}
 696:	60a6                	ld	ra,72(sp)
 698:	6406                	ld	s0,64(sp)
 69a:	7942                	ld	s2,48(sp)
 69c:	6161                	addi	sp,sp,80
 69e:	8082                	ret

00000000000006a0 <fprintf>:

void
fprintf(int fd, const char *fmt, ...)
{
 6a0:	715d                	addi	sp,sp,-80
 6a2:	ec06                	sd	ra,24(sp)
 6a4:	e822                	sd	s0,16(sp)
 6a6:	1000                	addi	s0,sp,32
 6a8:	e010                	sd	a2,0(s0)
 6aa:	e414                	sd	a3,8(s0)
 6ac:	e818                	sd	a4,16(s0)
 6ae:	ec1c                	sd	a5,24(s0)
 6b0:	03043023          	sd	a6,32(s0)
 6b4:	03143423          	sd	a7,40(s0)
  va_list ap;

  va_start(ap, fmt);
 6b8:	fe843423          	sd	s0,-24(s0)
  vprintf(fd, fmt, ap);
 6bc:	8622                	mv	a2,s0
 6be:	00000097          	auipc	ra,0x0
 6c2:	e16080e7          	jalr	-490(ra) # 4d4 <vprintf>
}
 6c6:	60e2                	ld	ra,24(sp)
 6c8:	6442                	ld	s0,16(sp)
 6ca:	6161                	addi	sp,sp,80
 6cc:	8082                	ret

00000000000006ce <printf>:

void
printf(const char *fmt, ...)
{
 6ce:	711d                	addi	sp,sp,-96
 6d0:	ec06                	sd	ra,24(sp)
 6d2:	e822                	sd	s0,16(sp)
 6d4:	1000                	addi	s0,sp,32
 6d6:	e40c                	sd	a1,8(s0)
 6d8:	e810                	sd	a2,16(s0)
 6da:	ec14                	sd	a3,24(s0)
 6dc:	f018                	sd	a4,32(s0)
 6de:	f41c                	sd	a5,40(s0)
 6e0:	03043823          	sd	a6,48(s0)
 6e4:	03143c23          	sd	a7,56(s0)
  va_list ap;

  va_start(ap, fmt);
 6e8:	00840613          	addi	a2,s0,8
 6ec:	fec43423          	sd	a2,-24(s0)
  vprintf(1, fmt, ap);
 6f0:	85aa                	mv	a1,a0
 6f2:	4505                	li	a0,1
 6f4:	00000097          	auipc	ra,0x0
 6f8:	de0080e7          	jalr	-544(ra) # 4d4 <vprintf>
}
 6fc:	60e2                	ld	ra,24(sp)
 6fe:	6442                	ld	s0,16(sp)
 700:	6125                	addi	sp,sp,96
 702:	8082                	ret

0000000000000704 <free>:
static Header base;
static Header *freep;

void
free(void *ap)
{
 704:	1141                	addi	sp,sp,-16
 706:	e422                	sd	s0,8(sp)
 708:	0800                	addi	s0,sp,16
  Header *bp, *p;

  bp = (Header*)ap - 1;
 70a:	ff050693          	addi	a3,a0,-16
  for(p = freep; !(bp > p && bp < p->s.ptr); p = p->s.ptr)
 70e:	00001797          	auipc	a5,0x1
 712:	8f27b783          	ld	a5,-1806(a5) # 1000 <freep>
 716:	a02d                	j	740 <free+0x3c>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
      break;
  if(bp + bp->s.size == p->s.ptr){
    bp->s.size += p->s.ptr->s.size;
 718:	4618                	lw	a4,8(a2)
 71a:	9f2d                	addw	a4,a4,a1
 71c:	fee52c23          	sw	a4,-8(a0)
    bp->s.ptr = p->s.ptr->s.ptr;
 720:	6398                	ld	a4,0(a5)
 722:	6310                	ld	a2,0(a4)
 724:	a83d                	j	762 <free+0x5e>
  } else
    bp->s.ptr = p->s.ptr;
  if(p + p->s.size == bp){
    p->s.size += bp->s.size;
 726:	ff852703          	lw	a4,-8(a0)
 72a:	9f31                	addw	a4,a4,a2
 72c:	c798                	sw	a4,8(a5)
    p->s.ptr = bp->s.ptr;
 72e:	ff053683          	ld	a3,-16(a0)
 732:	a091                	j	776 <free+0x72>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
 734:	6398                	ld	a4,0(a5)
 736:	00e7e463          	bltu	a5,a4,73e <free+0x3a>
 73a:	00e6ea63          	bltu	a3,a4,74e <free+0x4a>
{
 73e:	87ba                	mv	a5,a4
  for(p = freep; !(bp > p && bp < p->s.ptr); p = p->s.ptr)
 740:	fed7fae3          	bgeu	a5,a3,734 <free+0x30>
 744:	6398                	ld	a4,0(a5)
 746:	00e6e463          	bltu	a3,a4,74e <free+0x4a>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
 74a:	fee7eae3          	bltu	a5,a4,73e <free+0x3a>
  if(bp + bp->s.size == p->s.ptr){
 74e:	ff852583          	lw	a1,-8(a0)
 752:	6390                	ld	a2,0(a5)
 754:	02059813          	slli	a6,a1,0x20
 758:	01c85713          	srli	a4,a6,0x1c
 75c:	9736                	add	a4,a4,a3
 75e:	fae60de3          	beq	a2,a4,718 <free+0x14>
    bp->s.ptr = p->s.ptr->s.ptr;
 762:	fec53823          	sd	a2,-16(a0)
  if(p + p->s.size == bp){
 766:	4790                	lw	a2,8(a5)
 768:	02061593          	slli	a1,a2,0x20
 76c:	01c5d713          	srli	a4,a1,0x1c
 770:	973e                	add	a4,a4,a5
 772:	fae68ae3          	beq	a3,a4,726 <free+0x22>
    p->s.ptr = bp->s.ptr;
 776:	e394                	sd	a3,0(a5)
  } else
    p->s.ptr = bp;
  freep = p;
 778:	00001717          	auipc	a4,0x1
 77c:	88f73423          	sd	a5,-1912(a4) # 1000 <freep>
}
 780:	6422                	ld	s0,8(sp)
 782:	0141                	addi	sp,sp,16
 784:	8082                	ret

0000000000000786 <malloc>:
  return freep;
}

void*
malloc(uint nbytes)
{
 786:	7139                	addi	sp,sp,-64
 788:	fc06                	sd	ra,56(sp)
 78a:	f822                	sd	s0,48(sp)
 78c:	f426                	sd	s1,40(sp)
 78e:	ec4e                	sd	s3,24(sp)
 790:	0080                	addi	s0,sp,64
  Header *p, *prevp;
  uint nunits;

  nunits = (nbytes + sizeof(Header) - 1)/sizeof(Header) + 1;
 792:	02051493          	slli	s1,a0,0x20
 796:	9081                	srli	s1,s1,0x20
 798:	04bd                	addi	s1,s1,15
 79a:	8091                	srli	s1,s1,0x4
 79c:	0014899b          	addiw	s3,s1,1
 7a0:	0485                	addi	s1,s1,1
  if((prevp = freep) == 0){
 7a2:	00001517          	auipc	a0,0x1
 7a6:	85e53503          	ld	a0,-1954(a0) # 1000 <freep>
 7aa:	c915                	beqz	a0,7de <malloc+0x58>
    base.s.ptr = freep = prevp = &base;
    base.s.size = 0;
  }
  for(p = prevp->s.ptr; ; prevp = p, p = p->s.ptr){
 7ac:	611c                	ld	a5,0(a0)
    if(p->s.size >= nunits){
 7ae:	4798                	lw	a4,8(a5)
 7b0:	08977e63          	bgeu	a4,s1,84c <malloc+0xc6>
 7b4:	f04a                	sd	s2,32(sp)
 7b6:	e852                	sd	s4,16(sp)
 7b8:	e456                	sd	s5,8(sp)
 7ba:	e05a                	sd	s6,0(sp)
  if(nu < 4096)
 7bc:	8a4e                	mv	s4,s3
 7be:	0009871b          	sext.w	a4,s3
 7c2:	6685                	lui	a3,0x1
 7c4:	00d77363          	bgeu	a4,a3,7ca <malloc+0x44>
 7c8:	6a05                	lui	s4,0x1
 7ca:	000a0b1b          	sext.w	s6,s4
  p = sbrk(nu * sizeof(Header));
 7ce:	004a1a1b          	slliw	s4,s4,0x4
        p->s.size = nunits;
      }
      freep = prevp;
      return (void*)(p + 1);
    }
    if(p == freep)
 7d2:	00001917          	auipc	s2,0x1
 7d6:	82e90913          	addi	s2,s2,-2002 # 1000 <freep>
  if(p == (char*)-1)
 7da:	5afd                	li	s5,-1
 7dc:	a091                	j	820 <malloc+0x9a>
 7de:	f04a                	sd	s2,32(sp)
 7e0:	e852                	sd	s4,16(sp)
 7e2:	e456                	sd	s5,8(sp)
 7e4:	e05a                	sd	s6,0(sp)
    base.s.ptr = freep = prevp = &base;
 7e6:	00001797          	auipc	a5,0x1
 7ea:	82a78793          	addi	a5,a5,-2006 # 1010 <base>
 7ee:	00001717          	auipc	a4,0x1
 7f2:	80f73923          	sd	a5,-2030(a4) # 1000 <freep>
 7f6:	e39c                	sd	a5,0(a5)
    base.s.size = 0;
 7f8:	0007a423          	sw	zero,8(a5)
    if(p->s.size >= nunits){
 7fc:	b7c1                	j	7bc <malloc+0x36>
        prevp->s.ptr = p->s.ptr;
 7fe:	6398                	ld	a4,0(a5)
 800:	e118                	sd	a4,0(a0)
 802:	a08d                	j	864 <malloc+0xde>
  hp->s.size = nu;
 804:	01652423          	sw	s6,8(a0)
  free((void*)(hp + 1));
 808:	0541                	addi	a0,a0,16
 80a:	00000097          	auipc	ra,0x0
 80e:	efa080e7          	jalr	-262(ra) # 704 <free>
  return freep;
 812:	00093503          	ld	a0,0(s2)
      if((p = morecore(nunits)) == 0)
 816:	c13d                	beqz	a0,87c <malloc+0xf6>
  for(p = prevp->s.ptr; ; prevp = p, p = p->s.ptr){
 818:	611c                	ld	a5,0(a0)
    if(p->s.size >= nunits){
 81a:	4798                	lw	a4,8(a5)
 81c:	02977463          	bgeu	a4,s1,844 <malloc+0xbe>
    if(p == freep)
 820:	00093703          	ld	a4,0(s2)
 824:	853e                	mv	a0,a5
 826:	fef719e3          	bne	a4,a5,818 <malloc+0x92>
  p = sbrk(nu * sizeof(Header));
 82a:	8552                	mv	a0,s4
 82c:	00000097          	auipc	ra,0x0
 830:	ba2080e7          	jalr	-1118(ra) # 3ce <sbrk>
  if(p == (char*)-1)
 834:	fd5518e3          	bne	a0,s5,804 <malloc+0x7e>
        return 0;
 838:	4501                	li	a0,0
 83a:	7902                	ld	s2,32(sp)
 83c:	6a42                	ld	s4,16(sp)
 83e:	6aa2                	ld	s5,8(sp)
 840:	6b02                	ld	s6,0(sp)
 842:	a03d                	j	870 <malloc+0xea>
 844:	7902                	ld	s2,32(sp)
 846:	6a42                	ld	s4,16(sp)
 848:	6aa2                	ld	s5,8(sp)
 84a:	6b02                	ld	s6,0(sp)
      if(p->s.size == nunits)
 84c:	fae489e3          	beq	s1,a4,7fe <malloc+0x78>
        p->s.size -= nunits;
 850:	4137073b          	subw	a4,a4,s3
 854:	c798                	sw	a4,8(a5)
        p += p->s.size;
 856:	02071693          	slli	a3,a4,0x20
 85a:	01c6d713          	srli	a4,a3,0x1c
 85e:	97ba                	add	a5,a5,a4
        p->s.size = nunits;
 860:	0137a423          	sw	s3,8(a5)
      freep = prevp;
 864:	00000717          	auipc	a4,0x0
 868:	78a73e23          	sd	a0,1948(a4) # 1000 <freep>
      return (void*)(p + 1);
 86c:	01078513          	addi	a0,a5,16
  }
}
 870:	70e2                	ld	ra,56(sp)
 872:	7442                	ld	s0,48(sp)
 874:	74a2                	ld	s1,40(sp)
 876:	69e2                	ld	s3,24(sp)
 878:	6121                	addi	sp,sp,64
 87a:	8082                	ret
 87c:	7902                	ld	s2,32(sp)
 87e:	6a42                	ld	s4,16(sp)
 880:	6aa2                	ld	s5,8(sp)
 882:	6b02                	ld	s6,0(sp)
 884:	b7f5                	j	870 <malloc+0xea>
