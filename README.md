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

1. 根据要求书写电路网表文件，可以实现以下操作

   - `.dc`，直流电网电路计算

     > 输入示例：
     >
     > .dc

   - `.hb`，AC频率响应分析`暂未实现`

     > 输入示例：
     >
     > `.hb 10e6 30`

   - `.trans`，瞬态响应分析`暂未实现`

     > 输入示例：
     >
     > `.trans total_time step`

   - `.plotnv node `，可以得到节点的电压

     > 输入示例：显示节点的电流
     >
     > `.plotnv 108 `
     >
     > etc.

   - `.plotnc Device(device_port)`，可以得到器件的节点电流

     > 输入示例：显示器件对应的节点的电流
     >
     > `.plotnc M1(d/g/s)`
     >
     > `.plotnc I1(+)`
     >
     > `.plotnc R1(-)`
     >
     > `.plotnc V1(+)`
     >
     > etc.

   - `.MODEL <mosID> VT <Value> MU <Value> COX <Value> LAMBDA <Value> CJ0 <Value>`创建一个MOS管模型，可以根据需求创建不同的MOS管模型，输入要求：MODEL的标号从1开始递增

     > 示例输入：
     >
     > `.MODEL 1 VT -0.75 MU 5e-2 COX 0.3e-4 LAMBDA 0.05 CJ0 4.0e-14`
     > `.MODEL 2 VT 0.83 MU 1.5e-1 COX 0.3e-4 LAMBDA 0.05 CJ0 4.0e-14`

2. 修改Top_module中的filename，在 MATLAB 中运行 `Top_module.m` 脚本得到结果

## 电路网表文件格式

电路网表文件是一个文本文件，格式如下：

要求，文件中`D, M, R, V, C, L, .`都是关键字，在给电阻电容电感命名的时候最好不要使用，避免被错误索引

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
.MODEL 2 VT 0.83 MU 1.5e-1 COX 0.3e-4 LAMBDA 0.05 CJ0 4.0e-14

.dc
.end
```

## 项目的结构

```bash
├── picture # README文档的说明图片
├── projectfile # 项目要求文档
│   ├── HSPICE简明教程(复旦大学).pdf
│   ├── proj1_v02_tj.pdf		
├── testfile # 测试文件目录
│   ├── inverter.sp       		
│   ├── buffer.sp         	
│   ├── lc_filter.sp       	
│   └── amplifier.sp       	
├── Top_module.m
├── parse_netlist.m
├──
├──
├──
├── README.md # 项目说明文件
```

## 项目使用的示例文件

按照标准的电路网表文件进行输入产生电路，然后选择需要查看的端口或者器件的数据信息，选择 DC 或者瞬态仿真或者频率响应分析然后可以得到仿真的图像和数据结果。

## 项目细节介绍

#### 项目顶层文件与接口的定义

此部分由郑志宇同学维护，接口与功能与小组成员共同商议确定。最终实现了项目的并行推进与项目成员的独立维护。

├── Top_module.m

##### 顶层的实现

```matlab
%% 项目的顶层模块，用于实现整个项目的仿真流程
% 此文件为项目搭建的顶层架构，用于梳理和切割项目实现的功能并实现模块化
%% 读取文件，预处理阶段
filename = 'testfile\bufferSweep.sp';
%% 网表的解析
parse_netlist;
%% 生成线性网表
Generate_DCnetlist;
%% 根据读到的操作选择执行任务的分支
switch lower(SPICEOperation{1}{1})
    case '.dcsweep'
    %% DCSEWEEP操作的流程
    case '.hb'
    %% AC分析的流程
    case '.trans'
    %% 瞬态仿真的流程
    case '.dc'
    %% DC分析的流程
end

