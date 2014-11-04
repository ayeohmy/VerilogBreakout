/* Breakout: Verilog Style
 * @author: Audrey Yeoh, Tanguy Dauphin
 * @brief: To make Breakout in Verilog for 18-240 LabB
 */

/////////////////////////// BUTTON MODULE /////////////////////////////

module checkButton
	(input logic reset, 
	 input logic clock,
	 input logic button, 
	 output logic [1:0] buttonPress);
	 
	enum logic [1:0] {notPressed, pressed, held, released} state, nextState;
	
    always_comb begin 
        case (state)
            notPressed: begin 
					if (button == 0) nextState = pressed;
					else nextState = notPressed;
            end

            pressed: begin
                nextState = held;     
            end

            held: begin
                if(button == 1) nextState = released;
                else nextState = held;
            end
				
				released: begin
					nextState = notPressed;
				end
				
            default: 
                nextState = (~reset) ? state : notPressed;
        endcase
    end
	 
	always_comb begin
		unique case(state)
			notPressed: 
				buttonPress = 0;
			pressed:
				buttonPress = 1;
			held:
				buttonPress = 2;
			released:
				buttonPress = 3;
		endcase
	end

    always_ff @(posedge clock)
        if(reset) state <= notPressed;
        else state <= nextState;

endmodule: checkButton

/////////////////////////// COLOUR MODULE /////////////////////////////

module colour
	(input logic CLOCK_50, reset
	 input logic [8:0] row,
	 input logic [9:0] col,
	output logic [7:0] red, green, blue);

	logic [4:0] brick; // which brick is being looked at?
	logic paddle, wall;
	// logic ball;											// TODO~

	bricks BR (CLOCK_50, reset, row, col, brick);
	paddle PAD (CLOCK_50, reset, row, col, paddle);
	wall WAL (CLOCK_50, reset, row, col, wall);
	// ball BAL (CLOCK_50, reset, row, col, ball);			// TODO~

	always_comb begin
		if (wall) begin
			red = 8'hCC;
			green = 8'hCC;
			blue = 8'hCC;
		end
		else if (brick) begin
			if(brick[0]) begin
				red = 8'hFF;
				green = 8'hFF;
				blue = 8'h00;
			end
			else begin
				red = 8'hFF;
				green = 8'h00;
				blue = 8'hFF;
			end
		end
		else if (paddle) begin
			red = 8'h00;
			green = 8'hFF;
			blue = 8'h00;
		end
		// else if (ball) begin								// TODO~

		// end
		else begin
			red = 8'hFF;
			green = 8hFF;
			blue = 8'hFF;
		end

	end

endmodule: colour

/////////////////////////// OBJECT MODULE /////////////////////////////

// This module instantiates all the bricks
// It returns which brick it's on, if there is a brick
// No brick = 0 | brokenBrick = 0 | topRow = 1 2 3 4 5 6 | bottomRow = 8 9 10 11 12 13
module bricks
	(input logic CLOCK_50, reset
	 input logic [8:0] row,
	 input logic [9:0] col,
	output logic [4:0] brick);

	logic brick0, brick1, brick2, brick3, brick4, brick5, brick6, brick7, brick8, brick9, brickA, brickB;

	// top row 
	brick #( 40, 100, 100, 30) b0(CLOCK_50, reset, row, col, brick0); 
	brick #(140, 100, 100, 30) b1(CLOCK_50, reset, row, col, brick1); 
	brick #(240, 100, 100, 30) b2(CLOCK_50, reset, row, col, brick2); 
	brick #(340, 100, 100, 30) b3(CLOCK_50, reset, row, col, brick3); 
	brick #(440, 100, 100, 30) b4(CLOCK_50, reset, row, col, brick4); 
	brick #(540, 100, 50, 30) b5(CLOCK_50, reset, row, col, brick5); 
	// 2nd row 
	brick #( 40, 150, 50, 30) b6(CLOCK_50, reset, row, col, brick6); 
	brick #( 90, 150, 100, 30) b7(CLOCK_50, reset, row, col, brick7); 
	brick #(190, 150, 100, 30) b8(CLOCK_50, reset, row, col, brick8); 
	brick #(290, 150, 100, 30) b9(CLOCK_50, reset, row, col, brick9); 
	brick #(390, 150, 100, 30) bA(CLOCK_50, reset, row, col, brickA); 
	brick #(490, 150, 100, 30) bB(CLOCK_50, reset, row, col, brickB); 

	always_comb begin
		if(brick0)
			brick = 1;
		if(brick1)
			brick = 2;
		if(brick2) 
			brick = 3;
		if(brick3)
			brick = 4;
		if(brick4)
			brick = 5;
		if(brick5)
			brick = 6;
		if(brick6) 
			brick = 8;
		if(brick7)
			brick = 9;
		if(brick8)
			brick = 10;
		if(brick9)
			brick = 11;
		if(brickA)
			brick = 12;
		if(brickB)
			brick = 13;
	end
