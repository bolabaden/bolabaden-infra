#!/bin/bash

ENV_FILE=$2
grep "^$1=" ${ENV_FILE:-.env} | cut -d '=' -f2- | tr -d '"'