```

#### 顶层模块的流程

顶层模块遵循可读性高，流程清晰的原则进行书写。我们的基本思路是：

- 读取电路文件网表，根据网表文件读取并处理信息
- 对读取到的信息进行预处理，得到迭代所需要的网表
- 针对不同的SPICE操作进行处理，迭代得到电路的解
- 对电路的解进行输出

### Part 1 实现电路文件的读取与解析建立矩阵方程

#### 电路文件的信息提取

此功能由郑志宇同学完成

├── parse_netlist.m

##### 函数定义

```matlab
function [RCLINFO, SourceINFO, MOSINFO, DIODEINFO,...
PLOT, SPICEOperation] = parse_netlist(filename);
```

函数完成解析sp文件并提取出有效信息的功能，为后面功能的实现做铺垫。

##### 接口说明

`RCLINFO`：电阻，电容，电感的信息

```matlab
RCLINFO={RLCName,RLCN1,RLCN2,RLCValue};
```

`SourceINFO`：电源的信息

```matlab
SourceINFO={SourceName,SourceN1,SourceN2,...
Sourcetype,SourceDcValue,SourceAcValue,...
SourceFreq,SourcePhase};
```

`MOSINFO`：MOS管的信息

```matlab
MOSINFO={MOSName,MOSN1,MOSN2,MOSN3,...
MOStype,MOSW,MOSL,MOSID,MOSMODEL};
```

`DIODEINFO`：二极管的信息

```matlab
DIODEINFO={Diodes,DiodeN1,DiodeN2,DiodeID,DIODEModel};
```

`PLOT`：需要进行绘图的信息

`SPICEOperation`：电路所需要进行的操作

##### 技术细节

本部分使用了哈希表来装参数作为接口在函数中传递，加快了运行的速度，提高运行效率。文件主要使用正则表达式在文件中提取和匹配有效的信息并将有效信息打包给其他环节进行处理。这一部分在项目的开始阶段进行，为项目的实现搭建了一个整体的框架，同时定义了输入与输出的接口要求，以便于团队合作化工作以及推进。

#### 节点映射
——zrc

#### 电路初始解的生成
此功能由张润洲同学完成

在对非线性电路进行瞬态仿真或AC仿真之前，一般需要先进行DC仿真。线性电路的DC分析可以直接通过求解矩阵方程得到结果，而非线性电路的DC分析等同于求解超越方程组，需要为程序提供一组各个待求变量的初始解，程序以这组初值为基础开始数值迭代运算。如果没有为非线性电路提供初始解，或初始解估计不准，则会导致DC分析的计算时间增加，甚至会解出不合适的解 (比如SRAM单元、环形振荡器等多稳态电路)

给出电路初始解的思路可以分为手工进行DC分析和自动化给定初始解等。手工进行DC分析需要将L的初始电流、C的初始电压、MOS管、二极管、双极型晶体管等器件的初始电压设置为手工分析得到的直流解。或者将上述电流、电压量设置为一个较为合理的猜测的值再进行DC分析，这样做手工分析的工作量有所减少，但初始解同样不是自动化给出的

本项目选用自动化给定初始解的方法，采用程序init_value.m给定初始解。得到初始解后，Generate_DCnetlist函数利用初始解生成第1次NR迭代前伴随器件应“贴”入MNA方程的值 (MOS管、二极管、双极型晶体管分别对应3个、2个、6个伴随器件)，Gen_baseA函数将所有非伴随器件的值贴入MNA方程，之后每轮迭代调用一次Gen_nextRes函数将这一轮迭代的伴随器件值贴入MNA方程，直至迭代完成

##### 初始解赋值思路

本项目计算初始解的思路如下：

1. 找**源极接Gnd的NMOS管 (源极接Vdd的PMOS管)**，如果MOS管的节点已赋过值 (在NodeInfo中查找到的value为正值，不为-1) 则跳过该节点，否则为这些MOS管的源极电压赋值为0或Vdd，|Vgs|赋为Vdd *  2/3, |Vds|赋为Vdd / 2

   找**发射极接Gnd的npn型BJT管 (发射极接Vcc的pnp型BJT管)**，如果BJT管的节点已赋过值 (在NodeInfo中查找到的value为正值，不为-1) 则跳过该节点，否则为这些BJT管的发射极电压赋值为0或Vcc，|Vbe|赋为0.6667V，|Vce|赋为0.5V

2. 找**源极未连接Gnd的NMOS管 (源极未连接Vdd的PMOS管)**，如果MOS管的节点已赋过值则跳过该节点，否则和上述MOS管赋一样的|Vgs|和|Vds|

   找**发射极未连接Gnd的npn型BJT管 (发射极未连接Vcc的pnp型BJT管)**，如果BJT管的节点已赋过值则跳过该节点，否则和上述BJT管赋一样的|Vbe|和|Vce|

3. 找**直流电压源**，如果电压源的2个节点已赋过值则跳过该器件；如果电压源与Gnd或Vdd (Vcc) 相连，或者电压源的1个节点已赋过值，将另1个节点赋值以使得器件两端电压为电压源的直流电压值 (该值可以从DeviceInfo元胞数组中查到)；如果电压源的2个节点都未赋值，将电压源的第2个节点电压赋为0，将第1个节点电压赋为电压源的直流电压值
4. 找**有节点接Gnd的其他非NMOS非npn型BJT器件** (均为二端器件)，如果该器件的另1节点未连接Vdd，则先赋值为0
5. 找**有节点接Vdd的其他非PMOS非pnp型BJT器件** (均为二端器件)，将该器件的另1节点赋值为Vdd
6. 其他器件的节点如果没有赋过初值，则赋电压为Vdd/2

##### init_value函数输入输出

```matlab
function [x_0] = init_value(NodeInfo, DeviceInfo, Vdd, Vdd_node, Gnd_node)
```

init_value函数采用2重循环，先遍历各个器件，再遍历每个器件的各个节点。遍历器件需要DeviceInfo元胞数组的信息，遍历器件节点并赋节点电压初始值时需要NodeInfo元胞数组的信息

`DeviceInfo`：存储电路器件信息的cell

DeviceInfo元胞数组是在Generate_DCnetlist.m中通过调用Gen_DeviceInfo函数赋值的，Gen_DeviceInfo函数的定义如下：

```matlab
function [DeviceInfo] = Gen_DeviceInfo(RLCName,RLCN1,RLCN2,...
    SourceName,SourceN1,SourceN2,SourceDcValue,...
    MOSName,MOSN1,MOSN2,MOSN3,MOStype,...
    DiodeName,DiodeN1,DiodeN2,...
    BJTName,BJTN1,BJTN2,BJTN3,BJTtype)
