#!/usr/bin/python
# -*- coding: UTF-8 -*-
import os, os.path, re, sys, collections
sys.path.insert(0, os.environ['FUEGO_CORE'] + '/engine/scripts/parser')
import common as plib

SAVEDIR=os.getcwd()
LOGDIR=os.environ["LOGDIR"]
test_results = {}
test_results = collections.OrderedDict()
regex_string = '.*"case": "([^ ]*)".*"definition": "([^ ]*)".*"result": "([^ ]*)".*'

def make_dirs(dir_path):
    if os.path.exists(dir_path):
        return

    try:
        os.makedirs(dir_path)
    except OSError:
        pass

## Check testlog.txt
try:
    f = open("%s/testlog.txt" % LOGDIR)
except IOError:
    print '"testlog.txt" cannot be opened.'

lines = f.readlines()
f.close()
result_dir = '%s/result/default/outputs' % (LOGDIR)
make_dirs(result_dir)
in_loop = 0

regc = re.compile(regex_string)
for line in lines:
    if in_loop == 0:
        try:
            output_each = open(result_dir+"/tmp.log", "w")
            in_loop = 1
        except IOError:
            print('"%s" cannot be created or "%s/tmp.log" cannot be opened.' % (out_dir, out_dir))

    target_outputs = line.split("\"")[11]
    if target_outputs != 'case':
        output_each.write("%s\n" % target_outputs)

    m = regc.match(line)
    if m is not None:
        test_case = m.group(1)
        test_set = m.group(2)
        result = m.group(3)
        fin_case = test_case
        icnt = 1

        if result == "pass":
            status = "PASS"
        else:
            status = "FAIL"

        #TODO: it will be better if the LAVA related testcases can be
        #      listed in execution time order in the final test report.
        while test_set + '.' + fin_case in test_results.keys():
            fin_case = test_case + '-' + str(icnt)
            icnt += 1

        if "_" in test_set:
            test_set = test_set.split('_')[1]

        test_results[test_set + '.' + fin_case] = status
        output_each.close()

        output_dir = '%s/result/%s/outputs' % (LOGDIR, test_set)
        make_dirs(output_dir)

        os.rename(result_dir+"/tmp.log", output_dir+"/%s.log" % fin_case)
        in_loop = 0

sys.exit(plib.process(test_results))
