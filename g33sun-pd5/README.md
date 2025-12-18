# PD5: 5-Stage Pipelined Design

This document will guide you through introducing pipelining, bypassing, and stalling into your core from PD4.

**Deadline**: Friday, November 14, 2025 at 11:59 PM

**Weight**: 25% of total lab grade

## Environment Setup

### Getting the repository

Use `git` to clone the repository to your Linux environment. This can be done using:

```bash
git clone ist-git@git.uwaterloo.ca:ece320-f25/project/g33sun-pd5.git
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

You will add support for pipelined execution, bypassing, and stalling.

### Pipelined Execution

Your first task will be to add pipelining to your datapath as presented in the lectures.
You should have distinct fetch, decode, execute, memory, and writeback stages.
No two stages should be processing the same instruction in the same cycle.
The simplest way to do this will be to add pipeline registers for each signal you want to propagate between each stage.
This pipelining logic will likely go in your `pd` module.

### Bypassing

You will need to implement bypassing in the following paths:

- From the memory stage to the execute stage (MX).
- From the writeback stage to the execute stage (WX).
- From the writeback stage to the memory stage (WM).

**For PD5, we *require* bypassing into the branch comparator.**

**Do not implement bypassing into the decode stage.**

### Stalling

After you implement bypassing, you will still have some read-after-write (RAW) hazards between the decode stage and later stages.
In these cases, the data dependence cannot be resolved via forwarding, so you must stall the pipeline.
Recall that the basic method to stall the pipeline is to insert NOPs until the RAW does not exist.
In RISC-V, `nop` is a pseudoinstruction which is equivalent to `addi x0, x0, 0`.
Since this `addi` instruction reads from and writes to `x0`, the instruction should not write to the register file or PC.
Additionally, you must resolve any structural hazards that occur.

## Probes

You will need to fill in `design/signals.h` with your signal names in `design/code/pd.v` to wire up the probes.
There are no new probes compared to PD4; however, you will need to change some of your probe mappings to correspond to the newly pipelined signals.

## Tests

We provide simple tests that test for signal presence and basic timing correctness.

- `test_pd`: Tests for basic signal presence and to generate trace files (see below).  Note that `test_pd` does not check correctness properties, so it does not output `Test passed` even if it successfully completes.
- `test_pre_check`: Tests the initialization properties of your modules.
- `test_rf_init`: Tests the initialization of your register file. Run this test with 
    ```bash
    make -s run TEST=test_rf_init MEM_PATH=../data/read_rf.x
    ```

To run these tests, go to `verif/scripts` and use the following command:

```bash
make -s run [TEST=<test_name>] [MEM_PATH=<mem_path>]
```

If you do not supply a `TEST`, the command will default to the `test_pd` test.
We use the [rv32-benchmarks](https://git.uwaterloo.ca/ece320-f25/rv32-benchmarks) to test your design.
The path to the input `.x` file is provided to you as a macro of string named `MEM_PATH`.
You can set this macro when you run `make` to test different benchmarks.

We will be using trace files to output signal values at each pipeline stage every clock cycle.
If it doesn't encounter any errors, the `test_pd` test will generate a `.trace` file for a given benchmark located in `verif/sim/verilator/test_pd/`.

For PD5, we provide you with golden trace files for the individual instruction benchmarks in `verif/golden`.
Make sure that your output lines up with these.

The [rv32-benchmarks](https://git.uwaterloo.ca/ece320-f25/rv32-benchmarks) have subroutines called `pass` and `fail`, which write status values to certain registers.
You can use this information to check the correctness of your execution.
The registers used for status information are different for the two types of benchmarks:

- **Simple Programs**:
These benchmarks perform a correctness check after completing execution and then branch to one of the two subroutines.
The `pass` subroutine will write a 1 to register `x10`.

- **Individual Instructions**
These benchmarks perform multiple correctness checks and branch to the `fail` subroutine if any of them fail.
Otherwise, they branch to the `pass` subroutine which writes a 1 to register `x3`.

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

The following are deliverables for PD5.

1. Implement pipelining logic such that your core has five distinct stages: fetch, decode, execute, memory, writeback.
2. Implement bypasses for the paths described in lectures (MX, WX, and WM) **plus bypass paths into the branch comparator**.
3. Implement stalling to resolve data hazards and structural hazards.
4. Modify probe mappings in `design/signals.h` to reflect the pipelined design.
5. Ensure that your core executes all [rv32-benchmarks](https://git.uwaterloo.ca/ece320-f25/rv32-benchmarks) correctly.

When you are finished, remember to commit and push your changes to your GitLab repository.
Be sure to execute `git add <PATH(S) TO NEW FILE(S)>` if you add any new files before committing your changes.

```bash
git commit -am "<message>"
git push origin master
```

Your most recently pushed code prior to the deadline will be treated as your submission when we grade.

## Credits


The project structure heavily borrows the AWS EC2 FPGA HDK structure, [see here](https://github.com/aws/aws-fpga).