endmodule: bricks

module brick
#(parameter LEFT = 40, TOP = 100, WIDTH = 100, HEIGHT = 30)
	(input logic CLOCK_50, reset
	 input logic [8:0] row,
	 input logic [9:0] col,
	output logic signal);

	logic withinRow, withinColumn;

	offset_check row (row, LEFT, WIDTH, withinRow);
	offset_check col (col, TOP, HEIGHT, withinColumn);

	// assign withinRow = (row >= LEFT && row <= (LEFT + WIDTH));
	// assign withinColumn = (col >= TOP && col <= (TOP + HEIGHT));

	assign signal = withinRow && withinColumn;

endmodule: brick

// This module checks whether a wall should be at the given row and column and outputs a signal
module wall
	(input logic CLOCK_50, reset
	 input logic [8:0] row,
	 input logic [9:0] col,
	output logic signal);

	logic leftWall, rightWall, topWall;
	logic leftWallRow, leftWallCol;
	logic rightWallRow, rightWallCol;
	logic topWallRow, topWallCol;

	range_check leftRow (row, 10, 469, leftWallRow);
	range_check leftCol (col, 20, 39, leftWallCol);
	range_check rightRow (row, 10, 469, rightWallRow);
	range_check rightCol (col, 590, 609, rightWallCol);
	range_check topRow (row, 10, 29, topWallRow);
	range_check topCol (col, 20, 609, topWallCol);

	assign leftWall = leftWallRow && leftWallCol;
	assign rightWall = rightWallRow && rightWallCol;
	assign topWall = topWallRow && topWallCol;

	//assign leftWall = (col >= 20 && col <= 39) && (row >= 10 && row <=469);
	//assign rightWall = (col >= 590 && col <= 609) && (row >= 10 && row <=469);
	//assign topWall = (row >= 10 && row <= 29) && (col >= 20 && col <= 609);

	assign signal = leftWall | rightWall | topWall;

endmodule: wall

// This module checks for whether the paddle should be present at the given row and col every game cycle 
// Returns a 1 signal if the paddle should be there
// ALSO, the module updates the position of the paddle each time
module paddle
	(input logic CLOCK_50, reset,
	 input logic [8:0] row,
	 input logic [9:0] col,
	 input left, right;
	output logic signal);

    logic [15:0] paddlePosition; // left column of paddle
    logic withinRow, within col;

    assign withinRow = (row >= 440 && row <= 459);
    assign withinCol = (col >= paddlePosition && col <= (paddlePosition+64)) && (col > 39 && col < 590);

    assign signal = withinRow && withinCol;

    always @(row == 480 && col == 640) begin // game clock period
        if(reset) begin 
            paddlePosition = (225+40)-(32); // middle of game area - half paddle width
        end
       	else if((left && right) || (~left && ~right))
       		paddlePosition = paddlePosition;
       	else if (left && ~right) begin
       		if(paddlePosition - 5 > 39)
       			paddlePosition = paddlePosition - 5;
        end
        else if (~left && right) begin
        	if(paddlePosition + 5 < 590)
        		paddlePosition = paddlePosition + 5;
        end
    end

