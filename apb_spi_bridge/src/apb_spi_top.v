`timescale 1ns/1ps

module apb_spi_top (
    input  wire        PCLK,
    input  wire        PRESETn,

    // ------------------------------------------------------------
    // APB4 INTERFACE
    // ------------------------------------------------------------

    input  wire [31:0] PADDR,
    input  wire        PSEL,
    input  wire        PENABLE,
    input  wire        PWRITE,
    input  wire [31:0] PWDATA,
    input  wire [3:0]  PSTRB,

    output wire [31:0] PRDATA,
    output wire        PREADY,
    output wire        PSLVERR,


    // ------------------------------------------------------------
    // SPI INTERFACE
    // ------------------------------------------------------------

    input  wire        MISO,

    output wire        MOSI,
    output wire        SCLK,
    output wire        CS_N,


    // ------------------------------------------------------------
    // STATUS
    // ------------------------------------------------------------

    output wire        busy,
    output wire        done
);


    // ------------------------------------------------------------
    // INTERNAL CONNECTIONS
    // ------------------------------------------------------------

    wire [7:0]  tx_data;
    wire        start;
    wire [15:0] clkdiv;
    wire [7:0]  rx_data;


    // ------------------------------------------------------------
    // APB SLAVE
    // ------------------------------------------------------------

    apb_slave u_apb_slave (

        .PCLK    (PCLK),
        .PRESETn (PRESETn),

        .PADDR   (PADDR),
        .PSEL    (PSEL),
        .PENABLE (PENABLE),
        .PWRITE  (PWRITE),
        .PWDATA  (PWDATA),
        .PSTRB   (PSTRB),

        .PRDATA  (PRDATA),
        .PREADY  (PREADY),
        .PSLVERR (PSLVERR),

        .tx_data (tx_data),
        .start   (start),
        .clkdiv  (clkdiv),

        .rx_data (rx_data),
        .busy    (busy),
        .done    (done)
    );


    // ------------------------------------------------------------
    // SPI MASTER
    // ------------------------------------------------------------

    spi_master u_spi_master (

        .clk      (PCLK),
        .rst      (!PRESETn),

        .start    (start),
        .tx_data  (tx_data),
        .clkdiv   (clkdiv),

        .miso     (MISO),

        .mosi     (MOSI),
        .sclk     (SCLK),
        .cs_n     (CS_N),

        .busy     (busy),
        .done     (done),
        .rx_data  (rx_data)
    );

endmodule