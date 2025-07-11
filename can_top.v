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

`include "can_top_defines.v"
`include "can_registers.v"
`include "can_btl.v"
`include "can_bsp.v"

/*
 * Internal CAN controller implementation,
 * without an explicit bus adapter.
 */

module can_controller
	#(
	parameter Tp = 1
	)
	(
	input wire rst_i,
	input wire cs_i,
	input wire we_i,
	input wire [7:0] addr_i,
	input wire [7:0] data_i,
	output reg [7:0] data_o,

	input wire clk_i,
	input wire rx_i,
	output wire tx_o,
	output wire bus_off_on_o,
	output wire irq_n_o,
	output wire clkout_o

	`ifdef CAN_BIST
	,
	input wire mbist_si_i, // bist scan serial in
	output wire mbist_so_o, // bist scan serial out
	input wire [`CAN_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i // bist chain shift control
	`endif
	);


	reg          data_out_fifo_selected;

	wire   [7:0] data_out_fifo;
	wire   [7:0] data_out_regs;

	/* Mode register */
	wire         reset_mode;
	wire         listen_only_mode;
	wire         acceptance_filter_mode;
	wire         self_test_mode;

	/* Command register */
	wire         release_buffer;
	wire         tx_request;
	wire         abort_tx;
	wire         self_rx_request;
	wire         single_shot_transmission;
	wire         tx_state;
	wire         tx_state_q;
	wire         overload_request;
	wire         overload_frame;

	/* Arbitration Lost Capture Register */
	wire         read_arbitration_lost_capture_reg;

	/* Error Code Capture Register */
	wire         read_error_code_capture_reg;
	wire   [7:0] error_capture_code;

	/* Bus Timing 0 register */
	wire   [5:0] baud_r_presc;
	wire   [1:0] sync_jump_width;

	/* Bus Timing 1 register */
	wire   [3:0] time_segment1;
	wire   [2:0] time_segment2;
	wire         triple_sampling;

	/* Error Warning Limit register */
	wire   [7:0] error_warning_limit;

	/* Rx Error Counter register */
	wire         we_rx_err_cnt;

	/* Tx Error Counter register */
	wire         we_tx_err_cnt;

	/* Clock Divider register */
	wire         extended_mode;

	/* This section is for BASIC and EXTENDED mode */
	/* Acceptance code register */
	wire   [7:0] acceptance_code_0;

	/* Acceptance mask register */
	wire   [7:0] acceptance_mask_0;
	/* End: This section is for BASIC and EXTENDED mode */

	/* This section is for EXTENDED mode */
	/* Acceptance code register */
	wire   [7:0] acceptance_code_1;
	wire   [7:0] acceptance_code_2;
	wire   [7:0] acceptance_code_3;

	/* Acceptance mask register */
	wire   [7:0] acceptance_mask_1;
	wire   [7:0] acceptance_mask_2;
	wire   [7:0] acceptance_mask_3;
	/* End: This section is for EXTENDED mode */

	/* Tx data registers. Holding identifier (basic mode), tx frame information (extended mode) and data */
	wire   [7:0] tx_data_0;
	wire   [7:0] tx_data_1;
	wire   [7:0] tx_data_2;
	wire   [7:0] tx_data_3;
	wire   [7:0] tx_data_4;
	wire   [7:0] tx_data_5;
	wire   [7:0] tx_data_6;
	wire   [7:0] tx_data_7;
	wire   [7:0] tx_data_8;
	wire   [7:0] tx_data_9;
	wire   [7:0] tx_data_10;
	wire   [7:0] tx_data_11;
	wire   [7:0] tx_data_12;
	/* End: Tx data registers */

	/* Output signals from can_btl module */
	wire         sample_point;
	wire         sampled_bit;
	wire         sampled_bit_q;
	wire         tx_point;
	wire         hard_sync;

	/* output from can_bsp module */
	wire         rx_idle;
	wire         transmitting;
	wire         transmitter;
	wire         go_rx_inter;
	wire         not_first_bit_of_inter;
	wire         set_reset_mode;
	wire         node_bus_off;
	wire         error_status;
	wire   [7:0] rx_err_cnt;
	wire   [7:0] tx_err_cnt;
	wire         rx_err_cnt_dummy;  // The MSB is not displayed. It is just used for easier calculation (no counter overflow).
	wire         tx_err_cnt_dummy;  // The MSB is not displayed. It is just used for easier calculation (no counter overflow).
	wire         transmit_status;
	wire         receive_status;
	wire         tx_successful;
	wire         need_to_tx;
	wire         overrun;
	wire         info_empty;
	wire         set_bus_error_irq;
	wire         set_arbitration_lost_irq;
	wire   [4:0] arbitration_lost_capture;
	wire         node_error_passive;
	wire         node_error_active;
	wire   [6:0] rx_message_counter;
	wire         tx_next;

	wire         go_overload_frame;
	wire         go_error_frame;
	wire         go_tx;
	wire         send_ack;

	reg          rx_sync_tmp;
	reg          rx_sync;

	/* Connecting can_registers module */
	can_registers i_can_registers
	(
		.clk(clk_i),
		.rst(rst_i),
		.cs(cs_i),
		.we(we_i),
		.addr(addr_i),
		.data_in(data_i),
		.data_out(data_out_regs),
		.irq_n(irq_n_o),

		.sample_point(sample_point),
		.transmitting(transmitting),
		.set_reset_mode(set_reset_mode),
		.node_bus_off(node_bus_off),
		.error_status(error_status),
		.rx_err_cnt(rx_err_cnt),
		.tx_err_cnt(tx_err_cnt),
		.transmit_status(transmit_status),
		.receive_status(receive_status),
		.tx_successful(tx_successful),
		.need_to_tx(need_to_tx),
		.overrun(overrun),
		.info_empty(info_empty),
		.set_bus_error_irq(set_bus_error_irq),
		.set_arbitration_lost_irq(set_arbitration_lost_irq),
		.arbitration_lost_capture(arbitration_lost_capture),
		.node_error_passive(node_error_passive),
		.node_error_active(node_error_active),
		.rx_message_counter(rx_message_counter),

		/* Mode register */
		.reset_mode(reset_mode),
		.listen_only_mode(listen_only_mode),
		.acceptance_filter_mode(acceptance_filter_mode),
		.self_test_mode(self_test_mode),

		/* Command register */
		.clear_data_overrun(),
		.release_buffer(release_buffer),
		.abort_tx(abort_tx),
		.tx_request(tx_request),
		.self_rx_request(self_rx_request),
		.single_shot_transmission(single_shot_transmission),
		.tx_state(tx_state),
		.tx_state_q(tx_state_q),
		.overload_request(overload_request),
		.overload_frame(overload_frame),

		/* Arbitration Lost Capture Register */
		.read_arbitration_lost_capture_reg(read_arbitration_lost_capture_reg),

		/* Error Code Capture Register */
		.read_error_code_capture_reg(read_error_code_capture_reg),
		.error_capture_code(error_capture_code),

		/* Bus Timing 0 register */
		.baud_r_presc(baud_r_presc),
		.sync_jump_width(sync_jump_width),

		/* Bus Timing 1 register */
		.time_segment1(time_segment1),
		.time_segment2(time_segment2),
		.triple_sampling(triple_sampling),

		/* Error Warning Limit register */
		.error_warning_limit(error_warning_limit),

		/* Rx Error Counter register */
		.we_rx_err_cnt(we_rx_err_cnt),

		/* Tx Error Counter register */
		.we_tx_err_cnt(we_tx_err_cnt),

		/* Clock Divider register */
		.extended_mode(extended_mode),
		.clkout(clkout_o),

		/* This section is for BASIC and EXTENDED mode */
		/* Acceptance code register */
		.acceptance_code_0(acceptance_code_0),

		/* Acceptance mask register */
		.acceptance_mask_0(acceptance_mask_0),
		/* End: This section is for BASIC and EXTENDED mode */

		/* This section is for EXTENDED mode */
		/* Acceptance code register */
		.acceptance_code_1(acceptance_code_1),
		.acceptance_code_2(acceptance_code_2),
		.acceptance_code_3(acceptance_code_3),

		/* Acceptance mask register */
		.acceptance_mask_1(acceptance_mask_1),
		.acceptance_mask_2(acceptance_mask_2),
		.acceptance_mask_3(acceptance_mask_3),
		/* End: This section is for EXTENDED mode */

		/* Tx data registers. Holding identifier (basic mode), tx frame information (extended mode) and data */
		.tx_data_0(tx_data_0),
		.tx_data_1(tx_data_1),
		.tx_data_2(tx_data_2),
		.tx_data_3(tx_data_3),
		.tx_data_4(tx_data_4),
		.tx_data_5(tx_data_5),
		.tx_data_6(tx_data_6),
		.tx_data_7(tx_data_7),
		.tx_data_8(tx_data_8),
		.tx_data_9(tx_data_9),
		.tx_data_10(tx_data_10),
		.tx_data_11(tx_data_11),
		.tx_data_12(tx_data_12)
		/* End: Tx data registers */
	);

	/* some interconnect signal from BSP to BTL */
	wire rx_inter;

	/* Connecting can_btl module */
	can_btl i_can_btl
	(
		.clk(clk_i),
		.rst(rst_i),
		.rx(rx_sync),
		.tx(tx_o),

		/* Bus Timing 0 register */
		.baud_r_presc(baud_r_presc),
		.sync_jump_width(sync_jump_width),

		/* Bus Timing 1 register */
		.time_segment1(time_segment1),
		.time_segment2(time_segment2),
		.triple_sampling(triple_sampling),

		/* Output signals from this module */
		.sample_point(sample_point),
		.sampled_bit(sampled_bit),
		.sampled_bit_q(sampled_bit_q),
		.tx_point(tx_point),
		.hard_sync(hard_sync),


		/* output from can_bsp module */
		.rx_idle(rx_idle),
		.rx_inter(rx_inter),
		.transmitting(transmitting),
		.transmitter(transmitter),
		.go_rx_inter(go_rx_inter),
		.tx_next(tx_next),

		.go_overload_frame(go_overload_frame),
		.go_error_frame(go_error_frame),
		.go_tx(go_tx),
		.send_ack(send_ack),
		.node_error_passive(node_error_passive)
	);

	can_bsp i_can_bsp
	(
		.clk(clk_i),
		.rst(rst_i),

		/* From btl module */
		.sample_point(sample_point),
		.sampled_bit(sampled_bit),
		.sampled_bit_q(sampled_bit_q),
		.tx_point(tx_point),
		.hard_sync(hard_sync),

		.addr(addr_i),
		.data_in(data_i),
		.data_out(data_out_fifo),
		.fifo_selected(data_out_fifo_selected),

		/* Mode register */
		.reset_mode(reset_mode),
		.listen_only_mode(listen_only_mode),
		.acceptance_filter_mode(acceptance_filter_mode),
		.self_test_mode(self_test_mode),

		/* Command register */
		.release_buffer(release_buffer),
		.tx_request(tx_request),
		.abort_tx(abort_tx),
		.self_rx_request(self_rx_request),
		.single_shot_transmission(single_shot_transmission),
		.tx_state(tx_state),
		.tx_state_q(tx_state_q),
		.overload_request(overload_request),
		.overload_frame(overload_frame),

		/* Arbitration Lost Capture Register */
		.read_arbitration_lost_capture_reg(read_arbitration_lost_capture_reg),

		/* Error Code Capture Register */
		.read_error_code_capture_reg(read_error_code_capture_reg),
		.error_capture_code(error_capture_code),

		/* Error Warning Limit register */
		.error_warning_limit(error_warning_limit),

		/* Rx Error Counter register */
		.we_rx_err_cnt(we_rx_err_cnt),

		/* Tx Error Counter register */
		.we_tx_err_cnt(we_tx_err_cnt),

		/* Clock Divider register */
		.extended_mode(extended_mode),

		/* output from can_bsp module */
		.rx_idle(rx_idle),
		.transmitting(transmitting),
		.transmitter(transmitter),
		.go_rx_inter(go_rx_inter),
		.not_first_bit_of_inter(not_first_bit_of_inter),
		.rx_inter(rx_inter),
		.set_reset_mode(set_reset_mode),
		.node_bus_off(node_bus_off),
		.error_status(error_status),
		.rx_err_cnt({rx_err_cnt_dummy, rx_err_cnt[7:0]}),   // The MSB is not displayed. It is just used for easier calculation (no counter overflow).
		.tx_err_cnt({tx_err_cnt_dummy, tx_err_cnt[7:0]}),   // The MSB is not displayed. It is just used for easier calculation (no counter overflow).
		.transmit_status(transmit_status),
		.receive_status(receive_status),
		.tx_successful(tx_successful),
		.need_to_tx(need_to_tx),
		.overrun(overrun),
		.info_empty(info_empty),
		.set_bus_error_irq(set_bus_error_irq),
		.set_arbitration_lost_irq(set_arbitration_lost_irq),
		.arbitration_lost_capture(arbitration_lost_capture),
		.node_error_passive(node_error_passive),
		.node_error_active(node_error_active),
		.rx_message_counter(rx_message_counter),

		/* This section is for BASIC and EXTENDED mode */
		/* Acceptance code register */
		.acceptance_code_0(acceptance_code_0),

		/* Acceptance mask register */
		.acceptance_mask_0(acceptance_mask_0),
		/* End: This section is for BASIC and EXTENDED mode */

		/* This section is for EXTENDED mode */
		/* Acceptance code register */
		.acceptance_code_1(acceptance_code_1),
		.acceptance_code_2(acceptance_code_2),
		.acceptance_code_3(acceptance_code_3),

		/* Acceptance mask register */
		.acceptance_mask_1(acceptance_mask_1),
		.acceptance_mask_2(acceptance_mask_2),
		.acceptance_mask_3(acceptance_mask_3),
		/* End: This section is for EXTENDED mode */

		/* Tx data registers. Holding identifier (basic mode), tx frame information (extended mode) and data */
		.tx_data_0(tx_data_0),
		.tx_data_1(tx_data_1),
		.tx_data_2(tx_data_2),
		.tx_data_3(tx_data_3),
		.tx_data_4(tx_data_4),
		.tx_data_5(tx_data_5),
		.tx_data_6(tx_data_6),
		.tx_data_7(tx_data_7),
		.tx_data_8(tx_data_8),
		.tx_data_9(tx_data_9),
		.tx_data_10(tx_data_10),
		.tx_data_11(tx_data_11),
		.tx_data_12(tx_data_12),
		/* End: Tx data registers */

		/* Tx signal */
		.tx(tx_o),
		.tx_next(tx_next),
		.bus_off_on(bus_off_on_o),

		.go_overload_frame(go_overload_frame),
		.go_error_frame(go_error_frame),
		.go_tx(go_tx),
		.send_ack(send_ack)

		`ifdef CAN_BIST
		,
		.mbist_si_i(mbist_si_i),
		.mbist_so_o(mbist_so_o),
		.mbist_ctrl_i(mbist_ctrl_i)
		`endif
	);

	// Multiplexing registers and rx fifo into data_o
	always @(extended_mode or addr_i or reset_mode) begin
		if(extended_mode & (~reset_mode) & ((addr_i >= 8'd16) && (addr_i <= 8'd28))
			| (~extended_mode) & ((addr_i >= 8'd20) && (addr_i <= 8'd29))) begin

			data_out_fifo_selected = 1'b1;
		end else begin
			data_out_fifo_selected = 1'b0;
		end
	end

	always @(posedge clk_i) begin
		if(cs_i & (~we_i)) begin
			if(data_out_fifo_selected) begin
				data_o <=#Tp data_out_fifo;
			end else begin
				data_o <=#Tp data_out_regs;
			end
		end
	end

	always @(posedge clk_i or posedge rst_i) begin
		if(rst_i) begin
			rx_sync_tmp <= 1'b1;
			rx_sync     <= 1'b1;
		end else begin
			rx_sync_tmp <=#Tp rx_i;
			rx_sync     <=#Tp rx_sync_tmp;
		end
	end

endmodule


/*
 * CAN controller connected to a wishbone bus
 */
module can_wishbone_top
	#(
	parameter Tp = 1
	)
	(
	input wire wb_clk_i,
	input wire wb_rst_i,
	input wire [7:0] wb_dat_i,
	output wire [7:0] wb_dat_o,
	input wire wb_cyc_i,
	input wire wb_stb_i,
	input wire wb_we_i,
	input wire [7:0] wb_adr_i,
	output reg wb_ack_o,

	input wire clk_i,
	input wire rx_i,
	output wire tx_o,
	output wire bus_off_on_o,
	output wire irq_n_o,
	output wire clkout_o

	`ifdef CAN_BIST
	,
	input wire mbist_si_i, // bist scan serial in
	output wire mbist_so_o, // bist scan serial out
	input wire [`CAN_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i // bist chain shift control
	`endif
	);


	reg          cs_sync1 = 0;
	reg          cs_sync2 = 0;
	reg          cs_sync3 = 0;

	reg          cs_ack1 = 0;
	reg          cs_ack2 = 0;
	reg          cs_ack3 = 0;
	reg          cs_sync_rst1 = 0;
	reg          cs_sync_rst2 = 0;
	wire         cs_can = cs_sync2 & (~cs_sync3);


	// Combine wb_cyc_i and wb_stb_i signals to cs signal, then sync to clk_i clock domain.
	always @(posedge clk_i or posedge wb_rst_i) begin
		if(wb_rst_i) begin
			cs_sync1 <= 0;
			cs_sync2 <= 0;
			cs_sync3 <= 0;
			cs_sync_rst1 <= 0;
			cs_sync_rst2 <= 0;
		end else begin
			cs_sync1     <=#Tp wb_cyc_i & wb_stb_i & (~cs_sync_rst2);
			cs_sync2     <=#Tp cs_sync1            & (~cs_sync_rst2);
			cs_sync3     <=#Tp cs_sync2            & (~cs_sync_rst2);
			cs_sync_rst1 <=#Tp cs_ack3;
			cs_sync_rst2 <=#Tp cs_sync_rst1;
		end
	end

	// Generate bus signals
	always @(posedge wb_clk_i) begin
		cs_ack1 <=#Tp cs_sync3;
		cs_ack2 <=#Tp cs_ack1;
		cs_ack3 <=#Tp cs_ack2;
		wb_ack_o <=#Tp (cs_ack2 & (~cs_ack3));
	end

	can_controller #(.Tp(Tp)) can_controller(
		.rst_i(wb_rst_i),
		.cs_i(cs_can),
		.we_i(wb_we_i),
		.addr_i(wb_adr_i),
		.data_i(wb_dat_i),
		.data_o(wb_dat_o),

		.clk_i(clk_i),
		.rx_i(rx_i),
		.tx_o(tx_o),
		.bus_off_on_o(bus_off_on_o),
		.irq_n_o(irq_n_o),
		.clkout_o(clkout_o)

		`ifdef CAN_BIST
		,
		.mbist_si_i(mbist_si_i),
		.mbist_so_o(mbist_so_o),
		.mbist_ctrl_i(mbist_ctrl_i)
		`endif
		);

