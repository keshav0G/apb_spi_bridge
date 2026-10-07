`timescale 1ns/1ps

module apb_tb;

    reg PCLK;
    reg PRESETn;

    reg [31:0] PADDR;
    reg PSEL;
    reg PENABLE;
    reg PWRITE;
    reg [31:0] PWDATA;
    reg [3:0] PSTRB;

    wire [31:0] PRDATA;
    wire PREADY;
    wire PSLVERR;

    wire [7:0] tx_data;
    wire start;
    wire [15:0] clkdiv;

    reg [7:0] rx_data;
    reg busy;
    reg done;


    // ------------------------------------------------
    // DUT
    // ------------------------------------------------

    apb_slave dut (
        .PCLK     (PCLK),
        .PRESETn  (PRESETn),

        .PADDR    (PADDR),
        .PSEL     (PSEL),
        .PENABLE  (PENABLE),
        .PWRITE   (PWRITE),
        .PWDATA   (PWDATA),
        .PSTRB    (PSTRB),

        .PRDATA   (PRDATA),
        .PREADY   (PREADY),
        .PSLVERR  (PSLVERR),

        .tx_data  (tx_data),
        .start    (start),
        .clkdiv   (clkdiv),

        .rx_data  (rx_data),
        .busy     (busy),
        .done     (done)
    );


    // ------------------------------------------------
    // Clock
    // ------------------------------------------------

    initial begin
        PCLK = 0;
        forever #5 PCLK = ~PCLK;
    end


    // ------------------------------------------------
    // APB WRITE TASK
    // ------------------------------------------------

    task apb_write;

        input [31:0] addr;
        input [31:0] data;

        begin

            // SETUP
            @(posedge PCLK);
            PADDR   <= addr;
            PWDATA  <= data;
            PWRITE  <= 1'b1;
            PSEL    <= 1'b1;
            PENABLE <= 1'b0;
            PSTRB   <= 4'b1111;

            // ACCESS
            @(posedge PCLK);
            PENABLE <= 1'b1;

            // End transaction
            @(posedge PCLK);
            PSEL    <= 1'b0;
            PENABLE <= 1'b0;
            PWRITE  <= 1'b0;

        end

    endtask


    // ------------------------------------------------
    // APB READ TASK
    // ------------------------------------------------

    task apb_read;

        input [31:0] addr;

        begin

            // SETUP
            @(posedge PCLK);
            PADDR   <= addr;
            PWRITE  <= 1'b0;
            PSEL    <= 1'b1;
            PENABLE <= 1'b0;
            PSTRB   <= 4'b0000;

            // ACCESS
            @(posedge PCLK);
            PENABLE <= 1'b1;

            #1;

            $display(
                "READ addr=%h data=%h error=%b",
                addr,
                PRDATA,
                PSLVERR
            );

            // End transaction
            @(posedge PCLK);
            PSEL    <= 1'b0;
            PENABLE <= 1'b0;

        end

    endtask


    // ------------------------------------------------
    // Test
    // ------------------------------------------------

    initial begin

        $dumpfile("apb_tb.vcd");
        $dumpvars(0, apb_tb);

        PADDR   = 0;
        PWDATA  = 0;
        PSEL    = 0;
        PENABLE = 0;
        PWRITE  = 0;
        PSTRB   = 0;

        rx_data = 8'h3C;
        busy    = 0;
        done    = 0;

        // Reset
        PRESETn = 0;

        repeat (3)
            @(posedge PCLK);

        PRESETn = 1;

        // --------------------------------------------
        // Test TXDATA
        // --------------------------------------------

        apb_write(32'h0000_0008, 32'h0000_00A5);

        apb_read(32'h0000_0008);


        // --------------------------------------------
        // Test CLKDIV
        // --------------------------------------------

        apb_write(32'h0000_0010, 32'd13);

        apb_read(32'h0000_0010);


        // --------------------------------------------
        // Test START
        // --------------------------------------------

        apb_write(32'h0000_0000, 32'h0000_0001);


        // --------------------------------------------
        // Test STATUS
        // --------------------------------------------

        busy = 1;
        done = 0;

        apb_read(32'h0000_0004);


        // --------------------------------------------
        // Test RXDATA
        // --------------------------------------------

        apb_read(32'h0000_000C);


        // --------------------------------------------
        // Invalid address
        // --------------------------------------------

        apb_read(32'h0000_0100);


        #20;

        $finish;

    end

endmodule