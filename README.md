# Watch

[2026开源游戏开发大赛](https://2026gamejam.osgame.org/) 参赛作品。一款卡牌肉鸽游戏，核心机制是 **序列**：资源限制不是费用，而是出牌的顺序——攻防牌按顺序堆叠成序列，特殊牌消耗序列片段来触发效果。

## 当前状态

| 系统 | 状态 | 代码位置 | 文档 |
| --- | --- | --- | --- |
| 地图与崩解度 | 已实现，可运行 | `map/` | [docs/地图系统.md](docs/地图系统.md) |
| 战斗（序列、牌堆、效果） | 核心规则已实现，`base_fight.tscn` 可单独运行，未接入地图 | `cards/` `effect/` `fight/` | [docs/战斗系统.md](docs/战斗系统.md) |
| 敌人 | 机制已实现（状态机 + 意图），内容未设计 | `character/` | [docs/敌人与Boss.md](docs/敌人与Boss.md) |
| 商店 | 数据结构已定义，UI 与结算未接入 | `map/content/` | [docs/商店系统.md](docs/商店系统.md) |
| 事件 | 数据结构已定义，3 个示例事件，UI 未接入 | `map/content/` `map/res/data/events/` | [docs/事件系统.md](docs/事件系统.md) |
| 收集品 | 未开始 | — | [docs/收集品与局外养成.md](docs/收集品与局外养成.md) |
| 局外养成与存档 | 未开始 | — | [docs/收集品与局外养成.md](docs/收集品与局外养成.md) |
| 主题与叙事 | 文案草案（六个极端度阶段、三个 Boss） | — | [docs/主题与叙事.md](docs/主题与叙事.md) |

美术、音效、文案与数值的缺口汇总在 [docs/资源需求.md](docs/资源需求.md)；现在每个数是多少、在哪改、有没有生效，查 [docs/数值表.md](docs/数值表.md)。

## 待办事项

> 协作者请按照 [IDEA.md](IDEA.md) 的记载完成如下事项。完成一项就把 `[ ]` 改成 `[x]`，并在后面注明分支。

### 代码

* [x] 卡牌、序列与基础战斗逻辑（`cards/`，原型可运行） <- XiaoMuSWW
* [x] 地图系统，包括事件、战斗等节点与崩解度机制 <- chen-craftm,之后XiaoMuSWW全面优化
* [ ] 战斗接入地图（`RunState.fight_system` 已留入口）
* [ ] 三幕结构与 Boss 顺序随机（见 `docs/地图系统.md`）
* [ ] 战斗胜负结算与金币奖励
* [ ] 商店 UI 与结算
* [ ] 事件 UI 与卡组类结算
* [ ] 收集品系统 <- 宇宙霸主（XiaoMuSWW）在此，见开发分支 develop_usomf
* [ ] 人物系统设计 <- 宇宙霸主（XiaoMuSWW）在此，见开发分支 develop_usomf
* [ ] 敌人设计（血量、行为表、数值）<- 宇宙霸主（XiaoMuSWW）——在此，见开发分支 develop_usomf
* [ ] 局外养成与存档
* [ ] 后续事项待补充

### 剧情

emm....少女折寿中

### 美术

emm....少女折寿中

## 环境

- Godot **4.7**（`Forward Plus`，已启用 .NET / C# 程序集 `Watch`）。
- 脚本以 GDScript 为主。
- 用 Godot 编辑器打开 `project.godot` 即可运行。

## 目录结构

| 路径 | 说明 |
| --- | --- |
| `cards/` | 卡牌、卡组、序列与卡牌 UI |
| `character/` | 角色、敌人、行动状态与血条 |
| `effect/` | 卡牌效果资源（伤害、护甲、抽牌、伤害抵消） |
| `fight/` | 战斗场景、战斗阶段与效果结算 |
| `map/` | 地图生成、节点、内容资源与地图界面 |
| `run/` | 单局状态（种子、配置、生命、金币） |
| `components/` | 通用组件（网格生成、种子生成、地形噪声） |
| `ui/` | 开始菜单、设置、确认弹窗、字体与主题 |
| `shaders/` | 通用着色器与光照 |
| `docs/` | 设计文档、协作与命名规范 |
| `project.godot` | Godot 项目配置 |

## 文档

开工前请先读一遍**Git协作指南**与**Godot项目命名规则**，两者是本仓库的强制约定。设计文档按子系统分册，改机制时同步改对应分册。

| 文档 | 内容 |
| --- | --- |
| [docs/Git协作指南.md](docs/Git协作指南.md) | **分支结构、提交规范、冲突处理与 Pull Request 流程** |
| [docs/Godot项目命名规则.md](docs/Godot项目命名规则.md) | **文件目录、场景节点、脚本标识符与重命名约定** |
| [IDEA.md](IDEA.md) | 八个机制方向，每个一到三句，链接到分册 |
| [docs/战斗系统.md](docs/战斗系统.md) | 术语对照、序列规则、卡牌数据、牌堆、格挡、效果系统、回合流程 |
| [docs/敌人与Boss.md](docs/敌人与Boss.md) | 敌人状态机、小怪与 Boss 设计草案、设计缺口 |
| [docs/地图系统.md](docs/地图系统.md) | 六边形节点网络、幕与 Boss、崩解度、节点类型、渲染与调试 |
| [docs/商店系统.md](docs/商店系统.md) | 商店服务、金币来源、商人台词需求 |
| [docs/事件系统.md](docs/事件系统.md) | 六类事件、结算数据、与卡组的耦合缺口 |
| [docs/收集品与局外养成.md](docs/收集品与局外养成.md) | 收集品数据与触发点、局外评价与解锁 |
| [docs/主题与叙事.md](docs/主题与叙事.md) | 世界设定、智慧个体、六个极端度阶段 |
| [docs/资源需求.md](docs/资源需求.md) | 文案、美术、音效、数值需求与阻塞项 |
| [docs/数值表.md](docs/数值表.md) | 各项当前值、生效位置、目标值，以及配了但不生效的项 |

## 字体与致谢

游戏界面与地图地点标签默认使用 [Fusion Pixel Font（缝合像素字体）](https://github.com/TakWolf/fusion-pixel-font)，采用 [2026.11.10 发行版](https://github.com/TakWolf/fusion-pixel-font/releases/tag/2026.11.10)的 12 px 比例简体中文 OTF。字体按 [SIL Open Font License 1.1](ui/fonts/LICENSE-OFL) 随项目分发。

感谢 TakWolf 和 Fusion Pixel Font 的贡献者维护这套开源字体。
