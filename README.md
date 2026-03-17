# RISCV_32I_MAC System Design

RV32I 기반의 RISC-V 프로세서에 고성능 행렬 연산 가속을 위한 **커스텀 MAC(Multiply-Accumulate) 유닛**과 **VGA Text Subsystem**등 IO를 통합한 SoC(System-on-Chip) 프로젝트이다.

Custom ISA를 가지는 RV32I Single Cycle CPU를 설계, 검증하고, FPGA에 구현하는 것이 목표이다.

## 🛠️ 개발 환경 및 검증
- **FPGA Board**: Terasic DE1-SoC (Cyclone V)
- **Design Tools**: Intel Quartus Prime 18.1
- **Simulation**: Xcelium
- **Language**: Verilog HDL 
---

## 📂 폴더 구조 및 파일 설명
```text
📦 rtl
 ┣ 📂 core          # RISC-V Core (ALU, Control, DataPath 등)
 ┣ 📂 mac           # Custom MAC Accelerator (Instruction Decoder, Multiplier)
 ┣ 📂 peripherals   # VGA Subsystem (Sync Gen, Text Gen, Font ROM)
 ┣ 📂 memory        # IMEM, DMEM, MMIO Interconnect
 ┗ 📂 board         # Board Specific (PLL, DE1_Top Wrapper)
```
---

## Design Flow

### 1단계: Single Cycle RV32I Processor Core 설계
프로젝트의 기반이 되는 RISC-V RV32I ISA를 가지는 Single Cycle CPU를 설계하였다.
- **ISA**: RISC-V 32-bit Integer (RV32I) RISC-V ISA : https://docs.riscv.org/reference/isa/unpriv/rv32.html

RISC-V 32I ISA를 정리하면 아래 표와 같다. 
ECALL, EBREAK, FENCE 명령어를 제외한 37개의 명령어이다.

<img width="3616" height="1473" alt="rv32i_isa" src="https://github.com/user-attachments/assets/d2ff8a65-2200-40df-89d4-9af1af2c271d" />

또한 구글에서 강의자료를 참고하여, 블록 다이어그램을 구성한다. 

<img width="12500" height="7280" alt="RV32I drawio" src="https://github.com/user-attachments/assets/80b1ecd7-1246-429e-835d-e58470493ec0" />

Reference : https://lishixuan001.com/posts/40785/

Reference에 나와있는 블록 다이어그램을 참고하여, 37개의 Instruction을 모두 실행가능하도록 Control 신호를 추가하여 블록 다이어그램을 구성하였다.
Single cycle 특성상 Data Memory, Immediate Memory, Register File은 Asynchronous read - Synchronous write로 설계하였다.

Instruction별 Control 신호를 정리한 표는 다음과 같다. 
(Control 신호 정리 표)

구성한 블록 다이어그램을 기반으로 각 Instruction의 Dataflow를 분석하고, Instruction별 필요한 Control Signal, 모듈 in-out을 도출하여 설계에 반영하였다. 

또한 IO, MAC 유닛 설계 시의 확장성을 고려하여 Data Memory와 Immediate Memory를 Core와 분리하고, Core를 DataPath와 Control로 분리하였다.
아래 그림은 이를 반영한 블록 다이어그램이다. 

<img width="3210" height="2260" alt="RV32I_BASIC drawio" src="https://github.com/user-attachments/assets/a2a0c53d-42b9-4e2c-a735-280e76c74228" />


### 2단계: MAC (Multiply-Accumulate) 유닛 설계
벡터 연산 및 신호 처리 가속을 위해 전용 하드웨어 MAC 유닛을 설계한다. 

- **커스텀 명령어**: `v2mac` (Opcode: `0x0B`, Custom Instruction)
- **연산 구조**: 두 개의 16비트 데이터를 동시에 곱한 뒤 기존 레지스터 값에 누산하는 구조 (`rd = (rs1_high * rs2_high) + (rs1_low * rs2_low) + rd`)
- **FSM 제어**: 2-State (IDLE → CALC_WB) 하드웨어 상태 머신을 통해 코어 데이터패스와 동기화하여 연산을 수행한다.

