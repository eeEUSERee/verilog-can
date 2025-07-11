/* vim: colorcolumn=80
 *
 * This file is part of a verilog CAN controller that is SJA1000 compatible.
 *
 * Authors:
 *   * Igor Mohor <igorm@opencores.org>
 *       Author of the original version at
 *       http://www.opencores.org/projects/can/
 *       (which has been unmaintained since about 2009)
 *
 *   * David Piegdon <dgit@piegdon.de>
 *       Picked up project for cleanup and bugfixes in 2019
 *
 * Any additional information is available in the LICENSE file.
 *
 * Copyright (C) 2002, 2003, 2004, 2019 Authors
 *
 * This source file may be used and distributed without restriction provided
 * that this copyright statement is not removed from the file and that any
 * derivative work contains the original copyright notice and the associated
 * disclaimer.
 *
 * This source file is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by the
 * Free Software Foundation; either version 2.1 of the License, or (at your
 * option) any later version.
 *
 * This source is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this source; if not, download it from
 * http://www.opencores.org/lgpl.shtml
 *
 * The CAN protocol is developed by Robert Bosch GmbH and protected by patents.
 * Anybody who wants to implement this CAN IP core on silicon has to obtain
 * a CAN protocol license from Bosch.
 */

`default_nettype none

`timescale 1ns/10ps

/* Mode register */
`define CAN_MODE_RESET                  1'h1    /* Reset mode */

/* Bit Timing 0 register value */
//`define CAN_TIMING0_BRP                 6'h0    /* Baud rate prescaler (2*(value+1)) */
//`define CAN_TIMING0_SJW                 2'h2    /* SJW (value+1) */

`define CAN_TIMING0_BRP                 6'h3    /* Baud rate prescaler (2*(value+1)) */
`define CAN_TIMING0_SJW                 2'h1    /* SJW (value+1) */

/* Bit Timing 1 register value */
//`define CAN_TIMING1_TSEG1               4'h4    /* TSEG1 segment (value+1) */
//`define CAN_TIMING1_TSEG2               3'h3    /* TSEG2 segment (value+1) */
//`define CAN_TIMING1_SAM                 1'h0    /* Triple sampling */

