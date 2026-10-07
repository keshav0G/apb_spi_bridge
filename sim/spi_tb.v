`timescale 1ns/1ps

module spi_tb;

    reg clk;
    reg rst;

    reg start;
    reg [7:0] tx_data;
    reg [15:0] clkdiv;

    wire miso;
    wire mosi;
    wire sclk;
    wire cs_n;

    wire busy;
    wire done;

    wire [7:0] rx_data;


    // --------------------------------------------
    // DUT
    // --------------------------------------------

    spi_master dut (
        .clk      (clk),
        .rst      (rst),

        .start    (start),
        .tx_data  (tx_data),
        .clkdiv   (clkdiv),

        .miso     (miso),
        .mosi     (mosi),
        .sclk     (sclk),
        .cs_n     (cs_n),

        .busy     (busy),
        .done     (done),
        .rx_data  (rx_data)
    );


    // --------------------------------------------
    // 27 MHz-ish simulation clock
    // --------------------------------------------

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end


    // --------------------------------------------
    // Simple SPI slave
    //
    // Slave sends 0x3C
    // 0011 1100
    // --------------------------------------------

    reg [7:0] slave_tx;
    reg [7:0] slave_rx;
    reg [3:0] slave_bit;


    assign miso = (!cs_n) ? slave_tx[7] : 1'b0;


    // Sample master's MOSI on rising edge
    always @(posedge sclk) begin

        if (!cs_n) begin

            slave_rx <= {
                slave_rx[6:0],
                mosi
            };

        end

    end


    // Change MISO on falling edge
    always @(negedge sclk) begin

        if (!cs_n) begin

            slave_tx <= {
                slave_tx[6:0],
                1'b0
            };

        end

    end


    // --------------------------------------------
    // Test
    // --------------------------------------------

    initial begin

        $dumpfile("spi_tb.vcd");
        $dumpvars(0, spi_tb);

        rst     = 1'b1;
        start   = 1'b0;
        tx_data = 8'h00;
        clkdiv  = 16'd2;

        slave_tx = 8'h3C;
        slave_rx = 8'h00;
        slave_bit = 0;


        // Reset
        repeat (5)
            @(posedge clk);

        rst = 1'b0;


        // ----------------------------------------
        // Send A5
        // Receive 3C
        // ----------------------------------------

        tx_data = 8'hA5;

        @(posedge clk);
        start = 1'b1;

        @(posedge clk);
        start = 1'b0;


       fork

    begin
        wait(done);
        $display("DONE detected at time %0t", $time);
    end

    begin
        #5000;
        $display("ERROR: SPI TIMEOUT!");
        $finish;
    end

join_any

disable fork;

#20;

        $display("--------------------------------");
        $display("SPI TEST COMPLETE");
        $display("TX = %h", tx_data);
        $display("RX = %h", rx_data);
        $display("SLAVE RX = %h", slave_rx);
        $display("--------------------------------");


        if (rx_data == 8'h3C &&
            slave_rx == 8'hA5) begin

            $display("PASS");

        end

        else begin

            $display("FAIL");

        end


        #20;

        $finish;

    end

endmodule