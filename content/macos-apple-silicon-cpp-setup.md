+++
title = "My Modern C++ Setup on macOS and Apple Silicon"
date = 2026-05-19
description = "Set up a modern C++ toolchain on Apple Silicon macOS with LLVM, CMake, Ninja, VS Code, Helix, and mise."
draft = false

[taxonomies]
tags = ["cpp", "macos", "apple-silicon", "llvm", "cmake", "developer-tooling"]

[extra]
keywords = "cpp, macos, apple-silicon, llvm, cmake, developer-tooling"
toc = true
static_thumbnail = "/images/social-macos-apple-silicon-cpp-setup.png"

+++

I’m starting to learn modern C++, so I wanted a repeatable development setup on Apple Silicon:

- use a modern LLVM/Clang toolchain
- build projects with CMake and Ninja
- get proper language-server support in VS Code and Helix
- use sanitizers and static analysis from the beginning
- keep the setup practical

This cheatsheet assumes that Homebrew is already installed.

<!-- more -->

## Install Xcode Command Line Tools

Install Apple’s developer tools:

```bash
xcode-select --install
```

Check that they are available:

```bash
xcode-select -p
clang --version
```

macOS includes Apple Clang. I use a newer LLVM toolchain from Homebrew.

## Install the core C++ toolchain

```bash
brew install \
  llvm \
  cmake \
  ninja \
  ccache \
  git \
  pkg-config
```

The packages include:

- `clang`
- `clang++`
- `clangd`
- `clang-format`
- `clang-tidy`
- CMake
- Ninja

Homebrew installs LLVM as a separate toolchain, so its binaries may not be in `PATH` automatically.
Check the LLVM prefix first:

```bash
brew --prefix llvm
```

On Apple Silicon, it is usually `/opt/homebrew/opt/llvm`. Then check the LLVM tools directly:

```shell
$(brew --prefix llvm)/bin/clang++ --version
$(brew --prefix llvm)/bin/clangd --version
$(brew --prefix llvm)/bin/clang-format --version
$(brew --prefix llvm)/bin/clang-tidy --version
```

Add Homebrew LLVM to the interactive shell:

```shell
echo 'export PATH="$(brew --prefix llvm)/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
rehash
```

## Recommended project structure

For a small learning project, I use this structure:

```shell
cpp-lab/
  CMakeLists.txt
  src/
    main.cpp
  tests/
    test_main.cpp
  build/
  .clang-format
  .clang-tidy
  .gitignore
```

I create it manually for now.

## Minimal modern CMake setup

I’m new to CMake, so I keep `CMakeLists.txt` minimal:

```cmake
cmake_minimum_required(VERSION 3.25)

project(cpp_lab LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_compile_options(
    -Wall
    -Wextra
    -Wpedantic
    -Wconversion
    -Wshadow
)

add_executable(cpp_lab src/main.cpp)
```

This setting generates `compile_commands.json`, which `clangd` uses to understand the project:

```cmake
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
```

For now, the project has a single executable target and no dependency management.

## Build with LLVM and Ninja

Configure:

```bash
cmake -S . -B build -G Ninja \
  -DCMAKE_C_COMPILER=/opt/homebrew/opt/llvm/bin/clang \
  -DCMAKE_CXX_COMPILER=/opt/homebrew/opt/llvm/bin/clang++ \
  -DCMAKE_BUILD_TYPE=Debug
```

Build:

```bash
cmake --build build
```

Run:

```bash
./build/cpp_lab
```

For a release build:

```bash
cmake -S . -B build-release -G Ninja \
  -DCMAKE_C_COMPILER=/opt/homebrew/opt/llvm/bin/clang \
  -DCMAKE_CXX_COMPILER=/opt/homebrew/opt/llvm/bin/clang++ \
  -DCMAKE_BUILD_TYPE=Release

cmake --build build-release
```

## Enable sanitizers early

I use AddressSanitizer for memory errors and UndefinedBehaviorSanitizer for undefined behavior:

```bash
cmake -S . -B build-asan -G Ninja \
  -DCMAKE_C_COMPILER=/opt/homebrew/opt/llvm/bin/clang \
  -DCMAKE_CXX_COMPILER=/opt/homebrew/opt/llvm/bin/clang++ \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_CXX_FLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer"

cmake --build build-asan
./build-asan/cpp_lab
```

ThreadSanitizer is also useful for concurrency code:

```bash
cmake -S . -B build-tsan -G Ninja \
  -DCMAKE_C_COMPILER=/opt/homebrew/opt/llvm/bin/clang \
  -DCMAKE_CXX_COMPILER=/opt/homebrew/opt/llvm/bin/clang++ \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_CXX_FLAGS="-fsanitize=thread -fno-omit-frame-pointer"

cmake --build build-tsan
./build-tsan/cpp_lab
```

Do not combine AddressSanitizer and ThreadSanitizer in the same build. They are incompatible, so use
separate build directories.

## Add clang-format

`clang-format` comes with LLVM and keeps the code style consistent.

My `.clang-format` uses four spaces for indentation and a 100-character line limit:

```yaml
BasedOnStyle: LLVM
IndentWidth: 4
ColumnLimit: 100
AllowShortFunctionsOnASingleLine: Empty
DerivePointerAlignment: false
PointerAlignment: Left
```

Format the source files in place:

```bash
find src tests \( -name '*.cpp' -o -name '*.hpp' \) | xargs clang-format -i
```

## Add clang-tidy

