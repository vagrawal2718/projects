
kernel/kernel:     file format elf64-littleriscv


Disassembly of section .text:

0000000080000000 <_entry>:
    80000000:	00009117          	auipc	sp,0x9
    80000004:	a3010113          	addi	sp,sp,-1488 # 80008a30 <stack0>
    80000008:	6505                	lui	a0,0x1
    8000000a:	f14025f3          	csrr	a1,mhartid
    8000000e:	0585                	addi	a1,a1,1
    80000010:	02b50533          	mul	a0,a0,a1
    80000014:	912a                	add	sp,sp,a0
    80000016:	076000ef          	jal	8000008c <start>

000000008000001a <spin>:
    8000001a:	a001                	j	8000001a <spin>

000000008000001c <timerinit>:
// at timervec in kernelvec.S,
// which turns them into software interrupts for
// devintr() in trap.c.
void
timerinit()
{
    8000001c:	1141                	addi	sp,sp,-16
    8000001e:	e422                	sd	s0,8(sp)
    80000020:	0800                	addi	s0,sp,16
// which hart (core) is this?
static inline uint64
r_mhartid()
{
  uint64 x;
  asm volatile("csrr %0, mhartid" : "=r" (x) );
    80000022:	f14027f3          	csrr	a5,mhartid
  // each CPU has a separate source of timer interrupts.
  int id = r_mhartid();
    80000026:	0007859b          	sext.w	a1,a5

  // ask the CLINT for a timer interrupt.
  int interval = 1000000; // cycles; about 1/10th second in qemu.
  *(uint64*)CLINT_MTIMECMP(id) = *(uint64*)CLINT_MTIME + interval;
    8000002a:	0037979b          	slliw	a5,a5,0x3
    8000002e:	02004737          	lui	a4,0x2004
    80000032:	97ba                	add	a5,a5,a4
    80000034:	0200c737          	lui	a4,0x200c
    80000038:	1761                	addi	a4,a4,-8 # 200bff8 <_entry-0x7dff4008>
    8000003a:	6318                	ld	a4,0(a4)
    8000003c:	000f4637          	lui	a2,0xf4
    80000040:	24060613          	addi	a2,a2,576 # f4240 <_entry-0x7ff0bdc0>
    80000044:	9732                	add	a4,a4,a2
    80000046:	e398                	sd	a4,0(a5)

  // prepare information in scratch[] for timervec.
  // scratch[0..2] : space for timervec to save registers.
  // scratch[3] : address of CLINT MTIMECMP register.
  // scratch[4] : desired interval (in cycles) between timer interrupts.
  uint64 *scratch = &timer_scratch[id][0];
    80000048:	00259693          	slli	a3,a1,0x2
    8000004c:	96ae                	add	a3,a3,a1
    8000004e:	068e                	slli	a3,a3,0x3
    80000050:	00009717          	auipc	a4,0x9
    80000054:	8a070713          	addi	a4,a4,-1888 # 800088f0 <timer_scratch>
    80000058:	9736                	add	a4,a4,a3
  scratch[3] = CLINT_MTIMECMP(id);
    8000005a:	ef1c                	sd	a5,24(a4)
  scratch[4] = interval;
    8000005c:	f310                	sd	a2,32(a4)
}

static inline void 
w_mscratch(uint64 x)
{
  asm volatile("csrw mscratch, %0" : : "r" (x));
    8000005e:	34071073          	csrw	mscratch,a4
  asm volatile("csrw mtvec, %0" : : "r" (x));
    80000062:	00006797          	auipc	a5,0x6
    80000066:	45e78793          	addi	a5,a5,1118 # 800064c0 <timervec>
    8000006a:	30579073          	csrw	mtvec,a5
  asm volatile("csrr %0, mstatus" : "=r" (x) );
    8000006e:	300027f3          	csrr	a5,mstatus

  // set the machine-mode trap handler.
  w_mtvec((uint64)timervec);

  // enable machine-mode interrupts.
  w_mstatus(r_mstatus() | MSTATUS_MIE);
    80000072:	0087e793          	ori	a5,a5,8
  asm volatile("csrw mstatus, %0" : : "r" (x));
    80000076:	30079073          	csrw	mstatus,a5
  asm volatile("csrr %0, mie" : "=r" (x) );
    8000007a:	304027f3          	csrr	a5,mie

  // enable machine-mode timer interrupts.
  w_mie(r_mie() | MIE_MTIE);
    8000007e:	0807e793          	ori	a5,a5,128
  asm volatile("csrw mie, %0" : : "r" (x));
    80000082:	30479073          	csrw	mie,a5
}
    80000086:	6422                	ld	s0,8(sp)
    80000088:	0141                	addi	sp,sp,16
    8000008a:	8082                	ret

000000008000008c <start>:
{
    8000008c:	1141                	addi	sp,sp,-16
    8000008e:	e406                	sd	ra,8(sp)
    80000090:	e022                	sd	s0,0(sp)
    80000092:	0800                	addi	s0,sp,16
  asm volatile("csrr %0, mstatus" : "=r" (x) );
    80000094:	300027f3          	csrr	a5,mstatus
  x &= ~MSTATUS_MPP_MASK;
    80000098:	7779                	lui	a4,0xffffe
    8000009a:	7ff70713          	addi	a4,a4,2047 # ffffffffffffe7ff <end+0xffffffff7ffd3a9f>
    8000009e:	8ff9                	and	a5,a5,a4
  x |= MSTATUS_MPP_S;
    800000a0:	6705                	lui	a4,0x1
    800000a2:	80070713          	addi	a4,a4,-2048 # 800 <_entry-0x7ffff800>
    800000a6:	8fd9                	or	a5,a5,a4
  asm volatile("csrw mstatus, %0" : : "r" (x));
    800000a8:	30079073          	csrw	mstatus,a5
  asm volatile("csrw mepc, %0" : : "r" (x));
    800000ac:	00001797          	auipc	a5,0x1
    800000b0:	e2678793          	addi	a5,a5,-474 # 80000ed2 <main>
    800000b4:	34179073          	csrw	mepc,a5
  asm volatile("csrw satp, %0" : : "r" (x));
    800000b8:	4781                	li	a5,0
    800000ba:	18079073          	csrw	satp,a5
  asm volatile("csrw medeleg, %0" : : "r" (x));
    800000be:	67c1                	lui	a5,0x10
    800000c0:	17fd                	addi	a5,a5,-1 # ffff <_entry-0x7fff0001>
    800000c2:	30279073          	csrw	medeleg,a5
  asm volatile("csrw mideleg, %0" : : "r" (x));
    800000c6:	30379073          	csrw	mideleg,a5
  asm volatile("csrr %0, sie" : "=r" (x) );
    800000ca:	104027f3          	csrr	a5,sie
  w_sie(r_sie() | SIE_SEIE | SIE_STIE | SIE_SSIE);
    800000ce:	2227e793          	ori	a5,a5,546
  asm volatile("csrw sie, %0" : : "r" (x));
    800000d2:	10479073          	csrw	sie,a5
  asm volatile("csrw pmpaddr0, %0" : : "r" (x));
    800000d6:	57fd                	li	a5,-1
    800000d8:	83a9                	srli	a5,a5,0xa
    800000da:	3b079073          	csrw	pmpaddr0,a5
  asm volatile("csrw pmpcfg0, %0" : : "r" (x));
    800000de:	47bd                	li	a5,15
    800000e0:	3a079073          	csrw	pmpcfg0,a5
  timerinit();
    800000e4:	00000097          	auipc	ra,0x0
    800000e8:	f38080e7          	jalr	-200(ra) # 8000001c <timerinit>
  asm volatile("csrr %0, mhartid" : "=r" (x) );
    800000ec:	f14027f3          	csrr	a5,mhartid
  w_tp(id);
    800000f0:	2781                	sext.w	a5,a5
}

static inline void 
w_tp(uint64 x)
{
  asm volatile("mv tp, %0" : : "r" (x));
    800000f2:	823e                	mv	tp,a5
  asm volatile("mret");
    800000f4:	30200073          	mret
}
    800000f8:	60a2                	ld	ra,8(sp)
    800000fa:	6402                	ld	s0,0(sp)
    800000fc:	0141                	addi	sp,sp,16
    800000fe:	8082                	ret

0000000080000100 <consolewrite>:
//
// user write()s to the console go here.
//
int
consolewrite(int user_src, uint64 src, int n)
{
    80000100:	715d                	addi	sp,sp,-80
    80000102:	e486                	sd	ra,72(sp)
    80000104:	e0a2                	sd	s0,64(sp)
    80000106:	f84a                	sd	s2,48(sp)
    80000108:	0880                	addi	s0,sp,80
  int i;

  for(i = 0; i < n; i++){
    8000010a:	04c05663          	blez	a2,80000156 <consolewrite+0x56>
    8000010e:	fc26                	sd	s1,56(sp)
    80000110:	f44e                	sd	s3,40(sp)
    80000112:	f052                	sd	s4,32(sp)
    80000114:	ec56                	sd	s5,24(sp)
    80000116:	8a2a                	mv	s4,a0
    80000118:	84ae                	mv	s1,a1
    8000011a:	89b2                	mv	s3,a2
    8000011c:	4901                	li	s2,0
    char c;
    if(either_copyin(&c, user_src, src+i, 1) == -1)
    8000011e:	5afd                	li	s5,-1
    80000120:	4685                	li	a3,1
    80000122:	8626                	mv	a2,s1
    80000124:	85d2                	mv	a1,s4
    80000126:	fbf40513          	addi	a0,s0,-65
    8000012a:	00002097          	auipc	ra,0x2
    8000012e:	74c080e7          	jalr	1868(ra) # 80002876 <either_copyin>
    80000132:	03550463          	beq	a0,s5,8000015a <consolewrite+0x5a>
      break;
    uartputc(c);
    80000136:	fbf44503          	lbu	a0,-65(s0)
    8000013a:	00000097          	auipc	ra,0x0
    8000013e:	7e4080e7          	jalr	2020(ra) # 8000091e <uartputc>
  for(i = 0; i < n; i++){
    80000142:	2905                	addiw	s2,s2,1
    80000144:	0485                	addi	s1,s1,1
    80000146:	fd299de3          	bne	s3,s2,80000120 <consolewrite+0x20>
    8000014a:	894e                	mv	s2,s3
    8000014c:	74e2                	ld	s1,56(sp)
    8000014e:	79a2                	ld	s3,40(sp)
    80000150:	7a02                	ld	s4,32(sp)
    80000152:	6ae2                	ld	s5,24(sp)
    80000154:	a039                	j	80000162 <consolewrite+0x62>
    80000156:	4901                	li	s2,0
    80000158:	a029                	j	80000162 <consolewrite+0x62>
    8000015a:	74e2                	ld	s1,56(sp)
    8000015c:	79a2                	ld	s3,40(sp)
    8000015e:	7a02                	ld	s4,32(sp)
    80000160:	6ae2                	ld	s5,24(sp)
  }

  return i;
}
    80000162:	854a                	mv	a0,s2
    80000164:	60a6                	ld	ra,72(sp)
    80000166:	6406                	ld	s0,64(sp)
    80000168:	7942                	ld	s2,48(sp)
    8000016a:	6161                	addi	sp,sp,80
    8000016c:	8082                	ret

000000008000016e <consoleread>:
// user_dist indicates whether dst is a user
// or kernel address.
//
int
consoleread(int user_dst, uint64 dst, int n)
{
    8000016e:	711d                	addi	sp,sp,-96
    80000170:	ec86                	sd	ra,88(sp)
    80000172:	e8a2                	sd	s0,80(sp)
    80000174:	e4a6                	sd	s1,72(sp)
    80000176:	e0ca                	sd	s2,64(sp)
    80000178:	fc4e                	sd	s3,56(sp)
    8000017a:	f852                	sd	s4,48(sp)
    8000017c:	f456                	sd	s5,40(sp)
    8000017e:	f05a                	sd	s6,32(sp)
    80000180:	1080                	addi	s0,sp,96
    80000182:	8aaa                	mv	s5,a0
    80000184:	8a2e                	mv	s4,a1
    80000186:	89b2                	mv	s3,a2
  uint target;
  int c;
  char cbuf;

  target = n;
    80000188:	00060b1b          	sext.w	s6,a2
  acquire(&cons.lock);
    8000018c:	00011517          	auipc	a0,0x11
    80000190:	8a450513          	addi	a0,a0,-1884 # 80010a30 <cons>
    80000194:	00001097          	auipc	ra,0x1
    80000198:	aa4080e7          	jalr	-1372(ra) # 80000c38 <acquire>
  while(n > 0){
    // wait until interrupt handler has put some
    // input into cons.buffer.
    while(cons.r == cons.w){
    8000019c:	00011497          	auipc	s1,0x11
    800001a0:	89448493          	addi	s1,s1,-1900 # 80010a30 <cons>
      if(killed(myproc())){
        release(&cons.lock);
        return -1;
      }
      sleep(&cons.r, &cons.lock);
    800001a4:	00011917          	auipc	s2,0x11
    800001a8:	92490913          	addi	s2,s2,-1756 # 80010ac8 <cons+0x98>
  while(n > 0){
    800001ac:	0d305763          	blez	s3,8000027a <consoleread+0x10c>
    while(cons.r == cons.w){
    800001b0:	0984a783          	lw	a5,152(s1)
    800001b4:	09c4a703          	lw	a4,156(s1)
    800001b8:	0af71c63          	bne	a4,a5,80000270 <consoleread+0x102>
      if(killed(myproc())){
    800001bc:	00002097          	auipc	ra,0x2
    800001c0:	a78080e7          	jalr	-1416(ra) # 80001c34 <myproc>
    800001c4:	00002097          	auipc	ra,0x2
    800001c8:	4e8080e7          	jalr	1256(ra) # 800026ac <killed>
    800001cc:	e52d                	bnez	a0,80000236 <consoleread+0xc8>
      sleep(&cons.r, &cons.lock);
    800001ce:	85a6                	mv	a1,s1
    800001d0:	854a                	mv	a0,s2
    800001d2:	00002097          	auipc	ra,0x2
    800001d6:	1ec080e7          	jalr	492(ra) # 800023be <sleep>
    while(cons.r == cons.w){
    800001da:	0984a783          	lw	a5,152(s1)
    800001de:	09c4a703          	lw	a4,156(s1)
    800001e2:	fcf70de3          	beq	a4,a5,800001bc <consoleread+0x4e>
    800001e6:	ec5e                	sd	s7,24(sp)
    }

    c = cons.buf[cons.r++ % INPUT_BUF_SIZE];
    800001e8:	00011717          	auipc	a4,0x11
    800001ec:	84870713          	addi	a4,a4,-1976 # 80010a30 <cons>
    800001f0:	0017869b          	addiw	a3,a5,1
    800001f4:	08d72c23          	sw	a3,152(a4)
    800001f8:	07f7f693          	andi	a3,a5,127
    800001fc:	9736                	add	a4,a4,a3
    800001fe:	01874703          	lbu	a4,24(a4)
    80000202:	00070b9b          	sext.w	s7,a4

    if(c == C('D')){  // end-of-file
    80000206:	4691                	li	a3,4
    80000208:	04db8a63          	beq	s7,a3,8000025c <consoleread+0xee>
      }
      break;
    }

    // copy the input byte to the user-space buffer.
    cbuf = c;
    8000020c:	fae407a3          	sb	a4,-81(s0)
    if(either_copyout(user_dst, dst, &cbuf, 1) == -1)
    80000210:	4685                	li	a3,1
    80000212:	faf40613          	addi	a2,s0,-81
    80000216:	85d2                	mv	a1,s4
    80000218:	8556                	mv	a0,s5
    8000021a:	00002097          	auipc	ra,0x2
    8000021e:	604080e7          	jalr	1540(ra) # 8000281e <either_copyout>
    80000222:	57fd                	li	a5,-1
    80000224:	04f50a63          	beq	a0,a5,80000278 <consoleread+0x10a>
      break;

    dst++;
    80000228:	0a05                	addi	s4,s4,1
    --n;
    8000022a:	39fd                	addiw	s3,s3,-1

    if(c == '\n'){
    8000022c:	47a9                	li	a5,10
    8000022e:	06fb8163          	beq	s7,a5,80000290 <consoleread+0x122>
    80000232:	6be2                	ld	s7,24(sp)
    80000234:	bfa5                	j	800001ac <consoleread+0x3e>
        release(&cons.lock);
    80000236:	00010517          	auipc	a0,0x10
    8000023a:	7fa50513          	addi	a0,a0,2042 # 80010a30 <cons>
    8000023e:	00001097          	auipc	ra,0x1
    80000242:	aae080e7          	jalr	-1362(ra) # 80000cec <release>
        return -1;
    80000246:	557d                	li	a0,-1
    }
  }
  release(&cons.lock);

  return target - n;
}
    80000248:	60e6                	ld	ra,88(sp)
    8000024a:	6446                	ld	s0,80(sp)
    8000024c:	64a6                	ld	s1,72(sp)
    8000024e:	6906                	ld	s2,64(sp)
    80000250:	79e2                	ld	s3,56(sp)
    80000252:	7a42                	ld	s4,48(sp)
    80000254:	7aa2                	ld	s5,40(sp)
    80000256:	7b02                	ld	s6,32(sp)
    80000258:	6125                	addi	sp,sp,96
    8000025a:	8082                	ret
      if(n < target){
    8000025c:	0009871b          	sext.w	a4,s3
    80000260:	01677a63          	bgeu	a4,s6,80000274 <consoleread+0x106>
        cons.r--;
    80000264:	00011717          	auipc	a4,0x11
    80000268:	86f72223          	sw	a5,-1948(a4) # 80010ac8 <cons+0x98>
    8000026c:	6be2                	ld	s7,24(sp)
    8000026e:	a031                	j	8000027a <consoleread+0x10c>
    80000270:	ec5e                	sd	s7,24(sp)
    80000272:	bf9d                	j	800001e8 <consoleread+0x7a>
    80000274:	6be2                	ld	s7,24(sp)
    80000276:	a011                	j	8000027a <consoleread+0x10c>
    80000278:	6be2                	ld	s7,24(sp)
  release(&cons.lock);
    8000027a:	00010517          	auipc	a0,0x10
    8000027e:	7b650513          	addi	a0,a0,1974 # 80010a30 <cons>
    80000282:	00001097          	auipc	ra,0x1
    80000286:	a6a080e7          	jalr	-1430(ra) # 80000cec <release>
  return target - n;
    8000028a:	413b053b          	subw	a0,s6,s3
    8000028e:	bf6d                	j	80000248 <consoleread+0xda>
    80000290:	6be2                	ld	s7,24(sp)
    80000292:	b7e5                	j	8000027a <consoleread+0x10c>

0000000080000294 <consputc>:
{
    80000294:	1141                	addi	sp,sp,-16
    80000296:	e406                	sd	ra,8(sp)
    80000298:	e022                	sd	s0,0(sp)
    8000029a:	0800                	addi	s0,sp,16
  if(c == BACKSPACE){
    8000029c:	10000793          	li	a5,256
    800002a0:	00f50a63          	beq	a0,a5,800002b4 <consputc+0x20>
    uartputc_sync(c);
    800002a4:	00000097          	auipc	ra,0x0
    800002a8:	59c080e7          	jalr	1436(ra) # 80000840 <uartputc_sync>
}
    800002ac:	60a2                	ld	ra,8(sp)
    800002ae:	6402                	ld	s0,0(sp)
    800002b0:	0141                	addi	sp,sp,16
    800002b2:	8082                	ret
    uartputc_sync('\b'); uartputc_sync(' '); uartputc_sync('\b');
    800002b4:	4521                	li	a0,8
    800002b6:	00000097          	auipc	ra,0x0
    800002ba:	58a080e7          	jalr	1418(ra) # 80000840 <uartputc_sync>
    800002be:	02000513          	li	a0,32
    800002c2:	00000097          	auipc	ra,0x0
    800002c6:	57e080e7          	jalr	1406(ra) # 80000840 <uartputc_sync>
    800002ca:	4521                	li	a0,8
    800002cc:	00000097          	auipc	ra,0x0
    800002d0:	574080e7          	jalr	1396(ra) # 80000840 <uartputc_sync>
    800002d4:	bfe1                	j	800002ac <consputc+0x18>

00000000800002d6 <consoleintr>:
// do erase/kill processing, append to cons.buf,
// wake up consoleread() if a whole line has arrived.
//
void
consoleintr(int c)
{
    800002d6:	1101                	addi	sp,sp,-32
    800002d8:	ec06                	sd	ra,24(sp)
    800002da:	e822                	sd	s0,16(sp)
    800002dc:	e426                	sd	s1,8(sp)
    800002de:	1000                	addi	s0,sp,32
    800002e0:	84aa                	mv	s1,a0
  acquire(&cons.lock);
    800002e2:	00010517          	auipc	a0,0x10
    800002e6:	74e50513          	addi	a0,a0,1870 # 80010a30 <cons>
    800002ea:	00001097          	auipc	ra,0x1
    800002ee:	94e080e7          	jalr	-1714(ra) # 80000c38 <acquire>

  switch(c){
    800002f2:	47d5                	li	a5,21
    800002f4:	0af48563          	beq	s1,a5,8000039e <consoleintr+0xc8>
    800002f8:	0297c963          	blt	a5,s1,8000032a <consoleintr+0x54>
    800002fc:	47a1                	li	a5,8
    800002fe:	0ef48c63          	beq	s1,a5,800003f6 <consoleintr+0x120>
    80000302:	47c1                	li	a5,16
    80000304:	10f49f63          	bne	s1,a5,80000422 <consoleintr+0x14c>
  case C('P'):  // Print process list.
    procdump();
    80000308:	00002097          	auipc	ra,0x2
    8000030c:	5c6080e7          	jalr	1478(ra) # 800028ce <procdump>
      }
    }
    break;
  }
  
  release(&cons.lock);
    80000310:	00010517          	auipc	a0,0x10
    80000314:	72050513          	addi	a0,a0,1824 # 80010a30 <cons>
    80000318:	00001097          	auipc	ra,0x1
    8000031c:	9d4080e7          	jalr	-1580(ra) # 80000cec <release>
}
    80000320:	60e2                	ld	ra,24(sp)
    80000322:	6442                	ld	s0,16(sp)
    80000324:	64a2                	ld	s1,8(sp)
    80000326:	6105                	addi	sp,sp,32
    80000328:	8082                	ret
  switch(c){
    8000032a:	07f00793          	li	a5,127
    8000032e:	0cf48463          	beq	s1,a5,800003f6 <consoleintr+0x120>
    if(c != 0 && cons.e-cons.r < INPUT_BUF_SIZE){
    80000332:	00010717          	auipc	a4,0x10
    80000336:	6fe70713          	addi	a4,a4,1790 # 80010a30 <cons>
    8000033a:	0a072783          	lw	a5,160(a4)
    8000033e:	09872703          	lw	a4,152(a4)
    80000342:	9f99                	subw	a5,a5,a4
    80000344:	07f00713          	li	a4,127
    80000348:	fcf764e3          	bltu	a4,a5,80000310 <consoleintr+0x3a>
      c = (c == '\r') ? '\n' : c;
    8000034c:	47b5                	li	a5,13
    8000034e:	0cf48d63          	beq	s1,a5,80000428 <consoleintr+0x152>
      consputc(c);
    80000352:	8526                	mv	a0,s1
    80000354:	00000097          	auipc	ra,0x0
    80000358:	f40080e7          	jalr	-192(ra) # 80000294 <consputc>
      cons.buf[cons.e++ % INPUT_BUF_SIZE] = c;
    8000035c:	00010797          	auipc	a5,0x10
    80000360:	6d478793          	addi	a5,a5,1748 # 80010a30 <cons>
    80000364:	0a07a683          	lw	a3,160(a5)
    80000368:	0016871b          	addiw	a4,a3,1
    8000036c:	0007061b          	sext.w	a2,a4
    80000370:	0ae7a023          	sw	a4,160(a5)
    80000374:	07f6f693          	andi	a3,a3,127
    80000378:	97b6                	add	a5,a5,a3
    8000037a:	00978c23          	sb	s1,24(a5)
      if(c == '\n' || c == C('D') || cons.e-cons.r == INPUT_BUF_SIZE){
    8000037e:	47a9                	li	a5,10
    80000380:	0cf48b63          	beq	s1,a5,80000456 <consoleintr+0x180>
    80000384:	4791                	li	a5,4
    80000386:	0cf48863          	beq	s1,a5,80000456 <consoleintr+0x180>
    8000038a:	00010797          	auipc	a5,0x10
    8000038e:	73e7a783          	lw	a5,1854(a5) # 80010ac8 <cons+0x98>
    80000392:	9f1d                	subw	a4,a4,a5
    80000394:	08000793          	li	a5,128
    80000398:	f6f71ce3          	bne	a4,a5,80000310 <consoleintr+0x3a>
    8000039c:	a86d                	j	80000456 <consoleintr+0x180>
    8000039e:	e04a                	sd	s2,0(sp)
    while(cons.e != cons.w &&
    800003a0:	00010717          	auipc	a4,0x10
    800003a4:	69070713          	addi	a4,a4,1680 # 80010a30 <cons>
    800003a8:	0a072783          	lw	a5,160(a4)
    800003ac:	09c72703          	lw	a4,156(a4)
          cons.buf[(cons.e-1) % INPUT_BUF_SIZE] != '\n'){
    800003b0:	00010497          	auipc	s1,0x10
    800003b4:	68048493          	addi	s1,s1,1664 # 80010a30 <cons>
    while(cons.e != cons.w &&
    800003b8:	4929                	li	s2,10
    800003ba:	02f70a63          	beq	a4,a5,800003ee <consoleintr+0x118>
          cons.buf[(cons.e-1) % INPUT_BUF_SIZE] != '\n'){
    800003be:	37fd                	addiw	a5,a5,-1
    800003c0:	07f7f713          	andi	a4,a5,127
    800003c4:	9726                	add	a4,a4,s1
    while(cons.e != cons.w &&
    800003c6:	01874703          	lbu	a4,24(a4)
    800003ca:	03270463          	beq	a4,s2,800003f2 <consoleintr+0x11c>
      cons.e--;
    800003ce:	0af4a023          	sw	a5,160(s1)
      consputc(BACKSPACE);
    800003d2:	10000513          	li	a0,256
    800003d6:	00000097          	auipc	ra,0x0
    800003da:	ebe080e7          	jalr	-322(ra) # 80000294 <consputc>
    while(cons.e != cons.w &&
    800003de:	0a04a783          	lw	a5,160(s1)
    800003e2:	09c4a703          	lw	a4,156(s1)
    800003e6:	fcf71ce3          	bne	a4,a5,800003be <consoleintr+0xe8>
    800003ea:	6902                	ld	s2,0(sp)
    800003ec:	b715                	j	80000310 <consoleintr+0x3a>
    800003ee:	6902                	ld	s2,0(sp)
    800003f0:	b705                	j	80000310 <consoleintr+0x3a>
    800003f2:	6902                	ld	s2,0(sp)
    800003f4:	bf31                	j	80000310 <consoleintr+0x3a>
    if(cons.e != cons.w){
    800003f6:	00010717          	auipc	a4,0x10
    800003fa:	63a70713          	addi	a4,a4,1594 # 80010a30 <cons>
    800003fe:	0a072783          	lw	a5,160(a4)
    80000402:	09c72703          	lw	a4,156(a4)
    80000406:	f0f705e3          	beq	a4,a5,80000310 <consoleintr+0x3a>
      cons.e--;
    8000040a:	37fd                	addiw	a5,a5,-1
    8000040c:	00010717          	auipc	a4,0x10
    80000410:	6cf72223          	sw	a5,1732(a4) # 80010ad0 <cons+0xa0>
      consputc(BACKSPACE);
    80000414:	10000513          	li	a0,256
    80000418:	00000097          	auipc	ra,0x0
    8000041c:	e7c080e7          	jalr	-388(ra) # 80000294 <consputc>
    80000420:	bdc5                	j	80000310 <consoleintr+0x3a>
    if(c != 0 && cons.e-cons.r < INPUT_BUF_SIZE){
    80000422:	ee0487e3          	beqz	s1,80000310 <consoleintr+0x3a>
    80000426:	b731                	j	80000332 <consoleintr+0x5c>
      consputc(c);
    80000428:	4529                	li	a0,10
    8000042a:	00000097          	auipc	ra,0x0
    8000042e:	e6a080e7          	jalr	-406(ra) # 80000294 <consputc>
      cons.buf[cons.e++ % INPUT_BUF_SIZE] = c;
    80000432:	00010797          	auipc	a5,0x10
    80000436:	5fe78793          	addi	a5,a5,1534 # 80010a30 <cons>
    8000043a:	0a07a703          	lw	a4,160(a5)
    8000043e:	0017069b          	addiw	a3,a4,1
    80000442:	0006861b          	sext.w	a2,a3
    80000446:	0ad7a023          	sw	a3,160(a5)
    8000044a:	07f77713          	andi	a4,a4,127
    8000044e:	97ba                	add	a5,a5,a4
    80000450:	4729                	li	a4,10
    80000452:	00e78c23          	sb	a4,24(a5)
        cons.w = cons.e;
    80000456:	00010797          	auipc	a5,0x10
    8000045a:	66c7ab23          	sw	a2,1654(a5) # 80010acc <cons+0x9c>
        wakeup(&cons.r);
    8000045e:	00010517          	auipc	a0,0x10
    80000462:	66a50513          	addi	a0,a0,1642 # 80010ac8 <cons+0x98>
    80000466:	00002097          	auipc	ra,0x2
    8000046a:	fc8080e7          	jalr	-56(ra) # 8000242e <wakeup>
    8000046e:	b54d                	j	80000310 <consoleintr+0x3a>

0000000080000470 <consoleinit>:

void
consoleinit(void)
{
    80000470:	1141                	addi	sp,sp,-16
    80000472:	e406                	sd	ra,8(sp)
    80000474:	e022                	sd	s0,0(sp)
    80000476:	0800                	addi	s0,sp,16
  initlock(&cons.lock, "cons");
    80000478:	00008597          	auipc	a1,0x8
    8000047c:	b8858593          	addi	a1,a1,-1144 # 80008000 <etext>
    80000480:	00010517          	auipc	a0,0x10
    80000484:	5b050513          	addi	a0,a0,1456 # 80010a30 <cons>
    80000488:	00000097          	auipc	ra,0x0
    8000048c:	720080e7          	jalr	1824(ra) # 80000ba8 <initlock>

  uartinit();
    80000490:	00000097          	auipc	ra,0x0
    80000494:	354080e7          	jalr	852(ra) # 800007e4 <uartinit>

  // connect read and write system calls
  // to consoleread and consolewrite.
  devsw[CONSOLE].read = consoleread;
    80000498:	00029797          	auipc	a5,0x29
    8000049c:	73078793          	addi	a5,a5,1840 # 80029bc8 <devsw>
    800004a0:	00000717          	auipc	a4,0x0
    800004a4:	cce70713          	addi	a4,a4,-818 # 8000016e <consoleread>
    800004a8:	eb98                	sd	a4,16(a5)
  devsw[CONSOLE].write = consolewrite;
    800004aa:	00000717          	auipc	a4,0x0
    800004ae:	c5670713          	addi	a4,a4,-938 # 80000100 <consolewrite>
    800004b2:	ef98                	sd	a4,24(a5)
}
    800004b4:	60a2                	ld	ra,8(sp)
    800004b6:	6402                	ld	s0,0(sp)
    800004b8:	0141                	addi	sp,sp,16
    800004ba:	8082                	ret

00000000800004bc <printint>:

static char digits[] = "0123456789abcdef";

static void
printint(int xx, int base, int sign)
{
    800004bc:	7179                	addi	sp,sp,-48
    800004be:	f406                	sd	ra,40(sp)
    800004c0:	f022                	sd	s0,32(sp)
    800004c2:	1800                	addi	s0,sp,48
  char buf[16];
  int i;
  uint x;

  if(sign && (sign = xx < 0))
    800004c4:	c219                	beqz	a2,800004ca <printint+0xe>
    800004c6:	08054963          	bltz	a0,80000558 <printint+0x9c>
    x = -xx;
  else
    x = xx;
    800004ca:	2501                	sext.w	a0,a0
    800004cc:	4881                	li	a7,0
    800004ce:	fd040693          	addi	a3,s0,-48

  i = 0;
    800004d2:	4701                	li	a4,0
  do {
    buf[i++] = digits[x % base];
    800004d4:	2581                	sext.w	a1,a1
    800004d6:	00008617          	auipc	a2,0x8
    800004da:	25260613          	addi	a2,a2,594 # 80008728 <digits>
    800004de:	883a                	mv	a6,a4
    800004e0:	2705                	addiw	a4,a4,1
    800004e2:	02b577bb          	remuw	a5,a0,a1
    800004e6:	1782                	slli	a5,a5,0x20
    800004e8:	9381                	srli	a5,a5,0x20
    800004ea:	97b2                	add	a5,a5,a2
    800004ec:	0007c783          	lbu	a5,0(a5)
    800004f0:	00f68023          	sb	a5,0(a3)
  } while((x /= base) != 0);
    800004f4:	0005079b          	sext.w	a5,a0
    800004f8:	02b5553b          	divuw	a0,a0,a1
    800004fc:	0685                	addi	a3,a3,1
    800004fe:	feb7f0e3          	bgeu	a5,a1,800004de <printint+0x22>

  if(sign)
    80000502:	00088c63          	beqz	a7,8000051a <printint+0x5e>
    buf[i++] = '-';
    80000506:	fe070793          	addi	a5,a4,-32
    8000050a:	00878733          	add	a4,a5,s0
    8000050e:	02d00793          	li	a5,45
    80000512:	fef70823          	sb	a5,-16(a4)
    80000516:	0028071b          	addiw	a4,a6,2

  while(--i >= 0)
    8000051a:	02e05b63          	blez	a4,80000550 <printint+0x94>
    8000051e:	ec26                	sd	s1,24(sp)
    80000520:	e84a                	sd	s2,16(sp)
    80000522:	fd040793          	addi	a5,s0,-48
    80000526:	00e784b3          	add	s1,a5,a4
    8000052a:	fff78913          	addi	s2,a5,-1
    8000052e:	993a                	add	s2,s2,a4
    80000530:	377d                	addiw	a4,a4,-1
    80000532:	1702                	slli	a4,a4,0x20
    80000534:	9301                	srli	a4,a4,0x20
    80000536:	40e90933          	sub	s2,s2,a4
    consputc(buf[i]);
    8000053a:	fff4c503          	lbu	a0,-1(s1)
    8000053e:	00000097          	auipc	ra,0x0
    80000542:	d56080e7          	jalr	-682(ra) # 80000294 <consputc>
  while(--i >= 0)
    80000546:	14fd                	addi	s1,s1,-1
    80000548:	ff2499e3          	bne	s1,s2,8000053a <printint+0x7e>
    8000054c:	64e2                	ld	s1,24(sp)
    8000054e:	6942                	ld	s2,16(sp)
}
    80000550:	70a2                	ld	ra,40(sp)
    80000552:	7402                	ld	s0,32(sp)
    80000554:	6145                	addi	sp,sp,48
    80000556:	8082                	ret
    x = -xx;
    80000558:	40a0053b          	negw	a0,a0
  if(sign && (sign = xx < 0))
    8000055c:	4885                	li	a7,1
    x = -xx;
    8000055e:	bf85                	j	800004ce <printint+0x12>

0000000080000560 <panic>:
    release(&pr.lock);
}

void
panic(char *s)
{
    80000560:	1101                	addi	sp,sp,-32
    80000562:	ec06                	sd	ra,24(sp)
    80000564:	e822                	sd	s0,16(sp)
    80000566:	e426                	sd	s1,8(sp)
    80000568:	1000                	addi	s0,sp,32
    8000056a:	84aa                	mv	s1,a0
  pr.locking = 0;
    8000056c:	00010797          	auipc	a5,0x10
    80000570:	5807a223          	sw	zero,1412(a5) # 80010af0 <pr+0x18>
  printf("panic: ");
    80000574:	00008517          	auipc	a0,0x8
    80000578:	a9450513          	addi	a0,a0,-1388 # 80008008 <etext+0x8>
    8000057c:	00000097          	auipc	ra,0x0
    80000580:	02e080e7          	jalr	46(ra) # 800005aa <printf>
  printf(s);
    80000584:	8526                	mv	a0,s1
    80000586:	00000097          	auipc	ra,0x0
    8000058a:	024080e7          	jalr	36(ra) # 800005aa <printf>
  printf("\n");
    8000058e:	00008517          	auipc	a0,0x8
    80000592:	a8250513          	addi	a0,a0,-1406 # 80008010 <etext+0x10>
    80000596:	00000097          	auipc	ra,0x0
    8000059a:	014080e7          	jalr	20(ra) # 800005aa <printf>
  panicked = 1; // freeze uart output from other CPUs
    8000059e:	4785                	li	a5,1
    800005a0:	00008717          	auipc	a4,0x8
    800005a4:	30f72823          	sw	a5,784(a4) # 800088b0 <panicked>
  for(;;)
    800005a8:	a001                	j	800005a8 <panic+0x48>

00000000800005aa <printf>:
{
    800005aa:	7131                	addi	sp,sp,-192
    800005ac:	fc86                	sd	ra,120(sp)
    800005ae:	f8a2                	sd	s0,112(sp)
    800005b0:	e8d2                	sd	s4,80(sp)
    800005b2:	f06a                	sd	s10,32(sp)
    800005b4:	0100                	addi	s0,sp,128
    800005b6:	8a2a                	mv	s4,a0
    800005b8:	e40c                	sd	a1,8(s0)
    800005ba:	e810                	sd	a2,16(s0)
    800005bc:	ec14                	sd	a3,24(s0)
    800005be:	f018                	sd	a4,32(s0)
    800005c0:	f41c                	sd	a5,40(s0)
    800005c2:	03043823          	sd	a6,48(s0)
    800005c6:	03143c23          	sd	a7,56(s0)
  locking = pr.locking;
    800005ca:	00010d17          	auipc	s10,0x10
    800005ce:	526d2d03          	lw	s10,1318(s10) # 80010af0 <pr+0x18>
  if(locking)
    800005d2:	040d1463          	bnez	s10,8000061a <printf+0x70>
  if (fmt == 0)
    800005d6:	040a0b63          	beqz	s4,8000062c <printf+0x82>
  va_start(ap, fmt);
    800005da:	00840793          	addi	a5,s0,8
    800005de:	f8f43423          	sd	a5,-120(s0)
  for(i = 0; (c = fmt[i] & 0xff) != 0; i++){
    800005e2:	000a4503          	lbu	a0,0(s4)
    800005e6:	18050b63          	beqz	a0,8000077c <printf+0x1d2>
    800005ea:	f4a6                	sd	s1,104(sp)
    800005ec:	f0ca                	sd	s2,96(sp)
    800005ee:	ecce                	sd	s3,88(sp)
    800005f0:	e4d6                	sd	s5,72(sp)
    800005f2:	e0da                	sd	s6,64(sp)
    800005f4:	fc5e                	sd	s7,56(sp)
    800005f6:	f862                	sd	s8,48(sp)
    800005f8:	f466                	sd	s9,40(sp)
    800005fa:	ec6e                	sd	s11,24(sp)
    800005fc:	4981                	li	s3,0
    if(c != '%'){
    800005fe:	02500b13          	li	s6,37
    switch(c){
    80000602:	07000b93          	li	s7,112
  consputc('x');
    80000606:	4cc1                	li	s9,16
    consputc(digits[x >> (sizeof(uint64) * 8 - 4)]);
    80000608:	00008a97          	auipc	s5,0x8
    8000060c:	120a8a93          	addi	s5,s5,288 # 80008728 <digits>
    switch(c){
    80000610:	07300c13          	li	s8,115
    80000614:	06400d93          	li	s11,100
    80000618:	a0b1                	j	80000664 <printf+0xba>
    acquire(&pr.lock);
    8000061a:	00010517          	auipc	a0,0x10
    8000061e:	4be50513          	addi	a0,a0,1214 # 80010ad8 <pr>
    80000622:	00000097          	auipc	ra,0x0
    80000626:	616080e7          	jalr	1558(ra) # 80000c38 <acquire>
    8000062a:	b775                	j	800005d6 <printf+0x2c>
    8000062c:	f4a6                	sd	s1,104(sp)
    8000062e:	f0ca                	sd	s2,96(sp)
    80000630:	ecce                	sd	s3,88(sp)
    80000632:	e4d6                	sd	s5,72(sp)
    80000634:	e0da                	sd	s6,64(sp)
    80000636:	fc5e                	sd	s7,56(sp)
    80000638:	f862                	sd	s8,48(sp)
    8000063a:	f466                	sd	s9,40(sp)
    8000063c:	ec6e                	sd	s11,24(sp)
    panic("null fmt");
    8000063e:	00008517          	auipc	a0,0x8
    80000642:	9e250513          	addi	a0,a0,-1566 # 80008020 <etext+0x20>
    80000646:	00000097          	auipc	ra,0x0
    8000064a:	f1a080e7          	jalr	-230(ra) # 80000560 <panic>
      consputc(c);
    8000064e:	00000097          	auipc	ra,0x0
    80000652:	c46080e7          	jalr	-954(ra) # 80000294 <consputc>
  for(i = 0; (c = fmt[i] & 0xff) != 0; i++){
    80000656:	2985                	addiw	s3,s3,1
    80000658:	013a07b3          	add	a5,s4,s3
    8000065c:	0007c503          	lbu	a0,0(a5)
    80000660:	10050563          	beqz	a0,8000076a <printf+0x1c0>
    if(c != '%'){
    80000664:	ff6515e3          	bne	a0,s6,8000064e <printf+0xa4>
    c = fmt[++i] & 0xff;
    80000668:	2985                	addiw	s3,s3,1
    8000066a:	013a07b3          	add	a5,s4,s3
    8000066e:	0007c783          	lbu	a5,0(a5)
    80000672:	0007849b          	sext.w	s1,a5
    if(c == 0)
    80000676:	10078b63          	beqz	a5,8000078c <printf+0x1e2>
    switch(c){
    8000067a:	05778a63          	beq	a5,s7,800006ce <printf+0x124>
    8000067e:	02fbf663          	bgeu	s7,a5,800006aa <printf+0x100>
    80000682:	09878863          	beq	a5,s8,80000712 <printf+0x168>
    80000686:	07800713          	li	a4,120
    8000068a:	0ce79563          	bne	a5,a4,80000754 <printf+0x1aa>
      printint(va_arg(ap, int), 16, 1);
    8000068e:	f8843783          	ld	a5,-120(s0)
    80000692:	00878713          	addi	a4,a5,8
    80000696:	f8e43423          	sd	a4,-120(s0)
    8000069a:	4605                	li	a2,1
    8000069c:	85e6                	mv	a1,s9
    8000069e:	4388                	lw	a0,0(a5)
    800006a0:	00000097          	auipc	ra,0x0
    800006a4:	e1c080e7          	jalr	-484(ra) # 800004bc <printint>
      break;
    800006a8:	b77d                	j	80000656 <printf+0xac>
    switch(c){
    800006aa:	09678f63          	beq	a5,s6,80000748 <printf+0x19e>
    800006ae:	0bb79363          	bne	a5,s11,80000754 <printf+0x1aa>
      printint(va_arg(ap, int), 10, 1);
    800006b2:	f8843783          	ld	a5,-120(s0)
    800006b6:	00878713          	addi	a4,a5,8
    800006ba:	f8e43423          	sd	a4,-120(s0)
    800006be:	4605                	li	a2,1
    800006c0:	45a9                	li	a1,10
    800006c2:	4388                	lw	a0,0(a5)
    800006c4:	00000097          	auipc	ra,0x0
    800006c8:	df8080e7          	jalr	-520(ra) # 800004bc <printint>
      break;
    800006cc:	b769                	j	80000656 <printf+0xac>
      printptr(va_arg(ap, uint64));
    800006ce:	f8843783          	ld	a5,-120(s0)
    800006d2:	00878713          	addi	a4,a5,8
    800006d6:	f8e43423          	sd	a4,-120(s0)
    800006da:	0007b903          	ld	s2,0(a5)
  consputc('0');
    800006de:	03000513          	li	a0,48
    800006e2:	00000097          	auipc	ra,0x0
    800006e6:	bb2080e7          	jalr	-1102(ra) # 80000294 <consputc>
  consputc('x');
    800006ea:	07800513          	li	a0,120
    800006ee:	00000097          	auipc	ra,0x0
    800006f2:	ba6080e7          	jalr	-1114(ra) # 80000294 <consputc>
    800006f6:	84e6                	mv	s1,s9
    consputc(digits[x >> (sizeof(uint64) * 8 - 4)]);
    800006f8:	03c95793          	srli	a5,s2,0x3c
    800006fc:	97d6                	add	a5,a5,s5
    800006fe:	0007c503          	lbu	a0,0(a5)
    80000702:	00000097          	auipc	ra,0x0
    80000706:	b92080e7          	jalr	-1134(ra) # 80000294 <consputc>
  for (i = 0; i < (sizeof(uint64) * 2); i++, x <<= 4)
    8000070a:	0912                	slli	s2,s2,0x4
    8000070c:	34fd                	addiw	s1,s1,-1
    8000070e:	f4ed                	bnez	s1,800006f8 <printf+0x14e>
    80000710:	b799                	j	80000656 <printf+0xac>
      if((s = va_arg(ap, char*)) == 0)
    80000712:	f8843783          	ld	a5,-120(s0)
    80000716:	00878713          	addi	a4,a5,8
    8000071a:	f8e43423          	sd	a4,-120(s0)
    8000071e:	6384                	ld	s1,0(a5)
    80000720:	cc89                	beqz	s1,8000073a <printf+0x190>
      for(; *s; s++)
    80000722:	0004c503          	lbu	a0,0(s1)
    80000726:	d905                	beqz	a0,80000656 <printf+0xac>
        consputc(*s);
    80000728:	00000097          	auipc	ra,0x0
    8000072c:	b6c080e7          	jalr	-1172(ra) # 80000294 <consputc>
      for(; *s; s++)
    80000730:	0485                	addi	s1,s1,1
    80000732:	0004c503          	lbu	a0,0(s1)
    80000736:	f96d                	bnez	a0,80000728 <printf+0x17e>
    80000738:	bf39                	j	80000656 <printf+0xac>
        s = "(null)";
    8000073a:	00008497          	auipc	s1,0x8
    8000073e:	8de48493          	addi	s1,s1,-1826 # 80008018 <etext+0x18>
      for(; *s; s++)
    80000742:	02800513          	li	a0,40
    80000746:	b7cd                	j	80000728 <printf+0x17e>
      consputc('%');
    80000748:	855a                	mv	a0,s6
    8000074a:	00000097          	auipc	ra,0x0
    8000074e:	b4a080e7          	jalr	-1206(ra) # 80000294 <consputc>
      break;
    80000752:	b711                	j	80000656 <printf+0xac>
      consputc('%');
    80000754:	855a                	mv	a0,s6
    80000756:	00000097          	auipc	ra,0x0
    8000075a:	b3e080e7          	jalr	-1218(ra) # 80000294 <consputc>
      consputc(c);
    8000075e:	8526                	mv	a0,s1
    80000760:	00000097          	auipc	ra,0x0
    80000764:	b34080e7          	jalr	-1228(ra) # 80000294 <consputc>
      break;
    80000768:	b5fd                	j	80000656 <printf+0xac>
    8000076a:	74a6                	ld	s1,104(sp)
    8000076c:	7906                	ld	s2,96(sp)
    8000076e:	69e6                	ld	s3,88(sp)
    80000770:	6aa6                	ld	s5,72(sp)
    80000772:	6b06                	ld	s6,64(sp)
    80000774:	7be2                	ld	s7,56(sp)
    80000776:	7c42                	ld	s8,48(sp)
    80000778:	7ca2                	ld	s9,40(sp)
    8000077a:	6de2                	ld	s11,24(sp)
  if(locking)
    8000077c:	020d1263          	bnez	s10,800007a0 <printf+0x1f6>
}
    80000780:	70e6                	ld	ra,120(sp)
    80000782:	7446                	ld	s0,112(sp)
    80000784:	6a46                	ld	s4,80(sp)
    80000786:	7d02                	ld	s10,32(sp)
    80000788:	6129                	addi	sp,sp,192
    8000078a:	8082                	ret
    8000078c:	74a6                	ld	s1,104(sp)
    8000078e:	7906                	ld	s2,96(sp)
    80000790:	69e6                	ld	s3,88(sp)
    80000792:	6aa6                	ld	s5,72(sp)
    80000794:	6b06                	ld	s6,64(sp)
    80000796:	7be2                	ld	s7,56(sp)
    80000798:	7c42                	ld	s8,48(sp)
    8000079a:	7ca2                	ld	s9,40(sp)
    8000079c:	6de2                	ld	s11,24(sp)
    8000079e:	bff9                	j	8000077c <printf+0x1d2>
    release(&pr.lock);
    800007a0:	00010517          	auipc	a0,0x10
    800007a4:	33850513          	addi	a0,a0,824 # 80010ad8 <pr>
    800007a8:	00000097          	auipc	ra,0x0
    800007ac:	544080e7          	jalr	1348(ra) # 80000cec <release>
}
    800007b0:	bfc1                	j	80000780 <printf+0x1d6>

00000000800007b2 <printfinit>:
    ;
}

void
printfinit(void)
{
    800007b2:	1101                	addi	sp,sp,-32
    800007b4:	ec06                	sd	ra,24(sp)
    800007b6:	e822                	sd	s0,16(sp)
    800007b8:	e426                	sd	s1,8(sp)
    800007ba:	1000                	addi	s0,sp,32
  initlock(&pr.lock, "pr");
    800007bc:	00010497          	auipc	s1,0x10
    800007c0:	31c48493          	addi	s1,s1,796 # 80010ad8 <pr>
    800007c4:	00008597          	auipc	a1,0x8
    800007c8:	86c58593          	addi	a1,a1,-1940 # 80008030 <etext+0x30>
    800007cc:	8526                	mv	a0,s1
    800007ce:	00000097          	auipc	ra,0x0
    800007d2:	3da080e7          	jalr	986(ra) # 80000ba8 <initlock>
  pr.locking = 1;
    800007d6:	4785                	li	a5,1
    800007d8:	cc9c                	sw	a5,24(s1)
}
    800007da:	60e2                	ld	ra,24(sp)
    800007dc:	6442                	ld	s0,16(sp)
    800007de:	64a2                	ld	s1,8(sp)
    800007e0:	6105                	addi	sp,sp,32
    800007e2:	8082                	ret

00000000800007e4 <uartinit>:

void uartstart();

void
uartinit(void)
{
    800007e4:	1141                	addi	sp,sp,-16
    800007e6:	e406                	sd	ra,8(sp)
    800007e8:	e022                	sd	s0,0(sp)
    800007ea:	0800                	addi	s0,sp,16
  // disable interrupts.
  WriteReg(IER, 0x00);
    800007ec:	100007b7          	lui	a5,0x10000
    800007f0:	000780a3          	sb	zero,1(a5) # 10000001 <_entry-0x6fffffff>

  // special mode to set baud rate.
  WriteReg(LCR, LCR_BAUD_LATCH);
    800007f4:	10000737          	lui	a4,0x10000
    800007f8:	f8000693          	li	a3,-128
    800007fc:	00d701a3          	sb	a3,3(a4) # 10000003 <_entry-0x6ffffffd>

  // LSB for baud rate of 38.4K.
  WriteReg(0, 0x03);
    80000800:	468d                	li	a3,3
    80000802:	10000637          	lui	a2,0x10000
    80000806:	00d60023          	sb	a3,0(a2) # 10000000 <_entry-0x70000000>

  // MSB for baud rate of 38.4K.
  WriteReg(1, 0x00);
    8000080a:	000780a3          	sb	zero,1(a5)

  // leave set-baud mode,
  // and set word length to 8 bits, no parity.
  WriteReg(LCR, LCR_EIGHT_BITS);
    8000080e:	00d701a3          	sb	a3,3(a4)

  // reset and enable FIFOs.
  WriteReg(FCR, FCR_FIFO_ENABLE | FCR_FIFO_CLEAR);
    80000812:	10000737          	lui	a4,0x10000
    80000816:	461d                	li	a2,7
    80000818:	00c70123          	sb	a2,2(a4) # 10000002 <_entry-0x6ffffffe>

  // enable transmit and receive interrupts.
  WriteReg(IER, IER_TX_ENABLE | IER_RX_ENABLE);
    8000081c:	00d780a3          	sb	a3,1(a5)

  initlock(&uart_tx_lock, "uart");
    80000820:	00008597          	auipc	a1,0x8
    80000824:	81858593          	addi	a1,a1,-2024 # 80008038 <etext+0x38>
    80000828:	00010517          	auipc	a0,0x10
    8000082c:	2d050513          	addi	a0,a0,720 # 80010af8 <uart_tx_lock>
    80000830:	00000097          	auipc	ra,0x0
    80000834:	378080e7          	jalr	888(ra) # 80000ba8 <initlock>
}
    80000838:	60a2                	ld	ra,8(sp)
    8000083a:	6402                	ld	s0,0(sp)
    8000083c:	0141                	addi	sp,sp,16
    8000083e:	8082                	ret

0000000080000840 <uartputc_sync>:
// use interrupts, for use by kernel printf() and
// to echo characters. it spins waiting for the uart's
// output register to be empty.
void
uartputc_sync(int c)
{
    80000840:	1101                	addi	sp,sp,-32
    80000842:	ec06                	sd	ra,24(sp)
    80000844:	e822                	sd	s0,16(sp)
    80000846:	e426                	sd	s1,8(sp)
    80000848:	1000                	addi	s0,sp,32
    8000084a:	84aa                	mv	s1,a0
  push_off();
    8000084c:	00000097          	auipc	ra,0x0
    80000850:	3a0080e7          	jalr	928(ra) # 80000bec <push_off>

  if(panicked){
    80000854:	00008797          	auipc	a5,0x8
    80000858:	05c7a783          	lw	a5,92(a5) # 800088b0 <panicked>
    8000085c:	eb85                	bnez	a5,8000088c <uartputc_sync+0x4c>
    for(;;)
      ;
  }

  // wait for Transmit Holding Empty to be set in LSR.
  while((ReadReg(LSR) & LSR_TX_IDLE) == 0)
    8000085e:	10000737          	lui	a4,0x10000
    80000862:	0715                	addi	a4,a4,5 # 10000005 <_entry-0x6ffffffb>
    80000864:	00074783          	lbu	a5,0(a4)
    80000868:	0207f793          	andi	a5,a5,32
    8000086c:	dfe5                	beqz	a5,80000864 <uartputc_sync+0x24>
    ;
  WriteReg(THR, c);
    8000086e:	0ff4f513          	zext.b	a0,s1
    80000872:	100007b7          	lui	a5,0x10000
    80000876:	00a78023          	sb	a0,0(a5) # 10000000 <_entry-0x70000000>

  pop_off();
    8000087a:	00000097          	auipc	ra,0x0
    8000087e:	412080e7          	jalr	1042(ra) # 80000c8c <pop_off>
}
    80000882:	60e2                	ld	ra,24(sp)
    80000884:	6442                	ld	s0,16(sp)
    80000886:	64a2                	ld	s1,8(sp)
    80000888:	6105                	addi	sp,sp,32
    8000088a:	8082                	ret
    for(;;)
    8000088c:	a001                	j	8000088c <uartputc_sync+0x4c>

000000008000088e <uartstart>:
// called from both the top- and bottom-half.
void
uartstart()
{
  while(1){
    if(uart_tx_w == uart_tx_r){
    8000088e:	00008797          	auipc	a5,0x8
    80000892:	02a7b783          	ld	a5,42(a5) # 800088b8 <uart_tx_r>
    80000896:	00008717          	auipc	a4,0x8
    8000089a:	02a73703          	ld	a4,42(a4) # 800088c0 <uart_tx_w>
    8000089e:	06f70f63          	beq	a4,a5,8000091c <uartstart+0x8e>
{
    800008a2:	7139                	addi	sp,sp,-64
    800008a4:	fc06                	sd	ra,56(sp)
    800008a6:	f822                	sd	s0,48(sp)
    800008a8:	f426                	sd	s1,40(sp)
    800008aa:	f04a                	sd	s2,32(sp)
    800008ac:	ec4e                	sd	s3,24(sp)
    800008ae:	e852                	sd	s4,16(sp)
    800008b0:	e456                	sd	s5,8(sp)
    800008b2:	e05a                	sd	s6,0(sp)
    800008b4:	0080                	addi	s0,sp,64
      // transmit buffer is empty.
      return;
    }
    
    if((ReadReg(LSR) & LSR_TX_IDLE) == 0){
    800008b6:	10000937          	lui	s2,0x10000
    800008ba:	0915                	addi	s2,s2,5 # 10000005 <_entry-0x6ffffffb>
      // so we cannot give it another byte.
      // it will interrupt when it's ready for a new byte.
      return;
    }
    
    int c = uart_tx_buf[uart_tx_r % UART_TX_BUF_SIZE];
    800008bc:	00010a97          	auipc	s5,0x10
    800008c0:	23ca8a93          	addi	s5,s5,572 # 80010af8 <uart_tx_lock>
    uart_tx_r += 1;
    800008c4:	00008497          	auipc	s1,0x8
    800008c8:	ff448493          	addi	s1,s1,-12 # 800088b8 <uart_tx_r>
    
    // maybe uartputc() is waiting for space in the buffer.
    wakeup(&uart_tx_r);
    
    WriteReg(THR, c);
    800008cc:	10000a37          	lui	s4,0x10000
    if(uart_tx_w == uart_tx_r){
    800008d0:	00008997          	auipc	s3,0x8
    800008d4:	ff098993          	addi	s3,s3,-16 # 800088c0 <uart_tx_w>
    if((ReadReg(LSR) & LSR_TX_IDLE) == 0){
    800008d8:	00094703          	lbu	a4,0(s2)
    800008dc:	02077713          	andi	a4,a4,32
    800008e0:	c705                	beqz	a4,80000908 <uartstart+0x7a>
    int c = uart_tx_buf[uart_tx_r % UART_TX_BUF_SIZE];
    800008e2:	01f7f713          	andi	a4,a5,31
    800008e6:	9756                	add	a4,a4,s5
    800008e8:	01874b03          	lbu	s6,24(a4)
    uart_tx_r += 1;
    800008ec:	0785                	addi	a5,a5,1
    800008ee:	e09c                	sd	a5,0(s1)
    wakeup(&uart_tx_r);
    800008f0:	8526                	mv	a0,s1
    800008f2:	00002097          	auipc	ra,0x2
    800008f6:	b3c080e7          	jalr	-1220(ra) # 8000242e <wakeup>
    WriteReg(THR, c);
    800008fa:	016a0023          	sb	s6,0(s4) # 10000000 <_entry-0x70000000>
    if(uart_tx_w == uart_tx_r){
    800008fe:	609c                	ld	a5,0(s1)
    80000900:	0009b703          	ld	a4,0(s3)
    80000904:	fcf71ae3          	bne	a4,a5,800008d8 <uartstart+0x4a>
  }
}
    80000908:	70e2                	ld	ra,56(sp)
    8000090a:	7442                	ld	s0,48(sp)
    8000090c:	74a2                	ld	s1,40(sp)
    8000090e:	7902                	ld	s2,32(sp)
    80000910:	69e2                	ld	s3,24(sp)
    80000912:	6a42                	ld	s4,16(sp)
    80000914:	6aa2                	ld	s5,8(sp)
    80000916:	6b02                	ld	s6,0(sp)
    80000918:	6121                	addi	sp,sp,64
    8000091a:	8082                	ret
    8000091c:	8082                	ret

000000008000091e <uartputc>:
{
    8000091e:	7179                	addi	sp,sp,-48
    80000920:	f406                	sd	ra,40(sp)
    80000922:	f022                	sd	s0,32(sp)
    80000924:	ec26                	sd	s1,24(sp)
    80000926:	e84a                	sd	s2,16(sp)
    80000928:	e44e                	sd	s3,8(sp)
    8000092a:	e052                	sd	s4,0(sp)
    8000092c:	1800                	addi	s0,sp,48
    8000092e:	8a2a                	mv	s4,a0
  acquire(&uart_tx_lock);
    80000930:	00010517          	auipc	a0,0x10
    80000934:	1c850513          	addi	a0,a0,456 # 80010af8 <uart_tx_lock>
    80000938:	00000097          	auipc	ra,0x0
    8000093c:	300080e7          	jalr	768(ra) # 80000c38 <acquire>
  if(panicked){
    80000940:	00008797          	auipc	a5,0x8
    80000944:	f707a783          	lw	a5,-144(a5) # 800088b0 <panicked>
    80000948:	e7c9                	bnez	a5,800009d2 <uartputc+0xb4>
  while(uart_tx_w == uart_tx_r + UART_TX_BUF_SIZE){
    8000094a:	00008717          	auipc	a4,0x8
    8000094e:	f7673703          	ld	a4,-138(a4) # 800088c0 <uart_tx_w>
    80000952:	00008797          	auipc	a5,0x8
    80000956:	f667b783          	ld	a5,-154(a5) # 800088b8 <uart_tx_r>
    8000095a:	02078793          	addi	a5,a5,32
    sleep(&uart_tx_r, &uart_tx_lock);
    8000095e:	00010997          	auipc	s3,0x10
    80000962:	19a98993          	addi	s3,s3,410 # 80010af8 <uart_tx_lock>
    80000966:	00008497          	auipc	s1,0x8
    8000096a:	f5248493          	addi	s1,s1,-174 # 800088b8 <uart_tx_r>
  while(uart_tx_w == uart_tx_r + UART_TX_BUF_SIZE){
    8000096e:	00008917          	auipc	s2,0x8
    80000972:	f5290913          	addi	s2,s2,-174 # 800088c0 <uart_tx_w>
    80000976:	00e79f63          	bne	a5,a4,80000994 <uartputc+0x76>
    sleep(&uart_tx_r, &uart_tx_lock);
    8000097a:	85ce                	mv	a1,s3
    8000097c:	8526                	mv	a0,s1
    8000097e:	00002097          	auipc	ra,0x2
    80000982:	a40080e7          	jalr	-1472(ra) # 800023be <sleep>
  while(uart_tx_w == uart_tx_r + UART_TX_BUF_SIZE){
    80000986:	00093703          	ld	a4,0(s2)
    8000098a:	609c                	ld	a5,0(s1)
    8000098c:	02078793          	addi	a5,a5,32
    80000990:	fee785e3          	beq	a5,a4,8000097a <uartputc+0x5c>
  uart_tx_buf[uart_tx_w % UART_TX_BUF_SIZE] = c;
    80000994:	00010497          	auipc	s1,0x10
    80000998:	16448493          	addi	s1,s1,356 # 80010af8 <uart_tx_lock>
    8000099c:	01f77793          	andi	a5,a4,31
    800009a0:	97a6                	add	a5,a5,s1
    800009a2:	01478c23          	sb	s4,24(a5)
  uart_tx_w += 1;
    800009a6:	0705                	addi	a4,a4,1
    800009a8:	00008797          	auipc	a5,0x8
    800009ac:	f0e7bc23          	sd	a4,-232(a5) # 800088c0 <uart_tx_w>
  uartstart();
    800009b0:	00000097          	auipc	ra,0x0
    800009b4:	ede080e7          	jalr	-290(ra) # 8000088e <uartstart>
  release(&uart_tx_lock);
    800009b8:	8526                	mv	a0,s1
    800009ba:	00000097          	auipc	ra,0x0
    800009be:	332080e7          	jalr	818(ra) # 80000cec <release>
}
    800009c2:	70a2                	ld	ra,40(sp)
    800009c4:	7402                	ld	s0,32(sp)
    800009c6:	64e2                	ld	s1,24(sp)
    800009c8:	6942                	ld	s2,16(sp)
    800009ca:	69a2                	ld	s3,8(sp)
    800009cc:	6a02                	ld	s4,0(sp)
    800009ce:	6145                	addi	sp,sp,48
    800009d0:	8082                	ret
    for(;;)
    800009d2:	a001                	j	800009d2 <uartputc+0xb4>

00000000800009d4 <uartgetc>:

// read one input character from the UART.
// return -1 if none is waiting.
int
uartgetc(void)
{
    800009d4:	1141                	addi	sp,sp,-16
    800009d6:	e422                	sd	s0,8(sp)
    800009d8:	0800                	addi	s0,sp,16
  if(ReadReg(LSR) & 0x01){
    800009da:	100007b7          	lui	a5,0x10000
    800009de:	0795                	addi	a5,a5,5 # 10000005 <_entry-0x6ffffffb>
    800009e0:	0007c783          	lbu	a5,0(a5)
    800009e4:	8b85                	andi	a5,a5,1
    800009e6:	cb81                	beqz	a5,800009f6 <uartgetc+0x22>
    // input data is ready.
    return ReadReg(RHR);
    800009e8:	100007b7          	lui	a5,0x10000
    800009ec:	0007c503          	lbu	a0,0(a5) # 10000000 <_entry-0x70000000>
  } else {
    return -1;
  }
}
    800009f0:	6422                	ld	s0,8(sp)
    800009f2:	0141                	addi	sp,sp,16
    800009f4:	8082                	ret
    return -1;
    800009f6:	557d                	li	a0,-1
    800009f8:	bfe5                	j	800009f0 <uartgetc+0x1c>

00000000800009fa <uartintr>:
// handle a uart interrupt, raised because input has
// arrived, or the uart is ready for more output, or
// both. called from devintr().
void
uartintr(void)
{
    800009fa:	1101                	addi	sp,sp,-32
    800009fc:	ec06                	sd	ra,24(sp)
    800009fe:	e822                	sd	s0,16(sp)
    80000a00:	e426                	sd	s1,8(sp)
    80000a02:	1000                	addi	s0,sp,32
  // read and process incoming characters.
  while(1){
    int c = uartgetc();
    if(c == -1)
    80000a04:	54fd                	li	s1,-1
    80000a06:	a029                	j	80000a10 <uartintr+0x16>
      break;
    consoleintr(c);
    80000a08:	00000097          	auipc	ra,0x0
    80000a0c:	8ce080e7          	jalr	-1842(ra) # 800002d6 <consoleintr>
    int c = uartgetc();
    80000a10:	00000097          	auipc	ra,0x0
    80000a14:	fc4080e7          	jalr	-60(ra) # 800009d4 <uartgetc>
    if(c == -1)
    80000a18:	fe9518e3          	bne	a0,s1,80000a08 <uartintr+0xe>
  }

  // send buffered characters.
  acquire(&uart_tx_lock);
    80000a1c:	00010497          	auipc	s1,0x10
    80000a20:	0dc48493          	addi	s1,s1,220 # 80010af8 <uart_tx_lock>
    80000a24:	8526                	mv	a0,s1
    80000a26:	00000097          	auipc	ra,0x0
    80000a2a:	212080e7          	jalr	530(ra) # 80000c38 <acquire>
  uartstart();
    80000a2e:	00000097          	auipc	ra,0x0
    80000a32:	e60080e7          	jalr	-416(ra) # 8000088e <uartstart>
  release(&uart_tx_lock);
    80000a36:	8526                	mv	a0,s1
    80000a38:	00000097          	auipc	ra,0x0
    80000a3c:	2b4080e7          	jalr	692(ra) # 80000cec <release>
}
    80000a40:	60e2                	ld	ra,24(sp)
    80000a42:	6442                	ld	s0,16(sp)
    80000a44:	64a2                	ld	s1,8(sp)
    80000a46:	6105                	addi	sp,sp,32
    80000a48:	8082                	ret

0000000080000a4a <kfree>:
// which normally should have been returned by a
// call to kalloc().  (The exception is when
// initializing the allocator; see kinit above.)
void
kfree(void *pa)
{
    80000a4a:	1101                	addi	sp,sp,-32
    80000a4c:	ec06                	sd	ra,24(sp)
    80000a4e:	e822                	sd	s0,16(sp)
    80000a50:	e426                	sd	s1,8(sp)
    80000a52:	e04a                	sd	s2,0(sp)
    80000a54:	1000                	addi	s0,sp,32
  struct run *r;

  if(((uint64)pa % PGSIZE) != 0 || (char*)pa < end || (uint64)pa >= PHYSTOP)
    80000a56:	03451793          	slli	a5,a0,0x34
    80000a5a:	ebb9                	bnez	a5,80000ab0 <kfree+0x66>
    80000a5c:	84aa                	mv	s1,a0
    80000a5e:	0002a797          	auipc	a5,0x2a
    80000a62:	30278793          	addi	a5,a5,770 # 8002ad60 <end>
    80000a66:	04f56563          	bltu	a0,a5,80000ab0 <kfree+0x66>
    80000a6a:	47c5                	li	a5,17
    80000a6c:	07ee                	slli	a5,a5,0x1b
    80000a6e:	04f57163          	bgeu	a0,a5,80000ab0 <kfree+0x66>
    panic("kfree");

  // Fill with junk to catch dangling refs.
  memset(pa, 1, PGSIZE);
    80000a72:	6605                	lui	a2,0x1
    80000a74:	4585                	li	a1,1
    80000a76:	00000097          	auipc	ra,0x0
    80000a7a:	2be080e7          	jalr	702(ra) # 80000d34 <memset>

  r = (struct run*)pa;

  acquire(&kmem.lock);
    80000a7e:	00010917          	auipc	s2,0x10
    80000a82:	0b290913          	addi	s2,s2,178 # 80010b30 <kmem>
    80000a86:	854a                	mv	a0,s2
    80000a88:	00000097          	auipc	ra,0x0
    80000a8c:	1b0080e7          	jalr	432(ra) # 80000c38 <acquire>
  r->next = kmem.freelist;
    80000a90:	01893783          	ld	a5,24(s2)
    80000a94:	e09c                	sd	a5,0(s1)
  kmem.freelist = r;
    80000a96:	00993c23          	sd	s1,24(s2)
  release(&kmem.lock);
    80000a9a:	854a                	mv	a0,s2
    80000a9c:	00000097          	auipc	ra,0x0
    80000aa0:	250080e7          	jalr	592(ra) # 80000cec <release>
}
    80000aa4:	60e2                	ld	ra,24(sp)
    80000aa6:	6442                	ld	s0,16(sp)
    80000aa8:	64a2                	ld	s1,8(sp)
    80000aaa:	6902                	ld	s2,0(sp)
    80000aac:	6105                	addi	sp,sp,32
    80000aae:	8082                	ret
    panic("kfree");
    80000ab0:	00007517          	auipc	a0,0x7
    80000ab4:	59050513          	addi	a0,a0,1424 # 80008040 <etext+0x40>
    80000ab8:	00000097          	auipc	ra,0x0
    80000abc:	aa8080e7          	jalr	-1368(ra) # 80000560 <panic>

0000000080000ac0 <freerange>:
{
    80000ac0:	7179                	addi	sp,sp,-48
    80000ac2:	f406                	sd	ra,40(sp)
    80000ac4:	f022                	sd	s0,32(sp)
    80000ac6:	ec26                	sd	s1,24(sp)
    80000ac8:	1800                	addi	s0,sp,48
  p = (char*)PGROUNDUP((uint64)pa_start);
    80000aca:	6785                	lui	a5,0x1
    80000acc:	fff78713          	addi	a4,a5,-1 # fff <_entry-0x7ffff001>
    80000ad0:	00e504b3          	add	s1,a0,a4
    80000ad4:	777d                	lui	a4,0xfffff
    80000ad6:	8cf9                	and	s1,s1,a4
  for(; p + PGSIZE <= (char*)pa_end; p += PGSIZE)
    80000ad8:	94be                	add	s1,s1,a5
    80000ada:	0295e463          	bltu	a1,s1,80000b02 <freerange+0x42>
    80000ade:	e84a                	sd	s2,16(sp)
    80000ae0:	e44e                	sd	s3,8(sp)
    80000ae2:	e052                	sd	s4,0(sp)
    80000ae4:	892e                	mv	s2,a1
    kfree(p);
    80000ae6:	7a7d                	lui	s4,0xfffff
  for(; p + PGSIZE <= (char*)pa_end; p += PGSIZE)
    80000ae8:	6985                	lui	s3,0x1
    kfree(p);
    80000aea:	01448533          	add	a0,s1,s4
    80000aee:	00000097          	auipc	ra,0x0
    80000af2:	f5c080e7          	jalr	-164(ra) # 80000a4a <kfree>
  for(; p + PGSIZE <= (char*)pa_end; p += PGSIZE)
    80000af6:	94ce                	add	s1,s1,s3
    80000af8:	fe9979e3          	bgeu	s2,s1,80000aea <freerange+0x2a>
    80000afc:	6942                	ld	s2,16(sp)
    80000afe:	69a2                	ld	s3,8(sp)
    80000b00:	6a02                	ld	s4,0(sp)
}
    80000b02:	70a2                	ld	ra,40(sp)
    80000b04:	7402                	ld	s0,32(sp)
    80000b06:	64e2                	ld	s1,24(sp)
    80000b08:	6145                	addi	sp,sp,48
    80000b0a:	8082                	ret

0000000080000b0c <kinit>:
{
    80000b0c:	1141                	addi	sp,sp,-16
    80000b0e:	e406                	sd	ra,8(sp)
    80000b10:	e022                	sd	s0,0(sp)
    80000b12:	0800                	addi	s0,sp,16
  initlock(&kmem.lock, "kmem");
    80000b14:	00007597          	auipc	a1,0x7
    80000b18:	53458593          	addi	a1,a1,1332 # 80008048 <etext+0x48>
    80000b1c:	00010517          	auipc	a0,0x10
    80000b20:	01450513          	addi	a0,a0,20 # 80010b30 <kmem>
    80000b24:	00000097          	auipc	ra,0x0
    80000b28:	084080e7          	jalr	132(ra) # 80000ba8 <initlock>
  freerange(end, (void*)PHYSTOP);
    80000b2c:	45c5                	li	a1,17
    80000b2e:	05ee                	slli	a1,a1,0x1b
    80000b30:	0002a517          	auipc	a0,0x2a
    80000b34:	23050513          	addi	a0,a0,560 # 8002ad60 <end>
    80000b38:	00000097          	auipc	ra,0x0
    80000b3c:	f88080e7          	jalr	-120(ra) # 80000ac0 <freerange>
}
    80000b40:	60a2                	ld	ra,8(sp)
    80000b42:	6402                	ld	s0,0(sp)
    80000b44:	0141                	addi	sp,sp,16
    80000b46:	8082                	ret

0000000080000b48 <kalloc>:
// Allocate one 4096-byte page of physical memory.
// Returns a pointer that the kernel can use.
// Returns 0 if the memory cannot be allocated.
void *
kalloc(void)
{
    80000b48:	1101                	addi	sp,sp,-32
    80000b4a:	ec06                	sd	ra,24(sp)
    80000b4c:	e822                	sd	s0,16(sp)
    80000b4e:	e426                	sd	s1,8(sp)
    80000b50:	1000                	addi	s0,sp,32
  struct run *r;

  acquire(&kmem.lock);
    80000b52:	00010497          	auipc	s1,0x10
    80000b56:	fde48493          	addi	s1,s1,-34 # 80010b30 <kmem>
    80000b5a:	8526                	mv	a0,s1
    80000b5c:	00000097          	auipc	ra,0x0
    80000b60:	0dc080e7          	jalr	220(ra) # 80000c38 <acquire>
  r = kmem.freelist;
    80000b64:	6c84                	ld	s1,24(s1)
  if(r)
    80000b66:	c885                	beqz	s1,80000b96 <kalloc+0x4e>
    kmem.freelist = r->next;
    80000b68:	609c                	ld	a5,0(s1)
    80000b6a:	00010517          	auipc	a0,0x10
    80000b6e:	fc650513          	addi	a0,a0,-58 # 80010b30 <kmem>
    80000b72:	ed1c                	sd	a5,24(a0)
  release(&kmem.lock);
    80000b74:	00000097          	auipc	ra,0x0
    80000b78:	178080e7          	jalr	376(ra) # 80000cec <release>

  if(r)
    memset((char*)r, 5, PGSIZE); // fill with junk
    80000b7c:	6605                	lui	a2,0x1
    80000b7e:	4595                	li	a1,5
    80000b80:	8526                	mv	a0,s1
    80000b82:	00000097          	auipc	ra,0x0
    80000b86:	1b2080e7          	jalr	434(ra) # 80000d34 <memset>
  return (void*)r;
}
    80000b8a:	8526                	mv	a0,s1
    80000b8c:	60e2                	ld	ra,24(sp)
    80000b8e:	6442                	ld	s0,16(sp)
    80000b90:	64a2                	ld	s1,8(sp)
    80000b92:	6105                	addi	sp,sp,32
    80000b94:	8082                	ret
  release(&kmem.lock);
    80000b96:	00010517          	auipc	a0,0x10
    80000b9a:	f9a50513          	addi	a0,a0,-102 # 80010b30 <kmem>
    80000b9e:	00000097          	auipc	ra,0x0
    80000ba2:	14e080e7          	jalr	334(ra) # 80000cec <release>
  if(r)
    80000ba6:	b7d5                	j	80000b8a <kalloc+0x42>

0000000080000ba8 <initlock>:
#include "proc.h"
#include "defs.h"

void
initlock(struct spinlock *lk, char *name)
{
    80000ba8:	1141                	addi	sp,sp,-16
    80000baa:	e422                	sd	s0,8(sp)
    80000bac:	0800                	addi	s0,sp,16
  lk->name = name;
    80000bae:	e50c                	sd	a1,8(a0)
  lk->locked = 0;
    80000bb0:	00052023          	sw	zero,0(a0)
  lk->cpu = 0;
    80000bb4:	00053823          	sd	zero,16(a0)
}
    80000bb8:	6422                	ld	s0,8(sp)
    80000bba:	0141                	addi	sp,sp,16
    80000bbc:	8082                	ret

0000000080000bbe <holding>:
// Interrupts must be off.
int
holding(struct spinlock *lk)
{
  int r;
  r = (lk->locked && lk->cpu == mycpu());
    80000bbe:	411c                	lw	a5,0(a0)
    80000bc0:	e399                	bnez	a5,80000bc6 <holding+0x8>
    80000bc2:	4501                	li	a0,0
  return r;
}
    80000bc4:	8082                	ret
{
    80000bc6:	1101                	addi	sp,sp,-32
    80000bc8:	ec06                	sd	ra,24(sp)
    80000bca:	e822                	sd	s0,16(sp)
    80000bcc:	e426                	sd	s1,8(sp)
    80000bce:	1000                	addi	s0,sp,32
  r = (lk->locked && lk->cpu == mycpu());
    80000bd0:	6904                	ld	s1,16(a0)
    80000bd2:	00001097          	auipc	ra,0x1
    80000bd6:	046080e7          	jalr	70(ra) # 80001c18 <mycpu>
    80000bda:	40a48533          	sub	a0,s1,a0
    80000bde:	00153513          	seqz	a0,a0
}
    80000be2:	60e2                	ld	ra,24(sp)
    80000be4:	6442                	ld	s0,16(sp)
    80000be6:	64a2                	ld	s1,8(sp)
    80000be8:	6105                	addi	sp,sp,32
    80000bea:	8082                	ret

0000000080000bec <push_off>:
// it takes two pop_off()s to undo two push_off()s.  Also, if interrupts
// are initially off, then push_off, pop_off leaves them off.

void
push_off(void)
{
    80000bec:	1101                	addi	sp,sp,-32
    80000bee:	ec06                	sd	ra,24(sp)
    80000bf0:	e822                	sd	s0,16(sp)
    80000bf2:	e426                	sd	s1,8(sp)
    80000bf4:	1000                	addi	s0,sp,32
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80000bf6:	100024f3          	csrr	s1,sstatus
    80000bfa:	100027f3          	csrr	a5,sstatus
  w_sstatus(r_sstatus() & ~SSTATUS_SIE);
    80000bfe:	9bf5                	andi	a5,a5,-3
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80000c00:	10079073          	csrw	sstatus,a5
  int old = intr_get();

  intr_off();
  if(mycpu()->noff == 0)
    80000c04:	00001097          	auipc	ra,0x1
    80000c08:	014080e7          	jalr	20(ra) # 80001c18 <mycpu>
    80000c0c:	5d3c                	lw	a5,120(a0)
    80000c0e:	cf89                	beqz	a5,80000c28 <push_off+0x3c>
    mycpu()->intena = old;
  mycpu()->noff += 1;
    80000c10:	00001097          	auipc	ra,0x1
    80000c14:	008080e7          	jalr	8(ra) # 80001c18 <mycpu>
    80000c18:	5d3c                	lw	a5,120(a0)
    80000c1a:	2785                	addiw	a5,a5,1
    80000c1c:	dd3c                	sw	a5,120(a0)
}
    80000c1e:	60e2                	ld	ra,24(sp)
    80000c20:	6442                	ld	s0,16(sp)
    80000c22:	64a2                	ld	s1,8(sp)
    80000c24:	6105                	addi	sp,sp,32
    80000c26:	8082                	ret
    mycpu()->intena = old;
    80000c28:	00001097          	auipc	ra,0x1
    80000c2c:	ff0080e7          	jalr	-16(ra) # 80001c18 <mycpu>
  return (x & SSTATUS_SIE) != 0;
    80000c30:	8085                	srli	s1,s1,0x1
    80000c32:	8885                	andi	s1,s1,1
    80000c34:	dd64                	sw	s1,124(a0)
    80000c36:	bfe9                	j	80000c10 <push_off+0x24>

0000000080000c38 <acquire>:
{
    80000c38:	1101                	addi	sp,sp,-32
    80000c3a:	ec06                	sd	ra,24(sp)
    80000c3c:	e822                	sd	s0,16(sp)
    80000c3e:	e426                	sd	s1,8(sp)
    80000c40:	1000                	addi	s0,sp,32
    80000c42:	84aa                	mv	s1,a0
  push_off(); // disable interrupts to avoid deadlock.
    80000c44:	00000097          	auipc	ra,0x0
    80000c48:	fa8080e7          	jalr	-88(ra) # 80000bec <push_off>
  if(holding(lk))
    80000c4c:	8526                	mv	a0,s1
    80000c4e:	00000097          	auipc	ra,0x0
    80000c52:	f70080e7          	jalr	-144(ra) # 80000bbe <holding>
  while(__sync_lock_test_and_set(&lk->locked, 1) != 0)
    80000c56:	4705                	li	a4,1
  if(holding(lk))
    80000c58:	e115                	bnez	a0,80000c7c <acquire+0x44>
  while(__sync_lock_test_and_set(&lk->locked, 1) != 0)
    80000c5a:	87ba                	mv	a5,a4
    80000c5c:	0cf4a7af          	amoswap.w.aq	a5,a5,(s1)
    80000c60:	2781                	sext.w	a5,a5
    80000c62:	ffe5                	bnez	a5,80000c5a <acquire+0x22>
  __sync_synchronize();
    80000c64:	0ff0000f          	fence
  lk->cpu = mycpu();
    80000c68:	00001097          	auipc	ra,0x1
    80000c6c:	fb0080e7          	jalr	-80(ra) # 80001c18 <mycpu>
    80000c70:	e888                	sd	a0,16(s1)
}
    80000c72:	60e2                	ld	ra,24(sp)
    80000c74:	6442                	ld	s0,16(sp)
    80000c76:	64a2                	ld	s1,8(sp)
    80000c78:	6105                	addi	sp,sp,32
    80000c7a:	8082                	ret
    panic("acquire");
    80000c7c:	00007517          	auipc	a0,0x7
    80000c80:	3d450513          	addi	a0,a0,980 # 80008050 <etext+0x50>
    80000c84:	00000097          	auipc	ra,0x0
    80000c88:	8dc080e7          	jalr	-1828(ra) # 80000560 <panic>

0000000080000c8c <pop_off>:

void
pop_off(void)
{
    80000c8c:	1141                	addi	sp,sp,-16
    80000c8e:	e406                	sd	ra,8(sp)
    80000c90:	e022                	sd	s0,0(sp)
    80000c92:	0800                	addi	s0,sp,16
  struct cpu *c = mycpu();
    80000c94:	00001097          	auipc	ra,0x1
    80000c98:	f84080e7          	jalr	-124(ra) # 80001c18 <mycpu>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80000c9c:	100027f3          	csrr	a5,sstatus
  return (x & SSTATUS_SIE) != 0;
    80000ca0:	8b89                	andi	a5,a5,2
  if(intr_get())
    80000ca2:	e78d                	bnez	a5,80000ccc <pop_off+0x40>
    panic("pop_off - interruptible");
  if(c->noff < 1)
    80000ca4:	5d3c                	lw	a5,120(a0)
    80000ca6:	02f05b63          	blez	a5,80000cdc <pop_off+0x50>
    panic("pop_off");
  c->noff -= 1;
    80000caa:	37fd                	addiw	a5,a5,-1
    80000cac:	0007871b          	sext.w	a4,a5
    80000cb0:	dd3c                	sw	a5,120(a0)
  if(c->noff == 0 && c->intena)
    80000cb2:	eb09                	bnez	a4,80000cc4 <pop_off+0x38>
    80000cb4:	5d7c                	lw	a5,124(a0)
    80000cb6:	c799                	beqz	a5,80000cc4 <pop_off+0x38>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80000cb8:	100027f3          	csrr	a5,sstatus
  w_sstatus(r_sstatus() | SSTATUS_SIE);
    80000cbc:	0027e793          	ori	a5,a5,2
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80000cc0:	10079073          	csrw	sstatus,a5
    intr_on();
}
    80000cc4:	60a2                	ld	ra,8(sp)
    80000cc6:	6402                	ld	s0,0(sp)
    80000cc8:	0141                	addi	sp,sp,16
    80000cca:	8082                	ret
    panic("pop_off - interruptible");
    80000ccc:	00007517          	auipc	a0,0x7
    80000cd0:	38c50513          	addi	a0,a0,908 # 80008058 <etext+0x58>
    80000cd4:	00000097          	auipc	ra,0x0
    80000cd8:	88c080e7          	jalr	-1908(ra) # 80000560 <panic>
    panic("pop_off");
    80000cdc:	00007517          	auipc	a0,0x7
    80000ce0:	39450513          	addi	a0,a0,916 # 80008070 <etext+0x70>
    80000ce4:	00000097          	auipc	ra,0x0
    80000ce8:	87c080e7          	jalr	-1924(ra) # 80000560 <panic>

0000000080000cec <release>:
{
    80000cec:	1101                	addi	sp,sp,-32
    80000cee:	ec06                	sd	ra,24(sp)
    80000cf0:	e822                	sd	s0,16(sp)
    80000cf2:	e426                	sd	s1,8(sp)
    80000cf4:	1000                	addi	s0,sp,32
    80000cf6:	84aa                	mv	s1,a0
  if(!holding(lk))
    80000cf8:	00000097          	auipc	ra,0x0
    80000cfc:	ec6080e7          	jalr	-314(ra) # 80000bbe <holding>
    80000d00:	c115                	beqz	a0,80000d24 <release+0x38>
  lk->cpu = 0;
    80000d02:	0004b823          	sd	zero,16(s1)
  __sync_synchronize();
    80000d06:	0ff0000f          	fence
  __sync_lock_release(&lk->locked);
    80000d0a:	0f50000f          	fence	iorw,ow
    80000d0e:	0804a02f          	amoswap.w	zero,zero,(s1)
  pop_off();
    80000d12:	00000097          	auipc	ra,0x0
    80000d16:	f7a080e7          	jalr	-134(ra) # 80000c8c <pop_off>
}
    80000d1a:	60e2                	ld	ra,24(sp)
    80000d1c:	6442                	ld	s0,16(sp)
    80000d1e:	64a2                	ld	s1,8(sp)
    80000d20:	6105                	addi	sp,sp,32
    80000d22:	8082                	ret
    panic("release");
    80000d24:	00007517          	auipc	a0,0x7
    80000d28:	35450513          	addi	a0,a0,852 # 80008078 <etext+0x78>
    80000d2c:	00000097          	auipc	ra,0x0
    80000d30:	834080e7          	jalr	-1996(ra) # 80000560 <panic>

0000000080000d34 <memset>:
#include "types.h"

void*
memset(void *dst, int c, uint n)
{
    80000d34:	1141                	addi	sp,sp,-16
    80000d36:	e422                	sd	s0,8(sp)
    80000d38:	0800                	addi	s0,sp,16
  char *cdst = (char *) dst;
  int i;
  for(i = 0; i < n; i++){
    80000d3a:	ca19                	beqz	a2,80000d50 <memset+0x1c>
    80000d3c:	87aa                	mv	a5,a0
    80000d3e:	1602                	slli	a2,a2,0x20
    80000d40:	9201                	srli	a2,a2,0x20
    80000d42:	00a60733          	add	a4,a2,a0
    cdst[i] = c;
    80000d46:	00b78023          	sb	a1,0(a5)
  for(i = 0; i < n; i++){
    80000d4a:	0785                	addi	a5,a5,1
    80000d4c:	fee79de3          	bne	a5,a4,80000d46 <memset+0x12>
  }
  return dst;
}
    80000d50:	6422                	ld	s0,8(sp)
    80000d52:	0141                	addi	sp,sp,16
    80000d54:	8082                	ret

0000000080000d56 <memcmp>:

int
memcmp(const void *v1, const void *v2, uint n)
{
    80000d56:	1141                	addi	sp,sp,-16
    80000d58:	e422                	sd	s0,8(sp)
    80000d5a:	0800                	addi	s0,sp,16
  const uchar *s1, *s2;

  s1 = v1;
  s2 = v2;
  while(n-- > 0){
    80000d5c:	ca05                	beqz	a2,80000d8c <memcmp+0x36>
    80000d5e:	fff6069b          	addiw	a3,a2,-1 # fff <_entry-0x7ffff001>
    80000d62:	1682                	slli	a3,a3,0x20
    80000d64:	9281                	srli	a3,a3,0x20
    80000d66:	0685                	addi	a3,a3,1
    80000d68:	96aa                	add	a3,a3,a0
    if(*s1 != *s2)
    80000d6a:	00054783          	lbu	a5,0(a0)
    80000d6e:	0005c703          	lbu	a4,0(a1)
    80000d72:	00e79863          	bne	a5,a4,80000d82 <memcmp+0x2c>
      return *s1 - *s2;
    s1++, s2++;
    80000d76:	0505                	addi	a0,a0,1
    80000d78:	0585                	addi	a1,a1,1
  while(n-- > 0){
    80000d7a:	fed518e3          	bne	a0,a3,80000d6a <memcmp+0x14>
  }

  return 0;
    80000d7e:	4501                	li	a0,0
    80000d80:	a019                	j	80000d86 <memcmp+0x30>
      return *s1 - *s2;
    80000d82:	40e7853b          	subw	a0,a5,a4
}
    80000d86:	6422                	ld	s0,8(sp)
    80000d88:	0141                	addi	sp,sp,16
    80000d8a:	8082                	ret
  return 0;
    80000d8c:	4501                	li	a0,0
    80000d8e:	bfe5                	j	80000d86 <memcmp+0x30>

0000000080000d90 <memmove>:

void*
memmove(void *dst, const void *src, uint n)
{
    80000d90:	1141                	addi	sp,sp,-16
    80000d92:	e422                	sd	s0,8(sp)
    80000d94:	0800                	addi	s0,sp,16
  const char *s;
  char *d;

  if(n == 0)
    80000d96:	c205                	beqz	a2,80000db6 <memmove+0x26>
    return dst;
  
  s = src;
  d = dst;
  if(s < d && s + n > d){
    80000d98:	02a5e263          	bltu	a1,a0,80000dbc <memmove+0x2c>
    s += n;
    d += n;
    while(n-- > 0)
      *--d = *--s;
  } else
    while(n-- > 0)
    80000d9c:	1602                	slli	a2,a2,0x20
    80000d9e:	9201                	srli	a2,a2,0x20
    80000da0:	00c587b3          	add	a5,a1,a2
{
    80000da4:	872a                	mv	a4,a0
      *d++ = *s++;
    80000da6:	0585                	addi	a1,a1,1
    80000da8:	0705                	addi	a4,a4,1 # fffffffffffff001 <end+0xffffffff7ffd42a1>
    80000daa:	fff5c683          	lbu	a3,-1(a1)
    80000dae:	fed70fa3          	sb	a3,-1(a4)
    while(n-- > 0)
    80000db2:	feb79ae3          	bne	a5,a1,80000da6 <memmove+0x16>

  return dst;
}
    80000db6:	6422                	ld	s0,8(sp)
    80000db8:	0141                	addi	sp,sp,16
    80000dba:	8082                	ret
  if(s < d && s + n > d){
    80000dbc:	02061693          	slli	a3,a2,0x20
    80000dc0:	9281                	srli	a3,a3,0x20
    80000dc2:	00d58733          	add	a4,a1,a3
    80000dc6:	fce57be3          	bgeu	a0,a4,80000d9c <memmove+0xc>
    d += n;
    80000dca:	96aa                	add	a3,a3,a0
    while(n-- > 0)
    80000dcc:	fff6079b          	addiw	a5,a2,-1
    80000dd0:	1782                	slli	a5,a5,0x20
    80000dd2:	9381                	srli	a5,a5,0x20
    80000dd4:	fff7c793          	not	a5,a5
    80000dd8:	97ba                	add	a5,a5,a4
      *--d = *--s;
    80000dda:	177d                	addi	a4,a4,-1
    80000ddc:	16fd                	addi	a3,a3,-1
    80000dde:	00074603          	lbu	a2,0(a4)
    80000de2:	00c68023          	sb	a2,0(a3)
    while(n-- > 0)
    80000de6:	fef71ae3          	bne	a4,a5,80000dda <memmove+0x4a>
    80000dea:	b7f1                	j	80000db6 <memmove+0x26>

0000000080000dec <memcpy>:

// memcpy exists to placate GCC.  Use memmove.
void*
memcpy(void *dst, const void *src, uint n)
{
    80000dec:	1141                	addi	sp,sp,-16
    80000dee:	e406                	sd	ra,8(sp)
    80000df0:	e022                	sd	s0,0(sp)
    80000df2:	0800                	addi	s0,sp,16
  return memmove(dst, src, n);
    80000df4:	00000097          	auipc	ra,0x0
    80000df8:	f9c080e7          	jalr	-100(ra) # 80000d90 <memmove>
}
    80000dfc:	60a2                	ld	ra,8(sp)
    80000dfe:	6402                	ld	s0,0(sp)
    80000e00:	0141                	addi	sp,sp,16
    80000e02:	8082                	ret

0000000080000e04 <strncmp>:

int
strncmp(const char *p, const char *q, uint n)
{
    80000e04:	1141                	addi	sp,sp,-16
    80000e06:	e422                	sd	s0,8(sp)
    80000e08:	0800                	addi	s0,sp,16
  while(n > 0 && *p && *p == *q)
    80000e0a:	ce11                	beqz	a2,80000e26 <strncmp+0x22>
    80000e0c:	00054783          	lbu	a5,0(a0)
    80000e10:	cf89                	beqz	a5,80000e2a <strncmp+0x26>
    80000e12:	0005c703          	lbu	a4,0(a1)
    80000e16:	00f71a63          	bne	a4,a5,80000e2a <strncmp+0x26>
    n--, p++, q++;
    80000e1a:	367d                	addiw	a2,a2,-1
    80000e1c:	0505                	addi	a0,a0,1
    80000e1e:	0585                	addi	a1,a1,1
  while(n > 0 && *p && *p == *q)
    80000e20:	f675                	bnez	a2,80000e0c <strncmp+0x8>
  if(n == 0)
    return 0;
    80000e22:	4501                	li	a0,0
    80000e24:	a801                	j	80000e34 <strncmp+0x30>
    80000e26:	4501                	li	a0,0
    80000e28:	a031                	j	80000e34 <strncmp+0x30>
  return (uchar)*p - (uchar)*q;
    80000e2a:	00054503          	lbu	a0,0(a0)
    80000e2e:	0005c783          	lbu	a5,0(a1)
    80000e32:	9d1d                	subw	a0,a0,a5
}
    80000e34:	6422                	ld	s0,8(sp)
    80000e36:	0141                	addi	sp,sp,16
    80000e38:	8082                	ret

0000000080000e3a <strncpy>:

char*
strncpy(char *s, const char *t, int n)
{
    80000e3a:	1141                	addi	sp,sp,-16
    80000e3c:	e422                	sd	s0,8(sp)
    80000e3e:	0800                	addi	s0,sp,16
  char *os;

  os = s;
  while(n-- > 0 && (*s++ = *t++) != 0)
    80000e40:	87aa                	mv	a5,a0
    80000e42:	86b2                	mv	a3,a2
    80000e44:	367d                	addiw	a2,a2,-1
    80000e46:	02d05563          	blez	a3,80000e70 <strncpy+0x36>
    80000e4a:	0785                	addi	a5,a5,1
    80000e4c:	0005c703          	lbu	a4,0(a1)
    80000e50:	fee78fa3          	sb	a4,-1(a5)
    80000e54:	0585                	addi	a1,a1,1
    80000e56:	f775                	bnez	a4,80000e42 <strncpy+0x8>
    ;
  while(n-- > 0)
    80000e58:	873e                	mv	a4,a5
    80000e5a:	9fb5                	addw	a5,a5,a3
    80000e5c:	37fd                	addiw	a5,a5,-1
    80000e5e:	00c05963          	blez	a2,80000e70 <strncpy+0x36>
    *s++ = 0;
    80000e62:	0705                	addi	a4,a4,1
    80000e64:	fe070fa3          	sb	zero,-1(a4)
  while(n-- > 0)
    80000e68:	40e786bb          	subw	a3,a5,a4
    80000e6c:	fed04be3          	bgtz	a3,80000e62 <strncpy+0x28>
  return os;
}
    80000e70:	6422                	ld	s0,8(sp)
    80000e72:	0141                	addi	sp,sp,16
    80000e74:	8082                	ret

0000000080000e76 <safestrcpy>:

// Like strncpy but guaranteed to NUL-terminate.
char*
safestrcpy(char *s, const char *t, int n)
{
    80000e76:	1141                	addi	sp,sp,-16
    80000e78:	e422                	sd	s0,8(sp)
    80000e7a:	0800                	addi	s0,sp,16
  char *os;

  os = s;
  if(n <= 0)
    80000e7c:	02c05363          	blez	a2,80000ea2 <safestrcpy+0x2c>
    80000e80:	fff6069b          	addiw	a3,a2,-1
    80000e84:	1682                	slli	a3,a3,0x20
    80000e86:	9281                	srli	a3,a3,0x20
    80000e88:	96ae                	add	a3,a3,a1
    80000e8a:	87aa                	mv	a5,a0
    return os;
  while(--n > 0 && (*s++ = *t++) != 0)
    80000e8c:	00d58963          	beq	a1,a3,80000e9e <safestrcpy+0x28>
    80000e90:	0585                	addi	a1,a1,1
    80000e92:	0785                	addi	a5,a5,1
    80000e94:	fff5c703          	lbu	a4,-1(a1)
    80000e98:	fee78fa3          	sb	a4,-1(a5)
    80000e9c:	fb65                	bnez	a4,80000e8c <safestrcpy+0x16>
    ;
  *s = 0;
    80000e9e:	00078023          	sb	zero,0(a5)
  return os;
}
    80000ea2:	6422                	ld	s0,8(sp)
    80000ea4:	0141                	addi	sp,sp,16
    80000ea6:	8082                	ret

0000000080000ea8 <strlen>:

int
strlen(const char *s)
{
    80000ea8:	1141                	addi	sp,sp,-16
    80000eaa:	e422                	sd	s0,8(sp)
    80000eac:	0800                	addi	s0,sp,16
  int n;

  for(n = 0; s[n]; n++)
    80000eae:	00054783          	lbu	a5,0(a0)
    80000eb2:	cf91                	beqz	a5,80000ece <strlen+0x26>
    80000eb4:	0505                	addi	a0,a0,1
    80000eb6:	87aa                	mv	a5,a0
    80000eb8:	86be                	mv	a3,a5
    80000eba:	0785                	addi	a5,a5,1
    80000ebc:	fff7c703          	lbu	a4,-1(a5)
    80000ec0:	ff65                	bnez	a4,80000eb8 <strlen+0x10>
    80000ec2:	40a6853b          	subw	a0,a3,a0
    80000ec6:	2505                	addiw	a0,a0,1
    ;
  return n;
}
    80000ec8:	6422                	ld	s0,8(sp)
    80000eca:	0141                	addi	sp,sp,16
    80000ecc:	8082                	ret
  for(n = 0; s[n]; n++)
    80000ece:	4501                	li	a0,0
    80000ed0:	bfe5                	j	80000ec8 <strlen+0x20>

0000000080000ed2 <main>:
volatile static int started = 0;

// start() jumps here in supervisor mode on all CPUs.
void
main()
{
    80000ed2:	1141                	addi	sp,sp,-16
    80000ed4:	e406                	sd	ra,8(sp)
    80000ed6:	e022                	sd	s0,0(sp)
    80000ed8:	0800                	addi	s0,sp,16
  if(cpuid() == 0){
    80000eda:	00001097          	auipc	ra,0x1
    80000ede:	d2e080e7          	jalr	-722(ra) # 80001c08 <cpuid>
    virtio_disk_init(); // emulated hard disk
    userinit();      // first user process
    __sync_synchronize();
    started = 1;
  } else {
    while(started == 0)
    80000ee2:	00008717          	auipc	a4,0x8
    80000ee6:	9e670713          	addi	a4,a4,-1562 # 800088c8 <started>
  if(cpuid() == 0){
    80000eea:	c139                	beqz	a0,80000f30 <main+0x5e>
    while(started == 0)
    80000eec:	431c                	lw	a5,0(a4)
    80000eee:	2781                	sext.w	a5,a5
    80000ef0:	dff5                	beqz	a5,80000eec <main+0x1a>
      ;
    __sync_synchronize();
    80000ef2:	0ff0000f          	fence
    printf("hart %d starting\n", cpuid());
    80000ef6:	00001097          	auipc	ra,0x1
    80000efa:	d12080e7          	jalr	-750(ra) # 80001c08 <cpuid>
    80000efe:	85aa                	mv	a1,a0
    80000f00:	00007517          	auipc	a0,0x7
    80000f04:	19850513          	addi	a0,a0,408 # 80008098 <etext+0x98>
    80000f08:	fffff097          	auipc	ra,0xfffff
    80000f0c:	6a2080e7          	jalr	1698(ra) # 800005aa <printf>
    kvminithart();    // turn on paging
    80000f10:	00000097          	auipc	ra,0x0
    80000f14:	0d8080e7          	jalr	216(ra) # 80000fe8 <kvminithart>
    trapinithart();   // install kernel trap vector
    80000f18:	00002097          	auipc	ra,0x2
    80000f1c:	cb4080e7          	jalr	-844(ra) # 80002bcc <trapinithart>
    plicinithart();   // ask PLIC for device interrupts
    80000f20:	00005097          	auipc	ra,0x5
    80000f24:	5e4080e7          	jalr	1508(ra) # 80006504 <plicinithart>
  }

  scheduler();        
    80000f28:	00001097          	auipc	ra,0x1
    80000f2c:	264080e7          	jalr	612(ra) # 8000218c <scheduler>
    consoleinit();
    80000f30:	fffff097          	auipc	ra,0xfffff
    80000f34:	540080e7          	jalr	1344(ra) # 80000470 <consoleinit>
    printfinit();
    80000f38:	00000097          	auipc	ra,0x0
    80000f3c:	87a080e7          	jalr	-1926(ra) # 800007b2 <printfinit>
    printf("\n");
    80000f40:	00007517          	auipc	a0,0x7
    80000f44:	0d050513          	addi	a0,a0,208 # 80008010 <etext+0x10>
    80000f48:	fffff097          	auipc	ra,0xfffff
    80000f4c:	662080e7          	jalr	1634(ra) # 800005aa <printf>
    printf("xv6 kernel is booting\n");
    80000f50:	00007517          	auipc	a0,0x7
    80000f54:	13050513          	addi	a0,a0,304 # 80008080 <etext+0x80>
    80000f58:	fffff097          	auipc	ra,0xfffff
    80000f5c:	652080e7          	jalr	1618(ra) # 800005aa <printf>
    printf("\n");
    80000f60:	00007517          	auipc	a0,0x7
    80000f64:	0b050513          	addi	a0,a0,176 # 80008010 <etext+0x10>
    80000f68:	fffff097          	auipc	ra,0xfffff
    80000f6c:	642080e7          	jalr	1602(ra) # 800005aa <printf>
    kinit();         // physical page allocator
    80000f70:	00000097          	auipc	ra,0x0
    80000f74:	b9c080e7          	jalr	-1124(ra) # 80000b0c <kinit>
    kvminit();       // create kernel page table
    80000f78:	00000097          	auipc	ra,0x0
    80000f7c:	326080e7          	jalr	806(ra) # 8000129e <kvminit>
    kvminithart();   // turn on paging
    80000f80:	00000097          	auipc	ra,0x0
    80000f84:	068080e7          	jalr	104(ra) # 80000fe8 <kvminithart>
    procinit();      // process table
    80000f88:	00001097          	auipc	ra,0x1
    80000f8c:	bc0080e7          	jalr	-1088(ra) # 80001b48 <procinit>
    trapinit();      // trap vectors
    80000f90:	00002097          	auipc	ra,0x2
    80000f94:	c14080e7          	jalr	-1004(ra) # 80002ba4 <trapinit>
    trapinithart();  // install kernel trap vector
    80000f98:	00002097          	auipc	ra,0x2
    80000f9c:	c34080e7          	jalr	-972(ra) # 80002bcc <trapinithart>
    plicinit();      // set up interrupt controller
    80000fa0:	00005097          	auipc	ra,0x5
    80000fa4:	54a080e7          	jalr	1354(ra) # 800064ea <plicinit>
    plicinithart();  // ask PLIC for device interrupts
    80000fa8:	00005097          	auipc	ra,0x5
    80000fac:	55c080e7          	jalr	1372(ra) # 80006504 <plicinithart>
    binit();         // buffer cache
    80000fb0:	00002097          	auipc	ra,0x2
    80000fb4:	60c080e7          	jalr	1548(ra) # 800035bc <binit>
    iinit();         // inode table
    80000fb8:	00003097          	auipc	ra,0x3
    80000fbc:	cc2080e7          	jalr	-830(ra) # 80003c7a <iinit>
    fileinit();      // file table
    80000fc0:	00004097          	auipc	ra,0x4
    80000fc4:	c76080e7          	jalr	-906(ra) # 80004c36 <fileinit>
    virtio_disk_init(); // emulated hard disk
    80000fc8:	00005097          	auipc	ra,0x5
    80000fcc:	644080e7          	jalr	1604(ra) # 8000660c <virtio_disk_init>
    userinit();      // first user process
    80000fd0:	00001097          	auipc	ra,0x1
    80000fd4:	f80080e7          	jalr	-128(ra) # 80001f50 <userinit>
    __sync_synchronize();
    80000fd8:	0ff0000f          	fence
    started = 1;
    80000fdc:	4785                	li	a5,1
    80000fde:	00008717          	auipc	a4,0x8
    80000fe2:	8ef72523          	sw	a5,-1814(a4) # 800088c8 <started>
    80000fe6:	b789                	j	80000f28 <main+0x56>

0000000080000fe8 <kvminithart>:

// Switch h/w page table register to the kernel's page table,
// and enable paging.
void
kvminithart()
{
    80000fe8:	1141                	addi	sp,sp,-16
    80000fea:	e422                	sd	s0,8(sp)
    80000fec:	0800                	addi	s0,sp,16
// flush the TLB.
static inline void
sfence_vma()
{
  // the zero, zero means flush all TLB entries.
  asm volatile("sfence.vma zero, zero");
    80000fee:	12000073          	sfence.vma
  // wait for any previous writes to the page table memory to finish.
  sfence_vma();

  w_satp(MAKE_SATP(kernel_pagetable));
    80000ff2:	00008797          	auipc	a5,0x8
    80000ff6:	8de7b783          	ld	a5,-1826(a5) # 800088d0 <kernel_pagetable>
    80000ffa:	83b1                	srli	a5,a5,0xc
    80000ffc:	577d                	li	a4,-1
    80000ffe:	177e                	slli	a4,a4,0x3f
    80001000:	8fd9                	or	a5,a5,a4
  asm volatile("csrw satp, %0" : : "r" (x));
    80001002:	18079073          	csrw	satp,a5
  asm volatile("sfence.vma zero, zero");
    80001006:	12000073          	sfence.vma

  // flush stale entries from the TLB.
  sfence_vma();
}
    8000100a:	6422                	ld	s0,8(sp)
    8000100c:	0141                	addi	sp,sp,16
    8000100e:	8082                	ret

0000000080001010 <walk>:
//   21..29 -- 9 bits of level-1 index.
//   12..20 -- 9 bits of level-0 index.
//    0..11 -- 12 bits of byte offset within the page.
pte_t *
walk(pagetable_t pagetable, uint64 va, int alloc)
{
    80001010:	7139                	addi	sp,sp,-64
    80001012:	fc06                	sd	ra,56(sp)
    80001014:	f822                	sd	s0,48(sp)
    80001016:	f426                	sd	s1,40(sp)
    80001018:	f04a                	sd	s2,32(sp)
    8000101a:	ec4e                	sd	s3,24(sp)
    8000101c:	e852                	sd	s4,16(sp)
    8000101e:	e456                	sd	s5,8(sp)
    80001020:	e05a                	sd	s6,0(sp)
    80001022:	0080                	addi	s0,sp,64
    80001024:	84aa                	mv	s1,a0
    80001026:	89ae                	mv	s3,a1
    80001028:	8ab2                	mv	s5,a2
  if(va >= MAXVA)
    8000102a:	57fd                	li	a5,-1
    8000102c:	83e9                	srli	a5,a5,0x1a
    8000102e:	4a79                	li	s4,30
    panic("walk");

  for(int level = 2; level > 0; level--) {
    80001030:	4b31                	li	s6,12
  if(va >= MAXVA)
    80001032:	04b7f263          	bgeu	a5,a1,80001076 <walk+0x66>
    panic("walk");
    80001036:	00007517          	auipc	a0,0x7
    8000103a:	07a50513          	addi	a0,a0,122 # 800080b0 <etext+0xb0>
    8000103e:	fffff097          	auipc	ra,0xfffff
    80001042:	522080e7          	jalr	1314(ra) # 80000560 <panic>
    pte_t *pte = &pagetable[PX(level, va)];
    if(*pte & PTE_V) {
      pagetable = (pagetable_t)PTE2PA(*pte);
    } else {
      if(!alloc || (pagetable = (pde_t*)kalloc()) == 0)
    80001046:	060a8663          	beqz	s5,800010b2 <walk+0xa2>
    8000104a:	00000097          	auipc	ra,0x0
    8000104e:	afe080e7          	jalr	-1282(ra) # 80000b48 <kalloc>
    80001052:	84aa                	mv	s1,a0
    80001054:	c529                	beqz	a0,8000109e <walk+0x8e>
        return 0;
      memset(pagetable, 0, PGSIZE);
    80001056:	6605                	lui	a2,0x1
    80001058:	4581                	li	a1,0
    8000105a:	00000097          	auipc	ra,0x0
    8000105e:	cda080e7          	jalr	-806(ra) # 80000d34 <memset>
      *pte = PA2PTE(pagetable) | PTE_V;
    80001062:	00c4d793          	srli	a5,s1,0xc
    80001066:	07aa                	slli	a5,a5,0xa
    80001068:	0017e793          	ori	a5,a5,1
    8000106c:	00f93023          	sd	a5,0(s2)
  for(int level = 2; level > 0; level--) {
    80001070:	3a5d                	addiw	s4,s4,-9 # ffffffffffffeff7 <end+0xffffffff7ffd4297>
    80001072:	036a0063          	beq	s4,s6,80001092 <walk+0x82>
    pte_t *pte = &pagetable[PX(level, va)];
    80001076:	0149d933          	srl	s2,s3,s4
    8000107a:	1ff97913          	andi	s2,s2,511
    8000107e:	090e                	slli	s2,s2,0x3
    80001080:	9926                	add	s2,s2,s1
    if(*pte & PTE_V) {
    80001082:	00093483          	ld	s1,0(s2)
    80001086:	0014f793          	andi	a5,s1,1
    8000108a:	dfd5                	beqz	a5,80001046 <walk+0x36>
      pagetable = (pagetable_t)PTE2PA(*pte);
    8000108c:	80a9                	srli	s1,s1,0xa
    8000108e:	04b2                	slli	s1,s1,0xc
    80001090:	b7c5                	j	80001070 <walk+0x60>
    }
  }
  return &pagetable[PX(0, va)];
    80001092:	00c9d513          	srli	a0,s3,0xc
    80001096:	1ff57513          	andi	a0,a0,511
    8000109a:	050e                	slli	a0,a0,0x3
    8000109c:	9526                	add	a0,a0,s1
}
    8000109e:	70e2                	ld	ra,56(sp)
    800010a0:	7442                	ld	s0,48(sp)
    800010a2:	74a2                	ld	s1,40(sp)
    800010a4:	7902                	ld	s2,32(sp)
    800010a6:	69e2                	ld	s3,24(sp)
    800010a8:	6a42                	ld	s4,16(sp)
    800010aa:	6aa2                	ld	s5,8(sp)
    800010ac:	6b02                	ld	s6,0(sp)
    800010ae:	6121                	addi	sp,sp,64
    800010b0:	8082                	ret
        return 0;
    800010b2:	4501                	li	a0,0
    800010b4:	b7ed                	j	8000109e <walk+0x8e>

00000000800010b6 <walkaddr>:
walkaddr(pagetable_t pagetable, uint64 va)
{
  pte_t *pte;
  uint64 pa;

  if(va >= MAXVA)
    800010b6:	57fd                	li	a5,-1
    800010b8:	83e9                	srli	a5,a5,0x1a
    800010ba:	00b7f463          	bgeu	a5,a1,800010c2 <walkaddr+0xc>
    return 0;
    800010be:	4501                	li	a0,0
    return 0;
  if((*pte & PTE_U) == 0)
    return 0;
  pa = PTE2PA(*pte);
  return pa;
}
    800010c0:	8082                	ret
{
    800010c2:	1141                	addi	sp,sp,-16
    800010c4:	e406                	sd	ra,8(sp)
    800010c6:	e022                	sd	s0,0(sp)
    800010c8:	0800                	addi	s0,sp,16
  pte = walk(pagetable, va, 0);
    800010ca:	4601                	li	a2,0
    800010cc:	00000097          	auipc	ra,0x0
    800010d0:	f44080e7          	jalr	-188(ra) # 80001010 <walk>
  if(pte == 0)
    800010d4:	c105                	beqz	a0,800010f4 <walkaddr+0x3e>
  if((*pte & PTE_V) == 0)
    800010d6:	611c                	ld	a5,0(a0)
  if((*pte & PTE_U) == 0)
    800010d8:	0117f693          	andi	a3,a5,17
    800010dc:	4745                	li	a4,17
    return 0;
    800010de:	4501                	li	a0,0
  if((*pte & PTE_U) == 0)
    800010e0:	00e68663          	beq	a3,a4,800010ec <walkaddr+0x36>
}
    800010e4:	60a2                	ld	ra,8(sp)
    800010e6:	6402                	ld	s0,0(sp)
    800010e8:	0141                	addi	sp,sp,16
    800010ea:	8082                	ret
  pa = PTE2PA(*pte);
    800010ec:	83a9                	srli	a5,a5,0xa
    800010ee:	00c79513          	slli	a0,a5,0xc
  return pa;
    800010f2:	bfcd                	j	800010e4 <walkaddr+0x2e>
    return 0;
    800010f4:	4501                	li	a0,0
    800010f6:	b7fd                	j	800010e4 <walkaddr+0x2e>

00000000800010f8 <mappages>:
// physical addresses starting at pa. va and size might not
// be page-aligned. Returns 0 on success, -1 if walk() couldn't
// allocate a needed page-table page.
int
mappages(pagetable_t pagetable, uint64 va, uint64 size, uint64 pa, int perm)
{
    800010f8:	715d                	addi	sp,sp,-80
    800010fa:	e486                	sd	ra,72(sp)
    800010fc:	e0a2                	sd	s0,64(sp)
    800010fe:	fc26                	sd	s1,56(sp)
    80001100:	f84a                	sd	s2,48(sp)
    80001102:	f44e                	sd	s3,40(sp)
    80001104:	f052                	sd	s4,32(sp)
    80001106:	ec56                	sd	s5,24(sp)
    80001108:	e85a                	sd	s6,16(sp)
    8000110a:	e45e                	sd	s7,8(sp)
    8000110c:	0880                	addi	s0,sp,80
  uint64 a, last;
  pte_t *pte;

  if(size == 0)
    8000110e:	c639                	beqz	a2,8000115c <mappages+0x64>
    80001110:	8aaa                	mv	s5,a0
    80001112:	8b3a                	mv	s6,a4
    panic("mappages: size");
  
  a = PGROUNDDOWN(va);
    80001114:	777d                	lui	a4,0xfffff
    80001116:	00e5f7b3          	and	a5,a1,a4
  last = PGROUNDDOWN(va + size - 1);
    8000111a:	fff58993          	addi	s3,a1,-1
    8000111e:	99b2                	add	s3,s3,a2
    80001120:	00e9f9b3          	and	s3,s3,a4
  a = PGROUNDDOWN(va);
    80001124:	893e                	mv	s2,a5
    80001126:	40f68a33          	sub	s4,a3,a5
    if(*pte & PTE_V)
      panic("mappages: remap");
    *pte = PA2PTE(pa) | perm | PTE_V;
    if(a == last)
      break;
    a += PGSIZE;
    8000112a:	6b85                	lui	s7,0x1
    8000112c:	014904b3          	add	s1,s2,s4
    if((pte = walk(pagetable, a, 1)) == 0)
    80001130:	4605                	li	a2,1
    80001132:	85ca                	mv	a1,s2
    80001134:	8556                	mv	a0,s5
    80001136:	00000097          	auipc	ra,0x0
    8000113a:	eda080e7          	jalr	-294(ra) # 80001010 <walk>
    8000113e:	cd1d                	beqz	a0,8000117c <mappages+0x84>
    if(*pte & PTE_V)
    80001140:	611c                	ld	a5,0(a0)
    80001142:	8b85                	andi	a5,a5,1
    80001144:	e785                	bnez	a5,8000116c <mappages+0x74>
    *pte = PA2PTE(pa) | perm | PTE_V;
    80001146:	80b1                	srli	s1,s1,0xc
    80001148:	04aa                	slli	s1,s1,0xa
    8000114a:	0164e4b3          	or	s1,s1,s6
    8000114e:	0014e493          	ori	s1,s1,1
    80001152:	e104                	sd	s1,0(a0)
    if(a == last)
    80001154:	05390063          	beq	s2,s3,80001194 <mappages+0x9c>
    a += PGSIZE;
    80001158:	995e                	add	s2,s2,s7
    if((pte = walk(pagetable, a, 1)) == 0)
    8000115a:	bfc9                	j	8000112c <mappages+0x34>
    panic("mappages: size");
    8000115c:	00007517          	auipc	a0,0x7
    80001160:	f5c50513          	addi	a0,a0,-164 # 800080b8 <etext+0xb8>
    80001164:	fffff097          	auipc	ra,0xfffff
    80001168:	3fc080e7          	jalr	1020(ra) # 80000560 <panic>
      panic("mappages: remap");
    8000116c:	00007517          	auipc	a0,0x7
    80001170:	f5c50513          	addi	a0,a0,-164 # 800080c8 <etext+0xc8>
    80001174:	fffff097          	auipc	ra,0xfffff
    80001178:	3ec080e7          	jalr	1004(ra) # 80000560 <panic>
      return -1;
    8000117c:	557d                	li	a0,-1
    pa += PGSIZE;
  }
  return 0;
}
    8000117e:	60a6                	ld	ra,72(sp)
    80001180:	6406                	ld	s0,64(sp)
    80001182:	74e2                	ld	s1,56(sp)
    80001184:	7942                	ld	s2,48(sp)
    80001186:	79a2                	ld	s3,40(sp)
    80001188:	7a02                	ld	s4,32(sp)
    8000118a:	6ae2                	ld	s5,24(sp)
    8000118c:	6b42                	ld	s6,16(sp)
    8000118e:	6ba2                	ld	s7,8(sp)
    80001190:	6161                	addi	sp,sp,80
    80001192:	8082                	ret
  return 0;
    80001194:	4501                	li	a0,0
    80001196:	b7e5                	j	8000117e <mappages+0x86>

0000000080001198 <kvmmap>:
{
    80001198:	1141                	addi	sp,sp,-16
    8000119a:	e406                	sd	ra,8(sp)
    8000119c:	e022                	sd	s0,0(sp)
    8000119e:	0800                	addi	s0,sp,16
    800011a0:	87b6                	mv	a5,a3
  if(mappages(kpgtbl, va, sz, pa, perm) != 0)
    800011a2:	86b2                	mv	a3,a2
    800011a4:	863e                	mv	a2,a5
    800011a6:	00000097          	auipc	ra,0x0
    800011aa:	f52080e7          	jalr	-174(ra) # 800010f8 <mappages>
    800011ae:	e509                	bnez	a0,800011b8 <kvmmap+0x20>
}
    800011b0:	60a2                	ld	ra,8(sp)
    800011b2:	6402                	ld	s0,0(sp)
    800011b4:	0141                	addi	sp,sp,16
    800011b6:	8082                	ret
    panic("kvmmap");
    800011b8:	00007517          	auipc	a0,0x7
    800011bc:	f2050513          	addi	a0,a0,-224 # 800080d8 <etext+0xd8>
    800011c0:	fffff097          	auipc	ra,0xfffff
    800011c4:	3a0080e7          	jalr	928(ra) # 80000560 <panic>

00000000800011c8 <kvmmake>:
{
    800011c8:	1101                	addi	sp,sp,-32
    800011ca:	ec06                	sd	ra,24(sp)
    800011cc:	e822                	sd	s0,16(sp)
    800011ce:	e426                	sd	s1,8(sp)
    800011d0:	e04a                	sd	s2,0(sp)
    800011d2:	1000                	addi	s0,sp,32
  kpgtbl = (pagetable_t) kalloc();
    800011d4:	00000097          	auipc	ra,0x0
    800011d8:	974080e7          	jalr	-1676(ra) # 80000b48 <kalloc>
    800011dc:	84aa                	mv	s1,a0
  memset(kpgtbl, 0, PGSIZE);
    800011de:	6605                	lui	a2,0x1
    800011e0:	4581                	li	a1,0
    800011e2:	00000097          	auipc	ra,0x0
    800011e6:	b52080e7          	jalr	-1198(ra) # 80000d34 <memset>
  kvmmap(kpgtbl, UART0, UART0, PGSIZE, PTE_R | PTE_W);
    800011ea:	4719                	li	a4,6
    800011ec:	6685                	lui	a3,0x1
    800011ee:	10000637          	lui	a2,0x10000
    800011f2:	100005b7          	lui	a1,0x10000
    800011f6:	8526                	mv	a0,s1
    800011f8:	00000097          	auipc	ra,0x0
    800011fc:	fa0080e7          	jalr	-96(ra) # 80001198 <kvmmap>
  kvmmap(kpgtbl, VIRTIO0, VIRTIO0, PGSIZE, PTE_R | PTE_W);
    80001200:	4719                	li	a4,6
    80001202:	6685                	lui	a3,0x1
    80001204:	10001637          	lui	a2,0x10001
    80001208:	100015b7          	lui	a1,0x10001
    8000120c:	8526                	mv	a0,s1
    8000120e:	00000097          	auipc	ra,0x0
    80001212:	f8a080e7          	jalr	-118(ra) # 80001198 <kvmmap>
  kvmmap(kpgtbl, PLIC, PLIC, 0x400000, PTE_R | PTE_W);
    80001216:	4719                	li	a4,6
    80001218:	004006b7          	lui	a3,0x400
    8000121c:	0c000637          	lui	a2,0xc000
    80001220:	0c0005b7          	lui	a1,0xc000
    80001224:	8526                	mv	a0,s1
    80001226:	00000097          	auipc	ra,0x0
    8000122a:	f72080e7          	jalr	-142(ra) # 80001198 <kvmmap>
  kvmmap(kpgtbl, KERNBASE, KERNBASE, (uint64)etext-KERNBASE, PTE_R | PTE_X);
    8000122e:	00007917          	auipc	s2,0x7
    80001232:	dd290913          	addi	s2,s2,-558 # 80008000 <etext>
    80001236:	4729                	li	a4,10
    80001238:	80007697          	auipc	a3,0x80007
    8000123c:	dc868693          	addi	a3,a3,-568 # 8000 <_entry-0x7fff8000>
    80001240:	4605                	li	a2,1
    80001242:	067e                	slli	a2,a2,0x1f
    80001244:	85b2                	mv	a1,a2
    80001246:	8526                	mv	a0,s1
    80001248:	00000097          	auipc	ra,0x0
    8000124c:	f50080e7          	jalr	-176(ra) # 80001198 <kvmmap>
  kvmmap(kpgtbl, (uint64)etext, (uint64)etext, PHYSTOP-(uint64)etext, PTE_R | PTE_W);
    80001250:	46c5                	li	a3,17
    80001252:	06ee                	slli	a3,a3,0x1b
    80001254:	4719                	li	a4,6
    80001256:	412686b3          	sub	a3,a3,s2
    8000125a:	864a                	mv	a2,s2
    8000125c:	85ca                	mv	a1,s2
    8000125e:	8526                	mv	a0,s1
    80001260:	00000097          	auipc	ra,0x0
    80001264:	f38080e7          	jalr	-200(ra) # 80001198 <kvmmap>
  kvmmap(kpgtbl, TRAMPOLINE, (uint64)trampoline, PGSIZE, PTE_R | PTE_X);
    80001268:	4729                	li	a4,10
    8000126a:	6685                	lui	a3,0x1
    8000126c:	00006617          	auipc	a2,0x6
    80001270:	d9460613          	addi	a2,a2,-620 # 80007000 <_trampoline>
    80001274:	040005b7          	lui	a1,0x4000
    80001278:	15fd                	addi	a1,a1,-1 # 3ffffff <_entry-0x7c000001>
    8000127a:	05b2                	slli	a1,a1,0xc
    8000127c:	8526                	mv	a0,s1
    8000127e:	00000097          	auipc	ra,0x0
    80001282:	f1a080e7          	jalr	-230(ra) # 80001198 <kvmmap>
  proc_mapstacks(kpgtbl);
    80001286:	8526                	mv	a0,s1
    80001288:	00001097          	auipc	ra,0x1
    8000128c:	822080e7          	jalr	-2014(ra) # 80001aaa <proc_mapstacks>
}
    80001290:	8526                	mv	a0,s1
    80001292:	60e2                	ld	ra,24(sp)
    80001294:	6442                	ld	s0,16(sp)
    80001296:	64a2                	ld	s1,8(sp)
    80001298:	6902                	ld	s2,0(sp)
    8000129a:	6105                	addi	sp,sp,32
    8000129c:	8082                	ret

000000008000129e <kvminit>:
{
    8000129e:	1141                	addi	sp,sp,-16
    800012a0:	e406                	sd	ra,8(sp)
    800012a2:	e022                	sd	s0,0(sp)
    800012a4:	0800                	addi	s0,sp,16
  kernel_pagetable = kvmmake();
    800012a6:	00000097          	auipc	ra,0x0
    800012aa:	f22080e7          	jalr	-222(ra) # 800011c8 <kvmmake>
    800012ae:	00007797          	auipc	a5,0x7
    800012b2:	62a7b123          	sd	a0,1570(a5) # 800088d0 <kernel_pagetable>
}
    800012b6:	60a2                	ld	ra,8(sp)
    800012b8:	6402                	ld	s0,0(sp)
    800012ba:	0141                	addi	sp,sp,16
    800012bc:	8082                	ret

00000000800012be <uvmunmap>:
// Remove npages of mappings starting from va. va must be
// page-aligned. The mappings must exist.
// Optionally free the physical memory.
void
uvmunmap(pagetable_t pagetable, uint64 va, uint64 npages, int do_free)
{
    800012be:	715d                	addi	sp,sp,-80
    800012c0:	e486                	sd	ra,72(sp)
    800012c2:	e0a2                	sd	s0,64(sp)
    800012c4:	0880                	addi	s0,sp,80
  uint64 a;
  pte_t *pte;

  if((va % PGSIZE) != 0)
    800012c6:	03459793          	slli	a5,a1,0x34
    800012ca:	e39d                	bnez	a5,800012f0 <uvmunmap+0x32>
    800012cc:	f84a                	sd	s2,48(sp)
    800012ce:	f44e                	sd	s3,40(sp)
    800012d0:	f052                	sd	s4,32(sp)
    800012d2:	ec56                	sd	s5,24(sp)
    800012d4:	e85a                	sd	s6,16(sp)
    800012d6:	e45e                	sd	s7,8(sp)
    800012d8:	8a2a                	mv	s4,a0
    800012da:	892e                	mv	s2,a1
    800012dc:	8ab6                	mv	s5,a3
    panic("uvmunmap: not aligned");

  for(a = va; a < va + npages*PGSIZE; a += PGSIZE){
    800012de:	0632                	slli	a2,a2,0xc
    800012e0:	00b609b3          	add	s3,a2,a1
    if((pte = walk(pagetable, a, 0)) == 0)
      panic("uvmunmap: walk");
    if((*pte & PTE_V) == 0)
      panic("uvmunmap: not mapped");
    if(PTE_FLAGS(*pte) == PTE_V)
    800012e4:	4b85                	li	s7,1
  for(a = va; a < va + npages*PGSIZE; a += PGSIZE){
    800012e6:	6b05                	lui	s6,0x1
    800012e8:	0935fb63          	bgeu	a1,s3,8000137e <uvmunmap+0xc0>
    800012ec:	fc26                	sd	s1,56(sp)
    800012ee:	a8a9                	j	80001348 <uvmunmap+0x8a>
    800012f0:	fc26                	sd	s1,56(sp)
    800012f2:	f84a                	sd	s2,48(sp)
    800012f4:	f44e                	sd	s3,40(sp)
    800012f6:	f052                	sd	s4,32(sp)
    800012f8:	ec56                	sd	s5,24(sp)
    800012fa:	e85a                	sd	s6,16(sp)
    800012fc:	e45e                	sd	s7,8(sp)
    panic("uvmunmap: not aligned");
    800012fe:	00007517          	auipc	a0,0x7
    80001302:	de250513          	addi	a0,a0,-542 # 800080e0 <etext+0xe0>
    80001306:	fffff097          	auipc	ra,0xfffff
    8000130a:	25a080e7          	jalr	602(ra) # 80000560 <panic>
      panic("uvmunmap: walk");
    8000130e:	00007517          	auipc	a0,0x7
    80001312:	dea50513          	addi	a0,a0,-534 # 800080f8 <etext+0xf8>
    80001316:	fffff097          	auipc	ra,0xfffff
    8000131a:	24a080e7          	jalr	586(ra) # 80000560 <panic>
      panic("uvmunmap: not mapped");
    8000131e:	00007517          	auipc	a0,0x7
    80001322:	dea50513          	addi	a0,a0,-534 # 80008108 <etext+0x108>
    80001326:	fffff097          	auipc	ra,0xfffff
    8000132a:	23a080e7          	jalr	570(ra) # 80000560 <panic>
      panic("uvmunmap: not a leaf");
    8000132e:	00007517          	auipc	a0,0x7
    80001332:	df250513          	addi	a0,a0,-526 # 80008120 <etext+0x120>
    80001336:	fffff097          	auipc	ra,0xfffff
    8000133a:	22a080e7          	jalr	554(ra) # 80000560 <panic>
    if(do_free){
      uint64 pa = PTE2PA(*pte);
      kfree((void*)pa);
    }
    *pte = 0;
    8000133e:	0004b023          	sd	zero,0(s1)
  for(a = va; a < va + npages*PGSIZE; a += PGSIZE){
    80001342:	995a                	add	s2,s2,s6
    80001344:	03397c63          	bgeu	s2,s3,8000137c <uvmunmap+0xbe>
    if((pte = walk(pagetable, a, 0)) == 0)
    80001348:	4601                	li	a2,0
    8000134a:	85ca                	mv	a1,s2
    8000134c:	8552                	mv	a0,s4
    8000134e:	00000097          	auipc	ra,0x0
    80001352:	cc2080e7          	jalr	-830(ra) # 80001010 <walk>
    80001356:	84aa                	mv	s1,a0
    80001358:	d95d                	beqz	a0,8000130e <uvmunmap+0x50>
    if((*pte & PTE_V) == 0)
    8000135a:	6108                	ld	a0,0(a0)
    8000135c:	00157793          	andi	a5,a0,1
    80001360:	dfdd                	beqz	a5,8000131e <uvmunmap+0x60>
    if(PTE_FLAGS(*pte) == PTE_V)
    80001362:	3ff57793          	andi	a5,a0,1023
    80001366:	fd7784e3          	beq	a5,s7,8000132e <uvmunmap+0x70>
    if(do_free){
    8000136a:	fc0a8ae3          	beqz	s5,8000133e <uvmunmap+0x80>
      uint64 pa = PTE2PA(*pte);
    8000136e:	8129                	srli	a0,a0,0xa
      kfree((void*)pa);
    80001370:	0532                	slli	a0,a0,0xc
    80001372:	fffff097          	auipc	ra,0xfffff
    80001376:	6d8080e7          	jalr	1752(ra) # 80000a4a <kfree>
    8000137a:	b7d1                	j	8000133e <uvmunmap+0x80>
    8000137c:	74e2                	ld	s1,56(sp)
    8000137e:	7942                	ld	s2,48(sp)
    80001380:	79a2                	ld	s3,40(sp)
    80001382:	7a02                	ld	s4,32(sp)
    80001384:	6ae2                	ld	s5,24(sp)
    80001386:	6b42                	ld	s6,16(sp)
    80001388:	6ba2                	ld	s7,8(sp)
  }
}
    8000138a:	60a6                	ld	ra,72(sp)
    8000138c:	6406                	ld	s0,64(sp)
    8000138e:	6161                	addi	sp,sp,80
    80001390:	8082                	ret

0000000080001392 <uvmcreate>:

// create an empty user page table.
// returns 0 if out of memory.
pagetable_t
uvmcreate()
{
    80001392:	1101                	addi	sp,sp,-32
    80001394:	ec06                	sd	ra,24(sp)
    80001396:	e822                	sd	s0,16(sp)
    80001398:	e426                	sd	s1,8(sp)
    8000139a:	1000                	addi	s0,sp,32
  pagetable_t pagetable;
  pagetable = (pagetable_t) kalloc();
    8000139c:	fffff097          	auipc	ra,0xfffff
    800013a0:	7ac080e7          	jalr	1964(ra) # 80000b48 <kalloc>
    800013a4:	84aa                	mv	s1,a0
  if(pagetable == 0)
    800013a6:	c519                	beqz	a0,800013b4 <uvmcreate+0x22>
    return 0;
  memset(pagetable, 0, PGSIZE);
    800013a8:	6605                	lui	a2,0x1
    800013aa:	4581                	li	a1,0
    800013ac:	00000097          	auipc	ra,0x0
    800013b0:	988080e7          	jalr	-1656(ra) # 80000d34 <memset>
  return pagetable;
}
    800013b4:	8526                	mv	a0,s1
    800013b6:	60e2                	ld	ra,24(sp)
    800013b8:	6442                	ld	s0,16(sp)
    800013ba:	64a2                	ld	s1,8(sp)
    800013bc:	6105                	addi	sp,sp,32
    800013be:	8082                	ret

00000000800013c0 <uvmfirst>:
// Load the user initcode into address 0 of pagetable,
// for the very first process.
// sz must be less than a page.
void
uvmfirst(pagetable_t pagetable, uchar *src, uint sz)
{
    800013c0:	7179                	addi	sp,sp,-48
    800013c2:	f406                	sd	ra,40(sp)
    800013c4:	f022                	sd	s0,32(sp)
    800013c6:	ec26                	sd	s1,24(sp)
    800013c8:	e84a                	sd	s2,16(sp)
    800013ca:	e44e                	sd	s3,8(sp)
    800013cc:	e052                	sd	s4,0(sp)
    800013ce:	1800                	addi	s0,sp,48
  char *mem;

  if(sz >= PGSIZE)
    800013d0:	6785                	lui	a5,0x1
    800013d2:	04f67863          	bgeu	a2,a5,80001422 <uvmfirst+0x62>
    800013d6:	8a2a                	mv	s4,a0
    800013d8:	89ae                	mv	s3,a1
    800013da:	84b2                	mv	s1,a2
    panic("uvmfirst: more than a page");
  mem = kalloc();
    800013dc:	fffff097          	auipc	ra,0xfffff
    800013e0:	76c080e7          	jalr	1900(ra) # 80000b48 <kalloc>
    800013e4:	892a                	mv	s2,a0
  memset(mem, 0, PGSIZE);
    800013e6:	6605                	lui	a2,0x1
    800013e8:	4581                	li	a1,0
    800013ea:	00000097          	auipc	ra,0x0
    800013ee:	94a080e7          	jalr	-1718(ra) # 80000d34 <memset>
  mappages(pagetable, 0, PGSIZE, (uint64)mem, PTE_W|PTE_R|PTE_X|PTE_U);
    800013f2:	4779                	li	a4,30
    800013f4:	86ca                	mv	a3,s2
    800013f6:	6605                	lui	a2,0x1
    800013f8:	4581                	li	a1,0
    800013fa:	8552                	mv	a0,s4
    800013fc:	00000097          	auipc	ra,0x0
    80001400:	cfc080e7          	jalr	-772(ra) # 800010f8 <mappages>
  memmove(mem, src, sz);
    80001404:	8626                	mv	a2,s1
    80001406:	85ce                	mv	a1,s3
    80001408:	854a                	mv	a0,s2
    8000140a:	00000097          	auipc	ra,0x0
    8000140e:	986080e7          	jalr	-1658(ra) # 80000d90 <memmove>
}
    80001412:	70a2                	ld	ra,40(sp)
    80001414:	7402                	ld	s0,32(sp)
    80001416:	64e2                	ld	s1,24(sp)
    80001418:	6942                	ld	s2,16(sp)
    8000141a:	69a2                	ld	s3,8(sp)
    8000141c:	6a02                	ld	s4,0(sp)
    8000141e:	6145                	addi	sp,sp,48
    80001420:	8082                	ret
    panic("uvmfirst: more than a page");
    80001422:	00007517          	auipc	a0,0x7
    80001426:	d1650513          	addi	a0,a0,-746 # 80008138 <etext+0x138>
    8000142a:	fffff097          	auipc	ra,0xfffff
    8000142e:	136080e7          	jalr	310(ra) # 80000560 <panic>

0000000080001432 <uvmdealloc>:
// newsz.  oldsz and newsz need not be page-aligned, nor does newsz
// need to be less than oldsz.  oldsz can be larger than the actual
// process size.  Returns the new process size.
uint64
uvmdealloc(pagetable_t pagetable, uint64 oldsz, uint64 newsz)
{
    80001432:	1101                	addi	sp,sp,-32
    80001434:	ec06                	sd	ra,24(sp)
    80001436:	e822                	sd	s0,16(sp)
    80001438:	e426                	sd	s1,8(sp)
    8000143a:	1000                	addi	s0,sp,32
  if(newsz >= oldsz)
    return oldsz;
    8000143c:	84ae                	mv	s1,a1
  if(newsz >= oldsz)
    8000143e:	00b67d63          	bgeu	a2,a1,80001458 <uvmdealloc+0x26>
    80001442:	84b2                	mv	s1,a2

  if(PGROUNDUP(newsz) < PGROUNDUP(oldsz)){
    80001444:	6785                	lui	a5,0x1
    80001446:	17fd                	addi	a5,a5,-1 # fff <_entry-0x7ffff001>
    80001448:	00f60733          	add	a4,a2,a5
    8000144c:	76fd                	lui	a3,0xfffff
    8000144e:	8f75                	and	a4,a4,a3
    80001450:	97ae                	add	a5,a5,a1
    80001452:	8ff5                	and	a5,a5,a3
    80001454:	00f76863          	bltu	a4,a5,80001464 <uvmdealloc+0x32>
    int npages = (PGROUNDUP(oldsz) - PGROUNDUP(newsz)) / PGSIZE;
    uvmunmap(pagetable, PGROUNDUP(newsz), npages, 1);
  }

  return newsz;
}
    80001458:	8526                	mv	a0,s1
    8000145a:	60e2                	ld	ra,24(sp)
    8000145c:	6442                	ld	s0,16(sp)
    8000145e:	64a2                	ld	s1,8(sp)
    80001460:	6105                	addi	sp,sp,32
    80001462:	8082                	ret
    int npages = (PGROUNDUP(oldsz) - PGROUNDUP(newsz)) / PGSIZE;
    80001464:	8f99                	sub	a5,a5,a4
    80001466:	83b1                	srli	a5,a5,0xc
    uvmunmap(pagetable, PGROUNDUP(newsz), npages, 1);
    80001468:	4685                	li	a3,1
    8000146a:	0007861b          	sext.w	a2,a5
    8000146e:	85ba                	mv	a1,a4
    80001470:	00000097          	auipc	ra,0x0
    80001474:	e4e080e7          	jalr	-434(ra) # 800012be <uvmunmap>
    80001478:	b7c5                	j	80001458 <uvmdealloc+0x26>

000000008000147a <uvmalloc>:
  if(newsz < oldsz)
    8000147a:	0ab66b63          	bltu	a2,a1,80001530 <uvmalloc+0xb6>
{
    8000147e:	7139                	addi	sp,sp,-64
    80001480:	fc06                	sd	ra,56(sp)
    80001482:	f822                	sd	s0,48(sp)
    80001484:	ec4e                	sd	s3,24(sp)
    80001486:	e852                	sd	s4,16(sp)
    80001488:	e456                	sd	s5,8(sp)
    8000148a:	0080                	addi	s0,sp,64
    8000148c:	8aaa                	mv	s5,a0
    8000148e:	8a32                	mv	s4,a2
  oldsz = PGROUNDUP(oldsz);
    80001490:	6785                	lui	a5,0x1
    80001492:	17fd                	addi	a5,a5,-1 # fff <_entry-0x7ffff001>
    80001494:	95be                	add	a1,a1,a5
    80001496:	77fd                	lui	a5,0xfffff
    80001498:	00f5f9b3          	and	s3,a1,a5
  for(a = oldsz; a < newsz; a += PGSIZE){
    8000149c:	08c9fc63          	bgeu	s3,a2,80001534 <uvmalloc+0xba>
    800014a0:	f426                	sd	s1,40(sp)
    800014a2:	f04a                	sd	s2,32(sp)
    800014a4:	e05a                	sd	s6,0(sp)
    800014a6:	894e                	mv	s2,s3
    if(mappages(pagetable, a, PGSIZE, (uint64)mem, PTE_R|PTE_U|xperm) != 0){
    800014a8:	0126eb13          	ori	s6,a3,18
    mem = kalloc();
    800014ac:	fffff097          	auipc	ra,0xfffff
    800014b0:	69c080e7          	jalr	1692(ra) # 80000b48 <kalloc>
    800014b4:	84aa                	mv	s1,a0
    if(mem == 0){
    800014b6:	c915                	beqz	a0,800014ea <uvmalloc+0x70>
    memset(mem, 0, PGSIZE);
    800014b8:	6605                	lui	a2,0x1
    800014ba:	4581                	li	a1,0
    800014bc:	00000097          	auipc	ra,0x0
    800014c0:	878080e7          	jalr	-1928(ra) # 80000d34 <memset>
    if(mappages(pagetable, a, PGSIZE, (uint64)mem, PTE_R|PTE_U|xperm) != 0){
    800014c4:	875a                	mv	a4,s6
    800014c6:	86a6                	mv	a3,s1
    800014c8:	6605                	lui	a2,0x1
    800014ca:	85ca                	mv	a1,s2
    800014cc:	8556                	mv	a0,s5
    800014ce:	00000097          	auipc	ra,0x0
    800014d2:	c2a080e7          	jalr	-982(ra) # 800010f8 <mappages>
    800014d6:	ed05                	bnez	a0,8000150e <uvmalloc+0x94>
  for(a = oldsz; a < newsz; a += PGSIZE){
    800014d8:	6785                	lui	a5,0x1
    800014da:	993e                	add	s2,s2,a5
    800014dc:	fd4968e3          	bltu	s2,s4,800014ac <uvmalloc+0x32>
  return newsz;
    800014e0:	8552                	mv	a0,s4
    800014e2:	74a2                	ld	s1,40(sp)
    800014e4:	7902                	ld	s2,32(sp)
    800014e6:	6b02                	ld	s6,0(sp)
    800014e8:	a821                	j	80001500 <uvmalloc+0x86>
      uvmdealloc(pagetable, a, oldsz);
    800014ea:	864e                	mv	a2,s3
    800014ec:	85ca                	mv	a1,s2
    800014ee:	8556                	mv	a0,s5
    800014f0:	00000097          	auipc	ra,0x0
    800014f4:	f42080e7          	jalr	-190(ra) # 80001432 <uvmdealloc>
      return 0;
    800014f8:	4501                	li	a0,0
    800014fa:	74a2                	ld	s1,40(sp)
    800014fc:	7902                	ld	s2,32(sp)
    800014fe:	6b02                	ld	s6,0(sp)
}
    80001500:	70e2                	ld	ra,56(sp)
    80001502:	7442                	ld	s0,48(sp)
    80001504:	69e2                	ld	s3,24(sp)
    80001506:	6a42                	ld	s4,16(sp)
    80001508:	6aa2                	ld	s5,8(sp)
    8000150a:	6121                	addi	sp,sp,64
    8000150c:	8082                	ret
      kfree(mem);
    8000150e:	8526                	mv	a0,s1
    80001510:	fffff097          	auipc	ra,0xfffff
    80001514:	53a080e7          	jalr	1338(ra) # 80000a4a <kfree>
      uvmdealloc(pagetable, a, oldsz);
    80001518:	864e                	mv	a2,s3
    8000151a:	85ca                	mv	a1,s2
    8000151c:	8556                	mv	a0,s5
    8000151e:	00000097          	auipc	ra,0x0
    80001522:	f14080e7          	jalr	-236(ra) # 80001432 <uvmdealloc>
      return 0;
    80001526:	4501                	li	a0,0
    80001528:	74a2                	ld	s1,40(sp)
    8000152a:	7902                	ld	s2,32(sp)
    8000152c:	6b02                	ld	s6,0(sp)
    8000152e:	bfc9                	j	80001500 <uvmalloc+0x86>
    return oldsz;
    80001530:	852e                	mv	a0,a1
}
    80001532:	8082                	ret
  return newsz;
    80001534:	8532                	mv	a0,a2
    80001536:	b7e9                	j	80001500 <uvmalloc+0x86>

0000000080001538 <freewalk>:

// Recursively free page-table pages.
// All leaf mappings must already have been removed.
void
freewalk(pagetable_t pagetable)
{
    80001538:	7179                	addi	sp,sp,-48
    8000153a:	f406                	sd	ra,40(sp)
    8000153c:	f022                	sd	s0,32(sp)
    8000153e:	ec26                	sd	s1,24(sp)
    80001540:	e84a                	sd	s2,16(sp)
    80001542:	e44e                	sd	s3,8(sp)
    80001544:	e052                	sd	s4,0(sp)
    80001546:	1800                	addi	s0,sp,48
    80001548:	8a2a                	mv	s4,a0
  // there are 2^9 = 512 PTEs in a page table.
  for(int i = 0; i < 512; i++){
    8000154a:	84aa                	mv	s1,a0
    8000154c:	6905                	lui	s2,0x1
    8000154e:	992a                	add	s2,s2,a0
    pte_t pte = pagetable[i];
    if((pte & PTE_V) && (pte & (PTE_R|PTE_W|PTE_X)) == 0){
    80001550:	4985                	li	s3,1
    80001552:	a829                	j	8000156c <freewalk+0x34>
      // this PTE points to a lower-level page table.
      uint64 child = PTE2PA(pte);
    80001554:	83a9                	srli	a5,a5,0xa
      freewalk((pagetable_t)child);
    80001556:	00c79513          	slli	a0,a5,0xc
    8000155a:	00000097          	auipc	ra,0x0
    8000155e:	fde080e7          	jalr	-34(ra) # 80001538 <freewalk>
      pagetable[i] = 0;
    80001562:	0004b023          	sd	zero,0(s1)
  for(int i = 0; i < 512; i++){
    80001566:	04a1                	addi	s1,s1,8
    80001568:	03248163          	beq	s1,s2,8000158a <freewalk+0x52>
    pte_t pte = pagetable[i];
    8000156c:	609c                	ld	a5,0(s1)
    if((pte & PTE_V) && (pte & (PTE_R|PTE_W|PTE_X)) == 0){
    8000156e:	00f7f713          	andi	a4,a5,15
    80001572:	ff3701e3          	beq	a4,s3,80001554 <freewalk+0x1c>
    } else if(pte & PTE_V){
    80001576:	8b85                	andi	a5,a5,1
    80001578:	d7fd                	beqz	a5,80001566 <freewalk+0x2e>
      panic("freewalk: leaf");
    8000157a:	00007517          	auipc	a0,0x7
    8000157e:	bde50513          	addi	a0,a0,-1058 # 80008158 <etext+0x158>
    80001582:	fffff097          	auipc	ra,0xfffff
    80001586:	fde080e7          	jalr	-34(ra) # 80000560 <panic>
    }
  }
  kfree((void*)pagetable);
    8000158a:	8552                	mv	a0,s4
    8000158c:	fffff097          	auipc	ra,0xfffff
    80001590:	4be080e7          	jalr	1214(ra) # 80000a4a <kfree>
}
    80001594:	70a2                	ld	ra,40(sp)
    80001596:	7402                	ld	s0,32(sp)
    80001598:	64e2                	ld	s1,24(sp)
    8000159a:	6942                	ld	s2,16(sp)
    8000159c:	69a2                	ld	s3,8(sp)
    8000159e:	6a02                	ld	s4,0(sp)
    800015a0:	6145                	addi	sp,sp,48
    800015a2:	8082                	ret

00000000800015a4 <uvmfree>:

// Free user memory pages,
// then free page-table pages.
void
uvmfree(pagetable_t pagetable, uint64 sz)
{
    800015a4:	1101                	addi	sp,sp,-32
    800015a6:	ec06                	sd	ra,24(sp)
    800015a8:	e822                	sd	s0,16(sp)
    800015aa:	e426                	sd	s1,8(sp)
    800015ac:	1000                	addi	s0,sp,32
    800015ae:	84aa                	mv	s1,a0
  if(sz > 0)
    800015b0:	e999                	bnez	a1,800015c6 <uvmfree+0x22>
    uvmunmap(pagetable, 0, PGROUNDUP(sz)/PGSIZE, 1);
  freewalk(pagetable);
    800015b2:	8526                	mv	a0,s1
    800015b4:	00000097          	auipc	ra,0x0
    800015b8:	f84080e7          	jalr	-124(ra) # 80001538 <freewalk>
}
    800015bc:	60e2                	ld	ra,24(sp)
    800015be:	6442                	ld	s0,16(sp)
    800015c0:	64a2                	ld	s1,8(sp)
    800015c2:	6105                	addi	sp,sp,32
    800015c4:	8082                	ret
    uvmunmap(pagetable, 0, PGROUNDUP(sz)/PGSIZE, 1);
    800015c6:	6785                	lui	a5,0x1
    800015c8:	17fd                	addi	a5,a5,-1 # fff <_entry-0x7ffff001>
    800015ca:	95be                	add	a1,a1,a5
    800015cc:	4685                	li	a3,1
    800015ce:	00c5d613          	srli	a2,a1,0xc
    800015d2:	4581                	li	a1,0
    800015d4:	00000097          	auipc	ra,0x0
    800015d8:	cea080e7          	jalr	-790(ra) # 800012be <uvmunmap>
    800015dc:	bfd9                	j	800015b2 <uvmfree+0xe>

00000000800015de <uvmcopy>:
  pte_t *pte;
  uint64 pa, i;
  uint flags;
  char *mem;

  for(i = 0; i < sz; i += PGSIZE){
    800015de:	c679                	beqz	a2,800016ac <uvmcopy+0xce>
{
    800015e0:	715d                	addi	sp,sp,-80
    800015e2:	e486                	sd	ra,72(sp)
    800015e4:	e0a2                	sd	s0,64(sp)
    800015e6:	fc26                	sd	s1,56(sp)
    800015e8:	f84a                	sd	s2,48(sp)
    800015ea:	f44e                	sd	s3,40(sp)
    800015ec:	f052                	sd	s4,32(sp)
    800015ee:	ec56                	sd	s5,24(sp)
    800015f0:	e85a                	sd	s6,16(sp)
    800015f2:	e45e                	sd	s7,8(sp)
    800015f4:	0880                	addi	s0,sp,80
    800015f6:	8b2a                	mv	s6,a0
    800015f8:	8aae                	mv	s5,a1
    800015fa:	8a32                	mv	s4,a2
  for(i = 0; i < sz; i += PGSIZE){
    800015fc:	4981                	li	s3,0
    if((pte = walk(old, i, 0)) == 0)
    800015fe:	4601                	li	a2,0
    80001600:	85ce                	mv	a1,s3
    80001602:	855a                	mv	a0,s6
    80001604:	00000097          	auipc	ra,0x0
    80001608:	a0c080e7          	jalr	-1524(ra) # 80001010 <walk>
    8000160c:	c531                	beqz	a0,80001658 <uvmcopy+0x7a>
      panic("uvmcopy: pte should exist");
    if((*pte & PTE_V) == 0)
    8000160e:	6118                	ld	a4,0(a0)
    80001610:	00177793          	andi	a5,a4,1
    80001614:	cbb1                	beqz	a5,80001668 <uvmcopy+0x8a>
      panic("uvmcopy: page not present");
    pa = PTE2PA(*pte);
    80001616:	00a75593          	srli	a1,a4,0xa
    8000161a:	00c59b93          	slli	s7,a1,0xc
    flags = PTE_FLAGS(*pte);
    8000161e:	3ff77493          	andi	s1,a4,1023
    if((mem = kalloc()) == 0)
    80001622:	fffff097          	auipc	ra,0xfffff
    80001626:	526080e7          	jalr	1318(ra) # 80000b48 <kalloc>
    8000162a:	892a                	mv	s2,a0
    8000162c:	c939                	beqz	a0,80001682 <uvmcopy+0xa4>
      goto err;
    memmove(mem, (char*)pa, PGSIZE);
    8000162e:	6605                	lui	a2,0x1
    80001630:	85de                	mv	a1,s7
    80001632:	fffff097          	auipc	ra,0xfffff
    80001636:	75e080e7          	jalr	1886(ra) # 80000d90 <memmove>
    if(mappages(new, i, PGSIZE, (uint64)mem, flags) != 0){
    8000163a:	8726                	mv	a4,s1
    8000163c:	86ca                	mv	a3,s2
    8000163e:	6605                	lui	a2,0x1
    80001640:	85ce                	mv	a1,s3
    80001642:	8556                	mv	a0,s5
    80001644:	00000097          	auipc	ra,0x0
    80001648:	ab4080e7          	jalr	-1356(ra) # 800010f8 <mappages>
    8000164c:	e515                	bnez	a0,80001678 <uvmcopy+0x9a>
  for(i = 0; i < sz; i += PGSIZE){
    8000164e:	6785                	lui	a5,0x1
    80001650:	99be                	add	s3,s3,a5
    80001652:	fb49e6e3          	bltu	s3,s4,800015fe <uvmcopy+0x20>
    80001656:	a081                	j	80001696 <uvmcopy+0xb8>
      panic("uvmcopy: pte should exist");
    80001658:	00007517          	auipc	a0,0x7
    8000165c:	b1050513          	addi	a0,a0,-1264 # 80008168 <etext+0x168>
    80001660:	fffff097          	auipc	ra,0xfffff
    80001664:	f00080e7          	jalr	-256(ra) # 80000560 <panic>
      panic("uvmcopy: page not present");
    80001668:	00007517          	auipc	a0,0x7
    8000166c:	b2050513          	addi	a0,a0,-1248 # 80008188 <etext+0x188>
    80001670:	fffff097          	auipc	ra,0xfffff
    80001674:	ef0080e7          	jalr	-272(ra) # 80000560 <panic>
      kfree(mem);
    80001678:	854a                	mv	a0,s2
    8000167a:	fffff097          	auipc	ra,0xfffff
    8000167e:	3d0080e7          	jalr	976(ra) # 80000a4a <kfree>
    }
  }
  return 0;

 err:
  uvmunmap(new, 0, i / PGSIZE, 1);
    80001682:	4685                	li	a3,1
    80001684:	00c9d613          	srli	a2,s3,0xc
    80001688:	4581                	li	a1,0
    8000168a:	8556                	mv	a0,s5
    8000168c:	00000097          	auipc	ra,0x0
    80001690:	c32080e7          	jalr	-974(ra) # 800012be <uvmunmap>
  return -1;
    80001694:	557d                	li	a0,-1
}
    80001696:	60a6                	ld	ra,72(sp)
    80001698:	6406                	ld	s0,64(sp)
    8000169a:	74e2                	ld	s1,56(sp)
    8000169c:	7942                	ld	s2,48(sp)
    8000169e:	79a2                	ld	s3,40(sp)
    800016a0:	7a02                	ld	s4,32(sp)
    800016a2:	6ae2                	ld	s5,24(sp)
    800016a4:	6b42                	ld	s6,16(sp)
    800016a6:	6ba2                	ld	s7,8(sp)
    800016a8:	6161                	addi	sp,sp,80
    800016aa:	8082                	ret
  return 0;
    800016ac:	4501                	li	a0,0
}
    800016ae:	8082                	ret

00000000800016b0 <uvmclear>:

// mark a PTE invalid for user access.
// used by exec for the user stack guard page.
void
uvmclear(pagetable_t pagetable, uint64 va)
{
    800016b0:	1141                	addi	sp,sp,-16
    800016b2:	e406                	sd	ra,8(sp)
    800016b4:	e022                	sd	s0,0(sp)
    800016b6:	0800                	addi	s0,sp,16
  pte_t *pte;
  
  pte = walk(pagetable, va, 0);
    800016b8:	4601                	li	a2,0
    800016ba:	00000097          	auipc	ra,0x0
    800016be:	956080e7          	jalr	-1706(ra) # 80001010 <walk>
  if(pte == 0)
    800016c2:	c901                	beqz	a0,800016d2 <uvmclear+0x22>
    panic("uvmclear");
  *pte &= ~PTE_U;
    800016c4:	611c                	ld	a5,0(a0)
    800016c6:	9bbd                	andi	a5,a5,-17
    800016c8:	e11c                	sd	a5,0(a0)
}
    800016ca:	60a2                	ld	ra,8(sp)
    800016cc:	6402                	ld	s0,0(sp)
    800016ce:	0141                	addi	sp,sp,16
    800016d0:	8082                	ret
    panic("uvmclear");
    800016d2:	00007517          	auipc	a0,0x7
    800016d6:	ad650513          	addi	a0,a0,-1322 # 800081a8 <etext+0x1a8>
    800016da:	fffff097          	auipc	ra,0xfffff
    800016de:	e86080e7          	jalr	-378(ra) # 80000560 <panic>

00000000800016e2 <copyout>:
int
copyout(pagetable_t pagetable, uint64 dstva, char *src, uint64 len)
{
  uint64 n, va0, pa0;

  while(len > 0){
    800016e2:	c6bd                	beqz	a3,80001750 <copyout+0x6e>
{
    800016e4:	715d                	addi	sp,sp,-80
    800016e6:	e486                	sd	ra,72(sp)
    800016e8:	e0a2                	sd	s0,64(sp)
    800016ea:	fc26                	sd	s1,56(sp)
    800016ec:	f84a                	sd	s2,48(sp)
    800016ee:	f44e                	sd	s3,40(sp)
    800016f0:	f052                	sd	s4,32(sp)
    800016f2:	ec56                	sd	s5,24(sp)
    800016f4:	e85a                	sd	s6,16(sp)
    800016f6:	e45e                	sd	s7,8(sp)
    800016f8:	e062                	sd	s8,0(sp)
    800016fa:	0880                	addi	s0,sp,80
    800016fc:	8b2a                	mv	s6,a0
    800016fe:	8c2e                	mv	s8,a1
    80001700:	8a32                	mv	s4,a2
    80001702:	89b6                	mv	s3,a3
    va0 = PGROUNDDOWN(dstva);
    80001704:	7bfd                	lui	s7,0xfffff
    pa0 = walkaddr(pagetable, va0);
    if(pa0 == 0)
      return -1;
    n = PGSIZE - (dstva - va0);
    80001706:	6a85                	lui	s5,0x1
    80001708:	a015                	j	8000172c <copyout+0x4a>
    if(n > len)
      n = len;
    memmove((void *)(pa0 + (dstva - va0)), src, n);
    8000170a:	9562                	add	a0,a0,s8
    8000170c:	0004861b          	sext.w	a2,s1
    80001710:	85d2                	mv	a1,s4
    80001712:	41250533          	sub	a0,a0,s2
    80001716:	fffff097          	auipc	ra,0xfffff
    8000171a:	67a080e7          	jalr	1658(ra) # 80000d90 <memmove>

    len -= n;
    8000171e:	409989b3          	sub	s3,s3,s1
    src += n;
    80001722:	9a26                	add	s4,s4,s1
    dstva = va0 + PGSIZE;
    80001724:	01590c33          	add	s8,s2,s5
  while(len > 0){
    80001728:	02098263          	beqz	s3,8000174c <copyout+0x6a>
    va0 = PGROUNDDOWN(dstva);
    8000172c:	017c7933          	and	s2,s8,s7
    pa0 = walkaddr(pagetable, va0);
    80001730:	85ca                	mv	a1,s2
    80001732:	855a                	mv	a0,s6
    80001734:	00000097          	auipc	ra,0x0
    80001738:	982080e7          	jalr	-1662(ra) # 800010b6 <walkaddr>
    if(pa0 == 0)
    8000173c:	cd01                	beqz	a0,80001754 <copyout+0x72>
    n = PGSIZE - (dstva - va0);
    8000173e:	418904b3          	sub	s1,s2,s8
    80001742:	94d6                	add	s1,s1,s5
    if(n > len)
    80001744:	fc99f3e3          	bgeu	s3,s1,8000170a <copyout+0x28>
    80001748:	84ce                	mv	s1,s3
    8000174a:	b7c1                	j	8000170a <copyout+0x28>
  }
  return 0;
    8000174c:	4501                	li	a0,0
    8000174e:	a021                	j	80001756 <copyout+0x74>
    80001750:	4501                	li	a0,0
}
    80001752:	8082                	ret
      return -1;
    80001754:	557d                	li	a0,-1
}
    80001756:	60a6                	ld	ra,72(sp)
    80001758:	6406                	ld	s0,64(sp)
    8000175a:	74e2                	ld	s1,56(sp)
    8000175c:	7942                	ld	s2,48(sp)
    8000175e:	79a2                	ld	s3,40(sp)
    80001760:	7a02                	ld	s4,32(sp)
    80001762:	6ae2                	ld	s5,24(sp)
    80001764:	6b42                	ld	s6,16(sp)
    80001766:	6ba2                	ld	s7,8(sp)
    80001768:	6c02                	ld	s8,0(sp)
    8000176a:	6161                	addi	sp,sp,80
    8000176c:	8082                	ret

000000008000176e <copyin>:
int
copyin(pagetable_t pagetable, char *dst, uint64 srcva, uint64 len)
{
  uint64 n, va0, pa0;

  while(len > 0){
    8000176e:	caa5                	beqz	a3,800017de <copyin+0x70>
{
    80001770:	715d                	addi	sp,sp,-80
    80001772:	e486                	sd	ra,72(sp)
    80001774:	e0a2                	sd	s0,64(sp)
    80001776:	fc26                	sd	s1,56(sp)
    80001778:	f84a                	sd	s2,48(sp)
    8000177a:	f44e                	sd	s3,40(sp)
    8000177c:	f052                	sd	s4,32(sp)
    8000177e:	ec56                	sd	s5,24(sp)
    80001780:	e85a                	sd	s6,16(sp)
    80001782:	e45e                	sd	s7,8(sp)
    80001784:	e062                	sd	s8,0(sp)
    80001786:	0880                	addi	s0,sp,80
    80001788:	8b2a                	mv	s6,a0
    8000178a:	8a2e                	mv	s4,a1
    8000178c:	8c32                	mv	s8,a2
    8000178e:	89b6                	mv	s3,a3
    va0 = PGROUNDDOWN(srcva);
    80001790:	7bfd                	lui	s7,0xfffff
    pa0 = walkaddr(pagetable, va0);
    if(pa0 == 0)
      return -1;
    n = PGSIZE - (srcva - va0);
    80001792:	6a85                	lui	s5,0x1
    80001794:	a01d                	j	800017ba <copyin+0x4c>
    if(n > len)
      n = len;
    memmove(dst, (void *)(pa0 + (srcva - va0)), n);
    80001796:	018505b3          	add	a1,a0,s8
    8000179a:	0004861b          	sext.w	a2,s1
    8000179e:	412585b3          	sub	a1,a1,s2
    800017a2:	8552                	mv	a0,s4
    800017a4:	fffff097          	auipc	ra,0xfffff
    800017a8:	5ec080e7          	jalr	1516(ra) # 80000d90 <memmove>

    len -= n;
    800017ac:	409989b3          	sub	s3,s3,s1
    dst += n;
    800017b0:	9a26                	add	s4,s4,s1
    srcva = va0 + PGSIZE;
    800017b2:	01590c33          	add	s8,s2,s5
  while(len > 0){
    800017b6:	02098263          	beqz	s3,800017da <copyin+0x6c>
    va0 = PGROUNDDOWN(srcva);
    800017ba:	017c7933          	and	s2,s8,s7
    pa0 = walkaddr(pagetable, va0);
    800017be:	85ca                	mv	a1,s2
    800017c0:	855a                	mv	a0,s6
    800017c2:	00000097          	auipc	ra,0x0
    800017c6:	8f4080e7          	jalr	-1804(ra) # 800010b6 <walkaddr>
    if(pa0 == 0)
    800017ca:	cd01                	beqz	a0,800017e2 <copyin+0x74>
    n = PGSIZE - (srcva - va0);
    800017cc:	418904b3          	sub	s1,s2,s8
    800017d0:	94d6                	add	s1,s1,s5
    if(n > len)
    800017d2:	fc99f2e3          	bgeu	s3,s1,80001796 <copyin+0x28>
    800017d6:	84ce                	mv	s1,s3
    800017d8:	bf7d                	j	80001796 <copyin+0x28>
  }
  return 0;
    800017da:	4501                	li	a0,0
    800017dc:	a021                	j	800017e4 <copyin+0x76>
    800017de:	4501                	li	a0,0
}
    800017e0:	8082                	ret
      return -1;
    800017e2:	557d                	li	a0,-1
}
    800017e4:	60a6                	ld	ra,72(sp)
    800017e6:	6406                	ld	s0,64(sp)
    800017e8:	74e2                	ld	s1,56(sp)
    800017ea:	7942                	ld	s2,48(sp)
    800017ec:	79a2                	ld	s3,40(sp)
    800017ee:	7a02                	ld	s4,32(sp)
    800017f0:	6ae2                	ld	s5,24(sp)
    800017f2:	6b42                	ld	s6,16(sp)
    800017f4:	6ba2                	ld	s7,8(sp)
    800017f6:	6c02                	ld	s8,0(sp)
    800017f8:	6161                	addi	sp,sp,80
    800017fa:	8082                	ret

00000000800017fc <copyinstr>:
copyinstr(pagetable_t pagetable, char *dst, uint64 srcva, uint64 max)
{
  uint64 n, va0, pa0;
  int got_null = 0;

  while(got_null == 0 && max > 0){
    800017fc:	cacd                	beqz	a3,800018ae <copyinstr+0xb2>
{
    800017fe:	715d                	addi	sp,sp,-80
    80001800:	e486                	sd	ra,72(sp)
    80001802:	e0a2                	sd	s0,64(sp)
    80001804:	fc26                	sd	s1,56(sp)
    80001806:	f84a                	sd	s2,48(sp)
    80001808:	f44e                	sd	s3,40(sp)
    8000180a:	f052                	sd	s4,32(sp)
    8000180c:	ec56                	sd	s5,24(sp)
    8000180e:	e85a                	sd	s6,16(sp)
    80001810:	e45e                	sd	s7,8(sp)
    80001812:	0880                	addi	s0,sp,80
    80001814:	8a2a                	mv	s4,a0
    80001816:	8b2e                	mv	s6,a1
    80001818:	8bb2                	mv	s7,a2
    8000181a:	8936                	mv	s2,a3
    va0 = PGROUNDDOWN(srcva);
    8000181c:	7afd                	lui	s5,0xfffff
    pa0 = walkaddr(pagetable, va0);
    if(pa0 == 0)
      return -1;
    n = PGSIZE - (srcva - va0);
    8000181e:	6985                	lui	s3,0x1
    80001820:	a825                	j	80001858 <copyinstr+0x5c>
      n = max;

    char *p = (char *) (pa0 + (srcva - va0));
    while(n > 0){
      if(*p == '\0'){
        *dst = '\0';
    80001822:	00078023          	sb	zero,0(a5) # 1000 <_entry-0x7ffff000>
    80001826:	4785                	li	a5,1
      dst++;
    }

    srcva = va0 + PGSIZE;
  }
  if(got_null){
    80001828:	37fd                	addiw	a5,a5,-1
    8000182a:	0007851b          	sext.w	a0,a5
    return 0;
  } else {
    return -1;
  }
}
    8000182e:	60a6                	ld	ra,72(sp)
    80001830:	6406                	ld	s0,64(sp)
    80001832:	74e2                	ld	s1,56(sp)
    80001834:	7942                	ld	s2,48(sp)
    80001836:	79a2                	ld	s3,40(sp)
    80001838:	7a02                	ld	s4,32(sp)
    8000183a:	6ae2                	ld	s5,24(sp)
    8000183c:	6b42                	ld	s6,16(sp)
    8000183e:	6ba2                	ld	s7,8(sp)
    80001840:	6161                	addi	sp,sp,80
    80001842:	8082                	ret
    80001844:	fff90713          	addi	a4,s2,-1 # fff <_entry-0x7ffff001>
    80001848:	9742                	add	a4,a4,a6
      --max;
    8000184a:	40b70933          	sub	s2,a4,a1
    srcva = va0 + PGSIZE;
    8000184e:	01348bb3          	add	s7,s1,s3
  while(got_null == 0 && max > 0){
    80001852:	04e58663          	beq	a1,a4,8000189e <copyinstr+0xa2>
{
    80001856:	8b3e                	mv	s6,a5
    va0 = PGROUNDDOWN(srcva);
    80001858:	015bf4b3          	and	s1,s7,s5
    pa0 = walkaddr(pagetable, va0);
    8000185c:	85a6                	mv	a1,s1
    8000185e:	8552                	mv	a0,s4
    80001860:	00000097          	auipc	ra,0x0
    80001864:	856080e7          	jalr	-1962(ra) # 800010b6 <walkaddr>
    if(pa0 == 0)
    80001868:	cd0d                	beqz	a0,800018a2 <copyinstr+0xa6>
    n = PGSIZE - (srcva - va0);
    8000186a:	417486b3          	sub	a3,s1,s7
    8000186e:	96ce                	add	a3,a3,s3
    if(n > max)
    80001870:	00d97363          	bgeu	s2,a3,80001876 <copyinstr+0x7a>
    80001874:	86ca                	mv	a3,s2
    char *p = (char *) (pa0 + (srcva - va0));
    80001876:	955e                	add	a0,a0,s7
    80001878:	8d05                	sub	a0,a0,s1
    while(n > 0){
    8000187a:	c695                	beqz	a3,800018a6 <copyinstr+0xaa>
    8000187c:	87da                	mv	a5,s6
    8000187e:	885a                	mv	a6,s6
      if(*p == '\0'){
    80001880:	41650633          	sub	a2,a0,s6
    while(n > 0){
    80001884:	96da                	add	a3,a3,s6
    80001886:	85be                	mv	a1,a5
      if(*p == '\0'){
    80001888:	00f60733          	add	a4,a2,a5
    8000188c:	00074703          	lbu	a4,0(a4) # fffffffffffff000 <end+0xffffffff7ffd42a0>
    80001890:	db49                	beqz	a4,80001822 <copyinstr+0x26>
        *dst = *p;
    80001892:	00e78023          	sb	a4,0(a5)
      dst++;
    80001896:	0785                	addi	a5,a5,1
    while(n > 0){
    80001898:	fed797e3          	bne	a5,a3,80001886 <copyinstr+0x8a>
    8000189c:	b765                	j	80001844 <copyinstr+0x48>
    8000189e:	4781                	li	a5,0
    800018a0:	b761                	j	80001828 <copyinstr+0x2c>
      return -1;
    800018a2:	557d                	li	a0,-1
    800018a4:	b769                	j	8000182e <copyinstr+0x32>
    srcva = va0 + PGSIZE;
    800018a6:	6b85                	lui	s7,0x1
    800018a8:	9ba6                	add	s7,s7,s1
    800018aa:	87da                	mv	a5,s6
    800018ac:	b76d                	j	80001856 <copyinstr+0x5a>
  int got_null = 0;
    800018ae:	4781                	li	a5,0
  if(got_null){
    800018b0:	37fd                	addiw	a5,a5,-1
    800018b2:	0007851b          	sext.w	a0,a5
}
    800018b6:	8082                	ret

00000000800018b8 <rand>:
// Global seed for random number generation
static unsigned int seed = 123456789;  // You can change this to any initial seed

// Linear Congruential Generator (LCG) function
unsigned int rand()
{
    800018b8:	1141                	addi	sp,sp,-16
    800018ba:	e422                	sd	s0,8(sp)
    800018bc:	0800                	addi	s0,sp,16
    // Constants for LCG, chosen for 32-bit integers
    seed = (1664525 * seed + 1013904223) % 0xFFFFFFFF;
    800018be:	00007717          	auipc	a4,0x7
    800018c2:	fa670713          	addi	a4,a4,-90 # 80008864 <seed>
    800018c6:	431c                	lw	a5,0(a4)
    800018c8:	00196537          	lui	a0,0x196
    800018cc:	60d5051b          	addiw	a0,a0,1549 # 19660d <_entry-0x7fe699f3>
    800018d0:	02f5053b          	mulw	a0,a0,a5
    800018d4:	3c6ef7b7          	lui	a5,0x3c6ef
    800018d8:	35f7879b          	addiw	a5,a5,863 # 3c6ef35f <_entry-0x43910ca1>
    800018dc:	9d3d                	addw	a0,a0,a5
    800018de:	0005079b          	sext.w	a5,a0
    800018e2:	fff7b793          	sltiu	a5,a5,-1
    800018e6:	0017b793          	seqz	a5,a5
    800018ea:	9d3d                	addw	a0,a0,a5
    800018ec:	c308                	sw	a0,0(a4)
    return seed;
}
    800018ee:	2501                	sext.w	a0,a0
    800018f0:	6422                	ld	s0,8(sp)
    800018f2:	0141                	addi	sp,sp,16
    800018f4:	8082                	ret

00000000800018f6 <init_tickets>:


void init_tickets(struct proc *p)
{
    800018f6:	1141                	addi	sp,sp,-16
    800018f8:	e422                	sd	s0,8(sp)
    800018fa:	0800                	addi	s0,sp,16
  p->tickets = 1; // Default 1 ticket
    800018fc:	4785                	li	a5,1
    800018fe:	28f52a23          	sw	a5,660(a0)
}
    80001902:	6422                	ld	s0,8(sp)
    80001904:	0141                	addi	sp,sp,16
    80001906:	8082                	ret

0000000080001908 <total_tickets>:

int total_tickets()
{
    80001908:	1141                	addi	sp,sp,-16
    8000190a:	e422                	sd	s0,8(sp)
    8000190c:	0800                	addi	s0,sp,16
  struct proc *p;
  int total = 0;
    8000190e:	4501                	li	a0,0
  for (p = proc; p < &proc[NPROC]; p++)
    80001910:	0000f797          	auipc	a5,0xf
    80001914:	67078793          	addi	a5,a5,1648 # 80010f80 <proc>
  {
    if (p->state == RUNNABLE)
    80001918:	460d                	li	a2,3
  for (p = proc; p < &proc[NPROC]; p++)
    8000191a:	0001a697          	auipc	a3,0x1a
    8000191e:	06668693          	addi	a3,a3,102 # 8001b980 <tickslock>
    80001922:	a029                	j	8000192c <total_tickets+0x24>
    80001924:	2a878793          	addi	a5,a5,680
    80001928:	00d78a63          	beq	a5,a3,8000193c <total_tickets+0x34>
    if (p->state == RUNNABLE)
    8000192c:	1387a703          	lw	a4,312(a5)
    80001930:	fec71ae3          	bne	a4,a2,80001924 <total_tickets+0x1c>
      total += p->tickets;
    80001934:	2947a703          	lw	a4,660(a5)
    80001938:	9d39                	addw	a0,a0,a4
    8000193a:	b7ed                	j	80001924 <total_tickets+0x1c>
  }
  return total;
}
    8000193c:	6422                	ld	s0,8(sp)
    8000193e:	0141                	addi	sp,sp,16
    80001940:	8082                	ret

0000000080001942 <lottery_pick>:

struct proc *lottery_pick()
{
    80001942:	1101                	addi	sp,sp,-32
    80001944:	ec06                	sd	ra,24(sp)
    80001946:	e822                	sd	s0,16(sp)
    80001948:	1000                	addi	s0,sp,32
  int total = total_tickets();  // Get the total number of tickets
    8000194a:	00000097          	auipc	ra,0x0
    8000194e:	fbe080e7          	jalr	-66(ra) # 80001908 <total_tickets>
  if (total == 0) return 0;  // No runnable process, return NULL
    80001952:	4781                	li	a5,0
    80001954:	c539                	beqz	a0,800019a2 <lottery_pick+0x60>
    80001956:	e426                	sd	s1,8(sp)

  int winner = rand() % total_tickets();
    80001958:	00000097          	auipc	ra,0x0
    8000195c:	f60080e7          	jalr	-160(ra) # 800018b8 <rand>
    80001960:	0005049b          	sext.w	s1,a0
    80001964:	00000097          	auipc	ra,0x0
    80001968:	fa4080e7          	jalr	-92(ra) # 80001908 <total_tickets>
    8000196c:	02a4f53b          	remuw	a0,s1,a0
  int count = 0;
  struct proc *p;
  for (p = proc; p < &proc[NPROC]; p++)
    80001970:	0000f797          	auipc	a5,0xf
    80001974:	61078793          	addi	a5,a5,1552 # 80010f80 <proc>
  int count = 0;
    80001978:	4681                	li	a3,0
  {
    if (p->state == RUNNABLE)
    8000197a:	460d                	li	a2,3
  for (p = proc; p < &proc[NPROC]; p++)
    8000197c:	0001a597          	auipc	a1,0x1a
    80001980:	00458593          	addi	a1,a1,4 # 8001b980 <tickslock>
    80001984:	a029                	j	8000198e <lottery_pick+0x4c>
    80001986:	2a878793          	addi	a5,a5,680
    8000198a:	02b78163          	beq	a5,a1,800019ac <lottery_pick+0x6a>
    if (p->state == RUNNABLE)
    8000198e:	1387a703          	lw	a4,312(a5)
    80001992:	fec71ae3          	bne	a4,a2,80001986 <lottery_pick+0x44>
    {
      count += p->tickets;
    80001996:	2947a703          	lw	a4,660(a5)
    8000199a:	9eb9                	addw	a3,a3,a4
      if (count > winner)
    8000199c:	fed555e3          	bge	a0,a3,80001986 <lottery_pick+0x44>
    800019a0:	64a2                	ld	s1,8(sp)
        return p;
    }
  }
  return 0;
}
    800019a2:	853e                	mv	a0,a5
    800019a4:	60e2                	ld	ra,24(sp)
    800019a6:	6442                	ld	s0,16(sp)
    800019a8:	6105                	addi	sp,sp,32
    800019aa:	8082                	ret
  return 0;
    800019ac:	4781                	li	a5,0
    800019ae:	64a2                	ld	s1,8(sp)
    800019b0:	bfcd                	j	800019a2 <lottery_pick+0x60>

00000000800019b2 <init_mlfq>:

void init_mlfq(struct proc *p)
{
    800019b2:	1141                	addi	sp,sp,-16
    800019b4:	e422                	sd	s0,8(sp)
    800019b6:	0800                	addi	s0,sp,16
  p->priority = 0;
    800019b8:	28052c23          	sw	zero,664(a0)
  p->time_slice = 1;
    800019bc:	4785                	li	a5,1
    800019be:	28f52e23          	sw	a5,668(a0)
  p->queue_time = 0;
    800019c2:	2a052023          	sw	zero,672(a0)
}
    800019c6:	6422                	ld	s0,8(sp)
    800019c8:	0141                	addi	sp,sp,16
    800019ca:	8082                	ret

00000000800019cc <update_priority>:
    p->queue_time = 0;
  }
}*/

void update_priority(struct proc *p)
{
    800019cc:	7179                	addi	sp,sp,-48
    800019ce:	f422                	sd	s0,40(sp)
    800019d0:	1800                	addi	s0,sp,48
  // Define time slices for each priority level
  int time_slices[] = {1, 2, 4, 8, 16, 32};  // Time slices for priority 0, 1, 2, 3, 4, 5
    800019d2:	4785                	li	a5,1
    800019d4:	fcf42c23          	sw	a5,-40(s0)
    800019d8:	4789                	li	a5,2
    800019da:	fcf42e23          	sw	a5,-36(s0)
    800019de:	4791                	li	a5,4
    800019e0:	fef42023          	sw	a5,-32(s0)
    800019e4:	47a1                	li	a5,8
    800019e6:	fef42223          	sw	a5,-28(s0)
    800019ea:	47c1                	li	a5,16
    800019ec:	fef42423          	sw	a5,-24(s0)
    800019f0:	02000793          	li	a5,32
    800019f4:	fef42623          	sw	a5,-20(s0)

  // Check if process has exhausted its time slice in the current queue
  if (p->queue_time >= time_slices[p->priority])
    800019f8:	29852703          	lw	a4,664(a0)
    800019fc:	00271793          	slli	a5,a4,0x2
    80001a00:	17c1                	addi	a5,a5,-16
    80001a02:	97a2                	add	a5,a5,s0
    80001a04:	2a052683          	lw	a3,672(a0)
    80001a08:	fe87a783          	lw	a5,-24(a5)
    80001a0c:	02f6c363          	blt	a3,a5,80001a32 <update_priority+0x66>
  {
    // If process is not in the lowest priority queue, demote it
    if (p->priority < 3)
    80001a10:	4789                	li	a5,2
    80001a12:	00e7c563          	blt	a5,a4,80001a1c <update_priority+0x50>
    {
      p->priority++;  // Move process to the next lower priority queue
    80001a16:	2705                	addiw	a4,a4,1
    80001a18:	28e52c23          	sw	a4,664(a0)
    }

    // Reset queue time and set the time slice for the new priority level
    p->time_slice = time_slices[p->priority];  // Update time slice for new priority = queue
    80001a1c:	29852783          	lw	a5,664(a0)
    80001a20:	078a                	slli	a5,a5,0x2
    80001a22:	17c1                	addi	a5,a5,-16
    80001a24:	97a2                	add	a5,a5,s0
    80001a26:	fe87a783          	lw	a5,-24(a5)
    80001a2a:	28f52e23          	sw	a5,668(a0)
    p->queue_time = 0;  // Reset queue time since it's been demoted
    80001a2e:	2a052023          	sw	zero,672(a0)
  }
}
    80001a32:	7422                	ld	s0,40(sp)
    80001a34:	6145                	addi	sp,sp,48
    80001a36:	8082                	ret

0000000080001a38 <boost_priority>:
    release(&p->lock);
  }
}*/

void boost_priority(void)
{
    80001a38:	7179                	addi	sp,sp,-48
    80001a3a:	f406                	sd	ra,40(sp)
    80001a3c:	f022                	sd	s0,32(sp)
    80001a3e:	ec26                	sd	s1,24(sp)
    80001a40:	e84a                	sd	s2,16(sp)
    80001a42:	e44e                	sd	s3,8(sp)
    80001a44:	e052                	sd	s4,0(sp)
    80001a46:	1800                	addi	s0,sp,48
  struct proc *p;
  for (p = proc; p < &proc[NPROC]; p++)
    80001a48:	0000f497          	auipc	s1,0xf
    80001a4c:	65848493          	addi	s1,s1,1624 # 800110a0 <proc+0x120>
    80001a50:	0001a997          	auipc	s3,0x1a
    80001a54:	05098993          	addi	s3,s3,80 # 8001baa0 <syscall_counts+0x108>
      // Gradually boost processes by one level if they are in a lower priority queue
      if (p->priority > 0) // Only boost if not already in the highest priority queue
      {
        p->priority--; // Boost to a higher priority queue
        p->queue_time = 0; // Reset the queue time
        p->time_slice = 1 << p->priority;  // Adjust the time slice for the new priority queue
    80001a58:	4a05                	li	s4,1
    80001a5a:	a811                	j	80001a6e <boost_priority+0x36>
      }
    }
    release(&p->lock);
    80001a5c:	854a                	mv	a0,s2
    80001a5e:	fffff097          	auipc	ra,0xfffff
    80001a62:	28e080e7          	jalr	654(ra) # 80000cec <release>
  for (p = proc; p < &proc[NPROC]; p++)
    80001a66:	2a848493          	addi	s1,s1,680
    80001a6a:	03348863          	beq	s1,s3,80001a9a <boost_priority+0x62>
    acquire(&p->lock);
    80001a6e:	8926                	mv	s2,s1
    80001a70:	8526                	mv	a0,s1
    80001a72:	fffff097          	auipc	ra,0xfffff
    80001a76:	1c6080e7          	jalr	454(ra) # 80000c38 <acquire>
    if (p->state != UNUSED)
    80001a7a:	4c9c                	lw	a5,24(s1)
    80001a7c:	d3e5                	beqz	a5,80001a5c <boost_priority+0x24>
      if (p->priority > 0) // Only boost if not already in the highest priority queue
    80001a7e:	1784a783          	lw	a5,376(s1)
    80001a82:	fcf05de3          	blez	a5,80001a5c <boost_priority+0x24>
        p->priority--; // Boost to a higher priority queue
    80001a86:	37fd                	addiw	a5,a5,-1
    80001a88:	16f4ac23          	sw	a5,376(s1)
        p->queue_time = 0; // Reset the queue time
    80001a8c:	1804a023          	sw	zero,384(s1)
        p->time_slice = 1 << p->priority;  // Adjust the time slice for the new priority queue
    80001a90:	00fa17bb          	sllw	a5,s4,a5
    80001a94:	16f4ae23          	sw	a5,380(s1)
    80001a98:	b7d1                	j	80001a5c <boost_priority+0x24>
  }
}
    80001a9a:	70a2                	ld	ra,40(sp)
    80001a9c:	7402                	ld	s0,32(sp)
    80001a9e:	64e2                	ld	s1,24(sp)
    80001aa0:	6942                	ld	s2,16(sp)
    80001aa2:	69a2                	ld	s3,8(sp)
    80001aa4:	6a02                	ld	s4,0(sp)
    80001aa6:	6145                	addi	sp,sp,48
    80001aa8:	8082                	ret

0000000080001aaa <proc_mapstacks>:

// Allocate a page for each process's kernel stack.
// Map it high in memory, followed by an invalid
// guard page.
void proc_mapstacks(pagetable_t kpgtbl)
{
    80001aaa:	7139                	addi	sp,sp,-64
    80001aac:	fc06                	sd	ra,56(sp)
    80001aae:	f822                	sd	s0,48(sp)
    80001ab0:	f426                	sd	s1,40(sp)
    80001ab2:	f04a                	sd	s2,32(sp)
    80001ab4:	ec4e                	sd	s3,24(sp)
    80001ab6:	e852                	sd	s4,16(sp)
    80001ab8:	e456                	sd	s5,8(sp)
    80001aba:	e05a                	sd	s6,0(sp)
    80001abc:	0080                	addi	s0,sp,64
    80001abe:	8a2a                	mv	s4,a0
  struct proc *p;

  for (p = proc; p < &proc[NPROC]; p++)
    80001ac0:	0000f497          	auipc	s1,0xf
    80001ac4:	4c048493          	addi	s1,s1,1216 # 80010f80 <proc>
  {
    char *pa = kalloc();
    if (pa == 0)
      panic("kalloc");
    uint64 va = KSTACK((int)(p - proc));
    80001ac8:	8b26                	mv	s6,s1
    80001aca:	fcfd0937          	lui	s2,0xfcfd0
    80001ace:	cfd90913          	addi	s2,s2,-771 # fffffffffcfcfcfd <end+0xffffffff7cfa4f9d>
    80001ad2:	0942                	slli	s2,s2,0x10
    80001ad4:	cfd90913          	addi	s2,s2,-771
    80001ad8:	0942                	slli	s2,s2,0x10
    80001ada:	cfd90913          	addi	s2,s2,-771
    80001ade:	040009b7          	lui	s3,0x4000
    80001ae2:	19fd                	addi	s3,s3,-1 # 3ffffff <_entry-0x7c000001>
    80001ae4:	09b2                	slli	s3,s3,0xc
  for (p = proc; p < &proc[NPROC]; p++)
    80001ae6:	0001aa97          	auipc	s5,0x1a
    80001aea:	e9aa8a93          	addi	s5,s5,-358 # 8001b980 <tickslock>
    char *pa = kalloc();
    80001aee:	fffff097          	auipc	ra,0xfffff
    80001af2:	05a080e7          	jalr	90(ra) # 80000b48 <kalloc>
    80001af6:	862a                	mv	a2,a0
    if (pa == 0)
    80001af8:	c121                	beqz	a0,80001b38 <proc_mapstacks+0x8e>
    uint64 va = KSTACK((int)(p - proc));
    80001afa:	416485b3          	sub	a1,s1,s6
    80001afe:	858d                	srai	a1,a1,0x3
    80001b00:	032585b3          	mul	a1,a1,s2
    80001b04:	2585                	addiw	a1,a1,1
    80001b06:	00d5959b          	slliw	a1,a1,0xd
    kvmmap(kpgtbl, va, (uint64)pa, PGSIZE, PTE_R | PTE_W);
    80001b0a:	4719                	li	a4,6
    80001b0c:	6685                	lui	a3,0x1
    80001b0e:	40b985b3          	sub	a1,s3,a1
    80001b12:	8552                	mv	a0,s4
    80001b14:	fffff097          	auipc	ra,0xfffff
    80001b18:	684080e7          	jalr	1668(ra) # 80001198 <kvmmap>
  for (p = proc; p < &proc[NPROC]; p++)
    80001b1c:	2a848493          	addi	s1,s1,680
    80001b20:	fd5497e3          	bne	s1,s5,80001aee <proc_mapstacks+0x44>
  }
}
    80001b24:	70e2                	ld	ra,56(sp)
    80001b26:	7442                	ld	s0,48(sp)
    80001b28:	74a2                	ld	s1,40(sp)
    80001b2a:	7902                	ld	s2,32(sp)
    80001b2c:	69e2                	ld	s3,24(sp)
    80001b2e:	6a42                	ld	s4,16(sp)
    80001b30:	6aa2                	ld	s5,8(sp)
    80001b32:	6b02                	ld	s6,0(sp)
    80001b34:	6121                	addi	sp,sp,64
    80001b36:	8082                	ret
      panic("kalloc");
    80001b38:	00006517          	auipc	a0,0x6
    80001b3c:	68050513          	addi	a0,a0,1664 # 800081b8 <etext+0x1b8>
    80001b40:	fffff097          	auipc	ra,0xfffff
    80001b44:	a20080e7          	jalr	-1504(ra) # 80000560 <panic>

0000000080001b48 <procinit>:

// initialize the proc table.
void procinit(void)
{
    80001b48:	7139                	addi	sp,sp,-64
    80001b4a:	fc06                	sd	ra,56(sp)
    80001b4c:	f822                	sd	s0,48(sp)
    80001b4e:	f426                	sd	s1,40(sp)
    80001b50:	f04a                	sd	s2,32(sp)
    80001b52:	ec4e                	sd	s3,24(sp)
    80001b54:	e852                	sd	s4,16(sp)
    80001b56:	e456                	sd	s5,8(sp)
    80001b58:	e05a                	sd	s6,0(sp)
    80001b5a:	0080                	addi	s0,sp,64
  struct proc *p;

  initlock(&pid_lock, "nextpid");
    80001b5c:	00006597          	auipc	a1,0x6
    80001b60:	66458593          	addi	a1,a1,1636 # 800081c0 <etext+0x1c0>
    80001b64:	0000f517          	auipc	a0,0xf
    80001b68:	fec50513          	addi	a0,a0,-20 # 80010b50 <pid_lock>
    80001b6c:	fffff097          	auipc	ra,0xfffff
    80001b70:	03c080e7          	jalr	60(ra) # 80000ba8 <initlock>
  initlock(&wait_lock, "wait_lock");
    80001b74:	00006597          	auipc	a1,0x6
    80001b78:	65458593          	addi	a1,a1,1620 # 800081c8 <etext+0x1c8>
    80001b7c:	0000f517          	auipc	a0,0xf
    80001b80:	fec50513          	addi	a0,a0,-20 # 80010b68 <wait_lock>
    80001b84:	fffff097          	auipc	ra,0xfffff
    80001b88:	024080e7          	jalr	36(ra) # 80000ba8 <initlock>
  for (p = proc; p < &proc[NPROC]; p++)
    80001b8c:	0000f497          	auipc	s1,0xf
    80001b90:	3f448493          	addi	s1,s1,1012 # 80010f80 <proc>
  {
    initlock(&p->lock, "proc");
    80001b94:	00006b17          	auipc	s6,0x6
    80001b98:	644b0b13          	addi	s6,s6,1604 # 800081d8 <etext+0x1d8>
    p->state = UNUSED;
    p->kstack = KSTACK((int)(p - proc));
    80001b9c:	8aa6                	mv	s5,s1
    80001b9e:	fcfd0937          	lui	s2,0xfcfd0
    80001ba2:	cfd90913          	addi	s2,s2,-771 # fffffffffcfcfcfd <end+0xffffffff7cfa4f9d>
    80001ba6:	0942                	slli	s2,s2,0x10
    80001ba8:	cfd90913          	addi	s2,s2,-771
    80001bac:	0942                	slli	s2,s2,0x10
    80001bae:	cfd90913          	addi	s2,s2,-771
    80001bb2:	040009b7          	lui	s3,0x4000
    80001bb6:	19fd                	addi	s3,s3,-1 # 3ffffff <_entry-0x7c000001>
    80001bb8:	09b2                	slli	s3,s3,0xc
  for (p = proc; p < &proc[NPROC]; p++)
    80001bba:	0001aa17          	auipc	s4,0x1a
    80001bbe:	dc6a0a13          	addi	s4,s4,-570 # 8001b980 <tickslock>
    initlock(&p->lock, "proc");
    80001bc2:	85da                	mv	a1,s6
    80001bc4:	12048513          	addi	a0,s1,288
    80001bc8:	fffff097          	auipc	ra,0xfffff
    80001bcc:	fe0080e7          	jalr	-32(ra) # 80000ba8 <initlock>
    p->state = UNUSED;
    80001bd0:	1204ac23          	sw	zero,312(s1)
    p->kstack = KSTACK((int)(p - proc));
    80001bd4:	415487b3          	sub	a5,s1,s5
    80001bd8:	878d                	srai	a5,a5,0x3
    80001bda:	032787b3          	mul	a5,a5,s2
    80001bde:	2785                	addiw	a5,a5,1
    80001be0:	00d7979b          	slliw	a5,a5,0xd
    80001be4:	40f987b3          	sub	a5,s3,a5
    80001be8:	16f4b023          	sd	a5,352(s1)
  for (p = proc; p < &proc[NPROC]; p++)
    80001bec:	2a848493          	addi	s1,s1,680
    80001bf0:	fd4499e3          	bne	s1,s4,80001bc2 <procinit+0x7a>
  }
}
    80001bf4:	70e2                	ld	ra,56(sp)
    80001bf6:	7442                	ld	s0,48(sp)
    80001bf8:	74a2                	ld	s1,40(sp)
    80001bfa:	7902                	ld	s2,32(sp)
    80001bfc:	69e2                	ld	s3,24(sp)
    80001bfe:	6a42                	ld	s4,16(sp)
    80001c00:	6aa2                	ld	s5,8(sp)
    80001c02:	6b02                	ld	s6,0(sp)
    80001c04:	6121                	addi	sp,sp,64
    80001c06:	8082                	ret

0000000080001c08 <cpuid>:

// Must be called with interrupts disabled,
// to prevent race with process being moved
// to a different CPU.
int cpuid()
{
    80001c08:	1141                	addi	sp,sp,-16
    80001c0a:	e422                	sd	s0,8(sp)
    80001c0c:	0800                	addi	s0,sp,16
  asm volatile("mv %0, tp" : "=r" (x) );
    80001c0e:	8512                	mv	a0,tp
  int id = r_tp();
  return id;
}
    80001c10:	2501                	sext.w	a0,a0
    80001c12:	6422                	ld	s0,8(sp)
    80001c14:	0141                	addi	sp,sp,16
    80001c16:	8082                	ret

0000000080001c18 <mycpu>:

// Return this CPU's cpu struct.
// Interrupts must be disabled.
struct cpu *
mycpu(void)
{
    80001c18:	1141                	addi	sp,sp,-16
    80001c1a:	e422                	sd	s0,8(sp)
    80001c1c:	0800                	addi	s0,sp,16
    80001c1e:	8792                	mv	a5,tp
  int id = cpuid();
  struct cpu *c = &cpus[id];
    80001c20:	2781                	sext.w	a5,a5
    80001c22:	079e                	slli	a5,a5,0x7
  return c;
}
    80001c24:	0000f517          	auipc	a0,0xf
    80001c28:	f5c50513          	addi	a0,a0,-164 # 80010b80 <cpus>
    80001c2c:	953e                	add	a0,a0,a5
    80001c2e:	6422                	ld	s0,8(sp)
    80001c30:	0141                	addi	sp,sp,16
    80001c32:	8082                	ret

0000000080001c34 <myproc>:

// Return the current struct proc *, or zero if none.
struct proc *
myproc(void)
{
    80001c34:	1101                	addi	sp,sp,-32
    80001c36:	ec06                	sd	ra,24(sp)
    80001c38:	e822                	sd	s0,16(sp)
    80001c3a:	e426                	sd	s1,8(sp)
    80001c3c:	1000                	addi	s0,sp,32
  push_off();
    80001c3e:	fffff097          	auipc	ra,0xfffff
    80001c42:	fae080e7          	jalr	-82(ra) # 80000bec <push_off>
    80001c46:	8792                	mv	a5,tp
  struct cpu *c = mycpu();
  struct proc *p = c->proc;
    80001c48:	2781                	sext.w	a5,a5
    80001c4a:	079e                	slli	a5,a5,0x7
    80001c4c:	0000f717          	auipc	a4,0xf
    80001c50:	f0470713          	addi	a4,a4,-252 # 80010b50 <pid_lock>
    80001c54:	97ba                	add	a5,a5,a4
    80001c56:	7b84                	ld	s1,48(a5)
  pop_off();
    80001c58:	fffff097          	auipc	ra,0xfffff
    80001c5c:	034080e7          	jalr	52(ra) # 80000c8c <pop_off>
  return p;
}
    80001c60:	8526                	mv	a0,s1
    80001c62:	60e2                	ld	ra,24(sp)
    80001c64:	6442                	ld	s0,16(sp)
    80001c66:	64a2                	ld	s1,8(sp)
    80001c68:	6105                	addi	sp,sp,32
    80001c6a:	8082                	ret

0000000080001c6c <forkret>:
}

// A fork child's very first scheduling by scheduler()
// will swtch to forkret.
void forkret(void)
{
    80001c6c:	1141                	addi	sp,sp,-16
    80001c6e:	e406                	sd	ra,8(sp)
    80001c70:	e022                	sd	s0,0(sp)
    80001c72:	0800                	addi	s0,sp,16
  static int first = 1;

  // Still holding p->lock from scheduler.
  release(&myproc()->lock);
    80001c74:	00000097          	auipc	ra,0x0
    80001c78:	fc0080e7          	jalr	-64(ra) # 80001c34 <myproc>
    80001c7c:	12050513          	addi	a0,a0,288
    80001c80:	fffff097          	auipc	ra,0xfffff
    80001c84:	06c080e7          	jalr	108(ra) # 80000cec <release>

  if (first)
    80001c88:	00007797          	auipc	a5,0x7
    80001c8c:	bd87a783          	lw	a5,-1064(a5) # 80008860 <first.1>
    80001c90:	eb89                	bnez	a5,80001ca2 <forkret+0x36>
    // be run from main().
    first = 0;
    fsinit(ROOTDEV);
  }

  usertrapret();
    80001c92:	00001097          	auipc	ra,0x1
    80001c96:	f52080e7          	jalr	-174(ra) # 80002be4 <usertrapret>
}
    80001c9a:	60a2                	ld	ra,8(sp)
    80001c9c:	6402                	ld	s0,0(sp)
    80001c9e:	0141                	addi	sp,sp,16
    80001ca0:	8082                	ret
    first = 0;
    80001ca2:	00007797          	auipc	a5,0x7
    80001ca6:	ba07af23          	sw	zero,-1090(a5) # 80008860 <first.1>
    fsinit(ROOTDEV);
    80001caa:	4505                	li	a0,1
    80001cac:	00002097          	auipc	ra,0x2
    80001cb0:	f4e080e7          	jalr	-178(ra) # 80003bfa <fsinit>
    80001cb4:	bff9                	j	80001c92 <forkret+0x26>

0000000080001cb6 <allocpid>:
{
    80001cb6:	1101                	addi	sp,sp,-32
    80001cb8:	ec06                	sd	ra,24(sp)
    80001cba:	e822                	sd	s0,16(sp)
    80001cbc:	e426                	sd	s1,8(sp)
    80001cbe:	e04a                	sd	s2,0(sp)
    80001cc0:	1000                	addi	s0,sp,32
  acquire(&pid_lock);
    80001cc2:	0000f917          	auipc	s2,0xf
    80001cc6:	e8e90913          	addi	s2,s2,-370 # 80010b50 <pid_lock>
    80001cca:	854a                	mv	a0,s2
    80001ccc:	fffff097          	auipc	ra,0xfffff
    80001cd0:	f6c080e7          	jalr	-148(ra) # 80000c38 <acquire>
  pid = nextpid;
    80001cd4:	00007797          	auipc	a5,0x7
    80001cd8:	b9478793          	addi	a5,a5,-1132 # 80008868 <nextpid>
    80001cdc:	4384                	lw	s1,0(a5)
  nextpid = nextpid + 1;
    80001cde:	0014871b          	addiw	a4,s1,1
    80001ce2:	c398                	sw	a4,0(a5)
  release(&pid_lock);
    80001ce4:	854a                	mv	a0,s2
    80001ce6:	fffff097          	auipc	ra,0xfffff
    80001cea:	006080e7          	jalr	6(ra) # 80000cec <release>
}
    80001cee:	8526                	mv	a0,s1
    80001cf0:	60e2                	ld	ra,24(sp)
    80001cf2:	6442                	ld	s0,16(sp)
    80001cf4:	64a2                	ld	s1,8(sp)
    80001cf6:	6902                	ld	s2,0(sp)
    80001cf8:	6105                	addi	sp,sp,32
    80001cfa:	8082                	ret

0000000080001cfc <proc_pagetable>:
{
    80001cfc:	1101                	addi	sp,sp,-32
    80001cfe:	ec06                	sd	ra,24(sp)
    80001d00:	e822                	sd	s0,16(sp)
    80001d02:	e426                	sd	s1,8(sp)
    80001d04:	e04a                	sd	s2,0(sp)
    80001d06:	1000                	addi	s0,sp,32
    80001d08:	892a                	mv	s2,a0
  pagetable = uvmcreate();
    80001d0a:	fffff097          	auipc	ra,0xfffff
    80001d0e:	688080e7          	jalr	1672(ra) # 80001392 <uvmcreate>
    80001d12:	84aa                	mv	s1,a0
  if (pagetable == 0)
    80001d14:	c121                	beqz	a0,80001d54 <proc_pagetable+0x58>
  if (mappages(pagetable, TRAMPOLINE, PGSIZE,
    80001d16:	4729                	li	a4,10
    80001d18:	00005697          	auipc	a3,0x5
    80001d1c:	2e868693          	addi	a3,a3,744 # 80007000 <_trampoline>
    80001d20:	6605                	lui	a2,0x1
    80001d22:	040005b7          	lui	a1,0x4000
    80001d26:	15fd                	addi	a1,a1,-1 # 3ffffff <_entry-0x7c000001>
    80001d28:	05b2                	slli	a1,a1,0xc
    80001d2a:	fffff097          	auipc	ra,0xfffff
    80001d2e:	3ce080e7          	jalr	974(ra) # 800010f8 <mappages>
    80001d32:	02054863          	bltz	a0,80001d62 <proc_pagetable+0x66>
  if (mappages(pagetable, TRAPFRAME, PGSIZE,
    80001d36:	4719                	li	a4,6
    80001d38:	17893683          	ld	a3,376(s2)
    80001d3c:	6605                	lui	a2,0x1
    80001d3e:	020005b7          	lui	a1,0x2000
    80001d42:	15fd                	addi	a1,a1,-1 # 1ffffff <_entry-0x7e000001>
    80001d44:	05b6                	slli	a1,a1,0xd
    80001d46:	8526                	mv	a0,s1
    80001d48:	fffff097          	auipc	ra,0xfffff
    80001d4c:	3b0080e7          	jalr	944(ra) # 800010f8 <mappages>
    80001d50:	02054163          	bltz	a0,80001d72 <proc_pagetable+0x76>
}
    80001d54:	8526                	mv	a0,s1
    80001d56:	60e2                	ld	ra,24(sp)
    80001d58:	6442                	ld	s0,16(sp)
    80001d5a:	64a2                	ld	s1,8(sp)
    80001d5c:	6902                	ld	s2,0(sp)
    80001d5e:	6105                	addi	sp,sp,32
    80001d60:	8082                	ret
    uvmfree(pagetable, 0);
    80001d62:	4581                	li	a1,0
    80001d64:	8526                	mv	a0,s1
    80001d66:	00000097          	auipc	ra,0x0
    80001d6a:	83e080e7          	jalr	-1986(ra) # 800015a4 <uvmfree>
    return 0;
    80001d6e:	4481                	li	s1,0
    80001d70:	b7d5                	j	80001d54 <proc_pagetable+0x58>
    uvmunmap(pagetable, TRAMPOLINE, 1, 0);
    80001d72:	4681                	li	a3,0
    80001d74:	4605                	li	a2,1
    80001d76:	040005b7          	lui	a1,0x4000
    80001d7a:	15fd                	addi	a1,a1,-1 # 3ffffff <_entry-0x7c000001>
    80001d7c:	05b2                	slli	a1,a1,0xc
    80001d7e:	8526                	mv	a0,s1
    80001d80:	fffff097          	auipc	ra,0xfffff
    80001d84:	53e080e7          	jalr	1342(ra) # 800012be <uvmunmap>
    uvmfree(pagetable, 0);
    80001d88:	4581                	li	a1,0
    80001d8a:	8526                	mv	a0,s1
    80001d8c:	00000097          	auipc	ra,0x0
    80001d90:	818080e7          	jalr	-2024(ra) # 800015a4 <uvmfree>
    return 0;
    80001d94:	4481                	li	s1,0
    80001d96:	bf7d                	j	80001d54 <proc_pagetable+0x58>

0000000080001d98 <proc_freepagetable>:
{
    80001d98:	1101                	addi	sp,sp,-32
    80001d9a:	ec06                	sd	ra,24(sp)
    80001d9c:	e822                	sd	s0,16(sp)
    80001d9e:	e426                	sd	s1,8(sp)
    80001da0:	e04a                	sd	s2,0(sp)
    80001da2:	1000                	addi	s0,sp,32
    80001da4:	84aa                	mv	s1,a0
    80001da6:	892e                	mv	s2,a1
  uvmunmap(pagetable, TRAMPOLINE, 1, 0);
    80001da8:	4681                	li	a3,0
    80001daa:	4605                	li	a2,1
    80001dac:	040005b7          	lui	a1,0x4000
    80001db0:	15fd                	addi	a1,a1,-1 # 3ffffff <_entry-0x7c000001>
    80001db2:	05b2                	slli	a1,a1,0xc
    80001db4:	fffff097          	auipc	ra,0xfffff
    80001db8:	50a080e7          	jalr	1290(ra) # 800012be <uvmunmap>
  uvmunmap(pagetable, TRAPFRAME, 1, 0);
    80001dbc:	4681                	li	a3,0
    80001dbe:	4605                	li	a2,1
    80001dc0:	020005b7          	lui	a1,0x2000
    80001dc4:	15fd                	addi	a1,a1,-1 # 1ffffff <_entry-0x7e000001>
    80001dc6:	05b6                	slli	a1,a1,0xd
    80001dc8:	8526                	mv	a0,s1
    80001dca:	fffff097          	auipc	ra,0xfffff
    80001dce:	4f4080e7          	jalr	1268(ra) # 800012be <uvmunmap>
  uvmfree(pagetable, sz);
    80001dd2:	85ca                	mv	a1,s2
    80001dd4:	8526                	mv	a0,s1
    80001dd6:	fffff097          	auipc	ra,0xfffff
    80001dda:	7ce080e7          	jalr	1998(ra) # 800015a4 <uvmfree>
}
    80001dde:	60e2                	ld	ra,24(sp)
    80001de0:	6442                	ld	s0,16(sp)
    80001de2:	64a2                	ld	s1,8(sp)
    80001de4:	6902                	ld	s2,0(sp)
    80001de6:	6105                	addi	sp,sp,32
    80001de8:	8082                	ret

0000000080001dea <freeproc>:
{
    80001dea:	1101                	addi	sp,sp,-32
    80001dec:	ec06                	sd	ra,24(sp)
    80001dee:	e822                	sd	s0,16(sp)
    80001df0:	e426                	sd	s1,8(sp)
    80001df2:	1000                	addi	s0,sp,32
    80001df4:	84aa                	mv	s1,a0
  if (p->trapframe)
    80001df6:	17853503          	ld	a0,376(a0)
    80001dfa:	c509                	beqz	a0,80001e04 <freeproc+0x1a>
    kfree((void *)p->trapframe);
    80001dfc:	fffff097          	auipc	ra,0xfffff
    80001e00:	c4e080e7          	jalr	-946(ra) # 80000a4a <kfree>
  p->trapframe = 0;
    80001e04:	1604bc23          	sd	zero,376(s1)
  if (p->pagetable)
    80001e08:	1704b503          	ld	a0,368(s1)
    80001e0c:	c519                	beqz	a0,80001e1a <freeproc+0x30>
    proc_freepagetable(p->pagetable, p->sz);
    80001e0e:	1684b583          	ld	a1,360(s1)
    80001e12:	00000097          	auipc	ra,0x0
    80001e16:	f86080e7          	jalr	-122(ra) # 80001d98 <proc_freepagetable>
  p->pagetable = 0;
    80001e1a:	1604b823          	sd	zero,368(s1)
  p->sz = 0;
    80001e1e:	1604b423          	sd	zero,360(s1)
  p->pid = 0;
    80001e22:	1404a823          	sw	zero,336(s1)
  p->parent = 0;
    80001e26:	1404bc23          	sd	zero,344(s1)
  p->name[0] = 0;
    80001e2a:	26048c23          	sb	zero,632(s1)
  p->chan = 0;
    80001e2e:	1404b023          	sd	zero,320(s1)
  p->killed = 0;
    80001e32:	1404a423          	sw	zero,328(s1)
  p->xstate = 0;
    80001e36:	1404a623          	sw	zero,332(s1)
  p->state = UNUSED;
    80001e3a:	1204ac23          	sw	zero,312(s1)
}
    80001e3e:	60e2                	ld	ra,24(sp)
    80001e40:	6442                	ld	s0,16(sp)
    80001e42:	64a2                	ld	s1,8(sp)
    80001e44:	6105                	addi	sp,sp,32
    80001e46:	8082                	ret

0000000080001e48 <allocproc>:
{
    80001e48:	7179                	addi	sp,sp,-48
    80001e4a:	f406                	sd	ra,40(sp)
    80001e4c:	f022                	sd	s0,32(sp)
    80001e4e:	ec26                	sd	s1,24(sp)
    80001e50:	e84a                	sd	s2,16(sp)
    80001e52:	e44e                	sd	s3,8(sp)
    80001e54:	1800                	addi	s0,sp,48
  for (p = proc; p < &proc[NPROC]; p++)
    80001e56:	0000f497          	auipc	s1,0xf
    80001e5a:	12a48493          	addi	s1,s1,298 # 80010f80 <proc>
    80001e5e:	0001a997          	auipc	s3,0x1a
    80001e62:	b2298993          	addi	s3,s3,-1246 # 8001b980 <tickslock>
    acquire(&p->lock);
    80001e66:	12048913          	addi	s2,s1,288
    80001e6a:	854a                	mv	a0,s2
    80001e6c:	fffff097          	auipc	ra,0xfffff
    80001e70:	dcc080e7          	jalr	-564(ra) # 80000c38 <acquire>
    if (p->state == UNUSED)
    80001e74:	1384a783          	lw	a5,312(s1)
    80001e78:	cf81                	beqz	a5,80001e90 <allocproc+0x48>
      release(&p->lock);
    80001e7a:	854a                	mv	a0,s2
    80001e7c:	fffff097          	auipc	ra,0xfffff
    80001e80:	e70080e7          	jalr	-400(ra) # 80000cec <release>
  for (p = proc; p < &proc[NPROC]; p++)
    80001e84:	2a848493          	addi	s1,s1,680
    80001e88:	fd349fe3          	bne	s1,s3,80001e66 <allocproc+0x1e>
  return 0;
    80001e8c:	4481                	li	s1,0
    80001e8e:	a049                	j	80001f10 <allocproc+0xc8>
  p->pid = allocpid();
    80001e90:	00000097          	auipc	ra,0x0
    80001e94:	e26080e7          	jalr	-474(ra) # 80001cb6 <allocpid>
    80001e98:	14a4a823          	sw	a0,336(s1)
  p->state = USED;
    80001e9c:	4785                	li	a5,1
    80001e9e:	12f4ac23          	sw	a5,312(s1)
  if ((p->trapframe = (struct trapframe *)kalloc()) == 0)
    80001ea2:	fffff097          	auipc	ra,0xfffff
    80001ea6:	ca6080e7          	jalr	-858(ra) # 80000b48 <kalloc>
    80001eaa:	89aa                	mv	s3,a0
    80001eac:	16a4bc23          	sd	a0,376(s1)
    80001eb0:	c925                	beqz	a0,80001f20 <allocproc+0xd8>
  p->pagetable = proc_pagetable(p);
    80001eb2:	8526                	mv	a0,s1
    80001eb4:	00000097          	auipc	ra,0x0
    80001eb8:	e48080e7          	jalr	-440(ra) # 80001cfc <proc_pagetable>
    80001ebc:	89aa                	mv	s3,a0
    80001ebe:	16a4b823          	sd	a0,368(s1)
  if (p->pagetable == 0)
    80001ec2:	c93d                	beqz	a0,80001f38 <allocproc+0xf0>
  memset(&p->context, 0, sizeof(p->context));
    80001ec4:	07000613          	li	a2,112
    80001ec8:	4581                	li	a1,0
    80001eca:	18048513          	addi	a0,s1,384
    80001ece:	fffff097          	auipc	ra,0xfffff
    80001ed2:	e66080e7          	jalr	-410(ra) # 80000d34 <memset>
  p->context.ra = (uint64)forkret;
    80001ed6:	00000797          	auipc	a5,0x0
    80001eda:	d9678793          	addi	a5,a5,-618 # 80001c6c <forkret>
    80001ede:	18f4b023          	sd	a5,384(s1)
  p->context.sp = p->kstack + PGSIZE;
    80001ee2:	1604b783          	ld	a5,352(s1)
    80001ee6:	6705                	lui	a4,0x1
    80001ee8:	97ba                	add	a5,a5,a4
    80001eea:	18f4b423          	sd	a5,392(s1)
  p->rtime = 0;
    80001eee:	2804a423          	sw	zero,648(s1)
  p->etime = 0;
    80001ef2:	2804a823          	sw	zero,656(s1)
  p->ctime = ticks;
    80001ef6:	00007797          	auipc	a5,0x7
    80001efa:	9f27a783          	lw	a5,-1550(a5) # 800088e8 <ticks>
    80001efe:	28f4a623          	sw	a5,652(s1)
  p->priority = 0;
    80001f02:	2804ac23          	sw	zero,664(s1)
  p->time_slice = 1;
    80001f06:	4785                	li	a5,1
    80001f08:	28f4ae23          	sw	a5,668(s1)
  p->queue_time = 0;
    80001f0c:	2a04a023          	sw	zero,672(s1)
}
    80001f10:	8526                	mv	a0,s1
    80001f12:	70a2                	ld	ra,40(sp)
    80001f14:	7402                	ld	s0,32(sp)
    80001f16:	64e2                	ld	s1,24(sp)
    80001f18:	6942                	ld	s2,16(sp)
    80001f1a:	69a2                	ld	s3,8(sp)
    80001f1c:	6145                	addi	sp,sp,48
    80001f1e:	8082                	ret
    freeproc(p);
    80001f20:	8526                	mv	a0,s1
    80001f22:	00000097          	auipc	ra,0x0
    80001f26:	ec8080e7          	jalr	-312(ra) # 80001dea <freeproc>
    release(&p->lock);
    80001f2a:	854a                	mv	a0,s2
    80001f2c:	fffff097          	auipc	ra,0xfffff
    80001f30:	dc0080e7          	jalr	-576(ra) # 80000cec <release>
    return 0;
    80001f34:	84ce                	mv	s1,s3
    80001f36:	bfe9                	j	80001f10 <allocproc+0xc8>
    freeproc(p);
    80001f38:	8526                	mv	a0,s1
    80001f3a:	00000097          	auipc	ra,0x0
    80001f3e:	eb0080e7          	jalr	-336(ra) # 80001dea <freeproc>
    release(&p->lock);
    80001f42:	854a                	mv	a0,s2
    80001f44:	fffff097          	auipc	ra,0xfffff
    80001f48:	da8080e7          	jalr	-600(ra) # 80000cec <release>
    return 0;
    80001f4c:	84ce                	mv	s1,s3
    80001f4e:	b7c9                	j	80001f10 <allocproc+0xc8>

0000000080001f50 <userinit>:
{
    80001f50:	1101                	addi	sp,sp,-32
    80001f52:	ec06                	sd	ra,24(sp)
    80001f54:	e822                	sd	s0,16(sp)
    80001f56:	e426                	sd	s1,8(sp)
    80001f58:	1000                	addi	s0,sp,32
  p = allocproc();
    80001f5a:	00000097          	auipc	ra,0x0
    80001f5e:	eee080e7          	jalr	-274(ra) # 80001e48 <allocproc>
    80001f62:	84aa                	mv	s1,a0
  initproc = p;
    80001f64:	00007797          	auipc	a5,0x7
    80001f68:	96a7be23          	sd	a0,-1668(a5) # 800088e0 <initproc>
  uvmfirst(p->pagetable, initcode, sizeof(initcode));
    80001f6c:	03400613          	li	a2,52
    80001f70:	00007597          	auipc	a1,0x7
    80001f74:	90058593          	addi	a1,a1,-1792 # 80008870 <initcode>
    80001f78:	17053503          	ld	a0,368(a0)
    80001f7c:	fffff097          	auipc	ra,0xfffff
    80001f80:	444080e7          	jalr	1092(ra) # 800013c0 <uvmfirst>
  p->sz = PGSIZE;
    80001f84:	6785                	lui	a5,0x1
    80001f86:	16f4b423          	sd	a5,360(s1)
  p->trapframe->epc = 0;     // user program counter
    80001f8a:	1784b703          	ld	a4,376(s1)
    80001f8e:	00073c23          	sd	zero,24(a4) # 1018 <_entry-0x7fffefe8>
  p->trapframe->sp = PGSIZE; // user stack pointer
    80001f92:	1784b703          	ld	a4,376(s1)
    80001f96:	fb1c                	sd	a5,48(a4)
  safestrcpy(p->name, "initcode", sizeof(p->name));
    80001f98:	4641                	li	a2,16
    80001f9a:	00006597          	auipc	a1,0x6
    80001f9e:	24658593          	addi	a1,a1,582 # 800081e0 <etext+0x1e0>
    80001fa2:	27848513          	addi	a0,s1,632
    80001fa6:	fffff097          	auipc	ra,0xfffff
    80001faa:	ed0080e7          	jalr	-304(ra) # 80000e76 <safestrcpy>
  p->cwd = namei("/");
    80001fae:	00006517          	auipc	a0,0x6
    80001fb2:	24250513          	addi	a0,a0,578 # 800081f0 <etext+0x1f0>
    80001fb6:	00002097          	auipc	ra,0x2
    80001fba:	696080e7          	jalr	1686(ra) # 8000464c <namei>
    80001fbe:	26a4b823          	sd	a0,624(s1)
  p->state = RUNNABLE;
    80001fc2:	478d                	li	a5,3
    80001fc4:	12f4ac23          	sw	a5,312(s1)
  release(&p->lock);
    80001fc8:	12048513          	addi	a0,s1,288
    80001fcc:	fffff097          	auipc	ra,0xfffff
    80001fd0:	d20080e7          	jalr	-736(ra) # 80000cec <release>
}
    80001fd4:	60e2                	ld	ra,24(sp)
    80001fd6:	6442                	ld	s0,16(sp)
    80001fd8:	64a2                	ld	s1,8(sp)
    80001fda:	6105                	addi	sp,sp,32
    80001fdc:	8082                	ret

0000000080001fde <growproc>:
{
    80001fde:	1101                	addi	sp,sp,-32
    80001fe0:	ec06                	sd	ra,24(sp)
    80001fe2:	e822                	sd	s0,16(sp)
    80001fe4:	e426                	sd	s1,8(sp)
    80001fe6:	e04a                	sd	s2,0(sp)
    80001fe8:	1000                	addi	s0,sp,32
    80001fea:	892a                	mv	s2,a0
  struct proc *p = myproc();
    80001fec:	00000097          	auipc	ra,0x0
    80001ff0:	c48080e7          	jalr	-952(ra) # 80001c34 <myproc>
    80001ff4:	84aa                	mv	s1,a0
  sz = p->sz;
    80001ff6:	16853583          	ld	a1,360(a0)
  if (n > 0)
    80001ffa:	01204d63          	bgtz	s2,80002014 <growproc+0x36>
  else if (n < 0)
    80001ffe:	02094863          	bltz	s2,8000202e <growproc+0x50>
  p->sz = sz;
    80002002:	16b4b423          	sd	a1,360(s1)
  return 0;
    80002006:	4501                	li	a0,0
}
    80002008:	60e2                	ld	ra,24(sp)
    8000200a:	6442                	ld	s0,16(sp)
    8000200c:	64a2                	ld	s1,8(sp)
    8000200e:	6902                	ld	s2,0(sp)
    80002010:	6105                	addi	sp,sp,32
    80002012:	8082                	ret
    if ((sz = uvmalloc(p->pagetable, sz, sz + n, PTE_W)) == 0)
    80002014:	4691                	li	a3,4
    80002016:	00b90633          	add	a2,s2,a1
    8000201a:	17053503          	ld	a0,368(a0)
    8000201e:	fffff097          	auipc	ra,0xfffff
    80002022:	45c080e7          	jalr	1116(ra) # 8000147a <uvmalloc>
    80002026:	85aa                	mv	a1,a0
    80002028:	fd69                	bnez	a0,80002002 <growproc+0x24>
      return -1;
    8000202a:	557d                	li	a0,-1
    8000202c:	bff1                	j	80002008 <growproc+0x2a>
    sz = uvmdealloc(p->pagetable, sz, sz + n);
    8000202e:	00b90633          	add	a2,s2,a1
    80002032:	17053503          	ld	a0,368(a0)
    80002036:	fffff097          	auipc	ra,0xfffff
    8000203a:	3fc080e7          	jalr	1020(ra) # 80001432 <uvmdealloc>
    8000203e:	85aa                	mv	a1,a0
    80002040:	b7c9                	j	80002002 <growproc+0x24>

0000000080002042 <fork>:
{
    80002042:	7139                	addi	sp,sp,-64
    80002044:	fc06                	sd	ra,56(sp)
    80002046:	f822                	sd	s0,48(sp)
    80002048:	ec4e                	sd	s3,24(sp)
    8000204a:	e456                	sd	s5,8(sp)
    8000204c:	0080                	addi	s0,sp,64
  struct proc *p = myproc();
    8000204e:	00000097          	auipc	ra,0x0
    80002052:	be6080e7          	jalr	-1050(ra) # 80001c34 <myproc>
    80002056:	8aaa                	mv	s5,a0
  if ((np = allocproc()) == 0)
    80002058:	00000097          	auipc	ra,0x0
    8000205c:	df0080e7          	jalr	-528(ra) # 80001e48 <allocproc>
    80002060:	12050463          	beqz	a0,80002188 <fork+0x146>
    80002064:	e852                	sd	s4,16(sp)
    80002066:	8a2a                	mv	s4,a0
  if (uvmcopy(p->pagetable, np->pagetable, p->sz) < 0)
    80002068:	168ab603          	ld	a2,360(s5)
    8000206c:	17053583          	ld	a1,368(a0)
    80002070:	170ab503          	ld	a0,368(s5)
    80002074:	fffff097          	auipc	ra,0xfffff
    80002078:	56a080e7          	jalr	1386(ra) # 800015de <uvmcopy>
    8000207c:	04054a63          	bltz	a0,800020d0 <fork+0x8e>
    80002080:	f426                	sd	s1,40(sp)
    80002082:	f04a                	sd	s2,32(sp)
  np->sz = p->sz;
    80002084:	168ab783          	ld	a5,360(s5)
    80002088:	16fa3423          	sd	a5,360(s4)
  *(np->trapframe) = *(p->trapframe);
    8000208c:	178ab683          	ld	a3,376(s5)
    80002090:	87b6                	mv	a5,a3
    80002092:	178a3703          	ld	a4,376(s4)
    80002096:	12068693          	addi	a3,a3,288
    8000209a:	0007b803          	ld	a6,0(a5) # 1000 <_entry-0x7ffff000>
    8000209e:	6788                	ld	a0,8(a5)
    800020a0:	6b8c                	ld	a1,16(a5)
    800020a2:	6f90                	ld	a2,24(a5)
    800020a4:	01073023          	sd	a6,0(a4)
    800020a8:	e708                	sd	a0,8(a4)
    800020aa:	eb0c                	sd	a1,16(a4)
    800020ac:	ef10                	sd	a2,24(a4)
    800020ae:	02078793          	addi	a5,a5,32
    800020b2:	02070713          	addi	a4,a4,32
    800020b6:	fed792e3          	bne	a5,a3,8000209a <fork+0x58>
  np->trapframe->a0 = 0;
    800020ba:	178a3783          	ld	a5,376(s4)
    800020be:	0607b823          	sd	zero,112(a5)
  for (i = 0; i < NOFILE; i++)
    800020c2:	1f0a8493          	addi	s1,s5,496
    800020c6:	1f0a0913          	addi	s2,s4,496
    800020ca:	270a8993          	addi	s3,s5,624
    800020ce:	a01d                	j	800020f4 <fork+0xb2>
    freeproc(np);
    800020d0:	8552                	mv	a0,s4
    800020d2:	00000097          	auipc	ra,0x0
    800020d6:	d18080e7          	jalr	-744(ra) # 80001dea <freeproc>
    release(&np->lock);
    800020da:	120a0513          	addi	a0,s4,288
    800020de:	fffff097          	auipc	ra,0xfffff
    800020e2:	c0e080e7          	jalr	-1010(ra) # 80000cec <release>
    return -1;
    800020e6:	59fd                	li	s3,-1
    800020e8:	6a42                	ld	s4,16(sp)
    800020ea:	a841                	j	8000217a <fork+0x138>
  for (i = 0; i < NOFILE; i++)
    800020ec:	04a1                	addi	s1,s1,8
    800020ee:	0921                	addi	s2,s2,8
    800020f0:	01348b63          	beq	s1,s3,80002106 <fork+0xc4>
    if (p->ofile[i])
    800020f4:	6088                	ld	a0,0(s1)
    800020f6:	d97d                	beqz	a0,800020ec <fork+0xaa>
      np->ofile[i] = filedup(p->ofile[i]);
    800020f8:	00003097          	auipc	ra,0x3
    800020fc:	bd0080e7          	jalr	-1072(ra) # 80004cc8 <filedup>
    80002100:	00a93023          	sd	a0,0(s2)
    80002104:	b7e5                	j	800020ec <fork+0xaa>
  np->cwd = idup(p->cwd);
    80002106:	270ab503          	ld	a0,624(s5)
    8000210a:	00002097          	auipc	ra,0x2
    8000210e:	d36080e7          	jalr	-714(ra) # 80003e40 <idup>
    80002112:	26aa3823          	sd	a0,624(s4)
  safestrcpy(np->name, p->name, sizeof(p->name));
    80002116:	4641                	li	a2,16
    80002118:	278a8593          	addi	a1,s5,632
    8000211c:	278a0513          	addi	a0,s4,632
    80002120:	fffff097          	auipc	ra,0xfffff
    80002124:	d56080e7          	jalr	-682(ra) # 80000e76 <safestrcpy>
  pid = np->pid;
    80002128:	150a2983          	lw	s3,336(s4)
  release(&np->lock);
    8000212c:	120a0493          	addi	s1,s4,288
    80002130:	8526                	mv	a0,s1
    80002132:	fffff097          	auipc	ra,0xfffff
    80002136:	bba080e7          	jalr	-1094(ra) # 80000cec <release>
  acquire(&wait_lock);
    8000213a:	0000f917          	auipc	s2,0xf
    8000213e:	a2e90913          	addi	s2,s2,-1490 # 80010b68 <wait_lock>
    80002142:	854a                	mv	a0,s2
    80002144:	fffff097          	auipc	ra,0xfffff
    80002148:	af4080e7          	jalr	-1292(ra) # 80000c38 <acquire>
  np->parent = p;
    8000214c:	155a3c23          	sd	s5,344(s4)
  release(&wait_lock);
    80002150:	854a                	mv	a0,s2
    80002152:	fffff097          	auipc	ra,0xfffff
    80002156:	b9a080e7          	jalr	-1126(ra) # 80000cec <release>
  acquire(&np->lock);
    8000215a:	8526                	mv	a0,s1
    8000215c:	fffff097          	auipc	ra,0xfffff
    80002160:	adc080e7          	jalr	-1316(ra) # 80000c38 <acquire>
  np->state = RUNNABLE;
    80002164:	478d                	li	a5,3
    80002166:	12fa2c23          	sw	a5,312(s4)
  release(&np->lock);
    8000216a:	8526                	mv	a0,s1
    8000216c:	fffff097          	auipc	ra,0xfffff
    80002170:	b80080e7          	jalr	-1152(ra) # 80000cec <release>
  return pid;
    80002174:	74a2                	ld	s1,40(sp)
    80002176:	7902                	ld	s2,32(sp)
    80002178:	6a42                	ld	s4,16(sp)
}
    8000217a:	854e                	mv	a0,s3
    8000217c:	70e2                	ld	ra,56(sp)
    8000217e:	7442                	ld	s0,48(sp)
    80002180:	69e2                	ld	s3,24(sp)
    80002182:	6aa2                	ld	s5,8(sp)
    80002184:	6121                	addi	sp,sp,64
    80002186:	8082                	ret
    return -1;
    80002188:	59fd                	li	s3,-1
    8000218a:	bfc5                	j	8000217a <fork+0x138>

000000008000218c <scheduler>:
{
    8000218c:	7159                	addi	sp,sp,-112
    8000218e:	f486                	sd	ra,104(sp)
    80002190:	f0a2                	sd	s0,96(sp)
    80002192:	eca6                	sd	s1,88(sp)
    80002194:	e8ca                	sd	s2,80(sp)
    80002196:	e4ce                	sd	s3,72(sp)
    80002198:	e0d2                	sd	s4,64(sp)
    8000219a:	fc56                	sd	s5,56(sp)
    8000219c:	f85a                	sd	s6,48(sp)
    8000219e:	f45e                	sd	s7,40(sp)
    800021a0:	f062                	sd	s8,32(sp)
    800021a2:	ec66                	sd	s9,24(sp)
    800021a4:	e86a                	sd	s10,16(sp)
    800021a6:	e46e                	sd	s11,8(sp)
    800021a8:	1880                	addi	s0,sp,112
    800021aa:	8792                	mv	a5,tp
  int id = r_tp();
    800021ac:	2781                	sext.w	a5,a5
  c->proc = 0;
    800021ae:	00779d93          	slli	s11,a5,0x7
    800021b2:	0000f717          	auipc	a4,0xf
    800021b6:	99e70713          	addi	a4,a4,-1634 # 80010b50 <pid_lock>
    800021ba:	976e                	add	a4,a4,s11
    800021bc:	02073823          	sd	zero,48(a4)
          swtch(&c->context, &p->context);
    800021c0:	0000f717          	auipc	a4,0xf
    800021c4:	9c870713          	addi	a4,a4,-1592 # 80010b88 <cpus+0x8>
    800021c8:	9dba                	add	s11,s11,a4
    if (++ticks_since_boost >= 48)
    800021ca:	00006b17          	auipc	s6,0x6
    800021ce:	70eb0b13          	addi	s6,s6,1806 # 800088d8 <ticks_since_boost.2>
    800021d2:	02f00d13          	li	s10,47
      for (p = proc; p < &proc[NPROC]; p++)
    800021d6:	4c81                	li	s9,0
    800021d8:	00019a17          	auipc	s4,0x19
    800021dc:	7a8a0a13          	addi	s4,s4,1960 # 8001b980 <tickslock>
    for (int priority = 0; priority < 4; priority++)
    800021e0:	4c11                	li	s8,4
          c->proc = p;
    800021e2:	079e                	slli	a5,a5,0x7
    800021e4:	0000fb97          	auipc	s7,0xf
    800021e8:	96cb8b93          	addi	s7,s7,-1684 # 80010b50 <pid_lock>
    800021ec:	9bbe                	add	s7,s7,a5
    800021ee:	a8a5                	j	80002266 <scheduler+0xda>
      boost_priority();
    800021f0:	00000097          	auipc	ra,0x0
    800021f4:	848080e7          	jalr	-1976(ra) # 80001a38 <boost_priority>
      ticks_since_boost = 0;
    800021f8:	000b2023          	sw	zero,0(s6)
    800021fc:	a069                	j	80002286 <scheduler+0xfa>
        release(&p->lock);
    800021fe:	854a                	mv	a0,s2
    80002200:	fffff097          	auipc	ra,0xfffff
    80002204:	aec080e7          	jalr	-1300(ra) # 80000cec <release>
      for (p = proc; p < &proc[NPROC]; p++)
    80002208:	2a848493          	addi	s1,s1,680
    8000220c:	09448363          	beq	s1,s4,80002292 <scheduler+0x106>
        acquire(&p->lock);
    80002210:	12048913          	addi	s2,s1,288
    80002214:	854a                	mv	a0,s2
    80002216:	fffff097          	auipc	ra,0xfffff
    8000221a:	a22080e7          	jalr	-1502(ra) # 80000c38 <acquire>
        if (p->state == RUNNABLE && p->priority == priority)
    8000221e:	1384a783          	lw	a5,312(s1)
    80002222:	fd379ee3          	bne	a5,s3,800021fe <scheduler+0x72>
    80002226:	2984a783          	lw	a5,664(s1)
    8000222a:	fd579ae3          	bne	a5,s5,800021fe <scheduler+0x72>
          p->state = RUNNING;
    8000222e:	1384ac23          	sw	s8,312(s1)
          c->proc = p;
    80002232:	029bb823          	sd	s1,48(s7)
          swtch(&c->context, &p->context);
    80002236:	18048593          	addi	a1,s1,384
    8000223a:	856e                	mv	a0,s11
    8000223c:	00001097          	auipc	ra,0x1
    80002240:	8fe080e7          	jalr	-1794(ra) # 80002b3a <swtch>
          c->proc = 0;
    80002244:	020bb823          	sd	zero,48(s7)
          p->queue_time++;
    80002248:	2a04a783          	lw	a5,672(s1)
    8000224c:	2785                	addiw	a5,a5,1
    8000224e:	2af4a023          	sw	a5,672(s1)
          update_priority(p);
    80002252:	8526                	mv	a0,s1
    80002254:	fffff097          	auipc	ra,0xfffff
    80002258:	778080e7          	jalr	1912(ra) # 800019cc <update_priority>
          release(&p->lock);
    8000225c:	854a                	mv	a0,s2
    8000225e:	fffff097          	auipc	ra,0xfffff
    80002262:	a8e080e7          	jalr	-1394(ra) # 80000cec <release>
        if (p->state == RUNNABLE && p->priority == priority)
    80002266:	498d                	li	s3,3
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80002268:	100027f3          	csrr	a5,sstatus
  w_sstatus(r_sstatus() | SSTATUS_SIE);
    8000226c:	0027e793          	ori	a5,a5,2
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80002270:	10079073          	csrw	sstatus,a5
    if (++ticks_since_boost >= 48)
    80002274:	000b2783          	lw	a5,0(s6)
    80002278:	2785                	addiw	a5,a5,1
    8000227a:	0007871b          	sext.w	a4,a5
    8000227e:	00fb2023          	sw	a5,0(s6)
    80002282:	f6ed47e3          	blt	s10,a4,800021f0 <scheduler+0x64>
      for (p = proc; p < &proc[NPROC]; p++)
    80002286:	8ae6                	mv	s5,s9
    80002288:	0000f497          	auipc	s1,0xf
    8000228c:	cf848493          	addi	s1,s1,-776 # 80010f80 <proc>
    80002290:	b741                	j	80002210 <scheduler+0x84>
    for (int priority = 0; priority < 4; priority++)
    80002292:	2a85                	addiw	s5,s5,1
    80002294:	ff8a9ae3          	bne	s5,s8,80002288 <scheduler+0xfc>
  found:;
    80002298:	bfc1                	j	80002268 <scheduler+0xdc>

000000008000229a <sched>:
{
    8000229a:	7179                	addi	sp,sp,-48
    8000229c:	f406                	sd	ra,40(sp)
    8000229e:	f022                	sd	s0,32(sp)
    800022a0:	ec26                	sd	s1,24(sp)
    800022a2:	e84a                	sd	s2,16(sp)
    800022a4:	e44e                	sd	s3,8(sp)
    800022a6:	1800                	addi	s0,sp,48
  struct proc *p = myproc();
    800022a8:	00000097          	auipc	ra,0x0
    800022ac:	98c080e7          	jalr	-1652(ra) # 80001c34 <myproc>
    800022b0:	84aa                	mv	s1,a0
  if (!holding(&p->lock))
    800022b2:	12050513          	addi	a0,a0,288
    800022b6:	fffff097          	auipc	ra,0xfffff
    800022ba:	908080e7          	jalr	-1784(ra) # 80000bbe <holding>
    800022be:	cd25                	beqz	a0,80002336 <sched+0x9c>
  asm volatile("mv %0, tp" : "=r" (x) );
    800022c0:	8792                	mv	a5,tp
  if (mycpu()->noff != 1)
    800022c2:	2781                	sext.w	a5,a5
    800022c4:	079e                	slli	a5,a5,0x7
    800022c6:	0000f717          	auipc	a4,0xf
    800022ca:	88a70713          	addi	a4,a4,-1910 # 80010b50 <pid_lock>
    800022ce:	97ba                	add	a5,a5,a4
    800022d0:	0a87a703          	lw	a4,168(a5)
    800022d4:	4785                	li	a5,1
    800022d6:	06f71863          	bne	a4,a5,80002346 <sched+0xac>
  if (p->state == RUNNING)
    800022da:	1384a703          	lw	a4,312(s1)
    800022de:	4791                	li	a5,4
    800022e0:	06f70b63          	beq	a4,a5,80002356 <sched+0xbc>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    800022e4:	100027f3          	csrr	a5,sstatus
  return (x & SSTATUS_SIE) != 0;
    800022e8:	8b89                	andi	a5,a5,2
  if (intr_get())
    800022ea:	efb5                	bnez	a5,80002366 <sched+0xcc>
  asm volatile("mv %0, tp" : "=r" (x) );
    800022ec:	8792                	mv	a5,tp
  intena = mycpu()->intena;
    800022ee:	0000f917          	auipc	s2,0xf
    800022f2:	86290913          	addi	s2,s2,-1950 # 80010b50 <pid_lock>
    800022f6:	2781                	sext.w	a5,a5
    800022f8:	079e                	slli	a5,a5,0x7
    800022fa:	97ca                	add	a5,a5,s2
    800022fc:	0ac7a983          	lw	s3,172(a5)
    80002300:	8792                	mv	a5,tp
  swtch(&p->context, &mycpu()->context);
    80002302:	2781                	sext.w	a5,a5
    80002304:	079e                	slli	a5,a5,0x7
    80002306:	0000f597          	auipc	a1,0xf
    8000230a:	88258593          	addi	a1,a1,-1918 # 80010b88 <cpus+0x8>
    8000230e:	95be                	add	a1,a1,a5
    80002310:	18048513          	addi	a0,s1,384
    80002314:	00001097          	auipc	ra,0x1
    80002318:	826080e7          	jalr	-2010(ra) # 80002b3a <swtch>
    8000231c:	8792                	mv	a5,tp
  mycpu()->intena = intena;
    8000231e:	2781                	sext.w	a5,a5
    80002320:	079e                	slli	a5,a5,0x7
    80002322:	993e                	add	s2,s2,a5
    80002324:	0b392623          	sw	s3,172(s2)
}
    80002328:	70a2                	ld	ra,40(sp)
    8000232a:	7402                	ld	s0,32(sp)
    8000232c:	64e2                	ld	s1,24(sp)
    8000232e:	6942                	ld	s2,16(sp)
    80002330:	69a2                	ld	s3,8(sp)
    80002332:	6145                	addi	sp,sp,48
    80002334:	8082                	ret
    panic("sched p->lock");
    80002336:	00006517          	auipc	a0,0x6
    8000233a:	ec250513          	addi	a0,a0,-318 # 800081f8 <etext+0x1f8>
    8000233e:	ffffe097          	auipc	ra,0xffffe
    80002342:	222080e7          	jalr	546(ra) # 80000560 <panic>
    panic("sched locks");
    80002346:	00006517          	auipc	a0,0x6
    8000234a:	ec250513          	addi	a0,a0,-318 # 80008208 <etext+0x208>
    8000234e:	ffffe097          	auipc	ra,0xffffe
    80002352:	212080e7          	jalr	530(ra) # 80000560 <panic>
    panic("sched running");
    80002356:	00006517          	auipc	a0,0x6
    8000235a:	ec250513          	addi	a0,a0,-318 # 80008218 <etext+0x218>
    8000235e:	ffffe097          	auipc	ra,0xffffe
    80002362:	202080e7          	jalr	514(ra) # 80000560 <panic>
    panic("sched interruptible");
    80002366:	00006517          	auipc	a0,0x6
    8000236a:	ec250513          	addi	a0,a0,-318 # 80008228 <etext+0x228>
    8000236e:	ffffe097          	auipc	ra,0xffffe
    80002372:	1f2080e7          	jalr	498(ra) # 80000560 <panic>

0000000080002376 <yield>:
{
    80002376:	1101                	addi	sp,sp,-32
    80002378:	ec06                	sd	ra,24(sp)
    8000237a:	e822                	sd	s0,16(sp)
    8000237c:	e426                	sd	s1,8(sp)
    8000237e:	e04a                	sd	s2,0(sp)
    80002380:	1000                	addi	s0,sp,32
  struct proc *p = myproc();
    80002382:	00000097          	auipc	ra,0x0
    80002386:	8b2080e7          	jalr	-1870(ra) # 80001c34 <myproc>
    8000238a:	84aa                	mv	s1,a0
  acquire(&p->lock);
    8000238c:	12050913          	addi	s2,a0,288
    80002390:	854a                	mv	a0,s2
    80002392:	fffff097          	auipc	ra,0xfffff
    80002396:	8a6080e7          	jalr	-1882(ra) # 80000c38 <acquire>
  p->state = RUNNABLE;
    8000239a:	478d                	li	a5,3
    8000239c:	12f4ac23          	sw	a5,312(s1)
  sched();
    800023a0:	00000097          	auipc	ra,0x0
    800023a4:	efa080e7          	jalr	-262(ra) # 8000229a <sched>
  release(&p->lock);
    800023a8:	854a                	mv	a0,s2
    800023aa:	fffff097          	auipc	ra,0xfffff
    800023ae:	942080e7          	jalr	-1726(ra) # 80000cec <release>
}
    800023b2:	60e2                	ld	ra,24(sp)
    800023b4:	6442                	ld	s0,16(sp)
    800023b6:	64a2                	ld	s1,8(sp)
    800023b8:	6902                	ld	s2,0(sp)
    800023ba:	6105                	addi	sp,sp,32
    800023bc:	8082                	ret

00000000800023be <sleep>:

// Atomically release lock and sleep on chan.
// Reacquires lock when awakened.
void sleep(void *chan, struct spinlock *lk)
{
    800023be:	7179                	addi	sp,sp,-48
    800023c0:	f406                	sd	ra,40(sp)
    800023c2:	f022                	sd	s0,32(sp)
    800023c4:	ec26                	sd	s1,24(sp)
    800023c6:	e84a                	sd	s2,16(sp)
    800023c8:	e44e                	sd	s3,8(sp)
    800023ca:	e052                	sd	s4,0(sp)
    800023cc:	1800                	addi	s0,sp,48
    800023ce:	89aa                	mv	s3,a0
    800023d0:	892e                	mv	s2,a1
  struct proc *p = myproc();
    800023d2:	00000097          	auipc	ra,0x0
    800023d6:	862080e7          	jalr	-1950(ra) # 80001c34 <myproc>
    800023da:	84aa                	mv	s1,a0
  // Once we hold p->lock, we can be
  // guaranteed that we won't miss any wakeup
  // (wakeup locks p->lock),
  // so it's okay to release lk.

  acquire(&p->lock); // DOC: sleeplock1
    800023dc:	12050a13          	addi	s4,a0,288
    800023e0:	8552                	mv	a0,s4
    800023e2:	fffff097          	auipc	ra,0xfffff
    800023e6:	856080e7          	jalr	-1962(ra) # 80000c38 <acquire>
  release(lk);
    800023ea:	854a                	mv	a0,s2
    800023ec:	fffff097          	auipc	ra,0xfffff
    800023f0:	900080e7          	jalr	-1792(ra) # 80000cec <release>

  // Go to sleep.
  p->chan = chan;
    800023f4:	1534b023          	sd	s3,320(s1)
  p->state = SLEEPING;
    800023f8:	4789                	li	a5,2
    800023fa:	12f4ac23          	sw	a5,312(s1)

  sched();
    800023fe:	00000097          	auipc	ra,0x0
    80002402:	e9c080e7          	jalr	-356(ra) # 8000229a <sched>

  // Tidy up.
  p->chan = 0;
    80002406:	1404b023          	sd	zero,320(s1)

  // Reacquire original lock.
  release(&p->lock);
    8000240a:	8552                	mv	a0,s4
    8000240c:	fffff097          	auipc	ra,0xfffff
    80002410:	8e0080e7          	jalr	-1824(ra) # 80000cec <release>
  acquire(lk);
    80002414:	854a                	mv	a0,s2
    80002416:	fffff097          	auipc	ra,0xfffff
    8000241a:	822080e7          	jalr	-2014(ra) # 80000c38 <acquire>
}
    8000241e:	70a2                	ld	ra,40(sp)
    80002420:	7402                	ld	s0,32(sp)
    80002422:	64e2                	ld	s1,24(sp)
    80002424:	6942                	ld	s2,16(sp)
    80002426:	69a2                	ld	s3,8(sp)
    80002428:	6a02                	ld	s4,0(sp)
    8000242a:	6145                	addi	sp,sp,48
    8000242c:	8082                	ret

000000008000242e <wakeup>:

// Wake up all processes sleeping on chan.
// Must be called without any p->lock.
void wakeup(void *chan)
{
    8000242e:	7139                	addi	sp,sp,-64
    80002430:	fc06                	sd	ra,56(sp)
    80002432:	f822                	sd	s0,48(sp)
    80002434:	f426                	sd	s1,40(sp)
    80002436:	f04a                	sd	s2,32(sp)
    80002438:	ec4e                	sd	s3,24(sp)
    8000243a:	e852                	sd	s4,16(sp)
    8000243c:	e456                	sd	s5,8(sp)
    8000243e:	e05a                	sd	s6,0(sp)
    80002440:	0080                	addi	s0,sp,64
    80002442:	8aaa                	mv	s5,a0
  struct proc *p;

  for (p = proc; p < &proc[NPROC]; p++)
    80002444:	0000f497          	auipc	s1,0xf
    80002448:	b3c48493          	addi	s1,s1,-1220 # 80010f80 <proc>
  {
    if (p != myproc())
    {
      acquire(&p->lock);
      if (p->state == SLEEPING && p->chan == chan)
    8000244c:	4a09                	li	s4,2
      {
        p->state = RUNNABLE;
    8000244e:	4b0d                	li	s6,3
  for (p = proc; p < &proc[NPROC]; p++)
    80002450:	00019997          	auipc	s3,0x19
    80002454:	53098993          	addi	s3,s3,1328 # 8001b980 <tickslock>
    80002458:	a811                	j	8000246c <wakeup+0x3e>
      }
      release(&p->lock);
    8000245a:	854a                	mv	a0,s2
    8000245c:	fffff097          	auipc	ra,0xfffff
    80002460:	890080e7          	jalr	-1904(ra) # 80000cec <release>
  for (p = proc; p < &proc[NPROC]; p++)
    80002464:	2a848493          	addi	s1,s1,680
    80002468:	03348a63          	beq	s1,s3,8000249c <wakeup+0x6e>
    if (p != myproc())
    8000246c:	fffff097          	auipc	ra,0xfffff
    80002470:	7c8080e7          	jalr	1992(ra) # 80001c34 <myproc>
    80002474:	fea488e3          	beq	s1,a0,80002464 <wakeup+0x36>
      acquire(&p->lock);
    80002478:	12048913          	addi	s2,s1,288
    8000247c:	854a                	mv	a0,s2
    8000247e:	ffffe097          	auipc	ra,0xffffe
    80002482:	7ba080e7          	jalr	1978(ra) # 80000c38 <acquire>
      if (p->state == SLEEPING && p->chan == chan)
    80002486:	1384a783          	lw	a5,312(s1)
    8000248a:	fd4798e3          	bne	a5,s4,8000245a <wakeup+0x2c>
    8000248e:	1404b783          	ld	a5,320(s1)
    80002492:	fd5794e3          	bne	a5,s5,8000245a <wakeup+0x2c>
        p->state = RUNNABLE;
    80002496:	1364ac23          	sw	s6,312(s1)
    8000249a:	b7c1                	j	8000245a <wakeup+0x2c>
    }
  }
}
    8000249c:	70e2                	ld	ra,56(sp)
    8000249e:	7442                	ld	s0,48(sp)
    800024a0:	74a2                	ld	s1,40(sp)
    800024a2:	7902                	ld	s2,32(sp)
    800024a4:	69e2                	ld	s3,24(sp)
    800024a6:	6a42                	ld	s4,16(sp)
    800024a8:	6aa2                	ld	s5,8(sp)
    800024aa:	6b02                	ld	s6,0(sp)
    800024ac:	6121                	addi	sp,sp,64
    800024ae:	8082                	ret

00000000800024b0 <reparent>:
{
    800024b0:	7179                	addi	sp,sp,-48
    800024b2:	f406                	sd	ra,40(sp)
    800024b4:	f022                	sd	s0,32(sp)
    800024b6:	ec26                	sd	s1,24(sp)
    800024b8:	e84a                	sd	s2,16(sp)
    800024ba:	e44e                	sd	s3,8(sp)
    800024bc:	e052                	sd	s4,0(sp)
    800024be:	1800                	addi	s0,sp,48
    800024c0:	892a                	mv	s2,a0
  for (pp = proc; pp < &proc[NPROC]; pp++)
    800024c2:	0000f497          	auipc	s1,0xf
    800024c6:	abe48493          	addi	s1,s1,-1346 # 80010f80 <proc>
      pp->parent = initproc;
    800024ca:	00006a17          	auipc	s4,0x6
    800024ce:	416a0a13          	addi	s4,s4,1046 # 800088e0 <initproc>
  for (pp = proc; pp < &proc[NPROC]; pp++)
    800024d2:	00019997          	auipc	s3,0x19
    800024d6:	4ae98993          	addi	s3,s3,1198 # 8001b980 <tickslock>
    800024da:	a029                	j	800024e4 <reparent+0x34>
    800024dc:	2a848493          	addi	s1,s1,680
    800024e0:	01348f63          	beq	s1,s3,800024fe <reparent+0x4e>
    if (pp->parent == p)
    800024e4:	1584b783          	ld	a5,344(s1)
    800024e8:	ff279ae3          	bne	a5,s2,800024dc <reparent+0x2c>
      pp->parent = initproc;
    800024ec:	000a3503          	ld	a0,0(s4)
    800024f0:	14a4bc23          	sd	a0,344(s1)
      wakeup(initproc);
    800024f4:	00000097          	auipc	ra,0x0
    800024f8:	f3a080e7          	jalr	-198(ra) # 8000242e <wakeup>
    800024fc:	b7c5                	j	800024dc <reparent+0x2c>
}
    800024fe:	70a2                	ld	ra,40(sp)
    80002500:	7402                	ld	s0,32(sp)
    80002502:	64e2                	ld	s1,24(sp)
    80002504:	6942                	ld	s2,16(sp)
    80002506:	69a2                	ld	s3,8(sp)
    80002508:	6a02                	ld	s4,0(sp)
    8000250a:	6145                	addi	sp,sp,48
    8000250c:	8082                	ret

000000008000250e <exit>:
{
    8000250e:	7179                	addi	sp,sp,-48
    80002510:	f406                	sd	ra,40(sp)
    80002512:	f022                	sd	s0,32(sp)
    80002514:	ec26                	sd	s1,24(sp)
    80002516:	e84a                	sd	s2,16(sp)
    80002518:	e44e                	sd	s3,8(sp)
    8000251a:	e052                	sd	s4,0(sp)
    8000251c:	1800                	addi	s0,sp,48
    8000251e:	8a2a                	mv	s4,a0
  struct proc *p = myproc();
    80002520:	fffff097          	auipc	ra,0xfffff
    80002524:	714080e7          	jalr	1812(ra) # 80001c34 <myproc>
    80002528:	89aa                	mv	s3,a0
  if (p == initproc)
    8000252a:	00006797          	auipc	a5,0x6
    8000252e:	3b67b783          	ld	a5,950(a5) # 800088e0 <initproc>
    80002532:	1f050493          	addi	s1,a0,496
    80002536:	27050913          	addi	s2,a0,624
    8000253a:	02a79363          	bne	a5,a0,80002560 <exit+0x52>
    panic("init exiting");
    8000253e:	00006517          	auipc	a0,0x6
    80002542:	d0250513          	addi	a0,a0,-766 # 80008240 <etext+0x240>
    80002546:	ffffe097          	auipc	ra,0xffffe
    8000254a:	01a080e7          	jalr	26(ra) # 80000560 <panic>
      fileclose(f);
    8000254e:	00002097          	auipc	ra,0x2
    80002552:	7cc080e7          	jalr	1996(ra) # 80004d1a <fileclose>
      p->ofile[fd] = 0;
    80002556:	0004b023          	sd	zero,0(s1)
  for (int fd = 0; fd < NOFILE; fd++)
    8000255a:	04a1                	addi	s1,s1,8
    8000255c:	01248563          	beq	s1,s2,80002566 <exit+0x58>
    if (p->ofile[fd])
    80002560:	6088                	ld	a0,0(s1)
    80002562:	f575                	bnez	a0,8000254e <exit+0x40>
    80002564:	bfdd                	j	8000255a <exit+0x4c>
  begin_op();
    80002566:	00002097          	auipc	ra,0x2
    8000256a:	2e6080e7          	jalr	742(ra) # 8000484c <begin_op>
  iput(p->cwd);
    8000256e:	2709b503          	ld	a0,624(s3)
    80002572:	00002097          	auipc	ra,0x2
    80002576:	aca080e7          	jalr	-1334(ra) # 8000403c <iput>
  end_op();
    8000257a:	00002097          	auipc	ra,0x2
    8000257e:	34c080e7          	jalr	844(ra) # 800048c6 <end_op>
  p->cwd = 0;
    80002582:	2609b823          	sd	zero,624(s3)
  acquire(&wait_lock);
    80002586:	0000e497          	auipc	s1,0xe
    8000258a:	5e248493          	addi	s1,s1,1506 # 80010b68 <wait_lock>
    8000258e:	8526                	mv	a0,s1
    80002590:	ffffe097          	auipc	ra,0xffffe
    80002594:	6a8080e7          	jalr	1704(ra) # 80000c38 <acquire>
  reparent(p);
    80002598:	854e                	mv	a0,s3
    8000259a:	00000097          	auipc	ra,0x0
    8000259e:	f16080e7          	jalr	-234(ra) # 800024b0 <reparent>
  wakeup(p->parent);
    800025a2:	1589b503          	ld	a0,344(s3)
    800025a6:	00000097          	auipc	ra,0x0
    800025aa:	e88080e7          	jalr	-376(ra) # 8000242e <wakeup>
  acquire(&p->lock);
    800025ae:	12098513          	addi	a0,s3,288
    800025b2:	ffffe097          	auipc	ra,0xffffe
    800025b6:	686080e7          	jalr	1670(ra) # 80000c38 <acquire>
  p->xstate = status;
    800025ba:	1549a623          	sw	s4,332(s3)
  p->state = ZOMBIE;
    800025be:	4795                	li	a5,5
    800025c0:	12f9ac23          	sw	a5,312(s3)
  p->etime = ticks;
    800025c4:	00006797          	auipc	a5,0x6
    800025c8:	3247a783          	lw	a5,804(a5) # 800088e8 <ticks>
    800025cc:	28f9a823          	sw	a5,656(s3)
  release(&wait_lock);
    800025d0:	8526                	mv	a0,s1
    800025d2:	ffffe097          	auipc	ra,0xffffe
    800025d6:	71a080e7          	jalr	1818(ra) # 80000cec <release>
  sched();
    800025da:	00000097          	auipc	ra,0x0
    800025de:	cc0080e7          	jalr	-832(ra) # 8000229a <sched>
  panic("zombie exit");
    800025e2:	00006517          	auipc	a0,0x6
    800025e6:	c6e50513          	addi	a0,a0,-914 # 80008250 <etext+0x250>
    800025ea:	ffffe097          	auipc	ra,0xffffe
    800025ee:	f76080e7          	jalr	-138(ra) # 80000560 <panic>

00000000800025f2 <kill>:

// Kill the process with the given pid.
// The victim won't exit until it tries to return
// to user space (see usertrap() in trap.c).
int kill(int pid)
{
    800025f2:	7179                	addi	sp,sp,-48
    800025f4:	f406                	sd	ra,40(sp)
    800025f6:	f022                	sd	s0,32(sp)
    800025f8:	ec26                	sd	s1,24(sp)
    800025fa:	e84a                	sd	s2,16(sp)
    800025fc:	e44e                	sd	s3,8(sp)
    800025fe:	e052                	sd	s4,0(sp)
    80002600:	1800                	addi	s0,sp,48
    80002602:	89aa                	mv	s3,a0
  struct proc *p;

  for (p = proc; p < &proc[NPROC]; p++)
    80002604:	0000f497          	auipc	s1,0xf
    80002608:	97c48493          	addi	s1,s1,-1668 # 80010f80 <proc>
    8000260c:	00019a17          	auipc	s4,0x19
    80002610:	374a0a13          	addi	s4,s4,884 # 8001b980 <tickslock>
  {
    acquire(&p->lock);
    80002614:	12048913          	addi	s2,s1,288
    80002618:	854a                	mv	a0,s2
    8000261a:	ffffe097          	auipc	ra,0xffffe
    8000261e:	61e080e7          	jalr	1566(ra) # 80000c38 <acquire>
    if (p->pid == pid)
    80002622:	1504a783          	lw	a5,336(s1)
    80002626:	01378d63          	beq	a5,s3,80002640 <kill+0x4e>
        p->state = RUNNABLE;
      }
      release(&p->lock);
      return 0;
    }
    release(&p->lock);
    8000262a:	854a                	mv	a0,s2
    8000262c:	ffffe097          	auipc	ra,0xffffe
    80002630:	6c0080e7          	jalr	1728(ra) # 80000cec <release>
  for (p = proc; p < &proc[NPROC]; p++)
    80002634:	2a848493          	addi	s1,s1,680
    80002638:	fd449ee3          	bne	s1,s4,80002614 <kill+0x22>
  }
  return -1;
    8000263c:	557d                	li	a0,-1
    8000263e:	a839                	j	8000265c <kill+0x6a>
      p->killed = 1;
    80002640:	4785                	li	a5,1
    80002642:	14f4a423          	sw	a5,328(s1)
      if (p->state == SLEEPING)
    80002646:	1384a703          	lw	a4,312(s1)
    8000264a:	4789                	li	a5,2
    8000264c:	02f70063          	beq	a4,a5,8000266c <kill+0x7a>
      release(&p->lock);
    80002650:	854a                	mv	a0,s2
    80002652:	ffffe097          	auipc	ra,0xffffe
    80002656:	69a080e7          	jalr	1690(ra) # 80000cec <release>
      return 0;
    8000265a:	4501                	li	a0,0
}
    8000265c:	70a2                	ld	ra,40(sp)
    8000265e:	7402                	ld	s0,32(sp)
    80002660:	64e2                	ld	s1,24(sp)
    80002662:	6942                	ld	s2,16(sp)
    80002664:	69a2                	ld	s3,8(sp)
    80002666:	6a02                	ld	s4,0(sp)
    80002668:	6145                	addi	sp,sp,48
    8000266a:	8082                	ret
        p->state = RUNNABLE;
    8000266c:	478d                	li	a5,3
    8000266e:	12f4ac23          	sw	a5,312(s1)
    80002672:	bff9                	j	80002650 <kill+0x5e>

0000000080002674 <setkilled>:

void setkilled(struct proc *p)
{
    80002674:	1101                	addi	sp,sp,-32
    80002676:	ec06                	sd	ra,24(sp)
    80002678:	e822                	sd	s0,16(sp)
    8000267a:	e426                	sd	s1,8(sp)
    8000267c:	e04a                	sd	s2,0(sp)
    8000267e:	1000                	addi	s0,sp,32
    80002680:	84aa                	mv	s1,a0
  acquire(&p->lock);
    80002682:	12050913          	addi	s2,a0,288
    80002686:	854a                	mv	a0,s2
    80002688:	ffffe097          	auipc	ra,0xffffe
    8000268c:	5b0080e7          	jalr	1456(ra) # 80000c38 <acquire>
  p->killed = 1;
    80002690:	4785                	li	a5,1
    80002692:	14f4a423          	sw	a5,328(s1)
  release(&p->lock);
    80002696:	854a                	mv	a0,s2
    80002698:	ffffe097          	auipc	ra,0xffffe
    8000269c:	654080e7          	jalr	1620(ra) # 80000cec <release>
}
    800026a0:	60e2                	ld	ra,24(sp)
    800026a2:	6442                	ld	s0,16(sp)
    800026a4:	64a2                	ld	s1,8(sp)
    800026a6:	6902                	ld	s2,0(sp)
    800026a8:	6105                	addi	sp,sp,32
    800026aa:	8082                	ret

00000000800026ac <killed>:

int killed(struct proc *p)
{
    800026ac:	1101                	addi	sp,sp,-32
    800026ae:	ec06                	sd	ra,24(sp)
    800026b0:	e822                	sd	s0,16(sp)
    800026b2:	e426                	sd	s1,8(sp)
    800026b4:	e04a                	sd	s2,0(sp)
    800026b6:	1000                	addi	s0,sp,32
    800026b8:	84aa                	mv	s1,a0
  int k;

  acquire(&p->lock);
    800026ba:	12050913          	addi	s2,a0,288
    800026be:	854a                	mv	a0,s2
    800026c0:	ffffe097          	auipc	ra,0xffffe
    800026c4:	578080e7          	jalr	1400(ra) # 80000c38 <acquire>
  k = p->killed;
    800026c8:	1484a483          	lw	s1,328(s1)
  release(&p->lock);
    800026cc:	854a                	mv	a0,s2
    800026ce:	ffffe097          	auipc	ra,0xffffe
    800026d2:	61e080e7          	jalr	1566(ra) # 80000cec <release>
  return k;
}
    800026d6:	8526                	mv	a0,s1
    800026d8:	60e2                	ld	ra,24(sp)
    800026da:	6442                	ld	s0,16(sp)
    800026dc:	64a2                	ld	s1,8(sp)
    800026de:	6902                	ld	s2,0(sp)
    800026e0:	6105                	addi	sp,sp,32
    800026e2:	8082                	ret

00000000800026e4 <wait>:
{
    800026e4:	711d                	addi	sp,sp,-96
    800026e6:	ec86                	sd	ra,88(sp)
    800026e8:	e8a2                	sd	s0,80(sp)
    800026ea:	e4a6                	sd	s1,72(sp)
    800026ec:	e0ca                	sd	s2,64(sp)
    800026ee:	fc4e                	sd	s3,56(sp)
    800026f0:	f852                	sd	s4,48(sp)
    800026f2:	f456                	sd	s5,40(sp)
    800026f4:	f05a                	sd	s6,32(sp)
    800026f6:	ec5e                	sd	s7,24(sp)
    800026f8:	e862                	sd	s8,16(sp)
    800026fa:	e466                	sd	s9,8(sp)
    800026fc:	1080                	addi	s0,sp,96
    800026fe:	8baa                	mv	s7,a0
  struct proc *p = myproc();
    80002700:	fffff097          	auipc	ra,0xfffff
    80002704:	534080e7          	jalr	1332(ra) # 80001c34 <myproc>
    80002708:	892a                	mv	s2,a0
  acquire(&wait_lock);
    8000270a:	0000e517          	auipc	a0,0xe
    8000270e:	45e50513          	addi	a0,a0,1118 # 80010b68 <wait_lock>
    80002712:	ffffe097          	auipc	ra,0xffffe
    80002716:	526080e7          	jalr	1318(ra) # 80000c38 <acquire>
    havekids = 0;
    8000271a:	4c01                	li	s8,0
        if (pp->state == ZOMBIE)
    8000271c:	4a95                	li	s5,5
        havekids = 1;
    8000271e:	4b05                	li	s6,1
    for (pp = proc; pp < &proc[NPROC]; pp++)
    80002720:	00019997          	auipc	s3,0x19
    80002724:	26098993          	addi	s3,s3,608 # 8001b980 <tickslock>
    sleep(p, &wait_lock); // DOC: wait-sleep
    80002728:	0000ec97          	auipc	s9,0xe
    8000272c:	440c8c93          	addi	s9,s9,1088 # 80010b68 <wait_lock>
    80002730:	a0f9                	j	800027fe <wait+0x11a>
          pid = pp->pid;
    80002732:	1504a983          	lw	s3,336(s1)
          if (addr != 0 && copyout(p->pagetable, addr, (char *)&pp->xstate,
    80002736:	000b8e63          	beqz	s7,80002752 <wait+0x6e>
    8000273a:	4691                	li	a3,4
    8000273c:	14c48613          	addi	a2,s1,332
    80002740:	85de                	mv	a1,s7
    80002742:	17093503          	ld	a0,368(s2)
    80002746:	fffff097          	auipc	ra,0xfffff
    8000274a:	f9c080e7          	jalr	-100(ra) # 800016e2 <copyout>
    8000274e:	04054263          	bltz	a0,80002792 <wait+0xae>
          freeproc(pp);
    80002752:	8526                	mv	a0,s1
    80002754:	fffff097          	auipc	ra,0xfffff
    80002758:	696080e7          	jalr	1686(ra) # 80001dea <freeproc>
          release(&pp->lock);
    8000275c:	8552                	mv	a0,s4
    8000275e:	ffffe097          	auipc	ra,0xffffe
    80002762:	58e080e7          	jalr	1422(ra) # 80000cec <release>
          release(&wait_lock);
    80002766:	0000e517          	auipc	a0,0xe
    8000276a:	40250513          	addi	a0,a0,1026 # 80010b68 <wait_lock>
    8000276e:	ffffe097          	auipc	ra,0xffffe
    80002772:	57e080e7          	jalr	1406(ra) # 80000cec <release>
}
    80002776:	854e                	mv	a0,s3
    80002778:	60e6                	ld	ra,88(sp)
    8000277a:	6446                	ld	s0,80(sp)
    8000277c:	64a6                	ld	s1,72(sp)
    8000277e:	6906                	ld	s2,64(sp)
    80002780:	79e2                	ld	s3,56(sp)
    80002782:	7a42                	ld	s4,48(sp)
    80002784:	7aa2                	ld	s5,40(sp)
    80002786:	7b02                	ld	s6,32(sp)
    80002788:	6be2                	ld	s7,24(sp)
    8000278a:	6c42                	ld	s8,16(sp)
    8000278c:	6ca2                	ld	s9,8(sp)
    8000278e:	6125                	addi	sp,sp,96
    80002790:	8082                	ret
            release(&pp->lock);
    80002792:	8552                	mv	a0,s4
    80002794:	ffffe097          	auipc	ra,0xffffe
    80002798:	558080e7          	jalr	1368(ra) # 80000cec <release>
            release(&wait_lock);
    8000279c:	0000e517          	auipc	a0,0xe
    800027a0:	3cc50513          	addi	a0,a0,972 # 80010b68 <wait_lock>
    800027a4:	ffffe097          	auipc	ra,0xffffe
    800027a8:	548080e7          	jalr	1352(ra) # 80000cec <release>
            return -1;
    800027ac:	59fd                	li	s3,-1
    800027ae:	b7e1                	j	80002776 <wait+0x92>
    for (pp = proc; pp < &proc[NPROC]; pp++)
    800027b0:	2a848493          	addi	s1,s1,680
    800027b4:	03348863          	beq	s1,s3,800027e4 <wait+0x100>
      if (pp->parent == p)
    800027b8:	1584b783          	ld	a5,344(s1)
    800027bc:	ff279ae3          	bne	a5,s2,800027b0 <wait+0xcc>
        acquire(&pp->lock);
    800027c0:	12048a13          	addi	s4,s1,288
    800027c4:	8552                	mv	a0,s4
    800027c6:	ffffe097          	auipc	ra,0xffffe
    800027ca:	472080e7          	jalr	1138(ra) # 80000c38 <acquire>
        if (pp->state == ZOMBIE)
    800027ce:	1384a783          	lw	a5,312(s1)
    800027d2:	f75780e3          	beq	a5,s5,80002732 <wait+0x4e>
        release(&pp->lock);
    800027d6:	8552                	mv	a0,s4
    800027d8:	ffffe097          	auipc	ra,0xffffe
    800027dc:	514080e7          	jalr	1300(ra) # 80000cec <release>
        havekids = 1;
    800027e0:	875a                	mv	a4,s6
    800027e2:	b7f9                	j	800027b0 <wait+0xcc>
    if (!havekids || killed(p))
    800027e4:	c31d                	beqz	a4,8000280a <wait+0x126>
    800027e6:	854a                	mv	a0,s2
    800027e8:	00000097          	auipc	ra,0x0
    800027ec:	ec4080e7          	jalr	-316(ra) # 800026ac <killed>
    800027f0:	ed09                	bnez	a0,8000280a <wait+0x126>
    sleep(p, &wait_lock); // DOC: wait-sleep
    800027f2:	85e6                	mv	a1,s9
    800027f4:	854a                	mv	a0,s2
    800027f6:	00000097          	auipc	ra,0x0
    800027fa:	bc8080e7          	jalr	-1080(ra) # 800023be <sleep>
    havekids = 0;
    800027fe:	8762                	mv	a4,s8
    for (pp = proc; pp < &proc[NPROC]; pp++)
    80002800:	0000e497          	auipc	s1,0xe
    80002804:	78048493          	addi	s1,s1,1920 # 80010f80 <proc>
    80002808:	bf45                	j	800027b8 <wait+0xd4>
      release(&wait_lock);
    8000280a:	0000e517          	auipc	a0,0xe
    8000280e:	35e50513          	addi	a0,a0,862 # 80010b68 <wait_lock>
    80002812:	ffffe097          	auipc	ra,0xffffe
    80002816:	4da080e7          	jalr	1242(ra) # 80000cec <release>
      return -1;
    8000281a:	59fd                	li	s3,-1
    8000281c:	bfa9                	j	80002776 <wait+0x92>

000000008000281e <either_copyout>:

// Copy to either a user address, or kernel address,
// depending on usr_dst.
// Returns 0 on success, -1 on error.
int either_copyout(int user_dst, uint64 dst, void *src, uint64 len)
{
    8000281e:	7179                	addi	sp,sp,-48
    80002820:	f406                	sd	ra,40(sp)
    80002822:	f022                	sd	s0,32(sp)
    80002824:	ec26                	sd	s1,24(sp)
    80002826:	e84a                	sd	s2,16(sp)
    80002828:	e44e                	sd	s3,8(sp)
    8000282a:	e052                	sd	s4,0(sp)
    8000282c:	1800                	addi	s0,sp,48
    8000282e:	84aa                	mv	s1,a0
    80002830:	892e                	mv	s2,a1
    80002832:	89b2                	mv	s3,a2
    80002834:	8a36                	mv	s4,a3
  struct proc *p = myproc();
    80002836:	fffff097          	auipc	ra,0xfffff
    8000283a:	3fe080e7          	jalr	1022(ra) # 80001c34 <myproc>
  if (user_dst)
    8000283e:	c095                	beqz	s1,80002862 <either_copyout+0x44>
  {
    return copyout(p->pagetable, dst, src, len);
    80002840:	86d2                	mv	a3,s4
    80002842:	864e                	mv	a2,s3
    80002844:	85ca                	mv	a1,s2
    80002846:	17053503          	ld	a0,368(a0)
    8000284a:	fffff097          	auipc	ra,0xfffff
    8000284e:	e98080e7          	jalr	-360(ra) # 800016e2 <copyout>
  else
  {
    memmove((char *)dst, src, len);
    return 0;
  }
}
    80002852:	70a2                	ld	ra,40(sp)
    80002854:	7402                	ld	s0,32(sp)
    80002856:	64e2                	ld	s1,24(sp)
    80002858:	6942                	ld	s2,16(sp)
    8000285a:	69a2                	ld	s3,8(sp)
    8000285c:	6a02                	ld	s4,0(sp)
    8000285e:	6145                	addi	sp,sp,48
    80002860:	8082                	ret
    memmove((char *)dst, src, len);
    80002862:	000a061b          	sext.w	a2,s4
    80002866:	85ce                	mv	a1,s3
    80002868:	854a                	mv	a0,s2
    8000286a:	ffffe097          	auipc	ra,0xffffe
    8000286e:	526080e7          	jalr	1318(ra) # 80000d90 <memmove>
    return 0;
    80002872:	8526                	mv	a0,s1
    80002874:	bff9                	j	80002852 <either_copyout+0x34>

0000000080002876 <either_copyin>:

// Copy from either a user address, or kernel address,
// depending on usr_src.
// Returns 0 on success, -1 on error.
int either_copyin(void *dst, int user_src, uint64 src, uint64 len)
{
    80002876:	7179                	addi	sp,sp,-48
    80002878:	f406                	sd	ra,40(sp)
    8000287a:	f022                	sd	s0,32(sp)
    8000287c:	ec26                	sd	s1,24(sp)
    8000287e:	e84a                	sd	s2,16(sp)
    80002880:	e44e                	sd	s3,8(sp)
    80002882:	e052                	sd	s4,0(sp)
    80002884:	1800                	addi	s0,sp,48
    80002886:	892a                	mv	s2,a0
    80002888:	84ae                	mv	s1,a1
    8000288a:	89b2                	mv	s3,a2
    8000288c:	8a36                	mv	s4,a3
  struct proc *p = myproc();
    8000288e:	fffff097          	auipc	ra,0xfffff
    80002892:	3a6080e7          	jalr	934(ra) # 80001c34 <myproc>
  if (user_src)
    80002896:	c095                	beqz	s1,800028ba <either_copyin+0x44>
  {
    return copyin(p->pagetable, dst, src, len);
    80002898:	86d2                	mv	a3,s4
    8000289a:	864e                	mv	a2,s3
    8000289c:	85ca                	mv	a1,s2
    8000289e:	17053503          	ld	a0,368(a0)
    800028a2:	fffff097          	auipc	ra,0xfffff
    800028a6:	ecc080e7          	jalr	-308(ra) # 8000176e <copyin>
  else
  {
    memmove(dst, (char *)src, len);
    return 0;
  }
}
    800028aa:	70a2                	ld	ra,40(sp)
    800028ac:	7402                	ld	s0,32(sp)
    800028ae:	64e2                	ld	s1,24(sp)
    800028b0:	6942                	ld	s2,16(sp)
    800028b2:	69a2                	ld	s3,8(sp)
    800028b4:	6a02                	ld	s4,0(sp)
    800028b6:	6145                	addi	sp,sp,48
    800028b8:	8082                	ret
    memmove(dst, (char *)src, len);
    800028ba:	000a061b          	sext.w	a2,s4
    800028be:	85ce                	mv	a1,s3
    800028c0:	854a                	mv	a0,s2
    800028c2:	ffffe097          	auipc	ra,0xffffe
    800028c6:	4ce080e7          	jalr	1230(ra) # 80000d90 <memmove>
    return 0;
    800028ca:	8526                	mv	a0,s1
    800028cc:	bff9                	j	800028aa <either_copyin+0x34>

00000000800028ce <procdump>:

// Print a process listing to console.  For debugging.
// Runs when user types ^P on console.
// No lock to avoid wedging a stuck machine further.
void procdump(void)
{
    800028ce:	715d                	addi	sp,sp,-80
    800028d0:	e486                	sd	ra,72(sp)
    800028d2:	e0a2                	sd	s0,64(sp)
    800028d4:	fc26                	sd	s1,56(sp)
    800028d6:	f84a                	sd	s2,48(sp)
    800028d8:	f44e                	sd	s3,40(sp)
    800028da:	f052                	sd	s4,32(sp)
    800028dc:	ec56                	sd	s5,24(sp)
    800028de:	e85a                	sd	s6,16(sp)
    800028e0:	e45e                	sd	s7,8(sp)
    800028e2:	0880                	addi	s0,sp,80
      [RUNNING] "run   ",
      [ZOMBIE] "zombie"};
  struct proc *p;
  char *state;

  printf("\n");
    800028e4:	00005517          	auipc	a0,0x5
    800028e8:	72c50513          	addi	a0,a0,1836 # 80008010 <etext+0x10>
    800028ec:	ffffe097          	auipc	ra,0xffffe
    800028f0:	cbe080e7          	jalr	-834(ra) # 800005aa <printf>
  for (p = proc; p < &proc[NPROC]; p++)
    800028f4:	0000f497          	auipc	s1,0xf
    800028f8:	90448493          	addi	s1,s1,-1788 # 800111f8 <proc+0x278>
    800028fc:	00019917          	auipc	s2,0x19
    80002900:	2fc90913          	addi	s2,s2,764 # 8001bbf8 <syscall_counts+0x260>
  {
    if (p->state == UNUSED)
      continue;
    if (p->state >= 0 && p->state < NELEM(states) && states[p->state])
    80002904:	4b15                	li	s6,5
      state = states[p->state];
    else
      state = "???";
    80002906:	00006997          	auipc	s3,0x6
    8000290a:	95a98993          	addi	s3,s3,-1702 # 80008260 <etext+0x260>
    printf("%d %s %s", p->pid, state, p->name);
    8000290e:	00006a97          	auipc	s5,0x6
    80002912:	95aa8a93          	addi	s5,s5,-1702 # 80008268 <etext+0x268>
    printf("\n");
    80002916:	00005a17          	auipc	s4,0x5
    8000291a:	6faa0a13          	addi	s4,s4,1786 # 80008010 <etext+0x10>
    if (p->state >= 0 && p->state < NELEM(states) && states[p->state])
    8000291e:	00006b97          	auipc	s7,0x6
    80002922:	e22b8b93          	addi	s7,s7,-478 # 80008740 <states.0>
    80002926:	a00d                	j	80002948 <procdump+0x7a>
    printf("%d %s %s", p->pid, state, p->name);
    80002928:	ed86a583          	lw	a1,-296(a3)
    8000292c:	8556                	mv	a0,s5
    8000292e:	ffffe097          	auipc	ra,0xffffe
    80002932:	c7c080e7          	jalr	-900(ra) # 800005aa <printf>
    printf("\n");
    80002936:	8552                	mv	a0,s4
    80002938:	ffffe097          	auipc	ra,0xffffe
    8000293c:	c72080e7          	jalr	-910(ra) # 800005aa <printf>
  for (p = proc; p < &proc[NPROC]; p++)
    80002940:	2a848493          	addi	s1,s1,680
    80002944:	03248263          	beq	s1,s2,80002968 <procdump+0x9a>
    if (p->state == UNUSED)
    80002948:	86a6                	mv	a3,s1
    8000294a:	ec04a783          	lw	a5,-320(s1)
    8000294e:	dbed                	beqz	a5,80002940 <procdump+0x72>
      state = "???";
    80002950:	864e                	mv	a2,s3
    if (p->state >= 0 && p->state < NELEM(states) && states[p->state])
    80002952:	fcfb6be3          	bltu	s6,a5,80002928 <procdump+0x5a>
    80002956:	02079713          	slli	a4,a5,0x20
    8000295a:	01d75793          	srli	a5,a4,0x1d
    8000295e:	97de                	add	a5,a5,s7
    80002960:	6390                	ld	a2,0(a5)
    80002962:	f279                	bnez	a2,80002928 <procdump+0x5a>
      state = "???";
    80002964:	864e                	mv	a2,s3
    80002966:	b7c9                	j	80002928 <procdump+0x5a>
  }
}
    80002968:	60a6                	ld	ra,72(sp)
    8000296a:	6406                	ld	s0,64(sp)
    8000296c:	74e2                	ld	s1,56(sp)
    8000296e:	7942                	ld	s2,48(sp)
    80002970:	79a2                	ld	s3,40(sp)
    80002972:	7a02                	ld	s4,32(sp)
    80002974:	6ae2                	ld	s5,24(sp)
    80002976:	6b42                	ld	s6,16(sp)
    80002978:	6ba2                	ld	s7,8(sp)
    8000297a:	6161                	addi	sp,sp,80
    8000297c:	8082                	ret

000000008000297e <waitx>:

// waitx
int waitx(uint64 addr, uint *wtime, uint *rtime)
{
    8000297e:	7159                	addi	sp,sp,-112
    80002980:	f486                	sd	ra,104(sp)
    80002982:	f0a2                	sd	s0,96(sp)
    80002984:	eca6                	sd	s1,88(sp)
    80002986:	e8ca                	sd	s2,80(sp)
    80002988:	e4ce                	sd	s3,72(sp)
    8000298a:	e0d2                	sd	s4,64(sp)
    8000298c:	fc56                	sd	s5,56(sp)
    8000298e:	f85a                	sd	s6,48(sp)
    80002990:	f45e                	sd	s7,40(sp)
    80002992:	f062                	sd	s8,32(sp)
    80002994:	ec66                	sd	s9,24(sp)
    80002996:	e86a                	sd	s10,16(sp)
    80002998:	e46e                	sd	s11,8(sp)
    8000299a:	1880                	addi	s0,sp,112
    8000299c:	8b2a                	mv	s6,a0
    8000299e:	8bae                	mv	s7,a1
    800029a0:	8c32                	mv	s8,a2
  struct proc *np;
  int havekids, pid;
  struct proc *p = myproc();
    800029a2:	fffff097          	auipc	ra,0xfffff
    800029a6:	292080e7          	jalr	658(ra) # 80001c34 <myproc>
    800029aa:	892a                	mv	s2,a0

  acquire(&wait_lock);
    800029ac:	0000e517          	auipc	a0,0xe
    800029b0:	1bc50513          	addi	a0,a0,444 # 80010b68 <wait_lock>
    800029b4:	ffffe097          	auipc	ra,0xffffe
    800029b8:	284080e7          	jalr	644(ra) # 80000c38 <acquire>

  for (;;)
  {
    // Scan through table looking for exited children.
    havekids = 0;
    800029bc:	4c81                	li	s9,0
      {
        // make sure the child isn't still in exit() or swtch().
        acquire(&np->lock);

        havekids = 1;
        if (np->state == ZOMBIE)
    800029be:	4a15                	li	s4,5
        havekids = 1;
    800029c0:	4a85                	li	s5,1
    for (np = proc; np < &proc[NPROC]; np++)
    800029c2:	00019997          	auipc	s3,0x19
    800029c6:	fbe98993          	addi	s3,s3,-66 # 8001b980 <tickslock>
      release(&wait_lock);
      return -1;
    }

    // Wait for a child to exit.
    sleep(p, &wait_lock); // DOC: wait-sleep
    800029ca:	0000ed17          	auipc	s10,0xe
    800029ce:	19ed0d13          	addi	s10,s10,414 # 80010b68 <wait_lock>
    800029d2:	a0d5                	j	80002ab6 <waitx+0x138>
          pid = np->pid;
    800029d4:	1504a983          	lw	s3,336(s1)
          *rtime = np->rtime;
    800029d8:	2884a783          	lw	a5,648(s1)
    800029dc:	00fc2023          	sw	a5,0(s8)
          *wtime = np->etime - np->ctime - np->rtime;
    800029e0:	28c4a703          	lw	a4,652(s1)
    800029e4:	9f3d                	addw	a4,a4,a5
    800029e6:	2904a783          	lw	a5,656(s1)
    800029ea:	9f99                	subw	a5,a5,a4
    800029ec:	00fba023          	sw	a5,0(s7)
          if (addr != 0 && copyout(p->pagetable, addr, (char *)&np->xstate,
    800029f0:	000b0e63          	beqz	s6,80002a0c <waitx+0x8e>
    800029f4:	4691                	li	a3,4
    800029f6:	14c48613          	addi	a2,s1,332
    800029fa:	85da                	mv	a1,s6
    800029fc:	17093503          	ld	a0,368(s2)
    80002a00:	fffff097          	auipc	ra,0xfffff
    80002a04:	ce2080e7          	jalr	-798(ra) # 800016e2 <copyout>
    80002a08:	04054463          	bltz	a0,80002a50 <waitx+0xd2>
          freeproc(np);
    80002a0c:	8526                	mv	a0,s1
    80002a0e:	fffff097          	auipc	ra,0xfffff
    80002a12:	3dc080e7          	jalr	988(ra) # 80001dea <freeproc>
          release(&np->lock);
    80002a16:	856e                	mv	a0,s11
    80002a18:	ffffe097          	auipc	ra,0xffffe
    80002a1c:	2d4080e7          	jalr	724(ra) # 80000cec <release>
          release(&wait_lock);
    80002a20:	0000e517          	auipc	a0,0xe
    80002a24:	14850513          	addi	a0,a0,328 # 80010b68 <wait_lock>
    80002a28:	ffffe097          	auipc	ra,0xffffe
    80002a2c:	2c4080e7          	jalr	708(ra) # 80000cec <release>
  }
}
    80002a30:	854e                	mv	a0,s3
    80002a32:	70a6                	ld	ra,104(sp)
    80002a34:	7406                	ld	s0,96(sp)
    80002a36:	64e6                	ld	s1,88(sp)
    80002a38:	6946                	ld	s2,80(sp)
    80002a3a:	69a6                	ld	s3,72(sp)
    80002a3c:	6a06                	ld	s4,64(sp)
    80002a3e:	7ae2                	ld	s5,56(sp)
    80002a40:	7b42                	ld	s6,48(sp)
    80002a42:	7ba2                	ld	s7,40(sp)
    80002a44:	7c02                	ld	s8,32(sp)
    80002a46:	6ce2                	ld	s9,24(sp)
    80002a48:	6d42                	ld	s10,16(sp)
    80002a4a:	6da2                	ld	s11,8(sp)
    80002a4c:	6165                	addi	sp,sp,112
    80002a4e:	8082                	ret
            release(&np->lock);
    80002a50:	856e                	mv	a0,s11
    80002a52:	ffffe097          	auipc	ra,0xffffe
    80002a56:	29a080e7          	jalr	666(ra) # 80000cec <release>
            release(&wait_lock);
    80002a5a:	0000e517          	auipc	a0,0xe
    80002a5e:	10e50513          	addi	a0,a0,270 # 80010b68 <wait_lock>
    80002a62:	ffffe097          	auipc	ra,0xffffe
    80002a66:	28a080e7          	jalr	650(ra) # 80000cec <release>
            return -1;
    80002a6a:	59fd                	li	s3,-1
    80002a6c:	b7d1                	j	80002a30 <waitx+0xb2>
    for (np = proc; np < &proc[NPROC]; np++)
    80002a6e:	2a848493          	addi	s1,s1,680
    80002a72:	03348863          	beq	s1,s3,80002aa2 <waitx+0x124>
      if (np->parent == p)
    80002a76:	1584b783          	ld	a5,344(s1)
    80002a7a:	ff279ae3          	bne	a5,s2,80002a6e <waitx+0xf0>
        acquire(&np->lock);
    80002a7e:	12048d93          	addi	s11,s1,288
    80002a82:	856e                	mv	a0,s11
    80002a84:	ffffe097          	auipc	ra,0xffffe
    80002a88:	1b4080e7          	jalr	436(ra) # 80000c38 <acquire>
        if (np->state == ZOMBIE)
    80002a8c:	1384a783          	lw	a5,312(s1)
    80002a90:	f54782e3          	beq	a5,s4,800029d4 <waitx+0x56>
        release(&np->lock);
    80002a94:	856e                	mv	a0,s11
    80002a96:	ffffe097          	auipc	ra,0xffffe
    80002a9a:	256080e7          	jalr	598(ra) # 80000cec <release>
        havekids = 1;
    80002a9e:	8756                	mv	a4,s5
    80002aa0:	b7f9                	j	80002a6e <waitx+0xf0>
    if (!havekids || p->killed)
    80002aa2:	c305                	beqz	a4,80002ac2 <waitx+0x144>
    80002aa4:	14892783          	lw	a5,328(s2)
    80002aa8:	ef89                	bnez	a5,80002ac2 <waitx+0x144>
    sleep(p, &wait_lock); // DOC: wait-sleep
    80002aaa:	85ea                	mv	a1,s10
    80002aac:	854a                	mv	a0,s2
    80002aae:	00000097          	auipc	ra,0x0
    80002ab2:	910080e7          	jalr	-1776(ra) # 800023be <sleep>
    havekids = 0;
    80002ab6:	8766                	mv	a4,s9
    for (np = proc; np < &proc[NPROC]; np++)
    80002ab8:	0000e497          	auipc	s1,0xe
    80002abc:	4c848493          	addi	s1,s1,1224 # 80010f80 <proc>
    80002ac0:	bf5d                	j	80002a76 <waitx+0xf8>
      release(&wait_lock);
    80002ac2:	0000e517          	auipc	a0,0xe
    80002ac6:	0a650513          	addi	a0,a0,166 # 80010b68 <wait_lock>
    80002aca:	ffffe097          	auipc	ra,0xffffe
    80002ace:	222080e7          	jalr	546(ra) # 80000cec <release>
      return -1;
    80002ad2:	59fd                	li	s3,-1
    80002ad4:	bfb1                	j	80002a30 <waitx+0xb2>

0000000080002ad6 <update_time>:

void update_time()
{
    80002ad6:	7179                	addi	sp,sp,-48
    80002ad8:	f406                	sd	ra,40(sp)
    80002ada:	f022                	sd	s0,32(sp)
    80002adc:	ec26                	sd	s1,24(sp)
    80002ade:	e84a                	sd	s2,16(sp)
    80002ae0:	e44e                	sd	s3,8(sp)
    80002ae2:	e052                	sd	s4,0(sp)
    80002ae4:	1800                	addi	s0,sp,48
  struct proc *p;
  for (p = proc; p < &proc[NPROC]; p++)
    80002ae6:	0000e497          	auipc	s1,0xe
    80002aea:	5ba48493          	addi	s1,s1,1466 # 800110a0 <proc+0x120>
    80002aee:	00019a17          	auipc	s4,0x19
    80002af2:	fb2a0a13          	addi	s4,s4,-78 # 8001baa0 <syscall_counts+0x108>
  {
    acquire(&p->lock);
    if (p->state == RUNNING)
    80002af6:	4991                	li	s3,4
    80002af8:	a811                	j	80002b0c <update_time+0x36>
    {
      p->rtime++;
    }
    release(&p->lock);
    80002afa:	854a                	mv	a0,s2
    80002afc:	ffffe097          	auipc	ra,0xffffe
    80002b00:	1f0080e7          	jalr	496(ra) # 80000cec <release>
  for (p = proc; p < &proc[NPROC]; p++)
    80002b04:	2a848493          	addi	s1,s1,680
    80002b08:	03448163          	beq	s1,s4,80002b2a <update_time+0x54>
    acquire(&p->lock);
    80002b0c:	8926                	mv	s2,s1
    80002b0e:	8526                	mv	a0,s1
    80002b10:	ffffe097          	auipc	ra,0xffffe
    80002b14:	128080e7          	jalr	296(ra) # 80000c38 <acquire>
    if (p->state == RUNNING)
    80002b18:	4c9c                	lw	a5,24(s1)
    80002b1a:	ff3790e3          	bne	a5,s3,80002afa <update_time+0x24>
      p->rtime++;
    80002b1e:	1684a783          	lw	a5,360(s1)
    80002b22:	2785                	addiw	a5,a5,1
    80002b24:	16f4a423          	sw	a5,360(s1)
    80002b28:	bfc9                	j	80002afa <update_time+0x24>
  }
}
    80002b2a:	70a2                	ld	ra,40(sp)
    80002b2c:	7402                	ld	s0,32(sp)
    80002b2e:	64e2                	ld	s1,24(sp)
    80002b30:	6942                	ld	s2,16(sp)
    80002b32:	69a2                	ld	s3,8(sp)
    80002b34:	6a02                	ld	s4,0(sp)
    80002b36:	6145                	addi	sp,sp,48
    80002b38:	8082                	ret

0000000080002b3a <swtch>:
    80002b3a:	00153023          	sd	ra,0(a0)
    80002b3e:	00253423          	sd	sp,8(a0)
    80002b42:	e900                	sd	s0,16(a0)
    80002b44:	ed04                	sd	s1,24(a0)
    80002b46:	03253023          	sd	s2,32(a0)
    80002b4a:	03353423          	sd	s3,40(a0)
    80002b4e:	03453823          	sd	s4,48(a0)
    80002b52:	03553c23          	sd	s5,56(a0)
    80002b56:	05653023          	sd	s6,64(a0)
    80002b5a:	05753423          	sd	s7,72(a0)
    80002b5e:	05853823          	sd	s8,80(a0)
    80002b62:	05953c23          	sd	s9,88(a0)
    80002b66:	07a53023          	sd	s10,96(a0)
    80002b6a:	07b53423          	sd	s11,104(a0)
    80002b6e:	0005b083          	ld	ra,0(a1)
    80002b72:	0085b103          	ld	sp,8(a1)
    80002b76:	6980                	ld	s0,16(a1)
    80002b78:	6d84                	ld	s1,24(a1)
    80002b7a:	0205b903          	ld	s2,32(a1)
    80002b7e:	0285b983          	ld	s3,40(a1)
    80002b82:	0305ba03          	ld	s4,48(a1)
    80002b86:	0385ba83          	ld	s5,56(a1)
    80002b8a:	0405bb03          	ld	s6,64(a1)
    80002b8e:	0485bb83          	ld	s7,72(a1)
    80002b92:	0505bc03          	ld	s8,80(a1)
    80002b96:	0585bc83          	ld	s9,88(a1)
    80002b9a:	0605bd03          	ld	s10,96(a1)
    80002b9e:	0685bd83          	ld	s11,104(a1)
    80002ba2:	8082                	ret

0000000080002ba4 <trapinit>:
void kernelvec();

extern int devintr();

void trapinit(void)
{
    80002ba4:	1141                	addi	sp,sp,-16
    80002ba6:	e406                	sd	ra,8(sp)
    80002ba8:	e022                	sd	s0,0(sp)
    80002baa:	0800                	addi	s0,sp,16
  initlock(&tickslock, "time");
    80002bac:	00005597          	auipc	a1,0x5
    80002bb0:	6fc58593          	addi	a1,a1,1788 # 800082a8 <etext+0x2a8>
    80002bb4:	00019517          	auipc	a0,0x19
    80002bb8:	dcc50513          	addi	a0,a0,-564 # 8001b980 <tickslock>
    80002bbc:	ffffe097          	auipc	ra,0xffffe
    80002bc0:	fec080e7          	jalr	-20(ra) # 80000ba8 <initlock>
}
    80002bc4:	60a2                	ld	ra,8(sp)
    80002bc6:	6402                	ld	s0,0(sp)
    80002bc8:	0141                	addi	sp,sp,16
    80002bca:	8082                	ret

0000000080002bcc <trapinithart>:

// set up to take exceptions and traps while in the kernel.
void trapinithart(void)
{
    80002bcc:	1141                	addi	sp,sp,-16
    80002bce:	e422                	sd	s0,8(sp)
    80002bd0:	0800                	addi	s0,sp,16
  asm volatile("csrw stvec, %0" : : "r" (x));
    80002bd2:	00004797          	auipc	a5,0x4
    80002bd6:	85e78793          	addi	a5,a5,-1954 # 80006430 <kernelvec>
    80002bda:	10579073          	csrw	stvec,a5
  w_stvec((uint64)kernelvec);
}
    80002bde:	6422                	ld	s0,8(sp)
    80002be0:	0141                	addi	sp,sp,16
    80002be2:	8082                	ret

0000000080002be4 <usertrapret>:

//
// return to user space
//
void usertrapret(void)
{
    80002be4:	1141                	addi	sp,sp,-16
    80002be6:	e406                	sd	ra,8(sp)
    80002be8:	e022                	sd	s0,0(sp)
    80002bea:	0800                	addi	s0,sp,16
  struct proc *p = myproc();
    80002bec:	fffff097          	auipc	ra,0xfffff
    80002bf0:	048080e7          	jalr	72(ra) # 80001c34 <myproc>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80002bf4:	100027f3          	csrr	a5,sstatus
  w_sstatus(r_sstatus() & ~SSTATUS_SIE);
    80002bf8:	9bf5                	andi	a5,a5,-3
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80002bfa:	10079073          	csrw	sstatus,a5
  // kerneltrap() to usertrap(), so turn off interrupts until
  // we're back in user space, where usertrap() is correct.
  intr_off();

  // send syscalls, interrupts, and exceptions to uservec in trampoline.S
  uint64 trampoline_uservec = TRAMPOLINE + (uservec - trampoline);
    80002bfe:	00004697          	auipc	a3,0x4
    80002c02:	40268693          	addi	a3,a3,1026 # 80007000 <_trampoline>
    80002c06:	00004717          	auipc	a4,0x4
    80002c0a:	3fa70713          	addi	a4,a4,1018 # 80007000 <_trampoline>
    80002c0e:	8f15                	sub	a4,a4,a3
    80002c10:	040007b7          	lui	a5,0x4000
    80002c14:	17fd                	addi	a5,a5,-1 # 3ffffff <_entry-0x7c000001>
    80002c16:	07b2                	slli	a5,a5,0xc
    80002c18:	973e                	add	a4,a4,a5
  asm volatile("csrw stvec, %0" : : "r" (x));
    80002c1a:	10571073          	csrw	stvec,a4
  w_stvec(trampoline_uservec);

  // set up trapframe values that uservec will need when
  // the process next traps into the kernel.
  p->trapframe->kernel_satp = r_satp();         // kernel page table
    80002c1e:	17853703          	ld	a4,376(a0)
  asm volatile("csrr %0, satp" : "=r" (x) );
    80002c22:	18002673          	csrr	a2,satp
    80002c26:	e310                	sd	a2,0(a4)
  p->trapframe->kernel_sp = p->kstack + PGSIZE; // process's kernel stack
    80002c28:	17853603          	ld	a2,376(a0)
    80002c2c:	16053703          	ld	a4,352(a0)
    80002c30:	6585                	lui	a1,0x1
    80002c32:	972e                	add	a4,a4,a1
    80002c34:	e618                	sd	a4,8(a2)
  p->trapframe->kernel_trap = (uint64)usertrap;
    80002c36:	17853703          	ld	a4,376(a0)
    80002c3a:	00000617          	auipc	a2,0x0
    80002c3e:	14c60613          	addi	a2,a2,332 # 80002d86 <usertrap>
    80002c42:	eb10                	sd	a2,16(a4)
  p->trapframe->kernel_hartid = r_tp(); // hartid for cpuid()
    80002c44:	17853703          	ld	a4,376(a0)
  asm volatile("mv %0, tp" : "=r" (x) );
    80002c48:	8612                	mv	a2,tp
    80002c4a:	f310                	sd	a2,32(a4)
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80002c4c:	10002773          	csrr	a4,sstatus
  // set up the registers that trampoline.S's sret will use
  // to get to user space.

  // set S Previous Privilege mode to User.
  unsigned long x = r_sstatus();
  x &= ~SSTATUS_SPP; // clear SPP to 0 for user mode
    80002c50:	eff77713          	andi	a4,a4,-257
  x |= SSTATUS_SPIE; // enable interrupts in user mode
    80002c54:	02076713          	ori	a4,a4,32
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80002c58:	10071073          	csrw	sstatus,a4
  w_sstatus(x);

  // set S Exception Program Counter to the saved user pc.
  w_sepc(p->trapframe->epc);
    80002c5c:	17853703          	ld	a4,376(a0)
  asm volatile("csrw sepc, %0" : : "r" (x));
    80002c60:	6f18                	ld	a4,24(a4)
    80002c62:	14171073          	csrw	sepc,a4

  // tell trampoline.S the user page table to switch to.
  uint64 satp = MAKE_SATP(p->pagetable);
    80002c66:	17053503          	ld	a0,368(a0)
    80002c6a:	8131                	srli	a0,a0,0xc

  // jump to userret in trampoline.S at the top of memory, which
  // switches to the user page table, restores user registers,
  // and switches to user mode with sret.
  uint64 trampoline_userret = TRAMPOLINE + (userret - trampoline);
    80002c6c:	00004717          	auipc	a4,0x4
    80002c70:	43070713          	addi	a4,a4,1072 # 8000709c <userret>
    80002c74:	8f15                	sub	a4,a4,a3
    80002c76:	97ba                	add	a5,a5,a4
  ((void (*)(uint64))trampoline_userret)(satp);
    80002c78:	577d                	li	a4,-1
    80002c7a:	177e                	slli	a4,a4,0x3f
    80002c7c:	8d59                	or	a0,a0,a4
    80002c7e:	9782                	jalr	a5
}
    80002c80:	60a2                	ld	ra,8(sp)
    80002c82:	6402                	ld	s0,0(sp)
    80002c84:	0141                	addi	sp,sp,16
    80002c86:	8082                	ret

0000000080002c88 <clockintr>:
  w_sepc(sepc);
  w_sstatus(sstatus);
}

void clockintr()
{
    80002c88:	1101                	addi	sp,sp,-32
    80002c8a:	ec06                	sd	ra,24(sp)
    80002c8c:	e822                	sd	s0,16(sp)
    80002c8e:	e426                	sd	s1,8(sp)
    80002c90:	e04a                	sd	s2,0(sp)
    80002c92:	1000                	addi	s0,sp,32
  acquire(&tickslock);
    80002c94:	00019917          	auipc	s2,0x19
    80002c98:	cec90913          	addi	s2,s2,-788 # 8001b980 <tickslock>
    80002c9c:	854a                	mv	a0,s2
    80002c9e:	ffffe097          	auipc	ra,0xffffe
    80002ca2:	f9a080e7          	jalr	-102(ra) # 80000c38 <acquire>
  ticks++;
    80002ca6:	00006497          	auipc	s1,0x6
    80002caa:	c4248493          	addi	s1,s1,-958 # 800088e8 <ticks>
    80002cae:	409c                	lw	a5,0(s1)
    80002cb0:	2785                	addiw	a5,a5,1
    80002cb2:	c09c                	sw	a5,0(s1)
  update_time();
    80002cb4:	00000097          	auipc	ra,0x0
    80002cb8:	e22080e7          	jalr	-478(ra) # 80002ad6 <update_time>
  //   // {
  //   //   p->wtime++;
  //   // }
  //   release(&p->lock);
  // }
  wakeup(&ticks);
    80002cbc:	8526                	mv	a0,s1
    80002cbe:	fffff097          	auipc	ra,0xfffff
    80002cc2:	770080e7          	jalr	1904(ra) # 8000242e <wakeup>
  release(&tickslock);
    80002cc6:	854a                	mv	a0,s2
    80002cc8:	ffffe097          	auipc	ra,0xffffe
    80002ccc:	024080e7          	jalr	36(ra) # 80000cec <release>
}
    80002cd0:	60e2                	ld	ra,24(sp)
    80002cd2:	6442                	ld	s0,16(sp)
    80002cd4:	64a2                	ld	s1,8(sp)
    80002cd6:	6902                	ld	s2,0(sp)
    80002cd8:	6105                	addi	sp,sp,32
    80002cda:	8082                	ret

0000000080002cdc <devintr>:
  asm volatile("csrr %0, scause" : "=r" (x) );
    80002cdc:	142027f3          	csrr	a5,scause

    return 2;
  }
  else
  {
    return 0;
    80002ce0:	4501                	li	a0,0
  if ((scause & 0x8000000000000000L) &&
    80002ce2:	0a07d163          	bgez	a5,80002d84 <devintr+0xa8>
{
    80002ce6:	1101                	addi	sp,sp,-32
    80002ce8:	ec06                	sd	ra,24(sp)
    80002cea:	e822                	sd	s0,16(sp)
    80002cec:	1000                	addi	s0,sp,32
      (scause & 0xff) == 9)
    80002cee:	0ff7f713          	zext.b	a4,a5
  if ((scause & 0x8000000000000000L) &&
    80002cf2:	46a5                	li	a3,9
    80002cf4:	00d70c63          	beq	a4,a3,80002d0c <devintr+0x30>
  else if (scause == 0x8000000000000001L)
    80002cf8:	577d                	li	a4,-1
    80002cfa:	177e                	slli	a4,a4,0x3f
    80002cfc:	0705                	addi	a4,a4,1
    return 0;
    80002cfe:	4501                	li	a0,0
  else if (scause == 0x8000000000000001L)
    80002d00:	06e78163          	beq	a5,a4,80002d62 <devintr+0x86>
  }
}
    80002d04:	60e2                	ld	ra,24(sp)
    80002d06:	6442                	ld	s0,16(sp)
    80002d08:	6105                	addi	sp,sp,32
    80002d0a:	8082                	ret
    80002d0c:	e426                	sd	s1,8(sp)
    int irq = plic_claim();
    80002d0e:	00004097          	auipc	ra,0x4
    80002d12:	82e080e7          	jalr	-2002(ra) # 8000653c <plic_claim>
    80002d16:	84aa                	mv	s1,a0
    if (irq == UART0_IRQ)
    80002d18:	47a9                	li	a5,10
    80002d1a:	00f50963          	beq	a0,a5,80002d2c <devintr+0x50>
    else if (irq == VIRTIO0_IRQ)
    80002d1e:	4785                	li	a5,1
    80002d20:	00f50b63          	beq	a0,a5,80002d36 <devintr+0x5a>
    return 1;
    80002d24:	4505                	li	a0,1
    else if (irq)
    80002d26:	ec89                	bnez	s1,80002d40 <devintr+0x64>
    80002d28:	64a2                	ld	s1,8(sp)
    80002d2a:	bfe9                	j	80002d04 <devintr+0x28>
      uartintr();
    80002d2c:	ffffe097          	auipc	ra,0xffffe
    80002d30:	cce080e7          	jalr	-818(ra) # 800009fa <uartintr>
    if (irq)
    80002d34:	a839                	j	80002d52 <devintr+0x76>
      virtio_disk_intr();
    80002d36:	00004097          	auipc	ra,0x4
    80002d3a:	d30080e7          	jalr	-720(ra) # 80006a66 <virtio_disk_intr>
    if (irq)
    80002d3e:	a811                	j	80002d52 <devintr+0x76>
      printf("unexpected interrupt irq=%d\n", irq);
    80002d40:	85a6                	mv	a1,s1
    80002d42:	00005517          	auipc	a0,0x5
    80002d46:	56e50513          	addi	a0,a0,1390 # 800082b0 <etext+0x2b0>
    80002d4a:	ffffe097          	auipc	ra,0xffffe
    80002d4e:	860080e7          	jalr	-1952(ra) # 800005aa <printf>
      plic_complete(irq);
    80002d52:	8526                	mv	a0,s1
    80002d54:	00004097          	auipc	ra,0x4
    80002d58:	80c080e7          	jalr	-2036(ra) # 80006560 <plic_complete>
    return 1;
    80002d5c:	4505                	li	a0,1
    80002d5e:	64a2                	ld	s1,8(sp)
    80002d60:	b755                	j	80002d04 <devintr+0x28>
    if (cpuid() == 0)
    80002d62:	fffff097          	auipc	ra,0xfffff
    80002d66:	ea6080e7          	jalr	-346(ra) # 80001c08 <cpuid>
    80002d6a:	c901                	beqz	a0,80002d7a <devintr+0x9e>
  asm volatile("csrr %0, sip" : "=r" (x) );
    80002d6c:	144027f3          	csrr	a5,sip
    w_sip(r_sip() & ~2);
    80002d70:	9bf5                	andi	a5,a5,-3
  asm volatile("csrw sip, %0" : : "r" (x));
    80002d72:	14479073          	csrw	sip,a5
    return 2;
    80002d76:	4509                	li	a0,2
    80002d78:	b771                	j	80002d04 <devintr+0x28>
      clockintr();
    80002d7a:	00000097          	auipc	ra,0x0
    80002d7e:	f0e080e7          	jalr	-242(ra) # 80002c88 <clockintr>
    80002d82:	b7ed                	j	80002d6c <devintr+0x90>
}
    80002d84:	8082                	ret

0000000080002d86 <usertrap>:
{
    80002d86:	1101                	addi	sp,sp,-32
    80002d88:	ec06                	sd	ra,24(sp)
    80002d8a:	e822                	sd	s0,16(sp)
    80002d8c:	e426                	sd	s1,8(sp)
    80002d8e:	e04a                	sd	s2,0(sp)
    80002d90:	1000                	addi	s0,sp,32
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80002d92:	100027f3          	csrr	a5,sstatus
  if ((r_sstatus() & SSTATUS_SPP) != 0)
    80002d96:	1007f793          	andi	a5,a5,256
    80002d9a:	e3b9                	bnez	a5,80002de0 <usertrap+0x5a>
  asm volatile("csrw stvec, %0" : : "r" (x));
    80002d9c:	00003797          	auipc	a5,0x3
    80002da0:	69478793          	addi	a5,a5,1684 # 80006430 <kernelvec>
    80002da4:	10579073          	csrw	stvec,a5
  struct proc *p = myproc();
    80002da8:	fffff097          	auipc	ra,0xfffff
    80002dac:	e8c080e7          	jalr	-372(ra) # 80001c34 <myproc>
    80002db0:	84aa                	mv	s1,a0
  p->trapframe->epc = r_sepc();
    80002db2:	17853783          	ld	a5,376(a0)
  asm volatile("csrr %0, sepc" : "=r" (x) );
    80002db6:	14102773          	csrr	a4,sepc
    80002dba:	ef98                	sd	a4,24(a5)
  asm volatile("csrr %0, scause" : "=r" (x) );
    80002dbc:	14202773          	csrr	a4,scause
  if (r_scause() == 8)
    80002dc0:	47a1                	li	a5,8
    80002dc2:	02f70763          	beq	a4,a5,80002df0 <usertrap+0x6a>
  else if ((which_dev = devintr()) != 0)
    80002dc6:	00000097          	auipc	ra,0x0
    80002dca:	f16080e7          	jalr	-234(ra) # 80002cdc <devintr>
    80002dce:	892a                	mv	s2,a0
    80002dd0:	cd71                	beqz	a0,80002eac <usertrap+0x126>
  if (killed(p))
    80002dd2:	8526                	mv	a0,s1
    80002dd4:	00000097          	auipc	ra,0x0
    80002dd8:	8d8080e7          	jalr	-1832(ra) # 800026ac <killed>
    80002ddc:	c931                	beqz	a0,80002e30 <usertrap+0xaa>
    80002dde:	a0a1                	j	80002e26 <usertrap+0xa0>
    panic("usertrap: not from user mode");
    80002de0:	00005517          	auipc	a0,0x5
    80002de4:	4f050513          	addi	a0,a0,1264 # 800082d0 <etext+0x2d0>
    80002de8:	ffffd097          	auipc	ra,0xffffd
    80002dec:	778080e7          	jalr	1912(ra) # 80000560 <panic>
    if (killed(p))
    80002df0:	00000097          	auipc	ra,0x0
    80002df4:	8bc080e7          	jalr	-1860(ra) # 800026ac <killed>
    80002df8:	e545                	bnez	a0,80002ea0 <usertrap+0x11a>
    p->trapframe->epc += 4;
    80002dfa:	1784b703          	ld	a4,376(s1)
    80002dfe:	6f1c                	ld	a5,24(a4)
    80002e00:	0791                	addi	a5,a5,4
    80002e02:	ef1c                	sd	a5,24(a4)
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80002e04:	100027f3          	csrr	a5,sstatus
  w_sstatus(r_sstatus() | SSTATUS_SIE);
    80002e08:	0027e793          	ori	a5,a5,2
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80002e0c:	10079073          	csrw	sstatus,a5
    syscall();
    80002e10:	00000097          	auipc	ra,0x0
    80002e14:	354080e7          	jalr	852(ra) # 80003164 <syscall>
  if (killed(p))
    80002e18:	8526                	mv	a0,s1
    80002e1a:	00000097          	auipc	ra,0x0
    80002e1e:	892080e7          	jalr	-1902(ra) # 800026ac <killed>
    80002e22:	c52d                	beqz	a0,80002e8c <usertrap+0x106>
    80002e24:	4901                	li	s2,0
    exit(-1);
    80002e26:	557d                	li	a0,-1
    80002e28:	fffff097          	auipc	ra,0xfffff
    80002e2c:	6e6080e7          	jalr	1766(ra) # 8000250e <exit>
  if (which_dev == 2)
    80002e30:	4789                	li	a5,2
    80002e32:	04f91d63          	bne	s2,a5,80002e8c <usertrap+0x106>
    if (p->alarm_interval > 0)
    80002e36:	1004a703          	lw	a4,256(s1)
    80002e3a:	04e05563          	blez	a4,80002e84 <usertrap+0xfe>
      p->ticks_count++;
    80002e3e:	1104a783          	lw	a5,272(s1)
    80002e42:	2785                	addiw	a5,a5,1
    80002e44:	0007869b          	sext.w	a3,a5
    80002e48:	10f4a823          	sw	a5,272(s1)
      if (p->ticks_count >= p->alarm_interval && !p->alarm_on)
    80002e4c:	02e6cc63          	blt	a3,a4,80002e84 <usertrap+0xfe>
    80002e50:	1144a783          	lw	a5,276(s1)
    80002e54:	eb85                	bnez	a5,80002e84 <usertrap+0xfe>
        p->ticks_count = 0;
    80002e56:	1004a823          	sw	zero,272(s1)
        p->alarm_on = 1;
    80002e5a:	4785                	li	a5,1
    80002e5c:	10f4aa23          	sw	a5,276(s1)
        if (p->alarm_tf == 0)
    80002e60:	1184b783          	ld	a5,280(s1)
    80002e64:	c3d1                	beqz	a5,80002ee8 <usertrap+0x162>
        memmove(p->alarm_tf, p->trapframe, sizeof(struct trapframe));
    80002e66:	12000613          	li	a2,288
    80002e6a:	1784b583          	ld	a1,376(s1)
    80002e6e:	1184b503          	ld	a0,280(s1)
    80002e72:	ffffe097          	auipc	ra,0xffffe
    80002e76:	f1e080e7          	jalr	-226(ra) # 80000d90 <memmove>
        p->trapframe->epc = p->alarm_handler;
    80002e7a:	1784b783          	ld	a5,376(s1)
    80002e7e:	1084b703          	ld	a4,264(s1)
    80002e82:	ef98                	sd	a4,24(a5)
    yield();
    80002e84:	fffff097          	auipc	ra,0xfffff
    80002e88:	4f2080e7          	jalr	1266(ra) # 80002376 <yield>
  usertrapret();
    80002e8c:	00000097          	auipc	ra,0x0
    80002e90:	d58080e7          	jalr	-680(ra) # 80002be4 <usertrapret>
}
    80002e94:	60e2                	ld	ra,24(sp)
    80002e96:	6442                	ld	s0,16(sp)
    80002e98:	64a2                	ld	s1,8(sp)
    80002e9a:	6902                	ld	s2,0(sp)
    80002e9c:	6105                	addi	sp,sp,32
    80002e9e:	8082                	ret
      exit(-1);
    80002ea0:	557d                	li	a0,-1
    80002ea2:	fffff097          	auipc	ra,0xfffff
    80002ea6:	66c080e7          	jalr	1644(ra) # 8000250e <exit>
    80002eaa:	bf81                	j	80002dfa <usertrap+0x74>
  asm volatile("csrr %0, scause" : "=r" (x) );
    80002eac:	142025f3          	csrr	a1,scause
    printf("usertrap(): unexpected scause %p pid=%d\n", r_scause(), p->pid);
    80002eb0:	1504a603          	lw	a2,336(s1)
    80002eb4:	00005517          	auipc	a0,0x5
    80002eb8:	43c50513          	addi	a0,a0,1084 # 800082f0 <etext+0x2f0>
    80002ebc:	ffffd097          	auipc	ra,0xffffd
    80002ec0:	6ee080e7          	jalr	1774(ra) # 800005aa <printf>
  asm volatile("csrr %0, sepc" : "=r" (x) );
    80002ec4:	141025f3          	csrr	a1,sepc
  asm volatile("csrr %0, stval" : "=r" (x) );
    80002ec8:	14302673          	csrr	a2,stval
    printf("            sepc=%p stval=%p\n", r_sepc(), r_stval());
    80002ecc:	00005517          	auipc	a0,0x5
    80002ed0:	45450513          	addi	a0,a0,1108 # 80008320 <etext+0x320>
    80002ed4:	ffffd097          	auipc	ra,0xffffd
    80002ed8:	6d6080e7          	jalr	1750(ra) # 800005aa <printf>
    setkilled(p);
    80002edc:	8526                	mv	a0,s1
    80002ede:	fffff097          	auipc	ra,0xfffff
    80002ee2:	796080e7          	jalr	1942(ra) # 80002674 <setkilled>
    80002ee6:	bf0d                	j	80002e18 <usertrap+0x92>
          p->alarm_tf = kalloc();
    80002ee8:	ffffe097          	auipc	ra,0xffffe
    80002eec:	c60080e7          	jalr	-928(ra) # 80000b48 <kalloc>
    80002ef0:	10a4bc23          	sd	a0,280(s1)
          if (p->alarm_tf == 0)
    80002ef4:	f92d                	bnez	a0,80002e66 <usertrap+0xe0>
            panic("kalloc");
    80002ef6:	00005517          	auipc	a0,0x5
    80002efa:	2c250513          	addi	a0,a0,706 # 800081b8 <etext+0x1b8>
    80002efe:	ffffd097          	auipc	ra,0xffffd
    80002f02:	662080e7          	jalr	1634(ra) # 80000560 <panic>

0000000080002f06 <kerneltrap>:
{
    80002f06:	7179                	addi	sp,sp,-48
    80002f08:	f406                	sd	ra,40(sp)
    80002f0a:	f022                	sd	s0,32(sp)
    80002f0c:	ec26                	sd	s1,24(sp)
    80002f0e:	e84a                	sd	s2,16(sp)
    80002f10:	e44e                	sd	s3,8(sp)
    80002f12:	1800                	addi	s0,sp,48
  asm volatile("csrr %0, sepc" : "=r" (x) );
    80002f14:	14102973          	csrr	s2,sepc
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80002f18:	100024f3          	csrr	s1,sstatus
  asm volatile("csrr %0, scause" : "=r" (x) );
    80002f1c:	142029f3          	csrr	s3,scause
  if ((sstatus & SSTATUS_SPP) == 0)
    80002f20:	1004f793          	andi	a5,s1,256
    80002f24:	cb85                	beqz	a5,80002f54 <kerneltrap+0x4e>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80002f26:	100027f3          	csrr	a5,sstatus
  return (x & SSTATUS_SIE) != 0;
    80002f2a:	8b89                	andi	a5,a5,2
  if (intr_get() != 0)
    80002f2c:	ef85                	bnez	a5,80002f64 <kerneltrap+0x5e>
  if ((which_dev = devintr()) == 0)
    80002f2e:	00000097          	auipc	ra,0x0
    80002f32:	dae080e7          	jalr	-594(ra) # 80002cdc <devintr>
    80002f36:	cd1d                	beqz	a0,80002f74 <kerneltrap+0x6e>
  if (which_dev == 2 && myproc() != 0 && myproc()->state == RUNNING)
    80002f38:	4789                	li	a5,2
    80002f3a:	06f50a63          	beq	a0,a5,80002fae <kerneltrap+0xa8>
  asm volatile("csrw sepc, %0" : : "r" (x));
    80002f3e:	14191073          	csrw	sepc,s2
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80002f42:	10049073          	csrw	sstatus,s1
}
    80002f46:	70a2                	ld	ra,40(sp)
    80002f48:	7402                	ld	s0,32(sp)
    80002f4a:	64e2                	ld	s1,24(sp)
    80002f4c:	6942                	ld	s2,16(sp)
    80002f4e:	69a2                	ld	s3,8(sp)
    80002f50:	6145                	addi	sp,sp,48
    80002f52:	8082                	ret
    panic("kerneltrap: not from supervisor mode");
    80002f54:	00005517          	auipc	a0,0x5
    80002f58:	3ec50513          	addi	a0,a0,1004 # 80008340 <etext+0x340>
    80002f5c:	ffffd097          	auipc	ra,0xffffd
    80002f60:	604080e7          	jalr	1540(ra) # 80000560 <panic>
    panic("kerneltrap: interrupts enabled");
    80002f64:	00005517          	auipc	a0,0x5
    80002f68:	40450513          	addi	a0,a0,1028 # 80008368 <etext+0x368>
    80002f6c:	ffffd097          	auipc	ra,0xffffd
    80002f70:	5f4080e7          	jalr	1524(ra) # 80000560 <panic>
    printf("scause %p\n", scause);
    80002f74:	85ce                	mv	a1,s3
    80002f76:	00005517          	auipc	a0,0x5
    80002f7a:	41250513          	addi	a0,a0,1042 # 80008388 <etext+0x388>
    80002f7e:	ffffd097          	auipc	ra,0xffffd
    80002f82:	62c080e7          	jalr	1580(ra) # 800005aa <printf>
  asm volatile("csrr %0, sepc" : "=r" (x) );
    80002f86:	141025f3          	csrr	a1,sepc
  asm volatile("csrr %0, stval" : "=r" (x) );
    80002f8a:	14302673          	csrr	a2,stval
    printf("sepc=%p stval=%p\n", r_sepc(), r_stval());
    80002f8e:	00005517          	auipc	a0,0x5
    80002f92:	40a50513          	addi	a0,a0,1034 # 80008398 <etext+0x398>
    80002f96:	ffffd097          	auipc	ra,0xffffd
    80002f9a:	614080e7          	jalr	1556(ra) # 800005aa <printf>
    panic("kerneltrap");
    80002f9e:	00005517          	auipc	a0,0x5
    80002fa2:	41250513          	addi	a0,a0,1042 # 800083b0 <etext+0x3b0>
    80002fa6:	ffffd097          	auipc	ra,0xffffd
    80002faa:	5ba080e7          	jalr	1466(ra) # 80000560 <panic>
  if (which_dev == 2 && myproc() != 0 && myproc()->state == RUNNING)
    80002fae:	fffff097          	auipc	ra,0xfffff
    80002fb2:	c86080e7          	jalr	-890(ra) # 80001c34 <myproc>
    80002fb6:	d541                	beqz	a0,80002f3e <kerneltrap+0x38>
    80002fb8:	fffff097          	auipc	ra,0xfffff
    80002fbc:	c7c080e7          	jalr	-900(ra) # 80001c34 <myproc>
    80002fc0:	13852703          	lw	a4,312(a0)
    80002fc4:	4791                	li	a5,4
    80002fc6:	f6f71ce3          	bne	a4,a5,80002f3e <kerneltrap+0x38>
    yield();
    80002fca:	fffff097          	auipc	ra,0xfffff
    80002fce:	3ac080e7          	jalr	940(ra) # 80002376 <yield>
    80002fd2:	b7b5                	j	80002f3e <kerneltrap+0x38>

0000000080002fd4 <argraw>:
  return strlen(buf);
}

static uint64
argraw(int n)
{
    80002fd4:	1101                	addi	sp,sp,-32
    80002fd6:	ec06                	sd	ra,24(sp)
    80002fd8:	e822                	sd	s0,16(sp)
    80002fda:	e426                	sd	s1,8(sp)
    80002fdc:	1000                	addi	s0,sp,32
    80002fde:	84aa                	mv	s1,a0
  struct proc *p = myproc();
    80002fe0:	fffff097          	auipc	ra,0xfffff
    80002fe4:	c54080e7          	jalr	-940(ra) # 80001c34 <myproc>
  switch (n)
    80002fe8:	4795                	li	a5,5
    80002fea:	0497e763          	bltu	a5,s1,80003038 <argraw+0x64>
    80002fee:	048a                	slli	s1,s1,0x2
    80002ff0:	00005717          	auipc	a4,0x5
    80002ff4:	78070713          	addi	a4,a4,1920 # 80008770 <states.0+0x30>
    80002ff8:	94ba                	add	s1,s1,a4
    80002ffa:	409c                	lw	a5,0(s1)
    80002ffc:	97ba                	add	a5,a5,a4
    80002ffe:	8782                	jr	a5
  {
  case 0:
    return p->trapframe->a0;
    80003000:	17853783          	ld	a5,376(a0)
    80003004:	7ba8                	ld	a0,112(a5)
  case 5:
    return p->trapframe->a5;
  }
  panic("argraw");
  return -1;
}
    80003006:	60e2                	ld	ra,24(sp)
    80003008:	6442                	ld	s0,16(sp)
    8000300a:	64a2                	ld	s1,8(sp)
    8000300c:	6105                	addi	sp,sp,32
    8000300e:	8082                	ret
    return p->trapframe->a1;
    80003010:	17853783          	ld	a5,376(a0)
    80003014:	7fa8                	ld	a0,120(a5)
    80003016:	bfc5                	j	80003006 <argraw+0x32>
    return p->trapframe->a2;
    80003018:	17853783          	ld	a5,376(a0)
    8000301c:	63c8                	ld	a0,128(a5)
    8000301e:	b7e5                	j	80003006 <argraw+0x32>
    return p->trapframe->a3;
    80003020:	17853783          	ld	a5,376(a0)
    80003024:	67c8                	ld	a0,136(a5)
    80003026:	b7c5                	j	80003006 <argraw+0x32>
    return p->trapframe->a4;
    80003028:	17853783          	ld	a5,376(a0)
    8000302c:	6bc8                	ld	a0,144(a5)
    8000302e:	bfe1                	j	80003006 <argraw+0x32>
    return p->trapframe->a5;
    80003030:	17853783          	ld	a5,376(a0)
    80003034:	6fc8                	ld	a0,152(a5)
    80003036:	bfc1                	j	80003006 <argraw+0x32>
  panic("argraw");
    80003038:	00005517          	auipc	a0,0x5
    8000303c:	38850513          	addi	a0,a0,904 # 800083c0 <etext+0x3c0>
    80003040:	ffffd097          	auipc	ra,0xffffd
    80003044:	520080e7          	jalr	1312(ra) # 80000560 <panic>

0000000080003048 <fetchaddr>:
{
    80003048:	1101                	addi	sp,sp,-32
    8000304a:	ec06                	sd	ra,24(sp)
    8000304c:	e822                	sd	s0,16(sp)
    8000304e:	e426                	sd	s1,8(sp)
    80003050:	e04a                	sd	s2,0(sp)
    80003052:	1000                	addi	s0,sp,32
    80003054:	84aa                	mv	s1,a0
    80003056:	892e                	mv	s2,a1
  struct proc *p = myproc();
    80003058:	fffff097          	auipc	ra,0xfffff
    8000305c:	bdc080e7          	jalr	-1060(ra) # 80001c34 <myproc>
  if (addr >= p->sz || addr + sizeof(uint64) > p->sz) // both tests needed, in case of overflow
    80003060:	16853783          	ld	a5,360(a0)
    80003064:	02f4f963          	bgeu	s1,a5,80003096 <fetchaddr+0x4e>
    80003068:	00848713          	addi	a4,s1,8
    8000306c:	02e7e763          	bltu	a5,a4,8000309a <fetchaddr+0x52>
  if (copyin(p->pagetable, (char *)ip, addr, sizeof(*ip)) != 0)
    80003070:	46a1                	li	a3,8
    80003072:	8626                	mv	a2,s1
    80003074:	85ca                	mv	a1,s2
    80003076:	17053503          	ld	a0,368(a0)
    8000307a:	ffffe097          	auipc	ra,0xffffe
    8000307e:	6f4080e7          	jalr	1780(ra) # 8000176e <copyin>
    80003082:	00a03533          	snez	a0,a0
    80003086:	40a00533          	neg	a0,a0
}
    8000308a:	60e2                	ld	ra,24(sp)
    8000308c:	6442                	ld	s0,16(sp)
    8000308e:	64a2                	ld	s1,8(sp)
    80003090:	6902                	ld	s2,0(sp)
    80003092:	6105                	addi	sp,sp,32
    80003094:	8082                	ret
    return -1;
    80003096:	557d                	li	a0,-1
    80003098:	bfcd                	j	8000308a <fetchaddr+0x42>
    8000309a:	557d                	li	a0,-1
    8000309c:	b7fd                	j	8000308a <fetchaddr+0x42>

000000008000309e <fetchstr>:
{
    8000309e:	7179                	addi	sp,sp,-48
    800030a0:	f406                	sd	ra,40(sp)
    800030a2:	f022                	sd	s0,32(sp)
    800030a4:	ec26                	sd	s1,24(sp)
    800030a6:	e84a                	sd	s2,16(sp)
    800030a8:	e44e                	sd	s3,8(sp)
    800030aa:	1800                	addi	s0,sp,48
    800030ac:	892a                	mv	s2,a0
    800030ae:	84ae                	mv	s1,a1
    800030b0:	89b2                	mv	s3,a2
  struct proc *p = myproc();
    800030b2:	fffff097          	auipc	ra,0xfffff
    800030b6:	b82080e7          	jalr	-1150(ra) # 80001c34 <myproc>
  if (copyinstr(p->pagetable, buf, addr, max) < 0)
    800030ba:	86ce                	mv	a3,s3
    800030bc:	864a                	mv	a2,s2
    800030be:	85a6                	mv	a1,s1
    800030c0:	17053503          	ld	a0,368(a0)
    800030c4:	ffffe097          	auipc	ra,0xffffe
    800030c8:	738080e7          	jalr	1848(ra) # 800017fc <copyinstr>
    800030cc:	00054e63          	bltz	a0,800030e8 <fetchstr+0x4a>
  return strlen(buf);
    800030d0:	8526                	mv	a0,s1
    800030d2:	ffffe097          	auipc	ra,0xffffe
    800030d6:	dd6080e7          	jalr	-554(ra) # 80000ea8 <strlen>
}
    800030da:	70a2                	ld	ra,40(sp)
    800030dc:	7402                	ld	s0,32(sp)
    800030de:	64e2                	ld	s1,24(sp)
    800030e0:	6942                	ld	s2,16(sp)
    800030e2:	69a2                	ld	s3,8(sp)
    800030e4:	6145                	addi	sp,sp,48
    800030e6:	8082                	ret
    return -1;
    800030e8:	557d                	li	a0,-1
    800030ea:	bfc5                	j	800030da <fetchstr+0x3c>

00000000800030ec <argint>:

// Fetch the nth 32-bit system call argument.
void argint(int n, int *ip)
{
    800030ec:	1101                	addi	sp,sp,-32
    800030ee:	ec06                	sd	ra,24(sp)
    800030f0:	e822                	sd	s0,16(sp)
    800030f2:	e426                	sd	s1,8(sp)
    800030f4:	1000                	addi	s0,sp,32
    800030f6:	84ae                	mv	s1,a1
  *ip = argraw(n);
    800030f8:	00000097          	auipc	ra,0x0
    800030fc:	edc080e7          	jalr	-292(ra) # 80002fd4 <argraw>
    80003100:	c088                	sw	a0,0(s1)
}
    80003102:	60e2                	ld	ra,24(sp)
    80003104:	6442                	ld	s0,16(sp)
    80003106:	64a2                	ld	s1,8(sp)
    80003108:	6105                	addi	sp,sp,32
    8000310a:	8082                	ret

000000008000310c <argaddr>:

// Retrieve an argument as a pointer.
// Doesn't check for legality, since
// copyin/copyout will do that.
void argaddr(int n, uint64 *ip)
{
    8000310c:	1101                	addi	sp,sp,-32
    8000310e:	ec06                	sd	ra,24(sp)
    80003110:	e822                	sd	s0,16(sp)
    80003112:	e426                	sd	s1,8(sp)
    80003114:	1000                	addi	s0,sp,32
    80003116:	84ae                	mv	s1,a1
  *ip = argraw(n);
    80003118:	00000097          	auipc	ra,0x0
    8000311c:	ebc080e7          	jalr	-324(ra) # 80002fd4 <argraw>
    80003120:	e088                	sd	a0,0(s1)
}
    80003122:	60e2                	ld	ra,24(sp)
    80003124:	6442                	ld	s0,16(sp)
    80003126:	64a2                	ld	s1,8(sp)
    80003128:	6105                	addi	sp,sp,32
    8000312a:	8082                	ret

000000008000312c <argstr>:

// Fetch the nth word-sized system call argument as a null-terminated string.
// Copies into buf, at most max.
// Returns string length if OK (including nul), -1 if error.
int argstr(int n, char *buf, int max)
{
    8000312c:	7179                	addi	sp,sp,-48
    8000312e:	f406                	sd	ra,40(sp)
    80003130:	f022                	sd	s0,32(sp)
    80003132:	ec26                	sd	s1,24(sp)
    80003134:	e84a                	sd	s2,16(sp)
    80003136:	1800                	addi	s0,sp,48
    80003138:	84ae                	mv	s1,a1
    8000313a:	8932                	mv	s2,a2
  uint64 addr;
  argaddr(n, &addr);
    8000313c:	fd840593          	addi	a1,s0,-40
    80003140:	00000097          	auipc	ra,0x0
    80003144:	fcc080e7          	jalr	-52(ra) # 8000310c <argaddr>
  return fetchstr(addr, buf, max);
    80003148:	864a                	mv	a2,s2
    8000314a:	85a6                	mv	a1,s1
    8000314c:	fd843503          	ld	a0,-40(s0)
    80003150:	00000097          	auipc	ra,0x0
    80003154:	f4e080e7          	jalr	-178(ra) # 8000309e <fetchstr>
}
    80003158:	70a2                	ld	ra,40(sp)
    8000315a:	7402                	ld	s0,32(sp)
    8000315c:	64e2                	ld	s1,24(sp)
    8000315e:	6942                	ld	s2,16(sp)
    80003160:	6145                	addi	sp,sp,48
    80003162:	8082                	ret

0000000080003164 <syscall>:
    [SYS_sigreturn] sys_sigreturn,
    [SYS_settickets] sys_settickets,
};
uint64 syscall_counts[NPROC][32];
void syscall(void)
{
    80003164:	1101                	addi	sp,sp,-32
    80003166:	ec06                	sd	ra,24(sp)
    80003168:	e822                	sd	s0,16(sp)
    8000316a:	e426                	sd	s1,8(sp)
    8000316c:	1000                	addi	s0,sp,32
  int num;
  struct proc *p = myproc();
    8000316e:	fffff097          	auipc	ra,0xfffff
    80003172:	ac6080e7          	jalr	-1338(ra) # 80001c34 <myproc>
    80003176:	84aa                	mv	s1,a0
  num = p->trapframe->a7; // When a process is called, then its system call number is stored in a7. num contains the system call number.
    80003178:	17853783          	ld	a5,376(a0)
    8000317c:	77dc                	ld	a5,168(a5)
    8000317e:	0007869b          	sext.w	a3,a5
  // struct proc *pp = p->parent;
  // printf("a7 %d pid %d %s count %d\n", p->trapframe->a7, p->pid, p->name, p->syscall_counts[num-1]);
  int pid = p->pid;
    80003182:	15052583          	lw	a1,336(a0)
  if (num > 0 && num < NELEM(syscalls) && syscalls[num])
    80003186:	37fd                	addiw	a5,a5,-1
    80003188:	4765                	li	a4,25
    8000318a:	04f76063          	bltu	a4,a5,800031ca <syscall+0x66>
    8000318e:	00369713          	slli	a4,a3,0x3
    80003192:	00005797          	auipc	a5,0x5
    80003196:	5f678793          	addi	a5,a5,1526 # 80008788 <syscalls>
    8000319a:	97ba                	add	a5,a5,a4
    8000319c:	6390                	ld	a2,0(a5)
    8000319e:	c615                	beqz	a2,800031ca <syscall+0x66>
  {
    // Use num to lookup the system call function for num, call it,
    // and store its return value in p->trapframe->a0
    // Increment the count for this syscall
    p->syscall_counts[num - 1] = p->syscall_counts[num - 1] + 1;
    800031a0:	972a                	add	a4,a4,a0
    800031a2:	ff873783          	ld	a5,-8(a4)
    800031a6:	0785                	addi	a5,a5,1
    800031a8:	fef73c23          	sd	a5,-8(a4)
    syscall_counts[pid][num - 1] = p->syscall_counts[num - 1];
    800031ac:	36fd                	addiw	a3,a3,-1
    800031ae:	0596                	slli	a1,a1,0x5
    800031b0:	95b6                	add	a1,a1,a3
    800031b2:	058e                	slli	a1,a1,0x3
    800031b4:	00018717          	auipc	a4,0x18
    800031b8:	7e470713          	addi	a4,a4,2020 # 8001b998 <syscall_counts>
    800031bc:	972e                	add	a4,a4,a1
    800031be:	e31c                	sd	a5,0(a4)
    p->trapframe->a0 = syscalls[num](); // This call finds the exact function indexed by num and executes it. a0 stores the return value of that function.
    800031c0:	17853483          	ld	s1,376(a0)
    800031c4:	9602                	jalr	a2
    800031c6:	f8a8                	sd	a0,112(s1)
    800031c8:	a839                	j	800031e6 <syscall+0x82>
    // printf("__sysid %d return %d pid %d %s count %d\n", p->trapframe->a7, p->trapframe->a0,  p->pid, p->name, p->syscall_counts[num-1]);
  }
  else
  {
    printf("%d %s: unknown sys call %d\n",
    800031ca:	27848613          	addi	a2,s1,632
    800031ce:	00005517          	auipc	a0,0x5
    800031d2:	1fa50513          	addi	a0,a0,506 # 800083c8 <etext+0x3c8>
    800031d6:	ffffd097          	auipc	ra,0xffffd
    800031da:	3d4080e7          	jalr	980(ra) # 800005aa <printf>
           p->pid, p->name, num);
    p->trapframe->a0 = -1;
    800031de:	1784b783          	ld	a5,376(s1)
    800031e2:	577d                	li	a4,-1
    800031e4:	fbb8                	sd	a4,112(a5)
  }
}
    800031e6:	60e2                	ld	ra,24(sp)
    800031e8:	6442                	ld	s0,16(sp)
    800031ea:	64a2                	ld	s1,8(sp)
    800031ec:	6105                	addi	sp,sp,32
    800031ee:	8082                	ret

00000000800031f0 <sys_exit>:
#include "spinlock.h"
#include "proc.h"

uint64
sys_exit(void)
{
    800031f0:	1101                	addi	sp,sp,-32
    800031f2:	ec06                	sd	ra,24(sp)
    800031f4:	e822                	sd	s0,16(sp)
    800031f6:	1000                	addi	s0,sp,32
  int n;
  argint(0, &n);
    800031f8:	fec40593          	addi	a1,s0,-20
    800031fc:	4501                	li	a0,0
    800031fe:	00000097          	auipc	ra,0x0
    80003202:	eee080e7          	jalr	-274(ra) # 800030ec <argint>
  exit(n);
    80003206:	fec42503          	lw	a0,-20(s0)
    8000320a:	fffff097          	auipc	ra,0xfffff
    8000320e:	304080e7          	jalr	772(ra) # 8000250e <exit>
  return 0; // not reached
}
    80003212:	4501                	li	a0,0
    80003214:	60e2                	ld	ra,24(sp)
    80003216:	6442                	ld	s0,16(sp)
    80003218:	6105                	addi	sp,sp,32
    8000321a:	8082                	ret

000000008000321c <sys_getpid>:

uint64
sys_getpid(void)
{
    8000321c:	1141                	addi	sp,sp,-16
    8000321e:	e406                	sd	ra,8(sp)
    80003220:	e022                	sd	s0,0(sp)
    80003222:	0800                	addi	s0,sp,16
  return myproc()->pid;
    80003224:	fffff097          	auipc	ra,0xfffff
    80003228:	a10080e7          	jalr	-1520(ra) # 80001c34 <myproc>
}
    8000322c:	15052503          	lw	a0,336(a0)
    80003230:	60a2                	ld	ra,8(sp)
    80003232:	6402                	ld	s0,0(sp)
    80003234:	0141                	addi	sp,sp,16
    80003236:	8082                	ret

0000000080003238 <sys_fork>:

uint64
sys_fork(void)
{
    80003238:	1141                	addi	sp,sp,-16
    8000323a:	e406                	sd	ra,8(sp)
    8000323c:	e022                	sd	s0,0(sp)
    8000323e:	0800                	addi	s0,sp,16
  return fork();
    80003240:	fffff097          	auipc	ra,0xfffff
    80003244:	e02080e7          	jalr	-510(ra) # 80002042 <fork>
}
    80003248:	60a2                	ld	ra,8(sp)
    8000324a:	6402                	ld	s0,0(sp)
    8000324c:	0141                	addi	sp,sp,16
    8000324e:	8082                	ret

0000000080003250 <sys_wait>:

uint64
sys_wait(void)
{
    80003250:	1101                	addi	sp,sp,-32
    80003252:	ec06                	sd	ra,24(sp)
    80003254:	e822                	sd	s0,16(sp)
    80003256:	1000                	addi	s0,sp,32
  uint64 p;
  argaddr(0, &p);
    80003258:	fe840593          	addi	a1,s0,-24
    8000325c:	4501                	li	a0,0
    8000325e:	00000097          	auipc	ra,0x0
    80003262:	eae080e7          	jalr	-338(ra) # 8000310c <argaddr>
  return wait(p);
    80003266:	fe843503          	ld	a0,-24(s0)
    8000326a:	fffff097          	auipc	ra,0xfffff
    8000326e:	47a080e7          	jalr	1146(ra) # 800026e4 <wait>
}
    80003272:	60e2                	ld	ra,24(sp)
    80003274:	6442                	ld	s0,16(sp)
    80003276:	6105                	addi	sp,sp,32
    80003278:	8082                	ret

000000008000327a <sys_sbrk>:

uint64
sys_sbrk(void)
{
    8000327a:	7179                	addi	sp,sp,-48
    8000327c:	f406                	sd	ra,40(sp)
    8000327e:	f022                	sd	s0,32(sp)
    80003280:	ec26                	sd	s1,24(sp)
    80003282:	1800                	addi	s0,sp,48
  uint64 addr;
  int n;

  argint(0, &n);
    80003284:	fdc40593          	addi	a1,s0,-36
    80003288:	4501                	li	a0,0
    8000328a:	00000097          	auipc	ra,0x0
    8000328e:	e62080e7          	jalr	-414(ra) # 800030ec <argint>
  addr = myproc()->sz;
    80003292:	fffff097          	auipc	ra,0xfffff
    80003296:	9a2080e7          	jalr	-1630(ra) # 80001c34 <myproc>
    8000329a:	16853483          	ld	s1,360(a0)
  if (growproc(n) < 0)
    8000329e:	fdc42503          	lw	a0,-36(s0)
    800032a2:	fffff097          	auipc	ra,0xfffff
    800032a6:	d3c080e7          	jalr	-708(ra) # 80001fde <growproc>
    800032aa:	00054863          	bltz	a0,800032ba <sys_sbrk+0x40>
    return -1;
  return addr;
}
    800032ae:	8526                	mv	a0,s1
    800032b0:	70a2                	ld	ra,40(sp)
    800032b2:	7402                	ld	s0,32(sp)
    800032b4:	64e2                	ld	s1,24(sp)
    800032b6:	6145                	addi	sp,sp,48
    800032b8:	8082                	ret
    return -1;
    800032ba:	54fd                	li	s1,-1
    800032bc:	bfcd                	j	800032ae <sys_sbrk+0x34>

00000000800032be <sys_sleep>:

uint64
sys_sleep(void)
{
    800032be:	7139                	addi	sp,sp,-64
    800032c0:	fc06                	sd	ra,56(sp)
    800032c2:	f822                	sd	s0,48(sp)
    800032c4:	f04a                	sd	s2,32(sp)
    800032c6:	0080                	addi	s0,sp,64
  int n;
  uint ticks0;

  argint(0, &n);
    800032c8:	fcc40593          	addi	a1,s0,-52
    800032cc:	4501                	li	a0,0
    800032ce:	00000097          	auipc	ra,0x0
    800032d2:	e1e080e7          	jalr	-482(ra) # 800030ec <argint>
  acquire(&tickslock);
    800032d6:	00018517          	auipc	a0,0x18
    800032da:	6aa50513          	addi	a0,a0,1706 # 8001b980 <tickslock>
    800032de:	ffffe097          	auipc	ra,0xffffe
    800032e2:	95a080e7          	jalr	-1702(ra) # 80000c38 <acquire>
  ticks0 = ticks;
    800032e6:	00005917          	auipc	s2,0x5
    800032ea:	60292903          	lw	s2,1538(s2) # 800088e8 <ticks>
  while (ticks - ticks0 < n)
    800032ee:	fcc42783          	lw	a5,-52(s0)
    800032f2:	c3b9                	beqz	a5,80003338 <sys_sleep+0x7a>
    800032f4:	f426                	sd	s1,40(sp)
    800032f6:	ec4e                	sd	s3,24(sp)
    if (killed(myproc()))
    {
      release(&tickslock);
      return -1;
    }
    sleep(&ticks, &tickslock);
    800032f8:	00018997          	auipc	s3,0x18
    800032fc:	68898993          	addi	s3,s3,1672 # 8001b980 <tickslock>
    80003300:	00005497          	auipc	s1,0x5
    80003304:	5e848493          	addi	s1,s1,1512 # 800088e8 <ticks>
    if (killed(myproc()))
    80003308:	fffff097          	auipc	ra,0xfffff
    8000330c:	92c080e7          	jalr	-1748(ra) # 80001c34 <myproc>
    80003310:	fffff097          	auipc	ra,0xfffff
    80003314:	39c080e7          	jalr	924(ra) # 800026ac <killed>
    80003318:	ed15                	bnez	a0,80003354 <sys_sleep+0x96>
    sleep(&ticks, &tickslock);
    8000331a:	85ce                	mv	a1,s3
    8000331c:	8526                	mv	a0,s1
    8000331e:	fffff097          	auipc	ra,0xfffff
    80003322:	0a0080e7          	jalr	160(ra) # 800023be <sleep>
  while (ticks - ticks0 < n)
    80003326:	409c                	lw	a5,0(s1)
    80003328:	412787bb          	subw	a5,a5,s2
    8000332c:	fcc42703          	lw	a4,-52(s0)
    80003330:	fce7ece3          	bltu	a5,a4,80003308 <sys_sleep+0x4a>
    80003334:	74a2                	ld	s1,40(sp)
    80003336:	69e2                	ld	s3,24(sp)
  }
  release(&tickslock);
    80003338:	00018517          	auipc	a0,0x18
    8000333c:	64850513          	addi	a0,a0,1608 # 8001b980 <tickslock>
    80003340:	ffffe097          	auipc	ra,0xffffe
    80003344:	9ac080e7          	jalr	-1620(ra) # 80000cec <release>
  return 0;
    80003348:	4501                	li	a0,0
}
    8000334a:	70e2                	ld	ra,56(sp)
    8000334c:	7442                	ld	s0,48(sp)
    8000334e:	7902                	ld	s2,32(sp)
    80003350:	6121                	addi	sp,sp,64
    80003352:	8082                	ret
      release(&tickslock);
    80003354:	00018517          	auipc	a0,0x18
    80003358:	62c50513          	addi	a0,a0,1580 # 8001b980 <tickslock>
    8000335c:	ffffe097          	auipc	ra,0xffffe
    80003360:	990080e7          	jalr	-1648(ra) # 80000cec <release>
      return -1;
    80003364:	557d                	li	a0,-1
    80003366:	74a2                	ld	s1,40(sp)
    80003368:	69e2                	ld	s3,24(sp)
    8000336a:	b7c5                	j	8000334a <sys_sleep+0x8c>

000000008000336c <sys_kill>:

uint64
sys_kill(void)
{
    8000336c:	1101                	addi	sp,sp,-32
    8000336e:	ec06                	sd	ra,24(sp)
    80003370:	e822                	sd	s0,16(sp)
    80003372:	1000                	addi	s0,sp,32
  int pid;

  argint(0, &pid);
    80003374:	fec40593          	addi	a1,s0,-20
    80003378:	4501                	li	a0,0
    8000337a:	00000097          	auipc	ra,0x0
    8000337e:	d72080e7          	jalr	-654(ra) # 800030ec <argint>
  return kill(pid);
    80003382:	fec42503          	lw	a0,-20(s0)
    80003386:	fffff097          	auipc	ra,0xfffff
    8000338a:	26c080e7          	jalr	620(ra) # 800025f2 <kill>
}
    8000338e:	60e2                	ld	ra,24(sp)
    80003390:	6442                	ld	s0,16(sp)
    80003392:	6105                	addi	sp,sp,32
    80003394:	8082                	ret

0000000080003396 <sys_uptime>:

// return how many clock tick interrupts have occurred
// since start.
uint64
sys_uptime(void)
{
    80003396:	1101                	addi	sp,sp,-32
    80003398:	ec06                	sd	ra,24(sp)
    8000339a:	e822                	sd	s0,16(sp)
    8000339c:	e426                	sd	s1,8(sp)
    8000339e:	1000                	addi	s0,sp,32
  uint xticks;

  acquire(&tickslock);
    800033a0:	00018517          	auipc	a0,0x18
    800033a4:	5e050513          	addi	a0,a0,1504 # 8001b980 <tickslock>
    800033a8:	ffffe097          	auipc	ra,0xffffe
    800033ac:	890080e7          	jalr	-1904(ra) # 80000c38 <acquire>
  xticks = ticks;
    800033b0:	00005497          	auipc	s1,0x5
    800033b4:	5384a483          	lw	s1,1336(s1) # 800088e8 <ticks>
  release(&tickslock);
    800033b8:	00018517          	auipc	a0,0x18
    800033bc:	5c850513          	addi	a0,a0,1480 # 8001b980 <tickslock>
    800033c0:	ffffe097          	auipc	ra,0xffffe
    800033c4:	92c080e7          	jalr	-1748(ra) # 80000cec <release>
  return xticks;
}
    800033c8:	02049513          	slli	a0,s1,0x20
    800033cc:	9101                	srli	a0,a0,0x20
    800033ce:	60e2                	ld	ra,24(sp)
    800033d0:	6442                	ld	s0,16(sp)
    800033d2:	64a2                	ld	s1,8(sp)
    800033d4:	6105                	addi	sp,sp,32
    800033d6:	8082                	ret

00000000800033d8 <sys_waitx>:

uint64
sys_waitx(void)
{
    800033d8:	7139                	addi	sp,sp,-64
    800033da:	fc06                	sd	ra,56(sp)
    800033dc:	f822                	sd	s0,48(sp)
    800033de:	f426                	sd	s1,40(sp)
    800033e0:	f04a                	sd	s2,32(sp)
    800033e2:	0080                	addi	s0,sp,64
  uint64 addr, addr1, addr2;
  uint wtime, rtime;
  argaddr(0, &addr);
    800033e4:	fd840593          	addi	a1,s0,-40
    800033e8:	4501                	li	a0,0
    800033ea:	00000097          	auipc	ra,0x0
    800033ee:	d22080e7          	jalr	-734(ra) # 8000310c <argaddr>
  argaddr(1, &addr1); // user virtual memory
    800033f2:	fd040593          	addi	a1,s0,-48
    800033f6:	4505                	li	a0,1
    800033f8:	00000097          	auipc	ra,0x0
    800033fc:	d14080e7          	jalr	-748(ra) # 8000310c <argaddr>
  argaddr(2, &addr2);
    80003400:	fc840593          	addi	a1,s0,-56
    80003404:	4509                	li	a0,2
    80003406:	00000097          	auipc	ra,0x0
    8000340a:	d06080e7          	jalr	-762(ra) # 8000310c <argaddr>
  int ret = waitx(addr, &wtime, &rtime);
    8000340e:	fc040613          	addi	a2,s0,-64
    80003412:	fc440593          	addi	a1,s0,-60
    80003416:	fd843503          	ld	a0,-40(s0)
    8000341a:	fffff097          	auipc	ra,0xfffff
    8000341e:	564080e7          	jalr	1380(ra) # 8000297e <waitx>
    80003422:	892a                	mv	s2,a0
  struct proc *p = myproc();
    80003424:	fffff097          	auipc	ra,0xfffff
    80003428:	810080e7          	jalr	-2032(ra) # 80001c34 <myproc>
    8000342c:	84aa                	mv	s1,a0
  if (copyout(p->pagetable, addr1, (char *)&wtime, sizeof(int)) < 0)
    8000342e:	4691                	li	a3,4
    80003430:	fc440613          	addi	a2,s0,-60
    80003434:	fd043583          	ld	a1,-48(s0)
    80003438:	17053503          	ld	a0,368(a0)
    8000343c:	ffffe097          	auipc	ra,0xffffe
    80003440:	2a6080e7          	jalr	678(ra) # 800016e2 <copyout>
    return -1;
    80003444:	57fd                	li	a5,-1
  if (copyout(p->pagetable, addr1, (char *)&wtime, sizeof(int)) < 0)
    80003446:	02054063          	bltz	a0,80003466 <sys_waitx+0x8e>
  if (copyout(p->pagetable, addr2, (char *)&rtime, sizeof(int)) < 0)
    8000344a:	4691                	li	a3,4
    8000344c:	fc040613          	addi	a2,s0,-64
    80003450:	fc843583          	ld	a1,-56(s0)
    80003454:	1704b503          	ld	a0,368(s1)
    80003458:	ffffe097          	auipc	ra,0xffffe
    8000345c:	28a080e7          	jalr	650(ra) # 800016e2 <copyout>
    80003460:	00054a63          	bltz	a0,80003474 <sys_waitx+0x9c>
    return -1;
  return ret;
    80003464:	87ca                	mv	a5,s2
}
    80003466:	853e                	mv	a0,a5
    80003468:	70e2                	ld	ra,56(sp)
    8000346a:	7442                	ld	s0,48(sp)
    8000346c:	74a2                	ld	s1,40(sp)
    8000346e:	7902                	ld	s2,32(sp)
    80003470:	6121                	addi	sp,sp,64
    80003472:	8082                	ret
    return -1;
    80003474:	57fd                	li	a5,-1
    80003476:	bfc5                	j	80003466 <sys_waitx+0x8e>

0000000080003478 <sys_getSysCount>:
    return -1;
  //return p->trapframe->a0;
  return p->syscall_counts[syscall_num-1];
}*/
uint64 sys_getSysCount(void)
{
    80003478:	1101                	addi	sp,sp,-32
    8000347a:	ec06                	sd	ra,24(sp)
    8000347c:	e822                	sd	s0,16(sp)
    8000347e:	1000                	addi	s0,sp,32
  int syscall_num;
  int pid;
  argint(0, &syscall_num);
    80003480:	fec40593          	addi	a1,s0,-20
    80003484:	4501                	li	a0,0
    80003486:	00000097          	auipc	ra,0x0
    8000348a:	c66080e7          	jalr	-922(ra) # 800030ec <argint>
  argint(1, &pid); // Get the PID as a second argument
    8000348e:	fe840593          	addi	a1,s0,-24
    80003492:	4505                	li	a0,1
    80003494:	00000097          	auipc	ra,0x0
    80003498:	c58080e7          	jalr	-936(ra) # 800030ec <argint>

  if (syscall_num >= 32 || syscall_num < 1)
    8000349c:	fec42783          	lw	a5,-20(s0)
    800034a0:	fff7869b          	addiw	a3,a5,-1
    800034a4:	4779                	li	a4,30
    return -1;
    800034a6:	557d                	li	a0,-1
  if (syscall_num >= 32 || syscall_num < 1)
    800034a8:	00d76d63          	bltu	a4,a3,800034c2 <sys_getSysCount+0x4a>
  else
    return syscall_counts[pid][syscall_num - 1];
    800034ac:	fe842783          	lw	a5,-24(s0)
    800034b0:	0796                	slli	a5,a5,0x5
    800034b2:	97b6                	add	a5,a5,a3
    800034b4:	078e                	slli	a5,a5,0x3
    800034b6:	00018717          	auipc	a4,0x18
    800034ba:	4e270713          	addi	a4,a4,1250 # 8001b998 <syscall_counts>
    800034be:	97ba                	add	a5,a5,a4
    800034c0:	6388                	ld	a0,0(a5)
}
    800034c2:	60e2                	ld	ra,24(sp)
    800034c4:	6442                	ld	s0,16(sp)
    800034c6:	6105                	addi	sp,sp,32
    800034c8:	8082                	ret

00000000800034ca <sys_sigalarm>:

uint64
sys_sigalarm(void)
{
    800034ca:	1101                	addi	sp,sp,-32
    800034cc:	ec06                	sd	ra,24(sp)
    800034ce:	e822                	sd	s0,16(sp)
    800034d0:	1000                	addi	s0,sp,32
  int interval;
  uint64 handler;

  argint(0, &interval);
    800034d2:	fec40593          	addi	a1,s0,-20
    800034d6:	4501                	li	a0,0
    800034d8:	00000097          	auipc	ra,0x0
    800034dc:	c14080e7          	jalr	-1004(ra) # 800030ec <argint>
  argaddr(1, &handler);
    800034e0:	fe040593          	addi	a1,s0,-32
    800034e4:	4505                	li	a0,1
    800034e6:	00000097          	auipc	ra,0x0
    800034ea:	c26080e7          	jalr	-986(ra) # 8000310c <argaddr>

  struct proc *p = myproc();
    800034ee:	ffffe097          	auipc	ra,0xffffe
    800034f2:	746080e7          	jalr	1862(ra) # 80001c34 <myproc>
  p->alarm_interval = interval;
    800034f6:	fec42783          	lw	a5,-20(s0)
    800034fa:	10f52023          	sw	a5,256(a0)
  p->alarm_handler = handler;
    800034fe:	fe043783          	ld	a5,-32(s0)
    80003502:	10f53423          	sd	a5,264(a0)
  p->ticks_count = 0;
    80003506:	10052823          	sw	zero,272(a0)
  p->alarm_on = 0;
    8000350a:	10052a23          	sw	zero,276(a0)

  return 0;
}
    8000350e:	4501                	li	a0,0
    80003510:	60e2                	ld	ra,24(sp)
    80003512:	6442                	ld	s0,16(sp)
    80003514:	6105                	addi	sp,sp,32
    80003516:	8082                	ret

0000000080003518 <sys_sigreturn>:

uint64
sys_sigreturn(void)
{
    80003518:	1101                	addi	sp,sp,-32
    8000351a:	ec06                	sd	ra,24(sp)
    8000351c:	e822                	sd	s0,16(sp)
    8000351e:	1000                	addi	s0,sp,32
  struct proc *p = myproc();
    80003520:	ffffe097          	auipc	ra,0xffffe
    80003524:	714080e7          	jalr	1812(ra) # 80001c34 <myproc>
  if (p->alarm_on)
    80003528:	11452783          	lw	a5,276(a0)
    8000352c:	e791                	bnez	a5,80003538 <sys_sigreturn+0x20>
    kfree(p->alarm_tf);
    p->alarm_tf = 0;
    p->alarm_on = 0;
  }
  return 0;
}
    8000352e:	4501                	li	a0,0
    80003530:	60e2                	ld	ra,24(sp)
    80003532:	6442                	ld	s0,16(sp)
    80003534:	6105                	addi	sp,sp,32
    80003536:	8082                	ret
    80003538:	e426                	sd	s1,8(sp)
    8000353a:	84aa                	mv	s1,a0
    *p->trapframe = *p->alarm_tf;
    8000353c:	11853683          	ld	a3,280(a0)
    80003540:	87b6                	mv	a5,a3
    80003542:	17853703          	ld	a4,376(a0)
    80003546:	12068693          	addi	a3,a3,288
    8000354a:	0007b803          	ld	a6,0(a5)
    8000354e:	6788                	ld	a0,8(a5)
    80003550:	6b8c                	ld	a1,16(a5)
    80003552:	6f90                	ld	a2,24(a5)
    80003554:	01073023          	sd	a6,0(a4)
    80003558:	e708                	sd	a0,8(a4)
    8000355a:	eb0c                	sd	a1,16(a4)
    8000355c:	ef10                	sd	a2,24(a4)
    8000355e:	02078793          	addi	a5,a5,32
    80003562:	02070713          	addi	a4,a4,32
    80003566:	fed792e3          	bne	a5,a3,8000354a <sys_sigreturn+0x32>
    kfree(p->alarm_tf);
    8000356a:	1184b503          	ld	a0,280(s1)
    8000356e:	ffffd097          	auipc	ra,0xffffd
    80003572:	4dc080e7          	jalr	1244(ra) # 80000a4a <kfree>
    p->alarm_tf = 0;
    80003576:	1004bc23          	sd	zero,280(s1)
    p->alarm_on = 0;
    8000357a:	1004aa23          	sw	zero,276(s1)
    8000357e:	64a2                	ld	s1,8(sp)
    80003580:	b77d                	j	8000352e <sys_sigreturn+0x16>

0000000080003582 <sys_settickets>:

uint64 sys_settickets(void) {
    80003582:	1101                	addi	sp,sp,-32
    80003584:	ec06                	sd	ra,24(sp)
    80003586:	e822                	sd	s0,16(sp)
    80003588:	1000                	addi	s0,sp,32
  int num;
  argint(0, &num);
    8000358a:	fec40593          	addi	a1,s0,-20
    8000358e:	4501                	li	a0,0
    80003590:	00000097          	auipc	ra,0x0
    80003594:	b5c080e7          	jalr	-1188(ra) # 800030ec <argint>
  if(num <= 0)
    80003598:	fec42783          	lw	a5,-20(s0)
    return -1;
    8000359c:	557d                	li	a0,-1
  if(num <= 0)
    8000359e:	00f05b63          	blez	a5,800035b4 <sys_settickets+0x32>
  struct proc *p = myproc();
    800035a2:	ffffe097          	auipc	ra,0xffffe
    800035a6:	692080e7          	jalr	1682(ra) # 80001c34 <myproc>
  p->tickets = num;
    800035aa:	fec42783          	lw	a5,-20(s0)
    800035ae:	28f52a23          	sw	a5,660(a0)
  //printf("Process PID: %d set to %d tickets\n", p->pid, p->tickets);
  return num;
    800035b2:	853e                	mv	a0,a5
}
    800035b4:	60e2                	ld	ra,24(sp)
    800035b6:	6442                	ld	s0,16(sp)
    800035b8:	6105                	addi	sp,sp,32
    800035ba:	8082                	ret

00000000800035bc <binit>:
  struct buf head;
} bcache;

void
binit(void)
{
    800035bc:	7179                	addi	sp,sp,-48
    800035be:	f406                	sd	ra,40(sp)
    800035c0:	f022                	sd	s0,32(sp)
    800035c2:	ec26                	sd	s1,24(sp)
    800035c4:	e84a                	sd	s2,16(sp)
    800035c6:	e44e                	sd	s3,8(sp)
    800035c8:	e052                	sd	s4,0(sp)
    800035ca:	1800                	addi	s0,sp,48
  struct buf *b;

  initlock(&bcache.lock, "bcache");
    800035cc:	00005597          	auipc	a1,0x5
    800035d0:	e1c58593          	addi	a1,a1,-484 # 800083e8 <etext+0x3e8>
    800035d4:	0001c517          	auipc	a0,0x1c
    800035d8:	3c450513          	addi	a0,a0,964 # 8001f998 <bcache>
    800035dc:	ffffd097          	auipc	ra,0xffffd
    800035e0:	5cc080e7          	jalr	1484(ra) # 80000ba8 <initlock>

  // Create linked list of buffers
  bcache.head.prev = &bcache.head;
    800035e4:	00024797          	auipc	a5,0x24
    800035e8:	3b478793          	addi	a5,a5,948 # 80027998 <bcache+0x8000>
    800035ec:	00024717          	auipc	a4,0x24
    800035f0:	61470713          	addi	a4,a4,1556 # 80027c00 <bcache+0x8268>
    800035f4:	2ae7b823          	sd	a4,688(a5)
  bcache.head.next = &bcache.head;
    800035f8:	2ae7bc23          	sd	a4,696(a5)
  for(b = bcache.buf; b < bcache.buf+NBUF; b++){
    800035fc:	0001c497          	auipc	s1,0x1c
    80003600:	3b448493          	addi	s1,s1,948 # 8001f9b0 <bcache+0x18>
    b->next = bcache.head.next;
    80003604:	893e                	mv	s2,a5
    b->prev = &bcache.head;
    80003606:	89ba                	mv	s3,a4
    initsleeplock(&b->lock, "buffer");
    80003608:	00005a17          	auipc	s4,0x5
    8000360c:	de8a0a13          	addi	s4,s4,-536 # 800083f0 <etext+0x3f0>
    b->next = bcache.head.next;
    80003610:	2b893783          	ld	a5,696(s2)
    80003614:	e8bc                	sd	a5,80(s1)
    b->prev = &bcache.head;
    80003616:	0534b423          	sd	s3,72(s1)
    initsleeplock(&b->lock, "buffer");
    8000361a:	85d2                	mv	a1,s4
    8000361c:	01048513          	addi	a0,s1,16
    80003620:	00001097          	auipc	ra,0x1
    80003624:	4e8080e7          	jalr	1256(ra) # 80004b08 <initsleeplock>
    bcache.head.next->prev = b;
    80003628:	2b893783          	ld	a5,696(s2)
    8000362c:	e7a4                	sd	s1,72(a5)
    bcache.head.next = b;
    8000362e:	2a993c23          	sd	s1,696(s2)
  for(b = bcache.buf; b < bcache.buf+NBUF; b++){
    80003632:	45848493          	addi	s1,s1,1112
    80003636:	fd349de3          	bne	s1,s3,80003610 <binit+0x54>
  }
}
    8000363a:	70a2                	ld	ra,40(sp)
    8000363c:	7402                	ld	s0,32(sp)
    8000363e:	64e2                	ld	s1,24(sp)
    80003640:	6942                	ld	s2,16(sp)
    80003642:	69a2                	ld	s3,8(sp)
    80003644:	6a02                	ld	s4,0(sp)
    80003646:	6145                	addi	sp,sp,48
    80003648:	8082                	ret

000000008000364a <bread>:
}

// Return a locked buf with the contents of the indicated block.
struct buf*
bread(uint dev, uint blockno)
{
    8000364a:	7179                	addi	sp,sp,-48
    8000364c:	f406                	sd	ra,40(sp)
    8000364e:	f022                	sd	s0,32(sp)
    80003650:	ec26                	sd	s1,24(sp)
    80003652:	e84a                	sd	s2,16(sp)
    80003654:	e44e                	sd	s3,8(sp)
    80003656:	1800                	addi	s0,sp,48
    80003658:	892a                	mv	s2,a0
    8000365a:	89ae                	mv	s3,a1
  acquire(&bcache.lock);
    8000365c:	0001c517          	auipc	a0,0x1c
    80003660:	33c50513          	addi	a0,a0,828 # 8001f998 <bcache>
    80003664:	ffffd097          	auipc	ra,0xffffd
    80003668:	5d4080e7          	jalr	1492(ra) # 80000c38 <acquire>
  for(b = bcache.head.next; b != &bcache.head; b = b->next){
    8000366c:	00024497          	auipc	s1,0x24
    80003670:	5e44b483          	ld	s1,1508(s1) # 80027c50 <bcache+0x82b8>
    80003674:	00024797          	auipc	a5,0x24
    80003678:	58c78793          	addi	a5,a5,1420 # 80027c00 <bcache+0x8268>
    8000367c:	02f48f63          	beq	s1,a5,800036ba <bread+0x70>
    80003680:	873e                	mv	a4,a5
    80003682:	a021                	j	8000368a <bread+0x40>
    80003684:	68a4                	ld	s1,80(s1)
    80003686:	02e48a63          	beq	s1,a4,800036ba <bread+0x70>
    if(b->dev == dev && b->blockno == blockno){
    8000368a:	449c                	lw	a5,8(s1)
    8000368c:	ff279ce3          	bne	a5,s2,80003684 <bread+0x3a>
    80003690:	44dc                	lw	a5,12(s1)
    80003692:	ff3799e3          	bne	a5,s3,80003684 <bread+0x3a>
      b->refcnt++;
    80003696:	40bc                	lw	a5,64(s1)
    80003698:	2785                	addiw	a5,a5,1
    8000369a:	c0bc                	sw	a5,64(s1)
      release(&bcache.lock);
    8000369c:	0001c517          	auipc	a0,0x1c
    800036a0:	2fc50513          	addi	a0,a0,764 # 8001f998 <bcache>
    800036a4:	ffffd097          	auipc	ra,0xffffd
    800036a8:	648080e7          	jalr	1608(ra) # 80000cec <release>
      acquiresleep(&b->lock);
    800036ac:	01048513          	addi	a0,s1,16
    800036b0:	00001097          	auipc	ra,0x1
    800036b4:	492080e7          	jalr	1170(ra) # 80004b42 <acquiresleep>
      return b;
    800036b8:	a8b9                	j	80003716 <bread+0xcc>
  for(b = bcache.head.prev; b != &bcache.head; b = b->prev){
    800036ba:	00024497          	auipc	s1,0x24
    800036be:	58e4b483          	ld	s1,1422(s1) # 80027c48 <bcache+0x82b0>
    800036c2:	00024797          	auipc	a5,0x24
    800036c6:	53e78793          	addi	a5,a5,1342 # 80027c00 <bcache+0x8268>
    800036ca:	00f48863          	beq	s1,a5,800036da <bread+0x90>
    800036ce:	873e                	mv	a4,a5
    if(b->refcnt == 0) {
    800036d0:	40bc                	lw	a5,64(s1)
    800036d2:	cf81                	beqz	a5,800036ea <bread+0xa0>
  for(b = bcache.head.prev; b != &bcache.head; b = b->prev){
    800036d4:	64a4                	ld	s1,72(s1)
    800036d6:	fee49de3          	bne	s1,a4,800036d0 <bread+0x86>
  panic("bget: no buffers");
    800036da:	00005517          	auipc	a0,0x5
    800036de:	d1e50513          	addi	a0,a0,-738 # 800083f8 <etext+0x3f8>
    800036e2:	ffffd097          	auipc	ra,0xffffd
    800036e6:	e7e080e7          	jalr	-386(ra) # 80000560 <panic>
      b->dev = dev;
    800036ea:	0124a423          	sw	s2,8(s1)
      b->blockno = blockno;
    800036ee:	0134a623          	sw	s3,12(s1)
      b->valid = 0;
    800036f2:	0004a023          	sw	zero,0(s1)
      b->refcnt = 1;
    800036f6:	4785                	li	a5,1
    800036f8:	c0bc                	sw	a5,64(s1)
      release(&bcache.lock);
    800036fa:	0001c517          	auipc	a0,0x1c
    800036fe:	29e50513          	addi	a0,a0,670 # 8001f998 <bcache>
    80003702:	ffffd097          	auipc	ra,0xffffd
    80003706:	5ea080e7          	jalr	1514(ra) # 80000cec <release>
      acquiresleep(&b->lock);
    8000370a:	01048513          	addi	a0,s1,16
    8000370e:	00001097          	auipc	ra,0x1
    80003712:	434080e7          	jalr	1076(ra) # 80004b42 <acquiresleep>
  struct buf *b;

  b = bget(dev, blockno);
  if(!b->valid) {
    80003716:	409c                	lw	a5,0(s1)
    80003718:	cb89                	beqz	a5,8000372a <bread+0xe0>
    virtio_disk_rw(b, 0);
    b->valid = 1;
  }
  return b;
}
    8000371a:	8526                	mv	a0,s1
    8000371c:	70a2                	ld	ra,40(sp)
    8000371e:	7402                	ld	s0,32(sp)
    80003720:	64e2                	ld	s1,24(sp)
    80003722:	6942                	ld	s2,16(sp)
    80003724:	69a2                	ld	s3,8(sp)
    80003726:	6145                	addi	sp,sp,48
    80003728:	8082                	ret
    virtio_disk_rw(b, 0);
    8000372a:	4581                	li	a1,0
    8000372c:	8526                	mv	a0,s1
    8000372e:	00003097          	auipc	ra,0x3
    80003732:	10a080e7          	jalr	266(ra) # 80006838 <virtio_disk_rw>
    b->valid = 1;
    80003736:	4785                	li	a5,1
    80003738:	c09c                	sw	a5,0(s1)
  return b;
    8000373a:	b7c5                	j	8000371a <bread+0xd0>

000000008000373c <bwrite>:

// Write b's contents to disk.  Must be locked.
void
bwrite(struct buf *b)
{
    8000373c:	1101                	addi	sp,sp,-32
    8000373e:	ec06                	sd	ra,24(sp)
    80003740:	e822                	sd	s0,16(sp)
    80003742:	e426                	sd	s1,8(sp)
    80003744:	1000                	addi	s0,sp,32
    80003746:	84aa                	mv	s1,a0
  if(!holdingsleep(&b->lock))
    80003748:	0541                	addi	a0,a0,16
    8000374a:	00001097          	auipc	ra,0x1
    8000374e:	494080e7          	jalr	1172(ra) # 80004bde <holdingsleep>
    80003752:	cd01                	beqz	a0,8000376a <bwrite+0x2e>
    panic("bwrite");
  virtio_disk_rw(b, 1);
    80003754:	4585                	li	a1,1
    80003756:	8526                	mv	a0,s1
    80003758:	00003097          	auipc	ra,0x3
    8000375c:	0e0080e7          	jalr	224(ra) # 80006838 <virtio_disk_rw>
}
    80003760:	60e2                	ld	ra,24(sp)
    80003762:	6442                	ld	s0,16(sp)
    80003764:	64a2                	ld	s1,8(sp)
    80003766:	6105                	addi	sp,sp,32
    80003768:	8082                	ret
    panic("bwrite");
    8000376a:	00005517          	auipc	a0,0x5
    8000376e:	ca650513          	addi	a0,a0,-858 # 80008410 <etext+0x410>
    80003772:	ffffd097          	auipc	ra,0xffffd
    80003776:	dee080e7          	jalr	-530(ra) # 80000560 <panic>

000000008000377a <brelse>:

// Release a locked buffer.
// Move to the head of the most-recently-used list.
void
brelse(struct buf *b)
{
    8000377a:	1101                	addi	sp,sp,-32
    8000377c:	ec06                	sd	ra,24(sp)
    8000377e:	e822                	sd	s0,16(sp)
    80003780:	e426                	sd	s1,8(sp)
    80003782:	e04a                	sd	s2,0(sp)
    80003784:	1000                	addi	s0,sp,32
    80003786:	84aa                	mv	s1,a0
  if(!holdingsleep(&b->lock))
    80003788:	01050913          	addi	s2,a0,16
    8000378c:	854a                	mv	a0,s2
    8000378e:	00001097          	auipc	ra,0x1
    80003792:	450080e7          	jalr	1104(ra) # 80004bde <holdingsleep>
    80003796:	c925                	beqz	a0,80003806 <brelse+0x8c>
    panic("brelse");

  releasesleep(&b->lock);
    80003798:	854a                	mv	a0,s2
    8000379a:	00001097          	auipc	ra,0x1
    8000379e:	400080e7          	jalr	1024(ra) # 80004b9a <releasesleep>

  acquire(&bcache.lock);
    800037a2:	0001c517          	auipc	a0,0x1c
    800037a6:	1f650513          	addi	a0,a0,502 # 8001f998 <bcache>
    800037aa:	ffffd097          	auipc	ra,0xffffd
    800037ae:	48e080e7          	jalr	1166(ra) # 80000c38 <acquire>
  b->refcnt--;
    800037b2:	40bc                	lw	a5,64(s1)
    800037b4:	37fd                	addiw	a5,a5,-1
    800037b6:	0007871b          	sext.w	a4,a5
    800037ba:	c0bc                	sw	a5,64(s1)
  if (b->refcnt == 0) {
    800037bc:	e71d                	bnez	a4,800037ea <brelse+0x70>
    // no one is waiting for it.
    b->next->prev = b->prev;
    800037be:	68b8                	ld	a4,80(s1)
    800037c0:	64bc                	ld	a5,72(s1)
    800037c2:	e73c                	sd	a5,72(a4)
    b->prev->next = b->next;
    800037c4:	68b8                	ld	a4,80(s1)
    800037c6:	ebb8                	sd	a4,80(a5)
    b->next = bcache.head.next;
    800037c8:	00024797          	auipc	a5,0x24
    800037cc:	1d078793          	addi	a5,a5,464 # 80027998 <bcache+0x8000>
    800037d0:	2b87b703          	ld	a4,696(a5)
    800037d4:	e8b8                	sd	a4,80(s1)
    b->prev = &bcache.head;
    800037d6:	00024717          	auipc	a4,0x24
    800037da:	42a70713          	addi	a4,a4,1066 # 80027c00 <bcache+0x8268>
    800037de:	e4b8                	sd	a4,72(s1)
    bcache.head.next->prev = b;
    800037e0:	2b87b703          	ld	a4,696(a5)
    800037e4:	e724                	sd	s1,72(a4)
    bcache.head.next = b;
    800037e6:	2a97bc23          	sd	s1,696(a5)
  }
  
  release(&bcache.lock);
    800037ea:	0001c517          	auipc	a0,0x1c
    800037ee:	1ae50513          	addi	a0,a0,430 # 8001f998 <bcache>
    800037f2:	ffffd097          	auipc	ra,0xffffd
    800037f6:	4fa080e7          	jalr	1274(ra) # 80000cec <release>
}
    800037fa:	60e2                	ld	ra,24(sp)
    800037fc:	6442                	ld	s0,16(sp)
    800037fe:	64a2                	ld	s1,8(sp)
    80003800:	6902                	ld	s2,0(sp)
    80003802:	6105                	addi	sp,sp,32
    80003804:	8082                	ret
    panic("brelse");
    80003806:	00005517          	auipc	a0,0x5
    8000380a:	c1250513          	addi	a0,a0,-1006 # 80008418 <etext+0x418>
    8000380e:	ffffd097          	auipc	ra,0xffffd
    80003812:	d52080e7          	jalr	-686(ra) # 80000560 <panic>

0000000080003816 <bpin>:

void
bpin(struct buf *b) {
    80003816:	1101                	addi	sp,sp,-32
    80003818:	ec06                	sd	ra,24(sp)
    8000381a:	e822                	sd	s0,16(sp)
    8000381c:	e426                	sd	s1,8(sp)
    8000381e:	1000                	addi	s0,sp,32
    80003820:	84aa                	mv	s1,a0
  acquire(&bcache.lock);
    80003822:	0001c517          	auipc	a0,0x1c
    80003826:	17650513          	addi	a0,a0,374 # 8001f998 <bcache>
    8000382a:	ffffd097          	auipc	ra,0xffffd
    8000382e:	40e080e7          	jalr	1038(ra) # 80000c38 <acquire>
  b->refcnt++;
    80003832:	40bc                	lw	a5,64(s1)
    80003834:	2785                	addiw	a5,a5,1
    80003836:	c0bc                	sw	a5,64(s1)
  release(&bcache.lock);
    80003838:	0001c517          	auipc	a0,0x1c
    8000383c:	16050513          	addi	a0,a0,352 # 8001f998 <bcache>
    80003840:	ffffd097          	auipc	ra,0xffffd
    80003844:	4ac080e7          	jalr	1196(ra) # 80000cec <release>
}
    80003848:	60e2                	ld	ra,24(sp)
    8000384a:	6442                	ld	s0,16(sp)
    8000384c:	64a2                	ld	s1,8(sp)
    8000384e:	6105                	addi	sp,sp,32
    80003850:	8082                	ret

0000000080003852 <bunpin>:

void
bunpin(struct buf *b) {
    80003852:	1101                	addi	sp,sp,-32
    80003854:	ec06                	sd	ra,24(sp)
    80003856:	e822                	sd	s0,16(sp)
    80003858:	e426                	sd	s1,8(sp)
    8000385a:	1000                	addi	s0,sp,32
    8000385c:	84aa                	mv	s1,a0
  acquire(&bcache.lock);
    8000385e:	0001c517          	auipc	a0,0x1c
    80003862:	13a50513          	addi	a0,a0,314 # 8001f998 <bcache>
    80003866:	ffffd097          	auipc	ra,0xffffd
    8000386a:	3d2080e7          	jalr	978(ra) # 80000c38 <acquire>
  b->refcnt--;
    8000386e:	40bc                	lw	a5,64(s1)
    80003870:	37fd                	addiw	a5,a5,-1
    80003872:	c0bc                	sw	a5,64(s1)
  release(&bcache.lock);
    80003874:	0001c517          	auipc	a0,0x1c
    80003878:	12450513          	addi	a0,a0,292 # 8001f998 <bcache>
    8000387c:	ffffd097          	auipc	ra,0xffffd
    80003880:	470080e7          	jalr	1136(ra) # 80000cec <release>
}
    80003884:	60e2                	ld	ra,24(sp)
    80003886:	6442                	ld	s0,16(sp)
    80003888:	64a2                	ld	s1,8(sp)
    8000388a:	6105                	addi	sp,sp,32
    8000388c:	8082                	ret

000000008000388e <bfree>:
}

// Free a disk block.
static void
bfree(int dev, uint b)
{
    8000388e:	1101                	addi	sp,sp,-32
    80003890:	ec06                	sd	ra,24(sp)
    80003892:	e822                	sd	s0,16(sp)
    80003894:	e426                	sd	s1,8(sp)
    80003896:	e04a                	sd	s2,0(sp)
    80003898:	1000                	addi	s0,sp,32
    8000389a:	84ae                	mv	s1,a1
  struct buf *bp;
  int bi, m;

  bp = bread(dev, BBLOCK(b, sb));
    8000389c:	00d5d59b          	srliw	a1,a1,0xd
    800038a0:	00024797          	auipc	a5,0x24
    800038a4:	7d47a783          	lw	a5,2004(a5) # 80028074 <sb+0x1c>
    800038a8:	9dbd                	addw	a1,a1,a5
    800038aa:	00000097          	auipc	ra,0x0
    800038ae:	da0080e7          	jalr	-608(ra) # 8000364a <bread>
  bi = b % BPB;
  m = 1 << (bi % 8);
    800038b2:	0074f713          	andi	a4,s1,7
    800038b6:	4785                	li	a5,1
    800038b8:	00e797bb          	sllw	a5,a5,a4
  if((bp->data[bi/8] & m) == 0)
    800038bc:	14ce                	slli	s1,s1,0x33
    800038be:	90d9                	srli	s1,s1,0x36
    800038c0:	00950733          	add	a4,a0,s1
    800038c4:	05874703          	lbu	a4,88(a4)
    800038c8:	00e7f6b3          	and	a3,a5,a4
    800038cc:	c69d                	beqz	a3,800038fa <bfree+0x6c>
    800038ce:	892a                	mv	s2,a0
    panic("freeing free block");
  bp->data[bi/8] &= ~m;
    800038d0:	94aa                	add	s1,s1,a0
    800038d2:	fff7c793          	not	a5,a5
    800038d6:	8f7d                	and	a4,a4,a5
    800038d8:	04e48c23          	sb	a4,88(s1)
  log_write(bp);
    800038dc:	00001097          	auipc	ra,0x1
    800038e0:	148080e7          	jalr	328(ra) # 80004a24 <log_write>
  brelse(bp);
    800038e4:	854a                	mv	a0,s2
    800038e6:	00000097          	auipc	ra,0x0
    800038ea:	e94080e7          	jalr	-364(ra) # 8000377a <brelse>
}
    800038ee:	60e2                	ld	ra,24(sp)
    800038f0:	6442                	ld	s0,16(sp)
    800038f2:	64a2                	ld	s1,8(sp)
    800038f4:	6902                	ld	s2,0(sp)
    800038f6:	6105                	addi	sp,sp,32
    800038f8:	8082                	ret
    panic("freeing free block");
    800038fa:	00005517          	auipc	a0,0x5
    800038fe:	b2650513          	addi	a0,a0,-1242 # 80008420 <etext+0x420>
    80003902:	ffffd097          	auipc	ra,0xffffd
    80003906:	c5e080e7          	jalr	-930(ra) # 80000560 <panic>

000000008000390a <balloc>:
{
    8000390a:	711d                	addi	sp,sp,-96
    8000390c:	ec86                	sd	ra,88(sp)
    8000390e:	e8a2                	sd	s0,80(sp)
    80003910:	e4a6                	sd	s1,72(sp)
    80003912:	1080                	addi	s0,sp,96
  for(b = 0; b < sb.size; b += BPB){
    80003914:	00024797          	auipc	a5,0x24
    80003918:	7487a783          	lw	a5,1864(a5) # 8002805c <sb+0x4>
    8000391c:	10078f63          	beqz	a5,80003a3a <balloc+0x130>
    80003920:	e0ca                	sd	s2,64(sp)
    80003922:	fc4e                	sd	s3,56(sp)
    80003924:	f852                	sd	s4,48(sp)
    80003926:	f456                	sd	s5,40(sp)
    80003928:	f05a                	sd	s6,32(sp)
    8000392a:	ec5e                	sd	s7,24(sp)
    8000392c:	e862                	sd	s8,16(sp)
    8000392e:	e466                	sd	s9,8(sp)
    80003930:	8baa                	mv	s7,a0
    80003932:	4a81                	li	s5,0
    bp = bread(dev, BBLOCK(b, sb));
    80003934:	00024b17          	auipc	s6,0x24
    80003938:	724b0b13          	addi	s6,s6,1828 # 80028058 <sb>
    for(bi = 0; bi < BPB && b + bi < sb.size; bi++){
    8000393c:	4c01                	li	s8,0
      m = 1 << (bi % 8);
    8000393e:	4985                	li	s3,1
    for(bi = 0; bi < BPB && b + bi < sb.size; bi++){
    80003940:	6a09                	lui	s4,0x2
  for(b = 0; b < sb.size; b += BPB){
    80003942:	6c89                	lui	s9,0x2
    80003944:	a061                	j	800039cc <balloc+0xc2>
        bp->data[bi/8] |= m;  // Mark block in use.
    80003946:	97ca                	add	a5,a5,s2
    80003948:	8e55                	or	a2,a2,a3
    8000394a:	04c78c23          	sb	a2,88(a5)
        log_write(bp);
    8000394e:	854a                	mv	a0,s2
    80003950:	00001097          	auipc	ra,0x1
    80003954:	0d4080e7          	jalr	212(ra) # 80004a24 <log_write>
        brelse(bp);
    80003958:	854a                	mv	a0,s2
    8000395a:	00000097          	auipc	ra,0x0
    8000395e:	e20080e7          	jalr	-480(ra) # 8000377a <brelse>
  bp = bread(dev, bno);
    80003962:	85a6                	mv	a1,s1
    80003964:	855e                	mv	a0,s7
    80003966:	00000097          	auipc	ra,0x0
    8000396a:	ce4080e7          	jalr	-796(ra) # 8000364a <bread>
    8000396e:	892a                	mv	s2,a0
  memset(bp->data, 0, BSIZE);
    80003970:	40000613          	li	a2,1024
    80003974:	4581                	li	a1,0
    80003976:	05850513          	addi	a0,a0,88
    8000397a:	ffffd097          	auipc	ra,0xffffd
    8000397e:	3ba080e7          	jalr	954(ra) # 80000d34 <memset>
  log_write(bp);
    80003982:	854a                	mv	a0,s2
    80003984:	00001097          	auipc	ra,0x1
    80003988:	0a0080e7          	jalr	160(ra) # 80004a24 <log_write>
  brelse(bp);
    8000398c:	854a                	mv	a0,s2
    8000398e:	00000097          	auipc	ra,0x0
    80003992:	dec080e7          	jalr	-532(ra) # 8000377a <brelse>
}
    80003996:	6906                	ld	s2,64(sp)
    80003998:	79e2                	ld	s3,56(sp)
    8000399a:	7a42                	ld	s4,48(sp)
    8000399c:	7aa2                	ld	s5,40(sp)
    8000399e:	7b02                	ld	s6,32(sp)
    800039a0:	6be2                	ld	s7,24(sp)
    800039a2:	6c42                	ld	s8,16(sp)
    800039a4:	6ca2                	ld	s9,8(sp)
}
    800039a6:	8526                	mv	a0,s1
    800039a8:	60e6                	ld	ra,88(sp)
    800039aa:	6446                	ld	s0,80(sp)
    800039ac:	64a6                	ld	s1,72(sp)
    800039ae:	6125                	addi	sp,sp,96
    800039b0:	8082                	ret
    brelse(bp);
    800039b2:	854a                	mv	a0,s2
    800039b4:	00000097          	auipc	ra,0x0
    800039b8:	dc6080e7          	jalr	-570(ra) # 8000377a <brelse>
  for(b = 0; b < sb.size; b += BPB){
    800039bc:	015c87bb          	addw	a5,s9,s5
    800039c0:	00078a9b          	sext.w	s5,a5
    800039c4:	004b2703          	lw	a4,4(s6)
    800039c8:	06eaf163          	bgeu	s5,a4,80003a2a <balloc+0x120>
    bp = bread(dev, BBLOCK(b, sb));
    800039cc:	41fad79b          	sraiw	a5,s5,0x1f
    800039d0:	0137d79b          	srliw	a5,a5,0x13
    800039d4:	015787bb          	addw	a5,a5,s5
    800039d8:	40d7d79b          	sraiw	a5,a5,0xd
    800039dc:	01cb2583          	lw	a1,28(s6)
    800039e0:	9dbd                	addw	a1,a1,a5
    800039e2:	855e                	mv	a0,s7
    800039e4:	00000097          	auipc	ra,0x0
    800039e8:	c66080e7          	jalr	-922(ra) # 8000364a <bread>
    800039ec:	892a                	mv	s2,a0
    for(bi = 0; bi < BPB && b + bi < sb.size; bi++){
    800039ee:	004b2503          	lw	a0,4(s6)
    800039f2:	000a849b          	sext.w	s1,s5
    800039f6:	8762                	mv	a4,s8
    800039f8:	faa4fde3          	bgeu	s1,a0,800039b2 <balloc+0xa8>
      m = 1 << (bi % 8);
    800039fc:	00777693          	andi	a3,a4,7
    80003a00:	00d996bb          	sllw	a3,s3,a3
      if((bp->data[bi/8] & m) == 0){  // Is block free?
    80003a04:	41f7579b          	sraiw	a5,a4,0x1f
    80003a08:	01d7d79b          	srliw	a5,a5,0x1d
    80003a0c:	9fb9                	addw	a5,a5,a4
    80003a0e:	4037d79b          	sraiw	a5,a5,0x3
    80003a12:	00f90633          	add	a2,s2,a5
    80003a16:	05864603          	lbu	a2,88(a2)
    80003a1a:	00c6f5b3          	and	a1,a3,a2
    80003a1e:	d585                	beqz	a1,80003946 <balloc+0x3c>
    for(bi = 0; bi < BPB && b + bi < sb.size; bi++){
    80003a20:	2705                	addiw	a4,a4,1
    80003a22:	2485                	addiw	s1,s1,1
    80003a24:	fd471ae3          	bne	a4,s4,800039f8 <balloc+0xee>
    80003a28:	b769                	j	800039b2 <balloc+0xa8>
    80003a2a:	6906                	ld	s2,64(sp)
    80003a2c:	79e2                	ld	s3,56(sp)
    80003a2e:	7a42                	ld	s4,48(sp)
    80003a30:	7aa2                	ld	s5,40(sp)
    80003a32:	7b02                	ld	s6,32(sp)
    80003a34:	6be2                	ld	s7,24(sp)
    80003a36:	6c42                	ld	s8,16(sp)
    80003a38:	6ca2                	ld	s9,8(sp)
  printf("balloc: out of blocks\n");
    80003a3a:	00005517          	auipc	a0,0x5
    80003a3e:	9fe50513          	addi	a0,a0,-1538 # 80008438 <etext+0x438>
    80003a42:	ffffd097          	auipc	ra,0xffffd
    80003a46:	b68080e7          	jalr	-1176(ra) # 800005aa <printf>
  return 0;
    80003a4a:	4481                	li	s1,0
    80003a4c:	bfa9                	j	800039a6 <balloc+0x9c>

0000000080003a4e <bmap>:
// Return the disk block address of the nth block in inode ip.
// If there is no such block, bmap allocates one.
// returns 0 if out of disk space.
static uint
bmap(struct inode *ip, uint bn)
{
    80003a4e:	7179                	addi	sp,sp,-48
    80003a50:	f406                	sd	ra,40(sp)
    80003a52:	f022                	sd	s0,32(sp)
    80003a54:	ec26                	sd	s1,24(sp)
    80003a56:	e84a                	sd	s2,16(sp)
    80003a58:	e44e                	sd	s3,8(sp)
    80003a5a:	1800                	addi	s0,sp,48
    80003a5c:	89aa                	mv	s3,a0
  uint addr, *a;
  struct buf *bp;

  if(bn < NDIRECT){
    80003a5e:	47ad                	li	a5,11
    80003a60:	02b7e863          	bltu	a5,a1,80003a90 <bmap+0x42>
    if((addr = ip->addrs[bn]) == 0){
    80003a64:	02059793          	slli	a5,a1,0x20
    80003a68:	01e7d593          	srli	a1,a5,0x1e
    80003a6c:	00b504b3          	add	s1,a0,a1
    80003a70:	0504a903          	lw	s2,80(s1)
    80003a74:	08091263          	bnez	s2,80003af8 <bmap+0xaa>
      addr = balloc(ip->dev);
    80003a78:	4108                	lw	a0,0(a0)
    80003a7a:	00000097          	auipc	ra,0x0
    80003a7e:	e90080e7          	jalr	-368(ra) # 8000390a <balloc>
    80003a82:	0005091b          	sext.w	s2,a0
      if(addr == 0)
    80003a86:	06090963          	beqz	s2,80003af8 <bmap+0xaa>
        return 0;
      ip->addrs[bn] = addr;
    80003a8a:	0524a823          	sw	s2,80(s1)
    80003a8e:	a0ad                	j	80003af8 <bmap+0xaa>
    }
    return addr;
  }
  bn -= NDIRECT;
    80003a90:	ff45849b          	addiw	s1,a1,-12
    80003a94:	0004871b          	sext.w	a4,s1

  if(bn < NINDIRECT){
    80003a98:	0ff00793          	li	a5,255
    80003a9c:	08e7e863          	bltu	a5,a4,80003b2c <bmap+0xde>
    // Load indirect block, allocating if necessary.
    if((addr = ip->addrs[NDIRECT]) == 0){
    80003aa0:	08052903          	lw	s2,128(a0)
    80003aa4:	00091f63          	bnez	s2,80003ac2 <bmap+0x74>
      addr = balloc(ip->dev);
    80003aa8:	4108                	lw	a0,0(a0)
    80003aaa:	00000097          	auipc	ra,0x0
    80003aae:	e60080e7          	jalr	-416(ra) # 8000390a <balloc>
    80003ab2:	0005091b          	sext.w	s2,a0
      if(addr == 0)
    80003ab6:	04090163          	beqz	s2,80003af8 <bmap+0xaa>
    80003aba:	e052                	sd	s4,0(sp)
        return 0;
      ip->addrs[NDIRECT] = addr;
    80003abc:	0929a023          	sw	s2,128(s3)
    80003ac0:	a011                	j	80003ac4 <bmap+0x76>
    80003ac2:	e052                	sd	s4,0(sp)
    }
    bp = bread(ip->dev, addr);
    80003ac4:	85ca                	mv	a1,s2
    80003ac6:	0009a503          	lw	a0,0(s3)
    80003aca:	00000097          	auipc	ra,0x0
    80003ace:	b80080e7          	jalr	-1152(ra) # 8000364a <bread>
    80003ad2:	8a2a                	mv	s4,a0
    a = (uint*)bp->data;
    80003ad4:	05850793          	addi	a5,a0,88
    if((addr = a[bn]) == 0){
    80003ad8:	02049713          	slli	a4,s1,0x20
    80003adc:	01e75593          	srli	a1,a4,0x1e
    80003ae0:	00b784b3          	add	s1,a5,a1
    80003ae4:	0004a903          	lw	s2,0(s1)
    80003ae8:	02090063          	beqz	s2,80003b08 <bmap+0xba>
      if(addr){
        a[bn] = addr;
        log_write(bp);
      }
    }
    brelse(bp);
    80003aec:	8552                	mv	a0,s4
    80003aee:	00000097          	auipc	ra,0x0
    80003af2:	c8c080e7          	jalr	-884(ra) # 8000377a <brelse>
    return addr;
    80003af6:	6a02                	ld	s4,0(sp)
  }

  panic("bmap: out of range");
}
    80003af8:	854a                	mv	a0,s2
    80003afa:	70a2                	ld	ra,40(sp)
    80003afc:	7402                	ld	s0,32(sp)
    80003afe:	64e2                	ld	s1,24(sp)
    80003b00:	6942                	ld	s2,16(sp)
    80003b02:	69a2                	ld	s3,8(sp)
    80003b04:	6145                	addi	sp,sp,48
    80003b06:	8082                	ret
      addr = balloc(ip->dev);
    80003b08:	0009a503          	lw	a0,0(s3)
    80003b0c:	00000097          	auipc	ra,0x0
    80003b10:	dfe080e7          	jalr	-514(ra) # 8000390a <balloc>
    80003b14:	0005091b          	sext.w	s2,a0
      if(addr){
    80003b18:	fc090ae3          	beqz	s2,80003aec <bmap+0x9e>
        a[bn] = addr;
    80003b1c:	0124a023          	sw	s2,0(s1)
        log_write(bp);
    80003b20:	8552                	mv	a0,s4
    80003b22:	00001097          	auipc	ra,0x1
    80003b26:	f02080e7          	jalr	-254(ra) # 80004a24 <log_write>
    80003b2a:	b7c9                	j	80003aec <bmap+0x9e>
    80003b2c:	e052                	sd	s4,0(sp)
  panic("bmap: out of range");
    80003b2e:	00005517          	auipc	a0,0x5
    80003b32:	92250513          	addi	a0,a0,-1758 # 80008450 <etext+0x450>
    80003b36:	ffffd097          	auipc	ra,0xffffd
    80003b3a:	a2a080e7          	jalr	-1494(ra) # 80000560 <panic>

0000000080003b3e <iget>:
{
    80003b3e:	7179                	addi	sp,sp,-48
    80003b40:	f406                	sd	ra,40(sp)
    80003b42:	f022                	sd	s0,32(sp)
    80003b44:	ec26                	sd	s1,24(sp)
    80003b46:	e84a                	sd	s2,16(sp)
    80003b48:	e44e                	sd	s3,8(sp)
    80003b4a:	e052                	sd	s4,0(sp)
    80003b4c:	1800                	addi	s0,sp,48
    80003b4e:	89aa                	mv	s3,a0
    80003b50:	8a2e                	mv	s4,a1
  acquire(&itable.lock);
    80003b52:	00024517          	auipc	a0,0x24
    80003b56:	52650513          	addi	a0,a0,1318 # 80028078 <itable>
    80003b5a:	ffffd097          	auipc	ra,0xffffd
    80003b5e:	0de080e7          	jalr	222(ra) # 80000c38 <acquire>
  empty = 0;
    80003b62:	4901                	li	s2,0
  for(ip = &itable.inode[0]; ip < &itable.inode[NINODE]; ip++){
    80003b64:	00024497          	auipc	s1,0x24
    80003b68:	52c48493          	addi	s1,s1,1324 # 80028090 <itable+0x18>
    80003b6c:	00026697          	auipc	a3,0x26
    80003b70:	fb468693          	addi	a3,a3,-76 # 80029b20 <log>
    80003b74:	a039                	j	80003b82 <iget+0x44>
    if(empty == 0 && ip->ref == 0)    // Remember empty slot.
    80003b76:	02090b63          	beqz	s2,80003bac <iget+0x6e>
  for(ip = &itable.inode[0]; ip < &itable.inode[NINODE]; ip++){
    80003b7a:	08848493          	addi	s1,s1,136
    80003b7e:	02d48a63          	beq	s1,a3,80003bb2 <iget+0x74>
    if(ip->ref > 0 && ip->dev == dev && ip->inum == inum){
    80003b82:	449c                	lw	a5,8(s1)
    80003b84:	fef059e3          	blez	a5,80003b76 <iget+0x38>
    80003b88:	4098                	lw	a4,0(s1)
    80003b8a:	ff3716e3          	bne	a4,s3,80003b76 <iget+0x38>
    80003b8e:	40d8                	lw	a4,4(s1)
    80003b90:	ff4713e3          	bne	a4,s4,80003b76 <iget+0x38>
      ip->ref++;
    80003b94:	2785                	addiw	a5,a5,1
    80003b96:	c49c                	sw	a5,8(s1)
      release(&itable.lock);
    80003b98:	00024517          	auipc	a0,0x24
    80003b9c:	4e050513          	addi	a0,a0,1248 # 80028078 <itable>
    80003ba0:	ffffd097          	auipc	ra,0xffffd
    80003ba4:	14c080e7          	jalr	332(ra) # 80000cec <release>
      return ip;
    80003ba8:	8926                	mv	s2,s1
    80003baa:	a03d                	j	80003bd8 <iget+0x9a>
    if(empty == 0 && ip->ref == 0)    // Remember empty slot.
    80003bac:	f7f9                	bnez	a5,80003b7a <iget+0x3c>
      empty = ip;
    80003bae:	8926                	mv	s2,s1
    80003bb0:	b7e9                	j	80003b7a <iget+0x3c>
  if(empty == 0)
    80003bb2:	02090c63          	beqz	s2,80003bea <iget+0xac>
  ip->dev = dev;
    80003bb6:	01392023          	sw	s3,0(s2)
  ip->inum = inum;
    80003bba:	01492223          	sw	s4,4(s2)
  ip->ref = 1;
    80003bbe:	4785                	li	a5,1
    80003bc0:	00f92423          	sw	a5,8(s2)
  ip->valid = 0;
    80003bc4:	04092023          	sw	zero,64(s2)
  release(&itable.lock);
    80003bc8:	00024517          	auipc	a0,0x24
    80003bcc:	4b050513          	addi	a0,a0,1200 # 80028078 <itable>
    80003bd0:	ffffd097          	auipc	ra,0xffffd
    80003bd4:	11c080e7          	jalr	284(ra) # 80000cec <release>
}
    80003bd8:	854a                	mv	a0,s2
    80003bda:	70a2                	ld	ra,40(sp)
    80003bdc:	7402                	ld	s0,32(sp)
    80003bde:	64e2                	ld	s1,24(sp)
    80003be0:	6942                	ld	s2,16(sp)
    80003be2:	69a2                	ld	s3,8(sp)
    80003be4:	6a02                	ld	s4,0(sp)
    80003be6:	6145                	addi	sp,sp,48
    80003be8:	8082                	ret
    panic("iget: no inodes");
    80003bea:	00005517          	auipc	a0,0x5
    80003bee:	87e50513          	addi	a0,a0,-1922 # 80008468 <etext+0x468>
    80003bf2:	ffffd097          	auipc	ra,0xffffd
    80003bf6:	96e080e7          	jalr	-1682(ra) # 80000560 <panic>

0000000080003bfa <fsinit>:
fsinit(int dev) {
    80003bfa:	7179                	addi	sp,sp,-48
    80003bfc:	f406                	sd	ra,40(sp)
    80003bfe:	f022                	sd	s0,32(sp)
    80003c00:	ec26                	sd	s1,24(sp)
    80003c02:	e84a                	sd	s2,16(sp)
    80003c04:	e44e                	sd	s3,8(sp)
    80003c06:	1800                	addi	s0,sp,48
    80003c08:	892a                	mv	s2,a0
  bp = bread(dev, 1);
    80003c0a:	4585                	li	a1,1
    80003c0c:	00000097          	auipc	ra,0x0
    80003c10:	a3e080e7          	jalr	-1474(ra) # 8000364a <bread>
    80003c14:	84aa                	mv	s1,a0
  memmove(sb, bp->data, sizeof(*sb));
    80003c16:	00024997          	auipc	s3,0x24
    80003c1a:	44298993          	addi	s3,s3,1090 # 80028058 <sb>
    80003c1e:	02000613          	li	a2,32
    80003c22:	05850593          	addi	a1,a0,88
    80003c26:	854e                	mv	a0,s3
    80003c28:	ffffd097          	auipc	ra,0xffffd
    80003c2c:	168080e7          	jalr	360(ra) # 80000d90 <memmove>
  brelse(bp);
    80003c30:	8526                	mv	a0,s1
    80003c32:	00000097          	auipc	ra,0x0
    80003c36:	b48080e7          	jalr	-1208(ra) # 8000377a <brelse>
  if(sb.magic != FSMAGIC)
    80003c3a:	0009a703          	lw	a4,0(s3)
    80003c3e:	102037b7          	lui	a5,0x10203
    80003c42:	04078793          	addi	a5,a5,64 # 10203040 <_entry-0x6fdfcfc0>
    80003c46:	02f71263          	bne	a4,a5,80003c6a <fsinit+0x70>
  initlog(dev, &sb);
    80003c4a:	00024597          	auipc	a1,0x24
    80003c4e:	40e58593          	addi	a1,a1,1038 # 80028058 <sb>
    80003c52:	854a                	mv	a0,s2
    80003c54:	00001097          	auipc	ra,0x1
    80003c58:	b60080e7          	jalr	-1184(ra) # 800047b4 <initlog>
}
    80003c5c:	70a2                	ld	ra,40(sp)
    80003c5e:	7402                	ld	s0,32(sp)
    80003c60:	64e2                	ld	s1,24(sp)
    80003c62:	6942                	ld	s2,16(sp)
    80003c64:	69a2                	ld	s3,8(sp)
    80003c66:	6145                	addi	sp,sp,48
    80003c68:	8082                	ret
    panic("invalid file system");
    80003c6a:	00005517          	auipc	a0,0x5
    80003c6e:	80e50513          	addi	a0,a0,-2034 # 80008478 <etext+0x478>
    80003c72:	ffffd097          	auipc	ra,0xffffd
    80003c76:	8ee080e7          	jalr	-1810(ra) # 80000560 <panic>

0000000080003c7a <iinit>:
{
    80003c7a:	7179                	addi	sp,sp,-48
    80003c7c:	f406                	sd	ra,40(sp)
    80003c7e:	f022                	sd	s0,32(sp)
    80003c80:	ec26                	sd	s1,24(sp)
    80003c82:	e84a                	sd	s2,16(sp)
    80003c84:	e44e                	sd	s3,8(sp)
    80003c86:	1800                	addi	s0,sp,48
  initlock(&itable.lock, "itable");
    80003c88:	00005597          	auipc	a1,0x5
    80003c8c:	80858593          	addi	a1,a1,-2040 # 80008490 <etext+0x490>
    80003c90:	00024517          	auipc	a0,0x24
    80003c94:	3e850513          	addi	a0,a0,1000 # 80028078 <itable>
    80003c98:	ffffd097          	auipc	ra,0xffffd
    80003c9c:	f10080e7          	jalr	-240(ra) # 80000ba8 <initlock>
  for(i = 0; i < NINODE; i++) {
    80003ca0:	00024497          	auipc	s1,0x24
    80003ca4:	40048493          	addi	s1,s1,1024 # 800280a0 <itable+0x28>
    80003ca8:	00026997          	auipc	s3,0x26
    80003cac:	e8898993          	addi	s3,s3,-376 # 80029b30 <log+0x10>
    initsleeplock(&itable.inode[i].lock, "inode");
    80003cb0:	00004917          	auipc	s2,0x4
    80003cb4:	7e890913          	addi	s2,s2,2024 # 80008498 <etext+0x498>
    80003cb8:	85ca                	mv	a1,s2
    80003cba:	8526                	mv	a0,s1
    80003cbc:	00001097          	auipc	ra,0x1
    80003cc0:	e4c080e7          	jalr	-436(ra) # 80004b08 <initsleeplock>
  for(i = 0; i < NINODE; i++) {
    80003cc4:	08848493          	addi	s1,s1,136
    80003cc8:	ff3498e3          	bne	s1,s3,80003cb8 <iinit+0x3e>
}
    80003ccc:	70a2                	ld	ra,40(sp)
    80003cce:	7402                	ld	s0,32(sp)
    80003cd0:	64e2                	ld	s1,24(sp)
    80003cd2:	6942                	ld	s2,16(sp)
    80003cd4:	69a2                	ld	s3,8(sp)
    80003cd6:	6145                	addi	sp,sp,48
    80003cd8:	8082                	ret

0000000080003cda <ialloc>:
{
    80003cda:	7139                	addi	sp,sp,-64
    80003cdc:	fc06                	sd	ra,56(sp)
    80003cde:	f822                	sd	s0,48(sp)
    80003ce0:	0080                	addi	s0,sp,64
  for(inum = 1; inum < sb.ninodes; inum++){
    80003ce2:	00024717          	auipc	a4,0x24
    80003ce6:	38272703          	lw	a4,898(a4) # 80028064 <sb+0xc>
    80003cea:	4785                	li	a5,1
    80003cec:	06e7f463          	bgeu	a5,a4,80003d54 <ialloc+0x7a>
    80003cf0:	f426                	sd	s1,40(sp)
    80003cf2:	f04a                	sd	s2,32(sp)
    80003cf4:	ec4e                	sd	s3,24(sp)
    80003cf6:	e852                	sd	s4,16(sp)
    80003cf8:	e456                	sd	s5,8(sp)
    80003cfa:	e05a                	sd	s6,0(sp)
    80003cfc:	8aaa                	mv	s5,a0
    80003cfe:	8b2e                	mv	s6,a1
    80003d00:	4905                	li	s2,1
    bp = bread(dev, IBLOCK(inum, sb));
    80003d02:	00024a17          	auipc	s4,0x24
    80003d06:	356a0a13          	addi	s4,s4,854 # 80028058 <sb>
    80003d0a:	00495593          	srli	a1,s2,0x4
    80003d0e:	018a2783          	lw	a5,24(s4)
    80003d12:	9dbd                	addw	a1,a1,a5
    80003d14:	8556                	mv	a0,s5
    80003d16:	00000097          	auipc	ra,0x0
    80003d1a:	934080e7          	jalr	-1740(ra) # 8000364a <bread>
    80003d1e:	84aa                	mv	s1,a0
    dip = (struct dinode*)bp->data + inum%IPB;
    80003d20:	05850993          	addi	s3,a0,88
    80003d24:	00f97793          	andi	a5,s2,15
    80003d28:	079a                	slli	a5,a5,0x6
    80003d2a:	99be                	add	s3,s3,a5
    if(dip->type == 0){  // a free inode
    80003d2c:	00099783          	lh	a5,0(s3)
    80003d30:	cf9d                	beqz	a5,80003d6e <ialloc+0x94>
    brelse(bp);
    80003d32:	00000097          	auipc	ra,0x0
    80003d36:	a48080e7          	jalr	-1464(ra) # 8000377a <brelse>
  for(inum = 1; inum < sb.ninodes; inum++){
    80003d3a:	0905                	addi	s2,s2,1
    80003d3c:	00ca2703          	lw	a4,12(s4)
    80003d40:	0009079b          	sext.w	a5,s2
    80003d44:	fce7e3e3          	bltu	a5,a4,80003d0a <ialloc+0x30>
    80003d48:	74a2                	ld	s1,40(sp)
    80003d4a:	7902                	ld	s2,32(sp)
    80003d4c:	69e2                	ld	s3,24(sp)
    80003d4e:	6a42                	ld	s4,16(sp)
    80003d50:	6aa2                	ld	s5,8(sp)
    80003d52:	6b02                	ld	s6,0(sp)
  printf("ialloc: no inodes\n");
    80003d54:	00004517          	auipc	a0,0x4
    80003d58:	74c50513          	addi	a0,a0,1868 # 800084a0 <etext+0x4a0>
    80003d5c:	ffffd097          	auipc	ra,0xffffd
    80003d60:	84e080e7          	jalr	-1970(ra) # 800005aa <printf>
  return 0;
    80003d64:	4501                	li	a0,0
}
    80003d66:	70e2                	ld	ra,56(sp)
    80003d68:	7442                	ld	s0,48(sp)
    80003d6a:	6121                	addi	sp,sp,64
    80003d6c:	8082                	ret
      memset(dip, 0, sizeof(*dip));
    80003d6e:	04000613          	li	a2,64
    80003d72:	4581                	li	a1,0
    80003d74:	854e                	mv	a0,s3
    80003d76:	ffffd097          	auipc	ra,0xffffd
    80003d7a:	fbe080e7          	jalr	-66(ra) # 80000d34 <memset>
      dip->type = type;
    80003d7e:	01699023          	sh	s6,0(s3)
      log_write(bp);   // mark it allocated on the disk
    80003d82:	8526                	mv	a0,s1
    80003d84:	00001097          	auipc	ra,0x1
    80003d88:	ca0080e7          	jalr	-864(ra) # 80004a24 <log_write>
      brelse(bp);
    80003d8c:	8526                	mv	a0,s1
    80003d8e:	00000097          	auipc	ra,0x0
    80003d92:	9ec080e7          	jalr	-1556(ra) # 8000377a <brelse>
      return iget(dev, inum);
    80003d96:	0009059b          	sext.w	a1,s2
    80003d9a:	8556                	mv	a0,s5
    80003d9c:	00000097          	auipc	ra,0x0
    80003da0:	da2080e7          	jalr	-606(ra) # 80003b3e <iget>
    80003da4:	74a2                	ld	s1,40(sp)
    80003da6:	7902                	ld	s2,32(sp)
    80003da8:	69e2                	ld	s3,24(sp)
    80003daa:	6a42                	ld	s4,16(sp)
    80003dac:	6aa2                	ld	s5,8(sp)
    80003dae:	6b02                	ld	s6,0(sp)
    80003db0:	bf5d                	j	80003d66 <ialloc+0x8c>

0000000080003db2 <iupdate>:
{
    80003db2:	1101                	addi	sp,sp,-32
    80003db4:	ec06                	sd	ra,24(sp)
    80003db6:	e822                	sd	s0,16(sp)
    80003db8:	e426                	sd	s1,8(sp)
    80003dba:	e04a                	sd	s2,0(sp)
    80003dbc:	1000                	addi	s0,sp,32
    80003dbe:	84aa                	mv	s1,a0
  bp = bread(ip->dev, IBLOCK(ip->inum, sb));
    80003dc0:	415c                	lw	a5,4(a0)
    80003dc2:	0047d79b          	srliw	a5,a5,0x4
    80003dc6:	00024597          	auipc	a1,0x24
    80003dca:	2aa5a583          	lw	a1,682(a1) # 80028070 <sb+0x18>
    80003dce:	9dbd                	addw	a1,a1,a5
    80003dd0:	4108                	lw	a0,0(a0)
    80003dd2:	00000097          	auipc	ra,0x0
    80003dd6:	878080e7          	jalr	-1928(ra) # 8000364a <bread>
    80003dda:	892a                	mv	s2,a0
  dip = (struct dinode*)bp->data + ip->inum%IPB;
    80003ddc:	05850793          	addi	a5,a0,88
    80003de0:	40d8                	lw	a4,4(s1)
    80003de2:	8b3d                	andi	a4,a4,15
    80003de4:	071a                	slli	a4,a4,0x6
    80003de6:	97ba                	add	a5,a5,a4
  dip->type = ip->type;
    80003de8:	04449703          	lh	a4,68(s1)
    80003dec:	00e79023          	sh	a4,0(a5)
  dip->major = ip->major;
    80003df0:	04649703          	lh	a4,70(s1)
    80003df4:	00e79123          	sh	a4,2(a5)
  dip->minor = ip->minor;
    80003df8:	04849703          	lh	a4,72(s1)
    80003dfc:	00e79223          	sh	a4,4(a5)
  dip->nlink = ip->nlink;
    80003e00:	04a49703          	lh	a4,74(s1)
    80003e04:	00e79323          	sh	a4,6(a5)
  dip->size = ip->size;
    80003e08:	44f8                	lw	a4,76(s1)
    80003e0a:	c798                	sw	a4,8(a5)
  memmove(dip->addrs, ip->addrs, sizeof(ip->addrs));
    80003e0c:	03400613          	li	a2,52
    80003e10:	05048593          	addi	a1,s1,80
    80003e14:	00c78513          	addi	a0,a5,12
    80003e18:	ffffd097          	auipc	ra,0xffffd
    80003e1c:	f78080e7          	jalr	-136(ra) # 80000d90 <memmove>
  log_write(bp);
    80003e20:	854a                	mv	a0,s2
    80003e22:	00001097          	auipc	ra,0x1
    80003e26:	c02080e7          	jalr	-1022(ra) # 80004a24 <log_write>
  brelse(bp);
    80003e2a:	854a                	mv	a0,s2
    80003e2c:	00000097          	auipc	ra,0x0
    80003e30:	94e080e7          	jalr	-1714(ra) # 8000377a <brelse>
}
    80003e34:	60e2                	ld	ra,24(sp)
    80003e36:	6442                	ld	s0,16(sp)
    80003e38:	64a2                	ld	s1,8(sp)
    80003e3a:	6902                	ld	s2,0(sp)
    80003e3c:	6105                	addi	sp,sp,32
    80003e3e:	8082                	ret

0000000080003e40 <idup>:
{
    80003e40:	1101                	addi	sp,sp,-32
    80003e42:	ec06                	sd	ra,24(sp)
    80003e44:	e822                	sd	s0,16(sp)
    80003e46:	e426                	sd	s1,8(sp)
    80003e48:	1000                	addi	s0,sp,32
    80003e4a:	84aa                	mv	s1,a0
  acquire(&itable.lock);
    80003e4c:	00024517          	auipc	a0,0x24
    80003e50:	22c50513          	addi	a0,a0,556 # 80028078 <itable>
    80003e54:	ffffd097          	auipc	ra,0xffffd
    80003e58:	de4080e7          	jalr	-540(ra) # 80000c38 <acquire>
  ip->ref++;
    80003e5c:	449c                	lw	a5,8(s1)
    80003e5e:	2785                	addiw	a5,a5,1
    80003e60:	c49c                	sw	a5,8(s1)
  release(&itable.lock);
    80003e62:	00024517          	auipc	a0,0x24
    80003e66:	21650513          	addi	a0,a0,534 # 80028078 <itable>
    80003e6a:	ffffd097          	auipc	ra,0xffffd
    80003e6e:	e82080e7          	jalr	-382(ra) # 80000cec <release>
}
    80003e72:	8526                	mv	a0,s1
    80003e74:	60e2                	ld	ra,24(sp)
    80003e76:	6442                	ld	s0,16(sp)
    80003e78:	64a2                	ld	s1,8(sp)
    80003e7a:	6105                	addi	sp,sp,32
    80003e7c:	8082                	ret

0000000080003e7e <ilock>:
{
    80003e7e:	1101                	addi	sp,sp,-32
    80003e80:	ec06                	sd	ra,24(sp)
    80003e82:	e822                	sd	s0,16(sp)
    80003e84:	e426                	sd	s1,8(sp)
    80003e86:	1000                	addi	s0,sp,32
  if(ip == 0 || ip->ref < 1)
    80003e88:	c10d                	beqz	a0,80003eaa <ilock+0x2c>
    80003e8a:	84aa                	mv	s1,a0
    80003e8c:	451c                	lw	a5,8(a0)
    80003e8e:	00f05e63          	blez	a5,80003eaa <ilock+0x2c>
  acquiresleep(&ip->lock);
    80003e92:	0541                	addi	a0,a0,16
    80003e94:	00001097          	auipc	ra,0x1
    80003e98:	cae080e7          	jalr	-850(ra) # 80004b42 <acquiresleep>
  if(ip->valid == 0){
    80003e9c:	40bc                	lw	a5,64(s1)
    80003e9e:	cf99                	beqz	a5,80003ebc <ilock+0x3e>
}
    80003ea0:	60e2                	ld	ra,24(sp)
    80003ea2:	6442                	ld	s0,16(sp)
    80003ea4:	64a2                	ld	s1,8(sp)
    80003ea6:	6105                	addi	sp,sp,32
    80003ea8:	8082                	ret
    80003eaa:	e04a                	sd	s2,0(sp)
    panic("ilock");
    80003eac:	00004517          	auipc	a0,0x4
    80003eb0:	60c50513          	addi	a0,a0,1548 # 800084b8 <etext+0x4b8>
    80003eb4:	ffffc097          	auipc	ra,0xffffc
    80003eb8:	6ac080e7          	jalr	1708(ra) # 80000560 <panic>
    80003ebc:	e04a                	sd	s2,0(sp)
    bp = bread(ip->dev, IBLOCK(ip->inum, sb));
    80003ebe:	40dc                	lw	a5,4(s1)
    80003ec0:	0047d79b          	srliw	a5,a5,0x4
    80003ec4:	00024597          	auipc	a1,0x24
    80003ec8:	1ac5a583          	lw	a1,428(a1) # 80028070 <sb+0x18>
    80003ecc:	9dbd                	addw	a1,a1,a5
    80003ece:	4088                	lw	a0,0(s1)
    80003ed0:	fffff097          	auipc	ra,0xfffff
    80003ed4:	77a080e7          	jalr	1914(ra) # 8000364a <bread>
    80003ed8:	892a                	mv	s2,a0
    dip = (struct dinode*)bp->data + ip->inum%IPB;
    80003eda:	05850593          	addi	a1,a0,88
    80003ede:	40dc                	lw	a5,4(s1)
    80003ee0:	8bbd                	andi	a5,a5,15
    80003ee2:	079a                	slli	a5,a5,0x6
    80003ee4:	95be                	add	a1,a1,a5
    ip->type = dip->type;
    80003ee6:	00059783          	lh	a5,0(a1)
    80003eea:	04f49223          	sh	a5,68(s1)
    ip->major = dip->major;
    80003eee:	00259783          	lh	a5,2(a1)
    80003ef2:	04f49323          	sh	a5,70(s1)
    ip->minor = dip->minor;
    80003ef6:	00459783          	lh	a5,4(a1)
    80003efa:	04f49423          	sh	a5,72(s1)
    ip->nlink = dip->nlink;
    80003efe:	00659783          	lh	a5,6(a1)
    80003f02:	04f49523          	sh	a5,74(s1)
    ip->size = dip->size;
    80003f06:	459c                	lw	a5,8(a1)
    80003f08:	c4fc                	sw	a5,76(s1)
    memmove(ip->addrs, dip->addrs, sizeof(ip->addrs));
    80003f0a:	03400613          	li	a2,52
    80003f0e:	05b1                	addi	a1,a1,12
    80003f10:	05048513          	addi	a0,s1,80
    80003f14:	ffffd097          	auipc	ra,0xffffd
    80003f18:	e7c080e7          	jalr	-388(ra) # 80000d90 <memmove>
    brelse(bp);
    80003f1c:	854a                	mv	a0,s2
    80003f1e:	00000097          	auipc	ra,0x0
    80003f22:	85c080e7          	jalr	-1956(ra) # 8000377a <brelse>
    ip->valid = 1;
    80003f26:	4785                	li	a5,1
    80003f28:	c0bc                	sw	a5,64(s1)
    if(ip->type == 0)
    80003f2a:	04449783          	lh	a5,68(s1)
    80003f2e:	c399                	beqz	a5,80003f34 <ilock+0xb6>
    80003f30:	6902                	ld	s2,0(sp)
    80003f32:	b7bd                	j	80003ea0 <ilock+0x22>
      panic("ilock: no type");
    80003f34:	00004517          	auipc	a0,0x4
    80003f38:	58c50513          	addi	a0,a0,1420 # 800084c0 <etext+0x4c0>
    80003f3c:	ffffc097          	auipc	ra,0xffffc
    80003f40:	624080e7          	jalr	1572(ra) # 80000560 <panic>

0000000080003f44 <iunlock>:
{
    80003f44:	1101                	addi	sp,sp,-32
    80003f46:	ec06                	sd	ra,24(sp)
    80003f48:	e822                	sd	s0,16(sp)
    80003f4a:	e426                	sd	s1,8(sp)
    80003f4c:	e04a                	sd	s2,0(sp)
    80003f4e:	1000                	addi	s0,sp,32
  if(ip == 0 || !holdingsleep(&ip->lock) || ip->ref < 1)
    80003f50:	c905                	beqz	a0,80003f80 <iunlock+0x3c>
    80003f52:	84aa                	mv	s1,a0
    80003f54:	01050913          	addi	s2,a0,16
    80003f58:	854a                	mv	a0,s2
    80003f5a:	00001097          	auipc	ra,0x1
    80003f5e:	c84080e7          	jalr	-892(ra) # 80004bde <holdingsleep>
    80003f62:	cd19                	beqz	a0,80003f80 <iunlock+0x3c>
    80003f64:	449c                	lw	a5,8(s1)
    80003f66:	00f05d63          	blez	a5,80003f80 <iunlock+0x3c>
  releasesleep(&ip->lock);
    80003f6a:	854a                	mv	a0,s2
    80003f6c:	00001097          	auipc	ra,0x1
    80003f70:	c2e080e7          	jalr	-978(ra) # 80004b9a <releasesleep>
}
    80003f74:	60e2                	ld	ra,24(sp)
    80003f76:	6442                	ld	s0,16(sp)
    80003f78:	64a2                	ld	s1,8(sp)
    80003f7a:	6902                	ld	s2,0(sp)
    80003f7c:	6105                	addi	sp,sp,32
    80003f7e:	8082                	ret
    panic("iunlock");
    80003f80:	00004517          	auipc	a0,0x4
    80003f84:	55050513          	addi	a0,a0,1360 # 800084d0 <etext+0x4d0>
    80003f88:	ffffc097          	auipc	ra,0xffffc
    80003f8c:	5d8080e7          	jalr	1496(ra) # 80000560 <panic>

0000000080003f90 <itrunc>:

// Truncate inode (discard contents).
// Caller must hold ip->lock.
void
itrunc(struct inode *ip)
{
    80003f90:	7179                	addi	sp,sp,-48
    80003f92:	f406                	sd	ra,40(sp)
    80003f94:	f022                	sd	s0,32(sp)
    80003f96:	ec26                	sd	s1,24(sp)
    80003f98:	e84a                	sd	s2,16(sp)
    80003f9a:	e44e                	sd	s3,8(sp)
    80003f9c:	1800                	addi	s0,sp,48
    80003f9e:	89aa                	mv	s3,a0
  int i, j;
  struct buf *bp;
  uint *a;

  for(i = 0; i < NDIRECT; i++){
    80003fa0:	05050493          	addi	s1,a0,80
    80003fa4:	08050913          	addi	s2,a0,128
    80003fa8:	a021                	j	80003fb0 <itrunc+0x20>
    80003faa:	0491                	addi	s1,s1,4
    80003fac:	01248d63          	beq	s1,s2,80003fc6 <itrunc+0x36>
    if(ip->addrs[i]){
    80003fb0:	408c                	lw	a1,0(s1)
    80003fb2:	dde5                	beqz	a1,80003faa <itrunc+0x1a>
      bfree(ip->dev, ip->addrs[i]);
    80003fb4:	0009a503          	lw	a0,0(s3)
    80003fb8:	00000097          	auipc	ra,0x0
    80003fbc:	8d6080e7          	jalr	-1834(ra) # 8000388e <bfree>
      ip->addrs[i] = 0;
    80003fc0:	0004a023          	sw	zero,0(s1)
    80003fc4:	b7dd                	j	80003faa <itrunc+0x1a>
    }
  }

  if(ip->addrs[NDIRECT]){
    80003fc6:	0809a583          	lw	a1,128(s3)
    80003fca:	ed99                	bnez	a1,80003fe8 <itrunc+0x58>
    brelse(bp);
    bfree(ip->dev, ip->addrs[NDIRECT]);
    ip->addrs[NDIRECT] = 0;
  }

  ip->size = 0;
    80003fcc:	0409a623          	sw	zero,76(s3)
  iupdate(ip);
    80003fd0:	854e                	mv	a0,s3
    80003fd2:	00000097          	auipc	ra,0x0
    80003fd6:	de0080e7          	jalr	-544(ra) # 80003db2 <iupdate>
}
    80003fda:	70a2                	ld	ra,40(sp)
    80003fdc:	7402                	ld	s0,32(sp)
    80003fde:	64e2                	ld	s1,24(sp)
    80003fe0:	6942                	ld	s2,16(sp)
    80003fe2:	69a2                	ld	s3,8(sp)
    80003fe4:	6145                	addi	sp,sp,48
    80003fe6:	8082                	ret
    80003fe8:	e052                	sd	s4,0(sp)
    bp = bread(ip->dev, ip->addrs[NDIRECT]);
    80003fea:	0009a503          	lw	a0,0(s3)
    80003fee:	fffff097          	auipc	ra,0xfffff
    80003ff2:	65c080e7          	jalr	1628(ra) # 8000364a <bread>
    80003ff6:	8a2a                	mv	s4,a0
    for(j = 0; j < NINDIRECT; j++){
    80003ff8:	05850493          	addi	s1,a0,88
    80003ffc:	45850913          	addi	s2,a0,1112
    80004000:	a021                	j	80004008 <itrunc+0x78>
    80004002:	0491                	addi	s1,s1,4
    80004004:	01248b63          	beq	s1,s2,8000401a <itrunc+0x8a>
      if(a[j])
    80004008:	408c                	lw	a1,0(s1)
    8000400a:	dde5                	beqz	a1,80004002 <itrunc+0x72>
        bfree(ip->dev, a[j]);
    8000400c:	0009a503          	lw	a0,0(s3)
    80004010:	00000097          	auipc	ra,0x0
    80004014:	87e080e7          	jalr	-1922(ra) # 8000388e <bfree>
    80004018:	b7ed                	j	80004002 <itrunc+0x72>
    brelse(bp);
    8000401a:	8552                	mv	a0,s4
    8000401c:	fffff097          	auipc	ra,0xfffff
    80004020:	75e080e7          	jalr	1886(ra) # 8000377a <brelse>
    bfree(ip->dev, ip->addrs[NDIRECT]);
    80004024:	0809a583          	lw	a1,128(s3)
    80004028:	0009a503          	lw	a0,0(s3)
    8000402c:	00000097          	auipc	ra,0x0
    80004030:	862080e7          	jalr	-1950(ra) # 8000388e <bfree>
    ip->addrs[NDIRECT] = 0;
    80004034:	0809a023          	sw	zero,128(s3)
    80004038:	6a02                	ld	s4,0(sp)
    8000403a:	bf49                	j	80003fcc <itrunc+0x3c>

000000008000403c <iput>:
{
    8000403c:	1101                	addi	sp,sp,-32
    8000403e:	ec06                	sd	ra,24(sp)
    80004040:	e822                	sd	s0,16(sp)
    80004042:	e426                	sd	s1,8(sp)
    80004044:	1000                	addi	s0,sp,32
    80004046:	84aa                	mv	s1,a0
  acquire(&itable.lock);
    80004048:	00024517          	auipc	a0,0x24
    8000404c:	03050513          	addi	a0,a0,48 # 80028078 <itable>
    80004050:	ffffd097          	auipc	ra,0xffffd
    80004054:	be8080e7          	jalr	-1048(ra) # 80000c38 <acquire>
  if(ip->ref == 1 && ip->valid && ip->nlink == 0){
    80004058:	4498                	lw	a4,8(s1)
    8000405a:	4785                	li	a5,1
    8000405c:	02f70263          	beq	a4,a5,80004080 <iput+0x44>
  ip->ref--;
    80004060:	449c                	lw	a5,8(s1)
    80004062:	37fd                	addiw	a5,a5,-1
    80004064:	c49c                	sw	a5,8(s1)
  release(&itable.lock);
    80004066:	00024517          	auipc	a0,0x24
    8000406a:	01250513          	addi	a0,a0,18 # 80028078 <itable>
    8000406e:	ffffd097          	auipc	ra,0xffffd
    80004072:	c7e080e7          	jalr	-898(ra) # 80000cec <release>
}
    80004076:	60e2                	ld	ra,24(sp)
    80004078:	6442                	ld	s0,16(sp)
    8000407a:	64a2                	ld	s1,8(sp)
    8000407c:	6105                	addi	sp,sp,32
    8000407e:	8082                	ret
  if(ip->ref == 1 && ip->valid && ip->nlink == 0){
    80004080:	40bc                	lw	a5,64(s1)
    80004082:	dff9                	beqz	a5,80004060 <iput+0x24>
    80004084:	04a49783          	lh	a5,74(s1)
    80004088:	ffe1                	bnez	a5,80004060 <iput+0x24>
    8000408a:	e04a                	sd	s2,0(sp)
    acquiresleep(&ip->lock);
    8000408c:	01048913          	addi	s2,s1,16
    80004090:	854a                	mv	a0,s2
    80004092:	00001097          	auipc	ra,0x1
    80004096:	ab0080e7          	jalr	-1360(ra) # 80004b42 <acquiresleep>
    release(&itable.lock);
    8000409a:	00024517          	auipc	a0,0x24
    8000409e:	fde50513          	addi	a0,a0,-34 # 80028078 <itable>
    800040a2:	ffffd097          	auipc	ra,0xffffd
    800040a6:	c4a080e7          	jalr	-950(ra) # 80000cec <release>
    itrunc(ip);
    800040aa:	8526                	mv	a0,s1
    800040ac:	00000097          	auipc	ra,0x0
    800040b0:	ee4080e7          	jalr	-284(ra) # 80003f90 <itrunc>
    ip->type = 0;
    800040b4:	04049223          	sh	zero,68(s1)
    iupdate(ip);
    800040b8:	8526                	mv	a0,s1
    800040ba:	00000097          	auipc	ra,0x0
    800040be:	cf8080e7          	jalr	-776(ra) # 80003db2 <iupdate>
    ip->valid = 0;
    800040c2:	0404a023          	sw	zero,64(s1)
    releasesleep(&ip->lock);
    800040c6:	854a                	mv	a0,s2
    800040c8:	00001097          	auipc	ra,0x1
    800040cc:	ad2080e7          	jalr	-1326(ra) # 80004b9a <releasesleep>
    acquire(&itable.lock);
    800040d0:	00024517          	auipc	a0,0x24
    800040d4:	fa850513          	addi	a0,a0,-88 # 80028078 <itable>
    800040d8:	ffffd097          	auipc	ra,0xffffd
    800040dc:	b60080e7          	jalr	-1184(ra) # 80000c38 <acquire>
    800040e0:	6902                	ld	s2,0(sp)
    800040e2:	bfbd                	j	80004060 <iput+0x24>

00000000800040e4 <iunlockput>:
{
    800040e4:	1101                	addi	sp,sp,-32
    800040e6:	ec06                	sd	ra,24(sp)
    800040e8:	e822                	sd	s0,16(sp)
    800040ea:	e426                	sd	s1,8(sp)
    800040ec:	1000                	addi	s0,sp,32
    800040ee:	84aa                	mv	s1,a0
  iunlock(ip);
    800040f0:	00000097          	auipc	ra,0x0
    800040f4:	e54080e7          	jalr	-428(ra) # 80003f44 <iunlock>
  iput(ip);
    800040f8:	8526                	mv	a0,s1
    800040fa:	00000097          	auipc	ra,0x0
    800040fe:	f42080e7          	jalr	-190(ra) # 8000403c <iput>
}
    80004102:	60e2                	ld	ra,24(sp)
    80004104:	6442                	ld	s0,16(sp)
    80004106:	64a2                	ld	s1,8(sp)
    80004108:	6105                	addi	sp,sp,32
    8000410a:	8082                	ret

000000008000410c <stati>:

// Copy stat information from inode.
// Caller must hold ip->lock.
void
stati(struct inode *ip, struct stat *st)
{
    8000410c:	1141                	addi	sp,sp,-16
    8000410e:	e422                	sd	s0,8(sp)
    80004110:	0800                	addi	s0,sp,16
  st->dev = ip->dev;
    80004112:	411c                	lw	a5,0(a0)
    80004114:	c19c                	sw	a5,0(a1)
  st->ino = ip->inum;
    80004116:	415c                	lw	a5,4(a0)
    80004118:	c1dc                	sw	a5,4(a1)
  st->type = ip->type;
    8000411a:	04451783          	lh	a5,68(a0)
    8000411e:	00f59423          	sh	a5,8(a1)
  st->nlink = ip->nlink;
    80004122:	04a51783          	lh	a5,74(a0)
    80004126:	00f59523          	sh	a5,10(a1)
  st->size = ip->size;
    8000412a:	04c56783          	lwu	a5,76(a0)
    8000412e:	e99c                	sd	a5,16(a1)
}
    80004130:	6422                	ld	s0,8(sp)
    80004132:	0141                	addi	sp,sp,16
    80004134:	8082                	ret

0000000080004136 <readi>:
readi(struct inode *ip, int user_dst, uint64 dst, uint off, uint n)
{
  uint tot, m;
  struct buf *bp;

  if(off > ip->size || off + n < off)
    80004136:	457c                	lw	a5,76(a0)
    80004138:	10d7e563          	bltu	a5,a3,80004242 <readi+0x10c>
{
    8000413c:	7159                	addi	sp,sp,-112
    8000413e:	f486                	sd	ra,104(sp)
    80004140:	f0a2                	sd	s0,96(sp)
    80004142:	eca6                	sd	s1,88(sp)
    80004144:	e0d2                	sd	s4,64(sp)
    80004146:	fc56                	sd	s5,56(sp)
    80004148:	f85a                	sd	s6,48(sp)
    8000414a:	f45e                	sd	s7,40(sp)
    8000414c:	1880                	addi	s0,sp,112
    8000414e:	8b2a                	mv	s6,a0
    80004150:	8bae                	mv	s7,a1
    80004152:	8a32                	mv	s4,a2
    80004154:	84b6                	mv	s1,a3
    80004156:	8aba                	mv	s5,a4
  if(off > ip->size || off + n < off)
    80004158:	9f35                	addw	a4,a4,a3
    return 0;
    8000415a:	4501                	li	a0,0
  if(off > ip->size || off + n < off)
    8000415c:	0cd76a63          	bltu	a4,a3,80004230 <readi+0xfa>
    80004160:	e4ce                	sd	s3,72(sp)
  if(off + n > ip->size)
    80004162:	00e7f463          	bgeu	a5,a4,8000416a <readi+0x34>
    n = ip->size - off;
    80004166:	40d78abb          	subw	s5,a5,a3

  for(tot=0; tot<n; tot+=m, off+=m, dst+=m){
    8000416a:	0a0a8963          	beqz	s5,8000421c <readi+0xe6>
    8000416e:	e8ca                	sd	s2,80(sp)
    80004170:	f062                	sd	s8,32(sp)
    80004172:	ec66                	sd	s9,24(sp)
    80004174:	e86a                	sd	s10,16(sp)
    80004176:	e46e                	sd	s11,8(sp)
    80004178:	4981                	li	s3,0
    uint addr = bmap(ip, off/BSIZE);
    if(addr == 0)
      break;
    bp = bread(ip->dev, addr);
    m = min(n - tot, BSIZE - off%BSIZE);
    8000417a:	40000c93          	li	s9,1024
    if(either_copyout(user_dst, dst, bp->data + (off % BSIZE), m) == -1) {
    8000417e:	5c7d                	li	s8,-1
    80004180:	a82d                	j	800041ba <readi+0x84>
    80004182:	020d1d93          	slli	s11,s10,0x20
    80004186:	020ddd93          	srli	s11,s11,0x20
    8000418a:	05890613          	addi	a2,s2,88
    8000418e:	86ee                	mv	a3,s11
    80004190:	963a                	add	a2,a2,a4
    80004192:	85d2                	mv	a1,s4
    80004194:	855e                	mv	a0,s7
    80004196:	ffffe097          	auipc	ra,0xffffe
    8000419a:	688080e7          	jalr	1672(ra) # 8000281e <either_copyout>
    8000419e:	05850d63          	beq	a0,s8,800041f8 <readi+0xc2>
      brelse(bp);
      tot = -1;
      break;
    }
    brelse(bp);
    800041a2:	854a                	mv	a0,s2
    800041a4:	fffff097          	auipc	ra,0xfffff
    800041a8:	5d6080e7          	jalr	1494(ra) # 8000377a <brelse>
  for(tot=0; tot<n; tot+=m, off+=m, dst+=m){
    800041ac:	013d09bb          	addw	s3,s10,s3
    800041b0:	009d04bb          	addw	s1,s10,s1
    800041b4:	9a6e                	add	s4,s4,s11
    800041b6:	0559fd63          	bgeu	s3,s5,80004210 <readi+0xda>
    uint addr = bmap(ip, off/BSIZE);
    800041ba:	00a4d59b          	srliw	a1,s1,0xa
    800041be:	855a                	mv	a0,s6
    800041c0:	00000097          	auipc	ra,0x0
    800041c4:	88e080e7          	jalr	-1906(ra) # 80003a4e <bmap>
    800041c8:	0005059b          	sext.w	a1,a0
    if(addr == 0)
    800041cc:	c9b1                	beqz	a1,80004220 <readi+0xea>
    bp = bread(ip->dev, addr);
    800041ce:	000b2503          	lw	a0,0(s6)
    800041d2:	fffff097          	auipc	ra,0xfffff
    800041d6:	478080e7          	jalr	1144(ra) # 8000364a <bread>
    800041da:	892a                	mv	s2,a0
    m = min(n - tot, BSIZE - off%BSIZE);
    800041dc:	3ff4f713          	andi	a4,s1,1023
    800041e0:	40ec87bb          	subw	a5,s9,a4
    800041e4:	413a86bb          	subw	a3,s5,s3
    800041e8:	8d3e                	mv	s10,a5
    800041ea:	2781                	sext.w	a5,a5
    800041ec:	0006861b          	sext.w	a2,a3
    800041f0:	f8f679e3          	bgeu	a2,a5,80004182 <readi+0x4c>
    800041f4:	8d36                	mv	s10,a3
    800041f6:	b771                	j	80004182 <readi+0x4c>
      brelse(bp);
    800041f8:	854a                	mv	a0,s2
    800041fa:	fffff097          	auipc	ra,0xfffff
    800041fe:	580080e7          	jalr	1408(ra) # 8000377a <brelse>
      tot = -1;
    80004202:	59fd                	li	s3,-1
      break;
    80004204:	6946                	ld	s2,80(sp)
    80004206:	7c02                	ld	s8,32(sp)
    80004208:	6ce2                	ld	s9,24(sp)
    8000420a:	6d42                	ld	s10,16(sp)
    8000420c:	6da2                	ld	s11,8(sp)
    8000420e:	a831                	j	8000422a <readi+0xf4>
    80004210:	6946                	ld	s2,80(sp)
    80004212:	7c02                	ld	s8,32(sp)
    80004214:	6ce2                	ld	s9,24(sp)
    80004216:	6d42                	ld	s10,16(sp)
    80004218:	6da2                	ld	s11,8(sp)
    8000421a:	a801                	j	8000422a <readi+0xf4>
  for(tot=0; tot<n; tot+=m, off+=m, dst+=m){
    8000421c:	89d6                	mv	s3,s5
    8000421e:	a031                	j	8000422a <readi+0xf4>
    80004220:	6946                	ld	s2,80(sp)
    80004222:	7c02                	ld	s8,32(sp)
    80004224:	6ce2                	ld	s9,24(sp)
    80004226:	6d42                	ld	s10,16(sp)
    80004228:	6da2                	ld	s11,8(sp)
  }
  return tot;
    8000422a:	0009851b          	sext.w	a0,s3
    8000422e:	69a6                	ld	s3,72(sp)
}
    80004230:	70a6                	ld	ra,104(sp)
    80004232:	7406                	ld	s0,96(sp)
    80004234:	64e6                	ld	s1,88(sp)
    80004236:	6a06                	ld	s4,64(sp)
    80004238:	7ae2                	ld	s5,56(sp)
    8000423a:	7b42                	ld	s6,48(sp)
    8000423c:	7ba2                	ld	s7,40(sp)
    8000423e:	6165                	addi	sp,sp,112
    80004240:	8082                	ret
    return 0;
    80004242:	4501                	li	a0,0
}
    80004244:	8082                	ret

0000000080004246 <writei>:
writei(struct inode *ip, int user_src, uint64 src, uint off, uint n)
{
  uint tot, m;
  struct buf *bp;

  if(off > ip->size || off + n < off)
    80004246:	457c                	lw	a5,76(a0)
    80004248:	10d7ee63          	bltu	a5,a3,80004364 <writei+0x11e>
{
    8000424c:	7159                	addi	sp,sp,-112
    8000424e:	f486                	sd	ra,104(sp)
    80004250:	f0a2                	sd	s0,96(sp)
    80004252:	e8ca                	sd	s2,80(sp)
    80004254:	e0d2                	sd	s4,64(sp)
    80004256:	fc56                	sd	s5,56(sp)
    80004258:	f85a                	sd	s6,48(sp)
    8000425a:	f45e                	sd	s7,40(sp)
    8000425c:	1880                	addi	s0,sp,112
    8000425e:	8aaa                	mv	s5,a0
    80004260:	8bae                	mv	s7,a1
    80004262:	8a32                	mv	s4,a2
    80004264:	8936                	mv	s2,a3
    80004266:	8b3a                	mv	s6,a4
  if(off > ip->size || off + n < off)
    80004268:	00e687bb          	addw	a5,a3,a4
    8000426c:	0ed7ee63          	bltu	a5,a3,80004368 <writei+0x122>
    return -1;
  if(off + n > MAXFILE*BSIZE)
    80004270:	00043737          	lui	a4,0x43
    80004274:	0ef76c63          	bltu	a4,a5,8000436c <writei+0x126>
    80004278:	e4ce                	sd	s3,72(sp)
    return -1;

  for(tot=0; tot<n; tot+=m, off+=m, src+=m){
    8000427a:	0c0b0d63          	beqz	s6,80004354 <writei+0x10e>
    8000427e:	eca6                	sd	s1,88(sp)
    80004280:	f062                	sd	s8,32(sp)
    80004282:	ec66                	sd	s9,24(sp)
    80004284:	e86a                	sd	s10,16(sp)
    80004286:	e46e                	sd	s11,8(sp)
    80004288:	4981                	li	s3,0
    uint addr = bmap(ip, off/BSIZE);
    if(addr == 0)
      break;
    bp = bread(ip->dev, addr);
    m = min(n - tot, BSIZE - off%BSIZE);
    8000428a:	40000c93          	li	s9,1024
    if(either_copyin(bp->data + (off % BSIZE), user_src, src, m) == -1) {
    8000428e:	5c7d                	li	s8,-1
    80004290:	a091                	j	800042d4 <writei+0x8e>
    80004292:	020d1d93          	slli	s11,s10,0x20
    80004296:	020ddd93          	srli	s11,s11,0x20
    8000429a:	05848513          	addi	a0,s1,88
    8000429e:	86ee                	mv	a3,s11
    800042a0:	8652                	mv	a2,s4
    800042a2:	85de                	mv	a1,s7
    800042a4:	953a                	add	a0,a0,a4
    800042a6:	ffffe097          	auipc	ra,0xffffe
    800042aa:	5d0080e7          	jalr	1488(ra) # 80002876 <either_copyin>
    800042ae:	07850263          	beq	a0,s8,80004312 <writei+0xcc>
      brelse(bp);
      break;
    }
    log_write(bp);
    800042b2:	8526                	mv	a0,s1
    800042b4:	00000097          	auipc	ra,0x0
    800042b8:	770080e7          	jalr	1904(ra) # 80004a24 <log_write>
    brelse(bp);
    800042bc:	8526                	mv	a0,s1
    800042be:	fffff097          	auipc	ra,0xfffff
    800042c2:	4bc080e7          	jalr	1212(ra) # 8000377a <brelse>
  for(tot=0; tot<n; tot+=m, off+=m, src+=m){
    800042c6:	013d09bb          	addw	s3,s10,s3
    800042ca:	012d093b          	addw	s2,s10,s2
    800042ce:	9a6e                	add	s4,s4,s11
    800042d0:	0569f663          	bgeu	s3,s6,8000431c <writei+0xd6>
    uint addr = bmap(ip, off/BSIZE);
    800042d4:	00a9559b          	srliw	a1,s2,0xa
    800042d8:	8556                	mv	a0,s5
    800042da:	fffff097          	auipc	ra,0xfffff
    800042de:	774080e7          	jalr	1908(ra) # 80003a4e <bmap>
    800042e2:	0005059b          	sext.w	a1,a0
    if(addr == 0)
    800042e6:	c99d                	beqz	a1,8000431c <writei+0xd6>
    bp = bread(ip->dev, addr);
    800042e8:	000aa503          	lw	a0,0(s5)
    800042ec:	fffff097          	auipc	ra,0xfffff
    800042f0:	35e080e7          	jalr	862(ra) # 8000364a <bread>
    800042f4:	84aa                	mv	s1,a0
    m = min(n - tot, BSIZE - off%BSIZE);
    800042f6:	3ff97713          	andi	a4,s2,1023
    800042fa:	40ec87bb          	subw	a5,s9,a4
    800042fe:	413b06bb          	subw	a3,s6,s3
    80004302:	8d3e                	mv	s10,a5
    80004304:	2781                	sext.w	a5,a5
    80004306:	0006861b          	sext.w	a2,a3
    8000430a:	f8f674e3          	bgeu	a2,a5,80004292 <writei+0x4c>
    8000430e:	8d36                	mv	s10,a3
    80004310:	b749                	j	80004292 <writei+0x4c>
      brelse(bp);
    80004312:	8526                	mv	a0,s1
    80004314:	fffff097          	auipc	ra,0xfffff
    80004318:	466080e7          	jalr	1126(ra) # 8000377a <brelse>
  }

  if(off > ip->size)
    8000431c:	04caa783          	lw	a5,76(s5)
    80004320:	0327fc63          	bgeu	a5,s2,80004358 <writei+0x112>
    ip->size = off;
    80004324:	052aa623          	sw	s2,76(s5)
    80004328:	64e6                	ld	s1,88(sp)
    8000432a:	7c02                	ld	s8,32(sp)
    8000432c:	6ce2                	ld	s9,24(sp)
    8000432e:	6d42                	ld	s10,16(sp)
    80004330:	6da2                	ld	s11,8(sp)

  // write the i-node back to disk even if the size didn't change
  // because the loop above might have called bmap() and added a new
  // block to ip->addrs[].
  iupdate(ip);
    80004332:	8556                	mv	a0,s5
    80004334:	00000097          	auipc	ra,0x0
    80004338:	a7e080e7          	jalr	-1410(ra) # 80003db2 <iupdate>

  return tot;
    8000433c:	0009851b          	sext.w	a0,s3
    80004340:	69a6                	ld	s3,72(sp)
}
    80004342:	70a6                	ld	ra,104(sp)
    80004344:	7406                	ld	s0,96(sp)
    80004346:	6946                	ld	s2,80(sp)
    80004348:	6a06                	ld	s4,64(sp)
    8000434a:	7ae2                	ld	s5,56(sp)
    8000434c:	7b42                	ld	s6,48(sp)
    8000434e:	7ba2                	ld	s7,40(sp)
    80004350:	6165                	addi	sp,sp,112
    80004352:	8082                	ret
  for(tot=0; tot<n; tot+=m, off+=m, src+=m){
    80004354:	89da                	mv	s3,s6
    80004356:	bff1                	j	80004332 <writei+0xec>
    80004358:	64e6                	ld	s1,88(sp)
    8000435a:	7c02                	ld	s8,32(sp)
    8000435c:	6ce2                	ld	s9,24(sp)
    8000435e:	6d42                	ld	s10,16(sp)
    80004360:	6da2                	ld	s11,8(sp)
    80004362:	bfc1                	j	80004332 <writei+0xec>
    return -1;
    80004364:	557d                	li	a0,-1
}
    80004366:	8082                	ret
    return -1;
    80004368:	557d                	li	a0,-1
    8000436a:	bfe1                	j	80004342 <writei+0xfc>
    return -1;
    8000436c:	557d                	li	a0,-1
    8000436e:	bfd1                	j	80004342 <writei+0xfc>

0000000080004370 <namecmp>:

// Directories

int
namecmp(const char *s, const char *t)
{
    80004370:	1141                	addi	sp,sp,-16
    80004372:	e406                	sd	ra,8(sp)
    80004374:	e022                	sd	s0,0(sp)
    80004376:	0800                	addi	s0,sp,16
  return strncmp(s, t, DIRSIZ);
    80004378:	4639                	li	a2,14
    8000437a:	ffffd097          	auipc	ra,0xffffd
    8000437e:	a8a080e7          	jalr	-1398(ra) # 80000e04 <strncmp>
}
    80004382:	60a2                	ld	ra,8(sp)
    80004384:	6402                	ld	s0,0(sp)
    80004386:	0141                	addi	sp,sp,16
    80004388:	8082                	ret

000000008000438a <dirlookup>:

// Look for a directory entry in a directory.
// If found, set *poff to byte offset of entry.
struct inode*
dirlookup(struct inode *dp, char *name, uint *poff)
{
    8000438a:	7139                	addi	sp,sp,-64
    8000438c:	fc06                	sd	ra,56(sp)
    8000438e:	f822                	sd	s0,48(sp)
    80004390:	f426                	sd	s1,40(sp)
    80004392:	f04a                	sd	s2,32(sp)
    80004394:	ec4e                	sd	s3,24(sp)
    80004396:	e852                	sd	s4,16(sp)
    80004398:	0080                	addi	s0,sp,64
  uint off, inum;
  struct dirent de;

  if(dp->type != T_DIR)
    8000439a:	04451703          	lh	a4,68(a0)
    8000439e:	4785                	li	a5,1
    800043a0:	00f71a63          	bne	a4,a5,800043b4 <dirlookup+0x2a>
    800043a4:	892a                	mv	s2,a0
    800043a6:	89ae                	mv	s3,a1
    800043a8:	8a32                	mv	s4,a2
    panic("dirlookup not DIR");

  for(off = 0; off < dp->size; off += sizeof(de)){
    800043aa:	457c                	lw	a5,76(a0)
    800043ac:	4481                	li	s1,0
      inum = de.inum;
      return iget(dp->dev, inum);
    }
  }

  return 0;
    800043ae:	4501                	li	a0,0
  for(off = 0; off < dp->size; off += sizeof(de)){
    800043b0:	e79d                	bnez	a5,800043de <dirlookup+0x54>
    800043b2:	a8a5                	j	8000442a <dirlookup+0xa0>
    panic("dirlookup not DIR");
    800043b4:	00004517          	auipc	a0,0x4
    800043b8:	12450513          	addi	a0,a0,292 # 800084d8 <etext+0x4d8>
    800043bc:	ffffc097          	auipc	ra,0xffffc
    800043c0:	1a4080e7          	jalr	420(ra) # 80000560 <panic>
      panic("dirlookup read");
    800043c4:	00004517          	auipc	a0,0x4
    800043c8:	12c50513          	addi	a0,a0,300 # 800084f0 <etext+0x4f0>
    800043cc:	ffffc097          	auipc	ra,0xffffc
    800043d0:	194080e7          	jalr	404(ra) # 80000560 <panic>
  for(off = 0; off < dp->size; off += sizeof(de)){
    800043d4:	24c1                	addiw	s1,s1,16
    800043d6:	04c92783          	lw	a5,76(s2)
    800043da:	04f4f763          	bgeu	s1,a5,80004428 <dirlookup+0x9e>
    if(readi(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    800043de:	4741                	li	a4,16
    800043e0:	86a6                	mv	a3,s1
    800043e2:	fc040613          	addi	a2,s0,-64
    800043e6:	4581                	li	a1,0
    800043e8:	854a                	mv	a0,s2
    800043ea:	00000097          	auipc	ra,0x0
    800043ee:	d4c080e7          	jalr	-692(ra) # 80004136 <readi>
    800043f2:	47c1                	li	a5,16
    800043f4:	fcf518e3          	bne	a0,a5,800043c4 <dirlookup+0x3a>
    if(de.inum == 0)
    800043f8:	fc045783          	lhu	a5,-64(s0)
    800043fc:	dfe1                	beqz	a5,800043d4 <dirlookup+0x4a>
    if(namecmp(name, de.name) == 0){
    800043fe:	fc240593          	addi	a1,s0,-62
    80004402:	854e                	mv	a0,s3
    80004404:	00000097          	auipc	ra,0x0
    80004408:	f6c080e7          	jalr	-148(ra) # 80004370 <namecmp>
    8000440c:	f561                	bnez	a0,800043d4 <dirlookup+0x4a>
      if(poff)
    8000440e:	000a0463          	beqz	s4,80004416 <dirlookup+0x8c>
        *poff = off;
    80004412:	009a2023          	sw	s1,0(s4)
      return iget(dp->dev, inum);
    80004416:	fc045583          	lhu	a1,-64(s0)
    8000441a:	00092503          	lw	a0,0(s2)
    8000441e:	fffff097          	auipc	ra,0xfffff
    80004422:	720080e7          	jalr	1824(ra) # 80003b3e <iget>
    80004426:	a011                	j	8000442a <dirlookup+0xa0>
  return 0;
    80004428:	4501                	li	a0,0
}
    8000442a:	70e2                	ld	ra,56(sp)
    8000442c:	7442                	ld	s0,48(sp)
    8000442e:	74a2                	ld	s1,40(sp)
    80004430:	7902                	ld	s2,32(sp)
    80004432:	69e2                	ld	s3,24(sp)
    80004434:	6a42                	ld	s4,16(sp)
    80004436:	6121                	addi	sp,sp,64
    80004438:	8082                	ret

000000008000443a <namex>:
// If parent != 0, return the inode for the parent and copy the final
// path element into name, which must have room for DIRSIZ bytes.
// Must be called inside a transaction since it calls iput().
static struct inode*
namex(char *path, int nameiparent, char *name)
{
    8000443a:	711d                	addi	sp,sp,-96
    8000443c:	ec86                	sd	ra,88(sp)
    8000443e:	e8a2                	sd	s0,80(sp)
    80004440:	e4a6                	sd	s1,72(sp)
    80004442:	e0ca                	sd	s2,64(sp)
    80004444:	fc4e                	sd	s3,56(sp)
    80004446:	f852                	sd	s4,48(sp)
    80004448:	f456                	sd	s5,40(sp)
    8000444a:	f05a                	sd	s6,32(sp)
    8000444c:	ec5e                	sd	s7,24(sp)
    8000444e:	e862                	sd	s8,16(sp)
    80004450:	e466                	sd	s9,8(sp)
    80004452:	1080                	addi	s0,sp,96
    80004454:	84aa                	mv	s1,a0
    80004456:	8b2e                	mv	s6,a1
    80004458:	8ab2                	mv	s5,a2
  struct inode *ip, *next;

  if(*path == '/')
    8000445a:	00054703          	lbu	a4,0(a0)
    8000445e:	02f00793          	li	a5,47
    80004462:	02f70263          	beq	a4,a5,80004486 <namex+0x4c>
    ip = iget(ROOTDEV, ROOTINO);
  else
    ip = idup(myproc()->cwd);
    80004466:	ffffd097          	auipc	ra,0xffffd
    8000446a:	7ce080e7          	jalr	1998(ra) # 80001c34 <myproc>
    8000446e:	27053503          	ld	a0,624(a0)
    80004472:	00000097          	auipc	ra,0x0
    80004476:	9ce080e7          	jalr	-1586(ra) # 80003e40 <idup>
    8000447a:	8a2a                	mv	s4,a0
  while(*path == '/')
    8000447c:	02f00913          	li	s2,47
  if(len >= DIRSIZ)
    80004480:	4c35                	li	s8,13

  while((path = skipelem(path, name)) != 0){
    ilock(ip);
    if(ip->type != T_DIR){
    80004482:	4b85                	li	s7,1
    80004484:	a875                	j	80004540 <namex+0x106>
    ip = iget(ROOTDEV, ROOTINO);
    80004486:	4585                	li	a1,1
    80004488:	4505                	li	a0,1
    8000448a:	fffff097          	auipc	ra,0xfffff
    8000448e:	6b4080e7          	jalr	1716(ra) # 80003b3e <iget>
    80004492:	8a2a                	mv	s4,a0
    80004494:	b7e5                	j	8000447c <namex+0x42>
      iunlockput(ip);
    80004496:	8552                	mv	a0,s4
    80004498:	00000097          	auipc	ra,0x0
    8000449c:	c4c080e7          	jalr	-948(ra) # 800040e4 <iunlockput>
      return 0;
    800044a0:	4a01                	li	s4,0
  if(nameiparent){
    iput(ip);
    return 0;
  }
  return ip;
}
    800044a2:	8552                	mv	a0,s4
    800044a4:	60e6                	ld	ra,88(sp)
    800044a6:	6446                	ld	s0,80(sp)
    800044a8:	64a6                	ld	s1,72(sp)
    800044aa:	6906                	ld	s2,64(sp)
    800044ac:	79e2                	ld	s3,56(sp)
    800044ae:	7a42                	ld	s4,48(sp)
    800044b0:	7aa2                	ld	s5,40(sp)
    800044b2:	7b02                	ld	s6,32(sp)
    800044b4:	6be2                	ld	s7,24(sp)
    800044b6:	6c42                	ld	s8,16(sp)
    800044b8:	6ca2                	ld	s9,8(sp)
    800044ba:	6125                	addi	sp,sp,96
    800044bc:	8082                	ret
      iunlock(ip);
    800044be:	8552                	mv	a0,s4
    800044c0:	00000097          	auipc	ra,0x0
    800044c4:	a84080e7          	jalr	-1404(ra) # 80003f44 <iunlock>
      return ip;
    800044c8:	bfe9                	j	800044a2 <namex+0x68>
      iunlockput(ip);
    800044ca:	8552                	mv	a0,s4
    800044cc:	00000097          	auipc	ra,0x0
    800044d0:	c18080e7          	jalr	-1000(ra) # 800040e4 <iunlockput>
      return 0;
    800044d4:	8a4e                	mv	s4,s3
    800044d6:	b7f1                	j	800044a2 <namex+0x68>
  len = path - s;
    800044d8:	40998633          	sub	a2,s3,s1
    800044dc:	00060c9b          	sext.w	s9,a2
  if(len >= DIRSIZ)
    800044e0:	099c5863          	bge	s8,s9,80004570 <namex+0x136>
    memmove(name, s, DIRSIZ);
    800044e4:	4639                	li	a2,14
    800044e6:	85a6                	mv	a1,s1
    800044e8:	8556                	mv	a0,s5
    800044ea:	ffffd097          	auipc	ra,0xffffd
    800044ee:	8a6080e7          	jalr	-1882(ra) # 80000d90 <memmove>
    800044f2:	84ce                	mv	s1,s3
  while(*path == '/')
    800044f4:	0004c783          	lbu	a5,0(s1)
    800044f8:	01279763          	bne	a5,s2,80004506 <namex+0xcc>
    path++;
    800044fc:	0485                	addi	s1,s1,1
  while(*path == '/')
    800044fe:	0004c783          	lbu	a5,0(s1)
    80004502:	ff278de3          	beq	a5,s2,800044fc <namex+0xc2>
    ilock(ip);
    80004506:	8552                	mv	a0,s4
    80004508:	00000097          	auipc	ra,0x0
    8000450c:	976080e7          	jalr	-1674(ra) # 80003e7e <ilock>
    if(ip->type != T_DIR){
    80004510:	044a1783          	lh	a5,68(s4)
    80004514:	f97791e3          	bne	a5,s7,80004496 <namex+0x5c>
    if(nameiparent && *path == '\0'){
    80004518:	000b0563          	beqz	s6,80004522 <namex+0xe8>
    8000451c:	0004c783          	lbu	a5,0(s1)
    80004520:	dfd9                	beqz	a5,800044be <namex+0x84>
    if((next = dirlookup(ip, name, 0)) == 0){
    80004522:	4601                	li	a2,0
    80004524:	85d6                	mv	a1,s5
    80004526:	8552                	mv	a0,s4
    80004528:	00000097          	auipc	ra,0x0
    8000452c:	e62080e7          	jalr	-414(ra) # 8000438a <dirlookup>
    80004530:	89aa                	mv	s3,a0
    80004532:	dd41                	beqz	a0,800044ca <namex+0x90>
    iunlockput(ip);
    80004534:	8552                	mv	a0,s4
    80004536:	00000097          	auipc	ra,0x0
    8000453a:	bae080e7          	jalr	-1106(ra) # 800040e4 <iunlockput>
    ip = next;
    8000453e:	8a4e                	mv	s4,s3
  while(*path == '/')
    80004540:	0004c783          	lbu	a5,0(s1)
    80004544:	01279763          	bne	a5,s2,80004552 <namex+0x118>
    path++;
    80004548:	0485                	addi	s1,s1,1
  while(*path == '/')
    8000454a:	0004c783          	lbu	a5,0(s1)
    8000454e:	ff278de3          	beq	a5,s2,80004548 <namex+0x10e>
  if(*path == 0)
    80004552:	cb9d                	beqz	a5,80004588 <namex+0x14e>
  while(*path != '/' && *path != 0)
    80004554:	0004c783          	lbu	a5,0(s1)
    80004558:	89a6                	mv	s3,s1
  len = path - s;
    8000455a:	4c81                	li	s9,0
    8000455c:	4601                	li	a2,0
  while(*path != '/' && *path != 0)
    8000455e:	01278963          	beq	a5,s2,80004570 <namex+0x136>
    80004562:	dbbd                	beqz	a5,800044d8 <namex+0x9e>
    path++;
    80004564:	0985                	addi	s3,s3,1
  while(*path != '/' && *path != 0)
    80004566:	0009c783          	lbu	a5,0(s3)
    8000456a:	ff279ce3          	bne	a5,s2,80004562 <namex+0x128>
    8000456e:	b7ad                	j	800044d8 <namex+0x9e>
    memmove(name, s, len);
    80004570:	2601                	sext.w	a2,a2
    80004572:	85a6                	mv	a1,s1
    80004574:	8556                	mv	a0,s5
    80004576:	ffffd097          	auipc	ra,0xffffd
    8000457a:	81a080e7          	jalr	-2022(ra) # 80000d90 <memmove>
    name[len] = 0;
    8000457e:	9cd6                	add	s9,s9,s5
    80004580:	000c8023          	sb	zero,0(s9) # 2000 <_entry-0x7fffe000>
    80004584:	84ce                	mv	s1,s3
    80004586:	b7bd                	j	800044f4 <namex+0xba>
  if(nameiparent){
    80004588:	f00b0de3          	beqz	s6,800044a2 <namex+0x68>
    iput(ip);
    8000458c:	8552                	mv	a0,s4
    8000458e:	00000097          	auipc	ra,0x0
    80004592:	aae080e7          	jalr	-1362(ra) # 8000403c <iput>
    return 0;
    80004596:	4a01                	li	s4,0
    80004598:	b729                	j	800044a2 <namex+0x68>

000000008000459a <dirlink>:
{
    8000459a:	7139                	addi	sp,sp,-64
    8000459c:	fc06                	sd	ra,56(sp)
    8000459e:	f822                	sd	s0,48(sp)
    800045a0:	f04a                	sd	s2,32(sp)
    800045a2:	ec4e                	sd	s3,24(sp)
    800045a4:	e852                	sd	s4,16(sp)
    800045a6:	0080                	addi	s0,sp,64
    800045a8:	892a                	mv	s2,a0
    800045aa:	8a2e                	mv	s4,a1
    800045ac:	89b2                	mv	s3,a2
  if((ip = dirlookup(dp, name, 0)) != 0){
    800045ae:	4601                	li	a2,0
    800045b0:	00000097          	auipc	ra,0x0
    800045b4:	dda080e7          	jalr	-550(ra) # 8000438a <dirlookup>
    800045b8:	ed25                	bnez	a0,80004630 <dirlink+0x96>
    800045ba:	f426                	sd	s1,40(sp)
  for(off = 0; off < dp->size; off += sizeof(de)){
    800045bc:	04c92483          	lw	s1,76(s2)
    800045c0:	c49d                	beqz	s1,800045ee <dirlink+0x54>
    800045c2:	4481                	li	s1,0
    if(readi(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    800045c4:	4741                	li	a4,16
    800045c6:	86a6                	mv	a3,s1
    800045c8:	fc040613          	addi	a2,s0,-64
    800045cc:	4581                	li	a1,0
    800045ce:	854a                	mv	a0,s2
    800045d0:	00000097          	auipc	ra,0x0
    800045d4:	b66080e7          	jalr	-1178(ra) # 80004136 <readi>
    800045d8:	47c1                	li	a5,16
    800045da:	06f51163          	bne	a0,a5,8000463c <dirlink+0xa2>
    if(de.inum == 0)
    800045de:	fc045783          	lhu	a5,-64(s0)
    800045e2:	c791                	beqz	a5,800045ee <dirlink+0x54>
  for(off = 0; off < dp->size; off += sizeof(de)){
    800045e4:	24c1                	addiw	s1,s1,16
    800045e6:	04c92783          	lw	a5,76(s2)
    800045ea:	fcf4ede3          	bltu	s1,a5,800045c4 <dirlink+0x2a>
  strncpy(de.name, name, DIRSIZ);
    800045ee:	4639                	li	a2,14
    800045f0:	85d2                	mv	a1,s4
    800045f2:	fc240513          	addi	a0,s0,-62
    800045f6:	ffffd097          	auipc	ra,0xffffd
    800045fa:	844080e7          	jalr	-1980(ra) # 80000e3a <strncpy>
  de.inum = inum;
    800045fe:	fd341023          	sh	s3,-64(s0)
  if(writei(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    80004602:	4741                	li	a4,16
    80004604:	86a6                	mv	a3,s1
    80004606:	fc040613          	addi	a2,s0,-64
    8000460a:	4581                	li	a1,0
    8000460c:	854a                	mv	a0,s2
    8000460e:	00000097          	auipc	ra,0x0
    80004612:	c38080e7          	jalr	-968(ra) # 80004246 <writei>
    80004616:	1541                	addi	a0,a0,-16
    80004618:	00a03533          	snez	a0,a0
    8000461c:	40a00533          	neg	a0,a0
    80004620:	74a2                	ld	s1,40(sp)
}
    80004622:	70e2                	ld	ra,56(sp)
    80004624:	7442                	ld	s0,48(sp)
    80004626:	7902                	ld	s2,32(sp)
    80004628:	69e2                	ld	s3,24(sp)
    8000462a:	6a42                	ld	s4,16(sp)
    8000462c:	6121                	addi	sp,sp,64
    8000462e:	8082                	ret
    iput(ip);
    80004630:	00000097          	auipc	ra,0x0
    80004634:	a0c080e7          	jalr	-1524(ra) # 8000403c <iput>
    return -1;
    80004638:	557d                	li	a0,-1
    8000463a:	b7e5                	j	80004622 <dirlink+0x88>
      panic("dirlink read");
    8000463c:	00004517          	auipc	a0,0x4
    80004640:	ec450513          	addi	a0,a0,-316 # 80008500 <etext+0x500>
    80004644:	ffffc097          	auipc	ra,0xffffc
    80004648:	f1c080e7          	jalr	-228(ra) # 80000560 <panic>

000000008000464c <namei>:

struct inode*
namei(char *path)
{
    8000464c:	1101                	addi	sp,sp,-32
    8000464e:	ec06                	sd	ra,24(sp)
    80004650:	e822                	sd	s0,16(sp)
    80004652:	1000                	addi	s0,sp,32
  char name[DIRSIZ];
  return namex(path, 0, name);
    80004654:	fe040613          	addi	a2,s0,-32
    80004658:	4581                	li	a1,0
    8000465a:	00000097          	auipc	ra,0x0
    8000465e:	de0080e7          	jalr	-544(ra) # 8000443a <namex>
}
    80004662:	60e2                	ld	ra,24(sp)
    80004664:	6442                	ld	s0,16(sp)
    80004666:	6105                	addi	sp,sp,32
    80004668:	8082                	ret

000000008000466a <nameiparent>:

struct inode*
nameiparent(char *path, char *name)
{
    8000466a:	1141                	addi	sp,sp,-16
    8000466c:	e406                	sd	ra,8(sp)
    8000466e:	e022                	sd	s0,0(sp)
    80004670:	0800                	addi	s0,sp,16
    80004672:	862e                	mv	a2,a1
  return namex(path, 1, name);
    80004674:	4585                	li	a1,1
    80004676:	00000097          	auipc	ra,0x0
    8000467a:	dc4080e7          	jalr	-572(ra) # 8000443a <namex>
}
    8000467e:	60a2                	ld	ra,8(sp)
    80004680:	6402                	ld	s0,0(sp)
    80004682:	0141                	addi	sp,sp,16
    80004684:	8082                	ret

0000000080004686 <write_head>:
// Write in-memory log header to disk.
// This is the true point at which the
// current transaction commits.
static void
write_head(void)
{
    80004686:	1101                	addi	sp,sp,-32
    80004688:	ec06                	sd	ra,24(sp)
    8000468a:	e822                	sd	s0,16(sp)
    8000468c:	e426                	sd	s1,8(sp)
    8000468e:	e04a                	sd	s2,0(sp)
    80004690:	1000                	addi	s0,sp,32
  struct buf *buf = bread(log.dev, log.start);
    80004692:	00025917          	auipc	s2,0x25
    80004696:	48e90913          	addi	s2,s2,1166 # 80029b20 <log>
    8000469a:	01892583          	lw	a1,24(s2)
    8000469e:	02892503          	lw	a0,40(s2)
    800046a2:	fffff097          	auipc	ra,0xfffff
    800046a6:	fa8080e7          	jalr	-88(ra) # 8000364a <bread>
    800046aa:	84aa                	mv	s1,a0
  struct logheader *hb = (struct logheader *) (buf->data);
  int i;
  hb->n = log.lh.n;
    800046ac:	02c92603          	lw	a2,44(s2)
    800046b0:	cd30                	sw	a2,88(a0)
  for (i = 0; i < log.lh.n; i++) {
    800046b2:	00c05f63          	blez	a2,800046d0 <write_head+0x4a>
    800046b6:	00025717          	auipc	a4,0x25
    800046ba:	49a70713          	addi	a4,a4,1178 # 80029b50 <log+0x30>
    800046be:	87aa                	mv	a5,a0
    800046c0:	060a                	slli	a2,a2,0x2
    800046c2:	962a                	add	a2,a2,a0
    hb->block[i] = log.lh.block[i];
    800046c4:	4314                	lw	a3,0(a4)
    800046c6:	cff4                	sw	a3,92(a5)
  for (i = 0; i < log.lh.n; i++) {
    800046c8:	0711                	addi	a4,a4,4
    800046ca:	0791                	addi	a5,a5,4
    800046cc:	fec79ce3          	bne	a5,a2,800046c4 <write_head+0x3e>
  }
  bwrite(buf);
    800046d0:	8526                	mv	a0,s1
    800046d2:	fffff097          	auipc	ra,0xfffff
    800046d6:	06a080e7          	jalr	106(ra) # 8000373c <bwrite>
  brelse(buf);
    800046da:	8526                	mv	a0,s1
    800046dc:	fffff097          	auipc	ra,0xfffff
    800046e0:	09e080e7          	jalr	158(ra) # 8000377a <brelse>
}
    800046e4:	60e2                	ld	ra,24(sp)
    800046e6:	6442                	ld	s0,16(sp)
    800046e8:	64a2                	ld	s1,8(sp)
    800046ea:	6902                	ld	s2,0(sp)
    800046ec:	6105                	addi	sp,sp,32
    800046ee:	8082                	ret

00000000800046f0 <install_trans>:
  for (tail = 0; tail < log.lh.n; tail++) {
    800046f0:	00025797          	auipc	a5,0x25
    800046f4:	45c7a783          	lw	a5,1116(a5) # 80029b4c <log+0x2c>
    800046f8:	0af05d63          	blez	a5,800047b2 <install_trans+0xc2>
{
    800046fc:	7139                	addi	sp,sp,-64
    800046fe:	fc06                	sd	ra,56(sp)
    80004700:	f822                	sd	s0,48(sp)
    80004702:	f426                	sd	s1,40(sp)
    80004704:	f04a                	sd	s2,32(sp)
    80004706:	ec4e                	sd	s3,24(sp)
    80004708:	e852                	sd	s4,16(sp)
    8000470a:	e456                	sd	s5,8(sp)
    8000470c:	e05a                	sd	s6,0(sp)
    8000470e:	0080                	addi	s0,sp,64
    80004710:	8b2a                	mv	s6,a0
    80004712:	00025a97          	auipc	s5,0x25
    80004716:	43ea8a93          	addi	s5,s5,1086 # 80029b50 <log+0x30>
  for (tail = 0; tail < log.lh.n; tail++) {
    8000471a:	4a01                	li	s4,0
    struct buf *lbuf = bread(log.dev, log.start+tail+1); // read log block
    8000471c:	00025997          	auipc	s3,0x25
    80004720:	40498993          	addi	s3,s3,1028 # 80029b20 <log>
    80004724:	a00d                	j	80004746 <install_trans+0x56>
    brelse(lbuf);
    80004726:	854a                	mv	a0,s2
    80004728:	fffff097          	auipc	ra,0xfffff
    8000472c:	052080e7          	jalr	82(ra) # 8000377a <brelse>
    brelse(dbuf);
    80004730:	8526                	mv	a0,s1
    80004732:	fffff097          	auipc	ra,0xfffff
    80004736:	048080e7          	jalr	72(ra) # 8000377a <brelse>
  for (tail = 0; tail < log.lh.n; tail++) {
    8000473a:	2a05                	addiw	s4,s4,1
    8000473c:	0a91                	addi	s5,s5,4
    8000473e:	02c9a783          	lw	a5,44(s3)
    80004742:	04fa5e63          	bge	s4,a5,8000479e <install_trans+0xae>
    struct buf *lbuf = bread(log.dev, log.start+tail+1); // read log block
    80004746:	0189a583          	lw	a1,24(s3)
    8000474a:	014585bb          	addw	a1,a1,s4
    8000474e:	2585                	addiw	a1,a1,1
    80004750:	0289a503          	lw	a0,40(s3)
    80004754:	fffff097          	auipc	ra,0xfffff
    80004758:	ef6080e7          	jalr	-266(ra) # 8000364a <bread>
    8000475c:	892a                	mv	s2,a0
    struct buf *dbuf = bread(log.dev, log.lh.block[tail]); // read dst
    8000475e:	000aa583          	lw	a1,0(s5)
    80004762:	0289a503          	lw	a0,40(s3)
    80004766:	fffff097          	auipc	ra,0xfffff
    8000476a:	ee4080e7          	jalr	-284(ra) # 8000364a <bread>
    8000476e:	84aa                	mv	s1,a0
    memmove(dbuf->data, lbuf->data, BSIZE);  // copy block to dst
    80004770:	40000613          	li	a2,1024
    80004774:	05890593          	addi	a1,s2,88
    80004778:	05850513          	addi	a0,a0,88
    8000477c:	ffffc097          	auipc	ra,0xffffc
    80004780:	614080e7          	jalr	1556(ra) # 80000d90 <memmove>
    bwrite(dbuf);  // write dst to disk
    80004784:	8526                	mv	a0,s1
    80004786:	fffff097          	auipc	ra,0xfffff
    8000478a:	fb6080e7          	jalr	-74(ra) # 8000373c <bwrite>
    if(recovering == 0)
    8000478e:	f80b1ce3          	bnez	s6,80004726 <install_trans+0x36>
      bunpin(dbuf);
    80004792:	8526                	mv	a0,s1
    80004794:	fffff097          	auipc	ra,0xfffff
    80004798:	0be080e7          	jalr	190(ra) # 80003852 <bunpin>
    8000479c:	b769                	j	80004726 <install_trans+0x36>
}
    8000479e:	70e2                	ld	ra,56(sp)
    800047a0:	7442                	ld	s0,48(sp)
    800047a2:	74a2                	ld	s1,40(sp)
    800047a4:	7902                	ld	s2,32(sp)
    800047a6:	69e2                	ld	s3,24(sp)
    800047a8:	6a42                	ld	s4,16(sp)
    800047aa:	6aa2                	ld	s5,8(sp)
    800047ac:	6b02                	ld	s6,0(sp)
    800047ae:	6121                	addi	sp,sp,64
    800047b0:	8082                	ret
    800047b2:	8082                	ret

00000000800047b4 <initlog>:
{
    800047b4:	7179                	addi	sp,sp,-48
    800047b6:	f406                	sd	ra,40(sp)
    800047b8:	f022                	sd	s0,32(sp)
    800047ba:	ec26                	sd	s1,24(sp)
    800047bc:	e84a                	sd	s2,16(sp)
    800047be:	e44e                	sd	s3,8(sp)
    800047c0:	1800                	addi	s0,sp,48
    800047c2:	892a                	mv	s2,a0
    800047c4:	89ae                	mv	s3,a1
  initlock(&log.lock, "log");
    800047c6:	00025497          	auipc	s1,0x25
    800047ca:	35a48493          	addi	s1,s1,858 # 80029b20 <log>
    800047ce:	00004597          	auipc	a1,0x4
    800047d2:	d4258593          	addi	a1,a1,-702 # 80008510 <etext+0x510>
    800047d6:	8526                	mv	a0,s1
    800047d8:	ffffc097          	auipc	ra,0xffffc
    800047dc:	3d0080e7          	jalr	976(ra) # 80000ba8 <initlock>
  log.start = sb->logstart;
    800047e0:	0149a583          	lw	a1,20(s3)
    800047e4:	cc8c                	sw	a1,24(s1)
  log.size = sb->nlog;
    800047e6:	0109a783          	lw	a5,16(s3)
    800047ea:	ccdc                	sw	a5,28(s1)
  log.dev = dev;
    800047ec:	0324a423          	sw	s2,40(s1)
  struct buf *buf = bread(log.dev, log.start);
    800047f0:	854a                	mv	a0,s2
    800047f2:	fffff097          	auipc	ra,0xfffff
    800047f6:	e58080e7          	jalr	-424(ra) # 8000364a <bread>
  log.lh.n = lh->n;
    800047fa:	4d30                	lw	a2,88(a0)
    800047fc:	d4d0                	sw	a2,44(s1)
  for (i = 0; i < log.lh.n; i++) {
    800047fe:	00c05f63          	blez	a2,8000481c <initlog+0x68>
    80004802:	87aa                	mv	a5,a0
    80004804:	00025717          	auipc	a4,0x25
    80004808:	34c70713          	addi	a4,a4,844 # 80029b50 <log+0x30>
    8000480c:	060a                	slli	a2,a2,0x2
    8000480e:	962a                	add	a2,a2,a0
    log.lh.block[i] = lh->block[i];
    80004810:	4ff4                	lw	a3,92(a5)
    80004812:	c314                	sw	a3,0(a4)
  for (i = 0; i < log.lh.n; i++) {
    80004814:	0791                	addi	a5,a5,4
    80004816:	0711                	addi	a4,a4,4
    80004818:	fec79ce3          	bne	a5,a2,80004810 <initlog+0x5c>
  brelse(buf);
    8000481c:	fffff097          	auipc	ra,0xfffff
    80004820:	f5e080e7          	jalr	-162(ra) # 8000377a <brelse>

static void
recover_from_log(void)
{
  read_head();
  install_trans(1); // if committed, copy from log to disk
    80004824:	4505                	li	a0,1
    80004826:	00000097          	auipc	ra,0x0
    8000482a:	eca080e7          	jalr	-310(ra) # 800046f0 <install_trans>
  log.lh.n = 0;
    8000482e:	00025797          	auipc	a5,0x25
    80004832:	3007af23          	sw	zero,798(a5) # 80029b4c <log+0x2c>
  write_head(); // clear the log
    80004836:	00000097          	auipc	ra,0x0
    8000483a:	e50080e7          	jalr	-432(ra) # 80004686 <write_head>
}
    8000483e:	70a2                	ld	ra,40(sp)
    80004840:	7402                	ld	s0,32(sp)
    80004842:	64e2                	ld	s1,24(sp)
    80004844:	6942                	ld	s2,16(sp)
    80004846:	69a2                	ld	s3,8(sp)
    80004848:	6145                	addi	sp,sp,48
    8000484a:	8082                	ret

000000008000484c <begin_op>:
}

// called at the start of each FS system call.
void
begin_op(void)
{
    8000484c:	1101                	addi	sp,sp,-32
    8000484e:	ec06                	sd	ra,24(sp)
    80004850:	e822                	sd	s0,16(sp)
    80004852:	e426                	sd	s1,8(sp)
    80004854:	e04a                	sd	s2,0(sp)
    80004856:	1000                	addi	s0,sp,32
  acquire(&log.lock);
    80004858:	00025517          	auipc	a0,0x25
    8000485c:	2c850513          	addi	a0,a0,712 # 80029b20 <log>
    80004860:	ffffc097          	auipc	ra,0xffffc
    80004864:	3d8080e7          	jalr	984(ra) # 80000c38 <acquire>
  while(1){
    if(log.committing){
    80004868:	00025497          	auipc	s1,0x25
    8000486c:	2b848493          	addi	s1,s1,696 # 80029b20 <log>
      sleep(&log, &log.lock);
    } else if(log.lh.n + (log.outstanding+1)*MAXOPBLOCKS > LOGSIZE){
    80004870:	4979                	li	s2,30
    80004872:	a039                	j	80004880 <begin_op+0x34>
      sleep(&log, &log.lock);
    80004874:	85a6                	mv	a1,s1
    80004876:	8526                	mv	a0,s1
    80004878:	ffffe097          	auipc	ra,0xffffe
    8000487c:	b46080e7          	jalr	-1210(ra) # 800023be <sleep>
    if(log.committing){
    80004880:	50dc                	lw	a5,36(s1)
    80004882:	fbed                	bnez	a5,80004874 <begin_op+0x28>
    } else if(log.lh.n + (log.outstanding+1)*MAXOPBLOCKS > LOGSIZE){
    80004884:	5098                	lw	a4,32(s1)
    80004886:	2705                	addiw	a4,a4,1
    80004888:	0027179b          	slliw	a5,a4,0x2
    8000488c:	9fb9                	addw	a5,a5,a4
    8000488e:	0017979b          	slliw	a5,a5,0x1
    80004892:	54d4                	lw	a3,44(s1)
    80004894:	9fb5                	addw	a5,a5,a3
    80004896:	00f95963          	bge	s2,a5,800048a8 <begin_op+0x5c>
      // this op might exhaust log space; wait for commit.
      sleep(&log, &log.lock);
    8000489a:	85a6                	mv	a1,s1
    8000489c:	8526                	mv	a0,s1
    8000489e:	ffffe097          	auipc	ra,0xffffe
    800048a2:	b20080e7          	jalr	-1248(ra) # 800023be <sleep>
    800048a6:	bfe9                	j	80004880 <begin_op+0x34>
    } else {
      log.outstanding += 1;
    800048a8:	00025517          	auipc	a0,0x25
    800048ac:	27850513          	addi	a0,a0,632 # 80029b20 <log>
    800048b0:	d118                	sw	a4,32(a0)
      release(&log.lock);
    800048b2:	ffffc097          	auipc	ra,0xffffc
    800048b6:	43a080e7          	jalr	1082(ra) # 80000cec <release>
      break;
    }
  }
}
    800048ba:	60e2                	ld	ra,24(sp)
    800048bc:	6442                	ld	s0,16(sp)
    800048be:	64a2                	ld	s1,8(sp)
    800048c0:	6902                	ld	s2,0(sp)
    800048c2:	6105                	addi	sp,sp,32
    800048c4:	8082                	ret

00000000800048c6 <end_op>:

// called at the end of each FS system call.
// commits if this was the last outstanding operation.
void
end_op(void)
{
    800048c6:	7139                	addi	sp,sp,-64
    800048c8:	fc06                	sd	ra,56(sp)
    800048ca:	f822                	sd	s0,48(sp)
    800048cc:	f426                	sd	s1,40(sp)
    800048ce:	f04a                	sd	s2,32(sp)
    800048d0:	0080                	addi	s0,sp,64
  int do_commit = 0;

  acquire(&log.lock);
    800048d2:	00025497          	auipc	s1,0x25
    800048d6:	24e48493          	addi	s1,s1,590 # 80029b20 <log>
    800048da:	8526                	mv	a0,s1
    800048dc:	ffffc097          	auipc	ra,0xffffc
    800048e0:	35c080e7          	jalr	860(ra) # 80000c38 <acquire>
  log.outstanding -= 1;
    800048e4:	509c                	lw	a5,32(s1)
    800048e6:	37fd                	addiw	a5,a5,-1
    800048e8:	0007891b          	sext.w	s2,a5
    800048ec:	d09c                	sw	a5,32(s1)
  if(log.committing)
    800048ee:	50dc                	lw	a5,36(s1)
    800048f0:	e7b9                	bnez	a5,8000493e <end_op+0x78>
    panic("log.committing");
  if(log.outstanding == 0){
    800048f2:	06091163          	bnez	s2,80004954 <end_op+0x8e>
    do_commit = 1;
    log.committing = 1;
    800048f6:	00025497          	auipc	s1,0x25
    800048fa:	22a48493          	addi	s1,s1,554 # 80029b20 <log>
    800048fe:	4785                	li	a5,1
    80004900:	d0dc                	sw	a5,36(s1)
    // begin_op() may be waiting for log space,
    // and decrementing log.outstanding has decreased
    // the amount of reserved space.
    wakeup(&log);
  }
  release(&log.lock);
    80004902:	8526                	mv	a0,s1
    80004904:	ffffc097          	auipc	ra,0xffffc
    80004908:	3e8080e7          	jalr	1000(ra) # 80000cec <release>
}

static void
commit()
{
  if (log.lh.n > 0) {
    8000490c:	54dc                	lw	a5,44(s1)
    8000490e:	06f04763          	bgtz	a5,8000497c <end_op+0xb6>
    acquire(&log.lock);
    80004912:	00025497          	auipc	s1,0x25
    80004916:	20e48493          	addi	s1,s1,526 # 80029b20 <log>
    8000491a:	8526                	mv	a0,s1
    8000491c:	ffffc097          	auipc	ra,0xffffc
    80004920:	31c080e7          	jalr	796(ra) # 80000c38 <acquire>
    log.committing = 0;
    80004924:	0204a223          	sw	zero,36(s1)
    wakeup(&log);
    80004928:	8526                	mv	a0,s1
    8000492a:	ffffe097          	auipc	ra,0xffffe
    8000492e:	b04080e7          	jalr	-1276(ra) # 8000242e <wakeup>
    release(&log.lock);
    80004932:	8526                	mv	a0,s1
    80004934:	ffffc097          	auipc	ra,0xffffc
    80004938:	3b8080e7          	jalr	952(ra) # 80000cec <release>
}
    8000493c:	a815                	j	80004970 <end_op+0xaa>
    8000493e:	ec4e                	sd	s3,24(sp)
    80004940:	e852                	sd	s4,16(sp)
    80004942:	e456                	sd	s5,8(sp)
    panic("log.committing");
    80004944:	00004517          	auipc	a0,0x4
    80004948:	bd450513          	addi	a0,a0,-1068 # 80008518 <etext+0x518>
    8000494c:	ffffc097          	auipc	ra,0xffffc
    80004950:	c14080e7          	jalr	-1004(ra) # 80000560 <panic>
    wakeup(&log);
    80004954:	00025497          	auipc	s1,0x25
    80004958:	1cc48493          	addi	s1,s1,460 # 80029b20 <log>
    8000495c:	8526                	mv	a0,s1
    8000495e:	ffffe097          	auipc	ra,0xffffe
    80004962:	ad0080e7          	jalr	-1328(ra) # 8000242e <wakeup>
  release(&log.lock);
    80004966:	8526                	mv	a0,s1
    80004968:	ffffc097          	auipc	ra,0xffffc
    8000496c:	384080e7          	jalr	900(ra) # 80000cec <release>
}
    80004970:	70e2                	ld	ra,56(sp)
    80004972:	7442                	ld	s0,48(sp)
    80004974:	74a2                	ld	s1,40(sp)
    80004976:	7902                	ld	s2,32(sp)
    80004978:	6121                	addi	sp,sp,64
    8000497a:	8082                	ret
    8000497c:	ec4e                	sd	s3,24(sp)
    8000497e:	e852                	sd	s4,16(sp)
    80004980:	e456                	sd	s5,8(sp)
  for (tail = 0; tail < log.lh.n; tail++) {
    80004982:	00025a97          	auipc	s5,0x25
    80004986:	1cea8a93          	addi	s5,s5,462 # 80029b50 <log+0x30>
    struct buf *to = bread(log.dev, log.start+tail+1); // log block
    8000498a:	00025a17          	auipc	s4,0x25
    8000498e:	196a0a13          	addi	s4,s4,406 # 80029b20 <log>
    80004992:	018a2583          	lw	a1,24(s4)
    80004996:	012585bb          	addw	a1,a1,s2
    8000499a:	2585                	addiw	a1,a1,1
    8000499c:	028a2503          	lw	a0,40(s4)
    800049a0:	fffff097          	auipc	ra,0xfffff
    800049a4:	caa080e7          	jalr	-854(ra) # 8000364a <bread>
    800049a8:	84aa                	mv	s1,a0
    struct buf *from = bread(log.dev, log.lh.block[tail]); // cache block
    800049aa:	000aa583          	lw	a1,0(s5)
    800049ae:	028a2503          	lw	a0,40(s4)
    800049b2:	fffff097          	auipc	ra,0xfffff
    800049b6:	c98080e7          	jalr	-872(ra) # 8000364a <bread>
    800049ba:	89aa                	mv	s3,a0
    memmove(to->data, from->data, BSIZE);
    800049bc:	40000613          	li	a2,1024
    800049c0:	05850593          	addi	a1,a0,88
    800049c4:	05848513          	addi	a0,s1,88
    800049c8:	ffffc097          	auipc	ra,0xffffc
    800049cc:	3c8080e7          	jalr	968(ra) # 80000d90 <memmove>
    bwrite(to);  // write the log
    800049d0:	8526                	mv	a0,s1
    800049d2:	fffff097          	auipc	ra,0xfffff
    800049d6:	d6a080e7          	jalr	-662(ra) # 8000373c <bwrite>
    brelse(from);
    800049da:	854e                	mv	a0,s3
    800049dc:	fffff097          	auipc	ra,0xfffff
    800049e0:	d9e080e7          	jalr	-610(ra) # 8000377a <brelse>
    brelse(to);
    800049e4:	8526                	mv	a0,s1
    800049e6:	fffff097          	auipc	ra,0xfffff
    800049ea:	d94080e7          	jalr	-620(ra) # 8000377a <brelse>
  for (tail = 0; tail < log.lh.n; tail++) {
    800049ee:	2905                	addiw	s2,s2,1
    800049f0:	0a91                	addi	s5,s5,4
    800049f2:	02ca2783          	lw	a5,44(s4)
    800049f6:	f8f94ee3          	blt	s2,a5,80004992 <end_op+0xcc>
    write_log();     // Write modified blocks from cache to log
    write_head();    // Write header to disk -- the real commit
    800049fa:	00000097          	auipc	ra,0x0
    800049fe:	c8c080e7          	jalr	-884(ra) # 80004686 <write_head>
    install_trans(0); // Now install writes to home locations
    80004a02:	4501                	li	a0,0
    80004a04:	00000097          	auipc	ra,0x0
    80004a08:	cec080e7          	jalr	-788(ra) # 800046f0 <install_trans>
    log.lh.n = 0;
    80004a0c:	00025797          	auipc	a5,0x25
    80004a10:	1407a023          	sw	zero,320(a5) # 80029b4c <log+0x2c>
    write_head();    // Erase the transaction from the log
    80004a14:	00000097          	auipc	ra,0x0
    80004a18:	c72080e7          	jalr	-910(ra) # 80004686 <write_head>
    80004a1c:	69e2                	ld	s3,24(sp)
    80004a1e:	6a42                	ld	s4,16(sp)
    80004a20:	6aa2                	ld	s5,8(sp)
    80004a22:	bdc5                	j	80004912 <end_op+0x4c>

0000000080004a24 <log_write>:
//   modify bp->data[]
//   log_write(bp)
//   brelse(bp)
void
log_write(struct buf *b)
{
    80004a24:	1101                	addi	sp,sp,-32
    80004a26:	ec06                	sd	ra,24(sp)
    80004a28:	e822                	sd	s0,16(sp)
    80004a2a:	e426                	sd	s1,8(sp)
    80004a2c:	e04a                	sd	s2,0(sp)
    80004a2e:	1000                	addi	s0,sp,32
    80004a30:	84aa                	mv	s1,a0
  int i;

  acquire(&log.lock);
    80004a32:	00025917          	auipc	s2,0x25
    80004a36:	0ee90913          	addi	s2,s2,238 # 80029b20 <log>
    80004a3a:	854a                	mv	a0,s2
    80004a3c:	ffffc097          	auipc	ra,0xffffc
    80004a40:	1fc080e7          	jalr	508(ra) # 80000c38 <acquire>
  if (log.lh.n >= LOGSIZE || log.lh.n >= log.size - 1)
    80004a44:	02c92603          	lw	a2,44(s2)
    80004a48:	47f5                	li	a5,29
    80004a4a:	06c7c563          	blt	a5,a2,80004ab4 <log_write+0x90>
    80004a4e:	00025797          	auipc	a5,0x25
    80004a52:	0ee7a783          	lw	a5,238(a5) # 80029b3c <log+0x1c>
    80004a56:	37fd                	addiw	a5,a5,-1
    80004a58:	04f65e63          	bge	a2,a5,80004ab4 <log_write+0x90>
    panic("too big a transaction");
  if (log.outstanding < 1)
    80004a5c:	00025797          	auipc	a5,0x25
    80004a60:	0e47a783          	lw	a5,228(a5) # 80029b40 <log+0x20>
    80004a64:	06f05063          	blez	a5,80004ac4 <log_write+0xa0>
    panic("log_write outside of trans");

  for (i = 0; i < log.lh.n; i++) {
    80004a68:	4781                	li	a5,0
    80004a6a:	06c05563          	blez	a2,80004ad4 <log_write+0xb0>
    if (log.lh.block[i] == b->blockno)   // log absorption
    80004a6e:	44cc                	lw	a1,12(s1)
    80004a70:	00025717          	auipc	a4,0x25
    80004a74:	0e070713          	addi	a4,a4,224 # 80029b50 <log+0x30>
  for (i = 0; i < log.lh.n; i++) {
    80004a78:	4781                	li	a5,0
    if (log.lh.block[i] == b->blockno)   // log absorption
    80004a7a:	4314                	lw	a3,0(a4)
    80004a7c:	04b68c63          	beq	a3,a1,80004ad4 <log_write+0xb0>
  for (i = 0; i < log.lh.n; i++) {
    80004a80:	2785                	addiw	a5,a5,1
    80004a82:	0711                	addi	a4,a4,4
    80004a84:	fef61be3          	bne	a2,a5,80004a7a <log_write+0x56>
      break;
  }
  log.lh.block[i] = b->blockno;
    80004a88:	0621                	addi	a2,a2,8
    80004a8a:	060a                	slli	a2,a2,0x2
    80004a8c:	00025797          	auipc	a5,0x25
    80004a90:	09478793          	addi	a5,a5,148 # 80029b20 <log>
    80004a94:	97b2                	add	a5,a5,a2
    80004a96:	44d8                	lw	a4,12(s1)
    80004a98:	cb98                	sw	a4,16(a5)
  if (i == log.lh.n) {  // Add new block to log?
    bpin(b);
    80004a9a:	8526                	mv	a0,s1
    80004a9c:	fffff097          	auipc	ra,0xfffff
    80004aa0:	d7a080e7          	jalr	-646(ra) # 80003816 <bpin>
    log.lh.n++;
    80004aa4:	00025717          	auipc	a4,0x25
    80004aa8:	07c70713          	addi	a4,a4,124 # 80029b20 <log>
    80004aac:	575c                	lw	a5,44(a4)
    80004aae:	2785                	addiw	a5,a5,1
    80004ab0:	d75c                	sw	a5,44(a4)
    80004ab2:	a82d                	j	80004aec <log_write+0xc8>
    panic("too big a transaction");
    80004ab4:	00004517          	auipc	a0,0x4
    80004ab8:	a7450513          	addi	a0,a0,-1420 # 80008528 <etext+0x528>
    80004abc:	ffffc097          	auipc	ra,0xffffc
    80004ac0:	aa4080e7          	jalr	-1372(ra) # 80000560 <panic>
    panic("log_write outside of trans");
    80004ac4:	00004517          	auipc	a0,0x4
    80004ac8:	a7c50513          	addi	a0,a0,-1412 # 80008540 <etext+0x540>
    80004acc:	ffffc097          	auipc	ra,0xffffc
    80004ad0:	a94080e7          	jalr	-1388(ra) # 80000560 <panic>
  log.lh.block[i] = b->blockno;
    80004ad4:	00878693          	addi	a3,a5,8
    80004ad8:	068a                	slli	a3,a3,0x2
    80004ada:	00025717          	auipc	a4,0x25
    80004ade:	04670713          	addi	a4,a4,70 # 80029b20 <log>
    80004ae2:	9736                	add	a4,a4,a3
    80004ae4:	44d4                	lw	a3,12(s1)
    80004ae6:	cb14                	sw	a3,16(a4)
  if (i == log.lh.n) {  // Add new block to log?
    80004ae8:	faf609e3          	beq	a2,a5,80004a9a <log_write+0x76>
  }
  release(&log.lock);
    80004aec:	00025517          	auipc	a0,0x25
    80004af0:	03450513          	addi	a0,a0,52 # 80029b20 <log>
    80004af4:	ffffc097          	auipc	ra,0xffffc
    80004af8:	1f8080e7          	jalr	504(ra) # 80000cec <release>
}
    80004afc:	60e2                	ld	ra,24(sp)
    80004afe:	6442                	ld	s0,16(sp)
    80004b00:	64a2                	ld	s1,8(sp)
    80004b02:	6902                	ld	s2,0(sp)
    80004b04:	6105                	addi	sp,sp,32
    80004b06:	8082                	ret

0000000080004b08 <initsleeplock>:
#include "proc.h"
#include "sleeplock.h"

void
initsleeplock(struct sleeplock *lk, char *name)
{
    80004b08:	1101                	addi	sp,sp,-32
    80004b0a:	ec06                	sd	ra,24(sp)
    80004b0c:	e822                	sd	s0,16(sp)
    80004b0e:	e426                	sd	s1,8(sp)
    80004b10:	e04a                	sd	s2,0(sp)
    80004b12:	1000                	addi	s0,sp,32
    80004b14:	84aa                	mv	s1,a0
    80004b16:	892e                	mv	s2,a1
  initlock(&lk->lk, "sleep lock");
    80004b18:	00004597          	auipc	a1,0x4
    80004b1c:	a4858593          	addi	a1,a1,-1464 # 80008560 <etext+0x560>
    80004b20:	0521                	addi	a0,a0,8
    80004b22:	ffffc097          	auipc	ra,0xffffc
    80004b26:	086080e7          	jalr	134(ra) # 80000ba8 <initlock>
  lk->name = name;
    80004b2a:	0324b023          	sd	s2,32(s1)
  lk->locked = 0;
    80004b2e:	0004a023          	sw	zero,0(s1)
  lk->pid = 0;
    80004b32:	0204a423          	sw	zero,40(s1)
}
    80004b36:	60e2                	ld	ra,24(sp)
    80004b38:	6442                	ld	s0,16(sp)
    80004b3a:	64a2                	ld	s1,8(sp)
    80004b3c:	6902                	ld	s2,0(sp)
    80004b3e:	6105                	addi	sp,sp,32
    80004b40:	8082                	ret

0000000080004b42 <acquiresleep>:

void
acquiresleep(struct sleeplock *lk)
{
    80004b42:	1101                	addi	sp,sp,-32
    80004b44:	ec06                	sd	ra,24(sp)
    80004b46:	e822                	sd	s0,16(sp)
    80004b48:	e426                	sd	s1,8(sp)
    80004b4a:	e04a                	sd	s2,0(sp)
    80004b4c:	1000                	addi	s0,sp,32
    80004b4e:	84aa                	mv	s1,a0
  acquire(&lk->lk);
    80004b50:	00850913          	addi	s2,a0,8
    80004b54:	854a                	mv	a0,s2
    80004b56:	ffffc097          	auipc	ra,0xffffc
    80004b5a:	0e2080e7          	jalr	226(ra) # 80000c38 <acquire>
  while (lk->locked) {
    80004b5e:	409c                	lw	a5,0(s1)
    80004b60:	cb89                	beqz	a5,80004b72 <acquiresleep+0x30>
    sleep(lk, &lk->lk);
    80004b62:	85ca                	mv	a1,s2
    80004b64:	8526                	mv	a0,s1
    80004b66:	ffffe097          	auipc	ra,0xffffe
    80004b6a:	858080e7          	jalr	-1960(ra) # 800023be <sleep>
  while (lk->locked) {
    80004b6e:	409c                	lw	a5,0(s1)
    80004b70:	fbed                	bnez	a5,80004b62 <acquiresleep+0x20>
  }
  lk->locked = 1;
    80004b72:	4785                	li	a5,1
    80004b74:	c09c                	sw	a5,0(s1)
  lk->pid = myproc()->pid;
    80004b76:	ffffd097          	auipc	ra,0xffffd
    80004b7a:	0be080e7          	jalr	190(ra) # 80001c34 <myproc>
    80004b7e:	15052783          	lw	a5,336(a0)
    80004b82:	d49c                	sw	a5,40(s1)
  release(&lk->lk);
    80004b84:	854a                	mv	a0,s2
    80004b86:	ffffc097          	auipc	ra,0xffffc
    80004b8a:	166080e7          	jalr	358(ra) # 80000cec <release>
}
    80004b8e:	60e2                	ld	ra,24(sp)
    80004b90:	6442                	ld	s0,16(sp)
    80004b92:	64a2                	ld	s1,8(sp)
    80004b94:	6902                	ld	s2,0(sp)
    80004b96:	6105                	addi	sp,sp,32
    80004b98:	8082                	ret

0000000080004b9a <releasesleep>:

void
releasesleep(struct sleeplock *lk)
{
    80004b9a:	1101                	addi	sp,sp,-32
    80004b9c:	ec06                	sd	ra,24(sp)
    80004b9e:	e822                	sd	s0,16(sp)
    80004ba0:	e426                	sd	s1,8(sp)
    80004ba2:	e04a                	sd	s2,0(sp)
    80004ba4:	1000                	addi	s0,sp,32
    80004ba6:	84aa                	mv	s1,a0
  acquire(&lk->lk);
    80004ba8:	00850913          	addi	s2,a0,8
    80004bac:	854a                	mv	a0,s2
    80004bae:	ffffc097          	auipc	ra,0xffffc
    80004bb2:	08a080e7          	jalr	138(ra) # 80000c38 <acquire>
  lk->locked = 0;
    80004bb6:	0004a023          	sw	zero,0(s1)
  lk->pid = 0;
    80004bba:	0204a423          	sw	zero,40(s1)
  wakeup(lk);
    80004bbe:	8526                	mv	a0,s1
    80004bc0:	ffffe097          	auipc	ra,0xffffe
    80004bc4:	86e080e7          	jalr	-1938(ra) # 8000242e <wakeup>
  release(&lk->lk);
    80004bc8:	854a                	mv	a0,s2
    80004bca:	ffffc097          	auipc	ra,0xffffc
    80004bce:	122080e7          	jalr	290(ra) # 80000cec <release>
}
    80004bd2:	60e2                	ld	ra,24(sp)
    80004bd4:	6442                	ld	s0,16(sp)
    80004bd6:	64a2                	ld	s1,8(sp)
    80004bd8:	6902                	ld	s2,0(sp)
    80004bda:	6105                	addi	sp,sp,32
    80004bdc:	8082                	ret

0000000080004bde <holdingsleep>:

int
holdingsleep(struct sleeplock *lk)
{
    80004bde:	7179                	addi	sp,sp,-48
    80004be0:	f406                	sd	ra,40(sp)
    80004be2:	f022                	sd	s0,32(sp)
    80004be4:	ec26                	sd	s1,24(sp)
    80004be6:	e84a                	sd	s2,16(sp)
    80004be8:	1800                	addi	s0,sp,48
    80004bea:	84aa                	mv	s1,a0
  int r;
  
  acquire(&lk->lk);
    80004bec:	00850913          	addi	s2,a0,8
    80004bf0:	854a                	mv	a0,s2
    80004bf2:	ffffc097          	auipc	ra,0xffffc
    80004bf6:	046080e7          	jalr	70(ra) # 80000c38 <acquire>
  r = lk->locked && (lk->pid == myproc()->pid);
    80004bfa:	409c                	lw	a5,0(s1)
    80004bfc:	ef91                	bnez	a5,80004c18 <holdingsleep+0x3a>
    80004bfe:	4481                	li	s1,0
  release(&lk->lk);
    80004c00:	854a                	mv	a0,s2
    80004c02:	ffffc097          	auipc	ra,0xffffc
    80004c06:	0ea080e7          	jalr	234(ra) # 80000cec <release>
  return r;
}
    80004c0a:	8526                	mv	a0,s1
    80004c0c:	70a2                	ld	ra,40(sp)
    80004c0e:	7402                	ld	s0,32(sp)
    80004c10:	64e2                	ld	s1,24(sp)
    80004c12:	6942                	ld	s2,16(sp)
    80004c14:	6145                	addi	sp,sp,48
    80004c16:	8082                	ret
    80004c18:	e44e                	sd	s3,8(sp)
  r = lk->locked && (lk->pid == myproc()->pid);
    80004c1a:	0284a983          	lw	s3,40(s1)
    80004c1e:	ffffd097          	auipc	ra,0xffffd
    80004c22:	016080e7          	jalr	22(ra) # 80001c34 <myproc>
    80004c26:	15052483          	lw	s1,336(a0)
    80004c2a:	413484b3          	sub	s1,s1,s3
    80004c2e:	0014b493          	seqz	s1,s1
    80004c32:	69a2                	ld	s3,8(sp)
    80004c34:	b7f1                	j	80004c00 <holdingsleep+0x22>

0000000080004c36 <fileinit>:
  struct file file[NFILE];
} ftable;

void
fileinit(void)
{
    80004c36:	1141                	addi	sp,sp,-16
    80004c38:	e406                	sd	ra,8(sp)
    80004c3a:	e022                	sd	s0,0(sp)
    80004c3c:	0800                	addi	s0,sp,16
  initlock(&ftable.lock, "ftable");
    80004c3e:	00004597          	auipc	a1,0x4
    80004c42:	93258593          	addi	a1,a1,-1742 # 80008570 <etext+0x570>
    80004c46:	00025517          	auipc	a0,0x25
    80004c4a:	02250513          	addi	a0,a0,34 # 80029c68 <ftable>
    80004c4e:	ffffc097          	auipc	ra,0xffffc
    80004c52:	f5a080e7          	jalr	-166(ra) # 80000ba8 <initlock>
}
    80004c56:	60a2                	ld	ra,8(sp)
    80004c58:	6402                	ld	s0,0(sp)
    80004c5a:	0141                	addi	sp,sp,16
    80004c5c:	8082                	ret

0000000080004c5e <filealloc>:

// Allocate a file structure.
struct file*
filealloc(void)
{
    80004c5e:	1101                	addi	sp,sp,-32
    80004c60:	ec06                	sd	ra,24(sp)
    80004c62:	e822                	sd	s0,16(sp)
    80004c64:	e426                	sd	s1,8(sp)
    80004c66:	1000                	addi	s0,sp,32
  struct file *f;

  acquire(&ftable.lock);
    80004c68:	00025517          	auipc	a0,0x25
    80004c6c:	00050513          	mv	a0,a0
    80004c70:	ffffc097          	auipc	ra,0xffffc
    80004c74:	fc8080e7          	jalr	-56(ra) # 80000c38 <acquire>
  for(f = ftable.file; f < ftable.file + NFILE; f++){
    80004c78:	00025497          	auipc	s1,0x25
    80004c7c:	00848493          	addi	s1,s1,8 # 80029c80 <ftable+0x18>
    80004c80:	00026717          	auipc	a4,0x26
    80004c84:	fa070713          	addi	a4,a4,-96 # 8002ac20 <disk>
    if(f->ref == 0){
    80004c88:	40dc                	lw	a5,4(s1)
    80004c8a:	cf99                	beqz	a5,80004ca8 <filealloc+0x4a>
  for(f = ftable.file; f < ftable.file + NFILE; f++){
    80004c8c:	02848493          	addi	s1,s1,40
    80004c90:	fee49ce3          	bne	s1,a4,80004c88 <filealloc+0x2a>
      f->ref = 1;
      release(&ftable.lock);
      return f;
    }
  }
  release(&ftable.lock);
    80004c94:	00025517          	auipc	a0,0x25
    80004c98:	fd450513          	addi	a0,a0,-44 # 80029c68 <ftable>
    80004c9c:	ffffc097          	auipc	ra,0xffffc
    80004ca0:	050080e7          	jalr	80(ra) # 80000cec <release>
  return 0;
    80004ca4:	4481                	li	s1,0
    80004ca6:	a819                	j	80004cbc <filealloc+0x5e>
      f->ref = 1;
    80004ca8:	4785                	li	a5,1
    80004caa:	c0dc                	sw	a5,4(s1)
      release(&ftable.lock);
    80004cac:	00025517          	auipc	a0,0x25
    80004cb0:	fbc50513          	addi	a0,a0,-68 # 80029c68 <ftable>
    80004cb4:	ffffc097          	auipc	ra,0xffffc
    80004cb8:	038080e7          	jalr	56(ra) # 80000cec <release>
}
    80004cbc:	8526                	mv	a0,s1
    80004cbe:	60e2                	ld	ra,24(sp)
    80004cc0:	6442                	ld	s0,16(sp)
    80004cc2:	64a2                	ld	s1,8(sp)
    80004cc4:	6105                	addi	sp,sp,32
    80004cc6:	8082                	ret

0000000080004cc8 <filedup>:

// Increment ref count for file f.
struct file*
filedup(struct file *f)
{
    80004cc8:	1101                	addi	sp,sp,-32
    80004cca:	ec06                	sd	ra,24(sp)
    80004ccc:	e822                	sd	s0,16(sp)
    80004cce:	e426                	sd	s1,8(sp)
    80004cd0:	1000                	addi	s0,sp,32
    80004cd2:	84aa                	mv	s1,a0
  acquire(&ftable.lock);
    80004cd4:	00025517          	auipc	a0,0x25
    80004cd8:	f9450513          	addi	a0,a0,-108 # 80029c68 <ftable>
    80004cdc:	ffffc097          	auipc	ra,0xffffc
    80004ce0:	f5c080e7          	jalr	-164(ra) # 80000c38 <acquire>
  if(f->ref < 1)
    80004ce4:	40dc                	lw	a5,4(s1)
    80004ce6:	02f05263          	blez	a5,80004d0a <filedup+0x42>
    panic("filedup");
  f->ref++;
    80004cea:	2785                	addiw	a5,a5,1
    80004cec:	c0dc                	sw	a5,4(s1)
  release(&ftable.lock);
    80004cee:	00025517          	auipc	a0,0x25
    80004cf2:	f7a50513          	addi	a0,a0,-134 # 80029c68 <ftable>
    80004cf6:	ffffc097          	auipc	ra,0xffffc
    80004cfa:	ff6080e7          	jalr	-10(ra) # 80000cec <release>
  return f;
}
    80004cfe:	8526                	mv	a0,s1
    80004d00:	60e2                	ld	ra,24(sp)
    80004d02:	6442                	ld	s0,16(sp)
    80004d04:	64a2                	ld	s1,8(sp)
    80004d06:	6105                	addi	sp,sp,32
    80004d08:	8082                	ret
    panic("filedup");
    80004d0a:	00004517          	auipc	a0,0x4
    80004d0e:	86e50513          	addi	a0,a0,-1938 # 80008578 <etext+0x578>
    80004d12:	ffffc097          	auipc	ra,0xffffc
    80004d16:	84e080e7          	jalr	-1970(ra) # 80000560 <panic>

0000000080004d1a <fileclose>:

// Close file f.  (Decrement ref count, close when reaches 0.)
void
fileclose(struct file *f)
{
    80004d1a:	7139                	addi	sp,sp,-64
    80004d1c:	fc06                	sd	ra,56(sp)
    80004d1e:	f822                	sd	s0,48(sp)
    80004d20:	f426                	sd	s1,40(sp)
    80004d22:	0080                	addi	s0,sp,64
    80004d24:	84aa                	mv	s1,a0
  struct file ff;

  acquire(&ftable.lock);
    80004d26:	00025517          	auipc	a0,0x25
    80004d2a:	f4250513          	addi	a0,a0,-190 # 80029c68 <ftable>
    80004d2e:	ffffc097          	auipc	ra,0xffffc
    80004d32:	f0a080e7          	jalr	-246(ra) # 80000c38 <acquire>
  if(f->ref < 1)
    80004d36:	40dc                	lw	a5,4(s1)
    80004d38:	04f05c63          	blez	a5,80004d90 <fileclose+0x76>
    panic("fileclose");
  if(--f->ref > 0){
    80004d3c:	37fd                	addiw	a5,a5,-1
    80004d3e:	0007871b          	sext.w	a4,a5
    80004d42:	c0dc                	sw	a5,4(s1)
    80004d44:	06e04263          	bgtz	a4,80004da8 <fileclose+0x8e>
    80004d48:	f04a                	sd	s2,32(sp)
    80004d4a:	ec4e                	sd	s3,24(sp)
    80004d4c:	e852                	sd	s4,16(sp)
    80004d4e:	e456                	sd	s5,8(sp)
    release(&ftable.lock);
    return;
  }
  ff = *f;
    80004d50:	0004a903          	lw	s2,0(s1)
    80004d54:	0094ca83          	lbu	s5,9(s1)
    80004d58:	0104ba03          	ld	s4,16(s1)
    80004d5c:	0184b983          	ld	s3,24(s1)
  f->ref = 0;
    80004d60:	0004a223          	sw	zero,4(s1)
  f->type = FD_NONE;
    80004d64:	0004a023          	sw	zero,0(s1)
  release(&ftable.lock);
    80004d68:	00025517          	auipc	a0,0x25
    80004d6c:	f0050513          	addi	a0,a0,-256 # 80029c68 <ftable>
    80004d70:	ffffc097          	auipc	ra,0xffffc
    80004d74:	f7c080e7          	jalr	-132(ra) # 80000cec <release>

  if(ff.type == FD_PIPE){
    80004d78:	4785                	li	a5,1
    80004d7a:	04f90463          	beq	s2,a5,80004dc2 <fileclose+0xa8>
    pipeclose(ff.pipe, ff.writable);
  } else if(ff.type == FD_INODE || ff.type == FD_DEVICE){
    80004d7e:	3979                	addiw	s2,s2,-2
    80004d80:	4785                	li	a5,1
    80004d82:	0527fb63          	bgeu	a5,s2,80004dd8 <fileclose+0xbe>
    80004d86:	7902                	ld	s2,32(sp)
    80004d88:	69e2                	ld	s3,24(sp)
    80004d8a:	6a42                	ld	s4,16(sp)
    80004d8c:	6aa2                	ld	s5,8(sp)
    80004d8e:	a02d                	j	80004db8 <fileclose+0x9e>
    80004d90:	f04a                	sd	s2,32(sp)
    80004d92:	ec4e                	sd	s3,24(sp)
    80004d94:	e852                	sd	s4,16(sp)
    80004d96:	e456                	sd	s5,8(sp)
    panic("fileclose");
    80004d98:	00003517          	auipc	a0,0x3
    80004d9c:	7e850513          	addi	a0,a0,2024 # 80008580 <etext+0x580>
    80004da0:	ffffb097          	auipc	ra,0xffffb
    80004da4:	7c0080e7          	jalr	1984(ra) # 80000560 <panic>
    release(&ftable.lock);
    80004da8:	00025517          	auipc	a0,0x25
    80004dac:	ec050513          	addi	a0,a0,-320 # 80029c68 <ftable>
    80004db0:	ffffc097          	auipc	ra,0xffffc
    80004db4:	f3c080e7          	jalr	-196(ra) # 80000cec <release>
    begin_op();
    iput(ff.ip);
    end_op();
  }
}
    80004db8:	70e2                	ld	ra,56(sp)
    80004dba:	7442                	ld	s0,48(sp)
    80004dbc:	74a2                	ld	s1,40(sp)
    80004dbe:	6121                	addi	sp,sp,64
    80004dc0:	8082                	ret
    pipeclose(ff.pipe, ff.writable);
    80004dc2:	85d6                	mv	a1,s5
    80004dc4:	8552                	mv	a0,s4
    80004dc6:	00000097          	auipc	ra,0x0
    80004dca:	3a2080e7          	jalr	930(ra) # 80005168 <pipeclose>
    80004dce:	7902                	ld	s2,32(sp)
    80004dd0:	69e2                	ld	s3,24(sp)
    80004dd2:	6a42                	ld	s4,16(sp)
    80004dd4:	6aa2                	ld	s5,8(sp)
    80004dd6:	b7cd                	j	80004db8 <fileclose+0x9e>
    begin_op();
    80004dd8:	00000097          	auipc	ra,0x0
    80004ddc:	a74080e7          	jalr	-1420(ra) # 8000484c <begin_op>
    iput(ff.ip);
    80004de0:	854e                	mv	a0,s3
    80004de2:	fffff097          	auipc	ra,0xfffff
    80004de6:	25a080e7          	jalr	602(ra) # 8000403c <iput>
    end_op();
    80004dea:	00000097          	auipc	ra,0x0
    80004dee:	adc080e7          	jalr	-1316(ra) # 800048c6 <end_op>
    80004df2:	7902                	ld	s2,32(sp)
    80004df4:	69e2                	ld	s3,24(sp)
    80004df6:	6a42                	ld	s4,16(sp)
    80004df8:	6aa2                	ld	s5,8(sp)
    80004dfa:	bf7d                	j	80004db8 <fileclose+0x9e>

0000000080004dfc <filestat>:

// Get metadata about file f.
// addr is a user virtual address, pointing to a struct stat.
int
filestat(struct file *f, uint64 addr)
{
    80004dfc:	715d                	addi	sp,sp,-80
    80004dfe:	e486                	sd	ra,72(sp)
    80004e00:	e0a2                	sd	s0,64(sp)
    80004e02:	fc26                	sd	s1,56(sp)
    80004e04:	f44e                	sd	s3,40(sp)
    80004e06:	0880                	addi	s0,sp,80
    80004e08:	84aa                	mv	s1,a0
    80004e0a:	89ae                	mv	s3,a1
  struct proc *p = myproc();
    80004e0c:	ffffd097          	auipc	ra,0xffffd
    80004e10:	e28080e7          	jalr	-472(ra) # 80001c34 <myproc>
  struct stat st;
  
  if(f->type == FD_INODE || f->type == FD_DEVICE){
    80004e14:	409c                	lw	a5,0(s1)
    80004e16:	37f9                	addiw	a5,a5,-2
    80004e18:	4705                	li	a4,1
    80004e1a:	04f76863          	bltu	a4,a5,80004e6a <filestat+0x6e>
    80004e1e:	f84a                	sd	s2,48(sp)
    80004e20:	892a                	mv	s2,a0
    ilock(f->ip);
    80004e22:	6c88                	ld	a0,24(s1)
    80004e24:	fffff097          	auipc	ra,0xfffff
    80004e28:	05a080e7          	jalr	90(ra) # 80003e7e <ilock>
    stati(f->ip, &st);
    80004e2c:	fb840593          	addi	a1,s0,-72
    80004e30:	6c88                	ld	a0,24(s1)
    80004e32:	fffff097          	auipc	ra,0xfffff
    80004e36:	2da080e7          	jalr	730(ra) # 8000410c <stati>
    iunlock(f->ip);
    80004e3a:	6c88                	ld	a0,24(s1)
    80004e3c:	fffff097          	auipc	ra,0xfffff
    80004e40:	108080e7          	jalr	264(ra) # 80003f44 <iunlock>
    if(copyout(p->pagetable, addr, (char *)&st, sizeof(st)) < 0)
    80004e44:	46e1                	li	a3,24
    80004e46:	fb840613          	addi	a2,s0,-72
    80004e4a:	85ce                	mv	a1,s3
    80004e4c:	17093503          	ld	a0,368(s2)
    80004e50:	ffffd097          	auipc	ra,0xffffd
    80004e54:	892080e7          	jalr	-1902(ra) # 800016e2 <copyout>
    80004e58:	41f5551b          	sraiw	a0,a0,0x1f
    80004e5c:	7942                	ld	s2,48(sp)
      return -1;
    return 0;
  }
  return -1;
}
    80004e5e:	60a6                	ld	ra,72(sp)
    80004e60:	6406                	ld	s0,64(sp)
    80004e62:	74e2                	ld	s1,56(sp)
    80004e64:	79a2                	ld	s3,40(sp)
    80004e66:	6161                	addi	sp,sp,80
    80004e68:	8082                	ret
  return -1;
    80004e6a:	557d                	li	a0,-1
    80004e6c:	bfcd                	j	80004e5e <filestat+0x62>

0000000080004e6e <fileread>:

// Read from file f.
// addr is a user virtual address.
int
fileread(struct file *f, uint64 addr, int n)
{
    80004e6e:	7179                	addi	sp,sp,-48
    80004e70:	f406                	sd	ra,40(sp)
    80004e72:	f022                	sd	s0,32(sp)
    80004e74:	e84a                	sd	s2,16(sp)
    80004e76:	1800                	addi	s0,sp,48
  int r = 0;

  if(f->readable == 0)
    80004e78:	00854783          	lbu	a5,8(a0)
    80004e7c:	cbc5                	beqz	a5,80004f2c <fileread+0xbe>
    80004e7e:	ec26                	sd	s1,24(sp)
    80004e80:	e44e                	sd	s3,8(sp)
    80004e82:	84aa                	mv	s1,a0
    80004e84:	89ae                	mv	s3,a1
    80004e86:	8932                	mv	s2,a2
    return -1;

  if(f->type == FD_PIPE){
    80004e88:	411c                	lw	a5,0(a0)
    80004e8a:	4705                	li	a4,1
    80004e8c:	04e78963          	beq	a5,a4,80004ede <fileread+0x70>
    r = piperead(f->pipe, addr, n);
  } else if(f->type == FD_DEVICE){
    80004e90:	470d                	li	a4,3
    80004e92:	04e78f63          	beq	a5,a4,80004ef0 <fileread+0x82>
    if(f->major < 0 || f->major >= NDEV || !devsw[f->major].read)
      return -1;
    r = devsw[f->major].read(1, addr, n);
  } else if(f->type == FD_INODE){
    80004e96:	4709                	li	a4,2
    80004e98:	08e79263          	bne	a5,a4,80004f1c <fileread+0xae>
    ilock(f->ip);
    80004e9c:	6d08                	ld	a0,24(a0)
    80004e9e:	fffff097          	auipc	ra,0xfffff
    80004ea2:	fe0080e7          	jalr	-32(ra) # 80003e7e <ilock>
    if((r = readi(f->ip, 1, addr, f->off, n)) > 0)
    80004ea6:	874a                	mv	a4,s2
    80004ea8:	5094                	lw	a3,32(s1)
    80004eaa:	864e                	mv	a2,s3
    80004eac:	4585                	li	a1,1
    80004eae:	6c88                	ld	a0,24(s1)
    80004eb0:	fffff097          	auipc	ra,0xfffff
    80004eb4:	286080e7          	jalr	646(ra) # 80004136 <readi>
    80004eb8:	892a                	mv	s2,a0
    80004eba:	00a05563          	blez	a0,80004ec4 <fileread+0x56>
      f->off += r;
    80004ebe:	509c                	lw	a5,32(s1)
    80004ec0:	9fa9                	addw	a5,a5,a0
    80004ec2:	d09c                	sw	a5,32(s1)
    iunlock(f->ip);
    80004ec4:	6c88                	ld	a0,24(s1)
    80004ec6:	fffff097          	auipc	ra,0xfffff
    80004eca:	07e080e7          	jalr	126(ra) # 80003f44 <iunlock>
    80004ece:	64e2                	ld	s1,24(sp)
    80004ed0:	69a2                	ld	s3,8(sp)
  } else {
    panic("fileread");
  }

  return r;
}
    80004ed2:	854a                	mv	a0,s2
    80004ed4:	70a2                	ld	ra,40(sp)
    80004ed6:	7402                	ld	s0,32(sp)
    80004ed8:	6942                	ld	s2,16(sp)
    80004eda:	6145                	addi	sp,sp,48
    80004edc:	8082                	ret
    r = piperead(f->pipe, addr, n);
    80004ede:	6908                	ld	a0,16(a0)
    80004ee0:	00000097          	auipc	ra,0x0
    80004ee4:	400080e7          	jalr	1024(ra) # 800052e0 <piperead>
    80004ee8:	892a                	mv	s2,a0
    80004eea:	64e2                	ld	s1,24(sp)
    80004eec:	69a2                	ld	s3,8(sp)
    80004eee:	b7d5                	j	80004ed2 <fileread+0x64>
    if(f->major < 0 || f->major >= NDEV || !devsw[f->major].read)
    80004ef0:	02451783          	lh	a5,36(a0)
    80004ef4:	03079693          	slli	a3,a5,0x30
    80004ef8:	92c1                	srli	a3,a3,0x30
    80004efa:	4725                	li	a4,9
    80004efc:	02d76a63          	bltu	a4,a3,80004f30 <fileread+0xc2>
    80004f00:	0792                	slli	a5,a5,0x4
    80004f02:	00025717          	auipc	a4,0x25
    80004f06:	cc670713          	addi	a4,a4,-826 # 80029bc8 <devsw>
    80004f0a:	97ba                	add	a5,a5,a4
    80004f0c:	639c                	ld	a5,0(a5)
    80004f0e:	c78d                	beqz	a5,80004f38 <fileread+0xca>
    r = devsw[f->major].read(1, addr, n);
    80004f10:	4505                	li	a0,1
    80004f12:	9782                	jalr	a5
    80004f14:	892a                	mv	s2,a0
    80004f16:	64e2                	ld	s1,24(sp)
    80004f18:	69a2                	ld	s3,8(sp)
    80004f1a:	bf65                	j	80004ed2 <fileread+0x64>
    panic("fileread");
    80004f1c:	00003517          	auipc	a0,0x3
    80004f20:	67450513          	addi	a0,a0,1652 # 80008590 <etext+0x590>
    80004f24:	ffffb097          	auipc	ra,0xffffb
    80004f28:	63c080e7          	jalr	1596(ra) # 80000560 <panic>
    return -1;
    80004f2c:	597d                	li	s2,-1
    80004f2e:	b755                	j	80004ed2 <fileread+0x64>
      return -1;
    80004f30:	597d                	li	s2,-1
    80004f32:	64e2                	ld	s1,24(sp)
    80004f34:	69a2                	ld	s3,8(sp)
    80004f36:	bf71                	j	80004ed2 <fileread+0x64>
    80004f38:	597d                	li	s2,-1
    80004f3a:	64e2                	ld	s1,24(sp)
    80004f3c:	69a2                	ld	s3,8(sp)
    80004f3e:	bf51                	j	80004ed2 <fileread+0x64>

0000000080004f40 <filewrite>:
int
filewrite(struct file *f, uint64 addr, int n)
{
  int r, ret = 0;

  if(f->writable == 0)
    80004f40:	00954783          	lbu	a5,9(a0)
    80004f44:	12078963          	beqz	a5,80005076 <filewrite+0x136>
{
    80004f48:	715d                	addi	sp,sp,-80
    80004f4a:	e486                	sd	ra,72(sp)
    80004f4c:	e0a2                	sd	s0,64(sp)
    80004f4e:	f84a                	sd	s2,48(sp)
    80004f50:	f052                	sd	s4,32(sp)
    80004f52:	e85a                	sd	s6,16(sp)
    80004f54:	0880                	addi	s0,sp,80
    80004f56:	892a                	mv	s2,a0
    80004f58:	8b2e                	mv	s6,a1
    80004f5a:	8a32                	mv	s4,a2
    return -1;

  if(f->type == FD_PIPE){
    80004f5c:	411c                	lw	a5,0(a0)
    80004f5e:	4705                	li	a4,1
    80004f60:	02e78763          	beq	a5,a4,80004f8e <filewrite+0x4e>
    ret = pipewrite(f->pipe, addr, n);
  } else if(f->type == FD_DEVICE){
    80004f64:	470d                	li	a4,3
    80004f66:	02e78a63          	beq	a5,a4,80004f9a <filewrite+0x5a>
    if(f->major < 0 || f->major >= NDEV || !devsw[f->major].write)
      return -1;
    ret = devsw[f->major].write(1, addr, n);
  } else if(f->type == FD_INODE){
    80004f6a:	4709                	li	a4,2
    80004f6c:	0ee79863          	bne	a5,a4,8000505c <filewrite+0x11c>
    80004f70:	f44e                	sd	s3,40(sp)
    // and 2 blocks of slop for non-aligned writes.
    // this really belongs lower down, since writei()
    // might be writing a device like the console.
    int max = ((MAXOPBLOCKS-1-1-2) / 2) * BSIZE;
    int i = 0;
    while(i < n){
    80004f72:	0cc05463          	blez	a2,8000503a <filewrite+0xfa>
    80004f76:	fc26                	sd	s1,56(sp)
    80004f78:	ec56                	sd	s5,24(sp)
    80004f7a:	e45e                	sd	s7,8(sp)
    80004f7c:	e062                	sd	s8,0(sp)
    int i = 0;
    80004f7e:	4981                	li	s3,0
      int n1 = n - i;
      if(n1 > max)
    80004f80:	6b85                	lui	s7,0x1
    80004f82:	c00b8b93          	addi	s7,s7,-1024 # c00 <_entry-0x7ffff400>
    80004f86:	6c05                	lui	s8,0x1
    80004f88:	c00c0c1b          	addiw	s8,s8,-1024 # c00 <_entry-0x7ffff400>
    80004f8c:	a851                	j	80005020 <filewrite+0xe0>
    ret = pipewrite(f->pipe, addr, n);
    80004f8e:	6908                	ld	a0,16(a0)
    80004f90:	00000097          	auipc	ra,0x0
    80004f94:	248080e7          	jalr	584(ra) # 800051d8 <pipewrite>
    80004f98:	a85d                	j	8000504e <filewrite+0x10e>
    if(f->major < 0 || f->major >= NDEV || !devsw[f->major].write)
    80004f9a:	02451783          	lh	a5,36(a0)
    80004f9e:	03079693          	slli	a3,a5,0x30
    80004fa2:	92c1                	srli	a3,a3,0x30
    80004fa4:	4725                	li	a4,9
    80004fa6:	0cd76a63          	bltu	a4,a3,8000507a <filewrite+0x13a>
    80004faa:	0792                	slli	a5,a5,0x4
    80004fac:	00025717          	auipc	a4,0x25
    80004fb0:	c1c70713          	addi	a4,a4,-996 # 80029bc8 <devsw>
    80004fb4:	97ba                	add	a5,a5,a4
    80004fb6:	679c                	ld	a5,8(a5)
    80004fb8:	c3f9                	beqz	a5,8000507e <filewrite+0x13e>
    ret = devsw[f->major].write(1, addr, n);
    80004fba:	4505                	li	a0,1
    80004fbc:	9782                	jalr	a5
    80004fbe:	a841                	j	8000504e <filewrite+0x10e>
      if(n1 > max)
    80004fc0:	00048a9b          	sext.w	s5,s1
        n1 = max;

      begin_op();
    80004fc4:	00000097          	auipc	ra,0x0
    80004fc8:	888080e7          	jalr	-1912(ra) # 8000484c <begin_op>
      ilock(f->ip);
    80004fcc:	01893503          	ld	a0,24(s2)
    80004fd0:	fffff097          	auipc	ra,0xfffff
    80004fd4:	eae080e7          	jalr	-338(ra) # 80003e7e <ilock>
      if ((r = writei(f->ip, 1, addr + i, f->off, n1)) > 0)
    80004fd8:	8756                	mv	a4,s5
    80004fda:	02092683          	lw	a3,32(s2)
    80004fde:	01698633          	add	a2,s3,s6
    80004fe2:	4585                	li	a1,1
    80004fe4:	01893503          	ld	a0,24(s2)
    80004fe8:	fffff097          	auipc	ra,0xfffff
    80004fec:	25e080e7          	jalr	606(ra) # 80004246 <writei>
    80004ff0:	84aa                	mv	s1,a0
    80004ff2:	00a05763          	blez	a0,80005000 <filewrite+0xc0>
        f->off += r;
    80004ff6:	02092783          	lw	a5,32(s2)
    80004ffa:	9fa9                	addw	a5,a5,a0
    80004ffc:	02f92023          	sw	a5,32(s2)
      iunlock(f->ip);
    80005000:	01893503          	ld	a0,24(s2)
    80005004:	fffff097          	auipc	ra,0xfffff
    80005008:	f40080e7          	jalr	-192(ra) # 80003f44 <iunlock>
      end_op();
    8000500c:	00000097          	auipc	ra,0x0
    80005010:	8ba080e7          	jalr	-1862(ra) # 800048c6 <end_op>

      if(r != n1){
    80005014:	029a9563          	bne	s5,s1,8000503e <filewrite+0xfe>
        // error from writei
        break;
      }
      i += r;
    80005018:	013489bb          	addw	s3,s1,s3
    while(i < n){
    8000501c:	0149da63          	bge	s3,s4,80005030 <filewrite+0xf0>
      int n1 = n - i;
    80005020:	413a04bb          	subw	s1,s4,s3
      if(n1 > max)
    80005024:	0004879b          	sext.w	a5,s1
    80005028:	f8fbdce3          	bge	s7,a5,80004fc0 <filewrite+0x80>
    8000502c:	84e2                	mv	s1,s8
    8000502e:	bf49                	j	80004fc0 <filewrite+0x80>
    80005030:	74e2                	ld	s1,56(sp)
    80005032:	6ae2                	ld	s5,24(sp)
    80005034:	6ba2                	ld	s7,8(sp)
    80005036:	6c02                	ld	s8,0(sp)
    80005038:	a039                	j	80005046 <filewrite+0x106>
    int i = 0;
    8000503a:	4981                	li	s3,0
    8000503c:	a029                	j	80005046 <filewrite+0x106>
    8000503e:	74e2                	ld	s1,56(sp)
    80005040:	6ae2                	ld	s5,24(sp)
    80005042:	6ba2                	ld	s7,8(sp)
    80005044:	6c02                	ld	s8,0(sp)
    }
    ret = (i == n ? n : -1);
    80005046:	033a1e63          	bne	s4,s3,80005082 <filewrite+0x142>
    8000504a:	8552                	mv	a0,s4
    8000504c:	79a2                	ld	s3,40(sp)
  } else {
    panic("filewrite");
  }

  return ret;
}
    8000504e:	60a6                	ld	ra,72(sp)
    80005050:	6406                	ld	s0,64(sp)
    80005052:	7942                	ld	s2,48(sp)
    80005054:	7a02                	ld	s4,32(sp)
    80005056:	6b42                	ld	s6,16(sp)
    80005058:	6161                	addi	sp,sp,80
    8000505a:	8082                	ret
    8000505c:	fc26                	sd	s1,56(sp)
    8000505e:	f44e                	sd	s3,40(sp)
    80005060:	ec56                	sd	s5,24(sp)
    80005062:	e45e                	sd	s7,8(sp)
    80005064:	e062                	sd	s8,0(sp)
    panic("filewrite");
    80005066:	00003517          	auipc	a0,0x3
    8000506a:	53a50513          	addi	a0,a0,1338 # 800085a0 <etext+0x5a0>
    8000506e:	ffffb097          	auipc	ra,0xffffb
    80005072:	4f2080e7          	jalr	1266(ra) # 80000560 <panic>
    return -1;
    80005076:	557d                	li	a0,-1
}
    80005078:	8082                	ret
      return -1;
    8000507a:	557d                	li	a0,-1
    8000507c:	bfc9                	j	8000504e <filewrite+0x10e>
    8000507e:	557d                	li	a0,-1
    80005080:	b7f9                	j	8000504e <filewrite+0x10e>
    ret = (i == n ? n : -1);
    80005082:	557d                	li	a0,-1
    80005084:	79a2                	ld	s3,40(sp)
    80005086:	b7e1                	j	8000504e <filewrite+0x10e>

0000000080005088 <pipealloc>:
  int writeopen;  // write fd is still open
};

int
pipealloc(struct file **f0, struct file **f1)
{
    80005088:	7179                	addi	sp,sp,-48
    8000508a:	f406                	sd	ra,40(sp)
    8000508c:	f022                	sd	s0,32(sp)
    8000508e:	ec26                	sd	s1,24(sp)
    80005090:	e052                	sd	s4,0(sp)
    80005092:	1800                	addi	s0,sp,48
    80005094:	84aa                	mv	s1,a0
    80005096:	8a2e                	mv	s4,a1
  struct pipe *pi;

  pi = 0;
  *f0 = *f1 = 0;
    80005098:	0005b023          	sd	zero,0(a1)
    8000509c:	00053023          	sd	zero,0(a0)
  if((*f0 = filealloc()) == 0 || (*f1 = filealloc()) == 0)
    800050a0:	00000097          	auipc	ra,0x0
    800050a4:	bbe080e7          	jalr	-1090(ra) # 80004c5e <filealloc>
    800050a8:	e088                	sd	a0,0(s1)
    800050aa:	cd49                	beqz	a0,80005144 <pipealloc+0xbc>
    800050ac:	00000097          	auipc	ra,0x0
    800050b0:	bb2080e7          	jalr	-1102(ra) # 80004c5e <filealloc>
    800050b4:	00aa3023          	sd	a0,0(s4)
    800050b8:	c141                	beqz	a0,80005138 <pipealloc+0xb0>
    800050ba:	e84a                	sd	s2,16(sp)
    goto bad;
  if((pi = (struct pipe*)kalloc()) == 0)
    800050bc:	ffffc097          	auipc	ra,0xffffc
    800050c0:	a8c080e7          	jalr	-1396(ra) # 80000b48 <kalloc>
    800050c4:	892a                	mv	s2,a0
    800050c6:	c13d                	beqz	a0,8000512c <pipealloc+0xa4>
    800050c8:	e44e                	sd	s3,8(sp)
    goto bad;
  pi->readopen = 1;
    800050ca:	4985                	li	s3,1
    800050cc:	23352023          	sw	s3,544(a0)
  pi->writeopen = 1;
    800050d0:	23352223          	sw	s3,548(a0)
  pi->nwrite = 0;
    800050d4:	20052e23          	sw	zero,540(a0)
  pi->nread = 0;
    800050d8:	20052c23          	sw	zero,536(a0)
  initlock(&pi->lock, "pipe");
    800050dc:	00003597          	auipc	a1,0x3
    800050e0:	4d458593          	addi	a1,a1,1236 # 800085b0 <etext+0x5b0>
    800050e4:	ffffc097          	auipc	ra,0xffffc
    800050e8:	ac4080e7          	jalr	-1340(ra) # 80000ba8 <initlock>
  (*f0)->type = FD_PIPE;
    800050ec:	609c                	ld	a5,0(s1)
    800050ee:	0137a023          	sw	s3,0(a5)
  (*f0)->readable = 1;
    800050f2:	609c                	ld	a5,0(s1)
    800050f4:	01378423          	sb	s3,8(a5)
  (*f0)->writable = 0;
    800050f8:	609c                	ld	a5,0(s1)
    800050fa:	000784a3          	sb	zero,9(a5)
  (*f0)->pipe = pi;
    800050fe:	609c                	ld	a5,0(s1)
    80005100:	0127b823          	sd	s2,16(a5)
  (*f1)->type = FD_PIPE;
    80005104:	000a3783          	ld	a5,0(s4)
    80005108:	0137a023          	sw	s3,0(a5)
  (*f1)->readable = 0;
    8000510c:	000a3783          	ld	a5,0(s4)
    80005110:	00078423          	sb	zero,8(a5)
  (*f1)->writable = 1;
    80005114:	000a3783          	ld	a5,0(s4)
    80005118:	013784a3          	sb	s3,9(a5)
  (*f1)->pipe = pi;
    8000511c:	000a3783          	ld	a5,0(s4)
    80005120:	0127b823          	sd	s2,16(a5)
  return 0;
    80005124:	4501                	li	a0,0
    80005126:	6942                	ld	s2,16(sp)
    80005128:	69a2                	ld	s3,8(sp)
    8000512a:	a03d                	j	80005158 <pipealloc+0xd0>

 bad:
  if(pi)
    kfree((char*)pi);
  if(*f0)
    8000512c:	6088                	ld	a0,0(s1)
    8000512e:	c119                	beqz	a0,80005134 <pipealloc+0xac>
    80005130:	6942                	ld	s2,16(sp)
    80005132:	a029                	j	8000513c <pipealloc+0xb4>
    80005134:	6942                	ld	s2,16(sp)
    80005136:	a039                	j	80005144 <pipealloc+0xbc>
    80005138:	6088                	ld	a0,0(s1)
    8000513a:	c50d                	beqz	a0,80005164 <pipealloc+0xdc>
    fileclose(*f0);
    8000513c:	00000097          	auipc	ra,0x0
    80005140:	bde080e7          	jalr	-1058(ra) # 80004d1a <fileclose>
  if(*f1)
    80005144:	000a3783          	ld	a5,0(s4)
    fileclose(*f1);
  return -1;
    80005148:	557d                	li	a0,-1
  if(*f1)
    8000514a:	c799                	beqz	a5,80005158 <pipealloc+0xd0>
    fileclose(*f1);
    8000514c:	853e                	mv	a0,a5
    8000514e:	00000097          	auipc	ra,0x0
    80005152:	bcc080e7          	jalr	-1076(ra) # 80004d1a <fileclose>
  return -1;
    80005156:	557d                	li	a0,-1
}
    80005158:	70a2                	ld	ra,40(sp)
    8000515a:	7402                	ld	s0,32(sp)
    8000515c:	64e2                	ld	s1,24(sp)
    8000515e:	6a02                	ld	s4,0(sp)
    80005160:	6145                	addi	sp,sp,48
    80005162:	8082                	ret
  return -1;
    80005164:	557d                	li	a0,-1
    80005166:	bfcd                	j	80005158 <pipealloc+0xd0>

0000000080005168 <pipeclose>:

void
pipeclose(struct pipe *pi, int writable)
{
    80005168:	1101                	addi	sp,sp,-32
    8000516a:	ec06                	sd	ra,24(sp)
    8000516c:	e822                	sd	s0,16(sp)
    8000516e:	e426                	sd	s1,8(sp)
    80005170:	e04a                	sd	s2,0(sp)
    80005172:	1000                	addi	s0,sp,32
    80005174:	84aa                	mv	s1,a0
    80005176:	892e                	mv	s2,a1
  acquire(&pi->lock);
    80005178:	ffffc097          	auipc	ra,0xffffc
    8000517c:	ac0080e7          	jalr	-1344(ra) # 80000c38 <acquire>
  if(writable){
    80005180:	02090d63          	beqz	s2,800051ba <pipeclose+0x52>
    pi->writeopen = 0;
    80005184:	2204a223          	sw	zero,548(s1)
    wakeup(&pi->nread);
    80005188:	21848513          	addi	a0,s1,536
    8000518c:	ffffd097          	auipc	ra,0xffffd
    80005190:	2a2080e7          	jalr	674(ra) # 8000242e <wakeup>
  } else {
    pi->readopen = 0;
    wakeup(&pi->nwrite);
  }
  if(pi->readopen == 0 && pi->writeopen == 0){
    80005194:	2204b783          	ld	a5,544(s1)
    80005198:	eb95                	bnez	a5,800051cc <pipeclose+0x64>
    release(&pi->lock);
    8000519a:	8526                	mv	a0,s1
    8000519c:	ffffc097          	auipc	ra,0xffffc
    800051a0:	b50080e7          	jalr	-1200(ra) # 80000cec <release>
    kfree((char*)pi);
    800051a4:	8526                	mv	a0,s1
    800051a6:	ffffc097          	auipc	ra,0xffffc
    800051aa:	8a4080e7          	jalr	-1884(ra) # 80000a4a <kfree>
  } else
    release(&pi->lock);
}
    800051ae:	60e2                	ld	ra,24(sp)
    800051b0:	6442                	ld	s0,16(sp)
    800051b2:	64a2                	ld	s1,8(sp)
    800051b4:	6902                	ld	s2,0(sp)
    800051b6:	6105                	addi	sp,sp,32
    800051b8:	8082                	ret
    pi->readopen = 0;
    800051ba:	2204a023          	sw	zero,544(s1)
    wakeup(&pi->nwrite);
    800051be:	21c48513          	addi	a0,s1,540
    800051c2:	ffffd097          	auipc	ra,0xffffd
    800051c6:	26c080e7          	jalr	620(ra) # 8000242e <wakeup>
    800051ca:	b7e9                	j	80005194 <pipeclose+0x2c>
    release(&pi->lock);
    800051cc:	8526                	mv	a0,s1
    800051ce:	ffffc097          	auipc	ra,0xffffc
    800051d2:	b1e080e7          	jalr	-1250(ra) # 80000cec <release>
}
    800051d6:	bfe1                	j	800051ae <pipeclose+0x46>

00000000800051d8 <pipewrite>:

int
pipewrite(struct pipe *pi, uint64 addr, int n)
{
    800051d8:	711d                	addi	sp,sp,-96
    800051da:	ec86                	sd	ra,88(sp)
    800051dc:	e8a2                	sd	s0,80(sp)
    800051de:	e4a6                	sd	s1,72(sp)
    800051e0:	e0ca                	sd	s2,64(sp)
    800051e2:	fc4e                	sd	s3,56(sp)
    800051e4:	f852                	sd	s4,48(sp)
    800051e6:	f456                	sd	s5,40(sp)
    800051e8:	1080                	addi	s0,sp,96
    800051ea:	84aa                	mv	s1,a0
    800051ec:	8aae                	mv	s5,a1
    800051ee:	8a32                	mv	s4,a2
  int i = 0;
  struct proc *pr = myproc();
    800051f0:	ffffd097          	auipc	ra,0xffffd
    800051f4:	a44080e7          	jalr	-1468(ra) # 80001c34 <myproc>
    800051f8:	89aa                	mv	s3,a0

  acquire(&pi->lock);
    800051fa:	8526                	mv	a0,s1
    800051fc:	ffffc097          	auipc	ra,0xffffc
    80005200:	a3c080e7          	jalr	-1476(ra) # 80000c38 <acquire>
  while(i < n){
    80005204:	0d405863          	blez	s4,800052d4 <pipewrite+0xfc>
    80005208:	f05a                	sd	s6,32(sp)
    8000520a:	ec5e                	sd	s7,24(sp)
    8000520c:	e862                	sd	s8,16(sp)
  int i = 0;
    8000520e:	4901                	li	s2,0
    if(pi->nwrite == pi->nread + PIPESIZE){ //DOC: pipewrite-full
      wakeup(&pi->nread);
      sleep(&pi->nwrite, &pi->lock);
    } else {
      char ch;
      if(copyin(pr->pagetable, &ch, addr + i, 1) == -1)
    80005210:	5b7d                	li	s6,-1
      wakeup(&pi->nread);
    80005212:	21848c13          	addi	s8,s1,536
      sleep(&pi->nwrite, &pi->lock);
    80005216:	21c48b93          	addi	s7,s1,540
    8000521a:	a089                	j	8000525c <pipewrite+0x84>
      release(&pi->lock);
    8000521c:	8526                	mv	a0,s1
    8000521e:	ffffc097          	auipc	ra,0xffffc
    80005222:	ace080e7          	jalr	-1330(ra) # 80000cec <release>
      return -1;
    80005226:	597d                	li	s2,-1
    80005228:	7b02                	ld	s6,32(sp)
    8000522a:	6be2                	ld	s7,24(sp)
    8000522c:	6c42                	ld	s8,16(sp)
  }
  wakeup(&pi->nread);
  release(&pi->lock);

  return i;
}
    8000522e:	854a                	mv	a0,s2
    80005230:	60e6                	ld	ra,88(sp)
    80005232:	6446                	ld	s0,80(sp)
    80005234:	64a6                	ld	s1,72(sp)
    80005236:	6906                	ld	s2,64(sp)
    80005238:	79e2                	ld	s3,56(sp)
    8000523a:	7a42                	ld	s4,48(sp)
    8000523c:	7aa2                	ld	s5,40(sp)
    8000523e:	6125                	addi	sp,sp,96
    80005240:	8082                	ret
      wakeup(&pi->nread);
    80005242:	8562                	mv	a0,s8
    80005244:	ffffd097          	auipc	ra,0xffffd
    80005248:	1ea080e7          	jalr	490(ra) # 8000242e <wakeup>
      sleep(&pi->nwrite, &pi->lock);
    8000524c:	85a6                	mv	a1,s1
    8000524e:	855e                	mv	a0,s7
    80005250:	ffffd097          	auipc	ra,0xffffd
    80005254:	16e080e7          	jalr	366(ra) # 800023be <sleep>
  while(i < n){
    80005258:	05495f63          	bge	s2,s4,800052b6 <pipewrite+0xde>
    if(pi->readopen == 0 || killed(pr)){
    8000525c:	2204a783          	lw	a5,544(s1)
    80005260:	dfd5                	beqz	a5,8000521c <pipewrite+0x44>
    80005262:	854e                	mv	a0,s3
    80005264:	ffffd097          	auipc	ra,0xffffd
    80005268:	448080e7          	jalr	1096(ra) # 800026ac <killed>
    8000526c:	f945                	bnez	a0,8000521c <pipewrite+0x44>
    if(pi->nwrite == pi->nread + PIPESIZE){ //DOC: pipewrite-full
    8000526e:	2184a783          	lw	a5,536(s1)
    80005272:	21c4a703          	lw	a4,540(s1)
    80005276:	2007879b          	addiw	a5,a5,512
    8000527a:	fcf704e3          	beq	a4,a5,80005242 <pipewrite+0x6a>
      if(copyin(pr->pagetable, &ch, addr + i, 1) == -1)
    8000527e:	4685                	li	a3,1
    80005280:	01590633          	add	a2,s2,s5
    80005284:	faf40593          	addi	a1,s0,-81
    80005288:	1709b503          	ld	a0,368(s3)
    8000528c:	ffffc097          	auipc	ra,0xffffc
    80005290:	4e2080e7          	jalr	1250(ra) # 8000176e <copyin>
    80005294:	05650263          	beq	a0,s6,800052d8 <pipewrite+0x100>
      pi->data[pi->nwrite++ % PIPESIZE] = ch;
    80005298:	21c4a783          	lw	a5,540(s1)
    8000529c:	0017871b          	addiw	a4,a5,1
    800052a0:	20e4ae23          	sw	a4,540(s1)
    800052a4:	1ff7f793          	andi	a5,a5,511
    800052a8:	97a6                	add	a5,a5,s1
    800052aa:	faf44703          	lbu	a4,-81(s0)
    800052ae:	00e78c23          	sb	a4,24(a5)
      i++;
    800052b2:	2905                	addiw	s2,s2,1
    800052b4:	b755                	j	80005258 <pipewrite+0x80>
    800052b6:	7b02                	ld	s6,32(sp)
    800052b8:	6be2                	ld	s7,24(sp)
    800052ba:	6c42                	ld	s8,16(sp)
  wakeup(&pi->nread);
    800052bc:	21848513          	addi	a0,s1,536
    800052c0:	ffffd097          	auipc	ra,0xffffd
    800052c4:	16e080e7          	jalr	366(ra) # 8000242e <wakeup>
  release(&pi->lock);
    800052c8:	8526                	mv	a0,s1
    800052ca:	ffffc097          	auipc	ra,0xffffc
    800052ce:	a22080e7          	jalr	-1502(ra) # 80000cec <release>
  return i;
    800052d2:	bfb1                	j	8000522e <pipewrite+0x56>
  int i = 0;
    800052d4:	4901                	li	s2,0
    800052d6:	b7dd                	j	800052bc <pipewrite+0xe4>
    800052d8:	7b02                	ld	s6,32(sp)
    800052da:	6be2                	ld	s7,24(sp)
    800052dc:	6c42                	ld	s8,16(sp)
    800052de:	bff9                	j	800052bc <pipewrite+0xe4>

00000000800052e0 <piperead>:

int
piperead(struct pipe *pi, uint64 addr, int n)
{
    800052e0:	715d                	addi	sp,sp,-80
    800052e2:	e486                	sd	ra,72(sp)
    800052e4:	e0a2                	sd	s0,64(sp)
    800052e6:	fc26                	sd	s1,56(sp)
    800052e8:	f84a                	sd	s2,48(sp)
    800052ea:	f44e                	sd	s3,40(sp)
    800052ec:	f052                	sd	s4,32(sp)
    800052ee:	ec56                	sd	s5,24(sp)
    800052f0:	0880                	addi	s0,sp,80
    800052f2:	84aa                	mv	s1,a0
    800052f4:	892e                	mv	s2,a1
    800052f6:	8ab2                	mv	s5,a2
  int i;
  struct proc *pr = myproc();
    800052f8:	ffffd097          	auipc	ra,0xffffd
    800052fc:	93c080e7          	jalr	-1732(ra) # 80001c34 <myproc>
    80005300:	8a2a                	mv	s4,a0
  char ch;

  acquire(&pi->lock);
    80005302:	8526                	mv	a0,s1
    80005304:	ffffc097          	auipc	ra,0xffffc
    80005308:	934080e7          	jalr	-1740(ra) # 80000c38 <acquire>
  while(pi->nread == pi->nwrite && pi->writeopen){  //DOC: pipe-empty
    8000530c:	2184a703          	lw	a4,536(s1)
    80005310:	21c4a783          	lw	a5,540(s1)
    if(killed(pr)){
      release(&pi->lock);
      return -1;
    }
    sleep(&pi->nread, &pi->lock); //DOC: piperead-sleep
    80005314:	21848993          	addi	s3,s1,536
  while(pi->nread == pi->nwrite && pi->writeopen){  //DOC: pipe-empty
    80005318:	02f71963          	bne	a4,a5,8000534a <piperead+0x6a>
    8000531c:	2244a783          	lw	a5,548(s1)
    80005320:	cf95                	beqz	a5,8000535c <piperead+0x7c>
    if(killed(pr)){
    80005322:	8552                	mv	a0,s4
    80005324:	ffffd097          	auipc	ra,0xffffd
    80005328:	388080e7          	jalr	904(ra) # 800026ac <killed>
    8000532c:	e10d                	bnez	a0,8000534e <piperead+0x6e>
    sleep(&pi->nread, &pi->lock); //DOC: piperead-sleep
    8000532e:	85a6                	mv	a1,s1
    80005330:	854e                	mv	a0,s3
    80005332:	ffffd097          	auipc	ra,0xffffd
    80005336:	08c080e7          	jalr	140(ra) # 800023be <sleep>
  while(pi->nread == pi->nwrite && pi->writeopen){  //DOC: pipe-empty
    8000533a:	2184a703          	lw	a4,536(s1)
    8000533e:	21c4a783          	lw	a5,540(s1)
    80005342:	fcf70de3          	beq	a4,a5,8000531c <piperead+0x3c>
    80005346:	e85a                	sd	s6,16(sp)
    80005348:	a819                	j	8000535e <piperead+0x7e>
    8000534a:	e85a                	sd	s6,16(sp)
    8000534c:	a809                	j	8000535e <piperead+0x7e>
      release(&pi->lock);
    8000534e:	8526                	mv	a0,s1
    80005350:	ffffc097          	auipc	ra,0xffffc
    80005354:	99c080e7          	jalr	-1636(ra) # 80000cec <release>
      return -1;
    80005358:	59fd                	li	s3,-1
    8000535a:	a0a5                	j	800053c2 <piperead+0xe2>
    8000535c:	e85a                	sd	s6,16(sp)
  }
  for(i = 0; i < n; i++){  //DOC: piperead-copy
    8000535e:	4981                	li	s3,0
    if(pi->nread == pi->nwrite)
      break;
    ch = pi->data[pi->nread++ % PIPESIZE];
    if(copyout(pr->pagetable, addr + i, &ch, 1) == -1)
    80005360:	5b7d                	li	s6,-1
  for(i = 0; i < n; i++){  //DOC: piperead-copy
    80005362:	05505463          	blez	s5,800053aa <piperead+0xca>
    if(pi->nread == pi->nwrite)
    80005366:	2184a783          	lw	a5,536(s1)
    8000536a:	21c4a703          	lw	a4,540(s1)
    8000536e:	02f70e63          	beq	a4,a5,800053aa <piperead+0xca>
    ch = pi->data[pi->nread++ % PIPESIZE];
    80005372:	0017871b          	addiw	a4,a5,1
    80005376:	20e4ac23          	sw	a4,536(s1)
    8000537a:	1ff7f793          	andi	a5,a5,511
    8000537e:	97a6                	add	a5,a5,s1
    80005380:	0187c783          	lbu	a5,24(a5)
    80005384:	faf40fa3          	sb	a5,-65(s0)
    if(copyout(pr->pagetable, addr + i, &ch, 1) == -1)
    80005388:	4685                	li	a3,1
    8000538a:	fbf40613          	addi	a2,s0,-65
    8000538e:	85ca                	mv	a1,s2
    80005390:	170a3503          	ld	a0,368(s4)
    80005394:	ffffc097          	auipc	ra,0xffffc
    80005398:	34e080e7          	jalr	846(ra) # 800016e2 <copyout>
    8000539c:	01650763          	beq	a0,s6,800053aa <piperead+0xca>
  for(i = 0; i < n; i++){  //DOC: piperead-copy
    800053a0:	2985                	addiw	s3,s3,1
    800053a2:	0905                	addi	s2,s2,1
    800053a4:	fd3a91e3          	bne	s5,s3,80005366 <piperead+0x86>
    800053a8:	89d6                	mv	s3,s5
      break;
  }
  wakeup(&pi->nwrite);  //DOC: piperead-wakeup
    800053aa:	21c48513          	addi	a0,s1,540
    800053ae:	ffffd097          	auipc	ra,0xffffd
    800053b2:	080080e7          	jalr	128(ra) # 8000242e <wakeup>
  release(&pi->lock);
    800053b6:	8526                	mv	a0,s1
    800053b8:	ffffc097          	auipc	ra,0xffffc
    800053bc:	934080e7          	jalr	-1740(ra) # 80000cec <release>
    800053c0:	6b42                	ld	s6,16(sp)
  return i;
}
    800053c2:	854e                	mv	a0,s3
    800053c4:	60a6                	ld	ra,72(sp)
    800053c6:	6406                	ld	s0,64(sp)
    800053c8:	74e2                	ld	s1,56(sp)
    800053ca:	7942                	ld	s2,48(sp)
    800053cc:	79a2                	ld	s3,40(sp)
    800053ce:	7a02                	ld	s4,32(sp)
    800053d0:	6ae2                	ld	s5,24(sp)
    800053d2:	6161                	addi	sp,sp,80
    800053d4:	8082                	ret

00000000800053d6 <flags2perm>:
#include "elf.h"

static int loadseg(pde_t *, uint64, struct inode *, uint, uint);

int flags2perm(int flags)
{
    800053d6:	1141                	addi	sp,sp,-16
    800053d8:	e422                	sd	s0,8(sp)
    800053da:	0800                	addi	s0,sp,16
    800053dc:	87aa                	mv	a5,a0
    int perm = 0;
    if(flags & 0x1)
    800053de:	8905                	andi	a0,a0,1
    800053e0:	050e                	slli	a0,a0,0x3
      perm = PTE_X;
    if(flags & 0x2)
    800053e2:	8b89                	andi	a5,a5,2
    800053e4:	c399                	beqz	a5,800053ea <flags2perm+0x14>
      perm |= PTE_W;
    800053e6:	00456513          	ori	a0,a0,4
    return perm;
}
    800053ea:	6422                	ld	s0,8(sp)
    800053ec:	0141                	addi	sp,sp,16
    800053ee:	8082                	ret

00000000800053f0 <exec>:

int
exec(char *path, char **argv)
{
    800053f0:	df010113          	addi	sp,sp,-528
    800053f4:	20113423          	sd	ra,520(sp)
    800053f8:	20813023          	sd	s0,512(sp)
    800053fc:	ffa6                	sd	s1,504(sp)
    800053fe:	fbca                	sd	s2,496(sp)
    80005400:	0c00                	addi	s0,sp,528
    80005402:	892a                	mv	s2,a0
    80005404:	dea43c23          	sd	a0,-520(s0)
    80005408:	e0b43023          	sd	a1,-512(s0)
  uint64 argc, sz = 0, sp, ustack[MAXARG], stackbase;
  struct elfhdr elf;
  struct inode *ip;
  struct proghdr ph;
  pagetable_t pagetable = 0, oldpagetable;
  struct proc *p = myproc();
    8000540c:	ffffd097          	auipc	ra,0xffffd
    80005410:	828080e7          	jalr	-2008(ra) # 80001c34 <myproc>
    80005414:	84aa                	mv	s1,a0

  begin_op();
    80005416:	fffff097          	auipc	ra,0xfffff
    8000541a:	436080e7          	jalr	1078(ra) # 8000484c <begin_op>

  if((ip = namei(path)) == 0){
    8000541e:	854a                	mv	a0,s2
    80005420:	fffff097          	auipc	ra,0xfffff
    80005424:	22c080e7          	jalr	556(ra) # 8000464c <namei>
    80005428:	c135                	beqz	a0,8000548c <exec+0x9c>
    8000542a:	f3d2                	sd	s4,480(sp)
    8000542c:	8a2a                	mv	s4,a0
    end_op();
    return -1;
  }
  ilock(ip);
    8000542e:	fffff097          	auipc	ra,0xfffff
    80005432:	a50080e7          	jalr	-1456(ra) # 80003e7e <ilock>

  // Check ELF header
  if(readi(ip, 0, (uint64)&elf, 0, sizeof(elf)) != sizeof(elf))
    80005436:	04000713          	li	a4,64
    8000543a:	4681                	li	a3,0
    8000543c:	e5040613          	addi	a2,s0,-432
    80005440:	4581                	li	a1,0
    80005442:	8552                	mv	a0,s4
    80005444:	fffff097          	auipc	ra,0xfffff
    80005448:	cf2080e7          	jalr	-782(ra) # 80004136 <readi>
    8000544c:	04000793          	li	a5,64
    80005450:	00f51a63          	bne	a0,a5,80005464 <exec+0x74>
    goto bad;

  if(elf.magic != ELF_MAGIC)
    80005454:	e5042703          	lw	a4,-432(s0)
    80005458:	464c47b7          	lui	a5,0x464c4
    8000545c:	57f78793          	addi	a5,a5,1407 # 464c457f <_entry-0x39b3ba81>
    80005460:	02f70c63          	beq	a4,a5,80005498 <exec+0xa8>

 bad:
  if(pagetable)
    proc_freepagetable(pagetable, sz);
  if(ip){
    iunlockput(ip);
    80005464:	8552                	mv	a0,s4
    80005466:	fffff097          	auipc	ra,0xfffff
    8000546a:	c7e080e7          	jalr	-898(ra) # 800040e4 <iunlockput>
    end_op();
    8000546e:	fffff097          	auipc	ra,0xfffff
    80005472:	458080e7          	jalr	1112(ra) # 800048c6 <end_op>
  }
  return -1;
    80005476:	557d                	li	a0,-1
    80005478:	7a1e                	ld	s4,480(sp)
}
    8000547a:	20813083          	ld	ra,520(sp)
    8000547e:	20013403          	ld	s0,512(sp)
    80005482:	74fe                	ld	s1,504(sp)
    80005484:	795e                	ld	s2,496(sp)
    80005486:	21010113          	addi	sp,sp,528
    8000548a:	8082                	ret
    end_op();
    8000548c:	fffff097          	auipc	ra,0xfffff
    80005490:	43a080e7          	jalr	1082(ra) # 800048c6 <end_op>
    return -1;
    80005494:	557d                	li	a0,-1
    80005496:	b7d5                	j	8000547a <exec+0x8a>
    80005498:	ebda                	sd	s6,464(sp)
  if((pagetable = proc_pagetable(p)) == 0)
    8000549a:	8526                	mv	a0,s1
    8000549c:	ffffd097          	auipc	ra,0xffffd
    800054a0:	860080e7          	jalr	-1952(ra) # 80001cfc <proc_pagetable>
    800054a4:	8b2a                	mv	s6,a0
    800054a6:	30050f63          	beqz	a0,800057c4 <exec+0x3d4>
    800054aa:	f7ce                	sd	s3,488(sp)
    800054ac:	efd6                	sd	s5,472(sp)
    800054ae:	e7de                	sd	s7,456(sp)
    800054b0:	e3e2                	sd	s8,448(sp)
    800054b2:	ff66                	sd	s9,440(sp)
    800054b4:	fb6a                	sd	s10,432(sp)
  for(i=0, off=elf.phoff; i<elf.phnum; i++, off+=sizeof(ph)){
    800054b6:	e7042d03          	lw	s10,-400(s0)
    800054ba:	e8845783          	lhu	a5,-376(s0)
    800054be:	14078d63          	beqz	a5,80005618 <exec+0x228>
    800054c2:	f76e                	sd	s11,424(sp)
  uint64 argc, sz = 0, sp, ustack[MAXARG], stackbase;
    800054c4:	4901                	li	s2,0
  for(i=0, off=elf.phoff; i<elf.phnum; i++, off+=sizeof(ph)){
    800054c6:	4d81                	li	s11,0
    if(ph.vaddr % PGSIZE != 0)
    800054c8:	6c85                	lui	s9,0x1
    800054ca:	fffc8793          	addi	a5,s9,-1 # fff <_entry-0x7ffff001>
    800054ce:	def43823          	sd	a5,-528(s0)

  for(i = 0; i < sz; i += PGSIZE){
    pa = walkaddr(pagetable, va + i);
    if(pa == 0)
      panic("loadseg: address should exist");
    if(sz - i < PGSIZE)
    800054d2:	6a85                	lui	s5,0x1
    800054d4:	a0b5                	j	80005540 <exec+0x150>
      panic("loadseg: address should exist");
    800054d6:	00003517          	auipc	a0,0x3
    800054da:	0e250513          	addi	a0,a0,226 # 800085b8 <etext+0x5b8>
    800054de:	ffffb097          	auipc	ra,0xffffb
    800054e2:	082080e7          	jalr	130(ra) # 80000560 <panic>
    if(sz - i < PGSIZE)
    800054e6:	2481                	sext.w	s1,s1
      n = sz - i;
    else
      n = PGSIZE;
    if(readi(ip, 0, (uint64)pa, offset+i, n) != n)
    800054e8:	8726                	mv	a4,s1
    800054ea:	012c06bb          	addw	a3,s8,s2
    800054ee:	4581                	li	a1,0
    800054f0:	8552                	mv	a0,s4
    800054f2:	fffff097          	auipc	ra,0xfffff
    800054f6:	c44080e7          	jalr	-956(ra) # 80004136 <readi>
    800054fa:	2501                	sext.w	a0,a0
    800054fc:	28a49863          	bne	s1,a0,8000578c <exec+0x39c>
  for(i = 0; i < sz; i += PGSIZE){
    80005500:	012a893b          	addw	s2,s5,s2
    80005504:	03397563          	bgeu	s2,s3,8000552e <exec+0x13e>
    pa = walkaddr(pagetable, va + i);
    80005508:	02091593          	slli	a1,s2,0x20
    8000550c:	9181                	srli	a1,a1,0x20
    8000550e:	95de                	add	a1,a1,s7
    80005510:	855a                	mv	a0,s6
    80005512:	ffffc097          	auipc	ra,0xffffc
    80005516:	ba4080e7          	jalr	-1116(ra) # 800010b6 <walkaddr>
    8000551a:	862a                	mv	a2,a0
    if(pa == 0)
    8000551c:	dd4d                	beqz	a0,800054d6 <exec+0xe6>
    if(sz - i < PGSIZE)
    8000551e:	412984bb          	subw	s1,s3,s2
    80005522:	0004879b          	sext.w	a5,s1
    80005526:	fcfcf0e3          	bgeu	s9,a5,800054e6 <exec+0xf6>
    8000552a:	84d6                	mv	s1,s5
    8000552c:	bf6d                	j	800054e6 <exec+0xf6>
    sz = sz1;
    8000552e:	e0843903          	ld	s2,-504(s0)
  for(i=0, off=elf.phoff; i<elf.phnum; i++, off+=sizeof(ph)){
    80005532:	2d85                	addiw	s11,s11,1
    80005534:	038d0d1b          	addiw	s10,s10,56
    80005538:	e8845783          	lhu	a5,-376(s0)
    8000553c:	08fdd663          	bge	s11,a5,800055c8 <exec+0x1d8>
    if(readi(ip, 0, (uint64)&ph, off, sizeof(ph)) != sizeof(ph))
    80005540:	2d01                	sext.w	s10,s10
    80005542:	03800713          	li	a4,56
    80005546:	86ea                	mv	a3,s10
    80005548:	e1840613          	addi	a2,s0,-488
    8000554c:	4581                	li	a1,0
    8000554e:	8552                	mv	a0,s4
    80005550:	fffff097          	auipc	ra,0xfffff
    80005554:	be6080e7          	jalr	-1050(ra) # 80004136 <readi>
    80005558:	03800793          	li	a5,56
    8000555c:	20f51063          	bne	a0,a5,8000575c <exec+0x36c>
    if(ph.type != ELF_PROG_LOAD)
    80005560:	e1842783          	lw	a5,-488(s0)
    80005564:	4705                	li	a4,1
    80005566:	fce796e3          	bne	a5,a4,80005532 <exec+0x142>
    if(ph.memsz < ph.filesz)
    8000556a:	e4043483          	ld	s1,-448(s0)
    8000556e:	e3843783          	ld	a5,-456(s0)
    80005572:	1ef4e963          	bltu	s1,a5,80005764 <exec+0x374>
    if(ph.vaddr + ph.memsz < ph.vaddr)
    80005576:	e2843783          	ld	a5,-472(s0)
    8000557a:	94be                	add	s1,s1,a5
    8000557c:	1ef4e863          	bltu	s1,a5,8000576c <exec+0x37c>
    if(ph.vaddr % PGSIZE != 0)
    80005580:	df043703          	ld	a4,-528(s0)
    80005584:	8ff9                	and	a5,a5,a4
    80005586:	1e079763          	bnez	a5,80005774 <exec+0x384>
    if((sz1 = uvmalloc(pagetable, sz, ph.vaddr + ph.memsz, flags2perm(ph.flags))) == 0)
    8000558a:	e1c42503          	lw	a0,-484(s0)
    8000558e:	00000097          	auipc	ra,0x0
    80005592:	e48080e7          	jalr	-440(ra) # 800053d6 <flags2perm>
    80005596:	86aa                	mv	a3,a0
    80005598:	8626                	mv	a2,s1
    8000559a:	85ca                	mv	a1,s2
    8000559c:	855a                	mv	a0,s6
    8000559e:	ffffc097          	auipc	ra,0xffffc
    800055a2:	edc080e7          	jalr	-292(ra) # 8000147a <uvmalloc>
    800055a6:	e0a43423          	sd	a0,-504(s0)
    800055aa:	1c050963          	beqz	a0,8000577c <exec+0x38c>
    if(loadseg(pagetable, ph.vaddr, ip, ph.off, ph.filesz) < 0)
    800055ae:	e2843b83          	ld	s7,-472(s0)
    800055b2:	e2042c03          	lw	s8,-480(s0)
    800055b6:	e3842983          	lw	s3,-456(s0)
  for(i = 0; i < sz; i += PGSIZE){
    800055ba:	00098463          	beqz	s3,800055c2 <exec+0x1d2>
    800055be:	4901                	li	s2,0
    800055c0:	b7a1                	j	80005508 <exec+0x118>
    sz = sz1;
    800055c2:	e0843903          	ld	s2,-504(s0)
    800055c6:	b7b5                	j	80005532 <exec+0x142>
    800055c8:	7dba                	ld	s11,424(sp)
  iunlockput(ip);
    800055ca:	8552                	mv	a0,s4
    800055cc:	fffff097          	auipc	ra,0xfffff
    800055d0:	b18080e7          	jalr	-1256(ra) # 800040e4 <iunlockput>
  end_op();
    800055d4:	fffff097          	auipc	ra,0xfffff
    800055d8:	2f2080e7          	jalr	754(ra) # 800048c6 <end_op>
  p = myproc();
    800055dc:	ffffc097          	auipc	ra,0xffffc
    800055e0:	658080e7          	jalr	1624(ra) # 80001c34 <myproc>
    800055e4:	8aaa                	mv	s5,a0
  uint64 oldsz = p->sz;
    800055e6:	16853c83          	ld	s9,360(a0)
  sz = PGROUNDUP(sz);
    800055ea:	6985                	lui	s3,0x1
    800055ec:	19fd                	addi	s3,s3,-1 # fff <_entry-0x7ffff001>
    800055ee:	99ca                	add	s3,s3,s2
    800055f0:	77fd                	lui	a5,0xfffff
    800055f2:	00f9f9b3          	and	s3,s3,a5
  if((sz1 = uvmalloc(pagetable, sz, sz + 2*PGSIZE, PTE_W)) == 0)
    800055f6:	4691                	li	a3,4
    800055f8:	6609                	lui	a2,0x2
    800055fa:	964e                	add	a2,a2,s3
    800055fc:	85ce                	mv	a1,s3
    800055fe:	855a                	mv	a0,s6
    80005600:	ffffc097          	auipc	ra,0xffffc
    80005604:	e7a080e7          	jalr	-390(ra) # 8000147a <uvmalloc>
    80005608:	892a                	mv	s2,a0
    8000560a:	e0a43423          	sd	a0,-504(s0)
    8000560e:	e519                	bnez	a0,8000561c <exec+0x22c>
  if(pagetable)
    80005610:	e1343423          	sd	s3,-504(s0)
    80005614:	4a01                	li	s4,0
    80005616:	aaa5                	j	8000578e <exec+0x39e>
  uint64 argc, sz = 0, sp, ustack[MAXARG], stackbase;
    80005618:	4901                	li	s2,0
    8000561a:	bf45                	j	800055ca <exec+0x1da>
  uvmclear(pagetable, sz-2*PGSIZE);
    8000561c:	75f9                	lui	a1,0xffffe
    8000561e:	95aa                	add	a1,a1,a0
    80005620:	855a                	mv	a0,s6
    80005622:	ffffc097          	auipc	ra,0xffffc
    80005626:	08e080e7          	jalr	142(ra) # 800016b0 <uvmclear>
  stackbase = sp - PGSIZE;
    8000562a:	7bfd                	lui	s7,0xfffff
    8000562c:	9bca                	add	s7,s7,s2
  for(argc = 0; argv[argc]; argc++) {
    8000562e:	e0043783          	ld	a5,-512(s0)
    80005632:	6388                	ld	a0,0(a5)
    80005634:	c52d                	beqz	a0,8000569e <exec+0x2ae>
    80005636:	e9040993          	addi	s3,s0,-368
    8000563a:	f9040c13          	addi	s8,s0,-112
    8000563e:	4481                	li	s1,0
    sp -= strlen(argv[argc]) + 1;
    80005640:	ffffc097          	auipc	ra,0xffffc
    80005644:	868080e7          	jalr	-1944(ra) # 80000ea8 <strlen>
    80005648:	0015079b          	addiw	a5,a0,1
    8000564c:	40f907b3          	sub	a5,s2,a5
    sp -= sp % 16; // riscv sp must be 16-byte aligned
    80005650:	ff07f913          	andi	s2,a5,-16
    if(sp < stackbase)
    80005654:	13796863          	bltu	s2,s7,80005784 <exec+0x394>
    if(copyout(pagetable, sp, argv[argc], strlen(argv[argc]) + 1) < 0)
    80005658:	e0043d03          	ld	s10,-512(s0)
    8000565c:	000d3a03          	ld	s4,0(s10)
    80005660:	8552                	mv	a0,s4
    80005662:	ffffc097          	auipc	ra,0xffffc
    80005666:	846080e7          	jalr	-1978(ra) # 80000ea8 <strlen>
    8000566a:	0015069b          	addiw	a3,a0,1
    8000566e:	8652                	mv	a2,s4
    80005670:	85ca                	mv	a1,s2
    80005672:	855a                	mv	a0,s6
    80005674:	ffffc097          	auipc	ra,0xffffc
    80005678:	06e080e7          	jalr	110(ra) # 800016e2 <copyout>
    8000567c:	10054663          	bltz	a0,80005788 <exec+0x398>
    ustack[argc] = sp;
    80005680:	0129b023          	sd	s2,0(s3)
  for(argc = 0; argv[argc]; argc++) {
    80005684:	0485                	addi	s1,s1,1
    80005686:	008d0793          	addi	a5,s10,8
    8000568a:	e0f43023          	sd	a5,-512(s0)
    8000568e:	008d3503          	ld	a0,8(s10)
    80005692:	c909                	beqz	a0,800056a4 <exec+0x2b4>
    if(argc >= MAXARG)
    80005694:	09a1                	addi	s3,s3,8
    80005696:	fb8995e3          	bne	s3,s8,80005640 <exec+0x250>
  ip = 0;
    8000569a:	4a01                	li	s4,0
    8000569c:	a8cd                	j	8000578e <exec+0x39e>
  sp = sz;
    8000569e:	e0843903          	ld	s2,-504(s0)
  for(argc = 0; argv[argc]; argc++) {
    800056a2:	4481                	li	s1,0
  ustack[argc] = 0;
    800056a4:	00349793          	slli	a5,s1,0x3
    800056a8:	f9078793          	addi	a5,a5,-112 # ffffffffffffef90 <end+0xffffffff7ffd4230>
    800056ac:	97a2                	add	a5,a5,s0
    800056ae:	f007b023          	sd	zero,-256(a5)
  sp -= (argc+1) * sizeof(uint64);
    800056b2:	00148693          	addi	a3,s1,1
    800056b6:	068e                	slli	a3,a3,0x3
    800056b8:	40d90933          	sub	s2,s2,a3
  sp -= sp % 16;
    800056bc:	ff097913          	andi	s2,s2,-16
  sz = sz1;
    800056c0:	e0843983          	ld	s3,-504(s0)
  if(sp < stackbase)
    800056c4:	f57966e3          	bltu	s2,s7,80005610 <exec+0x220>
  if(copyout(pagetable, sp, (char *)ustack, (argc+1)*sizeof(uint64)) < 0)
    800056c8:	e9040613          	addi	a2,s0,-368
    800056cc:	85ca                	mv	a1,s2
    800056ce:	855a                	mv	a0,s6
    800056d0:	ffffc097          	auipc	ra,0xffffc
    800056d4:	012080e7          	jalr	18(ra) # 800016e2 <copyout>
    800056d8:	0e054863          	bltz	a0,800057c8 <exec+0x3d8>
  p->trapframe->a1 = sp;
    800056dc:	178ab783          	ld	a5,376(s5) # 1178 <_entry-0x7fffee88>
    800056e0:	0727bc23          	sd	s2,120(a5)
  for(last=s=path; *s; s++)
    800056e4:	df843783          	ld	a5,-520(s0)
    800056e8:	0007c703          	lbu	a4,0(a5)
    800056ec:	cf11                	beqz	a4,80005708 <exec+0x318>
    800056ee:	0785                	addi	a5,a5,1
    if(*s == '/')
    800056f0:	02f00693          	li	a3,47
    800056f4:	a039                	j	80005702 <exec+0x312>
      last = s+1;
    800056f6:	def43c23          	sd	a5,-520(s0)
  for(last=s=path; *s; s++)
    800056fa:	0785                	addi	a5,a5,1
    800056fc:	fff7c703          	lbu	a4,-1(a5)
    80005700:	c701                	beqz	a4,80005708 <exec+0x318>
    if(*s == '/')
    80005702:	fed71ce3          	bne	a4,a3,800056fa <exec+0x30a>
    80005706:	bfc5                	j	800056f6 <exec+0x306>
  safestrcpy(p->name, last, sizeof(p->name));
    80005708:	4641                	li	a2,16
    8000570a:	df843583          	ld	a1,-520(s0)
    8000570e:	278a8513          	addi	a0,s5,632
    80005712:	ffffb097          	auipc	ra,0xffffb
    80005716:	764080e7          	jalr	1892(ra) # 80000e76 <safestrcpy>
  oldpagetable = p->pagetable;
    8000571a:	170ab503          	ld	a0,368(s5)
  p->pagetable = pagetable;
    8000571e:	176ab823          	sd	s6,368(s5)
  p->sz = sz;
    80005722:	e0843783          	ld	a5,-504(s0)
    80005726:	16fab423          	sd	a5,360(s5)
  p->trapframe->epc = elf.entry;  // initial program counter = main
    8000572a:	178ab783          	ld	a5,376(s5)
    8000572e:	e6843703          	ld	a4,-408(s0)
    80005732:	ef98                	sd	a4,24(a5)
  p->trapframe->sp = sp; // initial stack pointer
    80005734:	178ab783          	ld	a5,376(s5)
    80005738:	0327b823          	sd	s2,48(a5)
  proc_freepagetable(oldpagetable, oldsz);
    8000573c:	85e6                	mv	a1,s9
    8000573e:	ffffc097          	auipc	ra,0xffffc
    80005742:	65a080e7          	jalr	1626(ra) # 80001d98 <proc_freepagetable>
  return argc; // this ends up in a0, the first argument to main(argc, argv)
    80005746:	0004851b          	sext.w	a0,s1
    8000574a:	79be                	ld	s3,488(sp)
    8000574c:	7a1e                	ld	s4,480(sp)
    8000574e:	6afe                	ld	s5,472(sp)
    80005750:	6b5e                	ld	s6,464(sp)
    80005752:	6bbe                	ld	s7,456(sp)
    80005754:	6c1e                	ld	s8,448(sp)
    80005756:	7cfa                	ld	s9,440(sp)
    80005758:	7d5a                	ld	s10,432(sp)
    8000575a:	b305                	j	8000547a <exec+0x8a>
    8000575c:	e1243423          	sd	s2,-504(s0)
    80005760:	7dba                	ld	s11,424(sp)
    80005762:	a035                	j	8000578e <exec+0x39e>
    80005764:	e1243423          	sd	s2,-504(s0)
    80005768:	7dba                	ld	s11,424(sp)
    8000576a:	a015                	j	8000578e <exec+0x39e>
    8000576c:	e1243423          	sd	s2,-504(s0)
    80005770:	7dba                	ld	s11,424(sp)
    80005772:	a831                	j	8000578e <exec+0x39e>
    80005774:	e1243423          	sd	s2,-504(s0)
    80005778:	7dba                	ld	s11,424(sp)
    8000577a:	a811                	j	8000578e <exec+0x39e>
    8000577c:	e1243423          	sd	s2,-504(s0)
    80005780:	7dba                	ld	s11,424(sp)
    80005782:	a031                	j	8000578e <exec+0x39e>
  ip = 0;
    80005784:	4a01                	li	s4,0
    80005786:	a021                	j	8000578e <exec+0x39e>
    80005788:	4a01                	li	s4,0
  if(pagetable)
    8000578a:	a011                	j	8000578e <exec+0x39e>
    8000578c:	7dba                	ld	s11,424(sp)
    proc_freepagetable(pagetable, sz);
    8000578e:	e0843583          	ld	a1,-504(s0)
    80005792:	855a                	mv	a0,s6
    80005794:	ffffc097          	auipc	ra,0xffffc
    80005798:	604080e7          	jalr	1540(ra) # 80001d98 <proc_freepagetable>
  return -1;
    8000579c:	557d                	li	a0,-1
  if(ip){
    8000579e:	000a1b63          	bnez	s4,800057b4 <exec+0x3c4>
    800057a2:	79be                	ld	s3,488(sp)
    800057a4:	7a1e                	ld	s4,480(sp)
    800057a6:	6afe                	ld	s5,472(sp)
    800057a8:	6b5e                	ld	s6,464(sp)
    800057aa:	6bbe                	ld	s7,456(sp)
    800057ac:	6c1e                	ld	s8,448(sp)
    800057ae:	7cfa                	ld	s9,440(sp)
    800057b0:	7d5a                	ld	s10,432(sp)
    800057b2:	b1e1                	j	8000547a <exec+0x8a>
    800057b4:	79be                	ld	s3,488(sp)
    800057b6:	6afe                	ld	s5,472(sp)
    800057b8:	6b5e                	ld	s6,464(sp)
    800057ba:	6bbe                	ld	s7,456(sp)
    800057bc:	6c1e                	ld	s8,448(sp)
    800057be:	7cfa                	ld	s9,440(sp)
    800057c0:	7d5a                	ld	s10,432(sp)
    800057c2:	b14d                	j	80005464 <exec+0x74>
    800057c4:	6b5e                	ld	s6,464(sp)
    800057c6:	b979                	j	80005464 <exec+0x74>
  sz = sz1;
    800057c8:	e0843983          	ld	s3,-504(s0)
    800057cc:	b591                	j	80005610 <exec+0x220>

00000000800057ce <argfd>:

// Fetch the nth word-sized system call argument as a file descriptor
// and return both the descriptor and the corresponding struct file.
static int
argfd(int n, int *pfd, struct file **pf)
{
    800057ce:	7179                	addi	sp,sp,-48
    800057d0:	f406                	sd	ra,40(sp)
    800057d2:	f022                	sd	s0,32(sp)
    800057d4:	ec26                	sd	s1,24(sp)
    800057d6:	e84a                	sd	s2,16(sp)
    800057d8:	1800                	addi	s0,sp,48
    800057da:	892e                	mv	s2,a1
    800057dc:	84b2                	mv	s1,a2
  int fd;
  struct file *f;

  argint(n, &fd);
    800057de:	fdc40593          	addi	a1,s0,-36
    800057e2:	ffffe097          	auipc	ra,0xffffe
    800057e6:	90a080e7          	jalr	-1782(ra) # 800030ec <argint>
  if(fd < 0 || fd >= NOFILE || (f=myproc()->ofile[fd]) == 0)
    800057ea:	fdc42703          	lw	a4,-36(s0)
    800057ee:	47bd                	li	a5,15
    800057f0:	02e7eb63          	bltu	a5,a4,80005826 <argfd+0x58>
    800057f4:	ffffc097          	auipc	ra,0xffffc
    800057f8:	440080e7          	jalr	1088(ra) # 80001c34 <myproc>
    800057fc:	fdc42703          	lw	a4,-36(s0)
    80005800:	03e70793          	addi	a5,a4,62
    80005804:	078e                	slli	a5,a5,0x3
    80005806:	953e                	add	a0,a0,a5
    80005808:	611c                	ld	a5,0(a0)
    8000580a:	c385                	beqz	a5,8000582a <argfd+0x5c>
    return -1;
  if(pfd)
    8000580c:	00090463          	beqz	s2,80005814 <argfd+0x46>
    *pfd = fd;
    80005810:	00e92023          	sw	a4,0(s2)
  if(pf)
    *pf = f;
  return 0;
    80005814:	4501                	li	a0,0
  if(pf)
    80005816:	c091                	beqz	s1,8000581a <argfd+0x4c>
    *pf = f;
    80005818:	e09c                	sd	a5,0(s1)
}
    8000581a:	70a2                	ld	ra,40(sp)
    8000581c:	7402                	ld	s0,32(sp)
    8000581e:	64e2                	ld	s1,24(sp)
    80005820:	6942                	ld	s2,16(sp)
    80005822:	6145                	addi	sp,sp,48
    80005824:	8082                	ret
    return -1;
    80005826:	557d                	li	a0,-1
    80005828:	bfcd                	j	8000581a <argfd+0x4c>
    8000582a:	557d                	li	a0,-1
    8000582c:	b7fd                	j	8000581a <argfd+0x4c>

000000008000582e <fdalloc>:

// Allocate a file descriptor for the given file.
// Takes over file reference from caller on success.
static int
fdalloc(struct file *f)
{
    8000582e:	1101                	addi	sp,sp,-32
    80005830:	ec06                	sd	ra,24(sp)
    80005832:	e822                	sd	s0,16(sp)
    80005834:	e426                	sd	s1,8(sp)
    80005836:	1000                	addi	s0,sp,32
    80005838:	84aa                	mv	s1,a0
  int fd;
  struct proc *p = myproc();
    8000583a:	ffffc097          	auipc	ra,0xffffc
    8000583e:	3fa080e7          	jalr	1018(ra) # 80001c34 <myproc>
    80005842:	862a                	mv	a2,a0

  for(fd = 0; fd < NOFILE; fd++){
    80005844:	1f050793          	addi	a5,a0,496
    80005848:	4501                	li	a0,0
    8000584a:	46c1                	li	a3,16
    if(p->ofile[fd] == 0){
    8000584c:	6398                	ld	a4,0(a5)
    8000584e:	cb19                	beqz	a4,80005864 <fdalloc+0x36>
  for(fd = 0; fd < NOFILE; fd++){
    80005850:	2505                	addiw	a0,a0,1
    80005852:	07a1                	addi	a5,a5,8
    80005854:	fed51ce3          	bne	a0,a3,8000584c <fdalloc+0x1e>
      p->ofile[fd] = f;
      return fd;
    }
  }
  return -1;
    80005858:	557d                	li	a0,-1
}
    8000585a:	60e2                	ld	ra,24(sp)
    8000585c:	6442                	ld	s0,16(sp)
    8000585e:	64a2                	ld	s1,8(sp)
    80005860:	6105                	addi	sp,sp,32
    80005862:	8082                	ret
      p->ofile[fd] = f;
    80005864:	03e50793          	addi	a5,a0,62
    80005868:	078e                	slli	a5,a5,0x3
    8000586a:	963e                	add	a2,a2,a5
    8000586c:	e204                	sd	s1,0(a2)
      return fd;
    8000586e:	b7f5                	j	8000585a <fdalloc+0x2c>

0000000080005870 <create>:
  return -1;
}

static struct inode*
create(char *path, short type, short major, short minor)
{
    80005870:	715d                	addi	sp,sp,-80
    80005872:	e486                	sd	ra,72(sp)
    80005874:	e0a2                	sd	s0,64(sp)
    80005876:	fc26                	sd	s1,56(sp)
    80005878:	f84a                	sd	s2,48(sp)
    8000587a:	f44e                	sd	s3,40(sp)
    8000587c:	ec56                	sd	s5,24(sp)
    8000587e:	e85a                	sd	s6,16(sp)
    80005880:	0880                	addi	s0,sp,80
    80005882:	8b2e                	mv	s6,a1
    80005884:	89b2                	mv	s3,a2
    80005886:	8936                	mv	s2,a3
  struct inode *ip, *dp;
  char name[DIRSIZ];

  if((dp = nameiparent(path, name)) == 0)
    80005888:	fb040593          	addi	a1,s0,-80
    8000588c:	fffff097          	auipc	ra,0xfffff
    80005890:	dde080e7          	jalr	-546(ra) # 8000466a <nameiparent>
    80005894:	84aa                	mv	s1,a0
    80005896:	14050e63          	beqz	a0,800059f2 <create+0x182>
    return 0;

  ilock(dp);
    8000589a:	ffffe097          	auipc	ra,0xffffe
    8000589e:	5e4080e7          	jalr	1508(ra) # 80003e7e <ilock>

  if((ip = dirlookup(dp, name, 0)) != 0){
    800058a2:	4601                	li	a2,0
    800058a4:	fb040593          	addi	a1,s0,-80
    800058a8:	8526                	mv	a0,s1
    800058aa:	fffff097          	auipc	ra,0xfffff
    800058ae:	ae0080e7          	jalr	-1312(ra) # 8000438a <dirlookup>
    800058b2:	8aaa                	mv	s5,a0
    800058b4:	c539                	beqz	a0,80005902 <create+0x92>
    iunlockput(dp);
    800058b6:	8526                	mv	a0,s1
    800058b8:	fffff097          	auipc	ra,0xfffff
    800058bc:	82c080e7          	jalr	-2004(ra) # 800040e4 <iunlockput>
    ilock(ip);
    800058c0:	8556                	mv	a0,s5
    800058c2:	ffffe097          	auipc	ra,0xffffe
    800058c6:	5bc080e7          	jalr	1468(ra) # 80003e7e <ilock>
    if(type == T_FILE && (ip->type == T_FILE || ip->type == T_DEVICE))
    800058ca:	4789                	li	a5,2
    800058cc:	02fb1463          	bne	s6,a5,800058f4 <create+0x84>
    800058d0:	044ad783          	lhu	a5,68(s5)
    800058d4:	37f9                	addiw	a5,a5,-2
    800058d6:	17c2                	slli	a5,a5,0x30
    800058d8:	93c1                	srli	a5,a5,0x30
    800058da:	4705                	li	a4,1
    800058dc:	00f76c63          	bltu	a4,a5,800058f4 <create+0x84>
  ip->nlink = 0;
  iupdate(ip);
  iunlockput(ip);
  iunlockput(dp);
  return 0;
}
    800058e0:	8556                	mv	a0,s5
    800058e2:	60a6                	ld	ra,72(sp)
    800058e4:	6406                	ld	s0,64(sp)
    800058e6:	74e2                	ld	s1,56(sp)
    800058e8:	7942                	ld	s2,48(sp)
    800058ea:	79a2                	ld	s3,40(sp)
    800058ec:	6ae2                	ld	s5,24(sp)
    800058ee:	6b42                	ld	s6,16(sp)
    800058f0:	6161                	addi	sp,sp,80
    800058f2:	8082                	ret
    iunlockput(ip);
    800058f4:	8556                	mv	a0,s5
    800058f6:	ffffe097          	auipc	ra,0xffffe
    800058fa:	7ee080e7          	jalr	2030(ra) # 800040e4 <iunlockput>
    return 0;
    800058fe:	4a81                	li	s5,0
    80005900:	b7c5                	j	800058e0 <create+0x70>
    80005902:	f052                	sd	s4,32(sp)
  if((ip = ialloc(dp->dev, type)) == 0){
    80005904:	85da                	mv	a1,s6
    80005906:	4088                	lw	a0,0(s1)
    80005908:	ffffe097          	auipc	ra,0xffffe
    8000590c:	3d2080e7          	jalr	978(ra) # 80003cda <ialloc>
    80005910:	8a2a                	mv	s4,a0
    80005912:	c531                	beqz	a0,8000595e <create+0xee>
  ilock(ip);
    80005914:	ffffe097          	auipc	ra,0xffffe
    80005918:	56a080e7          	jalr	1386(ra) # 80003e7e <ilock>
  ip->major = major;
    8000591c:	053a1323          	sh	s3,70(s4)
  ip->minor = minor;
    80005920:	052a1423          	sh	s2,72(s4)
  ip->nlink = 1;
    80005924:	4905                	li	s2,1
    80005926:	052a1523          	sh	s2,74(s4)
  iupdate(ip);
    8000592a:	8552                	mv	a0,s4
    8000592c:	ffffe097          	auipc	ra,0xffffe
    80005930:	486080e7          	jalr	1158(ra) # 80003db2 <iupdate>
  if(type == T_DIR){  // Create . and .. entries.
    80005934:	032b0d63          	beq	s6,s2,8000596e <create+0xfe>
  if(dirlink(dp, name, ip->inum) < 0)
    80005938:	004a2603          	lw	a2,4(s4)
    8000593c:	fb040593          	addi	a1,s0,-80
    80005940:	8526                	mv	a0,s1
    80005942:	fffff097          	auipc	ra,0xfffff
    80005946:	c58080e7          	jalr	-936(ra) # 8000459a <dirlink>
    8000594a:	08054163          	bltz	a0,800059cc <create+0x15c>
  iunlockput(dp);
    8000594e:	8526                	mv	a0,s1
    80005950:	ffffe097          	auipc	ra,0xffffe
    80005954:	794080e7          	jalr	1940(ra) # 800040e4 <iunlockput>
  return ip;
    80005958:	8ad2                	mv	s5,s4
    8000595a:	7a02                	ld	s4,32(sp)
    8000595c:	b751                	j	800058e0 <create+0x70>
    iunlockput(dp);
    8000595e:	8526                	mv	a0,s1
    80005960:	ffffe097          	auipc	ra,0xffffe
    80005964:	784080e7          	jalr	1924(ra) # 800040e4 <iunlockput>
    return 0;
    80005968:	8ad2                	mv	s5,s4
    8000596a:	7a02                	ld	s4,32(sp)
    8000596c:	bf95                	j	800058e0 <create+0x70>
    if(dirlink(ip, ".", ip->inum) < 0 || dirlink(ip, "..", dp->inum) < 0)
    8000596e:	004a2603          	lw	a2,4(s4)
    80005972:	00003597          	auipc	a1,0x3
    80005976:	c6658593          	addi	a1,a1,-922 # 800085d8 <etext+0x5d8>
    8000597a:	8552                	mv	a0,s4
    8000597c:	fffff097          	auipc	ra,0xfffff
    80005980:	c1e080e7          	jalr	-994(ra) # 8000459a <dirlink>
    80005984:	04054463          	bltz	a0,800059cc <create+0x15c>
    80005988:	40d0                	lw	a2,4(s1)
    8000598a:	00003597          	auipc	a1,0x3
    8000598e:	c5658593          	addi	a1,a1,-938 # 800085e0 <etext+0x5e0>
    80005992:	8552                	mv	a0,s4
    80005994:	fffff097          	auipc	ra,0xfffff
    80005998:	c06080e7          	jalr	-1018(ra) # 8000459a <dirlink>
    8000599c:	02054863          	bltz	a0,800059cc <create+0x15c>
  if(dirlink(dp, name, ip->inum) < 0)
    800059a0:	004a2603          	lw	a2,4(s4)
    800059a4:	fb040593          	addi	a1,s0,-80
    800059a8:	8526                	mv	a0,s1
    800059aa:	fffff097          	auipc	ra,0xfffff
    800059ae:	bf0080e7          	jalr	-1040(ra) # 8000459a <dirlink>
    800059b2:	00054d63          	bltz	a0,800059cc <create+0x15c>
    dp->nlink++;  // for ".."
    800059b6:	04a4d783          	lhu	a5,74(s1)
    800059ba:	2785                	addiw	a5,a5,1
    800059bc:	04f49523          	sh	a5,74(s1)
    iupdate(dp);
    800059c0:	8526                	mv	a0,s1
    800059c2:	ffffe097          	auipc	ra,0xffffe
    800059c6:	3f0080e7          	jalr	1008(ra) # 80003db2 <iupdate>
    800059ca:	b751                	j	8000594e <create+0xde>
  ip->nlink = 0;
    800059cc:	040a1523          	sh	zero,74(s4)
  iupdate(ip);
    800059d0:	8552                	mv	a0,s4
    800059d2:	ffffe097          	auipc	ra,0xffffe
    800059d6:	3e0080e7          	jalr	992(ra) # 80003db2 <iupdate>
  iunlockput(ip);
    800059da:	8552                	mv	a0,s4
    800059dc:	ffffe097          	auipc	ra,0xffffe
    800059e0:	708080e7          	jalr	1800(ra) # 800040e4 <iunlockput>
  iunlockput(dp);
    800059e4:	8526                	mv	a0,s1
    800059e6:	ffffe097          	auipc	ra,0xffffe
    800059ea:	6fe080e7          	jalr	1790(ra) # 800040e4 <iunlockput>
  return 0;
    800059ee:	7a02                	ld	s4,32(sp)
    800059f0:	bdc5                	j	800058e0 <create+0x70>
    return 0;
    800059f2:	8aaa                	mv	s5,a0
    800059f4:	b5f5                	j	800058e0 <create+0x70>

00000000800059f6 <sys_dup>:
{
    800059f6:	7179                	addi	sp,sp,-48
    800059f8:	f406                	sd	ra,40(sp)
    800059fa:	f022                	sd	s0,32(sp)
    800059fc:	1800                	addi	s0,sp,48
  if(argfd(0, 0, &f) < 0)
    800059fe:	fd840613          	addi	a2,s0,-40
    80005a02:	4581                	li	a1,0
    80005a04:	4501                	li	a0,0
    80005a06:	00000097          	auipc	ra,0x0
    80005a0a:	dc8080e7          	jalr	-568(ra) # 800057ce <argfd>
    return -1;
    80005a0e:	57fd                	li	a5,-1
  if(argfd(0, 0, &f) < 0)
    80005a10:	02054763          	bltz	a0,80005a3e <sys_dup+0x48>
    80005a14:	ec26                	sd	s1,24(sp)
    80005a16:	e84a                	sd	s2,16(sp)
  if((fd=fdalloc(f)) < 0)
    80005a18:	fd843903          	ld	s2,-40(s0)
    80005a1c:	854a                	mv	a0,s2
    80005a1e:	00000097          	auipc	ra,0x0
    80005a22:	e10080e7          	jalr	-496(ra) # 8000582e <fdalloc>
    80005a26:	84aa                	mv	s1,a0
    return -1;
    80005a28:	57fd                	li	a5,-1
  if((fd=fdalloc(f)) < 0)
    80005a2a:	00054f63          	bltz	a0,80005a48 <sys_dup+0x52>
  filedup(f);
    80005a2e:	854a                	mv	a0,s2
    80005a30:	fffff097          	auipc	ra,0xfffff
    80005a34:	298080e7          	jalr	664(ra) # 80004cc8 <filedup>
  return fd;
    80005a38:	87a6                	mv	a5,s1
    80005a3a:	64e2                	ld	s1,24(sp)
    80005a3c:	6942                	ld	s2,16(sp)
}
    80005a3e:	853e                	mv	a0,a5
    80005a40:	70a2                	ld	ra,40(sp)
    80005a42:	7402                	ld	s0,32(sp)
    80005a44:	6145                	addi	sp,sp,48
    80005a46:	8082                	ret
    80005a48:	64e2                	ld	s1,24(sp)
    80005a4a:	6942                	ld	s2,16(sp)
    80005a4c:	bfcd                	j	80005a3e <sys_dup+0x48>

0000000080005a4e <sys_read>:
{
    80005a4e:	7179                	addi	sp,sp,-48
    80005a50:	f406                	sd	ra,40(sp)
    80005a52:	f022                	sd	s0,32(sp)
    80005a54:	1800                	addi	s0,sp,48
  argaddr(1, &p);
    80005a56:	fd840593          	addi	a1,s0,-40
    80005a5a:	4505                	li	a0,1
    80005a5c:	ffffd097          	auipc	ra,0xffffd
    80005a60:	6b0080e7          	jalr	1712(ra) # 8000310c <argaddr>
  argint(2, &n);
    80005a64:	fe440593          	addi	a1,s0,-28
    80005a68:	4509                	li	a0,2
    80005a6a:	ffffd097          	auipc	ra,0xffffd
    80005a6e:	682080e7          	jalr	1666(ra) # 800030ec <argint>
  if(argfd(0, 0, &f) < 0)
    80005a72:	fe840613          	addi	a2,s0,-24
    80005a76:	4581                	li	a1,0
    80005a78:	4501                	li	a0,0
    80005a7a:	00000097          	auipc	ra,0x0
    80005a7e:	d54080e7          	jalr	-684(ra) # 800057ce <argfd>
    80005a82:	87aa                	mv	a5,a0
    return -1;
    80005a84:	557d                	li	a0,-1
  if(argfd(0, 0, &f) < 0)
    80005a86:	0007cc63          	bltz	a5,80005a9e <sys_read+0x50>
  return fileread(f, p, n);
    80005a8a:	fe442603          	lw	a2,-28(s0)
    80005a8e:	fd843583          	ld	a1,-40(s0)
    80005a92:	fe843503          	ld	a0,-24(s0)
    80005a96:	fffff097          	auipc	ra,0xfffff
    80005a9a:	3d8080e7          	jalr	984(ra) # 80004e6e <fileread>
}
    80005a9e:	70a2                	ld	ra,40(sp)
    80005aa0:	7402                	ld	s0,32(sp)
    80005aa2:	6145                	addi	sp,sp,48
    80005aa4:	8082                	ret

0000000080005aa6 <sys_write>:
{
    80005aa6:	7179                	addi	sp,sp,-48
    80005aa8:	f406                	sd	ra,40(sp)
    80005aaa:	f022                	sd	s0,32(sp)
    80005aac:	1800                	addi	s0,sp,48
  argaddr(1, &p);
    80005aae:	fd840593          	addi	a1,s0,-40
    80005ab2:	4505                	li	a0,1
    80005ab4:	ffffd097          	auipc	ra,0xffffd
    80005ab8:	658080e7          	jalr	1624(ra) # 8000310c <argaddr>
  argint(2, &n);
    80005abc:	fe440593          	addi	a1,s0,-28
    80005ac0:	4509                	li	a0,2
    80005ac2:	ffffd097          	auipc	ra,0xffffd
    80005ac6:	62a080e7          	jalr	1578(ra) # 800030ec <argint>
  if(argfd(0, 0, &f) < 0)
    80005aca:	fe840613          	addi	a2,s0,-24
    80005ace:	4581                	li	a1,0
    80005ad0:	4501                	li	a0,0
    80005ad2:	00000097          	auipc	ra,0x0
    80005ad6:	cfc080e7          	jalr	-772(ra) # 800057ce <argfd>
    80005ada:	87aa                	mv	a5,a0
    return -1;
    80005adc:	557d                	li	a0,-1
  if(argfd(0, 0, &f) < 0)
    80005ade:	0007cc63          	bltz	a5,80005af6 <sys_write+0x50>
  return filewrite(f, p, n);
    80005ae2:	fe442603          	lw	a2,-28(s0)
    80005ae6:	fd843583          	ld	a1,-40(s0)
    80005aea:	fe843503          	ld	a0,-24(s0)
    80005aee:	fffff097          	auipc	ra,0xfffff
    80005af2:	452080e7          	jalr	1106(ra) # 80004f40 <filewrite>
}
    80005af6:	70a2                	ld	ra,40(sp)
    80005af8:	7402                	ld	s0,32(sp)
    80005afa:	6145                	addi	sp,sp,48
    80005afc:	8082                	ret

0000000080005afe <sys_close>:
{
    80005afe:	1101                	addi	sp,sp,-32
    80005b00:	ec06                	sd	ra,24(sp)
    80005b02:	e822                	sd	s0,16(sp)
    80005b04:	1000                	addi	s0,sp,32
  if(argfd(0, &fd, &f) < 0)
    80005b06:	fe040613          	addi	a2,s0,-32
    80005b0a:	fec40593          	addi	a1,s0,-20
    80005b0e:	4501                	li	a0,0
    80005b10:	00000097          	auipc	ra,0x0
    80005b14:	cbe080e7          	jalr	-834(ra) # 800057ce <argfd>
    return -1;
    80005b18:	57fd                	li	a5,-1
  if(argfd(0, &fd, &f) < 0)
    80005b1a:	02054563          	bltz	a0,80005b44 <sys_close+0x46>
  myproc()->ofile[fd] = 0;
    80005b1e:	ffffc097          	auipc	ra,0xffffc
    80005b22:	116080e7          	jalr	278(ra) # 80001c34 <myproc>
    80005b26:	fec42783          	lw	a5,-20(s0)
    80005b2a:	03e78793          	addi	a5,a5,62
    80005b2e:	078e                	slli	a5,a5,0x3
    80005b30:	953e                	add	a0,a0,a5
    80005b32:	00053023          	sd	zero,0(a0)
  fileclose(f);
    80005b36:	fe043503          	ld	a0,-32(s0)
    80005b3a:	fffff097          	auipc	ra,0xfffff
    80005b3e:	1e0080e7          	jalr	480(ra) # 80004d1a <fileclose>
  return 0;
    80005b42:	4781                	li	a5,0
}
    80005b44:	853e                	mv	a0,a5
    80005b46:	60e2                	ld	ra,24(sp)
    80005b48:	6442                	ld	s0,16(sp)
    80005b4a:	6105                	addi	sp,sp,32
    80005b4c:	8082                	ret

0000000080005b4e <sys_fstat>:
{
    80005b4e:	1101                	addi	sp,sp,-32
    80005b50:	ec06                	sd	ra,24(sp)
    80005b52:	e822                	sd	s0,16(sp)
    80005b54:	1000                	addi	s0,sp,32
  argaddr(1, &st);
    80005b56:	fe040593          	addi	a1,s0,-32
    80005b5a:	4505                	li	a0,1
    80005b5c:	ffffd097          	auipc	ra,0xffffd
    80005b60:	5b0080e7          	jalr	1456(ra) # 8000310c <argaddr>
  if(argfd(0, 0, &f) < 0)
    80005b64:	fe840613          	addi	a2,s0,-24
    80005b68:	4581                	li	a1,0
    80005b6a:	4501                	li	a0,0
    80005b6c:	00000097          	auipc	ra,0x0
    80005b70:	c62080e7          	jalr	-926(ra) # 800057ce <argfd>
    80005b74:	87aa                	mv	a5,a0
    return -1;
    80005b76:	557d                	li	a0,-1
  if(argfd(0, 0, &f) < 0)
    80005b78:	0007ca63          	bltz	a5,80005b8c <sys_fstat+0x3e>
  return filestat(f, st);
    80005b7c:	fe043583          	ld	a1,-32(s0)
    80005b80:	fe843503          	ld	a0,-24(s0)
    80005b84:	fffff097          	auipc	ra,0xfffff
    80005b88:	278080e7          	jalr	632(ra) # 80004dfc <filestat>
}
    80005b8c:	60e2                	ld	ra,24(sp)
    80005b8e:	6442                	ld	s0,16(sp)
    80005b90:	6105                	addi	sp,sp,32
    80005b92:	8082                	ret

0000000080005b94 <sys_link>:
{
    80005b94:	7169                	addi	sp,sp,-304
    80005b96:	f606                	sd	ra,296(sp)
    80005b98:	f222                	sd	s0,288(sp)
    80005b9a:	1a00                	addi	s0,sp,304
  if(argstr(0, old, MAXPATH) < 0 || argstr(1, new, MAXPATH) < 0)
    80005b9c:	08000613          	li	a2,128
    80005ba0:	ed040593          	addi	a1,s0,-304
    80005ba4:	4501                	li	a0,0
    80005ba6:	ffffd097          	auipc	ra,0xffffd
    80005baa:	586080e7          	jalr	1414(ra) # 8000312c <argstr>
    return -1;
    80005bae:	57fd                	li	a5,-1
  if(argstr(0, old, MAXPATH) < 0 || argstr(1, new, MAXPATH) < 0)
    80005bb0:	12054663          	bltz	a0,80005cdc <sys_link+0x148>
    80005bb4:	08000613          	li	a2,128
    80005bb8:	f5040593          	addi	a1,s0,-176
    80005bbc:	4505                	li	a0,1
    80005bbe:	ffffd097          	auipc	ra,0xffffd
    80005bc2:	56e080e7          	jalr	1390(ra) # 8000312c <argstr>
    return -1;
    80005bc6:	57fd                	li	a5,-1
  if(argstr(0, old, MAXPATH) < 0 || argstr(1, new, MAXPATH) < 0)
    80005bc8:	10054a63          	bltz	a0,80005cdc <sys_link+0x148>
    80005bcc:	ee26                	sd	s1,280(sp)
  begin_op();
    80005bce:	fffff097          	auipc	ra,0xfffff
    80005bd2:	c7e080e7          	jalr	-898(ra) # 8000484c <begin_op>
  if((ip = namei(old)) == 0){
    80005bd6:	ed040513          	addi	a0,s0,-304
    80005bda:	fffff097          	auipc	ra,0xfffff
    80005bde:	a72080e7          	jalr	-1422(ra) # 8000464c <namei>
    80005be2:	84aa                	mv	s1,a0
    80005be4:	c949                	beqz	a0,80005c76 <sys_link+0xe2>
  ilock(ip);
    80005be6:	ffffe097          	auipc	ra,0xffffe
    80005bea:	298080e7          	jalr	664(ra) # 80003e7e <ilock>
  if(ip->type == T_DIR){
    80005bee:	04449703          	lh	a4,68(s1)
    80005bf2:	4785                	li	a5,1
    80005bf4:	08f70863          	beq	a4,a5,80005c84 <sys_link+0xf0>
    80005bf8:	ea4a                	sd	s2,272(sp)
  ip->nlink++;
    80005bfa:	04a4d783          	lhu	a5,74(s1)
    80005bfe:	2785                	addiw	a5,a5,1
    80005c00:	04f49523          	sh	a5,74(s1)
  iupdate(ip);
    80005c04:	8526                	mv	a0,s1
    80005c06:	ffffe097          	auipc	ra,0xffffe
    80005c0a:	1ac080e7          	jalr	428(ra) # 80003db2 <iupdate>
  iunlock(ip);
    80005c0e:	8526                	mv	a0,s1
    80005c10:	ffffe097          	auipc	ra,0xffffe
    80005c14:	334080e7          	jalr	820(ra) # 80003f44 <iunlock>
  if((dp = nameiparent(new, name)) == 0)
    80005c18:	fd040593          	addi	a1,s0,-48
    80005c1c:	f5040513          	addi	a0,s0,-176
    80005c20:	fffff097          	auipc	ra,0xfffff
    80005c24:	a4a080e7          	jalr	-1462(ra) # 8000466a <nameiparent>
    80005c28:	892a                	mv	s2,a0
    80005c2a:	cd35                	beqz	a0,80005ca6 <sys_link+0x112>
  ilock(dp);
    80005c2c:	ffffe097          	auipc	ra,0xffffe
    80005c30:	252080e7          	jalr	594(ra) # 80003e7e <ilock>
  if(dp->dev != ip->dev || dirlink(dp, name, ip->inum) < 0){
    80005c34:	00092703          	lw	a4,0(s2)
    80005c38:	409c                	lw	a5,0(s1)
    80005c3a:	06f71163          	bne	a4,a5,80005c9c <sys_link+0x108>
    80005c3e:	40d0                	lw	a2,4(s1)
    80005c40:	fd040593          	addi	a1,s0,-48
    80005c44:	854a                	mv	a0,s2
    80005c46:	fffff097          	auipc	ra,0xfffff
    80005c4a:	954080e7          	jalr	-1708(ra) # 8000459a <dirlink>
    80005c4e:	04054763          	bltz	a0,80005c9c <sys_link+0x108>
  iunlockput(dp);
    80005c52:	854a                	mv	a0,s2
    80005c54:	ffffe097          	auipc	ra,0xffffe
    80005c58:	490080e7          	jalr	1168(ra) # 800040e4 <iunlockput>
  iput(ip);
    80005c5c:	8526                	mv	a0,s1
    80005c5e:	ffffe097          	auipc	ra,0xffffe
    80005c62:	3de080e7          	jalr	990(ra) # 8000403c <iput>
  end_op();
    80005c66:	fffff097          	auipc	ra,0xfffff
    80005c6a:	c60080e7          	jalr	-928(ra) # 800048c6 <end_op>
  return 0;
    80005c6e:	4781                	li	a5,0
    80005c70:	64f2                	ld	s1,280(sp)
    80005c72:	6952                	ld	s2,272(sp)
    80005c74:	a0a5                	j	80005cdc <sys_link+0x148>
    end_op();
    80005c76:	fffff097          	auipc	ra,0xfffff
    80005c7a:	c50080e7          	jalr	-944(ra) # 800048c6 <end_op>
    return -1;
    80005c7e:	57fd                	li	a5,-1
    80005c80:	64f2                	ld	s1,280(sp)
    80005c82:	a8a9                	j	80005cdc <sys_link+0x148>
    iunlockput(ip);
    80005c84:	8526                	mv	a0,s1
    80005c86:	ffffe097          	auipc	ra,0xffffe
    80005c8a:	45e080e7          	jalr	1118(ra) # 800040e4 <iunlockput>
    end_op();
    80005c8e:	fffff097          	auipc	ra,0xfffff
    80005c92:	c38080e7          	jalr	-968(ra) # 800048c6 <end_op>
    return -1;
    80005c96:	57fd                	li	a5,-1
    80005c98:	64f2                	ld	s1,280(sp)
    80005c9a:	a089                	j	80005cdc <sys_link+0x148>
    iunlockput(dp);
    80005c9c:	854a                	mv	a0,s2
    80005c9e:	ffffe097          	auipc	ra,0xffffe
    80005ca2:	446080e7          	jalr	1094(ra) # 800040e4 <iunlockput>
  ilock(ip);
    80005ca6:	8526                	mv	a0,s1
    80005ca8:	ffffe097          	auipc	ra,0xffffe
    80005cac:	1d6080e7          	jalr	470(ra) # 80003e7e <ilock>
  ip->nlink--;
    80005cb0:	04a4d783          	lhu	a5,74(s1)
    80005cb4:	37fd                	addiw	a5,a5,-1
    80005cb6:	04f49523          	sh	a5,74(s1)
  iupdate(ip);
    80005cba:	8526                	mv	a0,s1
    80005cbc:	ffffe097          	auipc	ra,0xffffe
    80005cc0:	0f6080e7          	jalr	246(ra) # 80003db2 <iupdate>
  iunlockput(ip);
    80005cc4:	8526                	mv	a0,s1
    80005cc6:	ffffe097          	auipc	ra,0xffffe
    80005cca:	41e080e7          	jalr	1054(ra) # 800040e4 <iunlockput>
  end_op();
    80005cce:	fffff097          	auipc	ra,0xfffff
    80005cd2:	bf8080e7          	jalr	-1032(ra) # 800048c6 <end_op>
  return -1;
    80005cd6:	57fd                	li	a5,-1
    80005cd8:	64f2                	ld	s1,280(sp)
    80005cda:	6952                	ld	s2,272(sp)
}
    80005cdc:	853e                	mv	a0,a5
    80005cde:	70b2                	ld	ra,296(sp)
    80005ce0:	7412                	ld	s0,288(sp)
    80005ce2:	6155                	addi	sp,sp,304
    80005ce4:	8082                	ret

0000000080005ce6 <sys_unlink>:
{
    80005ce6:	7151                	addi	sp,sp,-240
    80005ce8:	f586                	sd	ra,232(sp)
    80005cea:	f1a2                	sd	s0,224(sp)
    80005cec:	1980                	addi	s0,sp,240
  if(argstr(0, path, MAXPATH) < 0)
    80005cee:	08000613          	li	a2,128
    80005cf2:	f3040593          	addi	a1,s0,-208
    80005cf6:	4501                	li	a0,0
    80005cf8:	ffffd097          	auipc	ra,0xffffd
    80005cfc:	434080e7          	jalr	1076(ra) # 8000312c <argstr>
    80005d00:	1a054a63          	bltz	a0,80005eb4 <sys_unlink+0x1ce>
    80005d04:	eda6                	sd	s1,216(sp)
  begin_op();
    80005d06:	fffff097          	auipc	ra,0xfffff
    80005d0a:	b46080e7          	jalr	-1210(ra) # 8000484c <begin_op>
  if((dp = nameiparent(path, name)) == 0){
    80005d0e:	fb040593          	addi	a1,s0,-80
    80005d12:	f3040513          	addi	a0,s0,-208
    80005d16:	fffff097          	auipc	ra,0xfffff
    80005d1a:	954080e7          	jalr	-1708(ra) # 8000466a <nameiparent>
    80005d1e:	84aa                	mv	s1,a0
    80005d20:	cd71                	beqz	a0,80005dfc <sys_unlink+0x116>
  ilock(dp);
    80005d22:	ffffe097          	auipc	ra,0xffffe
    80005d26:	15c080e7          	jalr	348(ra) # 80003e7e <ilock>
  if(namecmp(name, ".") == 0 || namecmp(name, "..") == 0)
    80005d2a:	00003597          	auipc	a1,0x3
    80005d2e:	8ae58593          	addi	a1,a1,-1874 # 800085d8 <etext+0x5d8>
    80005d32:	fb040513          	addi	a0,s0,-80
    80005d36:	ffffe097          	auipc	ra,0xffffe
    80005d3a:	63a080e7          	jalr	1594(ra) # 80004370 <namecmp>
    80005d3e:	14050c63          	beqz	a0,80005e96 <sys_unlink+0x1b0>
    80005d42:	00003597          	auipc	a1,0x3
    80005d46:	89e58593          	addi	a1,a1,-1890 # 800085e0 <etext+0x5e0>
    80005d4a:	fb040513          	addi	a0,s0,-80
    80005d4e:	ffffe097          	auipc	ra,0xffffe
    80005d52:	622080e7          	jalr	1570(ra) # 80004370 <namecmp>
    80005d56:	14050063          	beqz	a0,80005e96 <sys_unlink+0x1b0>
    80005d5a:	e9ca                	sd	s2,208(sp)
  if((ip = dirlookup(dp, name, &off)) == 0)
    80005d5c:	f2c40613          	addi	a2,s0,-212
    80005d60:	fb040593          	addi	a1,s0,-80
    80005d64:	8526                	mv	a0,s1
    80005d66:	ffffe097          	auipc	ra,0xffffe
    80005d6a:	624080e7          	jalr	1572(ra) # 8000438a <dirlookup>
    80005d6e:	892a                	mv	s2,a0
    80005d70:	12050263          	beqz	a0,80005e94 <sys_unlink+0x1ae>
  ilock(ip);
    80005d74:	ffffe097          	auipc	ra,0xffffe
    80005d78:	10a080e7          	jalr	266(ra) # 80003e7e <ilock>
  if(ip->nlink < 1)
    80005d7c:	04a91783          	lh	a5,74(s2)
    80005d80:	08f05563          	blez	a5,80005e0a <sys_unlink+0x124>
  if(ip->type == T_DIR && !isdirempty(ip)){
    80005d84:	04491703          	lh	a4,68(s2)
    80005d88:	4785                	li	a5,1
    80005d8a:	08f70963          	beq	a4,a5,80005e1c <sys_unlink+0x136>
  memset(&de, 0, sizeof(de));
    80005d8e:	4641                	li	a2,16
    80005d90:	4581                	li	a1,0
    80005d92:	fc040513          	addi	a0,s0,-64
    80005d96:	ffffb097          	auipc	ra,0xffffb
    80005d9a:	f9e080e7          	jalr	-98(ra) # 80000d34 <memset>
  if(writei(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    80005d9e:	4741                	li	a4,16
    80005da0:	f2c42683          	lw	a3,-212(s0)
    80005da4:	fc040613          	addi	a2,s0,-64
    80005da8:	4581                	li	a1,0
    80005daa:	8526                	mv	a0,s1
    80005dac:	ffffe097          	auipc	ra,0xffffe
    80005db0:	49a080e7          	jalr	1178(ra) # 80004246 <writei>
    80005db4:	47c1                	li	a5,16
    80005db6:	0af51b63          	bne	a0,a5,80005e6c <sys_unlink+0x186>
  if(ip->type == T_DIR){
    80005dba:	04491703          	lh	a4,68(s2)
    80005dbe:	4785                	li	a5,1
    80005dc0:	0af70f63          	beq	a4,a5,80005e7e <sys_unlink+0x198>
  iunlockput(dp);
    80005dc4:	8526                	mv	a0,s1
    80005dc6:	ffffe097          	auipc	ra,0xffffe
    80005dca:	31e080e7          	jalr	798(ra) # 800040e4 <iunlockput>
  ip->nlink--;
    80005dce:	04a95783          	lhu	a5,74(s2)
    80005dd2:	37fd                	addiw	a5,a5,-1
    80005dd4:	04f91523          	sh	a5,74(s2)
  iupdate(ip);
    80005dd8:	854a                	mv	a0,s2
    80005dda:	ffffe097          	auipc	ra,0xffffe
    80005dde:	fd8080e7          	jalr	-40(ra) # 80003db2 <iupdate>
  iunlockput(ip);
    80005de2:	854a                	mv	a0,s2
    80005de4:	ffffe097          	auipc	ra,0xffffe
    80005de8:	300080e7          	jalr	768(ra) # 800040e4 <iunlockput>
  end_op();
    80005dec:	fffff097          	auipc	ra,0xfffff
    80005df0:	ada080e7          	jalr	-1318(ra) # 800048c6 <end_op>
  return 0;
    80005df4:	4501                	li	a0,0
    80005df6:	64ee                	ld	s1,216(sp)
    80005df8:	694e                	ld	s2,208(sp)
    80005dfa:	a84d                	j	80005eac <sys_unlink+0x1c6>
    end_op();
    80005dfc:	fffff097          	auipc	ra,0xfffff
    80005e00:	aca080e7          	jalr	-1334(ra) # 800048c6 <end_op>
    return -1;
    80005e04:	557d                	li	a0,-1
    80005e06:	64ee                	ld	s1,216(sp)
    80005e08:	a055                	j	80005eac <sys_unlink+0x1c6>
    80005e0a:	e5ce                	sd	s3,200(sp)
    panic("unlink: nlink < 1");
    80005e0c:	00002517          	auipc	a0,0x2
    80005e10:	7dc50513          	addi	a0,a0,2012 # 800085e8 <etext+0x5e8>
    80005e14:	ffffa097          	auipc	ra,0xffffa
    80005e18:	74c080e7          	jalr	1868(ra) # 80000560 <panic>
  for(off=2*sizeof(de); off<dp->size; off+=sizeof(de)){
    80005e1c:	04c92703          	lw	a4,76(s2)
    80005e20:	02000793          	li	a5,32
    80005e24:	f6e7f5e3          	bgeu	a5,a4,80005d8e <sys_unlink+0xa8>
    80005e28:	e5ce                	sd	s3,200(sp)
    80005e2a:	02000993          	li	s3,32
    if(readi(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    80005e2e:	4741                	li	a4,16
    80005e30:	86ce                	mv	a3,s3
    80005e32:	f1840613          	addi	a2,s0,-232
    80005e36:	4581                	li	a1,0
    80005e38:	854a                	mv	a0,s2
    80005e3a:	ffffe097          	auipc	ra,0xffffe
    80005e3e:	2fc080e7          	jalr	764(ra) # 80004136 <readi>
    80005e42:	47c1                	li	a5,16
    80005e44:	00f51c63          	bne	a0,a5,80005e5c <sys_unlink+0x176>
    if(de.inum != 0)
    80005e48:	f1845783          	lhu	a5,-232(s0)
    80005e4c:	e7b5                	bnez	a5,80005eb8 <sys_unlink+0x1d2>
  for(off=2*sizeof(de); off<dp->size; off+=sizeof(de)){
    80005e4e:	29c1                	addiw	s3,s3,16
    80005e50:	04c92783          	lw	a5,76(s2)
    80005e54:	fcf9ede3          	bltu	s3,a5,80005e2e <sys_unlink+0x148>
    80005e58:	69ae                	ld	s3,200(sp)
    80005e5a:	bf15                	j	80005d8e <sys_unlink+0xa8>
      panic("isdirempty: readi");
    80005e5c:	00002517          	auipc	a0,0x2
    80005e60:	7a450513          	addi	a0,a0,1956 # 80008600 <etext+0x600>
    80005e64:	ffffa097          	auipc	ra,0xffffa
    80005e68:	6fc080e7          	jalr	1788(ra) # 80000560 <panic>
    80005e6c:	e5ce                	sd	s3,200(sp)
    panic("unlink: writei");
    80005e6e:	00002517          	auipc	a0,0x2
    80005e72:	7aa50513          	addi	a0,a0,1962 # 80008618 <etext+0x618>
    80005e76:	ffffa097          	auipc	ra,0xffffa
    80005e7a:	6ea080e7          	jalr	1770(ra) # 80000560 <panic>
    dp->nlink--;
    80005e7e:	04a4d783          	lhu	a5,74(s1)
    80005e82:	37fd                	addiw	a5,a5,-1
    80005e84:	04f49523          	sh	a5,74(s1)
    iupdate(dp);
    80005e88:	8526                	mv	a0,s1
    80005e8a:	ffffe097          	auipc	ra,0xffffe
    80005e8e:	f28080e7          	jalr	-216(ra) # 80003db2 <iupdate>
    80005e92:	bf0d                	j	80005dc4 <sys_unlink+0xde>
    80005e94:	694e                	ld	s2,208(sp)
  iunlockput(dp);
    80005e96:	8526                	mv	a0,s1
    80005e98:	ffffe097          	auipc	ra,0xffffe
    80005e9c:	24c080e7          	jalr	588(ra) # 800040e4 <iunlockput>
  end_op();
    80005ea0:	fffff097          	auipc	ra,0xfffff
    80005ea4:	a26080e7          	jalr	-1498(ra) # 800048c6 <end_op>
  return -1;
    80005ea8:	557d                	li	a0,-1
    80005eaa:	64ee                	ld	s1,216(sp)
}
    80005eac:	70ae                	ld	ra,232(sp)
    80005eae:	740e                	ld	s0,224(sp)
    80005eb0:	616d                	addi	sp,sp,240
    80005eb2:	8082                	ret
    return -1;
    80005eb4:	557d                	li	a0,-1
    80005eb6:	bfdd                	j	80005eac <sys_unlink+0x1c6>
    iunlockput(ip);
    80005eb8:	854a                	mv	a0,s2
    80005eba:	ffffe097          	auipc	ra,0xffffe
    80005ebe:	22a080e7          	jalr	554(ra) # 800040e4 <iunlockput>
    goto bad;
    80005ec2:	694e                	ld	s2,208(sp)
    80005ec4:	69ae                	ld	s3,200(sp)
    80005ec6:	bfc1                	j	80005e96 <sys_unlink+0x1b0>

0000000080005ec8 <sys_open>:

uint64
sys_open(void)
{
    80005ec8:	7131                	addi	sp,sp,-192
    80005eca:	fd06                	sd	ra,184(sp)
    80005ecc:	f922                	sd	s0,176(sp)
    80005ece:	0180                	addi	s0,sp,192
  int fd, omode;
  struct file *f;
  struct inode *ip;
  int n;

  argint(1, &omode);
    80005ed0:	f4c40593          	addi	a1,s0,-180
    80005ed4:	4505                	li	a0,1
    80005ed6:	ffffd097          	auipc	ra,0xffffd
    80005eda:	216080e7          	jalr	534(ra) # 800030ec <argint>
  if((n = argstr(0, path, MAXPATH)) < 0)
    80005ede:	08000613          	li	a2,128
    80005ee2:	f5040593          	addi	a1,s0,-176
    80005ee6:	4501                	li	a0,0
    80005ee8:	ffffd097          	auipc	ra,0xffffd
    80005eec:	244080e7          	jalr	580(ra) # 8000312c <argstr>
    80005ef0:	87aa                	mv	a5,a0
    return -1;
    80005ef2:	557d                	li	a0,-1
  if((n = argstr(0, path, MAXPATH)) < 0)
    80005ef4:	0a07ce63          	bltz	a5,80005fb0 <sys_open+0xe8>
    80005ef8:	f526                	sd	s1,168(sp)

  begin_op();
    80005efa:	fffff097          	auipc	ra,0xfffff
    80005efe:	952080e7          	jalr	-1710(ra) # 8000484c <begin_op>

  if(omode & O_CREATE){
    80005f02:	f4c42783          	lw	a5,-180(s0)
    80005f06:	2007f793          	andi	a5,a5,512
    80005f0a:	cfd5                	beqz	a5,80005fc6 <sys_open+0xfe>
    ip = create(path, T_FILE, 0, 0);
    80005f0c:	4681                	li	a3,0
    80005f0e:	4601                	li	a2,0
    80005f10:	4589                	li	a1,2
    80005f12:	f5040513          	addi	a0,s0,-176
    80005f16:	00000097          	auipc	ra,0x0
    80005f1a:	95a080e7          	jalr	-1702(ra) # 80005870 <create>
    80005f1e:	84aa                	mv	s1,a0
    if(ip == 0){
    80005f20:	cd41                	beqz	a0,80005fb8 <sys_open+0xf0>
      end_op();
      return -1;
    }
  }

  if(ip->type == T_DEVICE && (ip->major < 0 || ip->major >= NDEV)){
    80005f22:	04449703          	lh	a4,68(s1)
    80005f26:	478d                	li	a5,3
    80005f28:	00f71763          	bne	a4,a5,80005f36 <sys_open+0x6e>
    80005f2c:	0464d703          	lhu	a4,70(s1)
    80005f30:	47a5                	li	a5,9
    80005f32:	0ee7e163          	bltu	a5,a4,80006014 <sys_open+0x14c>
    80005f36:	f14a                	sd	s2,160(sp)
    iunlockput(ip);
    end_op();
    return -1;
  }

  if((f = filealloc()) == 0 || (fd = fdalloc(f)) < 0){
    80005f38:	fffff097          	auipc	ra,0xfffff
    80005f3c:	d26080e7          	jalr	-730(ra) # 80004c5e <filealloc>
    80005f40:	892a                	mv	s2,a0
    80005f42:	c97d                	beqz	a0,80006038 <sys_open+0x170>
    80005f44:	ed4e                	sd	s3,152(sp)
    80005f46:	00000097          	auipc	ra,0x0
    80005f4a:	8e8080e7          	jalr	-1816(ra) # 8000582e <fdalloc>
    80005f4e:	89aa                	mv	s3,a0
    80005f50:	0c054e63          	bltz	a0,8000602c <sys_open+0x164>
    iunlockput(ip);
    end_op();
    return -1;
  }

  if(ip->type == T_DEVICE){
    80005f54:	04449703          	lh	a4,68(s1)
    80005f58:	478d                	li	a5,3
    80005f5a:	0ef70c63          	beq	a4,a5,80006052 <sys_open+0x18a>
    f->type = FD_DEVICE;
    f->major = ip->major;
  } else {
    f->type = FD_INODE;
    80005f5e:	4789                	li	a5,2
    80005f60:	00f92023          	sw	a5,0(s2)
    f->off = 0;
    80005f64:	02092023          	sw	zero,32(s2)
  }
  f->ip = ip;
    80005f68:	00993c23          	sd	s1,24(s2)
  f->readable = !(omode & O_WRONLY);
    80005f6c:	f4c42783          	lw	a5,-180(s0)
    80005f70:	0017c713          	xori	a4,a5,1
    80005f74:	8b05                	andi	a4,a4,1
    80005f76:	00e90423          	sb	a4,8(s2)
  f->writable = (omode & O_WRONLY) || (omode & O_RDWR);
    80005f7a:	0037f713          	andi	a4,a5,3
    80005f7e:	00e03733          	snez	a4,a4
    80005f82:	00e904a3          	sb	a4,9(s2)

  if((omode & O_TRUNC) && ip->type == T_FILE){
    80005f86:	4007f793          	andi	a5,a5,1024
    80005f8a:	c791                	beqz	a5,80005f96 <sys_open+0xce>
    80005f8c:	04449703          	lh	a4,68(s1)
    80005f90:	4789                	li	a5,2
    80005f92:	0cf70763          	beq	a4,a5,80006060 <sys_open+0x198>
    itrunc(ip);
  }

  iunlock(ip);
    80005f96:	8526                	mv	a0,s1
    80005f98:	ffffe097          	auipc	ra,0xffffe
    80005f9c:	fac080e7          	jalr	-84(ra) # 80003f44 <iunlock>
  end_op();
    80005fa0:	fffff097          	auipc	ra,0xfffff
    80005fa4:	926080e7          	jalr	-1754(ra) # 800048c6 <end_op>

  return fd;
    80005fa8:	854e                	mv	a0,s3
    80005faa:	74aa                	ld	s1,168(sp)
    80005fac:	790a                	ld	s2,160(sp)
    80005fae:	69ea                	ld	s3,152(sp)
}
    80005fb0:	70ea                	ld	ra,184(sp)
    80005fb2:	744a                	ld	s0,176(sp)
    80005fb4:	6129                	addi	sp,sp,192
    80005fb6:	8082                	ret
      end_op();
    80005fb8:	fffff097          	auipc	ra,0xfffff
    80005fbc:	90e080e7          	jalr	-1778(ra) # 800048c6 <end_op>
      return -1;
    80005fc0:	557d                	li	a0,-1
    80005fc2:	74aa                	ld	s1,168(sp)
    80005fc4:	b7f5                	j	80005fb0 <sys_open+0xe8>
    if((ip = namei(path)) == 0){
    80005fc6:	f5040513          	addi	a0,s0,-176
    80005fca:	ffffe097          	auipc	ra,0xffffe
    80005fce:	682080e7          	jalr	1666(ra) # 8000464c <namei>
    80005fd2:	84aa                	mv	s1,a0
    80005fd4:	c90d                	beqz	a0,80006006 <sys_open+0x13e>
    ilock(ip);
    80005fd6:	ffffe097          	auipc	ra,0xffffe
    80005fda:	ea8080e7          	jalr	-344(ra) # 80003e7e <ilock>
    if(ip->type == T_DIR && omode != O_RDONLY){
    80005fde:	04449703          	lh	a4,68(s1)
    80005fe2:	4785                	li	a5,1
    80005fe4:	f2f71fe3          	bne	a4,a5,80005f22 <sys_open+0x5a>
    80005fe8:	f4c42783          	lw	a5,-180(s0)
    80005fec:	d7a9                	beqz	a5,80005f36 <sys_open+0x6e>
      iunlockput(ip);
    80005fee:	8526                	mv	a0,s1
    80005ff0:	ffffe097          	auipc	ra,0xffffe
    80005ff4:	0f4080e7          	jalr	244(ra) # 800040e4 <iunlockput>
      end_op();
    80005ff8:	fffff097          	auipc	ra,0xfffff
    80005ffc:	8ce080e7          	jalr	-1842(ra) # 800048c6 <end_op>
      return -1;
    80006000:	557d                	li	a0,-1
    80006002:	74aa                	ld	s1,168(sp)
    80006004:	b775                	j	80005fb0 <sys_open+0xe8>
      end_op();
    80006006:	fffff097          	auipc	ra,0xfffff
    8000600a:	8c0080e7          	jalr	-1856(ra) # 800048c6 <end_op>
      return -1;
    8000600e:	557d                	li	a0,-1
    80006010:	74aa                	ld	s1,168(sp)
    80006012:	bf79                	j	80005fb0 <sys_open+0xe8>
    iunlockput(ip);
    80006014:	8526                	mv	a0,s1
    80006016:	ffffe097          	auipc	ra,0xffffe
    8000601a:	0ce080e7          	jalr	206(ra) # 800040e4 <iunlockput>
    end_op();
    8000601e:	fffff097          	auipc	ra,0xfffff
    80006022:	8a8080e7          	jalr	-1880(ra) # 800048c6 <end_op>
    return -1;
    80006026:	557d                	li	a0,-1
    80006028:	74aa                	ld	s1,168(sp)
    8000602a:	b759                	j	80005fb0 <sys_open+0xe8>
      fileclose(f);
    8000602c:	854a                	mv	a0,s2
    8000602e:	fffff097          	auipc	ra,0xfffff
    80006032:	cec080e7          	jalr	-788(ra) # 80004d1a <fileclose>
    80006036:	69ea                	ld	s3,152(sp)
    iunlockput(ip);
    80006038:	8526                	mv	a0,s1
    8000603a:	ffffe097          	auipc	ra,0xffffe
    8000603e:	0aa080e7          	jalr	170(ra) # 800040e4 <iunlockput>
    end_op();
    80006042:	fffff097          	auipc	ra,0xfffff
    80006046:	884080e7          	jalr	-1916(ra) # 800048c6 <end_op>
    return -1;
    8000604a:	557d                	li	a0,-1
    8000604c:	74aa                	ld	s1,168(sp)
    8000604e:	790a                	ld	s2,160(sp)
    80006050:	b785                	j	80005fb0 <sys_open+0xe8>
    f->type = FD_DEVICE;
    80006052:	00f92023          	sw	a5,0(s2)
    f->major = ip->major;
    80006056:	04649783          	lh	a5,70(s1)
    8000605a:	02f91223          	sh	a5,36(s2)
    8000605e:	b729                	j	80005f68 <sys_open+0xa0>
    itrunc(ip);
    80006060:	8526                	mv	a0,s1
    80006062:	ffffe097          	auipc	ra,0xffffe
    80006066:	f2e080e7          	jalr	-210(ra) # 80003f90 <itrunc>
    8000606a:	b735                	j	80005f96 <sys_open+0xce>

000000008000606c <sys_mkdir>:

uint64
sys_mkdir(void)
{
    8000606c:	7175                	addi	sp,sp,-144
    8000606e:	e506                	sd	ra,136(sp)
    80006070:	e122                	sd	s0,128(sp)
    80006072:	0900                	addi	s0,sp,144
  char path[MAXPATH];
  struct inode *ip;

  begin_op();
    80006074:	ffffe097          	auipc	ra,0xffffe
    80006078:	7d8080e7          	jalr	2008(ra) # 8000484c <begin_op>
  if(argstr(0, path, MAXPATH) < 0 || (ip = create(path, T_DIR, 0, 0)) == 0){
    8000607c:	08000613          	li	a2,128
    80006080:	f7040593          	addi	a1,s0,-144
    80006084:	4501                	li	a0,0
    80006086:	ffffd097          	auipc	ra,0xffffd
    8000608a:	0a6080e7          	jalr	166(ra) # 8000312c <argstr>
    8000608e:	02054963          	bltz	a0,800060c0 <sys_mkdir+0x54>
    80006092:	4681                	li	a3,0
    80006094:	4601                	li	a2,0
    80006096:	4585                	li	a1,1
    80006098:	f7040513          	addi	a0,s0,-144
    8000609c:	fffff097          	auipc	ra,0xfffff
    800060a0:	7d4080e7          	jalr	2004(ra) # 80005870 <create>
    800060a4:	cd11                	beqz	a0,800060c0 <sys_mkdir+0x54>
    end_op();
    return -1;
  }
  iunlockput(ip);
    800060a6:	ffffe097          	auipc	ra,0xffffe
    800060aa:	03e080e7          	jalr	62(ra) # 800040e4 <iunlockput>
  end_op();
    800060ae:	fffff097          	auipc	ra,0xfffff
    800060b2:	818080e7          	jalr	-2024(ra) # 800048c6 <end_op>
  return 0;
    800060b6:	4501                	li	a0,0
}
    800060b8:	60aa                	ld	ra,136(sp)
    800060ba:	640a                	ld	s0,128(sp)
    800060bc:	6149                	addi	sp,sp,144
    800060be:	8082                	ret
    end_op();
    800060c0:	fffff097          	auipc	ra,0xfffff
    800060c4:	806080e7          	jalr	-2042(ra) # 800048c6 <end_op>
    return -1;
    800060c8:	557d                	li	a0,-1
    800060ca:	b7fd                	j	800060b8 <sys_mkdir+0x4c>

00000000800060cc <sys_mknod>:

uint64
sys_mknod(void)
{
    800060cc:	7135                	addi	sp,sp,-160
    800060ce:	ed06                	sd	ra,152(sp)
    800060d0:	e922                	sd	s0,144(sp)
    800060d2:	1100                	addi	s0,sp,160
  struct inode *ip;
  char path[MAXPATH];
  int major, minor;

  begin_op();
    800060d4:	ffffe097          	auipc	ra,0xffffe
    800060d8:	778080e7          	jalr	1912(ra) # 8000484c <begin_op>
  argint(1, &major);
    800060dc:	f6c40593          	addi	a1,s0,-148
    800060e0:	4505                	li	a0,1
    800060e2:	ffffd097          	auipc	ra,0xffffd
    800060e6:	00a080e7          	jalr	10(ra) # 800030ec <argint>
  argint(2, &minor);
    800060ea:	f6840593          	addi	a1,s0,-152
    800060ee:	4509                	li	a0,2
    800060f0:	ffffd097          	auipc	ra,0xffffd
    800060f4:	ffc080e7          	jalr	-4(ra) # 800030ec <argint>
  if((argstr(0, path, MAXPATH)) < 0 ||
    800060f8:	08000613          	li	a2,128
    800060fc:	f7040593          	addi	a1,s0,-144
    80006100:	4501                	li	a0,0
    80006102:	ffffd097          	auipc	ra,0xffffd
    80006106:	02a080e7          	jalr	42(ra) # 8000312c <argstr>
    8000610a:	02054b63          	bltz	a0,80006140 <sys_mknod+0x74>
     (ip = create(path, T_DEVICE, major, minor)) == 0){
    8000610e:	f6841683          	lh	a3,-152(s0)
    80006112:	f6c41603          	lh	a2,-148(s0)
    80006116:	458d                	li	a1,3
    80006118:	f7040513          	addi	a0,s0,-144
    8000611c:	fffff097          	auipc	ra,0xfffff
    80006120:	754080e7          	jalr	1876(ra) # 80005870 <create>
  if((argstr(0, path, MAXPATH)) < 0 ||
    80006124:	cd11                	beqz	a0,80006140 <sys_mknod+0x74>
    end_op();
    return -1;
  }
  iunlockput(ip);
    80006126:	ffffe097          	auipc	ra,0xffffe
    8000612a:	fbe080e7          	jalr	-66(ra) # 800040e4 <iunlockput>
  end_op();
    8000612e:	ffffe097          	auipc	ra,0xffffe
    80006132:	798080e7          	jalr	1944(ra) # 800048c6 <end_op>
  return 0;
    80006136:	4501                	li	a0,0
}
    80006138:	60ea                	ld	ra,152(sp)
    8000613a:	644a                	ld	s0,144(sp)
    8000613c:	610d                	addi	sp,sp,160
    8000613e:	8082                	ret
    end_op();
    80006140:	ffffe097          	auipc	ra,0xffffe
    80006144:	786080e7          	jalr	1926(ra) # 800048c6 <end_op>
    return -1;
    80006148:	557d                	li	a0,-1
    8000614a:	b7fd                	j	80006138 <sys_mknod+0x6c>

000000008000614c <sys_chdir>:

uint64
sys_chdir(void)
{
    8000614c:	7135                	addi	sp,sp,-160
    8000614e:	ed06                	sd	ra,152(sp)
    80006150:	e922                	sd	s0,144(sp)
    80006152:	e14a                	sd	s2,128(sp)
    80006154:	1100                	addi	s0,sp,160
  char path[MAXPATH];
  struct inode *ip;
  struct proc *p = myproc();
    80006156:	ffffc097          	auipc	ra,0xffffc
    8000615a:	ade080e7          	jalr	-1314(ra) # 80001c34 <myproc>
    8000615e:	892a                	mv	s2,a0
  
  begin_op();
    80006160:	ffffe097          	auipc	ra,0xffffe
    80006164:	6ec080e7          	jalr	1772(ra) # 8000484c <begin_op>
  if(argstr(0, path, MAXPATH) < 0 || (ip = namei(path)) == 0){
    80006168:	08000613          	li	a2,128
    8000616c:	f6040593          	addi	a1,s0,-160
    80006170:	4501                	li	a0,0
    80006172:	ffffd097          	auipc	ra,0xffffd
    80006176:	fba080e7          	jalr	-70(ra) # 8000312c <argstr>
    8000617a:	04054d63          	bltz	a0,800061d4 <sys_chdir+0x88>
    8000617e:	e526                	sd	s1,136(sp)
    80006180:	f6040513          	addi	a0,s0,-160
    80006184:	ffffe097          	auipc	ra,0xffffe
    80006188:	4c8080e7          	jalr	1224(ra) # 8000464c <namei>
    8000618c:	84aa                	mv	s1,a0
    8000618e:	c131                	beqz	a0,800061d2 <sys_chdir+0x86>
    end_op();
    return -1;
  }
  ilock(ip);
    80006190:	ffffe097          	auipc	ra,0xffffe
    80006194:	cee080e7          	jalr	-786(ra) # 80003e7e <ilock>
  if(ip->type != T_DIR){
    80006198:	04449703          	lh	a4,68(s1)
    8000619c:	4785                	li	a5,1
    8000619e:	04f71163          	bne	a4,a5,800061e0 <sys_chdir+0x94>
    iunlockput(ip);
    end_op();
    return -1;
  }
  iunlock(ip);
    800061a2:	8526                	mv	a0,s1
    800061a4:	ffffe097          	auipc	ra,0xffffe
    800061a8:	da0080e7          	jalr	-608(ra) # 80003f44 <iunlock>
  iput(p->cwd);
    800061ac:	27093503          	ld	a0,624(s2)
    800061b0:	ffffe097          	auipc	ra,0xffffe
    800061b4:	e8c080e7          	jalr	-372(ra) # 8000403c <iput>
  end_op();
    800061b8:	ffffe097          	auipc	ra,0xffffe
    800061bc:	70e080e7          	jalr	1806(ra) # 800048c6 <end_op>
  p->cwd = ip;
    800061c0:	26993823          	sd	s1,624(s2)
  return 0;
    800061c4:	4501                	li	a0,0
    800061c6:	64aa                	ld	s1,136(sp)
}
    800061c8:	60ea                	ld	ra,152(sp)
    800061ca:	644a                	ld	s0,144(sp)
    800061cc:	690a                	ld	s2,128(sp)
    800061ce:	610d                	addi	sp,sp,160
    800061d0:	8082                	ret
    800061d2:	64aa                	ld	s1,136(sp)
    end_op();
    800061d4:	ffffe097          	auipc	ra,0xffffe
    800061d8:	6f2080e7          	jalr	1778(ra) # 800048c6 <end_op>
    return -1;
    800061dc:	557d                	li	a0,-1
    800061de:	b7ed                	j	800061c8 <sys_chdir+0x7c>
    iunlockput(ip);
    800061e0:	8526                	mv	a0,s1
    800061e2:	ffffe097          	auipc	ra,0xffffe
    800061e6:	f02080e7          	jalr	-254(ra) # 800040e4 <iunlockput>
    end_op();
    800061ea:	ffffe097          	auipc	ra,0xffffe
    800061ee:	6dc080e7          	jalr	1756(ra) # 800048c6 <end_op>
    return -1;
    800061f2:	557d                	li	a0,-1
    800061f4:	64aa                	ld	s1,136(sp)
    800061f6:	bfc9                	j	800061c8 <sys_chdir+0x7c>

00000000800061f8 <sys_exec>:

uint64
sys_exec(void)
{
    800061f8:	7121                	addi	sp,sp,-448
    800061fa:	ff06                	sd	ra,440(sp)
    800061fc:	fb22                	sd	s0,432(sp)
    800061fe:	0380                	addi	s0,sp,448
  char path[MAXPATH], *argv[MAXARG];
  int i;
  uint64 uargv, uarg;

  argaddr(1, &uargv);
    80006200:	e4840593          	addi	a1,s0,-440
    80006204:	4505                	li	a0,1
    80006206:	ffffd097          	auipc	ra,0xffffd
    8000620a:	f06080e7          	jalr	-250(ra) # 8000310c <argaddr>
  if(argstr(0, path, MAXPATH) < 0) {
    8000620e:	08000613          	li	a2,128
    80006212:	f5040593          	addi	a1,s0,-176
    80006216:	4501                	li	a0,0
    80006218:	ffffd097          	auipc	ra,0xffffd
    8000621c:	f14080e7          	jalr	-236(ra) # 8000312c <argstr>
    80006220:	87aa                	mv	a5,a0
    return -1;
    80006222:	557d                	li	a0,-1
  if(argstr(0, path, MAXPATH) < 0) {
    80006224:	0e07c263          	bltz	a5,80006308 <sys_exec+0x110>
    80006228:	f726                	sd	s1,424(sp)
    8000622a:	f34a                	sd	s2,416(sp)
    8000622c:	ef4e                	sd	s3,408(sp)
    8000622e:	eb52                	sd	s4,400(sp)
  }
  memset(argv, 0, sizeof(argv));
    80006230:	10000613          	li	a2,256
    80006234:	4581                	li	a1,0
    80006236:	e5040513          	addi	a0,s0,-432
    8000623a:	ffffb097          	auipc	ra,0xffffb
    8000623e:	afa080e7          	jalr	-1286(ra) # 80000d34 <memset>
  for(i=0;; i++){
    if(i >= NELEM(argv)){
    80006242:	e5040493          	addi	s1,s0,-432
  memset(argv, 0, sizeof(argv));
    80006246:	89a6                	mv	s3,s1
    80006248:	4901                	li	s2,0
    if(i >= NELEM(argv)){
    8000624a:	02000a13          	li	s4,32
      goto bad;
    }
    if(fetchaddr(uargv+sizeof(uint64)*i, (uint64*)&uarg) < 0){
    8000624e:	00391513          	slli	a0,s2,0x3
    80006252:	e4040593          	addi	a1,s0,-448
    80006256:	e4843783          	ld	a5,-440(s0)
    8000625a:	953e                	add	a0,a0,a5
    8000625c:	ffffd097          	auipc	ra,0xffffd
    80006260:	dec080e7          	jalr	-532(ra) # 80003048 <fetchaddr>
    80006264:	02054a63          	bltz	a0,80006298 <sys_exec+0xa0>
      goto bad;
    }
    if(uarg == 0){
    80006268:	e4043783          	ld	a5,-448(s0)
    8000626c:	c7b9                	beqz	a5,800062ba <sys_exec+0xc2>
      argv[i] = 0;
      break;
    }
    argv[i] = kalloc();
    8000626e:	ffffb097          	auipc	ra,0xffffb
    80006272:	8da080e7          	jalr	-1830(ra) # 80000b48 <kalloc>
    80006276:	85aa                	mv	a1,a0
    80006278:	00a9b023          	sd	a0,0(s3)
    if(argv[i] == 0)
    8000627c:	cd11                	beqz	a0,80006298 <sys_exec+0xa0>
      goto bad;
    if(fetchstr(uarg, argv[i], PGSIZE) < 0)
    8000627e:	6605                	lui	a2,0x1
    80006280:	e4043503          	ld	a0,-448(s0)
    80006284:	ffffd097          	auipc	ra,0xffffd
    80006288:	e1a080e7          	jalr	-486(ra) # 8000309e <fetchstr>
    8000628c:	00054663          	bltz	a0,80006298 <sys_exec+0xa0>
    if(i >= NELEM(argv)){
    80006290:	0905                	addi	s2,s2,1
    80006292:	09a1                	addi	s3,s3,8
    80006294:	fb491de3          	bne	s2,s4,8000624e <sys_exec+0x56>
    kfree(argv[i]);

  return ret;

 bad:
  for(i = 0; i < NELEM(argv) && argv[i] != 0; i++)
    80006298:	f5040913          	addi	s2,s0,-176
    8000629c:	6088                	ld	a0,0(s1)
    8000629e:	c125                	beqz	a0,800062fe <sys_exec+0x106>
    kfree(argv[i]);
    800062a0:	ffffa097          	auipc	ra,0xffffa
    800062a4:	7aa080e7          	jalr	1962(ra) # 80000a4a <kfree>
  for(i = 0; i < NELEM(argv) && argv[i] != 0; i++)
    800062a8:	04a1                	addi	s1,s1,8
    800062aa:	ff2499e3          	bne	s1,s2,8000629c <sys_exec+0xa4>
  return -1;
    800062ae:	557d                	li	a0,-1
    800062b0:	74ba                	ld	s1,424(sp)
    800062b2:	791a                	ld	s2,416(sp)
    800062b4:	69fa                	ld	s3,408(sp)
    800062b6:	6a5a                	ld	s4,400(sp)
    800062b8:	a881                	j	80006308 <sys_exec+0x110>
      argv[i] = 0;
    800062ba:	0009079b          	sext.w	a5,s2
    800062be:	078e                	slli	a5,a5,0x3
    800062c0:	fd078793          	addi	a5,a5,-48
    800062c4:	97a2                	add	a5,a5,s0
    800062c6:	e807b023          	sd	zero,-384(a5)
  int ret = exec(path, argv);
    800062ca:	e5040593          	addi	a1,s0,-432
    800062ce:	f5040513          	addi	a0,s0,-176
    800062d2:	fffff097          	auipc	ra,0xfffff
    800062d6:	11e080e7          	jalr	286(ra) # 800053f0 <exec>
    800062da:	892a                	mv	s2,a0
  for(i = 0; i < NELEM(argv) && argv[i] != 0; i++)
    800062dc:	f5040993          	addi	s3,s0,-176
    800062e0:	6088                	ld	a0,0(s1)
    800062e2:	c901                	beqz	a0,800062f2 <sys_exec+0xfa>
    kfree(argv[i]);
    800062e4:	ffffa097          	auipc	ra,0xffffa
    800062e8:	766080e7          	jalr	1894(ra) # 80000a4a <kfree>
  for(i = 0; i < NELEM(argv) && argv[i] != 0; i++)
    800062ec:	04a1                	addi	s1,s1,8
    800062ee:	ff3499e3          	bne	s1,s3,800062e0 <sys_exec+0xe8>
  return ret;
    800062f2:	854a                	mv	a0,s2
    800062f4:	74ba                	ld	s1,424(sp)
    800062f6:	791a                	ld	s2,416(sp)
    800062f8:	69fa                	ld	s3,408(sp)
    800062fa:	6a5a                	ld	s4,400(sp)
    800062fc:	a031                	j	80006308 <sys_exec+0x110>
  return -1;
    800062fe:	557d                	li	a0,-1
    80006300:	74ba                	ld	s1,424(sp)
    80006302:	791a                	ld	s2,416(sp)
    80006304:	69fa                	ld	s3,408(sp)
    80006306:	6a5a                	ld	s4,400(sp)
}
    80006308:	70fa                	ld	ra,440(sp)
    8000630a:	745a                	ld	s0,432(sp)
    8000630c:	6139                	addi	sp,sp,448
    8000630e:	8082                	ret

0000000080006310 <sys_pipe>:

uint64
sys_pipe(void)
{
    80006310:	7139                	addi	sp,sp,-64
    80006312:	fc06                	sd	ra,56(sp)
    80006314:	f822                	sd	s0,48(sp)
    80006316:	f426                	sd	s1,40(sp)
    80006318:	0080                	addi	s0,sp,64
  uint64 fdarray; // user pointer to array of two integers
  struct file *rf, *wf;
  int fd0, fd1;
  struct proc *p = myproc();
    8000631a:	ffffc097          	auipc	ra,0xffffc
    8000631e:	91a080e7          	jalr	-1766(ra) # 80001c34 <myproc>
    80006322:	84aa                	mv	s1,a0

  argaddr(0, &fdarray);
    80006324:	fd840593          	addi	a1,s0,-40
    80006328:	4501                	li	a0,0
    8000632a:	ffffd097          	auipc	ra,0xffffd
    8000632e:	de2080e7          	jalr	-542(ra) # 8000310c <argaddr>
  if(pipealloc(&rf, &wf) < 0)
    80006332:	fc840593          	addi	a1,s0,-56
    80006336:	fd040513          	addi	a0,s0,-48
    8000633a:	fffff097          	auipc	ra,0xfffff
    8000633e:	d4e080e7          	jalr	-690(ra) # 80005088 <pipealloc>
    return -1;
    80006342:	57fd                	li	a5,-1
  if(pipealloc(&rf, &wf) < 0)
    80006344:	0c054963          	bltz	a0,80006416 <sys_pipe+0x106>
  fd0 = -1;
    80006348:	fcf42223          	sw	a5,-60(s0)
  if((fd0 = fdalloc(rf)) < 0 || (fd1 = fdalloc(wf)) < 0){
    8000634c:	fd043503          	ld	a0,-48(s0)
    80006350:	fffff097          	auipc	ra,0xfffff
    80006354:	4de080e7          	jalr	1246(ra) # 8000582e <fdalloc>
    80006358:	fca42223          	sw	a0,-60(s0)
    8000635c:	0a054063          	bltz	a0,800063fc <sys_pipe+0xec>
    80006360:	fc843503          	ld	a0,-56(s0)
    80006364:	fffff097          	auipc	ra,0xfffff
    80006368:	4ca080e7          	jalr	1226(ra) # 8000582e <fdalloc>
    8000636c:	fca42023          	sw	a0,-64(s0)
    80006370:	06054c63          	bltz	a0,800063e8 <sys_pipe+0xd8>
      p->ofile[fd0] = 0;
    fileclose(rf);
    fileclose(wf);
    return -1;
  }
  if(copyout(p->pagetable, fdarray, (char*)&fd0, sizeof(fd0)) < 0 ||
    80006374:	4691                	li	a3,4
    80006376:	fc440613          	addi	a2,s0,-60
    8000637a:	fd843583          	ld	a1,-40(s0)
    8000637e:	1704b503          	ld	a0,368(s1)
    80006382:	ffffb097          	auipc	ra,0xffffb
    80006386:	360080e7          	jalr	864(ra) # 800016e2 <copyout>
    8000638a:	02054163          	bltz	a0,800063ac <sys_pipe+0x9c>
     copyout(p->pagetable, fdarray+sizeof(fd0), (char *)&fd1, sizeof(fd1)) < 0){
    8000638e:	4691                	li	a3,4
    80006390:	fc040613          	addi	a2,s0,-64
    80006394:	fd843583          	ld	a1,-40(s0)
    80006398:	0591                	addi	a1,a1,4
    8000639a:	1704b503          	ld	a0,368(s1)
    8000639e:	ffffb097          	auipc	ra,0xffffb
    800063a2:	344080e7          	jalr	836(ra) # 800016e2 <copyout>
    p->ofile[fd1] = 0;
    fileclose(rf);
    fileclose(wf);
    return -1;
  }
  return 0;
    800063a6:	4781                	li	a5,0
  if(copyout(p->pagetable, fdarray, (char*)&fd0, sizeof(fd0)) < 0 ||
    800063a8:	06055763          	bgez	a0,80006416 <sys_pipe+0x106>
    p->ofile[fd0] = 0;
    800063ac:	fc442783          	lw	a5,-60(s0)
    800063b0:	03e78793          	addi	a5,a5,62
    800063b4:	078e                	slli	a5,a5,0x3
    800063b6:	97a6                	add	a5,a5,s1
    800063b8:	0007b023          	sd	zero,0(a5)
    p->ofile[fd1] = 0;
    800063bc:	fc042783          	lw	a5,-64(s0)
    800063c0:	03e78793          	addi	a5,a5,62
    800063c4:	078e                	slli	a5,a5,0x3
    800063c6:	94be                	add	s1,s1,a5
    800063c8:	0004b023          	sd	zero,0(s1)
    fileclose(rf);
    800063cc:	fd043503          	ld	a0,-48(s0)
    800063d0:	fffff097          	auipc	ra,0xfffff
    800063d4:	94a080e7          	jalr	-1718(ra) # 80004d1a <fileclose>
    fileclose(wf);
    800063d8:	fc843503          	ld	a0,-56(s0)
    800063dc:	fffff097          	auipc	ra,0xfffff
    800063e0:	93e080e7          	jalr	-1730(ra) # 80004d1a <fileclose>
    return -1;
    800063e4:	57fd                	li	a5,-1
    800063e6:	a805                	j	80006416 <sys_pipe+0x106>
    if(fd0 >= 0)
    800063e8:	fc442783          	lw	a5,-60(s0)
    800063ec:	0007c863          	bltz	a5,800063fc <sys_pipe+0xec>
      p->ofile[fd0] = 0;
    800063f0:	03e78793          	addi	a5,a5,62
    800063f4:	078e                	slli	a5,a5,0x3
    800063f6:	97a6                	add	a5,a5,s1
    800063f8:	0007b023          	sd	zero,0(a5)
    fileclose(rf);
    800063fc:	fd043503          	ld	a0,-48(s0)
    80006400:	fffff097          	auipc	ra,0xfffff
    80006404:	91a080e7          	jalr	-1766(ra) # 80004d1a <fileclose>
    fileclose(wf);
    80006408:	fc843503          	ld	a0,-56(s0)
    8000640c:	fffff097          	auipc	ra,0xfffff
    80006410:	90e080e7          	jalr	-1778(ra) # 80004d1a <fileclose>
    return -1;
    80006414:	57fd                	li	a5,-1
}
    80006416:	853e                	mv	a0,a5
    80006418:	70e2                	ld	ra,56(sp)
    8000641a:	7442                	ld	s0,48(sp)
    8000641c:	74a2                	ld	s1,40(sp)
    8000641e:	6121                	addi	sp,sp,64
    80006420:	8082                	ret
	...

0000000080006430 <kernelvec>:
    80006430:	7111                	addi	sp,sp,-256
    80006432:	e006                	sd	ra,0(sp)
    80006434:	e40a                	sd	sp,8(sp)
    80006436:	e80e                	sd	gp,16(sp)
    80006438:	ec12                	sd	tp,24(sp)
    8000643a:	f016                	sd	t0,32(sp)
    8000643c:	f41a                	sd	t1,40(sp)
    8000643e:	f81e                	sd	t2,48(sp)
    80006440:	fc22                	sd	s0,56(sp)
    80006442:	e0a6                	sd	s1,64(sp)
    80006444:	e4aa                	sd	a0,72(sp)
    80006446:	e8ae                	sd	a1,80(sp)
    80006448:	ecb2                	sd	a2,88(sp)
    8000644a:	f0b6                	sd	a3,96(sp)
    8000644c:	f4ba                	sd	a4,104(sp)
    8000644e:	f8be                	sd	a5,112(sp)
    80006450:	fcc2                	sd	a6,120(sp)
    80006452:	e146                	sd	a7,128(sp)
    80006454:	e54a                	sd	s2,136(sp)
    80006456:	e94e                	sd	s3,144(sp)
    80006458:	ed52                	sd	s4,152(sp)
    8000645a:	f156                	sd	s5,160(sp)
    8000645c:	f55a                	sd	s6,168(sp)
    8000645e:	f95e                	sd	s7,176(sp)
    80006460:	fd62                	sd	s8,184(sp)
    80006462:	e1e6                	sd	s9,192(sp)
    80006464:	e5ea                	sd	s10,200(sp)
    80006466:	e9ee                	sd	s11,208(sp)
    80006468:	edf2                	sd	t3,216(sp)
    8000646a:	f1f6                	sd	t4,224(sp)
    8000646c:	f5fa                	sd	t5,232(sp)
    8000646e:	f9fe                	sd	t6,240(sp)
    80006470:	a97fc0ef          	jal	80002f06 <kerneltrap>
    80006474:	6082                	ld	ra,0(sp)
    80006476:	6122                	ld	sp,8(sp)
    80006478:	61c2                	ld	gp,16(sp)
    8000647a:	7282                	ld	t0,32(sp)
    8000647c:	7322                	ld	t1,40(sp)
    8000647e:	73c2                	ld	t2,48(sp)
    80006480:	7462                	ld	s0,56(sp)
    80006482:	6486                	ld	s1,64(sp)
    80006484:	6526                	ld	a0,72(sp)
    80006486:	65c6                	ld	a1,80(sp)
    80006488:	6666                	ld	a2,88(sp)
    8000648a:	7686                	ld	a3,96(sp)
    8000648c:	7726                	ld	a4,104(sp)
    8000648e:	77c6                	ld	a5,112(sp)
    80006490:	7866                	ld	a6,120(sp)
    80006492:	688a                	ld	a7,128(sp)
    80006494:	692a                	ld	s2,136(sp)
    80006496:	69ca                	ld	s3,144(sp)
    80006498:	6a6a                	ld	s4,152(sp)
    8000649a:	7a8a                	ld	s5,160(sp)
    8000649c:	7b2a                	ld	s6,168(sp)
    8000649e:	7bca                	ld	s7,176(sp)
    800064a0:	7c6a                	ld	s8,184(sp)
    800064a2:	6c8e                	ld	s9,192(sp)
    800064a4:	6d2e                	ld	s10,200(sp)
    800064a6:	6dce                	ld	s11,208(sp)
    800064a8:	6e6e                	ld	t3,216(sp)
    800064aa:	7e8e                	ld	t4,224(sp)
    800064ac:	7f2e                	ld	t5,232(sp)
    800064ae:	7fce                	ld	t6,240(sp)
    800064b0:	6111                	addi	sp,sp,256
    800064b2:	10200073          	sret
    800064b6:	00000013          	nop
    800064ba:	00000013          	nop
    800064be:	0001                	nop

00000000800064c0 <timervec>:
    800064c0:	34051573          	csrrw	a0,mscratch,a0
    800064c4:	e10c                	sd	a1,0(a0)
    800064c6:	e510                	sd	a2,8(a0)
    800064c8:	e914                	sd	a3,16(a0)
    800064ca:	6d0c                	ld	a1,24(a0)
    800064cc:	7110                	ld	a2,32(a0)
    800064ce:	6194                	ld	a3,0(a1)
    800064d0:	96b2                	add	a3,a3,a2
    800064d2:	e194                	sd	a3,0(a1)
    800064d4:	4589                	li	a1,2
    800064d6:	14459073          	csrw	sip,a1
    800064da:	6914                	ld	a3,16(a0)
    800064dc:	6510                	ld	a2,8(a0)
    800064de:	610c                	ld	a1,0(a0)
    800064e0:	34051573          	csrrw	a0,mscratch,a0
    800064e4:	30200073          	mret
	...

00000000800064ea <plicinit>:
// the riscv Platform Level Interrupt Controller (PLIC).
//

void
plicinit(void)
{
    800064ea:	1141                	addi	sp,sp,-16
    800064ec:	e422                	sd	s0,8(sp)
    800064ee:	0800                	addi	s0,sp,16
  // set desired IRQ priorities non-zero (otherwise disabled).
  *(uint32*)(PLIC + UART0_IRQ*4) = 1;
    800064f0:	0c0007b7          	lui	a5,0xc000
    800064f4:	4705                	li	a4,1
    800064f6:	d798                	sw	a4,40(a5)
  *(uint32*)(PLIC + VIRTIO0_IRQ*4) = 1;
    800064f8:	0c0007b7          	lui	a5,0xc000
    800064fc:	c3d8                	sw	a4,4(a5)
}
    800064fe:	6422                	ld	s0,8(sp)
    80006500:	0141                	addi	sp,sp,16
    80006502:	8082                	ret

0000000080006504 <plicinithart>:

void
plicinithart(void)
{
    80006504:	1141                	addi	sp,sp,-16
    80006506:	e406                	sd	ra,8(sp)
    80006508:	e022                	sd	s0,0(sp)
    8000650a:	0800                	addi	s0,sp,16
  int hart = cpuid();
    8000650c:	ffffb097          	auipc	ra,0xffffb
    80006510:	6fc080e7          	jalr	1788(ra) # 80001c08 <cpuid>
  
  // set enable bits for this hart's S-mode
  // for the uart and virtio disk.
  *(uint32*)PLIC_SENABLE(hart) = (1 << UART0_IRQ) | (1 << VIRTIO0_IRQ);
    80006514:	0085171b          	slliw	a4,a0,0x8
    80006518:	0c0027b7          	lui	a5,0xc002
    8000651c:	97ba                	add	a5,a5,a4
    8000651e:	40200713          	li	a4,1026
    80006522:	08e7a023          	sw	a4,128(a5) # c002080 <_entry-0x73ffdf80>

  // set this hart's S-mode priority threshold to 0.
  *(uint32*)PLIC_SPRIORITY(hart) = 0;
    80006526:	00d5151b          	slliw	a0,a0,0xd
    8000652a:	0c2017b7          	lui	a5,0xc201
    8000652e:	97aa                	add	a5,a5,a0
    80006530:	0007a023          	sw	zero,0(a5) # c201000 <_entry-0x73dff000>
}
    80006534:	60a2                	ld	ra,8(sp)
    80006536:	6402                	ld	s0,0(sp)
    80006538:	0141                	addi	sp,sp,16
    8000653a:	8082                	ret

000000008000653c <plic_claim>:

// ask the PLIC what interrupt we should serve.
int
plic_claim(void)
{
    8000653c:	1141                	addi	sp,sp,-16
    8000653e:	e406                	sd	ra,8(sp)
    80006540:	e022                	sd	s0,0(sp)
    80006542:	0800                	addi	s0,sp,16
  int hart = cpuid();
    80006544:	ffffb097          	auipc	ra,0xffffb
    80006548:	6c4080e7          	jalr	1732(ra) # 80001c08 <cpuid>
  int irq = *(uint32*)PLIC_SCLAIM(hart);
    8000654c:	00d5151b          	slliw	a0,a0,0xd
    80006550:	0c2017b7          	lui	a5,0xc201
    80006554:	97aa                	add	a5,a5,a0
  return irq;
}
    80006556:	43c8                	lw	a0,4(a5)
    80006558:	60a2                	ld	ra,8(sp)
    8000655a:	6402                	ld	s0,0(sp)
    8000655c:	0141                	addi	sp,sp,16
    8000655e:	8082                	ret

0000000080006560 <plic_complete>:

// tell the PLIC we've served this IRQ.
void
plic_complete(int irq)
{
    80006560:	1101                	addi	sp,sp,-32
    80006562:	ec06                	sd	ra,24(sp)
    80006564:	e822                	sd	s0,16(sp)
    80006566:	e426                	sd	s1,8(sp)
    80006568:	1000                	addi	s0,sp,32
    8000656a:	84aa                	mv	s1,a0
  int hart = cpuid();
    8000656c:	ffffb097          	auipc	ra,0xffffb
    80006570:	69c080e7          	jalr	1692(ra) # 80001c08 <cpuid>
  *(uint32*)PLIC_SCLAIM(hart) = irq;
    80006574:	00d5151b          	slliw	a0,a0,0xd
    80006578:	0c2017b7          	lui	a5,0xc201
    8000657c:	97aa                	add	a5,a5,a0
    8000657e:	c3c4                	sw	s1,4(a5)
}
    80006580:	60e2                	ld	ra,24(sp)
    80006582:	6442                	ld	s0,16(sp)
    80006584:	64a2                	ld	s1,8(sp)
    80006586:	6105                	addi	sp,sp,32
    80006588:	8082                	ret

000000008000658a <free_desc>:
}

// mark a descriptor as free.
static void
free_desc(int i)
{
    8000658a:	1141                	addi	sp,sp,-16
    8000658c:	e406                	sd	ra,8(sp)
    8000658e:	e022                	sd	s0,0(sp)
    80006590:	0800                	addi	s0,sp,16
  if(i >= NUM)
    80006592:	479d                	li	a5,7
    80006594:	04a7cc63          	blt	a5,a0,800065ec <free_desc+0x62>
    panic("free_desc 1");
  if(disk.free[i])
    80006598:	00024797          	auipc	a5,0x24
    8000659c:	68878793          	addi	a5,a5,1672 # 8002ac20 <disk>
    800065a0:	97aa                	add	a5,a5,a0
    800065a2:	0187c783          	lbu	a5,24(a5)
    800065a6:	ebb9                	bnez	a5,800065fc <free_desc+0x72>
    panic("free_desc 2");
  disk.desc[i].addr = 0;
    800065a8:	00451693          	slli	a3,a0,0x4
    800065ac:	00024797          	auipc	a5,0x24
    800065b0:	67478793          	addi	a5,a5,1652 # 8002ac20 <disk>
    800065b4:	6398                	ld	a4,0(a5)
    800065b6:	9736                	add	a4,a4,a3
    800065b8:	00073023          	sd	zero,0(a4)
  disk.desc[i].len = 0;
    800065bc:	6398                	ld	a4,0(a5)
    800065be:	9736                	add	a4,a4,a3
    800065c0:	00072423          	sw	zero,8(a4)
  disk.desc[i].flags = 0;
    800065c4:	00071623          	sh	zero,12(a4)
  disk.desc[i].next = 0;
    800065c8:	00071723          	sh	zero,14(a4)
  disk.free[i] = 1;
    800065cc:	97aa                	add	a5,a5,a0
    800065ce:	4705                	li	a4,1
    800065d0:	00e78c23          	sb	a4,24(a5)
  wakeup(&disk.free[0]);
    800065d4:	00024517          	auipc	a0,0x24
    800065d8:	66450513          	addi	a0,a0,1636 # 8002ac38 <disk+0x18>
    800065dc:	ffffc097          	auipc	ra,0xffffc
    800065e0:	e52080e7          	jalr	-430(ra) # 8000242e <wakeup>
}
    800065e4:	60a2                	ld	ra,8(sp)
    800065e6:	6402                	ld	s0,0(sp)
    800065e8:	0141                	addi	sp,sp,16
    800065ea:	8082                	ret
    panic("free_desc 1");
    800065ec:	00002517          	auipc	a0,0x2
    800065f0:	03c50513          	addi	a0,a0,60 # 80008628 <etext+0x628>
    800065f4:	ffffa097          	auipc	ra,0xffffa
    800065f8:	f6c080e7          	jalr	-148(ra) # 80000560 <panic>
    panic("free_desc 2");
    800065fc:	00002517          	auipc	a0,0x2
    80006600:	03c50513          	addi	a0,a0,60 # 80008638 <etext+0x638>
    80006604:	ffffa097          	auipc	ra,0xffffa
    80006608:	f5c080e7          	jalr	-164(ra) # 80000560 <panic>

000000008000660c <virtio_disk_init>:
{
    8000660c:	1101                	addi	sp,sp,-32
    8000660e:	ec06                	sd	ra,24(sp)
    80006610:	e822                	sd	s0,16(sp)
    80006612:	e426                	sd	s1,8(sp)
    80006614:	e04a                	sd	s2,0(sp)
    80006616:	1000                	addi	s0,sp,32
  initlock(&disk.vdisk_lock, "virtio_disk");
    80006618:	00002597          	auipc	a1,0x2
    8000661c:	03058593          	addi	a1,a1,48 # 80008648 <etext+0x648>
    80006620:	00024517          	auipc	a0,0x24
    80006624:	72850513          	addi	a0,a0,1832 # 8002ad48 <disk+0x128>
    80006628:	ffffa097          	auipc	ra,0xffffa
    8000662c:	580080e7          	jalr	1408(ra) # 80000ba8 <initlock>
  if(*R(VIRTIO_MMIO_MAGIC_VALUE) != 0x74726976 ||
    80006630:	100017b7          	lui	a5,0x10001
    80006634:	4398                	lw	a4,0(a5)
    80006636:	2701                	sext.w	a4,a4
    80006638:	747277b7          	lui	a5,0x74727
    8000663c:	97678793          	addi	a5,a5,-1674 # 74726976 <_entry-0xb8d968a>
    80006640:	18f71c63          	bne	a4,a5,800067d8 <virtio_disk_init+0x1cc>
     *R(VIRTIO_MMIO_VERSION) != 2 ||
    80006644:	100017b7          	lui	a5,0x10001
    80006648:	0791                	addi	a5,a5,4 # 10001004 <_entry-0x6fffeffc>
    8000664a:	439c                	lw	a5,0(a5)
    8000664c:	2781                	sext.w	a5,a5
  if(*R(VIRTIO_MMIO_MAGIC_VALUE) != 0x74726976 ||
    8000664e:	4709                	li	a4,2
    80006650:	18e79463          	bne	a5,a4,800067d8 <virtio_disk_init+0x1cc>
     *R(VIRTIO_MMIO_DEVICE_ID) != 2 ||
    80006654:	100017b7          	lui	a5,0x10001
    80006658:	07a1                	addi	a5,a5,8 # 10001008 <_entry-0x6fffeff8>
    8000665a:	439c                	lw	a5,0(a5)
    8000665c:	2781                	sext.w	a5,a5
     *R(VIRTIO_MMIO_VERSION) != 2 ||
    8000665e:	16e79d63          	bne	a5,a4,800067d8 <virtio_disk_init+0x1cc>
     *R(VIRTIO_MMIO_VENDOR_ID) != 0x554d4551){
    80006662:	100017b7          	lui	a5,0x10001
    80006666:	47d8                	lw	a4,12(a5)
    80006668:	2701                	sext.w	a4,a4
     *R(VIRTIO_MMIO_DEVICE_ID) != 2 ||
    8000666a:	554d47b7          	lui	a5,0x554d4
    8000666e:	55178793          	addi	a5,a5,1361 # 554d4551 <_entry-0x2ab2baaf>
    80006672:	16f71363          	bne	a4,a5,800067d8 <virtio_disk_init+0x1cc>
  *R(VIRTIO_MMIO_STATUS) = status;
    80006676:	100017b7          	lui	a5,0x10001
    8000667a:	0607a823          	sw	zero,112(a5) # 10001070 <_entry-0x6fffef90>
  *R(VIRTIO_MMIO_STATUS) = status;
    8000667e:	4705                	li	a4,1
    80006680:	dbb8                	sw	a4,112(a5)
  *R(VIRTIO_MMIO_STATUS) = status;
    80006682:	470d                	li	a4,3
    80006684:	dbb8                	sw	a4,112(a5)
  uint64 features = *R(VIRTIO_MMIO_DEVICE_FEATURES);
    80006686:	10001737          	lui	a4,0x10001
    8000668a:	4b14                	lw	a3,16(a4)
  features &= ~(1 << VIRTIO_RING_F_INDIRECT_DESC);
    8000668c:	c7ffe737          	lui	a4,0xc7ffe
    80006690:	75f70713          	addi	a4,a4,1887 # ffffffffc7ffe75f <end+0xffffffff47fd39ff>
  *R(VIRTIO_MMIO_DRIVER_FEATURES) = features;
    80006694:	8ef9                	and	a3,a3,a4
    80006696:	10001737          	lui	a4,0x10001
    8000669a:	d314                	sw	a3,32(a4)
  *R(VIRTIO_MMIO_STATUS) = status;
    8000669c:	472d                	li	a4,11
    8000669e:	dbb8                	sw	a4,112(a5)
  *R(VIRTIO_MMIO_STATUS) = status;
    800066a0:	07078793          	addi	a5,a5,112
  status = *R(VIRTIO_MMIO_STATUS);
    800066a4:	439c                	lw	a5,0(a5)
    800066a6:	0007891b          	sext.w	s2,a5
  if(!(status & VIRTIO_CONFIG_S_FEATURES_OK))
    800066aa:	8ba1                	andi	a5,a5,8
    800066ac:	12078e63          	beqz	a5,800067e8 <virtio_disk_init+0x1dc>
  *R(VIRTIO_MMIO_QUEUE_SEL) = 0;
    800066b0:	100017b7          	lui	a5,0x10001
    800066b4:	0207a823          	sw	zero,48(a5) # 10001030 <_entry-0x6fffefd0>
  if(*R(VIRTIO_MMIO_QUEUE_READY))
    800066b8:	100017b7          	lui	a5,0x10001
    800066bc:	04478793          	addi	a5,a5,68 # 10001044 <_entry-0x6fffefbc>
    800066c0:	439c                	lw	a5,0(a5)
    800066c2:	2781                	sext.w	a5,a5
    800066c4:	12079a63          	bnez	a5,800067f8 <virtio_disk_init+0x1ec>
  uint32 max = *R(VIRTIO_MMIO_QUEUE_NUM_MAX);
    800066c8:	100017b7          	lui	a5,0x10001
    800066cc:	03478793          	addi	a5,a5,52 # 10001034 <_entry-0x6fffefcc>
    800066d0:	439c                	lw	a5,0(a5)
    800066d2:	2781                	sext.w	a5,a5
  if(max == 0)
    800066d4:	12078a63          	beqz	a5,80006808 <virtio_disk_init+0x1fc>
  if(max < NUM)
    800066d8:	471d                	li	a4,7
    800066da:	12f77f63          	bgeu	a4,a5,80006818 <virtio_disk_init+0x20c>
  disk.desc = kalloc();
    800066de:	ffffa097          	auipc	ra,0xffffa
    800066e2:	46a080e7          	jalr	1130(ra) # 80000b48 <kalloc>
    800066e6:	00024497          	auipc	s1,0x24
    800066ea:	53a48493          	addi	s1,s1,1338 # 8002ac20 <disk>
    800066ee:	e088                	sd	a0,0(s1)
  disk.avail = kalloc();
    800066f0:	ffffa097          	auipc	ra,0xffffa
    800066f4:	458080e7          	jalr	1112(ra) # 80000b48 <kalloc>
    800066f8:	e488                	sd	a0,8(s1)
  disk.used = kalloc();
    800066fa:	ffffa097          	auipc	ra,0xffffa
    800066fe:	44e080e7          	jalr	1102(ra) # 80000b48 <kalloc>
    80006702:	87aa                	mv	a5,a0
    80006704:	e888                	sd	a0,16(s1)
  if(!disk.desc || !disk.avail || !disk.used)
    80006706:	6088                	ld	a0,0(s1)
    80006708:	12050063          	beqz	a0,80006828 <virtio_disk_init+0x21c>
    8000670c:	00024717          	auipc	a4,0x24
    80006710:	51c73703          	ld	a4,1308(a4) # 8002ac28 <disk+0x8>
    80006714:	10070a63          	beqz	a4,80006828 <virtio_disk_init+0x21c>
    80006718:	10078863          	beqz	a5,80006828 <virtio_disk_init+0x21c>
  memset(disk.desc, 0, PGSIZE);
    8000671c:	6605                	lui	a2,0x1
    8000671e:	4581                	li	a1,0
    80006720:	ffffa097          	auipc	ra,0xffffa
    80006724:	614080e7          	jalr	1556(ra) # 80000d34 <memset>
  memset(disk.avail, 0, PGSIZE);
    80006728:	00024497          	auipc	s1,0x24
    8000672c:	4f848493          	addi	s1,s1,1272 # 8002ac20 <disk>
    80006730:	6605                	lui	a2,0x1
    80006732:	4581                	li	a1,0
    80006734:	6488                	ld	a0,8(s1)
    80006736:	ffffa097          	auipc	ra,0xffffa
    8000673a:	5fe080e7          	jalr	1534(ra) # 80000d34 <memset>
  memset(disk.used, 0, PGSIZE);
    8000673e:	6605                	lui	a2,0x1
    80006740:	4581                	li	a1,0
    80006742:	6888                	ld	a0,16(s1)
    80006744:	ffffa097          	auipc	ra,0xffffa
    80006748:	5f0080e7          	jalr	1520(ra) # 80000d34 <memset>
  *R(VIRTIO_MMIO_QUEUE_NUM) = NUM;
    8000674c:	100017b7          	lui	a5,0x10001
    80006750:	4721                	li	a4,8
    80006752:	df98                	sw	a4,56(a5)
  *R(VIRTIO_MMIO_QUEUE_DESC_LOW) = (uint64)disk.desc;
    80006754:	4098                	lw	a4,0(s1)
    80006756:	100017b7          	lui	a5,0x10001
    8000675a:	08e7a023          	sw	a4,128(a5) # 10001080 <_entry-0x6fffef80>
  *R(VIRTIO_MMIO_QUEUE_DESC_HIGH) = (uint64)disk.desc >> 32;
    8000675e:	40d8                	lw	a4,4(s1)
    80006760:	100017b7          	lui	a5,0x10001
    80006764:	08e7a223          	sw	a4,132(a5) # 10001084 <_entry-0x6fffef7c>
  *R(VIRTIO_MMIO_DRIVER_DESC_LOW) = (uint64)disk.avail;
    80006768:	649c                	ld	a5,8(s1)
    8000676a:	0007869b          	sext.w	a3,a5
    8000676e:	10001737          	lui	a4,0x10001
    80006772:	08d72823          	sw	a3,144(a4) # 10001090 <_entry-0x6fffef70>
  *R(VIRTIO_MMIO_DRIVER_DESC_HIGH) = (uint64)disk.avail >> 32;
    80006776:	9781                	srai	a5,a5,0x20
    80006778:	10001737          	lui	a4,0x10001
    8000677c:	08f72a23          	sw	a5,148(a4) # 10001094 <_entry-0x6fffef6c>
  *R(VIRTIO_MMIO_DEVICE_DESC_LOW) = (uint64)disk.used;
    80006780:	689c                	ld	a5,16(s1)
    80006782:	0007869b          	sext.w	a3,a5
    80006786:	10001737          	lui	a4,0x10001
    8000678a:	0ad72023          	sw	a3,160(a4) # 100010a0 <_entry-0x6fffef60>
  *R(VIRTIO_MMIO_DEVICE_DESC_HIGH) = (uint64)disk.used >> 32;
    8000678e:	9781                	srai	a5,a5,0x20
    80006790:	10001737          	lui	a4,0x10001
    80006794:	0af72223          	sw	a5,164(a4) # 100010a4 <_entry-0x6fffef5c>
  *R(VIRTIO_MMIO_QUEUE_READY) = 0x1;
    80006798:	10001737          	lui	a4,0x10001
    8000679c:	4785                	li	a5,1
    8000679e:	c37c                	sw	a5,68(a4)
    disk.free[i] = 1;
    800067a0:	00f48c23          	sb	a5,24(s1)
    800067a4:	00f48ca3          	sb	a5,25(s1)
    800067a8:	00f48d23          	sb	a5,26(s1)
    800067ac:	00f48da3          	sb	a5,27(s1)
    800067b0:	00f48e23          	sb	a5,28(s1)
    800067b4:	00f48ea3          	sb	a5,29(s1)
    800067b8:	00f48f23          	sb	a5,30(s1)
    800067bc:	00f48fa3          	sb	a5,31(s1)
  status |= VIRTIO_CONFIG_S_DRIVER_OK;
    800067c0:	00496913          	ori	s2,s2,4
  *R(VIRTIO_MMIO_STATUS) = status;
    800067c4:	100017b7          	lui	a5,0x10001
    800067c8:	0727a823          	sw	s2,112(a5) # 10001070 <_entry-0x6fffef90>
}
    800067cc:	60e2                	ld	ra,24(sp)
    800067ce:	6442                	ld	s0,16(sp)
    800067d0:	64a2                	ld	s1,8(sp)
    800067d2:	6902                	ld	s2,0(sp)
    800067d4:	6105                	addi	sp,sp,32
    800067d6:	8082                	ret
    panic("could not find virtio disk");
    800067d8:	00002517          	auipc	a0,0x2
    800067dc:	e8050513          	addi	a0,a0,-384 # 80008658 <etext+0x658>
    800067e0:	ffffa097          	auipc	ra,0xffffa
    800067e4:	d80080e7          	jalr	-640(ra) # 80000560 <panic>
    panic("virtio disk FEATURES_OK unset");
    800067e8:	00002517          	auipc	a0,0x2
    800067ec:	e9050513          	addi	a0,a0,-368 # 80008678 <etext+0x678>
    800067f0:	ffffa097          	auipc	ra,0xffffa
    800067f4:	d70080e7          	jalr	-656(ra) # 80000560 <panic>
    panic("virtio disk should not be ready");
    800067f8:	00002517          	auipc	a0,0x2
    800067fc:	ea050513          	addi	a0,a0,-352 # 80008698 <etext+0x698>
    80006800:	ffffa097          	auipc	ra,0xffffa
    80006804:	d60080e7          	jalr	-672(ra) # 80000560 <panic>
    panic("virtio disk has no queue 0");
    80006808:	00002517          	auipc	a0,0x2
    8000680c:	eb050513          	addi	a0,a0,-336 # 800086b8 <etext+0x6b8>
    80006810:	ffffa097          	auipc	ra,0xffffa
    80006814:	d50080e7          	jalr	-688(ra) # 80000560 <panic>
    panic("virtio disk max queue too short");
    80006818:	00002517          	auipc	a0,0x2
    8000681c:	ec050513          	addi	a0,a0,-320 # 800086d8 <etext+0x6d8>
    80006820:	ffffa097          	auipc	ra,0xffffa
    80006824:	d40080e7          	jalr	-704(ra) # 80000560 <panic>
    panic("virtio disk kalloc");
    80006828:	00002517          	auipc	a0,0x2
    8000682c:	ed050513          	addi	a0,a0,-304 # 800086f8 <etext+0x6f8>
    80006830:	ffffa097          	auipc	ra,0xffffa
    80006834:	d30080e7          	jalr	-720(ra) # 80000560 <panic>

0000000080006838 <virtio_disk_rw>:
  return 0;
}

void
virtio_disk_rw(struct buf *b, int write)
{
    80006838:	7159                	addi	sp,sp,-112
    8000683a:	f486                	sd	ra,104(sp)
    8000683c:	f0a2                	sd	s0,96(sp)
    8000683e:	eca6                	sd	s1,88(sp)
    80006840:	e8ca                	sd	s2,80(sp)
    80006842:	e4ce                	sd	s3,72(sp)
    80006844:	e0d2                	sd	s4,64(sp)
    80006846:	fc56                	sd	s5,56(sp)
    80006848:	f85a                	sd	s6,48(sp)
    8000684a:	f45e                	sd	s7,40(sp)
    8000684c:	f062                	sd	s8,32(sp)
    8000684e:	ec66                	sd	s9,24(sp)
    80006850:	1880                	addi	s0,sp,112
    80006852:	8a2a                	mv	s4,a0
    80006854:	8bae                	mv	s7,a1
  uint64 sector = b->blockno * (BSIZE / 512);
    80006856:	00c52c83          	lw	s9,12(a0)
    8000685a:	001c9c9b          	slliw	s9,s9,0x1
    8000685e:	1c82                	slli	s9,s9,0x20
    80006860:	020cdc93          	srli	s9,s9,0x20

  acquire(&disk.vdisk_lock);
    80006864:	00024517          	auipc	a0,0x24
    80006868:	4e450513          	addi	a0,a0,1252 # 8002ad48 <disk+0x128>
    8000686c:	ffffa097          	auipc	ra,0xffffa
    80006870:	3cc080e7          	jalr	972(ra) # 80000c38 <acquire>
  for(int i = 0; i < 3; i++){
    80006874:	4981                	li	s3,0
  for(int i = 0; i < NUM; i++){
    80006876:	44a1                	li	s1,8
      disk.free[i] = 0;
    80006878:	00024b17          	auipc	s6,0x24
    8000687c:	3a8b0b13          	addi	s6,s6,936 # 8002ac20 <disk>
  for(int i = 0; i < 3; i++){
    80006880:	4a8d                	li	s5,3
  int idx[3];
  while(1){
    if(alloc3_desc(idx) == 0) {
      break;
    }
    sleep(&disk.free[0], &disk.vdisk_lock);
    80006882:	00024c17          	auipc	s8,0x24
    80006886:	4c6c0c13          	addi	s8,s8,1222 # 8002ad48 <disk+0x128>
    8000688a:	a0ad                	j	800068f4 <virtio_disk_rw+0xbc>
      disk.free[i] = 0;
    8000688c:	00fb0733          	add	a4,s6,a5
    80006890:	00070c23          	sb	zero,24(a4) # 10001018 <_entry-0x6fffefe8>
    idx[i] = alloc_desc();
    80006894:	c19c                	sw	a5,0(a1)
    if(idx[i] < 0){
    80006896:	0207c563          	bltz	a5,800068c0 <virtio_disk_rw+0x88>
  for(int i = 0; i < 3; i++){
    8000689a:	2905                	addiw	s2,s2,1
    8000689c:	0611                	addi	a2,a2,4 # 1004 <_entry-0x7fffeffc>
    8000689e:	05590f63          	beq	s2,s5,800068fc <virtio_disk_rw+0xc4>
    idx[i] = alloc_desc();
    800068a2:	85b2                	mv	a1,a2
  for(int i = 0; i < NUM; i++){
    800068a4:	00024717          	auipc	a4,0x24
    800068a8:	37c70713          	addi	a4,a4,892 # 8002ac20 <disk>
    800068ac:	87ce                	mv	a5,s3
    if(disk.free[i]){
    800068ae:	01874683          	lbu	a3,24(a4)
    800068b2:	fee9                	bnez	a3,8000688c <virtio_disk_rw+0x54>
  for(int i = 0; i < NUM; i++){
    800068b4:	2785                	addiw	a5,a5,1
    800068b6:	0705                	addi	a4,a4,1
    800068b8:	fe979be3          	bne	a5,s1,800068ae <virtio_disk_rw+0x76>
    idx[i] = alloc_desc();
    800068bc:	57fd                	li	a5,-1
    800068be:	c19c                	sw	a5,0(a1)
      for(int j = 0; j < i; j++)
    800068c0:	03205163          	blez	s2,800068e2 <virtio_disk_rw+0xaa>
        free_desc(idx[j]);
    800068c4:	f9042503          	lw	a0,-112(s0)
    800068c8:	00000097          	auipc	ra,0x0
    800068cc:	cc2080e7          	jalr	-830(ra) # 8000658a <free_desc>
      for(int j = 0; j < i; j++)
    800068d0:	4785                	li	a5,1
    800068d2:	0127d863          	bge	a5,s2,800068e2 <virtio_disk_rw+0xaa>
        free_desc(idx[j]);
    800068d6:	f9442503          	lw	a0,-108(s0)
    800068da:	00000097          	auipc	ra,0x0
    800068de:	cb0080e7          	jalr	-848(ra) # 8000658a <free_desc>
    sleep(&disk.free[0], &disk.vdisk_lock);
    800068e2:	85e2                	mv	a1,s8
    800068e4:	00024517          	auipc	a0,0x24
    800068e8:	35450513          	addi	a0,a0,852 # 8002ac38 <disk+0x18>
    800068ec:	ffffc097          	auipc	ra,0xffffc
    800068f0:	ad2080e7          	jalr	-1326(ra) # 800023be <sleep>
  for(int i = 0; i < 3; i++){
    800068f4:	f9040613          	addi	a2,s0,-112
    800068f8:	894e                	mv	s2,s3
    800068fa:	b765                	j	800068a2 <virtio_disk_rw+0x6a>
  }

  // format the three descriptors.
  // qemu's virtio-blk.c reads them.

  struct virtio_blk_req *buf0 = &disk.ops[idx[0]];
    800068fc:	f9042503          	lw	a0,-112(s0)
    80006900:	00451693          	slli	a3,a0,0x4

  if(write)
    80006904:	00024797          	auipc	a5,0x24
    80006908:	31c78793          	addi	a5,a5,796 # 8002ac20 <disk>
    8000690c:	00a50713          	addi	a4,a0,10
    80006910:	0712                	slli	a4,a4,0x4
    80006912:	973e                	add	a4,a4,a5
    80006914:	01703633          	snez	a2,s7
    80006918:	c710                	sw	a2,8(a4)
    buf0->type = VIRTIO_BLK_T_OUT; // write the disk
  else
    buf0->type = VIRTIO_BLK_T_IN; // read the disk
  buf0->reserved = 0;
    8000691a:	00072623          	sw	zero,12(a4)
  buf0->sector = sector;
    8000691e:	01973823          	sd	s9,16(a4)

  disk.desc[idx[0]].addr = (uint64) buf0;
    80006922:	6398                	ld	a4,0(a5)
    80006924:	9736                	add	a4,a4,a3
  struct virtio_blk_req *buf0 = &disk.ops[idx[0]];
    80006926:	0a868613          	addi	a2,a3,168
    8000692a:	963e                	add	a2,a2,a5
  disk.desc[idx[0]].addr = (uint64) buf0;
    8000692c:	e310                	sd	a2,0(a4)
  disk.desc[idx[0]].len = sizeof(struct virtio_blk_req);
    8000692e:	6390                	ld	a2,0(a5)
    80006930:	00d605b3          	add	a1,a2,a3
    80006934:	4741                	li	a4,16
    80006936:	c598                	sw	a4,8(a1)
  disk.desc[idx[0]].flags = VRING_DESC_F_NEXT;
    80006938:	4805                	li	a6,1
    8000693a:	01059623          	sh	a6,12(a1)
  disk.desc[idx[0]].next = idx[1];
    8000693e:	f9442703          	lw	a4,-108(s0)
    80006942:	00e59723          	sh	a4,14(a1)

  disk.desc[idx[1]].addr = (uint64) b->data;
    80006946:	0712                	slli	a4,a4,0x4
    80006948:	963a                	add	a2,a2,a4
    8000694a:	058a0593          	addi	a1,s4,88
    8000694e:	e20c                	sd	a1,0(a2)
  disk.desc[idx[1]].len = BSIZE;
    80006950:	0007b883          	ld	a7,0(a5)
    80006954:	9746                	add	a4,a4,a7
    80006956:	40000613          	li	a2,1024
    8000695a:	c710                	sw	a2,8(a4)
  if(write)
    8000695c:	001bb613          	seqz	a2,s7
    80006960:	0016161b          	slliw	a2,a2,0x1
    disk.desc[idx[1]].flags = 0; // device reads b->data
  else
    disk.desc[idx[1]].flags = VRING_DESC_F_WRITE; // device writes b->data
  disk.desc[idx[1]].flags |= VRING_DESC_F_NEXT;
    80006964:	00166613          	ori	a2,a2,1
    80006968:	00c71623          	sh	a2,12(a4)
  disk.desc[idx[1]].next = idx[2];
    8000696c:	f9842583          	lw	a1,-104(s0)
    80006970:	00b71723          	sh	a1,14(a4)

  disk.info[idx[0]].status = 0xff; // device writes 0 on success
    80006974:	00250613          	addi	a2,a0,2
    80006978:	0612                	slli	a2,a2,0x4
    8000697a:	963e                	add	a2,a2,a5
    8000697c:	577d                	li	a4,-1
    8000697e:	00e60823          	sb	a4,16(a2)
  disk.desc[idx[2]].addr = (uint64) &disk.info[idx[0]].status;
    80006982:	0592                	slli	a1,a1,0x4
    80006984:	98ae                	add	a7,a7,a1
    80006986:	03068713          	addi	a4,a3,48
    8000698a:	973e                	add	a4,a4,a5
    8000698c:	00e8b023          	sd	a4,0(a7)
  disk.desc[idx[2]].len = 1;
    80006990:	6398                	ld	a4,0(a5)
    80006992:	972e                	add	a4,a4,a1
    80006994:	01072423          	sw	a6,8(a4)
  disk.desc[idx[2]].flags = VRING_DESC_F_WRITE; // device writes the status
    80006998:	4689                	li	a3,2
    8000699a:	00d71623          	sh	a3,12(a4)
  disk.desc[idx[2]].next = 0;
    8000699e:	00071723          	sh	zero,14(a4)

  // record struct buf for virtio_disk_intr().
  b->disk = 1;
    800069a2:	010a2223          	sw	a6,4(s4)
  disk.info[idx[0]].b = b;
    800069a6:	01463423          	sd	s4,8(a2)

  // tell the device the first index in our chain of descriptors.
  disk.avail->ring[disk.avail->idx % NUM] = idx[0];
    800069aa:	6794                	ld	a3,8(a5)
    800069ac:	0026d703          	lhu	a4,2(a3)
    800069b0:	8b1d                	andi	a4,a4,7
    800069b2:	0706                	slli	a4,a4,0x1
    800069b4:	96ba                	add	a3,a3,a4
    800069b6:	00a69223          	sh	a0,4(a3)

  __sync_synchronize();
    800069ba:	0ff0000f          	fence

  // tell the device another avail ring entry is available.
  disk.avail->idx += 1; // not % NUM ...
    800069be:	6798                	ld	a4,8(a5)
    800069c0:	00275783          	lhu	a5,2(a4)
    800069c4:	2785                	addiw	a5,a5,1
    800069c6:	00f71123          	sh	a5,2(a4)

  __sync_synchronize();
    800069ca:	0ff0000f          	fence

  *R(VIRTIO_MMIO_QUEUE_NOTIFY) = 0; // value is queue number
    800069ce:	100017b7          	lui	a5,0x10001
    800069d2:	0407a823          	sw	zero,80(a5) # 10001050 <_entry-0x6fffefb0>

  // Wait for virtio_disk_intr() to say request has finished.
  while(b->disk == 1) {
    800069d6:	004a2783          	lw	a5,4(s4)
    sleep(b, &disk.vdisk_lock);
    800069da:	00024917          	auipc	s2,0x24
    800069de:	36e90913          	addi	s2,s2,878 # 8002ad48 <disk+0x128>
  while(b->disk == 1) {
    800069e2:	4485                	li	s1,1
    800069e4:	01079c63          	bne	a5,a6,800069fc <virtio_disk_rw+0x1c4>
    sleep(b, &disk.vdisk_lock);
    800069e8:	85ca                	mv	a1,s2
    800069ea:	8552                	mv	a0,s4
    800069ec:	ffffc097          	auipc	ra,0xffffc
    800069f0:	9d2080e7          	jalr	-1582(ra) # 800023be <sleep>
  while(b->disk == 1) {
    800069f4:	004a2783          	lw	a5,4(s4)
    800069f8:	fe9788e3          	beq	a5,s1,800069e8 <virtio_disk_rw+0x1b0>
  }

  disk.info[idx[0]].b = 0;
    800069fc:	f9042903          	lw	s2,-112(s0)
    80006a00:	00290713          	addi	a4,s2,2
    80006a04:	0712                	slli	a4,a4,0x4
    80006a06:	00024797          	auipc	a5,0x24
    80006a0a:	21a78793          	addi	a5,a5,538 # 8002ac20 <disk>
    80006a0e:	97ba                	add	a5,a5,a4
    80006a10:	0007b423          	sd	zero,8(a5)
    int flag = disk.desc[i].flags;
    80006a14:	00024997          	auipc	s3,0x24
    80006a18:	20c98993          	addi	s3,s3,524 # 8002ac20 <disk>
    80006a1c:	00491713          	slli	a4,s2,0x4
    80006a20:	0009b783          	ld	a5,0(s3)
    80006a24:	97ba                	add	a5,a5,a4
    80006a26:	00c7d483          	lhu	s1,12(a5)
    int nxt = disk.desc[i].next;
    80006a2a:	854a                	mv	a0,s2
    80006a2c:	00e7d903          	lhu	s2,14(a5)
    free_desc(i);
    80006a30:	00000097          	auipc	ra,0x0
    80006a34:	b5a080e7          	jalr	-1190(ra) # 8000658a <free_desc>
    if(flag & VRING_DESC_F_NEXT)
    80006a38:	8885                	andi	s1,s1,1
    80006a3a:	f0ed                	bnez	s1,80006a1c <virtio_disk_rw+0x1e4>
  free_chain(idx[0]);

  release(&disk.vdisk_lock);
    80006a3c:	00024517          	auipc	a0,0x24
    80006a40:	30c50513          	addi	a0,a0,780 # 8002ad48 <disk+0x128>
    80006a44:	ffffa097          	auipc	ra,0xffffa
    80006a48:	2a8080e7          	jalr	680(ra) # 80000cec <release>
}
    80006a4c:	70a6                	ld	ra,104(sp)
    80006a4e:	7406                	ld	s0,96(sp)
    80006a50:	64e6                	ld	s1,88(sp)
    80006a52:	6946                	ld	s2,80(sp)
    80006a54:	69a6                	ld	s3,72(sp)
    80006a56:	6a06                	ld	s4,64(sp)
    80006a58:	7ae2                	ld	s5,56(sp)
    80006a5a:	7b42                	ld	s6,48(sp)
    80006a5c:	7ba2                	ld	s7,40(sp)
    80006a5e:	7c02                	ld	s8,32(sp)
    80006a60:	6ce2                	ld	s9,24(sp)
    80006a62:	6165                	addi	sp,sp,112
    80006a64:	8082                	ret

0000000080006a66 <virtio_disk_intr>:

void
virtio_disk_intr()
{
    80006a66:	1101                	addi	sp,sp,-32
    80006a68:	ec06                	sd	ra,24(sp)
    80006a6a:	e822                	sd	s0,16(sp)
    80006a6c:	e426                	sd	s1,8(sp)
    80006a6e:	1000                	addi	s0,sp,32
  acquire(&disk.vdisk_lock);
    80006a70:	00024497          	auipc	s1,0x24
    80006a74:	1b048493          	addi	s1,s1,432 # 8002ac20 <disk>
    80006a78:	00024517          	auipc	a0,0x24
    80006a7c:	2d050513          	addi	a0,a0,720 # 8002ad48 <disk+0x128>
    80006a80:	ffffa097          	auipc	ra,0xffffa
    80006a84:	1b8080e7          	jalr	440(ra) # 80000c38 <acquire>
  // we've seen this interrupt, which the following line does.
  // this may race with the device writing new entries to
  // the "used" ring, in which case we may process the new
  // completion entries in this interrupt, and have nothing to do
  // in the next interrupt, which is harmless.
  *R(VIRTIO_MMIO_INTERRUPT_ACK) = *R(VIRTIO_MMIO_INTERRUPT_STATUS) & 0x3;
    80006a88:	100017b7          	lui	a5,0x10001
    80006a8c:	53b8                	lw	a4,96(a5)
    80006a8e:	8b0d                	andi	a4,a4,3
    80006a90:	100017b7          	lui	a5,0x10001
    80006a94:	d3f8                	sw	a4,100(a5)

  __sync_synchronize();
    80006a96:	0ff0000f          	fence

  // the device increments disk.used->idx when it
  // adds an entry to the used ring.

  while(disk.used_idx != disk.used->idx){
    80006a9a:	689c                	ld	a5,16(s1)
    80006a9c:	0204d703          	lhu	a4,32(s1)
    80006aa0:	0027d783          	lhu	a5,2(a5) # 10001002 <_entry-0x6fffeffe>
    80006aa4:	04f70863          	beq	a4,a5,80006af4 <virtio_disk_intr+0x8e>
    __sync_synchronize();
    80006aa8:	0ff0000f          	fence
    int id = disk.used->ring[disk.used_idx % NUM].id;
    80006aac:	6898                	ld	a4,16(s1)
    80006aae:	0204d783          	lhu	a5,32(s1)
    80006ab2:	8b9d                	andi	a5,a5,7
    80006ab4:	078e                	slli	a5,a5,0x3
    80006ab6:	97ba                	add	a5,a5,a4
    80006ab8:	43dc                	lw	a5,4(a5)

    if(disk.info[id].status != 0)
    80006aba:	00278713          	addi	a4,a5,2
    80006abe:	0712                	slli	a4,a4,0x4
    80006ac0:	9726                	add	a4,a4,s1
    80006ac2:	01074703          	lbu	a4,16(a4)
    80006ac6:	e721                	bnez	a4,80006b0e <virtio_disk_intr+0xa8>
      panic("virtio_disk_intr status");

    struct buf *b = disk.info[id].b;
    80006ac8:	0789                	addi	a5,a5,2
    80006aca:	0792                	slli	a5,a5,0x4
    80006acc:	97a6                	add	a5,a5,s1
    80006ace:	6788                	ld	a0,8(a5)
    b->disk = 0;   // disk is done with buf
    80006ad0:	00052223          	sw	zero,4(a0)
    wakeup(b);
    80006ad4:	ffffc097          	auipc	ra,0xffffc
    80006ad8:	95a080e7          	jalr	-1702(ra) # 8000242e <wakeup>

    disk.used_idx += 1;
    80006adc:	0204d783          	lhu	a5,32(s1)
    80006ae0:	2785                	addiw	a5,a5,1
    80006ae2:	17c2                	slli	a5,a5,0x30
    80006ae4:	93c1                	srli	a5,a5,0x30
    80006ae6:	02f49023          	sh	a5,32(s1)
  while(disk.used_idx != disk.used->idx){
    80006aea:	6898                	ld	a4,16(s1)
    80006aec:	00275703          	lhu	a4,2(a4)
    80006af0:	faf71ce3          	bne	a4,a5,80006aa8 <virtio_disk_intr+0x42>
  }

  release(&disk.vdisk_lock);
    80006af4:	00024517          	auipc	a0,0x24
    80006af8:	25450513          	addi	a0,a0,596 # 8002ad48 <disk+0x128>
    80006afc:	ffffa097          	auipc	ra,0xffffa
    80006b00:	1f0080e7          	jalr	496(ra) # 80000cec <release>
}
    80006b04:	60e2                	ld	ra,24(sp)
    80006b06:	6442                	ld	s0,16(sp)
    80006b08:	64a2                	ld	s1,8(sp)
    80006b0a:	6105                	addi	sp,sp,32
    80006b0c:	8082                	ret
      panic("virtio_disk_intr status");
    80006b0e:	00002517          	auipc	a0,0x2
    80006b12:	c0250513          	addi	a0,a0,-1022 # 80008710 <etext+0x710>
    80006b16:	ffffa097          	auipc	ra,0xffffa
    80006b1a:	a4a080e7          	jalr	-1462(ra) # 80000560 <panic>
	...

0000000080007000 <_trampoline>:
    80007000:	14051073          	csrw	sscratch,a0
    80007004:	02000537          	lui	a0,0x2000
    80007008:	357d                	addiw	a0,a0,-1 # 1ffffff <_entry-0x7e000001>
    8000700a:	0536                	slli	a0,a0,0xd
    8000700c:	02153423          	sd	ra,40(a0)
    80007010:	02253823          	sd	sp,48(a0)
    80007014:	02353c23          	sd	gp,56(a0)
    80007018:	04453023          	sd	tp,64(a0)
    8000701c:	04553423          	sd	t0,72(a0)
    80007020:	04653823          	sd	t1,80(a0)
    80007024:	04753c23          	sd	t2,88(a0)
    80007028:	f120                	sd	s0,96(a0)
    8000702a:	f524                	sd	s1,104(a0)
    8000702c:	fd2c                	sd	a1,120(a0)
    8000702e:	e150                	sd	a2,128(a0)
    80007030:	e554                	sd	a3,136(a0)
    80007032:	e958                	sd	a4,144(a0)
    80007034:	ed5c                	sd	a5,152(a0)
    80007036:	0b053023          	sd	a6,160(a0)
    8000703a:	0b153423          	sd	a7,168(a0)
    8000703e:	0b253823          	sd	s2,176(a0)
    80007042:	0b353c23          	sd	s3,184(a0)
    80007046:	0d453023          	sd	s4,192(a0)
    8000704a:	0d553423          	sd	s5,200(a0)
    8000704e:	0d653823          	sd	s6,208(a0)
    80007052:	0d753c23          	sd	s7,216(a0)
    80007056:	0f853023          	sd	s8,224(a0)
    8000705a:	0f953423          	sd	s9,232(a0)
    8000705e:	0fa53823          	sd	s10,240(a0)
    80007062:	0fb53c23          	sd	s11,248(a0)
    80007066:	11c53023          	sd	t3,256(a0)
    8000706a:	11d53423          	sd	t4,264(a0)
    8000706e:	11e53823          	sd	t5,272(a0)
    80007072:	11f53c23          	sd	t6,280(a0)
    80007076:	140022f3          	csrr	t0,sscratch
    8000707a:	06553823          	sd	t0,112(a0)
    8000707e:	00853103          	ld	sp,8(a0)
    80007082:	02053203          	ld	tp,32(a0)
    80007086:	01053283          	ld	t0,16(a0)
    8000708a:	00053303          	ld	t1,0(a0)
    8000708e:	12000073          	sfence.vma
    80007092:	18031073          	csrw	satp,t1
    80007096:	12000073          	sfence.vma
    8000709a:	8282                	jr	t0

000000008000709c <userret>:
    8000709c:	12000073          	sfence.vma
    800070a0:	18051073          	csrw	satp,a0
    800070a4:	12000073          	sfence.vma
    800070a8:	02000537          	lui	a0,0x2000
    800070ac:	357d                	addiw	a0,a0,-1 # 1ffffff <_entry-0x7e000001>
    800070ae:	0536                	slli	a0,a0,0xd
    800070b0:	02853083          	ld	ra,40(a0)
    800070b4:	03053103          	ld	sp,48(a0)
    800070b8:	03853183          	ld	gp,56(a0)
    800070bc:	04053203          	ld	tp,64(a0)
    800070c0:	04853283          	ld	t0,72(a0)
    800070c4:	05053303          	ld	t1,80(a0)
    800070c8:	05853383          	ld	t2,88(a0)
    800070cc:	7120                	ld	s0,96(a0)
    800070ce:	7524                	ld	s1,104(a0)
    800070d0:	7d2c                	ld	a1,120(a0)
    800070d2:	6150                	ld	a2,128(a0)
    800070d4:	6554                	ld	a3,136(a0)
    800070d6:	6958                	ld	a4,144(a0)
    800070d8:	6d5c                	ld	a5,152(a0)
    800070da:	0a053803          	ld	a6,160(a0)
    800070de:	0a853883          	ld	a7,168(a0)
    800070e2:	0b053903          	ld	s2,176(a0)
    800070e6:	0b853983          	ld	s3,184(a0)
    800070ea:	0c053a03          	ld	s4,192(a0)
    800070ee:	0c853a83          	ld	s5,200(a0)
    800070f2:	0d053b03          	ld	s6,208(a0)
    800070f6:	0d853b83          	ld	s7,216(a0)
    800070fa:	0e053c03          	ld	s8,224(a0)
    800070fe:	0e853c83          	ld	s9,232(a0)
    80007102:	0f053d03          	ld	s10,240(a0)
    80007106:	0f853d83          	ld	s11,248(a0)
    8000710a:	10053e03          	ld	t3,256(a0)
    8000710e:	10853e83          	ld	t4,264(a0)
    80007112:	11053f03          	ld	t5,272(a0)
    80007116:	11853f83          	ld	t6,280(a0)
    8000711a:	7928                	ld	a0,112(a0)
    8000711c:	10200073          	sret
	...
