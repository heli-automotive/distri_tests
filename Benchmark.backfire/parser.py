#!/usr/bin/python
import os, re, sys
sys.path.insert(0, os.environ['FUEGO_CORE'] + '/engine/scripts/parser')
import common as plib

regex_string = ".* Min\s+(\d+).*, Avg\s+(\d+), Max\s+(\d+)"
measurements = {}
matches = plib.parse_log(regex_string)

if matches:
	min_intervals = []
	avg_intervals = []
	max_intervals = []
	for thread in matches:
		min_intervals.append(float(thread[0]))
		avg_intervals.append(float(thread[1]))
		max_intervals.append(float(thread[2]))
	measurements['default.intervals'] = [
		{"name": "max_interval", "measure" : max(max_intervals)},
		{"name": "min_interval", "measure" : min(min_intervals)},
		{"name": "avg_interval", "measure" : sum(avg_intervals)/len(avg_intervals)}]

sys.exit(plib.process(measurements))
