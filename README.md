# 🧠 32-bit RISC-V 5-Stage Pipelined Processor (RV32I)

A fully functional **32-bit in-order RISC-V pipelined core** implemented in **SystemVerilog**, featuring complete hazard handling, control logic, and verification testbenches.

This project was developed as part of **EECS 4201 – Computer Architecture** and is designed to closely reflect real-world pipeline implementations used in industry.

---

## ✨ Features

- **RV32I ISA Support**
- **Classic 5-stage pipeline**
  - Fetch (F)
  - Decode (D)
  - Execute (X)
  - Memory (M)
  - Writeback (W)
- **Hazard Handling**
  - Data hazard detection
  - Stall insertion
  - Forwarding / bypassing logic
- **Control Hazard Handling**
  - Branch resolution logic
  - Pipeline flushing / squashing
- **Pipeline Registers**
  - Enable/disable control
  - Flush/Squash and stall support
- **Verification**
  - Stage-level testbenches
  - Hazard, stall, bypass, and flush testing
- **Clean modular SystemVerilog design**

---

## 🧩 Pipeline Datapath

<p align="center">
  <img src="https://github.com/user-attachments/assets/dcf56d0b-88b6-4bf0-96f0-f5317496ee81" width="600"/>
</p>

---

## 🗂️ Project Structure

```text
.
├── rtl/
│   ├── fetch/
│   ├── decode/
│   ├── execute/
│   ├── memory/
│   ├── writeback/
│   ├── control/
│   ├── hazard/
│   └── pipeline_registers/
│
├── testbench/
│   ├── tb_pp.sv
│   └── tb_fdxmw_top.sv
│
├── scripts/
│   └── Makefile
│
└── README.md
```

## 🔁 Hazard & Control Handling Overview
# Data Hazards
 - RAW hazard detection in Decode stage
 - Forwarding paths from:
    - MEM → EX
    - WB → EX
    - WB → MEM
  - Automatic stall insertion when forwarding is not possible

# Control Hazards
 - Branch decision handled in Execute stage
 - Pipeline flush on taken branch
 - Squashing of incorrect instructions

## 🧪 Verification Strategy
 - Dedicated stage-level testbenches for:
    - Stages
    - Full pipeline integration
 - Designed for:
   - Localized bug detection
   - Easier debugging of stalls, bypassing, and flushing
 - Tested using ModelSim

## 🛠️ Tools & Technologies
 - SystemVerilog
 - ModelSim
 - Makefile-based simulation
 - Git / GitHub
 - Linux development environment

## 🔮 Future Improvements
 - Dynamic branch prediction
 - Instruction and data caches
 - Cache coherence support
 - Memory allocation and MMU extensions
 - Performance counters

## 📚 Educational Value
This project closely mirrors:
 - Industry-style RTL design
 - Pipeline hazard resolution logic
 - Verification-driven development
 - Modular, maintainable hardware architecture
It is suitable as:
 - A reference RISC-V pipeline implementation
 - A teaching aid for computer architecture
 - A foundation for research or extension

## 👤 Author
#Minhyeok An
Computer Engineering Graduate — York University
Specialization: Computer Architecture & Digital Hardware
🔗 GitHub: https://github.com/Anmh0128
🔗 LinkedIn: https://linkedin.com/in/minhyeok-an

```markdown
![SystemVerilog](https://img.shields.io/badge/SystemVerilog-RTL-blue)
![RISC-V](https://img.shields.io/badge/RISC--V-RV32I-orange)
![ModelSim](https://img.shields.io/badge/Verified-ModelSim-green)
