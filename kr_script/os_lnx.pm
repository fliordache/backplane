# Linux OS package 
# 							       							 
# Author: Florin Iordache
#
# Copyright 2019 NXP

package os_lnx;

use strict;
use warnings;
use Time::HiRes;
use POSIX qw(strftime);
use X11::GUITest;
use krconfig;

# private variables

# terminal window IDs
my @wterm_board = (0, 0);

# ifconfig mac counters: 3D array: [board][major_type(Rx/Tx)][minor_type(pckt/errors/dropped)]
my @prev_ifmac_counters = ();
my @ifmac_counters = ();

# top solution: 3D array: [board][sol_index][sol array:(index + 3 LD stats + 4 LP params)]
my @top_solutions = ();
my @count_solutions = (0, 0);
my @best_rxerr = (-1, -1);

# log files:
my $logfile_root;
my $logfile_all;
my $logfile_res;

# time
my $starttime;

# temporary file
my $temp_file = "tmp.txt";

# current iteration
my $crt_iteration = 0;

# current setup
my @crt_preq = ();
my @crt_pst1q = ();
my @crt_adpt_eq = ();
my @crt_amp_red = ();

# number of boards
my $boards_count = 2;

# function prototypes

sub open_term;
sub close_term;
sub connect_board;
sub init_kr_board;
sub collect_counters_ifconfig;
sub setup_kr_board;
sub set_ampred_board;
sub run_command_board;
sub run_ping_test_board;
sub save_clipboard;
sub save_output_board;
sub save_counters_ifconfig;
sub store_counters_ifconfig;
sub store_all_counters_ifconfig;
sub init_log_file;
sub init_res_log_file;
sub finish_log_file;
sub log_counters_ifconfig;

#----------------------------------------------------------------

sub initialize
{
	my $i = 0;
	foreach my $w (@wterm_board) {
		open_term($i);
		$i++;
	}

	$i = 0;
	foreach my $w (@wterm_board) {
		connect_board($w, $krconfig::telnet_ipaddr[$i], $krconfig::telnet_port[$i]);
		$i++;
	}
	
	$i = 0;
	foreach my $w (@wterm_board) {
		init_kr_board($w, $i);
		$i++;
	}	
	
	$i = 0;
	foreach my $w (@wterm_board) {
		collect_counters_ifconfig($w, $i);
		$i++;
	}
	store_all_counters_ifconfig();
	
	# prepare the log
	init_log_file();
	
}

sub terminate
{
	my $i = 0;

	finish_log_file();

	$i = 0;
	foreach my $w (@wterm_board) {
		close_term($w);
		$i++;
	}
}

sub setup_kr
{
	$crt_iteration = $_[0];
	my $preq = $_[1];
	my $pst1q = $_[2];
	my $adpt_eq = $_[3];
	
	my $i = 0;
	foreach my $w (@wterm_board) {
		
		$crt_preq[$i] = $preq;
		$crt_pst1q[$i] = $pst1q;
		$crt_adpt_eq[$i] = $adpt_eq;
		
		setup_kr_board($w, $i);
		$i++;
	}

	# wait a little to stabilize the link
	Time::HiRes::sleep(0.5);	
}

sub set_ampred
{
	$crt_iteration = $_[0];
	my $ampred = $_[1];
	
	my $i = 0;
	foreach my $w (@wterm_board) {
		
		$crt_amp_red[$i] = $ampred;
		
		set_ampred_board($w, $i);
		$i++;
	}

	# wait a little to stabilize the link
	Time::HiRes::sleep(0.5);	
}

sub run_command
{
	my $command = $_[0];
	
	my $i = 0;
	foreach my $w (@wterm_board) {
		run_command_board($w, $command);

		#save_output_board($w);
		$i++;
	}
}

