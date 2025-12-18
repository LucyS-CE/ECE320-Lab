module pd(
  input clock,
  input reset
);

  reg [31:0] imemory_pc;
  wire [31:0] imemory_insn;

  wire [31:0]  pd_pc;
  reg [6:0]   pd_opcode;
  reg [4:0]   pd_rd;
  reg [2:0]   pd_funct3;
  reg [4:0]   pd_rs1;
  reg [4:0]   pd_rs2;
  reg [6:0]   pd_funct7;
  reg [31:0]  pd_imm;
  reg [4:0]   pd_shamt;

  imemory imemory_0 (
    .clock(clock),
    .address(imemory_pc),
    .data_in(32'b0),    // no data in @ fetch stage
    .read_write(1'b0),  // no write @ fetch stage
    .data_out(imemory_insn)
  );

initial begin
  imemory_pc = 32'h0100_0000;
end

// PC fetch stage
always @(posedge clock) begin
  if(reset) begin
    imemory_pc <= 32'h0100_0000;
    // pd_pc <= 32'h0100_0000;
  end
  else begin
    imemory_pc <= imemory_pc + 32'd4;
    // pd_pc <= imemory_pc;
  end
end

// instruction decode stage (combinational)
assign pd_pc = imemory_pc;
always @* begin
  // default values
  pd_opcode = imemory_insn[6:0];
  pd_rd     = 5'd0;
  pd_funct3 = 3'd0;
  pd_rs1    = 5'd0;
  pd_rs2    = 5'd0;
  pd_funct7 = 7'd0;
  pd_imm    = 32'd0;
  pd_shamt  = 5'd0;

  case (pd_opcode)
    7'b0110011: begin // R type
      pd_rd     = imemory_insn[11:7];
      pd_funct3 = imemory_insn[14:12];
      pd_rs1    = imemory_insn[19:15];
      pd_rs2    = imemory_insn[24:20];
      pd_funct7 = imemory_insn[31:25];
    end

    7'b0010011: begin // I type 
      pd_rd     = imemory_insn[11:7];
      pd_funct3 = imemory_insn[14:12];
      pd_rs1    = imemory_insn[19:15];
      if (pd_funct3==3'b001 || pd_funct3==3'b101) begin
        pd_shamt  = imemory_insn[24:20];
        pd_funct7 = imemory_insn[31:25]; // SRLI/SRAI
      end else begin
        pd_imm = {{20{imemory_insn[31]}}, imemory_insn[31:20]}; // SLLI
      end
    end

    7'b0000011: begin // I type - load
      pd_rd     = imemory_insn[11:7];
      pd_funct3 = imemory_insn[14:12];
      pd_rs1    = imemory_insn[19:15];
      pd_imm    = {{20{imemory_insn[31]}}, imemory_insn[31:20]};
    end

    7'b0100011: begin // S type
      pd_funct3 = imemory_insn[14:12];
      pd_rs1    = imemory_insn[19:15];
      pd_rs2    = imemory_insn[24:20];
      pd_imm    = {{20{imemory_insn[31]}}, imemory_insn[31:25], imemory_insn[11:7]};
    end

    7'b1100011: begin // B type
      pd_funct3 = imemory_insn[14:12];
      pd_rs1    = imemory_insn[19:15];
      pd_rs2    = imemory_insn[24:20];
      pd_imm    = {{19{imemory_insn[31]}}, imemory_insn[31], imemory_insn[7],
                   imemory_insn[30:25], imemory_insn[11:8], 1'b0};
    end

    7'b1101111: begin // J type - JAL
      pd_rd  = imemory_insn[11:7];
      pd_imm = {{12{imemory_insn[31]}}, imemory_insn[19:12],
                imemory_insn[20], imemory_insn[30:21], 1'b0};
    end

    7'b1100111: begin // J type - JALR
      pd_rd     = imemory_insn[11:7];
      pd_funct3 = imemory_insn[14:12]; 
      pd_rs1    = imemory_insn[19:15];
      pd_imm    = {{20{imemory_insn[31]}}, imemory_insn[31:20]};
    end

    7'b0110111, 7'b0010111: begin // U type - LUI & AUIPC
      pd_rd  = imemory_insn[11:7];
      pd_imm = {imemory_insn[31:12], 12'b0};
    end

    default: begin
      // do nothing, all default values
    end
  endcase
end
endmodule
