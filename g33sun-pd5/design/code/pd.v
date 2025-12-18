
module pd(
    input clock,
    input reset
);
    // ==================== Signal Declarations ====================
    // Fetch Stage Signals
    reg [31:0]  if_pc;
    wire [31:0] if_insn;
    wire [31:0] if_pc_plus4 =  if_pc + 32'd4;
    reg [31:0]  if_next_pc;

    // IF/ID pipeline register
    reg [31:0] if_id_insn;
    reg [31:0] if_id_pc;
    

    // Decode Stage Signals (combinational from IF/ID)
    wire [31:0] id_pc;
    wire [31:0] id_insn;
    // decoded fields (combinational)
    reg [6:0]   id_opcode;
    reg [4:0]   id_rd;
    reg [2:0]   id_funct3;
    reg [4:0]   id_rs1;
    reg [4:0]   id_rs2;
    reg [6:0]   id_funct7;
    reg [31:0]  id_imm;
    reg [4:0]   id_shamt;
    
    // Register File Signals
    wire        wb_rf_we;
    wire [4:0]  wb_rf_rd;
    wire [31:0] wb_rf_data;
    wire [4:0]  id_rf_rs1;
    wire [4:0]  id_rf_rs2;
    wire [31:0] id_rf_rs1_data;
    wire [31:0] id_rf_rs2_data;

    // ID/EX pipeline registers
    reg [31:0] id_ex_pc;
    reg [31:0] id_ex_rs1_data;
    reg [31:0] id_ex_rs2_data;
    reg [4:0]  id_ex_rs1;
    reg [4:0]  id_ex_rs2;
    reg [31:0] id_ex_imm;
    reg [4:0]  id_ex_rd;
    reg [4:0]  id_ex_shamt;
    reg [31:0] id_ex_insn;
    

    // Execute Stage Signals
    reg [31:0] ex_alu_a;
    reg [31:0] ex_alu_b;
    reg [3:0]  ex_alu_control;
    reg [31:0] ex_alu_result_wire;  // <== [pd5] changed to reg since it is used in always
    reg        ex_br_taken;
    // EX/MEM pipeline registers
    reg [31:0] ex_mem_alu_result;
    reg [31:0] ex_mem_mem_wdata;
    reg [1:0]  ex_mem_access_size;
    reg        ex_mem_we;
    reg [4:0]  ex_mem_rd;
    reg [4:0]  ex_mem_rs2; // for WM forwarding
    reg [8:0]  ex_mem_insn_type;
    reg [31:0] ex_mem_pc;
    reg [31:0] ex_mem_wb_value;       // value ready in EX for WB / forwarding
    reg        ex_mem_wb_value_valid; // whether WB value is ready in EX
    
    // Memory Stage Signals
    reg [31:0] mem_addr;
    reg [31:0] mem_wdata;
    reg [1:0]  mem_access_size;
    reg        mem_we;
    wire [31:0] mem_rdata;
    // MEM/WB pipeline registers
    reg [31:0] mem_wb_data;
    reg [4:0]  mem_wb_rd;
    reg [31:0] mem_wb_pc;
    reg        mem_wb_we;
    
    // pipeline control signal
    reg stall_F, stall_D;   // stall state F and D
    reg flush_D, flush_E;   // flush state D and E
    localparam [31:0] NOP = 32'h0000_0013;  // addi x0, x0, 0  => x[rd] = x[rs1] + imm 
                                           // => imm[11:0] = 0000_0000_0000 | rs1(5 bits) = 0_0000 | funct3(3 bits) = 000 | rd(5 bits) = 0_0000 | opcode(7 bits) = 001_0011
    
    
    
    
    // ==================== Fetch Stage ====================
    initial begin
        if_pc = 32'h0100_0000;
        if_next_pc = 32'h0100_0004;

        if_id_pc = 32'h0000_0000;
        id_opcode = 7'b000_0000;
        id_rd = 5'b0_0000;
        id_funct3 = 3'b000;
        id_rs1 = 5'b0_0000;
        id_rs2 = 5'b0_0000;
        id_funct7 = 7'b000_0000;
        id_imm = 32'h0000_0000;
        id_shamt = 5'b0_0000;

        mem_wb_data = 32'h0000_0000;
    end
    
    always @(posedge clock) begin
        if(reset) begin
            if_pc <= 32'h0100_0000;
        end else if (stall_F) begin     
            if_pc <= if_pc;         // <== [pd5] hold pc for stall
        end else begin
            if_pc <= if_next_pc;    // included branch taken
        end
    end
    imemory imemory_0 (
        .clock(clock),
        .address(if_pc),
        .data_in(32'b0),
        .read_write(1'b0),
        .data_out(if_insn)
    );
    // IF/ID pipeline register update
    always @(posedge clock) begin
        if (reset) begin
            // if_id_insn <= 32'h0000_0000; 
            // [11/15] changed
            if_id_insn <= NOP;
            if_id_pc <= 32'h0000_0000;
        end else if(flush_D) begin
            if_id_insn <= NOP;  // <== [pd5] flush, insn == addi x0, x0, 0 => do nothing
            if_id_pc <= if_pc;
        end else if (!stall_D) begin    // stall happend in fetch state pc control
            if_id_insn <= if_insn;
            if_id_pc <= if_pc;
        end
    end




    // ==================== Decode Stage ====================
    assign id_pc = if_id_pc;
    assign id_insn = if_id_insn;
    
    // Instruction field decode (combinational, from id_insn)
    always @* begin
        // default values
        id_opcode = id_insn[6:0];
        id_rd     = 5'd0;
        id_funct3 = 3'd0;
        id_rs1    = 5'd0;
        id_rs2    = 5'd0;
        id_funct7 = 7'd0;
        id_imm    = 32'd0;
        id_shamt  = 5'd0;
        case (id_opcode)
            7'b0110011: begin // R type
                id_rd     = id_insn[11:7];
                id_funct3 = id_insn[14:12];
                id_rs1    = id_insn[19:15];
                id_rs2    = id_insn[24:20];
                id_funct7 = id_insn[31:25];
            end
            7'b0010011: begin // I type 
                id_rd     = id_insn[11:7];
                id_funct3 = id_insn[14:12];
                id_rs1    = id_insn[19:15];
                if (id_funct3 == 3'b001 || id_funct3 == 3'b101) begin
                    id_shamt  = id_insn[24:20];
                    id_funct7 = id_insn[31:25]; // SRLI/SRAI
                end 
                else begin
                    id_imm = {{20{id_insn[31]}}, id_insn[31:20]}; // immediate
                end
            end
            7'b0000011: begin // I type - load
                id_rd     = id_insn[11:7];
                id_funct3 = id_insn[14:12];
                id_rs1    = id_insn[19:15];
                id_imm    = {{20{id_insn[31]}}, id_insn[31:20]};
            end
            7'b0100011: begin // S type
                id_funct3 = id_insn[14:12];
                id_rs1    = id_insn[19:15];
                id_rs2    = id_insn[24:20];
                id_imm    = {{20{id_insn[31]}}, id_insn[31:25], id_insn[11:7]};
            end
            7'b1100011: begin // B type
                id_funct3 = id_insn[14:12];
                id_rs1    = id_insn[19:15];
                id_rs2    = id_insn[24:20];
                id_imm    = {{19{id_insn[31]}}, id_insn[31], id_insn[7],
                            id_insn[30:25], id_insn[11:8], 1'b0};
            end
            7'b1101111: begin // J type - JAL
                id_rd  = id_insn[11:7];
                id_imm = {{12{id_insn[31]}}, id_insn[19:12],
                            id_insn[20], id_insn[30:21], 1'b0};
            end
            7'b1100111: begin // J type - JALR
                id_rd     = id_insn[11:7];
                id_funct3 = id_insn[14:12]; 
                id_rs1    = id_insn[19:15];
                id_imm    = {{20{id_insn[31]}}, id_insn[31:20]};
            end
            7'b0110111, 7'b0010111: begin // U type - LUI & AUIPC
                id_rd  = id_insn[11:7];
                id_imm = {id_insn[31:12], 12'b0};
            end
            default: begin
                // do nothing, all default values
            end
        endcase
    end
    
    // Register file interface (addresses driven by decode)
    assign id_rf_rs1 = id_rs1;
    assign id_rf_rs2 = id_rs2;
    register_file register_file_0 (
        .clock(clock),
        .write_enable(wb_rf_we),
        .addr_rs1(id_rf_rs1),
        .addr_rs2(id_rf_rs2),
        .addr_rd(wb_rf_rd),
        .data_rd(wb_rf_data),
        .data_rs1(id_rf_rs1_data),
        .data_rs2(id_rf_rs2_data)
    );
    
    // ID/EX pipeline register: latch decoded fields and register values
    always @(posedge clock) begin
        if (reset) begin
            id_ex_pc <= 32'd0;
            id_ex_rs1_data <= 32'd0;
            id_ex_rs2_data <= 32'd0;
            id_ex_rs1 <= 5'd0; // <--- add
            id_ex_rs2 <= 5'd0; // <--- add
            id_ex_imm <= 32'd0;
            id_ex_rd <= 5'd0;
            id_ex_shamt <= 5'd0;
            // id_ex_insn <= 32'd0;
            // [11/15] changed
            id_ex_insn <= NOP;
        end else if (flush_E || pipeline_stall) begin
            id_ex_pc <= id_pc;
            id_ex_rs1_data <= 32'd0;
            id_ex_rs2_data <= 32'd0;
            id_ex_rs1 <= 5'd0; // <--- add
            id_ex_rs2 <= 5'd0; // <--- add
            id_ex_imm <= 32'd0;
            id_ex_rd <= 5'd0;
            id_ex_shamt <= 5'd0;
            id_ex_insn <= NOP;  // <== DE add NOP
        end else begin
            id_ex_pc <= id_pc;
            id_ex_rs1_data <= id_rf_rs1_data;
            id_ex_rs2_data <= id_rf_rs2_data;
            id_ex_rs1 <= id_rs1; // <--- add
            id_ex_rs2 <= id_rs2; // <--- add
            id_ex_imm <= id_imm;
            id_ex_rd <= id_rd;
            id_ex_shamt <= id_shamt;
            id_ex_insn <= id_insn;
        end
    end
    
    // --------------- Hazard Detection -----------------
    // EX stage load-use hazard (needs one bubble so data reaches MEM/WB)
    wire id_ex_is_load  = (id_ex_insn[6:2] == 5'b00000);  // load

    // Consumers that need rs1/rs2 in EX
    wire id_is_branch = (id_insn[6:2] == 5'b11000);  // B-type
    wire id_is_jalr   = (id_insn[6:2] == 5'b11001);  // JALR
    wire id_is_store  = (id_insn[6:2] == 5'b01000);  // S-type
    wire id_is_load   = (id_insn[6:2] == 5'b00000);  // I-type load uses rs1 as base
    wire id_is_r_alu  = (id_insn[6:2] == 5'b01100);  // R-type ALU
    wire id_is_i_alu  = (id_insn[6:2] == 5'b00100);  // I-type ALU imm
    wire id_uses_rs1_in_EX = id_is_branch || id_is_jalr || id_is_store || id_is_load || id_is_r_alu || id_is_i_alu;
    wire id_uses_rs2_in_EX = id_is_r_alu || id_is_branch; // store rs2 handled separately via WM
    
    wire load_use_hazard =
        id_ex_is_load && (id_ex_rd != 5'd0) &&
        ((id_uses_rs1_in_EX && (id_ex_rd == id_rs1)) ||
         (id_uses_rs2_in_EX && (id_ex_rd == id_rs2)));
    
    // WB stage is committing this cycle; hold decode one cycle so rd write completes (covers producer in W, consumer in D)
    wire wb_data_hazard =
        (mem_wb_we && (mem_wb_rd != 5'd0)) &&
        ((id_uses_rs1_in_EX && (mem_wb_rd == id_rs1)) ||
         (id_uses_rs2_in_EX && (mem_wb_rd == id_rs2)) ||
         ((mem_wb_rd == id_rs2) && id_is_store));

    wire pipeline_stall = load_use_hazard || wb_data_hazard;

    always @* begin
        // Branch redirect has higher priority than pipeline stall so PC can jump
        stall_F = pipeline_stall && !ex_br_taken;
        stall_D = pipeline_stall && !ex_br_taken;

        flush_D = ex_br_taken;
        flush_E = ex_br_taken;
    end


    // ==================== Execute Stage ====================
    wire [8:0] ex_insn_type = {id_ex_insn[30], id_ex_insn[14:12], id_ex_insn[6:2]};
    wire ex_is_r_type = (id_ex_insn[6:2] == 5'b01100);
    wire ex_is_i_alu  = (id_ex_insn[6:2] == 5'b00100);
    wire ex_is_lui    = (id_ex_insn[6:2] == 5'b01101);
    wire ex_is_auipc  = (id_ex_insn[6:2] == 5'b00101);
    wire ex_is_jal    = (id_ex_insn[6:2] == 5'b11011);
    wire ex_is_jalr   = (id_ex_insn[6:2] == 5'b11001);
    wire ex_is_branch = (id_ex_insn[6:2] == 5'b11000);
    wire ex_is_load   = (id_ex_insn[6:2] == 5'b00000);
    wire ex_is_store  = (id_ex_insn[6:2] == 5'b01000);
    wire ex_uses_rs1_forward =
        ex_is_branch || ex_is_load || ex_is_store || ex_is_i_alu || ex_is_r_type || ex_is_jalr;
    wire ex_uses_rs2_forward =
        ex_is_branch || ex_is_r_type || ex_is_store;
    localparam ALU_ADD = 4'b0000, ALU_SUB = 4'b0001,
               ALU_AND = 4'b0010, ALU_OR = 4'b0011,
               ALU_XOR = 4'b0100, ALU_SLL = 4'b0101, 
               ALU_SRL = 4'b0110, ALU_SRA = 4'b0111,
               ALU_SLT = 4'b1000, ALU_SLTU = 4'b1001,
               ALU_PASSB = 4'b1010;
    
    // Forwarding detection (MX stage: EX/MEM -> EX)
    wire ex_mem_can_forward = ex_mem_wb_value_valid;
    wire mx_forward_rs1 =
        (id_ex_rs1 == ex_mem_rd) &&
        (ex_mem_can_forward) && 
        (ex_mem_rd != 5'd0) &&
        ex_uses_rs1_forward;

    wire mx_forward_rs2 =
        (id_ex_rs2 == ex_mem_rd) &&
        (ex_mem_can_forward) && 
        (ex_mem_rd != 5'd0) &&
        ex_uses_rs2_forward;

    // Forwarding detection (WX stage: MEM/WB -> EX)
    wire wx_forward_rs1 =
        (id_ex_rs1 == mem_wb_rd) &&
        (mem_wb_rd != 5'd0) &&
        (mem_wb_we == 1'b1) &&
        !mx_forward_rs1 && // MX forwarding has higher priority
        ex_uses_rs1_forward;

    wire wx_forward_rs2 =
        (id_ex_rs2 == mem_wb_rd) &&
        (mem_wb_rd != 5'd0) &&
        (mem_wb_we == 1'b1) &&
        !mx_forward_rs2 && // MX forwarding has higher priority
        ex_uses_rs2_forward;
    
    // Forwarding detection (WM stage: MEM/WB -> MEM)
    // for Store(rs2) forwarding
    wire wm_forward_rs2 =
        (ex_mem_rs2 == mem_wb_rd) &&
        (mem_wb_rd != 5'd0) &&
        (mem_wb_we == 1'b1) &&
        (ex_mem_insn_type[4:0] == 5'b01000); // S-type
    
    wire [31:0] ex_pc_plus4 = id_ex_pc + 32'd4;
    wire [31:0] ex_forward_rs1 = mx_forward_rs1 ? ex_mem_wb_value :
                                 (wx_forward_rs1 ? mem_wb_data : id_ex_rs1_data);
    wire [31:0] ex_forward_rs2 = mx_forward_rs2 ? ex_mem_wb_value :
                                 (wx_forward_rs2 ? mem_wb_data : id_ex_rs2_data);

    // Default ALU input selection and control (combinational)
    always @* begin
        // defaults
        ex_alu_a = ex_forward_rs1;
        ex_alu_b = ex_forward_rs2;
        ex_alu_control = ALU_ADD;
        ex_br_taken = 1'b0;
        
        // case to decide ALU input
        casez (ex_insn_type)
            9'b0_000_01100: begin  // ADD
                ex_alu_control = ALU_ADD;
            end
            9'b1_000_01100: begin  // SUB
                ex_alu_control = ALU_SUB;
            end
            9'b0_111_01100: begin  // AND
                ex_alu_control = ALU_AND;
            end
            9'b0_110_01100: begin  // OR
                ex_alu_control = ALU_OR;
            end
            9'b0_100_01100: begin  // XOR
                ex_alu_control = ALU_XOR;
            end
            9'b0_001_01100: begin  // SLL
                ex_alu_control = ALU_SLL;
            end
            9'b0_101_01100: begin  // SRL
                ex_alu_control = ALU_SRL;
            end
            9'b1_101_01100: begin  // SRA
                ex_alu_control = ALU_SRA;
            end
            9'b0_010_01100: begin  // SLT
                ex_alu_control = ALU_SLT;
            end
            9'b0_011_01100: begin  // SLTU
                ex_alu_control = ALU_SLTU;
            end
            // I-type ALU immediate uses id_ex_imm
            9'b?_000_00100: begin  // ADDI
                ex_alu_control = ALU_ADD;
                ex_alu_b = id_ex_imm;
            end
            9'b?_111_00100: begin  // ANDI
                ex_alu_control = ALU_AND;
                ex_alu_b = id_ex_imm;
            end
            9'b?_110_00100: begin  // ORI
                ex_alu_control = ALU_OR;
                ex_alu_b = id_ex_imm;
            end
            9'b?_100_00100: begin  // XORI
                ex_alu_control = ALU_XOR;
                ex_alu_b = id_ex_imm;
            end
            9'b0_001_00100: begin  // SLLI
                ex_alu_control = ALU_SLL;
                ex_alu_b = {27'd0, id_ex_shamt};
            end
            9'b0_101_00100: begin  // SRLI
                ex_alu_control = ALU_SRL;
                ex_alu_b = {27'd0, id_ex_shamt};
            end
            9'b1_101_00100: begin  // SRAI
                ex_alu_control = ALU_SRA;
                ex_alu_b = {27'd0, id_ex_shamt};
            end
            9'b?_010_00100: begin  // SLTI
                ex_alu_control = ALU_SLT;
                ex_alu_b = id_ex_imm;
            end
            9'b?_011_00100: begin  // SLTIU
                ex_alu_control = ALU_SLTU;
                ex_alu_b = id_ex_imm;
            end
            // U-type
            9'b???_01101: begin // LUI
                ex_alu_control = ALU_PASSB;
                ex_alu_b = id_ex_imm;
            end
            9'b???_00101: begin // AUIPC
                ex_alu_control = ALU_ADD;
                ex_alu_a = id_ex_pc;
                ex_alu_b = id_ex_imm;
            end
            // Jumps:
            9'b???_11011: begin // JAL
                ex_alu_control = ALU_ADD;
                ex_alu_a = id_ex_pc;
                ex_alu_b = id_ex_imm;
                ex_br_taken = 1'b1;
            end
            9'b???_11001: begin // JALR
                ex_alu_control = ALU_ADD;
                ex_alu_b = id_ex_imm;
                ex_br_taken = 1'b1;
            end
            // Loads: use rs1 + imm
            9'b?_000_00000, 9'b?_100_00000, 9'b?_010_00000, 9'b?_001_00000, 9'b?_101_00000: begin
                ex_alu_control = ALU_ADD;
                ex_alu_b = id_ex_imm;
            end
            // Stores: rs1 + imm
            9'b?_000_01000, 9'b?_001_01000, 9'b?_010_01000: begin
                ex_alu_control = ALU_ADD;
                ex_alu_b = id_ex_imm;
            end
            // Branches: determine taken based on register values (no forwarding implemented)
            9'b?_000_11000: begin  // BEQ
                ex_alu_control = ALU_ADD;
                ex_alu_a = id_ex_pc;
                ex_alu_b = id_ex_imm;
                ex_br_taken = (
                    (ex_forward_rs1 ==
                    ex_forward_rs2)
                );
            end
            9'b?_001_11000: begin  // BNE
                ex_alu_control = ALU_ADD;
                ex_alu_a = id_ex_pc;
                ex_alu_b = id_ex_imm;
                ex_br_taken = (
                    (ex_forward_rs1 !=
                    ex_forward_rs2)
                );
            end
            9'b?_100_11000: begin  // BLT
                ex_alu_control = ALU_ADD;
                ex_alu_a = id_ex_pc;
                ex_alu_b = id_ex_imm;
                ex_br_taken = (
                    $signed(ex_forward_rs1) <
                    $signed(ex_forward_rs2)
                );
            end
            9'b?_101_11000: begin  // BGE
                ex_alu_control = ALU_ADD;
                ex_alu_a = id_ex_pc;
                ex_alu_b = id_ex_imm;
                ex_br_taken = (
                    $signed(ex_forward_rs1) >=
                    $signed(ex_forward_rs2)
                );
            end
            9'b?_110_11000: begin  // BLTU
                ex_alu_control = ALU_ADD;
                ex_alu_a = id_ex_pc;
                ex_alu_b = id_ex_imm;
                ex_br_taken = (
                    (ex_forward_rs1 <
                    ex_forward_rs2)
                );
            end
            9'b?_111_11000: begin  // BGEU
                ex_alu_control = ALU_ADD;
                ex_alu_a = id_ex_pc;
                ex_alu_b = id_ex_imm;
                ex_br_taken = (
                    (ex_forward_rs1 >=
                    ex_forward_rs2)
                );
            end
            default: begin
                ex_alu_control = ALU_ADD;
            end
        endcase
    end

    // ALU compute (combinational)
    always @* begin
        case (ex_alu_control)
            ALU_ADD : ex_alu_result_wire = ex_alu_a + ex_alu_b;
            ALU_SUB : ex_alu_result_wire = ex_alu_a - ex_alu_b;
            ALU_AND : ex_alu_result_wire = ex_alu_a & ex_alu_b;
            ALU_OR  : ex_alu_result_wire = ex_alu_a | ex_alu_b;
            ALU_XOR : ex_alu_result_wire = ex_alu_a ^ ex_alu_b;
            ALU_SLL : ex_alu_result_wire = ex_alu_a << ex_alu_b[4:0];
            ALU_SRL : ex_alu_result_wire = ex_alu_a >> ex_alu_b[4:0];
            ALU_SRA : ex_alu_result_wire = $signed(ex_alu_a) >>> ex_alu_b[4:0];
            ALU_SLT : ex_alu_result_wire = ($signed(ex_alu_a) <  $signed(ex_alu_b)) ? 32'd1 : 32'd0;
            ALU_SLTU: ex_alu_result_wire = (ex_alu_a < ex_alu_b) ? 32'd1 : 32'd0;
            ALU_PASSB: ex_alu_result_wire = ex_alu_b;
            default : ex_alu_result_wire = 32'd0;
        endcase
    end
    wire ex_has_fast_wb = (id_ex_rd != 5'd0) && 
                          (ex_is_r_type || ex_is_i_alu || ex_is_lui || ex_is_auipc || ex_is_jal || ex_is_jalr);
    wire [31:0] ex_fast_wb_value = (ex_is_jal || ex_is_jalr) ? ex_pc_plus4 : ex_alu_result_wire;

    // EX -> MEM pipeline register: compute control signals and latch results
    always @(posedge clock) begin
        if (reset) begin
            ex_mem_alu_result <= 32'd0;
            ex_mem_mem_wdata <= 32'd0;
            ex_mem_access_size <= 2'd0;
            ex_mem_we <= 1'b0;
            ex_mem_rd <= 5'd0;
            ex_mem_rs2 <= 5'd0;
            // ex_mem_insn_type <= 9'd0;
            // [11/15] changed
            ex_mem_insn_type <= 9'b0_0000_0100; // addi type to avoid go in to load
            ex_mem_pc <= 32'd0;
            ex_mem_wb_value <= 32'd0;
            ex_mem_wb_value_valid <= 1'b0;
        end else begin
            ex_mem_alu_result <= ex_alu_result_wire;
            ex_mem_mem_wdata <= ex_forward_rs2;
            ex_mem_access_size <= 2'd0;
            ex_mem_we <= 1'b0;
            ex_mem_rd <= id_ex_rd;
            ex_mem_rs2 <= id_ex_rs2;
            ex_mem_insn_type <= ex_insn_type;
            ex_mem_pc <= id_ex_pc;
            ex_mem_wb_value <= ex_fast_wb_value;
            ex_mem_wb_value_valid <= ex_has_fast_wb && (id_ex_rd != 5'b0_0000);
            casez (ex_insn_type)
                // R-type ALU writeback
                9'b0_000_01100, 9'b1_000_01100, 9'b0_111_01100, 9'b0_110_01100,
                9'b0_100_01100, 9'b0_001_01100, 9'b0_101_01100, 9'b1_101_01100,
                9'b0_010_01100, 9'b0_011_01100: begin
                    // ALU result already computed
                end
                // I-type ALU already set ex_alu_b above
                9'b?_000_00100, 9'b?_111_00100, 9'b?_110_00100, 9'b?_100_00100,
                9'b0_001_00100, 9'b0_101_00100, 9'b1_101_00100, 9'b?_010_00100, 9'b?_011_00100: begin
                    // ALU result already computed
                end
                // LUI / AUIPC: ALU computed
                9'b???_01101, 9'b???_00101: begin
                end
                // JAL
                9'b???_11011: begin
                    // target in ex_alu_result_wire = pc + imm
                    // set branch taken and set return value is PC+4 (written in MEM stage to WB)
                end
                // JALR
                9'b???_11001: begin
                end
                // Branches: determine taken based on register values (no forwarding implemented)
                9'b?_000_11000: begin  // BEQ
                end
                9'b?_001_11000: begin  // BNE
                end
                9'b?_100_11000: begin  // BLT
                end
                9'b?_101_11000: begin  // BGE
                end
                9'b?_110_11000: begin  // BLTU
                end
                9'b?_111_11000: begin  // BGEU
                end
                // LOADS: set mem_read and remember funct3
                9'b?_000_00000, 9'b?_100_00000, 9'b?_010_00000, 9'b?_001_00000, 9'b?_101_00000: begin
                end
                // STORES: set mem write enables and sizes
                9'b?_000_01000: begin  // SB
                    ex_mem_we <= 1'b1;
                    ex_mem_access_size <= 2'b00;
                end
                9'b?_001_01000: begin  // SH
                    ex_mem_we <= 1'b1;
                    ex_mem_access_size <= 2'b01;
                end
                9'b?_010_01000: begin  // SW
                    ex_mem_we <= 1'b1;
                    ex_mem_access_size <= 2'b10;
                end
                default: ;
            endcase
        end
    end



    // ==================== Memory Stage ====================
    // Drive dmemory inputs from EX/MEM pipeline registers
    always @* begin
        mem_addr = ex_mem_alu_result;
        mem_wdata = ex_mem_mem_wdata;
        mem_we = ex_mem_we;
        mem_access_size = ex_mem_access_size;
        
        // WM forwarding for store data
        if (wm_forward_rs2)
            mem_wdata = mem_wb_data;
    end
    dmemory dmemory_0 (
        .clock(clock),
        .address(mem_addr),
        .data_in(mem_wdata),
        .write_enable(mem_we),
        .data_out(mem_rdata),
        .access_size(mem_access_size)
    );

    // TODO: check reset behavior
    // MEM -> WB pipeline register: prepare writeback data
    always @(posedge clock) begin
        if (reset) begin
            mem_wb_data <= 32'd0;
            mem_wb_rd <= 5'd0;
            mem_wb_pc <= 32'd0;
            mem_wb_we <= 1'b0;
        end else begin
            mem_wb_rd <= ex_mem_rd;
            mem_wb_pc <= ex_mem_pc;
            mem_wb_we <= ex_mem_wb_value_valid;
            mem_wb_data <= ex_mem_wb_value_valid ? ex_mem_wb_value : 32'h0000_0000;
            // Use insn type to select writeback value and enable
            casez (ex_mem_insn_type)
                // R-type
                9'b?_???_01100: begin
                end
                // I-type ALU
                9'b?_???_00100: begin
                end
                // U-type
                9'b???_01101, 9'b???_00101: begin
                end
                // JAL
                9'b???_11011: begin
                    // mem_wb_we <= 1'b1;
                    // mem_wb_data <= ex_mem_wb_value;
                end
                // JALR
                9'b???_11001: begin
                    // mem_wb_we <= 1'b1;
                    // mem_wb_data <= ex_mem_wb_value;
                end
                // Loads
                9'b?_000_00000: begin // LB
                    mem_wb_we <= (ex_mem_rd != 5'd0);
                    mem_wb_data <= {{24{mem_rdata[7]}}, mem_rdata[7:0]};
                end
                9'b?_100_00000: begin // LBU
                    mem_wb_we <= (ex_mem_rd != 5'd0);;
                    mem_wb_data <= {24'd0, mem_rdata[7:0]};
                end
                9'b?_010_00000: begin // LW
                    mem_wb_we <= (ex_mem_rd != 5'd0);
                    mem_wb_data <= mem_rdata;
                end
                9'b?_001_00000: begin // LH
                    mem_wb_we <= (ex_mem_rd != 5'd0);
                    mem_wb_data <= {{16{mem_rdata[15]}}, mem_rdata[15:0]};
                end
                9'b?_101_00000: begin // LHU
                    mem_wb_we <= (ex_mem_rd != 5'd0);
                    mem_wb_data <= {16'd0, mem_rdata[15:0]};
                end
                // Stores/Branches: no writeback
                default: begin
                    // mem_wb_we <= 1'b0;
                    // mem_wb_data <= 32'h0000_0000;
                end
            endcase
        end
    end


    // ==================== Write Back Stage ====================
    // Connect writeback pipeline register to register file write ports (combinational)
    assign wb_rf_we = mem_wb_we;
    assign wb_rf_rd = mem_wb_rd;
    assign wb_rf_data = mem_wb_data;

    // Next PC selection
    always @* begin
        if (ex_br_taken) begin
            if (ex_is_jalr) // JALR
                if_next_pc = ex_alu_result_wire & ~32'b1;  // 清除最低 
            else
                if_next_pc = ex_alu_result_wire;
        end else begin
            if_next_pc = if_pc_plus4;
        end
    end
endmodule
