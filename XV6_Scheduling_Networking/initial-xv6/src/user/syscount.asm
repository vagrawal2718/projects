
user/_syscount:     file format elf64-littleriscv


Disassembly of section .text:

0000000000000000 <main>:
#include "kernel/stat.h"
#include "user/user.h"
// #include "kernel/proc.h"

int main(int argc, char *argv[])
{
   0:	716d                	addi	sp,sp,-272
   2:	e606                	sd	ra,264(sp)
   4:	e222                	sd	s0,256(sp)
   6:	fda6                	sd	s1,248(sp)
   8:	f9ca                	sd	s2,240(sp)
   a:	f5ce                	sd	s3,232(sp)
   c:	f1d2                	sd	s4,224(sp)
   e:	0a00                	addi	s0,sp,272
  10:	892e                	mv	s2,a1
  char *syscall_names[] = {
  12:	00001797          	auipc	a5,0x1
  16:	ad678793          	addi	a5,a5,-1322 # ae8 <malloc+0x2ac>
  1a:	ef840713          	addi	a4,s0,-264
  1e:	00001597          	auipc	a1,0x1
  22:	b9258593          	addi	a1,a1,-1134 # bb0 <malloc+0x374>
  26:	0007b303          	ld	t1,0(a5)
  2a:	0087b883          	ld	a7,8(a5)
  2e:	0107b803          	ld	a6,16(a5)
  32:	6f90                	ld	a2,24(a5)
  34:	7394                	ld	a3,32(a5)
  36:	00673023          	sd	t1,0(a4)
  3a:	01173423          	sd	a7,8(a4)
  3e:	01073823          	sd	a6,16(a4)
  42:	ef10                	sd	a2,24(a4)
  44:	f314                	sd	a3,32(a4)
  46:	02878793          	addi	a5,a5,40
  4a:	02870713          	addi	a4,a4,40
  4e:	fcb79ce3          	bne	a5,a1,26 <main+0x26>
  52:	6394                	ld	a3,0(a5)
  54:	679c                	ld	a5,8(a5)
  56:	e314                	sd	a3,0(a4)
  58:	e71c                	sd	a5,8(a4)
      "getpid", "sbrk", "sleep", "uptime", "open",
      "write", "mknod", "unlink", "link", "mkdir",
      "close", "waitx", "getSysCount","sigalarm","sigreturn","settickets"};
  int syscall_num = 0;
  int count = 0;
  if (argc < 3)
  5a:	4789                	li	a5,2
  5c:	02a7c063          	blt	a5,a0,7c <main+0x7c>
  {
    fprintf(2, "Usage: syscount <mask> command [args]\n");
  60:	00001597          	auipc	a1,0x1
  64:	8e058593          	addi	a1,a1,-1824 # 940 <malloc+0x104>
  68:	4509                	li	a0,2
  6a:	00000097          	auipc	ra,0x0
  6e:	6ec080e7          	jalr	1772(ra) # 756 <fprintf>
    exit(1);
  72:	4505                	li	a0,1
  74:	00000097          	auipc	ra,0x0
  78:	380080e7          	jalr	896(ra) # 3f4 <exit>
  }

  int mask = atoi(argv[1]);
  7c:	00893503          	ld	a0,8(s2)
  80:	00000097          	auipc	ra,0x0
  84:	27a080e7          	jalr	634(ra) # 2fa <atoi>
  88:	84aa                	mv	s1,a0

  // Get the current PID of the process before fork
  int parent_pid = getpid();
  8a:	00000097          	auipc	ra,0x0
  8e:	3ea080e7          	jalr	1002(ra) # 474 <getpid>
  92:	8a2a                	mv	s4,a0

  int pid = fork();
  94:	00000097          	auipc	ra,0x0
  98:	358080e7          	jalr	856(ra) # 3ec <fork>
  9c:	89aa                	mv	s3,a0

  if (pid < 0)
  9e:	06054763          	bltz	a0,10c <main+0x10c>
  {
    fprintf(2, "fork failed\n");
    exit(1);
  }

  if (pid == 0)
  a2:	c159                	beqz	a0,128 <main+0x128>
  }
  else
  {
    // This is the parent process
    // Calculate syscall number based on mask
    while (mask > 1)
  a4:	4705                	li	a4,1
  int syscall_num = 0;
  a6:	4901                	li	s2,0
    while (mask > 1)
  a8:	4785                	li	a5,1
  aa:	0a975563          	bge	a4,s1,154 <main+0x154>
    {
      mask >>= 1;
  ae:	4014d49b          	sraiw	s1,s1,0x1
      syscall_num++;
  b2:	2905                	addiw	s2,s2,1
    while (mask > 1)
  b4:	fe97cde3          	blt	a5,s1,ae <main+0xae>
    }

    count = getSysCount(syscall_num, pid);
  b8:	85ce                	mv	a1,s3
  ba:	854a                	mv	a0,s2
  bc:	00000097          	auipc	ra,0x0
  c0:	3e0080e7          	jalr	992(ra) # 49c <getSysCount>
    // Wait for the child to complete
    wait(0);
  c4:	4501                	li	a0,0
  c6:	00000097          	auipc	ra,0x0
  ca:	336080e7          	jalr	822(ra) # 3fc <wait>
    {
      mask >>= 1;
      syscall_num++;
    }

    count = getSysCount(syscall_num, pid);
  ce:	85ce                	mv	a1,s3
  d0:	854a                	mv	a0,s2
  d2:	00000097          	auipc	ra,0x0
  d6:	3ca080e7          	jalr	970(ra) # 49c <getSysCount>
  da:	872a                	mv	a4,a0
    printf("Parent process (PID: %d) reports: SYSID %d (%s) called %d times by child PID %d.\n", parent_pid, syscall_num, syscall_names[syscall_num], count, pid);
  dc:	00391693          	slli	a3,s2,0x3
  e0:	fd068793          	addi	a5,a3,-48
  e4:	008786b3          	add	a3,a5,s0
  e8:	87ce                	mv	a5,s3
  ea:	f286b683          	ld	a3,-216(a3)
  ee:	864a                	mv	a2,s2
  f0:	85d2                	mv	a1,s4
  f2:	00001517          	auipc	a0,0x1
  f6:	89e50513          	addi	a0,a0,-1890 # 990 <malloc+0x154>
  fa:	00000097          	auipc	ra,0x0
  fe:	68a080e7          	jalr	1674(ra) # 784 <printf>
  }

  exit(0);
 102:	4501                	li	a0,0
 104:	00000097          	auipc	ra,0x0
 108:	2f0080e7          	jalr	752(ra) # 3f4 <exit>
    fprintf(2, "fork failed\n");
 10c:	00001597          	auipc	a1,0x1
 110:	86458593          	addi	a1,a1,-1948 # 970 <malloc+0x134>
 114:	4509                	li	a0,2
 116:	00000097          	auipc	ra,0x0
 11a:	640080e7          	jalr	1600(ra) # 756 <fprintf>
    exit(1);
 11e:	4505                	li	a0,1
 120:	00000097          	auipc	ra,0x0
 124:	2d4080e7          	jalr	724(ra) # 3f4 <exit>
    exec(argv[2], &argv[2]);
 128:	01090593          	addi	a1,s2,16
 12c:	01093503          	ld	a0,16(s2)
 130:	00000097          	auipc	ra,0x0
 134:	2fc080e7          	jalr	764(ra) # 42c <exec>
    fprintf(2, "exec failed\n");
 138:	00001597          	auipc	a1,0x1
 13c:	84858593          	addi	a1,a1,-1976 # 980 <malloc+0x144>
 140:	4509                	li	a0,2
 142:	00000097          	auipc	ra,0x0
 146:	614080e7          	jalr	1556(ra) # 756 <fprintf>
    exit(1);
 14a:	4505                	li	a0,1
 14c:	00000097          	auipc	ra,0x0
 150:	2a8080e7          	jalr	680(ra) # 3f4 <exit>
    count = getSysCount(syscall_num, pid);
 154:	85aa                	mv	a1,a0
 156:	4501                	li	a0,0
 158:	00000097          	auipc	ra,0x0
 15c:	344080e7          	jalr	836(ra) # 49c <getSysCount>
    wait(0);
 160:	4501                	li	a0,0
 162:	00000097          	auipc	ra,0x0
 166:	29a080e7          	jalr	666(ra) # 3fc <wait>
  int syscall_num = 0;
 16a:	4901                	li	s2,0
 16c:	b78d                	j	ce <main+0xce>

