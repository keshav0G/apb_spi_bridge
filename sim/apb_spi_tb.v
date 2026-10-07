`timescale 1ns/1ps

module apb_spi_tb;

    reg clk;
    reg rst_n;

    // --------------------------------------------
    // APB signals
    // --------------------------------------------

    reg [31:0] PADDR;
    reg        PSEL;
    reg        PENABLE;
    reg        PWRITE;
    reg [31:0] PWDATA;
    reg [3:0]  PSTRB;

    wire [31:0] PRDATA;
    wire        PREADY;
    wire        PSLVERR;


    // --------------------------------------------
    // SPI signals
    // --------------------------------------------

    wire SCLK;
    wire MOSI;
    wire MISO;
    wire CS_N;


    // --------------------------------------------
    // DUT
    // --------------------------------------------

  apb_spi_top dut (

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


    // --------------------------------------------
    // System clock
    // --------------------------------------------

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end


    // --------------------------------------------
    // SPI slave
    //
    // Slave sends 0x3C.
    // --------------------------------------------

    reg [7:0] slave_tx;
    reg [7:0] slave_rx;

    assign MISO = (!CS_N) ? slave_tx[7] : 1'b0;


    // Sample MOSI on rising edge
    always @(posedge SCLK) begin

        if (!CS_N) begin

            slave_rx <= {
                slave_rx[6:0],
                MOSI
            };

        end

    end


    // Change MISO on falling edge
    always @(negedge SCLK) begin

        if (!CS_N) begin

            slave_tx <= {
                slave_tx[6:0],
                1'b0
            };

        end

    end


    // --------------------------------------------
    // APB WRITE TASK
    // --------------------------------------------

    task apb_write;

        input [31:0] addr;
        input [31:0] data;

        begin

            // SETUP phase

            @(negedge clk);

            PADDR   <= addr;
            PWDATA  <= data;
            PWRITE  <= 1'b1;
            PSEL    <= 1'b1;
            PENABLE <= 1'b0;
            PSTRB   <= 4'b1111;


            // ACCESS phase

            @(negedge clk);

            PENABLE <= 1'b1;


            // End transaction

            @(negedge clk);

            PSEL    <= 1'b0;
            PENABLE <= 1'b0;
            PWRITE  <= 1'b0;

        end

    endtask


    // --------------------------------------------
    // APB READ TASK
    // --------------------------------------------

    task apb_read;

        input [31:0] addr;
        output [31:0] data;

        begin

            // SETUP

            @(negedge clk);

            PADDR   <= addr;
            PWRITE  <= 1'b0;
            PSEL    <= 1'b1;
            PENABLE <= 1'b0;
            PSTRB   <= 4'b0000;


            // ACCESS

            @(negedge clk);

            PENABLE <= 1'b1;


            // Give combinational PRDATA time to settle

            @(posedge clk);

            data = PRDATA;


            // End transaction

            @(negedge clk);

            PSEL    <= 1'b0;
            PENABLE <= 1'b0;

        end

    endtask


    // --------------------------------------------
    // Test
    // --------------------------------------------

    reg [31:0] read_data;


    initial begin

        $dumpfile("apb_spi_tb.vcd");
        $dumpvars(0, apb_spi_tb);


        // ----------------------------------------
        // Initial values
        // ----------------------------------------

        rst_n    = 1'b0;

        PADDR    = 32'h0;
        PWDATA   = 32'h0;
        PSEL     = 1'b0;
        PENABLE  = 1'b0;
        PWRITE   = 1'b0;
        PSTRB    = 4'b0;

        slave_tx = 8'h3C;
        slave_rx = 8'h00;


        // ----------------------------------------
        // Reset
        // ----------------------------------------

        repeat (5)
            @(posedge clk);

        rst_n = 1'b1;


        // ----------------------------------------
        // Configure SPI divider
        // ----------------------------------------

        apb_write(
            32'h0000_0010,
            32'd2
        );


        // ----------------------------------------
        // Write TX data
        // ----------------------------------------

        apb_write(
            32'h0000_0008,
            32'h0000_00A5
        );


        // ----------------------------------------
        // Start SPI transfer
        // ----------------------------------------

        apb_write(
            32'h0000_0000,
            32'h0000_0001
        );


        // ----------------------------------------
        // Wait for SPI transaction to finish
        // ----------------------------------------

        wait(CS_N == 1'b1);

        $display(
            "SPI transaction complete at %0t",
            $time
        );

        // Wait until SPI completes
            wait(done == 1'b1);

            $display(
                "SPI transfer complete at %0t",
                $time
            );

        // ----------------------------------------
        // Read RXDATA
        // ----------------------------------------

        apb_read(
            32'h0000_000C,
            read_data
        );


        // ----------------------------------------
        // Results
        // ----------------------------------------

        $display("--------------------------------");
        $display("APB-SPI TEST");
        $display("Master TX = A5");
        $display("Slave RX  = %h", slave_rx);
        $display("Master RX = %h", read_data);
        $display("--------------------------------");


        if ((slave_rx == 8'hA5) &&
            (read_data == 32'h0000_003C)) begin

            $display("PASS");

        end

        else begin

            $display("FAIL");

        end


        #50;

        $finish;

    end

endmodule