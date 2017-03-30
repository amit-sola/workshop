///nexys4fga.v///top module for project_2
//------------------------------------------------------
// Created by:  Karthik and Ashwin
// Last Modified: 01-Nov-2016
// -----------------------------------------------------
// Description :
// Top level module for ECE 540 Project 2 
// contains all the module instanaces and wire connections 
//
// List of digits of sevensegment display used and the 
// digit_7,digit_6,digit_5 ---> displays the current heading in degrees (0,45,90,135,180,225,270,315)
// digit_4 ------> displays the current movement of the bot in a letter( H -> Stop, F -> Forward, b -> reverse, L -> slow left, l -> fast left, R -> slow right, r -> fast right)
// digit_3,digit_2 -------> displays the X coordinate of the bot in Hex 
// digit_1,digit_0 -------> displays the Y coordinate of the bot in Hex
// decimal point 0 (rightmost) ------> blinks in response to upd_sysregs signal  
//------------------------------------------------------
//list of modules/files -- instantance
//------------------------------------------------------
//1.debounce.v -- DB
//2.sevensegment.v -- SSB
//3.kcpsm6.v -- PB1
//4.motor_control.v -- PB1_PGM
//5.bot.v -- B1
//6.nexys4_bot_if.v -- N4BI
//7.dtg.v -- DTG_1
//8.icon.v -- ICON_1
//9.clolorizer.v -- COLO
//10.clk_wiz_0.v -- clk_ip


module nexys4fpga(	
	input 				clk,                 	                 // 100MHz clock from on-board oscillator
//////////////////////push buttons and switches are not used in project 2 the bot is automated to follow a black line//////////////////////////  	
	input				btnL, btnR,				// pushbutton inputs - left (db_btns[4])and right (db_btns[2])
	input				btnU, btnD,				// pushbutton inputs - up (db_btns[3]) and down (db_btns[1])
	input				btnC,					// pushbutton inputs - center button -> db_btns[5]
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////	
	input				btnCpuReset,			// red pushbutton input -> db_btns[0]
	input		[15:0]		sw,						// switch inputs
	
	output		[15:0]		led,  					// LED outputs	
	
	output	 	[6:0]		seg,					// Seven segment display cathode pins
	output                  	dp,
	output		[7:0]		an,						// Seven segment display anode pins	
	
	output		[7:0]		JA,						// JA Header
	output		[3:0]		vga_red,vga_green,vga_blue,			//outputs to colorizer
	output				vga_hsync,vga_vsync   				//outputs to clolorizer
	
);



    parameter  SIMULATE=0;
	wire				sysclk;			// 100MHz clock from on-board oscillator	
	wire				sysreset;				// system reset signal - asserted high to fo
	wire    	[7:0]       	segs_int;              // sevensegment module the segments and the decimal point
	wire 		[5:0]		db_btns;				// debounced buttons
	wire 		[15:0]		db_sw;					// debounced switches
	wire 		[4:0]		dig7, dig6,
					dig5, dig4,
					dig3, dig2, 
					dig1, dig0;				// display digits
	wire 		[7:0]		decpts;					// decimal points
	wire 		[63:0]		digits_out;

// internal variables for picoblaze and program ROM signals
// signal names taken from kcpsm6_design_template.v

	wire		[11:0]		address;
	wire		[17:0]		instruction;
	wire				bram_enable;
	wire		[7:0]		port_id;
	wire		[7:0]		out_port;
	wire		[7:0]		in_port;
	wire				write_strobe;
	wire				read_strobe;
	wire				interrupt;
	wire				interrupt_ack;
	wire				kcpsm6_sleep; 
	wire				kcpsm6_reset;

///interface for bot, interface, icon, coloriser 
 	wire 		[7:0]		MotCtl_in;		// Motor control input	
	wire		[7:0] 		LocX_reg,		// X-coordinate of rojobot's location		
					LocY_reg,		// Y-coordinate of rojobot's location
					Sensors_reg,		// Sensor readings
					BotInfo_reg,		// Information about rojobot's activity
					LMDist_reg,		// left motor distance register
					RMDist_reg;		// right motor distance register
	wire		[9:0]		vid_row,		// video logic row address
					vid_col;		// video logic column address
	wire 		[1:0]		vid_pixel_out;		// pixel (location) value
	wire				upd_sysregs;		// flag from PicoBlaze to indicate that the system registers 
	wire		[15:0]		if_led;
	wire				rev_reset;	
	wire		[1:0]		icon;			//output from icon to input of colorizer
	wire				video_on;		// enable signal from DTG to colorizer	
	wire 		                vgaclk,locked;		//clk input to vga which is 25MHz 
    	wire         	[9:0]		vid_col_bot,vid_row_bot;//inputs to the bot from DTG module 


	// global assigns
	
	assign 	sysreset = db_btns[0]; // btnCpuReset is asserted low
	
	assign dp = segs_int[7];
	assign seg = segs_int[6:0];
	
	assign	JA = {sysclk, sysreset, 6'b000000};

	assign	led = if_led;
	
	assign rev_reset = ~ sysreset;				// all module exept Seven_segment works on active high reset 
	assign kcpsm6_reset = ~sysreset;			// Picoblaze is reset w/ global reset signal
	assign kcpsm6_sleep = 1'b0;				// kcpsm6 sleep mode is not used
	assign vid_col_bot=vid_col >>2;				//scaling the resolution to 512
	assign vid_row_bot=vid_row >>2;                         //scaling the resolution to 512
	//instantiate the debounce module
	debounce
	#(
		.RESET_POLARITY_LOW(1),
		.SIMULATE(SIMULATE)
	)  	DB
	(
		.clk(sysclk),	
		.pbtn_in({btnC,btnL,btnU,btnR,btnD,btnCpuReset}),
		.switch_in(sw),
		.pbtn_db(db_btns),
		.swtch_db()
	);



	// instantiate the 7-segment, 8-digit display
	sevensegment
	#(
		.RESET_POLARITY_LOW(1),
		.SIMULATE(SIMULATE)
	) SSB
	(
		// inputs for control signals
		.d0(dig0),
		.d1(dig1),
 		.d2(dig2),
		.d3(dig3),
		.d4(dig4),
		.d5(dig5),
		.d6(dig6),
		.d7(dig7),
		.dp(decpts),
		
		// outputs to seven segment display
		.seg(segs_int),			
		.an(an),
		
		// clock and reset signals (100 MHz clock, active high reset)
		.clk(sysclk),
		.reset(sysreset),
		
		// ouput for simulation only
		.digits_out(digits_out)
	);




