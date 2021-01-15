/*
 *  PicoSoC - A simple example SoC using PicoRV32
 *
 *  Copyright (C) 2017  Clifford Wolf <clifford@clifford.at>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

`ifdef PICOSOC_V
`error "icebreaker.v must be read before picosoc.v!"
`endif

`define PICOSOC_MEM ice40up5k_spram

module icebreaker (
	input clk,

	output ser_tx,
	input ser_rx,

	output led1,
	output led2,
	output led3,
	output led4,
	output led5,

	output ledr_n,
	output ledg_n,

	output activity_red,
	output activity_green,

	input sense_led,
	output report_led,
	input user_button,

	input button1,
	input button2,
	input button3,

	output flash_csb,
	output flash_clk,
	inout  flash_io0,
	inout  flash_io1,
	inout  flash_io2,
	inout  flash_io3,

	// raven
	output [1:0] fp_gpio_out,
	input [1:0] fp_gpio_in,
	output [1:0] fp_gpio_pullup,
	output [1:0] fp_gpio_pulldown,
	output [1:0] fp_gpio_outenb
);
	parameter integer MEM_WORDS = 32768;

	reg [5:0] reset_cnt = 0;
	wire resetn = &reset_cnt;

	always @(posedge clk) begin
		reset_cnt <= reset_cnt + !resetn;
	end

	wire [7:0] leds;

	assign led1 = leds[1];
	assign led2 = leds[2];
	assign led3 = leds[3];
	assign led4 = leds[4];
	assign led5 = leds[5];

	assign ledr_n = !leds[6];
	assign ledg_n = !leds[7];

	wire [2:0] new_pmod_leds;

	assign report_led = new_pmod_leds[0];
	assign activity_red = new_pmod_leds[1];
	assign activity_green = new_pmod_leds[2];

	wire flash_io0_oe, flash_io0_do, flash_io0_di;
	wire flash_io1_oe, flash_io1_do, flash_io1_di;
	wire flash_io2_oe, flash_io2_do, flash_io2_di;
	wire flash_io3_oe, flash_io3_do, flash_io3_di;

	SB_IO #(
		.PIN_TYPE(6'b 1010_01),
		.PULLUP(1'b 0)
	) flash_io_buf [3:0] (
		.PACKAGE_PIN({flash_io3, flash_io2, flash_io1, flash_io0}),
		.OUTPUT_ENABLE({flash_io3_oe, flash_io2_oe, flash_io1_oe, flash_io0_oe}),
		.D_OUT_0({flash_io3_do, flash_io2_do, flash_io1_do, flash_io0_do}),
		.D_IN_0({flash_io3_di, flash_io2_di, flash_io1_di, flash_io0_di})
	);

	wire        iomem_valid;
	reg         iomem_ready;
	wire [3:0]  iomem_wstrb;
	wire [31:0] iomem_addr;
	wire [31:0] iomem_wdata;
	reg  [31:0] iomem_rdata;

	reg [31:0] gpio;
	assign leds = gpio;
	assign new_pmod_leds[1] = gpio[11];
	assign new_pmod_leds[2] = gpio[12];

	// raven
	assign new_pmod_leds[0] = fp_gpio[0];

	reg[15:0] mmio;

	// raven
	wire[1:0] fp_gpio_pullup;
	wire[1:0] fp_gpio_pulldown;
	wire[1:0] fp_gpio_outenb;

	// raven
	reg[1:0] fp_gpio;
	reg[1:0] fp_gpio_pu;
	reg[1:0] fp_gpio_pd;
	reg[1:0] fp_gpio_oeb;

	// This is for a reset switch.

	wire input_wire;

	SB_IO #(
	  .PIN_TYPE(6'b0000_01),
	  .PULLUP(1'b0)
	) input_wire_conf (
	  .PACKAGE_PIN(user_button),
	  .D_IN_0(input_wire)
	);

	wire sense_wire;
	assign sense_wire = sense_led;

	// raven
	assign fp_gpio_out = 0; // was 32'hcafebabe
	assign fp_gpio_pullup = 0;
	assign fp_gpio_pulldown = 0;
	assign fp_gpio_outenb = 0;

	always @(posedge clk) begin
		if (!resetn | !input_wire) begin // add reset on user button
			gpio <= 0;
			mmio <= 0;
			// raven
			fp_gpio <= 0;
			fp_gpio_pu <= 0;
			fp_gpio_pd <= 0;
			fp_gpio_oeb <= 2'b11; // default to input on reset
		end else begin
			iomem_ready <= 0;
			mmio[0] <= input_wire;
			mmio[1] <= sense_wire;
			if (iomem_valid && !iomem_ready) begin
				case (iomem_addr[31:24])
					8'h 03:
					begin
						iomem_ready <= 1;
						iomem_rdata <= gpio;
						if (iomem_wstrb[0]) gpio[ 7: 0] <= iomem_wdata[ 7: 0];
						if (iomem_wstrb[1]) gpio[15: 8] <= iomem_wdata[15: 8];
						if (iomem_wstrb[2]) gpio[23:16] <= iomem_wdata[23:16];
						if (iomem_wstrb[3]) gpio[31:24] <= iomem_wdata[31:24];
					end
					8'h 06:
					begin
						iomem_ready <= 1;
						iomem_rdata <= mmio;
						if (iomem_wstrb[0]) mmio[ 7: 0] <= iomem_wdata[ 7: 0];
						if (iomem_wstrb[1]) mmio[15: 8] <= iomem_wdata[15: 8];
					end
					// raven
					8'h 07:
					begin
						iomem_ready <= 1;
						case (iomem_addr[7:0])
							8'h 00: // data
							begin
								iomem_rdata <= {fp_gpio_out, fp_gpio_in};
								if (iomem_wstrb[0]) fp_gpio[1:0] <= iomem_wdata[1:0];
							end
							8'h 04: // output enable
							begin
								iomem_rdata <= {8'd0, fp_gpio_oeb};
								if (iomem_wstrb[0]) fp_gpio_oeb[1:0] <= iomem_wdata[1:0];
							end
							8'h 08: // pullup
							begin
								iomem_rdata <= {8'd0, fp_gpio_pu};
								if (iomem_wstrb[0]) fp_gpio_pu[1:0] <= iomem_wdata[1:0];
							end
							8'h 0c: // pulldown
							begin
								iomem_rdata <= {8'd0, fp_gpio_pd};
								if (iomem_wstrb[0]) fp_gpio_pd[1:0] <= iomem_wdata[1:0];
							end
							default:
							begin
							end
						endcase
					end // raven
					default:
					begin
					end
				endcase
			end // if iomem_valid
		end // else
	end // always

	picosoc #(
		.BARREL_SHIFTER(0),
		.ENABLE_MULDIV(0),
		.MEM_WORDS(MEM_WORDS)
	) soc (
		.clk          (clk         ),
		.resetn       (resetn      ),

		.ser_tx       (ser_tx      ),
		.ser_rx       (ser_rx      ),

		.flash_csb    (flash_csb   ),
		.flash_clk    (flash_clk   ),

		.flash_io0_oe (flash_io0_oe),
		.flash_io1_oe (flash_io1_oe),
		.flash_io2_oe (flash_io2_oe),
		.flash_io3_oe (flash_io3_oe),

		.flash_io0_do (flash_io0_do),
		.flash_io1_do (flash_io1_do),
		.flash_io2_do (flash_io2_do),
		.flash_io3_do (flash_io3_do),

		.flash_io0_di (flash_io0_di),
		.flash_io1_di (flash_io1_di),
		.flash_io2_di (flash_io2_di),
		.flash_io3_di (flash_io3_di),

		.irq_5        (1'b0        ),
		.irq_6        (1'b0        ),
		.irq_7        (1'b0        ),

		.iomem_valid  (iomem_valid ),
		.iomem_ready  (iomem_ready ),
		.iomem_wstrb  (iomem_wstrb ),
		.iomem_addr   (iomem_addr  ),
		.iomem_wdata  (iomem_wdata ),
		.iomem_rdata  (iomem_rdata )
	);
endmodule
