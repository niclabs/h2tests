#!/usr/bin/python3
import argparse
import os, re
import csv
import xlwt
import math

#to check malformed lines
def is_number(s):
    try:
        float(s)
        return True
    except ValueError:
        return False

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
ws.write(0, 0, 'header table size')
#ws.write(0, 1, 'data count')
ws.write(0, 1, 'avg cpu')
ws.write(0, 2, 'dev cpu')
ws.write(0, 3, 'avg mem')
ws.write(0, 4, 'dev mem')

# Open directory with files
directory_path = '/home/daniela/Desktop/max_header/'
directory = os.fsencode(directory_path)

# Counter for file/row number
i = 0

for file in os.listdir(directory):
	filename = os.fsdecode(file)
	
	full_path = directory_path + str(filename)
	# Create cpu and mem lists
	cpu = []
	mem = []
	
	# Match filename
	m = re.match('max_header_(\d+).log', filename)
	
	if m:
		header = str(m.group(1))
		print(str(header))
		
	# Read file
	with open(full_path) as csv_file:
		csv_reader = csv.reader(csv_file, delimiter='\t')
		for row in csv_reader:
			try:
				if (str(row[0]) != "Z" and is_number(row[1]) and is_number(row[2])):
						print(str(row[1]))
						cpu.append(float(row[1]))
						mem.append(float(row[2]))
			except (ValueError,IndexError):
				continue

	# Increment counter
	i = i + 1
	ws.write(i, 0, int(header))
	#ws.write(i, 1, len(cpu)) # count data (repetitions)
	ws.write(i, 1, mean(cpu)) 
	ws.write(i, 2, stdev(cpu))
	ws.write(i, 3, mean(mem))
	ws.write(i, 4, stdev(mem))

wb.save('maxheader.xls')



