#!/usr/bin/env bash
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --prefix=*)  PREFIX="${1#*=}"; ;;
    --prefix)    shift; PREFIX="$1"; ;;
    --bindir=*)  BINDIR="${1#*=}"; ;;
    --bindir)    shift; BINDIR="$1"; ;;
    --libdir=*)  LIBDIR="${1#*=}"; ;;
    --libdir)    shift; LIBDIR="$1"; ;;
    -g|--global) FSH=standard; ;;
    -l|--local)  FSH=nmroot; ;;
    --node=*)    NODE="${1#*=}"; ;;
    --node)      shift; NODE="$1"; ;;
    -l|--lndirs) STYLE=lndirs; ;;
    -c|--copy)   STYLEcopy; ;;
    --bin-links) BSTYLE=link; ;;
    --bin-wraps) BSTYLE=wrap; ;;
    --no-bins)   BSTYLE=skip; ;;
    --mode=*)    MODE="${1#*=}"; ;;
    --mode)      shift; MODE="$1"; ;;
  esac
  shift;
done
