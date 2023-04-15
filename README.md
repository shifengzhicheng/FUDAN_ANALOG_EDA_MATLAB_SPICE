# 模拟EDA SPICE工具

该项目是由复旦大学模拟集成电路设计自动化课程布置的课程作业。项目实现了一个基本的电路 SPICE 工具(Simulation Program with Integrated Circuit Emphasis)，可以对包含 MOSFET（简单的level1模型）、电阻、电容和电感的电路执行 DC 分析以及瞬态分析。

## 项目成员

| 成员名称 | 学号 |
| :----- | :---------: |
| 郑志宇 | 20307130176 |
| 朱瑞宸 |             |
| 林与正 |             |
| 张润洲 |             |

## 功能说明

该工具可以读入电路网表文件，然后执行 DC 分析和瞬态分析，生成对应的输出结果。支持的电路元件包括 MOSFET、电阻器、电容器和电感器。

在 DC 分析中，可以计算电路中各节点的电压和电流。在瞬态分析中，可以计算电路中各节点在一定时间范围内的电压和电流波形。

在 MOSFET 模型中，使用了简化版的 SPICE Level = 1 的 MOS 模型。MOSFET 的源端和漏端不是固定的，需要由两个端口当前的电压值来判断。寄生电容模型中，忽略了 MOS 管模型中寄生电容的非线性特性，假定各寄生电容形式为 $C_{gs}=1/2,~C_{ox}WL=C_{gd},~C_d=C_s=C_{j0}$。

## 用法

### 环境要求

- MATLAB R2020b 或以上版本

### 如何使用

1. 在 MATLAB 中运行 `main.m` 脚本
2. 在命令行中输入电路网表文件名
3. 根据提示选择执行 DC 分析或瞬态分析
4. 根据提示输入分析参数（例如电源电压、仿真时间等）

## 电路网表文件格式

电路网表文件是一个文本文件，格式如下：

```css
* non-inverting buffer
VDD 103 0 DC 3
Vin 101 0 SIN 1.5 2 10e6 0
Rin 101 102 10

M1   107 102 103 p 30e-6 0.35e-6 1
M2   107 102 0   n 10e-6 0.35e-6 2
M3   104 107 103 p 60e-6 0.35e-6 1
M4   104 107 0   n 20e-6 0.35e-6 2

C1 104 0 0.1e-12
R2 104 115 25
L1 115 116 0.5e-12
C2 116 0 0.5e-12
R3 116 117 35
L2 117 118 0.5e-12
C3 118 0 1e-12

.MODEL 1 VT -0.75 MU 5e-2 COX 0.3e-4 LAMBDA 0.05 CJ0 4.0e-14
.MODEL 2 VT 0.83 MU 1.5e-1 COX 0.3e-4 LAMBDA 0.05 CJ0 4.0
```

## 项目的结构

```bash
├── circuit                 # 电路仿真工具源码目录
│   ├── component.m        # 电路元件类定义
│   ├── dc_analysis.m      # 直流分析类定义
│   ├── transient_analysis.m # 瞬态分析类定义
│   ├── main.m             # 程序入口
│   ├── netlist_parser.m   # 网表解析器类定义
│   └── mosfet.py           # MOS管模型类定义
├── examples                # 示例文件目录
│   ├── inverter.cir        # 单个MOS管的反相器电路
│   ├── buffer.cir          # 双MOS管的缓冲器电路
│   ├── lc_filter.cir       # LC滤波器电路
│   └── amplifier.cir       # 差分放大器电路
├── README.md               # 项目说明文件
```

## 使用方法说明

按照标准的电路网表文件进行输入产生电路，然后选择需要查看的端口或者器件的数据信息，选择 DC 或者瞬态仿真或者频率响应分析然后可以得到仿真的图像和数据结果。

## 项目细节介绍

### Part 1 实现电路文件的读取，建立矩阵方程

实现项目的思路是慢慢来的。刚开始我们对项目还没有一个完整的把握，很多过程其实只有一个概念，具体该怎么做还不是很清楚明白。所以我们先做了一些中间看起来相对独立但是

#### 电路文件的读取与预处理

#### 实现矩阵方程的建立

矩阵方程只解线性电路，所以我们暂时不考虑电容、电感、MOSFET 的问题，这些非线性元件将在后面被转化成相应的线性元件然后进入迭代之中。

### Part 2 迭代求解电路的直流工作点

### Part 3 实现trans仿真

### Part 4 实现频率响应分析

## 结束语

要注意，我们的项目的仿真工具实现的只是一个较为简单的功能，部分地方细节并不完善，考虑也有欠妥的地方，还有不少改善空间。巴拉巴拉