sub run_ping_test
{
	# timeout in seconds:
	my $timeout = $_[0];
	my $i = 0;

	# store prev counters as a baseline for this test
	store_all_counters_ifconfig();

	$i = 0;
	foreach my $w (@wterm_board) {
		run_ping_test_board($w, $i);
		$i++;
	}
	
	# wait timeout
	sleep($timeout);

	# stop ping: CTRL+C
	foreach my $w (@wterm_board) {
		X11::GUITest::SetInputFocus($w);
		Time::HiRes::sleep(0.5);
		# Send CTRL+c to stop ping
		X11::GUITest::SendKeys("^(c)");
		Time::HiRes::sleep(0.5);
	}
	
	# wait a little to be received all frames 
	Time::HiRes::sleep(0.5);
	
	# collect ifconfig counters
	$i = 0;
	foreach my $w (@wterm_board) {
		collect_counters_ifconfig($w, $i);
		$i++;
	}
	
	# log test results
	log_counters_ifconfig();
}

#----------------------------------------------------------------

sub open_term
{
	my $idx = $_[0];
	my $wterm = $wterm_board[$idx];
	
	if ($wterm == 0) {
		# Send CTRL+SHIF+N to Open new terminal
		X11::GUITest::SendKeys("^(+(n))");
		Time::HiRes::sleep(0.5);
		$wterm = X11::GUITest::GetInputFocus();
		Time::HiRes::sleep(0.5);
		
		
		print "Warning: Make sure menu area is visible on both windows at startup !! \n";
		
		# Warning: menu area must be visible on both windows,
		#			otherwise 'Select All' command is not working !
		# resize and move window so that menu area must be visible
		
	# TODO: this API is not working properly !! 
	#	
	#	print "resize and move window \n";
	#	X11::GUITest::ResizeWindow($wterm, 600, 600);
	#	Time::HiRes::sleep(1);
	
	#	X11::GUITest::SetInputFocus($wterm);
	#	Time::HiRes::sleep(0.5);	
	#	X11::GUITest::RaiseWindow($wterm); 
	#	Time::HiRes::sleep(0.5);	
	#	X11::GUITest::MoveWindow($wterm, 500, 100 + $idx * 400);
	#	Time::HiRes::sleep(0.5);
		
		$wterm_board[$idx] = $wterm;
	}
	return $wterm; 
}

sub close_term
{
	my $wterm = $_[0];
	
	X11::GUITest::SetInputFocus($wterm);
	Time::HiRes::sleep(0.5);	
	X11::GUITest::SendKeys("\n");
	Time::HiRes::sleep(0.5);
	
	# Send CTRL+] to close telnet session
	X11::GUITest::SendKeys("^(])");
	Time::HiRes::sleep(0.5);

	# Quit telnet session
	X11::GUITest::SendKeys("quit\n");
	Time::HiRes::sleep(0.5);
	
	# Exit terminal
	X11::GUITest::SendKeys("exit\n");
	Time::HiRes::sleep(0.5);
}

sub connect_board
{
	my $wterm = $_[0];
	my $ip_addr = $_[1];
	my $port = $_[2];

	X11::GUITest::SetInputFocus($wterm);
	Time::HiRes::sleep(0.5);
	
	# telnet to board
	X11::GUITest::SendKeys("\n");
	Time::HiRes::sleep(0.5);
	X11::GUITest::SendKeys("telnet $ip_addr $port\n");
	Time::HiRes::sleep(1);
	X11::GUITest::SendKeys("\n");
	Time::HiRes::sleep(0.5);
	X11::GUITest::SendKeys("\n");
	Time::HiRes::sleep(0.5);
	
	# login just in case
	X11::GUITest::SendKeys("root\n");
	Time::HiRes::sleep(0.5);
}

sub init_kr_board
{
	my $wterm = $_[0];
	my $idx = $_[1];

	X11::GUITest::SetInputFocus($wterm);
	Time::HiRes::sleep(0.5);

	# assign IP address to interface - optional
	X11::GUITest::SendKeys("ifconfig $krconfig::test_intf_name[$idx] $krconfig::test_intf_ipaddr[$idx] netmask $krconfig::test_intf_netmask[$idx]\n");
	Time::HiRes::sleep(0.5);

	# go to debugfs path
	X11::GUITest::SendKeys("cd " . $krconfig::kr_debugfs_path . $krconfig::test_mac_name[$idx] . "/" . $krconfig::test_lane_name[$idx] . "\n");
	Time::HiRes::sleep(0.5);

	# disable training algorithm
	X11::GUITest::SendKeys("echo train_dis > cfg\n");
	Time::HiRes::sleep(0.5);
}

