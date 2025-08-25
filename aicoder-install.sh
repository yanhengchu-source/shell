#!/usr/bin/env bash

# 设置严格模式，遇到错误立即退出
set -euo pipefail

# 默认远程仓库地址
DEFAULT_REPO_URL="http://git.allsaints.top/android-vvo/aicoder-toolkit.git"
# 源码下载路径
INSTALL_PATH="$HOME/aispace"
# 获取当前命令行目录
CURRENT_DIR="$PWD"

# 参数处理
# 支持命名参数和位置参数
REPO_URL="$DEFAULT_REPO_URL"
FORCE_OVERWRITE=""

# 解析命名参数
while [[ $# -gt 0 ]]; do
  case $1 in
  --repo | -r)
    REPO_URL="$2"
    shift 2
    ;;
  --force | -f)
    FORCE_OVERWRITE="$2"
    shift 2
    ;;
  --help | -h)
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -r, --repo URL     指定远程仓库地址 (默认: $DEFAULT_REPO_URL)"
    echo "  -f, --force y/N    是否强制覆盖本地源码库 (y=是, N=否)"
    echo "  -h, --help         显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0                           # 使用默认参数"
    echo "  $0 -r https://github.com/user/repo.git  # 指定仓库"
    echo "  $0 -f y                      # 使用默认仓库，强制覆盖"
    echo "  $0 -r https://github.com/user/repo.git -f y  # 指定仓库并强制覆盖"
    exit 0
    ;;
  *)
    # 兼容位置参数
    if [ -z "$REPO_URL" ] || [ "$REPO_URL" = "$DEFAULT_REPO_URL" ]; then
      # 检查是否是覆盖选项（y/N）
      if [[ "$1" =~ ^[YyNn]$ ]]; then
        FORCE_OVERWRITE="$1"
      else
        REPO_URL="$1"
      fi
    elif [ -z "$FORCE_OVERWRITE" ]; then
      FORCE_OVERWRITE="$1"
    fi
    shift
    ;;
  esac
done

# 从仓库地址中提取仓库名称
REPO_NAME=$(basename "$REPO_URL" .git)
# 仓库根目录
AICODER_ROOT_DIR="$INSTALL_PATH/$REPO_NAME"

# =============================================
# AICoder 安装脚本
# - 参考 UI 风格: gemini-cli-startup-analysis.md
# - 功能：远程仓库下载、Git hooks 配置
# - 支持参数：远程仓库地址、是否覆盖本地源码库
# =============================================

# ANSI 样式
BOLD="\033[1m"    # 加粗
DIM="\033[2m"     # 淡化
RESET="\033[0m"   # 重置所有样式
FG="\033[36m"     # 青色（正文）
ACCENT="\033[35m" # 品牌强调色（紫）
GREEN="\033[32m"  # 成功
YELLOW="\033[33m" # 提示
GRAY="\033[90m"   # 次要信息

# 终端宽度
TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)

# ASCII 横幅（长/短） - 风格参考 gemini 启动界面（稳定显示 AICODER 文本）
LONG_ASCII='
   █████████   █████   █████████     ███████    ██████████   ██████████ ███████████  
  ███░░░░░███ ░░███   ███░░░░░███  ███░░░░░███ ░░███░░░░███ ░░███░░░░░█░░███░░░░░███ 
 ░███    ░███  ░███  ███     ░░░  ███     ░░███ ░███   ░░███ ░███  █ ░  ░███    ░███ 
 ░███████████  ░███ ░███         ░███      ░███ ░███    ░███ ░██████    ░██████████  
 ░███░░░░░███  ░███ ░███         ░███      ░███ ░███    ░███ ░███░░█    ░███░░░░░███ 
 ░███    ░███  ░███ ░░███     ███░░███     ███  ░███    ███  ░███ ░   █ ░███    ░███ 
 █████   █████ █████ ░░█████████  ░░░███████░   ██████████   ██████████ █████   █████
░░░░░   ░░░░░ ░░░░░   ░░░░░░░░░     ░░░░░░░    ░░░░░░░░░░   ░░░░░░░░░░ ░░░░░   ░░░░░                                                                                 
'

SHORT_ASCII='
   █████████   █████   █████████  ███████████  
  ███░░░░░███ ░░███   ███░░░░░███░░███░░░░░███ 
 ░███    ░███  ░███  ███     ░░░  ░███    ░███ 
 ░███████████  ░███ ░███          ░██████████  
 ░███░░░░░███  ░███ ░███          ░███░░░░░███ 
 ░███    ░███  ░███ ░░███     ███ ░███    ░███ 
 █████   █████ █████ ░░█████████  █████   █████