000000000000016e <_main>:
//
// wrapper so that it's OK if main() does not call exit().
//
void
_main()
{
 16e:	1141                	addi	sp,sp,-16
 170:	e406                	sd	ra,8(sp)
 172:	e022                	sd	s0,0(sp)
 174:	0800                	addi	s0,sp,16
  extern int main();
  main();
 176:	00000097          	auipc	ra,0x0
 17a:	e8a080e7          	jalr	-374(ra) # 0 <main>
  exit(0);
 17e:	4501                	li	a0,0
 180:	00000097          	auipc	ra,0x0
 184:	274080e7          	jalr	628(ra) # 3f4 <exit>

0000000000000188 <strcpy>:
}

char*
strcpy(char *s, const char *t)
{
 188:	1141                	addi	sp,sp,-16
 18a:	e422                	sd	s0,8(sp)
 18c:	0800                	addi	s0,sp,16
  char *os;

  os = s;
  while((*s++ = *t++) != 0)
 18e:	87aa                	mv	a5,a0
 190:	0585                	addi	a1,a1,1
 192:	0785                	addi	a5,a5,1
 194:	fff5c703          	lbu	a4,-1(a1)
 198:	fee78fa3          	sb	a4,-1(a5)
 19c:	fb75                	bnez	a4,190 <strcpy+0x8>
    ;
  return os;
}
 19e:	6422                	ld	s0,8(sp)
 1a0:	0141                	addi	sp,sp,16
 1a2:	8082                	ret

00000000000001a4 <strcmp>:

int
strcmp(const char *p, const char *q)
{
 1a4:	1141                	addi	sp,sp,-16
 1a6:	e422                	sd	s0,8(sp)
 1a8:	0800                	addi	s0,sp,16
  while(*p && *p == *q)
 1aa:	00054783          	lbu	a5,0(a0)
 1ae:	cb91                	beqz	a5,1c2 <strcmp+0x1e>
 1b0:	0005c703          	lbu	a4,0(a1)
 1b4:	00f71763          	bne	a4,a5,1c2 <strcmp+0x1e>
    p++, q++;
 1b8:	0505                	addi	a0,a0,1
 1ba:	0585                	addi	a1,a1,1
  while(*p && *p == *q)
 1bc:	00054783          	lbu	a5,0(a0)
 1c0:	fbe5                	bnez	a5,1b0 <strcmp+0xc>
  return (uchar)*p - (uchar)*q;
 1c2:	0005c503          	lbu	a0,0(a1)
}
 1c6:	40a7853b          	subw	a0,a5,a0
 1ca:	6422                	ld	s0,8(sp)
 1cc:	0141                	addi	sp,sp,16
 1ce:	8082                	ret

00000000000001d0 <strlen>:

uint
strlen(const char *s)
{
 1d0:	1141                	addi	sp,sp,-16
 1d2:	e422                	sd	s0,8(sp)
 1d4:	0800                	addi	s0,sp,16
  int n;

  for(n = 0; s[n]; n++)
 1d6:	00054783          	lbu	a5,0(a0)
 1da:	cf91                	beqz	a5,1f6 <strlen+0x26>
 1dc:	0505                	addi	a0,a0,1
 1de:	87aa                	mv	a5,a0
 1e0:	86be                	mv	a3,a5
 1e2:	0785                	addi	a5,a5,1
 1e4:	fff7c703          	lbu	a4,-1(a5)
 1e8:	ff65                	bnez	a4,1e0 <strlen+0x10>
 1ea:	40a6853b          	subw	a0,a3,a0
 1ee:	2505                	addiw	a0,a0,1
    ;
  return n;
}
 1f0:	6422                	ld	s0,8(sp)
 1f2:	0141                	addi	sp,sp,16
 1f4:	8082                	ret
  for(n = 0; s[n]; n++)
 1f6:	4501                	li	a0,0
 1f8:	bfe5                	j	1f0 <strlen+0x20>

00000000000001fa <memset>:

