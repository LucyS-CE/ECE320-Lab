# PD4: Completing the Single-Cycle Datapath

This document will guide you through the requirements for the memory and writeback stages to complete the single-cycle datapath of your core.

**Deadline**: Friday, October 31, 2025 at 11:59 PM

**Weight**: 25% of total lab grade

## Environment Setup

### Getting the repository

Use `git` to clone the repository to your Linux environment. This can be done using:

```bash
git clone ist-git@git.uwaterloo.ca:ece320-f25/project/g33sun-pd4.git
```

### Setup of simulators and environment variables

Before beginning, ensure that your terminal is using the `bash` shell.
If you run `echo $SHELL`, it should return `/bin/bash` or similar.
If it returns a different shell (e.g. `zsh` or `tcsh`), run the following command:

```bash
chsh -s /bin/bash
```

Log out and log back in and your `echo $SHELL` should now return `/bin/bash`.

Next, go to the root of the project repository and execute the command `source env.sh`.
You should get an output similar to the following.

```bash
$ source env.sh
================ Computer Architecture Course Environment Setup ================

Project Root ($PROJECT_ROOT):           /home/your/path/to/repo
verilator Version ($VERILATOR_VERSION): Verilator 4.210 2021-07-07 rev v4.210
Vivado Version ($VIVADO_VERSION):       Vivado v2022.1 (64-bit)

================ Computer Architecture Course Environment Done =================
```

Note that you will need to run `source env.sh` *every time* you use a different `bash` session.
Otherwise, the scripts will not be able to locate the files.
If the script is unable to locate the verilator or vivado version, the corresponding line will be empty.

## Specification

### Memory Stage

We are going to simplify the memory stage for ourselves by creating another memory module similar to the one we created for PD1.
This makes sense because both instruction and data are loaded into the memory.
The difference in the memory stage will be that we will not be wiring the read_write to only read.
This is because we want to perform the operation specified by the instructions: for a store, we perform a write, and for a load, we perform a read.
Note that you have memory operations that perform loads and stores on byte and half-word data sizes.
When loading bytes and half-words, you can retrieve the full word from the data memory, then strip out the required data in the memory stage.
There are some additions you will have to make in order for the data memory to work correctly.

- **Loads**:
For a given address, retrieve the four byte word that contains the corresponding byte or half-word, and return it on the data
output lines.
The correct 32-bit value can then be organized as per the specification in the processor pipeline.

- **Stores**:
To perform a half-word or byte stores, we need to make minor modifications to the memory interface.
Please add a 2-bit `access_size` port that indicates the size of the access to the memory.
The encoding of size should follow the RISC-V ISA specification.
Thus an `access_size` of 0 is equivalent to a byte access and an `access_size` of 2 is equivalent to a 4-byte (word) access.
For example, a store of `access_size` of two bytes (half-word) would select the appropriate two bytes provided in the input, and write it to the memory.

Note that there is also a `PC+4` component in the memory stage.
You should implement that here or in the writeback stage.

### Writeback Stage

The writeback stage takes the output from the ALU, memory, or PC register and writes it into the register file.
The choice of this data depends on the instruction currently executing.
You may have already generated control signals for it in PD3.
You should expect the logic for it to be quite simple when you are done.

### Full Datapath

After you implement your memory and writeback stages, your single-cycle datapath is complete!
Make sure that every instruction exits the pipeline before the next one is inserted into the pipeline.
Consequently, there is no need for hazard checking until PD5.
In effect, a correctly implemented single-cycle processor can serve as an ISA simulator for yourselves.

With the completion of PD4, you should be able to execute all benchmarks correctly.
The benchmark programs have subroutines called `pass` and `fail`, which write status values to certain registers.
You can use this information to check the correctness of your execution.
The registers used for status information are different for the two types of benchmarks:

- **Simple Programs**:
These benchmarks perform a correctness check after completing execution and then branch to one of the two subroutines.
The `pass` subroutine will write a 1 to register `x10`.

- **Individual Instructions**
These benchmarks perform multiple correctness checks and branch to the `fail` subroutine if any of them fail.
Otherwise, they branch to the `pass` subroutine which writes a 1 to register `x3`.

## Probes

You will need to fill in `design/signals.h` with your signal names in `design/code/pd.v` to wire up the probes.
The new probes are as follows:

