// Part 2 skeleton

module draw
	(
		board_clock,						//	On Board 50 MHz
		// Your inputs and outputs here
        go,
    	in_x,
		in_y,
		in_colour,
		resetn,
		// The ports below are for the VGA output.  Do not change.
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,						//	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B   						//	VGA Blue[9:0]
	);

	input			board_clock;				//	50 MHz
	input   [7:0]   in_x;
	input   [6:0]   in_y;
	input   [2:0]   in_colour;
	input           go;
	input           resetn;

	// Declare your inputs and outputs here
	// Do not change the following outputs
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;				//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[9:0]	VGA_R;   				//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 				//	VGA Green[9:0]
	output	[9:0]	VGA_B;   				//	VGA Blue[9:0]


	// Create the colour, x, y and writeEn wires that are inputs to the controller.
	wire [2:0] colour;
	wire [7:0] x;
	wire [6:0] y;
	wire writeEn;
	wire offset_x;
	wire offset_y;
	wire ld_x, ld_y;


	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter VGA(
			.resetn(resetn),
			.clock(board_clock),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(writeEn),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "black.mif";

	// Put your code here. Your code should produce signals x,y,colour and writeEn/plot
	// for the VGA controller, in addition to any other functionality your design may require.


    // Instantiate datapath
	draw_datapath d0(
		.x(in_x),
		.y(in_y),
		.offset_x(offset_x),
		.offset_y(offset_y),
		.colour(in_colour),
		.ld_x(ld_x),
		.ld_y(ld_y),
		.reset_n(resetn),
		.clock(board_clock),

		.out_x(x),
		.out_y(y),
		.out_colour(colour)
	);

    // Instantiate FSM control
    draw_control c0(
		.clock(board_clock),
		.reset_n(resetn),
		.go(go),
		
		.ld_x(ld_x),
		.ld_y(ld_y),
		.offset_x(offset_x),
		.offset_y(offset_y),
		.plot(writeEn)
	);

endmodule



module draw_datapath(
	input [7:0] x,
	input [6:0] y,
	input offset_x,
	input offset_y,
	input [2:0] colour,
	input ld_x,
	input ld_y,
	input reset_n,
	input clock,
	output reg [7:0] out_x,
	output reg [6:0] out_y,
	output reg [2:0] out_colour
	);
	reg [7:0] original_x;
	reg [6:0] original_y;


	always @(posedge clock)
	begin
		if (!reset_n)
		begin
			out_x <= 0;
			out_y <= 0;
			out_colour <= 0;
		end
		else
		begin
			if (ld_x)
			begin
				out_colour <= colour;
				original_x <= x;
				out_x <= original_x;
			end
			else
				out_x <= original_x + offset_x;
			if (ld_y)
			begin
				original_y <= y;
				out_y <= original_y;
			end
			else
				out_y <= original_y + offset_y;
		end
	end
endmodule

module draw_control(
	input clock,
	input reset_n,
	input go,

	output reg ld_x,
	output reg ld_y,
	output reg offset_x,
	output reg offset_y,
	output reg plot
	);

	reg [2:0] current_state;
	reg [2:0] next_state;

	localparam  S_LOAD        = 3'd0,
				S_DRAW_0_0        = 3'd1,
				S_DRAW_1_0        = 3'd2,
				S_DRAW_0_1        = 3'd3,
				S_DRAW_1_1        = 3'd4;

	always @(*)
	begin: state_table
		case(current_state)
			S_LOAD: next_state = go ? S_DRAW_0_0 : S_LOAD;
			S_DRAW_0_0: next_state = go ? S_DRAW_1_0 : S_DRAW_0_0;
			S_DRAW_1_0: next_state = go ? S_DRAW_0_1 : S_DRAW_1_0;
			S_DRAW_0_1: next_state = go ? S_DRAW_1_1 : S_DRAW_0_1;
			S_DRAW_1_1: next_state = go ? S_DRAW_1_1 : S_LOAD;

			default: next_state = S_LOAD;
		endcase
	end

	always @(*)
	begin: enable_signals
		ld_x <= 1'b0;
		ld_y <= 1'b0;
		offset_x <= 1'b0;
		offset_y <= 1'b0;
		plot <= 1'b0;

		case(current_state)
			S_LOAD: begin
				ld_x <= 1'b1;
				ld_y <= 1'b1;
				offset_x <= 1'b0;
				offset_y <= 1'b0;
				plot <= 1'b0;
				end
			S_DRAW_0_0: begin
				ld_x <= 1'b0;
				ld_y <= 1'b0;
				offset_x <= 0;
				offset_y <= 0;
				plot <= 1'b1;
				end
			S_DRAW_1_0: begin
				ld_x <= 1'b0;
				ld_y <= 1'b0;
				offset_x <= 1'b1;
				offset_y <= 0;
				plot <= 1'b1;
				end
			S_DRAW_0_1: begin
				ld_x <= 1'b0;
				ld_y <= 1'b0;
				offset_x <= 0;
				offset_y <= 1'b1;
				plot <= 1'b1;
				end
			S_DRAW_1_1: begin
				ld_x <= 1'b0;
				ld_y <= 1'b0;
				offset_x <= 1'b1;
				offset_y <= 1'b1;
				plot <= 1'b1;
				end
		endcase
	end

	
	always @(posedge clock)
	begin: state_FFs
		if(!reset_n)
			current_state <= S_LOAD;
		else
		begin
			current_state <= next_state;
		end
	end
endmodule
