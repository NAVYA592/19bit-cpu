module pipe_CPU19 (clk1, clk2); 
 input clk1, clk2; // Two-phase clock 
 reg [18:0] PC, IF_ID_IR, IF_ID_NPC; 
 reg [18:0] ID_EX_IR, ID_EX_NPC, ID_EX_A, ID_EX_B, ID_EX_Imm; 
 reg [2:0] ID_EX_type, EX_MEM_type, MEM_WB_type; 
 reg [18:0] EX_MEM_IR, EX_MEM_ALUOut, EX_MEM_B; 
 reg EX_MEM_cond; 
 reg [18:0] MEM_WB_IR, MEM_WB_ALUOut, MEM_WB_LMD; 
 reg [18:0] Reg [0:31]; // Register bank (32 x 19) 
 reg [18:0] Mem [0:1023]; // 1024 x 19 memory
 parameter ADD=6'b000000, SUB=6'b000001, AND=6'b000010, OR=6'b000011, SLT=6'b000100, MUL=6'b000101, HLT=6'b111111, LW=6'b001000, SW=6'b001001, ADDI=6'b001010, SUBI=6'b001011, SLTI=6'b001100, BNEQZ=6'b001101, BEQZ=6'b001110;
 parameter RR_ALU=3'b000, RM_ALU=3'b001, LOAD=3'b010, STORE=3'b011, BRANCH=3'b100, HALT=3'b101; 
 reg HALTED; 
 // Set after HLT instruction is completed (in WB stage) 
 reg TAKEN_BRANCH; 
 // Required to disable instructions after branch

always @(posedge clk1) // IF Stage 
 if (HALTED == 0) 
 begin 
   if (((EX_MEM_IR[18:13] == BEQZ) && (EX_MEM_cond == 1)) || 
       ((EX_MEM_IR[18:13] == BNEQZ) && (EX_MEM_cond == 0))) 
   begin 
     IF_ID_IR <= #2 Mem[EX_MEM_ALUOut]; 
     TAKEN_BRANCH <= #2 1'b1; 
     IF_ID_NPC <= #2 EX_MEM_ALUOut + 1; 
     PC <= #2 EX_MEM_ALUOut + 1; 
   end
   else 
   begin 
     IF_ID_IR <= #2 Mem[PC]; 
     IF_ID_NPC <= #2 PC + 1; 
     PC <= #2 PC + 1; 
   end 
 end

