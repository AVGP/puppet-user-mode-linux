# Class: UML
#
# This module allows to set up a host for UML containers 
#
# Parameters:
#   $switch_net_dev: The switched network device (e.g. "tap0")
#   $host_net_dev: The primary host network device (e.g. "eth0")
#   $guest_net_addr: The network part of the host IP space (e.g. "10.10.10.1")
# Actions: 
# Requires: stdlib
# Sample Usage:
#

# [Remember: No empty lines between comments and class definition]
#
class user-mode-linux {}

define user-mode-linux::host($switch_net_dev, $host_net_dev, $guest_net_addr) {
  include stdlib

  package { 'wget': ensure => present}
  package { 'bridge-utils':    ensure => present }
  package { 'debootstrap':     ensure => present }
  package { 'realpath':        ensure => present }

  file { '/usr/local/bin/create-container':
    mode   => '0755',
    source => 'puppet:///modules/user-mode-linux/create-container',
  }

  exec { 'enable IP Forward': command => '/bin/echo "1" &> /proc/sys/net/ipv4/ip_forward' }
  exec { 'enable NATting': command => "/sbin/iptables -t nat -A POSTROUTING -o ${host_net_dev} -j MASQUERADE" }

  augeas{ "add network device" :
    context => "/files/etc/network/interfaces",
    changes => [
        "set iface[last()+1] ${switch_net_dev}",
        "set iface[last()]/family inet",
        "set iface[last()]/method static",
        "set iface[last()]/address ${guest_net_addr}",
        "set iface[last()]/netmask 255.255.255.0",
        "set iface[last()]/tunctl_user uml-net",
    ],
  } ~>

#  file_line { 'Add switched device':
#    path => '/etc/network/interfaces',
#    line => "iface ${switch_net_dev} inet static address ${guest_net_addr} netmask 255.255.255.0 tunctl_user uml-net"
#  } ~>

  file_line { 'Set the switched device to auto':
    path => '/etc/network/interfaces',
    line => "auto ${switch_net_dev}"
  } ~>

  package { 'user-mode-linux': ensure => present } ~>
  package { 'uml-utilities':   ensure => present } ~>

  user { 'uml-net':
    ensure => present,
  } ~>

  exec {"/sbin/ifup ${switch_net_dev}":
    command => "/etc/init.d/uml-utilities stop && /sbin/ifup ${switch_net_dev} && /etc/init.d/uml-utilities start",
    unless  => "/sbin/ifconfig | grep ${switch_net_dev}",
  }
}
