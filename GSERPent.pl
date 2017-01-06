#if you run it on nix/osx it wont delete the temp file yet

#Created by Phill Moore - randomaccess3@gmail.com

#Version History
# 20161222 	- initial commit
# 20161223 	- add psi, start parsing and additional url from iacis listserv 
#			- added redirect link and url parameter parsing/note
# 20161225 	- add safe, pws
# 20161226	- add ust (time parameter)
#			- option for input from a file
#			- cd  (results link position)
# 20170104  - fixed spacing error in file parsing
#			- ie parameter
#			- add bih/biw parameter
#			- started rlz parameter
#			- added tbm
#
# 20170105  - updated GWS_RD, added client, formatting, sig2
#			- added stubs for cad, esrc, rct, sa, uact, usg, web
#
#
#To Install
# ppm install URI (which I think comes with perl now)
# requires python 2.7 installed to run the EI parser
# Automatically downloads the python EI parser if its not detected


#To do ; put in download code for EI parser 
# separate # from URL as it denotes a second search
# include the proto code for python
# probably port to python

# Known bug
# Doesnt deal with # in search
# Doesn't remove +'s in q or oq value

#Research
# http://www.ramdynamo.com/2014/03/google-gferdcr-url-mystery-revealed.html
# https://cs.chromium.org/chromium/src/chrome/common/search/instant_types.h?q=aqs&sq=package:chromium&dr=C&l=181
# https://gist.github.com/sshay77/4b1f6616a7afabc1ce2a


# Old VED/New VED - https://deedpolloffice.com/blog/articles/decoding-ved-parameter

#Original Query - If the original query is less than the q value then it's possible that the user has clicked on a suggested post - need more research on the topic


my $ved_parser = "/Users/phill/Desktop/GoogleURLParser/protobuff/ved-decoder-master/ved.py";


use Data::Dumper;
use URI::Escape;
use strict;

use Getopt::Long;
use File::Spec;

my %config;
Getopt::Long::Configure("prefix_pattern=(-|\/)");
GetOptions(\%config,qw(url|u=s file|f=s help|?|h));

my $VERSION = "20161226";
my @alerts = ();

if ($config{help} || !%config) {
	_help();
	exit;
}

