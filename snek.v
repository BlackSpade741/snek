// SNEK
// YUFEI CHEN, REECE MARTIN
// CONTROLLED WITH KEY[3:0] FOR NOW
// UP: KEY[2]
// DOWN: KEY[1]
// LEFT: KEY[3]
// RIGHT: KEY[0]
// ACTIVE LOW RESET: SW[0]
// PLAY: SW[1]
// CURRENT SCORE DISPLAYED ON HEX1 & HEX0
// HIGH SCORE DISPLAYED ON HEX5 & HEX4
// ENJOY!

module snek
    (
        CLOCK_50,
        SW,
		  LEDR,
		  KEY,
        // TODO: Keyboard inputs
        VGA_CLK,
        VGA_HS,
        VGA_VS,
        VGA_BLANK_N,
        VGA_SYNC_N,
        VGA_R,
        VGA_G,
        VGA_B
    );

    input           CLOCK_50;
    input   [9:0]   SW; //
	 input   [3:0]   KEY;
	 output  [9:0]   LEDR;
    // TODO: Keyboard inputs
    output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;				//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[9:0]	VGA_R;   				//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 				//	VGA Green[9:0]
	output	[9:0]	VGA_B;   				//	VGA Blue[9:0]

	wire [7:0] x_to_draw;
	wire [6:0] y_to_draw;

	wire [2:0] colour_to_draw;

	wire              go;
	 wire             init;
    wire             play;


    draw d(
        .board_clock(CLOCK_50),
        .go(go),
        .in_x(x_to_draw),
        .in_y(y_to_draw),
        .in_colour(colour_to_draw),
        .resetn(SW[0]),

		  .VGA_CLK(VGA_CLK),
        .VGA_R(VGA_R),
        .VGA_G(VGA_G),
        .VGA_B(VGA_B),
        .VGA_HS(VGA_HS),
        .VGA_VS(VGA_VS),
        .VGA_BLANK_N(VGA_BLANK_N),
        .VGA_SYNC_N(VGA_SYNC_N)
    );

	 wire     [1:0]   direction; // bit 1 is axis (x = 0, y = 1), bit 0 is pos/neg.
    wire             alive;


    convert_directions cd(
        .up(~KEY[2]),
        .down(~KEY[1]),
        .left(~KEY[3]),
        .right(~KEY[0]),
        .resetn(SW[0]),
        .clock(CLOCK_50),
        .direction(direction)
    );

    datapath dp(
        .clock(CLOCK_50),
        .play(play),
        .direction(direction),
        .resetn(SW[0]),
        .in(init),


        .alive(alive),
        .go(go),
        .x_to_draw(x_to_draw),
        .y_to_draw(y_to_draw),
        .colour_to_draw(colour_to_draw)
    );

    control c(
        .go(SW[1]),
        .alive(alive),
        .resetn(SW[0]),
        .play(play),
        .init(init),
		  .current_s(LEDR[3:2]),
		  .next_s(LEDR[1:0]),
		  .clock(CLOCK_50)
    );

endmodule