void*
memset(void *dst, int c, uint n)
{
 1fa:	1141                	addi	sp,sp,-16
 1fc:	e422                	sd	s0,8(sp)
 1fe:	0800                	addi	s0,sp,16
  char *cdst = (char *) dst;
  int i;
  for(i = 0; i < n; i++){
 200:	ca19                	beqz	a2,216 <memset+0x1c>
 202:	87aa                	mv	a5,a0
 204:	1602                	slli	a2,a2,0x20
 206:	9201                	srli	a2,a2,0x20
 208:	00a60733          	add	a4,a2,a0
    cdst[i] = c;
 20c:	00b78023          	sb	a1,0(a5)
  for(i = 0; i < n; i++){
 210:	0785                	addi	a5,a5,1
 212:	fee79de3          	bne	a5,a4,20c <memset+0x12>
  }
  return dst;
}
 216:	6422                	ld	s0,8(sp)
 218:	0141                	addi	sp,sp,16
 21a:	8082                	ret

000000000000021c <strchr>:

char*
strchr(const char *s, char c)
{
 21c:	1141                	addi	sp,sp,-16
 21e:	e422                	sd	s0,8(sp)
 220:	0800                	addi	s0,sp,16
  for(; *s; s++)
 222:	00054783          	lbu	a5,0(a0)
 226:	cb99                	beqz	a5,23c <strchr+0x20>
    if(*s == c)
 228:	00f58763          	beq	a1,a5,236 <strchr+0x1a>
  for(; *s; s++)
 22c:	0505                	addi	a0,a0,1
 22e:	00054783          	lbu	a5,0(a0)
 232:	fbfd                	bnez	a5,228 <strchr+0xc>
      return (char*)s;
  return 0;
 234:	4501                	li	a0,0
}
 236:	6422                	ld	s0,8(sp)
 238:	0141                	addi	sp,sp,16
 23a:	8082                	ret
  return 0;
 23c:	4501                	li	a0,0
 23e:	bfe5                	j	236 <strchr+0x1a>

0000000000000240 <gets>:

char*
gets(char *buf, int max)
{
 240:	711d                	addi	sp,sp,-96
 242:	ec86                	sd	ra,88(sp)
 244:	e8a2                	sd	s0,80(sp)
 246:	e4a6                	sd	s1,72(sp)
 248:	e0ca                	sd	s2,64(sp)
 24a:	fc4e                	sd	s3,56(sp)
 24c:	f852                	sd	s4,48(sp)
 24e:	f456                	sd	s5,40(sp)
 250:	f05a                	sd	s6,32(sp)
 252:	ec5e                	sd	s7,24(sp)
 254:	1080                	addi	s0,sp,96
 256:	8baa                	mv	s7,a0
 258:	8a2e                	mv	s4,a1
  int i, cc;
  char c;

  for(i=0; i+1 < max; ){
 25a:	892a                	mv	s2,a0
 25c:	4481                	li	s1,0
    cc = read(0, &c, 1);
    if(cc < 1)
      break;
    buf[i++] = c;
    if(c == '\n' || c == '\r')
 25e:	4aa9                	li	s5,10
 260:	4b35                	li	s6,13
  for(i=0; i+1 < max; ){
 262:	89a6                	mv	s3,s1
 264:	2485                	addiw	s1,s1,1
 266:	0344d863          	bge	s1,s4,296 <gets+0x56>
    cc = read(0, &c, 1);
 26a:	4605                	li	a2,1
 26c:	faf40593          	addi	a1,s0,-81
 270:	4501                	li	a0,0
 272:	00000097          	auipc	ra,0x0
 276:	19a080e7          	jalr	410(ra) # 40c <read>
    if(cc < 1)
 27a:	00a05e63          	blez	a0,296 <gets+0x56>
    buf[i++] = c;
 27e:	faf44783          	lbu	a5,-81(s0)
 282:	00f90023          	sb	a5,0(s2)
    if(c == '\n' || c == '\r')
 286:	01578763          	beq	a5,s5,294 <gets+0x54>
 28a:	0905                	addi	s2,s2,1
 28c:	fd679be3          	bne	a5,s6,262 <gets+0x22>
    buf[i++] = c;
 290:	89a6                	mv	s3,s1
 292:	a011                	j	296 <gets+0x56>
 294:	89a6                	mv	s3,s1
      break;
  }
  buf[i] = '\0';
 296:	99de                	add	s3,s3,s7
 298:	00098023          	sb	zero,0(s3)
  return buf;
}
 29c:	855e                	mv	a0,s7
 29e:	60e6                	ld	ra,88(sp)
 2a0:	6446                	ld	s0,80(sp)
 2a2:	64a6                	ld	s1,72(sp)
 2a4:	6906                	ld	s2,64(sp)
 2a6:	79e2                	ld	s3,56(sp)
 2a8:	7a42                	ld	s4,48(sp)
 2aa:	7aa2                	ld	s5,40(sp)
 2ac:	7b02                	ld	s6,32(sp)
 2ae:	6be2                	ld	s7,24(sp)
 2b0:	6125                	addi	sp,sp,96
 2b2:	8082                	ret

00000000000002b4 <stat>:

int
stat(const char *n, struct stat *st)
{
 2b4:	1101                	addi	sp,sp,-32
 2b6:	ec06                	sd	ra,24(sp)
 2b8:	e822                	sd	s0,16(sp)
 2ba:	e04a                	sd	s2,0(sp)
 2bc:	1000                	addi	s0,sp,32
 2be:	892e                	mv	s2,a1
  int fd;
  int r;

  fd = open(n, O_RDONLY);
 2c0:	4581                	li	a1,0
 2c2:	00000097          	auipc	ra,0x0
 2c6:	172080e7          	jalr	370(ra) # 434 <open>
  if(fd < 0)
 2ca:	02054663          	bltz	a0,2f6 <stat+0x42>
 2ce:	e426                	sd	s1,8(sp)
 2d0:	84aa                	mv	s1,a0
    return -1;
  r = fstat(fd, st);
 2d2:	85ca                	mv	a1,s2
 2d4:	00000097          	auipc	ra,0x0
 2d8:	178080e7          	jalr	376(ra) # 44c <fstat>
 2dc:	892a                	mv	s2,a0
  close(fd);
 2de:	8526                	mv	a0,s1
 2e0:	00000097          	auipc	ra,0x0
 2e4:	13c080e7          	jalr	316(ra) # 41c <close>
  return r;
 2e8:	64a2                	ld	s1,8(sp)
}
 2ea:	854a                	mv	a0,s2
 2ec:	60e2                	ld	ra,24(sp)
 2ee:	6442                	ld	s0,16(sp)
 2f0:	6902                	ld	s2,0(sp)
 2f2:	6105                	addi	sp,sp,32
 2f4:	8082                	ret
    return -1;
 2f6:	597d                	li	s2,-1
 2f8:	bfcd                	j	2ea <stat+0x36>

00000000000002fa <atoi>:

int
atoi(const char *s)
{
 2fa:	1141                	addi	sp,sp,-16
 2fc:	e422                	sd	s0,8(sp)
 2fe:	0800                	addi	s0,sp,16
  int n;

  n = 0;
  while('0' <= *s && *s <= '9')
 300:	00054683          	lbu	a3,0(a0)
 304:	fd06879b          	addiw	a5,a3,-48
 308:	0ff7f793          	zext.b	a5,a5
 30c:	4625                	li	a2,9
 30e:	02f66863          	bltu	a2,a5,33e <atoi+0x44>
 312:	872a                	mv	a4,a0
  n = 0;
 314:	4501                	li	a0,0
    n = n*10 + *s++ - '0';
 316:	0705                	addi	a4,a4,1
 318:	0025179b          	slliw	a5,a0,0x2
 31c:	9fa9                	addw	a5,a5,a0
 31e:	0017979b          	slliw	a5,a5,0x1
 322:	9fb5                	addw	a5,a5,a3
 324:	fd07851b          	addiw	a0,a5,-48
  while('0' <= *s && *s <= '9')
 328:	00074683          	lbu	a3,0(a4)
 32c:	fd06879b          	addiw	a5,a3,-48
 330:	0ff7f793          	zext.b	a5,a5
 334:	fef671e3          	bgeu	a2,a5,316 <atoi+0x1c>
  return n;
}
 338:	6422                	ld	s0,8(sp)
 33a:	0141                	addi	sp,sp,16
 33c:	8082                	ret
  n = 0;
 33e:	4501                	li	a0,0
 340:	bfe5                	j	338 <atoi+0x3e>

0000000000000342 <memmove>:

void*
memmove(void *vdst, const void *vsrc, int n)
{
 342:	1141                	addi	sp,sp,-16
 344:	e422                	sd	s0,8(sp)
 346:	0800                	addi	s0,sp,16
  char *dst;
  const char *src;

  dst = vdst;
  src = vsrc;
  if (src > dst) {
 348:	02b57463          	bgeu	a0,a1,370 <memmove+0x2e>
    while(n-- > 0)
 34c:	00c05f63          	blez	a2,36a <memmove+0x28>
 350:	1602                	slli	a2,a2,0x20
 352:	9201                	srli	a2,a2,0x20
 354:	00c507b3          	add	a5,a0,a2
  dst = vdst;
 358:	872a                	mv	a4,a0
      *dst++ = *src++;
 35a:	0585                	addi	a1,a1,1
 35c:	0705                	addi	a4,a4,1
 35e:	fff5c683          	lbu	a3,-1(a1)
 362:	fed70fa3          	sb	a3,-1(a4)
    while(n-- > 0)
 366:	fef71ae3          	bne	a4,a5,35a <memmove+0x18>
    src += n;
    while(n-- > 0)
      *--dst = *--src;
  }
  return vdst;
}
 36a:	6422                	ld	s0,8(sp)
 36c:	0141                	addi	sp,sp,16
 36e:	8082                	ret
    dst += n;
 370:	00c50733          	add	a4,a0,a2
    src += n;
 374:	95b2                	add	a1,a1,a2
    while(n-- > 0)
 376:	fec05ae3          	blez	a2,36a <memmove+0x28>
 37a:	fff6079b          	addiw	a5,a2,-1
 37e:	1782                	slli	a5,a5,0x20
 380:	9381                	srli	a5,a5,0x20
 382:	fff7c793          	not	a5,a5
 386:	97ba                	add	a5,a5,a4
      *--dst = *--src;
 388:	15fd                	addi	a1,a1,-1
 38a:	177d                	addi	a4,a4,-1
 38c:	0005c683          	lbu	a3,0(a1)
 390:	00d70023          	sb	a3,0(a4)
    while(n-- > 0)
 394:	fee79ae3          	bne	a5,a4,388 <memmove+0x46>
 398:	bfc9                	j	36a <memmove+0x28>

000000000000039a <memcmp>:

int
memcmp(const void *s1, const void *s2, uint n)
{
 39a:	1141                	addi	sp,sp,-16
 39c:	e422                	sd	s0,8(sp)
 39e:	0800                	addi	s0,sp,16
  const char *p1 = s1, *p2 = s2;
  while (n-- > 0) {
 3a0:	ca05                	beqz	a2,3d0 <memcmp+0x36>
 3a2:	fff6069b          	addiw	a3,a2,-1
 3a6:	1682                	slli	a3,a3,0x20
 3a8:	9281                	srli	a3,a3,0x20
 3aa:	0685                	addi	a3,a3,1
 3ac:	96aa                	add	a3,a3,a0
    if (*p1 != *p2) {
 3ae:	00054783          	lbu	a5,0(a0)
 3b2:	0005c703          	lbu	a4,0(a1)
 3b6:	00e79863          	bne	a5,a4,3c6 <memcmp+0x2c>
      return *p1 - *p2;
    }
    p1++;
 3ba:	0505                	addi	a0,a0,1
    p2++;
 3bc:	0585                	addi	a1,a1,1
  while (n-- > 0) {
 3be:	fed518e3          	bne	a0,a3,3ae <memcmp+0x14>
  }
  return 0;
 3c2:	4501                	li	a0,0
 3c4:	a019                	j	3ca <memcmp+0x30>
      return *p1 - *p2;
 3c6:	40e7853b          	subw	a0,a5,a4
}
 3ca:	6422                	ld	s0,8(sp)
 3cc:	0141                	addi	sp,sp,16
 3ce:	8082                	ret
  return 0;
 3d0:	4501                	li	a0,0
 3d2:	bfe5                	j	3ca <memcmp+0x30>

00000000000003d4 <memcpy>:

void *
memcpy(void *dst, const void *src, uint n)
{
 3d4:	1141                	addi	sp,sp,-16
 3d6:	e406                	sd	ra,8(sp)
 3d8:	e022                	sd	s0,0(sp)
 3da:	0800                	addi	s0,sp,16
  return memmove(dst, src, n);
 3dc:	00000097          	auipc	ra,0x0
 3e0:	f66080e7          	jalr	-154(ra) # 342 <memmove>
}
 3e4:	60a2                	ld	ra,8(sp)
 3e6:	6402                	ld	s0,0(sp)
 3e8:	0141                	addi	sp,sp,16
 3ea:	8082                	ret

00000000000003ec <fork>:
# generated by usys.pl - do not edit
#include "kernel/syscall.h"
.global fork
fork:
 li a7, SYS_fork
 3ec:	4885                	li	a7,1
 ecall
 3ee:	00000073          	ecall
 ret
 3f2:	8082                	ret

00000000000003f4 <exit>:
.global exit
exit:
 li a7, SYS_exit
 3f4:	4889                	li	a7,2
 ecall
 3f6:	00000073          	ecall
 ret
 3fa:	8082                	ret

00000000000003fc <wait>:
.global wait
wait:
 li a7, SYS_wait
 3fc:	488d                	li	a7,3
 ecall
 3fe:	00000073          	ecall
 ret
 402:	8082                	ret

0000000000000404 <pipe>:
.global pipe
pipe:
 li a7, SYS_pipe
 404:	4891                	li	a7,4
 ecall
 406:	00000073          	ecall
 ret
 40a:	8082                	ret

000000000000040c <read>:
.global read
read:
 li a7, SYS_read
 40c:	4895                	li	a7,5
 ecall
 40e:	00000073          	ecall
 ret
 412:	8082                	ret

0000000000000414 <write>:
.global write
write:
 li a7, SYS_write
 414:	48c1                	li	a7,16
 ecall
 416:	00000073          	ecall
 ret
 41a:	8082                	ret

000000000000041c <close>:
.global close
close:
 li a7, SYS_close
 41c:	48d5                	li	a7,21
 ecall
 41e:	00000073          	ecall
 ret
 422:	8082                	ret

0000000000000424 <kill>:
.global kill
kill:
 li a7, SYS_kill
 424:	4899                	li	a7,6
 ecall
 426:	00000073          	ecall
 ret
 42a:	8082                	ret

000000000000042c <exec>:
.global exec
exec:
 li a7, SYS_exec
 42c:	489d                	li	a7,7
 ecall
 42e:	00000073          	ecall
 ret
 432:	8082                	ret

0000000000000434 <open>:
.global open
open:
 li a7, SYS_open
 434:	48bd                	li	a7,15
 ecall
 436:	00000073          	ecall
 ret
 43a:	8082                	ret

000000000000043c <mknod>:
.global mknod
mknod:
 li a7, SYS_mknod
 43c:	48c5                	li	a7,17
 ecall
 43e:	00000073          	ecall
 ret
 442:	8082                	ret

0000000000000444 <unlink>:
.global unlink
unlink:
 li a7, SYS_unlink
 444:	48c9                	li	a7,18
 ecall
 446:	00000073          	ecall
 ret
 44a:	8082                	ret

000000000000044c <fstat>:
.global fstat
fstat:
 li a7, SYS_fstat
 44c:	48a1                	li	a7,8
 ecall
 44e:	00000073          	ecall
 ret
 452:	8082                	ret

0000000000000454 <link>:
.global link
link:
 li a7, SYS_link
 454:	48cd                	li	a7,19
 ecall
 456:	00000073          	ecall
 ret
 45a:	8082                	ret

000000000000045c <mkdir>:
.global mkdir
mkdir:
 li a7, SYS_mkdir
 45c:	48d1                	li	a7,20
 ecall
 45e:	00000073          	ecall
 ret
 462:	8082                	ret

0000000000000464 <chdir>:
.global chdir
chdir:
 li a7, SYS_chdir
 464:	48a5                	li	a7,9
 ecall
 466:	00000073          	ecall
 ret
 46a:	8082                	ret

000000000000046c <dup>:
.global dup
dup:
 li a7, SYS_dup
 46c:	48a9                	li	a7,10
 ecall
 46e:	00000073          	ecall
 ret
 472:	8082                	ret

0000000000000474 <getpid>:
.global getpid
getpid:
 li a7, SYS_getpid
 474:	48ad                	li	a7,11
 ecall
 476:	00000073          	ecall
 ret
 47a:	8082                	ret

000000000000047c <sbrk>:
.global sbrk
sbrk:
 li a7, SYS_sbrk
 47c:	48b1                	li	a7,12
 ecall
 47e:	00000073          	ecall
 ret
 482:	8082                	ret

0000000000000484 <sleep>:
.global sleep
sleep:
 li a7, SYS_sleep
 484:	48b5                	li	a7,13
 ecall
 486:	00000073          	ecall
 ret
 48a:	8082                	ret

000000000000048c <uptime>:
.global uptime
uptime:
 li a7, SYS_uptime
 48c:	48b9                	li	a7,14
 ecall
 48e:	00000073          	ecall
 ret
 492:	8082                	ret

0000000000000494 <waitx>:
.global waitx
waitx:
 li a7, SYS_waitx
 494:	48d9                	li	a7,22
 ecall
 496:	00000073          	ecall
 ret
 49a:	8082                	ret

000000000000049c <getSysCount>:
.global getSysCount
getSysCount:
 li a7, SYS_getSysCount
 49c:	48dd                	li	a7,23
 ecall
 49e:	00000073          	ecall
 ret
 4a2:	8082                	ret

00000000000004a4 <sigalarm>:
.global sigalarm
sigalarm:
 li a7, SYS_sigalarm
 4a4:	48e1                	li	a7,24
 ecall
 4a6:	00000073          	ecall
 ret
 4aa:	8082                	ret

00000000000004ac <sigreturn>:
.global sigreturn
sigreturn:
 li a7, SYS_sigreturn
 4ac:	48e5                	li	a7,25
 ecall
 4ae:	00000073          	ecall
 ret
 4b2:	8082                	ret

00000000000004b4 <settickets>:
.global settickets
settickets:
 li a7, SYS_settickets
 4b4:	48e9                	li	a7,26
 ecall
 4b6:	00000073          	ecall
 ret
 4ba:	8082                	ret

00000000000004bc <putc>:

static char digits[] = "0123456789ABCDEF";

static void
putc(int fd, char c)
{
 4bc:	1101                	addi	sp,sp,-32
 4be:	ec06                	sd	ra,24(sp)
 4c0:	e822                	sd	s0,16(sp)
 4c2:	1000                	addi	s0,sp,32
 4c4:	feb407a3          	sb	a1,-17(s0)
  write(fd, &c, 1);
 4c8:	4605                	li	a2,1
 4ca:	fef40593          	addi	a1,s0,-17
 4ce:	00000097          	auipc	ra,0x0
 4d2:	f46080e7          	jalr	-186(ra) # 414 <write>
}
 4d6:	60e2                	ld	ra,24(sp)
 4d8:	6442                	ld	s0,16(sp)
 4da:	6105                	addi	sp,sp,32
 4dc:	8082                	ret

00000000000004de <printint>:

static void
printint(int fd, int xx, int base, int sgn)
{
 4de:	7139                	addi	sp,sp,-64
 4e0:	fc06                	sd	ra,56(sp)
 4e2:	f822                	sd	s0,48(sp)
 4e4:	f426                	sd	s1,40(sp)
 4e6:	0080                	addi	s0,sp,64
 4e8:	84aa                	mv	s1,a0
  char buf[16];
  int i, neg;
  uint x;

  neg = 0;
  if(sgn && xx < 0){
 4ea:	c299                	beqz	a3,4f0 <printint+0x12>
 4ec:	0805cb63          	bltz	a1,582 <printint+0xa4>
    neg = 1;
    x = -xx;
  } else {
    x = xx;
 4f0:	2581                	sext.w	a1,a1
  neg = 0;
 4f2:	4881                	li	a7,0
 4f4:	fc040693          	addi	a3,s0,-64
  }

  i = 0;
 4f8:	4701                	li	a4,0
  do{
    buf[i++] = digits[x % base];
 4fa:	2601                	sext.w	a2,a2
 4fc:	00000517          	auipc	a0,0x0
 500:	71c50513          	addi	a0,a0,1820 # c18 <digits>
 504:	883a                	mv	a6,a4
 506:	2705                	addiw	a4,a4,1
 508:	02c5f7bb          	remuw	a5,a1,a2
 50c:	1782                	slli	a5,a5,0x20
 50e:	9381                	srli	a5,a5,0x20
 510:	97aa                	add	a5,a5,a0
 512:	0007c783          	lbu	a5,0(a5)
 516:	00f68023          	sb	a5,0(a3)
  }while((x /= base) != 0);
 51a:	0005879b          	sext.w	a5,a1
 51e:	02c5d5bb          	divuw	a1,a1,a2
 522:	0685                	addi	a3,a3,1
 524:	fec7f0e3          	bgeu	a5,a2,504 <printint+0x26>
  if(neg)
 528:	00088c63          	beqz	a7,540 <printint+0x62>
    buf[i++] = '-';
 52c:	fd070793          	addi	a5,a4,-48
 530:	00878733          	add	a4,a5,s0
 534:	02d00793          	li	a5,45
 538:	fef70823          	sb	a5,-16(a4)
 53c:	0028071b          	addiw	a4,a6,2

  while(--i >= 0)
 540:	02e05c63          	blez	a4,578 <printint+0x9a>
 544:	f04a                	sd	s2,32(sp)
 546:	ec4e                	sd	s3,24(sp)
 548:	fc040793          	addi	a5,s0,-64
 54c:	00e78933          	add	s2,a5,a4
 550:	fff78993          	addi	s3,a5,-1
 554:	99ba                	add	s3,s3,a4
 556:	377d                	addiw	a4,a4,-1
 558:	1702                	slli	a4,a4,0x20
 55a:	9301                	srli	a4,a4,0x20
 55c:	40e989b3          	sub	s3,s3,a4
    putc(fd, buf[i]);
 560:	fff94583          	lbu	a1,-1(s2)
 564:	8526                	mv	a0,s1
 566:	00000097          	auipc	ra,0x0
 56a:	f56080e7          	jalr	-170(ra) # 4bc <putc>
  while(--i >= 0)
 56e:	197d                	addi	s2,s2,-1
 570:	ff3918e3          	bne	s2,s3,560 <printint+0x82>
 574:	7902                	ld	s2,32(sp)
 576:	69e2                	ld	s3,24(sp)
}
 578:	70e2                	ld	ra,56(sp)
 57a:	7442                	ld	s0,48(sp)
 57c:	74a2                	ld	s1,40(sp)
 57e:	6121                	addi	sp,sp,64
 580:	8082                	ret
    x = -xx;
 582:	40b005bb          	negw	a1,a1
    neg = 1;
 586:	4885                	li	a7,1
    x = -xx;
 588:	b7b5                	j	4f4 <printint+0x16>

000000000000058a <vprintf>:
}

// Print to the given fd. Only understands %d, %x, %p, %s.
void
vprintf(int fd, const char *fmt, va_list ap)
{
 58a:	715d                	addi	sp,sp,-80
 58c:	e486                	sd	ra,72(sp)
 58e:	e0a2                	sd	s0,64(sp)
 590:	f84a                	sd	s2,48(sp)
 592:	0880                	addi	s0,sp,80
  char *s;
  int c, i, state;

  state = 0;
  for(i = 0; fmt[i]; i++){
 594:	0005c903          	lbu	s2,0(a1)
 598:	1a090a63          	beqz	s2,74c <vprintf+0x1c2>
 59c:	fc26                	sd	s1,56(sp)
 59e:	f44e                	sd	s3,40(sp)
 5a0:	f052                	sd	s4,32(sp)
 5a2:	ec56                	sd	s5,24(sp)
 5a4:	e85a                	sd	s6,16(sp)
 5a6:	e45e                	sd	s7,8(sp)
 5a8:	8aaa                	mv	s5,a0
 5aa:	8bb2                	mv	s7,a2
 5ac:	00158493          	addi	s1,a1,1
  state = 0;
 5b0:	4981                	li	s3,0
      if(c == '%'){
        state = '%';
      } else {
        putc(fd, c);
      }
    } else if(state == '%'){
 5b2:	02500a13          	li	s4,37
 5b6:	4b55                	li	s6,21
 5b8:	a839                	j	5d6 <vprintf+0x4c>
        putc(fd, c);
 5ba:	85ca                	mv	a1,s2
 5bc:	8556                	mv	a0,s5
 5be:	00000097          	auipc	ra,0x0
 5c2:	efe080e7          	jalr	-258(ra) # 4bc <putc>
 5c6:	a019                	j	5cc <vprintf+0x42>
    } else if(state == '%'){
 5c8:	01498d63          	beq	s3,s4,5e2 <vprintf+0x58>
  for(i = 0; fmt[i]; i++){
 5cc:	0485                	addi	s1,s1,1
 5ce:	fff4c903          	lbu	s2,-1(s1)
 5d2:	16090763          	beqz	s2,740 <vprintf+0x1b6>
    if(state == 0){
 5d6:	fe0999e3          	bnez	s3,5c8 <vprintf+0x3e>
      if(c == '%'){
 5da:	ff4910e3          	bne	s2,s4,5ba <vprintf+0x30>
        state = '%';
 5de:	89d2                	mv	s3,s4
 5e0:	b7f5                	j	5cc <vprintf+0x42>
      if(c == 'd'){
 5e2:	13490463          	beq	s2,s4,70a <vprintf+0x180>
 5e6:	f9d9079b          	addiw	a5,s2,-99
 5ea:	0ff7f793          	zext.b	a5,a5
 5ee:	12fb6763          	bltu	s6,a5,71c <vprintf+0x192>
 5f2:	f9d9079b          	addiw	a5,s2,-99
 5f6:	0ff7f713          	zext.b	a4,a5
 5fa:	12eb6163          	bltu	s6,a4,71c <vprintf+0x192>
 5fe:	00271793          	slli	a5,a4,0x2
 602:	00000717          	auipc	a4,0x0
 606:	5be70713          	addi	a4,a4,1470 # bc0 <malloc+0x384>
 60a:	97ba                	add	a5,a5,a4
 60c:	439c                	lw	a5,0(a5)
 60e:	97ba                	add	a5,a5,a4
 610:	8782                	jr	a5
        printint(fd, va_arg(ap, int), 10, 1);
 612:	008b8913          	addi	s2,s7,8
 616:	4685                	li	a3,1
 618:	4629                	li	a2,10
 61a:	000ba583          	lw	a1,0(s7)
 61e:	8556                	mv	a0,s5
 620:	00000097          	auipc	ra,0x0
 624:	ebe080e7          	jalr	-322(ra) # 4de <printint>
 628:	8bca                	mv	s7,s2
      } else {
        // Unknown % sequence.  Print it to draw attention.
        putc(fd, '%');
        putc(fd, c);
      }
      state = 0;
 62a:	4981                	li	s3,0
 62c:	b745                	j	5cc <vprintf+0x42>
        printint(fd, va_arg(ap, uint64), 10, 0);
 62e:	008b8913          	addi	s2,s7,8
 632:	4681                	li	a3,0
 634:	4629                	li	a2,10
 636:	000ba583          	lw	a1,0(s7)
 63a:	8556                	mv	a0,s5
 63c:	00000097          	auipc	ra,0x0
 640:	ea2080e7          	jalr	-350(ra) # 4de <printint>
 644:	8bca                	mv	s7,s2
      state = 0;
 646:	4981                	li	s3,0
 648:	b751                	j	5cc <vprintf+0x42>
        printint(fd, va_arg(ap, int), 16, 0);
 64a:	008b8913          	addi	s2,s7,8
 64e:	4681                	li	a3,0
 650:	4641                	li	a2,16
 652:	000ba583          	lw	a1,0(s7)
 656:	8556                	mv	a0,s5
 658:	00000097          	auipc	ra,0x0
 65c:	e86080e7          	jalr	-378(ra) # 4de <printint>
 660:	8bca                	mv	s7,s2
      state = 0;
 662:	4981                	li	s3,0
 664:	b7a5                	j	5cc <vprintf+0x42>
 666:	e062                	sd	s8,0(sp)
        printptr(fd, va_arg(ap, uint64));
 668:	008b8c13          	addi	s8,s7,8
 66c:	000bb983          	ld	s3,0(s7)
  putc(fd, '0');
 670:	03000593          	li	a1,48
 674:	8556                	mv	a0,s5
 676:	00000097          	auipc	ra,0x0
 67a:	e46080e7          	jalr	-442(ra) # 4bc <putc>
  putc(fd, 'x');
 67e:	07800593          	li	a1,120
 682:	8556                	mv	a0,s5
 684:	00000097          	auipc	ra,0x0
 688:	e38080e7          	jalr	-456(ra) # 4bc <putc>
 68c:	4941                	li	s2,16
    putc(fd, digits[x >> (sizeof(uint64) * 8 - 4)]);
 68e:	00000b97          	auipc	s7,0x0
 692:	58ab8b93          	addi	s7,s7,1418 # c18 <digits>
 696:	03c9d793          	srli	a5,s3,0x3c
 69a:	97de                	add	a5,a5,s7
 69c:	0007c583          	lbu	a1,0(a5)
 6a0:	8556                	mv	a0,s5
 6a2:	00000097          	auipc	ra,0x0
 6a6:	e1a080e7          	jalr	-486(ra) # 4bc <putc>
  for (i = 0; i < (sizeof(uint64) * 2); i++, x <<= 4)
 6aa:	0992                	slli	s3,s3,0x4
 6ac:	397d                	addiw	s2,s2,-1
 6ae:	fe0914e3          	bnez	s2,696 <vprintf+0x10c>
        printptr(fd, va_arg(ap, uint64));
 6b2:	8be2                	mv	s7,s8
      state = 0;
 6b4:	4981                	li	s3,0
 6b6:	6c02                	ld	s8,0(sp)
 6b8:	bf11                	j	5cc <vprintf+0x42>
        s = va_arg(ap, char*);
 6ba:	008b8993          	addi	s3,s7,8
 6be:	000bb903          	ld	s2,0(s7)
        if(s == 0)
 6c2:	02090163          	beqz	s2,6e4 <vprintf+0x15a>
        while(*s != 0){
 6c6:	00094583          	lbu	a1,0(s2)
 6ca:	c9a5                	beqz	a1,73a <vprintf+0x1b0>
          putc(fd, *s);
 6cc:	8556                	mv	a0,s5
 6ce:	00000097          	auipc	ra,0x0
 6d2:	dee080e7          	jalr	-530(ra) # 4bc <putc>
          s++;
 6d6:	0905                	addi	s2,s2,1
        while(*s != 0){
 6d8:	00094583          	lbu	a1,0(s2)
 6dc:	f9e5                	bnez	a1,6cc <vprintf+0x142>
        s = va_arg(ap, char*);
 6de:	8bce                	mv	s7,s3
      state = 0;
 6e0:	4981                	li	s3,0
 6e2:	b5ed                	j	5cc <vprintf+0x42>
          s = "(null)";
 6e4:	00000917          	auipc	s2,0x0
 6e8:	3fc90913          	addi	s2,s2,1020 # ae0 <malloc+0x2a4>
        while(*s != 0){
 6ec:	02800593          	li	a1,40
 6f0:	bff1                	j	6cc <vprintf+0x142>
        putc(fd, va_arg(ap, uint));
 6f2:	008b8913          	addi	s2,s7,8
 6f6:	000bc583          	lbu	a1,0(s7)
 6fa:	8556                	mv	a0,s5
 6fc:	00000097          	auipc	ra,0x0
 700:	dc0080e7          	jalr	-576(ra) # 4bc <putc>
 704:	8bca                	mv	s7,s2
      state = 0;
 706:	4981                	li	s3,0
 708:	b5d1                	j	5cc <vprintf+0x42>
        putc(fd, c);
 70a:	02500593          	li	a1,37
 70e:	8556                	mv	a0,s5
 710:	00000097          	auipc	ra,0x0
 714:	dac080e7          	jalr	-596(ra) # 4bc <putc>
      state = 0;
 718:	4981                	li	s3,0
 71a:	bd4d                	j	5cc <vprintf+0x42>
        putc(fd, '%');
 71c:	02500593          	li	a1,37
 720:	8556                	mv	a0,s5
 722:	00000097          	auipc	ra,0x0
 726:	d9a080e7          	jalr	-614(ra) # 4bc <putc>
        putc(fd, c);
 72a:	85ca                	mv	a1,s2
 72c:	8556                	mv	a0,s5
 72e:	00000097          	auipc	ra,0x0
 732:	d8e080e7          	jalr	-626(ra) # 4bc <putc>
      state = 0;
 736:	4981                	li	s3,0
 738:	bd51                	j	5cc <vprintf+0x42>
        s = va_arg(ap, char*);
 73a:	8bce                	mv	s7,s3
      state = 0;
 73c:	4981                	li	s3,0
 73e:	b579                	j	5cc <vprintf+0x42>
 740:	74e2                	ld	s1,56(sp)
 742:	79a2                	ld	s3,40(sp)
 744:	7a02                	ld	s4,32(sp)
 746:	6ae2                	ld	s5,24(sp)
 748:	6b42                	ld	s6,16(sp)
 74a:	6ba2                	ld	s7,8(sp)
    }
  }
}
 74c:	60a6                	ld	ra,72(sp)
 74e:	6406                	ld	s0,64(sp)
 750:	7942                	ld	s2,48(sp)
 752:	6161                	addi	sp,sp,80
 754:	8082                	ret

0000000000000756 <fprintf>:

void
fprintf(int fd, const char *fmt, ...)
{
 756:	715d                	addi	sp,sp,-80
 758:	ec06                	sd	ra,24(sp)
 75a:	e822                	sd	s0,16(sp)
 75c:	1000                	addi	s0,sp,32
 75e:	e010                	sd	a2,0(s0)
 760:	e414                	sd	a3,8(s0)
 762:	e818                	sd	a4,16(s0)
 764:	ec1c                	sd	a5,24(s0)
 766:	03043023          	sd	a6,32(s0)
 76a:	03143423          	sd	a7,40(s0)
  va_list ap;

  va_start(ap, fmt);
 76e:	fe843423          	sd	s0,-24(s0)
  vprintf(fd, fmt, ap);
 772:	8622                	mv	a2,s0
 774:	00000097          	auipc	ra,0x0
 778:	e16080e7          	jalr	-490(ra) # 58a <vprintf>
}
 77c:	60e2                	ld	ra,24(sp)
 77e:	6442                	ld	s0,16(sp)
 780:	6161                	addi	sp,sp,80
 782:	8082                	ret

0000000000000784 <printf>:

void
printf(const char *fmt, ...)
{
 784:	711d                	addi	sp,sp,-96
 786:	ec06                	sd	ra,24(sp)
 788:	e822                	sd	s0,16(sp)
 78a:	1000                	addi	s0,sp,32
 78c:	e40c                	sd	a1,8(s0)
 78e:	e810                	sd	a2,16(s0)
 790:	ec14                	sd	a3,24(s0)
 792:	f018                	sd	a4,32(s0)
 794:	f41c                	sd	a5,40(s0)
 796:	03043823          	sd	a6,48(s0)
 79a:	03143c23          	sd	a7,56(s0)
  va_list ap;

  va_start(ap, fmt);
 79e:	00840613          	addi	a2,s0,8
 7a2:	fec43423          	sd	a2,-24(s0)
  vprintf(1, fmt, ap);
 7a6:	85aa                	mv	a1,a0
 7a8:	4505                	li	a0,1
 7aa:	00000097          	auipc	ra,0x0
 7ae:	de0080e7          	jalr	-544(ra) # 58a <vprintf>
}
 7b2:	60e2                	ld	ra,24(sp)
 7b4:	6442                	ld	s0,16(sp)
 7b6:	6125                	addi	sp,sp,96
 7b8:	8082                	ret

00000000000007ba <free>:
static Header base;
static Header *freep;

void
free(void *ap)
{
 7ba:	1141                	addi	sp,sp,-16
 7bc:	e422                	sd	s0,8(sp)
 7be:	0800                	addi	s0,sp,16
  Header *bp, *p;

  bp = (Header*)ap - 1;
 7c0:	ff050693          	addi	a3,a0,-16
  for(p = freep; !(bp > p && bp < p->s.ptr); p = p->s.ptr)
 7c4:	00001797          	auipc	a5,0x1
 7c8:	83c7b783          	ld	a5,-1988(a5) # 1000 <freep>
 7cc:	a02d                	j	7f6 <free+0x3c>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
      break;
  if(bp + bp->s.size == p->s.ptr){
    bp->s.size += p->s.ptr->s.size;
 7ce:	4618                	lw	a4,8(a2)
 7d0:	9f2d                	addw	a4,a4,a1
 7d2:	fee52c23          	sw	a4,-8(a0)
    bp->s.ptr = p->s.ptr->s.ptr;
 7d6:	6398                	ld	a4,0(a5)
 7d8:	6310                	ld	a2,0(a4)
 7da:	a83d                	j	818 <free+0x5e>
  } else
    bp->s.ptr = p->s.ptr;
  if(p + p->s.size == bp){
    p->s.size += bp->s.size;
 7dc:	ff852703          	lw	a4,-8(a0)
 7e0:	9f31                	addw	a4,a4,a2
 7e2:	c798                	sw	a4,8(a5)
    p->s.ptr = bp->s.ptr;
 7e4:	ff053683          	ld	a3,-16(a0)
 7e8:	a091                	j	82c <free+0x72>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
 7ea:	6398                	ld	a4,0(a5)
 7ec:	00e7e463          	bltu	a5,a4,7f4 <free+0x3a>
 7f0:	00e6ea63          	bltu	a3,a4,804 <free+0x4a>
{
 7f4:	87ba                	mv	a5,a4
  for(p = freep; !(bp > p && bp < p->s.ptr); p = p->s.ptr)
 7f6:	fed7fae3          	bgeu	a5,a3,7ea <free+0x30>
 7fa:	6398                	ld	a4,0(a5)
 7fc:	00e6e463          	bltu	a3,a4,804 <free+0x4a>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
 800:	fee7eae3          	bltu	a5,a4,7f4 <free+0x3a>
  if(bp + bp->s.size == p->s.ptr){
 804:	ff852583          	lw	a1,-8(a0)
 808:	6390                	ld	a2,0(a5)
 80a:	02059813          	slli	a6,a1,0x20
 80e:	01c85713          	srli	a4,a6,0x1c
 812:	9736                	add	a4,a4,a3
 814:	fae60de3          	beq	a2,a4,7ce <free+0x14>
    bp->s.ptr = p->s.ptr->s.ptr;
 818:	fec53823          	sd	a2,-16(a0)
  if(p + p->s.size == bp){
 81c:	4790                	lw	a2,8(a5)
 81e:	02061593          	slli	a1,a2,0x20
 822:	01c5d713          	srli	a4,a1,0x1c
 826:	973e                	add	a4,a4,a5
 828:	fae68ae3          	beq	a3,a4,7dc <free+0x22>
    p->s.ptr = bp->s.ptr;
 82c:	e394                	sd	a3,0(a5)
  } else
    p->s.ptr = bp;
  freep = p;
 82e:	00000717          	auipc	a4,0x0
 832:	7cf73923          	sd	a5,2002(a4) # 1000 <freep>
}
 836:	6422                	ld	s0,8(sp)
 838:	0141                	addi	sp,sp,16
 83a:	8082                	ret

000000000000083c <malloc>:
  return freep;
}

void*
malloc(uint nbytes)
{
 83c:	7139                	addi	sp,sp,-64
 83e:	fc06                	sd	ra,56(sp)
 840:	f822                	sd	s0,48(sp)
 842:	f426                	sd	s1,40(sp)
 844:	ec4e                	sd	s3,24(sp)
 846:	0080                	addi	s0,sp,64
  Header *p, *prevp;
  uint nunits;

  nunits = (nbytes + sizeof(Header) - 1)/sizeof(Header) + 1;
 848:	02051493          	slli	s1,a0,0x20
 84c:	9081                	srli	s1,s1,0x20
 84e:	04bd                	addi	s1,s1,15
 850:	8091                	srli	s1,s1,0x4
 852:	0014899b          	addiw	s3,s1,1
 856:	0485                	addi	s1,s1,1
  if((prevp = freep) == 0){
 858:	00000517          	auipc	a0,0x0
 85c:	7a853503          	ld	a0,1960(a0) # 1000 <freep>
 860:	c915                	beqz	a0,894 <malloc+0x58>
    base.s.ptr = freep = prevp = &base;
    base.s.size = 0;
  }
  for(p = prevp->s.ptr; ; prevp = p, p = p->s.ptr){
 862:	611c                	ld	a5,0(a0)
    if(p->s.size >= nunits){
 864:	4798                	lw	a4,8(a5)
 866:	08977e63          	bgeu	a4,s1,902 <malloc+0xc6>
 86a:	f04a                	sd	s2,32(sp)
 86c:	e852                	sd	s4,16(sp)
 86e:	e456                	sd	s5,8(sp)
 870:	e05a                	sd	s6,0(sp)
  if(nu < 4096)
 872:	8a4e                	mv	s4,s3
 874:	0009871b          	sext.w	a4,s3
 878:	6685                	lui	a3,0x1
 87a:	00d77363          	bgeu	a4,a3,880 <malloc+0x44>
 87e:	6a05                	lui	s4,0x1
 880:	000a0b1b          	sext.w	s6,s4
  p = sbrk(nu * sizeof(Header));
 884:	004a1a1b          	slliw	s4,s4,0x4
        p->s.size = nunits;
      }
      freep = prevp;
      return (void*)(p + 1);
    }
    if(p == freep)
 888:	00000917          	auipc	s2,0x0
 88c:	77890913          	addi	s2,s2,1912 # 1000 <freep>
  if(p == (char*)-1)
 890:	5afd                	li	s5,-1
 892:	a091                	j	8d6 <malloc+0x9a>
 894:	f04a                	sd	s2,32(sp)
 896:	e852                	sd	s4,16(sp)
 898:	e456                	sd	s5,8(sp)
 89a:	e05a                	sd	s6,0(sp)
    base.s.ptr = freep = prevp = &base;
 89c:	00000797          	auipc	a5,0x0
 8a0:	77478793          	addi	a5,a5,1908 # 1010 <base>
 8a4:	00000717          	auipc	a4,0x0
 8a8:	74f73e23          	sd	a5,1884(a4) # 1000 <freep>
 8ac:	e39c                	sd	a5,0(a5)
    base.s.size = 0;
 8ae:	0007a423          	sw	zero,8(a5)
    if(p->s.size >= nunits){
 8b2:	b7c1                	j	872 <malloc+0x36>
        prevp->s.ptr = p->s.ptr;
 8b4:	6398                	ld	a4,0(a5)
 8b6:	e118                	sd	a4,0(a0)
 8b8:	a08d                	j	91a <malloc+0xde>
  hp->s.size = nu;
 8ba:	01652423          	sw	s6,8(a0)
  free((void*)(hp + 1));
 8be:	0541                	addi	a0,a0,16
 8c0:	00000097          	auipc	ra,0x0
 8c4:	efa080e7          	jalr	-262(ra) # 7ba <free>
  return freep;
 8c8:	00093503          	ld	a0,0(s2)
      if((p = morecore(nunits)) == 0)
 8cc:	c13d                	beqz	a0,932 <malloc+0xf6>
  for(p = prevp->s.ptr; ; prevp = p, p = p->s.ptr){
 8ce:	611c                	ld	a5,0(a0)
    if(p->s.size >= nunits){
 8d0:	4798                	lw	a4,8(a5)
 8d2:	02977463          	bgeu	a4,s1,8fa <malloc+0xbe>
    if(p == freep)
 8d6:	00093703          	ld	a4,0(s2)
 8da:	853e                	mv	a0,a5
 8dc:	fef719e3          	bne	a4,a5,8ce <malloc+0x92>
  p = sbrk(nu * sizeof(Header));
 8e0:	8552                	mv	a0,s4
 8e2:	00000097          	auipc	ra,0x0
 8e6:	b9a080e7          	jalr	-1126(ra) # 47c <sbrk>
  if(p == (char*)-1)
 8ea:	fd5518e3          	bne	a0,s5,8ba <malloc+0x7e>
        return 0;
 8ee:	4501                	li	a0,0
 8f0:	7902                	ld	s2,32(sp)
 8f2:	6a42                	ld	s4,16(sp)
 8f4:	6aa2                	ld	s5,8(sp)
 8f6:	6b02                	ld	s6,0(sp)
 8f8:	a03d                	j	926 <malloc+0xea>
 8fa:	7902                	ld	s2,32(sp)
 8fc:	6a42                	ld	s4,16(sp)
 8fe:	6aa2                	ld	s5,8(sp)
 900:	6b02                	ld	s6,0(sp)
      if(p->s.size == nunits)
 902:	fae489e3          	beq	s1,a4,8b4 <malloc+0x78>
        p->s.size -= nunits;
 906:	4137073b          	subw	a4,a4,s3
 90a:	c798                	sw	a4,8(a5)
        p += p->s.size;
 90c:	02071693          	slli	a3,a4,0x20
 910:	01c6d713          	srli	a4,a3,0x1c
 914:	97ba                	add	a5,a5,a4
        p->s.size = nunits;
 916:	0137a423          	sw	s3,8(a5)
      freep = prevp;
 91a:	00000717          	auipc	a4,0x0
 91e:	6ea73323          	sd	a0,1766(a4) # 1000 <freep>
      return (void*)(p + 1);
 922:	01078513          	addi	a0,a5,16
  }
}
 926:	70e2                	ld	ra,56(sp)
 928:	7442                	ld	s0,48(sp)
 92a:	74a2                	ld	s1,40(sp)
 92c:	69e2                	ld	s3,24(sp)
 92e:	6121                	addi	sp,sp,64
 930:	8082                	ret
 932:	7902                	ld	s2,32(sp)
 934:	6a42                	ld	s4,16(sp)
 936:	6aa2                	ld	s5,8(sp)
 938:	6b02                	ld	s6,0(sp)
 93a:	b7f5                	j	926 <malloc+0xea>
