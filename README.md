# RISCV_32I_MAC System Design

RV32I 기반의 RISC-V 프로세서에 고성능 행렬 연산 가속을 위한 **커스텀 MAC(Multiply-Accumulate) 유닛**과 **VGA Text Subsystem**등 IO를 통합한 SoC(System-on-Chip) 프로젝트이다.

본 프로젝트는 코어 구현을 넘어, 하드웨어 가속기 설계 및 주변장치 인터페이스 통합 과정을 포함하는 전형적인 시스템 반도체 설계 흐름을 따른다.

---

## Design Flow

### 1단계: Single Cycle RV32I Processor Core 설계
프로젝트의 기반이 되는 RISC-V RV32I 입출력 세트를 처리하는 코어를 설계했다.
- **ISA**: RISC-V 32-bit Integer (RV32I)

RISC-V ISA 
https://docs.riscv.org/reference/isa/unpriv/rv32.html


RISC-V 32I ISA를 정리하면 다음과 같다. ECALL, EBREAK, FENCE를 제외한 나머지 37개의 명령어이다. 

<img width="3616" height="1473" alt="rv32i_isa" src="https://github.com/user-attachments/assets/d2ff8a65-2200-40df-89d4-9af1af2c271d" />


또한 구글에서 강의자료를 참고하여, 블록 다이어그램을 구성했다. 

<img width="12500" height="7280" alt="RV32I drawio" src="https://github.com/user-attachments/assets/80b1ecd7-1246-429e-835d-e58470493ec0" />

Reference : https://lishixuan001.com/posts/40785/

Reference에 나와있는 블록 다이어그램을 참고하여, 37개의 ISA를 모두 실행가능하도록 Control 신호를 추가하여 블록 다이어그램을 구성했다.
Single cycle 특성상 Data Memory, Immediate Memory, Register File은 Asynchronous read - Synchronous write로 설계된다.

또한 ISA별 Control 신호를 정리한 표는 다음과 같다. 
(Control 신호 정리 표)

구성한 블록 다이어그램을 기반으로 각 ISA 명령어의 Dataflow를 분석하고, ISA별 필요한 Control Signal, 모듈별 in-out을 도출하여 설계에 반영했다.  

또한 IO, MAC 유닛 설계 시의 확장성을 고려하여 Data Memory와 Immediate Memory를 Core와 분리하고, Core를 DataPath와 Control로 분리해 주었다. 
아래 그림은 이를 반영한 블록 다이어그램이다. 

<img width="3210" height="2260" alt="RV32I_BASIC drawio" src="https://github.com/user-attachments/assets/a2a0c53d-42b9-4e2c-a735-280e76c74228" />


### 2단계: 커스텀 MAC (Multiply-Accumulate) 유닛 설계
행렬 연산 및 신호 처리 가속을 위해 단일 클럭 내 연산을 수행하는 하드웨어 가속기를 설계하였습니다.
- **커스텀 명령어**: `v2mac` (Opcode: `0x0B`, Custom Instruction)
- **연산 논리**: 두 개의 16비트 데이터를 동시에 곱한 뒤 기존 레지스터 값에 누산하는 구조 (`rd = (rs1_high * rs2_high) + (rs1_low * rs2_low) + rd`)
- **FSM 제어**: 4-State (IDLE → LATCH_RS → FETCH_RD → CALC_WB) 하드웨어 상태 머신을 통해 코어 데이터패스와 동기화하여 연산을 수행합니다.

### 3단계: 주변장치 (Peripheral) 설계 - VGA Subsystem
시스템의 출력 결과를 실시간으로 시각화하기 위한 VGA 컨트롤러를 설계하였습니다.
- **VGA Text Mode**: 640x480 resolution (25MHz Pixel Clock) 환경에서 텍스트(ASCII) 출력을 지원합니다.
- **Font ROM**: 하드웨어 내부에 ASCII 폰트 데이터를 내장하여 CPU가 글자 코드만 전송하면 화면에 즉시 렌더링합니다.
- **Video Memory**: CPU와 VGA 컨트롤러가 동시에 접근 가능한 Dual-port RAM 기반의 Video Buffer를 구현하였습니다.

### 4단계: 시스템 통합 및 I/O 연결
설계된 Core, MAC, Peripheral들을 하나의 버스 시스템으로 통합하였습니다.
- **MMIO Interconnect**: 메모리 맵 기반의 I/O 방식을 사용하여 CPU가 특정 주소에 쓰기 동작을 수행하는 것만으로 주변장치를 제어할 수 있습니다.
- **System Top-level Wiring**: `System_Top.v`를 통해 Core, IMEM, Interconnect, DMEM, VGA Subsystem을 유기적으로 연결하여 전체 SoC 아키텍처를 완성하였습니다.

---

## 🗺️ Memory Map
시스템 리소스는 아래와 같이 메모리 공간에 할당되어 관리됩니다.

| 주소 영역 (Address Range) | 장치 (Device) | 설명 |
| :--- | :--- | :--- |
| `0x0000_0000 ~ 0x0000_FFFF` | **DMEM** | 데이터 메모리 (최대 64KB) |
| `0x4000_0000 ~ 0x4000_0FFF` | **VMEM (VGA)** | VGA 텍스트 버퍼 (ASCII 출력용) |

---

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