```verilog
`define M_PC                ??? /* PC of instruction in memory stage */
`define M_ADDRESS           ??? /* Address input to the dmemory */
`define M_RW                ??? /* Read/write input to the dmemory */
`define M_SIZE_ENCODED      ??? /* Access size input to the dmemory */
`define M_DATA              ??? /* Data input to the dmemory */

`define W_PC                ??? /* PC of instruction in writeback stage */
`define W_ENABLE            ??? /* Write enable for rd of instruction in writeback stage */
`define W_DESTINATION       ??? /* Register rd index for instruction in writeback stage */
`define W_DATA              ??? /* Register rd data for instruction in writeback stage */
```

## Tests

We provide simple tests that test for signal presence and basic timing correctness.

- `test_pd`: Tests for basic signal presence and to generate trace files (see below).  Note that `test_pd` does not check correctness properties, so it does not output `Test passed` even if it successfully completes.
- `test_pre_check`: Tests the initialization properties of your modules.

To run these tests, go to `verif/scripts` and use the following command:

```bash
make -s run [TEST=<test_name>] [MEM_PATH=<mem_path>]
```

If you do not supply a `TEST`, the command will default to the `test_pd` test.
We use the [rv32-benchmarks](https://git.uwaterloo.ca/ece320-f25/rv32-benchmarks) to test your design.
The path to the input `.x` file is provided to you as a macro of string named `MEM_PATH`.
You can set this macro when you run `make` to test different benchmarks.

We will be using trace files to output signal values at each pipeline stage every clock cycle.
For PD4, we will output information from the full datapath.
If it doesn't encounter any errors, the `test_pd` test will generate a `.trace` file for a given benchmark located in `verif/sim/verilator/test_pd/`.
This time, your output will consist of two new lines for each instruction:

- Memory stage `[M]`: formatted as `[M] pc_address memory_address read_write access_size memory_data` in hexadecimal format.
- Writeback stage `[W]`: formatted as `[W] pc_address write_enable write_rd data_rd` in hexadecimal format.

For PD4, we provide you with golden trace files for the individual instruction benchmarks in `verif/golden`.
Make sure that your output lines up with these.

## Testbench

Apart from the tests we provided, you may write your own testbenches.
This is not required, but may help you find new bugs that the other tests cannot find.

You need to place your testbench in a module called `top`, located in `verif/tests/` (e.g. `verif/tests/test_my_pd.v`).
You may refer to `test_pd.v` and extend from that file.
By creating `test_my_pd.v`, you will be able to run the test in `verif/scripts` using `make run TEST=test_my_pd`.
Make sure that your design does not report any warning during compilation.

We provide the verilator `verif/tests/test_pd.cpp` that drives your testbench. 
However, your testbench should not depend on any modifications to the `test_pd.cpp`.

## Troubleshooting your Design

You may be tempted to rely on `$display()` tasks to debug your design.
However, it can be difficult to determine when signals change value with these statements.
Instead, you can plot the waves using `gtkwave`.
We have provided a Makefile target to do this:

```bash
make waves [MEM_PATH=<mem_path>]
```

You can edit `verif/scripts/waves.tcl` to automatically add specific signals to your screen, group signals together, set colours and zoom level, etc.
If you would like to do this Appendix C in the project deliverables document on LEARN.

Remember that if you add any verilog files to `design/code`, be sure to add them to `verif/scripts/design.f`.

## Submission

The following are deliverables for PD4.

1. Implement a data memory module that meets the specifications above.
2. Implement the writeback stage as described above.
3. Instantiate your data memory module and any other modules you create in `design/code/pd.v`.
4. Add probe mappings to `design/signals.h`.
5. Ensure that your core executes all [rv32-benchmarks](https://git.uwaterloo.ca/ece320-f25/rv32-benchmarks) correctly and that your trace file output is consistent with `verif/golden`.

When you are finished, remember to commit and push your changes to your GitLab repository.
Be sure to execute `git add <PATH(S) TO NEW FILE(S)>` if you add any new files before committing your changes.

```bash
git commit -am "<message>"
git push origin master
```

Your most recently pushed code prior to the deadline will be treated as your submission when we grade.

## Credits


The project structure heavily borrows the AWS EC2 FPGA HDK structure, [see here](https://github.com/aws/aws-fpga).
