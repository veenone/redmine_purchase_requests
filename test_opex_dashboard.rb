#!/usr/bin/env ruby
# Test script for OPEX dashboard functionality

require 'bundler/setup'
require_relative '../test_setup'

puts "Testing OPEX Dashboard Functionality..."
puts "=" * 50

# Test Opex model currency_symbol method
puts "\n1. Testing Opex model currency_symbol method:"
opex = Opex.new(currency: 'USD')
puts "USD currency symbol: #{opex.currency_symbol}"

opex.currency = 'EUR'
puts "EUR currency symbol: #{opex.currency_symbol}"

opex.currency = 'GBP'
puts "GBP currency symbol: #{opex.currency_symbol}"

opex.currency = 'JPY'
puts "JPY currency symbol: #{opex.currency_symbol}"

puts "\n2. Testing OPEX controller helper method:"
# This would need to be tested in context of a controller

puts "\n3. Testing OPEX dashboard route:"
puts "OPEX dashboard route should be available at: /projects/:id/opex/dashboard"

puts "\n4. Testing OPEX model validations:"
opex = Opex.new
puts "Empty OPEX validation errors:"
opex.valid?
opex.errors.full_messages.each { |msg| puts "  - #{msg}" }

puts "\n5. Testing OPEX quarterly calculations:"
opex = Opex.new(
  total_amount: 1000,
  q1_amount: 250,
  q2_amount: 250,
  q3_amount: 250,
  q4_amount: 250
)
puts "Total quarterly amount: #{opex.total_quarterly_amount}"
puts "Q1 percentage: #{opex.quarterly_percentage(1)}%"
puts "Q2 percentage: #{opex.quarterly_percentage(2)}%"

puts "\nOPEX Dashboard Test Complete!"