sub collect_counters_ifconfig
{
	my $wterm = $_[0];
	my $idx = $_[1];

	# ifconfig mac
	run_command_board($wterm, "ifconfig $krconfig::test_mac_name[$idx]");
	
	save_output_board($wterm);
	
	save_counters_ifconfig($idx);
}

sub setup_kr_board
{
	my $wterm = $_[0];
	my $idx = $_[1];
	
	X11::GUITest::SetInputFocus($wterm);
	Time::HiRes::sleep(0.5);

	# setup KR
	X11::GUITest::SendKeys("echo $crt_preq[$idx] > set_preq\n");
	Time::HiRes::sleep(0.5);

	X11::GUITest::SendKeys("echo $crt_pst1q[$idx] > set_pstq\n");
	Time::HiRes::sleep(0.5);

	X11::GUITest::SendKeys("echo $crt_adpt_eq[$idx] > set_adpteq\n");
	Time::HiRes::sleep(0.5);

	X11::GUITest::SendKeys("echo 1 > set_apply\n");
	Time::HiRes::sleep(0.5);	
}

sub set_ampred_board
{
	my $wterm = $_[0];
	my $idx = $_[1];
	
	X11::GUITest::SetInputFocus($wterm);
	Time::HiRes::sleep(0.5);

	# set AMP_RED
	X11::GUITest::SendKeys("echo $crt_amp_red[$idx] > set_ampred\n");
	Time::HiRes::sleep(0.5);
}

sub run_command_board
{
	my $wterm = $_[0];
	my $command = $_[1];

	# set window focus
	X11::GUITest::SetInputFocus($wterm);
	Time::HiRes::sleep(0.5);
	
	# clear terminal
	X11::GUITest::SendKeys("reset\n");
	Time::HiRes::sleep(0.5);

	# run comand
	X11::GUITest::SendKeys("$command\n");
	Time::HiRes::sleep(0.5);
}

sub run_ping_test_board
{
	my $wterm = $_[0];
	my $idx = $_[1];
	my $lpi = 0;

	# ping the partner interface
	if ($idx == 0) {
		$lpi = 1; 
	} else {
		$lpi = 0;
	}
	
	# send ping:
	#run_command_board($wterm, "ping $krconfig::test_intf_ipaddr[$lpi]");
	# send ping flood:
	run_command_board($wterm, "ping $krconfig::test_intf_ipaddr[$lpi] -f");
}

sub save_output_board
{
	my $wterm = $_[0];

	# Bring window in foreground
	X11::GUITest::RaiseWindow($wterm); 
	Time::HiRes::sleep(0.5);

	# Select-All from the menu
	X11::GUITest::ClickWindow($wterm, 50, 20, X11::GUITest::M_LEFT);
	Time::HiRes::sleep(0.5);
	X11::GUITest::ClickWindow($wterm, 50, 90, X11::GUITest::M_LEFT);
	Time::HiRes::sleep(0.5);
	
	# Copy: CTRL+SHIFT+C
	X11::GUITest::SetInputFocus($wterm);
	Time::HiRes::sleep(0.5);
	X11::GUITest::SendKeys("^(+(c))");
	Time::HiRes::sleep(0.5);

	# Enter to remove selection
	X11::GUITest::SendKeys("\n");
	Time::HiRes::sleep(0.5);
	
	save_clipboard();
}

sub save_clipboard
{
	# save clipboard in temp file
	system("xclip -o > $temp_file");
}

sub save_counters_ifconfig
{
	my $idx = $_[0];
	
	open(my $fh, '<:encoding(UTF-8)', $temp_file)
  		or die "Could not open file '$temp_file' $!";
 
	while (my $row = <$fh>) {
  		chomp $row;
  		#print "$row\n";

  		# regex match:
		if ($row =~ /RX packets:/) {
			my @stats = ($row =~ /([0-9]+)/g);
			#my @stats = $row =~ /(\d+)/g;
			#print "read/save Rx stats: @stats \n";

	  		# save stats for this board:
			$ifmac_counters[$idx][0] = [@stats];
		}
		elsif ($row =~ /TX packets:/) {
			my @stats = ($row =~ /([0-9]+)/g);
			#print "read/save Tx stats: @stats \n";

	  		# save stats for this board:
			$ifmac_counters[$idx][1] = [@stats];
		}
	}
	close($fh);
}

