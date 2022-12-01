# KR config package
# 							       							 
# Author: Florin Iordache
#
# Copyright 2019 NXP

package krconfig;

use strict;
use warnings;


# KR system: LX2160

# global variables

#-------------------------------------------------------------------

# Board 1 configs: stan
our $board_alias_board_1 = "stan";

# telnet connection
our $telnet_ipaddr_board_1 = "10.171.94.193";
our $telnet_port_board_1 = "1082"; 

# linux interfaces
our $test_intf_name_board_1 = "eth1";
our $test_mac_name_board_1 = "mac3";
our $test_intf_ipaddr_board_1 = "10.10.1.1";
our $test_intf_netmask_board_1 = "255.255.255.0";
our $test_lane_name_board_1 = "lane0";


#-------------------------------------------------------------------

# Board 2 configs: bran
our $board_alias_board_2 = "bran";

# telnet connection
our $telnet_ipaddr_board_2 = "10.171.95.207";
our $telnet_port_board_2 = "1082"; 

# linux interfaces
our $test_intf_name_board_2 = "eth1";
our $test_mac_name_board_2 = "mac3";
our $test_intf_ipaddr_board_2 = "10.10.1.2";
our $test_intf_netmask_board_2 = "255.255.255.0";
our $test_lane_name_board_2 = "lane0";


#-------------------------------------------------------------------

# Global configs

our $kr_debugfs_path = "/sys/kernel/debug/fsl_backplane/";

our $logs_dir = "./logs/";

#-------------------------------------------------------------------

# Both Boards configs
our @board_alias = ($board_alias_board_1, $board_alias_board_2);

# telnet connection
our @telnet_ipaddr = ($telnet_ipaddr_board_1, $telnet_ipaddr_board_2);
our @telnet_port = ($telnet_port_board_1, $telnet_port_board_2); 

# test linux interfaces
our @test_intf_name = ($test_intf_name_board_1, $test_intf_name_board_2);
our @test_mac_name = ($test_mac_name_board_1, $test_mac_name_board_2);
our @test_intf_ipaddr = ($test_intf_ipaddr_board_1, $test_intf_ipaddr_board_2);
our @test_intf_netmask = ($test_intf_netmask_board_1, $test_intf_netmask_board_2);
our @test_lane_name = ($test_lane_name_board_1, $test_lane_name_board_2);


#-------------------------------------------------------------------

1;