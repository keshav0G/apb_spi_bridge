`timescale 1ns/1ps

module spi_master (
    input  wire        clk,
    input  wire        rst,

    input  wire        start,
    input  wire [7:0]  tx_data,
    input  wire [15:0] clkdiv,

    input  wire        miso,
    output reg         mosi,
    output reg         sclk,
    output reg         cs_n,

    output reg         busy,
    output reg         done,
    output reg  [7:0]  rx_data
);

    // ------------------------------------------------------------
    // INTERNAL REGISTERS
    // ------------------------------------------------------------

    reg [7:0]  tx_shift;
    reg [7:0]  rx_shift;

    reg [3:0]  bit_count;

    reg [15:0] div_count;


    // ------------------------------------------------------------
    // STATE MACHINE
    // ------------------------------------------------------------

    localparam STATE_IDLE     = 1'b0;
    localparam STATE_TRANSFER = 1'b1;

    reg state;


    // ------------------------------------------------------------
    // SPI MASTER
    //
    // SPI MODE 0:
    //
    // CPOL = 0
    // CPHA = 0
    //
    // SCLK idle = LOW
    // Sample MISO on rising edge
    // Change MOSI on falling edge
    //
    // 8-bit, MSB first
    // ------------------------------------------------------------

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

            // DONE is a one-cycle pulse
            done <= 1'b0;

            case (state)

                // ====================================================
                // IDLE
                // ====================================================

                STATE_IDLE: begin

                    sclk      <= 1'b0;
                    cs_n      <= 1'b1;
                    busy      <= 1'b0;
                    div_count <= 16'd0;

                    if (start) begin

                        state <= STATE_TRANSFER;

                        busy <= 1'b1;
                        cs_n <= 1'b0;

                        // Load TX data
                        tx_shift <= tx_data;

                        // Clear RX shift register
                        rx_shift <= 8'h00;

                        // Start at bit 0
                        bit_count <= 4'd0;

                        // First MSB is placed on MOSI
                        // before first rising edge
                        mosi <= tx_data[7];

                        sclk <= 1'b0;

                    end

                end


                // ====================================================
                // TRANSFER
                // ====================================================

                STATE_TRANSFER: begin

                    // ------------------------------------------------
                    // SPI CLOCK DIVIDER
                    // ------------------------------------------------

                    if ((clkdiv <= 16'd1) ||
                        (div_count == clkdiv - 1'b1)) begin

                        div_count <= 16'd0;


                        // ------------------------------------------------
                        // RISING EDGE
                        //
                        // MODE 0:
                        // Sample MISO
                        // ------------------------------------------------

                        if (sclk == 1'b0) begin

                            sclk <= 1'b1;

                            rx_shift <= {
                                rx_shift[6:0],
                                miso
                            };

                            bit_count <= bit_count + 1'b1;

                        end


                        // ------------------------------------------------
                        // FALLING EDGE
                        //
                        // MODE 0:
                        // Change MOSI
                        // ------------------------------------------------

                        else begin

                            sclk <= 1'b0;

                            if (bit_count == 4'd8) begin

                                // Transfer complete

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

                    // ------------------------------------------------
                    // Divider has not expired
                    // ------------------------------------------------

                    else begin

                        div_count <= div_count + 1'b1;

                    end

                end


                // ====================================================
                // DEFAULT
                // ====================================================

                default: begin

                    state <= STATE_IDLE;

                    sclk <= 1'b0;
                    cs_n <= 1'b1;

                    busy <= 1'b0;
                    done <= 1'b0;

                    mosi <= 1'b0;

                end

            endcase

        end

    end

endmodule