romBase = $0FFFFFFFFFFF0000

		include "cpu/regs.i"
		include	"zp.i"

		include "tests/scan.asm"
		include "scan.asm"

		include "tests/char.asm"
		include "char.asm"

		include "con.asm"

; Cold boot entry point.

		align	8
start_tests:	or	x0, x0, x0
		jal	ra, L1

		dword	$0E00000000000000		; Pointer to debugger UART registers

		align	4
L1:		ld	a0, 0(ra)
		sd	a0, zpUartBase(x0)

		jal	a0, asrtRunI			; Run test suite and report results.
		align	8
		dword	10
		dword	do_nothing+romBase
		dword	testScanStart+romBase
		dword	testScanLineExhausted+romBase
		dword	testScanLineNotExhausted+romBase
		dword	testCharIsWhitespace+romBase
		dword	testCharIsNotWhitespace+romBase
		dword	testScanSkipWhitespace+romBase
		dword	testScanMarkWordStart+romBase
		dword	testScanSkipNonSpace+romBase
		dword	testScanMarkWordEnd+romBase

; First test suite.  This is a simple do-nothing test, illustrating how to write a typical test.
; Unconditionally jump to asrtFail if the test failed.

		byte	"NOTHING_"
do_nothing:	sd	ra, zpTestPC(x0)
		; ...
		ld	ra, zpTestPC(x0)
		jalr	0, 0(ra)

; asrtEquals will fail an assertion if A0 not equal A1.

asrtEquals:	beq	a0, a1, aIZ0
		or	s7, a1, x0
		or	s6, a0, x0
		auipc	gp, 0
aE0:		addi	a0, gp, expected0-aE0
		addi	a1, x0, expected2len
		jal	ra, conType
		or	a0, s7, x0
		jal	ra, conPutHex64
		addi	a0, gp, got0-aE0
		addi	a1, x0, got0len
		jal	ra, conType
		or	a0, s6, x0
		jal	ra, conPutHex64
		jal	x0, asrtFail

got0:		byte	" but got "
got0len = *-got0
		align	4

; asrtIsZero will fail an assertion if the value in the A0 register is non-zero.

asrtIsFalse:
asrtIsZero:	beq	a0, x0, aIZ0
		or	s7, a0, x0
		auipc	gp, 0
aIZ1:		addi	a0, gp, expected0-aIZ1
		addi	a1, x0, expected0len
		jal	ra, conType
		or	a0, s7, x0
		jal	ra, conPutHex64
		addi	a0, x0, 10
		jal	ra, conEmit
		jal	x0, asrtFail
aIZ0:		jalr	x0, 0(ra)

expected0:	byte	"Expected "
expected2len = *-expected0
		byte	"zero; got "
expected0len = *-expected0
		align	4

; asrtIsTrue will fail an assertion if the value in the A0 register is false/zero.

asrtIsTrue:	bne	a0, x0, aIT0
		or	s7, a0, x0
		auipc	gp, 0
aIT1:		addi	a0, gp, expected1-aIT1
		addi	a1, x0, expected1len
		jal	ra, conType
		or	a0, s7, x0
		jal	ra, conPutHex64
		addi	a0, x0, 10
		jal	ra, conEmit
		jal	x0, asrtFail
aIT0:		jalr	x0, 0(ra)

expected1:	byte	"Expected non-zero; got "
expected1len = *-expected1
		align	4

; asrtPrintName prints the grep tag for a test procedure.
;
; asrtPrintName(zpTestPtr)

asrtPrintName:	sd	ra, zpasrtPrintNamePC(x0)
		addi	a0, x0, 32
		jal	ra, conEmit
		jal	ra, conEmit
		ld	a0, zpTestPtr(x0)
		ld	a0, 0(a0)
		addi	a0, a0, -8
		addi	a1, x0, 8
		jal	ra, conType
		addi	a0, x0, 13
		jal	ra, conEmit
		addi	a0, x0, 10
		jal	ra, conEmit
		ld	ra, zpasrtPrintNamePC(x0)
		jalr	x0, 0(ra)

; asrtCallTest invokes the currently selected test.
; The current test address is pointed at by zpTestPtr.
; Note that zpTestPtr is a pointer to a pointer!

asrtCallTest:	sd	ra, zpasrtCallTestPC(x0)
		ld	a0, zpTestPtr(x0)
		ld	a0, 0(a0)
		jalr	ra, 0(a0)
		ld	ra, zpasrtCallTestPC(x0)
		jalr	x0, 0(ra)

; asrtRunTest invokes a single test procedure, pointed at by the
; dword pointed to by zpTestPtr.
;
; Remember to prepend the procedure with an 8-character grep tag!
; See asrtRun for more details.
;
; asrtRunTest(zpTestPtr)

asrtRunTest:	sd	ra, zpasrtRunTestPC(x0)
		jal	ra, asrtPrintName
		jal	ra, asrtCallTest
		ld	ra, zpasrtRunTestPC(x0)
		jalr	x0, 0(ra)

; asrtRunI runs a list of tests declared immediately after the subroutine call.
; This is safe, as asrtRunI never returns.
;
; The table must be aligned on an 8-byte boundary.  Therefore, call it like so:
;
;		jal	a0, asrtRunI
;		align	8
;		dword	number_of_tests
;		dword	test1
;		dword	test2
;		...

asrtRunI:	addi	a0, a0, 7
		andi	a0, a0, -8
		ld	a1, 0(a0)
		sd	a1, zpNumTests(x0)
		addi	a0, a0, 8
		sd	a0, zpTestPtr(x0)

		; fallthrough

; asrtRun executes a series of tests.  The tests to run appear in a table
; pointed to by zpTestPtr.  The table consists of zpNumTests dwords.
; If ALL tests pass, then PASSED appears, and the machine deadlocks.
; If ANY one test fails, then FAILED appears, and the machine similarly deadlocks.
;
; As each test runs, an 8-character test identifier is printed to the
; screen.  Each test procedure MUST be laid out in memory like so:
;
;		byte	"TESTNAME"	; case doesn't matter
;	tp:	...test goes here...
;
; The most recent test fail is guaranteed to be the one which deadlocks the
; computer, after FAILED is printed.
;
; NOTE: asrtRun NEVER returns.
;
; asrtRun(zpTestPtr, zpNumTests)

asrtRun:	ld	a0, zpNumTests(x0)
aR2:		beq	a0, x0, aR0	; length >= 0
		jal	ra, asrtRunTest
		ld	a0, zpTestPtr(x0)
		addi	a0, a0, 8
		sd	a0, zpTestPtr(x0)
		ld	a0, zpNumTests(x0)
		addi	a0, a0, -1	; length > 0 ==> length-1 >= 0
		sd	a0, zpNumTests(x0)
		jal	x0, aR2		; length >= 0

aR0:		auipc	gp, 0
aR1:		addi	a0, gp, PassMsg-aR1
		addi	a1, x0, PassLen
		jal	ra, conType
		jal	x0, *

; A failed assertion results in the message FAILED appearing on the console.
; We deadlock deliberately so that the human operator can record which test failed.
;
; asrtFail()

asrtFail:	auipc	gp, 0
aF1:		addi	a0, gp, FailMsg-aF1
		addi	a1, x0, FailLen
		jal	ra, conType
		jal	x0, *

FailMsg:	byte	"FAILED"
FailLen = * - FailMsg

PassMsg:	byte	"PASSED"
PassLen = * - PassMsg

		adv	$FF00, $CC
		jal	x0, start_tests

