#!/usr/bin/env bash

script_dir=$(dirname ${BASH_SOURCE[0]})
chmod u+x ${script_dir}/hq/* ${script_dir}/hqf/* ${script_dir}/hqmd/* ${script_dir}/tools/*
export PATH="${script_dir}/hq/:${script_dir}/hqf/:${script_dir}/hqmd/:${script_dir}/tools/:$PATH"
