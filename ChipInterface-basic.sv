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

	logic [4:0] isBrick, brickIndex; // which brick is being looked at?
	logic isPaddle, isWall;
	logic isBall;			
	logic [11:0] brickTracker;
	logic [11:0] bricksHit;
	logic inScreen;
	logic [2:0] life;
	logic gameOver;

	bricks BR (CLOCK_50, reset, row, col, isBrick, brickIndex);
	
	paddle PAD (CLOCK_50, gameClock, reset, row, col, left, right, isPaddle);
	wall WAL (CLOCK_50, gameClock, reset, row, col, isWall);
	ball BAL (CLOCK_50, gameClock, reset, row, col, start, isBrick, bricksHit, isPaddle, isBall, inScreen, gameOver, led);		
	
	SevenSegmentDigit SSD (life, HEX6, 0);
	
	//assign led = brickTracker;
	
	assign gameOver = !(life) || !(~brickTracker);
	
	always_comb begin
	
		if (isWall && !(~brickTracker)) begin // win-state
			red = 8'h00;
			green = 8'h70;
			blue = 8'hB0;			
		end		
		else if (isBall) begin								
			red = 8'hFF;
			green = 8'hFF;
			blue = 8'hFF;
		end	
		else if (isWall && life) begin
			red = 8'hCC;
			green = 8'hCC;
			blue = 8'hCC;
		end
		else if (isWall && !life) begin
			red = 8'h7C;
			green = 8'h00;
			blue = 8'h00;			
		end

		else if (isBrick && ~brickTracker[brickIndex]) begin
			if(isBrick[0]) begin
				red = 8'hFF; // set to ff
				green = 8'hff; // set to ff
				blue = 8'h00;
			end
			else begin
				red = 8'hFF;
				green = 8'h00;
				blue = 8'hFF;
			end
		end
		else if (isPaddle) begin
			red = 8'h00;
			green = 8'hFF;
			blue = 8'h00;
		end
		else if ((row == 100) || (row == 130) || (row == 150) || (row == 180))begin
			red = 8'hFF;
 			green = 8'h00;
			blue = 8'h00;
		end
		else begin
			red=8'h0;
			green=red;
			blue=red;
		end
	end

	always_ff @(posedge CLOCK_50 , posedge reset) begin
			if (reset) begin
				brickTracker <= 12'h0;
				life <= 3;
			end
			else if (gameOver && start) begin
				brickTracker <= 12'h0;
				life <= 3;
			end
			else if(gameClock) begin	
				brickTracker <= brickTracker | bricksHit;
				life <= (!inScreen) ? (life-1): life;
			end	
	end
endmodule: colour

/////////////////////////// OBJECT MODULE /////////////////////////////

// This module instantiates all the bricks
// It returns which brick it's on, if there is a brick
// No brick = 0 | brokenBrick = 0 | topRow = 1 2 3 4 5 6 | bottomRow = 8 9 10 11 12 13
module bricks
	(input logic CLOCK_50, reset,
	 input logic [8:0] row,
	 input logic [9:0] col,
	output logic [4:0] isBrick, brickIndex);

	// TODO: How to deal with bricks that got hit if we know which brick got hit? ie. change that bricks signal to 0 forever until reset
	//	 input logic [4:0] brickHit,

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
		if(brick0)begin
			isBrick = 1;
			brickIndex = 0;
		end
		else if(brick1) begin
			isBrick = 2;
			brickIndex =1;
		end
		else if(brick2) begin
			brickIndex = 2;
			isBrick = 3;
		end
		else if(brick3) begin
			brickIndex = 3;
			isBrick = 4;
		end
		else if(brick4) begin
			brickIndex = 4;
			isBrick = 5;
		end
		else if(brick5) begin
			brickIndex = 5;
			isBrick = 6;
		end
		else if(brick6) begin
			brickIndex = 6;
			isBrick = 8;
		end
		else if(brick7) begin
			brickIndex = 7;
			isBrick = 9;
		end
		else if(brick8) begin
			brickIndex = 8;
			isBrick = 10;
		end
		else if(brick9) begin
			brickIndex = 9;
			isBrick = 11;
		end
		else if(brickA) begin
			brickIndex = 10;
			isBrick = 12;
		end
		else if(brickB) begin
			brickIndex = 11;
			isBrick = 13;
		end
		else begin
			brickIndex = 12;
			isBrick = 0;
		end
	end
endmodule: bricks

