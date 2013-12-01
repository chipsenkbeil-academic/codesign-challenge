
module TB_collision_searcher;
  
    reg clk;
    reg reset;
    reg start;
    reg [4:0] target;
    reg [511:0] message;
    reg [31:0] counter;
    
    wire [31:0] digests_computed;
    wire done;
    wire [31:0] result; 
  
    CollisionSearcher U1(
        clk, reset, start,          // Execution inputs
        target, message, counter,   // Data inputs
        digests_computed,           // Progress outputs
        done, result                // Result outputs
    );
    
    initial begin
        clk = 0;
        reset = 1;
        start = 0;
        target = 5'd0;
        message = 512'd0;
        counter = 32'd0;
    end
    
    always #100 clk = ~clk;
    
    // For testing purposes, using instructed base message in testbench
    // "XXXX Keep your FPGA spinning!", which is 232 bits (29 bytes x 8)    
    
    parameter WORD_SIZE = 32;
    parameter TOTAL_WORDS = 16;
    parameter BASE_MESSAGE = "XXXX Keep your FPGA spinning!";
    parameter [WORD_SIZE*TOTAL_WORDS-1:0] MESSAGE = 
        {BASE_MESSAGE,152'h0,4'h8,60'h0,32'h00000000,32'h00000180};
    
    integer i;
    
    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            // Start execution of next collision search
            #200 reset   = 0;
                 start   = 1;
                 target  = i;
                 message = MESSAGE;
                 counter = 32'h0;
                 
            #200 start   = 0;
                 
            wait (done) begin
                $display("(Target is %d) Collision at %h", i, result);
            end
        end
    end
  
endmodule