░░░░░   ░░░░░ ░░░░░   ░░░░░░░░░  ░░░░░   ░░░░░ 
'

print_banner() {
  if [ "$TERM_WIDTH" -ge 80 ]; then
    printf "%b\n" "${ACCENT}${BOLD}${LONG_ASCII}${RESET}"
  else
    printf "%b\n" "${ACCENT}${BOLD}${SHORT_ASCII}${RESET}"
  fi
}

print_tips() {
  printf "%b\n" "${FG}Tips for getting started:${RESET}"
  printf "%b\n" "${FG}1.${RESET} 脚本会从远程仓库下载安装所需文件。"
  printf "%b\n" "${FG}2.${RESET} 当前使用仓库地址: ${REPO_URL}"
  if [ -n "$FORCE_OVERWRITE" ]; then
    printf "%b\n" "${FG}3.${RESET} 强制覆盖模式已启用。"
  else
    printf "%b\n" "${FG}3.${RESET} 如果目录已存在，会提示是否覆盖。"
  fi
  printf "%b\n\n" "${FG}4.${RESET} 按 Ctrl+C 可随时退出。"
}

download_remote_repo() {
  printf "%b\n" "${YELLOW}[*] 开始下载远程仓库 → ${REPO_URL}${RESET}"

  # 检查 git 是否已安装
  if ! command -v git &>/dev/null; then
    printf "%b\n" "${YELLOW}错误：未找到 git 命令，请先安装 git${RESET}"
    exit 1
  fi

  # 创建安装目录
  if [ ! -d "$INSTALL_PATH" ]; then
    printf "%b\n" "${FG}创建安装目录: ${INSTALL_PATH}${RESET}"
    mkdir -p "$INSTALL_PATH"
  fi

  # 检查目录是否已存在且非空
  if [ -d "$INSTALL_PATH" ] && [ "$(ls -A "$INSTALL_PATH" 2>/dev/null)" ]; then
    printf "%b\n" "${YELLOW}警告：目录 ${INSTALL_PATH} 已存在且非空${RESET}"
    if [ -z "$FORCE_OVERWRITE" ]; then
      read -p "是否继续？这将覆盖现有内容 (y/N): " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        printf "%b\n" "${YELLOW}用户取消操作${RESET}"
        exit 0
      fi
    fi
    # 清空目录
    rm -rf "$INSTALL_PATH"/*
  fi

  # 下载远程仓库
  printf "%b\n" "${FG}正在克隆仓库...${RESET}"
  if git clone "$REPO_URL" "$INSTALL_PATH/$REPO_NAME" 2>/dev/null; then
    printf "%b\n" "${GREEN}✓ 仓库下载成功${RESET}"
  else
    printf "%b\n" "${YELLOW}错误：仓库下载失败${RESET}"
    printf "%b\n" "${GRAY}请检查网络连接和仓库地址是否正确${RESET}"
    exit 1
  fi

  printf "%b\n" "${FG}源码已下载到: ${INSTALL_PATH}${RESET}"
  printf "%b\n\n" "${GRAY}下载完成${RESET}"
}

config_aicoder() {
  printf "%b\n" "${YELLOW}[*] 配置 Git hooks, 项目根目录: ${AICODER_ROOT_DIR}${RESET}"
  # 复制 aicoder 目录到 .git/hooks
  cp -r "$AICODER_ROOT_DIR/aicoder" "$CURRENT_DIR/.git/aicoder"
  # 复制 .git/hooks/pre-commit 文件到 .git/aicoder/pre-commit
  cp "$AICODER_ROOT_DIR/aicoder/post-commit" "$CURRENT_DIR/.git/hooks/post-commit"
  # 配置完成
  printf "%b\n" "${GREEN}✓ Git hooks 配置完成${RESET}"
}

print_steps() {
  printf "%b\n" "${BOLD}安装步骤：${RESET}"
  printf "%b\n" "[1/3] 下载远程仓库 ..."
  download_remote_repo
  printf "%b\n" "[2/3] 配置 AICoder ..."
  config_aicoder
  printf "%b\n\n" "[3/3] 安装完成 ... ${GREEN}OK${RESET}"
}

print_done() {
  printf "%b\n" "${GREEN}${BOLD}安装完成，欢迎使用${RESET}"
}

# 主流程
print_banner
print_tips
print_steps
print_done
