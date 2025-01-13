//.
//.
//.
//.
//.
`ifndef AMIQ_INPUT
`define AMIQ_INPUT
`endif
module amiq_input;
	reg[15:0] mat_in;
	reg mat_valid; //for mat_in signal validation
	reg clk;
	reg rst_n;
	reg mat_request; //if matrix needs more elements
	reg[15:0] det;
	reg det_valid; //if det is valid
	reg overflow;

	amiq_md uut(
		.mat_in(mat_in),
		.mat_valid(mat_valid),
		.clk(clk),
		.rst_n(rst_n),
		.mat_request(mat_request),
		.det(det),
		.det_valid(det_valid),
		.overflow(overflow)
	);

	initial begin
		clk = 0;
		forever #10 clk = ~clk;
	end


	initial begin
		//first test - no delays
		mat_in <= 16'h0000;
		mat_valid <= 1'b0;
		rst_n <= 0;

		@(posedge clk);
		repeat (3)
			@(posedge clk);
		rst_n <= 1; //reset becomes inactive

		@(posedge clk);
		@(posedge clk); mat_in <= 16'h0002;
		mat_valid <= 1'b1;
		@(posedge clk); mat_in <= 16'h0000;
		@(posedge clk); mat_in <= 16'h0000;
		@(posedge clk); mat_in <= 16'h0000;
		@(posedge clk); mat_in <= 16'h0003;
		@(posedge clk); mat_in <= 16'h0000;
		mat_valid <= 1'b1;
		@(posedge clk); mat_in <= 16'h0000;
		@(posedge clk); mat_in <= 16'h0000;
		@(posedge clk); mat_in <= 16'h0001;
		@(posedge clk);
		mat_valid <= 1'b0;
		@(posedge clk);
		mat_in <= 16'hxxxx;

		repeat (6)
			@(posedge clk);

		//second test - delays from mat_valid
		mat_valid <= 1'b0;

		rst_n <= 0;

		@(posedge clk);
		repeat (3)
			@(posedge clk);
		rst_n <= 1;

		@(posedge clk);

		@(posedge clk); mat_in <= 16'h0001;
		mat_valid <= 1'b1;
		@(posedge clk); mat_in <= 16'h0002;
		@(posedge clk); mat_in <= 16'h0003;
		@(posedge clk);
		mat_valid <= 0;

		repeat (3)
			@(posedge clk);

		@(posedge clk); mat_in <= 16'h0004;
		mat_valid <= 1'b1;
		@(posedge clk); mat_in <= 16'h0005;
		@(posedge clk); mat_in <= 16'h0006;
		@(posedge clk); mat_in <= 16'h0007;
		@(posedge clk); mat_in <= 16'h0008;
		@(posedge clk); mat_in <= 16'h0009;
		@(posedge clk);
		@(posedge clk);
		mat_valid <= 1'b0;
		mat_in <= 16'hxxxx;

		repeat (200)
			@(posedge clk);

		$finish;
	end
endmodule
