#!/usr/bin/python3
import argparse
import os, re
import csv
import xlwt
import math

def stdev(nums):
	diffs = 0
	avg = sum(nums)/len(nums)
	for n in nums:
		diffs += (n - avg)**(2)
	return (diffs/(len(nums)-1))**(0.5)

def mean(nums):
	return sum(nums) / float(len(nums))

# Create a workbook (xls)
wb = xlwt.Workbook()
ws = wb.add_sheet('Statistics')

# Add headers
ws.write(0, 0, 'number of clients')
ws.write(0, 1, 'total number of requests')
ws.write(0, 2, 'req total')
ws.write(0, 3, 'req succeeded')
#ws.write(0, 4, 'std succeeded')
ws.write(0, 4, 'req failed')
#ws.write(0, 6, 'std failed')
ws.write(0, 5, 'req errored')
ws.write(0, 6, 'req timeout')

# Open directory with files
directory_path = '/home/daniela/Desktop/h2load/'
directory = os.fsencode(directory_path)

# Counter for file/row number
i = 0

for file in os.listdir(directory):
	filename = os.fsdecode(file)
	
	full_path = directory_path + str(filename)
	# Create cpu and mem lists
	total = []
	succeeded = []
	failed = []
	errored = []
	timeout = []

	# Match filename
	m = re.match('h2load(\d+)_(\d+).log', filename)
	
	if m:
		n_clients = str(m.group(1))
		n_requests = str(m.group(2))

	# Read file
	with open(full_path) as f:
		for row in f:
			if row.startswith("requests:"):
				line = row.split()
				total.append(float(line[1]))
				succeeded.append(float(line[7]))
				failed.append(float(line[9]))
				errored.append(float(line[11]))
				timeout.append(float(line[13]))

	if (int(n_clients) <= int(n_requests)):
		# Increment counter
		i = i + 1
		ws.write(i, 0, int(n_clients))
		ws.write(i, 1, int(n_requests)) # count data (repetitions)
		ws.write(i, 2, mean(total)) 
		ws.write(i, 3, mean(succeeded))
		ws.write(i, 4, mean(failed))
		#ws.write(i, 6, stdev(failed))
		ws.write(i, 5, mean(errored))
		ws.write(i, 6, mean(timeout))

wb.save('req-status.xls')



