
user/_read1:     file format elf64-littleriscv


Disassembly of section .text:

0000000000000000 <main>:

    exit(0);
} */

int main()
{
   0:	715d                	addi	sp,sp,-80
   2:	e486                	sd	ra,72(sp)
   4:	e0a2                	sd	s0,64(sp)
   6:	f84a                	sd	s2,48(sp)
   8:	0880                	addi	s0,sp,80
    printf("Before sbrk\n");
   a:	00001517          	auipc	a0,0x1
   e:	87650513          	addi	a0,a0,-1930 # 880 <malloc+0x10e>
  12:	00000097          	auipc	ra,0x0
  16:	6a8080e7          	jalr	1704(ra) # 6ba <printf>
    int sz = 4096 * 10;
    char *p = sbrk(sz);
  1a:	6529                	lui	a0,0xa
  1c:	00000097          	auipc	ra,0x0
  20:	39e080e7          	jalr	926(ra) # 3ba <sbrk>
  24:	892a                	mv	s2,a0
    printf("After sbrk\n");
  26:	00001517          	auipc	a0,0x1
  2a:	87250513          	addi	a0,a0,-1934 # 898 <malloc+0x126>
  2e:	00000097          	auipc	ra,0x0
  32:	68c080e7          	jalr	1676(ra) # 6ba <printf>

    if (p == (char *)-1) {
  36:	57fd                	li	a5,-1
  38:	04f90963          	beq	s2,a5,8a <main+0x8a>
  3c:	fc26                	sd	s1,56(sp)
  3e:	f44e                	sd	s3,40(sp)
  40:	f052                	sd	s4,32(sp)
  42:	ec56                	sd	s5,24(sp)
  44:	4481                	li	s1,0
        exit(1);
    }

    // Read from each page without modifying it
    for (int i = 0; i < sz; i += 4096) {
        printf("Reading from page %d\n", i/4096);
  46:	00001a97          	auipc	s5,0x1
  4a:	872a8a93          	addi	s5,s5,-1934 # 8b8 <malloc+0x146>
    for (int i = 0; i < sz; i += 4096) {
  4e:	6a05                	lui	s4,0x1
  50:	69a9                	lui	s3,0xa
        printf("Reading from page %d\n", i/4096);
  52:	41f4d59b          	sraiw	a1,s1,0x1f
  56:	0145d59b          	srliw	a1,a1,0x14
  5a:	9da5                	addw	a1,a1,s1
  5c:	40c5d59b          	sraiw	a1,a1,0xc
  60:	8556                	mv	a0,s5
  62:	00000097          	auipc	ra,0x0
  66:	658080e7          	jalr	1624(ra) # 6ba <printf>
        volatile char temp = p[i];
  6a:	009907b3          	add	a5,s2,s1
  6e:	0007c783          	lbu	a5,0(a5)
  72:	faf40fa3          	sb	a5,-65(s0)
        (void)temp;
  76:	fbf44783          	lbu	a5,-65(s0)
    for (int i = 0; i < sz; i += 4096) {
  7a:	94d2                	add	s1,s1,s4
  7c:	fd349be3          	bne	s1,s3,52 <main+0x52>
    }

    exit(0);
  80:	4501                	li	a0,0
  82:	00000097          	auipc	ra,0x0
  86:	2b0080e7          	jalr	688(ra) # 332 <exit>
  8a:	fc26                	sd	s1,56(sp)
  8c:	f44e                	sd	s3,40(sp)
  8e:	f052                	sd	s4,32(sp)
  90:	ec56                	sd	s5,24(sp)
        printf("sbrk failed\n");
  92:	00001517          	auipc	a0,0x1
  96:	81650513          	addi	a0,a0,-2026 # 8a8 <malloc+0x136>
  9a:	00000097          	auipc	ra,0x0
  9e:	620080e7          	jalr	1568(ra) # 6ba <printf>
        exit(1);
  a2:	4505                	li	a0,1
  a4:	00000097          	auipc	ra,0x0
  a8:	28e080e7          	jalr	654(ra) # 332 <exit>

00000000000000ac <_main>:
//
// wrapper so that it's OK if main() does not call exit().
//
void
_main()
{
  ac:	1141                	addi	sp,sp,-16
  ae:	e406                	sd	ra,8(sp)
  b0:	e022                	sd	s0,0(sp)
  b2:	0800                	addi	s0,sp,16
  extern int main();
  main();
  b4:	00000097          	auipc	ra,0x0
  b8:	f4c080e7          	jalr	-180(ra) # 0 <main>
  exit(0);
  bc:	4501                	li	a0,0
  be:	00000097          	auipc	ra,0x0
  c2:	274080e7          	jalr	628(ra) # 332 <exit>

00000000000000c6 <strcpy>:
}

char*
strcpy(char *s, const char *t)
{
  c6:	1141                	addi	sp,sp,-16
  c8:	e422                	sd	s0,8(sp)
  ca:	0800                	addi	s0,sp,16
  char *os;

  os = s;
  while((*s++ = *t++) != 0)
  cc:	87aa                	mv	a5,a0
  ce:	0585                	addi	a1,a1,1
  d0:	0785                	addi	a5,a5,1
  d2:	fff5c703          	lbu	a4,-1(a1)
  d6:	fee78fa3          	sb	a4,-1(a5)
  da:	fb75                	bnez	a4,ce <strcpy+0x8>
    ;
  return os;
}
  dc:	6422                	ld	s0,8(sp)
  de:	0141                	addi	sp,sp,16
  e0:	8082                	ret

00000000000000e2 <strcmp>:

int
strcmp(const char *p, const char *q)
{
  e2:	1141                	addi	sp,sp,-16
  e4:	e422                	sd	s0,8(sp)
  e6:	0800                	addi	s0,sp,16
  while(*p && *p == *q)
  e8:	00054783          	lbu	a5,0(a0)
  ec:	cb91                	beqz	a5,100 <strcmp+0x1e>
  ee:	0005c703          	lbu	a4,0(a1)
  f2:	00f71763          	bne	a4,a5,100 <strcmp+0x1e>
    p++, q++;
  f6:	0505                	addi	a0,a0,1
  f8:	0585                	addi	a1,a1,1
  while(*p && *p == *q)
  fa:	00054783          	lbu	a5,0(a0)
  fe:	fbe5                	bnez	a5,ee <strcmp+0xc>
  return (uchar)*p - (uchar)*q;
 100:	0005c503          	lbu	a0,0(a1)
}
 104:	40a7853b          	subw	a0,a5,a0
 108:	6422                	ld	s0,8(sp)
 10a:	0141                	addi	sp,sp,16
 10c:	8082                	ret

000000000000010e <strlen>:

uint
strlen(const char *s)
{
 10e:	1141                	addi	sp,sp,-16
 110:	e422                	sd	s0,8(sp)
 112:	0800                	addi	s0,sp,16
  int n;

  for(n = 0; s[n]; n++)
 114:	00054783          	lbu	a5,0(a0)
 118:	cf91                	beqz	a5,134 <strlen+0x26>
 11a:	0505                	addi	a0,a0,1
 11c:	87aa                	mv	a5,a0
 11e:	86be                	mv	a3,a5
 120:	0785                	addi	a5,a5,1
 122:	fff7c703          	lbu	a4,-1(a5)
 126:	ff65                	bnez	a4,11e <strlen+0x10>
 128:	40a6853b          	subw	a0,a3,a0
 12c:	2505                	addiw	a0,a0,1
    ;
  return n;
}
 12e:	6422                	ld	s0,8(sp)
 130:	0141                	addi	sp,sp,16
 132:	8082                	ret
  for(n = 0; s[n]; n++)
 134:	4501                	li	a0,0
 136:	bfe5                	j	12e <strlen+0x20>

0000000000000138 <memset>:

void*
memset(void *dst, int c, uint n)
{
 138:	1141                	addi	sp,sp,-16
 13a:	e422                	sd	s0,8(sp)
 13c:	0800                	addi	s0,sp,16
  char *cdst = (char *) dst;
  int i;
  for(i = 0; i < n; i++){
 13e:	ca19                	beqz	a2,154 <memset+0x1c>
 140:	87aa                	mv	a5,a0
 142:	1602                	slli	a2,a2,0x20
 144:	9201                	srli	a2,a2,0x20
 146:	00a60733          	add	a4,a2,a0
    cdst[i] = c;
 14a:	00b78023          	sb	a1,0(a5)
  for(i = 0; i < n; i++){
 14e:	0785                	addi	a5,a5,1
 150:	fee79de3          	bne	a5,a4,14a <memset+0x12>
  }
  return dst;
}
 154:	6422                	ld	s0,8(sp)
 156:	0141                	addi	sp,sp,16
 158:	8082                	ret

000000000000015a <strchr>:

char*
strchr(const char *s, char c)
{
 15a:	1141                	addi	sp,sp,-16
 15c:	e422                	sd	s0,8(sp)
 15e:	0800                	addi	s0,sp,16
  for(; *s; s++)
 160:	00054783          	lbu	a5,0(a0)
 164:	cb99                	beqz	a5,17a <strchr+0x20>
    if(*s == c)
 166:	00f58763          	beq	a1,a5,174 <strchr+0x1a>
  for(; *s; s++)
 16a:	0505                	addi	a0,a0,1
 16c:	00054783          	lbu	a5,0(a0)
 170:	fbfd                	bnez	a5,166 <strchr+0xc>
      return (char*)s;
  return 0;
 172:	4501                	li	a0,0
}
 174:	6422                	ld	s0,8(sp)
 176:	0141                	addi	sp,sp,16
 178:	8082                	ret
  return 0;
 17a:	4501                	li	a0,0
 17c:	bfe5                	j	174 <strchr+0x1a>

000000000000017e <gets>:

char*
gets(char *buf, int max)
{
 17e:	711d                	addi	sp,sp,-96
 180:	ec86                	sd	ra,88(sp)
 182:	e8a2                	sd	s0,80(sp)
 184:	e4a6                	sd	s1,72(sp)
 186:	e0ca                	sd	s2,64(sp)
 188:	fc4e                	sd	s3,56(sp)
 18a:	f852                	sd	s4,48(sp)
 18c:	f456                	sd	s5,40(sp)
 18e:	f05a                	sd	s6,32(sp)
 190:	ec5e                	sd	s7,24(sp)
 192:	1080                	addi	s0,sp,96
 194:	8baa                	mv	s7,a0
 196:	8a2e                	mv	s4,a1
  int i, cc;
  char c;

  for(i=0; i+1 < max; ){
 198:	892a                	mv	s2,a0
 19a:	4481                	li	s1,0
    cc = read(0, &c, 1);
    if(cc < 1)
      break;
    buf[i++] = c;
    if(c == '\n' || c == '\r')
 19c:	4aa9                	li	s5,10
 19e:	4b35                	li	s6,13
  for(i=0; i+1 < max; ){
 1a0:	89a6                	mv	s3,s1
 1a2:	2485                	addiw	s1,s1,1
 1a4:	0344d863          	bge	s1,s4,1d4 <gets+0x56>
    cc = read(0, &c, 1);
 1a8:	4605                	li	a2,1
 1aa:	faf40593          	addi	a1,s0,-81
 1ae:	4501                	li	a0,0
 1b0:	00000097          	auipc	ra,0x0
 1b4:	19a080e7          	jalr	410(ra) # 34a <read>
    if(cc < 1)
 1b8:	00a05e63          	blez	a0,1d4 <gets+0x56>
    buf[i++] = c;
 1bc:	faf44783          	lbu	a5,-81(s0)
 1c0:	00f90023          	sb	a5,0(s2)
    if(c == '\n' || c == '\r')
 1c4:	01578763          	beq	a5,s5,1d2 <gets+0x54>
 1c8:	0905                	addi	s2,s2,1
 1ca:	fd679be3          	bne	a5,s6,1a0 <gets+0x22>
    buf[i++] = c;
 1ce:	89a6                	mv	s3,s1
 1d0:	a011                	j	1d4 <gets+0x56>
 1d2:	89a6                	mv	s3,s1
      break;
  }
  buf[i] = '\0';
 1d4:	99de                	add	s3,s3,s7
 1d6:	00098023          	sb	zero,0(s3) # a000 <base+0x8ff0>
  return buf;
}
 1da:	855e                	mv	a0,s7
 1dc:	60e6                	ld	ra,88(sp)
 1de:	6446                	ld	s0,80(sp)
 1e0:	64a6                	ld	s1,72(sp)
 1e2:	6906                	ld	s2,64(sp)
 1e4:	79e2                	ld	s3,56(sp)
 1e6:	7a42                	ld	s4,48(sp)
 1e8:	7aa2                	ld	s5,40(sp)
 1ea:	7b02                	ld	s6,32(sp)
 1ec:	6be2                	ld	s7,24(sp)
 1ee:	6125                	addi	sp,sp,96
 1f0:	8082                	ret

00000000000001f2 <stat>:

int
stat(const char *n, struct stat *st)
{
 1f2:	1101                	addi	sp,sp,-32
 1f4:	ec06                	sd	ra,24(sp)
 1f6:	e822                	sd	s0,16(sp)
 1f8:	e04a                	sd	s2,0(sp)
 1fa:	1000                	addi	s0,sp,32
 1fc:	892e                	mv	s2,a1
  int fd;
  int r;

  fd = open(n, O_RDONLY);
 1fe:	4581                	li	a1,0
 200:	00000097          	auipc	ra,0x0
 204:	172080e7          	jalr	370(ra) # 372 <open>
  if(fd < 0)
 208:	02054663          	bltz	a0,234 <stat+0x42>
 20c:	e426                	sd	s1,8(sp)
 20e:	84aa                	mv	s1,a0
    return -1;
  r = fstat(fd, st);
 210:	85ca                	mv	a1,s2
 212:	00000097          	auipc	ra,0x0
 216:	178080e7          	jalr	376(ra) # 38a <fstat>
 21a:	892a                	mv	s2,a0
  close(fd);
 21c:	8526                	mv	a0,s1
 21e:	00000097          	auipc	ra,0x0
 222:	13c080e7          	jalr	316(ra) # 35a <close>
  return r;
 226:	64a2                	ld	s1,8(sp)
}
 228:	854a                	mv	a0,s2
 22a:	60e2                	ld	ra,24(sp)
 22c:	6442                	ld	s0,16(sp)
 22e:	6902                	ld	s2,0(sp)
 230:	6105                	addi	sp,sp,32
 232:	8082                	ret
    return -1;
 234:	597d                	li	s2,-1
 236:	bfcd                	j	228 <stat+0x36>

0000000000000238 <atoi>:

int
atoi(const char *s)
{
 238:	1141                	addi	sp,sp,-16
 23a:	e422                	sd	s0,8(sp)
 23c:	0800                	addi	s0,sp,16
  int n;

  n = 0;
  while('0' <= *s && *s <= '9')
 23e:	00054683          	lbu	a3,0(a0)
 242:	fd06879b          	addiw	a5,a3,-48
 246:	0ff7f793          	zext.b	a5,a5
 24a:	4625                	li	a2,9
 24c:	02f66863          	bltu	a2,a5,27c <atoi+0x44>
 250:	872a                	mv	a4,a0
  n = 0;
 252:	4501                	li	a0,0
    n = n*10 + *s++ - '0';
 254:	0705                	addi	a4,a4,1
 256:	0025179b          	slliw	a5,a0,0x2
 25a:	9fa9                	addw	a5,a5,a0
 25c:	0017979b          	slliw	a5,a5,0x1
 260:	9fb5                	addw	a5,a5,a3
 262:	fd07851b          	addiw	a0,a5,-48
  while('0' <= *s && *s <= '9')
 266:	00074683          	lbu	a3,0(a4)
 26a:	fd06879b          	addiw	a5,a3,-48
 26e:	0ff7f793          	zext.b	a5,a5
 272:	fef671e3          	bgeu	a2,a5,254 <atoi+0x1c>
  return n;
}
 276:	6422                	ld	s0,8(sp)
 278:	0141                	addi	sp,sp,16
 27a:	8082                	ret
  n = 0;
 27c:	4501                	li	a0,0
 27e:	bfe5                	j	276 <atoi+0x3e>

0000000000000280 <memmove>:

void*
memmove(void *vdst, const void *vsrc, int n)
{
 280:	1141                	addi	sp,sp,-16
 282:	e422                	sd	s0,8(sp)
 284:	0800                	addi	s0,sp,16
  char *dst;
  const char *src;

  dst = vdst;
  src = vsrc;
  if (src > dst) {
 286:	02b57463          	bgeu	a0,a1,2ae <memmove+0x2e>
    while(n-- > 0)
 28a:	00c05f63          	blez	a2,2a8 <memmove+0x28>
 28e:	1602                	slli	a2,a2,0x20
 290:	9201                	srli	a2,a2,0x20
 292:	00c507b3          	add	a5,a0,a2
  dst = vdst;
 296:	872a                	mv	a4,a0
      *dst++ = *src++;
 298:	0585                	addi	a1,a1,1
 29a:	0705                	addi	a4,a4,1
 29c:	fff5c683          	lbu	a3,-1(a1)
 2a0:	fed70fa3          	sb	a3,-1(a4)
    while(n-- > 0)
 2a4:	fef71ae3          	bne	a4,a5,298 <memmove+0x18>
    src += n;
    while(n-- > 0)
      *--dst = *--src;
  }
  return vdst;
}
 2a8:	6422                	ld	s0,8(sp)
 2aa:	0141                	addi	sp,sp,16
 2ac:	8082                	ret
    dst += n;
 2ae:	00c50733          	add	a4,a0,a2
    src += n;
 2b2:	95b2                	add	a1,a1,a2
    while(n-- > 0)
 2b4:	fec05ae3          	blez	a2,2a8 <memmove+0x28>
 2b8:	fff6079b          	addiw	a5,a2,-1
 2bc:	1782                	slli	a5,a5,0x20
 2be:	9381                	srli	a5,a5,0x20
 2c0:	fff7c793          	not	a5,a5
 2c4:	97ba                	add	a5,a5,a4
      *--dst = *--src;
 2c6:	15fd                	addi	a1,a1,-1
 2c8:	177d                	addi	a4,a4,-1
 2ca:	0005c683          	lbu	a3,0(a1)
 2ce:	00d70023          	sb	a3,0(a4)
    while(n-- > 0)
 2d2:	fee79ae3          	bne	a5,a4,2c6 <memmove+0x46>
 2d6:	bfc9                	j	2a8 <memmove+0x28>

00000000000002d8 <memcmp>:

int
memcmp(const void *s1, const void *s2, uint n)
{
 2d8:	1141                	addi	sp,sp,-16
 2da:	e422                	sd	s0,8(sp)
 2dc:	0800                	addi	s0,sp,16
  const char *p1 = s1, *p2 = s2;
  while (n-- > 0) {
 2de:	ca05                	beqz	a2,30e <memcmp+0x36>
 2e0:	fff6069b          	addiw	a3,a2,-1
 2e4:	1682                	slli	a3,a3,0x20
 2e6:	9281                	srli	a3,a3,0x20
 2e8:	0685                	addi	a3,a3,1
 2ea:	96aa                	add	a3,a3,a0
    if (*p1 != *p2) {
 2ec:	00054783          	lbu	a5,0(a0)
 2f0:	0005c703          	lbu	a4,0(a1)
 2f4:	00e79863          	bne	a5,a4,304 <memcmp+0x2c>
      return *p1 - *p2;
    }
    p1++;
 2f8:	0505                	addi	a0,a0,1
    p2++;
 2fa:	0585                	addi	a1,a1,1
  while (n-- > 0) {
 2fc:	fed518e3          	bne	a0,a3,2ec <memcmp+0x14>
  }
  return 0;
 300:	4501                	li	a0,0
 302:	a019                	j	308 <memcmp+0x30>
      return *p1 - *p2;
 304:	40e7853b          	subw	a0,a5,a4
}
 308:	6422                	ld	s0,8(sp)
 30a:	0141                	addi	sp,sp,16
 30c:	8082                	ret
  return 0;
 30e:	4501                	li	a0,0
 310:	bfe5                	j	308 <memcmp+0x30>

0000000000000312 <memcpy>:

void *
memcpy(void *dst, const void *src, uint n)
{
 312:	1141                	addi	sp,sp,-16
 314:	e406                	sd	ra,8(sp)
 316:	e022                	sd	s0,0(sp)
 318:	0800                	addi	s0,sp,16
  return memmove(dst, src, n);
 31a:	00000097          	auipc	ra,0x0
 31e:	f66080e7          	jalr	-154(ra) # 280 <memmove>
}
 322:	60a2                	ld	ra,8(sp)
 324:	6402                	ld	s0,0(sp)
 326:	0141                	addi	sp,sp,16
 328:	8082                	ret

000000000000032a <fork>:
# generated by usys.pl - do not edit
#include "kernel/syscall.h"
.global fork
fork:
 li a7, SYS_fork
 32a:	4885                	li	a7,1
 ecall
 32c:	00000073          	ecall
 ret
 330:	8082                	ret

0000000000000332 <exit>:
.global exit
exit:
 li a7, SYS_exit
 332:	4889                	li	a7,2
 ecall
 334:	00000073          	ecall
 ret
 338:	8082                	ret

000000000000033a <wait>:
.global wait
wait:
 li a7, SYS_wait
 33a:	488d                	li	a7,3
 ecall
 33c:	00000073          	ecall
 ret
 340:	8082                	ret

0000000000000342 <pipe>:
.global pipe
pipe:
 li a7, SYS_pipe
 342:	4891                	li	a7,4
 ecall
 344:	00000073          	ecall
 ret
 348:	8082                	ret

000000000000034a <read>:
.global read
read:
 li a7, SYS_read
 34a:	4895                	li	a7,5
 ecall
 34c:	00000073          	ecall
 ret
 350:	8082                	ret

0000000000000352 <write>:
.global write
write:
 li a7, SYS_write
 352:	48c1                	li	a7,16
 ecall
 354:	00000073          	ecall
 ret
 358:	8082                	ret

000000000000035a <close>:
.global close
close:
 li a7, SYS_close
 35a:	48d5                	li	a7,21
 ecall
 35c:	00000073          	ecall
 ret
 360:	8082                	ret

0000000000000362 <kill>:
.global kill
kill:
 li a7, SYS_kill
 362:	4899                	li	a7,6
 ecall
 364:	00000073          	ecall
 ret
 368:	8082                	ret

000000000000036a <exec>:
.global exec
exec:
 li a7, SYS_exec
 36a:	489d                	li	a7,7
 ecall
 36c:	00000073          	ecall
 ret
 370:	8082                	ret

0000000000000372 <open>:
.global open
open:
 li a7, SYS_open
 372:	48bd                	li	a7,15
 ecall
 374:	00000073          	ecall
 ret
 378:	8082                	ret

000000000000037a <mknod>:
.global mknod
mknod:
 li a7, SYS_mknod
 37a:	48c5                	li	a7,17
 ecall
 37c:	00000073          	ecall
 ret
 380:	8082                	ret

0000000000000382 <unlink>:
.global unlink
unlink:
 li a7, SYS_unlink
 382:	48c9                	li	a7,18
 ecall
 384:	00000073          	ecall
 ret
 388:	8082                	ret

000000000000038a <fstat>:
.global fstat
fstat:
 li a7, SYS_fstat
 38a:	48a1                	li	a7,8
 ecall
 38c:	00000073          	ecall
 ret
 390:	8082                	ret

0000000000000392 <link>:
.global link
link:
 li a7, SYS_link
 392:	48cd                	li	a7,19
 ecall
 394:	00000073          	ecall
 ret
 398:	8082                	ret

000000000000039a <mkdir>:
.global mkdir
mkdir:
 li a7, SYS_mkdir
 39a:	48d1                	li	a7,20
 ecall
 39c:	00000073          	ecall
 ret
 3a0:	8082                	ret

00000000000003a2 <chdir>:
.global chdir
chdir:
 li a7, SYS_chdir
 3a2:	48a5                	li	a7,9
 ecall
 3a4:	00000073          	ecall
 ret
 3a8:	8082                	ret

00000000000003aa <dup>:
.global dup
dup:
 li a7, SYS_dup
 3aa:	48a9                	li	a7,10
 ecall
 3ac:	00000073          	ecall
 ret
 3b0:	8082                	ret

00000000000003b2 <getpid>:
.global getpid
getpid:
 li a7, SYS_getpid
 3b2:	48ad                	li	a7,11
 ecall
 3b4:	00000073          	ecall
 ret
 3b8:	8082                	ret

00000000000003ba <sbrk>:
.global sbrk
sbrk:
 li a7, SYS_sbrk
 3ba:	48b1                	li	a7,12
 ecall
 3bc:	00000073          	ecall
 ret
 3c0:	8082                	ret

00000000000003c2 <sleep>:
.global sleep
sleep:
 li a7, SYS_sleep
 3c2:	48b5                	li	a7,13
 ecall
 3c4:	00000073          	ecall
 ret
 3c8:	8082                	ret

00000000000003ca <uptime>:
.global uptime
uptime:
 li a7, SYS_uptime
 3ca:	48b9                	li	a7,14
 ecall
 3cc:	00000073          	ecall
 ret
 3d0:	8082                	ret

00000000000003d2 <waitx>:
.global waitx
waitx:
 li a7, SYS_waitx
 3d2:	48d9                	li	a7,22
 ecall
 3d4:	00000073          	ecall
 ret
 3d8:	8082                	ret

00000000000003da <get_fault_counts>:
.global get_fault_counts
get_fault_counts:
 li a7, SYS_get_fault_counts
 3da:	48dd                	li	a7,23
 ecall
 3dc:	00000073          	ecall
 ret
 3e0:	8082                	ret

00000000000003e2 <get_total_fault_counts>:
.global get_total_fault_counts
get_total_fault_counts:
 li a7, SYS_get_total_fault_counts
 3e2:	48e1                	li	a7,24
 ecall
 3e4:	00000073          	ecall
 ret
 3e8:	8082                	ret

00000000000003ea <get_cow_faults>:
.global get_cow_faults
get_cow_faults:
 li a7, SYS_get_cow_faults
 3ea:	48e5                	li	a7,25
 ecall
 3ec:	00000073          	ecall
 ret
 3f0:	8082                	ret

00000000000003f2 <putc>:

static char digits[] = "0123456789ABCDEF";

static void
putc(int fd, char c)
{
 3f2:	1101                	addi	sp,sp,-32
 3f4:	ec06                	sd	ra,24(sp)
 3f6:	e822                	sd	s0,16(sp)
 3f8:	1000                	addi	s0,sp,32
 3fa:	feb407a3          	sb	a1,-17(s0)
  write(fd, &c, 1);
 3fe:	4605                	li	a2,1
 400:	fef40593          	addi	a1,s0,-17
 404:	00000097          	auipc	ra,0x0
 408:	f4e080e7          	jalr	-178(ra) # 352 <write>
}
 40c:	60e2                	ld	ra,24(sp)
 40e:	6442                	ld	s0,16(sp)
 410:	6105                	addi	sp,sp,32
 412:	8082                	ret

0000000000000414 <printint>:

static void
printint(int fd, int xx, int base, int sgn)
{
 414:	7139                	addi	sp,sp,-64
 416:	fc06                	sd	ra,56(sp)
 418:	f822                	sd	s0,48(sp)
 41a:	f426                	sd	s1,40(sp)
 41c:	0080                	addi	s0,sp,64
 41e:	84aa                	mv	s1,a0
  char buf[16];
  int i, neg;
  uint x;

  neg = 0;
  if(sgn && xx < 0){
 420:	c299                	beqz	a3,426 <printint+0x12>
 422:	0805cb63          	bltz	a1,4b8 <printint+0xa4>
    neg = 1;
    x = -xx;
  } else {
    x = xx;
 426:	2581                	sext.w	a1,a1
  neg = 0;
 428:	4881                	li	a7,0
 42a:	fc040693          	addi	a3,s0,-64
  }

  i = 0;
 42e:	4701                	li	a4,0
  do{
    buf[i++] = digits[x % base];
 430:	2601                	sext.w	a2,a2
 432:	00000517          	auipc	a0,0x0
 436:	4fe50513          	addi	a0,a0,1278 # 930 <digits>
 43a:	883a                	mv	a6,a4
 43c:	2705                	addiw	a4,a4,1
 43e:	02c5f7bb          	remuw	a5,a1,a2
 442:	1782                	slli	a5,a5,0x20
 444:	9381                	srli	a5,a5,0x20
 446:	97aa                	add	a5,a5,a0
 448:	0007c783          	lbu	a5,0(a5)
 44c:	00f68023          	sb	a5,0(a3)
  }while((x /= base) != 0);
 450:	0005879b          	sext.w	a5,a1
 454:	02c5d5bb          	divuw	a1,a1,a2
 458:	0685                	addi	a3,a3,1
 45a:	fec7f0e3          	bgeu	a5,a2,43a <printint+0x26>
  if(neg)
 45e:	00088c63          	beqz	a7,476 <printint+0x62>
    buf[i++] = '-';
 462:	fd070793          	addi	a5,a4,-48
 466:	00878733          	add	a4,a5,s0
 46a:	02d00793          	li	a5,45
 46e:	fef70823          	sb	a5,-16(a4)
 472:	0028071b          	addiw	a4,a6,2

  while(--i >= 0)
 476:	02e05c63          	blez	a4,4ae <printint+0x9a>
 47a:	f04a                	sd	s2,32(sp)
 47c:	ec4e                	sd	s3,24(sp)
 47e:	fc040793          	addi	a5,s0,-64
 482:	00e78933          	add	s2,a5,a4
 486:	fff78993          	addi	s3,a5,-1
 48a:	99ba                	add	s3,s3,a4
 48c:	377d                	addiw	a4,a4,-1
 48e:	1702                	slli	a4,a4,0x20
 490:	9301                	srli	a4,a4,0x20
 492:	40e989b3          	sub	s3,s3,a4
    putc(fd, buf[i]);
 496:	fff94583          	lbu	a1,-1(s2)
 49a:	8526                	mv	a0,s1
 49c:	00000097          	auipc	ra,0x0
 4a0:	f56080e7          	jalr	-170(ra) # 3f2 <putc>
  while(--i >= 0)
 4a4:	197d                	addi	s2,s2,-1
 4a6:	ff3918e3          	bne	s2,s3,496 <printint+0x82>
 4aa:	7902                	ld	s2,32(sp)
 4ac:	69e2                	ld	s3,24(sp)
}
 4ae:	70e2                	ld	ra,56(sp)
 4b0:	7442                	ld	s0,48(sp)
 4b2:	74a2                	ld	s1,40(sp)
 4b4:	6121                	addi	sp,sp,64
 4b6:	8082                	ret
    x = -xx;
 4b8:	40b005bb          	negw	a1,a1
    neg = 1;
 4bc:	4885                	li	a7,1
    x = -xx;
 4be:	b7b5                	j	42a <printint+0x16>

00000000000004c0 <vprintf>:
}

// Print to the given fd. Only understands %d, %x, %p, %s.
void
vprintf(int fd, const char *fmt, va_list ap)
{
 4c0:	715d                	addi	sp,sp,-80
 4c2:	e486                	sd	ra,72(sp)
 4c4:	e0a2                	sd	s0,64(sp)
 4c6:	f84a                	sd	s2,48(sp)
 4c8:	0880                	addi	s0,sp,80
  char *s;
  int c, i, state;

  state = 0;
  for(i = 0; fmt[i]; i++){
 4ca:	0005c903          	lbu	s2,0(a1)
 4ce:	1a090a63          	beqz	s2,682 <vprintf+0x1c2>
 4d2:	fc26                	sd	s1,56(sp)
 4d4:	f44e                	sd	s3,40(sp)
 4d6:	f052                	sd	s4,32(sp)
 4d8:	ec56                	sd	s5,24(sp)
 4da:	e85a                	sd	s6,16(sp)
 4dc:	e45e                	sd	s7,8(sp)
 4de:	8aaa                	mv	s5,a0
 4e0:	8bb2                	mv	s7,a2
 4e2:	00158493          	addi	s1,a1,1
  state = 0;
 4e6:	4981                	li	s3,0
      if(c == '%'){
        state = '%';
      } else {
        putc(fd, c);
      }
    } else if(state == '%'){
 4e8:	02500a13          	li	s4,37
 4ec:	4b55                	li	s6,21
 4ee:	a839                	j	50c <vprintf+0x4c>
        putc(fd, c);
 4f0:	85ca                	mv	a1,s2
 4f2:	8556                	mv	a0,s5
 4f4:	00000097          	auipc	ra,0x0
 4f8:	efe080e7          	jalr	-258(ra) # 3f2 <putc>
 4fc:	a019                	j	502 <vprintf+0x42>
    } else if(state == '%'){
 4fe:	01498d63          	beq	s3,s4,518 <vprintf+0x58>
  for(i = 0; fmt[i]; i++){
 502:	0485                	addi	s1,s1,1
 504:	fff4c903          	lbu	s2,-1(s1)
 508:	16090763          	beqz	s2,676 <vprintf+0x1b6>
    if(state == 0){
 50c:	fe0999e3          	bnez	s3,4fe <vprintf+0x3e>
      if(c == '%'){
 510:	ff4910e3          	bne	s2,s4,4f0 <vprintf+0x30>
        state = '%';
 514:	89d2                	mv	s3,s4
 516:	b7f5                	j	502 <vprintf+0x42>
      if(c == 'd'){
 518:	13490463          	beq	s2,s4,640 <vprintf+0x180>
 51c:	f9d9079b          	addiw	a5,s2,-99
 520:	0ff7f793          	zext.b	a5,a5
 524:	12fb6763          	bltu	s6,a5,652 <vprintf+0x192>
 528:	f9d9079b          	addiw	a5,s2,-99
 52c:	0ff7f713          	zext.b	a4,a5
 530:	12eb6163          	bltu	s6,a4,652 <vprintf+0x192>
 534:	00271793          	slli	a5,a4,0x2
 538:	00000717          	auipc	a4,0x0
 53c:	3a070713          	addi	a4,a4,928 # 8d8 <malloc+0x166>
 540:	97ba                	add	a5,a5,a4
 542:	439c                	lw	a5,0(a5)
 544:	97ba                	add	a5,a5,a4
 546:	8782                	jr	a5
        printint(fd, va_arg(ap, int), 10, 1);
 548:	008b8913          	addi	s2,s7,8
 54c:	4685                	li	a3,1
 54e:	4629                	li	a2,10
 550:	000ba583          	lw	a1,0(s7)
 554:	8556                	mv	a0,s5
 556:	00000097          	auipc	ra,0x0
 55a:	ebe080e7          	jalr	-322(ra) # 414 <printint>
 55e:	8bca                	mv	s7,s2
      } else {
        // Unknown % sequence.  Print it to draw attention.
        putc(fd, '%');
        putc(fd, c);
      }
      state = 0;
 560:	4981                	li	s3,0
 562:	b745                	j	502 <vprintf+0x42>
        printint(fd, va_arg(ap, uint64), 10, 0);
 564:	008b8913          	addi	s2,s7,8
 568:	4681                	li	a3,0
 56a:	4629                	li	a2,10
 56c:	000ba583          	lw	a1,0(s7)
 570:	8556                	mv	a0,s5
 572:	00000097          	auipc	ra,0x0
 576:	ea2080e7          	jalr	-350(ra) # 414 <printint>
 57a:	8bca                	mv	s7,s2
      state = 0;
 57c:	4981                	li	s3,0
 57e:	b751                	j	502 <vprintf+0x42>
        printint(fd, va_arg(ap, int), 16, 0);
 580:	008b8913          	addi	s2,s7,8
 584:	4681                	li	a3,0
 586:	4641                	li	a2,16
 588:	000ba583          	lw	a1,0(s7)
 58c:	8556                	mv	a0,s5
 58e:	00000097          	auipc	ra,0x0
 592:	e86080e7          	jalr	-378(ra) # 414 <printint>
 596:	8bca                	mv	s7,s2
      state = 0;
 598:	4981                	li	s3,0
 59a:	b7a5                	j	502 <vprintf+0x42>
 59c:	e062                	sd	s8,0(sp)
        printptr(fd, va_arg(ap, uint64));
 59e:	008b8c13          	addi	s8,s7,8
 5a2:	000bb983          	ld	s3,0(s7)
  putc(fd, '0');
 5a6:	03000593          	li	a1,48
 5aa:	8556                	mv	a0,s5
 5ac:	00000097          	auipc	ra,0x0
 5b0:	e46080e7          	jalr	-442(ra) # 3f2 <putc>
  putc(fd, 'x');
 5b4:	07800593          	li	a1,120
 5b8:	8556                	mv	a0,s5
 5ba:	00000097          	auipc	ra,0x0
 5be:	e38080e7          	jalr	-456(ra) # 3f2 <putc>
 5c2:	4941                	li	s2,16
    putc(fd, digits[x >> (sizeof(uint64) * 8 - 4)]);
 5c4:	00000b97          	auipc	s7,0x0
 5c8:	36cb8b93          	addi	s7,s7,876 # 930 <digits>
 5cc:	03c9d793          	srli	a5,s3,0x3c
 5d0:	97de                	add	a5,a5,s7
 5d2:	0007c583          	lbu	a1,0(a5)
 5d6:	8556                	mv	a0,s5
 5d8:	00000097          	auipc	ra,0x0
 5dc:	e1a080e7          	jalr	-486(ra) # 3f2 <putc>
  for (i = 0; i < (sizeof(uint64) * 2); i++, x <<= 4)
 5e0:	0992                	slli	s3,s3,0x4
 5e2:	397d                	addiw	s2,s2,-1
 5e4:	fe0914e3          	bnez	s2,5cc <vprintf+0x10c>
        printptr(fd, va_arg(ap, uint64));
 5e8:	8be2                	mv	s7,s8
      state = 0;
 5ea:	4981                	li	s3,0
 5ec:	6c02                	ld	s8,0(sp)
 5ee:	bf11                	j	502 <vprintf+0x42>
        s = va_arg(ap, char*);
 5f0:	008b8993          	addi	s3,s7,8
 5f4:	000bb903          	ld	s2,0(s7)
        if(s == 0)
 5f8:	02090163          	beqz	s2,61a <vprintf+0x15a>
        while(*s != 0){
 5fc:	00094583          	lbu	a1,0(s2)
 600:	c9a5                	beqz	a1,670 <vprintf+0x1b0>
          putc(fd, *s);
 602:	8556                	mv	a0,s5
 604:	00000097          	auipc	ra,0x0
 608:	dee080e7          	jalr	-530(ra) # 3f2 <putc>
          s++;
 60c:	0905                	addi	s2,s2,1
        while(*s != 0){
 60e:	00094583          	lbu	a1,0(s2)
 612:	f9e5                	bnez	a1,602 <vprintf+0x142>
        s = va_arg(ap, char*);
 614:	8bce                	mv	s7,s3
      state = 0;
 616:	4981                	li	s3,0
 618:	b5ed                	j	502 <vprintf+0x42>
          s = "(null)";
 61a:	00000917          	auipc	s2,0x0
 61e:	2b690913          	addi	s2,s2,694 # 8d0 <malloc+0x15e>
        while(*s != 0){
 622:	02800593          	li	a1,40
 626:	bff1                	j	602 <vprintf+0x142>
        putc(fd, va_arg(ap, uint));
 628:	008b8913          	addi	s2,s7,8
 62c:	000bc583          	lbu	a1,0(s7)
 630:	8556                	mv	a0,s5
 632:	00000097          	auipc	ra,0x0
 636:	dc0080e7          	jalr	-576(ra) # 3f2 <putc>
 63a:	8bca                	mv	s7,s2
      state = 0;
 63c:	4981                	li	s3,0
 63e:	b5d1                	j	502 <vprintf+0x42>
        putc(fd, c);
 640:	02500593          	li	a1,37
 644:	8556                	mv	a0,s5
 646:	00000097          	auipc	ra,0x0
 64a:	dac080e7          	jalr	-596(ra) # 3f2 <putc>
      state = 0;
 64e:	4981                	li	s3,0
 650:	bd4d                	j	502 <vprintf+0x42>
        putc(fd, '%');
 652:	02500593          	li	a1,37
 656:	8556                	mv	a0,s5
 658:	00000097          	auipc	ra,0x0
 65c:	d9a080e7          	jalr	-614(ra) # 3f2 <putc>
        putc(fd, c);
 660:	85ca                	mv	a1,s2
 662:	8556                	mv	a0,s5
 664:	00000097          	auipc	ra,0x0
 668:	d8e080e7          	jalr	-626(ra) # 3f2 <putc>
      state = 0;
 66c:	4981                	li	s3,0
 66e:	bd51                	j	502 <vprintf+0x42>
        s = va_arg(ap, char*);
 670:	8bce                	mv	s7,s3
      state = 0;
 672:	4981                	li	s3,0
 674:	b579                	j	502 <vprintf+0x42>
 676:	74e2                	ld	s1,56(sp)
 678:	79a2                	ld	s3,40(sp)
 67a:	7a02                	ld	s4,32(sp)
 67c:	6ae2                	ld	s5,24(sp)
 67e:	6b42                	ld	s6,16(sp)
 680:	6ba2                	ld	s7,8(sp)
    }
  }
}
 682:	60a6                	ld	ra,72(sp)
 684:	6406                	ld	s0,64(sp)
 686:	7942                	ld	s2,48(sp)
 688:	6161                	addi	sp,sp,80
 68a:	8082                	ret

000000000000068c <fprintf>:

void
fprintf(int fd, const char *fmt, ...)
{
 68c:	715d                	addi	sp,sp,-80
 68e:	ec06                	sd	ra,24(sp)
 690:	e822                	sd	s0,16(sp)
 692:	1000                	addi	s0,sp,32
 694:	e010                	sd	a2,0(s0)
 696:	e414                	sd	a3,8(s0)
 698:	e818                	sd	a4,16(s0)
 69a:	ec1c                	sd	a5,24(s0)
 69c:	03043023          	sd	a6,32(s0)
 6a0:	03143423          	sd	a7,40(s0)
  va_list ap;

  va_start(ap, fmt);
 6a4:	fe843423          	sd	s0,-24(s0)
  vprintf(fd, fmt, ap);
 6a8:	8622                	mv	a2,s0
 6aa:	00000097          	auipc	ra,0x0
 6ae:	e16080e7          	jalr	-490(ra) # 4c0 <vprintf>
}
 6b2:	60e2                	ld	ra,24(sp)
 6b4:	6442                	ld	s0,16(sp)
 6b6:	6161                	addi	sp,sp,80
 6b8:	8082                	ret

00000000000006ba <printf>:

void
printf(const char *fmt, ...)
{
 6ba:	711d                	addi	sp,sp,-96
 6bc:	ec06                	sd	ra,24(sp)
 6be:	e822                	sd	s0,16(sp)
 6c0:	1000                	addi	s0,sp,32
 6c2:	e40c                	sd	a1,8(s0)
 6c4:	e810                	sd	a2,16(s0)
 6c6:	ec14                	sd	a3,24(s0)
 6c8:	f018                	sd	a4,32(s0)
 6ca:	f41c                	sd	a5,40(s0)
 6cc:	03043823          	sd	a6,48(s0)
 6d0:	03143c23          	sd	a7,56(s0)
  va_list ap;

  va_start(ap, fmt);
 6d4:	00840613          	addi	a2,s0,8
 6d8:	fec43423          	sd	a2,-24(s0)
  vprintf(1, fmt, ap);
 6dc:	85aa                	mv	a1,a0
 6de:	4505                	li	a0,1
 6e0:	00000097          	auipc	ra,0x0
 6e4:	de0080e7          	jalr	-544(ra) # 4c0 <vprintf>
}
 6e8:	60e2                	ld	ra,24(sp)
 6ea:	6442                	ld	s0,16(sp)
 6ec:	6125                	addi	sp,sp,96
 6ee:	8082                	ret

00000000000006f0 <free>:
static Header base;
static Header *freep;

void
free(void *ap)
{
 6f0:	1141                	addi	sp,sp,-16
 6f2:	e422                	sd	s0,8(sp)
 6f4:	0800                	addi	s0,sp,16
  Header *bp, *p;

  bp = (Header*)ap - 1;
 6f6:	ff050693          	addi	a3,a0,-16
  for(p = freep; !(bp > p && bp < p->s.ptr); p = p->s.ptr)
 6fa:	00001797          	auipc	a5,0x1
 6fe:	9067b783          	ld	a5,-1786(a5) # 1000 <freep>
 702:	a02d                	j	72c <free+0x3c>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
      break;
  if(bp + bp->s.size == p->s.ptr){
    bp->s.size += p->s.ptr->s.size;
 704:	4618                	lw	a4,8(a2)
 706:	9f2d                	addw	a4,a4,a1
 708:	fee52c23          	sw	a4,-8(a0)
    bp->s.ptr = p->s.ptr->s.ptr;
 70c:	6398                	ld	a4,0(a5)
 70e:	6310                	ld	a2,0(a4)
 710:	a83d                	j	74e <free+0x5e>
  } else
    bp->s.ptr = p->s.ptr;
  if(p + p->s.size == bp){
    p->s.size += bp->s.size;
 712:	ff852703          	lw	a4,-8(a0)
 716:	9f31                	addw	a4,a4,a2
 718:	c798                	sw	a4,8(a5)
    p->s.ptr = bp->s.ptr;
 71a:	ff053683          	ld	a3,-16(a0)
 71e:	a091                	j	762 <free+0x72>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
 720:	6398                	ld	a4,0(a5)
 722:	00e7e463          	bltu	a5,a4,72a <free+0x3a>
 726:	00e6ea63          	bltu	a3,a4,73a <free+0x4a>
{
 72a:	87ba                	mv	a5,a4
  for(p = freep; !(bp > p && bp < p->s.ptr); p = p->s.ptr)
 72c:	fed7fae3          	bgeu	a5,a3,720 <free+0x30>
 730:	6398                	ld	a4,0(a5)
 732:	00e6e463          	bltu	a3,a4,73a <free+0x4a>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
 736:	fee7eae3          	bltu	a5,a4,72a <free+0x3a>
  if(bp + bp->s.size == p->s.ptr){
 73a:	ff852583          	lw	a1,-8(a0)
 73e:	6390                	ld	a2,0(a5)
 740:	02059813          	slli	a6,a1,0x20
 744:	01c85713          	srli	a4,a6,0x1c
 748:	9736                	add	a4,a4,a3
 74a:	fae60de3          	beq	a2,a4,704 <free+0x14>
    bp->s.ptr = p->s.ptr->s.ptr;
 74e:	fec53823          	sd	a2,-16(a0)
  if(p + p->s.size == bp){
 752:	4790                	lw	a2,8(a5)
 754:	02061593          	slli	a1,a2,0x20
 758:	01c5d713          	srli	a4,a1,0x1c
 75c:	973e                	add	a4,a4,a5
 75e:	fae68ae3          	beq	a3,a4,712 <free+0x22>
    p->s.ptr = bp->s.ptr;
 762:	e394                	sd	a3,0(a5)
  } else
    p->s.ptr = bp;
  freep = p;
 764:	00001717          	auipc	a4,0x1
 768:	88f73e23          	sd	a5,-1892(a4) # 1000 <freep>
}
 76c:	6422                	ld	s0,8(sp)
 76e:	0141                	addi	sp,sp,16
 770:	8082                	ret

0000000000000772 <malloc>:
  return freep;
}

void*
malloc(uint nbytes)
{
 772:	7139                	addi	sp,sp,-64
 774:	fc06                	sd	ra,56(sp)
 776:	f822                	sd	s0,48(sp)
 778:	f426                	sd	s1,40(sp)
 77a:	ec4e                	sd	s3,24(sp)
 77c:	0080                	addi	s0,sp,64
  Header *p, *prevp;
  uint nunits;

  nunits = (nbytes + sizeof(Header) - 1)/sizeof(Header) + 1;
 77e:	02051493          	slli	s1,a0,0x20
 782:	9081                	srli	s1,s1,0x20
 784:	04bd                	addi	s1,s1,15
 786:	8091                	srli	s1,s1,0x4
 788:	0014899b          	addiw	s3,s1,1
 78c:	0485                	addi	s1,s1,1
  if((prevp = freep) == 0){
 78e:	00001517          	auipc	a0,0x1
 792:	87253503          	ld	a0,-1934(a0) # 1000 <freep>
 796:	c915                	beqz	a0,7ca <malloc+0x58>
    base.s.ptr = freep = prevp = &base;
    base.s.size = 0;
  }
  for(p = prevp->s.ptr; ; prevp = p, p = p->s.ptr){
 798:	611c                	ld	a5,0(a0)
    if(p->s.size >= nunits){
 79a:	4798                	lw	a4,8(a5)
 79c:	08977e63          	bgeu	a4,s1,838 <malloc+0xc6>
 7a0:	f04a                	sd	s2,32(sp)
 7a2:	e852                	sd	s4,16(sp)
 7a4:	e456                	sd	s5,8(sp)
 7a6:	e05a                	sd	s6,0(sp)
  if(nu < 4096)
 7a8:	8a4e                	mv	s4,s3
 7aa:	0009871b          	sext.w	a4,s3
 7ae:	6685                	lui	a3,0x1
 7b0:	00d77363          	bgeu	a4,a3,7b6 <malloc+0x44>
 7b4:	6a05                	lui	s4,0x1
 7b6:	000a0b1b          	sext.w	s6,s4
  p = sbrk(nu * sizeof(Header));
 7ba:	004a1a1b          	slliw	s4,s4,0x4
        p->s.size = nunits;
      }
      freep = prevp;
      return (void*)(p + 1);
    }
    if(p == freep)
 7be:	00001917          	auipc	s2,0x1
 7c2:	84290913          	addi	s2,s2,-1982 # 1000 <freep>
  if(p == (char*)-1)
 7c6:	5afd                	li	s5,-1
 7c8:	a091                	j	80c <malloc+0x9a>
 7ca:	f04a                	sd	s2,32(sp)
 7cc:	e852                	sd	s4,16(sp)
 7ce:	e456                	sd	s5,8(sp)
 7d0:	e05a                	sd	s6,0(sp)
    base.s.ptr = freep = prevp = &base;
 7d2:	00001797          	auipc	a5,0x1
 7d6:	83e78793          	addi	a5,a5,-1986 # 1010 <base>
 7da:	00001717          	auipc	a4,0x1
 7de:	82f73323          	sd	a5,-2010(a4) # 1000 <freep>
 7e2:	e39c                	sd	a5,0(a5)
    base.s.size = 0;
 7e4:	0007a423          	sw	zero,8(a5)
    if(p->s.size >= nunits){
 7e8:	b7c1                	j	7a8 <malloc+0x36>
        prevp->s.ptr = p->s.ptr;
 7ea:	6398                	ld	a4,0(a5)
 7ec:	e118                	sd	a4,0(a0)
 7ee:	a08d                	j	850 <malloc+0xde>
  hp->s.size = nu;
 7f0:	01652423          	sw	s6,8(a0)
  free((void*)(hp + 1));
 7f4:	0541                	addi	a0,a0,16
 7f6:	00000097          	auipc	ra,0x0
 7fa:	efa080e7          	jalr	-262(ra) # 6f0 <free>
  return freep;
 7fe:	00093503          	ld	a0,0(s2)
      if((p = morecore(nunits)) == 0)
 802:	c13d                	beqz	a0,868 <malloc+0xf6>
  for(p = prevp->s.ptr; ; prevp = p, p = p->s.ptr){
 804:	611c                	ld	a5,0(a0)
    if(p->s.size >= nunits){
 806:	4798                	lw	a4,8(a5)
 808:	02977463          	bgeu	a4,s1,830 <malloc+0xbe>
    if(p == freep)
 80c:	00093703          	ld	a4,0(s2)
 810:	853e                	mv	a0,a5
 812:	fef719e3          	bne	a4,a5,804 <malloc+0x92>
  p = sbrk(nu * sizeof(Header));
 816:	8552                	mv	a0,s4
 818:	00000097          	auipc	ra,0x0
 81c:	ba2080e7          	jalr	-1118(ra) # 3ba <sbrk>
  if(p == (char*)-1)
 820:	fd5518e3          	bne	a0,s5,7f0 <malloc+0x7e>
        return 0;
 824:	4501                	li	a0,0
 826:	7902                	ld	s2,32(sp)
 828:	6a42                	ld	s4,16(sp)
 82a:	6aa2                	ld	s5,8(sp)
 82c:	6b02                	ld	s6,0(sp)
 82e:	a03d                	j	85c <malloc+0xea>
 830:	7902                	ld	s2,32(sp)
 832:	6a42                	ld	s4,16(sp)
 834:	6aa2                	ld	s5,8(sp)
 836:	6b02                	ld	s6,0(sp)
      if(p->s.size == nunits)
 838:	fae489e3          	beq	s1,a4,7ea <malloc+0x78>
        p->s.size -= nunits;
 83c:	4137073b          	subw	a4,a4,s3
 840:	c798                	sw	a4,8(a5)
        p += p->s.size;
 842:	02071693          	slli	a3,a4,0x20
 846:	01c6d713          	srli	a4,a3,0x1c
 84a:	97ba                	add	a5,a5,a4
        p->s.size = nunits;
 84c:	0137a423          	sw	s3,8(a5)
      freep = prevp;
 850:	00000717          	auipc	a4,0x0
 854:	7aa73823          	sd	a0,1968(a4) # 1000 <freep>
      return (void*)(p + 1);
 858:	01078513          	addi	a0,a5,16
  }
}
 85c:	70e2                	ld	ra,56(sp)
 85e:	7442                	ld	s0,48(sp)
 860:	74a2                	ld	s1,40(sp)
 862:	69e2                	ld	s3,24(sp)
 864:	6121                	addi	sp,sp,64
 866:	8082                	ret
 868:	7902                	ld	s2,32(sp)
 86a:	6a42                	ld	s4,16(sp)
 86c:	6aa2                	ld	s5,8(sp)
 86e:	6b02                	ld	s6,0(sp)
 870:	b7f5                	j	85c <malloc+0xea>