sub store_counters_ifconfig
{
	my $i = $_[0];
	
	#print "save prev Rx stats \n";
	my $board_stats = $ifmac_counters[$i];
	my $j = 0;
	foreach my $stats (@$board_stats) {
		$prev_ifmac_counters[$i][$j] = [@$stats];
		$j++;
	}
}

sub store_all_counters_ifconfig
{
	my $i = 0, my $j = 0;
	
	#print "save prev Rx stats \n";
	$i = 0;
	foreach my $board_stats (@ifmac_counters) {
		$j = 0;
		foreach my $stats (@$board_stats) {
			$prev_ifmac_counters[$i][$j] = [@$stats];
			$j++;
		}
		$i++;
	}	
}

sub init_log_file
{
	my $name = strftime "%Y-%b-%e_%H_%M_%S", localtime;
	$starttime = strftime "%Y-%b-%e %H:%M:%S", localtime;

	my $fh;
	my $board_str1 = "Board1: $krconfig::board_alias_board_1 ($krconfig::telnet_ipaddr_board_1)";
	my $board_str2 = "Board2: $krconfig::board_alias_board_2 ($krconfig::telnet_ipaddr_board_2)";
	
	# compose log file name
	$logfile_root = $krconfig::logs_dir . $name;
	$logfile_all = $logfile_root . "_all";
	$logfile_res = $logfile_root . "_res";
	
	# full log file
	open($fh, '>', $logfile_all)
  		or die "Could not open file '$logfile_all' $!";
	
	print $fh "\n";
	print $fh "ping test: ifconfig mac counters - full log\n";
	print $fh "Test started at: $starttime \n";
	print $fh "\n";
	printf $fh "| %-50s | %-50s |\n", $board_str1, $board_str2;
	print $fh "-----------------------------------------------------------------------------------------------------------\n";
	#print $fh "\n";
	close($fh);

	init_res_log_file();
}

sub init_res_log_file
{
	my $fh;
	my $board_str1 = "Board1: $krconfig::board_alias_board_1 ($krconfig::telnet_ipaddr_board_1)";
	my $board_str2 = "Board2: $krconfig::board_alias_board_2 ($krconfig::telnet_ipaddr_board_2)";

	# results log file
	open($fh, '>', $logfile_res)
  		or die "Could not open file '$logfile_res' $!";
	
	print $fh "\n";
	print $fh "ping test: ifconfig mac counters - best solutions: top results log\n";
	print $fh "Test started at: $starttime \n";
	print $fh "\n";
	printf $fh "| %-50s | %-50s |\n", $board_str1, $board_str2;
	print $fh "-----------------------------------------------------------------------------------------------------------\n";
	#print $fh "\n";
	close($fh);	
}

sub finish_log_file
{
	my $date = strftime "%Y-%b-%e %H:%M:%S", localtime;
	my $fh;
	
	# full log file
	open($fh, '>>', $logfile_all)
  		or die "Could not open file '$logfile_all' $!";
	
	print $fh "\n";
	print $fh "Test successfully ended all iterations\n";
	print $fh "Test ended at: $date \n";
	print $fh "-----------------------------------------------------\n";
	print $fh "\n";	
	close($fh);

	# results log file
	open($fh, '>>', $logfile_res)
  		or die "Could not open file '$logfile_res' $!";
	
	print $fh "\n";
	print $fh "Test successfully ended all iterations\n";
	print $fh "Test ended at: $date \n";
	print $fh "-----------------------------------------------------\n";
	print $fh "\n";
	close($fh);
}