`define CAN_TIMING1_TSEG1               4'hf    /* TSEG1 segment (value+1) */
`define CAN_TIMING1_TSEG2               3'h2    /* TSEG2 segment (value+1) */
`define CAN_TIMING1_SAM                 1'h0    /* Triple sampling */


module old_can_top_tb
	#(
	parameter Tp = 1,
	parameter BRP = 2*(`CAN_TIMING0_BRP + 1)
	)
	(

	);

	initial begin
		$dumpfile("can_top_tb.vcd");
		$dumpvars;
	end

	reg         dut_clk;
	wire        dut1_clkout;
	wire        dut2_clkout;
	wire        dut1_tx;
	wire        dut2_tx;
	wire        dut1_irq;
	wire        dut2_irq;
	wire        dut1_bus_off_on;
	wire        dut2_bus_off_on;

	wire        dut_rx;

	reg         dut_wb_clk_i;
	reg         dut_wb_rst_i;
	reg   [7:0] dut_wb_dat_i;
	wire  [7:0] dut_wb_dat_o1;
	wire  [7:0] dut_wb_dat_o2;
	reg         dut_wb_cyc_i1;
	reg         dut_wb_cyc_i2;
	reg         dut_wb_stb_i;
	reg         dut_wb_we_i;
	reg   [7:0] dut_wb_adr_i;
	wire        dut_wb_ack_o1;
	wire        dut_wb_ack_o2;

	reg         bus_free;

	reg         rx;
	wire        tx;

	reg         delayed_tx;
	reg         tx_bypassed;

	integer     start_tb;
	reg         extended_mode;
	reg   [7:0] tmp_data;

	event       igor;

	// Instantiate can_top module
	can_wishbone_top dut1
	(
		.wb_clk_i(dut_wb_clk_i),
		.wb_rst_i(dut_wb_rst_i),
		.wb_dat_i(dut_wb_dat_i),
		.wb_dat_o(dut_wb_dat_o1),
		.wb_cyc_i(dut_wb_cyc_i1),
		.wb_stb_i(dut_wb_stb_i),
		.wb_we_i(dut_wb_we_i),
		.wb_adr_i(dut_wb_adr_i),
		.wb_ack_o(dut_wb_ack_o1),
		.clk_i(dut_clk),
		.rx_i(dut_rx),
		.tx_o(dut1_tx),
		.bus_off_on_o(dut1_bus_off_on),
		.irq_n_o(dut1_irq),
		.clkout_o(dut1_clkout)

		`ifdef CAN_BIST
		,
		.mbist_si_i(1'b0),       // bist scan serial in
		.mbist_so_o(),           // bist scan serial out
		.mbist_ctrl_i(3'b001)    // mbist scan {enable, clock, reset}
		`endif
	);


	// Instantiate can_top module 2
	can_wishbone_top dut2
	(
		.wb_clk_i(dut_wb_clk_i),
		.wb_rst_i(dut_wb_rst_i),
		.wb_dat_i(dut_wb_dat_i),
		.wb_dat_o(dut_wb_dat_o2),
		.wb_cyc_i(dut_wb_cyc_i2),
		.wb_stb_i(dut_wb_stb_i),
		.wb_we_i(dut_wb_we_i),
		.wb_adr_i(dut_wb_adr_i),
		.wb_ack_o(dut_wb_ack_o2),
		.clk_i(dut_clk),
		.rx_i(dut_rx),
		.tx_o(dut2_tx),
		.bus_off_on_o(dut2_bus_off_on),
		.irq_n_o(dut2_irq),
		.clkout_o(dut2_clkout)

		`ifdef CAN_BIST
		,
		.mbist_si_i(1'b0),       // bist scan serial in
		.mbist_so_o(),           // bist scan serial out
		.mbist_ctrl_i(3'b001)    // mbist scan {enable, clock, reset}
		`endif
	);


	// Combining tx with the output enable signal.
	wire tx_tmp1;
	wire tx_tmp2;

	assign tx_tmp1 = dut1_bus_off_on ? dut1_tx : 1'b1;
	assign tx_tmp2 = dut2_bus_off_on ? dut2_tx : 1'b1;

	assign tx = tx_tmp1 & tx_tmp2;



	// Generate wishbone clock signal 10 MHz
	initial begin
		dut_wb_clk_i=0;
		forever #50 dut_wb_clk_i = ~dut_wb_clk_i;
	end


	// Generate clock signal 25 MHz
	// Generate clock signal 16 MHz
	initial begin
		dut_clk=0;
		//forever #20 dut_clk = ~dut_clk;
		forever #31.25 dut_clk = ~dut_clk;
	end


	initial begin
		start_tb = 0;
		rx = 1;
		extended_mode = 0;
		tx_bypassed = 0;

		dut_wb_dat_i = 'hz;
		dut_wb_cyc_i1 = 0;
		dut_wb_cyc_i2 = 0;
		dut_wb_stb_i = 0;
		dut_wb_we_i = 'hz;
		dut_wb_adr_i = 'hz;
		dut_wb_rst_i = 1;
		#200 dut_wb_rst_i = 0;
		#200 start_tb = 1;

		bus_free = 1;
	end




	// Generating delayed tx signal (CAN transciever delay)
	always begin
		wait (tx);
		repeat (2*BRP) @(posedge dut_clk);   // 4 time quants delay
		#1 delayed_tx = tx;
		wait (~tx);
		repeat (2*BRP) @(posedge dut_clk);   // 4 time quants delay
		#1 delayed_tx = tx;
	end

	//assign dut_rx = rx & delayed_tx;   FIX ME !!!
	assign dut_rx = rx & (delayed_tx | tx_bypassed);   // When this signal is on, tx is not looped back to the rx.


	// Main testbench
	initial begin
		wait(start_tb);

		// Set bus timing register 0
		write_register1(8'd6, {`CAN_TIMING0_SJW, `CAN_TIMING0_BRP});
		write_register2(8'd6, {`CAN_TIMING0_SJW, `CAN_TIMING0_BRP});

		// Set bus timing register 1
		write_register1(8'd7, {`CAN_TIMING1_SAM, `CAN_TIMING1_TSEG2, `CAN_TIMING1_TSEG1});
		write_register2(8'd7, {`CAN_TIMING1_SAM, `CAN_TIMING1_TSEG2, `CAN_TIMING1_TSEG1});


		// Set Clock Divider register
		//  extended_mode = 1'b1;
		//  write_register1(8'd31, {extended_mode, 3'h0, 1'b0, 3'h0});   // Setting the normal mode (not extended)
		write_register2(8'd31, {extended_mode, 3'h0, 1'b0, 3'h0});   // Setting the normal mode (not extended)


		// Set Acceptance Code and Acceptance Mask registers (their address differs for basic and extended mode

		/* Set Acceptance Code and Acceptance Mask registers
		write_register1(8'd16, 8'ha6); // acceptance code 0
		write_register1(8'd17, 8'hb0); // acceptance code 1
		write_register1(8'd18, 8'h12); // acceptance code 2
		write_register1(8'd19, 8'h30); // acceptance code 3
		write_register1(8'd20, 8'hff); // acceptance mask 0
		write_register1(8'd21, 8'hff); // acceptance mask 1
		write_register1(8'd22, 8'hff); // acceptance mask 2
		write_register1(8'd23, 8'hff); // acceptance mask 3

		write_register2(8'd16, 8'ha6); // acceptance code 0
		write_register2(8'd17, 8'hb0); // acceptance code 1
		write_register2(8'd18, 8'h12); // acceptance code 2
		write_register2(8'd19, 8'h30); // acceptance code 3
		write_register2(8'd20, 8'hff); // acceptance mask 0
		write_register2(8'd21, 8'hff); // acceptance mask 1
		write_register2(8'd22, 8'hff); // acceptance mask 2
		write_register2(8'd23, 8'hff); // acceptance mask 3
		*/

		// Set Acceptance Code and Acceptance Mask registers
		write_register1(8'd4, 8'he8); // acceptance code
		write_register1(8'd5, 8'h0f); // acceptance mask

		#10;
		repeat (1000) @(posedge dut_clk);

		// Switch-off reset mode
		write_register1(8'd0, {7'h0, ~(`CAN_MODE_RESET)});
		write_register2(8'd0, {7'h0, ~(`CAN_MODE_RESET)});

		repeat (BRP) @(posedge dut_clk);   // At least BRP clocks needed before bus goes to dominant level. Otherwise 1 quant difference is possible
		// This difference is resynchronized later.

		// After exiting the reset mode sending bus free
		repeat (11) send_bit(1);

		//  test_synchronization;       // test currently switched off
		//  test_empty_fifo_ext;        // test currently switched off
		//  test_full_fifo_ext;         // test currently switched off
		//  send_frame_ext;             // test currently switched off
		//  test_empty_fifo;            // test currently switched off
		//  test_full_fifo;             // test currently switched off
		//  test_reset_mode;            // test currently switched off
		//  bus_off_test;               // test currently switched off
		//  forced_bus_off;             // test currently switched off
		//  send_frame_basic;           // test currently switched on
		//  send_frame_extended;        // test currently switched off
		//  self_reception_request;     // test currently switched off
		//  manual_frame_basic;         // test currently switched off
		//  manual_frame_ext;           // test currently switched off
		//  error_test;
		//  register_test;
		bus_off_recovery_test;


		/*
		#5000;
		$display("\n\nStart rx/tx err cnt\n");
		-> igor;

		// Switch-off reset mode
		$display("Rest mode ON");
		write_register1(8'd0, {7'h0, (`CAN_MODE_RESET)});

		$display("Set extended mode");
		extended_mode = 1'b1;
		write_register1(8'd31, {extended_mode, 3'h0, 1'b0, 3'h0});   // Setting the extended mode

		$display("Rest mode OFF");
		write_register1(8'd0, {7'h0, ~(`CAN_MODE_RESET)});

		write_register1(8'd14, 8'hde); // rx err cnt
		write_register1(8'd15, 8'had); // tx err cnt

		read_register1(8'd14, tmp_data); // rx err cnt
		read_register1(8'd15, tmp_data); // tx err cnt

		// Switch-on reset mode
		$display("Switch-on reset mode");
		write_register1(8'd0, {7'h0, `CAN_MODE_RESET});

		write_register1(8'd14, 8'h12); // rx err cnt
		write_register1(8'd15, 8'h34); // tx err cnt

		read_register1(8'd14, tmp_data); // rx err cnt
		read_register1(8'd15, tmp_data); // tx err cnt

		// Switch-off reset mode
		$display("Switch-off reset mode");
		write_register1(8'd0, {7'h0, ~(`CAN_MODE_RESET)});

		read_register1(8'd14, tmp_data); // rx err cnt
		read_register1(8'd15, tmp_data); // tx err cnt

		// Switch-on reset mode
		$display("Switch-on reset mode");
		write_register1(8'd0, {7'h0, `CAN_MODE_RESET});

		write_register1(8'd14, 8'h56); // rx err cnt
		write_register1(8'd15, 8'h78); // tx err cnt

		// Switch-off reset mode
		$display("Switch-off reset mode");
		write_register1(8'd0, {7'h0, ~(`CAN_MODE_RESET)});

		read_register1(8'd14, tmp_data); // rx err cnt
		read_register1(8'd15, tmp_data); // tx err cnt
		*/
	       #1000;
	       $display("CAN Testbench finished !");
	       $finish;
	end


	task bus_off_recovery_test;
		begin -> igor;

			// Switch-on reset mode
			write_register1(8'd0, {7'h0, (`CAN_MODE_RESET)});
			write_register2(8'd0, {7'h0, (`CAN_MODE_RESET)});

			// Set Clock Divider register
			extended_mode = 1'b1;
			write_register1(8'd31, {extended_mode, 3'h0, 1'b0, 3'h0});   // Setting the normal mode (not extended)
			write_register2(8'd31, {extended_mode, 3'h0, 1'b0, 3'h0});   // Setting the normal mode (not extended)

			write_register1(8'd16, 8'h00); // acceptance code 0
			write_register1(8'd17, 8'h00); // acceptance code 1
			write_register1(8'd18, 8'h00); // acceptance code 2
			write_register1(8'd19, 8'h00); // acceptance code 3
			write_register1(8'd20, 8'hff); // acceptance mask 0
			write_register1(8'd21, 8'hff); // acceptance mask 1
			write_register1(8'd22, 8'hff); // acceptance mask 2
			write_register1(8'd23, 8'hff); // acceptance mask 3

			write_register2(8'd16, 8'h00); // acceptance code 0
			write_register2(8'd17, 8'h00); // acceptance code 1
			write_register2(8'd18, 8'h00); // acceptance code 2
			write_register2(8'd19, 8'h00); // acceptance code 3
			write_register2(8'd20, 8'hff); // acceptance mask 0
			write_register2(8'd21, 8'hff); // acceptance mask 1
			write_register2(8'd22, 8'hff); // acceptance mask 2
			write_register2(8'd23, 8'hff); // acceptance mask 3

			// Switch-off reset mode
			write_register1(8'd0, {7'h0, ~(`CAN_MODE_RESET)});
			write_register2(8'd0, {7'h0, ~(`CAN_MODE_RESET)});

			// Enable all interrupts
			write_register1(8'd4, 8'hff); // irq enable register

			repeat (30) send_bit(1);
			-> igor;
			$display("(%0t) CAN should be idle now", $time);

			// DUT2 sends a message
			write_register2(8'd16, 8'h83); // tx registers
			write_register2(8'd17, 8'h12); // tx registers
			write_register2(8'd18, 8'h34); // tx registers
			write_register2(8'd19, 8'h45); // tx registers
			write_register2(8'd20, 8'h56); // tx registers
			write_register2(8'd21, 8'hde); // tx registers
			write_register2(8'd22, 8'had); // tx registers
			write_register2(8'd23, 8'hbe); // tx registers

			write_register2(8'd1, 8'h1);  // tx request

			// Wait until DUT 1 receives rx irq
			read_register1(8'd3, tmp_data);
			while (!(tmp_data & 8'h01)) begin
				read_register1(8'd3, tmp_data);
				#10000;
			end

			$display("Frame received by DUT1.");

			// DUT1 will send a message and will receive many errors
			write_register1(8'd16, 8'haa); // tx registers
			write_register1(8'd17, 8'haa); // tx registers
			write_register1(8'd18, 8'haa); // tx registers
			write_register1(8'd19, 8'haa); // tx registers
			write_register1(8'd20, 8'haa); // tx registers
			write_register1(8'd21, 8'haa); // tx registers
			write_register1(8'd22, 8'haa); // tx registers
			write_register1(8'd23, 8'haa); // tx registers

			fork
				begin
					write_register1(8'd1, 8'h1);  // tx request
				end

				begin
					// Waiting until DUT 1 starts transmitting
					wait (!dut1_tx);
					repeat (33) send_bit(1);
					repeat (330) send_bit(0);
					repeat (1) send_bit(1);
				end

			join

			// Switch-off reset mode
			write_register1(8'd0, {7'h0, ~(`CAN_MODE_RESET)});
			write_register2(8'd0, {7'h0, ~(`CAN_MODE_RESET)});

			repeat (1999) send_bit(1);

			// Switch-on reset mode
			write_register1(8'd0, {7'h0, (`CAN_MODE_RESET)});
			write_register2(8'd0, {7'h0, (`CAN_MODE_RESET)});

			write_register1(8'd14, 8'h0); // rx err cnt

			// Switch-off reset mode
			write_register1(8'd0, {7'h0, ~(`CAN_MODE_RESET)});
			write_register2(8'd0, {7'h0, ~(`CAN_MODE_RESET)});

			// Wait some time before simulation ends
			repeat (10000) @(posedge dut_clk);
		end
	endtask // bus_off_recovery_test


	task error_test;
		begin
			// Switch-off reset mode
			write_register1(8'd0, {7'h0, (`CAN_MODE_RESET)});
			write_register2(8'd0, {7'h0, (`CAN_MODE_RESET)});
			// Set Clock Divider register
			extended_mode = 1'b1;
			write_register1(8'd31, {extended_mode, 3'h0, 1'b0, 3'h0});   // Setting the normal mode (not extended)
			write_register2(8'd31, {extended_mode, 3'h0, 1'b0, 3'h0});   // Setting the normal mode (not extended)
			// Set error warning limit register
			write_register1(8'd13, 8'h56); // error warning limit
			// Switch-off reset mode
			write_register1(8'd0, {7'h0, ~(`CAN_MODE_RESET)});
			write_register2(8'd0, {7'h0, ~(`CAN_MODE_RESET)});
			// Enable all interrupts
			write_register1(8'd4, 8'hff); // irq enable register

			repeat (300) send_bit(0);

			$display("Kr neki");

		end
	endtask


	task register_test;
		integer i, j, tmp;
		begin
			$display("Change mode to extended mode and test registers");
			// Switch-off reset mode
			write_register1(8'd0, {7'h0, (`CAN_MODE_RESET)});
			write_register2(8'd0, {7'h0, (`CAN_MODE_RESET)});
			// Set Clock Divider register
			extended_mode = 1'b1;
			write_register1(8'd31, {extended_mode, 3'h0, 1'b0, 3'h0});   // Setting the normal mode (not extended)
			write_register2(8'd31, {extended_mode, 3'h0, 1'b0, 3'h0});   // Setting the normal mode (not extended)
			// Switch-off reset mode
			write_register1(8'd0, {7'h0, ~(`CAN_MODE_RESET)});
			write_register2(8'd0, {7'h0, ~(`CAN_MODE_RESET)});

			for (i=1; i<128; i=i+1) begin
				for (j=0; j<8; j=j+1) begin
					read_register1(i, tmp_data);
					write_register1(i, tmp_data | (1 << j));
				end
			end

		end
	endtask


	task forced_bus_off;    // Forcing bus-off by writinf to tx_err_cnt register
		begin
			// Switch-on reset mode
			write_register1(8'd0, {7'h0, `CAN_MODE_RESET});
			// Set Clock Divider register
			write_register1(8'd31, {1'b1, 7'h0});    // Setting the extended mode (not normal)
			// Write 255 to tx_err_cnt register - Forcing bus-off
			write_register1(8'd15, 255);
			// Switch-off reset mode
			write_register1(8'd0, {7'h0, ~(`CAN_MODE_RESET)});

			//    #1000000;
			#2500000;

			// Switch-on reset mode
			write_register1(8'd0, {7'h0, `CAN_MODE_RESET});
			// Write 245 to tx_err_cnt register
			write_register1(8'd15, 245);
			// Switch-off reset mode
			write_register1(8'd0, {7'h0, ~(`CAN_MODE_RESET)});

			#1000000;
		end
	endtask   // forced_bus_off


	task manual_frame_basic;    // Testbench sends a basic format frame
		begin
			// Switch-on reset mode
			write_register1(8'd0, {7'h0, (`CAN_MODE_RESET)});

			// Set Acceptance Code and Acceptance Mask registers
			write_register1(8'd4, 8'h28); // acceptance code
			write_register1(8'd5, 8'hff); // acceptance mask

			repeat (100) @(posedge dut_clk);

			// Switch-off reset mode
			//    write_register1(8'd0, {7'h0, ~(`CAN_MODE_RESET)});
			write_register1(8'd0, 8'h1e);  // reset_off, all irqs enabled.

			// After exiting the reset mode sending bus free
			repeat (11) send_bit(1);

			write_register1(8'd10, 8'h55); // Writing ID[10:3] = 0x55
			write_register1(8'd11, 8'h77); // Writing ID[2:0] = 0x3, rtr = 1, length = 7
			write_register1(8'd12, 8'h00); // data byte 1
			write_register1(8'd13, 8'h00); // data byte 2
			write_register1(8'd14, 8'h00); // data byte 3
			write_register1(8'd15, 8'h00); // data byte 4
			write_register1(8'd16, 8'h00); // data byte 5
			write_register1(8'd17, 8'h00); // data byte 6
			write_register1(8'd18, 8'h00); // data byte 7
			write_register1(8'd19, 8'h00); // data byte 8

			tx_bypassed = 0;    // When this signal is on, tx is not looped back to the rx.

			fork
				begin
					tx_request_command;
					// self_reception_request_command;
				end

				begin
					#931;

					repeat (1) begin
						send_bit(0);  // SOF
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID arbi lost
						send_bit(1);  // RTR
						send_bit(0);  // IDE
						send_bit(0);  // r0
						send_bit(0);  // DLC
						send_bit(1);  // DLC
						send_bit(1);  // DLC
						send_bit(1);  // DLC
						send_bit(1);  // CRC
						send_bit(1);  // CRC
						send_bit(0);  // CRC stuff
						send_bit(0);  // CRC 6
						send_bit(0);  // CRC
						send_bit(0);  // CRC
						send_bit(0);  // CRC
						send_bit(1);  // CRC  stuff
						send_bit(0);  // CRC 0
						send_bit(0);  // CRC
						send_bit(1);  // CRC
						send_bit(0);  // CRC
						send_bit(1);  // CRC 5
						send_bit(1);  // CRC
						send_bit(0);  // CRC
						send_bit(1);  // CRC
						send_bit(1);  // CRC b
						send_bit(1);  // CRC DELIM
						send_bit(0);  // ACK
						send_bit(1);  // ACK DELIM
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // INTER
						send_bit(1);  // INTER
						send_bit(1);  // INTER
						#400;

						send_bit(0);  // SOF
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(1);  // ID
						send_bit(1);  // RTR
						send_bit(0);  // IDE
						send_bit(0);  // r0
						send_bit(0);  // DLC
						send_bit(1);  // DLC
						send_bit(1);  // DLC
						send_bit(1);  // DLC
						send_bit(1);  // CRC
						send_bit(0);  // CRC
						send_bit(0);  // CRC 6
						send_bit(0);  // CRC
						send_bit(0);  // CRC
						send_bit(1);  // CRC
						send_bit(0);  // CRC 0
						send_bit(0);  // CRC
						send_bit(1);  // CRC
						send_bit(0);  // CRC
						send_bit(0);  // CRC 5
						send_bit(1);  // CRC
						send_bit(0);  // CRC
						send_bit(0);  // CRC
						send_bit(0);  // CRC b
						send_bit(1);  // CRC DELIM
						send_bit(0);  // ACK
						send_bit(1);  // ACK DELIM
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // INTER
						send_bit(1);  // INTER
						send_bit(1);  // INTER
					end // repeat
				end
			join

			read_receive_buffer;
			release_rx_buffer_command;

			#1000 read_register1(8'd3, tmp_data);
			read_receive_buffer;
			release_rx_buffer_command;
			read_receive_buffer;

			// First we receive a msg
			send_bit(0);  // SOF
			send_bit(0);  // ID
			send_bit(1);  // ID
			send_bit(0);  // ID
			send_bit(1);  // ID
			send_bit(0);  // ID
			send_bit(1);  // ID
			send_bit(0);  // ID
			send_bit(1);  // ID
			send_bit(0);  // ID
			send_bit(1);  // ID
			send_bit(1);  // ID
			send_bit(1);  // RTR
			send_bit(0);  // IDE
			send_bit(0);  // r0
			send_bit(0);  // DLC
			send_bit(1);  // DLC
			send_bit(1);  // DLC
			send_bit(1);  // DLC
			send_bit(1);  // CRC
			send_bit(0);  // CRC
			send_bit(0);  // CRC 6
			send_bit(0);  // CRC
			send_bit(0);  // CRC
			send_bit(1);  // CRC
			send_bit(0);  // CRC 0
			send_bit(0);  // CRC
			send_bit(1);  // CRC
			send_bit(0);  // CRC
			send_bit(0);  // CRC 5
			send_bit(1);  // CRC
			send_bit(0);  // CRC
			send_bit(0);  // CRC
			send_bit(0);  // CRC b
			send_bit(1);  // CRC DELIM
			send_bit(0);  // ACK
			send_bit(1);  // ACK DELIM
			send_bit(1);  // EOF
			send_bit(1);  // EOF
			send_bit(1);  // EOF
			send_bit(1);  // EOF
			send_bit(1);  // EOF
			send_bit(1);  // EOF
			send_bit(1);  // EOF
			send_bit(1);  // INTER
			send_bit(1);  // INTER
			send_bit(1);  // INTER

			fork
				begin
					tx_request_command;
					//        self_reception_request_command;
				end

				begin
					#931;
					repeat (1) begin
						send_bit(0);  // SOF
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID arbi lost
						send_bit(1);  // RTR
						send_bit(0);  // IDE
						send_bit(0);  // r0
						send_bit(0);  // DLC
						send_bit(1);  // DLC
						send_bit(1);  // DLC
						send_bit(1);  // DLC
						send_bit(1);  // CRC
						send_bit(0);  // CRC
						send_bit(0);  // CRC 6
						send_bit(0);  // CRC
						send_bit(0);  // CRC
						send_bit(1);  // CRC
						send_bit(0);  // CRC 0
						send_bit(0);  // CRC
						send_bit(1);  // CRC
						send_bit(0);  // CRC
						send_bit(0);  // CRC 5
						send_bit(1);  // CRC
						send_bit(0);  // CRC
						send_bit(0);  // CRC
						send_bit(0);  // CRC b
						send_bit(1);  // CRC DELIM
						send_bit(0);  // ACK
						send_bit(1);  // ACK DELIM
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // INTER
						send_bit(1);  // INTER
						send_bit(1);  // INTER
						#6000;

						send_bit(0);  // SOF
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(1);  // ID
						send_bit(1);  // RTR
						send_bit(0);  // IDE
						send_bit(0);  // r0
						send_bit(0);  // DLC
						send_bit(1);  // DLC
						send_bit(1);  // DLC
						send_bit(1);  // DLC
						send_bit(1);  // CRC
						send_bit(0);  // CRC
						send_bit(0);  // CRC 6
						send_bit(0);  // CRC
						send_bit(0);  // CRC
						send_bit(1);  // CRC
						send_bit(0);  // CRC 0
						send_bit(0);  // CRC
						send_bit(1);  // CRC
						send_bit(0);  // CRC
						send_bit(0);  // CRC 5
						send_bit(1);  // CRC
						send_bit(0);  // CRC
						send_bit(0);  // CRC
						send_bit(0);  // CRC b
						send_bit(1);  // CRC DELIM
						send_bit(0);  // ACK
						send_bit(1);  // ACK DELIM
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // INTER
						send_bit(1);  // INTER
						send_bit(1);  // INTER
					end // repeat
				end
			join

			read_receive_buffer;
			release_rx_buffer_command;

			#1000 read_register1(8'd3, tmp_data);
			read_receive_buffer;
			release_rx_buffer_command;
			read_receive_buffer;

			#4000000;
		end
	endtask   //  manual_frame_basic


	task manual_frame_ext;    // Testbench sends an extended format frame
		begin


			// Switch-on reset mode
			write_register1(8'd0, {7'h0, (`CAN_MODE_RESET)});

			// Set Clock Divider register
			extended_mode = 1'b1;
			write_register1(8'd31, {extended_mode, 7'h0});    // Setting the extended mode

			// Set Acceptance Code and Acceptance Mask registers
			write_register1(8'd16, 8'ha6); // acceptance code 0
			write_register1(8'd17, 8'h00); // acceptance code 1
			write_register1(8'd18, 8'h5a); // acceptance code 2
			write_register1(8'd19, 8'hac); // acceptance code 3
			write_register1(8'd20, 8'h00); // acceptance mask 0
			write_register1(8'd21, 8'h00); // acceptance mask 1
			write_register1(8'd22, 8'h00); // acceptance mask 2
			write_register1(8'd23, 8'h00); // acceptance mask 3

			//write_register1(8'd14, 8'h7a); // rx err cnt
			//write_register1(8'd15, 8'h7a); // tx err cnt

			//read_register1(8'd14, tmp_data); // rx err cnt
			//read_register1(8'd15, tmp_data); // tx err cnt

			repeat (100) @(posedge dut_clk);

			// Switch-off reset mode
			write_register1(8'd0, {7'h0, ~(`CAN_MODE_RESET)});

			// After exiting the reset mode sending bus free
			repeat (11) send_bit(1);


			// Extended frame format
			// Writing TX frame information + identifier + data
			write_register1(8'd16, 8'hc5);   // Frame format = 1, Remote transmision request = 1, DLC = 5
			write_register1(8'd17, 8'ha6);   // ID[28:21] = a6
			write_register1(8'd18, 8'h00);   // ID[20:13] = 00
			write_register1(8'd19, 8'h5a);   // ID[12:5]  = 5a
			write_register1(8'd20, 8'ha8);   // ID[4:0]   = 15
			// write_register1(8'd21, 8'h78); RTR does not send any data
			// write_register1(8'd22, 8'h9a);
			// write_register1(8'd23, 8'hbc);
			// write_register1(8'd24, 8'hde);
			// write_register1(8'd25, 8'hf0);
			// write_register1(8'd26, 8'h0f);
			// write_register1(8'd27, 8'hed);
			// write_register1(8'd28, 8'hcb);


			// Enabling IRQ's (extended mode)
			write_register1(8'd4, 8'hff);

			// tx_bypassed = 1;    // When this signal is on, tx is not looped back to the rx.

			fork
				begin
					tx_request_command;
					//        self_reception_request_command;
				end
				begin
					#771;
					repeat (1) begin
						send_bit(0);  // SOF
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID a
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID 6
						send_bit(0);  // ID
						send_bit(0);  // ID
						send_bit(0);  // ID
						send_bit(1);  // RTR
						send_bit(1);  // IDE
						send_bit(0);  // ID 0
						send_bit(0);  // ID
						send_bit(0);  // ID
						send_bit(0);  // ID
						send_bit(0);  // ID 0
						send_bit(1);  // ID stuff
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID 6
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID a
						send_bit(1);  // ID 1
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(0);  // ID 5   // Force arbitration lost
						send_bit(1);  // RTR
						send_bit(0);  // r1
						send_bit(0);  // r0
						send_bit(0);  // DLC
						send_bit(1);  // DLC
						send_bit(0);  // DLC
						send_bit(1);  // DLC
						send_bit(1);  // CRC
						send_bit(1);  // CRC
						send_bit(0);  // CRC 6
						send_bit(1);  // CRC
						send_bit(1);  // CRC
						send_bit(1);  // CRC
						send_bit(1);  // CRC f
						send_bit(0);  // CRC
						send_bit(0);  // CRC
						send_bit(1);  // CRC
						send_bit(0);  // CRC 2
						send_bit(1);  // CRC
						send_bit(0);  // CRC
						send_bit(1);  // CRC
						send_bit(0);  // CRC a
						send_bit(1);  // CRC DELIM
						send_bit(0);  // ACK
						send_bit(1);  // ACK DELIM
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // INTER
						send_bit(1);  // INTER
						send_bit(1);  // INTER
						#80;
						send_bit(0);  // SOF
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID a
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID 6
						send_bit(0);  // ID
						send_bit(0);  // ID
						send_bit(0);  // ID
						send_bit(1);  // RTR
						send_bit(1);  // IDE
						send_bit(0);  // ID 0
						send_bit(0);  // ID
						send_bit(0);  // ID
						send_bit(0);  // ID
						send_bit(0);  // ID 0
						send_bit(1);  // ID stuff
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID 6
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID a
						send_bit(1);  // ID 1
						send_bit(0);  // ID
						send_bit(0);  // ID     // Force arbitration lost
						send_bit(0);  // ID
						send_bit(1);  // ID 5
						send_bit(1);  // RTR
						send_bit(0);  // r1
						send_bit(0);  // r0
						send_bit(0);  // DLC
						send_bit(1);  // DLC
						send_bit(0);  // DLC
						send_bit(1);  // DLC
						send_bit(0);  // CRC
						send_bit(0);  // CRC
						send_bit(0);  // CRC 0
						send_bit(0);  // CRC
						send_bit(0);  // CRC
						send_bit(1);  // CRC stuff
						send_bit(0);  // CRC
						send_bit(0);  // CRC 0
						send_bit(1);  // CRC
						send_bit(1);  // CRC
						send_bit(1);  // CRC
						send_bit(0);  // CRC e
						send_bit(1);  // CRC
						send_bit(1);  // CRC
						send_bit(0);  // CRC
						send_bit(0);  // CRC c
						send_bit(1);  // CRC DELIM
						send_bit(0);  // ACK
						send_bit(1);  // ACK DELIM
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // INTER
						send_bit(1);  // INTER
						send_bit(1);  // INTER

						#80;
						send_bit(0);  // SOF
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID a
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID 6
						send_bit(0);  // ID
						send_bit(0);  // ID
						send_bit(0);  // ID
						send_bit(1);  // RTR
						send_bit(1);  // IDE
						send_bit(0);  // ID 0
						send_bit(0);  // ID
						send_bit(0);  // ID
						send_bit(0);  // ID
						send_bit(0);  // ID 0
						send_bit(1);  // ID stuff
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID 6
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID a
						send_bit(1);  // ID 1
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID 5
						send_bit(1);  // RTR
						send_bit(0);  // r1
						send_bit(0);  // r0
						send_bit(0);  // DLC
						send_bit(1);  // DLC
						send_bit(0);  // DLC
						send_bit(1);  // DLC
						send_bit(1);  // CRC
						send_bit(0);  // CRC
						send_bit(0);  // CRC 4
						send_bit(1);  // CRC
						send_bit(1);  // CRC
						send_bit(0);  // CRC
						send_bit(1);  // CRC d
						send_bit(0);  // CRC
						send_bit(0);  // CRC
						send_bit(1);  // CRC
						send_bit(1);  // CRC 3
						send_bit(1);  // CRC
						send_bit(0);  // CRC
						send_bit(0);  // CRC
						send_bit(1);  // CRC 9
						send_bit(1);  // CRC DELIM
						send_bit(0);  // ACK
						send_bit(1);  // ACK DELIM
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // INTER
						send_bit(1);  // INTER
						send_bit(1);  // INTER
					end // repeat
				end
			join

			read_receive_buffer;
			release_rx_buffer_command;

			read_receive_buffer;
			release_rx_buffer_command;
			read_receive_buffer;

			// Read irq register
			#1 read_register1(8'd3, tmp_data);

			// Read error code capture register
			read_register1(8'd12, tmp_data);

			// Read error capture code register
			//    read_register1(8'd12, tmp_data);

			read_register1(8'd14, tmp_data); // rx err cnt
			read_register1(8'd15, tmp_data); // tx err cnt

			#4000000;
		end
	endtask   //  manual_frame_ext


	task bus_off_test;    // Testbench sends a frame
		begin

			write_register1(8'd10, 8'he8); // Writing ID[10:3] = 0xe8
			write_register1(8'd11, 8'hb7); // Writing ID[2:0] = 0x5, rtr = 1, length = 7
			write_register1(8'd12, 8'h00); // data byte 1
			write_register1(8'd13, 8'h00); // data byte 2
			write_register1(8'd14, 8'h00); // data byte 3
			write_register1(8'd15, 8'h00); // data byte 4
			write_register1(8'd16, 8'h00); // data byte 5
			write_register1(8'd17, 8'h00); // data byte 6
			write_register1(8'd18, 8'h00); // data byte 7
			write_register1(8'd19, 8'h00); // data byte 8

			fork
				begin
					tx_request_command;
				end
				begin
					#2000;
					repeat (16) begin
						send_bit(0);  // SOF
						send_bit(1);  // ID
						send_bit(1);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(0);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(1);  // RTR
						send_bit(0);  // IDE
						send_bit(0);  // r0
						send_bit(0);  // DLC
						send_bit(1);  // DLC
						send_bit(1);  // DLC
						send_bit(1);  // DLC
						send_bit(1);  // CRC
						send_bit(0);  // CRC
						send_bit(0);  // CRC
						send_bit(1);  // CRC
						send_bit(1);  // CRC
						send_bit(1);  // CRC
						send_bit(0);  // CRC
						send_bit(1);  // CRC
						send_bit(0);  // CRC
						send_bit(0);  // CRC
						send_bit(1);  // CRC
						send_bit(1);  // CRC
						send_bit(1);  // CRC
						send_bit(1);  // CRC
						send_bit(1);  // CRC
						send_bit(1);  // CRC DELIM
						send_bit(1);  // ACK            ack error
						send_bit(0);  // ERROR
						send_bit(0);  // ERROR
						send_bit(0);  // ERROR
						send_bit(0);  // ERROR
						send_bit(0);  // ERROR
						send_bit(0);  // ERROR
						send_bit(1);  // ERROR DELIM
						send_bit(1);  // ERROR DELIM
						send_bit(1);  // ERROR DELIM
						send_bit(1);  // ERROR DELIM
						send_bit(1);  // ERROR DELIM
						send_bit(1);  // ERROR DELIM
						send_bit(1);  // ERROR DELIM
						send_bit(1);  // ERROR DELIM
						send_bit(1);  // INTER
						send_bit(1);  // INTER
						send_bit(1);  // INTER
					end // repeat

					// DUT is error passive now.

					// Read irq register (error interrupt should be cleared now.
					read_register1(8'd3, tmp_data);

					->igor;

					repeat (34) begin
						send_bit(0);  // SOF
						send_bit(1);  // ID
						send_bit(1);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(0);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(1);  // RTR
						send_bit(0);  // IDE
						send_bit(0);  // r0
						send_bit(0);  // DLC
						send_bit(1);  // DLC
						send_bit(1);  // DLC
						send_bit(1);  // DLC
						send_bit(1);  // CRC
						send_bit(0);  // CRC
						send_bit(0);  // CRC
						send_bit(1);  // CRC
						send_bit(1);  // CRC
						send_bit(1);  // CRC
						send_bit(0);  // CRC
						send_bit(1);  // CRC
						send_bit(0);  // CRC
						send_bit(0);  // CRC
						send_bit(1);  // CRC
						send_bit(1);  // CRC
						send_bit(1);  // CRC
						send_bit(1);  // CRC
						send_bit(1);  // CRC
						send_bit(1);  // CRC DELIM
						send_bit(1);  // ACK            ack error
						send_bit(0);  // ERROR
						send_bit(0);  // ERROR
						send_bit(0);  // ERROR
						send_bit(0);  // ERROR
						send_bit(0);  // ERROR
						send_bit(0);  // ERROR
						send_bit(1);  // ERROR DELIM
						send_bit(1);  // ERROR DELIM
						send_bit(1);  // ERROR DELIM
						send_bit(1);  // ERROR DELIM
						send_bit(1);  // ERROR DELIM
						send_bit(1);  // ERROR DELIM
						send_bit(1);  // ERROR DELIM
						send_bit(1);  // ERROR DELIM
						send_bit(1);  // INTER
						send_bit(1);  // INTER
						send_bit(1);  // INTER
						send_bit(1);  // SUSPEND
						send_bit(1);  // SUSPEND
						send_bit(1);  // SUSPEND
						send_bit(1);  // SUSPEND
						send_bit(1);  // SUSPEND
						send_bit(1);  // SUSPEND
						send_bit(1);  // SUSPEND
						send_bit(1);  // SUSPEND
					end // repeat

					->igor;

					// DUT is bus-off now


					// Read irq register (error interrupt should be cleared now.
					read_register1(8'd3, tmp_data);

					#100000;

					// Switch-off reset mode
					write_register1(8'd0, {7'h0, ~(`CAN_MODE_RESET)});

					repeat (64 * 11) begin
						send_bit(1);
					end // repeat

					// Read irq register (error interrupt should be cleared now.
					read_register1(8'd3, tmp_data);

					repeat (64 * 11) begin
						send_bit(1);
					end // repeat

					// Read irq register (error interrupt should be cleared now.
					read_register1(8'd3, tmp_data);
				end
			join

			fork
				begin
					tx_request_command;
				end
				begin
					#1100;

					send_bit(1);    // To spend some time before transmitter is ready.

					repeat (1) begin
						send_bit(0);  // SOF
						send_bit(1);  // ID
						send_bit(1);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(0);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(0);  // ID
						send_bit(1);  // ID
						send_bit(1);  // RTR
						send_bit(0);  // IDE
						send_bit(0);  // r0
						send_bit(0);  // DLC
						send_bit(1);  // DLC
						send_bit(1);  // DLC
						send_bit(1);  // DLC
						send_bit(1);  // CRC
						send_bit(0);  // CRC
						send_bit(0);  // CRC
						send_bit(1);  // CRC
						send_bit(1);  // CRC
						send_bit(1);  // CRC
						send_bit(0);  // CRC
						send_bit(1);  // CRC
						send_bit(0);  // CRC
						send_bit(0);  // CRC
						send_bit(1);  // CRC
						send_bit(1);  // CRC
						send_bit(1);  // CRC
						send_bit(1);  // CRC
						send_bit(1);  // CRC
						send_bit(1);  // CRC DELIM
						send_bit(0);  // ACK
						send_bit(1);  // ACK DELIM
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // EOF
						send_bit(1);  // INTER
						send_bit(1);  // INTER
						send_bit(1);  // INTER
					end // repeat
				end
			join

			read_receive_buffer;
			release_rx_buffer_command;
			read_receive_buffer;
			release_rx_buffer_command;
			read_receive_buffer;

			#4000000;

			receive_frame(0, 0, {26'h00000e8, 3'h1}, 4'h1, 15'h30bb); // mode, rtr, id, length, crc

			#1000000;

		end
	endtask   // bus_off_test



	task send_frame_basic;    // CAN IP core sends frames
		begin

			write_register1(8'd10, 8'hea); // Writing ID[10:3] = 0xea
			write_register1(8'd11, 8'h28); // Writing ID[2:0] = 0x1, rtr = 0, length = 8
			write_register1(8'd12, 8'h56); // data byte 1
			write_register1(8'd13, 8'h78); // data byte 2
			write_register1(8'd14, 8'h9a); // data byte 3
			write_register1(8'd15, 8'hbc); // data byte 4
			write_register1(8'd16, 8'hde); // data byte 5
			write_register1(8'd17, 8'hf0); // data byte 6
			write_register1(8'd18, 8'h0f); // data byte 7
			write_register1(8'd19, 8'hed); // data byte 8

			// Enable irqs (basic mode)
			write_register1(8'd0, 8'h1e);

			fork
				begin
					#1100;
					$display("\n\nStart receiving data from CAN bus");
					receive_frame(0, 0, {26'h00000e8, 3'h1}, 4'h1, 15'h30bb); // mode, rtr, id, length, crc
					receive_frame(0, 0, {26'h00000e8, 3'h1}, 4'h2, 15'h2da1); // mode, rtr, id, length, crc
					receive_frame(0, 0, {26'h00000ee, 3'h1}, 4'h0, 15'h6cea); // mode, rtr, id, length, crc
					receive_frame(0, 0, {26'h00000e8, 3'h1}, 4'h2, 15'h2da1); // mode, rtr, id, length, crc
					receive_frame(0, 0, {26'h00000ee, 3'h1}, 4'h2, 15'h7b4a); // mode, rtr, id, length, crc
					receive_frame(0, 0, {26'h00000ee, 3'h1}, 4'h1, 15'h00c5); // mode, rtr, id, length, crc
				end

				begin
					tx_request_command;
				end

				begin
					wait (can_top_tb.dut1.can_controller.i_can_bsp.go_tx)        // waiting for tx to start
					wait (~can_top_tb.dut1.can_controller.i_can_bsp.need_to_tx)  // waiting for tx to finish
					tx_request_command;                                   // start another tx
				end

				begin
					// Transmitting acknowledge (for first packet)
					wait (can_top_tb.dut1.can_controller.i_can_bsp.tx_state & can_top_tb.dut1.can_controller.i_can_bsp.rx_ack & can_top_tb.dut1.can_controller.i_can_bsp.tx_point);
					#1 rx = 0;
					wait (can_top_tb.dut1.can_controller.i_can_bsp.rx_ack_lim & can_top_tb.dut1.can_controller.i_can_bsp.tx_point);
					#1 rx = 1;

					// Transmitting acknowledge (for second packet)
					wait (can_top_tb.dut1.can_controller.i_can_bsp.tx_state & can_top_tb.dut1.can_controller.i_can_bsp.rx_ack & can_top_tb.dut1.can_controller.i_can_bsp.tx_point);
					#1 rx = 0;
					wait (can_top_tb.dut1.can_controller.i_can_bsp.rx_ack_lim & can_top_tb.dut1.can_controller.i_can_bsp.tx_point);
					#1 rx = 1;
				end
			join

			read_receive_buffer;
			release_rx_buffer_command;
			release_rx_buffer_command;
			read_receive_buffer;
			release_rx_buffer_command;
			read_receive_buffer;

			#200000;

			read_receive_buffer;

			// Read irq register
			read_register1(8'd3, tmp_data);
			#1000;
		end
	endtask   // send_frame_basic



	task send_frame_extended;    // CAN IP core sends basic or extended frames in extended mode
		begin

			// Switch-on reset mode
			write_register1(8'd0, {7'h0, (`CAN_MODE_RESET)});
			write_register2(8'd0, {7'h0, (`CAN_MODE_RESET)});

			// Set Clock Divider register
			extended_mode = 1'b1;
			write_register1(8'd31, {extended_mode, 7'h0});    // Setting the extended mode
			write_register2(8'd31, {extended_mode, 7'h0});    // Setting the extended mode

			// Set Acceptance Code and Acceptance Mask registers
			write_register1(8'd16, 8'ha6); // acceptance code 0
			write_register1(8'd17, 8'hb0); // acceptance code 1
			write_register1(8'd18, 8'h12); // acceptance code 2
			write_register1(8'd19, 8'h30); // acceptance code 3
			write_register1(8'd20, 8'h00); // acceptance mask 0
			write_register1(8'd21, 8'h00); // acceptance mask 1
			write_register1(8'd22, 8'h00); // acceptance mask 2
			write_register1(8'd23, 8'h00); // acceptance mask 3

			write_register2(8'd16, 8'ha6); // acceptance code 0
			write_register2(8'd17, 8'hb0); // acceptance code 1
			write_register2(8'd18, 8'h12); // acceptance code 2
			write_register2(8'd19, 8'h30); // acceptance code 3
			write_register2(8'd20, 8'h00); // acceptance mask 0
			write_register2(8'd21, 8'h00); // acceptance mask 1
			write_register2(8'd22, 8'h00); // acceptance mask 2
			write_register2(8'd23, 8'h00); // acceptance mask 3

			// Switch-off reset mode
			write_register1(8'd0, {7'h0, ~(`CAN_MODE_RESET)});
			write_register2(8'd0, {7'h0, ~(`CAN_MODE_RESET)});

			// After exiting the reset mode sending bus free
			repeat (11) send_bit(1);


			/*  Basic frame format
			// Writing TX frame information + identifier + data
			write_register1(8'd16, 8'h45);   // Frame format = 0, Remote transmision request = 1, DLC = 5
			write_register1(8'd17, 8'ha6);   // ID[28:21] = a6
			write_register1(8'd18, 8'ha0);   // ID[20:18] = 5
			// write_register1(8'd19, 8'h78); RTR does not send any data
			// write_register1(8'd20, 8'h9a);
			// write_register1(8'd21, 8'hbc);
			// write_register1(8'd22, 8'hde);
			// write_register1(8'd23, 8'hf0);
			// write_register1(8'd24, 8'h0f);
			// write_register1(8'd25, 8'hed);
			// write_register1(8'd26, 8'hcb);
			// write_register1(8'd27, 8'ha9);
			// write_register1(8'd28, 8'h87);
			*/

			// Extended frame format
			// Writing TX frame information + identifier + data
			write_register1(8'd16, 8'hc5);   // Frame format = 1, Remote transmision request = 1, DLC = 5
			write_register1(8'd17, 8'ha6);   // ID[28:21] = a6
			write_register1(8'd18, 8'h00);   // ID[20:13] = 00
			write_register1(8'd19, 8'h5a);   // ID[12:5]  = 5a
			write_register1(8'd20, 8'ha8);   // ID[4:0]   = 15
			write_register2(8'd16, 8'hc5);   // Frame format = 1, Remote transmision request = 1, DLC = 5
			write_register2(8'd17, 8'ha6);   // ID[28:21] = a6
			write_register2(8'd18, 8'h00);   // ID[20:13] = 00
			write_register2(8'd19, 8'h5a);   // ID[12:5]  = 5a
			write_register2(8'd20, 8'ha8);   // ID[4:0]   = 15
			// write_register1(8'd21, 8'h78); RTR does not send any data
			// write_register1(8'd22, 8'h9a);
			// write_register1(8'd23, 8'hbc);
			// write_register1(8'd24, 8'hde);
			// write_register1(8'd25, 8'hf0);
			// write_register1(8'd26, 8'h0f);
			// write_register1(8'd27, 8'hed);
			// write_register1(8'd28, 8'hcb);


			// Enabling IRQ's (extended mode)
			write_register1(8'd4, 8'hff);
			write_register2(8'd4, 8'hff);


			fork
				begin
					#1251;
					$display("\n\nStart receiving data from CAN bus");
					/* Standard frame format
					receive_frame(0, 0, {26'h00000a0, 3'h1}, 4'h1, 15'h2d9c); // mode, rtr, id, length, crc
					receive_frame(0, 0, {26'h00000a0, 3'h1}, 4'h2, 15'h46b4); // mode, rtr, id, length, crc
					receive_frame(0, 0, {26'h00000af, 3'h1}, 4'h0, 15'h42cd); // mode, rtr, id, length, crc
					receive_frame(0, 0, {26'h00000af, 3'h1}, 4'h1, 15'h555f); // mode, rtr, id, length, crc
					receive_frame(0, 0, {26'h00000af, 3'h1}, 4'h2, 15'h6742); // mode, rtr, id, length, crc
					*/

					// Extended frame format
					receive_frame(1, 0, {8'ha6, 8'h00, 8'h5a, 5'h14}, 4'h1, 15'h1528); // mode, rtr, id, length, crc
					receive_frame(1, 0, {8'ha6, 8'h00, 8'h5a, 5'h15}, 4'h2, 15'h3d2d); // mode, rtr, id, length, crc
					receive_frame(1, 0, {8'ha6, 8'h00, 8'h5a, 5'h15}, 4'h0, 15'h23aa); // mode, rtr, id, length, crc
					receive_frame(1, 0, {8'ha6, 8'h00, 8'h5a, 5'h15}, 4'h1, 15'h2d22); // mode, rtr, id, length, crc
					receive_frame(1, 0, {8'ha6, 8'h00, 8'h5a, 5'h15}, 4'h2, 15'h3d2d); // mode, rtr, id, length, crc

				end

				begin
					tx_request_command;
				end

				begin
					// Transmitting acknowledge
					wait (can_top_tb.dut1.can_controller.i_can_bsp.tx_state & can_top_tb.dut1.can_controller.i_can_bsp.rx_ack & can_top_tb.dut1.can_controller.i_can_bsp.tx_point);
					#1 rx = 0;
					wait (can_top_tb.dut1.can_controller.i_can_bsp.rx_ack_lim & can_top_tb.dut1.can_controller.i_can_bsp.tx_point);
					#1 rx = 1;
				end

				begin   // Reading irq and arbitration lost capture register

					repeat(1) begin
						while (~(can_top_tb.dut1.can_controller.i_can_bsp.rx_crc_lim & can_top_tb.dut1.can_controller.i_can_bsp.sample_point)) begin
							@(posedge dut_clk);
						end

						// Read irq register
						#1 read_register1(8'd3, tmp_data);

						// Read arbitration lost capture register
						read_register1(8'd11, tmp_data);
					end


					repeat(1) begin
						while (~(can_top_tb.dut1.can_controller.i_can_bsp.rx_crc_lim & can_top_tb.dut1.can_controller.i_can_bsp.sample_point)) begin
							@(posedge dut_clk);
						end

						// Read irq register
						#1 read_register1(8'd3, tmp_data);
					end

					repeat(1) begin
						while (~(can_top_tb.dut1.can_controller.i_can_bsp.rx_crc_lim & can_top_tb.dut1.can_controller.i_can_bsp.sample_point)) begin
							@(posedge dut_clk);
						end

						// Read arbitration lost capture register
						read_register1(8'd11, tmp_data);
					end

				end

				begin
					# 344000;

					// Switch-on reset mode
					$display("expect: SW reset ON\n");
					write_register1(8'd0, {7'h0, (`CAN_MODE_RESET)});

					#40000;
					// Switch-off reset mode
					$display("expect: SW reset OFF\n");
					write_register1(8'd0, {7'h0, (~`CAN_MODE_RESET)});
				end

			join

			read_receive_buffer;
			release_rx_buffer_command;
			release_rx_buffer_command;
			read_receive_buffer;
			release_rx_buffer_command;
			read_receive_buffer;
			release_rx_buffer_command;
			read_receive_buffer;
			release_rx_buffer_command;
			read_receive_buffer;

			#200000;

			read_receive_buffer;

			// Read irq register
			read_register1(8'd3, tmp_data);
			#1000;

		end
	endtask   // send_frame_extended



	task self_reception_request;    // CAN IP core sends sets self reception mode and transmits a msg. This test runs in EXTENDED mode
		begin

			// Switch-on reset mode
			write_register1(8'd0, {7'h0, (`CAN_MODE_RESET)});

			// Set Clock Divider register
			extended_mode = 1'b1;
			write_register1(8'd31, {extended_mode, 7'h0});    // Setting the extended mode

			// Set Acceptance Code and Acceptance Mask registers
			write_register1(8'd16, 8'ha6); // acceptance code 0
			write_register1(8'd17, 8'hb0); // acceptance code 1
			write_register1(8'd18, 8'h12); // acceptance code 2
			write_register1(8'd19, 8'h30); // acceptance code 3
			write_register1(8'd20, 8'h00); // acceptance mask 0
			write_register1(8'd21, 8'h00); // acceptance mask 1
			write_register1(8'd22, 8'h00); // acceptance mask 2
			write_register1(8'd23, 8'h00); // acceptance mask 3

			// Setting the "self test mode"
			write_register1(8'd0, 8'h4);

			// Switch-off reset mode
			write_register1(8'd0, {7'h0, ~(`CAN_MODE_RESET)});

			// After exiting the reset mode sending bus free
			repeat (11) send_bit(1);


			// Writing TX frame information + identifier + data
			write_register1(8'd16, 8'h45);   // Frame format = 0, Remote transmision request = 1, DLC = 5
			write_register1(8'd17, 8'ha6);   // ID[28:21] = a6
			write_register1(8'd18, 8'ha0);   // ID[20:18] = 5
			// write_register1(8'd19, 8'h78); RTR does not send any data
			// write_register1(8'd20, 8'h9a);
			// write_register1(8'd21, 8'hbc);
			// write_register1(8'd22, 8'hde);
			// write_register1(8'd23, 8'hf0);
			// write_register1(8'd24, 8'h0f);
			// write_register1(8'd25, 8'hed);
			// write_register1(8'd26, 8'hcb);
			// write_register1(8'd27, 8'ha9);
			// write_register1(8'd28, 8'h87);


			// Enabling IRQ's (extended mode)
			write_register1(8'd4, 8'hff);

			self_reception_request_command;

			#400000;

			read_receive_buffer;
			release_rx_buffer_command;
			release_rx_buffer_command;
			read_receive_buffer;
			release_rx_buffer_command;
			read_receive_buffer;
			release_rx_buffer_command;
			read_receive_buffer;
			release_rx_buffer_command;
			read_receive_buffer;


			read_receive_buffer;

			// Read irq register
			read_register1(8'd3, tmp_data);
			#1000;

		end
	endtask   // self_reception_request



	task test_empty_fifo;
		begin

			// Enable irqs (basic mode)
			write_register1(8'd0, 8'h1e);

			receive_frame(0, 0, {26'h00000e8, 3'h1}, 4'h3, 15'h56a9); // mode, rtr, id, length, crc
			receive_frame(0, 0, {26'h00000e8, 3'h1}, 4'h7, 15'h391d); // mode, rtr, id, length, crc

			read_receive_buffer;
			fifo_info;

			release_rx_buffer_command;
			$display("\n\n");
			read_receive_buffer;
			fifo_info;

			release_rx_buffer_command;
			$display("\n\n");
			read_receive_buffer;
			fifo_info;

			release_rx_buffer_command;
			$display("\n\n");
			read_receive_buffer;
			fifo_info;

			receive_frame(0, 0, {26'h00000e8, 3'h1}, 4'h8, 15'h70e0); // mode, rtr, id, length, crc

			$display("\n\n");
			read_receive_buffer;
			fifo_info;

			release_rx_buffer_command;
			$display("\n\n");
			read_receive_buffer;
			fifo_info;

			release_rx_buffer_command;
			$display("\n\n");
			read_receive_buffer;
			fifo_info;
		end
	endtask



	task test_empty_fifo_ext;
		begin
			receive_frame(1, 0, 29'h14d60246, 4'h3, 15'h5262); // mode, rtr, id, length, crc
			receive_frame(1, 0, 29'h14d60246, 4'h7, 15'h1730); // mode, rtr, id, length, crc

			read_receive_buffer;
			fifo_info;

			release_rx_buffer_command;
			$display("\n\n");
			read_receive_buffer;
			fifo_info;

			release_rx_buffer_command;
			$display("\n\n");
			read_receive_buffer;
			fifo_info;

			release_rx_buffer_command;
			$display("\n\n");
			read_receive_buffer;
			fifo_info;

			receive_frame(1, 0, 29'h14d60246, 4'h8, 15'h2f7a); // mode, rtr, id, length, crc

			$display("\n\n");
			read_receive_buffer;
			fifo_info;

			release_rx_buffer_command;
			$display("\n\n");
			read_receive_buffer;
			fifo_info;

			release_rx_buffer_command;
			$display("\n\n");
			read_receive_buffer;
			fifo_info;
		end
	endtask



	task test_full_fifo;
		begin

			// Enable irqs (basic mode)
			// write_register1(8'd0, 8'h1e);
			write_register1(8'd0, 8'h10); // enable only overrun irq

			$display("\n\n");

			receive_frame(0, 0, {26'h00000e8, 3'h1}, 4'h0, 15'h2372); // mode, rtr, id, length, crc
			fifo_info;
			receive_frame(0, 0, {26'h00000e8, 3'h1}, 4'h1, 15'h30bb); // mode, rtr, id, length, crc
			fifo_info;
			receive_frame(0, 0, {26'h00000e8, 3'h1}, 4'h2, 15'h2da1); // mode, rtr, id, length, crc
			fifo_info;
			receive_frame(0, 0, {26'h00000e8, 3'h1}, 4'h3, 15'h56a9); // mode, rtr, id, length, crc
			fifo_info;
			receive_frame(0, 0, {26'h00000e8, 3'h1}, 4'h4, 15'h3124); // mode, rtr, id, length, crc
			fifo_info;
			receive_frame(0, 0, {26'h00000e8, 3'h1}, 4'h5, 15'h6944); // mode, rtr, id, length, crc
			fifo_info;
			receive_frame(0, 0, {26'h00000e8, 3'h1}, 4'h6, 15'h5182); // mode, rtr, id, length, crc
			fifo_info;
			receive_frame(0, 0, {26'h00000e8, 3'h1}, 4'h7, 15'h391d); // mode, rtr, id, length, crc
			fifo_info;
			receive_frame(0, 0, {26'h00000e8, 3'h1}, 4'h8, 15'h70e0); // mode, rtr, id, length, crc
			fifo_info;
			receive_frame(0, 0, {26'h00000e8, 3'h1}, 4'h8, 15'h70e0); // mode, rtr, id, length, crc
			fifo_info;
			$display("FIFO should be full now");
			$display("2 packets won't be received because of the overrun. IRQ should be set");

			// Following one is accepted with overrun
			receive_frame(0, 0, {26'h00000e8, 3'h1}, 4'h8, 15'h70e0); // mode, rtr, id, length, crc
			fifo_info;

			// Following one is accepted with overrun
			receive_frame(0, 0, {26'h00000e8, 3'h1}, 4'h8, 15'h70e0); // mode, rtr, id, length, crc
			fifo_info;

			$display("Now we'll release 1 packet.");
			release_rx_buffer_command;
			fifo_info;

			// Space just enough for the following frame.
			$display("Getting 1 small packet (just big enough). Fifo is full again");
			receive_frame(0, 0, {26'h00000e8, 3'h1}, 4'h0, 15'h2372); // mode, rtr, id, length, crc
			fifo_info;

			// Following accepted with overrun
			$display("1 packets won't be received because of the overrun. IRQ should be set");
			receive_frame(0, 0, {26'h00000e8, 3'h1}, 4'h8, 15'h70e0); // mode, rtr, id, length, crc
			fifo_info;

			// Following accepted with overrun
			$display("1 packets won't be received because of the overrun. IRQ should be set");
			receive_frame(0, 0, {26'h00000e8, 3'h1}, 4'h8, 15'h70e0); // mode, rtr, id, length, crc
			fifo_info;
			//    read_overrun_info(0, 15);

			$display("Releasing 3 packets.");
			release_rx_buffer_command;
			release_rx_buffer_command;

			release_rx_buffer_command;
			read_receive_buffer;
			fifo_info;
			receive_frame(0, 0, {26'h00000e8, 3'h1}, 4'h8, 15'h70e0); // mode, rtr, id, length, crc
			fifo_info;
			//    read_overrun_info(0, 15);
			$display("\n\n");

			release_rx_buffer_command;
			read_receive_buffer;
			fifo_info;

			release_rx_buffer_command;
			read_receive_buffer;
			fifo_info;

			release_rx_buffer_command;
			read_receive_buffer;
			fifo_info;

			release_rx_buffer_command;
			read_receive_buffer;
			fifo_info;

			release_rx_buffer_command;
			read_receive_buffer;
			fifo_info;

			release_rx_buffer_command;
			read_receive_buffer;
			fifo_info;

			clear_data_overrun_command;

			release_rx_buffer_command;
			read_receive_buffer;
			fifo_info;

			release_rx_buffer_command;
			read_receive_buffer;
			fifo_info;

			clear_data_overrun_command;

			release_rx_buffer_command;
			read_receive_buffer;
			fifo_info;

			release_rx_buffer_command;
			read_receive_buffer;
			fifo_info;

			release_rx_buffer_command;
			read_receive_buffer;
			fifo_info;

			release_rx_buffer_command;
			read_receive_buffer;
			fifo_info;

			release_rx_buffer_command;
			read_receive_buffer;
			fifo_info;

			// Read irq register
			read_register1(8'd3, tmp_data);

			// Read irq register
			read_register1(8'd3, tmp_data);
			#1000;

		end
	endtask



	task test_full_fifo_ext;
		begin
			release_rx_buffer_command;
			$display("\n\n");
			read_receive_buffer;
			fifo_info;

			receive_frame(1, 0, 29'h14d60246, 4'h0, 15'h6f54); // mode, rtr, id, length, crc
			read_receive_buffer;
			fifo_info;
			receive_frame(1, 0, 29'h14d60246, 4'h1, 15'h6d38); // mode, rtr, id, length, crc
			read_receive_buffer;
			fifo_info;
			receive_frame(1, 0, 29'h14d60246, 4'h2, 15'h053e); // mode, rtr, id, length, crc
			fifo_info;
			read_receive_buffer;
			receive_frame(1, 0, 29'h14d60246, 4'h3, 15'h5262); // mode, rtr, id, length, crc
			fifo_info;
			receive_frame(1, 0, 29'h14d60246, 4'h4, 15'h4bba); // mode, rtr, id, length, crc
			fifo_info;
			receive_frame(1, 0, 29'h14d60246, 4'h5, 15'h4d7d); // mode, rtr, id, length, crc
			fifo_info;
			receive_frame(1, 0, 29'h14d60246, 4'h6, 15'h6f40); // mode, rtr, id, length, crc
			fifo_info;
			receive_frame(1, 0, 29'h14d60246, 4'h7, 15'h1730); // mode, rtr, id, length, crc
			fifo_info;
			//    read_overrun_info(0, 10);

			release_rx_buffer_command;
			release_rx_buffer_command;
			fifo_info;
			receive_frame(1, 0, 29'h14d60246, 4'h8, 15'h2f7a); // mode, rtr, id, length, crc
			fifo_info;
			//    read_overrun_info(0, 15);
			$display("\n\n");

			release_rx_buffer_command;
			read_receive_buffer;
			fifo_info;

			release_rx_buffer_command;
			read_receive_buffer;
			fifo_info;

			release_rx_buffer_command;
			read_receive_buffer;
			fifo_info;

			release_rx_buffer_command;
			read_receive_buffer;
			fifo_info;

			release_rx_buffer_command;
			read_receive_buffer;
			fifo_info;

			release_rx_buffer_command;
			read_receive_buffer;
			fifo_info;

			release_rx_buffer_command;
			read_receive_buffer;
			fifo_info;

		end
	endtask


	task test_reset_mode;
		begin
			release_rx_buffer_command;
			$display("\n\n");
			read_receive_buffer;
			fifo_info;
			$display("expect: Until now no data was received\n");

			receive_frame(1, 0, 29'h14d60246, 4'h0, 15'h6f54); // mode, rtr, id, length, crc
			receive_frame(1, 0, 29'h14d60246, 4'h1, 15'h6d38); // mode, rtr, id, length, crc
			receive_frame(1, 0, 29'h14d60246, 4'h2, 15'h053e); // mode, rtr, id, length, crc

			fifo_info;
			read_receive_buffer;
			$display("expect: 3 packets should be received (totally 18 bytes)\n");

			release_rx_buffer_command;
			fifo_info;
			read_receive_buffer;
			$display("expect: 2 packets should be received (totally 13 bytes)\n");


			$display("expect: SW reset performed\n");

			// Switch-on reset mode
			write_register1(8'd0, {7'h0, `CAN_MODE_RESET});

			// Switch-off reset mode
			write_register1(8'd0, {7'h0, ~(`CAN_MODE_RESET)});

			fifo_info;
			read_receive_buffer;
			$display("expect: The above read was after the SW reset.\n");

			receive_frame(1, 0, 29'h14d60246, 4'h3, 15'h5262); // mode, rtr, id, length, crc
			fifo_info;
			read_receive_buffer;
			$display("expect: 1 packets should be received (totally 8 bytes). See above.\n");

			// Switch-on reset mode
			$display("expect: SW reset ON\n");
			write_register1(8'd0, {7'h0, `CAN_MODE_RESET});

			receive_frame(1, 0, 29'h14d60246, 4'h5, 15'h4d7d); // mode, rtr, id, length, crc

			fifo_info;
			read_receive_buffer;
			$display("expect: 0 packets should be received because we are in reset. (totally 0 bytes). See above.\n");

			/*
			fork
				begin
					receive_frame(1, 0, 29'h14d60246, 4'h4, 15'h4bba); // mode, rtr, id, length, crc
				end
				begin
					// Switch-on reset mode
					write_register1(8'd0, {7'h0, `CAN_MODE_RESET});

					// Switch-off reset mode
					write_register1(8'd0, {7'h0, ~(`CAN_MODE_RESET)});


				end

			join
			*/

			fifo_info;
			receive_frame(1, 0, 29'h14d60246, 4'h5, 15'h4d7d); // mode, rtr, id, length, crc
			fifo_info;
			receive_frame(1, 0, 29'h14d60246, 4'h6, 15'h6f40); // mode, rtr, id, length, crc
			fifo_info;
			receive_frame(1, 0, 29'h14d60246, 4'h7, 15'h1730); // mode, rtr, id, length, crc
			fifo_info;
			//    read_overrun_info(0, 10);

			release_rx_buffer_command;
			release_rx_buffer_command;
			fifo_info;



			// Switch-off reset mode
			$display("expect: SW reset OFF\n");
			write_register1(8'd0, {7'h0, (~`CAN_MODE_RESET)});

			receive_frame(1, 0, 29'h14d60246, 4'h8, 15'h2f7a); // mode, rtr, id, length, crc
			fifo_info;
			read_receive_buffer;
			$display("expect: 1 packets should be received (totally 13 bytes). See above.\n");

			release_rx_buffer_command;
			fifo_info;
			read_receive_buffer;
			$display("expect: 0 packets should be received (totally 0 bytes). See above.\n");
			$display("\n\n");


			fork
				receive_frame(1, 0, 29'h14d60246, 4'h5, 15'h4d7d); // mode, rtr, id, length, crc

				begin
					#8000;
					// Switch-off reset mode
					$display("expect: SW reset ON while receiving a packet\n");
					write_register1(8'd0, {7'h0, `CAN_MODE_RESET});
				end
			join


			read_receive_buffer;
			fifo_info;
			$display("expect: 0 packets should be received (totally 0 bytes) because CAN was in reset. See above.\n");

			release_rx_buffer_command;
			read_receive_buffer;
			fifo_info;

		end
	endtask   // test_reset_mode


	/*
	task initialize_fifo;
		integer i;
		begin
			for (i=0; i<32; i=i+1)
			begin
				can_top_tb.dut1.can_controller.i_can_bsp.i_can_fifo.length_info[i] = 0;
				can_top_tb.dut1.can_controller.i_can_bsp.i_can_fifo.overrun_info[i] = 0;
			end

			for (i=0; i<64; i=i+1)
			begin
				can_top_tb.dut1.can_controller.i_can_bsp.i_can_fifo.fifo[i] = 0;
			end

			$display("(%0t) Fifo initialized", $time);
		end
	endtask
	*/
	/*
	task read_overrun_info;
		input [4:0] start_addr;
		input [4:0] end_addr;
		integer i;
		begin
			for (i=start_addr; i<=end_addr; i=i+1)
			begin
				$display("len[0x%0x]=0x%0x", i, can_top_tb.dut1.can_controller.i_can_bsp.i_can_fifo.length_info[i]);
				$display("overrun[0x%0x]=0x%0x\n", i, can_top_tb.dut1.can_controller.i_can_bsp.i_can_fifo.overrun_info[i]);
			end
		end
	endtask
	*/

	task fifo_info;   // Displaying how many packets and how many bytes are in fifo. Not working when wr_info_pointer is smaller than rd_info_pointer.
		begin
			$display("(%0t) Currently %0d bytes in fifo (%0d packets)", $time, can_top_tb.dut1.can_controller.i_can_bsp.i_can_fifo.fifo_cnt,
				(can_top_tb.dut1.can_controller.i_can_bsp.i_can_fifo.wr_info_pointer - can_top_tb.dut1.can_controller.i_can_bsp.i_can_fifo.rd_info_pointer));
		end
	endtask



	/*
	 * task to read a register via the connected bus.
	 * @dut: which device to interface with (1 or 2)
	 * @reg_addr: address of register to read
	 * @reg_data: output value
	 */
	task read_register_wb;
		input integer dut;
		input [7:0] reg_addr;
		output [7:0] reg_data;

		begin
			wait (bus_free);
			bus_free = 0;

			@(posedge dut_wb_clk_i);
			#1;
			dut_wb_adr_i = reg_addr;
			if(dut == 1) begin
				dut_wb_cyc_i1 = 1;
			end else if(dut == 2) begin
				dut_wb_cyc_i2 = 1;
			end
			dut_wb_stb_i = 1;
			dut_wb_we_i = 0;
			if(dut == 1) begin
				wait (dut_wb_ack_o1);
				reg_data = dut_wb_dat_o1;
			end else if(dut == 2) begin
				wait (dut_wb_ack_o2);
				reg_data = dut_wb_dat_o2;
			end
			@(posedge dut_wb_clk_i);
			#1;
			dut_wb_adr_i = 'hz;
			if(dut == 1) begin
				dut_wb_cyc_i1 = 0;
			end else if(dut == 2) begin
				dut_wb_cyc_i2 = 0;
			end
			dut_wb_stb_i = 0;
			dut_wb_we_i = 'hz;

			$display("(%012t) DUT%1d GET register %0d == 0x%0x", $time, dut, reg_addr, reg_data);
			bus_free = 1;
		end
	endtask

	/* read a register of dut2 */
	task read_register1;
		input [7:0] reg_addr;
		output [7:0] reg_data;
		begin
			read_register_wb(1, reg_addr, reg_data);
		end
	endtask

	/* read a register of dut2 */
	task read_register2;
		input [7:0] reg_addr;
		output [7:0] reg_data;
		begin
			read_register_wb(2, reg_addr, reg_data);
		end
	endtask



	/*
	 * task to write a register via the connected bus.
	 * @dut: which device to interface with (1 or 2)
	 * @reg_addr: address of register to write
	 * @reg_data: output value
	 */
	task write_register_wb;
		input integer dut;
		input [7:0] reg_addr;
		input [7:0] reg_data;

		begin
			wait (bus_free);
			bus_free = 0;
			$display("(%012t) DUT%1d SET register %0d := 0x%0x", $time, dut, reg_addr, reg_data);

			@(posedge dut_wb_clk_i);
			#1;
			dut_wb_adr_i = reg_addr;
			dut_wb_dat_i = reg_data;
			if(dut == 1) begin
				dut_wb_cyc_i1 = 1;
			end else if(dut == 2) begin
				dut_wb_cyc_i2 = 1;
			end
			dut_wb_stb_i = 1;
			dut_wb_we_i = 1;
			if(dut == 1) begin
				wait (dut_wb_ack_o1);
			end else if(dut == 2) begin
				wait (dut_wb_ack_o2);
			end
			@(posedge dut_wb_clk_i);
			#1;
			dut_wb_adr_i = 'hz;
			dut_wb_dat_i = 'hz;
			if(dut == 1) begin
				dut_wb_cyc_i1 = 0;
			end else if(dut == 2) begin
				dut_wb_cyc_i2 = 0;
			end
			dut_wb_stb_i = 0;
			dut_wb_we_i = 'hz;

			bus_free = 1;
		end
	endtask

	/* write a register of dut1 */
	task write_register1;
		input [7:0] reg_addr;
		input [7:0] reg_data;
		begin
			write_register_wb(1, reg_addr, reg_data);
		end
	endtask

	/* write a register of dut2 */
	task write_register2;
		input [7:0] reg_addr;
		input [7:0] reg_data;
		begin
			write_register_wb(2, reg_addr, reg_data);
		end
	endtask



	task read_receive_buffer;
		integer i;
		begin
			$display("\n\n(%0t)", $time);
			if(extended_mode) begin
				// Extended mode
				for (i=8'd16; i<=8'd28; i=i+1) begin
					read_register1(i, tmp_data);
				end
				/*
				if(can_top_tb.dut1.can_controller.i_can_bsp.i_can_fifo.overrun) begin
					$display("\nWARNING: Above packet was received with overrun.");
				end
				*/
			end else begin
				for (i=8'd20; i<=8'd29; i=i+1) begin
					read_register1(i, tmp_data);
				end
				/*
				if(can_top_tb.dut1.can_controller.i_can_bsp.i_can_fifo.overrun) begin
					$display("\nWARNING: Above packet was received with overrun.");
				end
				*/
			end
		end
	endtask


	task release_rx_buffer_command;
		begin
			write_register1(8'd1, 8'h4);
			$display("(%0t) Rx buffer released.", $time);
		end
	endtask


	task tx_request_command;
		begin
			write_register1(8'd1, 8'h1);
			$display("(%0t) Tx requested.", $time);
		end
	endtask


	task tx_abort_command;
		begin
			write_register1(8'd1, 8'h2);
			$display("(%0t) Tx abort requested.", $time);
		end
	endtask


	task clear_data_overrun_command;
		begin
			write_register1(8'd1, 8'h8);
			$display("(%0t) Data overrun cleared.", $time);
		end
	endtask


	task self_reception_request_command;
		begin
			write_register1(8'd1, 8'h10);
			$display("(%0t) Self reception requested.", $time);
		end
	endtask


	task test_synchronization;
		begin
			// Hard synchronization
			#1 rx=0;
			repeat (2*BRP) @(posedge dut_clk);
			repeat (8*BRP) @(posedge dut_clk);
			#1 rx=1;
			repeat (10*BRP) @(posedge dut_clk);

			// Resynchronization on time
			#1 rx=0;
			repeat (10*BRP) @(posedge dut_clk);
			#1 rx=1;
			repeat (10*BRP) @(posedge dut_clk);

			// Resynchronization late
			repeat (BRP) @(posedge dut_clk);
			repeat (BRP) @(posedge dut_clk);
			#1 rx=0;
			repeat (10*BRP) @(posedge dut_clk);
			#1 rx=1;

			// Resynchronization early
			repeat (8*BRP) @(posedge dut_clk);   // two frames too early
			#1 rx=0;
			repeat (10*BRP) @(posedge dut_clk);
			#1 rx=1;
			// Resynchronization early
			repeat (11*BRP) @(posedge dut_clk);   // one frames too late
			#1 rx=0;
			repeat (10*BRP) @(posedge dut_clk);
			#1 rx=1;

			repeat (10*BRP) @(posedge dut_clk);
			#1 rx=0;
			repeat (10*BRP) @(posedge dut_clk);
		end
	endtask


	task send_bit;
		input bit;
		integer cnt;
		begin
			#1 rx=bit;
			repeat ((`CAN_TIMING1_TSEG1 + `CAN_TIMING1_TSEG2 + 3)*BRP) @(posedge dut_clk);
		end
	endtask


	task receive_frame;           // CAN IP core receives frames
		input mode;
		input remote_trans_req;
		input [28:0] id;
		input  [3:0] length;
		input [14:0] crc;

		reg [117:0] data;
		reg         previous_bit;
		reg         stuff;
		reg         tmp;
		reg         arbitration_lost;
		integer     pointer;
		integer     cnt;
		integer     total_bits;
		integer     stuff_cnt;

		begin

			stuff_cnt = 1;
			stuff = 0;

			if(mode) begin
				// Extended format
				data = {id[28:18], 1'b1, 1'b1, id[17:0], remote_trans_req, 2'h0, length};
			end else begin
				// Standard format
				data = {id[10:0], remote_trans_req, 1'b0, 1'b0, length};
			end

			if(~remote_trans_req) begin
				if(length) begin
					// Send data if length is > 0
					for (cnt=1; cnt<=(2*length); cnt=cnt+1)  // data   (we are sending nibbles)
						data = {data[113:0], cnt[3:0]};
				end
			end

			// Adding CRC
			data = {data[104:0], crc[14:0]};


			// Calculating pointer that points to the bit that will be send
			if(remote_trans_req) begin
				if(mode) begin
					// Extended format
					pointer = 52;
				end else begin
					// Standard format
					pointer = 32;
				end
			end else begin
				if(mode) begin
					// Extended format
					pointer = 52 + 8 * length;
				end else begin
					// Standard format
					pointer = 32 + 8 * length;
				end
			end

			// This is how many bits we need to shift
			total_bits = pointer;

			// Waiting until previous msg is finished before sending another one
			if(arbitration_lost) begin
				//  Arbitration lost. Another DUT is transmitting. We have to wait until it is finished.
				wait ( (~can_top_tb.dut1.can_controller.i_can_bsp.error_frame) &
					(~can_top_tb.dut1.can_controller.i_can_bsp.rx_inter   ) &
					(~can_top_tb.dut1.can_controller.i_can_bsp.tx_state   ) );
			end else begin
				// We were transmitter of the previous frame. No need to wait for another DUT to finish transmission.
				wait ( (~can_top_tb.dut1.can_controller.i_can_bsp.error_frame) &
					(~can_top_tb.dut1.can_controller.i_can_bsp.rx_inter   ));
			end
			arbitration_lost = 0;

			send_bit(0);                        // SOF
			previous_bit = 0;

			fork

				begin
					for (cnt=0; cnt<=total_bits; cnt=cnt+1) begin
						if(stuff_cnt == 5) begin
							stuff_cnt = 1;
							total_bits = total_bits + 1;
							stuff = 1;
							tmp = ~data[pointer+1];
							send_bit(~data[pointer+1]);
							previous_bit = ~data[pointer+1];
						end else begin
							if(data[pointer] == previous_bit) begin
								stuff_cnt <= stuff_cnt + 1;
							end else begin
								stuff_cnt <= 1;
							end

							stuff = 0;
							tmp = data[pointer];
							send_bit(data[pointer]);
							previous_bit = data[pointer];
							pointer = pointer - 1;
						end
						if(arbitration_lost) begin
							cnt=total_bits+1;         // Exit the for loop
						end
					end

					// Nothing send after the data (just recessive bit)
					repeat (13) send_bit(1);         // CRC delimiter + ack + ack delimiter + EOF + intermission= 1 + 1 + 1 + 7 + 3
				end

				begin
					while (mode ? (cnt<32) : (cnt<12)) begin
						#1 wait (can_top_tb.dut1.can_controller.sample_point);
						if(mode) begin
							if(cnt<32 & tmp & (~dut_rx)) begin
								arbitration_lost = 1;
								rx = 1;       // Only recessive is send from now on.
							end
						end else begin
							if(cnt<12 & tmp & (~dut_rx)) begin
								arbitration_lost = 1;
								rx = 1;       // Only recessive is send from now on.
							end
						end
					end
				end

			join

		end
	endtask



	// State machine monitor (btl)
	always @(posedge dut_clk) begin
		if(can_top_tb.dut1.can_controller.i_can_btl.go_sync & can_top_tb.dut1.can_controller.i_can_btl.go_seg1
			| can_top_tb.dut1.can_controller.i_can_btl.go_sync & can_top_tb.dut1.can_controller.i_can_btl.go_seg2
			| can_top_tb.dut1.can_controller.i_can_btl.go_seg1 & can_top_tb.dut1.can_controller.i_can_btl.go_seg2) begin

			$display("(%0t) ERROR multiple go_sync, go_seg1 or go_seg2 occurance\n\n", $time);
			#1000;
			$stop;
		end

		if(can_top_tb.dut1.can_controller.i_can_btl.sync & can_top_tb.dut1.can_controller.i_can_btl.seg1
			| can_top_tb.dut1.can_controller.i_can_btl.sync & can_top_tb.dut1.can_controller.i_can_btl.seg2
			| can_top_tb.dut1.can_controller.i_can_btl.seg1 & can_top_tb.dut1.can_controller.i_can_btl.seg2) begin

			$display("(%0t) ERROR multiple sync, seg1 or seg2 occurance\n\n", $time);
			#1000;
			$stop;
		end
	end

	/* stuff_error monitor (bsp)
	always @(posedge dut_clk) begin
		if(can_top_tb.dut1.can_controller.i_can_bsp.stuff_error) begin
			$display("\n\n(%0t) Stuff error occured in can_bsp.v file\n\n", $time);
			$stop;                                      After everything is finished add another condition (something like & (~idle)) and enable stop
		end
	end
	*/

	//
	// CRC monitor (used until proper CRC generation is used in testbench
	always @(posedge dut_clk) begin
		if(can_top_tb.dut1.can_controller.i_can_bsp.rx_ack       &
			can_top_tb.dut1.can_controller.i_can_bsp.sample_point &
			can_top_tb.dut1.can_controller.i_can_bsp.crc_err) begin

			$display("*E (%0t) ERROR: CRC error (Calculated crc = 0x%0x, crc_in = 0x%0x)", $time, can_top_tb.dut1.can_controller.i_can_bsp.calculated_crc, can_top_tb.dut1.can_controller.i_can_bsp.crc_in);
		end
	end





	/*
	// overrun monitor
	always @(posedge dut_clk) begin
		if(can_top_tb.dut1.can_controller.i_can_bsp.i_can_fifo.wr
			& can_top_tb.dut1.can_controller.i_can_bsp.i_can_fifo.fifo_full) begin

			$display("(%0t)overrun", $time);
		end
	end
	*/


	// form error monitor
	always @(posedge dut_clk) begin
		if(can_top_tb.dut1.can_controller.i_can_bsp.form_err) begin
			$display("*E (%0t) ERROR: form_error", $time);
		end
	end



	// acknowledge error monitor
	always @(posedge dut_clk) begin
		if(can_top_tb.dut1.can_controller.i_can_bsp.ack_err) begin
			$display("*E (%0t) ERROR: acknowledge_error", $time);
		end
	end

	/*
	// bit error monitor
	always @(posedge dut_clk) begin
		if(can_top_tb.dut1.can_controller.i_can_bsp.bit_err) begin
			$display("*E (%0t) ERROR: bit_error", $time);
		end
	end
	*/

endmodule