my $url; 
if ($config{url}) {
	$url = $config{url};
	printEqDivider();
	print $url."\n";
	printEqDivider();
	parse_URL($url);
	print "\n";
}
elsif ($config {file}){
	my $count = 0;
	open(FH,"<",$config{file});
	foreach my $line (<FH>){
		chomp $line;

		next if ($line =~ m/^\#.*/);
		next if ($line =~ m/^$/);
		my $comment;
		($url,$comment) = split /\|/, $line;
		$count++;
		printEqDivider();
		print $count.": ".$url."\n";
		print "Comment: $comment\n" if ($comment);
		printEqDivider();
	
		parse_URL($url);
		print "\n";
	}
	close(FH);
	printDivider();
}
else {
		return undef;
}

sub parse_URL($){
	my @alerts = "";
	my %parameters = {};
	my $url = shift;
	
	
	$url =~ s/^http[s]:\/\///g if ($url =~ m/^http[s]:\/\//);
	
	# $url =~ s/^https\:\/\/[w*\.]google\..*\/(a-z*)\?//;
	#remove http://www.google.com.*/.*?
	my ($google, @rest) = split /\//, $url;
	$url = join('\/', @rest);
	$url =~ s/\\\//\//g;
		
	$url =~ s/\?/\n/g;
	$url =~ s/\&/\n/g;
	
	# If a hash exists in the URL then the previous search was before the hash and the current search was in the q after the hash
	if ($url =~ m/#/){
			push @alerts, "# indicates second search - not implemented currently";
	} 
	
	$url =~ s/\#/\n/g;
	
	#remove spaces
	$url =~ s/ //g;
	
	#print "URL:".$url."\n";

	my @urlentries = split /\n/, $url;
	
		
	#load hash with parameters
	my $u;
	foreach $u (@urlentries){
		$parameters{$1} = uri_unescape($2) if ($u =~ m/(.*)=(.*)/g); # may need to run uri_unescape twice
	}

	$u = "";
	
	#If the q and oq exist and arent equal
	if (exists($parameters{"q"}) && (exists($parameters{"oq"})) && ($parameters{"q"} ne $parameters{"oq"})){
			push @alerts, "Either additional search, or suggested search was suggested from search bar (tested on chrome)";
	} 
	
	foreach $u (sort keys %parameters){
		
		#Unsure why the hash has a HASH -> undef entry in it, this line skips it
		next if (!defined($parameters{$u}));
		
		
		# Sends the parameter value to the subroutine for parsing
		# result is returned and printed on a new line with the parameter name
		$parameters{$u} = parse_EI($parameters{$u}) if ($u eq "ei");
		$parameters{$u} = parse_GFE_RD($parameters{$u}) if ($u eq "gfe_rd");
		$parameters{$u} = parse_GWS_RD($parameters{$u}) if ($u eq "gws_rd");
		$parameters{$u} = parse_GFNS($parameters{$u}) if ($u eq "gfns");
		$parameters{$u} = parse_PSI($parameters{$u}) if ($u eq "psi");
		$parameters{$u} = parse_Start($parameters{$u}) if ($u eq "start");
		$parameters{$u} = parse_pws($parameters{$u}) if ($u eq "pws");
		$parameters{$u} = parse_safe($parameters{$u}) if ($u eq "safe");
		$parameters{$u} = parse_ust($parameters{$u}) if ($u eq "ust");
		$parameters{$u} = parse_VED($parameters{$u}) if ($u eq "ved");
		$parameters{$u} = parse_sourceid($parameters{$u}) if ($u eq "sourceid");
		$parameters{$u} = parse_aqs($parameters{$u}) if ($u eq "aqs");
		$parameters{$u} = parse_rlz($parameters{$u}) if ($u eq "rlz");	
		$parameters{$u} = parse_tbm($parameters{$u}) if ($u eq "tbm");	
		$parameters{$u} = parse_client($parameters{$u}) if ($u eq "client");
		$parameters{$u} = parse_q($parameters{$u}) if ($u eq "q");	
		$parameters{$u} = parse_cad($parameters{$u}) if ($u eq "cad");	
		$parameters{$u} = parse_esrc($parameters{$u}) if ($u eq "esrc");	
		$parameters{$u} = parse_rct($parameters{$u}) if ($u eq "rct");	
		$parameters{$u} = parse_uact($parameters{$u}) if ($u eq "uact");	
		$parameters{$u} = parse_sa($parameters{$u}) if ($u eq "sa");
		$parameters{$u} = parse_usg($parameters{$u}) if ($u eq "usg");		
		$parameters{$u} = parse_source($parameters{$u}) if ($u eq "source");		
		$parameters{$u} .= "\t\t(A user was logged in)" if ($u eq "sig2"); # https://moz.com/blog/decoding-googles-referral-string-or-how-i-survived-secure-search
		$parameters{$u} .= "\t\t\t\t(Screen Resolution - Height)" if ($u eq "bih"); #https://www.reddit.com/r/explainlikeimfive/comments/2ecozy/eli5_when_you_search_for_something_on_google_the/
		$parameters{$u} .= "\t\t\t\t(Screen Resolution - Width)" if ($u eq "biw");
		$parameters{$u} .= "\t\t(Link number - further testing required)" if ($u eq "cd");
		$parameters{$u} .= "\t\t\t\t(Original Query)" if ($u eq "oq");
		$parameters{$u} .= "\t\t\t\t(Input Encoding)" if ($u eq "ie");   #joostdevalk.nl - google websearch parameters
		$parameters{$u} .= "\t\t\t\t(Output Encoding)" if ($u eq "oe");   #joostdevalk.nl - google websearch parameters
		$parameters{$u} .= "\t\t(Usually indicates that this was opened in a new tab/window from the Search Results page)" if ($u eq "url");
		
		print "$u=$parameters{$u}\n";
		
	}

	#printDivider();
	#print scalar(@alerts)."\n";
	#printDivider();
	
	if (scalar(@alerts) > 1) {
		printDivider();
		print "Alerts:";
		foreach (@alerts) {
			print $_."\n";
		}
	}
	@alerts = "";
	return;
}

sub parse_PSI($){
	my $psi = shift;
	my ($ei, $unix, $unknown) = split /\./, $psi;
	
	
	my $command = "python google-ei-time.py -q -e \"".$ei."\" > temp";
	system (qq{$command});
	$ei = readTemp("temp")." UTC";
	system (qq{del temp});
	
	#$unix last three digits removed to make it a unix timestamp. Should match the EI timestamp
	$unix = substr($unix, 0, -3);
	$unix = gmtime($unix);
	
	$psi .= "\t\t($ei,$unix,$unknown)";
	return $psi;
}

#indicates the start of a session
#can reliably get this value if you go to Google's homepage on chrome
sub parse_EI($){
	my $ei = shift;
	
	my $command = "python google-ei-time.py -q -e \"".$ei."\" > temp";
	#print $command."\n";
	system (qq{$command});
	$ei .= "\t\t(".readTemp("temp")." UTC) - Session Start Time - Set by Google's Time Servers to indicate the start of a session";
	system (qq{del temp});
	return $ei;
}

sub parse_GFE_RD($){
	my $gfe_rd = shift;
	return "$gfe_rd\t\t\t\t(Country Redirect - Direct to your countries Google homepage)" if ($gfe_rd eq "cr");
	return $gfe_rd;
}

sub parse_q($){
	my $q = shift;
	return "$q\t\t(Query not passed to search URL)" if ($q eq "");
	return "$q\t\t(Query that Search results are returned for)";

}


# On Chrome
# Go to google.com - redirect to .com.au and no gws_RD
# go to google.com.au - no EI or gfe_rd, but gws_rd
# go to https://www.google.com.au - no parameters, just search term
# On IE
# Similar, except when searching from the URL bar you get the cr,ssl value
sub parse_GWS_RD($){
	my $gws_rd = shift;
	return "$gws_rd\t\t\t\t(Redirect to SSL site)" if ($gws_rd eq "ssl");
	return "$gws_rd\t\t\t\t(Country Redirect and Redirect to SSL site - so far only seen on IE)" if ($gws_rd eq "cr,ssl");
	return $gws_rd;
}



sub parse_GFNS($){
	my $gfns = shift;
	return "$gfns\t\t\t\t(I'm feeling lucky - first organic result will be accessed)" if ($gfns eq "1");
	return $gfns;
}

sub parse_sourceid($){
	my $sourceid = shift;
	return "$sourceid\t\t\t\t(Google Chrome)" if ($sourceid eq "chrome");
}

sub parse_client($){
	my $client = shift;
	return "$client\t\t\t(Mozilla Firefox)" if ($client eq "firefox-b");
	return "$client\t\t\t(Mozilla Firefox - Search using Address Bar)" if ($client eq "firefox-b-ab");
	return $client
}


# http://superuser.com/questions/653295/what-is-the-aqs-parameter-in-google-search-query
# Confirmed that the third parameter within this parameter (split by .'s) is number of milliseconds from initial keypress - if it exists
# so far can get this value when typing in chrome, but not in google search box on homepage
# aqs stands for Assisted query stats 
# https://cs.chromium.org/chromium/src/chrome/common/search/instant_types.h
sub parse_aqs($){
	my $aqs = shift;
	my @args = split /\./, $aqs;
	
	if (exists $args[3]){
		(my $time, my @other) = split /j/, $args[3];
		return $aqs."\t\t($time milliseconds from first keypress to search. Other parameters unknown)";
	}
	
	return $aqs;
}

#https://www.reddit.com/r/explainlikeimfive/comments/2ecozy/eli5_when_you_search_for_something_on_google_the/
# language and encoding information
sub parse_rlz($){
	my $rlz = shift;
	return $rlz;
}

# Search engine type
sub parse_tbm($){
	my $tbm = shift;
	return "$tbm\t\t(Image Search}" if ($tbm eq "isch");
	return "$tbm\t\t(Video Search}" if ($tbm eq "vid");
	return "$tbm\t\t(News Search}" if ($tbm eq "nws");
	return "$tbm\t\t(Books Search}" if ($tbm eq "books");
	return "$tbm\t\t(Shopping Search}" if ($tbm eq "shopping");
	return $tbm;
}



sub parse_Start($){
# Determines page that the search is on
# ie start=140 = page 15, so divide by 10 + 1
	my $start = shift;
	$start.= "\t\t(Page ".(($start/10)+1).")";
	return $start;
}


sub parse_pws($){
	my $pws = shift;
	return "$pws\t\t(Hide private results)" if ($pws eq "0");
	return "$pws\t\t(Show all results)" if ($pws eq "1");
}

sub parse_safe($){
	my $safe = shift;
	return "$safe\t\t(Safe search off)" if ($safe eq "off");
	return "$safe\t\t(Safe search on)" if ($safe eq "on");
}


# Limited testing of UST appears that its a timestamp that's generated when the results are returned
# So if you open a search page (I've tested for image search so far), then leave the page open for a while
# You can select different images and the black box will appear around them but the redirect link time will reflect
# the time of the original search
# So far this time has only appeared when you select a picture and then click on the "Visit page" or "View Image" boxes
# Selecting the image itself straight off the search page doesn't appear to generate this value but havent looked in the internet
# history, just right click, saved link and parsed
sub parse_ust($){
	my $ust = shift;
 #first 10 characters are a unix timestamp
	my $unix = substr($ust, 0, 10);
	$unix = gmtime($unix);
	return "$ust\t\t($unix UTC - unsure of validity)";
}


sub parse_cad($){
}

sub parse_esrc($){
}

sub parse_rct($){
}

sub parse_sa($){
}

sub parse_uact($){
}

sub parse_usg($){
}

# so far have only seen source = web - havent tested on mobile
sub parse_source($){
}














#Ved parser by https://github.com/beschulz/ved-decoder
sub parse_VED($){
	my $ved = shift;
	my $parsed = "";
	# print "ved = $ved\n";
	# my $command = "echo $ved > temp1";
	# system (qq{$command});
	# $command = "cat temp | $ved_parser"; 
	# system (qq{$command});
	# print "VED: ". readTemp("temp1")."\n\n\n\n";
	return $ved;
}




#https://deedpolloffice.com/blog/articles/decoding-ved-parameter
#     // Copyright 2013 Deed Poll Office Ltd, UK <https://deedpolloffice.com>
#    // Licensed under Apache Licence v2.0 <http://apache.org/licenses/LICENSE-2.0>

#sub parse_VED($){
#	my $ved = shift;
#	my $parsed;
	
	#my %keys = (
 	#	  	"t"  => "2",
    #		"r" => "6",
    #		"s"  => "7",
    #		"i" => "1"
	#);
	#my $ret;

	#if (substr($ved, 0, 1) == '1') {
	 #       preg_match_all('/([a-z]+):([0-9]+)/i', $ved, $matches, PREG_SET_ORDER);
 #       foreach ($matches as $m)
#	    $ret[isset($keys[$m[1]]) ? $keys[$m[1]] : $m[1]] = (int) $m[2];
	#	return "$ved\t\tPlain Text Encoded";
    #}
    #if (substr($ved, 0, 1) == '0') {
	#	return "$ved\t\tProtobuff Encoded";
    #}

 #   preg_match_all('/([\x80-\xff]*[\0-\x7f])([\x80-\xff]*[\0-\x7f])/',
#	base64_decode(str_replace(array('_','-'), array('+','/'), substr($ved, 1))),
#	$matches, PREG_SET_ORDER);
#    foreach ($matches as $m) {
#	$key = $val = 0;
#	foreach (str_split($m[1]) as $i => $c) $key += (ord($c) & 0x7f) << $i * 7;
#	foreach (str_split($m[2]) as $i => $c) $val += (ord($c) & 0x7f) << $i * 7;
#	$ret[$key >> 3] = $val;
#    }
#    return $ret;
#}


sub readTemp($){
	my $temp = shift;
	my $line;
	open(my $fh, '<', $temp) or die "cannot open file $temp";
	{
			local $/;
			$line = <$fh>;
	}
	close($fh);
	chomp $line;
	return $line;
}

sub printEqDivider{
	my $n = 150;
	my $character = '=';
	my $text =~ s/^(.*)/$character x $n . $1/mge;
	print $text."\n";
}

sub printDivider{
	my $n = 150;
	my $character = '-';
	my $text =~ s/^(.*)/$character x $n . $1/mge;
	print $text."\n";
}


sub _help {
	print<< "EOT";
GSERPent v.$VERSION - Google URL Parser
GSERPent [-u url] [-f file] [-h]
Parses Google Search and Redirect URLs to provide additional data
  -u|url ............Single URL
  -f|file ...........Read a list of URLS
  -h.................Help
  
Lists: Required format is URL|Comment. The comment will be included in the output
Lines beginning with # are ignored
EOT
}