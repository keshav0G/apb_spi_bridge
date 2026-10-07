
`timescale 1ns/1ps

module fpga_top (
    input  wire clk,
    input  wire rst_n,

    // Physical SPI pins
    input  wire MISO,
    output wire MOSI,
    output wire SCLK,
    output wire CS_N,

    // Optional status pins
    output wire busy,
    output wire done
);

    // ========================================================
    // APB signals: internal, NOT physical FPGA pins
    // ========================================================

    reg  [31:0] PADDR;
    reg         PSEL;
    reg         PENABLE;
    reg         PWRITE;
    reg  [31:0] PWDATA;
    reg  [3:0]  PSTRB;

    wire [31:0] PRDATA;
    wire        PREADY;
    wire        PSLVERR;

    // ========================================================
    // APB-SPI IP
    // ========================================================

    apb_spi_top u_apb_spi (
        .PCLK    (clk),
        .PRESETn (rst_n),

        .PADDR   (PADDR),
        .PSEL    (PSEL),
        .PENABLE (PENABLE),
        .PWRITE  (PWRITE),
        .PWDATA  (PWDATA),
        .PSTRB   (PSTRB),

        .PRDATA  (PRDATA),
        .PREADY  (PREADY),
        .PSLVERR (PSLVERR),

        .MISO    (MISO),
        .MOSI    (MOSI),
        .SCLK    (SCLK),
        .CS_N    (CS_N),

        .busy    (busy),
        .done    (done)
    );

    // ========================================================
    // One-shot APB controller
    //
    // After reset:
    //   1. Write CLKDIV = 2
    //   2. Write TXDATA = 0xA5
    //   3. Write CTRL = 1
    //   4. Wait for SPI completion
    //   5. Remain idle
    // ========================================================

    localparam [3:0]
        ST_DIV_SETUP   = 4'd0,
        ST_DIV_ACCESS  = 4'd1,
        ST_TX_SETUP    = 4'd2,
        ST_TX_ACCESS   = 4'd3,
        ST_START_SETUP = 4'd4,
        ST_START_ACCESS= 4'd5,
        ST_WAIT_BUSY   = 4'd6,
        ST_WAIT_DONE   = 4'd7,
        ST_FINISHED    = 4'd8;

    reg [3:0] state;

    always @(posedge clk) begin

        if (!rst_n) begin
            state <= ST_DIV_SETUP;
        end
        else begin
            case (state)

                ST_DIV_SETUP:
                    state <= ST_DIV_ACCESS;

                ST_DIV_ACCESS:
                    if (PREADY)
                        state <= ST_TX_SETUP;

                ST_TX_SETUP:
                    state <= ST_TX_ACCESS;

                ST_TX_ACCESS:
                    if (PREADY)
                        state <= ST_START_SETUP;

                ST_START_SETUP:
                    state <= ST_START_ACCESS;

                ST_START_ACCESS:
                    if (PREADY)
                        state <= ST_WAIT_BUSY;

                ST_WAIT_BUSY:
                    if (busy)
                        state <= ST_WAIT_DONE;

                ST_WAIT_DONE:
                    if (done)
                        state <= ST_FINISHED;

                ST_FINISHED:
                    state <= ST_FINISHED;

                default:
                    state <= ST_DIV_SETUP;

            endcase
        end
    end

    // ========================================================
    // APB output decoder
    //
    // Combinational outputs ensure each SETUP phase
    // precedes its corresponding ACCESS phase.
    // ========================================================

    always @(*) begin

        // Default: APB idle
        PADDR   = 32'h0000_0000;
        PWDATA  = 32'h0000_0000;
        PSEL    = 1'b0;
        PENABLE = 1'b0;
        PWRITE  = 1'b0;
        PSTRB   = 4'b0000;

        case (state)

            // ----------------------------------------------------
            // Write CLKDIV = 2
            // ----------------------------------------------------

            ST_DIV_SETUP,
            ST_DIV_ACCESS: begin

                PADDR   = 32'h0000_0010;
                PWDATA  = 32'd2;

                PSEL    = 1'b1;
                PENABLE = (state == ST_DIV_ACCESS);
                PWRITE  = 1'b1;
                PSTRB   = 4'b1111;

            end

            // ----------------------------------------------------
            // Write TXDATA = A5
            // ----------------------------------------------------

            ST_TX_SETUP,
            ST_TX_ACCESS: begin

                PADDR   = 32'h0000_0008;
                PWDATA  = 32'h0000_00A5;

                PSEL    = 1'b1;
                PENABLE = (state == ST_TX_ACCESS);
                PWRITE  = 1'b1;
                PSTRB   = 4'b1111;

            end

            // ----------------------------------------------------
            // Write CTRL.START = 1
            // ----------------------------------------------------

            ST_START_SETUP,
            ST_START_ACCESS: begin

                PADDR   = 32'h0000_0000;
                PWDATA  = 32'h0000_0001;

                PSEL    = 1'b1;
                PENABLE = (state == ST_START_ACCESS);
                PWRITE  = 1'b1;
                PSTRB   = 4'b1111;

            end

            default: begin
                // APB remains idle.
            end

        endcase
    end

endmodule
