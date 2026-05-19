+++
title = "My Modern C++ Setup on macOS and Apple Silicon"
date = 2026-05-19
description = "A practical setup for learning modern C++ on macOS with Apple Silicon, LLVM, CMake, Ninja, VS Code, Helix, and mise"
draft = false

[taxonomies]
tags = ["cpp", "macos", "apple-silicon", "llvm", "cmake", "vscode", "helix", "mise"]
categories = ["development"]

[extra]
toc = true
+++

I’m starting to learn modern C++ seriously (yes, seriously), so I wanted a clean and repeatable development setup on
macOS with Apple Silicon.

My goals are simple:

- use a modern LLVM/Clang toolchain
- build projects with CMake and Ninja
- get proper language-server support in VS Code and Helix
- use sanitizers and static analysis from the beginning
- keep the setup practical, not over-engineered
- make sure everything is reproducible on any M-series Mac

This post is a cheatsheet and assumes that Homebrew is already installed.

<!-- more -->

## Install Xcode Command Line Tools

First, install Apple’s basic developer tools:

```bash
xcode-select --install
```

Check that they are available:

```bash
xcode-select -p
clang --version
```

macOS ships Apple Clang, but for learning modern C++ I prefer installing a newer LLVM toolchain through Homebrew.

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

This gives us:

- `clang`
- `clang++`
- `clangd`
- `clang-format`
- `clang-tidy`
- CMake
- Ninja

llvm is installed as a separate toolchain and its binaries may not be available in PATH automatically.
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

Now add Homebrew LLVM to your interactive shell:

```shell
echo 'export PATH="$(brew --prefix llvm)/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
rehash
```

## Recommended project structure

For a small learning project the structure can as simple as this:

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

For now, I create such a structure manually, but it can be easily generated with a custom script or CMake template later.

## Minimal modern CMake setup

I’ve just started tinking with CMake, so I keep the setup minimal. The `CMakeLists.txt` looks like this:

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

The important part here is:

```cmake
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
```

It generates `compile_commands.json`, which helps `clangd` understand the project.
No Cargo facilities like workspaces or dependencies for now, just a single executable target.

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

When learning C++, sanitizers can help catch common mistakes and bad habits early on.

I’m experimenting with AddressSanitizer for memory bugs and UndefinedBehaviorSanitizer for undefined behavior.

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

Rule of thumb: do not mix AddressSanitizer and ThreadSanitizer in the same build, use separate build directories.
This sanitizers are not compatible with each other and will cause false positives.

## Add clang-format

clang-format helps keep the code style consistent and readable. The tools comes with llvm, so it is already installed.

The `.clang-format` file defines the code style. I prefer to use 4 spaces for indentation and a 100 character line limit.

```yaml
BasedOnStyle: LLVM
IndentWidth: 4
ColumnLimit: 100
AllowShortFunctionsOnASingleLine: Empty
DerivePointerAlignment: false
PointerAlignment: Left
```

Formatting code can be done with the following command:

```bash
find src tests \( -name '*.cpp' -o -name '*.hpp' \) | xargs clang-format -i
```

This way we can format all source files in one go. The `-i` flag means “in-place”, so the files will be modified directly.

## Add clang-tidy

clang-tidy is a powerful static analysis tool that can catch bugs, suggest improvements, and enforce coding standards.
It also comes with llvm.

The `.clang-tidy` file configures the checks to run. I enable a broad set of checks from different categories,
but you can customize it to your needs:

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

Do not blindly apply every suggestion. `clang-tidy` is a reviewer, not a enforcer.
Use your judgement to decide which suggestions to apply.

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

As I mentioned in my previous posts, I’m also trying out Helix as a lightweight editor in parallel to VS Code.
I’ve already configured the editor for Python and Rust, so now it’s time to add C++ support.

Check health first:

```bash
hx --health cpp
```

Next, add the following configuration to `~/.config/helix/languages.toml`:

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

I use [mise](https://mise.jdx.dev/) as a project environment manager.

Its main job is to install and activate the right tool versions for a project.
It can also load project-specific environment variables and run project tasks.
In small learning projects, this is a convenient way to keep common commands close to the code
without introducing a Makefile too early.

For this C++ setup, mise is optional. You can run all CMake commands manually. But if you already use mise,
a small `mise.toml` can make the workflow nicer.

Here is an example `mise.toml`:

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

This gives a simple project workflow without inventing a custom shell script too early.

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

```gitignore
build/
build-*/
.cache/
.DS_Store
compile_commands.json
```

Optionally create a symlink for `clangd`:

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

## Final setup checklist

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

If all commands work, the environment is ready.

## Final thought

The goal is not to build the most complicated C++ setup possible.

The goal is to have a small, modern, repeatable environment where I can learn the language properly:

- modern LLVM
- CMake, Ninja
- clangd
- clang-format
- clang-tidy
- sanitizers
- VS Code or Helix
- simple project tasks through mise.

That is enough to start writing modern C++ and avoid old C++ habits from day one.
Maybe I will add more tools later or change the setup completely, but for now this is a good starting point.
