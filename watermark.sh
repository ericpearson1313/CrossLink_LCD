#!/bin/bash
git rev-parse HEAD | head -c7 | awk -f format_commit.awk > commit.mem

