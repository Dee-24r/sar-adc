module sar_controller(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire cmp_in,

    output reg[7:0] dac_code
    );

    localparam [1:0]    IDLE = 2'b00,
                        LOAD = 2'b01,
                        SETTLE = 2'b10,
                        DECIDE = 2'b11;

    reg [1:0] state;

    always @(posedge clk) begin
        
        if (!rst_n) begin
            dac_code <= 8'd0;
            state <= IDLE;
        end

        else begin
            case(state)
                IDLE: begin
                    if (start)
                        state <= LOAD;
                end

                LOAD: begin
                    dac_code <= 8'b10000000;
                    state <= SETTLE;
                end

                SETTLE: begin
                    state <= DECIDE;
                end

                DECIDE: begin
                    if(!cmp_in)
                        dac_code[7] <= 1'b0;
                    state <= IDLE;
                end
            endcase
        end

    end

endmodule