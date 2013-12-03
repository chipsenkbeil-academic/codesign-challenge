
`timescale 1ns/10ps

module TB_collision_instruction;
  
    reg clk;
    reg clk_en;
    reg reset;
    reg start;
    reg [31:0] dataa;
    reg [31:0] datab;
    reg [2:0] n;
    wire done;
    wire [31:0] result; 
  
    CollisionInstruction #(46) U1(
        clk, clk_en, reset, start,  // Execution inputs
        dataa, datab,               // Data inputs
        n,                          // Instruction selection inputs
        done, result                // Instruction outputs
    );
    
    initial begin
        clk = 1;
        clk_en = 0;
        reset = 1;
        start = 0;
        dataa = 32'd0;
        datab = 32'd0;
        n = 3'd0;
    end
    
    always #10 clk = ~clk;
    
    // For testing purposes, using instructed base message in testbench
    // "XXXX Keep your FPGA spinning!", which is 232 bits (29 bytes x 8)    
    
    parameter WORD_SIZE = 32;
    parameter TOTAL_WORDS = 16;
    parameter BASE_MESSAGE = "XXXX Keep your FPGA spinning!";
    parameter [WORD_SIZE*TOTAL_WORDS-1:0] MESSAGE = 
        {BASE_MESSAGE,152'h0,4'h8,60'h0,32'h00000000,32'h00000180};
    
    integer i,j;
    
    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            // Send load base message instructions until entire message has
            // been loaded
            for (j = 0; j < TOTAL_WORDS; j = j + 2) begin
                #20 reset = 0;
                start = 1;
                dataa = MESSAGE[((WORD_SIZE*TOTAL_WORDS-1)-(j*WORD_SIZE))-:WORD_SIZE];
                datab = MESSAGE[((WORD_SIZE*TOTAL_WORDS-1)-((j+1)*WORD_SIZE))-:WORD_SIZE];
                n = 3'd0;
                clk_en = 1;
                
                #20 start = 0;
                clk_en = 0;
                
                wait (done);
            end
            
            // Start search collision
            #20 reset = 0;
                 start = 1;
                 dataa = i;
                 datab = 32'h00000000;
                 n     = 3'd1;
                 clk_en = 1;
            #20 start = 0;
            clk_en = 0;
                 
            wait (done);
            
            // Have to send this once to get result filled with the correct
            // status (there is no do--while loop in old Verilog)
            #20 start = 1;
                 n = 3'd3;
                 clk_en = 1;
            #20 start = 0;
            clk_en = 0;
            
            wait (done);
            
            // Keep cycling until we find a collision
            while (result != 32'd1) begin
                // Try out retrieving the current total digests computed
                #20 start = 1;
                     n = 3'd4;
                     clk_en = 1;
                #20 start = 0;
                clk_en = 0;
                
                wait (done) begin
                    $display("Total digests computed: %d", result);
                end
                
                // Now retrieve the status of our computation
                #20 start = 1;
                     n = 3'd3;
                     clk_en = 1;
                #20 start = 0;
                clk_en = 0;
                
                wait (done);
            end
            
            // Display the result of our collision detection
            #20 start = 1;
                 n = 3'd2;
                 clk_en = 1;
            #20 start = 0;
            clk_en = 0;
            
            wait (done) begin
                $display("(Target = %d) (Collision counter = %X)", i, result);
            end
        end
    end
  
endmodule
