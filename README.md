# configs (macOS / Linux)

このリポジトリは、**共通設定はGitで管理**しつつ、**マシン固有設定はローカルに残す**ための dotfiles 構成です。

## 方針

- Pushする: どのMac/Linuxでも使う共通設定
- Pushしない: 端末ごとのPATH・秘密情報・一時的な実験設定

## インストール

```bash
cd ~/configs
./setup.sh
```

デフォルトで以下を行います。

- ベースパッケージ導入（`git`, `curl`, `zsh`, `vim`, `tmux`, `node`, `npm`）
- `~/.zshrc`, `~/.gitconfig`, `~/.tmux.conf`, `~/.vimrc`, `~/.ssh/config` をこのリポジトリへシンボリックリンク
- 既存ファイルがあれば `*.backup.YYYYmmdd-HHMMSS` に退避
- `~/.oh-my-zsh` が無ければ clone
- `myShellConfig.sh` が無ければ `myShellConfig.example.sh` から作成
- AI系CLI導入（`claude`, `codex`）
- GitHub + SSH セットアップ（`gh` 導入、鍵生成、`ssh-agent` 登録、GitHub公開鍵登録）
- `zsh` が使える場合、ログインシェルを `zsh` に変更（再ログインで反映）

必要ならスキップ可能です。

```bash
./setup.sh --without-ai-tools
./setup.sh --skip-system-packages
./setup.sh --skip-change-shell
./setup.sh --skip-github-ssh
```

`install_ai_tools.sh` 単体実行もできます。

```bash
./install_ai_tools.sh
```

AI系CLI導入には Node.js 18+ が必要です。

## GitHub + SSH セットアップ

GitHub CLI 導入、SSH鍵生成、`ssh-agent` 登録、GitHub への公開鍵登録をまとめて実行できます。

`setup.sh` から自動で実行されます。個別実行する場合は以下です。

```bash
cd ~/configs
./setup_github_ssh.sh
```

実行時に `Git user.name` / `Git user.email` / SSH鍵コメント用メールを対話で確認します（既存値があればデフォルト表示）。

主なオプション:

- `--git-email you@example.com` (`git config --global user.email` を設定)
- `--key-path ~/.ssh/id_ed25519_github` (鍵の保存先を変更)
- `--skip-install` (パッケージ導入をスキップ)
- `--skip-gh-auth` (`gh auth login` をスキップ)
- `--skip-gh-key-register` (GitHub への公開鍵登録をスキップ)
- `--non-interactive` (対話入力を無効化)

## ローカル専用ファイル

以下は共通化せず、各マシンで個別管理します。

- `myShellConfig.sh` (repo内・gitignore済み)
- `~/.gitconfig.local` (`_gitconfig` から include)
- `~/.ssh/config.local` (`ssh_config` から Include)
- `~/.config/shell/local.zsh`
- `~/.config/shell/local.macos.zsh` / `~/.config/shell/local.linux.zsh`
- `~/.config/shell/secrets.zsh`

## 運用ルール

- 共通化できる変更だけ `_zshrc` などへ反映して push
- マシン固有の変更は `myShellConfig.sh` などへ寄せる
- 新しいサーバーに入るときは `git clone` → `./setup.sh` で最短復元

`setup.sh` は初回のみ以下も自動生成します（未存在時）。

- `~/.gitconfig.local`（`_gitconfig.local.example` から）
- `~/.ssh/config.local`（`ssh_config.local.example` から）