endmodule: paddle


//////////////////////////// CHIP INTERFACE ///////////////////////////

module ChipInterface
    (input logic CLOCK_50,
     input logic [3:0] KEY,
     input logic [17:0] SW,
    output logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7,
    output logic [7:0] VGA_R, VGA_G, VGA_B,
    output logic VGA_BLANK_N, VGA_CLK, VGA_SYNC_N,
    output logic VGA_VS, VGA_HS);
    
    logic [8:0] row;
    logic [9:0] col;
    // logic not_red, not_green1, not_green2, not_blue1, not_blue2, not_blue3, not_blue4;
	logic blank;
	logic [7:0] red, green, blue;

    vga VGA (CLOCK_50, ~KEY[2], VGA_HS, VGA_VS, blank, row, col);
    
    /*range_check RED (col, 0, 319, not_red);
    range_check GREEN1 (col, 0, 159, not_green1);
    range_check GREEN2 (col, 320, 479, not_green2);
    range_check BLUE1 (col, 0, 79, not_blue1);
    range_check BLUE2 (col, 160, 239, not_blue2);
    range_check BLUE3 (col, 320, 399, not_blue3);
    range_check BLUE4 (col, 480, 559, not_blue4);*/

    assign VGA_SYNC_N = 0;
    assign VGA_CLK = ~CLOCK_50;
	assign VGA_BLANK_N = ~blank;
	 
	colour C (CLOCK_50, ~KEY[2], row, col, red, green, blue);
	assign VGA_R = red;
	assign VGA_G = green;
	assign VGA_B = blue;

    /*assign VGA_R = (not_red) ? 8'h00: 8'hFF;
    assign VGA_G = (not_green1 | not_green2) ? 8'h00: 8'hFF;
    assign VGA_B = (not_blue1 | not_blue2 | not_blue3 | not_blue4) ? 8'h00 : 8'hFF;*/

endmodule: ChipInterface



module vga_test;
    logic CLOCK_50, reset;
    logic HS, VS, blank;
    logic [8:0] row;
    logic [9:0] col;
    
    vga V (.*);
    
    logic [15:0] rowCount,count;

	assign rowCount = V.rowCount;
    assign count = V.clockCount;
    assign HDisp = V.Tdisp;
    assign VDisp = V.RTdisp;


    initial begin
        $monitor($time,, "HS = %b, VS = %b, blank = %b, row = %b, col = %b, reset = %b, clockCount = %b", HS, VS, blank, row, col, reset, V.clockCount);
        CLOCK_50 = 0;
        #5 CLOCK_50 = 1;
        #5 CLOCK_50 = 0;
        reset = 1;
        #5 CLOCK_50 = 0;
        #5 CLOCK_50 = 1;
        #5 CLOCK_50 = 0;       
        #5 reset = 0;
  
		forever #5 CLOCK_50 = ~CLOCK_50;
		  
    end
endmodule: vga_test


/////////////////////////////////// VGA STUFF /////////////////////////

// Here is the VGA module. It controls the wave and things
module vga 
    (input logic CLOCK_50, reset,
    output logic HS, VS, blank,
    output logic [8:0] row,
    output logic [9:0] col);

    logic [15:0] clockCount, rowCount, startTime, change;
    logic withinRow, withinClock;
    logic Tdisp, Tpw, Tfp, Tbp;
    logic RTpw, RTbp, RTdisp, RTfp;

    
    offset_check ROW (rowCount, 0, 520, withinRow);
    offset_check CLOCK (clockCount, 0, 1599, withinClock);
    offset_check TDISP (clockCount, 288, 1279, Tdisp);
    offset_check TPW (clockCount, 0, 191, Tpw);
	 offset_check RTPW (rowCount, 0, 1, RTpw);
	 offset_check RDISP (rowCount, 31, 479, RTdisp);


    assign row = rowCount;
    assign col = (clockCount-288)/2;
    assign VS = ~RTpw; 	// (RTpw) ? 0:1;
    assign HS = ~Tpw;	// (Tpw) ? 0:1;
    assign blank = ~(Tdisp && RTdisp); 	//(Tdisp && RTdisp) ? 0:1;

    always @(posedge CLOCK_50) begin
        if(reset) begin 
            clockCount = 0;
            rowCount = 0;
        end
        else if(~withinClock && ~withinRow) begin
            clockCount = 0;
            rowCount = 0;
        end
        else if(~withinClock) begin // new row
            clockCount = 0;
            rowCount = rowCount + 1;
        end
        else begin
            clockCount = clockCount + 1;
        end
    end
