# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..5\n"; }
END {print "not ok 1\n" unless $loaded;}
use Text::Vpp;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

# will load a text file, set some variables and compare the output

$fin = new Text::Vpp("text_in.txt") ;
$fin->setVar('var1' => 'was set in calling script') ;

my $ret = $fin -> substitute() ;

my $expect = 
"Sample text for Text::Vpp
Some included text

We shoud see this line from included file
We should see this line

We should see this line if var1 was set by perl
var 1 is: was set in calling script.

Should see this one.

" ;

if ($ret)
  {
	print "ok 2\n";
  }
else
  {
	print "not ok 2\n";
	print @{$fin->getErrors()} ;
  }

my $res = join("\n",@{$fin->getText()})."\n" ;

if ($res eq $expect)
  {
	print "ok 3\n";
  }
else
  {
	print "not ok 3\n",
	"expect\n---\n",$expect,"---\n",
	"got   \n---\n",$res,   "---\n";
  }



# Test the ELSIF construct.

$fin = new Text::Vpp("text_elsif.txt") ;
$fin->setVar('var1' => 3) ;

$ret = $fin -> substitute() ;

$expect =  "Sample text for Text::Vpp using ELSEIF
We should see this line, because var1 should be 3
" ;

if ($ret)
  {
	print "ok 4\n";
  }
else
  {
	print "not ok 4\n";
	print @{$fin->getErrors()} ;
  }

$res = join("\n",@{$fin->getText()})."\n" ;

if ($res eq $expect)
  {
	print "ok 5\n";
  }
else
  {
	print "not ok 5\n",
	"expect\n---\n",$expect,"---\n",
	"got   \n---\n",$res,   "---\n";
  }


