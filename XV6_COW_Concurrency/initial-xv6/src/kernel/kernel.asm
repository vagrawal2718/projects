
kernel/kernel:     file format elf64-littleriscv


Disassembly of section .text:

0000000080000000 <_entry>:
    80000000:	00009117          	auipc	sp,0x9
    80000004:	a6010113          	addi	sp,sp,-1440 # 80008a60 <stack0>
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
    80000054:	8d070713          	addi	a4,a4,-1840 # 80008920 <timer_scratch>
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
    80000066:	20e78793          	addi	a5,a5,526 # 80006270 <timervec>
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
    8000009a:	7ff70713          	addi	a4,a4,2047 # ffffffffffffe7ff <end+0xffffffff7fdbc46f>
    8000009e:	8ff9                	and	a5,a5,a4
  x |= MSTATUS_MPP_S;
    800000a0:	6705                	lui	a4,0x1
    800000a2:	80070713          	addi	a4,a4,-2048 # 800 <_entry-0x7ffff800>
    800000a6:	8fd9                	or	a5,a5,a4
  asm volatile("csrw mstatus, %0" : : "r" (x));
    800000a8:	30079073          	csrw	mstatus,a5
  asm volatile("csrw mepc, %0" : : "r" (x));
    800000ac:	00001797          	auipc	a5,0x1
    800000b0:	f5c78793          	addi	a5,a5,-164 # 80001008 <main>
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
    8000012e:	68e080e7          	jalr	1678(ra) # 800027b8 <either_copyin>
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
    80000190:	8d450513          	addi	a0,a0,-1836 # 80010a60 <cons>
    80000194:	00001097          	auipc	ra,0x1
    80000198:	bda080e7          	jalr	-1062(ra) # 80000d6e <acquire>
  while(n > 0){
    // wait until interrupt handler has put some
    // input into cons.buffer.
    while(cons.r == cons.w){
    8000019c:	00011497          	auipc	s1,0x11
    800001a0:	8c448493          	addi	s1,s1,-1852 # 80010a60 <cons>
      if(killed(myproc())){
        release(&cons.lock);
        return -1;
      }
      sleep(&cons.r, &cons.lock);
    800001a4:	00011917          	auipc	s2,0x11
    800001a8:	95490913          	addi	s2,s2,-1708 # 80010af8 <cons+0x98>
  while(n > 0){
    800001ac:	0d305763          	blez	s3,8000027a <consoleread+0x10c>
    while(cons.r == cons.w){
    800001b0:	0984a783          	lw	a5,152(s1)
    800001b4:	09c4a703          	lw	a4,156(s1)
    800001b8:	0af71c63          	bne	a4,a5,80000270 <consoleread+0x102>
      if(killed(myproc())){
    800001bc:	00002097          	auipc	ra,0x2
    800001c0:	a7a080e7          	jalr	-1414(ra) # 80001c36 <myproc>
    800001c4:	00002097          	auipc	ra,0x2
    800001c8:	432080e7          	jalr	1074(ra) # 800025f6 <killed>
    800001cc:	e52d                	bnez	a0,80000236 <consoleread+0xc8>
      sleep(&cons.r, &cons.lock);
    800001ce:	85a6                	mv	a1,s1
    800001d0:	854a                	mv	a0,s2
    800001d2:	00002097          	auipc	ra,0x2
    800001d6:	14a080e7          	jalr	330(ra) # 8000231c <sleep>
    while(cons.r == cons.w){
    800001da:	0984a783          	lw	a5,152(s1)
    800001de:	09c4a703          	lw	a4,156(s1)
    800001e2:	fcf70de3          	beq	a4,a5,800001bc <consoleread+0x4e>
    800001e6:	ec5e                	sd	s7,24(sp)
    }

    c = cons.buf[cons.r++ % INPUT_BUF_SIZE];
    800001e8:	00011717          	auipc	a4,0x11
    800001ec:	87870713          	addi	a4,a4,-1928 # 80010a60 <cons>
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
    8000021e:	548080e7          	jalr	1352(ra) # 80002762 <either_copyout>
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
    80000236:	00011517          	auipc	a0,0x11
    8000023a:	82a50513          	addi	a0,a0,-2006 # 80010a60 <cons>
    8000023e:	00001097          	auipc	ra,0x1
    80000242:	be4080e7          	jalr	-1052(ra) # 80000e22 <release>
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
    80000268:	88f72a23          	sw	a5,-1900(a4) # 80010af8 <cons+0x98>
    8000026c:	6be2                	ld	s7,24(sp)
    8000026e:	a031                	j	8000027a <consoleread+0x10c>
    80000270:	ec5e                	sd	s7,24(sp)
    80000272:	bf9d                	j	800001e8 <consoleread+0x7a>
    80000274:	6be2                	ld	s7,24(sp)
    80000276:	a011                	j	8000027a <consoleread+0x10c>
    80000278:	6be2                	ld	s7,24(sp)
  release(&cons.lock);
    8000027a:	00010517          	auipc	a0,0x10
    8000027e:	7e650513          	addi	a0,a0,2022 # 80010a60 <cons>
    80000282:	00001097          	auipc	ra,0x1
    80000286:	ba0080e7          	jalr	-1120(ra) # 80000e22 <release>
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
    800002e6:	77e50513          	addi	a0,a0,1918 # 80010a60 <cons>
    800002ea:	00001097          	auipc	ra,0x1
    800002ee:	a84080e7          	jalr	-1404(ra) # 80000d6e <acquire>

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
    8000030c:	506080e7          	jalr	1286(ra) # 8000280e <procdump>
      }
    }
    break;
  }
  
  release(&cons.lock);
    80000310:	00010517          	auipc	a0,0x10
    80000314:	75050513          	addi	a0,a0,1872 # 80010a60 <cons>
    80000318:	00001097          	auipc	ra,0x1
    8000031c:	b0a080e7          	jalr	-1270(ra) # 80000e22 <release>
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
    80000336:	72e70713          	addi	a4,a4,1838 # 80010a60 <cons>
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
    80000360:	70478793          	addi	a5,a5,1796 # 80010a60 <cons>
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
    8000038e:	76e7a783          	lw	a5,1902(a5) # 80010af8 <cons+0x98>
    80000392:	9f1d                	subw	a4,a4,a5
    80000394:	08000793          	li	a5,128
    80000398:	f6f71ce3          	bne	a4,a5,80000310 <consoleintr+0x3a>
    8000039c:	a86d                	j	80000456 <consoleintr+0x180>
    8000039e:	e04a                	sd	s2,0(sp)
    while(cons.e != cons.w &&
    800003a0:	00010717          	auipc	a4,0x10
    800003a4:	6c070713          	addi	a4,a4,1728 # 80010a60 <cons>
    800003a8:	0a072783          	lw	a5,160(a4)
    800003ac:	09c72703          	lw	a4,156(a4)
          cons.buf[(cons.e-1) % INPUT_BUF_SIZE] != '\n'){
    800003b0:	00010497          	auipc	s1,0x10
    800003b4:	6b048493          	addi	s1,s1,1712 # 80010a60 <cons>
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
    800003fa:	66a70713          	addi	a4,a4,1642 # 80010a60 <cons>
    800003fe:	0a072783          	lw	a5,160(a4)
    80000402:	09c72703          	lw	a4,156(a4)
    80000406:	f0f705e3          	beq	a4,a5,80000310 <consoleintr+0x3a>
      cons.e--;
    8000040a:	37fd                	addiw	a5,a5,-1
    8000040c:	00010717          	auipc	a4,0x10
    80000410:	6ef72a23          	sw	a5,1780(a4) # 80010b00 <cons+0xa0>
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
    80000436:	62e78793          	addi	a5,a5,1582 # 80010a60 <cons>
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
    8000045a:	6ac7a323          	sw	a2,1702(a5) # 80010afc <cons+0x9c>
        wakeup(&cons.r);
    8000045e:	00010517          	auipc	a0,0x10
    80000462:	69a50513          	addi	a0,a0,1690 # 80010af8 <cons+0x98>
    80000466:	00002097          	auipc	ra,0x2
    8000046a:	f24080e7          	jalr	-220(ra) # 8000238a <wakeup>
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
    80000484:	5e050513          	addi	a0,a0,1504 # 80010a60 <cons>
    80000488:	00001097          	auipc	ra,0x1
    8000048c:	856080e7          	jalr	-1962(ra) # 80000cde <initlock>

  uartinit();
    80000490:	00000097          	auipc	ra,0x0
    80000494:	354080e7          	jalr	852(ra) # 800007e4 <uartinit>

  // connect read and write system calls
  // to consoleread and consolewrite.
  devsw[CONSOLE].read = consoleread;
    80000498:	00241797          	auipc	a5,0x241
    8000049c:	d6078793          	addi	a5,a5,-672 # 802411f8 <devsw>
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
    800004da:	28a60613          	addi	a2,a2,650 # 80008760 <digits>
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
    80000570:	5a07aa23          	sw	zero,1460(a5) # 80010b20 <pr+0x18>
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
    800005a4:	34f72023          	sw	a5,832(a4) # 800088e0 <panicked>
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
    800005ce:	556d2d03          	lw	s10,1366(s10) # 80010b20 <pr+0x18>
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
    8000060c:	158a8a93          	addi	s5,s5,344 # 80008760 <digits>
    switch(c){
    80000610:	07300c13          	li	s8,115
    80000614:	06400d93          	li	s11,100
    80000618:	a0b1                	j	80000664 <printf+0xba>
    acquire(&pr.lock);
    8000061a:	00010517          	auipc	a0,0x10
    8000061e:	4ee50513          	addi	a0,a0,1262 # 80010b08 <pr>
    80000622:	00000097          	auipc	ra,0x0
    80000626:	74c080e7          	jalr	1868(ra) # 80000d6e <acquire>
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
    800007a4:	36850513          	addi	a0,a0,872 # 80010b08 <pr>
    800007a8:	00000097          	auipc	ra,0x0
    800007ac:	67a080e7          	jalr	1658(ra) # 80000e22 <release>
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
    800007c0:	34c48493          	addi	s1,s1,844 # 80010b08 <pr>
    800007c4:	00008597          	auipc	a1,0x8
    800007c8:	86c58593          	addi	a1,a1,-1940 # 80008030 <etext+0x30>
    800007cc:	8526                	mv	a0,s1
    800007ce:	00000097          	auipc	ra,0x0
    800007d2:	510080e7          	jalr	1296(ra) # 80000cde <initlock>
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
    8000082c:	30050513          	addi	a0,a0,768 # 80010b28 <uart_tx_lock>
    80000830:	00000097          	auipc	ra,0x0
    80000834:	4ae080e7          	jalr	1198(ra) # 80000cde <initlock>
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
    80000850:	4d6080e7          	jalr	1238(ra) # 80000d22 <push_off>

  if(panicked){
    80000854:	00008797          	auipc	a5,0x8
    80000858:	08c7a783          	lw	a5,140(a5) # 800088e0 <panicked>
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
    8000087e:	548080e7          	jalr	1352(ra) # 80000dc2 <pop_off>
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
    80000892:	05a7b783          	ld	a5,90(a5) # 800088e8 <uart_tx_r>
    80000896:	00008717          	auipc	a4,0x8
    8000089a:	05a73703          	ld	a4,90(a4) # 800088f0 <uart_tx_w>
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
    800008c0:	26ca8a93          	addi	s5,s5,620 # 80010b28 <uart_tx_lock>
    uart_tx_r += 1;
    800008c4:	00008497          	auipc	s1,0x8
    800008c8:	02448493          	addi	s1,s1,36 # 800088e8 <uart_tx_r>
    
    // maybe uartputc() is waiting for space in the buffer.
    wakeup(&uart_tx_r);
    
    WriteReg(THR, c);
    800008cc:	10000a37          	lui	s4,0x10000
    if(uart_tx_w == uart_tx_r){
    800008d0:	00008997          	auipc	s3,0x8
    800008d4:	02098993          	addi	s3,s3,32 # 800088f0 <uart_tx_w>
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
    800008f6:	a98080e7          	jalr	-1384(ra) # 8000238a <wakeup>
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
    80000934:	1f850513          	addi	a0,a0,504 # 80010b28 <uart_tx_lock>
    80000938:	00000097          	auipc	ra,0x0
    8000093c:	436080e7          	jalr	1078(ra) # 80000d6e <acquire>
  if(panicked){
    80000940:	00008797          	auipc	a5,0x8
    80000944:	fa07a783          	lw	a5,-96(a5) # 800088e0 <panicked>
    80000948:	e7c9                	bnez	a5,800009d2 <uartputc+0xb4>
  while(uart_tx_w == uart_tx_r + UART_TX_BUF_SIZE){
    8000094a:	00008717          	auipc	a4,0x8
    8000094e:	fa673703          	ld	a4,-90(a4) # 800088f0 <uart_tx_w>
    80000952:	00008797          	auipc	a5,0x8
    80000956:	f967b783          	ld	a5,-106(a5) # 800088e8 <uart_tx_r>
    8000095a:	02078793          	addi	a5,a5,32
    sleep(&uart_tx_r, &uart_tx_lock);
    8000095e:	00010997          	auipc	s3,0x10
    80000962:	1ca98993          	addi	s3,s3,458 # 80010b28 <uart_tx_lock>
    80000966:	00008497          	auipc	s1,0x8
    8000096a:	f8248493          	addi	s1,s1,-126 # 800088e8 <uart_tx_r>
  while(uart_tx_w == uart_tx_r + UART_TX_BUF_SIZE){
    8000096e:	00008917          	auipc	s2,0x8
    80000972:	f8290913          	addi	s2,s2,-126 # 800088f0 <uart_tx_w>
    80000976:	00e79f63          	bne	a5,a4,80000994 <uartputc+0x76>
    sleep(&uart_tx_r, &uart_tx_lock);
    8000097a:	85ce                	mv	a1,s3
    8000097c:	8526                	mv	a0,s1
    8000097e:	00002097          	auipc	ra,0x2
    80000982:	99e080e7          	jalr	-1634(ra) # 8000231c <sleep>
  while(uart_tx_w == uart_tx_r + UART_TX_BUF_SIZE){
    80000986:	00093703          	ld	a4,0(s2)
    8000098a:	609c                	ld	a5,0(s1)
    8000098c:	02078793          	addi	a5,a5,32
    80000990:	fee785e3          	beq	a5,a4,8000097a <uartputc+0x5c>
  uart_tx_buf[uart_tx_w % UART_TX_BUF_SIZE] = c;
    80000994:	00010497          	auipc	s1,0x10
    80000998:	19448493          	addi	s1,s1,404 # 80010b28 <uart_tx_lock>
    8000099c:	01f77793          	andi	a5,a4,31
    800009a0:	97a6                	add	a5,a5,s1
    800009a2:	01478c23          	sb	s4,24(a5)
  uart_tx_w += 1;
    800009a6:	0705                	addi	a4,a4,1
    800009a8:	00008797          	auipc	a5,0x8
    800009ac:	f4e7b423          	sd	a4,-184(a5) # 800088f0 <uart_tx_w>
  uartstart();
    800009b0:	00000097          	auipc	ra,0x0
    800009b4:	ede080e7          	jalr	-290(ra) # 8000088e <uartstart>
  release(&uart_tx_lock);
    800009b8:	8526                	mv	a0,s1
    800009ba:	00000097          	auipc	ra,0x0
    800009be:	468080e7          	jalr	1128(ra) # 80000e22 <release>
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
    80000a20:	10c48493          	addi	s1,s1,268 # 80010b28 <uart_tx_lock>
    80000a24:	8526                	mv	a0,s1
    80000a26:	00000097          	auipc	ra,0x0
    80000a2a:	348080e7          	jalr	840(ra) # 80000d6e <acquire>
  uartstart();
    80000a2e:	00000097          	auipc	ra,0x0
    80000a32:	e60080e7          	jalr	-416(ra) # 8000088e <uartstart>
  release(&uart_tx_lock);
    80000a36:	8526                	mv	a0,s1
    80000a38:	00000097          	auipc	ra,0x0
    80000a3c:	3ea080e7          	jalr	1002(ra) # 80000e22 <release>
}
    80000a40:	60e2                	ld	ra,24(sp)
    80000a42:	6442                	ld	s0,16(sp)
    80000a44:	64a2                	ld	s1,8(sp)
    80000a46:	6105                	addi	sp,sp,32
    80000a48:	8082                	ret

0000000080000a4a <kfree>:
// Free the page of physical memory pointed at by pa,
// which normally should have been returned by a
// call to kalloc().  (The exception is when
// initializing the allocator; see kinit above.)
void kfree(void *pa)
{
    80000a4a:	1101                	addi	sp,sp,-32
    80000a4c:	ec06                	sd	ra,24(sp)
    80000a4e:	e822                	sd	s0,16(sp)
    80000a50:	e426                	sd	s1,8(sp)
    80000a52:	e04a                	sd	s2,0(sp)
    80000a54:	1000                	addi	s0,sp,32
  struct run *r;
  r = (struct run *)pa;
  if (((uint64)pa % PGSIZE) != 0 || (char *)pa < end || (uint64)pa >= PHYSTOP)
    80000a56:	03451793          	slli	a5,a0,0x34
    80000a5a:	ebbd                	bnez	a5,80000ad0 <kfree+0x86>
    80000a5c:	84aa                	mv	s1,a0
    80000a5e:	00242797          	auipc	a5,0x242
    80000a62:	93278793          	addi	a5,a5,-1742 # 80242390 <end>
    80000a66:	06f56563          	bltu	a0,a5,80000ad0 <kfree+0x86>
    80000a6a:	47c5                	li	a5,17
    80000a6c:	07ee                	slli	a5,a5,0x1b
    80000a6e:	06f57163          	bgeu	a0,a5,80000ad0 <kfree+0x86>
    panic("kfree");
	//when we free the page decraese the refcnt of the pa 
    //we need to acquire the lock
    //and get the really current cnt for the current fucntion
  acquire(&kmem.lock);
    80000a72:	00010517          	auipc	a0,0x10
    80000a76:	0ee50513          	addi	a0,a0,238 # 80010b60 <kmem>
    80000a7a:	00000097          	auipc	ra,0x0
    80000a7e:	2f4080e7          	jalr	756(ra) # 80000d6e <acquire>
  int pn = (uint64)r / PGSIZE;
    80000a82:	00c4d793          	srli	a5,s1,0xc
    80000a86:	2781                	sext.w	a5,a5
  if (refcnt[pn] < 1)
    80000a88:	00279693          	slli	a3,a5,0x2
    80000a8c:	00010717          	auipc	a4,0x10
    80000a90:	0f470713          	addi	a4,a4,244 # 80010b80 <refcnt>
    80000a94:	9736                	add	a4,a4,a3
    80000a96:	4318                	lw	a4,0(a4)
    80000a98:	04e05463          	blez	a4,80000ae0 <kfree+0x96>
    panic("kfree panic");
  refcnt[pn] -= 1;
    80000a9c:	377d                	addiw	a4,a4,-1
    80000a9e:	0007091b          	sext.w	s2,a4
    80000aa2:	078a                	slli	a5,a5,0x2
    80000aa4:	00010697          	auipc	a3,0x10
    80000aa8:	0dc68693          	addi	a3,a3,220 # 80010b80 <refcnt>
    80000aac:	97b6                	add	a5,a5,a3
    80000aae:	c398                	sw	a4,0(a5)
  int tmp = refcnt[pn];
  release(&kmem.lock);
    80000ab0:	00010517          	auipc	a0,0x10
    80000ab4:	0b050513          	addi	a0,a0,176 # 80010b60 <kmem>
    80000ab8:	00000097          	auipc	ra,0x0
    80000abc:	36a080e7          	jalr	874(ra) # 80000e22 <release>

  if (tmp >0)
    80000ac0:	03205863          	blez	s2,80000af0 <kfree+0xa6>

  acquire(&kmem.lock);
  r->next = kmem.freelist;
  kmem.freelist = r;
  release(&kmem.lock);
}
    80000ac4:	60e2                	ld	ra,24(sp)
    80000ac6:	6442                	ld	s0,16(sp)
    80000ac8:	64a2                	ld	s1,8(sp)
    80000aca:	6902                	ld	s2,0(sp)
    80000acc:	6105                	addi	sp,sp,32
    80000ace:	8082                	ret
    panic("kfree");
    80000ad0:	00007517          	auipc	a0,0x7
    80000ad4:	57050513          	addi	a0,a0,1392 # 80008040 <etext+0x40>
    80000ad8:	00000097          	auipc	ra,0x0
    80000adc:	a88080e7          	jalr	-1400(ra) # 80000560 <panic>
    panic("kfree panic");
    80000ae0:	00007517          	auipc	a0,0x7
    80000ae4:	56850513          	addi	a0,a0,1384 # 80008048 <etext+0x48>
    80000ae8:	00000097          	auipc	ra,0x0
    80000aec:	a78080e7          	jalr	-1416(ra) # 80000560 <panic>
  memset(pa, 1, PGSIZE);
    80000af0:	6605                	lui	a2,0x1
    80000af2:	4585                	li	a1,1
    80000af4:	8526                	mv	a0,s1
    80000af6:	00000097          	auipc	ra,0x0
    80000afa:	374080e7          	jalr	884(ra) # 80000e6a <memset>
  acquire(&kmem.lock);
    80000afe:	00010917          	auipc	s2,0x10
    80000b02:	06290913          	addi	s2,s2,98 # 80010b60 <kmem>
    80000b06:	854a                	mv	a0,s2
    80000b08:	00000097          	auipc	ra,0x0
    80000b0c:	266080e7          	jalr	614(ra) # 80000d6e <acquire>
  r->next = kmem.freelist;
    80000b10:	01893783          	ld	a5,24(s2)
    80000b14:	e09c                	sd	a5,0(s1)
  kmem.freelist = r;
    80000b16:	00993c23          	sd	s1,24(s2)
  release(&kmem.lock);
    80000b1a:	854a                	mv	a0,s2
    80000b1c:	00000097          	auipc	ra,0x0
    80000b20:	306080e7          	jalr	774(ra) # 80000e22 <release>
    80000b24:	b745                	j	80000ac4 <kfree+0x7a>

0000000080000b26 <freerange>:
{
    80000b26:	7139                	addi	sp,sp,-64
    80000b28:	fc06                	sd	ra,56(sp)
    80000b2a:	f822                	sd	s0,48(sp)
    80000b2c:	f426                	sd	s1,40(sp)
    80000b2e:	0080                	addi	s0,sp,64
  p = (char *)PGROUNDUP((uint64)pa_start);
    80000b30:	6785                	lui	a5,0x1
    80000b32:	fff78713          	addi	a4,a5,-1 # fff <_entry-0x7ffff001>
    80000b36:	953a                	add	a0,a0,a4
    80000b38:	777d                	lui	a4,0xfffff
    80000b3a:	00e574b3          	and	s1,a0,a4
  for (; p + PGSIZE <= (char *)pa_end; p += PGSIZE)
    80000b3e:	97a6                	add	a5,a5,s1
    80000b40:	04f5e463          	bltu	a1,a5,80000b88 <freerange+0x62>
    80000b44:	f04a                	sd	s2,32(sp)
    80000b46:	ec4e                	sd	s3,24(sp)
    80000b48:	e852                	sd	s4,16(sp)
    80000b4a:	e456                	sd	s5,8(sp)
    80000b4c:	e05a                	sd	s6,0(sp)
    80000b4e:	892e                	mv	s2,a1
    refcnt[(uint64)p / PGSIZE] = 1;
    80000b50:	00010b17          	auipc	s6,0x10
    80000b54:	030b0b13          	addi	s6,s6,48 # 80010b80 <refcnt>
    80000b58:	4a85                	li	s5,1
  for (; p + PGSIZE <= (char *)pa_end; p += PGSIZE)
    80000b5a:	6a05                	lui	s4,0x1
    80000b5c:	6989                	lui	s3,0x2
    refcnt[(uint64)p / PGSIZE] = 1;
    80000b5e:	00c4d793          	srli	a5,s1,0xc
    80000b62:	078a                	slli	a5,a5,0x2
    80000b64:	97da                	add	a5,a5,s6
    80000b66:	0157a023          	sw	s5,0(a5)
    kfree(p);
    80000b6a:	8526                	mv	a0,s1
    80000b6c:	00000097          	auipc	ra,0x0
    80000b70:	ede080e7          	jalr	-290(ra) # 80000a4a <kfree>
  for (; p + PGSIZE <= (char *)pa_end; p += PGSIZE)
    80000b74:	87a6                	mv	a5,s1
    80000b76:	94d2                	add	s1,s1,s4
    80000b78:	97ce                	add	a5,a5,s3
    80000b7a:	fef972e3          	bgeu	s2,a5,80000b5e <freerange+0x38>
    80000b7e:	7902                	ld	s2,32(sp)
    80000b80:	69e2                	ld	s3,24(sp)
    80000b82:	6a42                	ld	s4,16(sp)
    80000b84:	6aa2                	ld	s5,8(sp)
    80000b86:	6b02                	ld	s6,0(sp)
}
    80000b88:	70e2                	ld	ra,56(sp)
    80000b8a:	7442                	ld	s0,48(sp)
    80000b8c:	74a2                	ld	s1,40(sp)
    80000b8e:	6121                	addi	sp,sp,64
    80000b90:	8082                	ret

0000000080000b92 <kinit>:
{
    80000b92:	1141                	addi	sp,sp,-16
    80000b94:	e406                	sd	ra,8(sp)
    80000b96:	e022                	sd	s0,0(sp)
    80000b98:	0800                	addi	s0,sp,16
  initlock(&kmem.lock, "kmem");
    80000b9a:	00007597          	auipc	a1,0x7
    80000b9e:	4be58593          	addi	a1,a1,1214 # 80008058 <etext+0x58>
    80000ba2:	00010517          	auipc	a0,0x10
    80000ba6:	fbe50513          	addi	a0,a0,-66 # 80010b60 <kmem>
    80000baa:	00000097          	auipc	ra,0x0
    80000bae:	134080e7          	jalr	308(ra) # 80000cde <initlock>
  freerange(end, (void*)PHYSTOP);
    80000bb2:	45c5                	li	a1,17
    80000bb4:	05ee                	slli	a1,a1,0x1b
    80000bb6:	00241517          	auipc	a0,0x241
    80000bba:	7da50513          	addi	a0,a0,2010 # 80242390 <end>
    80000bbe:	00000097          	auipc	ra,0x0
    80000bc2:	f68080e7          	jalr	-152(ra) # 80000b26 <freerange>
}
    80000bc6:	60a2                	ld	ra,8(sp)
    80000bc8:	6402                	ld	s0,0(sp)
    80000bca:	0141                	addi	sp,sp,16
    80000bcc:	8082                	ret

0000000080000bce <kalloc>:
// Allocate one 4096-byte page of physical memory.
// Returns a pointer that the kernel can use.
// Returns 0 if the memory cannot be allocated.
void *
kalloc(void)
{
    80000bce:	1101                	addi	sp,sp,-32
    80000bd0:	ec06                	sd	ra,24(sp)
    80000bd2:	e822                	sd	s0,16(sp)
    80000bd4:	e426                	sd	s1,8(sp)
    80000bd6:	1000                	addi	s0,sp,32
  struct run *r;

  acquire(&kmem.lock);
    80000bd8:	00010497          	auipc	s1,0x10
    80000bdc:	f8848493          	addi	s1,s1,-120 # 80010b60 <kmem>
    80000be0:	8526                	mv	a0,s1
    80000be2:	00000097          	auipc	ra,0x0
    80000be6:	18c080e7          	jalr	396(ra) # 80000d6e <acquire>
  r = kmem.freelist;
    80000bea:	6c84                	ld	s1,24(s1)

  if (r)
    80000bec:	c4a5                	beqz	s1,80000c54 <kalloc+0x86>
  {
    int pn = (uint64)r / PGSIZE;
    80000bee:	00c4d793          	srli	a5,s1,0xc
    80000bf2:	2781                	sext.w	a5,a5
    if(refcnt[pn]!=0){
    80000bf4:	00279693          	slli	a3,a5,0x2
    80000bf8:	00010717          	auipc	a4,0x10
    80000bfc:	f8870713          	addi	a4,a4,-120 # 80010b80 <refcnt>
    80000c00:	9736                	add	a4,a4,a3
    80000c02:	4318                	lw	a4,0(a4)
    80000c04:	e321                	bnez	a4,80000c44 <kalloc+0x76>
      panic("refcnt kalloc");
    }
    refcnt[pn] = 1;
    80000c06:	078a                	slli	a5,a5,0x2
    80000c08:	00010717          	auipc	a4,0x10
    80000c0c:	f7870713          	addi	a4,a4,-136 # 80010b80 <refcnt>
    80000c10:	97ba                	add	a5,a5,a4
    80000c12:	4705                	li	a4,1
    80000c14:	c398                	sw	a4,0(a5)
    kmem.freelist = r->next;
    80000c16:	609c                	ld	a5,0(s1)
    80000c18:	00010517          	auipc	a0,0x10
    80000c1c:	f4850513          	addi	a0,a0,-184 # 80010b60 <kmem>
    80000c20:	ed1c                	sd	a5,24(a0)
  }

  release(&kmem.lock);
    80000c22:	00000097          	auipc	ra,0x0
    80000c26:	200080e7          	jalr	512(ra) # 80000e22 <release>

  if (r)
    memset((char *)r, 5, PGSIZE); // fill with junk
    80000c2a:	6605                	lui	a2,0x1
    80000c2c:	4595                	li	a1,5
    80000c2e:	8526                	mv	a0,s1
    80000c30:	00000097          	auipc	ra,0x0
    80000c34:	23a080e7          	jalr	570(ra) # 80000e6a <memset>
  return (void *)r;
}
    80000c38:	8526                	mv	a0,s1
    80000c3a:	60e2                	ld	ra,24(sp)
    80000c3c:	6442                	ld	s0,16(sp)
    80000c3e:	64a2                	ld	s1,8(sp)
    80000c40:	6105                	addi	sp,sp,32
    80000c42:	8082                	ret
      panic("refcnt kalloc");
    80000c44:	00007517          	auipc	a0,0x7
    80000c48:	41c50513          	addi	a0,a0,1052 # 80008060 <etext+0x60>
    80000c4c:	00000097          	auipc	ra,0x0
    80000c50:	914080e7          	jalr	-1772(ra) # 80000560 <panic>
  release(&kmem.lock);
    80000c54:	00010517          	auipc	a0,0x10
    80000c58:	f0c50513          	addi	a0,a0,-244 # 80010b60 <kmem>
    80000c5c:	00000097          	auipc	ra,0x0
    80000c60:	1c6080e7          	jalr	454(ra) # 80000e22 <release>
  if (r)
    80000c64:	bfd1                	j	80000c38 <kalloc+0x6a>

0000000080000c66 <increase>:


void increase(uint64 pa)
{ 
    80000c66:	1101                	addi	sp,sp,-32
    80000c68:	ec06                	sd	ra,24(sp)
    80000c6a:	e822                	sd	s0,16(sp)
    80000c6c:	e426                	sd	s1,8(sp)
    80000c6e:	1000                	addi	s0,sp,32
    80000c70:	84aa                	mv	s1,a0
    //acquire the lock
  acquire(&kmem.lock);
    80000c72:	00010517          	auipc	a0,0x10
    80000c76:	eee50513          	addi	a0,a0,-274 # 80010b60 <kmem>
    80000c7a:	00000097          	auipc	ra,0x0
    80000c7e:	0f4080e7          	jalr	244(ra) # 80000d6e <acquire>
  int pn = pa / PGSIZE;
  if(pa>PHYSTOP || refcnt[pn]<1){
    80000c82:	4745                	li	a4,17
    80000c84:	076e                	slli	a4,a4,0x1b
    80000c86:	04976463          	bltu	a4,s1,80000cce <increase+0x68>
    80000c8a:	00c4d793          	srli	a5,s1,0xc
    80000c8e:	2781                	sext.w	a5,a5
    80000c90:	00279693          	slli	a3,a5,0x2
    80000c94:	00010717          	auipc	a4,0x10
    80000c98:	eec70713          	addi	a4,a4,-276 # 80010b80 <refcnt>
    80000c9c:	9736                	add	a4,a4,a3
    80000c9e:	4318                	lw	a4,0(a4)
    80000ca0:	02e05763          	blez	a4,80000cce <increase+0x68>
    panic("increase ref cnt");
  }
  refcnt[pn]++;
    80000ca4:	078a                	slli	a5,a5,0x2
    80000ca6:	00010697          	auipc	a3,0x10
    80000caa:	eda68693          	addi	a3,a3,-294 # 80010b80 <refcnt>
    80000cae:	97b6                	add	a5,a5,a3
    80000cb0:	2705                	addiw	a4,a4,1
    80000cb2:	c398                	sw	a4,0(a5)
  release(&kmem.lock);
    80000cb4:	00010517          	auipc	a0,0x10
    80000cb8:	eac50513          	addi	a0,a0,-340 # 80010b60 <kmem>
    80000cbc:	00000097          	auipc	ra,0x0
    80000cc0:	166080e7          	jalr	358(ra) # 80000e22 <release>
}
    80000cc4:	60e2                	ld	ra,24(sp)
    80000cc6:	6442                	ld	s0,16(sp)
    80000cc8:	64a2                	ld	s1,8(sp)
    80000cca:	6105                	addi	sp,sp,32
    80000ccc:	8082                	ret
    panic("increase ref cnt");
    80000cce:	00007517          	auipc	a0,0x7
    80000cd2:	3a250513          	addi	a0,a0,930 # 80008070 <etext+0x70>
    80000cd6:	00000097          	auipc	ra,0x0
    80000cda:	88a080e7          	jalr	-1910(ra) # 80000560 <panic>

0000000080000cde <initlock>:
#include "proc.h"
#include "defs.h"

void
initlock(struct spinlock *lk, char *name)
{
    80000cde:	1141                	addi	sp,sp,-16
    80000ce0:	e422                	sd	s0,8(sp)
    80000ce2:	0800                	addi	s0,sp,16
  lk->name = name;
    80000ce4:	e50c                	sd	a1,8(a0)
  lk->locked = 0;
    80000ce6:	00052023          	sw	zero,0(a0)
  lk->cpu = 0;
    80000cea:	00053823          	sd	zero,16(a0)
}
    80000cee:	6422                	ld	s0,8(sp)
    80000cf0:	0141                	addi	sp,sp,16
    80000cf2:	8082                	ret

0000000080000cf4 <holding>:
// Interrupts must be off.
int
holding(struct spinlock *lk)
{
  int r;
  r = (lk->locked && lk->cpu == mycpu());
    80000cf4:	411c                	lw	a5,0(a0)
    80000cf6:	e399                	bnez	a5,80000cfc <holding+0x8>
    80000cf8:	4501                	li	a0,0
  return r;
}
    80000cfa:	8082                	ret
{
    80000cfc:	1101                	addi	sp,sp,-32
    80000cfe:	ec06                	sd	ra,24(sp)
    80000d00:	e822                	sd	s0,16(sp)
    80000d02:	e426                	sd	s1,8(sp)
    80000d04:	1000                	addi	s0,sp,32
  r = (lk->locked && lk->cpu == mycpu());
    80000d06:	6904                	ld	s1,16(a0)
    80000d08:	00001097          	auipc	ra,0x1
    80000d0c:	f12080e7          	jalr	-238(ra) # 80001c1a <mycpu>
    80000d10:	40a48533          	sub	a0,s1,a0
    80000d14:	00153513          	seqz	a0,a0
}
    80000d18:	60e2                	ld	ra,24(sp)
    80000d1a:	6442                	ld	s0,16(sp)
    80000d1c:	64a2                	ld	s1,8(sp)
    80000d1e:	6105                	addi	sp,sp,32
    80000d20:	8082                	ret

0000000080000d22 <push_off>:
// it takes two pop_off()s to undo two push_off()s.  Also, if interrupts
// are initially off, then push_off, pop_off leaves them off.

void
push_off(void)
{
    80000d22:	1101                	addi	sp,sp,-32
    80000d24:	ec06                	sd	ra,24(sp)
    80000d26:	e822                	sd	s0,16(sp)
    80000d28:	e426                	sd	s1,8(sp)
    80000d2a:	1000                	addi	s0,sp,32
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80000d2c:	100024f3          	csrr	s1,sstatus
    80000d30:	100027f3          	csrr	a5,sstatus
  w_sstatus(r_sstatus() & ~SSTATUS_SIE);
    80000d34:	9bf5                	andi	a5,a5,-3
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80000d36:	10079073          	csrw	sstatus,a5
  int old = intr_get();

  intr_off();
  if(mycpu()->noff == 0)
    80000d3a:	00001097          	auipc	ra,0x1
    80000d3e:	ee0080e7          	jalr	-288(ra) # 80001c1a <mycpu>
    80000d42:	5d3c                	lw	a5,120(a0)
    80000d44:	cf89                	beqz	a5,80000d5e <push_off+0x3c>
    mycpu()->intena = old;
  mycpu()->noff += 1;
    80000d46:	00001097          	auipc	ra,0x1
    80000d4a:	ed4080e7          	jalr	-300(ra) # 80001c1a <mycpu>
    80000d4e:	5d3c                	lw	a5,120(a0)
    80000d50:	2785                	addiw	a5,a5,1
    80000d52:	dd3c                	sw	a5,120(a0)
}
    80000d54:	60e2                	ld	ra,24(sp)
    80000d56:	6442                	ld	s0,16(sp)
    80000d58:	64a2                	ld	s1,8(sp)
    80000d5a:	6105                	addi	sp,sp,32
    80000d5c:	8082                	ret
    mycpu()->intena = old;
    80000d5e:	00001097          	auipc	ra,0x1
    80000d62:	ebc080e7          	jalr	-324(ra) # 80001c1a <mycpu>
  return (x & SSTATUS_SIE) != 0;
    80000d66:	8085                	srli	s1,s1,0x1
    80000d68:	8885                	andi	s1,s1,1
    80000d6a:	dd64                	sw	s1,124(a0)
    80000d6c:	bfe9                	j	80000d46 <push_off+0x24>

0000000080000d6e <acquire>:
{
    80000d6e:	1101                	addi	sp,sp,-32
    80000d70:	ec06                	sd	ra,24(sp)
    80000d72:	e822                	sd	s0,16(sp)
    80000d74:	e426                	sd	s1,8(sp)
    80000d76:	1000                	addi	s0,sp,32
    80000d78:	84aa                	mv	s1,a0
  push_off(); // disable interrupts to avoid deadlock.
    80000d7a:	00000097          	auipc	ra,0x0
    80000d7e:	fa8080e7          	jalr	-88(ra) # 80000d22 <push_off>
  if(holding(lk))
    80000d82:	8526                	mv	a0,s1
    80000d84:	00000097          	auipc	ra,0x0
    80000d88:	f70080e7          	jalr	-144(ra) # 80000cf4 <holding>
  while(__sync_lock_test_and_set(&lk->locked, 1) != 0)
    80000d8c:	4705                	li	a4,1
  if(holding(lk))
    80000d8e:	e115                	bnez	a0,80000db2 <acquire+0x44>
  while(__sync_lock_test_and_set(&lk->locked, 1) != 0)
    80000d90:	87ba                	mv	a5,a4
    80000d92:	0cf4a7af          	amoswap.w.aq	a5,a5,(s1)
    80000d96:	2781                	sext.w	a5,a5
    80000d98:	ffe5                	bnez	a5,80000d90 <acquire+0x22>
  __sync_synchronize();
    80000d9a:	0ff0000f          	fence
  lk->cpu = mycpu();
    80000d9e:	00001097          	auipc	ra,0x1
    80000da2:	e7c080e7          	jalr	-388(ra) # 80001c1a <mycpu>
    80000da6:	e888                	sd	a0,16(s1)
}
    80000da8:	60e2                	ld	ra,24(sp)
    80000daa:	6442                	ld	s0,16(sp)
    80000dac:	64a2                	ld	s1,8(sp)
    80000dae:	6105                	addi	sp,sp,32
    80000db0:	8082                	ret
    panic("acquire");
    80000db2:	00007517          	auipc	a0,0x7
    80000db6:	2d650513          	addi	a0,a0,726 # 80008088 <etext+0x88>
    80000dba:	fffff097          	auipc	ra,0xfffff
    80000dbe:	7a6080e7          	jalr	1958(ra) # 80000560 <panic>

0000000080000dc2 <pop_off>:

void
pop_off(void)
{
    80000dc2:	1141                	addi	sp,sp,-16
    80000dc4:	e406                	sd	ra,8(sp)
    80000dc6:	e022                	sd	s0,0(sp)
    80000dc8:	0800                	addi	s0,sp,16
  struct cpu *c = mycpu();
    80000dca:	00001097          	auipc	ra,0x1
    80000dce:	e50080e7          	jalr	-432(ra) # 80001c1a <mycpu>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80000dd2:	100027f3          	csrr	a5,sstatus
  return (x & SSTATUS_SIE) != 0;
    80000dd6:	8b89                	andi	a5,a5,2
  if(intr_get())
    80000dd8:	e78d                	bnez	a5,80000e02 <pop_off+0x40>
    panic("pop_off - interruptible");
  if(c->noff < 1)
    80000dda:	5d3c                	lw	a5,120(a0)
    80000ddc:	02f05b63          	blez	a5,80000e12 <pop_off+0x50>
    panic("pop_off");
  c->noff -= 1;
    80000de0:	37fd                	addiw	a5,a5,-1
    80000de2:	0007871b          	sext.w	a4,a5
    80000de6:	dd3c                	sw	a5,120(a0)
  if(c->noff == 0 && c->intena)
    80000de8:	eb09                	bnez	a4,80000dfa <pop_off+0x38>
    80000dea:	5d7c                	lw	a5,124(a0)
    80000dec:	c799                	beqz	a5,80000dfa <pop_off+0x38>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80000dee:	100027f3          	csrr	a5,sstatus
  w_sstatus(r_sstatus() | SSTATUS_SIE);
    80000df2:	0027e793          	ori	a5,a5,2
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80000df6:	10079073          	csrw	sstatus,a5
    intr_on();
}
    80000dfa:	60a2                	ld	ra,8(sp)
    80000dfc:	6402                	ld	s0,0(sp)
    80000dfe:	0141                	addi	sp,sp,16
    80000e00:	8082                	ret
    panic("pop_off - interruptible");
    80000e02:	00007517          	auipc	a0,0x7
    80000e06:	28e50513          	addi	a0,a0,654 # 80008090 <etext+0x90>
    80000e0a:	fffff097          	auipc	ra,0xfffff
    80000e0e:	756080e7          	jalr	1878(ra) # 80000560 <panic>
    panic("pop_off");
    80000e12:	00007517          	auipc	a0,0x7
    80000e16:	29650513          	addi	a0,a0,662 # 800080a8 <etext+0xa8>
    80000e1a:	fffff097          	auipc	ra,0xfffff
    80000e1e:	746080e7          	jalr	1862(ra) # 80000560 <panic>

0000000080000e22 <release>:
{
    80000e22:	1101                	addi	sp,sp,-32
    80000e24:	ec06                	sd	ra,24(sp)
    80000e26:	e822                	sd	s0,16(sp)
    80000e28:	e426                	sd	s1,8(sp)
    80000e2a:	1000                	addi	s0,sp,32
    80000e2c:	84aa                	mv	s1,a0
  if(!holding(lk))
    80000e2e:	00000097          	auipc	ra,0x0
    80000e32:	ec6080e7          	jalr	-314(ra) # 80000cf4 <holding>
    80000e36:	c115                	beqz	a0,80000e5a <release+0x38>
  lk->cpu = 0;
    80000e38:	0004b823          	sd	zero,16(s1)
  __sync_synchronize();
    80000e3c:	0ff0000f          	fence
  __sync_lock_release(&lk->locked);
    80000e40:	0f50000f          	fence	iorw,ow
    80000e44:	0804a02f          	amoswap.w	zero,zero,(s1)
  pop_off();
    80000e48:	00000097          	auipc	ra,0x0
    80000e4c:	f7a080e7          	jalr	-134(ra) # 80000dc2 <pop_off>
}
    80000e50:	60e2                	ld	ra,24(sp)
    80000e52:	6442                	ld	s0,16(sp)
    80000e54:	64a2                	ld	s1,8(sp)
    80000e56:	6105                	addi	sp,sp,32
    80000e58:	8082                	ret
    panic("release");
    80000e5a:	00007517          	auipc	a0,0x7
    80000e5e:	25650513          	addi	a0,a0,598 # 800080b0 <etext+0xb0>
    80000e62:	fffff097          	auipc	ra,0xfffff
    80000e66:	6fe080e7          	jalr	1790(ra) # 80000560 <panic>

0000000080000e6a <memset>:
#include "types.h"

void*
memset(void *dst, int c, uint n)
{
    80000e6a:	1141                	addi	sp,sp,-16
    80000e6c:	e422                	sd	s0,8(sp)
    80000e6e:	0800                	addi	s0,sp,16
  char *cdst = (char *) dst;
  int i;
  for(i = 0; i < n; i++){
    80000e70:	ca19                	beqz	a2,80000e86 <memset+0x1c>
    80000e72:	87aa                	mv	a5,a0
    80000e74:	1602                	slli	a2,a2,0x20
    80000e76:	9201                	srli	a2,a2,0x20
    80000e78:	00a60733          	add	a4,a2,a0
    cdst[i] = c;
    80000e7c:	00b78023          	sb	a1,0(a5)
  for(i = 0; i < n; i++){
    80000e80:	0785                	addi	a5,a5,1
    80000e82:	fee79de3          	bne	a5,a4,80000e7c <memset+0x12>
  }
  return dst;
}
    80000e86:	6422                	ld	s0,8(sp)
    80000e88:	0141                	addi	sp,sp,16
    80000e8a:	8082                	ret

0000000080000e8c <memcmp>:

int
memcmp(const void *v1, const void *v2, uint n)
{
    80000e8c:	1141                	addi	sp,sp,-16
    80000e8e:	e422                	sd	s0,8(sp)
    80000e90:	0800                	addi	s0,sp,16
  const uchar *s1, *s2;

  s1 = v1;
  s2 = v2;
  while(n-- > 0){
    80000e92:	ca05                	beqz	a2,80000ec2 <memcmp+0x36>
    80000e94:	fff6069b          	addiw	a3,a2,-1 # fff <_entry-0x7ffff001>
    80000e98:	1682                	slli	a3,a3,0x20
    80000e9a:	9281                	srli	a3,a3,0x20
    80000e9c:	0685                	addi	a3,a3,1
    80000e9e:	96aa                	add	a3,a3,a0
    if(*s1 != *s2)
    80000ea0:	00054783          	lbu	a5,0(a0)
    80000ea4:	0005c703          	lbu	a4,0(a1)
    80000ea8:	00e79863          	bne	a5,a4,80000eb8 <memcmp+0x2c>
      return *s1 - *s2;
    s1++, s2++;
    80000eac:	0505                	addi	a0,a0,1
    80000eae:	0585                	addi	a1,a1,1
  while(n-- > 0){
    80000eb0:	fed518e3          	bne	a0,a3,80000ea0 <memcmp+0x14>
  }

  return 0;
    80000eb4:	4501                	li	a0,0
    80000eb6:	a019                	j	80000ebc <memcmp+0x30>
      return *s1 - *s2;
    80000eb8:	40e7853b          	subw	a0,a5,a4
}
    80000ebc:	6422                	ld	s0,8(sp)
    80000ebe:	0141                	addi	sp,sp,16
    80000ec0:	8082                	ret
  return 0;
    80000ec2:	4501                	li	a0,0
    80000ec4:	bfe5                	j	80000ebc <memcmp+0x30>

0000000080000ec6 <memmove>:

void*
memmove(void *dst, const void *src, uint n)
{
    80000ec6:	1141                	addi	sp,sp,-16
    80000ec8:	e422                	sd	s0,8(sp)
    80000eca:	0800                	addi	s0,sp,16
  const char *s;
  char *d;

  if(n == 0)
    80000ecc:	c205                	beqz	a2,80000eec <memmove+0x26>
    return dst;
  
  s = src;
  d = dst;
  if(s < d && s + n > d){
    80000ece:	02a5e263          	bltu	a1,a0,80000ef2 <memmove+0x2c>
    s += n;
    d += n;
    while(n-- > 0)
      *--d = *--s;
  } else
    while(n-- > 0)
    80000ed2:	1602                	slli	a2,a2,0x20
    80000ed4:	9201                	srli	a2,a2,0x20
    80000ed6:	00c587b3          	add	a5,a1,a2
{
    80000eda:	872a                	mv	a4,a0
      *d++ = *s++;
    80000edc:	0585                	addi	a1,a1,1
    80000ede:	0705                	addi	a4,a4,1
    80000ee0:	fff5c683          	lbu	a3,-1(a1)
    80000ee4:	fed70fa3          	sb	a3,-1(a4)
    while(n-- > 0)
    80000ee8:	feb79ae3          	bne	a5,a1,80000edc <memmove+0x16>

  return dst;
}
    80000eec:	6422                	ld	s0,8(sp)
    80000eee:	0141                	addi	sp,sp,16
    80000ef0:	8082                	ret
  if(s < d && s + n > d){
    80000ef2:	02061693          	slli	a3,a2,0x20
    80000ef6:	9281                	srli	a3,a3,0x20
    80000ef8:	00d58733          	add	a4,a1,a3
    80000efc:	fce57be3          	bgeu	a0,a4,80000ed2 <memmove+0xc>
    d += n;
    80000f00:	96aa                	add	a3,a3,a0
    while(n-- > 0)
    80000f02:	fff6079b          	addiw	a5,a2,-1
    80000f06:	1782                	slli	a5,a5,0x20
    80000f08:	9381                	srli	a5,a5,0x20
    80000f0a:	fff7c793          	not	a5,a5
    80000f0e:	97ba                	add	a5,a5,a4
      *--d = *--s;
    80000f10:	177d                	addi	a4,a4,-1
    80000f12:	16fd                	addi	a3,a3,-1
    80000f14:	00074603          	lbu	a2,0(a4)
    80000f18:	00c68023          	sb	a2,0(a3)
    while(n-- > 0)
    80000f1c:	fef71ae3          	bne	a4,a5,80000f10 <memmove+0x4a>
    80000f20:	b7f1                	j	80000eec <memmove+0x26>

0000000080000f22 <memcpy>:

// memcpy exists to placate GCC.  Use memmove.
void*
memcpy(void *dst, const void *src, uint n)
{
    80000f22:	1141                	addi	sp,sp,-16
    80000f24:	e406                	sd	ra,8(sp)
    80000f26:	e022                	sd	s0,0(sp)
    80000f28:	0800                	addi	s0,sp,16
  return memmove(dst, src, n);
    80000f2a:	00000097          	auipc	ra,0x0
    80000f2e:	f9c080e7          	jalr	-100(ra) # 80000ec6 <memmove>
}
    80000f32:	60a2                	ld	ra,8(sp)
    80000f34:	6402                	ld	s0,0(sp)
    80000f36:	0141                	addi	sp,sp,16
    80000f38:	8082                	ret

0000000080000f3a <strncmp>:

int
strncmp(const char *p, const char *q, uint n)
{
    80000f3a:	1141                	addi	sp,sp,-16
    80000f3c:	e422                	sd	s0,8(sp)
    80000f3e:	0800                	addi	s0,sp,16
  while(n > 0 && *p && *p == *q)
    80000f40:	ce11                	beqz	a2,80000f5c <strncmp+0x22>
    80000f42:	00054783          	lbu	a5,0(a0)
    80000f46:	cf89                	beqz	a5,80000f60 <strncmp+0x26>
    80000f48:	0005c703          	lbu	a4,0(a1)
    80000f4c:	00f71a63          	bne	a4,a5,80000f60 <strncmp+0x26>
    n--, p++, q++;
    80000f50:	367d                	addiw	a2,a2,-1
    80000f52:	0505                	addi	a0,a0,1
    80000f54:	0585                	addi	a1,a1,1
  while(n > 0 && *p && *p == *q)
    80000f56:	f675                	bnez	a2,80000f42 <strncmp+0x8>
  if(n == 0)
    return 0;
    80000f58:	4501                	li	a0,0
    80000f5a:	a801                	j	80000f6a <strncmp+0x30>
    80000f5c:	4501                	li	a0,0
    80000f5e:	a031                	j	80000f6a <strncmp+0x30>
  return (uchar)*p - (uchar)*q;
    80000f60:	00054503          	lbu	a0,0(a0)
    80000f64:	0005c783          	lbu	a5,0(a1)
    80000f68:	9d1d                	subw	a0,a0,a5
}
    80000f6a:	6422                	ld	s0,8(sp)
    80000f6c:	0141                	addi	sp,sp,16
    80000f6e:	8082                	ret

0000000080000f70 <strncpy>:

char*
strncpy(char *s, const char *t, int n)
{
    80000f70:	1141                	addi	sp,sp,-16
    80000f72:	e422                	sd	s0,8(sp)
    80000f74:	0800                	addi	s0,sp,16
  char *os;

  os = s;
  while(n-- > 0 && (*s++ = *t++) != 0)
    80000f76:	87aa                	mv	a5,a0
    80000f78:	86b2                	mv	a3,a2
    80000f7a:	367d                	addiw	a2,a2,-1
    80000f7c:	02d05563          	blez	a3,80000fa6 <strncpy+0x36>
    80000f80:	0785                	addi	a5,a5,1
    80000f82:	0005c703          	lbu	a4,0(a1)
    80000f86:	fee78fa3          	sb	a4,-1(a5)
    80000f8a:	0585                	addi	a1,a1,1
    80000f8c:	f775                	bnez	a4,80000f78 <strncpy+0x8>
    ;
  while(n-- > 0)
    80000f8e:	873e                	mv	a4,a5
    80000f90:	9fb5                	addw	a5,a5,a3
    80000f92:	37fd                	addiw	a5,a5,-1
    80000f94:	00c05963          	blez	a2,80000fa6 <strncpy+0x36>
    *s++ = 0;
    80000f98:	0705                	addi	a4,a4,1
    80000f9a:	fe070fa3          	sb	zero,-1(a4)
  while(n-- > 0)
    80000f9e:	40e786bb          	subw	a3,a5,a4
    80000fa2:	fed04be3          	bgtz	a3,80000f98 <strncpy+0x28>
  return os;
}
    80000fa6:	6422                	ld	s0,8(sp)
    80000fa8:	0141                	addi	sp,sp,16
    80000faa:	8082                	ret

0000000080000fac <safestrcpy>:

// Like strncpy but guaranteed to NUL-terminate.
char*
safestrcpy(char *s, const char *t, int n)
{
    80000fac:	1141                	addi	sp,sp,-16
    80000fae:	e422                	sd	s0,8(sp)
    80000fb0:	0800                	addi	s0,sp,16
  char *os;

  os = s;
  if(n <= 0)
    80000fb2:	02c05363          	blez	a2,80000fd8 <safestrcpy+0x2c>
    80000fb6:	fff6069b          	addiw	a3,a2,-1
    80000fba:	1682                	slli	a3,a3,0x20
    80000fbc:	9281                	srli	a3,a3,0x20
    80000fbe:	96ae                	add	a3,a3,a1
    80000fc0:	87aa                	mv	a5,a0
    return os;
  while(--n > 0 && (*s++ = *t++) != 0)
    80000fc2:	00d58963          	beq	a1,a3,80000fd4 <safestrcpy+0x28>
    80000fc6:	0585                	addi	a1,a1,1
    80000fc8:	0785                	addi	a5,a5,1
    80000fca:	fff5c703          	lbu	a4,-1(a1)
    80000fce:	fee78fa3          	sb	a4,-1(a5)
    80000fd2:	fb65                	bnez	a4,80000fc2 <safestrcpy+0x16>
    ;
  *s = 0;
    80000fd4:	00078023          	sb	zero,0(a5)
  return os;
}
    80000fd8:	6422                	ld	s0,8(sp)
    80000fda:	0141                	addi	sp,sp,16
    80000fdc:	8082                	ret

0000000080000fde <strlen>:

int
strlen(const char *s)
{
    80000fde:	1141                	addi	sp,sp,-16
    80000fe0:	e422                	sd	s0,8(sp)
    80000fe2:	0800                	addi	s0,sp,16
  int n;

  for(n = 0; s[n]; n++)
    80000fe4:	00054783          	lbu	a5,0(a0)
    80000fe8:	cf91                	beqz	a5,80001004 <strlen+0x26>
    80000fea:	0505                	addi	a0,a0,1
    80000fec:	87aa                	mv	a5,a0
    80000fee:	86be                	mv	a3,a5
    80000ff0:	0785                	addi	a5,a5,1
    80000ff2:	fff7c703          	lbu	a4,-1(a5)
    80000ff6:	ff65                	bnez	a4,80000fee <strlen+0x10>
    80000ff8:	40a6853b          	subw	a0,a3,a0
    80000ffc:	2505                	addiw	a0,a0,1
    ;
  return n;
}
    80000ffe:	6422                	ld	s0,8(sp)
    80001000:	0141                	addi	sp,sp,16
    80001002:	8082                	ret
  for(n = 0; s[n]; n++)
    80001004:	4501                	li	a0,0
    80001006:	bfe5                	j	80000ffe <strlen+0x20>

0000000080001008 <main>:
volatile static int started = 0;

// start() jumps here in supervisor mode on all CPUs.
void
main()
{
    80001008:	1141                	addi	sp,sp,-16
    8000100a:	e406                	sd	ra,8(sp)
    8000100c:	e022                	sd	s0,0(sp)
    8000100e:	0800                	addi	s0,sp,16
  if(cpuid() == 0){
    80001010:	00001097          	auipc	ra,0x1
    80001014:	bfa080e7          	jalr	-1030(ra) # 80001c0a <cpuid>
    virtio_disk_init(); // emulated hard disk
    userinit();      // first user process
    __sync_synchronize();
    started = 1;
  } else {
    while(started == 0)
    80001018:	00008717          	auipc	a4,0x8
    8000101c:	8e070713          	addi	a4,a4,-1824 # 800088f8 <started>
  if(cpuid() == 0){
    80001020:	c139                	beqz	a0,80001066 <main+0x5e>
    while(started == 0)
    80001022:	431c                	lw	a5,0(a4)
    80001024:	2781                	sext.w	a5,a5
    80001026:	dff5                	beqz	a5,80001022 <main+0x1a>
      ;
    __sync_synchronize();
    80001028:	0ff0000f          	fence
    printf("hart %d starting\n", cpuid());
    8000102c:	00001097          	auipc	ra,0x1
    80001030:	bde080e7          	jalr	-1058(ra) # 80001c0a <cpuid>
    80001034:	85aa                	mv	a1,a0
    80001036:	00007517          	auipc	a0,0x7
    8000103a:	09a50513          	addi	a0,a0,154 # 800080d0 <etext+0xd0>
    8000103e:	fffff097          	auipc	ra,0xfffff
    80001042:	56c080e7          	jalr	1388(ra) # 800005aa <printf>
    kvminithart();    // turn on paging
    80001046:	00000097          	auipc	ra,0x0
    8000104a:	0d8080e7          	jalr	216(ra) # 8000111e <kvminithart>
    trapinithart();   // install kernel trap vector
    8000104e:	00002097          	auipc	ra,0x2
    80001052:	aba080e7          	jalr	-1350(ra) # 80002b08 <trapinithart>
    plicinithart();   // ask PLIC for device interrupts
    80001056:	00005097          	auipc	ra,0x5
    8000105a:	25e080e7          	jalr	606(ra) # 800062b4 <plicinithart>
  }

  scheduler();        
    8000105e:	00001097          	auipc	ra,0x1
    80001062:	0fa080e7          	jalr	250(ra) # 80002158 <scheduler>
    consoleinit();
    80001066:	fffff097          	auipc	ra,0xfffff
    8000106a:	40a080e7          	jalr	1034(ra) # 80000470 <consoleinit>
    printfinit();
    8000106e:	fffff097          	auipc	ra,0xfffff
    80001072:	744080e7          	jalr	1860(ra) # 800007b2 <printfinit>
    printf("\n");
    80001076:	00007517          	auipc	a0,0x7
    8000107a:	f9a50513          	addi	a0,a0,-102 # 80008010 <etext+0x10>
    8000107e:	fffff097          	auipc	ra,0xfffff
    80001082:	52c080e7          	jalr	1324(ra) # 800005aa <printf>
    printf("xv6 kernel is booting\n");
    80001086:	00007517          	auipc	a0,0x7
    8000108a:	03250513          	addi	a0,a0,50 # 800080b8 <etext+0xb8>
    8000108e:	fffff097          	auipc	ra,0xfffff
    80001092:	51c080e7          	jalr	1308(ra) # 800005aa <printf>
    printf("\n");
    80001096:	00007517          	auipc	a0,0x7
    8000109a:	f7a50513          	addi	a0,a0,-134 # 80008010 <etext+0x10>
    8000109e:	fffff097          	auipc	ra,0xfffff
    800010a2:	50c080e7          	jalr	1292(ra) # 800005aa <printf>
    kinit();         // physical page allocator
    800010a6:	00000097          	auipc	ra,0x0
    800010aa:	aec080e7          	jalr	-1300(ra) # 80000b92 <kinit>
    kvminit();       // create kernel page table
    800010ae:	00000097          	auipc	ra,0x0
    800010b2:	326080e7          	jalr	806(ra) # 800013d4 <kvminit>
    kvminithart();   // turn on paging
    800010b6:	00000097          	auipc	ra,0x0
    800010ba:	068080e7          	jalr	104(ra) # 8000111e <kvminithart>
    procinit();      // process table
    800010be:	00001097          	auipc	ra,0x1
    800010c2:	a88080e7          	jalr	-1400(ra) # 80001b46 <procinit>
    trapinit();      // trap vectors
    800010c6:	00002097          	auipc	ra,0x2
    800010ca:	a1a080e7          	jalr	-1510(ra) # 80002ae0 <trapinit>
    trapinithart();  // install kernel trap vector
    800010ce:	00002097          	auipc	ra,0x2
    800010d2:	a3a080e7          	jalr	-1478(ra) # 80002b08 <trapinithart>
    plicinit();      // set up interrupt controller
    800010d6:	00005097          	auipc	ra,0x5
    800010da:	1c4080e7          	jalr	452(ra) # 8000629a <plicinit>
    plicinithart();  // ask PLIC for device interrupts
    800010de:	00005097          	auipc	ra,0x5
    800010e2:	1d6080e7          	jalr	470(ra) # 800062b4 <plicinithart>
    binit();         // buffer cache
    800010e6:	00002097          	auipc	ra,0x2
    800010ea:	298080e7          	jalr	664(ra) # 8000337e <binit>
    iinit();         // inode table
    800010ee:	00003097          	auipc	ra,0x3
    800010f2:	94e080e7          	jalr	-1714(ra) # 80003a3c <iinit>
    fileinit();      // file table
    800010f6:	00004097          	auipc	ra,0x4
    800010fa:	8fe080e7          	jalr	-1794(ra) # 800049f4 <fileinit>
    virtio_disk_init(); // emulated hard disk
    800010fe:	00005097          	auipc	ra,0x5
    80001102:	2be080e7          	jalr	702(ra) # 800063bc <virtio_disk_init>
    userinit();      // first user process
    80001106:	00001097          	auipc	ra,0x1
    8000110a:	e2a080e7          	jalr	-470(ra) # 80001f30 <userinit>
    __sync_synchronize();
    8000110e:	0ff0000f          	fence
    started = 1;
    80001112:	4785                	li	a5,1
    80001114:	00007717          	auipc	a4,0x7
    80001118:	7ef72223          	sw	a5,2020(a4) # 800088f8 <started>
    8000111c:	b789                	j	8000105e <main+0x56>

000000008000111e <kvminithart>:
}

// Switch h/w page table register to the kernel's page table,
// and enable paging.
void kvminithart()
{
    8000111e:	1141                	addi	sp,sp,-16
    80001120:	e422                	sd	s0,8(sp)
    80001122:	0800                	addi	s0,sp,16
// flush the TLB.
static inline void
sfence_vma()
{
  // the zero, zero means flush all TLB entries.
  asm volatile("sfence.vma zero, zero");
    80001124:	12000073          	sfence.vma
  // wait for any previous writes to the page table memory to finish.
  sfence_vma();

  w_satp(MAKE_SATP(kernel_pagetable));
    80001128:	00007797          	auipc	a5,0x7
    8000112c:	7d87b783          	ld	a5,2008(a5) # 80008900 <kernel_pagetable>
    80001130:	83b1                	srli	a5,a5,0xc
    80001132:	577d                	li	a4,-1
    80001134:	177e                	slli	a4,a4,0x3f
    80001136:	8fd9                	or	a5,a5,a4
  asm volatile("csrw satp, %0" : : "r" (x));
    80001138:	18079073          	csrw	satp,a5
  asm volatile("sfence.vma zero, zero");
    8000113c:	12000073          	sfence.vma

  // flush stale entries from the TLB.
  sfence_vma();
}
    80001140:	6422                	ld	s0,8(sp)
    80001142:	0141                	addi	sp,sp,16
    80001144:	8082                	ret

0000000080001146 <walk>:
//   21..29 -- 9 bits of level-1 index.
//   12..20 -- 9 bits of level-0 index.
//    0..11 -- 12 bits of byte offset within the page.
pte_t *
walk(pagetable_t pagetable, uint64 va, int alloc)
{
    80001146:	7139                	addi	sp,sp,-64
    80001148:	fc06                	sd	ra,56(sp)
    8000114a:	f822                	sd	s0,48(sp)
    8000114c:	f426                	sd	s1,40(sp)
    8000114e:	f04a                	sd	s2,32(sp)
    80001150:	ec4e                	sd	s3,24(sp)
    80001152:	e852                	sd	s4,16(sp)
    80001154:	e456                	sd	s5,8(sp)
    80001156:	e05a                	sd	s6,0(sp)
    80001158:	0080                	addi	s0,sp,64
    8000115a:	84aa                	mv	s1,a0
    8000115c:	89ae                	mv	s3,a1
    8000115e:	8ab2                	mv	s5,a2
  if (va >= MAXVA)
    80001160:	57fd                	li	a5,-1
    80001162:	83e9                	srli	a5,a5,0x1a
    80001164:	4a79                	li	s4,30
    panic("walk");

  for (int level = 2; level > 0; level--)
    80001166:	4b31                	li	s6,12
  if (va >= MAXVA)
    80001168:	04b7f263          	bgeu	a5,a1,800011ac <walk+0x66>
    panic("walk");
    8000116c:	00007517          	auipc	a0,0x7
    80001170:	f7c50513          	addi	a0,a0,-132 # 800080e8 <etext+0xe8>
    80001174:	fffff097          	auipc	ra,0xfffff
    80001178:	3ec080e7          	jalr	1004(ra) # 80000560 <panic>
    {
      pagetable = (pagetable_t)PTE2PA(*pte);
    }
    else
    {
      if (!alloc || (pagetable = (pde_t *)kalloc()) == 0)
    8000117c:	060a8663          	beqz	s5,800011e8 <walk+0xa2>
    80001180:	00000097          	auipc	ra,0x0
    80001184:	a4e080e7          	jalr	-1458(ra) # 80000bce <kalloc>
    80001188:	84aa                	mv	s1,a0
    8000118a:	c529                	beqz	a0,800011d4 <walk+0x8e>
        return 0;
      memset(pagetable, 0, PGSIZE);
    8000118c:	6605                	lui	a2,0x1
    8000118e:	4581                	li	a1,0
    80001190:	00000097          	auipc	ra,0x0
    80001194:	cda080e7          	jalr	-806(ra) # 80000e6a <memset>
      *pte = PA2PTE(pagetable) | PTE_V;
    80001198:	00c4d793          	srli	a5,s1,0xc
    8000119c:	07aa                	slli	a5,a5,0xa
    8000119e:	0017e793          	ori	a5,a5,1
    800011a2:	00f93023          	sd	a5,0(s2)
  for (int level = 2; level > 0; level--)
    800011a6:	3a5d                	addiw	s4,s4,-9 # ff7 <_entry-0x7ffff009>
    800011a8:	036a0063          	beq	s4,s6,800011c8 <walk+0x82>
    pte_t *pte = &pagetable[PX(level, va)];
    800011ac:	0149d933          	srl	s2,s3,s4
    800011b0:	1ff97913          	andi	s2,s2,511
    800011b4:	090e                	slli	s2,s2,0x3
    800011b6:	9926                	add	s2,s2,s1
    if (*pte & PTE_V)
    800011b8:	00093483          	ld	s1,0(s2)
    800011bc:	0014f793          	andi	a5,s1,1
    800011c0:	dfd5                	beqz	a5,8000117c <walk+0x36>
      pagetable = (pagetable_t)PTE2PA(*pte);
    800011c2:	80a9                	srli	s1,s1,0xa
    800011c4:	04b2                	slli	s1,s1,0xc
    800011c6:	b7c5                	j	800011a6 <walk+0x60>
    }
  }
  return &pagetable[PX(0, va)];
    800011c8:	00c9d513          	srli	a0,s3,0xc
    800011cc:	1ff57513          	andi	a0,a0,511
    800011d0:	050e                	slli	a0,a0,0x3
    800011d2:	9526                	add	a0,a0,s1
}
    800011d4:	70e2                	ld	ra,56(sp)
    800011d6:	7442                	ld	s0,48(sp)
    800011d8:	74a2                	ld	s1,40(sp)
    800011da:	7902                	ld	s2,32(sp)
    800011dc:	69e2                	ld	s3,24(sp)
    800011de:	6a42                	ld	s4,16(sp)
    800011e0:	6aa2                	ld	s5,8(sp)
    800011e2:	6b02                	ld	s6,0(sp)
    800011e4:	6121                	addi	sp,sp,64
    800011e6:	8082                	ret
        return 0;
    800011e8:	4501                	li	a0,0
    800011ea:	b7ed                	j	800011d4 <walk+0x8e>

00000000800011ec <walkaddr>:
walkaddr(pagetable_t pagetable, uint64 va)
{
  pte_t *pte;
  uint64 pa;

  if (va >= MAXVA)
    800011ec:	57fd                	li	a5,-1
    800011ee:	83e9                	srli	a5,a5,0x1a
    800011f0:	00b7f463          	bgeu	a5,a1,800011f8 <walkaddr+0xc>
    return 0;
    800011f4:	4501                	li	a0,0
    return 0;
  if ((*pte & PTE_U) == 0)
    return 0;
  pa = PTE2PA(*pte);
  return pa;
}
    800011f6:	8082                	ret
{
    800011f8:	1141                	addi	sp,sp,-16
    800011fa:	e406                	sd	ra,8(sp)
    800011fc:	e022                	sd	s0,0(sp)
    800011fe:	0800                	addi	s0,sp,16
  pte = walk(pagetable, va, 0);
    80001200:	4601                	li	a2,0
    80001202:	00000097          	auipc	ra,0x0
    80001206:	f44080e7          	jalr	-188(ra) # 80001146 <walk>
  if (pte == 0)
    8000120a:	c105                	beqz	a0,8000122a <walkaddr+0x3e>
  if ((*pte & PTE_V) == 0)
    8000120c:	611c                	ld	a5,0(a0)
  if ((*pte & PTE_U) == 0)
    8000120e:	0117f693          	andi	a3,a5,17
    80001212:	4745                	li	a4,17
    return 0;
    80001214:	4501                	li	a0,0
  if ((*pte & PTE_U) == 0)
    80001216:	00e68663          	beq	a3,a4,80001222 <walkaddr+0x36>
}
    8000121a:	60a2                	ld	ra,8(sp)
    8000121c:	6402                	ld	s0,0(sp)
    8000121e:	0141                	addi	sp,sp,16
    80001220:	8082                	ret
  pa = PTE2PA(*pte);
    80001222:	83a9                	srli	a5,a5,0xa
    80001224:	00c79513          	slli	a0,a5,0xc
  return pa;
    80001228:	bfcd                	j	8000121a <walkaddr+0x2e>
    return 0;
    8000122a:	4501                	li	a0,0
    8000122c:	b7fd                	j	8000121a <walkaddr+0x2e>

000000008000122e <mappages>:
// Create PTEs for virtual addresses starting at va that refer to
// physical addresses starting at pa. va and size might not
// be page-aligned. Returns 0 on success, -1 if walk() couldn't
// allocate a needed page-table page.
int mappages(pagetable_t pagetable, uint64 va, uint64 size, uint64 pa, int perm)
{
    8000122e:	715d                	addi	sp,sp,-80
    80001230:	e486                	sd	ra,72(sp)
    80001232:	e0a2                	sd	s0,64(sp)
    80001234:	fc26                	sd	s1,56(sp)
    80001236:	f84a                	sd	s2,48(sp)
    80001238:	f44e                	sd	s3,40(sp)
    8000123a:	f052                	sd	s4,32(sp)
    8000123c:	ec56                	sd	s5,24(sp)
    8000123e:	e85a                	sd	s6,16(sp)
    80001240:	e45e                	sd	s7,8(sp)
    80001242:	0880                	addi	s0,sp,80
  uint64 a, last;
  pte_t *pte;

  if (size == 0)
    80001244:	c639                	beqz	a2,80001292 <mappages+0x64>
    80001246:	8aaa                	mv	s5,a0
    80001248:	8b3a                	mv	s6,a4
    panic("mappages: size");

  a = PGROUNDDOWN(va);
    8000124a:	777d                	lui	a4,0xfffff
    8000124c:	00e5f7b3          	and	a5,a1,a4
  last = PGROUNDDOWN(va + size - 1);
    80001250:	fff58993          	addi	s3,a1,-1
    80001254:	99b2                	add	s3,s3,a2
    80001256:	00e9f9b3          	and	s3,s3,a4
  a = PGROUNDDOWN(va);
    8000125a:	893e                	mv	s2,a5
    8000125c:	40f68a33          	sub	s4,a3,a5
    if (*pte & PTE_V)
      panic("mappages: remap");
    *pte = PA2PTE(pa) | perm | PTE_V;
    if (a == last)
      break;
    a += PGSIZE;
    80001260:	6b85                	lui	s7,0x1
    80001262:	014904b3          	add	s1,s2,s4
    if ((pte = walk(pagetable, a, 1)) == 0)
    80001266:	4605                	li	a2,1
    80001268:	85ca                	mv	a1,s2
    8000126a:	8556                	mv	a0,s5
    8000126c:	00000097          	auipc	ra,0x0
    80001270:	eda080e7          	jalr	-294(ra) # 80001146 <walk>
    80001274:	cd1d                	beqz	a0,800012b2 <mappages+0x84>
    if (*pte & PTE_V)
    80001276:	611c                	ld	a5,0(a0)
    80001278:	8b85                	andi	a5,a5,1
    8000127a:	e785                	bnez	a5,800012a2 <mappages+0x74>
    *pte = PA2PTE(pa) | perm | PTE_V;
    8000127c:	80b1                	srli	s1,s1,0xc
    8000127e:	04aa                	slli	s1,s1,0xa
    80001280:	0164e4b3          	or	s1,s1,s6
    80001284:	0014e493          	ori	s1,s1,1
    80001288:	e104                	sd	s1,0(a0)
    if (a == last)
    8000128a:	05390063          	beq	s2,s3,800012ca <mappages+0x9c>
    a += PGSIZE;
    8000128e:	995e                	add	s2,s2,s7
    if ((pte = walk(pagetable, a, 1)) == 0)
    80001290:	bfc9                	j	80001262 <mappages+0x34>
    panic("mappages: size");
    80001292:	00007517          	auipc	a0,0x7
    80001296:	e5e50513          	addi	a0,a0,-418 # 800080f0 <etext+0xf0>
    8000129a:	fffff097          	auipc	ra,0xfffff
    8000129e:	2c6080e7          	jalr	710(ra) # 80000560 <panic>
      panic("mappages: remap");
    800012a2:	00007517          	auipc	a0,0x7
    800012a6:	e5e50513          	addi	a0,a0,-418 # 80008100 <etext+0x100>
    800012aa:	fffff097          	auipc	ra,0xfffff
    800012ae:	2b6080e7          	jalr	694(ra) # 80000560 <panic>
      return -1;
    800012b2:	557d                	li	a0,-1
    pa += PGSIZE;
  }
  return 0;
}
    800012b4:	60a6                	ld	ra,72(sp)
    800012b6:	6406                	ld	s0,64(sp)
    800012b8:	74e2                	ld	s1,56(sp)
    800012ba:	7942                	ld	s2,48(sp)
    800012bc:	79a2                	ld	s3,40(sp)
    800012be:	7a02                	ld	s4,32(sp)
    800012c0:	6ae2                	ld	s5,24(sp)
    800012c2:	6b42                	ld	s6,16(sp)
    800012c4:	6ba2                	ld	s7,8(sp)
    800012c6:	6161                	addi	sp,sp,80
    800012c8:	8082                	ret
  return 0;
    800012ca:	4501                	li	a0,0
    800012cc:	b7e5                	j	800012b4 <mappages+0x86>

00000000800012ce <kvmmap>:
{
    800012ce:	1141                	addi	sp,sp,-16
    800012d0:	e406                	sd	ra,8(sp)
    800012d2:	e022                	sd	s0,0(sp)
    800012d4:	0800                	addi	s0,sp,16
    800012d6:	87b6                	mv	a5,a3
  if (mappages(kpgtbl, va, sz, pa, perm) != 0)
    800012d8:	86b2                	mv	a3,a2
    800012da:	863e                	mv	a2,a5
    800012dc:	00000097          	auipc	ra,0x0
    800012e0:	f52080e7          	jalr	-174(ra) # 8000122e <mappages>
    800012e4:	e509                	bnez	a0,800012ee <kvmmap+0x20>
}
    800012e6:	60a2                	ld	ra,8(sp)
    800012e8:	6402                	ld	s0,0(sp)
    800012ea:	0141                	addi	sp,sp,16
    800012ec:	8082                	ret
    panic("kvmmap");
    800012ee:	00007517          	auipc	a0,0x7
    800012f2:	e2250513          	addi	a0,a0,-478 # 80008110 <etext+0x110>
    800012f6:	fffff097          	auipc	ra,0xfffff
    800012fa:	26a080e7          	jalr	618(ra) # 80000560 <panic>

00000000800012fe <kvmmake>:
{
    800012fe:	1101                	addi	sp,sp,-32
    80001300:	ec06                	sd	ra,24(sp)
    80001302:	e822                	sd	s0,16(sp)
    80001304:	e426                	sd	s1,8(sp)
    80001306:	e04a                	sd	s2,0(sp)
    80001308:	1000                	addi	s0,sp,32
  kpgtbl = (pagetable_t)kalloc();
    8000130a:	00000097          	auipc	ra,0x0
    8000130e:	8c4080e7          	jalr	-1852(ra) # 80000bce <kalloc>
    80001312:	84aa                	mv	s1,a0
  memset(kpgtbl, 0, PGSIZE);
    80001314:	6605                	lui	a2,0x1
    80001316:	4581                	li	a1,0
    80001318:	00000097          	auipc	ra,0x0
    8000131c:	b52080e7          	jalr	-1198(ra) # 80000e6a <memset>
  kvmmap(kpgtbl, UART0, UART0, PGSIZE, PTE_R | PTE_W);
    80001320:	4719                	li	a4,6
    80001322:	6685                	lui	a3,0x1
    80001324:	10000637          	lui	a2,0x10000
    80001328:	100005b7          	lui	a1,0x10000
    8000132c:	8526                	mv	a0,s1
    8000132e:	00000097          	auipc	ra,0x0
    80001332:	fa0080e7          	jalr	-96(ra) # 800012ce <kvmmap>
  kvmmap(kpgtbl, VIRTIO0, VIRTIO0, PGSIZE, PTE_R | PTE_W);
    80001336:	4719                	li	a4,6
    80001338:	6685                	lui	a3,0x1
    8000133a:	10001637          	lui	a2,0x10001
    8000133e:	100015b7          	lui	a1,0x10001
    80001342:	8526                	mv	a0,s1
    80001344:	00000097          	auipc	ra,0x0
    80001348:	f8a080e7          	jalr	-118(ra) # 800012ce <kvmmap>
  kvmmap(kpgtbl, PLIC, PLIC, 0x400000, PTE_R | PTE_W);
    8000134c:	4719                	li	a4,6
    8000134e:	004006b7          	lui	a3,0x400
    80001352:	0c000637          	lui	a2,0xc000
    80001356:	0c0005b7          	lui	a1,0xc000
    8000135a:	8526                	mv	a0,s1
    8000135c:	00000097          	auipc	ra,0x0
    80001360:	f72080e7          	jalr	-142(ra) # 800012ce <kvmmap>
  kvmmap(kpgtbl, KERNBASE, KERNBASE, (uint64)etext - KERNBASE, PTE_R | PTE_X);
    80001364:	00007917          	auipc	s2,0x7
    80001368:	c9c90913          	addi	s2,s2,-868 # 80008000 <etext>
    8000136c:	4729                	li	a4,10
    8000136e:	80007697          	auipc	a3,0x80007
    80001372:	c9268693          	addi	a3,a3,-878 # 8000 <_entry-0x7fff8000>
    80001376:	4605                	li	a2,1
    80001378:	067e                	slli	a2,a2,0x1f
    8000137a:	85b2                	mv	a1,a2
    8000137c:	8526                	mv	a0,s1
    8000137e:	00000097          	auipc	ra,0x0
    80001382:	f50080e7          	jalr	-176(ra) # 800012ce <kvmmap>
  kvmmap(kpgtbl, (uint64)etext, (uint64)etext, PHYSTOP - (uint64)etext, PTE_R | PTE_W);
    80001386:	46c5                	li	a3,17
    80001388:	06ee                	slli	a3,a3,0x1b
    8000138a:	4719                	li	a4,6
    8000138c:	412686b3          	sub	a3,a3,s2
    80001390:	864a                	mv	a2,s2
    80001392:	85ca                	mv	a1,s2
    80001394:	8526                	mv	a0,s1
    80001396:	00000097          	auipc	ra,0x0
    8000139a:	f38080e7          	jalr	-200(ra) # 800012ce <kvmmap>
  kvmmap(kpgtbl, TRAMPOLINE, (uint64)trampoline, PGSIZE, PTE_R | PTE_X);
    8000139e:	4729                	li	a4,10
    800013a0:	6685                	lui	a3,0x1
    800013a2:	00006617          	auipc	a2,0x6
    800013a6:	c5e60613          	addi	a2,a2,-930 # 80007000 <_trampoline>
    800013aa:	040005b7          	lui	a1,0x4000
    800013ae:	15fd                	addi	a1,a1,-1 # 3ffffff <_entry-0x7c000001>
    800013b0:	05b2                	slli	a1,a1,0xc
    800013b2:	8526                	mv	a0,s1
    800013b4:	00000097          	auipc	ra,0x0
    800013b8:	f1a080e7          	jalr	-230(ra) # 800012ce <kvmmap>
  proc_mapstacks(kpgtbl);
    800013bc:	8526                	mv	a0,s1
    800013be:	00000097          	auipc	ra,0x0
    800013c2:	6e4080e7          	jalr	1764(ra) # 80001aa2 <proc_mapstacks>
}
    800013c6:	8526                	mv	a0,s1
    800013c8:	60e2                	ld	ra,24(sp)
    800013ca:	6442                	ld	s0,16(sp)
    800013cc:	64a2                	ld	s1,8(sp)
    800013ce:	6902                	ld	s2,0(sp)
    800013d0:	6105                	addi	sp,sp,32
    800013d2:	8082                	ret

00000000800013d4 <kvminit>:
{
    800013d4:	1141                	addi	sp,sp,-16
    800013d6:	e406                	sd	ra,8(sp)
    800013d8:	e022                	sd	s0,0(sp)
    800013da:	0800                	addi	s0,sp,16
  kernel_pagetable = kvmmake();
    800013dc:	00000097          	auipc	ra,0x0
    800013e0:	f22080e7          	jalr	-222(ra) # 800012fe <kvmmake>
    800013e4:	00007797          	auipc	a5,0x7
    800013e8:	50a7be23          	sd	a0,1308(a5) # 80008900 <kernel_pagetable>
}
    800013ec:	60a2                	ld	ra,8(sp)
    800013ee:	6402                	ld	s0,0(sp)
    800013f0:	0141                	addi	sp,sp,16
    800013f2:	8082                	ret

00000000800013f4 <uvmunmap>:

// Remove npages of mappings starting from va. va must be
// page-aligned. The mappings must exist.
// Optionally free the physical memory.
void uvmunmap(pagetable_t pagetable, uint64 va, uint64 npages, int do_free)
{
    800013f4:	715d                	addi	sp,sp,-80
    800013f6:	e486                	sd	ra,72(sp)
    800013f8:	e0a2                	sd	s0,64(sp)
    800013fa:	0880                	addi	s0,sp,80
  uint64 a;
  pte_t *pte;

  if ((va % PGSIZE) != 0)
    800013fc:	03459793          	slli	a5,a1,0x34
    80001400:	e39d                	bnez	a5,80001426 <uvmunmap+0x32>
    80001402:	f84a                	sd	s2,48(sp)
    80001404:	f44e                	sd	s3,40(sp)
    80001406:	f052                	sd	s4,32(sp)
    80001408:	ec56                	sd	s5,24(sp)
    8000140a:	e85a                	sd	s6,16(sp)
    8000140c:	e45e                	sd	s7,8(sp)
    8000140e:	8a2a                	mv	s4,a0
    80001410:	892e                	mv	s2,a1
    80001412:	8ab6                	mv	s5,a3
    panic("uvmunmap: not aligned");

  for (a = va; a < va + npages * PGSIZE; a += PGSIZE)
    80001414:	0632                	slli	a2,a2,0xc
    80001416:	00b609b3          	add	s3,a2,a1
  {
    if ((pte = walk(pagetable, a, 0)) == 0)
      panic("uvmunmap: walk");
    if ((*pte & PTE_V) == 0)
      panic("uvmunmap: not mapped");
    if (PTE_FLAGS(*pte) == PTE_V)
    8000141a:	4b85                	li	s7,1
  for (a = va; a < va + npages * PGSIZE; a += PGSIZE)
    8000141c:	6b05                	lui	s6,0x1
    8000141e:	0935fb63          	bgeu	a1,s3,800014b4 <uvmunmap+0xc0>
    80001422:	fc26                	sd	s1,56(sp)
    80001424:	a8a9                	j	8000147e <uvmunmap+0x8a>
    80001426:	fc26                	sd	s1,56(sp)
    80001428:	f84a                	sd	s2,48(sp)
    8000142a:	f44e                	sd	s3,40(sp)
    8000142c:	f052                	sd	s4,32(sp)
    8000142e:	ec56                	sd	s5,24(sp)
    80001430:	e85a                	sd	s6,16(sp)
    80001432:	e45e                	sd	s7,8(sp)
    panic("uvmunmap: not aligned");
    80001434:	00007517          	auipc	a0,0x7
    80001438:	ce450513          	addi	a0,a0,-796 # 80008118 <etext+0x118>
    8000143c:	fffff097          	auipc	ra,0xfffff
    80001440:	124080e7          	jalr	292(ra) # 80000560 <panic>
      panic("uvmunmap: walk");
    80001444:	00007517          	auipc	a0,0x7
    80001448:	cec50513          	addi	a0,a0,-788 # 80008130 <etext+0x130>
    8000144c:	fffff097          	auipc	ra,0xfffff
    80001450:	114080e7          	jalr	276(ra) # 80000560 <panic>
      panic("uvmunmap: not mapped");
    80001454:	00007517          	auipc	a0,0x7
    80001458:	cec50513          	addi	a0,a0,-788 # 80008140 <etext+0x140>
    8000145c:	fffff097          	auipc	ra,0xfffff
    80001460:	104080e7          	jalr	260(ra) # 80000560 <panic>
      panic("uvmunmap: not a leaf");
    80001464:	00007517          	auipc	a0,0x7
    80001468:	cf450513          	addi	a0,a0,-780 # 80008158 <etext+0x158>
    8000146c:	fffff097          	auipc	ra,0xfffff
    80001470:	0f4080e7          	jalr	244(ra) # 80000560 <panic>
    if (do_free)
    {
      uint64 pa = PTE2PA(*pte);
      kfree((void *)pa);
    }
    *pte = 0;
    80001474:	0004b023          	sd	zero,0(s1)
  for (a = va; a < va + npages * PGSIZE; a += PGSIZE)
    80001478:	995a                	add	s2,s2,s6
    8000147a:	03397c63          	bgeu	s2,s3,800014b2 <uvmunmap+0xbe>
    if ((pte = walk(pagetable, a, 0)) == 0)
    8000147e:	4601                	li	a2,0
    80001480:	85ca                	mv	a1,s2
    80001482:	8552                	mv	a0,s4
    80001484:	00000097          	auipc	ra,0x0
    80001488:	cc2080e7          	jalr	-830(ra) # 80001146 <walk>
    8000148c:	84aa                	mv	s1,a0
    8000148e:	d95d                	beqz	a0,80001444 <uvmunmap+0x50>
    if ((*pte & PTE_V) == 0)
    80001490:	6108                	ld	a0,0(a0)
    80001492:	00157793          	andi	a5,a0,1
    80001496:	dfdd                	beqz	a5,80001454 <uvmunmap+0x60>
    if (PTE_FLAGS(*pte) == PTE_V)
    80001498:	3ff57793          	andi	a5,a0,1023
    8000149c:	fd7784e3          	beq	a5,s7,80001464 <uvmunmap+0x70>
    if (do_free)
    800014a0:	fc0a8ae3          	beqz	s5,80001474 <uvmunmap+0x80>
      uint64 pa = PTE2PA(*pte);
    800014a4:	8129                	srli	a0,a0,0xa
      kfree((void *)pa);
    800014a6:	0532                	slli	a0,a0,0xc
    800014a8:	fffff097          	auipc	ra,0xfffff
    800014ac:	5a2080e7          	jalr	1442(ra) # 80000a4a <kfree>
    800014b0:	b7d1                	j	80001474 <uvmunmap+0x80>
    800014b2:	74e2                	ld	s1,56(sp)
    800014b4:	7942                	ld	s2,48(sp)
    800014b6:	79a2                	ld	s3,40(sp)
    800014b8:	7a02                	ld	s4,32(sp)
    800014ba:	6ae2                	ld	s5,24(sp)
    800014bc:	6b42                	ld	s6,16(sp)
    800014be:	6ba2                	ld	s7,8(sp)
  }
}
    800014c0:	60a6                	ld	ra,72(sp)
    800014c2:	6406                	ld	s0,64(sp)
    800014c4:	6161                	addi	sp,sp,80
    800014c6:	8082                	ret

00000000800014c8 <uvmcreate>:

// create an empty user page table.
// returns 0 if out of memory.
pagetable_t
uvmcreate()
{
    800014c8:	1101                	addi	sp,sp,-32
    800014ca:	ec06                	sd	ra,24(sp)
    800014cc:	e822                	sd	s0,16(sp)
    800014ce:	e426                	sd	s1,8(sp)
    800014d0:	1000                	addi	s0,sp,32
  pagetable_t pagetable;
  pagetable = (pagetable_t)kalloc();
    800014d2:	fffff097          	auipc	ra,0xfffff
    800014d6:	6fc080e7          	jalr	1788(ra) # 80000bce <kalloc>
    800014da:	84aa                	mv	s1,a0
  if (pagetable == 0)
    800014dc:	c519                	beqz	a0,800014ea <uvmcreate+0x22>
    return 0;
  memset(pagetable, 0, PGSIZE);
    800014de:	6605                	lui	a2,0x1
    800014e0:	4581                	li	a1,0
    800014e2:	00000097          	auipc	ra,0x0
    800014e6:	988080e7          	jalr	-1656(ra) # 80000e6a <memset>
  return pagetable;
}
    800014ea:	8526                	mv	a0,s1
    800014ec:	60e2                	ld	ra,24(sp)
    800014ee:	6442                	ld	s0,16(sp)
    800014f0:	64a2                	ld	s1,8(sp)
    800014f2:	6105                	addi	sp,sp,32
    800014f4:	8082                	ret

00000000800014f6 <uvmfirst>:

// Load the user initcode into address 0 of pagetable,
// for the very first process.
// sz must be less than a page.
void uvmfirst(pagetable_t pagetable, uchar *src, uint sz)
{
    800014f6:	7179                	addi	sp,sp,-48
    800014f8:	f406                	sd	ra,40(sp)
    800014fa:	f022                	sd	s0,32(sp)
    800014fc:	ec26                	sd	s1,24(sp)
    800014fe:	e84a                	sd	s2,16(sp)
    80001500:	e44e                	sd	s3,8(sp)
    80001502:	e052                	sd	s4,0(sp)
    80001504:	1800                	addi	s0,sp,48
  char *mem;

  if (sz >= PGSIZE)
    80001506:	6785                	lui	a5,0x1
    80001508:	04f67863          	bgeu	a2,a5,80001558 <uvmfirst+0x62>
    8000150c:	8a2a                	mv	s4,a0
    8000150e:	89ae                	mv	s3,a1
    80001510:	84b2                	mv	s1,a2
    panic("uvmfirst: more than a page");
  mem = kalloc();
    80001512:	fffff097          	auipc	ra,0xfffff
    80001516:	6bc080e7          	jalr	1724(ra) # 80000bce <kalloc>
    8000151a:	892a                	mv	s2,a0
  memset(mem, 0, PGSIZE);
    8000151c:	6605                	lui	a2,0x1
    8000151e:	4581                	li	a1,0
    80001520:	00000097          	auipc	ra,0x0
    80001524:	94a080e7          	jalr	-1718(ra) # 80000e6a <memset>
  mappages(pagetable, 0, PGSIZE, (uint64)mem, PTE_W | PTE_R | PTE_X | PTE_U);
    80001528:	4779                	li	a4,30
    8000152a:	86ca                	mv	a3,s2
    8000152c:	6605                	lui	a2,0x1
    8000152e:	4581                	li	a1,0
    80001530:	8552                	mv	a0,s4
    80001532:	00000097          	auipc	ra,0x0
    80001536:	cfc080e7          	jalr	-772(ra) # 8000122e <mappages>
  //mappages(pagetable, 0, PGSIZE, (uint64)mem, PTE_R | PTE_X | PTE_U);
  memmove(mem, src, sz);
    8000153a:	8626                	mv	a2,s1
    8000153c:	85ce                	mv	a1,s3
    8000153e:	854a                	mv	a0,s2
    80001540:	00000097          	auipc	ra,0x0
    80001544:	986080e7          	jalr	-1658(ra) # 80000ec6 <memmove>
}
    80001548:	70a2                	ld	ra,40(sp)
    8000154a:	7402                	ld	s0,32(sp)
    8000154c:	64e2                	ld	s1,24(sp)
    8000154e:	6942                	ld	s2,16(sp)
    80001550:	69a2                	ld	s3,8(sp)
    80001552:	6a02                	ld	s4,0(sp)
    80001554:	6145                	addi	sp,sp,48
    80001556:	8082                	ret
    panic("uvmfirst: more than a page");
    80001558:	00007517          	auipc	a0,0x7
    8000155c:	c1850513          	addi	a0,a0,-1000 # 80008170 <etext+0x170>
    80001560:	fffff097          	auipc	ra,0xfffff
    80001564:	000080e7          	jalr	ra # 80000560 <panic>

0000000080001568 <uvmdealloc>:
// newsz.  oldsz and newsz need not be page-aligned, nor does newsz
// need to be less than oldsz.  oldsz can be larger than the actual
// process size.  Returns the new process size.
uint64
uvmdealloc(pagetable_t pagetable, uint64 oldsz, uint64 newsz)
{
    80001568:	1101                	addi	sp,sp,-32
    8000156a:	ec06                	sd	ra,24(sp)
    8000156c:	e822                	sd	s0,16(sp)
    8000156e:	e426                	sd	s1,8(sp)
    80001570:	1000                	addi	s0,sp,32
  if (newsz >= oldsz)
    return oldsz;
    80001572:	84ae                	mv	s1,a1
  if (newsz >= oldsz)
    80001574:	00b67d63          	bgeu	a2,a1,8000158e <uvmdealloc+0x26>
    80001578:	84b2                	mv	s1,a2

  if (PGROUNDUP(newsz) < PGROUNDUP(oldsz))
    8000157a:	6785                	lui	a5,0x1
    8000157c:	17fd                	addi	a5,a5,-1 # fff <_entry-0x7ffff001>
    8000157e:	00f60733          	add	a4,a2,a5
    80001582:	76fd                	lui	a3,0xfffff
    80001584:	8f75                	and	a4,a4,a3
    80001586:	97ae                	add	a5,a5,a1
    80001588:	8ff5                	and	a5,a5,a3
    8000158a:	00f76863          	bltu	a4,a5,8000159a <uvmdealloc+0x32>
    int npages = (PGROUNDUP(oldsz) - PGROUNDUP(newsz)) / PGSIZE;
    uvmunmap(pagetable, PGROUNDUP(newsz), npages, 1);
  }

  return newsz;
}
    8000158e:	8526                	mv	a0,s1
    80001590:	60e2                	ld	ra,24(sp)
    80001592:	6442                	ld	s0,16(sp)
    80001594:	64a2                	ld	s1,8(sp)
    80001596:	6105                	addi	sp,sp,32
    80001598:	8082                	ret
    int npages = (PGROUNDUP(oldsz) - PGROUNDUP(newsz)) / PGSIZE;
    8000159a:	8f99                	sub	a5,a5,a4
    8000159c:	83b1                	srli	a5,a5,0xc
    uvmunmap(pagetable, PGROUNDUP(newsz), npages, 1);
    8000159e:	4685                	li	a3,1
    800015a0:	0007861b          	sext.w	a2,a5
    800015a4:	85ba                	mv	a1,a4
    800015a6:	00000097          	auipc	ra,0x0
    800015aa:	e4e080e7          	jalr	-434(ra) # 800013f4 <uvmunmap>
    800015ae:	b7c5                	j	8000158e <uvmdealloc+0x26>

00000000800015b0 <uvmalloc>:
  if (newsz < oldsz)
    800015b0:	0ab66b63          	bltu	a2,a1,80001666 <uvmalloc+0xb6>
{
    800015b4:	7139                	addi	sp,sp,-64
    800015b6:	fc06                	sd	ra,56(sp)
    800015b8:	f822                	sd	s0,48(sp)
    800015ba:	ec4e                	sd	s3,24(sp)
    800015bc:	e852                	sd	s4,16(sp)
    800015be:	e456                	sd	s5,8(sp)
    800015c0:	0080                	addi	s0,sp,64
    800015c2:	8aaa                	mv	s5,a0
    800015c4:	8a32                	mv	s4,a2
  oldsz = PGROUNDUP(oldsz);
    800015c6:	6785                	lui	a5,0x1
    800015c8:	17fd                	addi	a5,a5,-1 # fff <_entry-0x7ffff001>
    800015ca:	95be                	add	a1,a1,a5
    800015cc:	77fd                	lui	a5,0xfffff
    800015ce:	00f5f9b3          	and	s3,a1,a5
  for (a = oldsz; a < newsz; a += PGSIZE)
    800015d2:	08c9fc63          	bgeu	s3,a2,8000166a <uvmalloc+0xba>
    800015d6:	f426                	sd	s1,40(sp)
    800015d8:	f04a                	sd	s2,32(sp)
    800015da:	e05a                	sd	s6,0(sp)
    800015dc:	894e                	mv	s2,s3
    if (mappages(pagetable, a, PGSIZE, (uint64)mem, PTE_R | PTE_U | xperm) != 0)
    800015de:	0126eb13          	ori	s6,a3,18
    mem = kalloc();
    800015e2:	fffff097          	auipc	ra,0xfffff
    800015e6:	5ec080e7          	jalr	1516(ra) # 80000bce <kalloc>
    800015ea:	84aa                	mv	s1,a0
    if (mem == 0)
    800015ec:	c915                	beqz	a0,80001620 <uvmalloc+0x70>
    memset(mem, 0, PGSIZE);
    800015ee:	6605                	lui	a2,0x1
    800015f0:	4581                	li	a1,0
    800015f2:	00000097          	auipc	ra,0x0
    800015f6:	878080e7          	jalr	-1928(ra) # 80000e6a <memset>
    if (mappages(pagetable, a, PGSIZE, (uint64)mem, PTE_R | PTE_U | xperm) != 0)
    800015fa:	875a                	mv	a4,s6
    800015fc:	86a6                	mv	a3,s1
    800015fe:	6605                	lui	a2,0x1
    80001600:	85ca                	mv	a1,s2
    80001602:	8556                	mv	a0,s5
    80001604:	00000097          	auipc	ra,0x0
    80001608:	c2a080e7          	jalr	-982(ra) # 8000122e <mappages>
    8000160c:	ed05                	bnez	a0,80001644 <uvmalloc+0x94>
  for (a = oldsz; a < newsz; a += PGSIZE)
    8000160e:	6785                	lui	a5,0x1
    80001610:	993e                	add	s2,s2,a5
    80001612:	fd4968e3          	bltu	s2,s4,800015e2 <uvmalloc+0x32>
  return newsz;
    80001616:	8552                	mv	a0,s4
    80001618:	74a2                	ld	s1,40(sp)
    8000161a:	7902                	ld	s2,32(sp)
    8000161c:	6b02                	ld	s6,0(sp)
    8000161e:	a821                	j	80001636 <uvmalloc+0x86>
      uvmdealloc(pagetable, a, oldsz);
    80001620:	864e                	mv	a2,s3
    80001622:	85ca                	mv	a1,s2
    80001624:	8556                	mv	a0,s5
    80001626:	00000097          	auipc	ra,0x0
    8000162a:	f42080e7          	jalr	-190(ra) # 80001568 <uvmdealloc>
      return 0;
    8000162e:	4501                	li	a0,0
    80001630:	74a2                	ld	s1,40(sp)
    80001632:	7902                	ld	s2,32(sp)
    80001634:	6b02                	ld	s6,0(sp)
}
    80001636:	70e2                	ld	ra,56(sp)
    80001638:	7442                	ld	s0,48(sp)
    8000163a:	69e2                	ld	s3,24(sp)
    8000163c:	6a42                	ld	s4,16(sp)
    8000163e:	6aa2                	ld	s5,8(sp)
    80001640:	6121                	addi	sp,sp,64
    80001642:	8082                	ret
      kfree(mem);
    80001644:	8526                	mv	a0,s1
    80001646:	fffff097          	auipc	ra,0xfffff
    8000164a:	404080e7          	jalr	1028(ra) # 80000a4a <kfree>
      uvmdealloc(pagetable, a, oldsz);
    8000164e:	864e                	mv	a2,s3
    80001650:	85ca                	mv	a1,s2
    80001652:	8556                	mv	a0,s5
    80001654:	00000097          	auipc	ra,0x0
    80001658:	f14080e7          	jalr	-236(ra) # 80001568 <uvmdealloc>
      return 0;
    8000165c:	4501                	li	a0,0
    8000165e:	74a2                	ld	s1,40(sp)
    80001660:	7902                	ld	s2,32(sp)
    80001662:	6b02                	ld	s6,0(sp)
    80001664:	bfc9                	j	80001636 <uvmalloc+0x86>
    return oldsz;
    80001666:	852e                	mv	a0,a1
}
    80001668:	8082                	ret
  return newsz;
    8000166a:	8532                	mv	a0,a2
    8000166c:	b7e9                	j	80001636 <uvmalloc+0x86>

000000008000166e <freewalk>:

// Recursively free page-table pages.
// All leaf mappings must already have been removed.
void freewalk(pagetable_t pagetable)
{
    8000166e:	7179                	addi	sp,sp,-48
    80001670:	f406                	sd	ra,40(sp)
    80001672:	f022                	sd	s0,32(sp)
    80001674:	ec26                	sd	s1,24(sp)
    80001676:	e84a                	sd	s2,16(sp)
    80001678:	e44e                	sd	s3,8(sp)
    8000167a:	e052                	sd	s4,0(sp)
    8000167c:	1800                	addi	s0,sp,48
    8000167e:	8a2a                	mv	s4,a0
  // there are 2^9 = 512 PTEs in a page table.
  for (int i = 0; i < 512; i++)
    80001680:	84aa                	mv	s1,a0
    80001682:	6905                	lui	s2,0x1
    80001684:	992a                	add	s2,s2,a0
  {
    pte_t pte = pagetable[i];
    if ((pte & PTE_V) && (pte & (PTE_R | PTE_W | PTE_X)) == 0)
    80001686:	4985                	li	s3,1
    80001688:	a829                	j	800016a2 <freewalk+0x34>
    {
      // this PTE points to a lower-level page table.
      uint64 child = PTE2PA(pte);
    8000168a:	83a9                	srli	a5,a5,0xa
      freewalk((pagetable_t)child);
    8000168c:	00c79513          	slli	a0,a5,0xc
    80001690:	00000097          	auipc	ra,0x0
    80001694:	fde080e7          	jalr	-34(ra) # 8000166e <freewalk>
      pagetable[i] = 0;
    80001698:	0004b023          	sd	zero,0(s1)
  for (int i = 0; i < 512; i++)
    8000169c:	04a1                	addi	s1,s1,8
    8000169e:	03248163          	beq	s1,s2,800016c0 <freewalk+0x52>
    pte_t pte = pagetable[i];
    800016a2:	609c                	ld	a5,0(s1)
    if ((pte & PTE_V) && (pte & (PTE_R | PTE_W | PTE_X)) == 0)
    800016a4:	00f7f713          	andi	a4,a5,15
    800016a8:	ff3701e3          	beq	a4,s3,8000168a <freewalk+0x1c>
    }
    else if (pte & PTE_V)
    800016ac:	8b85                	andi	a5,a5,1
    800016ae:	d7fd                	beqz	a5,8000169c <freewalk+0x2e>
    {
      panic("freewalk: leaf");
    800016b0:	00007517          	auipc	a0,0x7
    800016b4:	ae050513          	addi	a0,a0,-1312 # 80008190 <etext+0x190>
    800016b8:	fffff097          	auipc	ra,0xfffff
    800016bc:	ea8080e7          	jalr	-344(ra) # 80000560 <panic>
    }
  }
  kfree((void *)pagetable);
    800016c0:	8552                	mv	a0,s4
    800016c2:	fffff097          	auipc	ra,0xfffff
    800016c6:	388080e7          	jalr	904(ra) # 80000a4a <kfree>
}
    800016ca:	70a2                	ld	ra,40(sp)
    800016cc:	7402                	ld	s0,32(sp)
    800016ce:	64e2                	ld	s1,24(sp)
    800016d0:	6942                	ld	s2,16(sp)
    800016d2:	69a2                	ld	s3,8(sp)
    800016d4:	6a02                	ld	s4,0(sp)
    800016d6:	6145                	addi	sp,sp,48
    800016d8:	8082                	ret

00000000800016da <uvmfree>:

// Free user memory pages,
// then free page-table pages.
void uvmfree(pagetable_t pagetable, uint64 sz)
{
    800016da:	1101                	addi	sp,sp,-32
    800016dc:	ec06                	sd	ra,24(sp)
    800016de:	e822                	sd	s0,16(sp)
    800016e0:	e426                	sd	s1,8(sp)
    800016e2:	1000                	addi	s0,sp,32
    800016e4:	84aa                	mv	s1,a0
  if (sz > 0)
    800016e6:	e999                	bnez	a1,800016fc <uvmfree+0x22>
    uvmunmap(pagetable, 0, PGROUNDUP(sz) / PGSIZE, 1);
  freewalk(pagetable);
    800016e8:	8526                	mv	a0,s1
    800016ea:	00000097          	auipc	ra,0x0
    800016ee:	f84080e7          	jalr	-124(ra) # 8000166e <freewalk>
}
    800016f2:	60e2                	ld	ra,24(sp)
    800016f4:	6442                	ld	s0,16(sp)
    800016f6:	64a2                	ld	s1,8(sp)
    800016f8:	6105                	addi	sp,sp,32
    800016fa:	8082                	ret
    uvmunmap(pagetable, 0, PGROUNDUP(sz) / PGSIZE, 1);
    800016fc:	6785                	lui	a5,0x1
    800016fe:	17fd                	addi	a5,a5,-1 # fff <_entry-0x7ffff001>
    80001700:	95be                	add	a1,a1,a5
    80001702:	4685                	li	a3,1
    80001704:	00c5d613          	srli	a2,a1,0xc
    80001708:	4581                	li	a1,0
    8000170a:	00000097          	auipc	ra,0x0
    8000170e:	cea080e7          	jalr	-790(ra) # 800013f4 <uvmunmap>
    80001712:	bfd9                	j	800016e8 <uvmfree+0xe>

0000000080001714 <uvmcopy>:
{
  pte_t *pte;
  uint64 pa, i;
  uint flags;

  for (i = 0; i < sz; i += PGSIZE)
    80001714:	ca55                	beqz	a2,800017c8 <uvmcopy+0xb4>
{
    80001716:	7139                	addi	sp,sp,-64
    80001718:	fc06                	sd	ra,56(sp)
    8000171a:	f822                	sd	s0,48(sp)
    8000171c:	f426                	sd	s1,40(sp)
    8000171e:	f04a                	sd	s2,32(sp)
    80001720:	ec4e                	sd	s3,24(sp)
    80001722:	e852                	sd	s4,16(sp)
    80001724:	e456                	sd	s5,8(sp)
    80001726:	e05a                	sd	s6,0(sp)
    80001728:	0080                	addi	s0,sp,64
    8000172a:	8b2a                	mv	s6,a0
    8000172c:	8aae                	mv	s5,a1
    8000172e:	8a32                	mv	s4,a2
  for (i = 0; i < sz; i += PGSIZE)
    80001730:	4901                	li	s2,0
  {
    if ((pte = walk(old, i, 0)) == 0)
    80001732:	4601                	li	a2,0
    80001734:	85ca                	mv	a1,s2
    80001736:	855a                	mv	a0,s6
    80001738:	00000097          	auipc	ra,0x0
    8000173c:	a0e080e7          	jalr	-1522(ra) # 80001146 <walk>
    80001740:	c121                	beqz	a0,80001780 <uvmcopy+0x6c>
      panic("uvmcopy: pte should exist");
    if ((*pte & PTE_V) == 0)
    80001742:	6118                	ld	a4,0(a0)
    80001744:	00177793          	andi	a5,a4,1
    80001748:	c7a1                	beqz	a5,80001790 <uvmcopy+0x7c>
      panic("uvmcopy: page not present");
    // fix the permission bits
    pa = PTE2PA(*pte);
    8000174a:	00a75993          	srli	s3,a4,0xa
    8000174e:	09b2                	slli	s3,s3,0xc
    *pte &= ~PTE_W;
    80001750:	ffb77493          	andi	s1,a4,-5
    80001754:	e104                	sd	s1,0(a0)
    // not allocated
    //  if((mem = kalloc()) == 0)
    //    goto err;
    //  memmove(mem, (char*)pa, PGSIZE);
    // increase refcnt
    increase(pa);
    80001756:	854e                	mv	a0,s3
    80001758:	fffff097          	auipc	ra,0xfffff
    8000175c:	50e080e7          	jalr	1294(ra) # 80000c66 <increase>
    // map the va to the same pa using flags
    if (mappages(new, i, PGSIZE, (uint64)pa, flags) != 0)
    80001760:	3fb4f713          	andi	a4,s1,1019
    80001764:	86ce                	mv	a3,s3
    80001766:	6605                	lui	a2,0x1
    80001768:	85ca                	mv	a1,s2
    8000176a:	8556                	mv	a0,s5
    8000176c:	00000097          	auipc	ra,0x0
    80001770:	ac2080e7          	jalr	-1342(ra) # 8000122e <mappages>
    80001774:	e515                	bnez	a0,800017a0 <uvmcopy+0x8c>
  for (i = 0; i < sz; i += PGSIZE)
    80001776:	6785                	lui	a5,0x1
    80001778:	993e                	add	s2,s2,a5
    8000177a:	fb496ce3          	bltu	s2,s4,80001732 <uvmcopy+0x1e>
    8000177e:	a81d                	j	800017b4 <uvmcopy+0xa0>
      panic("uvmcopy: pte should exist");
    80001780:	00007517          	auipc	a0,0x7
    80001784:	a2050513          	addi	a0,a0,-1504 # 800081a0 <etext+0x1a0>
    80001788:	fffff097          	auipc	ra,0xfffff
    8000178c:	dd8080e7          	jalr	-552(ra) # 80000560 <panic>
      panic("uvmcopy: page not present");
    80001790:	00007517          	auipc	a0,0x7
    80001794:	a3050513          	addi	a0,a0,-1488 # 800081c0 <etext+0x1c0>
    80001798:	fffff097          	auipc	ra,0xfffff
    8000179c:	dc8080e7          	jalr	-568(ra) # 80000560 <panic>
    }
  }
  return 0;

err:
  uvmunmap(new, 0, i / PGSIZE, 1);
    800017a0:	4685                	li	a3,1
    800017a2:	00c95613          	srli	a2,s2,0xc
    800017a6:	4581                	li	a1,0
    800017a8:	8556                	mv	a0,s5
    800017aa:	00000097          	auipc	ra,0x0
    800017ae:	c4a080e7          	jalr	-950(ra) # 800013f4 <uvmunmap>
  return -1;
    800017b2:	557d                	li	a0,-1
}
    800017b4:	70e2                	ld	ra,56(sp)
    800017b6:	7442                	ld	s0,48(sp)
    800017b8:	74a2                	ld	s1,40(sp)
    800017ba:	7902                	ld	s2,32(sp)
    800017bc:	69e2                	ld	s3,24(sp)
    800017be:	6a42                	ld	s4,16(sp)
    800017c0:	6aa2                	ld	s5,8(sp)
    800017c2:	6b02                	ld	s6,0(sp)
    800017c4:	6121                	addi	sp,sp,64
    800017c6:	8082                	ret
  return 0;
    800017c8:	4501                	li	a0,0
}
    800017ca:	8082                	ret

00000000800017cc <uvmclear>:

// mark a PTE invalid for user access.
// used by exec for the user stack guard page.
void uvmclear(pagetable_t pagetable, uint64 va)
{
    800017cc:	1141                	addi	sp,sp,-16
    800017ce:	e406                	sd	ra,8(sp)
    800017d0:	e022                	sd	s0,0(sp)
    800017d2:	0800                	addi	s0,sp,16
  pte_t *pte;

  pte = walk(pagetable, va, 0);
    800017d4:	4601                	li	a2,0
    800017d6:	00000097          	auipc	ra,0x0
    800017da:	970080e7          	jalr	-1680(ra) # 80001146 <walk>
  if (pte == 0)
    800017de:	c901                	beqz	a0,800017ee <uvmclear+0x22>
    panic("uvmclear");
  *pte &= ~PTE_U;
    800017e0:	611c                	ld	a5,0(a0)
    800017e2:	9bbd                	andi	a5,a5,-17
    800017e4:	e11c                	sd	a5,0(a0)
}
    800017e6:	60a2                	ld	ra,8(sp)
    800017e8:	6402                	ld	s0,0(sp)
    800017ea:	0141                	addi	sp,sp,16
    800017ec:	8082                	ret
    panic("uvmclear");
    800017ee:	00007517          	auipc	a0,0x7
    800017f2:	9f250513          	addi	a0,a0,-1550 # 800081e0 <etext+0x1e0>
    800017f6:	fffff097          	auipc	ra,0xfffff
    800017fa:	d6a080e7          	jalr	-662(ra) # 80000560 <panic>

00000000800017fe <cowfault>:

int cowfault(pagetable_t pagetable, uint64 va)
{
  if (va >= MAXVA)
    800017fe:	57fd                	li	a5,-1
    80001800:	83e9                	srli	a5,a5,0x1a
    80001802:	06b7e863          	bltu	a5,a1,80001872 <cowfault+0x74>
{
    80001806:	7179                	addi	sp,sp,-48
    80001808:	f406                	sd	ra,40(sp)
    8000180a:	f022                	sd	s0,32(sp)
    8000180c:	e44e                	sd	s3,8(sp)
    8000180e:	1800                	addi	s0,sp,48
    return -1;
  pte_t *pte = walk(pagetable, va, 0);
    80001810:	4601                	li	a2,0
    80001812:	00000097          	auipc	ra,0x0
    80001816:	934080e7          	jalr	-1740(ra) # 80001146 <walk>
    8000181a:	89aa                	mv	s3,a0
  if (pte == 0)
    8000181c:	cd29                	beqz	a0,80001876 <cowfault+0x78>
    return -1;
  if ((*pte & PTE_U) == 0 || (*pte & PTE_V) == 0)
    8000181e:	610c                	ld	a1,0(a0)
    80001820:	0115f713          	andi	a4,a1,17
    80001824:	47c5                	li	a5,17
    80001826:	04f71a63          	bne	a4,a5,8000187a <cowfault+0x7c>
    8000182a:	ec26                	sd	s1,24(sp)
    8000182c:	e84a                	sd	s2,16(sp)
    return -1;
  uint64 pa1 = PTE2PA(*pte);
    8000182e:	81a9                	srli	a1,a1,0xa
    80001830:	00c59913          	slli	s2,a1,0xc
  uint64 pa2 = (uint64)kalloc();
    80001834:	fffff097          	auipc	ra,0xfffff
    80001838:	39a080e7          	jalr	922(ra) # 80000bce <kalloc>
    8000183c:	84aa                	mv	s1,a0
  if (pa2 == 0)
    8000183e:	c121                	beqz	a0,8000187e <cowfault+0x80>
  {
    // panic("cow panic kalloc");
    return -1;
  }

  memmove((void *)pa2, (void *)pa1, PGSIZE);
    80001840:	6605                	lui	a2,0x1
    80001842:	85ca                	mv	a1,s2
    80001844:	fffff097          	auipc	ra,0xfffff
    80001848:	682080e7          	jalr	1666(ra) # 80000ec6 <memmove>
  *pte = PA2PTE(pa2) | PTE_U | PTE_V | PTE_W | PTE_X | PTE_R;
    8000184c:	80b1                	srli	s1,s1,0xc
    8000184e:	04aa                	slli	s1,s1,0xa
    80001850:	01f4e493          	ori	s1,s1,31
    80001854:	0099b023          	sd	s1,0(s3) # 2000 <_entry-0x7fffe000>
  kfree((void *)pa1);
    80001858:	854a                	mv	a0,s2
    8000185a:	fffff097          	auipc	ra,0xfffff
    8000185e:	1f0080e7          	jalr	496(ra) # 80000a4a <kfree>

   // Increment the COW page fault counter for the current process
  //struct proc *p = myproc(); // Get the current process
  //p->cow_page_faults += 1;
  
  return 0;
    80001862:	4501                	li	a0,0
    80001864:	64e2                	ld	s1,24(sp)
    80001866:	6942                	ld	s2,16(sp)
}
    80001868:	70a2                	ld	ra,40(sp)
    8000186a:	7402                	ld	s0,32(sp)
    8000186c:	69a2                	ld	s3,8(sp)
    8000186e:	6145                	addi	sp,sp,48
    80001870:	8082                	ret
    return -1;
    80001872:	557d                	li	a0,-1
}
    80001874:	8082                	ret
    return -1;
    80001876:	557d                	li	a0,-1
    80001878:	bfc5                	j	80001868 <cowfault+0x6a>
    return -1;
    8000187a:	557d                	li	a0,-1
    8000187c:	b7f5                	j	80001868 <cowfault+0x6a>
    return -1;
    8000187e:	557d                	li	a0,-1
    80001880:	64e2                	ld	s1,24(sp)
    80001882:	6942                	ld	s2,16(sp)
    80001884:	b7d5                	j	80001868 <cowfault+0x6a>

0000000080001886 <copyout>:
// Return 0 on success, -1 on error.
int copyout(pagetable_t pagetable, uint64 dstva, char *src, uint64 len)
{
  uint64 n, va0, pa0;

  while (len > 0)
    80001886:	c6cd                	beqz	a3,80001930 <copyout+0xaa>
{
    80001888:	711d                	addi	sp,sp,-96
    8000188a:	ec86                	sd	ra,88(sp)
    8000188c:	e8a2                	sd	s0,80(sp)
    8000188e:	e4a6                	sd	s1,72(sp)
    80001890:	e0ca                	sd	s2,64(sp)
    80001892:	fc4e                	sd	s3,56(sp)
    80001894:	f852                	sd	s4,48(sp)
    80001896:	f456                	sd	s5,40(sp)
    80001898:	f05a                	sd	s6,32(sp)
    8000189a:	ec5e                	sd	s7,24(sp)
    8000189c:	e862                	sd	s8,16(sp)
    8000189e:	e466                	sd	s9,8(sp)
    800018a0:	1080                	addi	s0,sp,96
    800018a2:	8b2a                	mv	s6,a0
    800018a4:	8a2e                	mv	s4,a1
    800018a6:	8bb2                	mv	s7,a2
    800018a8:	8ab6                	mv	s5,a3
  {
    va0 = PGROUNDDOWN(dstva);
    800018aa:	7cfd                	lui	s9,0xfffff
      pa0 = walkaddr(pagetable, va0);
      if (pa0 == 0)
        return -1;
    }

    n = PGSIZE - (dstva - va0);
    800018ac:	6c05                	lui	s8,0x1
    800018ae:	a805                	j	800018de <copyout+0x58>
    800018b0:	414984b3          	sub	s1,s3,s4
    800018b4:	94e2                	add	s1,s1,s8
    if (n > len)
    800018b6:	009af363          	bgeu	s5,s1,800018bc <copyout+0x36>
    800018ba:	84d6                	mv	s1,s5
      n = len;

    memmove((void *)(pa0 + (dstva - va0)), src, n);
    800018bc:	413a0533          	sub	a0,s4,s3
    800018c0:	0004861b          	sext.w	a2,s1
    800018c4:	85de                	mv	a1,s7
    800018c6:	954a                	add	a0,a0,s2
    800018c8:	fffff097          	auipc	ra,0xfffff
    800018cc:	5fe080e7          	jalr	1534(ra) # 80000ec6 <memmove>

    len -= n;
    800018d0:	409a8ab3          	sub	s5,s5,s1
    src += n;
    800018d4:	9ba6                	add	s7,s7,s1
    dstva = va0 + PGSIZE;
    800018d6:	01898a33          	add	s4,s3,s8
  while (len > 0)
    800018da:	040a8963          	beqz	s5,8000192c <copyout+0xa6>
    va0 = PGROUNDDOWN(dstva);
    800018de:	019a79b3          	and	s3,s4,s9
    pa0 = walkaddr(pagetable, va0);
    800018e2:	85ce                	mv	a1,s3
    800018e4:	855a                	mv	a0,s6
    800018e6:	00000097          	auipc	ra,0x0
    800018ea:	906080e7          	jalr	-1786(ra) # 800011ec <walkaddr>
    800018ee:	892a                	mv	s2,a0
    if (pa0 == 0)
    800018f0:	c131                	beqz	a0,80001934 <copyout+0xae>
    pte_t *pte = walk(pagetable, va0, 0);
    800018f2:	4601                	li	a2,0
    800018f4:	85ce                	mv	a1,s3
    800018f6:	855a                	mv	a0,s6
    800018f8:	00000097          	auipc	ra,0x0
    800018fc:	84e080e7          	jalr	-1970(ra) # 80001146 <walk>
    if (pte == 0)
    80001900:	c921                	beqz	a0,80001950 <copyout+0xca>
    if (!(*pte & PTE_W))
    80001902:	611c                	ld	a5,0(a0)
    80001904:	8b91                	andi	a5,a5,4
    80001906:	f7cd                	bnez	a5,800018b0 <copyout+0x2a>
      if (cowfault(pagetable, va0) < 0)
    80001908:	85ce                	mv	a1,s3
    8000190a:	855a                	mv	a0,s6
    8000190c:	00000097          	auipc	ra,0x0
    80001910:	ef2080e7          	jalr	-270(ra) # 800017fe <cowfault>
    80001914:	04054063          	bltz	a0,80001954 <copyout+0xce>
      pa0 = walkaddr(pagetable, va0);
    80001918:	85ce                	mv	a1,s3
    8000191a:	855a                	mv	a0,s6
    8000191c:	00000097          	auipc	ra,0x0
    80001920:	8d0080e7          	jalr	-1840(ra) # 800011ec <walkaddr>
    80001924:	892a                	mv	s2,a0
      if (pa0 == 0)
    80001926:	f549                	bnez	a0,800018b0 <copyout+0x2a>
        return -1;
    80001928:	557d                	li	a0,-1
    8000192a:	a031                	j	80001936 <copyout+0xb0>
  }
  return 0;
    8000192c:	4501                	li	a0,0
    8000192e:	a021                	j	80001936 <copyout+0xb0>
    80001930:	4501                	li	a0,0
}
    80001932:	8082                	ret
      return -1;
    80001934:	557d                	li	a0,-1
}
    80001936:	60e6                	ld	ra,88(sp)
    80001938:	6446                	ld	s0,80(sp)
    8000193a:	64a6                	ld	s1,72(sp)
    8000193c:	6906                	ld	s2,64(sp)
    8000193e:	79e2                	ld	s3,56(sp)
    80001940:	7a42                	ld	s4,48(sp)
    80001942:	7aa2                	ld	s5,40(sp)
    80001944:	7b02                	ld	s6,32(sp)
    80001946:	6be2                	ld	s7,24(sp)
    80001948:	6c42                	ld	s8,16(sp)
    8000194a:	6ca2                	ld	s9,8(sp)
    8000194c:	6125                	addi	sp,sp,96
    8000194e:	8082                	ret
      return -1;
    80001950:	557d                	li	a0,-1
    80001952:	b7d5                	j	80001936 <copyout+0xb0>
        return -1;
    80001954:	557d                	li	a0,-1
    80001956:	b7c5                	j	80001936 <copyout+0xb0>

0000000080001958 <copyin>:
// Return 0 on success, -1 on error.
int copyin(pagetable_t pagetable, char *dst, uint64 srcva, uint64 len)
{
  uint64 n, va0, pa0;

  while (len > 0)
    80001958:	caa5                	beqz	a3,800019c8 <copyin+0x70>
{
    8000195a:	715d                	addi	sp,sp,-80
    8000195c:	e486                	sd	ra,72(sp)
    8000195e:	e0a2                	sd	s0,64(sp)
    80001960:	fc26                	sd	s1,56(sp)
    80001962:	f84a                	sd	s2,48(sp)
    80001964:	f44e                	sd	s3,40(sp)
    80001966:	f052                	sd	s4,32(sp)
    80001968:	ec56                	sd	s5,24(sp)
    8000196a:	e85a                	sd	s6,16(sp)
    8000196c:	e45e                	sd	s7,8(sp)
    8000196e:	e062                	sd	s8,0(sp)
    80001970:	0880                	addi	s0,sp,80
    80001972:	8b2a                	mv	s6,a0
    80001974:	8a2e                	mv	s4,a1
    80001976:	8c32                	mv	s8,a2
    80001978:	89b6                	mv	s3,a3
  {
    va0 = PGROUNDDOWN(srcva);
    8000197a:	7bfd                	lui	s7,0xfffff
    pa0 = walkaddr(pagetable, va0);
    if (pa0 == 0)
      return -1;
    n = PGSIZE - (srcva - va0);
    8000197c:	6a85                	lui	s5,0x1
    8000197e:	a01d                	j	800019a4 <copyin+0x4c>
    if (n > len)
      n = len;
    memmove(dst, (void *)(pa0 + (srcva - va0)), n);
    80001980:	018505b3          	add	a1,a0,s8
    80001984:	0004861b          	sext.w	a2,s1
    80001988:	412585b3          	sub	a1,a1,s2
    8000198c:	8552                	mv	a0,s4
    8000198e:	fffff097          	auipc	ra,0xfffff
    80001992:	538080e7          	jalr	1336(ra) # 80000ec6 <memmove>

    len -= n;
    80001996:	409989b3          	sub	s3,s3,s1
    dst += n;
    8000199a:	9a26                	add	s4,s4,s1
    srcva = va0 + PGSIZE;
    8000199c:	01590c33          	add	s8,s2,s5
  while (len > 0)
    800019a0:	02098263          	beqz	s3,800019c4 <copyin+0x6c>
    va0 = PGROUNDDOWN(srcva);
    800019a4:	017c7933          	and	s2,s8,s7
    pa0 = walkaddr(pagetable, va0);
    800019a8:	85ca                	mv	a1,s2
    800019aa:	855a                	mv	a0,s6
    800019ac:	00000097          	auipc	ra,0x0
    800019b0:	840080e7          	jalr	-1984(ra) # 800011ec <walkaddr>
    if (pa0 == 0)
    800019b4:	cd01                	beqz	a0,800019cc <copyin+0x74>
    n = PGSIZE - (srcva - va0);
    800019b6:	418904b3          	sub	s1,s2,s8
    800019ba:	94d6                	add	s1,s1,s5
    if (n > len)
    800019bc:	fc99f2e3          	bgeu	s3,s1,80001980 <copyin+0x28>
    800019c0:	84ce                	mv	s1,s3
    800019c2:	bf7d                	j	80001980 <copyin+0x28>
  }
  return 0;
    800019c4:	4501                	li	a0,0
    800019c6:	a021                	j	800019ce <copyin+0x76>
    800019c8:	4501                	li	a0,0
}
    800019ca:	8082                	ret
      return -1;
    800019cc:	557d                	li	a0,-1
}
    800019ce:	60a6                	ld	ra,72(sp)
    800019d0:	6406                	ld	s0,64(sp)
    800019d2:	74e2                	ld	s1,56(sp)
    800019d4:	7942                	ld	s2,48(sp)
    800019d6:	79a2                	ld	s3,40(sp)
    800019d8:	7a02                	ld	s4,32(sp)
    800019da:	6ae2                	ld	s5,24(sp)
    800019dc:	6b42                	ld	s6,16(sp)
    800019de:	6ba2                	ld	s7,8(sp)
    800019e0:	6c02                	ld	s8,0(sp)
    800019e2:	6161                	addi	sp,sp,80
    800019e4:	8082                	ret

00000000800019e6 <copyinstr>:
int copyinstr(pagetable_t pagetable, char *dst, uint64 srcva, uint64 max)
{
  uint64 n, va0, pa0;
  int got_null = 0;

  while (got_null == 0 && max > 0)
    800019e6:	cacd                	beqz	a3,80001a98 <copyinstr+0xb2>
{
    800019e8:	715d                	addi	sp,sp,-80
    800019ea:	e486                	sd	ra,72(sp)
    800019ec:	e0a2                	sd	s0,64(sp)
    800019ee:	fc26                	sd	s1,56(sp)
    800019f0:	f84a                	sd	s2,48(sp)
    800019f2:	f44e                	sd	s3,40(sp)
    800019f4:	f052                	sd	s4,32(sp)
    800019f6:	ec56                	sd	s5,24(sp)
    800019f8:	e85a                	sd	s6,16(sp)
    800019fa:	e45e                	sd	s7,8(sp)
    800019fc:	0880                	addi	s0,sp,80
    800019fe:	8a2a                	mv	s4,a0
    80001a00:	8b2e                	mv	s6,a1
    80001a02:	8bb2                	mv	s7,a2
    80001a04:	8936                	mv	s2,a3
  {
    va0 = PGROUNDDOWN(srcva);
    80001a06:	7afd                	lui	s5,0xfffff
    pa0 = walkaddr(pagetable, va0);
    if (pa0 == 0)
      return -1;
    n = PGSIZE - (srcva - va0);
    80001a08:	6985                	lui	s3,0x1
    80001a0a:	a825                	j	80001a42 <copyinstr+0x5c>
    char *p = (char *)(pa0 + (srcva - va0));
    while (n > 0)
    {
      if (*p == '\0')
      {
        *dst = '\0';
    80001a0c:	00078023          	sb	zero,0(a5) # 1000 <_entry-0x7ffff000>
    80001a10:	4785                	li	a5,1
      dst++;
    }

    srcva = va0 + PGSIZE;
  }
  if (got_null)
    80001a12:	37fd                	addiw	a5,a5,-1
    80001a14:	0007851b          	sext.w	a0,a5
  }
  else
  {
    return -1;
  }
}
    80001a18:	60a6                	ld	ra,72(sp)
    80001a1a:	6406                	ld	s0,64(sp)
    80001a1c:	74e2                	ld	s1,56(sp)
    80001a1e:	7942                	ld	s2,48(sp)
    80001a20:	79a2                	ld	s3,40(sp)
    80001a22:	7a02                	ld	s4,32(sp)
    80001a24:	6ae2                	ld	s5,24(sp)
    80001a26:	6b42                	ld	s6,16(sp)
    80001a28:	6ba2                	ld	s7,8(sp)
    80001a2a:	6161                	addi	sp,sp,80
    80001a2c:	8082                	ret
    80001a2e:	fff90713          	addi	a4,s2,-1 # fff <_entry-0x7ffff001>
    80001a32:	9742                	add	a4,a4,a6
      --max;
    80001a34:	40b70933          	sub	s2,a4,a1
    srcva = va0 + PGSIZE;
    80001a38:	01348bb3          	add	s7,s1,s3
  while (got_null == 0 && max > 0)
    80001a3c:	04e58663          	beq	a1,a4,80001a88 <copyinstr+0xa2>
{
    80001a40:	8b3e                	mv	s6,a5
    va0 = PGROUNDDOWN(srcva);
    80001a42:	015bf4b3          	and	s1,s7,s5
    pa0 = walkaddr(pagetable, va0);
    80001a46:	85a6                	mv	a1,s1
    80001a48:	8552                	mv	a0,s4
    80001a4a:	fffff097          	auipc	ra,0xfffff
    80001a4e:	7a2080e7          	jalr	1954(ra) # 800011ec <walkaddr>
    if (pa0 == 0)
    80001a52:	cd0d                	beqz	a0,80001a8c <copyinstr+0xa6>
    n = PGSIZE - (srcva - va0);
    80001a54:	417486b3          	sub	a3,s1,s7
    80001a58:	96ce                	add	a3,a3,s3
    if (n > max)
    80001a5a:	00d97363          	bgeu	s2,a3,80001a60 <copyinstr+0x7a>
    80001a5e:	86ca                	mv	a3,s2
    char *p = (char *)(pa0 + (srcva - va0));
    80001a60:	955e                	add	a0,a0,s7
    80001a62:	8d05                	sub	a0,a0,s1
    while (n > 0)
    80001a64:	c695                	beqz	a3,80001a90 <copyinstr+0xaa>
    80001a66:	87da                	mv	a5,s6
    80001a68:	885a                	mv	a6,s6
      if (*p == '\0')
    80001a6a:	41650633          	sub	a2,a0,s6
    while (n > 0)
    80001a6e:	96da                	add	a3,a3,s6
    80001a70:	85be                	mv	a1,a5
      if (*p == '\0')
    80001a72:	00f60733          	add	a4,a2,a5
    80001a76:	00074703          	lbu	a4,0(a4) # fffffffffffff000 <end+0xffffffff7fdbcc70>
    80001a7a:	db49                	beqz	a4,80001a0c <copyinstr+0x26>
        *dst = *p;
    80001a7c:	00e78023          	sb	a4,0(a5)
      dst++;
    80001a80:	0785                	addi	a5,a5,1
    while (n > 0)
    80001a82:	fed797e3          	bne	a5,a3,80001a70 <copyinstr+0x8a>
    80001a86:	b765                	j	80001a2e <copyinstr+0x48>
    80001a88:	4781                	li	a5,0
    80001a8a:	b761                	j	80001a12 <copyinstr+0x2c>
      return -1;
    80001a8c:	557d                	li	a0,-1
    80001a8e:	b769                	j	80001a18 <copyinstr+0x32>
    srcva = va0 + PGSIZE;
    80001a90:	6b85                	lui	s7,0x1
    80001a92:	9ba6                	add	s7,s7,s1
    80001a94:	87da                	mv	a5,s6
    80001a96:	b76d                	j	80001a40 <copyinstr+0x5a>
  int got_null = 0;
    80001a98:	4781                	li	a5,0
  if (got_null)
    80001a9a:	37fd                	addiw	a5,a5,-1
    80001a9c:	0007851b          	sext.w	a0,a5
}
    80001aa0:	8082                	ret

0000000080001aa2 <proc_mapstacks>:

// Allocate a page for each process's kernel stack.
// Map it high in memory, followed by an invalid
// guard page.
void proc_mapstacks(pagetable_t kpgtbl)
{
    80001aa2:	7139                	addi	sp,sp,-64
    80001aa4:	fc06                	sd	ra,56(sp)
    80001aa6:	f822                	sd	s0,48(sp)
    80001aa8:	f426                	sd	s1,40(sp)
    80001aaa:	f04a                	sd	s2,32(sp)
    80001aac:	ec4e                	sd	s3,24(sp)
    80001aae:	e852                	sd	s4,16(sp)
    80001ab0:	e456                	sd	s5,8(sp)
    80001ab2:	e05a                	sd	s6,0(sp)
    80001ab4:	0080                	addi	s0,sp,64
    80001ab6:	8a2a                	mv	s4,a0
  struct proc *p;

  for (p = proc; p < &proc[NPROC]; p++)
    80001ab8:	0022f497          	auipc	s1,0x22f
    80001abc:	4f848493          	addi	s1,s1,1272 # 80230fb0 <proc>
  {
    char *pa = kalloc();
    if (pa == 0)
      panic("kalloc");
    uint64 va = KSTACK((int)(p - proc));
    80001ac0:	8b26                	mv	s6,s1
    80001ac2:	faaab937          	lui	s2,0xfaaab
    80001ac6:	aab90913          	addi	s2,s2,-1365 # fffffffffaaaaaab <end+0xffffffff7a86871b>
    80001aca:	0932                	slli	s2,s2,0xc
    80001acc:	aab90913          	addi	s2,s2,-1365
    80001ad0:	0932                	slli	s2,s2,0xc
    80001ad2:	aab90913          	addi	s2,s2,-1365
    80001ad6:	0932                	slli	s2,s2,0xc
    80001ad8:	aab90913          	addi	s2,s2,-1365
    80001adc:	040009b7          	lui	s3,0x4000
    80001ae0:	19fd                	addi	s3,s3,-1 # 3ffffff <_entry-0x7c000001>
    80001ae2:	09b2                	slli	s3,s3,0xc
  for (p = proc; p < &proc[NPROC]; p++)
    80001ae4:	00235a97          	auipc	s5,0x235
    80001ae8:	4cca8a93          	addi	s5,s5,1228 # 80236fb0 <tickslock>
    char *pa = kalloc();
    80001aec:	fffff097          	auipc	ra,0xfffff
    80001af0:	0e2080e7          	jalr	226(ra) # 80000bce <kalloc>
    80001af4:	862a                	mv	a2,a0
    if (pa == 0)
    80001af6:	c121                	beqz	a0,80001b36 <proc_mapstacks+0x94>
    uint64 va = KSTACK((int)(p - proc));
    80001af8:	416485b3          	sub	a1,s1,s6
    80001afc:	859d                	srai	a1,a1,0x7
    80001afe:	032585b3          	mul	a1,a1,s2
    80001b02:	2585                	addiw	a1,a1,1
    80001b04:	00d5959b          	slliw	a1,a1,0xd
    kvmmap(kpgtbl, va, (uint64)pa, PGSIZE, PTE_R | PTE_W);
    80001b08:	4719                	li	a4,6
    80001b0a:	6685                	lui	a3,0x1
    80001b0c:	40b985b3          	sub	a1,s3,a1
    80001b10:	8552                	mv	a0,s4
    80001b12:	fffff097          	auipc	ra,0xfffff
    80001b16:	7bc080e7          	jalr	1980(ra) # 800012ce <kvmmap>
  for (p = proc; p < &proc[NPROC]; p++)
    80001b1a:	18048493          	addi	s1,s1,384
    80001b1e:	fd5497e3          	bne	s1,s5,80001aec <proc_mapstacks+0x4a>
  }
}
    80001b22:	70e2                	ld	ra,56(sp)
    80001b24:	7442                	ld	s0,48(sp)
    80001b26:	74a2                	ld	s1,40(sp)
    80001b28:	7902                	ld	s2,32(sp)
    80001b2a:	69e2                	ld	s3,24(sp)
    80001b2c:	6a42                	ld	s4,16(sp)
    80001b2e:	6aa2                	ld	s5,8(sp)
    80001b30:	6b02                	ld	s6,0(sp)
    80001b32:	6121                	addi	sp,sp,64
    80001b34:	8082                	ret
      panic("kalloc");
    80001b36:	00006517          	auipc	a0,0x6
    80001b3a:	6ba50513          	addi	a0,a0,1722 # 800081f0 <etext+0x1f0>
    80001b3e:	fffff097          	auipc	ra,0xfffff
    80001b42:	a22080e7          	jalr	-1502(ra) # 80000560 <panic>

0000000080001b46 <procinit>:

// initialize the proc table.
void procinit(void)
{
    80001b46:	7139                	addi	sp,sp,-64
    80001b48:	fc06                	sd	ra,56(sp)
    80001b4a:	f822                	sd	s0,48(sp)
    80001b4c:	f426                	sd	s1,40(sp)
    80001b4e:	f04a                	sd	s2,32(sp)
    80001b50:	ec4e                	sd	s3,24(sp)
    80001b52:	e852                	sd	s4,16(sp)
    80001b54:	e456                	sd	s5,8(sp)
    80001b56:	e05a                	sd	s6,0(sp)
    80001b58:	0080                	addi	s0,sp,64
  struct proc *p;

  initlock(&pid_lock, "nextpid");
    80001b5a:	00006597          	auipc	a1,0x6
    80001b5e:	69e58593          	addi	a1,a1,1694 # 800081f8 <etext+0x1f8>
    80001b62:	0022f517          	auipc	a0,0x22f
    80001b66:	01e50513          	addi	a0,a0,30 # 80230b80 <pid_lock>
    80001b6a:	fffff097          	auipc	ra,0xfffff
    80001b6e:	174080e7          	jalr	372(ra) # 80000cde <initlock>
  initlock(&wait_lock, "wait_lock");
    80001b72:	00006597          	auipc	a1,0x6
    80001b76:	68e58593          	addi	a1,a1,1678 # 80008200 <etext+0x200>
    80001b7a:	0022f517          	auipc	a0,0x22f
    80001b7e:	01e50513          	addi	a0,a0,30 # 80230b98 <wait_lock>
    80001b82:	fffff097          	auipc	ra,0xfffff
    80001b86:	15c080e7          	jalr	348(ra) # 80000cde <initlock>
  for (p = proc; p < &proc[NPROC]; p++)
    80001b8a:	0022f497          	auipc	s1,0x22f
    80001b8e:	42648493          	addi	s1,s1,1062 # 80230fb0 <proc>
  {
    initlock(&p->lock, "proc");
    80001b92:	00006b17          	auipc	s6,0x6
    80001b96:	67eb0b13          	addi	s6,s6,1662 # 80008210 <etext+0x210>
    p->state = UNUSED;
    p->kstack = KSTACK((int)(p - proc));
    80001b9a:	8aa6                	mv	s5,s1
    80001b9c:	faaab937          	lui	s2,0xfaaab
    80001ba0:	aab90913          	addi	s2,s2,-1365 # fffffffffaaaaaab <end+0xffffffff7a86871b>
    80001ba4:	0932                	slli	s2,s2,0xc
    80001ba6:	aab90913          	addi	s2,s2,-1365
    80001baa:	0932                	slli	s2,s2,0xc
    80001bac:	aab90913          	addi	s2,s2,-1365
    80001bb0:	0932                	slli	s2,s2,0xc
    80001bb2:	aab90913          	addi	s2,s2,-1365
    80001bb6:	040009b7          	lui	s3,0x4000
    80001bba:	19fd                	addi	s3,s3,-1 # 3ffffff <_entry-0x7c000001>
    80001bbc:	09b2                	slli	s3,s3,0xc
  for (p = proc; p < &proc[NPROC]; p++)
    80001bbe:	00235a17          	auipc	s4,0x235
    80001bc2:	3f2a0a13          	addi	s4,s4,1010 # 80236fb0 <tickslock>
    initlock(&p->lock, "proc");
    80001bc6:	85da                	mv	a1,s6
    80001bc8:	00848513          	addi	a0,s1,8
    80001bcc:	fffff097          	auipc	ra,0xfffff
    80001bd0:	112080e7          	jalr	274(ra) # 80000cde <initlock>
    p->state = UNUSED;
    80001bd4:	0204a023          	sw	zero,32(s1)
    p->kstack = KSTACK((int)(p - proc));
    80001bd8:	415487b3          	sub	a5,s1,s5
    80001bdc:	879d                	srai	a5,a5,0x7
    80001bde:	032787b3          	mul	a5,a5,s2
    80001be2:	2785                	addiw	a5,a5,1
    80001be4:	00d7979b          	slliw	a5,a5,0xd
    80001be8:	40f987b3          	sub	a5,s3,a5
    80001bec:	e4bc                	sd	a5,72(s1)
  for (p = proc; p < &proc[NPROC]; p++)
    80001bee:	18048493          	addi	s1,s1,384
    80001bf2:	fd449ae3          	bne	s1,s4,80001bc6 <procinit+0x80>
  }
}
    80001bf6:	70e2                	ld	ra,56(sp)
    80001bf8:	7442                	ld	s0,48(sp)
    80001bfa:	74a2                	ld	s1,40(sp)
    80001bfc:	7902                	ld	s2,32(sp)
    80001bfe:	69e2                	ld	s3,24(sp)
    80001c00:	6a42                	ld	s4,16(sp)
    80001c02:	6aa2                	ld	s5,8(sp)
    80001c04:	6b02                	ld	s6,0(sp)
    80001c06:	6121                	addi	sp,sp,64
    80001c08:	8082                	ret

0000000080001c0a <cpuid>:

// Must be called with interrupts disabled,
// to prevent race with process being moved
// to a different CPU.
int cpuid()
{
    80001c0a:	1141                	addi	sp,sp,-16
    80001c0c:	e422                	sd	s0,8(sp)
    80001c0e:	0800                	addi	s0,sp,16
  asm volatile("mv %0, tp" : "=r" (x) );
    80001c10:	8512                	mv	a0,tp
  int id = r_tp();
  return id;
}
    80001c12:	2501                	sext.w	a0,a0
    80001c14:	6422                	ld	s0,8(sp)
    80001c16:	0141                	addi	sp,sp,16
    80001c18:	8082                	ret

0000000080001c1a <mycpu>:

// Return this CPU's cpu struct.
// Interrupts must be disabled.
struct cpu *
mycpu(void)
{
    80001c1a:	1141                	addi	sp,sp,-16
    80001c1c:	e422                	sd	s0,8(sp)
    80001c1e:	0800                	addi	s0,sp,16
    80001c20:	8792                	mv	a5,tp
  int id = cpuid();
  struct cpu *c = &cpus[id];
    80001c22:	2781                	sext.w	a5,a5
    80001c24:	079e                	slli	a5,a5,0x7
  return c;
}
    80001c26:	0022f517          	auipc	a0,0x22f
    80001c2a:	f8a50513          	addi	a0,a0,-118 # 80230bb0 <cpus>
    80001c2e:	953e                	add	a0,a0,a5
    80001c30:	6422                	ld	s0,8(sp)
    80001c32:	0141                	addi	sp,sp,16
    80001c34:	8082                	ret

0000000080001c36 <myproc>:

// Return the current struct proc *, or zero if none.
struct proc *
myproc(void)
{
    80001c36:	1101                	addi	sp,sp,-32
    80001c38:	ec06                	sd	ra,24(sp)
    80001c3a:	e822                	sd	s0,16(sp)
    80001c3c:	e426                	sd	s1,8(sp)
    80001c3e:	1000                	addi	s0,sp,32
  push_off();
    80001c40:	fffff097          	auipc	ra,0xfffff
    80001c44:	0e2080e7          	jalr	226(ra) # 80000d22 <push_off>
    80001c48:	8792                	mv	a5,tp
  struct cpu *c = mycpu();
  struct proc *p = c->proc;
    80001c4a:	2781                	sext.w	a5,a5
    80001c4c:	079e                	slli	a5,a5,0x7
    80001c4e:	0022f717          	auipc	a4,0x22f
    80001c52:	f3270713          	addi	a4,a4,-206 # 80230b80 <pid_lock>
    80001c56:	97ba                	add	a5,a5,a4
    80001c58:	7b84                	ld	s1,48(a5)
  pop_off();
    80001c5a:	fffff097          	auipc	ra,0xfffff
    80001c5e:	168080e7          	jalr	360(ra) # 80000dc2 <pop_off>
  return p;
}
    80001c62:	8526                	mv	a0,s1
    80001c64:	60e2                	ld	ra,24(sp)
    80001c66:	6442                	ld	s0,16(sp)
    80001c68:	64a2                	ld	s1,8(sp)
    80001c6a:	6105                	addi	sp,sp,32
    80001c6c:	8082                	ret

0000000080001c6e <forkret>:
}

// A fork child's very first scheduling by scheduler()
// will swtch to forkret.
void forkret(void)
{
    80001c6e:	1141                	addi	sp,sp,-16
    80001c70:	e406                	sd	ra,8(sp)
    80001c72:	e022                	sd	s0,0(sp)
    80001c74:	0800                	addi	s0,sp,16
  static int first = 1;

  // Still holding p->lock from scheduler.
  release(&myproc()->lock);
    80001c76:	00000097          	auipc	ra,0x0
    80001c7a:	fc0080e7          	jalr	-64(ra) # 80001c36 <myproc>
    80001c7e:	0521                	addi	a0,a0,8
    80001c80:	fffff097          	auipc	ra,0xfffff
    80001c84:	1a2080e7          	jalr	418(ra) # 80000e22 <release>

  if (first)
    80001c88:	00007797          	auipc	a5,0x7
    80001c8c:	c087a783          	lw	a5,-1016(a5) # 80008890 <first.1>
    80001c90:	eb89                	bnez	a5,80001ca2 <forkret+0x34>
    // be run from main().
    first = 0;
    fsinit(ROOTDEV);
  }

  usertrapret();
    80001c92:	00001097          	auipc	ra,0x1
    80001c96:	e8e080e7          	jalr	-370(ra) # 80002b20 <usertrapret>
}
    80001c9a:	60a2                	ld	ra,8(sp)
    80001c9c:	6402                	ld	s0,0(sp)
    80001c9e:	0141                	addi	sp,sp,16
    80001ca0:	8082                	ret
    first = 0;
    80001ca2:	00007797          	auipc	a5,0x7
    80001ca6:	be07a723          	sw	zero,-1042(a5) # 80008890 <first.1>
    fsinit(ROOTDEV);
    80001caa:	4505                	li	a0,1
    80001cac:	00002097          	auipc	ra,0x2
    80001cb0:	d10080e7          	jalr	-752(ra) # 800039bc <fsinit>
    80001cb4:	bff9                	j	80001c92 <forkret+0x24>

0000000080001cb6 <allocpid>:
{
    80001cb6:	1101                	addi	sp,sp,-32
    80001cb8:	ec06                	sd	ra,24(sp)
    80001cba:	e822                	sd	s0,16(sp)
    80001cbc:	e426                	sd	s1,8(sp)
    80001cbe:	e04a                	sd	s2,0(sp)
    80001cc0:	1000                	addi	s0,sp,32
  acquire(&pid_lock);
    80001cc2:	0022f917          	auipc	s2,0x22f
    80001cc6:	ebe90913          	addi	s2,s2,-322 # 80230b80 <pid_lock>
    80001cca:	854a                	mv	a0,s2
    80001ccc:	fffff097          	auipc	ra,0xfffff
    80001cd0:	0a2080e7          	jalr	162(ra) # 80000d6e <acquire>
  pid = nextpid;
    80001cd4:	00007797          	auipc	a5,0x7
    80001cd8:	bc078793          	addi	a5,a5,-1088 # 80008894 <nextpid>
    80001cdc:	4384                	lw	s1,0(a5)
  nextpid = nextpid + 1;
    80001cde:	0014871b          	addiw	a4,s1,1
    80001ce2:	c398                	sw	a4,0(a5)
  release(&pid_lock);
    80001ce4:	854a                	mv	a0,s2
    80001ce6:	fffff097          	auipc	ra,0xfffff
    80001cea:	13c080e7          	jalr	316(ra) # 80000e22 <release>
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
    80001d0e:	7be080e7          	jalr	1982(ra) # 800014c8 <uvmcreate>
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
    80001d2e:	504080e7          	jalr	1284(ra) # 8000122e <mappages>
    80001d32:	02054863          	bltz	a0,80001d62 <proc_pagetable+0x66>
  if (mappages(pagetable, TRAPFRAME, PGSIZE,
    80001d36:	4719                	li	a4,6
    80001d38:	06093683          	ld	a3,96(s2)
    80001d3c:	6605                	lui	a2,0x1
    80001d3e:	020005b7          	lui	a1,0x2000
    80001d42:	15fd                	addi	a1,a1,-1 # 1ffffff <_entry-0x7e000001>
    80001d44:	05b6                	slli	a1,a1,0xd
    80001d46:	8526                	mv	a0,s1
    80001d48:	fffff097          	auipc	ra,0xfffff
    80001d4c:	4e6080e7          	jalr	1254(ra) # 8000122e <mappages>
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
    80001d6a:	974080e7          	jalr	-1676(ra) # 800016da <uvmfree>
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
    80001d84:	674080e7          	jalr	1652(ra) # 800013f4 <uvmunmap>
    uvmfree(pagetable, 0);
    80001d88:	4581                	li	a1,0
    80001d8a:	8526                	mv	a0,s1
    80001d8c:	00000097          	auipc	ra,0x0
    80001d90:	94e080e7          	jalr	-1714(ra) # 800016da <uvmfree>
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
    80001db8:	640080e7          	jalr	1600(ra) # 800013f4 <uvmunmap>
  uvmunmap(pagetable, TRAPFRAME, 1, 0);
    80001dbc:	4681                	li	a3,0
    80001dbe:	4605                	li	a2,1
    80001dc0:	020005b7          	lui	a1,0x2000
    80001dc4:	15fd                	addi	a1,a1,-1 # 1ffffff <_entry-0x7e000001>
    80001dc6:	05b6                	slli	a1,a1,0xd
    80001dc8:	8526                	mv	a0,s1
    80001dca:	fffff097          	auipc	ra,0xfffff
    80001dce:	62a080e7          	jalr	1578(ra) # 800013f4 <uvmunmap>
  uvmfree(pagetable, sz);
    80001dd2:	85ca                	mv	a1,s2
    80001dd4:	8526                	mv	a0,s1
    80001dd6:	00000097          	auipc	ra,0x0
    80001dda:	904080e7          	jalr	-1788(ra) # 800016da <uvmfree>
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
    80001df6:	7128                	ld	a0,96(a0)
    80001df8:	c509                	beqz	a0,80001e02 <freeproc+0x18>
    kfree((void *)p->trapframe);
    80001dfa:	fffff097          	auipc	ra,0xfffff
    80001dfe:	c50080e7          	jalr	-944(ra) # 80000a4a <kfree>
  p->trapframe = 0;
    80001e02:	0604b023          	sd	zero,96(s1)
  if (p->pagetable)
    80001e06:	6ca8                	ld	a0,88(s1)
    80001e08:	c511                	beqz	a0,80001e14 <freeproc+0x2a>
    proc_freepagetable(p->pagetable, p->sz);
    80001e0a:	68ac                	ld	a1,80(s1)
    80001e0c:	00000097          	auipc	ra,0x0
    80001e10:	f8c080e7          	jalr	-116(ra) # 80001d98 <proc_freepagetable>
  p->pagetable = 0;
    80001e14:	0404bc23          	sd	zero,88(s1)
  p->sz = 0;
    80001e18:	0404b823          	sd	zero,80(s1)
  p->pid = 0;
    80001e1c:	0204ac23          	sw	zero,56(s1)
  p->parent = 0;
    80001e20:	0404b023          	sd	zero,64(s1)
  p->name[0] = 0;
    80001e24:	16048023          	sb	zero,352(s1)
  p->chan = 0;
    80001e28:	0204b423          	sd	zero,40(s1)
  p->killed = 0;
    80001e2c:	0204a823          	sw	zero,48(s1)
  p->xstate = 0;
    80001e30:	0204aa23          	sw	zero,52(s1)
  p->state = UNUSED;
    80001e34:	0204a023          	sw	zero,32(s1)
}
    80001e38:	60e2                	ld	ra,24(sp)
    80001e3a:	6442                	ld	s0,16(sp)
    80001e3c:	64a2                	ld	s1,8(sp)
    80001e3e:	6105                	addi	sp,sp,32
    80001e40:	8082                	ret

0000000080001e42 <allocproc>:
{
    80001e42:	7179                	addi	sp,sp,-48
    80001e44:	f406                	sd	ra,40(sp)
    80001e46:	f022                	sd	s0,32(sp)
    80001e48:	ec26                	sd	s1,24(sp)
    80001e4a:	e84a                	sd	s2,16(sp)
    80001e4c:	e44e                	sd	s3,8(sp)
    80001e4e:	1800                	addi	s0,sp,48
  for (p = proc; p < &proc[NPROC]; p++)
    80001e50:	0022f497          	auipc	s1,0x22f
    80001e54:	16048493          	addi	s1,s1,352 # 80230fb0 <proc>
    80001e58:	00235997          	auipc	s3,0x235
    80001e5c:	15898993          	addi	s3,s3,344 # 80236fb0 <tickslock>
    acquire(&p->lock);
    80001e60:	00848913          	addi	s2,s1,8
    80001e64:	854a                	mv	a0,s2
    80001e66:	fffff097          	auipc	ra,0xfffff
    80001e6a:	f08080e7          	jalr	-248(ra) # 80000d6e <acquire>
    if (p->state == UNUSED)
    80001e6e:	509c                	lw	a5,32(s1)
    80001e70:	cf81                	beqz	a5,80001e88 <allocproc+0x46>
      release(&p->lock);
    80001e72:	854a                	mv	a0,s2
    80001e74:	fffff097          	auipc	ra,0xfffff
    80001e78:	fae080e7          	jalr	-82(ra) # 80000e22 <release>
  for (p = proc; p < &proc[NPROC]; p++)
    80001e7c:	18048493          	addi	s1,s1,384
    80001e80:	ff3490e3          	bne	s1,s3,80001e60 <allocproc+0x1e>
  return 0;
    80001e84:	4481                	li	s1,0
    80001e86:	a0ad                	j	80001ef0 <allocproc+0xae>
  p->pid = allocpid();
    80001e88:	00000097          	auipc	ra,0x0
    80001e8c:	e2e080e7          	jalr	-466(ra) # 80001cb6 <allocpid>
    80001e90:	dc88                	sw	a0,56(s1)
  p->state = USED;
    80001e92:	4785                	li	a5,1
    80001e94:	d09c                	sw	a5,32(s1)
  p->cow_page_faults = 0;
    80001e96:	0004a023          	sw	zero,0(s1)
  if ((p->trapframe = (struct trapframe *)kalloc()) == 0)
    80001e9a:	fffff097          	auipc	ra,0xfffff
    80001e9e:	d34080e7          	jalr	-716(ra) # 80000bce <kalloc>
    80001ea2:	89aa                	mv	s3,a0
    80001ea4:	f0a8                	sd	a0,96(s1)
    80001ea6:	cd29                	beqz	a0,80001f00 <allocproc+0xbe>
  p->pagetable = proc_pagetable(p);
    80001ea8:	8526                	mv	a0,s1
    80001eaa:	00000097          	auipc	ra,0x0
    80001eae:	e52080e7          	jalr	-430(ra) # 80001cfc <proc_pagetable>
    80001eb2:	89aa                	mv	s3,a0
    80001eb4:	eca8                	sd	a0,88(s1)
  if (p->pagetable == 0)
    80001eb6:	c12d                	beqz	a0,80001f18 <allocproc+0xd6>
  memset(&p->context, 0, sizeof(p->context));
    80001eb8:	07000613          	li	a2,112
    80001ebc:	4581                	li	a1,0
    80001ebe:	06848513          	addi	a0,s1,104
    80001ec2:	fffff097          	auipc	ra,0xfffff
    80001ec6:	fa8080e7          	jalr	-88(ra) # 80000e6a <memset>
  p->context.ra = (uint64)forkret;
    80001eca:	00000797          	auipc	a5,0x0
    80001ece:	da478793          	addi	a5,a5,-604 # 80001c6e <forkret>
    80001ed2:	f4bc                	sd	a5,104(s1)
  p->context.sp = p->kstack + PGSIZE;
    80001ed4:	64bc                	ld	a5,72(s1)
    80001ed6:	6705                	lui	a4,0x1
    80001ed8:	97ba                	add	a5,a5,a4
    80001eda:	f8bc                	sd	a5,112(s1)
  p->rtime = 0;
    80001edc:	1604a823          	sw	zero,368(s1)
  p->etime = 0;
    80001ee0:	1604ac23          	sw	zero,376(s1)
  p->ctime = ticks;
    80001ee4:	00007797          	auipc	a5,0x7
    80001ee8:	a347a783          	lw	a5,-1484(a5) # 80008918 <ticks>
    80001eec:	16f4aa23          	sw	a5,372(s1)
}
    80001ef0:	8526                	mv	a0,s1
    80001ef2:	70a2                	ld	ra,40(sp)
    80001ef4:	7402                	ld	s0,32(sp)
    80001ef6:	64e2                	ld	s1,24(sp)
    80001ef8:	6942                	ld	s2,16(sp)
    80001efa:	69a2                	ld	s3,8(sp)
    80001efc:	6145                	addi	sp,sp,48
    80001efe:	8082                	ret
    freeproc(p);
    80001f00:	8526                	mv	a0,s1
    80001f02:	00000097          	auipc	ra,0x0
    80001f06:	ee8080e7          	jalr	-280(ra) # 80001dea <freeproc>
    release(&p->lock);
    80001f0a:	854a                	mv	a0,s2
    80001f0c:	fffff097          	auipc	ra,0xfffff
    80001f10:	f16080e7          	jalr	-234(ra) # 80000e22 <release>
    return 0;
    80001f14:	84ce                	mv	s1,s3
    80001f16:	bfe9                	j	80001ef0 <allocproc+0xae>
    freeproc(p);
    80001f18:	8526                	mv	a0,s1
    80001f1a:	00000097          	auipc	ra,0x0
    80001f1e:	ed0080e7          	jalr	-304(ra) # 80001dea <freeproc>
    release(&p->lock);
    80001f22:	854a                	mv	a0,s2
    80001f24:	fffff097          	auipc	ra,0xfffff
    80001f28:	efe080e7          	jalr	-258(ra) # 80000e22 <release>
    return 0;
    80001f2c:	84ce                	mv	s1,s3
    80001f2e:	b7c9                	j	80001ef0 <allocproc+0xae>

0000000080001f30 <userinit>:
{
    80001f30:	1101                	addi	sp,sp,-32
    80001f32:	ec06                	sd	ra,24(sp)
    80001f34:	e822                	sd	s0,16(sp)
    80001f36:	e426                	sd	s1,8(sp)
    80001f38:	1000                	addi	s0,sp,32
  p = allocproc();
    80001f3a:	00000097          	auipc	ra,0x0
    80001f3e:	f08080e7          	jalr	-248(ra) # 80001e42 <allocproc>
    80001f42:	84aa                	mv	s1,a0
  initproc = p;
    80001f44:	00007797          	auipc	a5,0x7
    80001f48:	9ca7b223          	sd	a0,-1596(a5) # 80008908 <initproc>
  uvmfirst(p->pagetable, initcode, sizeof(initcode));
    80001f4c:	03400613          	li	a2,52
    80001f50:	00007597          	auipc	a1,0x7
    80001f54:	95058593          	addi	a1,a1,-1712 # 800088a0 <initcode>
    80001f58:	6d28                	ld	a0,88(a0)
    80001f5a:	fffff097          	auipc	ra,0xfffff
    80001f5e:	59c080e7          	jalr	1436(ra) # 800014f6 <uvmfirst>
  p->sz = PGSIZE;
    80001f62:	6785                	lui	a5,0x1
    80001f64:	e8bc                	sd	a5,80(s1)
  p->trapframe->epc = 0;     // user program counter
    80001f66:	70b8                	ld	a4,96(s1)
    80001f68:	00073c23          	sd	zero,24(a4) # 1018 <_entry-0x7fffefe8>
  p->trapframe->sp = PGSIZE; // user stack pointer
    80001f6c:	70b8                	ld	a4,96(s1)
    80001f6e:	fb1c                	sd	a5,48(a4)
  safestrcpy(p->name, "initcode", sizeof(p->name));
    80001f70:	4641                	li	a2,16
    80001f72:	00006597          	auipc	a1,0x6
    80001f76:	2a658593          	addi	a1,a1,678 # 80008218 <etext+0x218>
    80001f7a:	16048513          	addi	a0,s1,352
    80001f7e:	fffff097          	auipc	ra,0xfffff
    80001f82:	02e080e7          	jalr	46(ra) # 80000fac <safestrcpy>
  p->cwd = namei("/");
    80001f86:	00006517          	auipc	a0,0x6
    80001f8a:	2a250513          	addi	a0,a0,674 # 80008228 <etext+0x228>
    80001f8e:	00002097          	auipc	ra,0x2
    80001f92:	480080e7          	jalr	1152(ra) # 8000440e <namei>
    80001f96:	14a4bc23          	sd	a0,344(s1)
  p->state = RUNNABLE;
    80001f9a:	478d                	li	a5,3
    80001f9c:	d09c                	sw	a5,32(s1)
  release(&p->lock);
    80001f9e:	00848513          	addi	a0,s1,8
    80001fa2:	fffff097          	auipc	ra,0xfffff
    80001fa6:	e80080e7          	jalr	-384(ra) # 80000e22 <release>
}
    80001faa:	60e2                	ld	ra,24(sp)
    80001fac:	6442                	ld	s0,16(sp)
    80001fae:	64a2                	ld	s1,8(sp)
    80001fb0:	6105                	addi	sp,sp,32
    80001fb2:	8082                	ret

0000000080001fb4 <growproc>:
{
    80001fb4:	1101                	addi	sp,sp,-32
    80001fb6:	ec06                	sd	ra,24(sp)
    80001fb8:	e822                	sd	s0,16(sp)
    80001fba:	e426                	sd	s1,8(sp)
    80001fbc:	e04a                	sd	s2,0(sp)
    80001fbe:	1000                	addi	s0,sp,32
    80001fc0:	892a                	mv	s2,a0
  struct proc *p = myproc();
    80001fc2:	00000097          	auipc	ra,0x0
    80001fc6:	c74080e7          	jalr	-908(ra) # 80001c36 <myproc>
    80001fca:	84aa                	mv	s1,a0
  sz = p->sz;
    80001fcc:	692c                	ld	a1,80(a0)
  if (n > 0)
    80001fce:	01204c63          	bgtz	s2,80001fe6 <growproc+0x32>
  else if (n < 0)
    80001fd2:	02094663          	bltz	s2,80001ffe <growproc+0x4a>
  p->sz = sz;
    80001fd6:	e8ac                	sd	a1,80(s1)
  return 0;
    80001fd8:	4501                	li	a0,0
}
    80001fda:	60e2                	ld	ra,24(sp)
    80001fdc:	6442                	ld	s0,16(sp)
    80001fde:	64a2                	ld	s1,8(sp)
    80001fe0:	6902                	ld	s2,0(sp)
    80001fe2:	6105                	addi	sp,sp,32
    80001fe4:	8082                	ret
    if ((sz = uvmalloc(p->pagetable, sz, sz + n, PTE_W)) == 0)
    80001fe6:	4691                	li	a3,4
    80001fe8:	00b90633          	add	a2,s2,a1
    80001fec:	6d28                	ld	a0,88(a0)
    80001fee:	fffff097          	auipc	ra,0xfffff
    80001ff2:	5c2080e7          	jalr	1474(ra) # 800015b0 <uvmalloc>
    80001ff6:	85aa                	mv	a1,a0
    80001ff8:	fd79                	bnez	a0,80001fd6 <growproc+0x22>
      return -1;
    80001ffa:	557d                	li	a0,-1
    80001ffc:	bff9                	j	80001fda <growproc+0x26>
    sz = uvmdealloc(p->pagetable, sz, sz + n);
    80001ffe:	00b90633          	add	a2,s2,a1
    80002002:	6d28                	ld	a0,88(a0)
    80002004:	fffff097          	auipc	ra,0xfffff
    80002008:	564080e7          	jalr	1380(ra) # 80001568 <uvmdealloc>
    8000200c:	85aa                	mv	a1,a0
    8000200e:	b7e1                	j	80001fd6 <growproc+0x22>

0000000080002010 <fork>:
{
    80002010:	7139                	addi	sp,sp,-64
    80002012:	fc06                	sd	ra,56(sp)
    80002014:	f822                	sd	s0,48(sp)
    80002016:	ec4e                	sd	s3,24(sp)
    80002018:	e456                	sd	s5,8(sp)
    8000201a:	0080                	addi	s0,sp,64
  struct proc *p = myproc();
    8000201c:	00000097          	auipc	ra,0x0
    80002020:	c1a080e7          	jalr	-998(ra) # 80001c36 <myproc>
    80002024:	8aaa                	mv	s5,a0
  if ((np = allocproc()) == 0)
    80002026:	00000097          	auipc	ra,0x0
    8000202a:	e1c080e7          	jalr	-484(ra) # 80001e42 <allocproc>
    8000202e:	12050363          	beqz	a0,80002154 <fork+0x144>
    80002032:	e852                	sd	s4,16(sp)
    80002034:	8a2a                	mv	s4,a0
  if (uvmcopy(p->pagetable, np->pagetable, p->sz) < 0)
    80002036:	050ab603          	ld	a2,80(s5)
    8000203a:	6d2c                	ld	a1,88(a0)
    8000203c:	058ab503          	ld	a0,88(s5)
    80002040:	fffff097          	auipc	ra,0xfffff
    80002044:	6d4080e7          	jalr	1748(ra) # 80001714 <uvmcopy>
    80002048:	04054a63          	bltz	a0,8000209c <fork+0x8c>
    8000204c:	f426                	sd	s1,40(sp)
    8000204e:	f04a                	sd	s2,32(sp)
  np->sz = p->sz;
    80002050:	050ab783          	ld	a5,80(s5)
    80002054:	04fa3823          	sd	a5,80(s4)
  *(np->trapframe) = *(p->trapframe);
    80002058:	060ab683          	ld	a3,96(s5)
    8000205c:	87b6                	mv	a5,a3
    8000205e:	060a3703          	ld	a4,96(s4)
    80002062:	12068693          	addi	a3,a3,288
    80002066:	0007b803          	ld	a6,0(a5) # 1000 <_entry-0x7ffff000>
    8000206a:	6788                	ld	a0,8(a5)
    8000206c:	6b8c                	ld	a1,16(a5)
    8000206e:	6f90                	ld	a2,24(a5)
    80002070:	01073023          	sd	a6,0(a4)
    80002074:	e708                	sd	a0,8(a4)
    80002076:	eb0c                	sd	a1,16(a4)
    80002078:	ef10                	sd	a2,24(a4)
    8000207a:	02078793          	addi	a5,a5,32
    8000207e:	02070713          	addi	a4,a4,32
    80002082:	fed792e3          	bne	a5,a3,80002066 <fork+0x56>
  np->trapframe->a0 = 0;
    80002086:	060a3783          	ld	a5,96(s4)
    8000208a:	0607b823          	sd	zero,112(a5)
  for (i = 0; i < NOFILE; i++)
    8000208e:	0d8a8493          	addi	s1,s5,216
    80002092:	0d8a0913          	addi	s2,s4,216
    80002096:	158a8993          	addi	s3,s5,344
    8000209a:	a01d                	j	800020c0 <fork+0xb0>
    freeproc(np);
    8000209c:	8552                	mv	a0,s4
    8000209e:	00000097          	auipc	ra,0x0
    800020a2:	d4c080e7          	jalr	-692(ra) # 80001dea <freeproc>
    release(&np->lock);
    800020a6:	008a0513          	addi	a0,s4,8
    800020aa:	fffff097          	auipc	ra,0xfffff
    800020ae:	d78080e7          	jalr	-648(ra) # 80000e22 <release>
    return -1;
    800020b2:	59fd                	li	s3,-1
    800020b4:	6a42                	ld	s4,16(sp)
    800020b6:	a841                	j	80002146 <fork+0x136>
  for (i = 0; i < NOFILE; i++)
    800020b8:	04a1                	addi	s1,s1,8
    800020ba:	0921                	addi	s2,s2,8
    800020bc:	01348b63          	beq	s1,s3,800020d2 <fork+0xc2>
    if (p->ofile[i])
    800020c0:	6088                	ld	a0,0(s1)
    800020c2:	d97d                	beqz	a0,800020b8 <fork+0xa8>
      np->ofile[i] = filedup(p->ofile[i]);
    800020c4:	00003097          	auipc	ra,0x3
    800020c8:	9c2080e7          	jalr	-1598(ra) # 80004a86 <filedup>
    800020cc:	00a93023          	sd	a0,0(s2)
    800020d0:	b7e5                	j	800020b8 <fork+0xa8>
  np->cwd = idup(p->cwd);
    800020d2:	158ab503          	ld	a0,344(s5)
    800020d6:	00002097          	auipc	ra,0x2
    800020da:	b2c080e7          	jalr	-1236(ra) # 80003c02 <idup>
    800020de:	14aa3c23          	sd	a0,344(s4)
  safestrcpy(np->name, p->name, sizeof(p->name));
    800020e2:	4641                	li	a2,16
    800020e4:	160a8593          	addi	a1,s5,352
    800020e8:	160a0513          	addi	a0,s4,352
    800020ec:	fffff097          	auipc	ra,0xfffff
    800020f0:	ec0080e7          	jalr	-320(ra) # 80000fac <safestrcpy>
  pid = np->pid;
    800020f4:	038a2983          	lw	s3,56(s4)
  release(&np->lock);
    800020f8:	008a0493          	addi	s1,s4,8
    800020fc:	8526                	mv	a0,s1
    800020fe:	fffff097          	auipc	ra,0xfffff
    80002102:	d24080e7          	jalr	-732(ra) # 80000e22 <release>
  acquire(&wait_lock);
    80002106:	0022f917          	auipc	s2,0x22f
    8000210a:	a9290913          	addi	s2,s2,-1390 # 80230b98 <wait_lock>
    8000210e:	854a                	mv	a0,s2
    80002110:	fffff097          	auipc	ra,0xfffff
    80002114:	c5e080e7          	jalr	-930(ra) # 80000d6e <acquire>
  np->parent = p;
    80002118:	055a3023          	sd	s5,64(s4)
  release(&wait_lock);
    8000211c:	854a                	mv	a0,s2
    8000211e:	fffff097          	auipc	ra,0xfffff
    80002122:	d04080e7          	jalr	-764(ra) # 80000e22 <release>
  acquire(&np->lock);
    80002126:	8526                	mv	a0,s1
    80002128:	fffff097          	auipc	ra,0xfffff
    8000212c:	c46080e7          	jalr	-954(ra) # 80000d6e <acquire>
  np->state = RUNNABLE;
    80002130:	478d                	li	a5,3
    80002132:	02fa2023          	sw	a5,32(s4)
  release(&np->lock);
    80002136:	8526                	mv	a0,s1
    80002138:	fffff097          	auipc	ra,0xfffff
    8000213c:	cea080e7          	jalr	-790(ra) # 80000e22 <release>
  return pid;
    80002140:	74a2                	ld	s1,40(sp)
    80002142:	7902                	ld	s2,32(sp)
    80002144:	6a42                	ld	s4,16(sp)
}
    80002146:	854e                	mv	a0,s3
    80002148:	70e2                	ld	ra,56(sp)
    8000214a:	7442                	ld	s0,48(sp)
    8000214c:	69e2                	ld	s3,24(sp)
    8000214e:	6aa2                	ld	s5,8(sp)
    80002150:	6121                	addi	sp,sp,64
    80002152:	8082                	ret
    return -1;
    80002154:	59fd                	li	s3,-1
    80002156:	bfc5                	j	80002146 <fork+0x136>

0000000080002158 <scheduler>:
{
    80002158:	715d                	addi	sp,sp,-80
    8000215a:	e486                	sd	ra,72(sp)
    8000215c:	e0a2                	sd	s0,64(sp)
    8000215e:	fc26                	sd	s1,56(sp)
    80002160:	f84a                	sd	s2,48(sp)
    80002162:	f44e                	sd	s3,40(sp)
    80002164:	f052                	sd	s4,32(sp)
    80002166:	ec56                	sd	s5,24(sp)
    80002168:	e85a                	sd	s6,16(sp)
    8000216a:	e45e                	sd	s7,8(sp)
    8000216c:	0880                	addi	s0,sp,80
    8000216e:	8792                	mv	a5,tp
  int id = r_tp();
    80002170:	2781                	sext.w	a5,a5
  c->proc = 0;
    80002172:	00779b13          	slli	s6,a5,0x7
    80002176:	0022f717          	auipc	a4,0x22f
    8000217a:	a0a70713          	addi	a4,a4,-1526 # 80230b80 <pid_lock>
    8000217e:	975a                	add	a4,a4,s6
    80002180:	02073823          	sd	zero,48(a4)
        swtch(&c->context, &p->context);
    80002184:	0022f717          	auipc	a4,0x22f
    80002188:	a3470713          	addi	a4,a4,-1484 # 80230bb8 <cpus+0x8>
    8000218c:	9b3a                	add	s6,s6,a4
      if (p->state == RUNNABLE)
    8000218e:	4a0d                	li	s4,3
        p->state = RUNNING;
    80002190:	4b91                	li	s7,4
        c->proc = p;
    80002192:	079e                	slli	a5,a5,0x7
    80002194:	0022fa97          	auipc	s5,0x22f
    80002198:	9eca8a93          	addi	s5,s5,-1556 # 80230b80 <pid_lock>
    8000219c:	9abe                	add	s5,s5,a5
    for (p = proc; p < &proc[NPROC]; p++)
    8000219e:	00235997          	auipc	s3,0x235
    800021a2:	e1298993          	addi	s3,s3,-494 # 80236fb0 <tickslock>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    800021a6:	100027f3          	csrr	a5,sstatus
  w_sstatus(r_sstatus() | SSTATUS_SIE);
    800021aa:	0027e793          	ori	a5,a5,2
  asm volatile("csrw sstatus, %0" : : "r" (x));
    800021ae:	10079073          	csrw	sstatus,a5
    800021b2:	0022f497          	auipc	s1,0x22f
    800021b6:	dfe48493          	addi	s1,s1,-514 # 80230fb0 <proc>
    800021ba:	a811                	j	800021ce <scheduler+0x76>
      release(&p->lock);
    800021bc:	854a                	mv	a0,s2
    800021be:	fffff097          	auipc	ra,0xfffff
    800021c2:	c64080e7          	jalr	-924(ra) # 80000e22 <release>
    for (p = proc; p < &proc[NPROC]; p++)
    800021c6:	18048493          	addi	s1,s1,384
    800021ca:	fd348ee3          	beq	s1,s3,800021a6 <scheduler+0x4e>
      acquire(&p->lock);
    800021ce:	00848913          	addi	s2,s1,8
    800021d2:	854a                	mv	a0,s2
    800021d4:	fffff097          	auipc	ra,0xfffff
    800021d8:	b9a080e7          	jalr	-1126(ra) # 80000d6e <acquire>
      if (p->state == RUNNABLE)
    800021dc:	509c                	lw	a5,32(s1)
    800021de:	fd479fe3          	bne	a5,s4,800021bc <scheduler+0x64>
        p->state = RUNNING;
    800021e2:	0374a023          	sw	s7,32(s1)
        c->proc = p;
    800021e6:	029ab823          	sd	s1,48(s5)
        swtch(&c->context, &p->context);
    800021ea:	06848593          	addi	a1,s1,104
    800021ee:	855a                	mv	a0,s6
    800021f0:	00001097          	auipc	ra,0x1
    800021f4:	886080e7          	jalr	-1914(ra) # 80002a76 <swtch>
        c->proc = 0;
    800021f8:	020ab823          	sd	zero,48(s5)
    800021fc:	b7c1                	j	800021bc <scheduler+0x64>

00000000800021fe <sched>:
{
    800021fe:	7179                	addi	sp,sp,-48
    80002200:	f406                	sd	ra,40(sp)
    80002202:	f022                	sd	s0,32(sp)
    80002204:	ec26                	sd	s1,24(sp)
    80002206:	e84a                	sd	s2,16(sp)
    80002208:	e44e                	sd	s3,8(sp)
    8000220a:	1800                	addi	s0,sp,48
  struct proc *p = myproc();
    8000220c:	00000097          	auipc	ra,0x0
    80002210:	a2a080e7          	jalr	-1494(ra) # 80001c36 <myproc>
    80002214:	84aa                	mv	s1,a0
  if (!holding(&p->lock))
    80002216:	0521                	addi	a0,a0,8
    80002218:	fffff097          	auipc	ra,0xfffff
    8000221c:	adc080e7          	jalr	-1316(ra) # 80000cf4 <holding>
    80002220:	c93d                	beqz	a0,80002296 <sched+0x98>
  asm volatile("mv %0, tp" : "=r" (x) );
    80002222:	8792                	mv	a5,tp
  if (mycpu()->noff != 1)
    80002224:	2781                	sext.w	a5,a5
    80002226:	079e                	slli	a5,a5,0x7
    80002228:	0022f717          	auipc	a4,0x22f
    8000222c:	95870713          	addi	a4,a4,-1704 # 80230b80 <pid_lock>
    80002230:	97ba                	add	a5,a5,a4
    80002232:	0a87a703          	lw	a4,168(a5)
    80002236:	4785                	li	a5,1
    80002238:	06f71763          	bne	a4,a5,800022a6 <sched+0xa8>
  if (p->state == RUNNING)
    8000223c:	5098                	lw	a4,32(s1)
    8000223e:	4791                	li	a5,4
    80002240:	06f70b63          	beq	a4,a5,800022b6 <sched+0xb8>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80002244:	100027f3          	csrr	a5,sstatus
  return (x & SSTATUS_SIE) != 0;
    80002248:	8b89                	andi	a5,a5,2
  if (intr_get())
    8000224a:	efb5                	bnez	a5,800022c6 <sched+0xc8>
  asm volatile("mv %0, tp" : "=r" (x) );
    8000224c:	8792                	mv	a5,tp
  intena = mycpu()->intena;
    8000224e:	0022f917          	auipc	s2,0x22f
    80002252:	93290913          	addi	s2,s2,-1742 # 80230b80 <pid_lock>
    80002256:	2781                	sext.w	a5,a5
    80002258:	079e                	slli	a5,a5,0x7
    8000225a:	97ca                	add	a5,a5,s2
    8000225c:	0ac7a983          	lw	s3,172(a5)
    80002260:	8792                	mv	a5,tp
  swtch(&p->context, &mycpu()->context);
    80002262:	2781                	sext.w	a5,a5
    80002264:	079e                	slli	a5,a5,0x7
    80002266:	0022f597          	auipc	a1,0x22f
    8000226a:	95258593          	addi	a1,a1,-1710 # 80230bb8 <cpus+0x8>
    8000226e:	95be                	add	a1,a1,a5
    80002270:	06848513          	addi	a0,s1,104
    80002274:	00001097          	auipc	ra,0x1
    80002278:	802080e7          	jalr	-2046(ra) # 80002a76 <swtch>
    8000227c:	8792                	mv	a5,tp
  mycpu()->intena = intena;
    8000227e:	2781                	sext.w	a5,a5
    80002280:	079e                	slli	a5,a5,0x7
    80002282:	993e                	add	s2,s2,a5
    80002284:	0b392623          	sw	s3,172(s2)
}
    80002288:	70a2                	ld	ra,40(sp)
    8000228a:	7402                	ld	s0,32(sp)
    8000228c:	64e2                	ld	s1,24(sp)
    8000228e:	6942                	ld	s2,16(sp)
    80002290:	69a2                	ld	s3,8(sp)
    80002292:	6145                	addi	sp,sp,48
    80002294:	8082                	ret
    panic("sched p->lock");
    80002296:	00006517          	auipc	a0,0x6
    8000229a:	f9a50513          	addi	a0,a0,-102 # 80008230 <etext+0x230>
    8000229e:	ffffe097          	auipc	ra,0xffffe
    800022a2:	2c2080e7          	jalr	706(ra) # 80000560 <panic>
    panic("sched locks");
    800022a6:	00006517          	auipc	a0,0x6
    800022aa:	f9a50513          	addi	a0,a0,-102 # 80008240 <etext+0x240>
    800022ae:	ffffe097          	auipc	ra,0xffffe
    800022b2:	2b2080e7          	jalr	690(ra) # 80000560 <panic>
    panic("sched running");
    800022b6:	00006517          	auipc	a0,0x6
    800022ba:	f9a50513          	addi	a0,a0,-102 # 80008250 <etext+0x250>
    800022be:	ffffe097          	auipc	ra,0xffffe
    800022c2:	2a2080e7          	jalr	674(ra) # 80000560 <panic>
    panic("sched interruptible");
    800022c6:	00006517          	auipc	a0,0x6
    800022ca:	f9a50513          	addi	a0,a0,-102 # 80008260 <etext+0x260>
    800022ce:	ffffe097          	auipc	ra,0xffffe
    800022d2:	292080e7          	jalr	658(ra) # 80000560 <panic>

00000000800022d6 <yield>:
{
    800022d6:	1101                	addi	sp,sp,-32
    800022d8:	ec06                	sd	ra,24(sp)
    800022da:	e822                	sd	s0,16(sp)
    800022dc:	e426                	sd	s1,8(sp)
    800022de:	e04a                	sd	s2,0(sp)
    800022e0:	1000                	addi	s0,sp,32
  struct proc *p = myproc();
    800022e2:	00000097          	auipc	ra,0x0
    800022e6:	954080e7          	jalr	-1708(ra) # 80001c36 <myproc>
    800022ea:	84aa                	mv	s1,a0
  acquire(&p->lock);
    800022ec:	00850913          	addi	s2,a0,8
    800022f0:	854a                	mv	a0,s2
    800022f2:	fffff097          	auipc	ra,0xfffff
    800022f6:	a7c080e7          	jalr	-1412(ra) # 80000d6e <acquire>
  p->state = RUNNABLE;
    800022fa:	478d                	li	a5,3
    800022fc:	d09c                	sw	a5,32(s1)
  sched();
    800022fe:	00000097          	auipc	ra,0x0
    80002302:	f00080e7          	jalr	-256(ra) # 800021fe <sched>
  release(&p->lock);
    80002306:	854a                	mv	a0,s2
    80002308:	fffff097          	auipc	ra,0xfffff
    8000230c:	b1a080e7          	jalr	-1254(ra) # 80000e22 <release>
}
    80002310:	60e2                	ld	ra,24(sp)
    80002312:	6442                	ld	s0,16(sp)
    80002314:	64a2                	ld	s1,8(sp)
    80002316:	6902                	ld	s2,0(sp)
    80002318:	6105                	addi	sp,sp,32
    8000231a:	8082                	ret

000000008000231c <sleep>:

// Atomically release lock and sleep on chan.
// Reacquires lock when awakened.
void sleep(void *chan, struct spinlock *lk)
{
    8000231c:	7179                	addi	sp,sp,-48
    8000231e:	f406                	sd	ra,40(sp)
    80002320:	f022                	sd	s0,32(sp)
    80002322:	ec26                	sd	s1,24(sp)
    80002324:	e84a                	sd	s2,16(sp)
    80002326:	e44e                	sd	s3,8(sp)
    80002328:	e052                	sd	s4,0(sp)
    8000232a:	1800                	addi	s0,sp,48
    8000232c:	89aa                	mv	s3,a0
    8000232e:	892e                	mv	s2,a1
  struct proc *p = myproc();
    80002330:	00000097          	auipc	ra,0x0
    80002334:	906080e7          	jalr	-1786(ra) # 80001c36 <myproc>
    80002338:	84aa                	mv	s1,a0
  // Once we hold p->lock, we can be
  // guaranteed that we won't miss any wakeup
  // (wakeup locks p->lock),
  // so it's okay to release lk.

  acquire(&p->lock); // DOC: sleeplock1
    8000233a:	00850a13          	addi	s4,a0,8
    8000233e:	8552                	mv	a0,s4
    80002340:	fffff097          	auipc	ra,0xfffff
    80002344:	a2e080e7          	jalr	-1490(ra) # 80000d6e <acquire>
  release(lk);
    80002348:	854a                	mv	a0,s2
    8000234a:	fffff097          	auipc	ra,0xfffff
    8000234e:	ad8080e7          	jalr	-1320(ra) # 80000e22 <release>

  // Go to sleep.
  p->chan = chan;
    80002352:	0334b423          	sd	s3,40(s1)
  p->state = SLEEPING;
    80002356:	4789                	li	a5,2
    80002358:	d09c                	sw	a5,32(s1)

  sched();
    8000235a:	00000097          	auipc	ra,0x0
    8000235e:	ea4080e7          	jalr	-348(ra) # 800021fe <sched>

  // Tidy up.
  p->chan = 0;
    80002362:	0204b423          	sd	zero,40(s1)

  // Reacquire original lock.
  release(&p->lock);
    80002366:	8552                	mv	a0,s4
    80002368:	fffff097          	auipc	ra,0xfffff
    8000236c:	aba080e7          	jalr	-1350(ra) # 80000e22 <release>
  acquire(lk);
    80002370:	854a                	mv	a0,s2
    80002372:	fffff097          	auipc	ra,0xfffff
    80002376:	9fc080e7          	jalr	-1540(ra) # 80000d6e <acquire>
}
    8000237a:	70a2                	ld	ra,40(sp)
    8000237c:	7402                	ld	s0,32(sp)
    8000237e:	64e2                	ld	s1,24(sp)
    80002380:	6942                	ld	s2,16(sp)
    80002382:	69a2                	ld	s3,8(sp)
    80002384:	6a02                	ld	s4,0(sp)
    80002386:	6145                	addi	sp,sp,48
    80002388:	8082                	ret

000000008000238a <wakeup>:

// Wake up all processes sleeping on chan.
// Must be called without any p->lock.
void wakeup(void *chan)
{
    8000238a:	7139                	addi	sp,sp,-64
    8000238c:	fc06                	sd	ra,56(sp)
    8000238e:	f822                	sd	s0,48(sp)
    80002390:	f426                	sd	s1,40(sp)
    80002392:	f04a                	sd	s2,32(sp)
    80002394:	ec4e                	sd	s3,24(sp)
    80002396:	e852                	sd	s4,16(sp)
    80002398:	e456                	sd	s5,8(sp)
    8000239a:	e05a                	sd	s6,0(sp)
    8000239c:	0080                	addi	s0,sp,64
    8000239e:	8aaa                	mv	s5,a0
  struct proc *p;

  for (p = proc; p < &proc[NPROC]; p++)
    800023a0:	0022f497          	auipc	s1,0x22f
    800023a4:	c1048493          	addi	s1,s1,-1008 # 80230fb0 <proc>
  {
    if (p != myproc())
    {
      acquire(&p->lock);
      if (p->state == SLEEPING && p->chan == chan)
    800023a8:	4a09                	li	s4,2
      {
        p->state = RUNNABLE;
    800023aa:	4b0d                	li	s6,3
  for (p = proc; p < &proc[NPROC]; p++)
    800023ac:	00235997          	auipc	s3,0x235
    800023b0:	c0498993          	addi	s3,s3,-1020 # 80236fb0 <tickslock>
    800023b4:	a811                	j	800023c8 <wakeup+0x3e>
      }
      release(&p->lock);
    800023b6:	854a                	mv	a0,s2
    800023b8:	fffff097          	auipc	ra,0xfffff
    800023bc:	a6a080e7          	jalr	-1430(ra) # 80000e22 <release>
  for (p = proc; p < &proc[NPROC]; p++)
    800023c0:	18048493          	addi	s1,s1,384
    800023c4:	03348863          	beq	s1,s3,800023f4 <wakeup+0x6a>
    if (p != myproc())
    800023c8:	00000097          	auipc	ra,0x0
    800023cc:	86e080e7          	jalr	-1938(ra) # 80001c36 <myproc>
    800023d0:	fea488e3          	beq	s1,a0,800023c0 <wakeup+0x36>
      acquire(&p->lock);
    800023d4:	00848913          	addi	s2,s1,8
    800023d8:	854a                	mv	a0,s2
    800023da:	fffff097          	auipc	ra,0xfffff
    800023de:	994080e7          	jalr	-1644(ra) # 80000d6e <acquire>
      if (p->state == SLEEPING && p->chan == chan)
    800023e2:	509c                	lw	a5,32(s1)
    800023e4:	fd4799e3          	bne	a5,s4,800023b6 <wakeup+0x2c>
    800023e8:	749c                	ld	a5,40(s1)
    800023ea:	fd5796e3          	bne	a5,s5,800023b6 <wakeup+0x2c>
        p->state = RUNNABLE;
    800023ee:	0364a023          	sw	s6,32(s1)
    800023f2:	b7d1                	j	800023b6 <wakeup+0x2c>
    }
  }
}
    800023f4:	70e2                	ld	ra,56(sp)
    800023f6:	7442                	ld	s0,48(sp)
    800023f8:	74a2                	ld	s1,40(sp)
    800023fa:	7902                	ld	s2,32(sp)
    800023fc:	69e2                	ld	s3,24(sp)
    800023fe:	6a42                	ld	s4,16(sp)
    80002400:	6aa2                	ld	s5,8(sp)
    80002402:	6b02                	ld	s6,0(sp)
    80002404:	6121                	addi	sp,sp,64
    80002406:	8082                	ret

0000000080002408 <reparent>:
{
    80002408:	7179                	addi	sp,sp,-48
    8000240a:	f406                	sd	ra,40(sp)
    8000240c:	f022                	sd	s0,32(sp)
    8000240e:	ec26                	sd	s1,24(sp)
    80002410:	e84a                	sd	s2,16(sp)
    80002412:	e44e                	sd	s3,8(sp)
    80002414:	e052                	sd	s4,0(sp)
    80002416:	1800                	addi	s0,sp,48
    80002418:	892a                	mv	s2,a0
  for (pp = proc; pp < &proc[NPROC]; pp++)
    8000241a:	0022f497          	auipc	s1,0x22f
    8000241e:	b9648493          	addi	s1,s1,-1130 # 80230fb0 <proc>
      pp->parent = initproc;
    80002422:	00006a17          	auipc	s4,0x6
    80002426:	4e6a0a13          	addi	s4,s4,1254 # 80008908 <initproc>
  for (pp = proc; pp < &proc[NPROC]; pp++)
    8000242a:	00235997          	auipc	s3,0x235
    8000242e:	b8698993          	addi	s3,s3,-1146 # 80236fb0 <tickslock>
    80002432:	a029                	j	8000243c <reparent+0x34>
    80002434:	18048493          	addi	s1,s1,384
    80002438:	01348d63          	beq	s1,s3,80002452 <reparent+0x4a>
    if (pp->parent == p)
    8000243c:	60bc                	ld	a5,64(s1)
    8000243e:	ff279be3          	bne	a5,s2,80002434 <reparent+0x2c>
      pp->parent = initproc;
    80002442:	000a3503          	ld	a0,0(s4)
    80002446:	e0a8                	sd	a0,64(s1)
      wakeup(initproc);
    80002448:	00000097          	auipc	ra,0x0
    8000244c:	f42080e7          	jalr	-190(ra) # 8000238a <wakeup>
    80002450:	b7d5                	j	80002434 <reparent+0x2c>
}
    80002452:	70a2                	ld	ra,40(sp)
    80002454:	7402                	ld	s0,32(sp)
    80002456:	64e2                	ld	s1,24(sp)
    80002458:	6942                	ld	s2,16(sp)
    8000245a:	69a2                	ld	s3,8(sp)
    8000245c:	6a02                	ld	s4,0(sp)
    8000245e:	6145                	addi	sp,sp,48
    80002460:	8082                	ret

0000000080002462 <exit>:
{
    80002462:	7179                	addi	sp,sp,-48
    80002464:	f406                	sd	ra,40(sp)
    80002466:	f022                	sd	s0,32(sp)
    80002468:	ec26                	sd	s1,24(sp)
    8000246a:	e84a                	sd	s2,16(sp)
    8000246c:	e44e                	sd	s3,8(sp)
    8000246e:	e052                	sd	s4,0(sp)
    80002470:	1800                	addi	s0,sp,48
    80002472:	8a2a                	mv	s4,a0
  struct proc *p = myproc();
    80002474:	fffff097          	auipc	ra,0xfffff
    80002478:	7c2080e7          	jalr	1986(ra) # 80001c36 <myproc>
    8000247c:	89aa                	mv	s3,a0
  if (p == initproc)
    8000247e:	00006797          	auipc	a5,0x6
    80002482:	48a7b783          	ld	a5,1162(a5) # 80008908 <initproc>
    80002486:	0d850493          	addi	s1,a0,216
    8000248a:	15850913          	addi	s2,a0,344
    8000248e:	02a79363          	bne	a5,a0,800024b4 <exit+0x52>
    panic("init exiting");
    80002492:	00006517          	auipc	a0,0x6
    80002496:	de650513          	addi	a0,a0,-538 # 80008278 <etext+0x278>
    8000249a:	ffffe097          	auipc	ra,0xffffe
    8000249e:	0c6080e7          	jalr	198(ra) # 80000560 <panic>
      fileclose(f);
    800024a2:	00002097          	auipc	ra,0x2
    800024a6:	636080e7          	jalr	1590(ra) # 80004ad8 <fileclose>
      p->ofile[fd] = 0;
    800024aa:	0004b023          	sd	zero,0(s1)
  for (int fd = 0; fd < NOFILE; fd++)
    800024ae:	04a1                	addi	s1,s1,8
    800024b0:	01248563          	beq	s1,s2,800024ba <exit+0x58>
    if (p->ofile[fd])
    800024b4:	6088                	ld	a0,0(s1)
    800024b6:	f575                	bnez	a0,800024a2 <exit+0x40>
    800024b8:	bfdd                	j	800024ae <exit+0x4c>
  begin_op();
    800024ba:	00002097          	auipc	ra,0x2
    800024be:	154080e7          	jalr	340(ra) # 8000460e <begin_op>
  iput(p->cwd);
    800024c2:	1589b503          	ld	a0,344(s3)
    800024c6:	00002097          	auipc	ra,0x2
    800024ca:	938080e7          	jalr	-1736(ra) # 80003dfe <iput>
  end_op();
    800024ce:	00002097          	auipc	ra,0x2
    800024d2:	1ba080e7          	jalr	442(ra) # 80004688 <end_op>
  p->cwd = 0;
    800024d6:	1409bc23          	sd	zero,344(s3)
  acquire(&wait_lock);
    800024da:	0022e497          	auipc	s1,0x22e
    800024de:	6be48493          	addi	s1,s1,1726 # 80230b98 <wait_lock>
    800024e2:	8526                	mv	a0,s1
    800024e4:	fffff097          	auipc	ra,0xfffff
    800024e8:	88a080e7          	jalr	-1910(ra) # 80000d6e <acquire>
  reparent(p);
    800024ec:	854e                	mv	a0,s3
    800024ee:	00000097          	auipc	ra,0x0
    800024f2:	f1a080e7          	jalr	-230(ra) # 80002408 <reparent>
  wakeup(p->parent);
    800024f6:	0409b503          	ld	a0,64(s3)
    800024fa:	00000097          	auipc	ra,0x0
    800024fe:	e90080e7          	jalr	-368(ra) # 8000238a <wakeup>
  acquire(&p->lock);
    80002502:	00898513          	addi	a0,s3,8
    80002506:	fffff097          	auipc	ra,0xfffff
    8000250a:	868080e7          	jalr	-1944(ra) # 80000d6e <acquire>
  p->xstate = status;
    8000250e:	0349aa23          	sw	s4,52(s3)
  p->state = ZOMBIE;
    80002512:	4795                	li	a5,5
    80002514:	02f9a023          	sw	a5,32(s3)
  p->etime = ticks;
    80002518:	00006797          	auipc	a5,0x6
    8000251c:	4007a783          	lw	a5,1024(a5) # 80008918 <ticks>
    80002520:	16f9ac23          	sw	a5,376(s3)
  release(&wait_lock);
    80002524:	8526                	mv	a0,s1
    80002526:	fffff097          	auipc	ra,0xfffff
    8000252a:	8fc080e7          	jalr	-1796(ra) # 80000e22 <release>
  sched();
    8000252e:	00000097          	auipc	ra,0x0
    80002532:	cd0080e7          	jalr	-816(ra) # 800021fe <sched>
  panic("zombie exit");
    80002536:	00006517          	auipc	a0,0x6
    8000253a:	d5250513          	addi	a0,a0,-686 # 80008288 <etext+0x288>
    8000253e:	ffffe097          	auipc	ra,0xffffe
    80002542:	022080e7          	jalr	34(ra) # 80000560 <panic>

0000000080002546 <kill>:

// Kill the process with the given pid.
// The victim won't exit until it tries to return
// to user space (see usertrap() in trap.c).
int kill(int pid)
{
    80002546:	7179                	addi	sp,sp,-48
    80002548:	f406                	sd	ra,40(sp)
    8000254a:	f022                	sd	s0,32(sp)
    8000254c:	ec26                	sd	s1,24(sp)
    8000254e:	e84a                	sd	s2,16(sp)
    80002550:	e44e                	sd	s3,8(sp)
    80002552:	e052                	sd	s4,0(sp)
    80002554:	1800                	addi	s0,sp,48
    80002556:	89aa                	mv	s3,a0
  struct proc *p;

  for (p = proc; p < &proc[NPROC]; p++)
    80002558:	0022f497          	auipc	s1,0x22f
    8000255c:	a5848493          	addi	s1,s1,-1448 # 80230fb0 <proc>
    80002560:	00235a17          	auipc	s4,0x235
    80002564:	a50a0a13          	addi	s4,s4,-1456 # 80236fb0 <tickslock>
  {
    acquire(&p->lock);
    80002568:	00848913          	addi	s2,s1,8
    8000256c:	854a                	mv	a0,s2
    8000256e:	fffff097          	auipc	ra,0xfffff
    80002572:	800080e7          	jalr	-2048(ra) # 80000d6e <acquire>
    if (p->pid == pid)
    80002576:	5c9c                	lw	a5,56(s1)
    80002578:	01378d63          	beq	a5,s3,80002592 <kill+0x4c>
        p->state = RUNNABLE;
      }
      release(&p->lock);
      return 0;
    }
    release(&p->lock);
    8000257c:	854a                	mv	a0,s2
    8000257e:	fffff097          	auipc	ra,0xfffff
    80002582:	8a4080e7          	jalr	-1884(ra) # 80000e22 <release>
  for (p = proc; p < &proc[NPROC]; p++)
    80002586:	18048493          	addi	s1,s1,384
    8000258a:	fd449fe3          	bne	s1,s4,80002568 <kill+0x22>
  }
  return -1;
    8000258e:	557d                	li	a0,-1
    80002590:	a829                	j	800025aa <kill+0x64>
      p->killed = 1;
    80002592:	4785                	li	a5,1
    80002594:	d89c                	sw	a5,48(s1)
      if (p->state == SLEEPING)
    80002596:	5098                	lw	a4,32(s1)
    80002598:	4789                	li	a5,2
    8000259a:	02f70063          	beq	a4,a5,800025ba <kill+0x74>
      release(&p->lock);
    8000259e:	854a                	mv	a0,s2
    800025a0:	fffff097          	auipc	ra,0xfffff
    800025a4:	882080e7          	jalr	-1918(ra) # 80000e22 <release>
      return 0;
    800025a8:	4501                	li	a0,0
}
    800025aa:	70a2                	ld	ra,40(sp)
    800025ac:	7402                	ld	s0,32(sp)
    800025ae:	64e2                	ld	s1,24(sp)
    800025b0:	6942                	ld	s2,16(sp)
    800025b2:	69a2                	ld	s3,8(sp)
    800025b4:	6a02                	ld	s4,0(sp)
    800025b6:	6145                	addi	sp,sp,48
    800025b8:	8082                	ret
        p->state = RUNNABLE;
    800025ba:	478d                	li	a5,3
    800025bc:	d09c                	sw	a5,32(s1)
    800025be:	b7c5                	j	8000259e <kill+0x58>

00000000800025c0 <setkilled>:

void setkilled(struct proc *p)
{
    800025c0:	1101                	addi	sp,sp,-32
    800025c2:	ec06                	sd	ra,24(sp)
    800025c4:	e822                	sd	s0,16(sp)
    800025c6:	e426                	sd	s1,8(sp)
    800025c8:	e04a                	sd	s2,0(sp)
    800025ca:	1000                	addi	s0,sp,32
    800025cc:	84aa                	mv	s1,a0
  acquire(&p->lock);
    800025ce:	00850913          	addi	s2,a0,8
    800025d2:	854a                	mv	a0,s2
    800025d4:	ffffe097          	auipc	ra,0xffffe
    800025d8:	79a080e7          	jalr	1946(ra) # 80000d6e <acquire>
  p->killed = 1;
    800025dc:	4785                	li	a5,1
    800025de:	d89c                	sw	a5,48(s1)
  release(&p->lock);
    800025e0:	854a                	mv	a0,s2
    800025e2:	fffff097          	auipc	ra,0xfffff
    800025e6:	840080e7          	jalr	-1984(ra) # 80000e22 <release>
}
    800025ea:	60e2                	ld	ra,24(sp)
    800025ec:	6442                	ld	s0,16(sp)
    800025ee:	64a2                	ld	s1,8(sp)
    800025f0:	6902                	ld	s2,0(sp)
    800025f2:	6105                	addi	sp,sp,32
    800025f4:	8082                	ret

00000000800025f6 <killed>:

int killed(struct proc *p)
{
    800025f6:	1101                	addi	sp,sp,-32
    800025f8:	ec06                	sd	ra,24(sp)
    800025fa:	e822                	sd	s0,16(sp)
    800025fc:	e426                	sd	s1,8(sp)
    800025fe:	e04a                	sd	s2,0(sp)
    80002600:	1000                	addi	s0,sp,32
    80002602:	84aa                	mv	s1,a0
  int k;

  acquire(&p->lock);
    80002604:	00850913          	addi	s2,a0,8
    80002608:	854a                	mv	a0,s2
    8000260a:	ffffe097          	auipc	ra,0xffffe
    8000260e:	764080e7          	jalr	1892(ra) # 80000d6e <acquire>
  k = p->killed;
    80002612:	5884                	lw	s1,48(s1)
  release(&p->lock);
    80002614:	854a                	mv	a0,s2
    80002616:	fffff097          	auipc	ra,0xfffff
    8000261a:	80c080e7          	jalr	-2036(ra) # 80000e22 <release>
  return k;
}
    8000261e:	8526                	mv	a0,s1
    80002620:	60e2                	ld	ra,24(sp)
    80002622:	6442                	ld	s0,16(sp)
    80002624:	64a2                	ld	s1,8(sp)
    80002626:	6902                	ld	s2,0(sp)
    80002628:	6105                	addi	sp,sp,32
    8000262a:	8082                	ret

000000008000262c <wait>:
{
    8000262c:	711d                	addi	sp,sp,-96
    8000262e:	ec86                	sd	ra,88(sp)
    80002630:	e8a2                	sd	s0,80(sp)
    80002632:	e4a6                	sd	s1,72(sp)
    80002634:	e0ca                	sd	s2,64(sp)
    80002636:	fc4e                	sd	s3,56(sp)
    80002638:	f852                	sd	s4,48(sp)
    8000263a:	f456                	sd	s5,40(sp)
    8000263c:	f05a                	sd	s6,32(sp)
    8000263e:	ec5e                	sd	s7,24(sp)
    80002640:	e862                	sd	s8,16(sp)
    80002642:	e466                	sd	s9,8(sp)
    80002644:	1080                	addi	s0,sp,96
    80002646:	8baa                	mv	s7,a0
  struct proc *p = myproc();
    80002648:	fffff097          	auipc	ra,0xfffff
    8000264c:	5ee080e7          	jalr	1518(ra) # 80001c36 <myproc>
    80002650:	892a                	mv	s2,a0
  acquire(&wait_lock);
    80002652:	0022e517          	auipc	a0,0x22e
    80002656:	54650513          	addi	a0,a0,1350 # 80230b98 <wait_lock>
    8000265a:	ffffe097          	auipc	ra,0xffffe
    8000265e:	714080e7          	jalr	1812(ra) # 80000d6e <acquire>
    havekids = 0;
    80002662:	4c01                	li	s8,0
        if (pp->state == ZOMBIE)
    80002664:	4a95                	li	s5,5
        havekids = 1;
    80002666:	4b05                	li	s6,1
    for (pp = proc; pp < &proc[NPROC]; pp++)
    80002668:	00235997          	auipc	s3,0x235
    8000266c:	94898993          	addi	s3,s3,-1720 # 80236fb0 <tickslock>
    sleep(p, &wait_lock); // DOC: wait-sleep
    80002670:	0022ec97          	auipc	s9,0x22e
    80002674:	528c8c93          	addi	s9,s9,1320 # 80230b98 <wait_lock>
    80002678:	a0e9                	j	80002742 <wait+0x116>
          pid = pp->pid;
    8000267a:	0384a983          	lw	s3,56(s1)
          if (addr != 0 && copyout(p->pagetable, addr, (char *)&pp->xstate,
    8000267e:	000b8e63          	beqz	s7,8000269a <wait+0x6e>
    80002682:	4691                	li	a3,4
    80002684:	03448613          	addi	a2,s1,52
    80002688:	85de                	mv	a1,s7
    8000268a:	05893503          	ld	a0,88(s2)
    8000268e:	fffff097          	auipc	ra,0xfffff
    80002692:	1f8080e7          	jalr	504(ra) # 80001886 <copyout>
    80002696:	04054263          	bltz	a0,800026da <wait+0xae>
          freeproc(pp);
    8000269a:	8526                	mv	a0,s1
    8000269c:	fffff097          	auipc	ra,0xfffff
    800026a0:	74e080e7          	jalr	1870(ra) # 80001dea <freeproc>
          release(&pp->lock);
    800026a4:	8552                	mv	a0,s4
    800026a6:	ffffe097          	auipc	ra,0xffffe
    800026aa:	77c080e7          	jalr	1916(ra) # 80000e22 <release>
          release(&wait_lock);
    800026ae:	0022e517          	auipc	a0,0x22e
    800026b2:	4ea50513          	addi	a0,a0,1258 # 80230b98 <wait_lock>
    800026b6:	ffffe097          	auipc	ra,0xffffe
    800026ba:	76c080e7          	jalr	1900(ra) # 80000e22 <release>
}
    800026be:	854e                	mv	a0,s3
    800026c0:	60e6                	ld	ra,88(sp)
    800026c2:	6446                	ld	s0,80(sp)
    800026c4:	64a6                	ld	s1,72(sp)
    800026c6:	6906                	ld	s2,64(sp)
    800026c8:	79e2                	ld	s3,56(sp)
    800026ca:	7a42                	ld	s4,48(sp)
    800026cc:	7aa2                	ld	s5,40(sp)
    800026ce:	7b02                	ld	s6,32(sp)
    800026d0:	6be2                	ld	s7,24(sp)
    800026d2:	6c42                	ld	s8,16(sp)
    800026d4:	6ca2                	ld	s9,8(sp)
    800026d6:	6125                	addi	sp,sp,96
    800026d8:	8082                	ret
            release(&pp->lock);
    800026da:	8552                	mv	a0,s4
    800026dc:	ffffe097          	auipc	ra,0xffffe
    800026e0:	746080e7          	jalr	1862(ra) # 80000e22 <release>
            release(&wait_lock);
    800026e4:	0022e517          	auipc	a0,0x22e
    800026e8:	4b450513          	addi	a0,a0,1204 # 80230b98 <wait_lock>
    800026ec:	ffffe097          	auipc	ra,0xffffe
    800026f0:	736080e7          	jalr	1846(ra) # 80000e22 <release>
            return -1;
    800026f4:	59fd                	li	s3,-1
    800026f6:	b7e1                	j	800026be <wait+0x92>
    for (pp = proc; pp < &proc[NPROC]; pp++)
    800026f8:	18048493          	addi	s1,s1,384
    800026fc:	03348663          	beq	s1,s3,80002728 <wait+0xfc>
      if (pp->parent == p)
    80002700:	60bc                	ld	a5,64(s1)
    80002702:	ff279be3          	bne	a5,s2,800026f8 <wait+0xcc>
        acquire(&pp->lock);
    80002706:	00848a13          	addi	s4,s1,8
    8000270a:	8552                	mv	a0,s4
    8000270c:	ffffe097          	auipc	ra,0xffffe
    80002710:	662080e7          	jalr	1634(ra) # 80000d6e <acquire>
        if (pp->state == ZOMBIE)
    80002714:	509c                	lw	a5,32(s1)
    80002716:	f75782e3          	beq	a5,s5,8000267a <wait+0x4e>
        release(&pp->lock);
    8000271a:	8552                	mv	a0,s4
    8000271c:	ffffe097          	auipc	ra,0xffffe
    80002720:	706080e7          	jalr	1798(ra) # 80000e22 <release>
        havekids = 1;
    80002724:	875a                	mv	a4,s6
    80002726:	bfc9                	j	800026f8 <wait+0xcc>
    if (!havekids || killed(p))
    80002728:	c31d                	beqz	a4,8000274e <wait+0x122>
    8000272a:	854a                	mv	a0,s2
    8000272c:	00000097          	auipc	ra,0x0
    80002730:	eca080e7          	jalr	-310(ra) # 800025f6 <killed>
    80002734:	ed09                	bnez	a0,8000274e <wait+0x122>
    sleep(p, &wait_lock); // DOC: wait-sleep
    80002736:	85e6                	mv	a1,s9
    80002738:	854a                	mv	a0,s2
    8000273a:	00000097          	auipc	ra,0x0
    8000273e:	be2080e7          	jalr	-1054(ra) # 8000231c <sleep>
    havekids = 0;
    80002742:	8762                	mv	a4,s8
    for (pp = proc; pp < &proc[NPROC]; pp++)
    80002744:	0022f497          	auipc	s1,0x22f
    80002748:	86c48493          	addi	s1,s1,-1940 # 80230fb0 <proc>
    8000274c:	bf55                	j	80002700 <wait+0xd4>
      release(&wait_lock);
    8000274e:	0022e517          	auipc	a0,0x22e
    80002752:	44a50513          	addi	a0,a0,1098 # 80230b98 <wait_lock>
    80002756:	ffffe097          	auipc	ra,0xffffe
    8000275a:	6cc080e7          	jalr	1740(ra) # 80000e22 <release>
      return -1;
    8000275e:	59fd                	li	s3,-1
    80002760:	bfb9                	j	800026be <wait+0x92>

0000000080002762 <either_copyout>:

// Copy to either a user address, or kernel address,
// depending on usr_dst.
// Returns 0 on success, -1 on error.
int either_copyout(int user_dst, uint64 dst, void *src, uint64 len)
{
    80002762:	7179                	addi	sp,sp,-48
    80002764:	f406                	sd	ra,40(sp)
    80002766:	f022                	sd	s0,32(sp)
    80002768:	ec26                	sd	s1,24(sp)
    8000276a:	e84a                	sd	s2,16(sp)
    8000276c:	e44e                	sd	s3,8(sp)
    8000276e:	e052                	sd	s4,0(sp)
    80002770:	1800                	addi	s0,sp,48
    80002772:	84aa                	mv	s1,a0
    80002774:	892e                	mv	s2,a1
    80002776:	89b2                	mv	s3,a2
    80002778:	8a36                	mv	s4,a3
  struct proc *p = myproc();
    8000277a:	fffff097          	auipc	ra,0xfffff
    8000277e:	4bc080e7          	jalr	1212(ra) # 80001c36 <myproc>
  if (user_dst)
    80002782:	c08d                	beqz	s1,800027a4 <either_copyout+0x42>
  {
    return copyout(p->pagetable, dst, src, len);
    80002784:	86d2                	mv	a3,s4
    80002786:	864e                	mv	a2,s3
    80002788:	85ca                	mv	a1,s2
    8000278a:	6d28                	ld	a0,88(a0)
    8000278c:	fffff097          	auipc	ra,0xfffff
    80002790:	0fa080e7          	jalr	250(ra) # 80001886 <copyout>
  else
  {
    memmove((char *)dst, src, len);
    return 0;
  }
}
    80002794:	70a2                	ld	ra,40(sp)
    80002796:	7402                	ld	s0,32(sp)
    80002798:	64e2                	ld	s1,24(sp)
    8000279a:	6942                	ld	s2,16(sp)
    8000279c:	69a2                	ld	s3,8(sp)
    8000279e:	6a02                	ld	s4,0(sp)
    800027a0:	6145                	addi	sp,sp,48
    800027a2:	8082                	ret
    memmove((char *)dst, src, len);
    800027a4:	000a061b          	sext.w	a2,s4
    800027a8:	85ce                	mv	a1,s3
    800027aa:	854a                	mv	a0,s2
    800027ac:	ffffe097          	auipc	ra,0xffffe
    800027b0:	71a080e7          	jalr	1818(ra) # 80000ec6 <memmove>
    return 0;
    800027b4:	8526                	mv	a0,s1
    800027b6:	bff9                	j	80002794 <either_copyout+0x32>

00000000800027b8 <either_copyin>:

// Copy from either a user address, or kernel address,
// depending on usr_src.
// Returns 0 on success, -1 on error.
int either_copyin(void *dst, int user_src, uint64 src, uint64 len)
{
    800027b8:	7179                	addi	sp,sp,-48
    800027ba:	f406                	sd	ra,40(sp)
    800027bc:	f022                	sd	s0,32(sp)
    800027be:	ec26                	sd	s1,24(sp)
    800027c0:	e84a                	sd	s2,16(sp)
    800027c2:	e44e                	sd	s3,8(sp)
    800027c4:	e052                	sd	s4,0(sp)
    800027c6:	1800                	addi	s0,sp,48
    800027c8:	892a                	mv	s2,a0
    800027ca:	84ae                	mv	s1,a1
    800027cc:	89b2                	mv	s3,a2
    800027ce:	8a36                	mv	s4,a3
  struct proc *p = myproc();
    800027d0:	fffff097          	auipc	ra,0xfffff
    800027d4:	466080e7          	jalr	1126(ra) # 80001c36 <myproc>
  if (user_src)
    800027d8:	c08d                	beqz	s1,800027fa <either_copyin+0x42>
  {
    return copyin(p->pagetable, dst, src, len);
    800027da:	86d2                	mv	a3,s4
    800027dc:	864e                	mv	a2,s3
    800027de:	85ca                	mv	a1,s2
    800027e0:	6d28                	ld	a0,88(a0)
    800027e2:	fffff097          	auipc	ra,0xfffff
    800027e6:	176080e7          	jalr	374(ra) # 80001958 <copyin>
  else
  {
    memmove(dst, (char *)src, len);
    return 0;
  }
}
    800027ea:	70a2                	ld	ra,40(sp)
    800027ec:	7402                	ld	s0,32(sp)
    800027ee:	64e2                	ld	s1,24(sp)
    800027f0:	6942                	ld	s2,16(sp)
    800027f2:	69a2                	ld	s3,8(sp)
    800027f4:	6a02                	ld	s4,0(sp)
    800027f6:	6145                	addi	sp,sp,48
    800027f8:	8082                	ret
    memmove(dst, (char *)src, len);
    800027fa:	000a061b          	sext.w	a2,s4
    800027fe:	85ce                	mv	a1,s3
    80002800:	854a                	mv	a0,s2
    80002802:	ffffe097          	auipc	ra,0xffffe
    80002806:	6c4080e7          	jalr	1732(ra) # 80000ec6 <memmove>
    return 0;
    8000280a:	8526                	mv	a0,s1
    8000280c:	bff9                	j	800027ea <either_copyin+0x32>

000000008000280e <procdump>:

// Print a process listing to console.  For debugging.
// Runs when user types ^P on console.
// No lock to avoid wedging a stuck machine further.
void procdump(void)
{
    8000280e:	715d                	addi	sp,sp,-80
    80002810:	e486                	sd	ra,72(sp)
    80002812:	e0a2                	sd	s0,64(sp)
    80002814:	fc26                	sd	s1,56(sp)
    80002816:	f84a                	sd	s2,48(sp)
    80002818:	f44e                	sd	s3,40(sp)
    8000281a:	f052                	sd	s4,32(sp)
    8000281c:	ec56                	sd	s5,24(sp)
    8000281e:	e85a                	sd	s6,16(sp)
    80002820:	e45e                	sd	s7,8(sp)
    80002822:	0880                	addi	s0,sp,80
      [RUNNING] "run   ",
      [ZOMBIE] "zombie"};
  struct proc *p;
  char *state;

  printf("\n");
    80002824:	00005517          	auipc	a0,0x5
    80002828:	7ec50513          	addi	a0,a0,2028 # 80008010 <etext+0x10>
    8000282c:	ffffe097          	auipc	ra,0xffffe
    80002830:	d7e080e7          	jalr	-642(ra) # 800005aa <printf>
  for (p = proc; p < &proc[NPROC]; p++)
    80002834:	0022f497          	auipc	s1,0x22f
    80002838:	8dc48493          	addi	s1,s1,-1828 # 80231110 <proc+0x160>
    8000283c:	00235917          	auipc	s2,0x235
    80002840:	8d490913          	addi	s2,s2,-1836 # 80237110 <bcache+0x148>
  {
    if (p->state == UNUSED)
      continue;
    if (p->state >= 0 && p->state < NELEM(states) && states[p->state])
    80002844:	4b15                	li	s6,5
      state = states[p->state];
    else
      state = "???";
    80002846:	00006997          	auipc	s3,0x6
    8000284a:	a5298993          	addi	s3,s3,-1454 # 80008298 <etext+0x298>
    printf("%d %s %s", p->pid, state, p->name);
    8000284e:	00006a97          	auipc	s5,0x6
    80002852:	a52a8a93          	addi	s5,s5,-1454 # 800082a0 <etext+0x2a0>
    printf("\n");
    80002856:	00005a17          	auipc	s4,0x5
    8000285a:	7baa0a13          	addi	s4,s4,1978 # 80008010 <etext+0x10>
    if (p->state >= 0 && p->state < NELEM(states) && states[p->state])
    8000285e:	00006b97          	auipc	s7,0x6
    80002862:	f1ab8b93          	addi	s7,s7,-230 # 80008778 <states.0>
    80002866:	a00d                	j	80002888 <procdump+0x7a>
    printf("%d %s %s", p->pid, state, p->name);
    80002868:	ed86a583          	lw	a1,-296(a3)
    8000286c:	8556                	mv	a0,s5
    8000286e:	ffffe097          	auipc	ra,0xffffe
    80002872:	d3c080e7          	jalr	-708(ra) # 800005aa <printf>
    printf("\n");
    80002876:	8552                	mv	a0,s4
    80002878:	ffffe097          	auipc	ra,0xffffe
    8000287c:	d32080e7          	jalr	-718(ra) # 800005aa <printf>
  for (p = proc; p < &proc[NPROC]; p++)
    80002880:	18048493          	addi	s1,s1,384
    80002884:	03248263          	beq	s1,s2,800028a8 <procdump+0x9a>
    if (p->state == UNUSED)
    80002888:	86a6                	mv	a3,s1
    8000288a:	ec04a783          	lw	a5,-320(s1)
    8000288e:	dbed                	beqz	a5,80002880 <procdump+0x72>
      state = "???";
    80002890:	864e                	mv	a2,s3
    if (p->state >= 0 && p->state < NELEM(states) && states[p->state])
    80002892:	fcfb6be3          	bltu	s6,a5,80002868 <procdump+0x5a>
    80002896:	02079713          	slli	a4,a5,0x20
    8000289a:	01d75793          	srli	a5,a4,0x1d
    8000289e:	97de                	add	a5,a5,s7
    800028a0:	6390                	ld	a2,0(a5)
    800028a2:	f279                	bnez	a2,80002868 <procdump+0x5a>
      state = "???";
    800028a4:	864e                	mv	a2,s3
    800028a6:	b7c9                	j	80002868 <procdump+0x5a>
  }
}
    800028a8:	60a6                	ld	ra,72(sp)
    800028aa:	6406                	ld	s0,64(sp)
    800028ac:	74e2                	ld	s1,56(sp)
    800028ae:	7942                	ld	s2,48(sp)
    800028b0:	79a2                	ld	s3,40(sp)
    800028b2:	7a02                	ld	s4,32(sp)
    800028b4:	6ae2                	ld	s5,24(sp)
    800028b6:	6b42                	ld	s6,16(sp)
    800028b8:	6ba2                	ld	s7,8(sp)
    800028ba:	6161                	addi	sp,sp,80
    800028bc:	8082                	ret

00000000800028be <waitx>:

// waitx
int waitx(uint64 addr, uint *wtime, uint *rtime)
{
    800028be:	7159                	addi	sp,sp,-112
    800028c0:	f486                	sd	ra,104(sp)
    800028c2:	f0a2                	sd	s0,96(sp)
    800028c4:	eca6                	sd	s1,88(sp)
    800028c6:	e8ca                	sd	s2,80(sp)
    800028c8:	e4ce                	sd	s3,72(sp)
    800028ca:	e0d2                	sd	s4,64(sp)
    800028cc:	fc56                	sd	s5,56(sp)
    800028ce:	f85a                	sd	s6,48(sp)
    800028d0:	f45e                	sd	s7,40(sp)
    800028d2:	f062                	sd	s8,32(sp)
    800028d4:	ec66                	sd	s9,24(sp)
    800028d6:	e86a                	sd	s10,16(sp)
    800028d8:	e46e                	sd	s11,8(sp)
    800028da:	1880                	addi	s0,sp,112
    800028dc:	8b2a                	mv	s6,a0
    800028de:	8bae                	mv	s7,a1
    800028e0:	8c32                	mv	s8,a2
  struct proc *np;
  int havekids, pid;
  struct proc *p = myproc();
    800028e2:	fffff097          	auipc	ra,0xfffff
    800028e6:	354080e7          	jalr	852(ra) # 80001c36 <myproc>
    800028ea:	892a                	mv	s2,a0

  acquire(&wait_lock);
    800028ec:	0022e517          	auipc	a0,0x22e
    800028f0:	2ac50513          	addi	a0,a0,684 # 80230b98 <wait_lock>
    800028f4:	ffffe097          	auipc	ra,0xffffe
    800028f8:	47a080e7          	jalr	1146(ra) # 80000d6e <acquire>

  for (;;)
  {
    // Scan through table looking for exited children.
    havekids = 0;
    800028fc:	4c81                	li	s9,0
      {
        // make sure the child isn't still in exit() or swtch().
        acquire(&np->lock);

        havekids = 1;
        if (np->state == ZOMBIE)
    800028fe:	4a15                	li	s4,5
        havekids = 1;
    80002900:	4a85                	li	s5,1
    for (np = proc; np < &proc[NPROC]; np++)
    80002902:	00234997          	auipc	s3,0x234
    80002906:	6ae98993          	addi	s3,s3,1710 # 80236fb0 <tickslock>
      release(&wait_lock);
      return -1;
    }

    // Wait for a child to exit.
    sleep(p, &wait_lock); // DOC: wait-sleep
    8000290a:	0022ed17          	auipc	s10,0x22e
    8000290e:	28ed0d13          	addi	s10,s10,654 # 80230b98 <wait_lock>
    80002912:	a0c5                	j	800029f2 <waitx+0x134>
          pid = np->pid;
    80002914:	0384a983          	lw	s3,56(s1)
          *rtime = np->rtime;
    80002918:	1704a783          	lw	a5,368(s1)
    8000291c:	00fc2023          	sw	a5,0(s8) # 1000 <_entry-0x7ffff000>
          *wtime = np->etime - np->ctime - np->rtime;
    80002920:	1744a703          	lw	a4,372(s1)
    80002924:	9f3d                	addw	a4,a4,a5
    80002926:	1784a783          	lw	a5,376(s1)
    8000292a:	9f99                	subw	a5,a5,a4
    8000292c:	00fba023          	sw	a5,0(s7)
          if (addr != 0 && copyout(p->pagetable, addr, (char *)&np->xstate,
    80002930:	000b0e63          	beqz	s6,8000294c <waitx+0x8e>
    80002934:	4691                	li	a3,4
    80002936:	03448613          	addi	a2,s1,52
    8000293a:	85da                	mv	a1,s6
    8000293c:	05893503          	ld	a0,88(s2)
    80002940:	fffff097          	auipc	ra,0xfffff
    80002944:	f46080e7          	jalr	-186(ra) # 80001886 <copyout>
    80002948:	04054463          	bltz	a0,80002990 <waitx+0xd2>
          freeproc(np);
    8000294c:	8526                	mv	a0,s1
    8000294e:	fffff097          	auipc	ra,0xfffff
    80002952:	49c080e7          	jalr	1180(ra) # 80001dea <freeproc>
          release(&np->lock);
    80002956:	856e                	mv	a0,s11
    80002958:	ffffe097          	auipc	ra,0xffffe
    8000295c:	4ca080e7          	jalr	1226(ra) # 80000e22 <release>
          release(&wait_lock);
    80002960:	0022e517          	auipc	a0,0x22e
    80002964:	23850513          	addi	a0,a0,568 # 80230b98 <wait_lock>
    80002968:	ffffe097          	auipc	ra,0xffffe
    8000296c:	4ba080e7          	jalr	1210(ra) # 80000e22 <release>
  }
}
    80002970:	854e                	mv	a0,s3
    80002972:	70a6                	ld	ra,104(sp)
    80002974:	7406                	ld	s0,96(sp)
    80002976:	64e6                	ld	s1,88(sp)
    80002978:	6946                	ld	s2,80(sp)
    8000297a:	69a6                	ld	s3,72(sp)
    8000297c:	6a06                	ld	s4,64(sp)
    8000297e:	7ae2                	ld	s5,56(sp)
    80002980:	7b42                	ld	s6,48(sp)
    80002982:	7ba2                	ld	s7,40(sp)
    80002984:	7c02                	ld	s8,32(sp)
    80002986:	6ce2                	ld	s9,24(sp)
    80002988:	6d42                	ld	s10,16(sp)
    8000298a:	6da2                	ld	s11,8(sp)
    8000298c:	6165                	addi	sp,sp,112
    8000298e:	8082                	ret
            release(&np->lock);
    80002990:	856e                	mv	a0,s11
    80002992:	ffffe097          	auipc	ra,0xffffe
    80002996:	490080e7          	jalr	1168(ra) # 80000e22 <release>
            release(&wait_lock);
    8000299a:	0022e517          	auipc	a0,0x22e
    8000299e:	1fe50513          	addi	a0,a0,510 # 80230b98 <wait_lock>
    800029a2:	ffffe097          	auipc	ra,0xffffe
    800029a6:	480080e7          	jalr	1152(ra) # 80000e22 <release>
            return -1;
    800029aa:	59fd                	li	s3,-1
    800029ac:	b7d1                	j	80002970 <waitx+0xb2>
    for (np = proc; np < &proc[NPROC]; np++)
    800029ae:	18048493          	addi	s1,s1,384
    800029b2:	03348663          	beq	s1,s3,800029de <waitx+0x120>
      if (np->parent == p)
    800029b6:	60bc                	ld	a5,64(s1)
    800029b8:	ff279be3          	bne	a5,s2,800029ae <waitx+0xf0>
        acquire(&np->lock);
    800029bc:	00848d93          	addi	s11,s1,8
    800029c0:	856e                	mv	a0,s11
    800029c2:	ffffe097          	auipc	ra,0xffffe
    800029c6:	3ac080e7          	jalr	940(ra) # 80000d6e <acquire>
        if (np->state == ZOMBIE)
    800029ca:	509c                	lw	a5,32(s1)
    800029cc:	f54784e3          	beq	a5,s4,80002914 <waitx+0x56>
        release(&np->lock);
    800029d0:	856e                	mv	a0,s11
    800029d2:	ffffe097          	auipc	ra,0xffffe
    800029d6:	450080e7          	jalr	1104(ra) # 80000e22 <release>
        havekids = 1;
    800029da:	8756                	mv	a4,s5
    800029dc:	bfc9                	j	800029ae <waitx+0xf0>
    if (!havekids || p->killed)
    800029de:	c305                	beqz	a4,800029fe <waitx+0x140>
    800029e0:	03092783          	lw	a5,48(s2)
    800029e4:	ef89                	bnez	a5,800029fe <waitx+0x140>
    sleep(p, &wait_lock); // DOC: wait-sleep
    800029e6:	85ea                	mv	a1,s10
    800029e8:	854a                	mv	a0,s2
    800029ea:	00000097          	auipc	ra,0x0
    800029ee:	932080e7          	jalr	-1742(ra) # 8000231c <sleep>
    havekids = 0;
    800029f2:	8766                	mv	a4,s9
    for (np = proc; np < &proc[NPROC]; np++)
    800029f4:	0022e497          	auipc	s1,0x22e
    800029f8:	5bc48493          	addi	s1,s1,1468 # 80230fb0 <proc>
    800029fc:	bf6d                	j	800029b6 <waitx+0xf8>
      release(&wait_lock);
    800029fe:	0022e517          	auipc	a0,0x22e
    80002a02:	19a50513          	addi	a0,a0,410 # 80230b98 <wait_lock>
    80002a06:	ffffe097          	auipc	ra,0xffffe
    80002a0a:	41c080e7          	jalr	1052(ra) # 80000e22 <release>
      return -1;
    80002a0e:	59fd                	li	s3,-1
    80002a10:	b785                	j	80002970 <waitx+0xb2>

0000000080002a12 <update_time>:

void update_time()
{
    80002a12:	7179                	addi	sp,sp,-48
    80002a14:	f406                	sd	ra,40(sp)
    80002a16:	f022                	sd	s0,32(sp)
    80002a18:	ec26                	sd	s1,24(sp)
    80002a1a:	e84a                	sd	s2,16(sp)
    80002a1c:	e44e                	sd	s3,8(sp)
    80002a1e:	e052                	sd	s4,0(sp)
    80002a20:	1800                	addi	s0,sp,48
  struct proc *p;
  for (p = proc; p < &proc[NPROC]; p++)
    80002a22:	0022e497          	auipc	s1,0x22e
    80002a26:	59648493          	addi	s1,s1,1430 # 80230fb8 <proc+0x8>
    80002a2a:	00234a17          	auipc	s4,0x234
    80002a2e:	58ea0a13          	addi	s4,s4,1422 # 80236fb8 <tickslock+0x8>
  {
    acquire(&p->lock);
    if (p->state == RUNNING)
    80002a32:	4991                	li	s3,4
    80002a34:	a811                	j	80002a48 <update_time+0x36>
    {
      p->rtime++;
    }
    release(&p->lock);
    80002a36:	854a                	mv	a0,s2
    80002a38:	ffffe097          	auipc	ra,0xffffe
    80002a3c:	3ea080e7          	jalr	1002(ra) # 80000e22 <release>
  for (p = proc; p < &proc[NPROC]; p++)
    80002a40:	18048493          	addi	s1,s1,384
    80002a44:	03448163          	beq	s1,s4,80002a66 <update_time+0x54>
    acquire(&p->lock);
    80002a48:	8926                	mv	s2,s1
    80002a4a:	8526                	mv	a0,s1
    80002a4c:	ffffe097          	auipc	ra,0xffffe
    80002a50:	322080e7          	jalr	802(ra) # 80000d6e <acquire>
    if (p->state == RUNNING)
    80002a54:	4c9c                	lw	a5,24(s1)
    80002a56:	ff3790e3          	bne	a5,s3,80002a36 <update_time+0x24>
      p->rtime++;
    80002a5a:	1684a783          	lw	a5,360(s1)
    80002a5e:	2785                	addiw	a5,a5,1
    80002a60:	16f4a423          	sw	a5,360(s1)
    80002a64:	bfc9                	j	80002a36 <update_time+0x24>
  }
    80002a66:	70a2                	ld	ra,40(sp)
    80002a68:	7402                	ld	s0,32(sp)
    80002a6a:	64e2                	ld	s1,24(sp)
    80002a6c:	6942                	ld	s2,16(sp)
    80002a6e:	69a2                	ld	s3,8(sp)
    80002a70:	6a02                	ld	s4,0(sp)
    80002a72:	6145                	addi	sp,sp,48
    80002a74:	8082                	ret

0000000080002a76 <swtch>:
    80002a76:	00153023          	sd	ra,0(a0)
    80002a7a:	00253423          	sd	sp,8(a0)
    80002a7e:	e900                	sd	s0,16(a0)
    80002a80:	ed04                	sd	s1,24(a0)
    80002a82:	03253023          	sd	s2,32(a0)
    80002a86:	03353423          	sd	s3,40(a0)
    80002a8a:	03453823          	sd	s4,48(a0)
    80002a8e:	03553c23          	sd	s5,56(a0)
    80002a92:	05653023          	sd	s6,64(a0)
    80002a96:	05753423          	sd	s7,72(a0)
    80002a9a:	05853823          	sd	s8,80(a0)
    80002a9e:	05953c23          	sd	s9,88(a0)
    80002aa2:	07a53023          	sd	s10,96(a0)
    80002aa6:	07b53423          	sd	s11,104(a0)
    80002aaa:	0005b083          	ld	ra,0(a1)
    80002aae:	0085b103          	ld	sp,8(a1)
    80002ab2:	6980                	ld	s0,16(a1)
    80002ab4:	6d84                	ld	s1,24(a1)
    80002ab6:	0205b903          	ld	s2,32(a1)
    80002aba:	0285b983          	ld	s3,40(a1)
    80002abe:	0305ba03          	ld	s4,48(a1)
    80002ac2:	0385ba83          	ld	s5,56(a1)
    80002ac6:	0405bb03          	ld	s6,64(a1)
    80002aca:	0485bb83          	ld	s7,72(a1)
    80002ace:	0505bc03          	ld	s8,80(a1)
    80002ad2:	0585bc83          	ld	s9,88(a1)
    80002ad6:	0605bd03          	ld	s10,96(a1)
    80002ada:	0685bd83          	ld	s11,104(a1)
    80002ade:	8082                	ret

0000000080002ae0 <trapinit>:
void kernelvec();

extern int devintr();

void trapinit(void)
{
    80002ae0:	1141                	addi	sp,sp,-16
    80002ae2:	e406                	sd	ra,8(sp)
    80002ae4:	e022                	sd	s0,0(sp)
    80002ae6:	0800                	addi	s0,sp,16
  initlock(&tickslock, "time");
    80002ae8:	00005597          	auipc	a1,0x5
    80002aec:	7f858593          	addi	a1,a1,2040 # 800082e0 <etext+0x2e0>
    80002af0:	00234517          	auipc	a0,0x234
    80002af4:	4c050513          	addi	a0,a0,1216 # 80236fb0 <tickslock>
    80002af8:	ffffe097          	auipc	ra,0xffffe
    80002afc:	1e6080e7          	jalr	486(ra) # 80000cde <initlock>
}
    80002b00:	60a2                	ld	ra,8(sp)
    80002b02:	6402                	ld	s0,0(sp)
    80002b04:	0141                	addi	sp,sp,16
    80002b06:	8082                	ret

0000000080002b08 <trapinithart>:

// set up to take exceptions and traps while in the kernel.
void trapinithart(void)
{
    80002b08:	1141                	addi	sp,sp,-16
    80002b0a:	e422                	sd	s0,8(sp)
    80002b0c:	0800                	addi	s0,sp,16
  asm volatile("csrw stvec, %0" : : "r" (x));
    80002b0e:	00003797          	auipc	a5,0x3
    80002b12:	6d278793          	addi	a5,a5,1746 # 800061e0 <kernelvec>
    80002b16:	10579073          	csrw	stvec,a5
  w_stvec((uint64)kernelvec);
}
    80002b1a:	6422                	ld	s0,8(sp)
    80002b1c:	0141                	addi	sp,sp,16
    80002b1e:	8082                	ret

0000000080002b20 <usertrapret>:

//
// return to user space
//
void usertrapret(void)
{
    80002b20:	1141                	addi	sp,sp,-16
    80002b22:	e406                	sd	ra,8(sp)
    80002b24:	e022                	sd	s0,0(sp)
    80002b26:	0800                	addi	s0,sp,16
  struct proc *p = myproc();
    80002b28:	fffff097          	auipc	ra,0xfffff
    80002b2c:	10e080e7          	jalr	270(ra) # 80001c36 <myproc>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80002b30:	100027f3          	csrr	a5,sstatus
  w_sstatus(r_sstatus() & ~SSTATUS_SIE);
    80002b34:	9bf5                	andi	a5,a5,-3
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80002b36:	10079073          	csrw	sstatus,a5
  // kerneltrap() to usertrap(), so turn off interrupts until
  // we're back in user space, where usertrap() is correct.
  intr_off();

  // send syscalls, interrupts, and exceptions to uservec in trampoline.S
  uint64 trampoline_uservec = TRAMPOLINE + (uservec - trampoline);
    80002b3a:	00004697          	auipc	a3,0x4
    80002b3e:	4c668693          	addi	a3,a3,1222 # 80007000 <_trampoline>
    80002b42:	00004717          	auipc	a4,0x4
    80002b46:	4be70713          	addi	a4,a4,1214 # 80007000 <_trampoline>
    80002b4a:	8f15                	sub	a4,a4,a3
    80002b4c:	040007b7          	lui	a5,0x4000
    80002b50:	17fd                	addi	a5,a5,-1 # 3ffffff <_entry-0x7c000001>
    80002b52:	07b2                	slli	a5,a5,0xc
    80002b54:	973e                	add	a4,a4,a5
  asm volatile("csrw stvec, %0" : : "r" (x));
    80002b56:	10571073          	csrw	stvec,a4
  w_stvec(trampoline_uservec);

  // set up trapframe values that uservec will need when
  // the process next traps into the kernel.
  p->trapframe->kernel_satp = r_satp();         // kernel page table
    80002b5a:	7138                	ld	a4,96(a0)
  asm volatile("csrr %0, satp" : "=r" (x) );
    80002b5c:	18002673          	csrr	a2,satp
    80002b60:	e310                	sd	a2,0(a4)
  p->trapframe->kernel_sp = p->kstack + PGSIZE; // process's kernel stack
    80002b62:	7130                	ld	a2,96(a0)
    80002b64:	6538                	ld	a4,72(a0)
    80002b66:	6585                	lui	a1,0x1
    80002b68:	972e                	add	a4,a4,a1
    80002b6a:	e618                	sd	a4,8(a2)
  p->trapframe->kernel_trap = (uint64)usertrap;
    80002b6c:	7138                	ld	a4,96(a0)
    80002b6e:	00000617          	auipc	a2,0x0
    80002b72:	14660613          	addi	a2,a2,326 # 80002cb4 <usertrap>
    80002b76:	eb10                	sd	a2,16(a4)
  p->trapframe->kernel_hartid = r_tp(); // hartid for cpuid()
    80002b78:	7138                	ld	a4,96(a0)
  asm volatile("mv %0, tp" : "=r" (x) );
    80002b7a:	8612                	mv	a2,tp
    80002b7c:	f310                	sd	a2,32(a4)
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80002b7e:	10002773          	csrr	a4,sstatus
  // set up the registers that trampoline.S's sret will use
  // to get to user space.

  // set S Previous Privilege mode to User.
  unsigned long x = r_sstatus();
  x &= ~SSTATUS_SPP; // clear SPP to 0 for user mode
    80002b82:	eff77713          	andi	a4,a4,-257
  x |= SSTATUS_SPIE; // enable interrupts in user mode
    80002b86:	02076713          	ori	a4,a4,32
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80002b8a:	10071073          	csrw	sstatus,a4
  w_sstatus(x);

  // set S Exception Program Counter to the saved user pc.
  w_sepc(p->trapframe->epc);
    80002b8e:	7138                	ld	a4,96(a0)
  asm volatile("csrw sepc, %0" : : "r" (x));
    80002b90:	6f18                	ld	a4,24(a4)
    80002b92:	14171073          	csrw	sepc,a4

  // tell trampoline.S the user page table to switch to.
  uint64 satp = MAKE_SATP(p->pagetable);
    80002b96:	6d28                	ld	a0,88(a0)
    80002b98:	8131                	srli	a0,a0,0xc

  // jump to userret in trampoline.S at the top of memory, which
  // switches to the user page table, restores user registers,
  // and switches to user mode with sret.
  uint64 trampoline_userret = TRAMPOLINE + (userret - trampoline);
    80002b9a:	00004717          	auipc	a4,0x4
    80002b9e:	50270713          	addi	a4,a4,1282 # 8000709c <userret>
    80002ba2:	8f15                	sub	a4,a4,a3
    80002ba4:	97ba                	add	a5,a5,a4
  ((void (*)(uint64))trampoline_userret)(satp);
    80002ba6:	577d                	li	a4,-1
    80002ba8:	177e                	slli	a4,a4,0x3f
    80002baa:	8d59                	or	a0,a0,a4
    80002bac:	9782                	jalr	a5
}
    80002bae:	60a2                	ld	ra,8(sp)
    80002bb0:	6402                	ld	s0,0(sp)
    80002bb2:	0141                	addi	sp,sp,16
    80002bb4:	8082                	ret

0000000080002bb6 <clockintr>:
  w_sepc(sepc);
  w_sstatus(sstatus);
}

void clockintr()
{
    80002bb6:	1101                	addi	sp,sp,-32
    80002bb8:	ec06                	sd	ra,24(sp)
    80002bba:	e822                	sd	s0,16(sp)
    80002bbc:	e426                	sd	s1,8(sp)
    80002bbe:	e04a                	sd	s2,0(sp)
    80002bc0:	1000                	addi	s0,sp,32
  acquire(&tickslock);
    80002bc2:	00234917          	auipc	s2,0x234
    80002bc6:	3ee90913          	addi	s2,s2,1006 # 80236fb0 <tickslock>
    80002bca:	854a                	mv	a0,s2
    80002bcc:	ffffe097          	auipc	ra,0xffffe
    80002bd0:	1a2080e7          	jalr	418(ra) # 80000d6e <acquire>
  ticks++;
    80002bd4:	00006497          	auipc	s1,0x6
    80002bd8:	d4448493          	addi	s1,s1,-700 # 80008918 <ticks>
    80002bdc:	409c                	lw	a5,0(s1)
    80002bde:	2785                	addiw	a5,a5,1
    80002be0:	c09c                	sw	a5,0(s1)
  update_time();
    80002be2:	00000097          	auipc	ra,0x0
    80002be6:	e30080e7          	jalr	-464(ra) # 80002a12 <update_time>
  //   // {
  //   //   p->wtime++;
  //   // }
  //   release(&p->lock);
  // }
  wakeup(&ticks);
    80002bea:	8526                	mv	a0,s1
    80002bec:	fffff097          	auipc	ra,0xfffff
    80002bf0:	79e080e7          	jalr	1950(ra) # 8000238a <wakeup>
  release(&tickslock);
    80002bf4:	854a                	mv	a0,s2
    80002bf6:	ffffe097          	auipc	ra,0xffffe
    80002bfa:	22c080e7          	jalr	556(ra) # 80000e22 <release>
}
    80002bfe:	60e2                	ld	ra,24(sp)
    80002c00:	6442                	ld	s0,16(sp)
    80002c02:	64a2                	ld	s1,8(sp)
    80002c04:	6902                	ld	s2,0(sp)
    80002c06:	6105                	addi	sp,sp,32
    80002c08:	8082                	ret

0000000080002c0a <devintr>:
  asm volatile("csrr %0, scause" : "=r" (x) );
    80002c0a:	142027f3          	csrr	a5,scause

    return 2;
  }
  else
  {
    return 0;
    80002c0e:	4501                	li	a0,0
  if ((scause & 0x8000000000000000L) &&
    80002c10:	0a07d163          	bgez	a5,80002cb2 <devintr+0xa8>
{
    80002c14:	1101                	addi	sp,sp,-32
    80002c16:	ec06                	sd	ra,24(sp)
    80002c18:	e822                	sd	s0,16(sp)
    80002c1a:	1000                	addi	s0,sp,32
      (scause & 0xff) == 9)
    80002c1c:	0ff7f713          	zext.b	a4,a5
  if ((scause & 0x8000000000000000L) &&
    80002c20:	46a5                	li	a3,9
    80002c22:	00d70c63          	beq	a4,a3,80002c3a <devintr+0x30>
  else if (scause == 0x8000000000000001L)
    80002c26:	577d                	li	a4,-1
    80002c28:	177e                	slli	a4,a4,0x3f
    80002c2a:	0705                	addi	a4,a4,1
    return 0;
    80002c2c:	4501                	li	a0,0
  else if (scause == 0x8000000000000001L)
    80002c2e:	06e78163          	beq	a5,a4,80002c90 <devintr+0x86>
  }
}
    80002c32:	60e2                	ld	ra,24(sp)
    80002c34:	6442                	ld	s0,16(sp)
    80002c36:	6105                	addi	sp,sp,32
    80002c38:	8082                	ret
    80002c3a:	e426                	sd	s1,8(sp)
    int irq = plic_claim();
    80002c3c:	00003097          	auipc	ra,0x3
    80002c40:	6b0080e7          	jalr	1712(ra) # 800062ec <plic_claim>
    80002c44:	84aa                	mv	s1,a0
    if (irq == UART0_IRQ)
    80002c46:	47a9                	li	a5,10
    80002c48:	00f50963          	beq	a0,a5,80002c5a <devintr+0x50>
    else if (irq == VIRTIO0_IRQ)
    80002c4c:	4785                	li	a5,1
    80002c4e:	00f50b63          	beq	a0,a5,80002c64 <devintr+0x5a>
    return 1;
    80002c52:	4505                	li	a0,1
    else if (irq)
    80002c54:	ec89                	bnez	s1,80002c6e <devintr+0x64>
    80002c56:	64a2                	ld	s1,8(sp)
    80002c58:	bfe9                	j	80002c32 <devintr+0x28>
      uartintr();
    80002c5a:	ffffe097          	auipc	ra,0xffffe
    80002c5e:	da0080e7          	jalr	-608(ra) # 800009fa <uartintr>
    if (irq)
    80002c62:	a839                	j	80002c80 <devintr+0x76>
      virtio_disk_intr();
    80002c64:	00004097          	auipc	ra,0x4
    80002c68:	bb2080e7          	jalr	-1102(ra) # 80006816 <virtio_disk_intr>
    if (irq)
    80002c6c:	a811                	j	80002c80 <devintr+0x76>
      printf("unexpected interrupt irq=%d\n", irq);
    80002c6e:	85a6                	mv	a1,s1
    80002c70:	00005517          	auipc	a0,0x5
    80002c74:	67850513          	addi	a0,a0,1656 # 800082e8 <etext+0x2e8>
    80002c78:	ffffe097          	auipc	ra,0xffffe
    80002c7c:	932080e7          	jalr	-1742(ra) # 800005aa <printf>
      plic_complete(irq);
    80002c80:	8526                	mv	a0,s1
    80002c82:	00003097          	auipc	ra,0x3
    80002c86:	68e080e7          	jalr	1678(ra) # 80006310 <plic_complete>
    return 1;
    80002c8a:	4505                	li	a0,1
    80002c8c:	64a2                	ld	s1,8(sp)
    80002c8e:	b755                	j	80002c32 <devintr+0x28>
    if (cpuid() == 0)
    80002c90:	fffff097          	auipc	ra,0xfffff
    80002c94:	f7a080e7          	jalr	-134(ra) # 80001c0a <cpuid>
    80002c98:	c901                	beqz	a0,80002ca8 <devintr+0x9e>
  asm volatile("csrr %0, sip" : "=r" (x) );
    80002c9a:	144027f3          	csrr	a5,sip
    w_sip(r_sip() & ~2);
    80002c9e:	9bf5                	andi	a5,a5,-3
  asm volatile("csrw sip, %0" : : "r" (x));
    80002ca0:	14479073          	csrw	sip,a5
    return 2;
    80002ca4:	4509                	li	a0,2
    80002ca6:	b771                	j	80002c32 <devintr+0x28>
      clockintr();
    80002ca8:	00000097          	auipc	ra,0x0
    80002cac:	f0e080e7          	jalr	-242(ra) # 80002bb6 <clockintr>
    80002cb0:	b7ed                	j	80002c9a <devintr+0x90>
}
    80002cb2:	8082                	ret

0000000080002cb4 <usertrap>:
{
    80002cb4:	1101                	addi	sp,sp,-32
    80002cb6:	ec06                	sd	ra,24(sp)
    80002cb8:	e822                	sd	s0,16(sp)
    80002cba:	e426                	sd	s1,8(sp)
    80002cbc:	e04a                	sd	s2,0(sp)
    80002cbe:	1000                	addi	s0,sp,32
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80002cc0:	100027f3          	csrr	a5,sstatus
  if ((r_sstatus() & SSTATUS_SPP) != 0)
    80002cc4:	1007f793          	andi	a5,a5,256
    80002cc8:	efa1                	bnez	a5,80002d20 <usertrap+0x6c>
  asm volatile("csrw stvec, %0" : : "r" (x));
    80002cca:	00003797          	auipc	a5,0x3
    80002cce:	51678793          	addi	a5,a5,1302 # 800061e0 <kernelvec>
    80002cd2:	10579073          	csrw	stvec,a5
  struct proc *p = myproc();
    80002cd6:	fffff097          	auipc	ra,0xfffff
    80002cda:	f60080e7          	jalr	-160(ra) # 80001c36 <myproc>
    80002cde:	84aa                	mv	s1,a0
  p->trapframe->epc = r_sepc();
    80002ce0:	713c                	ld	a5,96(a0)
  asm volatile("csrr %0, sepc" : "=r" (x) );
    80002ce2:	14102773          	csrr	a4,sepc
    80002ce6:	ef98                	sd	a4,24(a5)
  asm volatile("csrr %0, scause" : "=r" (x) );
    80002ce8:	14202773          	csrr	a4,scause
  if (r_scause() == 8)
    80002cec:	47a1                	li	a5,8
    80002cee:	04f70163          	beq	a4,a5,80002d30 <usertrap+0x7c>
    80002cf2:	14202773          	csrr	a4,scause
  else if (r_scause() == 15) // write page fault
    80002cf6:	47bd                	li	a5,15
    80002cf8:	06f70663          	beq	a4,a5,80002d64 <usertrap+0xb0>
    80002cfc:	14202773          	csrr	a4,scause
  else if (r_scause() == 13) // read page fault
    80002d00:	47b5                	li	a5,13
    80002d02:	08f70363          	beq	a4,a5,80002d88 <usertrap+0xd4>
  else if ((which_dev = devintr()) != 0)
    80002d06:	00000097          	auipc	ra,0x0
    80002d0a:	f04080e7          	jalr	-252(ra) # 80002c0a <devintr>
    80002d0e:	892a                	mv	s2,a0
    80002d10:	c145                	beqz	a0,80002db0 <usertrap+0xfc>
  if (killed(p))
    80002d12:	8526                	mv	a0,s1
    80002d14:	00000097          	auipc	ra,0x0
    80002d18:	8e2080e7          	jalr	-1822(ra) # 800025f6 <killed>
    80002d1c:	cd69                	beqz	a0,80002df6 <usertrap+0x142>
    80002d1e:	a0f9                	j	80002dec <usertrap+0x138>
    panic("usertrap: not from user mode");
    80002d20:	00005517          	auipc	a0,0x5
    80002d24:	5e850513          	addi	a0,a0,1512 # 80008308 <etext+0x308>
    80002d28:	ffffe097          	auipc	ra,0xffffe
    80002d2c:	838080e7          	jalr	-1992(ra) # 80000560 <panic>
    if (killed(p))
    80002d30:	00000097          	auipc	ra,0x0
    80002d34:	8c6080e7          	jalr	-1850(ra) # 800025f6 <killed>
    80002d38:	e105                	bnez	a0,80002d58 <usertrap+0xa4>
    p->trapframe->epc += 4;
    80002d3a:	70b8                	ld	a4,96(s1)
    80002d3c:	6f1c                	ld	a5,24(a4)
    80002d3e:	0791                	addi	a5,a5,4
    80002d40:	ef1c                	sd	a5,24(a4)
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80002d42:	100027f3          	csrr	a5,sstatus
  w_sstatus(r_sstatus() | SSTATUS_SIE);
    80002d46:	0027e793          	ori	a5,a5,2
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80002d4a:	10079073          	csrw	sstatus,a5
    syscall();
    80002d4e:	00000097          	auipc	ra,0x0
    80002d52:	302080e7          	jalr	770(ra) # 80003050 <syscall>
    80002d56:	a82d                	j	80002d90 <usertrap+0xdc>
      exit(-1);
    80002d58:	557d                	li	a0,-1
    80002d5a:	fffff097          	auipc	ra,0xfffff
    80002d5e:	708080e7          	jalr	1800(ra) # 80002462 <exit>
    80002d62:	bfe1                	j	80002d3a <usertrap+0x86>
  asm volatile("csrr %0, stval" : "=r" (x) );
    80002d64:	143025f3          	csrr	a1,stval
    if (cowfault(p->pagetable, r_stval()) == 0)
    80002d68:	6d28                	ld	a0,88(a0)
    80002d6a:	fffff097          	auipc	ra,0xfffff
    80002d6e:	a94080e7          	jalr	-1388(ra) # 800017fe <cowfault>
    80002d72:	e509                	bnez	a0,80002d7c <usertrap+0xc8>
      p->cow_page_faults += 1;
    80002d74:	409c                	lw	a5,0(s1)
    80002d76:	2785                	addiw	a5,a5,1
    80002d78:	c09c                	sw	a5,0(s1)
    80002d7a:	a819                	j	80002d90 <usertrap+0xdc>
      setkilled(p);
    80002d7c:	8526                	mv	a0,s1
    80002d7e:	00000097          	auipc	ra,0x0
    80002d82:	842080e7          	jalr	-1982(ra) # 800025c0 <setkilled>
    80002d86:	a029                	j	80002d90 <usertrap+0xdc>
    setkilled(p); // Kill process if it was a protected read fault
    80002d88:	00000097          	auipc	ra,0x0
    80002d8c:	838080e7          	jalr	-1992(ra) # 800025c0 <setkilled>
  if (killed(p))
    80002d90:	8526                	mv	a0,s1
    80002d92:	00000097          	auipc	ra,0x0
    80002d96:	864080e7          	jalr	-1948(ra) # 800025f6 <killed>
    80002d9a:	e921                	bnez	a0,80002dea <usertrap+0x136>
  usertrapret();
    80002d9c:	00000097          	auipc	ra,0x0
    80002da0:	d84080e7          	jalr	-636(ra) # 80002b20 <usertrapret>
}
    80002da4:	60e2                	ld	ra,24(sp)
    80002da6:	6442                	ld	s0,16(sp)
    80002da8:	64a2                	ld	s1,8(sp)
    80002daa:	6902                	ld	s2,0(sp)
    80002dac:	6105                	addi	sp,sp,32
    80002dae:	8082                	ret
  asm volatile("csrr %0, scause" : "=r" (x) );
    80002db0:	142025f3          	csrr	a1,scause
    printf("usertrap(): unexpected scause %p pid=%d\n", r_scause(), p->pid);
    80002db4:	5c90                	lw	a2,56(s1)
    80002db6:	00005517          	auipc	a0,0x5
    80002dba:	57250513          	addi	a0,a0,1394 # 80008328 <etext+0x328>
    80002dbe:	ffffd097          	auipc	ra,0xffffd
    80002dc2:	7ec080e7          	jalr	2028(ra) # 800005aa <printf>
  asm volatile("csrr %0, sepc" : "=r" (x) );
    80002dc6:	141025f3          	csrr	a1,sepc
  asm volatile("csrr %0, stval" : "=r" (x) );
    80002dca:	14302673          	csrr	a2,stval
    printf("            sepc=%p stval=%p\n", r_sepc(), r_stval());
    80002dce:	00005517          	auipc	a0,0x5
    80002dd2:	58a50513          	addi	a0,a0,1418 # 80008358 <etext+0x358>
    80002dd6:	ffffd097          	auipc	ra,0xffffd
    80002dda:	7d4080e7          	jalr	2004(ra) # 800005aa <printf>
    setkilled(p);
    80002dde:	8526                	mv	a0,s1
    80002de0:	fffff097          	auipc	ra,0xfffff
    80002de4:	7e0080e7          	jalr	2016(ra) # 800025c0 <setkilled>
    80002de8:	b765                	j	80002d90 <usertrap+0xdc>
  if (killed(p))
    80002dea:	4901                	li	s2,0
    exit(-1);
    80002dec:	557d                	li	a0,-1
    80002dee:	fffff097          	auipc	ra,0xfffff
    80002df2:	674080e7          	jalr	1652(ra) # 80002462 <exit>
  if (which_dev == 2)
    80002df6:	4789                	li	a5,2
    80002df8:	faf912e3          	bne	s2,a5,80002d9c <usertrap+0xe8>
    yield();
    80002dfc:	fffff097          	auipc	ra,0xfffff
    80002e00:	4da080e7          	jalr	1242(ra) # 800022d6 <yield>
    80002e04:	bf61                	j	80002d9c <usertrap+0xe8>

0000000080002e06 <kerneltrap>:
{
    80002e06:	7179                	addi	sp,sp,-48
    80002e08:	f406                	sd	ra,40(sp)
    80002e0a:	f022                	sd	s0,32(sp)
    80002e0c:	ec26                	sd	s1,24(sp)
    80002e0e:	e84a                	sd	s2,16(sp)
    80002e10:	e44e                	sd	s3,8(sp)
    80002e12:	1800                	addi	s0,sp,48
  asm volatile("csrr %0, sepc" : "=r" (x) );
    80002e14:	14102973          	csrr	s2,sepc
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80002e18:	100024f3          	csrr	s1,sstatus
  asm volatile("csrr %0, scause" : "=r" (x) );
    80002e1c:	142029f3          	csrr	s3,scause
  if ((sstatus & SSTATUS_SPP) == 0)
    80002e20:	1004f793          	andi	a5,s1,256
    80002e24:	cb85                	beqz	a5,80002e54 <kerneltrap+0x4e>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80002e26:	100027f3          	csrr	a5,sstatus
  return (x & SSTATUS_SIE) != 0;
    80002e2a:	8b89                	andi	a5,a5,2
  if (intr_get() != 0)
    80002e2c:	ef85                	bnez	a5,80002e64 <kerneltrap+0x5e>
  if ((which_dev = devintr()) == 0)
    80002e2e:	00000097          	auipc	ra,0x0
    80002e32:	ddc080e7          	jalr	-548(ra) # 80002c0a <devintr>
    80002e36:	cd1d                	beqz	a0,80002e74 <kerneltrap+0x6e>
  if (which_dev == 2 && myproc() != 0 && myproc()->state == RUNNING)
    80002e38:	4789                	li	a5,2
    80002e3a:	06f50a63          	beq	a0,a5,80002eae <kerneltrap+0xa8>
  asm volatile("csrw sepc, %0" : : "r" (x));
    80002e3e:	14191073          	csrw	sepc,s2
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80002e42:	10049073          	csrw	sstatus,s1
}
    80002e46:	70a2                	ld	ra,40(sp)
    80002e48:	7402                	ld	s0,32(sp)
    80002e4a:	64e2                	ld	s1,24(sp)
    80002e4c:	6942                	ld	s2,16(sp)
    80002e4e:	69a2                	ld	s3,8(sp)
    80002e50:	6145                	addi	sp,sp,48
    80002e52:	8082                	ret
    panic("kerneltrap: not from supervisor mode");
    80002e54:	00005517          	auipc	a0,0x5
    80002e58:	52450513          	addi	a0,a0,1316 # 80008378 <etext+0x378>
    80002e5c:	ffffd097          	auipc	ra,0xffffd
    80002e60:	704080e7          	jalr	1796(ra) # 80000560 <panic>
    panic("kerneltrap: interrupts enabled");
    80002e64:	00005517          	auipc	a0,0x5
    80002e68:	53c50513          	addi	a0,a0,1340 # 800083a0 <etext+0x3a0>
    80002e6c:	ffffd097          	auipc	ra,0xffffd
    80002e70:	6f4080e7          	jalr	1780(ra) # 80000560 <panic>
    printf("scause %p\n", scause);
    80002e74:	85ce                	mv	a1,s3
    80002e76:	00005517          	auipc	a0,0x5
    80002e7a:	54a50513          	addi	a0,a0,1354 # 800083c0 <etext+0x3c0>
    80002e7e:	ffffd097          	auipc	ra,0xffffd
    80002e82:	72c080e7          	jalr	1836(ra) # 800005aa <printf>
  asm volatile("csrr %0, sepc" : "=r" (x) );
    80002e86:	141025f3          	csrr	a1,sepc
  asm volatile("csrr %0, stval" : "=r" (x) );
    80002e8a:	14302673          	csrr	a2,stval
    printf("sepc=%p stval=%p\n", r_sepc(), r_stval());
    80002e8e:	00005517          	auipc	a0,0x5
    80002e92:	54250513          	addi	a0,a0,1346 # 800083d0 <etext+0x3d0>
    80002e96:	ffffd097          	auipc	ra,0xffffd
    80002e9a:	714080e7          	jalr	1812(ra) # 800005aa <printf>
    panic("kerneltrap");
    80002e9e:	00005517          	auipc	a0,0x5
    80002ea2:	54a50513          	addi	a0,a0,1354 # 800083e8 <etext+0x3e8>
    80002ea6:	ffffd097          	auipc	ra,0xffffd
    80002eaa:	6ba080e7          	jalr	1722(ra) # 80000560 <panic>
  if (which_dev == 2 && myproc() != 0 && myproc()->state == RUNNING)
    80002eae:	fffff097          	auipc	ra,0xfffff
    80002eb2:	d88080e7          	jalr	-632(ra) # 80001c36 <myproc>
    80002eb6:	d541                	beqz	a0,80002e3e <kerneltrap+0x38>
    80002eb8:	fffff097          	auipc	ra,0xfffff
    80002ebc:	d7e080e7          	jalr	-642(ra) # 80001c36 <myproc>
    80002ec0:	5118                	lw	a4,32(a0)
    80002ec2:	4791                	li	a5,4
    80002ec4:	f6f71de3          	bne	a4,a5,80002e3e <kerneltrap+0x38>
    yield();
    80002ec8:	fffff097          	auipc	ra,0xfffff
    80002ecc:	40e080e7          	jalr	1038(ra) # 800022d6 <yield>
    80002ed0:	b7bd                	j	80002e3e <kerneltrap+0x38>

0000000080002ed2 <argraw>:
  return strlen(buf);
}

static uint64
argraw(int n)
{
    80002ed2:	1101                	addi	sp,sp,-32
    80002ed4:	ec06                	sd	ra,24(sp)
    80002ed6:	e822                	sd	s0,16(sp)
    80002ed8:	e426                	sd	s1,8(sp)
    80002eda:	1000                	addi	s0,sp,32
    80002edc:	84aa                	mv	s1,a0
  struct proc *p = myproc();
    80002ede:	fffff097          	auipc	ra,0xfffff
    80002ee2:	d58080e7          	jalr	-680(ra) # 80001c36 <myproc>
  switch (n) {
    80002ee6:	4795                	li	a5,5
    80002ee8:	0497e163          	bltu	a5,s1,80002f2a <argraw+0x58>
    80002eec:	048a                	slli	s1,s1,0x2
    80002eee:	00006717          	auipc	a4,0x6
    80002ef2:	8ba70713          	addi	a4,a4,-1862 # 800087a8 <states.0+0x30>
    80002ef6:	94ba                	add	s1,s1,a4
    80002ef8:	409c                	lw	a5,0(s1)
    80002efa:	97ba                	add	a5,a5,a4
    80002efc:	8782                	jr	a5
  case 0:
    return p->trapframe->a0;
    80002efe:	713c                	ld	a5,96(a0)
    80002f00:	7ba8                	ld	a0,112(a5)
  case 5:
    return p->trapframe->a5;
  }
  panic("argraw");
  return -1;
}
    80002f02:	60e2                	ld	ra,24(sp)
    80002f04:	6442                	ld	s0,16(sp)
    80002f06:	64a2                	ld	s1,8(sp)
    80002f08:	6105                	addi	sp,sp,32
    80002f0a:	8082                	ret
    return p->trapframe->a1;
    80002f0c:	713c                	ld	a5,96(a0)
    80002f0e:	7fa8                	ld	a0,120(a5)
    80002f10:	bfcd                	j	80002f02 <argraw+0x30>
    return p->trapframe->a2;
    80002f12:	713c                	ld	a5,96(a0)
    80002f14:	63c8                	ld	a0,128(a5)
    80002f16:	b7f5                	j	80002f02 <argraw+0x30>
    return p->trapframe->a3;
    80002f18:	713c                	ld	a5,96(a0)
    80002f1a:	67c8                	ld	a0,136(a5)
    80002f1c:	b7dd                	j	80002f02 <argraw+0x30>
    return p->trapframe->a4;
    80002f1e:	713c                	ld	a5,96(a0)
    80002f20:	6bc8                	ld	a0,144(a5)
    80002f22:	b7c5                	j	80002f02 <argraw+0x30>
    return p->trapframe->a5;
    80002f24:	713c                	ld	a5,96(a0)
    80002f26:	6fc8                	ld	a0,152(a5)
    80002f28:	bfe9                	j	80002f02 <argraw+0x30>
  panic("argraw");
    80002f2a:	00005517          	auipc	a0,0x5
    80002f2e:	4ce50513          	addi	a0,a0,1230 # 800083f8 <etext+0x3f8>
    80002f32:	ffffd097          	auipc	ra,0xffffd
    80002f36:	62e080e7          	jalr	1582(ra) # 80000560 <panic>

0000000080002f3a <fetchaddr>:
{
    80002f3a:	1101                	addi	sp,sp,-32
    80002f3c:	ec06                	sd	ra,24(sp)
    80002f3e:	e822                	sd	s0,16(sp)
    80002f40:	e426                	sd	s1,8(sp)
    80002f42:	e04a                	sd	s2,0(sp)
    80002f44:	1000                	addi	s0,sp,32
    80002f46:	84aa                	mv	s1,a0
    80002f48:	892e                	mv	s2,a1
  struct proc *p = myproc();
    80002f4a:	fffff097          	auipc	ra,0xfffff
    80002f4e:	cec080e7          	jalr	-788(ra) # 80001c36 <myproc>
  if(addr >= p->sz || addr+sizeof(uint64) > p->sz) // both tests needed, in case of overflow
    80002f52:	693c                	ld	a5,80(a0)
    80002f54:	02f4f863          	bgeu	s1,a5,80002f84 <fetchaddr+0x4a>
    80002f58:	00848713          	addi	a4,s1,8
    80002f5c:	02e7e663          	bltu	a5,a4,80002f88 <fetchaddr+0x4e>
  if(copyin(p->pagetable, (char *)ip, addr, sizeof(*ip)) != 0)
    80002f60:	46a1                	li	a3,8
    80002f62:	8626                	mv	a2,s1
    80002f64:	85ca                	mv	a1,s2
    80002f66:	6d28                	ld	a0,88(a0)
    80002f68:	fffff097          	auipc	ra,0xfffff
    80002f6c:	9f0080e7          	jalr	-1552(ra) # 80001958 <copyin>
    80002f70:	00a03533          	snez	a0,a0
    80002f74:	40a00533          	neg	a0,a0
}
    80002f78:	60e2                	ld	ra,24(sp)
    80002f7a:	6442                	ld	s0,16(sp)
    80002f7c:	64a2                	ld	s1,8(sp)
    80002f7e:	6902                	ld	s2,0(sp)
    80002f80:	6105                	addi	sp,sp,32
    80002f82:	8082                	ret
    return -1;
    80002f84:	557d                	li	a0,-1
    80002f86:	bfcd                	j	80002f78 <fetchaddr+0x3e>
    80002f88:	557d                	li	a0,-1
    80002f8a:	b7fd                	j	80002f78 <fetchaddr+0x3e>

0000000080002f8c <fetchstr>:
{
    80002f8c:	7179                	addi	sp,sp,-48
    80002f8e:	f406                	sd	ra,40(sp)
    80002f90:	f022                	sd	s0,32(sp)
    80002f92:	ec26                	sd	s1,24(sp)
    80002f94:	e84a                	sd	s2,16(sp)
    80002f96:	e44e                	sd	s3,8(sp)
    80002f98:	1800                	addi	s0,sp,48
    80002f9a:	892a                	mv	s2,a0
    80002f9c:	84ae                	mv	s1,a1
    80002f9e:	89b2                	mv	s3,a2
  struct proc *p = myproc();
    80002fa0:	fffff097          	auipc	ra,0xfffff
    80002fa4:	c96080e7          	jalr	-874(ra) # 80001c36 <myproc>
  if(copyinstr(p->pagetable, buf, addr, max) < 0)
    80002fa8:	86ce                	mv	a3,s3
    80002faa:	864a                	mv	a2,s2
    80002fac:	85a6                	mv	a1,s1
    80002fae:	6d28                	ld	a0,88(a0)
    80002fb0:	fffff097          	auipc	ra,0xfffff
    80002fb4:	a36080e7          	jalr	-1482(ra) # 800019e6 <copyinstr>
    80002fb8:	00054e63          	bltz	a0,80002fd4 <fetchstr+0x48>
  return strlen(buf);
    80002fbc:	8526                	mv	a0,s1
    80002fbe:	ffffe097          	auipc	ra,0xffffe
    80002fc2:	020080e7          	jalr	32(ra) # 80000fde <strlen>
}
    80002fc6:	70a2                	ld	ra,40(sp)
    80002fc8:	7402                	ld	s0,32(sp)
    80002fca:	64e2                	ld	s1,24(sp)
    80002fcc:	6942                	ld	s2,16(sp)
    80002fce:	69a2                	ld	s3,8(sp)
    80002fd0:	6145                	addi	sp,sp,48
    80002fd2:	8082                	ret
    return -1;
    80002fd4:	557d                	li	a0,-1
    80002fd6:	bfc5                	j	80002fc6 <fetchstr+0x3a>

0000000080002fd8 <argint>:

// Fetch the nth 32-bit system call argument.
void
argint(int n, int *ip)
{
    80002fd8:	1101                	addi	sp,sp,-32
    80002fda:	ec06                	sd	ra,24(sp)
    80002fdc:	e822                	sd	s0,16(sp)
    80002fde:	e426                	sd	s1,8(sp)
    80002fe0:	1000                	addi	s0,sp,32
    80002fe2:	84ae                	mv	s1,a1
  *ip = argraw(n);
    80002fe4:	00000097          	auipc	ra,0x0
    80002fe8:	eee080e7          	jalr	-274(ra) # 80002ed2 <argraw>
    80002fec:	c088                	sw	a0,0(s1)
}
    80002fee:	60e2                	ld	ra,24(sp)
    80002ff0:	6442                	ld	s0,16(sp)
    80002ff2:	64a2                	ld	s1,8(sp)
    80002ff4:	6105                	addi	sp,sp,32
    80002ff6:	8082                	ret

0000000080002ff8 <argaddr>:
// Retrieve an argument as a pointer.
// Doesn't check for legality, since
// copyin/copyout will do that.
void
argaddr(int n, uint64 *ip)
{
    80002ff8:	1101                	addi	sp,sp,-32
    80002ffa:	ec06                	sd	ra,24(sp)
    80002ffc:	e822                	sd	s0,16(sp)
    80002ffe:	e426                	sd	s1,8(sp)
    80003000:	1000                	addi	s0,sp,32
    80003002:	84ae                	mv	s1,a1
  *ip = argraw(n);
    80003004:	00000097          	auipc	ra,0x0
    80003008:	ece080e7          	jalr	-306(ra) # 80002ed2 <argraw>
    8000300c:	e088                	sd	a0,0(s1)
}
    8000300e:	60e2                	ld	ra,24(sp)
    80003010:	6442                	ld	s0,16(sp)
    80003012:	64a2                	ld	s1,8(sp)
    80003014:	6105                	addi	sp,sp,32
    80003016:	8082                	ret

0000000080003018 <argstr>:
// Fetch the nth word-sized system call argument as a null-terminated string.
// Copies into buf, at most max.
// Returns string length if OK (including nul), -1 if error.
int
argstr(int n, char *buf, int max)
{
    80003018:	7179                	addi	sp,sp,-48
    8000301a:	f406                	sd	ra,40(sp)
    8000301c:	f022                	sd	s0,32(sp)
    8000301e:	ec26                	sd	s1,24(sp)
    80003020:	e84a                	sd	s2,16(sp)
    80003022:	1800                	addi	s0,sp,48
    80003024:	84ae                	mv	s1,a1
    80003026:	8932                	mv	s2,a2
  uint64 addr;
  argaddr(n, &addr);
    80003028:	fd840593          	addi	a1,s0,-40
    8000302c:	00000097          	auipc	ra,0x0
    80003030:	fcc080e7          	jalr	-52(ra) # 80002ff8 <argaddr>
  return fetchstr(addr, buf, max);
    80003034:	864a                	mv	a2,s2
    80003036:	85a6                	mv	a1,s1
    80003038:	fd843503          	ld	a0,-40(s0)
    8000303c:	00000097          	auipc	ra,0x0
    80003040:	f50080e7          	jalr	-176(ra) # 80002f8c <fetchstr>
}
    80003044:	70a2                	ld	ra,40(sp)
    80003046:	7402                	ld	s0,32(sp)
    80003048:	64e2                	ld	s1,24(sp)
    8000304a:	6942                	ld	s2,16(sp)
    8000304c:	6145                	addi	sp,sp,48
    8000304e:	8082                	ret

0000000080003050 <syscall>:
[SYS_get_cow_faults] = sys_get_cow_faults,
};

void
syscall(void)
{
    80003050:	1101                	addi	sp,sp,-32
    80003052:	ec06                	sd	ra,24(sp)
    80003054:	e822                	sd	s0,16(sp)
    80003056:	e426                	sd	s1,8(sp)
    80003058:	e04a                	sd	s2,0(sp)
    8000305a:	1000                	addi	s0,sp,32
  int num;
  struct proc *p = myproc();
    8000305c:	fffff097          	auipc	ra,0xfffff
    80003060:	bda080e7          	jalr	-1062(ra) # 80001c36 <myproc>
    80003064:	84aa                	mv	s1,a0

  num = p->trapframe->a7;
    80003066:	06053903          	ld	s2,96(a0)
    8000306a:	0a893783          	ld	a5,168(s2)
    8000306e:	0007869b          	sext.w	a3,a5
  if(num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    80003072:	37fd                	addiw	a5,a5,-1
    80003074:	4761                	li	a4,24
    80003076:	00f76f63          	bltu	a4,a5,80003094 <syscall+0x44>
    8000307a:	00369713          	slli	a4,a3,0x3
    8000307e:	00005797          	auipc	a5,0x5
    80003082:	74278793          	addi	a5,a5,1858 # 800087c0 <syscalls>
    80003086:	97ba                	add	a5,a5,a4
    80003088:	639c                	ld	a5,0(a5)
    8000308a:	c789                	beqz	a5,80003094 <syscall+0x44>
    // Use num to lookup the system call function for num, call it,
    // and store its return value in p->trapframe->a0
    p->trapframe->a0 = syscalls[num]();
    8000308c:	9782                	jalr	a5
    8000308e:	06a93823          	sd	a0,112(s2)
    80003092:	a839                	j	800030b0 <syscall+0x60>
  } else {
    printf("%d %s: unknown sys call %d\n",
    80003094:	16048613          	addi	a2,s1,352
    80003098:	5c8c                	lw	a1,56(s1)
    8000309a:	00005517          	auipc	a0,0x5
    8000309e:	36650513          	addi	a0,a0,870 # 80008400 <etext+0x400>
    800030a2:	ffffd097          	auipc	ra,0xffffd
    800030a6:	508080e7          	jalr	1288(ra) # 800005aa <printf>
            p->pid, p->name, num);
    p->trapframe->a0 = -1;
    800030aa:	70bc                	ld	a5,96(s1)
    800030ac:	577d                	li	a4,-1
    800030ae:	fbb8                	sd	a4,112(a5)
  }
}
    800030b0:	60e2                	ld	ra,24(sp)
    800030b2:	6442                	ld	s0,16(sp)
    800030b4:	64a2                	ld	s1,8(sp)
    800030b6:	6902                	ld	s2,0(sp)
    800030b8:	6105                	addi	sp,sp,32
    800030ba:	8082                	ret

00000000800030bc <sys_exit>:
#include "spinlock.h"
#include "proc.h"

uint64
sys_exit(void)
{
    800030bc:	1101                	addi	sp,sp,-32
    800030be:	ec06                	sd	ra,24(sp)
    800030c0:	e822                	sd	s0,16(sp)
    800030c2:	1000                	addi	s0,sp,32
  int n;
  argint(0, &n);
    800030c4:	fec40593          	addi	a1,s0,-20
    800030c8:	4501                	li	a0,0
    800030ca:	00000097          	auipc	ra,0x0
    800030ce:	f0e080e7          	jalr	-242(ra) # 80002fd8 <argint>
  exit(n);
    800030d2:	fec42503          	lw	a0,-20(s0)
    800030d6:	fffff097          	auipc	ra,0xfffff
    800030da:	38c080e7          	jalr	908(ra) # 80002462 <exit>
  return 0; // not reached
}
    800030de:	4501                	li	a0,0
    800030e0:	60e2                	ld	ra,24(sp)
    800030e2:	6442                	ld	s0,16(sp)
    800030e4:	6105                	addi	sp,sp,32
    800030e6:	8082                	ret

00000000800030e8 <sys_getpid>:

uint64
sys_getpid(void)
{
    800030e8:	1141                	addi	sp,sp,-16
    800030ea:	e406                	sd	ra,8(sp)
    800030ec:	e022                	sd	s0,0(sp)
    800030ee:	0800                	addi	s0,sp,16
  return myproc()->pid;
    800030f0:	fffff097          	auipc	ra,0xfffff
    800030f4:	b46080e7          	jalr	-1210(ra) # 80001c36 <myproc>
}
    800030f8:	5d08                	lw	a0,56(a0)
    800030fa:	60a2                	ld	ra,8(sp)
    800030fc:	6402                	ld	s0,0(sp)
    800030fe:	0141                	addi	sp,sp,16
    80003100:	8082                	ret

0000000080003102 <sys_fork>:

uint64
sys_fork(void)
{
    80003102:	1141                	addi	sp,sp,-16
    80003104:	e406                	sd	ra,8(sp)
    80003106:	e022                	sd	s0,0(sp)
    80003108:	0800                	addi	s0,sp,16
  return fork();
    8000310a:	fffff097          	auipc	ra,0xfffff
    8000310e:	f06080e7          	jalr	-250(ra) # 80002010 <fork>
}
    80003112:	60a2                	ld	ra,8(sp)
    80003114:	6402                	ld	s0,0(sp)
    80003116:	0141                	addi	sp,sp,16
    80003118:	8082                	ret

000000008000311a <sys_wait>:

uint64
sys_wait(void)
{
    8000311a:	1101                	addi	sp,sp,-32
    8000311c:	ec06                	sd	ra,24(sp)
    8000311e:	e822                	sd	s0,16(sp)
    80003120:	1000                	addi	s0,sp,32
  uint64 p;
  argaddr(0, &p);
    80003122:	fe840593          	addi	a1,s0,-24
    80003126:	4501                	li	a0,0
    80003128:	00000097          	auipc	ra,0x0
    8000312c:	ed0080e7          	jalr	-304(ra) # 80002ff8 <argaddr>
  return wait(p);
    80003130:	fe843503          	ld	a0,-24(s0)
    80003134:	fffff097          	auipc	ra,0xfffff
    80003138:	4f8080e7          	jalr	1272(ra) # 8000262c <wait>
}
    8000313c:	60e2                	ld	ra,24(sp)
    8000313e:	6442                	ld	s0,16(sp)
    80003140:	6105                	addi	sp,sp,32
    80003142:	8082                	ret

0000000080003144 <sys_sbrk>:

uint64
sys_sbrk(void)
{
    80003144:	7179                	addi	sp,sp,-48
    80003146:	f406                	sd	ra,40(sp)
    80003148:	f022                	sd	s0,32(sp)
    8000314a:	ec26                	sd	s1,24(sp)
    8000314c:	1800                	addi	s0,sp,48
  uint64 addr;
  int n;

  argint(0, &n);
    8000314e:	fdc40593          	addi	a1,s0,-36
    80003152:	4501                	li	a0,0
    80003154:	00000097          	auipc	ra,0x0
    80003158:	e84080e7          	jalr	-380(ra) # 80002fd8 <argint>
  addr = myproc()->sz;
    8000315c:	fffff097          	auipc	ra,0xfffff
    80003160:	ada080e7          	jalr	-1318(ra) # 80001c36 <myproc>
    80003164:	6924                	ld	s1,80(a0)
  if (growproc(n) < 0)
    80003166:	fdc42503          	lw	a0,-36(s0)
    8000316a:	fffff097          	auipc	ra,0xfffff
    8000316e:	e4a080e7          	jalr	-438(ra) # 80001fb4 <growproc>
    80003172:	00054863          	bltz	a0,80003182 <sys_sbrk+0x3e>
    return -1;
  return addr;
}
    80003176:	8526                	mv	a0,s1
    80003178:	70a2                	ld	ra,40(sp)
    8000317a:	7402                	ld	s0,32(sp)
    8000317c:	64e2                	ld	s1,24(sp)
    8000317e:	6145                	addi	sp,sp,48
    80003180:	8082                	ret
    return -1;
    80003182:	54fd                	li	s1,-1
    80003184:	bfcd                	j	80003176 <sys_sbrk+0x32>

0000000080003186 <sys_sleep>:

uint64
sys_sleep(void)
{
    80003186:	7139                	addi	sp,sp,-64
    80003188:	fc06                	sd	ra,56(sp)
    8000318a:	f822                	sd	s0,48(sp)
    8000318c:	f04a                	sd	s2,32(sp)
    8000318e:	0080                	addi	s0,sp,64
  int n;
  uint ticks0;

  argint(0, &n);
    80003190:	fcc40593          	addi	a1,s0,-52
    80003194:	4501                	li	a0,0
    80003196:	00000097          	auipc	ra,0x0
    8000319a:	e42080e7          	jalr	-446(ra) # 80002fd8 <argint>
  acquire(&tickslock);
    8000319e:	00234517          	auipc	a0,0x234
    800031a2:	e1250513          	addi	a0,a0,-494 # 80236fb0 <tickslock>
    800031a6:	ffffe097          	auipc	ra,0xffffe
    800031aa:	bc8080e7          	jalr	-1080(ra) # 80000d6e <acquire>
  ticks0 = ticks;
    800031ae:	00005917          	auipc	s2,0x5
    800031b2:	76a92903          	lw	s2,1898(s2) # 80008918 <ticks>
  while (ticks - ticks0 < n)
    800031b6:	fcc42783          	lw	a5,-52(s0)
    800031ba:	c3b9                	beqz	a5,80003200 <sys_sleep+0x7a>
    800031bc:	f426                	sd	s1,40(sp)
    800031be:	ec4e                	sd	s3,24(sp)
    if (killed(myproc()))
    {
      release(&tickslock);
      return -1;
    }
    sleep(&ticks, &tickslock);
    800031c0:	00234997          	auipc	s3,0x234
    800031c4:	df098993          	addi	s3,s3,-528 # 80236fb0 <tickslock>
    800031c8:	00005497          	auipc	s1,0x5
    800031cc:	75048493          	addi	s1,s1,1872 # 80008918 <ticks>
    if (killed(myproc()))
    800031d0:	fffff097          	auipc	ra,0xfffff
    800031d4:	a66080e7          	jalr	-1434(ra) # 80001c36 <myproc>
    800031d8:	fffff097          	auipc	ra,0xfffff
    800031dc:	41e080e7          	jalr	1054(ra) # 800025f6 <killed>
    800031e0:	ed15                	bnez	a0,8000321c <sys_sleep+0x96>
    sleep(&ticks, &tickslock);
    800031e2:	85ce                	mv	a1,s3
    800031e4:	8526                	mv	a0,s1
    800031e6:	fffff097          	auipc	ra,0xfffff
    800031ea:	136080e7          	jalr	310(ra) # 8000231c <sleep>
  while (ticks - ticks0 < n)
    800031ee:	409c                	lw	a5,0(s1)
    800031f0:	412787bb          	subw	a5,a5,s2
    800031f4:	fcc42703          	lw	a4,-52(s0)
    800031f8:	fce7ece3          	bltu	a5,a4,800031d0 <sys_sleep+0x4a>
    800031fc:	74a2                	ld	s1,40(sp)
    800031fe:	69e2                	ld	s3,24(sp)
  }
  release(&tickslock);
    80003200:	00234517          	auipc	a0,0x234
    80003204:	db050513          	addi	a0,a0,-592 # 80236fb0 <tickslock>
    80003208:	ffffe097          	auipc	ra,0xffffe
    8000320c:	c1a080e7          	jalr	-998(ra) # 80000e22 <release>
  return 0;
    80003210:	4501                	li	a0,0
}
    80003212:	70e2                	ld	ra,56(sp)
    80003214:	7442                	ld	s0,48(sp)
    80003216:	7902                	ld	s2,32(sp)
    80003218:	6121                	addi	sp,sp,64
    8000321a:	8082                	ret
      release(&tickslock);
    8000321c:	00234517          	auipc	a0,0x234
    80003220:	d9450513          	addi	a0,a0,-620 # 80236fb0 <tickslock>
    80003224:	ffffe097          	auipc	ra,0xffffe
    80003228:	bfe080e7          	jalr	-1026(ra) # 80000e22 <release>
      return -1;
    8000322c:	557d                	li	a0,-1
    8000322e:	74a2                	ld	s1,40(sp)
    80003230:	69e2                	ld	s3,24(sp)
    80003232:	b7c5                	j	80003212 <sys_sleep+0x8c>

0000000080003234 <sys_kill>:

uint64
sys_kill(void)
{
    80003234:	1101                	addi	sp,sp,-32
    80003236:	ec06                	sd	ra,24(sp)
    80003238:	e822                	sd	s0,16(sp)
    8000323a:	1000                	addi	s0,sp,32
  int pid;

  argint(0, &pid);
    8000323c:	fec40593          	addi	a1,s0,-20
    80003240:	4501                	li	a0,0
    80003242:	00000097          	auipc	ra,0x0
    80003246:	d96080e7          	jalr	-618(ra) # 80002fd8 <argint>
  return kill(pid);
    8000324a:	fec42503          	lw	a0,-20(s0)
    8000324e:	fffff097          	auipc	ra,0xfffff
    80003252:	2f8080e7          	jalr	760(ra) # 80002546 <kill>
}
    80003256:	60e2                	ld	ra,24(sp)
    80003258:	6442                	ld	s0,16(sp)
    8000325a:	6105                	addi	sp,sp,32
    8000325c:	8082                	ret

000000008000325e <sys_uptime>:

// return how many clock tick interrupts have occurred
// since start.
uint64
sys_uptime(void)
{
    8000325e:	1101                	addi	sp,sp,-32
    80003260:	ec06                	sd	ra,24(sp)
    80003262:	e822                	sd	s0,16(sp)
    80003264:	e426                	sd	s1,8(sp)
    80003266:	1000                	addi	s0,sp,32
  uint xticks;

  acquire(&tickslock);
    80003268:	00234517          	auipc	a0,0x234
    8000326c:	d4850513          	addi	a0,a0,-696 # 80236fb0 <tickslock>
    80003270:	ffffe097          	auipc	ra,0xffffe
    80003274:	afe080e7          	jalr	-1282(ra) # 80000d6e <acquire>
  xticks = ticks;
    80003278:	00005497          	auipc	s1,0x5
    8000327c:	6a04a483          	lw	s1,1696(s1) # 80008918 <ticks>
  release(&tickslock);
    80003280:	00234517          	auipc	a0,0x234
    80003284:	d3050513          	addi	a0,a0,-720 # 80236fb0 <tickslock>
    80003288:	ffffe097          	auipc	ra,0xffffe
    8000328c:	b9a080e7          	jalr	-1126(ra) # 80000e22 <release>
  return xticks;
}
    80003290:	02049513          	slli	a0,s1,0x20
    80003294:	9101                	srli	a0,a0,0x20
    80003296:	60e2                	ld	ra,24(sp)
    80003298:	6442                	ld	s0,16(sp)
    8000329a:	64a2                	ld	s1,8(sp)
    8000329c:	6105                	addi	sp,sp,32
    8000329e:	8082                	ret

00000000800032a0 <sys_waitx>:

uint64
sys_waitx(void)
{
    800032a0:	7139                	addi	sp,sp,-64
    800032a2:	fc06                	sd	ra,56(sp)
    800032a4:	f822                	sd	s0,48(sp)
    800032a6:	f426                	sd	s1,40(sp)
    800032a8:	f04a                	sd	s2,32(sp)
    800032aa:	0080                	addi	s0,sp,64
  uint64 addr, addr1, addr2;
  uint wtime, rtime;
  argaddr(0, &addr);
    800032ac:	fd840593          	addi	a1,s0,-40
    800032b0:	4501                	li	a0,0
    800032b2:	00000097          	auipc	ra,0x0
    800032b6:	d46080e7          	jalr	-698(ra) # 80002ff8 <argaddr>
  argaddr(1, &addr1); // user virtual memory
    800032ba:	fd040593          	addi	a1,s0,-48
    800032be:	4505                	li	a0,1
    800032c0:	00000097          	auipc	ra,0x0
    800032c4:	d38080e7          	jalr	-712(ra) # 80002ff8 <argaddr>
  argaddr(2, &addr2);
    800032c8:	fc840593          	addi	a1,s0,-56
    800032cc:	4509                	li	a0,2
    800032ce:	00000097          	auipc	ra,0x0
    800032d2:	d2a080e7          	jalr	-726(ra) # 80002ff8 <argaddr>
  int ret = waitx(addr, &wtime, &rtime);
    800032d6:	fc040613          	addi	a2,s0,-64
    800032da:	fc440593          	addi	a1,s0,-60
    800032de:	fd843503          	ld	a0,-40(s0)
    800032e2:	fffff097          	auipc	ra,0xfffff
    800032e6:	5dc080e7          	jalr	1500(ra) # 800028be <waitx>
    800032ea:	892a                	mv	s2,a0
  struct proc *p = myproc();
    800032ec:	fffff097          	auipc	ra,0xfffff
    800032f0:	94a080e7          	jalr	-1718(ra) # 80001c36 <myproc>
    800032f4:	84aa                	mv	s1,a0
  if (copyout(p->pagetable, addr1, (char *)&wtime, sizeof(int)) < 0)
    800032f6:	4691                	li	a3,4
    800032f8:	fc440613          	addi	a2,s0,-60
    800032fc:	fd043583          	ld	a1,-48(s0)
    80003300:	6d28                	ld	a0,88(a0)
    80003302:	ffffe097          	auipc	ra,0xffffe
    80003306:	584080e7          	jalr	1412(ra) # 80001886 <copyout>
    return -1;
    8000330a:	57fd                	li	a5,-1
  if (copyout(p->pagetable, addr1, (char *)&wtime, sizeof(int)) < 0)
    8000330c:	00054f63          	bltz	a0,8000332a <sys_waitx+0x8a>
  if (copyout(p->pagetable, addr2, (char *)&rtime, sizeof(int)) < 0)
    80003310:	4691                	li	a3,4
    80003312:	fc040613          	addi	a2,s0,-64
    80003316:	fc843583          	ld	a1,-56(s0)
    8000331a:	6ca8                	ld	a0,88(s1)
    8000331c:	ffffe097          	auipc	ra,0xffffe
    80003320:	56a080e7          	jalr	1386(ra) # 80001886 <copyout>
    80003324:	00054a63          	bltz	a0,80003338 <sys_waitx+0x98>
    return -1;
  return ret;
    80003328:	87ca                	mv	a5,s2
}
    8000332a:	853e                	mv	a0,a5
    8000332c:	70e2                	ld	ra,56(sp)
    8000332e:	7442                	ld	s0,48(sp)
    80003330:	74a2                	ld	s1,40(sp)
    80003332:	7902                	ld	s2,32(sp)
    80003334:	6121                	addi	sp,sp,64
    80003336:	8082                	ret
    return -1;
    80003338:	57fd                	li	a5,-1
    8000333a:	bfc5                	j	8000332a <sys_waitx+0x8a>

000000008000333c <sys_get_fault_counts>:

uint64
sys_get_fault_counts(void)
{
    8000333c:	1141                	addi	sp,sp,-16
    8000333e:	e422                	sd	s0,8(sp)
    80003340:	0800                	addi	s0,sp,16
    //printf("Total Page Fault Count: %d\n", total_fault_count);
    //printf("Copy-On-Write Page Fault Count: %d\n", cow_fault_count);

    return cow_fault_count; 
}
    80003342:	00005517          	auipc	a0,0x5
    80003346:	5ce52503          	lw	a0,1486(a0) # 80008910 <cow_fault_count>
    8000334a:	6422                	ld	s0,8(sp)
    8000334c:	0141                	addi	sp,sp,16
    8000334e:	8082                	ret

0000000080003350 <sys_get_total_fault_counts>:

uint64
sys_get_total_fault_counts(void)
{
    80003350:	1141                	addi	sp,sp,-16
    80003352:	e422                	sd	s0,8(sp)
    80003354:	0800                	addi	s0,sp,16
    //printf("Total Page Fault Count: %d\n", total_fault_count);
    //printf("Copy-On-Write Page Fault Count: %d\n", cow_fault_count);

    return total_fault_count; 
}
    80003356:	00005517          	auipc	a0,0x5
    8000335a:	5be52503          	lw	a0,1470(a0) # 80008914 <total_fault_count>
    8000335e:	6422                	ld	s0,8(sp)
    80003360:	0141                	addi	sp,sp,16
    80003362:	8082                	ret

0000000080003364 <sys_get_cow_faults>:
// sysproc.c
uint64
sys_get_cow_faults(void)
{
    80003364:	1141                	addi	sp,sp,-16
    80003366:	e406                	sd	ra,8(sp)
    80003368:	e022                	sd	s0,0(sp)
    8000336a:	0800                	addi	s0,sp,16
    struct proc *p = myproc();  // Get the current process
    8000336c:	fffff097          	auipc	ra,0xfffff
    80003370:	8ca080e7          	jalr	-1846(ra) # 80001c36 <myproc>
    return p->cow_page_faults;  // Return the COW page fault count
}
    80003374:	4108                	lw	a0,0(a0)
    80003376:	60a2                	ld	ra,8(sp)
    80003378:	6402                	ld	s0,0(sp)
    8000337a:	0141                	addi	sp,sp,16
    8000337c:	8082                	ret

000000008000337e <binit>:
  struct buf head;
} bcache;

void
binit(void)
{
    8000337e:	7179                	addi	sp,sp,-48
    80003380:	f406                	sd	ra,40(sp)
    80003382:	f022                	sd	s0,32(sp)
    80003384:	ec26                	sd	s1,24(sp)
    80003386:	e84a                	sd	s2,16(sp)
    80003388:	e44e                	sd	s3,8(sp)
    8000338a:	e052                	sd	s4,0(sp)
    8000338c:	1800                	addi	s0,sp,48
  struct buf *b;

  initlock(&bcache.lock, "bcache");
    8000338e:	00005597          	auipc	a1,0x5
    80003392:	09258593          	addi	a1,a1,146 # 80008420 <etext+0x420>
    80003396:	00234517          	auipc	a0,0x234
    8000339a:	c3250513          	addi	a0,a0,-974 # 80236fc8 <bcache>
    8000339e:	ffffe097          	auipc	ra,0xffffe
    800033a2:	940080e7          	jalr	-1728(ra) # 80000cde <initlock>

  // Create linked list of buffers
  bcache.head.prev = &bcache.head;
    800033a6:	0023c797          	auipc	a5,0x23c
    800033aa:	c2278793          	addi	a5,a5,-990 # 8023efc8 <bcache+0x8000>
    800033ae:	0023c717          	auipc	a4,0x23c
    800033b2:	e8270713          	addi	a4,a4,-382 # 8023f230 <bcache+0x8268>
    800033b6:	2ae7b823          	sd	a4,688(a5)
  bcache.head.next = &bcache.head;
    800033ba:	2ae7bc23          	sd	a4,696(a5)
  for(b = bcache.buf; b < bcache.buf+NBUF; b++){
    800033be:	00234497          	auipc	s1,0x234
    800033c2:	c2248493          	addi	s1,s1,-990 # 80236fe0 <bcache+0x18>
    b->next = bcache.head.next;
    800033c6:	893e                	mv	s2,a5
    b->prev = &bcache.head;
    800033c8:	89ba                	mv	s3,a4
    initsleeplock(&b->lock, "buffer");
    800033ca:	00005a17          	auipc	s4,0x5
    800033ce:	05ea0a13          	addi	s4,s4,94 # 80008428 <etext+0x428>
    b->next = bcache.head.next;
    800033d2:	2b893783          	ld	a5,696(s2)
    800033d6:	e8bc                	sd	a5,80(s1)
    b->prev = &bcache.head;
    800033d8:	0534b423          	sd	s3,72(s1)
    initsleeplock(&b->lock, "buffer");
    800033dc:	85d2                	mv	a1,s4
    800033de:	01048513          	addi	a0,s1,16
    800033e2:	00001097          	auipc	ra,0x1
    800033e6:	4e8080e7          	jalr	1256(ra) # 800048ca <initsleeplock>
    bcache.head.next->prev = b;
    800033ea:	2b893783          	ld	a5,696(s2)
    800033ee:	e7a4                	sd	s1,72(a5)
    bcache.head.next = b;
    800033f0:	2a993c23          	sd	s1,696(s2)
  for(b = bcache.buf; b < bcache.buf+NBUF; b++){
    800033f4:	45848493          	addi	s1,s1,1112
    800033f8:	fd349de3          	bne	s1,s3,800033d2 <binit+0x54>
  }
}
    800033fc:	70a2                	ld	ra,40(sp)
    800033fe:	7402                	ld	s0,32(sp)
    80003400:	64e2                	ld	s1,24(sp)
    80003402:	6942                	ld	s2,16(sp)
    80003404:	69a2                	ld	s3,8(sp)
    80003406:	6a02                	ld	s4,0(sp)
    80003408:	6145                	addi	sp,sp,48
    8000340a:	8082                	ret

000000008000340c <bread>:
}

// Return a locked buf with the contents of the indicated block.
struct buf*
bread(uint dev, uint blockno)
{
    8000340c:	7179                	addi	sp,sp,-48
    8000340e:	f406                	sd	ra,40(sp)
    80003410:	f022                	sd	s0,32(sp)
    80003412:	ec26                	sd	s1,24(sp)
    80003414:	e84a                	sd	s2,16(sp)
    80003416:	e44e                	sd	s3,8(sp)
    80003418:	1800                	addi	s0,sp,48
    8000341a:	892a                	mv	s2,a0
    8000341c:	89ae                	mv	s3,a1
  acquire(&bcache.lock);
    8000341e:	00234517          	auipc	a0,0x234
    80003422:	baa50513          	addi	a0,a0,-1110 # 80236fc8 <bcache>
    80003426:	ffffe097          	auipc	ra,0xffffe
    8000342a:	948080e7          	jalr	-1720(ra) # 80000d6e <acquire>
  for(b = bcache.head.next; b != &bcache.head; b = b->next){
    8000342e:	0023c497          	auipc	s1,0x23c
    80003432:	e524b483          	ld	s1,-430(s1) # 8023f280 <bcache+0x82b8>
    80003436:	0023c797          	auipc	a5,0x23c
    8000343a:	dfa78793          	addi	a5,a5,-518 # 8023f230 <bcache+0x8268>
    8000343e:	02f48f63          	beq	s1,a5,8000347c <bread+0x70>
    80003442:	873e                	mv	a4,a5
    80003444:	a021                	j	8000344c <bread+0x40>
    80003446:	68a4                	ld	s1,80(s1)
    80003448:	02e48a63          	beq	s1,a4,8000347c <bread+0x70>
    if(b->dev == dev && b->blockno == blockno){
    8000344c:	449c                	lw	a5,8(s1)
    8000344e:	ff279ce3          	bne	a5,s2,80003446 <bread+0x3a>
    80003452:	44dc                	lw	a5,12(s1)
    80003454:	ff3799e3          	bne	a5,s3,80003446 <bread+0x3a>
      b->refcnt++;
    80003458:	40bc                	lw	a5,64(s1)
    8000345a:	2785                	addiw	a5,a5,1
    8000345c:	c0bc                	sw	a5,64(s1)
      release(&bcache.lock);
    8000345e:	00234517          	auipc	a0,0x234
    80003462:	b6a50513          	addi	a0,a0,-1174 # 80236fc8 <bcache>
    80003466:	ffffe097          	auipc	ra,0xffffe
    8000346a:	9bc080e7          	jalr	-1604(ra) # 80000e22 <release>
      acquiresleep(&b->lock);
    8000346e:	01048513          	addi	a0,s1,16
    80003472:	00001097          	auipc	ra,0x1
    80003476:	492080e7          	jalr	1170(ra) # 80004904 <acquiresleep>
      return b;
    8000347a:	a8b9                	j	800034d8 <bread+0xcc>
  for(b = bcache.head.prev; b != &bcache.head; b = b->prev){
    8000347c:	0023c497          	auipc	s1,0x23c
    80003480:	dfc4b483          	ld	s1,-516(s1) # 8023f278 <bcache+0x82b0>
    80003484:	0023c797          	auipc	a5,0x23c
    80003488:	dac78793          	addi	a5,a5,-596 # 8023f230 <bcache+0x8268>
    8000348c:	00f48863          	beq	s1,a5,8000349c <bread+0x90>
    80003490:	873e                	mv	a4,a5
    if(b->refcnt == 0) {
    80003492:	40bc                	lw	a5,64(s1)
    80003494:	cf81                	beqz	a5,800034ac <bread+0xa0>
  for(b = bcache.head.prev; b != &bcache.head; b = b->prev){
    80003496:	64a4                	ld	s1,72(s1)
    80003498:	fee49de3          	bne	s1,a4,80003492 <bread+0x86>
  panic("bget: no buffers");
    8000349c:	00005517          	auipc	a0,0x5
    800034a0:	f9450513          	addi	a0,a0,-108 # 80008430 <etext+0x430>
    800034a4:	ffffd097          	auipc	ra,0xffffd
    800034a8:	0bc080e7          	jalr	188(ra) # 80000560 <panic>
      b->dev = dev;
    800034ac:	0124a423          	sw	s2,8(s1)
      b->blockno = blockno;
    800034b0:	0134a623          	sw	s3,12(s1)
      b->valid = 0;
    800034b4:	0004a023          	sw	zero,0(s1)
      b->refcnt = 1;
    800034b8:	4785                	li	a5,1
    800034ba:	c0bc                	sw	a5,64(s1)
      release(&bcache.lock);
    800034bc:	00234517          	auipc	a0,0x234
    800034c0:	b0c50513          	addi	a0,a0,-1268 # 80236fc8 <bcache>
    800034c4:	ffffe097          	auipc	ra,0xffffe
    800034c8:	95e080e7          	jalr	-1698(ra) # 80000e22 <release>
      acquiresleep(&b->lock);
    800034cc:	01048513          	addi	a0,s1,16
    800034d0:	00001097          	auipc	ra,0x1
    800034d4:	434080e7          	jalr	1076(ra) # 80004904 <acquiresleep>
  struct buf *b;

  b = bget(dev, blockno);
  if(!b->valid) {
    800034d8:	409c                	lw	a5,0(s1)
    800034da:	cb89                	beqz	a5,800034ec <bread+0xe0>
    virtio_disk_rw(b, 0);
    b->valid = 1;
  }
  return b;
}
    800034dc:	8526                	mv	a0,s1
    800034de:	70a2                	ld	ra,40(sp)
    800034e0:	7402                	ld	s0,32(sp)
    800034e2:	64e2                	ld	s1,24(sp)
    800034e4:	6942                	ld	s2,16(sp)
    800034e6:	69a2                	ld	s3,8(sp)
    800034e8:	6145                	addi	sp,sp,48
    800034ea:	8082                	ret
    virtio_disk_rw(b, 0);
    800034ec:	4581                	li	a1,0
    800034ee:	8526                	mv	a0,s1
    800034f0:	00003097          	auipc	ra,0x3
    800034f4:	0f8080e7          	jalr	248(ra) # 800065e8 <virtio_disk_rw>
    b->valid = 1;
    800034f8:	4785                	li	a5,1
    800034fa:	c09c                	sw	a5,0(s1)
  return b;
    800034fc:	b7c5                	j	800034dc <bread+0xd0>

00000000800034fe <bwrite>:

// Write b's contents to disk.  Must be locked.
void
bwrite(struct buf *b)
{
    800034fe:	1101                	addi	sp,sp,-32
    80003500:	ec06                	sd	ra,24(sp)
    80003502:	e822                	sd	s0,16(sp)
    80003504:	e426                	sd	s1,8(sp)
    80003506:	1000                	addi	s0,sp,32
    80003508:	84aa                	mv	s1,a0
  if(!holdingsleep(&b->lock))
    8000350a:	0541                	addi	a0,a0,16
    8000350c:	00001097          	auipc	ra,0x1
    80003510:	492080e7          	jalr	1170(ra) # 8000499e <holdingsleep>
    80003514:	cd01                	beqz	a0,8000352c <bwrite+0x2e>
    panic("bwrite");
  virtio_disk_rw(b, 1);
    80003516:	4585                	li	a1,1
    80003518:	8526                	mv	a0,s1
    8000351a:	00003097          	auipc	ra,0x3
    8000351e:	0ce080e7          	jalr	206(ra) # 800065e8 <virtio_disk_rw>
}
    80003522:	60e2                	ld	ra,24(sp)
    80003524:	6442                	ld	s0,16(sp)
    80003526:	64a2                	ld	s1,8(sp)
    80003528:	6105                	addi	sp,sp,32
    8000352a:	8082                	ret
    panic("bwrite");
    8000352c:	00005517          	auipc	a0,0x5
    80003530:	f1c50513          	addi	a0,a0,-228 # 80008448 <etext+0x448>
    80003534:	ffffd097          	auipc	ra,0xffffd
    80003538:	02c080e7          	jalr	44(ra) # 80000560 <panic>

000000008000353c <brelse>:

// Release a locked buffer.
// Move to the head of the most-recently-used list.
void
brelse(struct buf *b)
{
    8000353c:	1101                	addi	sp,sp,-32
    8000353e:	ec06                	sd	ra,24(sp)
    80003540:	e822                	sd	s0,16(sp)
    80003542:	e426                	sd	s1,8(sp)
    80003544:	e04a                	sd	s2,0(sp)
    80003546:	1000                	addi	s0,sp,32
    80003548:	84aa                	mv	s1,a0
  if(!holdingsleep(&b->lock))
    8000354a:	01050913          	addi	s2,a0,16
    8000354e:	854a                	mv	a0,s2
    80003550:	00001097          	auipc	ra,0x1
    80003554:	44e080e7          	jalr	1102(ra) # 8000499e <holdingsleep>
    80003558:	c925                	beqz	a0,800035c8 <brelse+0x8c>
    panic("brelse");

  releasesleep(&b->lock);
    8000355a:	854a                	mv	a0,s2
    8000355c:	00001097          	auipc	ra,0x1
    80003560:	3fe080e7          	jalr	1022(ra) # 8000495a <releasesleep>

  acquire(&bcache.lock);
    80003564:	00234517          	auipc	a0,0x234
    80003568:	a6450513          	addi	a0,a0,-1436 # 80236fc8 <bcache>
    8000356c:	ffffe097          	auipc	ra,0xffffe
    80003570:	802080e7          	jalr	-2046(ra) # 80000d6e <acquire>
  b->refcnt--;
    80003574:	40bc                	lw	a5,64(s1)
    80003576:	37fd                	addiw	a5,a5,-1
    80003578:	0007871b          	sext.w	a4,a5
    8000357c:	c0bc                	sw	a5,64(s1)
  if (b->refcnt == 0) {
    8000357e:	e71d                	bnez	a4,800035ac <brelse+0x70>
    // no one is waiting for it.
    b->next->prev = b->prev;
    80003580:	68b8                	ld	a4,80(s1)
    80003582:	64bc                	ld	a5,72(s1)
    80003584:	e73c                	sd	a5,72(a4)
    b->prev->next = b->next;
    80003586:	68b8                	ld	a4,80(s1)
    80003588:	ebb8                	sd	a4,80(a5)
    b->next = bcache.head.next;
    8000358a:	0023c797          	auipc	a5,0x23c
    8000358e:	a3e78793          	addi	a5,a5,-1474 # 8023efc8 <bcache+0x8000>
    80003592:	2b87b703          	ld	a4,696(a5)
    80003596:	e8b8                	sd	a4,80(s1)
    b->prev = &bcache.head;
    80003598:	0023c717          	auipc	a4,0x23c
    8000359c:	c9870713          	addi	a4,a4,-872 # 8023f230 <bcache+0x8268>
    800035a0:	e4b8                	sd	a4,72(s1)
    bcache.head.next->prev = b;
    800035a2:	2b87b703          	ld	a4,696(a5)
    800035a6:	e724                	sd	s1,72(a4)
    bcache.head.next = b;
    800035a8:	2a97bc23          	sd	s1,696(a5)
  }
  
  release(&bcache.lock);
    800035ac:	00234517          	auipc	a0,0x234
    800035b0:	a1c50513          	addi	a0,a0,-1508 # 80236fc8 <bcache>
    800035b4:	ffffe097          	auipc	ra,0xffffe
    800035b8:	86e080e7          	jalr	-1938(ra) # 80000e22 <release>
}
    800035bc:	60e2                	ld	ra,24(sp)
    800035be:	6442                	ld	s0,16(sp)
    800035c0:	64a2                	ld	s1,8(sp)
    800035c2:	6902                	ld	s2,0(sp)
    800035c4:	6105                	addi	sp,sp,32
    800035c6:	8082                	ret
    panic("brelse");
    800035c8:	00005517          	auipc	a0,0x5
    800035cc:	e8850513          	addi	a0,a0,-376 # 80008450 <etext+0x450>
    800035d0:	ffffd097          	auipc	ra,0xffffd
    800035d4:	f90080e7          	jalr	-112(ra) # 80000560 <panic>

00000000800035d8 <bpin>:

void
bpin(struct buf *b) {
    800035d8:	1101                	addi	sp,sp,-32
    800035da:	ec06                	sd	ra,24(sp)
    800035dc:	e822                	sd	s0,16(sp)
    800035de:	e426                	sd	s1,8(sp)
    800035e0:	1000                	addi	s0,sp,32
    800035e2:	84aa                	mv	s1,a0
  acquire(&bcache.lock);
    800035e4:	00234517          	auipc	a0,0x234
    800035e8:	9e450513          	addi	a0,a0,-1564 # 80236fc8 <bcache>
    800035ec:	ffffd097          	auipc	ra,0xffffd
    800035f0:	782080e7          	jalr	1922(ra) # 80000d6e <acquire>
  b->refcnt++;
    800035f4:	40bc                	lw	a5,64(s1)
    800035f6:	2785                	addiw	a5,a5,1
    800035f8:	c0bc                	sw	a5,64(s1)
  release(&bcache.lock);
    800035fa:	00234517          	auipc	a0,0x234
    800035fe:	9ce50513          	addi	a0,a0,-1586 # 80236fc8 <bcache>
    80003602:	ffffe097          	auipc	ra,0xffffe
    80003606:	820080e7          	jalr	-2016(ra) # 80000e22 <release>
}
    8000360a:	60e2                	ld	ra,24(sp)
    8000360c:	6442                	ld	s0,16(sp)
    8000360e:	64a2                	ld	s1,8(sp)
    80003610:	6105                	addi	sp,sp,32
    80003612:	8082                	ret

0000000080003614 <bunpin>:

void
bunpin(struct buf *b) {
    80003614:	1101                	addi	sp,sp,-32
    80003616:	ec06                	sd	ra,24(sp)
    80003618:	e822                	sd	s0,16(sp)
    8000361a:	e426                	sd	s1,8(sp)
    8000361c:	1000                	addi	s0,sp,32
    8000361e:	84aa                	mv	s1,a0
  acquire(&bcache.lock);
    80003620:	00234517          	auipc	a0,0x234
    80003624:	9a850513          	addi	a0,a0,-1624 # 80236fc8 <bcache>
    80003628:	ffffd097          	auipc	ra,0xffffd
    8000362c:	746080e7          	jalr	1862(ra) # 80000d6e <acquire>
  b->refcnt--;
    80003630:	40bc                	lw	a5,64(s1)
    80003632:	37fd                	addiw	a5,a5,-1
    80003634:	c0bc                	sw	a5,64(s1)
  release(&bcache.lock);
    80003636:	00234517          	auipc	a0,0x234
    8000363a:	99250513          	addi	a0,a0,-1646 # 80236fc8 <bcache>
    8000363e:	ffffd097          	auipc	ra,0xffffd
    80003642:	7e4080e7          	jalr	2020(ra) # 80000e22 <release>
}
    80003646:	60e2                	ld	ra,24(sp)
    80003648:	6442                	ld	s0,16(sp)
    8000364a:	64a2                	ld	s1,8(sp)
    8000364c:	6105                	addi	sp,sp,32
    8000364e:	8082                	ret

0000000080003650 <bfree>:
}

// Free a disk block.
static void
bfree(int dev, uint b)
{
    80003650:	1101                	addi	sp,sp,-32
    80003652:	ec06                	sd	ra,24(sp)
    80003654:	e822                	sd	s0,16(sp)
    80003656:	e426                	sd	s1,8(sp)
    80003658:	e04a                	sd	s2,0(sp)
    8000365a:	1000                	addi	s0,sp,32
    8000365c:	84ae                	mv	s1,a1
  struct buf *bp;
  int bi, m;

  bp = bread(dev, BBLOCK(b, sb));
    8000365e:	00d5d59b          	srliw	a1,a1,0xd
    80003662:	0023c797          	auipc	a5,0x23c
    80003666:	0427a783          	lw	a5,66(a5) # 8023f6a4 <sb+0x1c>
    8000366a:	9dbd                	addw	a1,a1,a5
    8000366c:	00000097          	auipc	ra,0x0
    80003670:	da0080e7          	jalr	-608(ra) # 8000340c <bread>
  bi = b % BPB;
  m = 1 << (bi % 8);
    80003674:	0074f713          	andi	a4,s1,7
    80003678:	4785                	li	a5,1
    8000367a:	00e797bb          	sllw	a5,a5,a4
  if((bp->data[bi/8] & m) == 0)
    8000367e:	14ce                	slli	s1,s1,0x33
    80003680:	90d9                	srli	s1,s1,0x36
    80003682:	00950733          	add	a4,a0,s1
    80003686:	05874703          	lbu	a4,88(a4)
    8000368a:	00e7f6b3          	and	a3,a5,a4
    8000368e:	c69d                	beqz	a3,800036bc <bfree+0x6c>
    80003690:	892a                	mv	s2,a0
    panic("freeing free block");
  bp->data[bi/8] &= ~m;
    80003692:	94aa                	add	s1,s1,a0
    80003694:	fff7c793          	not	a5,a5
    80003698:	8f7d                	and	a4,a4,a5
    8000369a:	04e48c23          	sb	a4,88(s1)
  log_write(bp);
    8000369e:	00001097          	auipc	ra,0x1
    800036a2:	148080e7          	jalr	328(ra) # 800047e6 <log_write>
  brelse(bp);
    800036a6:	854a                	mv	a0,s2
    800036a8:	00000097          	auipc	ra,0x0
    800036ac:	e94080e7          	jalr	-364(ra) # 8000353c <brelse>
}
    800036b0:	60e2                	ld	ra,24(sp)
    800036b2:	6442                	ld	s0,16(sp)
    800036b4:	64a2                	ld	s1,8(sp)
    800036b6:	6902                	ld	s2,0(sp)
    800036b8:	6105                	addi	sp,sp,32
    800036ba:	8082                	ret
    panic("freeing free block");
    800036bc:	00005517          	auipc	a0,0x5
    800036c0:	d9c50513          	addi	a0,a0,-612 # 80008458 <etext+0x458>
    800036c4:	ffffd097          	auipc	ra,0xffffd
    800036c8:	e9c080e7          	jalr	-356(ra) # 80000560 <panic>

00000000800036cc <balloc>:
{
    800036cc:	711d                	addi	sp,sp,-96
    800036ce:	ec86                	sd	ra,88(sp)
    800036d0:	e8a2                	sd	s0,80(sp)
    800036d2:	e4a6                	sd	s1,72(sp)
    800036d4:	1080                	addi	s0,sp,96
  for(b = 0; b < sb.size; b += BPB){
    800036d6:	0023c797          	auipc	a5,0x23c
    800036da:	fb67a783          	lw	a5,-74(a5) # 8023f68c <sb+0x4>
    800036de:	10078f63          	beqz	a5,800037fc <balloc+0x130>
    800036e2:	e0ca                	sd	s2,64(sp)
    800036e4:	fc4e                	sd	s3,56(sp)
    800036e6:	f852                	sd	s4,48(sp)
    800036e8:	f456                	sd	s5,40(sp)
    800036ea:	f05a                	sd	s6,32(sp)
    800036ec:	ec5e                	sd	s7,24(sp)
    800036ee:	e862                	sd	s8,16(sp)
    800036f0:	e466                	sd	s9,8(sp)
    800036f2:	8baa                	mv	s7,a0
    800036f4:	4a81                	li	s5,0
    bp = bread(dev, BBLOCK(b, sb));
    800036f6:	0023cb17          	auipc	s6,0x23c
    800036fa:	f92b0b13          	addi	s6,s6,-110 # 8023f688 <sb>
    for(bi = 0; bi < BPB && b + bi < sb.size; bi++){
    800036fe:	4c01                	li	s8,0
      m = 1 << (bi % 8);
    80003700:	4985                	li	s3,1
    for(bi = 0; bi < BPB && b + bi < sb.size; bi++){
    80003702:	6a09                	lui	s4,0x2
  for(b = 0; b < sb.size; b += BPB){
    80003704:	6c89                	lui	s9,0x2
    80003706:	a061                	j	8000378e <balloc+0xc2>
        bp->data[bi/8] |= m;  // Mark block in use.
    80003708:	97ca                	add	a5,a5,s2
    8000370a:	8e55                	or	a2,a2,a3
    8000370c:	04c78c23          	sb	a2,88(a5)
        log_write(bp);
    80003710:	854a                	mv	a0,s2
    80003712:	00001097          	auipc	ra,0x1
    80003716:	0d4080e7          	jalr	212(ra) # 800047e6 <log_write>
        brelse(bp);
    8000371a:	854a                	mv	a0,s2
    8000371c:	00000097          	auipc	ra,0x0
    80003720:	e20080e7          	jalr	-480(ra) # 8000353c <brelse>
  bp = bread(dev, bno);
    80003724:	85a6                	mv	a1,s1
    80003726:	855e                	mv	a0,s7
    80003728:	00000097          	auipc	ra,0x0
    8000372c:	ce4080e7          	jalr	-796(ra) # 8000340c <bread>
    80003730:	892a                	mv	s2,a0
  memset(bp->data, 0, BSIZE);
    80003732:	40000613          	li	a2,1024
    80003736:	4581                	li	a1,0
    80003738:	05850513          	addi	a0,a0,88
    8000373c:	ffffd097          	auipc	ra,0xffffd
    80003740:	72e080e7          	jalr	1838(ra) # 80000e6a <memset>
  log_write(bp);
    80003744:	854a                	mv	a0,s2
    80003746:	00001097          	auipc	ra,0x1
    8000374a:	0a0080e7          	jalr	160(ra) # 800047e6 <log_write>
  brelse(bp);
    8000374e:	854a                	mv	a0,s2
    80003750:	00000097          	auipc	ra,0x0
    80003754:	dec080e7          	jalr	-532(ra) # 8000353c <brelse>
}
    80003758:	6906                	ld	s2,64(sp)
    8000375a:	79e2                	ld	s3,56(sp)
    8000375c:	7a42                	ld	s4,48(sp)
    8000375e:	7aa2                	ld	s5,40(sp)
    80003760:	7b02                	ld	s6,32(sp)
    80003762:	6be2                	ld	s7,24(sp)
    80003764:	6c42                	ld	s8,16(sp)
    80003766:	6ca2                	ld	s9,8(sp)
}
    80003768:	8526                	mv	a0,s1
    8000376a:	60e6                	ld	ra,88(sp)
    8000376c:	6446                	ld	s0,80(sp)
    8000376e:	64a6                	ld	s1,72(sp)
    80003770:	6125                	addi	sp,sp,96
    80003772:	8082                	ret
    brelse(bp);
    80003774:	854a                	mv	a0,s2
    80003776:	00000097          	auipc	ra,0x0
    8000377a:	dc6080e7          	jalr	-570(ra) # 8000353c <brelse>
  for(b = 0; b < sb.size; b += BPB){
    8000377e:	015c87bb          	addw	a5,s9,s5
    80003782:	00078a9b          	sext.w	s5,a5
    80003786:	004b2703          	lw	a4,4(s6)
    8000378a:	06eaf163          	bgeu	s5,a4,800037ec <balloc+0x120>
    bp = bread(dev, BBLOCK(b, sb));
    8000378e:	41fad79b          	sraiw	a5,s5,0x1f
    80003792:	0137d79b          	srliw	a5,a5,0x13
    80003796:	015787bb          	addw	a5,a5,s5
    8000379a:	40d7d79b          	sraiw	a5,a5,0xd
    8000379e:	01cb2583          	lw	a1,28(s6)
    800037a2:	9dbd                	addw	a1,a1,a5
    800037a4:	855e                	mv	a0,s7
    800037a6:	00000097          	auipc	ra,0x0
    800037aa:	c66080e7          	jalr	-922(ra) # 8000340c <bread>
    800037ae:	892a                	mv	s2,a0
    for(bi = 0; bi < BPB && b + bi < sb.size; bi++){
    800037b0:	004b2503          	lw	a0,4(s6)
    800037b4:	000a849b          	sext.w	s1,s5
    800037b8:	8762                	mv	a4,s8
    800037ba:	faa4fde3          	bgeu	s1,a0,80003774 <balloc+0xa8>
      m = 1 << (bi % 8);
    800037be:	00777693          	andi	a3,a4,7
    800037c2:	00d996bb          	sllw	a3,s3,a3
      if((bp->data[bi/8] & m) == 0){  // Is block free?
    800037c6:	41f7579b          	sraiw	a5,a4,0x1f
    800037ca:	01d7d79b          	srliw	a5,a5,0x1d
    800037ce:	9fb9                	addw	a5,a5,a4
    800037d0:	4037d79b          	sraiw	a5,a5,0x3
    800037d4:	00f90633          	add	a2,s2,a5
    800037d8:	05864603          	lbu	a2,88(a2)
    800037dc:	00c6f5b3          	and	a1,a3,a2
    800037e0:	d585                	beqz	a1,80003708 <balloc+0x3c>
    for(bi = 0; bi < BPB && b + bi < sb.size; bi++){
    800037e2:	2705                	addiw	a4,a4,1
    800037e4:	2485                	addiw	s1,s1,1
    800037e6:	fd471ae3          	bne	a4,s4,800037ba <balloc+0xee>
    800037ea:	b769                	j	80003774 <balloc+0xa8>
    800037ec:	6906                	ld	s2,64(sp)
    800037ee:	79e2                	ld	s3,56(sp)
    800037f0:	7a42                	ld	s4,48(sp)
    800037f2:	7aa2                	ld	s5,40(sp)
    800037f4:	7b02                	ld	s6,32(sp)
    800037f6:	6be2                	ld	s7,24(sp)
    800037f8:	6c42                	ld	s8,16(sp)
    800037fa:	6ca2                	ld	s9,8(sp)
  printf("balloc: out of blocks\n");
    800037fc:	00005517          	auipc	a0,0x5
    80003800:	c7450513          	addi	a0,a0,-908 # 80008470 <etext+0x470>
    80003804:	ffffd097          	auipc	ra,0xffffd
    80003808:	da6080e7          	jalr	-602(ra) # 800005aa <printf>
  return 0;
    8000380c:	4481                	li	s1,0
    8000380e:	bfa9                	j	80003768 <balloc+0x9c>

0000000080003810 <bmap>:
// Return the disk block address of the nth block in inode ip.
// If there is no such block, bmap allocates one.
// returns 0 if out of disk space.
static uint
bmap(struct inode *ip, uint bn)
{
    80003810:	7179                	addi	sp,sp,-48
    80003812:	f406                	sd	ra,40(sp)
    80003814:	f022                	sd	s0,32(sp)
    80003816:	ec26                	sd	s1,24(sp)
    80003818:	e84a                	sd	s2,16(sp)
    8000381a:	e44e                	sd	s3,8(sp)
    8000381c:	1800                	addi	s0,sp,48
    8000381e:	89aa                	mv	s3,a0
  uint addr, *a;
  struct buf *bp;

  if(bn < NDIRECT){
    80003820:	47ad                	li	a5,11
    80003822:	02b7e863          	bltu	a5,a1,80003852 <bmap+0x42>
    if((addr = ip->addrs[bn]) == 0){
    80003826:	02059793          	slli	a5,a1,0x20
    8000382a:	01e7d593          	srli	a1,a5,0x1e
    8000382e:	00b504b3          	add	s1,a0,a1
    80003832:	0504a903          	lw	s2,80(s1)
    80003836:	08091263          	bnez	s2,800038ba <bmap+0xaa>
      addr = balloc(ip->dev);
    8000383a:	4108                	lw	a0,0(a0)
    8000383c:	00000097          	auipc	ra,0x0
    80003840:	e90080e7          	jalr	-368(ra) # 800036cc <balloc>
    80003844:	0005091b          	sext.w	s2,a0
      if(addr == 0)
    80003848:	06090963          	beqz	s2,800038ba <bmap+0xaa>
        return 0;
      ip->addrs[bn] = addr;
    8000384c:	0524a823          	sw	s2,80(s1)
    80003850:	a0ad                	j	800038ba <bmap+0xaa>
    }
    return addr;
  }
  bn -= NDIRECT;
    80003852:	ff45849b          	addiw	s1,a1,-12
    80003856:	0004871b          	sext.w	a4,s1

  if(bn < NINDIRECT){
    8000385a:	0ff00793          	li	a5,255
    8000385e:	08e7e863          	bltu	a5,a4,800038ee <bmap+0xde>
    // Load indirect block, allocating if necessary.
    if((addr = ip->addrs[NDIRECT]) == 0){
    80003862:	08052903          	lw	s2,128(a0)
    80003866:	00091f63          	bnez	s2,80003884 <bmap+0x74>
      addr = balloc(ip->dev);
    8000386a:	4108                	lw	a0,0(a0)
    8000386c:	00000097          	auipc	ra,0x0
    80003870:	e60080e7          	jalr	-416(ra) # 800036cc <balloc>
    80003874:	0005091b          	sext.w	s2,a0
      if(addr == 0)
    80003878:	04090163          	beqz	s2,800038ba <bmap+0xaa>
    8000387c:	e052                	sd	s4,0(sp)
        return 0;
      ip->addrs[NDIRECT] = addr;
    8000387e:	0929a023          	sw	s2,128(s3)
    80003882:	a011                	j	80003886 <bmap+0x76>
    80003884:	e052                	sd	s4,0(sp)
    }
    bp = bread(ip->dev, addr);
    80003886:	85ca                	mv	a1,s2
    80003888:	0009a503          	lw	a0,0(s3)
    8000388c:	00000097          	auipc	ra,0x0
    80003890:	b80080e7          	jalr	-1152(ra) # 8000340c <bread>
    80003894:	8a2a                	mv	s4,a0
    a = (uint*)bp->data;
    80003896:	05850793          	addi	a5,a0,88
    if((addr = a[bn]) == 0){
    8000389a:	02049713          	slli	a4,s1,0x20
    8000389e:	01e75593          	srli	a1,a4,0x1e
    800038a2:	00b784b3          	add	s1,a5,a1
    800038a6:	0004a903          	lw	s2,0(s1)
    800038aa:	02090063          	beqz	s2,800038ca <bmap+0xba>
      if(addr){
        a[bn] = addr;
        log_write(bp);
      }
    }
    brelse(bp);
    800038ae:	8552                	mv	a0,s4
    800038b0:	00000097          	auipc	ra,0x0
    800038b4:	c8c080e7          	jalr	-884(ra) # 8000353c <brelse>
    return addr;
    800038b8:	6a02                	ld	s4,0(sp)
  }

  panic("bmap: out of range");
}
    800038ba:	854a                	mv	a0,s2
    800038bc:	70a2                	ld	ra,40(sp)
    800038be:	7402                	ld	s0,32(sp)
    800038c0:	64e2                	ld	s1,24(sp)
    800038c2:	6942                	ld	s2,16(sp)
    800038c4:	69a2                	ld	s3,8(sp)
    800038c6:	6145                	addi	sp,sp,48
    800038c8:	8082                	ret
      addr = balloc(ip->dev);
    800038ca:	0009a503          	lw	a0,0(s3)
    800038ce:	00000097          	auipc	ra,0x0
    800038d2:	dfe080e7          	jalr	-514(ra) # 800036cc <balloc>
    800038d6:	0005091b          	sext.w	s2,a0
      if(addr){
    800038da:	fc090ae3          	beqz	s2,800038ae <bmap+0x9e>
        a[bn] = addr;
    800038de:	0124a023          	sw	s2,0(s1)
        log_write(bp);
    800038e2:	8552                	mv	a0,s4
    800038e4:	00001097          	auipc	ra,0x1
    800038e8:	f02080e7          	jalr	-254(ra) # 800047e6 <log_write>
    800038ec:	b7c9                	j	800038ae <bmap+0x9e>
    800038ee:	e052                	sd	s4,0(sp)
  panic("bmap: out of range");
    800038f0:	00005517          	auipc	a0,0x5
    800038f4:	b9850513          	addi	a0,a0,-1128 # 80008488 <etext+0x488>
    800038f8:	ffffd097          	auipc	ra,0xffffd
    800038fc:	c68080e7          	jalr	-920(ra) # 80000560 <panic>

0000000080003900 <iget>:
{
    80003900:	7179                	addi	sp,sp,-48
    80003902:	f406                	sd	ra,40(sp)
    80003904:	f022                	sd	s0,32(sp)
    80003906:	ec26                	sd	s1,24(sp)
    80003908:	e84a                	sd	s2,16(sp)
    8000390a:	e44e                	sd	s3,8(sp)
    8000390c:	e052                	sd	s4,0(sp)
    8000390e:	1800                	addi	s0,sp,48
    80003910:	89aa                	mv	s3,a0
    80003912:	8a2e                	mv	s4,a1
  acquire(&itable.lock);
    80003914:	0023c517          	auipc	a0,0x23c
    80003918:	d9450513          	addi	a0,a0,-620 # 8023f6a8 <itable>
    8000391c:	ffffd097          	auipc	ra,0xffffd
    80003920:	452080e7          	jalr	1106(ra) # 80000d6e <acquire>
  empty = 0;
    80003924:	4901                	li	s2,0
  for(ip = &itable.inode[0]; ip < &itable.inode[NINODE]; ip++){
    80003926:	0023c497          	auipc	s1,0x23c
    8000392a:	d9a48493          	addi	s1,s1,-614 # 8023f6c0 <itable+0x18>
    8000392e:	0023e697          	auipc	a3,0x23e
    80003932:	82268693          	addi	a3,a3,-2014 # 80241150 <log>
    80003936:	a039                	j	80003944 <iget+0x44>
    if(empty == 0 && ip->ref == 0)    // Remember empty slot.
    80003938:	02090b63          	beqz	s2,8000396e <iget+0x6e>
  for(ip = &itable.inode[0]; ip < &itable.inode[NINODE]; ip++){
    8000393c:	08848493          	addi	s1,s1,136
    80003940:	02d48a63          	beq	s1,a3,80003974 <iget+0x74>
    if(ip->ref > 0 && ip->dev == dev && ip->inum == inum){
    80003944:	449c                	lw	a5,8(s1)
    80003946:	fef059e3          	blez	a5,80003938 <iget+0x38>
    8000394a:	4098                	lw	a4,0(s1)
    8000394c:	ff3716e3          	bne	a4,s3,80003938 <iget+0x38>
    80003950:	40d8                	lw	a4,4(s1)
    80003952:	ff4713e3          	bne	a4,s4,80003938 <iget+0x38>
      ip->ref++;
    80003956:	2785                	addiw	a5,a5,1
    80003958:	c49c                	sw	a5,8(s1)
      release(&itable.lock);
    8000395a:	0023c517          	auipc	a0,0x23c
    8000395e:	d4e50513          	addi	a0,a0,-690 # 8023f6a8 <itable>
    80003962:	ffffd097          	auipc	ra,0xffffd
    80003966:	4c0080e7          	jalr	1216(ra) # 80000e22 <release>
      return ip;
    8000396a:	8926                	mv	s2,s1
    8000396c:	a03d                	j	8000399a <iget+0x9a>
    if(empty == 0 && ip->ref == 0)    // Remember empty slot.
    8000396e:	f7f9                	bnez	a5,8000393c <iget+0x3c>
      empty = ip;
    80003970:	8926                	mv	s2,s1
    80003972:	b7e9                	j	8000393c <iget+0x3c>
  if(empty == 0)
    80003974:	02090c63          	beqz	s2,800039ac <iget+0xac>
  ip->dev = dev;
    80003978:	01392023          	sw	s3,0(s2)
  ip->inum = inum;
    8000397c:	01492223          	sw	s4,4(s2)
  ip->ref = 1;
    80003980:	4785                	li	a5,1
    80003982:	00f92423          	sw	a5,8(s2)
  ip->valid = 0;
    80003986:	04092023          	sw	zero,64(s2)
  release(&itable.lock);
    8000398a:	0023c517          	auipc	a0,0x23c
    8000398e:	d1e50513          	addi	a0,a0,-738 # 8023f6a8 <itable>
    80003992:	ffffd097          	auipc	ra,0xffffd
    80003996:	490080e7          	jalr	1168(ra) # 80000e22 <release>
}
    8000399a:	854a                	mv	a0,s2
    8000399c:	70a2                	ld	ra,40(sp)
    8000399e:	7402                	ld	s0,32(sp)
    800039a0:	64e2                	ld	s1,24(sp)
    800039a2:	6942                	ld	s2,16(sp)
    800039a4:	69a2                	ld	s3,8(sp)
    800039a6:	6a02                	ld	s4,0(sp)
    800039a8:	6145                	addi	sp,sp,48
    800039aa:	8082                	ret
    panic("iget: no inodes");
    800039ac:	00005517          	auipc	a0,0x5
    800039b0:	af450513          	addi	a0,a0,-1292 # 800084a0 <etext+0x4a0>
    800039b4:	ffffd097          	auipc	ra,0xffffd
    800039b8:	bac080e7          	jalr	-1108(ra) # 80000560 <panic>

00000000800039bc <fsinit>:
fsinit(int dev) {
    800039bc:	7179                	addi	sp,sp,-48
    800039be:	f406                	sd	ra,40(sp)
    800039c0:	f022                	sd	s0,32(sp)
    800039c2:	ec26                	sd	s1,24(sp)
    800039c4:	e84a                	sd	s2,16(sp)
    800039c6:	e44e                	sd	s3,8(sp)
    800039c8:	1800                	addi	s0,sp,48
    800039ca:	892a                	mv	s2,a0
  bp = bread(dev, 1);
    800039cc:	4585                	li	a1,1
    800039ce:	00000097          	auipc	ra,0x0
    800039d2:	a3e080e7          	jalr	-1474(ra) # 8000340c <bread>
    800039d6:	84aa                	mv	s1,a0
  memmove(sb, bp->data, sizeof(*sb));
    800039d8:	0023c997          	auipc	s3,0x23c
    800039dc:	cb098993          	addi	s3,s3,-848 # 8023f688 <sb>
    800039e0:	02000613          	li	a2,32
    800039e4:	05850593          	addi	a1,a0,88
    800039e8:	854e                	mv	a0,s3
    800039ea:	ffffd097          	auipc	ra,0xffffd
    800039ee:	4dc080e7          	jalr	1244(ra) # 80000ec6 <memmove>
  brelse(bp);
    800039f2:	8526                	mv	a0,s1
    800039f4:	00000097          	auipc	ra,0x0
    800039f8:	b48080e7          	jalr	-1208(ra) # 8000353c <brelse>
  if(sb.magic != FSMAGIC)
    800039fc:	0009a703          	lw	a4,0(s3)
    80003a00:	102037b7          	lui	a5,0x10203
    80003a04:	04078793          	addi	a5,a5,64 # 10203040 <_entry-0x6fdfcfc0>
    80003a08:	02f71263          	bne	a4,a5,80003a2c <fsinit+0x70>
  initlog(dev, &sb);
    80003a0c:	0023c597          	auipc	a1,0x23c
    80003a10:	c7c58593          	addi	a1,a1,-900 # 8023f688 <sb>
    80003a14:	854a                	mv	a0,s2
    80003a16:	00001097          	auipc	ra,0x1
    80003a1a:	b60080e7          	jalr	-1184(ra) # 80004576 <initlog>
}
    80003a1e:	70a2                	ld	ra,40(sp)
    80003a20:	7402                	ld	s0,32(sp)
    80003a22:	64e2                	ld	s1,24(sp)
    80003a24:	6942                	ld	s2,16(sp)
    80003a26:	69a2                	ld	s3,8(sp)
    80003a28:	6145                	addi	sp,sp,48
    80003a2a:	8082                	ret
    panic("invalid file system");
    80003a2c:	00005517          	auipc	a0,0x5
    80003a30:	a8450513          	addi	a0,a0,-1404 # 800084b0 <etext+0x4b0>
    80003a34:	ffffd097          	auipc	ra,0xffffd
    80003a38:	b2c080e7          	jalr	-1236(ra) # 80000560 <panic>

0000000080003a3c <iinit>:
{
    80003a3c:	7179                	addi	sp,sp,-48
    80003a3e:	f406                	sd	ra,40(sp)
    80003a40:	f022                	sd	s0,32(sp)
    80003a42:	ec26                	sd	s1,24(sp)
    80003a44:	e84a                	sd	s2,16(sp)
    80003a46:	e44e                	sd	s3,8(sp)
    80003a48:	1800                	addi	s0,sp,48
  initlock(&itable.lock, "itable");
    80003a4a:	00005597          	auipc	a1,0x5
    80003a4e:	a7e58593          	addi	a1,a1,-1410 # 800084c8 <etext+0x4c8>
    80003a52:	0023c517          	auipc	a0,0x23c
    80003a56:	c5650513          	addi	a0,a0,-938 # 8023f6a8 <itable>
    80003a5a:	ffffd097          	auipc	ra,0xffffd
    80003a5e:	284080e7          	jalr	644(ra) # 80000cde <initlock>
  for(i = 0; i < NINODE; i++) {
    80003a62:	0023c497          	auipc	s1,0x23c
    80003a66:	c6e48493          	addi	s1,s1,-914 # 8023f6d0 <itable+0x28>
    80003a6a:	0023d997          	auipc	s3,0x23d
    80003a6e:	6f698993          	addi	s3,s3,1782 # 80241160 <log+0x10>
    initsleeplock(&itable.inode[i].lock, "inode");
    80003a72:	00005917          	auipc	s2,0x5
    80003a76:	a5e90913          	addi	s2,s2,-1442 # 800084d0 <etext+0x4d0>
    80003a7a:	85ca                	mv	a1,s2
    80003a7c:	8526                	mv	a0,s1
    80003a7e:	00001097          	auipc	ra,0x1
    80003a82:	e4c080e7          	jalr	-436(ra) # 800048ca <initsleeplock>
  for(i = 0; i < NINODE; i++) {
    80003a86:	08848493          	addi	s1,s1,136
    80003a8a:	ff3498e3          	bne	s1,s3,80003a7a <iinit+0x3e>
}
    80003a8e:	70a2                	ld	ra,40(sp)
    80003a90:	7402                	ld	s0,32(sp)
    80003a92:	64e2                	ld	s1,24(sp)
    80003a94:	6942                	ld	s2,16(sp)
    80003a96:	69a2                	ld	s3,8(sp)
    80003a98:	6145                	addi	sp,sp,48
    80003a9a:	8082                	ret

0000000080003a9c <ialloc>:
{
    80003a9c:	7139                	addi	sp,sp,-64
    80003a9e:	fc06                	sd	ra,56(sp)
    80003aa0:	f822                	sd	s0,48(sp)
    80003aa2:	0080                	addi	s0,sp,64
  for(inum = 1; inum < sb.ninodes; inum++){
    80003aa4:	0023c717          	auipc	a4,0x23c
    80003aa8:	bf072703          	lw	a4,-1040(a4) # 8023f694 <sb+0xc>
    80003aac:	4785                	li	a5,1
    80003aae:	06e7f463          	bgeu	a5,a4,80003b16 <ialloc+0x7a>
    80003ab2:	f426                	sd	s1,40(sp)
    80003ab4:	f04a                	sd	s2,32(sp)
    80003ab6:	ec4e                	sd	s3,24(sp)
    80003ab8:	e852                	sd	s4,16(sp)
    80003aba:	e456                	sd	s5,8(sp)
    80003abc:	e05a                	sd	s6,0(sp)
    80003abe:	8aaa                	mv	s5,a0
    80003ac0:	8b2e                	mv	s6,a1
    80003ac2:	4905                	li	s2,1
    bp = bread(dev, IBLOCK(inum, sb));
    80003ac4:	0023ca17          	auipc	s4,0x23c
    80003ac8:	bc4a0a13          	addi	s4,s4,-1084 # 8023f688 <sb>
    80003acc:	00495593          	srli	a1,s2,0x4
    80003ad0:	018a2783          	lw	a5,24(s4)
    80003ad4:	9dbd                	addw	a1,a1,a5
    80003ad6:	8556                	mv	a0,s5
    80003ad8:	00000097          	auipc	ra,0x0
    80003adc:	934080e7          	jalr	-1740(ra) # 8000340c <bread>
    80003ae0:	84aa                	mv	s1,a0
    dip = (struct dinode*)bp->data + inum%IPB;
    80003ae2:	05850993          	addi	s3,a0,88
    80003ae6:	00f97793          	andi	a5,s2,15
    80003aea:	079a                	slli	a5,a5,0x6
    80003aec:	99be                	add	s3,s3,a5
    if(dip->type == 0){  // a free inode
    80003aee:	00099783          	lh	a5,0(s3)
    80003af2:	cf9d                	beqz	a5,80003b30 <ialloc+0x94>
    brelse(bp);
    80003af4:	00000097          	auipc	ra,0x0
    80003af8:	a48080e7          	jalr	-1464(ra) # 8000353c <brelse>
  for(inum = 1; inum < sb.ninodes; inum++){
    80003afc:	0905                	addi	s2,s2,1
    80003afe:	00ca2703          	lw	a4,12(s4)
    80003b02:	0009079b          	sext.w	a5,s2
    80003b06:	fce7e3e3          	bltu	a5,a4,80003acc <ialloc+0x30>
    80003b0a:	74a2                	ld	s1,40(sp)
    80003b0c:	7902                	ld	s2,32(sp)
    80003b0e:	69e2                	ld	s3,24(sp)
    80003b10:	6a42                	ld	s4,16(sp)
    80003b12:	6aa2                	ld	s5,8(sp)
    80003b14:	6b02                	ld	s6,0(sp)
  printf("ialloc: no inodes\n");
    80003b16:	00005517          	auipc	a0,0x5
    80003b1a:	9c250513          	addi	a0,a0,-1598 # 800084d8 <etext+0x4d8>
    80003b1e:	ffffd097          	auipc	ra,0xffffd
    80003b22:	a8c080e7          	jalr	-1396(ra) # 800005aa <printf>
  return 0;
    80003b26:	4501                	li	a0,0
}
    80003b28:	70e2                	ld	ra,56(sp)
    80003b2a:	7442                	ld	s0,48(sp)
    80003b2c:	6121                	addi	sp,sp,64
    80003b2e:	8082                	ret
      memset(dip, 0, sizeof(*dip));
    80003b30:	04000613          	li	a2,64
    80003b34:	4581                	li	a1,0
    80003b36:	854e                	mv	a0,s3
    80003b38:	ffffd097          	auipc	ra,0xffffd
    80003b3c:	332080e7          	jalr	818(ra) # 80000e6a <memset>
      dip->type = type;
    80003b40:	01699023          	sh	s6,0(s3)
      log_write(bp);   // mark it allocated on the disk
    80003b44:	8526                	mv	a0,s1
    80003b46:	00001097          	auipc	ra,0x1
    80003b4a:	ca0080e7          	jalr	-864(ra) # 800047e6 <log_write>
      brelse(bp);
    80003b4e:	8526                	mv	a0,s1
    80003b50:	00000097          	auipc	ra,0x0
    80003b54:	9ec080e7          	jalr	-1556(ra) # 8000353c <brelse>
      return iget(dev, inum);
    80003b58:	0009059b          	sext.w	a1,s2
    80003b5c:	8556                	mv	a0,s5
    80003b5e:	00000097          	auipc	ra,0x0
    80003b62:	da2080e7          	jalr	-606(ra) # 80003900 <iget>
    80003b66:	74a2                	ld	s1,40(sp)
    80003b68:	7902                	ld	s2,32(sp)
    80003b6a:	69e2                	ld	s3,24(sp)
    80003b6c:	6a42                	ld	s4,16(sp)
    80003b6e:	6aa2                	ld	s5,8(sp)
    80003b70:	6b02                	ld	s6,0(sp)
    80003b72:	bf5d                	j	80003b28 <ialloc+0x8c>

0000000080003b74 <iupdate>:
{
    80003b74:	1101                	addi	sp,sp,-32
    80003b76:	ec06                	sd	ra,24(sp)
    80003b78:	e822                	sd	s0,16(sp)
    80003b7a:	e426                	sd	s1,8(sp)
    80003b7c:	e04a                	sd	s2,0(sp)
    80003b7e:	1000                	addi	s0,sp,32
    80003b80:	84aa                	mv	s1,a0
  bp = bread(ip->dev, IBLOCK(ip->inum, sb));
    80003b82:	415c                	lw	a5,4(a0)
    80003b84:	0047d79b          	srliw	a5,a5,0x4
    80003b88:	0023c597          	auipc	a1,0x23c
    80003b8c:	b185a583          	lw	a1,-1256(a1) # 8023f6a0 <sb+0x18>
    80003b90:	9dbd                	addw	a1,a1,a5
    80003b92:	4108                	lw	a0,0(a0)
    80003b94:	00000097          	auipc	ra,0x0
    80003b98:	878080e7          	jalr	-1928(ra) # 8000340c <bread>
    80003b9c:	892a                	mv	s2,a0
  dip = (struct dinode*)bp->data + ip->inum%IPB;
    80003b9e:	05850793          	addi	a5,a0,88
    80003ba2:	40d8                	lw	a4,4(s1)
    80003ba4:	8b3d                	andi	a4,a4,15
    80003ba6:	071a                	slli	a4,a4,0x6
    80003ba8:	97ba                	add	a5,a5,a4
  dip->type = ip->type;
    80003baa:	04449703          	lh	a4,68(s1)
    80003bae:	00e79023          	sh	a4,0(a5)
  dip->major = ip->major;
    80003bb2:	04649703          	lh	a4,70(s1)
    80003bb6:	00e79123          	sh	a4,2(a5)
  dip->minor = ip->minor;
    80003bba:	04849703          	lh	a4,72(s1)
    80003bbe:	00e79223          	sh	a4,4(a5)
  dip->nlink = ip->nlink;
    80003bc2:	04a49703          	lh	a4,74(s1)
    80003bc6:	00e79323          	sh	a4,6(a5)
  dip->size = ip->size;
    80003bca:	44f8                	lw	a4,76(s1)
    80003bcc:	c798                	sw	a4,8(a5)
  memmove(dip->addrs, ip->addrs, sizeof(ip->addrs));
    80003bce:	03400613          	li	a2,52
    80003bd2:	05048593          	addi	a1,s1,80
    80003bd6:	00c78513          	addi	a0,a5,12
    80003bda:	ffffd097          	auipc	ra,0xffffd
    80003bde:	2ec080e7          	jalr	748(ra) # 80000ec6 <memmove>
  log_write(bp);
    80003be2:	854a                	mv	a0,s2
    80003be4:	00001097          	auipc	ra,0x1
    80003be8:	c02080e7          	jalr	-1022(ra) # 800047e6 <log_write>
  brelse(bp);
    80003bec:	854a                	mv	a0,s2
    80003bee:	00000097          	auipc	ra,0x0
    80003bf2:	94e080e7          	jalr	-1714(ra) # 8000353c <brelse>
}
    80003bf6:	60e2                	ld	ra,24(sp)
    80003bf8:	6442                	ld	s0,16(sp)
    80003bfa:	64a2                	ld	s1,8(sp)
    80003bfc:	6902                	ld	s2,0(sp)
    80003bfe:	6105                	addi	sp,sp,32
    80003c00:	8082                	ret

0000000080003c02 <idup>:
{
    80003c02:	1101                	addi	sp,sp,-32
    80003c04:	ec06                	sd	ra,24(sp)
    80003c06:	e822                	sd	s0,16(sp)
    80003c08:	e426                	sd	s1,8(sp)
    80003c0a:	1000                	addi	s0,sp,32
    80003c0c:	84aa                	mv	s1,a0
  acquire(&itable.lock);
    80003c0e:	0023c517          	auipc	a0,0x23c
    80003c12:	a9a50513          	addi	a0,a0,-1382 # 8023f6a8 <itable>
    80003c16:	ffffd097          	auipc	ra,0xffffd
    80003c1a:	158080e7          	jalr	344(ra) # 80000d6e <acquire>
  ip->ref++;
    80003c1e:	449c                	lw	a5,8(s1)
    80003c20:	2785                	addiw	a5,a5,1
    80003c22:	c49c                	sw	a5,8(s1)
  release(&itable.lock);
    80003c24:	0023c517          	auipc	a0,0x23c
    80003c28:	a8450513          	addi	a0,a0,-1404 # 8023f6a8 <itable>
    80003c2c:	ffffd097          	auipc	ra,0xffffd
    80003c30:	1f6080e7          	jalr	502(ra) # 80000e22 <release>
}
    80003c34:	8526                	mv	a0,s1
    80003c36:	60e2                	ld	ra,24(sp)
    80003c38:	6442                	ld	s0,16(sp)
    80003c3a:	64a2                	ld	s1,8(sp)
    80003c3c:	6105                	addi	sp,sp,32
    80003c3e:	8082                	ret

0000000080003c40 <ilock>:
{
    80003c40:	1101                	addi	sp,sp,-32
    80003c42:	ec06                	sd	ra,24(sp)
    80003c44:	e822                	sd	s0,16(sp)
    80003c46:	e426                	sd	s1,8(sp)
    80003c48:	1000                	addi	s0,sp,32
  if(ip == 0 || ip->ref < 1)
    80003c4a:	c10d                	beqz	a0,80003c6c <ilock+0x2c>
    80003c4c:	84aa                	mv	s1,a0
    80003c4e:	451c                	lw	a5,8(a0)
    80003c50:	00f05e63          	blez	a5,80003c6c <ilock+0x2c>
  acquiresleep(&ip->lock);
    80003c54:	0541                	addi	a0,a0,16
    80003c56:	00001097          	auipc	ra,0x1
    80003c5a:	cae080e7          	jalr	-850(ra) # 80004904 <acquiresleep>
  if(ip->valid == 0){
    80003c5e:	40bc                	lw	a5,64(s1)
    80003c60:	cf99                	beqz	a5,80003c7e <ilock+0x3e>
}
    80003c62:	60e2                	ld	ra,24(sp)
    80003c64:	6442                	ld	s0,16(sp)
    80003c66:	64a2                	ld	s1,8(sp)
    80003c68:	6105                	addi	sp,sp,32
    80003c6a:	8082                	ret
    80003c6c:	e04a                	sd	s2,0(sp)
    panic("ilock");
    80003c6e:	00005517          	auipc	a0,0x5
    80003c72:	88250513          	addi	a0,a0,-1918 # 800084f0 <etext+0x4f0>
    80003c76:	ffffd097          	auipc	ra,0xffffd
    80003c7a:	8ea080e7          	jalr	-1814(ra) # 80000560 <panic>
    80003c7e:	e04a                	sd	s2,0(sp)
    bp = bread(ip->dev, IBLOCK(ip->inum, sb));
    80003c80:	40dc                	lw	a5,4(s1)
    80003c82:	0047d79b          	srliw	a5,a5,0x4
    80003c86:	0023c597          	auipc	a1,0x23c
    80003c8a:	a1a5a583          	lw	a1,-1510(a1) # 8023f6a0 <sb+0x18>
    80003c8e:	9dbd                	addw	a1,a1,a5
    80003c90:	4088                	lw	a0,0(s1)
    80003c92:	fffff097          	auipc	ra,0xfffff
    80003c96:	77a080e7          	jalr	1914(ra) # 8000340c <bread>
    80003c9a:	892a                	mv	s2,a0
    dip = (struct dinode*)bp->data + ip->inum%IPB;
    80003c9c:	05850593          	addi	a1,a0,88
    80003ca0:	40dc                	lw	a5,4(s1)
    80003ca2:	8bbd                	andi	a5,a5,15
    80003ca4:	079a                	slli	a5,a5,0x6
    80003ca6:	95be                	add	a1,a1,a5
    ip->type = dip->type;
    80003ca8:	00059783          	lh	a5,0(a1)
    80003cac:	04f49223          	sh	a5,68(s1)
    ip->major = dip->major;
    80003cb0:	00259783          	lh	a5,2(a1)
    80003cb4:	04f49323          	sh	a5,70(s1)
    ip->minor = dip->minor;
    80003cb8:	00459783          	lh	a5,4(a1)
    80003cbc:	04f49423          	sh	a5,72(s1)
    ip->nlink = dip->nlink;
    80003cc0:	00659783          	lh	a5,6(a1)
    80003cc4:	04f49523          	sh	a5,74(s1)
    ip->size = dip->size;
    80003cc8:	459c                	lw	a5,8(a1)
    80003cca:	c4fc                	sw	a5,76(s1)
    memmove(ip->addrs, dip->addrs, sizeof(ip->addrs));
    80003ccc:	03400613          	li	a2,52
    80003cd0:	05b1                	addi	a1,a1,12
    80003cd2:	05048513          	addi	a0,s1,80
    80003cd6:	ffffd097          	auipc	ra,0xffffd
    80003cda:	1f0080e7          	jalr	496(ra) # 80000ec6 <memmove>
    brelse(bp);
    80003cde:	854a                	mv	a0,s2
    80003ce0:	00000097          	auipc	ra,0x0
    80003ce4:	85c080e7          	jalr	-1956(ra) # 8000353c <brelse>
    ip->valid = 1;
    80003ce8:	4785                	li	a5,1
    80003cea:	c0bc                	sw	a5,64(s1)
    if(ip->type == 0)
    80003cec:	04449783          	lh	a5,68(s1)
    80003cf0:	c399                	beqz	a5,80003cf6 <ilock+0xb6>
    80003cf2:	6902                	ld	s2,0(sp)
    80003cf4:	b7bd                	j	80003c62 <ilock+0x22>
      panic("ilock: no type");
    80003cf6:	00005517          	auipc	a0,0x5
    80003cfa:	80250513          	addi	a0,a0,-2046 # 800084f8 <etext+0x4f8>
    80003cfe:	ffffd097          	auipc	ra,0xffffd
    80003d02:	862080e7          	jalr	-1950(ra) # 80000560 <panic>

0000000080003d06 <iunlock>:
{
    80003d06:	1101                	addi	sp,sp,-32
    80003d08:	ec06                	sd	ra,24(sp)
    80003d0a:	e822                	sd	s0,16(sp)
    80003d0c:	e426                	sd	s1,8(sp)
    80003d0e:	e04a                	sd	s2,0(sp)
    80003d10:	1000                	addi	s0,sp,32
  if(ip == 0 || !holdingsleep(&ip->lock) || ip->ref < 1)
    80003d12:	c905                	beqz	a0,80003d42 <iunlock+0x3c>
    80003d14:	84aa                	mv	s1,a0
    80003d16:	01050913          	addi	s2,a0,16
    80003d1a:	854a                	mv	a0,s2
    80003d1c:	00001097          	auipc	ra,0x1
    80003d20:	c82080e7          	jalr	-894(ra) # 8000499e <holdingsleep>
    80003d24:	cd19                	beqz	a0,80003d42 <iunlock+0x3c>
    80003d26:	449c                	lw	a5,8(s1)
    80003d28:	00f05d63          	blez	a5,80003d42 <iunlock+0x3c>
  releasesleep(&ip->lock);
    80003d2c:	854a                	mv	a0,s2
    80003d2e:	00001097          	auipc	ra,0x1
    80003d32:	c2c080e7          	jalr	-980(ra) # 8000495a <releasesleep>
}
    80003d36:	60e2                	ld	ra,24(sp)
    80003d38:	6442                	ld	s0,16(sp)
    80003d3a:	64a2                	ld	s1,8(sp)
    80003d3c:	6902                	ld	s2,0(sp)
    80003d3e:	6105                	addi	sp,sp,32
    80003d40:	8082                	ret
    panic("iunlock");
    80003d42:	00004517          	auipc	a0,0x4
    80003d46:	7c650513          	addi	a0,a0,1990 # 80008508 <etext+0x508>
    80003d4a:	ffffd097          	auipc	ra,0xffffd
    80003d4e:	816080e7          	jalr	-2026(ra) # 80000560 <panic>

0000000080003d52 <itrunc>:

// Truncate inode (discard contents).
// Caller must hold ip->lock.
void
itrunc(struct inode *ip)
{
    80003d52:	7179                	addi	sp,sp,-48
    80003d54:	f406                	sd	ra,40(sp)
    80003d56:	f022                	sd	s0,32(sp)
    80003d58:	ec26                	sd	s1,24(sp)
    80003d5a:	e84a                	sd	s2,16(sp)
    80003d5c:	e44e                	sd	s3,8(sp)
    80003d5e:	1800                	addi	s0,sp,48
    80003d60:	89aa                	mv	s3,a0
  int i, j;
  struct buf *bp;
  uint *a;

  for(i = 0; i < NDIRECT; i++){
    80003d62:	05050493          	addi	s1,a0,80
    80003d66:	08050913          	addi	s2,a0,128
    80003d6a:	a021                	j	80003d72 <itrunc+0x20>
    80003d6c:	0491                	addi	s1,s1,4
    80003d6e:	01248d63          	beq	s1,s2,80003d88 <itrunc+0x36>
    if(ip->addrs[i]){
    80003d72:	408c                	lw	a1,0(s1)
    80003d74:	dde5                	beqz	a1,80003d6c <itrunc+0x1a>
      bfree(ip->dev, ip->addrs[i]);
    80003d76:	0009a503          	lw	a0,0(s3)
    80003d7a:	00000097          	auipc	ra,0x0
    80003d7e:	8d6080e7          	jalr	-1834(ra) # 80003650 <bfree>
      ip->addrs[i] = 0;
    80003d82:	0004a023          	sw	zero,0(s1)
    80003d86:	b7dd                	j	80003d6c <itrunc+0x1a>
    }
  }

  if(ip->addrs[NDIRECT]){
    80003d88:	0809a583          	lw	a1,128(s3)
    80003d8c:	ed99                	bnez	a1,80003daa <itrunc+0x58>
    brelse(bp);
    bfree(ip->dev, ip->addrs[NDIRECT]);
    ip->addrs[NDIRECT] = 0;
  }

  ip->size = 0;
    80003d8e:	0409a623          	sw	zero,76(s3)
  iupdate(ip);
    80003d92:	854e                	mv	a0,s3
    80003d94:	00000097          	auipc	ra,0x0
    80003d98:	de0080e7          	jalr	-544(ra) # 80003b74 <iupdate>
}
    80003d9c:	70a2                	ld	ra,40(sp)
    80003d9e:	7402                	ld	s0,32(sp)
    80003da0:	64e2                	ld	s1,24(sp)
    80003da2:	6942                	ld	s2,16(sp)
    80003da4:	69a2                	ld	s3,8(sp)
    80003da6:	6145                	addi	sp,sp,48
    80003da8:	8082                	ret
    80003daa:	e052                	sd	s4,0(sp)
    bp = bread(ip->dev, ip->addrs[NDIRECT]);
    80003dac:	0009a503          	lw	a0,0(s3)
    80003db0:	fffff097          	auipc	ra,0xfffff
    80003db4:	65c080e7          	jalr	1628(ra) # 8000340c <bread>
    80003db8:	8a2a                	mv	s4,a0
    for(j = 0; j < NINDIRECT; j++){
    80003dba:	05850493          	addi	s1,a0,88
    80003dbe:	45850913          	addi	s2,a0,1112
    80003dc2:	a021                	j	80003dca <itrunc+0x78>
    80003dc4:	0491                	addi	s1,s1,4
    80003dc6:	01248b63          	beq	s1,s2,80003ddc <itrunc+0x8a>
      if(a[j])
    80003dca:	408c                	lw	a1,0(s1)
    80003dcc:	dde5                	beqz	a1,80003dc4 <itrunc+0x72>
        bfree(ip->dev, a[j]);
    80003dce:	0009a503          	lw	a0,0(s3)
    80003dd2:	00000097          	auipc	ra,0x0
    80003dd6:	87e080e7          	jalr	-1922(ra) # 80003650 <bfree>
    80003dda:	b7ed                	j	80003dc4 <itrunc+0x72>
    brelse(bp);
    80003ddc:	8552                	mv	a0,s4
    80003dde:	fffff097          	auipc	ra,0xfffff
    80003de2:	75e080e7          	jalr	1886(ra) # 8000353c <brelse>
    bfree(ip->dev, ip->addrs[NDIRECT]);
    80003de6:	0809a583          	lw	a1,128(s3)
    80003dea:	0009a503          	lw	a0,0(s3)
    80003dee:	00000097          	auipc	ra,0x0
    80003df2:	862080e7          	jalr	-1950(ra) # 80003650 <bfree>
    ip->addrs[NDIRECT] = 0;
    80003df6:	0809a023          	sw	zero,128(s3)
    80003dfa:	6a02                	ld	s4,0(sp)
    80003dfc:	bf49                	j	80003d8e <itrunc+0x3c>

0000000080003dfe <iput>:
{
    80003dfe:	1101                	addi	sp,sp,-32
    80003e00:	ec06                	sd	ra,24(sp)
    80003e02:	e822                	sd	s0,16(sp)
    80003e04:	e426                	sd	s1,8(sp)
    80003e06:	1000                	addi	s0,sp,32
    80003e08:	84aa                	mv	s1,a0
  acquire(&itable.lock);
    80003e0a:	0023c517          	auipc	a0,0x23c
    80003e0e:	89e50513          	addi	a0,a0,-1890 # 8023f6a8 <itable>
    80003e12:	ffffd097          	auipc	ra,0xffffd
    80003e16:	f5c080e7          	jalr	-164(ra) # 80000d6e <acquire>
  if(ip->ref == 1 && ip->valid && ip->nlink == 0){
    80003e1a:	4498                	lw	a4,8(s1)
    80003e1c:	4785                	li	a5,1
    80003e1e:	02f70263          	beq	a4,a5,80003e42 <iput+0x44>
  ip->ref--;
    80003e22:	449c                	lw	a5,8(s1)
    80003e24:	37fd                	addiw	a5,a5,-1
    80003e26:	c49c                	sw	a5,8(s1)
  release(&itable.lock);
    80003e28:	0023c517          	auipc	a0,0x23c
    80003e2c:	88050513          	addi	a0,a0,-1920 # 8023f6a8 <itable>
    80003e30:	ffffd097          	auipc	ra,0xffffd
    80003e34:	ff2080e7          	jalr	-14(ra) # 80000e22 <release>
}
    80003e38:	60e2                	ld	ra,24(sp)
    80003e3a:	6442                	ld	s0,16(sp)
    80003e3c:	64a2                	ld	s1,8(sp)
    80003e3e:	6105                	addi	sp,sp,32
    80003e40:	8082                	ret
  if(ip->ref == 1 && ip->valid && ip->nlink == 0){
    80003e42:	40bc                	lw	a5,64(s1)
    80003e44:	dff9                	beqz	a5,80003e22 <iput+0x24>
    80003e46:	04a49783          	lh	a5,74(s1)
    80003e4a:	ffe1                	bnez	a5,80003e22 <iput+0x24>
    80003e4c:	e04a                	sd	s2,0(sp)
    acquiresleep(&ip->lock);
    80003e4e:	01048913          	addi	s2,s1,16
    80003e52:	854a                	mv	a0,s2
    80003e54:	00001097          	auipc	ra,0x1
    80003e58:	ab0080e7          	jalr	-1360(ra) # 80004904 <acquiresleep>
    release(&itable.lock);
    80003e5c:	0023c517          	auipc	a0,0x23c
    80003e60:	84c50513          	addi	a0,a0,-1972 # 8023f6a8 <itable>
    80003e64:	ffffd097          	auipc	ra,0xffffd
    80003e68:	fbe080e7          	jalr	-66(ra) # 80000e22 <release>
    itrunc(ip);
    80003e6c:	8526                	mv	a0,s1
    80003e6e:	00000097          	auipc	ra,0x0
    80003e72:	ee4080e7          	jalr	-284(ra) # 80003d52 <itrunc>
    ip->type = 0;
    80003e76:	04049223          	sh	zero,68(s1)
    iupdate(ip);
    80003e7a:	8526                	mv	a0,s1
    80003e7c:	00000097          	auipc	ra,0x0
    80003e80:	cf8080e7          	jalr	-776(ra) # 80003b74 <iupdate>
    ip->valid = 0;
    80003e84:	0404a023          	sw	zero,64(s1)
    releasesleep(&ip->lock);
    80003e88:	854a                	mv	a0,s2
    80003e8a:	00001097          	auipc	ra,0x1
    80003e8e:	ad0080e7          	jalr	-1328(ra) # 8000495a <releasesleep>
    acquire(&itable.lock);
    80003e92:	0023c517          	auipc	a0,0x23c
    80003e96:	81650513          	addi	a0,a0,-2026 # 8023f6a8 <itable>
    80003e9a:	ffffd097          	auipc	ra,0xffffd
    80003e9e:	ed4080e7          	jalr	-300(ra) # 80000d6e <acquire>
    80003ea2:	6902                	ld	s2,0(sp)
    80003ea4:	bfbd                	j	80003e22 <iput+0x24>

0000000080003ea6 <iunlockput>:
{
    80003ea6:	1101                	addi	sp,sp,-32
    80003ea8:	ec06                	sd	ra,24(sp)
    80003eaa:	e822                	sd	s0,16(sp)
    80003eac:	e426                	sd	s1,8(sp)
    80003eae:	1000                	addi	s0,sp,32
    80003eb0:	84aa                	mv	s1,a0
  iunlock(ip);
    80003eb2:	00000097          	auipc	ra,0x0
    80003eb6:	e54080e7          	jalr	-428(ra) # 80003d06 <iunlock>
  iput(ip);
    80003eba:	8526                	mv	a0,s1
    80003ebc:	00000097          	auipc	ra,0x0
    80003ec0:	f42080e7          	jalr	-190(ra) # 80003dfe <iput>
}
    80003ec4:	60e2                	ld	ra,24(sp)
    80003ec6:	6442                	ld	s0,16(sp)
    80003ec8:	64a2                	ld	s1,8(sp)
    80003eca:	6105                	addi	sp,sp,32
    80003ecc:	8082                	ret

0000000080003ece <stati>:

// Copy stat information from inode.
// Caller must hold ip->lock.
void
stati(struct inode *ip, struct stat *st)
{
    80003ece:	1141                	addi	sp,sp,-16
    80003ed0:	e422                	sd	s0,8(sp)
    80003ed2:	0800                	addi	s0,sp,16
  st->dev = ip->dev;
    80003ed4:	411c                	lw	a5,0(a0)
    80003ed6:	c19c                	sw	a5,0(a1)
  st->ino = ip->inum;
    80003ed8:	415c                	lw	a5,4(a0)
    80003eda:	c1dc                	sw	a5,4(a1)
  st->type = ip->type;
    80003edc:	04451783          	lh	a5,68(a0)
    80003ee0:	00f59423          	sh	a5,8(a1)
  st->nlink = ip->nlink;
    80003ee4:	04a51783          	lh	a5,74(a0)
    80003ee8:	00f59523          	sh	a5,10(a1)
  st->size = ip->size;
    80003eec:	04c56783          	lwu	a5,76(a0)
    80003ef0:	e99c                	sd	a5,16(a1)
}
    80003ef2:	6422                	ld	s0,8(sp)
    80003ef4:	0141                	addi	sp,sp,16
    80003ef6:	8082                	ret

0000000080003ef8 <readi>:
readi(struct inode *ip, int user_dst, uint64 dst, uint off, uint n)
{
  uint tot, m;
  struct buf *bp;

  if(off > ip->size || off + n < off)
    80003ef8:	457c                	lw	a5,76(a0)
    80003efa:	10d7e563          	bltu	a5,a3,80004004 <readi+0x10c>
{
    80003efe:	7159                	addi	sp,sp,-112
    80003f00:	f486                	sd	ra,104(sp)
    80003f02:	f0a2                	sd	s0,96(sp)
    80003f04:	eca6                	sd	s1,88(sp)
    80003f06:	e0d2                	sd	s4,64(sp)
    80003f08:	fc56                	sd	s5,56(sp)
    80003f0a:	f85a                	sd	s6,48(sp)
    80003f0c:	f45e                	sd	s7,40(sp)
    80003f0e:	1880                	addi	s0,sp,112
    80003f10:	8b2a                	mv	s6,a0
    80003f12:	8bae                	mv	s7,a1
    80003f14:	8a32                	mv	s4,a2
    80003f16:	84b6                	mv	s1,a3
    80003f18:	8aba                	mv	s5,a4
  if(off > ip->size || off + n < off)
    80003f1a:	9f35                	addw	a4,a4,a3
    return 0;
    80003f1c:	4501                	li	a0,0
  if(off > ip->size || off + n < off)
    80003f1e:	0cd76a63          	bltu	a4,a3,80003ff2 <readi+0xfa>
    80003f22:	e4ce                	sd	s3,72(sp)
  if(off + n > ip->size)
    80003f24:	00e7f463          	bgeu	a5,a4,80003f2c <readi+0x34>
    n = ip->size - off;
    80003f28:	40d78abb          	subw	s5,a5,a3

  for(tot=0; tot<n; tot+=m, off+=m, dst+=m){
    80003f2c:	0a0a8963          	beqz	s5,80003fde <readi+0xe6>
    80003f30:	e8ca                	sd	s2,80(sp)
    80003f32:	f062                	sd	s8,32(sp)
    80003f34:	ec66                	sd	s9,24(sp)
    80003f36:	e86a                	sd	s10,16(sp)
    80003f38:	e46e                	sd	s11,8(sp)
    80003f3a:	4981                	li	s3,0
    uint addr = bmap(ip, off/BSIZE);
    if(addr == 0)
      break;
    bp = bread(ip->dev, addr);
    m = min(n - tot, BSIZE - off%BSIZE);
    80003f3c:	40000c93          	li	s9,1024
    if(either_copyout(user_dst, dst, bp->data + (off % BSIZE), m) == -1) {
    80003f40:	5c7d                	li	s8,-1
    80003f42:	a82d                	j	80003f7c <readi+0x84>
    80003f44:	020d1d93          	slli	s11,s10,0x20
    80003f48:	020ddd93          	srli	s11,s11,0x20
    80003f4c:	05890613          	addi	a2,s2,88
    80003f50:	86ee                	mv	a3,s11
    80003f52:	963a                	add	a2,a2,a4
    80003f54:	85d2                	mv	a1,s4
    80003f56:	855e                	mv	a0,s7
    80003f58:	fffff097          	auipc	ra,0xfffff
    80003f5c:	80a080e7          	jalr	-2038(ra) # 80002762 <either_copyout>
    80003f60:	05850d63          	beq	a0,s8,80003fba <readi+0xc2>
      brelse(bp);
      tot = -1;
      break;
    }
    brelse(bp);
    80003f64:	854a                	mv	a0,s2
    80003f66:	fffff097          	auipc	ra,0xfffff
    80003f6a:	5d6080e7          	jalr	1494(ra) # 8000353c <brelse>
  for(tot=0; tot<n; tot+=m, off+=m, dst+=m){
    80003f6e:	013d09bb          	addw	s3,s10,s3
    80003f72:	009d04bb          	addw	s1,s10,s1
    80003f76:	9a6e                	add	s4,s4,s11
    80003f78:	0559fd63          	bgeu	s3,s5,80003fd2 <readi+0xda>
    uint addr = bmap(ip, off/BSIZE);
    80003f7c:	00a4d59b          	srliw	a1,s1,0xa
    80003f80:	855a                	mv	a0,s6
    80003f82:	00000097          	auipc	ra,0x0
    80003f86:	88e080e7          	jalr	-1906(ra) # 80003810 <bmap>
    80003f8a:	0005059b          	sext.w	a1,a0
    if(addr == 0)
    80003f8e:	c9b1                	beqz	a1,80003fe2 <readi+0xea>
    bp = bread(ip->dev, addr);
    80003f90:	000b2503          	lw	a0,0(s6)
    80003f94:	fffff097          	auipc	ra,0xfffff
    80003f98:	478080e7          	jalr	1144(ra) # 8000340c <bread>
    80003f9c:	892a                	mv	s2,a0
    m = min(n - tot, BSIZE - off%BSIZE);
    80003f9e:	3ff4f713          	andi	a4,s1,1023
    80003fa2:	40ec87bb          	subw	a5,s9,a4
    80003fa6:	413a86bb          	subw	a3,s5,s3
    80003faa:	8d3e                	mv	s10,a5
    80003fac:	2781                	sext.w	a5,a5
    80003fae:	0006861b          	sext.w	a2,a3
    80003fb2:	f8f679e3          	bgeu	a2,a5,80003f44 <readi+0x4c>
    80003fb6:	8d36                	mv	s10,a3
    80003fb8:	b771                	j	80003f44 <readi+0x4c>
      brelse(bp);
    80003fba:	854a                	mv	a0,s2
    80003fbc:	fffff097          	auipc	ra,0xfffff
    80003fc0:	580080e7          	jalr	1408(ra) # 8000353c <brelse>
      tot = -1;
    80003fc4:	59fd                	li	s3,-1
      break;
    80003fc6:	6946                	ld	s2,80(sp)
    80003fc8:	7c02                	ld	s8,32(sp)
    80003fca:	6ce2                	ld	s9,24(sp)
    80003fcc:	6d42                	ld	s10,16(sp)
    80003fce:	6da2                	ld	s11,8(sp)
    80003fd0:	a831                	j	80003fec <readi+0xf4>
    80003fd2:	6946                	ld	s2,80(sp)
    80003fd4:	7c02                	ld	s8,32(sp)
    80003fd6:	6ce2                	ld	s9,24(sp)
    80003fd8:	6d42                	ld	s10,16(sp)
    80003fda:	6da2                	ld	s11,8(sp)
    80003fdc:	a801                	j	80003fec <readi+0xf4>
  for(tot=0; tot<n; tot+=m, off+=m, dst+=m){
    80003fde:	89d6                	mv	s3,s5
    80003fe0:	a031                	j	80003fec <readi+0xf4>
    80003fe2:	6946                	ld	s2,80(sp)
    80003fe4:	7c02                	ld	s8,32(sp)
    80003fe6:	6ce2                	ld	s9,24(sp)
    80003fe8:	6d42                	ld	s10,16(sp)
    80003fea:	6da2                	ld	s11,8(sp)
  }
  return tot;
    80003fec:	0009851b          	sext.w	a0,s3
    80003ff0:	69a6                	ld	s3,72(sp)
}
    80003ff2:	70a6                	ld	ra,104(sp)
    80003ff4:	7406                	ld	s0,96(sp)
    80003ff6:	64e6                	ld	s1,88(sp)
    80003ff8:	6a06                	ld	s4,64(sp)
    80003ffa:	7ae2                	ld	s5,56(sp)
    80003ffc:	7b42                	ld	s6,48(sp)
    80003ffe:	7ba2                	ld	s7,40(sp)
    80004000:	6165                	addi	sp,sp,112
    80004002:	8082                	ret
    return 0;
    80004004:	4501                	li	a0,0
}
    80004006:	8082                	ret

0000000080004008 <writei>:
writei(struct inode *ip, int user_src, uint64 src, uint off, uint n)
{
  uint tot, m;
  struct buf *bp;

  if(off > ip->size || off + n < off)
    80004008:	457c                	lw	a5,76(a0)
    8000400a:	10d7ee63          	bltu	a5,a3,80004126 <writei+0x11e>
{
    8000400e:	7159                	addi	sp,sp,-112
    80004010:	f486                	sd	ra,104(sp)
    80004012:	f0a2                	sd	s0,96(sp)
    80004014:	e8ca                	sd	s2,80(sp)
    80004016:	e0d2                	sd	s4,64(sp)
    80004018:	fc56                	sd	s5,56(sp)
    8000401a:	f85a                	sd	s6,48(sp)
    8000401c:	f45e                	sd	s7,40(sp)
    8000401e:	1880                	addi	s0,sp,112
    80004020:	8aaa                	mv	s5,a0
    80004022:	8bae                	mv	s7,a1
    80004024:	8a32                	mv	s4,a2
    80004026:	8936                	mv	s2,a3
    80004028:	8b3a                	mv	s6,a4
  if(off > ip->size || off + n < off)
    8000402a:	00e687bb          	addw	a5,a3,a4
    8000402e:	0ed7ee63          	bltu	a5,a3,8000412a <writei+0x122>
    return -1;
  if(off + n > MAXFILE*BSIZE)
    80004032:	00043737          	lui	a4,0x43
    80004036:	0ef76c63          	bltu	a4,a5,8000412e <writei+0x126>
    8000403a:	e4ce                	sd	s3,72(sp)
    return -1;

  for(tot=0; tot<n; tot+=m, off+=m, src+=m){
    8000403c:	0c0b0d63          	beqz	s6,80004116 <writei+0x10e>
    80004040:	eca6                	sd	s1,88(sp)
    80004042:	f062                	sd	s8,32(sp)
    80004044:	ec66                	sd	s9,24(sp)
    80004046:	e86a                	sd	s10,16(sp)
    80004048:	e46e                	sd	s11,8(sp)
    8000404a:	4981                	li	s3,0
    uint addr = bmap(ip, off/BSIZE);
    if(addr == 0)
      break;
    bp = bread(ip->dev, addr);
    m = min(n - tot, BSIZE - off%BSIZE);
    8000404c:	40000c93          	li	s9,1024
    if(either_copyin(bp->data + (off % BSIZE), user_src, src, m) == -1) {
    80004050:	5c7d                	li	s8,-1
    80004052:	a091                	j	80004096 <writei+0x8e>
    80004054:	020d1d93          	slli	s11,s10,0x20
    80004058:	020ddd93          	srli	s11,s11,0x20
    8000405c:	05848513          	addi	a0,s1,88
    80004060:	86ee                	mv	a3,s11
    80004062:	8652                	mv	a2,s4
    80004064:	85de                	mv	a1,s7
    80004066:	953a                	add	a0,a0,a4
    80004068:	ffffe097          	auipc	ra,0xffffe
    8000406c:	750080e7          	jalr	1872(ra) # 800027b8 <either_copyin>
    80004070:	07850263          	beq	a0,s8,800040d4 <writei+0xcc>
      brelse(bp);
      break;
    }
    log_write(bp);
    80004074:	8526                	mv	a0,s1
    80004076:	00000097          	auipc	ra,0x0
    8000407a:	770080e7          	jalr	1904(ra) # 800047e6 <log_write>
    brelse(bp);
    8000407e:	8526                	mv	a0,s1
    80004080:	fffff097          	auipc	ra,0xfffff
    80004084:	4bc080e7          	jalr	1212(ra) # 8000353c <brelse>
  for(tot=0; tot<n; tot+=m, off+=m, src+=m){
    80004088:	013d09bb          	addw	s3,s10,s3
    8000408c:	012d093b          	addw	s2,s10,s2
    80004090:	9a6e                	add	s4,s4,s11
    80004092:	0569f663          	bgeu	s3,s6,800040de <writei+0xd6>
    uint addr = bmap(ip, off/BSIZE);
    80004096:	00a9559b          	srliw	a1,s2,0xa
    8000409a:	8556                	mv	a0,s5
    8000409c:	fffff097          	auipc	ra,0xfffff
    800040a0:	774080e7          	jalr	1908(ra) # 80003810 <bmap>
    800040a4:	0005059b          	sext.w	a1,a0
    if(addr == 0)
    800040a8:	c99d                	beqz	a1,800040de <writei+0xd6>
    bp = bread(ip->dev, addr);
    800040aa:	000aa503          	lw	a0,0(s5)
    800040ae:	fffff097          	auipc	ra,0xfffff
    800040b2:	35e080e7          	jalr	862(ra) # 8000340c <bread>
    800040b6:	84aa                	mv	s1,a0
    m = min(n - tot, BSIZE - off%BSIZE);
    800040b8:	3ff97713          	andi	a4,s2,1023
    800040bc:	40ec87bb          	subw	a5,s9,a4
    800040c0:	413b06bb          	subw	a3,s6,s3
    800040c4:	8d3e                	mv	s10,a5
    800040c6:	2781                	sext.w	a5,a5
    800040c8:	0006861b          	sext.w	a2,a3
    800040cc:	f8f674e3          	bgeu	a2,a5,80004054 <writei+0x4c>
    800040d0:	8d36                	mv	s10,a3
    800040d2:	b749                	j	80004054 <writei+0x4c>
      brelse(bp);
    800040d4:	8526                	mv	a0,s1
    800040d6:	fffff097          	auipc	ra,0xfffff
    800040da:	466080e7          	jalr	1126(ra) # 8000353c <brelse>
  }

  if(off > ip->size)
    800040de:	04caa783          	lw	a5,76(s5)
    800040e2:	0327fc63          	bgeu	a5,s2,8000411a <writei+0x112>
    ip->size = off;
    800040e6:	052aa623          	sw	s2,76(s5)
    800040ea:	64e6                	ld	s1,88(sp)
    800040ec:	7c02                	ld	s8,32(sp)
    800040ee:	6ce2                	ld	s9,24(sp)
    800040f0:	6d42                	ld	s10,16(sp)
    800040f2:	6da2                	ld	s11,8(sp)

  // write the i-node back to disk even if the size didn't change
  // because the loop above might have called bmap() and added a new
  // block to ip->addrs[].
  iupdate(ip);
    800040f4:	8556                	mv	a0,s5
    800040f6:	00000097          	auipc	ra,0x0
    800040fa:	a7e080e7          	jalr	-1410(ra) # 80003b74 <iupdate>

  return tot;
    800040fe:	0009851b          	sext.w	a0,s3
    80004102:	69a6                	ld	s3,72(sp)
}
    80004104:	70a6                	ld	ra,104(sp)
    80004106:	7406                	ld	s0,96(sp)
    80004108:	6946                	ld	s2,80(sp)
    8000410a:	6a06                	ld	s4,64(sp)
    8000410c:	7ae2                	ld	s5,56(sp)
    8000410e:	7b42                	ld	s6,48(sp)
    80004110:	7ba2                	ld	s7,40(sp)
    80004112:	6165                	addi	sp,sp,112
    80004114:	8082                	ret
  for(tot=0; tot<n; tot+=m, off+=m, src+=m){
    80004116:	89da                	mv	s3,s6
    80004118:	bff1                	j	800040f4 <writei+0xec>
    8000411a:	64e6                	ld	s1,88(sp)
    8000411c:	7c02                	ld	s8,32(sp)
    8000411e:	6ce2                	ld	s9,24(sp)
    80004120:	6d42                	ld	s10,16(sp)
    80004122:	6da2                	ld	s11,8(sp)
    80004124:	bfc1                	j	800040f4 <writei+0xec>
    return -1;
    80004126:	557d                	li	a0,-1
}
    80004128:	8082                	ret
    return -1;
    8000412a:	557d                	li	a0,-1
    8000412c:	bfe1                	j	80004104 <writei+0xfc>
    return -1;
    8000412e:	557d                	li	a0,-1
    80004130:	bfd1                	j	80004104 <writei+0xfc>

0000000080004132 <namecmp>:

// Directories

int
namecmp(const char *s, const char *t)
{
    80004132:	1141                	addi	sp,sp,-16
    80004134:	e406                	sd	ra,8(sp)
    80004136:	e022                	sd	s0,0(sp)
    80004138:	0800                	addi	s0,sp,16
  return strncmp(s, t, DIRSIZ);
    8000413a:	4639                	li	a2,14
    8000413c:	ffffd097          	auipc	ra,0xffffd
    80004140:	dfe080e7          	jalr	-514(ra) # 80000f3a <strncmp>
}
    80004144:	60a2                	ld	ra,8(sp)
    80004146:	6402                	ld	s0,0(sp)
    80004148:	0141                	addi	sp,sp,16
    8000414a:	8082                	ret

000000008000414c <dirlookup>:

// Look for a directory entry in a directory.
// If found, set *poff to byte offset of entry.
struct inode*
dirlookup(struct inode *dp, char *name, uint *poff)
{
    8000414c:	7139                	addi	sp,sp,-64
    8000414e:	fc06                	sd	ra,56(sp)
    80004150:	f822                	sd	s0,48(sp)
    80004152:	f426                	sd	s1,40(sp)
    80004154:	f04a                	sd	s2,32(sp)
    80004156:	ec4e                	sd	s3,24(sp)
    80004158:	e852                	sd	s4,16(sp)
    8000415a:	0080                	addi	s0,sp,64
  uint off, inum;
  struct dirent de;

  if(dp->type != T_DIR)
    8000415c:	04451703          	lh	a4,68(a0)
    80004160:	4785                	li	a5,1
    80004162:	00f71a63          	bne	a4,a5,80004176 <dirlookup+0x2a>
    80004166:	892a                	mv	s2,a0
    80004168:	89ae                	mv	s3,a1
    8000416a:	8a32                	mv	s4,a2
    panic("dirlookup not DIR");

  for(off = 0; off < dp->size; off += sizeof(de)){
    8000416c:	457c                	lw	a5,76(a0)
    8000416e:	4481                	li	s1,0
      inum = de.inum;
      return iget(dp->dev, inum);
    }
  }

  return 0;
    80004170:	4501                	li	a0,0
  for(off = 0; off < dp->size; off += sizeof(de)){
    80004172:	e79d                	bnez	a5,800041a0 <dirlookup+0x54>
    80004174:	a8a5                	j	800041ec <dirlookup+0xa0>
    panic("dirlookup not DIR");
    80004176:	00004517          	auipc	a0,0x4
    8000417a:	39a50513          	addi	a0,a0,922 # 80008510 <etext+0x510>
    8000417e:	ffffc097          	auipc	ra,0xffffc
    80004182:	3e2080e7          	jalr	994(ra) # 80000560 <panic>
      panic("dirlookup read");
    80004186:	00004517          	auipc	a0,0x4
    8000418a:	3a250513          	addi	a0,a0,930 # 80008528 <etext+0x528>
    8000418e:	ffffc097          	auipc	ra,0xffffc
    80004192:	3d2080e7          	jalr	978(ra) # 80000560 <panic>
  for(off = 0; off < dp->size; off += sizeof(de)){
    80004196:	24c1                	addiw	s1,s1,16
    80004198:	04c92783          	lw	a5,76(s2)
    8000419c:	04f4f763          	bgeu	s1,a5,800041ea <dirlookup+0x9e>
    if(readi(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    800041a0:	4741                	li	a4,16
    800041a2:	86a6                	mv	a3,s1
    800041a4:	fc040613          	addi	a2,s0,-64
    800041a8:	4581                	li	a1,0
    800041aa:	854a                	mv	a0,s2
    800041ac:	00000097          	auipc	ra,0x0
    800041b0:	d4c080e7          	jalr	-692(ra) # 80003ef8 <readi>
    800041b4:	47c1                	li	a5,16
    800041b6:	fcf518e3          	bne	a0,a5,80004186 <dirlookup+0x3a>
    if(de.inum == 0)
    800041ba:	fc045783          	lhu	a5,-64(s0)
    800041be:	dfe1                	beqz	a5,80004196 <dirlookup+0x4a>
    if(namecmp(name, de.name) == 0){
    800041c0:	fc240593          	addi	a1,s0,-62
    800041c4:	854e                	mv	a0,s3
    800041c6:	00000097          	auipc	ra,0x0
    800041ca:	f6c080e7          	jalr	-148(ra) # 80004132 <namecmp>
    800041ce:	f561                	bnez	a0,80004196 <dirlookup+0x4a>
      if(poff)
    800041d0:	000a0463          	beqz	s4,800041d8 <dirlookup+0x8c>
        *poff = off;
    800041d4:	009a2023          	sw	s1,0(s4)
      return iget(dp->dev, inum);
    800041d8:	fc045583          	lhu	a1,-64(s0)
    800041dc:	00092503          	lw	a0,0(s2)
    800041e0:	fffff097          	auipc	ra,0xfffff
    800041e4:	720080e7          	jalr	1824(ra) # 80003900 <iget>
    800041e8:	a011                	j	800041ec <dirlookup+0xa0>
  return 0;
    800041ea:	4501                	li	a0,0
}
    800041ec:	70e2                	ld	ra,56(sp)
    800041ee:	7442                	ld	s0,48(sp)
    800041f0:	74a2                	ld	s1,40(sp)
    800041f2:	7902                	ld	s2,32(sp)
    800041f4:	69e2                	ld	s3,24(sp)
    800041f6:	6a42                	ld	s4,16(sp)
    800041f8:	6121                	addi	sp,sp,64
    800041fa:	8082                	ret

00000000800041fc <namex>:
// If parent != 0, return the inode for the parent and copy the final
// path element into name, which must have room for DIRSIZ bytes.
// Must be called inside a transaction since it calls iput().
static struct inode*
namex(char *path, int nameiparent, char *name)
{
    800041fc:	711d                	addi	sp,sp,-96
    800041fe:	ec86                	sd	ra,88(sp)
    80004200:	e8a2                	sd	s0,80(sp)
    80004202:	e4a6                	sd	s1,72(sp)
    80004204:	e0ca                	sd	s2,64(sp)
    80004206:	fc4e                	sd	s3,56(sp)
    80004208:	f852                	sd	s4,48(sp)
    8000420a:	f456                	sd	s5,40(sp)
    8000420c:	f05a                	sd	s6,32(sp)
    8000420e:	ec5e                	sd	s7,24(sp)
    80004210:	e862                	sd	s8,16(sp)
    80004212:	e466                	sd	s9,8(sp)
    80004214:	1080                	addi	s0,sp,96
    80004216:	84aa                	mv	s1,a0
    80004218:	8b2e                	mv	s6,a1
    8000421a:	8ab2                	mv	s5,a2
  struct inode *ip, *next;

  if(*path == '/')
    8000421c:	00054703          	lbu	a4,0(a0)
    80004220:	02f00793          	li	a5,47
    80004224:	02f70263          	beq	a4,a5,80004248 <namex+0x4c>
    ip = iget(ROOTDEV, ROOTINO);
  else
    ip = idup(myproc()->cwd);
    80004228:	ffffe097          	auipc	ra,0xffffe
    8000422c:	a0e080e7          	jalr	-1522(ra) # 80001c36 <myproc>
    80004230:	15853503          	ld	a0,344(a0)
    80004234:	00000097          	auipc	ra,0x0
    80004238:	9ce080e7          	jalr	-1586(ra) # 80003c02 <idup>
    8000423c:	8a2a                	mv	s4,a0
  while(*path == '/')
    8000423e:	02f00913          	li	s2,47
  if(len >= DIRSIZ)
    80004242:	4c35                	li	s8,13

  while((path = skipelem(path, name)) != 0){
    ilock(ip);
    if(ip->type != T_DIR){
    80004244:	4b85                	li	s7,1
    80004246:	a875                	j	80004302 <namex+0x106>
    ip = iget(ROOTDEV, ROOTINO);
    80004248:	4585                	li	a1,1
    8000424a:	4505                	li	a0,1
    8000424c:	fffff097          	auipc	ra,0xfffff
    80004250:	6b4080e7          	jalr	1716(ra) # 80003900 <iget>
    80004254:	8a2a                	mv	s4,a0
    80004256:	b7e5                	j	8000423e <namex+0x42>
      iunlockput(ip);
    80004258:	8552                	mv	a0,s4
    8000425a:	00000097          	auipc	ra,0x0
    8000425e:	c4c080e7          	jalr	-948(ra) # 80003ea6 <iunlockput>
      return 0;
    80004262:	4a01                	li	s4,0
  if(nameiparent){
    iput(ip);
    return 0;
  }
  return ip;
}
    80004264:	8552                	mv	a0,s4
    80004266:	60e6                	ld	ra,88(sp)
    80004268:	6446                	ld	s0,80(sp)
    8000426a:	64a6                	ld	s1,72(sp)
    8000426c:	6906                	ld	s2,64(sp)
    8000426e:	79e2                	ld	s3,56(sp)
    80004270:	7a42                	ld	s4,48(sp)
    80004272:	7aa2                	ld	s5,40(sp)
    80004274:	7b02                	ld	s6,32(sp)
    80004276:	6be2                	ld	s7,24(sp)
    80004278:	6c42                	ld	s8,16(sp)
    8000427a:	6ca2                	ld	s9,8(sp)
    8000427c:	6125                	addi	sp,sp,96
    8000427e:	8082                	ret
      iunlock(ip);
    80004280:	8552                	mv	a0,s4
    80004282:	00000097          	auipc	ra,0x0
    80004286:	a84080e7          	jalr	-1404(ra) # 80003d06 <iunlock>
      return ip;
    8000428a:	bfe9                	j	80004264 <namex+0x68>
      iunlockput(ip);
    8000428c:	8552                	mv	a0,s4
    8000428e:	00000097          	auipc	ra,0x0
    80004292:	c18080e7          	jalr	-1000(ra) # 80003ea6 <iunlockput>
      return 0;
    80004296:	8a4e                	mv	s4,s3
    80004298:	b7f1                	j	80004264 <namex+0x68>
  len = path - s;
    8000429a:	40998633          	sub	a2,s3,s1
    8000429e:	00060c9b          	sext.w	s9,a2
  if(len >= DIRSIZ)
    800042a2:	099c5863          	bge	s8,s9,80004332 <namex+0x136>
    memmove(name, s, DIRSIZ);
    800042a6:	4639                	li	a2,14
    800042a8:	85a6                	mv	a1,s1
    800042aa:	8556                	mv	a0,s5
    800042ac:	ffffd097          	auipc	ra,0xffffd
    800042b0:	c1a080e7          	jalr	-998(ra) # 80000ec6 <memmove>
    800042b4:	84ce                	mv	s1,s3
  while(*path == '/')
    800042b6:	0004c783          	lbu	a5,0(s1)
    800042ba:	01279763          	bne	a5,s2,800042c8 <namex+0xcc>
    path++;
    800042be:	0485                	addi	s1,s1,1
  while(*path == '/')
    800042c0:	0004c783          	lbu	a5,0(s1)
    800042c4:	ff278de3          	beq	a5,s2,800042be <namex+0xc2>
    ilock(ip);
    800042c8:	8552                	mv	a0,s4
    800042ca:	00000097          	auipc	ra,0x0
    800042ce:	976080e7          	jalr	-1674(ra) # 80003c40 <ilock>
    if(ip->type != T_DIR){
    800042d2:	044a1783          	lh	a5,68(s4)
    800042d6:	f97791e3          	bne	a5,s7,80004258 <namex+0x5c>
    if(nameiparent && *path == '\0'){
    800042da:	000b0563          	beqz	s6,800042e4 <namex+0xe8>
    800042de:	0004c783          	lbu	a5,0(s1)
    800042e2:	dfd9                	beqz	a5,80004280 <namex+0x84>
    if((next = dirlookup(ip, name, 0)) == 0){
    800042e4:	4601                	li	a2,0
    800042e6:	85d6                	mv	a1,s5
    800042e8:	8552                	mv	a0,s4
    800042ea:	00000097          	auipc	ra,0x0
    800042ee:	e62080e7          	jalr	-414(ra) # 8000414c <dirlookup>
    800042f2:	89aa                	mv	s3,a0
    800042f4:	dd41                	beqz	a0,8000428c <namex+0x90>
    iunlockput(ip);
    800042f6:	8552                	mv	a0,s4
    800042f8:	00000097          	auipc	ra,0x0
    800042fc:	bae080e7          	jalr	-1106(ra) # 80003ea6 <iunlockput>
    ip = next;
    80004300:	8a4e                	mv	s4,s3
  while(*path == '/')
    80004302:	0004c783          	lbu	a5,0(s1)
    80004306:	01279763          	bne	a5,s2,80004314 <namex+0x118>
    path++;
    8000430a:	0485                	addi	s1,s1,1
  while(*path == '/')
    8000430c:	0004c783          	lbu	a5,0(s1)
    80004310:	ff278de3          	beq	a5,s2,8000430a <namex+0x10e>
  if(*path == 0)
    80004314:	cb9d                	beqz	a5,8000434a <namex+0x14e>
  while(*path != '/' && *path != 0)
    80004316:	0004c783          	lbu	a5,0(s1)
    8000431a:	89a6                	mv	s3,s1
  len = path - s;
    8000431c:	4c81                	li	s9,0
    8000431e:	4601                	li	a2,0
  while(*path != '/' && *path != 0)
    80004320:	01278963          	beq	a5,s2,80004332 <namex+0x136>
    80004324:	dbbd                	beqz	a5,8000429a <namex+0x9e>
    path++;
    80004326:	0985                	addi	s3,s3,1
  while(*path != '/' && *path != 0)
    80004328:	0009c783          	lbu	a5,0(s3)
    8000432c:	ff279ce3          	bne	a5,s2,80004324 <namex+0x128>
    80004330:	b7ad                	j	8000429a <namex+0x9e>
    memmove(name, s, len);
    80004332:	2601                	sext.w	a2,a2
    80004334:	85a6                	mv	a1,s1
    80004336:	8556                	mv	a0,s5
    80004338:	ffffd097          	auipc	ra,0xffffd
    8000433c:	b8e080e7          	jalr	-1138(ra) # 80000ec6 <memmove>
    name[len] = 0;
    80004340:	9cd6                	add	s9,s9,s5
    80004342:	000c8023          	sb	zero,0(s9) # 2000 <_entry-0x7fffe000>
    80004346:	84ce                	mv	s1,s3
    80004348:	b7bd                	j	800042b6 <namex+0xba>
  if(nameiparent){
    8000434a:	f00b0de3          	beqz	s6,80004264 <namex+0x68>
    iput(ip);
    8000434e:	8552                	mv	a0,s4
    80004350:	00000097          	auipc	ra,0x0
    80004354:	aae080e7          	jalr	-1362(ra) # 80003dfe <iput>
    return 0;
    80004358:	4a01                	li	s4,0
    8000435a:	b729                	j	80004264 <namex+0x68>

000000008000435c <dirlink>:
{
    8000435c:	7139                	addi	sp,sp,-64
    8000435e:	fc06                	sd	ra,56(sp)
    80004360:	f822                	sd	s0,48(sp)
    80004362:	f04a                	sd	s2,32(sp)
    80004364:	ec4e                	sd	s3,24(sp)
    80004366:	e852                	sd	s4,16(sp)
    80004368:	0080                	addi	s0,sp,64
    8000436a:	892a                	mv	s2,a0
    8000436c:	8a2e                	mv	s4,a1
    8000436e:	89b2                	mv	s3,a2
  if((ip = dirlookup(dp, name, 0)) != 0){
    80004370:	4601                	li	a2,0
    80004372:	00000097          	auipc	ra,0x0
    80004376:	dda080e7          	jalr	-550(ra) # 8000414c <dirlookup>
    8000437a:	ed25                	bnez	a0,800043f2 <dirlink+0x96>
    8000437c:	f426                	sd	s1,40(sp)
  for(off = 0; off < dp->size; off += sizeof(de)){
    8000437e:	04c92483          	lw	s1,76(s2)
    80004382:	c49d                	beqz	s1,800043b0 <dirlink+0x54>
    80004384:	4481                	li	s1,0
    if(readi(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    80004386:	4741                	li	a4,16
    80004388:	86a6                	mv	a3,s1
    8000438a:	fc040613          	addi	a2,s0,-64
    8000438e:	4581                	li	a1,0
    80004390:	854a                	mv	a0,s2
    80004392:	00000097          	auipc	ra,0x0
    80004396:	b66080e7          	jalr	-1178(ra) # 80003ef8 <readi>
    8000439a:	47c1                	li	a5,16
    8000439c:	06f51163          	bne	a0,a5,800043fe <dirlink+0xa2>
    if(de.inum == 0)
    800043a0:	fc045783          	lhu	a5,-64(s0)
    800043a4:	c791                	beqz	a5,800043b0 <dirlink+0x54>
  for(off = 0; off < dp->size; off += sizeof(de)){
    800043a6:	24c1                	addiw	s1,s1,16
    800043a8:	04c92783          	lw	a5,76(s2)
    800043ac:	fcf4ede3          	bltu	s1,a5,80004386 <dirlink+0x2a>
  strncpy(de.name, name, DIRSIZ);
    800043b0:	4639                	li	a2,14
    800043b2:	85d2                	mv	a1,s4
    800043b4:	fc240513          	addi	a0,s0,-62
    800043b8:	ffffd097          	auipc	ra,0xffffd
    800043bc:	bb8080e7          	jalr	-1096(ra) # 80000f70 <strncpy>
  de.inum = inum;
    800043c0:	fd341023          	sh	s3,-64(s0)
  if(writei(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    800043c4:	4741                	li	a4,16
    800043c6:	86a6                	mv	a3,s1
    800043c8:	fc040613          	addi	a2,s0,-64
    800043cc:	4581                	li	a1,0
    800043ce:	854a                	mv	a0,s2
    800043d0:	00000097          	auipc	ra,0x0
    800043d4:	c38080e7          	jalr	-968(ra) # 80004008 <writei>
    800043d8:	1541                	addi	a0,a0,-16
    800043da:	00a03533          	snez	a0,a0
    800043de:	40a00533          	neg	a0,a0
    800043e2:	74a2                	ld	s1,40(sp)
}
    800043e4:	70e2                	ld	ra,56(sp)
    800043e6:	7442                	ld	s0,48(sp)
    800043e8:	7902                	ld	s2,32(sp)
    800043ea:	69e2                	ld	s3,24(sp)
    800043ec:	6a42                	ld	s4,16(sp)
    800043ee:	6121                	addi	sp,sp,64
    800043f0:	8082                	ret
    iput(ip);
    800043f2:	00000097          	auipc	ra,0x0
    800043f6:	a0c080e7          	jalr	-1524(ra) # 80003dfe <iput>
    return -1;
    800043fa:	557d                	li	a0,-1
    800043fc:	b7e5                	j	800043e4 <dirlink+0x88>
      panic("dirlink read");
    800043fe:	00004517          	auipc	a0,0x4
    80004402:	13a50513          	addi	a0,a0,314 # 80008538 <etext+0x538>
    80004406:	ffffc097          	auipc	ra,0xffffc
    8000440a:	15a080e7          	jalr	346(ra) # 80000560 <panic>

000000008000440e <namei>:

struct inode*
namei(char *path)
{
    8000440e:	1101                	addi	sp,sp,-32
    80004410:	ec06                	sd	ra,24(sp)
    80004412:	e822                	sd	s0,16(sp)
    80004414:	1000                	addi	s0,sp,32
  char name[DIRSIZ];
  return namex(path, 0, name);
    80004416:	fe040613          	addi	a2,s0,-32
    8000441a:	4581                	li	a1,0
    8000441c:	00000097          	auipc	ra,0x0
    80004420:	de0080e7          	jalr	-544(ra) # 800041fc <namex>
}
    80004424:	60e2                	ld	ra,24(sp)
    80004426:	6442                	ld	s0,16(sp)
    80004428:	6105                	addi	sp,sp,32
    8000442a:	8082                	ret

000000008000442c <nameiparent>:

struct inode*
nameiparent(char *path, char *name)
{
    8000442c:	1141                	addi	sp,sp,-16
    8000442e:	e406                	sd	ra,8(sp)
    80004430:	e022                	sd	s0,0(sp)
    80004432:	0800                	addi	s0,sp,16
    80004434:	862e                	mv	a2,a1
  return namex(path, 1, name);
    80004436:	4585                	li	a1,1
    80004438:	00000097          	auipc	ra,0x0
    8000443c:	dc4080e7          	jalr	-572(ra) # 800041fc <namex>
}
    80004440:	60a2                	ld	ra,8(sp)
    80004442:	6402                	ld	s0,0(sp)
    80004444:	0141                	addi	sp,sp,16
    80004446:	8082                	ret

0000000080004448 <write_head>:
// Write in-memory log header to disk.
// This is the true point at which the
// current transaction commits.
static void
write_head(void)
{
    80004448:	1101                	addi	sp,sp,-32
    8000444a:	ec06                	sd	ra,24(sp)
    8000444c:	e822                	sd	s0,16(sp)
    8000444e:	e426                	sd	s1,8(sp)
    80004450:	e04a                	sd	s2,0(sp)
    80004452:	1000                	addi	s0,sp,32
  struct buf *buf = bread(log.dev, log.start);
    80004454:	0023d917          	auipc	s2,0x23d
    80004458:	cfc90913          	addi	s2,s2,-772 # 80241150 <log>
    8000445c:	01892583          	lw	a1,24(s2)
    80004460:	02892503          	lw	a0,40(s2)
    80004464:	fffff097          	auipc	ra,0xfffff
    80004468:	fa8080e7          	jalr	-88(ra) # 8000340c <bread>
    8000446c:	84aa                	mv	s1,a0
  struct logheader *hb = (struct logheader *) (buf->data);
  int i;
  hb->n = log.lh.n;
    8000446e:	02c92603          	lw	a2,44(s2)
    80004472:	cd30                	sw	a2,88(a0)
  for (i = 0; i < log.lh.n; i++) {
    80004474:	00c05f63          	blez	a2,80004492 <write_head+0x4a>
    80004478:	0023d717          	auipc	a4,0x23d
    8000447c:	d0870713          	addi	a4,a4,-760 # 80241180 <log+0x30>
    80004480:	87aa                	mv	a5,a0
    80004482:	060a                	slli	a2,a2,0x2
    80004484:	962a                	add	a2,a2,a0
    hb->block[i] = log.lh.block[i];
    80004486:	4314                	lw	a3,0(a4)
    80004488:	cff4                	sw	a3,92(a5)
  for (i = 0; i < log.lh.n; i++) {
    8000448a:	0711                	addi	a4,a4,4
    8000448c:	0791                	addi	a5,a5,4
    8000448e:	fec79ce3          	bne	a5,a2,80004486 <write_head+0x3e>
  }
  bwrite(buf);
    80004492:	8526                	mv	a0,s1
    80004494:	fffff097          	auipc	ra,0xfffff
    80004498:	06a080e7          	jalr	106(ra) # 800034fe <bwrite>
  brelse(buf);
    8000449c:	8526                	mv	a0,s1
    8000449e:	fffff097          	auipc	ra,0xfffff
    800044a2:	09e080e7          	jalr	158(ra) # 8000353c <brelse>
}
    800044a6:	60e2                	ld	ra,24(sp)
    800044a8:	6442                	ld	s0,16(sp)
    800044aa:	64a2                	ld	s1,8(sp)
    800044ac:	6902                	ld	s2,0(sp)
    800044ae:	6105                	addi	sp,sp,32
    800044b0:	8082                	ret

00000000800044b2 <install_trans>:
  for (tail = 0; tail < log.lh.n; tail++) {
    800044b2:	0023d797          	auipc	a5,0x23d
    800044b6:	cca7a783          	lw	a5,-822(a5) # 8024117c <log+0x2c>
    800044ba:	0af05d63          	blez	a5,80004574 <install_trans+0xc2>
{
    800044be:	7139                	addi	sp,sp,-64
    800044c0:	fc06                	sd	ra,56(sp)
    800044c2:	f822                	sd	s0,48(sp)
    800044c4:	f426                	sd	s1,40(sp)
    800044c6:	f04a                	sd	s2,32(sp)
    800044c8:	ec4e                	sd	s3,24(sp)
    800044ca:	e852                	sd	s4,16(sp)
    800044cc:	e456                	sd	s5,8(sp)
    800044ce:	e05a                	sd	s6,0(sp)
    800044d0:	0080                	addi	s0,sp,64
    800044d2:	8b2a                	mv	s6,a0
    800044d4:	0023da97          	auipc	s5,0x23d
    800044d8:	caca8a93          	addi	s5,s5,-852 # 80241180 <log+0x30>
  for (tail = 0; tail < log.lh.n; tail++) {
    800044dc:	4a01                	li	s4,0
    struct buf *lbuf = bread(log.dev, log.start+tail+1); // read log block
    800044de:	0023d997          	auipc	s3,0x23d
    800044e2:	c7298993          	addi	s3,s3,-910 # 80241150 <log>
    800044e6:	a00d                	j	80004508 <install_trans+0x56>
    brelse(lbuf);
    800044e8:	854a                	mv	a0,s2
    800044ea:	fffff097          	auipc	ra,0xfffff
    800044ee:	052080e7          	jalr	82(ra) # 8000353c <brelse>
    brelse(dbuf);
    800044f2:	8526                	mv	a0,s1
    800044f4:	fffff097          	auipc	ra,0xfffff
    800044f8:	048080e7          	jalr	72(ra) # 8000353c <brelse>
  for (tail = 0; tail < log.lh.n; tail++) {
    800044fc:	2a05                	addiw	s4,s4,1
    800044fe:	0a91                	addi	s5,s5,4
    80004500:	02c9a783          	lw	a5,44(s3)
    80004504:	04fa5e63          	bge	s4,a5,80004560 <install_trans+0xae>
    struct buf *lbuf = bread(log.dev, log.start+tail+1); // read log block
    80004508:	0189a583          	lw	a1,24(s3)
    8000450c:	014585bb          	addw	a1,a1,s4
    80004510:	2585                	addiw	a1,a1,1
    80004512:	0289a503          	lw	a0,40(s3)
    80004516:	fffff097          	auipc	ra,0xfffff
    8000451a:	ef6080e7          	jalr	-266(ra) # 8000340c <bread>
    8000451e:	892a                	mv	s2,a0
    struct buf *dbuf = bread(log.dev, log.lh.block[tail]); // read dst
    80004520:	000aa583          	lw	a1,0(s5)
    80004524:	0289a503          	lw	a0,40(s3)
    80004528:	fffff097          	auipc	ra,0xfffff
    8000452c:	ee4080e7          	jalr	-284(ra) # 8000340c <bread>
    80004530:	84aa                	mv	s1,a0
    memmove(dbuf->data, lbuf->data, BSIZE);  // copy block to dst
    80004532:	40000613          	li	a2,1024
    80004536:	05890593          	addi	a1,s2,88
    8000453a:	05850513          	addi	a0,a0,88
    8000453e:	ffffd097          	auipc	ra,0xffffd
    80004542:	988080e7          	jalr	-1656(ra) # 80000ec6 <memmove>
    bwrite(dbuf);  // write dst to disk
    80004546:	8526                	mv	a0,s1
    80004548:	fffff097          	auipc	ra,0xfffff
    8000454c:	fb6080e7          	jalr	-74(ra) # 800034fe <bwrite>
    if(recovering == 0)
    80004550:	f80b1ce3          	bnez	s6,800044e8 <install_trans+0x36>
      bunpin(dbuf);
    80004554:	8526                	mv	a0,s1
    80004556:	fffff097          	auipc	ra,0xfffff
    8000455a:	0be080e7          	jalr	190(ra) # 80003614 <bunpin>
    8000455e:	b769                	j	800044e8 <install_trans+0x36>
}
    80004560:	70e2                	ld	ra,56(sp)
    80004562:	7442                	ld	s0,48(sp)
    80004564:	74a2                	ld	s1,40(sp)
    80004566:	7902                	ld	s2,32(sp)
    80004568:	69e2                	ld	s3,24(sp)
    8000456a:	6a42                	ld	s4,16(sp)
    8000456c:	6aa2                	ld	s5,8(sp)
    8000456e:	6b02                	ld	s6,0(sp)
    80004570:	6121                	addi	sp,sp,64
    80004572:	8082                	ret
    80004574:	8082                	ret

0000000080004576 <initlog>:
{
    80004576:	7179                	addi	sp,sp,-48
    80004578:	f406                	sd	ra,40(sp)
    8000457a:	f022                	sd	s0,32(sp)
    8000457c:	ec26                	sd	s1,24(sp)
    8000457e:	e84a                	sd	s2,16(sp)
    80004580:	e44e                	sd	s3,8(sp)
    80004582:	1800                	addi	s0,sp,48
    80004584:	892a                	mv	s2,a0
    80004586:	89ae                	mv	s3,a1
  initlock(&log.lock, "log");
    80004588:	0023d497          	auipc	s1,0x23d
    8000458c:	bc848493          	addi	s1,s1,-1080 # 80241150 <log>
    80004590:	00004597          	auipc	a1,0x4
    80004594:	fb858593          	addi	a1,a1,-72 # 80008548 <etext+0x548>
    80004598:	8526                	mv	a0,s1
    8000459a:	ffffc097          	auipc	ra,0xffffc
    8000459e:	744080e7          	jalr	1860(ra) # 80000cde <initlock>
  log.start = sb->logstart;
    800045a2:	0149a583          	lw	a1,20(s3)
    800045a6:	cc8c                	sw	a1,24(s1)
  log.size = sb->nlog;
    800045a8:	0109a783          	lw	a5,16(s3)
    800045ac:	ccdc                	sw	a5,28(s1)
  log.dev = dev;
    800045ae:	0324a423          	sw	s2,40(s1)
  struct buf *buf = bread(log.dev, log.start);
    800045b2:	854a                	mv	a0,s2
    800045b4:	fffff097          	auipc	ra,0xfffff
    800045b8:	e58080e7          	jalr	-424(ra) # 8000340c <bread>
  log.lh.n = lh->n;
    800045bc:	4d30                	lw	a2,88(a0)
    800045be:	d4d0                	sw	a2,44(s1)
  for (i = 0; i < log.lh.n; i++) {
    800045c0:	00c05f63          	blez	a2,800045de <initlog+0x68>
    800045c4:	87aa                	mv	a5,a0
    800045c6:	0023d717          	auipc	a4,0x23d
    800045ca:	bba70713          	addi	a4,a4,-1094 # 80241180 <log+0x30>
    800045ce:	060a                	slli	a2,a2,0x2
    800045d0:	962a                	add	a2,a2,a0
    log.lh.block[i] = lh->block[i];
    800045d2:	4ff4                	lw	a3,92(a5)
    800045d4:	c314                	sw	a3,0(a4)
  for (i = 0; i < log.lh.n; i++) {
    800045d6:	0791                	addi	a5,a5,4
    800045d8:	0711                	addi	a4,a4,4
    800045da:	fec79ce3          	bne	a5,a2,800045d2 <initlog+0x5c>
  brelse(buf);
    800045de:	fffff097          	auipc	ra,0xfffff
    800045e2:	f5e080e7          	jalr	-162(ra) # 8000353c <brelse>

static void
recover_from_log(void)
{
  read_head();
  install_trans(1); // if committed, copy from log to disk
    800045e6:	4505                	li	a0,1
    800045e8:	00000097          	auipc	ra,0x0
    800045ec:	eca080e7          	jalr	-310(ra) # 800044b2 <install_trans>
  log.lh.n = 0;
    800045f0:	0023d797          	auipc	a5,0x23d
    800045f4:	b807a623          	sw	zero,-1140(a5) # 8024117c <log+0x2c>
  write_head(); // clear the log
    800045f8:	00000097          	auipc	ra,0x0
    800045fc:	e50080e7          	jalr	-432(ra) # 80004448 <write_head>
}
    80004600:	70a2                	ld	ra,40(sp)
    80004602:	7402                	ld	s0,32(sp)
    80004604:	64e2                	ld	s1,24(sp)
    80004606:	6942                	ld	s2,16(sp)
    80004608:	69a2                	ld	s3,8(sp)
    8000460a:	6145                	addi	sp,sp,48
    8000460c:	8082                	ret

000000008000460e <begin_op>:
}

// called at the start of each FS system call.
void
begin_op(void)
{
    8000460e:	1101                	addi	sp,sp,-32
    80004610:	ec06                	sd	ra,24(sp)
    80004612:	e822                	sd	s0,16(sp)
    80004614:	e426                	sd	s1,8(sp)
    80004616:	e04a                	sd	s2,0(sp)
    80004618:	1000                	addi	s0,sp,32
  acquire(&log.lock);
    8000461a:	0023d517          	auipc	a0,0x23d
    8000461e:	b3650513          	addi	a0,a0,-1226 # 80241150 <log>
    80004622:	ffffc097          	auipc	ra,0xffffc
    80004626:	74c080e7          	jalr	1868(ra) # 80000d6e <acquire>
  while(1){
    if(log.committing){
    8000462a:	0023d497          	auipc	s1,0x23d
    8000462e:	b2648493          	addi	s1,s1,-1242 # 80241150 <log>
      sleep(&log, &log.lock);
    } else if(log.lh.n + (log.outstanding+1)*MAXOPBLOCKS > LOGSIZE){
    80004632:	4979                	li	s2,30
    80004634:	a039                	j	80004642 <begin_op+0x34>
      sleep(&log, &log.lock);
    80004636:	85a6                	mv	a1,s1
    80004638:	8526                	mv	a0,s1
    8000463a:	ffffe097          	auipc	ra,0xffffe
    8000463e:	ce2080e7          	jalr	-798(ra) # 8000231c <sleep>
    if(log.committing){
    80004642:	50dc                	lw	a5,36(s1)
    80004644:	fbed                	bnez	a5,80004636 <begin_op+0x28>
    } else if(log.lh.n + (log.outstanding+1)*MAXOPBLOCKS > LOGSIZE){
    80004646:	5098                	lw	a4,32(s1)
    80004648:	2705                	addiw	a4,a4,1
    8000464a:	0027179b          	slliw	a5,a4,0x2
    8000464e:	9fb9                	addw	a5,a5,a4
    80004650:	0017979b          	slliw	a5,a5,0x1
    80004654:	54d4                	lw	a3,44(s1)
    80004656:	9fb5                	addw	a5,a5,a3
    80004658:	00f95963          	bge	s2,a5,8000466a <begin_op+0x5c>
      // this op might exhaust log space; wait for commit.
      sleep(&log, &log.lock);
    8000465c:	85a6                	mv	a1,s1
    8000465e:	8526                	mv	a0,s1
    80004660:	ffffe097          	auipc	ra,0xffffe
    80004664:	cbc080e7          	jalr	-836(ra) # 8000231c <sleep>
    80004668:	bfe9                	j	80004642 <begin_op+0x34>
    } else {
      log.outstanding += 1;
    8000466a:	0023d517          	auipc	a0,0x23d
    8000466e:	ae650513          	addi	a0,a0,-1306 # 80241150 <log>
    80004672:	d118                	sw	a4,32(a0)
      release(&log.lock);
    80004674:	ffffc097          	auipc	ra,0xffffc
    80004678:	7ae080e7          	jalr	1966(ra) # 80000e22 <release>
      break;
    }
  }
}
    8000467c:	60e2                	ld	ra,24(sp)
    8000467e:	6442                	ld	s0,16(sp)
    80004680:	64a2                	ld	s1,8(sp)
    80004682:	6902                	ld	s2,0(sp)
    80004684:	6105                	addi	sp,sp,32
    80004686:	8082                	ret

0000000080004688 <end_op>:

// called at the end of each FS system call.
// commits if this was the last outstanding operation.
void
end_op(void)
{
    80004688:	7139                	addi	sp,sp,-64
    8000468a:	fc06                	sd	ra,56(sp)
    8000468c:	f822                	sd	s0,48(sp)
    8000468e:	f426                	sd	s1,40(sp)
    80004690:	f04a                	sd	s2,32(sp)
    80004692:	0080                	addi	s0,sp,64
  int do_commit = 0;

  acquire(&log.lock);
    80004694:	0023d497          	auipc	s1,0x23d
    80004698:	abc48493          	addi	s1,s1,-1348 # 80241150 <log>
    8000469c:	8526                	mv	a0,s1
    8000469e:	ffffc097          	auipc	ra,0xffffc
    800046a2:	6d0080e7          	jalr	1744(ra) # 80000d6e <acquire>
  log.outstanding -= 1;
    800046a6:	509c                	lw	a5,32(s1)
    800046a8:	37fd                	addiw	a5,a5,-1
    800046aa:	0007891b          	sext.w	s2,a5
    800046ae:	d09c                	sw	a5,32(s1)
  if(log.committing)
    800046b0:	50dc                	lw	a5,36(s1)
    800046b2:	e7b9                	bnez	a5,80004700 <end_op+0x78>
    panic("log.committing");
  if(log.outstanding == 0){
    800046b4:	06091163          	bnez	s2,80004716 <end_op+0x8e>
    do_commit = 1;
    log.committing = 1;
    800046b8:	0023d497          	auipc	s1,0x23d
    800046bc:	a9848493          	addi	s1,s1,-1384 # 80241150 <log>
    800046c0:	4785                	li	a5,1
    800046c2:	d0dc                	sw	a5,36(s1)
    // begin_op() may be waiting for log space,
    // and decrementing log.outstanding has decreased
    // the amount of reserved space.
    wakeup(&log);
  }
  release(&log.lock);
    800046c4:	8526                	mv	a0,s1
    800046c6:	ffffc097          	auipc	ra,0xffffc
    800046ca:	75c080e7          	jalr	1884(ra) # 80000e22 <release>
}

static void
commit()
{
  if (log.lh.n > 0) {
    800046ce:	54dc                	lw	a5,44(s1)
    800046d0:	06f04763          	bgtz	a5,8000473e <end_op+0xb6>
    acquire(&log.lock);
    800046d4:	0023d497          	auipc	s1,0x23d
    800046d8:	a7c48493          	addi	s1,s1,-1412 # 80241150 <log>
    800046dc:	8526                	mv	a0,s1
    800046de:	ffffc097          	auipc	ra,0xffffc
    800046e2:	690080e7          	jalr	1680(ra) # 80000d6e <acquire>
    log.committing = 0;
    800046e6:	0204a223          	sw	zero,36(s1)
    wakeup(&log);
    800046ea:	8526                	mv	a0,s1
    800046ec:	ffffe097          	auipc	ra,0xffffe
    800046f0:	c9e080e7          	jalr	-866(ra) # 8000238a <wakeup>
    release(&log.lock);
    800046f4:	8526                	mv	a0,s1
    800046f6:	ffffc097          	auipc	ra,0xffffc
    800046fa:	72c080e7          	jalr	1836(ra) # 80000e22 <release>
}
    800046fe:	a815                	j	80004732 <end_op+0xaa>
    80004700:	ec4e                	sd	s3,24(sp)
    80004702:	e852                	sd	s4,16(sp)
    80004704:	e456                	sd	s5,8(sp)
    panic("log.committing");
    80004706:	00004517          	auipc	a0,0x4
    8000470a:	e4a50513          	addi	a0,a0,-438 # 80008550 <etext+0x550>
    8000470e:	ffffc097          	auipc	ra,0xffffc
    80004712:	e52080e7          	jalr	-430(ra) # 80000560 <panic>
    wakeup(&log);
    80004716:	0023d497          	auipc	s1,0x23d
    8000471a:	a3a48493          	addi	s1,s1,-1478 # 80241150 <log>
    8000471e:	8526                	mv	a0,s1
    80004720:	ffffe097          	auipc	ra,0xffffe
    80004724:	c6a080e7          	jalr	-918(ra) # 8000238a <wakeup>
  release(&log.lock);
    80004728:	8526                	mv	a0,s1
    8000472a:	ffffc097          	auipc	ra,0xffffc
    8000472e:	6f8080e7          	jalr	1784(ra) # 80000e22 <release>
}
    80004732:	70e2                	ld	ra,56(sp)
    80004734:	7442                	ld	s0,48(sp)
    80004736:	74a2                	ld	s1,40(sp)
    80004738:	7902                	ld	s2,32(sp)
    8000473a:	6121                	addi	sp,sp,64
    8000473c:	8082                	ret
    8000473e:	ec4e                	sd	s3,24(sp)
    80004740:	e852                	sd	s4,16(sp)
    80004742:	e456                	sd	s5,8(sp)
  for (tail = 0; tail < log.lh.n; tail++) {
    80004744:	0023da97          	auipc	s5,0x23d
    80004748:	a3ca8a93          	addi	s5,s5,-1476 # 80241180 <log+0x30>
    struct buf *to = bread(log.dev, log.start+tail+1); // log block
    8000474c:	0023da17          	auipc	s4,0x23d
    80004750:	a04a0a13          	addi	s4,s4,-1532 # 80241150 <log>
    80004754:	018a2583          	lw	a1,24(s4)
    80004758:	012585bb          	addw	a1,a1,s2
    8000475c:	2585                	addiw	a1,a1,1
    8000475e:	028a2503          	lw	a0,40(s4)
    80004762:	fffff097          	auipc	ra,0xfffff
    80004766:	caa080e7          	jalr	-854(ra) # 8000340c <bread>
    8000476a:	84aa                	mv	s1,a0
    struct buf *from = bread(log.dev, log.lh.block[tail]); // cache block
    8000476c:	000aa583          	lw	a1,0(s5)
    80004770:	028a2503          	lw	a0,40(s4)
    80004774:	fffff097          	auipc	ra,0xfffff
    80004778:	c98080e7          	jalr	-872(ra) # 8000340c <bread>
    8000477c:	89aa                	mv	s3,a0
    memmove(to->data, from->data, BSIZE);
    8000477e:	40000613          	li	a2,1024
    80004782:	05850593          	addi	a1,a0,88
    80004786:	05848513          	addi	a0,s1,88
    8000478a:	ffffc097          	auipc	ra,0xffffc
    8000478e:	73c080e7          	jalr	1852(ra) # 80000ec6 <memmove>
    bwrite(to);  // write the log
    80004792:	8526                	mv	a0,s1
    80004794:	fffff097          	auipc	ra,0xfffff
    80004798:	d6a080e7          	jalr	-662(ra) # 800034fe <bwrite>
    brelse(from);
    8000479c:	854e                	mv	a0,s3
    8000479e:	fffff097          	auipc	ra,0xfffff
    800047a2:	d9e080e7          	jalr	-610(ra) # 8000353c <brelse>
    brelse(to);
    800047a6:	8526                	mv	a0,s1
    800047a8:	fffff097          	auipc	ra,0xfffff
    800047ac:	d94080e7          	jalr	-620(ra) # 8000353c <brelse>
  for (tail = 0; tail < log.lh.n; tail++) {
    800047b0:	2905                	addiw	s2,s2,1
    800047b2:	0a91                	addi	s5,s5,4
    800047b4:	02ca2783          	lw	a5,44(s4)
    800047b8:	f8f94ee3          	blt	s2,a5,80004754 <end_op+0xcc>
    write_log();     // Write modified blocks from cache to log
    write_head();    // Write header to disk -- the real commit
    800047bc:	00000097          	auipc	ra,0x0
    800047c0:	c8c080e7          	jalr	-884(ra) # 80004448 <write_head>
    install_trans(0); // Now install writes to home locations
    800047c4:	4501                	li	a0,0
    800047c6:	00000097          	auipc	ra,0x0
    800047ca:	cec080e7          	jalr	-788(ra) # 800044b2 <install_trans>
    log.lh.n = 0;
    800047ce:	0023d797          	auipc	a5,0x23d
    800047d2:	9a07a723          	sw	zero,-1618(a5) # 8024117c <log+0x2c>
    write_head();    // Erase the transaction from the log
    800047d6:	00000097          	auipc	ra,0x0
    800047da:	c72080e7          	jalr	-910(ra) # 80004448 <write_head>
    800047de:	69e2                	ld	s3,24(sp)
    800047e0:	6a42                	ld	s4,16(sp)
    800047e2:	6aa2                	ld	s5,8(sp)
    800047e4:	bdc5                	j	800046d4 <end_op+0x4c>

00000000800047e6 <log_write>:
//   modify bp->data[]
//   log_write(bp)
//   brelse(bp)
void
log_write(struct buf *b)
{
    800047e6:	1101                	addi	sp,sp,-32
    800047e8:	ec06                	sd	ra,24(sp)
    800047ea:	e822                	sd	s0,16(sp)
    800047ec:	e426                	sd	s1,8(sp)
    800047ee:	e04a                	sd	s2,0(sp)
    800047f0:	1000                	addi	s0,sp,32
    800047f2:	84aa                	mv	s1,a0
  int i;

  acquire(&log.lock);
    800047f4:	0023d917          	auipc	s2,0x23d
    800047f8:	95c90913          	addi	s2,s2,-1700 # 80241150 <log>
    800047fc:	854a                	mv	a0,s2
    800047fe:	ffffc097          	auipc	ra,0xffffc
    80004802:	570080e7          	jalr	1392(ra) # 80000d6e <acquire>
  if (log.lh.n >= LOGSIZE || log.lh.n >= log.size - 1)
    80004806:	02c92603          	lw	a2,44(s2)
    8000480a:	47f5                	li	a5,29
    8000480c:	06c7c563          	blt	a5,a2,80004876 <log_write+0x90>
    80004810:	0023d797          	auipc	a5,0x23d
    80004814:	95c7a783          	lw	a5,-1700(a5) # 8024116c <log+0x1c>
    80004818:	37fd                	addiw	a5,a5,-1
    8000481a:	04f65e63          	bge	a2,a5,80004876 <log_write+0x90>
    panic("too big a transaction");
  if (log.outstanding < 1)
    8000481e:	0023d797          	auipc	a5,0x23d
    80004822:	9527a783          	lw	a5,-1710(a5) # 80241170 <log+0x20>
    80004826:	06f05063          	blez	a5,80004886 <log_write+0xa0>
    panic("log_write outside of trans");

  for (i = 0; i < log.lh.n; i++) {
    8000482a:	4781                	li	a5,0
    8000482c:	06c05563          	blez	a2,80004896 <log_write+0xb0>
    if (log.lh.block[i] == b->blockno)   // log absorption
    80004830:	44cc                	lw	a1,12(s1)
    80004832:	0023d717          	auipc	a4,0x23d
    80004836:	94e70713          	addi	a4,a4,-1714 # 80241180 <log+0x30>
  for (i = 0; i < log.lh.n; i++) {
    8000483a:	4781                	li	a5,0
    if (log.lh.block[i] == b->blockno)   // log absorption
    8000483c:	4314                	lw	a3,0(a4)
    8000483e:	04b68c63          	beq	a3,a1,80004896 <log_write+0xb0>
  for (i = 0; i < log.lh.n; i++) {
    80004842:	2785                	addiw	a5,a5,1
    80004844:	0711                	addi	a4,a4,4
    80004846:	fef61be3          	bne	a2,a5,8000483c <log_write+0x56>
      break;
  }
  log.lh.block[i] = b->blockno;
    8000484a:	0621                	addi	a2,a2,8
    8000484c:	060a                	slli	a2,a2,0x2
    8000484e:	0023d797          	auipc	a5,0x23d
    80004852:	90278793          	addi	a5,a5,-1790 # 80241150 <log>
    80004856:	97b2                	add	a5,a5,a2
    80004858:	44d8                	lw	a4,12(s1)
    8000485a:	cb98                	sw	a4,16(a5)
  if (i == log.lh.n) {  // Add new block to log?
    bpin(b);
    8000485c:	8526                	mv	a0,s1
    8000485e:	fffff097          	auipc	ra,0xfffff
    80004862:	d7a080e7          	jalr	-646(ra) # 800035d8 <bpin>
    log.lh.n++;
    80004866:	0023d717          	auipc	a4,0x23d
    8000486a:	8ea70713          	addi	a4,a4,-1814 # 80241150 <log>
    8000486e:	575c                	lw	a5,44(a4)
    80004870:	2785                	addiw	a5,a5,1
    80004872:	d75c                	sw	a5,44(a4)
    80004874:	a82d                	j	800048ae <log_write+0xc8>
    panic("too big a transaction");
    80004876:	00004517          	auipc	a0,0x4
    8000487a:	cea50513          	addi	a0,a0,-790 # 80008560 <etext+0x560>
    8000487e:	ffffc097          	auipc	ra,0xffffc
    80004882:	ce2080e7          	jalr	-798(ra) # 80000560 <panic>
    panic("log_write outside of trans");
    80004886:	00004517          	auipc	a0,0x4
    8000488a:	cf250513          	addi	a0,a0,-782 # 80008578 <etext+0x578>
    8000488e:	ffffc097          	auipc	ra,0xffffc
    80004892:	cd2080e7          	jalr	-814(ra) # 80000560 <panic>
  log.lh.block[i] = b->blockno;
    80004896:	00878693          	addi	a3,a5,8
    8000489a:	068a                	slli	a3,a3,0x2
    8000489c:	0023d717          	auipc	a4,0x23d
    800048a0:	8b470713          	addi	a4,a4,-1868 # 80241150 <log>
    800048a4:	9736                	add	a4,a4,a3
    800048a6:	44d4                	lw	a3,12(s1)
    800048a8:	cb14                	sw	a3,16(a4)
  if (i == log.lh.n) {  // Add new block to log?
    800048aa:	faf609e3          	beq	a2,a5,8000485c <log_write+0x76>
  }
  release(&log.lock);
    800048ae:	0023d517          	auipc	a0,0x23d
    800048b2:	8a250513          	addi	a0,a0,-1886 # 80241150 <log>
    800048b6:	ffffc097          	auipc	ra,0xffffc
    800048ba:	56c080e7          	jalr	1388(ra) # 80000e22 <release>
}
    800048be:	60e2                	ld	ra,24(sp)
    800048c0:	6442                	ld	s0,16(sp)
    800048c2:	64a2                	ld	s1,8(sp)
    800048c4:	6902                	ld	s2,0(sp)
    800048c6:	6105                	addi	sp,sp,32
    800048c8:	8082                	ret

00000000800048ca <initsleeplock>:
#include "proc.h"
#include "sleeplock.h"

void
initsleeplock(struct sleeplock *lk, char *name)
{
    800048ca:	1101                	addi	sp,sp,-32
    800048cc:	ec06                	sd	ra,24(sp)
    800048ce:	e822                	sd	s0,16(sp)
    800048d0:	e426                	sd	s1,8(sp)
    800048d2:	e04a                	sd	s2,0(sp)
    800048d4:	1000                	addi	s0,sp,32
    800048d6:	84aa                	mv	s1,a0
    800048d8:	892e                	mv	s2,a1
  initlock(&lk->lk, "sleep lock");
    800048da:	00004597          	auipc	a1,0x4
    800048de:	cbe58593          	addi	a1,a1,-834 # 80008598 <etext+0x598>
    800048e2:	0521                	addi	a0,a0,8
    800048e4:	ffffc097          	auipc	ra,0xffffc
    800048e8:	3fa080e7          	jalr	1018(ra) # 80000cde <initlock>
  lk->name = name;
    800048ec:	0324b023          	sd	s2,32(s1)
  lk->locked = 0;
    800048f0:	0004a023          	sw	zero,0(s1)
  lk->pid = 0;
    800048f4:	0204a423          	sw	zero,40(s1)
}
    800048f8:	60e2                	ld	ra,24(sp)
    800048fa:	6442                	ld	s0,16(sp)
    800048fc:	64a2                	ld	s1,8(sp)
    800048fe:	6902                	ld	s2,0(sp)
    80004900:	6105                	addi	sp,sp,32
    80004902:	8082                	ret

0000000080004904 <acquiresleep>:

void
acquiresleep(struct sleeplock *lk)
{
    80004904:	1101                	addi	sp,sp,-32
    80004906:	ec06                	sd	ra,24(sp)
    80004908:	e822                	sd	s0,16(sp)
    8000490a:	e426                	sd	s1,8(sp)
    8000490c:	e04a                	sd	s2,0(sp)
    8000490e:	1000                	addi	s0,sp,32
    80004910:	84aa                	mv	s1,a0
  acquire(&lk->lk);
    80004912:	00850913          	addi	s2,a0,8
    80004916:	854a                	mv	a0,s2
    80004918:	ffffc097          	auipc	ra,0xffffc
    8000491c:	456080e7          	jalr	1110(ra) # 80000d6e <acquire>
  while (lk->locked) {
    80004920:	409c                	lw	a5,0(s1)
    80004922:	cb89                	beqz	a5,80004934 <acquiresleep+0x30>
    sleep(lk, &lk->lk);
    80004924:	85ca                	mv	a1,s2
    80004926:	8526                	mv	a0,s1
    80004928:	ffffe097          	auipc	ra,0xffffe
    8000492c:	9f4080e7          	jalr	-1548(ra) # 8000231c <sleep>
  while (lk->locked) {
    80004930:	409c                	lw	a5,0(s1)
    80004932:	fbed                	bnez	a5,80004924 <acquiresleep+0x20>
  }
  lk->locked = 1;
    80004934:	4785                	li	a5,1
    80004936:	c09c                	sw	a5,0(s1)
  lk->pid = myproc()->pid;
    80004938:	ffffd097          	auipc	ra,0xffffd
    8000493c:	2fe080e7          	jalr	766(ra) # 80001c36 <myproc>
    80004940:	5d1c                	lw	a5,56(a0)
    80004942:	d49c                	sw	a5,40(s1)
  release(&lk->lk);
    80004944:	854a                	mv	a0,s2
    80004946:	ffffc097          	auipc	ra,0xffffc
    8000494a:	4dc080e7          	jalr	1244(ra) # 80000e22 <release>
}
    8000494e:	60e2                	ld	ra,24(sp)
    80004950:	6442                	ld	s0,16(sp)
    80004952:	64a2                	ld	s1,8(sp)
    80004954:	6902                	ld	s2,0(sp)
    80004956:	6105                	addi	sp,sp,32
    80004958:	8082                	ret

000000008000495a <releasesleep>:

void
releasesleep(struct sleeplock *lk)
{
    8000495a:	1101                	addi	sp,sp,-32
    8000495c:	ec06                	sd	ra,24(sp)
    8000495e:	e822                	sd	s0,16(sp)
    80004960:	e426                	sd	s1,8(sp)
    80004962:	e04a                	sd	s2,0(sp)
    80004964:	1000                	addi	s0,sp,32
    80004966:	84aa                	mv	s1,a0
  acquire(&lk->lk);
    80004968:	00850913          	addi	s2,a0,8
    8000496c:	854a                	mv	a0,s2
    8000496e:	ffffc097          	auipc	ra,0xffffc
    80004972:	400080e7          	jalr	1024(ra) # 80000d6e <acquire>
  lk->locked = 0;
    80004976:	0004a023          	sw	zero,0(s1)
  lk->pid = 0;
    8000497a:	0204a423          	sw	zero,40(s1)
  wakeup(lk);
    8000497e:	8526                	mv	a0,s1
    80004980:	ffffe097          	auipc	ra,0xffffe
    80004984:	a0a080e7          	jalr	-1526(ra) # 8000238a <wakeup>
  release(&lk->lk);
    80004988:	854a                	mv	a0,s2
    8000498a:	ffffc097          	auipc	ra,0xffffc
    8000498e:	498080e7          	jalr	1176(ra) # 80000e22 <release>
}
    80004992:	60e2                	ld	ra,24(sp)
    80004994:	6442                	ld	s0,16(sp)
    80004996:	64a2                	ld	s1,8(sp)
    80004998:	6902                	ld	s2,0(sp)
    8000499a:	6105                	addi	sp,sp,32
    8000499c:	8082                	ret

000000008000499e <holdingsleep>:

int
holdingsleep(struct sleeplock *lk)
{
    8000499e:	7179                	addi	sp,sp,-48
    800049a0:	f406                	sd	ra,40(sp)
    800049a2:	f022                	sd	s0,32(sp)
    800049a4:	ec26                	sd	s1,24(sp)
    800049a6:	e84a                	sd	s2,16(sp)
    800049a8:	1800                	addi	s0,sp,48
    800049aa:	84aa                	mv	s1,a0
  int r;
  
  acquire(&lk->lk);
    800049ac:	00850913          	addi	s2,a0,8
    800049b0:	854a                	mv	a0,s2
    800049b2:	ffffc097          	auipc	ra,0xffffc
    800049b6:	3bc080e7          	jalr	956(ra) # 80000d6e <acquire>
  r = lk->locked && (lk->pid == myproc()->pid);
    800049ba:	409c                	lw	a5,0(s1)
    800049bc:	ef91                	bnez	a5,800049d8 <holdingsleep+0x3a>
    800049be:	4481                	li	s1,0
  release(&lk->lk);
    800049c0:	854a                	mv	a0,s2
    800049c2:	ffffc097          	auipc	ra,0xffffc
    800049c6:	460080e7          	jalr	1120(ra) # 80000e22 <release>
  return r;
}
    800049ca:	8526                	mv	a0,s1
    800049cc:	70a2                	ld	ra,40(sp)
    800049ce:	7402                	ld	s0,32(sp)
    800049d0:	64e2                	ld	s1,24(sp)
    800049d2:	6942                	ld	s2,16(sp)
    800049d4:	6145                	addi	sp,sp,48
    800049d6:	8082                	ret
    800049d8:	e44e                	sd	s3,8(sp)
  r = lk->locked && (lk->pid == myproc()->pid);
    800049da:	0284a983          	lw	s3,40(s1)
    800049de:	ffffd097          	auipc	ra,0xffffd
    800049e2:	258080e7          	jalr	600(ra) # 80001c36 <myproc>
    800049e6:	5d04                	lw	s1,56(a0)
    800049e8:	413484b3          	sub	s1,s1,s3
    800049ec:	0014b493          	seqz	s1,s1
    800049f0:	69a2                	ld	s3,8(sp)
    800049f2:	b7f9                	j	800049c0 <holdingsleep+0x22>

00000000800049f4 <fileinit>:
  struct file file[NFILE];
} ftable;

void
fileinit(void)
{
    800049f4:	1141                	addi	sp,sp,-16
    800049f6:	e406                	sd	ra,8(sp)
    800049f8:	e022                	sd	s0,0(sp)
    800049fa:	0800                	addi	s0,sp,16
  initlock(&ftable.lock, "ftable");
    800049fc:	00004597          	auipc	a1,0x4
    80004a00:	bac58593          	addi	a1,a1,-1108 # 800085a8 <etext+0x5a8>
    80004a04:	0023d517          	auipc	a0,0x23d
    80004a08:	89450513          	addi	a0,a0,-1900 # 80241298 <ftable>
    80004a0c:	ffffc097          	auipc	ra,0xffffc
    80004a10:	2d2080e7          	jalr	722(ra) # 80000cde <initlock>
}
    80004a14:	60a2                	ld	ra,8(sp)
    80004a16:	6402                	ld	s0,0(sp)
    80004a18:	0141                	addi	sp,sp,16
    80004a1a:	8082                	ret

0000000080004a1c <filealloc>:

// Allocate a file structure.
struct file*
filealloc(void)
{
    80004a1c:	1101                	addi	sp,sp,-32
    80004a1e:	ec06                	sd	ra,24(sp)
    80004a20:	e822                	sd	s0,16(sp)
    80004a22:	e426                	sd	s1,8(sp)
    80004a24:	1000                	addi	s0,sp,32
  struct file *f;

  acquire(&ftable.lock);
    80004a26:	0023d517          	auipc	a0,0x23d
    80004a2a:	87250513          	addi	a0,a0,-1934 # 80241298 <ftable>
    80004a2e:	ffffc097          	auipc	ra,0xffffc
    80004a32:	340080e7          	jalr	832(ra) # 80000d6e <acquire>
  for(f = ftable.file; f < ftable.file + NFILE; f++){
    80004a36:	0023d497          	auipc	s1,0x23d
    80004a3a:	87a48493          	addi	s1,s1,-1926 # 802412b0 <ftable+0x18>
    80004a3e:	0023e717          	auipc	a4,0x23e
    80004a42:	81270713          	addi	a4,a4,-2030 # 80242250 <disk>
    if(f->ref == 0){
    80004a46:	40dc                	lw	a5,4(s1)
    80004a48:	cf99                	beqz	a5,80004a66 <filealloc+0x4a>
  for(f = ftable.file; f < ftable.file + NFILE; f++){
    80004a4a:	02848493          	addi	s1,s1,40
    80004a4e:	fee49ce3          	bne	s1,a4,80004a46 <filealloc+0x2a>
      f->ref = 1;
      release(&ftable.lock);
      return f;
    }
  }
  release(&ftable.lock);
    80004a52:	0023d517          	auipc	a0,0x23d
    80004a56:	84650513          	addi	a0,a0,-1978 # 80241298 <ftable>
    80004a5a:	ffffc097          	auipc	ra,0xffffc
    80004a5e:	3c8080e7          	jalr	968(ra) # 80000e22 <release>
  return 0;
    80004a62:	4481                	li	s1,0
    80004a64:	a819                	j	80004a7a <filealloc+0x5e>
      f->ref = 1;
    80004a66:	4785                	li	a5,1
    80004a68:	c0dc                	sw	a5,4(s1)
      release(&ftable.lock);
    80004a6a:	0023d517          	auipc	a0,0x23d
    80004a6e:	82e50513          	addi	a0,a0,-2002 # 80241298 <ftable>
    80004a72:	ffffc097          	auipc	ra,0xffffc
    80004a76:	3b0080e7          	jalr	944(ra) # 80000e22 <release>
}
    80004a7a:	8526                	mv	a0,s1
    80004a7c:	60e2                	ld	ra,24(sp)
    80004a7e:	6442                	ld	s0,16(sp)
    80004a80:	64a2                	ld	s1,8(sp)
    80004a82:	6105                	addi	sp,sp,32
    80004a84:	8082                	ret

0000000080004a86 <filedup>:

// Increment ref count for file f.
struct file*
filedup(struct file *f)
{
    80004a86:	1101                	addi	sp,sp,-32
    80004a88:	ec06                	sd	ra,24(sp)
    80004a8a:	e822                	sd	s0,16(sp)
    80004a8c:	e426                	sd	s1,8(sp)
    80004a8e:	1000                	addi	s0,sp,32
    80004a90:	84aa                	mv	s1,a0
  acquire(&ftable.lock);
    80004a92:	0023d517          	auipc	a0,0x23d
    80004a96:	80650513          	addi	a0,a0,-2042 # 80241298 <ftable>
    80004a9a:	ffffc097          	auipc	ra,0xffffc
    80004a9e:	2d4080e7          	jalr	724(ra) # 80000d6e <acquire>
  if(f->ref < 1)
    80004aa2:	40dc                	lw	a5,4(s1)
    80004aa4:	02f05263          	blez	a5,80004ac8 <filedup+0x42>
    panic("filedup");
  f->ref++;
    80004aa8:	2785                	addiw	a5,a5,1
    80004aaa:	c0dc                	sw	a5,4(s1)
  release(&ftable.lock);
    80004aac:	0023c517          	auipc	a0,0x23c
    80004ab0:	7ec50513          	addi	a0,a0,2028 # 80241298 <ftable>
    80004ab4:	ffffc097          	auipc	ra,0xffffc
    80004ab8:	36e080e7          	jalr	878(ra) # 80000e22 <release>
  return f;
}
    80004abc:	8526                	mv	a0,s1
    80004abe:	60e2                	ld	ra,24(sp)
    80004ac0:	6442                	ld	s0,16(sp)
    80004ac2:	64a2                	ld	s1,8(sp)
    80004ac4:	6105                	addi	sp,sp,32
    80004ac6:	8082                	ret
    panic("filedup");
    80004ac8:	00004517          	auipc	a0,0x4
    80004acc:	ae850513          	addi	a0,a0,-1304 # 800085b0 <etext+0x5b0>
    80004ad0:	ffffc097          	auipc	ra,0xffffc
    80004ad4:	a90080e7          	jalr	-1392(ra) # 80000560 <panic>

0000000080004ad8 <fileclose>:

// Close file f.  (Decrement ref count, close when reaches 0.)
void
fileclose(struct file *f)
{
    80004ad8:	7139                	addi	sp,sp,-64
    80004ada:	fc06                	sd	ra,56(sp)
    80004adc:	f822                	sd	s0,48(sp)
    80004ade:	f426                	sd	s1,40(sp)
    80004ae0:	0080                	addi	s0,sp,64
    80004ae2:	84aa                	mv	s1,a0
  struct file ff;

  acquire(&ftable.lock);
    80004ae4:	0023c517          	auipc	a0,0x23c
    80004ae8:	7b450513          	addi	a0,a0,1972 # 80241298 <ftable>
    80004aec:	ffffc097          	auipc	ra,0xffffc
    80004af0:	282080e7          	jalr	642(ra) # 80000d6e <acquire>
  if(f->ref < 1)
    80004af4:	40dc                	lw	a5,4(s1)
    80004af6:	04f05c63          	blez	a5,80004b4e <fileclose+0x76>
    panic("fileclose");
  if(--f->ref > 0){
    80004afa:	37fd                	addiw	a5,a5,-1
    80004afc:	0007871b          	sext.w	a4,a5
    80004b00:	c0dc                	sw	a5,4(s1)
    80004b02:	06e04263          	bgtz	a4,80004b66 <fileclose+0x8e>
    80004b06:	f04a                	sd	s2,32(sp)
    80004b08:	ec4e                	sd	s3,24(sp)
    80004b0a:	e852                	sd	s4,16(sp)
    80004b0c:	e456                	sd	s5,8(sp)
    release(&ftable.lock);
    return;
  }
  ff = *f;
    80004b0e:	0004a903          	lw	s2,0(s1)
    80004b12:	0094ca83          	lbu	s5,9(s1)
    80004b16:	0104ba03          	ld	s4,16(s1)
    80004b1a:	0184b983          	ld	s3,24(s1)
  f->ref = 0;
    80004b1e:	0004a223          	sw	zero,4(s1)
  f->type = FD_NONE;
    80004b22:	0004a023          	sw	zero,0(s1)
  release(&ftable.lock);
    80004b26:	0023c517          	auipc	a0,0x23c
    80004b2a:	77250513          	addi	a0,a0,1906 # 80241298 <ftable>
    80004b2e:	ffffc097          	auipc	ra,0xffffc
    80004b32:	2f4080e7          	jalr	756(ra) # 80000e22 <release>

  if(ff.type == FD_PIPE){
    80004b36:	4785                	li	a5,1
    80004b38:	04f90463          	beq	s2,a5,80004b80 <fileclose+0xa8>
    pipeclose(ff.pipe, ff.writable);
  } else if(ff.type == FD_INODE || ff.type == FD_DEVICE){
    80004b3c:	3979                	addiw	s2,s2,-2
    80004b3e:	4785                	li	a5,1
    80004b40:	0527fb63          	bgeu	a5,s2,80004b96 <fileclose+0xbe>
    80004b44:	7902                	ld	s2,32(sp)
    80004b46:	69e2                	ld	s3,24(sp)
    80004b48:	6a42                	ld	s4,16(sp)
    80004b4a:	6aa2                	ld	s5,8(sp)
    80004b4c:	a02d                	j	80004b76 <fileclose+0x9e>
    80004b4e:	f04a                	sd	s2,32(sp)
    80004b50:	ec4e                	sd	s3,24(sp)
    80004b52:	e852                	sd	s4,16(sp)
    80004b54:	e456                	sd	s5,8(sp)
    panic("fileclose");
    80004b56:	00004517          	auipc	a0,0x4
    80004b5a:	a6250513          	addi	a0,a0,-1438 # 800085b8 <etext+0x5b8>
    80004b5e:	ffffc097          	auipc	ra,0xffffc
    80004b62:	a02080e7          	jalr	-1534(ra) # 80000560 <panic>
    release(&ftable.lock);
    80004b66:	0023c517          	auipc	a0,0x23c
    80004b6a:	73250513          	addi	a0,a0,1842 # 80241298 <ftable>
    80004b6e:	ffffc097          	auipc	ra,0xffffc
    80004b72:	2b4080e7          	jalr	692(ra) # 80000e22 <release>
    begin_op();
    iput(ff.ip);
    end_op();
  }
}
    80004b76:	70e2                	ld	ra,56(sp)
    80004b78:	7442                	ld	s0,48(sp)
    80004b7a:	74a2                	ld	s1,40(sp)
    80004b7c:	6121                	addi	sp,sp,64
    80004b7e:	8082                	ret
    pipeclose(ff.pipe, ff.writable);
    80004b80:	85d6                	mv	a1,s5
    80004b82:	8552                	mv	a0,s4
    80004b84:	00000097          	auipc	ra,0x0
    80004b88:	3a2080e7          	jalr	930(ra) # 80004f26 <pipeclose>
    80004b8c:	7902                	ld	s2,32(sp)
    80004b8e:	69e2                	ld	s3,24(sp)
    80004b90:	6a42                	ld	s4,16(sp)
    80004b92:	6aa2                	ld	s5,8(sp)
    80004b94:	b7cd                	j	80004b76 <fileclose+0x9e>
    begin_op();
    80004b96:	00000097          	auipc	ra,0x0
    80004b9a:	a78080e7          	jalr	-1416(ra) # 8000460e <begin_op>
    iput(ff.ip);
    80004b9e:	854e                	mv	a0,s3
    80004ba0:	fffff097          	auipc	ra,0xfffff
    80004ba4:	25e080e7          	jalr	606(ra) # 80003dfe <iput>
    end_op();
    80004ba8:	00000097          	auipc	ra,0x0
    80004bac:	ae0080e7          	jalr	-1312(ra) # 80004688 <end_op>
    80004bb0:	7902                	ld	s2,32(sp)
    80004bb2:	69e2                	ld	s3,24(sp)
    80004bb4:	6a42                	ld	s4,16(sp)
    80004bb6:	6aa2                	ld	s5,8(sp)
    80004bb8:	bf7d                	j	80004b76 <fileclose+0x9e>

0000000080004bba <filestat>:

// Get metadata about file f.
// addr is a user virtual address, pointing to a struct stat.
int
filestat(struct file *f, uint64 addr)
{
    80004bba:	715d                	addi	sp,sp,-80
    80004bbc:	e486                	sd	ra,72(sp)
    80004bbe:	e0a2                	sd	s0,64(sp)
    80004bc0:	fc26                	sd	s1,56(sp)
    80004bc2:	f44e                	sd	s3,40(sp)
    80004bc4:	0880                	addi	s0,sp,80
    80004bc6:	84aa                	mv	s1,a0
    80004bc8:	89ae                	mv	s3,a1
  struct proc *p = myproc();
    80004bca:	ffffd097          	auipc	ra,0xffffd
    80004bce:	06c080e7          	jalr	108(ra) # 80001c36 <myproc>
  struct stat st;
  
  if(f->type == FD_INODE || f->type == FD_DEVICE){
    80004bd2:	409c                	lw	a5,0(s1)
    80004bd4:	37f9                	addiw	a5,a5,-2
    80004bd6:	4705                	li	a4,1
    80004bd8:	04f76863          	bltu	a4,a5,80004c28 <filestat+0x6e>
    80004bdc:	f84a                	sd	s2,48(sp)
    80004bde:	892a                	mv	s2,a0
    ilock(f->ip);
    80004be0:	6c88                	ld	a0,24(s1)
    80004be2:	fffff097          	auipc	ra,0xfffff
    80004be6:	05e080e7          	jalr	94(ra) # 80003c40 <ilock>
    stati(f->ip, &st);
    80004bea:	fb840593          	addi	a1,s0,-72
    80004bee:	6c88                	ld	a0,24(s1)
    80004bf0:	fffff097          	auipc	ra,0xfffff
    80004bf4:	2de080e7          	jalr	734(ra) # 80003ece <stati>
    iunlock(f->ip);
    80004bf8:	6c88                	ld	a0,24(s1)
    80004bfa:	fffff097          	auipc	ra,0xfffff
    80004bfe:	10c080e7          	jalr	268(ra) # 80003d06 <iunlock>
    if(copyout(p->pagetable, addr, (char *)&st, sizeof(st)) < 0)
    80004c02:	46e1                	li	a3,24
    80004c04:	fb840613          	addi	a2,s0,-72
    80004c08:	85ce                	mv	a1,s3
    80004c0a:	05893503          	ld	a0,88(s2)
    80004c0e:	ffffd097          	auipc	ra,0xffffd
    80004c12:	c78080e7          	jalr	-904(ra) # 80001886 <copyout>
    80004c16:	41f5551b          	sraiw	a0,a0,0x1f
    80004c1a:	7942                	ld	s2,48(sp)
      return -1;
    return 0;
  }
  return -1;
}
    80004c1c:	60a6                	ld	ra,72(sp)
    80004c1e:	6406                	ld	s0,64(sp)
    80004c20:	74e2                	ld	s1,56(sp)
    80004c22:	79a2                	ld	s3,40(sp)
    80004c24:	6161                	addi	sp,sp,80
    80004c26:	8082                	ret
  return -1;
    80004c28:	557d                	li	a0,-1
    80004c2a:	bfcd                	j	80004c1c <filestat+0x62>

0000000080004c2c <fileread>:

// Read from file f.
// addr is a user virtual address.
int
fileread(struct file *f, uint64 addr, int n)
{
    80004c2c:	7179                	addi	sp,sp,-48
    80004c2e:	f406                	sd	ra,40(sp)
    80004c30:	f022                	sd	s0,32(sp)
    80004c32:	e84a                	sd	s2,16(sp)
    80004c34:	1800                	addi	s0,sp,48
  int r = 0;

  if(f->readable == 0)
    80004c36:	00854783          	lbu	a5,8(a0)
    80004c3a:	cbc5                	beqz	a5,80004cea <fileread+0xbe>
    80004c3c:	ec26                	sd	s1,24(sp)
    80004c3e:	e44e                	sd	s3,8(sp)
    80004c40:	84aa                	mv	s1,a0
    80004c42:	89ae                	mv	s3,a1
    80004c44:	8932                	mv	s2,a2
    return -1;

  if(f->type == FD_PIPE){
    80004c46:	411c                	lw	a5,0(a0)
    80004c48:	4705                	li	a4,1
    80004c4a:	04e78963          	beq	a5,a4,80004c9c <fileread+0x70>
    r = piperead(f->pipe, addr, n);
  } else if(f->type == FD_DEVICE){
    80004c4e:	470d                	li	a4,3
    80004c50:	04e78f63          	beq	a5,a4,80004cae <fileread+0x82>
    if(f->major < 0 || f->major >= NDEV || !devsw[f->major].read)
      return -1;
    r = devsw[f->major].read(1, addr, n);
  } else if(f->type == FD_INODE){
    80004c54:	4709                	li	a4,2
    80004c56:	08e79263          	bne	a5,a4,80004cda <fileread+0xae>
    ilock(f->ip);
    80004c5a:	6d08                	ld	a0,24(a0)
    80004c5c:	fffff097          	auipc	ra,0xfffff
    80004c60:	fe4080e7          	jalr	-28(ra) # 80003c40 <ilock>
    if((r = readi(f->ip, 1, addr, f->off, n)) > 0)
    80004c64:	874a                	mv	a4,s2
    80004c66:	5094                	lw	a3,32(s1)
    80004c68:	864e                	mv	a2,s3
    80004c6a:	4585                	li	a1,1
    80004c6c:	6c88                	ld	a0,24(s1)
    80004c6e:	fffff097          	auipc	ra,0xfffff
    80004c72:	28a080e7          	jalr	650(ra) # 80003ef8 <readi>
    80004c76:	892a                	mv	s2,a0
    80004c78:	00a05563          	blez	a0,80004c82 <fileread+0x56>
      f->off += r;
    80004c7c:	509c                	lw	a5,32(s1)
    80004c7e:	9fa9                	addw	a5,a5,a0
    80004c80:	d09c                	sw	a5,32(s1)
    iunlock(f->ip);
    80004c82:	6c88                	ld	a0,24(s1)
    80004c84:	fffff097          	auipc	ra,0xfffff
    80004c88:	082080e7          	jalr	130(ra) # 80003d06 <iunlock>
    80004c8c:	64e2                	ld	s1,24(sp)
    80004c8e:	69a2                	ld	s3,8(sp)
  } else {
    panic("fileread");
  }

  return r;
}
    80004c90:	854a                	mv	a0,s2
    80004c92:	70a2                	ld	ra,40(sp)
    80004c94:	7402                	ld	s0,32(sp)
    80004c96:	6942                	ld	s2,16(sp)
    80004c98:	6145                	addi	sp,sp,48
    80004c9a:	8082                	ret
    r = piperead(f->pipe, addr, n);
    80004c9c:	6908                	ld	a0,16(a0)
    80004c9e:	00000097          	auipc	ra,0x0
    80004ca2:	400080e7          	jalr	1024(ra) # 8000509e <piperead>
    80004ca6:	892a                	mv	s2,a0
    80004ca8:	64e2                	ld	s1,24(sp)
    80004caa:	69a2                	ld	s3,8(sp)
    80004cac:	b7d5                	j	80004c90 <fileread+0x64>
    if(f->major < 0 || f->major >= NDEV || !devsw[f->major].read)
    80004cae:	02451783          	lh	a5,36(a0)
    80004cb2:	03079693          	slli	a3,a5,0x30
    80004cb6:	92c1                	srli	a3,a3,0x30
    80004cb8:	4725                	li	a4,9
    80004cba:	02d76a63          	bltu	a4,a3,80004cee <fileread+0xc2>
    80004cbe:	0792                	slli	a5,a5,0x4
    80004cc0:	0023c717          	auipc	a4,0x23c
    80004cc4:	53870713          	addi	a4,a4,1336 # 802411f8 <devsw>
    80004cc8:	97ba                	add	a5,a5,a4
    80004cca:	639c                	ld	a5,0(a5)
    80004ccc:	c78d                	beqz	a5,80004cf6 <fileread+0xca>
    r = devsw[f->major].read(1, addr, n);
    80004cce:	4505                	li	a0,1
    80004cd0:	9782                	jalr	a5
    80004cd2:	892a                	mv	s2,a0
    80004cd4:	64e2                	ld	s1,24(sp)
    80004cd6:	69a2                	ld	s3,8(sp)
    80004cd8:	bf65                	j	80004c90 <fileread+0x64>
    panic("fileread");
    80004cda:	00004517          	auipc	a0,0x4
    80004cde:	8ee50513          	addi	a0,a0,-1810 # 800085c8 <etext+0x5c8>
    80004ce2:	ffffc097          	auipc	ra,0xffffc
    80004ce6:	87e080e7          	jalr	-1922(ra) # 80000560 <panic>
    return -1;
    80004cea:	597d                	li	s2,-1
    80004cec:	b755                	j	80004c90 <fileread+0x64>
      return -1;
    80004cee:	597d                	li	s2,-1
    80004cf0:	64e2                	ld	s1,24(sp)
    80004cf2:	69a2                	ld	s3,8(sp)
    80004cf4:	bf71                	j	80004c90 <fileread+0x64>
    80004cf6:	597d                	li	s2,-1
    80004cf8:	64e2                	ld	s1,24(sp)
    80004cfa:	69a2                	ld	s3,8(sp)
    80004cfc:	bf51                	j	80004c90 <fileread+0x64>

0000000080004cfe <filewrite>:
int
filewrite(struct file *f, uint64 addr, int n)
{
  int r, ret = 0;

  if(f->writable == 0)
    80004cfe:	00954783          	lbu	a5,9(a0)
    80004d02:	12078963          	beqz	a5,80004e34 <filewrite+0x136>
{
    80004d06:	715d                	addi	sp,sp,-80
    80004d08:	e486                	sd	ra,72(sp)
    80004d0a:	e0a2                	sd	s0,64(sp)
    80004d0c:	f84a                	sd	s2,48(sp)
    80004d0e:	f052                	sd	s4,32(sp)
    80004d10:	e85a                	sd	s6,16(sp)
    80004d12:	0880                	addi	s0,sp,80
    80004d14:	892a                	mv	s2,a0
    80004d16:	8b2e                	mv	s6,a1
    80004d18:	8a32                	mv	s4,a2
    return -1;

  if(f->type == FD_PIPE){
    80004d1a:	411c                	lw	a5,0(a0)
    80004d1c:	4705                	li	a4,1
    80004d1e:	02e78763          	beq	a5,a4,80004d4c <filewrite+0x4e>
    ret = pipewrite(f->pipe, addr, n);
  } else if(f->type == FD_DEVICE){
    80004d22:	470d                	li	a4,3
    80004d24:	02e78a63          	beq	a5,a4,80004d58 <filewrite+0x5a>
    if(f->major < 0 || f->major >= NDEV || !devsw[f->major].write)
      return -1;
    ret = devsw[f->major].write(1, addr, n);
  } else if(f->type == FD_INODE){
    80004d28:	4709                	li	a4,2
    80004d2a:	0ee79863          	bne	a5,a4,80004e1a <filewrite+0x11c>
    80004d2e:	f44e                	sd	s3,40(sp)
    // and 2 blocks of slop for non-aligned writes.
    // this really belongs lower down, since writei()
    // might be writing a device like the console.
    int max = ((MAXOPBLOCKS-1-1-2) / 2) * BSIZE;
    int i = 0;
    while(i < n){
    80004d30:	0cc05463          	blez	a2,80004df8 <filewrite+0xfa>
    80004d34:	fc26                	sd	s1,56(sp)
    80004d36:	ec56                	sd	s5,24(sp)
    80004d38:	e45e                	sd	s7,8(sp)
    80004d3a:	e062                	sd	s8,0(sp)
    int i = 0;
    80004d3c:	4981                	li	s3,0
      int n1 = n - i;
      if(n1 > max)
    80004d3e:	6b85                	lui	s7,0x1
    80004d40:	c00b8b93          	addi	s7,s7,-1024 # c00 <_entry-0x7ffff400>
    80004d44:	6c05                	lui	s8,0x1
    80004d46:	c00c0c1b          	addiw	s8,s8,-1024 # c00 <_entry-0x7ffff400>
    80004d4a:	a851                	j	80004dde <filewrite+0xe0>
    ret = pipewrite(f->pipe, addr, n);
    80004d4c:	6908                	ld	a0,16(a0)
    80004d4e:	00000097          	auipc	ra,0x0
    80004d52:	248080e7          	jalr	584(ra) # 80004f96 <pipewrite>
    80004d56:	a85d                	j	80004e0c <filewrite+0x10e>
    if(f->major < 0 || f->major >= NDEV || !devsw[f->major].write)
    80004d58:	02451783          	lh	a5,36(a0)
    80004d5c:	03079693          	slli	a3,a5,0x30
    80004d60:	92c1                	srli	a3,a3,0x30
    80004d62:	4725                	li	a4,9
    80004d64:	0cd76a63          	bltu	a4,a3,80004e38 <filewrite+0x13a>
    80004d68:	0792                	slli	a5,a5,0x4
    80004d6a:	0023c717          	auipc	a4,0x23c
    80004d6e:	48e70713          	addi	a4,a4,1166 # 802411f8 <devsw>
    80004d72:	97ba                	add	a5,a5,a4
    80004d74:	679c                	ld	a5,8(a5)
    80004d76:	c3f9                	beqz	a5,80004e3c <filewrite+0x13e>
    ret = devsw[f->major].write(1, addr, n);
    80004d78:	4505                	li	a0,1
    80004d7a:	9782                	jalr	a5
    80004d7c:	a841                	j	80004e0c <filewrite+0x10e>
      if(n1 > max)
    80004d7e:	00048a9b          	sext.w	s5,s1
        n1 = max;

      begin_op();
    80004d82:	00000097          	auipc	ra,0x0
    80004d86:	88c080e7          	jalr	-1908(ra) # 8000460e <begin_op>
      ilock(f->ip);
    80004d8a:	01893503          	ld	a0,24(s2)
    80004d8e:	fffff097          	auipc	ra,0xfffff
    80004d92:	eb2080e7          	jalr	-334(ra) # 80003c40 <ilock>
      if ((r = writei(f->ip, 1, addr + i, f->off, n1)) > 0)
    80004d96:	8756                	mv	a4,s5
    80004d98:	02092683          	lw	a3,32(s2)
    80004d9c:	01698633          	add	a2,s3,s6
    80004da0:	4585                	li	a1,1
    80004da2:	01893503          	ld	a0,24(s2)
    80004da6:	fffff097          	auipc	ra,0xfffff
    80004daa:	262080e7          	jalr	610(ra) # 80004008 <writei>
    80004dae:	84aa                	mv	s1,a0
    80004db0:	00a05763          	blez	a0,80004dbe <filewrite+0xc0>
        f->off += r;
    80004db4:	02092783          	lw	a5,32(s2)
    80004db8:	9fa9                	addw	a5,a5,a0
    80004dba:	02f92023          	sw	a5,32(s2)
      iunlock(f->ip);
    80004dbe:	01893503          	ld	a0,24(s2)
    80004dc2:	fffff097          	auipc	ra,0xfffff
    80004dc6:	f44080e7          	jalr	-188(ra) # 80003d06 <iunlock>
      end_op();
    80004dca:	00000097          	auipc	ra,0x0
    80004dce:	8be080e7          	jalr	-1858(ra) # 80004688 <end_op>

      if(r != n1){
    80004dd2:	029a9563          	bne	s5,s1,80004dfc <filewrite+0xfe>
        // error from writei
        break;
      }
      i += r;
    80004dd6:	013489bb          	addw	s3,s1,s3
    while(i < n){
    80004dda:	0149da63          	bge	s3,s4,80004dee <filewrite+0xf0>
      int n1 = n - i;
    80004dde:	413a04bb          	subw	s1,s4,s3
      if(n1 > max)
    80004de2:	0004879b          	sext.w	a5,s1
    80004de6:	f8fbdce3          	bge	s7,a5,80004d7e <filewrite+0x80>
    80004dea:	84e2                	mv	s1,s8
    80004dec:	bf49                	j	80004d7e <filewrite+0x80>
    80004dee:	74e2                	ld	s1,56(sp)
    80004df0:	6ae2                	ld	s5,24(sp)
    80004df2:	6ba2                	ld	s7,8(sp)
    80004df4:	6c02                	ld	s8,0(sp)
    80004df6:	a039                	j	80004e04 <filewrite+0x106>
    int i = 0;
    80004df8:	4981                	li	s3,0
    80004dfa:	a029                	j	80004e04 <filewrite+0x106>
    80004dfc:	74e2                	ld	s1,56(sp)
    80004dfe:	6ae2                	ld	s5,24(sp)
    80004e00:	6ba2                	ld	s7,8(sp)
    80004e02:	6c02                	ld	s8,0(sp)
    }
    ret = (i == n ? n : -1);
    80004e04:	033a1e63          	bne	s4,s3,80004e40 <filewrite+0x142>
    80004e08:	8552                	mv	a0,s4
    80004e0a:	79a2                	ld	s3,40(sp)
  } else {
    panic("filewrite");
  }

  return ret;
}
    80004e0c:	60a6                	ld	ra,72(sp)
    80004e0e:	6406                	ld	s0,64(sp)
    80004e10:	7942                	ld	s2,48(sp)
    80004e12:	7a02                	ld	s4,32(sp)
    80004e14:	6b42                	ld	s6,16(sp)
    80004e16:	6161                	addi	sp,sp,80
    80004e18:	8082                	ret
    80004e1a:	fc26                	sd	s1,56(sp)
    80004e1c:	f44e                	sd	s3,40(sp)
    80004e1e:	ec56                	sd	s5,24(sp)
    80004e20:	e45e                	sd	s7,8(sp)
    80004e22:	e062                	sd	s8,0(sp)
    panic("filewrite");
    80004e24:	00003517          	auipc	a0,0x3
    80004e28:	7b450513          	addi	a0,a0,1972 # 800085d8 <etext+0x5d8>
    80004e2c:	ffffb097          	auipc	ra,0xffffb
    80004e30:	734080e7          	jalr	1844(ra) # 80000560 <panic>
    return -1;
    80004e34:	557d                	li	a0,-1
}
    80004e36:	8082                	ret
      return -1;
    80004e38:	557d                	li	a0,-1
    80004e3a:	bfc9                	j	80004e0c <filewrite+0x10e>
    80004e3c:	557d                	li	a0,-1
    80004e3e:	b7f9                	j	80004e0c <filewrite+0x10e>
    ret = (i == n ? n : -1);
    80004e40:	557d                	li	a0,-1
    80004e42:	79a2                	ld	s3,40(sp)
    80004e44:	b7e1                	j	80004e0c <filewrite+0x10e>

0000000080004e46 <pipealloc>:
  int writeopen;  // write fd is still open
};

int
pipealloc(struct file **f0, struct file **f1)
{
    80004e46:	7179                	addi	sp,sp,-48
    80004e48:	f406                	sd	ra,40(sp)
    80004e4a:	f022                	sd	s0,32(sp)
    80004e4c:	ec26                	sd	s1,24(sp)
    80004e4e:	e052                	sd	s4,0(sp)
    80004e50:	1800                	addi	s0,sp,48
    80004e52:	84aa                	mv	s1,a0
    80004e54:	8a2e                	mv	s4,a1
  struct pipe *pi;

  pi = 0;
  *f0 = *f1 = 0;
    80004e56:	0005b023          	sd	zero,0(a1)
    80004e5a:	00053023          	sd	zero,0(a0)
  if((*f0 = filealloc()) == 0 || (*f1 = filealloc()) == 0)
    80004e5e:	00000097          	auipc	ra,0x0
    80004e62:	bbe080e7          	jalr	-1090(ra) # 80004a1c <filealloc>
    80004e66:	e088                	sd	a0,0(s1)
    80004e68:	cd49                	beqz	a0,80004f02 <pipealloc+0xbc>
    80004e6a:	00000097          	auipc	ra,0x0
    80004e6e:	bb2080e7          	jalr	-1102(ra) # 80004a1c <filealloc>
    80004e72:	00aa3023          	sd	a0,0(s4)
    80004e76:	c141                	beqz	a0,80004ef6 <pipealloc+0xb0>
    80004e78:	e84a                	sd	s2,16(sp)
    goto bad;
  if((pi = (struct pipe*)kalloc()) == 0)
    80004e7a:	ffffc097          	auipc	ra,0xffffc
    80004e7e:	d54080e7          	jalr	-684(ra) # 80000bce <kalloc>
    80004e82:	892a                	mv	s2,a0
    80004e84:	c13d                	beqz	a0,80004eea <pipealloc+0xa4>
    80004e86:	e44e                	sd	s3,8(sp)
    goto bad;
  pi->readopen = 1;
    80004e88:	4985                	li	s3,1
    80004e8a:	23352023          	sw	s3,544(a0)
  pi->writeopen = 1;
    80004e8e:	23352223          	sw	s3,548(a0)
  pi->nwrite = 0;
    80004e92:	20052e23          	sw	zero,540(a0)
  pi->nread = 0;
    80004e96:	20052c23          	sw	zero,536(a0)
  initlock(&pi->lock, "pipe");
    80004e9a:	00003597          	auipc	a1,0x3
    80004e9e:	74e58593          	addi	a1,a1,1870 # 800085e8 <etext+0x5e8>
    80004ea2:	ffffc097          	auipc	ra,0xffffc
    80004ea6:	e3c080e7          	jalr	-452(ra) # 80000cde <initlock>
  (*f0)->type = FD_PIPE;
    80004eaa:	609c                	ld	a5,0(s1)
    80004eac:	0137a023          	sw	s3,0(a5)
  (*f0)->readable = 1;
    80004eb0:	609c                	ld	a5,0(s1)
    80004eb2:	01378423          	sb	s3,8(a5)
  (*f0)->writable = 0;
    80004eb6:	609c                	ld	a5,0(s1)
    80004eb8:	000784a3          	sb	zero,9(a5)
  (*f0)->pipe = pi;
    80004ebc:	609c                	ld	a5,0(s1)
    80004ebe:	0127b823          	sd	s2,16(a5)
  (*f1)->type = FD_PIPE;
    80004ec2:	000a3783          	ld	a5,0(s4)
    80004ec6:	0137a023          	sw	s3,0(a5)
  (*f1)->readable = 0;
    80004eca:	000a3783          	ld	a5,0(s4)
    80004ece:	00078423          	sb	zero,8(a5)
  (*f1)->writable = 1;
    80004ed2:	000a3783          	ld	a5,0(s4)
    80004ed6:	013784a3          	sb	s3,9(a5)
  (*f1)->pipe = pi;
    80004eda:	000a3783          	ld	a5,0(s4)
    80004ede:	0127b823          	sd	s2,16(a5)
  return 0;
    80004ee2:	4501                	li	a0,0
    80004ee4:	6942                	ld	s2,16(sp)
    80004ee6:	69a2                	ld	s3,8(sp)
    80004ee8:	a03d                	j	80004f16 <pipealloc+0xd0>

 bad:
  if(pi)
    kfree((char*)pi);
  if(*f0)
    80004eea:	6088                	ld	a0,0(s1)
    80004eec:	c119                	beqz	a0,80004ef2 <pipealloc+0xac>
    80004eee:	6942                	ld	s2,16(sp)
    80004ef0:	a029                	j	80004efa <pipealloc+0xb4>
    80004ef2:	6942                	ld	s2,16(sp)
    80004ef4:	a039                	j	80004f02 <pipealloc+0xbc>
    80004ef6:	6088                	ld	a0,0(s1)
    80004ef8:	c50d                	beqz	a0,80004f22 <pipealloc+0xdc>
    fileclose(*f0);
    80004efa:	00000097          	auipc	ra,0x0
    80004efe:	bde080e7          	jalr	-1058(ra) # 80004ad8 <fileclose>
  if(*f1)
    80004f02:	000a3783          	ld	a5,0(s4)
    fileclose(*f1);
  return -1;
    80004f06:	557d                	li	a0,-1
  if(*f1)
    80004f08:	c799                	beqz	a5,80004f16 <pipealloc+0xd0>
    fileclose(*f1);
    80004f0a:	853e                	mv	a0,a5
    80004f0c:	00000097          	auipc	ra,0x0
    80004f10:	bcc080e7          	jalr	-1076(ra) # 80004ad8 <fileclose>
  return -1;
    80004f14:	557d                	li	a0,-1
}
    80004f16:	70a2                	ld	ra,40(sp)
    80004f18:	7402                	ld	s0,32(sp)
    80004f1a:	64e2                	ld	s1,24(sp)
    80004f1c:	6a02                	ld	s4,0(sp)
    80004f1e:	6145                	addi	sp,sp,48
    80004f20:	8082                	ret
  return -1;
    80004f22:	557d                	li	a0,-1
    80004f24:	bfcd                	j	80004f16 <pipealloc+0xd0>

0000000080004f26 <pipeclose>:

void
pipeclose(struct pipe *pi, int writable)
{
    80004f26:	1101                	addi	sp,sp,-32
    80004f28:	ec06                	sd	ra,24(sp)
    80004f2a:	e822                	sd	s0,16(sp)
    80004f2c:	e426                	sd	s1,8(sp)
    80004f2e:	e04a                	sd	s2,0(sp)
    80004f30:	1000                	addi	s0,sp,32
    80004f32:	84aa                	mv	s1,a0
    80004f34:	892e                	mv	s2,a1
  acquire(&pi->lock);
    80004f36:	ffffc097          	auipc	ra,0xffffc
    80004f3a:	e38080e7          	jalr	-456(ra) # 80000d6e <acquire>
  if(writable){
    80004f3e:	02090d63          	beqz	s2,80004f78 <pipeclose+0x52>
    pi->writeopen = 0;
    80004f42:	2204a223          	sw	zero,548(s1)
    wakeup(&pi->nread);
    80004f46:	21848513          	addi	a0,s1,536
    80004f4a:	ffffd097          	auipc	ra,0xffffd
    80004f4e:	440080e7          	jalr	1088(ra) # 8000238a <wakeup>
  } else {
    pi->readopen = 0;
    wakeup(&pi->nwrite);
  }
  if(pi->readopen == 0 && pi->writeopen == 0){
    80004f52:	2204b783          	ld	a5,544(s1)
    80004f56:	eb95                	bnez	a5,80004f8a <pipeclose+0x64>
    release(&pi->lock);
    80004f58:	8526                	mv	a0,s1
    80004f5a:	ffffc097          	auipc	ra,0xffffc
    80004f5e:	ec8080e7          	jalr	-312(ra) # 80000e22 <release>
    kfree((char*)pi);
    80004f62:	8526                	mv	a0,s1
    80004f64:	ffffc097          	auipc	ra,0xffffc
    80004f68:	ae6080e7          	jalr	-1306(ra) # 80000a4a <kfree>
  } else
    release(&pi->lock);
}
    80004f6c:	60e2                	ld	ra,24(sp)
    80004f6e:	6442                	ld	s0,16(sp)
    80004f70:	64a2                	ld	s1,8(sp)
    80004f72:	6902                	ld	s2,0(sp)
    80004f74:	6105                	addi	sp,sp,32
    80004f76:	8082                	ret
    pi->readopen = 0;
    80004f78:	2204a023          	sw	zero,544(s1)
    wakeup(&pi->nwrite);
    80004f7c:	21c48513          	addi	a0,s1,540
    80004f80:	ffffd097          	auipc	ra,0xffffd
    80004f84:	40a080e7          	jalr	1034(ra) # 8000238a <wakeup>
    80004f88:	b7e9                	j	80004f52 <pipeclose+0x2c>
    release(&pi->lock);
    80004f8a:	8526                	mv	a0,s1
    80004f8c:	ffffc097          	auipc	ra,0xffffc
    80004f90:	e96080e7          	jalr	-362(ra) # 80000e22 <release>
}
    80004f94:	bfe1                	j	80004f6c <pipeclose+0x46>

0000000080004f96 <pipewrite>:

int
pipewrite(struct pipe *pi, uint64 addr, int n)
{
    80004f96:	711d                	addi	sp,sp,-96
    80004f98:	ec86                	sd	ra,88(sp)
    80004f9a:	e8a2                	sd	s0,80(sp)
    80004f9c:	e4a6                	sd	s1,72(sp)
    80004f9e:	e0ca                	sd	s2,64(sp)
    80004fa0:	fc4e                	sd	s3,56(sp)
    80004fa2:	f852                	sd	s4,48(sp)
    80004fa4:	f456                	sd	s5,40(sp)
    80004fa6:	1080                	addi	s0,sp,96
    80004fa8:	84aa                	mv	s1,a0
    80004faa:	8aae                	mv	s5,a1
    80004fac:	8a32                	mv	s4,a2
  int i = 0;
  struct proc *pr = myproc();
    80004fae:	ffffd097          	auipc	ra,0xffffd
    80004fb2:	c88080e7          	jalr	-888(ra) # 80001c36 <myproc>
    80004fb6:	89aa                	mv	s3,a0

  acquire(&pi->lock);
    80004fb8:	8526                	mv	a0,s1
    80004fba:	ffffc097          	auipc	ra,0xffffc
    80004fbe:	db4080e7          	jalr	-588(ra) # 80000d6e <acquire>
  while(i < n){
    80004fc2:	0d405863          	blez	s4,80005092 <pipewrite+0xfc>
    80004fc6:	f05a                	sd	s6,32(sp)
    80004fc8:	ec5e                	sd	s7,24(sp)
    80004fca:	e862                	sd	s8,16(sp)
  int i = 0;
    80004fcc:	4901                	li	s2,0
    if(pi->nwrite == pi->nread + PIPESIZE){ //DOC: pipewrite-full
      wakeup(&pi->nread);
      sleep(&pi->nwrite, &pi->lock);
    } else {
      char ch;
      if(copyin(pr->pagetable, &ch, addr + i, 1) == -1)
    80004fce:	5b7d                	li	s6,-1
      wakeup(&pi->nread);
    80004fd0:	21848c13          	addi	s8,s1,536
      sleep(&pi->nwrite, &pi->lock);
    80004fd4:	21c48b93          	addi	s7,s1,540
    80004fd8:	a089                	j	8000501a <pipewrite+0x84>
      release(&pi->lock);
    80004fda:	8526                	mv	a0,s1
    80004fdc:	ffffc097          	auipc	ra,0xffffc
    80004fe0:	e46080e7          	jalr	-442(ra) # 80000e22 <release>
      return -1;
    80004fe4:	597d                	li	s2,-1
    80004fe6:	7b02                	ld	s6,32(sp)
    80004fe8:	6be2                	ld	s7,24(sp)
    80004fea:	6c42                	ld	s8,16(sp)
  }
  wakeup(&pi->nread);
  release(&pi->lock);

  return i;
}
    80004fec:	854a                	mv	a0,s2
    80004fee:	60e6                	ld	ra,88(sp)
    80004ff0:	6446                	ld	s0,80(sp)
    80004ff2:	64a6                	ld	s1,72(sp)
    80004ff4:	6906                	ld	s2,64(sp)
    80004ff6:	79e2                	ld	s3,56(sp)
    80004ff8:	7a42                	ld	s4,48(sp)
    80004ffa:	7aa2                	ld	s5,40(sp)
    80004ffc:	6125                	addi	sp,sp,96
    80004ffe:	8082                	ret
      wakeup(&pi->nread);
    80005000:	8562                	mv	a0,s8
    80005002:	ffffd097          	auipc	ra,0xffffd
    80005006:	388080e7          	jalr	904(ra) # 8000238a <wakeup>
      sleep(&pi->nwrite, &pi->lock);
    8000500a:	85a6                	mv	a1,s1
    8000500c:	855e                	mv	a0,s7
    8000500e:	ffffd097          	auipc	ra,0xffffd
    80005012:	30e080e7          	jalr	782(ra) # 8000231c <sleep>
  while(i < n){
    80005016:	05495f63          	bge	s2,s4,80005074 <pipewrite+0xde>
    if(pi->readopen == 0 || killed(pr)){
    8000501a:	2204a783          	lw	a5,544(s1)
    8000501e:	dfd5                	beqz	a5,80004fda <pipewrite+0x44>
    80005020:	854e                	mv	a0,s3
    80005022:	ffffd097          	auipc	ra,0xffffd
    80005026:	5d4080e7          	jalr	1492(ra) # 800025f6 <killed>
    8000502a:	f945                	bnez	a0,80004fda <pipewrite+0x44>
    if(pi->nwrite == pi->nread + PIPESIZE){ //DOC: pipewrite-full
    8000502c:	2184a783          	lw	a5,536(s1)
    80005030:	21c4a703          	lw	a4,540(s1)
    80005034:	2007879b          	addiw	a5,a5,512
    80005038:	fcf704e3          	beq	a4,a5,80005000 <pipewrite+0x6a>
      if(copyin(pr->pagetable, &ch, addr + i, 1) == -1)
    8000503c:	4685                	li	a3,1
    8000503e:	01590633          	add	a2,s2,s5
    80005042:	faf40593          	addi	a1,s0,-81
    80005046:	0589b503          	ld	a0,88(s3)
    8000504a:	ffffd097          	auipc	ra,0xffffd
    8000504e:	90e080e7          	jalr	-1778(ra) # 80001958 <copyin>
    80005052:	05650263          	beq	a0,s6,80005096 <pipewrite+0x100>
      pi->data[pi->nwrite++ % PIPESIZE] = ch;
    80005056:	21c4a783          	lw	a5,540(s1)
    8000505a:	0017871b          	addiw	a4,a5,1
    8000505e:	20e4ae23          	sw	a4,540(s1)
    80005062:	1ff7f793          	andi	a5,a5,511
    80005066:	97a6                	add	a5,a5,s1
    80005068:	faf44703          	lbu	a4,-81(s0)
    8000506c:	00e78c23          	sb	a4,24(a5)
      i++;
    80005070:	2905                	addiw	s2,s2,1
    80005072:	b755                	j	80005016 <pipewrite+0x80>
    80005074:	7b02                	ld	s6,32(sp)
    80005076:	6be2                	ld	s7,24(sp)
    80005078:	6c42                	ld	s8,16(sp)
  wakeup(&pi->nread);
    8000507a:	21848513          	addi	a0,s1,536
    8000507e:	ffffd097          	auipc	ra,0xffffd
    80005082:	30c080e7          	jalr	780(ra) # 8000238a <wakeup>
  release(&pi->lock);
    80005086:	8526                	mv	a0,s1
    80005088:	ffffc097          	auipc	ra,0xffffc
    8000508c:	d9a080e7          	jalr	-614(ra) # 80000e22 <release>
  return i;
    80005090:	bfb1                	j	80004fec <pipewrite+0x56>
  int i = 0;
    80005092:	4901                	li	s2,0
    80005094:	b7dd                	j	8000507a <pipewrite+0xe4>
    80005096:	7b02                	ld	s6,32(sp)
    80005098:	6be2                	ld	s7,24(sp)
    8000509a:	6c42                	ld	s8,16(sp)
    8000509c:	bff9                	j	8000507a <pipewrite+0xe4>

000000008000509e <piperead>:

int
piperead(struct pipe *pi, uint64 addr, int n)
{
    8000509e:	715d                	addi	sp,sp,-80
    800050a0:	e486                	sd	ra,72(sp)
    800050a2:	e0a2                	sd	s0,64(sp)
    800050a4:	fc26                	sd	s1,56(sp)
    800050a6:	f84a                	sd	s2,48(sp)
    800050a8:	f44e                	sd	s3,40(sp)
    800050aa:	f052                	sd	s4,32(sp)
    800050ac:	ec56                	sd	s5,24(sp)
    800050ae:	0880                	addi	s0,sp,80
    800050b0:	84aa                	mv	s1,a0
    800050b2:	892e                	mv	s2,a1
    800050b4:	8ab2                	mv	s5,a2
  int i;
  struct proc *pr = myproc();
    800050b6:	ffffd097          	auipc	ra,0xffffd
    800050ba:	b80080e7          	jalr	-1152(ra) # 80001c36 <myproc>
    800050be:	8a2a                	mv	s4,a0
  char ch;

  acquire(&pi->lock);
    800050c0:	8526                	mv	a0,s1
    800050c2:	ffffc097          	auipc	ra,0xffffc
    800050c6:	cac080e7          	jalr	-852(ra) # 80000d6e <acquire>
  while(pi->nread == pi->nwrite && pi->writeopen){  //DOC: pipe-empty
    800050ca:	2184a703          	lw	a4,536(s1)
    800050ce:	21c4a783          	lw	a5,540(s1)
    if(killed(pr)){
      release(&pi->lock);
      return -1;
    }
    sleep(&pi->nread, &pi->lock); //DOC: piperead-sleep
    800050d2:	21848993          	addi	s3,s1,536
  while(pi->nread == pi->nwrite && pi->writeopen){  //DOC: pipe-empty
    800050d6:	02f71963          	bne	a4,a5,80005108 <piperead+0x6a>
    800050da:	2244a783          	lw	a5,548(s1)
    800050de:	cf95                	beqz	a5,8000511a <piperead+0x7c>
    if(killed(pr)){
    800050e0:	8552                	mv	a0,s4
    800050e2:	ffffd097          	auipc	ra,0xffffd
    800050e6:	514080e7          	jalr	1300(ra) # 800025f6 <killed>
    800050ea:	e10d                	bnez	a0,8000510c <piperead+0x6e>
    sleep(&pi->nread, &pi->lock); //DOC: piperead-sleep
    800050ec:	85a6                	mv	a1,s1
    800050ee:	854e                	mv	a0,s3
    800050f0:	ffffd097          	auipc	ra,0xffffd
    800050f4:	22c080e7          	jalr	556(ra) # 8000231c <sleep>
  while(pi->nread == pi->nwrite && pi->writeopen){  //DOC: pipe-empty
    800050f8:	2184a703          	lw	a4,536(s1)
    800050fc:	21c4a783          	lw	a5,540(s1)
    80005100:	fcf70de3          	beq	a4,a5,800050da <piperead+0x3c>
    80005104:	e85a                	sd	s6,16(sp)
    80005106:	a819                	j	8000511c <piperead+0x7e>
    80005108:	e85a                	sd	s6,16(sp)
    8000510a:	a809                	j	8000511c <piperead+0x7e>
      release(&pi->lock);
    8000510c:	8526                	mv	a0,s1
    8000510e:	ffffc097          	auipc	ra,0xffffc
    80005112:	d14080e7          	jalr	-748(ra) # 80000e22 <release>
      return -1;
    80005116:	59fd                	li	s3,-1
    80005118:	a0a5                	j	80005180 <piperead+0xe2>
    8000511a:	e85a                	sd	s6,16(sp)
  }
  for(i = 0; i < n; i++){  //DOC: piperead-copy
    8000511c:	4981                	li	s3,0
    if(pi->nread == pi->nwrite)
      break;
    ch = pi->data[pi->nread++ % PIPESIZE];
    if(copyout(pr->pagetable, addr + i, &ch, 1) == -1)
    8000511e:	5b7d                	li	s6,-1
  for(i = 0; i < n; i++){  //DOC: piperead-copy
    80005120:	05505463          	blez	s5,80005168 <piperead+0xca>
    if(pi->nread == pi->nwrite)
    80005124:	2184a783          	lw	a5,536(s1)
    80005128:	21c4a703          	lw	a4,540(s1)
    8000512c:	02f70e63          	beq	a4,a5,80005168 <piperead+0xca>
    ch = pi->data[pi->nread++ % PIPESIZE];
    80005130:	0017871b          	addiw	a4,a5,1
    80005134:	20e4ac23          	sw	a4,536(s1)
    80005138:	1ff7f793          	andi	a5,a5,511
    8000513c:	97a6                	add	a5,a5,s1
    8000513e:	0187c783          	lbu	a5,24(a5)
    80005142:	faf40fa3          	sb	a5,-65(s0)
    if(copyout(pr->pagetable, addr + i, &ch, 1) == -1)
    80005146:	4685                	li	a3,1
    80005148:	fbf40613          	addi	a2,s0,-65
    8000514c:	85ca                	mv	a1,s2
    8000514e:	058a3503          	ld	a0,88(s4)
    80005152:	ffffc097          	auipc	ra,0xffffc
    80005156:	734080e7          	jalr	1844(ra) # 80001886 <copyout>
    8000515a:	01650763          	beq	a0,s6,80005168 <piperead+0xca>
  for(i = 0; i < n; i++){  //DOC: piperead-copy
    8000515e:	2985                	addiw	s3,s3,1
    80005160:	0905                	addi	s2,s2,1
    80005162:	fd3a91e3          	bne	s5,s3,80005124 <piperead+0x86>
    80005166:	89d6                	mv	s3,s5
      break;
  }
  wakeup(&pi->nwrite);  //DOC: piperead-wakeup
    80005168:	21c48513          	addi	a0,s1,540
    8000516c:	ffffd097          	auipc	ra,0xffffd
    80005170:	21e080e7          	jalr	542(ra) # 8000238a <wakeup>
  release(&pi->lock);
    80005174:	8526                	mv	a0,s1
    80005176:	ffffc097          	auipc	ra,0xffffc
    8000517a:	cac080e7          	jalr	-852(ra) # 80000e22 <release>
    8000517e:	6b42                	ld	s6,16(sp)
  return i;
}
    80005180:	854e                	mv	a0,s3
    80005182:	60a6                	ld	ra,72(sp)
    80005184:	6406                	ld	s0,64(sp)
    80005186:	74e2                	ld	s1,56(sp)
    80005188:	7942                	ld	s2,48(sp)
    8000518a:	79a2                	ld	s3,40(sp)
    8000518c:	7a02                	ld	s4,32(sp)
    8000518e:	6ae2                	ld	s5,24(sp)
    80005190:	6161                	addi	sp,sp,80
    80005192:	8082                	ret

0000000080005194 <flags2perm>:
#include "elf.h"

static int loadseg(pde_t *, uint64, struct inode *, uint, uint);

int flags2perm(int flags)
{
    80005194:	1141                	addi	sp,sp,-16
    80005196:	e422                	sd	s0,8(sp)
    80005198:	0800                	addi	s0,sp,16
    8000519a:	87aa                	mv	a5,a0
    int perm = 0;
    if(flags & 0x1)
    8000519c:	8905                	andi	a0,a0,1
    8000519e:	050e                	slli	a0,a0,0x3
      perm = PTE_X;
    if(flags & 0x2)
    800051a0:	8b89                	andi	a5,a5,2
    800051a2:	c399                	beqz	a5,800051a8 <flags2perm+0x14>
      perm |= PTE_W;
    800051a4:	00456513          	ori	a0,a0,4
    return perm;
}
    800051a8:	6422                	ld	s0,8(sp)
    800051aa:	0141                	addi	sp,sp,16
    800051ac:	8082                	ret

00000000800051ae <exec>:

int
exec(char *path, char **argv)
{
    800051ae:	df010113          	addi	sp,sp,-528
    800051b2:	20113423          	sd	ra,520(sp)
    800051b6:	20813023          	sd	s0,512(sp)
    800051ba:	ffa6                	sd	s1,504(sp)
    800051bc:	fbca                	sd	s2,496(sp)
    800051be:	0c00                	addi	s0,sp,528
    800051c0:	892a                	mv	s2,a0
    800051c2:	dea43c23          	sd	a0,-520(s0)
    800051c6:	e0b43023          	sd	a1,-512(s0)
  uint64 argc, sz = 0, sp, ustack[MAXARG], stackbase;
  struct elfhdr elf;
  struct inode *ip;
  struct proghdr ph;
  pagetable_t pagetable = 0, oldpagetable;
  struct proc *p = myproc();
    800051ca:	ffffd097          	auipc	ra,0xffffd
    800051ce:	a6c080e7          	jalr	-1428(ra) # 80001c36 <myproc>
    800051d2:	84aa                	mv	s1,a0

  begin_op();
    800051d4:	fffff097          	auipc	ra,0xfffff
    800051d8:	43a080e7          	jalr	1082(ra) # 8000460e <begin_op>

  if((ip = namei(path)) == 0){
    800051dc:	854a                	mv	a0,s2
    800051de:	fffff097          	auipc	ra,0xfffff
    800051e2:	230080e7          	jalr	560(ra) # 8000440e <namei>
    800051e6:	c135                	beqz	a0,8000524a <exec+0x9c>
    800051e8:	f3d2                	sd	s4,480(sp)
    800051ea:	8a2a                	mv	s4,a0
    end_op();
    return -1;
  }
  ilock(ip);
    800051ec:	fffff097          	auipc	ra,0xfffff
    800051f0:	a54080e7          	jalr	-1452(ra) # 80003c40 <ilock>

  // Check ELF header
  if(readi(ip, 0, (uint64)&elf, 0, sizeof(elf)) != sizeof(elf))
    800051f4:	04000713          	li	a4,64
    800051f8:	4681                	li	a3,0
    800051fa:	e5040613          	addi	a2,s0,-432
    800051fe:	4581                	li	a1,0
    80005200:	8552                	mv	a0,s4
    80005202:	fffff097          	auipc	ra,0xfffff
    80005206:	cf6080e7          	jalr	-778(ra) # 80003ef8 <readi>
    8000520a:	04000793          	li	a5,64
    8000520e:	00f51a63          	bne	a0,a5,80005222 <exec+0x74>
    goto bad;

  if(elf.magic != ELF_MAGIC)
    80005212:	e5042703          	lw	a4,-432(s0)
    80005216:	464c47b7          	lui	a5,0x464c4
    8000521a:	57f78793          	addi	a5,a5,1407 # 464c457f <_entry-0x39b3ba81>
    8000521e:	02f70c63          	beq	a4,a5,80005256 <exec+0xa8>

 bad:
  if(pagetable)
    proc_freepagetable(pagetable, sz);
  if(ip){
    iunlockput(ip);
    80005222:	8552                	mv	a0,s4
    80005224:	fffff097          	auipc	ra,0xfffff
    80005228:	c82080e7          	jalr	-894(ra) # 80003ea6 <iunlockput>
    end_op();
    8000522c:	fffff097          	auipc	ra,0xfffff
    80005230:	45c080e7          	jalr	1116(ra) # 80004688 <end_op>
  }
  return -1;
    80005234:	557d                	li	a0,-1
    80005236:	7a1e                	ld	s4,480(sp)
}
    80005238:	20813083          	ld	ra,520(sp)
    8000523c:	20013403          	ld	s0,512(sp)
    80005240:	74fe                	ld	s1,504(sp)
    80005242:	795e                	ld	s2,496(sp)
    80005244:	21010113          	addi	sp,sp,528
    80005248:	8082                	ret
    end_op();
    8000524a:	fffff097          	auipc	ra,0xfffff
    8000524e:	43e080e7          	jalr	1086(ra) # 80004688 <end_op>
    return -1;
    80005252:	557d                	li	a0,-1
    80005254:	b7d5                	j	80005238 <exec+0x8a>
    80005256:	ebda                	sd	s6,464(sp)
  if((pagetable = proc_pagetable(p)) == 0)
    80005258:	8526                	mv	a0,s1
    8000525a:	ffffd097          	auipc	ra,0xffffd
    8000525e:	aa2080e7          	jalr	-1374(ra) # 80001cfc <proc_pagetable>
    80005262:	8b2a                	mv	s6,a0
    80005264:	30050f63          	beqz	a0,80005582 <exec+0x3d4>
    80005268:	f7ce                	sd	s3,488(sp)
    8000526a:	efd6                	sd	s5,472(sp)
    8000526c:	e7de                	sd	s7,456(sp)
    8000526e:	e3e2                	sd	s8,448(sp)
    80005270:	ff66                	sd	s9,440(sp)
    80005272:	fb6a                	sd	s10,432(sp)
  for(i=0, off=elf.phoff; i<elf.phnum; i++, off+=sizeof(ph)){
    80005274:	e7042d03          	lw	s10,-400(s0)
    80005278:	e8845783          	lhu	a5,-376(s0)
    8000527c:	14078d63          	beqz	a5,800053d6 <exec+0x228>
    80005280:	f76e                	sd	s11,424(sp)
  uint64 argc, sz = 0, sp, ustack[MAXARG], stackbase;
    80005282:	4901                	li	s2,0
  for(i=0, off=elf.phoff; i<elf.phnum; i++, off+=sizeof(ph)){
    80005284:	4d81                	li	s11,0
    if(ph.vaddr % PGSIZE != 0)
    80005286:	6c85                	lui	s9,0x1
    80005288:	fffc8793          	addi	a5,s9,-1 # fff <_entry-0x7ffff001>
    8000528c:	def43823          	sd	a5,-528(s0)

  for(i = 0; i < sz; i += PGSIZE){
    pa = walkaddr(pagetable, va + i);
    if(pa == 0)
      panic("loadseg: address should exist");
    if(sz - i < PGSIZE)
    80005290:	6a85                	lui	s5,0x1
    80005292:	a0b5                	j	800052fe <exec+0x150>
      panic("loadseg: address should exist");
    80005294:	00003517          	auipc	a0,0x3
    80005298:	35c50513          	addi	a0,a0,860 # 800085f0 <etext+0x5f0>
    8000529c:	ffffb097          	auipc	ra,0xffffb
    800052a0:	2c4080e7          	jalr	708(ra) # 80000560 <panic>
    if(sz - i < PGSIZE)
    800052a4:	2481                	sext.w	s1,s1
      n = sz - i;
    else
      n = PGSIZE;
    if(readi(ip, 0, (uint64)pa, offset+i, n) != n)
    800052a6:	8726                	mv	a4,s1
    800052a8:	012c06bb          	addw	a3,s8,s2
    800052ac:	4581                	li	a1,0
    800052ae:	8552                	mv	a0,s4
    800052b0:	fffff097          	auipc	ra,0xfffff
    800052b4:	c48080e7          	jalr	-952(ra) # 80003ef8 <readi>
    800052b8:	2501                	sext.w	a0,a0
    800052ba:	28a49863          	bne	s1,a0,8000554a <exec+0x39c>
  for(i = 0; i < sz; i += PGSIZE){
    800052be:	012a893b          	addw	s2,s5,s2
    800052c2:	03397563          	bgeu	s2,s3,800052ec <exec+0x13e>
    pa = walkaddr(pagetable, va + i);
    800052c6:	02091593          	slli	a1,s2,0x20
    800052ca:	9181                	srli	a1,a1,0x20
    800052cc:	95de                	add	a1,a1,s7
    800052ce:	855a                	mv	a0,s6
    800052d0:	ffffc097          	auipc	ra,0xffffc
    800052d4:	f1c080e7          	jalr	-228(ra) # 800011ec <walkaddr>
    800052d8:	862a                	mv	a2,a0
    if(pa == 0)
    800052da:	dd4d                	beqz	a0,80005294 <exec+0xe6>
    if(sz - i < PGSIZE)
    800052dc:	412984bb          	subw	s1,s3,s2
    800052e0:	0004879b          	sext.w	a5,s1
    800052e4:	fcfcf0e3          	bgeu	s9,a5,800052a4 <exec+0xf6>
    800052e8:	84d6                	mv	s1,s5
    800052ea:	bf6d                	j	800052a4 <exec+0xf6>
    sz = sz1;
    800052ec:	e0843903          	ld	s2,-504(s0)
  for(i=0, off=elf.phoff; i<elf.phnum; i++, off+=sizeof(ph)){
    800052f0:	2d85                	addiw	s11,s11,1
    800052f2:	038d0d1b          	addiw	s10,s10,56
    800052f6:	e8845783          	lhu	a5,-376(s0)
    800052fa:	08fdd663          	bge	s11,a5,80005386 <exec+0x1d8>
    if(readi(ip, 0, (uint64)&ph, off, sizeof(ph)) != sizeof(ph))
    800052fe:	2d01                	sext.w	s10,s10
    80005300:	03800713          	li	a4,56
    80005304:	86ea                	mv	a3,s10
    80005306:	e1840613          	addi	a2,s0,-488
    8000530a:	4581                	li	a1,0
    8000530c:	8552                	mv	a0,s4
    8000530e:	fffff097          	auipc	ra,0xfffff
    80005312:	bea080e7          	jalr	-1046(ra) # 80003ef8 <readi>
    80005316:	03800793          	li	a5,56
    8000531a:	20f51063          	bne	a0,a5,8000551a <exec+0x36c>
    if(ph.type != ELF_PROG_LOAD)
    8000531e:	e1842783          	lw	a5,-488(s0)
    80005322:	4705                	li	a4,1
    80005324:	fce796e3          	bne	a5,a4,800052f0 <exec+0x142>
    if(ph.memsz < ph.filesz)
    80005328:	e4043483          	ld	s1,-448(s0)
    8000532c:	e3843783          	ld	a5,-456(s0)
    80005330:	1ef4e963          	bltu	s1,a5,80005522 <exec+0x374>
    if(ph.vaddr + ph.memsz < ph.vaddr)
    80005334:	e2843783          	ld	a5,-472(s0)
    80005338:	94be                	add	s1,s1,a5
    8000533a:	1ef4e863          	bltu	s1,a5,8000552a <exec+0x37c>
    if(ph.vaddr % PGSIZE != 0)
    8000533e:	df043703          	ld	a4,-528(s0)
    80005342:	8ff9                	and	a5,a5,a4
    80005344:	1e079763          	bnez	a5,80005532 <exec+0x384>
    if((sz1 = uvmalloc(pagetable, sz, ph.vaddr + ph.memsz, flags2perm(ph.flags))) == 0)
    80005348:	e1c42503          	lw	a0,-484(s0)
    8000534c:	00000097          	auipc	ra,0x0
    80005350:	e48080e7          	jalr	-440(ra) # 80005194 <flags2perm>
    80005354:	86aa                	mv	a3,a0
    80005356:	8626                	mv	a2,s1
    80005358:	85ca                	mv	a1,s2
    8000535a:	855a                	mv	a0,s6
    8000535c:	ffffc097          	auipc	ra,0xffffc
    80005360:	254080e7          	jalr	596(ra) # 800015b0 <uvmalloc>
    80005364:	e0a43423          	sd	a0,-504(s0)
    80005368:	1c050963          	beqz	a0,8000553a <exec+0x38c>
    if(loadseg(pagetable, ph.vaddr, ip, ph.off, ph.filesz) < 0)
    8000536c:	e2843b83          	ld	s7,-472(s0)
    80005370:	e2042c03          	lw	s8,-480(s0)
    80005374:	e3842983          	lw	s3,-456(s0)
  for(i = 0; i < sz; i += PGSIZE){
    80005378:	00098463          	beqz	s3,80005380 <exec+0x1d2>
    8000537c:	4901                	li	s2,0
    8000537e:	b7a1                	j	800052c6 <exec+0x118>
    sz = sz1;
    80005380:	e0843903          	ld	s2,-504(s0)
    80005384:	b7b5                	j	800052f0 <exec+0x142>
    80005386:	7dba                	ld	s11,424(sp)
  iunlockput(ip);
    80005388:	8552                	mv	a0,s4
    8000538a:	fffff097          	auipc	ra,0xfffff
    8000538e:	b1c080e7          	jalr	-1252(ra) # 80003ea6 <iunlockput>
  end_op();
    80005392:	fffff097          	auipc	ra,0xfffff
    80005396:	2f6080e7          	jalr	758(ra) # 80004688 <end_op>
  p = myproc();
    8000539a:	ffffd097          	auipc	ra,0xffffd
    8000539e:	89c080e7          	jalr	-1892(ra) # 80001c36 <myproc>
    800053a2:	8aaa                	mv	s5,a0
  uint64 oldsz = p->sz;
    800053a4:	05053c83          	ld	s9,80(a0)
  sz = PGROUNDUP(sz);
    800053a8:	6985                	lui	s3,0x1
    800053aa:	19fd                	addi	s3,s3,-1 # fff <_entry-0x7ffff001>
    800053ac:	99ca                	add	s3,s3,s2
    800053ae:	77fd                	lui	a5,0xfffff
    800053b0:	00f9f9b3          	and	s3,s3,a5
  if((sz1 = uvmalloc(pagetable, sz, sz + 2*PGSIZE, PTE_W)) == 0)
    800053b4:	4691                	li	a3,4
    800053b6:	6609                	lui	a2,0x2
    800053b8:	964e                	add	a2,a2,s3
    800053ba:	85ce                	mv	a1,s3
    800053bc:	855a                	mv	a0,s6
    800053be:	ffffc097          	auipc	ra,0xffffc
    800053c2:	1f2080e7          	jalr	498(ra) # 800015b0 <uvmalloc>
    800053c6:	892a                	mv	s2,a0
    800053c8:	e0a43423          	sd	a0,-504(s0)
    800053cc:	e519                	bnez	a0,800053da <exec+0x22c>
  if(pagetable)
    800053ce:	e1343423          	sd	s3,-504(s0)
    800053d2:	4a01                	li	s4,0
    800053d4:	aaa5                	j	8000554c <exec+0x39e>
  uint64 argc, sz = 0, sp, ustack[MAXARG], stackbase;
    800053d6:	4901                	li	s2,0
    800053d8:	bf45                	j	80005388 <exec+0x1da>
  uvmclear(pagetable, sz-2*PGSIZE);
    800053da:	75f9                	lui	a1,0xffffe
    800053dc:	95aa                	add	a1,a1,a0
    800053de:	855a                	mv	a0,s6
    800053e0:	ffffc097          	auipc	ra,0xffffc
    800053e4:	3ec080e7          	jalr	1004(ra) # 800017cc <uvmclear>
  stackbase = sp - PGSIZE;
    800053e8:	7bfd                	lui	s7,0xfffff
    800053ea:	9bca                	add	s7,s7,s2
  for(argc = 0; argv[argc]; argc++) {
    800053ec:	e0043783          	ld	a5,-512(s0)
    800053f0:	6388                	ld	a0,0(a5)
    800053f2:	c52d                	beqz	a0,8000545c <exec+0x2ae>
    800053f4:	e9040993          	addi	s3,s0,-368
    800053f8:	f9040c13          	addi	s8,s0,-112
    800053fc:	4481                	li	s1,0
    sp -= strlen(argv[argc]) + 1;
    800053fe:	ffffc097          	auipc	ra,0xffffc
    80005402:	be0080e7          	jalr	-1056(ra) # 80000fde <strlen>
    80005406:	0015079b          	addiw	a5,a0,1
    8000540a:	40f907b3          	sub	a5,s2,a5
    sp -= sp % 16; // riscv sp must be 16-byte aligned
    8000540e:	ff07f913          	andi	s2,a5,-16
    if(sp < stackbase)
    80005412:	13796863          	bltu	s2,s7,80005542 <exec+0x394>
    if(copyout(pagetable, sp, argv[argc], strlen(argv[argc]) + 1) < 0)
    80005416:	e0043d03          	ld	s10,-512(s0)
    8000541a:	000d3a03          	ld	s4,0(s10)
    8000541e:	8552                	mv	a0,s4
    80005420:	ffffc097          	auipc	ra,0xffffc
    80005424:	bbe080e7          	jalr	-1090(ra) # 80000fde <strlen>
    80005428:	0015069b          	addiw	a3,a0,1
    8000542c:	8652                	mv	a2,s4
    8000542e:	85ca                	mv	a1,s2
    80005430:	855a                	mv	a0,s6
    80005432:	ffffc097          	auipc	ra,0xffffc
    80005436:	454080e7          	jalr	1108(ra) # 80001886 <copyout>
    8000543a:	10054663          	bltz	a0,80005546 <exec+0x398>
    ustack[argc] = sp;
    8000543e:	0129b023          	sd	s2,0(s3)
  for(argc = 0; argv[argc]; argc++) {
    80005442:	0485                	addi	s1,s1,1
    80005444:	008d0793          	addi	a5,s10,8
    80005448:	e0f43023          	sd	a5,-512(s0)
    8000544c:	008d3503          	ld	a0,8(s10)
    80005450:	c909                	beqz	a0,80005462 <exec+0x2b4>
    if(argc >= MAXARG)
    80005452:	09a1                	addi	s3,s3,8
    80005454:	fb8995e3          	bne	s3,s8,800053fe <exec+0x250>
  ip = 0;
    80005458:	4a01                	li	s4,0
    8000545a:	a8cd                	j	8000554c <exec+0x39e>
  sp = sz;
    8000545c:	e0843903          	ld	s2,-504(s0)
  for(argc = 0; argv[argc]; argc++) {
    80005460:	4481                	li	s1,0
  ustack[argc] = 0;
    80005462:	00349793          	slli	a5,s1,0x3
    80005466:	f9078793          	addi	a5,a5,-112 # ffffffffffffef90 <end+0xffffffff7fdbcc00>
    8000546a:	97a2                	add	a5,a5,s0
    8000546c:	f007b023          	sd	zero,-256(a5)
  sp -= (argc+1) * sizeof(uint64);
    80005470:	00148693          	addi	a3,s1,1
    80005474:	068e                	slli	a3,a3,0x3
    80005476:	40d90933          	sub	s2,s2,a3
  sp -= sp % 16;
    8000547a:	ff097913          	andi	s2,s2,-16
  sz = sz1;
    8000547e:	e0843983          	ld	s3,-504(s0)
  if(sp < stackbase)
    80005482:	f57966e3          	bltu	s2,s7,800053ce <exec+0x220>
  if(copyout(pagetable, sp, (char *)ustack, (argc+1)*sizeof(uint64)) < 0)
    80005486:	e9040613          	addi	a2,s0,-368
    8000548a:	85ca                	mv	a1,s2
    8000548c:	855a                	mv	a0,s6
    8000548e:	ffffc097          	auipc	ra,0xffffc
    80005492:	3f8080e7          	jalr	1016(ra) # 80001886 <copyout>
    80005496:	0e054863          	bltz	a0,80005586 <exec+0x3d8>
  p->trapframe->a1 = sp;
    8000549a:	060ab783          	ld	a5,96(s5) # 1060 <_entry-0x7fffefa0>
    8000549e:	0727bc23          	sd	s2,120(a5)
  for(last=s=path; *s; s++)
    800054a2:	df843783          	ld	a5,-520(s0)
    800054a6:	0007c703          	lbu	a4,0(a5)
    800054aa:	cf11                	beqz	a4,800054c6 <exec+0x318>
    800054ac:	0785                	addi	a5,a5,1
    if(*s == '/')
    800054ae:	02f00693          	li	a3,47
    800054b2:	a039                	j	800054c0 <exec+0x312>
      last = s+1;
    800054b4:	def43c23          	sd	a5,-520(s0)
  for(last=s=path; *s; s++)
    800054b8:	0785                	addi	a5,a5,1
    800054ba:	fff7c703          	lbu	a4,-1(a5)
    800054be:	c701                	beqz	a4,800054c6 <exec+0x318>
    if(*s == '/')
    800054c0:	fed71ce3          	bne	a4,a3,800054b8 <exec+0x30a>
    800054c4:	bfc5                	j	800054b4 <exec+0x306>
  safestrcpy(p->name, last, sizeof(p->name));
    800054c6:	4641                	li	a2,16
    800054c8:	df843583          	ld	a1,-520(s0)
    800054cc:	160a8513          	addi	a0,s5,352
    800054d0:	ffffc097          	auipc	ra,0xffffc
    800054d4:	adc080e7          	jalr	-1316(ra) # 80000fac <safestrcpy>
  oldpagetable = p->pagetable;
    800054d8:	058ab503          	ld	a0,88(s5)
  p->pagetable = pagetable;
    800054dc:	056abc23          	sd	s6,88(s5)
  p->sz = sz;
    800054e0:	e0843783          	ld	a5,-504(s0)
    800054e4:	04fab823          	sd	a5,80(s5)
  p->trapframe->epc = elf.entry;  // initial program counter = main
    800054e8:	060ab783          	ld	a5,96(s5)
    800054ec:	e6843703          	ld	a4,-408(s0)
    800054f0:	ef98                	sd	a4,24(a5)
  p->trapframe->sp = sp; // initial stack pointer
    800054f2:	060ab783          	ld	a5,96(s5)
    800054f6:	0327b823          	sd	s2,48(a5)
  proc_freepagetable(oldpagetable, oldsz);
    800054fa:	85e6                	mv	a1,s9
    800054fc:	ffffd097          	auipc	ra,0xffffd
    80005500:	89c080e7          	jalr	-1892(ra) # 80001d98 <proc_freepagetable>
  return argc; // this ends up in a0, the first argument to main(argc, argv)
    80005504:	0004851b          	sext.w	a0,s1
    80005508:	79be                	ld	s3,488(sp)
    8000550a:	7a1e                	ld	s4,480(sp)
    8000550c:	6afe                	ld	s5,472(sp)
    8000550e:	6b5e                	ld	s6,464(sp)
    80005510:	6bbe                	ld	s7,456(sp)
    80005512:	6c1e                	ld	s8,448(sp)
    80005514:	7cfa                	ld	s9,440(sp)
    80005516:	7d5a                	ld	s10,432(sp)
    80005518:	b305                	j	80005238 <exec+0x8a>
    8000551a:	e1243423          	sd	s2,-504(s0)
    8000551e:	7dba                	ld	s11,424(sp)
    80005520:	a035                	j	8000554c <exec+0x39e>
    80005522:	e1243423          	sd	s2,-504(s0)
    80005526:	7dba                	ld	s11,424(sp)
    80005528:	a015                	j	8000554c <exec+0x39e>
    8000552a:	e1243423          	sd	s2,-504(s0)
    8000552e:	7dba                	ld	s11,424(sp)
    80005530:	a831                	j	8000554c <exec+0x39e>
    80005532:	e1243423          	sd	s2,-504(s0)
    80005536:	7dba                	ld	s11,424(sp)
    80005538:	a811                	j	8000554c <exec+0x39e>
    8000553a:	e1243423          	sd	s2,-504(s0)
    8000553e:	7dba                	ld	s11,424(sp)
    80005540:	a031                	j	8000554c <exec+0x39e>
  ip = 0;
    80005542:	4a01                	li	s4,0
    80005544:	a021                	j	8000554c <exec+0x39e>
    80005546:	4a01                	li	s4,0
  if(pagetable)
    80005548:	a011                	j	8000554c <exec+0x39e>
    8000554a:	7dba                	ld	s11,424(sp)
    proc_freepagetable(pagetable, sz);
    8000554c:	e0843583          	ld	a1,-504(s0)
    80005550:	855a                	mv	a0,s6
    80005552:	ffffd097          	auipc	ra,0xffffd
    80005556:	846080e7          	jalr	-1978(ra) # 80001d98 <proc_freepagetable>
  return -1;
    8000555a:	557d                	li	a0,-1
  if(ip){
    8000555c:	000a1b63          	bnez	s4,80005572 <exec+0x3c4>
    80005560:	79be                	ld	s3,488(sp)
    80005562:	7a1e                	ld	s4,480(sp)
    80005564:	6afe                	ld	s5,472(sp)
    80005566:	6b5e                	ld	s6,464(sp)
    80005568:	6bbe                	ld	s7,456(sp)
    8000556a:	6c1e                	ld	s8,448(sp)
    8000556c:	7cfa                	ld	s9,440(sp)
    8000556e:	7d5a                	ld	s10,432(sp)
    80005570:	b1e1                	j	80005238 <exec+0x8a>
    80005572:	79be                	ld	s3,488(sp)
    80005574:	6afe                	ld	s5,472(sp)
    80005576:	6b5e                	ld	s6,464(sp)
    80005578:	6bbe                	ld	s7,456(sp)
    8000557a:	6c1e                	ld	s8,448(sp)
    8000557c:	7cfa                	ld	s9,440(sp)
    8000557e:	7d5a                	ld	s10,432(sp)
    80005580:	b14d                	j	80005222 <exec+0x74>
    80005582:	6b5e                	ld	s6,464(sp)
    80005584:	b979                	j	80005222 <exec+0x74>
  sz = sz1;
    80005586:	e0843983          	ld	s3,-504(s0)
    8000558a:	b591                	j	800053ce <exec+0x220>

000000008000558c <argfd>:

// Fetch the nth word-sized system call argument as a file descriptor
// and return both the descriptor and the corresponding struct file.
static int
argfd(int n, int *pfd, struct file **pf)
{
    8000558c:	7179                	addi	sp,sp,-48
    8000558e:	f406                	sd	ra,40(sp)
    80005590:	f022                	sd	s0,32(sp)
    80005592:	ec26                	sd	s1,24(sp)
    80005594:	e84a                	sd	s2,16(sp)
    80005596:	1800                	addi	s0,sp,48
    80005598:	892e                	mv	s2,a1
    8000559a:	84b2                	mv	s1,a2
  int fd;
  struct file *f;

  argint(n, &fd);
    8000559c:	fdc40593          	addi	a1,s0,-36
    800055a0:	ffffe097          	auipc	ra,0xffffe
    800055a4:	a38080e7          	jalr	-1480(ra) # 80002fd8 <argint>
  if(fd < 0 || fd >= NOFILE || (f=myproc()->ofile[fd]) == 0)
    800055a8:	fdc42703          	lw	a4,-36(s0)
    800055ac:	47bd                	li	a5,15
    800055ae:	02e7eb63          	bltu	a5,a4,800055e4 <argfd+0x58>
    800055b2:	ffffc097          	auipc	ra,0xffffc
    800055b6:	684080e7          	jalr	1668(ra) # 80001c36 <myproc>
    800055ba:	fdc42703          	lw	a4,-36(s0)
    800055be:	01a70793          	addi	a5,a4,26
    800055c2:	078e                	slli	a5,a5,0x3
    800055c4:	953e                	add	a0,a0,a5
    800055c6:	651c                	ld	a5,8(a0)
    800055c8:	c385                	beqz	a5,800055e8 <argfd+0x5c>
    return -1;
  if(pfd)
    800055ca:	00090463          	beqz	s2,800055d2 <argfd+0x46>
    *pfd = fd;
    800055ce:	00e92023          	sw	a4,0(s2)
  if(pf)
    *pf = f;
  return 0;
    800055d2:	4501                	li	a0,0
  if(pf)
    800055d4:	c091                	beqz	s1,800055d8 <argfd+0x4c>
    *pf = f;
    800055d6:	e09c                	sd	a5,0(s1)
}
    800055d8:	70a2                	ld	ra,40(sp)
    800055da:	7402                	ld	s0,32(sp)
    800055dc:	64e2                	ld	s1,24(sp)
    800055de:	6942                	ld	s2,16(sp)
    800055e0:	6145                	addi	sp,sp,48
    800055e2:	8082                	ret
    return -1;
    800055e4:	557d                	li	a0,-1
    800055e6:	bfcd                	j	800055d8 <argfd+0x4c>
    800055e8:	557d                	li	a0,-1
    800055ea:	b7fd                	j	800055d8 <argfd+0x4c>

00000000800055ec <fdalloc>:

// Allocate a file descriptor for the given file.
// Takes over file reference from caller on success.
static int
fdalloc(struct file *f)
{
    800055ec:	1101                	addi	sp,sp,-32
    800055ee:	ec06                	sd	ra,24(sp)
    800055f0:	e822                	sd	s0,16(sp)
    800055f2:	e426                	sd	s1,8(sp)
    800055f4:	1000                	addi	s0,sp,32
    800055f6:	84aa                	mv	s1,a0
  int fd;
  struct proc *p = myproc();
    800055f8:	ffffc097          	auipc	ra,0xffffc
    800055fc:	63e080e7          	jalr	1598(ra) # 80001c36 <myproc>
    80005600:	862a                	mv	a2,a0

  for(fd = 0; fd < NOFILE; fd++){
    80005602:	0d850793          	addi	a5,a0,216
    80005606:	4501                	li	a0,0
    80005608:	46c1                	li	a3,16
    if(p->ofile[fd] == 0){
    8000560a:	6398                	ld	a4,0(a5)
    8000560c:	cb19                	beqz	a4,80005622 <fdalloc+0x36>
  for(fd = 0; fd < NOFILE; fd++){
    8000560e:	2505                	addiw	a0,a0,1
    80005610:	07a1                	addi	a5,a5,8
    80005612:	fed51ce3          	bne	a0,a3,8000560a <fdalloc+0x1e>
      p->ofile[fd] = f;
      return fd;
    }
  }
  return -1;
    80005616:	557d                	li	a0,-1
}
    80005618:	60e2                	ld	ra,24(sp)
    8000561a:	6442                	ld	s0,16(sp)
    8000561c:	64a2                	ld	s1,8(sp)
    8000561e:	6105                	addi	sp,sp,32
    80005620:	8082                	ret
      p->ofile[fd] = f;
    80005622:	01a50793          	addi	a5,a0,26
    80005626:	078e                	slli	a5,a5,0x3
    80005628:	963e                	add	a2,a2,a5
    8000562a:	e604                	sd	s1,8(a2)
      return fd;
    8000562c:	b7f5                	j	80005618 <fdalloc+0x2c>

000000008000562e <create>:
  return -1;
}

static struct inode*
create(char *path, short type, short major, short minor)
{
    8000562e:	715d                	addi	sp,sp,-80
    80005630:	e486                	sd	ra,72(sp)
    80005632:	e0a2                	sd	s0,64(sp)
    80005634:	fc26                	sd	s1,56(sp)
    80005636:	f84a                	sd	s2,48(sp)
    80005638:	f44e                	sd	s3,40(sp)
    8000563a:	ec56                	sd	s5,24(sp)
    8000563c:	e85a                	sd	s6,16(sp)
    8000563e:	0880                	addi	s0,sp,80
    80005640:	8b2e                	mv	s6,a1
    80005642:	89b2                	mv	s3,a2
    80005644:	8936                	mv	s2,a3
  struct inode *ip, *dp;
  char name[DIRSIZ];

  if((dp = nameiparent(path, name)) == 0)
    80005646:	fb040593          	addi	a1,s0,-80
    8000564a:	fffff097          	auipc	ra,0xfffff
    8000564e:	de2080e7          	jalr	-542(ra) # 8000442c <nameiparent>
    80005652:	84aa                	mv	s1,a0
    80005654:	14050e63          	beqz	a0,800057b0 <create+0x182>
    return 0;

  ilock(dp);
    80005658:	ffffe097          	auipc	ra,0xffffe
    8000565c:	5e8080e7          	jalr	1512(ra) # 80003c40 <ilock>

  if((ip = dirlookup(dp, name, 0)) != 0){
    80005660:	4601                	li	a2,0
    80005662:	fb040593          	addi	a1,s0,-80
    80005666:	8526                	mv	a0,s1
    80005668:	fffff097          	auipc	ra,0xfffff
    8000566c:	ae4080e7          	jalr	-1308(ra) # 8000414c <dirlookup>
    80005670:	8aaa                	mv	s5,a0
    80005672:	c539                	beqz	a0,800056c0 <create+0x92>
    iunlockput(dp);
    80005674:	8526                	mv	a0,s1
    80005676:	fffff097          	auipc	ra,0xfffff
    8000567a:	830080e7          	jalr	-2000(ra) # 80003ea6 <iunlockput>
    ilock(ip);
    8000567e:	8556                	mv	a0,s5
    80005680:	ffffe097          	auipc	ra,0xffffe
    80005684:	5c0080e7          	jalr	1472(ra) # 80003c40 <ilock>
    if(type == T_FILE && (ip->type == T_FILE || ip->type == T_DEVICE))
    80005688:	4789                	li	a5,2
    8000568a:	02fb1463          	bne	s6,a5,800056b2 <create+0x84>
    8000568e:	044ad783          	lhu	a5,68(s5)
    80005692:	37f9                	addiw	a5,a5,-2
    80005694:	17c2                	slli	a5,a5,0x30
    80005696:	93c1                	srli	a5,a5,0x30
    80005698:	4705                	li	a4,1
    8000569a:	00f76c63          	bltu	a4,a5,800056b2 <create+0x84>
  ip->nlink = 0;
  iupdate(ip);
  iunlockput(ip);
  iunlockput(dp);
  return 0;
}
    8000569e:	8556                	mv	a0,s5
    800056a0:	60a6                	ld	ra,72(sp)
    800056a2:	6406                	ld	s0,64(sp)
    800056a4:	74e2                	ld	s1,56(sp)
    800056a6:	7942                	ld	s2,48(sp)
    800056a8:	79a2                	ld	s3,40(sp)
    800056aa:	6ae2                	ld	s5,24(sp)
    800056ac:	6b42                	ld	s6,16(sp)
    800056ae:	6161                	addi	sp,sp,80
    800056b0:	8082                	ret
    iunlockput(ip);
    800056b2:	8556                	mv	a0,s5
    800056b4:	ffffe097          	auipc	ra,0xffffe
    800056b8:	7f2080e7          	jalr	2034(ra) # 80003ea6 <iunlockput>
    return 0;
    800056bc:	4a81                	li	s5,0
    800056be:	b7c5                	j	8000569e <create+0x70>
    800056c0:	f052                	sd	s4,32(sp)
  if((ip = ialloc(dp->dev, type)) == 0){
    800056c2:	85da                	mv	a1,s6
    800056c4:	4088                	lw	a0,0(s1)
    800056c6:	ffffe097          	auipc	ra,0xffffe
    800056ca:	3d6080e7          	jalr	982(ra) # 80003a9c <ialloc>
    800056ce:	8a2a                	mv	s4,a0
    800056d0:	c531                	beqz	a0,8000571c <create+0xee>
  ilock(ip);
    800056d2:	ffffe097          	auipc	ra,0xffffe
    800056d6:	56e080e7          	jalr	1390(ra) # 80003c40 <ilock>
  ip->major = major;
    800056da:	053a1323          	sh	s3,70(s4)
  ip->minor = minor;
    800056de:	052a1423          	sh	s2,72(s4)
  ip->nlink = 1;
    800056e2:	4905                	li	s2,1
    800056e4:	052a1523          	sh	s2,74(s4)
  iupdate(ip);
    800056e8:	8552                	mv	a0,s4
    800056ea:	ffffe097          	auipc	ra,0xffffe
    800056ee:	48a080e7          	jalr	1162(ra) # 80003b74 <iupdate>
  if(type == T_DIR){  // Create . and .. entries.
    800056f2:	032b0d63          	beq	s6,s2,8000572c <create+0xfe>
  if(dirlink(dp, name, ip->inum) < 0)
    800056f6:	004a2603          	lw	a2,4(s4)
    800056fa:	fb040593          	addi	a1,s0,-80
    800056fe:	8526                	mv	a0,s1
    80005700:	fffff097          	auipc	ra,0xfffff
    80005704:	c5c080e7          	jalr	-932(ra) # 8000435c <dirlink>
    80005708:	08054163          	bltz	a0,8000578a <create+0x15c>
  iunlockput(dp);
    8000570c:	8526                	mv	a0,s1
    8000570e:	ffffe097          	auipc	ra,0xffffe
    80005712:	798080e7          	jalr	1944(ra) # 80003ea6 <iunlockput>
  return ip;
    80005716:	8ad2                	mv	s5,s4
    80005718:	7a02                	ld	s4,32(sp)
    8000571a:	b751                	j	8000569e <create+0x70>
    iunlockput(dp);
    8000571c:	8526                	mv	a0,s1
    8000571e:	ffffe097          	auipc	ra,0xffffe
    80005722:	788080e7          	jalr	1928(ra) # 80003ea6 <iunlockput>
    return 0;
    80005726:	8ad2                	mv	s5,s4
    80005728:	7a02                	ld	s4,32(sp)
    8000572a:	bf95                	j	8000569e <create+0x70>
    if(dirlink(ip, ".", ip->inum) < 0 || dirlink(ip, "..", dp->inum) < 0)
    8000572c:	004a2603          	lw	a2,4(s4)
    80005730:	00003597          	auipc	a1,0x3
    80005734:	ee058593          	addi	a1,a1,-288 # 80008610 <etext+0x610>
    80005738:	8552                	mv	a0,s4
    8000573a:	fffff097          	auipc	ra,0xfffff
    8000573e:	c22080e7          	jalr	-990(ra) # 8000435c <dirlink>
    80005742:	04054463          	bltz	a0,8000578a <create+0x15c>
    80005746:	40d0                	lw	a2,4(s1)
    80005748:	00003597          	auipc	a1,0x3
    8000574c:	ed058593          	addi	a1,a1,-304 # 80008618 <etext+0x618>
    80005750:	8552                	mv	a0,s4
    80005752:	fffff097          	auipc	ra,0xfffff
    80005756:	c0a080e7          	jalr	-1014(ra) # 8000435c <dirlink>
    8000575a:	02054863          	bltz	a0,8000578a <create+0x15c>
  if(dirlink(dp, name, ip->inum) < 0)
    8000575e:	004a2603          	lw	a2,4(s4)
    80005762:	fb040593          	addi	a1,s0,-80
    80005766:	8526                	mv	a0,s1
    80005768:	fffff097          	auipc	ra,0xfffff
    8000576c:	bf4080e7          	jalr	-1036(ra) # 8000435c <dirlink>
    80005770:	00054d63          	bltz	a0,8000578a <create+0x15c>
    dp->nlink++;  // for ".."
    80005774:	04a4d783          	lhu	a5,74(s1)
    80005778:	2785                	addiw	a5,a5,1
    8000577a:	04f49523          	sh	a5,74(s1)
    iupdate(dp);
    8000577e:	8526                	mv	a0,s1
    80005780:	ffffe097          	auipc	ra,0xffffe
    80005784:	3f4080e7          	jalr	1012(ra) # 80003b74 <iupdate>
    80005788:	b751                	j	8000570c <create+0xde>
  ip->nlink = 0;
    8000578a:	040a1523          	sh	zero,74(s4)
  iupdate(ip);
    8000578e:	8552                	mv	a0,s4
    80005790:	ffffe097          	auipc	ra,0xffffe
    80005794:	3e4080e7          	jalr	996(ra) # 80003b74 <iupdate>
  iunlockput(ip);
    80005798:	8552                	mv	a0,s4
    8000579a:	ffffe097          	auipc	ra,0xffffe
    8000579e:	70c080e7          	jalr	1804(ra) # 80003ea6 <iunlockput>
  iunlockput(dp);
    800057a2:	8526                	mv	a0,s1
    800057a4:	ffffe097          	auipc	ra,0xffffe
    800057a8:	702080e7          	jalr	1794(ra) # 80003ea6 <iunlockput>
  return 0;
    800057ac:	7a02                	ld	s4,32(sp)
    800057ae:	bdc5                	j	8000569e <create+0x70>
    return 0;
    800057b0:	8aaa                	mv	s5,a0
    800057b2:	b5f5                	j	8000569e <create+0x70>

00000000800057b4 <sys_dup>:
{
    800057b4:	7179                	addi	sp,sp,-48
    800057b6:	f406                	sd	ra,40(sp)
    800057b8:	f022                	sd	s0,32(sp)
    800057ba:	1800                	addi	s0,sp,48
  if(argfd(0, 0, &f) < 0)
    800057bc:	fd840613          	addi	a2,s0,-40
    800057c0:	4581                	li	a1,0
    800057c2:	4501                	li	a0,0
    800057c4:	00000097          	auipc	ra,0x0
    800057c8:	dc8080e7          	jalr	-568(ra) # 8000558c <argfd>
    return -1;
    800057cc:	57fd                	li	a5,-1
  if(argfd(0, 0, &f) < 0)
    800057ce:	02054763          	bltz	a0,800057fc <sys_dup+0x48>
    800057d2:	ec26                	sd	s1,24(sp)
    800057d4:	e84a                	sd	s2,16(sp)
  if((fd=fdalloc(f)) < 0)
    800057d6:	fd843903          	ld	s2,-40(s0)
    800057da:	854a                	mv	a0,s2
    800057dc:	00000097          	auipc	ra,0x0
    800057e0:	e10080e7          	jalr	-496(ra) # 800055ec <fdalloc>
    800057e4:	84aa                	mv	s1,a0
    return -1;
    800057e6:	57fd                	li	a5,-1
  if((fd=fdalloc(f)) < 0)
    800057e8:	00054f63          	bltz	a0,80005806 <sys_dup+0x52>
  filedup(f);
    800057ec:	854a                	mv	a0,s2
    800057ee:	fffff097          	auipc	ra,0xfffff
    800057f2:	298080e7          	jalr	664(ra) # 80004a86 <filedup>
  return fd;
    800057f6:	87a6                	mv	a5,s1
    800057f8:	64e2                	ld	s1,24(sp)
    800057fa:	6942                	ld	s2,16(sp)
}
    800057fc:	853e                	mv	a0,a5
    800057fe:	70a2                	ld	ra,40(sp)
    80005800:	7402                	ld	s0,32(sp)
    80005802:	6145                	addi	sp,sp,48
    80005804:	8082                	ret
    80005806:	64e2                	ld	s1,24(sp)
    80005808:	6942                	ld	s2,16(sp)
    8000580a:	bfcd                	j	800057fc <sys_dup+0x48>

000000008000580c <sys_read>:
{
    8000580c:	7179                	addi	sp,sp,-48
    8000580e:	f406                	sd	ra,40(sp)
    80005810:	f022                	sd	s0,32(sp)
    80005812:	1800                	addi	s0,sp,48
  argaddr(1, &p);
    80005814:	fd840593          	addi	a1,s0,-40
    80005818:	4505                	li	a0,1
    8000581a:	ffffd097          	auipc	ra,0xffffd
    8000581e:	7de080e7          	jalr	2014(ra) # 80002ff8 <argaddr>
  argint(2, &n);
    80005822:	fe440593          	addi	a1,s0,-28
    80005826:	4509                	li	a0,2
    80005828:	ffffd097          	auipc	ra,0xffffd
    8000582c:	7b0080e7          	jalr	1968(ra) # 80002fd8 <argint>
  if(argfd(0, 0, &f) < 0)
    80005830:	fe840613          	addi	a2,s0,-24
    80005834:	4581                	li	a1,0
    80005836:	4501                	li	a0,0
    80005838:	00000097          	auipc	ra,0x0
    8000583c:	d54080e7          	jalr	-684(ra) # 8000558c <argfd>
    80005840:	87aa                	mv	a5,a0
    return -1;
    80005842:	557d                	li	a0,-1
  if(argfd(0, 0, &f) < 0)
    80005844:	0007cc63          	bltz	a5,8000585c <sys_read+0x50>
  return fileread(f, p, n);
    80005848:	fe442603          	lw	a2,-28(s0)
    8000584c:	fd843583          	ld	a1,-40(s0)
    80005850:	fe843503          	ld	a0,-24(s0)
    80005854:	fffff097          	auipc	ra,0xfffff
    80005858:	3d8080e7          	jalr	984(ra) # 80004c2c <fileread>
}
    8000585c:	70a2                	ld	ra,40(sp)
    8000585e:	7402                	ld	s0,32(sp)
    80005860:	6145                	addi	sp,sp,48
    80005862:	8082                	ret

0000000080005864 <sys_write>:
{
    80005864:	7179                	addi	sp,sp,-48
    80005866:	f406                	sd	ra,40(sp)
    80005868:	f022                	sd	s0,32(sp)
    8000586a:	1800                	addi	s0,sp,48
  argaddr(1, &p);
    8000586c:	fd840593          	addi	a1,s0,-40
    80005870:	4505                	li	a0,1
    80005872:	ffffd097          	auipc	ra,0xffffd
    80005876:	786080e7          	jalr	1926(ra) # 80002ff8 <argaddr>
  argint(2, &n);
    8000587a:	fe440593          	addi	a1,s0,-28
    8000587e:	4509                	li	a0,2
    80005880:	ffffd097          	auipc	ra,0xffffd
    80005884:	758080e7          	jalr	1880(ra) # 80002fd8 <argint>
  if(argfd(0, 0, &f) < 0)
    80005888:	fe840613          	addi	a2,s0,-24
    8000588c:	4581                	li	a1,0
    8000588e:	4501                	li	a0,0
    80005890:	00000097          	auipc	ra,0x0
    80005894:	cfc080e7          	jalr	-772(ra) # 8000558c <argfd>
    80005898:	87aa                	mv	a5,a0
    return -1;
    8000589a:	557d                	li	a0,-1
  if(argfd(0, 0, &f) < 0)
    8000589c:	0007cc63          	bltz	a5,800058b4 <sys_write+0x50>
  return filewrite(f, p, n);
    800058a0:	fe442603          	lw	a2,-28(s0)
    800058a4:	fd843583          	ld	a1,-40(s0)
    800058a8:	fe843503          	ld	a0,-24(s0)
    800058ac:	fffff097          	auipc	ra,0xfffff
    800058b0:	452080e7          	jalr	1106(ra) # 80004cfe <filewrite>
}
    800058b4:	70a2                	ld	ra,40(sp)
    800058b6:	7402                	ld	s0,32(sp)
    800058b8:	6145                	addi	sp,sp,48
    800058ba:	8082                	ret

00000000800058bc <sys_close>:
{
    800058bc:	1101                	addi	sp,sp,-32
    800058be:	ec06                	sd	ra,24(sp)
    800058c0:	e822                	sd	s0,16(sp)
    800058c2:	1000                	addi	s0,sp,32
  if(argfd(0, &fd, &f) < 0)
    800058c4:	fe040613          	addi	a2,s0,-32
    800058c8:	fec40593          	addi	a1,s0,-20
    800058cc:	4501                	li	a0,0
    800058ce:	00000097          	auipc	ra,0x0
    800058d2:	cbe080e7          	jalr	-834(ra) # 8000558c <argfd>
    return -1;
    800058d6:	57fd                	li	a5,-1
  if(argfd(0, &fd, &f) < 0)
    800058d8:	02054463          	bltz	a0,80005900 <sys_close+0x44>
  myproc()->ofile[fd] = 0;
    800058dc:	ffffc097          	auipc	ra,0xffffc
    800058e0:	35a080e7          	jalr	858(ra) # 80001c36 <myproc>
    800058e4:	fec42783          	lw	a5,-20(s0)
    800058e8:	07e9                	addi	a5,a5,26
    800058ea:	078e                	slli	a5,a5,0x3
    800058ec:	953e                	add	a0,a0,a5
    800058ee:	00053423          	sd	zero,8(a0)
  fileclose(f);
    800058f2:	fe043503          	ld	a0,-32(s0)
    800058f6:	fffff097          	auipc	ra,0xfffff
    800058fa:	1e2080e7          	jalr	482(ra) # 80004ad8 <fileclose>
  return 0;
    800058fe:	4781                	li	a5,0
}
    80005900:	853e                	mv	a0,a5
    80005902:	60e2                	ld	ra,24(sp)
    80005904:	6442                	ld	s0,16(sp)
    80005906:	6105                	addi	sp,sp,32
    80005908:	8082                	ret

000000008000590a <sys_fstat>:
{
    8000590a:	1101                	addi	sp,sp,-32
    8000590c:	ec06                	sd	ra,24(sp)
    8000590e:	e822                	sd	s0,16(sp)
    80005910:	1000                	addi	s0,sp,32
  argaddr(1, &st);
    80005912:	fe040593          	addi	a1,s0,-32
    80005916:	4505                	li	a0,1
    80005918:	ffffd097          	auipc	ra,0xffffd
    8000591c:	6e0080e7          	jalr	1760(ra) # 80002ff8 <argaddr>
  if(argfd(0, 0, &f) < 0)
    80005920:	fe840613          	addi	a2,s0,-24
    80005924:	4581                	li	a1,0
    80005926:	4501                	li	a0,0
    80005928:	00000097          	auipc	ra,0x0
    8000592c:	c64080e7          	jalr	-924(ra) # 8000558c <argfd>
    80005930:	87aa                	mv	a5,a0
    return -1;
    80005932:	557d                	li	a0,-1
  if(argfd(0, 0, &f) < 0)
    80005934:	0007ca63          	bltz	a5,80005948 <sys_fstat+0x3e>
  return filestat(f, st);
    80005938:	fe043583          	ld	a1,-32(s0)
    8000593c:	fe843503          	ld	a0,-24(s0)
    80005940:	fffff097          	auipc	ra,0xfffff
    80005944:	27a080e7          	jalr	634(ra) # 80004bba <filestat>
}
    80005948:	60e2                	ld	ra,24(sp)
    8000594a:	6442                	ld	s0,16(sp)
    8000594c:	6105                	addi	sp,sp,32
    8000594e:	8082                	ret

0000000080005950 <sys_link>:
{
    80005950:	7169                	addi	sp,sp,-304
    80005952:	f606                	sd	ra,296(sp)
    80005954:	f222                	sd	s0,288(sp)
    80005956:	1a00                	addi	s0,sp,304
  if(argstr(0, old, MAXPATH) < 0 || argstr(1, new, MAXPATH) < 0)
    80005958:	08000613          	li	a2,128
    8000595c:	ed040593          	addi	a1,s0,-304
    80005960:	4501                	li	a0,0
    80005962:	ffffd097          	auipc	ra,0xffffd
    80005966:	6b6080e7          	jalr	1718(ra) # 80003018 <argstr>
    return -1;
    8000596a:	57fd                	li	a5,-1
  if(argstr(0, old, MAXPATH) < 0 || argstr(1, new, MAXPATH) < 0)
    8000596c:	12054663          	bltz	a0,80005a98 <sys_link+0x148>
    80005970:	08000613          	li	a2,128
    80005974:	f5040593          	addi	a1,s0,-176
    80005978:	4505                	li	a0,1
    8000597a:	ffffd097          	auipc	ra,0xffffd
    8000597e:	69e080e7          	jalr	1694(ra) # 80003018 <argstr>
    return -1;
    80005982:	57fd                	li	a5,-1
  if(argstr(0, old, MAXPATH) < 0 || argstr(1, new, MAXPATH) < 0)
    80005984:	10054a63          	bltz	a0,80005a98 <sys_link+0x148>
    80005988:	ee26                	sd	s1,280(sp)
  begin_op();
    8000598a:	fffff097          	auipc	ra,0xfffff
    8000598e:	c84080e7          	jalr	-892(ra) # 8000460e <begin_op>
  if((ip = namei(old)) == 0){
    80005992:	ed040513          	addi	a0,s0,-304
    80005996:	fffff097          	auipc	ra,0xfffff
    8000599a:	a78080e7          	jalr	-1416(ra) # 8000440e <namei>
    8000599e:	84aa                	mv	s1,a0
    800059a0:	c949                	beqz	a0,80005a32 <sys_link+0xe2>
  ilock(ip);
    800059a2:	ffffe097          	auipc	ra,0xffffe
    800059a6:	29e080e7          	jalr	670(ra) # 80003c40 <ilock>
  if(ip->type == T_DIR){
    800059aa:	04449703          	lh	a4,68(s1)
    800059ae:	4785                	li	a5,1
    800059b0:	08f70863          	beq	a4,a5,80005a40 <sys_link+0xf0>
    800059b4:	ea4a                	sd	s2,272(sp)
  ip->nlink++;
    800059b6:	04a4d783          	lhu	a5,74(s1)
    800059ba:	2785                	addiw	a5,a5,1
    800059bc:	04f49523          	sh	a5,74(s1)
  iupdate(ip);
    800059c0:	8526                	mv	a0,s1
    800059c2:	ffffe097          	auipc	ra,0xffffe
    800059c6:	1b2080e7          	jalr	434(ra) # 80003b74 <iupdate>
  iunlock(ip);
    800059ca:	8526                	mv	a0,s1
    800059cc:	ffffe097          	auipc	ra,0xffffe
    800059d0:	33a080e7          	jalr	826(ra) # 80003d06 <iunlock>
  if((dp = nameiparent(new, name)) == 0)
    800059d4:	fd040593          	addi	a1,s0,-48
    800059d8:	f5040513          	addi	a0,s0,-176
    800059dc:	fffff097          	auipc	ra,0xfffff
    800059e0:	a50080e7          	jalr	-1456(ra) # 8000442c <nameiparent>
    800059e4:	892a                	mv	s2,a0
    800059e6:	cd35                	beqz	a0,80005a62 <sys_link+0x112>
  ilock(dp);
    800059e8:	ffffe097          	auipc	ra,0xffffe
    800059ec:	258080e7          	jalr	600(ra) # 80003c40 <ilock>
  if(dp->dev != ip->dev || dirlink(dp, name, ip->inum) < 0){
    800059f0:	00092703          	lw	a4,0(s2)
    800059f4:	409c                	lw	a5,0(s1)
    800059f6:	06f71163          	bne	a4,a5,80005a58 <sys_link+0x108>
    800059fa:	40d0                	lw	a2,4(s1)
    800059fc:	fd040593          	addi	a1,s0,-48
    80005a00:	854a                	mv	a0,s2
    80005a02:	fffff097          	auipc	ra,0xfffff
    80005a06:	95a080e7          	jalr	-1702(ra) # 8000435c <dirlink>
    80005a0a:	04054763          	bltz	a0,80005a58 <sys_link+0x108>
  iunlockput(dp);
    80005a0e:	854a                	mv	a0,s2
    80005a10:	ffffe097          	auipc	ra,0xffffe
    80005a14:	496080e7          	jalr	1174(ra) # 80003ea6 <iunlockput>
  iput(ip);
    80005a18:	8526                	mv	a0,s1
    80005a1a:	ffffe097          	auipc	ra,0xffffe
    80005a1e:	3e4080e7          	jalr	996(ra) # 80003dfe <iput>
  end_op();
    80005a22:	fffff097          	auipc	ra,0xfffff
    80005a26:	c66080e7          	jalr	-922(ra) # 80004688 <end_op>
  return 0;
    80005a2a:	4781                	li	a5,0
    80005a2c:	64f2                	ld	s1,280(sp)
    80005a2e:	6952                	ld	s2,272(sp)
    80005a30:	a0a5                	j	80005a98 <sys_link+0x148>
    end_op();
    80005a32:	fffff097          	auipc	ra,0xfffff
    80005a36:	c56080e7          	jalr	-938(ra) # 80004688 <end_op>
    return -1;
    80005a3a:	57fd                	li	a5,-1
    80005a3c:	64f2                	ld	s1,280(sp)
    80005a3e:	a8a9                	j	80005a98 <sys_link+0x148>
    iunlockput(ip);
    80005a40:	8526                	mv	a0,s1
    80005a42:	ffffe097          	auipc	ra,0xffffe
    80005a46:	464080e7          	jalr	1124(ra) # 80003ea6 <iunlockput>
    end_op();
    80005a4a:	fffff097          	auipc	ra,0xfffff
    80005a4e:	c3e080e7          	jalr	-962(ra) # 80004688 <end_op>
    return -1;
    80005a52:	57fd                	li	a5,-1
    80005a54:	64f2                	ld	s1,280(sp)
    80005a56:	a089                	j	80005a98 <sys_link+0x148>
    iunlockput(dp);
    80005a58:	854a                	mv	a0,s2
    80005a5a:	ffffe097          	auipc	ra,0xffffe
    80005a5e:	44c080e7          	jalr	1100(ra) # 80003ea6 <iunlockput>
  ilock(ip);
    80005a62:	8526                	mv	a0,s1
    80005a64:	ffffe097          	auipc	ra,0xffffe
    80005a68:	1dc080e7          	jalr	476(ra) # 80003c40 <ilock>
  ip->nlink--;
    80005a6c:	04a4d783          	lhu	a5,74(s1)
    80005a70:	37fd                	addiw	a5,a5,-1
    80005a72:	04f49523          	sh	a5,74(s1)
  iupdate(ip);
    80005a76:	8526                	mv	a0,s1
    80005a78:	ffffe097          	auipc	ra,0xffffe
    80005a7c:	0fc080e7          	jalr	252(ra) # 80003b74 <iupdate>
  iunlockput(ip);
    80005a80:	8526                	mv	a0,s1
    80005a82:	ffffe097          	auipc	ra,0xffffe
    80005a86:	424080e7          	jalr	1060(ra) # 80003ea6 <iunlockput>
  end_op();
    80005a8a:	fffff097          	auipc	ra,0xfffff
    80005a8e:	bfe080e7          	jalr	-1026(ra) # 80004688 <end_op>
  return -1;
    80005a92:	57fd                	li	a5,-1
    80005a94:	64f2                	ld	s1,280(sp)
    80005a96:	6952                	ld	s2,272(sp)
}
    80005a98:	853e                	mv	a0,a5
    80005a9a:	70b2                	ld	ra,296(sp)
    80005a9c:	7412                	ld	s0,288(sp)
    80005a9e:	6155                	addi	sp,sp,304
    80005aa0:	8082                	ret

0000000080005aa2 <sys_unlink>:
{
    80005aa2:	7151                	addi	sp,sp,-240
    80005aa4:	f586                	sd	ra,232(sp)
    80005aa6:	f1a2                	sd	s0,224(sp)
    80005aa8:	1980                	addi	s0,sp,240
  if(argstr(0, path, MAXPATH) < 0)
    80005aaa:	08000613          	li	a2,128
    80005aae:	f3040593          	addi	a1,s0,-208
    80005ab2:	4501                	li	a0,0
    80005ab4:	ffffd097          	auipc	ra,0xffffd
    80005ab8:	564080e7          	jalr	1380(ra) # 80003018 <argstr>
    80005abc:	1a054a63          	bltz	a0,80005c70 <sys_unlink+0x1ce>
    80005ac0:	eda6                	sd	s1,216(sp)
  begin_op();
    80005ac2:	fffff097          	auipc	ra,0xfffff
    80005ac6:	b4c080e7          	jalr	-1204(ra) # 8000460e <begin_op>
  if((dp = nameiparent(path, name)) == 0){
    80005aca:	fb040593          	addi	a1,s0,-80
    80005ace:	f3040513          	addi	a0,s0,-208
    80005ad2:	fffff097          	auipc	ra,0xfffff
    80005ad6:	95a080e7          	jalr	-1702(ra) # 8000442c <nameiparent>
    80005ada:	84aa                	mv	s1,a0
    80005adc:	cd71                	beqz	a0,80005bb8 <sys_unlink+0x116>
  ilock(dp);
    80005ade:	ffffe097          	auipc	ra,0xffffe
    80005ae2:	162080e7          	jalr	354(ra) # 80003c40 <ilock>
  if(namecmp(name, ".") == 0 || namecmp(name, "..") == 0)
    80005ae6:	00003597          	auipc	a1,0x3
    80005aea:	b2a58593          	addi	a1,a1,-1238 # 80008610 <etext+0x610>
    80005aee:	fb040513          	addi	a0,s0,-80
    80005af2:	ffffe097          	auipc	ra,0xffffe
    80005af6:	640080e7          	jalr	1600(ra) # 80004132 <namecmp>
    80005afa:	14050c63          	beqz	a0,80005c52 <sys_unlink+0x1b0>
    80005afe:	00003597          	auipc	a1,0x3
    80005b02:	b1a58593          	addi	a1,a1,-1254 # 80008618 <etext+0x618>
    80005b06:	fb040513          	addi	a0,s0,-80
    80005b0a:	ffffe097          	auipc	ra,0xffffe
    80005b0e:	628080e7          	jalr	1576(ra) # 80004132 <namecmp>
    80005b12:	14050063          	beqz	a0,80005c52 <sys_unlink+0x1b0>
    80005b16:	e9ca                	sd	s2,208(sp)
  if((ip = dirlookup(dp, name, &off)) == 0)
    80005b18:	f2c40613          	addi	a2,s0,-212
    80005b1c:	fb040593          	addi	a1,s0,-80
    80005b20:	8526                	mv	a0,s1
    80005b22:	ffffe097          	auipc	ra,0xffffe
    80005b26:	62a080e7          	jalr	1578(ra) # 8000414c <dirlookup>
    80005b2a:	892a                	mv	s2,a0
    80005b2c:	12050263          	beqz	a0,80005c50 <sys_unlink+0x1ae>
  ilock(ip);
    80005b30:	ffffe097          	auipc	ra,0xffffe
    80005b34:	110080e7          	jalr	272(ra) # 80003c40 <ilock>
  if(ip->nlink < 1)
    80005b38:	04a91783          	lh	a5,74(s2)
    80005b3c:	08f05563          	blez	a5,80005bc6 <sys_unlink+0x124>
  if(ip->type == T_DIR && !isdirempty(ip)){
    80005b40:	04491703          	lh	a4,68(s2)
    80005b44:	4785                	li	a5,1
    80005b46:	08f70963          	beq	a4,a5,80005bd8 <sys_unlink+0x136>
  memset(&de, 0, sizeof(de));
    80005b4a:	4641                	li	a2,16
    80005b4c:	4581                	li	a1,0
    80005b4e:	fc040513          	addi	a0,s0,-64
    80005b52:	ffffb097          	auipc	ra,0xffffb
    80005b56:	318080e7          	jalr	792(ra) # 80000e6a <memset>
  if(writei(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    80005b5a:	4741                	li	a4,16
    80005b5c:	f2c42683          	lw	a3,-212(s0)
    80005b60:	fc040613          	addi	a2,s0,-64
    80005b64:	4581                	li	a1,0
    80005b66:	8526                	mv	a0,s1
    80005b68:	ffffe097          	auipc	ra,0xffffe
    80005b6c:	4a0080e7          	jalr	1184(ra) # 80004008 <writei>
    80005b70:	47c1                	li	a5,16
    80005b72:	0af51b63          	bne	a0,a5,80005c28 <sys_unlink+0x186>
  if(ip->type == T_DIR){
    80005b76:	04491703          	lh	a4,68(s2)
    80005b7a:	4785                	li	a5,1
    80005b7c:	0af70f63          	beq	a4,a5,80005c3a <sys_unlink+0x198>
  iunlockput(dp);
    80005b80:	8526                	mv	a0,s1
    80005b82:	ffffe097          	auipc	ra,0xffffe
    80005b86:	324080e7          	jalr	804(ra) # 80003ea6 <iunlockput>
  ip->nlink--;
    80005b8a:	04a95783          	lhu	a5,74(s2)
    80005b8e:	37fd                	addiw	a5,a5,-1
    80005b90:	04f91523          	sh	a5,74(s2)
  iupdate(ip);
    80005b94:	854a                	mv	a0,s2
    80005b96:	ffffe097          	auipc	ra,0xffffe
    80005b9a:	fde080e7          	jalr	-34(ra) # 80003b74 <iupdate>
  iunlockput(ip);
    80005b9e:	854a                	mv	a0,s2
    80005ba0:	ffffe097          	auipc	ra,0xffffe
    80005ba4:	306080e7          	jalr	774(ra) # 80003ea6 <iunlockput>
  end_op();
    80005ba8:	fffff097          	auipc	ra,0xfffff
    80005bac:	ae0080e7          	jalr	-1312(ra) # 80004688 <end_op>
  return 0;
    80005bb0:	4501                	li	a0,0
    80005bb2:	64ee                	ld	s1,216(sp)
    80005bb4:	694e                	ld	s2,208(sp)
    80005bb6:	a84d                	j	80005c68 <sys_unlink+0x1c6>
    end_op();
    80005bb8:	fffff097          	auipc	ra,0xfffff
    80005bbc:	ad0080e7          	jalr	-1328(ra) # 80004688 <end_op>
    return -1;
    80005bc0:	557d                	li	a0,-1
    80005bc2:	64ee                	ld	s1,216(sp)
    80005bc4:	a055                	j	80005c68 <sys_unlink+0x1c6>
    80005bc6:	e5ce                	sd	s3,200(sp)
    panic("unlink: nlink < 1");
    80005bc8:	00003517          	auipc	a0,0x3
    80005bcc:	a5850513          	addi	a0,a0,-1448 # 80008620 <etext+0x620>
    80005bd0:	ffffb097          	auipc	ra,0xffffb
    80005bd4:	990080e7          	jalr	-1648(ra) # 80000560 <panic>
  for(off=2*sizeof(de); off<dp->size; off+=sizeof(de)){
    80005bd8:	04c92703          	lw	a4,76(s2)
    80005bdc:	02000793          	li	a5,32
    80005be0:	f6e7f5e3          	bgeu	a5,a4,80005b4a <sys_unlink+0xa8>
    80005be4:	e5ce                	sd	s3,200(sp)
    80005be6:	02000993          	li	s3,32
    if(readi(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    80005bea:	4741                	li	a4,16
    80005bec:	86ce                	mv	a3,s3
    80005bee:	f1840613          	addi	a2,s0,-232
    80005bf2:	4581                	li	a1,0
    80005bf4:	854a                	mv	a0,s2
    80005bf6:	ffffe097          	auipc	ra,0xffffe
    80005bfa:	302080e7          	jalr	770(ra) # 80003ef8 <readi>
    80005bfe:	47c1                	li	a5,16
    80005c00:	00f51c63          	bne	a0,a5,80005c18 <sys_unlink+0x176>
    if(de.inum != 0)
    80005c04:	f1845783          	lhu	a5,-232(s0)
    80005c08:	e7b5                	bnez	a5,80005c74 <sys_unlink+0x1d2>
  for(off=2*sizeof(de); off<dp->size; off+=sizeof(de)){
    80005c0a:	29c1                	addiw	s3,s3,16
    80005c0c:	04c92783          	lw	a5,76(s2)
    80005c10:	fcf9ede3          	bltu	s3,a5,80005bea <sys_unlink+0x148>
    80005c14:	69ae                	ld	s3,200(sp)
    80005c16:	bf15                	j	80005b4a <sys_unlink+0xa8>
      panic("isdirempty: readi");
    80005c18:	00003517          	auipc	a0,0x3
    80005c1c:	a2050513          	addi	a0,a0,-1504 # 80008638 <etext+0x638>
    80005c20:	ffffb097          	auipc	ra,0xffffb
    80005c24:	940080e7          	jalr	-1728(ra) # 80000560 <panic>
    80005c28:	e5ce                	sd	s3,200(sp)
    panic("unlink: writei");
    80005c2a:	00003517          	auipc	a0,0x3
    80005c2e:	a2650513          	addi	a0,a0,-1498 # 80008650 <etext+0x650>
    80005c32:	ffffb097          	auipc	ra,0xffffb
    80005c36:	92e080e7          	jalr	-1746(ra) # 80000560 <panic>
    dp->nlink--;
    80005c3a:	04a4d783          	lhu	a5,74(s1)
    80005c3e:	37fd                	addiw	a5,a5,-1
    80005c40:	04f49523          	sh	a5,74(s1)
    iupdate(dp);
    80005c44:	8526                	mv	a0,s1
    80005c46:	ffffe097          	auipc	ra,0xffffe
    80005c4a:	f2e080e7          	jalr	-210(ra) # 80003b74 <iupdate>
    80005c4e:	bf0d                	j	80005b80 <sys_unlink+0xde>
    80005c50:	694e                	ld	s2,208(sp)
  iunlockput(dp);
    80005c52:	8526                	mv	a0,s1
    80005c54:	ffffe097          	auipc	ra,0xffffe
    80005c58:	252080e7          	jalr	594(ra) # 80003ea6 <iunlockput>
  end_op();
    80005c5c:	fffff097          	auipc	ra,0xfffff
    80005c60:	a2c080e7          	jalr	-1492(ra) # 80004688 <end_op>
  return -1;
    80005c64:	557d                	li	a0,-1
    80005c66:	64ee                	ld	s1,216(sp)
}
    80005c68:	70ae                	ld	ra,232(sp)
    80005c6a:	740e                	ld	s0,224(sp)
    80005c6c:	616d                	addi	sp,sp,240
    80005c6e:	8082                	ret
    return -1;
    80005c70:	557d                	li	a0,-1
    80005c72:	bfdd                	j	80005c68 <sys_unlink+0x1c6>
    iunlockput(ip);
    80005c74:	854a                	mv	a0,s2
    80005c76:	ffffe097          	auipc	ra,0xffffe
    80005c7a:	230080e7          	jalr	560(ra) # 80003ea6 <iunlockput>
    goto bad;
    80005c7e:	694e                	ld	s2,208(sp)
    80005c80:	69ae                	ld	s3,200(sp)
    80005c82:	bfc1                	j	80005c52 <sys_unlink+0x1b0>

0000000080005c84 <sys_open>:

uint64
sys_open(void)
{
    80005c84:	7131                	addi	sp,sp,-192
    80005c86:	fd06                	sd	ra,184(sp)
    80005c88:	f922                	sd	s0,176(sp)
    80005c8a:	0180                	addi	s0,sp,192
  int fd, omode;
  struct file *f;
  struct inode *ip;
  int n;

  argint(1, &omode);
    80005c8c:	f4c40593          	addi	a1,s0,-180
    80005c90:	4505                	li	a0,1
    80005c92:	ffffd097          	auipc	ra,0xffffd
    80005c96:	346080e7          	jalr	838(ra) # 80002fd8 <argint>
  if((n = argstr(0, path, MAXPATH)) < 0)
    80005c9a:	08000613          	li	a2,128
    80005c9e:	f5040593          	addi	a1,s0,-176
    80005ca2:	4501                	li	a0,0
    80005ca4:	ffffd097          	auipc	ra,0xffffd
    80005ca8:	374080e7          	jalr	884(ra) # 80003018 <argstr>
    80005cac:	87aa                	mv	a5,a0
    return -1;
    80005cae:	557d                	li	a0,-1
  if((n = argstr(0, path, MAXPATH)) < 0)
    80005cb0:	0a07ce63          	bltz	a5,80005d6c <sys_open+0xe8>
    80005cb4:	f526                	sd	s1,168(sp)

  begin_op();
    80005cb6:	fffff097          	auipc	ra,0xfffff
    80005cba:	958080e7          	jalr	-1704(ra) # 8000460e <begin_op>

  if(omode & O_CREATE){
    80005cbe:	f4c42783          	lw	a5,-180(s0)
    80005cc2:	2007f793          	andi	a5,a5,512
    80005cc6:	cfd5                	beqz	a5,80005d82 <sys_open+0xfe>
    ip = create(path, T_FILE, 0, 0);
    80005cc8:	4681                	li	a3,0
    80005cca:	4601                	li	a2,0
    80005ccc:	4589                	li	a1,2
    80005cce:	f5040513          	addi	a0,s0,-176
    80005cd2:	00000097          	auipc	ra,0x0
    80005cd6:	95c080e7          	jalr	-1700(ra) # 8000562e <create>
    80005cda:	84aa                	mv	s1,a0
    if(ip == 0){
    80005cdc:	cd41                	beqz	a0,80005d74 <sys_open+0xf0>
      end_op();
      return -1;
    }
  }

  if(ip->type == T_DEVICE && (ip->major < 0 || ip->major >= NDEV)){
    80005cde:	04449703          	lh	a4,68(s1)
    80005ce2:	478d                	li	a5,3
    80005ce4:	00f71763          	bne	a4,a5,80005cf2 <sys_open+0x6e>
    80005ce8:	0464d703          	lhu	a4,70(s1)
    80005cec:	47a5                	li	a5,9
    80005cee:	0ee7e163          	bltu	a5,a4,80005dd0 <sys_open+0x14c>
    80005cf2:	f14a                	sd	s2,160(sp)
    iunlockput(ip);
    end_op();
    return -1;
  }

  if((f = filealloc()) == 0 || (fd = fdalloc(f)) < 0){
    80005cf4:	fffff097          	auipc	ra,0xfffff
    80005cf8:	d28080e7          	jalr	-728(ra) # 80004a1c <filealloc>
    80005cfc:	892a                	mv	s2,a0
    80005cfe:	c97d                	beqz	a0,80005df4 <sys_open+0x170>
    80005d00:	ed4e                	sd	s3,152(sp)
    80005d02:	00000097          	auipc	ra,0x0
    80005d06:	8ea080e7          	jalr	-1814(ra) # 800055ec <fdalloc>
    80005d0a:	89aa                	mv	s3,a0
    80005d0c:	0c054e63          	bltz	a0,80005de8 <sys_open+0x164>
    iunlockput(ip);
    end_op();
    return -1;
  }

  if(ip->type == T_DEVICE){
    80005d10:	04449703          	lh	a4,68(s1)
    80005d14:	478d                	li	a5,3
    80005d16:	0ef70c63          	beq	a4,a5,80005e0e <sys_open+0x18a>
    f->type = FD_DEVICE;
    f->major = ip->major;
  } else {
    f->type = FD_INODE;
    80005d1a:	4789                	li	a5,2
    80005d1c:	00f92023          	sw	a5,0(s2)
    f->off = 0;
    80005d20:	02092023          	sw	zero,32(s2)
  }
  f->ip = ip;
    80005d24:	00993c23          	sd	s1,24(s2)
  f->readable = !(omode & O_WRONLY);
    80005d28:	f4c42783          	lw	a5,-180(s0)
    80005d2c:	0017c713          	xori	a4,a5,1
    80005d30:	8b05                	andi	a4,a4,1
    80005d32:	00e90423          	sb	a4,8(s2)
  f->writable = (omode & O_WRONLY) || (omode & O_RDWR);
    80005d36:	0037f713          	andi	a4,a5,3
    80005d3a:	00e03733          	snez	a4,a4
    80005d3e:	00e904a3          	sb	a4,9(s2)

  if((omode & O_TRUNC) && ip->type == T_FILE){
    80005d42:	4007f793          	andi	a5,a5,1024
    80005d46:	c791                	beqz	a5,80005d52 <sys_open+0xce>
    80005d48:	04449703          	lh	a4,68(s1)
    80005d4c:	4789                	li	a5,2
    80005d4e:	0cf70763          	beq	a4,a5,80005e1c <sys_open+0x198>
    itrunc(ip);
  }

  iunlock(ip);
    80005d52:	8526                	mv	a0,s1
    80005d54:	ffffe097          	auipc	ra,0xffffe
    80005d58:	fb2080e7          	jalr	-78(ra) # 80003d06 <iunlock>
  end_op();
    80005d5c:	fffff097          	auipc	ra,0xfffff
    80005d60:	92c080e7          	jalr	-1748(ra) # 80004688 <end_op>

  return fd;
    80005d64:	854e                	mv	a0,s3
    80005d66:	74aa                	ld	s1,168(sp)
    80005d68:	790a                	ld	s2,160(sp)
    80005d6a:	69ea                	ld	s3,152(sp)
}
    80005d6c:	70ea                	ld	ra,184(sp)
    80005d6e:	744a                	ld	s0,176(sp)
    80005d70:	6129                	addi	sp,sp,192
    80005d72:	8082                	ret
      end_op();
    80005d74:	fffff097          	auipc	ra,0xfffff
    80005d78:	914080e7          	jalr	-1772(ra) # 80004688 <end_op>
      return -1;
    80005d7c:	557d                	li	a0,-1
    80005d7e:	74aa                	ld	s1,168(sp)
    80005d80:	b7f5                	j	80005d6c <sys_open+0xe8>
    if((ip = namei(path)) == 0){
    80005d82:	f5040513          	addi	a0,s0,-176
    80005d86:	ffffe097          	auipc	ra,0xffffe
    80005d8a:	688080e7          	jalr	1672(ra) # 8000440e <namei>
    80005d8e:	84aa                	mv	s1,a0
    80005d90:	c90d                	beqz	a0,80005dc2 <sys_open+0x13e>
    ilock(ip);
    80005d92:	ffffe097          	auipc	ra,0xffffe
    80005d96:	eae080e7          	jalr	-338(ra) # 80003c40 <ilock>
    if(ip->type == T_DIR && omode != O_RDONLY){
    80005d9a:	04449703          	lh	a4,68(s1)
    80005d9e:	4785                	li	a5,1
    80005da0:	f2f71fe3          	bne	a4,a5,80005cde <sys_open+0x5a>
    80005da4:	f4c42783          	lw	a5,-180(s0)
    80005da8:	d7a9                	beqz	a5,80005cf2 <sys_open+0x6e>
      iunlockput(ip);
    80005daa:	8526                	mv	a0,s1
    80005dac:	ffffe097          	auipc	ra,0xffffe
    80005db0:	0fa080e7          	jalr	250(ra) # 80003ea6 <iunlockput>
      end_op();
    80005db4:	fffff097          	auipc	ra,0xfffff
    80005db8:	8d4080e7          	jalr	-1836(ra) # 80004688 <end_op>
      return -1;
    80005dbc:	557d                	li	a0,-1
    80005dbe:	74aa                	ld	s1,168(sp)
    80005dc0:	b775                	j	80005d6c <sys_open+0xe8>
      end_op();
    80005dc2:	fffff097          	auipc	ra,0xfffff
    80005dc6:	8c6080e7          	jalr	-1850(ra) # 80004688 <end_op>
      return -1;
    80005dca:	557d                	li	a0,-1
    80005dcc:	74aa                	ld	s1,168(sp)
    80005dce:	bf79                	j	80005d6c <sys_open+0xe8>
    iunlockput(ip);
    80005dd0:	8526                	mv	a0,s1
    80005dd2:	ffffe097          	auipc	ra,0xffffe
    80005dd6:	0d4080e7          	jalr	212(ra) # 80003ea6 <iunlockput>
    end_op();
    80005dda:	fffff097          	auipc	ra,0xfffff
    80005dde:	8ae080e7          	jalr	-1874(ra) # 80004688 <end_op>
    return -1;
    80005de2:	557d                	li	a0,-1
    80005de4:	74aa                	ld	s1,168(sp)
    80005de6:	b759                	j	80005d6c <sys_open+0xe8>
      fileclose(f);
    80005de8:	854a                	mv	a0,s2
    80005dea:	fffff097          	auipc	ra,0xfffff
    80005dee:	cee080e7          	jalr	-786(ra) # 80004ad8 <fileclose>
    80005df2:	69ea                	ld	s3,152(sp)
    iunlockput(ip);
    80005df4:	8526                	mv	a0,s1
    80005df6:	ffffe097          	auipc	ra,0xffffe
    80005dfa:	0b0080e7          	jalr	176(ra) # 80003ea6 <iunlockput>
    end_op();
    80005dfe:	fffff097          	auipc	ra,0xfffff
    80005e02:	88a080e7          	jalr	-1910(ra) # 80004688 <end_op>
    return -1;
    80005e06:	557d                	li	a0,-1
    80005e08:	74aa                	ld	s1,168(sp)
    80005e0a:	790a                	ld	s2,160(sp)
    80005e0c:	b785                	j	80005d6c <sys_open+0xe8>
    f->type = FD_DEVICE;
    80005e0e:	00f92023          	sw	a5,0(s2)
    f->major = ip->major;
    80005e12:	04649783          	lh	a5,70(s1)
    80005e16:	02f91223          	sh	a5,36(s2)
    80005e1a:	b729                	j	80005d24 <sys_open+0xa0>
    itrunc(ip);
    80005e1c:	8526                	mv	a0,s1
    80005e1e:	ffffe097          	auipc	ra,0xffffe
    80005e22:	f34080e7          	jalr	-204(ra) # 80003d52 <itrunc>
    80005e26:	b735                	j	80005d52 <sys_open+0xce>

0000000080005e28 <sys_mkdir>:

uint64
sys_mkdir(void)
{
    80005e28:	7175                	addi	sp,sp,-144
    80005e2a:	e506                	sd	ra,136(sp)
    80005e2c:	e122                	sd	s0,128(sp)
    80005e2e:	0900                	addi	s0,sp,144
  char path[MAXPATH];
  struct inode *ip;

  begin_op();
    80005e30:	ffffe097          	auipc	ra,0xffffe
    80005e34:	7de080e7          	jalr	2014(ra) # 8000460e <begin_op>
  if(argstr(0, path, MAXPATH) < 0 || (ip = create(path, T_DIR, 0, 0)) == 0){
    80005e38:	08000613          	li	a2,128
    80005e3c:	f7040593          	addi	a1,s0,-144
    80005e40:	4501                	li	a0,0
    80005e42:	ffffd097          	auipc	ra,0xffffd
    80005e46:	1d6080e7          	jalr	470(ra) # 80003018 <argstr>
    80005e4a:	02054963          	bltz	a0,80005e7c <sys_mkdir+0x54>
    80005e4e:	4681                	li	a3,0
    80005e50:	4601                	li	a2,0
    80005e52:	4585                	li	a1,1
    80005e54:	f7040513          	addi	a0,s0,-144
    80005e58:	fffff097          	auipc	ra,0xfffff
    80005e5c:	7d6080e7          	jalr	2006(ra) # 8000562e <create>
    80005e60:	cd11                	beqz	a0,80005e7c <sys_mkdir+0x54>
    end_op();
    return -1;
  }
  iunlockput(ip);
    80005e62:	ffffe097          	auipc	ra,0xffffe
    80005e66:	044080e7          	jalr	68(ra) # 80003ea6 <iunlockput>
  end_op();
    80005e6a:	fffff097          	auipc	ra,0xfffff
    80005e6e:	81e080e7          	jalr	-2018(ra) # 80004688 <end_op>
  return 0;
    80005e72:	4501                	li	a0,0
}
    80005e74:	60aa                	ld	ra,136(sp)
    80005e76:	640a                	ld	s0,128(sp)
    80005e78:	6149                	addi	sp,sp,144
    80005e7a:	8082                	ret
    end_op();
    80005e7c:	fffff097          	auipc	ra,0xfffff
    80005e80:	80c080e7          	jalr	-2036(ra) # 80004688 <end_op>
    return -1;
    80005e84:	557d                	li	a0,-1
    80005e86:	b7fd                	j	80005e74 <sys_mkdir+0x4c>

0000000080005e88 <sys_mknod>:

uint64
sys_mknod(void)
{
    80005e88:	7135                	addi	sp,sp,-160
    80005e8a:	ed06                	sd	ra,152(sp)
    80005e8c:	e922                	sd	s0,144(sp)
    80005e8e:	1100                	addi	s0,sp,160
  struct inode *ip;
  char path[MAXPATH];
  int major, minor;

  begin_op();
    80005e90:	ffffe097          	auipc	ra,0xffffe
    80005e94:	77e080e7          	jalr	1918(ra) # 8000460e <begin_op>
  argint(1, &major);
    80005e98:	f6c40593          	addi	a1,s0,-148
    80005e9c:	4505                	li	a0,1
    80005e9e:	ffffd097          	auipc	ra,0xffffd
    80005ea2:	13a080e7          	jalr	314(ra) # 80002fd8 <argint>
  argint(2, &minor);
    80005ea6:	f6840593          	addi	a1,s0,-152
    80005eaa:	4509                	li	a0,2
    80005eac:	ffffd097          	auipc	ra,0xffffd
    80005eb0:	12c080e7          	jalr	300(ra) # 80002fd8 <argint>
  if((argstr(0, path, MAXPATH)) < 0 ||
    80005eb4:	08000613          	li	a2,128
    80005eb8:	f7040593          	addi	a1,s0,-144
    80005ebc:	4501                	li	a0,0
    80005ebe:	ffffd097          	auipc	ra,0xffffd
    80005ec2:	15a080e7          	jalr	346(ra) # 80003018 <argstr>
    80005ec6:	02054b63          	bltz	a0,80005efc <sys_mknod+0x74>
     (ip = create(path, T_DEVICE, major, minor)) == 0){
    80005eca:	f6841683          	lh	a3,-152(s0)
    80005ece:	f6c41603          	lh	a2,-148(s0)
    80005ed2:	458d                	li	a1,3
    80005ed4:	f7040513          	addi	a0,s0,-144
    80005ed8:	fffff097          	auipc	ra,0xfffff
    80005edc:	756080e7          	jalr	1878(ra) # 8000562e <create>
  if((argstr(0, path, MAXPATH)) < 0 ||
    80005ee0:	cd11                	beqz	a0,80005efc <sys_mknod+0x74>
    end_op();
    return -1;
  }
  iunlockput(ip);
    80005ee2:	ffffe097          	auipc	ra,0xffffe
    80005ee6:	fc4080e7          	jalr	-60(ra) # 80003ea6 <iunlockput>
  end_op();
    80005eea:	ffffe097          	auipc	ra,0xffffe
    80005eee:	79e080e7          	jalr	1950(ra) # 80004688 <end_op>
  return 0;
    80005ef2:	4501                	li	a0,0
}
    80005ef4:	60ea                	ld	ra,152(sp)
    80005ef6:	644a                	ld	s0,144(sp)
    80005ef8:	610d                	addi	sp,sp,160
    80005efa:	8082                	ret
    end_op();
    80005efc:	ffffe097          	auipc	ra,0xffffe
    80005f00:	78c080e7          	jalr	1932(ra) # 80004688 <end_op>
    return -1;
    80005f04:	557d                	li	a0,-1
    80005f06:	b7fd                	j	80005ef4 <sys_mknod+0x6c>

0000000080005f08 <sys_chdir>:

uint64
sys_chdir(void)
{
    80005f08:	7135                	addi	sp,sp,-160
    80005f0a:	ed06                	sd	ra,152(sp)
    80005f0c:	e922                	sd	s0,144(sp)
    80005f0e:	e14a                	sd	s2,128(sp)
    80005f10:	1100                	addi	s0,sp,160
  char path[MAXPATH];
  struct inode *ip;
  struct proc *p = myproc();
    80005f12:	ffffc097          	auipc	ra,0xffffc
    80005f16:	d24080e7          	jalr	-732(ra) # 80001c36 <myproc>
    80005f1a:	892a                	mv	s2,a0
  
  begin_op();
    80005f1c:	ffffe097          	auipc	ra,0xffffe
    80005f20:	6f2080e7          	jalr	1778(ra) # 8000460e <begin_op>
  if(argstr(0, path, MAXPATH) < 0 || (ip = namei(path)) == 0){
    80005f24:	08000613          	li	a2,128
    80005f28:	f6040593          	addi	a1,s0,-160
    80005f2c:	4501                	li	a0,0
    80005f2e:	ffffd097          	auipc	ra,0xffffd
    80005f32:	0ea080e7          	jalr	234(ra) # 80003018 <argstr>
    80005f36:	04054d63          	bltz	a0,80005f90 <sys_chdir+0x88>
    80005f3a:	e526                	sd	s1,136(sp)
    80005f3c:	f6040513          	addi	a0,s0,-160
    80005f40:	ffffe097          	auipc	ra,0xffffe
    80005f44:	4ce080e7          	jalr	1230(ra) # 8000440e <namei>
    80005f48:	84aa                	mv	s1,a0
    80005f4a:	c131                	beqz	a0,80005f8e <sys_chdir+0x86>
    end_op();
    return -1;
  }
  ilock(ip);
    80005f4c:	ffffe097          	auipc	ra,0xffffe
    80005f50:	cf4080e7          	jalr	-780(ra) # 80003c40 <ilock>
  if(ip->type != T_DIR){
    80005f54:	04449703          	lh	a4,68(s1)
    80005f58:	4785                	li	a5,1
    80005f5a:	04f71163          	bne	a4,a5,80005f9c <sys_chdir+0x94>
    iunlockput(ip);
    end_op();
    return -1;
  }
  iunlock(ip);
    80005f5e:	8526                	mv	a0,s1
    80005f60:	ffffe097          	auipc	ra,0xffffe
    80005f64:	da6080e7          	jalr	-602(ra) # 80003d06 <iunlock>
  iput(p->cwd);
    80005f68:	15893503          	ld	a0,344(s2)
    80005f6c:	ffffe097          	auipc	ra,0xffffe
    80005f70:	e92080e7          	jalr	-366(ra) # 80003dfe <iput>
  end_op();
    80005f74:	ffffe097          	auipc	ra,0xffffe
    80005f78:	714080e7          	jalr	1812(ra) # 80004688 <end_op>
  p->cwd = ip;
    80005f7c:	14993c23          	sd	s1,344(s2)
  return 0;
    80005f80:	4501                	li	a0,0
    80005f82:	64aa                	ld	s1,136(sp)
}
    80005f84:	60ea                	ld	ra,152(sp)
    80005f86:	644a                	ld	s0,144(sp)
    80005f88:	690a                	ld	s2,128(sp)
    80005f8a:	610d                	addi	sp,sp,160
    80005f8c:	8082                	ret
    80005f8e:	64aa                	ld	s1,136(sp)
    end_op();
    80005f90:	ffffe097          	auipc	ra,0xffffe
    80005f94:	6f8080e7          	jalr	1784(ra) # 80004688 <end_op>
    return -1;
    80005f98:	557d                	li	a0,-1
    80005f9a:	b7ed                	j	80005f84 <sys_chdir+0x7c>
    iunlockput(ip);
    80005f9c:	8526                	mv	a0,s1
    80005f9e:	ffffe097          	auipc	ra,0xffffe
    80005fa2:	f08080e7          	jalr	-248(ra) # 80003ea6 <iunlockput>
    end_op();
    80005fa6:	ffffe097          	auipc	ra,0xffffe
    80005faa:	6e2080e7          	jalr	1762(ra) # 80004688 <end_op>
    return -1;
    80005fae:	557d                	li	a0,-1
    80005fb0:	64aa                	ld	s1,136(sp)
    80005fb2:	bfc9                	j	80005f84 <sys_chdir+0x7c>

0000000080005fb4 <sys_exec>:

uint64
sys_exec(void)
{
    80005fb4:	7121                	addi	sp,sp,-448
    80005fb6:	ff06                	sd	ra,440(sp)
    80005fb8:	fb22                	sd	s0,432(sp)
    80005fba:	0380                	addi	s0,sp,448
  char path[MAXPATH], *argv[MAXARG];
  int i;
  uint64 uargv, uarg;

  argaddr(1, &uargv);
    80005fbc:	e4840593          	addi	a1,s0,-440
    80005fc0:	4505                	li	a0,1
    80005fc2:	ffffd097          	auipc	ra,0xffffd
    80005fc6:	036080e7          	jalr	54(ra) # 80002ff8 <argaddr>
  if(argstr(0, path, MAXPATH) < 0) {
    80005fca:	08000613          	li	a2,128
    80005fce:	f5040593          	addi	a1,s0,-176
    80005fd2:	4501                	li	a0,0
    80005fd4:	ffffd097          	auipc	ra,0xffffd
    80005fd8:	044080e7          	jalr	68(ra) # 80003018 <argstr>
    80005fdc:	87aa                	mv	a5,a0
    return -1;
    80005fde:	557d                	li	a0,-1
  if(argstr(0, path, MAXPATH) < 0) {
    80005fe0:	0e07c263          	bltz	a5,800060c4 <sys_exec+0x110>
    80005fe4:	f726                	sd	s1,424(sp)
    80005fe6:	f34a                	sd	s2,416(sp)
    80005fe8:	ef4e                	sd	s3,408(sp)
    80005fea:	eb52                	sd	s4,400(sp)
  }
  memset(argv, 0, sizeof(argv));
    80005fec:	10000613          	li	a2,256
    80005ff0:	4581                	li	a1,0
    80005ff2:	e5040513          	addi	a0,s0,-432
    80005ff6:	ffffb097          	auipc	ra,0xffffb
    80005ffa:	e74080e7          	jalr	-396(ra) # 80000e6a <memset>
  for(i=0;; i++){
    if(i >= NELEM(argv)){
    80005ffe:	e5040493          	addi	s1,s0,-432
  memset(argv, 0, sizeof(argv));
    80006002:	89a6                	mv	s3,s1
    80006004:	4901                	li	s2,0
    if(i >= NELEM(argv)){
    80006006:	02000a13          	li	s4,32
      goto bad;
    }
    if(fetchaddr(uargv+sizeof(uint64)*i, (uint64*)&uarg) < 0){
    8000600a:	00391513          	slli	a0,s2,0x3
    8000600e:	e4040593          	addi	a1,s0,-448
    80006012:	e4843783          	ld	a5,-440(s0)
    80006016:	953e                	add	a0,a0,a5
    80006018:	ffffd097          	auipc	ra,0xffffd
    8000601c:	f22080e7          	jalr	-222(ra) # 80002f3a <fetchaddr>
    80006020:	02054a63          	bltz	a0,80006054 <sys_exec+0xa0>
      goto bad;
    }
    if(uarg == 0){
    80006024:	e4043783          	ld	a5,-448(s0)
    80006028:	c7b9                	beqz	a5,80006076 <sys_exec+0xc2>
      argv[i] = 0;
      break;
    }
    argv[i] = kalloc();
    8000602a:	ffffb097          	auipc	ra,0xffffb
    8000602e:	ba4080e7          	jalr	-1116(ra) # 80000bce <kalloc>
    80006032:	85aa                	mv	a1,a0
    80006034:	00a9b023          	sd	a0,0(s3)
    if(argv[i] == 0)
    80006038:	cd11                	beqz	a0,80006054 <sys_exec+0xa0>
      goto bad;
    if(fetchstr(uarg, argv[i], PGSIZE) < 0)
    8000603a:	6605                	lui	a2,0x1
    8000603c:	e4043503          	ld	a0,-448(s0)
    80006040:	ffffd097          	auipc	ra,0xffffd
    80006044:	f4c080e7          	jalr	-180(ra) # 80002f8c <fetchstr>
    80006048:	00054663          	bltz	a0,80006054 <sys_exec+0xa0>
    if(i >= NELEM(argv)){
    8000604c:	0905                	addi	s2,s2,1
    8000604e:	09a1                	addi	s3,s3,8
    80006050:	fb491de3          	bne	s2,s4,8000600a <sys_exec+0x56>
    kfree(argv[i]);

  return ret;

 bad:
  for(i = 0; i < NELEM(argv) && argv[i] != 0; i++)
    80006054:	f5040913          	addi	s2,s0,-176
    80006058:	6088                	ld	a0,0(s1)
    8000605a:	c125                	beqz	a0,800060ba <sys_exec+0x106>
    kfree(argv[i]);
    8000605c:	ffffb097          	auipc	ra,0xffffb
    80006060:	9ee080e7          	jalr	-1554(ra) # 80000a4a <kfree>
  for(i = 0; i < NELEM(argv) && argv[i] != 0; i++)
    80006064:	04a1                	addi	s1,s1,8
    80006066:	ff2499e3          	bne	s1,s2,80006058 <sys_exec+0xa4>
  return -1;
    8000606a:	557d                	li	a0,-1
    8000606c:	74ba                	ld	s1,424(sp)
    8000606e:	791a                	ld	s2,416(sp)
    80006070:	69fa                	ld	s3,408(sp)
    80006072:	6a5a                	ld	s4,400(sp)
    80006074:	a881                	j	800060c4 <sys_exec+0x110>
      argv[i] = 0;
    80006076:	0009079b          	sext.w	a5,s2
    8000607a:	078e                	slli	a5,a5,0x3
    8000607c:	fd078793          	addi	a5,a5,-48
    80006080:	97a2                	add	a5,a5,s0
    80006082:	e807b023          	sd	zero,-384(a5)
  int ret = exec(path, argv);
    80006086:	e5040593          	addi	a1,s0,-432
    8000608a:	f5040513          	addi	a0,s0,-176
    8000608e:	fffff097          	auipc	ra,0xfffff
    80006092:	120080e7          	jalr	288(ra) # 800051ae <exec>
    80006096:	892a                	mv	s2,a0
  for(i = 0; i < NELEM(argv) && argv[i] != 0; i++)
    80006098:	f5040993          	addi	s3,s0,-176
    8000609c:	6088                	ld	a0,0(s1)
    8000609e:	c901                	beqz	a0,800060ae <sys_exec+0xfa>
    kfree(argv[i]);
    800060a0:	ffffb097          	auipc	ra,0xffffb
    800060a4:	9aa080e7          	jalr	-1622(ra) # 80000a4a <kfree>
  for(i = 0; i < NELEM(argv) && argv[i] != 0; i++)
    800060a8:	04a1                	addi	s1,s1,8
    800060aa:	ff3499e3          	bne	s1,s3,8000609c <sys_exec+0xe8>
  return ret;
    800060ae:	854a                	mv	a0,s2
    800060b0:	74ba                	ld	s1,424(sp)
    800060b2:	791a                	ld	s2,416(sp)
    800060b4:	69fa                	ld	s3,408(sp)
    800060b6:	6a5a                	ld	s4,400(sp)
    800060b8:	a031                	j	800060c4 <sys_exec+0x110>
  return -1;
    800060ba:	557d                	li	a0,-1
    800060bc:	74ba                	ld	s1,424(sp)
    800060be:	791a                	ld	s2,416(sp)
    800060c0:	69fa                	ld	s3,408(sp)
    800060c2:	6a5a                	ld	s4,400(sp)
}
    800060c4:	70fa                	ld	ra,440(sp)
    800060c6:	745a                	ld	s0,432(sp)
    800060c8:	6139                	addi	sp,sp,448
    800060ca:	8082                	ret

00000000800060cc <sys_pipe>:

uint64
sys_pipe(void)
{
    800060cc:	7139                	addi	sp,sp,-64
    800060ce:	fc06                	sd	ra,56(sp)
    800060d0:	f822                	sd	s0,48(sp)
    800060d2:	f426                	sd	s1,40(sp)
    800060d4:	0080                	addi	s0,sp,64
  uint64 fdarray; // user pointer to array of two integers
  struct file *rf, *wf;
  int fd0, fd1;
  struct proc *p = myproc();
    800060d6:	ffffc097          	auipc	ra,0xffffc
    800060da:	b60080e7          	jalr	-1184(ra) # 80001c36 <myproc>
    800060de:	84aa                	mv	s1,a0

  argaddr(0, &fdarray);
    800060e0:	fd840593          	addi	a1,s0,-40
    800060e4:	4501                	li	a0,0
    800060e6:	ffffd097          	auipc	ra,0xffffd
    800060ea:	f12080e7          	jalr	-238(ra) # 80002ff8 <argaddr>
  if(pipealloc(&rf, &wf) < 0)
    800060ee:	fc840593          	addi	a1,s0,-56
    800060f2:	fd040513          	addi	a0,s0,-48
    800060f6:	fffff097          	auipc	ra,0xfffff
    800060fa:	d50080e7          	jalr	-688(ra) # 80004e46 <pipealloc>
    return -1;
    800060fe:	57fd                	li	a5,-1
  if(pipealloc(&rf, &wf) < 0)
    80006100:	0c054463          	bltz	a0,800061c8 <sys_pipe+0xfc>
  fd0 = -1;
    80006104:	fcf42223          	sw	a5,-60(s0)
  if((fd0 = fdalloc(rf)) < 0 || (fd1 = fdalloc(wf)) < 0){
    80006108:	fd043503          	ld	a0,-48(s0)
    8000610c:	fffff097          	auipc	ra,0xfffff
    80006110:	4e0080e7          	jalr	1248(ra) # 800055ec <fdalloc>
    80006114:	fca42223          	sw	a0,-60(s0)
    80006118:	08054b63          	bltz	a0,800061ae <sys_pipe+0xe2>
    8000611c:	fc843503          	ld	a0,-56(s0)
    80006120:	fffff097          	auipc	ra,0xfffff
    80006124:	4cc080e7          	jalr	1228(ra) # 800055ec <fdalloc>
    80006128:	fca42023          	sw	a0,-64(s0)
    8000612c:	06054863          	bltz	a0,8000619c <sys_pipe+0xd0>
      p->ofile[fd0] = 0;
    fileclose(rf);
    fileclose(wf);
    return -1;
  }
  if(copyout(p->pagetable, fdarray, (char*)&fd0, sizeof(fd0)) < 0 ||
    80006130:	4691                	li	a3,4
    80006132:	fc440613          	addi	a2,s0,-60
    80006136:	fd843583          	ld	a1,-40(s0)
    8000613a:	6ca8                	ld	a0,88(s1)
    8000613c:	ffffb097          	auipc	ra,0xffffb
    80006140:	74a080e7          	jalr	1866(ra) # 80001886 <copyout>
    80006144:	02054063          	bltz	a0,80006164 <sys_pipe+0x98>
     copyout(p->pagetable, fdarray+sizeof(fd0), (char *)&fd1, sizeof(fd1)) < 0){
    80006148:	4691                	li	a3,4
    8000614a:	fc040613          	addi	a2,s0,-64
    8000614e:	fd843583          	ld	a1,-40(s0)
    80006152:	0591                	addi	a1,a1,4
    80006154:	6ca8                	ld	a0,88(s1)
    80006156:	ffffb097          	auipc	ra,0xffffb
    8000615a:	730080e7          	jalr	1840(ra) # 80001886 <copyout>
    p->ofile[fd1] = 0;
    fileclose(rf);
    fileclose(wf);
    return -1;
  }
  return 0;
    8000615e:	4781                	li	a5,0
  if(copyout(p->pagetable, fdarray, (char*)&fd0, sizeof(fd0)) < 0 ||
    80006160:	06055463          	bgez	a0,800061c8 <sys_pipe+0xfc>
    p->ofile[fd0] = 0;
    80006164:	fc442783          	lw	a5,-60(s0)
    80006168:	07e9                	addi	a5,a5,26
    8000616a:	078e                	slli	a5,a5,0x3
    8000616c:	97a6                	add	a5,a5,s1
    8000616e:	0007b423          	sd	zero,8(a5)
    p->ofile[fd1] = 0;
    80006172:	fc042783          	lw	a5,-64(s0)
    80006176:	07e9                	addi	a5,a5,26
    80006178:	078e                	slli	a5,a5,0x3
    8000617a:	94be                	add	s1,s1,a5
    8000617c:	0004b423          	sd	zero,8(s1)
    fileclose(rf);
    80006180:	fd043503          	ld	a0,-48(s0)
    80006184:	fffff097          	auipc	ra,0xfffff
    80006188:	954080e7          	jalr	-1708(ra) # 80004ad8 <fileclose>
    fileclose(wf);
    8000618c:	fc843503          	ld	a0,-56(s0)
    80006190:	fffff097          	auipc	ra,0xfffff
    80006194:	948080e7          	jalr	-1720(ra) # 80004ad8 <fileclose>
    return -1;
    80006198:	57fd                	li	a5,-1
    8000619a:	a03d                	j	800061c8 <sys_pipe+0xfc>
    if(fd0 >= 0)
    8000619c:	fc442783          	lw	a5,-60(s0)
    800061a0:	0007c763          	bltz	a5,800061ae <sys_pipe+0xe2>
      p->ofile[fd0] = 0;
    800061a4:	07e9                	addi	a5,a5,26
    800061a6:	078e                	slli	a5,a5,0x3
    800061a8:	97a6                	add	a5,a5,s1
    800061aa:	0007b423          	sd	zero,8(a5)
    fileclose(rf);
    800061ae:	fd043503          	ld	a0,-48(s0)
    800061b2:	fffff097          	auipc	ra,0xfffff
    800061b6:	926080e7          	jalr	-1754(ra) # 80004ad8 <fileclose>
    fileclose(wf);
    800061ba:	fc843503          	ld	a0,-56(s0)
    800061be:	fffff097          	auipc	ra,0xfffff
    800061c2:	91a080e7          	jalr	-1766(ra) # 80004ad8 <fileclose>
    return -1;
    800061c6:	57fd                	li	a5,-1
}
    800061c8:	853e                	mv	a0,a5
    800061ca:	70e2                	ld	ra,56(sp)
    800061cc:	7442                	ld	s0,48(sp)
    800061ce:	74a2                	ld	s1,40(sp)
    800061d0:	6121                	addi	sp,sp,64
    800061d2:	8082                	ret
	...

00000000800061e0 <kernelvec>:
    800061e0:	7111                	addi	sp,sp,-256
    800061e2:	e006                	sd	ra,0(sp)
    800061e4:	e40a                	sd	sp,8(sp)
    800061e6:	e80e                	sd	gp,16(sp)
    800061e8:	ec12                	sd	tp,24(sp)
    800061ea:	f016                	sd	t0,32(sp)
    800061ec:	f41a                	sd	t1,40(sp)
    800061ee:	f81e                	sd	t2,48(sp)
    800061f0:	fc22                	sd	s0,56(sp)
    800061f2:	e0a6                	sd	s1,64(sp)
    800061f4:	e4aa                	sd	a0,72(sp)
    800061f6:	e8ae                	sd	a1,80(sp)
    800061f8:	ecb2                	sd	a2,88(sp)
    800061fa:	f0b6                	sd	a3,96(sp)
    800061fc:	f4ba                	sd	a4,104(sp)
    800061fe:	f8be                	sd	a5,112(sp)
    80006200:	fcc2                	sd	a6,120(sp)
    80006202:	e146                	sd	a7,128(sp)
    80006204:	e54a                	sd	s2,136(sp)
    80006206:	e94e                	sd	s3,144(sp)
    80006208:	ed52                	sd	s4,152(sp)
    8000620a:	f156                	sd	s5,160(sp)
    8000620c:	f55a                	sd	s6,168(sp)
    8000620e:	f95e                	sd	s7,176(sp)
    80006210:	fd62                	sd	s8,184(sp)
    80006212:	e1e6                	sd	s9,192(sp)
    80006214:	e5ea                	sd	s10,200(sp)
    80006216:	e9ee                	sd	s11,208(sp)
    80006218:	edf2                	sd	t3,216(sp)
    8000621a:	f1f6                	sd	t4,224(sp)
    8000621c:	f5fa                	sd	t5,232(sp)
    8000621e:	f9fe                	sd	t6,240(sp)
    80006220:	be7fc0ef          	jal	80002e06 <kerneltrap>
    80006224:	6082                	ld	ra,0(sp)
    80006226:	6122                	ld	sp,8(sp)
    80006228:	61c2                	ld	gp,16(sp)
    8000622a:	7282                	ld	t0,32(sp)
    8000622c:	7322                	ld	t1,40(sp)
    8000622e:	73c2                	ld	t2,48(sp)
    80006230:	7462                	ld	s0,56(sp)
    80006232:	6486                	ld	s1,64(sp)
    80006234:	6526                	ld	a0,72(sp)
    80006236:	65c6                	ld	a1,80(sp)
    80006238:	6666                	ld	a2,88(sp)
    8000623a:	7686                	ld	a3,96(sp)
    8000623c:	7726                	ld	a4,104(sp)
    8000623e:	77c6                	ld	a5,112(sp)
    80006240:	7866                	ld	a6,120(sp)
    80006242:	688a                	ld	a7,128(sp)
    80006244:	692a                	ld	s2,136(sp)
    80006246:	69ca                	ld	s3,144(sp)
    80006248:	6a6a                	ld	s4,152(sp)
    8000624a:	7a8a                	ld	s5,160(sp)
    8000624c:	7b2a                	ld	s6,168(sp)
    8000624e:	7bca                	ld	s7,176(sp)
    80006250:	7c6a                	ld	s8,184(sp)
    80006252:	6c8e                	ld	s9,192(sp)
    80006254:	6d2e                	ld	s10,200(sp)
    80006256:	6dce                	ld	s11,208(sp)
    80006258:	6e6e                	ld	t3,216(sp)
    8000625a:	7e8e                	ld	t4,224(sp)
    8000625c:	7f2e                	ld	t5,232(sp)
    8000625e:	7fce                	ld	t6,240(sp)
    80006260:	6111                	addi	sp,sp,256
    80006262:	10200073          	sret
    80006266:	00000013          	nop
    8000626a:	00000013          	nop
    8000626e:	0001                	nop

0000000080006270 <timervec>:
    80006270:	34051573          	csrrw	a0,mscratch,a0
    80006274:	e10c                	sd	a1,0(a0)
    80006276:	e510                	sd	a2,8(a0)
    80006278:	e914                	sd	a3,16(a0)
    8000627a:	6d0c                	ld	a1,24(a0)
    8000627c:	7110                	ld	a2,32(a0)
    8000627e:	6194                	ld	a3,0(a1)
    80006280:	96b2                	add	a3,a3,a2
    80006282:	e194                	sd	a3,0(a1)
    80006284:	4589                	li	a1,2
    80006286:	14459073          	csrw	sip,a1
    8000628a:	6914                	ld	a3,16(a0)
    8000628c:	6510                	ld	a2,8(a0)
    8000628e:	610c                	ld	a1,0(a0)
    80006290:	34051573          	csrrw	a0,mscratch,a0
    80006294:	30200073          	mret
	...

000000008000629a <plicinit>:
// the riscv Platform Level Interrupt Controller (PLIC).
//

void
plicinit(void)
{
    8000629a:	1141                	addi	sp,sp,-16
    8000629c:	e422                	sd	s0,8(sp)
    8000629e:	0800                	addi	s0,sp,16
  // set desired IRQ priorities non-zero (otherwise disabled).
  *(uint32*)(PLIC + UART0_IRQ*4) = 1;
    800062a0:	0c0007b7          	lui	a5,0xc000
    800062a4:	4705                	li	a4,1
    800062a6:	d798                	sw	a4,40(a5)
  *(uint32*)(PLIC + VIRTIO0_IRQ*4) = 1;
    800062a8:	0c0007b7          	lui	a5,0xc000
    800062ac:	c3d8                	sw	a4,4(a5)
}
    800062ae:	6422                	ld	s0,8(sp)
    800062b0:	0141                	addi	sp,sp,16
    800062b2:	8082                	ret

00000000800062b4 <plicinithart>:

void
plicinithart(void)
{
    800062b4:	1141                	addi	sp,sp,-16
    800062b6:	e406                	sd	ra,8(sp)
    800062b8:	e022                	sd	s0,0(sp)
    800062ba:	0800                	addi	s0,sp,16
  int hart = cpuid();
    800062bc:	ffffc097          	auipc	ra,0xffffc
    800062c0:	94e080e7          	jalr	-1714(ra) # 80001c0a <cpuid>
  
  // set enable bits for this hart's S-mode
  // for the uart and virtio disk.
  *(uint32*)PLIC_SENABLE(hart) = (1 << UART0_IRQ) | (1 << VIRTIO0_IRQ);
    800062c4:	0085171b          	slliw	a4,a0,0x8
    800062c8:	0c0027b7          	lui	a5,0xc002
    800062cc:	97ba                	add	a5,a5,a4
    800062ce:	40200713          	li	a4,1026
    800062d2:	08e7a023          	sw	a4,128(a5) # c002080 <_entry-0x73ffdf80>

  // set this hart's S-mode priority threshold to 0.
  *(uint32*)PLIC_SPRIORITY(hart) = 0;
    800062d6:	00d5151b          	slliw	a0,a0,0xd
    800062da:	0c2017b7          	lui	a5,0xc201
    800062de:	97aa                	add	a5,a5,a0
    800062e0:	0007a023          	sw	zero,0(a5) # c201000 <_entry-0x73dff000>
}
    800062e4:	60a2                	ld	ra,8(sp)
    800062e6:	6402                	ld	s0,0(sp)
    800062e8:	0141                	addi	sp,sp,16
    800062ea:	8082                	ret

00000000800062ec <plic_claim>:

// ask the PLIC what interrupt we should serve.
int
plic_claim(void)
{
    800062ec:	1141                	addi	sp,sp,-16
    800062ee:	e406                	sd	ra,8(sp)
    800062f0:	e022                	sd	s0,0(sp)
    800062f2:	0800                	addi	s0,sp,16
  int hart = cpuid();
    800062f4:	ffffc097          	auipc	ra,0xffffc
    800062f8:	916080e7          	jalr	-1770(ra) # 80001c0a <cpuid>
  int irq = *(uint32*)PLIC_SCLAIM(hart);
    800062fc:	00d5151b          	slliw	a0,a0,0xd
    80006300:	0c2017b7          	lui	a5,0xc201
    80006304:	97aa                	add	a5,a5,a0
  return irq;
}
    80006306:	43c8                	lw	a0,4(a5)
    80006308:	60a2                	ld	ra,8(sp)
    8000630a:	6402                	ld	s0,0(sp)
    8000630c:	0141                	addi	sp,sp,16
    8000630e:	8082                	ret

0000000080006310 <plic_complete>:

// tell the PLIC we've served this IRQ.
void
plic_complete(int irq)
{
    80006310:	1101                	addi	sp,sp,-32
    80006312:	ec06                	sd	ra,24(sp)
    80006314:	e822                	sd	s0,16(sp)
    80006316:	e426                	sd	s1,8(sp)
    80006318:	1000                	addi	s0,sp,32
    8000631a:	84aa                	mv	s1,a0
  int hart = cpuid();
    8000631c:	ffffc097          	auipc	ra,0xffffc
    80006320:	8ee080e7          	jalr	-1810(ra) # 80001c0a <cpuid>
  *(uint32*)PLIC_SCLAIM(hart) = irq;
    80006324:	00d5151b          	slliw	a0,a0,0xd
    80006328:	0c2017b7          	lui	a5,0xc201
    8000632c:	97aa                	add	a5,a5,a0
    8000632e:	c3c4                	sw	s1,4(a5)
}
    80006330:	60e2                	ld	ra,24(sp)
    80006332:	6442                	ld	s0,16(sp)
    80006334:	64a2                	ld	s1,8(sp)
    80006336:	6105                	addi	sp,sp,32
    80006338:	8082                	ret

000000008000633a <free_desc>:
}

// mark a descriptor as free.
static void
free_desc(int i)
{
    8000633a:	1141                	addi	sp,sp,-16
    8000633c:	e406                	sd	ra,8(sp)
    8000633e:	e022                	sd	s0,0(sp)
    80006340:	0800                	addi	s0,sp,16
  if(i >= NUM)
    80006342:	479d                	li	a5,7
    80006344:	04a7cc63          	blt	a5,a0,8000639c <free_desc+0x62>
    panic("free_desc 1");
  if(disk.free[i])
    80006348:	0023c797          	auipc	a5,0x23c
    8000634c:	f0878793          	addi	a5,a5,-248 # 80242250 <disk>
    80006350:	97aa                	add	a5,a5,a0
    80006352:	0187c783          	lbu	a5,24(a5)
    80006356:	ebb9                	bnez	a5,800063ac <free_desc+0x72>
    panic("free_desc 2");
  disk.desc[i].addr = 0;
    80006358:	00451693          	slli	a3,a0,0x4
    8000635c:	0023c797          	auipc	a5,0x23c
    80006360:	ef478793          	addi	a5,a5,-268 # 80242250 <disk>
    80006364:	6398                	ld	a4,0(a5)
    80006366:	9736                	add	a4,a4,a3
    80006368:	00073023          	sd	zero,0(a4)
  disk.desc[i].len = 0;
    8000636c:	6398                	ld	a4,0(a5)
    8000636e:	9736                	add	a4,a4,a3
    80006370:	00072423          	sw	zero,8(a4)
  disk.desc[i].flags = 0;
    80006374:	00071623          	sh	zero,12(a4)
  disk.desc[i].next = 0;
    80006378:	00071723          	sh	zero,14(a4)
  disk.free[i] = 1;
    8000637c:	97aa                	add	a5,a5,a0
    8000637e:	4705                	li	a4,1
    80006380:	00e78c23          	sb	a4,24(a5)
  wakeup(&disk.free[0]);
    80006384:	0023c517          	auipc	a0,0x23c
    80006388:	ee450513          	addi	a0,a0,-284 # 80242268 <disk+0x18>
    8000638c:	ffffc097          	auipc	ra,0xffffc
    80006390:	ffe080e7          	jalr	-2(ra) # 8000238a <wakeup>
}
    80006394:	60a2                	ld	ra,8(sp)
    80006396:	6402                	ld	s0,0(sp)
    80006398:	0141                	addi	sp,sp,16
    8000639a:	8082                	ret
    panic("free_desc 1");
    8000639c:	00002517          	auipc	a0,0x2
    800063a0:	2c450513          	addi	a0,a0,708 # 80008660 <etext+0x660>
    800063a4:	ffffa097          	auipc	ra,0xffffa
    800063a8:	1bc080e7          	jalr	444(ra) # 80000560 <panic>
    panic("free_desc 2");
    800063ac:	00002517          	auipc	a0,0x2
    800063b0:	2c450513          	addi	a0,a0,708 # 80008670 <etext+0x670>
    800063b4:	ffffa097          	auipc	ra,0xffffa
    800063b8:	1ac080e7          	jalr	428(ra) # 80000560 <panic>

00000000800063bc <virtio_disk_init>:
{
    800063bc:	1101                	addi	sp,sp,-32
    800063be:	ec06                	sd	ra,24(sp)
    800063c0:	e822                	sd	s0,16(sp)
    800063c2:	e426                	sd	s1,8(sp)
    800063c4:	e04a                	sd	s2,0(sp)
    800063c6:	1000                	addi	s0,sp,32
  initlock(&disk.vdisk_lock, "virtio_disk");
    800063c8:	00002597          	auipc	a1,0x2
    800063cc:	2b858593          	addi	a1,a1,696 # 80008680 <etext+0x680>
    800063d0:	0023c517          	auipc	a0,0x23c
    800063d4:	fa850513          	addi	a0,a0,-88 # 80242378 <disk+0x128>
    800063d8:	ffffb097          	auipc	ra,0xffffb
    800063dc:	906080e7          	jalr	-1786(ra) # 80000cde <initlock>
  if(*R(VIRTIO_MMIO_MAGIC_VALUE) != 0x74726976 ||
    800063e0:	100017b7          	lui	a5,0x10001
    800063e4:	4398                	lw	a4,0(a5)
    800063e6:	2701                	sext.w	a4,a4
    800063e8:	747277b7          	lui	a5,0x74727
    800063ec:	97678793          	addi	a5,a5,-1674 # 74726976 <_entry-0xb8d968a>
    800063f0:	18f71c63          	bne	a4,a5,80006588 <virtio_disk_init+0x1cc>
     *R(VIRTIO_MMIO_VERSION) != 2 ||
    800063f4:	100017b7          	lui	a5,0x10001
    800063f8:	0791                	addi	a5,a5,4 # 10001004 <_entry-0x6fffeffc>
    800063fa:	439c                	lw	a5,0(a5)
    800063fc:	2781                	sext.w	a5,a5
  if(*R(VIRTIO_MMIO_MAGIC_VALUE) != 0x74726976 ||
    800063fe:	4709                	li	a4,2
    80006400:	18e79463          	bne	a5,a4,80006588 <virtio_disk_init+0x1cc>
     *R(VIRTIO_MMIO_DEVICE_ID) != 2 ||
    80006404:	100017b7          	lui	a5,0x10001
    80006408:	07a1                	addi	a5,a5,8 # 10001008 <_entry-0x6fffeff8>
    8000640a:	439c                	lw	a5,0(a5)
    8000640c:	2781                	sext.w	a5,a5
     *R(VIRTIO_MMIO_VERSION) != 2 ||
    8000640e:	16e79d63          	bne	a5,a4,80006588 <virtio_disk_init+0x1cc>
     *R(VIRTIO_MMIO_VENDOR_ID) != 0x554d4551){
    80006412:	100017b7          	lui	a5,0x10001
    80006416:	47d8                	lw	a4,12(a5)
    80006418:	2701                	sext.w	a4,a4
     *R(VIRTIO_MMIO_DEVICE_ID) != 2 ||
    8000641a:	554d47b7          	lui	a5,0x554d4
    8000641e:	55178793          	addi	a5,a5,1361 # 554d4551 <_entry-0x2ab2baaf>
    80006422:	16f71363          	bne	a4,a5,80006588 <virtio_disk_init+0x1cc>
  *R(VIRTIO_MMIO_STATUS) = status;
    80006426:	100017b7          	lui	a5,0x10001
    8000642a:	0607a823          	sw	zero,112(a5) # 10001070 <_entry-0x6fffef90>
  *R(VIRTIO_MMIO_STATUS) = status;
    8000642e:	4705                	li	a4,1
    80006430:	dbb8                	sw	a4,112(a5)
  *R(VIRTIO_MMIO_STATUS) = status;
    80006432:	470d                	li	a4,3
    80006434:	dbb8                	sw	a4,112(a5)
  uint64 features = *R(VIRTIO_MMIO_DEVICE_FEATURES);
    80006436:	10001737          	lui	a4,0x10001
    8000643a:	4b14                	lw	a3,16(a4)
  features &= ~(1 << VIRTIO_RING_F_INDIRECT_DESC);
    8000643c:	c7ffe737          	lui	a4,0xc7ffe
    80006440:	75f70713          	addi	a4,a4,1887 # ffffffffc7ffe75f <end+0xffffffff47dbc3cf>
  *R(VIRTIO_MMIO_DRIVER_FEATURES) = features;
    80006444:	8ef9                	and	a3,a3,a4
    80006446:	10001737          	lui	a4,0x10001
    8000644a:	d314                	sw	a3,32(a4)
  *R(VIRTIO_MMIO_STATUS) = status;
    8000644c:	472d                	li	a4,11
    8000644e:	dbb8                	sw	a4,112(a5)
  *R(VIRTIO_MMIO_STATUS) = status;
    80006450:	07078793          	addi	a5,a5,112
  status = *R(VIRTIO_MMIO_STATUS);
    80006454:	439c                	lw	a5,0(a5)
    80006456:	0007891b          	sext.w	s2,a5
  if(!(status & VIRTIO_CONFIG_S_FEATURES_OK))
    8000645a:	8ba1                	andi	a5,a5,8
    8000645c:	12078e63          	beqz	a5,80006598 <virtio_disk_init+0x1dc>
  *R(VIRTIO_MMIO_QUEUE_SEL) = 0;
    80006460:	100017b7          	lui	a5,0x10001
    80006464:	0207a823          	sw	zero,48(a5) # 10001030 <_entry-0x6fffefd0>
  if(*R(VIRTIO_MMIO_QUEUE_READY))
    80006468:	100017b7          	lui	a5,0x10001
    8000646c:	04478793          	addi	a5,a5,68 # 10001044 <_entry-0x6fffefbc>
    80006470:	439c                	lw	a5,0(a5)
    80006472:	2781                	sext.w	a5,a5
    80006474:	12079a63          	bnez	a5,800065a8 <virtio_disk_init+0x1ec>
  uint32 max = *R(VIRTIO_MMIO_QUEUE_NUM_MAX);
    80006478:	100017b7          	lui	a5,0x10001
    8000647c:	03478793          	addi	a5,a5,52 # 10001034 <_entry-0x6fffefcc>
    80006480:	439c                	lw	a5,0(a5)
    80006482:	2781                	sext.w	a5,a5
  if(max == 0)
    80006484:	12078a63          	beqz	a5,800065b8 <virtio_disk_init+0x1fc>
  if(max < NUM)
    80006488:	471d                	li	a4,7
    8000648a:	12f77f63          	bgeu	a4,a5,800065c8 <virtio_disk_init+0x20c>
  disk.desc = kalloc();
    8000648e:	ffffa097          	auipc	ra,0xffffa
    80006492:	740080e7          	jalr	1856(ra) # 80000bce <kalloc>
    80006496:	0023c497          	auipc	s1,0x23c
    8000649a:	dba48493          	addi	s1,s1,-582 # 80242250 <disk>
    8000649e:	e088                	sd	a0,0(s1)
  disk.avail = kalloc();
    800064a0:	ffffa097          	auipc	ra,0xffffa
    800064a4:	72e080e7          	jalr	1838(ra) # 80000bce <kalloc>
    800064a8:	e488                	sd	a0,8(s1)
  disk.used = kalloc();
    800064aa:	ffffa097          	auipc	ra,0xffffa
    800064ae:	724080e7          	jalr	1828(ra) # 80000bce <kalloc>
    800064b2:	87aa                	mv	a5,a0
    800064b4:	e888                	sd	a0,16(s1)
  if(!disk.desc || !disk.avail || !disk.used)
    800064b6:	6088                	ld	a0,0(s1)
    800064b8:	12050063          	beqz	a0,800065d8 <virtio_disk_init+0x21c>
    800064bc:	0023c717          	auipc	a4,0x23c
    800064c0:	d9c73703          	ld	a4,-612(a4) # 80242258 <disk+0x8>
    800064c4:	10070a63          	beqz	a4,800065d8 <virtio_disk_init+0x21c>
    800064c8:	10078863          	beqz	a5,800065d8 <virtio_disk_init+0x21c>
  memset(disk.desc, 0, PGSIZE);
    800064cc:	6605                	lui	a2,0x1
    800064ce:	4581                	li	a1,0
    800064d0:	ffffb097          	auipc	ra,0xffffb
    800064d4:	99a080e7          	jalr	-1638(ra) # 80000e6a <memset>
  memset(disk.avail, 0, PGSIZE);
    800064d8:	0023c497          	auipc	s1,0x23c
    800064dc:	d7848493          	addi	s1,s1,-648 # 80242250 <disk>
    800064e0:	6605                	lui	a2,0x1
    800064e2:	4581                	li	a1,0
    800064e4:	6488                	ld	a0,8(s1)
    800064e6:	ffffb097          	auipc	ra,0xffffb
    800064ea:	984080e7          	jalr	-1660(ra) # 80000e6a <memset>
  memset(disk.used, 0, PGSIZE);
    800064ee:	6605                	lui	a2,0x1
    800064f0:	4581                	li	a1,0
    800064f2:	6888                	ld	a0,16(s1)
    800064f4:	ffffb097          	auipc	ra,0xffffb
    800064f8:	976080e7          	jalr	-1674(ra) # 80000e6a <memset>
  *R(VIRTIO_MMIO_QUEUE_NUM) = NUM;
    800064fc:	100017b7          	lui	a5,0x10001
    80006500:	4721                	li	a4,8
    80006502:	df98                	sw	a4,56(a5)
  *R(VIRTIO_MMIO_QUEUE_DESC_LOW) = (uint64)disk.desc;
    80006504:	4098                	lw	a4,0(s1)
    80006506:	100017b7          	lui	a5,0x10001
    8000650a:	08e7a023          	sw	a4,128(a5) # 10001080 <_entry-0x6fffef80>
  *R(VIRTIO_MMIO_QUEUE_DESC_HIGH) = (uint64)disk.desc >> 32;
    8000650e:	40d8                	lw	a4,4(s1)
    80006510:	100017b7          	lui	a5,0x10001
    80006514:	08e7a223          	sw	a4,132(a5) # 10001084 <_entry-0x6fffef7c>
  *R(VIRTIO_MMIO_DRIVER_DESC_LOW) = (uint64)disk.avail;
    80006518:	649c                	ld	a5,8(s1)
    8000651a:	0007869b          	sext.w	a3,a5
    8000651e:	10001737          	lui	a4,0x10001
    80006522:	08d72823          	sw	a3,144(a4) # 10001090 <_entry-0x6fffef70>
  *R(VIRTIO_MMIO_DRIVER_DESC_HIGH) = (uint64)disk.avail >> 32;
    80006526:	9781                	srai	a5,a5,0x20
    80006528:	10001737          	lui	a4,0x10001
    8000652c:	08f72a23          	sw	a5,148(a4) # 10001094 <_entry-0x6fffef6c>
  *R(VIRTIO_MMIO_DEVICE_DESC_LOW) = (uint64)disk.used;
    80006530:	689c                	ld	a5,16(s1)
    80006532:	0007869b          	sext.w	a3,a5
    80006536:	10001737          	lui	a4,0x10001
    8000653a:	0ad72023          	sw	a3,160(a4) # 100010a0 <_entry-0x6fffef60>
  *R(VIRTIO_MMIO_DEVICE_DESC_HIGH) = (uint64)disk.used >> 32;
    8000653e:	9781                	srai	a5,a5,0x20
    80006540:	10001737          	lui	a4,0x10001
    80006544:	0af72223          	sw	a5,164(a4) # 100010a4 <_entry-0x6fffef5c>
  *R(VIRTIO_MMIO_QUEUE_READY) = 0x1;
    80006548:	10001737          	lui	a4,0x10001
    8000654c:	4785                	li	a5,1
    8000654e:	c37c                	sw	a5,68(a4)
    disk.free[i] = 1;
    80006550:	00f48c23          	sb	a5,24(s1)
    80006554:	00f48ca3          	sb	a5,25(s1)
    80006558:	00f48d23          	sb	a5,26(s1)
    8000655c:	00f48da3          	sb	a5,27(s1)
    80006560:	00f48e23          	sb	a5,28(s1)
    80006564:	00f48ea3          	sb	a5,29(s1)
    80006568:	00f48f23          	sb	a5,30(s1)
    8000656c:	00f48fa3          	sb	a5,31(s1)
  status |= VIRTIO_CONFIG_S_DRIVER_OK;
    80006570:	00496913          	ori	s2,s2,4
  *R(VIRTIO_MMIO_STATUS) = status;
    80006574:	100017b7          	lui	a5,0x10001
    80006578:	0727a823          	sw	s2,112(a5) # 10001070 <_entry-0x6fffef90>
}
    8000657c:	60e2                	ld	ra,24(sp)
    8000657e:	6442                	ld	s0,16(sp)
    80006580:	64a2                	ld	s1,8(sp)
    80006582:	6902                	ld	s2,0(sp)
    80006584:	6105                	addi	sp,sp,32
    80006586:	8082                	ret
    panic("could not find virtio disk");
    80006588:	00002517          	auipc	a0,0x2
    8000658c:	10850513          	addi	a0,a0,264 # 80008690 <etext+0x690>
    80006590:	ffffa097          	auipc	ra,0xffffa
    80006594:	fd0080e7          	jalr	-48(ra) # 80000560 <panic>
    panic("virtio disk FEATURES_OK unset");
    80006598:	00002517          	auipc	a0,0x2
    8000659c:	11850513          	addi	a0,a0,280 # 800086b0 <etext+0x6b0>
    800065a0:	ffffa097          	auipc	ra,0xffffa
    800065a4:	fc0080e7          	jalr	-64(ra) # 80000560 <panic>
    panic("virtio disk should not be ready");
    800065a8:	00002517          	auipc	a0,0x2
    800065ac:	12850513          	addi	a0,a0,296 # 800086d0 <etext+0x6d0>
    800065b0:	ffffa097          	auipc	ra,0xffffa
    800065b4:	fb0080e7          	jalr	-80(ra) # 80000560 <panic>
    panic("virtio disk has no queue 0");
    800065b8:	00002517          	auipc	a0,0x2
    800065bc:	13850513          	addi	a0,a0,312 # 800086f0 <etext+0x6f0>
    800065c0:	ffffa097          	auipc	ra,0xffffa
    800065c4:	fa0080e7          	jalr	-96(ra) # 80000560 <panic>
    panic("virtio disk max queue too short");
    800065c8:	00002517          	auipc	a0,0x2
    800065cc:	14850513          	addi	a0,a0,328 # 80008710 <etext+0x710>
    800065d0:	ffffa097          	auipc	ra,0xffffa
    800065d4:	f90080e7          	jalr	-112(ra) # 80000560 <panic>
    panic("virtio disk kalloc");
    800065d8:	00002517          	auipc	a0,0x2
    800065dc:	15850513          	addi	a0,a0,344 # 80008730 <etext+0x730>
    800065e0:	ffffa097          	auipc	ra,0xffffa
    800065e4:	f80080e7          	jalr	-128(ra) # 80000560 <panic>

00000000800065e8 <virtio_disk_rw>:
  return 0;
}

void
virtio_disk_rw(struct buf *b, int write)
{
    800065e8:	7159                	addi	sp,sp,-112
    800065ea:	f486                	sd	ra,104(sp)
    800065ec:	f0a2                	sd	s0,96(sp)
    800065ee:	eca6                	sd	s1,88(sp)
    800065f0:	e8ca                	sd	s2,80(sp)
    800065f2:	e4ce                	sd	s3,72(sp)
    800065f4:	e0d2                	sd	s4,64(sp)
    800065f6:	fc56                	sd	s5,56(sp)
    800065f8:	f85a                	sd	s6,48(sp)
    800065fa:	f45e                	sd	s7,40(sp)
    800065fc:	f062                	sd	s8,32(sp)
    800065fe:	ec66                	sd	s9,24(sp)
    80006600:	1880                	addi	s0,sp,112
    80006602:	8a2a                	mv	s4,a0
    80006604:	8bae                	mv	s7,a1
  uint64 sector = b->blockno * (BSIZE / 512);
    80006606:	00c52c83          	lw	s9,12(a0)
    8000660a:	001c9c9b          	slliw	s9,s9,0x1
    8000660e:	1c82                	slli	s9,s9,0x20
    80006610:	020cdc93          	srli	s9,s9,0x20

  acquire(&disk.vdisk_lock);
    80006614:	0023c517          	auipc	a0,0x23c
    80006618:	d6450513          	addi	a0,a0,-668 # 80242378 <disk+0x128>
    8000661c:	ffffa097          	auipc	ra,0xffffa
    80006620:	752080e7          	jalr	1874(ra) # 80000d6e <acquire>
  for(int i = 0; i < 3; i++){
    80006624:	4981                	li	s3,0
  for(int i = 0; i < NUM; i++){
    80006626:	44a1                	li	s1,8
      disk.free[i] = 0;
    80006628:	0023cb17          	auipc	s6,0x23c
    8000662c:	c28b0b13          	addi	s6,s6,-984 # 80242250 <disk>
  for(int i = 0; i < 3; i++){
    80006630:	4a8d                	li	s5,3
  int idx[3];
  while(1){
    if(alloc3_desc(idx) == 0) {
      break;
    }
    sleep(&disk.free[0], &disk.vdisk_lock);
    80006632:	0023cc17          	auipc	s8,0x23c
    80006636:	d46c0c13          	addi	s8,s8,-698 # 80242378 <disk+0x128>
    8000663a:	a0ad                	j	800066a4 <virtio_disk_rw+0xbc>
      disk.free[i] = 0;
    8000663c:	00fb0733          	add	a4,s6,a5
    80006640:	00070c23          	sb	zero,24(a4) # 10001018 <_entry-0x6fffefe8>
    idx[i] = alloc_desc();
    80006644:	c19c                	sw	a5,0(a1)
    if(idx[i] < 0){
    80006646:	0207c563          	bltz	a5,80006670 <virtio_disk_rw+0x88>
  for(int i = 0; i < 3; i++){
    8000664a:	2905                	addiw	s2,s2,1
    8000664c:	0611                	addi	a2,a2,4 # 1004 <_entry-0x7fffeffc>
    8000664e:	05590f63          	beq	s2,s5,800066ac <virtio_disk_rw+0xc4>
    idx[i] = alloc_desc();
    80006652:	85b2                	mv	a1,a2
  for(int i = 0; i < NUM; i++){
    80006654:	0023c717          	auipc	a4,0x23c
    80006658:	bfc70713          	addi	a4,a4,-1028 # 80242250 <disk>
    8000665c:	87ce                	mv	a5,s3
    if(disk.free[i]){
    8000665e:	01874683          	lbu	a3,24(a4)
    80006662:	fee9                	bnez	a3,8000663c <virtio_disk_rw+0x54>
  for(int i = 0; i < NUM; i++){
    80006664:	2785                	addiw	a5,a5,1
    80006666:	0705                	addi	a4,a4,1
    80006668:	fe979be3          	bne	a5,s1,8000665e <virtio_disk_rw+0x76>
    idx[i] = alloc_desc();
    8000666c:	57fd                	li	a5,-1
    8000666e:	c19c                	sw	a5,0(a1)
      for(int j = 0; j < i; j++)
    80006670:	03205163          	blez	s2,80006692 <virtio_disk_rw+0xaa>
        free_desc(idx[j]);
    80006674:	f9042503          	lw	a0,-112(s0)
    80006678:	00000097          	auipc	ra,0x0
    8000667c:	cc2080e7          	jalr	-830(ra) # 8000633a <free_desc>
      for(int j = 0; j < i; j++)
    80006680:	4785                	li	a5,1
    80006682:	0127d863          	bge	a5,s2,80006692 <virtio_disk_rw+0xaa>
        free_desc(idx[j]);
    80006686:	f9442503          	lw	a0,-108(s0)
    8000668a:	00000097          	auipc	ra,0x0
    8000668e:	cb0080e7          	jalr	-848(ra) # 8000633a <free_desc>
    sleep(&disk.free[0], &disk.vdisk_lock);
    80006692:	85e2                	mv	a1,s8
    80006694:	0023c517          	auipc	a0,0x23c
    80006698:	bd450513          	addi	a0,a0,-1068 # 80242268 <disk+0x18>
    8000669c:	ffffc097          	auipc	ra,0xffffc
    800066a0:	c80080e7          	jalr	-896(ra) # 8000231c <sleep>
  for(int i = 0; i < 3; i++){
    800066a4:	f9040613          	addi	a2,s0,-112
    800066a8:	894e                	mv	s2,s3
    800066aa:	b765                	j	80006652 <virtio_disk_rw+0x6a>
  }

  // format the three descriptors.
  // qemu's virtio-blk.c reads them.

  struct virtio_blk_req *buf0 = &disk.ops[idx[0]];
    800066ac:	f9042503          	lw	a0,-112(s0)
    800066b0:	00451693          	slli	a3,a0,0x4

  if(write)
    800066b4:	0023c797          	auipc	a5,0x23c
    800066b8:	b9c78793          	addi	a5,a5,-1124 # 80242250 <disk>
    800066bc:	00a50713          	addi	a4,a0,10
    800066c0:	0712                	slli	a4,a4,0x4
    800066c2:	973e                	add	a4,a4,a5
    800066c4:	01703633          	snez	a2,s7
    800066c8:	c710                	sw	a2,8(a4)
    buf0->type = VIRTIO_BLK_T_OUT; // write the disk
  else
    buf0->type = VIRTIO_BLK_T_IN; // read the disk
  buf0->reserved = 0;
    800066ca:	00072623          	sw	zero,12(a4)
  buf0->sector = sector;
    800066ce:	01973823          	sd	s9,16(a4)

  disk.desc[idx[0]].addr = (uint64) buf0;
    800066d2:	6398                	ld	a4,0(a5)
    800066d4:	9736                	add	a4,a4,a3
  struct virtio_blk_req *buf0 = &disk.ops[idx[0]];
    800066d6:	0a868613          	addi	a2,a3,168
    800066da:	963e                	add	a2,a2,a5
  disk.desc[idx[0]].addr = (uint64) buf0;
    800066dc:	e310                	sd	a2,0(a4)
  disk.desc[idx[0]].len = sizeof(struct virtio_blk_req);
    800066de:	6390                	ld	a2,0(a5)
    800066e0:	00d605b3          	add	a1,a2,a3
    800066e4:	4741                	li	a4,16
    800066e6:	c598                	sw	a4,8(a1)
  disk.desc[idx[0]].flags = VRING_DESC_F_NEXT;
    800066e8:	4805                	li	a6,1
    800066ea:	01059623          	sh	a6,12(a1)
  disk.desc[idx[0]].next = idx[1];
    800066ee:	f9442703          	lw	a4,-108(s0)
    800066f2:	00e59723          	sh	a4,14(a1)

  disk.desc[idx[1]].addr = (uint64) b->data;
    800066f6:	0712                	slli	a4,a4,0x4
    800066f8:	963a                	add	a2,a2,a4
    800066fa:	058a0593          	addi	a1,s4,88
    800066fe:	e20c                	sd	a1,0(a2)
  disk.desc[idx[1]].len = BSIZE;
    80006700:	0007b883          	ld	a7,0(a5)
    80006704:	9746                	add	a4,a4,a7
    80006706:	40000613          	li	a2,1024
    8000670a:	c710                	sw	a2,8(a4)
  if(write)
    8000670c:	001bb613          	seqz	a2,s7
    80006710:	0016161b          	slliw	a2,a2,0x1
    disk.desc[idx[1]].flags = 0; // device reads b->data
  else
    disk.desc[idx[1]].flags = VRING_DESC_F_WRITE; // device writes b->data
  disk.desc[idx[1]].flags |= VRING_DESC_F_NEXT;
    80006714:	00166613          	ori	a2,a2,1
    80006718:	00c71623          	sh	a2,12(a4)
  disk.desc[idx[1]].next = idx[2];
    8000671c:	f9842583          	lw	a1,-104(s0)
    80006720:	00b71723          	sh	a1,14(a4)

  disk.info[idx[0]].status = 0xff; // device writes 0 on success
    80006724:	00250613          	addi	a2,a0,2
    80006728:	0612                	slli	a2,a2,0x4
    8000672a:	963e                	add	a2,a2,a5
    8000672c:	577d                	li	a4,-1
    8000672e:	00e60823          	sb	a4,16(a2)
  disk.desc[idx[2]].addr = (uint64) &disk.info[idx[0]].status;
    80006732:	0592                	slli	a1,a1,0x4
    80006734:	98ae                	add	a7,a7,a1
    80006736:	03068713          	addi	a4,a3,48
    8000673a:	973e                	add	a4,a4,a5
    8000673c:	00e8b023          	sd	a4,0(a7)
  disk.desc[idx[2]].len = 1;
    80006740:	6398                	ld	a4,0(a5)
    80006742:	972e                	add	a4,a4,a1
    80006744:	01072423          	sw	a6,8(a4)
  disk.desc[idx[2]].flags = VRING_DESC_F_WRITE; // device writes the status
    80006748:	4689                	li	a3,2
    8000674a:	00d71623          	sh	a3,12(a4)
  disk.desc[idx[2]].next = 0;
    8000674e:	00071723          	sh	zero,14(a4)

  // record struct buf for virtio_disk_intr().
  b->disk = 1;
    80006752:	010a2223          	sw	a6,4(s4)
  disk.info[idx[0]].b = b;
    80006756:	01463423          	sd	s4,8(a2)

  // tell the device the first index in our chain of descriptors.
  disk.avail->ring[disk.avail->idx % NUM] = idx[0];
    8000675a:	6794                	ld	a3,8(a5)
    8000675c:	0026d703          	lhu	a4,2(a3)
    80006760:	8b1d                	andi	a4,a4,7
    80006762:	0706                	slli	a4,a4,0x1
    80006764:	96ba                	add	a3,a3,a4
    80006766:	00a69223          	sh	a0,4(a3)

  __sync_synchronize();
    8000676a:	0ff0000f          	fence

  // tell the device another avail ring entry is available.
  disk.avail->idx += 1; // not % NUM ...
    8000676e:	6798                	ld	a4,8(a5)
    80006770:	00275783          	lhu	a5,2(a4)
    80006774:	2785                	addiw	a5,a5,1
    80006776:	00f71123          	sh	a5,2(a4)

  __sync_synchronize();
    8000677a:	0ff0000f          	fence

  *R(VIRTIO_MMIO_QUEUE_NOTIFY) = 0; // value is queue number
    8000677e:	100017b7          	lui	a5,0x10001
    80006782:	0407a823          	sw	zero,80(a5) # 10001050 <_entry-0x6fffefb0>

  // Wait for virtio_disk_intr() to say request has finished.
  while(b->disk == 1) {
    80006786:	004a2783          	lw	a5,4(s4)
    sleep(b, &disk.vdisk_lock);
    8000678a:	0023c917          	auipc	s2,0x23c
    8000678e:	bee90913          	addi	s2,s2,-1042 # 80242378 <disk+0x128>
  while(b->disk == 1) {
    80006792:	4485                	li	s1,1
    80006794:	01079c63          	bne	a5,a6,800067ac <virtio_disk_rw+0x1c4>
    sleep(b, &disk.vdisk_lock);
    80006798:	85ca                	mv	a1,s2
    8000679a:	8552                	mv	a0,s4
    8000679c:	ffffc097          	auipc	ra,0xffffc
    800067a0:	b80080e7          	jalr	-1152(ra) # 8000231c <sleep>
  while(b->disk == 1) {
    800067a4:	004a2783          	lw	a5,4(s4)
    800067a8:	fe9788e3          	beq	a5,s1,80006798 <virtio_disk_rw+0x1b0>
  }

  disk.info[idx[0]].b = 0;
    800067ac:	f9042903          	lw	s2,-112(s0)
    800067b0:	00290713          	addi	a4,s2,2
    800067b4:	0712                	slli	a4,a4,0x4
    800067b6:	0023c797          	auipc	a5,0x23c
    800067ba:	a9a78793          	addi	a5,a5,-1382 # 80242250 <disk>
    800067be:	97ba                	add	a5,a5,a4
    800067c0:	0007b423          	sd	zero,8(a5)
    int flag = disk.desc[i].flags;
    800067c4:	0023c997          	auipc	s3,0x23c
    800067c8:	a8c98993          	addi	s3,s3,-1396 # 80242250 <disk>
    800067cc:	00491713          	slli	a4,s2,0x4
    800067d0:	0009b783          	ld	a5,0(s3)
    800067d4:	97ba                	add	a5,a5,a4
    800067d6:	00c7d483          	lhu	s1,12(a5)
    int nxt = disk.desc[i].next;
    800067da:	854a                	mv	a0,s2
    800067dc:	00e7d903          	lhu	s2,14(a5)
    free_desc(i);
    800067e0:	00000097          	auipc	ra,0x0
    800067e4:	b5a080e7          	jalr	-1190(ra) # 8000633a <free_desc>
    if(flag & VRING_DESC_F_NEXT)
    800067e8:	8885                	andi	s1,s1,1
    800067ea:	f0ed                	bnez	s1,800067cc <virtio_disk_rw+0x1e4>
  free_chain(idx[0]);

  release(&disk.vdisk_lock);
    800067ec:	0023c517          	auipc	a0,0x23c
    800067f0:	b8c50513          	addi	a0,a0,-1140 # 80242378 <disk+0x128>
    800067f4:	ffffa097          	auipc	ra,0xffffa
    800067f8:	62e080e7          	jalr	1582(ra) # 80000e22 <release>
}
    800067fc:	70a6                	ld	ra,104(sp)
    800067fe:	7406                	ld	s0,96(sp)
    80006800:	64e6                	ld	s1,88(sp)
    80006802:	6946                	ld	s2,80(sp)
    80006804:	69a6                	ld	s3,72(sp)
    80006806:	6a06                	ld	s4,64(sp)
    80006808:	7ae2                	ld	s5,56(sp)
    8000680a:	7b42                	ld	s6,48(sp)
    8000680c:	7ba2                	ld	s7,40(sp)
    8000680e:	7c02                	ld	s8,32(sp)
    80006810:	6ce2                	ld	s9,24(sp)
    80006812:	6165                	addi	sp,sp,112
    80006814:	8082                	ret

0000000080006816 <virtio_disk_intr>:

void
virtio_disk_intr()
{
    80006816:	1101                	addi	sp,sp,-32
    80006818:	ec06                	sd	ra,24(sp)
    8000681a:	e822                	sd	s0,16(sp)
    8000681c:	e426                	sd	s1,8(sp)
    8000681e:	1000                	addi	s0,sp,32
  acquire(&disk.vdisk_lock);
    80006820:	0023c497          	auipc	s1,0x23c
    80006824:	a3048493          	addi	s1,s1,-1488 # 80242250 <disk>
    80006828:	0023c517          	auipc	a0,0x23c
    8000682c:	b5050513          	addi	a0,a0,-1200 # 80242378 <disk+0x128>
    80006830:	ffffa097          	auipc	ra,0xffffa
    80006834:	53e080e7          	jalr	1342(ra) # 80000d6e <acquire>
  // we've seen this interrupt, which the following line does.
  // this may race with the device writing new entries to
  // the "used" ring, in which case we may process the new
  // completion entries in this interrupt, and have nothing to do
  // in the next interrupt, which is harmless.
  *R(VIRTIO_MMIO_INTERRUPT_ACK) = *R(VIRTIO_MMIO_INTERRUPT_STATUS) & 0x3;
    80006838:	100017b7          	lui	a5,0x10001
    8000683c:	53b8                	lw	a4,96(a5)
    8000683e:	8b0d                	andi	a4,a4,3
    80006840:	100017b7          	lui	a5,0x10001
    80006844:	d3f8                	sw	a4,100(a5)

  __sync_synchronize();
    80006846:	0ff0000f          	fence

  // the device increments disk.used->idx when it
  // adds an entry to the used ring.

  while(disk.used_idx != disk.used->idx){
    8000684a:	689c                	ld	a5,16(s1)
    8000684c:	0204d703          	lhu	a4,32(s1)
    80006850:	0027d783          	lhu	a5,2(a5) # 10001002 <_entry-0x6fffeffe>
    80006854:	04f70863          	beq	a4,a5,800068a4 <virtio_disk_intr+0x8e>
    __sync_synchronize();
    80006858:	0ff0000f          	fence
    int id = disk.used->ring[disk.used_idx % NUM].id;
    8000685c:	6898                	ld	a4,16(s1)
    8000685e:	0204d783          	lhu	a5,32(s1)
    80006862:	8b9d                	andi	a5,a5,7
    80006864:	078e                	slli	a5,a5,0x3
    80006866:	97ba                	add	a5,a5,a4
    80006868:	43dc                	lw	a5,4(a5)

    if(disk.info[id].status != 0)
    8000686a:	00278713          	addi	a4,a5,2
    8000686e:	0712                	slli	a4,a4,0x4
    80006870:	9726                	add	a4,a4,s1
    80006872:	01074703          	lbu	a4,16(a4)
    80006876:	e721                	bnez	a4,800068be <virtio_disk_intr+0xa8>
      panic("virtio_disk_intr status");

    struct buf *b = disk.info[id].b;
    80006878:	0789                	addi	a5,a5,2
    8000687a:	0792                	slli	a5,a5,0x4
    8000687c:	97a6                	add	a5,a5,s1
    8000687e:	6788                	ld	a0,8(a5)
    b->disk = 0;   // disk is done with buf
    80006880:	00052223          	sw	zero,4(a0)
    wakeup(b);
    80006884:	ffffc097          	auipc	ra,0xffffc
    80006888:	b06080e7          	jalr	-1274(ra) # 8000238a <wakeup>

    disk.used_idx += 1;
    8000688c:	0204d783          	lhu	a5,32(s1)
    80006890:	2785                	addiw	a5,a5,1
    80006892:	17c2                	slli	a5,a5,0x30
    80006894:	93c1                	srli	a5,a5,0x30
    80006896:	02f49023          	sh	a5,32(s1)
  while(disk.used_idx != disk.used->idx){
    8000689a:	6898                	ld	a4,16(s1)
    8000689c:	00275703          	lhu	a4,2(a4)
    800068a0:	faf71ce3          	bne	a4,a5,80006858 <virtio_disk_intr+0x42>
  }

  release(&disk.vdisk_lock);
    800068a4:	0023c517          	auipc	a0,0x23c
    800068a8:	ad450513          	addi	a0,a0,-1324 # 80242378 <disk+0x128>
    800068ac:	ffffa097          	auipc	ra,0xffffa
    800068b0:	576080e7          	jalr	1398(ra) # 80000e22 <release>
}
    800068b4:	60e2                	ld	ra,24(sp)
    800068b6:	6442                	ld	s0,16(sp)
    800068b8:	64a2                	ld	s1,8(sp)
    800068ba:	6105                	addi	sp,sp,32
    800068bc:	8082                	ret
      panic("virtio_disk_intr status");
    800068be:	00002517          	auipc	a0,0x2
    800068c2:	e8a50513          	addi	a0,a0,-374 # 80008748 <etext+0x748>
    800068c6:	ffffa097          	auipc	ra,0xffffa
    800068ca:	c9a080e7          	jalr	-870(ra) # 80000560 <panic>
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
