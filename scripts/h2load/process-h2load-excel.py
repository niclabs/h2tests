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
ws.write(0, 1, 'count')
ws.write(0, 2, 'min')
ws.write(0, 3, 'max')
ws.write(0, 4, 'mean')
ws.write(0, 5, 'mean sd')

# Open directory with files
directory_path = '/home/daniela/Desktop/h2load/'
directory = os.fsencode(directory_path)

# Counter for file/row number
i = 0

for file in os.listdir(directory):
	filename = os.fsdecode(file)
	
	full_path = directory_path + str(filename)
	# Increment counter
	i = i + 1
	# Create cpu and mem lists
	minimum = []
	maximum = []
	average = []
	std = []

	# Extract window size from filename
	#m = re,match('WINDOW_SIZE_(\d+)_(\d+)'. filename)
	m = re.match('h2load(\d+_(\d+).log', filename)
	
	if m:
		n_clients = str(m.group(1))
		n_requests = str(m.group(2))

	# Read file
	with open(full_path) as csv_file:
		csv_reader = csv.reader(csv_file) #, delimiter='\t'
		for row in csv_reader:
			if row:
				line = row[0].split()
				if line[0] == "req/s":
					minimum.append(float(line[2]))
					maximum.append(float(line[3]))
					average.append(float(line[4]))
					std.append(float(line[5]))

	ws.write(i, 0, int(n_clients))
	ws.write(i, 1, len(minimum)) # count data
	ws.write(i, 2, min(minimum)) # minimum of minimums
	ws.write(i, 3, max(maximum)) # max of max
	ws.write(i, 4, mean(average)) # mean of all
	ws.write(i, 5, mean(std)) # mean std

wb.save('h2load.xls')