```

以添加直流源为例，其他器件添加信息的区别只有Device.value不用赋值。

`NodeInfo`：存储电路节点信息的cell

NodeInfo元胞数组是在Generate_DCnetlist.m中通过调用Gen_NodeInfo函数赋值的。

将DeviceInfo中的各器件相连节点以其在NodeInfo中的索引值替换。同时，在NodeInfo中添加各节点相连器件信息。

`zp`：节点电压初始解向量

初始解函数只需要给出节点电压初始值，不需要为MNA方程中的电流变量提供初值后续迭代也可以收敛。

##### init_value函数细节

init_value函数采用2重循环，先遍历各个器件，再遍历每个器件的各个节点，按照上述初始解赋值思路为各个节点赋值。以找源极接Gnd的NMOS和发射极接Gnd的npn型BJT的部分为例，寻找其他器件的代码同样在内层循环中。

##### init_value函数备注

1. 计算初始解的函数认为，电路网表文件中的第一个直流电压源是Vdd (Vcc)
2. 初始解只能尽量满足各个器件的节点电压赋值要求 (包括MOS管的|Vgs|与|Vds|，电压源的两端节点电压等)

##### 初始解可能的优化方法

1. 采用瞬态分析得到初始解

   可以将直流分析的输入电压源视为具有较长上升时间的斜坡输入信号，将所有节点电压初始化为零后进行1次瞬态分析。使用本次瞬态分析结束时刻的解作为DC分析的初始解。通过这种方法得到的初始解准确，同时可以直接根据瞬态分析得到的初始解判断输入电路是否合理，但瞬态分析需要将L、C计入，算法复杂度较高，而DC分析中L、C都得到了简化，求解初始解的时间相对整个DC分析过程占比较大

2. 采用随机初始解

   通过大量随机初始解可以测得几组可能的收敛解，从中选出合理的收敛解。这种方法得到也能得到更准确的DC分析结果，通过多次运行DC分析避免了对初始解的依赖，但多次运行DC算法复杂度高；同时还需要从多组解中人工选出合理的解，没有完全实现初始解的自动化给定
   
#### 器件替换为dc分析网表形式
——zrc

#### 矩阵方程的建立

此功能由郑志宇、林与正同学完成，郑志宇同学写好了初版的线性电路矩阵的生成函数，由林与正同学运用到迭代中去

├── Gen_baseA.m

├── Gen_nextA.m

##### 函数定义

```matlab
%% 处理网表中的所有线性器件生成A、b
function [A,x,b] = Gen_baseA(Name, N1, N2, dependence, Value)
function [A, b] = Gen_nextA(pureA, pureb, Name, N1, N2, dependence, Value)
```

函数接受一个处理好的线性网表的参数，并生成电路的MNA方程

##### 接口说明

`A`：电路矩阵方程，用于求解电路以及迭代

`x`：解空间的命名，用于索引

`b`：`Ax=b`，MNA方程的右边部分

`Name`：器件名

`N1，N2`：线性器件的端口

`dependence`：器件的依赖，用于受控源

`Value`：线性器件的的参数

##### 技术细节

**函数实现了计算所有线性元件电路的方法，但是对受控源的书写顺序有一定的要求。即受到依赖的电路元件下标应该小于依赖这一元件的电路元件的下标，防止受控电流源找不到依赖的器件电流。**

`I、V、R - 基本的线性电路元件`

`压控电压源 (VCVS) - E`

`压控电流源 (VCCS) - G`

`流控电压源 (CCVS) - H`

`流控电流源 (CCCS) - F`

含有MOS管的电路中只用到了`(VCCS) - G`压控电流源

含有二极管的电路同理

### Part 2 迭代求解电路的直流工作点

### Part 3 实现trans仿真

### Part 4 实现频率响应分析

### Part 5 将电路生成的结果输出

#### `.dc`中输出结果

此功能由郑志宇同学完成

├── portMapping.m

├── ValueCalc.m

##### 函数定义

```matlab
function [plotnv,plotCurrent] = portMapping(PLOT,Node_Map)
function [Obj, res] = ValueCalc(plotnv, plotCurrent, ...
		DCres,x_0, Node_Map, LinerNet, MOSINFO, DIODEINFO)