sub log_counters_ifconfig
{	
	my @rx_pckt;
	my @rx_err;
	my @tx_pckt;
	my @tx_err;
	my @print_sol = (0, 0);
	my $reprint_res_file = 0;
	my $fh;
	my $str1;
	my $str2; 
	
	# calculate test results
	for (my $i = 0; $i < $boards_count; $i++) {
		
		$rx_pckt[$i] = $ifmac_counters[$i][0][0] - $prev_ifmac_counters[$i][0][0];
		$rx_err[$i] = $ifmac_counters[$i][0][1] - $prev_ifmac_counters[$i][0][1];
		$tx_pckt[$i] = $ifmac_counters[$i][1][0] - $prev_ifmac_counters[$i][1][0];
		$tx_err[$i] = $ifmac_counters[$i][1][1] - $prev_ifmac_counters[$i][1][1];
	}

#--------------------------------	
# for test only: set mangled statistics for testing
#	print "testing solution finding \n";
#	if($crt_iteration == 1) {
#		$rx_pckt[0] = 0;
#		$tx_pckt[0] = 0;
#
#		$rx_err[1] = 2000;
#	}
#	elsif($crt_iteration == 2) {
#		$rx_err[0] = 500;
#		$rx_err[1] = 1500;
#	}
#	elsif($crt_iteration == 3) {
#		$rx_err[0] = 0;
#		$rx_err[1] = 1200;			
#	}
#	elsif($crt_iteration == 4) {
#		$rx_err[0] = 0;
#		$rx_err[1] = 500;			
#	}
#	elsif($crt_iteration == 5) {
#		$rx_err[0] = 200;
#		$rx_err[1] = 800;			
#	}
# end of test only
#--------------------------------	

	# write test results to: full log file	
	open($fh, '>>', $logfile_all)
  		or die "Could not open file '$logfile_all' $!";

	$str1 = "Iteration: $crt_iteration";
	$str2 = "Iteration: $crt_iteration";
	printf $fh "| %-50s | %-50s |\n", $str1, $str2;
	
	$str1 = "PREQ = $crt_preq[0], PST1Q = $crt_pst1q[0], ADAPT_EQ = $crt_adpt_eq[0], AMP_RED = $crt_amp_red[0]";
	$str2 = "PREQ = $crt_preq[1], PST1Q = $crt_pst1q[1], ADAPT_EQ = $crt_adpt_eq[1], AMP_RED = $crt_amp_red[1]";
	printf $fh "| %-50s | %-50s |\n", $str1, $str2;
	
	$str1 = "Rx packets = $rx_pckt[0]";
	$str2 = "Rx packets = $rx_pckt[1]";
	printf $fh "| %-50s | %-50s |\n", $str1, $str2;

	$str1 = "Rx errors = $rx_err[0]";
	$str2 = "Rx errors = $rx_err[1]";
	printf $fh "| %-50s | %-50s |\n", $str1, $str2;

	$str1 = "Tx packets = $tx_pckt[0]";
	$str2 = "Tx packets = $tx_pckt[1]";
	printf $fh "| %-50s | %-50s |\n", $str1, $str2;

	$str1 = "Tx errors = $tx_err[0]";
	$str2 = "Tx errors = $tx_err[1]";
	printf $fh "| %-50s | %-50s |\n", $str1, $str2;
	
	print $fh "-----------------------------------------------------------------------------------------------------------\n";
	#print $fh "\n";
	
	close($fh);
	
	# check if this is a good solution
	$reprint_res_file = 0;
	my $lp_i = 0;
	for (my $i = 0; $i < $boards_count; $i++) {
		
		if ($i == 0) {
			$lp_i = 1;
		} else {
			$lp_i = 0;
		}
		
		$print_sol[$i] = 0;
		
		if ($rx_pckt[$i] == 0 || $tx_pckt[$lp_i] == 0) {
			# reject: this is not a good solution
		} else {
			
			if ($best_rxerr[$i] == -1) {
				# first valid solution found is the best solution so far
				$best_rxerr[$i] = $rx_err[$i];

				# clear the list of best solutions
				init_res_log_file();
				$reprint_res_file = 1;

				$top_solutions[$i] = ();
				$count_solutions[$i] = 0;
				# append this solution to the list of best solutions
				$top_solutions[$i][$count_solutions[$i]] = [($crt_iteration, $rx_pckt[$i], $rx_err[$i], $tx_pckt[$i], $crt_preq[$lp_i], $crt_pst1q[$lp_i], $crt_adpt_eq[$lp_i], $crt_amp_red[$lp_i])];
				$count_solutions[$i]++;

				$print_sol[$i] = 1;
						
			} else {

				if ($rx_err[$i] == $best_rxerr[$i]) {
					# solution just as good
					
					# append this solution to the list of best solutions
					$top_solutions[$i][$count_solutions[$i]] = [($crt_iteration, $rx_pckt[$i], $rx_err[$i], $tx_pckt[$i], $crt_preq[$lp_i], $crt_pst1q[$lp_i], $crt_adpt_eq[$lp_i], $crt_amp_red[$lp_i])];
					$count_solutions[$i]++;
					
					$print_sol[$i] = 1;
				}
				elsif ($rx_err[$i] < $best_rxerr[$i]) {
					# found a better solution: replace it
					$best_rxerr[$i] = $rx_err[$i];
	
					# clear the list of best solutions and add only this solution on top
					init_res_log_file();
					$reprint_res_file = 1;
		
					$top_solutions[$i] = ();
					$count_solutions[$i] = 0;
					# append this solution to the list of best solutions
					$top_solutions[$i][$count_solutions[$i]] = [($crt_iteration, $rx_pckt[$i], $rx_err[$i], $tx_pckt[$i], $crt_preq[$lp_i], $crt_pst1q[$lp_i], $crt_adpt_eq[$lp_i], $crt_amp_red[$lp_i])];
					$count_solutions[$i]++;

					$print_sol[$i] = 1;
				}
				# all other solutions are worse so they are ignored
			}
		}			
	}
	
#	print "print_sol: $print_sol[0] , $print_sol[1] \n";
#	print "rx_err = $rx_err[0] , $rx_err[1] \n";

#	print "--- printing top_solutions: \n";
#	foreach my $top_sol (@top_solutions) {
#		foreach my $sol (@$top_sol) {
#			foreach my $val (@$sol) {
#				print " $val ";
#			}
#			print "\n";
#		}
#	}	

	if ($print_sol[0] == 1 || $print_sol[1] == 1) {

		#print "opening res file \n";

		my @idx = (0, 0);
		my @iter = (0, 0);

		if ($reprint_res_file == 0) {
			
			# just append to the res file the last solution
			$idx[0] = $count_solutions[0] - 1;
			$idx[1] = $count_solutions[1] - 1;
		} else {
						
			# reprint the entire res file because the best solution so far has changed			
			$idx[0] = 0;
			$idx[1] = 0;			
		}

		# write test results to: results log file
		open($fh, '>>', $logfile_res)
	  		or die "Could not open file '$logfile_res' $!";

		while ($idx[0] < $count_solutions[0] || $idx[1] < $count_solutions[1]) {

			if ($reprint_res_file == 0) {
				# just append to the res file the last solution
			} else {
				# reprint the entire res file because the best solution so far has changed
				
				if ($idx[0] >= 0 && $idx[0] < $count_solutions[0]) {
					$iter[0] = $top_solutions[0][$idx[0]][0];
				} else {
					$iter[0] = -1;
				}
				
				if ($idx[1] >= 0 && $idx[1] < $count_solutions[1]) {
					$iter[1] = $top_solutions[1][$idx[1]][0];
				} else {
					$iter[1] = -1;
				}
				
				# print only smaller iteration or both if they are equal
				if ($iter[0] >= 0 && $iter[1] >= 0) {
					if ($iter[0] == $iter[1]) {
						$print_sol[0] = 1;
						$print_sol[1] = 1;
					} elsif ($iter[0] < $iter[1]) {
						$print_sol[0] = 1;
						$print_sol[1] = 0;
					} else {
						$print_sol[0] = 0;
						$print_sol[1] = 1;
					}
					
				} elsif ($iter[0] >= 0) {
					$print_sol[0] = 1;
				} elsif ($iter[1] >= 0) {
					$print_sol[1] = 1;
				}				
			}

			# print crt iteration for LD: stats on board B1 means stats for local board B1
			if ($print_sol[0] == 1 && $idx[0] >= 0 && $idx[0] < $count_solutions[0]) {
				$str1 = "Iteration: $top_solutions[0][$idx[0]][0]";
			} else {
				$str1 = "";
			}
			if ($print_sol[1] == 1 && $idx[1] >= 0 && $idx[1] < $count_solutions[1]) {
				$str2 = "Iteration: $top_solutions[1][$idx[1]][0]";
			} else {
				$str2 = "";
			}
			printf $fh "| %-50s | %-50s |\n", $str1, $str2;

			# print parameters solution for LP: Rx errors on board B1 means good Tx parameters for the partner board B2   
			if ($print_sol[1] == 1 && $idx[1] >= 0 && $idx[1] < $count_solutions[1]) {
				$str1 = "PREQ = $top_solutions[1][$idx[1]][4], PST1Q = $top_solutions[1][$idx[1]][5], ADAPT_EQ = $top_solutions[1][$idx[1]][6], AMP_RED = $top_solutions[1][$idx[1]][7]";
			} else {
				$str1 = ""; #"not ok"
			}
			if ($print_sol[0] == 1 && $idx[0] >= 0 && $idx[0] < $count_solutions[0]) {
				$str2 = "PREQ = $top_solutions[0][$idx[0]][4], PST1Q = $top_solutions[0][$idx[0]][5], ADAPT_EQ = $top_solutions[0][$idx[0]][6], AMP_RED = $top_solutions[0][$idx[0]][7]";
			} else {
				$str2 = ""; #"not ok"
			}
			printf $fh "| %-50s | %-50s |\n", $str1, $str2;
			
			# print statistics solution for LD: stats on board B1 means stats for local board B1
			if ($print_sol[0] == 1 && $idx[0] >= 0 && $idx[0] < $count_solutions[0]) {
				$str1 = "Rx packets = $top_solutions[0][$idx[0]][1]";
			} else {
				$str1 = ""; #not ok
			}
			if ($print_sol[1] == 1 && $idx[1] >= 0 && $idx[1] < $count_solutions[1]) {
				$str2 = "Rx packets = $top_solutions[1][$idx[1]][1]";
			} else {
				$str2 = ""; #not ok
			}
			printf $fh "| %-50s | %-50s |\n", $str1, $str2;
		
			if ($print_sol[0] == 1 && $idx[0] >= 0 && $idx[0] < $count_solutions[0]) {
				$str1 = "Rx errors = $top_solutions[0][$idx[0]][2]";
			} else {
				$str1 = "";
			}
			if ($print_sol[1] == 1 && $idx[1] >= 0 && $idx[1] < $count_solutions[1]) {
				$str2 = "Rx errors = $top_solutions[1][$idx[1]][2]";
			} else {
				$str2 = "";
			}
			printf $fh "| %-50s | %-50s |\n", $str1, $str2;
		
			if ($print_sol[0] == 1 && $idx[0] >= 0 && $idx[0] < $count_solutions[0]) {
				$str1 = "Tx packets = $top_solutions[0][$idx[0]][3]";
			} else {
				$str1 = "";
			}
			if ($print_sol[1] == 1 && $idx[1] >= 0 && $idx[1] < $count_solutions[1]) {
				$str2 = "Tx packets = $top_solutions[1][$idx[1]][3]";
			} else {
				$str2 = "";
			}
			printf $fh "| %-50s | %-50s |\n", $str1, $str2;
		
			#not useful
			#$str1 = "Tx errors = $tx_err[0]";
			#$str2 = "Tx errors = $tx_err[1]";
			#printf $fh "| %-50s | %-50s |\n", $str1, $str2;

			print $fh "-----------------------------------------------------------------------------------------------------------\n";
			#print $fh "\n";

			# increment indeces			
			if ($reprint_res_file == 0) {
				# just append to the res file the last solution
				if ($idx[0] < $count_solutions[0]) {
					$idx[0]++;
				}
				if ($idx[1] < $count_solutions[1]) {
					$idx[1]++;
				}				
			} else {
				# reprint the entire res file because the best solution so far has changed
				if ($print_sol[0] == 1 && $idx[0] < $count_solutions[0]) {
					$idx[0]++;
				}
				if ($print_sol[1] == 1 && $idx[1] < $count_solutions[1]) {
					$idx[1]++;
				}
			}
						
		} #while
	
		#print "exit sol print while, closing res file \n";
	
		close($fh);
	}
}

#----------------------------------------------------------------

1;