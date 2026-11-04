# MoonHermetic 项目方案

## 一句话介绍

MoonHermetic 是一个用 MoonBit 编写的测试隐式依赖静态审计器，在跨平台 CI
运行之前找出会读取本机时间、环境变量、网络、随机数、文件或 sleep 的测试。

## 要解决的真实问题

MoonBit 支持 Wasm、Wasm-GC、JavaScript 和 Native 多后端，同一套测试理应能在
不同机器上稳定运行。但测试只要隐式读取了宿主状态，就可能出现“本地通过、CI
失败”或“今天通过、明天失败”的情况。现有运行时 flake 分析通常要等失败发生，
MoonHermetic 则把问题提前暴露在代码审查阶段。

## 用户与使用场景

- MoonBit 库作者：发布前检查新增测试是否破坏跨机器可复现性。
- MoonBit 应用团队：在 Pull Request 中阻止依赖真实网络或宿主机器的测试。
- 测试维护者：获得具体到文件、行、列的修复建议，而不是笼统的失败分数。

## 差异化

Mooncakes 上已有 API 兼容、供应链、WASM 体积、变异测试和运行时 flake
工具。MoonHermetic 的边界是“测试源码中的环境隐式依赖”：

- 不比较 `.mbti` 公共接口。
- 不生成 SBOM，也不判断依赖漏洞。
- 不通过历史失败率猜哪个测试 flaky。
- 不改写测试，只指出应该注入、替换或隔离的边界。

## MVP

当前 MVP 已具备：

- 7 类规则：Clock、Random、Environment、Network、Process、Filesystem、Sleep。
- 注释、字符串、字符、块注释和快照内容屏蔽，减少假阳性。
- 文件、行、列和原始证据定位。
- `hermetic:ignore` 与 `hermetic:ignore-next` 局部豁免。
- Text、JSON、Markdown、SARIF 2.1.0 输出。
- 可配置 CI 失败阈值。
- 通过 `.moonhermetic.json` 按规则关闭、调整严重级别并设置排除路径。
- 单元测试和安全/风险示例。

## 一个月迭代计划

1. 第 1 周：在 10 个以上公开 MoonBit 仓库上做精度测试，建立真实 fixture。
2. 第 2 周：加入 `.moonhermetic.json` 规则配置和过期豁免策略。
3. 第 3 周：实现 diff-aware PR 模式，只报告修改行引入的风险。
4. 第 4 周：发布 Windows/Linux/macOS 二进制、可复用 GitHub Action 和
   Mooncakes 包。

## 演示脚本

```bash
moon run cmd/main -- examples/risky
```

预期结果：报告 `HERM-CLOCK`、`HERM-NET`、`HERM-SLEEP`，并以状态码 1 退出。

```bash
moon run cmd/main -- examples/safe --fail-on warning
```

预期结果：状态码 0，证明工具不会因为测试文件存在就无条件报错。

```bash
moon run cmd/main -- examples/risky --format sarif --fail-on never
```

预期结果：生成可导入 GitHub Code Scanning 的 SARIF 2.1.0。

## 验收证据

- `moon check --deny-warn` 通过。
- `moon test` 全部通过。
- 风险 fixture 与安全 fixture 的退出码分别为 1 和 0。
- JSON 与 SARIF 均通过结构化解析。
- README 提供完整安装、规则、豁免和 CI 使用方法。

## 可解释使用 AI 的声明

AI 可用于代码生成、重构、测试用例设计和文档校对，但项目边界、规则取舍、
误报处理和最终代码均需由参赛者理解并负责。仓库的测试与 fixture 应保留完整
提交历史，并在最终提交中说明 AI 实际参与环节。
