#!/usr/bin/env python

#--------------------------------------------------
# batchtable.py: Component of GLTF to GLB converter
# (c) 2016 Geopipe, Inc.
# All rights reserved. See LICENSE.
#--------------------------------------------------

import struct
import json

class BatchTable:
	def __init__(self):
		self.batch_in = {}
		self.batch_json = bytearray()
		self.batch_bin = bytearray()
		self.num_features = 0

	def loadJSONBatch(self, data_in, object_wise = True):
		""" Load object batch data from a dict/object. The data could,
			for example, have been decoded from a JSON string.
	
			If object_wise is True, then the JSON should be
			formatted as an array of batched objects, each
			of which has a series of keys and values. This
			method will transpose the data to map keys to
			arrays of values, one for each object. It handles
			keys that only exist for a subset of the batched
			obhects.
	
			If object_wise is False, then it is assumed that
			the input data already maps keys to arrays of
			values, one for each object, with the necessary
			null/None/placeholder values for keys that don't
			have a real value for that particular object.
		"""
		if object_wise:
			n_objs = len(data_in)
			# Find all the fields for all the objects
			for obj, objval in data_in.iteritems():
				obj = int(obj)

				# Add this object's key-vals
				for key, val in objval.iteritems():
					if not key in self.batch_in:
						self.batch_in[key] = [None] * n_objs

					self.batch_in[key][obj] = val

				n_objs += 1

		else:
			self.batch_in = data_in

		self.num_features = len(self.batch_in)

	def addGlobal(self, key, value):
		self.batch_in[key] = value
		self.num_features += 1

	def writeOutput(self):
		data_out = {}
		# TODO: Add proper encoding to JSON + binary, rather than just
		# punting to the naive method
		data_out = self.batch_in
		self.batch_json = bytearray(json.dumps(data_out, separators=(',', ':'), sort_keys=True))
		self.batch_in = bytearray()

	def finalize(self):
		# Create the actual batch JSON (and binary)
		self.writeOutput()

		# Pad with spaces to a multiple of 4 bytes
		padded_batch_json_len = len(self.batch_json) + 3 & ~3
		self.batch_json.extend(' ' * (padded_batch_json_len - len(self.batch_json)))

		padded_batch_bin_len = len(self.batch_bin) + 3 & ~3
		self.batch_bin.extend(' ' * (padded_batch_bin_len - len(self.batch_bin)))

	def getBatchJSON(self):
		return self.batch_json

	def getBatchBin(self):
		return self.batch_bin

	def getNumFeatures(self):
		return self.num_features
