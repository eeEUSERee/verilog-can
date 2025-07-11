/* vim: colorcolumn=80
 *
 * This file is part of a verilog CAN controller that is SJA1000 compatible.
 *
 * Authors:
 *   * David Piegdon <dgit@piegdon.de>
 *       Picked up project for cleanup and bugfixes in 2019
 *
 * Any additional information is available in the LICENSE file.
 *
 * Copyright (C) 2019 Authors
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

`include "testbench/canbus.v"
`include "testbench/test_rx_tx.v"
`include "testbench/test_acceptance_filter.v"

module can_top_tb();

	initial begin
		$dumpfile("can_trace.vcd"); // for GTKWave or similar viewer
		$dumpvars(0, can_top_tb);
	end

	localparam TESTCOUNT=2;

	wire [TESTCOUNT-1:0] subtest_finished;
	wire [15:0] subtest_errors[TESTCOUNT-1:0];

	// instantiate all sub-tests
	test_tx_rx test_tx_rx(subtest_finished[0], subtest_errors[0]);
	test_acceptance_filter test_acceptance_filter(subtest_finished[1], subtest_errors[1]);
	// to be ported:
	//	test_synchronization
	//	test_empty_fifo_ext
	//	test_full_fifo_ext
	//	send_frame_ext
	//	test_empty_fifo
	//	test_full_fifo
	//	test_reset_mode
	//	bus_off_test
	//	forced_bus_off
	//	send_frame_basic
	//	send_frame_extended
	//	self_reception_request
	//	manual_frame_basic
	//	manual_frame_ext
	//	error_test
	//	register_test
	//	bus_off_recovery_test;
	// new:
	//	test_baudrate
	//	test_arbitration_loss


	// collect output
	wire finished = &(subtest_finished);
	integer errors;
	integer i;

	always begin
		#1;

		wait(finished);
		#500;

		errors = 0;
		for(i = 0; i < TESTCOUNT; i = i+1) begin
			errors = errors + subtest_errors[i];
		end

		$display("%1d subtests completed.", TESTCOUNT);

		if(errors) begin
			$warning("FAIL: collected %d errors", errors);
			$fatal();
		end else begin
			$display("PASS: testsuite finished successfully");
			$finish;
		end
	end

endmodule