module brick
#(parameter LEFT = 40, TOP = 100, WIDTH = 100, HEIGHT = 30)
	(input logic CLOCK_50, reset,
	 input logic [8:0] row,
	 input logic [9:0] col,
	output logic signal);

	logic withinRow, withinColumn;

	offset_check R (col, LEFT, WIDTH, withinColumn);
	offset_check C (row, TOP, HEIGHT, withinRow);

	// assign withinRow = (row >= LEFT && row <= (LEFT + WIDTH));		cleaned up - below too
	// assign withinColumn = (col >= TOP && col <= (TOP + HEIGHT));

	assign signal = withinRow && withinColumn;

endmodule: brick

// This module checks whether a wall should be at the given row and column and outputs a signal
module wall
	(input logic CLOCK_50, gameClock, reset,
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
	range_check topRow (row, 10, 29, topWallRow); // 10, 29
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
// ALSO, the module updates the position of the paddle each game cycle
module paddle
	(input logic CLOCK_50, gameClock, reset,
	 input logic [8:0] row,
	 input logic [9:0] col,
	 input logic left, right,
	output logic signal);

    logic [9:0] paddlePosition; // left column of paddle
    logic withinRow, withinCol;
	logic paddleWidth;
	
	assign paddleWidth = 64;
	 
    assign withinRow = (row >= 440 && row <= 459);
    assign withinCol = (col >= paddlePosition && col <= (paddlePosition+64)) && (col > 39 && col < (590));

    assign signal = withinRow && withinCol;
	 
	 
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


module ball
	(input logic CLOCK_50, gameClock, reset,
	 input logic [8:0] row,
	 input logic [9:0] col,
	 input logic startKey,
	 input logic [4:0] isBrick, 
	output logic [11:0] bricksHit,
	 input logic isPaddle,
	output logic signal,
	output logic inScreen,
	 input logic gameOver,
	  output logic [11:0] led);			
	
	logic [10:0] ballRow, ballCol;
	logic playing;
	logic hitTopWall, hitPaddle, hitLeftWall, hitRightWall;
	logic movingUp, movingLeft;
	logic [10:0] dx,dy;
	logic [11:0] hitLeftBrickWall;
	logic [11:0] hitRightBrickWall;
	logic [11:0] hitTopBrickWall;
	logic [11:0] hitBottomBrickWall;
	logic [11:0] isWithinWidthBrick;
	logic [11:0] isWithinHeightBrick;
	
	logic [11:0] hitTopBrickEdge;
	logic [11:0] hitBottomBrickEdge;
	logic [11:0] hitLeftBrickEdge;
	logic [11:0] hitRightBrickEdge;
	
	logic [11:0] brickTracker;

	logic [1:0]start;
	checkButton B1 (reset, CLOCK_50, ~startKey, start);
	//paddle P (CLOCK_50, reset, row, col, 0, 0, hitPaddle); 				// Potential bug of updating paddle twice? 
	//bricks B (CLOCK_50, reset, row, col, hitBrick);

	//register BROW (ballRow, rst, en, gameClock, )
/*
	assign hitTopWall = ballRow < (29+1);
	assign hitLeftWall = ballCol < (39+1);
	assign hitRightWall = (ballCol+4) > 590;

	assign hitBrick = isBrick && signal && ~bricksHit[isBrick];
	assign hitPaddle = isPaddle && signal;
	
	assign movingUp = ((movingUp) && ~(hitTopWall || hitBrick)) || (~movingUp && (hitPaddle || hitBrick));
	assign movingLeft = (movingLeft && ~hitLeftWall) || (~movingLeft && hitRightWall);
*/

	range_check leftCol (ballCol, 20, 39, hitLeftWall);
	range_check rightCol (ballCol+4, 590, 609, hitRightWall);
	range_check topRow (ballRow, 10, 29, hitTopWall); // 10, 29
	
	range_check ballOff (ballRow, 10, 479, inScreen);
	
	offset_check leftBrick1 (40, ballCol, 4, hitLeftBrickWall[0]);
	offset_check rightBrick1 (140, ballCol, 4, hitRightBrickWall[0]);
	offset_check topBrick1 (100, ballRow, 4, hitTopBrickWall[0]);
	offset_check bottomBrick1 (130, ballRow, 4, hitBottomBrickWall[0]);
	range_check widthBrick1 (ballCol, 35, 145, isWithinWidthBrick[0]);
	range_check heightBrick1 (ballRow, 100, 130, isWithinHeightBrick[0]);
	
	offset_check leftBrick2 (140, ballCol, 4, hitLeftBrickWall[1]);
	offset_check rightBrick2 (240, ballCol, 4, hitRightBrickWall[1]);
	range_check widthBrick2 (ballCol, 140, 240, isWithinWidthBrick[1]);
	offset_check topBrick2 (100, ballRow, 4, hitTopBrickWall[1]);
	offset_check bottomBrick2 (130, ballRow, 4, hitBottomBrickWall[1]);
	range_check heightBrick2 (ballRow, 100, 130, isWithinHeightBrick[1]);
	
	offset_check leftBrick3 (240, ballCol, 4, hitLeftBrickWall[2]);
	offset_check rightBrick3 (340, ballCol, 4, hitRightBrickWall[2]);
	range_check widthBrick3 (ballCol, 240, 340, isWithinWidthBrick[2]);
	offset_check topBrick3 (100, ballRow, 4, hitTopBrickWall[2]);
	offset_check bottomBrick3 (130, ballRow, 4, hitBottomBrickWall[2]);
	range_check heightBrick3 (ballRow, 100, 130, isWithinHeightBrick[2]);
	
	offset_check leftBrick4 (340, ballCol, 4, hitLeftBrickWall[3]);
	offset_check rightBrick4 (440, ballCol, 4, hitRightBrickWall[3]);
	range_check widthBrick4 (ballCol, 340, 440, isWithinWidthBrick[3]);
	offset_check topBrick4 (100, ballRow, 4, hitTopBrickWall[3]);
	offset_check bottomBrick4 (130, ballRow, 4, hitBottomBrickWall[3]);
	range_check heightBrick4 (ballRow, 100, 130, isWithinHeightBrick[3]);

	offset_check leftBrick5 (440, ballCol, 4, hitLeftBrickWall[4]);
	offset_check rightBrick5 (540, ballCol, 4, hitRightBrickWall[4]);
	range_check widthBrick5 (ballCol, 440, 540, isWithinWidthBrick[4]);
	offset_check topBrick5 (100, ballRow, 4, hitTopBrickWall[4]);
	offset_check bottomBrick5 (130, ballRow, 4, hitBottomBrickWall[4]);
	range_check heightBrick5 (ballRow, 100, 130, isWithinHeightBrick[4]);
	
	offset_check leftBrick6 (540, ballCol, 4, hitLeftBrickWall[5]);
	offset_check rightBrick6 (590, ballCol, 4, hitRightBrickWall[5]);
	range_check widthBrick6 (ballCol, 540, 590, isWithinWidthBrick[5]);
	offset_check topBrick6 (100, ballRow, 4, hitTopBrickWall[5]);
	offset_check bottomBrick6 (130, ballRow, 4, hitBottomBrickWall[5]);
	range_check heightBrick6 (ballRow, 100, 130, isWithinHeightBrick[5]);
	
	// BOTTOM BRICKS
	offset_check leftBrick8 (40, ballCol, 4, hitLeftBrickWall[6]);
	offset_check rightBrick8 (90, ballCol, 4, hitRightBrickWall[6]);
	offset_check topBrick8 (150, ballRow, 4, hitTopBrickWall[6]);
	offset_check bottomBrick8 (180, ballRow, 4, hitBottomBrickWall[6]);
	range_check widthBrick8 (ballCol, 40, 90, isWithinWidthBrick[6]);
	range_check heightBrick8 (ballRow, 150, 180, isWithinHeightBrick[6]);
	
	offset_check leftBrick9 (90, ballCol, 4, hitLeftBrickWall[7]);
	offset_check rightBrick9 (190, ballCol, 4, hitRightBrickWall[7]);
	range_check widthBrick9 (ballCol, 90, 190, isWithinWidthBrick[7]);
	offset_check topBrick9 (150, ballRow, 4, hitTopBrickWall[7]);
	offset_check bottomBrick9 (180, ballRow, 4, hitBottomBrickWall[7]);
	range_check heightBrick9 (ballRow, 150, 180, isWithinHeightBrick[7]);
	
	offset_check leftBrick10 (190, ballCol, 4, hitLeftBrickWall[8]);
	offset_check rightBrick10 (290, ballCol, 4, hitRightBrickWall[8]);
	range_check widthBrick10 (ballCol, 190, 290, isWithinWidthBrick[8]);
	offset_check topBrick10 (150, ballRow, 4, hitTopBrickWall[8]);
	offset_check bottomBrick10 (180, ballRow, 4, hitBottomBrickWall[8]);
	range_check heightBrick10 (ballRow, 150, 180, isWithinHeightBrick[8]);
	
	offset_check leftBrick11 (290, ballCol, 4, hitLeftBrickWall[9]);
	offset_check rightBrick11 (390, ballCol, 4, hitRightBrickWall[9]);
	range_check widthBrick11 (ballCol, 290, 390, isWithinWidthBrick[9]);
	offset_check topBrick11 (150, ballRow, 4, hitTopBrickWall[9]);
	offset_check bottomBrick11 (180, ballRow, 4, hitBottomBrickWall[9]);
	range_check heightBrick11 (ballRow, 150, 180, isWithinHeightBrick[9]);
	
	offset_check leftBrick12 (390, ballCol, 4, hitLeftBrickWall[10]);
	offset_check rightBrick12 (490, ballCol, 4, hitRightBrickWall[10]);
	range_check widthBrick12 (ballCol, 390, 490, isWithinWidthBrick[10]);
	offset_check topBrick12 (150, ballRow, 4, hitTopBrickWall[10]);
	offset_check bottomBrick12 (180, ballRow, 4, hitBottomBrickWall[10]);
	range_check heightBrick12 (ballRow, 150, 180, isWithinHeightBrick[10]);
	
	offset_check leftBrick13 (490, ballCol, 4, hitLeftBrickWall[11]);
	offset_check rightBrick13 (590, ballCol, 4, hitRightBrickWall[11]);
	range_check widthBrick13 (ballCol, 490, 590, isWithinWidthBrick[11]);
	offset_check topBrick13 (150, ballRow, 4, hitTopBrickWall[11]);
	offset_check bottomBrick13 (180, ballRow, 4, hitBottomBrickWall[11]);
	range_check heightBrick13 (ballRow, 150, 180, isWithinHeightBrick[11]);

	
	
	assign hitPaddle = isPaddle && signal;
	assign signal = !(gameOver) && ((row >= ballRow) && (row < (ballRow+4))) && ((col >= ballCol) && (col < (ballCol+4)));
	
	assign hitTopBrickEdge = (hitTopBrickWall & isWithinWidthBrick) & ~brickTracker;
	assign hitBottomBrickEdge = (hitBottomBrickWall & isWithinWidthBrick) & ~brickTracker;
	assign hitLeftBrickEdge = (hitLeftBrickWall & isWithinHeightBrick) & ~brickTracker;
	assign hitRightBrickEdge = (hitRightBrickWall & isWithinHeightBrick)& ~brickTracker;
	
	//assign 
	
	assign movingUp = (movingUp && !hitTopWall && !hitBottomBrickEdge) || (!movingUp && (hitPaddle || hitTopBrickEdge));
	assign movingLeft = (movingLeft && !hitLeftWall && !(hitRightBrickEdge)) || (!movingLeft && (hitRightWall || hitLeftBrickEdge));
	
	assign led = brickTracker;

   always_ff @(posedge CLOCK_50, posedge reset) begin // game clock period
        if(reset ) begin
				dx <= 0;
				dy <= 0;
				ballRow <= 420;
				ballCol <= 400;
				playing <= 0;
				brickTracker <= 12'h0;
        end		  
		  else if(gameClock) begin
				if((start == 2) && ~playing) begin 
					dx <= 1;
					dy <= -2; // I don't like the specs so I changed it
					playing <= 1;
				end
				else if (!inScreen) begin
					dx <= 0;
					dy <= 0;
					ballRow <= 420;
					ballCol <= 400;
					playing <= 0;
					brickTracker <= brickTracker;	
					/*if(gameOver) begin	 // lose state
						brickTracker <= 12'h0;
					end*/
				end
				else if (playing) begin
					/*if(gameOver) begin // win state
						brickTracker <= 12'h0;
						dx <= 0;
						dy <= 0;
						ballRow <= 420;
						ballCol <= 400;
						playing <= 0;						
					end
					else */if (!inScreen) begin
						dx <= 0;
						dy <= 0;
						ballRow <= 420;
						ballCol <= 400;
						playing <= 0;
					end
					else begin
						if (movingUp) begin	
							bricksHit <= (hitTopBrickEdge | hitBottomBrickEdge | hitLeftBrickEdge | hitRightBrickEdge);
							brickTracker <= (brickTracker | bricksHit);
							dy <= -2;
						end
						else begin
							bricksHit <= (hitTopBrickEdge | hitBottomBrickEdge | hitLeftBrickEdge | hitRightBrickEdge);
							brickTracker <= (brickTracker | bricksHit);	
							dy <= 2;
						end
						if(movingLeft)
							dx <= -1;
						else
							dx <= 1;
						ballRow <= ballRow + dy;
						ballCol <= ballCol + dx;
					end

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