endmodule: vga

///////////////////////////////// END OF VGA ////////////////////////

// MODULE: RANGE_CHECK
// This module checks whether the value is between the given low and high values
// returns a 1 if true, 0 if not
module range_check
#(parameter WIDTH = 16)
    (input logic [WIDTH - 1: 0] val, low, high,
    output logic is_between);

    assign is_between = ((low <= val) && (high >= val)) ? 1 : 0;

endmodule: range_check


// MODULE: OFFSET_CHECK
// This module checks whether the value is between the low and the low + off_set
// it calls the range_check module to check the range once the values have been added
// returns a 1 if is, 0 if not
module offset_check
#(parameter WIDTH = 16)
    (input logic [WIDTH - 1: 0] val, low, delta,
    output logic is_between);
    
//    logic rangeCheckResult;
    logic [WIDTH-1:0] sum;
    assign sum = low + delta;
    range_check #(WIDTH) RC (val, low, sum, is_between);
    
    //assign is_between = (sum[WIDTH]) ? 0:rangeCheckResult;
    
endmodule: offset_check


///////////////// TEST MODULES FOR RANGE & OFFSET CHECK ///////////////////////////
// Note: to test the module, please use the vlogan method


// This module tests range check by running it through a bunch of test cases
module range_check_test;
    logic [15:0] val, low, high;
    logic is_between;

    range_check RC (.*);

    initial begin
        $monitor($time,, "val = %b | low = %b | high = %b | isBetween = %b", val, low, high, is_between);
        val = 0; // should return 1 because edge case: on low, on high
        low = 0;
        high = 0;

        // return 0: too high
        #10 val = 1;
        low = 0;
        high = 0;

        // return 1: normal valid
        #10 val = 1;
        low = 0;
        high = 2;

        // return 0: too low
        #10 val = 1;
        low = 2;
        high = 2;

        // return 1: on low
        #10 val = 2;
        low = 2;
        high = 3;

        // return 1: on high
        #10 val = 3;
        low = 2;
        high = 3;

        // return 1: Test the big numbers
        #10 val = 8'b1111_1111;
        low = 0;
        high = 8'b1111_1111;

        // return 0: Test fail on big numbers
        #10 val = 8'b1111_1111;
        low = 8'b1111_0000;
        high = 8'b1111_1110;

    end
endmodule: range_check_test


// This module tests offset_check. 
module offset_check_test;
    logic [15:0] val, low, delta;
    logic is_between;

    offset_check OC (.*);

    initial begin
        $monitor($time,, "val = %b | low = %b | delta = %b | sum = %b | isBetween = %b", val, low, delta, OC.sum, is_between);
        // return 1: true case
        val = 2;
        low = 0;
        delta = 3;

        // return 0: too high
        #10 val = 3;
        low = 0;
        delta = 2;

        // return 0: too low
        #10 val = 0;
        low = 2;
        delta = 1;

        // return 1: on low
        #10 val = 2;
        low = 2;
        delta = 3;

        // return 1: on high
        #10 val = 3;
        low = 1;
        delta = 2;

        // return 0: test overflow cases
        #10 val = 3;
        low = 3;
        delta = 8'b1111_1111;

        // return 1: test high cases
        #10 val = 8'b1111_1111;
        low = 0;
        delta = 8'b1111_1111;

    end
endmodule: offset_check_test




