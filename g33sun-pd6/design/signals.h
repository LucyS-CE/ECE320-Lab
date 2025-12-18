/* Your Code Below! Enable the following define's
 * and replace ??? with actual wires */
// ----- signals -----
// You will also need to define PC properly
`define F_PC      if_pc // address
`define F_INSN    if2_insn // data_out (imemory output before IF->ID register)

`define D_PC      if_id_pc
`define D_OPCODE  id_opcode
`define D_RD      id_rd
`define D_RS1     id_rs1
`define D_RS2     id_rs2
`define D_FUNCT3  id_funct3
`define D_FUNCT7  id_funct7
`define D_IMM     id_imm
`define D_SHAMT   id_shamt

`define R_WRITE_ENABLE       wb_rf_we
`define R_WRITE_DESTINATION  wb_rf_rd
`define R_WRITE_DATA         wb_rf_data
`define R_READ_RS1           id_rf_rs1
`define R_READ_RS2           id_rf_rs2
`define R_READ_RS1_DATA      id_id2_rs1_data
`define R_READ_RS2_DATA      id_id2_rs2_data

`define E_PC                id_ex_pc
`define E_ALU_RES           ex_alu_result_wire
`define E_BR_TAKEN          ex_br_taken

`define M_PC                ex_mem_pc
`define M_ADDRESS           mem_addr
`define M_RW                mem_we
`define M_SIZE_ENCODED      mem_access_size
`define M_DATA              mem_wdata

`define W_PC                mem_wb_pc
`define W_ENABLE            wb_rf_we
`define W_DESTINATION       wb_rf_rd
`define W_DATA              wb_rf_data

`define IMEMORY             imemory_0
`define DMEMORY             dmemory_0

    // ----- signals -----

    // ----- design -----
`define TOP_MODULE      pd
    // ----- design -----
