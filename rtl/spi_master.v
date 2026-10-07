`timescale 1ns/1ps

module spi_master (
    input  wire        clk,
    input  wire        rst,

    // Control interface
    input  wire        start,
    input  wire [7:0]  tx_data,
    input  wire [15:0] clkdiv,

    // SPI interface
    input  wire        miso,
    output reg         mosi,
    output reg         sclk,
    output reg         cs_n,

    // Status/data
    output reg         busy,
    output reg         done,
    output reg  [7:0]  rx_data
);

    // --------------------------------------------
    // Internal registers
    // --------------------------------------------

    reg [7:0] tx_shift;
    reg [7:0] rx_shift;

    reg [3:0] bit_count;
    reg [15:0] div_count;

    localparam STATE_IDLE     = 1'b0;
    localparam STATE_TRANSFER = 1'b1;

    reg state;


    // --------------------------------------------
    // SPI master
    //
    // Mode 0:
    // CPOL = 0
    // CPHA = 0
    //
    // Sample MISO on rising edge.
    // Change MOSI on falling edge.
    // MSB first.
    // --------------------------------------------

    always @(posedge clk) begin

        if (rst) begin

            state     <= STATE_IDLE;

            tx_shift  <= 8'h00;
            rx_shift  <= 8'h00;

            bit_count <= 4'd0;
            div_count <= 16'd0;

            mosi      <= 1'b0;
            sclk      <= 1'b0;
            cs_n      <= 1'b1;

            busy      <= 1'b0;
            done      <= 1'b0;

            rx_data   <= 8'h00;

        end

        else begin

            // DONE is a one-clock pulse
            done <= 1'b0;

            case (state)

                // ====================================
                // IDLE
                // ====================================

                STATE_IDLE: begin

                    sclk      <= 1'b0;
                    cs_n      <= 1'b1;
                    busy      <= 1'b0;
                    div_count <= 16'd0;

                    if (start) begin

                        state <= STATE_TRANSFER;

                        busy <= 1'b1;
                        cs_n <= 1'b0;

                        // Load transmit byte
                        tx_shift <= tx_data;

                        // First bit is available before
                        // the first rising SCLK edge.
                        mosi <= tx_data[7];

                        // Clear receive shift register
                        rx_shift <= 8'h00;

                        bit_count <= 4'd0;

                        sclk <= 1'b0;

                    end

                end


                // ====================================
                // TRANSFER
                // ====================================

                STATE_TRANSFER: begin

                    if ((clkdiv <= 16'd1) ||
                        (div_count == clkdiv - 1'b1)) begin

                        div_count <= 16'd0;

                        // --------------------------------
                        // Rising edge
                        // --------------------------------

                        if (sclk == 1'b0) begin

                            sclk <= 1'b1;

                            // Sample MISO
                            rx_shift <= {
                                rx_shift[6:0],
                                miso
                            };

                            bit_count <= bit_count + 1'b1;

                        end


                        // --------------------------------
                        // Falling edge
                        // --------------------------------

                        else begin

                            sclk <= 1'b0;

                            // After the 8th rising edge,
                            // the byte is complete.
                            if (bit_count == 4'd8) begin

                                // rx_shift already contains
                                // the 8 sampled bits.
                                rx_data <= rx_shift;

                                cs_n <= 1'b1;
                                busy <= 1'b0;
                                done <= 1'b1;

                                state <= STATE_IDLE;

                                mosi <= 1'b0;

                            end

                            else begin

                                // Shift to next TX bit
                                tx_shift <= {
                                    tx_shift[6:0],
                                    1'b0
                                };

                                mosi <= tx_shift[6];

                            end

                        end

                    end

                    else begin

                        div_count <= div_count + 1'b1;

                    end

                end


                default: begin

                    state <= STATE_IDLE;

                    sclk <= 1'b0;
                    cs_n <= 1'b1;
                    busy <= 1'b0;
                    done <= 1'b0;

                end

            endcase

        end

    end

endmodule