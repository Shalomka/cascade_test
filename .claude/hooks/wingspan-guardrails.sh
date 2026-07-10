#!/usr/bin/env bash
# Thin wrapper so the tool-call JSON on stdin reaches the python guardrail.
exec python3 "$(dirname "$0")/wingspan-guardrails.py"