// instantiate the  Picoblaze and its Program ROM
// below PB contols the bot movement on a black line
kcpsm6 #(
	.interrupt_vector	(12'h3FF),
	.scratch_pad_memory_size(64),
	.hwbuild		(8'h00))
  PB1 (
	.address 		(address),
	.instruction 	(instruction),
	.bram_enable 	(bram_enable),
	.port_id 		(port_id),
	.write_strobe 	(write_strobe),
	.k_write_strobe (),				// Constant Optimized writes are not used in this implementation
	.out_port 		(out_port),
	.read_strobe 	(read_strobe),
	.in_port 		(in_port),
	.interrupt 		(interrupt),
	.interrupt_ack 	(interrupt_ack),				// Interrupt is not used in this implementation
	.reset 			(kcpsm6_reset),
	.sleep			(kcpsm6_sleep),
	.clk 			(sysclk)
); 

// ram consisting of the instrunctions to contol the bot movement 
 motor_control PB1_PGM ( 
	.enable 		(bram_enable),
	.address 		(address),
	.instruction 	(instruction),
	.clk 			(sysclk));	

// instance of the bot which give the information of the bot 
bot B1 (
	.MotCtl_in(MotCtl_in),
	.LocX_reg(LocX_reg),				
	.LocY_reg(LocY_reg),		
	.Sensors_reg(Sensors_reg),
	.BotInfo_reg(BotInfo_reg),	
	.LMDist_reg(LMDist_reg),		
	.RMDist_reg(RMDist_reg),		
	.vid_row(vid_row_bot),		
	.vid_col(vid_col_bot),		
	.vid_pixel_out(vid_pixel_out),	
	.clk(sysclk),			
	.reset(rev_reset),			
	.upd_sysregs(upd_sysregs)		
	);	
// instance of the interface connecting the bot and the PB1 microprocessor	

nexys4_bot_if N4BI (
			.clk(sysclk),
			.reset(rev_reset),
	       		.LocX_reg(LocX_reg),
			.LocY_reg(LocY_reg),
			.Sensors_reg(Sensors_reg),
			.BotInfo_reg(BotInfo_reg),
			.LMDist_reg(LMDist_reg),
			.RMDist_reg(RMDist_reg),
			.upd_sysregs(upd_sysregs),
			.motctl(MotCtl_in),
			.write_strobe(write_strobe),
			.read_strobe(read_strobe), 
	 		.port_id(port_id), 
			.out_port(out_port), 
			.interrupt_ack(interrupt_ack), 
			.k_write_strobe(),
			.in_port(in_port), 
			.interrupt(interrupt), 
	 		.push_btns(db_btns[4:1]),
			.dig_7(dig7),
	       		.dig_6(dig6),
			.dig_5(dig5),
			.dig_4(dig4),
			.dig_3(dig3),
			.dig_2(dig2),
			.dig_1(dig1),
			.dig_0(dig0),
			.decpts(decpts),	
	 		.led(if_led[7:0])	
		   );

//DTG module generating the signals for VGA  
		   
dtg DTG_1 (
		.clock(vgaclk), 
		.rst(rev_reset),
		.horiz_sync(vga_hsync),
	       	.vert_sync(vga_vsync), 
		.video_on(video_on),		
		.pixel_row(vid_row), 
		.pixel_column(vid_col)
	);

// module for placing the icon on the world map

 icon ICON_1 (
	
		.locx_reg(LocX_reg),	        // Output from bot module	
		.locy_reg(LocY_reg),		    // Output from bot module
		.botinfo_reg(BotInfo_reg),		// Output from bot module	
		.pixel_row(vid_row),        // Output from Display Timing generator(dtg) module
		.pixel_column(vid_col),     // Output from Display Timing generator(dtg) module
	 	.vgaclk(vgaclk),			// clk    
	 	.reset(rev_reset),			// reset    
	        .icon(icon)	            // icon output		
	);

//module for assigning various colors to icon and map  	

 colorizer COLO	(
	 	.clk(vgaclk),
		.reset(rev_reset),
		.video_on(video_on),
		.world(vid_pixel_out),
		.icon(icon),
		.red(vga_red),
		.green(vga_green),
		.blue(vga_blue)
		);
		
//module generating clocks on for the VGA and other for all other modules		
clk_wiz_0 clk_ip
         (
          .clk_in1(clk),   //input clock 100MHz
          .sysclk(sysclk), //output clock of 75MHz for all the modules 
          .vgaclk(vgaclk), //output clock of 25MHz for the colorizer module controlling the VGA monitor
          .reset(1'b0),
          .locked(locked)
         );

 endmodule			   
