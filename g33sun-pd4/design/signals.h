/* Your Code Below! Enable the following define's 
 * and replace ??? with actual wires */
// ----- signals -----
// You will also need to define PC properly
`define F_PC                    imemory_pc  // address
`define F_INSN                  imemory_insn  // data_out

`define D_PC                    pd_pc
`define D_OPCODE                pd_opcode
`define D_RD                    pd_rd
`define D_RS1                   pd_rs1
`define D_RS2                   pd_rs2
`define D_FUNCT3                pd_funct3
`define D_FUNCT7                pd_funct7
`define D_IMM                   pd_imm
`define D_SHAMT                 pd_shamt

`define R_WRITE_ENABLE          rf_write_enable
`define R_WRITE_DESTINATION     rf_write_dest
`define R_WRITE_DATA            rf_write_data
`define R_READ_RS1              rf_read_rs1
`define R_READ_RS2              rf_read_rs2
`define R_READ_RS1_DATA         rf_read_rs1_data
`define R_READ_RS2_DATA         rf_read_rs2_data

`define E_PC                    es_pc
`define E_ALU_RES               es_alu_res
`define E_BR_TAKEN              es_br_taken

`define M_PC                es_pc
`define M_ADDRESS           mem_addr
`define M_RW                mem_we
`define M_SIZE_ENCODED      mem_access_size
`define M_DATA              mem_wdata

`define W_PC                es_pc
`define W_ENABLE            rf_write_enable
`define W_DESTINATION       rf_write_dest
`define W_DATA              rf_write_data

// ----- signals -----

// ----- design -----
`define TOP_MODULE                 pd
// ----- design -----
