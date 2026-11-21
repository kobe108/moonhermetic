# MoonHermetic 验收演示脚本

建议录制 3–5 分钟。全程使用仓库根目录，并在开始前运行一次：

```powershell
pwsh scripts/verify-acceptance.ps1
```

确认最后输出 `ACCEPTANCE PASSED`，再开始录制。

## 1. 介绍问题

说明 MoonBit 测试可能隐式读取时间、随机数、环境变量、网络、子进程、文件或
sleep。MoonHermetic 在测试运行前给出具体源码位置、所属测试和调用链。

强调它不替代运行测试，也不猜测历史 flaky 分数。

## 2. 展示跨文件调用链

```powershell
moon run cmd/main -- examples/semantic/cross_file --no-config --fail-on never
```

预期只报告 `request.mbt` 中的环境变量访问，并显示：

```text
cross-file request reads an ambient token
  -> prepare_request
  -> read_ambient_token
```

说明同一文件中的未使用网络 helper 没有报告，因为测试不可达。

## 3. 对比旧式整文件扫描

```powershell
moon run cmd/main -- examples/semantic/cross_file --no-config --no-reachability --fail-on never
```

预期有两条发现：环境变量和未使用 helper 中的网络调用。与默认模式的一条发现
对比，说明基础名称扫描为什么只保留给迁移场景。

## 4. 展示 CI 格式

```powershell
moon run cmd/main -- examples/semantic/cross_file --no-config --format json --fail-on never
moon run cmd/main -- examples/semantic/cross_file --no-config --format sarif --fail-on never
```

指出 JSON 中的 `testName`、`callPath`，以及 SARIF 可直接上传 GitHub Code
Scanning。

## 5. 展示项目接入

```powershell
moon run cmd/main -- doctor . --no-config --no-baseline
```

说明 `init` 可生成配置和基线，`doctor` 检查测试发现、配置、豁免、基线和新风险。

## 6. 展示交付

打开 [v0.16.1 Release](https://github.com/kobe108/moonhermetic/releases/tag/v0.16.1)，
说明 Linux、Windows、macOS 二进制、Mooncakes ZIP 和 SHA-256 均已发布。

最后打开 GitHub Actions，展示 Linux、Windows、macOS 的 CI、Reusable Action
和 Release action smoke 均通过。

## 讲解边界

- 当前只解析同一 package 目录内未限定名称的 `fn` 调用。
- 不解析方法、动态分派、宏、生成代码和跨 package 调用。
- 规则是启发式审查信号，不是“测试一定错误”的证明。
- 明确边界比夸大完整类型检查更符合当前实现。
