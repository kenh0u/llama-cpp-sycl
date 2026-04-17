# llama.cpp SYCL build with Nix (FHS Wrapper)

> [!IMPORTANT]
> このドキュメントは AI によって自動生成されました。

このプロジェクトは、Intel OneAPI (SYCL) をバックエンドに使用した `llama.cpp` を Nix でビルドし、SYCL のランタイムが要求する FHS (Filesystem Hierarchy Standard) 依存性を解決するための `buildFHSEnv` 構成を提供します。

## 背景

Intel OneAPI SYCL ランタイム（特に Level Zero 経由）は、`/lib` や `/usr/lib` などの標準的なパスにライブラリや設定ファイルが存在することを期待する傾向が強く、純粋な Nix 環境では動作が不安定になる場合があります。この Flake では、実行環境を FHS 互換のサンドボックスにラップすることで、実機での高い互換性を確保しています。

## システム要件

- **OS**: NixOS または他の Linux ディストリビューション (x86_64-linux)
- **Hardware**: Intel GPU (Arc, Data Center GPU, Integrated Graphics)
- **Nix**: Flakes が有効であること

## ビルド方法

ビルドには Unfree パッケージ (Intel OneAPI) の許可と、環境変数アクセスのための `--impure` フラグが必要です。

```bash
# Unfree パッケージを許可
export NIXPKGS_ALLOW_UNFREE=1

# ビルドの実行
nix build --impure
```

## 使い方

ビルドされた成果物 `./result/bin/llama-cpp-sycl` は、FHS 環境を起動するためのラッパースクリプトです。

### 1. FHS シェルに入る
シェルに入ってからバイナリを実行するのが最も確実な方法です。

```bash
./result/bin/llama-cpp-sycl
# シェル内
llama-cli --version
```

### 2. 直接コマンドを実行する
`-c` フラグを使用して、FHS 環境内で特定のコマンドを実行できます。

```bash
./result/bin/llama-cpp-sycl -c "llama-cli -m /path/to/model.gguf -p 'Hello' -ngl 99"
```

## NixOS での実行準備

SYCL を使用して Intel GPU で推論を行うには、ホスト側の NixOS 設定で GPU ドライバが有効になっている必要があります。

```nix
{ pkgs, ... }: {
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-compute-runtime
      intel-media-driver
      level-zero-loader
    ];
  };
}
```

## 技術的な構成

- **Unwrapped Package**: `packages.x86_64-linux.llama-cpp-sycl-unwrapped`
    - Intel OneAPI `icpx` コンパイラを使用してビルドされた raw バイナリ。
- **FHS Wrapper**: `packages.x86_64-linux.default`
    - `buildFHSEnv` を使用。`/usr/lib` 等に Intel MKL, Level Zero, Compiler Runtimes を配置。
    - 実行時に `ONEAPI_ROOT` 等を自動的に設定します。