```

##### 接口说明

`PLOT`：文件中希望绘制的结果信息

`Node_Map`：在前面节点映射的结果

`plotnv, plotCurrent`：电压电流的绘制信息

##### 技术细节

如果想要看一个节点的电压或者某个器件节点的电流在dc中的结果，应该在文件中这样书写：

```css
* dc
.plotnv <node>
.dc

* dcsweep
Vin <node1> <node2> DC <Value>
.plotnv <node>
.dcsweep Vin [1,3] <step>
```

`ValueCalc`利用迭代计算的结果以及端口映射的结果找到正确的计算值然后返回。



## 项目测试用例

### `.dc`/`.dcsweep`测试用例

#### DC测试用例1 `Amplifier.sp`

此测试文件由郑志宇同学提供

##### 网表文件

```css
* Amplifier
VDD 10 0 DC 3
Vin 13 0 DC 0

Rin 13 12 10

Rout 16 0 1000

VB1 18 0 DC 1.5
VB2 17 0 DC 1.5 

M1   15 10 10 p 30e-6 0.35e-6 1
M2   16 17 15 p 60e-6 0.35e-6 1
M3   16 18 11 n 20e-6 0.35e-6 2
M4   11 12 0  n 10e-6 0.35e-6 2

.MODEL 1 VT -0.75 MU 5e-2 COX 0.3e-4 LAMBDA 0.05 CJ0 4.0e-14
.MODEL 2 VT 0.83 MU 1.5e-1 COX 0.3e-4 LAMBDA 0.05 CJ0 4.0e-14

.plotnv 12
.plotnv 16


