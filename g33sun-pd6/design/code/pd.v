
module pd(
    input clock,
    input reset
);
    // ==================== Signal Declarations ====================
    
    // ===== Pipeline Control Signals =====
    reg stall_F, stall_D;
    reg [1:0] flush_cnt;
    reg [1:0] reset_warmup_cnt;
    localparam [31:0] NOP = 32'h0000_0013;  // addi x0, x0, 0
    wire reset_warmup_active = (reset_warmup_cnt != 2'd0);
    wire flush_ID = ex_br_taken || (flush_cnt != 2'd0) || reset_warmup_active;
    
    // ===== IF Stage =====
    reg [31:0]  if_pc;
    wire [31:0] if_pc_plus4 = if_pc + 32'd4;
    reg [31:0]  if_next_pc;
    
    // ===== IF/IF2 Pipeline Register =====
    reg [31:0]  if_if2_pc;
    wire [31:0] if2_insn;           // Output from imemory (combinational)
    
    // ===== IF2/ID Pipeline Register =====
    reg [31:0] if_id_insn;
    reg [31:0] if_id_pc;
    
    // ===== ID Stage (Decode) =====
    wire [31:0] id_pc   = if_id_pc;
    wire [31:0] id_insn = if_id_insn;
    // Decoded instruction fields (combinational)
    reg [6:0]   id_opcode;
    reg [4:0]   id_rd;
    reg [2:0]   id_funct3;
    reg [4:0]   id_rs1;
    reg [4:0]   id_rs2;
    reg [6:0]   id_funct7;
    reg [31:0]  id_imm;
    reg [4:0]   id_shamt;
    
    // ===== ID/ID2 Pipeline Register =====
    reg [31:0] id_id2_pc;
    reg [4:0]  id_id2_rs1;
    reg [4:0]  id_id2_rs2;
    reg [31:0] id_id2_imm;
    reg [4:0]  id_id2_rd;
    reg [4:0]  id_id2_shamt;
    reg [31:0] id_id2_insn;
    
    // ===== ID2 Stage (Register File Read) =====
    wire [4:0]  id_rf_rs1 = id_rs1;
    wire [4:0]  id_rf_rs2 = id_rs2;
    wire [31:0] id2_rf_rs1_data_raw;
    wire [31:0] id2_rf_rs2_data_raw;
    wire [31:0] id_id2_rs1_data = (id_id2_rs1 == 5'd0) ? 32'd0 : id2_rf_rs1_data_raw;
    wire [31:0] id_id2_rs2_data = (id_id2_rs2 == 5'd0) ? 32'd0 : id2_rf_rs2_data_raw;
    
    // ===== ID2/EX Pipeline Register =====
    reg [31:0] id_ex_pc;
    reg [31:0] id_ex_rs1_data;
    reg [31:0] id_ex_rs2_data;
    reg [4:0]  id_ex_rs1;
    reg [4:0]  id_ex_rs2;
    reg [31:0] id_ex_imm;
    reg [4:0]  id_ex_rd;
    reg [4:0]  id_ex_shamt;
    reg [31:0] id_ex_insn;
    
    // ===== EX Stage (Execute) =====
    reg [31:0] ex_alu_a;
    reg [31:0] ex_alu_b;
    reg [3:0]  ex_alu_control;
    reg [31:0] ex_alu_result_wire;
    reg        ex_br_taken;
    // EX stage derived signals
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
    wire ex_uses_rs1_forward = ex_is_branch || ex_is_load || ex_is_store || ex_is_i_alu || ex_is_r_type || ex_is_jalr;
    wire ex_uses_rs2_forward = ex_is_branch || ex_is_r_type || ex_is_store;
    wire [31:0] ex_pc_plus4 = id_ex_pc + 32'd4;
    wire ex_has_fast_wb = (id_ex_rd != 5'd0) && (ex_is_r_type || ex_is_i_alu || ex_is_lui || ex_is_auipc || ex_is_jal || ex_is_jalr);
    wire [31:0] ex_fast_wb_value = (ex_is_jal || ex_is_jalr) ? ex_pc_plus4 : ex_alu_result_wire;
    // ALU operation codes
    localparam ALU_ADD = 4'b0000, ALU_SUB = 4'b0001,
               ALU_AND = 4'b0010, ALU_OR = 4'b0011,
               ALU_XOR = 4'b0100, ALU_SLL = 4'b0101, 
               ALU_SRL = 4'b0110, ALU_SRA = 4'b0111,
               ALU_SLT = 4'b1000, ALU_SLTU = 4'b1001,
               ALU_PASSB = 4'b1010;
    
    // ===== EX/MEM Pipeline Register =====
    reg [31:0] ex_mem_alu_result;
    reg [31:0] ex_mem_mem_wdata;
    reg [1:0]  ex_mem_access_size;
    reg        ex_mem_we;
    reg [4:0]  ex_mem_rd;
    reg [4:0]  ex_mem_rs2;
    reg [8:0]  ex_mem_insn_type;
    reg [31:0] ex_mem_pc;
    reg [31:0] ex_mem_wb_value;
    reg        ex_mem_wb_value_valid;
    
    // ===== MEM Stage (Memory Access) =====
    reg [31:0] mem_addr;
    reg [31:0] mem_wdata;
    reg [1:0]  mem_access_size;
    reg        mem_we;
    
    // ===== MEM/MEM2 Pipeline Register =====
    reg [4:0]  mem_mem2_rd;
    reg [31:0] mem_mem2_pc;
    reg        mem_mem2_wb_value_valid;
    reg [31:0] mem_mem2_wb_value;
    reg [8:0]  mem_mem2_insn_type;
    wire [31:0] mem2_rdata;         // Output from dmemory (combinational)
    reg [31:0] mem2_load_data_processed; // Processed load data (sign/zero extended)
    
    // ===== MEM2/WB Pipeline Register ===
    reg [31:0] mem_wb_data;
    reg [4:0]  mem_wb_rd;
    reg [31:0] mem_wb_pc;
    reg        mem_wb_we;
    
    // ===== WB Stage (Write Back to Register File) =====
    // Only allow writeback when PC is valid (not 0, indicating pipeline has filled)
    reg         wb_rf_we;
    reg  [4:0]  wb_rf_rd;
    reg  [31:0] wb_rf_data;
    
    always @* begin
        wb_rf_we   = mem_wb_we && (mem_wb_pc != 32'd0);
        wb_rf_rd   = (mem_wb_pc != 32'd0) ? mem_wb_rd : 5'd0;
        wb_rf_data = (mem_wb_pc != 32'd0) ? mem_wb_data : 32'd0;
    end
    
    
    
    // ==================== Fetch Stage ====================
    initial begin
        if_pc = 32'h0000_0000;
        if_next_pc = 32'h0000_0000;

        if_id_pc = 32'h0000_0000;  // Fixed: match if_pc initialization
        id_opcode = 7'b000_0000;
        id_rd = 5'b0_0000;
        id_funct3 = 3'b000;
        id_rs1 = 5'b0_0000;
        id_rs2 = 5'b0_0000;
        id_funct7 = 7'b000_0000;
        id_imm = 32'h0000_0000;
        id_shamt = 5'b0_0000;

        mem_wb_data = 32'h0000_0000;
        mem_wb_pc = 32'h0000_0000;
        mem_wb_rd = 5'b0_0000;
        mem_wb_we = 1'b0;
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

    // Branch mispredict flush counter ensures two wrong-path instructions are squashed
    always @(posedge clock) begin
        if (reset) begin
            flush_cnt <= 2'd0;
        end else if (ex_br_taken) begin
            flush_cnt <= 2'd1; // already flush current ID via ex_br_taken, keep one more cycle for IF2
        end else if (flush_cnt != 2'd0) begin
            flush_cnt <= flush_cnt - 2'd1;
        end else begin
            flush_cnt <= 2'd0;
        end
    end

    // Hold ID stage in NOP for one cycle after reset so imemory warm-up data is ignored
    always @(posedge clock) begin
        if (reset) begin
            reset_warmup_cnt <= 2'd1;
        end else if (reset_warmup_cnt != 2'd0) begin
            reset_warmup_cnt <= reset_warmup_cnt - 2'd1;
        end
    end

    wire imem_en = ~stall_F;
    imemory imemory_0 (
        .clock(clock),
        .address(if_pc),
        .data_in(32'b0),
        .read_write(1'b0),
        .data_out(if2_insn),
        .enable(imem_en)
    );
    
    // IF -> IF2 pipeline register (only track PC, not instruction)
    // CRITICAL: if2_insn comes directly from BRAM with 1-cycle delay.
    // We only register the PC here to keep it synchronized with BRAM output.
    always @(posedge clock) begin
        if (reset) begin
            if_if2_pc <= 32'h0000_0000;
        end else if (stall_F) begin
            // Stall: hold PC (BRAM output if2_insn will be stale, but we handle in IF2->ID)
            if_if2_pc <= if_if2_pc;
        end else begin
            // Normal or branch: advance PC
            if_if2_pc <= if_pc;
        end
    end
    
    // IF2 -> ID pipeline register (instruction ready after 1 cycle from BRAM)
    // Use if2_insn directly (no extra delay), but handle stall and branch cases
    always @(posedge clock) begin
        if (reset) begin
            if_id_insn <= NOP;
            if_id_pc <= 32'h0000_0000;
        end else if (flush_ID) begin
            // Flush: insert NOP for two cycles to kill both in-flight wrong-path instructions
            if_id_insn <= NOP;
            if_id_pc <= if_if2_pc;
        end else if (stall_D) begin
            // Stall: hold current instruction
            if_id_insn <= if_id_insn;
            if_id_pc <= if_id_pc;
        end else begin
            // Normal: advance pipeline using if2_insn directly from BRAM
            if_id_insn <= if2_insn;
            if_id_pc <= if_if2_pc;
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
    
    // ===== Register File (BRAM - 坌步读，需覝 1 cycle) =====
    // ID 阶段：逝入地址
    assign id_rf_rs1 = id_rs1;
    assign id_rf_rs2 = id_rs2;
    
    register_file register_file_0 (
        .clock(clock),
        .write_enable(wb_rf_we),
        .addr_rs1(id_rf_rs1),
        .addr_rs2(id_rf_rs2),
        .addr_rd(wb_rf_rd),
        .data_rd(wb_rf_data),
        .data_rs1(id2_rf_rs1_data_raw),
        .data_rs2(id2_rf_rs2_data_raw)
    );
    
    // ID/ID2 Pipeline Register logic
    // id_id2_rs1_data and id_id2_rs2_data: handle x0=0 case
    assign id_id2_rs1_data = (id_id2_rs1 == 5'd0) ? 32'd0 : id2_rf_rs1_data_raw;
    assign id_id2_rs2_data = (id_id2_rs2 == 5'd0) ? 32'd0 : id2_rf_rs2_data_raw;
    
    always @(posedge clock) begin
        if (reset) begin
            id_id2_pc <= 32'd0;
            id_id2_rs1 <= 5'd0;
            id_id2_rs2 <= 5'd0;
            id_id2_imm <= 32'd0;
            id_id2_rd <= 5'd0;
            id_id2_shamt <= 5'd0;
            id_id2_insn <= NOP;
        end else if (ex_br_taken || pipeline_stall) begin
            // Flush or Stall: insert NOP (branch taken, this instruction is from wrong path)
            id_id2_pc <= id_pc;
            id_id2_rs1 <= 5'd0;
            id_id2_rs2 <= 5'd0;
            id_id2_imm <= 32'd0;
            id_id2_rd <= 5'd0;
            id_id2_shamt <= 5'd0;
            id_id2_insn <= NOP;
        end else begin
            // Normal: advance pipeline
            id_id2_pc <= id_pc;
            id_id2_rs1 <= id_rs1;
            id_id2_rs2 <= id_rs2;
            id_id2_imm <= id_imm;
            id_id2_rd <= id_rd;
            id_id2_shamt <= id_shamt;
            id_id2_insn <= id_insn;
        end
    end
    
    // ID2/EX pipeline register: latch decoded fields and register values
    // Priority: reset > ex_br_taken (flush) > pipeline_stall (bubble) > normal
    always @(posedge clock) begin
        if (reset) begin
            id_ex_pc <= 32'd0;
            id_ex_rs1_data <= 32'd0;
            id_ex_rs2_data <= 32'd0;
            id_ex_rs1 <= 5'd0;
            id_ex_rs2 <= 5'd0;
            id_ex_imm <= 32'd0;
            id_ex_rd <= 5'd0;
            id_ex_shamt <= 5'd0;
            id_ex_insn <= NOP;
        end else if (ex_br_taken) begin
            // Flush: insert NOP (branch taken, ID2 instruction is from wrong path)
            id_ex_pc <= id_id2_pc;
            id_ex_rs1_data <= 32'd0;
            id_ex_rs2_data <= 32'd0;
            id_ex_rs1 <= 5'd0;
            id_ex_rs2 <= 5'd0;
            id_ex_imm <= 32'd0;
            id_ex_rd <= 5'd0;
            id_ex_shamt <= 5'd0;
            id_ex_insn <= NOP;
        end else begin
            // Normal: advance pipeline
            id_ex_pc <= id_id2_pc;
            id_ex_rs1_data <= id_id2_rs1_data;
            id_ex_rs2_data <= id_id2_rs2_data;
            id_ex_rs1 <= id_id2_rs1;
            id_ex_rs2 <= id_id2_rs2;
            id_ex_imm <= id_id2_imm;
            id_ex_rd <= id_id2_rd;
            id_ex_shamt <= id_id2_shamt;
            id_ex_insn <= id_id2_insn;
        end
    end
    
    /////////////////////////////////////////////////////////////////////////////
    // --------------- Hazard Detection & Pipeline Stall Logic -----------------
    /////////////////////////////////////////////////////////////////////////////
    // Define mem2_is_load early for use in hazard detection
    wire mem2_is_load = (mem_mem2_insn_type[4:0] == 5'b00000);
    
    // Load-use hazard: producer in ID2, consumer in ID (need 1 stall so data reaches by EX)
    wire id_id2_is_load = (id_id2_insn[6:2] == 5'b00000);  // load in ID2

    // Consumers in ID that need rs1/rs2 data
    wire id_is_branch = (id_insn[6:2] == 5'b11000);  // B-type
    wire id_is_jalr   = (id_insn[6:2] == 5'b11001);  // JALR
    wire id_is_store  = (id_insn[6:2] == 5'b01000);  // S-type
    wire id_is_load   = (id_insn[6:2] == 5'b00000);  // I-type load uses rs1 as base
    wire id_is_r_alu  = (id_insn[6:2] == 5'b01100);  // R-type ALU
    wire id_is_i_alu  = (id_insn[6:2] == 5'b00100);  // I-type ALU imm
    wire id_uses_rs1 = id_is_branch || id_is_jalr || id_is_store || id_is_load || id_is_r_alu || id_is_i_alu;
    wire id_uses_rs2 = id_is_r_alu || id_is_branch || id_is_store;
    
    // Store rs2 is used in MEM stage, so no stall needed for load-use (can forward via WM/M2M)
    wire id_uses_rs1_in_ex = id_uses_rs1;
    wire id_uses_rs2_in_ex = id_is_r_alu || id_is_branch; // exclude store rs2
    
    wire load_use_hazard =
        id_id2_is_load && (id_id2_rd != 5'd0) &&
        ((id_uses_rs1_in_ex && (id_id2_rd == id_rs1)) ||
         (id_uses_rs2_in_ex && (id_id2_rd == id_rs2)));
    
    // WB stage is committing this cycle; hold decode one cycle so rd write completes (covers producer in W, consumer in D)
    wire wb_data_hazard =
        (mem_wb_we && (mem_wb_rd != 5'd0)) &&
        ((id_uses_rs1 && (mem_wb_rd == id_rs1)) ||
         (id_uses_rs2 && (mem_wb_rd == id_rs2)));

    // MEM2 stage is about to write back; hold decode one cycle (covers producer in M2, consumer in D)
    // Check if MEM2 has valid data: either fast_wb or load (data ready from BRAM)
    wire mem2_has_valid_data = mem_mem2_wb_value_valid || (mem2_is_load && (mem_mem2_rd != 5'd0));
    wire mem2_data_hazard =
        (mem2_has_valid_data && (mem_mem2_rd != 5'd0)) &&
        ((id_uses_rs1 && (mem_mem2_rd == id_rs1)) ||
         (id_uses_rs2 && (mem_mem2_rd == id_rs2)));

    wire pipeline_stall = load_use_hazard || wb_data_hazard || mem2_data_hazard;

    always @* begin
        // Branch redirect has higher priority than pipeline stall so PC can jump
        // When branch taken, don't stall - let branch flush the pipeline instead
        stall_F = pipeline_stall && !ex_br_taken;
        stall_D = pipeline_stall && !ex_br_taken;
        
        // Debug: trace hazard conditions
        // if ($time < 200) begin
        //     $display("[%0d] pipeline_stall=%b load_use=%b wb_data=%b mem2_data=%b | stall_D=%b ex_br_taken=%b", 
        //         $time, pipeline_stall, load_use_hazard, wb_data_hazard, mem2_data_hazard, stall_D, ex_br_taken);
        // end
    end
    /////////////////////////////////////////////////////////////////////////////


    // ==================== Execute Stage ====================
    /////////////////////////////////////////////////////////////////////////////
    // --------------- Forwarding Detection Logic -----------------
    /////////////////////////////////////////////////////////////////////////////
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

    // Forwarding detection (M2X stage: MEM/MEM2 -> EX)
    // Can forward if: fast_wb OR load (data ready from BRAM in MEM2)
    // Note: mem2_is_load is defined in hazard detection section
    wire mem_mem2_can_forward = mem_mem2_wb_value_valid || (mem2_is_load && (mem_mem2_rd != 5'd0));
    wire m2x_forward_rs1 =
        (id_ex_rs1 == mem_mem2_rd) &&
        (mem_mem2_can_forward) &&
        (mem_mem2_rd != 5'd0) &&
        !mx_forward_rs1 && // MX has higher priority
        ex_uses_rs1_forward;

    wire m2x_forward_rs2 =
        (id_ex_rs2 == mem_mem2_rd) &&
        (mem_mem2_can_forward) &&
        (mem_mem2_rd != 5'd0) &&
        !mx_forward_rs2 && // MX has higher priority
        ex_uses_rs2_forward;

    // Forwarding detection (WX stage: MEM/WB -> EX)
    wire wx_forward_rs1 =
        (id_ex_rs1 == mem_wb_rd) &&
        (mem_wb_rd != 5'd0) &&
        (mem_wb_we == 1'b1) &&
        !mx_forward_rs1 && // MX forwarding has higher priority
        !m2x_forward_rs1 && // M2X forwarding has higher priority
        ex_uses_rs1_forward;

    wire wx_forward_rs2 =
        (id_ex_rs2 == mem_wb_rd) &&
        (mem_wb_rd != 5'd0) &&
        (mem_wb_we == 1'b1) &&
        !mx_forward_rs2 && // MX forwarding has higher priority
        !m2x_forward_rs2 && // M2X forwarding has higher priority
        ex_uses_rs2_forward;
    
    // Forwarding detection (M2M stage: MEM/MEM2 -> MEM)
    // for Store(rs2) forwarding from MEM2 stage (higher priority - newer instruction)
    wire m2m_forward_rs2 =
        (ex_mem_rs2 == mem_mem2_rd) &&
        (mem_mem2_rd != 5'd0) &&
        mem_mem2_can_forward &&
        (ex_mem_insn_type[4:0] == 5'b01000); // S-type
    
    // Forwarding detection (WM stage: MEM/WB -> MEM)
    // for Store(rs2) forwarding (lower priority - older instruction)
    wire wm_forward_rs2 =
        (ex_mem_rs2 == mem_wb_rd) &&
        (mem_wb_rd != 5'd0) &&
        (mem_wb_we == 1'b1) &&
        !m2m_forward_rs2 && // M2M has higher priority (newer)
        (ex_mem_insn_type[4:0] == 5'b01000); // S-type
    
    // M2X forwarding data: use processed load data for loads, fast_wb value for ALU ops
    wire [31:0] m2x_forward_data = mem2_is_load ? mem2_load_data_processed : mem_mem2_wb_value;
    
    // M2M forwarding data: use processed load data for loads, fast_wb value for ALU ops  
    wire [31:0] m2m_forward_data = mem2_is_load ? mem2_load_data_processed : mem_mem2_wb_value;
    
    // Assign forwarding data (combinational)
    wire [31:0] ex_forward_rs1 = mx_forward_rs1 ? ex_mem_wb_value :
                            (m2x_forward_rs1 ? m2x_forward_data :
                            (wx_forward_rs1 ? mem_wb_data : id_ex_rs1_data));
    wire [31:0] ex_forward_rs2 = mx_forward_rs2 ? ex_mem_wb_value :
                            (m2x_forward_rs2 ? m2x_forward_data :
                            (wx_forward_rs2 ? mem_wb_data : id_ex_rs2_data));
    /////////////////////////////////////////////////////////////////////////////

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

    // EX -> MEM pipeline register: compute control signals and latch results
    always @(posedge clock) begin
        if (reset) begin
            ex_mem_alu_result <= 32'd0;
            ex_mem_mem_wdata <= 32'd0;
            ex_mem_access_size <= 2'd0;
            ex_mem_we <= 1'b0;
            ex_mem_rd <= 5'd0;
            ex_mem_rs2 <= 5'd0;
            ex_mem_insn_type <= 9'b0_0000_0100; // addi type to avoid go in to load
            ex_mem_pc <= 32'd0;
            ex_mem_wb_value <= 32'd0;
            ex_mem_wb_value_valid <= 1'b0;
        end else begin
            // Default: pass through all signals
            ex_mem_alu_result <= ex_alu_result_wire;
            ex_mem_mem_wdata <= ex_forward_rs2;
            ex_mem_rd <= id_ex_rd;
            ex_mem_rs2 <= id_ex_rs2;
            ex_mem_insn_type <= ex_insn_type;
            ex_mem_pc <= id_ex_pc;
            ex_mem_wb_value <= ex_fast_wb_value;
            ex_mem_wb_value_valid <= ex_has_fast_wb;
            
            // Store-specific: set write enable and access size
            ex_mem_we <= ex_is_store;
            ex_mem_access_size <= ex_insn_type[6:5]; // funct3[1:0]: 00=byte, 01=half, 10=word
        end
    end



    // ==================== Memory Stage ====================
    // Drive dmemory inputs from EX/MEM pipeline registers
    always @* begin
        mem_addr = ex_mem_alu_result;
        mem_wdata = ex_mem_mem_wdata;
        mem_we = ex_mem_we;
        mem_access_size = ex_mem_access_size;
        
        // M2M forwarding for store data (highest priority - newer instruction)
        if (m2m_forward_rs2)
            mem_wdata = m2m_forward_data;  // Use processed load data if needed
        // WM forwarding for store data (lower priority - older instruction)
        else if (wm_forward_rs2)
            mem_wdata = mem_wb_data;
    end
    dmemory dmemory_0 (
        .clock(clock),
        .address(mem_addr),
        .data_in(mem_wdata),
        .read_write(mem_we),
        .data_out(mem2_rdata),
        .access_size(mem_access_size)
    );
    
    // Process load data based on instruction type (combinational logic for forwarding)
    always @* begin
        casez (mem_mem2_insn_type)
            9'b?_000_00000: mem2_load_data_processed = {{24{mem2_rdata[7]}}, mem2_rdata[7:0]};   // LB
            9'b?_100_00000: mem2_load_data_processed = {24'd0, mem2_rdata[7:0]};                  // LBU
            9'b?_010_00000: mem2_load_data_processed = mem2_rdata;                                // LW
            9'b?_001_00000: mem2_load_data_processed = {{16{mem2_rdata[15]}}, mem2_rdata[15:0]}; // LH
            9'b?_101_00000: mem2_load_data_processed = {16'd0, mem2_rdata[15:0]};                // LHU
            default:        mem2_load_data_processed = mem2_rdata;
        endcase
    end
    
    always @(posedge clock) begin
        if (reset) begin
            mem_mem2_rd <= 5'd0;
            mem_mem2_pc <= 32'd0;
            mem_mem2_wb_value_valid <= 1'b0;
            mem_mem2_wb_value <= 32'd0;
            mem_mem2_insn_type <= 9'b0_0000_0100; // ADDI
        end else begin
            mem_mem2_rd <= ex_mem_rd;
            mem_mem2_pc <= ex_mem_pc;
            mem_mem2_wb_value_valid <= ex_mem_wb_value_valid;
            mem_mem2_wb_value <= ex_mem_wb_value;
            mem_mem2_insn_type <= ex_mem_insn_type;
        end
    end
    
    // MEM2 -> WB pipeline register: prepare writeback data (data ready after 1 cycle)
    always @(posedge clock) begin
        if (reset) begin
            mem_wb_data <= 32'd0;
            mem_wb_rd <= 5'd0;
            mem_wb_pc <= 32'd0;
            mem_wb_we <= 1'b0;
        end else begin
            mem_wb_rd <= mem_mem2_rd;
            mem_wb_pc <= mem_mem2_pc;
            // Set write enable: fast_wb OR load (and rd != 0)
            mem_wb_we <= mem_mem2_wb_value_valid || (mem2_is_load && (mem_mem2_rd != 5'd0));
            // Select writeback data: use fast_wb value for ALU ops, processed load data for loads
            mem_wb_data <= mem2_is_load ? mem2_load_data_processed : mem_mem2_wb_value;
        end
    end


    // ==================== Write Back Stage ====================
    // wb_rf_* signals are now driven by always @* block above
    
    // Next PC selection
    always @* begin
        if (ex_br_taken) begin
            if (ex_is_jalr) // JALR
                if_next_pc = ex_alu_result_wire & ~32'b1;  // 清除最低佝
            else
                if_next_pc = ex_alu_result_wire;
        end else begin
            if_next_pc = if_pc_plus4;
        end
    end
endmodule