endmodule


/*
 * CAN controller connected to an 8051 bus.
 * Output enable signal is provided for data bus output signals.
 */
module can_8051_top
	#(
	parameter Tp = 1
	)
	(
	input wire rst_i,
	input wire cs_can_i,
	input wire ale_i,
	input wire rd_i,
	input wire wr_i,
	input wire [7:0] port_0_i,
	output wire [7:0] port_0_o,
	output wire port_0_oe,

	input wire clk_i,
	input wire rx_i,
	output wire tx_o,
	output wire bus_off_on_o,
	output wire irq_n_o,
	output wire clkout_o

	`ifdef CAN_BIST
	,
	input wire mbist_si_i, // bist scan serial in
	output wire mbist_so_o, // bist scan serial out
	input wire [`CAN_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i // bist chain shift control
	`endif
	);

	reg    [7:0] addr_latched;
	reg          wr_i_q;
	reg          rd_i_q;

	// Latching of bus signals
	always @(posedge clk_i or posedge rst_i) begin
		if(rst_i) begin
			addr_latched <= 8'h0;
			wr_i_q <= 1'b0;
			rd_i_q <= 1'b0;
		end else if(ale_i) begin
			addr_latched <=#Tp port_0_i;
			wr_i_q <=#Tp wr_i;
			rd_i_q <=#Tp rd_i;
		end
	end

	wire cs = ((wr_i & (~wr_i_q)) | (rd_i & (~rd_i_q))) & cs_can_i;

	assign port_0_oe = cs_can_i & rd_i;

	can_controller can_controller(
		.rst_i(rst_i),
		.cs_i(cs),
		.we_i(wr_i),
		.addr_i(addr_latched),
		.data_i(port_0_i),
		.data_o(port_0_o),

		.clk_i(clk_i),
		.rx_i(rx_i),
		.tx_o(tx_o),
		.bus_off_on_o(bus_off_on_o),
		.irq_n_o(irq_n_o),
		.clkout_o(clkout_o)

		`ifdef CAN_BIST
		,
		.mbist_si_i(mbist_si_i),
		.mbist_so_o(mbist_so_o),
		.mbist_ctrl_i(mbist_ctrl_i)
		`endif
		);

endmodule


/*
 * CAN controller connected to an 8051 bus.
 * Data lines are shared between input and output;
 * outputs thus can be tri-stated.
 *
 * This is the original 8051 interface provided by earlier versions of this
 * core.
 */
module can_8051_tristate_top
	#(
	parameter Tp = 1
	)
	(
	input wire rst_i,
	input wire ale_i,
	input wire rd_i,
	input wire wr_i,
	inout wire [7:0] port_0_io,
	input wire cs_can_i,

	input wire clk_i,
	input wire rx_i,
	output wire tx_o,
	output wire bus_off_on_o,
	output wire irq_n_o,
	output wire clkout_o

	`ifdef CAN_BIST
	,
	input wire mbist_si_i, // bist scan serial in
	output wire mbist_so_o, // bist scan serial out
	input wire [`CAN_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i // bist chain shift control
	`endif
	);


	wire [7:0] port_0_o;
	wire port_0_oe;

	assign port_0_io = (port_0_oe) ? port_0_o : 8'hz;

	can_8051_top #(.Tp(Tp)) can_8051(
		.rst_i(rst_i),
		.ale_i(ale_i),
		.rd_i(rd_i),
		.wr_i(wr_i),
		.port_0_i(port_0_io),
		.port_0_o(port_0_o),
		.port_0_oe(port_0_oe),
		.cs_can_i(cs_can_i),

		.clk_i(clk_i),
		.rx_i(rx_i),
		.tx_o(tx_o),
		.bus_off_on_o(bus_off_on_o),
		.irq_n_o(irq_n_o),
		.clkout_o(clkout_o)

		`ifdef CAN_BIST
		,
		.mbist_si_i(mbist_si_i),
		.mbist_so_o(mbist_so_o),
		.mbist_ctrl_i(mbist_ctrl_i)
		`endif
	);

endmodule

