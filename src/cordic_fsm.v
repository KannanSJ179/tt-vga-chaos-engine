`default_nettype none
`timescale 1ns / 1ps

module cordic_fsm (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    output reg  [3:0] iter,
    output reg        en,
    output reg        done
);

    reg [1:0] state;
    localparam IDLE = 2'd0, COMPUTE = 2'd1, DONE = 2'd2;

    always @(posedge clk) begin
        // STRICT GATE-LEVEL RESET: Every single register must be cleared
        if (!rst_n) begin
            state <= IDLE;
            iter  <= 4'd0;
            en    <= 1'b0;
            done  <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        iter  <= 4'd0;
                        en    <= 1'b1;
                    end else begin
                        en    <= 1'b0;
                    end
                end
                
                COMPUTE: begin
                    if (iter == 4'd15) begin
                        state <= DONE;
                        en    <= 1'b0;
                        done  <= 1'b1;
                    end else begin
                        iter  <= iter + 1'b1;
                    end
                end
                
                DONE: begin
                    done  <= 1'b0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
