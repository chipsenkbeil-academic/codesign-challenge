
module TB_message_collector;
  
    reg clk;
    reg reset;
    reg start;
    reg [31:0] a;
    reg [31:0] b;
    wire [511:0] message; 
  
    MessageCollector U1(
        clk, reset, start,  // Execution inputs
        a, b,               // Data inputs
        message             // Message output 
    );
    
    initial begin
        clk = 1;
        reset = 1;
        start = 0;
        a = 32'd0;
        b = 32'd0;
    end
    
    always #100 clk = ~clk;
    
    // For testing purposes, using instructed base message in testbench
    // "XXXX Keep your FPGA spinning!", which is 232 bits (29 bytes x 8)    
    
    parameter WORD_SIZE = 32;
    parameter TOTAL_WORDS = 16;
    parameter BASE_MESSAGE = "XXXX Keep your FPGA spinning!";
    parameter [WORD_SIZE*TOTAL_WORDS-1:0] MESSAGE = 
        {BASE_MESSAGE,152'h0,4'h8,60'h0,32'h00000000,32'h00000180};
    
    integer j;
    
    initial begin
        // Test changing input with start disabled
        for (j = 0; j < TOTAL_WORDS; j = j + 2) begin
            #200 reset = 0;
            start = 0;
            a = MESSAGE[((WORD_SIZE*TOTAL_WORDS-1)-(j*WORD_SIZE))-:WORD_SIZE];
            b = MESSAGE[((WORD_SIZE*TOTAL_WORDS-1)-((j+1)*WORD_SIZE))-:WORD_SIZE];
            
            #200 start = 0;
        end
    
        // Test sending the message we have defined
        for (j = 0; j < TOTAL_WORDS; j = j + 2) begin
            #200 reset = 0;
            start = 1;
            a = MESSAGE[((WORD_SIZE*TOTAL_WORDS-1)-(j*WORD_SIZE))-:WORD_SIZE];
            b = MESSAGE[((WORD_SIZE*TOTAL_WORDS-1)-((j+1)*WORD_SIZE))-:WORD_SIZE];
            
            #200 start = 0;
        end
        
        // Test the reset
        #200 reset = 1;
        #200 reset = 0;
        
        // Test sending the message we have defined (again)
        for (j = 0; j < TOTAL_WORDS; j = j + 2) begin
            #200 reset = 0;
            start = 1;
            a = MESSAGE[((WORD_SIZE*TOTAL_WORDS-1)-(j*WORD_SIZE))-:WORD_SIZE];
            b = MESSAGE[((WORD_SIZE*TOTAL_WORDS-1)-((j+1)*WORD_SIZE))-:WORD_SIZE];
            
            #200 start = 0;
        end
        
        // Test sending an override series of bytes
        for (j = 0; j < TOTAL_WORDS; j = j + 2) begin
            #200 reset = 0;
            start = 1;
            a = 32'h01234567;
            b = 32'h89ABCDEF;
            
            #200 start = 0;
        end
        
        
    end
  
endmodule
