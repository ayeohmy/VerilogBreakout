/* Breakout: Verilog Style
 * @author: Audrey Yeoh, Tanguy Dauphin
 * @brief: To make Breakout in Verilog for 18-240 LabB
 */

`default_nettype null


/////////////////////////// GAME CLOCK MODULE /////////////////////////

module gameClockModule
	(input logic CLOCK_50, reset,
	 input logic [8:0] row,
	 input logic [9:0] col,
	output logic gameClock);

	assign gameClock = (~reset) && (row == 480) && (col == 640);

endmodule: gameClockModule



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

///////////////////////// SEVEN DIGIT THINGY ///////////////////////
module BCDtoSevenSegment
  (input logic [3:0] bcd,
   output logic [6:0] segment);
   always_comb 
     case ({bcd[3], bcd[2], bcd[1], bcd[0]})
       4'b0000: segment = 7'b100_0000;
       4'b0001: segment = 7'b111_1001;
       4'b0010: segment = 7'b010_0100;
       4'b0011: segment = 7'b011_0000;
       4'b0100: segment = 7'b001_1001;
       4'b0101: segment = 7'b001_0010;
       4'b0110: segment = 7'b000_0010;
       4'b0111: segment = 7'b111_1000;
       4'b1000: segment = 7'b000_0000;
       4'b1001: segment = 7'b001_0000;
       default: segment = 7'b111_1111;
     endcase // case ({bcd[3], bcd[2], bcd[1], bcd[0]})
endmodule: BCDtoSevenSegment

module SevenSegmentDigit
   (input  logic [3:0] bcd,
    output logic [6:0] segment,
    input  logic       blank);

   logic [6:0]       decoded;

   BCDtoSevenSegment b2ss(bcd, decoded);
   
   always_comb begin
      if (blank == 1)
			segment = 7'b111_1111;
      else
			segment = decoded;
   end
  

endmodule: SevenSegmentDigit

/////////////////////////// COLOUR MODULE /////////////////////////////

module colour
	(input logic CLOCK_50, gameClock, reset,
	 input logic [8:0] row,
	 input logic [9:0] col,
	 input logic left, right, start,
	 output logic [7:0] red, green, blue,
	 output logic [6:0] HEX6,
	 output logic [11:0] led);

	logic [8:0] bRow;
	logic [9:0] bCol;
	logic [11:0] brickTracker, bricksHit;
	logic [2:0] dx, dy;
	logic isBall, isPaddle, isWall;
	logic [11:0] brickIndex, hitBrickLeft, hitBrickRight, hitBrickTop, hitBrickBottom;
	logic hitPaddleLeft, hitPaddleRight, hitPaddleTop;
	logic hitLeftWall, hitRightWall, hitTopWall;
	logic [2:0] gameState;
	logic [1:0] lifes;

	ball B (CLOCK_50, gameClock, reset, row, col, dx, dy, gameState, isBall, bRow, bCol);
	paddle P (CLOCK_50, gameClock, reset, row, col, bRow, bCol, left, right, hitPaddleLeft, hitPaddleRight, hitPaddleTop, isPaddle);
	wall W (CLOCK_50, gameClock, reset, row, col, bRow, bCol, hitLeftWall, hitRightWall, hitTopWall, isWall);
	bricks BR (CLOCK_50, gameClock, reset, row, col, bRow, bCol, hitBrickTop, hitBrickBottom, hitBrickLeft, hitBrickRight, brickIndex);
	velocity V (CLOCK_50, gameClock, reset, gameState, hitPaddleTop, hitPaddleLeft, hitPaddleRight, hitBrickTop, hitBrickBottom, hitBrickLeft, hitBrickRight, hitLeftWall, hitRightWall, hitTopWall, brickTracker, dx, dy);

	score S (bRow, bCol, brickTracker, start, gameState, lifes, HEX6);
	
	assign bricksHit = (~brickTracker) & brickIndex;

	// Colour Setting
	always_comb begin
		if (isWall && (gameState == 4)) begin
			red = 8'h7C;
			green = 8'h00;
			blue = 8'h00;
		end
		else if (isWall && (gameState == 5)) begin
			red = 8'h00;
			green = 8'h70;
			blue = 8'hB0;
		end
		else if(isWall) begin
			red = 8'hCC;
			green = 8'hCC;
			blue = 8'hCC;
		end
		else if(isBall && (gameState != 4 || gameState != 5)) begin
			red = 8'hFF;
			green = 8'hFF;
			blue = 8'hFF;		end
		else if(isPaddle) begin
			red = 8'h00;
			green = 8'hFF;
			blue = 8'h00;
		end
		else if(bricksHit) begin 
			// no problem because the brickIndex only returns 1 brick at a time
			/*if (brickHit[0] || brickHit[2] || brickHit[4] || brickHit[7] || brickHit[9] || brickHit[11]) begin
				red = 8'hFF;
				green = 8'hff;
				blue = 8'h00;
			end
			else begin
				red = 8'hFF;
				green = 8'h00;
				blue = 8'hFF;
			end */

	        case ({brickHit})
	          	12'b000000_000000: segment = 7'b100_0000; //test all the different decimals
	          	12'b000000_000001: begin
					red = 8'hFF;
					green = 8'hff;
					blue = 8'h00;
	          	end
	          	12'b000000_000100: begin
					red = 8'hFF;
					green = 8'hff;
					blue = 8'h00;
	          	end
	          	12'b000000_010000: begin
					red = 8'hFF;
					green = 8'hff;
					blue = 8'h00;
	          	end
	          	12'b000010_000000: begin
					red = 8'hFF;
					green = 8'hff;
					blue = 8'h00;
	          	end
	          	12'b001000_000000: begin
					red = 8'hFF;
					green = 8'hff;
					blue = 8'h00;
	          	end
	          	12'b100000_000000: begin
					red = 8'hFF;
					green = 8'hff;
					blue = 8'h00;
	          	end
	          	default: begin
					red = 8'hFF;
					green = 8'h00;
					blue = 8'hFF;
	          	end
	        endcase
		end
		else begin	// rest of screen
			red = 8'h00;
			green = 8'h00;
			blue = 8'h00;	
		end
	end

	always_ff @(posedge CLOCK_50, posedge reset) begin
		if (reset) begin
			brickTracker <= 12'h0;
		end
		else if (gameClock) begin
			if (gameState == 0) begin
				brickTracker = 12'h0;
			end
			else begin
			brickTracker <= brickTracker | hitBrickLeft | hitBrickRight | hitBrickTop | hitBrickBottom;
			end
		end
	end

endmodule: colour
////////////////////////// SCORE MODULE ///////////////////////////////
module score 
	(input logic [8:0] bRow,
	 input logic [9:0] bCol,
	 input logic [11:0] brickTracker,
	 input logic startKey,
	output logic [2:0] gameState, 
	output logic [1:0] lifes,
	output logic [6:0] HEX6);

	enum logic [1:0] {resetted, threeLifes, twoLifes, oneLife, lose, win} state, nextState;
	logic inScreen, start, won;

	checkButton B1 (reset, gameClock, ~startKey, start); // I think we need it to be on gameClock

	range_check ballOff (ballRow, 10, 479, inScreen);
	assign won = !(~brickTracker);

	always_comb begin
		case(state)
			resetted: begin
				if (start == 2) nextState = threeLifes; // released button
				else nextState = resetted;
			end
			threeLifes: begin
				if(!inScreen) nextState = twoLifes;
				else if (won) nextState = win;
				else nextState = threeLifes;
			end
			twoLifes: begin
				if(!inScreen) nextState = oneLife;
				else if (won) nextState = win;
				else nextState = twoLifes;
			end
			oneLife: begin
				if(!inScreen) nextState = lose;
				else if (won) nextState = win;
				else nextState = oneLife;
			end
			lose: begin
				if(start == 3) nextState = resetted;
				else nextState = lose;
			end
			win: begin
				if(start == 3) nextState = resetted;
				else nextState = lose;
			end
	end

	always_com begin
		unique case(state)
			resetted: gameState = 0;
			threeLifes: gameState = 1;
			twoLifes: gameState = 2;
			oneLife: gameState = 3;
			lose: gameState = 4;
			win: gameState = 5;
		endcase
	end

	SevenSegmentDigit SSD (life, HEX6, 0);

	always_ff @(posedge CLOCK_50, posedge reset) begin
		if(reset) begin
			life <= 3;
			state <= resetted;
		end
		else begin
			else if(gameClock) begin
				if(state == threeLifes) life <= 3;
				else if (state == twoLifes) life <= 2;
				else if (state == oneLife) life <= 1;
				else if (state == lose) life <= 0;
				else if (state == win) life <= life;
				else if (state == resetted) life <= 3;
				else life <= 3;
			end
			state <= nextState;
		end
	end
endmodule: score

/////////////////////////// VELOCITY MODULE ///////////////////////////
module velocity
	(input logic CLOCK_50, gameClock, reset,
	 input logic [2:0] gameState,
	 input logic hitPaddleTop, hitPaddleLeft, hitPaddleRight,
	 input logic [11:0] hitBrickTop, hitBrickBottom, hitBrickLeft, hitBrickRight,
	 input logic hitLeftWall, hitRightWall, hitTopWall, 
	 input logic [11:0] brickTracker,
	 output logic [2:0] dx, dy);

	logic [2:0] dx, dy;
	logic moveLeft, moveRight, moveUp, moveDown;

	assign moveLeft = (hitBrickLeft && (~brickTracker)) || hitRightWall || hitPaddleLeft;
	assign moveRight (hitBrickRight && (~brickTracker)) || hitLeftWall || hitPaddleRIght;
	assign moveUp = (hitBrickTop && (~brickTracker)) || hitPaddleTop;
	assign moveDown = (hitBrickBottom && (~brickTracker)) || hitTopWall;


	always_ff @(posedge CLOCK_50, posedge reset) begin
		if(reset) begin
			dx <= 0; // changes columns (left - right)
			dy <= 0; // changes rows (up - down)
		end
		else if(gameClock) begin
			if(gameState == 1 || gameState == 2 || gameState == 3)
				if(moveUp) begin
					dy <= -2;
				end 
				else if(moveDown) begin
					dy <= 2;
				end
				else if(moveLeft) begin
					dx <= -1;
				end
				else if(moveRight) begin
					dx <= 1;
				end

				else begin
					dy <= dy;
					dx <= dx;
				end
			end				
			else if (gameState == 0) begin 
				// initialize the velocity (but don't move)
				dx <= 1;
				dy <= 2; 
			end
			else begin
				dx <= 0;
				dy <= 0;
			end
		end
	end
endmodule: velocity

/////////////////////////// OBJECT MODULE /////////////////////////////

// This module instantiates all the bricks
// It returns which brick it's on, if there is a brick
module bricks
	(input logic CLOCK_50, gameClock, reset,
	 input logic [8:0] row,
	 input logic [9:0] col,
	 input logic [8:0] brow,
	 input logic [9:0] bcol,
	output logic [11:0] hitBrickTop, hitBrickBottom, hitBrickLeft, hitBrickRight,
	output logic [11:0] brick);

	// top row 
	brick #( 40, 100, 100, 30) b0(CLOCK_50, gameClock, reset, row, col, brick[0]); 
	brick #(140, 100, 100, 30) b1(CLOCK_50, gameClock, reset, row, col, brick[1]); 
	brick #(240, 100, 100, 30) b2(CLOCK_50, gameClock, reset, row, col, brick[2]); 
	brick #(340, 100, 100, 30) b3(CLOCK_50, gameClock, reset, row, col, brick[3]); 
	brick #(440, 100, 100, 30) b4(CLOCK_50, gameClock, reset, row, col, brick[4]); 
	brick #(540, 100, 50, 30) b5(CLOCK_50, gameClock, reset, row, col, brick[5]); 
	// 2nd row 
	brick #( 40, 150, 50, 30) b6(CLOCK_50, gameClock, reset, row, col, brick[6]); 
	brick #( 90, 150, 100, 30) b7(CLOCK_50, gameClock, reset, row, col, brick[7]); 
	brick #(190, 150, 100, 30) b8(CLOCK_50, gameClock, reset, row, col, brick[8]); 
	brick #(290, 150, 100, 30) b9(CLOCK_50, gameClock, reset, row, col, brick[9]); 
	brick #(390, 150, 100, 30) bA(CLOCK_50, gameClock, reset, row, col, brick[10]); 
	brick #(490, 150, 100, 30) bB(CLOCK_50, gameClock, reset, row, col, brick[11]); 

	////////////////////////// Top Row Bottom Hit
	brick #( 40, 125, 105, 5) bb0(CLOCK_50, gameClock, reset, brow, bcol, hitBrickBottom[0]);
	brick #( 140, 125, 105, 5) bb1(CLOCK_50, gameClock, reset, brow, bcol, hitBrickBottom[1]); 
	brick #( 240, 125, 105, 5) bb2(CLOCK_50, gameClock, reset, brow, bcol, hitBrickBottom[2]);
	brick #( 340, 125, 105, 5) bb3(CLOCK_50, gameClock, reset, brow, bcol, hitBrickBottom[3]);
	brick #( 440, 125, 105, 5) bb4(CLOCK_50, gameClock, reset, brow, bcol, hitBrickBottom[4]);
	brick #( 540, 125, 45, 5) bb5(CLOCK_50, gameClock, reset, brow, bcol, hitBrickBottom[5]);
	////////////////////////// Bottom Row Bottom Hit
	brick #( 40, 175, 55, 5) bb6(CLOCK_50, gameClock, reset, brow, bcol, hitBrickBottom[6]);
	brick #( 90, 175, 105, 5) bb7(CLOCK_50, gameClock, reset, brow, bcol, hitBrickBottom[7]); 
	brick #( 190, 175, 105, 5) bb8(CLOCK_50, gameClock, reset, brow, bcol, hitBrickBottom[8]);
	brick #( 290, 175, 105, 5) bb9(CLOCK_50, gameClock, reset, brow, bcol, hitBrickBottom[9);
	brick #( 390, 175, 105, 5) bb10(CLOCK_50, gameClock, reset, brow, bcol, hitBrickBottom[10]);
	brick #( 490, 175, 95, 5) bb11(CLOCK_50, gameClock, reset, brow, bcol, hitBrickBottom[11]);

	//////////////////////// Top Row Top Hit
	brick #( 40, 95, 105, 5) bt0(CLOCK_50, gameClock, reset, brow, bcol, hitBrickTop[0]);
	brick #( 140, 95, 105, 5) bt1(CLOCK_50, gameClock, reset, brow, bcol, hitBrickTop[1]); 
	brick #( 240, 95, 105, 5) bt2(CLOCK_50, gameClock, reset, brow, bcol, hitBrickTop[2]);
	brick #( 340, 95, 105, 5) bt3(CLOCK_50, gameClock, reset, brow, bcol, hitBrickTop[3]);
	brick #( 440, 95, 105, 5) bt4(CLOCK_50, gameClock, reset, brow, bcol, hitBrickTop[4]);
	brick #( 540, 95, 45, 5) bt5(CLOCK_50, gameClock, reset, brow, bcol, hitBrickTop[5]);
	////////////////////// Bottom Row Top Hit
	brick #( 40, 145, 55, 5) bt6(CLOCK_50, gameClock, reset, brow, bcol, hitBrickTop[6]);
	brick #( 90, 145, 105, 5) bt7(CLOCK_50, gameClock, reset, brow, bcol, hitBrickTop[7]); 
	brick #( 190, 145, 105, 5) bt8(CLOCK_50, gameClock, reset, brow, bcol, hitBrickTop[8]);
	brick #( 290, 145, 105, 5) bt9(CLOCK_50, gameClock, reset, brow, bcol, hitBrickTop[9);
	brick #( 390, 145, 105, 5) bt10(CLOCK_50, gameClock, reset, brow, bcol, hitBrickTop[10]);
	brick #( 490, 145, 95, 5) bt11(CLOCK_50, gameClock, reset, brow, bcol, hitBrickTop[11]);	

	//////////////////////// Top Row Left Hit
	// can never hit the left most brick from the left
	brick #( 0, 0, 0, 0) bt0(CLOCK_50, gameClock, reset, brow, bcol, hitBrickLeft[0]);
	brick #( 135, 95, 5, 35) bl1(CLOCK_50, gameClock, reset, brow, bcol, hitBrickLeft[1]); 
	brick #( 235, 95, 5, 35) bl2(CLOCK_50, gameClock, reset, brow, bcol, hitBrickLeft[2]);
	brick #( 335, 95, 5, 35) bl3(CLOCK_50, gameClock, reset, brow, bcol, hitBrickLeft[3]);
	brick #( 435, 95, 5, 35) bl4(CLOCK_50, gameClock, reset, brow, bcol, hitBrickLeft[4]);
	brick #( 535, 95, 5, 35) bl5(CLOCK_50, gameClock, reset, brow, bcol, hitBrickLeft[5]);
	////////////////////// Bottom Row Left Hit
	brick #( 0, 0, 0, 0) bl6(CLOCK_50, gameClock, reset, brow, bcol, hitBrickLeft[6]);
	brick #( 85, 145, 5, 35) bl7(CLOCK_50, gameClock, reset, brow, bcol, hitBrickLeft[7]); 
	brick #( 185, 145, 5, 35) bl8(CLOCK_50, gameClock, reset, brow, bcol, hitBrickLeft[8]);
	brick #( 285, 145, 5, 35) bl9(CLOCK_50, gameClock, reset, brow, bcol, hitBrickLeft[9);
	brick #( 385, 145, 5, 35) bl10(CLOCK_50, gameClock, reset, brow, bcol, hitBrickLeft[10]);
	brick #( 485, 145, 5, 35) bl11(CLOCK_50, gameClock, reset, brow, bcol, hitBrickLeft[11]);

	//////////////////////// Top Row Right Hit
	// can never hit the right most brick from the right
	brick #( 140, 95, 5, 35) br0(CLOCK_50, gameClock, reset, brow, bcol, hitBrickRight[0]);
	brick #( 240, 95, 5, 35) br1(CLOCK_50, gameClock, reset, brow, bcol, hitBrickRight[1]); 
	brick #( 340, 95, 5, 35) br2(CLOCK_50, gameClock, reset, brow, bcol, hitBrickRight[2]);
	brick #( 440, 95, 5, 35) br3(CLOCK_50, gameClock, reset, brow, bcol, hitBrickRight[3]);
	brick #( 540, 95, 5, 35) br4(CLOCK_50, gameClock, reset, brow, bcol, hitBrickRight[4]);
	brick #( 0, 0, 0, 0) br5(CLOCK_50, gameClock, reset, brow, bcol, hitBrickRight[5]);
	////////////////////// Bottom Row Right4 Hit
	brick #( 90, 145, 5, 35) br6(CLOCK_50, gameClock, reset, brow, bcol, hitBrickRight[6]);
	brick #( 190, 145, 5, 35) br7(CLOCK_50, gameClock, reset, brow, bcol, hitBrickRight[7]); 
	brick #( 290, 145, 5, 35) br8(CLOCK_50, gameClock, reset, brow, bcol, hitBrickRight[8]);
	brick #( 390, 145, 5, 35) br9(CLOCK_50, gameClock, reset, brow, bcol, hitBrickRight[9);
	brick #( 490, 145, 5, 35) br10(CLOCK_50, gameClock, reset, brow, bcol, hitBrickRight[10]);
	brick #( 0, 0, 0, 0) br11(CLOCK_50, gameClock, reset, brow, bcol, hitBrickRight[11]);

endmodule: bricks

module brick
#(parameter LEFT = 40, TOP = 100, WIDTH = 100, HEIGHT = 30)
	(input logic CLOCK_50, gameClock, reset,
	 input logic [8:0] row,
	 input logic [9:0] col,
	output logic signal);

	logic withinRow, withinColumn;

	offset_check R (col, LEFT, WIDTH, withinColumn);
	offset_check C (row, TOP, HEIGHT, withinRow);

	assign signal = withinRow && withinColumn;

endmodule: brick

// This module checks whether a wall should be at the given row and column and outputs a signal
module wall
	(input logic CLOCK_50, gameClock, reset,
	 input logic [8:0] row,
	 input logic [9:0] col,
	 input logic [8:0] bRow, 
	 input logic [9:0] bCol,
	output logic hitLeftWall, hitRightWall, hitTopWall,
	output logic signal);

	// check if wall is at VGA row and col
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
	assign signal = leftWall | rightWall | topWall;

	// check if the ball has hit the wall
	logic bLeftWall, bRightWall, bTopWall;
	logic bLeftWallRow, bLeftWallCol;
	logic bRightWallRow, bRightWallCol;
	logic bTopWallRow, bTopWallCol;
	range_check bleftRow (bRow, 10, 469, bLeftWallRow);
	range_check bleftCol (bCol, 20, 39, bLeftWallCol);
	range_check brightRow (bRow, 10, 469, bRightWallRow);
	range_check brightCol (bCol, 590 - 5, 609, bRightWallCol);
	range_check btopRow (bRow, 10, 29, bTopWallRow);
	range_check btopCol (bCol, 40, 590-5, bTopWallCol);
	assign hitLeftWall = bLeftWallRow && bLeftWallCol;
	assign bRightWall = bRightWallRow && bRightWallCol;
	assign bTopWall = bTopWallRow && bTopWallCol;

endmodule: wall

// This module checks for whether the paddle should be present at the given row and col every game cycle 
// Returns a 1 signal if the paddle should be there
// ALSO, the module updates the position of the paddle each game cycle
module paddle
	(input logic CLOCK_50, gameClock, reset,
	 input logic [8:0] row,
	 input logic [9:0] col,
	 input logic [8:0] bRow,
	 input logic [9:0] bCol,
	 input logic left, right,
	output logic hitPaddleLeft, hitPaddleRight, hitPaddleTop,
	output logic signal);

    logic [9:0] paddlePosition; // left column of paddle

	// check if paddle at VGA row and column
	logic withinRow, withinCol;
    assign withinRow = (row >= 440 && row <= 459);
    assign withinCol = (col >= paddlePosition && col <= (paddlePosition+64)) && (col > 39 && col < (590));
    assign signal = withinRow && withinCol;
	
	// check for paddle hits: top has precedence?
	logic withinTop, withinHeight, withinTopHeight, withinLeft, withinRight;
	range_check T (bCol, paddlePosition-5, paddlePosition + 64, withinTop);
	range_check TH (bRow, 440 - 5, 440 + 5, withinTopHeight);
	assign hitPaddleTop = withinTop && withinTopHeight;
	range_check L (bCol, paddlePosition - 5, paddlePosition + 5, withinLeft);
	range_check H (bRow, 440 - 5, 459, withinHeight);
	assign hitPaddleLeft = withinLeft && withinHeight;
	range_check R (bCol, paddlePosition + 64 - 5, paddlePosition + 64, withinRight);
	assign hitPaddleRight = withinRight && withinHeight;

    always_ff @(posedge CLOCK_50, posedge reset) begin // game clock period
		if(reset) begin 
		    paddlePosition <= (275+40)-(32); // middle of game area - half paddle width
		end
		else if(gameClock) begin
			if((left && right) || (~left && ~right)) begin
					paddlePosition <= paddlePosition;
			end
			else if (left && ~right) begin
					if(paddlePosition - 5 > 39) begin
							paddlePosition <= paddlePosition - 5;
					end
					else begin
						paddlePosition <= paddlePosition;
					end
			end
			else if (~left && right) begin
				if(paddlePosition + 64 + 5 < 590) begin
					paddlePosition <= paddlePosition + 5;
				end
				else begin
					paddlePosition <= paddlePosition;
				end
			end
			else begin
					paddlePosition <= paddlePosition;
			end
		end
	 end

endmodule: paddle


// This is the ball module. It just handles the ball positioning and signaling 
// where the ball is
module ball
	(input logic CLOCK_50, gameClock, reset,
	 input logic [8:0] row,
	 input logic [9:0] col,
	 input logic [2:0] dx, dy,
	 input logic [2:0] gameState,
	output logic isBall,
	output logic [8:0] bRow,
	output logic [9:0] bCol);		

	assign isBall = ((row >= ballRow) && (row < ballRow + 4) && (col >= ballCol) && (col < ballCol + 4));

   always_ff @(posedge CLOCK_50, posedge reset) begin // game clock period
        if(reset) begin
        	bRow <= 420;
        	bCol <= 400;	
        end		  
		else if(gameClock) begin	
			if(gameState == 0) begin
				bRow <= 420;
				bRow <= 400;
			end else begin
				bRow <= bRow + dy;
				bCol <= bCol + dx;
			end
		end
	 end
endmodule: ball


//////////////////////////// CHIP INTERFACE ///////////////////////////

module ChipInterface
    (input logic CLOCK_50,
     input logic [3:0] KEY,
     input logic [17:0] SW,
	 output logic [17:0] LEDR,
    output logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7,
    output logic [7:0] VGA_R, VGA_G, VGA_B,
    output logic VGA_BLANK_N, VGA_CLK, VGA_SYNC_N,
    output logic VGA_VS, VGA_HS);
    
    logic [8:0] row;
    logic [9:0] col;
    // logic not_red, not_green1, not_green2, not_blue1, not_blue2, not_blue3, not_blue4;
	logic blank;
	logic [7:0] red, green, blue;
	logic right, left, start, rst;
	logic gameClock;

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

	checkButton B0 (reset, CLOCK_50, KEY[0], right);
	checkButton B3 (reset, CLOCK_50, KEY[3], left);
	checkButton B1 (reset, CLOCK_50, KEY[1], start);
	checkButton B2 (reset, CLOCK_50, KEY[2], rst);

	gameClockModule GCM (CLOCK_50, rst, row, col, gameClock);
	 
	colour C (CLOCK_50, gameClock, rst, row, col, ~KEY[3], ~KEY[0], ~KEY[1], red, green, blue, HEX6, LEDR[11:0]);
	assign VGA_R = (row == 0 || row == 479 || col == 0 || col == 639) ? 8'h10 : red;
	assign VGA_G = (row == 0 || row == 479 || col == 0 || col == 639) ? 8'h10 : green;
	assign VGA_B = (row == 0 || row == 479 || col == 0 || col == 639) ? 8'h10 : blue;
	
	
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


    assign row = rowCount - 31;
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

    assign is_between = ((low <= val) && (high >= val));

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



module register
    #(parameter WIDTH = 10)
    (input logic [WIDTH-1:0] D,
    input logic clear, en,
    input logic clock,
    output logic [WIDTH-1:0] Q);

    always @(posedge clock) begin
        if (clear) Q <= 0;
        else if (en) Q <= D;
        else Q <= Q;
    end
endmodule: register

module register_test();
    logic [7:0] D;
    logic clear, en, clock;
    logic [7:0] Q;

    register #(8) r (.*);

    initial begin
        $monitor("D = %b | Q = %b | En = %b | clear = %b | clock = %b", D, Q, en, clear, clock);
        
        // set value to D
        D = 8'b0000_1111;
        clock = 1;
        clear = 0;
        en = 1;

        #5 clock = 0;
        // clear value from D
        #5 clear = 1;
        en = 0;
        clock = 1;

        #5 clock = 0;
        // enable priority - Value should be set
        #5 clear = 1;
        en = 1;
        clock = 1;

        #5 clock = 0;
        // Change value in D
        #5 clear = 0;
        en = 1;
        clock = 1;
        D = 8'b1111_0000;

    end
endmodule: register_test