.dcsweep Vin [0,3] 0.01
```

##### 电路图

<img src="picture/Amplifier.png" alt="电路图" style="zoom:50%;" />

#### 运行结果
#### DC测试用例2 `bufferSweep.sp`

测试文件由课程提供的文件提供并基于小组项目进行修改

##### 电路网表

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
.MODEL 2 VT 0.83 MU 1.5e-1 COX 0.3e-4 LAMBDA 0.05 CJ0 4.0e-14

.PLOTNV 102
.PLOTNV 107
.PLOTNV 118

.plotnc M1(d)
.plotnc M3(d)
.plotnc R3(+)

.dcsweep Vin [0,3] 0.01
```

##### 电路图

<img src="picture\buffer.png" alt="image-20230504151356355" style="zoom:50%;" />

##### 测试结果图

<img src="picture\buffer_102.png" alt="转移特性" style="zoom:50%;" />

<img src="picture\buffer_M1_d.png" alt="转移特性" style="zoom:50%;" />

<img src="picture\buffer_M3_d.png" alt="转移特性" style="zoom:50%;" />

<img src="picture\buffer_107.png" alt="转移特性" style="zoom:50%;" />

<img src="picture\buffer_118.png" alt="转移特性" style="zoom:50%;" />

结果基本符合预期，DC扫描的结果验证正确。

#### DC测试用例3 `invertbuffer.sp`

测试文件由郑志宇同学提供

##### 测试网表

```css
* invertbuffer
VDD 103 0 DC 3
Vin 101 0 DC 1.5
Rin 101 107 10

M1 104 107 0 n 20e-6 0.35e-6 2
M2 104 107 103 p 60e-6 0.35e-6 1

C1 104 0 0.1e-12
R2 104 115 25
L1 115 116 0.5e-12
C2 116 0 0.5e-12
R3 116 117 35
L2 117 118 0.5e-12
C3 118 0 1e-12

.MODEL 1 VT -0.75 MU 5e-2 COX 0.3e-4 LAMBDA 0.05 CJ0 4.0e-14
.MODEL 2 VT 0.83 MU 1.5e-1 COX 0.3e-4 LAMBDA 0.05 CJ0 4.0e-14

.PLOTNV 104
.PLOTNV 118
.plotnc M1(d)
.dcsweep Vin [0,3] 0.01
```

##### 电路图

<img src="picture\invertbuffer.png" alt="反相器" style="zoom:50%;" />

##### 运行结果

<img src="picture\invertbuffer_M1_d.png" alt="转移特性" style="zoom:50%;" />

<img src="picture\invertbuffer_118.png" alt="转移特性" style="zoom:50%;" />

#### DC测试用例4`test circuit`

测试文件由林与正同学提供

##### 测试网表

```css
* A test circuit 

VDD 101 1 DC 3
Vb 111 0 DC 1
Rload1 104 0 10
Rload2 105 0 10

* mosfet
M1 102 112 121 n 30e-6 .5e-6 2
M2 103 112 121 n 30e-6 .5e-6 1
M3 102 111 101 p 90e-6 .5e-6 4
M4 103 111 101 p 90e-6 .5e-6 3

* diode 
D1 104 102 1
D2 103 105 1

* input 
VIN 112 0 1
Iref 121 0 0.001

RSS 121 0 100

* level 1 models
.MODEL 1 VT 0.5 MU 3e-2 COX 6e-3 LAMBDA 0.05 CJ0 4.0e-14
.MODEL 2 VT 0.3 MU 3e-2 COX 6e-3 LAMBDA 0.05 CJ0 4.0e-14
.MODEL 3 VT -0.5 MU 1e-2 COX 6e-3 LAMBDA 0.05 CJ0 4.0e-14
.MODEL 4 VT -0.3 MU 1e-2 COX 6e-3 LAMBDA 0.05 CJ0 4.0e-14

* diode models
.DIODE 1 IS 1e-3

.plotnv  102
.plotnv  103 
.plotnv  104
.plotnv  105
.plotnv  121
.plotnc  D1(+)
.plotnc  M4(d)
.plotnc  R2(+)
.end
```

##### 电路图

##### 运行结果

## 结束语

要注意，我们的项目的仿真工具实现的只是一个较为简单的功能，部分地方细节并不完善，考虑也有欠妥的地方，还有不少改善空间。巴拉巴拉
