# Godot 项目命名规则

适用于 Godot 4.x 项目。以下约定以 GDScript 为主，使用 C# 的项目可参照文末的补充规则。

## 文件和目录

目录和资源文件名使用小写英文和下划线（`snake_case`）。用完整单词表达用途，避免空格、含义不清的缩写和 `new`、`final` 等版本后缀。

| 对象 | 命名规则 | 示例 |
| --- | --- | --- |
| 目录 | 按功能或资源用途命名 | `characters/`、`inventory/`、`ui/` |
| 场景 | 使用场景代表的对象或界面名称 | `player.tscn`、`pause_menu.tscn` |
| GDScript 脚本 | 使用职责名称；场景主脚本通常与场景同名 | `player.gd`、`health_component.gd` |
| 资源 | 描述用途；同类资产较多时加上类型或用途后缀 | `iron_sword.tres`、`stone_albedo.png`、`door_open.ogg` |
| 编号资产 | 同系列使用统一位数 | `level_01.tscn`、`level_02.tscn` |

例外：`docs/` 下的设计文档用中文主题名（如 `docs/战斗系统.md`），不受 `snake_case` 约束，因为它们是给人读的索引目标，不是引擎资源。文档目录结构见 `docs/Git协作指南.md` 的“文档维护”。

## 场景和节点

- 节点名使用 `PascalCase`，优先表达职责，例如 `Player`、`HealthBar`、`Hitbox`。保留 `Timer` 等已经足够明确的默认名称，有多个同类节点时使用 `AttackCooldown`、`RespawnTimer` 等语义名称。
- 场景根节点通常与场景文件同义，例如 `pause_menu.tscn` 的根节点命名为 `PauseMenu`。实例节点按所在场景中的职责命名，例如两个相同传感器可分别命名为 `LeftSensor` 和 `RightSensor`。
- Autoload 名称使用 `PascalCase`，例如将 `audio_manager.gd` 注册为 `AudioManager`。Autoload 名称与全局 `class_name` 使用不同的标识符，避免冲突。

## GDScript 标识符

| 对象 | 命名规则 | 示例 |
| --- | --- | --- |
| 全局类和内部类 | `PascalCase`，使用名词 | `class_name HealthComponent` |
| 函数 | `snake_case`，优先使用动词 | `apply_damage()`、`open_menu()` |
| 变量、参数和导出属性 | `snake_case`，表达含义 | `current_health`、`damage_amount`、`move_speed` |
| 内部成员和方法 | 以下划线开头，表示内部使用 | `_elapsed_time`、`_refresh_view()` |
| 布尔值 | 使用可读的判断词 | `is_grounded`、`has_key`、`can_jump` |
| 常量 | `UPPER_SNAKE_CASE` | `MAX_HEALTH`、`DEFAULT_MOVE_SPEED` |
| 枚举名与枚举值 | 枚举名用 `PascalCase`，值用 `UPPER_SNAKE_CASE` | `enum MovementState { IDLE, RUNNING }` |
| 信号 | `snake_case`，描述已经发生的事件 | `health_changed`、`item_added`、`died` |
| 信号回调 | 使用 `_on_<来源>_<信号>`，来源转为 `snake_case` | `_on_retry_button_pressed()` |

重写引擎回调时保留 Godot 定义的名称，例如 `_ready()`、`_process(delta)` 和 `_physics_process(delta)`。

## 项目内的字符串标识符

- 输入动作使用 `snake_case`，按游戏中的动作命名，例如 `move_left`、`jump`、`interact`。自定义动作避免占用 Godot 内置动作的 `ui_` 前缀。
- 节点组使用 `snake_case`，优先用复数名词表示成员集合，例如 `enemies`、`save_points`。
- 动画使用 `snake_case`，例如 `idle`、`run`、`attack_heavy`。引用时保持与编辑器中的名称及大小写一致。
- 自定义项目设置使用 `分类/设置名`，每段采用 `snake_case`，例如 `gameplay/combat/default_damage`。

## C# 补充

C# 脚本文件使用 `PascalCase`，文件名与 Godot 脚本类同名，例如 `PlayerController.cs` 对应 `PlayerController`。类型、方法、公开属性和事件使用 `PascalCase`，局部变量和参数使用 `camelCase`，私有字段可使用 `_camelCase`。使用 `[Signal]` 声明信号时，委托名称以 `EventHandler` 结尾，例如 `HealthChangedEventHandler`。

## 重命名

优先在 Godot 的 FileSystem 面板中移动或重命名场景和资源。操作后检查代码中写死的 `res://` 路径、节点路径、组名、输入动作，以及 Autoload 和信号连接。仅修改文件名大小写时，建议先改成临时名称，再改为目标名称，并确认 Git 识别了变更。
