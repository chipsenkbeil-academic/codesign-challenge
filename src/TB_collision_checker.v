
////////////////////////////////////////////////////////////////////////////////
// =============================================================================
// = TESTING CODE BELOW!
// =============================================================================

module TB_CollisionChecker;
  
    wire         oResult;
    reg  [159:0] iDat;
    reg  [4:0]   iTarget;
    reg          iClk;
  
    CollisionChecker COLLISION_CHECKER(
        .iClk(iClk), .iTarget(iTarget), 
        .iData(iDat), .oResult(oResult)
    );
    
    initial begin
        iClk = 0;
        iTarget = 5'bz;
        iDat = 160'bz;
    end
    
    initial begin
        #250  iClk    = 0;
              iTarget = 5'd0;
              iDat    = 160'h8000000000000000000000000000000000000000;
              
        // BIT 159 is 1, TARGET is 0
        // Should output 0 with clock 0
        #100  iClk    = 0;
              iTarget = 5'd0;
              iDat    = 160'h8000000000000000000000000000000000000000;
              
        // BIT 159 is 1, TARGET is 0
        // Should output 0 since MSB is 1
        #100  iClk    = 1;
              iTarget = 5'd0;
              iDat    = 160'h8000000000000000000000000000000000000000;
              
        // BIT 158 is 1, TARGET is 0
        // Should output 0 since clock 0
        #100  iClk    = 0;
              iTarget = 5'd0;
              iDat    = 160'h4000000000000000000000000000000000000000;
              
        // BIT 158 is 1, TARGET is 0
        // Should output 1 since clock 1
        #100  iClk    = 1;
              iTarget = 5'd0;
              iDat    = 160'h4000000000000000000000000000000000000000;
              
        // BIT 158 is 1, TARGET is 1
        // Should output 1 since clock 0
        #100  iClk    = 0;
              iTarget = 5'd1;
              iDat    = 160'h4000000000000000000000000000000000000000;
              
        // BIT 158 is 1, TARGET is 1
        // Should output 0 since clock 1
        #100  iClk    = 1;
              iTarget = 5'd1;
              iDat    = 160'h4000000000000000000000000000000000000000;
              
        // BIT 157 is 1, TARGET is 1
        // Should output 0 since clock 0
        #100  iClk    = 0;
              iTarget = 5'd1;
              iDat    = 160'h2000000000000000000000000000000000000000;
              
        // BIT 157 is 1, TARGET is 1
        // Should output 1 since clock 1
        #100  iClk    = 1;
              iTarget = 5'd1;
              iDat    = 160'h2000000000000000000000000000000000000000;
              
        // SKIPPING TO LAST TARGET
        
        // BIT 128 is 1, TARGET is 31
        // Should output 0 since clock 0
        #100  iClk    = 0;
              iTarget = 5'd31;
              iDat    = 160'h0000000200000000000000000000000000000000;
              
        // BIT 128 is 1, TARGET is 31
        // Should output 0 since clock 1
        #100  iClk    = 1;
              iTarget = 5'd31;
              iDat    = 160'h0000000200000000000000000000000000000000;
              
        // BIT 128 is 1, TARGET is 31
        // Should output 1 since clock 0
        #100  iClk    = 0;
              iTarget = 5'd31;
              iDat    = 160'h0000000100000000000000000000000000000000;
              
        // BIT 128 is 1, TARGET is 31
        // Should output 0 since clock 1
        #100  iClk    = 1;
              iTarget = 5'd31;
              iDat    = 160'h0000000100000000000000000000000000000000;
              
        // BIT 127 is 1, TARGET is 31
        // Should output 0 since clock 0
        #100  iClk    = 0;
              iTarget = 5'd31;
              iDat    = 160'h0000000080000000000000000000000000000000;
              
        // BIT 127 is 1, TARGET is 31
        // Should output 1 since clock 1
        #100  iClk    = 1;
              iTarget = 5'd31;
              iDat    = 160'h0000000080000000000000000000000000000000;
              
        #100  iClk    = 0;
    end
endmodule

