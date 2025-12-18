module pd(
    input clock,
    input reset
);
    // ==================== Signal Declarations ====================
    // Core signals
    // Core PC and instruction signals
    reg [31:0]  imemory_pc;
    wire [31:0] imemory_insn;
    
    // Decoded instruction fields
    wire [31:0]  pd_pc;
    reg [6:0]   pd_opcode;
    reg [4:0]   pd_rd;
    reg [2:0]   pd_funct3;
    reg [4:0]   pd_rs1;
    reg [4:0]   pd_rs2;
    reg [6:0]   pd_funct7;
    reg [31:0]  pd_imm;
    reg [4:0]   pd_shamt;
    
    // Execute stage signals
    reg [31:0] es_pc;
    reg [31:0] es_alu_res;
    reg        es_br_taken;
    
    // Register file signals
    reg         rf_write_enable;
    reg [4:0]   rf_write_dest;
    reg [31:0]  rf_write_data;
    wire [4:0]  rf_read_rs1;
    wire [4:0]  rf_read_rs2;
    wire [31:0] rf_read_rs1_data;
    wire [31:0] rf_read_rs2_data;

    // Memory interface signals
    reg [31:0] mem_addr;
    reg [31:0] mem_wdata;
    reg [1:0]  mem_access_size;
    reg        mem_we;
    wire [31:0] mem_rdata;

    // ==================== Fetch Stage ====================
    // PC and instruction fetch logic
    initial begin
        imemory_pc = 32'h0100_0000;
    end

    wire [31:0] pc_plus4 = imemory_pc + 32'd4;
    reg [31:0] next_pc;

    always @(posedge clock) begin
        if(reset) begin
            imemory_pc <= 32'h0100_0000;
        end
        else begin
            imemory_pc <= next_pc;
        end
    end

    imemory imemory_0 (
        .clock(clock),
        .address(imemory_pc),
        .data_in(32'b0),
        .read_write(1'b0),
        .data_out(imemory_insn)
    );

    // ==================== Decode Stage ====================
    assign pd_pc = imemory_pc;
    // Instruction field decode
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
                end 
                else begin
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

    // Register file read
    assign rf_read_rs1 = pd_rs1;
    assign rf_read_rs2 = pd_rs2;

    register_file register_file_0 (
        .clock(clock),
        .write_enable(rf_write_enable),
        .addr_rs1(rf_read_rs1),
        .addr_rs2(rf_read_rs2),
        .addr_rd(rf_write_dest),
        .data_rd(rf_write_data),
        .data_rs1(rf_read_rs1_data),
        .data_rs2(rf_read_rs2_data)
    );

    // ==================== Execute Stage ====================
    // ALU control and operation
    wire [8:0] instruction_type_code = {imemory_insn[30], imemory_insn[14:12], imemory_insn[6:2]};  // get instruction type code (9 bits)

    // ALU definition
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
        // ALU operation
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

    // ==================== Memory Stage ====================
    dmemory dmemory_0 (
        .clock(clock),
        .address(mem_addr),
        .data_in(mem_wdata),
        .write_enable(mem_we),
        .data_out(mem_rdata),
        .access_size(mem_access_size)
    );

    // ==================== Write Back Stage ====================
    // Combined execute/memory/writeback control
    always @* begin
        // Default values
        es_pc = pd_pc;
        es_alu_res = alu_result;
        es_br_taken = 1'b0;

        // Memory access signals
        mem_addr  = 32'd0;
        mem_we    = 1'b0;
        mem_wdata = 32'd0;
        mem_access_size = 2'd0;
        
        // Write back signals
        alu_a = rf_read_rs1_data;
        alu_b = rf_read_rs2_data;
        alu_control = ALU_ADD;
        rf_write_dest = 5'd0;
        rf_write_enable = 1'b0;
        rf_write_data = alu_result;
        next_pc = pc_plus4;

        casez (instruction_type_code)
            9'b0_000_01100: begin  // ADD
                alu_control = ALU_ADD;
                rf_write_enable = 1'b1;
                rf_write_dest = pd_rd;
                rf_write_data = alu_result;
            end

            9'b1_000_01100: begin  // SUB
                alu_control = ALU_SUB;
                rf_write_enable = 1'b1;
                rf_write_dest = pd_rd;
                rf_write_data = alu_result;
            end

            9'b0_111_01100: begin  // AND
                alu_control = ALU_AND;
                rf_write_enable = 1'b1;
                rf_write_dest = pd_rd;
                rf_write_data = alu_result;
            end

            9'b0_110_01100: begin  // OR
                alu_control = ALU_OR;
                rf_write_enable = 1'b1;
                rf_write_dest = pd_rd;
                rf_write_data = alu_result;
            end

            9'b0_100_01100: begin  // XOR
                alu_control = ALU_XOR;
                rf_write_enable = 1'b1;
                rf_write_dest = pd_rd;
                rf_write_data = alu_result;
            end

            9'b0_001_01100: begin  // SLL
                alu_control = ALU_SLL;
                rf_write_enable = 1'b1;
                rf_write_dest = pd_rd;
                rf_write_data = alu_result;
            end

            9'b0_101_01100: begin  // SRL
                alu_control = ALU_SRL;
                rf_write_enable = 1'b1;
                rf_write_dest = pd_rd;
                rf_write_data = alu_result;
            end

            9'b1_101_01100: begin  // SRA
                alu_control = ALU_SRA;
                rf_write_enable = 1'b1;
                rf_write_dest = pd_rd;
                rf_write_data = alu_result;
            end

            9'b0_010_01100: begin  // SLT
                alu_control = ALU_SLT;
                rf_write_enable = 1'b1;
                rf_write_dest = pd_rd;
                rf_write_data = alu_result;
            end

            9'b0_011_01100: begin  // SLTU
                alu_control = ALU_SLTU;
                rf_write_enable = 1'b1;
                rf_write_dest = pd_rd;
                rf_write_data = alu_result;
            end


            // ===================== I-type ALU (opcode[6:2]=00100) =====================
            9'b?_000_00100: begin  // ADDI
                alu_control = ALU_ADD;
                alu_b = pd_imm;          // imm_i
                rf_write_enable = 1'b1;
                rf_write_dest = pd_rd;
                rf_write_data = alu_result;
            end

            9'b?_111_00100: begin  // ANDI
                alu_control = ALU_AND;
                alu_b = pd_imm;
                rf_write_enable = 1'b1;
                rf_write_dest = pd_rd;
                rf_write_data = alu_result;
            end

            9'b?_110_00100: begin  // ORI
                alu_control = ALU_OR;
                alu_b = pd_imm;
                rf_write_enable = 1'b1;
                rf_write_dest = pd_rd;
                rf_write_data = alu_result;
            end

            9'b?_100_00100: begin  // XORI
                alu_control = ALU_XOR;
                alu_b = pd_imm;
                rf_write_enable = 1'b1;
                rf_write_dest = pd_rd;
                rf_write_data = alu_result;
            end

            9'b0_001_00100: begin  // SLLI (use shamt)
                alu_control = ALU_SLL;
                alu_b  = {27'd0, pd_shamt};
                rf_write_enable = 1'b1;
                rf_write_dest = pd_rd;
                rf_write_data = alu_result;
            end

            9'b0_101_00100: begin  // SRLI (use shamt)
                alu_control = ALU_SRL;
                alu_b = {27'd0, pd_shamt};
                rf_write_enable = 1'b1;
                rf_write_dest = pd_rd;
                rf_write_data = alu_result;
            end

            9'b1_101_00100: begin  // SRAI (use shamt)
                alu_control = ALU_SRA;
                alu_b = {27'd0, pd_shamt};
                rf_write_enable = 1'b1;
                rf_write_dest = pd_rd;
                rf_write_data = alu_result;
            end

            9'b?_010_00100: begin  // SLTI
                alu_control = ALU_SLT;
                alu_b = pd_imm;
                rf_write_enable = 1'b1;
                rf_write_dest = pd_rd;
                rf_write_data = alu_result;
            end

            9'b?_011_00100: begin  // SLTIU
                alu_control = ALU_SLTU;
                alu_b = pd_imm;
                rf_write_enable = 1'b1;
                rf_write_dest = pd_rd;
                rf_write_data = alu_result;
            end


            // ===================== U-type =====================
            9'b???_01101: begin  // LUI: rd = imm_u
                alu_control = ALU_PASSB;   // pass B
                // alu_a = 32'd0;
                alu_b = pd_imm;      // imm_u
                rf_write_enable = 1'b1;
                rf_write_dest = pd_rd;
                rf_write_data = alu_result; // = imm_u
            end

            9'b???_00101: begin  // AUIPC: rd = PC + imm_u
                alu_control = ALU_ADD;
                alu_a = pd_pc;
                alu_b = pd_imm;      // imm_u
                rf_write_enable = 1'b1;
                rf_write_dest = pd_rd;
                rf_write_data = alu_result; // = PC + imm_u
            end


            // ===================== Jumps / Branches =====================
            9'b???_11011: begin  // JAL: rd = PC + 4, PC = PC + imm_j 
                alu_a = pd_pc;
                alu_b = pd_imm;
                alu_control = ALU_ADD; 
                rf_write_enable = 1'b1;
                rf_write_dest = pd_rd;
                rf_write_data = pc_plus4;
                next_pc = alu_result;
            end

            9'b???_11001: begin  // JALR: rd = PC + 4, PC = (rs1 + imm_i) & ~1 
                alu_b = pd_imm;
                alu_control = ALU_ADD; 
                rf_write_enable = 1'b1;
                rf_write_dest = pd_rd;
                rf_write_data = pc_plus4;
                next_pc = (alu_result) & ~32'd1;
            end

            9'b?_000_11000: begin  // BEQ: if equal, branch to PC + imm_b 
                alu_a = pd_pc;
                alu_b = pd_imm;
                alu_control = ALU_ADD; 
                es_br_taken = (rf_read_rs1_data == rf_read_rs2_data);
                next_pc = (es_br_taken)? alu_result : pc_plus4;
            end

            9'b?_001_11000: begin  // BNE
                alu_a = pd_pc;
                alu_b = pd_imm;
                alu_control = ALU_ADD; 
                es_br_taken = (rf_read_rs1_data != rf_read_rs2_data);
                next_pc = (es_br_taken)? alu_result : pc_plus4;
            end

            9'b?_100_11000: begin  // BLT
                alu_a = pd_pc;
                alu_b = pd_imm;
                alu_control = ALU_ADD; 
                es_br_taken = ($signed(rf_read_rs1_data) < $signed(rf_read_rs2_data));
                next_pc = (es_br_taken)? alu_result : pc_plus4;
            end

            9'b?_101_11000: begin  // BGE
                alu_a = pd_pc;
                alu_b = pd_imm;
                alu_control = ALU_ADD; 
                es_br_taken = ($signed(rf_read_rs1_data) >= $signed(rf_read_rs2_data));
                next_pc = (es_br_taken)? alu_result : pc_plus4;
            end

            9'b?_110_11000: begin  // BLTU
                alu_a = pd_pc;
                alu_b = pd_imm;
                alu_control = ALU_ADD; 
                es_br_taken = (rf_read_rs1_data < rf_read_rs2_data);
                next_pc = (es_br_taken)? alu_result : pc_plus4;
            end

            9'b?_111_11000: begin  // BGEU
                alu_a = pd_pc;
                alu_b = pd_imm;
                alu_control = ALU_ADD; 
                es_br_taken = (rf_read_rs1_data >= rf_read_rs2_data);
                next_pc = (es_br_taken)? alu_result : pc_plus4;
            end


            // ===================== LOAD (opcode[6:2]=00000) =====================
            9'b?_000_00000: begin  // LB
                alu_b = pd_imm;
                alu_control = ALU_ADD; 
                mem_addr = alu_result;  
                mem_we = 1'b0;
                mem_access_size = 2'b00;  // byte access
                rf_write_enable = 1'b1;
                rf_write_dest = pd_rd;
                rf_write_data = {{24{mem_rdata[7]}}, mem_rdata[7:0]};
            end

            9'b?_100_00000: begin  // LBU
                alu_b = pd_imm;
                alu_control = ALU_ADD; 
                mem_addr = alu_result;  
                mem_we = 1'b0;
                rf_write_enable = 1'b1;
                rf_write_dest = pd_rd;
                rf_write_data = {24'd0, mem_rdata[7:0]};
            end

            9'b?_010_00000: begin  // LW
                alu_b = pd_imm;
                alu_control = ALU_ADD; 
                mem_addr = alu_result;  // word-aligned
                mem_we = 1'b0;  // read
                rf_write_enable = 1'b1;
                rf_write_dest = pd_rd;
                rf_write_data = mem_rdata;
            end

            9'b?_001_00000: begin  // LH
                alu_b = pd_imm;
                alu_control = ALU_ADD; 
                mem_addr = alu_result;  
                mem_we = 1'b0;
                rf_write_enable = 1'b1;
                rf_write_dest = pd_rd;
                rf_write_data = {{16{mem_rdata[15]}}, mem_rdata[15:0]};
            end

            9'b?_101_00000: begin  // LHU
                alu_b = pd_imm;
                alu_control = ALU_ADD; 
                mem_addr = alu_result;
                mem_we = 1'b0;
                rf_write_enable = 1'b1;
                rf_write_dest = pd_rd;
                rf_write_data = {16'd0, mem_rdata[15:0]};
            end


            // ===================== STORE (opcode[6:2]=01000) =====================
            9'b?_000_01000: begin  // SB
                alu_b = pd_imm;
                alu_control = ALU_ADD; 
                mem_addr = alu_result;
                mem_wdata = rf_read_rs2_data;
                mem_we = 1'b1;
                mem_access_size = 2'b00;
            end

            9'b?_001_01000: begin  // SH
                alu_b = pd_imm;
                alu_control = ALU_ADD; 
                mem_addr = alu_result;
                mem_wdata = rf_read_rs2_data;
                mem_we = 1'b1;
                mem_access_size = 2'b01;
            end

            9'b?_010_01000: begin  // SW
                alu_b = pd_imm;
                alu_control = ALU_ADD; 
                mem_addr = alu_result;
                mem_wdata = rf_read_rs2_data;
                mem_we = 1'b1;
                mem_access_size = 2'b10;
            end

            default: ;
        endcase
    end

endmodule