
#!/usr/bin/perl -w
#
# check_hyperv.pl - Nagios Plugin
#

use strict;
use Getopt::Long;
use vars qw($PROGNAME);
use lib "/usr/lib/nagios/plugins"; # Pfad zur util.pm !!
use utils qw ($TIMEOUT %ERRORS &print_revision &support);
use List::MoreUtils qw(first_index);
use String::Escape qw( printable unprintable );

sub print_help ();
sub print_usage ();

my ($opt_V, $opt_h, $opt_m, $opt_H, $opt_u, $opt_p,  $opt_w, $opt_c, $opt_t, $opt_U, $opt_P);
my ($ok, $anzeige, @anzeige, $on, $off, @onlineoffline, $onoff, $percent, @memoryresults, $memory, $list, $load, $output, @resultslist, @resultsload, @arguments, $message, $size, $size2, $critical, $warning);
my ($osversion, @resultosversion);

$PROGNAME="check_hyperv";


Getopt::Long::Configure('bundling');
GetOptions(
        "h"   => \$opt_h, "help"        => \$opt_h,
        "U=s" => \$opt_U, "localuser"   => \$opt_U,
        "P=s" => \$opt_P, "localpassword" => \$opt_P,
        "m=s" => \$opt_m, "mode"        => \$opt_m,
        "H=s" => \$opt_H, "hostname"    => \$opt_H,
        "u=s" => \$opt_u, "username"    => \$opt_u,
        "p=s" => \$opt_p, "password"    => \$opt_p,
        "w=s" => \$opt_w, "warning=s"   => \$opt_w,
        "c=s" => \$opt_c, "critical=s"  => \$opt_c,
        "t=i" => \$opt_t, "timeout" => \$opt_t);

if ($opt_t) {
        $TIMEOUT=$opt_t;
}

# Timout bei Problemen
$SIG{'ALRM'} = sub {
        print "UNKNOWN - Plugin Timed out\n";
        exit $ERRORS{"UNKNOWN"};
};
alarm($TIMEOUT);

if ($opt_h) {
        print_help();
        exit $ERRORS{'OK'};
}

if (! $opt_m) {
        print "No mode specified\n\n";
        print_usage();
        exit $ERRORS{'UNKNOWN'};
}

if (! $opt_H) {
        print "No Hostname specified\n\n";
        print_usage();
        exit $ERRORS{'UNKNOWN'};
}

if ((! $opt_c) && (($opt_m ne "hyperv"))) {
        print "No critical threshold specified\n\n";
        print_usage();
        exit $ERRORS{'UNKNOWN'};
}

if ((! $opt_w) && (($opt_m ne "hyperv"))) {
        print "No warning threshold specified\n\n";
        print_usage();
        exit $ERRORS{'UNKNOWN'};
}


sub print_usage () {
        print "Usage:\n";
        print "  $PROGNAME -H <hostname> -m mode [-w <INTEGER> -c <INTEGER>]\n";
        print "  $PROGNAME [-h | --help]\n";

}

sub print_help () {
        print_usage();
        print "\n";
        print "  <help>  Nagios Plugin for Hyper-V Application running on Windows Server\n\n\t\t-m\thyperv|volumes\n\t\t\tFor using the mode Volumes you have to specify thresholds!\n ";
        print "\n";
#        support();
}

if ( defined $opt_U ) {
        if ($opt_U ne "\$") {
                $opt_u = $opt_U;
        }
}

if ( defined $opt_P ) {
        if ($opt_U ne "\$") {
                $opt_p = $opt_P;
        }
}

$osversion = "wmic -U" . printable($opt_u) . "%" . printable($opt_p) . " //" . $opt_H . " \"Select Version from Win32_OperatingSystem\" --namespace=root/CIMV2";
@resultosversion = split(/\n/,`$osversion`);
$osversion =  $resultosversion[2];

