# 2026年11月6日离线回归

Run `tools/validate_release_repairs.py` with the bundled/local Python. It copies source-only suites into a new ignored .validation directory, compiles standalone helpers and runs only controlled fixtures. Game/Workshop resources are read only. UI/world startup, game automation and deployment are excluded.

使用本地Python执行 `tools/validate_release_repairs.py`；测试资料被复制到新的隔离.validation目录。只编译独立工具和运行受控对象，仅读取游戏及工坊资源；不启动游戏、不部署。实际游戏与UI由用户验收。

Historical paths embedded in the archived suite sources are adapted by the runner in scratch only. Raw game/PZO/Workshop classes and full upstream Lua files are never copied into this repository. Public test source comprises original stubs, assertions, harnesses and bytecode extraction instructions.
