#!/usr/bin/perl

# Backplane KR training solution
# Pseudo-exhaustive search method
# 							       							 
# Author: Florin Iordache
#
# Copyright 2019 NXP


use strict;
use warnings;
use os_lnx;

# global variables



# private variables

# granularity level
my $step = 3;

# PREQ search space
my $min_preq = 0;
my $max_preq = 0xc;

# PST1Q search space
my $min_pst1q = 0;
my $max_pst1q = 0x10;

# ADAPT_EQ search space
my $min_adpt_eq = 25;
my $max_adpt_eq = 48;

# AMP_RED search space
my $min_amp_red = 0;
my $max_amp_red = 7;

# iterations count
my $iteration = 1;

# run in devel mode
my $devel_mode = 0;


# function prototypes

#----------------------------------------------------------------------

# Backplane KR training solution: Pseudo-exhaustive search method
print "Start Pseudo-exhaustive search method for KR training solution\n";

os_lnx::initialize();


if ($devel_mode == 1)
{
	# run in devel mode:
	print "Running in DEVEL mode \n";
	
	os_lnx::setup_kr($iteration, 2, 2, 48);
	os_lnx::set_ampred($iteration, 0);
	os_lnx::run_ping_test(2);
	$iteration ++;

	os_lnx::setup_kr($iteration, 2, 4, 48);
	os_lnx::set_ampred($iteration, 3);
	os_lnx::run_ping_test(2);
	$iteration ++;
	
	os_lnx::setup_kr($iteration, 4, 6, 48);
	os_lnx::run_ping_test(2);
	$iteration ++;

	os_lnx::setup_kr($iteration, 4, 9, 48);
	os_lnx::run_ping_test(2);
	$iteration ++;

	os_lnx::setup_kr($iteration, 4, 12, 48);
	os_lnx::run_ping_test(2);
	$iteration ++;
	
	# end of test
}
else
{
	# run in real mode: scan entire search space
	print "Running in REAL search mode \n";

	# scan the AMP_RED search space (with defined granularity level)
	for (my $ampred = $min_amp_red; $ampred <= $max_amp_red; $ampred += $step) {
	
		# scan the ADAPT_EQ search space (with defined granularity level)
		for (my $adpteq = $max_adpt_eq; $adpteq >= $min_adpt_eq; $adpteq -= $step) {
		
			#print "Test adpteq $adpteq \n";
		
			# scan the PREQ search space (with defined granularity level)
			for (my $preq = $min_preq; $preq <= $max_preq; $preq += $step) {
				
				#print "Test preq $preq \n";
				
				# scan the PST1Q search space (with defined granularity level)
				for (my $pst1q = $min_pst1q; $pst1q <= $max_pst1q; $pst1q += $step) {
	
					#print "Test pst1q $pst1q \n";
					
					# force kr setup for current iteration
					os_lnx::setup_kr($iteration, $preq, $pst1q, $adpteq);
					
					# amp_red must be forced after kr setup (according to backplane driver implementation) 
					os_lnx::set_ampred($iteration, $ampred);
					
					# run ping test on current iteration
					os_lnx::run_ping_test(60);
					
					#print "Test iteration $iteration \n";
					
					$iteration ++;
				}
			}
		}
	}

# end of scan the entire search space
}

os_lnx::terminate();

print "End of Pseudo-exhaustive search \n";

#----------------------------------------------------------------------



__END__
