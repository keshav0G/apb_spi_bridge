`timescale 1ns/1ps

module apb_slave (
    input  wire        PCLK,
    input  wire        PRESETn,

    input  wire [31:0] PADDR,
    input  wire        PSEL,
    input  wire        PENABLE,
    input  wire        PWRITE,
    input  wire [31:0] PWDATA,
    input  wire [3:0]  PSTRB,

    output reg  [31:0] PRDATA,
    output wire        PREADY,
    output wire        PSLVERR,

    output reg  [7:0]  tx_data,
    output reg         start,
    output reg  [15:0] clkdiv,
    output reg  [1:0]  spi_config,

    input  wire [7:0]  rx_data,
    input  wire        busy,
    input  wire        done
);

    // ------------------------------------------------------------
    // APB Register Addresses
    // ------------------------------------------------------------

    localparam ADDR_CTRL   = 32'h0000_0000;
    localparam ADDR_STATUS = 32'h0000_0004;
    localparam ADDR_TXDATA = 32'h0000_0008;
    localparam ADDR_RXDATA = 32'h0000_000C;
    localparam ADDR_CLKDIV = 32'h0000_0010;
    localparam ADDR_CONFIG = 32'h0000_0014;


    // ------------------------------------------------------------
    // APB Response
    // ------------------------------------------------------------

    // Peripheral is always ready.
    assign PREADY = 1'b1;

    // Generate slave error for invalid addresses during APB access.
    assign PSLVERR = PSEL && PENABLE &&
                     !(PADDR == ADDR_CTRL   ||
                       PADDR == ADDR_STATUS ||
                       PADDR == ADDR_TXDATA ||
                       PADDR == ADDR_RXDATA ||
                       PADDR == ADDR_CLKDIV ||
                       PADDR == ADDR_CONFIG);


    // ------------------------------------------------------------
    // Write Registers
    // ------------------------------------------------------------

    always @(posedge PCLK) begin

        if (!PRESETn) begin
            tx_data   <= 8'h00;
            start     <= 1'b0;
            clkdiv    <= 16'd10;
            spi_config <= 2'b00;
        end

        else begin

            // START is a one-cycle pulse.
            start <= 1'b0;

            // APB write occurs during ACCESS phase.
            if (PSEL && PENABLE && PWRITE) begin

                case (PADDR)

                    // ------------------------------------------------
                    // CTRL
                    // bit 0 = START
                    // ------------------------------------------------
                    ADDR_CTRL: begin
                        if (PSTRB[0])
                            start <= PWDATA[0];
                    end


                    // ------------------------------------------------
                    // TXDATA
                    // [7:0] = transmit data
                    // ------------------------------------------------
                    ADDR_TXDATA: begin
                        if (PSTRB[0])
                            tx_data <= PWDATA[7:0];
                    end


                    // ------------------------------------------------
                    // CLKDIV
                    // [15:0] = SPI clock divider
                    // ------------------------------------------------
                    ADDR_CLKDIV: begin
                        if (PSTRB[1:0] != 2'b00)
                            clkdiv <= PWDATA[15:0];
                    end


                    // ------------------------------------------------
                    // CONFIG
                    //
                    // bit 0 = CPOL
                    // bit 1 = CPHA
                    //
                    // 00 = Mode 0
                    // 01 = Mode 1
                    // 10 = Mode 2
                    // 11 = Mode 3
                    // ------------------------------------------------
                    ADDR_CONFIG: begin
                        if (PSTRB[0])
                            spi_config <= PWDATA[1:0];
                    end


                    default: begin
                    end

                endcase
            end
        end
    end


    // ------------------------------------------------------------
    // APB Read Logic
    // ------------------------------------------------------------

    always @(*) begin

        PRDATA = 32'h0000_0000;

        if (PSEL && !PWRITE) begin

            case (PADDR)

                // ------------------------------------------------
                // CTRL
                // START is a pulse, so read as zero.
                // ------------------------------------------------
                ADDR_CTRL: begin
                    PRDATA[0] = 1'b0;
                end


                // ------------------------------------------------
                // STATUS
                //
                // bit 0 = BUSY
                // bit 1 = DONE
                // ------------------------------------------------
                ADDR_STATUS: begin
                    PRDATA[0] = busy;
                    PRDATA[1] = done;
                end


                // ------------------------------------------------
                // TXDATA
                // ------------------------------------------------
                ADDR_TXDATA: begin
                    PRDATA[7:0] = tx_data;
                end


                // ------------------------------------------------
                // RXDATA
                // ------------------------------------------------
                ADDR_RXDATA: begin
                    PRDATA[7:0] = rx_data;
                end


                // ------------------------------------------------
                // CLKDIV
                // ------------------------------------------------
                ADDR_CLKDIV: begin
                    PRDATA[15:0] = clkdiv;
                end


                // ------------------------------------------------
                // CONFIG
                //
                // bit 0 = CPOL
                // bit 1 = CPHA
                // ------------------------------------------------
                ADDR_CONFIG: begin
                    PRDATA[1:0] = spi_config;
                end


                default: begin
                    PRDATA = 32'h0000_0000;
                end

            endcase
        end
    end

endmodule