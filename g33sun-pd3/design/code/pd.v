module pd(
    input clock,
    input reset
);
    // instantiate imemory
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
    
    // PD3: Add execute stage probe signals
    reg [31:0] pd_es_pc;
    reg [31:0] pd_es_alu_res;
    reg pd_es_br_taken;
    
    imemory imemory_0 (
        .clock(clock),
        .address(imemory_pc),
        .data_in(32'b0),    // no data in @ fetch stage
        .read_write(1'b0),  // no write @ fetch stage
        .data_out(imemory_insn)
    );

    // Data memory ports
    reg [31:0] d_addr, d_wdata;
    reg d_we;           // 1: write, 0: read
    wire [31:0] d_rdata;

    imemory dmemory_0 (
        .clock(clock),
        .address(d_addr),
        .data_in(d_wdata),
        .read_write(d_we),
        .data_out(d_rdata)
    );


    // instantiate register_file
    reg register_file_write_enable;
    reg [4:0] register_file_write_destination;
    reg [31:0] register_file_write_data;
    wire [4:0] register_file_read_rs1 = pd_rs1;
    wire [4:0] register_file_read_rs2 = pd_rs2;
    wire [31:0] register_file_read_rs1_data;
    wire [31:0] register_file_read_rs2_data;
    register_file register_file_0 (
        .clock(clock),
        // .write_enable(register_file_write_enable),
        .write_enable(1'b0), // pd3: no write back
        .addr_rs1(register_file_read_rs1),
        .addr_rs2(register_file_read_rs2),
        .addr_rd(register_file_write_destination),
        .data_rd(register_file_write_data),
        .data_rs1(register_file_read_rs1_data),
        .data_rs2(register_file_read_rs2_data)
    );

initial begin
    imemory_pc = 32'h0100_0000;
end

// ============== PC fetch stage ================
reg [31:0] pc_plus4 = imemory_pc + 32'd4;
reg [31:0] next_pc;
always @(posedge clock) begin
    if(reset) begin
        imemory_pc <= 32'h0100_0000;
        // pd_pc <= 32'h0100_0000;
    end
    else begin
        imemory_pc <= next_pc;
        // pd_pc <= imemory_pc;
    end
end

// ================ instruction decode stage (combinational) =================
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

// =========== execution stage (combinational) ==============
wire [8:0] instruction_type_code = {imemory_insn[30], imemory_insn[14:12], imemory_insn[6:2]};  // get instruction type code (9 bits)

// ALU
reg [31:0] alu_a, alu_b;
reg [31:0] alu_result;
reg [3:0]  alu_control;
localparam ALU_ADD = 4'b0000, ALU_SUB = 4'b0001,
           ALU_AND = 4'b0010, ALU_OR = 4'b0011,
           ALU_XOR = 4'b0100, ALU_SLL = 4'b0101, 
           ALU_SRL = 4'b0110, ALU_SRA = 4'b0111,
           ALU_SLT = 4'b1000, ALU_SLTU = 4'b1001,
           ALU_PASSB = 4'b1010;

always @* begin
    case (alu_control)
        ALU_ADD : alu_result = alu_a + alu_b;  // ADD/ADDI // LUI/AUIPC
        ALU_SUB : alu_result = alu_a - alu_b;  // SUB
        ALU_AND : alu_result = alu_a & alu_b;  // AND/ANDI
        ALU_OR  : alu_result = alu_a | alu_b;  // OR/ORI
        ALU_XOR : alu_result = alu_a ^ alu_b;  // XOR/XORI
        ALU_SLL : alu_result = alu_a << alu_b[4:0];  // SLL/SLLI
        ALU_SRL : alu_result = alu_a >> alu_b[4:0];  // SRL/SRLI
        ALU_SRA : alu_result = $signed(alu_a) >>> alu_b[4:0];   // SRA/SRAI
        ALU_SLT : alu_result = ($signed(alu_a) <  $signed(alu_b)) ? 32'd1 : 32'd0;  // SLT/SLTI
        ALU_SLTU: alu_result = (alu_a < alu_b) ? 32'd1 : 32'd0;   // SLTU/SLTIU
        ALU_PASSB: alu_result = alu_b;   // LUI
        default : alu_result = 32'd0;
    endcase
end


reg [31:0] next_pc_local;
reg [31:0] ea;  // effective address for memory operations
reg [31:0] wmask, wshift;

// execute stage main logic
always @* begin
    pd_es_pc = pd_pc;                    // pass PC to execute stage
    pd_es_alu_res = alu_result;          // ALU result for probe
    pd_es_br_taken = 1'b0;               // default: branch not taken

    d_addr  = 32'd0;
    d_we    = 1'b0;
    d_wdata = 32'd0;
    wmask   = 32'd0;
    wshift  = 32'd0;
    
    // default values for other signals
    alu_a = register_file_read_rs1_data;
    alu_b = register_file_read_rs2_data;
    alu_control = ALU_ADD;
    register_file_write_destination = 5'd0;
    register_file_write_enable = 1'b0;
    register_file_write_data = alu_result;
    next_pc = pc_plus4;
    next_pc_local = pc_plus4;           // default: PC+4
    ea = register_file_read_rs1_data + pd_imm;  // calculate effective address

    casez(instruction_type_code)
        9'b0_000_01100: begin  // ADD
            alu_control = ALU_ADD;
            register_file_write_enable = 1'b1;
            register_file_write_destination = pd_rd;
            register_file_write_data = alu_result;
        end

        9'b1_000_01100: begin  // SUB
            alu_control = ALU_SUB;
            register_file_write_enable = 1'b1;
            register_file_write_destination = pd_rd;
            register_file_write_data = alu_result;
        end

        9'b0_111_01100: begin  // AND
            alu_control = ALU_AND;
            register_file_write_enable = 1'b1;
            register_file_write_destination = pd_rd;
            register_file_write_data = alu_result;
        end

        9'b0_110_01100: begin  // OR
            alu_control = ALU_OR;
            register_file_write_enable = 1'b1;
            register_file_write_destination = pd_rd;
            register_file_write_data = alu_result;
        end

        9'b0_100_01100: begin  // XOR
            alu_control = ALU_XOR;
            register_file_write_enable = 1'b1;
            register_file_write_destination = pd_rd;
            register_file_write_data = alu_result;
        end

        9'b0_001_01100: begin  // SLL
            alu_control = ALU_SLL;
            register_file_write_enable = 1'b1;
            register_file_write_destination = pd_rd;
            register_file_write_data = alu_result;
        end

        9'b0_101_01100: begin  // SRL
            alu_control = ALU_SRL;
            register_file_write_enable = 1'b1;
            register_file_write_destination = pd_rd;
            register_file_write_data = alu_result;
        end

        9'b1_101_01100: begin  // SRA
            alu_control = ALU_SRA;
            register_file_write_enable = 1'b1;
            register_file_write_destination = pd_rd;
            register_file_write_data = alu_result;
        end

        9'b0_010_01100: begin  // SLT
            alu_control = ALU_SLT;
            register_file_write_enable = 1'b1;
            register_file_write_destination = pd_rd;
            register_file_write_data = alu_result;
        end

        9'b0_011_01100: begin  // SLTU
            alu_control = ALU_SLTU;
            register_file_write_enable = 1'b1;
            register_file_write_destination = pd_rd;
            register_file_write_data = alu_result;
        end


        // ===================== I-type ALU (opcode[6:2]=00100) =====================
        9'b?_000_00100: begin  // ADDI
            alu_control = ALU_ADD;
            alu_b = pd_imm;          // imm_i
            register_file_write_enable = 1'b1;
            register_file_write_destination = pd_rd;
            register_file_write_data = alu_result;
        end

        9'b?_111_00100: begin  // ANDI
            alu_control = ALU_AND;
            alu_b = pd_imm;
            register_file_write_enable = 1'b1;
            register_file_write_destination = pd_rd;
            register_file_write_data = alu_result;
        end

        9'b?_110_00100: begin  // ORI
            alu_control = ALU_OR;
            alu_b = pd_imm;
            register_file_write_enable = 1'b1;
            register_file_write_destination = pd_rd;
            register_file_write_data = alu_result;
        end

        9'b?_100_00100: begin  // XORI
            alu_control = ALU_XOR;
            alu_b = pd_imm;
            register_file_write_enable = 1'b1;
            register_file_write_destination = pd_rd;
            register_file_write_data = alu_result;
        end

        9'b0_001_00100: begin  // SLLI (use shamt)
            alu_control = ALU_SLL;
            alu_b  = {27'd0, pd_shamt};
            register_file_write_enable = 1'b1;
            register_file_write_destination = pd_rd;
            register_file_write_data = alu_result;
        end

        9'b0_101_00100: begin  // SRLI (use shamt)
            alu_control = ALU_SRL;
            alu_b = {27'd0, pd_shamt};
            register_file_write_enable = 1'b1;
            register_file_write_destination = pd_rd;
            register_file_write_data = alu_result;
        end

        9'b1_101_00100: begin  // SRAI (use shamt)
            alu_control = ALU_SRA;
            alu_b = {27'd0, pd_shamt};
            register_file_write_enable = 1'b1;
            register_file_write_destination = pd_rd;
            register_file_write_data = alu_result;
        end

        9'b?_010_00100: begin  // SLTI
            alu_control = ALU_SLT;
            alu_b = pd_imm;
            register_file_write_enable = 1'b1;
            register_file_write_destination = pd_rd;
            register_file_write_data = alu_result;
        end

        9'b?_011_00100: begin  // SLTIU
            alu_control = ALU_SLTU;
            alu_b = pd_imm;
            register_file_write_enable = 1'b1;
            register_file_write_destination = pd_rd;
            register_file_write_data = alu_result;
        end


        // ===================== U-type =====================

        9'b???_01101: begin  // LUI: rd = imm_u
            alu_control = ALU_PASSB;   // pass B
            alu_a = 32'd0;
            alu_b = pd_imm;      // imm_u
            register_file_write_enable = 1'b1;
            register_file_write_destination = pd_rd;
            register_file_write_data = alu_result; // = imm_u
        end

        9'b???_00101: begin  // AUIPC: rd = PC + imm_u
            alu_control = ALU_ADD;
            alu_a = pd_pc;
            alu_b = pd_imm;      // imm_u
            register_file_write_enable = 1'b1;
            register_file_write_destination = pd_rd;
            register_file_write_data = alu_result; // = PC + imm_u
        end


        // ===================== Jumps / Branches =====================

        // pd3: not update PC for jumps yet
        9'b???_11011: begin  // JAL: rd = PC + 4, PC = PC + imm_j 
            alu_a = pd_pc;
            alu_b = pd_imm;
            alu_control = ALU_ADD; 
            register_file_write_enable = 1'b1;
            register_file_write_destination = pd_rd;
            register_file_write_data = pd_pc + 32'd4;
            // next_pc_local = pd_pc + pd_imm;
        end

        9'b???_11001: begin  // JALR: rd = PC + 4, PC = (rs1 + imm_i) & ~1 
            alu_b = pd_imm;
            alu_control = ALU_ADD; 
            register_file_write_enable = 1'b1;
            register_file_write_destination = pd_rd;
            register_file_write_data = pd_pc + 32'd4;
            // next_pc_local = (register_file_read_rs1_data + pd_imm) & ~32'd1;
        end

        // pd3: calculate branch taken but not update PC 
        9'b?_000_11000: begin  // BEQ: if equal, branch to PC + imm_b 
            pd_es_br_taken = (register_file_read_rs1_data == register_file_read_rs2_data);
            pd_es_alu_res = pd_pc + pd_imm; 
            // if (pd_es_br_taken) next_pc_local = pd_es_alu_res;
        end

        9'b?_001_11000: begin  // BNE
            pd_es_br_taken = (register_file_read_rs1_data != register_file_read_rs2_data);
            pd_es_alu_res = pd_pc + pd_imm; 
            // if (pd_es_br_taken) next_pc_local = pd_es_alu_res;
        end

        9'b?_100_11000: begin  // BLT
            pd_es_br_taken = ($signed(register_file_read_rs1_data) < $signed(register_file_read_rs2_data));
            pd_es_alu_res = pd_pc + pd_imm; 
            // if (pd_es_br_taken) next_pc_local = pd_es_alu_res;
        end

        9'b?_101_11000: begin  // BGE
            pd_es_br_taken = ($signed(register_file_read_rs1_data) >= $signed(register_file_read_rs2_data));
            pd_es_alu_res = pd_pc + pd_imm; 
            // if (pd_es_br_taken) next_pc_local = pd_es_alu_res;
        end

        9'b?_110_11000: begin  // BLTU
            pd_es_br_taken = (register_file_read_rs1_data < register_file_read_rs2_data);
            pd_es_alu_res = pd_pc + pd_imm; 
            // if (pd_es_br_taken) next_pc_local = pd_es_alu_res;
        end

        9'b?_111_11000: begin  // BGEU
            pd_es_br_taken = (register_file_read_rs1_data >= register_file_read_rs2_data);
            pd_es_alu_res = pd_pc + pd_imm; 
            // if (pd_es_br_taken) next_pc_local = pd_es_alu_res;
        end


        // ===================== LOAD (opcode[6:2]=00000) =====================

        9'b?_000_00000: begin  // LB
            alu_b = pd_imm;
            alu_control = ALU_ADD; 
            d_addr = ea;  
            d_we = 1'b0;
            register_file_write_enable = 1'b1;
            register_file_write_destination = pd_rd;
            case (ea[1:0])
                2'd0: register_file_write_data = {{24{d_rdata[7]}},  d_rdata[7:0]};
                2'd1: register_file_write_data = {{24{d_rdata[15]}}, d_rdata[15:8]};
                2'd2: register_file_write_data = {{24{d_rdata[23]}}, d_rdata[23:16]};
                2'd3: register_file_write_data = {{24{d_rdata[31]}}, d_rdata[31:24]};
            endcase
        end

        9'b?_100_00000: begin  // LBU
            alu_b = pd_imm;
            alu_control = ALU_ADD; 
            d_addr = ea;  
            d_we = 1'b0;
            register_file_write_enable = 1'b1;
            register_file_write_destination = pd_rd;
            case (ea[1:0])
                2'd0: register_file_write_data = {24'd0, d_rdata[7:0]};
                2'd1: register_file_write_data = {24'd0, d_rdata[15:8]};
                2'd2: register_file_write_data = {24'd0, d_rdata[23:16]};
                2'd3: register_file_write_data = {24'd0, d_rdata[31:24]};
            endcase
        end

        9'b?_010_00000: begin  // LW
            alu_b = pd_imm;
            alu_control = ALU_ADD; 
            d_addr = {ea[31:2], 2'b00};  // word-aligned
            d_we = 1'b0;  // read
            register_file_write_enable = 1'b1;
            register_file_write_destination = pd_rd;
            register_file_write_data = d_rdata;
        end

        9'b?_001_00000: begin  // LH
            alu_b = pd_imm;
            alu_control = ALU_ADD; 
            d_addr = {ea[31:1], 1'b0};  
            d_we = 1'b0;
            register_file_write_enable = 1'b1;
            register_file_write_destination = pd_rd;
            if (ea[1]==1'b0) register_file_write_data = {{16{d_rdata[15]}}, d_rdata[15:0]};
            else register_file_write_data = {{16{d_rdata[31]}}, d_rdata[31:16]};
        end

        9'b?_101_00000: begin  // LHU
            alu_b = pd_imm;
            alu_control = ALU_ADD; 
            d_addr = {ea[31:1], 1'b0}; 
            d_we = 1'b0;
            register_file_write_enable = 1'b1;
            register_file_write_destination = pd_rd;
            if (ea[1]==1'b0) register_file_write_data = {16'd0, d_rdata[15:0]};
            else register_file_write_data = {16'd0, d_rdata[31:16]};
        end


        // ===================== STORE (opcode[6:2]=01000) =====================

        9'b?_000_01000: begin  // SB (read-modify-write)
            alu_b = pd_imm;
            alu_control = ALU_ADD; 
            d_addr = {ea[31:2],2'b00};
            d_we = 1'b1;
            wmask = ~(32'hFF << (ea[1:0]*8));
            wshift = {24'b0, (register_file_read_rs2_data[7:0])} << (ea[1:0]*8);
            d_wdata = (d_rdata & wmask) | wshift;
        end

        9'b?_001_01000: begin  // SH (read-modify-write)
            alu_b = pd_imm;
            alu_control = ALU_ADD; 
            d_addr = {ea[31:2],2'b00};
            d_we = 1'b1;
            if (ea[1]==1'b0) begin
                wmask = 32'hFFFF0000;
                wshift = {16'd0, register_file_read_rs2_data[15:0]};
            end else begin
                wmask = 32'h0000FFFF;
                wshift = {register_file_read_rs2_data[15:0], 16'd0};
            end
            d_wdata= (d_rdata & wmask) | wshift;
        end

        9'b?_010_01000: begin  // SW
            alu_b = pd_imm;
            alu_control = ALU_ADD; 
            d_addr = {ea[31:2],2'b00};
            d_wdata = register_file_read_rs2_data;
            d_we = 1'b1;
            // no writeback for store
        end
        default: ;
    endcase
    // final PC assignment
    next_pc = next_pc_local;  // this will be pc_plus4 for all instructions in pd3
end

endmodule