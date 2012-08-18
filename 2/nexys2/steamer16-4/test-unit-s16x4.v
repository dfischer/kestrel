`timescale 1ns / 1ps

`define RESET_ORIGIN 	16'hFFF0

module TEST_UNIT_S16X4();
	reg [15:0] story_o;

	reg clk_o;
	reg res_o;
	reg ack_o;
	reg [15:0] dat_o;

	wire [15:1] adr_i;
	wire we_i;
	wire cyc_i;
	wire [1:0] stb_i;
	wire vda_i;
	wire vpa_i;
	wire [15:0] dat_i;

	STEAMER16X4 cpu(
		.res_i(res_o),
		.clk_i(clk_o),

		.adr_o(adr_i),
		.we_o(we_i),
		.cyc_o(cyc_i),
		.stb_o(stb_i),
		.vpa_o(vpa_i),
		.vda_o(vda_i),
		.dat_o(dat_i),
		
		.ack_i(ack_o),
		.dat_i(dat_o)
	);
 
	always begin
		#50 clk_o <= ~clk_o;
	end

	initial begin
		clk_o <= 0;
		res_o <= 0;
		ack_o <= 0;
		dat_o <= 16'hDEAD;

		wait(clk_o); wait(~clk_o);
		
		// AS A hardware engineer
		// I WANT the CPU to start execution at address $..FFF0
		// SO THAT I can jump to the appropriate initialization code.
		
		story_o <= 16'h0000;
		res_o <= 1;
		ack_o <= 1;
		wait(clk_o); wait(~clk_o);
		if(adr_i != (`RESET_ORIGIN >> 1)) begin
			$display("CPU should fetch its first instruction at $..FF0"); $stop;
		end
		if(we_i != 0) begin
			$display("CPU should not be writing after a reset."); $stop;
		end
		if(cyc_i != 1) begin
			$display("CPU should be in a bus cycle while fetching its first instructions."); $stop;
		end
		if(stb_i != 2'h3) begin
			$display("CPU should be fetching a full word."); $stop;
		end
		if(vpa_i != 1) begin
			$display("CPU should be trying to fetch from program space right now."); $stop;
		end
		if(vda_i != 0) begin
			$display("CPU should not be fetching an operand to an instruction."); $stop;
		end

		// AS A hardware engineer
		// I WANT the CPU to pause on a fetch when ACK_I is negated
		// SO THAT I can handle synchronous memories or slow peripherals.
		
		story_o <= 16'h0010;
		res_o <= 1;
		ack_o <= 0;
		wait(clk_o); wait(~clk_o);
		if(adr_i != (`RESET_ORIGIN >> 1)) begin
			$display("CPU should be fetching first instruction here."); $stop;
		end
		res_o <= 0;
		wait(clk_o); wait(~clk_o);
		if(adr_i != (`RESET_ORIGIN >> 1)) begin
			$display("CPU should still be fetching first instruction here."); $stop;
		end
		ack_o <= 1;
		dat_o <= 16'h1000;
		wait(clk_o); wait(~clk_o);
		if(adr_i != (`RESET_ORIGIN>>1)+1) begin
			$display("CPU should have advanced to the first operand here."); $stop;
		end

		// AS A software engineer
		// I WANT the CPU to fetch a literal value in response to the LIT opcode
		// SO THAT I can perform fetches and stores to program variables.
		
		story_o <= 16'h0020;
		res_o <= 1;
		ack_o <= 1;
		wait(clk_o); wait(~clk_o);
		if(vpa_i != 1) begin
			$display("CPU should be trying to fetch from program space right now."); $stop;
		end
		if(vda_i != 0) begin
			$display("CPU should not be fetching an operand to an instruction."); $stop;
		end
		res_o <= 0;
		dat_o <= 16'h1000;
		wait(clk_o); wait(~clk_o);
		if(vpa_i != 1) begin
			$display("CPU should still be trying to fetch from program space."); $stop;
		end
		if(vda_i != 1) begin
			$display("CPU should now be fetching an operand."); $stop;
		end
		dat_o <= 16'h1234;
		wait(clk_o); wait(~clk_o);
		if(adr_i != (`RESET_ORIGIN >> 1)+2) begin
			$display("CPU should have fetched opcode and operand by now."); $stop;
		end
		if(vda_i != 0) begin
			$display("It's exhausted its instruction stream.  It should be getting another instruction."); $stop;
		end

		// AS A software engineer
		// I WANT predictable NOP timing
		// SO THAT I can have cycle-accurate control over timing loops.
		
		story_o <= 16'h0030;
		res_o <= 1;
		ack_o <= 1;
		wait(clk_o); wait(~clk_o);
		if(vpa_i != 1) begin
			$display("CPU should be trying to fetch from program space right now."); $stop;
		end
		if(vda_i != 0) begin
			$display("CPU should not be fetching an operand to an instruction."); $stop;
		end
		res_o <= 0;
		dat_o <= 16'h0010;
		wait(clk_o); wait(~clk_o);
		if(cyc_i) begin
			$display("CPU should never engage the bus during a NOP."); $stop;
		end
		if(vda_i) begin
			$display("CPU should not be accessing data space here."); $stop;
		end
		if(vpa_i) begin
			$display("CPU should not be accessing program space here."); $stop;
		end
		wait(clk_o); wait(~clk_o);
		if(cyc_i) begin
			$display("CPU should never engage the bus during a NOP."); $stop;
		end
		if(vda_i) begin
			$display("CPU should not be accessing data space here."); $stop;
		end
		if(vpa_i) begin
			$display("CPU should not be accessing program space here."); $stop;
		end
		wait(clk_o); wait(~clk_o);
		if(~cyc_i) begin
			$display("CPU should try fetching an operand here."); $stop;
		end
		if(~vda_i) begin
			$display("CPU should be accessing an operand here."); $stop;
		end
		if(~vpa_i) begin
			$display("CPU should be accessing program space here."); $stop;
		end
		if(stb_i != 2'b11) begin
			$display("Fetching a full word here."); $stop;
		end
		if(adr_i != (`RESET_ORIGIN>>1)+1) begin
			$display("Fetching operand from wrong address"); $stop;
		end
		wait(clk_o); wait(~clk_o);
		if(~cyc_i) begin
			$display("CPU should try fetching an opcode here."); $stop;
		end
		if(vda_i) begin
			$display("CPU should be accessing an opcode here."); $stop;
		end
		if(~vpa_i) begin
			$display("CPU should be accessing program space here."); $stop;
		end
		if(stb_i != 2'b11) begin
			$display("Fetching a full word here."); $stop;
		end
		if(adr_i != (`RESET_ORIGIN>>1)+2) begin
			$display("Fetching opcode from wrong address"); $stop;
		end
		
		// AS A software engineer
		// I WANT the ability to store a word to memory
		// SO THAT I can update program state.
		
		story_o <= 16'h0040;
		res_o <= 1;
		ack_o <= 1;
		wait(clk_o); wait(~clk_o);
		
		dat_o <= 16'h1130;		// LI $BBBB:LI $AAAA:SWM:NOP
		res_o <= 0;
		wait(clk_o); wait(~clk_o);
		dat_o <= 16'hBBBB;
		wait(clk_o); wait(~clk_o);
		dat_o <= 16'hAAAA;
		wait(clk_o); wait(~clk_o);
		if(adr_i != 15'h5555) begin
			$display("CPU should be addressing memory location $AAAA right now."); $stop;
		end
		if(stb_i != 2'b11) begin
			$display("CPU should be addressing a full word right now."); $stop;
		end
		if(~cyc_i) begin
			$display("CPU should be engaging the bus during this cycle."); $stop;
		end
		if(~we_i) begin
			$display("CPU should be writing during this cycle."); $stop;
		end
		if(~vda_i) begin
			$display("CPU should be addressing data space during this cycle."); $stop;
		end
		if(vpa_i) begin
			$display("CPU can never write to program space.  EVER."); $stop;
		end
		if(dat_i != 16'hBBBB) begin
			$display("CPU should be writing $BBBB during this cycle."); $stop;
		end
		wait(clk_o); wait(~clk_o);
		if(adr_i != (`RESET_ORIGIN>>1)+3) begin
			$display("Expected P value mismatch."); $stop;
		end
		if(~cyc_i) begin
			$display("CPU should be jonsing for an opcode fetch here."); $stop;
		end
		if(~vpa_i) begin
			$display("Opcodes live in program space, yo."); $stop;
		end
		if(vda_i) begin
			$display("Opcodes aren't operands, however."); $stop;
		end

		// AS A software engineer
		// I WANT the ability to store a byte to an odd memory address
		// SO THAT I can update program state or, probably, I/O peripherals.

		story_o <= 16'h0050;
		res_o <= 1;
		ack_o <= 1;
		wait(clk_o); wait(~clk_o);

		dat_o <= 16'h11B0;		// LI $BBBB:LI $AAAA:SBM:NOP
		res_o <= 0;
		wait(clk_o); wait(~clk_o);
		dat_o <= 16'hBBBB;
		wait(clk_o); wait(~clk_o);
		dat_o <= 16'hAAAA;
		wait(clk_o); wait(~clk_o);
		if(adr_i != 15'h5555) begin
			$display("CPU should be addressing memory location $AAAA right now."); $stop;
		end
		if(stb_i != 2'b01) begin
			$display("CPU should be addressing the low byte right now."); $stop;
		end
		if(~cyc_i) begin
			$display("CPU should be engaging the bus during this cycle."); $stop;
		end
		if(~we_i) begin
			$display("CPU should be writing during this cycle."); $stop;
		end
		if(~vda_i) begin
			$display("CPU should be addressing data space during this cycle."); $stop;
		end
		if(vpa_i) begin
			$display("CPU can never write to program space.  EVER."); $stop;
		end
		if(dat_i != 16'hBBBB) begin
			$display("CPU should be writing $BBBB during this cycle."); $stop;
		end
		wait(clk_o); wait(~clk_o);
		if(adr_i != (`RESET_ORIGIN>>1)+3) begin
			$display("Expected P value mismatch."); $stop;
		end
		if(~cyc_i) begin
			$display("CPU should be jonsing for an opcode fetch here."); $stop;
		end
		if(~vpa_i) begin
			$display("Opcodes live in program space, yo."); $stop;
		end
		if(vda_i) begin
			$display("Opcodes aren't operands, however."); $stop;
		end

		
		// AS A software engineer
		// I WANT the ability to store a byte to an even memory address
		// SO THAT I can update program state or, probably, I/O peripherals.
		
		story_o <= 16'h0060;
		res_o <= 1;
		ack_o <= 1;
		wait(clk_o); wait(~clk_o);

		dat_o <= 16'h11B0;		// LI $BBBB:LI $AAAB:SBM:NOP
		res_o <= 0;
		wait(clk_o); wait(~clk_o);
		dat_o <= 16'hBBBB;
		wait(clk_o); wait(~clk_o);
		dat_o <= 16'hAAAB;
		wait(clk_o); wait(~clk_o);
		if(adr_i != 15'h5555) begin
			$display("CPU should be addressing memory location $AAAB right now."); $stop;
		end
		if(stb_i != 2'b10) begin
			$display("CPU should be addressing the high byte right now."); $stop;
		end
		if(~cyc_i) begin
			$display("CPU should be engaging the bus during this cycle."); $stop;
		end
		if(~we_i) begin
			$display("CPU should be writing during this cycle."); $stop;
		end
		if(~vda_i) begin
			$display("CPU should be addressing data space during this cycle."); $stop;
		end
		if(vpa_i) begin
			$display("CPU can never write to program space.  EVER."); $stop;
		end
		if(dat_i != 16'hBBBB) begin
			$display("CPU should be writing $BBBB during this cycle."); $stop;
		end
		wait(clk_o); wait(~clk_o);
		if(adr_i != (`RESET_ORIGIN>>1)+3) begin
			$display("Expected P value mismatch."); $stop;
		end
		if(~cyc_i) begin
			$display("CPU should be jonsing for an opcode fetch here."); $stop;
		end
		if(~vpa_i) begin
			$display("Opcodes live in program space, yo."); $stop;
		end
		if(vda_i) begin
			$display("Opcodes aren't operands, however."); $stop;
		end

		// AS A hardware engineer
		// I WANT the ACKI_I input to be honored during memory write cycles
		// SO THAT I can enjoy using this CPU with synchronous or slow devices.

		story_o <= 16'h0070;
		res_o <= 1;
		ack_o <= 1;
		wait(clk_o); wait(~clk_o);

		dat_o <= 16'h11B0;		// LI $BBBB:LI $AAAB:SBM:NOP
		res_o <= 0;
		wait(clk_o); wait(~clk_o);
		dat_o <= 16'hBBBB;
		wait(clk_o); wait(~clk_o);
		dat_o <= 16'hAAAB;
		wait(clk_o); wait(~clk_o);
		if(adr_i != 15'h5555) begin
			$display("CPU should be addressing memory location $AAAB right now."); $stop;
		end
		if(stb_i != 2'b10) begin
			$display("CPU should be addressing the high byte right now."); $stop;
		end
		if(~cyc_i) begin
			$display("CPU should be engaging the bus during this cycle."); $stop;
		end
		if(~we_i) begin
			$display("CPU should be writing during this cycle."); $stop;
		end
		if(~vda_i) begin
			$display("CPU should be addressing data space during this cycle."); $stop;
		end
		if(vpa_i) begin
			$display("CPU can never write to program space.  EVER."); $stop;
		end
		if(dat_i != 16'hBBBB) begin
			$display("CPU should be writing $BBBB during this cycle."); $stop;
		end
		ack_o <= 0;
		wait(clk_o); wait(~clk_o);
		if(adr_i != 15'h5555) begin
			$display("CPU should still be addressing memory location $AAAB right now."); $stop;
		end
		if(stb_i != 2'b10) begin
			$display("CPU should still be addressing the high byte right now."); $stop;
		end
		if(~cyc_i) begin
			$display("CPU should still be engaging the bus during this cycle."); $stop;
		end
		if(~we_i) begin
			$display("CPU should still be writing during this cycle."); $stop;
		end
		if(~vda_i) begin
			$display("CPU should still be addressing data space during this cycle."); $stop;
		end
		if(vpa_i) begin
			$display("CPU can never write to program space.  EVER."); $stop;
		end
		if(dat_i != 16'hBBBB) begin
			$display("CPU should still be writing $BBBB during this cycle."); $stop;
		end
		ack_o <= 1;
		wait(clk_o); wait(~clk_o);
		if(adr_i != (`RESET_ORIGIN>>1)+3) begin
			$display("Expected P value mismatch."); $stop;
		end
		if(~cyc_i) begin
			$display("CPU should be jonsing for an opcode fetch here."); $stop;
		end
		if(~vpa_i) begin
			$display("Opcodes live in program space, yo."); $stop;
		end
		if(vda_i) begin
			$display("Opcodes aren't operands, however."); $stop;
		end

		// AS A software engineer
		// I WANT to fetch words from memory
		// SO THAT I can respond to previously established program state.

		story_o <= 16'h0080;
		res_o <= 1;
		ack_o <= 1;
		wait(clk_o); wait(~clk_o);
		
		dat_o <= 16'h1213;		// LI $BBBB:FWM:LI $AAAA:SWM
		res_o <= 0;
		wait(clk_o); wait(~clk_o);
		dat_o <= 16'hBBBB;
		wait(clk_o); wait(~clk_o);
		if(adr_i != 15'b101110111011101) begin
			$display("Peek address not what I expected"); $stop;
		end
		if(we_i) begin
			$display("We should be fetching, not storing."); $stop;
		end
		if(stb_i != 2'b11) begin
			$display("We should be fetching a full word."); $stop;
		end
		if(vpa_i) begin
			$display("We should be fetching from data memory."); $stop;
		end
		if(~vda_i) begin
			$display("We should be fetching from data memory."); $stop;
		end
		if(~cyc_i) begin
			$display("We should be engaging the bus to fetch."); $stop;
		end
		dat_o <= 16'hBEEF;
		wait(clk_o); wait(~clk_o);
		dat_o <= 16'hAAAA;
		wait(clk_o); wait(~clk_o);
		if(adr_i != 15'b101010101010101) begin
			$display("Poke address not what I expected"); $stop;
		end
		if(~we_i) begin
			$display("We should be storing, not fetching."); $stop;
		end
		if(stb_i != 2'b11) begin
			$display("We should be storing a full word."); $stop;
		end
		if(vpa_i) begin
			$display("We should be storing to data memory."); $stop;
		end
		if(~vda_i) begin
			$display("We should be storing to data memory."); $stop;
		end
		if(~cyc_i) begin
			$display("We should be engaging the bus to store."); $stop;
		end
		if(dat_i != 16'hBEEF) begin
			$display("The value we just fetched should be on the output bus right now."); $stop;
		end
		wait(clk_o); wait(~clk_o);
		if(adr_i != (`RESET_ORIGIN>>1)+3) begin
			$display("Poke address not what I expected"); $stop;
		end
		if(we_i) begin
			$display("We should be fetching."); $stop;
		end
		if(stb_i != 2'b11) begin
			$display("We should be fetching a full word."); $stop;
		end
		if(~vpa_i) begin
			$display("We should be fetching the next opcode."); $stop;
		end
		if(vda_i) begin
			$display("We should be fetching the next opcode."); $stop;
		end
		if(~cyc_i) begin
			$display("We should be engaging the bus to store."); $stop;
		end

		// AS A software engineer
		// I WANT to fetch bytes from memory
		// SO THAT I can look up LED segment values in a simple table.

		story_o <= 16'h0090;
		res_o <= 1;
		ack_o <= 1;
		wait(clk_o); wait(~clk_o);
		
		dat_o <= 16'h1A13;		// LI $BBBB:FBM:LI $AAAA:SWM
		res_o <= 0;
		wait(clk_o); wait(~clk_o);
		dat_o <= 16'hBBBB;
		wait(clk_o); wait(~clk_o);
		if(adr_i != 15'b101110111011101) begin
			$display("Peek address not what I expected"); $stop;
		end
		if(we_i) begin
			$display("We should be fetching, not storing."); $stop;
		end
		if(stb_i != 2'b10) begin
			$display("We should be fetching a byte at an odd address."); $stop;
		end
		if(vpa_i) begin
			$display("We should be fetching from data memory."); $stop;
		end
		if(~vda_i) begin
			$display("We should be fetching from data memory."); $stop;
		end
		if(~cyc_i) begin
			$display("We should be engaging the bus to fetch."); $stop;
		end
		dat_o <= 16'hBEEF;
		wait(clk_o); wait(~clk_o);
		dat_o <= 16'hAAAA;
		wait(clk_o); wait(~clk_o);
		if(adr_i != 15'b101010101010101) begin
			$display("Poke address not what I expected"); $stop;
		end
		if(~we_i) begin
			$display("We should be storing, not fetching."); $stop;
		end
		if(stb_i != 2'b11) begin
			$display("We should be storing a full word."); $stop;
		end
		if(vpa_i) begin
			$display("We should be storing to data memory."); $stop;
		end
		if(~vda_i) begin
			$display("We should be storing to data memory."); $stop;
		end
		if(~cyc_i) begin
			$display("We should be engaging the bus to store."); $stop;
		end
		if(dat_i != 16'h00BE) begin
			$display("The value we just fetched should be on the output bus right now."); $stop;
		end
		wait(clk_o); wait(~clk_o);
		if(adr_i != (`RESET_ORIGIN>>1)+3) begin
			$display("Poke address not what I expected"); $stop;
		end
		if(we_i) begin
			$display("We should be fetching."); $stop;
		end
		if(stb_i != 2'b11) begin
			$display("We should be fetching a full word."); $stop;
		end
		if(~vpa_i) begin
			$display("We should be fetching the next opcode."); $stop;
		end
		if(vda_i) begin
			$display("We should be fetching the next opcode."); $stop;
		end
		if(~cyc_i) begin
			$display("We should be engaging the bus to store."); $stop;
		end

		story_o <= 16'hFFFF;
		$stop;
	end
endmodule
