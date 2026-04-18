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

## NixOS での実行準備

SYCL を使用して Intel GPU で推論を行うには、ホスト側の NixOS 設定で GPU ドライバが有効になっている必要があります。

```nix
{ pkgs, ... }: {
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-compute-runtime
      intel-media-driver
      level-zero
    ];
  };
}
```

## 実機での推論実行手順 (FHS環境下) (13900Kにて人間が実際に確認済み)

NixOS上でSYCLバックエンドとIntel OneAPIを正常に連携させるため、生成されたバイナリはFHS環境のラッパースクリプトになっています。直接内部のバイナリを叩かず、必ず以下の手順でFHSシェルに入ってから推論を実行してください。

### 1. FHS環境（仮想シェル）の起動
まず、ビルドで生成されたラッパースクリプトを実行し、FHS環境に入ります。

```bash
./result/bin/llama-cpp-sycl
```
※ 実行後、シェルがFHS環境内のものに切り替わります。これ以降のコマンドはすべてこのシェル内で実行してください。

### 2. Intel GPU (iGPU) 用の必須環境変数の設定
Intelの内蔵GPU（13900KのUHD 770や1360PのIris Xeなど）でメインメモリをVRAMとして活用してLLMを動かす場合、デフォルトのメモリ制約を解除する必要があります。

```bash
# 1回のメモリ確保の上限(4GB)を解除し、巨大なモデルのロードを許可する（必須）
export UR_L0_ENABLE_RELAXED_ALLOCATION_LIMITS=1

# Level Zeroのシステムメモリ管理機能（空き容量の取得など）を有効化
export ZES_ENABLE_SYSMAN=1
```

> **💡 トラブルシューティング: デバイスが見つからない場合**
> マザーボードやNixOSのドライバ構成によって、SYCLのデフォルト通信プロトコル（Level Zero）がGPUを見失い `No device of requested type available` でクラッシュする場合があります。その際は、確実に動作する OpenCL バックエンドへ強制的にフォールバックさせる以下の環境変数を追加で設定してください。
> ```bash
> export ONEAPI_DEVICE_SELECTOR="opencl:*"
> ```

### 3. モデルの推論実行
環境変数がセットされたら、`llama` コマンドで推論を開始します。以下は Gemma 4 (Q4_K_M) をGPUフルオフロードで起動し、対話（チャット）モードに入るコマンド例です。

```bash
llama -hf ggml-org/gemma-4-E4B-it-GGUF:Q4_K_M -ngl 99 -cnv
```

* **`-hf`**: HuggingFaceから直接GGUFモデルをダウンロード＆ロード（またはキャッシュを使用）します。
* **`-ngl 99`**: 指定したレイヤー数（この場合は上限の99）をすべてGPUにオフロードします。
* **`-cnv`**: 対話（カンバセーション）モードで起動します。

※ 推論中、1コアのCPU使用率が100%に張り付くことがありますが、これはSYCLドライバがGPUの計算完了をポーリング（スピンロック）して遅延を極限まで削っている正常な仕様です。

## 技術的な構成

- **Unwrapped Package**: `packages.x86_64-linux.llama-cpp-sycl-unwrapped`
    - Intel OneAPI `icpx` コンパイラを使用してビルドされた raw バイナリ。
- **FHS Wrapper**: `packages.x86_64-linux.default`
    - `buildFHSEnv` を使用。`/usr/lib` 等に Intel MKL, Level Zero, Compiler Runtimes を配置。
    - 実行時に `ONEAPI_ROOT` 等を自動的に設定します。
