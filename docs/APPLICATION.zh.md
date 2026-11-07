# MoonHermetic 黑客松项目申报书
## 一、基本信息

- 项目名称：MoonHermetic
- 参赛账号：kobe108
- 联系方式：3360944005@qq.com
- 项目仓库：https://github.com/kobe108/moonhermetic
- 项目方向：MoonBit 测试工具、静态分析与 CI 基础设施
## 二、项目摘要

- MoonHermetic 是一个使用 MoonBit 编写的测试隐式依赖静态审计器，在测试执行前发现宿主环境边界。
- 项目提供 CLI、JSON/SARIF、GitHub Action、稳定基线、项目诊断、原生二进制和 Mooncakes 发布流程。
## 三、问题与背景

- MoonBit 支持 Wasm、Wasm-GC、JavaScript 和 Native，同一测试需要跨平台稳定运行。
- 隐式读取本机状态会让测试出现“本地通过、CI 失败”或“今天通过、明天失败”。
- 现有运行时 flake 工具通常要等失败发生，缺少在代码审查阶段定位环境边界的手段。
## 四、解决方案

- 扫描 `_test.mbt` 和 `_wbtest.mbt`，输出文件、行、列、规则 ID、证据和修复建议。
- 使用注释、字符串、嵌套块注释和快照感知的掩码扫描，降低文档内容造成的误报。
- 通过配置、基线、diff、豁免治理和 CI 报告支持渐进接入与团队协作。
## 五、核心功能

- 七类规则：Clock、Random、Environment、Network、Process、Filesystem、Sleep。
- `.moonhermetic.json` 支持关闭规则、调整严重级别和排除路径。
- `init` 一条命令生成配置和首次基线；`doctor` 检查配置、基线和新增风险。
- `--baseline` 冻结历史风险并跟踪重复次数、stale 条目和新增发现。
- `--diff` 只报告 PR 修改行；支持 Text、JSON、Markdown 和 SARIF 2.1.0。
## 六、技术创新

- 基于规则、仓库相对路径和规范化源码证据生成 SHA-256 稳定指纹。
- 指纹忽略行号移动与格式空白，但保留字符串字面量语义和重复调用次数。
- 基线、diff、严重级别和抑制治理采用明确组合顺序，行为可解释、可测试。
## 七、差异与竞品

- 不比较 `.mbti` 公共接口，不生成 SBOM，也不根据历史失败率猜测 flaky 测试。
- `mizchi/flaker` 侧重运行时 flake 计算；MoonHermetic 侧重测试源码中的宿主边界。
- 与通用静态分析框架相比，规则更窄、输出更直接，并提供 MoonBit 专用修复建议。
## 八、完成度与验证

- 已发布 `v0.14.0`，包含 Linux、Windows 和 macOS 原生二进制及 SHA-256。
- 61 个 MoonBit 测试在 Native、Wasm-GC、JavaScript 三个目标通过。
- 精度基准覆盖 10 个公开仓库、531 个测试文件和 1178 条发现。
- 提供 GitHub Action、Job Summary、PR 评论、Release 和 Mooncakes 包校验流程。
## 九、应用价值

- MoonBit 库作者可检查新增测试是否破坏跨机器可复现性。
- 应用团队可在 PR 中阻止真实网络、宿主机文件和未受控随机源进入测试。
- 大型项目可通过基线和诊断工具低成本渐进接入。
## 十、开源与交付

- 代码采用 Apache-2.0 许可证，提交和标签身份为 kobe108。
- 提供 README、规则语义、精度、基线、Doctor、Action 和发布文档。
- 提供可复用 Action、二进制校验文件、Mooncakes ZIP 和自动发布工作流。
## 十一、风险与应对

- 启发式规则可能误报：通过真实仓库基准、分层抽样和人工复核持续收敛。
- 基线可能掩盖新增风险：使用次数计数、stale 报告和严格治理门禁。
- macOS 与 Windows 二进制尚未签名：发布校验值，并将签名与 notarization 列入计划。
## 十二、黑客松期间计划

- 补充真实 MoonBit 项目样本、误报回归用例和演示材料。
- 完成 Mooncakes 正式发布、Action 版本维护和稳定版发布流程。
- 增加自动诊断修复、编辑器集成和二进制签名能力。
## 十三、声明

- 本项目由参赛者持续设计、验证和迭代，AI 用于辅助代码、测试与文档工作。
- 规则取舍、误报判断、发布决策和最终交付由参赛者负责。
- 项目内容与仓库提交历史可公开接受评审和复核。
