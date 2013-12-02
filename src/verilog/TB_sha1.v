
module TB_sha1;

    wire [159:0] oDat;
    wire         oReady;
    reg  [31:0]  iDat;
    reg          iClk;
    reg          iInitial;
    reg          iValid;
    reg          reset;

    sha1 SHA(oDat, oReady, iDat, iClk, iInitial, iValid, reset);

    initial begin
        iClk = 1;
        iInitial = 0;
        iValid = 0;
        reset = 1;
    end
    
    always #100 iClk = ~iClk;

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
            // Load the message with different counter values
            for (j = 0; j < TOTAL_WORDS; j = j + 1) begin
                #200 reset = 0;
                iInitial = (j == 0);
                iValid = 1;
                if (j == 0)
                    iDat = i;
                else
                    iDat = MESSAGE[((WORD_SIZE*TOTAL_WORDS-1)-(j*WORD_SIZE))-:WORD_SIZE];
            end
            
            // Start search collision
            #200 iValid = 0;
                 iInitial = 0;
                 iDat = 32'b0;
                 
            wait (oReady);
        end
    end

endmodule
