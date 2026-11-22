`timescale 1ns/1ps

module sar_controller_tb;
    reg clk;
    reg rst_n;
    reg start;
    reg cmp_in;
    wire [7:0] dac_code;

    sar_controller dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .cmp_in(cmp_in),
        .dac_code(dac_code)
    );

    always #5 clk = ~clk;


    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        start = 1'b0;
        cmp_in = 1'b0;

        @(negedge clk);
        rst_n = 1'b1;
        start = 1'b1;

        @(negedge clk);
        start = 1'b0;

        @(negedge clk);
        if (dac_code !== 8'd128)
            $fatal(1, "After LOAD: expected 128, got %0d", dac_code);

        repeat (2) @(negedge clk);
        if (dac_code !== 8'd0)
            $fatal(1, "After DECIDE: expected 0, got %0d", dac_code);

        $display("PASS");
        $finish;

    end

endmodule