always @(posedge clk2) // ID Stage 
 if (HALTED == 0) 
 begin 
   if (IF_ID_IR[12:8] == 5'b00000) ID_EX_A <= 0; 
   else ID_EX_A <= #2 Reg[IF_ID_IR[12:8]]; // "rs" 
   if (IF_ID_IR[7:3] == 5'b00000) ID_EX_B <= 0; 
   else ID_EX_B <= #2 Reg[IF_ID_IR[7:3]]; // "rt" 
   ID_EX_NPC <= #2 IF_ID_NPC; 
   ID_EX_IR <= #2 IF_ID_IR; 
   ID_EX_Imm <= #2 {{13{IF_ID_IR[5]}}, {IF_ID_IR[5:0]}}; // 13-bit sign extension
   case (IF_ID_IR[18:13]) 
     ADD, SUB, AND, OR, SLT, MUL: ID_EX_type <= #2 RR_ALU; 
     ADDI, SUBI, SLTI: ID_EX_type <= #2 RM_ALU; 
     LW: ID_EX_type <= #2 LOAD; 
     SW: ID_EX_type <= #2 STORE; 
     BNEQZ, BEQZ: ID_EX_type <= #2 BRANCH; 
     HLT: ID_EX_type <= #2 HALT; 
     default: ID_EX_type <= #2 HALT; 
     // Invalid opcode
   endcase
 end

always @(posedge clk1) // EX Stage 
 if (HALTED == 0) 
 begin 
   EX_MEM_type <= #2 ID_EX_type; 
   EX_MEM_IR <= #2 ID_EX_IR; 
   TAKEN_BRANCH <= #2 0; 
   case (ID_EX_type) 
     RR_ALU: begin 
       case (ID_EX_IR[18:13]) // "opcode" 
         ADD: EX_MEM_ALUOut <= #2 ID_EX_A + ID_EX_B; 
         SUB: EX_MEM_ALUOut <= #2 ID_EX_A - ID_EX_B; 
         AND: EX_MEM_ALUOut <= #2 ID_EX_A & ID_EX_B; 
         OR: EX_MEM_ALUOut <= #2 ID_EX_A | ID_EX_B; 
         SLT: EX_MEM_ALUOut <= #2 (ID_EX_A < ID_EX_B); 
         MUL: EX_MEM_ALUOut <= #2 ID_EX_A * ID_EX_B; 
         default: EX_MEM_ALUOut <= #2 19'hxxxxx; 
       endcase
     end
     RM_ALU: begin 
       case (ID_EX_IR[18:13]) // "opcode" 
         ADDI: EX_MEM_ALUOut <= #2 ID_EX_A + ID_EX_Imm; 
         SUBI: EX_MEM_ALUOut <= #2 ID_EX_A - ID_EX_Imm; 
         SLTI: EX_MEM_ALUOut <= #2 (ID_EX_A < ID_EX_Imm); 
         default: EX_MEM_ALUOut <= #2 19'hxxxxx; 
       endcase
     end
     LOAD, STORE: 
     begin 
       EX_MEM_ALUOut <= #2 ID_EX_A + ID_EX_Imm; 
       EX_MEM_B <= #2 ID_EX_B; 
     end
     BRANCH: begin 
       EX_MEM_ALUOut <= #2 ID_EX_NPC + ID_EX_Imm; 
       EX_MEM_cond <= #2 (ID_EX_A == 0); 
     end 
   endcase
 end

always @(posedge clk2) // MEM Stage 
 if (HALTED == 0) 
 begin 
   MEM_WB_type <= EX_MEM_type; 
   MEM_WB_IR <= #2 EX_MEM_IR; 
   case (EX_MEM_type) 
     RR_ALU, RM_ALU: 
       MEM_WB_ALUOut <= #2 EX_MEM_ALUOut; 
     LOAD: 
       MEM_WB_LMD <= #2 Mem[EX_MEM_ALUOut]; 
     STORE: 
       if (TAKEN_BRANCH == 0) // Disable write 
         Mem[EX_MEM_ALUOut] <= #2 EX_MEM_B; 
   endcase
 end

always @(posedge clk1) // WB Stage 
 begin 
   if (TAKEN_BRANCH == 0) // Disable write if branch taken 
   case (MEM_WB_type) 
     RR_ALU: 
       Reg[MEM_WB_IR[7:3]] <= #2 MEM_WB_ALUOut; // "rd" 
     RM_ALU: 
       Reg[MEM_WB_IR[7:3]] <= #2 MEM_WB_ALUOut; // "rt" 
     LOAD: 
       Reg[MEM_WB_IR[7:3]] <= #2 MEM_WB_LMD; // "rt" 
     HALT: 
       HALTED <= #2 1'b1; 
   endcase
 end 

endmodule

module test_cpu19; 
 reg clk1, clk2; 
 integer k; 
 pipe_CPU19 dut(.clk1(clk1), .clk2(clk2)); 

 initial begin 
   clk1 = 0; 
   clk2 = 0; 
   repeat (20) // Generating two-phase clock 
   begin 
     #5 clk1 = 1; #5 clk1 = 0; 
     #5 clk2 = 1; #5 clk2 = 0; 
   end 
 end 

 initial begin 
   // Initialize registers and memory
   for (k=0; k<31; k++) 
     dut.Reg[k] = k; // Notice "dut" instead of "cpu"

   dut.Mem[0] = 19'h2801a; // ADDI R1, R0, 10 
   dut.Mem[1] = 19'h2802c; // ADDI R2, R0, 20 
   dut.Mem[2] = 19'h28033; // ADDI R3, R0, 25 
   dut.Mem[3] = 19'h0ce77; // OR R7, R7, R7 -- dummy instr. 
   dut.Mem[4] = 19'h0ce77; // OR R7, R7, R7 -- dummy instr. 
   dut.Mem[5] = 19'h02220;  // ADD R4, R1, R2 
   dut.Mem[6] = 19'h0ce77; // OR R7, R7, R7 -- dummy instr. 
   dut.Mem[7] = 19'h08328;  // ADD R5, R4, R3 
   dut.Mem[8] = 19'h00000;  // HLT

   dut.HALTED = 0; 
   dut.PC = 0; 
   dut.TAKEN_BRANCH = 0; 
   
   #280 
   for (k=0; k<6; k++) 
     $display ("R%1d - %2d", k, dut.Reg[k]); // Use "dut" instead of "cpu"
 end 

 initial begin 
   $dumpfile ("cpu19.vcd"); 
   $dumpvars (0, test_cpu19); 
   #300 $finish; 
 end 
endmodule
