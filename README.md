# llama.cpp SYCL build with Nix

> [!IMPORTANT]
> このドキュメントは AI によって自動生成されました。

このプロジェクトは、Intel OneAPI (SYCL) をバックエンドに使用した `llama.cpp` を Nix でビルドし、NixOS 環境で動作させるための構成を提供します。

## システム要件

- **OS**: NixOS (x86_64-linux)
- **Hardware**: Intel GPU (Arc, Data Center GPU, Integrated Graphics)
- **Nix**: Flakes が有効であること

## ビルド方法

Intel OneAPI Toolkit は Unfree ライセンスのパッケージを含み、またビルド時に環境変数へのアクセスを必要とするため、`--impure` フラグが必要です。

```bash
# Unfree パッケージを許可
export NIXPKGS_ALLOW_UNFREE=1

# ビルドの実行
nix build --impure
```

ビルドが完了すると、カレントディレクトリの `result` シンボリックリンク内にバイナリが生成されます。

## NixOS での実行準備

SYCL を使用して Intel GPU で推論を行うには、NixOS の設定（`configuration.nix`）で GPU ドライバとランタイムが有効になっている必要があります。

```nix
{ pkgs, ... }: {
  # Intel GPU ドライバの有効化
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-compute-runtime # OpenCL/SYCL 用
      intel-media-driver    # VA-API 用
      level-zero-loader     # OneAPI Level Zero
    ];
  };
}
```

## 使い方

ビルドされたバイナリを直接実行します。

```bash
# CLI の実行例
./result/bin/llama-cli -m /path/to/your/model.gguf -p "Hello, how are you?" -ngln 99

# サーバーの実行例
./result/bin/llama-server -m /path/to/your/model.gguf --host 0.0.0.0 --port 8080
```

### 主要なバイナリ

- `llama-cli`: メインのコマンドラインインターフェース
- `llama-server`: HTTP API サーバー
- `llama-rpc-server`: 分散推論用 RPC サーバー

## 技術的な詳細

- **Compiler**: Intel OneAPI `icpx` (version 2025.3.1)
- **Backend**: SYCL (OneAPI Level Zero)
- **MKL**: ビルドおよび実行時に Intel MKL を使用するように構成されています
- **Nixpkgs**: `nixpkgs-master` の最新の `llama-cpp` 定義をベースに、SYCL 向けにオーバーライドしています