새로 추가한 Custom Instruction은 32비트 레지스터에 16비트 값 두개를 저장하여 각각 상위비트, 하위비트를 곱한 값을 기존 레지스터에 누산하는 구조이다. 
(`rd = (rs1_high * rs2_high) + (rs1_low * rs2_low) + rd`)

Register File의 구조적 한계로 인해, MAC 유닛을 Single Cycle로 구현하는 것이 불가능하다 (Register File의 read port가 2개뿐이기 때문이다). 표준 RISC-V 아키텍처는 2-Read 1-Write(2R1W) 구조를 명시하고 있으며, 만약 싱글 사이클 MAC 연산을 위해 강제로 읽기 포트를 3개로 증설할 경우, critical path가 증가할 우려가 있다. 이는 전체 시스템의 동작 주파수(fmax)를 하락시키는 성능 저하의 주원인이 된다. 따라서 기존의 2포트 구조를 유지하면서 연산을 2-Cycle로 분리하여 설계하였다.

### 2.1 MAC 유닛 구조

MAC 유닛은 (IDLE - CALC_WB)의 2-state 구조로 설계하였다. 
IDLE 상태에서는 rs1, rs2값을 읽고 FF에 저장하며,  mac_on 신호를 발생시켜 pc_en을 0으로 만들어 clock cycle을 멈추고 다음 state로 진행한다.
CALC_WB 상태에서는 rd값을 읽고 저장된 rs1, rs2와 rd를 통해 연산을 수행하고 wb_sel_mac 신호를 발생시킨다. 
아래 그림은 MAC 유닛의 state diagram을 나타낸 것이다.



mac_on 신호를 통해 Datapath로 들어가는 Control 신호를 muxing하여, mac 연산 중 필요한 신호들을 제어한다. 


MAC 유닛의 핵심 연산인 곱셈은 16bit로 설계하였는데, 이는 Cyclone V FPGA에 내장된 DSP 리소스를 활용하기 위함이다. 
Cyclone V FPGA는 두개의 18x18bit의 곱셈 및 덧셈을 1클럭에 수행할 수 있는 DSP 리소스를 내장하고 있다. 
이를 위해 behavioral 수준에서 곱셈 연산을 구현하였다. 

### 3단계: 시스템 레벨 검증 - Constrained Random Test

각각의 모듈과 다르게, 시스템 레벨에서 CPU는 상당히 복잡한 구조를 가지고 있다. 따라서 설계된 CPU가 정상적으로 작동하는지에 대한 검증이 필요하다. 
초기에는 특정한 알고리즘은 Assembly로 작성한 후, RARS (RISC-V Assembler and Runtime Simulator)를 이용하여 Register File, Program Counter의 값을 비교하는 방법으로 검증을 수행하였다. 
하지만 이 방법은 매우 한정된 경우의 수만 검증할 수 있으며, 실제로 이 방법으로 잡아내지 못한 오류가 다수 발생하는 문제가 있다. 
따라서 보다 많은 수의 체계적인 방법의 검증이 필요하며, 이를 위해 Constrained Random Test를 도입하였다. 

검증은 Verilog 문법인 Task문을 주로 활용하여 구현된다. RISC-V Instruction 형태에 맞는 Random한 Instruction을 생성하고, 
Verilog 문법 연산을 통해 예상되는 결과와 실제 CPU의 동작 결과를 비교한다. 

tb_System_top_CRT.v 파일에서 검증에 사용된 testbench의 구조를 확인할 수 있다. 

### 4단계: 주변장치 (Peripheral) 설계 - VGA Subsystem
Peripheral은 MMIO 방식으로 접근할 수 있도록 설계하였다.

- **VGA Text Generator**: 640x480 해상도 (25MHz Pixel Clock) 환경에서 텍스트(ASCII) 출력을 지원한다.

## 🗺️ Memory Map

| 주소 영역 (Address Range) | 장치 (Device) | 설명 |
| :--- | :--- | :--- |
| `0x0000_0000 ~ 0x0000_FFFF` | **DMEM** | 데이터 메모리 (최대 64KB) |
| `0x4000_0000 ~ 0x4000_0FFF` | **VMEM (VGA)** | VGA 텍스트 버퍼 (ASCII 출력용) |

---

