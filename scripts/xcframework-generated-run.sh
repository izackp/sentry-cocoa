#!/bin/bash
grep "generated by" "Package.swift" | sed 's/.*generated by \"\(.*\)\"/\1/'