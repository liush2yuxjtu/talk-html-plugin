# 模型越来越聪明，公司为什么没变快？

> Source Airtable record: `recrxe7yqyc8ylK6r`
> Version: `v1-html-derived`
> Status: RedNote derived draft, not published

我最近一直在想一个问题：

模型能力明明在指数增长，为什么很多公司的效率看起来还是线性的？

我现在觉得，中间其实少了两层东西。

第一层：Done Right。

很多 Agent 的做法还是：
找个便宜模型 → 让它自己理解 → 自己执行 → 自己检查 → 错了 retry。

这很像让同一个学生自己出题、自己答题、最后自己判卷。最危险的不是它答错，而是它能非常自洽地认为自己答对了。

我现在更喜欢拆成 3 个角色：

最强模型做 Advisor。
它先看完整上下文，定义 acceptance criteria，告诉系统“什么叫做对”，顺便决定这个任务最多值得花多少钱。

便宜模型做 Executor。
它只负责真正执行。

最后放一个上下文隔离的 Checker。
它不继承 Executor 的大段 reasoning，只看目标、验收标准和真实 evidence，然后给 PASS / FAIL。

这时候我关心的也不再是 cost per token，而是：

cost per accepted task。

一个便宜模型如果 retry 5 次、中间打断人 3 次、最后还要工程师重新检查，它一点都不便宜。

但做到这里还不够。

第二层：Ship to Production。

假设 Claude Code 在我的 Mac 上已经把一件事做对了：
Prompt 有了，Skills 有了，Tools 接好了，Harness / Evals 也过了。

但如果每次还要我打开电脑、开 terminal、手动贴任务、盯着它跑，那它仍然只是一个很好用的 prototype。

企业真正需要的是把“一次做对”打包成一个可复制单元：

Input Contract
→ Skills / Tools
→ Harness / Evals
→ Permissions / Secrets
→ State
→ Budget / Timeout
→ Evidence

然后交给 runtime：

Queue
→ 启动隔离 Worker
→ 执行
→ 自动验收
→ 失败重试 / 升级模型
→ 保存 evidence
→ 销毁 Worker

本地一个成功的 Agent，应该能复制成云端 10 个、100 个、1000 个遵守同一 contract 的 worker。

这很像 Cloud Computing。

CPU 越来越快，不等于你自动拥有一个能服务一亿用户的互联网公司。中间还需要虚拟化、调度、部署、监控、权限、存储和故障恢复。

模型也一样。

Model 是新的 CPU。
Harness + Runtime，才更像 Agent 时代的 Cloud Layer。

所以我现在会写成：

AI Output
≈ Model Intelligence × Reliability × Replication

模型再聪明，如果 Reliability 很低，每个任务都要人盯；
或者 Replication 很低，一个做对的 Agent 只能活在某个人电脑里；
企业得到的增长当然还是线性的。

我之前写：
Prompt 解决说法。
Context 解决信息。
Harness 解决行为。

现在再补一句：

Runtime 解决规模。

真正的问题可能已经不是“下一个模型能不能再聪明 20%”，而是：你有没有办法把一次做对，稳定复制到 production？