`clang-tidy` also comes with LLVM. It finds bugs, suggests improvements, and checks coding standards.

I enable checks from several categories in `.clang-tidy`:

```yaml
Checks: >
  clang-analyzer-*,
  bugprone-*,
  performance-*,
  modernize-*,
  readability-*,
  cppcoreguidelines-*

WarningsAsErrors: ''
HeaderFilterRegex: '.*'
FormatStyle: file
```

Run:

```bash
clang-tidy src/main.cpp -p build
```

Review each suggestion before applying it. `clang-tidy` is an aid, not an enforcer.

## VS Code setup

Recommended extensions:

```text
llvm-vs-code-extensions.vscode-clangd
ms-vscode.cmake-tools
vadimcn.vscode-lldb
```

If you use `clangd`, disable Microsoft IntelliSense to avoid duplicate diagnostics.

This is what to place in `.vscode/settings.json`:

```json
{
  "clangd.path": "/opt/homebrew/opt/llvm/bin/clangd",
  "clangd.arguments": [
    "--background-index",
    "--clang-tidy",
    "--completion-style=detailed",
    "--header-insertion=iwyu"
  ],
  "C_Cpp.intelliSenseEngine": "disabled",
  "cmake.generator": "Ninja",
  "cmake.configureArgs": [
    "-DCMAKE_C_COMPILER=/opt/homebrew/opt/llvm/bin/clang",
    "-DCMAKE_CXX_COMPILER=/opt/homebrew/opt/llvm/bin/clang++",
    "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON"
  ]
}
```

If `clangd` does not understand your project, check that this file exists:

```bash
ls build/compile_commands.json
```

## Helix setup

I also use Helix alongside VS Code. Check its C++ support first:

```bash
hx --health cpp
```

Add this configuration to `~/.config/helix/languages.toml`:

```toml
[[language]]
name = "cpp"
language-servers = ["clangd"]
formatter = { command = "clang-format" }
auto-format = true

[language-server.clangd]
command = "/opt/homebrew/opt/llvm/bin/clangd"
args = [
  "--background-index",
  "--clang-tidy",
  "--completion-style=detailed",
  "--header-insertion=iwyu"
]
```

Useful Helix commands:

```text
:config-reload
:format
:sh cmake --build build
```

## mise setup

I use [mise](https://mise.jdx.dev/) to manage project environments and tasks. It is optional; all the
CMake commands can be run manually. This `mise.toml` keeps the common commands with the project:

```toml
[tasks.configure]
description = "Configure the Debug build with CMake and Ninja"
run = """
LLVM_PREFIX="$(brew --prefix llvm)"

cmake -S . -B build -G Ninja \
  -DCMAKE_C_COMPILER="$LLVM_PREFIX/bin/clang" \
  -DCMAKE_CXX_COMPILER="$LLVM_PREFIX/bin/clang++" \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  -DCMAKE_BUILD_TYPE=Debug
"""

[tasks.build]
description = "Build the project"
run = "cmake --build build"

[tasks.run]
description = "Run the executable"
run = "./build/cpp_lab"

[tasks.format]
description = "Format C++ source files"
run = """
find src tests -type f \\( -name '*.cpp' -o -name '*.hpp' -o -name '*.h' \\) 2>/dev/null \
  | xargs clang-format -i
"""

[tasks.tidy]
description = "Run clang-tidy on the main source file"
run = "clang-tidy src/main.cpp -p build"
```

Usage:

```bash
mise run configure
mise run build
mise run run
mise run format
mise run tidy
```

## Minimal `main.cpp`

`src/main.cpp`:

```cpp
#include <iostream>
#include <string_view>

void greet(std::string_view name)
{
    std::cout << "Hello, " << name << "!\n";
}

int main()
{
    greet("modern C++");
}
```

Build and run:

```bash
mise run configure
mise run build
mise run run
```

Expected output:

```text
Hello, modern C++!
```

## `.gitignore`

```text
build/
build-*/
.cache/
.DS_Store
compile_commands.json
```

If the editor does not locate the compilation database in `build`, create a symlink for `clangd`:

```bash
ln -sf build/compile_commands.json compile_commands.json
```

## Daily workflow

```bash
# Configure once
mise run configure

# Build
mise run build

# Run
mise run run

# Format
mise run format

# Static analysis
mise run tidy

# Clean build
rm -rf build
mise run configure
mise run build
```

## Quick troubleshooting

### `clang++` still points to Apple Clang

```bash
which clang++
```

If it does not point to Homebrew LLVM, update your `PATH`:

```bash
export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
```

Then reload your shell:

```bash
source ~/.zprofile
```

### `clangd` cannot find headers

```bash
ls build/compile_commands.json
```

If it does not exist, reconfigure:

```bash
cmake -S . -B build -G Ninja \
  -DCMAKE_C_COMPILER=/opt/homebrew/opt/llvm/bin/clang \
  -DCMAKE_CXX_COMPILER=/opt/homebrew/opt/llvm/bin/clang++ \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
```

### Helix does not see `clangd`

```bash
which clangd
hx --health cpp
```

Make sure `languages.toml` points to:

```text
/opt/homebrew/opt/llvm/bin/clangd
```

### VS Code shows duplicate diagnostics

If you use `clangd`, disable Microsoft IntelliSense:

```json
{
  "C_Cpp.intelliSenseEngine": "disabled"
}
```

## Verify the setup

```bash
xcode-select -p
brew --version
clang++ --version
clangd --version
cmake --version
ninja --version
hx --health cpp
mise --version
```