module datapath(
    input clock,
    input play,
    input [1:0] direction, // bit 1 is axis (x = 0, y = 1), bit 0 is pos/neg.
    input resetn,
    input in,

    output reg alive,
    output reg go,
    output reg [8:0] x_to_draw,
    output reg [7:0] y_to_draw,
    output reg [3:0] colour_to_draw
    );



    localparam width = 8'd160;
    localparam height = 7'd120;
    localparam SNAKE_COLOUR = 3'b111;
    localparam FOOD_COLOUR = 3'b100;
    localparam BLACK_COLOUR = 3'b000;
    localparam delay = 20'b11001011011100110101;
    localparam frames = 6'd30;
    localparam pixels = 3'd4;

    reg     [7:0]    head_x;
    reg     [6:0]   head_y;
    reg     [7:0]   tail_x;
    reg     [6:0]   tail_y;
    reg     [7:0]   next_tail_x;
    reg     [6:0]   next_tail_y;
    wire    [14:0]  head_addr;
    assign head_addr = head_x * width + head_y;
    wire    [14:0]  tail_addr;
    assign tail_addr = tail_x * width + tail_y;
    wire    [14:0]  tail_top_addr;
    assign tail_top_addr = (tail_y - 1'b1) * width + tail_x;
    wire    [14:0]  tail_bottom_addr;
    assign tail_bottom_addr = (tail_y + 1'b1) * width + tail_x;
    wire    [14:0]  tail_left_addr;
    assign tail_left_addr = tail_y * width + tail_x - 1'b1;
    wire    [14:0]  tail_right_addr;
    assign tail_right_addr = tail_y * width + tail_x + 1'b1;


    reg      [2:0]   init_block_num;
    reg             init_drawing;
    reg     [14:0]  length;
    reg     [1:0]   init_pixel_counter;
    localparam      initial_length = 3'd5;
    localparam      starting_x = 8'd5;
    localparam      starting_y = 7'd5;

    reg             checking;
    reg             ram_buffer;
    reg     [1:0]   retrieving;

    reg     [14:0]  addr;
    reg     [2:0]   ram_in;
    wire     [2:0]   ram_out;
    reg             wren;

    reg             erase;
    reg     [19:0]  delay_counter;
    reg     [5:0]   frames_counter;
    reg     [2:0]   pixel_counter;
    reg             drawing;

	reg init;
//    ram r(
//        .address(addr),
//        .clock(clock),
//        .data(ram_in),
//        .q(ram_out),
//        .wren(wren)
//        );

    always @(posedge clock)
    begin
        if (!resetn) // Active low reset TODO: reset every register
        begin
            alive <= 1'b1;

            delay_counter <= delay;
            frames_counter <= frames;
            pixel_counter <= pixels;
            x_to_draw <= 0;
            y_to_draw <= 0;
            colour_to_draw <= 0;
            drawing <= 0;
            go <= 0;
            erase <= 0;
			init <= 1;

            head_x <= starting_x + initial_length;
            head_y <= starting_y;
            tail_x <= starting_x;
            tail_y <= starting_y;
            next_tail_x <= starting_x + 1'b1;
            next_tail_y <= starting_y;

            init_block_num <= 0;
            init_drawing <= 0;
            length <= 3'd6;
            init_pixel_counter <= pixels;

            checking <= 0;
            ram_buffer <= 0;
            retrieving <= 0;
            addr <= 0;
            ram_in <= 0;
            wren <= 0;
        end
        else if (play) // game is in play
            if (in && init) // game is starting, initialize.
            begin
                if (init_drawing) // drawing one block of the initial snake
                begin
                    if (pixel_counter == 0)
                    begin
                        init_drawing <= 0;
                        init_block_num <= init_block_num + 1'b1;
                        pixel_counter <= pixels;
                        go <= 1'b0;
                    end
                    else
                        pixel_counter <= pixel_counter - 1'b1;
                end
                else // not drawing a block, draw something else
                begin
                    if (init_block_num == initial_length) // the whole snake has been drawn
						  begin
                        init <= ~init;
                        init_block_num <= 0;
                        wren <= 1'b0;
								go <= 1'b0;
						  end
                    else // draw the next block
                    begin
                        // draw
                        x_to_draw <= starting_x + init_block_num + starting_x + init_block_num;
                        y_to_draw <= starting_y + starting_y;
                        colour_to_draw <= SNAKE_COLOUR;
                        init_drawing <= 1'b1;
                        go <= 1'b1;
                        // write to memory
                        addr <= starting_y * width + starting_x;
                        ram_in <= SNAKE_COLOUR;
                        wren <= 1'b1;
                    end
                end
            end
            else if (!in && !init) // game is in progress
            begin
                if (delay_counter == 20'b0 && frames_counter == 5'b0)// finished counting
                begin
                    if (drawing) // still drawing something
                    begin
                        if (pixel_counter == 0)
                        begin
                            drawing <= 0;
                            go <= 0;
                            erase <= ~erase;
                            pixel_counter <= pixels;
                            wren <= 1'b0;
                        end
                        else
                            pixel_counter <= pixel_counter - 1'b1;
                    end
                    else // find out what the next thing to draw is
                    begin
                        if (erase) // erase tail
                        begin
                            drawing <= 1'b1;
                            x_to_draw <= tail_x * 1'd2;
                            y_to_draw <= tail_y * 1'd2;
                            colour_to_draw <= BLACK_COLOUR;
                            addr <= tail_addr;
                            ram_in <= BLACK_COLOUR;
                            wren <= 1'b0;
                            go <= 1'b1;
                            pixel_counter <= pixels;
                            tail_x <= next_tail_x;
                            tail_y <= next_tail_y;
                            erase <= ~erase;
                        end
                        else // draw head TODO: ADD LOGIC FOR EATING FOOD
                        begin
                            drawing <= 1'b1;
                            if (!direction[1])// x axis
                            begin
                                if (!direction[0])// left
										  begin
                                    x_to_draw <= (head_x - 1'b1) * 1'd2;
                                    addr <= head_y * width + head_x - 1'b1;
										  end
                                else // right
										  begin
                                    x_to_draw <= (head_x + 1'b1) * 1'd2;
                                    addr <= head_y * width + head_x + 1'b1;
										  end
                                y_to_draw <= (head_y) * 1'd2;
                            end
                            else // y axis
                            begin
                                if (!direction[0])// top
										  begin
                                    y_to_draw <= (head_y - 1) * 1'd2;
                                    addr <= (head_y - 1) * width + head_x;
										  end
                                else
										  begin
                                    y_to_draw <= (head_y + 1) * 1'd2;
                                    addr <= (head_y + 1) * width + head_x;
										  end
                                x_to_draw <= (head_x) * 1'd2;
                            end
                            colour_to_draw <= SNAKE_COLOUR;
                            go <= 1'b1;
                            pixel_counter <= pixels;
                            erase <= ~erase;
                            delay_counter <= delay;
                            frames_counter <= frames;
                            ram_in <= SNAKE_COLOUR;
                            wren <= 1'b1;
                        end
                    end
                end
                else // keep counting
                begin
                    if (delay_counter == 20'b0)
                    begin
                        delay_counter <= delay;
                        frames_counter <= frames_counter - 1'b1;
                    end
                    if (checking) // checking the location of the next tail bit
                    begin
                        case(retrieving)
                            2'b00: begin // check left block
                                    if (!ram_buffer)
                                    begin
                                        wren <= 0;
                                        addr <= tail_left_addr;
                                        ram_buffer <= 1'b1;
                                    end
                                    else
                                    begin
                                        if (ram_out == SNAKE_COLOUR)
                                        begin
                                            next_tail_x <= tail_x - 1'b1;
                                            next_tail_y <= tail_y;
                                        end
                                        ram_buffer <= 1'b0;
                                    end
                                    retrieving <= retrieving + 1'b1;
                                end
                            2'b01: begin // check right block
                                    if (!ram_buffer)
                                    begin
                                        wren <= 0;
                                        addr <= tail_right_addr;
                                        ram_buffer <= 1'b1;
                                    end
                                    else
                                    begin
                                        if (ram_out == SNAKE_COLOUR)
                                        begin
                                            next_tail_x <= tail_x + 1'b1;
                                            next_tail_y <= tail_y;
                                        end
                                        ram_buffer <= 1'b0;
                                    end
                                    retrieving <= retrieving + 1'b1;
                                end
                            2'b10: begin // check top block
                                    if (!ram_buffer)
                                    begin
                                        wren <= 0;
                                        addr <= tail_top_addr;
                                        ram_buffer <= 1'b1;
                                    end
                                    else
                                    begin
                                        if (ram_out == SNAKE_COLOUR)
                                        begin
                                            next_tail_x <= tail_x;
                                            next_tail_y <= tail_y - 1'b1;
                                        end
                                        ram_buffer <= 1'b0;
                                    end
                                    retrieving <= retrieving + 1'b1;
                                end
                            2'b11: begin // check bottom block
                                    if (!ram_buffer)
                                    begin
                                        wren <= 0;
                                        addr <= tail_bottom_addr;
                                        ram_buffer <= 1'b1;
                                    end
                                    else
                                    begin
                                        if (ram_out == SNAKE_COLOUR)
                                        begin
                                            next_tail_x <= tail_x;
                                            next_tail_y <= tail_y - 1'b1;
                                        end
                                        ram_buffer <= 1'b0;
                                    end
                                    retrieving <= 0;
                                    checking <= 0;
                                end
                        endcase
                    end
                end
            end

    end

endmodule

module control(
    input go,
    input alive,
    input resetn,
	 input clock,
    output reg play,
    output reg init,
	 output [1:0] current_s,
	 output [1:0] next_s
    );

    localparam  S_START      = 2'b0,
                S_INIT       = 2'b1,
                S_PLAY       = 2'b10;

    reg [1:0] current_state, next_state;
	 assign current_s = current_state;
	 assign next_s = next_state;

    always @(*)
    begin: state_table
        case(current_state)
            S_START:  next_state = go ? S_INIT : S_START;
            S_INIT:   next_state = go ? S_INIT : S_PLAY;
            S_PLAY:   next_state = alive ? S_PLAY : S_START;
            default : next_state = S_START;
        endcase
    end

    always @(*)
    begin: enable_signals
        case(current_state)
            S_START: begin
                init <= 1'b0;
                play <= 1'b0;
                end
            S_INIT: begin
                init <= 1'b1;
                play <= 1'b1;
                end
            S_PLAY: begin
                init <= 1'b0;
                play <= 1'b1;
                end
        endcase
    end

    always @(posedge clock)
    begin: state_FFs
        if(!resetn)
        begin
            current_state <= S_START;
        end
        else
        begin
            current_state <= next_state;
        end
    end
endmodule


module convert_directions(
    input up,
    input down,
    input left,
    input right,
    input resetn,
    input clock,

    output reg [1:0] direction
    );

    reg cur_up;
    reg cur_down;
    reg cur_left;
    reg cur_right;

    always @(posedge clock)
    begin
        if (!resetn)
        begin
            cur_up <= 0;
            cur_down <= 0;
            cur_left <= 0;
            cur_right <= 1'b1;
            direction <= 2'b01; // reset to going right
        end
        else
        begin
            if (up && !cur_down)
            begin
                cur_up <= 1'b1;
                cur_down <= 0;
                cur_left <= 0;
                cur_right <= 0;
                direction <= 2'b10;
            end
            else if (down && !cur_up)
            begin
                cur_up <= 0;
                cur_down <= 1'b1;
                cur_left <= 0;
                cur_right <= 0;
                direction <= 2'b11;
            end
            else if (left && !cur_right)
            begin
                cur_up <= 0;
                cur_down <= 0;
                cur_left <= 1'b1;
                cur_right <= 0;
                direction <= 2'b00;
            end
            else if (right && !cur_left)
            begin
                cur_up <= 0;
                cur_down <= 0;
                cur_left <= 0;
                cur_right <= 1'b1;
                direction <= 2'b01;
            end
        end
    end

endmodule