use Switch;
switch ($opt_m) {
        case "hyperv" {


                #commands

                if ($osversion ge "6.3.0000") {
                        $list = "wmic -U" . printable($opt_u) . "%" . printable($opt_p) . " //" . $opt_H . " \"Select ElementName, OnTimeInMilliseconds from MSVM_ComputerSystem\" --namespace=root/virtualization/V2";
                        $load = "wmic -U" . printable($opt_u) . "%" . printable($opt_p) . " //" . $opt_H . " \"Select LoadPercentage FROM Msvm_processor\" --namespace=root/virtualization/V2";
                        $memory = "wmic -U" . printable($opt_u) . "%" . printable($opt_p) . " //" . $opt_H . " \"Select VirtualQuantity FROM Msvm_MemorySettingData\" --namespace=root/virtualization/V2";
                        $onoff = "wmic -U" . printable($opt_u) . "%" . printable($opt_p) . " //" . $opt_H . " \"Select enabledstate from MSVM_ComputerSystem\" --namespace=root/virtualization/V2";
                } else {

                        $list = "wmic -U" . printable($opt_u) . "%" . printable($opt_p) . " //" . $opt_H . " \"Select ElementName, OnTimeInMilliseconds from MSVM_ComputerSystem\" --namespace=root/virtualization";
                        $load = "wmic -U" . printable($opt_u) . "%" . printable($opt_p) . " //" . $opt_H . " \"Select LoadPercentage FROM Msvm_processor\" --namespace=root/virtualization";
                        $memory = "wmic -U" . printable($opt_u) . "%" . printable($opt_p) . " //" . $opt_H . " \"Select VirtualQuantity FROM Msvm_MemorySettingData\" --namespace=root/virtualization";
                        $onoff = "wmic -U" . printable($opt_u) . "%" . printable($opt_p) . " //" . $opt_H . " \"Select enabledstate from MSVM_ComputerSystem\" --namespace=root/virtualization";
                }
                #Arrays
                @resultslist = split(/\|/,`$list`);
                @resultsload = split(/\|/,`$load`);
                @memoryresults = split(/\|/,`$memory`);
                @onlineoffline = split(/\|/,`$onoff`);

                #handling and output
                $on=0;
                $off=0;
                for (my $i=5 ; $i <= $#onlineoffline; $i +=2) {
                        if ($onlineoffline[$i]==2){$on++;}
                        if ($onlineoffline[$i]==3){$off++;}
                  }
                print "OK: $on VM's online, $off VM's offline\n";


                for (my $i=7 ; $i <= $#resultslist; $i +=3) {

                   for (my $j=1 ; $j < $#memoryresults; $j++){

                        my $idxx = first_index {$_ =~ /$resultslist[$i+1]/} @memoryresults;
                        $memoryresults[$idxx+1]=~ m/(\d*)\n/;
                        print "$1 - "; last;
                   }
                        my $idx = first_index {$_ =~ /$resultslist[$i+1]/} @resultsload;
                        $resultslist[$i+2] =~ m/(\d*)/;
                        my $time=$1;
                        $time = int($time/60000);
                                my $days = int($time/(60*24));
                                my $hours = int(($time-60*24*$days)/60);
                                my $mins = $time % 60;
                        printf "%02d:%02d:%02d - ",$days,$hours,$mins;
                        print "$resultsload[$idx-2] - $resultslist[$i]\n";

                }

                ##Performancedata
                print "|";
                for (my $i=7 ; $i <= $#resultslist; $i +=3) {
                        my $idx = first_index {$_ =~ /$resultslist[$i+1]/} @resultsload;
                        print "CPU_Percantage_$resultslist[$i]=$resultsload[$idx-2];;;; \n";
                }

                exit $ERRORS{'OK'};

        }
        case "volumes" {

                #commands
                $list = "wmic -U" . $opt_u . "%" . $opt_p . " //" . $opt_H . " \"Select Label, Capacity, FreeSpace from win32_volume\"";

                #arrays
                @resultslist = split(/\|/,`$list`);
                @anzeige = split(/\|/,`$list`);

        #output first line
        $warning=0; $critical=0; $ok=0;
        for (my $k=3 ; $k < $#anzeige; $k +=3) {
                if ($anzeige[$k+3]=~ /^(\w*)/){
                                $anzeige[$k] =~ m/(\n\d*)/;
                                $size=sprintf("%.2f",$anzeige[$k+2]/=1073741824);
                                $size2=$1;

                                if ($size2>0 && $size>0){
                                        $size2=sprintf("%.2f",$size2/=1073741824);
                                        $percent=sprintf("%.2f",(100-($size*100/$size2)));
                                }
                                else {last;}

                        if ($percent >= $opt_c) {
                        $critical++;            }

                        if ($percent >= $opt_w) {
                        $warning++;            }

                        else {$ok++;}

                }
        }
        print "OK: $ok - WARNING: $warning - CRITICAL: $critical\n";

                #handling and output
                for (my $i=3 ; $i < $#resultslist; $i +=3) {
                        if ($resultslist[$i+3]=~ /^(\w*)/)
                        {
                        ##Label
                                $resultslist[$i+3] =~ m/([A-Za-z_0-9 ]*)/;
                                print "$1:\n";
                                $resultslist[$i] =~ m/(\n\d*)/;

                        ##size, free space
                            $size=sprintf("%.2f",$resultslist[$i+2]/=1073741824);
                                $size2=$1;

                                if ($size2>0 && $size>0){
                                        $size2=sprintf("%.2f",$size2/=1073741824);
                                        $percent=sprintf("%.2f",(100-($size*100/$size2)));
                                }
                                else {print "leer\n\n";last;}

                        ##CRITICAL
                           if ($percent >= $opt_c) {
                                $critical =1;
                                print "$size(GB free) - $size2(GB) - $percent% : CRITICAL\n\n";
                           }

                        ##WARNING
                          elsif ($percent >= $opt_w) {
                                $warning=1;
                                print "$size(GB free) - $size2(GB) - $percent% : WARNING\n\n";
                           }

                        ##OK
                           else {
                                print "$size(GB free) - $size2(GB) - $percent%\n\n";
                           }
                        }
                }

        print "WARNING: $opt_w\nCRITICAL: $opt_c\n";

                if ($critical==1){
                        exit $ERRORS{'CRITICAL'};}
                if ($warning==1){
                        exit $ERRORS{'WARNING'};}
                else {exit $ERRORS{'OK'};}
        }
}

