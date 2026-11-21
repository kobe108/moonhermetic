# MoonHermetic 黑客松项目申报书
## 一、基本信息
- 项目名称：MoonHermetic
- 参赛账号：kobe108
- 联系方式：3360944005@qq.com
- 项目仓库：https://github.com/kobe108/moonhermetic
- 项目方向：MoonBit 测试工具、静态分析与 CI 基础设施

## 二、项目摘要
- MoonHermetic 是一个使用 MoonBit 编写的测试语义审计器，在测试执行前发现从测试真正可达的宿主环境边界。
- 项目结合 MoonBit 声明解析、本地调用图、边界指纹、CI 报告、诊断、原生二进制和发布流程。

## 三、问题与背景
- MoonBit 支持 Wasm、Wasm-GC、JavaScript 和 Native，同一测试需要跨平台稳定运行。
- 隐式读取本机状态会让测试出现“本地通过、CI 失败”或“今天通过、明天失败”。
- 现有运行时 flake 工具通常要等失败发生；仅按 API 名称搜索又无法区分测试可达代码与未使用 helper。

## 四、解决方案
- 解析 `test` 和同包 `fn` 的括号体，构建跨文件调用图，只分析从命名测试可达的代码。
- 掩码注释、字符串、嵌套块注释和快照后提取调用边，降低文档与示例代码造成的误报。
- 对每个可达边界输出 `test -> helper -> effect` 路径，并通过基线、diff 和 CI 报告支持团队协作。

## 五、核心功能
- 七类环境边界作为调用图叶节点：Clock、Random、Environment、Network、Process、Filesystem、Sleep。
- `.moonhermetic.json` 支持关闭规则、调整严重级别和排除路径。
- `init` 一条命令生成配置和首次基线；`doctor` 检查配置、基线和新增风险。
- `--baseline` 冻结历史风险并跟踪重复次数、stale 条目和新增发现。
- `--diff` 只报告 PR 修改行；Text、JSON、Markdown 和 SARIF 同时携带测试名与调用链。

## 六、技术创新
- 以测试声明为根、同包函数为节点构建跨文件调用图，带环检测并忽略未使用 helper。
- 边界规则作为叶节点识别，最终结果由测试可达性、作用域和边界语义共同决定。
- SHA-256 基线指纹忽略行号移动与格式空白，但保留字符串内容和重复次数。

## 七、差异与竞品
- 不比较 `.mbti` 公共接口，不生成 SBOM，也不根据历史失败率猜测 flaky 测试。
- `mizchi/flaker` 侧重运行时 flake 计算；MoonHermetic 侧重测试调用链中的宿主边界。
- 可达案例输出 `test -> prepare_request -> read_ambient_token`；未被测试调用的网络 helper 不报告。
- 当前范围明确为同一 MoonBit package 内的静态调用图，不跨 package、不处理方法或动态分派；可回退整文件扫描。

## 八、完成度与验证
- 已准备 `v0.16.0` 发布，流水线覆盖 Linux、Windows 和 macOS 原生二进制及 SHA-256。
- 74 个 MoonBit 测试在 Native、Wasm、Wasm-GC、JavaScript 四个目标通过。
- 精度基准覆盖 10 个公开仓库、531 个测试文件和 1178 条发现。
- 提供语义示例、Action、Job Summary、PR 评论、Release 和 Mooncakes 包校验流程。

## 九、应用价值
- MoonBit 库作者可检查新增测试是否破坏跨机器可复现性。
- 应用团队可在 PR 中阻止真实网络、宿主机文件和未受控随机源进入测试。
- 大型项目可通过基线和诊断工具低成本渐进接入。

## 十、开源与交付
- 代码采用 Apache-2.0 许可证，提交和标签身份为 kobe108。
- 提供 README、调用图语义、精度、基线、Doctor、Action 和发布文档。
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
